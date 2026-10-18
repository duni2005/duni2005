class_name CombatPresentation
extends Control
## Read-only replacement renderer. Domain Nodes are hidden, never paused/rewritten.
const MAX_EFFECTS=96
const MAX_NUMBERS=40
const ZONE_COLORS={"blackhole":Color("a878f5"),"tankFire":Color("ff934f"),"ring":Color("ffd68a"),"healing":Color("6de3ad"),"holy":Color("ffeeb3"),"cosmic":Color("80b1ff"),"galaxy":Color("a0a1ff"),"discharge":Color("b8e7ff")}
var board: DeploymentBoard
var battle: BattleManager
var camera:=ArenaCameraController.new()
var effects: Array[Dictionary]=[]
var numbers: Array[Dictionary]=[]
var previous: Dictionary={}
var event_total: int=0
var real_age: float=0
var end_age: float=0
var debug_enabled: bool=false
var feed: Array[String]=[]
var connected: bool=false
var generated: Dictionary={}
var particles:=VisualParticles.new()
var parent_transform:=Transform2D.IDENTITY
var flashes: Dictionary={}
# A presentation freeze reproduces impact punctuation without changing simulation/TP time.
var impact_remaining: float=0
var impact_cooldown: float=0
var visual_positions: Dictionary={}
var freeze_positions: Dictionary={}
var last_dt: float=0
var explosive_seen: Dictionary={}
var tracked_projectiles: Dictionary={}
var projectile_trails: Dictionary={}
var projectile_origins: Dictionary={}
var trail_tick: float=-1
var release_counts: Dictionary={}
var weapon_releases: Dictionary={}
var afterimages: Array[Dictionary]=[]
const MAX_AFTERIMAGES=48
var kill_notices: Array[Dictionary]=[]
var cinematic:=BattleCinematicState.new()
var trans_active: bool=false
var trans_point:=Vector2.ZERO
var glow_layer: CombatGlowLayer
var field_layer: MagicFieldLayer
func impact_pause(milliseconds: int) -> void:
	if impact_cooldown>0:return
	impact_remaining=milliseconds/1000.0;impact_cooldown=.16;freeze_positions=visual_positions.duplicate()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field_layer=MagicFieldLayer.new();add_child(field_layer)
	glow_layer=CombatGlowLayer.new();glow_layer.host=self;add_child(glow_layer)
func attach(value: BattleManager) -> void:
	cleanup();battle=value
	if not is_instance_valid(battle):return
	show()
	battle.hide()
	battle.damage_resolver.damage_resolved.connect(_damage)
	battle.unit_died.connect(_death)
	battle.battle_finalizing.connect(_prepare_ending)
	connected=true
	for u in battle.units:release_counts[u.battle_id]=u.combat.attacks_released;previous[u.battle_id]={"hp":u.current_hp,"shield":u.shield_hp,"stun":u.stun_remaining,"inv":u.invincible_remaining}
func cleanup() -> void:
	if connected and is_instance_valid(battle):
		if battle.damage_resolver.damage_resolved.is_connected(_damage):battle.damage_resolver.damage_resolved.disconnect(_damage)
		if battle.unit_died.is_connected(_death):battle.unit_died.disconnect(_death)
		if battle.battle_finalizing.is_connected(_prepare_ending):battle.battle_finalizing.disconnect(_prepare_ending)
	cinematic=BattleCinematicState.new()
	kill_notices.clear()
	connected=false;battle=null;effects.clear();numbers.clear();previous.clear();feed.clear();event_total=0;end_age=0;camera.reset();particles.clear();flashes.clear();visual_positions.clear();freeze_positions.clear();impact_remaining=0;trans_active=false;explosive_seen.clear();tracked_projectiles.clear();projectile_trails.clear();projectile_origins.clear();release_counts.clear();weapon_releases.clear();afterimages.clear();trail_tick=-1;queue_redraw()
	if is_instance_valid(glow_layer):glow_layer.queue_redraw()
	if is_instance_valid(field_layer):field_layer.clear()
