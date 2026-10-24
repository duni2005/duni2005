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
## Item grade: "common" (basic, combines in pairs), "rare" (combined), "ancient", "legacy" (old saves).
@export var grade: StringName = &"legacy"
## Combined items: the two basic kinds they were made from.
@export var components: Array[StringName] = []
@export var physical_bonus: float = 0
@export var magic_bonus: float = 0
@export var element_bonus: float = 0
@export var ultimate_bonus: float = 0
@export var armor_bonus: float = 0
@export var attack_speed_bonus: float = 0
@export var crit_bonus: float = 0
## Strength of the special flag above (totems, kill growth, awl); legacy items are 1.
@export var ability_power: float = 1
## Ancient effects.
@export var phoenix: bool = false
@export var hourglass: bool = false
@export var dragon_heart: bool = false
