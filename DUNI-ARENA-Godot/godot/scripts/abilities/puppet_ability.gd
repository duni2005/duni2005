extends CharacterAbility
func on_spawn(u) -> void:
	var friends: Array=u.friends();friends.sort_custom(func(a,b):return u.position.distance_to(a.position)<u.position.distance_to(b.position));u.puppet_links.assign(friends.slice(0,2).map(func(a):return a.actor_id()))
func thread(u,angle: float,control: bool=false) -> void:
	shoot(u,angle,0 if control else CombatRules.attack(u),{"kind":"controlThread" if control else "sharpThread","speed":540 if control else 660,"radius":25 if control else 18,"offset":35,"life":1.5 if control else 1.2,"power":CombatRules.attack(u)*3.5 if control else CombatRules.attack(u),"impulse":145});u.set_state("shotsFired",u.state_value("shotsFired")+1)
func release_basic(u) -> void:
	for off in [-.16,0,.16]:thread(u,u.combat.aim_angle+off)
	u.knockback_velocity-=Vector2.from_angle(u.combat.aim_angle)*35
func can_ultimate(u,t) -> bool:return t!=null and u.position.distance_to(t.position)<530 and t.puppet_control.is_empty()
func release_ultimate(u,a,_dt: float) -> bool:thread(u,a.angle,true);return true
func projectile_hit(u,p,t) -> bool:
	if p.kind!="controlThread":return false
	p.live=false
	if t.invincible_remaining>0 or t.frog_rescue_guard or t.unavailable() or t.team==u.team:return true
	var reflected: Dictionary=t.ability.pre_damage(t,u,p.power,p.attack_instance.options(p.position))
	if not reflected.is_empty() or t.parry.try_block(t,u,p.power,p.projectile_id):return true
	if t.evade_remaining>0 and CombatPerception.can_see_attack(t,u,p.position,p.hidden_launch):return true
	CharacterLifecycle.control(t,u);return true
func debug_state(u) -> String:return "Links %d / control %.1f" % [u.puppet_links.size(),float(u.puppet_control.get("remaining",0))]
