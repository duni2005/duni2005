class_name BattleCueOverlay
extends Control
## Real-time banner/scan accents only. Does not pause or advance battle simulation.
var board: DeploymentBoard
var bound_battle: BattleManager
var cue: String=""
var age: float=0
var previous_state: int=-1
var ended: bool=false
var turning_age: float=0
func _ready() -> void:
	# Keep arena accents behind the result dialog (z=20), including its buttons.
	mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=15;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func observe(value,dt: float) -> void:
	if not is_instance_valid(value) or not value.started:
		cue="";bound_battle=null;queue_redraw();return
	if value!=bound_battle:
		bound_battle=value;cue="start";age=0;previous_state=-1;ended=false;turning_age=0
	else:age+=maxf(0,dt)
	if value.finished and not ended:
		ended=true;cue="";queue_redraw();return
	elif not value.finished and value.clock.state!=previous_state:
		if value.clock.state==BattleClock.State.TURNING_SLOWDOWN:cue="turning";age=0;turning_age=0
		elif value.clock.state==BattleClock.State.TURNING_PAUSED:cue="hold";age=0;turning_age=maxf(2,turning_age)
		elif previous_state==BattleClock.State.TURNING_PAUSED:cue="";age=0
	if cue in ["turning","hold"]:turning_age+=maxf(0,dt)
	previous_state=value.clock.state
	if cue in ["turning","hold"]:
		queue_redraw();return
	if age>(2.0 if cue=="turning" else 1.15):cue=""
	queue_redraw()
func _draw() -> void:
	if cue.is_empty() or not is_instance_valid(board):return
	var rect: Rect2=board.get_global_rect();rect.position-=global_position
	var side: float=minf(rect.size.x,rect.size.y);rect=Rect2(rect.get_center()-Vector2.ONE*side*.5,Vector2.ONE*side)
	var tint:=Color("8fe3ff") if cue in ["turning","hold","resume"] else Color("f3d48e") if cue in ["start","victory"] else Color("ea9a88")
	var life: float=2 if cue=="turning" else 1.15
	var alpha: float=minf(clampf(age/.12,0,1),clampf((life-age)/.35,0,1))
	if cue in ["victory","defeat"]:
		draw_rect(rect,Color(tint,alpha*.16));return
	if cue=="turning":
		CinematicArtwork.paint(self,rect,"turning",turning_age)
		return
	if cue=="hold":
		# Strategy phase: the board shrinks for the panel, so the big title gives way to a
		# small tag at the board's top edge and a light cold tint.
		var settle: float=clampf(age/.3,0,1)
		draw_rect(rect,Color(.02,.05,.11,.18*settle))
		var font: Font=ArenaUI.heading_font();var label: String="터닝포인트 · 전략 선택"
		var w: float=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+44
		var chip:=Rect2(Vector2(rect.get_center().x-w*.5,rect.position.y+8-(1-settle)*10),Vector2(w,28))
		draw_style_box(ArenaUI.box(Color(.03,.05,.09,.88*settle),Color(tint,.75*settle)),chip)
		var clock: Vector2=chip.position+Vector2(16,14)
		draw_arc(clock,7,0,TAU,24,Color(tint,settle),1.5,true);draw_line(clock,clock+Vector2.from_angle(-PI/2+turning_age*2)*5,Color(tint,settle),1.5,true)
		draw_string(font,chip.position+Vector2(30,19),label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(tint,settle))
		return
	var center: Vector2=rect.get_center();var width: float=minf(420,rect.size.x-20);var band:=Rect2(center-Vector2(width*.5,38),Vector2(width,76))
	if cue=="hold":band.position.y=rect.position.y+12
	draw_style_box(ArenaUI.box(Color(.03,.04,.08,alpha*.9),Color(tint,alpha*.8)),band)
	for side_index in [-1,1]:
		var at: Vector2=band.get_center()+Vector2(side_index*(width*.5-12),0)
		draw_polyline(PackedVector2Array([at+Vector2(-side_index*8,-12),at,at+Vector2(-side_index*8,12)]),Color(tint,alpha),2,true)
	var title: String={"start":"전투 시작"}.get(cue,"")
	var subtitle: String="길드원의 전투가 시작됩니다"
	draw_string(get_theme_default_font(),band.position+Vector2(12,32),title,HORIZONTAL_ALIGNMENT_CENTER,width-24,22,Color(tint,alpha))
	draw_string(get_theme_default_font(),band.position+Vector2(12,56),subtitle,HORIZONTAL_ALIGNMENT_CENTER,width-24,12,Color("e2e7f5",alpha))
