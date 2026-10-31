class_name TowerArt
extends RefCounted
## The tower's shared look, used by the cutscenes (side view) and the floor map (top view) so both
## read as one world: painterly daylight with a soft cyan sky, warm sunlit sandstone with cool blue
## shadows, summer greens, sandy paths, chapter-coloured banners and gold trim. Light falls from
## the upper left.
const SKY_TOP := Color("4fb4dc")
const SKY_MID := Color("8fd3ea")
const SKY_LOW := Color("dcefe6")
const HAZE := Color("cfe4ea")
const SUN := Color("fff1cf")
const STONE_LIT := Color("ecdcb2")
const STONE := Color("bba582")
const STONE_DARK := Color("5f6a92")
const RECESS := Color("3b4670")
const GRASS_LIT := Color("a9c862")
const GRASS := Color("6f9a4c")
const GRASS_DEEP := Color("5e8c3c")
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
## Sandstone shaded by how much it faces the light: sunlit to cool blue shadow.
static func stone(normal: Vector2, warm: float = 1) -> Color:
	var k: float = lit(normal)
	return STONE.lerp(STONE_LIT, k * warm).lerp(STONE_DARK, (1 - k) * .28)

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

## Soft shafts of sunlight fanning from `origin`, slowly breathing with `time`.
static func rays(c: CanvasItem, origin: Vector2, reach: float, time: float, alpha: float = 1, count: int = 6) -> void:
	for i in range(count):
		var angle: float = .25 + i * .2 + sin(time * .23 + i * 1.7) * .03;var width: float = .05 + .03 * sin(time * .4 + i * 2.3)
		var a: float = (.06 + .04 * sin(time * .5 + i)) * alpha
		c.draw_polygon(PackedVector2Array([origin, origin + Vector2.from_angle(angle - width) * reach, origin + Vector2.from_angle(angle + width) * reach]), PackedColorArray([Color(SUN, a), Color(SUN, 0), Color(SUN, 0)]))
