class_name Phase105Tests
extends RefCounted
var host: SceneTree
var checks: int=0
var failures: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE105 FAIL: "+label)
func match_at(type: int=0,point: Vector2=Vector2(400,400)) -> BattleManager:
	var b:=BattleManager.new();b.auto_start=false;host.root.add_child(b)
	b.start_battle([{"data":CharacterCatalog.all()[type],"team":0,"position":point},{"data":CharacterCatalog.all()[0],"team":1,"position":Vector2(620,400)},{"data":CharacterCatalog.all()[0],"team":0,"position":Vector2(300,460)}],17);b.set_physics_process(false);b.clock.elapsed=1
	var u: BattleUnit=b.units[0];u.current_hp=u.max_hp*.6;u.move_speed=u.data.move_speed;u.facing=0;u.combat.cooldown=0;u.target=b.units[1]
	u.brain.mode="observe";u.brain.think=5;u.brain.hold=5;u.brain.last_target=b.units[1].actor_id();u.brain.next_initiative_at=9;u.brain.commit_until=0;u.brain.phase=1.2;u.movement_phase=1.2;u.brain.side=1;u.brain.standoff=162;u.brain.swerve=1.1;u.brain.reaction=.2;u.brain.tempo=1;u.brain.patience=1;u.brain.goal=Vector2(700,400);u.brain.entry_plan="observe";u.brain.heading=Vector2.ZERO
	u.area_evaluator.initialized=true;u.area_evaluator.next_think=99
	# These checks pin the original web port; the tactical mind on top is tested separately.
	u.mind.enabled=false
	return b
func golden(data: Dictionary) -> void:
	for row in data.rows:
		var b:=match_at(int(row.type),Vector2(row.pos[0],row.pos[1]));var u: BattleUnit=b.units[0];var t: BattleUnit=b.units[1];u.brain.mode=row.get("mode","observe")
		if row.get("state","idle")!="idle":u.combat_state=CombatController.State.WINDUP if row.state=="windup" else CombatController.State.RECOVERY
		match row.kind:
			"general":u.brain.next_initiative_at=0;u.brain.move_general(u,t,.1)
			"precommit":u.brain.mode="observe";u.brain.entry_plan=row.mode;verify(u.brain.move_precommit(u,t,.1),"entry dispatch")
			"rear":
				var station: Dictionary=u.brain.rear_station(u,t);verify(station.point.distance_to(Vector2(row.expected.goal[0],row.expected.goal[1]))<.003,"rear station exact JS candidate")
				u.brain.move_rear(u,t,.1)
			"stance":u.stance=CombatStance.normalize(row.stance);u.cover_actor_id=b.units[2].actor_id();u.brain.move_stance(u,t,.1)
			"projectile":
				var p: BattleProjectile=b.PROJECTILE_SCENE.instantiate();p.initialize(t,PI);p.position=Vector2(450,400);p.velocity=Vector2(-470,0);p.lifetime=1;p.hit_radius=42;p.live=true;p.hidden_launch=false;p.projectile_id=9;b.projectiles.append(p);b.add_child(p);u.threat_response.projectile_notices[9]=.5
				u.brain.next_initiative_at=0;u.brain.move_general(u,t,.1)
			"bomb":
				var p: BattleProjectile=b.PROJECTILE_SCENE.instantiate();p.initialize(t,PI);p.position=Vector2(450,400);p.kind="bomb";p.velocity=Vector2.ZERO;p.live=true;p.hidden_launch=false;p.projectile_id=11;p.metadata={"fuse":.4,"blast_radius":120};b.projectiles.append(p);b.add_child(p);u.threat_response.projectile_notices[11]=.5
				verify(u.brain.move_bomb_escape(u,.1),"bomb escape source chance")
				u.threat_response.projectile_threat(u)
				verify(u.threat_response.projectile_notices.get(11)==.5,"live bomb retains perception roll during projectile scan")
			"separation":b.units[2].position=u.position;u.brain.next_initiative_at=0;u.brain.move_general(u,t,.1)
			"safe":
				var value: float=u.area_evaluator.support_value(u,{"kind":row.safeKind,"point":{"x":400.0,"y":400.0},"radius":165.0,"life":10.0},u.position)
				verify(is_equal_approx(value,row.expected),"actual JS safe influence "+row.safeKind);b.free();continue
			"risk":
				u.shield_hp=row.shield;u.shield_remaining=8;b.zones.add(t,"tankFire",Vector2(400,400),150,4)
				var risk: Dictionary=AreaEvaluator.evaluate(u,u.position)
				for key in ["total","hazard","crowd"]:verify(is_equal_approx(risk[key],row.expected[key]),"JS area risk "+key)
				b.free();continue
			"area_goal":
				if row.scenario=="hazard":b.zones.add(t,"tankFire",u.position,150,4)
				else:b.zones.add(b.units[2],"healing",Vector2(200,400),165,10)
				var choices: Dictionary=u.area_evaluator.goals(u)
				verify(choices.escape.point.distance_to(Vector2(row.expected.escape[0],row.expected.escape[1]))<.003,"JS danger/safe goal candidate")
				verify(is_equal_approx(choices.benefit,row.expected.benefit) and is_equal_approx(choices.improvement,row.expected.improvement),"JS area route and support score")
				if row.expected.refuge!=null:verify(choices.refuge.point.distance_to(Vector2(row.expected.refuge[0],row.expected.refuge[1]))<.003,"JS safe refuge selection")
				else:verify(choices.refuge.is_empty(),"no invented safe refuge")
				b.free();continue
		# Rush and cautious were reworked on purpose (StanceRules): checked for their new shape.
		if row.name=="stance_rush":
			verify(u.velocity.x>40 and absf(u.velocity.y)<absf(u.velocity.x)*.1 and u.brain.mode=="approach","rush walks straight at the target");b.free();continue
		if row.name=="stance_cautious":
			verify(absf(u.velocity.y)>absf(u.velocity.x) and u.velocity.length()>5,"cautious curves around the target instead of walking in");b.free();continue
		for pair in [["x",u.position.x],["y",u.position.y],["vx",u.velocity.x],["vy",u.velocity.y],["hx",u.brain.heading.x],["hy",u.brain.heading.y]]:verify(absf(row.expected[pair[0]]-pair[1])<.003,"direct JS "+row.name+" "+pair[0])
		verify(u.brain.mode==row.expected.mode,"JS movement plan "+row.name);b.free()
