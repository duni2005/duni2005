class_name TitleScenery
extends Control
## Main menu scenery, painted in depth layers like a cutscene: bright sky, drifting clouds, snowy
## far mountains, the distant DUNI tower on its ridge, a green valley with a winding road, and
## dark foliage up close. A virtual 1000x1600 canvas covers the screen, kept centered on the tower.
##   play_entry(): layers rise into place (near ones last) while the camera settles back.
##   play_dive(done): the camera pushes into the tower; near layers rush past, then `done` runs.
signal dive_finished
const VIEW := Vector2(1000, 1600)
## Tower base on its ridge; layers scale about this point when diving in.
const TOWER := Vector2(560, 700)
const ENTRY_TIME: float = 2.4
const DIVE_TIME: float = 1.5
var time: float = 0
var entry: float = 1
var dive: float = 0
var clouds: Array = []
var trees: Dictionary = {}
var pines: Array = []
var birds: Array = []
var sky: GradientTexture2D
var glow: GradientTexture2D
var shade: GradientTexture2D
var haze: GradientTexture2D
var tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky = _gradient([[0, Color("2f74c6")], [.42, Color("7db7e8")], [.62, Color("d3e9f1")], [1, Color("eaf3e1")]])
	shade = _gradient([[0, Color(0, 0, 0, 0)], [1, Color("0c1a24", .55)]])
	haze = _gradient([[0, Color(.93, .97, 1, 0)], [.6, Color(.93, .97, 1, .45)], [1, Color(.93, .97, 1, 0)]])
	var g := Gradient.new();g.set_color(0, Color(1, .98, .9, .75));g.set_color(1, Color(1, .98, .9, 0))
	glow = GradientTexture2D.new();glow.gradient = g;glow.fill = GradientTexture2D.FILL_RADIAL;glow.fill_from = Vector2(.5, .5);glow.fill_to = Vector2(1, .5);glow.width = 128;glow.height = 128
	var rng := RandomNumberGenerator.new();rng.seed = 7
	for c in [[180, 230, 1.6, 6], [770, 320, 1.35, 9], [500, 110, 1.0, 5], [110, 470, .7, 11], [930, 520, .6, 7], [380, 380, .55, 8]]:
		var blobs: Array = []
		var count: int = rng.randi_range(7, 10)
		for i in range(count):
			var t: float = float(i) / (count - 1)
			var r: float = (34 + 46 * sin(t * PI)) * rng.randf_range(.8, 1.15)
			blobs.append([Vector2((t - .5) * 260, -sin(t * PI) * 38 + rng.randf_range(-10, 10)), r])
		clouds.append({"x":float(c[0]), "y":float(c[1]), "s":float(c[2]), "speed":float(c[3]), "blobs":blobs})
	for band in [["valley", 26, 790.0, 70.0, 6.0, 10.0], ["mid", 22, 905.0, 110.0, 14.0, 26.0], ["near", 12, 1130.0, 120.0, 30.0, 52.0]]:
		var list: Array = []
		for i in range(band[1]):
			var x: float = rng.randf_range(-120, 1120)
			if band[0] != "valley" and absf(x - _road_x(_hill(band[0], x))) < 70:continue
			list.append([Vector2(x, _hill(band[0], x) + rng.randf_range(0, band[3])), rng.randf_range(band[4], band[5])])
		list.sort_custom(func(a, b):return a[0].y < b[0].y)
		trees[band[0]] = list
	for i in range(30):
		var t: float = rng.randf()
		pines.append([Vector2(-60, 560).lerp(Vector2(470, 1010), t) + Vector2(rng.randf_range(-20, 20), rng.randf_range(0, 70)), rng.randf_range(16, 30)])
	pines.sort_custom(func(a, b):return a[0].y < b[0].y)
	for i in range(4):birds.append([rng.randf_range(0, 1000), rng.randf_range(250, 520), rng.randf_range(14, 24), rng.randf_range(0, TAU)])
	resized.connect(queue_redraw)

func _process(dt: float) -> void:
	if is_visible_in_tree():time += dt;queue_redraw()

func play_entry() -> void:
	if tween != null:tween.kill()
	dive = 0
	if not UiMotion.enabled:entry = 1;return
	entry = 0;tween = create_tween();tween.tween_property(self, "entry", 1.0, ENTRY_TIME)

func play_dive() -> void:
	if tween != null:tween.kill()
	if not UiMotion.enabled:dive = 0;dive_finished.emit();return
	dive = 0;tween = create_tween();tween.tween_property(self, "dive", 1.0, DIVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():dive_finished.emit())

