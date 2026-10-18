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
		push_error("COMMON COMBAT UI FAIL: " + message)

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
		root.get_texture().get_image().save_png("/tmp/duni-phase7-" + name + ".png")

func run() -> void:
	screen=load("res://scenes/room_battle.tscn").instantiate()
	screen.full_character_debug=false
	root.add_child(screen)
	await frames()
	var members:Array[GuildMemberState]=screen.guild.all_members()
	for pair in [[0,Vector2(100,220)],[1,Vector2(100,620)],[3,Vector2(220,420)]]:
		await click(center(screen.roster.get_node(members[pair[0]].member_id)))
		await click(map_point(pair[1]))
	var original_start:Vector2=screen.plan.get_entry(members[0].member_id).position
	await click(center(screen.start_button))
	verify(screen.battle.started and screen.battle.common_combat_enabled,"F5 uses actualcommon mode")
	screen.battle.set_physics_process(false)
	var battle:BattleManager=screen.battle
	for unit in battle.units: unit.combat.cooldown=10000;unit.defense_cooldown=1000;unit.parry_cooldown=1000
	var source:BattleUnit=battle.units[0]
	var enemy:BattleUnit=battle.units[3]
	source.position=Vector2(300,400);enemy.position=Vector2(380,400)
	source.combat_state=CombatController.State.ACTIVE;source.combat.attack_serial+=1;source.combat.aim_angle=0
	var attack:AttackInstance=battle.spawn_melee_strike(source,source.data.attack_profile,16)
	attack.age=attack.duration*.5
	enemy.parry_cooldown=0
	verify(enemy.parry.start(enemy,source),"actualbasicparry starts")
	battle.advance_attacks(.001)
	verify(battle.combat_event_counts.get(&"parry_success",0)==1,"weaponcontact parried")
	verify(source.stun_remaining==1.3 and source.combat_state==CombatController.State.IDLE,"reprisal attacker interrupted")
	verify(source.current_hp<members[0].current_hp and enemy.current_hp==150,"reprisal damage targetblock")
	verify(enemy.combat.counter and enemy.parry_cooldown==12,"counter state and cooldownshown")
	await frames()
	await shot("desktop-parry")
	var before:Vector2=enemy.position
	battle.simulate(.1)
	verify(enemy.position!=before and enemy.combat.counter,"counterdash duringwindup")
	battle.clock.elapsed=12
	battle.simulate(2)
	await frames()
	verify(battle.turning.is_paused(),"TP hold common")
	var state:Array=[source.position,source.current_hp,source.stun_remaining,enemy.parry_cooldown,enemy.parry_remaining]
	battle.simulate(.5)
	verify([source.position,source.current_hp,source.stun_remaining,enemy.parry_cooldown,enemy.parry_remaining]==state,"TP freezes actualcommon states")
	var card:StrategyCardInstance
	for c in screen.guild.state.strategy_cards:
		if c.kind==&"iron":card=c
	var scroll:ScrollContainer=screen.turning_panel.card_row.get_parent()
	scroll.scroll_horizontal=int(screen.turning_panel.card_buttons[card.card_id].position.x-8)
	await frames()
	await click(center(screen.turning_panel.card_buttons[card.card_id]))
	await click(center(screen.turning_panel.use_button))
	verify(source.iron_defense_remaining==15 and source.parry_cooldown==0,"GUIiron real readiness")
	verify(not ParryReadiness.is_ready(source),"iron doesnot bypass stun")
	root.content_scale_size=Vector2i(390,844);root.size=Vector2i(390,844)
	await frames()
	verify(screen.turning_panel.size.x<=390 and screen.board.board_rect().size.x>=240,"mobileTP readable")
	verify(screen.turning_panel.resume_button.get_global_rect().end.x<=390,"mobile resume reachable")
	await shot("mobile-hold")
	battle.turning.current.enemy_plans.clear()
	await click(center(screen.turning_panel.resume_button),true)
	verify(not battle.turning.is_paused(),"touch resume")
	battle.simulate(.1)
	verify(source.iron_defense_remaining<15 and source.stun_remaining<state[2],"commonSIM timers resume")
	# Deterministic mixed clash uses real physical pipeline; GUI renders its result.
	for unit in battle.units:
		unit.stun_remaining=0;unit.parry_remaining=0;unit.parry_cooldown=1000;unit.defense_cooldown=1000
		unit.knockback_velocity=Vector2.ZERO;unit.combat.cancel(unit);unit.combat.cooldown=10000
	battle.melee_strikes.clear();battle.projectiles.clear()
	source.position=Vector2(300,400);enemy.position=Vector2(500,400)
	var archer:BattleUnit=battle.units[5]
	archer.position=Vector2(650,650)
	source.combat_state=CombatController.State.ACTIVE;source.combat.attack_serial+=1;source.combat.aim_angle=0
	attack=battle.spawn_melee_strike(source,source.data.attack_profile,16)
	attack.age=attack.duration*.5
	battle.spawn_projectile(archer,PI)
	battle.projectiles[0].position=Vector2(370,400)
	battle.advance_attacks(.001)
	verify(battle.combat_event_counts.get(&"clash",0)==1,"melee and arrow clash visible")
	verify(battle.projectiles.is_empty() and battle.melee_strikes.is_empty(),"mixed clash destroysattacks")
	verify(source.knockback_velocity.length()>0 and source.stun_remaining==.3,"clash recoil/stunshown")
	await frames()
	await shot("mobile-clash")
	battle.clock.elapsed=20
	await frames()
	verify(not screen.retreat_button.disabled,"existing20seconds retreat")
	await click(center(screen.retreat_button),true)
	verify(battle.finished and screen.settlement_status==BattleSettlement.Status.APPLIED,"commonroom single settlement")
	verify(members[0].character_specific_state.get("stun",-1)==.3,"allycommon persistence throughretreat")
	await click(center(screen.next_button),true)
	verify(screen.board.editing and screen.plan.entries().size()==3,"same room formationrestored")
	await click(center(screen.start_button),true)
	verify(screen.room.battle_attempt_count==2 and screen.battle.common_combat_enabled,"retry commonmode")
	screen.battle.set_physics_process(false)
	verify(screen.battle.units[0].current_hp==members[0].current_hp and screen.battle.units[0].stun_remaining > 0 and screen.battle.units[0].stun_remaining <= .3,"retryallyHP/stun")
	verify(screen.battle.units[0].position==original_start,"allyformation notlastcombatposition")
	await shot("mobile-retry")
	print("COMMON COMBAT UI RESULT: ",checks," checks; ",failures," failures; display=",DisplayServer.get_name())
	screen.free()
	quit(1 if failures else 0)

func phase7_manager() -> BattleManager:
	var manager := BattleManager.new()
	manager.full_characters_enabled = false
	return manager
