class_name TurningPointManager
extends RefCounted
## Battle-local scheduler; never decides battle outcome or settles rooms.
signal ultimate_requested(source_enemy_id: String, request: Dictionary)
signal parry_readiness_requested(source_member_id: String, duration: float, cooldown_override: float)
## A card was played (presentation: flight to the target, effect).
signal card_played(card_id: int, target_actor_id: String, point: Vector2)
## A plan an enemy had prepared was removed by a disruption card.
signal plan_broken(source_enemy_id: String, plan_type: StringName)
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
## Card ids taken into this battle (the loadout chosen before deployment), in slot order.
var hand: Array[int] = []
## 일반 / 쿨타임 cards already played this battle (card_id -> true): shown face down.
var used_cards: Dictionary = {}
var card_serial: int = 0

func _init(owner: BattleManager, manager: GuildManager) -> void:
	battle = owner
	guild = manager
	hand.assign(guild.state.card_loadout.filter(func(id): return guild.state.get_strategy_card(id) != null))

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
			ItemEffects.on_turning_point(battle)
			current.remaining_real_time = maxf(0, DURATION - extra)
			current.enemy_plans = build_plans()
			current.selected_actor_id = ""
			ItemEffects.cancel_plans(battle, current.enemy_plans)
			for unit in battle.units:
				if unit.alive and not unit.source_member_id.is_empty():
					current.selected_member_id = unit.source_member_id
					current.selected_actor_id = unit.actor_id()
					break
	elif battle.clock.is_turning_paused():
		current.remaining_real_time = maxf(0, current.remaining_real_time - real_delta)
	if battle.clock.is_turning_paused() and current.remaining_real_time <= 0:
		resolve()

## Each turning point's strategies depend on the enemy count, the chapter (tower progress) and
## the room: battle, miniboss or chapter boss.
func build_plans() -> Array[EnemyTurningPlan]:
	var plans: Array[EnemyTurningPlan] = []
	var tower: TowerRunState = guild.state.tower
	var room: RoomState = tower.map.get_room(tower.selected_room_id) if tower != null and tower.map != null else null
	var room_type: StringName = room.room_type if room != null else RoomType.BATTLE
	var i: float = EnemyStrategyPlanner.intensity(guild.state.strategy_progress.current_depth, room_type)
	var enemies: Array = battle.units.filter(func(u): return u.alive and u.team == 1 and not u.source_enemy_id.is_empty())
	var high_left: int = EnemyStrategyPlanner.high_cap(i, room_type)
	for enemy in enemies:
		var rank: StringName = &"normal"
		if room != null and room.encounter != null:
			for spawn in room.encounter.enemies:
				if spawn.enemy_id == enemy.source_enemy_id:rank = spawn.rank
		var plan: EnemyTurningPlan = EnemyStrategyPlanner.plan(enemy, i, battle.rng, enemies.size(), rank, high_left > 0)
		# 봉인의 낙인: a sealed enemy prepares nothing at this turning point.
		if enemy.state_value("planSealedThrough") >= serial:
			continue
		if plan == null:
			continue
		if plan.tier() == EnemyTurningPlan.HIGH:high_left -= 1
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

## The hand as instances, in slot order (consumed copies dropped).
func hand_cards() -> Array[StrategyCardInstance]:
	var out: Array[StrategyCardInstance] = []
	for id in hand:
		var card: StrategyCardInstance = guild.state.get_strategy_card(id)
		if card != null and not card.consumed: out.append(card)
	return out
## The plan an enemy prepared at this turning point (not yet carried out), or null.
func plan_of(enemy) -> EnemyTurningPlan:
	if current == null or enemy == null: return null
	for plan in current.enemy_plans:
		if plan.source_enemy_id == enemy.source_enemy_id and not plan.executed: return plan
	return null
## Disruption: the enemy's plan is dropped, with its badge and ground warning.
func remove_plan(enemy) -> EnemyTurningPlan:
	var plan: EnemyTurningPlan = plan_of(enemy)
	if plan == null: return null
	current.enemy_plans.erase(plan)
	battle.emit_combat_event(&"plan_broken", enemy.position, {"actor_id": enemy.battle_id, "plan": String(plan.plan_type), "tier": String(plan.tier())})
	plan_broken.emit(plan.source_enemy_id, plan.plan_type)
	return plan
## 방벽 설치: a wall of `length` across the line to the enemies, blocking enemy shots for `life` s.
func add_wall(point: Vector2, length: float, life: float) -> void:
	var foes: Array = battle.units.filter(func(u): return u.alive and u.team == 1)
	var toward := Vector2.RIGHT
	if not foes.is_empty():
		var center := Vector2.ZERO
		for f in foes: center += f.position
		center /= foes.size()
		if center.distance_to(point) > 1: toward = (center - point).normalized()
	battle.card_walls.append(CardWalls.make(point, toward.orthogonal(), length, life, 0))
	battle.emit_combat_event(&"card_wall", point, {"angle": toward.orthogonal().angle(), "length": length})
## Plays a hand card from the UI: on a unit (actor id) or at a field point.
func play(card_id: int, target_actor_id: String = "", point: Vector2 = Vector2.INF) -> Dictionary:
	if not is_paused(): return {"code": StrategyCardExecutor.Code.NOT_HOLD}
	card_serial += 1
	current.last_card_result = StrategyCardExecutor.apply(self, card_id, target_actor_id, current.turning_point_id + "_play_%d" % card_serial, point)
	return current.last_card_result

func select_card(id: int) -> bool:
	if not is_paused(): return false
	if current.selected_card_id == id:
		cancel_card_selection()
		return true
	var card: StrategyCardInstance = guild.state.get_strategy_card(id)
	if not id in hand or StrategyCardExecutor.hand_state(self, card) != &"ready": return false
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
	var data: StrategyCardData = StrategyCardCatalog.get_card(guild.state.get_strategy_card(current.selected_card_id).kind)
	var target: String = current.selected_actor_id if data.use_mode == &"enemy" or current.selected_member_id.is_empty() else current.selected_member_id
	current.last_card_result = StrategyCardExecutor.apply(self, current.selected_card_id, target, current.selected_request_id)
	if current.last_card_result.code == StrategyCardExecutor.Code.OK:
		cancel_card_selection()
	return current.last_card_result
