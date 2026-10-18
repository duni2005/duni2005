class_name TowerScreen
extends Control
signal main_menu_requested
## Functional vertical floors / horizontal rooms with ID-based content routing.
var controller := TowerController.new()
var wallet: WalletBar
var body: VBoxContainer
var map_scroll: ScrollContainer
var room_buttons: Dictionary = {}
var content_screen: TowerContentScreen
var guild_dialog: AcceptDialog
var guild_panel: GuildManagementPanel
var battle_screen: TowerBattleScreen
var confirm_abandon: ConfirmationDialog
var reward_dialog: AcceptDialog
var reward_panel: ConquestRewardPanel
var reward_title: Label
var new_button: Button
var abandon_button: Button
var resume_saved: bool=false
var save_label: Label
var manual_save_button: Button
var main_button: Button
var notice: Label
var last_unlocked: int=-1
var menu_dialog: AcceptDialog
var menu_button: Button
var guild_button: Button
var fx: TowerSceneDirector
var watched_run: String=""
var known_floors: Dictionary={}
var known_chapters: Dictionary={}
var map_rendered_run: String=""
var floor_widgets: Dictionary={}
var confirm_new: ConfirmationDialog
func _exit_tree() -> void:controller.release_runtime_connections()
func _ready() -> void:
	ArenaUI.install(self)
	fx=TowerSceneDirector.new();add_child(fx)
	get_window().gui_embed_subwindows=true
	get_window().size_changed.connect(_fit_display)
	_fit_display()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	ArenaUI.safe_margin(margin)
	body=VBoxContainer.new();margin.add_child(body)
	var brand:=ArenaBrandBar.new();body.add_child(brand)
	var top:=HBoxContainer.new();top.custom_minimum_size.y=44;body.add_child(top)
	var heading:=Label.new();heading.name="TowerHeading";heading.text="두니 타워 · 탐험 지도";heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_theme_font_size_override("font_size",18);top.add_child(heading)
	guild_button=make_nav_button(top,"guild",open_guild);guild_button.custom_minimum_size=Vector2(44,44);guild_button.tooltip_text="유닛 / 인벤토리 / 강화"
	menu_button=make_nav_button(top,"menu",func():menu_dialog.popup_centered(Vector2i(280,0)));menu_button.custom_minimum_size=Vector2(44,44);menu_button.tooltip_text="메뉴"
	for button in [guild_button,menu_button]:
		for state in ["normal","hover","pressed"]:
			var style: StyleBoxFlat=ArenaUI.box(Color("26342d"));style.set_corner_radius_all(22);button.add_theme_stylebox_override(state,style)
	wallet=WalletBar.new();wallet.guild=controller.guild;body.add_child(wallet)
	menu_dialog=AcceptDialog.new();menu_dialog.title="메뉴";menu_dialog.get_ok_button().text="닫기";add_child(menu_dialog);ArenaModalBackdrop.new().connect_window(menu_dialog,self)
	var actions:=VBoxContainer.new();menu_dialog.add_child(actions);ArenaUI.dialog_header(menu_dialog,actions,"메뉴")
	new_button=make_button(actions,"새 런",_request_new_run)
	abandon_button=make_button(actions,"탐험 포기",func():menu_dialog.hide();confirm_abandon.popup_centered())
	ArenaUI.danger(abandon_button)
	if controller.save_manager!=null:
		manual_save_button=make_button(actions,"저장",_manual_save)
		main_button=make_button(actions,"메인으로",_main_menu)
		save_label=Label.new();save_label.add_theme_font_size_override("font_size",11);save_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;save_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;save_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);save_label.offset_left=-250;save_label.offset_top=-22;add_child(save_label)
		controller.save_manager.status_changed.connect(_save_status)
	var map_frame:=PanelContainer.new();map_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(map_frame)
	var map_column:=VBoxContainer.new();map_frame.add_child(map_column)
	var map_title:=Label.new();map_title.text="두니 타워 탐험";map_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;map_title.add_theme_color_override("font_color",ArenaUI.GOLD);map_column.add_child(map_title)
	map_scroll=ScrollContainer.new();map_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;map_column.add_child(map_scroll)
	map_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(notice);notice.add_theme_font_size_override("font_size",12);notice.hide()
	confirm_abandon=ConfirmationDialog.new();confirm_abandon.dialog_text="이번 탐험을 포기하겠습니까?";add_child(confirm_abandon)
	confirm_abandon.confirmed.connect(func():if controller.abandon(true):show_map())
	reward_dialog=AcceptDialog.new();reward_dialog.title="층 정복 보상";add_child(reward_dialog)
	var reward_column:=VBoxContainer.new();reward_column.add_theme_constant_override("separation",18);reward_dialog.add_child(reward_column)
	ArenaUI.dialog_header(reward_dialog,reward_column,"층 정복 보상");reward_title=reward_column.get_child(0).get_child(0)
	reward_panel=ConquestRewardPanel.new();reward_panel.custom_minimum_size.x=280;reward_column.add_child(reward_panel)
	ArenaModalBackdrop.new().connect_window(reward_dialog,self)
	confirm_new=ConfirmationDialog.new();confirm_new.dialog_text="저장된 탐험을 새 런으로 교체하겠습니까?";add_child(confirm_new);confirm_new.confirmed.connect(new_run)
	if not resume_saved:new_run()
	guild_dialog=AcceptDialog.new();guild_dialog.title="유닛";guild_dialog.get_ok_button().text="닫기";add_child(guild_dialog)
	guild_panel=GuildManagementPanel.new();guild_panel.controller=controller;guild_dialog.add_child(guild_panel);guild_panel.modified.connect(_refresh_wallet)
	guild_panel.home_requested.connect(_main_menu)
	if resume_saved:route_loaded()
