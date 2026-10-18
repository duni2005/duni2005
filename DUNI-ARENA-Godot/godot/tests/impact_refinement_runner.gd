extends SceneTree
var checks: int=0
var failures: int=0
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("IMPACT REFINEMENT: "+label)
func _initialize():call_deferred("run")
func run():
	var fixtures:=Phase8Tests.new();fixtures.host=self
	for type in [0,3,10,14,16,19]:
		var b: BattleManager=fixtures.fixture([type,0],[0,1],[Vector2(200,400),Vector2(550,400)])
		var u: BattleUnit=b.units[0]
		u.combat.force_start(u,b.units[1]);u.set_state("paladinSwings",1)
		var profile: AttackData=u.combat.profile(u)
		var rng: int=b.rng.state;var start: float=b.clock.elapsed
		u.combat_state=CombatController.State.WINDUP;u.combat.phase_time=profile.windup*.5
		verify(WeaponMotion.sword_attack(u) and WeaponMotion.pose_progress(u)>.8,"early backswing settles into anticipation %d"%type)
		u.combat_state=CombatController.State.ACTIVE;u.set_state("paladinSwings",2);u.combat.phase_time=profile.active*.25
		verify(WeaponMotion.pose_progress(u)>.55,"fast visual slash %d"%type)
		verify(is_equal_approx(u.combat.phase_time,profile.active*.25) and b.rng.state==rng and b.clock.elapsed==start,"pose sampling never changes simulation %d"%type)
		b.free()
	var b: BattleManager=fixtures.fixture([0,0],[0,1],[Vector2(200,400),Vector2(650,400)])
	var u: BattleUnit=b.units[0];var visual:=CombatPresentation.new();root.add_child(visual);visual.attach(b);visual.set_process(false)
	u.ultimate_gauge=100
	verify(u.ultimate.request(u,b.units[1]),"actual warrior ultimate requested")
	var duration: float=u.ultimate.cast.duration
	u.ultimate.cast.t=duration*.8
	var pose: Dictionary=WeaponMotion.pose(u)
	verify(pose.key=="0:basic" and pose.index>=10 and float(pose.weapon_scale)>1.3,"ultimate has enlarged real sword anticipation")
	u.ultimate.advance(u,duration*.21)
	verify(b.projectiles.any(func(p):return p.kind=="swordWave"),"actual release creates sword wave")
	visual.advance(.01)
	verify(visual.weapon_releases.has(u.battle_id) and visual.generated.get("warrior_release",0)==1,"release presentation follows actual projectile")
	for i in range(5):visual.advance(.01)
	verify(visual.generated.get("warrior_release",0)==1,"same wave cannot repeat swing effect")
	var release: Dictionary=visual.weapon_releases.duplicate(true)
	b.clock.state=BattleClock.State.TURNING_PAUSED
	for i in range(20):visual.advance(.016)
	verify(visual.weapon_releases==release,"TP cannot advance release pose clock")
	b.clock.elapsed+=.3;visual.advance(.01)
	verify(visual.weapon_releases.is_empty(),"release pose expires")
	visual._death(b.units[1],u)
	var death: Dictionary=visual.effects.filter(func(e):return e.kind=="death").back()
	verify(death.radius>=115 and visual.particles.entries.size()<=VisualParticles.LIMIT,"large death wave and bounded debris")
	visual.add_effect("parry_success",Vector2(400,400))
	verify(visual.effects.back().radius==135,"wide pressure burst")
	visual.cleanup();verify(visual.weapon_releases.is_empty() and visual.effects.is_empty(),"release and wave cleanup")
	visual.free();b.free();await process_frame
	print("IMPACT REFINEMENT RESULT: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
