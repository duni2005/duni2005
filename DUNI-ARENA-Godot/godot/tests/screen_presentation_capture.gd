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
		await reset();await shot(tag+"-map")
		ui.select_room("0:0");await frames();ui.fx.advance(.55);await shot(tag+"-entry")
		ui.fx.advance(2);var offer: RecruitOffer=ui.controller.current_room().recruit.offers[0]
		ui.content_screen._action(&"recruit",{"offer_id":offer.offer_id});await frames();ui.fx.advance(.85);await shot(tag+"-recruit-reveal")
		ui.fx.skip_recruit();ui.fx.advance(0);await shot(tag+"-recruit")
		ui.content_screen._return_map();await frames();ui.select_room("0:1");await frames();ui.fx.advance(2.2);await shot(tag+"-shop")
		await reset();var group: Array=[ui.controller.guild.create_member(0),ui.controller.guild.create_member(0),ui.controller.guild.create_member(0)]
		ui.open_guild();var promotion: PromotionDialog=ui.guild_panel.promotion_dialog;promotion.open(group[0].member_id)
		for m in group.slice(1):promotion._pick(m.member_id)
		await frames();promotion._promote();await frames();ui.fx.advance(1.0);await shot(tag+"-promotion")
		await reset();ui.controller.guild.state.player_hp=70
		for id in ui.controller.guild.state.tower.map.floors[0].room_ids:ui.controller.guild.state.tower.map.get_room(id).cleared=true
		ui.controller.refresh_progress(0);ui.show_map();await frames();ui.fx.advance(.7);await shot(tag+"-conquest")
		await reset();ui.select_room("0:3");await frames();ui.fx.advance(2.2)
		var room_ui: TowerBattleScreen=ui.battle_screen
		for i in range(4):room_ui.plan.place(ui.controller.guild.all_members()[i].member_id,Vector2(100+i%2*140,200+i/2*220))
		await shot(tag+"-deploy");room_ui.start_battle();await frames();var b: BattleManager=room_ui.battle;b.set_physics_process(false)
		var visual: CombatPresentation=room_ui.board.presentation;visual.set_process(false)
		await shot(tag+"-battle-wide")
		for i in range(b.units.size()):b.units[i].position=Vector2(350+i%3*60,320+i/3*80)
		for i in range(120):visual.advance(1.0/60)
		await shot(tag+"-camera-framed")
		# Drive the real TP scheduler; keep actor positions as an explicit visual fixture.
		b.clock.elapsed=12;b.simulate(.5);b.simulate(1.5);visual.advance(.001);await frames();await shot(tag+"-tp")
		b.turning.resolve();await frames()
		# Explicit victory/death-event fixture; actual battle/RNG is covered by paired tests.
		var last: BattleUnit
		for enemy in b.units:
			if enemy.original_team==1:enemy.current_hp=0;enemy.alive=false;last=enemy
		b.unit_died.emit(last,b.units[0]);b.check_outcome();await frames();await shot(tag+"-victory")
	ui.free();quit()
