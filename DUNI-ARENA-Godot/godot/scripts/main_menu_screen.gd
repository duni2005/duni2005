class_name MainMenuScreen
extends Control
## Title screen over a layered landscape with the distant tower: the DUNI ARENA wordmark and four
## buttons (타워 입장 / 커스텀 전투 / 도감 / 설정). With a save, 타워 입장 opens a window to continue or
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
var prediction_button: Button
var prediction_screen: PredictionModeScreen
var status: Label
var menu_margin: MarginContainer
var scenery: TitleScenery
var tower_dialog: AcceptDialog
var overwrite_dialog: ConfirmationDialog
var settings_button: Button
var codex_button: Button
var codex_screen: CodexScreen
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
	var top:=Control.new();top.custom_minimum_size.y=72;menu.add_child(top)
	menu.add_child(_wordmark())
	# The buttons sit about two thirds of the way down, clear of the bottom edge.
	var open:=Control.new();open.size_flags_vertical=Control.SIZE_EXPAND_FILL;open.size_flags_stretch_ratio=2.6;menu.add_child(open)
	tower_button=_menu_button("타워 입장","crown",enter_tower,true)
	custom_button=_menu_button("커스텀 전투","battle",open_custom,false)
	prediction_button=_menu_button("전투 예측","prediction",open_prediction,false)
	codex_button=_menu_button("도감","book",open_codex,false)
	settings_button=_menu_button("설정","settings",open_settings,false)
	var below:=Control.new();below.size_flags_vertical=Control.SIZE_EXPAND_FILL;menu.add_child(below)
	version_label=Label.new();version_label.text="v"+str(ProjectSettings.get_setting("application/config/version","dev"));version_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;version_label.add_theme_font_size_override("font_size",10);version_label.add_theme_color_override("font_color",Color(1,1,1,.55));menu.add_child(version_label)
	_build_tower_dialog()
	_build_settings()
	overwrite_dialog=ConfirmationDialog.new();overwrite_dialog.title="새로하기";overwrite_dialog.dialog_text="저장된 탐험을 새 게임으로 교체하겠습니까?";add_child(overwrite_dialog);overwrite_dialog.confirmed.connect(new_game)
	get_window().size_changed.connect(_fit_menu);_fit_menu()
	refresh()
	if not splash_shown and get_tree().current_scene==self and DisplayServer.get_name()!="headless":
		splash_shown=true;scenery.entry=0;menu.modulate.a=0
		var splash:=SplashOverlay.new();add_child(splash);splash.fading.connect(_reveal)
	else:_reveal()
## "DUNI ARENA" in the condensed display font, ARENA in the accent colour, a slim outline and a
## soft shadow, with a thin gold rule and diamond underneath.
func _wordmark() -> VBoxContainer:
	var lockup:=VBoxContainer.new();lockup.add_theme_constant_override("separation",2)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",10);lockup.add_child(row)
	for part in [["DUNI",Color("f4f6ff")],["ARENA",Color("ffb867")]]:
		var label:=Label.new();label.text=part[0];label.add_theme_font_override("font",ArenaUI.numbers_font());label.add_theme_font_size_override("font_size",54)
		label.add_theme_color_override("font_color",part[1]);label.add_theme_color_override("font_outline_color",Color("13213d"));label.add_theme_constant_override("outline_size",7)
		label.add_theme_color_override("font_shadow_color",Color(.02,.05,.14,.32));label.add_theme_constant_override("shadow_offset_y",4);label.add_theme_constant_override("shadow_offset_x",0);label.add_theme_constant_override("shadow_outline_size",7)
		row.add_child(label)
	var rule:=Control.new();rule.custom_minimum_size.y=12;rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;lockup.add_child(rule)
	rule.draw.connect(func():
		var c:=Vector2(rule.size.x*.5,rule.size.y*.5);var reach: float=minf(120,rule.size.x*.36)
		for side in [-1,1]:rule.draw_line(c+Vector2(side*9,0),c+Vector2(side*reach,0),Color(ArenaUI.GOLD,.85),1.5,true)
		rule.draw_colored_polygon(PackedVector2Array([c+Vector2(0,-5),c+Vector2(5,0),c+Vector2(0,5),c+Vector2(-5,0)]),ArenaUI.GOLD))
	return lockup
