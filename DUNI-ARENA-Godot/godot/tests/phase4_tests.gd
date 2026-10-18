class_name Phase4Tests
extends RefCounted
var checks: int = 0
var failures: int = 0
var groups: int = 0
var host: SceneTree

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PHASE 4 FAIL: " + message)

func manager() -> BattleManager:
	var battle := legacy_manager()
	battle.auto_start = false
	battle.set_physics_process(false)
	host.root.add_child(battle)
	return battle

func make_guild(count: int = 4) -> GuildManager:
	var guild := GuildManager.new()
	for index in range(count):
		guild.create_member(0 if index < 2 else 1)
	return guild

func make_room(count: int = 3) -> RoomState:
	var room := RoomState.new()
	for index in range(count):
		room.add_enemy("enemy_room_01_%03d" % (index + 1), BattleManager.WARRIOR if index < 2 else BattleManager.ARCHER, Vector2(640, 200 + index * 200))
	return room

func actor(battle: BattleManager, id: String) -> BattleUnit:
	for unit in battle.units:
		if unit.source_member_id == id or unit.source_enemy_id == id:
			return unit
	return null

func plan_for(guild: GuildManager, members: Array[String], room: RoomState) -> DeploymentPlan:
	var blockers: Array[Vector2] = []
	for enemy in room.living_enemies():
		blockers.append(EnemyStateCodec.safe_position(enemy.position))
	var plan := DeploymentPlan.new(guild, blockers)
	for index in range(members.size()):
		verify(plan.place(members[index], Vector2(120, 220 + index * 200)) == DeploymentRules.Code.OK, "valid individual draft for room")
	return plan

func finish_naturally(battle: BattleManager) -> void:
	for frame in range(180 * 60):
		if battle.finished:
			break
		battle.simulate(1.0 / 60.0)
	verify(battle.finished, "real room combat finishes")

