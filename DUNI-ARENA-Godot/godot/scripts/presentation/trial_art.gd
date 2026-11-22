class_name TrialArt
extends RefCounted
## How 시련 look, drawn the same on the deployment field and in battle: the round icon (rim in
## the kind's colour), the weather over the field (under the units), and the marks enemies wear
## for the room's trials. Moments (impacts, blocks, souls…) are TrialFx, which uses these.
## 시련 피해 numbers.
const TRIAL_NUMBER := Color("b9bec8")
## Counter looks: one colour per trial for its marks and block reactions.
const COUNTER_TINT = {&"ironclad": Color("c3ccd8"), &"seastone": Color("9fc0d6"), &"tough": Color("b07a48"), &"holy": Color("ffd770"), &"corrupt": Color("a06ae0"), &"immune": Color("a8f070"), &"insulator": Color("ffd84a"), &"sun": Color("ffb347"), &"rain": Color("9fd0ff"), &"calm": Color("d8e6d0"), &"bomb_squad": Color("ff9a4a"), &"melee_masters": Color("e8eef8"), &"spread": Color("ffb0a0"), &"stubborn": Color("9cc79a")}

## The trial's round icon at `center` with radius `r` (scale animates it in, flash 0..1 lights it).
static func icon(c: CanvasItem, center: Vector2, r: float, id: StringName, scale: float = 1.0, flash: float = 0.0) -> void:
	if scale <= .01:return
	var rr: float = r * scale;var rim: Color = TrialCatalog.color_of(id)
	if flash > 0:VfxArt.glow(c, center, rr * (2.2 + flash), rim, .75 * flash)
	c.draw_circle(center, rr, Color("101624").lerp(rim, .45 * flash))
	ArenaIcon.draw(c, center, String(TrialCatalog.info(id).get("icon", "")), rr * 1.35, Color.WHITE)
	c.draw_arc(center, rr - .75, 0, TAU, 32, rim.lightened(.5 * flash), maxf(1.5, rr * .16), true)

static func low_quality() -> bool:return GameSettings.particles <= 0

## Weather and other field-wide looks over the arena (0..side, arena space, under the units).
## `k` 0..1 fades them in (the room entry); `time` animates.
static func field(c: CanvasItem, trials: Array, side: float, time: float, k: float = 1.0) -> void:
	if k <= 0:return
	var low: bool = low_quality()
	if &"sun" in trials:
		# Warm light pouring in from the top corners, a heat shimmer under it.
		c.draw_rect(Rect2(0, 0, side, side), Color("ffb347", .05 * k))
		for x in [0.0, side]:VfxArt.glow(c, Vector2(x, 0), side * .62, Color("ffc26a"), .42 * k)
		for i in range(5 if low else 9):
			var y: float = 30 + i * 26;var a: float = .12 * k * (1 - i / 9.0)
			var pts := PackedVector2Array()
			for j in range(13):pts.append(Vector2(side * j / 12.0, y + sin(time * 2.4 + j * .9 + i) * 3))
			c.draw_polyline(pts, Color("fff0c8", a), 2)
	if &"rain" in trials:
		c.draw_rect(Rect2(0, 0, side, side), Color("1a2a40", .16 * k))
		var drops: int = int((40 if low else 80) * k)
		var streaks := PackedVector2Array()
		for i in range(drops):
			var sx: float = fposmod(i * 0.6180339 * 997.0, 1.0);var fall: float = fposmod(time * 1.7 + i * .137, 1.0)
			var p := Vector2(sx * side + fall * 40, fall * side)
			streaks.append(p);streaks.append(p + Vector2(-6, 22))
		if not streaks.is_empty():c.draw_multiline(streaks, Color("b8dcff", .5), 1.6)
		# Raindrop rings on the ground.
		for i in range(6 if low else 14):
			var cycle: float = fposmod(time * .9 + i * .29, 1.0)
			var at := Vector2(fposmod(i * 211.7, side), fposmod(i * 389.3 + 57, side))
			VfxArt.ellipse(c, at, 4 + cycle * 16, .4, Color("cfe6ff", .6 * (1 - cycle) * k), 1.4)
	if &"calm" in trials:
		# Dust and leaves that hang in the air without drifting.
		for i in range(10 if low else 18):
			var at := Vector2(fposmod(i * 173.3 + 40, side), fposmod(i * 291.1 + 90, side)) + Vector2(0, sin(time * .6 + i) * 2)
			if i % 3 == 0:
				var dir := Vector2.from_angle(i * 1.3)
				c.draw_colored_polygon(PackedVector2Array([at - dir * 5, at + dir.orthogonal() * 2.2, at + dir * 5, at - dir.orthogonal() * 2.2]), Color("b7d19a", .75 * k))
			else:c.draw_circle(at, 1.6, Color("e9e2cf", .55 * k))
	if &"fog" in trials:
		# Two banks drifting at their own speeds, rolling in from the left on entry; thicker at the edges.
		for layer in range(1 if low else 2):
			var speed: float = .018 if layer == 0 else .031
			for i in range(4):
				var drift: float = fposmod(time * speed + i * .29 + layer * .5, 1.3) - .15
				var at := Vector2(drift * side - (1 - k) * side * .6, side * fposmod(i * .29 + layer * .17 + .1, 1.0))
				VfxArt.glow(c, at, side * (.36 + layer * .08), Color("d8dde6"), .24 * k, .55)
		for e in range(4):c.draw_rect(Rect2(e * 14, e * 14, side - e * 28, side - e * 28), Color("dfe4ec", .09 * k), false, 14)

