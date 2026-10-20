class_name AttackVisuals
extends RefCounted
## Source-grounded geometry. All inputs are observed; never writes to combat objects.
const INKS=["ffd39c","e2f5ad","bca9ee","a9eee5","f3dd9e","c5f4e5","ffe6ba","f0ca83","efb1de","efa794","e5d3ae","c2faff","d3e7b5","ffbc75","dceff5","d0fff0","fff0bc","ffc1a0","ebe5ba","e9d7ff","8bdbff","b4e5e8","d5c2ff","eed18f","ffc4c3","f4c0dc","e8c48f","ffb08c","bdf0ff","ffe08a","ff9aa4","bfeaff"]
static func ink(type: int) -> Color:return Color(INKS[type])
static func body_visible(u: BattleUnit) -> bool:
	if not u.alive or u.frog_flight!=0:return false
	if u.frog_carrier.is_empty():return true
	var owner: BattleUnit=u.battle.find_actor(u.frog_carrier)
	return owner==null or owner.frog_action.get("phase","")!="hold"
static func tongue(canvas: CanvasItem,from: Vector2,to: Vector2,scale: float=1,rescue: bool=false) -> void:
	# Original frog.js: 14/15px dark tongue + 7px pink inner beam, source-to-tip.
	if from.distance_to(to)<1:return
	var color:=Color("e1ffad") if rescue else Color("ffc4c3")
	var middle: Vector2=(from+to)*.5;var length: float=from.distance_to(to);var angle: float=(to-from).angle()
	VisualShapes.streak(canvas,middle,angle,length,14*scale,Color("ad687d"),.9)
	VisualShapes.streak(canvas,middle,angle,length,7*scale,color,.95)
	canvas.draw_circle(to,8*scale,Color("ad687d"));canvas.draw_circle(to,5*scale,color)
	var dir: Vector2=(to-from).normalized()
	canvas.draw_arc(to,10*scale,dir.angle()-.9,dir.angle()+.9,12,Color("ffe2df"),2*scale,true)
static func frog_action(canvas: CanvasItem,u: BattleUnit) -> void:
	if u.frog_action.is_empty():return
	var a: Dictionary=u.frog_action;var victim: BattleUnit=u.battle.find_actor(String(a.target))
	if victim==null:return
	if a.phase!="hold":tongue(canvas,u.position,victim.position,u.combat_scale(),bool(a.rescue))
	else:
		var pulse: float=1+sin(float(a.get("hold",0))*12)*.05
		VisualShapes.slash(canvas,u.position,35*u.combat_scale()*pulse,u.facing-.7,u.facing+.7,Color("dcffa5") if a.rescue else Color("ffc4c3"),12,.9)
static func melee(canvas: CanvasItem,u: BattleUnit,a: AttackInstance) -> void:
	if a.metadata.has("grapple"):return # Grab is a hand/duel, never a sword sweep.
	var blade: Array[Vector2]=a.blade(u.position);var angle: float=(blade[1]-u.position).angle()
	var t: float=clampf(a.age/maxf(.001,a.duration),0,1);var scale: float=float(a.metadata.get("scale",u.combat_scale()));var c: Color=ink(u.data.type_id)
	if a.shape==&"path":
		var dir: Vector2=(a.end_position-a.start_position).normalized();var n:=dir.orthogonal()
		for i in [-1,0,1]:canvas.draw_line(a.start_position+n*i*10*scale,a.end_position+n*i*10*scale,Color(c,.4 if i else .9),2 if i else 5,true)
		return
	if a.metadata.get("shield_bash",false):
		var p: Vector2=(blade[0]+blade[1])*.5-Vector2.from_angle(a.angle)*35
		VisualShapes.slash(canvas,p,70*scale,a.angle-.9,a.angle+.9,c,32,.85)
		VisualShapes.slash(canvas,p,72*scale,a.angle-.75,a.angle+.75,Color("fff6d7"),10,.95);return
	if a.metadata.get("headbutt",false):VisualShapes.streak(canvas,blade[1],a.angle,80*scale,26*scale,c,.75);return
	if u.data.type_id in [9,17]:
		var finisher: bool=int(u.combat.attack_metadata.get("combo",0))==2 or a.metadata.get("finisher",false)
		VisualShapes.streak(canvas,(blade[0]+blade[1])*.5,a.angle,(100 if finisher else 65)*scale,(24 if finisher else 15)*scale,c,.85)
		VisualShapes.streak(canvas,blade[1],a.angle,35*scale,8*scale,Color("fff4de"));return
	if u.data.type_id==12:
		var p: Vector2=u.position+Vector2.from_angle(a.angle)*a.reach*.6
		VisualShapes.streak(canvas,p,a.angle+PI/2,a.reach*.85,20*scale,Color("fff2ca"),1-t)
		for side in [-1,1]:VisualShapes.streak(canvas,p+Vector2.from_angle(a.angle+side*.9)*a.reach*.2,a.angle+side*.9,55*scale,10*scale,c,(1-t)*.8)
		return
	var width: float=(66 if u.data.type_id==10 else 58 if u.data.type_id==14 and int(u.combat.attack_metadata.get("combo",0))==2 else 24 if u.data.type_id==3 else 36)*scale
	var reach: float=a.reach*.88
	# A broad bright cutting edge with faint trailing sheets reads as one fast swing.
	VfxArt.ribbon(canvas,u.position,reach,angle-1.75,angle,width*1.3,c,.35)
	VfxArt.glow(canvas,blade[1],28*scale,c,.28)
	VfxArt.ribbon(canvas,u.position,reach,angle-1.35,angle,width*1.2,c,.55)
	VfxArt.star(canvas,blade[1],8*scale,Color("fff4db"),.7,angle)
	VisualShapes.slash(canvas,u.position,reach,angle-1.18,angle,c,width,.92)
	VisualShapes.slash(canvas,u.position,reach-1,angle-.72,angle,Color("fff8ec"),width*.38)
	if u.data.type_id==3:VisualShapes.slash(canvas,u.position,reach*.65,angle-1.4,angle-.28,Color("b2ffdf"),10,.8)