func policies(data: Dictionary) -> void:
	for row in data.policies:
		var b:=BattleManager.new();b.auto_start=false;host.root.add_child(b);var placements: Array[Dictionary]=[]
		for entry in row.entries:placements.append({"data":CharacterCatalog.all()[int(entry.type)],"team":int(entry.team),"position":Vector2(entry.x,entry.y)})
		b.start_battle(placements,17);b.set_physics_process(false)
		for i in range(b.units.size()):b.units[i].current_hp=row.entries[i].hp;b.units[i].stun_remaining=row.entries[i].stun
		var u: BattleUnit=b.units[0];u.saint_actor=b.units[4].actor_id();var target=u.target_selector.select_target(u,b.units)
		verify(b.units.find(target)==int(row.target),"direct JS unique target "+str(row.type));b.free()
	for row in data.chances:
		var b:=match_at();var u: BattleUnit=b.units[0];u.stance=CombatStance.normalize(row.stance);u.current_hp=u.max_hp*row.health;u.parry_cooldown=0 if row.ready else 12
		var value: Dictionary=ThreatResponseController.chances(u)
		if row.stance=="rush":
			# Rush lost the web's counter bonus: parry and dodge still match, the share goes to holding.
			verify(is_equal_approx(value.parry,row.expected.parry) and is_equal_approx(value.dodge,row.expected.dodge) and is_equal_approx(value.counter+value.hold,row.expected.counter+row.expected.hold) and value.counter<=row.expected.counter+1e-6,"rush reaction without the counter bonus");b.free();continue
		for key in ["parry","dodge","counter","hold"]:verify(is_equal_approx(value[key],row.expected[key]),"direct JS stance reaction probability")
		b.free()
