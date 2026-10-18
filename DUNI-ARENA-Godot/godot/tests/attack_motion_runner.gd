extends SceneTree
var checks: int=0
var failures: int=0
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("ATTACK MOTION: "+label)
func _initialize():call_deferred("run")
func run():
	var fixtures:=Phase8Tests.new();fixtures.host=self
	for type in range(26):
		var b: BattleManager=fixtures.fixture([type,0,1],[0,1,0],[Vector2(150,400),Vector2(450,400),Vector2(650,650)])
		var u: BattleUnit=b.units[0];var enemy: BattleUnit=b.units[1]
		u.combat.force_start(u,enemy)
		for state in [CombatController.State.WINDUP,CombatController.State.ACTIVE,CombatController.State.RECOVERY]:
			u.combat_state=state
			var p: AttackData=u.combat.profile(u)
			var duration: float=p.windup if state==CombatController.State.WINDUP else p.active if state==CombatController.State.ACTIVE else p.recovery
			for progress in [0.0,.5,1.0]:
				u.combat.phase_time=duration*progress
				var pose: Dictionary=WeaponMotion.pose(u)
				verify(WeaponMotion.DATA.banks.has(pose.key),"real source pose bank %d"%type)
				verify(pose.index==1+(state-1)*12+roundi(WeaponMotion.pose_progress(u)*11),"presentation phase sampling %d"%type)
				verify(pose.angle==u.combat.aim_angle,"weapon follows committed attack direction %d"%type)
		if type in [9,14]:
			u.combat.attack_metadata.combo=2;verify(WeaponMotion.pose(u).key=="%d:combo2"%type,"finisher is not first hit")
		if type==16:
			u.combat_state=CombatController.State.WINDUP;u.set_state("paladinSwings",1);verify(WeaponMotion.pose(u).key=="16:sword","second windup sword")
			u.combat_state=CombatController.State.ACTIVE;u.set_state("paladinSwings",2);verify(WeaponMotion.pose(u).key=="16:sword","release increment keeps sword pose")
		u.combat.cancel(u);u.ultimate.cast={"t":.5,"duration":1.0,"angle":.78}
		verify(WeaponMotion.pose(u).key==("0:basic" if type==0 else "%d:ultimate"%type),"ultimate source pose %d"%type)
		verify(WeaponMotion.pose(u).angle==.78,"ultimate aim retained")
		b.free()
	var board:=DeploymentBoard.new();root.add_child(board);board.size=Vector2(600,600)
	var b: BattleManager=fixtures.fixture([24,0,1],[0,1,1],[Vector2(150,400),Vector2(500,400),Vector2(680,650)])
	var frog: BattleUnit=b.units[0];var victim: BattleUnit=b.units[1]
	verify(CharacterLifecycle.capture(frog,victim),"frog real capture")
	verify(AttackVisuals.body_visible(victim),"pulling victim visible before swallow")
	CharacterLifecycle.advance_frog(frog,.6)
	verify(frog.frog_action.phase=="hold" and not AttackVisuals.body_visible(victim),"hold hides victim only at mouth")
	CharacterLifecycle.advance_frog(frog,.7)
	verify(victim.frog_flight!=0 and not AttackVisuals.body_visible(victim),"flight body drawn once by projectile renderer")
	board.battle=b;board.presentation.attach(b);board.presentation.set_process(false)
	var visual: CombatPresentation=board.presentation
	visual.advance(.01);var before: Dictionary=visual.projectile_trails.duplicate(true)
	b.clock.state=BattleClock.State.TURNING_PAUSED
	for i in range(20):visual.advance(.016)
	verify(visual.projectile_trails==before,"TP presentation cannot lengthen trails")
	verify(visual.projectile_trails.values().all(func(t):return t.size()<=10),"trail budget")
	visual.cleanup();verify(visual.projectile_trails.is_empty() and visual.projectile_origins.is_empty() and visual.release_counts.is_empty(),"visual tracking cleanup")
	b.free();board.free()
	# All 26 characters, actual simulation plus presentation, versus an untouched reference.
	var entries: Array[Dictionary]=[]
	for type in range(26):entries.append({"data":CharacterCatalog.all()[type],"team":type%2,"position":Vector2(110+(type%2)*470+(type%3)*35,70+(type/3)*72)})
	var active:=BattleManager.new();active.auto_start=false;root.add_child(active)
	var reference:=BattleManager.new();reference.auto_start=false;root.add_child(reference)
	verify(active.start_battle(entries,1461) and reference.start_battle(entries,1461),"26 character paired scenario")
	active.set_physics_process(false);reference.set_physics_process(false)
	visual=CombatPresentation.new();root.add_child(visual);visual.attach(active);visual.set_process(false)
	var peak: int=0
	for tick in range(900):
		active.simulate(1.0/60);reference.simulate(1.0/60);visual.advance(1.0/60)
		verify(active.rng.state==reference.rng.state and active.clock.elapsed==reference.clock.elapsed,"visuals preserve RNG/time")
		for i in range(26):
			var a: BattleUnit=active.units[i];var r: BattleUnit=reference.units[i]
			verify(a.position==r.position and a.current_hp==r.current_hp and a.combat_state==r.combat_state and a.character_specific_state==r.character_specific_state,"visuals preserve actor state")
		peak=maxi(peak,visual.particles.entries.size())
		verify(visual.projectile_trails.size()<=active.projectiles.size(),"dead projectile traces pruned")
		if tick%120==0:await process_frame
	verify(visual.effects.size()<=CombatPresentation.MAX_EFFECTS and peak<=VisualParticles.LIMIT,"finite effects/particle buffers")
	visual.cleanup();visual.free();active.free();reference.free();await process_frame
	print("ATTACK MOTION RESULT: ",checks," checks; ",failures," failures; peak particles ",peak);quit(1 if failures else 0)
