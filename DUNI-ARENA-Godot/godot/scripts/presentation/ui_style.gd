class_name ArenaUI
extends RefCounted
## Shared presentation vocabulary. No domain/RNG/state mutation.
const BACKGROUND=Color("0a0e18")
const PANEL=Color("131a2b")
const SURFACE=Color("1b2338")
const BORDER=Color("36446a")
const ACCENT=Color("ffb15c")
const GOLD=Color("ffd98c")
const MUTED=Color("9aa5c2")
const DANGER=Color("ff8088")
const HP=Color("86e3a4")
const STANCE_NAMES={&"normal":"기본",&"cautious":"신중함",&"rush":"저돌적",&"cover":"엄호"}
const STANCE_HELP={&"normal":"균형 잡힌 기본 전투 성향",&"cautious":"위험을 살피며 신중하게 교전합니다.",&"rush":"공격을 적극적으로 시도합니다.",&"cover":"아군을 엄호하는 위치를 선택합니다."}
static var shared_theme: Theme
static var pip_on: StyleBoxFlat
static var pip_off: StyleBoxFlat
static var body_font: Font
static var title_font: Font
static var condensed_font: Font
static func heading_font() -> Font:
	if title_font==null:
		var f:=FontVariation.new();f.base_font=load("res://assets/ui/fonts/korean.otf");f.variation_embolden=.45;title_font=f
	return title_font
static func numbers_font() -> Font:
	if condensed_font==null:condensed_font=load("res://assets/ui/fonts/BarlowCondensed-ExtraBold.ttf")
	return condensed_font
static func android_logical_size(physical: Vector2i,dpi: int) -> Vector2i:
	# Android reports physical window pixels; controls are authored in dp.
	# Keep the same logical touch area as Web CSS pixels at high density.
	var density: float=clampf(float(dpi)/160.0,1.0,4.0)
	return Vector2i(maxi(1,roundi(physical.x/density)),maxi(1,roundi(physical.y/density)))
static func fit_window(window: Window) -> Vector2i:
	# Web Window.size is the backing buffer (CSS size * devicePixelRatio).
	# Breakpoints and touch targets must use CSS pixels, while canvas_items keeps
	# the high-resolution buffer for sharp text and correct input transforms.
	var logical: Vector2i=window.size
	if OS.has_feature("web"):
		var css_w=JavaScriptBridge.eval("window.innerWidth");var css_h=JavaScriptBridge.eval("window.innerHeight")
		# A page whose CSP forbids eval returns null; derive CSS pixels from the buffer instead.
		if css_w==null or css_h==null:logical=Vector2i((Vector2(window.size)/maxf(1,DisplayServer.screen_get_scale())).round())
		else:logical=Vector2i(maxi(1,int(css_w)),maxi(1,int(css_h)))
		window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	elif OS.has_feature("android"):
		logical=android_logical_size(window.size,DisplayServer.screen_get_dpi())
		window.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	if window.content_scale_size!=logical:window.content_scale_size=logical
	return logical
static func page_rect(node: Node) -> Rect2i:
	# Full-page dialogs open at their final rect, so they never jump after the first frames.
	var root: Window=node.get_tree().root
	return Rect2i(Vector2i.ZERO,root.content_scale_size if root.content_scale_size!=Vector2i.ZERO else root.size)
static func touch_ui() -> bool:
	return DisplayServer.is_touchscreen_available()
static func is_held(button: BaseButton) -> bool:
	# Finger (or mouse) is down on the button right now, and the gesture has not become a scroll.
	if button.disabled or button.get_meta("drag_canceled",false):return false
	var mode: int=button.get_draw_mode()
	return (mode==BaseButton.DRAW_PRESSED or mode==BaseButton.DRAW_HOVER_PRESSED) and not (button.toggle_mode and button.button_pressed)
static func pip_style(on: bool) -> StyleBoxFlat:
	if pip_on==null:pip_on=box(GOLD,GOLD);pip_off=box(Color("26304a"),Color("26304a"));pip_on.set_corner_radius_all(1);pip_off.set_corner_radius_all(1)
	return pip_on if on else pip_off
