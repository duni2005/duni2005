class_name ProjectileRules
extends RefCounted
## Character projectile metadata on top of the existing swept collision engine.
static func find(battle,attack_id: int) -> BattleProjectile:
	for p in battle.projectiles:
		if p.projectile_id==attack_id:return p
	return null
static func explode(p) -> void:
	if p.metadata.get("detonated",false):return
	p.metadata.detonated=true
	var point: Vector2=p.position
	var radius: float=p.metadata.get("blast_radius",120)
	for enemy in p.source.enemies(false):
		if enemy.unavailable() or point.distance_to(enemy.position)>radius+24*enemy.combat_scale():continue
		var falloff: float=1-.35*clampf(point.distance_to(enemy.position)/radius,0,1) if p.kind=="tankShell" else 1
		p.source.battle.damage_resolver.resolve(p.source,enemy,p.damage*falloff,{"dmg":p.metadata.get("dmg",&"basic"),"critical":true,"impulse":p.attack_instance.impulse,"angle":(enemy.position-point).angle(),"attack_origin":point,"visible_hazard":true,"hidden_launch":p.hidden_launch,"attack_token":p.projectile_id})
	if p.kind=="tankShell" and p.metadata.get("enhanced",false):p.source.battle.zones.add(p.source,"tankFire",point,150*float(p.metadata.get("scale",1)),5,{"damage":UnitStatTable.raw(p.source,&"fire_zone")})
	p.live=false;p.attack_instance.life=0
static func prepare(p,dt: float) -> void:
	if p.kind=="missile" and float(p.metadata.get("guide",0))>0:
		var t=p.source.battle.find_actor(p.metadata.get("target",""))
		if t!=null and t.alive and CombatPerception.can_perceive(p.source,t):
			var turn: float=clampf(wrapf((t.position-p.position).angle()-p.velocity.angle(),-PI,PI),-1.7*minf(dt,p.metadata.guide),1.7*minf(dt,p.metadata.guide))
			p.velocity=p.velocity.rotated(turn)
		p.metadata.guide=maxf(0,float(p.metadata.guide)-dt)
static func boundary(p) -> bool:
	var tx: bool=(p.position.x<=20.00001 and p.velocity.x<0) or (p.position.x>=779.99999 and p.velocity.x>0)
	var ty: bool=(p.position.y<=20.00001 and p.velocity.y<0) or (p.position.y>=779.99999 and p.velocity.y>0)
	if not tx and not ty:return true
	if p.kind=="frogBody":CharacterLifecycle.finish_body(p);return false
	if p.kind=="tankShell":explode(p);return false
	if p.kind=="bomb":p.position=p.position.clamp(Vector2(20.001,20.001),Vector2(779.999,779.999));p.velocity=Vector2.ZERO;p.metadata.flight=0;return true
	if p.bounces>0:
		p.bounces-=1;p.bounce_count+=1
		if tx:p.velocity.x*=-1
		if ty:p.velocity.y*=-1
		p.position=p.position.clamp(Vector2(20.001,20.001),Vector2(779.999,779.999))
		if p.kind=="mirrorLight":p.damage*=1.2;p.power=p.damage
		p.attack_instance.damage=p.damage;p.attack_instance.power=p.power;p.attack_instance.velocity=p.velocity
		return true
	p.live=false;p.attack_instance.life=0;return false
static func finish(p) -> void:
	if p.kind=="frogBody":CharacterLifecycle.finish_body(p)
static func hit(p,target) -> DamageOutcome:
	var out:=DamageOutcome.new()
	if p.kind=="openingAwl":
		p.live=false;p.attack_instance.life=0
		if not target.alive or target.invincible_remaining>0:return out
		var intercept: Dictionary=target.ability.pre_damage(target,p.source,p.power,{"angle":0,"attack_token":p.projectile_id,"impulse":0})
		if not intercept.is_empty():return out
		if target.parry.try_block(target,p.source,p.power,p.projectile_id):out.parried=true;return out
		StatusController.stun(target,4*EquipmentCombatEffects.awl_strength(p.source));return out
	if p.source.ability.projectile_hit(p.source,p,target):
		if not p.live:p.attack_instance.life=0
		return out
	var options: Dictionary=p.attack_instance.options(target.position-p.velocity*(.008 if p.kind=="sniper" else .08));options["melee"]=false
	out=p.source.battle.damage_resolver.resolve(p.source,target,p.damage,options)
	if not p.piercing:p.live=false;p.attack_instance.life=0
	return out