func contracts() -> void:
	var b:=match_at();var u: BattleUnit=b.units[0];var t: BattleUnit=b.units[1]
	var before: Vector2=u.position;u.brain.move_precommit(u,t,.1);verify(u.position.x<before.x+.01,"observe initial entry does not charge")
	u.brain.begin(u,t,3);var due: float=u.brain.attack_decision.at;t.position=Vector2(750,400);u.brain.attack_ready(u,t);verify(u.brain.attack_decision.at==due,"intent timing survives distance loss")
	b.units[2].team=1;u.brain.attack_ready(u,b.units[2]);verify(u.brain.attack_decision.at==due and u.brain.attack_decision.actor==b.units[2].actor_id(),"intent timing survives target change")
	u.brain.think=4;u.brain.hold=4;u.brain.commit_until=0;u.brain.last_target=t.actor_id();u.brain.move_general(u,t,.1);verify(u.brain.decisions==0 and is_equal_approx(u.brain.think,3.9),"decision cadence held between thinks")
	u.brain.released(u);verify(u.brain.last_attack==1 and u.brain.disengage_until>=1.6,"post attack disengage lifetime")
	u.brain.reset_clash(u,false);verify(u.brain.attack_decision.is_empty() and u.brain.commit_until==0 and u.brain.next_initiative_at>u.brain.disengage_until,"clash intent reset")
	StatusController.stun(u,.7);verify(u.brain.disengage_until==1.7 and u.brain.next_initiative_at>1.7,"CC recovery clocks source contract")
	u.stun_remaining=0;u.command_retreat_until=9;u.retreat_point=Vector2(85,85);u.brain.commit_until=9;u.movement.advance(u,.1);verify(u.brain.movement_override=="forced_retreat" and not u.combat.can_start(u,t),"forced retreat wins over commit")
	u.command_retreat_until=0;u.brain.attack_decision={"actor":t.actor_id(),"at":6.0};u.target=t
	b.clock.state=BattleClock.State.TURNING_PAUSED;var snapshot: Dictionary=u.brain.debug_snapshot(u);before=u.position;b.simulate(1)
	verify(u.brain.debug_snapshot(u)==snapshot and u.position==before,"TP freezes full brain and steering")
	b.clock.state=BattleClock.State.NORMAL;t.receive_damage(10000,u);verify(u.target_selector.select_target(u,b.units)==b.units[2],"dead target replaced by remaining enemy");b.units[2].receive_damage(10000,u);verify(u.target_selector.select_target(u,b.units)==null,"target invalidation safe")
	b.free()
	# No per-frame new RNG consumption while a held plan uses a stable empty threat cache.
	b=match_at();u=b.units[0];t=b.units[1];u.brain.next_initiative_at=0;u.brain.hold=100;u.brain.think=100;var rng_before: int=b.rng.state
	for i in range(60):u.brain.move_general(u,t,1.0/60)
	verify(b.rng.state==rng_before,"held movement plan reuses randomness");b.free()
func additional_contracts() -> void:
	var b:=match_at(1,Vector2(180,400));var u: BattleUnit=b.units[0];var t: BattleUnit=b.units[1]
	u.brain.move_rear(u,t,.01);var point: Vector2=u.brain.rear_goal.point;var deadline: float=u.brain.rear_think_at;var state: int=b.rng.state
	for i in range(10):u.brain.move_rear(u,t,.01)
	verify(u.brain.rear_goal.point==point and u.brain.rear_think_at==deadline and b.rng.state==state,"rear goal/time/rolls retained between decisions")
	b.free();b=match_at();u=b.units[0];t=b.units[1]
	var seed_value: int=1
	while seed_value<1000:
		b.rng.seed=seed_value
		if b.rng.randf()<.32:break
		seed_value+=1
	b.rng.seed=seed_value;u.brain.last_attack=1;t.combat.cooldown=0
	verify(not u.brain.decide_initiative(u,t,3) and u.brain.hesitations==1 and u.brain.commit_until==0 and u.brain.next_initiative_at>1,"source hesitation schedules another probe")
	u.brain.hesitations=2;b.rng.seed=seed_value
	verify(u.brain.decide_initiative(u,t,3) and u.brain.commit_until>1 and not u.brain.attack_decision.is_empty(),"two hesitations then commit")
	u.combat_state=CombatController.State.IDLE;u.parry_cooldown=0;u.parry.start(u,t)
	verify(u.brain.attack_decision.is_empty() and u.brain.commit_until==0 and u.brain.disengage_until==1.55,"parry cancels intent and resets heading")
	u.parry_remaining=0;u.threat_response.response={"mode":&"hold","source_id":t.battle_id,"until":3};u.brain.commit_until=3;u.brain.attack_decision={"actor":t.actor_id(),"at":.5};u.brain.disengage_until=0
	verify(not u.threat_response.movement(u,.1) and u.brain.attack_ready(u,t),"source hold circles rather than stopping or blocking a commit")
	u.brain.attack_decision={"actor":t.actor_id(),"at":3};StatusController.stun(u,.3)
	verify(u.brain.attack_decision.is_empty() and u.brain.commit_until==0,"stun clears transient attack commitment")
	b.free()
