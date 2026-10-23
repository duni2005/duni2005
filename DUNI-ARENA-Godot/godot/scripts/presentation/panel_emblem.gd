class_name PanelEmblem
extends Control
## Quiet watermark behind a page panel so its empty space reads as designed. "room" puts a faint
## room emblem with ornament lines low in the panel; "result" turns a slow ray fan behind the title.
var icon: String = "battle"
var caption: String = ""
var tint: Color = Color("c9b27a")
var mode: String = "room"
var age: float = 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;set_process(UiMotion.enabled)
func _process(dt: float) -> void:
	age += dt;queue_redraw()
func _draw() -> void:
	if mode == "result":_draw_result();return
	if size.y < 300:return
	var r: float = minf(size.x, size.y) * .19;var c := Vector2(size.x * .5, size.y - r * 1.9)
	VfxArt.glow(self, c, r * 2.4, tint, .05 + .02 * sin(age * .8))
	draw_arc(c, r * 1.12, 0, TAU, 72, Color(tint, .08), 1.5, true)
	draw_arc(c, r * 1.3, age * .06, age * .06 + TAU * .78, 72, Color(tint, .05), 1, true)
	ArenaIcon.draw(self, c, icon, r * 1.25, Color(1, 1, 1, .08))
	for side in [-1, 1]:
		var inner := Vector2(c.x + side * r * 1.5, c.y);var outer := Vector2(c.x + side * (size.x * .5 - 22), c.y)
		draw_line(inner, outer, Color(tint, .09), 1)
		draw_colored_polygon(PackedVector2Array([outer + Vector2(0, -3), outer + Vector2(3 * side, 0), outer + Vector2(0, 3), outer - Vector2(3 * side, 0)]), Color(tint, .14))
	if not caption.is_empty():
		draw_string(get_theme_default_font(), Vector2(0, c.y + r * 1.75), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(tint, .22))
func _draw_result() -> void:
	var c := Vector2(size.x * .5, size.y * .36);var reach: float = maxf(size.x, size.y) * .7
	VfxArt.glow(self, c, minf(size.x, size.y) * .55, tint, .1 + .03 * sin(age * 1.2))
	for i in range(14):
		var a: float = i * TAU / 14 + age * .05
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * reach, c + Vector2.from_angle(a + .07) * reach]), Color(tint, .025))
	draw_arc(c, 92, 0, TAU, 72, Color(tint, .1), 1.5, true)
