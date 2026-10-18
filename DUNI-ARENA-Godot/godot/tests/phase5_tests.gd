class_name Phase5Tests
extends RefCounted
var checks: int = 0
var failures: int = 0
var groups: int = 0
var host: SceneTree

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PHASE 5 FAIL: " + message)

func fixture() -> Dictionary:
	var guild := GuildManager.new()
	for index in range(4): guild.create_member(0 if index < 3 else 1)
	var room := RoomState.new()
	room.add_enemy("e1", BattleManager.WARRIOR, Vector2(640, 220))
	room.add_enemy("e2", BattleManager.ARCHER, Vector2(710, 620))
	var battle := legacy_manager()
	battle.auto_start = false
	host.root.add_child(battle)
	battle.set_physics_process(false)
	var plan := DeploymentPlan.new(guild)
	plan.place(guild.all_members()[0].member_id, Vector2(100, 220))
	plan.place(guild.all_members()[1].member_id, Vector2(100, 620))
	var session := RoomBattleSession.new(guild, room)
	verify(session.start(plan, battle, 29), "room session enables TP")
	for unit in battle.units: unit.combat.cooldown = 10000
	return {"guild": guild, "room": room, "battle": battle, "session": session, "tp": battle.turning}

func pause(f: Dictionary, time: float = 12) -> void:
	f.battle.clock.elapsed = time
	f.battle.simulate(1.0)
	f.battle.simulate(1.0)
	verify(f.tp.is_paused(), "two real seconds enter hold")

func make_plan(f: Dictionary, kind: StringName, index: int = 2) -> EnemyTurningPlan:
	var plan := EnemyTurningPlan.new()
	plan.plan_id = "test_plan"
	plan.source_enemy_id = f.battle.units[index].source_enemy_id
	plan.plan_type = kind
	plan.target_member_id = f.battle.units[1].source_member_id
	if kind == EnemyTurningPlan.SPECIAL: plan.metadata = EnemyTurningPlan.special_metadata(f.battle.units[index].data.type_id)
	return plan

func test_clock_and_schedule() -> void:
	groups += 1
	var f: Dictionary = fixture()
	verify(f.tp.next_at == 12 and f.battle.clock.state == BattleClock.State.NORMAL, "web first12 normal")
	f.battle.clock.elapsed = 11.99
	f.battle.simulate(0.001)
	verify(f.tp.current == null, "before first threshold no occurrence")
	f.battle.clock.elapsed = 12
	f.battle.simulate(0.5)
	verify(f.tp.current.trigger_simulation_time == 12 and f.tp.next_at == 42, "first trigger and absolute web interval")
	verify(f.battle.clock.state == BattleClock.State.TURNING_SLOWDOWN and is_equal_approx(f.battle.clock.simulation_delta, 0.375), "brake .5 => rate .75")
	f.battle.simulate(0.5)
	verify(is_equal_approx(f.battle.clock.simulation_delta, 0.25), "brake 1 => rate .5 decreasing")
	f.battle.simulate(0.9)
	verify(f.battle.clock.state == BattleClock.State.TURNING_SLOWDOWN and is_equal_approx(f.battle.clock.turning_scale(), 0.05), "1.9 still braking")
	f.battle.simulate(0.1)
	verify(f.tp.is_paused() and f.tp.current.remaining_real_time == 40 and f.battle.clock.simulation_delta == 0, "exact 2real sec then40real hold")
	verify(not f.battle.clock.set_speed(2), "speed selection locked during hold")
	f.battle.simulate(20)
	verify(f.tp.current.remaining_real_time == 20 and f.tp.next_at == 42, "hold real time not next schedule")
	f.tp.current.enemy_plans.clear()
	verify(f.tp.resolve() and f.battle.clock.state == BattleClock.State.NORMAL, "manual resume normal")
	verify(not f.tp.resolve() and f.tp.resolve_count == 1, "duplicate manual resume rejected")
	verify(is_equal_approx(f.battle.clock.real_elapsed, 22.001), "clock real elapsed includes brake and held UI time")
	var at: float = f.battle.clock.elapsed
	f.battle.simulate(0.1)
	verify(is_equal_approx(f.battle.clock.elapsed, at + 0.1), "simulation resumes")
	f.battle.clock.elapsed = 41.99
	f.battle.simulate(0.001)
	verify(f.tp.serial == 1, "before second threshold no new TP")
	f.battle.clock.elapsed = 42
	f.battle.simulate(0.1)
	verify(f.tp.serial == 2 and f.tp.next_at == 72, "next at42 then72")
	f.battle.free()
	var clock := BattleClock.new()
	verify(clock.set_speed(4) and clock.advance(0.5) == 2, "speed separates sim/real clock")
	clock.begin_slowdown()
	verify(not clock.set_speed(1), "speed locked through brake")
	clock.progress_slowdown(1.99, 2)
	verify(clock.turning_scale() == 0.035, "minimum web brake scale .035")
	clock.stop()
	verify(clock.advance(50) == 0 and clock.stopped, "stop never advances")

