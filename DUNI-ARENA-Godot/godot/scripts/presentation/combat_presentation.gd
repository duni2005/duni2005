class_name CombatPresentation
extends Control
## Read-only replacement renderer. Domain Nodes are hidden, never paused/rewritten.
const MAX_EFFECTS=96
const MAX_NUMBERS=40
const FLAMETHROWER=preload("res://scripts/abilities/flamethrower_ability.gd")
const ZONE_COLORS={"blackhole":Color("a878f5"),"tankFire":Color("ff934f"),"ring":Color("ffd68a"),"healing":Color("6de3ad"),"holy":Color("ffeeb3"),"cosmic":Color("80b1ff"),"galaxy":Color("a0a1ff"),"discharge":Color("b8e7ff"),"griffinStorm":Color("9ff0d8")}
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
## Element visuals: orbs of light / dark flying between units, and per-unit emitter clocks for
## the rising flames, smoke and poison plumes.
var orbs: Array[Dictionary]=[]
## End of the hero's grab + charge (HeroAbility GRAB + CHARGE), when the fist is thrown.
const FIST_CHARGE_END: float=.64
var emit_clock: Dictionary={}
## Element status damage numbers and badges (ElementEffects).
const STATUS_COLORS={&"burn":Color("ff9a52"),&"burn_spread":Color("ffb27a"),&"poison":Color("8fe36b"),&"frostbite":Color("a8e4ff"),&"chain_shock":Color("9fdcff"),&"erosion":Color("b48cff")}
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
## Shader-drawn shockwaves, lightning and fire (ShaderFxLayer); false falls back to shapes.
var shader_fx: ShaderFxLayer
var use_shader_fx: bool=true
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
	shader_fx=ShaderFxLayer.new();add_child(shader_fx)
	glow_layer=CombatGlowLayer.new();glow_layer.host=self;add_child(glow_layer)
	bar_overlay=BarOverlay.new();bar_overlay.host=self;add_child(bar_overlay)
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
	if is_instance_valid(bar_overlay):bar_overlay.queue_redraw()
	connected=false;battle=null;effects.clear();numbers.clear();previous.clear();feed.clear();event_total=0;end_age=0;camera.reset();particles.clear();flashes.clear();visual_positions.clear();freeze_positions.clear();impact_remaining=0;trans_active=false;explosive_seen.clear();tracked_projectiles.clear();projectile_trails.clear();projectile_origins.clear();release_counts.clear();weapon_releases.clear();ult_released.clear();ult_timers.clear();afterimages.clear();orbs.clear();emit_clock.clear();trail_tick=-1;queue_redraw()
	if is_instance_valid(glow_layer):glow_layer.queue_redraw()
	if is_instance_valid(field_layer):field_layer.clear()
	if is_instance_valid(shader_fx):shader_fx.clear()
## Effects that bring their own particles (no default burst where they are added).
const QUIET_EFFECTS: Array = ["santa_sleigh","santa_snowfall","gift_fall","gift_text","gift_mark","frost_patch","snow_gather"]
const SANTA_AWAY: float = 3.2 # SantaAbility.AWAY_TIME
const GIFT_LABELS: Dictionary = {"mid":"얼음 피해","high":"큰 얼음 피해!","stun":"기절 6초","drain":"궁극기 초기화","root":"속박 10초","weak":"받는 피해 +50%","heal20":"HP +20%","heal30":"HP +30%","ult_full":"궁극기 충전","ult_half":"궁극기 +50%","power":"공격력 +50%"}
## Where the sleigh is at progress t (0..1) of Santa's absence: a long arc across the sky.
static func sleigh_point(t: float) -> Vector2:return Vector2(-200+1200*t,190+110*sin(t*PI*1.4))
func _star(at: Vector2,r: float,turn: float,color: Color) -> void:
	var pts:=PackedVector2Array()
	for k in range(10):pts.append(at+Vector2.from_angle(turn+k*PI/5-PI*.5)*(r if k%2==0 else r*.45))
	draw_colored_polygon(pts,color)
## 가위바위보 승부: each duelist pumps a fist over its head ("가위, 바위, 보!"), then both throw
## their hands; the winner's glows gold, the loser's dims under a red cross.
func _rps_hands(u: BattleUnit,p: Vector2,s: float) -> void:
	var d: Dictionary=u.duel;var mine: bool=String(d.get("master",""))==u.actor_id()
	var at: Vector2=p+Vector2(0,-64)*s;var time: float=float(d.get("time",0))
	if not bool(d.get("resolved",false)) or not d.has("ms"):
		var bob: float=absf(sin(time*PI*1.75))*10
		_rps_hand(at+Vector2(0,-bob),0,1.0,Color(1,1,1,1))
		if mine:
			var words: Array=["가위","바위","보!"];var w: String=words[mini(2,int(time/.58))]
			draw_string_outline(ThemeDB.fallback_font,at+Vector2(-40,-26),w,HORIZONTAL_ALIGNMENT_CENTER,80,15,4,Color(0,0,0,.8))
			draw_string(ThemeDB.fallback_font,at+Vector2(-40,-26),w,HORIZONTAL_ALIGNMENT_CENTER,80,15,Color("ffe6a0"))
		return
	var hand: int=int(d.ms) if mine else int(d.ts);var other: int=int(d.ts) if mine else int(d.ms)
	var won: bool=(hand-other+3)%3==1;var lost: bool=(other-hand+3)%3==1
	var pop: float=1+.35*maxf(0,1-(time-1.7)*6)
	if won:VfxArt.glow(self,at,30,Color("ffd65c"),.6)
	_rps_hand(at,hand,pop,Color(1,1,1,1) if not lost else Color(.6,.6,.65,1))
	if lost:
		draw_line(at+Vector2(-12,-12),at+Vector2(12,12),Color("ff5a5a"),3.5,true);draw_line(at+Vector2(12,-12),at+Vector2(-12,12),Color("ff5a5a"),3.5,true)
## A hand: 0 rock (fist), 1 paper (open palm), 2 scissors (two fingers in a V).
func _rps_hand(at: Vector2,kind: int,k: float,tint: Color) -> void:
	var skin: Color=Color("ffd2a8")*tint;var line: Color=Color("6b4a32");k*=1.35;var r: float=11*k
	match kind:
		1:
			for i in range(4):
				var x: float=(i-1.5)*5.2*k;draw_line(at+Vector2(x,-r*.2),at+Vector2(x*1.15,-r*1.55),line,5.4*k,true);draw_line(at+Vector2(x,-r*.2),at+Vector2(x*1.15,-r*1.55),skin,3.6*k,true)
			draw_line(at+Vector2(r*.7,r*.1),at+Vector2(r*1.35,-r*.55),line,5.4*k,true);draw_line(at+Vector2(r*.7,r*.1),at+Vector2(r*1.35,-r*.55),skin,3.6*k,true)
			draw_circle(at,r,line);draw_circle(at,r-1.5,skin)
		2:
			for side in [-1,1]:
				var tip: Vector2=at+Vector2(side*r*.75,-r*1.65);draw_line(at+Vector2(side*2.5*k,-r*.3),tip,line,5.6*k,true);draw_line(at+Vector2(side*2.5*k,-r*.3),tip,skin,3.8*k,true)
			draw_circle(at,r,line);draw_circle(at,r-1.5,skin)
			draw_arc(at+Vector2(0,r*.15),r*.55,PI*1.1,PI*1.9,8,line,1.4,true)
		_:
			draw_circle(at,r,line);draw_circle(at,r-1.5,skin)
			for i in range(3):draw_arc(at+Vector2((i-1)*r*.55,-r*.35),r*.32,PI,TAU,8,line,1.4,true)
## Seconds since Santa left, or -1 once Santa is back (the sleigh and gifts then stop drawing).
func _santa_clock(id: int) -> float:
	for v in battle.units:
		if v.battle_id==id:return v.state_value("santaClock") if v.state_value("santaAway")>0 else -1.0
	return -1.0
## The giant snowball rolling ahead of the snowman: a shaded white ball with turning streaks.
func _draw_snowball(u: BattleUnit) -> void:
	var ball: Dictionary=u.character_specific_state.snowball
	var at: Vector2=Vector2(float(ball.x),float(ball.y));var dir: Vector2=Vector2.from_angle(float(ball.angle))
	var r: float=(34+22*clampf(float(ball.get("rolled",0))/600.0,0,1))*u.combat_scale()
	# The packed-snow track it leaves behind, widening as the ball grows.
	var start: Vector2=Vector2(float(ball.get("sx",at.x)),float(ball.get("sy",at.y)))
	if start.distance_to(at)>4:
		draw_line(start,at,Color("eaf6ff",.28),r*1.5,true);draw_line(start,at,Color("ffffff",.3),r*.7,true)
		var side: Vector2=dir.orthogonal()*r*.78
		draw_line(start+side*.6,at+side,Color("cfe6f5",.5),2,true);draw_line(start-side*.6,at-side,Color("cfe6f5",.5),2,true)
	# Speed streaks and a snow spray at the back.
	for k in range(7):
		var off: Vector2=dir.orthogonal()*(k-3)*r*.28
		draw_line(at-dir*r*(1.1+fmod(k*.37,.4))+off,at-dir*r*(1.9+fmod(k*.53,.6))+off,Color("ffffff",.45),2,true)
	for k in range(6):draw_circle(at-dir*(r*.6+k*14),r*(.5-k*.06),Color("eaf6ff",.22-k*.03))
	draw_set_transform_matrix(parent_transform*Transform2D(0,Vector2(1,.35),0,at+Vector2(0,r*.75)));draw_circle(Vector2.ZERO,r*1.05,Color(0,0,0,.22));draw_set_transform_matrix(parent_transform)
	draw_circle(at,r,Color("eef7fd"))
	draw_circle(at+Vector2(r*.18,r*.2),r*.82,Color("dcecf6"))
	draw_circle(at+Vector2(-r*.25,-r*.3),r*.55,Color("ffffff"))
	# Lumps of snow and bits of ice packed into the surface turn with the roll.
	var spin: float=float(ball.get("rolled",0))/maxf(8,r)
	for k in range(7):
		var a: float=spin+k*TAU/7;var q: Vector2=at+Vector2.from_angle(a)*r*(.5+.3*fmod(k*.618,1.0))
		if cos(a-dir.angle()-PI*.5)<-.2:continue
		draw_circle(q,r*(.1+.05*fmod(k*.37,1.0)),Color("c4dcec") if k%3 else Color("9fd8f0"))
	for k in range(4):
		var a: float=spin+k*TAU/4
		draw_arc(at,r*.62,a,a+.8,10,Color("b8d6ea",.8),3,true)
	draw_arc(at,r,0,TAU,40,Color("9fc3dc"),3,true)
	VfxArt.glow(self,at,r*1.5,Color("dff4ff"),.3)
	# Anyone caught is packed into the front of the ball.
	for id in ball.get("hit",[]):
		for v in battle.units:
			if v.battle_id==int(id) and v.alive:
				for k in range(5):draw_circle(v.position+Vector2.from_angle(k*TAU/5+.4)*16,7,Color("ffffff",.8))
func add_effect(kind: String,point: Vector2,color: Color=Color.WHITE,radius: float=28,life: float=.45,direction: float=0) -> void:
	if not point.is_finite():return
	if effects.size()>=MAX_EFFECTS:effects.pop_front()
	effects.append({"kind":kind,"point":point,"color":color,"radius":radius,"life":life,"age":0.0})
	effects[-1]["angle"]=direction
	generated[kind]=int(generated.get(kind,0))+1
	if kind in QUIET_EFFECTS:return
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
	# 피해량 표시 off: damage numbers go, heals still show.
	if not GameSettings.damage_numbers and kind!="heal":return
	for n in numbers:
		if n.actor==actor and n.kind==kind and float(n.age)<.12:n.value+=value;return
	if numbers.size()>=MAX_NUMBERS:numbers.pop_front()
	numbers.append({"kind":kind,"point":point,"value":value,"color":color,"actor":actor,"age":0.0})
