class_name TowerBattleScreen
extends RoomBattleScreen
## Adapter reuses deployment, TP, cards and transcendence UI with a real map room.
signal map_requested
signal presentation_requested(event: Dictionary)
signal main_menu_requested
signal battle_started
var presented_results: Dictionary={}
var tower_controller: TowerController
var management_dialog: AcceptDialog
var management_panel: GuildManagementPanel
var management_button: Button
var result_kicker: Label
var result_wallet: WalletBar
var result_emblem: PanelEmblem
var result_losses: Label
var result_rewards: Label
var result_detail: VBoxContainer
var result_column: VBoxContainer
var retreat_scene: RetreatPresentation
var retreat_presenting: bool=false
var retreat_routed: bool=false
var result_revealed: bool=false
var reward_feedback: Dictionary={}
var records_button: Button
var records_dialog: AcceptDialog
var records_label: Label
var header_editing: bool=true
var starting_battle: bool=false
var loading_cover: ColorRect
var navigation_row: HBoxContainer
var navigation_title: Label
var menu_button: Button
var menu_dialog: AcceptDialog
func _ready() -> void:
	guild=tower_controller.guild;room=tower_controller.current_room()
	full_character_debug=true
	enemies=CombatPersistence.placements(room,guild)
	_build_ui();_build_tower_result();begin_deployment()
	retreat_scene=end_overlay
	var title: Label=status.get_parent().get_child(0);title.text="";title.custom_minimum_size.y=44
	navigation_row=HBoxContainer.new();title.add_child(navigation_row);navigation_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);navigation_row.offset_top=0;navigation_row.offset_bottom=44
	navigation_title=Label.new();navigation_title.text=ArenaUI.room_title(room);navigation_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;navigation_title.add_theme_font_override("font",ArenaUI.heading_font());navigation_title.add_theme_font_size_override("font_size",19);navigation_title.clip_text=true;navigation_row.add_child(navigation_title)
	next_button.pressed.disconnect(next_button.get_meta("bound_action"))
	ArenaUI.bind(next_button,_return_map)
	next_button.text="탐험 지도로"
	character_debug_row.hide()
	management_button=ArenaUI.nav_button("guild",_open_management);navigation_row.add_child(management_button)
	menu_button=ArenaUI.nav_button("menu",_open_menu);navigation_row.add_child(menu_button)
	menu_dialog=AcceptDialog.new();add_child(menu_dialog);var menu_actions:=VBoxContainer.new();menu_dialog.add_child(menu_actions);ArenaUI.dialog_header(menu_dialog,menu_actions,"메뉴");ArenaModalBackdrop.new().connect_window(menu_dialog,self)
	var home:=Button.new();home.text="메인화면";home.custom_minimum_size=Vector2(240,48);ArenaUI.with_icon(home,"home",22);ArenaUI.bind(home,func():if not starting_battle and board.editing:menu_dialog.hide();main_menu_requested.emit());menu_actions.add_child(home)
	management_dialog=AcceptDialog.new();management_dialog.title="전투 전 정비";management_dialog.get_ok_button().text="닫기";add_child(management_dialog)
	# The large management page is created when opened, not during room entry.
	records_button=Button.new();records_button.text="참가자 · 기록";records_button.add_theme_font_size_override("font_size",11);ArenaUI.quiet(records_button);ArenaUI.bind(records_button,_open_records);navigation_row.add_child(records_button);records_button.hide()
	records_dialog=AcceptDialog.new();add_child(records_dialog);var record_column:=VBoxContainer.new();records_dialog.add_child(record_column);ArenaUI.dialog_header(records_dialog,record_column,"참가자 · 기록");var record_scroll:=ScrollContainer.new();record_scroll.custom_minimum_size=Vector2(250,230);record_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;record_column.add_child(record_scroll);records_label=Label.new();records_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;records_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;record_scroll.add_child(records_label);ArenaModalBackdrop.new().connect_window(records_dialog,self)
	deployment_legend.text="배치된 아군을 드래그해 이동할 수 있습니다."
	if room.room_type in [RoomType.BOSS,RoomType.MINIBOSS]:navigation_title.add_theme_color_override("font_color",ArenaUI.GOLD);status.text="강력한 적이 기다립니다. 길드원과 진형을 준비하세요."
