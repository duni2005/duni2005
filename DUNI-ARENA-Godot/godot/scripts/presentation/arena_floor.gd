class_name ArenaFloor
extends RefCounted
## The arena floor as a clean vector-style meadow inside the tower: grass tones, a winding worn
## path with a few stepping stones and puddles, a bush fringe, and beyond it rune pillars,
## boulders, columns, statues and fallen columns. A shader paints it once into a cached texture,
## drawn as one quad in arena units. Two canopy-shadow layers are painted the same way and drawn
## over it every frame with a slow sway, so the shade moves like leaves in the wind.
const MARGIN: float = 800 # arena units of scenery around the 800-unit arena
const SIZE: int = 2048
const SHADOW_MARGIN: float = 320 # the moving shade only falls in and near the arena
const SHADOW_SIZE: int = 1024
const SHADER = preload("res://assets/vfx/arena_floor.gdshader")
const BASE := Color("4f7a34")
static var layers: Array[SubViewport] = []

## Layer 0 is the floor; 1 and 2 are the two canopy-shadow masks.
static func texture(layer: int = 0) -> Texture2D:
	if layers.is_empty():
		for i in range(3):
			var side: int = SIZE if i == 0 else SHADOW_SIZE
			var viewport := SubViewport.new();viewport.size = Vector2i(side, side);viewport.transparent_bg = true;viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			var paint := ColorRect.new();paint.size = Vector2(side, side)
			var material := ShaderMaterial.new();material.shader = SHADER;material.set_shader_parameter("margin", MARGIN if i == 0 else SHADOW_MARGIN);material.set_shader_parameter("layer", i);paint.material = material
			viewport.add_child(paint);layers.append(viewport)
			(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(viewport)
	return layers[layer].get_texture()

## Draws the floor in 800-unit arena space with `margin` units of scenery around it; the canopy
## shade sways with `time` (seconds).
static func draw(canvas: CanvasItem, margin: float, time: float = 0) -> void:
	margin = clampf(margin, 0, MARGIN)
	var dest := Rect2(-margin, -margin, 800 + margin * 2, 800 + margin * 2)
	# Plain grass colour shows for the frame before the texture is first painted.
	canvas.draw_rect(dest, BASE)
	canvas.draw_texture_rect_region(texture(0), dest, _source(margin, MARGIN, SIZE))
	var shade: float = minf(margin, SHADOW_MARGIN)
	for i in [1, 2]:
		var sway := Vector2(sin(time * .55 + i * 2.1), cos(time * .4 + i * 1.3)) * 5.0
		canvas.draw_texture_rect_region(texture(i), Rect2(Vector2(-shade, -shade) + sway, Vector2.ONE * (800 + shade * 2)), _source(shade, SHADOW_MARGIN, SHADOW_SIZE))
static func _source(margin: float, painted: float, side: int) -> Rect2:
	var px: float = side / (800 + painted * 2)
	return Rect2(Vector2.ONE * (painted - margin) * px, Vector2.ONE * (800 + margin * 2) * px)
