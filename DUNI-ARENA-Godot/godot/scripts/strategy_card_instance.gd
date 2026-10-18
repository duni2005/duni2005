class_name StrategyCardInstance
extends RefCounted
## Web id/kind/usedDepth/usedFloors/readyFloor. Consumed copies kept for audit.
var card_id: int
var kind: StringName
var used_depth: int = -1
var used_floors: Array[int] = []
var ready_floor: int = 0
var consumed: bool = false
