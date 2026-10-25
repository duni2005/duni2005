class_name TowerCinematic
extends Control
## Full-screen tower cutscenes, drawn as layered, shaded 2D art with parallax:
## "intro"  — the endless tower over a summer valley, a slow push-in, a fast zoom to the first
##            chapter's floors and the chapter title.
## "clear"  — the cleared chapter's floors glow, shake, flash and burst into rubble and dust; the
##            floors above drop into the gap; then the next chapter is introduced the same way.
## "enter"  — only the chapter title shot (resuming a run).
## Tapping skips to the fade-out. The screen's own UI fades out while this plays.
signal finished
const FH: float = 60 # one floor, world units
const TW: float = 180 # tower width at the base
const FLOORS_SHOWN: int = 44
## Painterly daylight: a soft cyan sky, warm sunlit sandstone with cool blue shadows, olive hills.
const SKY_TOP := Color("4fb4dc")
const SKY_MID := Color("8fd3ea")
const SKY_LOW := Color("dcefe6")
const HAZE := Color("cfe4ea")
const STONE_LIT := Color("ecdcb2")
const STONE := Color("bba582")
const STONE_DARK := Color("5f6a92")
const RECESS := Color("3b4670")
const CHAPTER_TINT = {1:Color("4f9c8c"), 2:Color("b8574c"), 3:Color("d2a24a")}
## Round tree crowns: soft summer greens with a few muted autumn and gold ones.
const TREE_COLORS = [Color("6c9e46"), Color("d69a52"), Color("4f8a4a"), Color("9cbc5a"), Color("5f9a55"), Color("c9a94e"), Color("3f7a52"), Color("b9764a")]
const BLOSSOM_COLORS = [Color("e3a9b8"), Color("eec3cc"), Color("f3ece6")]
var mode: String = ""
var chapter: int = 1 # chapter introduced (for "clear": the one after the cleared chapter)
var t: float = 0
var duration: float = 0
var fade_at: float = 0
var view := Vector2(390, 844)
var cam := Vector2.ZERO
var drift: float = 0 # sideways slide of the background layers only; the tower stays centred
var zoom: float = 1
var shake: float = 0
var chunks: Array = []
var motes: Array = []
var puffs: Array = []
var petals: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;visible = false
	gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed and t < fade_at:t = fade_at)

func active() -> bool:return visible
## Cutscenes play by themselves only in the real game with motion on: not with the motion
## setting off, and not under a scripted test/capture harness (a custom main loop script).
static func auto_play() -> bool:
	return UiMotion.enabled and Engine.get_main_loop().get_script() == null

func play(kind: String, intro_chapter: int) -> void:
	mode = kind;chapter = intro_chapter;t = 0;rng.seed = hash(kind + str(intro_chapter))
	duration = {"intro":9.2, "clear":10.2, "enter":3.8}[kind];fade_at = duration - .6
	chunks.clear();motes.clear();puffs.clear();petals.clear()
	for i in range(12):petals.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(3, 5.5), rng.randf_range(.3, 1), rng.randi_range(0, 2)])
	visible = true;view = get_viewport_rect().size;_camera();queue_redraw()

func _process(dt: float) -> void:
	if not visible:return
	t += dt;view = get_viewport_rect().size
	_camera()
	if t >= duration:visible = false;finished.emit();return
	queue_redraw()

# ---- Camera ----
func _ease(x: float) -> float:
	x = clampf(x, 0, 1);return x * x * (3 - 2 * x)
func _close_zoom() -> float:
	# The chapter's five floors take about half the screen height and half its width.
	return minf(view.x * .56 / TW, view.y * .46 / (5 * FH))
func _wide_zoom() -> float:
	return minf(view.x * .22 / TW, view.y / 2000.0)
## Camera position that puts the tower's foot (world y=0) at `ground` of the screen height.
func _cam_for(z: float, ground: float) -> Vector2:
	return Vector2(0, -(ground - .5) * view.y / z)
func _camera() -> void:
	var close: float = _close_zoom();shake = 0;drift = 0
	if mode == "intro":
		var wide: float = _wide_zoom()
		if t < 3.8:zoom = lerpf(wide, wide * 1.4, _ease(t / 3.8));cam = _cam_for(zoom, .84)
		elif t < 5.0:
			var k: float = clampf((t - 3.8) / 1.2, 0, 1);k = k * k * k * (k * (k * 6 - 15) + 10)
			zoom = exp(lerpf(log(wide * 1.4), log(close), k));cam = _cam_for(zoom, lerpf(.84, .86, k))
		else:zoom = close * (1 + (t - 5.0) * .012);cam = _cam_for(zoom, .86)
		# A slow sideways drift of the background over the opening shot, so the layers slide
		# past the centred tower.
		drift = 110 * (1 - _ease(t / 5.0))
	elif mode == "clear":
		var far: float = close * .74
		if t < 5.0:zoom = far;cam = _cam_for(zoom, .87)
		elif t < 6.0:zoom = exp(lerpf(log(far), log(close), _ease(t - 5.0)));cam = _cam_for(zoom, .86)
		else:zoom = close * (1 + (t - 6.0) * .012);cam = _cam_for(zoom, .86)
		if t > .5 and t < 2.3:shake = (t - .5) / 1.8 * 6
		elif t >= 2.3 and t < 2.9:shake = 11 * (1 - (t - 2.3) / .6)
		elif t >= 4.75 and t < 5.25:shake = 9 * (1 - (t - 4.75) / .5)
	else:
		zoom = close * (1 + t * .012);cam = _cam_for(zoom, .86)

func _shake() -> Vector2:return Vector2(sin(t * 53), cos(t * 41)) * shake
## Tower-world point to screen.
func to_screen(p: Vector2) -> Vector2:
	return (p - cam) * zoom + view * .5 + _shake()
