extends SceneTree
## Separate process producer/consumer; uses its own user data directory in orchestration.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("RESTART FAIL "+label)
func run() -> void:
	var mode: String=OS.get_cmdline_user_args()[0];var checkpoint: bool="checkpoint" in mode
	var save:=SaveManager.new("user://phase11-process/"+("checkpoint" if checkpoint else "complex")+".json")
	if mode.begins_with("write"):
		var c: TowerController
		if checkpoint:
			c=TowerController.new();c.new_run(19,73);save.attach(c);c.guild.all_members()[0].current_hp=43
			var room: RoomState=c.guild.state.tower.map.get_room("0:3");room.enemy_state.values()[0].current_hp=0;room.enemy_state.values()[1].current_hp=40;room.enemy_state.values()[1].position=Vector2(470,330);room.battle_attempt_count=1
			c.select_room("0:3");var plan:=DeploymentPlan.new(c.guild);plan.place(c.guild.all_members()[0].member_id,Vector2(180,400));var b:=BattleManager.new();b.auto_start=false;root.add_child(b);b.set_physics_process(false)
			verify(c.start_battle(plan,b),"producer live checkpoint")
			b.units[0].current_hp=1;b.units[0].position=Vector2(370,700)
			verify(save.manual_save(c).code==SaveLoadResult.Code.BUSY,"live frame not written")
			b.free();c.release_runtime_connections()
		else:
			c=Phase11Fixture.make();save.attach(c);verify(save.manual_save(c).ok(),"producer complex save")
		var expected: SaveLoadResult=save.read_document();verify(expected.ok(),"producer verifies disk")
		FileAccess.open("user://phase11-process/expected_"+("checkpoint" if checkpoint else "complex")+".json",FileAccess.WRITE).store_string(JSON.stringify(expected.document))
	else:
		var loaded: SaveLoadResult=save.load_controller();verify(loaded.ok(),"consumer load "+loaded.detail)
		if loaded.ok():
			var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://phase11-process/expected_"+("checkpoint" if checkpoint else "complex")+".json"))
			verify(JSON.parse_string(JSON.stringify(SaveDomainCodec.new().encode(loaded.run,"run")))==expected.run,"fresh process run equivalence")
			verify(loaded.run.tower.map.rooms.size()==120 and loaded.run.tower.map.floors.size()==15,"consumer complete map")
			if checkpoint:
				var c: TowerController=loaded.controller;var plan:=DeploymentPlan.new(c.guild);plan.restore(loaded.run.last_formation);var b:=BattleManager.new();b.auto_start=false;root.add_child(b);b.set_physics_process(false)
				verify(c.start_battle(plan,b),"consumer starts same attempt")
				verify(b.rng.seed==int(expected.recovery.seed) and b.units[0].current_hp==43 and b.units[0].position==Vector2(180,400),"consumer prebattle seed HP placement")
				verify(b.units.filter(func(u):return not u.source_enemy_id.is_empty()).size()==3 and b.turning.next_at==12,"consumer dead enemy omitted and fresh TP")
				b.free();c.release_runtime_connections()
	print("RESTART ",mode," RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
