extends Node
## Autoload: gives every button press feedback, every dialog a pop-in and every screen an entrance.
func _ready() -> void:
	if not UiMotion.enabled:return
	get_tree().node_added.connect(_added)
	var layer := CanvasLayer.new();layer.layer = 1200;add_child(layer);UiTransition.layer = layer
func _added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("motion_hooked"):
		n.set_meta("motion_hooked", true)
		n.button_down.connect(UiMotion.press.bind(n));n.button_up.connect(UiMotion.release.bind(n))
		n.mouse_entered.connect(UiMotion.hover.bind(n, true));n.mouse_exited.connect(UiMotion.hover.bind(n, false))
		_maybe_breathe.call_deferred(n)
	elif n is AcceptDialog:
		n.about_to_popup.connect(func():UiMotion.dialog_opened(n))
	elif n is MainMenuScreen or n is TowerContentScreen or n is TowerBattleScreen or n is CustomBattleScreen:
		UiMotion.enter.call_deferred(n)
func _maybe_breathe(b: BaseButton) -> void:
	if is_instance_valid(b) and b.get_meta("primary_cta", false):UiMotion.breathe(b)
