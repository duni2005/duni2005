extends CharacterAbility
## 굴절: at the start of battle swaps places with the farthest enemy. Fragile, slow, hard-hitting
## light shots. No ultimate (the data sets ultimate_windup < 0).
func tick(u,_dt: float) -> void:
	if u.state_value("refractOpened")>0 or not u.battle.started:return
	u.set_state("refractOpened",1)
	var farthest=null;var d: float=-1
	for e in u.enemies(false):
		if e.unavailable():continue
		var dist: float=u.position.distance_to(e.position)
		if dist>d:d=dist;farthest=e
	if farthest==null:return
	var from: Vector2=u.position
	u.position=farthest.position;farthest.position=from
	for v in [u,farthest]:v.velocity=Vector2.ZERO;v.knockback_velocity=Vector2.ZERO
	u.character_specific_state["refractFrom"]=CharacterPersistence.point(from)
	u.set_state("refractFx",.8)
func release_basic(u) -> void:
	shoot(u,u.combat.aim_angle,CombatRules.attack(u),{"kind":"light","speed":900,"radius":22,"impulse":300})