func test_retreat_and_retry() -> void:
	groups += 1
	var guild: GuildManager = make_guild()
	var members: Array[GuildMemberState] = guild.all_members()
	members[2].energy = 2
	members[3].energy = 2
	var room: RoomState = make_room()
	var battle: BattleManager = manager()
	var session := RoomBattleSession.new(guild, room)
	var plan: DeploymentPlan = plan_for(guild, [members[0].member_id, members[1].member_id], room)
	verify(not session.request_retreat(), "unstarted retreat is not deployment cancellation")
	verify(session.start(plan, battle, 29), "room attempt starts")
	verify(room.battle_attempt_count == 1 and room.active_result_id == battle.battle_result_id, "attempt tracked only for actual start")
	var a: BattleUnit = actor(battle, members[0].member_id)
	var dead_ally: BattleUnit = actor(battle, members[1].member_id)
	var e0: BattleUnit = actor(battle, "enemy_room_01_001")
	var e1: BattleUnit = actor(battle, "enemy_room_01_002")
	var e2: BattleUnit = actor(battle, "enemy_room_01_003")
	a.receive_damage(107, e1)
	a.position = Vector2(300, 300)
	dead_ally.receive_damage(9999, e1)
	verify(guild.state.player_hp == 95, "warrior death instantly costs base 100 * .05")
	battle.unit_died.emit(dead_ally, e1)
	verify(guild.state.player_hp == 95, "duplicate death event cannot subtract HP again")
	e0.receive_damage(9999, a)
	e1.receive_damage(100, a)
	e2.receive_damage(5, a)
	e1.position = Vector2(280, 400)
	e2.position = Vector2(700, 600)
	e1.ultimate_gauge = 37
	e1.stance = CombatStance.CAUTIOUS
	e1.character_specific_state = {"test_counter": 3, "nested": {"value": 9}}
	e1.combat.cooldown = 0.75
	e1.target = a
	e1.combat.attack_target = a
	e1.combat_state = CombatController.State.WINDUP
	battle.spawn_projectile(e2, PI)
	verify(battle.projectiles.size() == 1, "live projectile exists before retreat snapshot")
	battle.clock.advance(19.999)
	verify(session.retreat.check(battle, guild.state) == RetreatController.Code.TOO_EARLY and not session.request_retreat(), "19.999 simulation seconds rejected")
	verify(not battle.finished and room.enemy_state[e1.source_enemy_id].current_hp == 150, "refused retreat has no snapshot/settlement")
	battle.clock.elapsed = 20.0
	verify(session.retreat.check(battle, guild.state) == RetreatController.Code.OK, "exact >=20 web boundary accepted")
	var old_enemy_battle_id: int = e1.battle_id
	verify(session.request_retreat(), "valid retreat finishes once")
	var result: BattleResult = battle.result
	verify(result.end_reason == BattleEndReason.Value.RETREAT and result.room_id == room.room_id and result.battle_time == 20, "explicit retreat result identities and time")
	verify(result.result_id == battle.battle_result_id and result.winning_team == -1, "new result aliases preserve original API")
	verify(session.settlement_status == BattleSettlement.Status.APPLIED and not room.cleared, "retreat settles but does not clear room")
	verify(members[0].current_hp == 43 and members[1].current_hp == 0, "retreat preserves survivor HP and dead ally remains dead")
	verify(members[0].energy == 4 and members[1].energy == 4 and members[2].energy == 3 and members[3].energy == 3, "retreat participants including dead lose energy; reserves regain")
	verify(guild.state.player_hp == 95 and not guild.state.game_over, "retreat has no extra defeat loss, prior death loss remains")
	verify(room.enemy_state[e0.source_enemy_id].current_hp == 0 and not room.enemy_state[e0.source_enemy_id].alive, "dead enemy remains in room as dead")
	verify(room.enemy_state[e1.source_enemy_id].current_hp == 50 and room.enemy_state[e2.source_enemy_id].current_hp == 100, "remaining enemy HP snapshot exact")
	verify(room.enemy_state[e1.source_enemy_id].position == Vector2(280, 400), "enemy last position persists")
	verify(room.enemy_state[e1.source_enemy_id].ultimate_gauge == 37 and room.enemy_state[e1.source_enemy_id].persistent_state.test_counter == 3, "enemy gauge and pure special state survive")
	verify(room.enemy_state[e1.source_enemy_id].persistent_state.cooldown == 0.75, "web general cooldown persists without active attack")
	verify(result.surviving_enemy_ids.size() == 2 and result.dead_enemy_ids == [e0.source_enemy_id], "result enemy lists classify individual IDs")
	verify(battle.projectiles.is_empty() and a.target == null and e1.combat_state == CombatController.State.IDLE, "runtime attacks/target/projectiles discarded")
	verify(not session.request_retreat(), "repeated retreat rejected")
	var hp_after: float = guild.state.player_hp
	verify(BattleSettlement.new().apply_room(result, guild, room) == BattleSettlement.Status.ALREADY_SETTLED and guild.state.player_hp == hp_after and members[0].energy == 4, "room re-settlement has no duplicated death/energy loss")
	battle.simulate(1)
	verify(a.current_hp == 43 and battle.clock.elapsed == 20, "no mutation after retreat")
	var retry_plan := DeploymentPlan.new(guild, [Vector2(280, 400), Vector2(700, 600)])
	verify(retry_plan.restore(guild.state.last_formation) == 1 and retry_plan.get_entry(members[0].member_id).position == Vector2(120, 220), "ally formation uses START, not end position")
	retry_plan.clear()
	verify(retry_plan.place(members[0].member_id, Vector2(60, 700)) == DeploymentRules.Code.OK and retry_plan.place(members[2].member_id, Vector2(160, 600)) == DeploymentRules.Code.OK, "retry allows a new composition and new positions")
	var retry: BattleManager = manager()
	var next := RoomBattleSession.new(guild, room)
	verify(next.start(retry_plan, retry, 101), "same room retry starts from persisted enemy state")
	verify(room.battle_attempt_count == 2 and retry.battle_result_id != result.result_id, "retry is a fresh battle attempt")
	verify(actor(retry, "enemy_room_01_001") == null and retry.units.size() == 4, "dead enemy never recreated before room clear")
	var restored: BattleUnit = actor(retry, "enemy_room_01_002")
	verify(restored.source_enemy_id == e1.source_enemy_id and restored.battle_id != old_enemy_battle_id, "stable enemy ID, new per-attempt battle instance ID")
	verify(restored.current_hp == 50 and restored.position == Vector2(280, 400) and restored.ultimate_gauge == 37 and restored.stance == CombatStance.CAUTIOUS, "retry enemy injection exact")
	verify(restored.character_specific_state.test_counter == 3 and restored.combat.cooldown == 0.75, "retry persistent dictionary and cooldown restored")
	verify(restored.combat_state == CombatController.State.IDLE and restored.target == null and retry.projectiles.is_empty(), "retry recreates transient execution, not old scene")
	verify(actor(retry, members[0].member_id).position == Vector2(60, 700) and actor(retry, members[0].member_id).current_hp == 43, "ally new deployment position + old HP")
	actor(retry, "enemy_room_01_002").receive_damage(9999, actor(retry, members[0].member_id))
	actor(retry, "enemy_room_01_003").receive_damage(9999, actor(retry, members[0].member_id))
	retry.check_outcome()
	verify(retry.result.end_reason == BattleEndReason.Value.VICTORY and room.cleared, "retry victory clears the existing room")
	verify(members[0].current_hp == 43, "first victory 30% heal remains intentionally excluded")
	verify(not next.can_enter() and not next.request_retreat(), "cleared room cannot retry or retreat")
	verify(BattleSettlement.new().apply_room(retry.result, guild, room) == BattleSettlement.Status.ALREADY_SETTLED, "clear settlement one-time")
	retry.free()
	battle.free()
	print("PASS Phase 4 retreat boundary / dead actors / persistent room retry / victory")

