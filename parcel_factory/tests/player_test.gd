extends Node
## 플레이어 테스트: 실제 main 씬에서 물리 프레임을 돌려 이동·충돌·상호작용을 확인해요.
## 실행: godot --headless --path . res://tests/player_test.tscn
## (저장 파일은 건드리지 않고, 시작할 때 큰방을 새로 깔아요)

const TILE := 32.0
const PHYS_FPS := 60.0
const WATCHDOG_SEC := 240.0
const TEST_SAVE := "user://player_test_save.json"   # 진짜 저장 파일은 건드리지 않아요

var _fails := 0
var main
var player
var f: Factory


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SEC).timeout.connect(func() -> void: get_tree().quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	main.new_room(false)
	main.set_process(false)   # 키보드·조이스틱 입력 대신 테스트가 move_input을 직접 넣어요
	main.save_path = TEST_SAVE
	player = main.player
	f = main.factory
	player.inventory.clear()
	print("=== 플레이어 테스트 ===")
	await _test_speed()
	await _test_collision()
	await _test_rummage_insert_take()
	await _test_info_window()
	await _test_deconstruct()
	await _test_attack()
	await _test_drop_pickup()
	await _test_build()
	await _test_edit_modes()
	await _test_range_select()
	await _test_feel()
	await _test_day_hud()
	await _test_workers()
	await _test_repair_worker()
	await _test_courier3()
	await _test_save_load()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("=== 결과: %s (실패 %d) ===" % ["통과" if _fails == 0 else "실패", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, ok: bool, detail: String) -> void:
	print("[%s] %s — %s" % ["통과" if ok else "실패", label, detail])
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _put(cell: Vector2) -> void:
	player.position = cell * TILE
	player.velocity = Vector2.ZERO
	player.move_input = Vector2.ZERO
	player.run = false
	await _frames(2)


func _walk(dir: Vector2, sec: float, run := false) -> void:
	player.move_input = dir
	player.run = run
	await _frames(int(sec * PHYS_FPS))
	player.move_input = Vector2.ZERO
	player.run = false
	await _frames(int(0.2 * PHYS_FPS))


func _test_speed() -> void:
	await _put(Vector2(20.5, 30.5))
	var x0: float = player.position.x
	await _walk(Vector2.RIGHT, 1.0)
	var walk: float = (player.position.x - x0) / TILE
	await _put(Vector2(20.5, 32.5))
	x0 = player.position.x
	await _walk(Vector2.RIGHT, 1.0, true)
	var run: float = (player.position.x - x0) / TILE
	await _put(Vector2(20.5, 30.5))
	var p0: Vector2 = player.position
	await _walk(Vector2(1, 1).normalized(), 1.0)
	var diag: float = (player.position - p0).length() / TILE
	# 가속·감속(0.08초)만큼 조금 덜·더 가요
	_check("이동: 걷기 2칸/초 · 달리기 3칸/초 · 대각선 보정", absf(walk - 2.0) < 0.15 and absf(run - 3.0) < 0.2 and absf(diag - 2.0) < 0.15,
		"걷기 %.2f · 달리기 %.2f · 대각선 %.2f칸" % [walk, run, diag])


func _test_collision() -> void:
	# 설비에 막혀요
	var m = f.place("분해기", Vector2i(24, 30), 0)
	await _put(Vector2(21.5, 31.0))
	await _walk(Vector2.RIGHT, 2.0)
	var stop_x: float = player.position.x / TILE
	var blocked: bool = stop_x < 24.0
	# 레일 위는 걸어 다녀요
	for x in range(22, 28):
		f.place("레일 Mk1", Vector2i(x, 34), 0)
	await _put(Vector2(21.5, 34.5))
	await _walk(Vector2.RIGHT, 2.5)
	var over_rail: bool = player.position.x / TILE > 25.5
	# 벽에 막혀요
	await _put(Vector2(30.5, 2.5))
	await _walk(Vector2.UP, 3.0)
	var wall_ok: bool = player.position.y > 0.0
	_check("충돌: 설비·벽은 막히고 레일 위는 걸어감", blocked and over_rail and wall_ok,
		"설비 앞에서 멈춤 x=%.2f(설비 24) · 레일 건넘 %s · 벽 앞 y=%.2f" % [stop_x, str(over_rail), player.position.y / TILE])
	f.remove_at(m.pos)
	for x in range(22, 28):
		f.remove_at(Vector2i(x, 34))


func _test_rummage_insert_take() -> void:
	# 쓰레기 더미 오른쪽에 서서 왼쪽을 보고 탭 → 3초 뒤 가방에
	await _put(Vector2(5.0, 12.5))
	await _walk(Vector2.LEFT, 0.1)
	var t = player.target
	player.action_press()
	await _frames(2)
	player.action_release()
	var busy: bool = player.action == "rummage"
	await _frames(int(3.3 * PHYS_FPS))
	var got: int = player.inventory.total()
	_check("더미 뒤지기: 탭 → 3초 → 3~5개", t is ItemPile and busy and got >= 3 and got <= 5,
		"대상 %s · 뒤지는 중 %s · 가방 %d개" % [t.name if t != null else "없음", str(busy), got])


func _hud():
	return main.hud


func _test_info_window() -> void:
	# 3칸 안 분해기를 탭 → 정보창 + 인벤토리(주고받기)가 함께 열려요
	var hud = _hud()
	player.inventory.clear()
	player.inventory.add("나뭇가지", 10)
	player.inventory.add("종이", 3)
	var m = f.place("분해기", Vector2i(10, 20), 0)
	for r in m.available_recipes():
		if r["out"].has("종이") and r["in"].has("나뭇가지"):
			m.set_recipe(r)
	await _put(Vector2(8.5, 21.0))
	await _walk(Vector2.RIGHT, 0.05)
	player.action_press()
	await _frames(2)
	player.action_release()
	await _frames(2)
	var opened: bool = hud.info_open() and hud.info.building == m and hud.inventory_panel.visible and hud.inventory_panel.transfer == hud.info
	var hidden: bool = not hud.bottom_box.visible and not hud.action_btn.visible
	# 넣을 수 없는 아이템은 흐리게
	var twig_slot: int = hud.inventory_panel.slot_of("나뭇가지")
	var paper_slot: int = hud.inventory_panel.slot_of("종이")
	var dim_ok: bool = hud.inventory_panel.slot_node(paper_slot).dim and not hud.inventory_panel.slot_node(twig_slot).dim
	# 인벤토리 탭 = 1개, 꾹 = 넣을 수 있는 만큼
	hud.info.give(twig_slot, "one")
	var one: bool = int(m.inputs.get("나뭇가지", 0)) == 1 and player.inventory.count("나뭇가지") == 9
	hud.info.give(twig_slot, "all")
	var cap: int = m.input_cap("나뭇가지")
	var all_ok: bool = int(m.inputs.get("나뭇가지", 0)) == cap and player.inventory.count("나뭇가지") == 10 - cap
	# 종이를 꺼내요 (분해기가 돌아 종이가 나올 때까지 기다리지 않고 출력 칸을 채워 둬요)
	m.outputs["종이"] = 4
	await _frames(int(0.2 * PHYS_FPS))
	var out_i := -1
	var slots: Array = m.get_slots()
	for i in slots.size():
		if slots[i]["kind"] == "out":
			out_i = i
	hud.info.take(out_i, "one")
	var took_one: bool = player.inventory.count("종이") == 4
	hud.info.take(out_i, "all")
	var took_all: bool = player.inventory.count("종이") == 7 and int(m.outputs["종이"]) == 0
	_check("정보창: 탭 → 두 창 · 흐림 · 탭 1개/꾹 전부 넣기 · 종이 꺼내기", opened and hidden and dim_ok and one and all_ok and took_one and took_all,
		"열림 %s · HUD 숨김 %s · 흐림 %s · 1개 %s · 전부 %s · 꺼냄 1 %s · 전부 %s" % [str(opened), str(hidden), str(dim_ok), str(one), str(all_ok), str(took_one), str(took_all)])
	# 바깥 탭으로 닫기 → HUD 돌아와요
	hud._on_backdrop_input(_press_event())
	await _frames(2)
	var closed: bool = not hud.info_open() and not hud.inventory_panel.visible and hud.bottom_box.visible
	# 3칸 밖 설비 탭 → 안 열리고 테두리만 깜빡
	await _put(Vector2(20.5, 21.0))
	main._tap(main.get_viewport().get_canvas_transform() * ((Vector2(m.pos) + Vector2(1, 1)) * TILE))
	await _frames(2)
	var far_ok: bool = not hud.info_open() and player.blink_target == m
	# 들고 꾹 = 빠른 넣기 (정보창 없이)
	await _put(Vector2(8.5, 21.0))
	await _walk(Vector2.RIGHT, 0.05)
	m.inputs["나뭇가지"] = 0
	player.hotbar = -1
	for i in Inventory.HOTBAR:
		if player.inventory.id_at(i) == "나뭇가지":
			player.select_hotbar(i)
	player.action_press()
	await _frames(int(0.5 * PHYS_FPS))
	player.action_release()
	await _frames(2)
	var quick: bool = int(m.inputs.get("나뭇가지", 0)) == cap and not hud.info_open()
	_check("정보창 닫기 · 3칸 밖은 깜빡임만 · 들고 꾹 = 빠른 넣기", closed and far_ok and quick,
		"바깥 탭 닫힘 %s · 멀면 안 열림 %s · 빠른 넣기 %s" % [str(closed), str(far_ok), str(quick)])
	player.hotbar = -1
	_info_machine = m


var _info_machine = null


func _press_event() -> InputEvent:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _test_deconstruct() -> void:
	# 정보창의 [철거(꾹)] → 재료와 내용물이 바닥에 쏟아져요
	var hud = _hud()
	var m = _info_machine
	var drops0: int = f.floor_items.drops.size()
	hud.open_info(m)
	await _frames(2)
	hud.info._on_deconstruct()
	await _frames(2)
	var gone: bool = not f.buildings.has(m) and not hud.info_open()
	var mats := 0
	for d in f.floor_items.drops:
		if d["id"] == "나무 판자":
			mats += int(d["n"])
	# 지급 설비는 철거 버튼이 회색
	var pc = f.get_at(Room.GIVEN[0]["pos"])
	hud.open_info(pc)
	await _frames(2)
	var grey: bool = hud.info._decon_btn.disabled
	hud.close_info()
	_check("철거: 정보창 버튼 → 재료·내용물이 바닥에 · 지급 설비는 회색", gone and mats > 0 and f.floor_items.drops.size() > drops0 and grey,
		"철거됨 %s · 나무 판자 %d · 바닥 무더기 %d→%d · 지급 설비 회색 %s" % [str(gone), mats, drops0, f.floor_items.drops.size(), str(grey)])


func _test_attack() -> void:
	await _put(Vector2(25.5, 25.5))
	await _frames(2)
	var no_target: bool = player.target == null
	player.action_press()
	await _frames(int(0.45 * PHYS_FPS))
	var swinging: bool = player.action == "attack" and player.hitbox.monitoring
	player.action_release()
	await _frames(int(0.5 * PHYS_FPS))
	_check("공격: 맨손 꾹 → 휘두르기 + 판정 상자", no_target and swinging and player.action == "" and player.hp == 100,
		"대상 없음 %s · 휘두르는 중 %s · HP %d" % [str(no_target), str(swinging), player.hp])


func _floor_count(id: String) -> int:
	var n := 0
	for d in f.floor_items.drops:
		if d["id"] == id:
			n += int(d["n"])
	return n


func _test_drop_pickup() -> void:
	player.inventory.clear()
	player.inventory.add("바위", 10)
	await _put(Vector2(20.5, 25.5))
	await _walk(Vector2.RIGHT, 0.05)
	player.drop_slot(0)
	await _frames(int(0.5 * PHYS_FPS))
	var on_floor: bool = _floor_count("바위") == 10 and player.inventory.count("바위") == 0
	# 멀어졌다가 다시 다가가면 끌려와 주워져요
	await _walk(Vector2.LEFT, 1.0)
	await _walk(Vector2.RIGHT, 1.8)   # 버린 자리(앞 1.4칸 ± 흩어짐)를 지나가요
	await _frames(int(0.5 * PHYS_FPS))
	var repicked: bool = player.inventory.count("바위") == 10 and _floor_count("바위") == 0
	# 가방이 가득이면 그대로 남아요
	player.inventory.add("나사", Inventory.SLOTS * Inventory.STACK_ITEM)
	f.floor_items.spawn("종이", 2, player.position / TILE, 0.0, false)
	await _frames(int(1.0 * PHYS_FPS))
	var stays: bool = _floor_count("종이") == 2
	_check("버리기·다시 줍기: 앞에 버림 → 다가가면 끌려와 주움 · 가득이면 남음", on_floor and repicked and stays,
		"바닥에 %s · 다시 주움 %s · 가득이면 남음 %s" % [str(on_floor), str(repicked), str(stays)])
	player.inventory.clear()


func _test_save_load() -> void:
	player.inventory.clear()
	player.inventory.add("[설비] 레일 Mk1", 130)
	player.inventory.add("나무 판자", 20)
	player.select_hotbar(1)
	f.floor_items.spawn("바위", 3, Vector2(30.5, 30.5), 0.0, false)
	await _put(Vector2(33.5, 31.5))
	var drops_before: int = f.floor_items.drops.size()
	main.save_game()
	# 다 지우고 불러오기
	main.new_room(false)
	player.inventory.clear()
	player.select_hotbar(1)
	main.load_game()
	await _frames(2)
	var inv_ok: bool = player.inventory.count("[설비] 레일 Mk1") == 130 and player.inventory.count("나무 판자") == 20 and player.hotbar == 1
	var floor_ok: bool = f.floor_items.drops.size() == drops_before and _floor_count("바위") >= 3
	var pos_ok: bool = (player.position / TILE).distance_to(Vector2(33.5, 31.5)) < 0.1
	_check("저장 → 불러오기: 인벤토리·핫바·바닥 아이템·위치", inv_ok and floor_ok and pos_ok,
		"인벤토리 %s · 바닥 %s · 위치 %s" % [str(inv_ok), str(floor_ok), str(pos_ok)])


func _hold_build() -> void:
	## 상호작용 버튼 꾹 → 설치 모드 (설비 아이템을 든 상태)
	player.action_press()
	await _frames(int(0.5 * PHYS_FPS))


func _release_build(cancel := false) -> void:
	main.build.release(cancel)
	player.action_release()
	await _frames(3)


func _select(id: String) -> void:
	player.hotbar = -1
	for i in Inventory.HOTBAR:
		if player.inventory.id_at(i) == id:
			player.select_hotbar(i)
			return


func _test_build() -> void:
	var b = main.build
	player.inventory.clear()
	player.inventory.add("[설비] 분해기", 2)
	_select("[설비] 분해기")
	await _put(Vector2(20.5, 30.5))
	await _walk(Vector2.RIGHT, 0.05)
	# 꾹 → 설치 모드, 오른쪽으로 2칸만큼 끌기 → 미리보기가 앞 2칸 + 2칸
	await _hold_build()
	var started: bool = b.active
	b.drag(Vector2(b.DRAG_PX_PER_CELL * 2, 0))
	await _frames(2)
	var aim: Vector2i = b.aim
	var aim_ok: bool = aim == player.cell() + Vector2i(b.AHEAD + 2, 0)
	var ghost_ok: bool = main.view.ghost.get("ok", false)
	await _release_build()
	var built: bool = f.get_at(aim) != null and f.get_at(aim).name == "분해기" and player.inventory.count("[설비] 분해기") == 1
	# 취소: 버튼 가운데로 되돌아와 떼기
	var count0: int = f.buildings.size()
	await _hold_build()
	b.drag(Vector2(0, b.DRAG_PX_PER_CELL * 2))
	await _frames(2)
	await _release_build(true)
	var cancelled: bool = f.buildings.size() == count0 and player.inventory.count("[설비] 분해기") == 1
	# 막힘: 벽 쪽
	await _put(Vector2(30.5, 1.5))
	await _walk(Vector2.UP, 0.05)
	await _hold_build()
	await _frames(2)
	var wall_reason: String = main.view.ghost.get("reason", "")
	await _release_build()
	var wall_ok: bool = wall_reason == "벽" and player.inventory.count("[설비] 분해기") == 1
	# 거리: 8칸 넘게 끌면 빨강
	await _hold_build()
	b.drag(Vector2(b.DRAG_PX_PER_CELL * 12, b.DRAG_PX_PER_CELL * 10))
	await _frames(2)
	var far_reason: String = main.view.ghost.get("reason", "")
	await _release_build(true)
	_check("설치: 꾹 → 끌어서 조준 → 떼면 설치(1개 차감) · 취소 · 벽·거리는 빨강", started and aim_ok and ghost_ok and built and cancelled and wall_ok and far_reason == "거리",
		"설치 모드 %s · 조준 %s · 초록 %s · 설치 %s · 취소 %s · 벽 '%s' · 거리 '%s'" % [str(started), str(aim_ok), str(ghost_ok), str(built), str(cancelled), wall_reason, far_reason])
	# 레일 두 점: A (20,25) → B (24,27) = ㄱ자 7칸
	player.inventory.clear()
	player.inventory.add("[설비] 레일 Mk1", 30)
	_select("[설비] 레일 Mk1")
	await _put(Vector2(22.5, 24.0))
	var a := Vector2i(20, 25)
	var bb := Vector2i(24, 27)
	await _hold_build()
	b._world_aim = a
	await _frames(2)
	await _release_build()
	var anchored: bool = b.anchor == a and f.get_at(a) != null
	await _hold_build()
	b._world_aim = bb
	await _frames(2)
	var path_n: int = main.view.ghost.get("cells", []).size()
	await _release_build()
	var corner = f.get_at(Vector2i(24, 25))
	var rails_ok: bool = path_n == 7 and f.get_at(a).rot == 0 and corner != null and corner.rot == 1 and f.get_at(bb) != null and f.get_at(bb).rot == 1
	var used: int = 30 - player.inventory.count("[설비] 레일 Mk1")
	var chained: bool = b.anchor == bb
	# 개수 부족: 2개만 남기고 5칸 더 → 빨강 + 'N개 필요 / M개 있음'
	player.inventory.remove("[설비] 레일 Mk1", player.inventory.count("[설비] 레일 Mk1") - 2)
	await _hold_build()
	b._world_aim = bb + Vector2i(5, 0)
	await _frames(2)
	var short_reason: String = main.view.ghost.get("reason", "")
	await _release_build()
	var not_placed: bool = f.get_at(bb + Vector2i(5, 0)) == null and player.inventory.count("[설비] 레일 Mk1") == 2
	# B = A: 그 칸만, A 고정 해제
	await _hold_build()
	b._world_aim = bb
	await _frames(2)
	await _release_build()
	var released: bool = b.anchor == null
	_check("레일 두 점: A → B ㄱ자 · 방향 자동 · 이어 깔기 · 개수 부족 빨강 · B=A면 고정 해제",
		anchored and rails_ok and used == 7 and chained and short_reason.find("필요") >= 0 and not_placed and released,
		"A 고정 %s · 경로 %d칸 · 방향 %s · 쓴 레일 %d · B가 새 A %s · 부족 '%s' · 안 깔림 %s · 해제 %s" % [str(anchored), path_n, str(rails_ok), used, str(chained), short_reason, str(not_placed), str(released)])
	player.hotbar = -1


# ---------- 9단계: 이동·철거 모드 · 범위 선택 (진짜 터치 이벤트를 main에 넣어요) ----------

func _look() -> void:
	## main._process를 꺼 둬서 카메라를 직접 플레이어에게
	main.cam.position = player.position
	await _frames(2)


func _sp(cell: Vector2) -> Vector2:
	return main.get_viewport().get_canvas_transform() * (cell * TILE)


func _touch(i: int, cell: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = _sp(cell)
	e.pressed = down
	main._on_touch(e)


func _drag_to(i: int, cell: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = _sp(cell)
	main._on_drag(e)


func _hold_at(cell: Vector2, sec: float) -> void:
	_touch(0, cell, true)
	await _frames(int(sec * PHYS_FPS))


func _twig_machine():
	var m = f.place("분해기", Vector2i(23, 30), 0)
	for r in m.available_recipes():
		if r["out"].has("종이") and r["in"].has("나뭇가지"):
			m.set_recipe(r)
	return m


func _test_edit_modes() -> void:
	main.new_room(false)
	var ed = main.edit
	await _put(Vector2(21.5, 30.5))
	await _look()
	# 철거 모드: 탭 = 안내만 · 중간에 떼면 취소 · 0.6초 다 차면 재료·내용물이 그 자리에
	var m = _twig_machine()
	f.player_insert(m, "나뭇가지", 2)
	main.play_mode.set_mode(PlayMode.Mode.DECONSTRUCT)
	await _hold_at(Vector2(23.5, 30.5), 0.05)
	_touch(0, Vector2(23.5, 30.5), false)
	await _frames(2)
	var tap_hint: bool = ed.hint.get("text", "") == "꾹 눌러서 철거" and not main.hud.info_open() and f.buildings.has(m)
	await _hold_at(Vector2(23.5, 30.5), 0.6)
	var gauging: bool = ed.state == "gauge"
	_touch(0, Vector2(23.5, 30.5), false)
	await _frames(2)
	var early_kept: bool = f.buildings.has(m)
	await _hold_at(Vector2(23.5, 30.5), 1.2)
	_touch(0, Vector2(23.5, 30.5), false)
	await _frames(2)
	var twigs := 0
	for d in f.floor_items.drops:
		if d["id"] == "나뭇가지" and d["pos"].distance_to(Vector2(24, 31)) < 1.5:
			twigs += int(d["n"])
	var decon_ok: bool = not f.buildings.has(m) and twigs == 2 and _floor_count("나무 판자") > 0
	_check("철거 모드: 탭 = 안내 · 게이지 중 떼면 취소 · 다 차면 재료·내용물이 그 자리에", tap_hint and gauging and early_kept and decon_ok,
		"안내 %s · 게이지 %s · 취소 %s · 철거 %s(나뭇가지 %d)" % [str(tap_hint), str(gauging), str(early_kept), str(decon_ok), twigs])
	# 이동 모드: 꾹 → 끌어서 놓기 = 내용물 유지 / 막힌 곳 = 제자리로
	f.floor_items.clear()
	m = _twig_machine()
	var n_in: int = f.player_insert(m, "나뭇가지", 3)
	main.play_mode.set_mode(PlayMode.Mode.MOVE)
	await _hold_at(Vector2(23.5, 30.5), 0.5)
	var lifted: bool = ed.moving() and f.held.has(m)
	_drag_to(0, Vector2(25.5, 32.5))
	await _frames(3)
	var ghost_ok: bool = main.view.ghost.get("cells", []).size() == 1 and main.view.ghost["cells"][0]["pos"] == Vector2i(25, 32)
	_touch(0, Vector2(25.5, 32.5), false)
	await _frames(3)
	var moved: bool = m.pos == Vector2i(25, 32) and n_in > 0 and m.contents().size() == n_in and f.held.is_empty()
	f.place("창고 블록", Vector2i(28, 32), 0)
	await _hold_at(Vector2(25.5, 32.5), 0.5)
	_drag_to(0, Vector2(28.5, 32.5))
	await _frames(3)
	var red: bool = not main.view.ghost.get("cells", [{}])[0].get("ok", true) and main.view.ghost.get("reason", "") == "다른 설비"
	_touch(0, Vector2(28.5, 32.5), false)
	await _frames(int(0.3 * PHYS_FPS))
	var back: bool = m.pos == Vector2i(25, 32) and f.held.is_empty()
	# 상호작용 버튼 꾹 → 버튼을 끌어 조준 (40px = 1칸) → 떼면 놓기
	player.facing = 0
	await _put(Vector2(23.0, 33.0))
	await _frames(3)
	var hud = main.hud
	var target_ok: bool = player.shown_target() == m
	hud._on_action_down()
	await _frames(int(0.5 * PHYS_FPS))
	hud._on_action_dragged(Vector2(0, -80))
	await _frames(3)
	hud._on_action_released()
	await _frames(3)
	var btn_ok: bool = target_ok and m.pos == Vector2i(25, 30)
	_check("이동 모드: 꾹 → 끌어 놓기(내용물 유지) · 막히면 빨강 → 제자리 · 버튼 끌어 옮기기", lifted and ghost_ok and moved and red and back and btn_ok,
		"들기 %s · 미리보기 %s · 옮김 %s · 빨강 %s · 제자리 %s · 버튼 %s(대상 %s, %s)" % [str(lifted), str(ghost_ok), str(moved), str(red), str(back), str(btn_ok), str(target_ok), str(m.pos)])
	main.play_mode.set_mode(PlayMode.Mode.NORMAL)


func _test_range_select() -> void:
	main.new_room(false)
	var ed = main.edit
	await _put(Vector2(31.5, 30.5))
	await _look()
	var rails := []
	for x in 5:
		rails.append(f.place("레일 Mk1", Vector2i(29 + x, 28), 0))
	rails[1].item = Item.new("종이")
	# 빈 칸 꾹 → 끌기 → 놓기 = 레일 5개 선택
	await _hold_at(Vector2(28.5, 27.5), 0.5)
	var selecting: bool = ed.state == "select"
	_drag_to(0, Vector2(33.5, 28.5))
	await _frames(3)
	_touch(0, Vector2(33.5, 28.5), false)
	await _frames(int(0.15 * PHYS_FPS))
	var picked: bool = ed.sel.size() == 5 and main.hud.sel_bar.visible and main.hud.sel_label.text == "설비 5개 선택됨"
	# 선택 안 된 빈 곳 탭 = 해제
	await _hold_at(Vector2(30.5, 32.5), 0.05)
	_touch(0, Vector2(30.5, 32.5), false)
	await _frames(2)
	var cleared: bool = ed.sel.is_empty()
	await _hold_at(Vector2(28.5, 27.5), 0.5)
	_drag_to(0, Vector2(33.5, 28.5))
	await _frames(2)
	_touch(0, Vector2(33.5, 28.5), false)
	await _frames(2)
	# 이동 모드: 선택된 레일 하나를 꾹 → 줄 전체가 같이 (물건도)
	main.play_mode.set_mode(PlayMode.Mode.MOVE)
	await _hold_at(Vector2(30.5, 28.5), 0.5)
	_drag_to(0, Vector2(30.5, 26.5))
	await _frames(3)
	_touch(0, Vector2(30.5, 26.5), false)
	await _frames(3)
	var all_moved := true
	for i in rails.size():
		if rails[i].pos != Vector2i(29 + i, 26):
			all_moved = false
	var carried := 0   # 종이는 레일을 타고 계속 가요: 줄 어딘가에 그대로 있어야 해요
	for r in rails:
		if r.item != null:
			carried += 1
	all_moved = all_moved and carried == 1
	# 철거 모드: 선택된 것 하나를 꾹 → 게이지 옆 '5개 철거' → 전부
	main.play_mode.set_mode(PlayMode.Mode.DECONSTRUCT)
	await _hold_at(Vector2(31.5, 26.5), 0.5)
	var many: bool = ed.state == "gauge" and ed.gauge_list.size() == 5
	await _frames(int(0.6 * PHYS_FPS))
	_touch(0, Vector2(31.5, 26.5), false)
	await _frames(2)
	var gone := true
	for r in rails:
		if f.buildings.has(r):
			gone = false
	var spilled: bool = _floor_count("[설비] 레일 Mk1") == 5 and _floor_count("종이") == 1 and ed.sel.is_empty() and not main.hud.sel_bar.visible
	_check("범위 선택: 빈 칸 꾹-끌기 · 바깥 탭 해제 · 레일 줄 통째로 옮기기(물건 같이) · 통째로 철거",
		selecting and picked and cleared and all_moved and many and gone and spilled,
		"선택 중 %s · 5개 %s(%d) · 해제 %s · 옮김 %s · 게이지 %s · 철거 %s · 쏟음 %s" % [str(selecting), str(picked), ed.sel.size(), str(cleared), str(all_moved), str(many), str(gone), str(spilled)])
	main.play_mode.set_mode(PlayMode.Mode.NORMAL)


# ---------- 10단계: 손에 붙는 조작감 ----------

func _cam(sec: float) -> void:
	## main._process를 꺼 둬서 카메라만 직접 돌려요
	var n := int(sec * PHYS_FPS)
	for i in n:
		main.update_camera(1.0 / PHYS_FPS)
		await get_tree().physics_frame


func _test_feel() -> void:
	main.new_room(false)
	var ed = main.edit
	var hud = main.hud
	await _put(Vector2(25.5, 30.5))
	main.snap_camera()
	await _frames(2)
	# 데드존: 0.5칸 움직여도 카메라는 그대로 · 위치는 화면 픽셀에 맞춰 반올림
	var c0: Vector2 = main.cam.position
	player.position += Vector2(16, 0)
	await _cam(0.5)
	var dead_ok: bool = main.cam.position.distance_to(c0) < 1.0
	player.position += Vector2(48, 0)
	await _cam(1.0)
	var follow_ok: bool = main.cam.position.x > c0.x + 30.0
	var z: float = main.cam.zoom.x
	var px: Vector2 = main.cam.position * z
	var round_ok: bool = absf(px.x - roundf(px.x)) < 0.01 and absf(px.y - roundf(px.y)) < 0.01
	main.snap_camera()
	# 꾹 게이지: 누르는 동안 차고 · 12px 넘게 끌면 둘러보기(꾹 아님) · 떼고 1.5초 뒤 돌아와요
	_touch(0, Vector2(25.5, 27.5), true)
	await _frames(int(0.2 * PHYS_FPS))
	var ring: float = ed.press_progress()
	var ring_ok: bool = ring > 0.3 and ring < 1.0
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = _sp(Vector2(25.5, 27.5)) + Vector2(120, 0)
	main._on_drag(e)
	await _frames(int(0.4 * PHYS_FPS))
	var panned: bool = main.cam_pan.x < -20.0 and ed.state == "" and ed.press_progress() < 0.0
	_touch(0, Vector2(25.5, 27.5), false)
	await _cam(1.0)
	var stays: bool = main.cam_pan.length() > 20.0
	await _cam(1.5)
	var back: bool = main.cam_pan.length() < 10.0
	_check("카메라: 데드존 1칸 · 픽셀 반올림 · 꾹 게이지 · 끌면 둘러보기 · 1.5초 뒤 복귀",
		dead_ok and follow_ok and round_ok and ring_ok and panned and stays and back,
		"데드존 %s · 따라감 %s · 반올림 %s · 게이지 %.2f · 둘러보기 %s(%s) · 1초 뒤 그대로 %s · 돌아옴 %s" % [str(dead_ok), str(follow_ok), str(round_ok), ring, str(panned), str(main.cam_pan), str(stays), str(back)])
	# 확대 0.5~3배 · 저장
	main._zoom_at(100.0, Vector2.ZERO)
	var zmax: float = main.cam.zoom.x
	main._zoom_at(0.0001, Vector2.ZERO)
	var zmin: float = main.cam.zoom.x
	main._zoom_at(2.0, Vector2.ZERO)
	await _cam(0.7)
	var saved: bool = is_equal_approx(hud.settings.zoom, 1.0)
	main._zoom_at(1.6, Vector2.ZERO)
	await _cam(0.7)
	_check("확대·축소 0.5~3배 · 설정에 저장", is_equal_approx(zmax, 3.0) and is_equal_approx(zmin, 0.5) and saved,
		"최대 %.2f · 최소 %.2f · 저장 %.2f" % [zmax, zmin, hud.settings.zoom])
	# 대상 고정 0.15초: 다른 쪽을 바라봐도 바로 안 바뀌어요
	var a = f.place("창고 블록", Vector2i(27, 30), 0)
	var b = f.place("창고 블록", Vector2i(23, 30), 0)
	await _put(Vector2(25.5, 30.5))
	player.use_aim = false
	player.facing = 0
	await _frames(int(0.3 * PHYS_FPS))
	var first_ok: bool = player.target == a
	player.facing = 2
	await _frames(int(0.05 * PHYS_FPS))
	var held_on: bool = player.target == a
	await _frames(int(0.2 * PHYS_FPS))
	var switched: bool = player.target == b
	_check("대상 고정 0.15초", first_ok and held_on and switched, "처음 %s · 0.05초 뒤 그대로 %s · 0.25초 뒤 바뀜 %s" % [str(first_ok), str(held_on), str(switched)])
	# 연속 설치: 창고 블록을 들고 버튼 꾹 → 3칸 끌기 = 지나간 칸마다 (떼도 더 안 놓아요)
	f.remove_at(a.pos)
	f.remove_at(b.pos)
	hud.settings.build_continuous = true
	player.inventory.clear()
	player.inventory.add("[설비] 창고 블록", 10)
	_select("[설비] 창고 블록")
	player.facing = 1
	await _frames(2)
	var n0: int = f.buildings.size()
	await _hold_build()
	for k in 4:
		main.build.drag(Vector2(40.0 * k, 0))
		await _frames(3)
	await _release_build()
	var placed: int = f.buildings.size() - n0
	var cont_ok: bool = placed == 4 and player.inventory.count("[설비] 창고 블록") == 6
	hud.settings.build_continuous = false
	await _hold_build()
	main.build.drag(Vector2(0, 80))
	await _frames(3)
	await _release_build()
	var single_ok: bool = f.buildings.size() - n0 == 5
	_check("연속 설치: 켜면 끄는 칸마다 · 끄면 한 개만", cont_ok and single_ok, "연속 %d개 · 끈 뒤 한 개 %s" % [placed, str(single_ok)])
	# 설비 아이템을 들고 월드의 설비를 꾹 = 설치 모드가 아니에요 (설치는 버튼으로만)
	await _hold_at(Vector2(25.5, 32.5), 0.5)
	var not_build: bool = not main.build.active
	_touch(0, Vector2(25.5, 32.5), false)
	await _frames(2)
	player.hotbar = -1
	# 코너 보정: 1칸 틈 옆 모서리에 살짝 어긋나게 걸어 들어가도 미끄러져 지나가요
	main.new_room(false)
	f.place("창고 블록", Vector2i(30, 20), 0)
	f.place("창고 블록", Vector2i(30, 22), 0)
	await _frames(2)
	await _put(Vector2(28.5, 21.5 - 0.62))
	await _walk(Vector2.RIGHT, 1.6)
	var through: bool = player.position.x / TILE > 31.2
	_check("코너 보정 · 월드 꾹은 설치 모드 아님", through and not_build, "틈 통과 %s (x %.2f) · 설치 모드 아님 %s" % [str(through), player.position.x / TILE, str(not_build)])


func _test_day_hud() -> void:
	## 18:00 → '하루 끝' 창 · 멈춤 버튼 잠금 · [다음 날] → 09:00, 시계 아래 오늘 배달 수
	var hud = main.hud
	f.paused = false
	f.record_shipment(null, true)
	f.record_shipment(null, false)
	f.sim_time = GameClock.DAY_REAL_SEC - 0.05
	await _frames(int(0.4 * PHYS_FPS))
	var shown: bool = f.day_over and hud.day_panel.visible and hud.pause_btn.disabled and hud.clock_label.text == "18:00"
	var ship_ok: bool = hud.ship_label.text == "배달 1 · 오배송 1"
	hud._on_next_day()
	await _frames(int(0.3 * PHYS_FPS))
	var next: bool = not hud.day_panel.visible and not f.day_over and f.day == 2 and hud.clock_label.text == "09:00" and hud.ship_label.text == "배달 0 · 오배송 0"
	_check("하루 끝 창 · 배달 수 표시 · 다음 날", shown and ship_ok and next, "창 %s · 배달 '%s' · 다음 날 %s" % [str(shown), hud.ship_label.text, str(next)])


# ---------- 12단계: 아르바이트 직원 ----------

func _parcel_line() -> Shelf:
	## 무한 공급기(택배) → 레일 → 지급 출하대(정문 옆)
	var src = f.place("무한 공급기", Vector2i(44, 19), 0)
	src.item_id = "택배"
	src.per_sec = 4.0
	f.place("레일 Mk1", Vector2i(45, 19), 0)
	return f.get_at(Vector2i(46, 19))


func _clear_workers() -> void:
	for w in main.workers.workers:
		w.queue_free()
	main.workers.workers.clear()
	main.workers._count_couriers()


func _deliveries_in(sec: float) -> int:
	var n0: int = f.today_ok + f.today_bad
	await _frames(int(sec * PHYS_FPS))
	return f.today_ok + f.today_bad - n0


func _test_workers() -> void:
	main.new_room(false)
	_clear_workers()
	f.paused = false
	f.speed = 4.0
	var shelf := _parcel_line()
	await _put(Vector2(30.5, 30.5))
	# 1명: 출하대 → 정문 → 밖(사라짐) → 다시 들어옴. 출하대 자동 배달은 꺼져요
	var w = main.workers.hire("초보 배달 아르바이트")
	w.round_trip = 8.0
	var went_out := false
	var carried := false
	var n0: int = f.today_ok + f.today_bad
	for i in int(7.0 * PHYS_FPS):
		await get_tree().physics_frame
		went_out = went_out or not w.visible
		carried = carried or not w.carried.is_empty()
	var one: int = f.today_ok + f.today_bad - n0
	var auto_off: bool = f.courier_count == 1 and shelf.shipped == 0
	# 2명이면 처리량이 늘어요
	var w2 = main.workers.hire("초보 배달 아르바이트")
	w2.round_trip = 8.0
	await _frames(int(2.0 * PHYS_FPS))
	var two: int = await _deliveries_in(7.0)
	var more: bool = one >= 2 and two >= int(one * 1.6)
	# 직원 탭 → 작은 정보창 (거리 제한 없음)
	f.paused = true
	await _frames(2)
	var vis = w if w.visible else w2
	await _look()
	_touch(0, vis.position / TILE - Vector2(0, 0.6), true)
	await _frames(3)
	_touch(0, vis.position / TILE - Vector2(0, 0.6), false)
	await _frames(3)
	var panel: bool = main.hud.worker_panel.visible and main.hud.worker_shown == vis and main.hud._worker_labels[2].text.begins_with("오늘 배달")
	main.hud.close_worker()
	f.paused = false
	_check("배달 아르바이트: 출하대 → 정문 → 밖 · 자동 배달 꺼짐 · 2명이면 처리량 늘어남 · 탭하면 정보창",
		went_out and carried and auto_off and more and panel,
		"밖으로 %s · 들고 감 %s · 자동 꺼짐 %s · 1명 %d개 → 2명 %d개 · 정보창 %s" % [str(went_out), str(carried), str(auto_off), one, two, str(panel)])
	# 길이 막히면: 출하대를 창고 블록으로 둘러싸요 → 1초마다 다시, 3번 실패하면 말풍선
	f.remove_at(Vector2i(44, 19))
	f.remove_at(Vector2i(45, 19))
	shelf.stack.clear()
	var s2: Shelf = f.place("출하대", Vector2i(20, 20), 0)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		f.place("창고 블록", Vector2i(20, 20) + d, 0)
	for i in 3:
		s2.try_insert(Item.new("택배"), Vector2i(19, 20))
	await _frames(int(3.0 * PHYS_FPS))
	var bubble: bool = (w.blocked and w.state_text() == "길이 막혔어요") or (w2.blocked and w2.state_text() == "길이 막혔어요")
	# 막힌 걸 치우면 다시 가요
	f.remove_at(Vector2i(19, 20))
	await _frames(int(5.0 * PHYS_FPS))
	var unblocked: bool = not w.blocked and not w2.blocked and s2.stack.size() < 3
	_check("길이 막히면 1초마다 다시 · 3번 실패 말풍선 · 뚫리면 다시 가요", bubble and unblocked, "말풍선 %s · 다시 감 %s (남은 택배 %d)" % [str(bubble), str(unblocked), s2.stack.size()])
	_clear_workers()
	f.speed = 1.0
	f.paused = true


func _test_repair_worker() -> void:
	main.new_room(false)
	_clear_workers()
	f.paused = false
	f.speed = 4.0
	var near = f.place("분해기", Vector2i(30, 24), 0)
	var far = f.place("분해기", Vector2i(10, 30), 0)
	var w = main.workers.hire("초보 정비 아르바이트")
	w.zone = Rect2i(25, 15, 20, 20)   # 담당 구역: near만
	near.broken = true
	far.broken = true
	var info_broken: bool = main.hud.info._status(near)[2] == "고장"
	var went := false
	for i in int(5.0 * PHYS_FPS):
		await get_tree().physics_frame
		went = went or w.state == w.S.REPAIR
		if not near.broken:
			break
	var fixed: bool = not near.broken and w.today == 1
	await _frames(int(1.0 * PHYS_FPS))
	var zone_ok: bool = far.broken and w.state != w.S.GO_REPAIR
	_check("정비 아르바이트: 담당 구역 안 고장 설비로 가서 8초 수리 · 구역 밖은 안 가요 · 정보창 '고장'",
		went and fixed and zone_ok and info_broken, "수리 중 봄 %s · 고침 %s · 구역 밖 그대로 %s · 정보창 %s" % [str(went), str(fixed), str(zone_ok), str(info_broken)])
	_clear_workers()
	f.speed = 1.0
	f.paused = true


func _test_courier3() -> void:
	## 배달 아르바이트: 한 번에 최대 3개 · 가던 출하대가 옮겨지면 다시 찾아요
	main.new_room(false)
	_clear_workers()
	f.paused = false
	f.speed = 4.0
	var a: Shelf = f.get_at(Vector2i(46, 19))
	var b: Shelf = f.place("출하대", Vector2i(30, 30), 0)
	for i in 5:
		b.try_insert(Item.new("택배"), Vector2i(29, 30))
	var w = main.workers.hire("배달 아르바이트")
	await _frames(int(0.3 * PHYS_FPS))
	var aimed: bool = w.target == b and w.state == w.S.GO_PICK
	f.move_buildings([b], Vector2i(-6, 0), 0)   # 가는 중에 옮겨요
	var max_carry := 0
	for i in int(6.0 * PHYS_FPS):
		await get_tree().physics_frame
		max_carry = maxi(max_carry, w.carried.size())
	var three: bool = max_carry == 3 and b.stack.size() == 2 and a.stack.is_empty()
	_check("배달 아르바이트: 한 번에 3개 · 출하대를 옮기면 다시 찾아감", aimed and three,
		"처음 목표 %s · 최대 %d개 · 남은 택배 %d" % [str(aimed), max_carry, b.stack.size()])
	_clear_workers()
	f.speed = 1.0
	f.paused = true