func _ensure_room() -> void:
	pass # The route owns the encounter, never recreate or grant debug cards.
func start_battle() -> void:
	if not board.editing or starting_battle:return
	starting_battle=true;start_button.disabled=true
	UiTransition.play("battle");BackgroundMusic.play(&"battle")
	_reset_ending();result_revealed=false;reward_feedback.clear();retreat_routed=false
	for icon in trans_row.get_children():trans_row.remove_child(icon);icon.queue_free()
	trans_press.clear()
	battle=BattleManager.new();battle.auto_start=false;board.add_child(battle)
	var accepted: bool
	if tower_controller.save_manager!=null and tower_controller.save_manager.background_enabled:
		loading_cover=ColorRect.new();loading_cover.color=Color(0,0,0,.28);loading_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loading_cover.z_index=100;add_child(loading_cover)
		var loading:=Label.new();loading.text="전투 준비 중…";loading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;loading.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);loading_cover.add_child(loading)
		# Paint feedback before capture; physics has not begun and input is locked.
		await get_tree().process_frame
		accepted=await tower_controller.start_battle_async(plan,battle)
		loading_cover.queue_free();loading_cover=null
	else:accepted=tower_controller.start_battle(plan,battle)
	starting_battle=false
	if not accepted:
		board.remove_child(battle);battle.queue_free();battle=null
		status.text="시작 전 저장 실패 · "+tower_controller.save_manager.last_result.detail if tower_controller.save_manager!=null and not tower_controller.save_manager.last_result.ok() else "생존 길드원을 유효한 위치에 배치하세요."
		start_button.disabled=false;return
	session=tower_controller.session;session.settled.connect(_room_finished)
	board.battle=battle;board.editing=false
	for button in [start_button,clear_button,remove_button,restore_button]:button.disabled=true
	_refresh_roster();_update_room_hud()
	battle_started.emit()
func _room_finished(result: BattleResult,applied: BattleSettlement.Status) -> void:
	super._room_finished(result,applied)
	next_button.disabled=applied!=BattleSettlement.Status.APPLIED
	next_button.text="탐험 지도로"
	_format_result(result)
	retreat_presenting=result.end_reason==BattleEndReason.Value.RETREAT and end_presenting
	room_hud.updates_suspended=end_presenting;result_wallet.updates_suspended=end_presenting
	if not presented_results.has(result.result_id):
		presented_results[result.result_id]=true
		if room.reward_claimed and result.end_reason==BattleEndReason.Value.VICTORY:
			reward_feedback={"point":ArenaUI.control_center(board),"gold":room.gold_reward,"tokens":room.token_reward}
func _return_map() -> void:
	if tower_controller.return_map():map_requested.emit()
