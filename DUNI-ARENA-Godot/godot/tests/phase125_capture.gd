extends SceneTree
## Reproducible visual reference fixtures, never production saves or source web edits.
var target: String="before"
var tag: String
var screen: TowerScreen
var rows: Array=[]
func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():target=OS.get_cmdline_user_args()[0]
	call_deferred("run")
func frames() -> void:
	for i in range(3):await process_frame
func shot(label: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	var file: String="res://migration/phase125/%s/%s-%s.png"%[target,tag,label]
	root.get_texture().get_image().save_png(file)
	var bounds: Dictionary={}
	if is_instance_valid(screen):
		for pair in [["map",screen.map_scroll],["wallet",screen.wallet],["battle",screen.battle_screen]]:
			if is_instance_valid(pair[1]) and pair[1] is Control:bounds[pair[0]]=str(pair[1].get_global_rect())
		if is_instance_valid(screen.battle_screen):
			for pair in [["arena",screen.battle_screen.board],["TP",screen.battle_screen.turning_panel],["resume",screen.battle_screen.turning_panel.resume_button]]:bounds[pair[0]]=str(pair[1].get_global_rect())
	var live_state: Dictionary={}
	if is_instance_valid(screen) and is_instance_valid(screen.battle_screen) and is_instance_valid(screen.battle_screen.battle):
		var live: BattleManager=screen.battle_screen.battle
		live_state={"clock":BattleClock.State.keys()[live.clock.state],"cast_actors":live.units.filter(func(actor):return not actor.ultimate.cast.is_empty()).map(func(actor):return actor.actor_id()),"transcendence_aim":live.transcendence!=null and not live.transcendence.aim.is_empty(),"transcendence_cast":live.transcendence!=null and not live.transcendence.cast.is_empty()}
		if label=="ultimate":assert(not live_state.cast_actors.is_empty(),"Actual Godot ultimate must be active")
		if label=="transcendence-aim":assert(live_state.transcendence_aim,"Actual Godot aim must be active")
		if label=="transcendence":assert(live_state.transcendence_cast,"Actual Godot cast must be active")
	rows.append({"name":label,"file":file,"size":{"x":root.size.x,"y":root.size.y},"bounds":bounds,"state":live_state});print("CAPTURE ",target," ",tag," ",label)
	var f:=FileAccess.open("res://migration/phase125/%s/manifest.json"%target,FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
func reset() -> void:
	if is_instance_valid(screen):screen.free();await frames()
	var c:=TowerController.new();c.new_run(19,73);c.guild.state.guild_members.clear();c.guild.state.next_member_number=1
	for type in range(8):c.guild.create_member(type)
	c.guild.state.gold=10000;c.guild.state.tokens=30
	c.content.inventory.give(&"fang","reference:fang")
	c.content.inventory.give(&"vital","reference:vital").equipped_to_member_id=c.guild.all_members()[0].member_id
	screen=load("res://scenes/tower.tscn").instantiate();screen.controller=c;screen.resume_saved=true;root.add_child(screen);await frames()
func select_room(id: String) -> void:
	screen.select_room(id);await frames()
func battle_fixture() -> TowerBattleScreen:
	await reset();await select_room("0:3")
	var room: TowerBattleScreen=screen.battle_screen
	for i in range(6):room.plan.place(room.guild.all_members()[i].member_id,Vector2(100+(i%2)*160,160+(i/2)*200))
	room._refresh_roster();await frames();return room
func run() -> void:
	for size in [Vector2i(1280,720),Vector2i(390,844)]:
		tag="desktop" if size.x>400 else "mobile";root.size=size;root.content_scale_size=size
		var menu:=MainMenuScreen.new();menu.save_manager=SaveManager.new("user://phase125-reference/menu.json");root.add_child(menu);await shot("menu");menu.free();await frames()
		await reset();await shot("tower");screen.open_guild();await shot("guild");await shot("upgrade");await shot("equipment");screen.guild_dialog.hide()
		for pair in [["0:0","recruit"],["0:1","shop"],["0:2","rest"],["0:4","event"]]:
			await reset();await select_room(pair[0]);await shot(pair[1])
		await reset();var trio: Array=[screen.controller.guild.create_member(0),screen.controller.guild.create_member(0),screen.controller.guild.create_member(0)]
		screen.open_guild();screen.guild_panel.show_tab("upgrade");screen.guild_panel.promotion_dialog.open(trio[0].member_id);await shot("promotion");screen.guild_panel.promotion_dialog.hide();screen.guild_dialog.hide()
		var room: TowerBattleScreen=await battle_fixture();await shot("character-select");await shot("deployment")
		room.start_battle();room.battle.set_physics_process(false);await shot("battle-zero")
		var b: BattleManager=room.battle
		for i in range(240):b.simulate(1.0/60)
		await shot("battle")
		b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2);await shot("tp")
		if not room.guild.state.strategy_cards.is_empty():b.turning.select_card(room.guild.state.strategy_cards[0].card_id)
		await shot("strategy-card")
		var u: BattleUnit=b.units[0];u.stun_remaining=0;u.invincible_remaining=0;u.ultimate.cast.clear();u.combat.cancel(u);u.transcendence_gauge=100
		b.transcendence.begin(u,Vector2(190,230));b.transcendence.update(Vector2(290,230));await shot("transcendence-aim")
		b.transcendence.release();b.simulate(.35);await shot("transcendence");b.simulate(1)
		b.turning.resolve();u.ultimate_gauge=100;u.combat.cancel(u);u.ultimate.cast.clear();u.stun_remaining=0;u.ultimate.request(u,b.units[-1]);await shot("ultimate")
		for kind in ["victory","defeat","retreat","gameover"]:
			room=await battle_fixture();room.start_battle();b=room.battle;b.set_physics_process(false);b.clock.elapsed=24
			if kind=="retreat":room.session.request_retreat()
			else:
				if kind=="gameover":room.guild.state.player_hp=0
				for unit in b.units:
					if unit.original_team==(1 if kind=="victory" else 0):unit.receive_damage(unit.current_hp+1,b.units[0])
				b.check_outcome()
			await shot(kind)
		if is_instance_valid(screen):screen.free();screen=null
		await frames()
	print("VISUAL REFERENCE CAPTURE ",target," ",rows.size()," screens")
	quit()