func add_effect(kind: String,point: Vector2,color: Color=Color.WHITE,radius: float=28,life: float=.45,direction: float=0) -> void:
	if not point.is_finite():return
	if effects.size()>=MAX_EFFECTS:effects.pop_front()
	effects.append({"kind":kind,"point":point,"color":color,"radius":radius,"life":life,"age":0.0})
	effects[-1]["angle"]=direction
	generated[kind]=int(generated.get(kind,0))+1
	var strong: bool=kind in ["explosion","ultimate","clash","parry_success","warrior_parry","death","shield_break"]
	var style: String="shard" if kind in ["reflect","shield_break"] else "heal" if kind in ["heal","vigor_totem"] else "spark"
	particles.burst(point,color,24 if strong else 11 if kind in ["hit","critical"] else 7,260 if strong else 190 if kind in ["hit","critical"] else 120,direction,style,strong)
	if kind=="explosion":
		particles.burst(point,Color("ffbf72"),14,210,direction,"ember",true)
		particles.burst(point,color,7,55,direction,"smoke",true)
	elif kind in ["ultimate","transcendence"]:particles.burst(point,color,16,100,direction,"mote",true)
	if kind in ["parry_success","warrior_parry"]:effects[-1].radius=135;effects[-1].life=.5;impact_pause(80);camera.impact(7.5,point)
	elif kind=="clash":effects[-1].radius=150;effects[-1].life=.36;impact_pause(80);camera.impact(8,point)
	elif kind=="critical":impact_pause(55);camera.impact(5,point)
	elif kind=="hit":effects[-1].radius=90;effects[-1].life=.24;impact_pause(35)
	elif kind=="explosion":impact_pause(80);camera.impact(9,point)
	elif kind=="ultimate":camera.impact(10,point)

func number(kind: String,point: Vector2,value: float,color: Color,actor: int) -> void:
	if value<=0:return
	for n in numbers:
		if n.actor==actor and n.kind==kind and float(n.age)<.12:n.value+=value;return
	if numbers.size()>=MAX_NUMBERS:numbers.pop_front()
	numbers.append({"kind":kind,"point":point,"value":value,"color":color,"actor":actor,"age":0.0})
func _explosion_once(key: int,point: Vector2,radius: float) -> void:
	if explosive_seen.has(key):return
	if explosive_seen.size()>=256:explosive_seen.erase(explosive_seen.keys()[0])
	explosive_seen[key]=true;add_effect("explosion",point,Color("ffbc75"),radius,.48)
func _departed_projectile(reference: WeakRef) -> void:
	var p=reference.get_ref()
	if p==null or not is_instance_valid(battle) or not is_instance_valid(p.source) or p.source.battle!=battle:return
	tracked_projectiles.erase(p.projectile_id)
	if p.metadata.get("detonated",false):_explosion_once(p.projectile_id,p.position,float(p.metadata.get("blast_radius",120)))
func _damage(source,target,out: DamageOutcome) -> void:
	if is_instance_valid(source) and is_instance_valid(battle):
		for p in battle.projectiles:
			if p.source!=source:continue
			if p.metadata.get("detonated",false):_explosion_once(p.projectile_id,p.position,float(p.metadata.get("blast_radius",120)))
			elif source.data.type_id==2 and p.live and p.kind.is_empty() and p.attack_instance!=null and p.attack_instance.hit_ids.has(target.battle_id):_explosion_once(p.projectile_id,p.position,110*float(p.metadata.get("scale",1)))
	if out.hp_damage>0:
		flashes[target.battle_id]=.15
		add_effect("critical" if out.critical else "hit",target.position,ArenaUI.GOLD if out.critical else AttackVisuals.ink(source.data.type_id) if is_instance_valid(source) else Color("fff3d1"),95 if out.critical else 28,.32 if out.critical else .24,(target.position-source.position).angle() if is_instance_valid(source) else 0)
		effects[-1]["angle"]=(target.position-source.position).angle() if is_instance_valid(source) else 0
		number("critical" if out.critical else "damage",target.position,out.hp_damage,ArenaUI.GOLD if out.critical else Color.WHITE,target.battle_id)
		camera.impact(5 if out.critical else 2,target.position)
	if out.shield_absorbed>0:
		add_effect("shield_hit",target.position,Color("7bd9ff"),32);number("shield",target.position,out.shield_absorbed,Color("7bd9ff"),target.battle_id)
		if target.shield_hp<=0:add_effect("shield_break",target.position,Color("7bd9ff"),48)
	if out.reflected_damage>0:add_effect("reflect",target.position,Color("ff90ce"),40)
	if is_instance_valid(source) and source.data.attack_profile.kind==AttackData.Kind.PROJECTILE:add_effect("projectile_hit",target.position,source.team_color(),18)
func _death(u,source) -> void:
	if u.data.type_id==13 and u.state_value("bomberFuse",1)<=0:_explosion_once(-u.battle_id,u.position,165*u.combat_scale())
	add_effect("death",u.position,u.team_color(),115*u.combat_scale(),.72)
	effects[-1]["type"]=u.data.type_id;effects[-1]["scale"]=u.combat_scale()
	particles.burst(u.position,u.team_color(),52,380,0,"shard",true)
	feed.push_front("%s %s 사망"%["아군" if u.original_team==0 else "적",u.data.display_name])
	if feed.size()>3:feed.pop_back()
	kill_notices.push_front({"age":0.0,"target":u.data.type_id,"target_name":u.data.display_name,"source":source.data.type_id if is_instance_valid(source) else -1,"source_name":source.data.display_name if is_instance_valid(source) else "","team":u.original_team})
	if kill_notices.size()>2:kill_notices.pop_back()
	if u.original_team==1:
		camera.focus(u.position,.5)
		if battle.units.all(func(v):return v.original_team!=1 or not v.alive):add_effect("final_kill",u.position,ArenaUI.GOLD,150,1);camera.impact(9,u.position);impact_pause(80);camera.finish(u.position)
