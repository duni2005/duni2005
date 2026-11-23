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
	catalog();rolls();generation();saves();counters();environment();empowered();rewards();ui_rules();visuals();added_rules();structures();added_battle();structure_ai()
	print("TRIAL RESULT: %d checks; %d failures" % [checks, failures])

func catalog() -> void:
	var by_kind: Dictionary = {}
	for kind in TrialCatalog.KINDS:by_kind[kind] = TrialCatalog.of_kind(kind).size()
	verify(by_kind == {&"counter": 14, &"environment": 4, &"empower": 8, &"reward": 2, &"constraint": 2, &"structure": 2}, "14 카운터, 4 환경, 8 적 강화, 2 보상, 2 제약, 2 구조물 (%s)" % str(by_kind))
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
	# Held in place: the AI would rightly walk out of the warning circle.
	for u in meteor.units:u.position = spot + Vector2(u.battle_id % 3 * 10 - 10, u.battle_id % 2 * 10);u.combat.cooldown = 999;StatusController.stun(u, 5)
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

## 0.99.18 effects: what the presentation is told and how it answers (TrialFx).
func visuals() -> void:
	verify(TrialCatalog.TRIALS.keys().all(func(id):return not TrialCatalog.short_of(id).is_empty()), "every trial has its one-line entry text")
	var b := battle([&"tough"])
	var seen: Array = []
	b.damage_resolver.damage_resolved.connect(func(_s, _t, out):seen.append(out.trial_counter))
	blow(b, b.units[2]);blow(b, b.units[0])
	verify(seen == [&"tough", &""], "a cut hit names its counter (강인함); an ally's hit names none")
	var view := CombatPresentation.new();host.root.add_child(view);view.attach(b)
	var pings: Array = []
	view.trial_pinged.connect(func(id):pings.append(id))
	blow(b, b.units[2]);blow(b, b.units[2])
	var cut: Array = view.numbers.filter(func(n):return n.get("counter", &"") == &"tough")
	verify(pings == [&"tough"] and not cut.is_empty() and cut[0].get("mark", false), "the block pings its icon once a second and marks the number with its cracked shield")
	verify(view.trial_fx.blocked(b.units[2], &"tough", 0) == false, "…one reaction per unit per 0.3 s")
	view.queue_free();b.free()
	var m := battle([&"meteor", &"regen"])
	m.trial_state.meteor_clock = .02
	for u in m.units:u.combat.cooldown = 999
	m.units[2].current_hp = m.units[2].max_hp * .5
	step(m, .05);var spot: Vector2 = m.trial_state.meteors[0].point
	for u in m.units:u.position = spot;StatusController.stun(u, 5)
	step(m, TrialCatalog.METEOR_WARN + .05)
	var hits: Array = m.combat_events.filter(func(e):return e.kind == &"trial_hit")
	verify(not hits.is_empty() and hits.all(func(e):return str(e.metadata.get("trial", "")) == "meteor"), "시련 피해 says which trial dealt it (the number's icon)")
	verify(m.combat_events.any(func(e):return e.kind == &"trial_regen" and float(e.metadata.get("amount", 0)) > 0), "끈질긴 생명 reports each heal (summed on screen)")
	m.free()
	var room := RoomState.new();room.room_type = RoomType.BOSS;room.trials.assign([&"elite_squad"]);room.encounter = EncounterState.new()
	for rank in [&"boss", &"elite", &"normal", &"elite"]:
		var e := EnemySpawnEntry.new();e.set_rank(rank);e.enemy_id = "e%d" % room.encounter.enemies.size();room.encounter.enemies.append(e)
	verify(TrialCatalog.trial_elite_id(room) == "e3", "정예 부대 mark: the first elite after a boss room's own boss and elite")

