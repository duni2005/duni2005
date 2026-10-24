class_name DeploymentBoard
extends Control
## Coordinate adapter + input/presentation only. Rules live in DeploymentPlan.
signal battle_unit_selected(actor_id: String)
var selected_actor_id: String = ""
signal selection_changed(member_id: String)
signal placement_changed(error: DeploymentRules.Code)
signal edit_started
signal edit_finished
var plan: DeploymentPlan
var enemies: Array[Dictionary] = []
var selected_id: String = ""
var editing: bool = true
var battle: BattleManager
var dragging_id: String = ""
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO
var pointer_id: int = -2
var dragged: bool = false
var erase_mode: bool = false
var presentation: CombatPresentation
func _ready() -> void:
	presentation=CombatPresentation.new();presentation.board=self;add_child(presentation)

func board_rect() -> Rect2:
	var side: float = minf(size.x, size.y)
	return Rect2((size - Vector2.ONE * side) / 2.0, Vector2.ONE * side)

func logical_point(local: Vector2) -> Vector2:
	var rect: Rect2 = board_rect()
	var point: Vector2=(local-rect.position)*800/maxf(rect.size.x,1)
	return presentation.camera.transform().affine_inverse()*point if not editing and presentation!=null else point

func select(member_id: String) -> void:
	selected_id = member_id
	selection_changed.emit(member_id)
	queue_redraw()

func _process(_delta: float) -> void:
	if is_instance_valid(battle):
		if presentation!=null and presentation.battle!=battle:presentation.attach(battle)
		var rect: Rect2 = board_rect()
		battle.position = rect.position
		battle.scale = Vector2.ONE * rect.size.x / 800.0
	elif presentation!=null and is_instance_valid(presentation.battle):presentation.cleanup()
	# The pinch zoom belongs to the turning point; ease back once the battle runs again.
	if presentation!=null and not _zoomable():presentation.camera.user_relax(_delta)
	queue_redraw()

func hit_member(point: Vector2) -> String:
	if plan == null:
		return ""
	for entry in plan.entries():
		if entry.position.distance_to(point) <= 28.0:
			return entry.member_id
	return ""

func pointer_down(local: Vector2, id: int) -> void:
	if not editing or plan == null or pointer_id != -2 or not board_rect().has_point(local):
		return
	pointer_id = id
	edit_started.emit()
	drag_origin = local
	dragged = false
	var point: Vector2 = logical_point(local)
	dragging_id = hit_member(point)
	if not dragging_id.is_empty():
		drag_offset = point - plan.get_entry(dragging_id).position
		select(dragging_id)
	else:
		drag_offset = Vector2.ZERO

func pointer_motion(local: Vector2, id: int) -> void:
	if not editing or erase_mode or pointer_id != id or dragging_id.is_empty():
		return
	if local.distance_to(drag_origin) >= 6.0:
		dragged = true
	if dragged:
		placement_changed.emit(plan.move(dragging_id, logical_point(local) - drag_offset))
		queue_redraw()

func pointer_up(local: Vector2, id: int, canceled: bool = false) -> void:
	if pointer_id != id:
		return
	if editing and not canceled:
		if erase_mode:
			var erased: String=hit_member(logical_point(local))
			if not erased.is_empty():plan.remove(erased);placement_changed.emit(DeploymentRules.Code.OK)
		elif dragged and not dragging_id.is_empty():
			placement_changed.emit(plan.move(dragging_id, logical_point(local) - drag_offset))
		elif dragging_id.is_empty() and not selected_id.is_empty() and board_rect().has_point(local):
			var point: Vector2 = logical_point(local)
			var error: DeploymentRules.Code = plan.move(selected_id, point) if plan.get_entry(selected_id) != null else plan.place(selected_id, point)
			placement_changed.emit(error)
	pointer_id = -2
	dragging_id = ""
	dragged = false
	edit_finished.emit()
	queue_redraw()

## Two-finger pinch (and mouse wheel / trackpad pinch) zooms the field during a turning point.
var touches: Dictionary={}
var pinch_span: float=0
var pinch_mid:=Vector2.ZERO
func _zoomable() -> bool:
	return not editing and is_instance_valid(battle) and battle.clock.is_turning_paused() and presentation!=null
func _board_space(local: Vector2) -> Vector2:
	var rect: Rect2=board_rect();return (local-rect.position)*800/maxf(rect.size.x,1)