func _request_new_run() -> void:
	menu_dialog.hide()
	if controller.save_manager==null:new_run()
	else:confirm_new.popup_centered()
func _save_status(result: SaveLoadResult) -> void:
	if save_label==null:return
	save_label.text="저장됨" if result.ok() else "전투가 끝난 후 저장할 수 있습니다." if result.code==SaveLoadResult.Code.BUSY else "저장 실패 · "+result.detail
func _manual_save() -> void:
	controller.guild.state.tower.map_scroll_y=map_scroll.scroll_vertical
	controller.save_manager.manual_save(controller)
func _main_menu() -> void:
	if controller.save_manager==null:main_menu_requested.emit();return
	if not controller.save_manager.safe(controller):return
	if controller.save_manager.manual_save(controller).ok():main_menu_requested.emit()
func route_loaded() -> void:
	var phase: StringName=controller.guild.state.tower.phase
	if phase in [&"route",&"gameover",&"result"]:
		# A result is already settled. Display stored room status, never settle again.
		show_map()
		if phase==&"result":make_button(body,"정산 완료 · 지도로 계속",func():if controller.return_map():show_map())
	else:_show_selected_room()
func show_notice(text: String) -> void:
	if notice!=null:notice.text=text;notice.modulate=ArenaUI.GOLD;notice.visible=not text.is_empty()
func make_nav_button(parent: Node,kind: String,callback: Callable) -> Button:
	var button:=ArenaUI.nav_button(kind,callback);parent.add_child(button);return button
func make_button(parent: Node,text: String,callback: Callable) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(0,44);var symbol: String={"새 런":"reengrave","탐험 포기":"flag","저장":"save","메인으로":"home"}.get(text,"");
	if not symbol.is_empty():ArenaUI.with_icon(button,symbol)
	ArenaUI.bind(button,callback);parent.add_child(button);return button
func new_run() -> void:
	# Active attempts cannot be disposed via an unrelated navigation button.
	if controller.guild!=null and controller.guild.state.tower.phase in [&"deploy",&"battle",&"event_active"]:return
	if is_instance_valid(battle_screen):remove_child(battle_screen);battle_screen.queue_free();battle_screen=null
	var seed_value: int=Time.get_ticks_usec()
	controller.new_run(seed_value,seed_value^0x35a921)
	show_map()
