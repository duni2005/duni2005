class_name Phase2Tests
extends RefCounted
## Added suite. Phase 1 test functions remain unchanged in test_runner.gd.

const STEP: float = 1.0 / 60.0
var checks: int = 0
var failures: int = 0
var groups: int = 0
var host: SceneTree

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PHASE 2 FAIL: " + message)

func battle_node() -> BattleManager:
	var battle := legacy_manager()
	battle.auto_start = false
	battle.set_physics_process(false)
	host.root.add_child(battle)
	return battle

func deploy(member: GuildMemberState, at: Vector2) -> Dictionary:
	return {"member_id": member.member_id, "position": at}

func enemy(data: UnitData, at: Vector2) -> Dictionary:
	return {"data": data, "team": 1, "position": at}

func unit_for(battle: BattleManager, member: GuildMemberState) -> BattleUnit:
	for unit in battle.units:
		if unit.source_member_id == member.member_id:
			return unit
	return null

func finish_naturally(battle: BattleManager) -> void:
	for frame in range(180 * 60):
		if battle.finished:
			break
		battle.simulate(STEP)
	verify(battle.finished, "member battle finishes through the real combat loop")

func test_registry() -> void:
	groups += 1
	var guild := GuildManager.new()
	var ids: Dictionary = {}
	for number in range(50):
		var member: GuildMemberState = guild.create_member(number % 2)
		verify(member != null and not ids.has(member.member_id), "every member ID is unique")
		ids[member.member_id] = true
		verify(guild.get_member(member.member_id) == member, "lookup preserves individual member identity")
		verify(member.level == 0 and member.stars == 0 and member.energy == 5 and member.stance == CombatStance.NORMAL, "web recruitment defaults without recruitment features")
	verify(guild.all_members().size() == 50 and guild.living_members().size() == 50, "all/living roster access")
	var first: GuildMemberState = guild.get_member("member_000001")
	var other: GuildMemberState = guild.get_member("member_000003")
	first.member_id = "accidental_reassignment"
	verify(first.member_id == "member_000001" and guild.get_member(first.member_id) == first, "registered identity cannot drift")
	var shared_input: Dictionary = {"nested": {"counter": 1}}
	first.character_specific_state = shared_input
	other.character_specific_state = shared_input
	first.character_specific_state.nested.counter = 3
	verify(other.character_specific_state.nested.counter == 1 and shared_input.nested.counter == 1, "assigning one input dictionary to two members still deep-copies state")
	first.character_specific_state = {}
	other.character_specific_state = {}
	first.current_hp = 43
	first.ultimate_gauge = 37
	first.transcendence_gauge = 18
	first.character_specific_state["test_counter"] = 3
	verify(other.current_hp == 150 and other.ultimate_gauge == 0 and other.transcendence_gauge == 0 and other.character_specific_state.is_empty(), "same type has independent HP/gauges/dictionaries")
	verify(not guild.register_member(first), "duplicate registration rejected")
	verify(guild.create_member(26) == null, "unported type is not silently guessed")
	var restarted_manager := GuildManager.new(guild.state)
	var next: GuildMemberState = restarted_manager.create_member(0)
	verify(next.member_id == "member_000051" and next.member_id != first.member_id, "ID counter belongs to run, not manager/Node lifetime")
	var external := GuildMemberState.new()
	external.member_id = "imported_member"
	external.unit_type_id = 1
	external.current_hp = 0
	verify(guild.register_member(external) and guild.get_member(external.member_id) == external, "register pure dead member state without deleting it")
	verify(not guild.living_members().has(external), "registered dead member excluded from living list")
	print("PASS Phase 2 registry, unique IDs, independent state and run-owned counter")

