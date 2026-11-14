class_name CardFieldView
extends RefCounted
## Strategy cards on the field (drawn in arena space by CombatPresentation):
## - while a unit card is held, the units it can be played on glow and the others are dimmed;
## - 방벽 설치 walls (glowing barriers that flicker as they run out);
## - an enemy strategy badge breaking when a disruption card removes it, and wall hits.

static func draw_walls(c: CanvasItem, battle, time: float) -> void:
	for w in battle.card_walls:
		var a: Vector2 = w.a;var b: Vector2 = w.b;var left: float = float(w.life) / maxf(.01, float(w.max_life))
		var flick: float = 1.0 if left > .25 else .55 + .45 * sin(time * 30)
		var col: Color = Color("8fe3ff")
		var n: Vector2 = (b - a).normalized().orthogonal() * StrategyCardTuning.WALL_THICKNESS * .5
		c.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), Color(col, .28 * flick))
		c.draw_line(a, b, Color(col.lightened(.4), .9 * flick), 3, true)
		for k in range(1, 6):
			var p: Vector2 = a.lerp(b, k / 6.0)
			c.draw_line(p - n, p + n, Color(col, .5 * flick), 1.5, true)
		VfxArt.glow(c, Vector2(w.center), Vector2(w.a).distance_to(Vector2(w.b)) * .6, col, .18 * flick)

## Held unit card: rings on the units it can be played on, a shade over the others.
static func draw_focus(c: CanvasItem, battle, board, time: float) -> void:
	if board == null or not board.card_focus_on:return
	for u in battle.units:
		if not u.alive:continue
		var r: float = 30 * u.combat_scale()
		if u.actor_id() in board.card_focus_ids:
			var pulse: float = .5 + .5 * sin(time * 6)
			VfxArt.glow(c, u.position, r * 2.2, ArenaUI.GOLD, .3 + .15 * pulse)
			c.draw_arc(u.position, r + 4 + 3 * pulse, 0, TAU, 32, Color(ArenaUI.GOLD, .95), 3, true)
		else:
			c.draw_circle(u.position, r * 1.2, Color(0, 0, 0, .55))

## Combat events: a strategy badge shatters (disruption), a wall is raised or stops a shot.
static func event(presentation, kind: StringName, point: Vector2, m: Dictionary) -> bool:
	match kind:
		&"plan_broken":
			var tier: StringName = StringName(str(m.get("tier", "normal")))
			var col: Color = {&"normal":Color("8fd0ff"), &"danger":Color("ffb05e"), &"high":Color("ff5a6a")}.get(tier, Color.WHITE)
			var at: Vector2 = point + Vector2(0, -52)
			presentation.particles.burst(at, col, 26, 260, 0, "shard", true)
			presentation.particles.burst(at, Color.WHITE, 10, 160, 0, "spark", true)
			presentation.add_effect("slime_ring", at, col, 46, .5)
			presentation.add_effect("hero_shock", point, col, 70, .45)
			presentation.camera.impact(4, point)
			return true
		&"card_wall":
			presentation.particles.burst(point, Color("8fe3ff"), 22, 200, 0, "spark", true)
			presentation.add_effect("slime_ring", point, Color("8fe3ff"), 70, .5)
			return true
		&"wall_block":
			presentation.particles.burst(point, Color("dff6ff"), 10, 180, float(m.get("angle", 0)) + PI, "spark", true)
			presentation.add_effect("shield_hit", point, Color("8fe3ff"), 26)
			return true
	return false