func _explosion_once(key: int,point: Vector2,radius: float) -> void:
	if explosive_seen.has(key):return
	if explosive_seen.size()>=256:explosive_seen.erase(explosive_seen.keys()[0])
	explosive_seen[key]=true;add_effect("explosion",point,Color("ffbc75"),radius,.48)
	# A real blast: a billowing fireball that rolls up into smoke, a pressure ring, debris and
	# embers thrown out, and a scorch mark left on the ground.
	add_effect("fireball",point,Color("ff8a3d"),radius,1.1,randf()*TAU)
	add_effect("scorch",point,Color("2a1a12"),radius*.62,3.2,randf()*TAU)
	if use_shader_fx:shader_fx.shock(point,radius*1.1,.55,Color("ffb057"))
	particles.burst(point,Color("4a3326"),int(10+radius/12),radius*3.4,0,"shard",true)
	particles.burst(point,Color("ffb347"),int(12+radius/10),radius*3.0,0,"ember",true)
	particles.burst(point,Color("5a4a42"),int(6+radius/20),radius*.9,-PI*.5,"smoke",true)
	camera.impact(minf(14,4+radius/16),point)
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
	if out.status!=&"":
		if out.hp_damage>0:number("status",target.position,out.hp_damage,STATUS_COLORS.get(out.status,Color.WHITE),target.battle_id)
		if out.status==&"chain_shock" and out.hp_damage>0:flashes[target.battle_id]=.1
		match out.status:
			&"burn":particles.burst(target.position,Color("ff9a52"),3,90,-PI/2,"flame",false)
			&"poison":particles.burst(target.position,Color("2f6b2a"),3,40,0,"plume",false);particles.burst(target.position,Color("8fe36b"),3,80,-PI/2,"mote",false)
			&"erosion":particles.burst(target.position,Color("a777ff"),7,200,0,"shard",true);particles.burst(target.position,Color("2a1840"),3,40,0,"plume",false)
			&"frostbite":particles.burst(target.position,Color("d9f4ff"),7,200,0,"shard",true)
		return
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
	if u.original_team==1:camera.focus(u.position,.5)
	# The final-kill close-up only for the kill that decides the battle: with three or more
	# teams, wiping out one team (even team 1) leaves the others still fighting.
	var left: Dictionary={}
	for v in battle.units:
		if v.alive:left[v.original_team]=true
	var multi: bool=battle.custom_mode or not battle.team_colors.is_empty()
	if left.size()<=1 and (u.original_team==1 or multi) and not left.has(u.original_team):add_effect("final_kill",u.position,ArenaUI.GOLD,150,1);camera.impact(9,u.position);impact_pause(80);camera.finish(u.position)
