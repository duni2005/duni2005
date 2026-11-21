class_name TrialPopup
extends RefCounted
## A small panel beside a tapped 시련 icon or 불리 mark: name, kind and description of each trial.
## Taps outside close it.

## Shows `trials` (one or more ids) next to `at` (global position) over `host`'s window.
static func show(host: Control, trials: Array, at: Vector2, heading: String = "") -> PopupPanel:
	var popup := PopupPanel.new();popup.theme = ArenaUI.get_theme()
	popup.add_theme_stylebox_override("panel", ArenaUI.window_style())
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 6);popup.add_child(column)
	var width: float = minf(290, host.get_viewport_rect().size.x - 24)
	if not heading.is_empty():
		var top := Label.new();top.text = heading;top.add_theme_font_size_override("font_size", 12);top.add_theme_color_override("font_color", ArenaUI.DANGER);column.add_child(top)
	for id in trials:
		var name := Label.new();name.text = "%s · %s" % [TrialCatalog.name_of(id), TrialCatalog.KIND_NAMES.get(TrialCatalog.kind_of(id), "")]
		name.add_theme_font_override("font", ArenaUI.heading_font());name.add_theme_font_size_override("font_size", 15);name.add_theme_color_override("font_color", TrialCatalog.color_of(id));column.add_child(name)
		var text := Label.new();text.text = str(TrialCatalog.info(id).get("text", ""));text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;text.custom_minimum_size.x = width - 24
		text.add_theme_font_size_override("font_size", 12);text.add_theme_color_override("font_color", Color("dfe6f6"));column.add_child(text)
	host.get_window().add_child(popup)
	popup.reset_size()
	var size: Vector2 = Vector2(popup.size)
	var view: Vector2 = host.get_viewport_rect().size
	var pos := Vector2(clampf(at.x - size.x * .5, 12, view.x - size.x - 12), clampf(at.y + 18, 12, view.y - size.y - 12))
	popup.popup(Rect2i(Vector2i(pos), Vector2i(size)))
	popup.popup_hide.connect(popup.queue_free)
	return popup
