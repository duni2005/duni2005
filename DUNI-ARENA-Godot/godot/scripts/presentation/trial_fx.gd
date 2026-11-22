class_name TrialFx
extends RefCounted
## The moments of a battle's 시련 (CombatPresentation owns one): counter blocks, the environment's
## warnings and impacts, the enemies' empowerments, the reward trials' coins, and the ping that
## flashes a trial's wallet icon whenever it acts. Presentation only: it reads the battle and never
## changes it. Weather and the marks enemies wear come from TrialArt.
const C = preload("res://scripts/trial_catalog.gd")
## A trial's icon flashes at most this often.
const PING_EVERY: float = 1.0
## One counter reaction (particles and the cracked shield) per unit this often.
const BLOCK_EVERY: float = .3
## 끈질긴 생명 heals add up and show this often.
const REGEN_SHOW_EVERY: float = 2.0
## Seconds of 소행성 fall drawn at the end of its warning.
const METEOR_FALL: float = .45
const CRATER_LIFE: float = 6.0
const SOUL_LIFE: float = .65
const COIN_LIFE: float = .85

var p ## CombatPresentation
var pings: Dictionary = {}
var block_at: Dictionary = {}
var regen_frame: Dictionary = {}
var regen_pool: Dictionary = {}
var regen_clock: float = 0
var berserk_seen: Dictionary = {}
var emit_at: Dictionary = {}
var souls: Array[Dictionary] = []
var coins: Array[Dictionary] = []
var tracers: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var craters: Array[Dictionary] = []
var texts: Array[Dictionary] = []
var banner: Dictionary = {}
var quake_warn: float = -1
var quake_fade: float = -1
var started: bool = false

func _init(host) -> void:p = host
func clear() -> void:
	pings.clear();block_at.clear();regen_frame.clear();regen_pool.clear();regen_clock = 0;berserk_seen.clear();emit_at.clear()
	souls.clear();coins.clear();tracers.clear();rings.clear();craters.clear();texts.clear();banner = {};quake_warn = -1;quake_fade = -1;started = false
	if is_instance_valid(strip_hit):strip_hit.hide()
func active() -> bool:return is_instance_valid(p.battle) and not p.battle.trials.is_empty()
func on(id: StringName) -> bool:return id in p.battle.trials

## The trial acted: its icon flashes (once a second at most).
func ping(id: StringName) -> void:
	if p.real_age - float(pings.get(id, -9.0)) < PING_EVERY:return
	pings[id] = p.real_age;p.trial_pinged.emit(id)
## 0..1 of a trial's flash for icons drawn by the presentation (custom battles).
func flash(id: StringName) -> float:
	var age: float = p.real_age - float(pings.get(id, -9.0))
	return clampf(1 - age / .5, 0, 1) if UiMotion.enabled else 0.0

