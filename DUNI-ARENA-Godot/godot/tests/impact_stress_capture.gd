extends SceneTree
var board: DeploymentBoard
var battle: BattleManager
var failures: int=0
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(800,800);root.content_scale_size=root.size
	board=DeploymentBoard.new();board.size=Vector2(800,800);board.editing=false;root.add_child(board)
	battle=BattleManager.new();battle.auto_start=false;board.add_child(battle)
	battle.start_battle(Phase12Tests.new().placements(),731);battle.set_physics_process(false);board.battle=battle;board.presentation.attach(battle);board.presentation.set_process(false)
	for u in battle.units:u.ultimate_gauge=100
	var samples: Array[float]=[];var peaks: Dictionary={"particles":0,"lights":0,"fields":0,"echoes":0}
	for tick in range(360):
		battle.simulate(1.0/60);board.presentation.advance(1.0/60)
		if tick%3==0:
			var at: int=Time.get_ticks_usec();await process_frame;await RenderingServer.frame_post_draw;samples.append((Time.get_ticks_usec()-at)/1000.0)
			peaks.particles=maxi(peaks.particles,board.presentation.particles.entries.size());peaks.lights=maxi(peaks.lights,board.presentation.glow_layer.drawn);peaks.fields=maxi(peaks.fields,board.presentation.field_layer.active);peaks.echoes=maxi(peaks.echoes,board.presentation.afterimages.size())
			if tick in [60,120,180,240,300]:root.get_texture().get_image().save_png("res://migration/impact-refinement/stress-%d.png"%tick)
			if board.presentation.glow_layer.drawn>112:failures+=1
	var field_count: int=board.presentation.field_layer.pool.size();board.presentation.cleanup();await process_frame
	if board.presentation.field_layer.active!=0 or not board.presentation.afterimages.is_empty() or not board.presentation.particles.entries.is_empty():failures+=1
	root.get_texture().get_image().save_png("res://migration/impact-refinement/stress-cleanup.png")
	samples.sort();var metrics: Dictionary={"rendered_frames":samples.size(),"median_frame_wait_ms":samples[samples.size()/2],"p95_frame_wait_ms":samples[int(samples.size()*.95)],"peaks":peaks,"allocated_field_nodes":field_count,"failures":failures,"environment":"X11 Mesa llvmpipe; frame waits include scheduling, not Android FPS"}
	FileAccess.open("res://migration/impact-refinement/render-stress.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "));print("VFX RENDER STRESS: ",metrics)
	board.free();quit(1 if failures else 0)
