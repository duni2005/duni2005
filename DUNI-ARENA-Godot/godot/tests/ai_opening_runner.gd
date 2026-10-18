extends SceneTree
## Full tick comparison with normalized transient traits; not a production RNG mode.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://migration/phase105-web-openings.json"))
	var checks: int=0;var failures: int=0;var maximum: float=0;var results: Array=[]
	for row in rows:
		var b:=BattleManager.new();b.auto_start=false;root.add_child(b)
		b.start_battle([{"data":CharacterCatalog.all()[0],"team":0,"position":Vector2(180,400)},{"data":CharacterCatalog.all()[0],"team":1,"position":Vector2(620,400)}],17);b.set_physics_process(false)
		for u in b.units:
			u.facing=0 if u.team==0 else PI;u.movement_phase=1.2;u.move_speed=u.data.move_speed;u.combat.cooldown=0;u.brain.mode="observe";u.brain.think=99;u.brain.hold=99;u.brain.last_target="";u.brain.next_initiative_at=5;u.brain.commit_until=0;u.brain.phase=1.2;u.brain.side=1;u.brain.standoff=162;u.brain.swerve=1.1;u.brain.reaction=.2;u.brain.tempo=1;u.brain.patience=1;u.brain.entry_plan=row.plan;u.area_evaluator.initialized=true;u.area_evaluator.next_think=99
		var trace: Array=[]
		for tick in range(1,121):
			b.simulate(1.0/60)
			if tick%15!=0:continue
			var sample: Dictionary=row.trace[tick/15-1];var actors: Array=[]
			for i in range(b.units.size()):
				var u: BattleUnit=b.units[i];var expected: Dictionary=sample.actors[i];var error: float=u.position.distance_to(Vector2(expected.x,expected.y));maximum=maxf(maximum,error)
				for valid in [error<.003,u.brain.heading.distance_to(Vector2(expected.hx,expected.hy))<.003,is_equal_approx(u.current_hp,expected.hp),b.units.find(u.target)==int(expected.target),u.combat_state==CombatController.State.IDLE]:
					checks+=1
					if not valid:failures+=1;push_error("Opening mismatch "+row.plan+" time "+str(sample.time))
				actors.append({"x":u.position.x,"y":u.position.y,"hx":u.brain.heading.x,"hy":u.brain.heading.y,"hp":u.current_hp,"target":b.units.find(u.target)})
			trace.append({"time":b.clock.elapsed,"actors":actors})
		results.append({"plan":row.plan,"trace":trace});b.free()
	FileAccess.open("res://migration/phase105-godot-openings.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("OPENING RESULT: ",checks," checks; ",failures," failures; max_position_error=",maximum);quit(1 if failures else 0)