## Background layers stand on the horizon (the tower's foot) and grow only a little as the
## camera pushes in: `f` 0 never scales, 1 scales with the tower. Units are phone pixels.
func _layer_scale(f: float) -> float:
	return minf(view.x / 390, view.y / 844) * pow(zoom / _close_zoom(), f)
func _layer(p: Vector2, f: float) -> Vector2:
	var s: float = _layer_scale(f)
	return Vector2(view.x * .5 + (p.x - drift * f) * s, to_screen(Vector2.ZERO).y + p.y * s) + Vector2(_shake().x, 0)

func _draw() -> void:
	var alpha: float = minf(clampf(t / (.5 if mode == "clear" else .35), 0, 1), clampf((duration - t) / .6, 0, 1))
	modulate.a = alpha
	_sky();_clouds(.08, 0);_ridge(.14, 30, 300, 1.3, Color("a9c3e6"), HAZE, true);_ridge(.22, 20, 190, 4.1, Color("8eaed6"), Color("b9d2e2"), false)
	_clouds(.2, 1);_treeline(.32, 8, 70, 2.2, Color("8eae6a"), Color("a9c27c"));_treeline(.45, 4, 40, 5.4, Color("6f9a4c"), Color("8fb45e"))
	_back_trees();_meadow();_tower();_mid_trees()
	if mode == "clear":_clear_effects()
	_front_foliage();_petals();_vignette()
	_titles()

# ---- Sky ----
func _sky() -> void:
	var horizon: float = to_screen(Vector2.ZERO).y;var mid: float = horizon * .5
	_vgradient(0, mid, SKY_TOP, SKY_MID);_vgradient(mid, horizon, SKY_MID, SKY_LOW);_vgradient(horizon, view.y, SKY_LOW, SKY_LOW)
	# Warm light washing in from the upper left, haze along the horizon.
	var sun := Vector2(-view.x * .1 - drift * .02, view.y * .02)
	VfxArt.glow(self, sun, view.x * 1.2, Color("fff1cf"), .45)
	VfxArt.glow(self, Vector2(view.x * .5, horizon), view.x * .9, Color("f4f1dc"), .5, .35)
	_birds()
func _vgradient(y0: float, y1: float, top: Color, bottom: Color) -> void:
	if y1 <= y0:return
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(view.x, y0), Vector2(view.x, y1), Vector2(0, y1)]), PackedColorArray([top, top, bottom, bottom]))

## A loose flock crossing the sky, wings flapping.
func _birds() -> void:
	for i in range(9):
		var slide: float = fposmod(i * .137 + t * (.03 + (i % 3) * .008), 1.3) - .15
		var at := Vector2(slide * view.x, view.y * (.3 + (i % 4) * .035 + (i % 2) * .02) + sin(t * 1.3 + i) * 5)
		var s: float = (4 + (i % 3) * 2) * clampf(view.x / 390, .8, 2);var flap: float = sin(t * 8 + i * 1.7)
		var tip := Vector2(s, -s * (.2 + flap * .45))
		draw_polyline(PackedVector2Array([at + Vector2(-tip.x, tip.y), at + Vector2(-s * .4, -s * .05 * flap), at, at + Vector2(s * .4, -s * .05 * flap), at + tip]), Color(1, 1, 1, .85), maxf(1.2, s * .2), true)

## Fluffy cumulus: a flat blue-grey underside beneath round white puffs.
func _cloud(center: Vector2, r: float, seed_value: int, alpha: float = 1) -> void:
	var local := RandomNumberGenerator.new();local.seed = seed_value
	var parts: Array = []
	for i in range(6):parts.append([Vector2(local.randf_range(-1.3, 1.3), local.randf_range(-.5, 0)) * r, r * local.randf_range(.36, .66)])
	parts.append([Vector2(local.randf_range(-.3, .3), -.4) * r, r * .72])
	# Flat-bottomed base, shaded underside, then the lit puffs.
	draw_set_transform(center + Vector2(0, r * .12), 0, Vector2(1, .22));draw_circle(Vector2.ZERO, r * 1.45, Color("c3d6ec", .95 * alpha));draw_set_transform(Vector2.ZERO)
	for p in parts:draw_circle(center + p[0] + Vector2(0, r * .14), p[1], Color("c3d6ec", .95 * alpha))
	for p in parts:draw_circle(center + p[0], p[1], Color("f4f6f2", .97 * alpha))
	for p in parts.slice(0, 4):draw_circle(center + p[0] + Vector2(-p[1] * .2, -p[1] * .22), p[1] * .5, Color("fffbef", alpha))
## Clouds keep to the sky beside and below the title, drifting with the wind.
func _clouds(f: float, layer: int) -> void:
	var s: float = _layer_scale(f)
	for i in range(5):
		var x: float = fposmod(i * 260 + layer * 130 + t * (10 + layer * 8), 1300) - 650
		var y: float = -470 - (i % 2) * 70 if layer == 0 else -300 - (i % 3) * 40
		_cloud(_layer(Vector2(x, y), f), (34 + (i % 3) * 12) * s * (1.4 if layer == 0 else 1.0), i * 31 + layer * 7, .75 if layer == 0 else .95)

# ---- Land ----
func _ridge(f: float, base: float, amp: float, seed_value: float, top: Color, bottom: Color, snow: bool) -> void:
	var pts := PackedVector2Array();var colors := PackedColorArray();var peaks: Array = []
	var prev: float = 0;var rising: bool = false
	for i in range(101):
		var x: float = -1500 + i * 30
		var h: float = amp * (.55 + .3 * sin(x * .0062 + seed_value) + .18 * sin(x * .017 + seed_value * 2.3) + .07 * sin(x * .041 + seed_value))
		if i > 0 and h < prev and rising:peaks.append(pts[pts.size() - 1])
		rising = h > prev;prev = h
		pts.append(_layer(Vector2(x, base - h), f));colors.append(top)
	pts.append(Vector2(pts[pts.size() - 1].x, view.y + 40));colors.append(bottom)
	pts.append(Vector2(pts[0].x, view.y + 40));colors.append(bottom)
	draw_polygon(pts, colors)
	if snow:
		var s: float = 30 * _layer_scale(f)
		for p in peaks:draw_colored_polygon(PackedVector2Array([p, p + Vector2(s * .8, s * .55), p + Vector2(s * .3, s * .42), p + Vector2(0, s * .6), p + Vector2(-s * .35, s * .4), p + Vector2(-s * .8, s * .55)]), Color("eef3fb", .8))