func test_defeat_and_reserves() -> void:
	groups += 1
	var guild: GuildManager = make_guild(3)
	var members: Array[GuildMemberState] = guild.all_members()
	var room: RoomState = make_room(1)
	var battle: BattleManager = manager()
	var session := RoomBattleSession.new(guild, room)
	verify(session.start(plan_for(guild, [members[0].member_id], room), battle, 29), "defeat attempt starts")
	var enemy: BattleUnit = actor(battle, "enemy_room_01_001")
	enemy.receive_damage(73, battle.units[0])
	enemy.position = Vector2(310, 280)
	battle.units[0].receive_damage(9999, enemy)
	verify(guild.state.player_hp == 95, "death loss precedes outcome settlement")
	battle.check_outcome()
	verify(battle.result.end_reason == BattleEndReason.Value.DEFEAT and not room.cleared, "ordinary defeat distinct from room clear")
	verify(guild.state.player_hp == 75, "death cost5 plus defeat penalty20")
	verify(members[0].current_hp == 0 and guild.living_members().size() == 2 and not guild.state.game_over, "reserve survivors mean defeat is not run end")
	verify(room.enemy_state[enemy.source_enemy_id].current_hp == 77 and room.enemy_state[enemy.source_enemy_id].position == Vector2(310, 280), "defeat saves enemy HP and location")
	verify(not session.request_retreat(), "ended defeat cannot retreat")
	var retry: BattleManager = manager()
	var next := RoomBattleSession.new(guild, room)
	verify(next.start(plan_for(guild, [members[1].member_id], room), retry, 101), "another living guild member can retry same room")
	verify(actor(retry, enemy.source_enemy_id).current_hp == 77 and actor(retry, enemy.source_enemy_id).position == Vector2(310, 280), "defeat retry consumes original room state")
	finish_naturally(retry)
	verify(retry.result.end_reason == BattleEndReason.Value.VICTORY and room.cleared, "reserve wins through real unchanged combat loop")
	verify(guild.state.player_hp == 75, "victory has no defeat penalty or automatic player heal")
	verify(BattleSettlement.new().apply_room(battle.result, guild, room) == BattleSettlement.Status.ALREADY_SETTLED, "old defeat replay cannot regress newer clear")
	verify(room.cleared and guild.state.player_hp == 75, "stale result leaves room and HP intact")
	retry.free()
	battle.free()
	print("PASS Phase 4 defeat → reserve retry → natural victory")

