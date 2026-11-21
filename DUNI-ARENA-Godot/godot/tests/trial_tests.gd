class_name TrialTests
extends RefCounted
## 시련 (0.99.16): catalog, floor rules, generation and saves, every trial's effect in battle.
var checks: int = 0
var failures: int = 0
var host: SceneTree

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;push_error("TRIAL FAIL: " + label)

func run(tree: SceneTree) -> void:
	host = tree
	catalog();rolls();generation();saves();counters();environment();empowered();rewards();ui_rules()
	print("TRIAL RESULT: %d checks; %d failures" % [checks, failures])

func catalog() -> void:
	var by_kind: Dictionary = {}
	for kind in TrialCatalog.KINDS:by_kind[kind] = TrialCatalog.of_kind(kind).size()
	verify(by_kind == {&"counter": 14, &"environment": 3, &"empower": 6, &"reward": 2}, "14 카운터, 3 환경, 6 적 강화, 2 보상 (%s)" % str(by_kind))
	verify(TrialCatalog.TRIALS.keys().all(func(id):return ArenaIcon.texture(str(TrialCatalog.info(id).icon)) != null and not TrialCatalog.info(id).text.is_empty()), "every trial has an icon and a description")
	verify(TrialCatalog.of_kind(TrialCatalog.COUNTER).all(func(id):return TrialCatalog.info(id).has("match")), "every counter names what it blocks")
	verify(TrialCatalog.KIND_COLORS[&"counter"].r > .9 and TrialCatalog.KIND_COLORS[&"counter"].g < .5 and TrialCatalog.KIND_COLORS[&"empower"].b > .9, "counter red, empower purple rims")

func rolls() -> void:
	var rng := RandomNumberGenerator.new();rng.seed = 5
	var ok_count: bool = true;var ok_counters: bool = true;var ok_broad: bool = true;var ok_boss: bool = true;var ok_reward: bool = true;var ok_unique: bool = true
	var seen_sizes: Dictionary = {}
	for floor in range(1, 16):
		for room_type in [RoomType.BATTLE, RoomType.MINIBOSS, RoomType.BOSS]:
			for i in range(120):
				var list: Array[StringName] = TrialCatalog.roll(rng, floor, room_type)
				var rule: Array = TrialCatalog.floor_rule(floor)
				ok_count = ok_count and list.size() >= int(rule[0]) and list.size() <= int(rule[1])
				seen_sizes["%d:%d" % [floor, list.size()]] = true
				var counters: int = list.filter(func(t):return TrialCatalog.kind_of(t) == TrialCatalog.COUNTER).size()
				ok_counters = ok_counters and counters <= int(rule[2]) and counters <= TrialCatalog.MAX_COUNTERS
				if floor < TrialCatalog.BROAD_COUNTER_FLOOR:ok_broad = ok_broad and not &"tough" in list and not &"seastone" in list
				ok_broad = ok_broad and not (&"tough" in list and &"seastone" in list)
				if room_type != RoomType.BATTLE:ok_boss = ok_boss and counters <= 1
				ok_reward = ok_reward and list.filter(func(t):return TrialCatalog.kind_of(t) == TrialCatalog.REWARD).size() <= 1
				var unique: Dictionary = {}
				for t in list:unique[t] = true
				ok_unique = ok_unique and unique.size() == list.size()
	verify(ok_count and seen_sizes.has("1:0") and seen_sizes.has("1:1") and seen_sizes.has("12:4") and not seen_sizes.has("12:1"), "trial counts by floor: 0-1, 1-2, 2-3, 2-4")
	verify(ok_counters, "counters: none on floors 1-3, at most 1 on 4-6, 2 later")
	verify(ok_broad, "강인함 · 해루석 보호막 from floor 7 and never together")
	verify(ok_boss and ok_reward and ok_unique, "boss rooms at most one counter; one reward trial; each trial once")
	verify(TrialCatalog.roll(rng, 10, RoomType.SHOP).is_empty() and TrialCatalog.roll(rng, 10, RoomType.REST).is_empty(), "only battle rooms get trials")

