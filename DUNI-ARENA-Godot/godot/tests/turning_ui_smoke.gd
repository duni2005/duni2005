extends SceneTree
## Real Control/input routing; deterministic timing fixtures, not a balance test.
var checks: int = 0
var failures: int = 0
var screen: RoomBattleScreen

func _initialize() -> void:
	call_deferred("run")

func verify(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("TURNING UI FAIL: " + message)

func frames() -> void:
	await process_frame
	await process_frame
	await process_frame

func center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func click(point: Vector2, touch: bool = false) -> void:
	point = root.get_final_transform() * point
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		Input.parse_input_event(event)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(event)
	await frames()

func map_point(at: Vector2) -> Vector2:
	var rect: Rect2 = screen.board.board_rect()
	return screen.board.global_position + rect.position + at * rect.size.x / 800.0

func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/duni-phase5-" + name + ".png")

func run() -> void:
	screen = load("res://scenes/room_battle.tscn").instantiate()
	screen.full_character_debug=false
	root.add_child(screen)
	await frames()
	var members: Array[GuildMemberState] = screen.guild.all_members()
	await click(center(screen.roster.get_node(members[0].member_id)))
	await click(map_point(Vector2(100,220)))
	await click(center(screen.roster.get_node(members[1].member_id)),true)
	await click(map_point(Vector2(100,620)),true)
	await click(center(screen.start_button))
	verify(screen.battle.started and screen.battle.turning != null, "F5 deployment starts TP-enabled room")
	screen.battle.set_physics_process(false)
	for unit in screen.battle.units: unit.combat.cooldown = 10000
	screen.battle.clock.elapsed = 12
	screen.battle.simulate(0.5)
	await frames()
	verify(screen.turning_panel.visible and screen.turning_panel.resume_button.disabled, "slowdown shown, resume not yet allowed")
	await shot("slowdown")
	screen.battle.simulate(1.5)
	await frames()
	var tp: TurningPointManager = screen.battle.turning
	verify(tp.is_paused() and screen.turning_panel.resume_button.visible and not screen.turning_panel.resume_button.disabled, "hold UI active")
	verify(screen.turning_panel.allies.get_child_count() == 2 and not screen.turning_panel.plans.text.is_empty(), "living ally choices and fixed enemy plans shown")
	verify(screen.retreat_button.disabled, "first hold remains earlier than20 retreat")
	var at: float = screen.battle.clock.elapsed
	var locations: Array = screen.battle.units.map(func(u): return u.position)
	screen.battle.simulate(5)
	await frames()
	verify(screen.battle.clock.elapsed == at and locations == screen.battle.units.map(func(u): return u.position), "simulation frozen during displayed countdown")
	verify(screen.turning_panel.heading.text.contains("35"), "real35 seconds displayed")
	await click(center(screen.turning_panel.allies.get_node(members[1].member_id)))
	await click(center(screen.turning_panel.choices[CombatStance.CAUTIOUS]))
	verify(members[1].stance == CombatStance.CAUTIOUS and screen.battle.units[1].stance == CombatStance.CAUTIOUS, "mouse member and stance store individually")
	await shot("paused")
	await click(center(screen.turning_panel.resume_button))
	verify(not tp.is_paused() and tp.resolve_count == 1 and not screen.turning_panel.visible, "resume Button shared resolution, hide panel")
	screen.battle.simulate(0.1)
	verify(screen.battle.clock.elapsed > at, "battle continues after Button")
	root.content_scale_size = Vector2i(390,844)
	root.size = Vector2i(390,844)
	await frames()
	screen.battle.clock.elapsed = 42
	screen.battle.simulate(1)
	screen.battle.simulate(1)
	await frames()
	verify(tp.is_paused() and tp.serial == 2 and screen.turning_panel.size.x <= 390, "second TP fits mobile")
	verify(screen.board.board_rect().size.x >= 240, "mobile map keeps minimum readable area")
	await click(center(screen.turning_panel.allies.get_node(members[0].member_id)),true)
	await click(center(screen.turning_panel.choices[CombatStance.COVER]),true)
	verify(members[0].stance == CombatStance.COVER and tp.current.selected_member_id == members[0].member_id, "mobile touch ally/stance")
	verify(screen.turning_panel.plans.get_global_rect().size.x <= 390 and screen.turning_panel.resume_button.get_global_rect().end.x <= 390, "mobile plans/resume reachable")
	await shot("mobile")
	await click(center(screen.turning_panel.resume_button),true)
	verify(tp.resolve_count == 2 and not tp.is_paused(), "mobile touch manual resume")
	# Third occurrence tests auto-resume on the same presentation/resolve path.
	screen.battle.clock.elapsed = 72
	screen.battle.simulate(2)
	await frames()
	tp.current.remaining_real_time = 0.1
	screen.battle.simulate(0.1)
	await frames()
	verify(tp.resolve_count == 3 and not screen.turning_panel.visible, "automatic resume closes UI once")
	await click(center(screen.retreat_button),true)
	verify(screen.battle.finished and screen.settlement_status == BattleSettlement.Status.APPLIED and not tp.enabled, "post TP retreat still settles once")
	await click(center(screen.next_button),true)
	await click(center(screen.start_button),true)
	verify(screen.room.battle_attempt_count == 2 and screen.battle.turning.next_at == 12 and screen.battle.turning.current == null, "GUI same-room retry fresh TP schedule")
	await shot("retry")
	print("TURNING UI RESULT: ",checks," checks; ",failures," failures; display=",DisplayServer.get_name())
	screen.free()
	quit(1 if failures else 0)
