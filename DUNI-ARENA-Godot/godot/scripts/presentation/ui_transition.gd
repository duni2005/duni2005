class_name UiTransition
extends RefCounted
## Screen transitions that never delay the actual swap: the last rendered frame is captured
## just before a screen changes, then animated away on top of the new screen. Input passes
## straight through to the new screen the whole time.
## "forward" / "back": two or three slanted panels sweep across one after another with a gold
##   edge, the next screen's English title flashes past while they cover, then they sweep off.
##   Forward travels left to right, back right to left.
## "battle": the old screen splits along a diagonal and flies apart, a light streak fills the
##   gap and "BATTLE" is stamped in the middle.
static var layer: CanvasLayer

static func play(style: String = "forward", title: String = "") -> void:
	if not UiMotion.enabled or layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():return
	var viewport: Viewport = layer.get_viewport()
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():return
	for child in layer.get_children():child.queue_free()
	var wipe := Wipe.new();wipe.snapshot = ImageTexture.create_from_image(image);wipe.style = style
	wipe.title = title if not title.is_empty() else "BATTLE" if style == "battle" else ""
	wipe.duration = Motion.SCREEN_BATTLE if style == "battle" else Motion.SCREEN
	layer.add_child(wipe)

class Wipe extends Control:
	var snapshot: Texture2D
	var style: String = "forward"
	var title: String = ""
	var duration: float = Motion.SCREEN
	var t: float = 0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(dt: float) -> void:
		t += dt;queue_redraw()
		if t >= duration:queue_free()

	func _draw() -> void:
		if style == "battle":_split()
		else:_sweep(style == "back")

	## The old screen as a textured polygon (UVs follow screen position).
	func _old(points: PackedVector2Array, offset: Vector2 = Vector2.ZERO) -> void:
		var uvs := PackedVector2Array();var moved := PackedVector2Array()
		for p in points:uvs.append(p / size);moved.append(p + offset)
		draw_colored_polygon(moved, Color.WHITE, uvs, snapshot)

	func _sweep(back: bool) -> void:
		var w: float = size.x;var h: float = size.y;var slant: float = h * .3;var k: float = t / duration
		# Panels arrive over the first 40%, cover, then leave over the last half (each one slightly
		# after the other, so their edges read as stripes).
		var colors: Array = [TypeArt.NAVY, TypeArt.INDIGO, TypeArt.STEEL]
		var leads: Array = [];var tails: Array = []
		for i in range(3):
			leads.append(lerpf(-slant - 8, w + 8, Motion.out_expo(Motion.phase(k, i * .07, .36))))
			tails.append(lerpf(-slant - 8, w + 8, Motion.in_cubic(Motion.phase(k, .42 + (2 - i) * .07, .44))))
		# The old screen stays visible ahead of the front panel.
		if leads[0] < w + 8:_old(TypeArt.band(Rect2(Vector2.ZERO, size), w + slant + 8, leads[0], slant, back))
		# The front panel lies underneath; later ones stack on top, so their edges show as stripes.
		for i in range(3):
			if leads[i] <= tails[i]:continue
			var pts: PackedVector2Array = TypeArt.band(Rect2(Vector2.ZERO, size), leads[i], tails[i], slant, back)
			draw_colored_polygon(pts, colors[i])
		# Faint speed lines across the top panel, parallel to its edges.
		for j in range(5):
			var x: float = lerpf(tails[2], leads[2], (j + 1) / 6.0)
			var line: PackedVector2Array = TypeArt.band(Rect2(Vector2.ZERO, size), x, x, slant, back)
			draw_line(line[1], line[2], Color(1, 1, 1, .045), 1 + j % 2)
		# Gold lines ride the front panel's leading edge and the last panel's trailing edge.
		var front: PackedVector2Array = TypeArt.band(Rect2(Vector2.ZERO, size), leads[0], leads[0] - 1, slant, back)
		if leads[0] < w + 4:draw_line(front[1], front[2], ArenaUI.GOLD, 2, true)
		var rear: PackedVector2Array = TypeArt.band(Rect2(Vector2.ZERO, size), tails[0] + 1, tails[0], slant, back)
		if tails[0] > -slant and tails[0] < w + 4:draw_line(rear[0], rear[3], Color(ArenaUI.GOLD, .8), 2, true)
		# The next screen's English title flashes across while the panels cover.
		if not title.is_empty():
			var q: float = Motion.phase(k, .18, .6);var dir: float = Motion.sign_of(back)
			var size_px: int = int(clampf(h * .13, 56, 150))
			var x: float = w * .5 + dir * lerpf(w * .32, -w * .32, q)
			TypeArt.watermark(self, title, Vector2(x, h * .5), size_px, Color(1, 1, 1, .9 * sin(q * PI)), -.22, 10 * (1 - q))
			TypeArt.rule(self, Vector2(x, h * .5 + size_px * .62), size_px * 1.2, Motion.phase(k, .22, .3), Color(ArenaUI.GOLD, .8 * sin(q * PI)), 2)

	func _split() -> void:
		# Timings below are authored for a 0.6 s split and stretched to the configured length.
		var t: float = self.t * .6 / duration
		var w: float = size.x;var h: float = size.y;var c: Vector2 = size * .5
		# Diagonal cut through the centre, from the lower left to the upper right.
		var cut := Vector2(w, -h * .55).normalized();var normal := Vector2(cut.y, -cut.x)
		var a: Vector2 = c - cut * (w + h);var b: Vector2 = c + cut * (w + h)
		var open: float = Motion.out_expo(Motion.phase(t, .1, .42)) * (w + h) * .55
		var shake := Vector2.ZERO
		if GameSettings.shake and t < .2:shake = Vector2(sin(t * 90), cos(t * 70)) * 4 * (1 - t / .2)
		# Two halves of the old screen fly apart along the cut's normal.
		var far: float = (w + h) * 2
		var upper := PackedVector2Array([a, b, b + normal * -far, a + normal * -far])
		var lower := PackedVector2Array([a, b, b + normal * far, a + normal * far])
		_old(lower, normal * open + shake);_old(upper, -normal * open + shake)
		# Gold edges on both cut faces, and a light streak filling the gap.
		var gap: float = maxf(2, open * .25 * (1 - Motion.phase(t, .3, .3)))
		var glow := PackedVector2Array([a - normal * gap, b - normal * gap, b + normal * gap, a + normal * gap])
		draw_colored_polygon(glow, Color(1, .93, .75, .55 * (1 - Motion.phase(t, .25, .35))))
		for side in [-1, 1]:draw_line(a + normal * open * side + shake, b + normal * open * side + shake, ArenaUI.GOLD, 3, true)
		# A flash at the cut and short rays.
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, .96, .86, .45 * (1 - Motion.phase(t, 0, .16))))
		var rays: float = Motion.phase(t, .05, .3)
		for i in range(10):
			var d: Vector2 = Vector2.from_angle(i * TAU / 10 + .3);var from: Vector2 = c + d * (40 + rays * w * .5)
			draw_line(from, from + d * 60 * (1 - rays), Color(1, .9, .6, .8 * (1 - rays)), 3, true)
		# "BATTLE" stamped hard: big, slanted, settling with a slight overshoot, then gone.
		var stamp: float = Motion.phase(t, .06, .16);var fade: float = 1 - Motion.phase(t, .42, .18)
		if stamp > 0 and fade > 0:
			var s: float = lerpf(1.7, 1.0, Motion.emphasis(stamp))
			var px: int = int(clampf(w * .24, 70, 200) * s)
			TypeArt.watermark(self, title, c + Vector2(4, 6), px, Color(0, 0, 0, .45 * fade), -.2)
			TypeArt.watermark(self, title, c, px, Color(1, .95, .82, fade), -.2)
			TypeArt.rule(self, c + Vector2(0, px * .55), w * .3, stamp, Color(ArenaUI.GOLD, fade), 2)
