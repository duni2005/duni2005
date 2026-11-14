class_name ItemFx
extends RefCounted
## Battle visuals of the items (희귀 and up), drawn by CombatPresentation:
## - the item's icon rises over the bearer's head when its effect fires (ItemEffects.proc limits
##   that to once per PROC_ICON_GAP per item), with a halo and, from 전설 up, light rays;
## - every "item_fx" event gets a burst scaled by grade (GRADE_SCALE): 희귀 a ring and sparks,
##   영웅 a double ring and shards, 전설 a light pillar, rays and a shockwave, 고대 a rune circle,
##   a crimson double shockwave and a short camera kick; then the item's own effect, also scaled;
## - lasting looks drawn with the unit, and a slow grade-coloured sigil under units wearing 전설 /
##   고대 items.
## Frequent effects (blood orbs, coins, poison, sanctuary...) are rate-limited and get the small
## burst only; every particle burst follows 파티클 품질, shockwaves the shader-effect switch.
var host
## Rising item icons: {actor, item, age, point}.
var pops: Array[Dictionary] = []
## Short-lived drawn effects: {kind, point, age, life, ...}.
var marks: Array[Dictionary] = []
## Last time (real seconds) a rate-limited effect was shown, by item.
var recent: Dictionary = {}
var bleed_clock: float = 0
const MAX_MARKS: int = 64
## Size / particle multiplier by grade rank (일반 0 .. 고대 4).
const GRADE_SCALE = [1.0, 1.3, 1.65, 2.05, 2.5]
## Effects that fire on many hits: at most one every LIMIT_GAP seconds per item, small burst only.
const LIMITED = ["vampireFang", "bloodChalice", "sniperScope", "weakEye", "poisonDagger", "guardChain", "shadowDoll", "enchantedBlade", "duelistGlove", "elementTome", "vanguardShield", "sanctuaryLamp", "elderHeart", "piercingAwl", "swiftCloak", "frostCrown", "giantHeart", "skyBowstring"]
const STAT_NAMES = {"max_hp": "최대 HP", "physical_damage": "물리 피해", "magic_damage": "마법 피해", "defense": "방어력", "speed": "이동속도", "attack_speed": "공격속도"}
const LIMIT_GAP: float = .18
const ICON_LIFE: float = ItemTuning.PROC_ICON_TIME
const ELEMENT_COLORS = {"fire": Color("ff8a3d"), "poison": Color("8fe36b"), "ice": Color("a8e4ff"), "lightning": Color("bfe9ff"), "wind": Color("9ff0d8"), "light": Color("ffe9a0"), "dark": Color("b48cff")}

func _init(presentation) -> void:host = presentation

func clear() -> void:pops.clear();marks.clear();recent.clear()

func advance(dt: float) -> void:
	for row in [pops, marks]:
		for m in row:m.age = float(m.age) + dt
	pops = pops.filter(func(m):return float(m.age) < ICON_LIFE)
	marks = marks.filter(func(m):return float(m.age) < float(m.life))
	# Bleeding units drip.
	bleed_clock -= dt
	if bleed_clock <= 0 and is_instance_valid(host.battle):
		bleed_clock = .25
		for u in host.battle.units:
			if u.alive and u.state_value("bleedTime") > 0:host.particles.burst(u.position + Vector2(0, -8), Color("d23a4a"), 4, 90, PI * .5, "spark", false)

func _mark(kind: String, point: Vector2, life: float, extra: Dictionary = {}) -> void:
	if marks.size() >= MAX_MARKS:marks.pop_front()
	var m: Dictionary = {"kind": kind, "point": point, "age": 0.0, "life": life};m.merge(extra, true);marks.append(m)
static func grade_color(item: String) -> Color:return ItemCatalog.grade_color(StringName(item))
static func rank(item: String) -> int:return clampi(ItemCatalog.grade_rank(StringName(item)), 0, 4)
static func high(item: String) -> bool:return rank(item) >= 2
static func gscale(item: String) -> float:return GRADE_SCALE[rank(item)]

## The burst every item effect gets, bigger and richer with the grade.
func _grade_burst(item: String, at: Vector2, small: bool) -> void:
	var r: int = rank(item);var g: float = GRADE_SCALE[r];var tint: Color = grade_color(item);var p = host.particles
	host.add_effect("slime_ring", at, tint, 34 * g, .45)
	p.burst(at, tint.lightened(.25), int(6 * g), 150 * g, 0, "spark", r >= 2)
	if small:return
	if r >= 2:
		host.add_effect("slime_ring", at, tint.lightened(.35), 56 * g, .6)
		p.burst(at, tint, int(8 * g), 230 * g, 0, "shard", true)
	if r >= 3:
		_mark("pillar", at, .75, {"color": tint, "size": g})
		_mark("rays", at, .6, {"color": tint, "size": g})
		if host.use_shader_fx:host.shader_fx.shock(at, 70 * g, .5, tint)
		p.burst(at, tint.lightened(.5), int(10 * g), 120, -PI * .5, "mote", true)
	if r >= 4:
		_mark("sigil", at, .9, {"color": tint, "size": g})
		if host.use_shader_fx:host.shader_fx.shock(at, 110 * g, .7, Color("ff4f6d"))
		host.add_effect("hero_shock", at, Color("ff6a86"), 90 * g, .6)
		host.camera.impact(3, at)