## A distant forest edge: a rolling hill topped with scalloped tree crowns.
func _treeline(f: float, base: float, amp: float, seed_value: float, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array();var colors := PackedColorArray()
	for i in range(241):
		var x: float = -1200 + i * 10
		var bump: float = sin(fposmod(x + seed_value * 40, 26) / 26 * PI) * (9 + 4 * sin(x * .05 + seed_value))
		var h: float = amp * (.6 + .3 * sin(x * .008 + seed_value) + .1 * sin(x * .021 + seed_value)) + bump
		pts.append(_layer(Vector2(x, base - h), f));colors.append(top)
	pts.append(Vector2(pts[pts.size() - 1].x, view.y + 40));colors.append(bottom)
	pts.append(Vector2(pts[0].x, view.y + 40));colors.append(bottom)
	draw_polygon(pts, colors)

func _tree(base: Vector2, h: float, kind: int, color: Color, seed_value: int, haze: float = 0) -> void:
	if base.x < -h or base.x > view.x + h or h < 2:return
	var bark: Color = Color("6b5440").lerp(HAZE, haze);color = color.lerp(HAZE, haze)
	var trunk_w: float = maxf(1.5, h * .06)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-trunk_w, 0), base + Vector2(trunk_w, 0), base + Vector2(trunk_w * .45, -h * .62), base + Vector2(-trunk_w * .45, -h * .62)]), bark)
	draw_rect(Rect2(base + Vector2(-h * .3, -h * .02), Vector2(h * .6, h * .04)), Color(0, 0, 0, .12))
	if kind == 1:
		# Conifer: stacked tiers, lit on the left.
		for k in range(4):
			var top: Vector2 = base + Vector2(0, -h * (1.05 - k * .17));var w: float = h * (.16 + k * .06);var bot: float = top.y + h * .36
			draw_colored_polygon(PackedVector2Array([top, Vector2(top.x, bot), Vector2(top.x - w, bot)]), color.lightened(.1))
			draw_colored_polygon(PackedVector2Array([top, Vector2(top.x + w, bot), Vector2(top.x, bot)]), color.darkened(.22))
		return
	var c: Vector2 = base + Vector2(0, -h * .72);var r: float = h * .33
	var spots: Array = [Vector2(-.55, .15), Vector2(.55, .2), Vector2(0, -.4), Vector2(-.3, -.15), Vector2(.35, -.2), Vector2(0, .25)]
	for p in spots:draw_circle(c + p * r + Vector2(r * .08, r * .1), r * .62, color.darkened(.3))
	for p in spots:draw_circle(c + p * r, r * .56, color)
	for p in spots.slice(2, 5):draw_circle(c + p * r + Vector2(-r * .16, -r * .18), r * .3, color.lightened(.16))
	if kind == 2:
		# Blossom: a scatter of light flowers.
		# Seeded per tree (not by screen position) so the blossoms hold still as the camera moves.
		var local := RandomNumberGenerator.new();local.seed = seed_value
		for i in range(8):draw_circle(c + Vector2(local.randf_range(-.8, .8), local.randf_range(-.7, .4)) * r, maxf(1, r * .08), Color("fff3f8", .9))
func _tree_color(i: int, kind: int) -> Color:
	if kind == 1:return [Color("3f6e4a"), Color("4a7d52"), Color("355f45")][i % 3]
	if kind == 2:return BLOSSOM_COLORS[i % BLOSSOM_COLORS.size()]
	return TREE_COLORS[i % TREE_COLORS.size()]
func _back_trees() -> void:
	var s: float = _layer_scale(.6)
	for i in range(22):
		var x: float = -1100 + i * 100 + (i % 3) * 22
		if absf(x) < 60:continue
		var kind: int = 1 if i % 3 == 1 else 2 if i % 7 == 3 else 0
		_tree(_layer(Vector2(x, 2), .6), (46 + (i % 4) * 10) * s, kind, _tree_color(i * 3, kind), i, .3)
func _meadow() -> void:
	# Rolling green ground from the tower's foot to the bottom of the screen.
	var pts := PackedVector2Array();var colors := PackedColorArray()
	for i in range(81):
		var x: float = -4000 + i * 100;pts.append(to_screen(Vector2(x, sin(x * .004) * 8 - 3)));colors.append(Color("a9c862"))
	pts.append(Vector2(pts[pts.size() - 1].x, view.y + 40));colors.append(Color("5e8c3c"))
	pts.append(Vector2(pts[0].x, view.y + 40));colors.append(Color("5e8c3c"))
	draw_polygon(pts, colors)
	# The tower's shadow on the grass, then a dirt path to the door.
	var foot: Vector2 = to_screen(Vector2.ZERO)
	draw_set_transform(foot + Vector2(TW * zoom * .25, 4 * zoom), 0, Vector2(1, .16));draw_circle(Vector2.ZERO, TW * zoom * 1.1, Color(.15, .25, .35, .22));draw_set_transform(Vector2.ZERO)
	var far_l: Vector2 = to_screen(Vector2(-24, 4));var far_r: Vector2 = to_screen(Vector2(24, 4))
	var near_y: float = view.y + 40;var spread: float = (far_r.x - far_l.x) * 5
	var path := PackedVector2Array([far_l, far_r]);var path_colors := PackedColorArray([Color("d8c79a"), Color("d8c79a")])
	for k in range(9):
		var u: float = k / 8.0;path.append(Vector2(foot.x + spread * (1 - u * 2) + sin(u * PI * 2) * spread * .2, near_y));path_colors.append(Color("e8d8a8"))
	draw_polygon(path, path_colors)
	# Grass tufts and wildflowers, bigger towards the viewer.
	var local := RandomNumberGenerator.new();local.seed = 77
	for i in range(90):
		var p: Vector2 = to_screen(Vector2(local.randf_range(-1100, 1100), local.randf_range(8, 420)))
		if p.y > view.y + 10 or p.y < 0:continue
		var s: float = maxf(2, 5 * zoom * (1 + (p.y / view.y)))
		draw_polyline(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(-s * .3, -s * 1.6), p, p + Vector2(s * .4, -s * 1.8), p + Vector2(s, 0)]), Color("5d8a3a", .8), maxf(1, s * .3))
		if i % 3 == 0:draw_circle(p + Vector2(0, -s * 1.5), maxf(1.2, s * .35), [Color("fff7e6"), Color("f1d77a"), Color("e9b4c4")][i % 9 / 3])

