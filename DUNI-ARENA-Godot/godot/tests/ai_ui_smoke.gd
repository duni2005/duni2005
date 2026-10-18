extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1;print("AI UI ",checks,": ",label," = ",ok)
	if not ok:failures+=1;push_error("AI UI FAIL "+label)
func frames() -> void:
	for i in range(3):await process_frame
func click(point: Vector2,touch: bool) -> void:
	point=root.get_final_transform()*point
	if touch:
		var e:=InputEventScreenTouch.new();e.position=point;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventScreenTouch.new();e.position=point;Input.parse_input_event(e)
	else:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(e)
	await frames()
func button(control: Control,touch: bool) -> void:
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames();await click(control.get_global_rect().get_center(),touch)
func unit_point(board: DeploymentBoard,position: Vector2) -> Vector2:return board.global_position+board.board_rect().position+position*board.board_rect().size.x/800
func run() -> void:
	for touch in [false,true]:
		root.size=Vector2i(390,844) if touch else Vector2i(1000,1100);root.content_scale_size=root.size
		var screen: TowerScreen=load("res://scenes/tower.tscn").instantiate();root.add_child(screen);screen.controller.new_run(19,73);screen.show_map();await frames()
		await button(screen.room_buttons["0:3"],touch);var room: TowerBattleScreen=screen.battle_screen;room.toggle_debug()
		await button(room.roster.get_child(0),touch);await click(unit_point(room.board,Vector2(180,400)),touch);await button(room.start_button,touch)
		var b: BattleManager=room.battle;b.set_physics_process(false)
		for i in range(30):b.simulate(1.0/60)
		var u: BattleUnit=b.units[0];var hp: float=u.current_hp;var simulation: float=b.clock.elapsed
		await click(unit_point(room.board,u.position),touch)
		verify(room.ai_debug_actor==u.actor_id() and room.ai_debug_panel.visible,"unit selection opens AI debug")
		verify("Brain" in room.ai_debug_label.text and "Target" in room.ai_debug_label.text and "Intent" in room.ai_debug_label.text and "Movement" in room.ai_debug_label.text,"required debug state displayed")
		verify(u.current_hp==hp and b.clock.elapsed==simulation,"debug selection is simulation read-only")
		verify(room.ai_debug_panel.size.x<root.size.x,"debug fits current window width")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/duni-phase105-ai-"+("mobile" if touch else "desktop")+".png")
		b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2);await frames();verify(b.turning.is_paused(),"TP hold still available")
		var brain_state: Dictionary=u.brain.debug_snapshot(u);b.simulate(2);await frames();verify(u.brain.debug_snapshot(u)==brain_state,"TP freezes AI while debug renders")
		verify(b.turning.change_stance(u.source_member_id,CombatStance.CAUTIOUS),"live stance change")
		verify(u.brain.attack_decision.is_empty() and u.brain.think==0 and u.brain.next_initiative_at>12,"stance change resets source deliberation fields")
		verify(b.turning.resolve(),"resume single path")
		b.clock.elapsed=20;verify(screen.controller.session.request_retreat(),"full retreat remains usable")
		verify(b.finished and b.result.end_reason==BattleEndReason.Value.RETREAT,"retreat settlement unchanged")
		screen.free();await frames()
	print("AI UI RESULT: ",checks," checks; ",failures," failures; display=",DisplayServer.get_name());quit(1 if failures else 0)