func _process(delta: float) -> void:
	super._process(delta)
	if result_column!=null:result_column.custom_minimum_size.x=minf(420,get_viewport_rect().size.x-72)
	retreat_presenting=end_presenting and is_instance_valid(battle) and battle.result!=null and battle.result.end_reason==BattleEndReason.Value.RETREAT
	if end_presenting:
		result_overlay.hide();next_button.disabled=true
	elif is_instance_valid(battle) and battle.finished and not result_revealed:
		result_revealed=true;room_hud.updates_suspended=false;result_wallet.updates_suspended=false
		if result_column!=null:UiMotion.pop(result_column,0,.9,.4)
		if battle.result.end_reason==BattleEndReason.Value.RETREAT:
			if not retreat_routed:retreat_routed=true;call_deferred("_finish_retreat_presentation")
		else:
			next_button.disabled=false;result_column.modulate.a=0
			var reveal:=create_tween();reveal.tween_property(result_column,"modulate:a",1.0,.25)
			if not reward_feedback.is_empty():presentation_requested.emit(reward_feedback);reward_feedback.clear()
	character_debug_row.hide()
	if management_button!=null:management_button.visible=board.editing
	if menu_button!=null:menu_button.visible=board.editing
	if header_editing!=board.editing:
		header_editing=board.editing
		navigation_title.add_theme_font_size_override("font_size",19 if board.editing else 14);navigation_title.text=("" if board.editing else "두니 타워 · ")+ArenaUI.room_title(room)
	# A height-bound (landscape) arena grows when the fight slims the wallet;
	# tall phones are width-bound and keep the full wallet.
	var viewport: Vector2=get_viewport_rect().size;var slim: bool=not board.editing and viewport.x>viewport.y*.8
	if room_hud.compact!=slim:room_hud.compact=slim
	if records_button!=null:records_button.visible=not board.editing and not end_presenting and is_instance_valid(battle) and not battle.finished
func _update_room_hud() -> void:
	super._update_room_hud()

func _open_management() -> void:
	if not board.editing or starting_battle:return
	if management_panel==null:
		management_panel=GuildManagementPanel.new();management_panel.controller=tower_controller;management_panel.prebattle_room=room;management_dialog.add_child(management_panel)
		management_panel.home_requested.connect(func():main_menu_requested.emit())
		management_panel.modified.connect(func():_refresh_roster();_update_room_hud())
	management_panel.show_tab("inventory");management_dialog.popup(ArenaUI.page_rect(self))
func _open_menu() -> void:
	if board.editing and not starting_battle:menu_dialog.popup_centered(Vector2i(280,0))

func _open_records() -> void:
	if not is_instance_valid(battle):return
	var lines: Array[String]=[]
	for unit in battle.units:lines.append("%s %s · %s"%["아군" if unit.original_team==0 else "적",unit.data.display_name,ArenaUI.hp(unit.current_hp,unit.max_hp) if unit.alive else "사망"])
	if not board.presentation.feed.is_empty():lines.append("\n최근 기록\n"+"\n".join(board.presentation.feed))
	records_label.text="\n".join(lines);records_dialog.popup_centered(Vector2i(mini(380,int(get_viewport_rect().size.x)-32),mini(420,int(get_viewport_rect().size.y)-80)))

