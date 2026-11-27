extends Node2D
## 공장을 그리는 노드. 그래픽 에셋 없이 도형과 글자로만 그려요.
## (픽셀아트는 나중에 이 파일만 바꾸면 돼요.)

const TILE := 32.0
const CAT_COLORS := {
	"물류": Color("5a6270"),
	"택배 라인": Color("b07a3a"),
	"생산·가공": Color("3f6fa8"),
	"물": Color("2f8fb0"),
	"전력·방어": Color("a8963f"),
	"크리에이티브": Color("7a4fa8"),
}

var factory: Factory = null
var ghost := {}             # {def, pos, rot, ok}
var selected = null         # Building
var show_layers := true
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font


func _process(_dt: float) -> void:
	queue_redraw()


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
	draw_rect(Rect2(Vector2(vis.position) * TILE, Vector2(vis.size) * TILE), Color("1d2026"))
	if zoom > 0.45:
		_draw_grid(vis)
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
	if selected != null and factory.buildings.has(selected):
		draw_rect(cell_rect(selected.pos, selected.size), Color(1, 1, 1, 0.9), false, 3.0)
	_draw_ghost()


func _draw_grid(vis: Rect2i) -> void:
	var col := Color(1, 1, 1, 0.04)
	for x in range(vis.position.x, vis.end.x + 1):
		draw_line(Vector2(x * TILE, vis.position.y * TILE), Vector2(x * TILE, vis.end.y * TILE), col, 1.0)
	for y in range(vis.position.y, vis.end.y + 1):
		draw_line(Vector2(vis.position.x * TILE, y * TILE), Vector2(vis.end.x * TILE, y * TILE), col, 1.0)


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
