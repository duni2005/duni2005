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
## Item grade (ItemTuning.GRADES): common, rare, epic, legendary, ancient; legacy = old saves.
@export var grade: StringName = &"legacy"
@export var physical_bonus: float = 0
@export var magic_bonus: float = 0
@export var element_bonus: float = 0
@export var ultimate_bonus: float = 0
@export var armor_bonus: float = 0
@export var attack_speed_bonus: float = 0
@export var crit_bonus: float = 0
## Strength of the special flag above (totems, kill growth, awl); legacy items are 1.
@export var ability_power: float = 1
## Legendary effects (0.93 and earlier: ancient).
@export var phoenix: bool = false
@export var hourglass: bool = false
@export var dragon_heart: bool = false
## Flat physical / magic defense and an attack-range multiplier (일반).
@export var physical_defense_bonus: float = 0
@export var magic_defense_bonus: float = 0
@export var range_multiplier: float = 1
## Body size multiplier (거인의 심장).
@export var scale_multiplier: float = 1
## Special effects, numbers in ItemTuning (ItemEffects runs them).
@export var duelist: bool = false
@export var vanguard: bool = false
@export var elementalist: bool = false
@export var enchant: bool = false
@export var overcharge: bool = false
@export var chain_ring: bool = false
@export var sovereign: bool = false
@export var immovable: bool = false
@export var sanctuary: bool = false
## 0.95: one special effect key run by ItemEffects (&"" = stats only), bonuses by damage tag or
## element (tag -> share), ultimate / critical damage bonuses, and the element a 프리즘 조각 rolled.
@export var effect: StringName = &""
@export var tag_bonuses: Dictionary = {}
@export var ult_damage_bonus: float = 0
@export var crit_damage_bonus: float = 0
@export var element_choice: StringName = &""
## 0.96: "모든 스탯 +N%" (max HP, damage, defenses, speeds) and healing given only.
@export var all_stats: float = 0
@export var heal_power_bonus: float = 0
## 0.97: healing received only (수호자의 휘장).
@export var heal_taken_bonus: float = 0
