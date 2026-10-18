class_name FloorState
extends RefCounted
var floor_index: int
var chapter_index: int
var unlocked: bool = false
var room_ids: Array[String] = []
var cleared_count: int = 0
var required_clear_count: int = 0
var conquered: bool = false
var bonus: StringName = &""
var bonus_item_kind: StringName = &""
