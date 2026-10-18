extends SceneTree
## Run: godot --headless --path godot --script res://tests/test_runner.gd
## Uses the SAME scenes/resources/simulation as the interactive default battle.

const STEP: float = 1.0 / 60.0
var failures: int = 0
var checks: int = 0
var scenarios: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func placement(data: UnitData, team: int, point: Vector2) -> Dictionary:
	return {"data": data, "team": team, "position": point}

func make_battle(entries: Array[Dictionary], seed_value: int = 100) -> BattleManager:
	var battle := legacy_manager()
	battle.auto_start = false
	battle.set_physics_process(false)
	root.add_child(battle)
	verify(battle.start_battle(entries, seed_value), "battle accepts valid placements")
	return battle

func signature(battle: BattleManager) -> Array:
	var snapshot: Array = [battle.clock.elapsed, battle.rng.state, battle.finished, battle.result]
	for unit in battle.units:
		snapshot.append([unit.current_hp, unit.position, unit.velocity, unit.target, unit.alive, unit.combat_state, unit.combat.cooldown, unit.combat.phase_time, unit.combat.attacks_started, unit.combat.attacks_released, unit.combat.melee_age])
	for arrow in battle.projectiles:
		snapshot.append([arrow.position, arrow.velocity, arrow.live, arrow.lifetime])
	return snapshot

func verify_invariants(battle: BattleManager) -> void:
	for unit in battle.units:
		verify(unit.position.is_finite() and unit.velocity.is_finite(), "finite position/velocity")
		verify(unit.position.x >= 28 and unit.position.x <= 772 and unit.position.y >= 28 and unit.position.y <= 772, "inside logical arena")
		verify(is_finite(unit.current_hp) and unit.current_hp >= 0 and unit.current_hp <= unit.data.max_hp, "HP remains in bounds")
		verify(unit.alive == (unit.current_hp > 0), "death agrees with HP")
		if not unit.alive:
			verify(unit.combat_state == CombatController.State.IDLE and unit.target == null and not unit.combat.melee_live, "dead unit cannot attack/think")
	for arrow in battle.projectiles:
		verify(arrow.position.is_finite() and arrow.velocity.is_finite(), "finite projectile")

func verify_frozen(battle: BattleManager) -> void:
	var before: Array = signature(battle)
	for frame in range(120):
		battle.simulate(STEP)
	battle.check_outcome()
	if battle.units.size() > 1:
		var source: BattleUnit = battle.units[0]
		var target: BattleUnit = battle.units[-1]
		verify(battle.damage_resolver.apply(source, target, 9999) == 0, "no post-finish damage")
		verify(target.receive_damage(9999, source) == 0, "unit HP entry point also rejects post-finish damage")
		verify(not source.combat.start(source, target, battle.rng), "no post-finish attack")
		battle.spawn_projectile(source, 0)
		source.movement.advance(source, STEP)
	verify(signature(battle) == before, "entire simulation remains frozen after result")

func run_match(label: String, entries: Array[Dictionary], seed_value: int) -> void:
	scenarios += 1
	var battle := legacy_manager()
	battle.auto_start = false
	battle.set_physics_process(false)
	root.add_child(battle)
	var counters: Dictionary = {"result": 0, "deaths": {}}
	battle.battle_finished.connect(func(_result): counters.result += 1)
	battle.unit_died.connect(func(unit, _source): counters.deaths[unit.battle_id] = counters.deaths.get(unit.battle_id, 0) + 1)
	verify(battle.start_battle(entries, seed_value), label + " starts")
	var phases: Dictionary = {}
	for frame in range(180 * 60):
		if battle.finished:
			break
		battle.simulate(STEP)
		for unit in battle.units:
			phases[unit.combat_state] = true
		if frame % 30 == 0:
			verify_invariants(battle)
	verify(battle.finished, label + " terminates within test budget")
	verify(counters.result == 1, label + " emits exactly one result")
	for count in counters.deaths.values():
		verify(count == 1, label + " emits each death once")
	if entries.size() > 1 and entries[0].team != entries[-1].team:
		for phase in CombatController.State.values():
			verify(phases.has(phase), label + " visits all attack states")
	verify_invariants(battle)
	verify_frozen(battle)
	print("PASS ", label, " seed=", seed_value, " time=", snappedf(battle.clock.elapsed, 0.01), " winner=", battle.result.winner_team)
	battle.free()

