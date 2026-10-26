class_name CharacterCombat
extends RefCounted
## Ordered extension hooks for abilities; DamageResolver remains the HP owner.
static func champion_factor(u) -> float:
	if u==null or not u.battle.full_characters_enabled:return 1
	var devotees: int=u.battle.units.filter(func(v):return v.alive and v.team==u.team and v.saint_actor==u.actor_id() and not v.character_specific_state.get("saintFallen",false)).size()
	return u.ability.attack_factor(u)*(1+devotees*.1)
## Damage passed on to linked units keeps the hit's kind; only the receiver's defense applies.
static func plan_share(u,hp_damage: float,source,options: Dictionary,kind: StringName=&"physical") -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if hp_damage>0 and u.state_value("magnetTime")>0 and u.state_value("magnetPull")<=0:
		var partner=u.battle.find_actor(str(u.character_specific_state.get("magnetPartner","")))
		var echo: int=CombatRules.js_round(hp_damage*BindingController.MAGNET_SHARE)
		if partner!=null and partner.alive and echo>0:result.append({"unit":partner,"damage":echo,"source":source,"extra":true,"kind":kind})
	if u.puppet_links.is_empty() or hp_damage<=0 or options.get("puppet_shared",false):return result
	var friends: Array=[]
	for id in u.puppet_links:
		var actor=u.battle.find_actor(id)
		if actor!=null and actor.alive and actor.team==u.team:friends.append(actor)
	if friends.is_empty():return result
	var total: int=int(minf(hp_damage,CombatRules.js_round(hp_damage*.3)))
	var each: int=total/friends.size();var remainder: int=total-each*friends.size()
	for i in range(friends.size()):result.append({"unit":friends[i],"damage":each+(1 if i<remainder else 0),"source":source,"kind":kind})
	return result
static func apply_shares(owner,shares: Array[Dictionary]) -> void:
	for s in shares:
		var target=s.unit
		if not target.alive or target.invincible_remaining>0 or CharacterLifecycle.protected(target):continue
		var amount: float=CombatRules.js_round(float(s.damage)*CombatRules.mitigation(target,s.kind))
		if CharacterLifecycle.intercept_lethal(target,maxf(0,amount-target.shield_hp)):continue
		var absorbed: float=StrategyEffects.absorb(target,amount)
		var actual: float=target.receive_damage(amount-absorbed,s.source,true)
		if actual>0:target.ability.on_damage(target,actual,{"puppet_shared":true})
		target.ultimate.charge(target,actual+absorbed,false)
		if s.source!=null and s.source.team!=target.team:s.source.damage_dealt+=actual;s.source.ultimate.charge(s.source,actual+absorbed,true)
		target.announce_death(s.source)
static func after_hit(source,target,out: DamageOutcome,options: Dictionary) -> void:
	var charge: float=out.hp_damage+out.shield_absorbed
	if source!=null and source.team!=target.team:
		source.damage_dealt+=out.hp_damage
		source.ultimate.charge(source,charge,true)
		if out.hp_damage>0:source.ability.dealt_damage(source,target,out.hp_damage,options)
	if out.hp_damage>0:
		target.last_damage_time=target.battle.clock.elapsed
		target.last_damage_actor=source.actor_id() if source!=null else ""
		target.set_state("revealTime",3)
		target.ability.on_damage(target,out.hp_damage,options)
	target.ultimate.charge(target,charge,false)