# ---- The tower ----
## Every chapter is one tier of the tower: a sturdy base, lit storeys, a feature window and a
## crenellated gallery that juts out on top. Tiers step in as they climb.
func _tower() -> void:
	var gone: bool = false;var glow: float = 0;var drop: float = 0
	if mode == "clear":
		gone = t >= 2.3;glow = clampf((t - .5) / 1.8, 0, 1)
		# Floors above the cleared chapter wait, then fall into the gap with gravity.
		drop = 5 * FH * (1 - pow(clampf((t - 3.9) / .85, 0, 1), 2)) if t >= 3.9 else 5 * FH
	var base_floor: int = (chapter - 2) * 5 if mode == "clear" else (chapter - 1) * 5
	# Top down, so each gallery stands in front of the tier above it.
	for i in range(FLOORS_SHOWN - 1, -1, -1):
		var y0: float = -(i + 1) * FH
		if mode == "clear":
			if i < 5 and gone:continue
			if i >= 5:y0 = -(i - 4) * FH - drop
		_floor(base_floor + i, i, y0, glow if mode == "clear" and i < 5 else 0.0)
	_plinth()
	# Outline the introduced chapter during the title shot.
	var shown: float = 5.0 if mode == "intro" else 6.0 if mode == "clear" else 0.0
	if t > shown:
		var k: float = clampf((t - shown) / .6, 0, 1);var tint: Color = CHAPTER_TINT.get(chapter, Color("ffd27a"))
		var first: int = (chapter - 1) * 5
		var a: Vector2 = to_screen(Vector2(-_width(first) * .62, -5 * FH - 22));var b: Vector2 = to_screen(Vector2(_width(first) * .62, 2))
		VfxArt.glow(self, (a + b) * .5, (b - a).length() * .65, tint, .14 * k)
		for corner in [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
			var dx: float = 16 if corner.x < (a.x + b.x) * .5 else -16;var dy: float = 16 if corner.y < (a.y + b.y) * .5 else -16
			draw_polyline(PackedVector2Array([corner + Vector2(dx * k, 0), corner, corner + Vector2(0, dy * k)]), Color(tint.lightened(.45), .9 * k), 2.5)
func _width(floor: int) -> float:
	return TW * (1 - .045 * mini(floor / 5, 8))
func _plinth() -> void:
	var w: float = TW * 1.24
	for step in range(3):
		var a: Vector2 = to_screen(Vector2(-w * .5 - step * 10, -7 + step * 4));var b: Vector2 = to_screen(Vector2(w * .5 + step * 10, -3 + step * 4))
		draw_rect(Rect2(a, b - a), STONE.lerp(STONE_LIT, .35 - step * .12))
		draw_line(a, Vector2(b.x, a.y), Color(1, 1, 1, .22), 1)
func _floor(floor: int, index: int, y0: float, glow: float) -> void:
	var tier: int = floor / 5;var k: int = floor % 5
	var w: float = _width(floor) * (1.04 if k == 0 else 1.0);var a: Vector2 = to_screen(Vector2(-w * .5, y0));var b: Vector2 = to_screen(Vector2(w * .5, y0 + FH))
	if b.y < -80 or a.y > view.y + 80:return
	var W: float = b.x - a.x;var H: float = b.y - a.y
	var fade: float = clampf((index - 8.0) / 26.0, 0, 1) # higher floors melt into the haze
	var warm: float = .5 if tier % 2 == 1 else 0.0
	# Rounded stone: vertical strips lit from the left.
	var strips: int = 12
	for j in range(strips):
		var u0: float = float(j) / strips;var u1: float = float(j + 1) / strips
		var c0: Color = _stone(u0, warm).lerp(HAZE, fade * .85);var c1: Color = _stone(u1, warm).lerp(HAZE, fade * .85)
		draw_polygon(PackedVector2Array([Vector2(a.x + W * u0, a.y), Vector2(a.x + W * u1, a.y), Vector2(a.x + W * u1, b.y), Vector2(a.x + W * u0, b.y)]), PackedColorArray([c0, c1, c1, c0]))
	var ink: float = 1 - fade
	if H > 18:
		# Masonry courses, joints squeezed towards the curved edges.
		for r in range(1, 4):
			var y: float = a.y + H * r / 4;draw_line(Vector2(a.x, y), Vector2(b.x, y), Color(.3, .32, .45, .16 * ink), 1)
			for j in range(7):
				var x: float = a.x + W * (.5 + .5 * sin(((j + (.5 if r % 2 else 0.0)) / 7.0 - .5) * PI));draw_line(Vector2(x, y - H / 4), Vector2(x, y), Color(.3, .32, .45, .1 * ink), 1)
	# Corner pilasters frame every storey.
	for u in [.07, .93]:
		var px: float = a.x + W * u;var pw: float = W * .045
		draw_rect(Rect2(Vector2(px - pw * .5, a.y), Vector2(pw, H)), Color(1, 1, .9, .1 * ink) if u < .5 else Color(.2, .25, .45, .14 * ink))
	if H > 10:
		if k == 0:
			if floor == 0 and index == 0 and mode != "clear":_door(a, W, H)
			else:
				for th in [-.9, 0.0, .9]:_window(_on_drum(a, W, th, H * .26), W * .14 * cos(th), H * .6, 0, fade, false)
		elif k == 2:
			if tier % 2 == 0:_rose(Vector2(a.x + W * .5, a.y + H * .52), minf(W * .16, H * .36), glow, fade)
			else:
				for th in [-.18, .18]:_window(_on_drum(a, W, th, H * .2), W * .1, H * .64, glow, fade, true)
		else:
			var spots: Array = [-.95, -.35, .35, .95] if (k + tier) % 2 == 0 else [-.7, 0.0, .7]
			for th in spots:_window(_on_drum(a, W, th, H * .26), W * .11 * cos(th), H * .52, glow, fade, true)
	# Each tier's base course; a crenellated gallery on corbels tops the tier.
	if k == 0:
		var band: float = maxf(2, H * .1)
		draw_rect(Rect2(Vector2(a.x - W * .02, b.y - band), Vector2(W * 1.04, band)), STONE_DARK.lerp(STONE, .5).lerp(HAZE, fade * .85))
		draw_line(Vector2(a.x - W * .02, b.y - band), Vector2(b.x + W * .02, b.y - band), Color(1, 1, 1, .18 * ink), 1)
	if k == 4 and H > 6:_gallery(a, W, H, floor, fade)
	if (k == 0 or k == 4) and H > 10 and fade < .9:
		var moss := RandomNumberGenerator.new();moss.seed = floor * 31 + 7
		for m in range(5):
			var at := Vector2(a.x + W * moss.randf_range(.05, .95), b.y - (H * .1 if k == 0 else H))
			draw_set_transform(at, 0, Vector2(1, .45));draw_circle(Vector2.ZERO, W * moss.randf_range(.03, .06), Color("86ad4f", .8 * ink));draw_circle(Vector2(-W * .01, -W * .01), W * .02, Color("a9c866", .8 * ink));draw_set_transform(Vector2.ZERO)
	# Vines on some floors.
	var local := RandomNumberGenerator.new();local.seed = floor * 977 + 13
	for v in range(2):
		if local.randf() < .4 and fade < .8:
			var x: float = a.x + W * local.randf_range(.1, .9);var length: float = H * local.randf_range(.5, 1.3)
			var pts := PackedVector2Array()
			for s in range(7):pts.append(Vector2(x + sin(s * .9 + t * 1.5 + floor) * W * .012, a.y + length * s / 6.0))
			draw_polyline(pts, Color("3f7f3b", .9 - fade), maxf(1, W * .01))
			for s in range(1, 7, 2):draw_circle(pts[s] + Vector2(W * .012, 0), maxf(1.4, W * .014), Color("5fae4e", .9 - fade))
	# Silhouette: a light rim on the sun side, a dark edge on the other.
	draw_line(a, Vector2(a.x, b.y), Color(1, 1, .92, .3 * ink), 1);draw_line(Vector2(b.x, a.y), b, Color(STONE_DARK.darkened(.2), .7 * ink), 1.5)
	if glow > 0:
		# Charging before the burst: white-hot cracks and a pulsing veil.
		draw_rect(Rect2(a, Vector2(W, H)), Color(1, .96, .85, glow * .4 * (.7 + .3 * sin(t * 18 + index))))
		for c in range(3):
			var p := Vector2(a.x + W * (.15 + c * .33), a.y)
			draw_polyline(PackedVector2Array([p, p + Vector2(W * .05, H * .4), p + Vector2(-W * .03, H * .7), p + Vector2(W * .02, H)]), Color(1, 1, .92, glow), maxf(1, W * .012))
## A point on the round wall: `theta` is the angle around the drum, 0 facing the viewer.
func _on_drum(a: Vector2, W: float, theta: float, y: float) -> Vector2:
	return Vector2(a.x + W * (.5 + .45 * sin(theta)), a.y + y)
func _stone(u: float, warm: float) -> Color:
	var light: float = clampf(cos((u - .3) * PI * .95), -1, 1)
	var lit: Color = STONE_LIT.lerp(Color("f1d6a8"), warm);var mid: Color = STONE.lerp(Color("c09f80"), warm)
	return STONE_DARK.lerp(mid, clampf(light + .55, 0, 1)) if light < .45 else mid.lerp(lit, (light - .45) / .55)
func _window(top: Vector2, w: float, h: float, glow: float, fade: float, lit_up: bool) -> void:
	if w < 1.5:return
	var frame := PackedVector2Array();var inner := PackedVector2Array();var colors := PackedColorArray()
	for k in range(7):
		var ang: float = PI + k * PI / 6;frame.append(top + Vector2(cos(ang) * w * .65, h * .28 + sin(ang) * h * .32))
	frame.append(top + Vector2(w * .65, h));frame.append(top + Vector2(-w * .65, h))
	draw_colored_polygon(frame, STONE.darkened(.25).lerp(HAZE, fade * .8))
	var lit: Color = Color("4a5a88").lerp(Color("fffbe8"), glow);var deep: Color = RECESS.lerp(Color("fff1c8"), glow)
	if not lit_up:lit = RECESS.darkened(.2);deep = RECESS
	for k in range(7):
		var ang: float = PI + k * PI / 6;inner.append(top + Vector2(cos(ang) * w * .45, h * .3 + sin(ang) * h * .26));colors.append(lit.lerp(HAZE, fade * .8))
	inner.append(top + Vector2(w * .45, h * .92));colors.append(deep.lerp(HAZE, fade * .8))
	inner.append(top + Vector2(-w * .45, h * .92));colors.append(deep.lerp(HAZE, fade * .8))
	draw_polygon(inner, colors)
	if lit_up:draw_line(top + Vector2(0, h * .05), top + Vector2(0, h * .92), Color(STONE.darkened(.25), .8 * (1 - fade)), maxf(1, w * .08))
	draw_rect(Rect2(top + Vector2(-w * .75, h), Vector2(w * 1.5, maxf(1.5, h * .07))), STONE_LIT.lerp(HAZE, fade * .8))
## Round rose window with tracery.
func _rose(c: Vector2, r: float, glow: float, fade: float) -> void:
	var tracery: Color = STONE.darkened(.1).lerp(HAZE, fade * .8)
	draw_circle(c, r * 1.15, tracery)
	draw_circle(c, r, RECESS.lerp(Color("fff1c8"), glow).lerp(HAZE, fade * .8));draw_circle(c, r * .55, Color("6a7aa8").lerp(Color("fffbe8"), glow).lerp(HAZE, fade * .8))
	for s in range(8):draw_line(c, c + Vector2.from_angle(s * PI / 4) * r, tracery, maxf(1, r * .1))
	draw_arc(c, r * .55, 0, TAU, 24, tracery, maxf(1, r * .08), true)
	draw_circle(c, r * .16, tracery)
func _gallery(a: Vector2, W: float, H: float, floor: int, fade: float) -> void:
	var band: float = maxf(2, H * .14);var x0: float = a.x - W * .08;var gw: float = W * 1.16
	var stone: Color = STONE.lerp(STONE_LIT, .45).lerp(HAZE, fade * .85)
	# Corbels under the walkway.
	var corbels: int = 9
	for m in range(corbels):
		var cx: float = x0 + gw * (m + .5) / corbels;var cw: float = gw / corbels * .5
		draw_colored_polygon(PackedVector2Array([Vector2(cx - cw * .5, a.y + band * .5), Vector2(cx + cw * .5, a.y + band * .5), Vector2(cx + cw * .2, a.y + band * 1.4), Vector2(cx - cw * .2, a.y + band * 1.4)]), STONE_DARK.lerp(STONE, .5).lerp(HAZE, fade * .85))
	draw_rect(Rect2(Vector2(x0, a.y - band * .5), Vector2(gw, band)), stone)
	draw_line(Vector2(x0, a.y - band * .5), Vector2(x0 + gw, a.y - band * .5), Color(1, 1, 1, .25 * (1 - fade)), 1)
	# Crenellations: merlons with a lit face.
	var merlon: float = gw / 11;var mh: float = H * .24
	for m in range(6):
		var r := Rect2(Vector2(x0 + m * merlon * 2, a.y - band * .5 - mh), Vector2(merlon, mh))
		draw_rect(r, stone);draw_rect(Rect2(r.position, Vector2(r.size.x * .3, r.size.y)), Color(1, 1, 1, .08 * (1 - fade)))
	var tint: Color = CHAPTER_TINT.get(floor / 5 + 1, Color("8a4e4f")).lerp(HAZE, fade * .7)
	for u in [.16, .84]:_banner(Vector2(a.x + W * u, a.y + band * 1.4), W * .1, H * .7, tint)
	for u in [-.05, 1.05]:_torch(Vector2(a.x + W * u, a.y - band * .5 - mh), H * .14, fade)
func _banner(at: Vector2, w: float, h: float, tint: Color) -> void:
	var sway: float = sin(t * 2 + at.x * .01) * w * .08
	draw_colored_polygon(PackedVector2Array([at + Vector2(-w * .5, 0), at + Vector2(w * .5, 0), at + Vector2(w * .5 + sway, h), at + Vector2(sway, h * .82), at + Vector2(-w * .5 + sway, h)]), tint)
	draw_rect(Rect2(at + Vector2(-w * .5, 0), Vector2(w * .22, h * .9)), Color(1, 1, 1, .12))
	draw_rect(Rect2(at + Vector2(-w * .6, -1), Vector2(w * 1.2, maxf(1.5, h * .05))), Color("c9a560"))
	draw_circle(at + Vector2(sway * .5, h * .4), w * .22, Color("f4d27a", .9))
func _torch(at: Vector2, s: float, fade: float) -> void:
	var flick: float = .85 + .15 * sin(t * 13 + at.x)
	VfxArt.glow(self, at, s * 3.2 * flick, Color("ffb35a"), .45 * (1 - fade))
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 1.3 * flick), at + Vector2(s * .45, 0), at + Vector2(-s * .45, 0)]), Color("ffd27a", 1 - fade))
func _door(a: Vector2, W: float, H: float) -> void:
	var c := Vector2(a.x + W * .5, a.y + H);var w: float = W * .22;var h: float = H * .8
	var pts := PackedVector2Array([c + Vector2(-w * .5, 0), c + Vector2(-w * .5, -h * .6)])
	for k in range(1, 6):
		var ang: float = PI + k * PI / 6;pts.append(c + Vector2(cos(ang) * w * .5, -h * .6 + sin(ang) * h * .4))
	pts.append(c + Vector2(w * .5, -h * .6));pts.append(c + Vector2(w * .5, 0))
	var arch := PackedVector2Array()
	for p in pts:arch.append(c + (p - c) * Vector2(1.25, 1.1))
	draw_colored_polygon(arch, STONE_LIT);draw_colored_polygon(pts, Color("4a3a30"));draw_polyline(pts, Color("9a7a4a"), maxf(1, W * .012))
	draw_line(c, c + Vector2(0, -h * .95), Color("1e130b"), maxf(1, W * .01))
	for side in [-1, 1]:_torch(c + Vector2(side * w * .85, -h * .62), H * .11, 0)

