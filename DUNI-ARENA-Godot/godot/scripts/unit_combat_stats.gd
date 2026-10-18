class_name UnitCombatStats
extends RefCounted
## Per-spawn calculated stats, never the shared character Resource.
var max_hp: float
var attack: float
var defense: float
var speed: float
var scale: float = 1

var healing_power: float = 1
var victory_gold: int = 0
var vigor_totem_count: int = 0
var charge_totem_count: int = 0
var fang_count: int = 0
var opening_awl_count: int = 0
var equipment_attack_without_growth: float = 0
