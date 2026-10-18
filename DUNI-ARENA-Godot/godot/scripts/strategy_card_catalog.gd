class_name StrategyCardCatalog
extends RefCounted
const DEFINITIONS = {
	&"mango": preload("res://data/strategy/mango.tres"),
	&"evade": preload("res://data/strategy/evade.tres"),
	&"charge": preload("res://data/strategy/charge.tres"),
	&"shield": preload("res://data/strategy/shield.tres"),
	&"iron": preload("res://data/strategy/iron.tres"),
	&"taunt": preload("res://data/strategy/taunt.tres"),
}
static func get_card(kind: StringName) -> StrategyCardData:
	return DEFINITIONS.get(kind)
