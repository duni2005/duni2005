extends SceneTree
## Actual Godot GUI events + explicit battle/progression outcome fixtures.
var checks: int=0
var failures: int=0
var screen: TowerScreen
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1;print("TOWER CHECK ",checks,": ",label," = ",ok)
	if not ok:failures+=1;push_error("TOWER UI FAIL: "+label)
func frames() -> void:
	await process_frame;await process_frame;await process_frame
func click(point: Vector2,touch: bool=false) -> void:
	point=root.get_final_transform()*point
	if touch:
		var e:=InputEventScreenTouch.new();e.position=point;e.index=0;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventScreenTouch.new();e.position=point;e.index=0;Input.parse_input_event(e)
	else:
		var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame
		e=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(e)
	await frames()
func button(control: Control,touch: bool=false) -> void:await click(control.get_global_rect().get_center(),touch)
func point(board: DeploymentBoard,logical: Vector2) -> Vector2:return board.global_position+board.board_rect().position+logical*board.board_rect().size.x/800
func outcome_fixture(b: BattleManager) -> void:
	for u in b.units:
		if u.original_team==1:u.receive_damage(u.current_hp+1,b.units[0])
	b.check_outcome()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/duni-phase9-"+name+".png")
func nodes(node: Node) -> int:
	var count: int=1
	for child in node.get_children():count+=nodes(child)
	return count
