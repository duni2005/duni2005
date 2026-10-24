class_name Phase3Tests
extends RefCounted
const STEP: float = 1.0 / 60.0
var checks: int = 0
var failures: int = 0
var groups: int = 0
var host: SceneTree

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PHASE 3 FAIL: " + message)

func member_snapshot(guild: GuildManager) -> Dictionary:
	var snapshot: Dictionary = {}
	for member in guild.all_members():
		snapshot[member.member_id] = {"type": member.unit_type_id, "hp": member.current_hp, "energy": member.energy, "ult": member.ultimate_gauge, "trans": member.transcendence_gauge, "stance": member.stance, "level": member.level, "stars": member.stars, "specific": member.character_specific_state.duplicate(true)}
	return snapshot

func make_battle() -> BattleManager:
	var battle := legacy_manager()
	battle.auto_start = false
	battle.set_physics_process(false)
	host.root.add_child(battle)
	return battle

func enemies() -> Array[Dictionary]:
	return [{"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(650, 400)}]

func finish(battle: BattleManager) -> void:
	for frame in range(180 * 60):
		if battle.finished:
			break
		battle.simulate(STEP)
	verify(battle.finished, "real deployed combat finishes")

func test_rules() -> void:
	groups += 1
	var guild := GuildManager.new()
	var a: GuildMemberState = guild.create_member(0)
	var b: GuildMemberState = guild.create_member(0)
	var dead: GuildMemberState = guild.create_member(1)
	a.energy = 0
	dead.current_hp = 0
	var plan := DeploymentPlan.new(guild)
	verify(plan.place(a.member_id, Vector2(100, 100)) == DeploymentRules.Code.OK, "living energy-zero member deploys")
	verify(plan.place(a.member_id, Vector2(200, 100)) == DeploymentRules.Code.ALREADY_DEPLOYED, "same individual cannot deploy twice")
	verify(plan.place(dead.member_id, Vector2(200, 100)) == DeploymentRules.Code.DEAD_MEMBER, "dead member rejected")
	verify(plan.place("missing", Vector2(200, 100)) == DeploymentRules.Code.UNKNOWN_MEMBER, "unknown ID rejected")
	verify(plan.place(b.member_id, Vector2(157.999, 100)) == DeploymentRules.Code.TOO_CLOSE, "strictly less than 58 rejected")
	verify(plan.place(b.member_id, Vector2(158, 100)) == DeploymentRules.Code.OK, "exactly 58 accepted for same type, different individual")
	verify(plan.entries().size() == 2, "rejected placements have no partial draft changes")
	var old_point: Vector2 = plan.get_entry(b.member_id).position
	verify(plan.move(b.member_id, Vector2(110, 100)) == DeploymentRules.Code.TOO_CLOSE, "move validates other allies")
	verify(plan.get_entry(b.member_id).position == old_point, "invalid move keeps prior position")
	verify(plan.move(a.member_id, Vector2(90, 100)) == DeploymentRules.Code.OK, "move ignores self")
	verify(plan.get_entry(a.member_id).member_id == a.member_id, "move preserves identity")
	verify(plan.move("missing", Vector2(300, 100)) == DeploymentRules.Code.UNKNOWN_MEMBER, "unknown move rejected")
	plan.clear()
	for point in [Vector2(381, 100), Vector2(39, 100), Vector2(100, 39), Vector2(100, 761), Vector2(-1, 100), Vector2(801, 100), Vector2(100, 801)]:
		verify(plan.place(a.member_id, point) == DeploymentRules.Code.OUTSIDE_DEPLOYMENT_ZONE, "outside raw position rejected: " + str(point))
	for point in [Vector2(NAN, 100), Vector2(100, NAN), Vector2(INF, 100), Vector2(100, -INF)]:
		verify(plan.place(a.member_id, point) == DeploymentRules.Code.INVALID_POSITION, "non-finite rejected")
	verify(plan.place(a.member_id, Vector2(40, 40)) == DeploymentRules.Code.OK, "inclusive min corner")
	verify(plan.place(b.member_id, Vector2(380, 760)) == DeploymentRules.Code.OK, "inclusive max corner")
	var blockers: Array[Vector2] = [Vector2(400, 400)]
	var blocked := DeploymentPlan.new(guild, blockers)
	verify(blocked.place(a.member_id, Vector2(380, 400)) == DeploymentRules.Code.TOO_CLOSE, "enemy preview also blocks spacing")
	verify(DeploymentRules.validate(guild, DeploymentEntry.new(a.member_id, Vector2(100, 100), 1), [], []) == DeploymentRules.Code.INVALID_TEAM, "player cannot deploy enemy team")
	verify(plan.remove(a.member_id) and not plan.remove(a.member_id), "remove only draft entry, repeat safe")
	verify(plan.move(a.member_id, Vector2(200, 200)) == DeploymentRules.Code.NOT_DEPLOYED, "move requires actual deployment")
	print("PASS Phase 3 rule boundaries / identities / moves")

func test_invariant_and_capacity() -> void:
	groups += 1
	var guild := GuildManager.new()
	for index in range(30):
		var member: GuildMemberState = guild.create_member(index % 2)
		member.current_hp -= index % 20
		member.energy = index % 6
		member.ultimate_gauge = index
		member.transcendence_gauge = index * 2
		member.level = 2
		member.stars = 1
		member.stance = CombatStance.CAUTIOUS
		member.character_specific_state = {"nested": {"test_counter": 3}}
	var before: Dictionary = member_snapshot(guild)
	var plan := DeploymentPlan.new(guild)
	for index in range(30):
		verify(plan.place(guild.all_members()[index].member_id, Vector2(40 + index % 6 * 60, 40 + int(index / 6) * 60)) == DeploymentRules.Code.OK, "30 survivors deploy without custom 24 cap")
	verify(plan.entries().size() == 30, "tower has no artificial deployment headcount limit")
	var copied: Array[DeploymentEntry] = plan.entries()
	copied[0].position = Vector2(700, 700)
	verify(plan.entries()[0].position == Vector2(40, 40), "returned entries are detached from draft")
	var formation := FormationState.new()
	formation.capture(plan.entries())
	plan.move(guild.all_members()[0].member_id, Vector2(40, 600))
	verify(formation.entries[0].position == Vector2(40, 40), "formation is detached from draft moves")
	plan.remove(guild.all_members()[1].member_id)
	plan.clear()
	verify(member_snapshot(guild) == before, "placement/removal/clear preserves every member field including energy")
	for iteration in range(5):
		verify(plan.restore(formation) == 30, "repeated restoration remains valid")
		verify(member_snapshot(guild) == before, "restoration does not mutate member state")
		plan.clear()
	formation.entries[0].position = Vector2(20, 900)
	verify(member_snapshot(guild) == before, "formation mutation cannot affect member state")
	verify(guild.state.last_formation.entries.is_empty(), "editing/cancelling draft never saves last started formation")
	print("PASS Phase 3 pure-state invariants / >24 placements")

func test_restore() -> void:
	groups += 1
	var guild := GuildManager.new()
	var a: GuildMemberState = guild.create_member(0)
	var b: GuildMemberState = guild.create_member(0)
	var c: GuildMemberState = guild.create_member(1)
	var d: GuildMemberState = guild.create_member(1)
	var formation := FormationState.new()
	formation.entries = [DeploymentEntry.new(a.member_id, Vector2(100, 100)), DeploymentEntry.new(b.member_id, Vector2(100, 100)), DeploymentEntry.new(c.member_id, Vector2(900, -2)), DeploymentEntry.new(d.member_id, Vector2(200, 600)), DeploymentEntry.new("missing", Vector2(250, 600)), DeploymentEntry.new(a.member_id, Vector2(300, 600))]
	d.current_hp = 0
	var plan := DeploymentPlan.new(guild)
	verify(plan.restore(formation) == 3, "restore skips dead/missing/repeated IDs")
	verify(plan.get_entry(a.member_id).position == Vector2(100, 100), "valid saved position unchanged")
	verify(plan.get_entry(b.member_id).position == Vector2(40, 100), "nearest free candidate uses web x/y tie order")
	verify(plan.get_entry(c.member_id).position == Vector2(380, 40), "out-of-bounds restore safely clamps")
	verify(plan.get_entry(d.member_id) == null, "dead individual never restored")
	verify(DeploymentRules.validate_all(guild, plan.entries(), []) == DeploymentRules.Code.OK, "all restored positions satisfy rules")
	var invalid := FormationState.new()
	invalid.entries = [DeploymentEntry.new(a.member_id, Vector2(NAN, INF))]
	verify(plan.restore(invalid) == 0, "nonfinite saved position skipped safely")
	var enemy_positions: Array[Vector2] = [Vector2(100, 100)]
	var near: Dictionary = FormationPositionFinder.find(Vector2(100, 100), [], enemy_positions)
	verify(near.found and near.position == Vector2(40, 100), "enemy occupation gets nearest safe fallback")
	var blocked: Array[Vector2] = []
	for x in range(40, 381, 40):
		for y in range(40, 761, 40):
			blocked.append(Vector2(x, y))
	verify(not FormationPositionFinder.find(Vector2(100, 100), [], blocked).found, "finite exhaustive search reports no space")
	var filled := DeploymentPlan.new(guild, blocked)
	verify(filled.restore(formation) == 0, "no-space restore skips members without loops or overlaps")
	var saved: Array[DeploymentEntry] = formation.snapshot()
	saved[0].position = Vector2.ZERO
	verify(formation.entries[0].position == Vector2(100, 100), "formation snapshot copies pure entries")
	print("PASS Phase 3 restoration / bounded nearest fallback")

func test_battle_bridge() -> void:
	groups += 1
	var guild := GuildManager.new()
	var a: GuildMemberState = guild.create_member(0)
	var b: GuildMemberState = guild.create_member(0)
	var reserve: GuildMemberState = guild.create_member(1)
	a.current_hp = 120
	a.energy = 0
	a.stance = CombatStance.COVER
	a.ultimate_gauge = 37
	b.current_hp = 110
	reserve.current_hp = 61
	reserve.energy = 2
	var plan := DeploymentPlan.new(guild)
	plan.place(a.member_id, Vector2(120.5, 300.25))
	plan.place(b.member_id, Vector2(220.25, 500.5))
	var before: Dictionary = member_snapshot(guild)
	var battle: BattleManager = make_battle()
	verify(plan.launch(battle, enemies(), 29), "valid deployment launches through existing factory")
	verify(battle.units[0].position == Vector2(120.5, 300.25) and battle.units[1].position == Vector2(220.25, 500.5), "continuous starting coordinates transmitted exactly")
	verify(battle.units[0].data == battle.units[1].data and battle.units[0].source_member_id != battle.units[1].source_member_id, "same type shared data, separate positions and identity")
	verify(battle.units[0].current_hp == 120 and battle.units[0].stance == CombatStance.COVER and battle.units[0].ultimate_gauge == 37, "Phase 2 injection preserved without stance effects")
	verify(member_snapshot(guild) == before, "actual start does not change member state")
	verify(guild.state.last_formation.entries.size() == 2, "successful start saves formation")
	plan.move(a.member_id, Vector2(40, 40))
	verify(guild.state.last_formation.entries[0].position == Vector2(120.5, 300.25), "subsequent draft edits cannot alter started formation")
	verify(not plan.launch(battle, enemies()), "running battle cannot start twice")
	finish(battle)
	var final_position: Vector2 = battle.units[0].position
	verify(final_position != Vector2(120.5, 300.25), "battle unit really moves away from start")
	var settlement := BattleSettlement.new()
	verify(settlement.apply(battle.result, guild) == BattleSettlement.Status.APPLIED, "completed battle settles separately from deployment")
	verify(a.energy == 0 and b.energy == 5 and reserve.energy == 2, "settlement no longer touches energy")
	verify(reserve.current_hp == 61, "reserve HP unchanged")
	var after: Dictionary = member_snapshot(guild)
	verify(settlement.apply(battle.result, guild) == BattleSettlement.Status.ALREADY_SETTLED and member_snapshot(guild) == after, "deployment integration preserves one-time settlement")
	var next := DeploymentPlan.new(guild)
	verify(next.restore(guild.state.last_formation) == battle.result.surviving_member_ids.size(), "next draft restores only survivors")
	if a.is_alive():
		verify(next.get_entry(a.member_id).position == Vector2(120.5, 300.25), "next draft uses saved START rather than final movement coordinates")
	if b.is_alive():
		verify(next.get_entry(b.member_id).position == Vector2(220.25, 500.5), "second individual keeps its own starting position")
	verify(member_snapshot(guild) == after, "next draft restore does not consume/restore HP or energy")
	var second: BattleManager = make_battle()
	verify(next.launch(second, enemies(), 101), "restored survivors can start a second new battle")
	for unit in second.units:
		if not unit.source_member_id.is_empty():
			verify(unit.current_hp == guild.get_member(unit.source_member_id).current_hp, "second battle starts with settled HP")
	second.free()
	battle.free()
	print("PASS Phase 3 deployment → combat → settlement → next formation")

func test_failed_start() -> void:
	groups += 1
	var guild := GuildManager.new()
	var member: GuildMemberState = guild.create_member(0)
	guild.state.last_formation.capture([DeploymentEntry.new(member.member_id, Vector2(70, 70))])
	var plan := DeploymentPlan.new(guild)
	var battle: BattleManager = make_battle()
	var before: Dictionary = member_snapshot(guild)
	verify(not plan.launch(battle, enemies()), "empty draft cannot launch")
	verify(guild.state.last_formation.entries[0].position == Vector2(70, 70), "failed start leaves formation unchanged")
	plan.place(member.member_id, Vector2(120, 200))
	member.current_hp = 0
	verify(not plan.launch(battle, enemies()) and battle.units.is_empty(), "late death revalidated atomically before start")
	member.current_hp = before[member.member_id].hp
	var occupying: Array[Dictionary] = [{"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(120, 200)}]
	verify(not plan.launch(battle, occupying), "actual enemy positions revalidated even if preview differs")
	var invalid: Array[Dictionary] = [{"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(NAN, 200)}]
	verify(not plan.launch(battle, invalid), "invalid enemy position cannot start")
	var allied_enemy: Array[Dictionary] = [{"data": BattleManager.WARRIOR, "team": 0, "position": Vector2(650, 400)}]
	verify(not plan.launch(battle, allied_enemy), "enemy deployment cannot impersonate player team")
	verify(not battle.started and battle.units.is_empty() and member_snapshot(guild) == before, "failed starts never spawn/settle/mutate members")
	verify(guild.state.last_formation.entries[0].position == Vector2(70, 70), "all failed requests preserve last successful formation")
	battle.free()
	print("PASS Phase 3 failed start atomicity")

func test_debug_screen() -> void:
	groups += 1
	var screen: DeploymentScreen = load("res://scenes/deployment.tscn").instantiate()
	host.root.add_child(screen)
	verify(screen.guild.all_members().size() == 6 and screen.plan.entries().is_empty(), "F5 debug scene starts with six individual members, no combat")
	var a: GuildMemberState = screen.guild.all_members()[0]
	var b: GuildMemberState = screen.guild.all_members()[1]
	var before: Dictionary = member_snapshot(screen.guild)
	# Lay out board explicitly to exercise coordinate conversion in a headless tree.
	screen.board.size = Vector2(800, 800)
	screen.board.select(a.member_id)
	screen.board.pointer_down(Vector2(120, 240), -1)
	screen.board.pointer_up(Vector2(120, 240), -1)
	verify(screen.plan.get_entry(a.member_id).position == Vector2(120, 240), "PC select + pointer place")
	screen.board.pointer_down(Vector2(120, 240), -1)
	screen.board.pointer_motion(Vector2(200, 250), -1)
	screen.board.pointer_up(Vector2(200, 250), -1)
	verify(screen.plan.get_entry(a.member_id).position == Vector2(200, 250), "PC drag moves same individual")
	screen.board.select(b.member_id)
	screen.board.pointer_down(Vector2(120, 500), 0)
	screen.board.pointer_up(Vector2(120, 500), 0)
	verify(screen.plan.get_entry(b.member_id) != null, "touch placement places the member")
	screen.board.pointer_down(Vector2(120, 500), 0)
	screen.board.pointer_motion(Vector2(200, 500), 0)
	screen.board.pointer_up(Vector2(200, 500), 0)
	verify(screen.plan.get_entry(b.member_id).position == Vector2(200, 500), "touch drag moves placed individual")
	screen.board.pointer_down(Vector2(260, 600), 0)
	screen.board.pointer_up(Vector2(260, 600), 0)
	verify(screen.plan.get_entry(b.member_id).position == Vector2(260, 600), "selected placed member can be repositioned by tap")
	screen.remove_selected()
	verify(screen.plan.get_entry(b.member_id) == null and member_snapshot(screen.guild) == before, "UI remove preserves guild states")
	screen.clear_draft()
	verify(screen.plan.entries().is_empty() and member_snapshot(screen.guild) == before, "UI clear preserves guild states")
	screen.plan.place(a.member_id, Vector2(140, 260))
	screen.plan.place(b.member_id, Vector2(140, 540))
	screen.start_battle()
	verify(screen.battle.started and not screen.board.editing and screen.start_button.disabled, "UI starts combat and locks editing")
	verify(member_snapshot(screen.guild) == before, "UI start does not settle early")
	screen.begin_deployment()
	verify(screen.battle != null and not screen.board.editing, "active combat cannot be left via next deployment")
	screen.battle.set_physics_process(false)
	finish(screen.battle)
	verify(screen.settlement_status == BattleSettlement.Status.APPLIED and not screen.next_button.disabled, "UI result triggers exactly one explicit settlement")
	var after: Dictionary = member_snapshot(screen.guild)
	var survivors: int = screen.battle.result.surviving_member_ids.size()
	screen.begin_deployment()
	verify(screen.board.editing and screen.plan.entries().size() == survivors and member_snapshot(screen.guild) == after, "UI next deployment restores survivor starts without changing HP")
	verify(screen.guild.state.last_formation.entries[0].position == Vector2(140, 260), "UI last formation never captures battle end")
	# Portrait-size viewport mapping remains logical 800x800.
	screen.board.size = Vector2(340, 500)
	verify(screen.board.logical_point(screen.board.board_rect().position + Vector2(170, 170)) == Vector2(400, 400), "mobile square viewport maps correctly to logical coordinates")
	screen.free()
	print("PASS Phase 3 debug UI mouse/touch/session flow")

func run(tree: SceneTree) -> void:
	host = tree
	test_rules()
	test_invariant_and_capacity()
	test_restore()
	test_battle_bridge()
	test_failed_start()
	test_debug_screen()
	print("PHASE 3 RESULT: ", groups, " test groups; ", checks, " checks; ", failures, " failures")

func legacy_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.common_combat_enabled = false
	manager.full_characters_enabled = false
	return manager
