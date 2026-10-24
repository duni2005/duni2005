extends "res://tests/event_parity_runner.gd"
const BLUE_OUT="res://migration/blue-touch/"
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("BLUE TOUCH: "+label)
func shot(name: String):
	print("BLUE SCREEN ",tag," ",name)
	if DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(BLUE_OUT+tag+"-"+name+".png")
func pointer(at: Vector2,pressed: bool,index: int=0,canceled: bool=false):
	var event:=InputEventScreenTouch.new();event.position=at;event.pressed=pressed;event.index=index;event.canceled=canceled;Input.parse_input_event(event)
func jitter_tap(control: Control,offset: Vector2=Vector2(7,5)):
	var at: Vector2=root.get_final_transform()*ArenaUI.control_center(control)
	pointer(at,true);await process_frame
	var drag:=InputEventScreenDrag.new();drag.position=at+offset;drag.relative=offset;Input.parse_input_event(drag);await process_frame
	pointer(at+offset,false);await frames()
func input_contract():
	var holder:=Control.new();root.add_child(holder);holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var b:=Button.new();holder.add_child(b);b.position=Vector2(60,70);b.size=Vector2(150,60);b.toggle_mode=true;b.text="터치 검사";var count: Array=[0];ArenaUI.bind(b,func():count[0]+=1)
	await frames();await jitter_tap(b)
	verify(count[0]==1 and b.button_pressed,"one small-jitter gesture activates once and keeps selection")
	b.pressed.emit();verify(count[0]==1 and b.button_pressed,"synthetic mouse release cannot repeat touch")
	var center: Vector2=ArenaUI.control_center(b);pointer(center,true);pointer(center,false);pointer(center,true);pointer(center,false);await frames()
	verify(count[0]==3 and b.button_pressed,"separate taps in one low-FPS frame are both accepted")
	pointer(center,true);pointer(center,false,0,true);await frames();verify(count[0]==3,"canceled touch is rejected")
	pointer(center,true);pointer(center,false,1);await frames();verify(count[0]==3,"another finger cannot release owned gesture")
	pointer(center,false);await frames();verify(count[0]==4,"original finger still releases correctly")
	await jitter_tap(b,Vector2(30,0));verify(count[0]==4,"real drag never acts as a tap")
	var e:=InputEventMouseButton.new();e.position=center;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame;e=InputEventMouseButton.new();e.position=center;e.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(e);await frames()
	verify(count[0]==5,"real desktop mouse remains independent of recent touch")
	pointer(center,true);await create_timer(.65).timeout;pointer(center,false);await frames();verify(count[0]==6,"long or low-FPS touch never falls through a duplicate-mouse timeout")
	b.disabled=true;await jitter_tap(b);verify(count[0]==6,"disabled red action cannot execute")
	var scroll:=ScrollContainer.new();holder.add_child(scroll);scroll.position=Vector2(30,180);scroll.size=Vector2(240,120)
	var list:=VBoxContainer.new();list.custom_minimum_size.y=500;scroll.add_child(list);var scroll_calls: Array=[0]
	var child:=Button.new();child.text="스크롤 안의 버튼";child.custom_minimum_size=Vector2(210,60);list.add_child(child);ArenaUI.bind(child,func():scroll_calls[0]+=1)
	await frames();await jitter_tap(child,Vector2(0,-7));verify(scroll_calls[0]==1 and scroll.scroll_vertical==0,"small finger jitter in a scroll list still taps without scrolling")
	await frames();var at: Vector2=ArenaUI.control_center(child);pointer(at,true);await process_frame;scroll.scroll_vertical=6;pointer(at,false);await frames()
	verify(scroll_calls[0]==1,"parent scrolling cancels release even below finger-jitter threshold")
	holder.free();await frames()
