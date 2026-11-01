class_name TowerArt
extends RefCounted
## The tower's shared look, used by the cutscenes (side view) and the floor map (top view) so both
## read as one world, in a clean flat cel style (colour shapes with hard-edged shadows): a bright
## blue sky, warm sunlit sandstone with cool blue
## shadows, summer greens, sandy paths, chapter-coloured banners and gold trim. Light falls from
## the upper left.
const SKY_TOP := Color("3f9de2")
const SKY_MID := Color("86ccf0")
const SKY_LOW := Color("d6eef7")
const HAZE := Color("cfe4ea")
const SUN := Color("fff1cf")
const STONE_LIT := Color("ecdcb2")
const STONE := Color("bba582")
const STONE_DARK := Color("5f6a92")
const RECESS := Color("3b4670")
const GRASS_LIT := Color("a8d34e")
const GRASS := Color("86bf3f")
const GRASS_DEEP := Color("5f9a34")
const PATH := Color("e8d8a8")
const PATH_EDGE := Color("d8c79a")
const GOLD := Color("c9a560")
const CHAPTER_TINT = {1:Color("4f9c8c"), 2:Color("b8574c"), 3:Color("d2a24a")}
## Round tree crowns: soft summer greens with a few muted autumn and gold ones.
const TREE_COLORS = [Color("6c9e46"), Color("d69a52"), Color("4f8a4a"), Color("9cbc5a"), Color("5f9a55"), Color("c9a94e"), Color("3f7a52"), Color("b9764a")]
const BLOSSOM_COLORS = [Color("e3a9b8"), Color("eec3cc"), Color("f3ece6")]
## Direction the light comes from (towards the upper left).
const LIGHT := Vector2(-.707, -.707)

static func chapter_tint(chapter: int) -> Color:return CHAPTER_TINT.get(chapter, Color("4f9c8c"))
## How lit a surface facing `normal` is, 0 (in shadow) to 1 (facing the sun).
static func lit(normal: Vector2) -> float:return .5 + .5 * normal.normalized().dot(LIGHT)
## A flat-bottomed cartoon cloud: a pale blue underside, then the lit puffs.
static func cloud(c: CanvasItem, center: Vector2, r: float, seed_value: int, alpha: float = 1) -> void:
	var local := RandomNumberGenerator.new();local.seed = seed_value
	var parts: Array = []
	for i in range(6):parts.append([Vector2(local.randf_range(-1.3, 1.3), local.randf_range(-.5, 0)) * r, r * local.randf_range(.36, .66)])
	parts.append([Vector2(local.randf_range(-.3, .3), -.4) * r, r * .72])
	c.draw_set_transform(center + Vector2(0, r * .12), 0, Vector2(1, .22));c.draw_circle(Vector2.ZERO, r * 1.45, Color("c3d6ec", .95 * alpha));c.draw_set_transform(Vector2.ZERO)
	for p in parts:c.draw_circle(center + p[0] + Vector2(0, r * .14), p[1], Color("c3d6ec", .95 * alpha))
	for p in parts:c.draw_circle(center + p[0], p[1], Color("f4f6f2", .97 * alpha))
	for p in parts.slice(0, 4):c.draw_circle(center + p[0] + Vector2(-p[1] * .2, -p[1] * .22), p[1] * .5, Color("fffbef", alpha))

## A round tree crown seen from above: a soft shadow, clustered leaf puffs lit from the upper left,
## and for blossom trees a scatter of light flowers.
static func crown(c: CanvasItem, center: Vector2, r: float, color: Color, seed_value: int, blossom: bool = false) -> void:
	c.draw_circle(center + Vector2(r * .35, r * .45), r * 1.05, Color(.05, .12, .05, .22))
	var spots: Array = [Vector2(-.45, .2), Vector2(.45, .25), Vector2(0, -.4), Vector2(-.3, -.15), Vector2(.35, -.2), Vector2(0, .3)]
	for p in spots:c.draw_circle(center + p * r + Vector2(r * .08, r * .1), r * .55, color.darkened(.3))
	for p in spots:c.draw_circle(center + p * r, r * .5, color)
	for p in spots.slice(2, 5):c.draw_circle(center + p * r + Vector2(-r * .16, -r * .18), r * .27, color.lightened(.16))
	if blossom:
		var local := RandomNumberGenerator.new();local.seed = seed_value
		for i in range(7):c.draw_circle(center + Vector2(local.randf_range(-.8, .8), local.randf_range(-.7, .5)) * r, maxf(1, r * .1), Color("fff3f8", .9))

# ---- Fantasy scenery (animated by the caller's time) ----
const ROCK := Color("a3a6c4")
const ROCK_DARK := Color("7a7fa6")
const WATER := Color("cdeefa")
const WATER_DEEP := Color("9fd9f2")
const SPIRIT := Color("fff4c2")

