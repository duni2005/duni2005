class_name DragScroll
extends Node
## Touch drag-to-scroll for every ScrollContainer in this node's window, even when the finger
## lands on a button inside it. Picks the innermost container that scrolls along the drag's
## axis, cancels the tap on the button under the finger, and glides on release.
const SLOP: float = 12
const GROUP: StringName = &"drag_scroll"
var touch: int = -1
var fingers: Dictionary = {}
var origin: Vector2
var last: Vector2
var last_ms: int = 0
var press_ms: int = 0
var scroll: ScrollContainer
var glide: ScrollContainer
var axis: int = 0
var pos: float = 0
var velocity: float = 0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:fingers[event.index]=true
		else:fingers.erase(event.index)
		if event.pressed and fingers.size()==1:
			_end_glide();touch=event.index;origin=event.position;last=origin;last_ms=Time.get_ticks_msec();press_ms=last_ms;scroll=null;velocity=0
		elif event.pressed:_finish(false)
		elif event.index==touch:_finish(true)
	elif event is InputEventScreenDrag and event.index==touch:
		if scroll==null:
			if event.position.distance_to(origin)<SLOP:return
			_begin(event.position-origin)
			if scroll==null:touch=-1;return
		var step: float=-(event.position-last)[axis];last=event.position
		var now: int=Time.get_ticks_msec();var dt: float=maxf(.004,(now-last_ms)/1000.0);last_ms=now
		velocity=lerpf(velocity,step/dt,.5)
		_shift(step)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device==InputEvent.DEVICE_ID_EMULATION and scroll!=null:
		get_viewport().set_input_as_handled()

func _begin(moved: Vector2) -> void:
	axis=0 if absf(moved.x)>absf(moved.y) else 1
	var best: ScrollContainer=null;var depth: int=-1
	for node in get_tree().get_nodes_in_group(GROUP):
		var s: ScrollContainer=node
		if s.get_window()!=get_window() or not s.is_visible_in_tree():continue
		# Strips whose cards aim on a long press (transcendence) only scroll on a quick drag.
		if s.has_meta("hold_drag") and Time.get_ticks_msec()-press_ms>150:continue
		var bar: ScrollBar=s.get_h_scroll_bar() if axis==0 else s.get_v_scroll_bar()
		var mode: int=s.horizontal_scroll_mode if axis==0 else s.vertical_scroll_mode
		if mode==ScrollContainer.SCROLL_MODE_DISABLED or bar.max_value-bar.page<=1:continue
		var xform: Transform2D=s.get_global_transform_with_canvas()
		if not Rect2(xform.origin,s.size*xform.get_scale()).has_point(origin):continue
		var d: int=s.get_path().get_name_count()
		if d>depth:depth=d;best=s
	scroll=best
	if scroll==null:return
	pos=float(scroll.scroll_horizontal if axis==0 else scroll.scroll_vertical)
	# The finger is scrolling now, so the button it landed on must not fire.
	for b in scroll.find_children("*","BaseButton",true,false):
		var xform: Transform2D=b.get_global_transform_with_canvas()
		if not b.is_visible_in_tree() or not Rect2(xform.origin,b.size*xform.get_scale()).has_point(origin):continue
		if b.has_meta("tap_hooked"):b.set_meta("drag_canceled",true)
		elif not b.disabled:b.disabled=true;b.disabled=false
		UiMotion.release(b);b.queue_redraw()
	scroll.scroll_started.emit()

func _shift(step: float) -> bool:
	var s: ScrollContainer=glide if glide!=null else scroll;var bar: ScrollBar=s.get_h_scroll_bar() if axis==0 else s.get_v_scroll_bar()
	var before: float=pos;pos=clampf(pos+step,0,maxf(0,bar.max_value-bar.page))
	bar.value=roundf(pos)
	return not is_equal_approx(before,pos)

func _finish(released: bool) -> void:
	var was: ScrollContainer=scroll;touch=-1;scroll=null
	if was==null:return
	if released and absf(velocity)>120 and Time.get_ticks_msec()-last_ms<80:glide=was
	else:was.scroll_ended.emit()

func _end_glide() -> void:
	if glide==null:return
	var was: ScrollContainer=glide;glide=null
	if is_instance_valid(was):was.scroll_ended.emit()

func _process(delta: float) -> void:
	if glide==null:return
	if not is_instance_valid(glide) or not glide.is_visible_in_tree():glide=null;return
	velocity*=exp(-delta*4.0)
	if not _shift(velocity*delta) or absf(velocity)<40:_end_glide()
