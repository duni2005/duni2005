extends Node2D
## 이동·철거·범위 선택 표시: 끄는 사각형, 선택된 설비 노란 테두리, 들린 설비의 원래 자리 점선,
## 철거 원형 게이지(+ 'N개 철거'), 안내 말풍선. edit_controller·시뮬레이션 상태는 읽기만 해요.

const TILE := 32.0
const GAUGE_W := 5.0
const DASH := 6.0

var edit = null   # scripts/player/edit_controller.gd


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f: Factory = edit.factory
	var yellow := Palette.c(Palette.YELLOW)
	var ink := Palette.c(Palette.INK)
	var font := ThemeDB.fallback_font
	# 선택된 설비: 노란 테두리 (전선·파이프 칸은 작은 노란 네모)
	for e in edit.sel:
		if e is Building:
			var r := Rect2(Vector2(e.pos) * TILE, Vector2(e.size) * TILE).grow(1)
			draw_rect(r, ink, false, 4.0)
			draw_rect(r, yellow, false, 2.0)
		else:
			var c: Vector2 = (Vector2(e["pos"]) + Vector2(0.5, 0.5)) * TILE
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), yellow, false, 2.0)
	# 끄는 중인 범위
	if edit.state == "select":
		var a: Vector2i = edit.sel_from
		var b: Vector2i = edit.sel_to
		var r := Rect2(Vector2(mini(a.x, b.x), mini(a.y, b.y)) * TILE, (Vector2((a - b).abs()) + Vector2.ONE) * TILE)
		draw_rect(r, Color(yellow, 0.15))
		draw_rect(r, yellow, false, 2.0)
		var s := Rect2(Vector2(a) * TILE + Vector2(8, 8), Vector2(16, 16))
		draw_rect(s, ink)
		draw_rect(s.grow(-3), yellow)
	# 들린 설비의 원래 자리: 점선
	for b in f.held:
		var r := Rect2(Vector2(b.pos) * TILE, Vector2(b.size) * TILE)
		_dashed(r, Palette.c(Palette.PAPER))
	# 철거 게이지
	if edit.state == "gauge" and edit.gauge_b != null:
		var gb = edit.gauge_b
		var c: Vector2 = (Vector2(gb.pos) + Vector2(gb.size) * 0.5) * TILE
		var rad: float = maxf(gb.size.x, gb.size.y) * TILE * 0.5 + 8.0
		var k: float = clampf(edit.gauge_t / edit.gauge_need(), 0.0, 1.0)
		draw_arc(c, rad, 0.0, TAU, 40, Color(ink, 0.7), GAUGE_W + 3.0)
		draw_arc(c, rad, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Palette.c(Palette.RED), GAUGE_W)
		if edit.gauge_list.size() > 1:
			_plate(c - Vector2(0, rad + 16), "%d개 철거" % edit.gauge_list.size(), Palette.c(Palette.PINK), font, true)
	# 안내 말풍선
	if not edit.hint.is_empty():
		var r: Rect2 = edit.hint["rect"]
		_plate(Vector2(r.get_center().x, r.position.y - 14), edit.hint["text"], Palette.c(Palette.PAPER), font, true)


func _dashed(r: Rect2, col: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(pts[i], pts[(i + 1) % 4], col, 2.0, DASH)


func _plate(at: Vector2, text: String, col: Color, font: Font, centered := false) -> void:
	var fs := 14
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var pos := at - Vector2(w * 0.5 if centered else 0.0, 10)
	var r := Rect2(pos, Vector2(w, 20))
	draw_rect(r.grow(1), Palette.c(Palette.INK))
	draw_rect(r, Color(Palette.c(Palette.INK), 0.9))
	draw_string(font, r.position + Vector2(7, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if centered:
		var tip := Vector2(at.x, r.end.y)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-5, 0), tip + Vector2(5, 0), tip + Vector2(0, 6)]), Palette.c(Palette.INK))