func test_injection_snapshot_and_settlement() -> void:
	groups += 1
	var guild := GuildManager.new()
	var a: GuildMemberState = guild.create_member(0)
	var b: GuildMemberState = guild.create_member(0)
	var reserve: GuildMemberState = guild.create_member(1)
	a.current_hp = 43
	a.ultimate_gauge = 37
	a.transcendence_gauge = 26
	a.stance = CombatStance.CAUTIOUS
	a.level = 3
	a.stars = 1
	a.character_specific_state = {"test_counter": 3, "nested": {"numbers": [1, 2]}}
	b.current_hp = 129
	b.ultimate_gauge = 82
	b.transcendence_gauge = 9
	b.stance = CombatStance.RUSH
	reserve.current_hp = 57
	reserve.energy = 2
	var battle := battle_node()
	verify(battle.start_guild_battle(guild, [deploy(a, Vector2(160, 260)), deploy(b, Vector2(160, 540))], [enemy(BattleManager.ARCHER, Vector2(640, 400))], 29), "start only the selected members")
	var ua: BattleUnit = unit_for(battle, a)
	var ub: BattleUnit = unit_for(battle, b)
	verify(ua.data == ub.data and ua.data == GuildManager.WARRIOR, "same type uses the same immutable UnitData")
	verify(ua.source_member_id == a.member_id and str(ua.battle_id) != a.member_id, "member identity is separate from per-battle identity")
	verify(ua.current_hp == 43 and ub.current_hp == 129, "distinct HP injected, never reset to max")
	verify(ua.ultimate_gauge == 37 and ua.transcendence_gauge == 26 and ub.ultimate_gauge == 82 and ub.transcendence_gauge == 9, "distinct gauges injected")
	verify(ua.energy == 5 and ua.stance == CombatStance.CAUTIOUS and ub.stance == CombatStance.RUSH, "energy and stance injected as data only")
	verify(ua.character_specific_state.test_counter == 3, "character state injected")
	ua.character_specific_state.nested.numbers[0] = 99
	ua.current_hp = 21
	ua.ultimate_gauge = 48
	ua.transcendence_gauge = 61
	ua.stance = CombatStance.COVER
	verify(a.character_specific_state.nested.numbers[0] == 1 and a.current_hp == 43 and ub.current_hp == 129, "battle mutation cannot alias member/other-unit state")
	verify(a.ultimate_gauge == 37 and b.ultimate_gauge == 82, "battle gauge mutation is isolated until settlement")
	battle.damage_resolver.apply(ua, battle.units[-1], 9999)
	battle.check_outcome()
	var result: BattleResult = battle.result
	verify(result.completed and result.participating_member_ids == [a.member_id, b.member_id], "result contains exact actual participant IDs")
	verify(result.surviving_member_ids == [a.member_id, b.member_id] and result.dead_member_ids.is_empty(), "result includes members only, not test enemies")
	verify(result.final_hp_by_member_id[a.member_id] == 21 and result.final_hp_by_member_id[b.member_id] == 129, "per-member final HP")
	verify(UnitStateCodec.is_pure_data(result.member_states), "persistent snapshots contain no Nodes/Resources")
	var saved: Dictionary = result.member_states[a.member_id]
	for key in ["position", "target", "combat_state", "cooldown", "battle_id", "movement_state", "attack"]:
		verify(not saved.has(key), "battle-only field excluded: " + key)
	ua.character_specific_state.nested.numbers[0] = 88
	verify(saved.character_specific_state.nested.numbers[0] == 99, "result snapshot detached from live Unit dictionary")
	battle.free() # Settlement must work after scene/Units have been freed.
	var settlement := BattleSettlement.new()
	verify(settlement.apply(result, guild) == BattleSettlement.Status.APPLIED, "settle detached result after freeing scene")
	verify(a.current_hp == 21 and b.current_hp == 129 and reserve.current_hp == 57, "HP recovered for participants only, no automatic victory heal")
	verify(a.ultimate_gauge == 48 and a.transcendence_gauge == 61 and b.ultimate_gauge == 82 and b.transcendence_gauge == 9, "both gauge fields restored independently")
	verify(a.stance == CombatStance.COVER and b.stance == CombatStance.RUSH, "stance restored per member")
	verify(a.character_specific_state.test_counter == 3 and a.character_specific_state.nested.numbers[0] == 99, "deep character state round trip")
	verify(a.level == 3 and a.stars == 1, "growth metadata remains untouched")
	verify(a.energy == 4 and b.energy == 4 and reserve.energy == 3, "participants -1, reserve +1")
	result.member_states[a.member_id].character_specific_state.nested.numbers[0] = 77
	verify(a.character_specific_state.nested.numbers[0] == 99, "member dictionary detached from result dictionary")
	a.current_hp = 19
	verify(BattleSettlement.new().apply(result, GuildManager.new(guild.state)) == BattleSettlement.Status.ALREADY_SETTLED, "new manager/settler cannot repeat settlement")
	verify(a.energy == 4 and reserve.energy == 3 and a.current_hp == 19, "duplicate result changes neither energy nor later HP")
	print("PASS Phase 2 injection, whitelist/deep snapshots, HP/gauge/stance recovery and idempotency")

