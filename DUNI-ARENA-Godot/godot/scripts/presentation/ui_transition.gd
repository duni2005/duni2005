class_name UiTransition
extends RefCounted
## Screen transitions that never delay the actual swap: the last rendered frame is captured
## just before a screen changes, then animated away on top of the new screen.
## "forward" zooms the old page out, "back" slides it aside, "battle" splits it like a curtain.
static var layer: CanvasLayer

static func play(style: String = "forward") -> void:
	if not UiMotion.enabled or layer == null or not is_instance_valid(layer) or not layer.is_inside_tree():return
	var viewport: Viewport = layer.get_viewport()
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():return
	var texture := ImageTexture.create_from_image(image)
	for child in layer.get_children():child.queue_free()
	var size: Vector2 = viewport.get_visible_rect().size
	if style == "battle":_curtain(texture, size)
	else:_shift(texture, size, style == "back")

static func _sheet(texture: Texture2D, rect: Rect2, region: Rect2 = Rect2()) -> TextureRect:
	var sheet := TextureRect.new();sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE;sheet.stretch_mode = TextureRect.STRETCH_SCALE
	if region.has_area():
		var atlas := AtlasTexture.new();atlas.atlas = texture;atlas.region = region;sheet.texture = atlas
	else:sheet.texture = texture
	sheet.position = rect.position;sheet.size = rect.size;sheet.pivot_offset = rect.size * .5
	layer.add_child(sheet);return sheet

static func _veil(size: Vector2, color: Color) -> ColorRect:
	var veil := ColorRect.new();veil.color = color;veil.mouse_filter = Control.MOUSE_FILTER_IGNORE;veil.size = size
	layer.add_child(veil);return veil

static func _shift(texture: Texture2D, size: Vector2, back: bool) -> void:
	var veil: ColorRect = _veil(size, Color(.02, .03, .06, .55))
	var sheet: TextureRect = _sheet(texture, Rect2(Vector2.ZERO, size))
	var t: Tween = layer.create_tween().set_parallel(true)
	t.tween_property(veil, "color:a", 0.0, .38).set_ease(Tween.EASE_OUT)
	t.tween_property(sheet, "modulate:a", 0.0, .3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if back:t.tween_property(sheet, "position:x", size.x * .18, .3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	else:t.tween_property(sheet, "scale", Vector2.ONE * 1.07, .3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.chain().tween_callback(_clear)

static func _curtain(texture: Texture2D, size: Vector2) -> void:
	var half: float = size.y * .5;var pixels: Vector2 = texture.get_size();var ratio: float = pixels.y / size.y
	var top: TextureRect = _sheet(texture, Rect2(0, 0, size.x, half), Rect2(0, 0, pixels.x, half * ratio))
	var bottom: TextureRect = _sheet(texture, Rect2(0, half, size.x, half), Rect2(0, half * ratio, pixels.x, pixels.y - half * ratio))
	var seam: ColorRect = _veil(Vector2(size.x, 4), Color("ffe6b0"));seam.position.y = half - 2
	var flash: ColorRect = _veil(size, Color(1, .95, .85, 0))
	var t: Tween = layer.create_tween().set_parallel(true)
	t.tween_property(flash, "color:a", .35, .08)
	t.tween_property(seam, "size:y", 26.0, .14).set_ease(Tween.EASE_OUT);t.tween_property(seam, "position:y", half - 13, .14).set_ease(Tween.EASE_OUT)
	t.tween_property(top, "position:y", -half, .42).set_delay(.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	t.tween_property(bottom, "position:y", size.y, .42).set_delay(.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	t.tween_property(seam, "modulate:a", 0.0, .3).set_delay(.16)
	t.tween_property(flash, "color:a", 0.0, .35).set_delay(.08)
	t.chain().tween_callback(_clear)

static func _clear() -> void:
	if layer != null and is_instance_valid(layer):
		for child in layer.get_children():child.queue_free()
