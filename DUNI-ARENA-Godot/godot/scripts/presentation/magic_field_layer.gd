class_name MagicFieldLayer
extends Control
## Bounded reusable shader quads for decorative flow; actual boundaries stay in main draw.
const LIMIT=16
const KINDS={"blackhole":0,"tankFire":1,"healing":2,"holy":2,"galaxy":3,"cosmic":3}
const FLOW=preload("res://assets/vfx/magic_flow.gdshader")
const NOISE=preload("res://assets/vfx/flow_noise.png")
var pool: Array[Node2D]=[]
var active: int=0
var logical: Array[Transform2D]=[]
class Surface extends Node2D:
	func _draw() -> void:draw_texture_rect(VfxArt.GLOW,Rect2(-1,-1,2,2),false)
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func sync(entries: Array[Dictionary],parent: Transform2D,time: float) -> void:
	active=0
	# Priority vortex is kept even when many decorative fields overlap.
	for priority in [true,false]:
		for z in entries:
			if active>=LIMIT:break
			if not KINDS.has(z.kind) or (String(z.kind)=="blackhole")!=priority:continue
			if pool.size()<=active:
				var surface:=Surface.new();var effect:=ShaderMaterial.new();effect.shader=FLOW;effect.set_shader_parameter("flow_noise",NOISE);surface.material=effect;add_child(surface);pool.append(surface);logical.append(Transform2D.IDENTITY)
			var node: Node2D=pool[active];node.show()
			logical[active]=Transform2D(0,Vector2.ONE*float(z.radius),0,CharacterPersistence.vector(z.point))
			node.transform=parent*logical[active]
			var effect: ShaderMaterial=node.material
			effect.set_shader_parameter("clock",time);effect.set_shader_parameter("kind",KINDS[z.kind]);effect.set_shader_parameter("strength",clampf(float(z.life)*3,0,1))
			effect.set_shader_parameter("tint",CombatPresentation.ZONE_COLORS.get(z.kind,Color("a599ff")))
			active+=1
	for i in range(active,pool.size()):pool[i].hide()
func align(parent: Transform2D) -> void:
	for i in range(active):pool[i].transform=parent*logical[i]
func clear() -> void:
	active=0
	for node in pool:node.hide()