func test_two_battles() -> void:
	groups += 1
	var guild := GuildManager.new()
	var wa: GuildMemberState = guild.create_member(0)
	var wb: GuildMemberState = guild.create_member(0)
	var aa: GuildMemberState = guild.create_member(1)
	var ab: GuildMemberState = guild.create_member(1)
	wb.current_hp = 91
	wb.energy = 1
	aa.current_hp = 80
	aa.energy = 1
	ab.current_hp = 67
	ab.energy = 3
	wa.ultimate_gauge = 37
	aa.transcendence_gauge = 42
	var first := battle_node()
	verify(first.start_guild_battle(guild, [deploy(wa, Vector2(330, 400)), deploy(aa, Vector2(200, 430))], [enemy(BattleManager.WARRIOR, Vector2(500, 400))], 29), "first actual battle starts")
	finish_naturally(first)
	verify(unit_for(first, wa).alive and unit_for(first, aa).alive, "two-round fixture's deployed members survive round one")
	verify(unit_for(first, wa).current_hp < 150, "real round-one attacks cause HP loss")
	var first_result: BattleResult = first.result
	verify(BattleSettlement.new().apply(first_result, guild) == BattleSettlement.Status.APPLIED, "first battle settlement")
	var first_wa_hp: float = wa.current_hp
	var first_aa_hp: float = aa.current_hp
	verify(wb.current_hp == 91 and ab.current_hp == 67, "round-one reserves retain their separate HP")
	verify(wa.energy == 4 and aa.energy == 0 and wb.energy == 2 and ab.energy == 4, "round-one energy uses actual participant IDs")
	var first_id: String = first.battle_result_id
	first.free()
	var second := battle_node()
	verify(second.start_guild_battle(guild, [deploy(wa, Vector2(160, 260)), deploy(wb, Vector2(160, 540)), deploy(aa, Vector2(80, 400))], [enemy(BattleManager.ARCHER, Vector2(680, 400))], 101), "second battle includes energy-zero archer")
	verify(second.battle_result_id != first_id, "each battle has a distinct settlement ID")
	verify(unit_for(second, wa).current_hp == first_wa_hp and unit_for(second, aa).current_hp == first_aa_hp, "previous final HP is exactly the next starting HP")
	verify(unit_for(second, wb).current_hp == 91 and ab.current_hp == 67, "same-type reserve HP never mixes with returning member")
	verify(unit_for(second, aa).energy == 0 and unit_for(second, aa).alive, "energy zero does not block participation")
	verify(unit_for(second, wa).source_member_id == wa.member_id and unit_for(second, aa).source_member_id == aa.member_id, "member IDs remain stable across battles")
	verify(unit_for(second, wa).ultimate_gauge == 37 and unit_for(second, aa).transcendence_gauge == 42, "gauges never reset between battles")
	finish_naturally(second)
	verify(BattleSettlement.new().apply(second.result, guild) == BattleSettlement.Status.APPLIED, "second battle settlement")
	verify(wa.current_hp == second.result.final_hp_by_member_id[wa.member_id] and wb.current_hp == second.result.final_hp_by_member_id[wb.member_id] and aa.current_hp == second.result.final_hp_by_member_id[aa.member_id], "round-two HP belongs to the right members")
	verify(wa.energy == 3 and wb.energy == 1 and aa.energy == 0 and ab.energy == 5, "second participation and energy floor/ceiling")
	verify(ab.current_hp == 67 and guild.all_members().size() == 4, "unselected reserve HP and roster remain unchanged")
	var hp_after_second: float = wa.current_hp
	verify(BattleSettlement.new().apply(first_result, guild) == BattleSettlement.Status.ALREADY_SETTLED and wa.current_hp == hp_after_second, "late round-one result cannot overwrite round-two HP")
	print("PASS Phase 2 real two-battle HP continuity; warrior HP ", first_wa_hp, " -> next battle ", hp_after_second)
	second.free()

