class_name CardLoadoutPanel
extends VBoxContainer
## 전투 전 카드 선택: shown under the field before deployment in a battle room. Up to
## StrategyCardTuning.LOADOUT_SIZE owned cards go into the slots; cards on cooldown are dimmed with
## "N승 후" and cannot be chosen. Tapping an owned card or a slot opens its details with 넣기 / 빼기.
## 이전 구성 refills the last confirmed choice (cards gone or on cooldown stay out); 확정 stores the
## choice in the run (card_loadout and last_card_loadout) and hands over to deployment.
signal confirmed
var guild: GuildManager
var chosen: Array[int] = []
var title: Label
var previous_button: Button
var confirm_button: Button
var slots: HBoxContainer
var owned: HBoxContainer
var owned_scroll: ScrollContainer
var detail: StrategyCardDetail
var detail_layer: CanvasLayer
const SLOT := Vector2(56, 80)
const OWNED := Vector2(60, 86)

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation", 6);add_child(row)
	title = Label.new();title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;title.add_theme_font_override("font", ArenaUI.heading_font());title.add_theme_font_size_override("font_size", 15);title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;row.add_child(title)
	previous_button = Button.new();previous_button.text = "이전 구성";previous_button.custom_minimum_size = Vector2(0, 40);previous_button.add_theme_font_size_override("font_size", 12);ArenaUI.quiet(previous_button);ArenaUI.bind(previous_button, fill_previous);row.add_child(previous_button)
	confirm_button = Button.new();confirm_button.text = "확정";confirm_button.custom_minimum_size = Vector2(84, 40);ArenaUI.primary(confirm_button);ArenaUI.with_icon(confirm_button, "play", 12, true);ArenaUI.bind(confirm_button, confirm);row.add_child(confirm_button)
	slots = HBoxContainer.new();slots.alignment = BoxContainer.ALIGNMENT_CENTER;slots.add_theme_constant_override("separation", 6);add_child(slots)
	for i in range(StrategyCardTuning.LOADOUT_SIZE):
		var s := CardThumb.new();s.custom_minimum_size = SLOT;s.slot_index = i;s.pressed.connect(_slot_pressed.bind(i));slots.add_child(s)
	var hint := Label.new();hint.name = "Hint";hint.text = "보유 카드 · 누르면 설명과 넣기";hint.add_theme_font_size_override("font_size", 10);hint.add_theme_color_override("font_color", ArenaUI.MUTED);add_child(hint)
	owned_scroll = ScrollContainer.new();owned_scroll.custom_minimum_size.y = OWNED.y + 4;owned_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;owned_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER;add_child(owned_scroll)
	owned = HBoxContainer.new();owned.add_theme_constant_override("separation", 6);owned_scroll.add_child(owned)
	detail_layer = CanvasLayer.new();detail_layer.layer = 70;add_child(detail_layer)
	detail = StrategyCardDetail.new();detail_layer.add_child(detail);detail.action_pressed.connect(_detail_action)

## Fresh choice for this entry (empty; 이전 구성 refills it).
func open(manager: GuildManager) -> void:
	guild = manager;chosen.clear();render()

## The owned cards a loadout may hold: not consumed, cooldown cards included (shown dimmed).
func _owned() -> Array[StrategyCardInstance]:
	var out: Array[StrategyCardInstance] = []
	for card in guild.state.strategy_cards:
		if not card.consumed and StrategyCardCatalog.get_card(card.kind) != null:out.append(card)
	return out

func render() -> void:
	if guild == null:return
	chosen.assign(chosen.filter(func(id): var c: StrategyCardInstance = guild.state.get_strategy_card(id);return c != null and StrategyCardExecutor.availability(c)))
	if title == null:return
	var limit: int = mini(StrategyCardTuning.LOADOUT_SIZE, _owned().filter(func(c): return StrategyCardExecutor.availability(c)).size())
	title.text = "전략카드 선택  %d / %d" % [chosen.size(), StrategyCardTuning.LOADOUT_SIZE]
	previous_button.disabled = _previous().is_empty() or _previous() == chosen
	for i in range(slots.get_child_count()):
		var s: CardThumb = slots.get_child(i)
		var id: int = chosen[i] if i < chosen.size() else 0
		var card: StrategyCardInstance = guild.state.get_strategy_card(id) if id != 0 else null
		s.card_kind = card.kind if card != null else &"";s.card_id = id;s.state = "ready";s.note = "";s.locked = i >= maxi(limit, chosen.size());s.queue_redraw()
	for child in owned.get_children():owned.remove_child(child);child.queue_free()
	var cards: Array[StrategyCardInstance] = _owned()
	cards.sort_custom(func(a, b): return a.wins_left < b.wins_left if a.wins_left != b.wins_left else a.card_id < b.card_id)
	for card in cards:
		var t := CardThumb.new();t.custom_minimum_size = OWNED;t.card_kind = card.kind;t.card_id = card.card_id
		t.state = "waiting" if card.wins_left > 0 else "chosen" if card.card_id in chosen else "ready"
		t.note = "%d승 후" % card.wins_left if card.wins_left > 0 else "선택됨" if card.card_id in chosen else ""
		t.pressed.connect(_owned_pressed.bind(card.card_id));owned.add_child(t)

