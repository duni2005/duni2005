class_name RoomBattleScreen
extends DeploymentScreen
## Phase8 debug room, all type creation and manual transcendence; no tower map.
@export var full_character_debug: bool = true
var character_select: OptionButton
var character_debug_row: Control
var trans_scroll: ScrollContainer
var trans_row: HBoxContainer
var trans_press: Dictionary = {}
var trans_cutin: PanelContainer
var trans_cutin_label: Label
var room: RoomState
var session: RoomBattleSession
var retreat_button: Button
var room_hud: WalletBar
var turning_panel: TurningPointPanel
var ai_debug_panel: PanelContainer
var ai_debug_label: Label
var ai_debug_actor: String = ""
var deployment_legend: Control
var debug_enabled: bool=false
var debug_button: Button
var selected_details: Label
var result_panel: PanelContainer
var result_label: Label
var result_icon: String="crown"
var result_banner: BattleResultBanner
var battle_cue: BattleCueOverlay
var result_heading: Label
var arena_home: Node
var arena_index: int
var desktop_dock: bool=false
var feedback: Label
var deployment_hint: Label
var speed_row: HBoxContainer
var speed_buttons: Dictionary={}
var battle_toolbar: HBoxContainer
var pause_button: Button
var watch_paused: bool=false
var watch_physics_before: bool=true
var watch_presentation_before: bool=true
var actions_home: Control
var result_overlay: ColorRect
var result_scroll: ScrollContainer
var result_actions: HBoxContainer
var end_sequence: BattleCinematicState
var end_overlay: RetreatPresentation
var end_presenting: bool=false
var end_board_height: float=0
var last_end_id: String=""