func _menu_button(text: String,icon: String,callback: Callable,primary: bool) -> Button:
	var button:=Button.new();button.text=text;button.custom_minimum_size.y=48;button.add_theme_font_override("font",ArenaUI.heading_font());button.add_theme_font_size_override("font_size",16)
	ArenaUI.with_icon(button,icon,18);menu.add_child(button);ArenaUI.bind(button,callback)
	if primary:
		ArenaUI.primary(button)
	else:ArenaUI.style_button(button,Color("1b2644",.94))
	return button
## Continue / start over, shown when 타워 입장 finds a save.
func _build_tower_dialog() -> void:
	tower_dialog=AcceptDialog.new();tower_dialog.title="두니 타워";tower_dialog.get_ok_button().text="닫기";add_child(tower_dialog);ArenaModalBackdrop.new().connect_window(tower_dialog,self)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);column.custom_minimum_size.x=290;tower_dialog.add_child(column);ArenaUI.dialog_header(tower_dialog,column,"두니 타워")
	var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",ArenaUI.card_style());column.add_child(card)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status.add_theme_font_size_override("font_size",12);status.add_theme_color_override("font_color",Color("c9d0e6"));status.custom_minimum_size.x=264;card.add_child(status)
	continue_button=Button.new();continue_button.text="이어하기";continue_button.custom_minimum_size.y=54;continue_button.add_theme_font_override("font",ArenaUI.heading_font());continue_button.add_theme_font_size_override("font_size",17);column.add_child(continue_button);ArenaUI.bind(continue_button,continue_run);ArenaUI.primary(continue_button)
	new_button=Button.new();new_button.text="새로하기";new_button.custom_minimum_size.y=48;new_button.add_theme_font_size_override("font_size",15);column.add_child(new_button);ArenaUI.bind(new_button,_request_new)
func _fit_menu() -> void:
	var window: Window=get_window()
	var logical: Vector2i=ArenaUI.fit_window(window)
	if menu_margin!=null:
		ArenaUI.safe_margin(menu_margin)
		# Portrait: a centred column. Wide screens move it to the left so the tower stays clear.
		var inset: int=maxi(36,(logical.x-300)/2)
		var left: int=inset if logical.x<=logical.y else maxi(24,logical.x/16)
		menu_margin.add_theme_constant_override("margin_left",left);menu_margin.add_theme_constant_override("margin_right",maxi(36,logical.x-left-300))
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
func has_save() -> bool:
	if not (FileAccess.file_exists(save_manager.path) or FileAccess.file_exists(save_manager.path+".backup")):return false
	# A failed run has nothing to continue: its save is cleared the first time the menu looks.
	var header: SaveLoadResult=SaveMenuPreview.read(save_manager.path)
	if header.ok() and String(header.metadata.get("phase",""))=="gameover":save_manager.discard();return false
	return true
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
## The camera dives into the tower, a loading screen covers the hand-over, then the run opens
## (all at once without UI motion). The tower theme starts from the top on each entry.
func _dive_into(controller: TowerController,notice: String="") -> void:
	tower_dialog.hide();overwrite_dialog.hide()
	var open:=func():
		BackgroundMusic.reset(&"tower")
		LoadingScreen.run(self,func():
			open_tower(controller)
			if not notice.is_empty():tower_screen.show_notice(notice))
	if not UiMotion.enabled:open.call();return
	_set_menu_disabled(true)
	create_tween().tween_property(menu,"modulate:a",0.0,.3)
	scenery.dive_finished.connect(open,CONNECT_ONE_SHOT);scenery.play_dive()
func _set_menu_disabled(on: bool) -> void:
	for button in [tower_button,custom_button,prediction_button,codex_button,settings_button]:button.disabled=on
func open_custom() -> void:
	if is_instance_valid(custom_screen) or is_instance_valid(prediction_screen) or is_instance_valid(tower_screen):return
	_set_menu_disabled(true)
	LoadingScreen.run(self,func():
		menu.get_parent().hide();scenery.hide();_set_menu_disabled(false)
		custom_screen=CustomBattleScreen.new();add_child(custom_screen)
		custom_screen.closed.connect(func():call_deferred("close_custom"))
		BackgroundMusic.play(&"battle"))
## 전투 예측: random AI battles to call, with a reroll before each one.
func open_prediction() -> void:
	if is_instance_valid(custom_screen) or is_instance_valid(prediction_screen) or is_instance_valid(tower_screen):return
	_set_menu_disabled(true)
	LoadingScreen.run(self,func():
		menu.get_parent().hide();scenery.hide();_set_menu_disabled(false)
		prediction_screen=PredictionModeScreen.new();add_child(prediction_screen)
		prediction_screen.closed.connect(func():call_deferred("close_prediction"))
		BackgroundMusic.play(&"battle"))
