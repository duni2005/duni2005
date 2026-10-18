extends SceneTree
var screen: RoomBattleScreen
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("CHARACTER UI: "+label)
func frames() -> void:
	await process_frame;await process_frame;await process_frame
func click(control: Control) -> void:
	var e:=InputEventMouseButton.new();e.position=root.get_final_transform()*control.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventMouseButton.new();e.position=root.get_final_transform()*control.get_global_rect().get_center();e.global_position=e.position;e.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(e);await frames()
func capture(name: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/duni-phase8-"+name+".png")
func run() -> void:
	root.size=Vector2i(1000,1100)
	screen=load("res://scenes/room_battle.tscn").instantiate();root.add_child(screen);screen.toggle_debug();await frames()
	verify(screen.full_character_debug and screen.character_select.item_count==CharacterCatalog.NAMES.size(),"every real type is an option")
	screen.character_select.select(23)
	await click(screen.character_debug_row.get_child(1))
	verify(screen.guild.all_members().size()==7 and screen.guild.all_members().back().unit_type_id==23,"UI creates individual machine gun")
	screen.character_select.select(21)
	await click(screen.character_debug_row.get_child(2))
	verify(screen.room.enemy_state.size()==4 and screen.room.enemy_state.values().back().unit_type_id==21,"UI adds test mirror enemy")
	var members: Array=screen.guild.all_members()
	verify(screen.plan.place(members[0].member_id,Vector2(100,400))==DeploymentRules.Code.OK,"member deployment")
	verify(screen.plan.place(members[6].member_id,Vector2(200,550))==DeploymentRules.Code.OK,"new type deployment")
	await click(screen.start_button)
	var b: BattleManager=screen.battle;b.set_physics_process(false);await frames()
	verify(b.common_combat_enabled and b.full_characters_enabled,"F5 actual full common mode")
	verify(b.units.any(func(u):return u.data.type_id==23) and b.units.any(func(u):return u.data.type_id==21),"new types rendered as battle instances")
	for u in b.units:u.combat.cooldown=1000;u.parry_cooldown=1000;u.move_speed=0
	b.clock.elapsed=12;b.turning.advance(.01);b.turning.advance(2);await frames()
	verify(b.turning.is_paused() and screen.turning_panel.visible,"TP integration")
	verify(screen.trans_row.get_child_count()==2,"owned transcendence row")
	var u=b.units[0];u.transcendence_gauge=100;u.stun_remaining=0;u.combat.cancel(u);u.ultimate.cast.clear()
	await frames()
	verify(b.transcendence.ready(u),"manual ready")
	if DisplayServer.get_name()!="headless":await capture("desktop")
	root.size=Vector2i(390,844);root.content_scale_size=Vector2i(390,844);screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);await frames()
	verify(screen.turning_panel.resume_button.get_global_rect().end.y<=844,"mobile resume visible")
	verify(screen.trans_row.get_child(0).get_global_rect().end.y<=844,"mobile trans icon visible")
	var button: Button=screen.trans_row.get_child(0);var origin: Vector2=button.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new();event.index=0;event.position=origin;event.pressed=true;screen._trans_button_input(event,u.actor_id(),button)
	screen._refresh_transcendence(.16)
	verify(b.clock.state==BattleClock.State.TRANSCENDENCE_AIM,"touch hold .16 pauses")
	var move:=InputEventScreenDrag.new();move.position=origin+Vector2(60,0);screen._input(move)
	event=InputEventScreenTouch.new();event.index=0;event.position=origin+Vector2(60,0);screen._input(event)
	verify(b.clock.state==BattleClock.State.TRANSCENDENCE_CAST and u.transcendence_gauge==0,"touch direction releases manual skill")
	var pos: Vector2=b.units[-1].position;var time: float=b.clock.elapsed;b.simulate(.5)
	verify(b.units[-1].position==pos and b.clock.elapsed==time,"other actors frozen during manual skill")
	b.simulate(.7);await frames()
	verify(b.clock.is_turning_paused(),"returns TP hold")
	if DisplayServer.get_name()!="headless":await capture("mobile")
	b.turning.resolve();await frames();verify(b.clock.state==BattleClock.State.NORMAL,"TP resume full mode")
	b.clock.elapsed=20;screen._retreat();await frames()
	verify(b.finished and b.result.end_reason==BattleEndReason.Value.RETREAT,"full characters retreat")
	await click(screen.next_button)
	verify(screen.board.editing and screen.plan.entries().size()==2,"survivor formation retry")
	screen.free();await frames();print("CHARACTER UI RESULT: ",checks," checks; ",failures," failures; display=",DisplayServer.get_name());quit(1 if failures else 0)