func _build_ui() -> void:
	if OS.has_feature("web"):ArenaUI.fit_window(get_tree().root)
	super._build_ui()
	arena_home=board.get_parent();arena_index=board.get_index()
	actions_home=start_button.get_parent()
	tools_row.reparent(arena_home)
	deployment_hint=Label.new();deployment_hint.text="보유 길드원을 골라 배치하세요.";deployment_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;deployment_hint.add_theme_font_size_override("font_size",11);deployment_hint.add_theme_color_override("font_color",ArenaUI.MUTED);actions_home.add_child(deployment_hint);actions_home.move_child(deployment_hint,0)
	ai_debug_panel=PanelContainer.new();ai_debug_panel.z_index=10;ai_debug_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;board.add_child(ai_debug_panel)
	ai_debug_label=Label.new();ai_debug_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;ai_debug_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;ai_debug_label.add_theme_font_size_override("font_size",11);ai_debug_panel.add_child(ai_debug_label);ai_debug_panel.hide()
	board.battle_unit_selected.connect(func(actor_id):ai_debug_actor=actor_id;_refresh_selected())

	var column: VBoxContainer = status.get_parent()
	column.get_child(0).text = "전투 준비 · 길드원 배치"
	room_hud = WalletBar.new();room_hud.guild=guild
	room_hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_hud.custom_minimum_size.y = 70
	column.add_child(room_hud)
	column.move_child(room_hud, 2)
	character_debug_row=HFlowContainer.new()
	column.add_child(character_debug_row);column.move_child(character_debug_row,3)
	character_select=OptionButton.new()
	for type in range(CharacterCatalog.NAMES.size()):character_select.add_item("%02d %s" % [type,guild.definition(type).display_name],type)
	character_debug_row.add_child(character_select)
	_button(character_debug_row,"길드원 생성",_debug_create_member)
	_button(character_debug_row,"테스트 적 추가",_debug_create_enemy)
	trans_scroll=ScrollContainer.new();trans_scroll.custom_minimum_size.y=58
	trans_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(trans_scroll);column.move_child(trans_scroll,board.get_index());trans_row=HBoxContainer.new();trans_row.add_theme_constant_override("separation",6);trans_scroll.add_child(trans_row)
	trans_cutin=PanelContainer.new();add_child(trans_cutin)
	trans_cutin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	trans_cutin.offset_left=12;trans_cutin.offset_top=-155;trans_cutin.offset_right=260;trans_cutin.offset_bottom=-12
	var style:=StyleBoxFlat.new();style.bg_color=Color(.25,.1,.4,.8);style.content_margin_left=20;style.content_margin_top=10
	trans_cutin.add_theme_stylebox_override("panel",style);trans_cutin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	trans_cutin_label=Label.new();trans_cutin_label.add_theme_font_size_override("font_size",30);trans_cutin.add_child(trans_cutin_label);trans_cutin.visible=false
	retreat_button = _button(start_button.get_parent(), "후퇴 · 20초 이후", _retreat)
	ArenaUI.danger(retreat_button)
	retreat_button.disabled = true
	battle_toolbar=HBoxContainer.new();battle_toolbar.custom_minimum_size.y=44;actions_home.add_child(battle_toolbar)
	pause_button=Button.new();pause_button.text="Ⅱ 일시정지";pause_button.add_theme_font_size_override("font_size",11);pause_button.custom_minimum_size.x=104;ArenaUI.bind(pause_button,_toggle_watch_pause);ArenaUI.quiet(pause_button);battle_toolbar.add_child(pause_button)
	var leading_space:=Control.new();leading_space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;battle_toolbar.add_child(leading_space)
	speed_row=HBoxContainer.new();speed_row.add_theme_constant_override("separation",4);battle_toolbar.add_child(speed_row)
	for speed in [1,2,4]:
		var choice:=Button.new();choice.text="%d×"%speed;choice.toggle_mode=true;choice.custom_minimum_size=Vector2(30,44);choice.add_theme_font_size_override("font_size",12);ArenaUI.bind(choice,func():if is_instance_valid(battle):battle.clock.set_speed(float(speed)));speed_row.add_child(choice);speed_buttons[speed]=choice
		ArenaUI.quiet(choice)
	var space:=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;battle_toolbar.add_child(space);retreat_button.reparent(battle_toolbar);retreat_button.custom_minimum_size.x=104
	next_button.text = "같은 방 재도전"
	deployment_legend = column.get_child(board.get_index()+1)
	var aim_overlay:=TranscendenceOverlay.new();aim_overlay.screen=self;add_child(aim_overlay)
	turning_panel = TurningPointPanel.new()
	turning_panel.name = "TurningPointPanel"
	debug_button=_button(start_button.get_parent(),"개발 정보 OFF",toggle_debug);debug_button.hide()
	selected_details=Label.new();selected_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(selected_details);selected_details.hide()
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;feedback.max_lines_visible=2;feedback.mouse_filter=Control.MOUSE_FILTER_IGNORE;feedback.add_theme_font_size_override("font_size",12);feedback.add_theme_color_override("font_color",ArenaUI.GOLD);board.add_child(feedback);feedback.hide()
	result_overlay=ColorRect.new();result_overlay.name="BattleResultOverlay";result_overlay.color=Color(0,0,0,.68);result_overlay.z_index=20;result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(result_overlay)
	var result_margin:=MarginContainer.new();result_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);result_overlay.add_child(result_margin);ArenaUI.safe_margin(result_margin)
	var center:=CenterContainer.new();result_margin.add_child(center)
	result_panel=PanelContainer.new();center.add_child(result_panel);var result_column:=VBoxContainer.new();result_panel.add_child(result_column)
	result_banner=BattleResultBanner.new();result_column.add_child(result_banner)
	result_heading=Label.new();result_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;result_heading.add_theme_font_size_override("font_size",24);result_column.add_child(result_heading)
	result_scroll=ScrollContainer.new();result_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;result_column.add_child(result_scroll)
	result_label=Label.new();result_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;result_label.add_theme_font_size_override("font_size",14);result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result_scroll.add_child(result_label)
	result_actions=HBoxContainer.new();result_actions.alignment=BoxContainer.ALIGNMENT_CENTER;result_column.add_child(result_actions)
	ArenaUI.primary(next_button);next_button.custom_minimum_size.y=48
	result_panel.hide();result_overlay.hide()
	column.add_child(turning_panel)
	column.move_child(turning_panel, deployment_legend.get_index())
	battle_cue=BattleCueOverlay.new();battle_cue.board=board;add_child(battle_cue)
	end_overlay=RetreatPresentation.new();add_child(end_overlay)

func _ensure_room() -> void:
	if room != null:
		return
	room = RoomState.new()
	for kind in StrategyCardCatalog.DEFINITIONS:
		guild.state.give_strategy_card(kind) # Fixed debug grants, once per run.
	for index in range(enemies.size()):
		room.add_enemy("enemy_room_01_%03d" % (index + 1), enemies[index].data, enemies[index].position)
	session = RoomBattleSession.new(guild, room)

