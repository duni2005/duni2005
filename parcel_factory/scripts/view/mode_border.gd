extends Control
## 모드 표시: 이동 모드 = 화면 가장자리 얇은 파란 테두리, 철거 모드 = 붉은 테두리.
## 입력은 받지 않아요 (마우스 무시). PlayMode를 읽기만 해요.

const WIDTH := 6.0

var play_mode: PlayMode = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_mode.changed.connect(func(_m) -> void: queue_redraw())


func color_of(m: int) -> Color:
	match m:
		PlayMode.Mode.MOVE:
			return Palette.c(Palette.BLUE)
		PlayMode.Mode.DECONSTRUCT:
			return Palette.c(Palette.RED)
	return Color(0, 0, 0, 0)


func _draw() -> void:
	if play_mode.mode == PlayMode.Mode.NORMAL:
		return
	draw_rect(Rect2(Vector2.ZERO, size).grow(-WIDTH * 0.5), Color(color_of(play_mode.mode), 0.85), false, WIDTH)
