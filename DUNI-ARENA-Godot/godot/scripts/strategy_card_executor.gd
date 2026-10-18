class_name StrategyCardExecutor
extends RefCounted
## Effects and records committed synchronously; UI never mutates combat values.
enum Code { OK, NOT_HOLD, INVALID_CARD, UNAVAILABLE, INVALID_TARGET, NO_EFFECT, DUPLICATE }
static func availability(card: StrategyCardInstance, context: StrategyProgressContext) -> bool:
	if card == null or card.consumed: return false
	var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
	if data == null: return false
	if data.usage_rule == StrategyCardData.Usage.FLOOR:
		return card.used_depth != context.current_depth and context.current_depth not in card.used_floors
	if data.usage_rule == StrategyCardData.Usage.COOLDOWN:
		return context.unlocked_floor >= card.ready_floor
	return true
static func apply(manager: TurningPointManager, card_id: int, member_id: String, request_id: String) -> Dictionary:
	if manager == null or not manager.is_paused() or manager.battle.run_end_requested or manager.guild.state.game_over:
		return {"code": Code.NOT_HOLD}
	var run: RunState = manager.guild.state
	if request_id.is_empty(): return {"code": Code.INVALID_CARD}
	if run.strategy_use_receipts.has(request_id): return {"code": Code.DUPLICATE}
	var card: StrategyCardInstance = run.get_strategy_card(card_id)
	if card == null: return {"code": Code.INVALID_CARD}
	if not availability(card, run.strategy_progress): return {"code": Code.UNAVAILABLE}
	var unit: BattleUnit = EnemyPlanExecutor.find_member(manager.battle, member_id)
	if unit == null or manager.guild.get_member(member_id) == null or unit.team != 0:
		return {"code": Code.INVALID_TARGET}
	var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
	var command: StrategyCommand
	match card.kind:
		&"mango":
			if StrategyEffects.heal(unit, unit.max_hp * data.amount) <= 0: return {"code": Code.NO_EFFECT}
		&"charge":
			if unit.ultimate_gauge >= 100 or (manager.battle.common_combat_enabled and StatusController.skill_charge_blocked(unit)): return {"code": Code.NO_EFFECT}
			if manager.battle.full_characters_enabled:
				if unit.ultimate.gain(unit,data.amount)<=0:return {"code":Code.NO_EFFECT}
			else:unit.ultimate_gauge = minf(100, unit.ultimate_gauge + data.amount)
		&"shield":
			unit.shield_hp = data.amount
			unit.shield_remaining = data.duration
		&"iron":
			unit.iron_defense_remaining = data.duration
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
			command.duration = data.duration
			if card.kind == &"taunt":
				# Both currently implemented types are visible. Perception/stealth later.
				var enemies: Array = manager.battle.units.filter(func(v): return v.alive and v.team == 1 and not v.source_enemy_id.is_empty() and (not manager.battle.common_combat_enabled or CombatPerception.can_perceive(v,unit)))
				enemies.sort_custom(func(a, b): return unit.position.distance_squared_to(a.position) < unit.position.distance_squared_to(b.position))
				if enemies.is_empty(): return {"code": Code.NO_EFFECT}
				var ids: Array[String] = []
				for enemy in enemies.slice(0, int(data.amount)): ids.append(enemy.source_enemy_id)
				command.metadata = {"target_enemy_ids": ids}
			manager.current.pending_commands.append(command)
	if data.usage_rule == StrategyCardData.Usage.ONCE:
		card.consumed = true
	elif data.usage_rule == StrategyCardData.Usage.FLOOR:
		card.used_depth = run.strategy_progress.current_depth
		card.used_floors.append(card.used_depth)
	else:
		card.ready_floor = run.strategy_progress.unlocked_floor + 3
	manager.current.selected_member_id = member_id
	run.strategy_use_receipts[request_id] = {"card_id": card_id, "member_id": member_id}
	if card.kind == &"iron":
		manager.parry_readiness_requested.emit(member_id, data.duration, data.amount)
	return {"code": Code.OK, "kind": card.kind, "pending": command != null}
