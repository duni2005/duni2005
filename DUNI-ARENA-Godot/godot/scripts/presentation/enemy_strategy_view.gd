class_name EnemyStrategyView
extends RefCounted
## Shows the special strategies enemies are preparing at a turning point: a badge over each
## enemy's head, the range or path of attacks and moves on the ground, and a detail card for the
## selected enemy. After the turning point the warning stays up until a smash or cleave lands.
const COLORS = {&"heal":Color("77edb4"), &"smash":Color("ff7a5a"), &"move":Color("8ec5ff"), &"charge":Color("c49dff"), &"overcharge":Color("ffd36b"), &"cleave":Color("ff7a5a"), &"evade":Color("8ee8ff"), &"slash":Color("ffb36b"), &"sweep":Color("ff3d5a")}
## Grade marks: 위험 one "!", 고위험 two, in the grade's colour.
const TIER_COLORS = {&"normal":Color("9fb4d8"), &"danger":Color("ff9a4a"), &"high":Color("ff3d5a")}
const TIER_MARKS = {&"normal":"", &"danger":"!", &"high":"!!"}
const BADGE := Vector2(60, 20)
static func badge_size(plan: EnemyTurningPlan, font: Font) -> Vector2:
	var text: String = EnemyTurningPlan.NAMES[plan.plan_type] + TIER_MARKS[plan.tier()]
	return Vector2(maxf(BADGE.x, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 30), BADGE.y)

## [plan, enemy] pairs on display while the turning point holds.
static func shown(battle: BattleManager) -> Array:
	var out: Array = []
	if battle.turning == null or not battle.turning.is_paused():return out
	for plan in battle.turning.current.enemy_plans:
		var enemy: BattleUnit = EnemyPlanExecutor.find_enemy(battle, plan.source_enemy_id)
		if enemy != null and not plan.executed:out.append([plan, enemy])
	return out
static func plan_for(battle: BattleManager, actor_id: String) -> EnemyTurningPlan:
	for row in shown(battle):
		if row[1].actor_id() == actor_id:return row[0]
	return null

## Ground markers in arena space: the planned area while held, then the live warning.
static func draw_ground(c: CanvasItem, battle: BattleManager, time: float) -> void:
	for row in shown(battle):
		_area(c, row[0].plan_type, row[0].metadata, row[1], time, 0)
	for u in battle.units:
		if u.alive and not u.strategy_cast.is_empty():
			_area(c, u.strategy_cast.kind, u.strategy_cast, u, time, clampf(float(u.strategy_cast.age) / EnemyPlanExecutor.windup(u.strategy_cast), 0, 1))
