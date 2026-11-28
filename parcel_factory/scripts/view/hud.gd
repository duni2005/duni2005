extends CanvasLayer
## 화면 UI: 위쪽 도구 막대, 아래쪽 설비 팔레트, 오른쪽 정보 패널.
## 휴대폰 터치에 맞게 버튼을 크게 만들었어요.

var main = null

var root: Control
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var inspector: PanelContainer
var status_label: Label
var tool_buttons := {}
var pause_btn: Button
var speed_btn: Button
var cat_box: HBoxContainer
var item_box: HBoxContainer
var current_cat: String = ""

var ins_title: Label
var ins_info: Label
var ins_controls: VBoxContainer
var ins_target = null
var _refresh_t := 0.0

var menu_panel: PanelContainer
var creative_btn: Button
var debug_overlay
var _msg := ""
var _msg_t := 0.0

const SPEEDS := [1.0, 2.0, 4.0, 8.0]
const MSG_SEC := 2.5            # 저장·불러오기 알림을 위쪽 막대에 띄우는 시간
const HOTBAR_SIZE := 9          # 숫자 1~9로 고를 수 있는 팔레트 칸 수
const DebugOverlay := preload("res://scripts/view/debug_overlay.gd")


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 22
	root.theme = th
	get_tree().root.theme = th
	add_child(root)
	_build_top()
	_build_bottom()
	_build_inspector()
	_build_menu()
	debug_overlay = DebugOverlay.new()
	debug_overlay.factory = main.factory
	debug_overlay.position = Vector2(8, 76)
	root.add_child(debug_overlay)
	refresh_tool_buttons()
	_select_category(DB.building_categories[0])


func _btn(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


# ---------- 위쪽 막대 ----------

func _build_top() -> void:
	top_panel = PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	top_panel.add_child(h)
	h.add_child(_btn("F3", toggle_debug, 56))
	pause_btn = _btn("멈춤", _on_pause, 110)
	h.add_child(pause_btn)
	speed_btn = _btn("×1", _on_speed, 70)
	h.add_child(speed_btn)
	for t in [["view", "보기"], ["build", "설치"], ["erase", "철거"]]:
		var b := _btn(t[1], main.set_tool.bind(t[0]), 110)
		b.toggle_mode = true
		tool_buttons[t[0]] = b
		h.add_child(b)
	h.add_child(_btn("회전", main.rotate_tool, 100))
	h.add_child(_btn("층 보기", _on_layers, 100))
	h.add_child(_btn("예시 불러오기", _on_demo, 150))
	h.add_child(_btn("비우기", _on_clear, 90))
	h.add_child(_btn("메뉴", toggle_menu, 80))
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 18)
	h.add_child(status_label)


func refresh_tool_buttons() -> void:
	for k in tool_buttons:
		tool_buttons[k].button_pressed = (k == main.tool)
	if main.tool == "build":
		tool_buttons["build"].text = "설치: " + main.build_def
	else:
		tool_buttons["build"].text = "설치"
	if main.tool != "view":
		hide_inspector()


func _on_pause() -> void:
	main.factory.paused = not main.factory.paused
	pause_btn.text = "재생" if main.factory.paused else "멈춤"


func _on_speed() -> void:
	var i := SPEEDS.find(main.factory.speed)
	var s: float = SPEEDS[(i + 1) % SPEEDS.size()]
	main.factory.speed = s
	speed_btn.text = "×%d" % int(s)


func _on_layers() -> void:
	main.view.show_layers = not main.view.show_layers


func _on_demo() -> void:
	main.new_room(true)


func _on_clear() -> void:
	main.clear_room()


# ---------- 아래쪽 팔레트 ----------

func _build_bottom() -> void:
	bottom_panel = PanelContainer.new()
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom_panel)
	var v := VBoxContainer.new()
	bottom_panel.add_child(v)
	var cs := ScrollContainer.new()
	cs.custom_minimum_size = Vector2(0, 60)
	cs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(cs)
	cat_box = HBoxContainer.new()
	cs.add_child(cat_box)
	for c in DB.building_categories:
		var b := _btn(c, _select_category.bind(c), 120)
		b.toggle_mode = true
		cat_box.add_child(b)
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, 64)
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(s)
	item_box = HBoxContainer.new()
	s.add_child(item_box)


func _select_category(c: String) -> void:
	current_cat = c
	for b in cat_box.get_children():
		b.button_pressed = (b.text == c)
	for ch in item_box.get_children():
		ch.queue_free()
	var names := DB.buildings_in(c)
	for i in names.size():
		var n: String = names[i]
		var label := "%d %s" % [i + 1, n] if i < HOTBAR_SIZE else n
		var b := _btn(label, main.select_build.bind(n), 0)
		b.tooltip_text = DB.buildings[n].get("desc", "")
		item_box.add_child(b)


