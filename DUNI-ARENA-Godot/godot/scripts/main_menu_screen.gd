class_name MainMenuScreen
extends Control
## Title screen: tower entry (continue or start), custom battle and settings. TowerScreen remains the actual game view.
var save_manager:=SaveManager.new(SaveManager.DEFAULT_PATH,true)
var tower_screen: TowerScreen
var menu: VBoxContainer
var new_button: Button
var continue_button: Button
var custom_button: Button
var custom_screen: CustomBattleScreen
var status: Label
var menu_margin: MarginContainer
var backdrop: TitleBackdrop
var overwrite_dialog: ConfirmationDialog
var tower_card: PanelContainer
var save_box: PanelContainer
var settings_button: Button
var settings_dialog: AcceptDialog
var version_label: Label
func _ready() -> void:
	ArenaUI.install(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().gui_embed_subwindows=true;get_tree().auto_accept_quit=false
	get_window().close_requested.connect(_close)
	backdrop=TitleBackdrop.new();add_child(backdrop)
	var margin:=MarginContainer.new();menu_margin=margin;margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	ArenaUI.safe_margin(margin)
	menu=VBoxContainer.new();margin.add_child(menu);menu.alignment=BoxContainer.ALIGNMENT_CENTER;menu.add_theme_constant_override("separation",12)
	menu.add_child(TitleLogo.new())
	var title:=Label.new();title.text="두니 아레나의 승자가\n망고를 얻을 것이다";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_override("font",ArenaUI.heading_font());title.add_theme_font_size_override("font_size",22);menu.add_child(title)
	var note:=Label.new();note.text="개별 길드원을 영입하고, 배치하고, 함께 타워를 정복하세요.";note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_color_override("font_color",ArenaUI.MUTED);menu.add_child(note)
	var gap:=Control.new();gap.custom_minimum_size.y=8;menu.add_child(gap)
	# Tower card: one entry. With a save it offers 이어하기 (main) and 새로 시작; without, 두니 타워 오르기 enters at once.
	tower_card=PanelContainer.new();var tower_style: StyleBoxFlat=ArenaUI.box(Color(ArenaUI.PANEL,.9),Color("4a5680"));tower_style.set_corner_radius_all(12)
	for side in ["left","right","top","bottom"]:tower_style.set("content_margin_"+side,14)
	tower_style.shadow_color=Color(0,0,0,.35);tower_style.shadow_size=10;tower_style.shadow_offset=Vector2(0,4);tower_card.add_theme_stylebox_override("panel",tower_style);menu.add_child(tower_card)
	var tower_column:=VBoxContainer.new();tower_column.add_theme_constant_override("separation",10);tower_card.add_child(tower_column)
	var tower_head:=HBoxContainer.new();tower_column.add_child(tower_head)
	var tower_icon:=TextureRect.new();tower_icon.texture=ArenaIcon.texture("crown");tower_icon.custom_minimum_size=Vector2(22,22);tower_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;tower_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;tower_head.add_child(tower_icon)
	var tower_title:=Label.new();tower_title.text="두니 타워";tower_title.add_theme_font_override("font",ArenaUI.heading_font());tower_title.add_theme_font_size_override("font_size",17);tower_title.add_theme_color_override("font_color",ArenaUI.GOLD);tower_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tower_head.add_child(tower_title)
	var tower_meta:=Label.new();tower_meta.text="3챕터 · 15층";tower_meta.add_theme_font_size_override("font_size",11);tower_meta.add_theme_color_override("font_color",ArenaUI.MUTED);tower_head.add_child(tower_meta)
	continue_button=Button.new();continue_button.text="이어하기 · 두니 타워 오르기  →";continue_button.custom_minimum_size.y=56;continue_button.add_theme_font_override("font",ArenaUI.heading_font());continue_button.add_theme_font_size_override("font_size",17);tower_column.add_child(continue_button);ArenaUI.bind(continue_button,continue_run);ArenaUI.primary(continue_button)
	for state in ["normal","hover","pressed"]:continue_button.get_theme_stylebox(state).set_corner_radius_all(10)
	var save_card:=PanelContainer.new();save_box=save_card;var card_style: StyleBoxFlat=ArenaUI.box(Color("101626",.9),Color("2c3756"));card_style.set_corner_radius_all(8);card_style.content_margin_left=12;card_style.content_margin_right=12;card_style.content_margin_top=8;card_style.content_margin_bottom=8;save_card.add_theme_stylebox_override("panel",card_style);tower_column.add_child(save_card)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",12);status.add_theme_color_override("font_color",Color("c9d0e6"));save_card.add_child(status)
	new_button=Button.new();new_button.text="두니 타워 오르기  →";new_button.custom_minimum_size.y=56;new_button.add_theme_font_override("font",ArenaUI.heading_font());new_button.add_theme_font_size_override("font_size",17);tower_column.add_child(new_button);ArenaUI.bind(new_button,_request_new)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);menu.add_child(row)
	custom_button=Button.new();custom_button.text="커스텀 전투 · 자유 배치";custom_button.custom_minimum_size.y=50;custom_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(custom_button);ArenaUI.bind(custom_button,open_custom);ArenaUI.with_icon(custom_button,"battle",18)
	settings_button=Button.new();settings_button.text="설정";settings_button.custom_minimum_size=Vector2(96,50);row.add_child(settings_button);ArenaUI.bind(settings_button,open_settings);ArenaUI.with_icon(settings_button,"settings",18)
	for button in [custom_button,settings_button]:
		for state in ["normal","hover","pressed","hover_pressed"]:
			var style: StyleBoxFlat=ArenaUI.box(Color("1b2338",.92) if state=="normal" else Color("26304c"),Color("4b5a86") if state=="normal" else Color("7f93c8"));style.set_corner_radius_all(10);button.add_theme_stylebox_override(state,style)
	version_label=Label.new();version_label.text="v"+str(ProjectSettings.get_setting("application/config/version","dev"));version_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;version_label.add_theme_font_size_override("font_size",10);version_label.add_theme_color_override("font_color",Color(ArenaUI.MUTED,.6));menu.add_child(version_label)
	_build_settings()
	overwrite_dialog=ConfirmationDialog.new();overwrite_dialog.dialog_text="저장된 탐험을 새 게임으로 교체하겠습니까?";add_child(overwrite_dialog);overwrite_dialog.confirmed.connect(new_game)
	get_window().size_changed.connect(_fit_menu);_fit_menu()
	refresh()
