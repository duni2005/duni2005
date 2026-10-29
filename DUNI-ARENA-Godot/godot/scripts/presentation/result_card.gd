class_name ResultCard
extends Control
## Finished-room result page: ray fan and medallion with the outcome icon, title, detail line,
## optional unit icons (e.g. the predicted team) and reward chips. Fills the room panel.
var icon: String = "star"
var title: String = ""
var detail: String = ""
var accent: Color = ArenaUI.GOLD
var types: Array[int] = []
var types_caption: String = ""
var chips: Array[String] = []
var age: float = 0
## Room above the medallion's centre, for the medallion and its orbit.
const ABOVE: float = 70

## Height from the medallion's centre to the bottom of the last line.
func _below() -> float:
	var h: float = 152
	if not detail.is_empty():h += 22 * (1 + detail.count("\n")) + 12
	if not types.is_empty():h += 58 + (10 if not types_caption.is_empty() else 0)
	if not chips.is_empty():h += 36
	return h

func _ready() -> void:
	# Tall enough for exactly what it shows, so a finished room never needs scrolling.
	mouse_filter = Control.MOUSE_FILTER_IGNORE;custom_minimum_size.y = ABOVE + _below() + 8;size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not UiMotion.enabled:age = 10
	set_process(UiMotion.enabled)

func _process(dt: float) -> void:
	age += dt;queue_redraw()

func _draw() -> void:
	var font: Font = ArenaUI.heading_font();var text_font: Font = get_theme_default_font()
	var c := Vector2(size.x * .5, maxf(ABOVE, minf(clampf(size.y * .3, 96, 190), size.y - _below() - 8)));var reach: float = maxf(size.x, size.y) * .75
	var pop: float = clampf(age / .5, 0, 1);var k: float = 1 + 2.2 * pow(pop - 1, 3) + 1.2 * pow(pop - 1, 2) if pop < 1 else 1.0
	var show: float = clampf((age - .25) / .4, 0, 1)
	# Rays and glow behind the medallion.
	VfxArt.glow(self, c, minf(size.x, size.y) * .5, accent, (.12 + .03 * sin(age * 1.4)) * pop)
	for i in range(16):
		var a: float = i * TAU / 16 + age * .06
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a) * reach, c + Vector2.from_angle(a + .08) * reach]), Color(accent, .035 * pop))
	# Medallion.
	var r: float = 52 * k
	draw_circle(c, r + 8, Color(accent, .08));draw_circle(c, r, Color("0d1424"))
	draw_arc(c, r, 0, TAU, 64, Color(accent, .95), 3, true);draw_arc(c, r - 7, 0, TAU, 64, Color(accent, .3), 1, true)
	draw_arc(c, r + 16, age * .5, age * .5 + PI * .6, 32, Color(accent, .45 * pop), 2, true)
	draw_arc(c, r + 16, age * .5 + PI, age * .5 + PI * 1.6, 32, Color(accent, .45 * pop), 2, true)
	ArenaIcon.draw(self, c, icon, r * 1.05, Color(1, 1, 1, pop))
	# Title and detail.
	var y: float = c.y + 52 + 58
	draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(accent.lightened(.25), show))
	var line_w: float = minf(220, size.x * .5) * show
	draw_line(Vector2(c.x - line_w * .5, y + 14), Vector2(c.x + line_w * .5, y + 14), Color(accent, .5 * show), 1)
	y += 42
	if not detail.is_empty():
		draw_multiline_string(text_font, Vector2(24, y), detail, HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 15, -1, Color(.85, .88, .96, show))
		y += 22 * (1 + detail.count("\n")) + 12
	if not types.is_empty():
		if not types_caption.is_empty():
			draw_string(text_font, Vector2(0, y), types_caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(.6, .65, .8, show));y += 10
		var step: float = 46;var x: float = c.x - step * (types.size() - 1) * .5
		for t in types:
			var at := Vector2(x, y + 22);draw_circle(at, 20, Color("0c1220"));UnitIcon.draw(self, Rect2(at - Vector2(17, 17), Vector2(34, 34)), t)
			draw_arc(at, 20, 0, TAU, 32, Color(accent, .7 * show), 1.5, true);x += step
		y += 58
	if chips.is_empty():return
	# Reward chips, centred in one row.
	var widths: Array[float] = [];var total: float = -10
	for chip in chips:var w: float = text_font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28;widths.append(w);total += w + 10
	var x0: float = (size.x - total) * .5;var rise: float = 8 * (1 - clampf((age - .45) / .35, 0, 1));var a: float = clampf((age - .45) / .35, 0, 1)
	for i in range(chips.size()):
		var rect := Rect2(Vector2(x0, y + rise), Vector2(widths[i], 36))
		var box: StyleBoxFlat = ArenaUI.box(Color(accent, .16 * a), Color(accent, .75 * a));box.set_corner_radius_all(18);draw_style_box(box, rect)
		draw_string(font, rect.position + Vector2(0, 24), chips[i], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, Color(accent.lightened(.35), a))
		x0 += widths[i] + 10
