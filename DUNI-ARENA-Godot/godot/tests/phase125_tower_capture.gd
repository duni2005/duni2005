extends "res://tests/phase125_capture.gd"
func run() -> void:
	target="after"
	for resolution in [Vector2i(1280,720),Vector2i(390,844)]:
		root.size=resolution;root.content_scale_size=resolution;tag="desktop" if resolution.x>400 else "mobile"
		await reset();await shot("tower");screen.open_guild();await shot("guild");await shot("upgrade");await shot("equipment")
		if is_instance_valid(screen):screen.free();screen=null
	quit()
