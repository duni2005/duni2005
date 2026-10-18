extends SceneTree
var checks: int=0
var failures: int=0
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("VFX UPGRADE: "+label)
func _initialize():call_deferred("run")
func run():
	for texture in [VfxArt.GLOW,VfxArt.FLARE,VfxArt.GLINT,VfxArt.SMOKE,MagicFieldLayer.NOISE]:verify(texture!=null and texture.get_width()<=256,"small reusable texture")
	var board:=DeploymentBoard.new();board.size=Vector2(800,800);root.add_child(board)
	var active:=BattleManager.new();active.auto_start=false;board.add_child(active)
	var reference:=BattleManager.new();reference.auto_start=false;root.add_child(reference)
	verify(active.start_battle(Phase12Tests.new().placements(),731) and reference.start_battle(Phase12Tests.new().placements(),731),"mixed 12vs12 paired fixture")
	active.set_physics_process(false);reference.set_physics_process(false);board.battle=active;board.editing=false
	var visual: CombatPresentation=board.presentation;visual.attach(active);visual.set_process(false)
	verify(visual.glow_layer.mouse_filter==Control.MOUSE_FILTER_IGNORE and visual.field_layer.mouse_filter==Control.MOUSE_FILTER_IGNORE,"VFX layers never intercept touches")
	verify(visual.glow_layer.material.blend_mode==CanvasItemMaterial.BLEND_MODE_ADD,"dedicated bounded additive pass")
	for b in [active,reference]:
		for u in b.units:u.ultimate_gauge=100
	var before_rng: int=active.rng.state;var before_time: float=active.clock.elapsed
	for i in range(120):
		visual.add_effect(["explosion","critical","heal","parry_success","clash","ultimate","transcendence","shield_break"][i%8],Vector2(100+(i%4)*200,100+(i/4)*15),Color.CYAN)
	verify(active.rng.state==before_rng and active.clock.elapsed==before_time,"effects cannot consume combat RNG/time")
	verify(visual.effects.size()==CombatPresentation.MAX_EFFECTS and visual.particles.entries.size()<=VisualParticles.LIMIT,"simultaneous impact buffers capped")
	for i in range(25):active.zones.add(active.units[0],"blackhole" if i==24 else "galaxy",Vector2(400,400),80,1)
	visual.advance(.01)
	verify(visual.field_layer.pool.size()==MagicFieldLayer.LIMIT and visual.field_layer.active==MagicFieldLayer.LIMIT,"shader surfaces bounded and reused")
	verify(visual.field_layer.pool[0].material.get_shader_parameter("kind")==0,"blackhole priority reserve")
	var pool_count: int=visual.field_layer.get_child_count()
	visual.field_layer.sync(active.zones.entries,Transform2D.IDENTITY,.3)
	verify(visual.field_layer.get_child_count()==pool_count,"no field node churn")
	var camera_transform:=Transform2D(0,Vector2.ONE*1.8,0,Vector2(-180,-180))
	visual.field_layer.align(camera_transform)
	verify(visual.field_layer.pool[0].transform==camera_transform*visual.field_layer.logical[0],"shader and world share current camera, including zoom")
	visual.field_layer.clear();verify(visual.field_layer.pool.all(func(n):return not n.visible),"clear hides every pooled field")
	active.zones.entries.clear();visual.cleanup();visual.attach(active)
	var peak_fields: int=0;var peak_particles: int=0;var peak_echoes: int=0
	var start: int=Time.get_ticks_usec()
	for tick in range(900):
		active.simulate(1.0/60);reference.simulate(1.0/60);visual.advance(1.0/60)
		verify(active.rng.state==reference.rng.state and active.clock.elapsed==reference.clock.elapsed,"presentation preserves RNG/time")
		for i in range(active.units.size()):
			var a: BattleUnit=active.units[i];var r: BattleUnit=reference.units[i]
			verify(a.current_hp==r.current_hp and a.position==r.position and a.combat_state==r.combat_state and a.character_specific_state==r.character_specific_state,"full actor state parity")
		peak_fields=maxi(peak_fields,visual.field_layer.pool.size());peak_particles=maxi(peak_particles,visual.particles.entries.size());peak_echoes=maxi(peak_echoes,visual.afterimages.size())
		verify(visual.afterimages.size()<=CombatPresentation.MAX_AFTERIMAGES,"afterimage cap")
		if tick%120==0:await process_frame
	verify(peak_fields<=16 and peak_particles<=640 and peak_echoes<=48,"stress bounded")
	var digest: Array=[active.clock.elapsed,active.rng.state,active.units.map(func(u):return [u.current_hp,u.position,u.combat.phase_time])]
	active.clock.state=BattleClock.State.TURNING_PAUSED
	for i in range(90):visual.advance(1.0/60)
	verify([active.clock.elapsed,active.rng.state,active.units.map(func(u):return [u.current_hp,u.position,u.combat.phase_time])]==digest,"TP visuals cannot advance gameplay")
	visual.cleanup();verify(visual.effects.is_empty() and visual.particles.entries.is_empty() and visual.afterimages.is_empty() and visual.field_layer.active==0,"complete presentation cleanup")
	board.free();reference.free();await process_frame
	print("VFX UPGRADE RESULT: ",checks," checks; ",failures," failures; particles ",peak_particles," fields ",peak_fields," echoes ",peak_echoes," paired_ms ",(Time.get_ticks_usec()-start)/1000.0)
	quit(1 if failures else 0)
