extends Node
## 플레이어 테스트: 실제 main 씬에서 물리 프레임을 돌려 이동·충돌·상호작용을 확인해요.
## 실행: godot --headless --path . res://tests/player_test.tscn
## (저장 파일은 건드리지 않고, 시작할 때 큰방을 새로 깔아요)

const TILE := 32.0
const PHYS_FPS := 60.0
const WATCHDOG_SEC := 90.0
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