# --- Canvas fit and layer transforms ---------------------------------------------------------
## Covers the screen. Wide screens zoom less (the layers reach 200 past each side) so the
## tower stays whole; the sky above it stays in view.
func _fit() -> Array:
	var k: float = maxf(maxf(size.x / (VIEW.x + 400), size.y / VIEW.y), minf(maxf(size.x / VIEW.x, size.y / VIEW.y), size.y / 640))
	var off := Vector2((size.x - VIEW.x * k) * .5, maxf(size.y * .42 - TOWER.y * k, -200 * k))
	off.y = clampf(off.y, size.y - VIEW.y * k, 0)
	return [k, off]
## Sets the transform of a layer at `depth` (0 far ... 1 nearest).
func _layer(depth: float) -> void:
	var fit: Array = _fit();var k: float = fit[0];var off: Vector2 = fit[1]
	var rise: float = _ease_out(clampf(entry * 1.3 - depth * .3, 0, 1))
	var s: float = 1 + dive * dive * (.2 + depth * 3.4) + (1 - _ease_out(entry)) * .07
	var shift := Vector2(sin(time * .13) * 9 * depth, (1 - rise) * 420 * depth)
	draw_set_transform(off + k * (TOWER - TOWER * s + shift), 0, Vector2.ONE * k * s)
static func _ease_out(t: float) -> float:return 1 - pow(1 - t, 3)

# --- Shapes ------------------------------------------------------------------------------------
func _hill(band: String, x: float) -> float:
	match band:
		"ridge":return 735 - 38 * exp(-pow((x - TOWER.x) / 120, 2)) + sin(x * .011) * 10
		"valley":return 790 + sin(x * .007 + 1) * 14
		"mid":return 905 + sin(x * .006) * 26 + sin(x * .019 + 2) * 9
		"near":return 1130 + sin(x * .005 + 2) * 40 + sin(x * .021) * 12
	return 0
## The road's centre at a given height (it winds from the bottom up toward the tower).
func _road_x(y: float) -> float:
	var t: float = clampf((y - 760) / 900, 0, 1)
	return lerpf(TOWER.x - 30, 330, t) + sin(t * 5.2) * 120 * t
func _band(band: String, color: Color, bottom: float = 1800) -> void:
	var points := PackedVector2Array()
	for i in range(0, 71):
		var x: float = -200 + i * 20;points.append(Vector2(x, _hill(band, x)))
	points.append(Vector2(1200, bottom));points.append(Vector2(-200, bottom))
	draw_colored_polygon(points, color)
func _ridge(peaks: Array, base: float, color: Color, snow: bool) -> void:
	var points := PackedVector2Array()
	for p in peaks:points.append(Vector2(p[0], p[1]))
	points.append(Vector2(1200, base));points.append(Vector2(-200, base))
	draw_colored_polygon(points, color)
	if not snow:return
	for i in range(1, peaks.size() - 1):
		var p := Vector2(peaks[i][0], peaks[i][1])
		var l := Vector2(peaks[i - 1][0], peaks[i - 1][1]);var r := Vector2(peaks[i + 1][0], peaks[i + 1][1])
		if p.y > 600 or p.y > l.y or p.y > r.y:continue
		# Snow cap: the peak, its two flanks a quarter of the way down, a jagged lower edge between.
		var a: Vector2 = p.lerp(l, .28);var b: Vector2 = p.lerp(r, .28)
		draw_colored_polygon(PackedVector2Array([p, b, b.lerp(a, .33) + Vector2(0, 9), b.lerp(a, .66) + Vector2(0, -3), a]), Color("f2f6ff", .92))
func _road(from_y: float, to_y: float, w0: float, w1: float, color: Color, edge: Color) -> void:
	var left := PackedVector2Array();var right := PackedVector2Array()
	for i in range(13):
		var t: float = i / 12.0;var y: float = lerpf(from_y, to_y, t);var w: float = lerpf(w0, w1, t);var x: float = _road_x(y)
		left.append(Vector2(x - w * .5, y));right.append(Vector2(x + w * .5, y))
	var ribbon := left.duplicate();right.reverse();ribbon.append_array(right)
	draw_colored_polygon(ribbon, color)
	draw_polyline(left, edge, maxf(1.5, w0 * .06), true)
func _tree(at: Vector2, r: float, dark: Color, light: Color) -> void:
	draw_circle(at + Vector2(0, r * .25), r, dark)
	draw_circle(at + Vector2(-r * .35, -r * .15), r * .72, dark.lerp(light, .5))
	draw_circle(at + Vector2(r * .3, -r * .35), r * .55, light)
