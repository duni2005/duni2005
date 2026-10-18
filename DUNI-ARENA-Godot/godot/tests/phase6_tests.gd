class_name Phase6Tests
extends RefCounted
var checks: int = 0
var failures: int = 0
var groups: int = 0
var host: SceneTree
func verify(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PHASE 6 FAIL: " + message)
func fixture(hold: bool = true) -> Dictionary:
	var helper := Phase5Tests.new()
	helper.host = host
	var f: Dictionary = helper.fixture()
	for kind in StrategyCardCatalog.DEFINITIONS: f.guild.state.give_strategy_card(kind)
	if hold:
		helper.pause(f)
		f.tp.current.enemy_plans.clear()
	return f
func card(f: Dictionary, kind: StringName) -> StrategyCardInstance:
	for item in f.guild.state.strategy_cards:
		if item.kind == kind: return item
	return null
func use(f: Dictionary, kind: StringName, index: int = 0, request: String = "") -> Dictionary:
	var id: String = f.battle.units[index].source_member_id
	return StrategyCardExecutor.apply(f.tp, card(f, kind).card_id, id, request if not request.is_empty() else "%s_%d" % [kind, checks])
func ok(result: Dictionary) -> bool:
	return result.code == StrategyCardExecutor.Code.OK
func clear(f: Dictionary) -> void:
	f.battle.free()
func gates() -> void:
	groups += 1
	var f := fixture(false)
	verify(not ok(use(f, &"mango")), "normal battle rejects cards")
	f.battle.clock.elapsed = 12
	f.battle.simulate(1)
	verify(not ok(use(f, &"shield")), "slowdown rejects cards")
	f.battle.simulate(1)
	verify(f.tp.is_paused(), "hold permits cards")
	verify(StrategyCardExecutor.apply(f.tp, 999, f.battle.units[0].source_member_id, "bad").code == StrategyCardExecutor.Code.INVALID_CARD, "unknown card")
	verify(StrategyCardExecutor.apply(f.tp, card(f, &"shield").card_id, "unknown", "bad").code == StrategyCardExecutor.Code.INVALID_TARGET, "unknown member")
	verify(StrategyCardExecutor.apply(f.tp, card(f, &"shield").card_id, f.guild.all_members()[2].member_id, "reserve").code == StrategyCardExecutor.Code.INVALID_TARGET, "reserve not battle target")
	f.battle.units[0].alive = false
	verify(use(f, &"shield").code == StrategyCardExecutor.Code.INVALID_TARGET, "dead member rejects")
	verify(not card(f, &"shield").consumed, "invalid use unchanged")
	f.battle.units[0].alive = true
	f.battle.finish_with_reason(BattleEndReason.Value.RETREAT, -1)
	verify(not ok(use(f, &"shield")), "finished rejects")
	verify(not f.tp.select_card(card(f, &"shield").card_id), "finished selection rejects")
	clear(f)
func immediate() -> void:
	groups += 1
	var f := fixture()
	var u: BattleUnit = f.battle.units[0]
	verify(use(f, &"mango").code == StrategyCardExecutor.Code.NO_EFFECT, "full HP no effect")
	verify(not card(f, &"mango").consumed, "full HP keeps copy")
	u.current_hp = 40
	verify(ok(use(f, &"mango", 0, "heal")), "hold recovery allowed")
	verify(u.current_hp == 85, "warrior max150 30percent45")
	verify(card(f, &"mango").consumed, "once consumed")
	verify(use(f, &"mango", 0, "heal").code == StrategyCardExecutor.Code.DUPLICATE, "request receipt prevents reapply")
	verify(not ok(use(f, &"mango", 0, "heal2")), "once cannot reuse different request")
	verify(u.current_hp == 85, "no duplicate recovery")
	var extra: StrategyCardInstance = f.guild.state.give_strategy_card(&"mango")
	u.current_hp = 140
	verify(ok(StrategyCardExecutor.apply(f.tp, extra.card_id, u.source_member_id, "clamp")) and u.current_hp == 150, "HP cap")
	verify(extra.card_id != card(f, &"mango").card_id, "same kind separate instance IDs")
	verify(f.guild.state.give_strategy_card(&"unknown") == null, "unknown grant rejected")
	u.ultimate_gauge = 100
	verify(use(f, &"charge").code == StrategyCardExecutor.Code.NO_EFFECT, "full ultimate no effect")
	verify(card(f, &"charge").ready_floor == 0, "no effect cooldown not started")
	u.ultimate_gauge = 37
	f.guild.state.strategy_progress.current_depth = 1
	f.guild.state.strategy_progress.unlocked_floor = 7
	verify(ok(use(f, &"charge")) and u.ultimate_gauge == 87, "charge50 percentage points")
	verify(card(f, &"charge").ready_floor == 10, "highest unlocked7 plus3 not current1 plus2")
	f.guild.state.strategy_progress.unlocked_floor = 9
	verify(not ok(use(f, &"charge")), "two intervening floors not ready")
	f.guild.state.strategy_progress.unlocked_floor = 10
	verify(ok(use(f, &"charge")) and u.ultimate_gauge == 100, "ready boundary inclusive gauge clamp")
	verify(card(f, &"charge").ready_floor == 13, "next cooldown starts highest unlocked")
	verify(f.guild.state.strategy_use_receipts.size() == 4, "only successful uses recorded")
	clear(f)
func shield_and_iron() -> void:
	groups += 1
	var f := fixture()
	var u: BattleUnit = f.battle.units[0]
	u.parry_cooldown = 9
	u.defense_cooldown = 5
	verify(ok(use(f, &"iron")), "iron immediate state")
	verify(u.iron_defense_remaining == 15 and u.parry_cooldown == 0 and u.defense_cooldown == 0, "iron15 resets warrior readiness")
	verify(ParryReadiness.is_ready(u) and ParryReadiness.cooldown_duration(u) == 3, "3sec readiness override")
	verify(card(f, &"iron").ready_floor == 3 and not ok(use(f, &"iron")), "iron cooldown")
	verify(ok(use(f, &"shield")), "shield immediate")
	verify(u.shield_hp == 100 and u.shield_remaining == 8, "100hp eight seconds")
	verify(not ok(use(f, &"shield")), "shield once")
	var shield2: StrategyCardInstance = f.guild.state.give_strategy_card(&"shield")
	verify(ok(StrategyCardExecutor.apply(f.tp, shield2.card_id, u.source_member_id, "refresh")), "web allows unchanged shield refresh consuming new copy")
	verify(u.shield_hp == 100 and shield2.consumed, "shield replaces never stacks")
	f.battle.simulate(5)
	verify(u.shield_remaining == 8 and u.iron_defense_remaining == 15, "hold timers frozen")
	verify(f.battle.damage_resolver.apply(f.battle.units[2], u, 60) == 0 and u.shield_hp == 100, "normal attacks blocked hold")
	f.tp.resolve()
	var outcome: DamageOutcome = f.battle.damage_resolver.resolve(f.battle.units[2], u, 30)
	verify(outcome.accepted and outcome.hp_damage == 0, "shield takes first hit")
	verify(outcome.shield_absorbed == outcome.resolved_damage and u.shield_hp == 100-outcome.resolved_damage, "postcrit shield accounting")
	var prior: float = u.shield_hp
	outcome = f.battle.damage_resolver.resolve(f.battle.units[2], u, 80)
	verify(outcome.shield_absorbed == prior and u.shield_hp == 0 and u.shield_remaining == 0, "shield exhausted clears duration")
	verify(outcome.hp_damage == outcome.resolved_damage-prior, "overflow actual HP loss")
	verify(u.current_hp == 150-outcome.hp_damage, "HP after shield exact")
	StrategyEffects.advance(u, 15)
	verify(u.iron_defense_remaining == 0 and ParryReadiness.cooldown_duration(u) == 12, "iron expiration restores12sec")
	verify(u.alive, "deferred parry safe no fabricated block")
	var another := fixture()
	verify(ok(use(another, &"shield")), "second shield fixture")
	another.tp.resolve()
	StrategyEffects.advance(another.battle.units[0], 7.99)
	verify(another.battle.units[0].shield_hp == 100, "shield valid before expiry")
	StrategyEffects.advance(another.battle.units[0], .01)
	verify(another.battle.units[0].shield_hp == 0 and another.battle.units[0].shield_remaining == 0, "shield expires exact8")
	clear(another)
	clear(f)
func pending_and_order() -> void:
	groups += 1
	var f := fixture()
	var u: BattleUnit = f.battle.units[0]
	var enemy: BattleUnit = f.battle.units[2]
	var where: Vector2 = u.position
	verify(ok(use(f, &"taunt")), "taunt creates command")
	verify(ok(use(f, &"evade")), "evade creates command")
	verify(f.tp.current.pending_commands.size() == 2 and u.position == where and u.strategy_dash.is_empty(), "hold never moves")
	verify(enemy.taunted_until == 0, "taunt deferred too")
	verify(not ok(use(f, &"evade")) and f.tp.current.pending_commands.size() == 2, "samecopy no duplicate commands")
	var extra: StrategyCardInstance = f.guild.state.give_strategy_card(&"evade")
	verify(StrategyCardExecutor.apply(f.tp, extra.card_id, u.source_member_id, "pendingdup").code == StrategyCardExecutor.Code.NO_EFFECT, "secondcopy same pending rejected")
	verify(extra.used_depth == -1, "pending failure leaves copy unused")
	var p := EnemyTurningPlan.new()
	p.plan_type = EnemyTurningPlan.RETREAT
	p.source_enemy_id = enemy.source_enemy_id
	f.tp.current.enemy_plans.append(p)
	var time: float = f.battle.clock.elapsed
	verify(f.tp.resolve(), "manual shared resolve")
	verify(p.executed and enemy.command_retreat_until == 0 and enemy.strategy_dash.is_empty(), "enemy retreat first overridden by later ally taunt")
	verify(enemy.taunted_member_id == u.source_member_id and enemy.taunted_until == time+8, "taunt8sec")
	verify(u.command_retreat_until == time+6 and not u.strategy_dash.is_empty(), "evade dash six seconds")
	for command in f.tp.current.pending_commands:
		verify(command.executed and UnitStateCodec.is_pure_data(command.metadata), "commands pure metadata and executed once")
	verify(f.tp.current.pending_commands[0].metadata.target_enemy_ids.size() == 2, "nearest max2 no distance cutoff")
	enemy.focus_member_id = f.battle.units[1].source_member_id
	enemy.focus_until = time+10
	verify(enemy.target_selector.select_target(enemy, f.battle.units) == u, "taunt outranks focus")
	f.battle.clock.elapsed = time+8
	verify(enemy.target_selector.select_target(enemy, f.battle.units) == f.battle.units[1], "taunt expiry returns focus")
	verify(not f.tp.resolve(), "resolve once")
	f.battle.clock.elapsed = time
	f.battle.simulate(.1)
	verify(u.position.distance_to(where) > 0 and not f.battle.finished, "evade real movement not full retreat")
	verify(card(f, &"evade").used_depth == 0 and card(f, &"evade").used_floors == [0], "floor records")
	f.battle.clock.elapsed = time+8
	f.battle.simulate(.01)
	verify(u.command_retreat_until < f.battle.clock.elapsed, "flee expires simulation time")
	clear(f)
	f = fixture()
	for e in f.battle.units:
		if e.team == 1: e.alive = false
	verify(use(f, &"taunt").code == StrategyCardExecutor.Code.NO_EFFECT, "no target no consumption")
	verify(card(f, &"taunt").used_depth == -1, "emptytaunt nofloor record")
	clear(f)
func selection_and_auto() -> void:
	groups += 1
	var f := fixture()
	var id: int = card(f, &"shield").card_id
	verify(f.tp.select_card(id), "card selected")
	verify(not card(f, &"shield").consumed, "selection only no consumption")
	f.tp.cancel_card_selection()
	verify(f.tp.current.selected_card_id == 0 and not card(f, &"shield").consumed, "cancel clean")
	verify(f.tp.select_card(id) and f.tp.select_card(id) and f.tp.current.selected_card_id == 0, "toggle cancels")
	f.tp.select_card(id)
	verify(ok(f.tp.use_selected_card()), "UI executor path")
	verify(not ok(f.tp.use_selected_card()) and f.battle.units[0].shield_hp == 100, "fast UI repeated click single effect")
	verify(f.tp.current.selected_card_id == 0, "success clears selection")
	verify(ok(use(f, &"evade")), "auto command pending")
	var state: TurningPointState = f.tp.current
	state.remaining_real_time = .01
	f.battle.simulate(.01)
	verify(state.resolved and state.pending_commands[0].executed and f.tp.resolve_count == 1, "auto same resolve command path")
	verify(f.battle.clock.state == BattleClock.State.NORMAL and not f.battle.units[0].strategy_dash.is_empty(), "auto resumes with dash")
	verify(f.tp.next_at == 42, "Phase5 next schedule preserved")
	clear(f)
func persistence_retry() -> void:
	groups += 1
	var f := fixture()
	var u: BattleUnit = f.battle.units[0]
	verify(ok(use(f, &"shield")) and ok(use(f, &"iron")) and ok(use(f, &"charge")), "persistent immediate effects")
	verify(ok(use(f, &"evade")), "pending before retreat")
	f.battle.clock.elapsed = 20
	verify(f.session.request_retreat(), "full retreat legal duringhold")
	verify(not f.tp.current.pending_commands[0].executed, "full retreat discards pending no refund")
	var saved: GuildMemberState = f.guild.get_member(u.source_member_id)
	verify(saved.character_specific_state.shieldHp == 100 and saved.character_specific_state.shieldTime == 8, "ally shield persistence")
	verify(saved.character_specific_state.ironDefenseTime == 15 and saved.ultimate_gauge == 50, "iron charge snapshot")
	verify(not saved.character_specific_state.has("pendingRetreat") and not saved.character_specific_state.has("tauntedUntil"), "transient exclusions")
	var run: RunState = f.guild.state
	var counts: int = run.strategy_cards.size()
	var plan := DeploymentPlan.new(f.guild)
	plan.place(saved.member_id, Vector2(120, 300))
	var next := legacy_manager()
	next.auto_start = false
	host.root.add_child(next)
	next.set_physics_process(false)
	var session := RoomBattleSession.new(f.guild, f.room)
	verify(session.start(plan, next, 9), "same room retry")
	verify(next.units[0].shield_hp == 100 and next.units[0].iron_defense_remaining == 15, "effects re-injected")
	verify(next.units[0].ultimate_gauge == 50 and next.units[0].command_retreat_until == 0, "gauge persists pending doesnot")
	verify(next.turning.current == null and next.turning.next_at == 12, "fresh TurningPointState")
	verify(run.strategy_cards.size() == counts and card(f, &"shield").consumed, "no retry grant/reset")
	verify(not StrategyCardExecutor.availability(card(f, &"evade"), run.strategy_progress), "usedfloor persists retry")
	run.strategy_progress.current_depth = 1
	verify(StrategyCardExecutor.availability(card(f, &"evade"), run.strategy_progress), "different depth floor usable")
	run.strategy_progress.current_depth = 0
	verify(not StrategyCardExecutor.availability(card(f, &"evade"), run.strategy_progress), "revisit usedfloor blocked")
	verify(not StrategyCardExecutor.availability(card(f, &"charge"), run.strategy_progress), "cooldown persists retry")
	next.free()
	clear(f)
	f = fixture()
	verify(ok(use(f, &"evade")), "active flee persistence")
	f.tp.resolve()
	f.battle.clock.elapsed += 2
	f.battle.clock.elapsed = maxf(20, f.battle.clock.elapsed)
	# Active duration with known relative point, as later room retries require.
	f.battle.units[0].command_retreat_until = f.battle.clock.elapsed+4
	var snapshot: Dictionary = UnitStateCodec.snapshot(f.battle.units[0])
	verify(snapshot.character_specific_state.retreatRemaining == 4, "ally actual remaining flee stored")
	var enemy: BattleUnit = f.battle.units[2]
	enemy.shield_hp = 17
	enemy.shield_remaining = 3
	enemy.iron_defense_remaining = 9
	enemy.taunted_member_id = f.battle.units[0].source_member_id
	enemy.taunted_until = f.battle.clock.elapsed+7
	var es: Dictionary = EnemyStateCodec.snapshot(enemy)
	verify(es.persistent_state.shieldHp == 17 and es.persistent_state.ironDefenseTime == 9, "same numeric whitelist enemy")
	verify(not es.persistent_state.has("tauntedUntil") and UnitStateCodec.is_pure_data(es.persistent_state), "enemy no transient/node refs")
	clear(f)
func edge_commands() -> void:
	groups += 1
	var f := fixture()
	var u: BattleUnit = f.battle.units[0]
	var far: BattleUnit = f.battle.unit_factory.create({"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(750, 750)}, 99, f.battle, f.battle.rng)
	far.source_enemy_id = "third"
	f.battle.units.append(far)
	f.battle.add_child(far)
	verify(ok(use(f, &"taunt")), "three enemy taunt accepted")
	var targets: Array = f.tp.current.pending_commands[0].metadata.target_enemy_ids
	verify(targets.size() == 2 and "third" not in targets, "nearest2 excludes farthird")
	var first_target: BattleUnit = EnemyPlanExecutor.find_enemy(f.battle, targets[0])
	first_target.alive = false
	f.tp.resolve()
	verify(first_target.taunted_until == 0, "dead stored enemy ignored on resume")
	verify(f.tp.current.pending_commands[0].executed, "command completes even partial invalid target")
	clear(f)
	f = fixture()
	var command := StrategyCommand.new()
	var source: Dictionary = {"ids": ["e1"]}
	command.metadata = source
	source.ids.append("e2")
	verify(command.metadata.ids == ["e1"], "metadata incoming detached")
	var output: Dictionary = command.metadata
	output.ids.append("e3")
	verify(command.metadata.ids == ["e1"], "metadata outgoing detached")
	var node := Node.new()
	command.metadata = {"bad": node}
	verify(command.metadata.ids == ["e1"], "metadata refuses Node reference")
	node.free()
	var events: Array = []
	f.tp.parry_readiness_requested.connect(func(id, duration, cooldown): events.append([id, duration, cooldown]))
	verify(ok(use(f, &"iron", 0, "ironhook")), "iron hook success")
	verify(events == [[f.battle.units[0].source_member_id, 15.0, 3.0]], "exact future parry call contract")
	verify(not ok(use(f, &"iron", 0, "ironhook")) and events.size() == 1, "no duplicate hook")
	f.guild.state.strategy_progress.unlocked_floor = 3
	verify(ok(use(f, &"iron", 0, "ironrefresh")) and events.size() == 2, "ready boundary allows iron refresh")
	var u2: BattleUnit = f.battle.units[0]
	u2.shield_hp = 41
	u2.shield_remaining = 3
	u2.parry_cooldown = 3
	u2.defense_cooldown = 5
	var snapshot: Dictionary = UnitStateCodec.snapshot(u2)
	var member: GuildMemberState = f.guild.get_member(u2.source_member_id)
	UnitStateCodec.restore(member, snapshot)
	var prepared: Dictionary = BattleUnitFactory.guild_placement(f.guild, member.member_id, Vector2(160, 320))
	var clone: BattleUnit = f.battle.unit_factory.create(prepared, 77, f.battle, f.battle.rng)
	verify(clone.shield_hp == 41 and clone.shield_remaining == 3 and clone.parry_cooldown == 3 and clone.defense_cooldown == 5, "all numeric fields roundtrip")
	clone.shield_hp = 1
	verify(u2.shield_hp == 41 and member.character_specific_state.shieldHp == 41, "effect states independent")
	clone.free()
	f.tp.resolve()
	verify(f.battle.damage_resolver.apply(f.battle.units[2], u2, 9999) > 0 and not u2.alive, "lethal overflow")
	verify(u2.shield_hp == 0 and u2.shield_remaining == 0 and u2.iron_defense_remaining == 0 and u2.parry_remaining == 0, "death clears web effect fields")
	clear(f)

func run(tree: SceneTree) -> void:
	host = tree
	gates()
	immediate()
	shield_and_iron()
	pending_and_order()
	selection_and_auto()
	persistence_retry()
	edge_commands()
	print("PHASE 6 RESULT: ", groups, " groups; ", checks, " checks; ", failures, " failures")

func legacy_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.common_combat_enabled = false
	manager.full_characters_enabled = false
	return manager
