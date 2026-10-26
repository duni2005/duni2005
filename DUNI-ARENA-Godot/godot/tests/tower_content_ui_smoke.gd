extends SceneTree
## Real mouse/touch events. Outcome/stock/eligible-unit fixtures are explicit.
var checks: int=0
var failures: int=0
var screen: TowerScreen
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1;print("CONTENT UI ",checks,": ",label," = ",ok)
	if not ok:failures+=1;push_error("CONTENT UI FAIL: "+label)
func frames() -> void:
	for i in range(4):await process_frame
func find_button(node: Node,fragment: String) -> Button:
	if node is Button and fragment in node.text:return node
	for child in node.get_children():
		var found: Button=find_button(child,fragment)
		if found!=null:return found
	return null
func click(control: Control,touch: bool=false) -> void:
	if control==null:verify(false,"missing clickable control");return
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames()
	var viewport: Viewport=control.get_viewport()
	var point: Vector2=control.get_global_rect().get_center()
	# Embedded sibling popup positions are relative to their root embedder,
	# including a dialog parented inside another dialog.
	if viewport is Window and viewport!=root:point+=Vector2(viewport.position)
	point=root.get_final_transform()*point
	if touch:
		var e:=InputEventScreenTouch.new();e.position=point;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventScreenTouch.new();e.position=point;Input.parse_input_event(e)
	else:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(e)
	await frames()
func board_click(board: DeploymentBoard,logical: Vector2,touch: bool) -> void:
	var p: Vector2=root.get_final_transform()*(board.global_position+board.board_rect().position+logical*board.board_rect().size.x/800)
	if touch:
		var e:=InputEventScreenTouch.new();e.position=p;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventScreenTouch.new();e.position=p;Input.parse_input_event(e)
	else:
		var e:=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(e)
	await frames()
