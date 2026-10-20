class_name CustomBattleScreen
extends Control
## Custom battle (web "커스텀 전투"): free placement of any character for up to four teams or
## free-for-all, per-unit stance and items, then a full battle where every unit can use
## transcendence. No run, gold or save is touched.
signal closed
var setup := CustomBattleSetup.new()
var battle: BattleManager
var board: CustomBattleBoard
var selected_type: int = -1
var selected_team: int = 0
var erasing: bool = false
var trans_press: Dictionary = {}
var watch_paused: bool = false
var unit_id: int = -1
var unit_tab: String = "stance"
var item_choice: StringName = &""
var title_label: Label
var cost_row: HBoxContainer
var setup_controls: VBoxContainer
var team_buttons: Dictionary = {}
var eraser_button: Button
var clear_button: Button
var library_row: HBoxContainer
var summary: Label
var validation: Label
var start_button: Button
var battle_header: HBoxContainer
var setup_header: HBoxContainer
var status_line: BattleStatusLine
var trans_scroll: ScrollContainer
var trans_row: HBoxContainer
var battle_toolbar: HBoxContainer
var pause_button: Button
var speed_buttons: Dictionary = {}
var winner_panel: PanelContainer
var winner_title: Label
var winner_detail: Label
var unit_dialog: AcceptDialog
var unit_body: VBoxContainer
var info_dialog: AcceptDialog
var info_label: Label
var records_dialog: AcceptDialog
var records_label: Label

