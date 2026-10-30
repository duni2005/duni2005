class_name UnitRarity
extends RefCounted
## Character rarity = recruit price in tokens (1-5): 일반, 고급, 희귀, 영웅, 전설. Cards show it as a
## coloured top band, a border and a wash of the grade's colour from 고급 up, one ◆ per token and
## a light running round the border for 전설.
const NAMES = ["", "일반", "고급", "희귀", "영웅", "전설"]
const COLORS = [Color.WHITE, Color("aab4c8"), Color("6fd58a"), Color("5fb0ff"), Color("b884ff"), Color("ffc34a")]
const BORDER_ALPHA = [0.0, 0.0, .45, .6, .8, .95]
const WASH_ALPHA = [0.0, 0.0, .07, .1, .14, .16]
static var _tiers: Dictionary = {}
static var _frames: Dictionary = {}

static func tier(type_id: int) -> int:
	if not _tiers.has(type_id):
		var data: UnitData = CharacterCatalog.all().get(type_id)
		_tiers[type_id] = clampi(data.recruit_tokens, 1, 5) if data != null else 1
	return _tiers[type_id]
static func color(type_id: int) -> Color:return COLORS[tier(type_id)]
static func label(type_id: int) -> String:return NAMES[tier(type_id)]

## Wash, band and border over a card face (`rect` inside the card's own border).
static func draw_frame(c: CanvasItem, rect: Rect2, type_id: int, radius: float, dim: bool = false, border: bool = true) -> void:
	var t: int = tier(type_id);var col: Color = COLORS[t];var a: float = .45 if dim else 1.0
	if WASH_ALPHA[t] > 0:_wash(c, rect, radius, Color(col, WASH_ALPHA[t] * a))
	c.draw_rect(Rect2(rect.position + Vector2(radius * .7, 1.5), Vector2(rect.size.x - radius * 1.4, 2.5)), Color(col, .9 * a))
	if border and BORDER_ALPHA[t] > 0:
		var key: String = "%d:%d" % [t, int(radius)]
		if not _frames.has(key):
			var box := StyleBoxFlat.new();box.draw_center = false;box.set_corner_radius_all(int(radius));box.set_border_width_all(2 if t >= 4 else 1);box.anti_aliasing = true
			_frames[key] = box
		var frame: StyleBoxFlat = _frames[key];frame.border_color = Color(col, BORDER_ALPHA[t] * a)
		c.draw_style_box(frame, rect)
	if t == 5 and not dim:
		# A short gold glint travelling round the border.
		var head: float = Time.get_ticks_msec() / 1000.0 * .3;var points := PackedVector2Array();var colors := PackedColorArray()
		for i in range(11):
			var k: float = i / 10.0
			points.append(Motion.perimeter_point(rect, radius, head - .12 * (1 - k)));colors.append(Color(1, .92, .6, k * k * .9))
		c.draw_polyline_colors(points, colors, 2, true)

## Colour fading down from the top edge over the upper 45% of the face, following its rounded corners.
static func _wash(c: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	var points := PackedVector2Array();var colors := PackedColorArray();var r: float = maxf(1, radius - 1)
	var bottom: float = rect.position.y + rect.size.y * .45
	points.append(Vector2(rect.position.x + 1, bottom));colors.append(Color(col, 0))
	for i in range(7):
		points.append(rect.position + Vector2(r + 1, r + 1) + Vector2.from_angle(PI + PI * .5 * i / 6) * r);colors.append(col)
	for i in range(7):
		points.append(Vector2(rect.end.x - r - 1, rect.position.y + r + 1) + Vector2.from_angle(PI * 1.5 + PI * .5 * i / 6) * r);colors.append(col)
	points.append(Vector2(rect.end.x - 1, bottom));colors.append(Color(col, 0))
	c.draw_polygon(points, colors)

## One ◆ per token from `at` (the first diamond's centre), left to right or along `step`.
static func draw_pips(c: CanvasItem, at: Vector2, type_id: int, size: float = 3.5, dim: bool = false, step: Vector2 = Vector2.RIGHT) -> void:
	var t: int = tier(type_id);var col: Color = Color(COLORS[t], .5 if dim else 1.0)
	for i in range(t):
		var p: Vector2 = at + step * i * size * 2.3
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -size), p + Vector2(size * .8, 0), p + Vector2(0, size), p + Vector2(-size * .8, 0)]), col)

## Width of draw_pips for centring.
static func pips_width(type_id: int, size: float = 3.5) -> float:return (tier(type_id) - 1) * size * 2.3 + size * 1.6
