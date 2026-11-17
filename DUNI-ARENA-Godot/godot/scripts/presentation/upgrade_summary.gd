class_name UpgradeSummary
extends Control
## Read-only view of the selected unit's level, EXP and per-level growth; never applies growth.
var member_name: String=""
var level: int=0
var hp: float=0
var max_hp: float=1
var exp_progress: int=0
var exp_needed: int=1
var total_exp: int=0
## Item slots the next level adds (shown as its own chip on the right).
var slot_gain: int=0
## Compact (inside a room's tab): name, HP and EXP only, without the per-level growth chips.
var compact: bool=false
func _ready() -> void:
	custom_minimum_size.y=84 if compact else 120;mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var font: Font=get_theme_default_font();var bold: Font=ArenaUI.heading_font()
	draw_string(bold,Vector2(0,23),member_name,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("eef1fa"))
	var name_width: float=bold.get_string_size(member_name,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	draw_string(font,Vector2(name_width+10,23),"Lv.%d"%level,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ArenaUI.MUTED)
	ArenaIcon.draw(self,Vector2(10,47),"heart",17,Color.WHITE)
	var bar_width: float=minf(180,size.x*.44);var at:=Vector2(30,44)
	draw_style_box(ArenaUI.box(Color("0e1424"),Color.TRANSPARENT),Rect2(at,Vector2(bar_width,5)))
	draw_style_box(ArenaUI.box(ArenaUI.HP,Color.TRANSPARENT),Rect2(at,Vector2(bar_width*clampf(hp/maxf(1,max_hp),0,1),5)))
	draw_string(font,Vector2(bar_width+45,51),ArenaUI.hp(hp,max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,12,ArenaUI.MUTED)
	# Experience toward the next level, and the total since Lv.0.
	draw_string(bold,Vector2(0,73),"EXP",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c49dff"))
	at=Vector2(30,66)
	draw_style_box(ArenaUI.box(Color("0e1424"),Color.TRANSPARENT),Rect2(at,Vector2(bar_width,5)))
	draw_style_box(ArenaUI.box(Color("c49dff"),Color.TRANSPARENT),Rect2(at,Vector2(bar_width*clampf(float(exp_progress)/maxf(1,exp_needed),0,1),5)))
	draw_string(font,Vector2(bar_width+45,73),"%d / %d · 누적 %d"%[exp_progress,exp_needed,total_exp],HORIZONTAL_ALIGNMENT_LEFT,-1,12,ArenaUI.MUTED)
	if compact:return
	var labels: Array=["최대 HP","공격력","방어력","이동속도"];var values: Array=["+12%","+8%","+8%","+2%"]
	# Four stat chips, then the item-slot chip on the right.
	var gap: float=5;var slot_cell: float=minf(76,(size.x-gap*4)/5);var cell: float=(size.x-gap*4-slot_cell)/4
	var slot_rect:=Rect2(size.x-slot_cell,86,slot_cell,32);var gained: bool=slot_gain>0
	draw_style_box(ArenaUI.box(Color("1a2440") if gained else Color("161b28"),Color("8fc4ff",.7) if gained else Color.TRANSPARENT),slot_rect)
	draw_string(font,slot_rect.position+Vector2(5,13),"장비칸",HORIZONTAL_ALIGNMENT_LEFT,slot_cell-10,9,ArenaUI.MUTED)
	draw_string(bold,slot_rect.position+Vector2(5,28),"+%d"%slot_gain,HORIZONTAL_ALIGNMENT_LEFT,slot_cell-10,14,Color("8fc4ff") if gained else ArenaUI.MUTED)
	for i in range(4):
		# One slim chip per stat: name on the left, growth per level on the right.
		var rect:=Rect2(i*(cell+gap),86,cell,32)
		draw_style_box(ArenaUI.box(Color("15251b"),Color.TRANSPARENT),rect)
		draw_string(font,rect.position+Vector2(5,13),labels[i],HORIZONTAL_ALIGNMENT_LEFT,cell-10,9,ArenaUI.MUTED)
		draw_string(bold,rect.position+Vector2(5,28),values[i],HORIZONTAL_ALIGNMENT_LEFT,cell-10,14,Color("9fdaa2"))