func _ready() -> void:
	ArenaUI.install(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin);ArenaUI.safe_margin(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);margin.add_child(column)
	column.add_child(ArenaBrandBar.new())
	# Setup header: title, settings summary, back to the main menu.
	setup_header=HBoxContainer.new();setup_header.custom_minimum_size.y=44;column.add_child(setup_header)
	title_label=Label.new();title_label.text="커스텀 전투";title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title_label.add_theme_font_override("font",ArenaUI.heading_font());title_label.add_theme_font_size_override("font_size",20);title_label.add_theme_color_override("font_color",ArenaUI.GOLD);setup_header.add_child(title_label)
	var info:=_button(setup_header,"ⓘ 맵 · 모드",_show_settings);ArenaUI.quiet(info)
	var home:=_button(setup_header,"메인으로",func():closed.emit());ArenaUI.quiet(home)
	# Battle header: back to setup, mode label, records.
	battle_header=HBoxContainer.new();battle_header.custom_minimum_size.y=44;column.add_child(battle_header);battle_header.hide()
	var back:=_button(battle_header,"← 전투 설정",return_setup);ArenaUI.quiet(back)
	var mode:=Label.new();mode.text="커스텀 전투";mode.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mode.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mode.add_theme_font_override("font",ArenaUI.heading_font());battle_header.add_child(mode)
	var records:=_button(battle_header,"참가자 · 기록",_show_records);ArenaUI.quiet(records)
	# Team spending (temporary card costs, unlimited funds).
	cost_row=HBoxContainer.new();cost_row.add_theme_constant_override("separation",4);column.add_child(cost_row)
	status_line=BattleStatusLine.new();column.add_child(status_line);status_line.hide()
	board=CustomBattleBoard.new();board.setup=setup;board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.custom_minimum_size=Vector2(0,260);board.clip_contents=true;column.add_child(board)
	board.empty_tapped.connect(_place);board.unit_tapped.connect(_unit_tapped);board.unit_moved.connect(_move)
	# Setup controls: teams, tools, character library, footer.
	setup_controls=VBoxContainer.new();setup_controls.add_theme_constant_override("separation",8);column.add_child(setup_controls)
	var tools:=HBoxContainer.new();tools.add_theme_constant_override("separation",4);setup_controls.add_child(tools)
	for i in range(CustomBattleSetup.TEAM_ORDER.size()):
		var team: int=CustomBattleSetup.TEAM_ORDER[i]
		var b:=_button(tools,"%d %s"%[i+1,CustomBattleSetup.TEAM_NAMES[team]],_select_team.bind(team));b.toggle_mode=true;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.add_theme_font_size_override("font_size",12);_team_style(b,team);team_buttons[team]=b
	eraser_button=_button(tools,"",_toggle_eraser);eraser_button.toggle_mode=true;eraser_button.tooltip_text="지우개 · 유닛을 눌러 삭제";eraser_button.custom_minimum_size.x=44;ArenaUI.with_icon(eraser_button,"eraser",18);ArenaUI.quiet(eraser_button)
	clear_button=_button(tools,"",_clear);clear_button.tooltip_text="전체 삭제";clear_button.custom_minimum_size.x=44;ArenaUI.with_icon(clear_button,"clear_all",18);ArenaUI.quiet(clear_button)
	var library:=ScrollContainer.new();library.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;library.custom_minimum_size.y=96;setup_controls.add_child(library)
	library_row=HBoxContainer.new();library_row.add_theme_constant_override("separation",6);library.add_child(library_row)
	var catalog: Dictionary=CharacterCatalog.all()
	for type in range(catalog.size()):
		var data: UnitData=catalog[type]
		var card:=ArenaCard.new();card.card_type="library";card.type_id=type;card.title=data.display_name;card.price=str(int(data.base_gold_cost));card.text="%s 선택 · %d G"%[data.display_name,int(data.base_gold_cost)];card.custom_minimum_size=Vector2(72,88);card.toggle_mode=true;card.name="type_%d"%type
		ArenaUI.bind(card,_select_type.bind(type));library_row.add_child(card)
	var footer:=HBoxContainer.new();setup_controls.add_child(footer)
	var texts:=VBoxContainer.new();texts.size_flags_horizontal=Control.SIZE_EXPAND_FILL;texts.add_theme_constant_override("separation",0);footer.add_child(texts)
	summary=Label.new();summary.add_theme_font_size_override("font_size",13);texts.add_child(summary)
	validation=Label.new();validation.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;validation.add_theme_font_size_override("font_size",11);validation.add_theme_color_override("font_color",ArenaUI.MUTED);texts.add_child(validation)
	start_button=_button(footer,"전투 시작",start_battle);start_button.custom_minimum_size=Vector2(140,52);ArenaUI.primary(start_button);ArenaUI.with_icon(start_button,"play",12,true)
	# Battle controls: transcendence for every unit, pause / speed / rematch.
	trans_scroll=ScrollContainer.new();trans_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;trans_scroll.custom_minimum_size.y=60;column.add_child(trans_scroll);trans_scroll.hide()
	trans_row=HBoxContainer.new();trans_row.add_theme_constant_override("separation",6);trans_scroll.add_child(trans_row)
	battle_toolbar=HBoxContainer.new();column.add_child(battle_toolbar);battle_toolbar.hide()
	pause_button=_button(battle_toolbar,"Ⅱ 일시정지",_toggle_pause);pause_button.custom_minimum_size.x=104;pause_button.add_theme_font_size_override("font_size",11);ArenaUI.quiet(pause_button)
	var lead:=Control.new();lead.size_flags_horizontal=Control.SIZE_EXPAND_FILL;battle_toolbar.add_child(lead)
	var speeds:=HBoxContainer.new();speeds.add_theme_constant_override("separation",4);battle_toolbar.add_child(speeds)
	for speed in [1,2,4]:
		var s:=_button(speeds,"%d×"%speed,_set_speed.bind(speed));s.toggle_mode=true;s.custom_minimum_size.x=30;s.add_theme_font_size_override("font_size",12);ArenaUI.quiet(s);speed_buttons[speed]=s
	var trail:=Control.new();trail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;battle_toolbar.add_child(trail)
	var rematch:=_button(battle_toolbar,"↻ 다시 전투",start_battle);rematch.custom_minimum_size.x=104;rematch.add_theme_font_size_override("font_size",11);ArenaUI.quiet(rematch)
	_build_winner();_build_dialogs()
	var overlay:=TranscendenceOverlay.new();overlay.screen=self;add_child(overlay)
	refresh()

