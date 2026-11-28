extends Control
## 화면 오른쪽 아래 상호작용 버튼. 누르면 pressed_down, 떼면 released (짧게 = 탭, 길게 = 꾹은 플레이어가 판단).
## 지금 대상의 말풍선 아이콘(손·톱니·상자)을 보여줘요. 터치·마우스 모두 받아요.

signal pressed_down
signal released

const RADIUS := 62.0
const ICON := 48.0      # 8×8 아이콘 6배

var icon_kind := ""     # "", hand, gear, box
var _touch := -2


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_icon(kind: String) -> void:
	if kind != icon_kind:
		icon_kind = kind
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _touch == -2:
			_down(t.index)
		elif not t.pressed and t.index == _touch:
			_up()
		accept_event()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed and _touch == -2:
			_down(-1)
		elif not mb.pressed and _touch == -1:
			_up()
		accept_event()


func _down(index: int) -> void:
	_touch = index
	pressed_down.emit()
	queue_redraw()


func _up() -> void:
	_touch = -2
	released.emit()
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var down := _touch != -2
	draw_circle(c, RADIUS, Color(Palette.c(Palette.INK), 0.55))
	draw_circle(c, RADIUS - 6, Color(Palette.c(Palette.ORANGE if down else Palette.G3), 0.9))
	var kind := icon_kind if icon_kind != "" else "hand"
	var i := SpriteGen.UI_ICONS.find(kind)
	draw_texture_rect_region(Art.tex("ui_icons"), Rect2(c - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), Rect2(i * 8, 0, 8, 8))
