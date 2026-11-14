class_name StrategyCardArt
extends RefCounted
## Draws a strategy card as a playing card: framed body in the card's colour, the kind chip
## (소모 / 일반 / 쿨타임 N) top left, the use icon (유닛 / 위치 / 즉시) top right, name band, art
## window with the card icon, the condition / disruption tag and (when large) the use and effect.
## A card used this battle is drawn face down (draw_back).
const THEMES := {
	"mango": [Color("6b3a1c"), Color("f2a24a")],
	"shield": [Color("1f3a5c"), Color("7cc8ff")],
	"evade": [Color("1f4a3a"), Color("7fe0b0")],
	"taunt": [Color("5a1f2a"), Color("ff8a8a")],
	"charge": [Color("3d2466"), Color("c9a2ff")],
	"iron": [Color("2f3746"), Color("c8d2e6")],
	"disrupt": [Color("3a2a52"), Color("d6a8ff")],
	"block": [Color("4a2630"), Color("ff9ab0")],
	"seal": [Color("2a1a3a"), Color("ff6bd6")],
	"barrier": [Color("21404a"), Color("8fe3ff")],
	"feast": [Color("5a3a12"), Color("ffd36b")],
}
const KIND_COLORS = {StrategyCardData.Usage.CONSUME: Color("ffb36b"), StrategyCardData.Usage.GENERAL: Color("8fe3b0"), StrategyCardData.Usage.COOLDOWN: Color("8fc8ff")}

static func theme_for(kind: String) -> Array:
	return THEMES.get(kind, [Color("2a2142"), Color("a07ad8")])

