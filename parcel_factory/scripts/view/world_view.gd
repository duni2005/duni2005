extends Node2D
## 공장을 그리는 노드. 큰방 지형은 도트 텍스처(assets/art.gd), 설비는 아직 도형과 글자로 그려요.
## 시뮬레이션 상태는 읽기만 해요.

const TILE := 32.0
const CAT_COLORS := {
	"물류": Color("5a6270"),
	"택배 라인": Color("b07a3a"),
	"생산·가공": Color("3f6fa8"),
	"물": Color("2f8fb0"),
	"전력·방어": Color("a8963f"),
	"크리에이티브": Color("7a4fa8"),
}

const OUTSIDE_COLOR := Color("0b0c0f")
const ROOM_GRID_COLOR := Color(1, 1, 1, 0.035)
const TILE_FLOOR_FROM_X := 40     # 이 x부터 정문 쪽은 카펫 대신 타일 바닥
const EXPANSION_COLOR := Color(0.75, 0.78, 0.85, 0.45)
const POP_SEC := 0.9              # 손으로 꺼낸 물건이 튀어나오는 연출 시간
const POP_GRAVITY := 900.0
const LABEL_SIZE := 26            # 정문·복도 이름 글자 크기
const SUBLABEL_SIZE := 16
const EXPANSION_LABEL_SIZE := 48

var factory: Factory = null
var ghost := {}             # {def, pos, rot, ok}
var selected = null         # Building
var show_layers := true
var font: Font
var _pops: Array = []        # [{p, v, t, id}] 튀어나오는 물건 연출


func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	factory.items_popped.connect(_on_items_popped)


func _process(dt: float) -> void:
	for pop in _pops:
		var v: Vector2 = pop["v"]
		v.y += POP_GRAVITY * dt
		pop["v"] = v
		pop["p"] += v * dt
		pop["t"] += dt
	_pops = _pops.filter(func(pp) -> bool: return pp["t"] < POP_SEC)
	queue_redraw()


func _on_items_popped(_pile, cell: Vector2i, items: Array) -> void:
	var i := 0
	for it in items:
		var ang := -PI * 0.5 + (float(i) - float(items.size() - 1) * 0.5) * 0.45
		_pops.append({"p": cell_center(cell), "v": Vector2(cos(ang), sin(ang)) * 260.0, "t": 0.0, "id": it.id})
		i += 1


func cell_rect(c: Vector2i, s: Vector2i = Vector2i.ONE) -> Rect2:
	return Rect2(Vector2(c) * TILE, Vector2(s) * TILE)


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


func _visible_cells() -> Rect2i:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * get_viewport_rect().size
	var x0 := int(floor(min(a.x, b.x) / TILE)) - 1
	var y0 := int(floor(min(a.y, b.y) / TILE)) - 1
	var x1 := int(ceil(max(a.x, b.x) / TILE)) + 1
	var y1 := int(ceil(max(a.y, b.y) / TILE)) + 1
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


func _draw() -> void:
	if factory == null:
		return
	var vis := _visible_cells()
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var room: Room = factory.room
	if room == null:
		draw_rect(Rect2(Vector2(vis.position) * TILE, Vector2(vis.size) * TILE), Color("1d2026"))
		if zoom > 0.45:
			_draw_grid(vis, vis)
	else:
		draw_rect(Rect2(Vector2(vis.position) * TILE, Vector2(vis.size) * TILE), OUTSIDE_COLOR)
		_draw_room(room, vis)
		if zoom > 0.45:
			_draw_grid(vis, vis if factory.creative else room.interior())
	# 물 샘
	for c in factory.water:
		if vis.has_point(c):
			draw_rect(cell_rect(c).grow(-1), Color("2a5d8a"))
	if show_layers:
		_draw_layer(factory.pipes, Color(0.35, 0.75, 1.0, 0.9), 5.0, vis)
		_draw_layer(factory.wires, Color(1.0, 0.85, 0.2, 0.9), 3.0, vis)
	for b in factory.buildings:
		if not vis.intersects(Rect2i(b.pos, b.size)):
			continue
		_draw_building(b, zoom)
	_draw_pops()
	if selected != null and factory.buildings.has(selected):
		draw_rect(cell_rect(selected.pos, selected.size), Color(1, 1, 1, 0.9), false, 3.0)
	_draw_ghost()