func show_map() -> void:
	if is_instance_valid(content_screen):remove_child(content_screen);content_screen.queue_free();content_screen=null
	if is_instance_valid(battle_screen):remove_child(battle_screen);battle_screen.queue_free();battle_screen=null
	body.get_parent().show();map_scroll.show()
	var placeholder = body.get_node_or_null("RoomPlaceholder")
	if placeholder != null: body.remove_child(placeholder);placeholder.queue_free()
	var run: RunState=controller.guild.state;var state: TowerRunState=run.tower
	wallet.guild=controller.guild
	if body.find_child("TowerHeading",true,false)!=null:body.find_child("TowerHeading",true,false).text="두니 타워 · 탐험 지도"
	# Prior transactions were already shown in their room. Do not leak raw IDs
	# or prediction enum strings as a permanent footer over the map.
	if notice!=null:notice.hide()
	wallet.text="두니 타워 · %s\n플레이어 HP %.0f / %.0f   🪙 %d   💎 %d   생존 %d/%d"%["게임오버" if run.game_over else "정복 완료" if state.conquered else "탐험 지도",run.player_hp,run.player_max_hp,run.gold,run.tokens,controller.guild.living_members().size(),controller.guild.all_members().size()]
	if last_unlocked>=0 and state.unlocked_floor>last_unlocked:show_notice("새 층 해금 · %d층을 탐험할 수 있습니다."%(state.unlocked_floor+1))
	last_unlocked=state.unlocked_floor
	wallet.text+="\n챕터 %d · 최고 해금 %d층"%[state.current_chapter,state.unlocked_floor+1]
	if run.game_over:show_notice("게임오버 · "+("탐험 포기" if String(state.result)=="abandon" else "플레이어 HP 소진" if run.player_hp<=0 else "생존 길드원 없음"))
	if run.game_over:wallet.text+="\n"+ ("탐험을 포기했습니다." if String(state.result)=="abandon" else "플레이어 HP가 소진되었습니다." if run.player_hp<=0 else "생존 길드원이 없습니다.")
	abandon_button.disabled=run.game_over
	if map_rendered_run==run.run_id and room_buttons.size()==state.map.rooms.size():
		_refresh_map_cards();call_deferred("_restore_scroll");return
	for child in map_scroll.get_children():map_scroll.remove_child(child);child.queue_free()
	room_buttons.clear();floor_widgets.clear();map_rendered_run=run.run_id
	var floors:=VBoxContainer.new();floors.size_flags_horizontal=Control.SIZE_EXPAND_FILL;map_scroll.add_child(floors)
	for floor in state.map.floors:
		var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);floors.add_child(box);box.add_child(HSeparator.new())
		var heading:=HBoxContainer.new();box.add_child(heading)
		var label:=Label.new();label.text="%d층   챕터 %d%s"%[floor.floor_index+1,floor.chapter_index," · 정복 ✓" if floor.conquered else ""];label.add_theme_font_size_override("font_size",14);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(label)
		var conquest_button:=ConquestRewardButton.new();conquest_button.text=("" if floor.unlocked else "잠김 · ")+"층 정복 보상"+(" ✓" if floor.conquered else "");conquest_button.fraction=float(floor.cleared_count)/maxi(1,floor.room_ids.size());ArenaUI.bind(conquest_button,show_reward.bind(floor.floor_index));heading.add_child(conquest_button)
		var scroll:=ScrollContainer.new();scroll.custom_minimum_size.y=104 if get_viewport_rect().size.x<720 else 132;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",5);scroll.add_child(row)
		floor_widgets[floor.floor_index]={"label":label,"conquest":conquest_button}
		for id in floor.room_ids:
			var button:=ArenaCard.new();button.card_type="room";button.toggle_mode=true
			ArenaUI.bind(button,select_room.bind(id));row.add_child(button);room_buttons[id]=button
	_refresh_map_cards()
	call_deferred("_restore_scroll")
func _refresh_map_cards() -> void:
	var run: RunState=controller.guild.state;var state: TowerRunState=run.tower
	var narrow: bool=get_viewport_rect().size.x<720
	for floor in state.map.floors:
		var widgets: Dictionary=floor_widgets[floor.floor_index]
		widgets.label.text="%d층   챕터 %d%s"%[floor.floor_index+1,floor.chapter_index," · 정복 ✓" if floor.conquered else ""]
		widgets.conquest.text=("" if floor.unlocked else "잠김 · ")+"층 정복 보상"+(" ✓" if floor.conquered else "")
		widgets.conquest.fraction=float(floor.cleared_count)/maxi(1,floor.room_ids.size());widgets.conquest.queue_redraw()
		for id in floor.room_ids:
			var room: RoomState=state.map.get_room(id);var button: ArenaCard=room_buttons[id]
			var kind: String=RoomType.LABELS.get(room.visible_kind(),"미탐험")
			if room.discovered and room.room_type==RoomType.EVENT:kind={&"promotion":"승급",&"hotSpring":"온천",&"supply":"보물상자",&"prediction":"전투 예측"}.get(room.event_type,kind)
			var marker: String="잠김" if not floor.unlocked else "✓ 클리어" if room.cleared else "소비 완료" if room.consumed else "방문함" if room.visited else "발견" if room.discovered or room.publicly_visible else "탐험 가능"
			button.text="%d번 방\n%s\n%s"%[room.lane+1,kind,marker];button.title=kind;button.subtitle="%d번 방"%(room.lane+1)
			button.kind=String(room.event_type) if room.discovered and room.room_type==RoomType.EVENT else String(room.visible_kind()) if room.visible_kind()!=&"" else "hidden"
			button.status_text=marker;button.sold=room.cleared;button.spent=room.consumed or room.cleared and RoomType.is_combat(room.room_type)
			button.set_pressed_no_signal(id==state.selected_room_id);button.disabled=not floor.unlocked or run.game_over
			button.modulate=Color(1,1,1,.52) if button.spent else Color(1,1,1,.4) if not floor.unlocked and not room.publicly_visible else Color.WHITE
			button.custom_minimum_size=Vector2(54 if narrow else clampf((get_viewport_rect().size.x-96)/6-10,80,175),100 if narrow else 126)
			button.queue_redraw()
