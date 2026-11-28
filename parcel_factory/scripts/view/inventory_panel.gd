extends PanelContainer
## 인벤토리 창 (scenes/inventory_panel.tscn). 한 씬을 두 자리에서 써요:
##   open("center") : 가방만 볼 때 화면 가운데
##   open("beside") : 설비 정보창과 함께 볼 때 화면 가운데 오른쪽
## 위 3줄 = 가방 27칸, 아래 1줄 = 핫바 9칸. '크리에이티브 보관함' 탭은 디버그 메뉴에서 켜요.
## 조작: 끌어다 놓기 = 옮기기 · 두 칸을 차례로 탭 = 바꾸기 · 길게 누르기/오른쪽 클릭 = 반 나누기
##       Shift+클릭 = 핫바↔가방 빠른 이동 · 창 밖으로 끌어 놓기 = 플레이어 앞에 버리기
## 설비 정보창과 함께 열리면 '주고받기' 모드(transfer): 탭 = 1개를 설비로, 꾹·Shift+클릭 = 전부, 오른쪽 클릭 = 반.
## 그 설비에 넣을 수 없는 아이템은 흐리게(40%). 끌기 정리는 그대로예요.
## 인벤토리는 Inventory의 함수로만 바꾸고, 플레이어 상태는 읽기만 해요.

const InvSlot := preload("res://scripts/view/inv_slot.gd")
const GAP := 4
const BESIDE_GAP := 16.0      # 'beside' 자리: 화면 가운데에서 오른쪽으로 띄우는 거리
const CREATIVE_ROWS := 4      # 크리에이티브 보관함 목록 높이 (칸 줄 수, 넘치면 목록만 스크롤)

var player = null
var creative_enabled := false
var mode := "center"

var _title: Label
var _tab_bag: Button
var _tab_creative: Button
var _bag_view: VBoxContainer
var _creative_view: ScrollContainer
var _creative_grid: GridContainer
var _slots: Array = []        # 인벤토리 칸 번호 순서 (0~8 핫바, 9~ 가방)
var _picked := -1             # 탭-탭 교환에서 먼저 고른 칸
var _pointer := Vector2.ZERO  # 마지막 마우스·손가락 위치 (창 밖에 놓았는지 볼 때)
var transfer = null           # 주고받기 상대 (info_panel.gd). null이면 보통 가방
const TRANSFER_HOLD := 0.35   # 주고받기 모드에서 '꾹' 시간


func _ready() -> void:
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
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	_tab_bag = _button("가방", _show_tab.bind(false), 100)
	_tab_bag.toggle_mode = true
	top.add_child(_tab_bag)
	_tab_creative = _button("크리에이티브 보관함", _show_tab.bind(true), 220)
	_tab_creative.toggle_mode = true
	top.add_child(_tab_creative)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 18)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_title)
	top.add_child(_button("닫기", close, 90))
	# 가방 27칸 + 핫바 9칸
	_bag_view = VBoxContainer.new()
	_bag_view.add_theme_constant_override("separation", 10)
	v.add_child(_bag_view)
	_slots.resize(Inventory.SLOTS)
	var bag := _grid()
	_bag_view.add_child(bag)
	for i in range(Inventory.HOTBAR, Inventory.SLOTS):
		bag.add_child(_make_slot(i))
	var hot := _grid()
	_bag_view.add_child(hot)
	for i in Inventory.HOTBAR:
		hot.add_child(_make_slot(i))
	# 크리에이티브 보관함: 모든 아이템·설비 (누르면 한 묶음)
	_creative_view = ScrollContainer.new()
	_creative_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_creative_view.custom_minimum_size = Vector2(0, CREATIVE_ROWS * (InvSlot.SIZE + GAP))
	v.add_child(_creative_view)
	_creative_grid = _grid()
	_creative_view.add_child(_creative_grid)
	for n in DB.all_item_names():
		var s = InvSlot.new()
		s.draggable = false
		s.show_item(n, 0)
		s.tooltip_text = n
		s.clicked.connect(func(_i, _sh) -> void: _give(n))
		_creative_grid.add_child(s)
	player.inventory.changed.connect(refresh)
	player.hotbar_changed.connect(refresh)
	visible = false
	_show_tab(false)


func _button(text: String, cb: Callable, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 52)
	b.pressed.connect(cb)
	return b


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = Inventory.HOTBAR
	g.add_theme_constant_override("h_separation", GAP)
	g.add_theme_constant_override("v_separation", GAP)
	return g


