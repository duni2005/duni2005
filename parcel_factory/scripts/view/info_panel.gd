extends PanelContainer
## 설비 정보창 (화면 가운데 왼쪽, 폭 약 40%). 오른쪽엔 인벤토리가 '주고받기' 모드로 함께 열려요.
##   [아이콘] 이름 [X] / 분류 · 크기 · 전력 / 설명 / [상태][설정] 탭
##   상태 탭: 색 점 + 아이콘 + 짧은 글 · 입력 칸 → 진행 화살표 → 출력 칸 (창고는 보관 격자) · 진행 · 전력 · 종류별 정보
##   설정 탭: 설비 종류별 설정 (레시피는 아이콘 격자 팝업)
##   아래: [이동] · [철거(꾹)]
## 칸 탭 = 1개를 인벤토리로, 꾹(0.35초) · Shift+클릭 = 전부, 오른쪽 클릭 = 반.
## 인벤토리 쪽에서 오는 넣기(give)도 여기서 처리해요 (inventory_panel.transfer = 이 창).
## 시뮬레이션은 factory.player_insert / player_extract / change_recipe / deconstruct로만 바꿔요.

signal closed

const InvSlot := preload("res://scripts/view/inv_slot.gd")
const REFRESH_SEC := 0.1
const HOLD_TAKE := 0.35          # 칸 꾹 = 전부
const DECON_HOLD := 0.6          # 철거 버튼 꾹
const ICON_BIG := 48.0
const STORE_COLS := 7
const STORE_ROWS := 3            # 보관 격자 높이 (넘치면 목록만 스크롤)
const RECIPE_COLS := 6
const KIND_BORDER := {"in": Palette.G3, "fuel": Palette.ORANGE, "out": Palette.GREEN, "store": Palette.G3}

var hud = null
var player = null
var factory: Factory = null
var inv_panel = null
var building = null

var _memory := {}               # 설비 이름 → 마지막 탭 ("상태"/"설정")
var _t := 0.0
var _icon: TextureRect
var _title: Label
var _tags: Label
var _desc: Label
var _tab_status: Button
var _tab_settings: Button
var _page_status: VBoxContainer
var _page_settings: VBoxContainer
var _status_icon: TextureRect
var _status_dot: ColorRect
var _status_label: Label
var _slot_row: HBoxContainer
var _in_box: HBoxContainer
var _out_box: HBoxContainer
var _arrow: Arrow
var _store_scroll: ScrollContainer
var _store_grid: GridContainer
var _prog_row: HBoxContainer
var _prog_bar: Bar
var _prog_label: Label
var _power_row: HBoxContainer
var _power_bar: Bar
var _power_label: Label
var _extra: Label
var _extra_icons: HBoxContainer
var _move_btn: Button
var _decon_btn: HoldButton
var _slot_nodes: Array = []     # get_slots() 순서
var _popup: PanelContainer
var _popup_grid: GridContainer
var _popup_preview: Label
var _popup_pick = null


# ---------- 작은 그림 부품 ----------

class Bar extends Control:
	## 가로 게이지
	var value := 0.0
	var color := Color.WHITE

	func _ready() -> void:
		custom_minimum_size = Vector2(220, 14)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float, c: Color) -> void:
		value = clampf(v, 0.0, 1.0)
		color = c
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Palette.c(Palette.INK))
		draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * value, size.y - 4)), color)


