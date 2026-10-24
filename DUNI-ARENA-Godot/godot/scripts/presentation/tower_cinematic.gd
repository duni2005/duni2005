class_name TowerCinematic
extends Control
## Full-screen tower cutscenes, drawn as layered flat 2D art with parallax:
## "intro"  — the endless tower from afar, a slow push-in, a fast zoom to the first chapter's floors
##            and the chapter title.
## "clear"  — the cleared chapter's floors glow, shake, flash and burst into dust; the floors above
##            drop into the gap; then the next chapter is introduced the same way.
## "enter"  — only the chapter title shot (resuming a run).
## Tapping skips to the fade-out. The screen's own UI fades out while this plays.
signal finished
const FH: float = 70 # one floor, world units
const TW: float = 210 # tower width
const FLOORS_SHOWN: int = 46
const SKY_TOP := Color("2c6cc6")
const SKY_MID := Color("6db3ea")
const SKY_LOW := Color("c4ecf7")
## Tree crowns: greens with autumn orange, blossom pink and spring yellow-green.
const TREE_COLORS = [Color("3f9a52"), Color("2f7d46"), Color("e08a3c"), Color("5cae4c"), Color("e58fb0"), Color("9cc84e"), Color("2c6e45"), Color("d9b23e")]
const CHAPTER_TINT = {1:Color("3fa596"),2:Color("c4524e"),3:Color("e0b04a")}
var mode: String = ""
var chapter: int = 1 # chapter introduced (for "clear": the one that follows the cleared chapter)
var t: float = 0
var duration: float = 0
var fade_at: float = 0
var view: Vector2
var cam := Vector2.ZERO
var zoom: float = 1
var shake: float = 0
var chunks: Array = []
var motes: Array = []
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
	duration = {"intro":8.6, "clear":9.8, "enter":3.8}[kind];fade_at = duration - .6
	chunks.clear();motes.clear()
	for i in range(40):motes.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(2, 7), rng.randf_range(.2, .8)])
	visible = true;queue_redraw()

func _process(dt: float) -> void:
	if not visible:return
	t += dt;view = get_viewport_rect().size
	_camera()
	if t >= duration:visible = false;finished.emit();return
	queue_redraw()

func _ease(x: float) -> float:
	x = clampf(x, 0, 1);return x * x * (3 - 2 * x)
func _frame_zoom() -> float:
	return view.y / (5 * FH + 230)
## Camera path per mode, in world units (tower base at y=0, floors go up to negative y).
func _camera() -> void:
	var near: float = _frame_zoom();var chapter_cam := Vector2(0, -FH * 2.5 - 10)
	shake = 0
	if mode == "intro":
		var wide: float = view.y / 3400.0
		if t < 3.6:
			var k: float = _ease(t / 3.6);cam = Vector2(0, -1700).lerp(Vector2(0, -1050), k);zoom = lerpf(wide, wide * 1.3, k)
		else:
			var k: float = clampf((t - 3.6) / 1.0, 0, 1);k = k * k * k * (k * (k * 6 - 15) + 10)
			cam = Vector2(0, -1050).lerp(chapter_cam, k);zoom = lerpf(wide * 1.3, near, k)
			if t > 4.6:cam.y -= (t - 4.6) * 6
	elif mode == "clear":
		var far: float = near * .62
		if t < 4.9:cam = Vector2(0, -FH * 4);zoom = far
		elif t < 5.9:
			var k: float = _ease((t - 4.9) / 1.0);cam = Vector2(0, -FH * 4).lerp(chapter_cam, k);zoom = lerpf(far, near, k)
		else:cam = chapter_cam - Vector2(0, (t - 5.9) * 6);zoom = near
		if t > .5 and t < 2.3:shake = (t - .5) / 1.8 * 7
		elif t >= 2.3 and t < 2.9:shake = 10 * (1 - (t - 2.3) / .6)
		elif t >= 4.75 and t < 5.2:shake = 9 * (1 - (t - 4.75) / .45)
	else:
		cam = chapter_cam - Vector2(0, t * 6);zoom = near

