class_name TrialBanner
extends Control
## Room entry with 시련: one band per trial along the bottom of the field, in turn, each with its
## icon, name (in its kind's colour) and one line of what it does, sliding in from the right and
## out to the left. A tap skips them all. Frees itself when done.
signal finished
const HEIGHT: float = 36
## A band's time on screen, and the time between two bands.
const BAND_LIFE: float = 1.9
const STEP: float = 1.15
const SLIDE: float = .28
var trials: Array = []
var age: float = 0

## Starts the bands over the bottom of `parent` after `delay` s (the room's own entry banner, taps
## pass through meanwhile); null when motion is off.
static func play(parent: Control, list: Array, delay: float = 0) -> TrialBanner:
	if list.is_empty() or not UiMotion.enabled:return null
	var band := TrialBanner.new();band.trials = list.duplicate();band.age = -delay
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE;parent.add_child(band);band._place();return band
## Along the bottom of the field's visible rect (the deployment board's), which can still change
## while the room's layout settles.
func _place() -> void:
	var parent: Control = get_parent()
	var field: Rect2 = parent.board_rect() if parent.has_method("board_rect") else Rect2(Vector2.ZERO, parent.size)
	field = field.intersection(Rect2(Vector2.ZERO, parent.size))
	position = Vector2(field.position.x, field.end.y - HEIGHT - 10);size = Vector2(field.size.x, HEIGHT)
func life() -> float:return (trials.size() - 1) * STEP + BAND_LIFE

func _process(dt: float) -> void:
	age += dt;_place();queue_redraw()
	mouse_filter = Control.MOUSE_FILTER_STOP if age >= 0 else Control.MOUSE_FILTER_IGNORE
	if age >= life():skip()
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:accept_event();skip()
func skip() -> void:
	if is_queued_for_deletion():return
	finished.emit();queue_free()
func _draw() -> void:
	if age < 0:return
	var heading: Font = ArenaUI.heading_font();var font: Font = get_theme_default_font()
	for i in range(trials.size()):
		var t: float = age - i * STEP
		if t < 0 or t > BAND_LIFE:continue
		var id: StringName = trials[i];var tint: Color = TrialCatalog.color_of(id)
		# In from the right, a pause in the middle, out to the left.
		var enter: float = 1 - pow(1 - clampf(t / SLIDE, 0, 1), 3);var leave: float = pow(clampf((t - (BAND_LIFE - SLIDE)) / SLIDE, 0, 1), 3)
		var w: float = minf(size.x - 24, 360.0)
		var x: float = lerpf(size.x, (size.x - w) * .5, enter) - leave * (size.x + w) * .5
		var box := Rect2(x, 0, w, size.y)
		draw_rect(box, Color(.04, .05, .09, .86))
		draw_rect(Rect2(box.position, Vector2(4, box.size.y)), tint)
		draw_line(box.position, box.position + Vector2(w, 0), Color(tint, .7), 1.5);draw_line(box.position + Vector2(0, size.y), box.end, Color(tint, .7), 1.5)
		TrialArt.icon(self, box.position + Vector2(24, size.y * .5), 12, id, 1.0, clampf(1 - t / .5, 0, 1))
		var name: String = TrialCatalog.name_of(id)
		draw_string(heading, box.position + Vector2(44, size.y * .5 + 5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint.lightened(.2))
		var nw: float = heading.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, box.position + Vector2(52 + nw, size.y * .5 + 4), TrialCatalog.short_of(id), HORIZONTAL_ALIGNMENT_LEFT, w - 60 - nw, 12, Color("dfe6f6"))