func _button(parent: Node,text: String,callback: Callable) -> Button:
	var b:=Button.new();b.text=text;b.custom_minimum_size.y=44;ArenaUI.bind(b,callback);parent.add_child(b);return b
func _team_style(b: Button,team: int) -> void:
	var color: Color=CustomBattleSetup.team_color(team)
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var on: bool=state in ["pressed","hover_pressed"]
		var style: StyleBoxFlat=ArenaUI.box(Color(color,.32) if on else Color("111726"),Color(color,1.0 if on else .55));style.set_corner_radius_all(8);style.set_border_width_all(2 if on else 1)
		if state=="focus":style.draw_center=false;style.border_color=Color.TRANSPARENT
		b.add_theme_stylebox_override(state,style)
	for name in ["font_color","font_hover_color","font_focus_color"]:b.add_theme_color_override(name,Color(color,.85))
	for name in ["font_pressed_color","font_hover_pressed_color"]:b.add_theme_color_override(name,Color.WHITE)

func _build_winner() -> void:
	winner_panel=PanelContainer.new();winner_panel.z_index=25;add_child(winner_panel);winner_panel.hide()
	var style: StyleBoxFlat=ArenaUI.box(Color(ArenaUI.PANEL,.96),Color("6a5a34"));style.set_corner_radius_all(14);style.content_margin_left=24;style.content_margin_right=24;style.content_margin_top=18;style.content_margin_bottom=18;winner_panel.add_theme_stylebox_override("panel",style)
	var col:=VBoxContainer.new();col.add_theme_constant_override("separation",10);winner_panel.add_child(col)
	var kicker:=Label.new();kicker.text="BATTLE COMPLETE";kicker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;kicker.add_theme_font_override("font",ArenaUI.numbers_font());kicker.add_theme_color_override("font_color",ArenaUI.ACCENT);col.add_child(kicker)
	winner_title=Label.new();winner_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;winner_title.add_theme_font_override("font",ArenaUI.heading_font());winner_title.add_theme_font_size_override("font_size",28);col.add_child(winner_title)
	winner_detail=Label.new();winner_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;winner_detail.add_theme_color_override("font_color",ArenaUI.MUTED);col.add_child(winner_detail)
	var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",10);col.add_child(row)
	var again:=_button(row,"↻ 다시 전투",start_battle);again.custom_minimum_size.x=130;ArenaUI.primary(again)
	var back:=_button(row,"전투 설정",return_setup);back.custom_minimum_size.x=110
func _build_dialogs() -> void:
	unit_dialog=AcceptDialog.new();add_child(unit_dialog);unit_dialog.min_size=Vector2i(300,0)
	var col:=VBoxContainer.new();unit_dialog.add_child(col);ArenaUI.dialog_header(unit_dialog,col,"유닛 설정");ArenaModalBackdrop.new().connect_window(unit_dialog,self)
	unit_body=VBoxContainer.new();unit_body.add_theme_constant_override("separation",8);col.add_child(unit_body)
	info_dialog=AcceptDialog.new();add_child(info_dialog)
	var info_col:=VBoxContainer.new();info_dialog.add_child(info_col);ArenaUI.dialog_header(info_dialog,info_col,"캐릭터 정보");ArenaModalBackdrop.new().connect_window(info_dialog,self)
	info_label=Label.new();info_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info_label.custom_minimum_size.x=280;info_col.add_child(info_label)
	records_dialog=AcceptDialog.new();add_child(records_dialog)
	var rec_col:=VBoxContainer.new();records_dialog.add_child(rec_col);ArenaUI.dialog_header(records_dialog,rec_col,"참가자 · 기록");ArenaModalBackdrop.new().connect_window(records_dialog,self)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(280,300);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;rec_col.add_child(scroll)
	records_label=Label.new();records_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;records_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(records_label)

func _popup(dialog: AcceptDialog) -> void:
	dialog.popup_centered(Vector2i(mini(380,int(get_viewport_rect().size.x)-24),0));call_deferred("_fit",dialog)
