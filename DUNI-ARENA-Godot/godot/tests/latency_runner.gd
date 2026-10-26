extends SceneTree
## Real asynchronous writer + transition regression. Uses a separate user slot.
var checks: int=0
var failures: int=0
var heartbeats: int=0
var metrics: Dictionary={}
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("LATENCY FAIL "+label)
func frames(count: int=3) -> void:
	for i in range(count):await process_frame
func pulse() -> void:heartbeats+=1
func run() -> void:
	root.size=Vector2i(390,844);root.content_scale_size=root.size
	var folder: String="user://latency-tests/"+Crypto.new().generate_random_bytes(8).hex_encode()
	var c:=TowerController.new();c.new_run(19,73)
	var save:=SaveManager.new(folder+"/autosave.json",true);save.attach(c)
	process_frame.connect(pulse)
	var start: int=Time.get_ticks_usec();save.request_autosave(c)
	metrics.capture_ms=(Time.get_ticks_usec()-start)/1000.0
	await save.wait_for_idle()
	verify(save.last_result.ok() and save.writes==1,"background atomic autosave succeeds")
	verify(heartbeats>0,"main loop keeps processing during writer")
	metrics.writer_ms=save.last_write_usec/1000.0;metrics.writer_heartbeats=heartbeats
	var first: Dictionary=save.read_document().document
	verify(first.schema_version==SaveMigrator.CURRENT_VERSION and first.run.tower.map.rooms.size()==120,"same current-version full map schema")
	var initial: int=c.guild.state.gold
	c.guild.state.gold+=1;save.request_autosave(c)
	c.guild.state.gold+=2;save.request_autosave(c)
	c.guild.state.gold+=3;save.request_autosave(c)
	await save.wait_for_idle()
	verify(save.writes==2 and save.read_document().run.gold==initial+6,"one frame requests coalesce latest snapshot")
	verify(save.read_file(save.path+".backup").run.gold==initial,"backup retains previous valid state")
	# A queued snapshot never reads the later live run from the writer thread.
	save.request_autosave(c);c.guild.state.gold+=10;await save.wait_for_idle()
	verify(save.read_document().run.gold==initial+6,"background writer sees detached boundary data")
	var before: String=FileAccess.get_file_as_string(save.path)
	var bad: Dictionary=save.snapshot(c).document;bad.schema_version=999
	verify(not save.write_document(bad).ok() and FileAccess.get_file_as_string(save.path)==before,"invalid document never replaces slot")
	save.write_text(save.path+".tmp","{")
	verify(not save.commit_temp().ok() and FileAccess.get_file_as_string(save.path)==before,"invalid temp preserves slot")
	FileAccess.open(save.path,FileAccess.WRITE).store_string("{")
	verify(save.read_document().ok() and save.read_document().from_backup,"corrupt primary recovers validated backup")
	c.select_room("0:3");await save.wait_for_idle()
	var plan:=DeploymentPlan.new(c.guild);var member: GuildMemberState=c.guild.all_members()[0]
	plan.place(member.member_id,Vector2(180,400))
	var b:=BattleManager.new();b.auto_start=false;root.add_child(b);b.set_physics_process(false)
	start=Time.get_ticks_usec();var began: bool=await c.start_battle_async(plan,b)
	metrics.async_start_total_ms=(Time.get_ticks_usec()-start)/1000.0
	verify(began and b.started and c.guild.state.tower.phase==&"battle","async checkpoint launches full battle")
	var checkpoint: SaveLoadResult=save.read_document()
	verify(checkpoint.ok() and checkpoint.document.recovery.kind=="battle" and checkpoint.run.tower.phase==&"deploy","checkpoint committed before first simulation")
	verify(checkpoint.run.last_formation.entries[0].position==Vector2(180,400),"checkpoint actual start formation")
	verify(not await c.start_battle_async(plan,b),"duplicate async battle rejected")
	var actor_id: String=b.units.filter(func(u):return u.source_member_id==member.member_id)[0].actor_id()
	verify(actor_id=="member:"+member.member_id,"actor IDs remain stable")
	b.clock.elapsed=21
	start=Time.get_ticks_usec();verify(c.session.request_retreat(),"real retreat settles")
	metrics.settle_main_ms=(Time.get_ticks_usec()-start)/1000.0
	await save.wait_for_idle()
	var settled: SaveLoadResult=save.load_controller()
	verify(settled.ok() and settled.run.tower.phase==&"result" and settled.document.recovery.is_empty(),"result persisted after complete settlement")
	verify(settled.run.tower.processed_results.size()==1,"one result receipt")
	var seed_state: int=settled.controller.combat_rng.state
	verify(settled.controller.return_map(),"loaded result can return map")
	await save.wait_for_idle()
	verify(settled.controller.combat_rng.state==seed_state,"save/routing do not consume combat RNG")
	settled.controller.release_runtime_connections();settled=null
	verify(c.return_map(),"return map succeeds");await save.wait_for_idle()
	var screen:=TowerScreen.new();screen.controller=c;screen.resume_saved=true;root.add_child(screen);await frames()
	var room_button: ArenaCard=screen.room_buttons["0:3"]
	var object_id: int=room_button.get_instance_id()
	start=Time.get_ticks_usec();screen.show_map();metrics.map_return_ms=(Time.get_ticks_usec()-start)/1000.0
	verify(screen.room_buttons["0:3"].get_instance_id()==object_id,"map return reuses room controls")
	verify(screen.room_buttons.size()==120,"all map controls retained")
	screen.select_room("0:3");await frames();screen.fx.advance(3)
	var ui: TowerBattleScreen=screen.battle_screen
	verify(ui!=null and ui.management_panel==null,"room entry defers hidden management page")
	ui._open_management();await frames()
	verify(ui.management_panel!=null and ui.management_panel.active_tab=="inventory","management still works on first request")
	ui.management_dialog.hide()
	ui.plan.place(member.member_id,Vector2(180,400))
	ui.start_battle();ui.start_battle()
	verify(ui.starting_battle and ui.loading_cover!=null,"entry immediately shows feedback and locks repeated taps")
	while ui.starting_battle:await process_frame
	verify(ui.battle.started and ui.loading_cover==null,"UI starts only after durable checkpoint")
	ui.battle.set_physics_process(false)
	verify(save.read_document().document.recovery.kind=="battle","UI checkpoint recoverable")
	# Snapshot references are weak for UI; destroying the view during background
	# writes must never pass any Nodes/brain objects to the save thread.
	screen.free();b.free();c.release_runtime_connections();await save.wait_for_idle();await frames()
	var rejected:=TowerController.new();rejected.new_run(19,73);rejected.select_room("0:3")
	var invalid_slot:=SaveManager.new("res://forbidden-slot.json",true);invalid_slot.attach(rejected)
	var rejected_plan:=DeploymentPlan.new(rejected.guild);rejected_plan.place(rejected.guild.all_members()[0].member_id,Vector2(180,400))
	var rejected_battle:=BattleManager.new();rejected_battle.auto_start=false;root.add_child(rejected_battle)
	var rng_before: int=rejected.combat_rng.state
	verify(not await rejected.start_battle_async(rejected_plan,rejected_battle) and not rejected_battle.started,"failed async checkpoint prevents simulation")
	verify(rejected.combat_rng.state==rng_before and not rejected.battle_preparing,"failed checkpoint restores seed source and input readiness")
	rejected_battle.free();rejected.release_runtime_connections()
	process_frame.disconnect(pulse)
	print("LATENCY METRICS ",JSON.stringify(metrics))
	var file:=FileAccess.open("res://migration/latency-fix/runtime-metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
	print("LATENCY RESULT: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
