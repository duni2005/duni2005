class_name StrategyCardExecutor
extends RefCounted
## Card rules and effects, committed synchronously; UI never mutates combat values.
## A card can be played when it is in the battle's hand (loadout), not consumed, not on cooldown,
## not already used this battle (일반 / 쿨타임) and its condition has a target or holds.
enum Code { OK, NOT_HOLD, INVALID_CARD, UNAVAILABLE, INVALID_TARGET, NO_EFFECT, DUPLICATE, NOT_IN_HAND, USED, COOLDOWN, CONDITION, NO_POSITION }

## Owned and ready outside a battle: not consumed and no wins left on its cooldown.
static func availability(card: StrategyCardInstance, _context = null) -> bool:
	return card != null and not card.consumed and card.wins_left <= 0 and StrategyCardCatalog.get_card(card.kind) != null

## How a card in the hand stands: &"ready", &"used" (일반 / 쿨타임 used this battle),
## &"cooldown", &"gone" (consumed) or &"blocked" (its condition has no target now).
static func hand_state(manager: TurningPointManager, card: StrategyCardInstance) -> StringName:
	if card == null or card.consumed:return &"gone"
	if manager.used_cards.has(card.card_id):return &"used"
	if card.wins_left > 0:return &"cooldown"
	var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
	if not condition_open(manager, data):return &"blocked"
	return &"ready"

## Its condition has at least one fitting unit (or the situation holds).
static func condition_open(manager: TurningPointManager, data: StrategyCardData) -> bool:
	if data.condition == &"":return true
	if data.situation():return situation_ok(manager, data.condition)
	return not targets(manager, data).is_empty()
static func situation_ok(manager: TurningPointManager, condition: StringName) -> bool:
	var battle: BattleManager = manager.battle
	match condition:
		&"outnumbered":
			var allies: int = battle.units.filter(func(u): return u.alive and u.original_team == 0 and not u.source_member_id.is_empty()).size()
			var foes: int = battle.units.filter(func(u): return u.alive and u.team == 1 and not u.source_enemy_id.is_empty()).size()
			return allies < foes
		&"enemy_planning":return manager.current != null and manager.current.enemy_plans.any(func(p): return not p.executed)
	return true
## Units the card can be played on now (its side, alive, its condition).
static func targets(manager: TurningPointManager, data: StrategyCardData) -> Array:
	var out: Array = []
	if not data.unit_target():return out
	for u in manager.battle.units:
		if valid_target(manager, data, u):out.append(u)
	return out
static func valid_target(manager: TurningPointManager, data: StrategyCardData, u) -> bool:
	if u == null or not u.alive:return false
	if data.use_mode == &"ally" and (u.team != 0 or u.source_member_id.is_empty() or manager.guild.get_member(u.source_member_id) == null):return false
	if data.use_mode == &"enemy" and (u.team != 1 or u.source_enemy_id.is_empty()):return false
	return data.situation() or target_condition(manager, data, u)
static func target_condition(manager: TurningPointManager, data: StrategyCardData, u) -> bool:
	match data.condition:
		&"melee":return u.data.attack_range < StrategyCardTuning.MELEE_RANGE
		&"rush":return u.stance == CombatStance.RUSH
		&"low_hp":return u.current_hp <= u.max_hp * StrategyCardTuning.LOW_HP
		&"planning":
			var plan: EnemyTurningPlan = manager.plan_of(u)
			return plan != null and (data.disrupt == &"" or tier_rank(plan.tier()) <= tier_rank(data.disrupt))
	return true
static func tier_rank(tier: StringName) -> int:return StrategyCardTuning.TIER_ORDER.find(tier)
## Short hint when the selected unit does not fit, e.g. "근접형 아군을 선택하세요".
static func target_hint(data: StrategyCardData) -> String:
	var side: String = "아군" if data.use_mode == &"ally" else "적"
	match data.condition:
		&"melee":return "근접형 아군을 선택하세요"
		&"rush":return "저돌적 성향의 %s을 선택하세요" % side
		&"low_hp":return "HP 30%% 이하인 %s을 선택하세요" % side
		&"planning":return "특수전략(%s)을 준비 중인 적을 선택하세요" % StrategyCardData.DISRUPT_NAMES.get(data.disrupt, "")
	return "%s을 선택하세요" % ("아군" if data.use_mode == &"ally" else "적")

