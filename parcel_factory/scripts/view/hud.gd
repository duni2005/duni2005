extends CanvasLayer
## 화면 UI (모바일 가로 화면 기준, PC도 같은 화면).
##   왼쪽 위    : 지금 상호작용 대상 이름 · 짧은 상태          (+ F3 디버그 오버레이)
##   오른쪽 위  : 시계 · 일시정지 · 속도 · 메뉴(저장·설정·디버그), 그 아래 모드 글씨
##   왼쪽 아래  : 떠 있는 조이스틱 영역 (화면 왼쪽 35% × 아래 60%, 터치 입력일 때만)
##   가운데 아래: HP 바(+스테미나 자리) · 핫바 9칸 + 가방 버튼
##   오른쪽 아래: 상호작용 버튼(큰 원) · 회전 버튼 · 그 위 모드 묶음 [일반][이동][철거]
##   화면 가장자리: 이동 모드 파란 테두리 · 철거 모드 붉은 테두리
## 모든 UI는 root 하나 아래에 두고, root가 UI 확대(80~150%)와 안전 영역(노치)을 맞춰요.
## 시뮬레이션·플레이어 상태는 읽기만 하고, 바꿀 때는 main·player·factory·PlayMode의 함수를 불러요.

var main = null

const MARGIN := 16.0             # 화면 가장자리 여백
const BTN_H := 64.0              # 버튼 최소 크기 (엄지)
const ACTION_RADIUS := 72.0      # 상호작용 버튼 반지름
const ROTATE_RADIUS := 34.0
const HP_GAP := 8.0              # HP 바와 핫바 사이
const INFO_W := 0.4               # 정보창 폭 (화면 폭 비율, 가운데 왼쪽)
const INFO_GAP := 8.0              # 정보창과 인벤토리 사이 반 간격
const InfoPanel := preload("res://scripts/view/info_panel.gd")
const MSG_SEC := 2.5             # 알림 글씨가 떠 있는 시간
const REFRESH_SEC := 0.1         # 대상 이름·시계 갱신 간격
const SPEEDS := [1.0, 2.0, 4.0, 8.0]
const DebugOverlay := preload("res://scripts/view/debug_overlay.gd")
const FloatJoystick := preload("res://scripts/view/float_joystick.gd")
const ActionButton := preload("res://scripts/view/action_button.gd")
const ModeBar := preload("res://scripts/view/mode_bar.gd")
const ModeBorder := preload("res://scripts/view/mode_border.gd")
const HpBar := preload("res://scripts/view/hp_bar.gd")
const Hotbar := preload("res://scripts/view/hotbar.gd")
const InventoryPanelScene := preload("res://scenes/inventory_panel.tscn")

var settings := Settings.new()
var root: Control
var touch_mode := false

var target_label: Label
var target_panel: PanelContainer
var top_right: HBoxContainer
var clock_label: Label
var pause_btn: Button
var speed_btn: Button
var mode_label: Label
var mode_panel: PanelContainer
var toast: Label
var joystick              # float_joystick.gd (조이스틱 영역)
var action_btn            # action_button.gd
var rotate_btn            # action_button.gd (작은 원)
var mode_bar              # mode_bar.gd
var border                # mode_border.gd
var bottom_box: VBoxContainer
var hotbar
var inventory_panel
var debug_overlay
var palette: PanelContainer
var cat_box: HBoxContainer
var item_box: HBoxContainer
var current_cat := ""

var info                  # info_panel.gd (설비 정보창)
var backdrop: Control     # 정보창이 열린 동안 두 창 바깥 탭 받기
var fly_layer             # 옮겨지는 아이템 연출

var menu_panel: PanelContainer
var _menu_tabs := {}
var _menu_pages := {}
var _menu_labels := {}

var _msg_t := 0.0
var _refresh_t := 0.0