func begin_deployment() -> void:
	_ensure_room()
	if is_instance_valid(battle) and not battle.finished:
		return
	if guild.state.game_over or room.cleared:
		return
	enemies = CombatPersistence.placements(room, guild)
	super.begin_deployment()
	retreat_button.disabled = true
	_update_room_hud()

func start_battle() -> void:
	if not board.editing:
		return
	_reset_ending()
	for icon in trans_row.get_children():trans_row.remove_child(icon);icon.queue_free()
	trans_press.clear()
	battle = BattleManager.new()
	battle.common_combat_enabled = true
	battle.full_characters_enabled=full_character_debug
	battle.auto_start = false
	board.add_child(battle)
	session = RoomBattleSession.new(guild, room)
	session.settled.connect(_room_finished)
	if not session.start(plan, battle):
		board.remove_child(battle)
		battle.queue_free()
		battle = null
		status.text = "Cannot start: check living deployment, room and run state."
		return
	board.battle = battle
	board.editing = false
	for button in [start_button, clear_button, remove_button, restore_button]:
		button.disabled = true
	_refresh_roster()
	_update_room_hud()

func _retreat() -> void:
	if watch_paused:_toggle_watch_pause()
	if session == null or not session.request_retreat():
		status.text = "20초 이후 양쪽에 생존자가 있을 때 후퇴할 수 있습니다."

func _room_finished(result: BattleResult, applied: BattleSettlement.Status) -> void:
	if watch_paused:
		watch_paused=false;battle.set_physics_process(watch_physics_before);board.presentation.set_process(watch_presentation_before)
	if result.result_id!=last_end_id:
		last_end_id=result.result_id
		if board.presentation.battle!=battle:board.presentation.attach(battle)
		end_sequence=board.presentation.ensure_cinematic(result.end_reason)
		end_board_height=board.custom_minimum_size.y
		end_presenting=end_sequence.active
		end_overlay.begin(end_sequence,board)
	settlement_status = applied
	var names: Dictionary={BattleEndReason.Value.VICTORY:"승리",BattleEndReason.Value.DEFEAT:"패배",BattleEndReason.Value.RETREAT:"후퇴",BattleEndReason.Value.DRAW:"무승부",BattleEndReason.Value.RUN_ENDED:"탐험 종료"}
	status.text="%s · %.1f초"%[names[result.end_reason],result.elapsed]
	result_label.text=status.text+"\n플레이어 HP "+ArenaUI.hp(guild.state.player_hp,guild.state.player_max_hp)+" · 생존 길드원 %d명"%guild.living_members().size()
	if result.end_reason==BattleEndReason.Value.RETREAT:result_label.text+="\n생존 참가자는 귀환했습니다. 남은 적의 HP와 위치는 유지됩니다."
	elif result.end_reason==BattleEndReason.Value.DEFEAT:result_label.text+="\n패배 추가 손실 20 HP · 예비 길드원이 있다면 재배치 후 도전할 수 있습니다."
	elif room.cleared:result_label.text+="\n방 클리어 · 보상과 첫 승리 회복 정산이 완료되었습니다."
	if guild.state.game_over:result_label.text+="\n게임오버 · "+("플레이어 HP 소진" if guild.state.player_hp<=0 else "생존 길드원 없음")
	var losses: Dictionary=guild.state.death_losses_by_result_id.get(result.result_id,{})
	for id in losses:
		var member: GuildMemberState=guild.get_member(id)
		if member!=null:result_label.text+="\n%s 사망 · 플레이어 HP -%s"%[guild.definition(member.unit_type_id).display_name,ArenaUI.number(float(losses[id]))]
	var tint: Color=Color("93bd8d") if result.end_reason==BattleEndReason.Value.VICTORY else Color("edc08b") if result.end_reason==BattleEndReason.Value.RETREAT else Color("dc8d7c")
	result_panel.add_theme_stylebox_override("panel",ArenaUI.box(Color(tint*.16,1),tint))
	result_icon="crown" if result.end_reason==BattleEndReason.Value.VICTORY else "rest" if result.end_reason==BattleEndReason.Value.RETREAT else "boss"
	result_banner.reveal("victory" if result.end_reason==BattleEndReason.Value.VICTORY else "retreat" if result.end_reason==BattleEndReason.Value.RETREAT else "defeat")
	result_heading.queue_redraw()
	result_heading.text="방 클리어!" if result.end_reason==BattleEndReason.Value.VICTORY else "후퇴 완료" if result.end_reason==BattleEndReason.Value.RETREAT else "탐험 종료" if guild.state.game_over else "전투 패배"
	result_heading.add_theme_color_override("font_color",tint)
	result_label.add_theme_color_override("font_color",tint)
	result_panel.show()
	next_button.disabled = applied != BattleSettlement.Status.APPLIED or guild.state.game_over or room.cleared
	retreat_button.disabled = true
	retreat_button.text = "후퇴 · 전투 종료"
	_refresh_roster()
	_update_room_hud()