## A counter cut a hit on `target`: its reaction, limited per unit. True when the cracked shield shows.
func blocked(target, id: StringName, angle: float) -> bool:
	ping(id)
	if p.real_age - float(block_at.get(target.battle_id, -9.0)) < BLOCK_EVERY:return false
	block_at[target.battle_id] = p.real_age
	var at: Vector2 = target.position;var r: float = 25 * target.combat_scale();var tint: Color = TrialArt.COUNTER_TINT.get(id, Color.WHITE)
	var hit: Vector2 = at - Vector2.from_angle(angle) * r
	match id:
		&"ironclad":
			p.particles.burst(hit, Color("fff3c8"), 10, 260, angle + PI, "spark", true);p.particles.burst(hit, Color("aab3bf"), 3, 200, angle + PI * .8, "shard", true)
			_text("팅", hit + Vector2(0, -14), Color("e6ecf2"), 12)
		&"seastone":
			rings.append({"point": at, "radius": r + 16, "color": Color("b9d4e4"), "age": 0.0, "life": .45, "width": 3.0})
			p.particles.burst(hit, Color("cfe2ee"), 6, 150, angle + PI, "shard", true)
		&"tough":
			rings.append({"point": at + Vector2(0, r * .6), "radius": r + 22, "color": Color("a07850"), "age": 0.0, "life": .4, "width": 5.0, "flat": true})
			p.particles.burst(at + Vector2(0, r * .6), Color("8a7258"), 5, 70, 0, "smoke", true)
		&"holy":p.particles.burst(hit, Color("ffe7a0"), 10, 140, -PI * .5, "mote", true)
		&"corrupt":
			rings.append({"point": hit, "radius": 22.0, "color": Color("fff6c8"), "age": 0.0, "life": .35, "shrink": true})
			p.particles.burst(hit, Color("3a1a4a"), 4, 50, 0, "plume", false)
		&"immune":p.particles.burst(hit, Color("a8f070"), 8, 170, angle + PI, "mote", true)
		&"insulator":tracers.append({"from": at, "to": at + Vector2(randf_range(-10, 10), r + 16), "age": 0.0, "life": .3, "color": Color("ffe36a"), "bolt": true})
		&"sun":p.particles.burst(at, Color("f2f6fa"), 6, 60, -PI * .5, "smoke", true)
		&"rain":
			p.particles.burst(at, Color("eef4fa"), 7, 70, -PI * .5, "smoke", true)
			_text("치익", hit + Vector2(0, -14), Color("dfe9f4"), 12)
		&"calm":
			for i in range(3):tracers.append({"from": hit + Vector2(0, (i - 1) * 7), "to": hit + Vector2.from_angle(angle + PI + (i - 1) * .5) * 1 + Vector2.from_angle(angle + PI + (i - 1) * .5) * 26 + Vector2(0, (i - 1) * 7), "age": 0.0, "life": .4, "color": Color("d8e6d0")})
		&"bomb_squad":p.particles.burst(hit, Color("ff9a4a"), 6, 60, 0, "ember", true)
		&"melee_masters":
			p.particles.burst(hit, Color("fff6d8"), 12, 280, angle + PI, "spark", true)
			rings.append({"point": hit, "radius": 14.0, "color": Color("fff6d8"), "age": 0.0, "life": .2, "width": 3.0})
		&"spread":
			p.particles.burst(hit, Color("ffd2c6"), 5, 230, angle + PI * .5, "shard", true);p.particles.burst(hit, Color("ffd2c6"), 5, 230, angle - PI * .5, "shard", true)
		&"stubborn":rings.append({"point": at, "radius": r + 8, "color": tint, "age": 0.0, "life": .3, "shield": true})
	return true

