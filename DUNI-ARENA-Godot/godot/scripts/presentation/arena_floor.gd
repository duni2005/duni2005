class_name ArenaFloor
extends RefCounted
## The arena floor in the cutscenes' warm hand-painted style: worn cream flagstones with soft
## rims, broad moss patches, sandy wear and cool tree shade, a low block curb, and beyond it
## sunlit grass, broken walls, corner pillars and teal canopies. A shader paints it once into a
## cached texture, which is then drawn as one quad in arena units.
const MARGIN: float = 320 # arena units of scenery around the 800-unit arena
const SIZE: int = 1024
const SHADER = preload("res://assets/vfx/arena_floor.gdshader")
const BASE := Color("d9cba2")
static var viewport: SubViewport

static func texture() -> Texture2D:
	if viewport == null:
		viewport = SubViewport.new();viewport.size = Vector2i(SIZE, SIZE);viewport.transparent_bg = true;viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var paint := ColorRect.new();paint.size = Vector2(SIZE, SIZE)
		var material := ShaderMaterial.new();material.shader = SHADER;material.set_shader_parameter("margin", MARGIN);paint.material = material
		viewport.add_child(paint)
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(viewport)
	return viewport.get_texture()

## Draws the floor in 800-unit arena space with `margin` units of scenery around it.
static func draw(canvas: CanvasItem, margin: float) -> void:
	margin = clampf(margin, 0, MARGIN);var px: float = SIZE / (800 + MARGIN * 2)
	var dest := Rect2(-margin, -margin, 800 + margin * 2, 800 + margin * 2)
	# Plain stone colour shows for the frame before the texture is first painted.
	canvas.draw_rect(dest, BASE)
	canvas.draw_texture_rect_region(texture(), dest, Rect2(Vector2.ONE * (MARGIN - margin) * px, Vector2.ONE * (800 + margin * 2) * px))
