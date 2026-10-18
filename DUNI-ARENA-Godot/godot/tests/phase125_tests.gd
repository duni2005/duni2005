class_name Phase125Tests
extends RefCounted
var checks: int=0
var failures: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE12.5: "+label)
func run(tree: SceneTree) -> void:
	var fingerprints: Dictionary={}
	for type in range(26):
		var portrait: Texture2D=CharacterPainter.portrait(type);var weapon: Texture2D=CharacterPainter.weapon(type)
		verify(portrait!=null and weapon!=null,"authored portrait and original weapon %d"%type)
		verify(portrait.get_width()==128,"pixel portrait resolution")
		verify(weapon.get_width()==(2048 if type==10 else 1024),"unclipped source pose atlas")
		var signature: String=FileAccess.get_file_as_string("res://assets/characters/portrait_%02d.svg"%type).sha256_text()
		verify(not fingerprints.has(signature),"distinct character silhouette");fingerprints[signature]=true
		verify(not AbilityMotifs.MOTIFS[type].is_empty(),"named ultimate / special motif")
	var particles:=VisualParticles.new()
	for i in range(80):particles.burst(Vector2(400,400),Color.WHITE,100)
	verify(particles.entries.size()==VisualParticles.AMBIENT_LIMIT,"ambient budget leaves priority reserve")
	particles.burst(Vector2.ZERO,Color.CYAN,200,400,0,"shard",true)
	verify(particles.entries.size()>VisualParticles.AMBIENT_LIMIT and particles.entries.size()<=VisualParticles.LIMIT,"important impact reserve")
	for i in range(60):particles.advance(1.0/30)
	verify(particles.entries.is_empty(),"particle lifetime cleanup")
	var camera:=ArenaCameraController.new();camera.focus(Vector2(200,300));camera.impact(10,Vector2(200,300));camera.advance(.04)
	verify(camera.zoom>1 and camera.offset.length()>0,"focus and directional impulse")
	var point:=Vector2(263,459);verify((camera.transform().affine_inverse()*(camera.transform()*point)).distance_to(point)<.001,"presentation inverse coordinates")
	camera.advance(.02,true);verify(camera.zoom==1 and camera.offset==Vector2.ZERO,"TP / aim camera reset")
	camera.reset();verify(camera.pan==Vector2.ZERO and camera.zoom==1,"cleanup camera reset")
	var board:=DeploymentBoard.new();tree.root.add_child(board);board.size=Vector2(600,600);await tree.process_frame
	var b:=BattleManager.new();b.auto_start=false;board.add_child(b)
	verify(b.start_battle(Phase12Tests.new().placements(),731),"mixed common/full battle")
	b.set_physics_process(false);board.battle=b;board.editing=false;board.presentation.attach(b);board.presentation.set_process(false)
	var visual: CombatPresentation=board.presentation
	visual.advance(.01);visual.impact_pause(35);verify(is_equal_approx(visual.impact_remaining,.035),"35ms presentation freeze")
	visual.impact_pause(80);verify(is_equal_approx(visual.impact_remaining,.035),"160ms impact debounce")
	visual.advance(.2);visual.impact_pause(55);verify(is_equal_approx(visual.impact_remaining,.055),"55ms freeze")
	visual.advance(.2);visual.impact_pause(80);verify(is_equal_approx(visual.impact_remaining,.080),"80ms freeze")
	var before_time: float=b.clock.elapsed;var before_rng: int=b.rng.state;var hp: float=b.units[0].current_hp
	for i in range(10):visual.advance(.01)
	verify(b.clock.elapsed==before_time and b.rng.state==before_rng and b.units[0].current_hp==hp,"visual real timers cannot mutate gameplay")
	var u: BattleUnit=b.units[0]
	for state in [CombatController.State.WINDUP,CombatController.State.ACTIVE,CombatController.State.RECOVERY]:
		u.combat_state=state;u.combat.phase_time=.001
		verify(CharacterPainter.frame_for(u)==(1 if state==CombatController.State.WINDUP else 5 if state==CombatController.State.ACTIVE else 9),"actual phase selects source atlas")
	u.combat_state=CombatController.State.IDLE;verify(CharacterPainter.frame_for(u)==0,"idle atlas")
	visual.camera.focus(Vector2(200,200));visual.camera.advance(.05)
	var logical:=Vector2(180,360);var rect: Rect2=board.board_rect()
	var local: Vector2=rect.position+(visual.camera.transform()*logical)*rect.size.x/800
	verify(board.logical_point(local).distance_to(logical)<.001,"touch selection stays correct under zoom/focus")
	for kind in ["hit","critical","explosion","shield_break","parry_success","clash","death","reflect","heal","ultimate"]:
		visual.add_effect(kind,Vector2(300,400));verify(int(visual.generated.get(kind,0))>0,"composed VFX "+kind)
	verify(visual.particles.entries.size()>0,"events spawn actual CPU particles")
	var explosion_count: int=int(visual.generated.get("explosion",0))
	visual._explosion_once(9999,Vector2(410,420),160)
	verify(visual.effects.back().point==Vector2(410,420) and visual.effects.back().radius==160,"actual detonation point and radius")
	visual._explosion_once(9999,Vector2.ZERO,120)
	verify(int(visual.generated.get("explosion",0))==explosion_count+1,"one explosion per physical projectile, not per victim")
	verify(visual.effects.any(func(e):return e.kind=="parry_success" and e.radius==135),"source parry visual envelope")
	verify(visual.effects.any(func(e):return e.kind=="clash" and e.radius==150),"clash contact glyph envelope")
	visual.cleanup();verify(visual.particles.entries.is_empty() and visual.flashes.is_empty() and visual.freeze_positions.is_empty(),"all presentation buffers cleared")
	board.free();await tree.process_frame
	verify(ArenaUI.plain("🪙 아이템 🔒")=="아이템","normal card labels independent of emoji")
	for resolution in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1000,1100),Vector2i(390,844)]:
		tree.root.size=resolution;tree.root.content_scale_size=resolution
		var card:=ArenaCard.new();card.card_type="member";card.title="전사";card.subtitle="#1 · Lv. 0";card.custom_minimum_size=Vector2(155,182);tree.root.add_child(card)
		await tree.process_frame
		verify(card.size.x>=155 and card.size.y>=182,"portrait card bounds %s"%resolution)
		verify(card.get_theme_color("font_color").a==0,"semantic text not drawn over portrait")
		card.free()
	print("PHASE 12.5 RESULT: ",checks," checks; ",failures," failures; particle peak ",particles.peak)
