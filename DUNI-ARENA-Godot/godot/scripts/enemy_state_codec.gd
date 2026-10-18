class_name EnemyStateCodec
extends RefCounted
## Web enemy whitelist and stable-ID cast/relationship codec for all 26 types.
## Normal target/AI/active attacks/projectiles are deliberately never copied.

static func safe_position(point: Vector2) -> Vector2:
	return MovementController.clamp_position(point) if point.is_finite() else Vector2(640, 400)

static func valid(enemy: EnemyRoomState, data: UnitData) -> bool:
	return enemy != null and data != null and not enemy.enemy_id.is_empty() and enemy.unit_type_id == data.type_id and is_finite(enemy.current_hp) and enemy.current_hp >= 0 and is_finite(enemy.ultimate_gauge) and UnitStateCodec.is_pure_data(enemy.persistent_state)

static func placement(enemy: EnemyRoomState, data: UnitData, room_id: String) -> Dictionary:
	if not valid(enemy, data) or not enemy.alive or room_id.is_empty():
		return {}
	return {"data": data, "team": 1, "position": safe_position(enemy.position), "enemy": enemy, "source_room_id": room_id, "combat_stats": enemy.combat_stats, "current_hp": clampf(enemy.current_hp, 0, enemy.max_hp(data))}

static func inject(unit: BattleUnit, enemy: EnemyRoomState, room_id: String) -> void:
	unit.source_enemy_id = enemy.enemy_id
	unit.source_room_id = room_id
	unit.current_hp = clampf(enemy.current_hp, 0, unit.max_hp)
	unit.alive = unit.current_hp > 0
	unit.position = safe_position(enemy.position)
	unit.ultimate_gauge = enemy.ultimate_gauge
	unit.stance = CombatStance.normalize(enemy.stance)
	unit.character_specific_state = enemy.persistent_state.duplicate(true)
	StrategyEffects.inject(unit, unit.character_specific_state)
	CharacterPersistence.restore(unit)
	var remaining = enemy.persistent_state.get("retreatRemaining", 0.0)
	if (remaining is int or remaining is float) and is_finite(float(remaining)) and remaining > 0:
		unit.command_retreat_until = float(remaining)
		# Web recreates retreatPoint on the first fleeing movement.
		unit.retreat_point = unit.position
	var special = enemy.persistent_state.get("specialRemaining", 0.0)
	if (special is int or special is float) and is_finite(float(special)):
		unit.strategy_special_until = maxf(0, float(special))
	# Web saves general cooldown despite recreating normal attack phases.
	var cooldown = enemy.persistent_state.get("cooldown")
	if (cooldown is int or cooldown is float) and is_finite(float(cooldown)):
		unit.combat.cooldown = float(cooldown)

static func snapshot(unit: BattleUnit) -> Dictionary:
	if not is_finite(unit.current_hp) or not is_finite(unit.ultimate_gauge) or not UnitStateCodec.is_pure_data(unit.character_specific_state):
		return {}
	var state: Dictionary = StrategyEffects.snapshot(unit)
	state["cooldown"] = unit.combat.cooldown
	state["retreatRemaining"] = maxf(0, unit.command_retreat_until - unit.battle.clock.elapsed)
	state["specialRemaining"] = maxf(0, unit.strategy_special_until - unit.battle.clock.elapsed)
	return {"enemy_id": unit.source_enemy_id, "unit_type_id": unit.data.type_id, "alive": unit.alive, "current_hp": clampf(unit.current_hp, 0, unit.max_hp), "position": safe_position(unit.position), "ultimate_gauge": clampf(unit.ultimate_gauge, 0, 100), "stance": unit.stance, "persistent_state": state}

static func valid_snapshot(saved: Dictionary, enemy: EnemyRoomState, data: UnitData) -> bool:
	if enemy == null or data == null or saved.get("enemy_id") != enemy.enemy_id or saved.get("unit_type_id") != enemy.unit_type_id:
		return false
	for key in ["current_hp", "ultimate_gauge"]:
		var value = saved.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0:
			return false
	return saved.current_hp <= enemy.max_hp(data) and saved.ultimate_gauge <= 100 and saved.get("position") is Vector2 and saved.position.is_finite() and saved.position == safe_position(saved.position) and saved.get("alive") == (saved.current_hp > 0) and saved.get("persistent_state") is Dictionary and UnitStateCodec.is_pure_data(saved.persistent_state)

static func restore(enemy: EnemyRoomState, saved: Dictionary) -> void:
	enemy.current_hp = float(saved.current_hp)
	enemy.position = saved.position
	enemy.ultimate_gauge = float(saved.ultimate_gauge)
	enemy.stance = CombatStance.normalize(saved.get("stance"))
	enemy.persistent_state = saved.persistent_state.duplicate(true)