func reaction_distribution() -> void:
	var reference: Array=JSON.parse_string(FileAccess.get_file_as_string("res://migration/phase105-web-reactions.json"));var results: Array=[]
	for row in reference:
		var b:=match_at();var u: BattleUnit=b.units[0];var t: BattleUnit=b.units[1];t.position=Vector2(470,400);u.current_hp=u.max_hp;u.stance=CombatStance.normalize(row.stance)
		var counts: Dictionary={"parry":0,"dodge":0,"counter":0,"hold":0}
		for i in range(int(row.trials)):
			b.clock.elapsed=i*3;u.parry_remaining=0;u.parry_cooldown=0;u.stun_remaining=0;u.evade_remaining=0;u.facing=0;u.combat_state=CombatController.State.IDLE;u.combat.counter=false;u.threat_response.response.clear();u.threat_response.read_attacks.clear();u.brain.attack_decision.clear();u.brain.commit_until=0;u.brain.disengage_until=0;u.brain.punish_until=0
			t.combat_state=CombatController.State.WINDUP;t.combat.attack_serial=i+1;t.combat.phase_time=0;t.combat.aim_angle=PI;t.combat.attack_target=u
			u.threat_response.advance(u);var key: String="%d:%d"%[t.battle_id,t.combat.attack_serial]
			verify(u.threat_response.read_attacks.has(key),"visible windup creates timed read")
			var record: Dictionary=u.threat_response.read_attacks[key];var rng_state: int=b.rng.state
			for ignored in range(3):u.threat_response.advance(u)
			verify(b.rng.state==rng_state,"reaction does not reroll per physics frame")
			b.clock.elapsed=record.at+.00001;u.threat_response.advance(u)
			verify(not u.threat_response.response.is_empty(),"timed threat response")
			counts[String(u.threat_response.response.get("mode",&"hold"))]+=1
		for kind in counts:
			var web: float=row.counts[kind]/float(row.trials);var ours: float=counts[kind]/float(row.trials)
			# Rush counters less than the web did (no counter bonus); the rest still matches.
			if row.stance=="rush" and kind in ["counter","hold"]:verify(ours<=web+.035 if kind=="counter" else ours>=web-.035,"rush reaction distribution "+kind)
			else:verify(absf(ours-web)<.035,"actual web/Godot reaction distribution "+row.stance+" "+kind)
		results.append({"stance":row.stance,"trials":row.trials,"counts":counts});b.free()
	FileAccess.open("res://migration/phase105-godot-reactions.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
func frame_rates() -> void:
	var positions: Array[Vector2]=[]
	for fps in [30,60,120]:
		var b:=match_at();var u: BattleUnit=b.units[0];u.brain.mode="circle";u.brain.next_initiative_at=0;u.brain.think=100;u.brain.hold=100
		for i in range(fps):u.brain.move_general(u,b.units[1],1.0/fps)
		verify(u.position.is_finite(),"FPS finite trajectory");positions.append(u.position);b.free()
	verify(positions[0].distance_to(positions[2])<3,"30/60/120 steering bounded integration error")
	print("AI FPS HELD CIRCLE POSITIONS ",positions)
func run(tree: SceneTree) -> void:
	host=tree;var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://migration/phase105-ai-golden.json"));golden(data);policies(data);contracts();additional_contracts();reaction_distribution();frame_rates()
	print("PHASE 10.5 RESULT: ",checks," checks; ",failures," failures")