func display_contract():
	await fresh();var g: GuildManager=ui.controller.guild;var member: GuildMemberState=g.all_members()[0]
	member.current_hp=83;member.energy=3
	var item: ItemInstance=ui.controller.content.inventory.give(&"fang");item.equipped_to_member_id=member.member_id
	ui.guild_panel.selected_member_id=member.member_id;ui.guild_panel.show_tab("guild");ui.open_guild();await frames()
	var card: ArenaCard=ui.guild_panel.roster.get_node(member.member_id)
	verify(card.hp==83 and card.equipment_kinds==["fang"],"guild card copies individual HP/equipment")
	verify(fits(card) and fits(ui.guild_panel.close_button),"guild card/close fit")
	await shot("guild");await tap(ui.guild_panel.tabs.inventory);await frames();card=ui.guild_panel.roster.get_node(member.member_id)
	verify(card.card_type=="mini_member" and card.hp==83 and card.equipment_kinds==["fang"],"inventory selector preserves all member information")
	verify(card.custom_minimum_size.y>=88 and fits(card),"inventory summary has space for gear row")
	await shot("inventory");ui.guild_dialog.hide();ui.select_room("0:3");await frames();ui.fx.advance(3)
	var screen: TowerBattleScreen=ui.battle_screen
	var tools: Array=screen.tools_row.get_children().filter(func(c):return c is Button)
	verify(tools.size()==4,"four separate deployment tools")
	for tool in tools:verify(tool.size.x>=44 and tool.size.y>=44 and fits(tool),"small tool remains a touch target")
	verify(screen.management_button is ArenaCard and screen.management_button.card_type=="nav","management matches map unit nav")
	verify(screen.roster.get_child(0).custom_minimum_size.x<116 and screen.roster.get_child(0).custom_minimum_size.y<146,"deployment cards are smaller")
	verify(fits(screen.start_button) and screen.start_button.size.x>=120,"start CTA visible and prominent")
	var first: ArenaCard=screen.roster.get_child(0);var object_id: int=first.get_instance_id();await jitter_tap(first)
	verify(screen.board.selected_id==member.member_id,"first touch selects a deployment member")
	verify(screen.roster.get_child(0).get_instance_id()==object_id,"selection updates card in place instead of replacing touch target")
	var rect: Rect2=screen.board.board_rect();var point: Vector2=screen.board.global_position+rect.position+Vector2(145,300)*rect.size.x/800
	pointer(point,true);pointer(point,false);await frames();verify(screen.plan.get_entry(member.member_id)!=null,"real touch places member")
	verify(screen.undo_history.size()==1,"one placement is one undo record")
	await tap(screen.undo_button);verify(screen.plan.get_entry(member.member_id)==null,"undo actual button")
	await tap(screen.redo_button);verify(screen.plan.get_entry(member.member_id)!=null,"redo actual button")
	await tap(screen.erase_button);verify(screen.board.erase_mode,"eraser touch stays selected")
	pointer(point,true);pointer(point,false);await frames();verify(screen.plan.get_entry(member.member_id)==null,"eraser removes clicked member")
	await tap(screen.undo_button);verify(screen.plan.get_entry(member.member_id)!=null,"erase can be undone")
	await tap(screen.tools_row.get_node("ClearAll"));verify(screen.plan.entries().is_empty(),"all clear actual button")
	await tap(screen.undo_button);verify(screen.plan.entries().size()==1,"all clear can be undone")
	await shot("deployment")
	await tap(screen.management_button);await frames();verify(screen.management_dialog.visible and screen.management_panel.active_tab=="inventory","unit icon opens original prebattle inventory page")
	screen.management_dialog.hide()
	# The new color/touch presentation must not alter live state when inspected.
	var saved: String=pure();screen._refresh_roster();await frames();verify(pure()==saved,"card refresh is read-only")
	await tap(screen.start_button);await frames();verify(is_instance_valid(screen.battle) and screen.battle.started,"start CTA responds on first tap")
	screen.battle.set_physics_process(false);screen.board.presentation.set_process(false);screen.set_process(false)
	var b: BattleManager=screen.battle;screen.battle_cue.observe(b,0);b.clock.elapsed=12;b.turning.advance(.001);screen.battle_cue.observe(b,0)
	screen.board.presentation.camera.zoom=1.8;screen.board.presentation.advance(.4);screen.battle_cue.observe(b,.4);screen._process(0)
	verify(CinematicArtwork.title_alpha("turning",.4)>.8 and screen.board.presentation.camera.zoom>1,"TP text/effect appears during camera pullback")
	await shot("tp-zoom")
	b.turning.advance(2);screen._process(0);await frames()
	var ally_card: ArenaCard=screen.turning_panel.allies.get_node(member.member_id);var ally_identity: int=ally_card.get_instance_id()
	var mango: StrategyCardInstance=g.state.give_strategy_card(&"mango");b.turning.current.selected_member_id=member.member_id;screen._process(0);await frames()
	await tap(screen.turning_panel.card_buttons[mango.card_id]);screen._process(0);await frames();await tap(screen.turning_panel.use_button);screen._process(0)
	verify(b.turning.current.last_card_result.code==StrategyCardExecutor.Code.OK,"real mango UI action works on first touch")
	verify(ally_card.hp>83 and ally_card.hp==b.units[0].current_hp,"TP member HP display updates immediately after heal")
	verify(ally_card.get_instance_id()==ally_identity,"stance/card updates keep the held ally card alive")
	await tap(screen.turning_panel.resume_button)
	screen.battle_cue.observe(b,.01);verify(b.clock.state==BattleClock.State.NORMAL and screen.battle_cue.cue=="","resume produces no text overlay")
	verify(screen.retreat_button.get_theme_color("font_color")==ArenaUI.DANGER,"retreat uses red semantic style")
	await shot("battle")
func run():
	root.gui_embed_subwindows=true
	verify(ArenaUI.PANEL==Color("131a2b") and ArenaUI.ACCENT==Color("ffb15c"),"midnight panel and amber accent surfaces")
	verify(ArenaUI.get_theme().get_color("font_disabled_color","Button")==ArenaUI.DANGER,"unavailable buttons are red")
	for res in [Vector2i(390,844),Vector2i(1000,1100)]:
		root.size=res;root.content_scale_size=res;tag="mobile" if res.x<500 else "desktop"
		await input_contract();await display_contract()
	if is_instance_valid(ui):ui.free()
	await frames();print("BLUE TOUCH RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
