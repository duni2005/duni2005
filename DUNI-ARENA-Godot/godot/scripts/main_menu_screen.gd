class_name MainMenuScreen
extends Control
## Minimal entry/continue UI. TowerScreen remains the actual game view.
var save_manager:=SaveManager.new(SaveManager.DEFAULT_PATH,true)
var tower_screen: TowerScreen
var menu: VBoxContainer
var new_button: Button
var continue_button: Button
var status: Label
var menu_margin: MarginContainer
var overwrite_dialog: ConfirmationDialog
func _ready() -> void:
	ArenaUI.install(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().gui_embed_subwindows=true;get_tree().auto_accept_quit=false
	get_window().close_requested.connect(_close)
	var margin:=MarginContainer.new();menu_margin=margin;margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	ArenaUI.safe_margin(margin)
	menu=VBoxContainer.new();margin.add_child(menu);menu.alignment=BoxContainer.ALIGNMENT_CENTER;menu.add_theme_constant_override("separation",12)
	var title:=Label.new();title.text="두니 아레나의 승자가\n망고를 얻을 것이다";title.add_theme_font_size_override("font_size",30);menu.add_child(title)
	var eyebrow:=Label.new();eyebrow.text="DUNI ARENA  /  TOWER";eyebrow.add_theme_color_override("font_color",Color("8fa9c3"));menu.add_child(eyebrow);menu.move_child(eyebrow,0)
	var note:=Label.new();note.text="개별 길드원을 영입하고, 배치하고, 함께 타워를 정복하세요.";note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.add_theme_color_override("font_color",ArenaUI.MUTED);menu.add_child(note)
	new_button=Button.new();new_button.text="새 게임 · 두니 타워 정복  →";new_button.custom_minimum_size.y=48;menu.add_child(new_button);ArenaUI.bind(new_button,_request_new);ArenaUI.primary(new_button)
	continue_button=Button.new();continue_button.text="이어하기";continue_button.custom_minimum_size.y=48;menu.add_child(continue_button);ArenaUI.bind(continue_button,continue_run)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu.add_child(status)
	overwrite_dialog=ConfirmationDialog.new();overwrite_dialog.dialog_text="저장된 탐험을 새 게임으로 교체하겠습니까?";add_child(overwrite_dialog);overwrite_dialog.confirmed.connect(new_game)
	get_window().size_changed.connect(_fit_menu);_fit_menu()
	refresh()
func _fit_menu() -> void:
	var window: Window=get_window()
	var logical: Vector2i=ArenaUI.fit_window(window)
	if menu_margin!=null:
		ArenaUI.safe_margin(menu_margin)
		var inset: int=maxi(12,(logical.x-600)/2)
		menu_margin.add_theme_constant_override("margin_left",inset);menu_margin.add_theme_constant_override("margin_right",inset)
func refresh() -> void:
	continue_button.disabled=true
	_show_metadata(SaveMenuPreview.read(save_manager.path))
	call_deferred("_validate_preview")
func _validate_preview() -> void:
	var saved: SaveLoadResult=save_manager.metadata();continue_button.disabled=not saved.ok()
	_show_metadata(saved)
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
func open_tower(controller: TowerController) -> void:
	menu.get_parent().hide()
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free()
	tower_screen=load("res://scenes/tower.tscn").instantiate();tower_screen.controller=controller;tower_screen.resume_saved=true;add_child(tower_screen)
	tower_screen.main_menu_requested.connect(func():call_deferred("return_menu"))
func return_menu() -> void:
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free();tower_screen=null
	menu.get_parent().show();refresh()
func _close() -> void:
	# Flush already-built safe snapshots; a live battle leaves its checkpoint intact.
	save_manager.flush_autosave();get_tree().quit()
