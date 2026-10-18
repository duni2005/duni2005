extends "res://tests/event_parity_runner.gd"
const CINEMA_OUT="res://migration/cinematic-flow/"
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("CINEMATIC FLOW: "+label)
func shot(name: String):
	print("CINEMATIC SCREEN ",tag," ",name)
	if DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(CINEMA_OUT+tag+"-"+name+".png")
func no_objects(value: Variant) -> bool:
	if value is Object:return false
	if value is Array:
		for e in value:
			if not no_objects(e):return false
	if value is Dictionary:
		for e in value.values():
			if not no_objects(e):return false
	return true
func prepare():
	await battle_fixture()
	var s: TowerBattleScreen=ui.battle_screen;var b: BattleManager=s.battle
	s.set_process(false);s.board.presentation.set_process(false)
	for i in range(b.units.size()):
		b.units[i].position=Vector2(290+i%3*90,290+i/3*100);b.units[i].velocity=Vector2(75,20);b.units[i].facing=.3
	var c: ArenaCameraController=s.board.presentation.camera;c.zoom=2.1;c.center=Vector2(400,400);c.pan=Vector2.ZERO
func ending_flow(reason: BattleEndReason.Value,label: String):
	await prepare();var s: TowerBattleScreen=ui.battle_screen;var b: BattleManager=s.battle;var v: CombatPresentation=s.board.presentation
	if reason==BattleEndReason.Value.RETREAT:b.clock.elapsed=20;verify(s.session.request_retreat(),"retreat accepted by unchanged simulation rule")
	else:
		for u in b.units:
			if u.original_team==(1 if reason==BattleEndReason.Value.VICTORY else 0):
				for attempt in range(8):
					if not u.alive:break
					u.invincible_remaining=0;u.parry_remaining=0;u.receive_damage(10000,b.units[0] if reason==BattleEndReason.Value.VICTORY else b.units[-1])
		b.check_outcome()
	verify(s.settlement_status==BattleSettlement.Status.APPLIED,"real ending is settled before presentation")
	var sequence: BattleCinematicState=s.end_sequence
	verify(sequence.started and sequence.kind==label,"shared sequence captures correct ending")
	verify(sequence.units.size()>0 and no_objects(sequence.units) and no_objects(sequence.projectiles),"detached finite pose data has no Nodes/Resources")
	verify(not s.result_overlay.visible and CinematicArtwork.title_alpha(label,0)==0,"no immediate text/result")
	var saved: String=pure();var elapsed: float=b.clock.elapsed;var rng: int=b.rng.state;var row: Dictionary=sequence.units[0].duplicate(true)
	var actor: BattleUnit=b.find_unit(row.id);var actor_point: Vector2=actor.position
	s._process(0);v.advance(.6);s._process(0)
	verify(v.camera.zoom<2.1 and v.camera.zoom>1,"camera begins with gradual pullback")
	verify(CinematicArtwork.darkness(label,sequence.age)==0 and CinematicArtwork.title_alpha(label,sequence.age)==0,"camera/motion phase precedes darkness/title")
	verify(sequence.position_for(row).distance_to(actor_point)>1 and actor.position==actor_point,"visual motion continues without moving stopped actors")
	await shot(label+"-camera")
	v.advance(.9);s._process(0)
	verify(v.camera.transform().is_equal_approx(Transform2D.IDENTITY),"entire arena shown before title")
	verify(BattleCinematicState.motion_seconds(1.7)-BattleCinematicState.motion_seconds(1.5)<BattleCinematicState.motion_seconds(.4)-BattleCinematicState.motion_seconds(.2),"unit motion visibly slows")
	v.advance(.6);s._process(0)
	verify(CinematicArtwork.darkness(label,sequence.age)>0 and CinematicArtwork.title_alpha(label,sequence.age)==0,"dimming follows slowdown, title still withheld")
	var stopped_point: Vector2=sequence.position_for(row);await shot(label+"-dim")
	v.advance(.95);s._process(0)
	verify(CinematicArtwork.title_alpha(label,sequence.age)>.8 and not s.result_overlay.visible,"title follows pullback/brake/dim, before result page")
	verify(sequence.position_for(row)==stopped_point,"detached motion has come to rest")
	verify(pure()==saved and b.clock.elapsed==elapsed and b.rng.state==rng and actor.position==actor_point,"whole sequence leaves guild/room/HP/RNG/clock/actor positions unchanged")
	verify(not s.feedback.visible and not s.selected_details.visible,"no bottom feed/detail text in ending")
	await shot(label+"-title")
	var title_age: float=sequence.age
	s._room_finished(b.result,BattleSettlement.Status.APPLIED)
	verify(sequence==s.end_sequence and is_equal_approx(sequence.age,title_age) and pure()==saved,"duplicate UI result cannot restart or settle again")
	v.advance(BattleCinematicState.DURATION-sequence.age-.01);s._process(0);await frames();verify(is_instance_valid(ui.battle_screen) and not sequence.complete,"no route/result before complete storyboard")
	v.advance(.02);s._process(0);await frames()
	if reason==BattleEndReason.Value.RETREAT:verify(ui.battle_screen==null and ui.controller.guild.state.tower.phase==&"route","retreat auto routes once after full sequence")
	else:
		verify(s.result_overlay.visible and not s.end_overlay.visible and fits(s.next_button),"victory/defeat result follows cinematic")
		verify(sequence.units.is_empty() and v.effects.is_empty() and v.particles.entries.is_empty(),"transition clears temporary visuals")
		await shot(label+"-result");await tap(s.next_button);verify(ui.battle_screen==null,"result CTA remains usable")
