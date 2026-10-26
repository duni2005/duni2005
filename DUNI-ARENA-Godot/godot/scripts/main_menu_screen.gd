class_name MainMenuScreen
extends Control
## Title screen over a layered landscape with the distant tower: the DUNI ARENA wordmark and three
## buttons (타워 입장 / 커스텀 전투 / 설정). With a save, 타워 입장 opens a window to continue or
## start over; without one it starts at once. Entering the tower dives the camera into it.
## TowerScreen remains the actual game view.
var save_manager:=SaveManager.new(SaveManager.DEFAULT_PATH,true)
var tower_screen: TowerScreen
var menu: VBoxContainer
var tower_button: Button
var new_button: Button
var continue_button: Button
var custom_button: Button
var custom_screen: CustomBattleScreen
var status: Label
var menu_margin: MarginContainer
var scenery: TitleScenery
var tower_dialog: AcceptDialog
var overwrite_dialog: ConfirmationDialog
var settings_button: Button
var settings_dialog: AcceptDialog
var version_label: Label
## The logo screen plays once, when the app starts on this scene.
static var splash_shown: bool=false
func _ready() -> void:
	ArenaUI.install(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().gui_embed_subwindows=true;get_tree().auto_accept_quit=false
	BackgroundMusic.play(&"menu")
	get_window().close_requested.connect(_close)
	scenery=TitleScenery.new();add_child(scenery)
	var margin:=MarginContainer.new();menu_margin=margin;margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	ArenaUI.safe_margin(margin)
	menu=VBoxContainer.new();margin.add_child(menu);menu.add_theme_constant_override("separation",12)
	var top:=Control.new();top.custom_minimum_size.y=28;menu.add_child(top)
	menu.add_child(_wordmark())
	var open:=Control.new();open.size_flags_vertical=Control.SIZE_EXPAND_FILL;menu.add_child(open)
	tower_button=_menu_button("타워 입장","crown",enter_tower,true)
	custom_button=_menu_button("커스텀 전투","battle",open_custom,false)
	settings_button=_menu_button("설정","settings",open_settings,false)
	version_label=Label.new();version_label.text="v"+str(ProjectSettings.get_setting("application/config/version","dev"));version_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;version_label.add_theme_font_size_override("font_size",10);version_label.add_theme_color_override("font_color",Color(1,1,1,.55));menu.add_child(version_label)
	_build_tower_dialog()
	_build_settings()
	overwrite_dialog=ConfirmationDialog.new();overwrite_dialog.dialog_text="저장된 탐험을 새 게임으로 교체하겠습니까?";add_child(overwrite_dialog);overwrite_dialog.confirmed.connect(new_game)
	get_window().size_changed.connect(_fit_menu);_fit_menu()
	refresh()
	if not splash_shown and get_tree().current_scene==self and DisplayServer.get_name()!="headless":
		splash_shown=true;scenery.entry=0;menu.modulate.a=0
		var splash:=SplashOverlay.new();add_child(splash);splash.fading.connect(_reveal)
	else:_reveal()
## "DUNI ARENA" in the condensed display font, ARENA in the accent colour.
func _wordmark() -> HBoxContainer:
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",14)
	for part in [["DUNI",Color("f4f6ff")],["ARENA",ArenaUI.ACCENT]]:
		var label:=Label.new();label.text=part[0];label.add_theme_font_override("font",ArenaUI.numbers_font());label.add_theme_font_size_override("font_size",68)
		label.add_theme_color_override("font_color",part[1]);label.add_theme_color_override("font_outline_color",Color("10203a"));label.add_theme_constant_override("outline_size",12)
		label.add_theme_color_override("font_shadow_color",Color(0,0,0,.35));label.add_theme_constant_override("shadow_offset_y",5);label.add_theme_constant_override("shadow_offset_x",0)
		row.add_child(label)
	return row
func _menu_button(text: String,icon: String,callback: Callable,primary: bool) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=58;button.add_theme_font_override("font",ArenaUI.heading_font());button.add_theme_font_size_override("font_size",18)
	ArenaUI.with_icon(button,icon,20);menu.add_child(button);ArenaUI.bind(button,callback)
	if primary:
		ArenaUI.primary(button)
		for state in ["normal","hover","pressed"]:button.get_theme_stylebox(state).set_corner_radius_all(12)
	else:
		for state in ["normal","hover","pressed","hover_pressed"]:
			var style: StyleBoxFlat=ArenaUI.box(Color("101a2c",.82) if state=="normal" else Color("1d2a46",.9),Color(1,1,1,.28) if state=="normal" else Color(1,1,1,.5));style.set_corner_radius_all(12);button.add_theme_stylebox_override(state,style)
		button.add_theme_color_override("font_color",Color("eef2ff"))
	return button
## Continue / start over, shown when 타워 입장 finds a save.
func _build_tower_dialog() -> void:
	tower_dialog=AcceptDialog.new();tower_dialog.title="두니 타워";tower_dialog.get_ok_button().text="닫기";add_child(tower_dialog);ArenaModalBackdrop.new().connect_window(tower_dialog,self)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);column.custom_minimum_size.x=290;tower_dialog.add_child(column);ArenaUI.dialog_header(tower_dialog,column,"두니 타워")
	var card:=PanelContainer.new();var card_style: StyleBoxFlat=ArenaUI.box(Color("101626",.9),Color("2c3756"));card_style.set_corner_radius_all(8);card_style.content_margin_left=12;card_style.content_margin_right=12;card_style.content_margin_top=8;card_style.content_margin_bottom=8;card.add_theme_stylebox_override("panel",card_style);column.add_child(card)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",12);status.add_theme_color_override("font_color",Color("c9d0e6"));status.custom_minimum_size.x=264;card.add_child(status)
	continue_button=Button.new();continue_button.text="이어하기";continue_button.custom_minimum_size.y=54;continue_button.add_theme_font_override("font",ArenaUI.heading_font());continue_button.add_theme_font_size_override("font_size",17);column.add_child(continue_button);ArenaUI.bind(continue_button,continue_run);ArenaUI.primary(continue_button)
	new_button=Button.new();new_button.text="새로하기";new_button.custom_minimum_size.y=48;new_button.add_theme_font_size_override("font_size",15);column.add_child(new_button);ArenaUI.bind(new_button,_request_new)
