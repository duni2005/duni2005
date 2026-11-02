class_name ShaderFxLayer
extends Control
## Shader-drawn effects on reusable quads (like MagicFieldLayer): shockwaves (with a heat-haze
## warp), lightning bolts between units, and fire on burning units. Effects live in board space;
## the host passes the board→screen transform each frame.
const SHOCK=preload("res://assets/vfx/fx_shock.gdshader")
const WARP=preload("res://assets/vfx/fx_warp.gdshader")
const FLAME=preload("res://assets/vfx/fx_flame.gdshader")
const BOLT=preload("res://assets/vfx/fx_bolt.gdshader")
const NOISE=preload("res://assets/vfx/fx_noise.png")
const LIMIT=40
var pools: Dictionary={}
var used: Dictionary={}
var logical: Dictionary={}
## One-shot effects: {kind, point, radius, angle, cone, to, age, life, tint, seed}.
var bursts: Array[Dictionary]=[]
class Surface extends Node2D:
	func _draw() -> void:draw_texture_rect(VfxArt.GLOW,Rect2(-1,-1,2,2),false)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func shock(point: Vector2,radius: float,life: float,tint: Color,angle: float=0,cone: float=0) -> void:
	_push({"kind":"shock","point":point,"radius":radius,"life":life,"tint":tint,"angle":angle,"cone":cone})
	_push({"kind":"warp","point":point,"radius":radius,"life":life})
func bolt(from: Vector2,to: Vector2,life: float=.5) -> void:
	_push({"kind":"bolt","point":from,"to":to,"life":life,"seed":randf()*10})
func _push(e: Dictionary) -> void:
	if bursts.size()>=LIMIT:bursts.pop_front()
	e["age"]=0.0;bursts.append(e)
func advance(dt: float) -> void:
	for e in bursts:e.age=float(e.age)+dt
	for i in range(bursts.size()-1,-1,-1):
		if float(bursts[i].age)>=float(bursts[i].life):bursts.remove_at(i)
func _surface(kind: String,shader: Shader) -> Node2D:
	var pool: Array=pools.get(kind,[]);var n: int=int(used.get(kind,0))
	if pool.size()<=n:
		var s:=Surface.new();var m:=ShaderMaterial.new();m.shader=shader;if kind!="warp":m.set_shader_parameter("noise_tex",NOISE)
		s.material=m;add_child(s);pool.append(s);pools[kind]=pool;logical[s]=Transform2D.IDENTITY
	used[kind]=n+1;var node: Node2D=pool[n];node.show();return node
func sync(battle,parent: Transform2D,time: float) -> void:
	used.clear()
	for e in bursts:
		var t: float=float(e.age)/float(e.life)
		match String(e.kind):
			"shock":
				var s:=_surface("shock",SHOCK);var m: ShaderMaterial=s.material
				logical[s]=Transform2D(0,Vector2.ONE*float(e.radius),0,e.point)
				m.set_shader_parameter("progress",t);m.set_shader_parameter("clock",time);m.set_shader_parameter("angle",float(e.angle));m.set_shader_parameter("cone",float(e.cone));m.set_shader_parameter("tint",e.tint)
			"warp":
				var s:=_surface("warp",WARP);logical[s]=Transform2D(0,Vector2.ONE*float(e.radius)*1.05,0,e.point);(s.material as ShaderMaterial).set_shader_parameter("progress",t)
			"bolt":
				var s:=_surface("bolt",BOLT);var m: ShaderMaterial=s.material
				var a: Vector2=e.point;var b: Vector2=e.to;var span: float=maxf(1,a.distance_to(b))
				logical[s]=Transform2D((b-a).angle(),Vector2(span*.5,clampf(span*.12,18,40)),0,(a+b)*.5)
				m.set_shader_parameter("clock",time);m.set_shader_parameter("seed",float(e.seed));m.set_shader_parameter("fade",pow(1-t,.8))
	if battle!=null:
		for u in battle.units:
			if not u.alive or u.state_value("burnStacks")<=0:continue
			var sc: float=u.combat_scale();var stacks: float=u.state_value("burnStacks")
			var s:=_surface("flame",FLAME);var m: ShaderMaterial=s.material
			var h: float=(60+stacks*3)*sc;var w: float=36*sc
			logical[s]=Transform2D(0,Vector2(w,h*.5),0,u.position+Vector2(0,14*sc-h*.5))
			m.set_shader_parameter("clock",time);m.set_shader_parameter("seed",u.battle_id*.37);m.set_shader_parameter("intensity",clampf(.7+stacks*.04,.7,1.0))
			m.set_shader_parameter("hole",Vector4(.5,(h-14*sc)/h,26*sc/(2*w),26*sc/h))
	for kind in pools:
		var pool: Array=pools[kind]
		for i in range(int(used.get(kind,0)),pool.size()):pool[i].hide()
	align(parent)
func align(parent: Transform2D) -> void:
	for kind in pools:
		var pool: Array=pools[kind]
		for i in range(int(used.get(kind,0))):pool[i].transform=parent*logical[pool[i]]
func clear() -> void:
	bursts.clear();used.clear()
	for kind in pools:
		for node in pools[kind]:node.hide()
