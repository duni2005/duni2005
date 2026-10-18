class_name UnitStateCodec
extends RefCounted
## Explicit persistent-state whitelist. Deep-copy dictionaries at every boundary.
## No positions/targets/normal attack phases/AI decisions are round-tripped.
## Normal cooldown is preserved through CharacterPersistence (Phase8 contract).
## StrategyEffects transports the explicit common defense/status timer whitelist.

static func is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for item in value:
				if not is_pure_data(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not (key is String or key is StringName or key is int) or not is_pure_data(value[key], depth + 1):
					return false
			return true
	return false # Includes Nodes, Resources, Callables and other object references.

static func valid_member(member: GuildMemberState, data: UnitData) -> bool:
	return member != null and data != null and not member.member_id.is_empty() and member.unit_type_id == data.type_id and is_finite(member.current_hp) and member.current_hp >= 0.0 and is_finite(member.ultimate_gauge) and is_finite(member.transcendence_gauge) and is_pure_data(member.character_specific_state)

static func can_spawn(member: GuildMemberState, data: UnitData) -> bool:
	return valid_member(member, data) and member.is_alive() # Energy 0 is allowed.

static func inject(unit: BattleUnit, member: GuildMemberState, run_id: String) -> void:
	unit.source_member_id = member.member_id
	unit.source_run_id = run_id
	unit.current_hp = clampf(member.current_hp, 0.0, unit.max_hp)
	unit.alive = unit.current_hp > 0.0
	unit.energy = member.energy
	unit.equipment_fang_kills=member.fang_kills
	unit.ultimate_gauge = member.ultimate_gauge
	unit.transcendence_gauge = member.transcendence_gauge
	unit.stance = CombatStance.normalize(member.stance)
	unit.character_specific_state = member.character_specific_state.duplicate(true)
	StrategyEffects.inject(unit, unit.character_specific_state)
	CharacterPersistence.restore(unit)

static func snapshot(unit: BattleUnit) -> Dictionary:
	if not is_finite(unit.current_hp) or not is_finite(unit.ultimate_gauge) or not is_finite(unit.transcendence_gauge) or not is_pure_data(unit.character_specific_state):
		return {}
	return {
		"member_id": unit.source_member_id,
		"unit_type_id": unit.data.type_id,
		"fang_kills": unit.equipment_fang_kills,
		"current_hp": clampf(unit.current_hp, 0.0, unit.max_hp),
		"ultimate_gauge": clampf(unit.ultimate_gauge, 0.0, GuildMemberState.MAX_GAUGE),
		"transcendence_gauge": clampf(unit.transcendence_gauge, 0.0, GuildMemberState.MAX_GAUGE),
		"stance": CombatStance.normalize(unit.stance),
		"character_specific_state": StrategyEffects.snapshot(unit),
	}

static func valid_snapshot(snapshot_data: Dictionary, member: GuildMemberState, data: UnitData, hp_limit: float = -1) -> bool:
	if member == null or data == null or snapshot_data.get("member_id") != member.member_id or snapshot_data.get("unit_type_id") != member.unit_type_id:
		return false
	for key in ["current_hp", "ultimate_gauge", "transcendence_gauge"]:
		var value = snapshot_data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0:
			return false
	var kills = snapshot_data.get("fang_kills", member.fang_kills)
	if not kills is int or kills < 0: return false
	if float(snapshot_data.current_hp) > (data.max_hp if hp_limit < 0 else hp_limit) or float(snapshot_data.ultimate_gauge) > 100.0 or float(snapshot_data.transcendence_gauge) > 100.0:
		return false
	return snapshot_data.get("character_specific_state") is Dictionary and is_pure_data(snapshot_data.character_specific_state)

static func restore(member: GuildMemberState, snapshot_data: Dictionary) -> void:
	# Called only after the whole settlement batch has passed validation.
	member.current_hp = float(snapshot_data.current_hp)
	member.fang_kills=int(snapshot_data.get("fang_kills",member.fang_kills))
	member.ultimate_gauge = float(snapshot_data.ultimate_gauge)
	member.transcendence_gauge = float(snapshot_data.transcendence_gauge)
	member.stance = CombatStance.normalize(snapshot_data.get("stance"))
	member.character_specific_state = snapshot_data.character_specific_state.duplicate(true)