func _ready() -> void:
	settings.load_file()
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 22
	root.theme = th
	get_tree().root.theme = th
	add_child(root)
	_build_border()
	_build_joystick()
	_build_top_left()
	_build_top_right()
	_build_toast()
	_build_palette()
	_build_bottom()
	_build_action()
	_build_info()
	_build_inventory()
	_build_menu()
	fly_layer = FlyLayer.new()
	root.add_child(fly_layer)
	get_viewport().size_changed.connect(apply_layout)
	apply_layout()
	match settings.input_mode:
		"touch":
			set_touch_mode(true)
		"keyboard":
			set_touch_mode(false)
		_:
			set_touch_mode(DisplayServer.is_touchscreen_available())
	_select_category(DB.building_categories[0])


func _btn(text: String, cb: Callable, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_w, BTN_H), BTN_H)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _dark(c: PanelContainer) -> void:
	## 작은 글씨 판(대상 이름·모드·시계): 거의 불투명한 어두운 바탕이라 월드 위에서도 잘 읽혀요
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.c(Palette.INK), 0.88)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	c.add_theme_stylebox_override("panel", sb)


func _corner(c: Control, ax: float, ay: float, grow_x: int, grow_y: int, off := Vector2.ZERO) -> void:
	## c를 root의 (ax, ay) 지점(0~1)에서 off만큼 떨어진 곳에 붙여요. grow: 그 점에서 어느 쪽으로 커질지
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = off.x
	c.offset_right = off.x
	c.offset_top = off.y
	c.offset_bottom = off.y
	c.grow_horizontal = grow_x
	c.grow_vertical = grow_y


# ---------- 화면 크기 · UI 확대 · 안전 영역 ----------

func apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var tl := Vector2.ZERO
	var br := Vector2.ZERO
	if OS.has_feature("mobile"):
		# 노치·둥근 모서리: 안전 영역을 뷰포트 좌표로 바꿔 여백으로 써요
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var win := Vector2(DisplayServer.window_get_size())
		if win.x > 0 and win.y > 0 and safe.size.x > 0:
			var k := vp / win
			tl = safe.position * k
			br = (win - safe.end) * k
	var s := settings.ui_scale
	root.position = tl
	root.scale = Vector2(s, s)
	root.size = (vp - tl - br) / s


func set_touch_mode(on: bool) -> void:
	## 터치 입력이면 조이스틱 영역을 켜고, 키보드·마우스면 숨겨요 (나머지 UI는 같아요)
	touch_mode = on
	joystick.visible = on


# ---------- 왼쪽 위: 상호작용 대상 ----------

func _build_top_left() -> void:
	target_panel = PanelContainer.new()
	target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark(target_panel)
	_corner(target_panel, 0, 0, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END, Vector2(MARGIN, MARGIN))
	root.add_child(target_panel)
	target_label = Label.new()
	target_label.add_theme_font_size_override("font_size", 20)
	target_panel.add_child(target_label)
	debug_overlay = DebugOverlay.new()
	debug_overlay.factory = main.factory
	debug_overlay.position = Vector2(MARGIN, MARGIN + BTN_H)
	root.add_child(debug_overlay)


func _target_text() -> String:
	var t = main.player.shown_target()
	if t == null:
		return ""
	var st: String = t.status
	return t.name if st == "" else "%s · %s" % [t.name, st]


# ---------- 오른쪽 위: 시계 · 일시정지 · 속도 · 메뉴 / 모드 글씨 ----------