# ---- Foreground ----
func _mid_trees() -> void:
	# Trees beside the tower, kept clear of it.
	for i in range(10):
		var side: float = -1.0 if i % 2 == 0 else 1.0;var x: float = side * (TW * .95 + (i / 2) * 150 + (i % 3) * 20)
		var kind: int = 1 if i % 5 == 3 else 2 if i % 4 == 1 else 0
		_tree(to_screen(Vector2(x, 4)), (140 + (i % 3) * 40) * zoom, kind, _tree_color(i * 5 + 1, kind), 100 + i)
func _leaf(root: Vector2, dir: Vector2, length: float, width: float, color: Color) -> void:
	var n: Vector2 = dir.orthogonal();var pts := PackedVector2Array();var colors := PackedColorArray()
	for k in range(9):
		var u: float = k / 8.0;pts.append(root + dir * length * u + n * width * sin(u * PI));colors.append(color.darkened(.25).lerp(color.lightened(.15), u))
	for k in range(7, 0, -1):
		var u: float = k / 8.0;pts.append(root + dir * length * u - n * width * sin(u * PI) * .8);colors.append(color.darkened(.35).lerp(color, u))
	draw_polygon(pts, colors);draw_line(root, root + dir * length * .92, color.lightened(.2), maxf(1, width * .08))