func _restore_scroll() -> void:
	map_scroll.scroll_vertical=controller.guild.state.tower.map_scroll_y
func select_room(id: String) -> void:
	if is_instance_valid(battle_screen) or is_instance_valid(content_screen):return
	controller.guild.state.tower.map_scroll_y=map_scroll.scroll_vertical
	var target: RoomState=controller.guild.state.tower.map.get_room(id)
	var discovered: bool=target!=null and not target.discovered
	var origin: Vector2=room_buttons[id].get_global_rect().get_center() if room_buttons.has(id) else get_viewport_rect().size*.5
	get_tree().root.set_meta("action_point",origin)
	if controller.select_room(id)!=TowerNavigationPolicy.Code.OK:show_notice("지금은 이 방에 들어갈 수 없습니다.");return
	_show_selected_room()
	if discovered and target!=null:
		_update_fx_context()
		fx.enqueue({"kind":"entry","room_id":id,"key":"entry:"+id,"icon":String(target.room_type) if target.room_type!=RoomType.EVENT else String(target.event_type),"title":RoomType.LABELS[target.room_type],"detail":"%d층 · %d번 방"%[target.floor_index+1,target.lane+1]})
		_discovery_flight(id,origin)
func _show_selected_room() -> void:
	if is_instance_valid(battle_screen) or is_instance_valid(content_screen):return
	var room: RoomState=controller.current_room()
	if controller.guild.state.tower.phase==&"deploy":
		body.get_parent().hide()
		battle_screen=TowerBattleScreen.new();battle_screen.tower_controller=controller;add_child(battle_screen);battle_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		battle_screen.map_requested.connect(func():call_deferred("show_map"))
		battle_screen.presentation_requested.connect(_present_content)
		battle_screen.main_menu_requested.connect(_main_menu)
	else:
		body.get_parent().hide()
		content_screen=TowerContentScreen.new();content_screen.controller=controller;add_child(content_screen)
		content_screen.map_requested.connect(func():call_deferred("show_map"))
		content_screen.abandon_requested.connect(func():confirm_abandon.popup_centered())
		content_screen.main_menu_requested.connect(_main_menu)
		content_screen.presentation_requested.connect(_present_content)
func show_reward(depth: int) -> void:
	var floor: FloorState=controller.floor_reward(depth)
	if floor==null:return
	reward_title.text="%d층 정복 보상"%(depth+1);reward_panel.set_floor(floor)
	reward_dialog.popup_centered(Vector2i(mini(390,int(get_viewport_rect().size.x)-28),390))

func _refresh_wallet() -> void:
	wallet.guild=controller.guild
	if body.find_child("TowerHeading",true,false)!=null:body.find_child("TowerHeading",true,false).text="두니 타워 · 탐험 지도"
	wallet.text="두니 타워 · 탐험 지도\n플레이어 HP %.0f / %.0f   🪙 %d   💎 %d   생존 %d/%d"%[controller.guild.state.player_hp,controller.guild.state.player_max_hp,controller.guild.state.gold,controller.guild.state.tokens,controller.guild.living_members().size(),controller.guild.all_members().size()]
func open_guild() -> void:
	if controller.guild.state.tower.phase!=&"route" or controller.guild.state.game_over:return
	guild_panel.show_tab("guild");guild_dialog.popup_centered(Vector2i(mini(700,int(get_viewport_rect().size.x)-24),mini(650,int(get_viewport_rect().size.y)-65)))

