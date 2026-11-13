class_name ItemFx
extends RefCounted
## Battle visuals of the 0.95 items, drawn by CombatPresentation:
## - an item's icon rises over the bearer's head for PROC_ICON_TIME when its effect fires
##   (ItemEffects.proc limits that to once per PROC_ICON_GAP per item),
## - one-off effects from the "item_fx" combat events (by item),
## - lasting looks drawn with the unit (red steam at low HP, horns, cloak, gears, crowns...).
## 영웅 and higher items add a ring in their grade colour to their effects. Frequent effects
## (blood orbs, drops, coins) are rate-limited; every burst follows 파티클 품질 and the
## shader-effect switch through the presentation.
var host
## Rising item icons: {actor, item, age}.
var pops: Array[Dictionary] = []
## Short-lived drawn effects: {kind, point, age, life, ...}.
var marks: Array[Dictionary] = []
## Last time (real seconds) a rate-limited effect was shown, by item.
var recent: Dictionary = {}
var bleed_clock: float = 0
const MAX_MARKS: int = 48
## Effects that fire on many hits; at most one every LIMIT_GAP seconds per item.
const LIMITED = ["vampireFang", "bloodChalice", "sniperScope", "weakEye", "poisonDagger", "guardChain", "shadowDoll"]
const LIMIT_GAP: float = .14
const ELEMENT_COLORS = {"fire": Color("ff8a3d"), "poison": Color("8fe36b"), "ice": Color("a8e4ff"), "lightning": Color("bfe9ff")}

func _init(presentation) -> void:host = presentation

func clear() -> void:pops.clear();marks.clear();recent.clear()

func advance(dt: float) -> void:
	for row in [pops, marks]:
		for m in row:m.age = float(m.age) + dt
	pops = pops.filter(func(m):return float(m.age) < ItemTuning.PROC_ICON_TIME)
	marks = marks.filter(func(m):return float(m.age) < float(m.life))
	# Bleeding units drip.
	bleed_clock -= dt
	if bleed_clock <= 0 and is_instance_valid(host.battle):
		bleed_clock = .3
		for u in host.battle.units:
			if u.alive and u.state_value("bleedTime") > 0:host.particles.burst(u.position + Vector2(0, -8), Color("d23a4a"), 2, 60, PI * .5, "spark", false)

func _mark(kind: String, point: Vector2, life: float, extra: Dictionary = {}) -> void:
	if marks.size() >= MAX_MARKS:marks.pop_front()
	var m: Dictionary = {"kind": kind, "point": point, "age": 0.0, "life": life};m.merge(extra, true);marks.append(m)
static func grade_color(item: String) -> Color:return ItemCatalog.grade_color(StringName(item))
static func high(item: String) -> bool:return ItemCatalog.grade_rank(StringName(item)) >= 2

