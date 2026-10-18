class_name AbilityRegistry
extends RefCounted
const NAMES = CharacterCatalog.NAMES
static func create(type_id: int) -> CharacterAbility:
	assert(type_id>=0 and type_id<NAMES.size())
	return load("res://scripts/abilities/%s_ability.gd" % NAMES[type_id]).new()
