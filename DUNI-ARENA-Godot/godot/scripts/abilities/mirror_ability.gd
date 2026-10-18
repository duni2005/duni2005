extends CharacterAbility
func release_basic(u) -> void:shoot(u,u.combat.aim_angle,CombatRules.attack(u),{"kind":"mirrorLight","speed":620,"radius":18,"offset":36,"life":10,"bounces":4,"impulse":145});u.knockback_velocity-=Vector2.from_angle(u.combat.aim_angle)*40
func pre_damage(u,source,damage: float,_options: Dictionary) -> Dictionary:
	if u.state_value("mirrorReflectTime")<=0:return {}
	if source!=null and source!=u and source.team!=u.team and damage>0:shoot(u,(source.position-u.position).angle(),damage,{"kind":"mirrorReflection","speed":620,"radius":18,"offset":36,"life":2.5,"impulse":145})
	return {"blocked":true,"reflected":damage}
func projectile_hit(u,p,t) -> bool:
	if p.kind!="mirrorReflection":return false
	u.battle.damage_resolver.resolve(u,t,p.damage,{"mirror_raw":true,"critical":false,"impulse":145,"attack_origin":t.position-p.velocity*.08,"attack_token":p.projectile_id});p.live=false;return true
func after_damage(u,source,actual: float,options: Dictionary) -> void:
	if options.get("mirror_shard",false) or actual<=0 or source==null or not source.alive or source.team==u.team:return
	var amount: float=CombatRules.js_round(actual*.1)
	if amount>0:u.battle.damage_resolver.resolve(u,source,amount,{"mirror_shard":true,"mirror_raw":true,"critical":false,"impulse":0})
func can_ultimate(u,t) -> bool:return t!=null and u.state_value("mirrorReflectTime")<=0 and (not u.threat_response.projectile_threat(u).is_empty() or u.enemies().any(func(e):return e.combat_state==CombatController.State.WINDUP and e.combat.attack_target==u) or u.current_hp/u.max_hp<.55 and u.position.distance_to(t.position)<260 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,_a,_dt: float) -> bool:u.set_state("mirrorReflectTime",3);return true
func defensive_ultimate() -> bool:return true
func debug_state(u) -> String:return " / ".join(["mirrorReflectTime"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
