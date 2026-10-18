class_name StrategyCommandExecutor
extends RefCounted
static func cancel_intent(unit: BattleUnit) -> void:
	unit.combat.cancel(unit)
	if unit.battle.full_characters_enabled:
		unit.brain.commit_until=0;unit.brain.punish_until=0;unit.brain.attack_decision.clear();unit.brain.heading=Vector2.ZERO;unit.threat_response.response.clear()
		CharacterLifecycle.cancel_duel(unit);unit.ultimate.cast.clear();unit.dodge_state.clear();unit.evade_remaining=0;unit.knockback_velocity=Vector2.ZERO;unit.set_state("guardRemaining",0)
		for attack in unit.battle.melee_strikes:
			if attack.source_battle_id==unit.battle_id:attack.life=0
	unit.strategy_dash.clear()
	unit.strategy_heading = Vector2.ZERO
	unit.velocity = Vector2.ZERO
static func execute_all(manager: TurningPointManager) -> void:
	# Web: enemy forecasts first, then allied UNIT order, evade BEFORE taunt.
	for unit in manager.battle.units:
		if manager.battle.finished: return
		if not unit.alive or unit.source_member_id.is_empty(): continue
		for kind in [&"evade", &"taunt"]:
			for command in manager.current.pending_commands:
				if command.executed or command.member_id != unit.source_member_id or command.command_type != kind: continue
				command.executed = true
				if kind == &"evade":
					cancel_intent(unit)
					StrategyMovementController.begin_retreat(unit, manager.battle.rng, command.duration)
					if manager.battle.full_characters_enabled:unit.brain.disengage_until=0
				else:
					for id in command.metadata.get("target_enemy_ids", []):
						var enemy: BattleUnit = EnemyPlanExecutor.find_enemy(manager.battle, id)
						if enemy == null: continue
						cancel_intent(enemy)
						enemy.command_retreat_until = 0
						enemy.taunted_member_id = unit.source_member_id
						enemy.taunted_until = manager.battle.clock.elapsed + command.duration
						enemy.target = unit