func test_data_and_damage() -> void:
	var w: UnitData = BattleManager.WARRIOR
	var a: UnitData = BattleManager.ARCHER
	verify([w.type_id, w.display_name, w.max_hp, w.attack, w.move_speed, w.attack_range, w.attack_interval, w.critical_chance] == [0, "전사", 150.0, 16.0, 96.0, 62.0, 1.0, 0.22], "warrior TYPES values")
	verify([a.type_id, a.display_name, a.max_hp, a.attack, a.move_speed, a.attack_range, a.attack_interval, a.critical_chance] == [1, "궁수", 105.0, 15.0, 92.0, 380.0, 0.75, 0.2], "archer TYPES values")
	verify(is_equal_approx(w.attack_profile.start_distance(), 97.2) and a.attack_profile.start_distance() == 410, "real attack initiation thresholds")
	var battle := make_battle([placement(w, 0, Vector2(100, 100)), placement(w, 0, Vector2(100, 200)), placement(a, 1, Vector2(700, 700))])
	var u: BattleUnit = battle.units[0]
	var copy: BattleUnit = battle.units[1]
	var enemy: BattleUnit = battle.units[2]
	verify(u.data == copy.data and u.combat != copy.combat and u.target_selector != copy.target_selector, "shared resource, independent controllers")
	var no_crit: UnitData = w.duplicate()
	no_crit.critical_chance = 0.0
	u.data = no_crit
	verify(battle.damage_resolver.apply(u, enemy, 16) == 16, "normal damage")
	var all_crit: UnitData = a.duplicate()
	all_crit.critical_chance = 1.0
	enemy.data = all_crit
	verify(battle.damage_resolver.apply(enemy, u, 15) == 23, "1.5 critical multiplier and round 22.5 to 23")
	verify(copy.current_hp == 150 and w.critical_chance == 0.22 and a.critical_chance == 0.2, "runtime HP/fixture data never alters another instance or shared resource")
	var hp_before: float = u.current_hp
	verify(battle.damage_resolver.apply(copy, u, 50) == 0, "friendly damage rejected")
	verify(battle.damage_resolver.apply(enemy, u, NAN) == 0 and battle.damage_resolver.apply(enemy, u, INF) == 0, "non-finite damage rejected")
	verify(u.current_hp == hp_before, "invalid damage leaves HP unchanged")
	u.combat.cooldown = 0
	verify(not u.combat.start(u, enemy, battle.rng), "cannot begin outside real range")
	var target_hp: float = enemy.current_hp
	enemy.position = Vector2(190, 100)
	verify(u.combat.start(u, enemy, battle.rng), "can begin inside profile range")
	verify(enemy.current_hp == target_hp and u.combat_state == CombatController.State.WINDUP, "windup does not immediately deal damage")
	verify(not u.combat.start(u, enemy, battle.rng), "no overlapping attacks")
	var cd: float = u.combat.cooldown
	verify(cd >= 1.1 and cd <= 1.35, "original cooldown formula retained")
	print("PASS source data, independent instances, normal/critical damage and range/windup gates")
	battle.free()

func test_retarget_and_death() -> void:
	var battle := make_battle([placement(BattleManager.WARRIOR, 0, Vector2(100, 100)), placement(BattleManager.WARRIOR, 1, Vector2(170, 100)), placement(BattleManager.ARCHER, 1, Vector2(600, 600))])
	var source: BattleUnit = battle.units[0]
	var first: BattleUnit = battle.units[1]
	var second: BattleUnit = battle.units[2]
	battle.simulate(STEP)
	verify(source.target == first, "initial nearest target")
	var death_count: Array[int] = [0]
	first.died.connect(func(_unit, _killer): death_count[0] += 1)
	battle.damage_resolver.apply(source, first, 9999)
	battle.damage_resolver.apply(source, first, 9999)
	var dead_before: Array = [first.position, first.combat.attacks_started, first.combat.attacks_released, first.combat.cooldown]
	for frame in range(120):
		battle.simulate(STEP)
	verify(source.target == second, "retarget after target dies, even during old windup")
	verify(dead_before == [first.position, first.combat.attacks_started, first.combat.attacks_released, first.combat.cooldown], "dead AI/movement/cooldown/attacks stop")
	verify(death_count[0] == 1, "death signal cannot repeat")
	print("PASS retarget and dead-unit inactivity")
	battle.free()

func test_projectiles_and_draw() -> void:
	var battle := make_battle([placement(BattleManager.ARCHER, 0, Vector2(350, 400)), placement(BattleManager.ARCHER, 1, Vector2(450, 400))])
	var outcomes: Array[int] = [0]
	battle.battle_finished.connect(func(_result): outcomes[0] += 1)
	for unit in battle.units:
		unit.current_hp = 1
		unit.combat.cooldown = 999
		battle.spawn_projectile(unit, 0.0 if unit.team == 0 else PI)
	# Both arrows are in flight before damage. Death of their source doesn't erase them.
	for frame in range(30):
		battle.simulate(STEP)
		if battle.finished:
			break
	verify(battle.finished and battle.result.draw and battle.result.survivors.is_empty(), "near simultaneous final projectile kills -> draw")
	verify(outcomes[0] == 1, "draw emits exactly one result")
	verify_frozen(battle)
	print("PASS simultaneous last deaths / draw")
	battle.free()
	# Test frame-skipping without inventing a different production projectile speed.
	battle = make_battle([placement(BattleManager.ARCHER, 0, Vector2(100, 400)), placement(BattleManager.WARRIOR, 1, Vector2(300, 400))])
	for unit in battle.units:
		unit.combat.cooldown = 999
	battle.spawn_projectile(battle.units[0], 0)
	var arrow: BattleProjectile = battle.projectiles[0]
	verify(not arrow.collect_hits(battle.units, 0.5).is_empty(), "sweep catches a target crossed between distant frame endpoints")
	battle.units[1].position.y = 500
	verify(arrow.collect_hits(battle.units, 0.5).is_empty(), "moving out of flight path can evade, no guaranteed target hit")
	battle.units[1].position.y = 400
	var previous_hp: float = battle.units[1].current_hp
	battle.advance_attacks(0.5)
	verify(battle.units[1].current_hp < previous_hp and battle.projectiles.is_empty(), "swept collision applies damage once and consumes normal arrow")
	print("PASS continuous projectile collision / movement evasion")
	battle.free()