## A combat event (CombatPresentation passes "item_proc" and "item_fx").
func event(e: Dictionary) -> void:
	var m: Dictionary = e.metadata;var item: String = str(m.get("item", ""));var at: Vector2 = e.point
	var targets: Array = m.get("to") if m.get("to") is Array else []
	if String(e.kind) == "item_proc":
		pops = pops.filter(func(q):return not (int(q.actor) == int(m.get("actor_id", -1)) and q.item == item))
		pops.append({"actor": int(m.get("actor_id", -1)), "item": item, "age": 0.0, "point": at})
		# The bearer flashes in the grade colour as the icon rises.
		var r: int = rank(item)
		if r >= 1:host.add_effect("slime_ring", at, grade_color(item), 26 * GRADE_SCALE[r], .35)
		return
	var limited: bool = item in LIMITED or item in BuildItemFx.LIMITED
	if limited:
		if host.real_age - float(recent.get(item, -9.0)) < LIMIT_GAP:return
		recent[item] = host.real_age
	var p = host.particles;var shader: bool = host.use_shader_fx;var g: float = gscale(item)
	if not m.get("trail", false):_grade_burst(item, at, limited)
	if BuildItemFx.event(self, item, m, at, targets, g):return
	match item:
		# ---- 희귀 ----
		"sniperScope":_mark("crosshair", at, .5, {"size": g, "color": Color("ff5a5a")})
		"vampireFang", "bloodChalice":
			var to: Vector2 = CharacterPersistence.vector(m.get("to", {}), at)
			var col: Color = Color("ff4a5e") if item == "vampireFang" else Color("c0102e")
			_mark("orb", at, .5, {"to": to, "color": col, "size": 6.0 * g, "trail": true})
			p.burst(at, col, int(5 * g), 120, -PI * .5, "spark", false)
		"hunterShuriken":
			_mark("speed", at, .6, {"actor": int(m.actor_id), "size": g});p.burst(at, Color("ffe066"), int(10 * g), 260, 0, "spark", true)
		"thornArmor":
			_mark("thorns", at, .45, {"to": CharacterPersistence.vector(m.get("to", {}), at), "size": g});p.burst(at, Color("b48a4a"), int(8 * g), 200, 0, "shard", true)
		"firstStrikeRing":
			host.add_effect("hero_shock", at, Color("fff6d8"), 90 * g, .45);_mark("star", at, .5, {"color": Color("fff6d8"), "size": g})
			p.burst(at, Color.WHITE, int(18 * g), 340, 0, "spark", true);host.camera.impact(3, at)
		"bleedBlade":p.burst(at, Color("e5525e"), int(14 * g), 200, PI * .5, "spark", true);_mark("slash", at, .35, {"color": Color("ff4a5e"), "size": g})
		"lifeChalice":
			_mark("icon", CharacterPersistence.vector(m.get("from", {}), at) + Vector2(0, -60), .8, {"icon": "lifeChalice", "size": 26 * g})
			host.add_effect("shield_hit", at, Color("ffe08a"), 44 * g);p.burst(at, Color("ffe08a"), int(10 * g), 140, -PI * .5, "heal", true)
		"guardFeather":
			host.add_effect("shield_hit", at, Color("dfe8ff"), 60 * g);_mark("dome", at, .8, {"color": Color("dfe8ff"), "size": g})
			p.burst(at, Color("f4f6ff"), int(18 * g), 200, -PI * .5, "mote", true)
		"poisonDagger":p.burst(at, Color("8fe36b"), int(8 * g), 120, -PI * .5, "mote", false);host.add_effect("slime_ring", at, Color("8fe36b"), 30 * g, .4)
		"duelistGlove":
			var stacks: int = int(m.get("stacks", 1))
			_mark("pips", at, .45, {"count": stacks, "color": Color("ff9a5a"), "size": g})
		"vanguardShield":_mark("dome", at, .4, {"color": Color("7fb8ff"), "size": g * .8})
		"elementTome":_mark("rune", at, .45, {"color": Color("c9a2ff"), "size": g})
		# ---- 영웅 ----
		"enchantedBlade":
			var col: Color = ELEMENT_COLORS.get(str(m.get("element", "fire")), Color("ff8a3d"))
			_mark("slash", at, .35, {"color": col, "size": g});p.burst(at, col, int(8 * g), 220, 0, "spark", false)
		"overchargeCore":
			_mark("charge", at, .8, {"color": Color("b884ff"), "size": g});p.burst(at, Color("d9c2ff"), int(16 * g), 200, -PI * .5, "mote", true)
		"chainRing":
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				_mark("link", at, .45, {"to": hit, "size": g});p.burst(hit, Color("ffd27a"), int(10 * g), 260, (hit - at).angle(), "spark", true)
		"echoStaff":
			if m.has("from"):_mark("echo", CharacterPersistence.vector(m.from, at), .45, {"to": at, "size": g})
			host.add_effect("slime_ring", at, Color("c49dff"), 46 * g, .5);p.burst(at, Color("e6d6ff"), int(10 * g), 180, 0, "spark", true)
		"executionScythe":
			_mark("scythe", at, .8, {"size": g});host.add_effect("hero_shock", at, Color("d7c6ff"), 100 * g, .55);host.camera.impact(8, at)
			p.burst(at, Color("efe6ff"), int(20 * g), 320, 0, "shard", true);host.impact_pause(60)
		"counterShield":
			if m.get("strike", false):_mark("shield_flash", at, .55, {"size": g});host.camera.impact(4, at)
			else:_mark("shield_spark", at, .7, {"actor": int(m.actor_id), "size": g})
		"rageHorn":
			host.add_effect("hero_shock", at, Color("ff5a5a"), 80 * g, .5);p.burst(at, Color("ff6a6a"), int(16 * g), 180, -PI * .5, "heal", true)
			_mark("horns", at, .7, {"size": g})
		"steelGreatsword":
			host.add_effect("hero_shock", at, Color("dfe6f0"), 110 * g, .5);p.burst(at, Color("eef3fa"), int(18 * g), 320, 0, "shard", true);host.camera.impact(6, at)
			if shader:host.shader_fx.shock(at, 90 * g, .4, Color("dfe6f0"))
		"piercingAwl":
			_mark("pierce", at, .4, {"size": g, "angle": float(m.get("angle", 0))});p.burst(at, Color("eef3fa"), int(6 * g), 240, float(m.get("angle", 0)), "shard", false)
		"guardChain":
			if m.has("amount"):host.number("status", at, float(m.amount), Color("a9a6b4"), -100 - int(m.actor_id))
			else:_mark("chain", at, .5, {"to": CharacterPersistence.vector(m.get("to", {}), at), "size": g})
		"weakEye":_mark("crosshair", at, .6, {"size": g * 1.2, "color": Color("ff3a4a")});_mark("eye", at, .6, {"size": g})
		"elementStone":
			var col: Color = ELEMENT_COLORS.get(str(m.get("element", "fire")), Color("ffb46a"));var rad: float = float(m.get("radius", 100))
			host.add_effect("fireball", at, col, rad * .8, .8, 0);host.camera.impact(6, at)
			if shader:host.shader_fx.shock(at, rad * 1.3, .5, col)
			p.burst(at, col, int(24 * g), rad * 3, 0, "shard", true)
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				p.burst(hit, col, int(8 * g), 160, 0, "spark", true);_mark("shard", at, .4, {"to": hit, "color": col})
		"swiftCloak":_mark("swirl", at, .5, {"size": g});p.burst(at, Color("c8f8ff"), int(10 * g), 200, 0, "spark", false)
		# ---- 전설 ----
		"phoenixFeather":
			host.add_effect("fireball", at, Color("ff9a3d"), 60 * g, .9, 0);_mark("wings", at, 1.1, {"size": g})
			p.burst(at, Color("ffd36b"), int(30 * g), 300, -PI * .5, "flame", true);host.camera.impact(8, at)
		"hourglass":_mark("icon", at + Vector2(0, -70), .9, {"icon": "hourglass", "size": 30 * g});p.burst(at, Color("ffe08a"), int(14 * g), 120, -PI * .5, "mote", true)
		"dragonHeart":
			var rad: float = float(m.get("radius", 130));_mark("flames", at, .7, {"radius": rad})
			p.burst(at, Color("ff7a3a"), int(16 * g), rad * 2.2, 0, "flame", true)
		"sovereignSword":
			_mark("crown_wave", at, .9, {"radius": float(m.get("radius", 200))});p.burst(at, Color("ffe08a"), int(22 * g), 300, -PI * .5, "spark", true)
		"giantHeart":
			host.add_effect("hero_shock", at, Color("ff8a6a"), 70 * g, .45);_mark("text", at, .7, {"text": "면역", "color": Color("ffc9a8")})
			p.burst(at + Vector2(0, 20), Color("8a7a6a"), int(10 * g), 120, 0, "smoke", true);host.camera.impact(3, at)
		"sanctuaryLamp":
			var from: Vector2 = CharacterPersistence.vector(m.get("from", {}), at)
			_mark("beam", from, .4, {"to": at, "color": Color("fff0b0")});host.add_effect("shield_hit", at, Color("fff0b0"), 34)
		"stormCrown":
			_mark("cloud", at, 1.2, {"size": g})
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				if shader:host.shader_fx.bolt(hit + Vector2(0, -240), hit)
				_mark("bolt", hit, .45, {"size": g})
				host.add_effect("hero_shock", hit, Color("bfe9ff"), 60 * g, .4);p.burst(hit, Color("dff4ff"), int(14 * g), 260, 0, "spark", true)
			host.camera.impact(9, at)
		"infinityEdge":
			_mark("blade", at, .45, {"size": g});_boost_number(at, "big");p.burst(at, Color("ffd54a"), int(14 * g), 320, 0, "spark", true)
		"skyBowstring":
			var n: int = int(m.get("count", 1))
			_mark("pierce", at, .45, {"size": g * (1 + n * .15), "angle": float(m.get("angle", 0)), "color": Color("bfe9ff")})
			host.add_effect("slime_ring", at, Color("bfe9ff"), (26 + n * 8) * g, .35);p.burst(at, Color("e8f8ff"), int((8 + n * 3) * g), 260, float(m.get("angle", 0)), "spark", true)
		"oblivionVeil":
			if m.get("cloak", false):
				p.burst(at, Color("2a2238"), int(24 * g), 90, 0, "smoke", true);_mark("veil", at, .8, {"size": g})
			else:
				host.add_effect("hero_shock", at, Color("b48cff"), 90 * g, .45);_mark("tear", at, .55, {"size": g});p.burst(at, Color("efd9ff"), int(20 * g), 320, 0, "shard", true);host.camera.impact(6, at)
		"elderHeart":p.burst(at + Vector2(0, 16), Color("87d65f"), int(6 * g), 80, -PI * .5, "heal", false);_mark("leaves", at, .9, {"size": g})
		"lifeResonance":
			var rad: float = float(m.get("radius", 150))
			host.add_effect("hero_shock", at, Color("8fe36b"), rad * 1.3, .9);_mark("bloom", at, 1.0, {"radius": rad})
			if shader:host.shader_fx.shock(at, rad * 1.2, .6, Color("8fe36b"))
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				p.burst(hit, Color("b9f08f"), int(12 * g), 120, -PI * .5, "heal", true);host.add_effect("slime_ring", hit, Color("b9f08f"), 40, .5)
		"eternalArmor":_mark("armor", at, .6, {"size": g});_boost_number(at, "cracked");p.burst(at, Color("ffd54a"), int(14 * g), 240, 0, "shard", true);host.camera.impact(4, at)
		"warDrum":
			for i in range(3):_mark("beat", at, .9, {"delay": i * .18, "size": g})
			p.burst(at, Color("ffd08a"), int(20 * g), 260, 0, "spark", true);host.camera.impact(5, at)
		"frostCrown":
			var col: Color = ELEMENT_COLORS.get(str(m.get("element", "ice")), Color("e2f6ff"))
			_mark("crown_mark", at, .6, {"color": col});p.burst(at, col, int(12 * g), 220, 0, "shard", true);host.add_effect("slime_ring", at, col, 40 * g, .45)
		# ---- 고대 ----
		"twinMirror":_mark("ripple", at, .9, {"size": g});p.burst(at, Color("dfe8ff"), int(24 * g), 220, 0, "mote", true)
		"mangoSeed":
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				_mark("mango", hit, 1.0, {"size": g, "shield": m.get("shield", false)})
				if m.get("shield", false):host.add_effect("shield_hit", hit, Color("ffd36b"), 50)
		"cursedCrown":
			_mark("icon", at + Vector2(0, -70), 1.2, {"icon": "cursedCrown", "size": 34 * g})
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				_mark("beam", at, .9, {"to": hit, "color": Color("ffd36b")});_mark("crown_mark", hit, 1.0, {"color": Color("ffd36b")})
				p.burst(hit, Color("ffe08a"), int(8 * g), 140, -PI * .5, "mote", true)
		"rewindClock":
			var path: Array = []
			for q in m.get("path", []):path.append(CharacterPersistence.vector(q, at))
			_mark("rewind", at, 1.1, {"path": path, "size": g});p.burst(at, Color("d0b8ff"), int(24 * g), 220, 0, "mote", true);host.impact_pause(90);host.camera.impact(8, at)
		"invertedHourglass":_mark("icon", at + Vector2(0, -74), 1.0, {"icon": "invertedHourglass", "size": 34 * g, "flip": true});p.burst(at, Color("eec45e"), int(18 * g), 120, -PI * .5, "mote", true)
		"greedPouch":
			for i in range(5):_mark("coin", at + Vector2((i - 2) * 9, 0), .8, {"delay": i * .05, "size": g})
			p.burst(at, Color("ffd54a"), int(12 * g), 200, -PI * .5, "spark", true)
		"overdriveEngine":
			var lv: int = int(m.get("level", 1));var col: Color = Color("ffd08a").lerp(Color("ff4a2a"), lv / 3.0)
			host.add_effect("hero_shock", at, col, (50 + lv * 20) * g, .55);p.burst(at, col, int((12 + lv * 6) * g), 200, -PI * .5, "flame", true)
			_mark("text", at, .9, {"text": "폭주 +%d%%" % (lv * 30), "color": col});host.camera.impact(2 + lv, at)
		"mimicMask":
			host.add_effect("hero_shock", at, Color("c49dff"), 110 * g, .6);_mark("icon", at + Vector2(0, -70), .9, {"icon": "mimicMask", "size": 34 * g})
			_mark("ripple", at, .8, {"size": g * 1.4});host.camera.impact(6, at)
		"soulReaper":
			_mark("orb", at, .8, {"to": CharacterPersistence.vector(m.get("to", {}), at), "color": Color("b9d8ff"), "size": 8.0, "trail": true})
			p.burst(at, Color("cfe2ff"), int(16 * g), 140, -PI * .5, "mote", true)
		"starShard":
			for to in targets:_mark("meteor", CharacterPersistence.vector(to, at), .8, {"radius": float(m.get("radius", 70)) * 1.2, "size": g})
		"shadowDoll":
			_mark("thread", CharacterPersistence.vector(m.get("from", {}), at), .5, {"to": at});p.burst(at, Color("6a3a8a"), int(10 * g), 120, 0, "smoke", false)
			host.add_effect("slime_ring", at, Color("b48cd8"), 36 * g, .4)
		"commanderScepter":
			_mark("banner", at, 1.4, {"color": Color("b884ff")});p.burst(at, Color("d9c2ff"), int(16 * g), 160, -PI * .5, "mote", true)
		"gamblerDice":
			var stat: String = STAT_NAMES.get(str(m.get("stat", "")), "")
			_mark("dice", at, 1.3, {"size": g})
			if stat != "":_mark("text", at, 1.6, {"text": "%s +%d%%" % [stat, roundi(float(m.get("roll", 0)) * 100)], "color": Color("ffd27a"), "delay": .5})
			p.burst(at, Color("ff6a86"), int(14 * g), 200, -PI * .5, "spark", true)
		"berserkerHelm":
			host.add_effect("hero_shock", at, Color("ff4a3a"), 70 * g, .5);_mark("text", at, .8, {"text": "광전", "color": Color("ff7a6a")})
			p.burst(at, Color("ff5a4a"), int(16 * g), 220, -PI * .5, "flame", true)
		"warmNecklace+verdantStone":
			var rad: float = float(m.get("radius", 165));_mark("ring_fill", at, .7, {"radius": rad, "color": Color("77edb4")})
			p.burst(at, Color("9ff5c4"), int(12 * g), 120, -PI * .5, "heal", true)
		"currentOrb+ether":
			var rad: float = float(m.get("radius", 165));_mark("ring_fill", at, .7, {"radius": rad, "color": Color("b884ff")})
			p.burst(at, Color("d9c2ff"), int(12 * g), 140, -PI * .5, "mote", true)
		"woodSword+redThorn":_mark("fang", at, .8, {"size": g});p.burst(at, Color("ff6a5a"), int(12 * g), 200, -PI * .5, "spark", true)
		"woodSword+hawkFeather":p.burst(at, Color("eef3fa"), int(10 * g), 260, 0, "spark", true);host.add_effect("slime_ring", at, Color("5fb0ff"), 40 * g, .4)

