class_name ArenaFloor
extends RefCounted
## The arena floor as one cached texture in the cutscenes' warm painterly look: old, irregular
## cream flagstones in sunlit yellow-green grass and moss, soft teal shadows, a stone curb on the
## arena edge, and beyond it ruined walls, pillars and teal tree canopies. Painted once with a fixed seed, mostly with native fill calls, then drawn
## as a single textured quad in arena units.
const PX: float = .5 # texture pixels per arena unit
const MARGIN: float = 320 # arena units of scenery around the 800-unit arena
const SOIL := Color("679a3c")
const OUTSIDE := Color("5a8c3a")
const SHADE := Color("2d5f55") # cool teal shadow
const STONE := Color("e2d6ae")
static var cached: Texture2D

static func texture() -> Texture2D:
	if cached == null:cached = ImageTexture.create_from_image(_paint())
	return cached

## Draws the floor in 800-unit arena space with `margin` units of scenery around it.
static func draw(canvas: CanvasItem, margin: float) -> void:
	margin = clampf(margin, 0, MARGIN)
	var source := Rect2(Vector2.ONE * (MARGIN - margin) * PX, Vector2.ONE * (800 + margin * 2) * PX)
	canvas.draw_texture_rect_region(texture(), Rect2(-margin, -margin, 800 + margin * 2, 800 + margin * 2), source)

static func _paint() -> Image:
	var size: int = int((800 + MARGIN * 2) * PX);var a0: int = int(MARGIN * PX);var a1: int = a0 + int(800 * PX)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new();rng.seed = 20261025
	img.fill(OUTSIDE)
	img.fill_rect(Rect2i(a0, a0, a1 - a0, a1 - a0), SOIL)
	# Big flagstones in uneven courses: random heights and widths, each slab shrunk unevenly so
	# the gaps wander; some split, some missing, and grass clearings where several have gone.
	var clearings: Array = []
	for i in range(9):clearings.append([Vector2(rng.randi_range(a0, a1), rng.randi_range(a0, a1)), rng.randf_range(14, 34)])
	var y: int = a0 + 1
	while y < a1 - 1:
		var h: int = mini(rng.randi_range(14, 28), a1 - 1 - y);var x: int = a0 + 1 - rng.randi_range(0, 18)
		while x < a1 - 1:
			var w: int = rng.randi_range(16, 42);var left: int = maxi(x, a0 + 1)
			var r := Rect2i(left, y, mini(x + w, a1 - 1) - left, h).grow_individual(-rng.randi_range(1, 2), -rng.randi_range(1, 2), -rng.randi_range(1, 3), -rng.randi_range(1, 3))
			var gone: float = .16
			for c in clearings:
				if Vector2(r.get_center()).distance_to(c[0]) < c[1]:gone = .75
			if r.size.x > 3 and r.size.y > 3 and rng.randf() > gone:
				if r.size.y > 16 and rng.randf() < .2:
					var top: int = r.size.y / 2
					_stone(img, rng, Rect2i(r.position, Vector2i(r.size.x, top - 1)), SOIL);_stone(img, rng, Rect2i(r.position.x, r.position.y + top, r.size.x, r.size.y - top), SOIL)
				else:_stone(img, rng, r, SOIL)
			x += w
		y += h
	# Grass grows from the gaps and bare patches; moss creeps over the stones.
	for i in range(16000):
		var p := Vector2i(rng.randi_range(a0, a1 - 1), rng.randi_range(a0 + 2, a1 - 1))
		if img.get_pixel(p.x, p.y).is_equal_approx(SOIL):_tuft(img, rng, p, [Color("86b84a"), Color("a6cf5c"), Color("5a8f38")])
	for i in range(300):_blob(img, rng, Vector2i(rng.randi_range(a0, a1), rng.randi_range(a0, a1)), rng.randi_range(2, 7), [Color("7fb245"), Color("6aa03e"), Color("9cc955")][i % 3], .5)
	# Stone curb on the arena edge.
	for side in range(4):
		var along: int = a0 - 7
		while along < a1 + 7:
			var length: int = rng.randi_range(14, 24);var r: Rect2i
			match side:
				0:r = Rect2i(along, a0 - 7, length, 7)
				1:r = Rect2i(along, a1, length, 7)
				2:r = Rect2i(a0 - 7, along, 7, length)
				_:r = Rect2i(a1, along, 7, length)
			_stone(img, rng, r.grow(-1).intersection(Rect2i(a0 - 7, a0 - 7, a1 - a0 + 14, a1 - a0 + 14)), OUTSIDE, Color("d7cba0"))
			along += length
	# Outside: patchy meadow, wild grass, ruined walls and pillars, then trees.
	for i in range(40):
		var p := Vector2i(rng.randi_range(0, size), rng.randi_range(0, size))
		if p.x < a0 - 12 or p.x > a1 + 12 or p.y < a0 - 12 or p.y > a1 + 12:_light(img, p, rng.randi_range(20, 50), [Color("82b64a"), Color("6ea242"), Color("3f7a48")][i % 3], .6)
	for i in range(9000):
		var p := Vector2i(rng.randi_range(0, size - 1), rng.randi_range(1, size - 1))
		if p.x < a0 - 9 or p.x > a1 + 9 or p.y < a0 - 9 or p.y > a1 + 9:_tuft(img, rng, p, [Color("78ad45"), Color("94c352"), Color("4f8236")])
	for side in range(4):
		var along: int = a0 - 10
		while along < a1 + 10:
			var length: int = rng.randi_range(30, 90)
			if rng.randf() < .65:
				var offset: int = rng.randi_range(10, 26);var horizontal: bool = side < 2
				var at := Vector2i(along, a0 - 7 - offset - 10 if side == 0 else a1 + 7 + offset) if horizontal else Vector2i(a0 - 7 - offset - 10 if side == 2 else a1 + 7 + offset, along)
				_wall(img, rng, at, length, horizontal)
			along += length + rng.randi_range(6, 26)
	for corner in [Vector2i(a0 - 30, a0 - 32), Vector2i(a1 + 12, a0 - 32), Vector2i(a0 - 30, a1 + 10), Vector2i(a1 + 12, a1 + 10)]:_pillar(img, rng, corner)
	var trees: int = 0
	while trees < 34:
		var p := Vector2i(rng.randi_range(0, size), rng.randi_range(0, size));var r: int = rng.randi_range(24, 46)
		var gap: int = maxi(maxi(a0 - p.x, p.x - a1), maxi(a0 - p.y, p.y - a1))
		if gap < r * 2 / 3 + 30:continue
		_tree(img, rng, p, r);trees += 1
	# Dappled sunlight on the floor, leaf shade near the edges, fallen leaves.
	for i in range(10):_light(img, Vector2i(rng.randi_range(a0 + 30, a1 - 30), rng.randi_range(a0 + 30, a1 - 30)), rng.randi_range(28, 52), Color("fff2b4"), .3)
	for i in range(14):
		var t: float = rng.randf();var side: int = i % 4;var edge: int = rng.randi_range(a0, a1)
		var p: Vector2i = [Vector2i(edge, a0 + 6), Vector2i(edge, a1 - 6), Vector2i(a0 + 6, edge), Vector2i(a1 - 6, edge)][side]
		_light(img, p, rng.randi_range(24, 40), SHADE, .35 + t * .1)
	for i in range(300):
		var p := Vector2i(rng.randi_range(2, size - 3), rng.randi_range(2, size - 3));var c: Color = [Color("f0c95a"), Color("e39b4a"), Color("fff3c0"), Color("f5df7a")][i % 4]
		img.set_pixel(p.x, p.y, c);img.set_pixel(p.x + 1, p.y, c.darkened(.15))
	return img

