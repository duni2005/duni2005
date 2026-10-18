class_name StrategyCommand
extends RefCounted
## Battle-local pure data; never persisted in room/guild snapshots.
var command_id: String
var card_id: int
var member_id: String
var command_type: StringName
var duration: float
var _metadata: Dictionary = {}
var metadata: Dictionary:
	get: return _metadata.duplicate(true)
	set(value):
		if UnitStateCodec.is_pure_data(value):
			_metadata = value.duplicate(true)
var executed: bool = false