func to_screen(p: Vector2, parallax: float = 1) -> Vector2:
	var z: float = pow(zoom, parallax)
	return (p - cam * parallax) * z + view * .5 + Vector2(sin(t * 53), cos(t * 41)) * shake

func _draw() -> void:
	view = get_viewport_rect().size
	var alpha: float = minf(clampf(t / .35, 0, 1), clampf((duration - t) / .6, 0, 1))
	if mode == "clear":alpha = minf(clampf(t / .5, 0, 1), clampf((duration - t) / .6, 0, 1))
	modulate.a = alpha
	_sky();_clouds();_hills();_tower();_jungle();_foreground();_motes()
	if mode == "clear":_clear_effects()
	_letterbox()
	_titles()

# ---- Background layers ----
func _sky() -> void:
	var mid: float = view.y * .55
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(view.x, 0), Vector2(view.x, mid), Vector2(0, mid)]), PackedColorArray([SKY_TOP, SKY_TOP, SKY_MID, SKY_MID]))
	draw_polygon(PackedVector2Array([Vector2(0, mid), Vector2(view.x, mid), view, Vector2(0, view.y)]), PackedColorArray([SKY_MID, SKY_MID, SKY_LOW, SKY_LOW]))
	var sun: Vector2 = to_screen(Vector2(-300, -2600), .08);VfxArt.glow(self, sun, view.x * .6, Color("fff8de"), .5)
	draw_circle(sun, view.x * .07, Color("fffbea", .95))
	_birds()

## A loose flock crossing the sky, wings flapping.
func _birds() -> void:
	for i in range(9):
		var drift: float = fposmod(i * .137 + t * (.035 + (i % 3) * .008), 1.3) - .15
		var at := Vector2(drift * view.x, view.y * (.14 + (i % 4) * .05) + sin(t * 1.3 + i) * 6)
		var s: float = (7 + (i % 3) * 2.5) * clampf(view.x / 390, .8, 2);var flap: float = sin(t * 9 + i * 1.7) * .55
		var wing := Vector2(s, -s * (.35 + flap * .5))
		draw_polyline(PackedVector2Array([at - wing, at, at + Vector2(wing.x, wing.y)]), Color("23304d", .8), maxf(1.5, s * .22), true)

func _blob(center: Vector2, r: float, color: Color, seed_value: int) -> void:
	var local := RandomNumberGenerator.new();local.seed = seed_value
	for i in range(6):draw_circle(center + Vector2(local.randf_range(-1.4, 1.4), local.randf_range(-.4, .3)) * r, r * local.randf_range(.55, .95), color)

func _clouds() -> void:
	for i in range(14):
		var at := Vector2(-1100 + i * 170, -2500 + (i % 4) * 560 - (i % 3) * 120)
		_blob(to_screen(at, .25), 90 * pow(zoom, .25) * (1 + (i % 3) * .3), Color("ffffff", .88) if i % 2 == 0 else Color("e6f4ff", .8), i * 31)

func _hills() -> void:
	# Two green mountain ridges, then colourful trees behind the tower on green ground.
	for layer in range(2):
		var pts := PackedVector2Array();var f: float = .35 + layer * .15
		for i in range(25):
			var x: float = -2400 + i * 200;var h: float = (300 - layer * 120) + sin(i * 1.7 + layer * 2) * 110 + cos(i * .6) * 60
			pts.append(to_screen(Vector2(x, -40 - h), f))
		pts.append(to_screen(Vector2(2600, 400), f));pts.append(to_screen(Vector2(-2400, 400), f))
		draw_colored_polygon(pts, Color("6fa889") if layer == 0 else Color("4e9467"))
	var ground: Vector2 = to_screen(Vector2(0, 20), .72)
	draw_rect(Rect2(Vector2(0, ground.y), Vector2(view.x, view.y - ground.y + 20)), Color("4f9a4a"))
	for i in range(16):
		var x: float = -1700 + i * 220 + (i % 2) * 60;var f: float = .72
		var top: Vector2 = to_screen(Vector2(x, -240 - (i % 4) * 55), f);var base: Vector2 = to_screen(Vector2(x, 60), f)
		draw_line(top, base, Color("5b3d2e"), maxf(2, 12 * pow(zoom, f)))
		_blob(top, 60 * pow(zoom, f), TREE_COLORS[(i * 3) % TREE_COLORS.size()].lightened(.12), i * 13)

