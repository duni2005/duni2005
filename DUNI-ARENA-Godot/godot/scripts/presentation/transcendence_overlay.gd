class_name TranscendenceOverlay
extends Control
## Screen-space gesture feedback; owns no command, gauge or gameplay timer.
var screen: Control # Any screen exposing `battle` and `trans_press` (room or custom battle).
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);z_index=20
func _process(_dt: float) -> void:queue_redraw()
func _draw() -> void:
	if screen==null or not is_instance_valid(screen.battle):return
	var trans: TranscendenceController=screen.battle.transcendence
	if trans==null:return
	if not trans.cast.is_empty():
		var t: float=trans.cast.time
		draw_rect(Rect2(Vector2.ZERO,size),Color(.18,.05,.28,.22 if t<.38 else .08))
		if t>=.38 and t<=.58:draw_rect(Rect2(Vector2.ZERO,size),Color(.83,.7,1,(.58-t)*.5))
	if not screen.trans_press.is_empty():
		var p: Dictionary=screen.trans_press;var origin: Vector2=p.origin-global_position
		var progress: float=clampf(float(p.held)/.16,0,1)
		draw_arc(origin,32,0,TAU,32,Color(.8,.65,1,.35),2);draw_arc(origin,37,-PI/2,-PI/2+TAU*progress,32,Color("d7a8ff"),3)
		if p.activated:
			var at: Vector2=p.point-global_position
			draw_line(origin,at,Color("d7a8ff"),3)
			var note: String="방향 선택 → 놓으면 시전" if not trans.aim.is_empty() and trans.aim.outside else "원 안에서 놓으면 취소"
			draw_string(ThemeDB.fallback_font,Vector2(20,size.y-26),note,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e3c5ff"))
