class_name ArenaFloor
extends RefCounted
## The arena floor as a clean vector-style meadow inside the tower: grass tones, a winding worn
## path with a few stepping stones and puddles, a bush fringe, and beyond it rune pillars,
## boulders, columns, statues and fallen columns. A shader paints it once into a cached texture,
## drawn as one quad in arena units. Two canopy-shadow layers are painted the same way and drawn
## over it every frame with a slow sway, so the shade moves like leaves in the wind.
const MARGIN: float = 800 # arena units of scenery around the arena
const SIZE: int = 2048
const SHADOW_MARGIN: float = 320 # the moving shade only falls in and near the arena
const SHADOW_SIZE: int = 1024
const SHADER = preload("res://assets/vfx/arena_floor.gdshader")
const BASE := Color("4f7a34")
## Painted layers per map side (사각 정원 · 소/중/대 each get their own garden).
static var layers: Dictionary = {}

## Texture pixels for a map: the same detail per arena unit as the small garden.
static func _pixels(side: float, layer: int) -> int:
	return roundi((SIZE if layer == 0 else SHADOW_SIZE) * (side + (MARGIN if layer == 0 else SHADOW_MARGIN) * 2) / (800.0 + (MARGIN if layer == 0 else SHADOW_MARGIN) * 2))

## Layer 0 is the floor; 1 and 2 are the two canopy-shadow masks.
static func texture(layer: int = 0, side: float = 800) -> Texture2D:
	var key: int = roundi(side)
	if not layers.has(key):
		var set: Array[SubViewport] = []
		for i in range(3):
			var px: int = _pixels(side, i)
			var viewport := SubViewport.new();viewport.size = Vector2i(px, px);viewport.transparent_bg = true;viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			var paint := ColorRect.new();paint.size = Vector2(px, px)
			var material := ShaderMaterial.new();material.shader = SHADER;material.set_shader_parameter("margin", MARGIN if i == 0 else SHADOW_MARGIN);material.set_shader_parameter("layer", i);material.set_shader_parameter("side", side);paint.material = material
			viewport.add_child(paint);set.append(viewport)
			(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(viewport)
		layers[key] = set
	return layers[key][layer].get_texture()

## Draws the floor of a `side`-unit garden in arena space with `margin` units of scenery around
## it; the canopy shade sways with `time` (seconds).
static func draw(canvas: CanvasItem, margin: float, time: float = 0, side: float = 800) -> void:
	margin = clampf(margin, 0, MARGIN)
	var dest := Rect2(-margin, -margin, side + margin * 2, side + margin * 2)
	# Plain grass colour shows for the frame before the texture is first painted.
	canvas.draw_rect(dest, BASE)
	canvas.draw_texture_rect_region(texture(0, side), dest, _source(margin, MARGIN, _pixels(side, 0), side))
	var shade: float = minf(margin, SHADOW_MARGIN)
	for i in [1, 2]:
		var sway := Vector2(sin(time * .55 + i * 2.1), cos(time * .4 + i * 1.3)) * 5.0
		canvas.draw_texture_rect_region(texture(i, side), Rect2(Vector2(-shade, -shade) + sway, Vector2.ONE * (side + shade * 2)), _source(shade, SHADOW_MARGIN, _pixels(side, i), side))
static func _source(margin: float, painted: float, pixels: int, side: float) -> Rect2:
	var px: float = pixels / (side + painted * 2)
	return Rect2(Vector2.ONE * (painted - margin) * px, Vector2.ONE * (side + margin * 2) * px)