## Marks on the ground under one enemy (타락 smoke, 산개 ring).
static func unit_ground(c: CanvasItem, at: Vector2, r: float, trials: Array, time: float, seed: float) -> void:
	if &"corrupt" in trials:
		for i in range(3):
			var wob: float = sin(time * 1.6 + seed + i * 2.1)
			VfxArt.glow(c, at + Vector2((i - 1) * r * .55 + wob * 3, r * .8), r * .7, Color("2a1236"), .55, .45)
		VfxArt.glow(c, at + Vector2(0, r * .8), r * 1.1, Color("7a3fb8"), .25, .4)
	if &"spread" in trials:
		for i in range(16):
			var a: float = i * TAU / 16 + time * .25
			c.draw_arc(at + Vector2(0, r * .55), r * 1.45, a, a + TAU / 40, 4, Color("ffb0a0", .6), 2, true)

## Marks an enemy wears for the room's counters and 보상 trials (over its body).
static func unit_over(c: CanvasItem, at: Vector2, r: float, trials: Array, time: float, seed: float) -> void:
	for id in trials:
		match id:
			&"ironclad":
				for i in range(6):
					var a: float = i * TAU / 6 + .2
					c.draw_arc(at, r + 3, a, a + .8, 6, Color("3a4250"), 7, true)
					c.draw_arc(at, r + 3, a + .03, a + .77, 6, Color("b8c2ce"), 4.5, true)
					c.draw_circle(at + Vector2.from_angle(a + .4) * (r + 3), 1.6, Color("f2f6fa"))
			&"seastone":
				var pts := PackedVector2Array()
				for i in range(7):pts.append(at + Vector2.from_angle(i * TAU / 6 + time * .2) * (r + 8))
				c.draw_colored_polygon(pts, Color("9fc0d6", .14))
				c.draw_polyline(pts, Color("d0e6f2", .75), 2, true)
				for i in range(6):c.draw_circle(pts[i], 2.2, Color("e8f4fa", .8))
			&"tough":
				VfxArt.glow(c, at, r + 12, Color("8a5a32"), .26)
				c.draw_arc(at, r + 2, 0, TAU, 36, Color("7a4a24"), 5, true)
			&"holy":
				# A small gold ring resting on the head (under the HP bar).
				var halo: Vector2 = at + Vector2(0, -r * .92)
				VfxArt.glow(c, halo, 14, Color("ffd770"), .45)
				VfxArt.ellipse(c, halo, r * .5, .3, Color("ffe7a0"), 3)
			&"immune":
				VfxArt.glow(c, at, r + 10, Color("a8f070"), .14)
				for i in range(4):
					var p: Vector2 = at + Vector2.from_angle(time * .5 + i * TAU / 4 + seed) * (r + 9)
					c.draw_line(p - Vector2(4, 0), p + Vector2(4, 0), Color("c8ff8a", .85), 2.5);c.draw_line(p - Vector2(0, 4), p + Vector2(0, 4), Color("c8ff8a", .85), 2.5)
			&"insulator":
				# A yellow-and-black striped hood band across the brow.
				var y: float = at.y - r * .95;var w: float = r * 1.5
				c.draw_rect(Rect2(at.x - w * .5 - 1, y - 1, w + 2, 10), Color("111111"))
				for i in range(6):
					var x0: float = at.x - w * .5 + w * i / 6.0
					c.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 3, y), Vector2(x0 + w / 6.0 + 3, y), Vector2(x0 + w / 6.0, y + 8), Vector2(x0, y + 8)]), Color("ffd84a") if i % 2 == 0 else Color("1b1b1b"))
			&"bomb_squad":
				var vest := Rect2(at + Vector2(-r * .55, r * .12), Vector2(r * 1.1, r * .62))
				c.draw_rect(vest, Color("4a5236", .9));c.draw_rect(vest, Color("1e2216"), false, 1.5)
				for i in range(2):c.draw_line(vest.position + Vector2(2, 5 + i * 7), vest.position + Vector2(vest.size.x - 2, 5 + i * 7), Color("ff9a4a"), 2)
			&"melee_masters":
				# Crossed swords on the upper right.
				var p: Vector2 = at + Vector2(r * .9, -r * .8)
				c.draw_circle(p, 9, Color("1a2030", .85))
				for s in [-1, 1]:
					var hilt: Vector2 = p + Vector2(-6 * s, 6);var tip: Vector2 = p + Vector2(6 * s, -6)
					c.draw_line(hilt, tip, Color("eef3fa"), 2.5)
					var guard: Vector2 = hilt.lerp(tip, .28);var across: Vector2 = (tip - hilt).normalized().orthogonal() * 3.5
					c.draw_line(guard - across, guard + across, Color("e0a84a"), 2)
			&"stubborn":
				var pulse: float = .5 + .5 * sin(time * 3 + seed)
				VfxArt.glow(c, at, r + 10, Color("9cc79a"), .18 + .18 * pulse)
				c.draw_arc(at, r + 4 + pulse * 4, 0, TAU, 32, Color("9cc79a", .35 + .4 * pulse), 2.5, true)
			&"treasure_guard":
				for i in range(4):
					var a: float = i * TAU / 4 + PI / 4
					c.draw_arc(at, r + 3, a - .32, a + .32, 8, Color("f2c74a"), 3, true)
					c.draw_circle(at + Vector2.from_angle(a) * (r + 3), 2.6, Color("ff6a7a"))
			&"gold_convoy":
				# A small gold sack slung on the back.
				var bag: Vector2 = at + Vector2(r * .75, r * .45)
				c.draw_circle(bag, r * .32, Color("c9902a"));c.draw_circle(bag + Vector2(-1, -1), r * .24, Color("f2c74a"))
				c.draw_line(bag + Vector2(-r * .12, -r * .3), bag + Vector2(r * .12, -r * .3), Color("7a5214"), 2)
				c.draw_string(ArenaUI.numbers_font(), bag + Vector2(-3, 4), "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("7a5214"))

## 정예 부대: a crown and a gold pulse.
static func elite_mark(c: CanvasItem, at: Vector2, r: float, time: float) -> void:
	var pulse: float = .5 + .5 * sin(time * 3.2)
	c.draw_arc(at, r + 5 + pulse * 3, 0, TAU, 36, Color("ffd34a", .35 + .35 * pulse), 2.5, true)
	c.draw_circle(at + Vector2(-r * .9, -r * .8), 9, Color("2a1e08", .85))
	ArenaIcon.draw(c, at + Vector2(-r * .9, -r * .8), "crown", 15, Color.WHITE)

## A row of icons centred at `center` (the custom battle shows its trials this way).
static func strip(c: CanvasItem, center: Vector2, trials: Array, r: float, flashes: Dictionary) -> void:
	var gap: float = 4;var width: float = trials.size() * (r * 2 + gap) - gap
	for i in range(trials.size()):
		var f: float = float(flashes.get(trials[i], 0.0))
		icon(c, center + Vector2(-width * .5 + r + i * (r * 2 + gap), -sin(f * PI) * 4), r, trials[i], 1.0 + .2 * f, f)

## The cracked half shield shown beside a number a counter cut, in that trial's colour.
static func broken_shield(c: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var s: float = size
	var outline := PackedVector2Array([at + Vector2(-s * .5, -s * .45), at + Vector2(s * .5, -s * .45), at + Vector2(s * .45, s * .1), at + Vector2(0, s * .55), at + Vector2(-s * .45, s * .1)])
	c.draw_colored_polygon(outline, Color(color, .35 * color.a))
	outline.append(outline[0]);c.draw_polyline(outline, color, 1.6, true)
	c.draw_polyline(PackedVector2Array([at + Vector2(s * .05, -s * .45), at + Vector2(-s * .12, -s * .1), at + Vector2(s * .1, s * .08), at + Vector2(-s * .05, s * .4)]), Color(1, 1, 1, color.a), 1.6, true)
