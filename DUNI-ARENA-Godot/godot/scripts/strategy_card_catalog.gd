class_name StrategyCardCatalog
extends RefCounted
## Card definitions are data (data/strategy/*.tres): kind, cooldown, condition, use, disruption
## grade and effect numbers.
const DEFINITIONS = {
	&"mango": preload("res://data/strategy/mango.tres"),
	&"evade": preload("res://data/strategy/evade.tres"),
	&"charge": preload("res://data/strategy/charge.tres"),
	&"shield": preload("res://data/strategy/shield.tres"),
	&"iron": preload("res://data/strategy/iron.tres"),
	&"taunt": preload("res://data/strategy/taunt.tres"),
	&"disrupt": preload("res://data/strategy/disrupt.tres"),
	&"block": preload("res://data/strategy/block.tres"),
	&"seal": preload("res://data/strategy/seal.tres"),
	&"barrier": preload("res://data/strategy/barrier.tres"),
	&"feast": preload("res://data/strategy/feast.tres"),
}
static func get_card(kind: StringName) -> StrategyCardData:
	return DEFINITIONS.get(kind)