func run() -> void:
	root.size=Vector2i(1000,1100)
	screen=load("res://scenes/tower.tscn").instantiate();root.add_child(screen);screen.controller.new_run(19,73);screen.show_map();await frames()
	var node_count: int=nodes(screen)
	verify(node_count<600,"15-floor map has bounded UI nodes")
	for i in range(3):screen.show_map();await frames()
	verify(nodes(screen)==node_count,"map rebuild has no accumulating Room Nodes")
	print("TOWER MAP UI NODES: ",node_count)
	await capture("desktop-map")
	verify(screen.room_buttons.size()==120,"15 floor map renders120 room buttons")
	verify(screen.controller.guild.all_members().size()==4,"real initial guild")
	verify(not screen.room_buttons["0:3"].disabled and screen.room_buttons["1:0"].disabled,"floor locking UI")
	await button(screen.room_buttons["0:3"]);var room_screen: TowerBattleScreen=screen.battle_screen
	await capture("desktop-deployment")
	verify(room_screen!=null and room_screen.board.editing,"room→deployment")
	verify(room_screen.guild==screen.controller.guild,"same run guild injected")
	await button(room_screen.roster.get_child(0));await click(point(room_screen.board,Vector2(120,400)))
	verify(room_screen.plan.entries().size()==1,"GUI member selection +free placement")
	await button(room_screen.start_button);var b: BattleManager=room_screen.battle;b.set_physics_process(false)
	verify(b.started and b.common_combat_enabled and b.full_characters_enabled,"actual full combat mode")
	b.units[0].current_hp=40;outcome_fixture(b);await frames()
	verify(room_screen.room.cleared and room_screen.next_button.text=="탐험 지도로" and not room_screen.next_button.disabled,"clear /map return UI")
	await button(room_screen.next_button)
	verify(screen.battle_screen==null and screen.controller.guild.state.tower.phase==&"route","result returns to map")
	verify(screen.room_buttons["0:3"].modulate.r<.6,"cleared combat dim")
	# Phase10 noncombat completion is intentionally absent: explicit domain fixture.
	for id in ["0:0","0:1"]:screen.controller.guild.state.tower.map.get_room(id).cleared=true
	screen.controller.refresh_progress(0);screen.show_map();await frames()
	verify(not screen.room_buttons["1:0"].disabled,"progression unlock visible after actual clear threshold")
	await button(screen.room_buttons["0:5"]);room_screen=screen.battle_screen
	verify(room_screen.plan.entries().size()==1,"last started formation automatically restored")
	await button(room_screen.start_button);b=room_screen.battle;b.set_physics_process(false)
	for u in b.units:u.move_speed=0;u.combat.cooldown=1000
	var enemies: Array=b.units.filter(func(u):return not u.source_enemy_id.is_empty())
	var dead_id: String=enemies[0].source_enemy_id;var saved_id: String=enemies[1].source_enemy_id
	enemies[0].receive_damage(enemies[0].current_hp+1,b.units[0]);enemies[1].current_hp=17;enemies[1].position=Vector2(450,550)
	b.clock.elapsed=20;await frames();await button(room_screen.retreat_button)
	verify(b.result.end_reason==BattleEndReason.Value.RETREAT and not room_screen.room.cleared,"retreat via button")
	await button(room_screen.next_button);await button(screen.room_buttons["0:5"]);room_screen=screen.battle_screen
	verify(room_screen.enemies.any(func(e):return e.enemy.enemy_id==saved_id and e.current_hp==17 and e.position==Vector2(450,550)),"map reentry shows damaged enemy at saved position")
	verify(not room_screen.enemies.any(func(e):return e.enemy.enemy_id==dead_id),"dead enemy absent on retry")
	# Explicit 390x844 viewport; touch controls use the same policy/coordinate path.
	screen.free();root.size=Vector2i(390,844);root.content_scale_size=Vector2i(390,844)
	screen=load("res://scenes/tower.tscn").instantiate();root.add_child(screen);screen.controller.new_run(19,73);screen.show_map();await frames()
	await capture("mobile-map")
	verify(screen.map_scroll.size.x<=390 and screen.map_scroll.size.y>500,"mobile map readable vertical scroll")
	var map_rows=screen.map_scroll.get_child(0)
	var horizontal: ScrollContainer=map_rows.get_child(14).get_children().filter(func(n):return n is ScrollContainer)[0]
	horizontal.scroll_horizontal=390;await frames()
	verify(horizontal.scroll_horizontal>0,"later ten-room floors retain horizontal room scroll")
	await button(screen.room_buttons["0:3"],true);room_screen=screen.battle_screen
	verify(room_screen!=null and room_screen.board.size.x<=390,"mobile room touch /board")
	await button(room_screen.roster.get_child(0),true);await click(point(room_screen.board,Vector2(120,400)),true)
	verify(room_screen.plan.entries().size()==1,"mobile touch deployment")
	await button(room_screen.start_button,true);b=room_screen.battle;b.set_physics_process(false)
	verify(b.started,"mobile touch battle start")
	b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2);await frames()
	await capture("mobile-tp")
	verify(b.turning.is_paused() and room_screen.turning_panel.visible,"tower TP hold UI remains connected")
	var ally: BattleUnit=b.units[0];ally.current_hp=40
	await button(room_screen.turning_panel.card_buttons[1],true)
	await button(room_screen.turning_panel.use_button,true)
	verify(ally.current_hp==85 and screen.controller.guild.state.strategy_cards[0].consumed,"tower touch mango card real effect")
	# Keep enemies off the manual slash path: input test, not random victory test.
	for enemy in b.units:
		if enemy.original_team==1:enemy.position.y=700
	ally.transcendence_gauge=100;ally.stun_remaining=0;ally.combat.cancel(ally);ally.ultimate.cast.clear();await frames()
	var origin: Vector2=room_screen.trans_row.get_child(0).get_global_rect().get_center()
	var input:=InputEventScreenTouch.new();input.index=0;input.position=root.get_final_transform()*origin;input.pressed=true;Input.parse_input_event(input)
	await create_timer(.22).timeout;await frames()
	verify(b.clock.state==BattleClock.State.TRANSCENDENCE_AIM,"tower UI hold enters manual transcendence aim")
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=root.get_final_transform()*(origin+Vector2(60,0));Input.parse_input_event(drag);await process_frame
	input=InputEventScreenTouch.new();input.index=0;input.position=root.get_final_transform()*(origin+Vector2(60,0));Input.parse_input_event(input);await frames()
	verify(b.clock.state==BattleClock.State.TRANSCENDENCE_CAST and ally.transcendence_gauge==0,"tower UI direction release casts skill")
	b.simulate(1.2);await frames()
	verify(b.turning.is_paused(),"transcendence returns to TP hold")
	await button(room_screen.turning_panel.resume_button,true)
	verify(not b.turning.is_paused(),"mobile TP manual resume")
	outcome_fixture(b);await frames();await button(room_screen.next_button,true)
	verify(screen.battle_screen==null,"mobile result→map")
	screen.map_scroll.scroll_vertical=10000;await frames();verify(screen.map_scroll.scroll_vertical>0,"15-floor map vertical scroll")
	screen.free();await frames()
	print("TOWER UI RESULT: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
