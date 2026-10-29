class_name CombatPresentation
extends Control
## Read-only replacement renderer. Domain Nodes are hidden, never paused/rewritten.
const MAX_EFFECTS=96
const MAX_NUMBERS=40
const FLAMETHROWER=preload("res://scripts/abilities/flamethrower_ability.gd")
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
## Multi-kill (original spectator): kills within KILL_CHAIN_WINDOW battle seconds chain per killer.
const MULTI_KILL_NAMES=["","","더블 킬","트리플 킬","쿼드라 킬","펜타 킬","헥사 킬"]
const MULTI_KILL_COLORS=[Color.WHITE,Color.WHITE,Color("ffe28a"),Color("ffb45e"),Color("ff7a5a"),Color("ff5fa8"),Color("c58bff")]
const KILL_CHAIN_WINDOW: float=6
const BANNER_LIFE: float=2.6
var kill_streaks: Dictionary={}
var multi_banner: Dictionary={}
var multi_queue: Array[Dictionary]=[]
## Set when a KillFeed control shows the log outside the arena.
var external_kill_feed: bool=false
var cinematic:=BattleCinematicState.new()
var trans_active: bool=false
var trans_point:=Vector2.ZERO
var glow_layer: CombatGlowLayer
var field_layer: MagicFieldLayer
var ult_released: Dictionary={}
var ult_timers: Dictionary={}
var stance_marks:=StanceMarks.new()
## Buff windows opened by an ultimate; the unit wears a rising aura in its ink colour meanwhile.
const EMPOWERED_STATES=["guardianUltTime","paladinBlessingTime","mirrorReflectTime","sniperBurstReady","tankFlameReady"]
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
	kill_notices.clear();kill_streaks.clear();multi_banner.clear();multi_queue.clear()
	connected=false;battle=null;effects.clear();numbers.clear();previous.clear();feed.clear();event_total=0;end_age=0;camera.reset();particles.clear();flashes.clear();visual_positions.clear();freeze_positions.clear();impact_remaining=0;trans_active=false;explosive_seen.clear();tracked_projectiles.clear();projectile_trails.clear();projectile_origins.clear();release_counts.clear();weapon_releases.clear();ult_released.clear();ult_timers.clear();afterimages.clear();trail_tick=-1;queue_redraw()
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
	if out.ultimate and (out.hp_damage>0 or out.shield_absorbed>0) and is_instance_valid(source) and real_age-float(ult_timers.get("hit%d"%target.battle_id,-1.0))>.12:
		ult_timers["hit%d"%target.battle_id]=real_age
		var ink: Color=AttackVisuals.ink(source.data.type_id);var angle: float=(target.position-source.position).angle()
		add_effect("ult_hit",target.position,ink,110*target.combat_scale(),.4,angle)
		particles.burst(target.position,ink,12,320,angle,"spark",true);particles.burst(target.position,Color("fff3d6"),5,220,angle,"shard",true)
		impact_pause(50);camera.impact(5,target.position)
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
	var killer: bool=is_instance_valid(source) and source!=u
	kill_notices.push_front({"age":0.0,"target":u.data.type_id,"target_name":u.data.display_name,"target_color":u.team_color(),"source":source.data.type_id if killer else -1,"source_name":source.data.display_name if killer else "","source_color":source.team_color() if killer else Color("a9c9f0"),"team":u.original_team})
	if kill_notices.size()>3:kill_notices.pop_back()
	_count_kill(u,source if killer else null)
	if u.original_team==1:
		camera.focus(u.position,.5)
		if battle.units.all(func(v):return v.original_team!=1 or not v.alive):add_effect("final_kill",u.position,ArenaUI.GOLD,150,1);camera.impact(9,u.position);impact_pause(80);camera.finish(u.position)
func _count_kill(victim,source) -> void:
	kill_streaks.erase(victim.actor_id())
	if source==null or not source.alive:return
	var previous: Dictionary=kill_streaks.get(source.actor_id(),{})
	var count: int=int(previous.count)+1 if not previous.is_empty() and battle.clock.elapsed-float(previous.last)<=KILL_CHAIN_WINDOW else 1
	kill_streaks[source.actor_id()]={"count":count,"last":battle.clock.elapsed}
	if count<2:return
	var item: Dictionary={"actor":source.actor_id(),"type":source.data.type_id,"name":source.data.display_name,"color":source.team_color(),"count":mini(6,count),"age":0.0}
	# A killer's own banner upgrades in place; another killer waits its turn.
	if multi_banner.is_empty() or multi_banner.actor==item.actor:multi_banner=item;return
	for waiting in multi_queue:
		if waiting.actor==item.actor:waiting.count=item.count;return
	multi_queue.append(item)