func test_edge_and_empty() -> void:
	var battle := make_battle([placement(BattleManager.WARRIOR, 0, Vector2(-50, 900)), placement(BattleManager.ARCHER, 1, Vector2(800, 0))])
	verify(battle.units[0].position == Vector2(28, 772) and battle.units[1].position == Vector2(772, 28), "spawn boundary clamp")
	for frame in range(600):
		battle.simulate(STEP)
		verify_invariants(battle)
	print("PASS movement near arena boundaries")
	battle.free()
	run_match("one living faction / no enemy", [placement(BattleManager.WARRIOR, 0, Vector2(400, 400))], 11)
	run_match("zero units", [], 12)
	battle = legacy_manager()
	battle.auto_start = false
	root.add_child(battle)
	verify(not battle.start_battle([placement(BattleManager.WARRIOR, 0, Vector2(NAN, INF))]), "reject non-finite spawn rather than corrupt simulation")
	verify(not battle.started and battle.units.is_empty(), "invalid spawn has no partial side effects")
	battle.free()

func test_scene() -> void:
	var packed: PackedScene = load("res://scenes/battle.tscn")
	var screen = packed.instantiate()
	root.add_child(screen)
	var battle: BattleManager = screen.get_node("Battle")
	verify(battle.started and battle.units.size() == 6, "main scene loads and directly starts 3v3")
	verify(battle.units[0].data == battle.units[1].data, "scene repeats warrior using shared resource")
	print("PASS main scene/resource instantiation")
	screen.free()

func _run() -> void:
	test_data_and_damage()
	test_scene()
	for seed_value in [3, 29, 101]:
		run_match("warrior vs warrior", [placement(BattleManager.WARRIOR, 0, Vector2(180, 400)), placement(BattleManager.WARRIOR, 1, Vector2(620, 400))], seed_value)
		run_match("warrior vs archer", [placement(BattleManager.WARRIOR, 0, Vector2(180, 400)), placement(BattleManager.ARCHER, 1, Vector2(620, 400))], seed_value)
		run_match("archer vs archer", [placement(BattleManager.ARCHER, 0, Vector2(180, 400)), placement(BattleManager.ARCHER, 1, Vector2(620, 400))], seed_value)
		run_match("3 vs 3", BattleManager.default_placements(), seed_value)
	test_retarget_and_death()
	test_projectiles_and_draw()
	test_edge_and_empty()
	print("RESULT: ", scenarios, " completed battles; ", checks, " checks; ", failures, " failures")
	var phase2 := Phase2Tests.new()
	phase2.run(self)
	var phase3 := Phase3Tests.new()
	phase3.run(self)
	var phase4 := Phase4Tests.new()
	phase4.run(self)
	var phase5 := Phase5Tests.new()
	phase5.run(self)
	var phase6 := Phase6Tests.new()
	phase6.run(self)
	var phase7 := Phase7Tests.new()
	phase7.run(self)
	var phase8 := Phase8Tests.new()
	phase8.run(self)
	var phase9 := Phase9Tests.new()
	phase9.run(self)
	var phase10 := Phase10Tests.new()
	phase10.run(self)
	var phase105 := Phase105Tests.new()
	phase105.run(self)
	var phase11:=Phase11Tests.new()
	await phase11.run(self)
	var phase12:=Phase12Tests.new()
	await phase12.run(self)
	var phase125:=Phase125Tests.new()
	await phase125.run(self)
	var custom:=CustomBattleTests.new()
	await custom.run(self)
	print("TOTAL: ", checks + phase2.checks + phase3.checks + phase4.checks + phase5.checks + phase6.checks + phase7.checks + phase8.checks + phase9.checks + phase10.checks + phase105.checks + phase11.checks + phase12.checks + phase125.checks + custom.checks, " checks; ", failures + phase2.failures + phase3.failures + phase4.failures + phase5.failures + phase6.failures + phase7.failures + phase8.failures + phase9.failures + phase10.failures + phase105.failures + phase11.failures + phase12.failures + phase125.failures + custom.failures, " failures")
	quit(1 if failures + phase2.failures + phase3.failures + phase4.failures + phase5.failures + phase6.failures + phase7.failures + phase8.failures + phase9.failures + phase10.failures + phase105.failures + phase11.failures + phase12.failures + phase125.failures + custom.failures else 0)

func legacy_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.common_combat_enabled = false
	manager.full_characters_enabled = false
	return manager