func _update_room_hud() -> void:
	if room_hud == null or room == null:
		return
	var allies: int=guild.living_members().size();var opponents: int=room.living_enemies().size()
	if is_instance_valid(battle):allies=battle.units.filter(func(u):return u.original_team==0 and u.alive).size();opponents=battle.units.filter(func(u):return u.original_team==1 and u.alive).size()
	room_hud.battle=battle
	room_hud.text="플레이어 HP %s · 아군 %d · 적 %d"%[ArenaUI.hp(guild.state.player_hp,guild.state.player_max_hp),allies,opponents]

func _process(delta: float) -> void:
	status.battle=battle;status.combat_active=not board.editing;status.spectator_paused=watch_paused
	_refresh_ai_debug()
	if battle_cue!=null:battle_cue.observe(battle,delta)
	super._process(delta)
	if session != null and is_instance_valid(battle) and battle.started and not battle.finished:
		retreat_button.disabled = session.retreat.check(battle, guild.state) != RetreatController.Code.OK
		retreat_button.text = "전체 후퇴" if not retreat_button.disabled else "후퇴까지 %d초" % maxi(0, ceili(20 - battle.clock.elapsed))
		_update_room_hud()

	if not board.editing:
		for button in [start_button,remove_button,clear_button,restore_button,deploy_tools_button]:button.hide()
	else:
		start_button.show();deploy_tools_button.show()
		for button in [remove_button,clear_button,restore_button]:button.visible=debug_enabled
	var turning: TurningPointManager = battle.turning if is_instance_valid(battle) else null
	turning_panel.refresh(turning)
	character_debug_row.visible=board.editing and full_character_debug and debug_enabled
	_refresh_transcendence(0 if watch_paused else delta)
	turning_panel.debug_enabled=debug_enabled
	_refresh_selected()
	var paused: bool = turning != null and turning.is_paused()
	var finished: bool=is_instance_valid(battle) and battle.finished
	retreat_button.visible=not board.editing and not finished
	next_button.visible=is_instance_valid(battle) and battle.finished
	# Keep the map readable on mobile; debug deployment details return on resume.
	roster.get_parent().visible = board.editing and not paused
	deployment_legend.visible = board.editing and not paused and debug_enabled
	actions_home.visible = board.editing or (not paused and not finished)
	room_hud.visible = true
	status.visible = not paused and (not board.editing or debug_enabled)
	deployment_hint.visible=board.editing
	battle_toolbar.visible=not board.editing and not finished and not paused
	for speed in speed_buttons:
		speed_buttons[speed].disabled=watch_paused or not is_instance_valid(battle) or battle.clock.state!=BattleClock.State.NORMAL;speed_buttons[speed].set_pressed_no_signal(is_instance_valid(battle) and int(battle.clock.speed)==speed)
	pause_button.disabled=not is_instance_valid(battle) or battle.finished or battle.clock.state!=BattleClock.State.NORMAL
	pause_button.text="▶ 계속" if watch_paused else "Ⅱ 일시정지"
	if is_instance_valid(battle) and not battle.finished and not paused:status.text="전투 중   %02d:%02d   ·   아군 %d / 적 %d"%[int(battle.clock.elapsed)/60,int(battle.clock.elapsed)%60,battle.units.filter(func(u):return u.alive and u.original_team==0).size(),battle.units.filter(func(u):return u.alive and u.original_team==1).size()]
	status.get_parent().get_child(0).visible = not paused
	if end_sequence!=null:end_presenting=end_sequence.active
	end_overlay.visible=end_presenting
	if end_sequence!=null and end_sequence.complete:
		board.presentation.hide();end_sequence.release_visuals()
	if end_presenting:status.text=" "
	result_panel.visible=finished and not end_presenting;result_overlay.visible=finished and not end_presenting
	if finished and next_button.get_parent()!=result_actions:next_button.reparent(result_actions)
	elif not finished and next_button.get_parent()!=actions_home:next_button.reparent(actions_home)
	if is_instance_valid(board.presentation):
		feedback.text=" · ".join(board.presentation.feed)
		if is_instance_valid(battle):
			var losses: Dictionary=guild.state.death_losses_by_result_id.get(battle.battle_result_id,{})
			if not losses.is_empty():feedback.text+=" · 플레이어 HP -"+ArenaUI.number(losses.values().reduce(func(a,b):return a+float(b),0.0))
		feedback.visible=debug_enabled and not feedback.text.is_empty() and not paused and not finished
	if paused:
		status.text = "전투 정지 · 아군 성향을 선택하세요"
	var transcending: bool=is_instance_valid(battle) and battle.transcendence!=null and not battle.transcendence.cast.is_empty()
	trans_cutin.visible=transcending
	if transcending:
		selected_details.hide();feedback.hide()
		var cast: Dictionary=battle.transcendence.cast;var caster=battle.find_actor(cast.actor)
		trans_cutin_label.text="%s %s\n초월 · 검격" % ["DUNI ARENA",caster.data.display_name] if caster!=null else "초월 · 검격"
		trans_cutin.modulate.a=1-clampf((float(cast.time)-.72)/.3,0,1)
		for ui in [turning_panel,trans_scroll,room_hud,status,status.get_parent().get_child(0),roster.get_parent(),deployment_legend,start_button.get_parent()]:ui.visible=false
	if paused and retreat_button.get_parent() != turning_panel.heading.get_parent():
		retreat_button.reparent(turning_panel.heading.get_parent())
	elif not paused and retreat_button.get_parent() != battle_toolbar:
		retreat_button.reparent(battle_toolbar)
	if paused and (not full_character_debug or battle.transcendence==null or not battle.units.any(func(u):return battle.transcendence.ready(u))):trans_scroll.hide()
	_layout_arena()

