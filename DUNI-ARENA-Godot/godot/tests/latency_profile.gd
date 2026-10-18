extends SceneTree
var report: Dictionary={}
class TimedScreen extends TowerBattleScreen:
	func _build_ui() -> void:
		var t: int=Time.get_ticks_usec();super._build_ui();print("BUILD base_ui_ms=",(Time.get_ticks_usec()-t)/1000.0)
	func _build_tower_result() -> void:
		var t: int=Time.get_ticks_usec();super._build_tower_result();print("BUILD result_ui_ms=",(Time.get_ticks_usec()-t)/1000.0)
	func begin_deployment() -> void:
		var t: int=Time.get_ticks_usec();super.begin_deployment();print("BUILD begin_deployment_ms=",(Time.get_ticks_usec()-t)/1000.0)
func _initialize() -> void:call_deferred("run")
func measure(label: String,action: Callable,count: int=1) -> void:
	var samples: Array=[]
	for i in range(count):
		var start: int=Time.get_ticks_usec();action.call();samples.append((Time.get_ticks_usec()-start)/1000.0)
	report[label]=samples;print("LATENCY ",label," ms ",samples)
func run() -> void:
	root.size=Vector2i(390,844);root.content_scale_size=root.size
	var c:=TowerController.new();measure("new_run",func():c.new_run(19,73))
	var save:=SaveManager.new("user://latency-profile/autosave.json");save.attach(c)
	var snap: SaveLoadResult
	measure("snapshot",func():save.snapshot(c),3)
	snap=save.snapshot(c)
	measure("write_document",func():save.write_document(snap.document),3)
	measure("request_autosave",func():save.request_autosave(c),3)
	measure("flush_autosave",func():save.flush_autosave())
	c.select_room("0:3");save.flush_autosave()
	var screen:=TimedScreen.new();screen.tower_controller=c
	measure("deployment_build",func():root.add_child(screen))
	var warm:=TimedScreen.new();warm.tower_controller=c
	measure("deployment_build_warm",func():root.add_child(warm));warm.free()
	for i in range(8):await process_frame
	for member in c.guild.all_members():screen.plan.place(member.member_id,Vector2(140,150+screen.plan.entries().size()*140))
	measure("battle_start",screen.start_battle)
	if is_instance_valid(screen.battle):screen.battle.set_physics_process(false)
	measure("battle_ui_100_frames",func():screen._process(1.0/60),100)
	if is_instance_valid(screen.battle):
		measure("simulation_tick",func():screen.battle.simulate(1.0/60),120)
		measure("settle_retreat",func():screen.battle.clock.elapsed=21;screen.session.request_retreat())
	measure("result_autosave",func():save.flush_autosave())
	screen.free();c.release_runtime_connections()
	var dest: String="/workspace/arena/godot/migration/latency-fix/"+("after" if "--after" in OS.get_cmdline_user_args() else "before")+"-profile.json"
	var file:=FileAccess.open(dest,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	quit()