func _pinch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:touches[event.index]=event.position
		else:touches.erase(event.index)
		if touches.size()==2:
			var points: Array=touches.values();pinch_span=points[0].distance_to(points[1]);pinch_mid=(points[0]+points[1])*.5
		return touches.size()>=2
	if event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index]=event.position
		if touches.size()==2 and _zoomable():
			var points: Array=touches.values();var span: float=points[0].distance_to(points[1]);var mid: Vector2=(points[0]+points[1])*.5
			var cam: ArenaCameraController=presentation.camera
			if pinch_span>8:cam.user_zoom_by(span/pinch_span,_board_space(mid))
			cam.user_pan_by(_board_space(mid)-_board_space(pinch_mid))
			pinch_span=span;pinch_mid=mid;return true
		return touches.size()>=2
	if _zoomable() and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		presentation.camera.user_zoom_by(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.12,_board_space(event.position));return true
	if _zoomable() and event is InputEventMagnifyGesture:
		presentation.camera.user_zoom_by(event.factor,_board_space(event.position));return true
	return false

## One-finger (or mouse) drag pans the zoomed field during a turning point.
var pan_down: bool=false
var pan_moved: bool=false
var pan_from:=Vector2.ZERO
var pan_last:=Vector2.ZERO
func _pan(event: InputEvent) -> bool:
	var button: bool=event is InputEventScreenTouch or (event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT)
	if button:
		pan_down=event.pressed and touches.size()<2;pan_from=event.position;pan_last=event.position;pan_moved=false;return false
	var motion: bool=event is InputEventScreenDrag or (event is InputEventMouseMotion and event.device!=-1)
	if not motion or not pan_down or touches.size()>=2:return false
	if not pan_moved and event.position.distance_to(pan_from)>8:pan_moved=true
	if pan_moved:presentation.camera.user_pan_by(_board_space(event.position)-_board_space(pan_last))
	pan_last=event.position;return true
func _gui_input(event: InputEvent) -> void:
	if _pinch(event):pan_down=false;accept_event();return
	if _zoomable() and _pan(event):accept_event();return
	if not editing and is_instance_valid(battle) and battle.full_characters_enabled:
		var pressed: bool=(event is InputEventMouseButton and event.device!=-1 and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
		if pressed and board_rect().has_point(event.position):
			var point: Vector2=logical_point(event.position)
			for u in battle.units:
				if u.alive and u.position.distance_to(point)<=28*u.combat_scale():selected_actor_id="" if selected_actor_id==u.actor_id() else u.actor_id();battle_unit_selected.emit(selected_actor_id);accept_event();return
	if not editing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down(event.position, -1)
		else:
			pointer_up(event.position, -1)
		accept_event()
	elif event is InputEventMouseMotion:
		pointer_motion(event.position, -1)
	elif event is InputEventScreenTouch:
		if event.pressed:
			pointer_down(event.position, event.index)
		else:
			pointer_up(event.position, event.index, event.canceled)
		accept_event()
	elif event is InputEventScreenDrag:
		pointer_motion(event.position, event.index)
		accept_event()

func _draw() -> void:
	if not editing or plan == null:
		return
	var rect: Rect2 = board_rect()
	var factor: float = rect.size.x / 800.0
	draw_set_transform(rect.position, 0.0, Vector2.ONE * factor)
	VisualShapes.arena(self)
	draw_rect(Rect2(40,40,340,720),Color(.35,.5,.95,.09))
	draw_rect(Rect2(40,40,340,720),Color("7f9cd6"),false,2)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(48, 25), "아군 배치 영역", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bcc6e0"))
	for enemy in enemies:
		_draw_token(enemy.position, enemy.data, "적", float(enemy.get("current_hp", enemy.data.max_hp)), Color("ff947d"), false, enemy.combat_stats.max_hp if enemy.get("combat_stats") != null else enemy.data.max_hp)
	for entry in plan.entries():
		var member: GuildMemberState = plan.guild.get_member(entry.member_id)
		if member != null:
			_draw_token(entry.position, plan.guild.definition(member.unit_type_id), ArenaUI.stance(member.stance)+" "+ArenaUI.member_label(entry.member_id), member.current_hp, Color("88b7ff"), entry.member_id == selected_id, plan.guild.member_max_hp(member))
	draw_set_transform(Vector2.ZERO)

func _draw_token(at: Vector2, data: UnitData, id: String, hp: float, color: Color, selected: bool, hp_limit: float = -1) -> void:
	var font: Font = ThemeDB.fallback_font
	if hp_limit < 0: hp_limit = data.max_hp
	var rect: Rect2=board_rect();var factor: float=rect.size.x/800
	UnitIcon.draw(self,Rect2(at-Vector2.ONE*27,Vector2.ONE*54),data.type_id)
	if selected:draw_arc(at,34,0,TAU,32,ArenaUI.GOLD,2)
	draw_rect(Rect2(at + Vector2(-28, -40), Vector2(56, 5)), Color("202a44"))
	draw_rect(Rect2(at + Vector2(-28, -40), Vector2(56 * clampf(hp / hp_limit, 0, 1), 5)), color)
	if selected:draw_string(font, at + Vector2(-27, -45), "HP %d" % ceili(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if selected:draw_string(font, at + Vector2(-27, 43), id, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