func generation() -> void:
	var a := TowerController.new();a.new_run(19, 73);var b := TowerController.new();b.new_run(19, 73)
	var rooms: Array = a.guild.state.tower.map.rooms.values()
	var same: bool = rooms.all(func(r):return r.trials == b.guild.state.tower.map.get_room(r.room_id).trials)
	verify(same and rooms.all(func(r):return r.trials_set and (r.trials.is_empty() or RoomType.is_combat(r.room_type))), "trials are fixed by the map seed, only on battle rooms")
	verify(rooms.any(func(r):return r.trials.size() >= 3) and rooms.filter(func(r):return r.floor_index < 3 and r.trials.size() > 1).is_empty(), "late floors carry more trials than early ones")
	# Spawn changes baked in.
	var room := RoomState.new("t:0");room.floor_index = 8;room.room_type = RoomType.BATTLE
	var enc := EncounterState.new()
	for type in [0, 27, 1]:var e := EnemySpawnEntry.new();e.unit_type_id = type;e.set_rank(&"normal");enc.enemies.append(e)
	TrialCatalog.apply_spawns(enc, [&"elite_squad", &"treasure_guard", &"gold_convoy"])
	var costliest: int = 0
	for i in range(3):
		if CharacterCatalog.all()[enc.enemies[i].unit_type_id].base_gold_cost > CharacterCatalog.all()[enc.enemies[costliest].unit_type_id].base_gold_cost:costliest = i
	verify(enc.enemies[costliest].rank == &"elite" and enc.enemies.filter(func(e):return e.rank == &"elite").size() == 1, "정예 부대: the costliest ordinary enemy becomes the elite")
	verify(enc.enemies.all(func(e):return is_equal_approx(e.hp_multiplier, (2.5 if e.rank == &"elite" else 1.0) * TrialCatalog.TREASURE_HP) and is_equal_approx(e.speed_multiplier, (1.08 if e.rank == &"elite" else 1.0) * TrialCatalog.CONVOY_SPEED)), "보물 수호자 HP and 금괴 운반대 speed land on every enemy")

func saves() -> void:
	var t := TowerController.new();t.new_run(19, 73)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(SaveSnapshotBuilder.capture(t, "trials", 1).document))
	var loaded: SaveLoadResult = SaveSnapshotLoader.restore(doc)
	var rooms: Array = t.guild.state.tower.map.rooms.values()
	verify(loaded.ok() and rooms.all(func(r):return loaded.run.tower.map.get_room(r.room_id).trials == r.trials), "trials survive a save and load")
	# An old (v12) save: rooms not entered get trials, an entered one keeps none.
	var entered: String = rooms.filter(func(r):return RoomType.is_combat(r.room_type) and r.floor_index == 0)[0].room_id
	doc.schema_version = 12
	for r in doc.run.tower.map.rooms:
		r.erase("trials");r.erase("trials_set")
		if r.room_id == entered:r.visited = true;r.discovered = true;doc.run.tower.visited_rooms[entered] = true
	var old: SaveLoadResult = SaveSnapshotLoader.restore(doc)
	var later: Array = rooms.filter(func(r):return RoomType.is_combat(r.room_type) and r.floor_index >= 6)
	verify(old.ok() and old.run.tower.map.get_room(entered).trials.is_empty() and later.any(func(r):return not old.run.tower.map.get_room(r.room_id).trials.is_empty()), "v12 save: trials for rooms not entered, none for the one entered")
	var bad: Dictionary = JSON.parse_string(JSON.stringify(SaveSnapshotBuilder.capture(t, "trials", 1).document))
	for r in bad.run.tower.map.rooms:
		if RoomType.is_combat(StringName(r.room_type)):r.trials = ["tough", "seastone"];break
	verify(not SaveSnapshotLoader.restore(bad).ok(), "a save with 강인함 and 해루석 보호막 together is rejected")

## A custom battle (full characters) with `trials`: blue (team 0) against red.
func battle(trials: Array, allies: Array = [0, 0], foes: Array = [0, 0], spacing: float = 300) -> BattleManager:
	var setup := CustomBattleSetup.new()
	for i in range(allies.size()):setup.add(allies[i], 0, Vector2(150, 200 + i * 120))
	for i in range(foes.size()):setup.add(foes[i], 1, Vector2(150 + spacing, 200 + i * 120))
	var b := BattleManager.new();b.auto_start = false;b.custom_mode = true;b.set_physics_process(false);host.root.add_child(b)
	b.trials.assign(trials);b.trial_floor = 8
	b.start_battle(setup.placements(), 7, setup.map)
	for u in b.units:u.combat.cooldown = 999
	return b
func step(b: BattleManager, seconds: float) -> void:
	for i in range(roundi(seconds * 60)):b.simulate(1.0 / 60)
func blow(b: BattleManager, target: BattleUnit, dmg: StringName = &"basic") -> float:
	var source: BattleUnit = b.units.filter(func(u):return u.team != target.team)[0]
	var hp: float = target.current_hp
	b.damage_resolver.resolve(source, target, 50, {"dmg": dmg, "critical": false, "transcendent": true, "impulse": 0})
	return hp - target.current_hp

