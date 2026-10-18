class_name EnemySpawnEntry
extends RefCounted
## Immutable encounter specification, distinct from current EnemyRoomState.
var enemy_id: String
var unit_type_id: int
var level: int = 0
var initial_position: Vector2
var rank: StringName = &"normal"
var body_scale: float = 1
var hp_multiplier: float = 1
var damage_multiplier: float = 1
var defense_multiplier: float = 1
var speed_multiplier: float = 1
func set_rank(value: StringName) -> void:
	rank = value
	if rank == &"boss":
		body_scale=1.85; hp_multiplier=3.6; damage_multiplier=2.15; defense_multiplier=2; speed_multiplier=1.12
	elif rank == &"elite":
		body_scale=1.5; hp_multiplier=2.5; damage_multiplier=1.65; defense_multiplier=1.5; speed_multiplier=1.08