func test_frozen_state_and_stance() -> void:
	groups += 1
	var f: Dictionary = fixture()
	pause(f)
	var unit: BattleUnit = f.battle.units[0]
	unit.combat_state = CombatController.State.WINDUP
	unit.combat.phase_time = 0.12
	unit.combat.cooldown = 1.23
	f.battle.units[2].combat_state = CombatController.State.ACTIVE
	f.battle.units[2].combat.melee_live = true
	f.battle.units[2].combat.melee_age = 0.03
	f.battle.units[3].combat_state = CombatController.State.RECOVERY
	f.battle.units[3].combat.phase_time = 0.1
	var arrow: BattleProjectile = BattleManager.PROJECTILE_SCENE.instantiate()
	arrow.initialize(f.battle.units[3], PI)
	f.battle.projectiles.append(arrow)
	f.battle.add_child(arrow)
	var target_before = unit.target
	var positions: Array = f.battle.units.map(func(u): return u.position)
	var hp: Array = f.battle.units.map(func(u): return u.current_hp)
	var at: float = f.battle.clock.elapsed
	var arrow_at: Vector2 = arrow.position
	var life: float = arrow.lifetime
	var rng_state: int = f.battle.rng.state
	var plans = f.tp.current.enemy_plans.duplicate()
	for frame in range(60): f.battle.simulate(1.0 / 60.0)
	verify(positions == f.battle.units.map(func(u): return u.position), "paused positions frozen")
	verify(hp == f.battle.units.map(func(u): return u.current_hp), "paused HP frozen")
	verify(unit.combat_state == CombatController.State.WINDUP and unit.combat.phase_time == 0.12, "paused windup frozen")
	verify(unit.combat.cooldown == 1.23, "paused cooldown frozen")
	verify(f.battle.units[2].combat_state == CombatController.State.ACTIVE and f.battle.units[2].combat.melee_age == 0.03, "active strike frozen")
	verify(f.battle.units[3].combat_state == CombatController.State.RECOVERY and f.battle.units[3].combat.phase_time == 0.1, "recovery frozen")
	verify(unit.target == target_before and f.battle.rng.state == rng_state, "paused AI/RNG no judgement")
	verify(f.battle.clock.elapsed == at, "paused sim clock frozen")
	verify(is_equal_approx(f.tp.current.remaining_real_time, 39), "paused real countdown advances")
	verify(arrow.position == arrow_at and arrow.lifetime == life, "projectile paused")
	verify(plans == f.tp.current.enemy_plans and not plans[0].executed, "plans generated once and fixed")
	verify(unit.receive_damage(10, f.battle.units[2]) == 0, "even direct HP path denies paused combat damage")
	verify(f.battle.damage_resolver.apply(f.battle.units[2], unit, 10) == 0, "resolver paused")
	verify(f.tp.change_stance(unit.source_member_id, CombatStance.CAUTIOUS), "live stance selection")
	verify(unit.stance == CombatStance.CAUTIOUS and f.guild.get_member(unit.source_member_id).stance == CombatStance.CAUTIOUS, "stance both runtime/guild")
	verify(not f.tp.change_stance(unit.source_member_id, &"invalid"), "invalid stance rejected")
	verify(not f.tp.change_stance(f.guild.all_members()[2].member_id, CombatStance.RUSH), "reserve is not a live participant")
	f.tp.current.enemy_plans.clear()
	f.tp.resolve()
	verify(not f.tp.change_stance(unit.source_member_id, CombatStance.RUSH), "stance edits locked after resume")
	f.battle.clock.elapsed = 20
	f.session.request_retreat()
	verify(f.guild.get_member(unit.source_member_id).stance == CombatStance.CAUTIOUS, "stance survives room settlement")
	f.battle.free()