# ---------- 정보 패널 ----------

func _build_inspector() -> void:
	inspector = PanelContainer.new()
	inspector.anchor_left = 1.0
	inspector.anchor_right = 1.0
	inspector.anchor_top = 0.0
	inspector.anchor_bottom = 1.0
	inspector.offset_left = -520
	inspector.offset_right = 0
	inspector.offset_top = 70
	inspector.offset_bottom = -140
	root.add_child(inspector)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	ins_title = Label.new()
	ins_title.add_theme_font_size_override("font_size", 26)
	v.add_child(ins_title)
	ins_info = Label.new()
	ins_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ins_info.custom_minimum_size = Vector2(480, 0)
	ins_info.add_theme_font_size_override("font_size", 18)
	v.add_child(ins_info)
	ins_controls = VBoxContainer.new()
	v.add_child(ins_controls)
	var h := HBoxContainer.new()
	v.add_child(h)
	h.add_child(_btn("회전", main.rotate_tool, 120))
	h.add_child(_btn("철거", _on_inspector_remove, 120))
	h.add_child(_btn("닫기", hide_inspector, 100))
	inspector.visible = false


func hide_inspector() -> void:
	inspector.visible = false
	ins_target = null
	if main != null and main.view != null:
		main.view.selected = null


func show_inspector(b) -> void:
	if b == null:
		hide_inspector()
		return
	ins_target = b
	inspector.visible = true
	ins_title.text = b.name
	for ch in ins_controls.get_children():
		ch.queue_free()
	_build_controls(b)
	_refresh_info()


func _on_inspector_remove() -> void:
	if ins_target != null:
		main.factory.remove_at(ins_target.pos)
	hide_inspector()


func _process(dt: float) -> void:
	_refresh_t -= dt
	if _refresh_t > 0.0:
		return
	_refresh_t = 0.25
	var f = main.factory
	if _msg_t > 0.0:
		_msg_t -= 0.25
		status_label.text = _msg
	else:
		status_label.text = "%s%s · %s · 배달 %d (오배송 %d) · 손 %d" % ["[크리에이티브] " if f.creative else "", f.time_text(), f.power_summary(), f.shipped, f.shipped - f.shipped_ok, f.hand_total()]
	if inspector.visible:
		if ins_target == null or not f.buildings.has(ins_target):
			hide_inspector()
		else:
			_refresh_info()


func _refresh_info() -> void:
	if ins_target != null:
		ins_info.text = ins_target.info()


func is_over_ui(p: Vector2) -> bool:
	for c in [top_panel, bottom_panel, inspector, menu_panel]:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false


# ---------- 메뉴 · 단축키 ----------

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(menu_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	menu_panel.add_child(v)
	var t := Label.new()
	t.text = "메뉴"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_btn("저장 (Ctrl+S)", _on_menu_save, 300))
	v.add_child(_btn("불러오기", _on_menu_load, 300))
	v.add_child(_btn("팔레트 접기/펴기 (E)", toggle_palette, 300))
	creative_btn = _btn("", _on_creative, 300)
	v.add_child(creative_btn)
	v.add_child(_btn("닫기 (Esc)", toggle_menu, 300))
	menu_panel.visible = false


func toggle_menu() -> void:
	menu_panel.visible = not menu_panel.visible
	_refresh_creative_btn()


func _on_creative() -> void:
	main.toggle_creative()
	_refresh_creative_btn()


func _refresh_creative_btn() -> void:
	creative_btn.text = "크리에이티브 (디버그): %s" % ("켬" if main.factory.creative else "끔")


func close_menu() -> bool:
	## 메뉴가 열려 있었으면 닫고 true
	if menu_panel.visible:
		menu_panel.visible = false
		return true
	return false


func _on_menu_save() -> void:
	main.save_game()
	menu_panel.visible = false


func _on_menu_load() -> void:
	main.load_game()
	menu_panel.visible = false


func toggle_debug() -> void:
	debug_overlay.toggle()


func toggle_palette() -> void:
	bottom_panel.visible = not bottom_panel.visible


func select_hotbar(i: int) -> void:
	## 숫자 키 i(1~9): 지금 보이는 팔레트 분류의 i번째 설비를 골라요
	var names := DB.buildings_in(current_cat)
	if i >= 1 and i <= mini(names.size(), HOTBAR_SIZE):
		main.select_build(names[i - 1])


func show_message(s: String) -> void:
	_msg = s
	_msg_t = MSG_SEC
	_refresh_t = 0.0


# ---------- 설비별 설정 ----------

