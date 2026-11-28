extends Node2D
## 샌드박스 메인: 공장·화면·카메라·UI를 만들고 터치 입력을 처리해요.
## 조작 (플레이어 중심: 상호작용은 플레이어 주변 REACH칸, 설치·철거는 BUILD_RANGE칸 안에서)
##   이동            : WASD·방향키 / 왼쪽 아래 조이스틱 (Shift 또는 끝까지 밀면 달리기)
##   상호작용        : F · 오른쪽 아래 버튼 = 지금 대상 / 설비를 직접 탭(마우스 왼쪽) = 그 설비
##                    짧게 = 탭, 길게 = 꾹 (자세한 건 scripts/player/player.gd)
##   두 손가락·휠     : 확대·축소 (카메라는 플레이어를 따라가요)
##   설치 도구        : 탭 = 놓기, 레일·전선·파이프는 끌어서 깔기 / 철거 도구: 탭 = 가방으로 철거
## 키보드·마우스는 InputMap 액션(project.godot)으로 받아요.
##   move_* 이동 · run 달리기 · interact 상호작용 · cancel 취소 · rotate 회전
##   hotbar_1~9·휠 핫바 고르기 · inventory 가방 · zoom_in/out(Ctrl+휠) 확대·축소
##   debug 디버그 오버레이 · save_game 저장 (Ctrl+S)

const TILE := 32.0
const CAM_FOLLOW := 8.0         # 카메라가 플레이어를 따라가는 빠르기 (클수록 바짝)
const BUILD_RANGE := 6.0        # 설치·철거 거리 (칸, 크리에이티브면 무제한)
const PLAYER_START := Vector2(40.5, 20.5)   # 처음 서 있는 칸 (정문 안쪽)
const Player := preload("res://scripts/player/player.gd")
const WorldCollision := preload("res://scripts/player/world_collision.gd")
const TargetMarker := preload("res://scripts/player/target_marker.gd")
const DropLayer := preload("res://scripts/view/drop_layer.gd")
## 새 게임 시작 지급품 [이름, 개수]
const STARTER_KIT := [
	["나무 판자", 20], ["나사", 40], ["[설비] 레일 Mk1", 100],
	["[설비] 전선", 50], ["박스 테이프", 20], ["작은 택배 박스", 40],
]
const ZOOM_STEP := 1.1          # 휠 한 칸 확대 배율
const ZOOM_MIN := 0.3
const ZOOM_MAX := 4.0
const DRAG_THRESHOLD := 14.0    # 이만큼 움직여야 탭이 아니라 끌기로 봐요
const SAVE_PATH := "user://save.json"
const CAM_START_ZOOM := 1.6     # 처음 확대 배율 (카메라가 플레이어를 따라가요)
const HUD := preload("res://scripts/view/hud.gd")
const WorldView := preload("res://scripts/view/world_view.gd")
const Demo := preload("res://scripts/demo.gd")

var factory: Factory
var view
var cam: Camera2D
var hud
var player       # scripts/player/player.gd
var save_path := SAVE_PATH   # 테스트는 다른 파일을 써요

var tool: String = "view"          # view / build / erase
var build_def: String = "레일 Mk1"
var rot: int = 0

var _touches := {}
var _drag_start := Vector2.ZERO
var _moved := false
var _multi := false
var _last_cell := Vector2i(0, 0)
var _pinch_dist := 0.0
var _world_press := false          # 설비를 직접 눌러 플레이어 상호작용 중


func _ready() -> void:
	factory = Factory.new()
	factory.name = "Factory"
	factory.room = Room.new()
	add_child(factory)
	view = WorldView.new()
	view.factory = factory
	add_child(view)
	var walls := WorldCollision.new()
	walls.factory = factory
	view.add_child(walls)
	var drops := DropLayer.new()
	drops.world = view
	view.add_actor(drops)
	player = Player.new()
	player.factory = factory
	player.position = PLAYER_START * TILE
	view.add_actor(player)
	var marker := TargetMarker.new()
	marker.player = player
	view.add_actor(marker)
	cam = Camera2D.new()
	cam.zoom = Vector2(CAM_START_ZOOM, CAM_START_ZOOM)
	cam.position = player.position
	add_child(cam)
	cam.make_current()
	hud = HUD.new()
	hud.main = self
	add_child(hud)
	# 저장 파일이 있으면 그대로 이어서, 없으면 빈 큰방(지형 + 지급 설비) + 시작 지급품으로 시작해요
	if not _load_file():
		new_room(false)
		give_starter_kit()


