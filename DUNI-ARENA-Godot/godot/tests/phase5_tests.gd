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

func fixture(legacy: bool = true) -> Dictionary:
	var guild := GuildManager.new()
	for index in range(4): guild.create_member(0 if index < 3 else 1)
	var room := RoomState.new()
	room.add_enemy("e1", BattleManager.WARRIOR, Vector2(640, 220))
	room.add_enemy("e2", BattleManager.ARCHER, Vector2(710, 620))
	var battle := legacy_manager() if legacy else BattleManager.new()
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
	var enemy: BattleUnit = f.battle.units[index]
	match kind:
		EnemyTurningPlan.OVERCHARGE: plan.metadata = EnemyTurningPlan.special_metadata(enemy.data.type_id)
		EnemyTurningPlan.MOVE: plan.metadata = {"from": CharacterPersistence.point(enemy.position), "to": CharacterPersistence.point(enemy.position + Vector2(-200, 0))}
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
	verify(plans == f.tp.current.enemy_plans and plans.all(func(p): return not p.executed), "plans generated once and fixed")
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

func test_plans_and_overcharge() -> void:
	groups += 1
	var f: Dictionary = fixture()
	pause(f)
	var ids: Array = f.tp.current.enemy_plans.map(func(p): return p.source_enemy_id)
	verify(f.tp.current.enemy_plans.size() <= 2 and ids.all(func(id): return id in ["e1", "e2"] and ids.count(id) == 1), "at most one strategy per living enemy, stable IDs")
	verify(f.tp.current.enemy_plans.all(func(p): return UnitStateCodec.is_pure_data(p.metadata) and EnemyTurningPlan.NAMES.has(p.plan_type)), "pure metadata, known strategies")
	var unsafe := EnemyTurningPlan.new()
	var node := Node.new()
	unsafe.metadata = {"node": node}
	verify(unsafe.metadata.is_empty(), "plan metadata refuses Node refs")
	node.free()
	var special: EnemyTurningPlan = make_plan(f, EnemyTurningPlan.OVERCHARGE, 3)
	f.tp.current.enemy_plans.assign([special])
	var requests: Array = []
	f.tp.ultimate_requested.connect(func(id, data): requests.append([id, data]))
	verify(f.tp.resolve(), "shared resolve executes overcharge")
	verify(f.battle.units[3].ultimate_gauge == 100 and requests.size() == 1 and requests[0][0] == "e2", "overcharge charge+readiness hook without invented ability")
	verify(f.battle.units[3].character_specific_state.strategyUltimateReady and f.battle.units[3].character_specific_state.ultReadyAge == 5, "web readiness fields")
	verify(special.executed and not f.tp.resolve() and requests.size() == 1, "plans/hook execute once")
	var shotgun: Dictionary = EnemyTurningPlan.special_metadata(7)
	verify(shotgun.mode == "temporary_boost" and shotgun.duration == 8 and shotgun.damage_multiplier == 1.25 and shotgun.ammo == 2 and shotgun.reloadRemaining == 0, "shotgun exact exception metadata")
	# A temporary definition tests the future hook; no new character Resource.
	var shotunit: BattleUnit = f.battle.units[3]
	var boost := EnemyTurningPlan.new()
	boost.source_enemy_id = "e2"
	boost.plan_type = EnemyTurningPlan.OVERCHARGE
	boost.metadata = shotgun
	EnemyPlanExecutor.execute(boost, f.battle)
	verify(shotunit.strategy_special_until == f.battle.clock.elapsed + 8 and shotunit.combat.cooldown == 0 and shotunit.character_specific_state.ammo == 2, "exception readiness applied, no fictional shotgun attack")
	f.battle.free()

