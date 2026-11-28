extends Control
## 오른쪽 아래 큰 원 상호작용 버튼. 누르면 pressed_down, 떼면 released
## (짧게 = 탭, 길게 = 꾹은 플레이어가 판단). 아이콘은 HUD가 모드·손에 든 것에 맞춰 바꿔요:
##   일반 모드 — 맨손 fist(주먹) · 아이템 hand(손) · 설비 hammer(설치) / 이동 모드 move / 철거 모드 crowbar
## 작은 버튼(회전 등)도 같은 스크립트로 만들어요 (radius만 다르게). 터치·마우스 모두 받아요.

signal pressed_down
signal released
signal dragged(offset: Vector2)   # 누른 채 끈 거리 (설치 미리보기 조준)

const ICON_SCALE := 0.75      # 원 지름 대비 아이콘 크기
const CANCEL_RADIUS := 0.45   # 버튼 반지름 대비: 이 안으로 되돌아와 떼면 취소
const CANCEL_ARM := 1.2       # 한 번이라도 이만큼(반지름 배) 끌어야 취소 표시가 켜져요
const HOLD_SEC := 0.35        # 누르는 동안 테두리 게이지가 이 시간에 다 차요 ('꾹'이 되는 때)

var radius := 72.0
var icon_kind := "fist"
var tint := -1                # 팔레트 번호 (-1 = 기본 회색)
var _touch := -2
var drag_offset := Vector2.ZERO
var cancel_mode := false      # 설치 끌기 중: 가운데에 취소 X
var _armed := false           # 충분히 끌었다가
var _press_at := Vector2.ZERO
var _down_t := 0.0


func in_cancel_zone() -> bool:
	## 취소 표시가 켜진 뒤 버튼 가운데로 되돌아왔는지
	return cancel_mode and _armed and drag_offset.length() < radius * CANCEL_RADIUS


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
			_press_at = t.position
			_down(t.index)
		elif not t.pressed and t.index == _touch:
			_up()
		accept_event()
	elif e is InputEventScreenDrag and (e as InputEventScreenDrag).index == _touch:
		_drag((e as InputEventScreenDrag).position)
		accept_event()
	elif e is InputEventMouseMotion and _touch == -1:
		_drag((e as InputEventMouseMotion).position)
		accept_event()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed and _touch == -2:
			_press_at = mb.position
			_down(-1)
		elif not mb.pressed and _touch == -1:
			_up()
		accept_event()


func _process(dt: float) -> void:
	if _touch != -2 and _down_t < HOLD_SEC:
		_down_t += dt
		queue_redraw()


func _drag(p: Vector2) -> void:
	drag_offset = p - _press_at
	if drag_offset.length() > radius * CANCEL_ARM:
		_armed = true
	dragged.emit(drag_offset)
	queue_redraw()


func _down(index: int) -> void:
	_touch = index
	drag_offset = Vector2.ZERO
	_armed = false
	_down_t = 0.0
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
	if _touch != -2:
		# 꾹 게이지: 테두리가 0.35초 동안 차요
		draw_arc(c, r - 2.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(_down_t / HOLD_SEC, 0.0, 1.0), 48, Palette.c(Palette.PAPER), 4.0)
	if cancel_mode and _armed and _touch != -2:
		# 설치 끌기 중: 가운데 취소 X (되돌아오면 밝게)
		var hot := in_cancel_zone()
		var cr := r * CANCEL_RADIUS
		draw_circle(c, cr, Color(Palette.c(Palette.RED_D if not hot else Palette.RED), 0.95))
		var k := cr * 0.5
		draw_line(c - Vector2(k, k), c + Vector2(k, k), Palette.c(Palette.PAPER), 5.0)
		draw_line(c + Vector2(-k, k), c + Vector2(k, -k), Palette.c(Palette.PAPER), 5.0)
		return
	var i := SpriteGen.UI_ICONS.find(icon_kind)
	if i < 0:
		return
	var s := r * 2.0 * ICON_SCALE * 0.75
	draw_texture_rect_region(Art.tex("ui_icons"), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), Rect2(i * 8, 0, 8, 8))