func _fit_menu() -> void:
	var window: Window=get_window()
	var logical: Vector2i=ArenaUI.fit_window(window)
	if menu_margin!=null:
		ArenaUI.safe_margin(menu_margin)
		var inset: int=maxi(16,(logical.x-440)/2)
		menu_margin.add_theme_constant_override("margin_left",inset);menu_margin.add_theme_constant_override("margin_right",inset)
func refresh() -> void:
	continue_button.disabled=true;_layout_tower(SaveMenuPreview.read(save_manager.path).ok())
	_show_metadata(SaveMenuPreview.read(save_manager.path))
	call_deferred("_validate_preview")
func _validate_preview() -> void:
	var saved: SaveLoadResult=save_manager.metadata();continue_button.disabled=not saved.ok()
	_show_metadata(saved);_layout_tower(saved.ok())
## With a save, 이어하기 is the main action and 새로 시작 a quiet second choice; without one the
## single 두니 타워 오르기 button starts at once.
func _layout_tower(has_save: bool) -> void:
	continue_button.visible=has_save;save_box.visible=has_save
	new_button.text="새로 시작" if has_save else "두니 타워 오르기  →";new_button.custom_minimum_size.y=46 if has_save else 56
	if has_save:
		for state in ["normal","hover","pressed","hover_pressed"]:
			var style: StyleBoxFlat=ArenaUI.box(Color("141b2d",.9) if state=="normal" else Color("1f2840"),Color("3c4870"));style.set_corner_radius_all(10);new_button.add_theme_stylebox_override(state,style)
		for name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:new_button.add_theme_color_override(name,Color("c9d0e6"))
		new_button.add_theme_font_size_override("font_size",14)
	else:
		ArenaUI.primary(new_button);new_button.add_theme_font_size_override("font_size",17)
		for state in ["normal","hover","pressed"]:new_button.get_theme_stylebox(state).set_corner_radius_all(10)
	continue_button.set_meta("primary_cta",has_save);new_button.set_meta("primary_cta",not has_save)
	UiMotion.calm(continue_button if not has_save else new_button);UiMotion.breathe(continue_button if has_save else new_button)
func _show_metadata(saved: SaveLoadResult) -> void:
	if saved.ok():
		var m: Dictionary=saved.metadata
		var phases: Dictionary={"route":"탐험 지도","deploy":"전투 전 배치","gameover":"종료된 탐험","result":"정산 완료","content_result":"이벤트 결과","event_active":"이벤트","shop":"상점","recruit":"길드원 모집","rest":"휴식소","battle_checkpoint":"전투 시작 전","cleared":"클리어"}
		status.text="챕터 %d · %d층 · %s\n플레이어 HP %.0f   골드 %d   토큰 %d\n길드원 %d명 · 생존 %d명%s%s"%[m.chapter,m.floor,phases.get(m.phase,"탐험"),m.player_hp,m.gold,m.tokens,m.guild_count,m.living_guild_count,"\n타워 정복 완료" if m.tower_conquered else "","\n백업에서 복구할 수 있습니다." if saved.from_backup else ""]
		status.text += "\n마지막 저장 · " + Time.get_datetime_string_from_unix_time(int(m.timestamp)).replace("T"," ") + " UTC"
	else:status.text="저장된 탐험이 없습니다." if saved.code==SaveLoadResult.Code.FILE_NOT_FOUND else "저장을 읽을 수 없습니다 · "+SaveLoadResult.Code.keys()[saved.code]