# ---- The tower ----
func _tower() -> void:
	var cleared_drop: float = 0;var gone: bool = false;var glow: float = 0
	if mode == "clear":
		gone = t >= 2.3
		glow = clampf((t - .5) / 1.8, 0, 1)
		# Upper floors fall into the gap once the cleared chapter is gone.
		cleared_drop = 5 * FH * (1 - clampf(pow(clampf((t - 3.9) / .85, 0, 1), 2), 0, 1)) if t >= 3.9 else 5 * FH
	var base_floor: int = (chapter - 2) * 5 if mode == "clear" else (chapter - 1) * 5
	# Ground plinth.
	var g0: Vector2 = to_screen(Vector2(-TW * .8, 0));var g1: Vector2 = to_screen(Vector2(TW * .8, 40))
	draw_rect(Rect2(g0, g1 - g0), Color("3d3a48"))
	for i in range(FLOORS_SHOWN):
		var floor: int = base_floor + i;var y0: float = -(i + 1) * FH
		if mode == "clear":
			if i < 5 and gone:continue
			# The floors above the cleared chapter keep their height until they drop.
			if i >= 5:y0 = -(i - 4) * FH - cleared_drop
		_floor_band(floor, y0, i, glow if (mode == "clear" and i < 5) else 0.0)
	# Highlight the introduced chapter's floors during the title shot.
	if (mode == "intro" and t > 4.4) or mode == "enter" or (mode == "clear" and t > 5.6):
		var k: float = clampf((t - (4.4 if mode == "intro" else 5.6 if mode == "clear" else 0)) / .6, 0, 1)
		var a: Vector2 = to_screen(Vector2(-TW * .5 - 8, -5 * FH));var b: Vector2 = to_screen(Vector2(TW * .5 + 8, 0))
		var tint: Color = CHAPTER_TINT.get(chapter, Color("ffd27a"))
		draw_rect(Rect2(a, b - a), Color(tint.lightened(.3), .7 * k), false, 3)
		VfxArt.glow(self, (a + b) * .5, (b - a).length() * .6, tint, .18 * k)

