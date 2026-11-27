extends RefCounted
## '예시' 버튼으로 까는 시험용 공장 4개.
##  A. 종이 → 박스 라인 (분해기 → 가공기 → 창고) + 바이오 발전기
##  B. 요청 포장 라인 (작업 컴퓨터 → 결합기 → 감지기 2개 → 판정기 → 포장기 → 출하대)
##  C. 물건 더미 → 출구 → 분류기 (장난감만 옆으로)
##  D. 물 라인 (물 샘 → 펌프 → 파이프 → 주입기로 양동이 채우기)


static func _rail(f, x: int, y: int, r: int, n := "레일 Mk1"):
	return f.place(n, Vector2i(x, y), r)


static func _wire_line(f, a: Vector2i, b: Vector2i) -> void:
	var c := a
	f.place("전선", c, 0)
	while c != b:
		if c.x != b.x:
			c.x += signi(b.x - c.x)
		else:
			c.y += signi(b.y - c.y)
		f.place("전선", c, 0)


static func _recipe(m, out_name: String, in_name: String = "") -> void:
	for r in m.available_recipes():
		if r["out"].has(out_name) and (in_name == "" or r["in"].has(in_name)):
			m.set_recipe(r)
			return


static func build(f) -> void:
	# ---- A. 종이 → 박스 ----
	var s = f.place("무한 공급기", Vector2i(0, 0), 0)
	s.item_id = "나뭇가지"
	_rail(f, 1, 0, 0)
	_rail(f, 2, 0, 0)
	var m1 = f.place("분해기", Vector2i(3, 0), 0)
	_recipe(m1, "종이", "나뭇가지")
	_rail(f, 5, 0, 0)
	_rail(f, 6, 0, 0)
	var m2 = f.place("가공기", Vector2i(7, 0), 0)
	_recipe(m2, "작은 택배 박스")
	_rail(f, 9, 0, 0)
	_rail(f, 10, 0, 0)
	f.place("창고 블록", Vector2i(11, 0), 0)
	f.place("창고 블록", Vector2i(12, 0), 0)
	var g1 = f.place("바이오 발전기", Vector2i(3, 3), 0)
	var fuel1 = f.place("무한 공급기", Vector2i(2, 3), 0)
	fuel1.item_id = "유기물"
	fuel1.per_sec = 1.0
	_wire_line(f, Vector2i(3, 1), Vector2i(8, 1))
	_wire_line(f, Vector2i(3, 1), Vector2i(3, 3))

	# ---- B. 요청 포장 라인 ----
	var pc = f.place("작업 컴퓨터", Vector2i(0, 6), 0)
	pc.order_items = ["장난감", "나뭇가지"]
	pc.max_kinds = 2
	pc.max_total = 3
	_rail(f, 2, 6, 0)
	f.place("요청 결합기", Vector2i(3, 6), 0)
	var bx = f.place("무한 공급기", Vector2i(3, 8), 3)
	bx.item_id = "작은 택배 박스"
	bx.per_sec = 1.0
	_rail(f, 3, 7, 3)
	_rail(f, 4, 6, 0)
	var d1 = f.place("요청 감지기", Vector2i(5, 6), 0)
	d1.selected = "장난감"
	var t1 = f.place("무한 공급기", Vector2i(5, 8), 3)
	t1.item_id = "장난감"
	_rail(f, 5, 7, 3)
	_rail(f, 6, 6, 0)
	var d2 = f.place("요청 감지기", Vector2i(7, 6), 0)
	d2.selected = "나뭇가지"
	var t2 = f.place("무한 공급기", Vector2i(7, 8), 3)
	t2.item_id = "나뭇가지"
	_rail(f, 7, 7, 3)
	_rail(f, 8, 6, 0)
	f.place("완료 판정기", Vector2i(9, 6), 0)
	f.place("소각기", Vector2i(10, 6), 0)
	_rail(f, 9, 7, 1)
	_rail(f, 9, 8, 1)
	f.place("포장기", Vector2i(9, 9), 0)
	var tp = f.place("무한 공급기", Vector2i(12, 9), 2)
	tp.item_id = "박스 테이프"
	tp.per_sec = 1.0
	_rail(f, 11, 9, 2)
	_rail(f, 9, 11, 1)
	_rail(f, 9, 12, 1)
	f.place("출하대", Vector2i(9, 13), 0)
	f.place("바이오 발전기", Vector2i(11, 4), 0)
	var fuel2 = f.place("무한 공급기", Vector2i(13, 4), 2)
	fuel2.item_id = "유기물"
	fuel2.per_sec = 1.0
	_wire_line(f, Vector2i(3, 6), Vector2i(11, 6))
	_wire_line(f, Vector2i(11, 6), Vector2i(11, 5))
	_wire_line(f, Vector2i(9, 6), Vector2i(9, 9))

	# ---- C. 물건 더미 → 분류기 ----
	f.place("물건 더미", Vector2i(16, 0), 0)
	f.place("출구", Vector2i(18, 0), 0)
	for x in range(19, 23):
		_rail(f, x, 0, 0)
	var so = f.place("분류기", Vector2i(23, 0), 0)
	so.filter_item = "장난감"
	_rail(f, 23, 1, 1)
	f.place("소각기", Vector2i(23, 2), 0)
	_rail(f, 24, 0, 0)
	f.place("소각기", Vector2i(25, 0), 0)

	# ---- D. 물 라인 ----
	f.place("물 샘", Vector2i(16, 6), 0)
	f.place("펌프", Vector2i(16, 6), 0)
	var bk = f.place("무한 공급기", Vector2i(17, 7), 0)
	bk.item_id = "양동이"
	bk.per_sec = 1.0
	_rail(f, 18, 7, 0)
	f.place("주입기", Vector2i(19, 7), 0)
	_rail(f, 20, 7, 0)
	f.place("창고 블록", Vector2i(21, 7), 0)
	f.place("창고 블록", Vector2i(22, 7), 0)
	for x in range(16, 20):
		f.place("파이프", Vector2i(x, 6), 0)
	f.place("파이프", Vector2i(19, 7), 0)
	# 물 라인 전력은 A 발전기에 이어요
	_wire_line(f, Vector2i(8, 1), Vector2i(16, 1))
	_wire_line(f, Vector2i(16, 1), Vector2i(16, 6))
	_wire_line(f, Vector2i(16, 6), Vector2i(19, 6))
	_wire_line(f, Vector2i(19, 6), Vector2i(19, 7))
	if g1 == null:
		push_warning("예시 A 발전기를 놓지 못했어요")