## Marks the newest damage number at a point (무한의 칼날 makes it bigger, 영겁의 갑주 cracks it).
func _boost_number(at: Vector2, flag: String) -> void:
	for i in range(host.numbers.size() - 1, -1, -1):
		var n: Dictionary = host.numbers[i]
		if float(n.age) < .3 and n.kind in ["damage", "critical"] and Vector2(n.point).distance_to(at) < 40:n[flag] = true;return

## The ground layer: a slow sigil in the grade colour under units wearing 전설 / 고대 items.
func draw_ground(c: CanvasItem) -> void:
	var t: float = host.real_age
	for u in host.battle.units:
		if not u.alive or u.combat_stats == null or u.combat_stats.items.is_empty():continue
		var best: int = 0;var item: String = ""
		for it in u.combat_stats.items:
			var r: int = ItemCatalog.grade_rank(it.kind)
			if r > best:best = r;item = String(it.kind)
		if best < 3:continue
		var s: float = u.combat_scale();var col: Color = grade_color(item);var rad: float = (36 if best == 3 else 42) * s
		var squash := Transform2D(0, Vector2(1, .42), 0, u.position + Vector2(0, 18 * s))
		c.draw_set_transform_matrix(host.parent_transform * squash)
		c.draw_arc(Vector2.ZERO, rad, 0, TAU, 40, Color(col, .45), 2.5, true)
		for k in range(6 if best == 3 else 8):
			var a: float = t * (.6 if best == 3 else -.8) + k * TAU / (6 if best == 3 else 8)
			c.draw_arc(Vector2.ZERO, rad * .82, a, a + .45, 6, Color(col.lightened(.3), .55), 2, true)
		if best == 4:c.draw_arc(Vector2.ZERO, rad * 1.18, t * .5, t * .5 + TAU * .7, 32, Color(col, .3), 1.5, true)
		c.draw_set_transform_matrix(host.parent_transform)
	BuildItemFx.draw_ground(self, c)

