class_name ItemCatalog
extends RefCounted
const KINDS = [&"vital",&"fang",&"boots",&"reengrave",&"greenNecklace",&"goldToken",&"vigorTotem",&"chargeTotem",&"predatorFang",&"thickAwl"]
static var _definitions: Dictionary = {}
static func all() -> Dictionary:
	if _definitions.is_empty():
		for kind in KINDS:_definitions[kind]=load("res://data/items/%s.tres"%kind)
	return _definitions.duplicate()
static func get_item(kind: StringName) -> ItemData:return all().get(kind)