func _row(label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	ins_controls.add_child(h)
	return h


func _item_option(current: String, allow_none: bool, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(340, 52)
	o.focus_mode = Control.FOCUS_NONE
	o.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 16×16 도트 아이콘이 번지지 않게
	o.get_popup().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	o.add_theme_constant_override("icon_max_width", 32)
	o.get_popup().add_theme_constant_override("icon_max_width", 32)
	var idx := 0
	if allow_none:
		o.add_item("(없음)")
		o.set_item_metadata(0, "")
		idx = 1
	var sel := 0
	for n in DB.item_order:
		o.add_icon_item(Art.item_icon(n), n)
		o.set_item_metadata(idx, n)
		if n == current:
			sel = idx
		idx += 1
	o.select(sel)
	o.item_selected.connect(func(i): cb.call(o.get_item_metadata(i)))
	return o


func _options(names: Array, current, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(340, 52)
	o.focus_mode = Control.FOCUS_NONE
	for i in names.size():
		o.add_item(str(names[i][0]))
		o.set_item_metadata(i, names[i][1])
		if names[i][1] == current:
			o.select(i)
	o.item_selected.connect(func(i): cb.call(o.get_item_metadata(i)))
	return o


func _build_controls(b) -> void:
	if b is Machine:
		var rs: Array = b.available_recipes()
		var names := [["(레시피 없음)", -1]]
		for r in rs:
			names.append([DB.recipe_label(r), r["id"]])
		var cur: int = b.recipe["id"] if b.recipe != null else -1
		_row("레시피").add_child(_options(names, cur, func(id): _set_recipe(b, id)))
		_row("속도").add_child(_options([["100%", 1.0], ["50% (전력 40%)", 0.5]], b.speed_setting, func(v): b.speed_setting = v))
	elif b is Sorter:
		_row("품목").add_child(_item_option(b.filter_item, true, func(n): b.filter_item = n))
		_row("모드").add_child(_options([["고른 품목 → 옆", "filter"], ["넘치면 옆", "overflow"], ["고른 품목 → 앞", "inverse"]], b.mode, func(m): b.mode = m))
		_row("옆 출력").add_child(_options([["오른쪽", true], ["왼쪽", false]], b.side_right, func(v): b.side_right = v))
	elif b is Detector:
		_row("아이템").add_child(_item_option(b.selected, true, func(n): _set_detector_item(b, n)))
		_row("모드").add_child(_options([["요청 채우기", false], ["판매용 (같은 물건 4개)", true]], b.sale_mode, func(v): b.sale_mode = v))
	elif b is ItemPile:
		var types := []
		for t in DB.piles:
			types.append([t, t])
		_row("종류").add_child(_options(types, b.pile_type, func(t): b.set_type(t)))
		_row("레벨").add_child(_options([["Lv1 · 30개/분", 1], ["Lv2 · 60개/분", 2], ["Lv3 · 120개/분", 3]], b.level, func(l): b.level = l))
		var hr: Vector2i = b.hand_pull_range()
		if hr != Vector2i.ZERO:
			_row("손").add_child(_btn("손으로 뒤지기 (%d~%d개)" % [hr.x, hr.y], main.hand_pull.bind(b), 300))
	elif b is InfiniteSource:
		_row("아이템").add_child(_item_option(b.item_id, false, func(n): b.item_id = n))
		_row("속도").add_child(_options([["1개/초", 1.0], ["2개/초", 2.0], ["4개/초", 4.0]], b.per_sec, func(v): b.per_sec = v))
	elif b is WorkComputer:
		_row("품목 추가").add_child(_item_option("", true, func(n): _add_order_item(b, n)))
		var h := _row("목록")
		h.add_child(_btn("비우기", _clear_orders.bind(b), 120))
		h.add_child(_btn("기본값", _default_orders.bind(b), 120))
		_row("최대 종류").add_child(_options([["1종", 1], ["2종", 2], ["3종", 3]], b.max_kinds, func(v): b.max_kinds = v))
		_row("최대 개수").add_child(_options([["1개", 1], ["2개", 2], ["3개", 3], ["4개", 4]], b.max_total, func(v): b.max_total = v))
		_row("선물용").add_child(_options([["아니오", false], ["예", true]], b.gift, func(v): b.gift = v))
		_row("출력").add_child(_options([["켬", true], ["끔", false]], b.printing, func(v): b.printing = v))
	elif b is Shelf:
		_row("자동 배달").add_child(_options([["켬", true], ["끔", false]], b.auto_deliver, func(v): b.auto_deliver = v))


func _clear_orders(b) -> void:
	b.order_items.clear()


func _default_orders(b) -> void:
	b.order_items = ["장난감", "나뭇가지", "바위"]


func _set_detector_item(b, n) -> void:
	b.selected = n
	b.stock = 0


func _add_order_item(b, n) -> void:
	if n != "" and not b.order_items.has(n):
		b.order_items.append(n)


func _set_recipe(b, id) -> void:
	if int(id) < 0:
		b.set_recipe(null)
		return
	for r in DB.recipes:
		if r["id"] == int(id):
			b.set_recipe(r)
			return