func _count_kill(victim,source) -> void:
	kill_streaks.erase(victim.actor_id())
	if source==null or not source.alive:return
	# 슬라임: only the last slime of a family counts toward a kill streak.
	if victim.data.type_id==35 and battle.units.any(func(v):return v!=victim and v.alive and v.data.type_id==35 and v.team==victim.team and str(v.character_specific_state.get("slimeFamily",""))==str(victim.character_specific_state.get("slimeFamily",""))):return
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
	# The live bar overlay stands down for the ending (the frozen units carry their own bars).
	if is_instance_valid(bar_overlay):bar_overlay.queue_redraw()
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
	if is_instance_valid(shader_fx):shader_fx.clear()
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
		if is_instance_valid(shader_fx):shader_fx.clear()
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
			if kind=="chain_shock":
				var to: Vector2=CharacterPersistence.vector(e.metadata.get("to",{}),e.point)
				add_effect("chain_shock",e.point,Color("bfe9ff"),20,.34);effects[-1]["to"]=to
				if use_shader_fx:shader_fx.bolt(e.point,to)
				particles.burst(to,Color("bfe9ff"),14,280,(to-e.point).angle(),"spark",true);particles.burst(to,Color.WHITE,5,150,0,"spark",true)
				for k in range(3):particles.burst(e.point.lerp(to,(k+1)/4.0),Color("9fdcff"),3,110,0,"spark",false)
			elif kind in ["light_pop","dark_pop","shock_stun","light_mark","dark_mark"]:
				var light: bool=kind.begins_with("light")
				add_effect(kind,e.point,Color("ffe9a0") if light else Color("9fdcff") if kind=="shock_stun" else Color("b48cff"),48 if kind.ends_with("pop") else 34,.55)
				match kind:
					"light_pop":particles.burst(e.point,Color("ffe59a"),18,220,0,"heal",true);particles.burst(e.point,Color.WHITE,8,260,0,"spark",true)
					"dark_pop":particles.burst(e.point,Color("a777ff"),16,260,0,"shard",true);particles.burst(e.point,Color("3a1f63"),8,60,0,"plume",true)
					"shock_stun":particles.burst(e.point,Color("bfe9ff"),20,300,0,"spark",true)
					"light_mark":particles.burst(e.point,Color("ffe59a"),8,90,0,"mote",false)
					"dark_mark":particles.burst(e.point,Color("6b3fb0"),6,50,0,"plume",false)
			if kind in ["light_orbs","light_pop","dark_pop"]:
				for id in e.metadata.get("to",[]):_orb(e.point,str(id),kind)
			match kind:
				"hero_call":
					add_effect("hero_call",e.point,Color("ffd27a"),70,.6)
					particles.burst(e.point,Color("ffe59a"),16,220,0,"spark",true)
				"hero_rescue":
					# Landing: triple shockwave, ground cracks, a ring of dust smoke, heavy shake.
					add_effect("hero_shock",e.point,Color("ffd27a"),240,1.0)
					if use_shader_fx:shader_fx.shock(e.point,220,.85,Color("ffcf6e"))
					particles.burst(e.point,Color("6b5a4a"),26,320,0,"smoke",true);particles.burst(e.point,Color("c8a77c"),22,420,0,"shard",true)
					particles.burst(e.point,Color("ffe59a"),20,380,0,"spark",true)
					impact_pause(120);camera.impact(16,e.point);camera.focus(e.point)
				"slime_slam":
					add_effect("slime_ring",e.point,Color("9be36f"),float(e.metadata.get("radius",58))*1.3,.4)
					particles.burst(e.point,Color("8fd86b"),12,240,0,"shard",true);camera.impact(4,e.point)
				"slime_land":
					add_effect("slime_ring",e.point,Color("b6f08a"),float(e.metadata.get("radius",92))*1.4,.55)
					particles.burst(e.point,Color("8fd86b"),18,320,0,"shard",true);particles.burst(e.point,Color("6b5a4a"),8,90,0,"smoke",true)
					camera.impact(7,e.point)
				"slime_split","unit_spawned":
					particles.burst(e.point,Color("a6ec7c"),16,260,0,"shard",true);add_effect("slime_ring",e.point,Color("c4f2a8"),46,.45)
				"griffin_gust":
					var angle: float=float(e.metadata.get("angle",0))
					add_effect("griffin_gust",e.point,Color("c8f7e6"),float(e.metadata.get("radius",270)),.6,angle);effects[-1]["cone"]=float(e.metadata.get("cone",.6))
					particles.burst(e.point+Vector2.from_angle(angle)*60,Color("e8fff6"),24,520,angle,"spark",true)
					camera.impact(9,e.point)
				"griffin_storm":
					particles.burst(e.point,Color("c8f7e6"),14,220,0,"spark",false);particles.burst(e.point,Color("9fb9ae"),6,60,0,"smoke",false)
				"targeted":
					add_effect("targeted",e.point,Color("ff6a5a"),40,.5)
				"charmed":
					add_effect("targeted",e.point,Color("ff6fb0"),36,.5)
					particles.burst(e.point,Color("ff8cc4"),12,180,0,"spark",true)
				"whisper_burst":
					add_effect("slime_ring",e.point,Color("b78cff"),56,.45)
					particles.burst(e.point,Color("8a5cd6"),14,220,0,"shard",true);particles.burst(e.point,Color("2b1f3d"),6,70,0,"smoke",true)
				"plague_fog":
					# The whole field sinks under green-violet plague fog.
					add_effect("plague_fog",e.point,Color("6a4a8f"),1150,float(e.metadata.get("time",5)))
					add_effect("plague_slam",e.point,Color("9b7bd6"),140,.7)
					if use_shader_fx:shader_fx.shock(e.point,160,.7,Color("8a6bc6"))
					particles.burst(e.point,Color("3a2a55"),30,420,0,"smoke",true);particles.burst(e.point,Color("7fa35a"),18,320,0,"smoke",true)
					particles.burst(e.point,Color("c9a6ff"),16,360,0,"spark",true)
					impact_pause(70);camera.impact(9,e.point)
				"plague_bonus":
					particles.burst(e.point,Color("9fd36a"),8,160,0,"spark",true)
				"golem_slam":
					var sr: float=float(e.metadata.get("radius",80))
					add_effect("slime_ring",e.point,Color("bfe9ff"),sr*1.3,.4)
					add_effect("ice_spikes",e.point,Color("cfeeff"),sr,.7,float(Time.get_ticks_msec()%628)/100.0);effects[-1]["count"]=9
					particles.burst(e.point,Color("e8f8ff"),18,280,0,"shard",true);particles.burst(e.point,Color("9fb7c4"),8,90,0,"smoke",true);camera.impact(6,e.point)
				"golem_aura":
					add_effect("slime_ring",e.point,Color("cfeeff"),float(e.metadata.get("radius",120)),.6)
					particles.burst(e.point,Color("eaf8ff"),8,90,0,"spark",false)
				"golem_blast":
					var br: float=float(e.metadata.get("radius",170))
					add_effect("hero_shock",e.point,Color("bfe9ff"),br*1.2,.9)
					add_effect("ice_spikes",e.point,Color("cfeeff"),br,1.1,0.0);effects[-1]["count"]=22
					add_effect("slime_ring",e.point,Color("e8f8ff"),br*1.5,.8)
					if use_shader_fx:shader_fx.shock(e.point,br,.8,Color("bfe9ff"))
					particles.burst(e.point,Color("e8f8ff"),40,480,0,"shard",true);particles.burst(e.point,Color("cfe6f2"),24,180,0,"smoke",true);particles.burst(e.point,Color("ffffff"),20,360,0,"spark",true)
					impact_pause(110);camera.impact(14,e.point)
				"flame_slash":
					add_effect("flame_arc",e.point,Color("ff8a3d"),70,.32,float(e.metadata.get("angle",0)))
					particles.burst(e.point,Color("ffb347"),10,220,float(e.metadata.get("angle",0)),"spark",true)
				"flame_charge":
					# Winding up: the blade drawn back, flames licking along it.
					add_effect("flame_windup",e.point,Color("ff9a4a"),70,float(e.metadata.get("time",.5)))
				"flame_whirl":
					# The sword spins twice, leaving a huge circular fire slash.
					var fr: float=float(e.metadata.get("radius",135))
					add_effect("blade_whirl",e.point,Color("ff6a2a"),fr,.75,float(e.metadata.get("angle",0)))
					for spark in range(12):
						var sa: float=spark*TAU/12
						particles.burst(e.point+Vector2.from_angle(sa)*fr*.9,Color("ffb347"),4,260,sa+PI/2,"spark",true)
					camera.impact(7,e.point)
				"ignite":
					add_effect("slime_ring",e.point,Color("ff8a3d"),26+2*float(e.metadata.get("stacks",1)),.35)
					particles.burst(e.point,Color("ffb347"),8+int(e.metadata.get("stacks",1)),260,0,"spark",true)
				"top_bounce":
					# The top ricochets: a puff of wind and sparks where it struck the wall or a unit.
					add_effect("slime_ring",e.point,Color("c8f7e6"),26,.3)
					particles.burst(e.point,Color("e8fff6"),6,220,0,"spark",true)
				"top_hit":
					var ta: float=float(e.metadata.get("angle",0));var boosted: bool=bool(e.metadata.get("boost",false))
					add_effect("griffin_gust",e.point-Vector2.from_angle(ta)*20,Color("c8f7e6"),70 if boosted else 52,.3,ta);effects[-1]["cone"]=.7
					particles.burst(e.point,Color("ffb070") if boosted else Color("e8fff6"),10 if boosted else 7,280,ta,"spark",true)
					if boosted:camera.impact(4,e.point)
				"top_boost":
					# 폭주 회전: a red-hot whirlwind flares round the top.
					add_effect("hero_shock",e.point,Color("ff8a4a"),110,.6)
					add_effect("slime_ring",e.point,Color("ffd0a0"),90,.5)
					particles.burst(e.point,Color("ff9a4a"),24,360,0,"spark",true);particles.burst(e.point,Color("e8fff6"),16,260,0,"smoke",true)
					camera.impact(7,e.point)
				"bounty_marked":
					add_effect("targeted",e.point,Color("ffcf6e"),42,.8)
					particles.burst(e.point,Color("ffd65c"),10,160,-PI*.5,"spark",true)
				"bounty_paid":
					# Bounty collected: gold coins burst from the fallen target and a "+100 G" rises.
					particles.burst(e.point,Color("ffd65c"),26,320,-PI*.5,"shard",true);particles.burst(e.point,Color("fff3c4"),12,200,-PI*.5,"spark",true)
					add_effect("star_burst",e.point,Color("ffd65c"),90,.8)
					add_effect("gift_text",e.point,Color("ffd65c"),0,1.6);effects[-1]["text"]="현상금 +%d G"%int(e.metadata.get("gold",100))
				"deagle_shot":
					# Muzzle flash, smoke and a spent casing flicked aside.
					var ma: float=float(e.metadata.get("angle",0))
					add_effect("muzzle_flash",e.point,Color("ffcf6e"),34,.12,ma)
					particles.burst(e.point,Color("fff3c4"),8,260,ma,"spark",true);particles.burst(e.point,Color("8a8478"),5,70,ma,"smoke",true)
					particles.burst(e.point-Vector2.from_angle(ma)*26,Color("e8c46a"),1,180,ma-PI*.5,"shard",true)
					camera.impact(2.5,e.point)
				"deagle_reload":
					add_effect("gift_text",e.point,Color("d9a45a"),0,.8);effects[-1]["text"]="장전"
				"bounty_shot":
					# 현상금 집행: an instant shot straight to each marked target, which is chained in place.
					var to: Vector2=CharacterPersistence.vector(e.metadata.get("to",{}),e.point)
					add_effect("bounty_tracer",e.point,Color("ffcf6e"),0,.45);effects[-1]["to"]=to
					add_effect("star_burst",to,Color("ffd65c"),70,.6)
					add_effect("gift_mark",to,Color("b8c2d6"),40,1.6);effects[-1]["mark"]="root"
					particles.burst(to,Color("fff3c4"),18,340,(to-e.point).angle(),"spark",true);particles.burst(e.point,Color("ffcf6e"),10,260,(to-e.point).angle(),"spark",true)
					impact_pause(60);camera.impact(9,to)
				"snow_club":
					# The ice club lands: frost chips and a cold ring.
					var ca: float=float(e.metadata.get("angle",0))
					add_effect("slime_ring",e.point,Color("cfeeff"),34,.35)
					particles.burst(e.point,Color("e8f8ff"),10,260,ca,"shard",true);particles.burst(e.point,Color("9fd8f0"),6,180,ca,"spark",true)
				"santa_shove":
					# A red-and-white candy-cane swing with a puff of gold dust.
					add_effect("candy_arc",e.point,Color("e8525a"),54,.32,float(e.metadata.get("angle",0)))
					particles.burst(e.point,Color("ffd65c"),8,220,float(e.metadata.get("angle",0)),"spark",true);particles.burst(e.point,Color("ffffff"),4,120,0,"smoke",true)
				"snow_charge":
					# The snowman gathers itself: a blizzard spirals in and a snowball forms in front of it.
					add_effect("snow_gather",e.point,Color("e8f6ff"),110,float(e.metadata.get("time",.8)),float(e.metadata.get("angle",0)))
					add_effect("frost_patch",e.point,Color("cfeeff"),80,float(e.metadata.get("time",.8))+.6)
					particles.burst(e.point,Color("ffffff"),14,160,0,"smoke",true)
				"snowball_burst":
					# The giant snowball bursts against the wall: a dome of snow, flying chunks and a frozen crater.
					var sb: float=float(e.metadata.get("radius",115))
					add_effect("hero_shock",e.point,Color("dff4ff"),sb*1.3,.85)
					add_effect("snow_dome",e.point,Color("ffffff"),sb*1.5,1.1)
					add_effect("slime_ring",e.point,Color("ffffff"),sb*1.6,.8)
					add_effect("ice_spikes",e.point,Color("cfeeff"),sb,1.1,0.0);effects[-1]["count"]=22
					add_effect("frost_patch",e.point,Color("cfeeff"),sb*1.1,2.6)
					if use_shader_fx:shader_fx.shock(e.point,sb*1.2,.8,Color("dff4ff"))
					particles.burst(e.point,Color("ffffff"),48,560,0,"shard",true);particles.burst(e.point,Color("e6f2fa"),34,240,0,"smoke",true)
					particles.burst(e.point,Color("bfe6ff"),22,380,0,"spark",true);particles.burst(e.point,Color("f4fbff"),16,120,-PI*.5,"mote",true)
					impact_pause(110);camera.impact(15,e.point)
				"santa_away":
					# Santa vanishes in a burst of gold stars; snow starts to fall over the whole field, the
					# sleigh's shadow flies across with a trail of stardust and a gift drops on everyone.
					particles.burst(e.point,Color("ffffff"),26,300,0,"smoke",true);particles.burst(e.point,Color("e8525a"),16,280,0,"spark",true)
					particles.burst(e.point,Color("ffd65c"),24,360,0,"spark",true);particles.burst(e.point,Color("fff3c4"),12,160,-PI*.5,"mote",true)
					add_effect("star_burst",e.point,Color("ffd65c"),120,.9)
					add_effect("slime_ring",e.point,Color("ffd0d4"),70,.55)
					if use_shader_fx:shader_fx.shock(e.point,140,.6,Color("ffd65c"))
					camera.impact(8,e.point)
					# Both follow Santa's own clock so they stay in step with the gifts actually landing.
					var away: float=float(e.metadata.get("time",3.2));var santa_id: int=int(e.metadata.get("actor_id",0))
					add_effect("santa_snowfall",e.point,Color.WHITE,0,away+1);effects[-1]["santa"]=santa_id;effects[-1]["away"]=away
					add_effect("santa_sleigh",e.point,Color("1a1426"),0,away+1);effects[-1]["santa"]=santa_id;effects[-1]["away"]=away
					for gift in e.metadata.get("gifts",[]):
						add_effect("gift_fall",e.point,Color("4fbf6a") if bool(gift.get("ally",false)) else Color("d8404a"),20,away+1)
						effects[-1]["target"]=int(gift.get("to",0));effects[-1]["santa"]=santa_id;effects[-1]["at"]=float(gift.get("at",1))
				"santa_gift":
					# The gift lands and bursts open: a light pillar, confetti, the lid flying off and a
					# mark for what was inside.
					var ally_gift: bool=bool(e.metadata.get("ally",false));var gk: String=String(e.metadata.get("kind",""))
					var gc: Color=Color("6fe08a") if ally_gift else Color("ff6a6a")
					add_effect("gift_pillar",e.point,gc,46,.8)
					add_effect("gift_open",e.point,Color("4fbf6a") if ally_gift else Color("d8404a"),22,.7,randf_range(-.6,.6))
					add_effect("gift_mark",e.point,gc,40,1.2);effects[-1]["mark"]=gk
					add_effect("slime_ring",e.point,gc.lightened(.3),52,.5)
					for confetti in [Color("e8525a"),Color("4fbf6a"),Color("ffd65c"),Color("ffffff")]:particles.burst(e.point+Vector2(0,-10),confetti,6,300,-PI*.5,"shard",true)
					match gk:
						"heal20","heal30":particles.burst(e.point,Color("86e3a4"),16,160,-PI*.5,"heal",true)
						"ult_full","ult_half":particles.burst(e.point,Color("9fd8ff"),14,220,-PI*.5,"mote",true);particles.burst(e.point,Color("ffd65c"),10,200,-PI*.5,"spark",true)
						"power":particles.burst(e.point,Color("ff9a4a"),14,240,-PI*.5,"ember",true)
						"mid","high":
							add_effect("ice_spikes",e.point,Color("cfeeff"),40 if gk=="mid" else 58,.8,0.0);effects[-1]["count"]=8 if gk=="mid" else 12
							particles.burst(e.point,Color("e8f8ff"),14 if gk=="mid" else 24,320,0,"shard",true)
							if gk=="high":camera.impact(6,e.point)
						"weak":particles.burst(e.point,Color("b48cff"),12,140,PI*.5,"plume",true)
						"drain":particles.burst(e.point,Color("6b7ab0"),12,180,0,"smoke",true)
					add_effect("gift_text",e.point,gc,0,1.4);effects[-1]["text"]=GIFT_LABELS.get(gk,"선물")
				"santa_back":
					# Santa drops back in with a ring of gold stars and a puff of snow.
					particles.burst(e.point,Color("ffffff"),24,260,0,"smoke",true);particles.burst(e.point,Color("ffd65c"),20,300,0,"spark",true)
					add_effect("star_burst",e.point,Color("ffd65c"),100,.8)
					add_effect("slime_ring",e.point,Color("ffd0d4"),70,.5);camera.impact(6,e.point)
				"parrot_mimic":
					# Feathers burst off the parrot; a thin streak links it to the enemy it copies.
					particles.burst(e.point,Color("8fd47a"),16,260,0,"shard",true);particles.burst(e.point,Color("ffd65c"),10,200,0,"spark",true)
					add_effect("slime_ring",e.point,Color("c9f5a0"),60,.5)
				"hero_grab":
					add_effect("hero_grab",e.point,Color("ffd27a"),46,.4)
					particles.burst(e.point,Color("fff1c4"),10,200,0,"spark",true);camera.impact(5,e.point)
				"hero_punch":
					var angle: float=float(e.metadata.get("angle",0))
					add_effect("hero_punch",e.point,Color("ffb347"),280,.9,angle)
					if use_shader_fx:shader_fx.shock(e.point,240,.75,Color("ffab45"),angle,.85)
					particles.burst(e.point,Color("ffe1a0"),30,560,angle,"spark",true);particles.burst(e.point,Color("6b5a4a"),18,280,angle,"smoke",true)
					particles.burst(e.point,Color("c8a77c"),16,460,angle,"shard",true)
					impact_pause(150);camera.impact(18,e.point);camera.focus(e.point)
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
	_status_emitters(delta);_advance_orbs(delta)
	var rows: Array=[]
	for unit in battle.units:
		if unit.alive:rows.append({"position":unit.position,"velocity":unit.velocity,"scale":unit.combat_scale()})
	camera.set_framing(rows)
	var ending: bool=battle.finished and end_age<1.55 and camera.finale_remaining>0
	if battle.clock.state==BattleClock.State.TURNING_SLOWDOWN and not battle.finished:camera.advance_overview(ui_delta,2.0,ArenaCameraController.TURNING_ZOOM)
	else:camera.advance(ui_delta,(battle.clock.state!=BattleClock.State.NORMAL or battle.finished) and not ending,ArenaCameraController.TURNING_ZOOM if battle.clock.state==BattleClock.State.TURNING_PAUSED else 1.0)
	queue_redraw()
	if is_instance_valid(glow_layer):glow_layer.queue_redraw()
	if is_instance_valid(bar_overlay):bar_overlay.queue_redraw()
	if is_instance_valid(field_layer) and board!=null:
		var rect: Rect2=board.board_rect()
		var at:=Transform2D(0,Vector2.ONE*rect.size.x/800,0,rect.position)*camera.transform()
		field_layer.sync(battle.zones.entries,at,real_age)
		if is_instance_valid(shader_fx):
			if use_shader_fx:shader_fx.advance(delta);shader_fx.sync(battle,at,real_age)
			else:shader_fx.clear()
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
	if is_instance_valid(shader_fx):shader_fx.align(parent_transform)
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
		elif z.kind=="oilFire":_oil_fire(z)
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
		if u.alive and u.character_specific_state.has("snowball"):_draw_snowball(u)
	particles.draw(self)
	_draw_orbs()
	for e in effects:
		if e.kind=="ultimate":
			var caster: BattleUnit=battle.find_actor(String(e.get("actor","")))
			if caster!=null:AbilityMotifs.draw(self,caster,e.point,real_age,float(e.age)/float(e.life))
		var t: float=float(e.age)/float(e.life);var c: Color=Color(e.color,1-t);var radius: float=float(e.radius)*(.25+t)
		if e.kind=="death":
			VfxArt.effect(self,e)
			UnitIcon.draw(self,Rect2(e.point-Vector2(26,26)*float(e.get("scale",1))+Vector2(0,t*12),Vector2(52,52)*float(e.get("scale",1))),int(e.get("type",0)),1-t)
			for i in range(5):draw_line(e.point+Vector2(-25,-20+i*10),e.point+Vector2(25+t*30,-20+i*10),Color(e.color,.5*(1-t)),2)
		elif e.kind=="hero_shock":
			for k in range(0 if use_shader_fx else 3):
				var tk: float=clampf((t-k*.13)/(1-k*.13),0,1);var r: float=e.radius*(1-pow(1-tk,3))*(1-k*.18)
				if tk>0 and tk<1:draw_arc(e.point,r,0,TAU,64,Color(Color(e.color).lightened(.3*k),(1-tk)*.9),12*(1-tk)+1.5,true)
			VfxArt.glow(self,e.point,e.radius*.55,e.color,.65*pow(1-t,2))
			draw_circle(e.point,e.radius*.18*(1-t),Color(1,1,1,.8*(1-t)))
			for i in range(10):
				var v:=Vector2.from_angle(i*TAU/10+.3);var reach: float=e.radius*.42*minf(1,t*5)
				draw_line(e.point+v*18,e.point+v*reach+v.orthogonal()*sin(i*2.3)*10,Color("4a3b2e",.75*(1-t)),3*(1-t)+1,true)
		elif e.kind=="plague_fog":
			# Dark, eerie fog rolls out from the staff and swallows the map within 0.6 s, then churns.
			var age: float=float(e.age);var spread: float=1-pow(1-clampf(age/.6,0,1),3)
			var fade: float=clampf((1-t)/.12,0,1);var reach: float=e.radius*spread
			draw_circle(e.point,reach,Color(.13,.08,.2,.42*fade))
			for i in range(28):
				# The rolling front: fog banks along the edge of the spreading circle.
				var a: float=i*TAU/28+age*.4;var q: Vector2=e.point+Vector2.from_angle(a)*reach*(.92+.06*sin(age*3+i))
				VfxArt.glow(self,q,70+20*sin(age*2+i),Color("4a3070") if i%2==0 else Color("5f7a45"),.5*fade*(1-spread*.5))
			for i in range(18):
				var seed_x: float=fmod(i*137.5,800.0);var seed_y: float=fmod(i*283.1+90,800.0)
				var q: Vector2=Vector2(seed_x+sin(age*.5+i)*70,seed_y+cos(age*.4+i*1.7)*60)
				if q.distance_to(e.point)>reach:continue
				VfxArt.glow(self,q,110+40*sin(age*1.3+i),Color("6a4a8f") if i%3!=0 else Color("6f9a52"),.38*fade)
			for i in range(40):
				# Floating spores drifting upward through the fog.
				var q: Vector2=Vector2(fmod(i*97.3+age*12,800.0),fmod(i*211.7-age*(18+i%5*4),800.0)+(800 if fmod(i*211.7-age*(18+i%5*4),800.0)<0 else 0))
				if q.distance_to(e.point)>reach:continue
				draw_circle(q,1.8+i%3,Color("c9a6ff",.55*fade) if i%2==0 else Color("b6e08a",.45*fade))
		elif e.kind=="plague_slam":
			# The staff strikes: a dark rune ring and cracks.
			var rr: float=e.radius*(1-pow(1-t,3))
			draw_arc(e.point,rr,0,TAU,48,Color(e.color,.9*(1-t)),5*(1-t)+1.5,true)
			draw_arc(e.point,rr*.62,0,TAU,40,Color("5f7a45",.7*(1-t)),3,true)
			for i in range(8):
				var d:=Vector2.from_angle(i*TAU/8+.2);draw_line(e.point+d*rr*.2,e.point+d*rr*(.75+.15*sin(i*2.3)),Color("2a1a3d",.8*(1-t)),3,true)
		elif e.kind=="ice_spikes":
			# Ice spikes burst up in a ring and sink back.
			var grow: float=sin(clampf(t*1.6,0,1)*PI*.5)*(1-clampf((t-.6)/.4,0,1))
			for i in range(int(e.get("count",10))):
				var a: float=i*TAU/float(e.get("count",10))+float(e.angle)
				var base: Vector2=e.point+Vector2.from_angle(a)*e.radius*(.45+.5*fmod(i*.618,1.0))
				var h: float=(18+14*fmod(i*.37,1.0))*grow;var w:=Vector2.from_angle(a).orthogonal()*6
				draw_colored_polygon(PackedVector2Array([base-w,base+w,base+Vector2(0,-h)]),Color("cfeeff",.9))
				draw_line(base,base+Vector2(0,-h),Color("ffffff",.8),1.2,true)
		elif e.kind=="flame_arc":
			# A burning crescent swept in front of the swordsman.
			var a0: float=float(e.angle);var sweep: float=-1.1+2.2*clampf(t*1.6,0,1)
			draw_arc(e.point,e.radius*.8,a0-1.1,a0+sweep,24,Color(e.color,(1-t)),14*(1-t)+2,true)
			draw_arc(e.point,e.radius*.8,a0-.6,a0+sweep,18,Color("fff1c4",(1-t)*.9),5*(1-t)+1,true)
		elif e.kind=="flame_windup":
			# The blade held back and burning brighter.
			var a: float=float(e.angle)+PI*.75;var tip: Vector2=e.point+Vector2.from_angle(a)*e.radius
			VfxArt.glow(self,tip,20+26*t,Color("ff8a3d"),.4+.4*t)
			draw_line(e.point+Vector2.from_angle(a)*12,tip,Color("ffe9c8"),3+2*t,true)
			for k in range(4):
				var q: Vector2=e.point+Vector2.from_angle(a)*e.radius*(.3+.2*k)+Vector2(0,-6-10*fmod(float(e.age)*3+k*.25,1.0))
				draw_circle(q,3+2*t,Color("ffb347",.7))
		elif e.kind=="blade_whirl":
			# Two fast turns of the sword: a burning crescent sweeps round with a fading trail, the
			# blade itself drawn along the leading edge, and the full circle lingers as it fades.
			var head: float=float(e.angle)+(1-pow(1-t,2))*TAU*2
			var r: float=e.radius*(.9+.12*t);var fade: float=1-pow(t,2.5)
			if t>.35:draw_arc(e.point,r,0,TAU,72,Color(e.color,.35*fade),10*fade+2,true)
			for k in range(14):
				var a1: float=head-k*.2;var w: float=(22-k*1.3)*fade+2
				draw_arc(e.point,r,a1-.22,a1,6,Color(e.color,(1-k/14.0)*fade),w,true)
			draw_arc(e.point,r,head-1.1,head,16,Color("fff4d0",fade),6*fade+1,true)
			draw_arc(e.point,r*.64,head-1.6,head,18,Color("ffcf6e",.55*fade),4,true)
			var dir:=Vector2.from_angle(head)
			draw_line(e.point+dir*14,e.point+dir*r*.95,Color("fff1e0",fade),5,true)
			draw_line(e.point+dir*14,e.point+dir*r*.95,Color("ff9a4a",.8*fade),2,true)
			VfxArt.glow(self,e.point+dir*r,26,Color("ffb347"),.7*fade)
		elif e.kind=="flame_gather":
			# Flames spiral in while the swordsman gathers power.
			for i in range(6):
				var a: float=float(e.age)*6+i*TAU/6;var rr: float=e.radius*(1-t)
				draw_arc(e.point,rr,a,a+.9,10,Color(e.color,.5+.5*t),3+4*t,true)
			VfxArt.glow(self,e.point,40+60*t,Color("ff8a3d"),.3+.4*t)
		elif e.kind=="flame_ring":
			# The circular cut: a full ring of fire racing outward with a bright edge.
			var rr: float=e.radius*(1-pow(1-clampf(t*1.5,0,1),3))
			draw_arc(e.point,rr,0,TAU,64,Color(e.color,(1-t)),22*(1-t)+2,true)
			draw_arc(e.point,rr,0,TAU,64,Color("fff1c4",(1-t)*.9),6*(1-t)+1,true)
			for i in range(16):
				var a: float=i*TAU/16+float(e.age)*2;var q: Vector2=e.point+Vector2.from_angle(a)*rr
				VfxArt.glow(self,q,18*(1-t)+4,Color("ff9a4a"),.6*(1-t))
		elif e.kind=="snow_gather":
			# A blizzard spirals in toward the snowman while a snowball packs itself in front of it.
			var spin: float=float(e.age)*7
			for i in range(26):
				var a: float=spin*(1+fmod(i*.37,.6))+i*TAU/26;var rr: float=e.radius*(1.25-t)*(.55+.45*fmod(i*.618,1.0))
				var q: Vector2=e.point+Vector2.from_angle(a)*rr
				draw_line(q,q+Vector2.from_angle(a+1.9)*(6+10*t),Color("ffffff",.35+.5*t),2,true);draw_circle(q,2+1.5*t,Color("ffffff",.6+.4*t))
			draw_arc(e.point,e.radius*(1-t*.55),spin*.3,spin*.3+TAU*.8,48,Color(e.color,.25+.5*t),2+4*t,true)
			VfxArt.glow(self,e.point,40+60*t,Color("dff4ff"),.25+.45*t)
			var front: Vector2=e.point+Vector2.from_angle(float(e.angle))*54;var br: float=8+26*t
			draw_circle(front+Vector2(0,br*.5),br,Color(0,0,0,.15));draw_circle(front,br,Color("f4fbff"));draw_arc(front,br,0,TAU,24,Color("9fc3dc"),2,true)
			draw_circle(front+Vector2(-br*.3,-br*.3),br*.45,Color("ffffff"))
		elif e.kind=="fireball":
			# Billowing lobes of fire that swell fast, then cool to dark smoke as they rise.
			var grow: float=1-pow(1-clampf(t*2.4,0,1),3);var r: float=e.radius*grow;var lift: float=-e.radius*.55*t*t
			var heat: float=clampf(1-t*1.4,0,1);var fade: float=clampf((1-t)*2.2,0,1)
			for i in range(14):
				var a: float=float(e.angle)+i*2.399;var d: float=r*(.3+.28*fmod(i*.618,1.0))
				var q: Vector2=e.point+Vector2.from_angle(a)*d+Vector2(0,lift*(.6+.4*fmod(i*.37,1.0)))
				var lobe: float=r*(.34+.1*sin(i*2.7))*(1-t*.35)
				var smoke: float=clampf(t*1.5-.25,0,1);var col: Color=Color("ff6a1f").lerp(Color("4a3e38"),smoke)
				draw_circle(q,lobe,Color(col,(.85-.4*smoke)*fade))
				if heat>0:draw_circle(q+Vector2(0,-lobe*.15),lobe*.55,Color(Color("ffd36b"),.8*heat))
			if heat>0:
				draw_circle(e.point+Vector2(0,lift*.4),r*.42*heat,Color("fff4d6",.95*heat))
				VfxArt.glow(self,e.point,e.radius*1.2,Color("ff8a3d"),.7*heat)
		elif e.kind=="scorch":
			# A blackened crater with glowing embers that cool and fade.
			var fade: float=clampf((1-t)*3,0,1);var cool: float=clampf(1-t*2.5,0,1)
			for i in range(9):
				var a: float=float(e.angle)+i*TAU/9;var q: Vector2=e.point+Vector2.from_angle(a)*e.radius*(.35+.25*fmod(i*.618,1.0))
				draw_circle(q,e.radius*(.3+.12*fmod(i*.37,1.0)),Color(e.color,.35*fade))
			draw_circle(e.point,e.radius*.55,Color(e.color,.45*fade))
			for i in range(7):
				var q: Vector2=e.point+Vector2.from_angle(float(e.angle)*2+i*2.1)*e.radius*(.2+.5*fmod(i*.53,1.0))
				draw_circle(q,2.2,Color(Color("ff9a4a"),.9*cool*(.5+.5*sin(real_age*9+i))))
		elif e.kind=="bounty_tracer":
			# A straight hot tracer from the hunter to its target.
			var to: Vector2=e.get("to",e.point);var w: float=10*(1-t)+1.5
			draw_line(e.point,to,Color("ffcf6e",.55*(1-t)),w*2,true);draw_line(e.point,to,Color("fff6dc",1-t),w*.6,true)
			VfxArt.glow(self,to,26,Color("ffcf6e"),.6*(1-t))
		elif e.kind=="muzzle_flash":
			# A short star-shaped flash at the muzzle.
			var md:=Vector2.from_angle(float(e.angle))
			VfxArt.glow(self,e.point,e.radius*(1-t),Color("ffcf6e"),.8*(1-t))
			draw_colored_polygon(PackedVector2Array([e.point-md.orthogonal()*7,e.point+md*e.radius*(1.2-t),e.point+md.orthogonal()*7]),Color("fff3c4",1-t))
		elif e.kind=="frost_patch":
			# A frozen patch of ground: pale ice with crystal cracks, fading at the end.
			var fade: float=clampf(minf(t*4,(1-t)*3),0,1)
			draw_circle(e.point,e.radius,Color("dff4ff",.18*fade))
			for i in range(10):
				var d: Vector2=Vector2.from_angle(i*TAU/10+.4);var len: float=e.radius*(.55+.35*fmod(i*.618,1.0))
				draw_line(e.point+d*e.radius*.15,e.point+d*len,Color("ffffff",.55*fade),2,true)
				draw_line(e.point+d*len*.6,e.point+d*len*.6+d.rotated(.7)*len*.25,Color("cfeeff",.5*fade),1.5,true)
			draw_arc(e.point,e.radius,0,TAU,48,Color("cfeeff",.4*fade),2,true)
		elif e.kind=="snow_dome":
			# A dome of snow thrown up by the burst: puffs that billow outward and settle.
			var grow: float=1-pow(1-clampf(t*1.8,0,1),3)
			for i in range(18):
				var a: float=i*TAU/18+fmod(i*.53,.3);var rr: float=e.radius*grow*(.55+.4*fmod(i*.618,1.0))
				var q: Vector2=e.point+Vector2.from_angle(a)*rr+Vector2(0,-14*sin(t*PI))
				draw_circle(q,(18+12*fmod(i*.37,1.0))*(1-t*.5),Color("ffffff",.55*(1-t)))
			draw_circle(e.point,e.radius*.45*grow,Color("f4fbff",.5*(1-t)))
		elif e.kind=="candy_arc":
			# Santa's shove: a red-and-white striped crescent.
			var a0: float=float(e.angle);var sweep: float=-1+2*clampf(t*2,0,1)
			for k in range(8):
				var a1: float=a0-1+k*.25
				if a1>a0+sweep:break
				draw_arc(e.point-Vector2.from_angle(a0)*20,e.radius,a1,a1+.25,6,Color("e8525a") if k%2==0 else Color("ffffff"),10*(1-t)+2,true)
		elif e.kind=="star_burst":
			# Gold five-point stars flung outward with a soft glow.
			VfxArt.glow(self,e.point,e.radius*.6,Color("ffd65c"),.5*(1-t))
			for i in range(10):
				var a: float=i*TAU/10+.3;var q: Vector2=e.point+Vector2.from_angle(a)*e.radius*(1-pow(1-t,2))
				_star(q,9*(1-t)+3,float(e.age)*4+i,Color("ffe68a",1-t))
		elif e.kind=="santa_snowfall":
			# Snow drifts down over the whole field while Santa is away, with a warm golden hush.
			var clock: float=_santa_clock(int(e.get("santa",0)))
			if clock<0:continue
			var fade: float=clampf(minf(clock/.4,(float(e.get("away",3.2))-clock)/.4),0,1)
			draw_rect(Rect2(0,0,800,800),Color(1,.86,.55,.06*fade))
			for i in range(90):
				var x: float=fmod(i*97.31+sin(clock*1.3+i)*18,800.0);var y: float=fmod(i*53.7+clock*(60+fmod(i*7.0,50.0)),800.0)
				draw_circle(Vector2(x,y),1.4+fmod(i*.37,1.0)*2.2,Color(1,1,1,(.45+.4*fmod(i*.61,1.0))*fade))
		elif e.kind=="santa_sleigh":
			# The sleigh's shadow flies across the sky trailing gold stardust; its shadow sweeps the
			# ground below. Santa and his sack ride in the sleigh, four reindeer pull it.
			var clock: float=_santa_clock(int(e.get("santa",0)))
			if clock<0:continue
			t=clampf(clock/float(e.get("away",3.2)),0,1)
			var p: Vector2=sleigh_point(t);var z: float=1.9;var vis: float=sin(t*PI)
			var shadow: Color=Color(.09,.06,.15,.72*vis)
			# Ground shadow, far below the sleigh.
			draw_set_transform_matrix(parent_transform*Transform2D(0,Vector2(1,.32),0,p+Vector2(0,150)));draw_circle(Vector2.ZERO,110,Color(0,0,0,.16*vis));draw_set_transform_matrix(parent_transform)
			# Stardust ribbon: a widening, fading trail behind the runners.
			for k in range(28):
				var tk: float=maxf(0,t-k*.009);var q: Vector2=sleigh_point(tk)+Vector2(-62,10)*z
				var wob: float=sin(k*1.3+float(e.age)*9)*6
				VfxArt.glow(self,q+Vector2(0,wob),12+k*.9,Color("ffd65c"),.42*(1-k/28.0)*vis)
				draw_circle(q+Vector2(0,wob),4.4-k*.13,Color("fff3c4",(1-k/28.0)*vis))
				if k%4==0:_star(q+Vector2(0,wob-10),5*(1-k/28.0)+1,float(e.age)*5+k,Color("ffe68a",(1-k/28.0)*vis))
			# Sleigh body with a curled runner, Santa and the sack.
			draw_colored_polygon(PackedVector2Array([p+Vector2(-58,-8)*z,p+Vector2(-18,-8)*z,p+Vector2(-12,10)*z,p+Vector2(-62,10)*z]),shadow)
			draw_line(p+Vector2(-70,15)*z,p+Vector2(-6,15)*z,shadow,5,true);draw_arc(p+Vector2(-4,9)*z,6*z,-PI*.5,PI*.5,10,shadow,5,true)
			draw_circle(p+Vector2(-36,-14)*z,9*z,shadow);draw_circle(p+Vector2(-36,-27)*z,5*z,shadow)
			draw_colored_polygon(PackedVector2Array([p+Vector2(-41,-30)*z,p+Vector2(-31,-30)*z,p+Vector2(-44,-42)*z]),shadow)
			draw_circle(p+Vector2(-54,-13)*z,8*z,shadow)
			draw_line(p+Vector2(-18,0)*z,p+Vector2(84,-6)*z,Color(shadow,shadow.a*.8),2,true)
			for k in range(4):
				var d: Vector2=p+Vector2(22+(k/2)*34,-6+(k%2)*8)*z
				draw_colored_polygon(PackedVector2Array([d+Vector2(-12,-4)*z,d+Vector2(12,-6)*z,d+Vector2(12,2)*z,d+Vector2(-12,3)*z]),shadow)
				draw_line(d+Vector2(12,-5)*z,d+Vector2(18,-14)*z,shadow,3,true)
				draw_line(d+Vector2(18,-14)*z,d+Vector2(14,-21)*z,shadow,2.5,true);draw_line(d+Vector2(18,-14)*z,d+Vector2(24,-20)*z,shadow,2.5,true)
				var leg: float=sin(float(e.age)*16+k*1.7)*5
				draw_line(d+Vector2(-8,2)*z,d+Vector2(-11+leg,11)*z,shadow,2.5,true);draw_line(d+Vector2(8,1)*z,d+Vector2(11-leg,10)*z,shadow,2.5,true)
			# The lead reindeer's glowing red nose.
			var nose: Vector2=p+Vector2(74,-12)*z
			VfxArt.glow(self,nose,16,Color("ff5a5a"),.7*vis);draw_circle(nose,3.5,Color("ff8a8a",vis))
		elif e.kind=="gift_fall":
			# A wrapped gift falls onto its target, glowing, with a streak above and a growing shadow.
			var target: BattleUnit=null
			for v in battle.units:
				if v.battle_id==int(e.get("target",0)):target=v
			var clock: float=_santa_clock(int(e.get("santa",0)))
			if target==null or not target.alive or clock<0 or clock>=float(e.get("at",1)):continue
			var drop: float=clampf((clock/float(e.get("at",1))-.35)/.65,0,1)
			if drop<=0:continue
			var land: Vector2=target.position;var at: Vector2=land+Vector2(sin(clock*5+int(e.get("target",0)))*6*(1-drop),-300*(1-drop*drop))
			draw_set_transform_matrix(parent_transform*Transform2D(0,Vector2(1,.4),0,land+Vector2(0,12)));draw_circle(Vector2.ZERO,8+14*drop,Color(0,0,0,.28*drop));draw_set_transform_matrix(parent_transform)
			draw_arc(land,22*(1.2-drop*.4),0,TAU,32,Color(e.color.lightened(.3),.5*drop),2,true)
			draw_line(at+Vector2(0,-14),at+Vector2(0,-60),Color("fff3c4",.35),5,true)
			VfxArt.glow(self,at,24,e.color.lightened(.3),.45)
			var tilt: float=sin(clock*7+int(e.get("target",0)))*.25*(1-drop)
			draw_set_transform_matrix(parent_transform*Transform2D(tilt,Vector2.ONE,0,at))
			draw_rect(Rect2(Vector2(-12,-10),Vector2(24,21)),e.color);draw_rect(Rect2(Vector2(-12,-10),Vector2(24,21)),Color(0,0,0,.25),false,2)
			draw_rect(Rect2(Vector2(-14,-14),Vector2(28,6)),e.color.lightened(.15))
			draw_rect(Rect2(Vector2(-3,-14),Vector2(6,25)),Color("ffd65c"));draw_rect(Rect2(Vector2(-12,-2),Vector2(24,4)),Color("ffd65c"))
			draw_circle(Vector2(-5,-17),4.5,Color("ffd65c"));draw_circle(Vector2(5,-17),4.5,Color("ffd65c"))
			draw_set_transform_matrix(parent_transform)
		elif e.kind=="gift_pillar":
			# A column of light where the gift opened.
			var w: float=e.radius*(1-t*.6);var h: float=220*(1-pow(1-clampf(t*3,0,1),2))
			draw_rect(Rect2(e.point+Vector2(-w*.5,-h),Vector2(w,h)),Color(e.color,.22*(1-t)))
			draw_rect(Rect2(e.point+Vector2(-w*.18,-h),Vector2(w*.36,h)),Color(1,1,1,.35*(1-t)))
			VfxArt.glow(self,e.point,e.radius*1.4,e.color,.5*(1-t))
		elif e.kind=="gift_open":
			# The lid flips off and the box walls fall open.
			var lid: Vector2=e.point+Vector2(30*float(e.angle)*t,-14-80*t+90*t*t)
			draw_set_transform_matrix(parent_transform*Transform2D(float(e.angle)*6*t,Vector2.ONE,0,lid))
			draw_rect(Rect2(Vector2(-14,-4),Vector2(28,7)),Color(e.color,1-t));draw_rect(Rect2(Vector2(-3,-4),Vector2(6,7)),Color("ffd65c",1-t))
			draw_set_transform_matrix(parent_transform)
			for side in [-1,1]:
				draw_set_transform_matrix(parent_transform*Transform2D(side*t*1.3,Vector2.ONE,0,e.point+Vector2(side*12,0)))
				draw_rect(Rect2(Vector2(-2 if side>0 else -2,-18),Vector2(4,20)),Color(e.color.darkened(.1),1-t))
				draw_set_transform_matrix(parent_transform)
		elif e.kind=="gift_mark":
			# What was inside: rising arrows (attack up), sinking arrows (damage taken up), spinning stars
			# (stun), a ring of chains (root), a cross (heal) or a gauge ring (ultimate).
			var mark: String=String(e.get("mark",""));var fade: float=clampf((1-t)*3,0,1)
			match mark:
				"power","weak":
					var up: bool=mark=="power";var col: Color=Color("ff9a4a") if up else Color("b48cff")
					for i in range(3):
						var x: float=(i-1)*16;var y: float=fmod(float(e.age)*60+i*14,48.0)*(-1 if up else 1)
						var base: Vector2=e.point+Vector2(x,(-10 if up else -40)+y);var tip: Vector2=base+Vector2(0,-10 if up else 10)
						draw_colored_polygon(PackedVector2Array([tip,base+Vector2(-6,0),base+Vector2(6,0)]),Color(col,.85*fade))
				"stun":
					for i in range(4):
						var a: float=float(e.age)*6+i*TAU/4;_star(e.point+Vector2(cos(a)*20,-34+sin(a)*6),5,float(e.age)*8,Color("ffe68a",fade))
				"root":
					for i in range(10):
						var a: float=i*TAU/10+float(e.age);var q: Vector2=e.point+Vector2(cos(a)*24,sin(a)*10+6)
						draw_set_transform_matrix(parent_transform*Transform2D(a,Vector2(1,.6),0,q));draw_arc(Vector2.ZERO,5,0,TAU,12,Color("b8c2d6",fade),2.5,true);draw_set_transform_matrix(parent_transform)
				"heal20","heal30":
					var cross: Vector2=e.point+Vector2(0,-30-20*t)
					draw_rect(Rect2(cross-Vector2(4,12),Vector2(8,24)),Color("86e3a4",fade));draw_rect(Rect2(cross-Vector2(12,4),Vector2(24,8)),Color("86e3a4",fade))
				"ult_full","ult_half":
					draw_arc(e.point,26,-PI*.5,-PI*.5+TAU*(1.0 if mark=="ult_full" else .5)*clampf(t*2.5,0,1),40,Color("9fd8ff",fade),4,true)
					VfxArt.glow(self,e.point,30,Color("9fd8ff"),.4*fade)
				"drain":
					draw_arc(e.point,26,-PI*.5,-PI*.5+TAU*(1-clampf(t*2.5,0,1)),40,Color("6b7ab0",fade),4,true)
		elif e.kind=="gift_text":
			var label: String=String(e.get("text",""))
			var pop: float=1+.35*maxf(0,1-t*6);var ty: Vector2=e.point+Vector2(-70,-58-t*24)
			draw_string_outline(ThemeDB.fallback_font,ty,label,HORIZONTAL_ALIGNMENT_CENTER,140,int(16*pop),5,Color(0,0,0,.85*(1-t*t)))
			draw_string(ThemeDB.fallback_font,ty,label,HORIZONTAL_ALIGNMENT_CENTER,140,int(16*pop),Color(Color(e.color).lightened(.4),1-t*t))
		elif e.kind=="slime_ring":
			# A squashy ring of slime splashing outward.
			var rr: float=e.radius*(.35+.65*(1-pow(1-t,2)))
			draw_arc(e.point,rr,0,TAU,40,Color(e.color,.8*(1-t)),7*(1-t)+1.5,true)
			for i in range(8):
				var d:=Vector2.from_angle(i*TAU/8+.2);draw_circle(e.point+d*rr,(6-4*t),Color(e.color,.9*(1-t)))
		elif e.kind=="griffin_gust":
			# Curved wind blades sweeping out through the cone.
			var cone: float=float(e.get("cone",.6))
			for k in range(4):
				var tk: float=clampf((t-k*.08)/(1-k*.08),0,1);var r: float=e.radius*(.25+.75*(1-pow(1-tk,2)))
				if tk>0 and tk<1:draw_arc(e.point,r,float(e.angle)-cone,float(e.angle)+cone,28,Color(Color("e8fff6"),(1-tk)*.85),6*(1-tk)+1.5,true)
			for i in range(7):
				var a: float=float(e.angle)+(i-3)*cone/3.5;var len: float=e.radius*(.3+.7*t)
				draw_line(e.point+Vector2.from_angle(a)*len*.45,e.point+Vector2.from_angle(a)*len,Color(Color("c8f7e6"),.7*(1-t)),2.5,true)
		elif e.kind=="targeted":
			draw_arc(e.point,e.radius*(1.4-t*.6),0,TAU,32,Color(e.color,1-t),3,true)
			for i in range(4):
				var d:=Vector2.from_angle(i*PI/2);draw_line(e.point+d*e.radius*(1.6-t),e.point+d*e.radius*(.9-t*.3),Color(e.color,1-t),3,true)
		elif e.kind=="hero_punch":
			var dir:=Vector2.from_angle(float(e.angle))
			VfxArt.flare(self,e.point,float(e.angle),e.radius*(.5+t),Color("fff4dd"),1-t)
			for k in range(0 if use_shader_fx else 3):
				var tk: float=clampf((t-k*.1)/(1-k*.1),0,1);var r: float=e.radius*(1-pow(1-tk,3))*(1-k*.2)
				if tk>0 and tk<1:draw_arc(e.point,r,float(e.angle)-.95,float(e.angle)+.95,40,Color(e.color,(1-tk)),14*(1-tk)+1.5,true)
			var ring: float=e.radius*.45*(1-pow(1-t,3))
			draw_arc(e.point,ring,0,TAU,48,Color(1,1,1,.7*(1-t)),5*(1-t)+1,true)
			for i in range(7):
				var a: float=float(e.angle)+(i-3)*.22;var v:=Vector2.from_angle(a);var len: float=e.radius*(.35+.5*t)
				draw_line(e.point+v*len*.4,e.point+v*len,Color("ffe1a0",.8*(1-t)),3,true)
			VfxArt.glow(self,e.point+dir*30,e.radius*.4,e.color,.7*pow(1-t,2))
		elif e.kind=="hero_call":
			VfxArt.glow(self,e.point,e.radius*(.6+t*.6),e.color,.7*(1-t))
			draw_arc(e.point,e.radius*(.3+t),0,TAU,40,Color(Color.WHITE,1-t),4*(1-t)+1,true)
		elif e.kind=="hero_grab":
			for i in range(4):
				var v:=Vector2.from_angle(i*TAU/4+PI/4);draw_line(e.point+v*(14+t*20),e.point+v*(28+t*30),Color(e.color,1-t),4*(1-t)+1,true)
		elif e.kind=="chain_shock":
			var to: Vector2=e.get("to",e.point)
			if not use_shader_fx:
				VisualShapes.bolt(self,e.point,to,Color("6fc6ff",.45*(1-t)),real_age*30+float(e.radius),8*(1-t)+2)
				VisualShapes.bolt(self,e.point,to,c,real_age*30+float(e.radius),3*(1-t)+1)
				VisualShapes.bolt(self,e.point,to,Color(1,1,1,1-t),real_age*30+float(e.radius)+.5,1.2)
			VfxArt.glow(self,to,26*(1-t)+8,Color("9fdcff"),.6*(1-t))
		elif e.kind in ["light_pop","dark_pop","shock_stun","light_mark","dark_mark"]:
			VfxArt.glow(self,e.point,e.radius*(.6+t),e.color,.5*(1-t))
			for i in range(4):
				var v:=Vector2.from_angle(i*TAU/4+PI/4+t*1.2)
				draw_line(e.point+v*(10+t*30),e.point+v*(22+t*38),c,3*(1-t)+1,true)
		elif e.kind=="ult_flash":
			draw_rect(Rect2(0,0,800,800),Color(e.color,.06*pow(1-t,2)))
			draw_arc(e.point,40+t*520,0,TAU,72,Color(Color(e.color).lightened(.4),.3*(1-t)),3*(1-t)+1,true)
		elif VfxArt.effect(self,e):pass
		else:draw_arc(e.point,radius,0,TAU,32,c,2)
		if e.kind not in ["hit","critical","projectile_hit","explosion","heal","parry_success","warrior_parry","clash","ultimate","transcendence","launch","reflect","shield_break","shield_hit","ult_flash","ult_release","ult_impact","ult_hit","chain_shock","light_pop","dark_pop","shock_stun","light_mark","dark_mark","hero_shock","hero_punch","hero_call","hero_grab","griffin_gust","targeted","slime_ring"]:
			for i in range(4):
				var v:=Vector2.from_angle(i*TAU/4+float(e.age)*.7);VfxArt.star(self,e.point+v*radius,5,e.color,1-t)
		if e.kind in ["parry_success","warrior_parry","clash"]:draw_string(ThemeDB.fallback_font,e.point+Vector2(-26,-50-t*18),{"parry_success":"패링","warrior_parry":"반격","clash":"상쇄"}[e.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,18,c)
	for n in numbers:
		var prefix: String="+" if n.kind=="heal" else "흡수 " if n.kind=="shield" else ""
		draw_string(ThemeDB.fallback_font,n.point+Vector2(-14+(16 if n.kind=="status" else 0),-38-float(n.age)*42),prefix+str(ceili(n.value)),HORIZONTAL_ALIGNMENT_LEFT,-1,23 if n.kind=="critical" else 14 if n.kind=="status" else 18,Color(n.color,1-clampf(float(n.age)/.9,0,1)))
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
## HP bar (dark outlined well, bright team-colour fill, never smaller than ~28x4 screen px however
## far the board is scaled down) and the ultimate gauge under it. Drawn with the unit and again on
## the top overlay (BarOverlay) so effects never hide them.
func draw_bars(canvas: CanvasItem,u: BattleUnit,parent: Transform2D) -> Rect2:
	var at: Vector2=u.position;var radius: float=25*u.combat_scale();var color: Color=u.team_color()
	var px: float=1/maxf(.05,parent.get_scale().x)
	var bar_w: float=maxf(48,28*px);var hp_h: float=maxf(6,4*px);var ult_h: float=maxf(3,2.5*px)
	var hp_rect:=Rect2(at+Vector2(-bar_w*.5,-radius-6-hp_h-ult_h),Vector2(bar_w,hp_h));var hp_frac: float=clampf(u.current_hp/u.max_hp,0,1)
	canvas.draw_rect(hp_rect.grow(px),Color(0,0,0,.85));canvas.draw_rect(hp_rect,Color("1a2232"))
	canvas.draw_rect(Rect2(hp_rect.position,Vector2(hp_rect.size.x*hp_frac,hp_rect.size.y)),color.lightened(.15))
	canvas.draw_rect(Rect2(hp_rect.position,Vector2(hp_rect.size.x*hp_frac,hp_h*.3)),Color(1,1,1,.3))
	if u.data.ultimate_windup>=0:
		var gauge: float=clampf(u.ultimate_gauge/100,0,1);var ult_rect:=Rect2(Vector2(hp_rect.position.x,hp_rect.end.y+px),Vector2(bar_w,ult_h))
		canvas.draw_rect(ult_rect.grow(px*.8),Color(0,0,0,.8));canvas.draw_rect(ult_rect,Color("1c2433"))
		canvas.draw_rect(Rect2(ult_rect.position,Vector2(ult_rect.size.x*gauge,ult_rect.size.y)),Color("ffe28a") if gauge>=1 else Color("c49dff"))
	if u.shield_hp>0:canvas.draw_rect(Rect2(hp_rect.position-Vector2(0,ult_h+px),Vector2(bar_w*minf(1,u.shield_hp/100),ult_h)),Color("7ddfff"))
	return hp_rect
class BarOverlay extends Control:
	var host
	func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if host==null or not is_instance_valid(host.battle) or host.board==null or host.battle.finished:return
		draw_set_transform_matrix(host.parent_transform)
		for u in host.battle.units:
			if u.alive and AttackVisuals.body_visible(u):host.draw_bars(self,u,host.parent_transform)
var bar_overlay: BarOverlay
func _unit(u: BattleUnit,parent: Transform2D) -> void:
	var at: Vector2=u.position;var radius: float=25*u.combat_scale();var color: Color=u.team_color()
	var pose_override: Dictionary={}
	if weapon_releases.has(u.battle_id):
		var row: Dictionary=weapon_releases[u.battle_id]
		var t: float=clampf((battle.clock.elapsed-float(row.start))/float(row.life),0,1)
		var swing: float=1-pow(1-t,3)
		pose_override={"key":"0:basic","index":13+roundi(swing*11),"angle":row.angle,"weapon_scale":1.4,"swing":swing}
	CharacterPainter.draw_unit(self,u,parent,float(flashes.get(u.battle_id,0))/.15,pose_override)
	_ability_state(u,parent)
	# HP bar: dark outlined well and bright team-colour fill, never smaller than ~28x4 screen px
	# however far the board is scaled down on a phone.
	var px: float=1/maxf(.05,parent.get_scale().x)
	var ult_h: float=maxf(3,2.5*px)
	var hp_rect: Rect2=draw_bars(self,u,parent)
	if u.data.ultimate_windup>=0 and u.ultimate_gauge>=100:VfxArt.glow(self,at+Vector2(0,-radius-6),30,Color("ffe28a"),.25+.15*sin(real_age*6),.2)
	stance_marks.draw(self,u,hp_rect,px,real_age)
	if u.shield_hp>0:
		VfxArt.shield(self,at,radius+9,Color("7ddfff"),real_age)
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

func _ability_state(u: BattleUnit,parent: Transform2D) -> void:
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
	for i in range(mini(ElementEffects.SHOCK_STACKS,shock)):
		var point: Vector2=p+Vector2.from_angle(-PI/2+(i-2)*.45)*35*s
		VisualShapes.streak(self,point,PI/2,10*s,4*s,Color("93dcff"),.85)
	if u.data.type_id==5 and u.combat_state==CombatController.State.ACTIVE and is_instance_valid(u.combat.healing_target):
		var patient: BattleUnit=u.combat.healing_target
		draw_line(p,patient.position,Color("c5f4e5",.35*(1-WeaponMotion.phase_progress(u))),3,true)
	if not u.puppet_control.is_empty():
		var cross: Vector2=p+Vector2(0,-48)*s
		draw_line(cross-Vector2(12,0)*s,cross+Vector2(12,0)*s,Color("ffe6ee"),4*s)
		draw_line(cross-Vector2(0,8)*s,cross+Vector2(0,8)*s,Color("ffe6ee"),4*s)
	if not u.duel.is_empty() and u.alive:_rps_hands(u,p,maxf(s,1.0))
	if u.data.type_id==43 and u.alive:
		# 팽이: spinning wind arcs round the body; red-hot while 폭주 회전 lasts.
		var hot: bool=u.state_value("topBoost")>0;var spin: float=real_age*(26 if hot else 16)
		if hot:VfxArt.glow(self,p,46*s,Color("ff8a4a"),.35+.1*sin(real_age*20))
		for k in range(3):
			var turn: float=spin+k*TAU/3;draw_arc(p,(30+k*5)*s,turn,turn+1.6,14,Color("ffb070" if hot else "e8fff6",.75-.2*k),3-k*.6,true)
	if u.character_specific_state.has("bountyBy") and u.alive:
		# 현상금: a gold crosshair with a coin over the bountied unit.
		var mark: Vector2=p+Vector2(0,-58)*s;var pulse: float=1+.08*sin(real_age*5)
		draw_arc(mark,11*pulse,0,TAU,24,Color("ffcf6e"),2,true)
		for k in range(4):
			var arm: Vector2=Vector2.from_angle(k*PI*.5);draw_line(mark+arm*7,mark+arm*15*pulse,Color("ffcf6e"),2,true)
		draw_circle(mark,4.5,Color("ffd65c"));draw_string(ThemeDB.fallback_font,mark+Vector2(-3,4),"$",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("6b4a10"))
	if not u.lost_sword.is_empty():
		var at: Vector2=CharacterPersistence.vector(u.lost_sword.get("point",CharacterPersistence.point(p)))
		# The same greatsword it swings, lying where it landed (spinning while still in flight).
		var spin: float=float(u.lost_sword.get("rotation",0))
		draw_set_transform_matrix(parent*Transform2D(0,Vector2(1,.35),0,at+Vector2(0,10*s)));draw_circle(Vector2.ZERO,40*s,Color(0,0,0,.18));draw_set_transform_matrix(parent)
		if not WeaponMotion.draw_loose(self,u.data.type_id,parent*Transform2D(spin,Vector2.ONE*s*float(u.lost_sword.get("sizeBoost",1)),0,at)):
			VisualShapes.streak(self,at,-.65,90*s,18*s,Color("e5d3b3"));draw_line(at+Vector2(-17,17),at+Vector2(2,36),Color("9c7149"),5)
		draw_set_transform_matrix(parent)
	if not u.puppet_control.is_empty():
		for i in range(3):draw_line(p+Vector2((i-1)*12,-30)*s,p+Vector2((i-1)*23,-77)*s,Color("dca2e1"),1.5)
	
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
	_element_status(u,p,s)
	_hero_state(u,p,s)
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
## 히어로: a golden barrier on the ally being rescued, speed lines and afterimages while it flies,
## and during the ultimate the grip on the held enemy and the fist drawn back gathering power.
func _hero_state(u: BattleUnit,p: Vector2,s: float) -> void:
	if not u.hero_rescue_owner.is_empty():
		VfxArt.glow(self,p,52*s,Color("ffd27a"),.35+.1*sin(real_age*10))
		VisualShapes.barrier(self,p,40*s,Color("ffd284"),real_age)
	if u.data.type_id!=17 or not u.alive:return
	if u.is_dashing() and u.velocity.length()>120:
		var dir: Vector2=u.velocity.normalized();var side: Vector2=dir.orthogonal()
		for i in range(4):draw_circle(p-dir*(22+i*22)*s,(22-i*4)*s,Color("ffd27a",.22-i*.05))
		for i in range(7):
			var off: float=(i-3)*9*s;var len: float=(50+VisualParticles.noise(i*7.1+floorf(real_age*30))*60)*s
			draw_line(p-dir*28*s+side*off,p-dir*(28*s+len)+side*off,Color("fff4dd",.75),2,true)
		VfxArt.glow(self,p+dir*14*s,34*s,Color("ffd27a"),.28)
	var cast: Dictionary=u.ultimate.cast
	if cast.get("phase","")=="punch" and float(cast.get("punch_time",0))<FIST_CHARGE_END:
		var k: float=clampf((float(cast.get("punch_time",0))-.14)/.5,0,1);var dir:=Vector2.from_angle(float(cast.get("angle",u.facing)))
		var fist: Vector2=p-dir*(24+24*k)*s+dir.orthogonal()*10*s
		var shake:=Vector2(sin(real_age*90),cos(real_age*77))*2.5*k
		VfxArt.glow(self,fist+shake,(22+46*k)*s,Color("ffb347"),.45+.5*k)
		for i in range(8):
			var a: float=i*TAU/8+real_age*3;var phase: float=fposmod(real_age*2.4+i*.125,1.0)
			var from: Vector2=fist+Vector2.from_angle(a)*(72*(1-phase)+14)*s
			draw_line(from,from.lerp(fist,.35),Color("ffe1a0",.85*k*(1-phase)),2,true)
		draw_arc(fist+shake,(14+10*k)*s,0,TAU,24,Color("fff4dd",.4+.5*k),2+2*k,true)
		draw_circle(fist+shake,13*s,Color("f2c27a"));draw_circle(fist+shake,13*s*.55,Color("ffe9c0"))
		for i in range(3):draw_line(fist+shake+dir*6*s+dir.orthogonal()*(i-1)*4*s,fist+shake+dir*10*s+dir.orthogonal()*(i-1)*4*s,Color("8a5a2a"),2,true)
		var held=battle.find_actor(str(cast.get("target","")))
		if held!=null and held.alive and k>0:
			for i in range(2):
				var g: Vector2=held.position+(u.position-held.position).normalized()*18*s+dir.orthogonal()*(i*2-1)*14*s
				draw_arc(g,6*s,0,TAU,12,Color("ffd27a",.9),3,true)
## Rising flames and smoke while burning, dark-green and violet plumes while poisoned, violet smoke
## while eroded, frost glints while frostbitten. Emitters run on battle time.
func _status_emitters(dt: float) -> void:
	if dt<=0 or not is_instance_valid(battle):return
	for u in battle.units:
		if not u.alive or (u.character_specific_state.is_empty() and u.data.type_id!=17):continue
		var clock: Dictionary=emit_clock.get(u.battle_id,{})
		var s: float=u.combat_scale();var p: Vector2=u.position
		if u.data.type_id==17 and u.is_dashing() and u.velocity.length()>120:
			var dust: float=float(clock.get("dash",0.0))+dt
			while dust>=.035:
				dust-=.035;particles.burst(p-u.velocity.normalized()*20*s,Color("6b5a4a"),1,50,u.velocity.angle()+PI,"smoke",false)
			clock["dash"]=dust
		if u.character_specific_state.has("snowball"):
			var ball: Dictionary=u.character_specific_state.snowball;var bdir: Vector2=Vector2.from_angle(float(ball.angle))
			var spray: float=float(clock.get("snow",0.0))+dt
			while spray>=.03:
				spray-=.03;var bp: Vector2=Vector2(float(ball.x),float(ball.y))-bdir*30*s
				particles.burst(bp+bdir.orthogonal()*(VisualParticles.noise(real_age*53+spray)-.5)*50*s,Color("ffffff"),1,120,bdir.angle()+PI,"smoke",false)
				particles.burst(bp,Color("eaf6ff"),1,180,bdir.angle()+PI+(VisualParticles.noise(real_age*31)-.5),"shard",false)
			clock["snow"]=spray
		if u.data.type_id==42:
			var dust: float=float(clock.get("santa",0.0))+dt
			var away: float=u.state_value("santaAway")
			while dust>=(.04 if away>0 else .45):
				dust-=.04 if away>0 else .45
				if away>0:
					# Stardust and snow shaken loose from the sleigh as it passes.
					var q: Vector2=sleigh_point(clampf(u.state_value("santaClock")/SANTA_AWAY,0,1))+Vector2(-110,20)
					particles.burst(q,Color("ffd65c"),1,90,PI*.5,"spark",false);particles.burst(q+Vector2(30,0),Color("ffffff"),1,60,PI*.5,"mote",false)
				else:
					# 전설: a faint drift of gold and snow around Santa.
					var n: float=VisualParticles.noise(real_age*41+u.battle_id)
					particles.burst(p+Vector2((n-.5)*44*s,-20*s),Color("ffd65c") if n>.5 else Color("ffffff"),1,30,-PI/2,"mote",false)
			clock["santa"]=dust
		var burn: float=u.state_value("burnStacks")
		for row in [["flame",burn>0 and not use_shader_fx,.07/(1+burn*.08)],["smoke",burn>0,.18],["poison",u.state_value("poisonStacks")>0,.11],["erosion",u.state_value("erosionTime")>0,.1],["frost",u.state_value("frostbiteTime")>0,.22]]:
			if not row[1]:clock.erase(row[0]);continue
			var t: float=float(clock.get(row[0],row[2]))+dt
			while t>=row[2]:
				t-=row[2]
				var n: float=VisualParticles.noise(real_age*97+u.battle_id*13+t);var x: float=(n-.5)*36*s
				match row[0]:
					"flame":particles.burst(p+Vector2(x,10*s),Color("ff7a2e"),1,70*s,-PI/2,"flame",false)
					"smoke":particles.burst(p+Vector2(x*.6,-24*s),Color("3a3432"),1,40*s,-PI/2,"plume",false)
					"poison":
						particles.burst(p+Vector2(x,8*s),Color("2e7a22") if n<.55 else Color("7a3aa8"),1,42*s,-PI/2,"plume",false)
						if n>.75:particles.burst(p+Vector2(x,0),Color("a6f07a"),1,40*s,-PI/2,"mote",false)
					"erosion":
						particles.burst(p+Vector2(x,6*s),Color("2a1840") if n<.6 else Color("6b3fb0"),1,46*s,-PI/2,"plume",false)
						if n>.7:particles.burst(p+Vector2(x,-6*s),Color("c9a6ff"),1,50*s,-PI/2,"mote",false)
					"frost":particles.burst(p+Vector2(x,-10*s),Color("e6f8ff"),1,40*s,-PI/2,"mote",false)
			clock[row[0]]=t
		emit_clock[u.battle_id]=clock
## An orb of light (heal) or darkness (empower) flies on a bent path from a struck enemy to an ally.
func _orb(from: Vector2,actor: String,kind: String) -> void:
	if orbs.size()>=48:orbs.pop_front()
	orbs.append({"from":from,"to":from,"actor":actor,"age":0.0,"life":.6 if kind=="light_orbs" else .7,"dark":kind=="dark_pop","big":kind!="light_orbs","bend":(1 if orbs.size()%2==0 else -1)*(.5+VisualParticles.noise(real_age*31+orbs.size())*.5),"trail":[]})
func _orb_point(o: Dictionary,t: float) -> Vector2:
	var from: Vector2=o.from;var to: Vector2=o.to;var k: float=t*t*(3-2*t)
	var mid: Vector2=(from+to)*.5+(to-from).orthogonal()*float(o.bend)*.45+Vector2(0,-50)
	return from.lerp(mid,k).lerp(mid.lerp(to,k),k)
func _advance_orbs(dt: float) -> void:
	for o in orbs.duplicate():
		o.age=float(o.age)+dt
		var u=battle.find_actor(String(o.actor)) if is_instance_valid(battle) else null
		if u!=null:o.to=u.position
		var t: float=clampf(float(o.age)/float(o.life),0,1);var at: Vector2=_orb_point(o,t)
		o.trail.append(at)
		if o.trail.size()>9:o.trail.pop_front()
		var tint: Color=Color("a777ff") if o.dark else Color("ffe59a")
		if VisualParticles.noise(real_age*53+float(o.age)*7)>.6:particles.burst(at,tint,1,40,0,"mote",false)
		if t>=1:
			orbs.erase(o)
			add_effect("orb_land",o.to,tint,30 if o.big else 20,.45)
			particles.burst(o.to,tint,14 if o.big else 8,160,0,"shard" if o.dark else "heal",true)
func _draw_orbs() -> void:
	for o in orbs:
		var t: float=clampf(float(o.age)/float(o.life),0,1);var at: Vector2=_orb_point(o,t)
		var tint: Color=Color("a777ff") if o.dark else Color("ffe59a");var core: Color=Color("2a1048") if o.dark else Color.WHITE
		var r: float=9.0 if o.big else 6.5
		var trail: Array=o.trail
		for i in range(1,trail.size()):draw_line(trail[i-1],trail[i],Color(tint,float(i)/trail.size()*.7),r*float(i)/trail.size()*1.3,true)
		VfxArt.glow(self,at,r*4.5,tint,.85)
		draw_circle(at,r,tint);draw_circle(at,r*.55,core)
		if not o.dark:VfxArt.star(self,at,r*1.6,Color.WHITE,.9,real_age*4)
		else:draw_arc(at,r*1.4,real_age*6,real_age*6+2.2,8,Color("e0ccff",.9),1.5,true)
## Element statuses (ElementEffects): an aura for burning / poison / erosion / frostbite / headwind,
## marks over the head, and a row of small counted badges under the unit.
func _element_status(u: BattleUnit,p: Vector2,s: float) -> void:
	if u.character_specific_state.is_empty() or not u.alive:return
	var flicker: float=.5+.5*sin(real_age*9+u.battle_id)
	if u.state_value("burnStacks")>0:
		VfxArt.glow(self,p,44*s,Color("ff6a1e"),.32+.14*flicker)
		VfxArt.glow(self,p+Vector2(0,-14)*s,26*s,Color("ffc061"),.22+.1*flicker)
	if u.state_value("poisonStacks")>0:
		VfxArt.glow(self,p,40*s,Color("3f7a2c"),.28+.08*flicker)
		VfxArt.glow(self,p+Vector2(8,-8)*s,24*s,Color("6b3a8f"),.2)
	if u.state_value("frostbiteTime")>0:
		for i in range(6):
			var a: float=i*TAU/6+real_age*.6
			draw_line(p+Vector2.from_angle(a)*27*s,p+Vector2.from_angle(a)*33*s,Color("d9f4ff",.8),2,true)
	if u.state_value("headwindTime")>0:
		for i in range(2):
			var a: float=-real_age*5+i*PI
			draw_arc(p,(31+i*4)*s,a,a+1.4,10,Color("e8f3f0",.55),2,true)
	if u.state_value("windStacks")>0:
		var n: int=mini(int(u.state_value("windStacks")),5)
		for i in range(n):
			var a: float=real_age*4+i*TAU/n
			draw_arc(p+Vector2.from_angle(a)*30*s,5*s,a,a+2.4,6,Color("9ff0d8",.85),2,true)
	if u.state_value("erosionTime")>0:
		VfxArt.glow(self,p,44*s,Color("4a2290"),.38+.12*flicker)
		for i in range(3):
			var a: float=-real_age*2.4+i*TAU/3
			draw_arc(p,34*s,a,a+.9,10,Color("c9a6ff",.75),2.5,true)
	# 둔화: a sluggish lavender ring at the feet.
	if u.state_value("slowTime")>0:
		VfxArt.ellipse(self,p+Vector2(0,22*s),26*s,.35,Color("c9b8ff",.8),2.5)
	# 빙하 골렘: a frosty ring at its feet; while charging, vapour spirals inward and the glow grows.
	if u.data.type_id==39:
		# Cold mist at the feet with snowflakes drifting around.
		VfxArt.glow(self,p+Vector2(0,10*s),70*s,Color("cfeeff"),.18)
		VfxArt.ellipse(self,p+Vector2(0,22*s),40*s,.35,Color("cfeeff",.55),2)
		for i in range(7):
			var a: float=real_age*.7+i*TAU/7;var rr: float=(48+10*sin(real_age*1.3+i))*s
			var q: Vector2=p+Vector2(cos(a)*rr,sin(a)*rr*.5+(fmod(real_age*.6+i*.3,1.0)-.5)*30*s)
			VfxArt.star(self,q,3.5*s,Color("eaf8ff"),.8,real_age+i)
		var charge: float=u.state_value("golemCharge")
		if charge>0:
			VfxArt.glow(self,p,(40+60*charge)*s,Color("bfe9ff"),.25+.35*charge)
			for i in range(6):
				var a: float=real_age*3+i*TAU/6;var rr: float=(90-60*fmod(real_age*.8+i/6.0,1.0))*s
				draw_arc(p,rr,a,a+.8,8,Color("e8f8ff",.7),2.5,true)
	# 매혹 (속삭이는 자): a pink heart bobbing over the head.
	if u.state_value("charmTime")>0:
		var hp_at: Vector2=p+Vector2(0,-60*s+sin(real_age*5)*3);var hs: float=9*s*(1+.12*sin(real_age*8))
		VfxArt.glow(self,hp_at,22*s,Color("ff5fa8"),.4)
		var pts:=PackedVector2Array()
		for i in range(24):
			var t: float=TAU*i/24.0
			pts.append(hp_at+Vector2(16*pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))/16.0*hs)
		draw_colored_polygon(pts,Color("ff4f9a"))
		# Little hearts keep floating up from the charmed unit.
		for k in range(5):
			var cyc: float=fmod(real_age*.9+k*.2,1.0);var hx: float=sin(real_age*2+k*1.7)*14*s+(k-2)*7*s
			var at: Vector2=p+Vector2(hx,(10-70*cyc)*s);var sz: float=(4+3*sin(k*1.3))*s*(1-cyc*.4)
			var hp2:=PackedVector2Array()
			for i in range(16):
				var t2: float=TAU*i/16.0
				hp2.append(at+Vector2(16*pow(sin(t2),3),-(13*cos(t2)-5*cos(2*t2)-2*cos(3*t2)-cos(4*t2)))/16.0*sz)
			draw_colored_polygon(hp2,Color("ff7ab8",(1-cyc)*.85))
	# 속삭임 stacks: small violet needles orbiting the unit.
	var whispers: int=int(u.state_value("whisperStacks"))
	for i in range(whispers):
		var a: float=-real_age*2+i*TAU/3
		var q: Vector2=p+Vector2.from_angle(a)*26*s;draw_line(q,q+Vector2.from_angle(a+1.2)*8*s,Color("c9a6ff"),2,true)
	# 목표 (석궁): a red reticle turning over the unit.
	if u.state_value("targetedTime")>0:
		var rr: float=31*s;var spin: float=real_age*1.5
		draw_arc(p,rr,0,TAU,32,Color("ff6a5a",.75),2,true)
		for i in range(4):
			var d:=Vector2.from_angle(spin+i*PI/2);draw_line(p+d*(rr-6*s),p+d*(rr+7*s),Color("ff8a7a"),2.5,true)
	# Marks: a turning golden sigil (광휘) / a violet sigil of inward fangs (암흑) over the head.
	var light_mark: bool=not str(u.character_specific_state.get("lightMark","")).is_empty()
	var dark_mark: bool=not str(u.character_specific_state.get("darkMark","")).is_empty()
	if light_mark:
		var at: Vector2=p+Vector2(-15 if dark_mark else 0,-66)*s+Vector2(0,sin(real_age*3)*2)
		VfxArt.glow(self,at,26*s,Color("ffd86a"),.45+.15*flicker)
		VfxArt.star(self,at,8*s,Color("fff4c8"),1,real_age*1.5)
		for i in range(4):
			var v: Vector2=Vector2.from_angle(real_age*2+i*TAU/4)*12*s;var d: float=3.5*s
			draw_colored_polygon(PackedVector2Array([at+v+Vector2(0,-d),at+v+Vector2(d*.7,0),at+v+Vector2(0,d),at+v+Vector2(-d*.7,0)]),Color("ffe59a",.95))
		draw_arc(at,12*s,0,TAU,24,Color("ffe59a",.5),1.5,true)
	if dark_mark:
		var at: Vector2=p+Vector2(15 if light_mark else 0,-66)*s+Vector2(0,cos(real_age*3)*2)
		VfxArt.glow(self,at,26*s,Color("6b3fb0"),.55+.15*flicker)
		draw_circle(at,6*s,Color("1c0f30"));draw_arc(at,6*s,0,TAU,16,Color("c9a6ff"),1.5,true)
		for i in range(3):
			var v: Vector2=Vector2.from_angle(-real_age*2.2+i*TAU/3)
			draw_colored_polygon(PackedVector2Array([at+v*8*s,at+v*15*s+v.orthogonal()*4*s,at+v*15*s-v.orthogonal()*4*s]),Color("b48cff",.95))
		draw_arc(at,15*s,0,TAU,24,Color("b48cff",.45),1.5,true)
	var badges: Array=[]
	for row in [["burnStacks","phoenixFeather",Color("ff9a52")],["poisonStacks","verdantStone",Color("8fe36b")],["windStacks","hawkFeather",Color("9ff0d8")]]:
		var n: int=int(u.state_value(row[0]))
		if n>0:badges.append([row[1],row[2],n])
	if badges.is_empty():return
	var w: float=30*s;var start: Vector2=p+Vector2(-(badges.size()-1)*w*.5,54*s)
	for i in range(badges.size()):
		var at: Vector2=start+Vector2(i*w,0)
		draw_circle(at,12*s,Color("10141f",.88));draw_arc(at,12*s,0,TAU,20,Color(badges[i][1],.95),2,true)
		ArenaIcon.draw(self,at,badges[i][0],15*s,badges[i][1])
		draw_string(ThemeDB.fallback_font,at+Vector2(7,12)*s,str(badges[i][2]),HORIZONTAL_ALIGNMENT_LEFT,-1,int(13*s)+1,Color.WHITE)
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

