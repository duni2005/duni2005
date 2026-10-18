class_name EnemyTurningPlan
extends RefCounted
## Pure identity-based data. No Unit, target Node or UI reference.
const SPECIAL: StringName = &"special"
const FOCUS: StringName = &"focus"
const RETREAT: StringName = &"retreat"
var plan_id: String = ""
var source_enemy_id: String = ""
var plan_type: StringName = SPECIAL
var target_member_id: String = ""
var _metadata: Dictionary = {}
var metadata: Dictionary:
	get: return _metadata.duplicate(true)
	set(value):
		if UnitStateCodec.is_pure_data(value):
			_metadata = value.duplicate(true)
var executed: bool = false

static func special_metadata(type_id: int) -> Dictionary:
	# dist/ultimate.js: type 7 (shotgun) is the only null ULTIMATES entry.
	if type_id == 7:
		return {"mode": "temporary_boost", "duration": 8.0, "damage_multiplier": 1.25, "cooldown": 0.0, "ammo": 2, "reloadRemaining": 0.0}
	return {"mode": "ultimate_ready", "gauge_gain": 100.0, "ultThink": 0.0, "ultReadyAge": 5.0, "strategyUltimateReady": true}
