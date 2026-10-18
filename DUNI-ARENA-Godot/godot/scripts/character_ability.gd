class_name CharacterAbility
extends RefCounted
## Character policy hooks; shared damage/physics/parry stay in their controllers.
func on_spawn(_u) -> void:pass
func tick(_u,_dt: float) -> void:pass
func on_damage(_u,_actual: float,_options: Dictionary) -> void:pass
func on_kill(_u,_victim) -> void:pass
func on_death(_u) -> void:pass
func choose_target(u,enemies: Array):
	var seen: Array=enemies.duplicate()
	enemies.sort_custom(func(a,b):return target_priority(u,a,seen)<target_priority(u,b,seen) if target_priority(u,a,seen)!=target_priority(u,b,seen) else u.position.distance_to(a.position)<u.position.distance_to(b.position))
	return enemies[0] if not enemies.is_empty() else null
func target_priority(_u,_enemy,_seen: Array) -> float:return 0
func support_anchor(u):
	var friends: Array=u.friends()
	friends.sort_custom(func(a,b):return a.current_hp<b.current_hp if a.current_hp!=b.current_hp else u.position.distance_to(a.position)<u.position.distance_to(b.position))
	return friends[0] if not friends.is_empty() else null
func modify_movement(_u,_target,_dt: float) -> bool:return false
func steer_override(_u,_direction: Vector2,_dt: float,_factor: float) -> bool:return false
func can_attack(_u,_target) -> bool:return true
func locked(u) -> bool:return u.unavailable() or u.state_value("guardRemaining")>0 or not u.duel.is_empty() or not u.frog_action.is_empty() or not u.hero_rescue.is_empty() or not u.machine_dash.is_empty()
func profile(u) -> AttackData:return u.data.attack_profile.duplicate()
func attack_factor(_u) -> float:return 1
func movement_rate(_u) -> float:return 1
func attack_rate(_u) -> float:return 1
func critical_bonus(_u,_target) -> float:return 0
func can_ultimate(u,target) -> bool:return target!=null
func ultimate_target(u):return u.target if is_instance_valid(u.target) and u.target.alive else nearest(u,u.enemies())
func release_basic(u) -> void:
	var p: AttackData=u.combat.profile(u)
	if p.kind==AttackData.Kind.MELEE:
		u.battle.spawn_melee_strike(u,p,CombatRules.attack(u)*(1.25 if u.combat.counter else 1))
		u.knockback_velocity+=Vector2.from_angle(u.combat.aim_angle)*90
	else:shoot(u,u.combat.aim_angle,CombatRules.attack(u))
func attack_tick(_u,_dt: float) -> bool:return false
func release_ultimate(_u,_cast: Dictionary,_dt: float) -> bool:return true
func projectile_hit(_u,_p,_target) -> bool:return false
func melee_hit(_u,_attack,_target,_outcome) -> void:pass
func pre_damage(_u,_source,_damage: float,_options: Dictionary) -> Dictionary:return {}
static func nearest(u,list: Array):
	var sorted: Array=list.duplicate();sorted.sort_custom(func(a,b):return u.position.distance_to(a.position)<u.position.distance_to(b.position));return sorted[0] if not sorted.is_empty() else null
static func restore_hp(target, base: float, source=null) -> float:
	if target==null or not target.alive or base<=0:return 0
	var gain: float=minf(target.max_hp-target.current_hp,base*(source.healing_power if source!=null else 1)*target.healing_power)
	target.current_hp+=gain;return gain
static func shoot(u,angle: float,damage: float,settings: Dictionary={}) -> BattleProjectile:
	var p:=u.battle.PROJECTILE_SCENE.instantiate() as BattleProjectile
	p.initialize(u,angle)
	var scale: float=u.combat_scale()
	p.kind=settings.get("kind","")
	p.position=u.position+Vector2.from_angle(angle)*float(settings.get("offset",32))*scale
	p.previous_position=p.position
	p.velocity=Vector2.from_angle(angle)*float(settings.get("speed",u.data.attack_profile.projectile_speed))
	p.damage=damage;p.power=settings.get("power",damage)
	p.hit_radius=float(settings.get("radius",26))*scale
	p.lifetime=settings.get("life",2.4)
	p.piercing=settings.get("piercing",false);p.bounces=settings.get("bounces",0)
	p.metadata=settings.duplicate(true);p.metadata["scale"]=settings.get("visual_scale",scale)
	if u.battle.ultimate_actor==u:p.metadata["ultimate"]=true
	u.battle.physical_serial+=1;p.projectile_id=u.battle.physical_serial
	var a:=AttackInstance.new();a.attack_id=p.projectile_id;a.source_battle_id=u.battle_id;a.team=u.team
	a.attack_type=&"projectile";a.shape=&"circle";a.position=p.position;a.start_position=p.position;a.velocity=p.velocity;a.damage=damage;a.power=p.power
	a.radius=p.hit_radius
	a.clash_radius=(float(settings.get("radius",26))*.75 if settings.get("ultimate",false) else {"bomb":22 if settings.get("large",false) else 12,"lightning":8,"missile":10 if settings.get("enhanced",false) else 6,"machineBullet":5,"sniper":7,"pellet":5}.get(p.kind,u.data.attack_profile.projectile_clash_radius))*float(settings.get("visual_scale",scale))
	a.impulse=settings.get("impulse",u.data.attack_profile.impulse);a.life=p.lifetime;a.hidden_launch=u.combat.hidden_launch if u.combat_state!=CombatController.State.IDLE else CombatPerception.concealed(u)
	a.metadata=p.metadata.duplicate(true);a.metadata.kind=p.kind
	p.attack_instance=a;u.battle.projectiles.append(p);u.battle.add_child(p)
	return p