func test_death_energy_and_refusals() -> void:
	groups += 1
	var guild := GuildManager.new()
	var killed: GuildMemberState = guild.create_member(0)
	var survivor: GuildMemberState = guild.create_member(0)
	var reserve: GuildMemberState = guild.create_member(1)
	var dead_reserve: GuildMemberState = guild.create_member(1)
	killed.energy = 5
	survivor.energy = 3
	reserve.energy = 5
	dead_reserve.current_hp = 0
	dead_reserve.energy = 1
	var battle := battle_node()
	verify(battle.start_guild_battle(guild, [deploy(killed, Vector2(150, 260)), deploy(survivor, Vector2(150, 540))], [enemy(BattleManager.WARRIOR, Vector2(650, 400))]), "members spawn before casualty settlement")
	var killer: BattleUnit = battle.units[-1]
	battle.damage_resolver.apply(killer, unit_for(battle, killed), 9999)
	battle.damage_resolver.apply(unit_for(battle, survivor), killer, 9999)
	battle.check_outcome()
	verify(battle.result.participating_member_ids == [killed.member_id, survivor.member_id], "participation includes a member who died")
	verify(battle.result.dead_member_ids == [killed.member_id] and battle.result.surviving_member_ids == [survivor.member_id], "dead/surviving member IDs are exact")
	verify(BattleSettlement.new().apply(battle.result, guild) == BattleSettlement.Status.APPLIED, "settle member death")
	verify(killed.current_hp == 0 and not killed.is_alive() and guild.get_member(killed.member_id) == killed, "death stores HP zero without deleting member")
	verify(guild.all_members().size() == 4 and not guild.living_members().has(killed) and not guild.living_members().has(dead_reserve), "roster retains dead members but living list excludes them")
	verify(killed.energy == 4 and survivor.energy == 2 and reserve.energy == 5, "death still consumes participation; energy stays within 0..5")
	verify(dead_reserve.energy == 2 and dead_reserve.current_hp == 0, "web nonparticipating dead member regains energy, not HP")
	verify(BattleUnitFactory.guild_placement(guild, killed.member_id, Vector2(100, 100)).is_empty(), "factory refuses dead members")
	var rejected := battle_node()
	verify(not rejected.start_guild_battle(guild, [deploy(killed, Vector2(100, 100))], [enemy(BattleManager.WARRIOR, Vector2(600, 600))]) and rejected.units.is_empty() and not rejected.started, "dead-member start rejected without partial creation")
	verify(not rejected.start_guild_battle(guild, [deploy(survivor, Vector2(100, 100)), deploy(survivor, Vector2(200, 100))], []) and rejected.units.is_empty(), "same individual cannot occupy two battle slots")
	verify(not rejected.start_guild_battle(guild, [{"member_id": "missing_member", "position": Vector2(100, 100)}], []), "unknown member is not guessed")
	verify(not rejected.start_guild_battle(guild, [deploy(survivor, Vector2(NAN, INF))], []), "invalid member spawn position rejected")
	killed.energy = -20
	reserve.energy = 20
	verify(killed.energy == 0 and reserve.energy == 5, "energy clamps even on direct assignment")
	print("PASS Phase 2 death retention, energy bounds, dead/duplicate/unknown spawn rejection")
	rejected.free()
	battle.free()

