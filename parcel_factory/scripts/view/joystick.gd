extends Control
## 화면 왼쪽 아래 가상 조이스틱. vector(-1~1)를 main이 읽어 플레이어 이동에 써요.
## 끝까지 밀면(RUN_THRESHOLD 이상) 달리기. 터치·마우스 모두 받아요.

const RADIUS := 80.0          # 바깥 원 반지름
const KNOB := 34.0            # 손잡이 반지름
const DEADZONE := 0.15
const RUN_THRESHOLD := 0.95

var vector := Vector2.ZERO
var _touch := -2              # 잡고 있는 손가락 번호 (-2 = 없음, -1 = 마우스)


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_running() -> bool:
	return vector.length() >= RUN_THRESHOLD


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _touch == -2:
			_touch = t.index
			_update(t.position)
		elif not t.pressed and t.index == _touch:
			_release()
		accept_event()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _touch:
			_update(d.position)
		accept_event()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed and _touch == -2:
			_touch = -1
			_update(mb.position)
		elif not mb.pressed and _touch == -1:
			_release()
		accept_event()
	elif e is InputEventMouseMotion and _touch == -1:
		_update((e as InputEventMouseMotion).position)
		accept_event()


func _update(local: Vector2) -> void:
	var v := (local - size * 0.5) / RADIUS
	v = v.limit_length(1.0)
	vector = Vector2.ZERO if v.length() < DEADZONE else v
	queue_redraw()


func _release() -> void:
	_touch = -2
	vector = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_release()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(Palette.c(Palette.INK), 0.45))
	draw_arc(c, RADIUS, 0, TAU, 48, Color(Palette.c(Palette.G4), 0.8), 3.0)
	var knob_col := Palette.c(Palette.ORANGE) if is_running() else Palette.c(Palette.G4)
	draw_circle(c + vector * (RADIUS - KNOB * 0.5), KNOB, Color(knob_col, 0.9))