## 화염방사기 ultimate, read from its zone's clock: bottles arc out and shatter into oil puddles,
## a jet of fire lights the nearest puddle, and the fire runs across the rest of the oil.
func _oil_fire(z: Dictionary) -> void:
	var age: float=float(z.total)-float(z.life);var fade: float=clampf(float(z.life)/.6,0,1)
	var origin: Vector2=CharacterPersistence.vector(z.origin);var first: Vector2=CharacterPersistence.vector(z.first)
	for i in range(z.puddles.size()):
		var pd: Dictionary=z.puddles[i];var at: Vector2=CharacterPersistence.vector(pd);var r: float=float(pd.r);var land: float=float(pd.land)
		if age<land:
			var k: float=(age-(land-FLAMETHROWER.FLIGHT))/FLAMETHROWER.FLIGHT
			if k>=0:_oil_bottle(origin.lerp(at,k)+Vector2(0,-sin(k*PI)*80),age*13+i,k)
			continue
		var since: float=age-land;var grow: float=Motion.out_quint(clampf(since/.25,0,1))
		# A flat, irregular pool of glossy oil, squashed a little for the top-down ground.
		var pool:=PackedVector2Array();var inner:=PackedVector2Array();var lit: float=age-float(pd.ignite)
		for j in range(20):
			var d: Vector2=Vector2.from_angle(j*TAU/20)*Vector2(1,.72);var wob: float=.82+.3*VisualParticles.noise(i*29+j)
			pool.append(at+d*r*wob*grow);inner.append(at+d*r*wob*grow*.62+Vector2(-r*.08,-r*.06))
		draw_colored_polygon(pool,Color("241a10",.6*fade));draw_colored_polygon(inner,Color("3d2e1a",.45*fade))
		if lit>=0:draw_colored_polygon(pool,Color("ff5a1f",(.28+.08*sin(real_age*9+i))*clampf(lit/.3,0,1)*fade))
		else:draw_arc(at+Vector2(-r*.25,-r*.2)*grow,r*.3*grow,PI*1.1,PI*1.7,10,Color("c8b48a",.55*fade),2,true)
		if since<.35:
			# Shattering glass and splashing oil.
			var q: float=since/.35
			for j in range(8):
				var d: Vector2=Vector2.from_angle(j*TAU/8+i);var p: Vector2=at+d*r*(.3+.9*Motion.out_quint(q))
				draw_line(p,p+d*6,Color("cfe7d0",1-q),2,true);draw_circle(p-d*8,3*(1-q),Color("2a2016",1-q))
			draw_arc(at,r*(.4+.8*q),0,TAU,24,Color("d8c7a0",.6*(1-q)),2,true)
		if lit<0:continue
		# The fire front races across the pool, then the oil keeps burning.
		var spread: float=clampf(lit/.3,0,1)
		VfxArt.glow(self,at,r*1.5,Color("ff6b25"),.45*fade*spread)
		if spread<1:draw_arc(at,r*spread,0,TAU,28,Color("ffe08a",.9),4,true)
		for j in range(13):
			var t: float=fposmod(real_age*1.2+j*.131+i*.31,1.0);var base: Vector2=at+Vector2.from_angle(j*2.399+i)*Vector2(1,.72)*r*.85*sqrt(VisualParticles.noise(i*11+j+1))*spread
			var flame: Vector2=base+Vector2(sin(real_age*3+j)*5,-t*42);var alpha: float=sin(t*PI)*fade
			VfxArt.quad(self,VfxArt.SMOKE,flame,Vector2(15*(1-t)+6,30*(1-t)+8),sin(j)*.3,Color("ff5a1f",alpha*.7))
			VfxArt.flare(self,flame,-PI/2,20*(1-t)+8,Color("ffdc82"),alpha*.9)
			if j%3==0:VfxArt.star(self,flame+Vector2(sin(j*3.1)*8,-14-t*20),3,Color("ffd593"),alpha*.8)
	# The jet of fire that lights the oil.
	var jet: float=Motion.phase(age,FLAMETHROWER.IGNITE-.3,.3)*(1-Motion.phase(age,FLAMETHROWER.IGNITE+.05,.2))
	if jet>0:
		var dir: Vector2=(first-origin).normalized();var length: float=origin.distance_to(first)*minf(1,Motion.phase(age,FLAMETHROWER.IGNITE-.3,.25)*1.2)
		for i in range(12):
			var t: float=(i+fposmod(real_age*9,1.0))/12.0;var at: Vector2=origin+dir*(34+length*t)+dir.orthogonal()*sin(real_age*31+i)*8*t
			draw_circle(at,6+20*t,Color(Color("ff4d1f").lerp(Color("ffb340"),1-t),.45*jet*(1-t*.6)))
