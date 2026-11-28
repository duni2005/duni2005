extends RefCounted
## 누름 효과: 누르는 동안 크기 95% + 조금 밝게, 누르는 순간 버튼 소리(assets/sfx/button, 없으면 무음).
## hud가 모든 버튼·인벤토리 칸·둥근 버튼에 붙여요. 게임 상태는 바꾸지 않아요.

const SCALE := 0.95
const BRIGHT := Color(1.15, 1.15, 1.15)


static func wants(n: Node) -> bool:
	## 붙일 대상: 버튼, 인벤토리 칸(inv_slot), 둥근 버튼(action_button)
	return n is BaseButton or (n is Control and (n.has_signal("long_pressed") or n.has_signal("pressed_down")))


static func attach(c: Control, sfx) -> void:
	if c.has_meta("press_fx"):
		return
	c.set_meta("press_fx", true)
	c.gui_input.connect(func(e: InputEvent) -> void: _on_input(c, e, sfx))
	c.mouse_exited.connect(func() -> void: _apply(c, false))
	if c is BaseButton:
		(c as BaseButton).button_up.connect(func() -> void: _apply(c, false))


static func _on_input(c: Control, e: InputEvent, sfx) -> void:
	if c is BaseButton and (c as BaseButton).disabled:
		return
	var down := -1
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = 1 if (e as InputEventMouseButton).pressed else 0
	elif e is InputEventScreenTouch:
		down = 1 if (e as InputEventScreenTouch).pressed else 0
	if down == 1 and c.scale.x == 1.0:
		_apply(c, true)
		sfx.play("button")
	elif down == 0:
		_apply(c, false)


static func _apply(c: Control, on: bool) -> void:
	if not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * (SCALE if on else 1.0)
	c.modulate = BRIGHT if on else Color.WHITE