func _prepare_ending(reason: BattleEndReason.Value) -> void:
	if cinematic.started or not is_instance_valid(battle):return
	var rows: Array[Dictionary]=[];var arrows: Array[Dictionary]=[]
	for echo in afterimages:
		var alpha: float=(1-float(echo.age)/float(echo.life))*.22
		draw_texture_rect(UnitIcon.texture(int(echo.type)),Rect2(echo.point-Vector2.ONE*25*float(echo.scale),Vector2.ONE*50*float(echo.scale)),false,Color(.6,.8,1,alpha))
	for u in battle.units:
		if AttackVisuals.body_visible(u):rows.append(CharacterPainter.capture_unit(u))
	for p in battle.projectiles:
		if p.live and not p.hidden_launch:
			arrows.append({"position":p.position,"velocity":p.velocity,"life":p.lifetime,"color":p.source.team_color() if is_instance_valid(p.source) else Color.WHITE})
	cinematic.begin("retreat" if reason==BattleEndReason.Value.RETREAT else "victory" if reason==BattleEndReason.Value.VICTORY else "defeat",rows,arrows)
	camera.overview_age=-1;camera.finale_remaining=0;camera.strength=0;impact_remaining=0
func ensure_cinematic(reason: BattleEndReason.Value) -> BattleCinematicState:
	_prepare_ending(reason);return cinematic
func _advance_ending(delta: float) -> void:
	var before: float=BattleCinematicState.motion_seconds(cinematic.age)
	cinematic.advance(delta);end_age=cinematic.age
	var slow_dt: float=BattleCinematicState.motion_seconds(cinematic.age)-before
	real_age+=slow_dt;particles.advance(slow_dt)
	for collection in [effects,numbers,afterimages]:
		for e in collection:e.age=float(e.age)+slow_dt
		for i in range(collection.size()-1,-1,-1):
			if collection[i].age>=collection[i].get("life",.9):collection.remove_at(i)
	camera.advance_overview(delta,BattleCinematicState.CAMERA_DURATION)
	if cinematic.complete:effects.clear();numbers.clear();afterimages.clear();particles.clear();camera.reset()
	queue_redraw()
	if is_instance_valid(glow_layer):glow_layer.queue_redraw()
	if is_instance_valid(field_layer):field_layer.clear()
