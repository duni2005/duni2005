class_name CardFieldView
extends RefCounted
## Strategy cards on the field (drawn in arena space by CombatPresentation):
## - while a unit card is held, the units it can be played on glow and the others are dimmed;
## - 방벽 설치 walls (glowing barriers that flicker as they run out);
## - an enemy strategy badge breaking when a disruption card removes it, and wall hits;
## - passive cards: 전열 정비 shield light on the allies at the start, 원소 공명 solid lines in the
##   element's colour between the allies that share it, 불굴의 의지 a golden crack and "불굴".

static func draw_walls(c: CanvasItem, battle, time: float) -> void:
	# 치유 장판: a green circle with rising crosses, fading out in its last second.
	for z in battle.card_zones:
		var center: Vector2 = z.center;var r: float = float(z.radius);var fade: float = clampf(float(z.life), 0, 1)
		var col: Color = Color("7fe0a0")
		c.draw_circle(center, r, Color(col, .16 * fade));c.draw_arc(center, r, 0, TAU, 48, Color(col, .8 * fade), 2.5, true)
		c.draw_arc(center, r * (.4 + .6 * fposmod(time * .6, 1)), 0, TAU, 40, Color(col.lightened(.3), .45 * fade * (1 - fposmod(time * .6, 1))), 2, true)
		for k in range(5):
			var rise: float = fposmod(time * .7 + k * .2, 1);var at: Vector2 = center + Vector2.from_angle(k * 1.3) * r * .55 * fposmod(k * .37 + .2, 1) - Vector2(0, 26 * rise)
			var a: float = (1 - rise) * .9 * fade
			c.draw_line(at - Vector2(5, 0), at + Vector2(5, 0), Color(col.lightened(.4), a), 2.5, true);c.draw_line(at - Vector2(0, 5), at + Vector2(0, 5), Color(col.lightened(.4), a), 2.5, true)
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
		&"card_heal_zone":
			presentation.particles.burst(point, Color("b8f5c8"), 22, 180, 0, "spark", true)
			presentation.add_effect("slime_ring", point, Color("7fe0a0"), float(m.get("radius", 110)), .6)
			return true
		&"card_wall":
			presentation.particles.burst(point, Color("8fe3ff"), 22, 200, 0, "spark", true)
			presentation.add_effect("slime_ring", point, Color("8fe3ff"), 70, .5)
			return true
		&"passive_rally":
			presentation.add_effect("slime_ring", point, Color("9fe0ff"), 54, .7)
			presentation.add_effect("shield_hit", point, Color("c8f0ff"), 40)
			presentation.particles.burst(point, Color("c8f0ff"), 10, 120, 0, "spark", true)
			return true
		&"passive_resonance":
			var col: Color = ItemFx.ELEMENT_COLORS.get(str(m.get("element", "")), Color("ffd36b"))
			var points: Array = m.get("points", [])
			for i in range(points.size()):
				var p: Vector2 = points[i];var q: Vector2 = points[(i + 1) % points.size()]
				if points.size() == 2 and i == 1:break
				presentation.item_fx._mark("beam", p, 1.4, {"to": q, "color": col})
				presentation.particles.burst(p, col, 8, 110, 0, "spark", true)
			return true
		&"passive_indomitable":
			presentation.item_fx._mark("card_crack", point, 1.1, {"color": ArenaUI.GOLD})
			presentation.item_fx._mark("text", point, 1.3, {"text": "불굴", "color": ArenaUI.GOLD})
			presentation.add_effect("hero_shock", point, ArenaUI.GOLD, 80, .5)
			presentation.particles.burst(point, Color("ffe08a"), 22, 240, 0, "shard", true)
			presentation.camera.impact(4, point)
			return true
		&"wall_block":
			presentation.particles.burst(point, Color("dff6ff"), 10, 180, float(m.get("angle", 0)) + PI, "spark", true)
			presentation.add_effect("shield_hit", point, Color("8fe3ff"), 26)
			return true
	return false
