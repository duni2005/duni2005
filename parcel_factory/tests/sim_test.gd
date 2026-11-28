extends Node
## 시뮬레이션 단위 테스트. 화면 없이 Factory.step()만 돌려서 분당 수치를 재요.
## 실행: godot --headless --path . res://tests/sim_test.tscn
## 끝나면 결과를 출력하고, 하나라도 실패하면 종료 코드 1로 끝나요.

const Demo := preload("res://scripts/demo.gd")

const WARMUP_SEC := 10.0      # 줄이 꽉 찰 때까지 기다리는 시간
const MEASURE_SEC := 300.0    # 이 시간 동안 센 개수를 분당으로 바꿔요
const TOLERANCE := 0.5        # 분당 허용 오차
const DEMO_SEC := 120.0       # 예시 공장을 돌려 보는 시간
const CYCLES := 60            # 설비 속도는 레시피를 이만큼 돌리는 데 걸린 시간으로 재요
const PILE_SEC := 60.0        # 쓰레기 더미 출구를 지켜보는 시간
const WATCHDOG_SEC := 10.0    # 스크립트 오류로 멈추면 이 시간 뒤 실패로 끝내요

var _fails := 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SEC).timeout.connect(func() -> void: get_tree().quit(2))
	print("=== 시뮬레이션 테스트 ===")
	_test_rail_mk1()
	_test_disassembler_paper()
	_test_half_power()
	_test_room_rules()
	_test_trash_pile()
	_test_inventory()
	_test_hand_actions()
	_test_floor_items()
	_test_demos()
	_test_save_roundtrip()
	print("=== 결과: %s (실패 %d) ===" % ["통과" if _fails == 0 else "실패", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# ---------- 도우미 ----------

func _check(label: String, ok: bool, detail: String) -> void:
	print("[%s] %s — %s" % ["통과" if ok else "실패", label, detail])
	if not ok:
		_fails += 1


func _new_factory() -> Factory:
	var f := Factory.new()
	add_child(f)
	f.paused = true   # _process로 따로 돌지 않게, step()만 써요
	return f


func _new_room_factory() -> Factory:
	## 큰방 + 지형 설비(쓰레기 더미·물 샘)
	var f := _new_factory()
	f.room = Room.new()
	f.room.build_fixed(f)
	return f


func _run(f: Factory, sec: float) -> void:
	var n := int(round(sec / Factory.DT))
	for i in n:
		f.step(Factory.DT)


func _set_recipe(m: Machine, out_name: String, in_name: String) -> void:
	for r in m.available_recipes():
		if r["out"].has(out_name) and r["in"].has(in_name):
			m.set_recipe(r)
			return


func _per_minute(f: Factory, counter: Callable) -> float:
	_run(f, WARMUP_SEC)
	var a: int = counter.call()
	_run(f, MEASURE_SEC)
	var b: int = counter.call()
	return float(b - a) * 60.0 / MEASURE_SEC


## 레시피가 막 끝난 순간부터 CYCLES번 더 끝날 때까지의 시간으로 분당 결과물을 계산해요.
## 결과물이 실제로 레일을 타고 소각기까지 갔는지도 같이 봐요.
func _machine_rate(f: Factory, m: Machine, sink: VoidSink, out_name: String) -> Dictionary:
	_run(f, WARMUP_SEC)
	var k0 := m.made
	while m.made == k0:
		f.step(Factory.DT)
	var t0 := f.sim_time
	var k1 := m.made
	var s0: int = sink.counts.get(out_name, 0)
	while m.made < k1 + CYCLES:
		f.step(Factory.DT)
	var elapsed := f.sim_time - t0
	var made_items := CYCLES * int(m.recipe["out"][out_name])
	var arrived: int = int(sink.counts.get(out_name, 0)) - s0
	var rate := float(made_items) * 60.0 / elapsed
	# 출력 버퍼(최대 4개)만큼은 아직 레일 위에 있을 수 있어요
	return {"rate": rate, "flow_ok": made_items - arrived <= m.output_cap(), "arrived": arrived}


## 무한 공급기(나뭇가지) → 레일 → 분해기 → 레일 → 소각기, 바이오 발전기로 전력.
## extra_machines만큼 같은 전력망에 분해기를 더 놓아 수요를 늘려요.
func _build_paper_rig(f: Factory, extra_machines: int) -> Dictionary:
	var src: InfiniteSource = f.place("무한 공급기", Vector2i(0, 0), 0)
	src.item_id = "나뭇가지"
	src.per_sec = 4.0
	f.place("레일 Mk3", Vector2i(1, 0), 0)
	var m: Machine = f.place("분해기", Vector2i(2, 0), 0)
	_set_recipe(m, "종이", "나뭇가지")
	f.place("레일 Mk3", Vector2i(4, 0), 0)
	var sink: VoidSink = f.place("소각기", Vector2i(5, 0), 0)
	var fuel: InfiniteSource = f.place("무한 공급기", Vector2i(1, 3), 0)
	fuel.item_id = "유기물"
	fuel.per_sec = 1.0
	var gen: Generator = f.place("바이오 발전기", Vector2i(2, 3), 0)
	for y in range(1, 7):
		f.place("전선", Vector2i(2, y), 0)
	for k in extra_machines:
		var x := 2 + 3 * (k + 1)
		var e: Machine = f.place("분해기", Vector2i(x, 6), 0)
		_set_recipe(e, "종이", "나뭇가지")
		for dx in 3:
			f.place("전선", Vector2i(x - dx, 6), 0)
	return {"machine": m, "sink": sink, "gen": gen}


# ---------- 테스트 ----------

func _test_rail_mk1() -> void:
	var f := _new_factory()
	var src: InfiniteSource = f.place("무한 공급기", Vector2i(0, 0), 0)
	src.item_id = "바위"
	src.per_sec = 4.0
	for x in range(1, 11):
		f.place("레일 Mk1", Vector2i(x, 0), 0)
	var sink: VoidSink = f.place("소각기", Vector2i(11, 0), 0)
	var rate := _per_minute(f, func() -> int: return sink.total)
	var want: float = 60.0 * float(DB.buildings["레일 Mk1"]["speed"])
	_check("레일 Mk1 1분 = 60개", absf(rate - want) <= TOLERANCE and is_equal_approx(want, 60.0), "분당 %.2f개 (기대 %d)" % [rate, int(want)])
	f.free()


func _test_disassembler_paper() -> void:
	var f := _new_factory()
	var rig := _build_paper_rig(f, 0)
	var m: Machine = rig["machine"]
	var res := _machine_rate(f, m, rig["sink"], "종이")
	var rate: float = res["rate"]
	var want: float = float(m.recipe["out"]["종이"]) * 60.0 / float(m.recipe["t"])
	_check("분해기 나뭇가지→종이 분당 60", absf(rate - want) <= TOLERANCE and is_equal_approx(want, 60.0) and res["flow_ok"], "분당 %.2f개 (기대 %d, 전력 %d%%, 소각기 도착 %d개)" % [rate, int(want), int(m.power_mult() * 100.0), res["arrived"]])
	f.free()


func _test_half_power() -> void:
	# 바이오 발전기 공급 ÷ 분해기 전력 × 2 = 필요한 분해기 수 (JSON 수치 기준)
	var gen_supply: float = DB.buildings["바이오 발전기"]["gen"]
	var per_machine: float = DB.buildings["분해기"]["power"]
	var total := int(round(gen_supply * 2.0 / per_machine))
	var f := _new_factory()
	var rig := _build_paper_rig(f, total - 1)
	var m: Machine = rig["machine"]
	var res := _machine_rate(f, m, rig["sink"], "종이")
	var rate: float = res["rate"]
	var full: float = float(m.recipe["out"]["종이"]) * 60.0 / float(m.recipe["t"])
	var sat: float = m.power_mult()
	_check("전력 50% 부족 시 속도 절반", is_equal_approx(sat, 0.5) and absf(rate - full * 0.5) <= TOLERANCE and res["flow_ok"], "충족률 %d%% · 분당 %.2f개 (기대 %.0f, 분해기 %d대)" % [int(sat * 100.0), rate, full * 0.5, total])
	f.free()


func _test_room_rules() -> void:
	var f := _new_room_factory()
	var rail: Dictionary = DB.buildings["레일 Mk1"]
	var door_y := f.room.door_rect().position.y + 2
	var corridor: Rect2i = f.room.corridor_rects()[0]
	var blocked := {
		"벽": Vector2i(-1, 5),
		"정문": Vector2i(Room.W, door_y),
		"정문 앞 통로": Vector2i(Room.W - 1, door_y),
		"복도": corridor.position,
		"방 밖": Vector2i(-5, -5),
		"작업대 자리": Room.WORKBENCH_RECT.position,
		"쓰레기 더미 위": Vector2i(2, 10),
	}
	var wrong := []
	for k in blocked:
		if f.can_place(rail, blocked[k], 0):
			wrong.append(k)
	f.place("전선", Vector2i(-1, 5), 0)
	if f.wires.has(Vector2i(-1, 5)):
		wrong.append("벽 위 전선")
	var floor_ok := f.can_place(rail, Vector2i(20, 20), 0)
	_check("큰방: 벽·정문·통로·복도·방 밖 설치 불가", wrong.is_empty() and floor_ok, "막혀야 하는데 놓인 곳: %s · 바닥 설치 %s" % [str(wrong), "가능" if floor_ok else "불가"])
	var pile_kept := not f.remove_at(Vector2i(1, 1))
	f.creative = true
	var creative_ok := f.can_place(rail, Vector2i(-1, 5), 0) and f.can_place(rail, Vector2i(-5, -5), 0) and f.can_place(rail, Vector2i(Room.W - 1, door_y), 0)
	_check("크리에이티브: 켜면 어디든 설치 · 끄면 더미 철거 불가", pile_kept and creative_ok, "더미 남음 %s · 크리에이티브 벽/밖/통로 설치 %s" % [str(pile_kept), str(creative_ok)])
	f.free()


func _test_trash_pile() -> void:
	var f := _new_room_factory()
	var pile: ItemPile = f.get_at(Room.PILE_POS)
	var slots: Array = pile.exit_slots()
	var slot: Vector2i = slots[0]
	var bad := slot + Vector2i(0, 2)
	var bad_exit = f.place("출구", bad, 0)
	f.place("출구", slot, 0)
	f.place("레일 Mk1", slot + Vector2i(1, 0), 0)
	var sink: VoidSink = f.place("소각기", slot + Vector2i(2, 0), 0)
	# 출구 자리가 아닌 곳의 바깥쪽 레일로는 자동 출력되지 않아야 해요
	f.place("레일 Mk1", bad, 0)
	var sink2: VoidSink = f.place("소각기", bad + Vector2i(1, 0), 0)
	_run(f, PILE_SEC)
	var mix: Dictionary = DB.piles[pile.pile_type]
	var only_raw := true
	for k in sink.counts:
		if not mix.has(k):
			only_raw = false
	_check("쓰레기 더미 → 출구 자리에서 원재료", sink.total > 0 and only_raw and pile.level == 1 and slots.size() == int(pile.def["exit_slots"]), "출구 자리 %d곳 · %d초 동안 %d개 %s · Lv%d" % [slots.size(), int(PILE_SEC), sink.total, str(sink.counts.keys()), pile.level])
	_check("쓰레기 더미: 출구 자리 밖은 막힘", bad_exit == null and sink2.total == 0, "자리 밖 출구 %s · 자리 밖 레일로 나온 수 %d" % ["못 놓음" if bad_exit == null else "놓임", sink2.total])
	var inv := Inventory.new()
	var got: Array = f.hand_pull(pile, pile.pos, inv)
	var r := pile.hand_pull_range()
	_check("쓰레기 더미: 손으로 뒤지면 3~5개 → 가방", got.size() >= r.x and got.size() <= r.y and r == Vector2i(3, 5) and inv.total() == got.size(), "%d개 (범위 %d~%d) · 가방 %d개" % [got.size(), r.x, r.y, inv.total()])
	f.free()


func _test_inventory() -> void:
	var inv := Inventory.new()
	# 쌓기: 일반 50 · 설비 20 · 레일·전선·파이프 100, 넘치면 못 넣은 수를 돌려줘요
	var left := inv.add("종이", 120)
	var paper_ok := left == 0 and inv.used_slots() == 3 and inv.count("종이") == 120
	inv.add("[설비] 포장기", 25)
	inv.add("[설비] 레일 Mk1", 150)
	var stack_ok: bool = inv.used_slots() == 3 + 2 + 2 and inv.slots[3]["n"] == 20 and inv.slots[5]["n"] == 100
	# 핫바부터 채워요
	var hotbar_first := inv.id_at(0) == "종이" and inv.id_at(Inventory.HOTBAR - 1) == ""
	# 내용물이 있는 박스는 1칸 1개
	var box := Item.new("작은 택배 박스")
	box.contents = ["장난감"]
	inv.add(box, 1)
	inv.add(box, 1)
	var unique_ok := inv.count("작은 택배 박스") == 2 and inv.used_slots() == 9
	# 빼기: 고른 칸부터
	var got := inv.remove("종이", 60, 2)
	var remove_ok := got.size() == 60 and inv.count("종이") == 60 and inv.id_at(2) == ""
	# 가득 차면 못 넣은 수
	var full := Inventory.new()
	var rest := full.add("나사", Inventory.SLOTS * Inventory.STACK_ITEM + 7)
	var full_ok := rest == 7 and not full.can_accept("바위") and full.can_accept("나사") == false
	_check("인벤토리: 쌓기 50·20·100, 핫바 먼저, 박스 1칸 1개, 가득이면 남은 수", paper_ok and stack_ok and hotbar_first and unique_ok and remove_ok and full_ok,
		"종이 %s · 설비/레일 %s · 핫바 먼저 %s · 박스 %s · 빼기 %s · 가득 %s" % [str(paper_ok), str(stack_ok), str(hotbar_first), str(unique_ok), str(remove_ok), str(full_ok)])
	# 가방 정리: 옮기기·합치기·바꾸기·반 나누기·빠른 이동
	var g := Inventory.new()
	g.add("바위", 30)                    # 0칸
	g.move_slot(0, 12)                   # 가방 칸으로 옮기기
	var moved := g.id_at(0) == "" and g.id_at(12) == "바위"
	g.add("바위", 30)                    # 12칸 50, 0칸 10
	g.move_slot(0, 12)                   # 가득이라 합쳐지지 않아요 → 그대로
	var merge_full: bool = g.slots[12]["n"] == 50 and g.slots[0]["n"] == 10
	g.add("종이", 5)
	g.move_slot(1, 0)                    # 다른 물건 → 자리 바꾸기
	var swapped := g.id_at(0) == "종이" and g.id_at(1) == "바위"
	var e := g.split_slot(12)
	var split_ok: bool = e >= Inventory.HOTBAR and g.slots[12]["n"] == 25 and g.slots[e]["n"] == 25
	g.quick_move(0)                      # 핫바 → 가방
	var quick_ok := g.id_at(0) == "" and g.count("종이") == 5
	_check("가방 정리: 옮기기·합치기·바꾸기·반 나누기·빠른 이동", moved and merge_full and swapped and split_ok and quick_ok,
		"옮기기 %s · 가득 합치기 %s · 바꾸기 %s · 반 나누기 %s · 빠른 이동 %s" % [str(moved), str(merge_full), str(swapped), str(split_ok), str(quick_ok)])
	# 제작법 '×4'는 4개 지급
	var four := false
	for r in DB.recipes_by_machine.get("설비 제작대", []):
		if r["out"].has("[설비] 레일 Mk1"):
			four = int(r["out"]["[설비] 레일 Mk1"]) == 4
	_check("설비 아이템 이름: '[설비] 레일 Mk1 ×4' → [설비] 레일 Mk1 4개", four, str(four))


func _test_hand_actions() -> void:
	var f := _new_room_factory()
	var inv := Inventory.new()
	# 레일 위 물건 줍기
	var rail: Conveyor = f.place("레일 Mk1", Vector2i(10, 10), 0)
	rail.item = Item.new("바위")
	var picked := f.pick_item(rail, inv) and rail.item == null and inv.count("바위") == 1
	# 설비에 넣기: 맞는 재료는 들어가고, 안 맞는 건 가방에 그대로
	var m: Machine = f.place("분해기", Vector2i(12, 12), 0)
	_set_recipe(m, "종이", "나뭇가지")
	inv.add("나뭇가지", 3)
	inv.add("종이", 2)
	var twig := _slot_of(inv, "나뭇가지")
	var ins_ok := f.insert_from(inv, twig, m) and int(m.inputs.get("나뭇가지", 0)) == 1 and inv.count("나뭇가지") == 2
	var ins_bad := not f.insert_from(inv, _slot_of(inv, "종이"), m) and inv.count("종이") == 2
	# 결과물·보관물 꺼내기
	var st: StorageBlock = f.place("창고 블록", Vector2i(15, 12), 0)
	for i in 5:
		st.try_insert(Item.new("유리"), Vector2i(14, 12))
	var took := f.take_outputs(st, inv, 50)
	_check("손: 줍기·넣기·꺼내기", picked and ins_ok and ins_bad and took == 5 and inv.count("유리") == 5,
		"줍기 %s · 넣기 %s · 잘못 넣기 막힘 %s · 꺼냄 %d개" % [str(picked), str(ins_ok), str(ins_bad), took])
	# 철거: 설비 아이템 + 안에 든 재료를 돌려받아요
	var before := inv.count("나뭇가지")
	var dec := f.deconstruct(m, inv) and not f.buildings.has(m) and inv.count("[설비] 분해기") == 1 and inv.count("나뭇가지") == before + 1
	var pile_kept := not f.deconstruct(f.get_at(Room.PILE_POS), inv)
	# 가방이 꽉 차면 철거한 설비는 바닥에 떨어져요
	var full := Inventory.new()
	full.add("나사", Inventory.SLOTS * Inventory.STACK_ITEM)
	var dropped := f.deconstruct(rail, full) and not f.buildings.has(rail) and _floor_count(f, "[설비] 레일 Mk1") == 1
	_check("손: 철거 → 설비 아이템 + 내용물이 가방으로 (가득이면 바닥에)", dec and pile_kept and dropped,
		"철거 %s · 더미는 못 지움 %s · 가득이면 바닥에 %s" % [str(dec), str(pile_kept), str(dropped)])
	f.free()


func _test_floor_items() -> void:
	var f := _new_room_factory()
	var fl := f.floor_items
	fl.spawn("바위", 3, Vector2(20.5, 20.5), 0.0, false)
	fl.spawn("바위", 2, Vector2(20.7, 20.2), 0.0, false)   # 같은 칸 → 합쳐져요
	fl.spawn("바위", 1, Vector2(22.5, 20.5), 0.0, false)   # 다른 칸
	var merged := fl.drops.size() == 2 and _floor_count(f, "바위") == 6
	var inv := Inventory.new()
	var left := f.pickup_drop(fl.drops[0], inv)
	var picked := left == 0 and inv.count("바위") == 5 and fl.drops.size() == 1
	var full := Inventory.new()
	full.add("나사", Inventory.SLOTS * Inventory.STACK_ITEM)
	var stays := f.pickup_drop(fl.drops[0], full) == 1 and fl.drops.size() == 1
	# 바닥 아이템은 시뮬레이션에 영향 없음: 레일 위에 놓아도 레일은 비어 있어요
	var rail: Conveyor = f.place("레일 Mk1", Vector2i(25, 20), 0)
	fl.spawn("종이", 1, Vector2(25.5, 20.5), 0.0, false)
	_run(f, 2.0)
	var no_sim := rail.item == null and _floor_count(f, "종이") == 1
	_check("바닥 아이템: 같은 칸 합치기 · 줍기 · 가득이면 남음 · 레일이 끌고 가지 않음", merged and picked and stays and no_sim,
		"합치기 %s · 줍기 %s · 가득이면 남음 %s · 시뮬레이션 영향 없음 %s" % [str(merged), str(picked), str(stays), str(no_sim)])
	f.free()


func _slot_of(inv: Inventory, id: String) -> int:
	for i in Inventory.SLOTS:
		if inv.id_at(i) == id:
			return i
	return -1


func _floor_count(f: Factory, id: String) -> int:
	var n := 0
	for d in f.floor_items.drops:
		if d["id"] == id:
			n += int(d["n"])
	return n


func _test_demos() -> void:
	# 예시는 큰방(지형 + 지급 설비) 안에 깔려야 해요
	var plain := _new_factory()
	Demo.build(plain)
	var want := plain.buildings.size()
	plain.free()
	var f := _new_room_factory()
	f.room.build_given(f)
	var n0 := f.buildings.size()
	Demo.build(f)
	_check("예시 공장이 큰방 안에 전부 깔림", f.buildings.size() - n0 == want, "%d / %d개" % [f.buildings.size() - n0, want])
	var o := Demo.ORIGIN
	_run(f, DEMO_SEC)
	# A: 창고에 박스
	var st: StorageBlock = f.get_at(Vector2i(11, 0) + o)
	var boxes := 0
	for it in st.group.items:
		if it.id == "작은 택배 박스":
			boxes += 1
	_check("예시 A 종이→박스 → 창고", boxes > 0, "창고의 작은 택배 박스 %d개" % boxes)
	# B: 출하대 정상 배달
	var sh: Shelf = f.get_at(Vector2i(9, 13) + o)
	_check("예시 B 요청 포장 → 정상 배달", sh.shipped_ok > 0 and sh.shipped_ok == sh.shipped, "배달 %d · 정상 %d" % [sh.shipped, sh.shipped_ok])
	# C: 옆 소각기에는 장난감만, 앞 소각기에는 장난감 없음
	var side: VoidSink = f.get_at(Vector2i(23, 2) + o)
	var front: VoidSink = f.get_at(Vector2i(25, 0) + o)
	var toys: int = side.counts.get("장난감", 0)
	_check("예시 C 분류기 장난감만 옆으로", toys > 0 and toys == side.total and not front.counts.has("장난감") and front.total > 0, "옆 %d개(장난감 %d) · 앞 %d개(장난감 %d)" % [side.total, toys, front.total, int(front.counts.get("장난감", 0))])
	# D: 창고에 물 양동이만
	var ws: StorageBlock = f.get_at(Vector2i(21, 7) + o)
	var filled := 0
	for it in ws.group.items:
		if it.id == "물 양동이":
			filled += 1
	_check("예시 D 주입기 양동이 → 물 양동이", filled > 0 and filled == ws.group.items.size(), "창고 %d개 중 물 양동이 %d개" % [ws.group.items.size(), filled])
	f.free()


func _test_save_roundtrip() -> void:
	var a := _new_room_factory()
	a.room.build_given(a)
	Demo.build(a)
	var so: Sorter = a.get_at(Vector2i(23, 0) + Demo.ORIGIN)
	so.mode = "inverse"
	a.floor_items.spawn("바위", 4, Vector2(30.5, 30.5), 0.0, false)
	var box := Item.new("작은 택배 박스")
	box.request = {"items": {"장난감": 2}, "fragile": false, "gift": false}
	a.floor_items.spawn(box, 1, Vector2(31.5, 30.5), 0.0, false)
	var text := JSON.stringify(a.to_save())
	var b := _new_factory()
	b.room = Room.new()
	var parsed = JSON.parse_string(text)
	var ok: bool = b.load_save(parsed)
	var same: bool = ok and JSON.stringify(b.to_save()) == text
	var floor_ok := b.floor_items.drops.size() == 2 and b.floor_items.drops[1]["item"] != null and int(b.floor_items.drops[1]["item"].request["items"]["장난감"]) == 2
	# 인벤토리 저장
	var inv := Inventory.new()
	inv.add("[설비] 레일 Mk1", 130)
	inv.add(box, 1)
	var inv2 := Inventory.new()
	inv2.load_save(JSON.parse_string(JSON.stringify(inv.to_save())))
	var inv_ok := JSON.stringify(inv2.to_save()) == JSON.stringify(inv.to_save()) and inv2.count("[설비] 레일 Mk1") == 130
	_check("저장 → 불러오기 그대로 (바닥 아이템·인벤토리 포함)", same and floor_ok and inv_ok, "설비 %d / %d · 전선 %d / %d · 파이프 %d / %d · 바닥 %s · 인벤토리 %s" % [b.buildings.size(), a.buildings.size(), b.wires.size(), a.wires.size(), b.pipes.size(), a.pipes.size(), str(floor_ok), str(inv_ok)])
	a.free()
	b.free()
