extends SceneTree
var battle: BattleManager
var stage: String="before"
class Gallery extends Control:
	var battle: BattleManager
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color("10181e"))
		for u in battle.units:
			var t: int=u.data.type_id;var origin:=Vector2(10+(t%7)*145,25+(t/7)*215)
			draw_string(ThemeDB.fallback_font,origin,u.data.display_name,HORIZONTAL_ALIGNMENT_LEFT,142,15,Color("e3d2b1"))
			var parent:=Transform2D(0,Vector2.ONE*.62,0,origin+Vector2(25,105))
			draw_set_transform_matrix(parent);CharacterPainter.draw_unit(self,u,parent)
			draw_set_transform(Vector2.ZERO)
func _initialize():call_deferred("run")
func run():
	if "--after" in OS.get_cmdline_user_args():stage="after"
	root.size=Vector2i(1040,900);root.content_scale_size=root.size
	battle=BattleManager.new();battle.auto_start=false;root.add_child(battle)
	var entries: Array[Dictionary]=[]
	for type in range(26):entries.append({"data":CharacterCatalog.all()[type],"team":type%2,"position":Vector2(100+type%6*100,100+type/6*100)})
	battle.start_battle(entries,731);battle.set_physics_process(false);battle.hide()
	var gallery:=Gallery.new();gallery.battle=battle;gallery.size=Vector2(1040,900);root.add_child(gallery)
	for state in [CombatController.State.WINDUP,CombatController.State.ACTIVE,CombatController.State.RECOVERY]:
		for u in battle.units:
			u.position=Vector2.ZERO;u.facing=.12;u.combat.aim_angle=0;u.combat_state=state;var p: AttackData=u.combat.profile(u)
			u.combat.phase_time=(p.windup if state==CombatController.State.WINDUP else p.active if state==CombatController.State.ACTIVE else p.recovery)*.6
		gallery.queue_redraw()
		for i in range(4):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://migration/attack-motion/%s-motion-%d.png"%[stage,state])
	gallery.free();battle.free();quit()
