class_name CharacterCatalog
extends RefCounted
const NAMES = ["warrior", "archer", "mage", "assassin", "guardian", "healer", "sniper", "shotgun", "rps", "ufc", "greatsword", "dolphin", "predator", "bomber", "swordsman", "satellite", "paladin", "hero", "tank", "fanatic", "lightning", "mirror", "galaxy", "machine_gun", "frog", "puppet","stake", "conductor", "refraction", "courier", "magnet"]
static var _data: Dictionary = {}
static func all() -> Dictionary:
	if _data.is_empty():
		for name in NAMES:
			var data: UnitData = load("res://data/%s.tres" % name)
			_data[data.type_id] = data
	return _data.duplicate()