func test_plans_focus_and_special() -> void:
	groups += 1
	var f: Dictionary = fixture()
	pause(f)
	verify(f.tp.current.enemy_plans.size() == 2 and f.tp.current.enemy_plans[0].source_enemy_id == "e1", "per living enemy stable ID plan")
	verify(UnitStateCodec.is_pure_data(f.tp.current.enemy_plans[0].metadata), "pure metadata")
	var unsafe := EnemyTurningPlan.new()
	var node := Node.new()
	unsafe.metadata = {"node": node}
	verify(unsafe.metadata.is_empty(), "plan metadata refuses Node refs")
	node.free()
	var a: BattleUnit = f.battle.units[0]
	var b: BattleUnit = f.battle.units[1]
	a.current_hp = 100
	b.current_hp = 30
	verify(TurningPointManager.focus_target([a,b]) == b, "lowest HP RATIO target")
	var old: UnitData = a.data
	a.data = old.duplicate(true)
	a.data.type_id = 5
	verify(TurningPointManager.focus_target([b,a]) == a, "first healer ahead of low ratio")
	a.data = old
	var focus: EnemyTurningPlan = make_plan(f, EnemyTurningPlan.FOCUS)
	var special: EnemyTurningPlan = make_plan(f, EnemyTurningPlan.SPECIAL, 3)
	f.tp.current.enemy_plans.assign([focus, special])
	var requests: Array = []
	f.tp.ultimate_requested.connect(func(id, data): requests.append([id, data]))
	verify(f.tp.resolve(), "shared resolve executes focus/special")
	var enemy: BattleUnit = f.battle.units[2]
	verify(enemy.focus_member_id == b.source_member_id and enemy.focus_until == f.battle.clock.elapsed + 10, "focus duration10")
	enemy.position = a.position + Vector2(60,0)
	verify(enemy.target_selector.select_target(enemy, f.battle.units) == b, "focus overrides nearer valid enemy")
	verify(f.battle.units[3].ultimate_gauge == 100 and requests.size() == 1 and requests[0][0] == "e2", "special charge+readiness hook without invented ability")
	verify(f.battle.units[3].character_specific_state.strategyUltimateReady and f.battle.units[3].character_specific_state.ultReadyAge == 5, "web readiness fields")
	verify(focus.executed and special.executed and not f.tp.resolve() and requests.size() == 1, "plans/hook execute once")
	b.receive_damage(9999, enemy)
	verify(enemy.target_selector.select_target(enemy, f.battle.units) == a, "dead focus falls back safely")
	var invalid := EnemyTurningPlan.new()
	invalid.source_enemy_id = "e1"
	invalid.plan_type = EnemyTurningPlan.FOCUS
	invalid.target_member_id = "missing"
	enemy.combat_state = CombatController.State.WINDUP
	EnemyPlanExecutor.execute(invalid, f.battle)
	verify(invalid.executed and enemy.combat_state == CombatController.State.WINDUP, "invalid focus safely no-op")
	var shotgun: Dictionary = EnemyTurningPlan.special_metadata(7)
	verify(shotgun.mode == "temporary_boost" and shotgun.duration == 8 and shotgun.damage_multiplier == 1.25 and shotgun.ammo == 2 and shotgun.reloadRemaining == 0, "shotgun exact exception metadata")
	# A temporary definition tests the future hook; no new character Resource.
	var shotunit: BattleUnit = f.battle.units[3]
	var boost := EnemyTurningPlan.new()
	boost.source_enemy_id = "e2"
	boost.plan_type = EnemyTurningPlan.SPECIAL
	boost.metadata = shotgun
	EnemyPlanExecutor.execute(boost, f.battle)
	verify(shotunit.strategy_special_until == f.battle.clock.elapsed + 8 and shotunit.combat.cooldown == 0 and shotunit.character_specific_state.ammo == 2, "exception readiness applied, no fictional shotgun attack")
	f.battle.free()