static func _stone(img: Image, rng: RandomNumberGenerator, r: Rect2i, ground: Color, tint: Color = Color.TRANSPARENT) -> void:
	if r.size.x < 2 or r.size.y < 2:return
	var base: Color = tint if tint.a > 0 else STONE.lerp(Color("cfc9a4"), rng.randf() * .6)
	base = base.lerp(SHADE, rng.randf_range(0, .14))
	# Sunlit face, a lit top edge, and a cool teal shadow along the bottom and right.
	img.fill_rect(r, base)
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, 2), base.lightened(.16));img.fill_rect(Rect2i(r.position.x, r.position.y, 1, r.size.y), base.lightened(.08))
	img.fill_rect(Rect2i(r.position.x, r.end.y - 2, r.size.x, 2), base.lerp(SHADE, .45));img.fill_rect(Rect2i(r.end.x - 2, r.position.y, 2, r.size.y), base.lerp(SHADE, .32))
	for i in range(r.get_area() / 45):
		var p := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 3), rng.randi_range(r.position.y + 2, r.end.y - 3))
		img.set_pixel(p.x, p.y, base.lerp(SHADE, .12) if i % 2 else base.lightened(.06))
	if rng.randf() < .15:
		# A crack wandering across the slab.
		var p := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2), r.position.y + 1)
		for k in range(r.size.y - 2):
			p.x = clampi(p.x + rng.randi_range(-1, 1), r.position.x + 1, r.end.x - 2);img.set_pixel(p.x, p.y + k, base.lerp(SHADE, .4))
	if rng.randf() < .3:
		# A chipped corner.
		var corner := Vector2i(r.position.x if rng.randf() < .5 else r.end.x - 2, r.position.y if rng.randf() < .5 else r.end.y - 2)
		img.fill_rect(Rect2i(corner, Vector2i(2, 2)), ground)

