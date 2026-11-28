extends Node2D
## 전선·파이프·물 샘. bold = false: 바닥 위 얇은 선(설비 밑으로 숨어요),
## bold = true: '층 보기'를 켰을 때만 설비 위에 진하게. 시뮬레이션 상태는 읽기만 해요.

const TILE := 32.0
const THIN_WIDTH := 2.0     # 1도트
const BOLD_WIDTH := 6.0     # 3도트
const THIN_ALPHA := 0.75

var world = null
var bold := false
var _rev := -1


func _process(_dt: float) -> void:
	var f: Factory = world.factory
	if bold:
		visible = world.show_layers
	# 전선·파이프는 설치·철거 때만 바뀌어요 (그린 내용은 화면을 움직여도 그대로 남아요)
	if f.revision != _rev:
		_rev = f.revision
		queue_redraw()


func _draw() -> void:
	var f: Factory = world.factory
	if not bold:
		var tiles := Art.tex("tiles")
		var src := Rect2(Art.tile_index("water") * Art.DOT, 0, Art.DOT, Art.DOT)
		for c in f.water:
			draw_texture_rect_region(tiles, world.cell_rect(c), src)
	var w := BOLD_WIDTH if bold else THIN_WIDTH
	var a := 1.0 if bold else THIN_ALPHA
	_draw_net(f.pipes, Color(Palette.c(Palette.CYAN), a), w)
	_draw_net(f.wires, Color(Palette.c(Palette.YELLOW), a), w)


func _draw_net(layer: Dictionary, col: Color, w: float) -> void:
	var ink := Palette.c(Palette.INK)
	for pass_i in (2 if bold else 1):
		var cw := w + 2.0 if (bold and pass_i == 0) else w
		var cc := ink if (bold and pass_i == 0) else col
		for c in layer:
			var p: Vector2 = world.cell_center(c)
			draw_rect(Rect2(p - Vector2(cw, cw) * 0.5, Vector2(cw, cw)), cc)
			if layer.has(c + Vector2i(1, 0)):
				draw_line(p, world.cell_center(c + Vector2i(1, 0)), cc, cw)
			if layer.has(c + Vector2i(0, 1)):
				draw_line(p, world.cell_center(c + Vector2i(0, 1)), cc, cw)