func test_enemy_retreat_and_automatic() -> void:
	groups += 1
	var f: Dictionary = fixture()
	pause(f,20)
	var plan: EnemyTurningPlan = make_plan(f, EnemyTurningPlan.RETREAT)
	f.tp.current.enemy_plans.assign([plan])
	f.tp.current.remaining_real_time = 0.5
	var at: float = f.battle.clock.elapsed
	f.battle.simulate(0.5)
	verify(f.tp.resolve_count == 1 and f.tp.current.resolved and f.battle.clock.state == BattleClock.State.NORMAL, "automatic shared resolve")
	verify(plan.executed and not f.battle.finished and f.battle.result == null, "enemy retreat is not BattleEndReason.RETREAT")
	var enemy: BattleUnit = f.battle.units[2]
	verify(enemy.command_retreat_until == at + 6 and not enemy.strategy_dash.is_empty(), "6sec retreat plus dash")
	verify(enemy.position.is_finite() and enemy.position.x >= 28 and enemy.position.x <= 772, "dash bounds finite")
	verify(not enemy.combat.can_start(enemy, f.battle.units[0]), "retreat blocks attacks")
	var before: Vector2 = enemy.position
	f.battle.simulate(0.1)
	verify(enemy.position != before and not f.battle.finished, "enemy escape dash explicit movement")
	verify(f.tp.next_at == 42 and is_equal_approx(f.battle.clock.elapsed, at + 0.2), "automatic resume uses capped frame, excludes strategy wall time")
	for frame in range(120): f.battle.simulate(1.0/60)
	verify(enemy.strategy_dash.is_empty() and enemy.position.is_finite(), "dash completes then safe flee")
	verify(f.session.request_retreat(), "whole battle retreat after individual retreat")
	var saved: Dictionary = f.room.enemy_state.e1.persistent_state
	verify(saved.retreatRemaining > 0 and not saved.has("plan") and not saved.has("turning"), "remaining retreat numeric persistence, no plan objects")
	var retry := legacy_manager()
	retry.auto_start = false
	host.root.add_child(retry)
	retry.set_physics_process(false)
	var draft := DeploymentPlan.new(f.guild)
	draft.place(f.guild.all_members()[0].member_id, Vector2(60,400))
	var session := RoomBattleSession.new(f.guild, f.room)
	verify(session.start(draft, retry, 3), "retry after TP")
	verify(retry.turning.next_at == 12 and retry.turning.current == null and retry.turning.serial == 0, "new attempt fresh first TP")
	verify(retry.units[1].command_retreat_until == saved.retreatRemaining and retry.units[1].strategy_dash.is_empty(), "web persists remaining flee, recreates dash-free movement")
	verify(not f.room.get_property_list().any(func(p): return p.name == "turning") and UnitStateCodec.is_pure_data(saved), "room/enemy contain no TurningPointState")
	f.battle.free()
	retry.free()

