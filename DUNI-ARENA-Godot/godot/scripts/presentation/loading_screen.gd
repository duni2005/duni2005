class_name LoadingScreen
extends CanvasLayer
## Short loading cover for entering the tower, the next floor and custom battle: a dark gradient,
## a small tower whose floors light up one by one under a pulsing crystal, and a loading bar.
## The music fades out as it opens (unless kept, as when climbing to the next floor); music asked
## for while it is up starts once it lifts.
const FADE_IN: float = .3
const FADE_OUT: float = .4
const MIN_TIME: float = 1.2
var progress: float = 0
var keep_music: bool = false
var time: float = 0
var cover: Control
var background: GradientTexture2D

## Covers the screen, runs `work` behind the cover, then lifts and runs `done`.
## Without UI motion both run at once. With `keep_music` the music plays on underneath.
static func run(host: Node, work: Callable, done: Callable = Callable(), keep_music: bool = false) -> void:
	if not keep_music:BackgroundMusic.hold()
	if not UiMotion.enabled:
		work.call()
		if not keep_music:BackgroundMusic.release()
		if done.is_valid():done.call()
		return
	var screen := LoadingScreen.new();screen.keep_music = keep_music;host.get_tree().root.add_child(screen);screen._start(work, done)

func _ready() -> void:
	layer = 1200
	var g := Gradient.new();g.offsets = PackedFloat32Array([0, .55, 1]);g.colors = PackedColorArray([Color("1c1838"), Color("0e1428"), Color("070a14")])
	background = GradientTexture2D.new();background.gradient = g;background.fill_from = Vector2(0, 0);background.fill_to = Vector2(0, 1);background.width = 4;background.height = 256
	cover = Control.new();cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);cover.mouse_filter = Control.MOUSE_FILTER_STOP;add_child(cover)
	cover.draw.connect(_paint)

func _process(delta: float) -> void:
	time += delta;cover.queue_redraw()

func _start(work: Callable, done: Callable) -> void:
	cover.modulate.a = 0
	var t := create_tween()
	t.tween_property(cover, "modulate:a", 1.0, FADE_IN)
	t.parallel().tween_property(self, "progress", .15, FADE_IN)
	t.tween_callback(work)
	t.tween_property(self, "progress", 1.0, MIN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not keep_music:t.tween_callback(BackgroundMusic.release)
	t.tween_property(cover, "modulate:a", 0.0, FADE_OUT)
	t.tween_callback(func():
		if done.is_valid():done.call()
		queue_free())

func _paint() -> void:
	var size: Vector2 = cover.size;var center := Vector2(size.x * .5, size.y * .46)
	cover.draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	# Small tower: five floors lighting up in turn, a crystal pulsing on top.
	var floors: int = 5;var lit: int = int(time * 4) % (floors + 2)
	var y: float = center.y + 34
	for i in range(floors):
		var w: float = 30 - i * 4;var h: float = 11
		cover.draw_rect(Rect2(center.x - w * .5, y - h, w, h - 1), Color("4a5687"))
		cover.draw_rect(Rect2(center.x, y - h, w * .5, h - 1), Color("6b7ab0"))
		var on: bool = i < lit
		cover.draw_rect(Rect2(center.x - 2, y - h * .75, 4, h * .45), Color("ffd98a") if on else Color("232a48"))
		y -= h
	cover.draw_colored_polygon(PackedVector2Array([Vector2(center.x - 9, y), Vector2(center.x + 9, y), Vector2(center.x, y - 16)]), Color("4a5687"))
	var gem := Vector2(center.x, y - 26 + sin(time * 3) * 2);var pulse: float = .5 + .5 * sin(time * 4)
	cover.draw_circle(gem, 14 + pulse * 4, Color(.8, .7, 1, .12 + pulse * .1))
	cover.draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -7), gem + Vector2(5, 0), gem + Vector2(0, 7), gem + Vector2(-5, 0)]), Color("e6d6ff"))
	# Loading bar.
	var bar := Rect2(center.x - 90, center.y + 64, 180, 6)
	cover.draw_rect(bar.grow(1), Color(1, 1, 1, .12));cover.draw_rect(bar, Color("151b30"))
	cover.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0, 1), bar.size.y)), ArenaUI.GOLD)