static func melee(u,damage: float,overrides: Dictionary={}) -> AttackInstance:
	var profile: AttackData=u.combat.profile(u).duplicate()
	for key in overrides:
		if key in ["reach","cone","active","impulse"]:profile.set(key,overrides[key])
	var strike: AttackInstance=u.battle.spawn_melee_strike(u,profile,damage)
	if strike!=null:
		strike.metadata=overrides.duplicate(true);strike.metadata.scale=u.combat_scale()
		if u.battle.ultimate_actor==u:strike.metadata["ultimate"]=true
	return strike
static func area_damage(u,point: Vector2,radius: float,damage: float,impulse: float,options: Dictionary={}) -> void:
	for enemy in u.enemies(false):
		if enemy.unavailable() or point.distance_to(enemy.position)>radius+24*enemy.combat_scale():continue
		var opts: Dictionary=options.duplicate();opts.merge({"attack_origin":point,"visible_hazard":true,"angle":(enemy.position-point).angle(),"impulse":impulse},true)
		u.battle.damage_resolver.resolve(u,enemy,damage,opts)
static func dash_to(u,point: Vector2,speed: float,dt: float,stop: float=0) -> bool:
	var before: Vector2=u.position
	var d: float=u.position.distance_to(point)
	u.position=MovementController.clamp_position(before+(point-before).normalized()*minf(maxf(0,d-stop),speed*dt))
	u.velocity=(u.position-before)/maxf(.000001,dt);u.knockback_velocity=Vector2.ZERO
	return u.position.distance_to(point)<=stop+2
func unique_defense(_u,_source,_amount: float,_can_evade: bool,_options: Dictionary) -> Dictionary:return {}
func incoming_factor(_u,_source,_options) -> float:return 1
func defense_aura(_u,_target) -> float:return 0
func defense_factor(_u) -> float:return 1
func on_attack_start(_u) -> void:pass
func after_recovery(_u) -> void:pass
func passive_tick(_u,_dt: float) -> void:pass
func after_damage(_u,_source,_actual: float,_options: Dictionary) -> void:pass
func projectile_tick(_u,_dt: float) -> void:pass
func dealt_damage(_u,_target,_actual: float,_options: Dictionary) -> void:pass
func incoming_reduction(_u) -> float:return 1

func ultimate_danger(u,observer,a: Dictionary) -> bool:
	var relative: Vector2=observer.position-u.position
	return relative.length()<maxf(u.data.attack_range,300)*u.combat_scale()+90 and (a.get("target","")==observer.actor_id() or absf(wrapf(relative.angle()-float(a.angle),-PI,PI))<1.05)
func impact_delay_extra(u,observer,ultimate: bool) -> float:
	var d: float=observer.position.distance_to(u.position)
	if u.data.type_id==20 and not ultimate:return d/760
	if u.data.type_id==18:return d/620
	if u.data.type_id==17 and ultimate:return maxf(0,d-95)/900+.25
	if u.data.type_id==15:return d/430
	if u.data.type_id==13:return 2.5 if ultimate else 2
	if u.data.type_id==8:return maxf(0,d-50)/320
	if u.data.type_id==11:return maxf(0,d-50)/560
	if not ultimate and u.data.attack_range>100:return d/(4200 if u.data.type_id==23 else 4700 if u.data.type_id==6 else 720 if u.data.type_id==7 else 470 if u.data.type_id==1 else 340)
	if ultimate and u.data.type_id in [0,1,10]:return maxf(0,d-90)/1050
	return 0

func windup_track_fraction(_u) -> float:return .65
func track_aim(u,desired: float,dt: float) -> float:return lerp_angle(u.combat.aim_angle,desired,minf(1,dt*5))

func attack_cooldown(u,rng: RandomNumberGenerator) -> float:
	var p: AttackData=u.combat.profile(u)
	return p.windup+p.active+p.recovery+u.data.attack_interval*rng.randf_range(.3,.55)
func cast_area(_u,_a: Dictionary) -> Dictionary:return {}

func can_cast(_u) -> bool:return true
func defensive_ultimate() -> bool:return false
func ultimate_point(_u,point: Vector2) -> Vector2:return point.clamp(Vector2(28,28),Vector2(772,772))
func requires_initiative() -> bool:return true
func debug_state(_u) -> String:return ""
func reactive_ultimate() -> bool:return false