## A floating island seen from the side: a grassy cap with a deeper front lip on a jagged rock
## cone (sunlit left face, flat shadow facet on the right), a tree or two, and with `fall` a thin
## waterfall pouring off the right edge, its light streaks running down.
static func island(c: CanvasItem, center: Vector2, r: float, seed_value: int, time: float, fall: bool = false) -> void:
	var local := RandomNumberGenerator.new();local.seed = seed_value
	var rock := PackedVector2Array([center + Vector2(-r, 0)])
	for k in range(1, 6):
		var u: float = k / 6.0;rock.append(center + Vector2(-r + u * r * .9 + local.randf_range(-.06, .06) * r, r * (.35 + u * .75)))
	rock.append(center + Vector2(local.randf_range(-.1, .1) * r, r * 1.25))
	for k in range(5, 0, -1):
		var u: float = k / 6.0;rock.append(center + Vector2(r - u * r * .9 + local.randf_range(-.06, .06) * r, r * (.35 + u * .75)))
	rock.append(center + Vector2(r, 0))
	c.draw_colored_polygon(rock, ROCK)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(r * .15, r * .1), center + Vector2(r, 0), rock[rock.size() - 2], rock[6]]), ROCK_DARK)
	if fall:
		# Water pours off the right edge and thins out as it falls.
		var top: Vector2 = center + Vector2(r * .62, r * .06);var w: float = maxf(2, r * .1)
		for seg in range(3):c.draw_rect(Rect2(top + Vector2(-w * .5, r * .8 * seg), Vector2(w, r * .8)), Color(WATER, .9 - seg * .3))
		for k in range(4):
			var y: float = fposmod(time * r * .9 + k * r * .6, r * 2.4)
			c.draw_rect(Rect2(top + Vector2(-w * .2, y), Vector2(w * .4, r * .25)), Color(1, 1, 1, .8 * (1 - y / (r * 2.4))))
	c.draw_set_transform(center + Vector2(0, r * .06), 0, Vector2(1, .3));c.draw_circle(Vector2.ZERO, r * 1.02, GRASS_DEEP);c.draw_set_transform(Vector2.ZERO)
	c.draw_set_transform(center, 0, Vector2(1, .26));c.draw_circle(Vector2.ZERO, r, GRASS_LIT);c.draw_set_transform(Vector2.ZERO)
	for k in range(1 + seed_value % 2):
		var at: Vector2 = center + Vector2((-.35 + k * .55) * r, -r * .02);var h: float = r * (.55 - k * .12)
		c.draw_rect(Rect2(at + Vector2(-h * .05, -h * .5), Vector2(h * .1, h * .5)), Color("6b5440"))
		crown(c, at + Vector2(0, -h * .62), h * .38, TREE_COLORS[(seed_value + k) % TREE_COLORS.size()], seed_value + k, (seed_value + k) % 3 == 0)

## A floating island seen from above (the map's sky): its rock side shows below the grassy top,
## with a tree or two and sometimes a little pond.
static func island_top(c: CanvasItem, center: Vector2, r: float, seed_value: int) -> void:
	c.draw_circle(center + Vector2(r * .5, r * .9), r * 1.05, Color(STONE_DARK, .18))
	c.draw_circle(center + Vector2(0, r * .3), r, ROCK_DARK);c.draw_circle(center, r, ROCK)
	c.draw_circle(center + Vector2(-r * .04, -r * .06), r * .84, GRASS_LIT)
	if seed_value % 2 == 0:
		c.draw_set_transform(center + Vector2(r * .3, r * .2), 0, Vector2(1, .7));c.draw_circle(Vector2.ZERO, r * .26, WATER_DEEP);c.draw_circle(Vector2(-r * .05, -r * .05), r * .16, WATER);c.draw_set_transform(Vector2.ZERO)
	crown(c, center + Vector2(-r * .3, -r * .2), r * .32, TREE_COLORS[seed_value % TREE_COLORS.size()], seed_value, seed_value % 3 == 0)
	if r > 30:crown(c, center + Vector2(r * .05, -r * .45), r * .22, TREE_COLORS[(seed_value + 3) % TREE_COLORS.size()], seed_value + 1)

## A bird gliding, wings beating with `flap` (-1..1).
static func bird(c: CanvasItem, at: Vector2, s: float, flap: float, color: Color = Color(1, 1, 1, .9)) -> void:
	var tip := Vector2(s, -s * (.2 + flap * .45))
	c.draw_polyline(PackedVector2Array([at + Vector2(-tip.x, tip.y), at + Vector2(-s * .4, -s * .05 * flap), at, at + Vector2(s * .4, -s * .05 * flap), at + tip]), color, maxf(1.2, s * .2), true)

## Little spirit lights drifting up through `rect` and fading in and out.
static func spirits(c: CanvasItem, rect: Rect2, time: float, count: int = 12, scale: float = 1) -> void:
	for i in range(count):
		var sx: float = sin(i * 12.98 + 3.14) * .5 + .5;var k: float = fposmod(time * (.05 + .03 * (i % 4)) + sin(i * 7.7) * .5 + .5, 1.0)
		var at := Vector2(rect.position.x + sx * rect.size.x + sin(time * 1.3 + i) * 10 * scale, rect.end.y - k * rect.size.y)
		var a: float = sin(k * PI) * (.6 + .4 * sin(time * 3 + i * 2.1))
		c.draw_circle(at, 6 * scale, Color(SPIRIT, .18 * a));c.draw_circle(at, 2.2 * scale, Color(SPIRIT, .95 * a))