func _build_tower_result() -> void:
	# Tower results are a page with the existing wallet, not a modal over combat.
	for control in [result_heading,result_scroll,result_actions,result_banner]:control.get_parent().remove_child(control)
	for child in result_overlay.get_children():result_overlay.remove_child(child);child.queue_free()
	result_overlay.color=ArenaUI.BACKGROUND
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);result_overlay.add_child(margin);ArenaUI.safe_margin(margin)
	var column:=VBoxContainer.new();margin.add_child(column)
	var heading:=Label.new();heading.text="%d층 · %d번 방 · %s"%[room.floor_index+1,room.lane+1,RoomType.LABELS[room.room_type]];heading.custom_minimum_size.y=44;heading.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;heading.add_theme_font_override("font",ArenaUI.heading_font());heading.add_theme_font_size_override("font_size",19);column.add_child(heading)
	result_wallet=WalletBar.new();result_wallet.guild=guild;column.add_child(result_wallet)
	result_panel=PanelContainer.new();result_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;result_panel.add_theme_stylebox_override("panel",ArenaUI.window_style());column.add_child(result_panel)
	result_emblem=PanelEmblem.new();result_emblem.mode="result";result_panel.add_child(result_emblem)
	var center:=CenterContainer.new();result_panel.add_child(center)
	result_column=VBoxContainer.new();result_column.add_theme_constant_override("separation",16);center.add_child(result_column)
	result_banner.hide();result_column.add_child(result_banner)
	result_kicker=Label.new();result_kicker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;result_kicker.add_theme_font_override("font",ArenaUI.numbers_font());result_kicker.add_theme_font_size_override("font_size",16);result_kicker.add_theme_color_override("font_color",ArenaUI.ACCENT);result_column.add_child(result_kicker)
	result_heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result_heading.add_theme_font_override("font",ArenaUI.heading_font());result_heading.add_theme_font_size_override("font_size",30);result_heading.add_theme_color_override("font_color",Color("eef1fa"));result_column.add_child(result_heading)
	var summary_center:=CenterContainer.new();result_column.add_child(summary_center)
	var summary:=PanelContainer.new();summary.custom_minimum_size.x=260;var summary_style:=ArenaUI.card_style();summary_style.content_margin_left=20;summary_style.content_margin_right=20;summary_style.content_margin_top=14;summary_style.content_margin_bottom=14;summary.add_theme_stylebox_override("panel",summary_style);summary_center.add_child(summary)
	result_detail=VBoxContainer.new();result_detail.add_theme_constant_override("separation",12);summary.add_child(result_detail)
	result_losses=Label.new();result_losses.add_theme_color_override("font_color",Color("ff8088"));result_detail.add_child(result_losses)
	result_rewards=Label.new();result_rewards.add_theme_color_override("font_color",ArenaUI.HP);result_detail.add_child(result_rewards)
	result_column.add_child(result_scroll);result_scroll.hide();result_column.add_child(result_actions)
	next_button.custom_minimum_size.x=210;ArenaUI.with_icon(next_button,"play",14,true)
func _format_result(result: BattleResult) -> void:
	var victory: bool=room.cleared
	if result_emblem!=null:result_emblem.tint=Color("f0d490") if victory else Color("8a96c8")
	result_kicker.text="ROOM CLEAR" if victory else "RETREAT" if result.end_reason==BattleEndReason.Value.RETREAT else "EXPLORATION ENDED" if guild.state.game_over else "TRY AGAIN"
	result_heading.text="방 클리어!" if victory else "안전하게 후퇴했습니다" if result.end_reason==BattleEndReason.Value.RETREAT else "탐험이 종료되었습니다" if guild.state.game_over else "길드원을 정비해 다시 도전하세요"
	result_heading.add_theme_color_override("font_color",ArenaUI.GOLD if victory else Color("eef1fa"))
	result_kicker.add_theme_color_override("font_color",ArenaUI.ACCENT if victory else ArenaUI.DANGER if guild.state.game_over else ArenaUI.MUTED)
	result_panel.add_theme_stylebox_override("panel",ArenaUI.window_style(Color("a88a4a") if victory else ArenaUI.WINDOW_RIM))
	var losses: Dictionary=guild.state.death_losses_by_result_id.get(result.result_id,{})
	var death_loss: float=losses.values().reduce(func(a,b):return a+float(b),0.0)
	var penalty: float=20 if result.end_reason==BattleEndReason.Value.DEFEAT else 0
	result_losses.text="유닛 손실 %d명\n플레이어 HP -%s"%[result.dead_member_ids.size(),ArenaUI.number(death_loss+penalty)]
	result_losses.add_theme_color_override("font_color",ArenaUI.MUTED if result.dead_member_ids.is_empty() and death_loss+penalty<=0 else ArenaUI.DANGER)
	result_rewards.visible=room.reward_claimed and victory
	if result_rewards.visible:
		var equipment_gold: int=0
		for id in result.surviving_member_ids:equipment_gold+=int(result.member_victory_gold.get(id,0))
		result_rewards.text="승리 보상\n골드 +%d\n토큰 +%d"%[room.gold_reward+equipment_gold,room.token_reward]
	result_label.hide();result_banner.hide()
func _finish_retreat_presentation() -> void:
	# The session and autosave already settled this retreat exactly once.
	# Returning to the map only routes the existing result.
	if tower_controller.return_map():map_requested.emit()