func _fit_menu() -> void:
	var window: Window=get_window()
	var logical: Vector2i=ArenaUI.fit_window(window)
	if menu_margin!=null:
		ArenaUI.safe_margin(menu_margin)
		# Portrait: a centred column. Wide screens move it to the left so the tower stays clear.
		var inset: int=maxi(24,(logical.x-340)/2)
		var left: int=inset if logical.x<=logical.y else maxi(24,logical.x/16)
		menu_margin.add_theme_constant_override("margin_left",left);menu_margin.add_theme_constant_override("margin_right",maxi(24,logical.x-left-340))
## Scenery rises in and the menu fades in after it.
func _reveal() -> void:
	scenery.play_entry()
	if not UiMotion.enabled:menu.modulate.a=1;return
	menu.modulate.a=0;var t:=create_tween();t.tween_interval(.9);t.tween_property(menu,"modulate:a",1.0,.6)
func refresh() -> void:
	continue_button.disabled=true
	_show_metadata(SaveMenuPreview.read(save_manager.path))
	call_deferred("_validate_preview")
func _validate_preview() -> void:
	var saved: SaveLoadResult=save_manager.metadata();continue_button.disabled=not saved.ok()
	_show_metadata(saved)
func has_save() -> bool:return FileAccess.file_exists(save_manager.path) or FileAccess.file_exists(save_manager.path+".backup")
func enter_tower() -> void:
	if is_instance_valid(tower_screen):return
	if has_save():refresh();tower_dialog.popup_centered(Vector2i(mini(360,int(get_viewport_rect().size.x)-28),0))
	else:new_game()