func _build_top_right() -> void:
	top_right = HBoxContainer.new()
	top_right.add_theme_constant_override("separation", 6)
	_corner(top_right, 1, 0, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END, Vector2(-MARGIN, MARGIN))
	root.add_child(top_right)
	var cp := PanelContainer.new()
	_dark(cp)
	cp.custom_minimum_size = Vector2(110, BTN_H)
	top_right.add_child(cp)
	clock_label = Label.new()
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.add_theme_font_size_override("font_size", 26)
	cp.add_child(clock_label)
	pause_btn = _btn("멈춤", _on_pause, 90)
	top_right.add_child(pause_btn)
	speed_btn = _btn("×1", _on_speed)
	top_right.add_child(speed_btn)
	top_right.add_child(_btn("메뉴", toggle_menu, 96))
	mode_panel = PanelContainer.new()
	mode_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark(mode_panel)
	_corner(mode_panel, 1, 0, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END, Vector2(-MARGIN, MARGIN + BTN_H + 6))
	root.add_child(mode_panel)
	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 18)
	mode_panel.add_child(mode_label)
	main.play_mode.changed.connect(func(_m) -> void: _refresh_mode_label())
	_refresh_mode_label()


func _refresh_mode_label() -> void:
	var m: int = main.play_mode.mode
	mode_panel.visible = m != PlayMode.Mode.NORMAL
	mode_label.text = "%s 모드" % main.play_mode.label()
	mode_label.add_theme_color_override("font_color", border.color_of(m).lightened(0.35))


func _on_pause() -> void:
	main.factory.paused = not main.factory.paused
	pause_btn.text = "재생" if main.factory.paused else "멈춤"


func _on_speed() -> void:
	var i := SPEEDS.find(main.factory.speed)
	var s: float = SPEEDS[(i + 1) % SPEEDS.size()]
	main.factory.speed = s
	speed_btn.text = "×%d" % int(s)


# ---------- 알림 · 테두리 · 조이스틱 ----------

func _build_toast() -> void:
	toast = Label.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_constant_override("outline_size", 6)
	toast.add_theme_color_override("font_outline_color", Palette.c(Palette.INK))
	_corner(toast, 0.5, 0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END, Vector2(0, MARGIN + 14))
	root.add_child(toast)


func show_message(s: String) -> void:
	toast.text = s
	_msg_t = MSG_SEC


func _build_border() -> void:
	border = ModeBorder.new()
	border.play_mode = main.play_mode
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(border)


func _build_joystick() -> void:
	joystick = FloatJoystick.new()
	joystick.anchor_left = 0.0
	joystick.anchor_right = FloatJoystick.AREA_W
	joystick.anchor_top = 1.0 - FloatJoystick.AREA_H
	joystick.anchor_bottom = 1.0
	root.add_child(joystick)


# ---------- 가운데 아래: HP · 핫바 ----------

func _build_bottom() -> void:
	bottom_box = VBoxContainer.new()
	bottom_box.alignment = BoxContainer.ALIGNMENT_END
	bottom_box.add_theme_constant_override("separation", HP_GAP)
	_corner(bottom_box, 0.5, 1, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN, Vector2(0, -MARGIN))
	bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_box)
	var hp = HpBar.new()
	hp.player = main.player
	hp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom_box.add_child(hp)
	hotbar = Hotbar.new()
	hotbar.player = main.player
	hotbar.open_bag.connect(toggle_inventory)
	bottom_box.add_child(hotbar)


# ---------- 오른쪽 아래: 상호작용 · 회전 · 모드 ----------

