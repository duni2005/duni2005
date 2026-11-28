extends Node
## 임시 도트 스프라이트를 assets/gen/*.png로 구워요 (assets/palette.png, items_index.txt도 함께).
## 실행: godot --headless --path . res://tools/gen_assets.tscn
## 사람이 그린 그림은 assets/sprites/에 같은 이름으로 넣으세요. 이 도구는 그 폴더를 건드리지 않아요.


func _ready() -> void:
	var dir := ProjectSettings.globalize_path(Art.GEN_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var n := 0
	for key in Art.all_keys():
		var img := SpriteGen.make(key, Art.cells_of(key))
		var err := img.save_png(dir.path_join(key + ".png"))
		if err != OK:
			push_error("저장 실패: %s (%s)" % [key, error_string(err)])
		n += 1
	Palette.image().save_png(ProjectSettings.globalize_path("res://assets/palette.png"))
	var f := FileAccess.open(dir.path_join("items_index.txt"), FileAccess.WRITE)
	f.store_line("# items8.png / items16.png 아이콘 순서 (한 줄 %d개, 왼쪽 위부터)" % SpriteGen.ATLAS_COLS)
	for item in SpriteGen.ITEMS:
		f.store_line(item)
	f.close()
	print("스프라이트 %d장 + 팔레트를 저장했어요: %s" % [n, dir])
	get_tree().quit()