func _show_metadata(saved: SaveLoadResult) -> void:
	if saved.ok():
		var m: Dictionary=saved.metadata
		var phases: Dictionary={"route":"탐험 지도","deploy":"전투 전 배치","gameover":"종료된 탐험","result":"정산 완료","content_result":"이벤트 결과","event_active":"이벤트","shop":"상점","recruit":"길드원 모집","rest":"휴식소","battle_checkpoint":"전투 시작 전","cleared":"클리어"}
		status.text="챕터 %d · %d층 · %s\n플레이어 HP %.0f   골드 %d   토큰 %d\n길드원 %d명 · 생존 %d명%s%s"%[m.chapter,m.floor,phases.get(m.phase,"탐험"),m.player_hp,m.gold,m.tokens,m.guild_count,m.living_guild_count,"\n타워 정복 완료" if m.tower_conquered else "","\n백업에서 복구할 수 있습니다." if saved.from_backup else ""]
		status.text += "\n마지막 저장 · " + Time.get_datetime_string_from_unix_time(int(m.timestamp)).replace("T"," ") + " UTC"
	else:status.text="저장된 탐험이 없습니다." if saved.code==SaveLoadResult.Code.FILE_NOT_FOUND else "저장을 읽을 수 없습니다 · "+SaveLoadResult.Code.keys()[saved.code]
func _request_new() -> void:
	if has_save():overwrite_dialog.popup_centered()
	else:new_game()
func new_game() -> void:
	if is_instance_valid(tower_screen):return
	var controller:=TowerController.new();save_manager.attach(controller)
	var seed_value: int=Time.get_ticks_usec()
	if not controller.new_run(seed_value,seed_value^0x35a921):return
	if not save_manager.flush_autosave().ok():status.text="새 게임 저장 실패 · "+save_manager.last_result.detail;tower_dialog.popup_centered();return
	_dive_into(controller)
func continue_run() -> void:
	if is_instance_valid(tower_screen):return
	var loaded: SaveLoadResult=save_manager.load_controller()
	if not loaded.ok():status.text="이어하기 실패 · "+loaded.detail;continue_button.disabled=true;return
	_dive_into(loaded.controller,"이전 정상 저장에서 복구했습니다." if loaded.from_backup else "")
## The camera dives into the tower, then the run opens (at once without UI motion).
func _dive_into(controller: TowerController,notice: String="") -> void:
	tower_dialog.hide();overwrite_dialog.hide()
	var open:=func():
		open_tower(controller)
		if not notice.is_empty():tower_screen.show_notice(notice)
	if not UiMotion.enabled:open.call();return
	_set_menu_disabled(true)
	create_tween().tween_property(menu,"modulate:a",0.0,.3)
	scenery.dive_finished.connect(open,CONNECT_ONE_SHOT);scenery.play_dive()
func _set_menu_disabled(on: bool) -> void:
	for button in [tower_button,custom_button,settings_button]:button.disabled=on
func open_custom() -> void:
	if is_instance_valid(custom_screen) or is_instance_valid(tower_screen):return
	UiTransition.play("forward")
	menu.get_parent().hide();scenery.hide()
	custom_screen=CustomBattleScreen.new();add_child(custom_screen)
	custom_screen.closed.connect(func():call_deferred("close_custom"))
func close_custom() -> void:
	UiTransition.play("back")
	if is_instance_valid(custom_screen):remove_child(custom_screen);custom_screen.queue_free();custom_screen=null
	menu.get_parent().show();scenery.show();_reveal()
func open_tower(controller: TowerController) -> void:
	UiTransition.play("forward");BackgroundMusic.play(&"tower")
	menu.get_parent().hide();scenery.hide()
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free()
	tower_screen=load("res://scenes/tower.tscn").instantiate();tower_screen.controller=controller;tower_screen.resume_saved=true;add_child(tower_screen)
	tower_screen.main_menu_requested.connect(func():call_deferred("return_menu"))
func return_menu() -> void:
	UiTransition.play("back");BackgroundMusic.play(&"menu")
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free();tower_screen=null
	menu.get_parent().show();scenery.show();_set_menu_disabled(false);refresh();_reveal()
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
