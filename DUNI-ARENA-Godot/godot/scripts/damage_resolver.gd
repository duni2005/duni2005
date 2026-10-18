class_name DamageResolver
extends RefCounted
## Phase 7 common pipeline and explicit Phase 1–6 golden-comparison pipeline.
## General: crit/fatigue -> parry -> invincible/evade -> armor/reduction ->
## unique defense -> shield -> HP -> impact -> death/counter. Collision is separate.
## Rules emit outcomes/events; drawing belongs to the debug presentation.
## MIGRATION_NOTE: only additional armor reduces general damage; base defense
## contributes to parry strength. This preserves the web's current behavior.

signal damage_applied(source, target, amount: float, critical: bool)
signal damage_resolved(source, target, outcome: DamageOutcome)

const CRITICAL_MULTIPLIER: float = 1.5
var battle
var rng: RandomNumberGenerator

func _init(owner, random_source: RandomNumberGenerator) -> void:
	battle = owner
	rng = random_source

func apply(source, target, raw_damage: float) -> float:
	# Preserve the Phase 1 numeric API and existing signal's actual-HP-loss meaning.
	return resolve(source, target, raw_damage).hp_damage

func resolve(source, target, raw_damage: float, options: Dictionary = {}) -> DamageOutcome:
	if battle.common_combat_enabled: return resolve_common(source, target, raw_damage, options)
	return resolve_minimal(source, target, raw_damage)

func resolve_minimal(source, target, raw_damage: float) -> DamageOutcome:
	var outcome := DamageOutcome.new()
	if not battle.started or battle.finished or battle.clock.is_turning_paused() or not is_instance_valid(source) or not is_instance_valid(target):
		return outcome
	if not target.alive or source.team == target.team or not is_finite(raw_damage) or raw_damage <= 0.0:
		return outcome
	# Released arrows may hit after the shooter dies (same behavior as the web).
	outcome.accepted = true
	outcome.attempted_damage = raw_damage
	outcome.critical = rng.randf() < clampf(source.data.critical_chance+(source.ability.critical_bonus(source,target) if battle.full_characters_enabled else 0),0,1)
	outcome.resolved_damage = roundf(raw_damage * (CRITICAL_MULTIPLIER if outcome.critical else 1.0))
	outcome.shield_absorbed = StrategyEffects.absorb(target, outcome.resolved_damage)
	outcome.hp_damage = target.receive_damage(outcome.resolved_damage - outcome.shield_absorbed, source)
	if outcome.hp_damage > 0.0:
		damage_applied.emit(source, target, outcome.hp_damage, outcome.critical)
	damage_resolved.emit(source, target, outcome)
	return outcome

func complete(source, target, outcome: DamageOutcome) -> DamageOutcome:
	if outcome.hp_damage > 0: damage_applied.emit(source, target, outcome.hp_damage, outcome.critical)
	damage_resolved.emit(source, target, outcome)
	return outcome

