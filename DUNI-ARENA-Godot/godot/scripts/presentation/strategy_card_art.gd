class_name StrategyCardArt
extends RefCounted
## The one strategy card look, used everywhere a card appears (pre-battle choice, turning-point
## hand, inventory, shop, rewards, codex, details). A vertical card in two halves:
## - frame: 액티브 steel blue, 패시브 gold;
## - name ribbon at the top centre; the card picture under it (data.image when it exists, else the
##   card icon on the card kind's colour);
## - the type band between picture and text: "액티브 · 유닛 지정(아군)", "액티브 · 위치 지정",
##   "액티브 · 즉시 시전", "패시브"; disruption cards add a small "방해" chip with the grade;
## - the description in the lower half (large cards only): a condition first as [조건: …] in the
##   accent colour, numbers in the accent colour;
## - the cooldown-type badge at the top right (small cards: on the picture's corner): "소모" over
##   an X-shaped star, "일반" over a +-shaped star, the cooldown number over an hourglass (the wins
##   still to go when waiting).
## Small cards (about five across a phone) show name, badge, picture and type band; large cards add
## the description. A card used this battle is drawn face down (draw_back).
const FRAME := {&"active": Color("6f93c4"), &"passive": Color("e2b85a")}
const BODY := {&"active": Color("1b2638"), &"passive": Color("33270f")}
## The picture background (card kind colour, top and bottom).
const PICTURE := {&"active": [Color("3b5d8c"), Color("17243a")], &"passive": [Color("8a6420"), Color("2e2008")]}
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
}

static func theme_for(kind: String) -> Array:
	return THEMES.get(kind, [Color("2a2142"), Color("a07ad8")])
static func frame_color(data: StrategyCardData) -> Color:
	return FRAME[&"passive"] if data != null and data.passive() else FRAME[&"active"]
