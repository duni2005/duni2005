class_name ButtonShine
extends Control
## A slanted light streak that crosses its parent button every Motion.SHINE_EVERY seconds.
## Redraws only while the streak is crossing; nothing at all while the button is disabled.
var clock: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clock = Motion.SHINE_EVERY - .6

func _process(dt: float) -> void:
	var button := get_parent() as BaseButton
	if button == null or button.disabled or not is_visible_in_tree():clock = 0;return
	var was: bool = clock < Motion.SHINE
	clock = fposmod(clock + dt, Motion.SHINE_EVERY)
	if clock < Motion.SHINE or was:queue_redraw()

func _draw() -> void:
	if clock >= Motion.SHINE:return
	# Inset by the corner radius so the streak never spills past the rounded corners.
	var inset: float = ArenaUI.RADIUS_BUTTON * .3
	TypeArt.sweep(self, Rect2(Vector2(inset, 1), size - Vector2(inset * 2, ArenaUI.LIP + 2)), clock / Motion.SHINE, .32, 22)