func _cloud(c: Dictionary) -> void:
	var x: float = fposmod(c.x + time * c.speed + 400, 1900) - 400;var origin := Vector2(x, c.y);var s: float = c.s
	for b in c.blobs:draw_circle(origin + b[0] * s + Vector2(0, b[1] * s * .2), b[1] * s, Color("bfd3ec"))
	for b in c.blobs:draw_circle(origin + b[0] * s, b[1] * s * .96, Color("fbfdff"))
	for b in c.blobs:draw_circle(origin + b[0] * s + Vector2(-b[1] * s * .2, -b[1] * s * .25), b[1] * s * .5, Color(1, 1, 1, .6))
func _tower() -> void:
	var base := TOWER;var tiers: Array = [[96, 70], [78, 60], [64, 52], [52, 44], [42, 36]]
	# Outer walls and corner turrets at the foot.
	for k in [-1, 1]:
		var at := base + Vector2(k * 70, 0)
		draw_rect(Rect2(at.x - 13, at.y - 58, 26, 58), Color("6b7cb2") if k < 0 else Color("94a6d6"))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-17, -58), at + Vector2(17, -58), at + Vector2(0, -84)]), Color("55619a"))
	draw_rect(Rect2(base.x - 70, base.y - 34, 140, 34), Color("7d8ec2"))
	for i in range(7):draw_rect(Rect2(base.x - 66 + i * 20, base.y - 40, 10, 7), Color("7d8ec2"))
	var y: float = base.y
	for i in range(tiers.size()):
		var w0: float = tiers[i][0];var w1: float = tiers[i + 1][0] if i + 1 < tiers.size() else w0 * .82;var h: float = tiers[i][1]
		var bl := Vector2(base.x - w0 * .5, y);var br := Vector2(base.x + w0 * .5, y);var tr := Vector2(base.x + w1 * .5, y - h);var tl := Vector2(base.x - w1 * .5, y - h)
		draw_colored_polygon(PackedVector2Array([bl, br, tr, tl]), Color("6b7cb2"))
		draw_colored_polygon(PackedVector2Array([Vector2(base.x + w0 * .12, y), br, tr, Vector2(base.x + w1 * .12, y - h)]), Color("a7b7e2"))
		draw_rect(Rect2(base.x - w1 * .5 - 5, y - h - 5, w1 + 10, 6), Color("4d5a8f"))
		for k in [-1, 1]:
			var glow_on: float = .55 + .45 * sin(time * 1.3 + i * 1.7 + k)
			draw_rect(Rect2(base.x + k * w1 * .2 - 3, y - h * .62, 6, h * .3), Color("ffe6a0", .55 + .35 * glow_on))
		y -= h
	var top := Vector2(base.x, y - 6)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-20, 0), top + Vector2(20, 0), top + Vector2(0, -46)]), Color("55619a"))
	var gem: Vector2 = top + Vector2(0, -60);var pulse: float = .5 + .5 * sin(time * 2)
	draw_texture_rect(glow, Rect2(gem - Vector2(70, 70) * (1 + pulse * .15), Vector2(140, 140) * (1 + pulse * .15)), false, Color(.85, .75, 1, .9))
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -16), gem + Vector2(10, 0), gem + Vector2(0, 16), gem + Vector2(-10, 0)]), Color("e6d6ff"))
	draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -16), gem + Vector2(10, 0), gem + Vector2(0, 2)]), Color("ffffff"))
func _house(at: Vector2, roof: Color) -> void:
	draw_rect(Rect2(at + Vector2(-11, -8), Vector2(22, 12)), Color("efe6d6"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-14, -8), at + Vector2(14, -8), at + Vector2(8, -17), at + Vector2(-8, -17)]), roof)