func _floor_band(floor: int, y0: float, index: int, glow: float) -> void:
	var a: Vector2 = to_screen(Vector2(-TW * .5, y0));var b: Vector2 = to_screen(Vector2(TW * .5, y0 + FH))
	if b.y < -40 or a.y > view.y + 40:return
	var height_fade: float = clampf(float(index) / FLOORS_SHOWN, 0, 1)
	# Dark weathered stone that thins into the blue haze higher up.
	var stone: Color = Color("57536a").lerp(Color("9fb8d6"), height_fade * .85)
	var body := Rect2(a, b - a);var w: float = body.size.x
	# Lit left face, shaded right face.
	draw_rect(body, stone)
	draw_rect(Rect2(body.position, Vector2(w * .28, body.size.y)), stone.lightened(.12))
	draw_rect(Rect2(body.position + Vector2(w * .7, 0), Vector2(w * .3, body.size.y)), stone.darkened(.18))
	# Cornice; every chapter's last floor wears its colour.
	var cornice_h: float = maxf(2, body.size.y * .14)
	var chapter_end: bool = floor % 5 == 4
	draw_rect(Rect2(body.position - Vector2(w * .05, cornice_h * .3), Vector2(w * 1.1, cornice_h)), CHAPTER_TINT.get(floor / 5 + 1, Color("8a4e4f")).darkened(.2) if chapter_end else stone.darkened(.28))
	# Rim light on the sunny edge, shadow under the cornice.
	draw_rect(Rect2(body.position, Vector2(maxf(1, w * .02), body.size.y)), Color(.85, .92, 1, .45))
	draw_rect(Rect2(body.position + Vector2(0, cornice_h * .7), Vector2(w, maxf(1, body.size.y * .06))), Color(0, 0, 0, .12))
	var local := RandomNumberGenerator.new();local.seed = floor * 977 + 13
	# Arched windows with warm light; every third floor gets a wide arcade instead.
	var count: int = 2 if floor % 3 == 1 else 3
	if body.size.y > 10:
		for k in range(count):
			var cx: float = body.position.x + w * ((.3 + k * .4) if count == 2 else (.22 + k * .28));var top: float = body.position.y + body.size.y * .34
			var ww: float = w * .1;var wh: float = body.size.y * .44
			var light: Color = Color("ffd9a0").lerp(Color("fff8e8"), glow)
			draw_rect(Rect2(Vector2(cx - ww * .5, top + ww * .5), Vector2(ww, wh - ww * .5)), Color(light, .85 - height_fade * .5))
			draw_circle(Vector2(cx, top + ww * .5), ww * .5, Color(light, .85 - height_fade * .5))
	# A chapter banner on some floors, moss on the ledge.
	if local.randf() < .35 and body.size.y > 14:
		var bx: float = body.position.x + w * local.randf_range(.1, .85);var bw: float = w * .07
		var tint: Color = CHAPTER_TINT.get(floor / 5 + 1, Color("8a4e4f"))
		draw_colored_polygon(PackedVector2Array([Vector2(bx, body.position.y + cornice_h), Vector2(bx + bw, body.position.y + cornice_h), Vector2(bx + bw, body.position.y + body.size.y * .75), Vector2(bx + bw * .5, body.position.y + body.size.y * .62), Vector2(bx, body.position.y + body.size.y * .75)]), Color(tint, .9 - height_fade * .6))
	for m in range(3):
		var mx: float = body.position.x + w * local.randf_range(0, 1)
		draw_circle(Vector2(mx, body.position.y + cornice_h * .4), maxf(1.5, w * local.randf_range(.02, .045)), Color("6fa65a", .8 - height_fade * .6))
	# Hanging vines on some floors.
	for v in range(2):
		if local.randf() < .55:
			var x: float = body.position.x + w * local.randf_range(.05, .95);var length: float = body.size.y * local.randf_range(.6, 1.6)
			draw_line(Vector2(x, body.position.y), Vector2(x + sin(t + floor) * 2, body.position.y + length), Color("5f9c55", .85 - height_fade * .5), maxf(1, w * .012))
			draw_circle(Vector2(x, body.position.y + length), maxf(1.5, w * .018), Color("7dbb63", .85 - height_fade * .5))
	if glow > 0:
		# Charging up before the burst: white-hot cracks and a pulsing veil.
		draw_rect(body, Color(1, .96, .8, glow * .45 * (.7 + .3 * sin(t * 18 + index))))
		for c in range(3):
			var p := Vector2(body.position.x + w * (.15 + c * .33), body.position.y)
			draw_polyline(PackedVector2Array([p, p + Vector2(w * .05, body.size.y * .4), p + Vector2(-w * .03, body.size.y)]), Color(1, 1, .9, glow), maxf(1, w * .015))
	# Fade the endless top into the sky.
	if height_fade > .55:draw_rect(body, Color(SKY_MID, (height_fade - .55) * 2.1))

