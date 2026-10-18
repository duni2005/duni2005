extends "res://tests/phase125_capture.gd"
func run() -> void:
	target="after"
	for resolution in [Vector2i(1280,720),Vector2i(390,844)]:
		root.size=resolution;root.content_scale_size=resolution;tag="desktop" if resolution.x>400 else "mobile"
		var room: TowerBattleScreen=await battle_fixture();room.start_battle();room.battle.set_physics_process(false)
		await shot("battle-zero");room.battle.clock.elapsed=12;room.battle.turning.advance(.01);room.battle.turning.advance(2)
		await shot("tp")
		print("LAYOUT ",tag," board ",room.board.get_global_rect()," TP ",room.turning_panel.get_global_rect()," resume ",room.turning_panel.resume_button.get_global_rect())
		if is_instance_valid(screen):screen.free();screen=null
	quit()