## 0.99.19: 낙뢰, 순교자, 분열, 도망칠 길은 없다, 좁은 방, 온기의 동상, 화약통.
func added_rules() -> void:
	verify(TrialCatalog.first_floor(&"no_escape") == 4 and TrialCatalog.first_floor(&"narrow_room") == 4 and TrialCatalog.first_floor(&"warm_statue") == 2 and TrialCatalog.first_floor(&"lightning") == 1, "제약 from floor 4, 구조물 from floor 2")
	verify(not TrialCatalog.allowed(&"narrow_room", [&"no_escape"]) and not TrialCatalog.allowed(&"powder_kegs", [&"warm_statue"]) and not TrialCatalog.allowed(&"split", [&"martyr"]) and TrialCatalog.allowed(&"martyr", [&"no_escape", &"warm_statue"]), "one 제약, one 구조물; 순교자 never with 분열")
	var bad: int = 0;var seen_structure_low: bool = false
	for seed_value in range(400):
		var rng := RandomNumberGenerator.new();rng.seed = seed_value
		var floor: int = 1 + seed_value % 15
		var list: Array = TrialCatalog.roll(rng, floor, RoomType.BATTLE)
		if not TrialCatalog.valid(list):bad += 1
		if floor < 2 and list.any(func(t):return TrialCatalog.kind_of(t) == TrialCatalog.STRUCTURE):seen_structure_low = true
		if floor < 4 and list.any(func(t):return TrialCatalog.kind_of(t) == TrialCatalog.CONSTRAINT):seen_structure_low = true
	verify(bad == 0 and not seen_structure_low, "400 rolls: every list valid, kinds only from their floors")
	var run := RunState.new()
	var room := RoomState.new();room.trials.assign([&"narrow_room", &"fog"])
	verify(TrialCatalog.active(room, run) == [&"fog"], "좁은 방 sleeps before 출정 확장 (limit 3)")
	run.sortie_level = 1
	verify(TrialCatalog.active(room, run) == [&"narrow_room", &"fog"] and TrialCatalog.sortie_limit(4, [&"narrow_room"]) == 3 and TrialCatalog.sortie_limit(3, [&"narrow_room"]) == 3 and TrialCatalog.sortie_limit(4, []) == 4, "…then the sortie limit is one lower")
	var t := TowerController.new();t.new_run(19, 73)
	var member: GuildMemberState = t.guild.all_members()[0];var others: Array = t.guild.all_members().slice(1)
	var entries: Array[DeploymentEntry] = []
	for i in range(2):entries.append(DeploymentEntry.new(others[i].member_id, Vector2(100, 100 + i * 100)))
	verify(DeploymentRules.validate(t.guild, DeploymentEntry.new(member.member_id, Vector2(300, 600)), entries, [], false, 2) == DeploymentRules.Code.SORTIE_FULL, "deployment honours the lowered limit")
	var b := battle([&"no_escape"]);b.room_id = "test"
	verify(RetreatController.new().check(b, RunState.new()) == RetreatController.Code.TRIAL_LOCKED, "도망칠 길은 없다: no retreat")
	verify(&"evade" in TrialCatalog.RETREAT_CARDS, "…and 전투 회피 is among the cards it locks")
	b.free()

