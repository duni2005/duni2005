extends SceneTree
## Real GUI routing (Buttons + board); usable headless or in an actual OS window.
## Screenshots go to /tmp only. No automatic commands/settings in game code.
var checks: int = 0
var failures: int = 0
var screen: DeploymentScreen

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("UI SMOKE FAIL: " + message)

func settle_frames() -> void:
	await process_frame
	await process_frame
	await process_frame

func dispatch(event: InputEvent) -> void:
	# Input.parse_input_event receives window pixels; GUI helpers return viewport
	# logical pixels. Account for project canvas_items stretch before dispatch.
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		event.position = root.get_final_transform() * event.position
		if event is InputEventMouse:
			event.global_position = event.position
	Input.parse_input_event(event)

func mouse_click(point: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = point
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	dispatch(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = point
	up.button_index = MOUSE_BUTTON_LEFT
	dispatch(up)
	await settle_frames()

func touch_click(point: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.position = point
	down.index = 0
	down.pressed = true
	dispatch(down)
	await process_frame
	var up := InputEventScreenTouch.new()
	up.position = point
	up.index = 0
	dispatch(up)
	await settle_frames()

func center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func map_point(at: Vector2) -> Vector2:
	var rect: Rect2 = screen.board.board_rect()
	return screen.board.global_position + rect.position + at * rect.size.x / 800.0

func screenshot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/duni-phase3-" + name + ".png")

func run() -> void:
	screen = load("res://scenes/deployment.tscn").instantiate()
	screen.debug_comparison_minimal=true
	root.add_child(screen)
	await settle_frames()
	# Fixed simple enemy for a visible surviving-formation UI round trip.
	screen.enemies = [{"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(650, 400)}]
	screen.begin_deployment()
	await settle_frames()
	var a: GuildMemberState = screen.guild.all_members()[0]
	var b: GuildMemberState = screen.guild.all_members()[1]
	var before_a: float = a.current_hp
	await mouse_click(center(screen.roster.get_node(a.member_id)))
	verify(screen.board.selected_id == a.member_id, "mouse card selects actual member")
	await mouse_click(map_point(Vector2(140, 260)))
	verify(screen.plan.get_entry(a.member_id) != null, "mouse board click places")
	if screen.plan.get_entry(a.member_id) == null:
		quit(1)
		return
	var down := InputEventMouseButton.new()
	down.position = map_point(Vector2(140, 260))
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	dispatch(down)
	await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = map_point(Vector2(220, 260))
	motion.relative = Vector2(60, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	dispatch(motion)
	await process_frame
	var up := InputEventMouseButton.new()
	up.position = map_point(Vector2(220, 260))
	up.button_index = MOUSE_BUTTON_LEFT
	dispatch(up)
	await settle_frames()
	verify(screen.plan.get_entry(a.member_id).position.distance_to(Vector2(220, 260)) < 0.001, "GUI mouse drag maps to continuous logical position")
	await screenshot("placed")
	await mouse_click(center(screen.remove_button))
	verify(screen.plan.entries().is_empty() and a.current_hp == before_a and a.energy == 5, "remove Button preserves member state")
	await touch_click(center(screen.roster.get_node(b.member_id)))
	verify(screen.board.selected_id == b.member_id, "native touch selects actual Button")
	await touch_click(map_point(Vector2(140, 540)))
	verify(screen.plan.get_entry(b.member_id) != null and b.energy == 0, "native touch board places energy-zero member once")
	verify(screen.plan.entries().size() == 1, "touch/mouse emulation does not duplicate placement")
	var touch_down := InputEventScreenTouch.new()
	touch_down.position = map_point(Vector2(140, 540))
	touch_down.index = 0
	touch_down.pressed = true
	dispatch(touch_down)
	await process_frame
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.position = map_point(Vector2(200, 540))
	touch_drag.index = 0
	touch_drag.relative = Vector2(60, 0)
	dispatch(touch_drag)
	await process_frame
	var touch_up := InputEventScreenTouch.new()
	touch_up.position = map_point(Vector2(200, 540))
	touch_up.index = 0
	dispatch(touch_up)
	await settle_frames()
	verify(screen.plan.get_entry(b.member_id).position.distance_to(Vector2(200, 540)) < 0.001, "native GUI touch drag moves without duplicate input")
	await touch_click(map_point(Vector2(140, 540)))
	await mouse_click(center(screen.roster.get_node(a.member_id)))
	await mouse_click(map_point(Vector2(140, 260)))
	await mouse_click(center(screen.start_button))
	verify(screen.battle != null and screen.battle.started and not screen.board.editing, "start Button routes into combat")
	verify(screen.guild.state.last_formation.entries.size() == 2 and a.energy == 5, "start saves formation without early energy settlement")
	await screenshot("battle")
	screen.battle.set_physics_process(false)
	for frame in range(180 * 60):
		if screen.battle.finished:
			break
		screen.battle.simulate(1.0 / 60.0)
	verify(screen.battle.finished and screen.settlement_status == BattleSettlement.Status.APPLIED, "real combat result settles via screen")
	var expected: int = screen.battle.result.surviving_member_ids.size()
	verify(a.energy == 4 and b.energy == 0, "exactly one participant energy loss")
	await screenshot("result")
	await mouse_click(center(screen.next_button))
	verify(expected > 0 and screen.board.editing and screen.plan.entries().size() == expected, "next Button restores only survivors")
	verify(screen.guild.state.last_formation.entries[0].position.distance_to(Vector2(140, 540)) < 0.001, "last formation keeps starts, not battle end positions")
	await screenshot("restored")
	# Reduced viewport simulates portrait mobile layout without changing rules.
	root.content_scale_size = Vector2i(390, 844)
	root.size = Vector2i(390, 844)
	await settle_frames()
	verify(screen.board.size.x > 0 and screen.board.board_rect().size.x <= 390, "mobile viewport remains usable")
	await touch_click(center(screen.clear_button))
	var reserve: GuildMemberState = screen.guild.all_members()[3]
	var reserve_hp: float = reserve.current_hp
	var scrolling: ScrollContainer = screen.roster.get_parent()
	scrolling.ensure_control_visible(screen.roster.get_node(reserve.member_id))
	await settle_frames()
	verify(scrolling.scroll_horizontal > 0, "horizontal roster exposes later individual cards on mobile")
	await touch_click(center(screen.roster.get_node(reserve.member_id)))
	verify(screen.board.selected_id == reserve.member_id, "mobile scrolled card touch selects correct individual")
	await touch_click(map_point(Vector2(140, 400)))
	verify(screen.plan.get_entry(reserve.member_id) != null and reserve.current_hp == reserve_hp, "mobile scaled map placement preserves reserve HP")
	await screenshot("mobile")
	print("UI SMOKE RESULT: ", checks, " checks; ", failures, " failures; display=", DisplayServer.get_name())
	screen.free()
	quit(1 if failures else 0)
