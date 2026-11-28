extends Node2D
## 샌드박스 메인: 공장·화면·카메라·UI를 만들고 터치 입력을 처리해요.
## 조작 (플레이어 중심: 상호작용은 플레이어 주변 REACH칸, 설치·철거는 BUILD_RANGE칸 안에서)
##   이동            : WASD·방향키 / 왼쪽 아래 조이스틱 (Shift 또는 끝까지 밀면 달리기)
##   상호작용        : F · 오른쪽 아래 버튼 = 지금 대상 / 설비를 직접 탭(마우스 왼쪽) = 그 설비
##                    짧게 = 탭, 길게 = 꾹 (자세한 건 scripts/player/player.gd)
##   두 손가락·휠     : 확대·축소 (카메라는 플레이어를 따라가요)
##   설치 도구(메뉴 → 디버그 → 설치 팔레트): 탭 = 놓기, 레일·전선·파이프는 끌어서 깔기
##   모드: Z 일반 / X 이동 / C 철거 (오른쪽 아래 묶음 버튼과 같아요, 동작은 9단계)
##   PC(키보드·마우스)일 때는 마우스를 올린 칸이 상호작용 대상, 터치일 때는 바라보는 방향의 대상
## 키보드·마우스는 InputMap 액션(project.godot)으로 받아요.
##   move_* 이동 · run 달리기 · interact 상호작용 · cancel 취소 · rotate 회전
##   hotbar_1~9 핫바 고르기 · inventory 가방 · zoom_in/out(휠) 확대·축소 · mode_* 모드
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
var play_mode := PlayMode.new()   # 일반·이동·철거 모드는 여기 한 곳에서만
var save_path := SAVE_PATH   # 테스트는 다른 파일을 써요

var tool: String = "view"          # view / build
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
	player.hotbar_changed.connect(_on_hotbar_changed)
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
	hud.close_info()


func _reset_player() -> void:
	player.cancel()
	player.position = PLAYER_START * TILE
	player.velocity = Vector2.ZERO
	cam.position = player.position


func clear_room() -> void:
	## 비우기: 지울 수 없는 지형 설비만 남겨요
	factory.clear_all()
	factory.room.build_fixed(factory)
	hud.close_info()


func begin_move(b) -> void:
	## 정보창 [이동]: 9단계에서 그 설비를 들고 옮기는 동작이 붙어요. 지금은 이동 모드로 바꾸기만 해요
	play_mode.set_mode(PlayMode.Mode.MOVE)
	view.selected = b
	hud.show_message("이동 모드 — 설비를 들어 옮기는 동작은 9단계에서 붙어요")


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
		hud.close_info()
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
	## Esc·오른쪽 클릭: 가방·메뉴 닫기 → 일반 모드로 → 하던 일·손에 든 것 내려놓기 → 설치 취소 → 정보 패널 닫기
	if hud.close_inventory() or hud.close_menu():
		return
	if play_mode.mode != PlayMode.Mode.NORMAL:
		play_mode.set_mode(PlayMode.Mode.NORMAL)
		return
	if player.action != "" or player.hotbar >= 0:
		player.cancel()
	elif tool != "view":
		set_tool("view")
	else:
		hud.close_info()


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


func _tap(sp: Vector2) -> void:
	var c := screen_to_cell(sp)
	match tool:
		"view":
			# 손 닿는 설비는 누를 때 이미 처리했어요. 여기 오는 건 멀리 있는 설비
			var b = factory.get_at(c)
			if b != null and play_mode.mode == PlayMode.Mode.NORMAL and not player.in_reach(b):
				player.blink(b)
				hud.show_message("가까이 가야 해요")
		"build":
			if not is_drag_def():
				_place(c)


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
	# 정보창이 열린 동안 플레이어는 멈춰요 (PC는 WASD를 누르면 창이 닫혀요)
	player.move_input = Vector2.ZERO if hud.info_open() else v.limit_length(1.0)
	player.run = Input.is_action_pressed("run") or hud.joystick.is_running()
	# PC: 마우스를 올린 칸이 상호작용 대상 (UI 위면 없음)
	player.use_aim = not hud.touch_mode
	if player.use_aim:
		var mp := get_viewport().get_mouse_position()
		player.aim = null if hud.is_over_ui(mp) else factory.get_at(screen_to_cell(mp))
	# 카메라는 플레이어를 부드럽게 따라가요
	cam.position = cam.position.lerp(player.position, 1.0 - exp(-CAM_FOLLOW * dt))
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


func _on_hotbar_changed() -> void:
	## 핫바에서 설비를 고르면 일반 모드로 돌아가요
	if player.held_id().begins_with("[설비]"):
		play_mode.set_mode(PlayMode.Mode.NORMAL)


func _input(event: InputEvent) -> void:
	## 입력 방식 자동 전환: 진짜 터치면 터치 UI(조이스틱), 키보드·마우스를 쓰면 조이스틱을 숨겨요.
	## (마우스에서 흉내 낸 터치·터치에서 흉내 낸 마우스는 DEVICE_ID_EMULATION이라 무시해요)
	if hud.settings.input_mode != "auto" or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not hud.touch_mode:
			hud.set_touch_mode(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		if hud.touch_mode:
			hud.set_touch_mode(false)


func _handle_actions(event: InputEvent) -> bool:
	## InputMap 액션 처리. 처리했으면 true
	if event.is_echo():
		return false
	if hud.info_open():
		for a in ["move_up", "move_down", "move_left", "move_right"]:
			if event.is_action_pressed(a):
				hud.close_info()
				return true
	if event.is_action_pressed("save_game", false, true):
		save_game()
	elif event.is_action_pressed("zoom_in"):
		_zoom_at(ZOOM_STEP, _event_pos(event))
	elif event.is_action_pressed("zoom_out"):
		_zoom_at(1.0 / ZOOM_STEP, _event_pos(event))
	elif event.is_action_pressed("mode_normal"):
		play_mode.set_mode(PlayMode.Mode.NORMAL)
	elif event.is_action_pressed("mode_move"):
		play_mode.set_mode(PlayMode.Mode.MOVE)
	elif event.is_action_pressed("mode_deconstruct"):
		play_mode.set_mode(PlayMode.Mode.DECONSTRUCT)
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
			elif tool == "view" and play_mode.mode == PlayMode.Mode.NORMAL:
				# 일반 모드: 3칸 안 설비를 누르면 그 설비와 상호작용 (탭 = 정보창, 들고 꾹 = 빠른 넣기)
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
			if not _moved and not _multi:
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
