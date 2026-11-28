extends PanelContainer
## 가방 창 (E · Tab · '가방' 버튼). 칸을 누르면 그 물건을 손에 들고, 다시 누르면 내려놔요.
## 가방·플레이어 상태는 읽기만 하고, 들기는 player.set_held()로 해요.

const COLS := 10
const SLOT := 64.0
const ICON := 32.0     # 16×16 아이콘 2배

var player = null
var _title: Label
var _slots: Array = []   # [Button, TextureRect, Label]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.c(Palette.G1)
	sb.border_color = Palette.c(Palette.G3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(100, 52)
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for i in Inventory.SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.pressed.connect(_on_slot.bind(i))
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(SLOT - ICON, SLOT - ICON) * 0.5 - Vector2(0, 4)
		icon.size = Vector2(ICON, ICON)
		b.add_child(icon)
		var count := Label.new()
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 16)
		count.position = Vector2(4, SLOT - 24)
		count.size = Vector2(SLOT - 8, 20)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(count)
		grid.add_child(b)
		_slots.append([b, icon, count])
	player.inventory.changed.connect(refresh)
	visible = false
	refresh()


func toggle() -> void:
	visible = not visible
	refresh()


func _on_slot(i: int) -> void:
	var slots: Array = player.inventory.slots
	if i < slots.size():
		player.set_held(slots[i]["id"])
	refresh()


func refresh() -> void:
	var inv: Inventory = player.inventory
	var held_txt: String = "맨손" if player.held == "" else "손에 든 것: " + player.held
	_title.text = "가방 %d/%d칸 · HP %d · %s" % [inv.slots.size(), Inventory.SLOTS, player.hp, held_txt]
	for i in _slots.size():
		var b: Button = _slots[i][0]
		var icon: TextureRect = _slots[i][1]
		var count: Label = _slots[i][2]
		if i < inv.slots.size():
			var s: Dictionary = inv.slots[i]
			icon.texture = Art.item_icon(s["id"], 16)
			count.text = str(s["n"]) if int(s["n"]) > 1 else ""
			b.tooltip_text = s["id"]
			b.set_pressed_no_signal(s["id"] == player.held)
			b.disabled = false
		else:
			icon.texture = null
			count.text = ""
			b.tooltip_text = ""
			b.set_pressed_no_signal(false)
			b.disabled = true