func _front_foliage() -> void:
	# Leaves framing the bottom corners.
	var s: float = clampf(view.x / 390, .9, 2.2)
	for side in [-1.0, 1.0]:
		var corner := Vector2(view.x * .5 + side * view.x * .56, view.y + 14)
		for k in range(6):
			var ang: float = -PI * .5 + side * (k * .2 - .2) - side * .55 + sin(t * 1.2 + k) * .03
			_leaf(corner, Vector2.from_angle(ang), (120 + (k % 3) * 36) * s, (18 + (k % 2) * 7) * s, Color("31523a") if k % 2 else Color("3d6544"))
func _petals() -> void:
	for p in petals:
		var at := Vector2(fposmod(p[0].x + t * .05 * p[2], 1.1) * view.x, fposmod(p[0].y + t * .06 * p[2], 1) * view.y)
		var c: Color = [Color("f3dbe0"), Color("fff6dc"), Color("b7d68a")][p[3]]
		draw_set_transform(at, t * 2 * p[2] + p[0].x * 9, Vector2(1, .5));draw_circle(Vector2.ZERO, p[1], Color(c, .8));draw_set_transform(Vector2.ZERO)
func _vignette() -> void:
	_vgradient(view.y * .88, view.y, Color(.1, .14, .1, 0), Color(.1, .14, .1, .35))

