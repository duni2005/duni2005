class_name TrialArt
extends RefCounted
## How 시련 look: the round icon (rim in the kind's colour), the battlefield warnings (소행성
## impact circles, 저격 지원 aim lines), the weather over the field (태양 warm edges, 비 rain,
## 짙은 안개 drifting fog; 무풍지대 has only its icon) and the reactions to trial events.
const METEOR_COLOR := Color("ff4a3a")
const SNIPER_COLOR := Color("ff3a4a")
## 시련 피해 numbers.
const TRIAL_NUMBER := Color("b9bec8")

## The trial's round icon at `center` with radius `r` (scale animates it in).
static func icon(c: CanvasItem, center: Vector2, r: float, id: StringName, scale: float = 1.0) -> void:
	if scale <= .01:return
	var rr: float = r * scale;var rim: Color = TrialCatalog.color_of(id)
	c.draw_circle(center, rr, Color("101624"))
	ArenaIcon.draw(c, center, String(TrialCatalog.info(id).get("icon", "")), rr * 1.35, Color.WHITE)
	c.draw_arc(center, rr - .75, 0, TAU, 32, rim, maxf(1.5, rr * .16), true)

## Ground warnings, in arena space (under the units).
static func draw_ground(c: CanvasItem, battle, time: float) -> void:
	var s: Dictionary = battle.trial_state
	if s.is_empty():return
	for m in s.get("meteors", []):
		var k: float = clampf(1 - float(m.left) / TrialCatalog.METEOR_WARN, 0, 1);var r: float = float(m.radius)
		c.draw_circle(m.point, r, Color(METEOR_COLOR, .12 + .2 * k))
		c.draw_circle(m.point, r * k, Color(METEOR_COLOR, .22))
		c.draw_arc(m.point, r, 0, TAU, 48, Color(METEOR_COLOR, .75 + .25 * sin(time * 14)), 3, true)
		for i in range(4):
			var d: Vector2 = Vector2.from_angle(i * PI * .5 + PI * .25)
			c.draw_line(m.point + d * r * .25, m.point + d * r * .6, Color(METEOR_COLOR, .6), 2, true)
	var aim: Dictionary = s.get("aim", {})
	if not aim.is_empty():
		var target = battle.find_actor(String(aim.target))
		if target != null and target.alive:
			var from: Vector2 = TrialEffects.sniper_origin(battle, target.position);var k: float = clampf(1 - float(aim.left) / TrialCatalog.SNIPER_AIM, 0, 1)
			c.draw_line(from, target.position, Color(SNIPER_COLOR, .35 + .5 * k), 1.5 + 2 * k, true)
			c.draw_arc(target.position, 30 * target.combat_scale(), 0, TAU, 32, Color(SNIPER_COLOR, .6 + .4 * sin(time * 18)), 2, true)
			for i in range(4):
				var d: Vector2 = Vector2.from_angle(i * PI * .5)
				c.draw_line(target.position + d * 18, target.position + d * 38, Color(SNIPER_COLOR, .85), 2, true)

## Weather over the whole board rect (screen space).
static func draw_weather(c: CanvasItem, battle, rect: Rect2, time: float) -> void:
	if TrialEffects.on(battle, &"sun"):
		# Warm light leaking in from the edges.
		c.draw_rect(rect, Color("ffb347", .07))
		for i in range(8):
			var edge: Vector2 = rect.position + Vector2(rect.size.x * (i % 4) / 3.0, 0 if i < 4 else rect.size.y)
			VfxArt.glow(c, edge, rect.size.x * .34, Color("ffb347"), .3 + .06 * sin(time * 1.3 + i))
		VfxArt.glow(c, rect.position + Vector2(rect.size.x * .85, 0), rect.size.x * .5, Color("ffe39a"), .4)
	if TrialEffects.on(battle, &"rain"):
		for i in range(90):
			var seed_x: float = fposmod(i * 0.6180339 * 997.0, 1.0);var fall: float = fposmod(time * 1.7 + i * .137, 1.0)
			var p: Vector2 = rect.position + Vector2(seed_x * rect.size.x + fall * 30, fall * rect.size.y)
			c.draw_line(p, p + Vector2(-5, 18), Color("b8dcff", .55), 1.4)
		c.draw_rect(rect, Color("1a2a40", .12))
	if TrialEffects.on(battle, &"fog"):
		for i in range(9):
			var drift: float = fposmod(time * .025 + i * .17, 1.2) - .1
			var p: Vector2 = rect.position + Vector2(drift * rect.size.x, rect.size.y * fposmod(i * .37, 1.0))
			VfxArt.glow(c, p, rect.size.x * .38, Color("d8dde6"), .18, .55)

## Reactions to trial events; true when handled.
static func event(presentation, kind: StringName, point: Vector2, m: Dictionary) -> bool:
	match kind:
		&"trial_meteor":
			presentation.add_effect("ult_impact", point, Color("ff7a3a"), float(m.get("radius", 110)), 1.0)
			presentation.particles.burst(point, Color("ffb36b"), 26, 320, 0, "ember", true);presentation.particles.burst(point, Color("6b5a4a"), 14, 110, 0, "smoke", true)
			presentation.camera.impact(12, point)
			return true
		&"trial_meteor_warn":return true
		&"trial_quake_warn":presentation.camera.impact(4, point);return true
		&"trial_quake":
			presentation.camera.impact(7, point)
			for u in presentation.battle.units:
				if u.alive:presentation.particles.burst(u.position + Vector2(0, 18), Color("8a7a62"), 3, 60, -PI * .5, "smoke")
			return true
		&"trial_snipe":
			presentation.add_effect("hit", point, SNIPER_COLOR, 60, .3);presentation.camera.impact(5, point)
			return true
		&"trial_hit":
			var gray: bool = str(m.get("kind", "")) == "trial"
			presentation.number("trial" if gray else "damage", point, float(m.get("amount", 0)), TRIAL_NUMBER if gray else Color.WHITE, int(m.get("actor_id", 0)))
			return true
	return false