func _draw_grid(vis: Rect2i, area: Rect2i) -> void:
	var g := vis.intersection(area)
	if g.size.x <= 0 or g.size.y <= 0:
		return
	var col := ROOM_GRID_COLOR
	for x in range(g.position.x, g.end.x + 1):
		draw_line(Vector2(x * TILE, g.position.y * TILE), Vector2(x * TILE, g.end.y * TILE), col, 1.0)
	for y in range(g.position.y, g.end.y + 1):
		draw_line(Vector2(g.position.x * TILE, y * TILE), Vector2(g.end.x * TILE, y * TILE), col, 1.0)


# ---------- 큰방 ----------

func _tex_at(key: String, c: Vector2i) -> void:
	draw_texture_rect(Art.tex(key), cell_rect(c), false)


func _draw_room(room: Room, vis: Rect2i) -> void:
	for z in Room.EXPANSIONS:
		_draw_expansion(z["name"], z["rect"])
	# 바닥 (카펫, 정문 쪽은 타일)
	var inner := vis.intersection(room.interior())
	for y in range(inner.position.y, inner.end.y):
		for x in range(inner.position.x, inner.end.x):
			var c := Vector2i(x, y)
			if x >= TILE_FLOOR_FROM_X:
				_tex_at("tile", c)
			else:
				_tex_at("carpet_stain" if absi(hash(c)) % 11 == 0 else "carpet", c)
	# 벽·정문·복도
	var ring := vis.intersection(room.interior().grow(1))
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var c := Vector2i(x, y)
			match room.terrain_at(c):
				Room.T.WALL:
					_tex_at("wall", c)
				Room.T.DOOR:
					_tex_at("door", c)
				Room.T.NO_BUILD:
					_tex_at("hazard", c)
	for r in room.corridor_rects():
		_draw_corridor(r, r.position.y < 0)
	_draw_door(room)
	var wb := cell_rect(Room.WORKBENCH_RECT.position, Room.WORKBENCH_RECT.size)
	_dashed_rect(wb.grow(-2), Color(1, 1, 1, 0.5))
	_text(wb.get_center(), "작업대 자리", 12, Color(1, 1, 1, 0.75), wb.size.x)


func _draw_corridor(r: Rect2i, up: bool) -> void:
	## 벽에 뚫린 입구 + 바깥으로 이어지는 어두운 통로 + 막힘 표시
	var dir := -1 if up else 1
	for k in Room.CORRIDOR_LEN + 1:
		var fade := 1.0 - float(k) / float(Room.CORRIDOR_LEN + 1)
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, r.position.y + dir * k)
			draw_texture_rect(Art.tex("corridor"), cell_rect(c), false, Color(1, 1, 1, fade))
		# 통로 양옆 벽
		var wl := Vector2i(r.position.x - 1, r.position.y + dir * k)
		var wr := Vector2i(r.end.x, r.position.y + dir * k)
		draw_texture_rect(Art.tex("wall"), cell_rect(wl), false, Color(1, 1, 1, fade))
		draw_texture_rect(Art.tex("wall"), cell_rect(wr), false, Color(1, 1, 1, fade))
	for x in range(r.position.x, r.end.x):
		_tex_at("barrier", Vector2i(x, r.position.y))
	var area := cell_rect(r.position, r.size)
	var label_c := area.get_center() + Vector2(0, dir * TILE * 3.0)
	_label_plate(label_c, "복도", "막힘 · 아직 못 들어가요", Color(1, 0.6, 0.55), area.size.x + TILE * 2)


func _draw_door(room: Room) -> void:
	var d := room.door_rect()
	var r := cell_rect(d.position, d.size)
	draw_rect(r, Color("d4a82a"), false, 2.0)
	# 문 밖: 바깥 길 (배달 아르바이트가 드나드는 곳)
	var outside := Rect2(r.position + Vector2(TILE, 0), Vector2(TILE * 3, r.size.y))
	draw_rect(outside, Color("23262b"))
	for i in 3:
		for k in [-3, 3]:
			var p := outside.get_center() + Vector2(-TILE + i * TILE, k * TILE)
			_arrow(p, Vector2.RIGHT, 9.0, Color(1, 1, 1, 0.25), 2.0)
	_label_plate(outside.get_center(), "정문", "배달 출입", Color("f0d070"), outside.size.x)


func _draw_expansion(label: String, rect: Rect2i) -> void:
	var r := cell_rect(rect.position, rect.size)
	_dashed_rect(r, EXPANSION_COLOR)
	_text(r.get_center(), "확장 예정 %s" % label, EXPANSION_LABEL_SIZE, EXPANSION_COLOR, r.size.x)


