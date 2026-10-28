class_name TypeArt
extends RefCounted
## Drawing pieces for the typographic motion language: slanted panels, large translucent English
## words, letters rising one by one, a light streak, a centre-out gold rule and drifting motes.
## Pure draw calls on a given canvas; no nodes, no randomness, no allocation beyond the polygons.
const NAVY := Color("0b1122")
const INDIGO := Color("1b2a55")
const STEEL := Color("2c3f78")

## English display words for screens and rooms (the large translucent words behind titles).
const WORDS := {&"guild":"GUILD", &"tower":"TOWER", &"map":"MAP", &"menu":"DUNI ARENA", &"custom":"ARENA",
	&"battle":"BATTLE", &"recruit":"RECRUIT", &"shop":"SHOP", &"rest":"REST", &"event":"EVENT",
	&"boss":"BOSS", &"miniboss":"ELITE", &"victory":"VICTORY", &"defeat":"DEFEAT", &"retreat":"RETREAT",
	&"turning":"TURNING POINT", &"chapter":"CHAPTER", &"clear":"CLEAR", &"blacksmith":"FORGE", &"mangoSapling":"MANGO TREE"}

static func word(key: StringName) -> String:return WORDS.get(key, String(key).to_upper())
## A room's word: its event's own word when it has one (the blacksmith), else its room type's.
static func room_word(room: RoomState) -> String:return word(room.event_type if WORDS.has(room.event_type) else room.room_type)

## A parallelogram band across `rect`, slanted by `slant` (its top edge sits `slant` further along).
## `lead` and `tail` are the band's leading and trailing x at the bottom edge. With `back` the band
## runs right to left.
static func band(rect: Rect2, lead: float, tail: float, slant: float, back: bool = false) -> PackedVector2Array:
	var y0: float = rect.position.y;var y1: float = rect.end.y
	var pts := PackedVector2Array([Vector2(tail + slant, y0), Vector2(lead + slant, y0), Vector2(lead, y1), Vector2(tail, y1)])
	if back:
		for i in range(pts.size()):pts[i].x = rect.position.x + rect.end.x - pts[i].x
	return pts

## Layered slanted panels sweeping across a horizontal strip: they come in fast (out-expo) one after
## another, hold, then leave the same way they travel (in-cubic). `t` runs 0..1 over the whole cycle.
## Returns the front panel's leading edge so callers can trail effects behind it.
static func panels(canvas: CanvasItem, strip: Rect2, t: float, back: bool = false, colors: Array = [NAVY, INDIGO, STEEL], hold: float = .45, edge: Color = ArenaUI.GOLD) -> float:
	var w: float = strip.size.x;var slant: float = strip.size.y * .35;var front_lead: float = 0
	var n: int = colors.size();var front := PackedVector2Array()
	# The front panel lies underneath; later ones stack on top, so their edges show as stripes.
	for i in range(n):
		var lead: float = lerpf(-slant - 4, w + 4, Motion.out_expo(Motion.phase(t, i * .06, .32)))
		var tail: float = lerpf(-slant - w * .2, w + slant + 4, Motion.in_cubic(Motion.phase(t, hold + (n - 1 - i) * .05, .35)))
		if lead <= tail:continue
		var pts: PackedVector2Array = band(Rect2(strip.position.x, strip.position.y, w, strip.size.y), strip.position.x + lead, strip.position.x + tail, slant, back)
		canvas.draw_colored_polygon(pts, colors[i])
		if i == 0:front = pts;front_lead = lead
	if not front.is_empty():canvas.draw_line(front[1], front[2], edge, 2, true);canvas.draw_line(front[0], front[3], Color(edge, .55), 1, true)
	return front_lead

## A large English word, translucent and slanted; `spacing` widens the letters (pixels per letter).
static func watermark(canvas: CanvasItem, text: String, center: Vector2, size: int, color: Color, slant: float = -.22, spacing: float = 0) -> void:
	if color.a <= .002 or text.is_empty():return
	var font: Font = ArenaUI.numbers_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing * (text.length() - 1)
	canvas.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(slant, 1), center))
	var x: float = -width * .5;var y: float = size * .36
	if is_zero_approx(spacing):canvas.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	else:
		for ch in text:
			canvas.draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