func test_end_priority_and_retreat() -> void:
	groups += 1
	for reason in [BattleEndReason.Value.VICTORY, BattleEndReason.Value.DEFEAT, BattleEndReason.Value.RUN_ENDED]:
		var f: Dictionary = fixture()
		f.battle.clock.elapsed = 12
		f.battle.simulate(0.25)
		verify(f.battle.clock.state == BattleClock.State.TURNING_SLOWDOWN, "braking before outcome")
		if reason == BattleEndReason.Value.VICTORY:
			for unit in f.battle.units:
				if unit.team == 1: unit.receive_damage(9999, f.battle.units[0])
		elif reason == BattleEndReason.Value.DEFEAT:
			for unit in f.battle.units:
				if unit.team == 0: unit.receive_damage(9999, f.battle.units[2])
		else:
			f.guild.state.player_hp = 4
			f.battle.units[0].receive_damage(9999, f.battle.units[2])
		f.battle.simulate(0.01)
		verify(f.battle.result.end_reason == reason and f.battle.clock.stopped, "battle reason outranks brake")
		verify(not f.tp.enabled and f.tp.next_at == INF and f.tp.current.phase == TurningPointState.Phase.CANCELLED, "end removes timer/schedule")
		verify(not f.tp.resolve() and f.tp.resolve_count == 0, "ended plans never execute")
		var result: BattleResult = f.battle.result
		f.battle.simulate(100)
		verify(f.battle.result == result and f.session.settlement.apply_room(result, f.guild, f.room) == BattleSettlement.Status.ALREADY_SETTLED, "end settlement once")
		f.battle.free()
	var f: Dictionary = fixture()
	pause(f,42)
	verify(f.session.retreat.check(f.battle, f.guild.state) == RetreatController.Code.OK, "web allows full retreat in TP hold after20")
	verify(f.session.request_retreat() and f.battle.result.end_reason == BattleEndReason.Value.RETREAT, "full retreat from hold")
	verify(f.tp.resolve_count == 0 and not f.tp.resolve() and f.guild.state.player_hp == 100, "no plans/defeat penalty when retreat from hold")
	verify(f.session.settlement.apply_room(f.battle.result, f.guild, f.room) == BattleSettlement.Status.ALREADY_SETTLED, "TP retreat single settlement")
	f.battle.free()
	f = fixture()
	f.battle.clock.elapsed = 20
	f.battle.simulate(0.1)
	verify(f.battle.clock.state == BattleClock.State.TURNING_SLOWDOWN and f.session.retreat.check(f.battle, f.guild.state) == RetreatController.Code.OK, "full retreat allowed during braking")
	verify(f.session.request_retreat() and f.tp.current.enemy_plans.is_empty() and f.tp.resolve_count == 0, "brake retreat ends without generated/executed plans")
	f.battle.free()
	f = fixture()
	pause(f)
	verify(f.session.retreat.check(f.battle, f.guild.state) == RetreatController.Code.TOO_EARLY, "first TP does not grant early full retreat")
	f.guild.state.player_hp = 0
	f.battle.simulate(0.1)
	verify(f.battle.result.end_reason == BattleEndReason.Value.RUN_ENDED and not f.tp.resolve(), "external run ended while held snapshots/no resume")
	f.battle.free()

func test_overshoot_and_dead_sides() -> void:
	groups += 1
	var f: Dictionary = fixture()
	f.battle.clock.elapsed = 12
	f.battle.simulate(2.25)
	verify(f.tp.is_paused() and f.tp.current.remaining_real_time == 39.75, "brake overshoot consumed by real hold")
	f.tp.current.enemy_plans.clear()
	f.battle.simulate(39.75)
	verify(f.tp.resolve_count == 1 and f.battle.clock.state == BattleClock.State.NORMAL, "exact zero timer auto resume")
	f.battle.free()
	f = fixture()
	for unit in f.battle.units:
		if unit.team == 1: unit.receive_damage(9999, f.battle.units[0])
	f.battle.clock.elapsed = 12
	f.battle.simulate(0.1)
	verify(f.tp.current == null and f.battle.finished, "no live enemy => end before TP")
	f.battle.free()

func run(tree: SceneTree) -> void:
	host = tree
	test_clock_and_schedule()
	test_frozen_state_and_stance()
	test_plans_focus_and_special()
	test_enemy_retreat_and_automatic()
	test_end_priority_and_retreat()
	test_overshoot_and_dead_sides()
	print("PHASE 5 RESULT: ", groups, " test groups; ", checks, " checks; ", failures, " failures")

func legacy_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.common_combat_enabled = false
	manager.full_characters_enabled = false
	return manager
