extends SceneTree
## Actual engine mouse/touch events, separate test slot. No production autosave.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1;print("SAVE UI ",checks,": ",label," = ",ok)
	if not ok:failures+=1;push_error("SAVE UI FAIL "+label)
func frames() -> void:
	for i in range(4):await process_frame
func find_button(node: Node,text: String) -> Button:
	if node is Button and text in node.text and not node.disabled:return node
	for child in node.get_children():
		var found: Button=find_button(child,text)
		if found!=null:return found
	return null
func click(control: Control,touch: bool) -> void:
	if control==null:verify(false,"missing input control");return
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames();var point: Vector2=control.get_global_rect().get_center();var viewport: Viewport=control.get_viewport()
	if viewport is Window and viewport!=root:point+=Vector2(viewport.position)
	point=root.get_final_transform()*point
	if touch:
		var event:=InputEventScreenTouch.new();event.position=point;event.pressed=true;Input.parse_input_event(event);await process_frame
		event=InputEventScreenTouch.new();event.position=point;Input.parse_input_event(event)
	else:
		var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;Input.parse_input_event(event);await process_frame
		event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(event)
	await frames()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/duni-phase11-"+name+".png")
func flow(touch: bool) -> void:
	root.size=Vector2i(390,844) if touch else Vector2i(1000,1100);root.content_scale_size=root.size
	var slot: String="user://phase11-ui/"+Crypto.new().generate_random_bytes(8).hex_encode()+"/autosave.json"
	var menu:=MainMenuScreen.new();menu.save_manager=SaveManager.new(slot);root.add_child(menu);await frames()
	verify(menu.continue_button.disabled,"no save disables Continue")
	await click(menu.new_button,touch);verify(menu.tower_screen!=null and menu.save_manager.read_document().ok(),"New creates actual autosave")
	var screen: TowerScreen=menu.tower_screen;var c: TowerController=screen.controller
	c.new_run(19,73);screen.show_map();await frames()
	await click(screen.room_buttons["0:0"],touch)
	var recruit: RoomState=c.current_room();var offer: RecruitOffer=recruit.recruit.offers[0]
	await click(screen.content_screen.content_box.get_child(1).get_child(0).get_child(0),touch)
	verify(offer.purchased and c.guild.all_members().size()==5,"recruit input/autosave")
	await finish_reveal(screen,touch)
	await click(screen.content_screen.map_button,touch);await click(screen.room_buttons["0:1"],touch)
	var stock: ShopOffer=c.current_room().shop.offers.filter(func(o):return o.category==&"equipment" and o.kind!=&"reengrave")[0]
	await click(find_button(screen.content_screen,ItemCatalog.get_item(stock.kind).display_name),touch)
	verify(stock.purchased and c.content.inventory.available().size()==1,"shop input/autosave")
	var item: ItemInstance=c.content.inventory.available()[0]
	await click(screen.content_screen.map_button,touch);await click(screen.guild_button,touch)
	await click(screen.guild_panel.tabs["inventory"],touch)
	await click(screen.guild_panel.inventory_grid.get_node("item_%d"%item.item_id),touch)
	await click(screen.guild_panel.item_dialog.get_ok_button(),touch);await click(screen.guild_panel.tabs["upgrade"],touch);await click(screen.guild_panel.upgrade_button,touch)
	var member: GuildMemberState=c.guild.all_members()[0]
	verify(item.equipped_to_member_id==member.member_id and member.level==1,"equipment and growth input")
	await click(screen.guild_panel.close_button,touch)
	# Detached enemy state is a declared fixture; actual retreat persistence is domain-tested.
	var room: RoomState=c.guild.state.tower.map.get_room("0:3");var enemies: Array=room.enemy_state.values();enemies[0].current_hp=0;enemies[1].current_hp=40;enemies[1].position=Vector2(470,330);room.battle_attempt_count=1
	c.guild.state.last_formation.capture([DeploymentEntry.new(member.member_id,Vector2(180,400))])
	await click(screen.menu_button,touch);await click(screen.manual_save_button,touch);verify(menu.save_manager.last_result.ok() and "저장됨" in screen.save_label.text,"manual save feedback")
	var previous_run_id: String=c.guild.state.run_id;var previous_gold: int=c.guild.state.gold
	screen.menu_dialog.hide();await click(screen.menu_button,touch);await click(screen.main_button,touch);await frames();screen=null;c=null;member=null;item=null;room=null;recruit=null
	verify(menu.tower_screen==null and not menu.continue_button.disabled,"run view disposed / Continue available")
	await capture("mobile-menu" if touch else "desktop-menu")
	await click(menu.continue_button,touch);screen=menu.tower_screen;c=screen.controller
	verify(c.guild.state.run_id==previous_run_id and c.guild.state.gold==previous_gold and c.guild.all_members().size()==5,"Continue exact run values")
	verify(c.content.inventory.equipped(c.guild.all_members()[0].member_id).size()==1 and c.guild.all_members()[0].level==1,"Continue equipment/growth")
	verify(c.guild.state.tower.map.get_room("0:0").recruit.offers[0].purchased and c.guild.state.tower.map.get_room("0:1").shop.offers.any(func(o):return o.offer_id==stock.offer_id and o.purchased),"Continue candidates and stock")
	await capture("mobile-map" if touch else "desktop-map")
	await click(screen.room_buttons["0:3"],touch);var battle_screen: TowerBattleScreen=screen.battle_screen
	verify(battle_screen!=null and battle_screen.plan.entries().size()==1,"loaded formation in deployment")
	# Freeze at the same input event boundary, after the actual UI handler created the battle.
	# Touch can deliver an emulated mouse signal before semantic touch release.
	# Observe actual launch, rather than consuming a one-shot on that early signal.
	battle_screen.battle_started.connect(func():battle_screen.battle.set_physics_process(false),CONNECT_ONE_SHOT)
	await click(battle_screen.start_button,touch);var b: BattleManager=battle_screen.battle;b.set_physics_process(false)
	var enemy: BattleUnit=b.units.filter(func(u):return u.source_enemy_id==enemies[1].enemy_id)[0]
	verify(b.units.filter(func(u):return not u.source_enemy_id.is_empty()).size()==3 and enemy.current_hp==40 and enemy.position==Vector2(470,330),"loaded damaged enemy and dead omission")
	verify(b.turning.next_at==12,"new TP schedule")
	# Emulate OS restart while battle is unfinished: dispose the whole view.
	menu.return_menu();screen=null;c=null;battle_screen=null;b=null;await frames();await click(menu.continue_button,touch)
	verify(menu.tower_screen.battle_screen!=null and menu.tower_screen.controller.guild.state.tower.phase==&"deploy","live crash checkpoint routes to deployment")
	verify(menu.tower_screen.battle_screen.plan.entries()[0].position==Vector2(180,400),"checkpoint exact starting formation")
	await capture("mobile-checkpoint" if touch else "desktop-checkpoint")
	menu.free();await frames()
func finish_reveal(screen: TowerScreen,touch: bool) -> void:
	for i in range(10):
		if screen.fx.active.is_empty():break
		var scene: Dictionary=screen.fx.active
		if scene.kind=="recruit":
			screen.fx.advance(maxf(.01,-float(scene.age)+.01));await click(screen.fx.surface,touch)
		else:screen.fx.advance(float(scene.duration)-float(scene.age)+.01);await frames()
func run() -> void:
	await flow(false);await flow(true)
	verify(checks>=30,"both input flows completed")
	print("SAVE UI RESULT: ",checks," checks; ",failures," failures; display=",DisplayServer.get_name());quit(1 if failures else 0)