func test_game_over() -> void:
	groups += 1
	var guild: GuildManager = make_guild(1)
	var room: RoomState = make_room(1)
	var battle: BattleManager = manager()
	var session := RoomBattleSession.new(guild, room)
	session.start(plan_for(guild, [guild.all_members()[0].member_id], room), battle, 3)
	battle.units[0].receive_damage(9999, battle.units[1])
	battle.check_outcome()
	verify(guild.state.game_over and guild.state.game_over_reason == RunState.GameOverReason.NO_LIVING_MEMBERS and guild.state.player_hp == 75, "no living guild members ends run despite positive player HP")
	verify(not session.can_enter(), "guild wipe cannot retry")
	battle.free()
	guild = make_guild(3)
	guild.state.player_hp = 4
	room = make_room(1)
	battle = manager()
	session = RoomBattleSession.new(guild, room)
	session.start(plan_for(guild, [guild.all_members()[0].member_id, guild.all_members()[1].member_id], room), battle, 3)
	battle.units[0].receive_damage(9999, battle.units[-1])
	verify(guild.state.player_hp == 0 and battle.run_end_requested and not battle.finished, "lethal player HP requests end at physics outcome boundary")
	battle.check_outcome()
	verify(battle.result.end_reason == BattleEndReason.Value.RUN_ENDED and guild.state.game_over_reason == RunState.GameOverReason.PLAYER_HP, "run-HP termination separate from normal battle defeat")
	verify(guild.state.game_over and guild.living_members().size() == 2, "player HP0 ends run even with alive deployed/reserve members")
	verify(battle.result.surviving_member_ids.size() == 1 and not battle.result.enemy_states.is_empty(), "HP game over still snapshots allies and enemies")
	verify(not room.cleared and not session.can_enter() and not session.request_retreat(), "HP game over disallows retry/retreat and does not clear room")
	verify(guild.state.player_hp == 0, "no defeat extra20 after death already depleted HP")
	battle.free()
	guild = make_guild(2)
	guild.state.player_hp = 24
	room = make_room(1)
	battle = manager()
	session = RoomBattleSession.new(guild, room)
	session.start(plan_for(guild, [guild.all_members()[0].member_id], room), battle, 3)
	battle.units[0].receive_damage(9999, battle.units[1])
	battle.check_outcome()
	verify(guild.state.game_over and guild.state.game_over_reason == RunState.GameOverReason.PLAYER_HP and guild.state.player_hp == 0, "defeat extra20 can itself trigger game over")
	battle.free()
	# Archer cost 120 ->6, preserving fractional cost-rate formula without rounding.
	guild = make_guild(3)
	room = make_room(1)
	battle = manager()
	session = RoomBattleSession.new(guild, room)
	session.start(plan_for(guild, [guild.all_members()[2].member_id], room), battle, 3)
	battle.units[0].receive_damage(9999, battle.units[1])
	verify(guild.state.player_hp == 94, "archer death uses current web base cost120 * .05")
	battle.check_outcome()
	verify(guild.state.player_hp == 74, "archer death + ordinary defeat penalty")
	battle.free()
	print("PASS Phase 4 player HP / reserve distinction / game-over reasons")

func test_retreat_invalid_and_draw() -> void:
	groups += 1
	var guild: GuildManager = make_guild(3)
	var room: RoomState = make_room(1)
	var battle: BattleManager = manager()
	var session := RoomBattleSession.new(guild, room)
	session.start(plan_for(guild, [guild.all_members()[0].member_id], room), battle, 3)
	battle.clock.elapsed = 20
	battle.units[0].receive_damage(9999, battle.units[1])
	verify(session.retreat.check(battle, guild.state) == RetreatController.Code.NO_ALLIES, "no alive participant cannot retreat before outcome finalized")
	battle.units[1].receive_damage(9999, null)
	battle.check_outcome()
	verify(battle.result.end_reason == BattleEndReason.Value.DRAW and battle.result.draw, "simultaneous last actors die -> explicit draw")
	verify(guild.state.player_hp == 75 and room.cleared, "web draw: non-victory penalty20 but all enemies dead clear if HP remains")
	verify(not session.request_retreat(), "all-dead ended combat cannot retreat")
	battle.free()
	guild = make_guild(2)
	room = make_room(1)
	battle = manager()
	session = RoomBattleSession.new(guild, room)
	session.start(plan_for(guild, [guild.all_members()[0].member_id], room), battle, 3)
	battle.clock.elapsed = 21
	battle.units[1].receive_damage(9999, battle.units[0])
	verify(session.retreat.check(battle, guild.state) == RetreatController.Code.NO_ENEMIES, "enemy wipe cannot be turned into retreat")
	battle.check_outcome()
	verify(battle.result.end_reason == BattleEndReason.Value.VICTORY, "enemy wipe stays victory")
	battle.free()
	print("PASS Phase 4 unavailable retreat and web draw exceptions")