static func projectile(canvas: CanvasItem,p: BattleProjectile,trail: Array,time: float,parent: Transform2D,origin: Vector2=Vector2.ZERO) -> void:
	var u: BattleUnit=p.source;var kind: String=p.kind if not p.kind.is_empty() else "magic" if u.data.type_id==2 else "light" if u.data.type_id==5 else "arrow"
	var scale: float=float(p.metadata.get("scale",u.combat_scale()));var dir: Vector2=p.velocity.normalized();var a: float=dir.angle();var at: Vector2=p.position
	var c: Color=ink(u.data.type_id)
	if kind=="frogTongue":
		tongue(canvas,u.position,at,scale);VfxArt.glow(canvas,at,18*scale,Color("ffb9d3"),.3);return
	if kind=="frogBody":
		var cargo: BattleUnit=u.battle.find_actor(String(p.metadata.get("cargo","")))
		if cargo==null:return
		for i in range(trail.size()):VisualShapes.streak(canvas,trail[i],a,30,9,Color("f6bdad"),float(i+1)/maxi(1,trail.size())*.35)
		canvas.draw_set_transform_matrix(parent*Transform2D(time*9,Vector2.ONE*scale,0,at))
		UnitIcon.draw(canvas,Rect2(-27,-27,54,54),cargo.data.type_id)
		canvas.draw_set_transform_matrix(parent)
		VisualShapes.streak(canvas,at-dir*32,a,68*scale,11*scale,Color("c2f58e") if p.metadata.get("rescue",false) else Color("f6bdad"),.8);return
	if kind=="bomb":
		var flight: float=float(p.metadata.get("flight",0));var max_flight: float=.7 if p.metadata.get("large",false) else .55
		var height: float=sin(clampf(1-flight/max_flight,0,1)*PI)*(95 if p.metadata.get("large",false) else 65)
		canvas.draw_circle(at+Vector2(0,5),13*scale,Color(0,0,0,.35))
		if flight<=0:
			var radius: float=p.metadata.get("blast_radius",120);var fuse: float=p.metadata.get("fuse",2)
			canvas.draw_circle(at,radius,Color("dd7645",.1));canvas.draw_arc(at,radius,0,TAU,64,Color("db9556",.65),2)
			canvas.draw_arc(at,radius,-PI/2,-PI/2+TAU*clampf(1-fuse/(2.5 if p.metadata.get("large",false) else 2),0,1),48,Color("ffcc8e"),4)
		at.y-=height;UnitIcon.draw(canvas,Rect2(at-Vector2.ONE*16.5*scale,Vector2.ONE*33*scale),13)
		VisualShapes.hit_glyph(canvas,at+Vector2(7,-16)*scale,time*4,10*scale,Color("ffd38b"),.2);return
	if kind=="lightning":
		var start: Vector2=origin
		VisualShapes.bolt(canvas,start,at,Color("8bdbff"),floor(time*30)+p.projectile_id,3*scale)
		VfxArt.glow(canvas,at,26*scale,Color("79cfff"),.6);VfxArt.star(canvas,at,12*scale,Color("e5fcff"),.9);return
	if kind in ["controlThread","sharpThread"]:
		var start: Vector2=trail[0] if not trail.is_empty() else at-dir*30
		canvas.draw_line(start,at,Color("db7698",.65),2*scale,true)
		VisualShapes.streak(canvas,at,a,28*scale,4*scale,Color("ff8fad") if kind=="controlThread" else c)
		if kind=="controlThread":canvas.draw_arc(at,12*scale,time*5,time*5+PI*1.6,18,Color("ff8fad"),2)
		return
	if kind in ["magic","light","star","mirrorLight","mirrorReflection"]:
		VfxArt.glow(canvas,at,25*scale,c,.4)
		for i in range(0,trail.size(),2):VfxArt.star(canvas,trail[i],3.5*scale,c,float(i+1)/maxi(1,trail.size())*.65,time+i)
	for i in range(1,trail.size()):
		var fade: float=float(i)/trail.size()
		canvas.draw_line(trail[i-1],trail[i],Color(c,fade*.38),maxf(1,(4 if kind in ["magic","light","mirrorLight","star"] else 2)*scale*fade),true)
	if kind in ["arrow","giantArrow"]:
		if p.bounces>0 or p.bounce_count>0:c=Color("e5ff9c")
		var length: float=80 if kind=="giantArrow" else 24
		var n:=dir.orthogonal();canvas.draw_line(at-dir*length,at+dir*7,c,3 if kind=="giantArrow" else 1.8,true)
		canvas.draw_colored_polygon(PackedVector2Array([at+dir*14,at-dir*2+n*6,at-dir*2-n*6]),Color("fff4d1"))
		for side in [-1,1]:canvas.draw_line(at-dir*length,at-dir*(length-10)+n*side*5,c,2)
		if kind=="giantArrow":
			VisualShapes.streak(canvas,at-dir*20,a,288*scale,29*scale,Color("c7e78c"),.45)
			VisualShapes.streak(canvas,at,a,216*scale,13*scale,Color("fff3c6"))
			var n2:=dir.orthogonal();canvas.draw_colored_polygon(PackedVector2Array([at+dir*83*scale,at+dir*26*scale-n2*30*scale,at+dir*38*scale,at+dir*26*scale+n2*30*scale]),Color("e4efac"))
	elif kind in ["sniper","machineBullet","pellet"]:
		VisualShapes.streak(canvas,at,a,170 if kind=="sniper" else 125 if kind=="machineBullet" else 24,9 if kind=="sniper" else 5,c,.8)
		VisualShapes.streak(canvas,at,a,35 if kind=="sniper" else 12,2,Color("fff4d1"))
	elif kind in ["tankShell","missile"]:
		canvas.draw_set_transform_matrix(parent*Transform2D(a,Vector2.ONE*scale,0,at))
		VfxArt.flare(canvas,Vector2(-20,0),0,32,Color("ffb561"),.65)
		VisualShapes.streak(canvas,Vector2(-22,0),0,55,9,Color("f5c991"),.7)
		canvas.draw_rect(Rect2(-12,-4,25,8),Color("bdd8dc") if kind=="missile" else Color("ebe5ba"))
		canvas.draw_rect(Rect2(6,-3,10,6),Color("f4fffc"))
		for side in [-1,1]:canvas.draw_rect(Rect2(-12,side*6-1,7,3),Color("567b81"))
		canvas.draw_set_transform_matrix(parent)
	elif kind=="swordWave":
		VfxArt.crescent(canvas,at,a,scale)
	elif kind=="greatImpact":
		VisualShapes.streak(canvas,at,a,150*scale,50*scale,c,.55);VisualShapes.streak(canvas,at,a,105*scale,22*scale,Color("fff2cd"),.9)
	elif kind in ["mirrorLight","mirrorReflection"]:
		VisualShapes.streak(canvas,at,a,45*scale,10*scale,Color("caffff"),.8)
		var n:=dir.orthogonal()*7*scale;canvas.draw_colored_polygon(PackedVector2Array([at+dir*15*scale,at+n,at-dir*9*scale,at-n]),Color("e9ffff"))
	elif kind=="iceShard":
		# Faceted ice crystal with a frosty glow.
		VfxArt.glow(canvas,at,18*scale,Color("9fdcff"),.45)
		var n:=dir.orthogonal()*5*scale
		canvas.draw_colored_polygon(PackedVector2Array([at+dir*14*scale,at+n,at-dir*10*scale,at-n]),Color("d8f4ff"))
		canvas.draw_line(at-dir*8*scale,at+dir*12*scale,Color("ffffff"),1.2,true)
	elif kind=="star":
		for i in range(4):VisualShapes.streak(canvas,at,time*2+i*PI/2,20*scale,4*scale,Color("f0e5ff"),.9)
	else:
		for i in range(3):canvas.draw_circle(at,(10-i*3)*scale,Color(c,.08+i*.12))
		VisualShapes.streak(canvas,at,a,30*scale,9*scale,c,.85)
		if kind=="light":ArenaIcon.draw(canvas,at,"heal",11*scale,Color("e8fff4"))