func structures() -> void:
	var rng := RandomNumberGenerator.new();rng.seed = 5
	var enemies: Array = [Vector2(450, 300), Vector2(460, 520)]
	var rows: Array = FieldObjects.layout(rng, [&"powder_kegs"], enemies)
	var points: Array = FieldObjects.points(rows)
	var spaced: bool = true
	for i in range(points.size()):
		for j in range(i + 1, points.size()):spaced = spaced and points[i].distance_to(points[j]) >= FieldObject.KEG_SPACING
	verify(rows.size() == FieldObject.KEG_COUNT and spaced and points.all(func(p):return p.x > DeploymentRules.MAX_POSITION.x and p.x < 415 and enemies.all(func(e):return e.distance_to(p) >= FieldObjects.ENEMY_GAP)), "화약통: five, 120 apart, between the deployment zones, clear of the enemies")
	verify(FieldObjects.layout(rng, [&"warm_statue"]) == [{"kind": "statue", "x": 400.0, "y": 400.0}], "온기의 동상: the middle of the field")
	var t := TowerController.new();t.new_run(19, 73)
	var room: RoomState = t.guild.state.tower.map.rooms.values().filter(func(r):return RoomType.is_combat(r.room_type))[0]
	room.trials.assign([&"powder_kegs"]);room.field_objects.assign(rows)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(SaveSnapshotBuilder.capture(t, "objects", 1).document))
	var loaded: SaveLoadResult = SaveSnapshotLoader.restore(doc)
	verify(loaded.ok() and FieldObjects.points(loaded.run.tower.map.get_room(room.room_id).field_objects) == points, "the layout survives a save and load")
	doc.schema_version = 13
	for r in doc.run.tower.map.rooms:r.erase("field_objects")
	var old: SaveLoadResult = SaveSnapshotLoader.restore(doc)
	verify(old.ok() and old.run.tower.map.get_room(room.room_id).field_objects.is_empty() and SaveMigrator.CURRENT_VERSION == 14, "a v13 save loads (rooms without objects)")
	var broken: Dictionary = JSON.parse_string(JSON.stringify(SaveSnapshotBuilder.capture(t, "objects", 1).document))
	for r in broken.run.tower.map.rooms:
		if r.room_id == room.room_id:r.field_objects = [{"kind": "volcano", "x": 1, "y": 2}]
	verify(not SaveSnapshotLoader.restore(broken).ok(), "an unknown object kind is rejected")
	# In battle: the statue keeps units out and warms them; kegs stop shots and blow up in a chain.
	var s := battle([&"warm_statue"], [0, 0], [0, 0])
	var statue: FieldObject = s.field_objects[0]
	s.units[0].position = statue.position;s.units[2].position = statue.position + Vector2(90, 0)
	for u in s.units:u.combat.cooldown = 999;u.current_hp = u.max_hp * .5
	FieldObjects.constrain(s)
	verify(s.units[0].position.distance_to(statue.position) >= statue.radius, "a unit cannot stand in the statue")
	var before: Array = s.units.map(func(u):return u.current_hp)
	FieldObjects.advance(s, 1.01)
	var near_gain: float = s.units[2].current_hp - float(before[2])
	verify(absf(near_gain - s.units[2].max_hp * FieldObject.STATUE_HEAL) < 1 and s.units[2].state_value("trialWarmth") > 0 and StatusCatalog.collect(s.units[2]).any(func(r):return r.key == &"trial_warmth"), "…heals 2%% a second within 150 (both sides) and shows 온기")
	verify(s.zones.safe_areas(s.units[0]).any(func(a):return str(a.ref).begins_with("object:")) and s.zones.safe_areas(s.units[2]).any(func(a):return str(a.ref).begins_with("object:")), "the AI sees the statue as a place to recover")
	s.free()
	var k := battle([&"powder_kegs"], [0, 0], [0, 0])
	verify(k.field_objects.size() == FieldObject.KEG_COUNT, "a custom battle lays its kegs out")
	var first: FieldObject = k.field_objects[0];var second: FieldObject = k.field_objects[1]
	second.position = first.position + Vector2(0, FieldObject.KEG_BLAST - 10)
	for i in range(2, k.field_objects.size()):k.field_objects[i].position = Vector2(60 + i * 10, 60)
	for u in k.units:u.combat.cooldown = 999;StatusController.stun(u, 5)
	k.units[0].position = first.position + Vector2(-60, 0);k.units[2].position = first.position + Vector2(60, 0)
	verify(k.zones.risk_hazards(k.units[0]).size() >= 1, "the AI keeps a little away from kegs")
	var shot := BattleProjectile.new();shot.source = k.units[2];shot.previous_position = first.position + Vector2(40, 0);shot.position = first.position - Vector2(40, 0);shot.hit_radius = 8
	verify(FieldObjects.blocks(shot) and not shot.live and first.fuse > 0, "a projectile stops on a keg and lights it")
	shot.free()
	var hp: Array = k.units.map(func(u):return u.current_hp)
	for i in range(30):FieldObjects.advance(k, 1.0 / 60)
	verify(not first.alive and k.units[0].current_hp < float(hp[0]) and k.units[2].current_hp < float(hp[2]) and k.units[0].state_value("burnStacks") >= FieldObject.KEG_BURN and second.alive and second.fuse > 0 and second.fuse <= FieldObject.KEG_CHAIN_FUSE, "it blasts both sides (burn, push) and lights the next keg")
	for i in range(12):FieldObjects.advance(k, 1.0 / 60)
	verify(not second.alive, "…which goes off %.2f s later" % FieldObject.KEG_CHAIN_FUSE)
	k.free()