func _process(delta: float) -> void:advance(delta)
func advance(delta: float) -> void:
	if is_instance_valid(battle) and battle.finished:
		if not cinematic.started:_prepare_ending(battle.result.end_reason)
		_advance_ending(maxf(0,delta));return
	real_age+=maxf(0,delta);last_dt=delta
	for i in range(kill_notices.size()-1,-1,-1):
		kill_notices[i].age+=maxf(0,delta)
		if kill_notices[i].age>3.2:kill_notices.remove_at(i)
	impact_cooldown=maxf(0,impact_cooldown-delta);impact_remaining=maxf(0,impact_remaining-delta)
	if impact_remaining<=0:particles.advance(delta)
	for id in flashes:flashes[id]=maxf(0,float(flashes[id])-delta)

	for collection in [effects,numbers,afterimages]:
		for e in collection:e.age=float(e.age)+delta
		for i in range(collection.size()-1,-1,-1):
			if collection[i].age>=collection[i].get("life",.9):collection.remove_at(i)
	if not is_instance_valid(battle):
		camera.reset();queue_redraw()
		if is_instance_valid(field_layer):field_layer.clear()
		return
	if battle.finished:
		end_age+=delta
		if end_age>1.55:effects.clear();numbers.clear();particles.clear();camera.reset()
	else:
		# Trails sample simulation progress only, so TP/render FPS cannot extend them.
		if battle.clock.elapsed!=trail_tick:
			trail_tick=battle.clock.elapsed
			for unit in battle.units:
				if not unit.alive or not AttackVisuals.body_visible(unit):continue
				if (unit.velocity+unit.knockback_velocity).length()>240 and (unit.evade_remaining>0 or unit.ultimate.cast.get("dashing",false) or unit.combat_state==CombatController.State.ACTIVE):
					if afterimages.size()>=MAX_AFTERIMAGES:afterimages.pop_front()
					afterimages.append({"point":unit.position,"type":unit.data.type_id,"scale":unit.combat_scale(),"age":0.0,"life":.16})
			var live_ids: Dictionary={}
			for projectile in battle.projectiles:
				if not projectile.live:continue
				live_ids[projectile.projectile_id]=true
				if not projectile_origins.has(projectile.projectile_id):projectile_origins[projectile.projectile_id]=projectile.previous_position
				var trail: Array=projectile_trails.get(projectile.projectile_id,[])
				if trail.is_empty() or Vector2(trail[-1]).distance_to(projectile.position)>1:trail.append(projectile.position)
				if trail.size()>10:trail.pop_front()
				projectile_trails[projectile.projectile_id]=trail
			for id in projectile_trails.keys():
				if not live_ids.has(id):projectile_trails.erase(id);projectile_origins.erase(id)
		for fighter in battle.units:
			var releases: int=fighter.combat.attacks_released
			if releases>int(release_counts.get(fighter.battle_id,releases)):
				var type: int=fighter.data.type_id;var angle: float=fighter.combat.aim_angle
				var muzzle: Vector2=fighter.position+Vector2.from_angle(angle)*(90 if type==6 else 72 if type==23 else 65 if type==18 else 45)*fighter.combat_scale()
				if type in [1,2,5,6,7,13,15,18,20,21,22,23,24,25]:
					add_effect("launch",muzzle,AttackVisuals.ink(type),45 if type in [6,7,18] else 20,.12)
					effects[-1].angle=angle;effects[-1]["type"]=type
					if type in [6,7,18,23]:particles.burst(muzzle,Color("fff0c7"),8,180,angle,"spark")
			release_counts[fighter.battle_id]=releases
		var transcending: bool=battle.transcendence!=null and not battle.transcendence.cast.is_empty()
		if transcending:
			var caster: BattleUnit=battle.find_actor(battle.transcendence.cast.actor)
			if caster!=null:trans_point=caster.position
			if not trans_active:add_effect("transcendence",trans_point,Color("dcb1ff"),130,.8)
		elif trans_active:camera.impact(12,trans_point);camera.focus(trans_point,.4)
		trans_active=transcending
		for p in battle.projectiles:
			if not tracked_projectiles.has(p.projectile_id):
				tracked_projectiles[p.projectile_id]=true
				if p.kind=="swordWave" and is_instance_valid(p.source) and p.source.data.type_id==0:
					weapon_releases[p.source.battle_id]={"start":battle.clock.elapsed,"angle":p.velocity.angle(),"life":.24}
					add_effect("warrior_release",p.source.position,Color("ffca88"),140*p.source.combat_scale(),.24,p.velocity.angle())
				p.tree_exiting.connect(_departed_projectile.bind(weakref(p)),CONNECT_ONE_SHOT)
		for id in weapon_releases.keys():
			if battle.clock.elapsed-float(weapon_releases[id].start)>float(weapon_releases[id].life):weapon_releases.erase(id)
		var total: int=0
		for count in battle.combat_event_counts.values():total+=count
		var fresh: int=mini(total-event_total,battle.combat_events.size());event_total=total
		for i in range(battle.combat_events.size()-fresh,battle.combat_events.size()):
			var e: Dictionary=battle.combat_events[i];var kind: String=String(e.kind)
			if kind in ["clash","parry_success","warrior_parry","ultimate","hero_rescue","wave_stun","vigor_totem","charge_totem"]:
				add_effect(kind,e.point,Color("8edff7") if "parry" in kind else ArenaUI.GOLD if kind=="clash" else Color("cb9aff"),42 if kind=="clash" else 32)
				if kind in ["parry_success","warrior_parry"]:
					var defender: BattleUnit=battle.units.filter(func(u):return u.position.distance_to(e.point)<2).front() if battle.units.any(func(u):return u.position.distance_to(e.point)<2) else null
					if defender!=null:effects[-1].angle=defender.facing;effects[-1].radius=135*defender.combat_scale()
				if kind=="ultimate":effects[-1]["actor"]=String(e.metadata.get("actor",""));effects[-1]["type"]=int(e.metadata.get("type",0))
				if kind in ["clash","ultimate"]:camera.impact(5,e.point);camera.focus(e.point)
		for u in battle.units:
			var old: Dictionary=previous.get(u.battle_id,{"hp":u.current_hp,"shield":0,"stun":0,"inv":0})
			if u.current_hp>float(old.hp):add_effect("heal",u.position,Color("77edb4"),25);number("heal",u.position,u.current_hp-float(old.hp),Color("77edb4"),u.battle_id)
			if u.stun_remaining>0 and float(old.stun)<=0:add_effect("stun",u.position,ArenaUI.GOLD,32)
			if u.invincible_remaining>0 and float(old.inv)<=0:add_effect("invincible",u.position,ArenaUI.GOLD,38)
			previous[u.battle_id]={"hp":u.current_hp,"shield":u.shield_hp,"stun":u.stun_remaining,"inv":u.invincible_remaining}
	var rows: Array=[]
	for unit in battle.units:
		if unit.alive:rows.append({"position":unit.position,"velocity":unit.velocity,"scale":unit.combat_scale()})
	camera.set_framing(rows)
	var ending: bool=battle.finished and end_age<1.55 and camera.finale_remaining>0
	if battle.clock.state==BattleClock.State.TURNING_SLOWDOWN and not battle.finished:camera.advance_overview(delta)
	else:camera.advance(delta,(battle.clock.state!=BattleClock.State.NORMAL or battle.finished) and not ending)
	queue_redraw()
	if is_instance_valid(glow_layer):glow_layer.queue_redraw()
	if is_instance_valid(field_layer) and board!=null:
		var rect: Rect2=board.board_rect()
		var at:=Transform2D(0,Vector2.ONE*rect.size.x/800,0,rect.position)*camera.transform()
		field_layer.sync(battle.zones.entries,at,real_age)