func _fit_display() -> void:
	# Tower UI uses the actual window width; the battle board keeps 800 logical units.
	ArenaUI.fit_window(get_window())

func _find_wallet(node: Node) -> WalletBar:
	if node is WalletBar and node.visible:return node
	for child in node.get_children():
		var found: WalletBar=_find_wallet(child)
		if found!=null:return found
	return null
func _current_wallet() -> WalletBar:
	for dialog in [guild_dialog,content_screen.guild_dialog if is_instance_valid(content_screen) else null,battle_screen.management_dialog if is_instance_valid(battle_screen) else null]:
		if is_instance_valid(dialog) and dialog.visible:
			var nested: WalletBar=_find_wallet(dialog)
			if nested!=null:return nested
	if is_instance_valid(battle_screen) and battle_screen.result_overlay.visible:return battle_screen.result_wallet
	return content_screen.wallet if is_instance_valid(content_screen) else battle_screen.room_hud if is_instance_valid(battle_screen) else wallet
func _wallet_point(kind: String) -> Vector2:return _current_wallet().anchor(kind)
func _resource_origin() -> Vector2:
	if is_instance_valid(battle_screen) and is_instance_valid(battle_screen.battle) and not battle_screen.board.editing:return ArenaUI.control_center(battle_screen.board)
	if is_instance_valid(content_screen) and is_instance_valid(content_screen.board):return ArenaUI.control_center(content_screen.board)
	return get_tree().root.get_meta("action_point",get_viewport_rect().size*.5)
func _update_fx_context() -> void:
	if controller.guild==null or fx==null:return
	var state: TowerRunState=controller.guild.state.tower
	fx.context(controller.guild.state.run_id,state.selected_room_id,String(state.phase))
func _process(_dt: float) -> void:
	_update_fx_context()
	if controller.guild==null or fx==null:return
	var run: RunState=controller.guild.state;var state: TowerRunState=run.tower
	if watched_run!=run.run_id:
		watched_run=run.run_id;known_floors.clear();known_chapters=state.chapter_progress.duplicate()
		for floor in state.map.floors:known_floors[floor.floor_index]=floor.conquered
		fx.rebase_wallet(run.gold,run.tokens)
		return
	if is_instance_valid(battle_screen) and battle_screen.end_presenting:return
	if is_instance_valid(content_screen) and is_instance_valid(content_screen.battle) and content_screen.battle.finished and not content_screen.rendered_prediction_finished:return
	fx.sync_wallet(_current_wallet(),_resource_origin())
	for floor in state.map.floors:
		if floor.conquered and not known_floors.get(floor.floor_index,false):
			known_floors[floor.floor_index]=true
			var reward: String={&"heal":"전체 길드 HP +20%",&"tokens":"토큰 +2",&"item":"아이템 획득"}.get(floor.bonus,"")
			fx.enqueue({"kind":"conquest","key":"floor:%d"%floor.floor_index,"title":"%d층 정복"%(floor.floor_index+1),"detail":"플레이어 HP 회복 · 전체 기력 +1\n"+reward,"icon":"crown"})
	for chapter in state.chapter_progress:
		if state.chapter_progress[chapter] and not known_chapters.get(chapter,false):
			known_chapters[chapter]=true;fx.enqueue({"kind":"chapterConquest","key":"chapter:%d"%int(chapter),"title":"%d챕터 정복"%int(chapter),"detail":"보스 격파","icon":"crown"})
func _present_content(event: Dictionary) -> void:
	_update_fx_context()
	var origin: Vector2=event.get("point",_resource_origin())
	fx.sync_wallet(_current_wallet(),origin,event)
	if event.get("kind","") in ["recruit","promotion"]:
		fx.enqueue({"kind":event.kind,"room_id":controller.guild.state.tower.selected_room_id,"key":event.get("key",""),"title":event.title,"type":event.type,"stars":event.get("stars",0),"detail":"길드원 영입" if event.kind=="recruit" else "승급 완료 · 장비 %d칸"%event.get("slots",3),"delay":.5 if event.kind=="recruit" else 0})
	elif event.has("title"):fx.toast(event.title,event.get("icon","event"),event.get("detail",""))

func _discovery_flight(id: String,origin: Vector2) -> void:
	# New room Controls need a container layout pass before their wallet has a rect.
	await get_tree().process_frame
	if fx!=null and controller.guild.state.tower.selected_room_id==id and controller.guild.state.tower.phase!=&"battle":fx.sync_wallet(_current_wallet(),origin)
