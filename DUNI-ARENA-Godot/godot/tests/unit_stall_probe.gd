extends SceneTree
func _initialize():call_deferred("run")
func run():
	var rows: Array=[]
	for seed in [17,73,101]:
		var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);root.add_child(b);b.start_battle(BattleManager.default_placements(),seed)
		var stale: Dictionary={};var max_streak: Dictionary={};var streak: Dictionary={}
		for frame in range(60*40):
			if b.finished:break
			b.simulate(1.0/60)
			for u in b.units:
				var stuck: bool=u.alive and u.stun_remaining<=0 and u.combat_state==CombatController.State.IDLE and u.combat.counter and not u.unavailable() and not u.ability.locked(u) and u.ultimate.cast.is_empty()
				if stuck:stale[u.battle_id]=int(stale.get(u.battle_id,0))+1
				streak[u.battle_id]=float(streak.get(u.battle_id,0))+1.0/60 if stuck else 0.0
				max_streak[u.battle_id]=maxf(max_streak.get(u.battle_id,0),streak[u.battle_id])
		var row: Dictionary={"seed":seed,"time":b.clock.elapsed,"finished":b.finished,"stale_counter_ticks":stale,"longest_stale_seconds":max_streak,"parries":b.combat_event_counts.get(&"parry_success",0)};rows.append(row);print(JSON.stringify(row));b.free()
	var args: PackedStringArray=OS.get_cmdline_user_args();var path: String=args[0] if not args.is_empty() else "res://migration/unit-stall/probe.json"
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close();quit()
