class_name ItemRewardRow
extends VBoxContainer
## 전투 보상: the offered items as cards (grade frame, name, effect, grade), 아이템 받기 and 통계. The cards
## flip in one after another; 영웅 and above burst in their grade colour as they turn, 전설 adds a
## short gold flourish. A tap shows the card's full effect; 받기 takes it. `picked` carries the
## item kind.
signal picked(kind: StringName)
signal stats_requested
## Shows the 통계 button under 아이템 받기 (the battle result page has one).
var with_stats: bool = true
var stats_button: Button
const FLIP: float = Motion.ENTER
const GAP: float = .22
var cards: Array[ArenaCard] = []
var take_button: Button
var detail: Label
var cost_line: Label
var looking: StringName = &""
var bursts: Array[Dictionary] = []
var age: float = 0

func setup(kinds: Array, chosen: StringName) -> void:
	add_theme_constant_override("separation", 8)
	var title := Label.new();title.text = "보상 아이템 · 1개 선택" if chosen == &"" else "보상 아이템";title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", ArenaUI.heading_font());title.add_theme_font_size_override("font_size", 15);title.add_theme_color_override("font_color", ArenaUI.GOLD);add_child(title)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation", 6);row.alignment = BoxContainer.ALIGNMENT_CENTER;add_child(row)
	for i in range(kinds.size()):
		var kind: StringName = kinds[i];var data: ItemData = ItemCatalog.get_item(kind)
		var card := ArenaCard.new();card.name = "reward_%d" % i;card.card_type = "product";card.slot_kind = "item";card.kind = String(kind);card.title = data.display_name
		card.description = ItemCatalog.body_text(data);card.text = data.display_name;card.tag_text = "소모품" if data.consumable else ItemCatalog.grade_name(kind) + " 아이템";card.item_grade = data.grade if not data.consumable else &""
		card.rarity = ItemCatalog.grade_color(kind) if not data.consumable else Color(0, 0, 0, 0);card.tooltip_text = data.description
		card.custom_minimum_size = Vector2(0, 168);card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true;card.selected = chosen == kind;card.set_pressed_no_signal(card.selected)
		# After the pick the cards stay readable: the others just fade and stop taking taps.
		if chosen != &"":card.mouse_filter = Control.MOUSE_FILTER_IGNORE;card.modulate.a = 1.0 if chosen == kind else .45
		ArenaUI.bind(card, _look.bind(kind));row.add_child(card);cards.append(card)
	# The tapped card's whole effect (cards cut long text short).
	detail = Label.new();detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", ArenaUI.MUTED);detail.text = "카드를 눌러 효과를 보고 아이템 받기를 누르세요." if chosen == &"" else "";detail.visible = chosen == &"";add_child(detail)
	cost_line = ArenaUI.cost_label(self, &"", 12, true)
	# 아이템 받기 (armed by tapping a card), and 통계 under it. No skip: one item is always taken.
	take_button = Button.new();take_button.name = "Take";take_button.text = "아이템 받기";take_button.custom_minimum_size = Vector2(0, 48);take_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;ArenaUI.primary(take_button)
	take_button.disabled = true;take_button.visible = chosen == &"";ArenaUI.bind(take_button, func():if looking != &"":_pick(looking));add_child(take_button)
	stats_button = Button.new();stats_button.name = "Stats";stats_button.text = "통계";stats_button.custom_minimum_size = Vector2(0, 42);stats_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;ArenaUI.quiet(stats_button)
	stats_button.visible = with_stats;ArenaUI.bind(stats_button, func():stats_requested.emit());add_child(stats_button)
	if chosen == &"" and UiMotion.enabled:_flip_in()

## Cards turn over one after another (edge-on to face up); a high grade bursts as it lands.
func _flip_in() -> void:
	for i in range(cards.size()):
		var card: ArenaCard = cards[i];card.modulate.a = 0
		card.resized.connect(func():card.pivot_offset = card.size * .5)
		var t := create_tween();t.tween_interval(i * GAP)
		t.tween_callback(func():card.pivot_offset = card.size * .5;card.scale = Vector2(0, 1);card.modulate.a = 1)
		Motion.enter_curve(t.tween_property(card, "scale", Vector2.ONE, FLIP))
		var grade: StringName = card.item_grade
		if ItemTuning.GRADES.find(grade) >= ItemTuning.GRADES.find(&"epic"):
			t.tween_callback(_burst.bind(card, grade))
	set_process(true)
## The burst is drawn by a layer inside the card, above it and its neighbours, without taking taps.
func _burst(card: ArenaCard, grade: StringName) -> void:
	var fx := Control.new();fx.mouse_filter = Control.MOUSE_FILTER_IGNORE;fx.z_index = 5;card.add_child(fx)
	var b: Dictionary = {"fx":fx, "color":ItemTuning.GRADE_COLORS[grade], "age":0.0, "gold":grade == &"legendary", "size":card.size}
	fx.draw.connect(_draw_burst.bind(b));bursts.append(b)
	set_process(true)
func _process(dt: float) -> void:
	age += dt
	for b in bursts:
		b.age = float(b.age) + dt
		if float(b.age) >= (1.1 if b.gold else .7):b.fx.queue_free()
		else:b.fx.queue_redraw()
	bursts = bursts.filter(func(b):return float(b.age) < (1.1 if b.gold else .7))
	if bursts.is_empty() and age > cards.size() * GAP + FLIP + .1:set_process(false)
func _draw_burst(b: Dictionary) -> void:
	var overlay: Control = b.fx
	if true:
		var t: float = float(b.age) / (1.1 if b.gold else .7);var at: Vector2 = b.size * .5;var col: Color = b.color;var fade: float = 1 - t
		VfxArt.glow(overlay, at, 70 + 50 * t, col, .55 * fade)
		overlay.draw_arc(at, 30 + 90 * Motion.out_expo(t), 0, TAU, 48, Color(col, .8 * fade), 3, true)
		for k in range(10):
			var dir := Vector2.from_angle(k * TAU / 10 + .3);overlay.draw_line(at + dir * (24 + 40 * t), at + dir * (40 + 80 * t), Color(col.lightened(.3), .7 * fade), 2, true)
		if b.gold:
			# 전설: a gold glint sweeps across the card and sparks rise.
			var size: Vector2 = b.size;var x: float = lerpf(-size.x * .6, size.x * .6, Motion.out_quint(minf(1, t * 1.6)))
			overlay.draw_line(at + Vector2(x - 12, -size.y * .45), at + Vector2(x + 12, size.y * .45), Color(1, .95, .7, .7 * fade), 6, true)
			for k in range(8):
				var s: float = fposmod(k * .37 + t, 1.0);overlay.draw_circle(at + Vector2((k - 3.5) * size.x / 8, size.y * (.4 - s)), 2.5 * fade + 1, Color(1, .9, .5, fade))

## First tap: show the whole effect and arm 받기.
func _look(kind: StringName) -> void:
	looking = kind
	for card in cards:card.selected = card.kind == String(kind);card.set_pressed_no_signal(card.selected);card.queue_redraw()
	var data: ItemData = ItemCatalog.get_item(kind)
	detail.text = "[%s] %s\n%s" % [ItemCatalog.grade_name(kind), data.display_name, ItemCatalog.body_text(data)];cost_line.text = ItemCatalog.cost_text(kind);cost_line.visible = cost_line.text != "";detail.add_theme_color_override("font_color", ItemCatalog.grade_color(kind).lightened(.35))
	take_button.disabled = false;take_button.text = "아이템 받기 · " + data.display_name
func _pick(kind: StringName) -> void:
	picked.emit(kind)