## A combat event (CombatPresentation passes "item_proc" and "item_fx").
func event(e: Dictionary) -> void:
	var m: Dictionary = e.metadata;var item: String = str(m.get("item", ""));var at: Vector2 = e.point
	var targets: Array = m.get("to") if m.get("to") is Array else []
	if String(e.kind) == "item_proc":
		pops = pops.filter(func(p):return not (int(p.actor) == int(m.get("actor_id", -1)) and p.item == item))
		pops.append({"actor": int(m.get("actor_id", -1)), "item": item, "age": 0.0, "point": at});return
	if item in LIMITED:
		if host.real_age - float(recent.get(item, -9.0)) < LIMIT_GAP:return
		recent[item] = host.real_age
	var p = host.particles;var shader: bool = host.use_shader_fx
	var tint: Color = grade_color(item)
	# 영웅+: one extra ring of the grade colour around the effect.
	if high(item) and not m.get("trail", false):host.add_effect("slime_ring", at, tint, 46, .45)
	match item:
		"sniperScope":_mark("crosshair", at, .4)
		"vampireFang", "bloodChalice":
			var to: Vector2 = CharacterPersistence.vector(m.get("to", {}), at)
			_mark("orb", at, .45, {"to": to, "color": Color("e5525e") if item == "vampireFang" else Color("b3122e"), "size": 5.0 if item == "vampireFang" else 3.5})
		"hunterShuriken":_mark("speed", at, .5, {"actor": int(m.actor_id)});p.burst(at, Color("ffe066"), 8, 220, 0, "spark", false)
		"thornArmor":_mark("thorns", at, .35, {"to": CharacterPersistence.vector(m.get("to", {}), at)})
		"firstStrikeRing":
			host.add_effect("hero_shock", at, Color("fff6d8"), 80, .4);p.burst(at, Color.WHITE, 16, 300, 0, "spark", true)
		"bleedBlade":p.burst(at, Color("e5525e"), 8, 160, PI * .5, "spark", true)
		"lifeChalice":
			_mark("cup", CharacterPersistence.vector(m.get("from", {}), at), .7)
			host.add_effect("shield_hit", at, Color("ffe08a"), 34)
		"echoStaff":
			if m.has("from"):_mark("echo", CharacterPersistence.vector(m.from, at), .35, {"to": at})
			host.add_effect("slime_ring", at, Color("c49dff"), 30, .4)
		"executionScythe":_mark("scythe", at, .7);host.add_effect("hero_shock", at, Color("d7c6ff"), 70, .5);host.camera.impact(6, at)
		"counterShield":
			if m.get("strike", false):_mark("shield_flash", at, .45)
			else:_mark("shield_spark", at, .5, {"actor": int(m.actor_id)})
		"rageHorn":host.add_effect("hero_shock", at, Color("ff5a5a"), 60, .45);p.burst(at, Color("ff6a6a"), 12, 140, -PI * .5, "heal", true)
		"steelGreatsword":host.add_effect("hero_shock", at, Color("dfe6f0"), 85, .45);p.burst(at, Color("eef3fa"), 14, 260, 0, "shard", true);host.camera.impact(4, at)
		"elementStone":
			var c: Color = ELEMENT_COLORS.get(str(m.get("element", "fire")), Color("ffb46a"))
			host.add_effect("fireball", at, c, float(m.get("radius", 100)) * .8, .7, 0)
			if shader:host.shader_fx.shock(at, float(m.get("radius", 100)), .45, c)
			for to in targets:p.burst(CharacterPersistence.vector(to, at), c, 6, 120, 0, "shard", true);_mark("shard", at, .3, {"to": CharacterPersistence.vector(to, at), "color": c})
		"stormCrown":
			_mark("cloud", at, 1.0)
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				if shader:host.shader_fx.bolt(hit + Vector2(0, -150), hit)
				else:_mark("bolt", hit, .3)
				p.burst(hit, Color("bfe9ff"), 8, 200, 0, "spark", true)
		"infinityEdge":
			_mark("blade", at, .35);_boost_number(at, "big")
		"oblivionVeil":
			if m.get("cloak", false):p.burst(at, Color("2a2238"), 14, 60, 0, "smoke", true)
			else:host.add_effect("hero_shock", at, Color("b48cff"), 70, .4);_mark("tear", at, .45);p.burst(at, Color("efd9ff"), 12, 260, 0, "shard", true)
		"elderHeart":
			if m.has("grow"):host.add_effect("slime_ring", at, Color("b8875a"), 40, .5);p.burst(at, Color("87b65f"), 10, 120, -PI * .5, "mote", true)
			else:p.burst(at + Vector2(0, 16), Color("87b65f"), 5, 60, -PI * .5, "mote", false)
		"lifeResonance":
			host.add_effect("hero_shock", at, Color("8fe36b"), float(m.get("radius", 150)), .7)
			for to in targets:p.burst(CharacterPersistence.vector(to, at), Color("b9f08f"), 6, 90, -PI * .5, "heal", false)
		"eternalArmor":_mark("armor", at, .45);_boost_number(at, "cracked")
		"frostCrown":
			host.add_effect("slime_ring", at, Color("a8e4ff"), float(m.get("radius", 100)), .5);p.burst(at, Color("e2f6ff"), 18, 260, 0, "shard", true)
		"twinMirror":_mark("ripple", at, .7);p.burst(at, Color("dfe8ff"), 12, 160, 0, "mote", true)
		"mangoSeed":
			for to in targets:_mark("mango", CharacterPersistence.vector(to, at), .8)
		"rewindClock":
			var path: Array = []
			for q in m.get("path", []):path.append(CharacterPersistence.vector(q, at))
			_mark("rewind", at, .9, {"path": path});p.burst(at, Color("d0b8ff"), 14, 160, 0, "mote", true)
		"invertedHourglass":_mark("hourglass", at, .9);p.burst(at + Vector2(0, -30), Color("eec45e"), 10, 90, -PI * .5, "mote", true)
		"greedPouch":_mark("coin", at, .5)
		"overdriveEngine":host.add_effect("slime_ring", at, Color("ff6a3d"), 40, .6);p.burst(at, Color("6b5a5a"), 10, 70, -PI * .5, "smoke", true)
		"shadowDoll":
			# 저주 인형: a dark thread from the doll to the attacker it hurts back.
			_mark("thread", CharacterPersistence.vector(m.get("from", {}), at), .35, {"to": at});p.burst(at, Color("4a2a5a"), 4, 70, 0, "smoke", false)
		"guardFeather":host.add_effect("shield_hit", at, Color("dfe8ff"), 44);p.burst(at, Color("f4f6ff"), 14, 180, -PI * .5, "mote", true)
		"poisonDagger":p.burst(at, Color("8fe36b"), 5, 90, -PI * .5, "mote", false)
		"weakEye":_mark("crosshair", at, .45)
		"guardChain":
			if m.has("amount"):host.number("status", at, float(m.amount), Color("a9a6b4"), -100 - int(m.actor_id))
			else:_mark("chain", at, .4, {"to": CharacterPersistence.vector(m.get("to", {}), at)})
		"warDrum":host.add_effect("hero_shock", at, Color("ffb36b"), 160, .6);p.burst(at, Color("ffd08a"), 12, 200, 0, "spark", true)
		"mimicMask":host.add_effect("slime_ring", at, Color("c49dff"), 60, .5);_mark("badge", at, .6, {"color": Color("c49dff"), "icon": "mimicMask"})
		"soulReaper":_mark("orb", at, .6, {"to": CharacterPersistence.vector(m.get("to", {}), at), "color": Color("b9d8ff"), "size": 5.0})
		"starShard":
			for to in targets:_mark("meteor", CharacterPersistence.vector(to, at), .55, {"radius": float(m.get("radius", 70))})