static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal",button_box(ACCENT,Color("efbc8f")))
	button.add_theme_stylebox_override("hover",button_box(Color("ffc49b"),Color("ffdab6")) if not touch_ui() else button.get_theme_stylebox("normal"))
	button.add_theme_stylebox_override("pressed",button_box(Color("d98b53"),Color("ffce9f")))
	for name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(name,Color("29211b"))
static func danger(button: Button) -> void:
	for state in ["normal","hover","pressed","disabled"]:
		button.add_theme_stylebox_override(state,button_box(Color("49303b") if state!="disabled" else Color("2d2630"),Color("a36d79") if state!="disabled" else Color("71505e")))
	for name in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:button.add_theme_color_override(name,DANGER)
static func button_box(color: Color,border: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat=box(color,border);return s
static func box(color: Color,border: Color=Color("36446a")) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border
	s.set_border_width_all(1);s.set_corner_radius_all(7)
	s.content_margin_left=8;s.content_margin_right=8;s.content_margin_top=5;s.content_margin_bottom=5
	return s
static func get_theme() -> Theme:
	if shared_theme!=null:return shared_theme
	shared_theme=Theme.new();shared_theme.default_font_size=14
	body_font=load("res://assets/ui/fonts/korean.otf");shared_theme.default_font=body_font
	shared_theme.set_stylebox("panel","PanelContainer",box(PANEL))
	shared_theme.set_stylebox("panel","AcceptDialog",box(PANEL,BORDER))
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var color: Color=Color("232d4a") if state=="normal" else Color("2c385c") if state=="hover" else Color("51432d") if state in ["pressed","hover_pressed"] else Color("191c28")
		shared_theme.set_stylebox(state,"Button",button_box(color,Color("ebc27a") if state in ["pressed","hover_pressed","focus"] else Color("4a3f58") if state=="disabled" else Color("56669c")))
	var focus:=box(Color.TRANSPARENT,ACCENT);focus.draw_center=false;shared_theme.set_stylebox("focus","Button",focus)
	if touch_ui():
		# No hover on touch: a tapped button must not stay highlighted, nor keep a focus ring.
		shared_theme.set_stylebox("hover","Button",shared_theme.get_stylebox("normal","Button"));shared_theme.set_stylebox("focus","Button",StyleBoxEmpty.new())
	shared_theme.set_type_variation("ArenaCard","Button")
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:shared_theme.set_stylebox(state,"ArenaCard",StyleBoxEmpty.new())
	# Native text is accessibility metadata; the authored card draws all visible type.
	shared_theme.set_font_size("font_size","ArenaCard",1)
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color","font_hover_pressed_color"]:shared_theme.set_color(state,"ArenaCard",Color.TRANSPARENT)
	shared_theme.set_color("font_color","Label",Color("eef1fa"))
	shared_theme.set_color("font_color","Button",Color("eef1fa"))
	shared_theme.set_color("font_disabled_color","Button",DANGER)
	shared_theme.set_color("font_pressed_color","Button",Color("e6eff7"))
	shared_theme.set_constant("separation","VBoxContainer",6);shared_theme.set_constant("separation","HBoxContainer",6)
	shared_theme.set_constant("h_separation","HFlowContainer",8);shared_theme.set_constant("v_separation","HFlowContainer",6)
	return shared_theme
static func install(root: Control) -> void:
	if root.is_inside_tree():root.get_window().title="DUNI ARENA"
	root.theme=get_theme()
	if root.get_node_or_null("PresentationBackground")==null:
		var bg:=ColorRect.new();bg.name="PresentationBackground";bg.color=BACKGROUND;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg);root.move_child(bg,0)
static func safe_margin(margin: MarginContainer) -> void:
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,10 if side in ["top","bottom"] else 8)
	if DisplayServer.get_name()!="headless":
		var safe: Rect2i=DisplayServer.get_display_safe_area()
		# Full-page dialogs are embedded subwindows; the device insets belong to the app's root window.
		var window: Window=margin.get_tree().root if margin.is_inside_tree() else margin.get_window()
		if safe.size.x>0 and window.mode==Window.MODE_FULLSCREEN:
			var scale: Vector2=Vector2(window.content_scale_size)/Vector2(window.size)
			margin.add_theme_constant_override("margin_top",maxi(16,int((safe.position.y-window.position.y)*scale.y)))
			margin.add_theme_constant_override("margin_bottom",maxi(16,int((window.position.y+window.size.y-safe.end.y)*scale.y)))
