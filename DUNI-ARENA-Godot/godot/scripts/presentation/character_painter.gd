class_name CharacterPainter
extends RefCounted
## Authored pixel avatars + offline-baked original Canvas weapons. Read-only pose adapter.
static var portraits: Dictionary={}
static var weapons: Dictionary={}
static func portrait(type: int) -> Texture2D:
	if not portraits.has(type):portraits[type]=load("res://assets/characters/portrait_%02d.svg"%type)
	return portraits[type]
static func weapon(type: int) -> Texture2D:
	if not weapons.has(type):weapons[type]=load("res://assets/weapons/weapon_%02d.png"%type)
	return weapons[type]
static func draw_portrait(canvas: CanvasItem,rect: Rect2,type: int,alpha: float=1) -> void:
	canvas.draw_texture_rect(portrait(type),rect,false,Color(1,1,1,alpha))
static func draw_battle_portrait(canvas: CanvasItem,rect: Rect2,type: int,alpha: float=1) -> void:
	# Original HTML type icon/rim, with the existing source-derived weapon pose.
	UnitIcon.draw(canvas,rect,type,alpha)
static func frame_for(u: BattleUnit) -> int:
	if not u.ultimate.cast.is_empty():return 1+clampi(int(float(u.ultimate.cast.t)/maxf(.01,float(u.ultimate.cast.duration))*4),0,3)
	if u.parry_remaining>.8:return 2
	if u.combat_state==CombatController.State.IDLE:return 0
	var profile: AttackData=u.combat.profile(u)
	var duration: float=profile.windup if u.combat_state==CombatController.State.WINDUP else profile.active if u.combat_state==CombatController.State.ACTIVE else profile.recovery
	return (1 if u.combat_state==CombatController.State.WINDUP else 5 if u.combat_state==CombatController.State.ACTIVE else 9)+clampi(int(u.combat.phase_time/maxf(.001,duration)*4),0,3)
static func draw_unit(canvas: CanvasItem,u: BattleUnit,parent: Transform2D,flash: float=0,pose_override: Dictionary={}) -> void:
	var scale: float=u.combat_scale();var at: Vector2=u.position;var sx: float=1;var sy: float=1;var shift: float=0
	var elapsed: float=u.battle.clock.elapsed
	if u.combat_state!=CombatController.State.IDLE:
		var p: AttackData=u.combat.profile(u)
		var phase: float=clampf(u.combat.phase_time/maxf(.001,p.windup if u.combat_state==CombatController.State.WINDUP else p.active if u.combat_state==CombatController.State.ACTIVE else p.recovery),0,1)
		shift=-phase*8 if u.combat_state==CombatController.State.WINDUP else sin(phase*PI)*14 if u.combat_state==CombatController.State.ACTIVE else 0
		sx=1-phase*.08 if u.combat_state==CombatController.State.WINDUP else 1+.1*sin(phase*PI);sy=2-sx
		if WeaponMotion.sword_attack(u):
			var charged: float=WeaponMotion.pose_progress(u)
			if u.combat_state==CombatController.State.WINDUP:shift=-13*charged;sx=1-.13*charged;sy=1+.12*charged
			elif u.combat_state==CombatController.State.ACTIVE:shift=sin(charged*PI)*22;sx=1+.16*sin(charged*PI);sy=2-sx
	if not u.ultimate.cast.is_empty() and u.data.type_id==0:
		var charge: float=clampf(float(u.ultimate.cast.t)/maxf(.001,float(u.ultimate.cast.duration)),0,1)
		shift=-13*charge;sx=1-.13*charge;sy=1+.12*charge
	if not pose_override.is_empty():shift=sin(float(pose_override.get("swing",0))*PI)*25
	var bob: float=sin(elapsed*17+u.battle_id)*1.5 if u.velocity.length()>8 else sin(elapsed*2+u.battle_id)*.35
	if u.stun_remaining>0:sx=.94;sy=.9;bob=1.5
	var lift: float=sin(PI*clampf(float(u.frog_hop.get("t",0))/maxf(.001,float(u.frog_hop.get("duration",1))),0,1))*30 if not u.frog_hop.is_empty() else 0
	if not u.frog_action.is_empty() and u.frog_action.get("phase","")=="hold":sx=1+sin(float(u.frog_action.get("hold",0))*12)*.05;sy=1
	var body: Vector2=at+Vector2.from_angle(u.facing)*shift*scale+Vector2(0,bob-lift)
	var alpha: float=.24 if u.hidden_from_enemies else .65 if u.evade_remaining>0 else 1
	canvas.draw_set_transform_matrix(parent*Transform2D(0,Vector2(scale,scale*.35),0,at+Vector2(0,24*scale)))
	canvas.draw_circle(Vector2.ZERO,25,Color(0,0,0,.3))
	canvas.draw_set_transform_matrix(parent)
	var portrait:=Rect2(body-Vector2(25*sx,25*sy)*scale,Vector2(50*sx,50*sy)*scale)
	draw_battle_portrait(canvas,portrait,u.data.type_id,alpha)
	# The rim shows the team, not the character's own colour.
	UnitIcon.draw_ring(canvas,portrait,u.team_color(),alpha)
	if flash>0:
		# Small bright bands follow the actual body rather than covering it with a circle.
		for i in range(4):canvas.draw_rect(Rect2(body+Vector2(-18,-20+i*10)*scale,Vector2(36,2)*scale),Color(1,1,.93,flash*.55))
	if u.data.type_id!=10 or u.lost_sword.is_empty():
		var pose: Dictionary=pose_override if not pose_override.is_empty() else WeaponMotion.pose(u)
		canvas.draw_set_transform_matrix(parent*Transform2D(float(pose.angle),Vector2.ONE*scale*float(pose.get("weapon_scale",1)),0,at))
		WeaponMotion.draw(canvas,pose,alpha)
		canvas.draw_set_transform_matrix(parent)
	# Team status is separate from character identity; a controlled enemy keeps its portrait.
	canvas.draw_arc(at+Vector2(0,24*scale),22*scale,.12,PI-.12,20,u.team_color(),3)
	var marker: Vector2=at+Vector2(0,29*scale);var sign: int=1 if u.team==0 else -1
	canvas.draw_colored_polygon(PackedVector2Array([marker+Vector2(0,-4*sign),marker+Vector2(-3,2*sign),marker+Vector2(3,2*sign)]),u.team_color())
	if u.stun_remaining>0:
		for i in range(3):
			var a: float=elapsed*4+i*TAU/3;var p:=at+Vector2(cos(a)*18,-35+sin(a)*4)*scale
			canvas.draw_rect(Rect2(p-Vector2.ONE*2,Vector2.ONE*4),Color("ffe39d"))

