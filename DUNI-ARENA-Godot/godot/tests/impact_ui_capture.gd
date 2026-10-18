extends SceneTree
const OUT="res://migration/impact-ui/"
var ui: TowerScreen
func _initialize():call_deferred("run")
func frames():
	for i in range(4):await process_frame
func shot(label: String):
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+label+".png")
func fresh():
	if is_instance_valid(ui):ui.free();await frames()
	ui=TowerScreen.new();root.add_child(ui);ui.controller.new_run(19,73);ui.show_map();await frames();ui.fx.set_process(false)
func run():
	root.gui_embed_subwindows=true
	for res in [Vector2i(390,844),Vector2i(1280,720)]:
		root.size=res;root.content_scale_size=res;var tag: String="mobile" if res.x<500 else "desktop"
		await fresh();var room: RoomState=ui.controller.guild.state.tower.map.get_room("0:4");room.event_type=&"prediction";room.event=null
		ui.select_room("0:4");await frames();ui.fx.advance(3)
		ui.content_screen._pick_prediction(1);ui.content_screen._stake_prediction(200);await frames()
		ui.content_screen.content_box.find_child("stake_200",true,false).grab_focus();await shot(tag+"-prediction-selected")
		await fresh();ui.select_room("0:0");var w: WalletBar=ui.content_screen.wallet;w.set_process(false);await frames()
		ui.fx.advance(.35);w.advance_view(.35);await shot(tag+"-gold-gain-flight")
		ui.fx.advance(.4);w.advance_view(.4);await shot(tag+"-gold-arrival")
		ui.fx.advance(2);w.advance_view(2)
		var card: Control=ui.content_screen.content_box.get_child(0).get_child(0).get_child(0)
		root.set_meta("action_point",ArenaUI.control_center(card));var offer: RecruitOffer=ui.controller.current_room().recruit.offers[0]
		ui.content_screen._action(&"recruit",{"offer_id":offer.offer_id});await frames();ui.fx.advance(.35);w.advance_view(.35);await shot(tag+"-token-spend-flight")
		await fresh();ui.select_room("0:3");await frames();ui.fx.advance(3)
		var screen: TowerBattleScreen=ui.battle_screen
		for i in range(4):screen.plan.place(ui.controller.guild.all_members()[i].member_id,Vector2(100+i%2*140,200+i/2*220))
		screen.start_battle();var b: BattleManager=screen.battle;b.set_physics_process(false);await frames();screen.set_process(false)
		screen.battle_cue.bound_battle=null;screen.battle_cue.observe(b,0);screen.battle_cue.observe(b,.3);await shot(tag+"-battle-start")
		var visual: CombatPresentation=screen.board.presentation;visual.set_process(false)
		for i in range(b.units.size()):b.units[i].position=Vector2(300+i%3*80,320+i/3*85)
		for i in range(120):visual.advance(1.0/60)
		screen.battle_cue.cue="";await shot(tag+"-camera-closer")
		b.clock.elapsed=12;b.simulate(.4);screen.set_process(true);await frames();screen.set_process(false);visual.advance(.001);screen.battle_cue.observe(b,.5);await shot(tag+"-tp-slowdown")
		b.simulate(1.6);screen.set_process(true);await frames();screen.set_process(false);visual.advance(.001);screen.battle_cue.observe(b,.25);await shot(tag+"-tp-hold")
		b.turning.resolve()
		for enemy in b.units:
			if enemy.original_team==1:enemy.receive_damage(10000,b.units[0])
		b.check_outcome();screen.set_process(true);await frames();screen.set_process(false);ui.fx.advance(.3);screen.result_banner.age=.35
		await shot(tag+"-victory")
		await fresh();ui.select_room("0:3");await frames();ui.fx.advance(3);screen=ui.battle_screen
		screen.plan.place(ui.controller.guild.all_members()[0].member_id,Vector2(100,400));screen.start_battle();b=screen.battle;b.set_physics_process(false)
		for ally in b.units:
			if ally.original_team==0:ally.receive_damage(10000,b.units[-1])
		b.check_outcome();await frames();screen.result_banner.age=.35;await shot(tag+"-defeat")
	ui.free();quit()
