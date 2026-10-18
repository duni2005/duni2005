class_name ItemData
extends Resource
## Shared definition; no ownership or use state.
@export var kind: StringName
@export var display_name: String
@export var description: String
@export var emoji: String
@export var gold_price: int
@export var max_hp_multiplier: float = 1
@export var attack_multiplier: float = 1
@export var speed_multiplier: float = 1
@export var healing_multiplier: float = 1
@export var victory_gold: int = 0
@export var vigor_totem: bool = false
@export var charge_totem: bool = false
@export var kill_growth: bool = false
@export var opening_awl: bool = false
@export var consumable: bool = false