## The last confirmed loadout, cards still owned and ready, in its order.
func _previous() -> Array[int]:
	var out: Array[int] = []
	for id in guild.state.last_card_loadout:
		var c: StrategyCardInstance = guild.state.get_strategy_card(id)
		if c != null and StrategyCardExecutor.availability(c) and out.size() < StrategyCardTuning.LOADOUT_SIZE:out.append(id)
	return out
func fill_previous() -> void:
	chosen = _previous();render()

func add(id: int) -> bool:
	var c: StrategyCardInstance = guild.state.get_strategy_card(id)
	if c == null or not StrategyCardExecutor.availability(c) or id in chosen or chosen.size() >= StrategyCardTuning.LOADOUT_SIZE:return false
	chosen.append(id);render();return true
func remove(id: int) -> void:
	chosen.erase(id);render()

func _owned_pressed(id: int) -> void:
	var c: StrategyCardInstance = guild.state.get_strategy_card(id)
	if c == null:return
	if c.wins_left > 0:detail.open(id, c.kind, "%d승 후 사용 가능 (쿨타임)" % c.wins_left);return
	if id in chosen:detail.open(id, c.kind, "가지고 들어갈 카드", "빼기")
	else:detail.open(id, c.kind, "슬롯 %d / %d" % [chosen.size(), StrategyCardTuning.LOADOUT_SIZE], "넣기", chosen.size() < StrategyCardTuning.LOADOUT_SIZE)
func _slot_pressed(i: int) -> void:
	if i >= chosen.size():return
	var c: StrategyCardInstance = guild.state.get_strategy_card(chosen[i])
	if c != null:detail.open(c.card_id, c.kind, "가지고 들어갈 카드", "빼기")
func _detail_action(id: int) -> void:
	if id in chosen:remove(id)
	else:add(id)

## The choice goes into the run; deployment comes next.
func confirm() -> void:
	guild.state.card_loadout.assign(chosen)
	guild.state.last_card_loadout.assign(chosen)
	confirmed.emit()

## A card in a slot or in the owned row (drawn with StrategyCardArt).
class CardThumb extends Control:
	signal pressed
	var card_kind: StringName = &""
	var card_id: int = 0
	var state: String = "ready"
	var note: String = ""
	var locked: bool = false
	var slot_index: int = -1
	var down: Vector2 = Vector2.INF
	func _ready() -> void:mouse_filter = Control.MOUSE_FILTER_PASS
	func _gui_input(event: InputEvent) -> void:
		var press: bool = event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
		if press and event.pressed:down = event.position
		elif press and not event.pressed and down.is_finite():
			if event.position.distance_to(down) < 12:pressed.emit()
			down = Vector2.INF
	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		if card_kind == &"":
			var box: StyleBoxFlat = ArenaUI.box(Color(1, 1, 1, .03), Color(1, 1, 1, .12 if locked else .3));box.set_corner_radius_all(6);box.set_border_width_all(1)
			draw_style_box(box, r)
			draw_string(get_theme_default_font(), Vector2(0, size.y * .5 + 6), "" if locked else "+", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 1, 1, .35))
			return
		var data: StrategyCardData = StrategyCardCatalog.get_card(card_kind)
		StrategyCardArt.draw(self, r, String(card_kind), data.display_name, "", "", "selected" if state == "chosen" else state, note)
		if state == "chosen":draw_string(get_theme_default_font(), Vector2(0, size.y - 4), "선택됨", HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, ArenaUI.GOLD)