func test_enemy_retreat_and_automatic() -> void:
	groups += 1
	var f: Dictionary = fixture()
	pause(f,20)
	var plan: EnemyTurningPlan = make_plan(f, EnemyTurningPlan.MOVE)
	f.tp.current.enemy_plans.assign([plan])
	f.tp.current.remaining_real_time = 0.5
	var at: float = f.battle.clock.elapsed
	f.battle.simulate(0.5)
	verify(f.tp.resolve_count == 1 and f.tp.current.resolved and f.battle.clock.state == BattleClock.State.NORMAL, "automatic shared resolve")
	verify(plan.executed and not f.battle.finished and f.battle.result == null, "enemy move is not BattleEndReason.RETREAT")
	var enemy: BattleUnit = f.battle.units[2]
	verify(not enemy.strategy_dash.is_empty(), "move strategy dashes")
	verify(enemy.position.is_finite() and enemy.position.x >= 28 and enemy.position.x <= 772, "dash bounds finite")
	verify(not enemy.combat.can_start(enemy, f.battle.units[0]), "dash blocks attacks")
	var before: Vector2 = enemy.position
	f.battle.simulate(0.1)
	verify(enemy.position != before and not f.battle.finished, "enemy move dash explicit movement")
	verify(f.tp.next_at == 42 and is_equal_approx(f.battle.clock.elapsed, at + 0.2), "automatic resume uses capped frame, excludes strategy wall time")
	for frame in range(30):
		if not enemy.strategy_dash.is_empty(): f.battle.simulate(1.0/60)
	verify(enemy.strategy_dash.is_empty() and enemy.position.distance_to(CharacterPersistence.vector(plan.metadata.to)) < 2, "dash ends on the shown path end")
	for frame in range(90): f.battle.simulate(1.0/60)
	enemy.command_retreat_until = f.battle.clock.elapsed + 3
	verify(f.session.request_retreat(), "whole battle retreat after enemy move")
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

func test_special_strategies(legacy: bool) -> void:
	groups += 1
	var mode: String = " (legacy)" if legacy else " (full)"
	verify(EnemyStrategyPlanner.progress(0) == 0 and EnemyStrategyPlanner.progress(14) == 1 and EnemyStrategyPlanner.act_chance(0) < EnemyStrategyPlanner.act_chance(1), "chance grows with tower progress")
	var f: Dictionary = fixture(legacy)
	pause(f)
	var ally: BattleUnit = f.battle.units[0]
	var enemy: BattleUnit = f.battle.units[2]
	# Situations: hurt and next to a foe.
	enemy.current_hp = enemy.max_hp * .3
	ally.position = enemy.position + Vector2(-70, 0)
	var rng := RandomNumberGenerator.new()
	var used := [0, 0]
	var kinds: Dictionary = {}
	for i in range(400):
		rng.seed = i
		for side in range(2):
			var plan: EnemyTurningPlan = EnemyStrategyPlanner.plan(enemy, float(side), rng)
			if plan == null: continue
			used[side] += 1
			kinds[plan.plan_type] = true
			if side == 1 and plan.plan_type == EnemyTurningPlan.HEAL: verify(is_equal_approx(plan.metadata.amount, .3), "heal stronger on the top floor" + mode)
	verify(used[0] > 25 and used[0] < 80 and used[1] > used[0] * 3, "few enemies act early, many later" + mode)
	verify(kinds.has(EnemyTurningPlan.HEAL) and kinds.has(EnemyTurningPlan.SMASH) and not kinds.has(EnemyTurningPlan.MOVE), "hurt melee next to a foe heals or smashes, no walk-in" + mode)
	# Heal and charge resolve at once.
	var heal := make_plan(f, EnemyTurningPlan.HEAL); heal.metadata = {"amount": .2}
	var charge := make_plan(f, EnemyTurningPlan.CHARGE, 3); charge.metadata = {"gauge": 20.0}
	var gauge: float = f.battle.units[3].ultimate_gauge
	# Smash: the ally stands in the fan in front.
	var smash := make_plan(f, EnemyTurningPlan.SMASH)
	smash.metadata = {"angle": PI, "range": 150.0, "damage": 30.0, "stun": 2.0}
	f.tp.current.enemy_plans.assign([heal, charge, smash])
	verify(f.tp.resolve(), "resolve runs strategies" + mode)
	verify(is_equal_approx(enemy.current_hp, enemy.max_hp * .5), "heal 20% max HP" + mode)
	verify(f.battle.units[3].ultimate_gauge >= gauge + 20 - .01, "charge 20%" + mode)
	verify(not enemy.strategy_cast.is_empty(), "smash winds up" + mode)
	var hp: float = ally.current_hp
	for frame in range(30): f.battle.simulate(1.0 / 60)
	verify(ally.current_hp == hp and not enemy.strategy_cast.is_empty(), "nothing lands during the warning" + mode)
	for frame in range(12): f.battle.simulate(1.0 / 60)
	verify(ally.current_hp < hp and ally.stun_remaining > 1.5 and enemy.strategy_cast.is_empty(), "smash hits and stuns 2s" + mode)
	f.battle.free()
	# Cleave: dash along the path, hitting the ally on it once.
	f = fixture(legacy)
	pause(f)
	ally = f.battle.units[0]
	enemy = f.battle.units[2]
	ally.position = enemy.position + Vector2(-180, 0)
	ally.parry_cooldown = 999 # a parry would knock the dasher back (covered elsewhere)
	var cleave := make_plan(f, EnemyTurningPlan.CLEAVE)
	var end: Vector2 = enemy.position + Vector2(-300, 0)
	cleave.metadata = {"from": CharacterPersistence.point(enemy.position), "to": CharacterPersistence.point(end), "width": 64.0, "damage": 25.0}
	f.tp.current.enemy_plans.assign([cleave])
	f.tp.resolve()
	hp = ally.current_hp
	for frame in range(60): f.battle.simulate(1.0 / 60)
	verify(ally.current_hp < hp and hp - ally.current_hp <= 25 * 1.6, "cleave hits the ally on the path once" + mode)
	verify(enemy.strategy_cast.is_empty() and enemy.position.distance_to(end) < 40, "cleave ends at the path end" + mode)
	f.battle.free()
	# A stun during the warning cancels the attack.
	f = fixture(legacy)
	pause(f)
	ally = f.battle.units[0]
	enemy = f.battle.units[2]
	ally.position = enemy.position + Vector2(-70, 0)
	smash = make_plan(f, EnemyTurningPlan.SMASH)
	smash.metadata = {"angle": PI, "range": 150.0, "damage": 30.0, "stun": 2.0}
	f.tp.current.enemy_plans.assign([smash])
	f.tp.resolve()
	f.battle.simulate(1.0 / 60)
	StatusController.stun(enemy, 1)
	hp = ally.current_hp
	for frame in range(60): f.battle.simulate(1.0 / 60)
	verify(enemy.strategy_cast.is_empty() and ally.stun_remaining <= 0 and ally.current_hp == hp, "stun cancels a winding-up strategy" + mode)
	f.battle.free()