func test_codec_and_atomicity() -> void:
	groups += 1
	verify(RunState.new().player_hp == 100 and RunState.new().player_max_hp == 100, "web newTowerState player HP100")
	verify(EnemyStateCodec.safe_position(Vector2(-10, 900)) == Vector2(28, 772), "finite outside enemy position clamps to actual movement bounds")
	verify(EnemyStateCodec.safe_position(Vector2(NAN, INF)) == Vector2(640, 400), "nonfinite enemy position has documented safe fallback")
	var guild: GuildManager = make_guild(2)
	var room: RoomState = make_room(1)
	var enemy: EnemyRoomState = room.enemy_state["enemy_room_01_001"]
	enemy.position = Vector2(NAN, INF)
	enemy.ultimate_gauge = 137
	enemy.persistent_state = {"test_counter": 3, "nested": {"array": [2, 3]}, "cooldown": 0.6}
	var battle: BattleManager = manager()
	var session := RoomBattleSession.new(guild, room)
	verify(session.start(plan_for(guild, [guild.all_members()[0].member_id], room), battle, 3), "bad stored enemy coordinate safely recovers at entry")
	var unit: BattleUnit = actor(battle, enemy.enemy_id)
	verify(unit.position == Vector2(640, 400) and unit.ultimate_gauge == 100, "safe position and gauge range injection")
	unit.character_specific_state.nested.array[0] = 99
	verify(enemy.persistent_state.nested.array[0] == 2, "live enemy dictionaries never alias room state")
	var saved: Dictionary = EnemyStateCodec.snapshot(unit)
	verify(UnitStateCodec.is_pure_data(saved.persistent_state), "persistent enemy payload has no Node references")
	for key in ["target", "battle_id", "combat_state", "attack", "projectiles", "scene", "transcendence_gauge"]:
		verify(not saved.has(key), "excluded enemy runtime field: " + key)
	var bad := Node.new()
	unit.character_specific_state["bad"] = bad
	verify(EnemyStateCodec.snapshot(unit).is_empty(), "Node reference rejected at snapshot boundary")
	unit.character_specific_state.erase("bad")
	bad.free()
	battle.clock.elapsed = 21
	verify(session.request_retreat(), "valid pure snapshot retreats")
	verify(enemy.persistent_state.test_counter == 3 and enemy.persistent_state.nested.array[0] == 99, "dictionary round trip retains opaque test values")
	var invalid_room: RoomState = make_room(1)
	var rejected_node := Node.new()
	invalid_room.enemy_state["enemy_room_01_001"].persistent_state = {"node": rejected_node}
	verify(invalid_room.enemy_state["enemy_room_01_001"].persistent_state.is_empty(), "EnemyRoomState refuses Node assignment instead of storing it")
	rejected_node.free()
	invalid_room.enemy_state["enemy_room_01_001"].current_hp = NAN
	var reject: BattleManager = manager()
	var wrong := RoomBattleSession.new(guild, invalid_room)
	verify(not wrong.start(plan_for(guild, [guild.all_members()[0].member_id], invalid_room), reject, 3) and not reject.started and invalid_room.battle_attempt_count == 0, "bad room state rejected without partial spawn/attempt")
	reject.free()
	var foreign := RoomBattleSession.new(make_guild(2), room)
	verify(not foreign.can_enter(), "room owned by one run cannot be reused by another")
	# Simulate invalid completed result before session's normal completion handler.
	var next_battle: BattleManager = manager()
	var next := RoomBattleSession.new(guild, room)
	verify(next.start(plan_for(guild, [guild.all_members()[0].member_id], room), next_battle, 29), "next atomic-validation attempt starts")
	next_battle.battle_finished.disconnect(next._on_finished)
	next_battle.clock.elapsed = 21
	verify(next.request_retreat(), "detached completion produced for validation test")
	var result: BattleResult = next_battle.result
	verify(BattleSettlement.new().apply(result, guild) == BattleSettlement.Status.INVALID_RESULT and not guild.state.settled_battle_ids.has(result.result_id), "legacy guild-only settlement cannot consume a room result")
	var original: Dictionary = result.enemy_states[enemy.enemy_id].duplicate(true)
	var hp_before: float = guild.all_members()[0].current_hp
	var energy_before: int = guild.all_members()[0].energy
	result.enemy_states[enemy.enemy_id].current_hp = NAN
	verify(BattleSettlement.new().apply_room(result, guild, room) == BattleSettlement.Status.INVALID_STATE, "corrupt enemy snapshot atomically rejects settlement")
	verify(guild.all_members()[0].current_hp == hp_before and guild.all_members()[0].energy == energy_before and not guild.state.settled_battle_ids.has(result.result_id), "failed validation does not consume allied state/energy/ledger")
	result.enemy_states[enemy.enemy_id] = original
	verify(BattleSettlement.new().apply_room(result, guild, room) == BattleSettlement.Status.APPLIED, "repaired valid result settles")
	verify(BattleSettlement.new().apply_room(result, guild, room) == BattleSettlement.Status.ALREADY_SETTLED, "duplicate repaired result blocked")
	next_battle.free()
	battle.free()
	print("PASS Phase 4 pure enemy codec / safe coordinates / atomic room settlement")