static func accent(data: StrategyCardData) -> Color:
	return ACCENT[&"passive"] if data != null and data.passive() else ACCENT[&"active"]

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
	var hot: bool = state in ["selected", "lifted"]
	var a: float = .5 if dim else 1.0
	var frame_col: Color = FRAME[ck];var acc: Color = ACCENT[ck]
	var radius: int = maxi(3, int(w * .07))
	var heading: Font = ArenaUI.heading_font();var font: Font = ArenaUI.get_theme().default_font
	# Shadow, glow, body and frame.
	var shadow := StyleBoxFlat.new();shadow.bg_color = Color(0, 0, 0, .45);shadow.set_corner_radius_all(radius)
	c.draw_style_box(shadow, Rect2(rect.position + Vector2(0, h * (.05 if state == "lifted" else .025)), rect.size))
	if hot:VfxArt.glow(c, rect.get_center(), w * .95, Color(frame_col.lightened(.3)), .26)
	if state == "passive":VfxArt.glow(c, rect.get_center(), w * .9, FRAME[&"passive"], .14 + .08 * sin(Time.get_ticks_msec() * .004))
	var body := StyleBoxFlat.new();body.bg_color = BODY[ck].darkened(.3) if dim else BODY[ck];body.set_corner_radius_all(radius)
	body.border_color = Color(frame_col.lightened(.35) if hot else frame_col, .55 if dim else 1.0);body.set_border_width_all(maxi(2, int(w * (.045 if hot else .035))))
	c.draw_style_box(body, rect)
	var inset: float = maxf(3, w * .06)
	var inner := StyleBoxFlat.new();inner.draw_center = false;inner.set_corner_radius_all(maxi(2, radius - 2));inner.border_color = Color(frame_col.lightened(.5), .22);inner.set_border_width_all(1)
	c.draw_style_box(inner, rect.grow(-inset * .55))
	# Layout (fractions of the height).
	var ribbon_h: float = h * (.1 if big else .17)
	var ribbon := Rect2(rect.position + Vector2(-w * .02, h * .03), Vector2(w * 1.04, ribbon_h))
	var pic_top: float = ribbon.end.y + h * .01
	var pic := Rect2(Vector2(rect.position.x + inset, pic_top), Vector2(w - inset * 2, h * (.36 if big else .52)))
	var band_h: float = h * (.075 if big else .15)
	var band := Rect2(Vector2(rect.position.x + inset * .4, pic.end.y + h * .012), Vector2(w - inset * .8, band_h))
	# Picture: data.image when it exists, else the card icon on the card kind's colour.
	_picture(c, pic, data, kind, dim, maxi(2, radius - 2))
	# Name ribbon (drawn over the picture's top edge).
	_ribbon(c, ribbon, frame_col, dim)
	var name_size: int = int(clampf(ribbon_h * .56, 9, 22))
	var name_w: float = heading.get_string_size(data.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	if name_w > ribbon.size.x - w * .16:name_size = maxi(7, int(name_size * (ribbon.size.x - w * .16) / name_w))
	c.draw_string(heading, Vector2(ribbon.position.x, ribbon.get_center().y + name_size * .36), data.display_name, HORIZONTAL_ALIGNMENT_CENTER, ribbon.size.x, name_size, Color(1, .97, .9, a))
	# Type band and the disruption chip.
	var band_box := StyleBoxFlat.new();band_box.bg_color = Color(frame_col.darkened(.55), .95);band_box.set_corner_radius_all(maxi(2, int(band_h * .3)));band_box.border_color = Color(frame_col, .75 * a);band_box.set_border_width_all(1)
	c.draw_style_box(band_box, band)
	var type_size: int = int(clampf(band_h * .55, 7, 14))
	# Narrow large cards (shop / codex) keep the band on one line: short type and grade.
	var narrow: bool = big and w < 170 and data.disrupt != &""
	var type_text: String = data.type_text(not big or narrow)
	var chip: String = ("방해 · " + (StrategyCardData.DISRUPT_SHORT if narrow else StrategyCardData.DISRUPT_NAMES).get(data.disrupt, "")) if big else "방해"
	var chip_w: float = (font.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, type_size - 1).x + 8) if data.disrupt != &"" else 0.0
	if chip_w > 0 and big:
		var tw: float = font.get_string_size(type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, type_size).x
		var x0: float = band.get_center().x - (tw + chip_w + 6) * .5
		c.draw_string(font, Vector2(x0, band.get_center().y + type_size * .36), type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, type_size, Color(acc.lightened(.3), a))
		_chip(c, Rect2(Vector2(x0 + tw + 6, band.get_center().y - type_size * .62), Vector2(chip_w, type_size * 1.24)), chip, type_size - 1, a)
	else:
		c.draw_string(font, Vector2(band.position.x, band.get_center().y + type_size * .36), type_text, HORIZONTAL_ALIGNMENT_CENTER, band.size.x, type_size, Color(acc.lightened(.3), a))
		if chip_w > 0:
			# Small cards: the chip sits on the picture's lower left, just above the band.
			_chip(c, Rect2(Vector2(pic.position.x + 2, pic.end.y - type_size * 1.3 - 2), Vector2(chip_w, type_size * 1.3)), chip, type_size - 1, a)
	# Description (large only).
	if big:
		var text_rect := Rect2(Vector2(rect.position.x + inset * 1.3, band.end.y + h * .03), Vector2(w - inset * 2.6, rect.end.y - band.end.y - h * .06))
		var lines: Array = []
		if not data.conditions.is_empty():lines.append(["[조건: %s]" % data.condition_text(), true])
		lines.append([data.description, false])
		rich(c, font, text_rect, lines, int(clampf(w * .068, 10, 16)), Color("eef1fa", a), Color(acc.lightened(.15), a))
	# Cooldown-type badge, top right.
	# (On small cards it sits on the picture's corner, clear of the name.)
	var br: float = w * (.13 if big else .16)
	var bat: Vector2 = Vector2(rect.end.x - br * .62, rect.position.y + br * .62) if big else Vector2(pic.end.x - br * .8, pic.position.y + br * .95)
	_badge(c, bat, br, data, wins if state == "waiting" else 0, a)
	# State bands.
	if state == "passive":
		var py: float = band.position.y - (h * .09 if big else h * .15)
		var pb := Rect2(Vector2(rect.position.x + inset, py), Vector2(w - inset * 2, h * (.075 if big else .13)))
		var pk := StyleBoxFlat.new();pk.bg_color = Color(.12, .08, .02, .78);pk.set_corner_radius_all(int(pb.size.y * .45));pk.border_color = Color(FRAME[&"passive"], .6 + .3 * sin(Time.get_ticks_msec() * .004));pk.set_border_width_all(1)
		c.draw_style_box(pk, pb)
		var ps: int = int(clampf(pb.size.y * .62, 7, 15))
		c.draw_string(heading, Vector2(pb.position.x, pb.get_center().y + ps * .36), "적용 중", HORIZONTAL_ALIGNMENT_CENTER, pb.size.x, ps, ArenaUI.GOLD)
	elif dim:
		var stamp: String = note if not note.is_empty() else "조건 미충족" if state == "passive_off" else "사용 불가"
		var sh: float = h * (.12 if big else .17)
		var sb := Rect2(Vector2(rect.position.x, pic.get_center().y - sh * .5), Vector2(w, sh))
		c.draw_rect(sb, Color(0, 0, 0, .6))
		var ss: int = int(clampf(sh * .55, 8, 16))
		c.draw_string(heading, Vector2(rect.position.x, sb.get_center().y + ss * .36), stamp, HORIZONTAL_ALIGNMENT_CENTER, w, ss, Color("e6ecff"))

