extends SceneTree
## GUI routing for persistent room outcomes. Deterministic state fixtures, no saves.
var checks: int = 0
var failures: int = 0
var screen: RoomBattleScreen

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ROOM UI FAIL: " + message)

func frames() -> void:
	await process_frame
	await process_frame
	await process_frame

func click(point: Vector2, touch: bool = false) -> void:
	point = root.get_final_transform() * point
	if touch:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.position = point
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.position = point
		Input.parse_input_event(up)
	else:
		var down := InputEventMouseButton.new()
		down.position = point
		down.global_position = point
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		var up := InputEventMouseButton.new()
		up.position = point
		up.global_position = point
		up.button_index = MOUSE_BUTTON_LEFT
		Input.parse_input_event(up)
	await frames()

func center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()

func map_point(at: Vector2) -> Vector2:
	var rect: Rect2 = screen.board.board_rect()
	return screen.board.global_position + rect.position + at * rect.size.x / 800.0

func shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/duni-phase4-" + name + ".png")

func run() -> void:
	screen = load("res://scenes/room_battle.tscn").instantiate()
	screen.full_character_debug=false
	root.add_child(screen)
	await frames()
	var members: Array[GuildMemberState] = screen.guild.all_members()
	await click(center(screen.roster.get_node(members[0].member_id)))
	await click(map_point(Vector2(120, 260)))
	await click(center(screen.roster.get_node(members[1].member_id)), true)
	await click(map_point(Vector2(120, 540)), true)
	verify(screen.plan.entries().size() == 2, "mouse/touch individual guild deployment")
	await click(center(screen.start_button))
	verify(screen.battle.started and screen.room.battle_attempt_count == 1 and screen.retreat_button.disabled, "start Button enters room, retreat too early")
	screen.battle.set_physics_process(false)
	var dead_enemy: BattleUnit = screen.battle.units[2]
	var damaged_enemy: BattleUnit = screen.battle.units[3]
	var damaged_enemy_id: String = damaged_enemy.source_enemy_id
	dead_enemy.receive_damage(9999, screen.battle.units[0])
	damaged_enemy.receive_damage(73, screen.battle.units[0])
	damaged_enemy.position = Vector2(310, 400)
	screen.battle.units[0].current_hp = 43
	screen.battle.units[1].receive_damage(9999, damaged_enemy)
	verify(screen.guild.state.player_hp == 95, "live death HUD rule, only5 loss")
	screen.battle.clock.elapsed = 19.999
	screen._process(0)
	verify(screen.retreat_button.disabled, "GUI retreat disabled before20")
	screen.battle.clock.elapsed = 20
	screen._process(0)
	await shot("retreat-ready")
	await click(center(screen.retreat_button))
	verify(screen.battle.finished and screen.battle.result.end_reason == BattleEndReason.Value.RETREAT and screen.settlement_status == BattleSettlement.Status.APPLIED, "retreat Button routes one settlement")
	verify(screen.guild.state.player_hp == 95 and members[0].current_hp == 43 and members[1].current_hp == 0, "retreat result preserves survivor/dead and no extra penalty")
	verify(not screen.room.cleared and not screen.next_button.disabled, "uncleared result permits retry")
	await shot("retreat-result")
	await click(center(screen.next_button))
	verify(screen.board.editing and screen.enemies.size() == 2 and screen.plan.entries().size() == 1, "retry UI restores survivor formation and excludes dead enemy")
	verify(screen.enemies[0].current_hp == 77 and screen.enemies[0].position == Vector2(310, 400), "remaining enemy HP and position visible in retry preview")
	await shot("retry-preview")
	await click(center(screen.deploy_tools_button))
	screen.deploy_tools.id_pressed.emit(1);screen.deploy_tools.hide();await frames()
	await click(center(screen.roster.get_node(members[2].member_id)))
	await click(map_point(Vector2(100, 600)))
	await click(center(screen.start_button))
	verify(screen.battle.started and screen.room.battle_attempt_count == 2 and screen.battle.units[0].source_member_id == members[2].member_id, "new reserve/composition starts same room")
	screen.battle.set_physics_process(false)
	verify(screen.battle.units[1].source_enemy_id == damaged_enemy_id and screen.battle.units[1].current_hp == 77, "retry battle uses same enemy actor identity and HP")
	screen.battle.units[0].receive_damage(9999, screen.battle.units[1])
	screen.battle.check_outcome()
	verify(screen.battle.result.end_reason == BattleEndReason.Value.DEFEAT and screen.guild.state.player_hp == 70 and not screen.guild.state.game_over, "second death5 + defeat20, reserves still allow play")
	verify(not screen.next_button.disabled and not screen.room.cleared, "defeat is not game over")
	await shot("defeat-reserves")
	await click(center(screen.next_button))
	await click(center(screen.roster.get_node(members[0].member_id)))
	await click(map_point(Vector2(80, 200)))
	await click(center(screen.start_button))
	verify(screen.room.battle_attempt_count == 3 and screen.battle.units[0].current_hp == 43, "third attempt uses previous survivor HP and newly chosen start")
	screen.battle.set_physics_process(false)
	# Isolated late-run fixture for the player-HP termination condition.
	screen.guild.state.player_hp = 4
	screen.battle.units[0].receive_damage(9999, screen.battle.units[1])
	screen.battle.check_outcome()
	verify(screen.guild.state.game_over and screen.guild.state.player_hp == 0 and screen.battle.result.end_reason == BattleEndReason.Value.RUN_ENDED, "HP game-over interrupts/snapshots even with reserves")
	verify(screen.next_button.disabled and screen.retreat_button.disabled, "run end locks retry and retreat")
	await shot("game-over")
	root.content_scale_size = Vector2i(390, 844)
	root.size = Vector2i(390, 844)
	await frames()
	verify(screen.room_hud.size.x <= 390 and screen.board.board_rect().size.x <= 390, "persistent room HUD and map fit mobile width")
	await shot("mobile")
	print("ROOM UI RESULT: ", checks, " checks; ", failures, " failures; display=", DisplayServer.get_name())
	screen.free()
	quit(1 if failures else 0)