func give_starter_kit() -> void:
	for e in STARTER_KIT:
		player.inventory.add(e[0], e[1])


func _exit_tree() -> void:
	Art.clear_cache()


# ---------- 큰방 ----------

func new_room(with_demo: bool) -> void:
	## 큰방을 처음 상태로: 쓰레기 더미·물 샘 + 지급 설비 (+ 예시 공장)
	factory.clear_all()
	factory.room.build_fixed(factory)
	factory.room.build_given(factory)
	if with_demo:
		Demo.build(factory)
	_reset_player()
	hud.hide_inspector()


func _reset_player() -> void:
	player.cancel()
	player.position = PLAYER_START * TILE
	player.velocity = Vector2.ZERO
	cam.position = player.position


func clear_room() -> void:
	## 비우기: 지울 수 없는 지형 설비만 남겨요
	factory.clear_all()
	factory.room.build_fixed(factory)
	hud.hide_inspector()


func toggle_creative() -> void:
	factory.creative = not factory.creative
	hud.show_message("크리에이티브 %s" % ("켬: 어디든 설치·철거" if factory.creative else "끔: 큰방 규칙"))


# ---------- 저장·불러오기 ----------

func save_game() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		hud.show_message("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return
	var data := factory.to_save()
	data["player"] = player.to_save()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	hud.show_message("저장했어요 (설비 %d개)" % factory.buildings.size())


func load_game() -> void:
	if _load_file():
		hud.hide_inspector()
		hud.show_message("불러왔어요 (설비 %d개)" % factory.buildings.size())
	else:
		hud.show_message("불러올 저장 파일이 없어요")


func _load_file() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not factory.load_save(data):
		push_warning("저장 파일을 읽지 못했어요: " + save_path)
		return false
	if data.has("player"):
		player.load_save(data["player"])
		cam.position = player.position
	return true


func cancel() -> void:
	## Esc·오른쪽 클릭: 가방·메뉴 닫기 → 하던 일·손에 든 것 내려놓기 → 설치·철거 취소 → 정보 패널 닫기
	if hud.close_inventory() or hud.close_menu():
		return
	if player.action != "" or player.hotbar >= 0:
		player.cancel()
	elif tool != "view":
		set_tool("view")
	else:
		hud.hide_inspector()


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
	view.ghost = {"def": def, "pos": c, "rot": rot, "ok": factory.can_place(def, c, rot) and in_build_range(c)}


func in_build_range(c: Vector2i) -> bool:
	## 설치·철거는 플레이어 주변에서만 (크리에이티브면 어디든)
	if factory.creative:
		return true
	return (Vector2(c) + Vector2(0.5, 0.5)).distance_to(player.position / TILE) <= BUILD_RANGE


func _place(c: Vector2i) -> void:
	if in_build_range(c):
		factory.place(build_def, c, rot)
	_update_ghost(c)


func _erase(c: Vector2i) -> void:
	if not in_build_range(c):
		hud.show_message("플레이어에게서 너무 멀어요")
		return
	var b = factory.get_at(c)
	if b != null:
		var nm: String = b.name
		if factory.deconstruct(b, player.inventory):
			hud.show_message("%s을(를) 철거해 가방에 넣었어요" % nm)
			if view.selected != null and not factory.buildings.has(view.selected):
				view.selected = null
		else:
			hud.show_message("%s은(는) 철거할 수 없거나 가방이 가득 찼어요" % nm)
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

func _process(dt: float) -> void:
	# 이동: 키보드 + 조이스틱. Ctrl+S의 S가 move_down으로 잡히지 않게 Ctrl을 누르는 동안은 멈춰요
	var v := Vector2.ZERO
	if not Input.is_key_pressed(KEY_CTRL):
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	v += hud.joystick.vector
	player.move_input = v.limit_length(1.0)
	player.run = Input.is_action_pressed("run") or hud.joystick.is_running()
	# 카메라는 플레이어를 부드럽게 따라가요
	cam.position = cam.position.lerp(player.position, 1.0 - exp(-CAM_FOLLOW * dt))
	hud.update_touch(player)
	if tool == "build" and not view.ghost.is_empty():
		_update_ghost(view.ghost["pos"])   # 걸어가면 설치 가능 거리가 바뀌어요


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif _handle_actions(event):
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and tool == "build" and _touches.is_empty():
		var mm := event as InputEventMouseMotion
		if not hud.is_over_ui(mm.position):
			_update_ghost(screen_to_cell(mm.position))


func _handle_actions(event: InputEvent) -> bool:
	## InputMap 액션 처리. 처리했으면 true
	if event.is_echo():
		return false
	if event.is_action_pressed("save_game", false, true):
		save_game()
	elif event.is_action_pressed("zoom_in", false, true):
		_zoom_at(ZOOM_STEP, _event_pos(event))
	elif event.is_action_pressed("zoom_out", false, true):
		_zoom_at(1.0 / ZOOM_STEP, _event_pos(event))
	elif event.is_action_pressed("hotbar_prev", false, true):
		player.scroll_hotbar(-1)
	elif event.is_action_pressed("hotbar_next", false, true):
		player.scroll_hotbar(1)
	elif event.is_action_pressed("cancel"):
		cancel()
	elif event.is_action_pressed("interact") and not (event is InputEventMouseButton):
		# 마우스 왼쪽은 터치 흉내(emulate_touch_from_mouse)로 _on_touch에서 처리돼요.
		# F 키: 플레이어가 지금 바라보는 대상과 상호작용 (누르는 시간으로 탭·꾹을 나눠요)
		player.action_press()
	elif event.is_action_released("interact") and not (event is InputEventMouseButton):
		player.action_release()
	elif event.is_action_pressed("rotate"):
		rotate_tool()
	elif event.is_action_pressed("inventory"):
		hud.toggle_inventory()
	elif event.is_action_pressed("debug"):
		hud.toggle_debug()
	else:
		for i in range(1, 10):
			if event.is_action_pressed("hotbar_%d" % i):
				player.select_hotbar(i - 1)
				return true
		return false
	return true


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	return get_viewport().get_visible_rect().size * 0.5


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
			elif tool == "view":
				# 손 닿는 설비를 직접 누르면 그 설비와 상호작용 (멀면 떼었을 때 정보만 봐요)
				var b = factory.get_at(_last_cell)
				if b != null and player.in_reach(b):
					_world_press = true
					player.action_press(b)
		elif _touches.size() == 2:
			_multi = true
			if _world_press:
				_world_press = false
				player.action_release()
			_start_pinch()
	else:
		if not _touches.has(e.index):
			return
		_touches.erase(e.index)
		if _world_press and _touches.is_empty():
			_world_press = false
			player.action_release()
		elif _touches.is_empty():
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
	if not _moved and (e.position - _drag_start).length() > DRAG_THRESHOLD:
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


func _do_pinch() -> void:
	var p := _pinch_points()
	var d: float = (p[0] - p[1]).length()
	var center: Vector2 = (p[0] + p[1]) * 0.5
	if _pinch_dist > 1.0:
		_zoom_at(d / _pinch_dist, center)
	_pinch_dist = d


func _zoom_at(f: float, _sp: Vector2) -> void:
	## 카메라가 플레이어를 따라가니 확대·축소는 플레이어 중심으로 해요
	var z := clampf(cam.zoom.x * f, ZOOM_MIN, ZOOM_MAX)
	cam.zoom = Vector2(z, z)