## Marks the newest damage number at a point (무한의 칼날 makes it bigger, 영겁의 갑주 cracks it).
func _boost_number(at: Vector2, flag: String) -> void:
	for i in range(host.numbers.size() - 1, -1, -1):
		var n: Dictionary = host.numbers[i]
		if float(n.age) < .3 and n.kind in ["damage", "critical"] and Vector2(n.point).distance_to(at) < 40:n[flag] = true;return

## The ground layer (nothing since 0.96; kept for the presentation's call order).
func draw_ground(_c: CanvasItem) -> void:pass

## Looks that last while the item's condition holds, drawn with the unit (p: body centre, s: scale).
func draw_unit(c: CanvasItem, u: BattleUnit, p: Vector2, s: float) -> void:
	if not u.alive:return
	var t: float = host.real_age;var stats: UnitCombatStats = u.combat_stats
	if u.character_specific_state.has("mirrorOf"):
		c.draw_arc(p, 30 * s, 0, TAU, 32, Color("e8eef8", .55 + .2 * sin(t * 3)), 2, true)
	# Team auras: 왕의 왕관 (a small gold crown light), 전쟁의 북 (beat rings), 약점 노출 (red reticle).
	if ItemEffects.king_blessed(u):VfxArt.glow(c, p + Vector2(0, -50 * s), 8 * s, Color("ffd36b"), .45)
	if ItemEffects.drummed(u) and fposmod(t, .8) < .2:c.draw_arc(p, (26 + fposmod(t, .8) * 40) * s, 0, TAU, 24, Color("ffb36b", .35), 1.5, true)
	if u.state_value("weakTime") > 0:
		c.draw_arc(p, 20 * s, t * 2, t * 2 + 1.2, 10, Color("ff5a5a", .8), 2, true);c.draw_arc(p, 20 * s, t * 2 + PI, t * 2 + PI + 1.2, 10, Color("ff5a5a", .8), 2, true)
	if stats == null or stats.effects.is_empty():return
	var head: Vector2 = p + Vector2(0, -44 * s)
	if stats.has(&"berserkerHelm") and ItemEffects.berserk(u):
		var pulse: float = .5 + .5 * sin(t * 8)
		c.draw_arc(p, 31 * s, 0, TAU, 32, Color("ff4a3a", .4 + .4 * pulse), 2.5, true)
		for k in range(3):
			var rise: float = fposmod(t * .9 + k * .33, 1.0)
			VfxArt.glow(c, head + Vector2((k - 1) * 8 * s, -rise * 22 * s), 9 * s, Color("ff6a5a"), .35 * (1 - rise))
	if stats.has(&"rageHorn") and u.stance == CombatStance.RUSH:
		for side in [-1, 1]:
			c.draw_colored_polygon(PackedVector2Array([head + Vector2(side * 8, 4) * s, head + Vector2(side * 18, -14) * s, head + Vector2(side * 3, 0) * s]), Color("ff4a4a", .75))
	if stats.has(&"oblivionVeil") and u.state_value("shadowTime") > 0:
		VfxArt.glow(c, p, 40 * s, Color("2a2238"), .45)
	if stats.has(&"overdriveEngine"):
		var speed: float = 1 + minf(30, u.state_value("overdrive")) * .25;var at: Vector2 = p + Vector2(26, -20) * s
		for k in range(6):
			var a: float = t * speed + k * TAU / 6
			c.draw_line(at + Vector2.from_angle(a) * 5 * s, at + Vector2.from_angle(a) * 9 * s, Color("c9d2de"), 2.5, true)
		c.draw_circle(at, 4 * s, Color("8a95a6"))
	if u.state_value("rewindReady") > 0:
		var at: Vector2 = head + Vector2(0, -16 * s)
		c.draw_arc(at, 8 * s, 0, TAU, 20, Color("d0b8ff", .8), 1.5, true)
		c.draw_line(at, at + Vector2.from_angle(-t * 3) * 6 * s, Color("d0b8ff"), 1.5, true)
	if stats.has(&"mangoSeed"):
		var at: Vector2 = head + Vector2(18, 0) * s
		c.draw_line(at, at + Vector2(0, -8) * s, Color("87b65f"), 2, true);c.draw_circle(at + Vector2(0, -12) * s, 3.5 * s, Color("ffc34a"))
	if stats.has(&"elderHeart"):c.draw_arc(p, 29 * s, 0, TAU, 28, Color("8a6440", .55), 2, true)
	if u.state_value("regenTime") > 0:
		VfxArt.glow(c, p, 36 * s, Color("77edb4"), .3 + .15 * sin(t * 10));c.draw_circle(p, 5 * s, Color("b6ffd8"))
	if stats.has(&"stormCrown"):VfxArt.glow(c, head + Vector2(0, -10 * s), 14 * s, Color("5a6680"), .4)
	if stats.has(&"frostCrown"):VfxArt.glow(c, head + Vector2(0, -6 * s), 10 * s, Color("ffb46a").lerp(Color("bfeaff"), .5 + .5 * sin(t * 2)), .45)
	if stats.has(&"soulReaper") and u.state_value("soulStacks") > 0:
		for k in range(mini(6, int(u.state_value("soulStacks")))):
			var a: float = t * 1.5 + k * TAU / 6;VfxArt.glow(c, p + Vector2.from_angle(a) * 24 * s, 5 * s, Color("b9d8ff"), .5)
	if stats.has(&"guardChain"):
		var ward = host.battle.units.filter(func(a):return a != u and a.alive and a.team == u.team and not a.character_specific_state.has("mirrorOf"))
		if not ward.is_empty():
			ward.sort_custom(func(x, y):return x.position.distance_to(p) < y.position.distance_to(p))
			_chain(c, p, ward[0].position, .3)
	if u.state_value("counterCritUntil") > host.battle.clock.elapsed:VfxArt.glow(c, p + Vector2(-22, -18) * s, 8 * s, Color("bfe9ff"), .6 + .3 * sin(t * 12))
	var ready: bool = u.state_value("firstStrike") > 0 or stats.has(&"steelGreatsword") and u.state_value("smashCount") >= ItemTuning.GREATSWORD_EVERY - 1
	if ready:VfxArt.glow(c, p + Vector2.from_angle(u.facing) * 30 * s, 9 * s, Color("fff3c8"), .5 + .3 * sin(t * 10))