func _debug_create_member() -> void:
	if not board.editing:return
	var member: GuildMemberState=guild.create_member(character_select.get_selected_id())
	if member!=null:_refresh_roster();status.text="Created %s / %s" % [member.member_id,guild.definition(member.unit_type_id).display_name]
func _debug_create_enemy() -> void:
	if not board.editing or room.cleared:return
	var point: Vector2=Vector2.ZERO
	for y in range(80,741,70):
		for x in range(470,741,70):
			var candidate:=Vector2(x,y)
			if room.living_enemies().all(func(e):return e.position.distance_to(candidate)>=58):point=candidate;break
		if point!=Vector2.ZERO:break
	if point==Vector2.ZERO:return
	room.add_enemy("enemy_debug_%03d" % room.enemy_state.size(),guild.definition(character_select.get_selected_id()),point)
	enemies=CombatPersistence.placements(room,guild);board.enemies=enemies;board.queue_redraw();_update_room_hud()
func _refresh_transcendence(dt: float) -> void:
	trans_scroll.visible=is_instance_valid(battle) and battle.started and not battle.finished and full_character_debug
	if not trans_scroll.visible:return
	if trans_row.get_child_count()==0:
		for u in battle.units:
			if u.source_member_id.is_empty():continue
			var button:=ArenaCard.new();button.card_type="party";button.type_id=u.data.type_id;button.title=u.data.display_name;button.custom_minimum_size=Vector2(48,54);button.set_meta("actor",u.actor_id());button.show_member(guild,guild.get_member(u.source_member_id));button.subtitle=u.data.display_name;trans_row.add_child(button)
			button.gui_input.connect(_trans_button_input.bind(u.actor_id(),button))
	for button in trans_row.get_children():
		var u=battle.find_actor(button.get_meta("actor"))
		if u==null:continue
		button.text="%s · 초월 %d%% / 궁극기 %d%%