func close_prediction() -> void:
	UiTransition.play("back",TypeArt.word(&"menu"));BackgroundMusic.play(&"menu")
	if is_instance_valid(prediction_screen):remove_child(prediction_screen);prediction_screen.queue_free();prediction_screen=null
	menu.get_parent().show();scenery.show();_reveal()
## 도감: a full page over the title screen.
func open_codex() -> void:
	if is_instance_valid(codex_screen) or is_instance_valid(custom_screen) or is_instance_valid(prediction_screen) or is_instance_valid(tower_screen):return
	UiTransition.play("forward","CODEX");menu.get_parent().hide();scenery.hide()
	codex_screen=CodexScreen.new();add_child(codex_screen);codex_screen.closed.connect(func():call_deferred("close_codex"))
func close_codex() -> void:
	UiTransition.play("back",TypeArt.word(&"menu"))
	if is_instance_valid(codex_screen):remove_child(codex_screen);codex_screen.queue_free();codex_screen=null
	menu.get_parent().show();scenery.show();_reveal()
func close_custom() -> void:
	UiTransition.play("back",TypeArt.word(&"menu"));BackgroundMusic.play(&"menu")
	if is_instance_valid(custom_screen):remove_child(custom_screen);custom_screen.queue_free();custom_screen=null
	menu.get_parent().show();scenery.show();_reveal()
func open_tower(controller: TowerController) -> void:
	UiTransition.play("forward",TypeArt.word(&"tower"));BackgroundMusic.play(&"tower")
	menu.get_parent().hide();scenery.hide()
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free()
	tower_screen=load("res://scenes/tower.tscn").instantiate();tower_screen.controller=controller;tower_screen.resume_saved=true;add_child(tower_screen)
	tower_screen.main_menu_requested.connect(func():call_deferred("return_menu"))
func return_menu() -> void:
	UiTransition.play("back",TypeArt.word(&"menu"));BackgroundMusic.play(&"menu")
	if is_instance_valid(tower_screen):remove_child(tower_screen);tower_screen.queue_free();tower_screen=null
	menu.get_parent().show();scenery.show();_set_menu_disabled(false);refresh();_reveal()
## 설정 window: 게임플레이 / 그래픽 / 소리 tabs. Every change is saved at once (GameSettings).
var settings_pages: Dictionary = {}
var settings_tabs: Dictionary = {}
const SETTINGS_TABS = [["gameplay","게임플레이"],["graphics","그래픽"],["sound","소리"]]
func _build_settings() -> void:
	settings_dialog=AcceptDialog.new();settings_dialog.title="설정";settings_dialog.get_ok_button().text="닫기";add_child(settings_dialog);ArenaModalBackdrop.new().connect_window(settings_dialog,self)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);column.custom_minimum_size.x=290;settings_dialog.add_child(column);ArenaUI.dialog_header(settings_dialog,column,"설정")
	var tabs:=HBoxContainer.new();tabs.add_theme_constant_override("separation",6);column.add_child(tabs)
	for pair in SETTINGS_TABS:
		var b:=Button.new();b.name="Tab_"+pair[0];b.text=pair[1];b.toggle_mode=true;b.custom_minimum_size.y=36;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ArenaUI.tab(b)
		b.pressed.connect(show_settings_tab.bind(pair[0]));tabs.add_child(b);settings_tabs[pair[0]]=b
		var page:=VBoxContainer.new();page.name="Page_"+pair[0];page.add_theme_constant_override("separation",12);page.custom_minimum_size.y=200;column.add_child(page);settings_pages[pair[0]]=page
	var play: VBoxContainer=settings_pages.gameplay
	play.add_child(_toggle_row("vibration","진동","버튼을 누를 때 짧게 진동합니다."))
	play.add_child(_choice_row("shake_level","화면 흔들림","타격과 연출 때 화면이 흔들리는 세기.",GameSettings.SHAKE_LEVELS,[0,1,2,3]))
	play.add_child(_toggle_row("damage_numbers","피해량 표시","전투 중 피해 숫자를 띄웁니다. 회복 숫자는 항상 보입니다."))
	play.add_child(_toggle_row("motion","UI 애니메이션","화면 전환과 등장 연출을 켭니다."))
	var gfx: VBoxContainer=settings_pages.graphics
	gfx.add_child(_choice_row("fps_limit","프레임 제한","낮추면 배터리와 발열이 줄어듭니다.",["30","60","무제한"],GameSettings.FPS_CHOICES))
	gfx.add_child(_choice_row("particles","파티클 품질","낮추면 이펙트 입자가 줄어 가벼워집니다.",GameSettings.PARTICLE_LEVELS,[0,1,2]))
	gfx.add_child(_toggle_row("shader_effects","셰이더 이펙트","끄면 충격파 · 불길 · 번개를 단순한 도형으로 그립니다."))
	var snd: VBoxContainer=settings_pages.sound
	for row in [["master","마스터 볼륨"],["music","배경음악"],["sfx","효과음"]]:snd.add_child(_volume_row(row[0],row[1]))
	var about:=Label.new();about.text="DUNI ARENA · v"+str(ProjectSettings.get_setting("application/config/version","dev"));about.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;about.add_theme_font_size_override("font_size",11);about.add_theme_color_override("font_color",ArenaUI.MUTED);column.add_child(about)
	show_settings_tab("gameplay")
