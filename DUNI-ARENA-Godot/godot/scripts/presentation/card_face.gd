class_name CardFace
extends RefCounted
## Drawing parts shared by the strategy card (StrategyCardArt) and the item card (ItemCardArt):
## a clean frame, the name plate at the top centre, the picture window, the centred band line
## and the body text that shrinks until it fits its box. Numbers in the body are drawn in the
## accent colour. Every size is a fraction of the card, so one layout serves small and large.

## The card body and frame. hot: a soft light round a held card and a brighter rim.
static func frame(c: CanvasItem, r: Rect2, body: Color, rim: Color, dim: bool, hot: bool) -> void:
	var w: float = r.size.x;var radius: int = maxi(4, int(w * .06))
	var shadow := StyleBoxFlat.new();shadow.bg_color = Color(0, 0, 0, .4);shadow.set_corner_radius_all(radius)
	c.draw_style_box(shadow, Rect2(r.position + Vector2(0, maxf(2, w * .025)), r.size))
	if hot:VfxArt.glow(c, r.get_center(), w * .9, rim.lightened(.3), .24)
	var box := StyleBoxFlat.new();box.bg_color = body.darkened(.35) if dim else body;box.set_corner_radius_all(radius)
	box.border_color = Color(rim.lightened(.35) if hot else rim, .45 if dim else 1.0);box.set_border_width_all(maxi(2, int(w * (.04 if hot else .028))))
	c.draw_style_box(box, r)
	# A faint light on the upper half (one soft gradient instead of extra rules).
	var top := Rect2(r.position + Vector2(2, 2), Vector2(w - 4, r.size.y * .45))
	for i in range(6):
		var t: float = i / 6.0
		c.draw_rect(Rect2(top.position + Vector2(0, top.size.y * t), Vector2(top.size.x, top.size.y / 6.0)), Color(1, 1, 1, .035 * (1 - t)))

## The name plate: a flat band across the top with the name centred (shrunk to fit).
static func plate(c: CanvasItem, r: Rect2, title: String, col: Color, dim: bool) -> void:
	var box := StyleBoxFlat.new();box.bg_color = col.darkened(.5 if not dim else .7);box.set_corner_radius_all(maxi(2, int(r.size.y * .3)))
	box.border_color = Color(col, .7 if not dim else .3);box.set_border_width_all(1)
	c.draw_style_box(box, r)
	var font: Font = ArenaUI.heading_font()
	var size: int = int(clampf(r.size.y * .58, 8, 22))
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if tw > r.size.x - 6:size = maxi(7, int(size * (r.size.x - 6) / tw))
	c.draw_string(font, Vector2(r.position.x, r.get_center().y + size * .36), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color(1, .97, .9, .55 if dim else 1.0))

## The picture window: a texture when given, else the icon lit in `glow` on a two-tone ground.
static func picture(c: CanvasItem, r: Rect2, icon: String, top: Color, bottom: Color, glow: Color, dim: bool, tex: Texture2D = null) -> void:
	var radius: int = maxi(3, int(r.size.x * .05))
	if dim:top = top.darkened(.4);bottom = bottom.darkened(.4)
	var box := StyleBoxFlat.new();box.bg_color = bottom;box.set_corner_radius_all(radius)
	c.draw_style_box(box, r)
	if tex != null:
		c.draw_texture_rect(tex, r.grow(-1), false, Color(1, 1, 1, .5 if dim else 1));return
	for i in range(6):
		var t: float = i / 6.0
		c.draw_rect(Rect2(r.position + Vector2(1, 1 + r.size.y * .7 * t), Vector2(r.size.x - 2, r.size.y * .7 / 6.0)), Color(top, .5 * (1 - t)))
	VfxArt.glow(c, r.get_center(), r.size.x * .45, glow, .1 if dim else .26)
	ArenaIcon.draw(c, r.get_center(), icon, minf(r.size.y * .7, r.size.x * .62), Color(1, 1, 1, .4 if dim else 1))

## The band between picture and text: one centred line between two thin rules.
static func band(c: CanvasItem, r: Rect2, text: String, col: Color, dim: bool) -> void:
	var font: Font = ArenaUI.get_theme().default_font
	var size: int = int(clampf(r.size.y * .62, 7, 15))
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if tw > r.size.x - 4:size = maxi(6, int(size * (r.size.x - 4) / tw));tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var a: float = .5 if dim else 1.0
	var y: float = r.get_center().y;var gap: float = tw * .5 + 5
	if gap < r.size.x * .5 - 6:
		c.draw_line(Vector2(r.position.x + 3, y), Vector2(r.get_center().x - gap, y), Color(col, .35 * a), 1)
		c.draw_line(Vector2(r.get_center().x + gap, y), Vector2(r.end.x - 3, y), Color(col, .35 * a), 1)
	c.draw_string(font, Vector2(r.position.x, y + size * .36), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size, Color(col.lightened(.25), a))

## Wrapped, centred text in rect. lines: [text, color] (a line's colour; numbers in the plain
## lines take `acc`). The size steps down from `size` until every line fits (never cut).
static func text(c: CanvasItem, rect: Rect2, lines: Array, size: int, base: Color, acc: Color, min_size: int = 7) -> void:
	var font: Font = ArenaUI.get_theme().default_font
	var s: int = size;var rows: Array = []
	while true:
		rows = _wrap(font, lines, rect.size.x, s)
		if rows.size() * s * 1.32 <= rect.size.y + s * .32 or s <= min_size:break
		s -= 1
	var line_h: float = s * 1.32
	var y: float = rect.position.y + (rect.size.y - rows.size() * line_h) * .5 + s
	var re := RegEx.new();re.compile("[0-9]+(\\.[0-9]+)?(%p|%|초|G|승)?")
	for row in rows:
		var x: float = rect.position.x + (rect.size.x - float(row.width)) * .5
		var col: Color = row.color
		if col.a > 0:
			c.draw_string(font, Vector2(x, y), row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
		else:
			var at: int = 0;var t: String = row.text
			for m in re.search_all(t):
				if m.get_start() > at:x = _piece(c, font, x, y, t.substr(at, m.get_start() - at), s, base)
				x = _piece(c, font, x, y, m.get_string(), s, acc);at = m.get_end()
			if at < t.length():_piece(c, font, x, y, t.substr(at), s, base)
		y += line_h
## Rows {text, width, color}: words joined by spaces, a word too wide broken by characters.
static func _wrap(font: Font, lines: Array, width: float, s: int) -> Array:
	var rows: Array = []
	for line in lines:
		var row: String = ""
		for word in str(line[0]).split(" ", false):
			var next: String = word if row.is_empty() else row + " " + word
			if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= width:row = next;continue
			if not row.is_empty():rows.append(_row(font, row, s, line[1]));row = ""
			while font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width and word.length() > 1:
				var n: int = word.length() - 1
				while n > 1 and font.get_string_size(word.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > width:n -= 1
				rows.append(_row(font, word.substr(0, n), s, line[1]));word = word.substr(n)
			row = word
		if not row.is_empty():rows.append(_row(font, row, s, line[1]))
	return rows
static func _row(font: Font, t: String, s: int, col: Color) -> Dictionary:
	return {"text": t, "width": font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x, "color": col}
static func _piece(c: CanvasItem, font: Font, x: float, y: float, t: String, s: int, col: Color) -> float:
	c.draw_string(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
	return x + font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
