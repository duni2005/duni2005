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
## Item stat lines (see ItemCatalog). Powers multiply; armor/crit add.
var physical_power: float = 1
var magic_power: float = 1
var element_power: float = 1
var ultimate_power: float = 1
var armor: float = 0
var attack_speed: float = 1
var crit: float = 0
## Summed ability_power of the special items; legacy items count 1 each.
var vigor_totem_power: float = 0
var charge_totem_power: float = 0
var fang_power: float = 0
var awl_power: float = 0
var phoenix_count: int = 0
var hourglass_count: int = 0
var dragon_heart_count: int = 0

## Gear rules shared by guild members and custom battle entries.
func apply_item(item: ItemData) -> void:
	max_hp*=item.max_hp_multiplier;attack*=item.attack_multiplier;speed*=item.speed_multiplier
	healing_power*=item.healing_multiplier;victory_gold+=item.victory_gold
	vigor_totem_count+=int(item.vigor_totem);charge_totem_count+=int(item.charge_totem)
	fang_count+=int(item.kill_growth);opening_awl_count+=int(item.opening_awl)
	if item.vigor_totem:vigor_totem_power+=item.ability_power
	if item.charge_totem:charge_totem_power+=item.ability_power
	if item.kill_growth:fang_power+=item.ability_power
	if item.opening_awl:awl_power+=item.ability_power
	physical_power+=item.physical_bonus;magic_power+=item.magic_bonus;element_power+=item.element_bonus
	ultimate_power+=item.ultimate_bonus;armor+=item.armor_bonus;attack_speed+=item.attack_speed_bonus;crit+=item.crit_bonus
	phoenix_count+=int(item.phoenix);hourglass_count+=int(item.hourglass);dragon_heart_count+=int(item.dragon_heart)
## Attack growth per kill: .015 per legacy fang, stronger on the combined item.
func fang_rate() -> float:
	return .015*fang_power/fang_count if fang_count>0 else .015