## Grades, intensity and the three new strategies.
func test_strategy_grades(legacy: bool) -> void:
	groups += 1
	var mode: String = " (legacy)" if legacy else " (full)"
	verify(EnemyStrategyPlanner.intensity(4, &"boss") > EnemyStrategyPlanner.intensity(4, &"miniboss") and EnemyStrategyPlanner.intensity(4, &"miniboss") > EnemyStrategyPlanner.intensity(4) and EnemyStrategyPlanner.intensity(10) > EnemyStrategyPlanner.intensity(4), "intensity grows with chapter and room weight")
	verify(EnemyStrategyPlanner.act_chance(.5, 2) > EnemyStrategyPlanner.act_chance(.5, 10) and EnemyStrategyPlanner.act_chance(.5, 4, &"boss") > EnemyStrategyPlanner.act_chance(.5, 4), "fewer enemies or a boss act more often")
	verify(EnemyStrategyPlanner.tier_weights(0)[EnemyTurningPlan.HIGH] == 0 and EnemyStrategyPlanner.tier_weights(1)[EnemyTurningPlan.HIGH] > EnemyStrategyPlanner.tier_weights(.5)[EnemyTurningPlan.HIGH] and EnemyStrategyPlanner.high_cap(0) == 0 and EnemyStrategyPlanner.high_cap(1.3, &"boss") == 3, "고위험 only later, more of it in boss rooms")
	verify(EnemyTurningPlan.TIERS[EnemyTurningPlan.EVADE] == EnemyTurningPlan.NORMAL and EnemyTurningPlan.TIERS[EnemyTurningPlan.SLASH] == EnemyTurningPlan.NORMAL and EnemyTurningPlan.TIERS[EnemyTurningPlan.SWEEP] == EnemyTurningPlan.HIGH, "grades of the new strategies")
	var f: Dictionary = fixture(legacy)
	pause(f)
	var ally: BattleUnit = f.battle.units[0];var enemy: BattleUnit = f.battle.units[2]
	ally.position = enemy.position + Vector2(-90, 0)
	var rng := RandomNumberGenerator.new();var grades: Array = [{}, {}];var kinds: Dictionary = {}
	for i in range(600):
		rng.seed = i
		for side in range(2):
			var plan: EnemyTurningPlan = EnemyStrategyPlanner.plan(enemy, [0.0, 1.3][side], rng, 1)
			if plan == null:continue
			grades[side][plan.tier()] = int(grades[side].get(plan.tier(), 0)) + 1;kinds[plan.plan_type] = true
			if plan.plan_type == EnemyTurningPlan.SWEEP:verify(plan.metadata.has("gather") and float(plan.metadata.windup) == EnemyTurningPlan.WINDUP_HIGH, "sweep has a gather point and a longer warning" + mode)
	verify(not grades[0].has(EnemyTurningPlan.HIGH) and grades[1].get(EnemyTurningPlan.HIGH, 0) > grades[0].get(EnemyTurningPlan.DANGER, 0), "no 고위험 early; plenty late" + mode)
	verify(kinds.has(EnemyTurningPlan.SLASH) and kinds.has(EnemyTurningPlan.SWEEP), "slash and sweep are chosen next to a foe" + mode)
	for i in range(200):
		rng.seed = i;var held: EnemyTurningPlan = EnemyStrategyPlanner.plan(enemy, 1.3, rng, 1, &"normal", false)
		if held != null and held.tier() == EnemyTurningPlan.HIGH:verify(false, "high cap respected" + mode);break
	# Slash: one hit inside its circle after the warning.
	var slash := make_plan(f, EnemyTurningPlan.SLASH)
	slash.metadata = {"center": CharacterPersistence.point(ally.position), "radius": 80.0, "damage": 30.0}
	f.tp.current.enemy_plans.assign([slash]);f.tp.resolve()
	var hp: float = ally.current_hp
	for frame in range(30): f.battle.simulate(1.0 / 60)
	verify(ally.current_hp == hp and not enemy.strategy_cast.is_empty(), "slash waits through its warning" + mode)
	for frame in range(12): f.battle.simulate(1.0 / 60)
	verify(ally.current_hp < hp and enemy.strategy_cast.is_empty(), "slash lands in its circle" + mode)
	f.battle.free()
	# Sweep: hits everyone in the wide circle and drags them to the gather point.
	f = fixture(legacy);pause(f)
	ally = f.battle.units[0];enemy = f.battle.units[2];var other: BattleUnit = f.battle.units[1]
	ally.position = enemy.position + Vector2(-150, 80);other.position = enemy.position + Vector2(-150, -80)
	ally.parry_cooldown = 999;other.parry_cooldown = 999;ally.defense_cooldown = 999;other.defense_cooldown = 999
	var gather: Vector2 = enemy.position + Vector2(-60, 0)
	var sweep := make_plan(f, EnemyTurningPlan.SWEEP)
	sweep.metadata = {"center": CharacterPersistence.point(enemy.position), "radius": 210.0, "gather": CharacterPersistence.point(gather), "damage": 20.0, "windup": 1.0}
	f.tp.current.enemy_plans.assign([sweep]);f.tp.resolve()
	var before: Array = [ally.position.distance_to(gather), other.position.distance_to(gather)];hp = ally.current_hp
	for frame in range(48): f.battle.simulate(1.0 / 60)
	verify(ally.current_hp == hp, "sweep holds a longer warning" + mode)
	for frame in range(40): f.battle.simulate(1.0 / 60)
	verify(ally.current_hp < hp and ally.position.distance_to(gather) < before[0] * .6 and other.position.distance_to(gather) < before[1] * .6, "sweep hits and drags units together" + mode)
	f.battle.free()
	# Evade: a dash to the marked spot.
	f = fixture(legacy);pause(f)
	enemy = f.battle.units[2]
	var evade := make_plan(f, EnemyTurningPlan.EVADE)
	var spot: Vector2 = enemy.position + Vector2(0, 180)
	evade.metadata = {"from": CharacterPersistence.point(enemy.position), "to": CharacterPersistence.point(spot)}
	f.tp.current.enemy_plans.assign([evade]);f.tp.resolve()
	for frame in range(40): f.battle.simulate(1.0 / 60)
	verify(enemy.position.distance_to(spot) < 40, "evade moves to its spot" + mode)
	f.battle.free()

func run(tree: SceneTree) -> void:
	host = tree
	test_clock_and_schedule()
	test_frozen_state_and_stance()
	test_plans_and_overcharge()
	test_enemy_retreat_and_automatic()
	test_end_priority_and_retreat()
	test_overshoot_and_dead_sides()
	for legacy in [true, false]: test_special_strategies(legacy)
	for legacy in [true, false]: test_strategy_grades(legacy)
	print("PHASE 5 RESULT: ", groups, " test groups; ", checks, " checks; ", failures, " failures")

func legacy_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.common_combat_enabled = false
	manager.full_characters_enabled = false
	return manager
