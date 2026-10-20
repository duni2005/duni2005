class_name AmbientBackdrop
extends ColorRect
## Screen background: deep vertical gradient, two slowly drifting glows and rising motes.
## Decorative only; it ignores input and stays still in headless runs.
const TOP := Color("141c34")
const BOTTOM := Color("080b14")
var age: float = 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;set_process(UiMotion.enabled)
func _process(dt: float) -> void:
	age += dt;queue_redraw()
func _draw() -> void:
	var s: Vector2 = size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]), PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	VfxArt.glow(self, Vector2(s.x * (.25 + .1 * sin(age * .11)), s.y * (.16 + .05 * sin(age * .07))), s.x * .95, Color("3b4f9a"), .16)
	VfxArt.glow(self, Vector2(s.x * (.8 + .08 * cos(age * .09)), s.y * (.78 + .06 * sin(age * .13))), s.x * .8, Color("6a4590"), .12)
	for i in range(34):
		var x: float = VisualParticles.noise(i) * s.x + sin(age * .3 + i) * 8
		var y: float = fposmod(VisualParticles.noise(i + 40) * s.y - age * (6 + VisualParticles.noise(i + 80) * 14), s.y + 20) - 10
		var twinkle: float = .5 + .5 * sin(age * (1.2 + VisualParticles.noise(i + 9)) + i)
		draw_circle(Vector2(x, y), 1 + VisualParticles.noise(i + 3) * 1.6, Color(.75, .82, 1, .1 + .3 * twinkle))