func test_scene() -> void:
	groups += 1
	var screen: RoomBattleScreen = load("res://scenes/room_battle.tscn").instantiate()
	host.root.add_child(screen)
	verify(screen.room.enemy_state.size() == 3 and screen.guild.all_members().size() == 6, "Phase 4 F5 room/guild debug scene loads")
	verify(screen.board.editing and screen.retreat_button.disabled, "deployment not considered retreat")
	var member: GuildMemberState = screen.guild.all_members()[0]
	screen.plan.place(member.member_id, Vector2(120, 300))
	screen.start_battle()
	verify(screen.battle.started and screen.room.battle_attempt_count == 1, "screen starts room session")
	screen.battle.set_physics_process(false)
	screen.battle.clock.elapsed = 20
	var enemy: BattleUnit = actor(screen.battle, "enemy_room_01_001")
	enemy.current_hp = 61
	enemy.position = Vector2(280, 400)
	screen._process(0)
	verify(not screen.retreat_button.disabled, "screen retreat enables at simulation20")
	screen._retreat()
	verify(screen.battle.result.end_reason == BattleEndReason.Value.RETREAT and screen.settlement_status == BattleSettlement.Status.APPLIED and not screen.next_button.disabled, "screen retreat publishes settled state and retry action")
	screen.begin_deployment()
	verify(screen.board.editing and screen.enemies[0].current_hp == 61 and screen.enemies[0].position == Vector2(280, 400), "screen retry previews actual remaining enemy HP/position")
	verify(screen.plan.get_entry(member.member_id).position == Vector2(120, 300), "screen retry restores ally start formation")
	screen.free()
	print("PASS Phase 4 debug screen retreat / room state / retry preview")

func run(tree: SceneTree) -> void:
	host = tree
	test_retreat_and_retry()
	test_defeat_and_reserves()
	test_game_over()
	test_retreat_invalid_and_draw()
	test_codec_and_atomicity()
	test_scene()
	print("PHASE 4 RESULT: ", groups, " test groups; ", checks, " checks; ", failures, " failures")

func legacy_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.common_combat_enabled = false
	manager.full_characters_enabled = false
	return manager
