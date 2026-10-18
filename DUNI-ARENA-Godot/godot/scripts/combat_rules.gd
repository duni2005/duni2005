class_name CombatRules
extends RefCounted
## Formulas from combat.js/ai.js; base defense is NOT flat HP reduction.
static func js_round(value: float) -> float:
	return floorf(value + 0.5)
static func fatigue(unit, kind: StringName) -> float:
	var missing: int = clampi(5 - unit.energy, 0, 5) if unit != null and not unit.source_member_id.is_empty() else 0
	return 1 + missing * .03 if kind == &"taken" else 1 - missing * .05
static func attack(unit) -> float:
	var stance: float = .8 if unit.stance == CombatStance.CAUTIOUS else 1.25 if unit.stance == CombatStance.RUSH else .85 if unit.stance == CombatStance.COVER else 1.0
	return unit.attack_power * stance * (1.25 if unit.strategy_special_until > unit.battle.clock.elapsed else 1.0)
static func defense(unit) -> float:
	var aura: float=0
	if unit.battle.full_characters_enabled:
		for friend in unit.battle.units:
			if friend.alive:aura=maxf(aura,friend.ability.defense_aura(friend,unit))
	return maxf(1, (unit.defense_power + unit.additional_defense+aura) * (1.15 if unit.stance == CombatStance.COVER else 1)*(unit.ability.defense_factor(unit) if unit.battle.full_characters_enabled else 1))
static func armor(unit) -> float:
	return maxf(0, defense(unit) - unit.defense_power)
static func taken(unit) -> float:
	return (1.2 if unit.character_specific_state.get("saintFallen",false) and unit.data.type_id==19 else 1)*(1.15 if unit.state_value("curseTime")>0 else 1)*(1.2 if unit.stance == CombatStance.RUSH else 1.0) * fatigue(unit, &"taken")