func test_policy_and_atomic_validation() -> void:
	groups += 1
	var guild := GuildManager.new()
	var a: GuildMemberState = guild.create_member(0)
	var b: GuildMemberState = guild.create_member(1)
	a.ultimate_gauge = 137
	a.transcendence_gauge = -4
	a.stance = &"invalid_stance"
	verify(a.ultimate_gauge == 100 and a.transcendence_gauge == 0 and a.stance == CombatStance.NORMAL, "gauges clamp 0..100 and invalid stance becomes normal")
	for stance in CombatStance.VALUES:
		a.stance = stance
		verify(a.stance == stance, "all four canonical stance IDs are valid")
	var node := Node.new()
	a.character_specific_state = {"bad": node}
	verify(not UnitStateCodec.can_spawn(a, GuildManager.WARRIOR), "object reference is rejected at persistent-state boundary")
	a.character_specific_state = {"test_counter": 3}
	node.free()
	var battle := battle_node()
	verify(battle.start_guild_battle(guild, [deploy(a, Vector2(100, 100)), deploy(b, Vector2(100, 200))], [enemy(BattleManager.ARCHER, Vector2(700, 400))]), "valid state starts")
	verify(BattleSettlement.new().apply(BattleResult.new(), guild) == BattleSettlement.Status.INVALID_RESULT, "unfinished result cannot settle")
	unit_for(battle, a).current_hp = 40
	battle.damage_resolver.apply(unit_for(battle, a), battle.units[-1], 9999)
	battle.check_outcome()
	var result: BattleResult = battle.result
	var original_hp: float = b.current_hp
	var valid_snapshot: Dictionary = result.member_states[b.member_id].duplicate(true)
	result.member_states[b.member_id].current_hp = NAN
	verify(BattleSettlement.new().apply(result, guild) == BattleSettlement.Status.INVALID_STATE, "corrupt second participant refuses whole settlement")
	verify(a.current_hp == 150 and b.current_hp == original_hp and a.energy == 5 and not guild.state.settled_battle_ids.has(result.battle_result_id), "failed settlement leaves all HP/energy/ledger unchanged")
	result.member_states[b.member_id] = valid_snapshot
	var foreign := GuildManager.new()
	var same_id: GuildMemberState = foreign.create_member(0)
	verify(same_id.member_id == a.member_id and foreign.state.run_id != guild.state.run_id, "member IDs are namespaced by run")
	verify(BattleSettlement.new().apply(result, foreign) == BattleSettlement.Status.FOREIGN_RUN and same_id.current_hp == 150 and same_id.energy == 5, "cannot apply same-looking member ID to another run")
	verify(BattleSettlement.new().apply(result, guild) == BattleSettlement.Status.APPLIED and a.current_hp == 40, "valid repaired result applies after previous refusal")
	var replay := BattleResult.new()
	replay.completed = true
	replay.battle_result_id = result.battle_result_id
	replay.source_run_id = result.source_run_id
	replay.participating_member_ids = result.participating_member_ids.duplicate()
	verify(BattleSettlement.new().apply(replay, guild) == BattleSettlement.Status.ALREADY_SETTLED and a.energy == 4, "dedup uses stable result ID, not result object identity")
	print("PASS Phase 2 gauge/stance policy, pure data, atomic validation and cross-run/replayed result protection")
	battle.free()

func test_damage_outcome() -> void:
	groups += 1
	var battle := battle_node()
	verify(battle.start_battle([{"data": BattleManager.ARCHER, "team": 0, "position": Vector2(100, 100)}, enemy(BattleManager.WARRIOR, Vector2(700, 700))]), "damage-stage test starts")
	var source: BattleUnit = battle.units[0]
	var target: BattleUnit = battle.units[1]
	var fixture: UnitData = source.data.duplicate()
	fixture.critical_chance = 0
	source.data = fixture
	var normal: DamageOutcome = battle.damage_resolver.resolve(source, target, 15)
	verify(normal.accepted and not normal.critical and normal.attempted_damage == 15 and normal.resolved_damage == 15 and normal.hp_damage == 15, "normal damage stages")
	fixture.critical_chance = 1
	target.current_hp = 3
	var critical: DamageOutcome = battle.damage_resolver.resolve(source, target, 15)
	verify(critical.accepted and critical.critical and critical.attempted_damage == 15 and critical.resolved_damage == 23 and critical.hp_damage == 3, "critical/overkill separates attempted, resolved and actual HP loss")
	battle.check_outcome()
	var rejected: DamageOutcome = battle.damage_resolver.resolve(source, target, 100)
	verify(not rejected.accepted and rejected.hp_damage == 0 and not target.alive, "finished battle rejects new damage")
	verify(DamageResolver.CRITICAL_MULTIPLIER == 1.5 and BattleManager.ARCHER.critical_chance == 0.2, "damage staging did not change shared balance data")
	print("PASS Phase 2 additive damage outcome; legacy numeric apply API preserved")
	battle.free()

func run(tree: SceneTree) -> void:
	host = tree
	test_registry()
	test_injection_snapshot_and_settlement()
	test_two_battles()
	test_death_energy_and_refusals()
	test_policy_and_atomic_validation()
	test_damage_outcome()
	print("PHASE 2 RESULT: ", groups, " test groups; ", checks, " checks; ", failures, " failures")

func legacy_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.common_combat_enabled = false
	manager.full_characters_enabled = false
	return manager