func counters() -> void:
	var plain := battle([]);var one := battle([&"tough"]);var two := battle([&"tough", &"melee_masters"]);var other := battle([&"seastone"])
	var base: float = blow(plain, plain.units[2]);var cut: float = blow(one, one.units[2]);var both: float = blow(two, two.units[2]);var off: float = blow(other, other.units[2])
	verify(base > 0 and absf(cut - base * .4) <= 1 and absf(both - base * .4) <= 1, "카운터: 60%% less after defense, once however many match (%.0f / %.0f / %.0f)" % [base, cut, both])
	verify(absf(off - base) <= .01, "a counter of another kind does nothing (magic vs a physical blow)")
	var ally_hit: float = blow(one, one.units[0])
	verify(absf(ally_hit - blow(plain, plain.units[0])) <= .01, "counters protect only the enemies")
	verify(TrialEffects.counter_factor(one, one.units[2], &"magic", [&"fire", &"dot"]) == 1.0 and TrialEffects.counter_factor(two, two.units[2], &"magic", [&"melee"]) == TrialCatalog.COUNTER_TAKEN, "tags count too (status damage by its own tags)")
	verify(TrialCatalog.basic_counters([&"ironclad"], 1) == [&"ironclad"] and TrialCatalog.basic_counters([&"ironclad"], 0).is_empty(), "불리: the archer's basic arrows run into 철갑, the warrior's sword does not")
	for b in [plain, one, two, other]:b.free()

func environment() -> void:
	var fog := battle([&"fog"], [1, 0], [1, 0])
	var archer: BattleUnit = fog.units[0]
	verify(is_equal_approx(archer.data.attack_range, CharacterCatalog.all()[1].attack_range * TrialCatalog.FOG_RANGE) and fog.units[1].data.attack_range >= TrialCatalog.FOG_MIN_RANGE - .01, "짙은 안개: range ×0.7, never below 60")
	verify(CharacterCatalog.all()[1].attack_range > archer.data.attack_range, "…on the unit's own copy, the shared data untouched")
	fog.free()
	var meteor := battle([&"meteor"])
	meteor.trial_state.meteor_clock = .05
	step(meteor, .1)
	var falling: Array = meteor.trial_state.meteors
	verify(falling.size() == 1 and meteor.zones.risk_hazards(meteor.units[0]).size() >= 1, "소행성: a warning circle the AI reads as danger")
	var spot: Vector2 = falling[0].point
	for u in meteor.units:u.position = spot + Vector2(randf_range(-20, 20), randf_range(-20, 20));u.combat.cooldown = 999
	var hp: Array = meteor.units.map(func(u):return u.current_hp)
	step(meteor, TrialCatalog.METEOR_WARN + .05)
	var hurt: bool = true
	for i in range(meteor.units.size()):hurt = hurt and meteor.units[i].current_hp < hp[i]
	verify(hurt and meteor.trial_state.meteors.is_empty() and int(meteor.combat_event_counts.get(&"trial_hit", 0)) >= meteor.units.size(), "…then it hits allies and enemies alike as 시련 피해")
	meteor.free()
	var quake := battle([&"quake"])
	quake.trial_state.quake_clock = TrialCatalog.QUAKE_WARN + .05
	step(quake, .1)
	var warned: bool = int(quake.combat_event_counts.get(&"trial_quake_warn", 0)) == 1
	step(quake, TrialCatalog.QUAKE_WARN)
	verify(warned and quake.units.all(func(u):return u.stun_remaining > 0 and u.state_value("quakeTime") > 0), "지진: warned a second ahead, then everyone falls")
	verify(StatusCatalog.collect(quake.units[0]).any(func(r):return r.key == &"trial_quake"), "넘어짐 shows in the status tab")
	quake.free()

