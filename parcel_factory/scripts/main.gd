extends Node2D
## 샌드박스 메인: 공장·화면·카메라·UI를 만들고 터치 입력을 처리해요.
## 조작
##   한 손가락 끌기 : 화면 이동 (설치 중인 레일·전선·파이프는 끌어서 깔기)
##   두 손가락      : 확대·축소와 이동
##   탭            : 보기 = 설비 선택 / 설치 = 놓기 / 철거 = 지우기

const TILE := 32.0
const HUD := preload("res://scripts/view/hud.gd")
const WorldView := preload("res://scripts/view/world_view.gd")
const Demo := preload("res://scripts/demo.gd")

var factory: Factory
var view
var cam: Camera2D
var hud

var tool: String = "view"          # view / build / erase
var build_def: String = "레일 Mk1"
var rot: int = 0

var _touches := {}
var _drag_start := Vector2.ZERO
var _moved := false
var _multi := false
var _last_cell := Vector2i(0, 0)
var _pinch_dist := 0.0
var _pinch_center := Vector2.ZERO


func _ready() -> void:
	factory = Factory.new()
	factory.name = "Factory"
	add_child(factory)
	view = WorldView.new()
	view.factory = factory
	add_child(view)
	cam = Camera2D.new()
	cam.zoom = Vector2(1.4, 1.4)
	cam.position = Vector2(16, 8) * TILE
	add_child(cam)
	cam.make_current()
	hud = HUD.new()
	hud.main = self
	add_child(hud)
	Demo.build(factory)


# ---------- 도구 ----------

func set_tool(t: String) -> void:
	tool = t
	if t != "build":
		view.ghost = {}
	if t != "view":
		view.selected = null
	hud.refresh_tool_buttons()


func select_build(def_name: String) -> void:
	build_def = def_name
	set_tool("build")


func rotate_tool() -> void:
	rot = (rot + 1) % 4
	if tool == "view" and view.selected != null and view.selected.size == Vector2i.ONE:
		factory.rotate_conveyor(view.selected, (view.selected.rot + 1) % 4)
	if not view.ghost.is_empty():
		view.ghost["rot"] = rot
		_update_ghost(view.ghost["pos"])


func is_drag_def() -> bool:
	return bool(DB.buildings[build_def].get("drag", false))


func screen_to_cell(sp: Vector2) -> Vector2i:
	var wp: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * sp
	return Vector2i(floori(wp.x / TILE), floori(wp.y / TILE))


func _update_ghost(c: Vector2i) -> void:
	if tool != "build":
		return
	var def: Dictionary = DB.buildings[build_def]
	view.ghost = {"def": def, "pos": c, "rot": rot, "ok": factory.can_place(def, c, rot)}


func _place(c: Vector2i) -> void:
	factory.place(build_def, c, rot)
	_update_ghost(c)


func _erase(c: Vector2i) -> void:
	if factory.remove_at(c):
		if view.selected != null and not factory.buildings.has(view.selected):
			view.selected = null
		return
	for layer in ["wire", "pipe", "water"]:
		if factory.remove_layer(layer, c):
			return


func _tap(sp: Vector2) -> void:
	var c := screen_to_cell(sp)
	match tool:
		"view":
			view.selected = factory.get_at(c)
			hud.show_inspector(view.selected)
		"build":
			if not is_drag_def():
				_place(c)
		"erase":
			_erase(c)


func _drag_path(c: Vector2i) -> void:
	## 손가락이 지나간 칸마다 레일을 놓고, 지나온 방향으로 레일 방향을 맞춰요
	var guard := 0
	while _last_cell != c and guard < 200:
		guard += 1
		var diff := c - _last_cell
		var step := Vector2i(signi(diff.x), 0) if absi(diff.x) >= absi(diff.y) else Vector2i(0, signi(diff.y))
		var r: int = Building.DIRV.find(step)
		var def: Dictionary = DB.buildings[build_def]
		if def["kind"] not in Factory.LAYER_KINDS:
			var prev = factory.get_at(_last_cell)
			if prev != null and prev.name == build_def and prev.is_conveyor():
				factory.rotate_conveyor(prev, r)
			rot = r
		_last_cell += step
		_place(_last_cell)


# ---------- 입력 ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.1, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.1, mb.position)
	elif event is InputEventMouseMotion and tool == "build" and _touches.is_empty():
		var mm := event as InputEventMouseMotion
		if not hud.is_over_ui(mm.position):
			_update_ghost(screen_to_cell(mm.position))


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if _touches.is_empty() and hud.is_over_ui(e.position):
			return
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_drag_start = e.position
			_moved = false
			_multi = false
			_last_cell = screen_to_cell(e.position)
			_update_ghost(_last_cell)
			if tool == "build" and is_drag_def():
				_place(_last_cell)
			elif tool == "erase":
				_erase(_last_cell)
		elif _touches.size() == 2:
			_multi = true
			_start_pinch()
	else:
		if not _touches.has(e.index):
			return
		_touches.erase(e.index)
		if _touches.is_empty():
			if not _moved and not _multi and tool != "erase":
				_tap(e.position)
		elif _touches.size() == 1:
			_pinch_dist = 0.0


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	_touches[e.index] = e.position
	if _touches.size() >= 2:
		_do_pinch()
		return
	if _multi:
		return
	if not _moved and (e.position - _drag_start).length() > 14.0:
		_moved = true
	if not _moved:
		return
	var c := screen_to_cell(e.position)
	if tool == "build" and is_drag_def():
		_drag_path(c)
	elif tool == "erase":
		if c != _last_cell:
			_last_cell = c
			_erase(c)
	else:
		cam.position -= e.relative / cam.zoom.x


func _pinch_points() -> Array:
	var pts := []
	for k in _touches:
		pts.append(_touches[k])
		if pts.size() == 2:
			break
	return pts


func _start_pinch() -> void:
	var p := _pinch_points()
	_pinch_dist = (p[0] - p[1]).length()
	_pinch_center = (p[0] + p[1]) * 0.5


func _do_pinch() -> void:
	var p := _pinch_points()
	var d: float = (p[0] - p[1]).length()
	var center: Vector2 = (p[0] + p[1]) * 0.5
	if _pinch_dist > 1.0:
		_zoom_at(d / _pinch_dist, center)
	cam.position -= (center - _pinch_center) / cam.zoom.x
	_pinch_dist = d
	_pinch_center = center


func _zoom_at(f: float, sp: Vector2) -> void:
	var before: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * sp
	var z := clampf(cam.zoom.x * f, 0.3, 4.0)
	cam.zoom = Vector2(z, z)
	cam.force_update_scroll()
	var after: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * sp
	cam.position += before - after
