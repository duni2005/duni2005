class_name SplashOverlay
extends Control
## The logo screen. It repeats the engine boot splash exactly (same image, cover fit, no
## filtering, same backdrop colour), so the hand-over from the boot screen is invisible, holds
## until HOLD seconds after launch, then fades out (`fading` marks the start) and frees itself.
signal fading
const HOLD: float = 3.0
const FADE: float = .7
const IMAGE := "res://assets/ui/boot_splash.png"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 100
	var back := ColorRect.new();back.color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK);back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);back.mouse_filter = Control.MOUSE_FILTER_IGNORE;add_child(back)
	var logo := TextureRect.new();logo.texture = load(IMAGE);logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED;logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST;add_child(logo)
	var wait: float = maxf(0, HOLD - Time.get_ticks_msec() / 1000.0)
	var t := create_tween();t.tween_interval(wait);t.tween_callback(func():fading.emit())
	t.tween_property(self, "modulate:a", 0.0, FADE);t.tween_callback(queue_free)
