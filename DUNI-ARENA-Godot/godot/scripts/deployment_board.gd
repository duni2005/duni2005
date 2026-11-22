class_name DeploymentBoard
extends Control
## Coordinate adapter + input/presentation only. Rules live in DeploymentPlan.
signal battle_unit_selected(actor_id: String)
var selected_actor_id: String = ""
var strategy_actor_id: String = "" # enemy whose turning-point strategy card is open
## A unit card is held: the units it can be played on (actor ids) are highlighted.
var card_focus_on: bool = false
var card_focus_ids: Array = []
signal selection_changed(member_id: String)
signal placement_changed(error: DeploymentRules.Code)
signal edit_started
signal edit_finished
## A unit on the field was tapped for its description: an already selected ally, an enemy
## preview, or the selected unit again in battle. member_id is empty for enemies.
## `subject` is what the 상태 tab reads: the battle unit, the room enemy or the guild member.
signal unit_info_requested(unit_type: int, member_id: String, stats: UnitCombatStats, subject)
var tapped_selected: bool = false
var plan: DeploymentPlan
var enemies: Array[Dictionary] = []
## The room's 시련: their weather and the enemies' marks fade in from `trial_reveal` 0 (seconds,
## negative while waiting); `trial_elite` is the enemy 정예 부대 promoted.
var trials: Array = []
var trial_reveal: float = 0
var trial_elite: String = ""
const TRIAL_FADE: float = 1.5
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

## Arena units across the board rect: 800-unit board space while placing; in battle the camera's
## view for the map (ArenaMap.VIEWS), so characters look a little smaller on a bigger garden.
func view_side() -> float:
	return ArenaMap.VIEWS[battle.map] if not editing and is_instance_valid(battle) else ArenaMap.BOARD
## Side of the garden (사각 정원 · 소/중/대) the board shows.
func floor_side() -> float:
	return ArenaMap.SIDES[battle.map] if not editing and is_instance_valid(battle) else ArenaMap.BOARD
## Arena units the floor drawing spans across the board rect: the camera view in battle, the
## whole garden while placing.
func floor_span() -> float:
	return view_side() if not editing and is_instance_valid(battle) else floor_side()

## Arena point to screen (global) and back; arena units per screen pixel.
func screen_point(logical: Vector2) -> Vector2:
	return get_global_transform() * presentation.parent_transform * logical
func logical_from_screen(global_point: Vector2) -> Vector2:
	return presentation.parent_transform.affine_inverse() * (get_global_transform().affine_inverse() * global_point)
func pixels_per_unit() -> float:
	return (get_global_transform() * presentation.parent_transform).x.length()
func logical_point(local: Vector2) -> Vector2:
	var rect: Rect2 = board_rect()
	var point: Vector2=(local-rect.position)*view_side()/maxf(rect.size.x,1)
	if editing:return edit_transform().affine_inverse()*point
	return presentation.camera.transform().affine_inverse()*point if presentation!=null else point

## 준비 시간: the placing view zooms (pinch / wheel) and pans (drag on empty ground when zoomed).
## edit_focus is the board point that stays fixed while zoomed.
var edit_zoom: float = 1
var edit_focus := Vector2(400, 400)
var edit_panned: bool = false
var edit_pan_from := Vector2.ZERO
var edit_pan_last := Vector2.ZERO
func edit_transform() -> Transform2D:
	return Transform2D(0, Vector2.ONE * edit_zoom, 0, edit_focus * (1 - edit_zoom))
## Board space to screen while placing (floor drawings add their own garden scale on top).
func edit_canvas() -> Transform2D:
	var rect: Rect2 = board_rect()
	return Transform2D(0, Vector2.ONE * rect.size.x / ArenaMap.BOARD, 0, rect.position) * edit_transform()
## A bigger garden is drawn smaller while placing, so it may be zoomed in further.
func edit_zoom_max() -> float:return 2.2 * floor_side() / ArenaMap.BOARD
func edit_zoom_by(factor: float, screen_point: Vector2) -> void:
	var before: float = edit_zoom;edit_zoom = clampf(edit_zoom * factor, 1, edit_zoom_max())
	if edit_zoom <= 1.001:edit_zoom = 1;queue_redraw();return
	var anchor: Vector2 = edit_focus + (screen_point - edit_focus) / before if before > 1.001 else screen_point
	edit_focus = ((anchor * edit_zoom - screen_point) / (edit_zoom - 1)).clamp(Vector2.ZERO, Vector2.ONE * ArenaMap.BOARD);queue_redraw()