func _fit(dialog: AcceptDialog) -> void:
	# Wrapped text can over-grow a window on its first layout pass; shrink it to its content.
	await get_tree().process_frame
	if not dialog.visible:return
	dialog.size=Vector2i(dialog.size.x,ceili(dialog.get_contents_minimum_size().y));dialog.move_to_center()
# ---- Setup ----
func refresh() -> void:
	for child in cost_row.get_children():cost_row.remove_child(child);child.queue_free()
	for team in CustomBattleSetup.TEAM_ORDER:
		var chip:=Label.new();chip.text="%s %s G"%[CustomBattleSetup.TEAM_NAMES[team],ArenaUI.grouped(setup.team_spending(team))];chip.size_flags_horizontal=Control.SIZE_EXPAND_FILL;chip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;chip.add_theme_font_size_override("font_size",11)
		chip.add_theme_color_override("font_color",CustomBattleSetup.team_color(team));cost_row.add_child(chip)
	var funds:=Label.new();funds.text="자금 ∞";funds.add_theme_font_size_override("font_size",11);funds.add_theme_color_override("font_color",ArenaUI.MUTED);cost_row.add_child(funds)
	for team in team_buttons:team_buttons[team].set_pressed_no_signal(team==selected_team and not erasing)
	eraser_button.set_pressed_no_signal(erasing);clear_button.disabled=setup.entries.is_empty()
	for card in library_row.get_children():card.set_pressed_no_signal(card.type_id==selected_type and not erasing);card.queue_redraw()
	summary.text="%d / %d명 · %d개 진영"%[setup.entries.size(),CustomBattleSetup.MAX_PARTICIPANTS,setup.faction_count()]
	if validation.get_meta("sticky",false):validation.set_meta("sticky",false)
	elif erasing:validation.text="지울 유닛을 누르세요."
	elif selected_type<0:validation.text="카드를 선택하고 맵에 배치하세요."
	else:validation.text="%s · %s 배치 · 다시 누르면 정보"%[CharacterCatalog.all()[selected_type].display_name,"개인" if selected_team<0 else CustomBattleSetup.TEAM_NAMES[selected_team]+" 팀"]
	board.queue_redraw()
func _say(text: String) -> void:
	validation.text=text;validation.set_meta("sticky",true)
func _select_team(team: int) -> void:
	selected_team=team;erasing=false;refresh()
func _select_type(type: int) -> void:
	if selected_type==type and not erasing:_show_info(type);refresh();return
	selected_type=type;erasing=false;refresh()
func _toggle_eraser() -> void:
	erasing=not erasing;refresh()
func _clear() -> void:
	setup.clear();refresh()
func _place(point: Vector2) -> void:
	if erasing:return
	if selected_type<0:_say("먼저 하단에서 캐릭터 카드를 선택하세요.");refresh();return
	var error: String=setup.add(selected_type,selected_team,point)
	if not error.is_empty():_say(error)
	refresh()
func _move(id: int,point: Vector2) -> void:
	var error: String=setup.move(id,point)
	if not error.is_empty():_say(error)
	refresh()
func _unit_tapped(id: int) -> void:
	if erasing:setup.remove(id);refresh();return
	unit_id=id;unit_tab="stance";item_choice=&"";_render_unit();_popup(unit_dialog)
func _show_settings() -> void:
	info_dialog.get_child(0).get_child(0).get_child(0).text="맵 · 모드"
	info_label.text="전투 맵 · 스퀘어 아레나\n장애물 없는 정사각형 경기장\n\n전투 모드 · 최후의 생존자\n마지막까지 남은 개인 또는 팀이 승리합니다.\n\n커스텀 전투 자금은 무제한입니다. 카드 가격은 임시 비용이며 팀별 합계만 기록합니다."
	_popup(info_dialog)
