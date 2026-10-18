extends SceneTree
class Gallery extends Control:
	var b: BattleManager
	var column: int=0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color("101619"))
		for i in range(26):
			var at:=Vector2(90+(i%7)*180,85+(i/7)*190)
			var u: BattleUnit=b.units[i];u.position=at
			CharacterPainter.draw_unit(self,u,Transform2D.IDENTITY)
			AbilityMotifs.draw(self,u,at,1,.2)
			draw_string(ThemeDB.fallback_font,at+Vector2(-60,70),u.data.display_name,HORIZONTAL_ALIGNMENT_CENTER,120,15,Color("f3d48e"))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var b:=BattleManager.new();b.auto_start=false;root.add_child(b)
	var entries: Array[Dictionary]=[]
	for type in range(26):entries.append({"data":CharacterCatalog.all()[type],"team":type%2,"position":Vector2(200+(type%7)*65,150+(type/7)*120)})
	b.start_battle(entries,123);b.set_physics_process(false);b.hide()
	var gallery:=Gallery.new();gallery.b=b;gallery.size=Vector2(root.size);root.add_child(gallery)
	for pose in ["idle","windup","attack","recovery","stun","parry","ultimate"]:
		for u in b.units:
			u.stun_remaining=1 if pose=="stun" else 0;u.parry_remaining=1.2 if pose=="parry" else 0
			u.combat_state=CombatController.State.WINDUP if pose=="windup" else CombatController.State.ACTIVE if pose=="attack" else CombatController.State.RECOVERY if pose=="recovery" else CombatController.State.IDLE
			u.combat.phase_time=.12
		gallery.queue_redraw();await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://migration/phase125/after/characters-%s.png"%pose)
	print("PHASE125 GALLERY: 26 characters × 7 pose sheets")
	gallery.free();b.free();quit()
