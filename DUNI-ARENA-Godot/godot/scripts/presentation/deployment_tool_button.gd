class_name DeploymentToolButton
extends Button
## A common round tool face. Disabled undo/redo are neutral, only clear is red.
var tool_kind: String="undo"
func _init() -> void:
	theme=ArenaUI.get_theme();theme_type_variation=&"ArenaCard";custom_minimum_size=Vector2(44,44)
func _ready() -> void:
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw);toggled.connect(func(_v):queue_redraw())
func _draw() -> void:
	var active: bool=toggle_mode and button_pressed
	var destructive: bool=tool_kind=="clear_all"
	var color: Color=Color("ff9b91") if destructive else Color("ffe1a2") if active else Color("d2dcd5")
	var fill: Color=Color("482d2c") if destructive else Color("675236") if active else Color("253034")
	var edge: Color=Color("a55c58") if destructive else Color("ffce8a") if active else Color("63726c")
	if disabled:color=Color("7a8580") if not destructive else Color("a56d66");fill=Color("1b2522") if not destructive else Color("302322");edge=Color("3b4841") if not destructive else Color("63413e")
	elif is_hovered():fill=fill.lightened(.1)
	var at:=size*.5;var radius: float=minf(size.x,size.y)*.5-2
	draw_circle(at+Vector2(0,1.5),radius,Color(0,0,0,.3));draw_circle(at,radius,fill);draw_arc(at,radius,0,TAU,64,edge,2 if active else 1,true)
	var icon: Texture2D=ArenaIcon.texture(tool_kind)
	if icon!=null:draw_texture_rect(icon,Rect2(at-Vector2.ONE*10,Vector2.ONE*20),false,color)
	if active:
		draw_circle(at+Vector2(13,12),6,Color("ffce8a"));draw_line(at+Vector2(10,12),at+Vector2(12,14),Color("29211b"),1.8,true);draw_line(at+Vector2(12,14),at+Vector2(16,10),Color("29211b"),1.8,true)
	if has_focus():draw_arc(at,radius-3,0,TAU,64,Color(edge,.6),1,true)