func show_settings_tab(key: String) -> void:
	for k in settings_pages:settings_pages[k].visible=k==key;settings_tabs[k].set_pressed_no_signal(k==key)
func _setting_texts(title: String,hint: String) -> VBoxContainer:
	var texts:=VBoxContainer.new();texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;texts.add_theme_constant_override("separation",0)
	var label:=Label.new();label.text=title;texts.add_child(label)
	if not hint.is_empty():
		var small:=Label.new();small.text=hint;small.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;small.custom_minimum_size.x=200;small.add_theme_font_size_override("font_size",11);small.add_theme_color_override("font_color",ArenaUI.MUTED);texts.add_child(small)
	return texts
func _toggle_row(key: String,title: String,hint: String) -> Control:
	var line:=HBoxContainer.new();line.add_child(_setting_texts(title,hint))
	var toggle:=CheckButton.new();toggle.name=key;toggle.button_pressed=GameSettings.value(key);line.add_child(toggle)
	toggle.toggled.connect(func(on: bool):GameSettings.set_value(key,on))
	return line
## A label and a row of segmented choices (화면 흔들림, 프레임 제한, 파티클 품질).
func _choice_row(key: String,title: String,hint: String,labels: Array,values: Array) -> Control:
	var box:=VBoxContainer.new();box.name=key;box.add_theme_constant_override("separation",6);box.add_child(_setting_texts(title,hint))
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",4);box.add_child(row)
	var buttons: Array[Button]=[]
	for i in range(labels.size()):
		var b:=Button.new();b.text=labels[i];b.toggle_mode=true;b.custom_minimum_size.y=34;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.add_theme_font_size_override("font_size",12);ArenaUI.tab(b)
		b.set_pressed_no_signal(GameSettings.value(key)==values[i]);row.add_child(b);buttons.append(b)
		var v=values[i]
		b.pressed.connect(func():
			GameSettings.set_value(key,v)
			for other in buttons:other.set_pressed_no_signal(other==b))
	return box
## A volume slider with its percentage.
func _volume_row(key: String,title: String) -> Control:
	var box:=VBoxContainer.new();box.name=key;box.add_theme_constant_override("separation",4)
	var head:=HBoxContainer.new();box.add_child(head);head.add_child(_setting_texts(title,""))
	var amount:=Label.new();amount.text="%d%%"%roundi(float(GameSettings.value(key))*100);amount.add_theme_font_override("font",ArenaUI.numbers_font());amount.add_theme_color_override("font_color",ArenaUI.GOLD);head.add_child(amount)
	var slider:=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=5;slider.value=roundi(float(GameSettings.value(key))*100);slider.custom_minimum_size.y=32;box.add_child(slider)
	slider.value_changed.connect(func(v: float):amount.text="%d%%"%roundi(v);GameSettings.set_value(key,v/100.0))
	return box
func open_settings() -> void:
	settings_dialog.popup_centered(Vector2i(mini(360,int(get_viewport_rect().size.x)-28),0))
func _close() -> void:
	# Flush already-built safe snapshots; a live battle leaves its checkpoint intact.
	save_manager.flush_autosave();get_tree().quit()
