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
	# 들고 탭 → 1개 넣기, 맨손 탭 → 꺼내기
	var st = f.place("창고 블록", Vector2i(8, 12), 0)
	await _put(Vector2(7.0, 12.5))
	await _walk(Vector2.RIGHT, 0.1)
	var before: int = player.inventory.total()
	player.select_hotbar(0)   # 핫바 0칸 = 뒤져서 찾은 첫 물건
	player.action_press()
	await _frames(2)
	player.action_release()
	var put_one: bool = st.group.items.size() == 1 and player.inventory.total() == before - 1
	player.select_hotbar(0)   # 같은 칸을 다시 고르면 맨손
	player.action_press()
	await _frames(2)
	player.action_release()
	var taken: bool = st.group.items.is_empty() and player.inventory.total() == before
	_check("넣기·꺼내기: 핫바로 들고 탭 = 1개 넣기 · 맨손 탭 = 꺼내기", put_one and taken and player.hotbar == -1,
		"대상 %s · 넣음 %s · 꺼냄 %s" % [player.target.name if player.target != null else "없음", str(put_one), str(taken)])


func _test_deconstruct() -> void:
	var st = player.target
	player.hotbar = -1
	player.action_press()
	await _frames(int(0.6 * PHYS_FPS))
	var gauge: float = player.progress()
	await _frames(int(1.0 * PHYS_FPS))
	player.action_release()
	var gone: bool = st != null and not f.buildings.has(st)
	_check("철거: 꾹 1초 → 설비 아이템으로 돌려받기", gone and player.inventory.count("[설비] 창고 블록") == 1 and gauge > 0.0,
		"게이지 %.2f · 철거됨 %s · [설비] 창고 블록 %d개" % [gauge, str(gone), player.inventory.count("[설비] 창고 블록")])


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