# ---- Foreground jungle ----
func _jungle() -> void:
	# Trees in front, kept to the sides so the tower stays clear.
	var f: float = 1.2
	for i in range(12):
		var side: float = -1.0 if i % 2 == 0 else 1.0;var x: float = side * (TW * .95 + (i / 2) * 170)
		var top: Vector2 = to_screen(Vector2(x, -200 - (i % 3) * 60), f);var base: Vector2 = to_screen(Vector2(x, 90), f)
		draw_line(top, base, Color("4a3226"), maxf(3, 15 * pow(zoom, f)))
		_blob(top, 46 * pow(zoom, f), TREE_COLORS[(i * 5 + 1) % TREE_COLORS.size()], i * 7)
	# Sunbeams.
	for s in range(3):
		var p: Vector2 = to_screen(Vector2(-700 + s * 650, -500), f)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(60, 0) * pow(zoom, f), p + Vector2(260, 900) * pow(zoom, f), p + Vector2(120, 900) * pow(zoom, f)]), Color("ffffff", .07))

func _foreground() -> void:
	var f: float = 1.7;var color := Color("1f4a2e")
	for i in range(18):
		var root: Vector2 = to_screen(Vector2(-1300 + i * 150, 140), f);var s: float = 60 * pow(zoom, f) * (1 + (i % 3) * .35)
		for leaf in range(5):
			var dir := Vector2.from_angle(-PI * .5 + (leaf - 2) * .45);var tip: Vector2 = root + dir * s * 1.6
			draw_colored_polygon(PackedVector2Array([root, root + dir.rotated(.5) * s * .5 + dir * s * .8, tip, root + dir.rotated(-.5) * s * .5 + dir * s * .8]), color)

func _motes() -> void:
	for m in motes:
		var p := Vector2(fposmod(m[0].x + t * .01 * m[2], 1) * view.x, fposmod(m[0].y - t * .03 * m[2], 1) * view.y)
		draw_circle(p, m[1], Color("ffffff", .22 * m[2]))

# ---- Chapter clear: flash, burst, dust ----
func _clear_effects() -> void:
	if t >= 2.3 and chunks.is_empty():
		for i in range(140):
			var floor_y: float = -rng.randf_range(0, 5 * FH);var x: float = rng.randf_range(-TW * .5, TW * .5)
			chunks.append({"p":Vector2(x, floor_y), "v":Vector2(x * rng.randf_range(1.5, 4), rng.randf_range(-260, 40)), "s":rng.randf_range(3, 11), "c":Color("6b667c").lerp(Color("e8eef7"), rng.randf())})
	if t >= 2.3:
		var age: float = t - 2.3
		for c in chunks:
			var p: Vector2 = c.p + c.v * age + Vector2(0, 160 * age * age);var a: float = clampf(1 - age / 1.7, 0, 1)
			var s: Vector2 = to_screen(p);var r: float = c.s * zoom * (1 - age * .35)
			if r > .5:draw_rect(Rect2(s - Vector2.ONE * r * .5, Vector2.ONE * r), Color(c.c, a))
		# Dust cloud where the floors stood.
		VfxArt.glow(self, to_screen(Vector2(0, -2.5 * FH)), TW * zoom * (1.2 + age), Color("e9eef5"), clampf(.6 - age * .3, 0, .6))
		var flash: float = clampf(1 - age / .6, 0, 1)
		if flash > 0:draw_rect(Rect2(Vector2.ZERO, view), Color(1, .98, .9, flash))
	elif t > .5:
		VfxArt.glow(self, to_screen(Vector2(0, -2.5 * FH)), TW * zoom * 1.4, Color("fff1c8"), clampf((t - .5) / 1.8, 0, 1) * .5)
	# The falling tower lands: dust puffs at the base.
	if t >= 4.75 and t < 5.8:
		var k: float = (t - 4.75) / 1.05
		for side in [-1, 1]:VfxArt.glow(self, to_screen(Vector2(side * TW * (.6 + k), -10)), 60 * zoom * (1 + k * 2), Color("dfe6ee"), (1 - k) * .55)

