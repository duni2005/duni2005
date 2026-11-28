extends HBoxContainer
## 모드 버튼 묶음 [일반][이동][철거]. 늘 하나만 선택되고, 선택된 버튼은 밝게.
## 상태는 PlayMode 하나에만 있고, 이 묶음은 그걸 보여주고 set_mode()만 불러요.

const BTN_W := 96.0
const BTN_H := 64.0
const COLORS := {PlayMode.Mode.NORMAL: Palette.G4, PlayMode.Mode.MOVE: Palette.BLUE, PlayMode.Mode.DECONSTRUCT: Palette.RED}

var play_mode: PlayMode = null
var _buttons := {}


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	for m in [PlayMode.Mode.NORMAL, PlayMode.Mode.MOVE, PlayMode.Mode.DECONSTRUCT]:
		var b := Button.new()
		b.text = PlayMode.NAMES[m]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(BTN_W, BTN_H)
		b.toggle_mode = true
		b.pressed.connect(play_mode.set_mode.bind(m))
		add_child(b)
		_buttons[m] = b
	play_mode.changed.connect(func(_m) -> void: refresh())
	refresh()


func refresh() -> void:
	for m in _buttons:
		var b: Button = _buttons[m]
		var on: bool = m == play_mode.mode
		b.set_pressed_no_signal(on)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.c(COLORS[m]) if on else Color(Palette.c(Palette.G1), 0.85)
		sb.border_color = Palette.c(Palette.INK)
		sb.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("hover_pressed", sb)
		b.add_theme_color_override("font_color", Palette.c(Palette.PAPER) if on else Palette.c(Palette.G4))
		b.add_theme_color_override("font_pressed_color", Palette.c(Palette.PAPER))
		b.add_theme_color_override("font_hover_color", Palette.c(Palette.PAPER))
