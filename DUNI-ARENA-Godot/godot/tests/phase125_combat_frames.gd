extends SceneTree
var rows: Array=[]
var seen: Dictionary={}
var board: DeploymentBoard
var b: BattleManager
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
	board.presentation.queue_redraw();await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://migration/phase125/after/duel-%s.png"%name)
	rows.append({"name":name,"simulation_time":b.clock.elapsed});seen[name]=true
func run() -> void:
	root.size=Vector2i(800,800);root.content_scale_size=root.size
	board=DeploymentBoard.new();board.editing=false;board.size=Vector2(800,800);root.add_child(board)
	b=BattleManager.new();b.auto_start=false;board.add_child(b)
	b.start_battle([{"data":CharacterCatalog.all()[0],"team":0,"position":Vector2(280,400)},{"data":CharacterCatalog.all()[0],"team":1,"position":Vector2(520,400)}],123)
	b.set_physics_process(false);board.battle=b;board.presentation.attach(b);board.presentation.set_process(false)
	await shot("zero")
	for i in range(6000):
		if b.finished:break
		b.simulate(1.0/60);board.presentation.advance(1.0/60)
		var flags: Array=[]
		if b.units.any(func(u):return u.combat_state==CombatController.State.WINDUP):flags.append("first-attack")
		if b.units.any(func(u):return u.current_hp<u.max_hp):flags.append("first-hit")
		if b.combat_event_counts.get(&"parry_success",0)>0 or b.combat_event_counts.get(&"warrior_parry",0)>0:flags.append("parry")
		if b.combat_event_counts.get(&"clash",0)>0:flags.append("clash")
		if b.units.any(func(u):return not u.alive):flags.append("death")
		for key in flags:
			if not seen.has(key):await shot(key)
	var f:=FileAccess.open("res://migration/phase125/after/duel-manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify({"matchup":"warrior vs warrior; 280,400 / 520,400; actual common/full events; seed123", "frames":rows},"  "));f.close()
	print("GODOT DUEL FRAMES ",rows);board.free();quit()