# ---- Chapter clear: flash, rubble, dust ----
func _clear_effects() -> void:
	if t >= 2.3 and chunks.is_empty():
		for i in range(110):
			var x: float = rng.randf_range(-TW * .5, TW * .5);var corners: Array = []
			for k in range(4):corners.append(Vector2.from_angle(k * PI / 2 + rng.randf_range(-.4, .4)) * rng.randf_range(.6, 1.1))
			chunks.append({"p":Vector2(x, -rng.randf_range(0, 5 * FH)), "v":Vector2(x * rng.randf_range(1.5, 4.5), rng.randf_range(-320, 40)), "s":rng.randf_range(4, 14), "r":rng.randf_range(-6, 6), "c":STONE.lerp(STONE_LIT, rng.randf()), "k":corners})
		for i in range(140):
			motes.append({"p":Vector2(rng.randf_range(-TW * .55, TW * .55), -rng.randf_range(0, 5 * FH)), "v":Vector2(rng.randf_range(-40, 40), -rng.randf_range(20, 110)), "s":rng.randf_range(1.2, 3.2), "life":rng.randf_range(1.6, 3.2)})
		for i in range(16):
			puffs.append({"p":Vector2(rng.randf_range(-TW * .5, TW * .5), -rng.randf_range(0, 5 * FH)), "v":Vector2(rng.randf_range(-60, 60), rng.randf_range(-30, 10)), "r":rng.randf_range(40, 80)})
	if t >= 2.3:
		var age: float = t - 2.3
		# Shock ring and a bright core.
		var core: Vector2 = to_screen(Vector2(0, -2.5 * FH))
		VfxArt.glow(self, core, TW * zoom * (1.3 + age * 1.2), Color("f2f0ea"), clampf(.75 - age * .35, 0, .75))
		if age < .9:draw_arc(core, TW * zoom * (.4 + age * 3), 0, TAU, 64, Color(1, .96, .85, (1 - age / .9) * .7), maxf(2, 10 * (1 - age / .9)), true)
		# Dust clouds billowing out and thinning.
		for p in puffs:
			var at: Vector2 = to_screen(p.p + p.v * age);var a: float = clampf(1 - age / 3.2, 0, 1) * .55
			VfxArt.glow(self, at, p.r * zoom * (1 + age * .8), Color("d9d2c4"), a)
		for c in chunks:
			var p: Vector2 = c.p + c.v * age + Vector2(0, 260 * age * age);var a: float = clampf(1 - age / 1.9, 0, 1)
			var s: Vector2 = to_screen(p);var r: float = c.s * zoom * .5
			if r < .4 or a <= 0:continue
			var poly := PackedVector2Array()
			for corner in c.k:poly.append(s + (corner as Vector2).rotated(c.r * age) * r)
			draw_colored_polygon(poly, Color(c.c, a));draw_line(poly[0], poly[1], Color(1, 1, 1, .3 * a), 1)
		# The floors crumble to glittering dust that drifts up and fades.
		for m in motes:
			var k: float = age / m.life
			if k >= 1:continue
			var at: Vector2 = to_screen(m.p + m.v * age + Vector2(sin(age * 3 + m.p.x) * 8, 0));var a: float = sin(k * PI)
			VfxArt.glow(self, at, m.s * 3 * maxf(1, zoom), Color("ffe9b0"), .35 * a);draw_circle(at, m.s * maxf(.8, zoom * .7), Color(1, .97, .86, a))
		var flash: float = clampf(1 - age / .6, 0, 1)
		if flash > 0:draw_rect(Rect2(Vector2.ZERO, view), Color(1, .99, .94, flash))
	elif t > .5:
		VfxArt.glow(self, to_screen(Vector2(0, -2.5 * FH)), TW * zoom * 1.5, Color("fff4d2"), clampf((t - .5) / 1.8, 0, 1) * .55)
		# Light gathers into the chapter before it bursts.
		for i in range(14):
			var k: float = fposmod(t * .9 + i * .071, 1.0);var dir: Vector2 = Vector2.from_angle(i * 2.4)
			var at: Vector2 = to_screen(Vector2(0, -2.5 * FH) + dir * TW * 1.3 * (1 - k))
			draw_circle(at, 2.5 * maxf(1, zoom), Color(1, .95, .8, k * clampf((t - .5) / 1.8, 0, 1)))
	# The falling tower lands: dust rolls out from the foot.
	if t >= 4.75 and t < 6.0:
		var k: float = (t - 4.75) / 1.25
		for side in [-1, 1]:
			for j in range(3):VfxArt.glow(self, to_screen(Vector2(side * TW * (.5 + k * (1 + j * .4)), -12 - j * 10)), 50 * zoom * (1 + k * 2), Color("e8e2d6"), (1 - k) * .5)