## Looks that last while the item's condition holds, drawn with the unit (p: body centre, s: scale).
func draw_unit(c: CanvasItem, u: BattleUnit, p: Vector2, s: float) -> void:
	if not u.alive:return
	var t: float = host.real_age;var stats: UnitCombatStats = u.combat_stats
	if u.character_specific_state.has("mirrorOf") and not u.character_specific_state.has("spiritOf"):
		c.draw_arc(p, 32 * s, 0, TAU, 32, Color("e8eef8", .65 + .25 * sin(t * 3)), 3, true);VfxArt.glow(c, p, 40 * s, Color("dfe8ff"), .18)
	# Team auras: 왕의 왕관 (gold crown light), 전쟁의 북 (beat rings), 약점 노출 (red reticle).
	if ItemEffects.king_blessed(u):
		VfxArt.glow(c, p + Vector2(0, -52 * s), 12 * s, Color("ffd36b"), .55);_crown(c, p + Vector2(0, -52 * s), 7 * s, Color("ffd36b"))
	if ItemEffects.drummed(u):
		var beat: float = fposmod(t, .6) / .6;c.draw_arc(p, (28 + beat * 22) * s, 0, TAU, 28, Color("ffb36b", .5 * (1 - beat)), 2.5, true)
	if u.state_value("weakTime") > 0:
		for k in range(2):
			var a: float = t * 2 + k * PI;c.draw_arc(p, 26 * s, a, a + 1.2, 10, Color("ff3a4a", .9), 3, true)
		c.draw_line(p + Vector2(0, -34) * s, p + Vector2(0, -20) * s, Color("ff3a4a", .8), 2, true)
	BuildItemFx.draw_unit(self, c, u, p, s)
	if stats == null or stats.effects.is_empty():return
	var head: Vector2 = p + Vector2(0, -44 * s)
	if stats.has(&"berserkerHelm") and ItemEffects.berserk(u):
		var pulse: float = .5 + .5 * sin(t * 8)
		c.draw_arc(p, 32 * s, 0, TAU, 32, Color("ff4a3a", .5 + .4 * pulse), 3.5, true);VfxArt.glow(c, p, 42 * s, Color("ff3a2a"), .2 + .15 * pulse)
		for k in range(4):
			var rise: float = fposmod(t * .9 + k * .25, 1.0)
			VfxArt.glow(c, head + Vector2((k - 1.5) * 8 * s, -rise * 26 * s), 11 * s, Color("ff6a5a"), .45 * (1 - rise))
	if stats.has(&"rageHorn") and u.stance == CombatStance.RUSH:
		VfxArt.glow(c, head, 18 * s, Color("ff4a4a"), .35)
		for side in [-1, 1]:
			c.draw_colored_polygon(PackedVector2Array([head + Vector2(side * 8, 4) * s, head + Vector2(side * 22, -18) * s, head + Vector2(side * 3, 0) * s]), Color("ff4a4a", .9))
	if stats.has(&"oblivionVeil") and u.state_value("shadowTime") > 0:
		VfxArt.glow(c, p, 48 * s, Color("1a1428"), .6)
		for k in range(5):
			var a: float = t * 1.2 + k * TAU / 5;c.draw_arc(p, 34 * s, a, a + .6, 6, Color("b48cff", .5), 2, true)
	if stats.has(&"overdriveEngine"):
		var heat: float = clampf(u.state_value("overdrive") / 30.0, 0, 1)
		var speed: float = 1 + minf(30, u.state_value("overdrive")) * .3;var at: Vector2 = p + Vector2(28, -22) * s
		var col: Color = Color("c9d2de").lerp(Color("ff6a3d"), heat)
		for k in range(8):
			var a: float = t * speed + k * TAU / 8
			c.draw_line(at + Vector2.from_angle(a) * 6 * s, at + Vector2.from_angle(a) * 12 * s, col, 3, true)
		c.draw_circle(at, 6 * s, col.darkened(.3))
		if heat > .3:VfxArt.glow(c, p, 40 * s, Color("ff6a3d"), .3 * heat)
	if u.state_value("rewindReady") > 0:
		var at: Vector2 = head + Vector2(0, -18 * s)
		VfxArt.glow(c, at, 14 * s, Color("d0b8ff"), .35);c.draw_arc(at, 10 * s, 0, TAU, 24, Color("d0b8ff", .9), 2, true)
		c.draw_line(at, at + Vector2.from_angle(-t * 3) * 8 * s, Color("efe2ff"), 2, true)
	if stats.has(&"mangoSeed"):
		var at: Vector2 = head + Vector2(20, 0) * s
		VfxArt.glow(c, at + Vector2(0, -12) * s, 9 * s, Color("ffc34a"), .45)
		c.draw_line(at, at + Vector2(0, -8) * s, Color("87b65f"), 2.5, true);c.draw_circle(at + Vector2(0, -12) * s, 5 * s, Color("ffc34a"))
	if stats.has(&"elderHeart"):
		for k in range(3):
			var a: float = t * .7 + k * TAU / 3;c.draw_circle(p + Vector2.from_angle(a) * 30 * s, 3.5 * s, Color("87d65f", .8))
	if u.state_value("regenTime") > 0:
		VfxArt.glow(c, p, 44 * s, Color("77edb4"), .35 + .15 * sin(t * 10));c.draw_arc(p, 34 * s, 0, TAU, 32, Color("b6ffd8", .7), 2.5, true)
	if stats.has(&"stormCrown"):
		for k in range(3):VfxArt.glow(c, head + Vector2((k - 1) * 9, -12 + sin(t * 2 + k) * 2) * s, 11 * s, Color("4a5670"), .55)
		if fposmod(t, 1.7) < .08:c.draw_line(head + Vector2(0, -12) * s, head + Vector2(4, 4) * s, Color("dff4ff"), 2, true)
	if stats.has(&"frostCrown"):
		var col: Color = Color("ffb46a").lerp(Color("bfeaff"), .5 + .5 * sin(t * 2))
		VfxArt.glow(c, head + Vector2(0, -8 * s), 14 * s, col, .55);_crown(c, head + Vector2(0, -8 * s), 7 * s, col)
	if stats.has(&"soulReaper") and u.state_value("soulStacks") > 0:
		for k in range(mini(8, int(u.state_value("soulStacks")))):
			var a: float = t * 1.5 + k * TAU / 8;VfxArt.glow(c, p + Vector2.from_angle(a) * 30 * s, 7 * s, Color("b9d8ff"), .65)
	if stats.has(&"guardChain"):
		var ward = host.battle.units.filter(func(a):return a != u and a.alive and a.team == u.team and not a.character_specific_state.has("mirrorOf"))
		if not ward.is_empty():
			ward.sort_custom(func(x, y):return x.position.distance_to(p) < y.position.distance_to(p))
			_chain(c, p, ward[0].position, .45, 1.0)
	if stats.has(&"sanctuaryLamp"):
		VfxArt.glow(c, head + Vector2(16, 6) * s, 10 * s, Color("fff0b0"), .5 + .2 * sin(t * 3))
		c.draw_arc(p, ItemTuning.SANCTUARY_RADIUS * s, 0, TAU, 48, Color("fff0b0", .12), 2, true)
	if u.state_value("counterCritUntil") > host.battle.clock.elapsed:
		VfxArt.glow(c, p + Vector2(-24, -20) * s, 12 * s, Color("bfe9ff"), .7 + .3 * sin(t * 12));ArenaIcon.draw(c, p + Vector2(-24, -20) * s, "counterShield", 16 * s, Color.WHITE)
	var ready: bool = u.state_value("firstStrike") > 0 or stats.has(&"steelGreatsword") and u.state_value("smashCount") >= ItemTuning.GREATSWORD_EVERY - 1
	if ready:VfxArt.glow(c, p + Vector2.from_angle(u.facing) * 32 * s, 13 * s, Color("fff3c8"), .6 + .3 * sin(t * 10))

