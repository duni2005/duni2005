class_name CombatRules
extends RefCounted
## Formulas from combat.js/ai.js; base defense is NOT flat HP reduction.
static func js_round(value: float) -> float:
	return floorf(value + 0.5)
static func attack(unit) -> float:
	return unit.attack_power * stance_factor(unit)
## Stance and the strategy power buff, part of attack %.
static func stance_factor(unit) -> float:
	var stance: float = .8 if unit.stance == CombatStance.CAUTIOUS else 1.25 if unit.stance == CombatStance.RUSH else .85 if unit.stance == CombatStance.COVER else 1.0
	return stance * (1.25 if unit.strategy_special_until > unit.battle.clock.elapsed else 1.0)
## Attack % of a hit: the stat (items, kill growth, elite/boss multiplier) times stance effects.
static func attack_factor(unit) -> float:
	return (unit.combat_stats.attack if unit.combat_stats != null else 1.0) * stance_factor(unit)
static func defense(unit) -> float:
	return maxf(1, defense_sum(unit))
## Defense before the legacy floor of 1; the new mitigation curve also handles negative values.
static func defense_sum(unit) -> float:
	var aura: float=0
	if unit.battle.full_characters_enabled:
		for friend in unit.battle.units:
			if friend.alive:aura=maxf(aura,friend.ability.defense_aura(friend,unit))
	return ((unit.defense_power + unit.additional_defense+EquipmentCombatEffects.armor(unit)+aura) * (1.15 if unit.stance == CombatStance.COVER else 1)*(unit.ability.defense_factor(unit) if unit.battle.full_characters_enabled else 1))
## Damage left after defense: defense plus physical or magic defense for that kind of hit.
static func mitigation(unit, kind: StringName) -> float:
	var extra: float = 0
	if unit.combat_stats != null:extra = unit.combat_stats.physical_defense if kind == &"physical" else unit.combat_stats.magic_defense
	else:extra = UnitStatTable.base_physical_defense(unit.data.type_id) if kind == &"physical" else UnitStatTable.base_magic_defense(unit.data.type_id)
	return UnitStatTable.mitigation(defense_sum(unit) + extra)
static func armor(unit) -> float:
	return maxf(0, defense(unit) - unit.defense_power)
static func taken(unit) -> float:
	return (1.2 if unit.character_specific_state.get("saintFallen",false) and unit.data.type_id==19 else 1)*(1.15 if unit.state_value("curseTime")>0 else 1)*(1.2 if unit.stance == CombatStance.RUSH else 1.0)