func _letterbox() -> void:
	var h: float = view.y * .07
	draw_rect(Rect2(0, 0, view.x, h), Color(0, 0, 0, .85));draw_rect(Rect2(0, view.y - h, view.x, h), Color(0, 0, 0, .85))

# ---- Text ----
func _titles() -> void:
	var font: Font = ArenaUI.heading_font();var numbers: Font = ArenaUI.numbers_font()
	if mode == "intro" and t > .8 and t < 3.6:
		var a: float = minf(clampf((t - .8) / .6, 0, 1), clampf((3.6 - t) / .5, 0, 1))
		_text(font, "두니 타워", Vector2(view.x * .5, view.y * .2), clampf(view.x * .11, 30, 64), Color(1, .97, .9, a), Color(.04, .08, .18, .6 * a))
		_text(font, "끝없이 하늘로 뻗은 탑", Vector2(view.x * .5, view.y * .2 + clampf(view.x * .08, 26, 48)), 15, Color(1, .95, .88, .9 * a), Color(.04, .08, .18, .5 * a))
	if mode == "clear" and t > 2.45 and t < 4.6:
		var a: float = minf(clampf((t - 2.45) / .25, 0, 1), clampf((4.6 - t) / .4, 0, 1));var pop: float = 1 + (1 - clampf((t - 2.45) / .3, 0, 1)) * .3
		_text(numbers, "CHAPTER %d CLEAR" % (chapter - 1), Vector2(view.x * .5, view.y * .34), clampf(view.x * .085, 26, 56) * pop, Color("ffe7a6", a), Color(.04, .08, .18, .8 * a))
		_text(font, "%s 정복" % TowerSceneDirector.CHAPTER_NAMES.get(chapter - 1, ""), Vector2(view.x * .5, view.y * .34 + 44), 17, Color(1, .96, .88, a), Color(.04, .08, .18, .6 * a))
	var title_at: float = {"intro":4.7, "clear":6.0, "enter":.3}.get(mode, 0.0)
	if t > title_at and t < fade_at + .6:
		var k: float = clampf((t - title_at) / .5, 0, 1);var a: float = minf(k, clampf((fade_at + .4 - t) / .4, 0, 1))
		var first: int = (chapter - 1) * 5 + 1;var y: float = view.y * .2
		var tint: Color = CHAPTER_TINT.get(chapter, Color("ffd27a")).lightened(.45)
		_text(numbers, "CHAPTER %d" % chapter, Vector2(view.x * .5, y - (1 - k) * 12), 20, Color(tint, a), Color(0, 0, 0, .55 * a))
		var line_w: float = minf(240, view.x * .55) * k
		draw_line(Vector2(view.x * .5 - line_w * .5, y + 12), Vector2(view.x * .5 + line_w * .5, y + 12), Color(tint, .8 * a), 2)
		_text(font, TowerSceneDirector.CHAPTER_NAMES.get(chapter, ""), Vector2(view.x * .5, y + 58), clampf(view.x * .1, 30, 58), Color(1, .97, .9, a), Color(.04, .08, .18, .7 * a))
		_text(font, "%d – %d층" % [first, first + 4], Vector2(view.x * .5, y + 94), 15, Color(1, .93, .85, .9 * a), Color(.04, .08, .18, .6 * a))

func _text(font: Font, text: String, center: Vector2, size: float, color: Color, outline: Color) -> void:
	var width: float = view.x
	draw_string_outline(font, Vector2(0, center.y), text, HORIZONTAL_ALIGNMENT_CENTER, width, int(size), maxi(4, int(size * .14)), outline)
	draw_string(font, Vector2(0, center.y), text, HORIZONTAL_ALIGNMENT_CENTER, width, int(size), color)
