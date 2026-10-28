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
		push_error("STRATEGY UI FAIL: " + message)

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
		root.get_texture().get_image().save_png("/tmp/duni-phase6-" + name + ".png")

func pick(kind: StringName, touch: bool = false) -> void:
	var card: StrategyCardInstance
	for copy in screen.guild.state.strategy_cards:
		if copy.kind == kind and screen.turning_panel.card_buttons.has(copy.card_id): card = copy; break
	var button: Button = screen.turning_panel.card_buttons[card.card_id]
	var scroll: ScrollContainer = screen.turning_panel.card_row.get_parent()
	scroll.scroll_horizontal = maxi(0, int(button.position.x - 8))
	await frames()
	await click(center(button), touch)

func run() -> void:
	screen = load("res://scenes/room_battle.tscn").instantiate()
	screen.full_character_debug=false
	root.add_child(screen)
	await frames()
	var members: Array[GuildMemberState] = screen.guild.all_members()
	await click(center(screen.roster.get_node(members[0].member_id)))
	await click(map_point(Vector2(100,220)))
	await click(center(screen.roster.get_node(members[1].member_id)))
	await click(map_point(Vector2(100,620)))
	await click(center(screen.start_button))
	verify(screen.battle.started, "deployment starts battle")
	screen.battle.set_physics_process(false)
	for unit in screen.battle.units: unit.combat.cooldown = 10000
	screen.battle.units[0].current_hp = 40
	screen.battle.clock.elapsed = 12
	screen.battle.simulate(2)
	await frames()
	var tp: TurningPointManager = screen.battle.turning
	tp.current.enemy_plans.clear()
	verify(screen.turning_panel.card_buttons.size() == 6, "six cards visible via horizontal strip")
	await pick(&"mango")
	verify(tp.current.selected_card_id != 0 and screen.battle.units[0].current_hp == 40, "selection does not heal")
	await click(center(screen.turning_panel.cancel_button))
	verify(tp.current.selected_card_id == 0 and not screen.guild.state.strategy_cards[0].consumed, "cancel no use")
	await pick(&"mango")
	await click(center(screen.turning_panel.use_button))
	verify(screen.battle.units[0].current_hp == 85 and screen.guild.state.strategy_cards[0].consumed, "mouse recovery exact")
	verify(not screen.turning_panel.card_buttons.has(screen.guild.state.strategy_cards[0].card_id), "used one-off card leaves the hand")
	await click(center(screen.turning_panel.use_button))
	verify(screen.battle.units[0].current_hp == 85, "repeatedclick no heal")
	await pick(&"evade")
	await click(center(screen.turning_panel.use_button))
	verify(tp.current.pending_commands.size() == 1 and screen.turning_panel.card_result.text.contains("대기"), "pending command displayed")
	verify(screen.battle.units[0].strategy_dash.is_empty(), "hold no dash")
	await shot("desktop-cards")
	await click(center(screen.turning_panel.resume_button))
	verify(tp.resolve_count == 1 and not screen.battle.units[0].strategy_dash.is_empty(), "manual resume executes escape")
	var position_before: Vector2 = screen.battle.units[0].position
	screen.battle.simulate(.1)
	verify(screen.battle.units[0].position != position_before, "escape actual movement")
	root.content_scale_size = Vector2i(390,844)
	root.size = Vector2i(390,844)
	await frames()
	screen.battle.clock.elapsed = 42
	screen.battle.simulate(2)
	await frames()
	tp.current.enemy_plans.clear()
	verify(screen.turning_panel.size.x <= 390 and screen.board.board_rect().size.x >= 240, "390x844 readable map and cards")
	await click(center(screen.turning_panel.allies.get_node(members[1].member_id)), true)
	verify(tp.current.selected_member_id == members[1].member_id, "touch target changes")
	await pick(&"shield", true)
	await click(center(screen.turning_panel.use_button), true)
	verify(screen.battle.units[1].shield_hp == 100 and screen.battle.units[0].shield_hp == 0, "touch shield targets independent member")
	var charge_before: float = screen.battle.units[1].ultimate_gauge
	await pick(&"charge", true)
	await click(center(screen.turning_panel.use_button), true)
	verify(screen.battle.units[1].ultimate_gauge == minf(100, charge_before + 50), "mobile charge")
	await pick(&"iron", true)
	await click(center(screen.turning_panel.use_button), true)
	verify(screen.battle.units[1].iron_defense_remaining == 15, "mobile iron readiness")
	await pick(&"taunt", true)
	await click(center(screen.turning_panel.use_button), true)
	verify(tp.current.pending_commands.size() == 1 and screen.turning_panel.card_result.text.contains("도발"), "mobile taunt pending")
	verify(screen.turning_panel.use_button.get_global_rect().end.y <= 844 and screen.turning_panel.resume_button.get_global_rect().end.y <= 844, "buttons reachable mobile")
	await shot("mobile-cards")
	tp.current.remaining_real_time = .01
	screen.battle.simulate(.01)
	await frames()
	verify(tp.resolve_count == 2 and screen.battle.units[2].taunted_member_id == members[1].member_id, "automatic resume applies taunt")
	await click(center(screen.retreat_button), true)
	verify(screen.battle.finished and screen.settlement_status == BattleSettlement.Status.APPLIED, "card battle fullretreat settles")
	await click(center(screen.next_button), true)
	await click(center(screen.start_button), true)
	verify(screen.room.battle_attempt_count == 2 and screen.battle.turning.current == null, "retry fresh TP")
	verify(screen.guild.state.strategy_cards.size() == 6 and screen.guild.state.strategy_cards[0].consumed, "no retry copies/reset")
	verify(screen.battle.units[1].shield_hp > 0 and screen.battle.units[1].ultimate_gauge == minf(100, charge_before + 50), "retry reinject card effects")
	print("STRATEGY UI RESULT: ", checks, " checks; ", failures, " failures; display=", DisplayServer.get_name())
	screen.free()
	quit(1 if failures else 0)