## Plays a card. target_id: a member id or actor id (unit cards); point: the field position
## (position cards). Records the use (consumed / used this battle / cooldown) on success.
static func apply(manager: TurningPointManager, card_id: int, target_id: String, request_id: String, point: Vector2 = Vector2.INF) -> Dictionary:
	if manager == null or not manager.is_paused() or manager.battle.run_end_requested or manager.guild.state.game_over:
		return {"code": Code.NOT_HOLD}
	var run: RunState = manager.guild.state
	if request_id.is_empty(): return {"code": Code.INVALID_CARD}
	if run.strategy_use_receipts.has(request_id): return {"code": Code.DUPLICATE}
	var card: StrategyCardInstance = run.get_strategy_card(card_id)
	if card == null or StrategyCardCatalog.get_card(card.kind) == null: return {"code": Code.INVALID_CARD}
	if not card_id in manager.hand: return {"code": Code.NOT_IN_HAND}
	if card.consumed: return {"code": Code.UNAVAILABLE}
	if manager.used_cards.has(card_id): return {"code": Code.USED}
	if card.wins_left > 0: return {"code": Code.COOLDOWN}
	var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
	if data.situation() and not situation_ok(manager, data.condition): return {"code": Code.CONDITION}
	var unit: BattleUnit = null
	if data.unit_target():
		unit = EnemyPlanExecutor.find_member(manager.battle, target_id) if data.use_mode == &"ally" else EnemyPlanExecutor.find_enemy(manager.battle, target_id)
		if unit == null: unit = manager.battle.find_actor(target_id)
		if unit == null or not unit.alive or (data.use_mode == &"ally" and (unit.team != 0 or unit.source_member_id.is_empty() or manager.guild.get_member(unit.source_member_id) == null)) or (data.use_mode == &"enemy" and (unit.team != 1 or unit.source_enemy_id.is_empty())):
			return {"code": Code.INVALID_TARGET}
		if not data.situation() and not target_condition(manager, data, unit): return {"code": Code.CONDITION, "hint": target_hint(data)}
	if data.use_mode == &"position" and (not point.is_finite() or point.x < 20 or point.y < 20 or point.x > ArenaMap.side - 20 or point.y > ArenaMap.side - 20):
		return {"code": Code.NO_POSITION}
	var member_id: String = unit.source_member_id if unit != null and data.use_mode == &"ally" else ""
	# 전술가의 깃펜: cards used on the bearer are QUILL_POWER times as strong.
	var k: float = ItemTuning.QUILL_POWER if unit != null and data.use_mode == &"ally" and ItemEffects.has(unit, &"tacticianQuill") else 1.0
	if k > 1: ItemEffects.proc(unit, &"tacticianQuill")
	var command: StrategyCommand
	match card.kind:
		&"disrupt", &"block", &"seal":
			if manager.remove_plan(unit) == null: return {"code": Code.NO_EFFECT}
			if card.kind == &"seal": unit.set_state("planSealedThrough", float(manager.serial + int(data.extra)))
		&"barrier":
			manager.add_wall(point, data.amount, data.duration)
		&"feast":
			var any: bool = false
			for ally in manager.battle.units:
				if not ally.alive or ally.original_team != 0 or ally.source_member_id.is_empty(): continue
				var healed: float = StrategyEffects.heal(ally, ally.max_hp * data.amount)
				var gained: float = ally.ultimate.gain(ally, data.extra) if manager.battle.full_characters_enabled else 0.0
				if not manager.battle.full_characters_enabled and ally.ultimate_gauge < 100: gained = minf(100, ally.ultimate_gauge + data.extra) - ally.ultimate_gauge;ally.ultimate_gauge += gained
				any = any or healed > 0 or gained > 0
			if not any: return {"code": Code.NO_EFFECT}
		&"mango":
			if StrategyEffects.heal(unit, unit.max_hp * data.amount * k) <= 0: return {"code": Code.NO_EFFECT}
		&"charge":
			if unit.ultimate_gauge >= 100 or (manager.battle.common_combat_enabled and StatusController.skill_charge_blocked(unit)): return {"code": Code.NO_EFFECT}
			if manager.battle.full_characters_enabled:
				if unit.ultimate.gain(unit,data.amount*k)<=0:return {"code":Code.NO_EFFECT}
			else:unit.ultimate_gauge = minf(100, unit.ultimate_gauge + data.amount * k)
		&"shield":
			unit.shield_hp = data.amount * k
			unit.shield_remaining = data.duration * k
		&"iron":
			unit.iron_defense_remaining = data.duration * k
			unit.parry_cooldown = 0
			if unit.data.type_id == 0: unit.defense_cooldown = 0
		&"evade", &"taunt":
			for pending in manager.current.pending_commands:
				if not pending.executed and pending.member_id == member_id and pending.command_type == card.kind:
					return {"code": Code.NO_EFFECT}
			command = StrategyCommand.new()
			command.command_id = request_id
			command.card_id = card_id
			command.member_id = member_id
			command.command_type = card.kind
			command.duration = data.duration * k
			if card.kind == &"taunt":
				# Both currently implemented types are visible. Perception/stealth later.
				var enemies: Array = manager.battle.units.filter(func(v): return v.alive and v.team == 1 and not v.source_enemy_id.is_empty() and (not manager.battle.common_combat_enabled or CombatPerception.can_perceive(v,unit)))
				enemies.sort_custom(func(a, b): return unit.position.distance_squared_to(a.position) < unit.position.distance_squared_to(b.position))
				if enemies.is_empty(): return {"code": Code.NO_EFFECT}
				var ids: Array[String] = []
				for enemy in enemies.slice(0, int(data.amount)): ids.append(enemy.source_enemy_id)
				command.metadata = {"target_enemy_ids": ids}
			manager.current.pending_commands.append(command)
	if data.usage_rule == StrategyCardData.Usage.CONSUME:
		card.consumed = true
	else:
		manager.used_cards[card_id] = true
		if data.usage_rule == StrategyCardData.Usage.COOLDOWN: card.wins_left = maxi(1, data.cooldown_wins)
	if member_id != "": manager.current.selected_member_id = member_id
	run.strategy_use_receipts[request_id] = {"card_id": card_id, "member_id": member_id if member_id != "" else (unit.actor_id() if unit != null else "")}
	if card.kind == &"iron":
		manager.parry_readiness_requested.emit(member_id, data.duration * k, data.amount)
	manager.card_played.emit(card_id, unit.actor_id() if unit != null else "", point)
	return {"code": Code.OK, "kind": card.kind, "pending": command != null}