## Letters rising into place one after another (baseline-left at `at`); `t` is seconds since start.
## Each letter rises `rise` pixels over Motion.ENTER on the out-expo curve, Motion.LETTER apart.
static func letters(canvas: CanvasItem, font: Font, text: String, at: Vector2, size: int, color: Color, t: float, rise: float, outline: Color = Color(0, 0, 0, 0)) -> float:
	var x: float = 0
	for i in range(text.length()):
		var ch: String = text[i];var k: float = Motion.out_expo(Motion.phase(t, i * Motion.LETTER, Motion.ENTER))
		var w: float = font.get_string_size(text.substr(0, i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if k > 0:
			var p: Vector2 = at + Vector2(x, (1 - k) * rise)
			if outline.a > 0:canvas.draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(2, size / 9), Color(outline, outline.a * k))
			canvas.draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, color.a * minf(1, k * 1.6)))
		x = w
	return x

## Seconds until `letters` has finished for `text`.
static func letters_time(text: String) -> float:return maxi(0, text.length() - 1) * Motion.LETTER + Motion.ENTER

## A slanted light streak crossing `rect` once as `k` runs 0..1, clipped to the rectangle.
static func sweep(canvas: CanvasItem, rect: Rect2, k: float, strength: float = .22, width: float = 26) -> void:
	if k <= 0 or k >= 1 or rect.size.x < 2 or rect.size.y < 2:return
	var slant: float = rect.size.y * .6;var x: float = lerpf(rect.position.x - width - slant, rect.end.x, k)
	var streak := PackedVector2Array([Vector2(x + slant, rect.position.y), Vector2(x + slant + width, rect.position.y), Vector2(x + width, rect.end.y), Vector2(x, rect.end.y)])
	var box := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var a: float = strength * sin(k * PI)
	for piece in Geometry2D.intersect_polygons(streak, box):
		# Slivers at the rectangle's edge cannot be triangulated; they would be invisible anyway.
		if piece.size() >= 3 and absf(_area(piece)) > 2:canvas.draw_colored_polygon(piece, Color(1, .97, .88, a))

static func _area(points: PackedVector2Array) -> float:
	var sum: float = 0
	for i in range(points.size()):sum += points[i].cross(points[(i + 1) % points.size()])
	return sum * .5

## A rule drawn out from its centre to both sides as `k` runs 0..1.
static func rule(canvas: CanvasItem, center: Vector2, half_width: float, k: float, color: Color, width: float = 1) -> void:
	var h: float = half_width * Motion.out_expo(k)
	if h > .5:canvas.draw_line(center - Vector2(h, 0), center + Vector2(h, 0), color, width)

## Deterministic motes drifting through `rect`: rising for triumph, falling for loss.
static func motes(canvas: CanvasItem, rect: Rect2, t: float, color: Color, count: int = 24, rising: bool = true, speed: float = .18) -> void:
	for i in range(count):
		var sx: float = sin(i * 12.98 + 3.14) * .5 + .5;var v: float = speed * (.6 + (sin(i * 4.1) * .5 + .5) * .8)
		var k: float = fposmod(t * v + sin(i * 7.7) * .5 + .5, 1.0)
		var y: float = rect.end.y - k * rect.size.y if rising else rect.position.y + k * rect.size.y
		var at := Vector2(rect.position.x + sx * rect.size.x + sin(t * 1.7 + i) * 6, y)
		var a: float = color.a * sin(k * PI)
		canvas.draw_circle(at, 1.2 + i % 3 * .7, Color(color, a))
		if rising and i % 4 == 0:canvas.draw_line(at, at + Vector2(0, 7 + i % 3 * 3), Color(color, a * .5), 1)