## Combat events of the trials; true when handled.
func event(kind: StringName, point: Vector2, m: Dictionary) -> bool:
	match kind:
		&"trial_meteor_warn":ping(&"meteor");return true
		&"trial_meteor":
			var r: float = float(m.get("radius", C.METEOR_RADIUS))
			ping(&"meteor")
			p.add_effect("ult_impact", point, Color("ffb057"), r, .9)
			rings.append({"point": point, "radius": r * 1.5, "color": Color("fff0c8"), "age": 0.0, "life": .5, "width": 8.0})
			if p.use_shader_fx:p.shader_fx.shock(point, r * 1.4, .6, Color("ffb057"))
			else:rings.append({"point": point, "radius": r * 1.9, "color": Color("ffb057"), "age": 0.0, "life": .6, "width": 5.0})
			if craters.size() >= 6:craters.pop_front()
			craters.append({"point": point, "radius": r * .62, "age": 0.0, "turn": randf() * TAU})
			p.particles.burst(point, Color("6a5444"), 18, 380, 0, "shard", true);p.particles.burst(point, Color("ffb36b"), 22, 300, 0, "ember", true);p.particles.burst(point, Color("5a4a42"), 10, 90, -PI * .5, "smoke", true)
			p.camera.impact(12, point)
			return true
		&"trial_quake_warn":ping(&"quake");quake_warn = 0;quake_fade = -1;p.camera.impact(3, point);return true
		&"trial_quake":
			ping(&"quake");quake_warn = -1;quake_fade = 0
			p.camera.impact(10, point)
			for u in p.battle.units:
				if u.alive:p.particles.burst(u.position + Vector2(0, 20 * u.combat_scale()), Color("9a8a70"), 5, 80, -PI * .5, "smoke", true)
			return true
		&"trial_snipe":
			ping(&"sniper")
			var from: Vector2 = m.get("from", point)
			tracers.append({"from": from, "to": point, "age": 0.0, "life": .3, "color": Color("ffd0a0"), "width": 3.0})
			rings.append({"point": from, "radius": 30.0, "color": Color("ffcf8a"), "age": 0.0, "life": .25, "flash": true})
			p.add_effect("hit", point, C.HAZARD_ALLY, 60, .3);p.camera.impact(5, point)
			p.particles.burst(point, C.HAZARD_ALLY, 10, 260, (point - from).angle(), "spark", true)
			return true
		&"trial_lightning_warn":ping(&"lightning");return true
		&"trial_lightning":
			ping(&"lightning")
			var r: float = float(m.get("radius", C.LIGHTNING_RADIUS));var sky: Vector2 = point + Vector2(randf_range(-60, 60), -560)
			if p.use_shader_fx:p.shader_fx.bolt(sky, point, .45)
			tracers.append({"from": sky, "to": point, "age": 0.0, "life": .35, "color": Color("fff6b0"), "bolt": true, "width": 5.0})
			rings.append({"point": point, "radius": r * 1.4, "color": Color("fff8c8"), "age": 0.0, "life": .3, "flash": true})
			rings.append({"point": point, "radius": r * 1.2, "color": Color("ffe36a"), "age": 0.0, "life": .4, "width": 4.0})
			if craters.size() >= 8:craters.pop_front()
			craters.append({"point": point, "radius": r * .45, "age": 1.5, "turn": randf() * TAU})
			p.particles.burst(point, Color("ffe36a"), 14, 260, 0, "spark", true);p.camera.impact(6, point)
			return true
		&"trial_martyr_mark":ping(&"martyr");return true
		&"trial_martyr":
			ping(&"martyr")
			var r: float = float(m.get("radius", C.MARTYR_RADIUS))
			p.add_effect("fireball", point, Color("ff5a3a"), r, .9, randf() * TAU)
			rings.append({"point": point, "radius": r * 1.3, "color": Color("ff8a6a"), "age": 0.0, "life": .45, "width": 6.0})
			if p.use_shader_fx:p.shader_fx.shock(point, r * 1.2, .5, Color("ff6a4a"))
			p.particles.burst(point, Color("ff7a4a"), 18, 300, 0, "ember", true);p.camera.impact(8, point)
			return true
		&"trial_split":
			ping(&"split")
			# Swells, then tears in two with shadow-black shards (not a slime's green).
			rings.append({"point": point, "radius": 46.0, "color": Color("2a2036"), "age": 0.0, "life": .35, "width": 7.0})
			p.particles.burst(point, Color("1e1828"), 14, 240, 0, "shard", true);p.particles.burst(point, Color("8a70b8"), 6, 120, 0, "mote", true)
			return true
		&"keg_lit":
			ping(&"powder_kegs");p.particles.burst(point + Vector2(0, -20), Color("ffd070"), 8, 160, -PI * .5, "spark", true);return true
		&"keg_blast":
			ping(&"powder_kegs")
			var r: float = float(m.get("radius", FieldObject.KEG_BLAST))
			p.add_effect("fireball", point, Color("ff8a3d"), r, 1.0, randf() * TAU)
			rings.append({"point": point, "radius": r * 1.2, "color": Color("ffd08a"), "age": 0.0, "life": .45, "width": 6.0})
			if p.use_shader_fx:p.shader_fx.shock(point, r * 1.1, .55, Color("ffb057"))
			if craters.size() >= 8:craters.pop_front()
			craters.append({"point": point, "radius": r * .55, "age": 0.0, "turn": randf() * TAU})
			p.particles.burst(point, Color("5a3a2a"), 14, 320, 0, "shard", true);p.particles.burst(point, Color("ffb347"), 18, 280, 0, "ember", true);p.particles.burst(point, Color("4a4038"), 8, 80, -PI * .5, "smoke", true)
			p.camera.impact(10, point)
			return true
		&"statue_heal":ping(&"warm_statue");return true
		&"object_block":p.particles.burst(point, Color("e8d0a0"), 5, 150, float(m.get("angle", 0)) + PI, "spark", true);return true
		&"trial_hit":
			var trial: StringName = StringName(m.get("trial", ""))
			p.number("damage", point, float(m.get("amount", 0)), TrialArt.TRIAL_NUMBER, int(m.get("actor_id", 0)), {"icon": String(C.info(trial).get("icon", "")) if trial != &"" else ""})
			return true
		&"trial_regen":
			var id: int = int(m.get("actor_id", 0));var gain: float = float(m.get("amount", 0))
			regen_frame[id] = float(regen_frame.get(id, 0.0)) + gain;regen_pool[id] = float(regen_pool.get(id, 0.0)) + gain
			return true
	return false