%s" % [u.data.display_name,int(u.transcendence_gauge),int(u.ultimate_gauge),"사망" if not u.alive else "준비 · 길게 눌러 방향 선택" if battle.transcendence.ready(u) else "충전 중"]
		button.description="초월 %d%% · %s"%[int(u.transcendence_gauge),"길게 눌러 시전" if battle.transcendence.ready(u) else "충전 중"];button.queue_redraw()
		button.hp=u.current_hp;button.hp_max=u.max_hp;button.gauge=u.transcendence_gauge;button.dead=not u.alive;button.status_text="초월 준비" if battle.transcendence.ready(u) else "";button.tooltip_text=button.text+"\nHP "+ArenaUI.hp(u.current_hp,u.max_hp)+" · 기력 %d/5"%button.energy
		button.modulate=Color("cd9aff") if u.transcendence_gauge>=100 else Color.WHITE
	if not trans_press.is_empty():
		trans_press.held=float(trans_press.held)+dt
		if float(trans_press.held)>=.16 and not trans_press.get("activated",false):
			var u=battle.find_actor(trans_press.actor)
			trans_press.activated=battle.transcendence.begin(u,trans_press.origin)
			if trans_press.activated:battle.transcendence.update(trans_press.point)
func _trans_button_input(event: InputEvent,actor: String,button: Button) -> void:
	if watch_paused:return
	var pressed: bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed
	if pressed and battle.transcendence.ready(battle.find_actor(actor)):
		var origin: Vector2=button.get_global_rect().get_center()
		trans_press={"actor":actor,"held":0.0,"origin":origin,"point":origin,"activated":false,"dragged":false}
