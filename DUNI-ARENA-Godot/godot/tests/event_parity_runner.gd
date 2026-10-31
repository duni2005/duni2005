extends SceneTree
## Domain transactions + real touch input; optional X11 captures from the same fixtures.
const OUT="res://migration/event-parity/"
var checks: int=0
var failures: int=0
var ui: TowerScreen
var tag: String
func _initialize():call_deferred("run")
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("EVENT PARITY: "+label)
func frames():
	for i in range(5):await process_frame
func shot(name: String):
	print("EVENT PARITY SCREEN ",tag," ",name)
	if DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+tag+"-godot-"+name+".png")
func fits(c: Control) -> bool:
	var r: Rect2=c.get_global_rect();return r.position.x>=-1 and r.position.y>=-1 and r.end.x<=root.content_scale_size.x+1 and r.end.y<=root.content_scale_size.y+1
func tap(c: Control):
	verify(c!=null,"touch target exists")
	if c==null:return
	var parent: Node=c.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(c)
		parent=parent.get_parent()
	await frames()
	var point: Vector2=root.get_final_transform()*ArenaUI.control_center(c)
	var e:=InputEventScreenTouch.new();e.position=point;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventScreenTouch.new();e.position=point;Input.parse_input_event(e);await frames()
func fresh():
	if is_instance_valid(ui):ui.free();await frames()
	ui=TowerScreen.new();root.add_child(ui);ui.controller.new_run(19,73);ui.show_map();await frames();ui.fx.set_process(false)
func select_event(kind: StringName):
	await fresh();var room: RoomState=ui.controller.guild.state.tower.map.get_room("0:4");room.event_type=kind;room.event=null
	ui.select_room("0:4");await frames();ui.fx.advance(3)
func battle_fixture():
	await fresh();ui.select_room("0:3");await frames();ui.fx.advance(3)
	var s: TowerBattleScreen=ui.battle_screen
	for i in range(ui.controller.guild.all_members().size()):s.plan.place(ui.controller.guild.all_members()[i].member_id,Vector2(100+i%2*140,200+i/2*220))
	s.start_battle();s.battle.set_physics_process(false);await frames();s.board.presentation.set_process(false)