func _show_info(type: int) -> void:
	var data: UnitData=CharacterCatalog.all()[type]
	info_dialog.get_child(0).get_child(0).get_child(0).text=data.display_name
	info_label.text="%d G · HP %d · ATK %s · 방어력 %d\n이동 %d · 사거리 %d · 치명타 %d%%\n\n행동 유형 · %s"%[int(data.base_gold_cost),int(data.max_hp),ArenaUI.number(data.attack),int(data.defense_power),int(data.move_speed),int(data.attack_range),int(round(data.critical_chance*100)),", ".join(data.tags)]
	_popup(info_dialog)
func _render_unit() -> void:
	for child in unit_body.get_children():unit_body.remove_child(child);child.queue_free()
	var entry: Dictionary=setup.get_entry(unit_id)
	if entry.is_empty():unit_dialog.hide();return
	var data: UnitData=CharacterCatalog.all()[int(entry.type)]
	var head:=HBoxContainer.new();head.add_theme_constant_override("separation",10);unit_body.add_child(head)
	var portrait:=TextureRect.new();portrait.texture=CharacterPainter.portrait(int(entry.type));portrait.custom_minimum_size=Vector2(48,48);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;head.add_child(portrait)
	var names:=VBoxContainer.new();names.size_flags_horizontal=Control.SIZE_EXPAND_FILL;names.add_theme_constant_override("separation",0);head.add_child(names)
	var name_label:=Label.new();name_label.text="%s #%d"%[data.display_name,int(entry.id)];name_label.add_theme_font_override("font",ArenaUI.heading_font());name_label.add_theme_font_size_override("font_size",17);names.add_child(name_label)
	var team_label:=Label.new();team_label.text="개인" if int(entry.team)<0 else CustomBattleSetup.TEAM_NAMES[int(entry.team)]+" 팀";team_label.add_theme_font_size_override("font_size",12);team_label.add_theme_color_override("font_color",CustomBattleSetup.faction_color(CustomBattleSetup.faction_of(entry),int(entry.type)));names.add_child(team_label)
	var tabs:=HBoxContainer.new();unit_body.add_child(tabs)
	for pair in [["stance","행동성향"],["items","아이템"]]:
		var t:=_button(tabs,pair[1],func():unit_tab=pair[0];_render_unit());t.toggle_mode=true;t.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ArenaUI.tab(t);t.set_pressed_no_signal(unit_tab==pair[0])
	if unit_tab=="stance":
		for stance in CombatStance.VALUES:
			var b:=_button(unit_body,"%s\n%s"%[ArenaUI.stance(stance),ArenaUI.STANCE_HELP[stance]],func():setup.set_stance(unit_id,stance);_render_unit();board.queue_redraw())
			b.toggle_mode=true;b.custom_minimum_size.y=52;b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.add_theme_font_size_override("font_size",13);ArenaUI.tab(b);b.set_pressed_no_signal(entry.stance==stance)
	else:
		var stats: UnitCombatStats=setup.stats_for(entry)
		var heading:=Label.new();heading.text="아이템 %d / %d · 무료 장착 · 자유롭게 해제"%[entry.items.size(),CustomBattleSetup.MAX_ITEMS];heading.add_theme_font_size_override("font_size",12);heading.add_theme_color_override("font_color",ArenaUI.MUTED);unit_body.add_child(heading)
		var slots:=HBoxContainer.new();unit_body.add_child(slots)
		for i in range(CustomBattleSetup.MAX_ITEMS):
			if i<entry.items.size():
				var item: ItemData=ItemCatalog.get_item(entry.items[i])
				var s:=_button(slots,item.display_name+"  ×",func():setup.unequip(unit_id,i);_render_unit();board.queue_redraw());s.size_flags_horizontal=Control.SIZE_EXPAND_FILL;s.add_theme_font_size_override("font_size",12);ArenaUI.with_icon(s,String(entry.items[i]),18)
			else:
				var empty:=Label.new();empty.text="＋ 빈 슬롯";empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL;empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;empty.custom_minimum_size.y=44;empty.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;empty.add_theme_color_override("font_color",ArenaUI.MUTED);slots.add_child(empty)
		var stat_line:=Label.new();stat_line.text="HP %d · 공격력 %s · 이동 %s%s"%[int(stats.max_hp),ArenaUI.number(stats.attack),ArenaUI.number(stats.speed)," · 치유 +%d%%"%int(round((stats.healing_power-1)*100)) if stats.healing_power>1 else ""];stat_line.add_theme_font_size_override("font_size",12);stat_line.add_theme_color_override("font_color",ArenaUI.HP);unit_body.add_child(stat_line)
		var grid:=GridContainer.new();grid.columns=4;unit_body.add_child(grid)
		for kind in CustomBattleSetup.equippable_items():
			var item: ItemData=ItemCatalog.get_item(kind)
			var c:=_button(grid,"",func():item_choice=kind;_render_unit());c.toggle_mode=true;c.custom_minimum_size=Vector2(60,44);c.tooltip_text=item.display_name;ArenaUI.with_icon(c,String(kind),24);c.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;ArenaUI.tab(c);c.set_pressed_no_signal(item_choice==kind)
		var detail:=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",12);unit_body.add_child(detail)
		if item_choice==&"":detail.text="아이템을 선택하세요."
		else:
			var picked: ItemData=ItemCatalog.get_item(item_choice)
			detail.text="%s · %s"%[picked.display_name,"타워 전용 · 생존 승리 시 40골드" if picked.victory_gold>0 else picked.description]
			var full: bool=entry.items.size()>=CustomBattleSetup.MAX_ITEMS
			var equip:=_button(unit_body,"슬롯 가득 참" if full else "장착",func():setup.equip(unit_id,item_choice);_render_unit();board.queue_redraw());equip.disabled=full;ArenaUI.primary(equip)
	var info:=_button(unit_body,"캐릭터 정보 보기 ⓘ",func():_show_info(int(entry.type)));ArenaUI.quiet(info)
	if unit_dialog.visible:call_deferred("_fit",unit_dialog)

