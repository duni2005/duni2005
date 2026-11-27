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
	var before := f.hand_total()
	var got: Array = f.hand_pull(pile, pile.pos)
	var r := pile.hand_pull_range()
	_check("쓰레기 더미: 손으로 뒤지면 3~5개", got.size() >= r.x and got.size() <= r.y and r == Vector2i(3, 5) and f.hand_total() == before + got.size(), "%d개 (범위 %d~%d)" % [got.size(), r.x, r.y])
	f.free()


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
	var text := JSON.stringify(a.to_save())
	var b := _new_factory()
	b.room = Room.new()
	var parsed = JSON.parse_string(text)
	var ok: bool = b.load_save(parsed)
	var same: bool = ok and JSON.stringify(b.to_save()) == text
	_check("저장 → 불러오기 그대로", same, "설비 %d / %d · 전선 %d / %d · 파이프 %d / %d" % [b.buildings.size(), a.buildings.size(), b.wires.size(), a.wires.size(), b.pipes.size(), a.pipes.size()])
	a.free()
	b.free()
