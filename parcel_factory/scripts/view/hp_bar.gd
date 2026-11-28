extends Control
## 핫바 바로 위 HP 바 (지금은 100 고정) + 옆에 스테미나 자리(빈 칸). 플레이어를 읽기만 해요.

const BAR := Vector2(260, 18)
const GAP := 12.0

var player = null
var _shown := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR.x * 2.0 + GAP, BAR.y)


func _process(_dt: float) -> void:
	if player.hp != _shown:
		_shown = player.hp
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var ink := Palette.c(Palette.INK)
	# HP
	var r := Rect2(Vector2.ZERO, BAR)
	draw_rect(r.grow(2), ink)
	draw_rect(r, Palette.c(Palette.RED_D))
	var k := clampf(float(player.hp) / float(player.HP_MAX), 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(BAR.x * k, BAR.y)), Palette.c(Palette.RED))
	draw_rect(Rect2(r.position, Vector2(BAR.x * k, 3)), Palette.c(Palette.PINK))
	draw_string_outline(font, Vector2(6, BAR.y - 3), "HP %d" % player.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, ink)
	draw_string(font, Vector2(6, BAR.y - 3), "HP %d" % player.hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.c(Palette.PAPER))
	# 스테미나 자리 (아직 비어 있어요)
	var s := Rect2(Vector2(BAR.x + GAP, 0), BAR)
	draw_rect(s.grow(2), Color(ink, 0.6))
	draw_dashed_line(s.position, s.position + Vector2(BAR.x, 0), Palette.c(Palette.G2), 2.0, 6.0)
	draw_dashed_line(s.position + Vector2(0, BAR.y), s.end, Palette.c(Palette.G2), 2.0, 6.0)