func _draw() -> void:
	if not is_instance_valid(battle) or board==null:return
	var rect: Rect2=board.board_rect();var factor: float=rect.size.x/800
	# Screen-space fill covers the viewport beyond the arena at its edges.
	# All actual map geometry must share the actor camera, including shake.
	draw_set_transform(rect.position,0,Vector2.ONE*factor)
	draw_rect(Rect2(0,0,800,800),Color("122219"))
	parent_transform=Transform2D(0,Vector2.ONE*factor,0,rect.position)*camera.transform()
	draw_set_transform_matrix(parent_transform)
	if is_instance_valid(field_layer):field_layer.align(parent_transform)
	VisualShapes.arena(self)
	if cinematic.started and battle.finished:
		_draw_ending();draw_set_transform(Vector2.ZERO);return
	for z in ([] if battle.finished else battle.zones.entries):
		var point: Vector2=CharacterPersistence.vector(z.point);var c: Color=ZONE_COLORS.get(z.kind,Color("a3b7ff"));var radius: float=z.radius
		if z.kind=="ring":
			draw_rect(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2),Color(c,.055))
			for layer in range(3):draw_rect(Rect2(point-Vector2.ONE*(radius-layer*5),Vector2.ONE*(radius-layer*5)*2),[Color("f7d6aa"),Color("e07a5b"),Color("5c83bc")][layer],false,3)
			for x in [-1,1]:
				for y in [-1,1]:draw_rect(Rect2(point+Vector2(x,y)*radius-Vector2.ONE*6,Vector2.ONE*12),Color("f2d1a0"))
		else:
			VfxArt.field(self,z,real_age,c)
			if z.kind=="discharge":
				for i in range(8):VisualShapes.bolt(self,point,point+Vector2.from_angle(i*TAU/8+real_age)*radius,c,i,3)
	for u in battle.units:
		if u.alive:AttackVisuals.frog_action(self,u)
	for attack in battle.melee_strikes:
		var owner: BattleUnit=battle.find_unit(attack.source_battle_id)
		if owner!=null and PhysicalAttackSystem.live(battle,attack):AttackVisuals.melee(self,owner,attack)
	for p in ([] if battle.finished else battle.projectiles):
		if p.live and not p.hidden_launch:AttackVisuals.projectile(self,p,projectile_trails.get(p.projectile_id,[]),battle.clock.elapsed,parent_transform,projectile_origins.get(p.projectile_id,p.previous_position))
	for wave in ([] if battle.finished else battle.combat_waves):
		var t: float=clampf(wave.age/maxf(.001,wave.duration),0,1)
		VfxArt.pressure(self,wave.origin,0,wave.radius*(.2+t*.8),Color("a7eaff"),(1-t)*.3)
	for u in battle.units:
		if AttackVisuals.body_visible(u):
			visual_positions[u.battle_id]=u.position
			var difference: Vector2=Vector2(freeze_positions.get(u.battle_id,u.position))-u.position if impact_remaining>0 else Vector2.ZERO
			draw_set_transform_matrix(parent_transform*Transform2D(0,difference));_unit(u,parent_transform*Transform2D(0,difference));draw_set_transform_matrix(parent_transform)
	particles.draw(self)
	for e in effects:
		if e.kind=="ultimate":
			var caster: BattleUnit=battle.find_actor(String(e.get("actor","")))
			if caster!=null:AbilityMotifs.draw(self,caster,e.point,real_age,float(e.age)/float(e.life))
		var t: float=float(e.age)/float(e.life);var c: Color=Color(e.color,1-t);var radius: float=float(e.radius)*(.25+t)
		if e.kind=="death":
			VfxArt.effect(self,e)
			CharacterPainter.draw_battle_portrait(self,Rect2(e.point-Vector2(32,33)*float(e.get("scale",1))+Vector2(0,t*12),Vector2(64,64)*float(e.get("scale",1))),int(e.get("type",0)),1-t)
			for i in range(5):draw_line(e.point+Vector2(-25,-20+i*10),e.point+Vector2(25+t*30,-20+i*10),Color(e.color,.5*(1-t)),2)
		elif VfxArt.effect(self,e):pass
		else:draw_arc(e.point,radius,0,TAU,32,c,2)
		if e.kind not in ["hit","critical","projectile_hit","explosion","heal","parry_success","warrior_parry","clash","ultimate","transcendence","launch","reflect","shield_break","shield_hit"]:
			for i in range(4):
				var v:=Vector2.from_angle(i*TAU/4+float(e.age)*.7);VfxArt.star(self,e.point+v*radius,5,e.color,1-t)
		if e.kind in ["parry_success","warrior_parry","clash","ultimate"]:draw_string(ThemeDB.fallback_font,e.point+Vector2(-26,-50-t*18),{"parry_success":"패링","warrior_parry":"반격","clash":"상쇄","ultimate":"궁극기"}[e.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,18,c)
	for n in numbers:
		var prefix: String="+" if n.kind=="heal" else "흡수 " if n.kind=="shield" else ""
		draw_string(ThemeDB.fallback_font,n.point+Vector2(-14,-38-float(n.age)*42),prefix+str(ceili(n.value)),HORIZONTAL_ALIGNMENT_LEFT,-1,23 if n.kind=="critical" else 18,Color(n.color,1-clampf(float(n.age)/.9,0,1)))
	if battle.transcendence!=null:
		var action: Dictionary=battle.transcendence.aim if not battle.transcendence.aim.is_empty() else battle.transcendence.cast
		if not action.is_empty():
			var caster=battle.find_actor(action.actor)
			if caster!=null:
				var direction:=Vector2.from_angle(action.angle)
				draw_rect(Rect2(0,0,800,800),Color(.08,.025,.14,.38))
				for i in range(24):
					var phase: float=fposmod(real_age*1.8+i*.117,1);var d:=Vector2.from_angle(i*2.399+real_age)
					draw_line(caster.position+d*(45+phase*150),caster.position+d*(40+phase*130),Color("dbacff",1-phase),2)
				VfxArt.glow(self,caster.position,150,Color("9a69ed"),.35)
				VfxArt.sigil(self,caster.position,85,real_age*3,Color("d4b5ff"),.8)
				VfxArt.ribbon(self,caster.position,140,action.angle-1.2,action.angle+.7,34,Color("d9a0ff"),.85)
				VisualShapes.streak(self,caster.position+direction*170,action.angle,340,18,Color("e5b9ff"),.6)
				draw_line(caster.position,caster.position+direction*310*caster.combat_scale(),Color("d6a6ff"),5)
				draw_arc(caster.position,40,0,TAU,32,Color("d6a6ff"),3)
	if battle.clock.state in [BattleClock.State.TURNING_SLOWDOWN,BattleClock.State.TURNING_PAUSED]:
		var t: float=clampf(battle.clock.slowdown_elapsed/2,0,1)
		draw_rect(Rect2(0,0,800,800),Color(.09,.15,.12,.19*t))
		for edge in range(10):draw_rect(Rect2(edge*8,edge*8,800-edge*16,800-edge*16),Color(0,.03,.025,.025*t),false,8)
		for x in range(80,800,80):draw_line(Vector2(x,20),Vector2(x,780),Color(.7,.8,.6,.07*t),1)
	draw_set_transform(Vector2.ZERO)
	_draw_kill_notices(rect)
func _draw_kill_notices(rect: Rect2) -> void:
	if battle.clock.state!=BattleClock.State.NORMAL:return
	var width: float=minf(252,rect.size.x-16)
	for i in range(kill_notices.size()):
		var row: Dictionary=kill_notices[i];var alpha: float=clampf((3.2-float(row.age))/.45,0,1);var at:=rect.position+Vector2(rect.size.x-width-8,10+i*34)
		draw_style_box(ArenaUI.box(Color(.065,.105,.09,.93*alpha),Color(.6,.65,.49,.65*alpha)),Rect2(at,Vector2(width,29)))
		if row.source>=0:UnitIcon.draw(self,Rect2(at+Vector2(5,4),Vector2.ONE*21),row.source,alpha)
		draw_string(get_theme_default_font(),at+Vector2(31,19),row.source_name,HORIZONTAL_ALIGNMENT_LEFT,width*.4-25,11,Color("a9c9f0",alpha))
		ArenaIcon.draw(self,at+Vector2(width*.49,14),"battle",17,Color(1,1,1,alpha))
		draw_string(get_theme_default_font(),at+Vector2(width*.56,19),row.target_name,HORIZONTAL_ALIGNMENT_LEFT,width*.44-30,11,Color(ArenaUI.DANGER if row.team==0 else Color("f5c89a"),alpha))
		UnitIcon.draw(self,Rect2(at+Vector2(width-26,4),Vector2.ONE*21),row.target,alpha)
func _unit(u: BattleUnit,parent: Transform2D) -> void:
	var at: Vector2=u.position;var radius: float=25*u.combat_scale();var color: Color=u.team_color()
	var pose_override: Dictionary={}
	if weapon_releases.has(u.battle_id):
		var row: Dictionary=weapon_releases[u.battle_id]
		var t: float=clampf((battle.clock.elapsed-float(row.start))/float(row.life),0,1)
		var swing: float=1-pow(1-t,3)
		pose_override={"key":"0:basic","index":13+roundi(swing*11),"angle":row.angle,"weapon_scale":1.4,"swing":swing}
	CharacterPainter.draw_unit(self,u,parent,float(flashes.get(u.battle_id,0))/.15,pose_override)
	_ability_state(u)
	draw_rect(Rect2(at+Vector2(-25,-radius-13),Vector2(50,5)),Color("32455c"))
	draw_rect(Rect2(at+Vector2(-25,-radius-13),Vector2(50*clampf(u.current_hp/u.max_hp,0,1),5)),color)
	if u.shield_hp>0:
		VfxArt.shield(self,at,radius+9,Color("7ddfff"),real_age);draw_rect(Rect2(at+Vector2(-25,-radius-20),Vector2(50*minf(1,u.shield_hp/100),3)),Color("7ddfff"))
	if u.invincible_remaining>0:
		VfxArt.glow(self,at,radius*1.8,Color("ffe4ab"),.2);VfxArt.sigil(self,at,radius+10,real_age,Color("ffe4ab"),.65)
	if u.parry_remaining>.8:VfxArt.glow(self,at+Vector2.from_angle(u.facing)*20,radius+12,Color("c2f5ff"),.28)
	var badges: Array[String]=[]
	if u.stun_remaining>0:badges.append("기절")
	if u.iron_defense_remaining>0:badges.append("철벽")
	if u.hidden_from_enemies:badges.append("은신")
	if not u.duel.is_empty():badges.append("승부")
	if u.state_value("reloadRemaining")>0:badges.append("장전")
	if not u.frog_carrier.is_empty():badges.append("포획")
	if not u.puppet_control.is_empty():badges.append("조종")
	var unique: String=CharacterVisuals.active_badge(u)
	if not unique.is_empty() and unique not in badges:badges.append(unique)
	if not badges.is_empty():draw_string(ThemeDB.fallback_font,at+Vector2(-22,-radius-25)," · ".join(badges),HORIZONTAL_ALIGNMENT_LEFT,-1,13,ArenaUI.GOLD)
	if u.knockback_velocity.length()>80:
		var angle: float=u.knockback_velocity.angle()
		VfxArt.flare(self,at-Vector2.from_angle(angle)*25,angle,minf(50,u.knockback_velocity.length()*.12),color,.35)
	if not battle.finished and not u.ultimate.cast.is_empty():
		AbilityMotifs.draw(self,u,at,real_age,0)
		var area: Dictionary=u.ability.cast_area(u,u.ultimate.cast)
		if not area.is_empty():
			if area.get("shape","")=="path":draw_line(CharacterPersistence.vector(area.from),CharacterPersistence.vector(area.to),Color("ddaeff"),2)
			else:draw_arc(CharacterPersistence.vector(area.point),float(area.radius),0,TAU,48,Color("ddaeff"),2)
	if not u.lost_sword.is_empty():draw_line(CharacterPersistence.vector(u.lost_sword.get("point",CharacterPersistence.point(at))),at,Color("ddd1ac"),1)
	if not u.saint_actor.is_empty():
		var saint=battle.find_actor(u.saint_actor)
		if saint!=null:draw_line(at,saint.position,Color(1,.8,.4,.2),1)
	if not u.cover_actor_id.is_empty():
		var covered=battle.find_actor(u.cover_actor_id)
		if covered!=null:draw_line(at,covered.position,Color(.4,.9,.8,.25),1)
	if camera.focus_remaining>0 and camera.focus_point.distance_to(at)<45:draw_arc(at,radius+17,0,TAU,40,Color("d4afff"),2)
	if board.selected_actor_id==u.actor_id():draw_arc(at,radius+13,0,TAU,40,ArenaUI.GOLD,2)

func _ability_state(u: BattleUnit) -> void:
	var p: Vector2=u.position;var s: float=u.combat_scale();var c:=Color("f1d48f")
	if u.state_value("mirrorReflectTime")>0:VisualShapes.barrier(self,p,39*s,Color("c4f4f7"),real_age)
	if u.state_value("paladinBlessingTime")>0:
		for i in range(4):ArenaIcon.draw(self,p+Vector2.from_angle(real_age+i*PI/2)*42*s,"heal",12,c)
	if u.state_value("bomberFuse",-1)>=0:
		var flame: Vector2=p+Vector2(5,-39)*s
		VisualShapes.streak(self,flame,-PI/2,20+sin(real_age*35)*7,9,Color("ffae68"))
	if u.data.type_id==6 and u.combat_state==CombatController.State.WINDUP:
		var progress: float=WeaponMotion.phase_progress(u)
		if u.combat.phase_time>=2:
			var dir:=Vector2.from_angle(u.combat.aim_angle)
			var tint:=Color("ffe6b3",.18+progress*.35) if progress>.9 else Color("b9835d",.18+progress*.35)
			if progress>.9:draw_line(p+dir*48,p+dir*1200,tint,3,true)
			else:draw_dashed_line(p+dir*48,p+dir*1200,tint,1,8)
		for i in range(10):draw_rect(Rect2(p+Vector2(-25+i*5,-55),Vector2.ONE*4),Color("ffd69a") if i<progress*10 else Color("3d4038"))
	if u.data.type_id in [7,23]:
		var maximum: int=2 if u.data.type_id==7 else 20
		var ammo: int=int(u.state_value("ammo",maximum))
		for i in range(maximum):draw_rect(Rect2(p+Vector2(-maximum*1.5+i*3,38)*s,Vector2(2,4)*s),c if i<ammo else Color("39463b"))
		if u.state_value("reloadRemaining")>0:
			var progress: float=clampf(1-u.state_value("reloadRemaining")/4,0,1)
			draw_arc(p,37*s,-PI/2,-PI/2+maxf(.001,progress*TAU),32,Color("e4bc73"),3)
	var shock: int=int(u.state_value("shockStacks"))
	for i in range(mini(3,shock)):
		var point: Vector2=p+Vector2.from_angle(-PI/2+(i-1)*.55)*35*s
		VisualShapes.streak(self,point,PI/2,10*s,4*s,Color("93dcff"),.85)
	if u.data.type_id==5 and u.combat_state==CombatController.State.ACTIVE and is_instance_valid(u.combat.healing_target):
		var patient: BattleUnit=u.combat.healing_target
		draw_line(p,patient.position,Color("c5f4e5",.35*(1-WeaponMotion.phase_progress(u))),3,true)
	if not u.puppet_control.is_empty():
		var cross: Vector2=p+Vector2(0,-48)*s
		draw_line(cross-Vector2(12,0)*s,cross+Vector2(12,0)*s,Color("ffe6ee"),4*s)
		draw_line(cross-Vector2(0,8)*s,cross+Vector2(0,8)*s,Color("ffe6ee"),4*s)
	if not u.lost_sword.is_empty():
		var at: Vector2=CharacterPersistence.vector(u.lost_sword.get("point",CharacterPersistence.point(p)))
		VisualShapes.streak(self,at,-.65,90*s,18*s,Color("e5d3b3"));draw_line(at+Vector2(-17,17),at+Vector2(2,36),Color("9c7149"),5)
	if not u.puppet_control.is_empty():
		for i in range(3):draw_line(p+Vector2((i-1)*12,-30)*s,p+Vector2((i-1)*23,-77)*s,Color("dca2e1"),1.5)
	
	if not u.hero_rescue.is_empty():VisualShapes.barrier(self,p,43*s,Color("ffd284"),real_age)

func _draw_ending() -> void:
	var time: float=BattleCinematicState.motion_seconds(cinematic.age)
	for row in cinematic.projectiles:
		if time<row.life:
			var point: Vector2=row.position+row.velocity*time
			if Rect2(0,0,800,800).has_point(point):VisualShapes.streak(self,point,row.velocity.angle(),34,3,row.color,.7)
	for row in cinematic.units:CharacterPainter.draw_snapshot(self,row,cinematic.position_for(row),parent_transform,time)
	for e in effects:
		if e.kind=="death":
			VfxArt.effect(self,e)
			var t: float=clampf(float(e.age)/float(e.life),0,1)
			CharacterPainter.draw_battle_portrait(self,Rect2(e.point-Vector2(32,33)*float(e.get("scale",1))+Vector2(0,t*12),Vector2.ONE*64*float(e.get("scale",1))),int(e.get("type",0)),1-t)
	particles.draw(self)