static func _picture(c: CanvasItem, pic: Rect2, data: StrategyCardData, kind: String, dim: bool, radius: int) -> void:
	var ck: StringName = &"passive" if data.passive() else &"active"
	var top: Color = PICTURE[ck][0];var bottom: Color = PICTURE[ck][1]
	if dim:top = top.darkened(.4);bottom = bottom.darkened(.4)
	var box := StyleBoxFlat.new();box.bg_color = bottom;box.set_corner_radius_all(radius);box.border_color = Color(FRAME[ck], .5);box.set_border_width_all(1)
	c.draw_style_box(box, pic)
	var tex: Texture2D = load(data.image) if not data.image.is_empty() and ResourceLoader.exists(data.image) else null
	if tex != null:
		c.draw_texture_rect(tex, pic.grow(-1), false, Color(1, 1, 1, .5 if dim else 1));return
	# A soft vertical gradient (top light) and the icon in the card's own glow.
	var steps: int = 6
	for i in range(steps):
		var t: float = float(i) / steps
		c.draw_rect(Rect2(pic.position + Vector2(1, 1 + pic.size.y * t * .6), Vector2(pic.size.x - 2, pic.size.y * .6 / steps)), Color(top, .55 * (1 - t)))
	var glow: Color = theme_for(kind)[1]
	VfxArt.glow(c, pic.get_center(), pic.size.x * .5, glow, .12 if dim else .32)
	ArenaIcon.draw(c, pic.get_center() + Vector2(0, pic.size.y * .04), kind, minf(pic.size.y * .74, pic.size.x * .7), Color(1, 1, 1, .4 if dim else 1))

static func _ribbon(c: CanvasItem, r: Rect2, col: Color, dim: bool) -> void:
	var notch: float = r.size.y * .35
	var fill: Color = col.darkened(.25 if not dim else .55)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - notch, r.get_center().y), r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x + notch, r.get_center().y)])
	c.draw_colored_polygon(pts, fill)
	var band := Rect2(r.position + Vector2(notch * 1.1, 0), Vector2(r.size.x - notch * 2.2, r.size.y))
	c.draw_rect(band, col.darkened(.05 if not dim else .45))
	c.draw_line(band.position + Vector2(0, 1), Vector2(band.end.x, band.position.y + 1), Color(1, 1, 1, .35 if not dim else .15), 1)
	c.draw_line(Vector2(band.position.x, band.end.y - 1), band.end - Vector2(0, 1), Color(0, 0, 0, .35), 1)

static func _chip(c: CanvasItem, r: Rect2, text: String, size: int, a: float) -> void:
	var box := StyleBoxFlat.new();box.bg_color = Color(.35, .08, .16, .95);box.set_corner_radius_all(int(r.size.y * .4));box.border_color = Color("ff8aa8", a);box.set_border_width_all(1)
	c.draw_style_box(box, r)
	c.draw_string(ArenaUI.get_theme().default_font, Vector2(r.position.x, r.get_center().y + size * .36), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color("ffd0dc", a))

## The cooldown-type badge: text over an icon. waiting > 0: the wins still to go on the hourglass.
static func _badge(c: CanvasItem, at: Vector2, r: float, data: StrategyCardData, waiting: int, a: float) -> void:
	var col: Color = BADGE.get(data.cooldown_type, Color.WHITE)
	var font: Font = ArenaUI.heading_font()
	c.draw_circle(at, r, Color(0.05, .06, .1, .92))
	c.draw_arc(at, r, 0, TAU, 28, Color(col, .95), maxf(1.5, r * .12), true)
	var s: float = r * .82
	match data.cooldown_type:
		&"consume":_star(c, at, s, PI * .25, Color(col, .85 * a))
		&"normal":_star(c, at, s, 0, Color(col, .85 * a))
		_:_hourglass(c, at, s, Color(col, .85 * a))
	var text: String = str(waiting) if waiting > 0 else str(data.cooldown_wins) if data.cooldown_type == &"cooldown" else data.kind_text()
	var size: int = int(r * (1.05 if text.length() <= 1 else .66))
	var y: float = at.y + size * .36
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		c.draw_string(font, Vector2(at.x - r, y) + o, text, HORIZONTAL_ALIGNMENT_CENTER, r * 2, size, Color(0, 0, 0, .9 * a))
	c.draw_string(font, Vector2(at.x - r, y), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2, size, Color(1, 1, 1, a))
