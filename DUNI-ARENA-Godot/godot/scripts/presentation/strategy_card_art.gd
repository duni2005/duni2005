class_name StrategyCardArt
extends RefCounted
## The one strategy card look, used everywhere a card appears (pre-battle choice, turning-point
## hand, inventory, shop, rewards, codex, details). Drawn with CardFace:
## - frame: 액티브 steel blue, 패시브 gold;
## - the name plate at the top centre; the card picture under it (data.image when it exists, else
##   the card icon on the card kind's colour);
## - the band between picture and text: "액티브 · 유닛 지정(아군)", "액티브 · 위치 지정",
##   "액티브 · 즉시 시전", "패시브";
## - the description in the lower half (large cards only), shrunk to fit: a condition first as
##   [조건: …] in the accent colour, numbers in the accent colour (disruption grades are in the
##   effect text);
## - the cooldown-type badge on the picture's top-right corner: "소모" over an X-shaped star,
##   "일반" over a +-shaped star, the cooldown number over an hourglass (the wins still to go when
##   waiting).
## Small cards (about five across a phone) show name, badge, picture and band; large cards add
## the description. A card used this battle is drawn face down (draw_back).
const FRAME := {&"active": Color("6f93c4"), &"passive": Color("d9b45a")}
const BODY := {&"active": Color("161f2f"), &"passive": Color("2a2111")}
## The picture ground (card kind colour, top and bottom).
const PICTURE := {&"active": [Color("34527d"), Color("131c2c")], &"passive": [Color("7a5a1e"), Color("261c0a")]}
const ACCENT := {&"active": Color("9fd0ff"), &"passive": Color("ffd77a")}
const BADGE := {&"consume": Color("ff9d5c"), &"normal": Color("8fe3b0"), &"cooldown": Color("8fc8ff")}
const LARGE_WIDTH := 110.0
## The card's own glow colour (the icon's light in the picture).
const THEMES := {
	"mango": [Color("6b3a1c"), Color("f2a24a")], "shield": [Color("1f3a5c"), Color("7cc8ff")],
	"evade": [Color("1f4a3a"), Color("7fe0b0")], "taunt": [Color("5a1f2a"), Color("ff8a8a")],
	"charge": [Color("3d2466"), Color("c9a2ff")], "iron": [Color("2f3746"), Color("c8d2e6")],
	"disrupt": [Color("3a2a52"), Color("d6a8ff")], "block": [Color("4a2630"), Color("ff9ab0")],
	"seal": [Color("2a1a3a"), Color("ff6bd6")], "barrier": [Color("21404a"), Color("8fe3ff")],
	"feast": [Color("5a3a12"), Color("ffd36b")], "rally": [Color("1f3a5c"), Color("9fe0ff")],
	"resonance": [Color("5a2a12"), Color("ffb36b")], "command_flag": [Color("4a1f22"), Color("ff8a7a")],
	"indomitable": [Color("5a4512"), Color("ffe08a")], "lunchbox": [Color("4a3416"), Color("ffc36b")],
	"heal_zone": [Color("1f4a2e"), Color("7fe0a0")], "pressure": [Color("3a1f4a"), Color("c99bff")],
}

static func theme_for(kind: String) -> Array:
	return THEMES.get(kind, [Color("2a2142"), Color("a07ad8")])

