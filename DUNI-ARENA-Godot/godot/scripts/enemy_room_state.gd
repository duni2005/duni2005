class_name EnemyRoomState
extends RefCounted
## One persistent enemy owned by one room; no runtime/scene references.
var enemy_id: String = ""
var unit_type_id: int = 0
var current_hp: float = 0.0
var position := Vector2(640, 400)
var ultimate_gauge: float = 0.0:
	set(value): ultimate_gauge = clampf(value, 0, 100)
var stance: StringName = CombatStance.NORMAL
var _persistent_state: Dictionary = {}
var persistent_state: Dictionary:
	get: return _persistent_state.duplicate(true)
	set(value):
		if UnitStateCodec.is_pure_data(value):
			_persistent_state = value.duplicate(true)
var alive: bool:
	get: return is_finite(current_hp) and current_hp > 0

var spawn: EnemySpawnEntry
var combat_stats: UnitCombatStats
func max_hp(data: UnitData) -> float:
	return combat_stats.max_hp if combat_stats != null else data.max_hp