## Part of `gain` HP the presentation would show as a heal number that 끈질긴 생명 gave this frame
## (shown summed every REGEN_SHOW_EVERY instead).
func shown_heal(u, gain: float) -> float:return gain - float(regen_frame.get(u.battle_id, 0.0))
func end_frame() -> void:regen_frame.clear()

## A unit fell: 복수심 souls fly to the enemies it spurs, 금괴 운반대 coins leap out.
func death(u) -> void:
	if not active() or not TrialEffects.enemy_side(u):return
	if on(&"vengeance"):
		for v in p.battle.units:
			if v.alive and v != u and TrialEffects.enemy_side(v) and v.position.distance_to(u.position) <= C.VENGEANCE_RADIUS:
				if souls.size() < 24:souls.append({"from": u.position, "actor": v.actor_id(), "age": 0.0, "bend": 1.0 if souls.size() % 2 == 0 else -1.0})
		ping(&"vengeance")
	if on(&"gold_convoy"):
		ping(&"gold_convoy")
		p.particles.burst(u.position, Color("ffd34a"), 12, 240, -PI * .5, "spark", true)
		var from: Vector2 = p.parent_transform * u.position
		for i in range(6):coins.append({"from": from + Vector2(randf_range(-14, 14), randf_range(-10, 6)), "age": -i * .05, "bend": randf_range(-60, 60)})

## Custom battles: the icon row drawn on the field answers a tap with the trial's card.
var strip_hit: Control
const STRIP_R: float = 11
func _sync_strip() -> void:
	var show: bool = active() and p.battle.custom_mode and is_instance_valid(p.board)
	if not show:
		if is_instance_valid(strip_hit):strip_hit.hide()
		return
	if not is_instance_valid(strip_hit):
		strip_hit = Control.new();strip_hit.mouse_filter = Control.MOUSE_FILTER_STOP;p.add_child(strip_hit)
		strip_hit.gui_input.connect(_strip_input)
	var n: int = p.battle.trials.size();var width: float = n * (STRIP_R * 2 + 4) - 4
	strip_hit.position = Vector2(p.board.board_rect().get_center().x - width * .5, 16 - STRIP_R - 4);strip_hit.size = Vector2(width, STRIP_R * 2 + 8);strip_hit.show()