## state: "ready"; "selected" / "lifted" (held: bright rim); "used" (face down); "waiting"
## (cooldown: dimmed, the hourglass shows `wins` still to go); "blocked" (dimmed, note on a
## band); "passive" (적용 중: soft pulsing glow); "passive_off" (its condition does not hold).
## large: 1 / 0 forces the layout, -1 picks by width (LARGE_WIDTH).
static func draw(c: CanvasItem, rect: Rect2, kind: String, state: String = "ready", note: String = "", wins: int = 0, large: int = -1) -> void:
	if state == "used":
		draw_back(c, rect, note if not note.is_empty() else "사용함");return
	var data: StrategyCardData = StrategyCardCatalog.get_card(StringName(kind))
	if data == null:return
	var big: bool = rect.size.x >= LARGE_WIDTH if large < 0 else large == 1
	var w: float = rect.size.x;var h: float = rect.size.y
	var ck: StringName = &"passive" if data.passive() else &"active"
	var dim: bool = state in ["waiting", "blocked", "passive_off"]
	var rim: Color = FRAME[ck];var acc: Color = ACCENT[ck]
	if state == "passive":VfxArt.glow(c, rect.get_center(), w * .9, rim, .12 + .07 * sin(Time.get_ticks_msec() * .004))
	CardFace.frame(c, rect, BODY[ck], rim, dim, state in ["selected", "lifted"])
	var inset: float = maxf(3, w * .06)
	var plate := Rect2(rect.position + Vector2(inset * .7, h * .035), Vector2(w - inset * 1.4, h * (.085 if big else .15)))
	var pic := Rect2(Vector2(rect.position.x + inset, plate.end.y + h * .02), Vector2(w - inset * 2, h * (.37 if big else .5)))
	var band := Rect2(Vector2(rect.position.x + inset * .6, pic.end.y + h * .012), Vector2(w - inset * 1.2, h * (.065 if big else .14)))
	var tex: Texture2D = load(data.image) if not data.image.is_empty() and ResourceLoader.exists(data.image) else null
	CardFace.picture(c, pic, kind, PICTURE[ck][0], PICTURE[ck][1], theme_for(kind)[1], dim, tex)
	CardFace.plate(c, plate, data.display_name, rim, dim)
	CardFace.band(c, band, data.type_text(not big), acc, dim)
	if big:
		var body := Rect2(Vector2(rect.position.x + inset * 1.2, band.end.y + h * .02), Vector2(w - inset * 2.4, rect.end.y - band.end.y - h * .055))
		var lines: Array = []
		if not data.conditions.is_empty():lines.append(["[조건: %s]" % data.condition_text(), Color(acc, .5 if dim else 1.0)])
		lines.append([data.description, Color(0, 0, 0, 0)])
		CardFace.text(c, body, lines, int(clampf(w * .07, 9, 17)), Color("e8ecf6", .5 if dim else 1.0), Color(acc.lightened(.1), .5 if dim else 1.0))
	var br: float = w * (.12 if big else .155)
	_badge(c, Vector2(pic.end.x - br * .55, pic.position.y + br * .55), br, data, wins if state == "waiting" else 0, .5 if dim else 1.0)
	# State marks.
	var heading: Font = ArenaUI.heading_font()
	if state == "passive":
		var ph: float = h * (.07 if big else .12)
		var pb := Rect2(Vector2(pic.position.x, pic.end.y - ph - 2), Vector2(pic.size.x, ph))
		c.draw_rect(pb, Color(.1, .07, .02, .72))
		var ps: int = int(clampf(ph * .62, 7, 15))
		c.draw_string(heading, Vector2(pb.position.x, pb.get_center().y + ps * .36), "적용 중", HORIZONTAL_ALIGNMENT_CENTER, pb.size.x, ps, ArenaUI.GOLD)
	elif dim:
		var stamp: String = note if not note.is_empty() else "조건 미충족" if state == "passive_off" else "사용 불가"
		var sh: float = h * (.1 if big else .15)
		var sb := Rect2(Vector2(rect.position.x + 2, pic.get_center().y - sh * .5), Vector2(w - 4, sh))
		c.draw_rect(sb, Color(0, 0, 0, .6))
		var ss: int = int(clampf(sh * .55, 8, 16))
		c.draw_string(heading, Vector2(sb.position.x, sb.get_center().y + ss * .36), stamp, HORIZONTAL_ALIGNMENT_CENTER, sb.size.x, ss, Color("e6ecff"))

## The cooldown-type badge: text over an icon. waiting > 0: the wins still to go on the hourglass.
static func _badge(c: CanvasItem, at: Vector2, r: float, data: StrategyCardData, waiting: int, a: float) -> void:
	var col: Color = BADGE.get(data.cooldown_type, Color.WHITE)
	c.draw_circle(at, r, Color(.06, .07, .1, .95))
	c.draw_arc(at, r - .5, 0, TAU, 32, Color(col, .9 * a), maxf(1.2, r * .09), true)
	var s: float = r * .78
	match data.cooldown_type:
		&"consume":_star(c, at, s, PI * .25, Color(col, .45 * a))
		&"normal":_star(c, at, s, 0, Color(col, .45 * a))
		_:_hourglass(c, at, s, Color(col, .45 * a))
	var text: String = str(waiting) if waiting > 0 else str(data.cooldown_wins) if data.cooldown_type == &"cooldown" else data.kind_text()
	var font: Font = ArenaUI.heading_font()
	var size: int = int(r * (1.1 if text.length() <= 1 else .7))
	c.draw_string(font, Vector2(at.x - r, at.y + size * .36), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2, size, Color(col.lightened(.55), a))
## A four-pointed star (rotation 0: +, PI/4: X).
static func _star(c: CanvasItem, at: Vector2, s: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(8):pts.append(at + Vector2.from_angle(rot - PI * .5 + i * PI * .25) * (s if i % 2 == 0 else s * .28))
	c.draw_colored_polygon(pts, col)
static func _hourglass(c: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var w: float = s * .6;var h: float = s * .85
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-w, -h), at + Vector2(w, -h), at + Vector2(0, -h * .06)]), col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-w, h), at + Vector2(w, h), at + Vector2(0, h * .06)]), col)

## The back of a card (used this battle).
static func draw_back(c: CanvasItem, rect: Rect2, note: String = "") -> void:
	var radius: int = maxi(4, int(rect.size.x * .06))
	var frame := StyleBoxFlat.new();frame.bg_color = Color("161c2e");frame.set_corner_radius_all(radius);frame.border_color = Color("4a5778");frame.set_border_width_all(2)
	c.draw_style_box(frame, rect)
	c.draw_arc(rect.get_center(), rect.size.x * .22, 0, TAU, 32, Color("8a96c0", .45), 1.5, true)
	ArenaIcon.draw(c, rect.get_center(), "card_back", rect.size.x * .3, Color(1, 1, 1, .45))
	if not note.is_empty():
		var big: bool = rect.size.x >= LARGE_WIDTH
		c.draw_string(ArenaUI.get_theme().default_font, Vector2(rect.position.x, rect.end.y - rect.size.y * .1), note, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12 if big else 8, Color("aab4d6"))