func resolve_common(source, target, raw_damage: float, options: Dictionary) -> DamageOutcome:
	var out := DamageOutcome.new()
	var collision: bool = options.get("collision", false)
	if not battle.started or battle.finished or battle.clock.is_turning_paused() or not is_instance_valid(target) or not target.alive or not is_finite(raw_damage) or raw_damage <= 0: return out
	if not collision and (battle.run_end_requested or not is_instance_valid(source) or source.team == target.team): return out
	if battle.full_characters_enabled and CharacterLifecycle.protected(target):return out
	out.accepted = true
	out.attempted_damage = raw_damage
	var damage: float = raw_damage
	var recoil: bool = options.get("parry_recoil", false) or options.get("clash_recoil", false) or options.get("mirror_shard",false)
	var transcend: bool=options.get("transcendent",false)
	var duel_result: bool=options.get("duel_result",false)
	if not collision:
		out.critical = options.get("critical", true) and rng.randf() < clampf(source.data.critical_chance+(source.ability.critical_bonus(source,target) if battle.full_characters_enabled else 0),0,1)
		damage *= (CRITICAL_MULTIPLIER if out.critical else 1.0)*CombatRules.fatigue(source, &"damage")
	if battle.full_characters_enabled:
		if not collision and options.get("critical",true):damage*=CharacterCombat.champion_factor(source)
		if source!=null and not collision:
			damage*=.7 if source.cosmic_marked else 1
			if not options.get("mirror_shard",false):damage*=target.ability.incoming_factor(target,source,options)
			if not recoil and not options.get("mirror_raw",false) and not duel_result and source.state_value("paladinBlessingTime")>0:damage*=1.3
		var interception: Dictionary=target.ability.pre_damage(target,source,damage,options)
		if not interception.is_empty():out.reflected_damage=interception.get("reflected",0);return complete(source,target,out)
	var power: float = options.get("attack_power", damage)
	if not collision and not recoil and not transcend and target.parry.try_block(target, source, power, options.get("attack_token")):
		out.parried = true
		return complete(source, target, out)
	var reducing: bool = not recoil and not collision and target.stun_remaining <= 0 and target.parry_remaining > 0
	var origin: Vector2 = options.get("attack_origin", source.position if is_instance_valid(source) else target.position)
	var can_evade: bool = not collision and not recoil and not transcend and not duel_result and target.duel.is_empty() and target.stun_remaining <= 0 and CombatPerception.can_see_attack(target, source, origin, options.get("hidden_launch", false))
	if target.invincible_remaining > 0 or (target.evade_remaining > 0 and can_evade):
		out.invulnerable = target.invincible_remaining > 0
		out.avoided = not out.invulnerable
		return complete(source, target, out)
	var amount: float = CombatRules.js_round(damage * CombatRules.taken(target)*100/(100+CombatRules.armor(target))*(1 if collision else 1+maxf(0,battle.clock.elapsed-60)/70))
	if battle.full_characters_enabled:
		if options.get("mirror_shard",false):amount=CombatRules.js_round(damage*CombatRules.fatigue(target,&"taken"))
		elif duel_result:amount=CombatRules.js_round(damage*CombatRules.taken(target))
		else:
			amount=CombatRules.js_round(damage*CombatRules.taken(target)*target.ability.incoming_reduction(target)*100/(100+CombatRules.armor(target))*(1 if collision else 1+maxf(0,battle.clock.elapsed-60)/70))
			if not target.duel.is_empty() and source!=null and source.actor_id() not in [target.duel.master,target.duel.target]:amount=CombatRules.js_round(amount*(.2 if target.duel.master==target.actor_id() else .35))
	var impulse: float = options.get("impulse", source.data.attack_profile.impulse if is_instance_valid(source) else 0)
	var angle: float = options.get("angle", (target.position-source.position).angle() if is_instance_valid(source) else 0)
	if collision:
		# Collision has its own pipeline; perfect-window factor is deterministic.
		amount = CombatRules.js_round(damage*ParryController.factor(target)*CombatRules.taken(target)*100/(100+CombatRules.armor(target)))
	elif reducing:
		amount = CombatRules.js_round(amount*.4)
		impulse *= .4
		out.damage_reduced = true
	if battle.full_characters_enabled and not reducing and not recoil and not collision and not transcend and not duel_result and target.stun_remaining<=0:
		var unique: Dictionary=target.ability.unique_defense(target,source,amount,can_evade,options)
		if unique.get("avoid",false):out.avoided=true;return complete(source,target,out)
		if unique.has("amount"):amount=unique.amount;impulse*=float(unique.get("impulse_factor",1));out.damage_reduced=true
	if not reducing and can_evade and target.defense_cooldown <= 0:
		if target.stance == CombatStance.CAUTIOUS and rng.randf() < .1:
			target.defense_cooldown = 3
			DodgeController.start(target, source)
			out.avoided = true
			return complete(source, target, out)
		if target.data.type_id in ([1,3,5,7] if battle.full_characters_enabled else [1]) and rng.randf() < (.2 if target.data.type_id in [5,7] else .25)*(.5 if target.stance == CombatStance.RUSH else 1):
			target.defense_cooldown = 6 if target.data.type_id==3 else .8 if target.data.type_id==5 else 4
			DodgeController.start(target, source,&"healer" if target.data.type_id==5 else &"roll")
			out.avoided = true
			return complete(source, target, out)
	var warrior_defended: bool = not transcend and not duel_result and not collision and not recoil and not reducing and target.stun_remaining <= 0 and target.data.type_id == 0 and target.defense_cooldown <= 0 and target.parry_cooldown <= 0
	if warrior_defended:
		target.defense_cooldown = ParryReadiness.cooldown_duration(target)
		target.parry_cooldown = target.defense_cooldown
		target.facing = angle+PI
		var perfect: bool = rng.randf() < .2*ParryController.success_chance(target,power)
		target.parry.counter_targets.clear()
		target.parry_pulse_used = false
		target.parry.reprisal(target,source,power,1 if perfect else .75)
		amount = 0 if perfect else ceilf(amount*.5)
		impulse *= .05 if perfect else .3
		target.combat.cancel(target)
		out.parried = perfect
		out.damage_reduced = not perfect
		battle.emit_combat_event(&"warrior_parry",target.position,{"actor_id":target.battle_id,"perfect":perfect})
	var shares: Array[Dictionary]=[]
	var executed: bool=false
	if battle.full_characters_enabled:
		shares=CharacterCombat.plan_share(target,maxf(0,amount-target.shield_hp),source,options)
		for share in shares:
			if not share.get("extra",false):amount-=float(share.damage)
		var threshold: float=float(options.get("execute_threshold",0))
		executed=threshold>0 and amount>target.shield_hp and target.current_hp-maxf(0,amount-target.shield_hp)<=target.max_hp*threshold+1e-7
		if CharacterLifecycle.intercept_lethal(target,maxf(0,amount-target.shield_hp),executed):out.avoided=true;return complete(source,target,out)
	out.resolved_damage = amount
	out.shield_absorbed = StrategyEffects.absorb(target, amount)
	out.hp_damage = target.receive_damage(target.current_hp if executed else amount-out.shield_absorbed,source,true)
	if battle.full_characters_enabled:
		CharacterCombat.after_hit(source,target,out,options)
		if target.state_value("guardRemaining")>0:impulse=0
		target.knockback_collision_stun=options.get("collision_stun",0)
	# Shield absorption still creates impact. Invulnerability returned before shield.
	if not collision and target.alive and amount > 0:
		KnockbackController.apply(target, Vector2.from_angle(angle)*KnockbackController.attack_force(amount,impulse,source,target),source)
	target.announce_death(source)
	if battle.full_characters_enabled:
		CharacterCombat.apply_shares(target,shares)
		target.ability.after_damage(target,source,out.hp_damage,options)
	if warrior_defended and target.alive: target.combat.start_counter(target,source)
	if out.hp_damage > 0 or out.shield_absorbed > 0: battle.emit_combat_event(&"hit",target.position,{"actor_id":target.battle_id,"hp_damage":out.hp_damage,"shield":out.shield_absorbed})
	return complete(source,target,out)
