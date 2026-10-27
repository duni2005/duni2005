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
	if age>(2.0 if cue=="turning" else 1.8):cue=""
	queue_redraw()
func _draw() -> void:
	if cue.is_empty() or not is_instance_valid(board):return
	var rect: Rect2=board.get_global_rect();rect.position-=global_position
	var side: float=minf(rect.size.x,rect.size.y);rect=Rect2(rect.get_center()-Vector2.ONE*side*.5,Vector2.ONE*side)
	var tint:=Color("8fe3ff") if cue in ["turning","hold","resume"] else Color("f3d48e") if cue in ["start","victory"] else Color("ea9a88")
	var life: float=2 if cue=="turning" else 1.8
	var alpha: float=minf(clampf(age/.12,0,1),clampf((life-age)/.35,0,1))
	if cue in ["victory","defeat"]:
		draw_rect(Rect2(Vector2.ZERO,size),Color(tint,alpha*.16));return
	if cue=="turning":
		CinematicArtwork.paint(self,rect,"turning",turning_age)
		return
	# Strategy phase: the panel below says it all, nothing is drawn over the field.
	if cue=="hold":return
	# Battle start: slanted panels sweep across the field, the title rises letter by letter and the
	# panels sweep off again within the cue's life.
	var center: Vector2=rect.get_center();var strip:=Rect2(rect.position.x,center.y-38,rect.size.x,76)
	var k: float=age/life if UiMotion.enabled else 99.0;var a: float=alpha if not UiMotion.enabled else 1-Motion.phase(k,.62,.25)
	if UiMotion.enabled:TypeArt.panels(self,strip,k,false,[TypeArt.NAVY,TypeArt.INDIGO,Color(.03,.04,.08,.94)],.6,tint)
	else:draw_rect(strip,Color(.03,.04,.08,.92*alpha))
	var font: Font=ArenaUI.heading_font();var title: String={"start":"전투 시작"}.get(cue,"")
	var title_w: float=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
	TypeArt.letters(self,font,title,Vector2(center.x-title_w*.5,center.y+2),24,Color(tint,a),age-.12 if UiMotion.enabled else 99.0,14)
	draw_string(get_theme_default_font(),Vector2(strip.position.x,center.y+26),"길드원의 전투가 시작됩니다",HORIZONTAL_ALIGNMENT_CENTER,strip.size.x,12,Color("e2e7f5",a*Motion.phase(age,.25,.2)))
