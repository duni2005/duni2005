extends Control
## 떠 있는 조이스틱. 이 Control이 '조이스틱 영역'(부모가 화면 왼쪽 AREA_W × 아래 AREA_H로 잡아 줘요)이고,
## 영역 안을 누르면 그 자리에 조이스틱이 생겨요. vector(-1~1)를 main이 읽어 플레이어 이동에 써요.
## 데드존 DEADZONE, 끝까지(RUN_THRESHOLD) 밀면 달리기. 터치·마우스 모두 받아요.
## 입력 곡선: 데드존 밖 기울기를 0~1로 펴고 제곱해요 (조금 밀면 아주 천천히 → 미세 이동이 쉬워요).

const AREA_W := 0.35          # 화면 왼쪽 35%
const AREA_H := 0.60          # 화면 아래 60%
const RADIUS := 90.0          # 바깥 원 반지름
const KNOB := 38.0            # 손잡이 반지름
const DEADZONE := 0.15
const RUN_THRESHOLD := 0.95

var vector := Vector2.ZERO     # 곡선을 지난 이동 입력
var _raw := 0.0               # 곡선 전 기울기 (달리기 판정)
var _touch := -2              # 잡고 있는 손가락 번호 (-2 = 없음, -1 = 마우스)
var _center := Vector2.ZERO   # 누른 자리 (이 Control 안 좌표)
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_running() -> bool:
	return _raw >= RUN_THRESHOLD


func is_active() -> bool:
	return _touch != -2


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _touch == -2:
			_start(t.index, t.position)
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
			_start(-1, mb.position)
		elif not mb.pressed and _touch == -1:
			_release()
		accept_event()
	elif e is InputEventMouseMotion and _touch == -1:
		_update((e as InputEventMouseMotion).position)
		accept_event()


func _start(index: int, p: Vector2) -> void:
	_touch = index
	# 화면 가장자리에 너무 붙어 누르면 원이 잘리지 않게 살짝 안쪽으로
	_center = p.clamp(Vector2(RADIUS, RADIUS), size - Vector2(RADIUS, RADIUS))
	_update(p)


func _update(p: Vector2) -> void:
	var v := ((p - _center) / RADIUS).limit_length(1.0)
	_knob = v
	_raw = v.length()
	if _raw < DEADZONE:
		vector = Vector2.ZERO
	else:
		var k := (_raw - DEADZONE) / (1.0 - DEADZONE)
		vector = v / _raw * k * k
	queue_redraw()


func _release() -> void:
	_touch = -2
	vector = Vector2.ZERO
	_raw = 0.0
	_knob = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_release()


func _draw() -> void:
	if _touch == -2:
		return
	draw_circle(_center, RADIUS, Color(Palette.c(Palette.INK), 0.45))
	draw_arc(_center, RADIUS, 0, TAU, 48, Color(Palette.c(Palette.G4), 0.8), 3.0)
	draw_arc(_center, RADIUS * DEADZONE, 0, TAU, 24, Color(Palette.c(Palette.G4), 0.4), 2.0)
	var knob_col := Palette.c(Palette.ORANGE) if is_running() else Palette.c(Palette.G4)
	draw_circle(_center + _knob * (RADIUS - KNOB * 0.5), KNOB, Color(knob_col, 0.9))
