extends Node2D
## 큰방 위에 겹쳐 그리는 표시: 확장 예정 점선, 정문·복도 이름판, 복도 어둠, 작업대 자리,
## 쓰레기 더미 출구 자리, 설치 중일 때 격자. 시뮬레이션 상태는 읽기만 해요.

const TILE := 32.0
const LABEL_SIZE := 26
const SUBLABEL_SIZE := 16
const EXPANSION_LABEL_SIZE := 48
const GRID_ALPHA := 0.08

var world = null   # world_view
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var room: Room = world.factory.room
	if room == null:
		return
	var ink := Palette.c(Palette.INK)
	var outside := ink.darkened(0.45)
	for z in Room.EXPANSIONS:
		_draw_expansion(z["name"], z["rect"])
	for r in room.corridor_rects():
		_draw_corridor(r, r.position.y < 0, outside)
	_draw_door(room)
	var wb: Rect2 = world.cell_rect(Room.WORKBENCH_RECT.position, Room.WORKBENCH_RECT.size)
	_dashed_rect(wb.grow(-3), Palette.c(Palette.CREAM))
	_text(wb.get_center(), "작업대 자리", 12, Palette.c(Palette.CREAM), wb.size.x)
	_draw_pile_slots()
	if not world.ghost.is_empty():
		_draw_grid(room)


func _draw_corridor(r: Rect2i, up: bool, outside: Color) -> void:
	## 통로 끝으로 갈수록 어둠에 묻히게 + 이름판
	var dir := -1.0 if up else 1.0
	var x0 := (r.position.x - 1) * TILE
	var x1 := (r.end.x + 1) * TILE
	var near := (r.position.y + (0.0 if up else 1.0)) * TILE
	var far := near + dir * Room.CORRIDOR_LEN * TILE
	var clear := Color(outside, 0.0)
	draw_polygon(PackedVector2Array([Vector2(x0, near), Vector2(x1, near), Vector2(x1, far), Vector2(x0, far)]),
		PackedColorArray([clear, clear, outside, outside]))
	var area: Rect2 = world.cell_rect(r.position, r.size)
	_label_plate(area.get_center() + Vector2(0, dir * TILE * 3.0), "복도", "막힘 · 아직 못 들어가요", Palette.c(Palette.PINK), area.size.x + TILE * 2)


func _draw_door(room: Room) -> void:
	var d := room.door_rect()
	var r: Rect2 = world.cell_rect(d.position, d.size)
	var outside := Rect2(r.position + Vector2(TILE, 0), Vector2(TILE * 3, r.size.y))
	draw_rect(outside, Palette.c(Palette.G1))
	for i in 3:
		for k in [-3, 3]:
			_chevron(outside.get_center() + Vector2(-TILE + i * TILE, k * TILE), Palette.c(Palette.G3))
	_label_plate(outside.get_center(), "정문", "배달 출입", Palette.c(Palette.YELLOW), outside.size.x)


func _draw_pile_slots() -> void:
	for b in world.factory.buildings:
		if not (b is ItemPile) or not b.is_giant():
			continue
		var col := Palette.c(Palette.YELLOW)
		for s in b.exit_slots():
			var sr: Rect2 = world.cell_rect(s)
			draw_rect(Rect2(sr.position - Vector2(4, 0), Vector2(4, TILE)), col)
			if world.factory.get_at(s) == null:
				_dashed_rect(sr.grow(-3), col)
				_chevron(sr.get_center(), col)


func _draw_grid(room: Room) -> void:
	var g: Rect2i = room.interior()
	if world.factory.creative:
		var v: Rect2 = world.visible_rect()
		g = Rect2i(Vector2i(v.position / TILE), Vector2i(v.size / TILE) + Vector2i.ONE)
	var col := Color(Palette.c(Palette.INK), GRID_ALPHA)
	for x in range(g.position.x, g.end.x + 1):
		draw_line(Vector2(x * TILE, g.position.y * TILE), Vector2(x * TILE, g.end.y * TILE), col, 1.0)
	for y in range(g.position.y, g.end.y + 1):
		draw_line(Vector2(g.position.x * TILE, y * TILE), Vector2(g.end.x * TILE, y * TILE), col, 1.0)


func _draw_expansion(label: String, rect: Rect2i) -> void:
	var r: Rect2 = world.cell_rect(rect.position, rect.size)
	var col := Color(Palette.c(Palette.G4), 0.5)
	_dashed_rect(r, col)
	_text(r.get_center(), "확장 예정 %s" % label, EXPANSION_LABEL_SIZE, col, r.size.x)


# ---------- 그리기 도우미 ----------

func _chevron(c: Vector2, col: Color) -> void:
	draw_line(c + Vector2(-4, -7), c + Vector2(4, 0), col, 3.0)
	draw_line(c + Vector2(-4, 7), c + Vector2(4, 0), col, 3.0)


func _text(p: Vector2, s: String, size: int, col: Color, width: float) -> void:
	draw_string(font, p - Vector2(width * 0.5, -size * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _label_plate(c: Vector2, title: String, sub: String, col: Color, width: float) -> void:
	var h := float(LABEL_SIZE + SUBLABEL_SIZE) + 16.0
	draw_rect(Rect2(c - Vector2(width * 0.5, h * 0.5), Vector2(width, h)), Color(Palette.c(Palette.INK), 0.8))
	_text(c - Vector2(0, SUBLABEL_SIZE * 0.6), title, LABEL_SIZE, col, width)
	_text(c + Vector2(0, LABEL_SIZE * 0.6), sub, SUBLABEL_SIZE, col.darkened(0.15), width)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var a := r.position
	var b := r.position + Vector2(r.size.x, 0)
	var c := r.end
	var d := r.position + Vector2(0, r.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		draw_dashed_line(seg[0], seg[1], col, 2.0, 8.0)