static func number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value,roundf(value)) else "%.1f"%value
static func grouped(value: int) -> String:
	var text: String=str(value);var out: String=""
	for i in range(text.length()):
		if i>0 and (text.length()-i)%3==0:out+=","
		out+=text[i]
	return out
static func hp(value: float,maximum: float) -> String:return "%d / %d"%[ceili(value),ceili(maximum)]
static func member_label(id: String) -> String:return "#%d"%int(id.trim_prefix("member_"))
static func stance(value: StringName) -> String:return STANCE_NAMES.get(value,String(value))
static func nav_button(kind: String,callback: Callable) -> ArenaCard:
	var button:=ArenaCard.new();button.card_type="nav";button.kind=kind
	button.text={"guild":"유닛 / 인벤토리","menu":"메뉴","close":"닫기"}.get(kind,kind)
	button.tooltip_text=button.text;button.custom_minimum_size=Vector2(44,44)
	bind(button,callback);return button
static func room_title(room: RoomState) -> String:
	var label: String={&"promotion":"승급",&"hotSpring":"온천",&"supply":"보물상자",&"prediction":"전투 예측"}.get(room.event_type,RoomType.LABELS[room.room_type])
	return "%d층 · %d번 방 · %s"%[room.floor_index+1,room.lane+1,label]
static func bind(button: Button,callback: Callable) -> void:
	button.custom_minimum_size.y=maxf(44,button.custom_minimum_size.y)
	button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.mouse_filter=Control.MOUSE_FILTER_PASS
	if not button.has_meta("tap_hooked"):
		button.set_meta("tap_hooked",true);button.set_meta("tap_origin",Vector2.ZERO);button.set_meta("drag_canceled",false)
		button.gui_input.connect(_button_input.bind(button))
		button.tree_entered.connect(func():_scroll_position(button,true))
	if button.is_inside_tree():_scroll_position(button,true)
	if button.has_meta("bound_action") and button.pressed.is_connected(button.get_meta("bound_action")):button.pressed.disconnect(button.get_meta("bound_action"))
	var action: Callable=func():
		# A real touch owns its gesture. Ignore the synthesized mouse release,
		# including the native Button's second toggle, without a timer/click delay.
		if not button.get_meta("touch_dispatch",false) and button.get_meta("touch_owned",false):
			if button.toggle_mode:button.set_pressed_no_signal(button.get_meta("touch_toggle",button.button_pressed));button.queue_redraw()
			return
		if button.get_meta("drag_canceled",false) or (not button.get_meta("touch_dispatch",false) and button.get_meta("action_frame",-1)==Engine.get_process_frames()):return
		button.set_meta("action_frame",Engine.get_process_frames());button.get_tree().root.set_meta("action_point",control_center(button))
		if OS.has_feature("mobile"):Input.vibrate_handheld(12)
		callback.call()
	button.set_meta("bound_action",action);button.pressed.connect(action)
static func _scroll_position(button: Control,tune: bool=false) -> Vector2:
	var result:=Vector2.ZERO;var parent: Node=button.get_parent()
	while parent!=null:
		if parent is ScrollContainer:
			if tune:parent.scroll_deadzone=maxi(18,parent.scroll_deadzone)
			result+=Vector2(parent.scroll_horizontal,parent.scroll_vertical)
		parent=parent.get_parent()
	return result
