class_name StrategyCardDetail
extends Control
## Full-screen detail of a strategy card: the card large (kind, condition, use, effect), a line
## of status (e.g. "2승 후 사용 가능"), an optional action button (넣기 / 빼기) and 닫기. Tapping
## the dim backdrop closes it.
signal action_pressed(card_id: int)
var card_id: int = 0
var kind: StringName
var note: String = ""
var action: Button
var close: Button
var info: Label
var t: float = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 80;theme = ArenaUI.get_theme()
	info = Label.new();info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;info.add_theme_font_size_override("font_size", 12);info.add_theme_color_override("font_color", Color("c9d2ea"));add_child(info)
	action = Button.new();action.custom_minimum_size = Vector2(0, 46);ArenaUI.primary(action);ArenaUI.bind(action, func(): action_pressed.emit(card_id);hide());add_child(action)
	close = Button.new();close.text = "닫기";close.custom_minimum_size = Vector2(0, 46);ArenaUI.quiet(close);ArenaUI.bind(close, hide);add_child(close)
	resized.connect(_layout);hide()

## Opens the card. action_text: "" for no action button.
func open(id: int, card_kind: StringName, status: String = "", action_text: String = "", action_enabled: bool = true) -> void:
	card_id = id;kind = card_kind;note = status;t = 0
	var data: StrategyCardData = StrategyCardCatalog.get_card(kind)
	info.text = "%s\n%s" % [data.rule_line(), status] if not status.is_empty() else data.rule_line()
	action.visible = not action_text.is_empty();action.text = action_text;action.disabled = not action_enabled
	show();_layout();queue_redraw()

func _card_rect() -> Rect2:
	var view: Vector2 = size;var w: float = minf(240, view.x - 80);var h: float = minf(w * 1.42, view.y - 230)
	w = h / 1.42
	return Rect2(Vector2((view.x - w) * .5, maxf(30, (view.y - h - 150) * .5)), Vector2(w, h))

func _layout() -> void:
	var r: Rect2 = _card_rect();var w: float = minf(300, size.x - 40)
	info.position = Vector2((size.x - w) * .5, r.end.y + 10);info.size = Vector2(w, 0)
	var y: float = r.end.y + 58
	var bw: float = (w - 10) * .5 if action.visible else w
	action.position = Vector2((size.x - w) * .5, y);action.size = Vector2(bw, 46)
	close.position = Vector2((size.x - w) * .5 + (bw + 10 if action.visible else 0), y);close.size = Vector2(bw, 46)

func _process(dt: float) -> void:
	if visible and t < 1:t = minf(1, t + dt / Motion.REACT if GameSettings.motion else 1.0);queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var press: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if press and not _card_rect().has_point(event.position):hide();accept_event()

func _draw() -> void:
	var e: float = Motion.out_quint(t)
	draw_rect(Rect2(Vector2.ZERO, size), Color(.01, .02, .05, .78 * e))
	var data: StrategyCardData = StrategyCardCatalog.get_card(kind)
	if data == null:return
	var r: Rect2 = _card_rect();var grow: float = (1 - e) * .15
	r = r.grow_individual(-r.size.x * grow, -r.size.y * grow, -r.size.x * grow, -r.size.y * grow)
	StrategyCardArt.draw(self, r, String(kind), data.display_name, "", "", "ready")
