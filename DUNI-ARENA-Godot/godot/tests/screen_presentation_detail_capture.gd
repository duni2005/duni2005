extends SceneTree
const OUT="res://migration/screen-presentation/"
var ui: TowerScreen
func _initialize():call_deferred("run")
func frames():
	for i in range(5):await process_frame
func shot(name: String):
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func reset():
	if is_instance_valid(ui):ui.free();await frames()
	ui=TowerScreen.new();root.add_child(ui);ui.controller.new_run(19,73);ui.show_map();await frames();ui.fx.set_process(false)
func run():
	root.gui_embed_subwindows=true
	for res in [Vector2i(390,844),Vector2i(1280,720)]:
		root.size=res;root.content_scale_size=res;var tag: String="mobile" if res.x<500 else "desktop"
		await reset();ui.select_room("0:0");await frames();ui.fx.advance(2.2)
		var offer: RecruitOffer=ui.controller.current_room().recruit.offers[0]
		ui.content_screen._action(&"recruit",{"offer_id":offer.offer_id});await frames();ui.fx.advance(.85)
		ui.fx.skip_recruit();ui.fx.advance(0);await shot(tag+"-recruit")
		await reset();ui.select_room("0:3");await frames();ui.fx.advance(2.2)
		var room_ui: TowerBattleScreen=ui.battle_screen
		for i in range(4):room_ui.plan.place(ui.controller.guild.all_members()[i].member_id,Vector2(100+i%2*140,200+i/2*220))
		room_ui.start_battle();await frames();var b: BattleManager=room_ui.battle;b.set_physics_process(false)
		var visual: CombatPresentation=room_ui.board.presentation;visual.set_process(false)
		b.clock.elapsed=12;b.simulate(.5);b.simulate(1.5);visual.advance(.001);await frames();await shot(tag+"-tp")
	ui.free();quit()