func _label_plate(c: Vector2, title: String, sub: String, col: Color, width: float) -> void:
	## 어두운 판 위에 큰 이름 + 작은 설명
	var h := float(LABEL_SIZE + SUBLABEL_SIZE) + 16.0
	draw_rect(Rect2(c - Vector2(width * 0.5, h * 0.5), Vector2(width, h)), Color(0, 0, 0, 0.7))
	_text(c - Vector2(0, SUBLABEL_SIZE * 0.6), title, LABEL_SIZE, col, width)
	_text(c + Vector2(0, LABEL_SIZE * 0.6), sub, SUBLABEL_SIZE, col.darkened(0.15), width)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var a := r.position
	var b := r.position + Vector2(r.size.x, 0)
	var c := r.end
	var d := r.position + Vector2(0, r.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		draw_dashed_line(seg[0], seg[1], col, 2.0, 8.0)


func _draw_giant_pile(b: ItemPile) -> void:
	var r := cell_rect(b.pos, b.size)
	for y in range(b.pos.y, b.pos.y + b.size.y):
		for x in range(b.pos.x, b.pos.x + b.size.x):
			var c := Vector2i(x, y)
			_tex_at("trash%d" % (absi(hash(c)) % 3 + 1), c)
	draw_rect(r, Color(0, 0, 0, 0.35), false, 3.0)
	# 출구 자리: 비어 있으면 점선 칸 + 화살표
	for s in b.exit_slots():
		var sr := cell_rect(s)
		var occupant = factory.get_at(s)
		if occupant == null:
			_dashed_rect(sr.grow(-3), Color("f0d070"))
			_arrow(sr.get_center() - Vector2(4, 0), Vector2.RIGHT, 7.0, Color("f0d070"), 2.0)
		draw_rect(Rect2(sr.position - Vector2(4, 0), Vector2(4, TILE)), Color("f0d070"))
	draw_set_transform(r.get_center(), -PI * 0.5, Vector2.ONE)
	_text(Vector2.ZERO, "엄청난 쓰레기 더미 · %s Lv%d" % [b.pile_type, b.level], 20, Color(1, 1, 0.85), r.size.y)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_pops() -> void:
	for pop in _pops:
		var t: float = pop["t"]
		var p: Vector2 = pop["p"]
		var id: String = pop["id"]
		var a := 1.0 - clampf((t - POP_SEC * 0.6) / (POP_SEC * 0.4), 0.0, 1.0)
		var col: Color = DB.color_of(id)
		col.a = a
		draw_circle(p, 9.0, col)
		draw_arc(p, 9.0, 0, TAU, 16, Color(0, 0, 0, 0.5 * a), 1.5)
		_text(p, DB.short(id).substr(0, 2), 8, Color(0, 0, 0, a), 24)


func _draw_layer(layer: Dictionary, col: Color, w: float, vis: Rect2i) -> void:
	for c in layer:
		if not vis.has_point(c):
			continue
		var p := cell_center(c)
		draw_circle(p, w * 0.8, col)
		if layer.has(c + Vector2i(1, 0)):
			draw_line(p, cell_center(c + Vector2i(1, 0)), col, w)
		if layer.has(c + Vector2i(0, 1)):
			draw_line(p, cell_center(c + Vector2i(0, 1)), col, w)


func _arrow(center: Vector2, dir: Vector2, l: float, col: Color, width := 3.0) -> void:
	var tip := center + dir * l
	var side := Vector2(-dir.y, dir.x) * l * 0.6
	draw_line(tip, tip - dir * l * 0.8 + side, col, width)
	draw_line(tip, tip - dir * l * 0.8 - side, col, width)


func _text(p: Vector2, s: String, size: int, col := Color.WHITE, width := 64.0) -> void:
	draw_string(font, p - Vector2(width * 0.5, -size * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _draw_building(b, _zoom: float) -> void:
	var r := cell_rect(b.pos, b.size)
	var cat: String = b.def.get("cat", "물류")
	var base: Color = CAT_COLORS.get(cat, Color.GRAY)
	if b.is_conveyor():
		_draw_conveyor(b, r, base)
		return
	if b is ItemPile and b.is_giant():
		_draw_giant_pile(b)
		return
	draw_rect(r.grow(-2), base.darkened(0.15))
	draw_rect(r.grow(-2), base.lightened(0.25), false, 2.0)
	var c := r.get_center()
	var bs: Vector2i = b.size
	var big: bool = bs.x * bs.y > 1
	_text(c + Vector2(0, -8 if big else 0), b.def.get("short", b.name), 13 if big else 10, Color.WHITE, r.size.x)
	# 레시피 결과물 / 상태
	if b is Machine:
		if b.recipe != null:
			var outs: Array = b.recipe["out"].keys()
			_text(c + Vector2(0, 8), DB.short(outs[0]), 11, Color(1, 1, 0.8), r.size.x)
			var bp: float = b.progress
			var bt: float = b.recipe["t"]
			var frac := clampf(bp / bt, 0.0, 1.0)
			draw_rect(Rect2(r.position + Vector2(4, r.size.y - 8), Vector2((r.size.x - 8) * frac, 4)), Color("6fe07a"))
	elif b is ItemPile:
		_text(c + Vector2(0, 8), "%s Lv%d" % [b.pile_type, b.level], 10, Color(1, 1, 0.8), r.size.x)
	elif b is InfiniteSource:
		_text(c + Vector2(0, 9), DB.short(b.item_id), 9, Color(1, 1, 0.8), r.size.x)
		_arrow(c, Vector2(b.dir_vec()), 12.0, Color(1, 1, 1, 0.7), 2.0)
	elif b is Shelf:
		_text(c + Vector2(0, 8), "%d" % b.stack.size(), 11, Color(1, 1, 0.8), r.size.x)
	elif b is Combiner:
		_arrow(c, Vector2(b.dir_vec()), 12.0, Color(1, 1, 1, 0.7), 2.0)
	# 전력 표시: 빨강 = 연결 안 됨/전력 없음, 노랑 = 부족
	if b.needs_power():
		var m: float = b.power_mult()
		var dot := Color("e05555") if m <= 0.0 else (Color("e0c040") if m < 1.0 else Color("5fd06a"))
		draw_circle(r.position + Vector2(8, 8), 4.0, dot)
	elif b is Generator:
		draw_circle(r.position + Vector2(8, 8), 4.0, Color("5fd06a") if b.running() else Color("e05555"))


func _draw_conveyor(b, r: Rect2, base: Color) -> void:
	var col := Color("3a3f47")
	if b.kind == "rail":
		var sp: float = b.speed
		col = Color("3a3f47") if sp <= 1.0 else (Color("44505e") if sp <= 2.0 else Color("4d5b48"))
	else:
		col = base.darkened(0.2)
	draw_rect(r.grow(-1), col)
	var d := Vector2(b.dir_vec())
	var c := r.get_center()
	_arrow(c - d * 4.0, d, 8.0, Color(1, 1, 1, 0.18), 2.0)
	if b.kind != "rail":
		_text(c + Vector2(0, -9), b.def.get("short", ""), 9, Color(1, 1, 1, 0.85), r.size.x)
	if b is Sorter or b is Judge:
		var sd := Vector2(Building.DIRV[(b.rot + 1) % 4]) if (b is Judge or b.side_right) else Vector2(Building.DIRV[(b.rot + 3) % 4])
		draw_line(c, c + sd * 14.0, Color(1, 0.7, 0.3, 0.8), 2.0)
	if b is Detector and b.selected != "":
		_text(c + Vector2(0, 11), DB.short(b.selected), 8, Color(1, 1, 0.7), r.size.x)
	if b.item != null:
		var prog: float = b.progress
		var p: Vector2 = c + d * (prog - 0.5) * TILE * 0.8
		_draw_item(p, b.item)


func _draw_item(p: Vector2, it: Item) -> void:
	var col: Color = DB.color_of(it.id)
	if DB.is_box(it.id) or it.id == "택배" or it.id == "선물용 택배":
		var s := Vector2(18, 18)
		draw_rect(Rect2(p - s * 0.5, s), Color("c8955a"))
		if it.has_request():
			draw_rect(Rect2(p - s * 0.5, Vector2(18, 5)), Color("f0f0f0") if not it.request_done() else Color("7be07f"))
		if it.id == "선물용 택배":
			draw_line(p - Vector2(0, 9), p + Vector2(0, 9), Color("e04060"), 3.0)
		_text(p + Vector2(0, 3), str(it.contents.size()), 9, Color.BLACK, 18)
		return
	draw_circle(p, 9.0, col)
	draw_arc(p, 9.0, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.5)
	_text(p, DB.short(it.id).substr(0, 2), 8, Color.BLACK, 24)


func _draw_ghost() -> void:
	if ghost.is_empty():
		return
	var def: Dictionary = ghost["def"]
	var s: Vector2i = def["size"]
	if ghost["rot"] % 2 == 1:
		s = Vector2i(s.y, s.x)
	var col := Color(0.4, 1.0, 0.5, 0.35) if ghost["ok"] else Color(1.0, 0.3, 0.3, 0.35)
	var r := cell_rect(ghost["pos"], s)
	draw_rect(r, col)
	draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
	if def["kind"] not in Factory.LAYER_KINDS:
		_arrow(r.get_center(), Vector2(Building.DIRV[ghost["rot"]]), 12.0, Color.WHITE, 3.0)