# ---- Battle ----
func start_battle() -> void:
	var error: String=setup.validate()
	if not error.is_empty():_say(error);refresh();return
	UiTransition.play("battle")
	_dispose_battle()
	battle=BattleManager.new();battle.auto_start=false;battle.custom_mode=true;board.add_child(battle)
	if not battle.start_battle(setup.placements(),int(Time.get_ticks_usec()&0x7fffffff)):
		_dispose_battle();_say("전투를 시작할 수 없습니다.");refresh();return
	for i in range(setup.entries.size()):
		battle.units[i].stance=setup.entries[i].stance
		# Web custom mode is a transcendence practice ground: every unit starts charged.
		battle.units[i].transcendence_gauge=100
	board.battle=battle;board.editing=false;watch_paused=false;trans_press.clear()
	battle.battle_finished.connect(func(_r):call_deferred("_show_winner"))
	for child in trans_row.get_children():trans_row.remove_child(child);child.queue_free()
	var refill:=_button(trans_row,"초월 충전",_refill);refill.custom_minimum_size=Vector2(60,56);refill.add_theme_font_size_override("font_size",11);refill.tooltip_text="생존 유닛의 초월 게이지 충전";ArenaUI.quiet(refill)
	for u in battle.units:
		var card:=ArenaCard.new();card.card_type="party";card.type_id=u.data.type_id;card.title=u.data.display_name;card.custom_minimum_size=Vector2(48,56);card.set_meta("actor",u.actor_id());trans_row.add_child(card)
		card.gui_input.connect(_trans_input.bind(u.actor_id(),card))
	status_line.battle=battle;status_line.combat_active=true
	_set_phase(true);_set_speed(1)
func _dispose_battle() -> void:
	if is_instance_valid(battle):
		if battle.get_parent()!=null:battle.get_parent().remove_child(battle)
		battle.queue_free()
	battle=null;board.battle=null;winner_panel.hide()
func return_setup() -> void:
	UiTransition.play("back")
	_dispose_battle();board.editing=true;trans_press.clear();_set_phase(false);refresh()
