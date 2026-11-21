class_name TrialBanner
extends Control
## Room entry with 시련: a short band whose trial names drift across while the wallet's icons
## pop in one by one. A tap skips it (and the icons settle at once). Frees itself when done.
signal finished
const LIFE: float = 2.6
const HEIGHT: float = 30
var trials: Array = []
var age: float = 0

## Starts the band over `parent` (full width, at `top`) for `list`; null when motion is off.
## `delay`: seconds it waits first (the room's own entry banner), letting taps through meanwhile.
static func play(parent: Control, list: Array, top: float, delay: float = 0) -> TrialBanner:
	if list.is_empty() or not UiMotion.enabled:return null
	var band := TrialBanner.new();band.trials = list.duplicate();band.age = -delay
	band.mouse_filter = Control.MOUSE_FILTER_STOP;band.position = Vector2(0, top);band.size = Vector2(parent.size.x, HEIGHT)
	parent.add_child(band);return band

func _process(dt: float) -> void:
	age += dt;queue_redraw()
	mouse_filter = Control.MOUSE_FILTER_STOP if age >= 0 else Control.MOUSE_FILTER_IGNORE
	if age >= LIFE:skip()
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:accept_event();skip()
func skip() -> void:
	if is_queued_for_deletion():return
	finished.emit();queue_free()
func _draw() -> void:
	if age < 0:return
	var fade: float = clampf(age / .25, 0, 1) * clampf((LIFE - age) / .35, 0, 1)
	draw_rect(Rect2(Vector2.ZERO, size), Color(.05, .03, .06, .78 * fade))
	draw_line(Vector2(0, 0), Vector2(size.x, 0), Color("ff6a5a", .7 * fade), 1.5);draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Color("ff6a5a", .7 * fade), 1.5)
	var font: Font = ArenaUI.heading_font()
	var text: String = "시련  ·  " + "  ·  ".join(trials.map(func(t):return TrialCatalog.name_of(t)))
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	# Drifts from the right edge to the left across the band's life.
	var x: float = lerpf(size.x, -width * .35, clampf(age / LIFE, 0, 1))
	draw_string(font, Vector2(x, size.y * .5 + 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe1d8", fade))