func empowered() -> void:
	var b := battle([&"regen", &"berserkers", &"vengeance", &"vanguard"], [0, 0], [0, 0, 0])
	var foe: BattleUnit = b.units[2];var near: BattleUnit = b.units[3]
	verify(is_equal_approx(TrialEffects.move_speed(foe), TrialCatalog.VANGUARD_MOVE) and is_equal_approx(TrialEffects.move_speed(b.units[0]), 1.0), "선봉대: enemies move ×1.6 at the start, allies unchanged")
	step(b, TrialCatalog.VANGUARD_TIME + .1)
	verify(is_equal_approx(TrialEffects.move_speed(foe), 1.0), "…for three seconds")
	foe.current_hp = foe.max_hp * .25
	verify(is_equal_approx(TrialEffects.attack_speed(foe), TrialCatalog.BERSERK_ATTACK_SPEED) and is_equal_approx(TrialEffects.move_speed(foe), TrialCatalog.BERSERK_MOVE), "광전사들: at 30%% HP attack speed ×1.5, move ×1.2")
	var before: float = foe.current_hp
	step(b, 1.05)
	verify(foe.current_hp > before + foe.max_hp * .005, "끈질긴 생명: about 1%% of max HP a second")
	near.position = b.units[4].position + Vector2(40, 0)
	b.damage_resolver.resolve(b.units[0], b.units[4], 99999, {"dmg": &"basic", "critical": false, "transcendent": true})
	verify(not b.units[4].alive and near.state_value("vengeanceStacks") == 1 and is_equal_approx(TrialEffects.attack_factor(near), 1.1), "복수심: a fallen enemy gives the ones nearby +10% attack")
	verify(StatusCatalog.collect(near).any(func(r):return r.key == &"trial_vengeance") and StatusCatalog.collect(foe).any(func(r):return r.key == &"trial_berserk"), "the empowered states show in the status tab")
	b.free()
	var s := battle([&"sniper"], [0, 4], [0])
	var big: BattleUnit = s.units[0] if s.units[0].current_hp >= s.units[1].current_hp else s.units[1]
	s.trial_state.sniper_clock = .02
	step(s, .1)
	var aimed: bool = String(s.trial_state.aim.get("target", "")) == big.actor_id()
	var hp: float = big.current_hp
	step(s, TrialCatalog.SNIPER_AIM + .05)
	verify(aimed and big.current_hp < hp and int(s.combat_event_counts.get(&"trial_snipe", 0)) == 1, "저격 지원: aims at the ally with the most HP, then fires")
	s.free()
	var elite := battle([&"elite_squad"], [0], [0, 27])
	verify(elite.units[2].state_value("trialElite") > 0 and elite.units[2].max_hp > CharacterCatalog.all()[27].max_hp * 2, "정예 부대 (custom battle): the costliest enemy becomes an elite")
	elite.free()

func rewards() -> void:
	verify(TrialEffects.kill_gold([&"gold_convoy"]) == 2.0 and is_equal_approx(TrialEffects.victory_gold([&"gold_convoy"]), 1.3) and TrialEffects.kill_gold([]) == 1.0, "금괴 운반대: kill gold ×2, victory gold ×1.3")
	verify(TrialEffects.extra_choices([&"treasure_guard"]) == 1 and TrialEffects.extra_choices([&"regen"]) == 0, "보물 수호자: one more reward choice")
	var t := TowerController.new();t.new_run(19, 73)
	var room: RoomState = t.guild.state.tower.map.rooms.values().filter(func(r):return r.room_type == RoomType.BATTLE)[0]
	room.trials.assign([&"treasure_guard"]);t.content.roll_battle_reward(room, t.generator.rng, TrialEffects.extra_choices(room.trials))
	verify(room.item_choices.size() == ItemTuning.REWARD_CHOICES + 1, "…four choices instead of three")

func ui_rules() -> void:
	verify(not TrialCatalog.allowed(&"calm", [&"sun", &"holy"]) and TrialCatalog.allowed(&"fog", [&"sun", &"holy"]) and not TrialCatalog.allowed(&"seastone", [&"tough"]) and not TrialCatalog.allowed(&"meteor", [&"fog", &"quake", &"regen", &"vanguard"]), "custom picker: up to four, two counters, 강인함 ↔ 해루석 보호막")
	var bar := WalletBar.new();bar.size = Vector2(360, 81)
	var four: Array[StringName] = [&"tough", &"meteor", &"regen", &"gold_convoy"];bar.trials = four
	var rects: Array = range(4).map(func(i):return Rect2(bar.trial_center(i) - Vector2.ONE * WalletBar.TRIAL_R, Vector2.ONE * WalletBar.TRIAL_R * 2))
	var apart: bool = true
	for i in range(3):apart = apart and not rects[i].intersects(rects[i + 1])
	var middle: float = (rects[0].position.x + rects[3].end.x) * .5
	verify(apart and absf(middle - 180) < 1 and rects[0].position.y >= 68 + 4 and rects[3].end.y <= bar.custom_minimum_size.y and bar.custom_minimum_size.y == 70 + WalletBar.TRIAL_TOP + WalletBar.TRIAL_R * 2, "four icons in a row centred under the wallet panel on a 360 px phone")
	bar.free()