func finish_reveal(screen: TowerScreen,touch: bool) -> void:
	for i in range(10):
		if screen.fx.active.is_empty():break
		var scene: Dictionary=screen.fx.active
		if scene.kind=="recruit":
			screen.fx.advance(maxf(.01,-float(scene.age)+.01));await click(screen.fx.surface,touch)
		else:screen.fx.advance(float(scene.duration)-float(scene.age)+.01);await frames()
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/duni-phase10-"+label+".png")
func flow(touch: bool) -> void:
	root.size=Vector2i(390,844) if touch else Vector2i(1000,1100);root.content_scale_size=root.size
	screen=load("res://scenes/tower.tscn").instantiate();root.add_child(screen);screen.controller.new_run(19,73);screen.show_map();await frames()
	var t: TowerController=screen.controller;var run_state: RunState=t.guild.state
	await click(screen.room_buttons["0:0"],touch)
	verify(screen.content_screen!=null and t.current_room().recruit.offers.size()==3,"recruit room UI")
	var offer: RecruitOffer=t.current_room().recruit.offers[0];var tokens: int=run_state.tokens
	await click(screen.content_screen.content_box.get_child(0).get_child(0).get_child(0),touch)
	verify(run_state.guild_members.size()==5 and offer.purchased and run_state.tokens==tokens-offer.token_price,"candidate purchase via input")
	await finish_reveal(screen,touch)
	var gold: int=run_state.gold;await click(screen.content_screen.content_box.find_child("Reroll",true,false),touch)
	verify(run_state.gold==gold-200 and t.current_room().recruit.revision==1,"reroll via input")
	await capture("mobile-recruit" if touch else "desktop-recruit")
	await click(screen.content_screen.map_button,touch)
	verify(t.guild.state.tower.phase==&"route" and screen.content_screen==null,"recruit completes and returns map")
	await click(screen.room_buttons["0:1"],touch)
	# Fixed stock only for UI selection; actual random stock tested in Phase10Tests.
	var shop: RoomState=t.current_room();var stock:=ShopOffer.new();stock.offer_id="ui_vital";stock.kind=&"vital";stock.category=&"equipment";stock.gold_price=90;shop.shop.offers=[stock];screen.content_screen.render();await frames()
	gold=run_state.gold;await click(screen.content_screen.content_box.find_child("ui_vital",true,false),touch)
	verify(stock.purchased and run_state.gold==gold-90 and t.content.inventory.available().size()==1,"shop input purchase")
	await capture("mobile-shop" if touch else "desktop-shop")
	await click(screen.content_screen.map_button,touch);await click(screen.guild_button,touch)
	verify(screen.guild_dialog.visible,"guild management opens")
	var member: GuildMemberState=t.guild.all_members()[0];var panel: GuildManagementPanel=screen.guild_panel
	await capture("mobile-guild-before" if touch else "desktop-guild-before")
	var item: ItemInstance=t.content.inventory.available()[0]
	await click(panel.tabs["inventory"],touch)
	await click(panel.inventory_grid.get_node("item_%d"%item.item_id),touch)
	verify(panel.item_dialog.visible and item.equipped_to_member_id.is_empty(),"item description precedes equip")
	await click(panel.item_dialog.get_ok_button(),touch)
	verify(item.equipped_to_member_id==member.member_id and t.guild.member_max_hp(member)==180,"explicit equip input")
	await click(panel.tabs["upgrade"],touch)
	gold=run_state.gold;await click(panel.upgrade_button,touch)
	verify(member.level==1 and run_state.gold==gold-80 and t.guild.member_max_hp(member)==202,"upgrade UI +actual derived maxHP")
	await capture("mobile-guild" if touch else "desktop-guild")
	await click(screen.guild_panel.close_button,touch)
	await click(screen.room_buttons["0:3"],touch)
	var room_screen: TowerBattleScreen=screen.battle_screen
	verify(room_screen!=null and room_screen.board.editing,"battle deployment route")
	await click(room_screen.roster.get_child(0),touch);await board_click(room_screen.board,Vector2(120,400),touch)
	verify(room_screen.plan.entries().size()==1,"input deployment")
	await click(room_screen.start_button,touch)
	var b: BattleManager=room_screen.battle;b.set_physics_process(false)
	verify(b.started and b.units[0].max_hp==202 and b.units[0].attack_power==member_stats_attack(t,member),"equipment/growth actual battle")
	for u in b.units:
		if u.original_team==1:u.receive_damage(10000,b.units[0])
	b.check_outcome();room_screen.board.presentation.advance(BattleCinematicState.DURATION);await frames();await click(room_screen.next_button,touch)
	verify(t.guild.state.tower.phase==&"route" and t.guild.state.tower.map.get_room("0:3").cleared,"battle clear returns map")
	verify(screen.map_scroll.stairs.visible,"real noncombat+combat completion opens the stairs")
	await click(screen.room_buttons["0:2"],touch);gold=run_state.gold
	await click(screen.content_screen.content_box.find_child("resources",true,false),touch)
	verify(run_state.gold==gold+350 and t.guild.state.tower.map.get_room("0:2").consumed,"rest choice+consume via input")
	var event_room: RoomState=run_state.tower.map.get_room("0:4");event_room.event_type=&"hotSpring"
	await click(screen.room_buttons["0:4"],touch)
	verify(screen.content_screen.map_button.disabled,"unfinished event blocks map")
	await click(screen.content_screen.content_box.find_child("bathe",true,false),touch)
	verify(event_room.cleared and event_room.consumed and not screen.content_screen.map_button.disabled,"event result unlocks map")
	await capture("mobile-event" if touch else "desktop-event")
	await click(screen.content_screen.map_button,touch)
	# Promotion from the guild screen's upgrade tab: three individual living warrior members.
	var ids: Array[String]=[]
	for i in range(3):
		var m: GuildMemberState=t.guild.create_member(0);ids.append(m.member_id)
	await click(screen.map_scroll.stairs,touch)
	verify(t.current_floor()==1 and screen.room_buttons["0:2"].disabled and not screen.room_buttons["1:0"].disabled,"stairs climb; the floor below stays behind")
	screen.open_guild();await frames();screen.guild_panel.selected_member_id=ids[0];screen.guild_panel.show_tab("upgrade");await frames()
	await click(screen.guild_panel.promote_button,touch)
	for id in ids.slice(1):await click(screen.guild_panel.promotion_dialog.grid.get_node(NodePath(id)),touch)
	await click(screen.guild_panel.promotion_dialog.confirm,touch)
	verify(t.guild.get_member(ids[0]).stars==1 and t.guild.get_member(ids[1])==null and t.guild.get_member(ids[2])==null,"promotion via selection/input")
	await finish_reveal(screen,touch)
	var prediction_room: RoomState=run_state.tower.map.get_room("1:1");prediction_room.room_type=RoomType.EVENT;prediction_room.event_type=&"prediction";prediction_room.event=null
	screen.show_map();await frames();await click(screen.room_buttons["1:1"],touch)
	await click(screen.content_screen.content_box.get_node("team_0"),touch);await click(screen.content_screen.content_box.find_child("stake_50",true,false),touch)
	verify(prediction_room.event.prediction.picked_team==0 and prediction_room.event.prediction.stake==50,"prediction team/stake UI")
	await click(screen.content_screen.content_box.get_node("Watch"),touch)
	b=screen.content_screen.battle;b.set_physics_process(false)
	verify(b.started and screen.content_screen.map_button.disabled and b.turning==null,"isolated watch battle navigation lock")
	for u in b.units:
		if u.original_team!=0:u.receive_damage(10000,b.units[0])
	b.check_outcome();await frames();screen.content_screen.board.presentation.advance(BattleCinematicState.DURATION);await frames()
	verify(prediction_room.event.prediction.result==&"correct" and prediction_room.consumed and not screen.content_screen.map_button.disabled,"prediction reward/result UI")
	await click(screen.content_screen.map_button,touch)
	verify(screen.content_screen==null and run_state.tower.phase==&"route","prediction returns map")
	screen.free();await frames()
func member_stats_attack(t: TowerController,m: GuildMemberState) -> float:return t.guild.member_stats(m).attack
func run() -> void:
	root.gui_embed_subwindows=true
	await flow(false);await flow(true)
	print("CONTENT UI RESULT: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