func _chain(c: CanvasItem, a: Vector2, b: Vector2, alpha: float) -> void:
	var n: int = maxi(2, int(a.distance_to(b) / 12))
	for i in range(n):
		var q: Vector2 = a.lerp(b, (i + .5) / n)
		c.draw_arc(q, 4, 0, TAU, 8, Color("ffd27a", alpha), 2, true)

## Short effects and the rising item icons, above everything on the field.
func draw_over(c: CanvasItem) -> void:
	for m in marks:
		var k: float = float(m.age) / float(m.life);var at: Vector2 = m.point;var fade: float = 1 - k
		match m.kind:
			"crosshair":
				c.draw_arc(at, 14, 0, TAU, 20, Color("ff5a5a", fade), 2, true)
				for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:c.draw_line(at + d * 8, at + d * 20, Color("ff5a5a", fade), 2, true)
			"orb":
				var to: Vector2 = m.to;var q: Vector2 = at.lerp(to, Motion.out_quint(k)) + Vector2(0, -30 * sin(k * PI))
				c.draw_circle(q, float(m.size), Color(m.color, fade));VfxArt.glow(c, q, float(m.size) * 2.5, m.color, .3 * fade)
			"speed":
				var u = host.battle.find_unit(int(m.actor))
				if u != null:
					for i in range(4):c.draw_line(u.position + Vector2(-30 - i * 6, -12 + i * 8), u.position + Vector2(-14 - i * 6, -12 + i * 8), Color("ffe066", fade), 2, true)
			"thorns":
				var dir: Vector2 = (Vector2(m.to) - at).normalized()
				for i in range(5):
					var a: Vector2 = at + dir.rotated((i - 2) * .35) * 22;c.draw_line(a, a + dir.rotated((i - 2) * .35) * (10 + 10 * (1 - k)), Color("8a6a3a", fade), 3, true)
			"cup":ArenaIcon.draw(c, at + Vector2(0, -60 - 12 * k), "lifeChalice", 22, Color(1, 1, 1, fade))
			"echo":c.draw_line(at, Vector2(m.to), Color("c49dff", .6 * fade), 3, true);c.draw_circle(Vector2(m.to), 6 * fade + 2, Color("e6d6ff", fade))
			"scythe":
				var a0: float = -2.4 + 2.6 * Motion.out_quint(k)
				c.draw_arc(at + Vector2(0, -10), 46, a0 - 1.1, a0, 18, Color("e8e2ff", .75 * fade), 6, true)
				c.draw_string(ThemeDB.fallback_font, at + Vector2(-20, -52 - 10 * k), "처형", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffe8ff", fade))
			"shield_flash":
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -26), at + Vector2(20, -16), at + Vector2(16, 12), at + Vector2(0, 24), at + Vector2(-16, 12), at + Vector2(-20, -16)]), Color("bfe9ff", .45 * fade))
			"shield_spark":
				var u = host.battle.find_unit(int(m.actor))
				if u != null:ArenaIcon.draw(c, u.position + Vector2(-24, -24), "counterShield", 16, Color(1, 1, 1, fade))
			"chain":_chain(c, at, Vector2(m.to), fade)
			"badge":ArenaIcon.draw(c, at + Vector2(0, -40 - 10 * k), str(m.get("icon", "")), 26 + 10 * k, Color(1, 1, 1, fade))
			"shard":c.draw_line(at.lerp(Vector2(m.to), k * .7), at.lerp(Vector2(m.to), minf(1, k * .7 + .2)), Color(m.color, fade), 3, true)
			"cloud":
				for i in range(3):VfxArt.glow(c, at + Vector2((i - 1) * 16, -64), 22, Color("3a4258"), .6 * fade)
			"bolt":VisualShapes.bolt(c, at + Vector2(0, -150), at, Color("dff4ff", fade), int(m.age * 30), 3)
			"blade":c.draw_line(at + Vector2(-34, 24), at + Vector2(34, -24), Color("ffd54a", fade), 5 * fade + 1, true)
			"tear":
				for i in range(3):c.draw_line(at + Vector2(-20 + i * 14, -24), at + Vector2(-14 + i * 14, 24), Color("efd9ff", fade), 3, true)
			"armor":
				c.draw_arc(at, 34, 0, TAU, 6, Color("ffd54a", fade), 4, true);VfxArt.glow(c, at, 40, Color("ffd54a"), .35 * fade)
			"ripple":
				for i in range(3):c.draw_arc(at, (10 + i * 10) * (.5 + k), 0, TAU, 28, Color("e8eef8", fade * (1 - i * .25)), 2, true)
			"mango":
				var q: Vector2 = at + Vector2(0, -70 + 50 * Motion.out_quint(minf(1, k * 1.6)))
				c.draw_circle(q, 6, Color("ffb347", fade));c.draw_line(q + Vector2(0, -6), q + Vector2(3, -10), Color("4e813e", fade), 2, true)
			"rewind":
				var path: Array = m.path
				for i in range(path.size() - 1, 0, -1):
					var w: float = clampf(k * path.size() - (path.size() - 1 - i), 0, 1)
					c.draw_line(path[i], path[i - 1], Color("d0b8ff", .7 * (1 - w) * fade + .1), 3, true)
				c.draw_arc(at, 22, -k * 8, -k * 8 + 4.5, 20, Color("d0b8ff", fade), 3, true)
			"hourglass":ArenaIcon.draw(c, at + Vector2(0, -64), "invertedHourglass", 26, Color(1, 1, 1, fade))
			"coin":
				var q: Vector2 = at + Vector2(0, -20 - 26 * k);c.draw_circle(q, 5, Color("ffd54a", fade));c.draw_arc(q, 5, 0, TAU, 12, Color("b8822a", fade), 1.5, true)
			"thread":c.draw_line(at, Vector2(m.to), Color("17121f", .8 * fade), 2, true)
			"meteor":
				# A star falls for the first half, then bursts on the ground.
				var fall: float = minf(1, k * 2);var from: Vector2 = at + Vector2(-90, -220)
				if k < .5:
					var head: Vector2 = from.lerp(at, fall);c.draw_line(from.lerp(at, maxf(0, fall - .3)), head, Color("ffe6a0", .8), 4, true);c.draw_circle(head, 6, Color("fff6d8"))
				else:
					var b: float = (k - .5) * 2;c.draw_arc(at, float(m.radius) * (.4 + .6 * b), 0, TAU, 28, Color("ffd27a", 1 - b), 3, true);VfxArt.glow(c, at, float(m.radius), Color("ffb46a"), .4 * (1 - b))
	# Rising icons over the bearers' heads.
	for pop in pops:
		var u = host.battle.find_unit(int(pop.actor))
		var base: Vector2 = u.position if u != null and u.alive else Vector2(pop.point)
		var s: float = u.combat_scale() if u != null else 1.0
		var k: float = float(pop.age) / ItemTuning.PROC_ICON_TIME
		var alpha: float = minf(1, k * 6) * (1 - maxf(0, k - .6) / .4)
		var at: Vector2 = base + Vector2(0, -(62 + 18 * Motion.out_quint(k)) * s)
		var ring: Color = grade_color(pop.item)
		c.draw_circle(at, 18, Color(.06, .07, .1, .75 * alpha))
		c.draw_arc(at, 18, 0, TAU, 24, Color(ring, alpha), 3.5 if high(pop.item) else 2.0, true)
		ArenaIcon.draw(c, at, pop.item, 28, Color(1, 1, 1, alpha))
