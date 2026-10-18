extends SceneTree
var board: DeploymentBoard
var battle: BattleManager
var stage: String="after"
class Labels extends Control:
	func _draw():
		for row in [[Vector2(50,55),"패링 · 타격 · 사망"],[Vector2(50,340),"힘을 모은 뒤 빠른 참격"],[Vector2(50,610),"전사 궁극기 · 초승달 검기"]]:draw_string(ThemeDB.fallback_font,row[0],row[1],HORIZONTAL_ALIGNMENT_LEFT,700,22,Color("f1e6d3"))
func _initialize():call_deferred("run")
func run():
	if "--before" in OS.get_cmdline_user_args():stage="before"
	root.size=Vector2i(800,800);root.content_scale_size=root.size
	board=DeploymentBoard.new();board.size=Vector2(800,800);board.editing=false;root.add_child(board)
	var fixtures:=Phase8Tests.new();fixtures.host=self
	battle=fixtures.fixture([0,10,14,0,0],[0,0,0,0,1],[Vector2(140,450),Vector2(400,450),Vector2(660,450),Vector2(180,710),Vector2(780,710)])
	battle.set_physics_process(false);board.battle=battle;board.presentation.attach(battle);board.presentation.set_process(false)
	var labels:=Labels.new();labels.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(labels)
	var v: CombatPresentation=board.presentation
	v.add_effect("parry_success",Vector2(140,190),Color("8bdfff"));v.add_effect("hit",Vector2(400,190),Color("ffd39c"))
	# Same actual death event path as ordinary combat, including body and particles.
	var victim: BattleUnit=battle.units[4];var saved: Vector2=victim.position
	victim.position=Vector2(660,190);v._death(victim,battle.units[3]);victim.position=saved
	for i in range(3):battle.units[i].combat.force_start(battle.units[i],victim)
	var warrior: BattleUnit=battle.units[3];warrior.ultimate_gauge=100;warrior.ultimate.request(warrior,victim)
	for frame in range(24):
		var time: float=frame*.04;battle.clock.elapsed=time
		for i in range(3):
			var u: BattleUnit=battle.units[i];var p: AttackData=u.combat.profile(u)
			var t: float=fposmod(time,p.windup+p.active+p.recovery)
			u.combat_state=CombatController.State.WINDUP if t<p.windup else CombatController.State.ACTIVE if t<p.windup+p.active else CombatController.State.RECOVERY
			u.combat.phase_time=t if t<p.windup else t-p.windup if t<p.windup+p.active else t-p.windup-p.active
			u.combat.aim_angle=-.25;u.facing=-.25
		warrior.ultimate.advance_action(warrior,.04)
		for p in battle.projectiles:p.position+=p.velocity*.04
		v.advance(.04);v.camera.reset();v.queue_redraw()
		for i in range(2):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://migration/impact-refinement/%s-%02d.png"%[stage,frame])
	labels.free();board.free();battle.free();quit()