func _crown(c: CanvasItem, at: Vector2, r: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-r, r * .6), at + Vector2(-r, -r * .4), at + Vector2(-r * .5, r * .1), at + Vector2(0, -r * .7), at + Vector2(r * .5, r * .1), at + Vector2(r, -r * .4), at + Vector2(r, r * .6)]), col)
func _chain(c: CanvasItem, a: Vector2, b: Vector2, alpha: float, size: float) -> void:
	var n: int = maxi(2, int(a.distance_to(b) / 12))
	for i in range(n):
		var q: Vector2 = a.lerp(b, (i + .5) / n)
		c.draw_arc(q, 4.5 * size, 0, TAU, 8, Color("ffd27a", alpha), 2.5, true)

## Short effects and the rising item icons, above everything on the field.
func draw_over(c: CanvasItem) -> void:
	# 천공의 활시위: shots that pierced glow brighter and leave a longer tail.
	for pr in host.battle.projectiles:
		if not pr.live or int(pr.metadata.get("pierced", 0)) <= 0:continue
		var n: int = int(pr.metadata.pierced);var back: Vector2 = pr.position - pr.velocity.normalized() * (30 + 22 * n)
		VfxArt.glow(c, pr.position, 14 + 6 * n, Color("bfe9ff"), .3 + .1 * n);c.draw_line(back, pr.position, Color("e8f8ff", .45 + .1 * n), 2 + n, true)
	BuildItemFx.draw_over(self, c)
	for m in marks:
		var age: float = float(m.age) - float(m.get("delay", 0))
		if age < 0:continue
		var k: float = clampf(age / maxf(.01, float(m.life) - float(m.get("delay", 0))), 0, 1);var at: Vector2 = m.point;var fade: float = 1 - k
		var g: float = float(m.get("size", 1.0))
		match m.kind:
			"pillar":
				# 전설+: a column of light over the bearer.
				var w: float = 18 * g * (1 - k * .5);var h: float = 160 * g
				c.draw_rect(Rect2(at + Vector2(-w * .5, -h), Vector2(w, h)), Color(m.color.lightened(.4), .35 * fade))
				c.draw_rect(Rect2(at + Vector2(-w * .2, -h), Vector2(w * .4, h)), Color(1, 1, 1, .45 * fade))
				VfxArt.glow(c, at, 50 * g, m.color, .45 * fade)
			"rays":
				for i in range(10):
					var a: float = i * TAU / 10 + k * .6;var r0: float = 22 * g;var r1: float = r0 + 70 * g * Motion.out_quint(k)
					c.draw_line(at + Vector2.from_angle(a) * r0, at + Vector2.from_angle(a) * r1, Color(m.color.lightened(.4), .8 * fade), 3, true)
			"sigil":
				# 고대: a turning rune circle.
				var r: float = 40 * g * (.6 + .4 * Motion.out_quint(k))
				c.draw_arc(at, r, 0, TAU, 48, Color(m.color, fade), 3, true);c.draw_arc(at, r * .78, 0, TAU, 40, Color(m.color.lightened(.3), .8 * fade), 1.5, true)
				for i in range(6):
					var a: float = i * TAU / 6 + k * 2.5;var q: Vector2 = at + Vector2.from_angle(a) * r * .89
					c.draw_colored_polygon(PackedVector2Array([q + Vector2.from_angle(a) * 6, q + Vector2.from_angle(a + 2.1) * 6, q + Vector2.from_angle(a - 2.1) * 6]), Color(m.color.lightened(.5), fade))
				var tri: PackedVector2Array = PackedVector2Array()
				for i in range(4):tri.append(at + Vector2.from_angle(-k * 1.5 + i * TAU / 3 - PI * .5) * r * .7)
				c.draw_polyline(tri, Color(m.color, .7 * fade), 2, true)
			"crosshair":
				var r: float = 16 * g;var col: Color = m.get("color", Color("ff5a5a"))
				c.draw_arc(at, r * (1.4 - .4 * Motion.out_quint(k)), 0, TAU, 24, Color(col, fade), 2.5, true)
				for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:c.draw_line(at + d * r * .5, at + d * r * 1.5, Color(col, fade), 2.5, true)
			"eye":
				var q: Vector2 = at + Vector2(0, -48 * g * .6)
				c.draw_colored_polygon(PackedVector2Array([q + Vector2(-14, 0) * g * .6, q + Vector2(0, -7) * g * .6, q + Vector2(14, 0) * g * .6, q + Vector2(0, 7) * g * .6]), Color(1, .95, .9, fade))
				c.draw_circle(q, 4 * g * .6, Color("ff3a4a", fade))
			"orb":
				var to: Vector2 = m.to;var q: Vector2 = at.lerp(to, Motion.out_quint(k)) + Vector2(0, -40 * sin(k * PI))
				if m.get("trail", false):
					for j in range(4):
						var kk: float = maxf(0, k - j * .06);var qq: Vector2 = at.lerp(to, Motion.out_quint(kk)) + Vector2(0, -40 * sin(kk * PI))
						c.draw_circle(qq, float(m.size) * (1 - j * .2), Color(m.color, fade * (.7 - j * .15)))
				c.draw_circle(q, float(m.size), Color(m.color, fade));VfxArt.glow(c, q, float(m.size) * 3, m.color, .45 * fade)
			"speed":
				var u = host.battle.find_unit(int(m.actor))
				if u != null:
					for i in range(6):c.draw_line(u.position + Vector2(-34 - i * 6, -18 + i * 7) * g * .8, u.position + Vector2(-12 - i * 6, -18 + i * 7) * g * .8, Color("ffe066", fade), 3, true)
			"thorns":
				var dir: Vector2 = (Vector2(m.to) - at).normalized()
				for i in range(7):
					var a: Vector2 = at + dir.rotated((i - 3) * .3) * 22;c.draw_line(a, a + dir.rotated((i - 3) * .3) * (14 + 14 * (1 - k)) * g, Color("a87a3a", fade), 4, true)
			"star":
				for i in range(4):
					var a: float = i * PI * .5 + k;c.draw_line(at - Vector2.from_angle(a) * 50 * g * fade, at + Vector2.from_angle(a) * 50 * g * fade, Color(m.color, fade), 3, true)
			"slash":
				var a: float = -.7 + k * .3;c.draw_line(at + Vector2.from_angle(a + PI) * 30 * g, at + Vector2.from_angle(a) * 30 * g, Color(m.color, fade), 5 * fade + 1, true)
			"dome":
				c.draw_arc(at, 34 * g, PI, TAU, 28, Color(m.color, .9 * fade), 3, true);VfxArt.glow(c, at, 40 * g, m.color, .35 * fade)
			"pips":
				for i in range(int(m.count)):c.draw_circle(at + Vector2((i - (int(m.count) - 1) * .5) * 9, -40), 3.5, Color(m.color, fade))
			"rune":
				c.draw_arc(at, (16 + 10 * k) * g, 0, TAU, 6, Color(m.color, fade), 2.5, true);c.draw_arc(at, 9 * g, k * 4, k * 4 + PI, 6, Color(m.color, fade), 2, true)
			"charge":
				for i in range(3):c.draw_arc(at, (30 - i * 8) * g * (1 - k), 0, TAU, 28, Color(m.color.lightened(.2 * i), fade), 2.5, true)
			"link":
				var to: Vector2 = m.to;c.draw_line(at, at.lerp(to, minf(1, k * 3)), Color("ffd27a", fade), 4 * g * .6, true);_chain(c, at, at.lerp(to, minf(1, k * 3)), fade, g * .7)
			"icon":ArenaIcon.draw(c, at + Vector2(0, -14 * k), str(m.icon), float(m.size) * (1 + .15 * sin(k * PI)), Color(1, 1, 1, fade))
			"echo":
				c.draw_line(at, Vector2(m.to), Color("c49dff", .7 * fade), 4, true);c.draw_circle(Vector2(m.to), (8 * fade + 3) * g * .7, Color("e6d6ff", fade))
			"scythe":
				var a0: float = -2.4 + 2.6 * Motion.out_quint(k)
				c.draw_arc(at + Vector2(0, -10), 56 * g * .8, a0 - 1.2, a0, 22, Color("e8e2ff", .85 * fade), 9, true)
				c.draw_string(ArenaUI.heading_font(), at + Vector2(-28, -64 - 12 * k), "처형", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("ffe8ff", fade))
			"shield_flash":
				var r: float = 30 * g * .8
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -1) * r, at + Vector2(.8, -.6) * r, at + Vector2(.65, .45) * r, at + Vector2(0, 1) * r, at + Vector2(-.65, .45) * r, at + Vector2(-.8, -.6) * r]), Color("bfe9ff", .55 * fade))
			"shield_spark":
				var u = host.battle.find_unit(int(m.actor))
				if u != null:ArenaIcon.draw(c, u.position + Vector2(-26, -26), "counterShield", 22 * g * .7, Color(1, 1, 1, fade))
			"chain":_chain(c, at, Vector2(m.to), fade, g * .8)
			"horns":
				for side in [-1, 1]:c.draw_colored_polygon(PackedVector2Array([at + Vector2(side * 10, -40), at + Vector2(side * 30, -70 - 10 * k), at + Vector2(side * 4, -44)]), Color("ff4a4a", fade))
			"pierce":
				# A spike driven through the target along the attack.
				var dir: Vector2 = Vector2.from_angle(float(m.get("angle", 0)));var nrm: Vector2 = dir.orthogonal();var col: Color = m.get("color", Color("eef3fa"))
				var back: Vector2 = at - dir * 46 * g * .7;var tip: Vector2 = at + dir * (46 + 20 * k) * g * .7
				c.draw_line(back, tip, Color(col, fade), 4, true);VfxArt.glow(c, at, 18 * g, col, .4 * fade)
				c.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14 + nrm * 7, tip - dir * 14 - nrm * 7]), Color(col, fade))
			"swirl":
				for i in range(3):
					var a: float = k * 6 + i * TAU / 3;c.draw_arc(at, (24 + i * 6) * g * .7, a, a + 1.6, 12, Color("c8f8ff", .8 * fade), 3, true)
			"text":c.draw_string(ArenaUI.heading_font(), at + Vector2(-40, -78 - 18 * k), str(m.text), HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(m.color, fade))
			"crown_mark":
				var q: Vector2 = at + Vector2(0, -56 - 10 * k);VfxArt.glow(c, q, 18, m.color, .5 * fade);_crown(c, q, 10, Color(m.color, fade))
			"banner":
				var q: Vector2 = at + Vector2(0, -50 - 30 * Motion.out_quint(minf(1, k * 2)))
				c.draw_line(q + Vector2(-16, 26), q + Vector2(-16, -24), Color("e8d8b0", fade), 3, true)
				c.draw_colored_polygon(PackedVector2Array([q + Vector2(-14, -24), q + Vector2(22, -18), q + Vector2(14, -8), q + Vector2(22, 2), q + Vector2(-14, -2)]), Color(m.color, fade))
				ArenaIcon.draw(c, q + Vector2(4, -12), "commanderScepter", 16, Color(1, 1, 1, fade))
			"dice":
				for i in range(2):
					var q: Vector2 = at + Vector2((i - .5) * 34, -70 + 20 * absf(sin(k * 9 + i))) * g * .6;var r: float = 12 * g * .6
					var a: float = k * 10 * (1 - k) + i
					var box: PackedVector2Array = PackedVector2Array()
					for j in range(5):box.append(q + Vector2.from_angle(a + j * PI * .5 + PI * .25) * r * 1.41)
					c.draw_colored_polygon(box.slice(0, 4), Color("f4f1ea", fade) if i == 0 else Color("e5525e", fade));c.draw_polyline(box, Color("2b2230", fade), 2, true)
			"ring_fill":
				c.draw_circle(at, float(m.radius) * Motion.out_quint(k), Color(m.color, .14 * fade));c.draw_arc(at, float(m.radius) * Motion.out_quint(k), 0, TAU, 48, Color(m.color, .8 * fade), 3, true)
			"fang":
				for side in [-1, 1]:c.draw_colored_polygon(PackedVector2Array([at + Vector2(side * 6, -70), at + Vector2(side * 16, -70), at + Vector2(side * 9, -48 + 6 * k)]), Color("fff4ea", fade))
				VfxArt.glow(c, at + Vector2(0, -60), 20, Color("ff5a4a"), .45 * fade)
			"shard":c.draw_line(at.lerp(Vector2(m.to), k * .7), at.lerp(Vector2(m.to), minf(1, k * .7 + .25)), Color(m.color, fade), 4, true)
			"cloud":
				for i in range(4):VfxArt.glow(c, at + Vector2((i - 1.5) * 20, -80) * g * .7, 28 * g * .7, Color("2e3446"), .75 * fade)
			"bolt":VisualShapes.bolt(c, at + Vector2(0, -220), at, Color("dff4ff", fade), int(m.age * 30), 4)
			"blade":
				c.draw_line(at + Vector2(-44, 30) * g * .7, at + Vector2(44, -30) * g * .7, Color("ffd54a", fade), 7 * fade + 2, true)
				c.draw_line(at + Vector2(-44, -30) * g * .7, at + Vector2(44, 30) * g * .7, Color("fff3c8", .7 * fade), 3, true)
			"veil":
				for i in range(3):c.draw_arc(at, (30 + i * 12) * g * .7 * (1 - k * .3), k * 3 + i, k * 3 + i + 2, 14, Color("2a2238", .8 * fade), 4, true)
			"tear":
				for i in range(4):c.draw_line(at + Vector2(-27 + i * 16, -32) * g * .7, at + Vector2(-19 + i * 16, 32) * g * .7, Color("efd9ff", fade), 4, true)
			"armor":
				c.draw_arc(at, 40 * g * .7, 0, TAU, 6, Color("ffd54a", fade), 5, true);VfxArt.glow(c, at, 50 * g * .7, Color("ffd54a"), .45 * fade)
			"wings":
				for side in [-1, 1]:
					var tip: Vector2 = at + Vector2(side * 70, -40 - 20 * k) * g * .6
					c.draw_colored_polygon(PackedVector2Array([at + Vector2(side * 8, -10), tip, at + Vector2(side * 40, 10) * g * .6]), Color("ffb347", .7 * fade))
			"flames":
				for i in range(10):
					var a: float = i * TAU / 10;var q: Vector2 = at + Vector2.from_angle(a) * float(m.radius) * Motion.out_quint(k)
					VfxArt.glow(c, q, 18, Color("ff7a3a"), .6 * fade)
			"crown_wave":
				c.draw_arc(at, float(m.radius) * Motion.out_quint(k), 0, TAU, 48, Color("ffd36b", .9 * fade), 4, true);_crown(c, at + Vector2(0, -70 - 10 * k), 12, Color("ffd36b", fade))
			"beam":c.draw_line(at, Vector2(m.to), Color(m.color, .7 * fade), 3, true)
			"leaves":
				for i in range(4):
					var a: float = i * TAU / 4 + k * 2;c.draw_circle(at + Vector2.from_angle(a) * 26 * (1 + k), 4, Color("87d65f", fade))
			"bloom":
				var r: float = float(m.radius) * Motion.out_quint(k)
				for i in range(8):
					var a: float = i * TAU / 8;c.draw_circle(at + Vector2.from_angle(a) * r, 7 * fade + 2, Color("b9f08f", fade))
			"beat":c.draw_arc(at, 40 + 160 * Motion.out_quint(k), 0, TAU, 40, Color("ffb36b", .8 * fade), 4 * fade + 1, true)
			"ripple":
				for i in range(4):c.draw_arc(at, (14 + i * 12) * g * .7 * (.5 + k), 0, TAU, 32, Color("e8eef8", fade * (1 - i * .2)), 2.5, true)
			"mango":
				var q: Vector2 = at + Vector2(0, -90 + 70 * Motion.out_quint(minf(1, k * 1.6)))
				VfxArt.glow(c, q, 14, Color("ffc34a"), .5 * fade)
				c.draw_circle(q, 8, Color("ffb347", fade));c.draw_line(q + Vector2(0, -8), q + Vector2(4, -13), Color("4e813e", fade), 2.5, true)
				if k > .6:c.draw_arc(at, 30 * (k - .6) * 3, 0, TAU, 24, Color("ffd36b", fade), 2, true)
			"rewind":
				var path: Array = m.path
				for i in range(path.size() - 1, 0, -1):
					var w: float = clampf(k * path.size() - (path.size() - 1 - i), 0, 1)
					c.draw_line(path[i], path[i - 1], Color("d0b8ff", .8 * (1 - w) * fade + .15), 5, true)
				for i in range(12):
					var a: float = i * TAU / 12;c.draw_line(at + Vector2.from_angle(a) * 34, at + Vector2.from_angle(a) * 40, Color("d0b8ff", fade), 2, true)
				c.draw_line(at, at + Vector2.from_angle(-k * 12) * 30, Color("efe2ff", fade), 3, true)
			"coin":
				var q: Vector2 = at + Vector2(0, -24 - 40 * k);c.draw_circle(q, 6, Color("ffd54a", fade));c.draw_arc(q, 6, 0, TAU, 12, Color("b8822a", fade), 1.5, true)
			"thread":c.draw_line(at, Vector2(m.to), Color("2a0f3a", .9 * fade), 3, true);c.draw_line(at, Vector2(m.to), Color("b48cd8", .5 * fade), 1, true)
			"meteor":
				# A star falls for the first half, then bursts on the ground.
				var fall: float = minf(1, k * 2);var from: Vector2 = at + Vector2(-120, -300)
				if k < .5:
					var head: Vector2 = from.lerp(at, fall)
					c.draw_line(from.lerp(at, maxf(0, fall - .35)), head, Color("ffe6a0", .9), 7, true);VfxArt.glow(c, head, 22, Color("ffb46a"), .6);c.draw_circle(head, 9, Color("fff6d8"))
				else:
					var b: float = (k - .5) * 2
					c.draw_arc(at, float(m.radius) * (.4 + .6 * b), 0, TAU, 32, Color("ffd27a", 1 - b), 5, true);VfxArt.glow(c, at, float(m.radius) * 1.2, Color("ffb46a"), .6 * (1 - b))
			_:BuildItemFx.draw_mark(c, m, at, k, fade, g, host.real_age)
	# Rising icons over the bearers' heads: a halo in the grade colour, rays from 전설 up.
	for pop in pops:
		var u = host.battle.find_unit(int(pop.actor))
		var base: Vector2 = u.position if u != null and u.alive else Vector2(pop.point)
		var s: float = u.combat_scale() if u != null else 1.0
		var k: float = float(pop.age) / ICON_LIFE;var r: int = rank(pop.item);var g: float = GRADE_SCALE[r]
		var alpha: float = minf(1, k * 6) * (1 - maxf(0, k - .65) / .35)
		var pop_in: float = 1 + .35 * (1 - Motion.out_quint(minf(1, k * 4)))
		var at: Vector2 = base + Vector2(0, -(66 + 20 * Motion.out_quint(k)) * s)
		var ring: Color = grade_color(pop.item);var radius: float = (18 + 3 * r) * pop_in
		if r >= 3:
			for i in range(8):
				var a: float = i * TAU / 8 + k * 1.5
				c.draw_line(at + Vector2.from_angle(a) * radius * 1.1, at + Vector2.from_angle(a) * radius * 1.9, Color(ring.lightened(.3), .7 * alpha), 2.5, true)
		VfxArt.glow(c, at, radius * (1.6 + .2 * r), ring, (.25 + .08 * r) * alpha)
		c.draw_circle(at, radius, Color(.06, .07, .1, .8 * alpha))
		c.draw_arc(at, radius, 0, TAU, 28, Color(ring, alpha), 2.0 + r * .8, true)
		if r >= 4:c.draw_arc(at, radius + 5, k * 4, k * 4 + TAU * .6, 20, Color(ring.lightened(.4), alpha), 2, true)
		ArenaIcon.draw(c, at, pop.item, (26 + 3 * r) * pop_in, Color(1, 1, 1, alpha))
