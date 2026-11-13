class_name UnitCombatStats
extends RefCounted
## Per-spawn calculated stats, never the shared character Resource.
## Base stats: max HP, defense (all damage), physical/magic defense (that kind only), attack %
## (multiplies all damage), physical/magic damage (the stat each damage instance scales with).
var max_hp: float
var attack: float = 1
var defense: float
var physical_defense: float = 0
var magic_defense: float = 0
var physical_damage: float = 0
var magic_damage: float = 0
var speed: float
var scale: float = 1
var crit_damage: float = UnitStatTable.CRIT_DAMAGE
## Special stats: healing received, ultimate damage %, and bonuses per element / damage tag
## (UnitStatTable.ELEMENTS, DAMAGE_TAGS); healing_power is healing given.
var healing_received: float = 1
var ult_damage: float = 1
var element_bonus: Dictionary = {}
var tag_bonus: Dictionary = {}

var healing_power: float = 1
var victory_gold: int = 0
var vigor_totem_count: int = 0
var charge_totem_count: int = 0
var fang_count: int = 0
var opening_awl_count: int = 0
var equipment_attack_without_growth: float = 0
## Item stat lines (see ItemCatalog). Powers multiply; armor/crit add. element_power is the
## "element damage %" special stat, ultimate_power the "ultimate charge %" one.
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
## 0.94 items (numbers in ItemTuning, run by ItemEffects).
var range_multiplier: float = 1
var duelist: bool = false
var vanguard: bool = false
var elementalist: bool = false
var enchant: bool = false
var overcharge_count: int = 0
var chain_ring: bool = false
var sovereign: bool = false
var immovable: bool = false
var sanctuary: bool = false
var kind_swap: bool = false
var crown: bool = false
var dice: bool = false
## 0.95 items: effect key -> how many worn, the items themselves (빈 액자 copies one), the enemy
## rank (normal / elite / boss; 처형의 낫 spares the last two) and the 망고 씨앗 stage.
var effects: Dictionary = {}
var items: Array = []
var rank: StringName = &"normal"
var mango_stage: int = 0

## Base stats of a character from UnitStatTable, with level-style growth factors.
static func from_table(data: UnitData,hp_factor: float=1,damage_factor: float=1,defense_factor: float=1,speed_factor: float=1) -> UnitCombatStats:
	var stats:=UnitCombatStats.new();var t: int=data.type_id
	# UnitBalance: tier and per-unit corrections on top of the source values (0.75.0).
	hp_factor*=UnitBalance.hp(data);damage_factor*=UnitBalance.damage(data)
	stats.max_hp=data.max_hp*hp_factor;stats.speed=data.move_speed*speed_factor
	stats.physical_damage=UnitStatTable.base_physical(t)*damage_factor;stats.magic_damage=UnitStatTable.base_magic(t)*damage_factor
	stats.defense=UnitStatTable.base_defense(t)*defense_factor
	stats.physical_defense=UnitStatTable.base_physical_defense(t);stats.magic_defense=UnitStatTable.base_magic_defense(t)
	return stats
## Gear rules shared by guild members and custom battle entries.
func apply_item(item: ItemData) -> void:
	max_hp*=item.max_hp_multiplier;attack*=item.attack_multiplier;speed*=item.speed_multiplier
	healing_power*=item.healing_multiplier;healing_received*=item.healing_multiplier;victory_gold+=item.victory_gold
	vigor_totem_count+=int(item.vigor_totem);charge_totem_count+=int(item.charge_totem)
	fang_count+=int(item.kill_growth);opening_awl_count+=int(item.opening_awl)
	if item.vigor_totem:vigor_totem_power+=item.ability_power
	if item.charge_totem:charge_totem_power+=item.ability_power
	if item.kill_growth:fang_power+=item.ability_power
	if item.opening_awl:awl_power+=item.ability_power
	physical_power+=item.physical_bonus;magic_power+=item.magic_bonus;element_power+=item.element_bonus
	ultimate_power+=item.ultimate_bonus;armor+=item.armor_bonus;attack_speed+=item.attack_speed_bonus;crit+=item.crit_bonus
	phoenix_count+=int(item.phoenix);hourglass_count+=int(item.hourglass);dragon_heart_count+=int(item.dragon_heart)
	physical_defense+=item.physical_defense_bonus;magic_defense+=item.magic_defense_bonus
	range_multiplier*=item.range_multiplier;scale*=item.scale_multiplier
	duelist=duelist or item.duelist;vanguard=vanguard or item.vanguard;elementalist=elementalist or item.elementalist
	enchant=enchant or item.enchant;overcharge_count+=int(item.overcharge);chain_ring=chain_ring or item.chain_ring
	sovereign=sovereign or item.sovereign;immovable=immovable or item.immovable;sanctuary=sanctuary or item.sanctuary
	kind_swap=kind_swap or item.kind_swap;crown=crown or item.crown;dice=dice or item.dice
	if item.effect!=&"":effects[item.effect]=int(effects.get(item.effect,0))+1
	for tag in item.tag_bonuses:
		var field: Dictionary=element_bonus if tag in UnitStatTable.ELEMENTS else tag_bonus
		field[tag]=float(field.get(tag,0))+float(item.tag_bonuses[tag])
	ult_damage+=item.ult_damage_bonus;crit_damage+=item.crit_damage_bonus
	items.append(item)
## A worn item's effect (0.95 items).
func has(effect: StringName) -> bool:return effects.has(effect)
## 빈 액자: an item added for one battle after finish_items (its damage powers scale the damage
## stats right away).
func add_item_live(item: ItemData) -> void:
	var physical: float=physical_power;var magic: float=magic_power
	apply_item(item)
	physical_damage*=physical_power/physical;magic_damage*=magic_power/magic
## Item damage powers scale the physical / magic damage stats; call once after all items.
## 저주받은 왕관 raises every stat; 두 얼굴의 가면 then swaps the physical and magic damage stats.
func finish_items() -> void:
	physical_damage*=physical_power;magic_damage*=magic_power
	if crown:
		var k: float=1+ItemTuning.CROWN_STATS
		max_hp*=k;physical_damage*=k;magic_damage*=k;defense*=k;physical_defense*=k;magic_defense*=k;speed*=k;attack_speed*=k
	if kind_swap:var keep: float=physical_damage;physical_damage=magic_damage;magic_damage=keep
## A separate copy (도박사의 주사위 changes its numbers for one battle only).
func copy() -> UnitCombatStats:
	var out:=UnitCombatStats.new()
	for p in get_property_list():
		if p.usage&PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v=get(p.name);out.set(p.name,v.duplicate(true) if v is Dictionary or v is Array else v)
	return out
## Attack growth per kill: .015 per legacy fang, stronger on the combined item.
func fang_rate() -> float:
	return .015*fang_power/fang_count if fang_count>0 else .015
