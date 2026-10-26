class_name ParryController
extends RefCounted
var rolls: Dictionary = {}
var counter_targets: Dictionary = {}
static func perfect(unit) -> bool:
	return unit.stun_remaining <= 0 and unit.parry_remaining > .8 + 1e-8
static func factor(unit) -> float:
	return 1 if unit.stun_remaining > 0 else 0 if perfect(unit) else .4 if unit.parry_remaining > 0 else 1
static func available(unit) -> bool:
	if unit.battle.full_characters_enabled and (unit.unavailable() or not unit.frog_action.is_empty() or not unit.hero_rescue.is_empty() or not unit.machine_dash.is_empty() or not unit.ultimate.cast.is_empty() or not unit.duel.is_empty()):return false
	return unit.alive and not unit.battle.finished and unit.stun_remaining <= 0 and unit.parry_cooldown <= 0 and unit.parry_remaining <= 0 and unit.evade_remaining <= 0 and unit.dodge_state.is_empty() and unit.strategy_dash.is_empty() and unit.combat_state in [CombatController.State.IDLE, CombatController.State.WINDUP]
static func success_chance(unit, power: float) -> float:
	return minf(1, clampf(pow(CombatRules.defense(unit) / maxf(1, power), 1.2), .08, 1) * StanceRules.pick(unit, 1.0, StanceRules.CAUTIOUS_PARRY_SUCCESS, 1.0))
func start(unit, source = null) -> bool:
	if not available(unit) or unit.battle.clock.is_turning_paused(): return false
	unit.combat.cancel(unit)
	unit.parry_remaining = 1.2
	unit.parry_cooldown = ParryReadiness.cooldown_duration(unit)
	if unit.data.type_id == 0: unit.defense_cooldown = unit.parry_cooldown
	unit.parry_counter_used = false
	unit.parry_pulse_used = false
	rolls.clear()
	counter_targets.clear()
	unit.strategy_heading = Vector2.ZERO
	if unit.battle.full_characters_enabled:
		unit.brain.heading=Vector2.ZERO;unit.brain.commit_until=0;unit.brain.punish_until=0;unit.brain.attack_decision.clear();unit.brain.disengage_until=unit.battle.clock.elapsed+.55
	if is_instance_valid(source) and (not unit.battle.full_characters_enabled or unit.data.type_id!=18): unit.facing = (source.position - unit.position).angle()
	unit.battle.emit_combat_event(&"parry_start", unit.position, {"actor_id": unit.battle_id})
	return true
func try_block(unit, source, power: float, token: Variant) -> bool:
	if not perfect(unit): return false
	var key: String = str(token) if token != null else "%d:%d:%s" % [source.battle_id, source.combat.attack_serial, power]
	if not rolls.has(key): rolls[key] = unit.battle.rng.randf() < success_chance(unit, power) * unit.mind.parry_factor(unit)
	if not rolls[key]:
		unit.parry_remaining = minf(unit.parry_remaining, .8)
		return false
	reprisal(unit, source, power)
	if unit.data.type_id == 0 and not unit.parry_counter_used:
		unit.parry_counter_used = true
		unit.combat.start_counter(unit, source)
	unit.battle.emit_combat_event(&"parry_success", unit.position, {"actor_id": unit.battle_id, "source_id": source.battle_id})
	return true
func reprisal(unit, source, power: float, strength: float = 1) -> void:
	if counter_targets.has(source.battle_id): return
	counter_targets[source.battle_id] = true
	unit.parry_pulse_used = true
	unit.battle.spawn_combat_wave(&"parry", unit.position, [unit.battle_id], 220, .7, 470, [unit.battle_id, source.battle_id])
	if source.alive and source.team != unit.team:
		var amount: float = CombatRules.js_round(clampf(CombatRules.attack(unit) * .65 + power * .1, 10, 30) * strength)
		unit.battle.damage_resolver.resolve(unit, source, amount, {"parry_recoil": true, "critical": false, "impulse": 0})
		if source.alive:
			StatusController.stun(source, 1.3)
			KnockbackController.apply(source, (source.position - unit.position).normalized() * 640, unit)
