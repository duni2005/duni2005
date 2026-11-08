extends CharacterAbility
func can_attack(u,_t) -> bool:return u.lost_sword.is_empty()
func profile(u) -> AttackData:
	var p: AttackData=super.profile(u);var boost: float=1+u.state_value("guardStacks")*.06;p.reach*=boost;return p
func on_attack_start(u) -> void:u.combat.attack_metadata.boost=1+u.state_value("guardStacks")*.06;u.set_state("guardStacks",0)
func movement_rate(u) -> float:return 1+u.state_value("guardStacks")*.15
func on_damage(u,_actual: float,options: Dictionary) -> void:
	if not u.alive or u.stun_remaining>0 or options.get("parry_recoil",false) or options.get("clash_recoil",false) or options.get("mirror_shard",false):return
	if u.state_value("guardRemaining")>0:u.set_state("guardStacks",u.state_value("guardStacks")+1)
	elif u.character_specific_state.get("guardReady",true):
		u.set_state("guardRemaining",4);u.set_state("guardReady",false);u.set_state("guardStacks",u.state_value("guardStacks")+1);u.guard_anchor=u.position;u.combat.cancel(u);u.ultimate.cast.clear();u.knockback_velocity=Vector2.ZERO
## The dropped greatsword flies, lands and is picked up like any 놓침 weapon (WeaponDrop).
func release_basic(u) -> void:
	u.set_state("guardReady",true)
	if u.battle.rng.randf()<.15:
		var angle: float=u.battle.rng.randf_range(-PI,PI);var dir: Vector2=Vector2.from_angle(angle)*480
		u.lost_sword={"point":CharacterPersistence.point(u.position),"vx":dir.x,"vy":dir.y,"flight":.6,"rotation":angle,"sizeBoost":u.combat.attack_metadata.get("boost",1),"scale":u.combat_scale()};return
	melee(u,UnitStatTable.raw(u,&"basic")*float(u.combat.attack_metadata.get("boost",1)),{"dmg":&"basic"});u.knockback_velocity+=Vector2.from_angle(u.combat.aim_angle)*140
func can_ultimate(u,t) -> bool:return t!=null and u.lost_sword.is_empty() and (u.position.distance_to(t.position)<430 or u.state_value("ultReadyAge")>4)
func release_ultimate(u,a,_dt: float) -> bool:
	u.combat.aim_angle=a.angle;melee(u,UnitStatTable.raw(u,&"ult_slash"),{"dmg":&"ult_slash","reach":190,"cone":.7,"active":.25,"impulse":500,"independent":true})
	shoot(u,a.angle,UnitStatTable.raw(u,&"ult_wave"),{"dmg":&"ult_wave","kind":"greatImpact","speed":640,"radius":48,"life":1.5,"offset":48,"piercing":true,"ultimate":true,"impulse":540});return true
func can_cast(u) -> bool:return u.lost_sword.is_empty()
func debug_state(u) -> String:return " / ".join(["guardStacks", "guardRemaining"].map(func(k):return k+":"+str(u.character_specific_state.get(k,0))))