## Multi-kill banner: a ribbon that snaps open across the upper field with the killer's portrait,
## the streak name, a shine sweep and one pip per kill.
func _draw_multi_kill(rect: Rect2) -> void:
	if multi_banner.is_empty():return
	var age: float=float(multi_banner.age);var level: int=int(multi_banner.count)
	var enter: float=clampf(age/.22,0,1);var alpha: float=minf(clampf(age/.1,0,1),clampf((BANNER_LIFE-age)/.45,0,1))
	var color: Color=MULTI_KILL_COLORS[level];var team: Color=multi_banner.color
	var font: Font=ArenaUI.heading_font();var text: String=MULTI_KILL_NAMES[level]
	var size: float=clampf(rect.size.x*.05,15,24);var text_w: float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(size)).x
	var icon: float=size*1.4;var band_h: float=size*1.7;var band_w: float=text_w+icon+size*1.6
	var center:=Vector2(rect.get_center().x,rect.position.y+clampf(rect.size.y*.24,90,180))
	var half: float=band_w*.5*(1-pow(1-enter,3));var tip: float=band_h*.42;var top: float=center.y-band_h*.5;var bottom: float=center.y+band_h*.5
	VfxArt.glow(self,center,band_w*.65,color,.2*alpha,.5)
	var band:=PackedVector2Array([Vector2(center.x-half-tip,center.y),Vector2(center.x-half,top),Vector2(center.x+half,top),Vector2(center.x+half+tip,center.y),Vector2(center.x+half,bottom),Vector2(center.x-half,bottom)])
	var dark:=Color(.06,.04,.09,.94*alpha);var lit:=Color(color.darkened(.62),.94*alpha)
	draw_polygon(band,PackedColorArray([Color(lit,lit.a*.8),dark,dark,Color(lit,lit.a*.8),lit,lit]))
	var outline:=band.duplicate();outline.append(band[0]);draw_polyline(outline,Color(color,.9*alpha),2,true)
	draw_line(Vector2(center.x-half,top+3),Vector2(center.x+half,top+3),Color(1,1,1,.14*alpha),1)
	if enter<1:return
	# A shine sweeps across once the ribbon is open.
	var k: float=clampf((age-.22)/.45,0,1)
	if k>0 and k<1:
		var x: float=lerpf(center.x-half,center.x+half-band_h*.4,k)
		draw_colored_polygon(PackedVector2Array([Vector2(x+band_h*.25,top+2),Vector2(x+band_h*.45,top+2),Vector2(x+band_h*.2,bottom-2),Vector2(x,bottom-2)]),Color(1,1,1,.22*(1-k)*alpha))
	var portrait:=Vector2(center.x-half+icon*.5+size*.25,center.y)
	draw_circle(portrait,icon*.56,Color("0b0f1a",alpha));UnitIcon.draw_team(self,Rect2(portrait-Vector2.ONE*icon*.5,Vector2.ONE*icon),int(multi_banner.type),team,alpha)
	var pop: float=1+(1-clampf((age-.22)/.25,0,1))*.15;var text_x: float=portrait.x+icon*.5+size*.35+text_w*.5
	draw_set_transform(Vector2(text_x,center.y),0,Vector2.ONE*pop)
	draw_string_outline(font,Vector2(-text_w*.5,size*.36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(size),4,Color(.06,.03,.02,.9*alpha))
	draw_string(font,Vector2(-text_w*.5,size*.36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,int(size),Color(color.lightened(.45),alpha))
	draw_set_transform(Vector2.ZERO)
	# Killer name above, one pip per kill below.
	var name: String=String(multi_banner.name)
	draw_string_outline(font,Vector2(center.x-120,top-6),name,HORIZONTAL_ALIGNMENT_CENTER,240,11,4,Color(0,0,0,.75*alpha))
	draw_string(font,Vector2(center.x-120,top-6),name,HORIZONTAL_ALIGNMENT_CENTER,240,11,Color(team.lightened(.45),alpha))
	var pip: float=3.5;var start: float=center.x-(level-1)*pip*1.6
	for i in range(level):
		var at:=Vector2(start+i*pip*3.2,bottom+pip+4)
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-pip),at+Vector2(pip,0),at+Vector2(0,pip),at+Vector2(-pip,0)]),Color(color.lightened(.3),alpha))
func _age_banner(dt: float) -> void:
	if multi_banner.is_empty():return
	multi_banner.age=float(multi_banner.age)+maxf(0,dt)
	if multi_banner.age>=BANNER_LIFE:multi_banner=multi_queue.pop_front() if not multi_queue.is_empty() else {}
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
	# The last kills often end the fight: their streak banner plays over the ending.
	_age_banner(delta)
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
	# Kill notices are UI and keep real time; combat effects follow the chosen battle speed (1×/2×/4×).
	var ui_delta: float=delta
	if is_instance_valid(battle) and not battle.finished:delta*=battle.clock.speed
	real_age+=maxf(0,delta);last_dt=delta
	stance_marks.track(battle if is_instance_valid(battle) else null,real_age)
	for i in range(kill_notices.size()-1,-1,-1):
		kill_notices[i].age+=maxf(0,ui_delta)
		if kill_notices[i].age>3.2:kill_notices.remove_at(i)
	_age_banner(ui_delta)
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
				if projectile.metadata.get("ultimate",false) and is_instance_valid(projectile.source):particles.burst(projectile.position,AttackVisuals.ink(projectile.source.data.type_id),1,90,projectile.velocity.angle()+PI,"spark")
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
			if fighter.alive:_ultimate_cues(fighter,delta)
		_ultimate_zone_motes(delta)
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
			if kind=="ult_impact":
				add_effect("ult_impact",e.point,AttackVisuals.ink(int(e.metadata.get("type",0))),float(e.metadata.get("radius",110)),1.1)
				particles.burst(e.point,Color("c8a77c"),20,340,0,"shard",true);particles.burst(e.point,Color("6b5a4a"),12,90,0,"smoke",true)
				impact_pause(90);camera.impact(14,e.point)
			if kind=="dragon_heart":
				add_effect("dragon_heart",e.point,Color("ff8a4a"),float(e.metadata.get("radius",130)),.6)
				particles.burst(e.point,Color("ffbf72"),12,170,0,"ember",false)
			elif kind=="phoenix":
				add_effect("hero_rescue",e.point,Color("ffb347"),48,.9)
				particles.burst(e.point,Color("ffbf72"),22,260,-PI*.5,"ember",true);camera.impact(6,e.point)
			if kind in ["clash","parry_success","warrior_parry","ultimate","hero_rescue","wave_stun","vigor_totem","charge_totem"]:
				var tint: Color=Color("8edff7") if "parry" in kind else ArenaUI.GOLD if kind=="clash" else AttackVisuals.ink(int(e.metadata.get("type",0))) if kind=="ultimate" else Color("cb9aff")
				add_effect(kind,e.point,tint,42 if kind=="clash" else 55 if kind=="ultimate" else 32)
				if kind in ["parry_success","warrior_parry"]:
					var defender: BattleUnit=battle.units.filter(func(u):return u.position.distance_to(e.point)<2).front() if battle.units.any(func(u):return u.position.distance_to(e.point)<2) else null
					if defender!=null:effects[-1].angle=defender.facing;effects[-1].radius=135*defender.combat_scale()
				if kind=="ultimate":
					effects[-1]["actor"]=String(e.metadata.get("actor",""));effects[-1]["type"]=int(e.metadata.get("type",0));effects[-1].life=.9
					add_effect("ult_flash",e.point,tint,0,.35)
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
	if battle.clock.state==BattleClock.State.TURNING_SLOWDOWN and not battle.finished:camera.advance_overview(ui_delta,2.0,ArenaCameraController.TURNING_ZOOM)
	else:camera.advance(ui_delta,(battle.clock.state!=BattleClock.State.NORMAL or battle.finished) and not ending,ArenaCameraController.TURNING_ZOOM if battle.clock.state==BattleClock.State.TURNING_PAUSED else 1.0)
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
	draw_rect(Rect2(0,0,800,800),Color("101a26"))
	parent_transform=Transform2D(0,Vector2.ONE*factor,0,rect.position)*camera.transform()
	draw_set_transform_matrix(parent_transform)
	if is_instance_valid(field_layer):field_layer.align(parent_transform)
	VisualShapes.arena(self,ArenaFloor.MARGIN)
	if battle.clock.state in [BattleClock.State.TURNING_SLOWDOWN,BattleClock.State.TURNING_PAUSED]:
		# Turning point tint lies on the ground only; units stay at full brightness.
		var t: float=clampf(battle.clock.slowdown_elapsed/2,0,1)
		draw_rect(Rect2(0,0,800,800),Color(.09,.15,.12,.19*t))
		for edge in range(10):draw_rect(Rect2(edge*8,edge*8,800-edge*16,800-edge*16),Color(0,.03,.025,.025*t),false,8)
		for x in range(80,800,80):draw_line(Vector2(x,20),Vector2(x,780),Color(.7,.8,.6,.07*t),1)
	if cinematic.started and battle.finished:
		_draw_ending();draw_set_transform(Vector2.ZERO);_draw_multi_kill(rect);return
	for z in ([] if battle.finished else battle.zones.entries):
		var point: Vector2=CharacterPersistence.vector(z.point);var c: Color=ZONE_COLORS.get(z.kind,Color("a3b7ff"));var radius: float=z.radius
		if z.kind=="ring":
			draw_rect(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2),Color(c,.055))
			for layer in range(3):draw_rect(Rect2(point-Vector2.ONE*(radius-layer*5),Vector2.ONE*(radius-layer*5)*2),[Color("f7d6aa"),Color("e07a5b"),Color("5c83bc")][layer],false,3)
			for x in [-1,1]:
				for y in [-1,1]:draw_rect(Rect2(point+Vector2(x,y)*radius-Vector2.ONE*6,Vector2.ONE*12),Color("f2d1a0"))
		else:
			VfxArt.field(self,z,real_age,c)
			if z.get("ultimate",false):_ult_zone(z,point,radius)
			if z.kind=="discharge":
				for i in range(8):VisualShapes.bolt(self,point,point+Vector2.from_angle(i*TAU/8+real_age)*radius,c,i,3)
	if not battle.finished:EnemyStrategyView.draw_ground(self,battle,real_age)
	for u in battle.units:
		if u.alive:AttackVisuals.frog_action(self,u)
	for attack in battle.melee_strikes:
		var owner: BattleUnit=battle.find_unit(attack.source_battle_id)
		if owner!=null and PhysicalAttackSystem.live(battle,attack):
			if attack.metadata.get("ultimate",false) and not attack.metadata.has("grapple"):_ult_melee(owner,attack)
			AttackVisuals.melee(self,owner,attack)
	for p in ([] if battle.finished else battle.projectiles):
		if p.live and not p.hidden_launch and p.metadata.get("ultimate",false):_ult_projectile(p)
		if p.live and not p.hidden_launch:AttackVisuals.projectile(self,p,projectile_trails.get(p.projectile_id,[]),battle.clock.elapsed,parent_transform,projectile_origins.get(p.projectile_id,p.previous_position))
	for wave in ([] if battle.finished else battle.combat_waves):
		var t: float=clampf(wave.age/maxf(.001,wave.duration),0,1)
		VfxArt.pressure(self,wave.origin,0,wave.radius*(.2+t*.8),Color("a7eaff"),(1-t)*.3)
	for u in battle.units:
		if AttackVisuals.body_visible(u):
			visual_positions[u.battle_id]=u.position
			var difference: Vector2=Vector2(freeze_positions.get(u.battle_id,u.position))-u.position if impact_remaining>0 else Vector2.ZERO
			draw_set_transform_matrix(parent_transform*Transform2D(0,difference));_unit(u,parent_transform*Transform2D(0,difference));draw_set_transform_matrix(parent_transform)
	for u in ([] if battle.finished else battle.units):
		if u.data.type_id==27 and u.state_value("trainFx")>0 and u.ultimate.cast.has("track"):_draw_train(u)
	particles.draw(self)
	for e in effects:
		if e.kind=="ultimate":
			var caster: BattleUnit=battle.find_actor(String(e.get("actor","")))
			if caster!=null:AbilityMotifs.draw(self,caster,e.point,real_age,float(e.age)/float(e.life))
		var t: float=float(e.age)/float(e.life);var c: Color=Color(e.color,1-t);var radius: float=float(e.radius)*(.25+t)
		if e.kind=="death":
			VfxArt.effect(self,e)
			UnitIcon.draw(self,Rect2(e.point-Vector2(26,26)*float(e.get("scale",1))+Vector2(0,t*12),Vector2(52,52)*float(e.get("scale",1))),int(e.get("type",0)),1-t)
			for i in range(5):draw_line(e.point+Vector2(-25,-20+i*10),e.point+Vector2(25+t*30,-20+i*10),Color(e.color,.5*(1-t)),2)
		elif e.kind=="ult_flash":
			draw_rect(Rect2(0,0,800,800),Color(e.color,.06*pow(1-t,2)))
			draw_arc(e.point,40+t*520,0,TAU,72,Color(Color(e.color).lightened(.4),.3*(1-t)),3*(1-t)+1,true)
		elif VfxArt.effect(self,e):pass
		else:draw_arc(e.point,radius,0,TAU,32,c,2)
		if e.kind not in ["hit","critical","projectile_hit","explosion","heal","parry_success","warrior_parry","clash","ultimate","transcendence","launch","reflect","shield_break","shield_hit","ult_flash","ult_release","ult_impact","ult_hit"]:
			for i in range(4):
				var v:=Vector2.from_angle(i*TAU/4+float(e.age)*.7);VfxArt.star(self,e.point+v*radius,5,e.color,1-t)
		if e.kind in ["parry_success","warrior_parry","clash"]:draw_string(ThemeDB.fallback_font,e.point+Vector2(-26,-50-t*18),{"parry_success":"패링","warrior_parry":"반격","clash":"상쇄"}[e.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,18,c)
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
	draw_set_transform(Vector2.ZERO)
	EnemyStrategyView.draw_badges(self,battle,parent_transform,board.strategy_actor_id,real_age)
	EnemyStrategyView.draw_detail(self,battle,rect,board.strategy_actor_id)
	if not external_kill_feed:_draw_kill_notices(rect)
	_draw_multi_kill(rect)
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
	# HP bar: dark outlined well and bright team-colour fill, never smaller than ~28x4 screen px
	# however far the board is scaled down on a phone.
	var px: float=1/maxf(.05,parent.get_scale().x)
	var bar_w: float=maxf(48,28*px);var hp_h: float=maxf(6,4*px);var ult_h: float=maxf(3,2.5*px)
	var hp_rect:=Rect2(at+Vector2(-bar_w*.5,-radius-6-hp_h-ult_h),Vector2(bar_w,hp_h));var hp_frac: float=clampf(u.current_hp/u.max_hp,0,1)
	draw_rect(hp_rect.grow(px),Color(0,0,0,.85));draw_rect(hp_rect,Color("1a2232"))
	draw_rect(Rect2(hp_rect.position,Vector2(hp_rect.size.x*hp_frac,hp_rect.size.y)),color.lightened(.15))
	draw_rect(Rect2(hp_rect.position,Vector2(hp_rect.size.x*hp_frac,hp_h*.3)),Color(1,1,1,.3))
	if u.data.ultimate_windup>=0:
		# Ultimate gauge under the HP bar; glows when ready.
		var gauge: float=clampf(u.ultimate_gauge/100,0,1);var ult_rect:=Rect2(Vector2(hp_rect.position.x,hp_rect.end.y+px),Vector2(bar_w,ult_h))
		draw_rect(ult_rect.grow(px*.8),Color(0,0,0,.8));draw_rect(ult_rect,Color("1c2433"))
		draw_rect(Rect2(ult_rect.position,Vector2(ult_rect.size.x*gauge,ult_rect.size.y)),Color("ffe28a") if gauge>=1 else Color("c49dff"))
		if gauge>=1:VfxArt.glow(self,at+Vector2(0,-radius-6),30,Color("ffe28a"),.25+.15*sin(real_age*6),.2)
	stance_marks.draw(self,u,hp_rect,px,real_age)
	if u.shield_hp>0:
		VfxArt.shield(self,at,radius+9,Color("7ddfff"),real_age);draw_rect(Rect2(hp_rect.position-Vector2(0,ult_h+px),Vector2(bar_w*minf(1,u.shield_hp/100),ult_h)),Color("7ddfff"))
	if u.invincible_remaining>0:
		VfxArt.glow(self,at,radius*1.8,Color("ffe4ab"),.2);VfxArt.sigil(self,at,radius+10,real_age,Color("ffe4ab"),.65)
	if u.parry_remaining>.8:VfxArt.glow(self,at+Vector2.from_angle(u.facing)*20,radius+12,Color("c2f5ff"),.28)
	var badges: Array[String]=[]
	if u.stun_remaining>0:badges.append("빙결" if u.state_value("frozenTime")>0 else "기절")
	if u.iron_defense_remaining>0:badges.append("철벽")
	if u.hidden_from_enemies:badges.append("은신")
	if not u.duel.is_empty():badges.append("승부")
	if u.state_value("reloadRemaining")>0:badges.append("장전")
	if not u.frog_carrier.is_empty():badges.append("포획")
	if not u.puppet_control.is_empty():badges.append("조종")
	var unique: String=CharacterVisuals.active_badge(u)
	if not unique.is_empty() and unique not in badges:badges.append(unique)
	if not badges.is_empty():draw_string(ThemeDB.fallback_font,Vector2(at.x-22,hp_rect.position.y-ult_h-3*px)," · ".join(badges),HORIZONTAL_ALIGNMENT_LEFT,-1,13,ArenaUI.GOLD)
	if u.knockback_velocity.length()>80:
		var angle: float=u.knockback_velocity.angle()
		VfxArt.flare(self,at-Vector2.from_angle(angle)*25,angle,minf(50,u.knockback_velocity.length()*.12),color,.35)
	if not battle.finished and not u.ultimate.cast.is_empty():
		_ultimate_charge(u,at,parent)
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
	if u.data.type_id==32:
		# Oil gauge: a thin orange bar under the unit, dimmed while it is too low to spray.
		var oil: float=u.state_value("oil",FLAMETHROWER.OIL_MAX)/FLAMETHROWER.OIL_MAX
		draw_rect(Rect2(p+Vector2(-15,38)*s,Vector2(30,4)*s),Color("2a2320"))
		draw_rect(Rect2(p+Vector2(-15,38)*s,Vector2(30*oil,4)*s),Color("ff8a3d") if u.state_value("oil",FLAMETHROWER.OIL_MAX)>=FLAMETHROWER.OIL_START else Color("8a5a3b"))
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
	_new_character_state(u,p,s)
	_ult_empowered(u,p,s)

func _new_character_state(u: BattleUnit,p: Vector2,s: float) -> void:
	# 말뚝 tether: rope to the stake and the allowed circle.
	if u.state_value("tetherTime")>0:
		var stake: Vector2=CharacterPersistence.vector(u.character_specific_state.get("tetherPoint",CharacterPersistence.point(p)))
		draw_arc(stake,u.state_value("tetherRadius",BindingController.TETHER_RADIUS),0,TAU,40,Color("c9a06b",.35),2,true)
		draw_line(stake,p,Color("d8b98a",.8),2,true)
		draw_rect(Rect2(stake-Vector2(4,14),Vector2(8,18)),Color("8a6440"));draw_rect(Rect2(stake-Vector2(6,16),Vector2(12,4)),Color("e8c48f"))
	# 자석 link: current between the pair, N/S marks over each head.
	if u.state_value("magnetTime")>0:
		var pole: String=str(u.character_specific_state.get("magnetPole",""))
		var tint:=Color("ff6f7a") if pole=="N" else Color("7fb6ff")
		var partner=battle.find_actor(str(u.character_specific_state.get("magnetPartner","")))
		if pole=="N" and partner!=null:VisualShapes.bolt(self,p,partner.position,Color("ffd0d6"),real_age*20,2)
		draw_circle(p+Vector2(0,-50)*s,9,Color(tint,.9));draw_string(ThemeDB.fallback_font,p+Vector2(-5,-45)*s,pole,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
	if u.state_value("magnetShockFx")>0:
		for i in range(3):VisualShapes.bolt(self,p+Vector2.from_angle(i*TAU/3+real_age*9)*30*s,p,Color("ffb3bb"),real_age*30+i,2)
	# 굴절 swap: light beam between the old and new spot.
	if u.state_value("refractFx")>0:
		var from: Vector2=CharacterPersistence.vector(u.character_specific_state.get("refractFrom",CharacterPersistence.point(p)))
		var a: float=u.state_value("refractFx")/.8
		draw_line(from,p,Color("bdf0ff",.7*a),6*a+1,true);draw_circle(from,22*a,Color("9fe3ff",.35*a));draw_circle(p,26*a,Color("e6fbff",.4*a))
	# 배달부 parcel: on the ground, or carried overhead.
	if u.data.type_id==29 and u.alive:
		var parcel: Dictionary=u.character_specific_state.get("parcel",{})
		if not parcel.is_empty():
			var at: Vector2=p+Vector2(0,-46)*s if parcel.get("held",false) else Vector2(float(parcel.x),float(parcel.y))
			if not parcel.get("held",false):draw_circle(at,18+sin(real_age*5)*3,Color("ffe08a",.18))
			draw_rect(Rect2(at-Vector2(10,8),Vector2(20,16)),Color("c08a4a"));draw_rect(Rect2(at-Vector2(2,8),Vector2(4,16)),Color("ffe08a"))
			draw_rect(Rect2(at-Vector2(10,8),Vector2(20,16)),Color("5a3a1e"),false,1.5)
	# 빙결: frost pips over the head; a block of ice while frozen.
	var frost: int=int(u.state_value("frostStacks"))
	if frost>0:
		for i in range(10):
			var a: float=-PI*.8+i*PI*.6/9
			draw_arc(p,34*s,a,a+.05,2,Color("bfeaff") if i<frost else Color("2a3a48"),4,true)
	if u.state_value("frozenTime")>0:
		var k: float=clampf(u.state_value("frozenTime")/4.0,0,1)
		var block:=Rect2(p-Vector2(27,30)*s,Vector2(54,56)*s)
		draw_rect(block,Color("9fdcff",.38));draw_rect(block,Color("e6f8ff",.85),false,2)
		draw_line(block.position+Vector2(6,6)*s,block.position+Vector2(20,22)*s,Color(1,1,1,.7),2)
		draw_line(block.position+Vector2(36,10)*s,block.position+Vector2(46,4)*s,Color(1,1,1,.5),2)
		VfxArt.glow(self,p,40*s,Color("9fdcff"),.15+.1*k)
	# 빙결술사 storm drifting across the field.
	if u.data.type_id==31 and u.alive and u.character_specific_state.has("storm"):_frost_storm(u)
	# 화염방사기 spraying: a flickering stream of flame from the nozzle.
	if u.data.type_id==32 and u.alive and u.combat_state==CombatController.State.ACTIVE and u.state_value("oil")>=1:_flame_stream(u)
	# Delivered buff: the gift icon rising over the recipient.
	if u.state_value("deliveryFx")>0:
		var kind: String=str(u.character_specific_state.get("deliveryKind","heal"))
		var t: float=1-u.state_value("deliveryFx")/1.2
		var icon: String={"heal":"heal","power":"fang","charge":"charge","shield":"shield"}.get(kind,"heal")
		ArenaIcon.draw(self,p+Vector2(0,-58-t*22)*s,icon,18,Color({"heal":"8ff0a4","power":"ff9a7a","charge":"9fd8ff","shield":"7ddfff"}.get(kind,"ffffff"),1-t))
## Shared ultimate cues: gathering motes during the windup, one burst when the ultimate fires.
func _ultimate_cues(u: BattleUnit,delta: float) -> void:
	var cast: Dictionary=u.ultimate.cast;var serial: int=u.ultimate.serial;var ink: Color=AttackVisuals.ink(u.data.type_id)
	if not ult_released.has(u.battle_id):ult_released[u.battle_id]=serial
	var winding: bool=not cast.is_empty() and float(cast.t)<float(cast.duration)
	if winding:
		ult_timers[u.battle_id]=float(ult_timers.get(u.battle_id,0))+delta
		if float(ult_timers[u.battle_id])>=.12:ult_timers[u.battle_id]=0;particles.burst(u.position+Vector2(0,12),ink,2,70,-PI/2,"mote")
	elif int(ult_released[u.battle_id])<serial:
		ult_released[u.battle_id]=serial
		add_effect("ult_release",u.position,ink,95*u.combat_scale(),.45,u.facing)
		particles.burst(u.position,Color("fff3d6"),10,260,u.facing,"spark",true)
		camera.impact(4,u.position)
	if u.data.type_id==27 and u.state_value("trainFx")>0 and cast.has("track"):_train_exhaust(u,cast,delta)
func _ultimate_charge(u: BattleUnit,at: Vector2,parent: Transform2D) -> void:
	var cast: Dictionary=u.ultimate.cast;var k: float=clampf(float(cast.t)/maxf(.05,float(cast.duration)),0,1)
	var ink: Color=AttackVisuals.ink(u.data.type_id);var r: float=58*u.combat_scale();var ground: Vector2=at+Vector2(0,14)*u.combat_scale()
	if u.data.type_id==27 and not cast.has("track"):_train_warning(u,cast,parent)
	# Subdued rune circle on the ground and a few gathering motes.
	VfxArt.glow(self,ground,r*1.3,ink,.1+.12*k,.45)
	VfxArt.ellipse(self,ground,r*(.7+.25*k),.42,Color(ink,.55),2)
	VfxArt.ellipse(self,ground,r*(.95+.25*k),.42,Color(ink,.3),1.2,real_age*2,real_age*2+PI*1.2)
	for i in range(5):
		var f: float=fmod(real_age*1.5+i*.2,1.0);var a: float=i*2.399
		VfxArt.star(self,at+Vector2.from_angle(a)*r*1.5*(1-f),2+3*f,ink.lightened(.35),f*.6,a)
	draw_arc(at,r*.72,-PI/2,-PI/2+TAU*k,48,Color(1,1,1,.55),2,true)

## 기관사: warning lane while the whistle blows, then the locomotive in track space (x along the rails).
func _train_warning(u: BattleUnit,cast: Dictionary,parent: Transform2D) -> void:
	var angle: float=float(cast.angle);var span: Vector2=u.ability.track_span(u.position,Vector2.from_angle(angle))
	draw_set_transform_matrix(parent*Transform2D(angle,u.position))
	draw_rect(Rect2(span.x,-58,span.y-span.x,116),Color("ff4a3a",.1+.07*sin(real_age*18)))
	for k in [-1,1]:draw_line(Vector2(span.x,k*58),Vector2(span.y,k*58),Color("ff6a4a",.65),2)
	var x: float=span.x+fmod(real_age*260,64)
	while x<span.y-12:
		draw_polyline(PackedVector2Array([Vector2(x-12,-16),Vector2(x+4,0),Vector2(x-12,16)]),Color("ffb08c",.75),4)
		x+=64
	draw_set_transform_matrix(parent)
func _train_exhaust(u: BattleUnit,cast: Dictionary,delta: float) -> void:
	var key: String="train%d"%u.battle_id;ult_timers[key]=float(ult_timers.get(key,0))+delta
	if float(ult_timers[key])<.03:return
	ult_timers[key]=0
	var track: Dictionary=cast.track;var dir: Vector2=Vector2.from_angle(float(track.angle));var side: Vector2=dir.orthogonal()
	var head: Vector2=Vector2(float(track.x),float(track.y))+dir*float(cast.s);var arena:=Rect2(0,0,800,800)
	var stack: Vector2=head-dir*62
	if arena.has_point(stack):particles.burst(stack,Color("8a8a96"),3,50,dir.angle()+PI,"smoke",true)
	for k in [-1,1]:
		var wheel: Vector2=head-dir*(40+VisualParticles.noise(real_age*13+k)*100)+side*k*32
		if arena.has_point(wheel):particles.burst(wheel,Color("ffb35c"),1,220,dir.angle()+PI+k*.5,"ember")
	if arena.has_point(head):camera.impact(2.5,head)
func _clip_rect(x0: float,x1: float,y0: float,y1: float,color: Color,lo: float,hi: float) -> void:
	var a: float=maxf(x0,lo);var b: float=minf(x1,hi)
	if b>a:draw_rect(Rect2(a,y0,b-a,y1-y0),color)
func _draw_train(u: BattleUnit) -> void:
	var cast: Dictionary=u.ultimate.cast;var track: Dictionary=cast.track;var angle: float=float(track.angle)
	var lo: float=float(track.from);var hi: float=float(track.to);var h: float=float(cast.s);var center:=Vector2(float(track.x),float(track.y))
	# Wider across than along so the body fills the track's hit width.
	draw_set_transform_matrix(parent_transform*Transform2D(angle,Vector2(1,1.4),0,center))
	# Sleepers and rails over the whole crossing; rails glow hot behind the train.
	var sleeper: float=ceilf(lo/28)*28
	while sleeper<hi:draw_rect(Rect2(sleeper-4,-26,8,52),Color("4e3c2e",.85));sleeper+=28
	for k in [-1,1]:
		draw_line(Vector2(lo,k*17),Vector2(hi,k*17),Color("aab4c4"),3)
		var hot0: float=maxf(lo,h-560);var hot1: float=minf(hi,h-270)
		if hot1>hot0:draw_line(Vector2(hot0,k*17),Vector2(hot1,k*17),Color("ff9a4a",.6),4)
	for i in range(12):
		var y: float=(VisualParticles.noise(i)*2-1)*44;var x: float=h-280-fmod(real_age*700+i*83,360)
		if x>lo and x-60<hi:draw_line(Vector2(maxf(lo,x-60),y),Vector2(minf(hi,x),y),Color(1,.95,.85,.35),2)
	# Rear wagon, coal tender, cab, boiler and the red cowcatcher in front.
	_clip_rect(h-270,h-214,-25,25,Color("8c3b2c"),lo,hi)
	for i in range(4):_clip_rect(h-264+i*13,h-256+i*13,-21,21,Color("a94c37"),lo,hi)
	for k in [-1,1]:_clip_rect(h-270,h-214,k*25-2,k*25+2,Color("4a1d14"),lo,hi)
	_clip_rect(h-214,h-204,-4,4,Color("2a2a30"),lo,hi)
	_clip_rect(h-204,h-160,-26,26,Color("3a3330"),lo,hi)
	_clip_rect(h-198,h-166,-19,19,Color("17130f"),lo,hi)
	for i in range(3):
		var coal:=Vector2(h-192+i*11,(i-1)*7.0)
		if coal.x>lo and coal.x<hi:draw_circle(coal,5,Color("2c2620"))
	_clip_rect(h-160,h-152,-4,4,Color("2a2a30"),lo,hi)
	_clip_rect(h-152,h-110,-29,29,Color("e07a5f"),lo,hi)
	for k in [-1,1]:_clip_rect(h-152,h-110,k*29-(6 if k>0 else 0),k*29+(0 if k>0 else 6),Color("a8462f"),lo,hi)
	for k in [-1,1]:_clip_rect(h-146,h-132,k*16-4,k*16+4,Color("ffe3a6"),lo,hi)
	for k in [-1,1]:_clip_rect(h-142,h-18,k*31-3,k*31+3,Color("1d1f25"),lo,hi)
	_clip_rect(h-110,h-14,-22,22,Color("353c4a"),lo,hi)
	_clip_rect(h-110,h-14,-22,-13,Color("5b6880"),lo,hi)
	for x in [h-98,h-72,h-44]:_clip_rect(x,x+5,-22,22,Color("d6a84a"),lo,hi)
	var roll: float=sin(real_age*34)*5
	for k in [-1,1]:
		for x in [h-128,h-96,h-64,h-32]:
			if x>lo and x<hi:draw_circle(Vector2(x,k*31),7,Color("3d414c"));draw_line(Vector2(x,k*31),Vector2(x+roll,k*31+cos(real_age*34)*5),Color("9aa2b0"),2)
		if h-130>lo and h-30<hi:draw_line(Vector2(h-130+roll,k*31),Vector2(h-30+roll,k*31),Color("d0453a"),3)
	if h-88>lo and h-88<hi:draw_circle(Vector2(h-88,0),7,Color("d6a84a"))
	if h-62>lo and h-62<hi:draw_circle(Vector2(h-62,0),11,Color("15161b"));draw_arc(Vector2(h-62,0),11,0,TAU,20,Color("6c7080"),3)
	_clip_rect(h-14,h+2,-23,23,Color("23262e"),lo,hi)
	if h+28<hi and h+2>lo:
		draw_colored_polygon(PackedVector2Array([Vector2(h+2,-26),Vector2(h+28,0),Vector2(h+2,26)]),Color("c43d2e"))
		for k in [-1,1]:draw_line(Vector2(h+4,k*16),Vector2(h+20,k*5),Color("ff8a6e"),2)
		draw_circle(Vector2(h+2,0),6,Color("fff1b0"))
	draw_set_transform_matrix(parent_transform)
	var dir: Vector2=Vector2.from_angle(angle);var lamp: Vector2=center+dir*(h+4)
	if h+4>lo and h+4<hi:VfxArt.flare(self,lamp+dir*70,angle,150,Color("fff1b0"),.6);VfxArt.glow(self,lamp,40,Color("ffe6a0"),.5)

## Ultimate-tagged attacks: heavier trails, slashes, hits and fields in the caster's ink colour.
func _ult_projectile(p: BattleProjectile) -> void:
	if not is_instance_valid(p.source):return
	var ink: Color=AttackVisuals.ink(p.source.data.type_id);var r: float=maxf(14,p.hit_radius)
	var trail: Array=projectile_trails.get(p.projectile_id,[])
	for i in range(1,trail.size()):
		var k: float=float(i)/trail.size()
		draw_line(trail[i-1],trail[i],Color(ink,.4*k),r*1.3*k,true)
	VfxArt.glow(self,p.position,r*2.3,ink,.45);VfxArt.glow(self,p.position,r*.9,Color("fff6e6"),.35)
	for i in range(3):
		var a: float=real_age*6+i*TAU/3;VfxArt.star(self,p.position+Vector2.from_angle(a)*r*.9,5,ink.lightened(.4),.8,a)
func _ult_melee(owner: BattleUnit,attack: AttackInstance) -> void:
	var ink: Color=AttackVisuals.ink(owner.data.type_id);var t: float=clampf(attack.age/maxf(.001,attack.duration),0,1)
	var reach: float=maxf(70,attack.reach);var half: float=clampf(attack.cone*.5,.35,1.6);var sweep: float=1-pow(1-t,3)
	var start: float=attack.angle-half;var end: float=start+2*half*sweep
	VfxArt.ribbon(self,owner.position,reach,start,end,reach*.5,ink,(1-t)*.8)
	VfxArt.ribbon(self,owner.position,reach*.8,start,end,reach*.22,Color("fff3dc"),(1-t)*.75)
	VfxArt.flare(self,owner.position+Vector2.from_angle(attack.angle)*reach*.6,attack.angle,reach*.55*(1-t),ink,(1-t)*.6)
func _ult_zone(z: Dictionary,point: Vector2,radius: float) -> void:
	var source=battle.find_actor(z.source)
	if source==null or z.kind=="ring":return
	var ink: Color=AttackVisuals.ink(source.data.type_id);var pulse: float=.5+.5*sin(real_age*4)
	VfxArt.glow(self,point,radius*1.05,ink,.06+.05*pulse)
	draw_arc(point,radius,0,TAU,72,Color(ink,.35+.25*pulse),3,true)
	draw_arc(point,radius*(.9-.04*pulse),real_age,real_age+PI*1.3,48,Color(ink.lightened(.4),.4),2,true)
	draw_arc(point,radius*(.9-.04*pulse),real_age+PI,real_age+PI*2.3,48,Color(ink.lightened(.4),.4),2,true)
func _ultimate_zone_motes(delta: float) -> void:
	ult_timers["zones"]=float(ult_timers.get("zones",0))+delta
	if float(ult_timers["zones"])<.1:return
	ult_timers["zones"]=0
	for z in battle.zones.entries:
		var source=battle.find_actor(z.source)
		if source==null or not z.get("ultimate",false) or z.kind=="ring":continue
		var seed: float=real_age*31+float(z.area_id)
		var at: Vector2=CharacterPersistence.vector(z.point)+Vector2.from_angle(VisualParticles.noise(seed)*TAU)*float(z.radius)*sqrt(VisualParticles.noise(seed+1))
		particles.burst(at,AttackVisuals.ink(source.data.type_id),2,60,-PI/2,"mote")
	for u in battle.units:
		if u.data.type_id!=31 or not u.alive or not u.character_specific_state.has("storm"):continue
		var storm: Dictionary=u.character_specific_state.storm;var seed: float=real_age*29+u.battle_id
		var spot: Vector2=CharacterPersistence.vector(storm)+Vector2.from_angle(VisualParticles.noise(seed)*TAU)*115*sqrt(VisualParticles.noise(seed+1))
		particles.burst(spot,Color("eaf8ff"),3,140,float(storm.angle)+PI*.5,"spark")
func _ult_empowered(u: BattleUnit,p: Vector2,s: float) -> void:
	var dashing: bool=u.ultimate.cast.get("dashing",false)
	var active: bool=dashing
	for key in EMPOWERED_STATES:
		var v=u.character_specific_state.get(key,0)
		if (v is bool and v) or (not v is bool and float(v)>0):active=true;break
	if not active:return
	var ink: Color=AttackVisuals.ink(u.data.type_id)
	VfxArt.glow(self,p,36*s,ink,.16+.06*sin(real_age*5))
	for i in range(6):
		var phase: float=fmod(real_age*1.1+i/6.0,1.0)
		VfxArt.star(self,p+Vector2(cos(i*1.7+real_age)*20,16-phase*46)*s,4+3*(1-phase),ink.lightened(.3),(1-phase)*.7)
	if dashing:
		var motion: Vector2=u.velocity+u.knockback_velocity
		if motion.length()>60:VfxArt.flare(self,p-motion.normalized()*34*s,motion.angle(),80*s,ink,.6)

func _frost_storm(u: BattleUnit) -> void:
	var storm: Dictionary=u.character_specific_state.storm;var at: Vector2=CharacterPersistence.vector(storm)
	var r: float=115*u.combat_scale();var fade: float=clampf(float(storm.life)/.6,0,1)*clampf((7-float(storm.life))/.4,0,1)
	VfxArt.glow(self,at,r*1.25,Color("8fd4ff"),.32*fade)
	draw_circle(at,r,Color("cfeeff",.08*fade))
	for i in range(3):
		var spin: float=real_age*(2.2+i*.8)*(1 if i%2==0 else -1)
		draw_arc(at,r*(.45+i*.25),spin,spin+PI*1.2,40,Color("e6f8ff",(.55-i*.12)*fade),3-i*.6,true)
	for i in range(26):
		var a: float=real_age*(1.6+VisualParticles.noise(i)*1.5)+i*2.399;var d: float=r*(.2+VisualParticles.noise(i+7)*.8)
		VfxArt.star(self,at+Vector2.from_angle(a)*d,3+VisualParticles.noise(i+3)*4,Color("f2fbff"),.85*fade,a)

func _flame_stream(u: BattleUnit) -> void:
	var scale: float=u.combat_scale();var dir: Vector2=Vector2.from_angle(u.combat.aim_angle);var side: Vector2=dir.orthogonal()
	var origin: Vector2=u.position+dir*34*scale;var length: float=240*scale;var k: float=clampf(u.combat.phase_time/.12,0,1)
	VfxArt.glow(self,origin+dir*length*.45,length*.55,Color("ff7a2f"),.22*k)
	for i in range(14):
		var t: float=(i+fposmod(real_age*9,1.0))/14.0;var wobble: float=sin(real_age*31+i*1.7)*10*t*scale
		var at: Vector2=origin+dir*length*t*k+side*wobble;var r: float=(6+28*t)*scale
		draw_circle(at,r,Color(Color("ff4d1f").lerp(Color("ffb340"),1-t),.42*(1-t*.75)*k))
		if t<.55:draw_circle(at,r*.5,Color("fff1c4",.55*(1-t/.55)*k))
	for i in range(6):
		var t: float=fposmod(real_age*2.3+i*.17,1.0)
		VfxArt.star(self,origin+dir*length*t+side*sin(i*5.1+real_age*7)*18*t*scale,3+2*(1-t),Color("ffd27a"),.8*(1-t)*k,real_age*4+i)

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
			UnitIcon.draw(self,Rect2(e.point-Vector2(26,26)*float(e.get("scale",1))+Vector2(0,t*12),Vector2.ONE*52*float(e.get("scale",1))),int(e.get("type",0)),1-t)
	particles.draw(self)