func _input(event: InputEvent) -> void:
	if trans_press.is_empty() or not is_instance_valid(battle):return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		trans_press.point=event.position
		if event.position.distance_to(trans_press.origin)>4:trans_press.dragged=true
		if trans_press.get("activated",false):battle.transcendence.update(event.position)
		elif event.position.distance_to(trans_press.origin)>12:trans_press.clear()
	elif (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		if trans_press.get("activated",false):
			battle.transcendence.update(event.position if trans_press.dragged else trans_press.origin);battle.transcendence.release()
		trans_press.clear()

func _refresh_ai_debug() -> void:
	if not debug_enabled or not is_instance_valid(battle) or board.editing or ai_debug_actor.is_empty():ai_debug_panel.hide();return
	var unit=battle.find_actor(ai_debug_actor)
	if unit==null:ai_debug_panel.hide();return
	var state: Dictionary=unit.brain.debug_snapshot(unit)
	ai_debug_panel.position=Vector2(8,8);ai_debug_panel.size=Vector2(minf(350,board.size.x-18),0)
	ai_debug_label.text="AI Brain %s / %s\nTarget %s\nPlan %s · Entry %s\nIntent %s · commit %.2f\nDistance %.1f · danger %.2f / safe %.2f\nDesired (%.2f, %.2f)\nHeading (%.2f, %.2f)\nMovement %s · Ability %s\nReaction %s · stance %s"%[unit.data.display_name,unit.actor_id(),state.target,state.plan,state.entry,str(state.intent.get("at","—")),state.commit,state.desired_distance,state.danger,state.safe,unit.brain.desired_direction.x,unit.brain.desired_direction.y,unit.brain.heading.x,unit.brain.heading.y,state.movement_override,state.ability_override,state.reaction,state.stance]
	ai_debug_panel.show()

func toggle_debug() -> void:
	debug_enabled=not debug_enabled;debug_button.text="개발 정보 ON" if debug_enabled else "개발 정보 OFF"
	if board.presentation!=null:board.presentation.debug_enabled=debug_enabled
	_refresh_ai_debug()
func _refresh_selected() -> void:
	if selected_details==null:return
	var unit=battle.find_actor(ai_debug_actor) if is_instance_valid(battle) else null
	selected_details.visible=debug_enabled and unit!=null and not board.editing and not battle.finished and not battle.clock.is_turning_paused()
	if unit!=null:selected_details.text="%s %s · %s\nHP %s · 보호막 %d · 궁극기 %d%% · 초월 %d%%"%["",unit.data.display_name,ArenaUI.stance(unit.stance),ArenaUI.hp(unit.current_hp,unit.max_hp),ceili(unit.shield_hp),int(unit.ultimate_gauge),int(unit.transcendence_gauge)] + "\n" + CharacterVisuals.ABILITIES[unit.data.type_id]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:toggle_debug();get_viewport().set_input_as_handled()

func _layout_arena() -> void:
	# Match the original play flow: status above the arena, actions below it.
	# Never dock all controls at the top-right, including on high-DPR phones.
	var margin: MarginContainer=arena_home.get_parent()
	desktop_dock=false;margin.offset_left=0;margin.offset_right=0
	_move_layout_child(room_hud,1)
	if not board.editing:
		_move_layout_child(status,2)
		_move_layout_child(board,3)
		_move_layout_child(trans_scroll,4)
		_move_layout_child(actions_home,5)
	else:
		_move_layout_child(board,2)
		_move_layout_child(tools_row,3)
		_move_layout_child(roster.get_parent(),4)
		_move_layout_child(actions_home,5)
		_move_layout_child(status,6)
	var viewport: Vector2=get_viewport_rect().size
	var occupied: float=margin.get_theme_constant("margin_top")+margin.get_theme_constant("margin_bottom")
	var visible_count: int=0
	for child in arena_home.get_children():
		if child is Control and child.visible:
			visible_count+=1
			if child!=board:occupied+=child.get_combined_minimum_size().y
	occupied+=maxi(0,visible_count-1)*arena_home.get_theme_constant("separation")
	board.size_flags_vertical=Control.SIZE_FILL
	board.custom_minimum_size.y=minf(viewport.x-(24 if board.editing else 16),maxf(80 if turning_panel.visible else 120,viewport.y-occupied))
	if end_presenting and end_board_height>0:board.custom_minimum_size.y=end_board_height
	var arena_rect: Rect2=board.board_rect()
	feedback.position=arena_rect.position+Vector2(10,maxf(0,arena_rect.size.y-42));feedback.size=Vector2(maxf(1,arena_rect.size.x-20),38)
	for strip in [trans_scroll,actions_home]:
		strip.size_flags_horizontal=Control.SIZE_FILL if board.editing else Control.SIZE_SHRINK_CENTER
		strip.custom_minimum_size.x=0 if board.editing else (viewport.x-16 if strip==actions_home else board.custom_minimum_size.y)
	actions_home.alignment=FlowContainer.ALIGNMENT_END if board.editing else FlowContainer.ALIGNMENT_CENTER
	deployment_hint.custom_minimum_size.x=maxf(80,viewport.x-164) if viewport.x<720 else maxf(100,viewport.x-360)
	battle_toolbar.custom_minimum_size.x=viewport.x-16 if viewport.x<720 else minf(800,viewport.x-24)
	start_button.custom_minimum_size.x=(128 if viewport.x<720 else 180) if board.editing else 0
	if board.editing and start_button.get_index()!=actions_home.get_child_count()-1:actions_home.move_child(start_button,-1)
	result_panel.custom_minimum_size.x=minf(520,viewport.x-48)
	result_scroll.custom_minimum_size.y=clampf(maxf(result_label.get_minimum_size().y,result_label.get_line_count()*20.0)+12,80,minf(260,maxf(80,viewport.y-240)))

func _move_layout_child(child: Node,index: int) -> void:
	# Moving a Control every frame cancels a held mouse press. Reorder only on
	# a phase transition, then leave the control hierarchy stable while playing.
	if child.get_index()!=index:arena_home.move_child(child,index)

func _draw_result_emblem() -> void:
	ArenaIcon.draw(result_heading,Vector2(21,17),result_icon,28,Color.WHITE)

func _reset_ending() -> void:
	watch_paused=false;end_sequence=null;end_presenting=false;end_board_height=0;last_end_id=""
	if is_instance_valid(end_overlay):end_overlay.hide()

func _toggle_watch_pause() -> void:
	if not is_instance_valid(battle) or battle.finished or battle.clock.state!=BattleClock.State.NORMAL:return
	# This is an unsaved spectator control at a frame boundary. No Clock, AI,
	# timer, RNG or persistent field is rewritten; TP/cast cannot enter here.
	if not watch_paused:
		watch_physics_before=battle.is_physics_processing();watch_presentation_before=board.presentation.is_processing()
		battle.set_physics_process(false);board.presentation.set_process(false);watch_paused=true
	else:
		battle.set_physics_process(watch_physics_before);board.presentation.set_process(watch_presentation_before);watch_paused=false
