class_name RoomContentResult
extends RefCounted
## Service-created completion proposal, receipt checked by TowerController.
var room_id: String
var receipt: String
var choice: StringName
var stay_for_result: bool = false
var outcome: Dictionary = {}
