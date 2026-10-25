class_name ArenaFloor
extends RefCounted
## The arena floor as a clean vector-style meadow: grass tones, a winding worn path with a few
## stepping stones and puddles, a bush fringe, and beyond it rocks, rune pillars, round stone
## towers and trees. A shader paints it once into a cached texture, drawn as one quad in arena
## units. Two canopy-shadow layers are painted the same way and drawn over it every frame with
## a slow sway, so the shade moves like leaves in the wind.
const MARGIN: float = 320 # arena units of scenery around the 800-unit arena
const SIZE: int = 1024
const SHADER = preload("res://assets/vfx/arena_floor.gdshader")
const BASE := Color("6a9a3e")
static var layers: Array[SubViewport] = []

## Layer 0 is the floor; 1 and 2 are the two canopy-shadow masks.
static func texture(layer: int = 0) -> Texture2D:
	if layers.is_empty():
		for i in range(3):
			var viewport := SubViewport.new();viewport.size = Vector2i(SIZE, SIZE);viewport.transparent_bg = true;viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			var paint := ColorRect.new();paint.size = Vector2(SIZE, SIZE)
			var material := ShaderMaterial.new();material.shader = SHADER;material.set_shader_parameter("margin", MARGIN);material.set_shader_parameter("layer", i);paint.material = material
			viewport.add_child(paint);layers.append(viewport)
			(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(viewport)
	return layers[layer].get_texture()

## Draws the floor in 800-unit arena space with `margin` units of scenery around it; the canopy
## shade sways with `time` (seconds).
static func draw(canvas: CanvasItem, margin: float, time: float = 0) -> void:
	margin = clampf(margin, 0, MARGIN);var px: float = SIZE / (800 + MARGIN * 2)
	var dest := Rect2(-margin, -margin, 800 + margin * 2, 800 + margin * 2)
	var source := Rect2(Vector2.ONE * (MARGIN - margin) * px, Vector2.ONE * (800 + margin * 2) * px)
	# Plain grass colour shows for the frame before the texture is first painted.
	canvas.draw_rect(dest, BASE)
	canvas.draw_texture_rect_region(texture(0), dest, source)
	for i in [1, 2]:
		var sway := Vector2(sin(time * .55 + i * 2.1), cos(time * .4 + i * 1.3)) * 5.0
		canvas.draw_texture_rect_region(texture(i), Rect2(dest.position + sway, dest.size), source)
