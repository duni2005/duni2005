extends "res://tests/layout_parity_runner.gd"
const SOURCE_OUT="res://migration/source-ui/"
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("SOURCE UI: "+label)
func shot(name: String):
	print("SOURCE UI SCREEN ",tag," ",name)
	if DisplayServer.get_name()=="headless":return
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(SOURCE_OUT+tag+"-"+name+".png")
func source_flow(res: Vector2i):
	await flow(res)
	var s: TowerBattleScreen=ui.battle_screen
	verify(s.undo_button is DeploymentToolButton and s.erase_button is DeploymentToolButton and s.tools_row.get_node("ClearAll") is DeploymentToolButton,"all four draft tools use one circular face")
	verify(s.tools_row.get_node("ClearAll").tool_kind=="clear_all" and s.erase_button.toggle_mode,"destructive tool separate from selected eraser")
	verify(s.pause_button.get_global_rect().end.x<s.speed_row.get_global_rect().position.x and s.speed_row.get_global_rect().end.x<=s.retreat_button.get_global_rect().position.x,"pause / speed / retreat preserve source order")
	verify(s.trans_scroll.custom_minimum_size.y<=58 and s.trans_row.get_child(0).custom_minimum_size.x==48,"source compact party proportion")
	var b: BattleManager=s.battle;var sim: float=b.clock.elapsed;var rng: int=b.rng.state
	await tap(s.pause_button);await frames()
	verify(s.watch_paused and not b.is_physics_processing(),"real touch pauses spectator simulation")
	verify(b.clock.elapsed==sim and b.rng.state==rng and b.clock.state==BattleClock.State.NORMAL,"pause consumes no clock/RNG or TP state")
	await shot("paused");await tap(s.pause_button)
	verify(not s.watch_paused and not b.is_physics_processing(),"resume restores the prior processing policy")
	b.set_physics_process(true);s._toggle_watch_pause();sim=b.clock.elapsed;rng=b.rng.state
	await frames();verify(b.clock.elapsed==sim and b.rng.state==rng,"enabled live battle also freezes exactly under spectator pause")
	s._toggle_watch_pause();verify(b.is_physics_processing(),"live processing resumes without catch-up time");b.set_physics_process(false)
	for u in b.units:
		if u.original_team==1:u.current_hp=0;u.alive=false
	b.check_outcome();s.board.presentation.advance(BattleCinematicState.DURATION);s._process(0);await frames()
	verify(s.result_kicker.text=="ROOM CLEAR" and s.result_rewards.visible,"existing settled victory has source hierarchy")
	var saved: String=pure();s._format_result(b.result);await shot("victory");verify(pure()==saved,"result rendering never pays reward again")
	await tap(s.next_button);verify(ui.battle_screen==null,"result action returns to existing map")
	ui.controller.guild.state.tower.last_content_outcome={"prediction":"incorrect","tokens":0};ui.show_map();await frames()
	verify(not ui.notice.visible,"map has no raw enum result footer")
	await shot("tower")
	ui.controller.floor_reward(12) # Source determines/stores a floor bonus once.
	saved=pure();ui.show_reward(12);await frames()
	verify(ui.reward_dialog.borderless and not ui.reward_dialog.get_ok_button().visible,"conquest uses game header, no system Alert/OK")
	verify(ui.reward_title.text=="13층 정복 보상" and ui.reward_panel.rewards.get_child_count()==2,"conquest shows progress plus two actual rewards")
	verify(ui.reward_dialog.size.x<=res.x-28 and fits(ui.reward_panel),"conquest modal fits mobile and desktop")
	verify(ui.reward_dialog.size.y<=440 and ui.reward_dialog.position.y>0,"conquest remains a compact centered modal")
	verify(not ui.reward_panel.status_label.text.is_empty() and not ui.reward_panel.unlock_label.text.is_empty(),"received and unlock rules are visible")
	verify(not "vigorTotem" in ui.reward_panel.rewards.get_child(1).get_child(0).get_child(1).text,"reward item is a localized catalog name")
	await shot("conquest");ui.reward_dialog.hide();verify(pure()==saved,"viewing reward changes no wallet/receipt/RNG")
	await battle_fixture();s=ui.battle_screen;b=s.battle
	for u in b.units:
		if u.original_team==0:u.receive_damage(10000,b.units[-1])
	b.check_outcome();s.board.presentation.advance(BattleCinematicState.DURATION);s._process(0);await frames();await shot("defeat")
func run():
	root.gui_embed_subwindows=true
	verify(ArenaUI.BACKGROUND==Color("0a0e18") and ArenaUI.PANEL==Color("131a2b") and ArenaUI.ACCENT==Color("ffb15c") and ArenaUI.HP==Color("86e3a4"),"palette equals the midnight/amber game palette")
	for res in [Vector2i(390,844),Vector2i(1280,800)]:await source_flow(res)
	if is_instance_valid(ui):ui.free()
	await frames();print("SOURCE UI RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