## A few grass blades rising from `p`.
static func _tuft(img: Image, rng: RandomNumberGenerator, p: Vector2i, colors: Array) -> void:
	for b in range(rng.randi_range(2, 4)):
		var x: int = p.x + rng.randi_range(-2, 2);var tall: int = rng.randi_range(1, 4);var c: Color = colors[rng.randi_range(0, colors.size() - 1)]
		for k in range(tall):
			var at := Vector2i(x, p.y - k)
			if at.x >= 0 and at.y >= 0 and at.x < img.get_width() and at.y < img.get_height():img.set_pixel(at.x, at.y, c.lightened(.12) if k == tall - 1 else c)

## A blended disc with a ragged, dithered rim.
static func _blob(img: Image, rng: RandomNumberGenerator, c: Vector2i, r: int, color: Color, strength: float) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d: float = sqrt(dx * dx + dy * dy) / maxf(1, r)
			if d > 1 or d > .75 and rng.randf() > (1 - d) * 4:continue
			var p := c + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():continue
			img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).lerp(color, strength))

## Soft radial wash (sunlight or shade).
static func _light(img: Image, c: Vector2i, r: int, color: Color, strength: float) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := c + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():continue
			var d: float = sqrt(dx * dx + dy * dy) / r
			if d < 1:img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).lerp(color, strength * (1 - d) * (1 - d)))

## A broken wall run seen from above: block tops with a shaded face below, gaps and fallen blocks.
static func _wall(img: Image, rng: RandomNumberGenerator, at: Vector2i, length: int, horizontal: bool) -> void:
	var along: int = 0
	while along < length:
		var block: int = rng.randi_range(10, 16)
		if rng.randf() < .15:along += block;continue
		var depth: int = rng.randi_range(10, 14)
		var top := Rect2i(at + Vector2i(along, 0), Vector2i(block - 1, depth)) if horizontal else Rect2i(at + Vector2i(0, along), Vector2i(depth, block - 1))
		img.fill_rect(Rect2i(top.position + Vector2i(3, top.size.y + 2), Vector2i(top.size.x, 6)), OUTSIDE.lerp(SHADE, .6))
		img.fill_rect(Rect2i(top.position + Vector2i(0, top.size.y), Vector2i(top.size.x, 6)), Color("7fa892"))
		img.fill_rect(Rect2i(top.position + Vector2i(0, top.size.y + 3), Vector2i(top.size.x, 1)), Color("6c9884"))
		_stone(img, rng, top, OUTSIDE, Color("eadfba"))
		if rng.randf() < .35:_blob(img, rng, top.position + Vector2i(rng.randi_range(0, top.size.x), 0), 3, Color("8fbf4e"), .7)
		if rng.randf() < .12:
			var fallen := top.position + (Vector2i(0, depth + rng.randi_range(6, 14)) if horizontal else Vector2i(depth + rng.randi_range(6, 14), 0))
			_stone(img, rng, Rect2i(fallen, Vector2i(6, 5)), OUTSIDE, Color("dcd2ac"))
		along += block
## A square pillar with a capstone, mossy on top.
static func _pillar(img: Image, rng: RandomNumberGenerator, at: Vector2i) -> void:
	img.fill_rect(Rect2i(at + Vector2i(4, 20), Vector2i(18, 10)), OUTSIDE.lerp(SHADE, .6))
	img.fill_rect(Rect2i(at + Vector2i(0, 16), Vector2i(18, 12)), Color("7fa892"))
	_stone(img, rng, Rect2i(at, Vector2i(18, 17)), OUTSIDE, Color("eadfba"))
	_stone(img, rng, Rect2i(at + Vector2i(3, 3), Vector2i(12, 11)), OUTSIDE, Color("f3ead0"))
	_blob(img, rng, at + Vector2i(5, 4), 5, Color("8fbf4e"), .7)
## A canopy from above: cast shadow, dark base, mid layer and sunlit tops.
static func _tree(img: Image, rng: RandomNumberGenerator, c: Vector2i, r: int) -> void:
	var autumn: bool = rng.randf() < .14
	var colors: Array = [Color("b0862e"), Color("d9aa3e"), Color("f5d673")] if autumn else [Color("1d5550"), Color("2f7a62"), Color("6fae5a")]
	_blob(img, rng, c + Vector2i(5, 7), r, SHADE.darkened(.3), .5)
	for k in range(5):_blob(img, rng, c + Vector2i(rng.randi_range(-r / 2, r / 2), rng.randi_range(-r / 2, r / 2)), r * 2 / 3, colors[0], .95)
	for k in range(4):_blob(img, rng, c + Vector2i(rng.randi_range(-r / 3, r / 4), rng.randi_range(-r / 3, r / 4)) - Vector2i(r / 6, r / 6), r / 2, colors[1], .9)
	for k in range(3):_blob(img, rng, c + Vector2i(rng.randi_range(-r / 3, 0), rng.randi_range(-r / 3, 0)) - Vector2i(r / 4, r / 4), r / 3, colors[2], .85)