func edit_pan_by(screen_delta: Vector2) -> void:
	if edit_zoom <= 1.001:return
	edit_focus = (edit_focus - screen_delta / (edit_zoom - 1)).clamp(Vector2.ZERO, Vector2.ONE * ArenaMap.BOARD);queue_redraw()
## Whether a finger currently holds a unit (subclasses track their own drag).
func grabbing() -> bool:return not dragging_id.is_empty()
func _edit_view(event: InputEvent) -> bool:
	var button: bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if button:
		if event.pressed:edit_pan_from = event.position;edit_pan_last = event.position;edit_panned = false;return false
		if edit_panned:
			edit_panned = false;pointer_up(event.position, event.index if event is InputEventScreenTouch else -1, true);return true
		return false
	var motion: bool = event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT)
	if not motion or touches.size() >= 2 or edit_zoom <= 1.001 or grabbing() or pointer_id == -2:return false
	if not edit_panned and event.position.distance_to(edit_pan_from) > 10:edit_panned = true
	if edit_panned:edit_pan_by(_board_space(event.position) - _board_space(edit_pan_last))
	edit_pan_last = event.position
	return edit_panned

func select(member_id: String) -> void:
	selected_id = member_id
	selection_changed.emit(member_id)
	queue_redraw()

func _process(_delta: float) -> void:
	if editing and not trials.is_empty():trial_reveal += _delta;queue_redraw()
	if is_instance_valid(battle):
		if presentation!=null and presentation.battle!=battle:presentation.attach(battle)
		var rect: Rect2 = board_rect()
		battle.position = rect.position
		battle.scale = Vector2.ONE * rect.size.x / view_side()
	elif presentation!=null and is_instance_valid(presentation.battle):presentation.cleanup()
	# Pinch limit: the turning point allows the most; in battle it depends on the map. A turning
	# point zoom eases back to the battle limit once the battle runs again.
	if presentation!=null:
		var cam: ArenaCameraController=presentation.camera
		var turning: bool=is_instance_valid(battle) and battle.clock.is_turning_paused()
		cam.user_zoom_max=ArenaCameraController.USER_ZOOM_MAX if turning else ArenaMap.ZOOMS[battle.map] if is_instance_valid(battle) else 1.0
		if not _zoomable():cam.user_relax(_delta)
		elif cam.user_zoom>cam.user_zoom_max:cam.user_relax(_delta,cam.user_zoom_max)
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
	tapped_selected = not dragging_id.is_empty() and dragging_id == selected_id
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
		elif tapped_selected:
			var member: GuildMemberState = plan.guild.get_member(dragging_id)
			if member != null:unit_info_requested.emit(member.unit_type_id, dragging_id, null, member)
		elif dragging_id.is_empty() and board_rect().has_point(local):
			var point: Vector2 = logical_point(local);var foe: Dictionary = {}
			for enemy in enemies:
				if enemy.position.distance_to(point) <= 28.0:foe = enemy
			if not foe.is_empty():unit_info_requested.emit(foe.data.type_id, "", foe.get("combat_stats"), foe.get("enemy"))
			elif not selected_id.is_empty():
				var error: DeploymentRules.Code = plan.move(selected_id, point) if plan.get_entry(selected_id) != null else plan.place(selected_id, point)
				placement_changed.emit(error)
	pointer_id = -2
	dragging_id = ""
	dragged = false
	edit_finished.emit()
	queue_redraw()

## Two-finger pinch (and mouse wheel / trackpad pinch) zooms the field: in battle (most during a
## turning point) and while placing.
var touches: Dictionary={}
var pinch_span: float=0
var pinch_mid:=Vector2.ZERO
func _zoomable() -> bool:
	return not editing and is_instance_valid(battle) and not battle.finished and presentation!=null
func _board_space(local: Vector2) -> Vector2:
	var rect: Rect2=board_rect();return (local-rect.position)*view_side()/maxf(rect.size.x,1)
