class_name StrategyEffects
extends RefCounted
const FIELDS = {"shieldHp": "shield_hp", "shieldTime": "shield_remaining", "ironDefenseTime": "iron_defense_remaining", "parryCooldown": "parry_cooldown", "parryTime": "parry_remaining", "defenseCooldown": "defense_cooldown", "stun": "stun_remaining", "invincible": "invincible_remaining"}
const BOOL_FIELDS = {"parryCounterUsed": "parry_counter_used", "parryPulseUsed": "parry_pulse_used"}
static func heal(unit: BattleUnit, base: float) -> float:
	# Strategy recovery during hold uses the recipient healingPower, no caster.
	var gain: float = minf(maxf(0, base)*(unit.healing_power if unit.battle.full_characters_enabled else 1), unit.max_hp - unit.current_hp)
	if not unit.alive or gain <= 0: return 0
	unit.current_hp += gain
	unit.queue_redraw()
	return gain
static func advance(unit: BattleUnit, delta: float) -> void:
	for field in ["shield_remaining", "iron_defense_remaining", "parry_cooldown", "parry_remaining", "defense_cooldown", "invincible_remaining", "evade_remaining"]:
		unit.set(field, maxf(0, float(unit.get(field)) - delta))
	if unit.shield_remaining <= 0: unit.shield_hp = 0
static func absorb(unit: BattleUnit, amount: float) -> float:
	var absorbed: float = minf(amount, unit.shield_hp) if unit.shield_remaining > 0 else 0.0
	unit.shield_hp -= absorbed
	if unit.shield_hp <= 0: unit.shield_remaining = 0
	return absorbed
static func inject(unit: BattleUnit, state: Dictionary) -> void:
	for key in FIELDS:
		var value = state.get(key, 0)
		if (value is int or value is float) and is_finite(float(value)):
			unit.set(FIELDS[key], maxf(0, float(value)))
	for pair in [["retreatRemaining", "command_retreat_until"], ["specialRemaining", "strategy_special_until"]]:
		var value = state.get(pair[0], 0)
		if (value is int or value is float) and is_finite(float(value)):
			unit.set(pair[1], maxf(0, float(value)))
	for key in BOOL_FIELDS:
		if state.get(key) is bool: unit.set(BOOL_FIELDS[key], state[key])
	if (state.get("face") is int or state.get("face") is float) and is_finite(float(state.face)): unit.facing = float(state.face)
	unit.retreat_point = unit.position
static func snapshot(unit: BattleUnit) -> Dictionary:
	var state: Dictionary = unit.character_specific_state.duplicate(true)
	for key in FIELDS:
		var value: float = unit.get(FIELDS[key])
		if value > 0 or state.has(key): state[key] = value
	for pair in [["retreatRemaining", "command_retreat_until"], ["specialRemaining", "strategy_special_until"]]:
		var value: float = maxf(0, float(unit.get(pair[1])) - unit.battle.clock.elapsed)
		if value > 0 or state.has(pair[0]): state[pair[0]] = value
	for key in BOOL_FIELDS:
		if unit.get(BOOL_FIELDS[key]) or state.has(key): state[key] = unit.get(BOOL_FIELDS[key])
	if unit.battle.common_combat_enabled or state.has("face"): state["face"] = unit.facing
	return CharacterPersistence.snapshot(unit,state)
