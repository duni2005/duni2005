class_name StatusController
extends RefCounted
static func stun(unit, duration: float) -> void:
	if unit.battle.finished or unit.battle.clock.is_turning_paused() or not unit.alive or not is_finite(duration) or duration <= 0: return
	unit.stun_remaining = maxf(unit.stun_remaining, duration)
	unit.stun_revision += 1
	interrupt(unit)
	if unit.battle.full_characters_enabled and unit.stun_remaining>0:
		unit.brain.disengage_until=unit.battle.clock.elapsed+unit.stun_remaining
		unit.brain.next_initiative_at=unit.brain.disengage_until+unit.battle.rng.randf_range(.2,1.2)*unit.brain.tempo
static func interrupt(unit) -> void:
	if unit.battle.full_characters_enabled:
		if not unit.hero_rescue.is_empty():unit.stun_remaining=0;return
		CharacterLifecycle.interrupt(unit)
	unit.combat.cancel(unit)
	unit.parry_remaining = 0
	unit.dodge_state.clear()
	unit.evade_remaining = 0
	unit.strategy_dash.clear()
	unit.strategy_heading = Vector2.ZERO
	unit.velocity = Vector2.ZERO
	if unit.battle.full_characters_enabled:
		unit.brain.heading=Vector2.ZERO;unit.brain.commit_until=0;unit.brain.punish_until=0;unit.brain.attack_decision.clear()
	unit.threat_response.response.clear()
	for attack in unit.battle.melee_strikes:
		if attack.source_battle_id == unit.battle_id: attack.life = 0
	# Released projectiles / external momentum keep moving.

static func skill_charge_blocked(unit) -> bool:
	# Current runtime supports stun only. Roots/control/duels belong to later types.
	return not unit.alive or unit.stun_remaining > 0 or unit.unavailable() or not unit.puppet_control.is_empty() or not unit.duel.is_empty() or (unit.battle.full_characters_enabled and CharacterLifecycle.cc_remaining(unit)>0)
