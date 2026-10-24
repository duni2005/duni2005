class_name StrategyCardArt
extends RefCounted
## Draws a strategy card as a playing card: framed body in the card's colour, name band, art
## window with the card icon, usage chip, and (when large) the full description.
const THEMES := {
	"mango": [Color("6b3a1c"), Color("f2a24a")],
	"shield": [Color("1f3a5c"), Color("7cc8ff")],
	"evade": [Color("1f4a3a"), Color("7fe0b0")],
	"taunt": [Color("5a1f2a"), Color("ff8a8a")],
	"charge": [Color("3d2466"), Color("c9a2ff")],
	"iron": [Color("2f3746"), Color("c8d2e6")],
}

static func theme_for(kind: String) -> Array:
	return THEMES.get(kind, [Color("2a2142"), Color("a07ad8")])

## state: "ready", "selected", "used" or "waiting". note: small text for used/waiting cards.
static func draw(c: CanvasItem, rect: Rect2, kind: String, title: String, rule: String, description: String, state: String = "ready", note: String = "") -> void:
	var colors: Array = theme_for(kind);var body: Color = colors[0];var glow: Color = colors[1]
	var big: bool = rect.size.x > 160;var dim: bool = state in ["used", "waiting"]
	var radius: int = int(rect.size.x * .09)
	# Drop shadow and body.
	var shadow := StyleBoxFlat.new();shadow.bg_color = Color(0, 0, 0, .45);shadow.set_corner_radius_all(radius)
	c.draw_style_box(shadow, Rect2(rect.position + Vector2(0, rect.size.y * .03), rect.size))
	var frame := StyleBoxFlat.new();frame.bg_color = body.darkened(.35) if dim else body;frame.set_corner_radius_all(radius)
	frame.border_color = ArenaUI.GOLD if state == "selected" else Color(glow, .45) if dim else Color(glow.lerp(ArenaUI.GOLD, .4), .95)
	frame.set_border_width_all(3 if state == "selected" else 2)
	c.draw_style_box(frame, rect)
	if state == "selected":VfxArt.glow(c, rect.get_center(), rect.size.x * .9, ArenaUI.GOLD, .18)
	var inset: float = rect.size.x * .07
	# Inner frame line.
	var inner := StyleBoxFlat.new();inner.draw_center = false;inner.set_corner_radius_all(maxi(2, radius - 3));inner.border_color = Color(1, 1, 1, .1);inner.set_border_width_all(1)
	c.draw_style_box(inner, rect.grow(-inset * .45))
	var font: Font = ArenaUI.heading_font();var text_font: Font = ArenaUI.get_theme().default_font
	var name_size: int = 22 if big else 11
	c.draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * (.13 if big else .17)), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, name_size, Color(1, .96, .88, .55 if dim else 1))
	# Art window.
	var art := Rect2(rect.position + Vector2(inset, rect.size.y * (.18 if big else .22)), Vector2(rect.size.x - inset * 2, rect.size.y * (.36 if big else .44)))
	var window := StyleBoxFlat.new();window.bg_color = body.darkened(.55);window.set_corner_radius_all(maxi(3, radius - 4));window.border_color = Color(glow, .35);window.set_border_width_all(1)
	c.draw_style_box(window, art)
	VfxArt.glow(c, art.get_center(), art.size.x * .55, glow, .12 if dim else .3)
	ArenaIcon.draw(c, art.get_center(), kind, art.size.y * .7, Color(1, 1, 1, .4 if dim else 1))
	# Usage chip.
	var chip_font: int = 13 if big else 8
	var chip_w: float = text_font.get_string_size(rule, HORIZONTAL_ALIGNMENT_LEFT, -1, chip_font).x + (16 if big else 8)
	var chip := Rect2(Vector2(rect.get_center().x - chip_w * .5, art.end.y + rect.size.y * .03), Vector2(chip_w, chip_font + (10 if big else 5)))
	c.draw_style_box(ArenaUI.box(Color(glow, .18), Color(glow, .6)), chip)
	c.draw_string(text_font, chip.position + Vector2(0, chip.size.y * .5 + chip_font * .36), rule, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, chip_font, glow.lightened(.4))
	if big and not description.is_empty():
		c.draw_multiline_string(text_font, Vector2(rect.position.x + inset, chip.end.y + 30), description, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - inset * 2, 17, 4, Color("eef1fa"))
	if dim:
		# Stamp across the card.
		var stamp: String = note if not note.is_empty() else "사용함"
		var band := Rect2(Vector2(rect.position.x, rect.get_center().y - (14 if big else 9)), Vector2(rect.size.x, 28 if big else 18))
		c.draw_rect(band, Color(0, 0, 0, .55))
		c.draw_string(font, Vector2(rect.position.x, band.get_center().y + (6 if big else 4)), stamp, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16 if big else 10, Color("c9d0e6"))
