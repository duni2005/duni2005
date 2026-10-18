extends "res://tests/event_parity_runner.gd"
func run():
	root.gui_embed_subwindows=true
	for res in [Vector2i(390,844),Vector2i(1280,720)]:
		root.size=res;root.content_scale_size=res;tag="mobile" if res.x<500 else "desktop"
		await battle_fixture();var s: TowerBattleScreen=ui.battle_screen;var b: BattleManager=s.battle
		s.set_process(false);s.board.presentation.set_process(false)
		var cam: ArenaCameraController=s.board.presentation.camera
		cam.zoom=2;cam.center=Vector2(340,420);cam.pan=Vector2(120,-40)
		b.clock.elapsed=12;b.turning.advance(.001);s.board.presentation.advance(.5);s.battle_cue.observe(b,0);s.battle_cue.observe(b,.5)
		await shot("tp-slowdown")
		s.board.presentation.advance(1.5);b.turning.advance(2);s._process(0);s.set_process(false);s.board.presentation.advance(.1)
		verify(cam.transform().is_equal_approx(Transform2D.IDENTITY),"final TP overview")
		s.battle_cue.cue="";await shot("tp-hold")
	ui.free();await frames();print("FINAL TP CAPTURE RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