func _request_new() -> void:
	if FileAccess.file_exists(save_manager.path) or FileAccess.file_exists(save_manager.path+".backup"):overwrite_dialog.popup_centered()
	else:new_game()
func new_game() -> void:
	if is_instance_valid(tower_screen):return
	var controller:=TowerController.new();save_manager.attach(controller)
	var seed_value: int=Time.get_ticks_usec()
	if not controller.new_run(seed_value,seed_value^0x35a921):return
	if not save_manager.flush_autosave().ok():status.text="새 게임 저장 실패 · "+save_manager.last_result.detail;return
	open_tower(controller)
func continue_run() -> void:
	if is_instance_valid(tower_screen):return
	var loaded: SaveLoadResult=save_manager.load_controller()
	if not loaded.ok():status.text="이어하기 실패 · "+loaded.detail;continue_button.disabled=true;return
	open_tower(loaded.controller)
	if loaded.from_backup:tower_screen.show_notice("이전 정상 저장에서 복구했습니다.")
func open_custom() -> void:
	if is_instance_valid(custom_screen) or is_instance_valid(tower_screen):return
	UiTransition.play("forward")
	menu.get_parent().hide();backdrop.hide()
	custom_screen=CustomBattleScreen.new();add_child(custom_screen)
	custom_screen.closed.connect(func():call_deferred("close_custom"))
func close_custom() -> void:
	UiTransition.play("back")
	if is_instance_valid(custom_screen):remove_child(custom_screen);custom_screen.queue_free();custom_screen=null
	menu.get_parent().show();backdrop.show()
func open_tower(controller: TowerController) -> void:
	UiTransition.play("forward")
	menu.get_parent().hide();backdrop.hide()
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free()
	tower_screen=load("res://scenes/tower.tscn").instantiate();tower_screen.controller=controller;tower_screen.resume_saved=true;add_child(tower_screen)
	tower_screen.main_menu_requested.connect(func():call_deferred("return_menu"))
func return_menu() -> void:
	UiTransition.play("back")
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free();tower_screen=null
	menu.get_parent().show();backdrop.show();refresh()
func _build_settings() -> void:
	settings_dialog=AcceptDialog.new();settings_dialog.title="설정";settings_dialog.get_ok_button().text="닫기";add_child(settings_dialog);ArenaModalBackdrop.new().connect_window(settings_dialog,self)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);column.custom_minimum_size.x=280;settings_dialog.add_child(column);ArenaUI.dialog_header(settings_dialog,column,"설정")
	for row in [["vibration","진동","버튼을 누를 때 짧게 진동합니다."],["motion","UI 애니메이션","화면 전환과 등장 연출을 켭니다."],["shake","화면 흔들림","전투 타격 시 화면이 흔들립니다."]]:
		var line:=HBoxContainer.new();column.add_child(line)
		var texts:=VBoxContainer.new();texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;texts.add_theme_constant_override("separation",0);line.add_child(texts)
		var label:=Label.new();label.text=row[1];texts.add_child(label)
		var hint:=Label.new();hint.text=row[2];hint.add_theme_font_size_override("font_size",11);hint.add_theme_color_override("font_color",ArenaUI.MUTED);texts.add_child(hint)
		var toggle:=CheckButton.new();toggle.name=row[0];toggle.button_pressed=GameSettings.value(row[0]);line.add_child(toggle)
		toggle.toggled.connect(func(on: bool):GameSettings.set_value(row[0],on))
	var about:=Label.new();about.text="DUNI ARENA · v"+str(ProjectSettings.get_setting("application/config/version","dev"));about.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;about.add_theme_font_size_override("font_size",11);about.add_theme_color_override("font_color",ArenaUI.MUTED);column.add_child(about)
func open_settings() -> void:
	settings_dialog.popup_centered(Vector2i(mini(360,int(get_viewport_rect().size.x)-28),0))
func _close() -> void:
	# Flush already-built safe snapshots; a live battle leaves its checkpoint intact.
	save_manager.flush_autosave();get_tree().quit()
