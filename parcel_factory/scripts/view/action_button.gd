extends Control
## 오른쪽 아래 큰 원 상호작용 버튼. 누르면 pressed_down, 떼면 released
## (짧게 = 탭, 길게 = 꾹은 플레이어가 판단). 아이콘은 HUD가 모드·손에 든 것에 맞춰 바꿔요:
##   일반 모드 — 맨손 fist(주먹) · 아이템 hand(손) · 설비 hammer(설치) / 이동 모드 move / 철거 모드 crowbar
## 작은 버튼(회전 등)도 같은 스크립트로 만들어요 (radius만 다르게). 터치·마우스 모두 받아요.

signal pressed_down
signal released

const ICON_SCALE := 0.75      # 원 지름 대비 아이콘 크기

var radius := 72.0
var icon_kind := "fist"
var tint := -1                # 팔레트 번호 (-1 = 기본 회색)
var _touch := -2


func _ready() -> void:
	custom_minimum_size = Vector2(radius, radius) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_icon(kind: String, p_tint: int = -1) -> void:
	if kind != icon_kind or p_tint != tint:
		icon_kind = kind
		tint = p_tint
		queue_redraw()


func is_down() -> bool:
	return _touch != -2


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and _touch != -2:
		_up()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var fill := Palette.c(Palette.G3) if tint < 0 else Palette.c(tint)
	if _touch != -2:
		fill = fill.lightened(0.25)
	draw_circle(c, r, Color(Palette.c(Palette.INK), 0.6))
	draw_circle(c, r - 5.0, Color(fill, 0.92))
	var i := SpriteGen.UI_ICONS.find(icon_kind)
	if i < 0:
		return
	var s := r * 2.0 * ICON_SCALE * 0.75
	draw_texture_rect_region(Art.tex("ui_icons"), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), Rect2(i * 8, 0, 8, 8))
