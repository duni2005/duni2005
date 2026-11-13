class_name ItemGainShow
extends Control
## 아이템 획득: the item taken from a battle reward. The screen dims, the item's card turns over in
## the middle with light in its grade colour (a gold flourish for 전설, rising sparks), its name and
## grade come in under it, then it closes by itself. A tap anywhere closes it at once.
signal finished
const LIFE: float = 2.4
var kind: StringName
var age: float = 0
var done: bool = false
var card: ArenaCard
var name_label: Label
var grade_label: Label

static func play(host: Control, item_kind: StringName) -> ItemGainShow:
	var show := ItemGainShow.new();show.kind = item_kind;host.add_child(show);return show

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 50
	var data: ItemData = ItemCatalog.get_item(kind)
	card = ArenaCard.new();card.card_type = "product";card.slot_kind = "item";card.kind = String(kind);card.title = data.display_name;card.description = data.description
	card.tag_text = "소모품" if data.consumable else ItemCatalog.grade_name(kind) + " 아이템";card.item_grade = data.grade if not data.consumable else &"";card.rarity = ItemCatalog.grade_color(kind) if not data.consumable else Color(0, 0, 0, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE;card.size = Vector2(170, 236);add_child(card)
	name_label = _label("", 13, ArenaUI.MUTED);name_label.text = "아이템 획득"
	grade_label = _label(data.display_name, 24, ItemCatalog.grade_color(kind).lightened(.3))
	var hint := _label("화면을 누르면 넘어갑니다", 11, Color(ArenaUI.MUTED, .7));hint.name = "Hint"
	_layout()
	resized.connect(_layout)
func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new();l.text = text;l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;l.add_theme_font_size_override("font_size", font_size);l.add_theme_color_override("font_color", color)
	if font_size >= 20:l.add_theme_font_override("font", ArenaUI.heading_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE;l.modulate.a = 0;add_child(l);return l
func _layout() -> void:
	var c: Vector2 = size * .5
	card.position = c - card.size * .5 - Vector2(0, 30);card.pivot_offset = card.size * .5
	name_label.position = Vector2(0, card.position.y + card.size.y + 22);name_label.size = Vector2(size.x, 20)
	grade_label.position = Vector2(0, name_label.position.y + 20);grade_label.size = Vector2(size.x, 34)
	var hint: Label = get_node("Hint");hint.position = Vector2(0, size.y - 60);hint.size = Vector2(size.x, 20)

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:accept_event();close()
func close() -> void:
	if done:return
	done = true;finished.emit();queue_free()

func _process(dt: float) -> void:
	age += dt
	var t: float = age
	# The card turns over (edge-on → face up) with a small lift, then settles.
	var flip: float = clampf(t / .45, 0, 1)
	card.scale = Vector2(maxf(.02, Motion.out_quint(flip)), 1) * (1.0 + .12 * (1 - Motion.out_quint(clampf(t / .7, 0, 1))))
	name_label.modulate.a = clampf((t - .45) / .25, 0, 1);grade_label.modulate.a = clampf((t - .55) / .25, 0, 1)
	get_node("Hint").modulate.a = clampf((t - .9) / .3, 0, 1)
	if t >= LIFE:close()
	queue_redraw()

func _draw() -> void:
	var t: float = age;var c: Vector2 = card.position + card.size * .5
	var col: Color = ItemCatalog.grade_color(kind);var grade: StringName = ItemCatalog.grade_of(kind)
	draw_rect(Rect2(Vector2.ZERO, size), Color(.02, .03, .06, .93 * clampf(t / .2, 0, 1)))
	var rank: int = maxi(0, ItemCatalog.grade_rank(kind))
	# Light behind the card, stronger for higher grades.
	VfxArt.glow(self, c, 150 + rank * 25, col, (.25 + rank * .06) * clampf(t / .4, 0, 1))
	var rays: int = 8 + rank * 3
	for i in range(rays):
		var a: float = i * TAU / rays + t * .35
		var len: float = (120 + rank * 30) * Motion.out_quint(clampf((t - .3) / .6, 0, 1))
		draw_line(c + Vector2.from_angle(a) * 70, c + Vector2.from_angle(a) * (70 + len), Color(col.lightened(.3), .22), 3, true)
	# The burst as the card lands face up.
	var b: float = clampf((t - .42) / .6, 0, 1)
	if b > 0 and b < 1:
		draw_arc(c, 60 + 220 * Motion.out_expo(b), 0, TAU, 64, Color(col, .7 * (1 - b)), 4, true)
		if rank >= 2:draw_arc(c, 40 + 160 * Motion.out_expo(b), 0, TAU, 64, Color(col.lightened(.4), .5 * (1 - b)), 2, true)
	if grade == &"legendary":
		# 전설: a gold glint sweeps across and sparks rise.
		var sweep: float = clampf((t - .5) / .5, 0, 1)
		if sweep > 0 and sweep < 1:
			var x: float = lerpf(-100, 100, Motion.out_quint(sweep))
			draw_line(c + Vector2(x - 20, -120), c + Vector2(x + 20, 120), Color(1, .95, .7, .55 * (1 - sweep)), 10, true)
	for k in range(6 + rank * 4):
		var s: float = fposmod(k * .173 + t * .5, 1.0)
		draw_circle(c + Vector2((k * 37 % 200) - 100, 110 - s * 260), 2 + rank * .4, Color(col.lightened(.4), (1 - s) * .8 * clampf(t / .5, 0, 1)))
