extends SceneTree
## Regression: a completed parry counter must release its movement lock.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("UNIT STALL FAIL: "+label)
func fixture(full: bool=true) -> BattleManager:
	var b:=BattleManager.new();b.auto_start=false;b.full_characters_enabled=full;b.common_combat_enabled=true;b.set_physics_process(false);root.add_child(b)
	b.start_battle([{"data":BattleManager.WARRIOR,"team":0,"position":Vector2(300,400)},{"data":BattleManager.WARRIOR,"team":1,"position":Vector2(370,400)},{"data":BattleManager.ARCHER,"team":1,"position":Vector2(700,600)}],17)
	return b
func complete_counter(b: BattleManager,step: float) -> void:
	var u: BattleUnit=b.units[0];var enemy: BattleUnit=b.units[1]
	verify(u.combat.start_counter(u,enemy),"counter begins")
	verify(u.combat.counter and u.combat_state==CombatController.State.WINDUP,"counter movement lock during windup")
	for frame in range(ceili(1.0/step)):
		if u.combat_state==CombatController.State.IDLE:break
		b.clock.elapsed+=step
		var cooldown: float=u.combat.cooldown
		u.combat.advance(u,step,b)
		verify(is_equal_approx(u.combat.cooldown,cooldown-step),"attack completion preserves cooldown cadence")
	verify(u.combat_state==CombatController.State.IDLE,"counter recovery completed")
	verify(not u.combat.counter,"completed counter releases flag")
	verify(u.combat.attack_target==null,"completed attack releases target")
	verify(u.combat.profile(u).reach==u.data.attack_profile.reach,"normal profile restored")
func escaped_target(fps: int,dead: bool) -> void:
	var b:=fixture();var u: BattleUnit=b.units[0];var previous: BattleUnit=b.units[1];var survivor: BattleUnit=b.units[2]
	complete_counter(b,1.0/fps)
	if dead:previous.receive_damage(10000,u)
	else:previous.position=Vector2(720,400)
	u.target=u.target_selector.select_target(u,b.units);u.brain.begin(u,u.target,4.5);u.area_evaluator.initialized=true;u.area_evaluator.next_think=1000
	var before: Vector2=u.position;u.movement.advance(u,.1)
	verify(u.position.distance_to(before)>.5,"movement resumes after counter / fps=%d dead=%s"%[fps,dead])
	if dead:verify(u.target==survivor,"dead counter target replaced")
	var released: int=u.combat.attacks_released
	for enemy in b.units.slice(1):enemy.stun_remaining=100
	for frame in range(fps*7):
		if b.finished or u.combat.attacks_released>released:break
		b.simulate(1.0/fps)
	verify(u.combat.attacks_released>released,"can close distance and attack again / fps=%d dead=%s"%[fps,dead])
	b.free()
func chains() -> void:
	for type in [9,14]:
		var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);root.add_child(b)
		b.start_battle([{"data":CharacterCatalog.all()[type],"team":0,"position":Vector2(300,400)},{"data":BattleManager.WARRIOR,"team":1,"position":Vector2(350,400)}],41)
		var u: BattleUnit=b.units[0];u.combat.force_start(u,b.units[1]);var max_combo: int=0
		for frame in range(240):
			if u.combat_state==CombatController.State.IDLE:break
			u.combat.advance(u,1.0/60,b);max_combo=maxi(max_combo,int(u.combat.attack_metadata.get("combo",0)))
		verify(max_combo==2 and u.combat.attacks_released==3,"three-hit combo survives intermediate recovery: %d"%type)
		verify(u.combat_state==CombatController.State.IDLE,"combo completes: %d"%type)
		b.free()
func pause_and_interrupt() -> void:
	var b:=fixture();var u: BattleUnit=b.units[0];u.combat.start_counter(u,b.units[1]);b.clock.state=BattleClock.State.TURNING_PAUSED
	var before: Vector2=u.position;var phase: float=u.combat.phase_time
	u.combat.advance(u,2,b);u.movement.advance(u,2)
	verify(u.combat.counter and u.position==before and u.combat.phase_time==phase,"TP pauses counter without completing/cancelling it")
	b.clock.state=BattleClock.State.NORMAL;StatusController.stun(u,1)
	verify(not u.combat.counter and u.combat_state==CombatController.State.IDLE,"stun still cancels counter")
	b.free()
func real_parry() -> void:
	var b:=fixture();var u: BattleUnit=b.units[0];var enemy: BattleUnit=b.units[1]
	verify(u.parry.start(u,enemy),"real parry begins")
	var out: DamageOutcome=b.damage_resolver.resolve(enemy,u,16,{"critical":false,"attack_token":"stall-repro"})
	verify(out.parried and u.combat.counter,"actual hit creates parry counter")
	for other in b.units.slice(1):other.stun_remaining=100
	enemy.position=Vector2(720,400)
	for i in range(120):b.simulate(1.0/60)
	verify(not u.combat.counter,"real parry counter completes without idle movement lock")
	var before: Vector2=u.position;var releases: int=u.combat.attacks_released
	for i in range(60*8):
		if b.finished or u.combat.attacks_released>releases:break
		b.simulate(1.0/60)
	verify(u.position.distance_to(before)>20 and u.combat.attacks_released>releases,"real parry reconnects pursuit and regular attacks")
	b.free()
func run() -> void:
	for fps in [30,60,120]:
		for dead in [false,true]:escaped_target(fps,dead)
	var common:=fixture(false);complete_counter(common,1.0/60);common.free()
	chains();pause_and_interrupt();real_parry()
	print("UNIT STALL RESULT: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
