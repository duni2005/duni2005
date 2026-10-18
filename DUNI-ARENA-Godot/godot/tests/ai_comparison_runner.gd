extends SceneTree
## Actual full-mode ticks, independent motion and decision telemetry.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var case_path: String=args[1] if args.size()>1 else "res://migration/phase105-scenarios.json"
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string(case_path));var results: Array=[]
	for scenario in cases:
		var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);root.add_child(b)
		var placements: Array[Dictionary]=[]
		for e in scenario.entries:placements.append({"data":CharacterCatalog.all()[int(e.type)],"team":int(e.team),"position":Vector2(e.x,e.y)})
		b.start_battle(placements,int(scenario.seed));b.set_physics_process(false)
		for i in range(b.units.size()):b.units[i].stance=CombatStance.normalize(scenario.entries[i].stance)
		var m: Dictionary={"name":scenario.name,"seed":scenario.seed,"first_attack":null,"first_hit":null,"attacks":0,"hits":0,"parry":0,"dodge":0,"clash":0,"travel":0.0,"gap":0.0,"gap_samples":0,"target_changes":0,"idle":0.0,"danger_time":0.0,"escape":0,"trace":[]}
		var previous: Array=[]
		for u in b.units:previous.append({"point":u.position,"target":null,"serial":0,"hp":u.current_hp,"escape":false})
		var sample: float=0
		for tick in range(int(scenario.seconds*scenario.fps)):
			if b.finished:break
			var dt: float=1.0/scenario.fps;b.simulate(dt)
			for i in range(b.units.size()):
				var u: BattleUnit=b.units[i];var p: Dictionary=previous[i]
				m.travel+=u.position.distance_to(p.point);p.point=u.position
				if u.combat.attack_serial!=p.serial:
					p.serial=u.combat.attack_serial
					if u.combat.healing_target==null:
						m.attacks+=1
						if m.first_attack==null:m.first_attack=b.clock.elapsed
				if u.current_hp<p.hp:
					m.hits+=1
					if m.first_hit==null:m.first_hit=b.clock.elapsed
				p.hp=u.current_hp
				var target: int=b.units.find(u.target)
				if target!=p.target:
					if p.target!=null and p.target!=-1:m.target_changes+=1
					p.target=target
				if u.alive:
					var foes: Array=b.units.filter(func(e):return e.alive and e.team!=u.team)
					if not foes.is_empty():
						var gap: float=INF
						for e in foes:gap=minf(gap,u.position.distance_to(e.position))
						m.gap+=gap;m.gap_samples+=1
					if u.combat_state==CombatController.State.IDLE and u.ultimate.cast.is_empty():m.idle+=dt
					if AreaEvaluator.evaluate(u,u.position).total>.2:m.danger_time+=dt
					var escape: bool=u.area_evaluator.escape_until>b.clock.elapsed and not u.area_evaluator.supporting
					if escape and not p.escape:m.escape+=1
					p.escape=escape
			if b.clock.elapsed>=sample-1e-8:
				var actors: Array=[]
				for u in b.units:actors.append({"x":u.position.x,"y":u.position.y,"hp":u.current_hp,"alive":u.alive,"target":b.units.find(u.target),"plan":u.brain.mode,"intent":u.brain.attack_decision.get("at"),"state":CombatController.State.keys()[u.combat_state].to_lower(),"heading":[u.brain.heading.x,u.brain.heading.y],"desired":[u.brain.desired_direction.x,u.brain.desired_direction.y],"movement":u.brain.movement_override,"initiative":u.brain.next_initiative_at})
				m.trace.append({"time":b.clock.elapsed,"actors":actors});sample+=.25
		m.parry=b.combat_event_counts.get(&"parry_start",0);m.clash=b.combat_event_counts.get(&"clash",0)
		for u in b.units:m.dodge+=u.threat_response.counts.get(&"dodge",0)
		m.gap=m.gap/m.gap_samples if m.gap_samples>0 else 0;m.duration=b.clock.elapsed;m.completed=b.finished
		results.append(m);print("COMPARE ",scenario.name," ",scenario.seed," attack=",m.first_attack," travel=",m.travel);b.free();await process_frame
	var output: String="res://migration/phase105-godot-before.json"
	if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "));quit()
