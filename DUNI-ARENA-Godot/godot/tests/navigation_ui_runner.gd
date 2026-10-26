extends "res://tests/event_parity_runner.gd"
const NAV_OUT="res://migration/navigation-ui/"
func shot(name: String):
	if DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(NAV_OUT+tag+"-"+name+".png")
func same_rect(a: Control,b: Rect2) -> bool:
	return a.get_global_rect().position.distance_to(b.position)<1 and a.size.distance_to(b.size)<1
func no_inventory_action(node: Node) -> bool:
	if node is Button and "인벤토리" in node.text:return false
	for child in node.get_children():
		if not no_inventory_action(child):return false
	return true
func flow(res: Vector2i):
	root.size=res;root.content_scale_size=res;tag="mobile" if res.x<500 else "desktop"
	await fresh()
	var unit_rect: Rect2=ui.guild_button.get_global_rect();var menu_rect: Rect2=ui.menu_button.get_global_rect()
	ui.select_room("0:3");await frames();ui.fx.advance(3)
	var s: TowerBattleScreen=ui.battle_screen
	verify(same_rect(s.management_button,unit_rect) and same_rect(s.menu_button,menu_rect),"deployment unit/menu match map coordinates and dimensions")
	verify(s.navigation_title.get_global_rect().end.x<=s.management_button.global_position.x,"room name is left of right-aligned navigation")
	verify(s.navigation_title.text=="1층 · 4번 방 · 전투","deployment room title")
	await shot("deployment")
	var member: GuildMemberState=s.guild.all_members()[0];s.plan.place(member.member_id,Vector2(150,300))
	var before: String=pure();await tap(s.menu_button)
	verify(s.menu_dialog.visible and no_inventory_action(s.menu_dialog),"deployment menu opens with no inventory duplicate")
	s.menu_dialog.hide();await tap(s.management_button);await frames()
	var panel: GuildManagementPanel=s.management_panel
	verify(panel.close_button.kind=="close" and panel.menu_button.kind=="menu","management replaces unit icon with X and retains menu")
	verify(same_rect(panel.close_button,unit_rect) and same_rect(panel.menu_button,menu_rect),"management X/menu remain in same map slots")
	verify(panel.page_title.text==s.navigation_title.text,"management retains room title")
	await shot("management")
	await tap(panel.menu_button);verify(panel.menu_dialog.visible and no_inventory_action(panel.menu_dialog),"management menu is separate from close")
	panel.menu_dialog.hide();await tap(panel.close_button)
	verify(not s.management_dialog.visible and s.board.editing,"X returns directly to deployment")
	verify(s.plan.get_entry(member.member_id).position==Vector2(150,300) and pure()==before,"opening/closing navigation preserves domain/RNG/draft")
	# Real room screens share the same header; the fixed footer is outside scroll.
	for kind in ["recruit","shop","rest","hotSpring","supply","prediction"]:
		await fresh()
		var id: String={"recruit":"0:0","shop":"0:1","rest":"0:2"}.get(kind,"0:4")
		var node: RoomState=ui.controller.guild.state.tower.map.get_room(id)
		if id=="0:4":node.event_type=StringName(kind);node.event=null
		ui.select_room(id);await frames();ui.fx.advance(3)
		var c: TowerContentScreen=ui.content_screen
		verify(same_rect(c.guild_button,unit_rect) and same_rect(c.menu_button,menu_rect),kind+" header matches map slots")
		var state: String=pure();await tap(c.guild_button);await frames()
		verify(c.guild_dialog.visible and c.guild_panel.close_button.kind=="close",kind+" unit button opens roster")
		verify(same_rect(c.guild_panel.close_button,unit_rect),kind+" roster X occupies unit slot")
		await tap(c.guild_panel.close_button);verify(not c.guild_dialog.visible and pure()==state,kind+" close is presentation only")
		await tap(c.menu_button);verify(c.content_menu.visible and no_inventory_action(c.content_menu),kind+" menu contains no unit/inventory action");c.content_menu.hide()
		if kind in ["hotSpring","supply","prediction"]:
			verify(not c.map_footer.visible and not c.map_button.visible,kind+" unfinished event retains navigation lock")
			if kind=="hotSpring":c._action(&"event",{"choice":&"bathe"});await frames()
			elif kind=="supply":
				await shot(kind);c._action(&"event",{"choice":node.event.choices[0]});await frames()
				verify(ui.content_screen==null and node.cleared,"supply keeps original automatic return after resolution");continue
			else:continue # Real prediction battle/result is covered by event smoke.
		verify(c.map_button.visible and c.map_footer.visible,kind+" map return footer shown")
		verify(c.map_button.get_parent()==c.map_footer and c.map_footer.get_parent()==c.column,kind+" footer outside content scroll")
		verify(absf(c.map_button.get_global_rect().get_center().x-res.x*.5)<1,kind+" map return horizontally centered")
		verify(c.map_button.size.x>=minf(520,res.x-32)-1 and c.map_button.size.y>=48,kind+" wide touch return button")
		verify(c.map_button.global_position.y>=c.room_frame.get_global_rect().end.y and fits(c.map_button),kind+" footer at viewport bottom without clipping")
		await shot(kind)
		await tap(c.map_button);verify(ui.content_screen==null and ui.controller.guild.state.tower.phase==&"route",kind+" real return action works")
func run():
	await flow(Vector2i(390,844));await flow(Vector2i(1000,1100))
	if is_instance_valid(ui):ui.free()
	await frames();print("NAVIGATION UI RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
