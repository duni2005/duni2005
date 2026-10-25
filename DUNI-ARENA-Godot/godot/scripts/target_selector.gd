class_name TargetSelector
extends RefCounted
## Replace this policy later without changing movement or damage code.

func is_valid_enemy(unit, candidate) -> bool:
	return is_instance_valid(candidate) and candidate != unit and candidate.alive and candidate.team != unit.team and (not unit.battle.common_combat_enabled or CombatPerception.can_perceive(unit, candidate))

func select_target(unit, candidates: Array):
	if not unit.alive or unit.battle.finished:
		return null
	if unit.battle.full_characters_enabled and unit.data.type_id in [15,24]:return unit.ability.choose_target(unit,unit.enemies())
	if unit.taunted_until > unit.battle.clock.elapsed:
		for candidate in candidates:
			if candidate.source_member_id == unit.taunted_member_id and is_valid_enemy(unit, candidate):
				return candidate
	if unit.focus_until > unit.battle.clock.elapsed:
		for candidate in candidates:
			if candidate.source_member_id == unit.focus_member_id and is_valid_enemy(unit, candidate):
				return candidate
	if unit.battle.full_characters_enabled:
		if unit.stance==CombatStance.COVER:
			var anchor=unit.battle.find_actor(unit.cover_actor_id)
			if anchor==null or not anchor.alive or anchor.team!=unit.team:
				var allies: Array=unit.friends();allies.sort_custom(func(a,b):return unit.deployment_position.distance_to(a.deployment_position)<unit.deployment_position.distance_to(b.deployment_position))
				anchor=allies[0] if not allies.is_empty() else null;unit.cover_actor_id=anchor.actor_id() if anchor!=null else ""
			if anchor!=null and anchor.alive:
				var threats: Array=unit.enemies().filter(func(e):return e.position.distance_to(anchor.position)<320)
				if not threats.is_empty():return CharacterAbility.nearest(anchor,threats)
		if unit.threat_response.response.get("mode",&"")==&"counter":
			var reply=unit.battle.find_unit(unit.threat_response.response.get("source_id",0))
			if is_valid_enemy(unit,reply):return reply
		var punish=unit.battle.find_actor(unit.brain.punish_actor)
		if unit.brain.punish_until>unit.battle.clock.elapsed and is_valid_enemy(unit,punish):return punish
		var best=unit.ability.choose_target(unit,unit.enemies())
		# Character choices that aim at allies (healing, support) are kept as they are.
		if best==null or best.team!=unit.team:best=unit.mind.pick_target(unit,best)
		return committed(unit,best)
	var nearest = null
	var nearest_distance: float = INF
	for candidate in candidates:
		if not is_valid_enemy(unit, candidate):
			continue
		var distance: float = unit.position.distance_squared_to(candidate.position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

## Target commitment (full characters): keep the current target for a while instead of
## flicking between enemies at similar range. Switch early only when the target is gone,
## another enemy is already in reach while this one is not, or another is far closer.
## After the hold, a better-priority choice or a clearly closer one takes over.
const HOLD: float = 1.6
var hold_until: float = 0
func committed(unit, best):
	var current = unit.target
	if best == null or current == best:
		if best != null and hold_until <= unit.battle.clock.elapsed:hold_until = unit.battle.clock.elapsed + HOLD
		return best
	if current == null or not is_valid_enemy(unit, current) or current.unavailable() or not unit.enemies().has(current):
		return _switch(unit, best)
	var now: float = unit.battle.clock.elapsed
	var dc: float = unit.position.distance_to(current.position);var db: float = unit.position.distance_to(best.position)
	var reach: float = unit.data.attack_range + 30 * unit.combat_scale()
	if (db < reach and dc > reach * 1.4) or db < dc * .5:return _switch(unit, best)
	if now < hold_until:return current
	var seen: Array = unit.enemies()
	var pb: float = unit.ability.target_priority(unit, best, seen);var pc: float = unit.ability.target_priority(unit, current, seen)
	if pb < pc or (is_equal_approx(pb, pc) and db < dc * .75):return _switch(unit, best)
	hold_until = now + HOLD * .5
	return current
func _switch(unit, target):
	hold_until = unit.battle.clock.elapsed + HOLD
	return target
