class_name CardDetail
extends Control
## The detail of a strategy card or an item: the card alone, enlarged over a dim backdrop, with
## one action button under it only when there is something to do (넣기 / 빼기, 장착, 구매).
## No text besides the card; tapping anywhere off the card and the button closes it. The whole
## tap (press and release, touch and its emulated mouse events) is swallowed and the overlay
## stays up a moment after the release, so nothing under it is pressed by the closing tap.
signal action_pressed(id: int)
var id: int = 0
## Strategy card: its kind. Item: item_kind / item_data / item_color.
var kind: StringName = &""
var item_kind: StringName = &""
var item_data: ItemData
var item_color: Color = Color(0, 0, 0, 0)
## A strategy card's look: "ready", or "waiting" with the wins still to go on its cooldown.
var state: String = "ready"
var wins: int = 0
var action: Button
var t: float = 0
## Closing: a press outside the card started it; hidden CLOSE_DELAY s after the release.
var closing: bool = false
var close_in: float = -1
const CLOSE_DELAY := .12

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 80;theme = ArenaUI.get_theme()
	action = Button.new();action.name = "Action";action.custom_minimum_size = Vector2(0, 48);ArenaUI.bind(action, func(): action.disabled = true;action_pressed.emit(id);closing = true;close_in = CLOSE_DELAY);add_child(action)
	resized.connect(_layout);hide()

## A strategy card. action_text: "" for no button; wins_left > 0: shown waiting on its cooldown.
## price > 0: the button is a price button.
func open(card_id: int, card_kind: StringName, action_text: String = "", enabled: bool = true, wins_left: int = 0, price: int = 0) -> void:
	id = card_id;kind = card_kind;item_data = null;item_kind = &"";wins = wins_left;state = "waiting" if wins_left > 0 else "ready"
	_show(action_text, enabled, price)
## An item card. price > 0: the button is a price button (구매 · price).
func open_item(item_id: int, kind_name: StringName, data: ItemData, color: Color = Color(0, 0, 0, 0), action_text: String = "", enabled: bool = true, price: int = 0) -> void:
	id = item_id;kind = &"";item_kind = kind_name;item_data = data;item_color = color
	_show(action_text, enabled, price)

func _show(action_text: String, enabled: bool, price: int) -> void:
	t = 0;closing = false;close_in = -1;mouse_filter = Control.MOUSE_FILTER_STOP
	var old: Node = action.get_node_or_null("PriceRow")
	if old != null:action.remove_child(old);old.queue_free()
	action.text = action_text;action.icon = null
	if price > 0:ArenaUI.price_button(action, action_text, "gold", price)
	else:ArenaUI.primary(action)
	action.visible = not action_text.is_empty();action.disabled = not enabled
	show();_layout();queue_redraw()

func _card_rect() -> Rect2:
	var view: Vector2 = size;var room: float = view.y - (90.0 if action.visible else 40.0)
	var w: float = minf(minf(260, view.x - 64), room / 1.42);var h: float = w * 1.42
	return Rect2(Vector2((view.x - w) * .5, (view.y - h - (60.0 if action.visible else 0.0)) * .5), Vector2(w, h))

func _layout() -> void:
	var r: Rect2 = _card_rect()
	action.position = Vector2(r.position.x, r.end.y + 14);action.size = Vector2(r.size.x, 48)

func _process(dt: float) -> void:
	if visible and t < 1:t = minf(1, t + dt / Motion.REACT if GameSettings.motion else 1.0);queue_redraw()
	if close_in >= 0:
		close_in -= dt
		if close_in < 0:closing = false;hide()

func _gui_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if not tap:
		if closing:accept_event()
		return
	# The action button's own taps (they pass up to here) never close the card.
	if action.visible and action.get_rect().has_point(event.position) and not closing:return
	if event.pressed and not _card_rect().has_point(event.position):closing = true
	elif not event.pressed and closing and close_in < 0:close_in = CLOSE_DELAY
	if closing:accept_event()

func _draw() -> void:
	var e: float = Motion.out_quint(t)
	draw_rect(Rect2(Vector2.ZERO, size), Color(.01, .02, .05, .8 * e))
	var r: Rect2 = _card_rect();var grow: float = (1 - e) * .15
	r = r.grow_individual(-r.size.x * grow, -r.size.y * grow, -r.size.x * grow, -r.size.y * grow)
	if item_data != null:ItemCardArt.draw(self, r, item_kind, item_data, item_color)
	elif StrategyCardCatalog.get_card(kind) != null:StrategyCardArt.draw(self, r, String(kind), state, "%d승 후" % wins if wins > 0 else "", wins, 1)
