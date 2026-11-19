class_name StrategyCardCatalog
extends RefCounted
## Card definitions are data (data/strategy/*.tres): card kind (active / passive), usage, cooldown
## type, conditions, disruption grade and effect numbers.
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
	&"rally": preload("res://data/strategy/rally.tres"),
	&"resonance": preload("res://data/strategy/resonance.tres"),
	&"command_flag": preload("res://data/strategy/command_flag.tres"),
	&"indomitable": preload("res://data/strategy/indomitable.tres"),
	&"lunchbox": preload("res://data/strategy/lunchbox.tres"),
	&"heal_zone": preload("res://data/strategy/heal_zone.tres"),
	&"pressure": preload("res://data/strategy/pressure.tres"),
}
static func get_card(kind: StringName) -> StrategyCardData:
	return DEFINITIONS.get(kind)
