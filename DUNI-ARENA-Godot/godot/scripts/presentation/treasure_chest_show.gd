class_name TreasureChestShow
extends Control
## 보물 수호자: before the clear reward's cards, a chest drops in, shakes and bursts open with gold
## light and coins (about 1.5 s). A tap skips it. Frees itself when done.
signal finished
const LIFE: float = 1.5
var age: float = 0

static func play(host: Control) -> TreasureChestShow:
	var show := TreasureChestShow.new();host.add_child(show);return show
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 50
func _process(dt: float) -> void:
	age += dt;queue_redraw()
	if age >= LIFE:skip()
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:accept_event();skip()
func skip() -> void:
	if is_queued_for_deletion():return
	finished.emit();queue_free()
func _draw() -> void:
	var fade: float = clampf((LIFE - age) / .25, 0, 1)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, .45 * fade))
	var center: Vector2 = size * .5 + Vector2(0, 20)
	# Drop (0–.35 s), shake (.35–.7 s), open (.7 s on).
	var drop: float = 1 - pow(1 - clampf(age / .35, 0, 1), 3)
	var shake: float = sin(age * 60) * 4 if age > .35 and age < .7 else 0.0
	var open: float = clampf((age - .7) / .25, 0, 1)
	var at: Vector2 = center + Vector2(shake, -(1 - drop) * 220)
	var w: float = 96;var h: float = 58
	if open > 0:
		VfxArt.glow(self, at + Vector2(0, -h * .5), 170 * open, Color("ffd34a"), .7 * fade)
		for i in range(10):
			var a: float = -PI * .5 + (i - 4.5) * .22;var reach: float = 160 * open
			draw_line(at + Vector2(0, -h * .45), at + Vector2(0, -h * .45) + Vector2.from_angle(a) * reach, Color("fff0b0", .5 * fade * (1 - open * .4)), 3)
		for i in range(8):
			var k: float = clampf((age - .7 - i * .03) / .7, 0, 1)
			var coin: Vector2 = at + Vector2((i - 3.5) * 22 * k, -h * .5 - 140 * k + 180 * k * k)
			draw_circle(coin, 7, Color("c9902a", fade));draw_circle(coin, 5, Color("ffd34a", fade))
	var body := Rect2(at - Vector2(w * .5, h * .25), Vector2(w, h * .75))
	draw_rect(body, Color("7a4a24", fade));draw_rect(body, Color("3a2210", fade), false, 3)
	for x in [body.position.x + 10, body.end.x - 16]:draw_rect(Rect2(x, body.position.y, 6, body.size.y), Color("f2c74a", fade))
	# The lid swings up and back.
	var hinge: Vector2 = at + Vector2(0, -h * .25)
	var lid_h: float = h * .35 * (1 - open * 1.6)
	var lid := Rect2(hinge.x - w * .5, hinge.y - absf(lid_h), w, absf(lid_h))
	draw_rect(lid, Color("8a5a2c", fade));draw_rect(lid, Color("3a2210", fade), false, 3)
	draw_rect(Rect2(hinge.x - 7, hinge.y - 6, 14, 12), Color("f2c74a", fade))
	if open <= 0:draw_circle(hinge + Vector2(0, 2), 3, Color("3a2210", fade))
