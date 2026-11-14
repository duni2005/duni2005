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

func card_of(kind: StringName) -> StrategyCardInstance:
	for copy in screen.guild.state.strategy_cards:
		if copy.kind == kind and copy.card_id in screen.battle.turning.hand and not copy.consumed: return copy
	return null
## Pointer down on the card, up past the use line, release: the swipe gesture, fed to the hand
## in its own coordinates (the scaled test window remaps synthetic motion events).
func swipe(kind: StringName, touch: bool = false, rise: float = 170) -> void:
	await frames()
	var hand: StrategyHand = screen.turning_panel.hand
	var at: Vector2 = Vector2(hand.looks[card_of(kind).card_id].pos)
	hand._gui_input(pointer(at, true, touch))
	for i in range(1, 11):
		hand._gui_input(pointer_move(at + Vector2(0, -rise * i / 10.0), touch))
		await process_frame
	hand._gui_input(pointer(at + Vector2(0, -rise), false, touch))
	await frames()
func pointer(at: Vector2, pressed: bool, touch: bool) -> InputEvent:
	if touch:
		var e := InputEventScreenTouch.new();e.index = 0;e.position = at;e.pressed = pressed;return e
	var m := InputEventMouseButton.new();m.position = at;m.button_index = MOUSE_BUTTON_LEFT;m.pressed = pressed;return m
func pointer_move(at: Vector2, touch: bool) -> InputEvent:
	if touch:
		var e := InputEventScreenDrag.new();e.index = 0;e.position = at;return e
	var m := InputEventMouseMotion.new();m.position = at;m.button_mask = MOUSE_BUTTON_MASK_LEFT;return m

func run() -> void:
	screen = load("res://scenes/room_battle.tscn").instantiate()
	screen.full_character_debug=false
	root.add_child(screen)
	await frames()
	# 전투 전 카드 선택: five cards go in, then deployment.
	verify(screen.card_stage and screen.loadout_panel.visible and not screen.roster.get_parent().visible, "card choice comes before deployment")
	for kind in [&"mango", &"evade", &"shield", &"charge", &"iron"]:
		for copy in screen.guild.state.strategy_cards:
			if copy.kind == kind: screen.loadout_panel.add(copy.card_id); break
	await click(center(screen.loadout_panel.confirm_button))
	verify(not screen.card_stage and screen.guild.state.card_loadout.size() == 5, "확정 hands over to deployment")
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
	screen._process(0);await frames()
	verify(screen.turning_panel.hand.rows.size() == 5, "the five chosen cards in the hand")
	var mango: StrategyCardInstance = card_of(&"mango")
	await swipe(&"mango", false, 40)
	verify(screen.battle.units[0].current_hp == 40 and not mango.consumed, "released under the use line: no use")
	tp.current.selected_actor_id = screen.battle.units[0].actor_id()
	await swipe(&"mango")
	verify(screen.battle.units[0].current_hp == 85 and mango.consumed, "mouse swipe recovery exact")
	verify(not screen.turning_panel.hand.rows.any(func(r): return int(r.id) == mango.card_id), "used 소모 card leaves the hand")
	verify(screen.battle.units[0].current_hp == 85, "no second heal")
	await swipe(&"evade")
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
	screen._process(0);await frames()
	await click(center(screen.turning_panel.allies.get_node(members[1].member_id)), true)
	verify(tp.current.selected_member_id == members[1].member_id, "touch target changes")
	await swipe(&"shield", true)
	verify(screen.battle.units[1].shield_hp == 100 and screen.battle.units[0].shield_hp == 0, "touch shield targets independent member")
	var charge_before: float = screen.battle.units[1].ultimate_gauge
	verify(card_of(&"charge").wins_left == 0, "charge ready")
	await swipe(&"charge", true)
	verify(screen.battle.units[1].ultimate_gauge == minf(100, charge_before + 50), "mobile charge")
	await swipe(&"iron", true)
	verify(screen.battle.units[1].iron_defense_remaining == 15, "mobile iron readiness")
	var taunt: StrategyCardInstance = screen.guild.state.give_strategy_card(&"taunt");tp.hand.append(taunt.card_id);screen._process(0)
	await swipe(&"taunt", true)
	verify(tp.current.pending_commands.size() == 1 and screen.turning_panel.card_result.text.contains("도발"), "mobile taunt pending")
	verify(screen.turning_panel.hand.get_global_rect().end.y <= 844 and screen.turning_panel.resume_button.get_global_rect().end.y <= 844, "hand and resume reachable mobile")
	await shot("mobile-cards")
	tp.current.remaining_real_time = .01
	screen.battle.simulate(.01)
	await frames()
	verify(tp.resolve_count == 2 and screen.battle.units[2].taunted_member_id == members[1].member_id, "automatic resume applies taunt")
	await click(center(screen.retreat_button), true)
	verify(screen.battle.finished and screen.settlement_status == BattleSettlement.Status.APPLIED, "card battle fullretreat settles")
	for i in range(400):
		if screen.next_button.is_visible_in_tree() and screen.result_overlay.visible:break
		await process_frame
	await click(center(screen.next_button), true)
	if is_instance_valid(screen.battle) and not screen.board.editing:screen.begin_deployment() # headless: the end cinematic may still hold the button
	await frames()
	# Back in after a retreat: the cards are chosen again; 이전 구성 leaves out the used 소모 card.
	verify(screen.card_stage and screen.guild.state.card_loadout.is_empty(), "retry chooses cards again")
	screen.loadout_panel.fill_previous()
	verify(screen.loadout_panel.chosen.size() == 2 and not screen.guild.state.strategy_cards[0].card_id in screen.loadout_panel.chosen, "이전 구성 without the consumed and cooling cards")
	screen._process(0);await frames();await frames()
	# (The confirm click itself is covered at the start; after the retreat cinematic the headless
	# harness routes touches to the closing overlay, so confirm directly.)
	screen.loadout_panel.confirm()
	screen._process(0);await frames()
	screen.start_battle();await frames()
	verify(screen.room.battle_attempt_count == 2 and screen.battle.turning.current == null and screen.battle.turning.used_cards.is_empty(), "retry fresh TP, 일반 cards back")
	verify(screen.guild.state.strategy_cards.size() == 12 and screen.guild.state.strategy_cards[0].consumed, "no retry copies/reset")
	verify(screen.battle.units[1].shield_hp > 0 and screen.battle.units[1].ultimate_gauge == minf(100, charge_before + 50), "retry reinject card effects")
	print("STRATEGY UI RESULT: ", checks, " checks; ", failures, " failures; display=", DisplayServer.get_name())
	screen.free()
	quit(1 if failures else 0)
