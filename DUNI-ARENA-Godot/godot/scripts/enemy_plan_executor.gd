class_name EnemyPlanExecutor
extends RefCounted
## Effects use persistent actor IDs; nodes are looked up only while executing.
static func find_enemy(battle: BattleManager, id: String) -> BattleUnit:
	for unit in battle.units:
		if unit.source_enemy_id == id and unit.alive and unit.team == 1:
			return unit
	return null

static func find_member(battle: BattleManager, id: String) -> BattleUnit:
	for unit in battle.units:
		if unit.source_member_id == id and unit.alive and unit.team == 0:
			return unit
	return null

static func execute(plan: EnemyTurningPlan, battle: BattleManager) -> Dictionary:
	if plan.executed or battle.finished:
		return {}
	plan.executed = true
	var enemy: BattleUnit = find_enemy(battle, plan.source_enemy_id)
	if enemy == null:
		return {}
	if plan.plan_type == EnemyTurningPlan.FOCUS and find_member(battle, plan.target_member_id) == null:
		return {} # Dead/invalid target: safe no-op, do not interrupt another action.
	StrategyCommandExecutor.cancel_intent(enemy)
	enemy.velocity = Vector2.ZERO
	match plan.plan_type:
		EnemyTurningPlan.FOCUS:
			enemy.focus_member_id = plan.target_member_id
			enemy.focus_until = battle.clock.elapsed + 10.0
		EnemyTurningPlan.RETREAT:
			StrategyMovementController.begin_retreat(enemy, battle.rng)
			if battle.full_characters_enabled:enemy.brain.disengage_until=0
		EnemyTurningPlan.SPECIAL:
			if plan.metadata.get("mode") == "temporary_boost":
				enemy.strategy_special_until = battle.clock.elapsed + float(plan.metadata.duration)
				enemy.combat.cooldown = 0.0
				# The shotgun Ability reads these exact ammo/reload runtime fields.
				enemy.character_specific_state["ammo"] = plan.metadata.ammo
				enemy.character_specific_state["reloadRemaining"] = plan.metadata.reloadRemaining
			else:
				if not battle.common_combat_enabled or not StatusController.skill_charge_blocked(enemy):
					if battle.full_characters_enabled:enemy.ultimate.gain(enemy,100)
					else:enemy.ultimate_gauge = clampf(enemy.ultimate_gauge + 100.0, 0, 100)
				# UltimateController owns think; this is a one-shot strategy readiness request.
				enemy.ultimate.think=0
				enemy.character_specific_state["ultReadyAge"] = 5.0
				enemy.character_specific_state["strategyUltimateReady"] = true
				return {"source_enemy_id": enemy.source_enemy_id, "unit_type_id": enemy.data.type_id, "request": plan.metadata.duplicate(true)}
	return {}