func added_battle() -> void:
	var l := battle([&"lightning"], [0, 0], [0, 0])
	l.trial_state.lightning_clock = .02
	step(l, .05)
	var bolts: Array = l.trial_state.bolts
	var near: int = bolts.filter(func(b):return l.units.any(func(u):return u.position.distance_to(b.point) <= TrialCatalog.LIGHTNING_SPREAD * 1.5)).size()
	verify(bolts.size() == TrialCatalog.LIGHTNING_STRIKES and near >= TrialCatalog.LIGHTNING_NEAR and l.zones.risk_hazards(l.units[0]).size() >= TrialCatalog.LIGHTNING_STRIKES, "낙뢰: three warned spots, two by units, read as danger")
	var spot: Vector2 = bolts[0].point
	for u in l.units:u.position = spot;u.combat.cooldown = 999;StatusController.stun(u, 5)
	var hp: Array = l.units.map(func(u):return u.current_hp)
	l.trial_state.bolts = [bolts[0]]
	for u in l.units:u.stun_remaining = 0
	l.trial_state.bolts[0].left = .01
	TrialEffects.advance(l, .02)
	var hurt: bool = true
	for i in range(l.units.size()):hurt = hurt and l.units[i].current_hp < float(hp[i])
	verify(hurt and l.units.all(func(u):return u.state_value("shockStacks") == TrialCatalog.LIGHTNING_SHOCK), "…the bolt hurts everyone inside and leaves 2 감전 stacks")
	l.free()
	var m := battle([&"martyr"], [0, 0], [0, 0, 0])
	for u in m.units:u.combat.cooldown = 999;StatusController.stun(u, 5)
	var foe: BattleUnit = m.units[2];var ally: BattleUnit = m.units[0];var friend: BattleUnit = m.units[3]
	ally.position = foe.position + Vector2(-60, 0);friend.position = foe.position + Vector2(60, 0)
	var ally_hp: float = ally.current_hp;var friend_hp: float = friend.current_hp
	m.damage_resolver.resolve(m.units[1], foe, 99999, {"dmg": &"basic", "critical": false, "transcendent": true})
	verify(not foe.alive and m.trial_state.blasts.size() == 1 and m.zones.risk_hazards(ally).size() >= 1 and m.zones.risk_hazards(friend).is_empty(), "순교자: a fallen enemy leaves a blast the player's side avoids")
	TrialEffects.advance(m, TrialCatalog.MARTYR_FUSE + .01)
	verify(absf(ally_hp - ally.current_hp - CombatRules.js_round(foe.max_hp * TrialCatalog.MARTYR_HP * UnitStatTable.mitigation(CombatRules.defense_sum(ally)))) <= 1 and friend.current_hp == friend_hp and ally.knockback_velocity.length() > 0, "…a second later it hits only the player's side (20%% of its max HP) and pushes")
	m.free()
	var sp := battle([&"split"], [0, 0], [0, 35])
	for u in sp.units:u.combat.cooldown = 999
	var target: BattleUnit = sp.units[2];var full: float = target.max_hp
	sp.damage_resolver.resolve(sp.units[0], target, 99999, {"dmg": &"basic", "critical": false, "transcendent": true})
	step(sp, .02)
	var family: Array = sp.units.filter(func(u):return u.alive and u.original_team == 1 and u.data.type_id == 0)
	verify(target.alive and family.size() == 2 and absf(target.max_hp - full * .25) <= 1 and target.invincible_remaining > 0 and family.all(func(u):return u.state_value("trialSplit") > 0), "분열: the first deadly blow splits it in two (HP 25%, briefly invincible)")
	target.invincible_remaining = 0
	verify(TrialEffects.family_alive(target) and TrialEffects.reward_enemy_id(target) == target.source_enemy_id, "kill gold and kill streaks wait for the family's last member")
	sp.damage_resolver.resolve(sp.units[0], target, 99999, {"dmg": &"basic", "critical": false, "transcendent": true})
	verify(not target.alive, "…a split enemy does not split again")
	var slime: BattleUnit = sp.units[3];var count_before: int = sp.units.size()
	sp.damage_resolver.resolve(sp.units[0], slime, 99999, {"dmg": &"basic", "critical": false, "transcendent": true})
	step(sp, .02)
	verify(slime.alive and slime.state_value("trialSplit") == 0 and slime.state_value("slimeSplits") == 1 and sp.units.size() == count_before + 1, "a slime keeps its own split rule only")
	sp.free()
	var el := battle([&"split", &"elite_squad"], [0], [0, 27])
	var elite: BattleUnit = el.units[2];var elite_hp: float = elite.max_hp
	el.damage_resolver.resolve(el.units[0], elite, 99999, {"dmg": &"basic", "critical": false, "transcendent": true})
	var rank := EnemySpawnEntry.new();rank.set_rank(&"elite")
	verify(elite.alive and elite.state_value("trialElite") == 0 and absf(elite.max_hp - floorf(elite_hp / rank.hp_multiplier + .5) * .25) <= 2, "an elite that splits loses its elite multipliers (%.0f → %.0f)" % [elite_hp, elite.max_hp])
	el.free()