# --- Paint ---------------------------------------------------------------------------------------
func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(sky, Rect2(Vector2.ZERO, size), false)
	_layer(0)
	draw_texture_rect(glow, Rect2(Vector2(820, 250) - Vector2(560, 560), Vector2(1120, 1120)), false)
	for i in range(5):
		var a: float = 2.2 + i * .12 + sin(time * .1 + i) * .02
		draw_colored_polygon(PackedVector2Array([Vector2(820, 250), Vector2(820, 250) + Vector2.from_angle(a - .03) * 1500, Vector2(820, 250) + Vector2.from_angle(a + .03) * 1500]), Color(1, 1, .95, .045))
	_layer(.05)
	for c in clouds:_cloud(c)
	_layer(.08)
	for b in birds:
		var p := Vector2(fposmod(b[0] + time * b[2], 1200) - 100, b[1] + sin(time * .8 + b[3]) * 8);var flap: float = sin(time * 6 + b[3]) * 5
		draw_polyline(PackedVector2Array([p + Vector2(-9, -flap), p, p + Vector2(9, -flap)]), Color("2c4a6e", .7), 2, true)
	_layer(.12)
	_ridge([[-200, 640], [-40, 560], [120, 480], [250, 560], [380, 520], [520, 600], [640, 455], [790, 540], [900, 490], [1040, 570], [1200, 620]], 900, Color("a6b9e3"), true)
	_ridge([[-200, 720], [40, 640], [200, 700], [330, 650], [470, 720], [690, 660], [860, 715], [1000, 650], [1200, 700]], 900, Color("8098d0"), true)
	draw_texture_rect(haze, Rect2(-300, 600, 1600, 220), false)
	_layer(.2)
	_band("ridge", Color("8fbca6"), 1000)
	_tower()
	_layer(.32)
	_band("valley", Color("b5dd6c"), 1100)
	for i in range(6):draw_rect(Rect2(-100 + i * 210, 800 + (i % 3) * 22, 150, 9), Color("c8e884", .7))
	_road(760, 905, 6, 16, Color("ddc896"), Color("b89d70"))
	for h in [[240, 860, "c4553f"], [282, 868, "4f7fc2"], [322, 852, "c4553f"], [705, 880, "c4553f"], [742, 872, "4f7fc2"]]:_house(Vector2(h[0], h[1]), Color(h[2]))
	for t in trees.valley:_tree(t[0], t[1], Color("4e8f4a"), Color("6eb25a"))
	_layer(.5)
	_band("mid", Color("8bcd4c"))
	_road(905, 1130, 16, 54, Color("d6b57f"), Color("b58f63"))
	for t in trees.mid:_tree(t[0], t[1], Color("3c824d"), Color("5aa65a"))
	_layer(.6)
	draw_colored_polygon(PackedVector2Array([Vector2(-220, 520), Vector2(-40, 560), Vector2(160, 690), Vector2(330, 840), Vector2(470, 1010), Vector2(500, 1120), Vector2(-220, 1250)]), Color("6dbb46"))
	draw_colored_polygon(PackedVector2Array([Vector2(-220, 700), Vector2(120, 760), Vector2(300, 900), Vector2(420, 1060), Vector2(-220, 1180)]), Color("5aa83f"))
	for p in pines:
		var at: Vector2 = p[0];var r: float = p[1]
		for k in range(3):draw_colored_polygon(PackedVector2Array([at + Vector2(-r * (1 - k * .22), k * -r * .5), at + Vector2(r * (1 - k * .22), k * -r * .5), at + Vector2(0, -r * (1.2 + k * .55))]), Color("2f6a50") if k % 2 == 0 else Color("3b7b5b"))
	_layer(.78)
	_band("near", Color("5fae3c"))
	_road(1130, 1420, 54, 150, Color("c9a072"), Color("a5805a"))
	for t in trees.near:_tree(t[0], t[1], Color("2e6b52"), Color("3f8661"))
	_layer(1)
	_road(1420, 1800, 150, 360, Color("bb9068"), Color("9a7352"))
	for b in [[Vector2(-40, 1450), 150], [Vector2(110, 1560), 120], [Vector2(-20, 1700), 160], [Vector2(980, 1420), 140], [Vector2(1060, 1560), 170], [Vector2(860, 1660), 110]]:
		draw_circle(b[0], b[1], Color("1e4c47"));draw_circle(b[0] + Vector2(b[1] * .25, -b[1] * .3), b[1] * .6, Color("2a6157"))
	draw_set_transform(Vector2.ZERO)
	# Darker lower half so the menu reads over the scenery; the dive ends in a soft white-out.
	draw_texture_rect(shade, Rect2(0, size.y * .45, size.x, size.y * .55), false)
	if dive > .55:draw_rect(Rect2(Vector2.ZERO, size), Color(.97, .98, 1, smoothstep(.55, 1, dive)))
	if entry < 1:draw_rect(Rect2(Vector2.ZERO, size), Color(.97, .98, 1, (1 - smoothstep(0, .35, entry)) * .8))
static func _gradient(stops: Array) -> GradientTexture2D:
	var g := Gradient.new();g.offsets = PackedFloat32Array(stops.map(func(s):return float(s[0])));g.colors = PackedColorArray(stops.map(func(s):return s[1]))
	var t := GradientTexture2D.new();t.gradient = g;t.fill_from = Vector2(0, 0);t.fill_to = Vector2(0, 1);t.width = 4;t.height = 256;return t