func _make_slot(i: int):
	var s = InvSlot.new()
	s.index = i
	s.clicked.connect(_on_click)
	s.right_clicked.connect(_on_right)
	s.long_pressed.connect(_on_long)
	s.moved.connect(_on_moved)
	s.dragged_out.connect(_on_dragged_out)
	_slots[i] = s
	return s


# ---------- 열고 닫기 ----------

func open(where: String = "center") -> void:
	mode = where
	_place()
	visible = true
	_picked = -1
	refresh()


func close() -> void:
	visible = false
	_picked = -1


func toggle(where: String = "center") -> void:
	if visible:
		close()
	else:
		open(where)


func set_creative(on: bool) -> void:
	creative_enabled = on
	_tab_creative.visible = on
	if not on:
		_show_tab(false)


func _place() -> void:
	## 'center' = 화면 가운데 · 'beside' = 가운데 오른쪽 (왼쪽엔 설비 정보창)
	reset_size()
	var sz := get_combined_minimum_size()
	if mode == "beside":
		set_anchors_preset(Control.PRESET_CENTER_LEFT)
		anchor_left = 0.5
		anchor_right = 0.5
		offset_left = BESIDE_GAP
		offset_right = BESIDE_GAP + sz.x
	else:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -sz.x * 0.5
		offset_right = sz.x * 0.5
	offset_top = -sz.y * 0.5
	offset_bottom = sz.y * 0.5


func _show_tab(creative: bool) -> void:
	var c := creative and creative_enabled
	_bag_view.visible = not c
	_creative_view.visible = c
	_tab_bag.set_pressed_no_signal(not c)
	_tab_creative.set_pressed_no_signal(c)
	_tab_creative.visible = creative_enabled
	if visible:
		_place()


# ---------- 칸 조작 ----------

func _on_click(i: int, shift: bool) -> void:
	var inv: Inventory = player.inventory
	if transfer != null:
		transfer.give(i, "all" if shift else "one")
		return
	if shift:
		inv.quick_move(i)
		_picked = -1
	elif _picked < 0:
		if inv.id_at(i) != "":
			_picked = i
	elif _picked == i:
		_picked = -1
	else:
		inv.move_slot(_picked, i)
		_picked = -1
	refresh()


func _on_right(i: int) -> void:
	if transfer != null:
		transfer.give(i, "half")
	else:
		player.inventory.split_slot(i)
		_picked = -1


func _on_long(i: int) -> void:
	if transfer != null:
		transfer.give(i, "all")
	else:
		player.inventory.split_slot(i)
		_picked = -1


func set_transfer(t) -> void:
	## 설비 정보창과 함께 열릴 때 주고받기 모드로
	transfer = t
	_picked = -1
	for s in _slots:
		s.long_press = TRANSFER_HOLD if t != null else InvSlot.LONG_PRESS
		s.show_gauge = t != null
	refresh()


func slot_node(i: int):
	return _slots[i] if i >= 0 and i < _slots.size() else null


func slot_of(id: String) -> int:
	## 그 아이템이 있는 첫 칸 (핫바 먼저)
	for i in Inventory.SLOTS:
		if player.inventory.id_at(i) == id:
			return i
	return -1


func _on_moved(from: int, to: int) -> void:
	player.inventory.move_slot(from, to)
	_picked = -1


func _input(e: InputEvent) -> void:
	# 끌기 중엔 칸이 움직임을 못 받으니, 손가락·마우스 위치는 여기서 기억해요
	if visible and (e is InputEventMouseMotion or e is InputEventMouseButton or e is InputEventScreenDrag or e is InputEventScreenTouch):
		_pointer = e.position


func _on_dragged_out(i: int) -> void:
	## 창 밖에 놓았으면 플레이어 앞에 버려요
	if not get_global_rect().has_point(_pointer):
		player.drop_slot(i)
	_picked = -1
	refresh()


func _give(id: String) -> void:
	var lim := Inventory.stack_limit(id)
	var left: int = player.inventory.add(id, lim)
	player.message.emit(("%s %d개를 꺼냈어요" % [id, lim - left]) if left < lim else "가방이 가득 찼어요")


func refresh() -> void:
	if not visible:
		return
	var inv: Inventory = player.inventory
	var held: String = player.held_id()
	_title.text = "%d/%d칸 · HP %d · %s" % [inv.used_slots(), Inventory.SLOTS, player.hp, "맨손" if held == "" else held]
	for i in Inventory.SLOTS:
		var s = _slots[i]
		var e = inv.slots[i]
		s.show_item("" if e == null else e["id"], 0 if e == null else int(e["n"]))
		s.set_marks(i == _picked, i == player.hotbar)
		s.set_dim(transfer != null and e != null and not transfer.can_accept(e["id"]))