static func draw_static(canvas: CanvasItem,at: Vector2,type: int,facing: float,parent: Transform2D) -> void:
	canvas.draw_set_transform_matrix(parent*Transform2D(0,Vector2(1,.35),0,at+Vector2(0,24)))
	canvas.draw_circle(Vector2.ZERO,25,Color(0,0,0,.28));canvas.draw_set_transform_matrix(parent)
	draw_portrait(canvas,Rect2(at-Vector2(32,33),Vector2(64,64)),type)
	canvas.draw_set_transform_matrix(parent*Transform2D(facing,at))
	WeaponMotion.draw(canvas,{"key":"%d:basic"%type,"index":0})
	canvas.draw_set_transform_matrix(parent)

static func capture_unit(u: BattleUnit) -> Dictionary:
	# Only primitive pose values. Never retain a Unit, target, ability or Resource.
	var velocity: Vector2=u.velocity+u.knockback_velocity
	if not velocity.is_finite():velocity=Vector2.ZERO
	return {"position":u.position,"velocity":velocity.limit_length(220),"scale":u.combat_scale(),"type":u.data.type_id,"facing":u.facing,"frame":frame_for(u),"motion":WeaponMotion.pose(u),"weapon_visible":u.data.type_id!=10 or u.lost_sword.is_empty(),"color":u.team_color(),"hp":u.current_hp,"max_hp":u.max_hp,"shield":u.shield_hp,"hidden":u.hidden_from_enemies,"id":u.battle_id}

static func draw_snapshot(canvas: CanvasItem,row: Dictionary,at: Vector2,parent: Transform2D,time: float) -> void:
	var scale: float=row.scale;var color: Color=row.color
	var bob: float=sin(time*15+row.id)*minf(1.5,row.velocity.length()*.01)*(1-clampf(time/.74,0,1))
	canvas.draw_set_transform_matrix(parent*Transform2D(0,Vector2(scale,scale*.35),0,at+Vector2(0,24*scale)))
	canvas.draw_circle(Vector2.ZERO,25,Color(0,0,0,.3));canvas.draw_set_transform_matrix(parent)
	draw_battle_portrait(canvas,Rect2(at+Vector2(-25,-25+bob)*scale,Vector2.ONE*50*scale),row.type,.3 if row.hidden else 1)
	var pose: Dictionary=row.get("motion",{"key":"%d:basic"%row.type,"index":0,"angle":row.facing})
	canvas.draw_set_transform_matrix(parent*Transform2D(float(pose.angle),Vector2.ONE*scale*float(pose.get("weapon_scale",1)),0,at))
	if row.weapon_visible:WeaponMotion.draw(canvas,pose)
	canvas.draw_set_transform_matrix(parent)
	canvas.draw_arc(at+Vector2(0,24*scale),22*scale,.12,PI-.12,20,color,3)
	if row.shield>0:VisualShapes.barrier(canvas,at,25*scale+9,Color("7ddfff"),time)
	canvas.draw_rect(Rect2(at+Vector2(-25,-25*scale-13),Vector2(50,5)),Color("32455c"))
	canvas.draw_rect(Rect2(at+Vector2(-25,-25*scale-13),Vector2(50*clampf(row.hp/maxf(1,row.max_hp),0,1),5)),color)