# ---- Text ----
func _titles() -> void:
	var font: Font = ArenaUI.heading_font();var numbers: Font = ArenaUI.numbers_font()
	if mode == "intro" and t > .9 and t < 3.9:
		var a: float = minf(clampf((t - .9) / .6, 0, 1), clampf((3.9 - t) / .5, 0, 1))
		var size: float = clampf(view.x * .15, 40, 80);var y: float = view.y * .19 - (1 - a) * 8
		VfxArt.glow(self, Vector2(view.x * .5, y - size * .3), view.x * .5, Color(.02, .08, .2), .35 * a, .45)
		_kicker(numbers, "DUNI ARENA", y - size * .95, Color(1, .86, .52), a)
		_text(font, "두니 타워", Vector2(view.x * .5, y), size, Color(1, .98, .9, a), a, true)
		_text(font, "끝없이 하늘로 뻗은 탑", Vector2(view.x * .5, y + size * .6), 16, Color(.94, .97, 1, .95 * a), a)
	if mode == "clear" and t > 2.45 and t < 4.6:
		var a: float = minf(clampf((t - 2.45) / .25, 0, 1), clampf((4.6 - t) / .4, 0, 1));var pop: float = 1 + (1 - clampf((t - 2.45) / .3, 0, 1)) * .3
		VfxArt.glow(self, Vector2(view.x * .5, view.y * .2), view.x * .55, Color(.02, .06, .16), .4 * a, .5)
		_text(numbers, "CHAPTER %d CLEAR" % (chapter - 1), Vector2(view.x * .5, view.y * .2), clampf(view.x * .1, 28, 60) * pop, Color(1, .88, .5, a), a, true)
		_text(font, "%s 정복" % TowerSceneDirector.CHAPTER_NAMES.get(chapter - 1, ""), Vector2(view.x * .5, view.y * .2 + 40), 18, Color(1, 1, 1, a), a)
	var title_at: float = {"intro":5.1, "clear":6.1, "enter":.3}.get(mode, 0.0)
	if t > title_at and t < fade_at + .6:
		var k: float = clampf((t - title_at) / .5, 0, 1);var a: float = minf(k, clampf((fade_at + .4 - t) / .4, 0, 1))
		var first: int = (chapter - 1) * 5 + 1;var y: float = view.y * .1
		# Dark band behind the title so it reads over the sky and the tower.
		_vgradient(0, view.y * .3, Color(.06, .1, .16, .6 * a), Color(.06, .1, .16, 0))
		var tint: Color = CHAPTER_TINT.get(chapter, Color("ffd27a")).lightened(.5)
		_kicker(numbers, "CHAPTER %d" % chapter, y - (1 - k) * 10, tint, a)
		_text(font, TowerSceneDirector.CHAPTER_NAMES.get(chapter, ""), Vector2(view.x * .5, y + 52), clampf(view.x * .11, 32, 62), Color(1, .98, .92, a), a, true)
		_text(font, "%d층 – %d층" % [first, first + 4], Vector2(view.x * .5, y + 84), 15, Color(.85, .9, 1, .9 * a), a)
	if t < fade_at:draw_string(get_theme_default_font(), Vector2(0, view.y - 18), "화면을 누르면 건너뜁니다  ", HORIZONTAL_ALIGNMENT_RIGHT, view.x, 11, Color(1, 1, 1, .5))

## Small spaced caption between two ornamented rules.
func _kicker(font: Font, text: String, y: float, tint: Color, a: float) -> void:
	_text(font, text, Vector2(view.x * .5, y), 16, Color(tint, a), a)
	var half: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * .5 + 12;var line_w: float = minf(90, view.x * .2) * a
	for side in [-1, 1]:
		var from := Vector2(view.x * .5 + side * half, y - 6);draw_line(from, from + Vector2(side * line_w, 0), Color(tint, .8 * a), 1.5)
		var tip: Vector2 = from + Vector2(side * line_w, 0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -3), tip + Vector2(side * 4, 0), tip + Vector2(0, 3), tip + Vector2(-side * 4, 0)]), Color(tint, a))
func _text(font: Font, text: String, center: Vector2, size: float, color: Color, alpha: float, gilded: bool = false) -> void:
	draw_string(font, Vector2(2, center.y + 3), text, HORIZONTAL_ALIGNMENT_CENTER, view.x, int(size), Color(.02, .05, .14, .55 * alpha))
	draw_string_outline(font, Vector2(0, center.y), text, HORIZONTAL_ALIGNMENT_CENTER, view.x, int(size), maxi(3, int(size * (.16 if gilded else .1))), Color(.02, .06, .16, .75 * alpha))
	if gilded:draw_string_outline(font, Vector2(0, center.y), text, HORIZONTAL_ALIGNMENT_CENTER, view.x, int(size), maxi(2, int(size * .07)), Color(.86, .66, .3, alpha))
	draw_string(font, Vector2(0, center.y), text, HORIZONTAL_ALIGNMENT_CENTER, view.x, int(size), color)