static func _button_input(event: InputEvent,button: Button) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if button.disabled or button.has_meta("touch_index"):return
			button.set_meta("touch_index",event.index);button.set_meta("tap_origin",event.position);button.set_meta("scroll_origin",_scroll_position(button));button.set_meta("drag_canceled",false);button.set_meta("touch_owned",true);button.set_meta("touch_initial",button.button_pressed);button.set_meta("touch_toggle",button.button_pressed)
		elif button.get_meta("touch_index",-1)==event.index:
			button.remove_meta("touch_index")
			var valid: bool=not event.canceled and not button.disabled and not button.get_meta("drag_canceled",false) and event.position.distance_to(button.get_meta("tap_origin"))<=18 and _scroll_position(button).distance_to(button.get_meta("scroll_origin"))<4 and Rect2(Vector2.ZERO,button.size).has_point(event.position)
			if valid:
				if button.toggle_mode:button.set_pressed_no_signal(not bool(button.get_meta("touch_initial")))
				button.set_meta("touch_toggle",button.button_pressed);button.set_meta("touch_dispatch",true);button.pressed.emit();button.set_meta("touch_dispatch",false);button.queue_redraw()
			else:button.set_meta("touch_toggle",button.button_pressed)
			button.accept_event()
	elif event is InputEventScreenDrag and button.get_meta("touch_index",-1)==event.index:
		if event.position.distance_to(button.get_meta("tap_origin"))>18:button.set_meta("drag_canceled",true);button.queue_redraw()
	elif event is InputEventMouseButton and event.device!=-1 and event.pressed:
		button.set_meta("touch_owned",false);button.set_meta("tap_origin",event.position);button.set_meta("drag_canceled",false)
	elif event is InputEventKey and event.pressed:button.set_meta("touch_owned",false);button.set_meta("drag_canceled",false)
	elif event is InputEventMouseMotion and event.device!=-1 and event.button_mask!=0:
		if event.position.distance_to(button.get_meta("tap_origin"))>18:button.set_meta("drag_canceled",true)
static func reason(code: String) -> String:
	return {"OUTSIDE_DEPLOYMENT_ZONE":"강조된 배치 영역 안을 선택하세요.","TOO_CLOSE":"다른 유닛과 최소 58만큼 거리를 두세요.","DEAD_MEMBER":"사망한 길드원은 배치할 수 없습니다.","ALREADY_DEPLOYED":"이미 배치된 길드원입니다. 위치를 옮길 수 있습니다.","INVALID_POSITION":"유효한 전장 위치를 선택하세요.","INSUFFICIENT_GOLD":"골드가 부족합니다.","INSUFFICIENT_TOKENS":"토큰이 부족합니다.","NO_EFFECT":"현재 대상에게 효과가 없습니다.","INVALID_TARGET":"살아 있는 아군을 선택하세요.","NOT_AVAILABLE":"이번 층에서 사용할 수 없습니다.","UNAVAILABLE":"사용 기록 또는 쿨타임 때문에 사용할 수 없습니다.","NOT_HOLD":"전투가 완전히 정지한 뒤 사용할 수 있습니다.","DUPLICATE":"이미 적용된 카드입니다.","NOT_PAUSED":"터닝포인트 정지 중에 사용할 수 있습니다."}.get(code,code.replace("_"," ").to_lower())

static func plain(value: String) -> String:
	var out: String=""
	for i in range(value.length()):
		var code: int=value.unicode_at(i)
		if code>=0x1F000 or code==0xFE0F or code==0x200D:continue
		out+=value[i]
	return out.strip_edges()

static func dialog_header(window: AcceptDialog,column: VBoxContainer,title: String) -> Button:
	window.borderless=true;window.get_ok_button().hide()
	var row:=HBoxContainer.new();column.add_child(row);column.move_child(row,0)
	var label:=Label.new();label.text=title;label.add_theme_font_override("font",heading_font());label.add_theme_font_size_override("font_size",18);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
	var close:=Button.new();close.text="×";close.tooltip_text="닫기";close.custom_minimum_size=Vector2(44,44);close.add_theme_font_size_override("font_size",23)
	for state in ["normal","pressed"]:close.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	close.add_theme_stylebox_override("hover",box(Color("1f2a44"),Color.TRANSPARENT));row.add_child(close);bind(close,window.hide)
	return close

static func with_icon(button: Button,kind: String,width: int=16,right: bool=false) -> void:
	button.icon=ArenaIcon.texture(kind);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",width)
	button.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT

static func control_center(control: Control) -> Vector2:
	var point: Vector2=control.get_global_rect().get_center()
	var viewport: Viewport=control.get_viewport()
	if viewport is Window and viewport!=control.get_tree().root:point+=Vector2(viewport.position)
	return point