func turning_flow():
	await prepare();var s: TowerBattleScreen=ui.battle_screen;var b: BattleManager=s.battle;var v: CombatPresentation=s.board.presentation
	s.ai_debug_actor=b.units[0].actor_id();v.feed=["적 수호자 사망","아군 전사 사망"]
	s._process(0);verify(not s.feedback.visible and not s.selected_details.visible,"ordinary combat hides feed and selected-unit detail")
	s.toggle_debug();s._process(0);verify(s.feedback.visible and s.selected_details.visible,"explicit debug still exposes inspection tools")
	s.toggle_debug();s._process(0);verify(not s.feedback.visible and not s.selected_details.visible,"debug off restores clean HUD")
	s.battle_cue.cue="";await shot("clean-battle")
	b.clock.elapsed=12;b.turning.advance(.001);s.battle_cue.observe(b,0)
	var saved: String=pure();var rng: int=b.rng.state;var elapsed: float=b.clock.elapsed
	v.advance(.6);s.battle_cue.observe(b,.6);s._process(0)
	verify(CinematicArtwork.title_alpha("turning",s.battle_cue.turning_age)>0,"TP title shares the early pullback")
	verify(v.camera.zoom>1 and v.camera.zoom<2.1,"TP still eases toward overview")
	await shot("tp-camera")
	v.advance(1.4);b.turning.advance(2);s._process(0);s.battle_cue.observe(b,.5);await frames()
	verify(v.camera.transform().is_equal_approx(Transform2D.IDENTITY),"TP hold reveals all arena corners")
	verify(CinematicArtwork.title_alpha("turning",s.battle_cue.turning_age)>0,"TP one-line clock title continues into hold")
	verify(fits(s.turning_panel.resume_button) and s.turning_panel.resume_button.size.y>=44,"title art does not replace or cover TP input")
	verify(b.clock.elapsed==elapsed and b.rng.state!=rng,"only real TP plan generation, not camera, consumed RNG")
	# Once real plans exist, presentation-only animation must preserve all domain values.
	saved=pure();rng=b.rng.state;v.advance(.5);s.battle_cue.observe(b,.5)
	verify(pure()==saved and b.clock.elapsed==elapsed and b.rng.state==rng,"TP art never changes held simulation or plans")
	await shot("tp-title");await tap(s.turning_panel.resume_button);verify(b.clock.state==BattleClock.State.NORMAL,"manual resume remains usable through decorative overlay")
func run():
	root.gui_embed_subwindows=true
	for res in [Vector2i(390,844),Vector2i(1280,720)]:
		root.size=res;root.content_scale_size=res;tag="mobile" if res.x<500 else "desktop"
		await turning_flow()
		await ending_flow(BattleEndReason.Value.VICTORY,"victory")
		await ending_flow(BattleEndReason.Value.DEFEAT,"defeat")
		await ending_flow(BattleEndReason.Value.RETREAT,"retreat")
	ui.free();await frames();print("CINEMATIC FLOW RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
