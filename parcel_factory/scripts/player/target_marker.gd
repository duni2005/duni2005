extends Node2D
## 플레이어 상호작용 대상 표시: 흰 모서리 테두리 + 작은 말풍선 아이콘(손·톱니·상자),
## 그리고 머리 위 진행 게이지(더미 뒤지기·철거). 플레이어·시뮬레이션 상태는 읽기만 해요.

const TILE := 32.0
const CORNER := 8.0          # 모서리 꺾쇠 길이
const LINE := 3.0
const BUBBLE := Vector2(24, 22)
const ICON := 16.0           # 8×8 아이콘 2배
const GAUGE := Vector2(36, 6)
const GAUGE_Y := -58.0       # 플레이어 발끝 기준
const BIG_AREA := 9          # 이보다 큰 설비(쓰레기 더미 등)는 플레이어에게 가장 가까운 칸만 표시

var player = null


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t = player.shown_target()
	if t != null:
		var r := Rect2(Vector2(t.pos) * TILE, Vector2(t.size) * TILE).grow(2)
		if t.size.x * t.size.y > BIG_AREA:
			r = Rect2(Vector2(player.closest_cell(t)) * TILE, Vector2(TILE, TILE)).grow(2)
		_corners(r, Palette.c(Palette.PAPER))
		var kind: String = player.bubble_kind(t)
		if kind != "":
			_bubble(Vector2(r.get_center().x, r.position.y - 6), kind)
	var p: float = player.progress()
	if p >= 0.0:
		var base: Vector2 = player.position + Vector2(-GAUGE.x * 0.5, GAUGE_Y)
		draw_rect(Rect2(base - Vector2(1, 1), GAUGE + Vector2(2, 2)), Palette.c(Palette.INK))
		var col := Palette.c(Palette.YELLOW) if player.action == "rummage" else Palette.c(Palette.RED)
		draw_rect(Rect2(base, Vector2(GAUGE.x * clampf(p, 0.0, 1.0), GAUGE.y)), col)


func _corners(r: Rect2, col: Color) -> void:
	var ink := Palette.c(Palette.INK)
	for pass_i in 2:
		var c := ink if pass_i == 0 else col
		var w := LINE + 2.0 if pass_i == 0 else LINE
		for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
			var p: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_line(p, p + Vector2(d.x * CORNER, 0), c, w)
			draw_line(p, p + Vector2(0, d.y * CORNER), c, w)


func _bubble(bottom_center: Vector2, kind: String) -> void:
	var box := Rect2(bottom_center - Vector2(BUBBLE.x * 0.5, BUBBLE.y + 5), BUBBLE)
	var ink := Palette.c(Palette.INK)
	var paper := Palette.c(Palette.PAPER)
	draw_rect(box.grow(2), ink)
	draw_rect(box, paper)
	var tail := PackedVector2Array([bottom_center + Vector2(-4, -6), bottom_center + Vector2(4, -6), bottom_center])
	draw_colored_polygon(tail, ink)
	draw_colored_polygon(PackedVector2Array([bottom_center + Vector2(-2, -7), bottom_center + Vector2(2, -7), bottom_center + Vector2(0, -3)]), paper)
	var i := SpriteGen.UI_ICONS.find(kind)
	var src := Rect2(i * 8, 0, 8, 8)
	draw_texture_rect_region(Art.tex("ui_icons"), Rect2(box.get_center() - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), src)