## Units and solid objects: round them, never into them (0.99.20).
func structure_ai() -> void:
	var b := battle([&"warm_statue"], [0], [0])
	var statue: FieldObject = b.field_objects[0];var me: BattleUnit = b.units[0];var foe: BattleUnit = b.units[1]
	me.position = statue.position + Vector2(-170, 3);foe.position = statue.position + Vector2(170, 0)
	foe.combat.cooldown = 999;StatusController.stun(foe, 99)
	var closest: float = INF;var reached: float = -1;var turns: int = 0;var last: Vector2 = Vector2.ZERO
	for frame in range(60 * 8):
		b.simulate(1.0 / 60)
		closest = minf(closest, me.position.distance_to(statue.position) - FieldObjects.reach(statue, me))
		var v: Vector2 = me.velocity
		if v.length() > 5 and last.length() > 5 and v.normalized().dot(last.normalized()) < -.5:turns += 1
		if v.length() > 5:last = v
		if reached < 0 and me.position.distance_to(foe.position) < 110:reached = frame / 60.0
	verify(reached > 0 and reached < 6 and closest >= -1 and turns <= 2, "a unit whose target is behind the statue walks round it (reached in %.1f s, nearest %.0f from its face, %d reversals)" % [reached, closest, turns])
	b.free()
	var k := battle([&"powder_kegs"], [1], [0])
	var keg: FieldObject = k.field_objects[0];var archer: BattleUnit = k.units[0];var target: BattleUnit = k.units[1]
	for i in range(1, k.field_objects.size()):k.field_objects[i].position = Vector2(60 + i * 30, 760)
	archer.position = keg.position + Vector2(-150, 0);target.position = keg.position + Vector2(150, 0)
	target.combat.cooldown = 999;StatusController.stun(target, 99);archer.combat.cooldown = 0
	verify(k.zones.risk(archer, keg.position + Vector2(0, FieldObjects.reach(keg, archer) + 1)) < 1.0 and k.zones.risk(archer, keg.position) > 2, "the inside of an object is no place to go; its face is")
	var hp: float = target.current_hp;var first_hit: float = -1;var lit: float = -1
	for frame in range(60 * 6):
		k.simulate(1.0 / 60)
		if first_hit < 0 and target.current_hp < hp:first_hit = frame / 60.0
		if lit < 0 and (keg.fuse >= 0 or not keg.alive):lit = frame / 60.0
	verify(first_hit > 0 and (lit < 0 or lit > first_hit), "an archer with a keg in its line of fire steps aside and shoots its target, not straight into the keg (hit %.1f s, keg %.1f s)" % [first_hit, lit])
	k.free()