class Arrow extends Control:
	## 입력 → 출력 화살표. 진행만큼 채워져요
	var value := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(72, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var y := size.y * 0.5
		var x0 := 6.0
		var x1 := size.x - 18.0
		draw_rect(Rect2(x0, y - 6, x1 - x0, 12), Palette.c(Palette.G2))
		draw_rect(Rect2(x0, y - 6, (x1 - x0) * value, 12), Palette.c(Palette.LIME))
		var head := PackedVector2Array([Vector2(x1, y - 14), Vector2(size.x - 4, y), Vector2(x1, y + 14)])
		draw_colored_polygon(head, Palette.c(Palette.LIME) if value >= 0.999 else Palette.c(Palette.G3))


class HoldButton extends Button:
	## 꾹 눌러야 되는 버튼 (철거). 누르는 동안 채워지고, 다 차면 held
	signal held
	var hold_sec := 0.6
	var _t := -1.0

	func _ready() -> void:
		button_down.connect(func() -> void: _t = 0.0)
		button_up.connect(func() -> void: _cancel())

	func _cancel() -> void:
		_t = -1.0
		queue_redraw()

	func _process(dt: float) -> void:
		if _t < 0.0 or disabled:
			return
		_t += dt
		queue_redraw()
		if _t >= hold_sec:
			_t = -1.0
			held.emit()

	func _draw() -> void:
		if _t > 0.0:
			draw_rect(Rect2(Vector2(0, size.y - 6), Vector2(size.x * clampf(_t / hold_sec, 0.0, 1.0), 6)), Palette.c(Palette.RED))


# ---------- 만들기 ----------

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.c(Palette.G1)
	sb.border_color = Palette.c(Palette.G3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	# 머리: 아이콘 · 이름 · 태그 · 닫기
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(ICON_BIG, ICON_BIG)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_icon)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	tv.add_child(_title)
	_tags = Label.new()
	_tags.add_theme_font_size_override("font_size", 15)
	_tags.add_theme_color_override("font_color", Palette.c(Palette.G4))
	tv.add_child(_tags)
	head.add_child(_btn("X", close, 64))
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.max_lines_visible = 2
	_desc.add_theme_font_size_override("font_size", 15)
	_desc.add_theme_color_override("font_color", Palette.c(Palette.G5))
	v.add_child(_desc)
	# 탭
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	_tab_status = _btn("상태", _show_tab.bind("상태"), 110)
	_tab_status.toggle_mode = true
	tabs.add_child(_tab_status)
	_tab_settings = _btn("설정", _show_tab.bind("설정"), 110)
	_tab_settings.toggle_mode = true
	tabs.add_child(_tab_settings)
	# 상태 탭
	_page_status = VBoxContainer.new()
	_page_status.add_theme_constant_override("separation", 10)
	_page_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_page_status)
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", 8)
	_page_status.add_child(st)
	_status_dot = ColorRect.new()
	_status_dot.custom_minimum_size = Vector2(14, 14)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.add_child(_status_dot)
	_status_icon = TextureRect.new()
	_status_icon.custom_minimum_size = Vector2(24, 24)
	_status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.add_child(_status_icon)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	st.add_child(_status_label)
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 6)
	_page_status.add_child(_slot_row)
	_in_box = HBoxContainer.new()
	_in_box.add_theme_constant_override("separation", 4)
	_slot_row.add_child(_in_box)
	_arrow = Arrow.new()
	_slot_row.add_child(_arrow)
	_out_box = HBoxContainer.new()
	_out_box.add_theme_constant_override("separation", 4)
	_slot_row.add_child(_out_box)
	_store_scroll = ScrollContainer.new()
	_store_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_store_scroll.custom_minimum_size = Vector2(0, STORE_ROWS * (InvSlot.SIZE + 4))
	_page_status.add_child(_store_scroll)
	_store_grid = GridContainer.new()
	_store_grid.columns = STORE_COLS
	_store_grid.add_theme_constant_override("h_separation", 4)
	_store_grid.add_theme_constant_override("v_separation", 4)
	_store_scroll.add_child(_store_grid)
	_prog_row = _bar_row()
	_prog_bar = _prog_row.get_child(1)
	_prog_label = _prog_row.get_child(2)
	_power_row = _bar_row()
	_power_bar = _power_row.get_child(1)
	_power_label = _power_row.get_child(2)
	_extra = Label.new()
	_extra.add_theme_font_size_override("font_size", 16)
	_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page_status.add_child(_extra)
	_extra_icons = HBoxContainer.new()
	_page_status.add_child(_extra_icons)
	# 설정 탭
	_page_settings = VBoxContainer.new()
	_page_settings.add_theme_constant_override("separation", 8)
	_page_settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_page_settings)
	# 아래: 이동 · 철거
	var foot := HBoxContainer.new()
	v.add_child(foot)
	_move_btn = _btn("이동", _on_move, 120)
	foot.add_child(_move_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	_decon_btn = HoldButton.new()
	_decon_btn.text = "철거 (꾹)"
	_decon_btn.hold_sec = DECON_HOLD
	_decon_btn.focus_mode = Control.FOCUS_NONE
	_decon_btn.custom_minimum_size = Vector2(150, 64)
	_decon_btn.held.connect(_on_deconstruct)
	foot.add_child(_decon_btn)
	_build_popup()
	visible = false


func _btn(text: String, cb: Callable, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 64)
	b.pressed.connect(cb)
	return b


func _bar_row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(24, 24)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var bar := Bar.new()
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	_page_status.add_child(h)
	return h


func _ui_icon(kind: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = Art.tex("ui_icons")
	a.region = Rect2(SpriteGen.UI_ICONS.find(kind) * 8, 0, 8, 8)
	return a


# ---------- 열고 닫기 ----------

func open(b) -> void:
	building = b
	visible = true
	_title.text = b.name
	_icon.texture = Art.item_icon(DB.building_item(b.name), 16)
	var d: Dictionary = b.def
	var tags := [str(d.get("cat", "")), "%d×%d" % [b.size.x, b.size.y]]
	if float(d.get("power", 0.0)) > 0.0:
		tags.append("전력 %d" % int(d["power"]))
	if float(d.get("gen", 0.0)) > 0.0:
		tags.append("발전 %d" % int(d["gen"]))
	_tags.text = " · ".join(tags)
	_desc.text = str(d.get("desc", ""))
	_decon_btn.disabled = not factory.can_deconstruct(b)
	_decon_btn.tooltip_text = "" if not _decon_btn.disabled else "지급 설비·지형은 철거할 수 없어요"
	_rebuild_settings()
	_rebuild_slots()
	_popup.visible = false
	var has_settings := _page_settings.get_child_count() > 0
	_tab_settings.visible = has_settings
	var tab: String = _memory.get(b.name, "상태")
	_show_tab(tab if has_settings else "상태")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	building = null
	closed.emit()


func _show_tab(tab: String) -> void:
	_page_status.visible = tab == "상태"
	_page_settings.visible = tab == "설정"
	_tab_status.set_pressed_no_signal(tab == "상태")
	_tab_settings.set_pressed_no_signal(tab == "설정")
	if building != null:
		_memory[building.name] = tab


func _process(dt: float) -> void:
	if not visible:
		return
	if building == null or not factory.buildings.has(building):
		close()
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = REFRESH_SEC
	refresh()


# ---------- 칸 ----------

func _rebuild_slots() -> void:
	for n in _slot_nodes:
		n.queue_free()
	_slot_nodes.clear()
	var slots: Array = building.get_slots()
	var store := false
	for i in slots.size():
		var s: Dictionary = slots[i]
		var node = InvSlot.new()
		node.index = i
		node.draggable = false
		node.long_press = HOLD_TAKE
		node.show_gauge = true
		node.border_color = KIND_BORDER.get(s["kind"], Palette.G3)
		node.clicked.connect(func(idx, shift) -> void: take(idx, "all" if shift else "one"))
		node.long_pressed.connect(func(idx) -> void: take(idx, "all"))
		node.right_clicked.connect(func(idx) -> void: take(idx, "half"))
		if s["kind"] == "store":
			store = true
			_store_grid.add_child(node)
		elif s["kind"] == "out":
			_out_box.add_child(node)
		else:
			_in_box.add_child(node)
		_slot_nodes.append(node)
	_store_scroll.visible = store
	_slot_row.visible = not store and not slots.is_empty()
	_arrow.visible = _out_box.get_child_count() > 0 and _in_box.get_child_count() > 0


func refresh() -> void:
	if building == null:
		return
	var b = building
	var slots: Array = b.get_slots()
	if slots.size() != _slot_nodes.size():
		_rebuild_slots()
	for i in slots.size():
		var s: Dictionary = slots[i]
		var node = _slot_nodes[i]
		node.show_item(s["item_id"] if s["count"] > 0 or s["kind"] != "store" else "", int(s["count"]))
		node.set_cap(int(s["cap"]) if s["kind"] != "store" else 0)
		node.set_dim(int(s["count"]) == 0)
	# 상태: 색 점 + 아이콘 + 짧은 글
	var st := _status(b)
	_status_dot.color = st[0]
	_status_icon.texture = _ui_icon(st[1])
	_status_label.text = st[2]
	# 진행
	var pr := _progress(b)
	_prog_row.visible = pr[0] >= 0.0
	if pr[0] >= 0.0:
		_prog_bar.set_value(pr[0], Palette.c(Palette.LIME))
		_prog_label.text = pr[1]
		_arrow.set_value(pr[0])
	(_prog_row.get_child(0) as TextureRect).texture = _ui_icon("gear")
	# 전력
	_power_row.visible = b.needs_power() or b is Generator
	(_power_row.get_child(0) as TextureRect).texture = _ui_icon("bolt")
	if b is Generator:
		_power_bar.set_value(b.burn_fraction(), Palette.c(Palette.ORANGE))
		_power_label.text = "공급 %d · 연소" % int(b.power_supply())
	elif b.needs_power():
		var m: float = b.power_mult()
		_power_bar.set_value(m, Palette.c(Palette.YELLOW) if m < 1.0 else Palette.c(Palette.GREEN))
		_power_label.text = "%d%%" % int(round(m * 100.0)) if b.power_net != null else "연결 안 됨"
	_extra.text = _extra_text(b)
	_extra.visible = _extra.text != ""
	_update_extra_icons(b)
	if inv_panel != null and inv_panel.visible:
		inv_panel.refresh()


func _status(b) -> Array:
	## [색, 아이콘, 짧은 글]
	var s: String = b.status
	if b.needs_power() and b.power_net == null:
		return [Palette.c(Palette.RED), "stop", "전력 연결 안 됨"]
	if b.needs_power() and b.power_mult() <= 0.0 and s.find("전력") >= 0:
		return [Palette.c(Palette.RED), "stop", "전력 없음"]
	if s.find("막힘") >= 0:
		return [Palette.c(Palette.RED), "stop", "출력 막힘"]
	if b.is_active():
		if b.needs_power() and b.power_mult() < 1.0:
			return [Palette.c(Palette.YELLOW), "bolt", "작동 중 (전력 부족)"]
		return [Palette.c(Palette.GREEN), "check", "작동 중"]
	if s.find("기다") >= 0 or s.find("재료") >= 0 or s.find("모자라") >= 0:
		return [Palette.c(Palette.YELLOW), "warn", "재료 부족"]
	if s.find("레시피") >= 0:
		return [Palette.c(Palette.YELLOW), "warn", "레시피를 골라요"]
	return [Palette.c(Palette.G4), "warn", s if s != "" else "대기"]


func _progress(b) -> Array:
	## [0~1 (없으면 -1), 글]
	var k := -1.0
	var total := 0.0
	var mult: float = b.power_mult() if b.needs_power() else 1.0
	if b is Machine and b.recipe != null:
		total = float(b.recipe["t"])
		k = b.progress / total
		mult *= b.speed_setting
	elif b is Packer or b is Combiner or b is GiftPacker:
		total = float(b.def.get("time", 1.0))
		k = b.t / total
	elif b is Injector:
		total = float(b.def.get("time", 6.0))
		k = b.fill_t / total
	if k < 0.0:
		return [-1.0, ""]
	var left := (1.0 - k) * total / maxf(mult, 0.01)
	return [k, "%d%% · %.1f초 남음" % [int(k * 100.0), left] if b.is_active() else "%d%%" % int(k * 100.0)]


func _extra_text(b) -> String:
	if b is Machine and b.recipe != null:
		return b.per_minute()
	if b is Pump:
		return "물 %d/분 공급" % int(b.water_supply())
	if b is Injector:
		var net = b.water_net
		var fill: String = ("채우는 중: " + b.item.id) if b.item != null else "빈 용기를 기다려요"
		if net == null:
			return "파이프 연결 안 됨 · " + fill
		return "물 공급 %d · 수요 %d · %s" % [int(net["supply"]), int(net["demand"]), fill]
	if b is StorageBlock:
		return "보관 %d/%d (블록 %d개)" % [b.group.items.size(), b.group.cap, b.group.members.size()]
	if b is ItemPile:
		return "Lv%d · %d개/분 · 다음에 나올 것:" % [b.level, int(b.rate_per_min())]
	if b is RailBridge:
		var p = b.partner()
		if p == null:
			return "짝 다리 없음 (앞쪽 2~5칸에 같은 방향 다리를 놓아요)"
		return "짝 다리 있음 · %d칸 앞" % (absi(p.pos.x - b.pos.x) + absi(p.pos.y - b.pos.y))
	if b is Shelf:
		return "오늘 배달 %d (정상 %d · 오배송 %d)" % [b.shipped, b.shipped_ok, b.shipped - b.shipped_ok]
	if b is Detector:
		return "고른 물건: %s · 보관 %d/10" % [b.selected if b.selected != "" else "없음", b.stock]
	if b is Sorter:
		return "필터: %s" % (b.filter_item if b.filter_item != "" else "없음")
	if b is VoidSink:
		return "없앤 수 %d" % b.total
	if b is InfiniteSource:
		return "%s · %d개/초 · 보낸 수 %d" % [b.item_id, int(b.per_sec), b.sent]
	if b is WorkComputer:
		return "요청서 출력 %s · 대기 %d · 출력 %d" % ["중" if b.printing else "멈춤", b.buffer.size(), b.printed]
	return ""


func _update_extra_icons(b) -> void:
	var want: Array = b.upcoming(3) if b is ItemPile else []
	while _extra_icons.get_child_count() < want.size():
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(40, 40)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_extra_icons.add_child(t)
	for i in _extra_icons.get_child_count():
		var t: TextureRect = _extra_icons.get_child(i)
		t.visible = i < want.size()
		if i < want.size():
			t.texture = Art.item_icon(want[i], 16)
	_extra_icons.visible = not want.is_empty()


# ---------- 주고받기 ----------

func can_accept(id: String) -> bool:
	return building != null and building.accepts(id)


func take(i: int, mode: String) -> void:
	## 정보창 칸 → 인벤토리
	var slots: Array = building.get_slots()
	if i >= slots.size():
		return
	var s: Dictionary = slots[i]
	var have := int(s["count"])
	var node = _slot_nodes[i]
	if have <= 0:
		_fail(node, "비어 있어요")
		return
	var want := 1 if mode == "one" else (have if mode == "all" else maxi(1, int(ceil(have / 2.0))))
	var item = s["item"] if s["item"] != null else s["item_id"]
	var room: int = player.inventory.space_for(item)
	if room <= 0:
		_fail(node, "인벤토리가 가득 찼어요")
		return
	var got := factory.player_extract(building, i, mini(want, room))
	for it in got:
		player.inventory.add(it, 1)
	if got.is_empty():
		_fail(node, "꺼낼 수 없어요")
		return
	var to: int = inv_panel.slot_of(got[0].id)
	hud.fly(got[0].id, node.get_global_rect(), inv_panel.slot_node(to).get_global_rect() if to >= 0 else inv_panel.get_global_rect(), got.size())
	if to >= 0:
		inv_panel.slot_node(to).bounce()
	refresh()


func give(inv_slot: int, mode: String) -> void:
	## 인벤토리 칸 → 설비 (어느 칸에 들어갈지는 설비가 정해요)
	var inv: Inventory = player.inventory
	var id := inv.id_at(inv_slot)
	var node = inv_panel.slot_node(inv_slot)
	if id == "":
		return
	if not building.accepts(id):
		_fail(node, "넣을 수 없어요")
		return
	var have := inv.count(id) if mode == "all" else int(inv.slots[inv_slot]["n"])
	var want := 1 if mode == "one" else (have if mode == "all" else maxi(1, int(ceil(have / 2.0))))
	var unique: Item = inv.slots[inv_slot]["item"]
	var put := factory.player_insert(building, unique if unique != null else id, want)
	if put <= 0:
		_fail(node, "가득 찼어요")
		return
	inv.remove(id, put, inv_slot)
	var target = null
	var slots: Array = building.get_slots()
	for j in slots.size():
		if slots[j]["item_id"] == id:
			target = _slot_nodes[j] if j < _slot_nodes.size() else null
			break
	hud.fly(id, node.get_global_rect(), target.get_global_rect() if target != null else get_global_rect(), put)
	if target != null:
		target.bounce()
	refresh()


func _fail(node, why: String) -> void:
	if node != null:
		node.shake()
	hud.show_message(why)


# ---------- 이동 · 철거 ----------

func _on_move() -> void:
	## 9단계의 '옮기기'로 바로 들어요 (지금은 이동 모드로 바꾸기만 해요)
	var b = building
	close()
	hud.main.begin_move(b)


func _on_deconstruct() -> void:
	var b = building
	var name_: String = b.name
	var out := factory.deconstruct(b)
	if out.is_empty():
		hud.show_message("%s은(는) 철거할 수 없어요" % name_)
		return
	hud.show_message("%s을(를) 철거했어요 · %d개가 바닥에 쏟아졌어요" % [name_, out.size()])
	close()


# ---------- 설정 탭 (설비 종류별) ----------

func _row(label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	h.add_child(l)
	_page_settings.add_child(h)
	return h


func _item_option(current: String, allow_none: bool, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(340, 64)
	o.focus_mode = Control.FOCUS_NONE
	o.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	o.get_popup().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
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
	o.custom_minimum_size = Vector2(340, 64)
	o.focus_mode = Control.FOCUS_NONE
	for i in names.size():
		o.add_item(str(names[i][0]))
		o.set_item_metadata(i, names[i][1])
		if names[i][1] == current:
			o.select(i)
	o.item_selected.connect(func(i): cb.call(o.get_item_metadata(i)))
	return o


func _rebuild_settings() -> void:
	for ch in _page_settings.get_children():
		_page_settings.remove_child(ch)
		ch.queue_free()
	var b = building
	if b is Machine and not b.available_recipes().is_empty():
		var rb := _btn(_recipe_text(b.recipe), _open_popup, 400)
		rb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		rb.expand_icon = false
		if b.recipe != null:
			rb.icon = Art.item_icon(b.recipe["out"].keys()[0], 16)
		_row("레시피").add_child(rb)
		_row("속도").add_child(_options([["100%", 1.0], ["50% (전력 40%)", 0.5]], b.speed_setting, func(v): b.speed_setting = v))
	elif b is Sorter:
		_row("필터").add_child(_item_option(b.filter_item, true, func(n): b.filter_item = n))
		_row("모드").add_child(_options([["필터: 고른 품목 → 옆", "filter"], ["넘침: 막히면 옆", "overflow"], ["반전: 고른 품목 → 앞", "inverse"]], b.mode, func(m): b.mode = m))
		_row("옆 방향").add_child(_options([["오른쪽", true], ["왼쪽", false]], b.side_right, func(v): b.side_right = v))
	elif b is Detector:
		_row("고른 물건").add_child(_item_option(b.selected, true, func(n): _set_detector_item(b, n)))
		_row("모드").add_child(_options([["요청 채우기", false], ["판매용 (같은 물건 4개)", true]], b.sale_mode, func(v): b.sale_mode = v))
	elif b is ItemPile:
		var types := []
		for t in DB.piles:
			types.append([t, t])
		_row("종류").add_child(_options(types, b.pile_type, func(t): b.set_type(t)))
		_row("레벨").add_child(_options([["Lv1 · 30개/분", 1], ["Lv2 · 60개/분", 2], ["Lv3 · 120개/분", 3]], b.level, func(l): b.level = l))
	elif b is InfiniteSource:
		_row("아이템").add_child(_item_option(b.item_id, false, func(n): b.item_id = n))
		_row("속도").add_child(_options([["1개/초", 1.0], ["2개/초", 2.0], ["4개/초", 4.0]], b.per_sec, func(v): b.per_sec = v))
	elif b is WorkComputer:
		_row("품목 추가").add_child(_item_option("", true, func(n): _add_order_item(b, n)))
		var h := _row("목록")
		h.add_child(_btn("비우기", func() -> void: b.order_items.clear(), 120))
		h.add_child(_btn("기본값", func() -> void: b.order_items = ["장난감", "나뭇가지", "바위"], 120))
		_row("최대 종류").add_child(_options([["1종", 1], ["2종", 2], ["3종", 3]], b.max_kinds, func(v): b.max_kinds = v))
		_row("최대 개수").add_child(_options([["1개", 1], ["2개", 2], ["3개", 3], ["4개", 4]], b.max_total, func(v): b.max_total = v))
		_row("선물용").add_child(_options([["아니오", false], ["예", true]], b.gift, func(v): b.gift = v))
		_row("출력").add_child(_options([["켬", true], ["끔", false]], b.printing, func(v): b.printing = v))
	elif b is Shelf:
		_row("자동 배달").add_child(_options([["켬", true], ["끔", false]], b.auto_deliver, func(v): b.auto_deliver = v))


func _set_detector_item(b, n) -> void:
	b.selected = n
	b.stock = 0
	_rebuild_slots()


func _add_order_item(b, n) -> void:
	if n != "" and not b.order_items.has(n):
		b.order_items.append(n)


func _recipe_text(r) -> String:
	return "(레시피 없음)" if r == null else DB.recipe_label(r)


# ---------- 레시피 고르기 팝업 (아이콘 격자 + 재료→결과 미리보기) ----------

func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.c(Palette.INK), 0.97)
	sb.set_content_margin_all(12)
	_popup.add_theme_stylebox_override("panel", sb)
	add_child(_popup)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_popup.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Label.new()
	t.text = "레시피 고르기"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(_btn("선택", _apply_popup, 100))
	top.add_child(_btn("취소", func() -> void: _popup.visible = false, 100))
	_popup_preview = Label.new()
	_popup_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_preview.add_theme_font_size_override("font_size", 16)
	v.add_child(_popup_preview)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_popup_grid = GridContainer.new()
	_popup_grid.columns = RECIPE_COLS
	_popup_grid.add_theme_constant_override("h_separation", 6)
	_popup_grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(_popup_grid)
	_popup.visible = false


func _open_popup() -> void:
	for ch in _popup_grid.get_children():
		ch.queue_free()
	var rs: Array = building.available_recipes()
	var none := _btn("없음", _pick_recipe.bind(null), 72)
	_popup_grid.add_child(none)
	for r in rs:
		var b := Button.new()
		b.custom_minimum_size = Vector2(72, 72)
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Art.item_icon(r["out"].keys()[0], 16)
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.tooltip_text = DB.recipe_label(r)
		if r["alt"]:
			b.text = "대체"
			b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_pick_recipe.bind(r))
		_popup_grid.add_child(b)
	_popup_pick = building.recipe
	_popup_preview.text = "지금: " + _recipe_text(building.recipe)
	_popup.visible = true


func _pick_recipe(r) -> void:
	_popup_pick = r
	_popup_preview.text = "미리보기: " + _recipe_text(r)


func _apply_popup() -> void:
	_popup.visible = false
	if _popup_pick == building.recipe:
		return
	factory.change_recipe(building, _popup_pick, player.inventory)
	_rebuild_settings()
	_rebuild_slots()
	refresh()
	hud.show_message("레시피: " + _recipe_text(building.recipe))