func _build_action() -> void:
	action_btn = ActionButton.new()
	action_btn.radius = ACTION_RADIUS
	_corner(action_btn, 1, 1, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	action_btn.offset_right = -MARGIN
	action_btn.offset_bottom = -MARGIN
	action_btn.offset_left = -MARGIN - ACTION_RADIUS * 2.0
	action_btn.offset_top = -MARGIN - ACTION_RADIUS * 2.0
	action_btn.pressed_down.connect(func() -> void: main.player.action_press())
	action_btn.released.connect(_on_action_released)
	action_btn.dragged.connect(func(off) -> void: main.build.drag(off))
	root.add_child(action_btn)
	rotate_btn = ActionButton.new()
	rotate_btn.radius = ROTATE_RADIUS
	rotate_btn.icon_kind = "rotate"
	_corner(rotate_btn, 1, 1, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	rotate_btn.offset_right = action_btn.offset_left - MARGIN
	rotate_btn.offset_left = rotate_btn.offset_right - ROTATE_RADIUS * 2.0
	rotate_btn.offset_bottom = -MARGIN
	rotate_btn.offset_top = -MARGIN - ROTATE_RADIUS * 2.0
	rotate_btn.pressed_down.connect(func() -> void: main.rotate_tool())
	root.add_child(rotate_btn)
	mode_bar = ModeBar.new()
	mode_bar.play_mode = main.play_mode
	_corner(mode_bar, 1, 1, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN, Vector2(-MARGIN, action_btn.offset_top - MARGIN))
	root.add_child(mode_bar)


func _on_action_released() -> void:
	## 설치 모드였다면: 가운데 취소 X 위에서 떼면 취소, 아니면 설치
	if main.build.active:
		main.build.release(action_btn.in_cancel_zone())
	main.player.action_release()


func _action_icon() -> Array:
	## [아이콘, 색] 모드와 손에 든 것에 따라
	match main.play_mode.mode:
		PlayMode.Mode.MOVE:
			return ["move", Palette.BLUE_D]
		PlayMode.Mode.DECONSTRUCT:
			return ["crowbar", Palette.RED_D]
	var held: String = main.player.held_id()
	if held == "":
		return ["fist", -1]
	if held.begins_with("[설비]"):
		return ["hammer", -1]
	return ["hand", -1]


func rotate_visible() -> bool:
	## 설비를 들었거나 설치 도구일 때만 (옮기는 중은 9단계)
	return main.player.held_id().begins_with("[설비]") or main.tool == "build"


# ---------- 매 프레임 ----------

func _process(dt: float) -> void:
	var ic := _action_icon()
	action_btn.set_icon(ic[0], ic[1])
	action_btn.cancel_mode = main.build.active
	rotate_btn.visible = rotate_visible() and not info_open()
	if _msg_t > 0.0:
		_msg_t -= dt
		toast.modulate.a = clampf(_msg_t / 0.5, 0.0, 1.0)
	_refresh_t -= dt
	if _refresh_t > 0.0:
		return
	_refresh_t = REFRESH_SEC
	var f = main.factory
	clock_label.text = GameClock.text(f.sim_time)
	var tt := _target_text()
	target_panel.visible = tt != ""
	target_label.text = tt


func is_over_ui(p: Vector2) -> bool:
	for c in [top_right, palette, hotbar, action_btn, rotate_btn, mode_bar, backdrop, info, inventory_panel, menu_panel, joystick]:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false


# ---------- 인벤토리 ----------

func _build_inventory() -> void:
	inventory_panel = InventoryPanelScene.instantiate()
	inventory_panel.player = main.player
	root.add_child(inventory_panel)
	main.player.request_info.connect(_on_player_info)
	main.player.message.connect(show_message)


func toggle_inventory() -> void:
	## 정보창이 열려 있으면 E는 둘 다 닫기, 아니면 가방만 화면 가운데에
	if info_open():
		close_info()
	else:
		inventory_panel.toggle("center")


func close_inventory() -> bool:
	if info_open():
		close_info()
		return true
	if inventory_panel.visible:
		inventory_panel.close()
		return true
	return false


func _on_player_info(b) -> void:
	open_info(b)


# ---------- 설치 팔레트 (디버그: 크리에이티브식 자유 설치) ----------

func _build_palette() -> void:
	palette = PanelContainer.new()
	_corner(palette, 0.5, 0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END, Vector2(0, MARGIN + BTN_H + 40))
	root.add_child(palette)
	var v := VBoxContainer.new()
	palette.add_child(v)
	cat_box = HBoxContainer.new()
	v.add_child(cat_box)
	for c in DB.building_categories:
		var b := _btn(c, _select_category.bind(c), 120)
		b.toggle_mode = true
		cat_box.add_child(b)
	cat_box.add_child(_btn("닫기", toggle_palette, 90))
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, BTN_H + 8)
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(s)
	item_box = HBoxContainer.new()
	s.add_child(item_box)
	palette.visible = false


func toggle_palette() -> void:
	palette.visible = not palette.visible
	if not palette.visible and main.tool == "build":
		main.set_tool("view")


func _select_category(c: String) -> void:
	current_cat = c
	for b in cat_box.get_children():
		b.button_pressed = (b.text == c)
	for ch in item_box.get_children():
		ch.queue_free()
	for n in DB.buildings_in(c):
		var b := _btn(n, main.select_build.bind(n), 0)
		b.tooltip_text = DB.buildings[n].get("desc", "")
		item_box.add_child(b)


func refresh_tool_buttons() -> void:
	if main.tool != "view":
		close_info()


# ---------- 메뉴: 저장 · 설정 · 디버그 ----------

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	_corner(menu_panel, 0.5, 0.5, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	root.add_child(menu_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	menu_panel.add_child(v)
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for t in ["저장", "설정", "디버그"]:
		var b := _btn(t, _show_menu_page.bind(t), 120)
		b.toggle_mode = true
		tabs.add_child(b)
		_menu_tabs[t] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	tabs.add_child(_btn("닫기", toggle_menu, 90))
	_menu_page(v, "저장", [
		["저장 (Ctrl+S)", _menu_call.bind(main.save_game)],
		["불러오기", _menu_call.bind(main.load_game)],
	])
	_menu_page(v, "설정", [
		["UI 작게", _on_ui_scale.bind(-1)],
		["UI 크게", _on_ui_scale.bind(1)],
		["ui_scale", Callable()],
		["input_mode", _on_input_mode],
	])
	_menu_page(v, "디버그", [
		["F3 디버그 오버레이", toggle_debug],
		["creative", _on_creative],
		["storage", _on_storage_toggle],
		["설치 팔레트", _menu_call.bind(toggle_palette)],
		["층 보기 (전선·파이프)", _on_layers],
		["예시 불러오기", _menu_call.bind(main.new_room.bind(true))],
		["비우기", _menu_call.bind(main.clear_room)],
	])
	menu_panel.visible = false
	_show_menu_page("저장")


func _menu_page(parent: Control, page: String, items: Array) -> void:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	parent.add_child(g)
	_menu_pages[page] = g
	for it in items:
		var key: String = it[0]
		var b := _btn(key, it[1] if it[1].is_valid() else func() -> void: pass, 320)
		if not it[1].is_valid():
			b.disabled = true
		g.add_child(b)
		_menu_labels[key] = b
	_refresh_menu_labels()


func _show_menu_page(page: String) -> void:
	for p in _menu_pages:
		_menu_pages[p].visible = p == page
		_menu_tabs[p].set_pressed_no_signal(p == page)
	_refresh_menu_labels()


func _refresh_menu_labels() -> void:
	if _menu_labels.has("ui_scale"):
		_menu_labels["ui_scale"].text = "UI 크기 %d%%" % int(round(settings.ui_scale * 100.0))
	if _menu_labels.has("input_mode"):
		var names := {"auto": "자동 (터치·키보드)", "touch": "터치", "keyboard": "키보드·마우스"}
		_menu_labels["input_mode"].text = "조작: %s" % names[settings.input_mode]
	if _menu_labels.has("creative"):
		_menu_labels["creative"].text = "크리에이티브: %s" % ("켬" if main.factory.creative else "끔")
	if _menu_labels.has("storage") and inventory_panel != null:
		_menu_labels["storage"].text = "크리에이티브 보관함: %s" % ("켬" if inventory_panel.creative_enabled else "끔")


func _menu_call(cb: Callable) -> void:
	cb.call()
	menu_panel.visible = false


func toggle_menu() -> void:
	menu_panel.visible = not menu_panel.visible
	_refresh_menu_labels()


func close_menu() -> bool:
	if menu_panel.visible:
		menu_panel.visible = false
		return true
	return false


func toggle_debug() -> void:
	debug_overlay.toggle()


func _on_ui_scale(dir: int) -> void:
	settings.step_scale(dir)
	apply_layout()
	_refresh_menu_labels()


func _on_input_mode() -> void:
	settings.next_input_mode()
	if settings.input_mode == "touch":
		set_touch_mode(true)
	elif settings.input_mode == "keyboard":
		set_touch_mode(false)
	_refresh_menu_labels()


func _on_creative() -> void:
	main.toggle_creative()
	_refresh_menu_labels()


func _on_storage_toggle() -> void:
	inventory_panel.set_creative(not inventory_panel.creative_enabled)
	_refresh_menu_labels()


func _on_layers() -> void:
	main.view.show_layers = not main.view.show_layers


# ---------- 설비 정보창 + 인벤토리 (함께 열려요) ----------

func _build_info() -> void:
	# 두 창 바깥을 탭하면 닫혀요
	backdrop = Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	backdrop.visible = false
	root.add_child(backdrop)
	info = InfoPanel.new()
	info.hud = self
	info.player = main.player
	info.factory = main.factory
	info.anchor_left = 0.5 - INFO_W
	info.anchor_right = 0.5
	info.anchor_top = 0.0
	info.anchor_bottom = 1.0
	info.offset_left = 0
	info.offset_right = -INFO_GAP
	info.offset_top = MARGIN + BTN_H + 12
	info.offset_bottom = -MARGIN
	info.closed.connect(_on_info_closed)
	root.add_child(info)


func open_info(b) -> void:
	info.inv_panel = inventory_panel
	info.open(b)
	main.view.selected = b
	backdrop.visible = true
	inventory_panel.set_transfer(info)
	inventory_panel.open("beside")
	_set_play_hud(false)


func close_info() -> void:
	if info.visible:
		info.close()   # → _on_info_closed


func info_open() -> bool:
	return info.visible


func _on_info_closed() -> void:
	backdrop.visible = false
	inventory_panel.set_transfer(null)
	inventory_panel.close()
	main.view.selected = null
	_set_play_hud(true)


func _on_backdrop_input(e: InputEvent) -> void:
	var down: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if down:
		close_info()


func _set_play_hud(on: bool) -> void:
	## 정보창이 열린 동안은 핫바·조이스틱·상호작용·모드 버튼을 숨겨요
	bottom_box.visible = on
	joystick.visible = on and touch_mode
	action_btn.visible = on
	mode_bar.visible = on
	if not on:
		rotate_btn.visible = false


# ---------- 옮겨지는 아이템 연출 ----------

class FlyLayer extends Control:
	## 아이템이 칸에서 칸으로 날아가는 짧은 연출 (+ 옮긴 개수)
	const SEC := 0.3
	const ICON := 40.0
	var flights: Array = []   # {id, a, b, t, n}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func add(id: String, a: Vector2, b: Vector2, n: int) -> void:
		var inv := get_global_transform().affine_inverse()
		flights.append({"id": id, "a": inv * a, "b": inv * b, "t": 0.0, "n": n})

	func _process(dt: float) -> void:
		if flights.is_empty():
			return
		for f in flights:
			f["t"] += dt
		flights = flights.filter(func(f) -> bool: return f["t"] < SEC)
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for f in flights:
			var k: float = clampf(f["t"] / SEC, 0.0, 1.0)
			var p: Vector2 = f["a"].lerp(f["b"], k) - Vector2(0, sin(PI * k) * 30.0)
			var tex := Art.item_icon(f["id"], 16)
			draw_texture_rect(tex, Rect2(p - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON)), false)
			if int(f["n"]) > 1:
				var txt := "×%d" % int(f["n"])
				draw_string_outline(font, p + Vector2(12, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Palette.c(Palette.INK))
				draw_string(font, p + Vector2(12, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.c(Palette.PAPER))


func fly(id: String, from_rect: Rect2, to_rect: Rect2, n: int) -> void:
	fly_layer.add(id, from_rect.get_center(), to_rect.get_center(), n)
