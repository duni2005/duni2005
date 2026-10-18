extends CharacterAbility
## 배달부: does not fight. A parcel lands somewhere on the map (one per courier). The courier
## walks to it, picks it up and carries it to a random fighting ally, granting one of: heal,
## damage up, ultimate charge or a shield. Taking damage while carrying has a 25% chance to
## knock the parcel far away. Ultimate: pull a dropped parcel in, or throw a held one at once.
## The courier dies when no fighting ally is left.
const RESPAWN: float = 6
const DROP_CHANCE: float = .25
const PICKUP_RANGE: float = 26
const DELIVER_RANGE: float = 54
const BUFFS: Array = ["heal","power","charge","shield"]
func can_attack(_u,_t) -> bool:return false
func fighters(u) -> Array:return u.friends().filter(func(f):return f.alive and f.data.type_id!=29)
func parcel(u) -> Dictionary:return u.character_specific_state.get("parcel",{})
func tick(u,dt: float) -> void:
	if not u.battle.started or u.battle.finished:return
	if fighters(u).is_empty():
		u.receive_damage(u.current_hp+1,u);return
	var p: Dictionary=parcel(u)
	if p.is_empty():
		var wait: float=u.state_value("parcelRespawn")-dt;u.set_state("parcelRespawn",wait)
		if wait<=0:_spawn(u)
	elif p.get("held",false):
		var to=u.battle.find_actor(p.get("to",""))
		if to==null or not to.alive:p["to"]=_pick_recipient(u)
func _spawn(u) -> void:
	var rng: RandomNumberGenerator=u.battle.rng
	u.character_specific_state["parcel"]={"x":rng.randf_range(120,680),"y":rng.randf_range(120,680),"held":false,"to":""}
func _pick_recipient(u) -> String:
	var list: Array=fighters(u)
	return list[u.battle.rng.randi_range(0,list.size()-1)].actor_id() if not list.is_empty() else ""
func modify_movement(u,_t,dt: float) -> bool:
	var p: Dictionary=parcel(u)
	if p.is_empty():
		# Between parcels: stay behind the nearest fighting ally.
		var ally=nearest(u,fighters(u))
		u.brain.steer(u,((ally.position if ally!=null else u.position)-u.position).normalized() if ally!=null and ally.position.distance_to(u.position)>90 else Vector2.ZERO,dt,1);return true
	if not p.get("held",false):
		var spot:=Vector2(float(p.x),float(p.y))
		if u.position.distance_to(spot)<=PICKUP_RANGE*u.combat_scale():p["held"]=true;p["to"]=_pick_recipient(u)
		u.brain.steer(u,(spot-u.position).normalized(),dt,1.1);return true
	var to=u.battle.find_actor(p.get("to",""))
	if to==null:u.brain.steer(u,Vector2.ZERO,dt,1);return true
	if u.position.distance_to(to.position)<=DELIVER_RANGE*u.combat_scale():_deliver(u,to);return true
	u.brain.steer(u,(to.position-u.position).normalized(),dt,1.1);return true
func _deliver(u,to) -> void:
	var kind: String=BUFFS[u.battle.rng.randi_range(0,BUFFS.size()-1)]
	match kind:
		"heal":restore_hp(to,to.max_hp*.3,u)
		"power":to.strategy_special_until=maxf(to.strategy_special_until,u.battle.clock.elapsed+8)
		"charge":to.ultimate.gain(to,45)
		"shield":to.shield_hp=maxf(to.shield_hp,to.max_hp*.25);to.shield_remaining=maxf(to.shield_remaining,8)
	to.set_state("deliveryFx",1.2);to.character_specific_state["deliveryKind"]=kind
	u.character_specific_state.erase("parcel");u.set_state("parcelRespawn",RESPAWN)
func after_damage(u,_source,actual: float,_options: Dictionary) -> void:
	var p: Dictionary=parcel(u)
	if actual<=0 or p.is_empty() or not p.get("held",false) or u.battle.rng.randf()>=DROP_CHANCE:return
	var away: Vector2=MovementController.clamp_position(u.position+Vector2.from_angle(u.battle.rng.randf_range(-PI,PI))*u.battle.rng.randf_range(200,320))
	p["held"]=false;p["to"]="";p["x"]=away.x;p["y"]=away.y
func can_ultimate(u,_t) -> bool:
	var p: Dictionary=parcel(u)
	return not p.is_empty() and (p.get("held",false) or u.position.distance_to(Vector2(float(p.x),float(p.y)))>160) and not fighters(u).is_empty()
func ultimate_target(u):return nearest(u,fighters(u))
func release_ultimate(u,_a,_dt: float) -> bool:
	var p: Dictionary=parcel(u)
	if p.is_empty():return true
	if p.get("held",false):
		var to=u.battle.find_actor(p.get("to",""))
		if to==null or not to.alive:to=u.battle.find_actor(_pick_recipient(u))
		if to!=null:_deliver(u,to)
	else:p["held"]=true;p["to"]=_pick_recipient(u)
	return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func defensive_ultimate() -> bool:return true
func requires_initiative() -> bool:return false