func _strip_input(e: InputEvent) -> void:
	if not ((e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed) or not active():return
	var i: int = clampi(int(e.position.x / (STRIP_R * 2 + 4)), 0, p.battle.trials.size() - 1)
	strip_hit.accept_event()
	TrialPopup.show(p, [p.battle.trials[i]], strip_hit.get_global_transform() * Vector2(STRIP_R + i * (STRIP_R * 2 + 4), STRIP_R + 4))

func advance(dt: float) -> void:
	_sync_strip()
	if not active():return
	var battle = p.battle
	if not started and battle.started:
		started = true
		if on(&"vanguard"):
			# After the screen's BATTLE sweep.
			banner = {"text": "돌격!", "age": -.9, "color": C.color_of(&"vanguard")};ping(&"vanguard")
		for u in battle.units:
			if u.alive and u.state_value("trialElite") > 0:
				_text("정예", u.position + Vector2(0, -60 * u.combat_scale()), Color("ffd34a"), 18, 1.6)
				rings.append({"point": u.position, "radius": 70 * u.combat_scale(), "color": Color("ffd34a"), "age": 0.0, "life": .8, "width": 5.0});ping(&"elite_squad")
		if on(&"fog"):ping(&"fog")
	if banner.has("age"):
		banner.age = float(banner.age) + dt
		if float(banner.age) > 1.6:banner = {}
	# 끈질긴 생명: the heals of the last two seconds in one small number.
	regen_clock += dt
	if regen_clock >= REGEN_SHOW_EVERY:
		regen_clock = 0
		for id in regen_pool:
			var u = _unit(int(id))
			if u != null and float(regen_pool[id]) >= 1:
				p.number("heal", u.position, float(regen_pool[id]), Color("9be8a0"), u.battle_id, {"small": true});ping(&"regen")
		regen_pool.clear()
	for u in battle.units:
		if not u.alive or not TrialEffects.enemy_side(u):continue
		if on(&"berserkers") and TrialEffects.berserk(u) and not berserk_seen.has(u.battle_id):
			berserk_seen[u.battle_id] = true;ping(&"berserkers")
			p.flashes[u.battle_id] = .15
			rings.append({"point": u.position, "radius": 60 * u.combat_scale(), "color": Color("ff3a2a"), "age": 0.0, "life": .5, "width": 6.0})
			p.particles.burst(u.position, Color("ff4a3a"), 14, 220, 0, "ember", true);_text("광폭화", u.position + Vector2(0, -50), Color("ff6a5a"), 15)
		if berserk_seen.has(u.battle_id) and _every("steam%d" % u.battle_id, .3):p.particles.burst(u.position + Vector2(0, -10), Color("c85a50"), 1, 40, -PI * .5, "smoke", false)
		if TrialEffects.vanguard(u) and _every("dust%d" % u.battle_id, .07):
			p.particles.burst(u.position - Vector2.from_angle(u.facing) * 18 + Vector2(0, 14), Color("b8a68a"), 1, 30, u.facing + PI, "smoke", false)
	if quake_warn >= 0:
		quake_warn += dt
		if _every("quake", .18):p.camera.impact(1.5, ArenaMap.center())
	if quake_fade >= 0:
		quake_fade += dt
		if quake_fade > 1.2:quake_fade = -1
	for list in [souls, tracers, rings, craters, texts, coins]:
		for e in list:e.age = float(e.age) + dt
	for s in souls.duplicate():
		if float(s.age) >= SOUL_LIFE:
			souls.erase(s);var v = battle.find_actor(String(s.actor))
			if v != null and v.alive:p.particles.burst(v.position, Color("ff6a3a"), 6, 120, -PI * .5, "flame", true)
	tracers = tracers.filter(func(e):return float(e.age) < float(e.life))
	rings = rings.filter(func(e):return float(e.age) < float(e.life))
	craters = craters.filter(func(e):return float(e.age) < CRATER_LIFE)
	texts = texts.filter(func(e):return float(e.age) < float(e.life))
	coins = coins.filter(func(e):return float(e.age) < COIN_LIFE)
func _every(key: String, period: float) -> bool:
	if p.real_age - float(emit_at.get(key, -9.0)) < period:return false
	emit_at[key] = p.real_age;return true
func _text(text: String, at: Vector2, color: Color, size: int, life: float = .9) -> void:
	if texts.size() >= 12:texts.pop_front()
	texts.append({"text": text, "point": at, "color": color, "size": size, "age": 0.0, "life": life})
func _unit(id: int):
	for u in p.battle.units:
		if u.battle_id == id:return u
	return null

## Under the units (arena space): weather, cracks, craters, impact warnings, enemy ground marks.
func draw_ground(c: CanvasItem) -> void:
	var battle = p.battle;var time: float = p.real_age;var side: float = p.map_side
	TrialArt.field(c, battle.trials, side, time)
	for e in craters:
		var fade: float = clampf((CRATER_LIFE - float(e.age)) / 1.5, 0, 1)
		VfxArt.glow(c, e.point, float(e.radius) * 1.3, Color("1a120c"), .7 * fade, .7)
		for i in range(7):
			var a: float = float(e.turn) + i * TAU / 7
			c.draw_line(e.point + Vector2.from_angle(a) * float(e.radius) * .4, e.point + Vector2.from_angle(a + .2) * float(e.radius) * 1.1, Color("2a1a12", .6 * fade), 3)
		if float(e.age) < 2:VfxArt.glow(c, e.point, float(e.radius) * .6, Color("ff7a3a"), .35 * (1 - float(e.age) / 2))
	# 지진: cracks spread from the middle during the warning, then fade.
	var crack: float = clampf(quake_warn / C.QUAKE_WARN, 0, 1) if quake_warn >= 0 else (1 - quake_fade / 1.2 if quake_fade >= 0 else 0.0)
	if crack > 0:
		var grow: float = clampf(quake_warn / C.QUAKE_WARN, 0, 1) if quake_warn >= 0 else 1.0
		var alpha: float = 1.0 if quake_warn >= 0 else crack
		var center := Vector2(side, side) * .5
		for i in range(9):
			var a: float = i * TAU / 9 + .3;var at: Vector2 = center
			for seg in range(5):
				if seg > grow * 5:break
				var next: Vector2 = at + Vector2.from_angle(a + sin(i * 3.1 + seg * 1.7) * .5) * side * .1
				c.draw_line(at, next, Color("2a2018", .8 * alpha), 4 - seg * .5);c.draw_line(at, next, Color(C.HAZARD_ALL, .35 * alpha), 1.2)
				at = next
	var s: Dictionary = battle.trial_state
	for m in s.get("meteors", []):
		# The sky darkens and the shadow grows; the circle is yellow (it hits both sides).
		var k: float = clampf(1 - float(m.left) / C.METEOR_WARN, 0, 1);var r: float = float(m.radius)
		VfxArt.glow(c, m.point, r * (.3 + .7 * k), Color("0a0806"), .5 * k, .7)
		c.draw_circle(m.point, r, Color(C.HAZARD_ALL, .08 + .12 * k))
		c.draw_arc(m.point, r, 0, TAU, 48, Color(C.HAZARD_ALL, .7 + .3 * sin(time * 14)), 3, true)
		c.draw_arc(m.point, r * k, 0, TAU, 48, Color(C.HAZARD_ALL, .5), 2, true)
	# 낙뢰: yellow (everyone) with crackling sparks; 순교자: red (the player's side), shrinking.
	for b in s.get("bolts", []):
		var k: float = clampf(1 - float(b.left) / C.LIGHTNING_WARN, 0, 1);var r: float = float(b.radius)
		c.draw_circle(b.point, r, Color(C.HAZARD_ALL, .1 + .14 * k))
		c.draw_arc(b.point, r, 0, TAU, 40, Color(C.HAZARD_ALL, .75 + .25 * sin(time * 16)), 2.5, true)
		for i in range(3):
			var a: float = time * 9 + i * 2.1
			VisualShapes.bolt(c, b.point + Vector2.from_angle(a) * r * .2, b.point + Vector2.from_angle(a + .6) * r * .9, Color("fff6a0", .7), time * 40 + i, 1.5)
	for mk in s.get("blasts", []):
		var k: float = clampf(float(mk.left) / C.MARTYR_FUSE, 0, 1);var r: float = float(mk.radius)
		VfxArt.glow(c, mk.point, r * (.4 + .6 * k), C.HAZARD_ALLY, .35 + .25 * (1 - k))
		c.draw_arc(mk.point, r * k, 0, TAU, 48, Color(C.HAZARD_ALLY, .9), 3, true)
		c.draw_arc(mk.point, r, 0, TAU, 48, Color(C.HAZARD_ALLY, .4), 1.5, true)
	for u in battle.units:
		if u.alive and TrialEffects.enemy_side(u):TrialArt.unit_ground(c, u.position, 25 * u.combat_scale(), battle.trials, time, u.battle_id)
	if not battle.field_objects.is_empty():TrialArt.objects(c, battle.field_objects, time)

## Over the units (arena space): enemy marks, empowerments, falling meteors, aim, souls, rings, words.
func draw_over(c: CanvasItem) -> void:
	var battle = p.battle;var time: float = p.real_age
	for u in battle.units:
		if not u.alive or not TrialEffects.enemy_side(u):continue
		var at: Vector2 = u.position;var r: float = 25 * u.combat_scale()
		TrialArt.unit_over(c, at, r, battle.trials, time, u.battle_id)
		if u.state_value("trialElite") > 0:TrialArt.elite_mark(c, at, r, time)
		if on(&"regen"):
			# Green leaves rising slowly.
			for i in range(3):
				var phase: float = fposmod(time * .35 + i / 3.0 + u.battle_id * .13, 1.0)
				var leaf: Vector2 = at + Vector2(sin(i * 2.3 + u.battle_id) * r * .7 + sin(time * 2 + i) * 4, r * .3 - phase * r * 1.8)
				var dir := Vector2.from_angle(time * 1.5 + i)
				c.draw_colored_polygon(PackedVector2Array([leaf - dir * 4, leaf + dir.orthogonal() * 2, leaf + dir * 4, leaf - dir.orthogonal() * 2]), Color("7fe07a", .8 * sin(phase * PI)))
		if berserk_seen.has(u.battle_id):
			VfxArt.glow(c, at, r * 1.6, Color("ff2a1a"), .3 + .12 * sin(time * 8))
			for e in [-1, 1]:VfxArt.glow(c, at + Vector2(e * r * .28, -r * .18), 5, Color("ff3a2a"), .9)
		var stacks: int = int(u.state_value("vengeanceStacks"))
		if stacks > 0:
			var badge: Vector2 = at + Vector2(r * .9, r * .75)
			c.draw_circle(badge, 8, Color("3a0c0a"));c.draw_arc(badge, 8, 0, TAU, 20, Color("ff6a3a"), 1.5, true)
			ArenaIcon.draw(c, badge + Vector2(-9, 0), "fang", 9, Color("ff8a5a"))
			c.draw_string(ArenaUI.numbers_font(), badge + Vector2(-3.5, 4.5), str(stacks), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd0a0"))
		if TrialEffects.vanguard(u):
			# Speed lines trailing the charge.
			var back: Vector2 = -Vector2.from_angle(u.facing)
			for i in range(3):
				var o: Vector2 = back.orthogonal() * (i - 1) * r * .5
				c.draw_line(at + back * r * 1.1 + o, at + back * r * (2.2 + .4 * sin(time * 20 + i)) + o, Color("ffe6c8", .55), 2)
	var s: Dictionary = battle.trial_state
	for m in s.get("meteors", []):
		if float(m.left) > METEOR_FALL:continue
		# A burning rock streaking down from the upper right.
		var k: float = 1 - float(m.left) / METEOR_FALL
		var start: Vector2 = m.point + Vector2(260, -420);var rock: Vector2 = start.lerp(m.point, k * k)
		for i in range(6):VfxArt.glow(c, rock.lerp(start, i * .07), 26 - i * 3, Color("ff8a3a").lerp(Color("ffe08a"), i / 6.0), .6 - i * .08)
		c.draw_circle(rock, 13, Color("4a3426"));c.draw_circle(rock + Vector2(-3, -3), 7, Color("6a4a32"))
	var aim: Dictionary = s.get("aim", {})
	if not aim.is_empty():
		var target = battle.find_actor(String(aim.target))
		if target != null and target.alive:
			var from: Vector2 = TrialEffects.sniper_origin(battle, target.position);var k: float = clampf(1 - float(aim.left) / C.SNIPER_AIM, 0, 1)
			c.draw_line(from, target.position, Color(C.HAZARD_ALLY, .3 + .5 * k), 1.2 + 2 * k, true)
			# The scope's ring tightens on the target.
			var ring: float = lerpf(64, 24, k) * target.combat_scale()
			c.draw_arc(target.position, ring, 0, TAU, 36, Color(C.HAZARD_ALLY, .65 + .35 * sin(time * 18)), 2, true)
			for i in range(4):
				var d: Vector2 = Vector2.from_angle(i * PI * .5)
				c.draw_line(target.position + d * (ring - 8), target.position + d * (ring + 12), Color(C.HAZARD_ALLY, .9), 2, true)
			VfxArt.glow(c, from, 18, C.HAZARD_ALLY, .4 + .4 * k)
	for e in tracers:
		var t: float = float(e.age) / float(e.life)
		if e.get("bolt", false):VisualShapes.bolt(c, e.from, e.to, Color(e.color, 1 - t), p.real_age * 40, 2)
		else:c.draw_line(Vector2(e.from).lerp(e.to, t * .6), e.to, Color(e.color, 1 - t), float(e.get("width", 2.0)) * (1 - t) + 1, true)
	for e in rings:
		var t: float = float(e.age) / float(e.life);var col: Color = Color(e.color, 1 - t)
		if e.get("shield", false):TrialArt.broken_shield(c, e.point + Vector2(0, -float(e.radius) * .2), 18, col)
		elif e.get("flash", false):VfxArt.glow(c, e.point, float(e.radius) * (1 + t), e.color, 1 - t)
		elif e.get("shrink", false):VfxArt.glow(c, e.point, float(e.radius) * (1 - t), e.color, .8 * (1 - t))
		elif e.get("flat", false):VfxArt.ellipse(c, e.point, float(e.radius) * (.4 + .6 * t), .4, col, float(e.get("width", 2.0)) * (1 - t) + 1)
		else:c.draw_arc(e.point, float(e.radius) * (.3 + .7 * (1 - pow(1 - t, 3))), 0, TAU, 40, col, float(e.get("width", 2.0)) * (1 - t) + 1, true)
	for sl in souls:
		var v = battle.find_actor(String(sl.actor))
		if v == null:continue
		var t: float = clampf(float(sl.age) / SOUL_LIFE, 0, 1);var k: float = t * t * (3 - 2 * t)
		var mid: Vector2 = (Vector2(sl.from) + v.position) * .5 + Vector2(0, -60) + (v.position - Vector2(sl.from)).orthogonal().normalized() * 30 * float(sl.bend)
		var at: Vector2 = Vector2(sl.from).lerp(mid, k).lerp(mid.lerp(v.position, k), k)
		VfxArt.glow(c, at, 14, Color("ff3a2a"), .8);c.draw_circle(at, 4, Color("ffd0a0"))
	var font: Font = ArenaUI.heading_font()
	for e in texts:
		var t: float = float(e.age) / float(e.life)
		c.draw_string_outline(font, Vector2(e.point) + Vector2(-float(e.size) * len(e.text) * .45, -t * 24), e.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(e.size), 4, Color(0, 0, 0, .6 * (1 - t)))
		c.draw_string(font, Vector2(e.point) + Vector2(-float(e.size) * len(e.text) * .45, -t * 24), e.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(e.size), Color(e.color, 1 - t * t))

## 짙은 안개: a projectile far from where it left fades into the fog.
func veil(c: CanvasItem, projectile, origin: Vector2) -> void:
	var k: float = clampf(projectile.position.distance_to(origin) / 220.0, 0, 1)
	if k > .05:VfxArt.glow(c, projectile.position, 30, Color("d8dde6"), .55 * k)

## Screen space over the board: the sky dimming before a meteor, the 선봉대 call, coins, and in
## custom battles the trials' icon row (with their flashes).
func draw_screen(c: CanvasItem, rect: Rect2) -> void:
	var battle = p.battle
	var dark: float = 0
	for m in battle.trial_state.get("meteors", []):dark = maxf(dark, clampf(1 - float(m.left) / C.METEOR_WARN, 0, 1))
	if dark > 0:c.draw_rect(rect, Color(0, 0, .02, .16 * dark))
	if banner.has("age") and float(banner.age) >= 0:
		var t: float = float(banner.age) / 1.6;var a: float = clampf(t / .12, 0, 1) * clampf((1 - t) / .2, 0, 1)
		# High on the field, clear of the battle's own start banner.
		var y: float = rect.position.y + rect.size.y * .14 + 22
		c.draw_rect(Rect2(rect.position.x, y - 22, rect.size.x, 44), Color(.08, .02, .04, .75 * a))
		for e in [y - 22, y + 22]:c.draw_line(Vector2(rect.position.x, e), Vector2(rect.end.x, e), Color(banner.color, a), 2)
		var font: Font = ArenaUI.heading_font();var x: float = lerpf(rect.end.x, rect.position.x + rect.size.x * .5, 1 - pow(1 - clampf(t * 4, 0, 1), 3)) - 40
		c.draw_string(font, Vector2(x, y + 10), banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, .92, .85, a))
	var to := Vector2(rect.get_center().x, rect.position.y - 10)
	if is_instance_valid(p.wallet) and p.wallet.is_visible_in_tree():to = p.get_global_transform().affine_inverse() * p.wallet.anchor("gold")
	for e in coins:
		if float(e.age) < 0:continue
		var t: float = float(e.age) / COIN_LIFE;var k: float = t * t
		var from: Vector2 = e.from;var mid: Vector2 = from.lerp(to, .3) + Vector2(float(e.bend), -80)
		var at: Vector2 = from.lerp(mid, k).lerp(mid.lerp(to, k), k)
		c.draw_circle(at, 6, Color("c9902a"));c.draw_circle(at, 4.5, Color("ffd34a"))
	if battle.custom_mode and not battle.trials.is_empty():
		var f: Dictionary = {}
		for id in battle.trials:f[id] = flash(id)
		# In the status row at the top of the board (between "전투 중" and the clock).
		TrialArt.strip(c, Vector2(rect.get_center().x, 16), battle.trials, STRIP_R, f)