## A four-pointed star (rotation 0: +, PI/4: X).
static func _star(c: CanvasItem, at: Vector2, s: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(8):pts.append(at + Vector2.from_angle(rot - PI * .5 + i * PI * .25) * (s if i % 2 == 0 else s * .3))
	c.draw_colored_polygon(pts, col)
static func _hourglass(c: CanvasItem, at: Vector2, s: float, col: Color) -> void:
	var w: float = s * .62;var h: float = s * .9
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-w, -h), at + Vector2(w, -h), at + Vector2(0, -h * .08)]), col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-w, h), at + Vector2(w, h), at + Vector2(0, h * .08)]), col)
	c.draw_line(at + Vector2(-w * 1.2, -h), at + Vector2(w * 1.2, -h), col, maxf(1, s * .12))
	c.draw_line(at + Vector2(-w * 1.2, h), at + Vector2(w * 1.2, h), col, maxf(1, s * .12))

## Wrapped text in rect: lines are [text, accent_all]; numbers (with %, 초, G, p) are drawn in the
## accent colour. Stops (with "…") when the rect is full.
static func rich(c: CanvasItem, font: Font, rect: Rect2, lines: Array, size: int, base: Color, acc: Color) -> void:
	var re := RegEx.new();re.compile("[0-9]+(\\.[0-9]+)?(%p|%|초|G|승)?")
	var line_h: float = size * 1.35;var y: float = rect.position.y + size;var x: float = rect.position.x
	var rows: Array = []
	for line in lines:
		# Words (by spaces); a word too wide is broken by characters.
		var row: Array = [];var row_w: float = 0
		for word in str(line[0]).split(" ", false):
			var ww: float = font.get_string_size(word + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if row_w + ww > rect.size.x and not row.is_empty():rows.append([row, row_w]);row = [];row_w = 0
			row.append([word, bool(line[1])]);row_w += ww
		if not row.is_empty():rows.append([row, row_w])
	var max_rows: int = maxi(1, int((rect.size.y + line_h - size) / line_h))
	for i in range(mini(rows.size(), max_rows)):
		var row: Array = rows[i][0];var cx: float = x + (rect.size.x - float(rows[i][1])) * .5
		if i == max_rows - 1 and rows.size() > max_rows:row = row.duplicate();row.append(["…", false])
		for item in row:
			var word: String = item[0]
			if item[1]:
				c.draw_string(font, Vector2(cx, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, acc)
			else:
				var at: int = 0
				for m in re.search_all(word):
					if m.get_start() > at:cx = _piece(c, font, cx, y, word.substr(at, m.get_start() - at), size, base)
					cx = _piece(c, font, cx, y, m.get_string(), size, acc);at = m.get_end()
				if at < word.length():cx = _piece(c, font, cx, y, word.substr(at), size, base)
				cx -= font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			cx += font.get_string_size(word + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		y += line_h
static func _piece(c: CanvasItem, font: Font, x: float, y: float, text: String, size: int, col: Color) -> float:
	c.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return x + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## The back of a card (used this battle).
static func draw_back(c: CanvasItem, rect: Rect2, note: String = "") -> void:
	var radius: int = maxi(3, int(rect.size.x * .07))
	var frame := StyleBoxFlat.new();frame.bg_color = Color("1a2036");frame.set_corner_radius_all(radius);frame.border_color = Color("5a6890");frame.set_border_width_all(2)
	c.draw_style_box(frame, rect)
	var inner: Rect2 = rect.grow(-rect.size.x * .1)
	for i in range(5):
		var t: float = (i + 1) / 6.0
		c.draw_line(Vector2(inner.position.x, inner.position.y + inner.size.y * t), Vector2(inner.end.x, inner.position.y + inner.size.y * t), Color("2a3352"), 1)
	c.draw_arc(rect.get_center(), rect.size.x * .22, 0, TAU, 24, Color("8a96c0", .6), 2, true)
	ArenaIcon.draw(c, rect.get_center(), "card_back", rect.size.x * .3, Color(1, 1, 1, .5))
	if not note.is_empty():
		var big: bool = rect.size.x >= LARGE_WIDTH
		c.draw_string(ArenaUI.get_theme().default_font, Vector2(rect.position.x, rect.end.y - rect.size.y * .1), note, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12 if big else 8, Color("aab4d6"))