func _set_phase(fighting: bool) -> void:
	setup_header.visible=not fighting;cost_row.visible=not fighting;setup_controls.visible=not fighting
	battle_header.visible=fighting;status_line.visible=fighting;trans_scroll.visible=fighting;battle_toolbar.visible=fighting
	if not fighting:unit_dialog.hide()
func _set_speed(speed: int) -> void:
	if is_instance_valid(battle):battle.clock.set_speed(float(speed))
	for s in speed_buttons:speed_buttons[s].set_pressed_no_signal(s==speed)
func _toggle_pause() -> void:
	if not is_instance_valid(battle) or battle.finished:return
	watch_paused=not watch_paused
	battle.set_physics_process(not watch_paused);board.presentation.set_process(not watch_paused)
	pause_button.text="▶ 계속" if watch_paused else "Ⅱ 일시정지";status_line.spectator_paused=watch_paused
func _refill() -> void:
	if not is_instance_valid(battle):return
	for u in battle.units:
		if u.alive:u.transcendence_gauge=100
func _show_winner() -> void:
	if not is_instance_valid(battle) or battle.result==null:return
	# Let the shared ending cinematic play first, as in tower battles.
	await get_tree().create_timer(BattleCinematicState.DURATION).timeout
	if not is_instance_valid(battle):return
	var winner: int=battle.result.winner_team
	var left: Array=battle.units.filter(func(u):return u.alive)
	if winner<0 or left.is_empty():winner_title.text="무승부"
	elif winner<CustomBattleSetup.SOLO_FACTION_BASE:winner_title.text=CustomBattleSetup.TEAM_NAMES[winner]+" 팀 승리"
	else:winner_title.text=left[0].data.display_name+" 승리"
	winner_title.add_theme_color_override("font_color",ArenaUI.GOLD if left.size()>0 else Color("eef1fa"))
	winner_detail.text="%d초의 전투 · %d명 생존"%[int(battle.clock.elapsed),left.size()]
	winner_panel.show();winner_panel.reset_size()
	winner_panel.position=(get_viewport_rect().size-winner_panel.size)*.5
func _show_records() -> void:
	if not is_instance_valid(battle):return
	var lines: Array[String]=[]
	for u in battle.units:
		var side: String=CustomBattleSetup.TEAM_NAMES[u.original_team] if u.original_team<CustomBattleSetup.SOLO_FACTION_BASE else "개인"
		lines.append("%s · %s · %s"%[side,u.data.display_name,ArenaUI.hp(u.current_hp,u.max_hp) if u.alive else "사망"])
	if not board.presentation.feed.is_empty():lines.append("\n최근 기록\n"+"\n".join(board.presentation.feed))
	records_label.text="\n".join(lines);_popup(records_dialog)

func _process(dt: float) -> void:
	if not is_instance_valid(battle) or board.editing:return
	for card in trans_row.get_children():
		if not card is ArenaCard:continue
		var u=battle.find_actor(card.get_meta("actor"))
		if u==null:continue
		card.hp=u.current_hp;card.hp_max=u.max_hp;card.gauge=u.transcendence_gauge;card.dead=not u.alive
		card.status_text="초월 준비" if battle.transcendence.ready(u) else "";card.modulate=Color("cd9aff") if battle.transcendence.ready(u) else Color.WHITE;card.queue_redraw()
	if not trans_press.is_empty():
		trans_press.held=float(trans_press.held)+dt
		if float(trans_press.held)>=.16 and not trans_press.get("activated",false):
			trans_press.activated=battle.transcendence.begin(battle.find_actor(trans_press.actor),trans_press.origin)
			if trans_press.activated:battle.transcendence.update(trans_press.point)
func _trans_input(event: InputEvent,actor: String,card: Control) -> void:
	if watch_paused or not is_instance_valid(battle):return
	var pressed: bool=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed
	if pressed and battle.transcendence.ready(battle.find_actor(actor)):
		var origin: Vector2=card.get_global_rect().get_center()
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
