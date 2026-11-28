class_name PlayMode
extends RefCounted
## 플레이 모드: 한 곳에서만 관리해요. 버튼·키(Z/X/C)·표시는 모두 이 객체를 읽고 set_mode()로 바꿔요.
## 이동·철거 동작은 scripts/player/edit_controller.gd가 이 모드를 읽어서 해요.

signal changed(mode: int)

enum Mode { NORMAL, MOVE, DECONSTRUCT }

const NAMES := {Mode.NORMAL: "일반", Mode.MOVE: "이동", Mode.DECONSTRUCT: "철거"}

var mode: int = Mode.NORMAL


func set_mode(m: int) -> void:
	if m != mode:
		mode = m
		changed.emit(mode)


func label() -> String:
	return NAMES[mode]