func _oil_bottle(at: Vector2,spin: float,k: float) -> void:
	var turn:=Transform2D(spin,Vector2.ONE*1.5,0,at);var shadow: float=1-sin(k*PI)
	draw_circle(at+Vector2(0,sin(k*PI)*80),5,Color(0,0,0,.18*(1-shadow*.5)))
	draw_colored_polygon(PackedVector2Array([turn*Vector2(-6,-7),turn*Vector2(6,-7),turn*Vector2(6,9),turn*Vector2(-6,9)]),Color("4b6b3c"))
	draw_colored_polygon(PackedVector2Array([turn*Vector2(-5,-2),turn*Vector2(5,-2),turn*Vector2(5,8),turn*Vector2(-5,8)]),Color("2a2016"))
	draw_colored_polygon(PackedVector2Array([turn*Vector2(-2.5,-13),turn*Vector2(2.5,-13),turn*Vector2(2.5,-7),turn*Vector2(-2.5,-7)]),Color("6c8f5c"))
	draw_colored_polygon(PackedVector2Array([turn*Vector2(-3,-16),turn*Vector2(3,-16),turn*Vector2(3,-12),turn*Vector2(-3,-12)]),Color("b98a54"))
	draw_line(turn*Vector2(-4,-5),turn*Vector2(-4,6),Color(1,1,1,.45),1.5,true)
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