## state: "ready", "selected", "lifted", "used" (face down), "waiting" / "blocked" (dimmed, note on
## a band). rule and description: overrides for the small chip and the big text (empty: from data).
static func draw(c: CanvasItem, rect: Rect2, kind: String, title: String, rule: String = "", description: String = "", state: String = "ready", note: String = "") -> void:
	if state == "used":
		draw_back(c, rect, note if not note.is_empty() else "사용함");return
	var data: StrategyCardData = StrategyCardCatalog.get_card(StringName(kind))
	var colors: Array = theme_for(kind);var body: Color = colors[0];var glow: Color = colors[1]
	var big: bool = rect.size.x > 140;var dim: bool = state in ["waiting", "blocked"]
	var radius: int = int(rect.size.x * .09)
	var shadow := StyleBoxFlat.new();shadow.bg_color = Color(0, 0, 0, .45);shadow.set_corner_radius_all(radius)
	c.draw_style_box(shadow, Rect2(rect.position + Vector2(0, rect.size.y * (.06 if state == "lifted" else .03)), rect.size))
	var frame := StyleBoxFlat.new();frame.bg_color = body.darkened(.35) if dim else body;frame.set_corner_radius_all(radius)
	var hot: bool = state in ["selected", "lifted"]
	frame.border_color = ArenaUI.GOLD if hot else Color(glow, .45) if dim else Color(glow.lerp(ArenaUI.GOLD, .4), .95)
	frame.set_border_width_all(3 if hot else 2)
	c.draw_style_box(frame, rect)
	if hot:VfxArt.glow(c, rect.get_center(), rect.size.x * .9, ArenaUI.GOLD, .22)
	var inset: float = rect.size.x * .07
	var inner := StyleBoxFlat.new();inner.draw_center = false;inner.set_corner_radius_all(maxi(2, radius - 3));inner.border_color = Color(1, 1, 1, .1);inner.set_border_width_all(1)
	c.draw_style_box(inner, rect.grow(-inset * .45))
	var font: Font = ArenaUI.heading_font();var text_font: Font = ArenaUI.get_theme().default_font
	var a: float = .55 if dim else 1.0
	# Kind chip (top left) and use icon (top right).
	var chip_font: int = 12 if big else 8
	var kind_text: String = rule if not rule.is_empty() else (_short_kind(data) if not big else data.kind_text()) if data != null else ""
	if not kind_text.is_empty():
		var kc: Color = KIND_COLORS.get(data.usage_rule, glow) if data != null else glow
		var kw: float = text_font.get_string_size(kind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, chip_font).x + (12 if big else 6)
		var kr := Rect2(rect.position + Vector2(inset * .6, inset * .6), Vector2(kw, chip_font + (8 if big else 4)))
		var kb: StyleBoxFlat = ArenaUI.box(Color(0, 0, 0, .55), Color(kc, .9 * a));kb.set_corner_radius_all(4);c.draw_style_box(kb, kr)
		c.draw_string(text_font, kr.position + Vector2(0, kr.size.y * .5 + chip_font * .36), kind_text, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, chip_font, Color(kc.lightened(.3), a))
	if data != null:
		var ir: float = rect.size.x * (.075 if big else .1);var ic: Vector2 = Vector2(rect.end.x - inset * .6 - ir, rect.position.y + inset * .6 + ir)
		c.draw_circle(ic, ir, Color(0, 0, 0, .55));c.draw_arc(ic, ir, 0, TAU, 18, Color(glow, .8 * a), 1.5, true)
		ArenaIcon.draw(c, ic, data.use_icon(), ir * 1.5, Color(1, 1, 1, a))
	var name_size: int = 20 if big else 10
	var name_y: float = rect.position.y + rect.size.y * (.2 if big else .3)
	c.draw_string(font, Vector2(rect.position.x + 2, name_y), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 4, name_size, Color(1, .96, .88, a))
	var art := Rect2(rect.position + Vector2(inset, rect.size.y * (.24 if big else .34)), Vector2(rect.size.x - inset * 2, rect.size.y * (.3 if big else .4)))
	var window := StyleBoxFlat.new();window.bg_color = body.darkened(.55);window.set_corner_radius_all(maxi(3, radius - 4));window.border_color = Color(glow, .35);window.set_border_width_all(1)
	c.draw_style_box(window, art)
	VfxArt.glow(c, art.get_center(), art.size.x * .55, glow, .12 if dim else .3)
	ArenaIcon.draw(c, art.get_center(), kind, art.size.y * .72, Color(1, 1, 1, .4 if dim else 1))
	# Condition / disruption tag under the art.
	var tag: String = ""
	if data != null:
		if data.disrupt != &"":tag = "방해 · " + StrategyCardData.DISRUPT_NAMES.get(data.disrupt, "")
		elif data.condition != &"":tag = data.condition_text()
	var y: float = art.end.y + rect.size.y * .03
	if not tag.is_empty():
		var tf: int = 11 if big else 7
		var tw: float = minf(rect.size.x - inset, text_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x + (14 if big else 6))
		var tr := Rect2(Vector2(rect.get_center().x - tw * .5, y), Vector2(tw, tf + (8 if big else 4)))
		c.draw_style_box(ArenaUI.box(Color(glow, .18), Color(glow, .6)), tr)
		c.draw_string(text_font, tr.position + Vector2(0, tr.size.y * .5 + tf * .36), tag, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, tf, Color(glow.lightened(.4), a))
		y = tr.end.y
	if big and data != null:
		c.draw_string(text_font, Vector2(rect.position.x, y + 18), data.use_text(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color(glow.lightened(.35), .9))
		var text: String = description if not description.is_empty() else data.description
		c.draw_multiline_string(text_font, Vector2(rect.position.x + inset, y + 38), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - inset * 2, int(clampf(rect.size.x * .075, 12, 16)), 4, Color("eef1fa"))
	if dim:
		var stamp: String = note if not note.is_empty() else "사용 불가"
		var band := Rect2(Vector2(rect.position.x, rect.get_center().y - (14 if big else 9)), Vector2(rect.size.x, 28 if big else 18))
		c.draw_rect(band, Color(0, 0, 0, .62))
		c.draw_string(font, Vector2(rect.position.x, band.get_center().y + (6 if big else 4)), stamp, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15 if big else 9, Color("e6ecff"))

## "소모", "일반", "쿨2" (small cards).
static func _short_kind(data: StrategyCardData) -> String:
	return "쿨%d" % data.cooldown_wins if data.usage_rule == StrategyCardData.Usage.COOLDOWN else data.kind_text()

## The back of a card (used this battle).
static func draw_back(c: CanvasItem, rect: Rect2, note: String = "") -> void:
	var radius: int = int(rect.size.x * .09)
	var frame := StyleBoxFlat.new();frame.bg_color = Color("1a2036");frame.set_corner_radius_all(radius);frame.border_color = Color("5a6890");frame.set_border_width_all(2)
	c.draw_style_box(frame, rect)
	var inner: Rect2 = rect.grow(-rect.size.x * .1)
	for i in range(5):
		var t: float = (i + 1) / 6.0
		c.draw_line(Vector2(inner.position.x, inner.position.y + inner.size.y * t), Vector2(inner.end.x, inner.position.y + inner.size.y * t), Color("2a3352"), 1)
	c.draw_arc(rect.get_center(), rect.size.x * .22, 0, TAU, 24, Color("8a96c0", .6), 2, true)
	ArenaIcon.draw(c, rect.get_center(), "card_back", rect.size.x * .3, Color(1, 1, 1, .5))
	if not note.is_empty():
		var big: bool = rect.size.x > 140
		c.draw_string(ArenaUI.get_theme().default_font, Vector2(rect.position.x, rect.end.y - rect.size.y * .1), note, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12 if big else 8, Color("aab4d6"))
