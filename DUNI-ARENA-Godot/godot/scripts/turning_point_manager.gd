class_name TurningPointManager
extends RefCounted
## Battle-local scheduler; never decides battle outcome or settles rooms.
signal ultimate_requested(source_enemy_id: String, request: Dictionary)
signal parry_readiness_requested(source_member_id: String, duration: float, cooldown_override: float)
const FIRST: float = 12.0
const INTERVAL: float = 30.0
const BRAKE: float = 2.0
const DURATION: float = 40.0
var battle: BattleManager
var guild: GuildManager
var next_at: float = FIRST
var serial: int = 0
var enabled: bool = true
var current: TurningPointState
var resolve_count: int = 0

func _init(owner: BattleManager, manager: GuildManager) -> void:
	battle = owner
	guild = manager

func can_trigger() -> bool:
	if not enabled or not battle.started or battle.finished or battle.run_end_requested or guild.state.game_over or guild.state.player_hp <= 0 or battle.clock.state != BattleClock.State.NORMAL:
		return false
	var allies: bool = battle.units.any(func(u): return u.alive and not u.source_member_id.is_empty())
	var enemies: bool = battle.units.any(func(u): return u.alive and not u.source_enemy_id.is_empty())
	return allies and enemies and (current == null or current.resolved)

func advance(real_delta: float) -> void:
	if not enabled or not is_finite(real_delta) or real_delta <= 0 or battle.finished:
		return
	if can_trigger() and battle.clock.elapsed >= next_at:
		serial += 1
		current = TurningPointState.new()
		current.turning_point_id = battle.battle_result_id + "_tp_%03d" % serial
		current.trigger_simulation_time = battle.clock.elapsed
		next_at += INTERVAL # Web schedules at START: 12, 42, 72, not resume+30.
		battle.clock.begin_slowdown(BRAKE)
	if battle.clock.state == BattleClock.State.TURNING_SLOWDOWN:
		var extra: float = battle.clock.progress_slowdown(real_delta, BRAKE)
		if battle.clock.is_turning_paused():
			current.phase = TurningPointState.Phase.PAUSED
			current.remaining_real_time = maxf(0, DURATION - extra)
			current.enemy_plans = build_plans()
			for unit in battle.units:
				if unit.alive and not unit.source_member_id.is_empty():
					current.selected_member_id = unit.source_member_id
					break
	elif battle.clock.is_turning_paused():
		current.remaining_real_time = maxf(0, current.remaining_real_time - real_delta)
	if battle.clock.is_turning_paused() and current.remaining_real_time <= 0:
		resolve()

func build_plans() -> Array[EnemyTurningPlan]:
	var plans: Array[EnemyTurningPlan] = []
	var p: float = EnemyStrategyPlanner.progress(guild.state.strategy_progress.current_depth)
	for enemy in battle.units:
		if not enemy.alive or enemy.team != 1 or enemy.source_enemy_id.is_empty():
			continue
		var plan: EnemyTurningPlan = EnemyStrategyPlanner.plan(enemy, p, battle.rng)
		if plan == null:
			continue
		plan.plan_id = current.turning_point_id + "_" + enemy.source_enemy_id
		plan.source_enemy_id = enemy.source_enemy_id
		plans.append(plan)
	return plans

func is_paused() -> bool:
	return enabled and not battle.finished and current != null and not current.resolved and current.phase == TurningPointState.Phase.PAUSED and battle.clock.is_turning_paused()

func change_stance(member_id: String, value: StringName) -> bool:
	if not is_paused() or value not in CombatStance.VALUES:
		return false
	var unit: BattleUnit = EnemyPlanExecutor.find_member(battle, member_id)
	var member: GuildMemberState = guild.get_member(member_id)
	if unit == null or member == null:
		return false
	unit.stance = value
	if battle.full_characters_enabled:unit.brain.stance_changed(unit)
	if battle.full_characters_enabled and value==CombatStance.COVER:CharacterLifecycle.bind_cover(unit)
	member.stance = value
	current.selected_member_id = member_id
	return true

func resolve() -> bool:
	if not is_paused() or battle.run_end_requested or guild.state.game_over or guild.state.player_hp <= 0:
		return false
	current.resolved = true # Mark BEFORE effects/signals, guarding reentrant resume.
	current.phase = TurningPointState.Phase.RESOLVED
	current.remaining_real_time = 0.0
	resolve_count += 1
	for plan in current.enemy_plans:
		if battle.finished:
			break
		var request: Dictionary = EnemyPlanExecutor.execute(plan, battle)
		if not request.is_empty():
			ultimate_requested.emit(request.source_enemy_id, request.request)
	if not battle.finished:
		StrategyCommandExecutor.execute_all(self)
		cancel_card_selection()
		battle.clock.resume()
	return true

func cancel() -> void:
	cancel_card_selection()
	enabled = false
	next_at = INF
	if current != null and not current.resolved:
		current.phase = TurningPointState.Phase.CANCELLED
		current.remaining_real_time = 0.0
		current.resolved = true

func permits_full_retreat() -> bool:
	# canRetreatTower does NOT exclude strategyBattleActive/frozen.
	return enabled and not battle.finished and battle.clock.state in [BattleClock.State.NORMAL, BattleClock.State.TURNING_SLOWDOWN, BattleClock.State.TURNING_PAUSED]

func select_card(id: int) -> bool:
	if not is_paused(): return false
	if current.selected_card_id == id:
		cancel_card_selection()
		return true
	var card: StrategyCardInstance = guild.state.get_strategy_card(id)
	if not StrategyCardExecutor.availability(card, guild.state.strategy_progress): return false
	current.selection_serial += 1
	current.selected_card_id = id
	current.selected_request_id = current.turning_point_id + "_card_%d" % current.selection_serial
	current.last_card_result.clear()
	return true
func cancel_card_selection() -> void:
	if current != null:
		current.selected_card_id = 0
		current.selected_request_id = ""
func use_selected_card() -> Dictionary:
	if not is_paused() or current.selected_card_id == 0:
		return {"code": StrategyCardExecutor.Code.NOT_HOLD}
	current.last_card_result = StrategyCardExecutor.apply(self, current.selected_card_id, current.selected_member_id, current.selected_request_id)
	if current.last_card_result.code == StrategyCardExecutor.Code.OK:
		cancel_card_selection()
	return current.last_card_result
