class_name TitleFx
extends Control
## Screen title motion, attached to a title Label. On `play`, the label's letters slide up out of a
## mask one after another; a large translucent English word drifts in behind it a moment later the
## other way (down and left, a slow parallax), and an optional gold rule draws out from the centre
## under the title. When the letters land the Label draws its own text again, so it ends crisp.
## The watermark and the rule stay; with UI motion off everything is shown at once.
const WATERMARK_DELAY: float = .08
const WATERMARK_TIME: float = .9
var label: Label
var word: String = ""
var rule: bool = false
var rule_color: Color = Color(ArenaUI.GOLD, .28)
## Watermark size relative to the label's height.
var watermark_scale: float = 1.9
var watermark_alpha: float = .07
var age: float = 99
var mask: Control

static func attach(target: Label, english: String = "", with_rule: bool = false) -> TitleFx:
	var fx: TitleFx = target.get_node_or_null("TitleFx")
	if fx == null:
		fx = TitleFx.new();fx.name = "TitleFx";fx.label = target;target.add_child(fx)
	fx.word = english;fx.rule = with_rule;fx.queue_redraw()
	return fx

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;show_behind_parent = true;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask = Control.new();mask.name = "Mask";mask.mouse_filter = Control.MOUSE_FILTER_IGNORE;mask.clip_contents = true
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(mask);mask.draw.connect(_draw_letters)
	# The mask draws the letters over the label, not behind it.
	mask.show_behind_parent = false;mask.z_index = 1
	set_process(false)

func play(delay: float = 0) -> void:
	if not UiMotion.enabled or label == null:age = 99;_settle();return
	age = -delay;set_process(true)
	# Wrapped titles keep their own text; only the watermark and rule move.
	if label.get_line_count() <= 1:label.self_modulate.a = 0

func _end_time() -> float:
	return maxf(TypeArt.letters_time(label.text), WATERMARK_DELAY + WATERMARK_TIME)

func _process(dt: float) -> void:
	age += dt;queue_redraw();mask.queue_redraw()
	if age >= TypeArt.letters_time(label.text):label.self_modulate.a = 1
	if age >= _end_time():_settle()

func _settle() -> void:
	set_process(false);if label != null:label.self_modulate.a = 1
	queue_redraw();if mask != null:mask.queue_redraw()

## Where the Label draws its first line: baseline-left of the text and its width.
func _text_origin() -> Array:
	var font: Font = label.get_theme_font("font");var fs: int = label.get_theme_font_size("font_size")
	var style: StyleBox = label.get_theme_stylebox("normal");var text_w: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var top: float = style.get_margin(SIDE_TOP);var inner_h: float = size.y - top - style.get_margin(SIDE_BOTTOM)
	var line_h: float = font.get_height(fs)
	if label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:top += (inner_h - line_h) * .5
	elif label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:top += inner_h - line_h
	var left: float = style.get_margin(SIDE_LEFT);var inner_w: float = size.x - left - style.get_margin(SIDE_RIGHT)
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:left += (inner_w - text_w) * .5
	elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:left += inner_w - text_w
	return [Vector2(left, top + font.get_ascent(fs)), text_w, font, fs]

func _draw() -> void:
	if label == null or label.text.is_empty():return
	var o: Array = _text_origin();var at: Vector2 = o[0];var text_w: float = o[1]
	var k: float = Motion.out_quint(Motion.phase(age, WATERMARK_DELAY, WATERMARK_TIME))
	if not word.is_empty():
		var px: int = int(clampf(size.y * watermark_scale, 34, 96))
		var word_w: float = ArenaUI.numbers_font().get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var center := Vector2(at.x + text_w * .5 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else at.x + word_w * .5 - 6, at.y - px * .2)
		# Counter-motion: the title rises, the word settles down and to the left.
		TypeArt.watermark(self, word, center + Vector2(28 * (1 - k), -10 * (1 - k)), px, Color(1, 1, 1, watermark_alpha * k), lerpf(-.38, -.2, k), 8 * (1 - k))
	if rule:
		var y: float = size.y - 1
		TypeArt.rule(self, Vector2(size.x * .5, y), size.x * .5, Motion.phase(age, .1, Motion.ENTER), rule_color)

func _draw_letters() -> void:
	if label == null or age >= TypeArt.letters_time(label.text) or age < 0 or label.self_modulate.a > 0:return
	var o: Array = _text_origin()
	var color: Color = label.get_theme_color("font_color")
	TypeArt.letters(mask, o[2], label.text, o[0], o[3], color, age, o[2].get_height(o[3]))
