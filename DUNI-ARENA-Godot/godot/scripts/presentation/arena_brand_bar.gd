class_name ArenaBrandBar
extends Control
func _ready() -> void:
 custom_minimum_size.y=35;mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _draw() -> void:
 var font: Font=ArenaUI.numbers_font();var orange:=ArenaUI.ACCENT
 draw_circle(Vector2(9,13),6,orange);draw_arc(Vector2(9,13),8,0,TAU,32,orange,1,true);draw_circle(Vector2(9,13),4,ArenaUI.BACKGROUND)
 draw_string(font,Vector2(24,20),"DUNI",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("eef1fa"))
 draw_string(font,Vector2(24+font.get_string_size("DUNI",HORIZONTAL_ALIGNMENT_LEFT,-1,19).x+3,20),"ARENA",HORIZONTAL_ALIGNMENT_LEFT,-1,19,orange)
 draw_line(Vector2(0,size.y-1),Vector2(size.x,size.y-1),Color("2a3554"),1)