static func _area(c: CanvasItem, kind: StringName, m: Dictionary, u: BattleUnit, time: float, charge: float) -> void:
	var color: Color = COLORS.get(kind, Color.WHITE);var pulse: float = .5 + .5 * sin(time * 5)
	match kind:
		EnemyTurningPlan.SMASH:
			var angle: float = float(m.angle);var r: float = float(m.range);var arc: float = EnemyPlanExecutor.SMASH_ARC
			var fan := PackedVector2Array([u.position])
			for i in range(17):fan.append(u.position + Vector2.from_angle(angle - arc + arc * 2 * i / 16.0) * r)
			c.draw_colored_polygon(fan, Color(color, .13 + .06 * pulse + .25 * charge))
			if charge > 0:
				var inner := PackedVector2Array([u.position])
				for i in range(17):inner.append(u.position + Vector2.from_angle(angle - arc + arc * 2 * i / 16.0) * r * charge)
				c.draw_colored_polygon(inner, Color(color, .3))
			c.draw_arc(u.position, r, angle - arc, angle + arc, 24, Color(color, .85), 3, true)
			for side in [-1, 1]:c.draw_line(u.position, u.position + Vector2.from_angle(angle + arc * side) * r, Color(color, .6), 2, true)
			for k in range(3):
				var at: Vector2 = u.position + Vector2.from_angle(angle) * r * (.35 + .2 * k + .08 * fposmod(time * 1.6, 1))
				c.draw_polyline(PackedVector2Array([at + Vector2.from_angle(angle + 2.4) * 12, at, at + Vector2.from_angle(angle - 2.4) * 12]), Color(color.lightened(.3), .7), 3, true)
		EnemyTurningPlan.CLEAVE:
			var from: Vector2 = CharacterPersistence.vector(m.from, u.position);var to: Vector2 = CharacterPersistence.vector(m.to, u.position)
			var direction: float = (to - from).angle();var length: float = from.distance_to(to);var half: float = float(m.width) * .5
			var side: Vector2 = Vector2.from_angle(direction + PI * .5) * half;var forward: Vector2 = Vector2.from_angle(direction)
			c.draw_colored_polygon(PackedVector2Array([from + side, to + side, to - side, from - side]), Color(color, .12 + .06 * pulse + .2 * charge))
			if charge > 0:c.draw_colored_polygon(PackedVector2Array([from + side, from + side + forward * length * charge, from - side + forward * length * charge, from - side]), Color(color, .28))
			for k in [-1, 1]:c.draw_line(from + side * k, to + side * k, Color(color, .75), 2, true)
			var x: float = fmod(time * 220, 48)
			while x < length - 10:
				var at: Vector2 = from + forward * x
				c.draw_polyline(PackedVector2Array([at + side * .55 - forward * 10, at, at - side * .55 - forward * 10]), Color(color.lightened(.3), .65), 3, true)
				x += 48
		EnemyTurningPlan.SLASH, EnemyTurningPlan.SWEEP:
			var center: Vector2 = CharacterPersistence.vector(m.center, u.position);var r: float = float(m.radius)
			c.draw_circle(center, r, Color(color, .12 + .06 * pulse + .22 * charge))
			if charge > 0:c.draw_circle(center, r * charge, Color(color, .28))
			c.draw_arc(center, r, 0, TAU, 48, Color(color, .85), 3 if kind == EnemyTurningPlan.SWEEP else 2, true)
			# Crossed slash marks; the sweep turns them slowly around its centre.
			for k in range(3 if kind == EnemyTurningPlan.SWEEP else 2):
				var a: float = time * (.8 if kind == EnemyTurningPlan.SWEEP else 0) + k * PI / (3 if kind == EnemyTurningPlan.SWEEP else 2) + PI * .25
				c.draw_line(center + Vector2.from_angle(a) * r * .55, center - Vector2.from_angle(a) * r * .55, Color(color.lightened(.3), .6), 3, true)
			if kind == EnemyTurningPlan.SWEEP:
				# Arrows from the rim toward the point everyone will be dragged to.
				var gather: Vector2 = CharacterPersistence.vector(m.get("gather", {}), center)
				for k in range(8):
					var rim: Vector2 = center + Vector2.from_angle(k * TAU / 8 + time * .3) * r * .92
					var along: Vector2 = (gather - rim).normalized();var tip: Vector2 = rim + along * (r * .3 + 10 * fposmod(time * 1.4, 1))
					c.draw_line(rim, tip, Color(color.lightened(.2), .75), 2, true)
					c.draw_colored_polygon(PackedVector2Array([tip + along * 8, tip + along.orthogonal() * 5, tip - along.orthogonal() * 5]), Color(color.lightened(.2), .85))
				c.draw_circle(gather, 9, Color(color, .5 + .3 * pulse));c.draw_arc(gather, 15, 0, TAU, 24, Color(color.lightened(.4), .8), 2, true)
		EnemyTurningPlan.MOVE, EnemyTurningPlan.EVADE:
			var from: Vector2 = CharacterPersistence.vector(m.from, u.position);var to: Vector2 = CharacterPersistence.vector(m.to, u.position)
			var forward: Vector2 = (to - from).normalized();var length: float = from.distance_to(to);var x: float = fmod(time * 60, 22)
			while x < length - 16:
				c.draw_line(from + forward * x, from + forward * minf(x + 11, length - 16), Color(color, .8), 3, true)
				x += 22
			c.draw_colored_polygon(PackedVector2Array([to, to - forward * 20 + forward.orthogonal() * 10, to - forward * 20 - forward.orthogonal() * 10]), Color(color, .9))
			c.draw_arc(to, 22 * u.combat_scale(), 0, TAU, 32, Color(color, .5 + .3 * pulse), 2, true)

## Badges over the enemies' heads, in the board's screen space: [plan, enemy, rect]. A badge
## that would cover another one stacks above it.
static func layout(battle: BattleManager, parent: Transform2D, font: Font = null) -> Array:
	var rows: Array = shown(battle)
	for row in rows:
		var head: Vector2 = parent * (row[1].position - Vector2(0, 25 * row[1].combat_scale() + 6))
		var badge: Vector2 = badge_size(row[0], font) if font != null else BADGE
		row.append(Rect2(head - Vector2(badge.x * .5, badge.y + 20), badge))
	rows.sort_custom(func(a, b): return a[2].position.y > b[2].position.y)
	for i in range(rows.size()):
		var moved: bool = true
		while moved:
			moved = false
			for j in range(i):
				if rows[i][2].grow(1).intersects(rows[j][2]):rows[i][2].position.y = rows[j][2].position.y - BADGE.y - 3;moved = true
	return rows
