extends SceneTree
## VFX ON/OFF through the actual TowerController -> settlement/reward/progression path.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("ROOM PAIRED: "+label)
func run() -> void:
	var controllers: Array[TowerController]=[];var battles: Array[BattleManager]=[]
	var board:=DeploymentBoard.new();board.editing=false;board.size=Vector2(800,800);root.add_child(board)
	for index in range(2):
		var c:=TowerController.new();c.new_run(19,73);c.select_room("0:3")
		# Both replicas enter the same already damaged room, as on a normal retry.
		c.current_room().battle_attempt_count=1
		for e in c.current_room().enemy_state.values():e.current_hp*=.25
		var plan:=DeploymentPlan.new(c.guild)
		for i in range(c.guild.all_members().size()):
			var m: GuildMemberState=c.guild.all_members()[i];m.ultimate_gauge=100
			plan.place(m.member_id,Vector2(100+(i%2)*160,180+(i/2)*270))
		var b:=BattleManager.new();b.auto_start=false
		if index==0:board.add_child(b)
		else:root.add_child(b);b.hide()
		verify(c.start_battle(plan,b),"actual tower attempt starts")
		b.set_physics_process(false);controllers.append(c);battles.append(b)
	var a: BattleManager=battles[0];var b: BattleManager=battles[1]
	board.battle=a;board.presentation.attach(a);board.presentation.set_process(false)
	var equal: bool=true;var tick: int=0;var started: int=Time.get_ticks_msec()
	while tick<18000 and (not a.finished or not b.finished):
		a.simulate(1.0/60);b.simulate(1.0/60);board.presentation.advance(1.0/60);tick+=1
		if a.rng.state!=b.rng.state or a.clock.elapsed!=b.clock.elapsed or a.finished!=b.finished:equal=false;break
		for i in range(a.units.size()):
			if a.units[i].current_hp!=b.units[i].current_hp or a.units[i].position!=b.units[i].position or a.units[i].combat_state!=b.units[i].combat_state:equal=false;break
		if not equal:break
		if tick%120==0:await process_frame
	verify(equal,"all ticks RNG/HP/position/attack state equal")
	verify(a.finished and b.finished,"both naturally reach a result")
	if a.finished and b.finished:
		verify(a.result.end_reason==b.result.end_reason and a.result.winner_team==b.result.winner_team,"battle result equal")
		var ca: TowerController=controllers[0];var cb: TowerController=controllers[1]
		verify(ca.current_room().cleared==cb.current_room().cleared and ca.current_room().cleared,"victory room cleared in both")
		verify(ca.guild.state.gold==cb.guild.state.gold and ca.guild.state.tokens==cb.guild.state.tokens and ca.guild.state.player_hp==cb.guild.state.player_hp,"actual rewards and player HP equal")
		verify(ca.current_room().reward_claimed and cb.current_room().reward_claimed,"actual room reward receipt")
		verify(ca.guild.state.tower.processed_results.size()==1 and cb.guild.state.tower.processed_results.size()==1,"single result processing")
		var members_equal: bool=true
		for i in range(ca.guild.all_members().size()):
			var x: GuildMemberState=ca.guild.all_members()[i];var y: GuildMemberState=cb.guild.all_members()[i]
			if x.current_hp!=y.current_hp or x.energy!=y.energy or x.ultimate_gauge!=y.ultimate_gauge or x.character_specific_state!=y.character_specific_state:members_equal=false
		verify(members_equal,"settled member HP/energy/gauge/persistence equal")
		var enemies_equal: bool=true
		for id in ca.current_room().enemy_state:
			var x: EnemyRoomState=ca.current_room().enemy_state[id];var y: EnemyRoomState=cb.current_room().enemy_state[id]
			if x.current_hp!=y.current_hp or x.position!=y.position or x.ultimate_gauge!=y.ultimate_gauge or x.persistent_state!=y.persistent_state:enemies_equal=false
		verify(enemies_equal,"settled enemy room state equal")
		verify(ca.guild.state.tower.phase==cb.guild.state.tower.phase and ca.guild.state.tower.unlocked_floor==cb.guild.state.tower.unlocked_floor,"tower phase/progression equal")
	board.presentation.cleanup();verify(board.presentation.particles.entries.is_empty() and board.presentation.camera.zoom==1,"presentation end cleanup")
	print("ROOM PAIRED RESULT: ",checks," checks; ",failures," failures; ticks=",tick," sim=",a.clock.elapsed," wall_ms=",Time.get_ticks_msec()-started," display=",DisplayServer.get_name())
	board.free();b.free()
	for c in controllers:c.release_runtime_connections()
	quit(1 if failures else 0)
