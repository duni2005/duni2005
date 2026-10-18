extends "res://tests/phase125_capture.gd"
func run() -> void:
	target="after"
	rows=JSON.parse_string(FileAccess.get_file_as_string("res://migration/phase125/after/manifest.json"))
	for resolution in [Vector2i(1280,720),Vector2i(390,844)]:
		root.size=resolution;root.content_scale_size=resolution;tag="desktop" if resolution.x>400 else "mobile"
		rows=rows.filter(func(r):return not (r.name=="rest" and int(r.size.x)==resolution.x))
		await reset();await select_room("0:2");await shot("rest")
		if is_instance_valid(screen):screen.free();screen=null
	quit()