static func badge_hit(battle: BattleManager, parent: Transform2D, point: Vector2, font: Font = null) -> BattleUnit:
	for row in layout(battle, parent, font):
		if row[2].grow(3).has_point(point):return row[1]
	return null
static func draw_badges(c: CanvasItem, battle: BattleManager, parent: Transform2D, selected: String, time: float) -> void:
	var font: Font = c.get_theme_default_font()
	for row in layout(battle, parent, font):
		var plan: EnemyTurningPlan = row[0];var u: BattleUnit = row[1];var color: Color = COLORS[plan.plan_type];var rect: Rect2 = row[2]
		var tier: StringName = plan.tier();var tier_color: Color = TIER_COLORS[tier]
		var picked: bool = selected == u.actor_id()
		# A thin leader line ties a stacked badge to its enemy.
		var head: Vector2 = parent * (u.position - Vector2(0, 25 * u.combat_scale() + 6))
		c.draw_line(Vector2(rect.get_center().x, rect.end.y), head - Vector2(0, 14), Color(color, .55), 1.5, true)
		# 고위험 badges glow and pulse red; 위험 ones carry an orange edge.
		if tier == EnemyTurningPlan.HIGH:c.draw_style_box(ArenaUI.box(Color(tier_color, .25 + .2 * sin(time * 7)), Color(0, 0, 0, 0)), rect.grow(4))
		c.draw_style_box(ArenaUI.box(Color(.06, .07, .1, .92), color if picked else tier_color if tier != EnemyTurningPlan.NORMAL else Color(color, .7)), rect)
		ArenaIcon.draw(c, rect.position + Vector2(12, 10), EnemyTurningPlan.ICONS[plan.plan_type], 14, Color.WHITE)
		c.draw_string(font, rect.position + Vector2(21, 15), EnemyTurningPlan.NAMES[plan.plan_type], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24 - (10 if tier != EnemyTurningPlan.NORMAL else 0), 11, color.lightened(.25))
		if tier != EnemyTurningPlan.NORMAL:c.draw_string(font, Vector2(rect.end.x - 14, rect.position.y + 15), TIER_MARKS[tier], HORIZONTAL_ALIGNMENT_CENTER, 12, 12, tier_color.lightened(.2))
		if picked:c.draw_rect(rect.grow(2), Color(color, .45 + .3 * sin(time * 6)), false, 1.5)

## Detail card for the selected enemy's strategy, inside the board rect.
static func draw_detail(c: CanvasItem, battle: BattleManager, area: Rect2, selected: String) -> void:
	var plan: EnemyTurningPlan = plan_for(battle, selected)
	if plan == null:return
	var enemy: BattleUnit = battle.find_actor(selected);var color: Color = COLORS[plan.plan_type];var font: Font = c.get_theme_default_font()
	var width: float = minf(300, area.size.x - 20);var rect := Rect2(Vector2(area.get_center().x - width * .5, area.position.y + 10), Vector2(width, 82))
	c.draw_style_box(ArenaUI.box(Color(.055, .065, .095, .95), Color(color, .8)), rect)
	c.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(4, rect.size.y - 2)), color)
	c.draw_circle(rect.position + Vector2(30, 28), 17, Color(color, .2));ArenaIcon.draw(c, rect.position + Vector2(30, 28), EnemyTurningPlan.ICONS[plan.plan_type], 22, Color.WHITE)
	c.draw_string(font, rect.position + Vector2(54, 24), "[%s]" % EnemyTurningPlan.NAMES[plan.plan_type], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color.lightened(.2))
	var tier: StringName = plan.tier()
	c.draw_string(font, rect.position + Vector2(54, 41), "%s · %s 특수행동" % [enemy.data.display_name, EnemyTurningPlan.TIER_NAMES[tier]], HORIZONTAL_ALIGNMENT_LEFT, width - 62, 11, TIER_COLORS[tier] if tier != EnemyTurningPlan.NORMAL else ArenaUI.MUTED)
	c.draw_multiline_string(font, rect.position + Vector2(14, 60), plan.describe(), HORIZONTAL_ALIGNMENT_LEFT, width - 24, 12, 2, Color("e8ecf5"))