func pure() -> String:return JSON.stringify(SaveDomainCodec.new().encode(ui.controller.guild.state,"run"))
func flow(res: Vector2i):
	root.size=res;root.content_scale_size=res;tag="mobile" if res.x<500 else "desktop"
	await fresh();ui.controller.guild.all_members()[0].current_hp=0;ui.controller.guild.all_members()[1].current_hp=0
	ui.select_room("0:2");await frames();ui.fx.advance(3)
	var c: TowerContentScreen=ui.content_screen
	verify(c.event_grid.columns==2 and c.event_grid.get_child_count()==4,"rest four choices / two columns")
	verify(c.party_strip.visible and c.party_members.get_child_count()==4,"persistent individual guild strip")
	verify(c.event_grid.get_child(0).global_position.y==c.event_grid.get_child(1).global_position.y,"choice pair same row")
	verify(fits(c.event_grid) and c.event_grid.size.x<=580,"compact options fit viewport")
	await shot("rest");var saved: String=pure();await tap(c.event_grid.get_node("Revival"))
	verify(c.revive_dialog.visible and c.revival_units.get_child_count()==2,"revival opens modal / dead members only")
	verify(c.revive_confirm.disabled and pure()==saved,"opening revival never consumes the room")
	await tap(c.revival_units.get_child(0));verify(c.revive_selection.size()==1 and not c.revive_confirm.disabled,"explicit individual selection")
	await shot("revive");await tap(c.revive_confirm)
	verify(ui.controller.guild.all_members()[0].current_hp>0 and ui.controller.guild.all_members()[1].current_hp==0,"revive only chosen member")
	verify(ui.controller.guild.state.tower.phase==&"route","rest completes back to map")
	await select_event(&"hotSpring");c=ui.content_screen
	verify(not c.map_button.visible and c.event_grid.get_child_count()==2,"hot spring hides escape / two choices")
	verify(fits(c.event_grid),"hot spring choices fit");await shot("hotSpring")
	await tap(c.event_grid.get_node("bathe"));verify(c.map_button.visible and not c.map_button.disabled,"hot spring result unlocks map")
	verify(c.event_grid==null and c.content_box.get_child_count()==1,"hot spring dedicated reward card replaces choices")
	saved=pure();c.render();await frames();verify(pure()==saved,"result re-render never rewards twice");await shot("hotSpring-result")
	await select_event(&"supply");c=ui.content_screen;verify(c.event_grid.get_child_count()==4 and not c.map_button.visible,"treasure four original options")
	await shot("supply");var gold: int=ui.controller.guild.state.gold;await tap(c.event_grid.get_node("gold"))
	verify(ui.controller.guild.state.gold==gold+300 and ui.controller.guild.state.tower.phase==&"route","treasure choice pays once / returns map")
	# Promotion lives in the guild screen's upgrade tab, not in an event room.
	await fresh();var members: Array=[]
	for i in range(3):var member: GuildMemberState=ui.controller.guild.create_member(0);member.current_hp=ui.controller.guild.member_max_hp(member);members.append(member)
	ui.open_guild();await frames();var panel: GuildManagementPanel=ui.guild_panel;panel.selected_member_id=members[0].member_id;panel.show_tab("upgrade");panel.show_upgrade_view("guild");await frames()
	verify(not panel.promote_button.disabled,"three matching units enable promotion");await tap(panel.promote_button)
	var dialog: PromotionDialog=panel.promotion_dialog;verify(dialog.visible and dialog.lead_id==members[0].member_id,"promotion window opens with the selected unit as lead")
	for m in members.slice(1):await tap(dialog.grid.get_node(NodePath(m.member_id)))
	verify(not dialog.confirm.disabled,"lead + two materials unlock promotion")
	await shot("promotion");await tap(dialog.confirm);verify(ui.controller.guild.get_member(members[0].member_id).stars==1 and ui.controller.guild.get_member(members[1].member_id)==null,"promotion keeps the lead")
	ui.fx.advance(4)
	await select_event(&"prediction");c=ui.content_screen
	verify(not c.map_button.visible,"prediction cannot escape before result");await shot("prediction")
	await battle_fixture();var s: TowerBattleScreen=ui.battle_screen;var b: BattleManager=s.battle
	b.clock.elapsed=12;b.turning.advance(.001);s.set_process(false);s.board.presentation.set_process(false)
	var cam: ArenaCameraController=s.board.presentation.camera;cam.zoom=2;cam.center=Vector2(340,420);cam.pan=Vector2(120,-40)
	var elapsed: float=b.clock.elapsed;s.board.presentation.advance(.5)
	verify(cam.zoom>1 and cam.zoom<2,"TP slowdown smoothly pulls camera back")
	verify(b.clock.elapsed==elapsed,"camera never advances simulation")
	s.battle_cue.observe(b,.4);await shot("tp-slowdown")
	s.board.presentation.advance(1.5);verify(is_equal_approx(cam.zoom,1) and cam.pan.length()<.001,"whole arena revealed by two seconds")
	b.turning.advance(2);s._process(0);s.set_process(false);s.board.presentation.advance(.1)
	verify(cam.transform().is_equal_approx(Transform2D.IDENTITY),"hold displays all arena corners")
	await shot("tp-hold");b.turning.resolve()
	for u in b.units:
		if u.original_team==1:u.current_hp=0;u.alive=false
	b.check_outcome();s.board.presentation.advance(BattleCinematicState.DURATION);s.set_process(true);await frames()
	verify(s.result_overlay.visible and s.result_wallet.visible and s.result_kicker.text=="ROOM CLEAR","victory has full tower result page / wallet")
	verify(not s.result_banner.visible and not s.result_label.visible,"no giant crest or debug-style result text")
	verify(fits(s.result_panel) and fits(s.next_button),"result frame and CTA fit")
	saved=pure();s._format_result(b.result);verify(pure()==saved,"result formatting never settles again")
	await shot("victory");await tap(s.next_button);verify(ui.battle_screen==null,"victory map action")
	await battle_fixture();s=ui.battle_screen;b=s.battle
	for u in b.units:
		if u.original_team==0:u.receive_damage(10000,b.units[-1])
	b.check_outcome();s.board.presentation.advance(BattleCinematicState.DURATION);await frames();verify(s.result_kicker.text=="TRY AGAIN" or s.result_kicker.text=="EXPLORATION ENDED","defeat uses original result hierarchy")
	await shot("defeat")
	await battle_fixture();s=ui.battle_screen;b=s.battle;s.set_process(false);b.clock.elapsed=20
	verify(s.session.request_retreat(),"retreat settles through existing controller")
	verify(s.retreat_presenting and s.retreat_scene.visible,"accepted retreat starts visual fade")
	saved=pure();s.board.presentation.advance(.8);s._process(0);s.set_process(false);verify(not s.result_overlay.visible and s.next_button.disabled,"no result popup during retreat")
	verify(pure()==saved and b.finished,"fade never changes settled actors/resources/RNG")
	await shot("retreat-fade");s.board.presentation.advance(BattleCinematicState.DURATION-.81);s._process(0);s.set_process(false);await frames();verify(is_instance_valid(ui.battle_screen),"no early map before storyboard duration")
	s.board.presentation.advance(.02);s._process(0);await frames();verify(ui.battle_screen==null and ui.controller.guild.state.tower.phase==&"route","retreat auto returns map at storyboard end")
func run():
	root.gui_embed_subwindows=true
	await flow(Vector2i(390,844));await flow(Vector2i(1280,720))
	ui.free();await frames();print("EVENT PARITY RESULT: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
