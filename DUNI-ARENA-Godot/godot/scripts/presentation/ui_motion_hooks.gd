extends Node
## Autoload: gives every button press feedback, every dialog a pop-in and every screen an entrance.
func _ready() -> void:
	GameSettings.load_settings()
	if DisplayServer.get_name() == "headless":return
	get_tree().node_added.connect(_added)
	var layer := CanvasLayer.new();layer.layer = 1200;add_child(layer);UiTransition.layer = layer
	add_child(DragScroll.new())
func _added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("motion_hooked"):
		n.set_meta("motion_hooked", true)
		n.button_down.connect(UiMotion.press.bind(n));n.button_up.connect(UiMotion.release.bind(n))
		n.button_down.connect(func():n.set_meta("motion_down_ms", Time.get_ticks_msec()))
		n.mouse_entered.connect(UiMotion.hover.bind(n, true));n.mouse_exited.connect(UiMotion.hover.bind(n, false))
		_maybe_breathe.call_deferred(n)
		# Bounce only for toggles the player just pressed, not ones set by a re-render.
		n.toggled.connect(func(on: bool):if on and Time.get_ticks_msec()-int(n.get_meta("motion_down_ms", -99999))<1500:UiMotion.bump(n))
	elif n is ScrollContainer:
		n.add_to_group(DragScroll.GROUP)
		n.get_v_scroll_bar().value_changed.connect(func(_v):UiMotion.scrolled.call_deferred(n, true))
		n.get_h_scroll_bar().value_changed.connect(func(_v):UiMotion.scrolled.call_deferred(n, false))
	elif n is AcceptDialog:
		n.about_to_popup.connect(func():UiMotion.dialog_opened(n))
	if n is Window and not n.has_meta("drag_scroll"):
		# Each window routes its own touches, so each gets its own drag scroller.
		n.set_meta("drag_scroll",true);n.add_child.call_deferred(DragScroll.new())
	elif n is MainMenuScreen or n is TowerContentScreen or n is TowerBattleScreen or n is CustomBattleScreen:
		UiMotion.enter.call_deferred(n)
func _maybe_breathe(b: BaseButton) -> void:
	if is_instance_valid(b) and b.get_meta("primary_cta", false):UiMotion.breathe(b)
