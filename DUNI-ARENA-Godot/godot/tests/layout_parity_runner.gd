extends "res://tests/event_parity_runner.gd"
const PARITY_OUT="res://migration/layout-parity/"
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("LAYOUT PARITY: "+label)
func shot(name: String):
	print("LAYOUT SCREEN ",tag," ",name)
	if DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(PARITY_OUT+tag+"-"+name+".png")
func flow(res: Vector2i):
	root.size=res;root.content_scale_size=res;tag="mobile" if res.x==390 else "desktop"
	await fresh();ui.select_room("0:3");await frames();ui.fx.advance(3)
	var s: TowerBattleScreen=ui.battle_screen;var g: GuildManager=s.guild
	var frog: GuildMemberState=g.create_member(24);s._refresh_roster();await frames()
	s._open_management();await frames();var panel: GuildManagementPanel=s.management_panel
	verify(panel.prebattle_room==s.room and panel.tabs.size()==2,"prepare uses dedicated two-tab management page")
	verify(panel.active_tab=="inventory" and panel.page_action!=null,"page has deploy CTA and inventory first")
	verify(s.management_dialog.size.x<=root.content_scale_size.x and s.management_dialog.size.y<=root.content_scale_size.y,"management page fits viewport")
	verify(panel.roster.columns==g.all_members().size() and panel.roster_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,"inventory roster is horizontal, not a tiled grid")
	verify(fits(panel.page_action) and fits(panel.inventory_heading),"prepare action and selected heading visible")
	verify(panel.inventory_grid.columns==(4 if res.x<650 else 6),"inventory uses original responsive slot count")
	for card in panel.roster.get_children():verify(card.strip_style and card.equipment_slots>=2,"original strip keeps independent HP/energy/gear")
	await shot("inventory")
	await tap(panel.tabs.upgrade);panel._select(frog.member_id);await frames()
	verify(panel.upgrade_frame.visible and not panel.details.visible and panel.upgrade_summary.member_name=="개구리","upgrade has a visual summary instead of a raw paragraph")
	verify(fits(panel.upgrade_button) and fits(panel.upgrade_summary),"upgrade tiles/action fit viewport")
	var hp: float=frog.current_hp;var gold: int=g.state.gold
	await shot("upgrade");await tap(panel.upgrade_button);await frames()
	verify(frog.level==1 and g.state.gold==gold-80 and frog.current_hp>hp,"restyled upgrade invokes one existing growth transaction")
	var saved: String=pure();await tap(panel.menu_button);await frames()
	verify(panel.menu_dialog.visible and pure()==saved,"prepare menu opens without state/RNG change")
	await shot("menu");panel.menu_dialog.hide();await tap(panel.page_action);await frames()
	verify(not s.management_dialog.visible and s.board.editing,"deploy action returns to same draft")
	verify(s.tools_row.get_global_rect().end.y<=s.roster.get_parent().get_global_rect().position.y+1,"four tools sit between arena and member strip")
	verify(s.management_button.get_parent()==s.navigation_row,"unit/maintenance action is in the page heading")
	verify(s.start_button.size.x>=120 and fits(s.start_button),"prominent footer action matches original placement")
	await shot("deployment")
	for i in range(4):s.plan.place(g.all_members()[i].member_id,Vector2(100+i%2*140,180+i/2*220))
	await tap(s.start_button);s.battle.set_physics_process(false);await frames();s.board.presentation.set_process(false)
	verify(s.battle.started and s.status is BattleStatusLine,"battle uses original split status/time row")
	verify(s.trans_scroll.custom_minimum_size.y<80,"compact party no longer steals arena height")
	verify(s.battle_toolbar.visible and fits(s.retreat_button),"bottom battle actions remain visible")
	await tap(s.speed_buttons[2]);verify(s.battle.clock.speed==2,"speed control uses existing clock API")
	await tap(s.speed_buttons[1]);verify(s.battle.clock.speed==1,"speed can return to normal")
	saved=pure();await tap(s.records_button);await frames();verify(s.records_dialog.visible and pure()==saved,"participant/record popup is read-only")
	s.records_dialog.hide();await shot("battle")
	s.battle.clock.elapsed=12;s.battle.turning.advance(.001);s.battle.turning.advance(2);s._process(0);await frames()
	verify(s.turning_panel.visible and fits(s.turning_panel.resume_button),"TP input still fits revised HUD")
	await shot("tp");await tap(s.turning_panel.resume_button);verify(s.battle.clock.state==BattleClock.State.NORMAL,"TP resume still works")
func run():
	root.gui_embed_subwindows=true
	for res in [Vector2i(390,710),Vector2i(1280,800)]:await flow(res)
	ui.free();await frames();print("LAYOUT PARITY RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