func _pinch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:touches[event.index]=event.position
		else:touches.erase(event.index)
		if touches.size()==2:
			var points: Array=touches.values();pinch_span=points[0].distance_to(points[1]);pinch_mid=(points[0]+points[1])*.5
			# A second finger turns a placing touch into a pinch: the first touch places nothing.
			if editing and pointer_id!=-2:pointer_up(event.position,pointer_id,true)
		return touches.size()>=2
	if event is InputEventScreenDrag and touches.has(event.index):
		touches[event.index]=event.position
		if touches.size()==2 and editing:
			var points: Array=touches.values();var span: float=points[0].distance_to(points[1]);var mid: Vector2=(points[0]+points[1])*.5
			if pinch_span>8:edit_zoom_by(span/pinch_span,_board_space(mid))
			edit_pan_by(_board_space(mid)-_board_space(pinch_mid))
			pinch_span=span;pinch_mid=mid;return true
		if touches.size()==2 and _zoomable():
			var points: Array=touches.values();var span: float=points[0].distance_to(points[1]);var mid: Vector2=(points[0]+points[1])*.5
			var cam: ArenaCameraController=presentation.camera
			if pinch_span>8:cam.user_zoom_by(span/pinch_span,_board_space(mid))
			cam.user_pan_by(_board_space(mid)-_board_space(pinch_mid))
			pinch_span=span;pinch_mid=mid;return true
		return touches.size()>=2
	if editing and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		edit_zoom_by(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.12,_board_space(event.position));return true
	if editing and event is InputEventMagnifyGesture:
		edit_zoom_by(event.factor,_board_space(event.position));return true
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
			# An enemy's strategy badge over its head counts as tapping that enemy.
			var badge: BattleUnit=EnemyStrategyView.badge_hit(battle,presentation.parent_transform,event.position,get_theme_default_font())
			var inspected: String=strategy_actor_id;strategy_actor_id=""
			for u in battle.units:
				if badge!=null and u!=badge:continue
				if not u.alive or badge==null and u.position.distance_to(point)>28*u.combat_scale():continue
				# First tap on an enemy with a strategy opens its card; the next opens the unit sheet.
				if EnemyStrategyView.plan_for(battle,u.actor_id())!=null:
					if inspected==u.actor_id():unit_info_requested.emit(u.data.type_id,"",null,u)
					else:strategy_actor_id=u.actor_id()
					# It is also chosen as the target of unit cards.
					selected_actor_id=u.actor_id();battle_unit_selected.emit(selected_actor_id)
					accept_event();return
				# Tapping the selected unit again opens its description.
				if selected_actor_id==u.actor_id():unit_info_requested.emit(u.data.type_id,u.source_member_id if u.original_team==0 else "",null,u);accept_event();return
				selected_actor_id=u.actor_id();battle_unit_selected.emit(selected_actor_id);accept_event();return
	if not editing:
		return
	if _edit_view(event):accept_event();return
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
	draw_set_transform_matrix(edit_canvas())
	VisualShapes.arena(self)
	var trial_k: float = clampf(trial_reveal / TRIAL_FADE, 0, 1) if not trials.is_empty() else 0.0
	var time: float = Time.get_ticks_msec() * .001
	if trial_k > 0:TrialArt.field(self, trials, 800, time, trial_k)
	draw_rect(Rect2(40,40,340,720),Color(.35,.5,.95,.09))
	draw_rect(Rect2(40,40,340,720),Color("7f9cd6"),false,2)
	var font: Font = ArenaUI.heading_font()
	draw_string(font, Vector2(48, 25), "아군 배치 영역", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bcc6e0"))
	for enemy in enemies:
		var room_enemy = enemy.get("enemy");var spawn: EnemySpawnEntry=room_enemy.spawn if room_enemy != null else null
		var kinds: Array=spawn.items if spawn != null else []
		var mark_r: float = maxf(TOKEN_ICON * .5, 14.0 / maxf(.2, edit_canvas().get_scale().x)) * float(RANK_SIZE.get(spawn.rank if spawn != null else &"normal", 1.0))
		if trial_k > 0:TrialArt.unit_ground(self, enemy.position, mark_r, trials, time, enemies.find(enemy))
		_draw_token(enemy.position, enemy.data, enemy.data.display_name, float(enemy.get("current_hp", enemy.data.max_hp)), false, false, enemy.combat_stats.max_hp if enemy.get("combat_stats") != null else enemy.data.max_hp, kinds, spawn.rank if spawn != null else &"normal")
		if trial_k > 0:
			TrialArt.unit_over(self, enemy.position, mark_r, trials, time, enemies.find(enemy))
			if spawn != null and spawn.enemy_id == trial_elite:TrialArt.elite_mark(self, enemy.position, mark_r, time)
	for entry in plan.entries():
		var member: GuildMemberState = plan.guild.get_member(entry.member_id)
		if member != null:
			var kinds: Array=plan.guild.state.inventory.filter(func(i):return not i.consumed and i.equipped_to_member_id==member.member_id).map(func(i):return i.kind)
			_draw_token(entry.position, plan.guild.definition(member.unit_type_id), plan.guild.definition(member.unit_type_id).display_name, member.current_hp, true, entry.member_id == selected_id, plan.guild.member_max_hp(member), kinds)
	draw_set_transform(Vector2.ZERO)

## A unit on the deployment field (0.99.7): the icon in a ring of its rarity colour (영웅 · 전설 with
## a few sparks around it), the HP bar above, the items it wears in small slots above the bar,
## the name under it (allies blue, enemies red). 미니보스 are larger, 보스 larger still with a crown
## and rising embers.
const TOKEN_ICON := 54.0
const RANK_SIZE = {&"normal": 1.0, &"elite": 1.2, &"boss": 1.45}
const ALLY_NAME := Color("8fc4ff")
const ENEMY_NAME := Color("ff8a8a")
func _draw_token(at: Vector2, data: UnitData, title: String, hp: float, ally: bool, selected: bool, hp_limit: float = -1, items: Array = [], rank: StringName = &"normal") -> void:
	if hp_limit < 0: hp_limit = data.max_hp
	# Logical units per screen pixel: text, bars and item slots keep a readable size on a phone.
	var px: float = 1.0 / maxf(.2, edit_canvas().get_scale().x)
	var k: float = float(RANK_SIZE.get(rank, 1.0));var r: float = maxf(TOKEN_ICON * .5, 14 * px) * k
	var tier: int = UnitRarity.tier(data.type_id);var ring: Color = UnitRarity.color(data.type_id)
	var t: float = Time.get_ticks_msec() * .001
	if rank == &"boss":
		VfxArt.glow(self, at, r * 2.6, Color("ff7a3a"), .22 + .06 * sin(t * 3))
		for n in range(6):
			var s: float = fposmod(t * .5 + n / 6.0, 1.0)
			draw_circle(at + Vector2(sin(n * 2.1 + t) * r * .9, r * .6 - s * r * 2.4), 2.2 * (1 - s) + .6, Color(1, .62, .25, .8 * (1 - s)))
	elif tier >= 4:
		VfxArt.glow(self, at, r * 1.9, ring, .12)
	if tier >= 4:
		for n in range(4 if tier == 4 else 6):
			var a: float = t * (1.1 if tier == 4 else 1.5) + n * TAU / (4 if tier == 4 else 6)
			draw_circle(at + Vector2.from_angle(a) * (r + 6), 1.8, Color(ring.lightened(.4), .85))
	draw_circle(at, r + 3, Color("0b1120"))
	UnitIcon.draw(self, Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2), data.type_id)
	draw_arc(at, r + 3, 0, TAU, 40, ring, 3.0 if tier >= 3 else 2.0, true)
	if selected:draw_arc(at, r + 8, 0, TAU, 40, ArenaUI.GOLD, 2.5, true)
	if rank == &"boss":ArenaIcon.draw(self, at + Vector2(0, -r - 8), "boss", 30 * k * .8, Color.WHITE)
	elif rank == &"elite":ArenaIcon.draw(self, at + Vector2(r * .85, -r * .85), "miniboss", 20, Color.WHITE)
	# HP bar above the icon, the item slots above the bar.
	var bar_w: float = maxf(56, r * 2.1);var bar_h: float = maxf(6, 4 * px);var bar_y: float = at.y - r - (22 if rank == &"boss" else 8) - bar_h
	draw_rect(Rect2(at.x - bar_w * .5, bar_y, bar_w, bar_h), Color("202a44"))
	draw_rect(Rect2(at.x - bar_w * .5, bar_y, bar_w * clampf(hp / hp_limit, 0, 1), bar_h), Color("7fe0a0") if ally else Color("ff6b6b"))
	draw_rect(Rect2(at.x - bar_w * .5, bar_y, bar_w, bar_h), Color(0, 0, 0, .6), false, 1)
	if not items.is_empty():
		var slot: float = maxf(15, 13 * px);var gap: float = maxf(2, 1.5 * px);var total: float = items.size() * slot + (items.size() - 1) * gap
		for n in range(items.size()):
			var box := Rect2(Vector2(at.x - total * .5 + n * (slot + gap), bar_y - slot - 3), Vector2(slot, slot))
			var grade: Color = ItemCatalog.grade_color(StringName(items[n]))
			draw_rect(box, Color("0e1424"));draw_rect(box, grade, false, 1.5)
			ArenaIcon.draw(self, box.get_center(), String(items[n]), slot * .85, Color.WHITE)
	# Name under the icon.
	var font: Font = ArenaUI.heading_font();var size: int = int(maxf(15, 10.5 * px)) if rank == &"normal" else int(maxf(17, 12 * px))
	var col: Color = ALLY_NAME if ally else ENEMY_NAME
	var name_y: float = at.y + r + 4 + size
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, Vector2(at.x - 100, name_y) + o * px * .8, title, HORIZONTAL_ALIGNMENT_CENTER, 200, size, Color(0, 0, 0, .85))
	draw_string(font, Vector2(at.x - 100, name_y), title, HORIZONTAL_ALIGNMENT_CENTER, 200, size, col)
