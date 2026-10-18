class_name GuildManagementPanel
extends PanelContainer
## Presentation only; ownership/growth operations go through TowerController.
signal modified
var controller: TowerController
var selected_member_id: String = ""
var roster: GridContainer
var details: Label
var inventory_grid: GridContainer
var status: Label
var upgrade_button: Button
var item_dialog: ConfirmationDialog
var pending_item_id: int = 0
var pending_member_id: String = ""
var close_button: Button
var active_tab: String="guild"
var tabs: Dictionary={}
var roster_scroll: ScrollContainer
var inventory_scroll: ScrollContainer
var column: VBoxContainer
var prebattle_room: RoomState
var header_room: RoomState
var page_frame: PanelContainer
var upgrade_frame: PanelContainer
var upgrade_summary: UpgradeSummary
var inventory_heading: HBoxContainer
var inventory_name: Label
var inventory_count: Label
var page_action: Button
var menu_dialog: AcceptDialog
var menu_button: Button
var page_title: Label
signal home_requested
func _ready() -> void:
 theme=ArenaUI.get_theme();var outer:=StyleBoxFlat.new();outer.bg_color=ArenaUI.BACKGROUND;add_theme_stylebox_override("panel",outer)
 custom_minimum_size.x=280
 var margin:=MarginContainer.new();add_child(margin);ArenaUI.safe_margin(margin)
 column=VBoxContainer.new();margin.add_child(column);column.add_theme_constant_override("separation",6)
 var window: Window=get_window()
 if window is AcceptDialog:
  window.borderless=true;window.get_ok_button().hide();window.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
  column.add_child(ArenaBrandBar.new())
  var heading:=HBoxContainer.new();heading.custom_minimum_size.y=44;column.add_child(heading)
  var context_room: RoomState=prebattle_room if prebattle_room!=null else header_room
  page_title=Label.new();page_title.text=ArenaUI.room_title(context_room) if context_room!=null else "길드 관리";page_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_title.add_theme_font_size_override("font_size",18);page_title.clip_text=true;heading.add_child(page_title)
  close_button=ArenaUI.nav_button("close",window.hide);close_button.tooltip_text="배치로 돌아가기" if prebattle_room!=null else "유닛 창 닫기";heading.add_child(close_button)
  menu_button=ArenaUI.nav_button("menu",_open_page_menu);heading.add_child(menu_button)
  var wallet:=WalletBar.new();wallet.guild=controller.guild;column.add_child(wallet)
 page_frame=PanelContainer.new();page_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(page_frame)
 var style: StyleBoxFlat=ArenaUI.box(ArenaUI.PANEL,ArenaUI.BORDER);style.set_corner_radius_all(10);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=14;style.content_margin_bottom=12;page_frame.add_theme_stylebox_override("panel",style)
 var content:=VBoxContainer.new();content.add_theme_constant_override("separation",6);page_frame.add_child(content)
 if prebattle_room!=null:
  var row:=HBoxContainer.new();content.add_child(row)
  var labels:=VBoxContainer.new();labels.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(labels)
  var title:=Label.new();title.text="전투 전 정비";title.add_theme_font_override("font",ArenaUI.heading_font());title.add_theme_font_size_override("font_size",20);labels.add_child(title)
  var enemies:=Label.new();enemies.text="적 %d명 · %s"%[prebattle_room.living_enemies().size(),prebattle_room.encounter.formation if prebattle_room.encounter!=null else "전열"];enemies.add_theme_font_size_override("font_size",12);enemies.add_theme_color_override("font_color",ArenaUI.GOLD);labels.add_child(enemies)
  page_action=Button.new();page_action.text="배치하기";ArenaUI.with_icon(page_action,"play",12,true);page_action.custom_minimum_size=Vector2(102,44);ArenaUI.primary(page_action);ArenaUI.bind(page_action,window.hide);row.add_child(page_action)
 var tab_row:=HBoxContainer.new();content.add_child(tab_row);tab_row.visible=window is AcceptDialog
 var definitions: Array=[["inventory","인벤토리"],["upgrade","강화"]] if prebattle_room!=null else [["guild","유닛목록"],["inventory","인벤토리"],["upgrade","강화"]]
 for pair in definitions:
  var tab:=Button.new();tab.text=pair[1];tab.toggle_mode=true;tab.custom_minimum_size.y=36;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ArenaUI.bind(tab,show_tab.bind(pair[0]));tab_row.add_child(tab);tabs[pair[0]]=tab
  for state in ["normal","hover"]:tab.add_theme_stylebox_override(state,ArenaUI.box(Color("233229"),Color("50604b")))
 roster_scroll=ScrollContainer.new();roster_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(roster_scroll)
 roster=GridContainer.new();roster.columns=2;roster_scroll.add_child(roster)
 content.add_child(HSeparator.new())
 inventory_heading=HBoxContainer.new();content.add_child(inventory_heading)
 inventory_name=Label.new();inventory_name.add_theme_font_override("font",ArenaUI.heading_font());inventory_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inventory_heading.add_child(inventory_name)
 inventory_count=Label.new();inventory_count.add_theme_font_size_override("font_size",10);inventory_count.add_theme_color_override("font_color",ArenaUI.MUTED);inventory_heading.add_child(inventory_count)
 details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_theme_font_size_override("font_size",12);content.add_child(details)
 upgrade_frame=PanelContainer.new();upgrade_frame.add_theme_stylebox_override("panel",ArenaUI.box(Color("203326"),Color.TRANSPARENT));content.add_child(upgrade_frame)
 var upgrade_column:=VBoxContainer.new();upgrade_frame.add_child(upgrade_column)
 upgrade_summary=UpgradeSummary.new();upgrade_column.add_child(upgrade_summary)
 upgrade_button=Button.new();upgrade_button.custom_minimum_size.y=44;ArenaUI.bind(upgrade_button,_upgrade);upgrade_column.add_child(upgrade_button)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",12);content.add_child(status)
 inventory_scroll=ScrollContainer.new();inventory_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;inventory_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(inventory_scroll)
 inventory_grid=GridContainer.new();inventory_grid.columns=4;inventory_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inventory_grid.add_theme_constant_override("h_separation",6);inventory_grid.add_theme_constant_override("v_separation",6);inventory_scroll.add_child(inventory_grid)
 item_dialog=ConfirmationDialog.new();item_dialog.dialog_autowrap=true;add_child(item_dialog);item_dialog.confirmed.connect(_confirm_item);ArenaModalBackdrop.new().connect_window(item_dialog,self)
 if window is AcceptDialog:
  menu_dialog=AcceptDialog.new();menu_dialog.title="메뉴";add_child(menu_dialog);var list:=VBoxContainer.new();menu_dialog.add_child(list);ArenaUI.dialog_header(menu_dialog,list,"메뉴")
  var home:=Button.new();home.text="메인화면";home.alignment=HORIZONTAL_ALIGNMENT_LEFT;home.custom_minimum_size=Vector2(240,54);ArenaUI.with_icon(home,"home",24);ArenaUI.bind(home,func():menu_dialog.hide();home_requested.emit());list.add_child(home);ArenaModalBackdrop.new().connect_window(menu_dialog,self)
 render()
func _open_page_menu() -> void:menu_dialog.popup_centered(Vector2i(mini(300,get_viewport_rect().size.x-50),145))
func show_tab(tab: String) -> void:
 active_tab="inventory" if prebattle_room!=null and tab=="guild" else tab;render();call_deferred("_fit_dialog")
func _fit_dialog() -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 var window: Window=get_window();var root_window: Window=get_tree().root
 if window!=root_window and window is AcceptDialog:
  window.size=root_window.content_scale_size;window.move_to_center()
func _process(_dt: float) -> void:
 var wide: bool=size.x>650
 roster.columns=(4 if wide else 2) if active_tab=="guild" else maxi(1,controller.guild.all_members().size())
 inventory_grid.columns=6 if wide else 4
func clear(node: Node) -> void:
 for child in node.get_children():node.remove_child(child);child.queue_free()
func render() -> void:
 var guild: GuildManager=controller.guild
 if guild.get_member(selected_member_id)==null:selected_member_id=guild.all_members()[0].member_id if not guild.all_members().is_empty() else ""
 clear(roster);clear(inventory_grid)
 for key in tabs:tabs[key].button_pressed=key==active_tab
 var main_list: bool=active_tab=="guild"
 roster_scroll.custom_minimum_size.y=220 if main_list else 92
 roster_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED if main_list else ScrollContainer.SCROLL_MODE_AUTO
 roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL if main_list else Control.SIZE_SHRINK_BEGIN
 roster_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL if main_list else Control.SIZE_FILL
 roster_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO if main_list else ScrollContainer.SCROLL_MODE_DISABLED
 details.visible=active_tab=="inventory";upgrade_frame.visible=active_tab=="upgrade";upgrade_button.visible=active_tab=="upgrade";inventory_heading.visible=active_tab=="inventory"
 inventory_scroll.visible=active_tab=="inventory";status.visible=not status.text.is_empty()
 if active_tab=="inventory":inventory_scroll.custom_minimum_size.y=0
 for member in guild.all_members():
  var data: UnitData=guild.definition(member.unit_type_id);var stats: UnitCombatStats=guild.member_stats(member)
  var button:=ArenaCard.new();button.name=member.member_id;button.text="%s %s%s\nLv.%d · %s\n❤️ %d/%d · ⚡ %d/5"%[data.emoji,data.display_name,"⭐".repeat(member.stars),member.level,ArenaUI.member_label(member.member_id),ceili(member.current_hp),int(stats.max_hp),member.energy]
  button.text+="\n"+("사망 · 배치 불가" if not member.is_alive() else ArenaUI.stance(member.stance))
  button.card_type="member";button.type_id=member.unit_type_id;button.title=data.display_name;button.subtitle="%s · Lv. %d"%[ArenaUI.member_label(member.member_id),member.level];button.hp=member.current_hp;button.hp_max=stats.max_hp;button.energy=member.energy;button.stars=member.stars;button.dead=not member.is_alive();button.status_text=ArenaUI.stance(member.stance)+" · 장비 %d/%d"%[controller.content.inventory.equipped(member.member_id).size(),GuildMemberCombatStats.equipment_limit(member)]
  button.show_member(guild,member);button.strip_style=not main_list
  button.card_type="member" if active_tab=="guild" else "mini_member"
  button.custom_minimum_size=Vector2(0 if main_list else 70,152 if main_list else 88);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL if main_list else Control.SIZE_FILL;button.toggle_mode=true;button.button_pressed=member.member_id==selected_member_id
  ArenaUI.bind(button,_select.bind(member.member_id));roster.add_child(button)
 var selected: GuildMemberState=guild.get_member(selected_member_id)
 if selected==null:return
 var stats: UnitCombatStats=guild.member_stats(selected);var items: Array[ItemInstance]=controller.content.inventory.equipped(selected_member_id)
 details.text="%s%s · Lv.%d\nHP %d/%d · 기력 %d/5 · 장비 %d/%d\n공격 %.1f · 방어 %.1f · 이동 %.1f\n%s"%[guild.definition(selected.unit_type_id).display_name,"★".repeat(selected.stars),selected.level,ceili(selected.current_hp),int(stats.max_hp),selected.energy,items.size(),GuildMemberCombatStats.equipment_limit(selected),stats.attack,stats.defense,stats.speed," / ".join(items.map(func(i):return ItemCatalog.get_item(i.kind).display_name))]
 if selected.level<10 and active_tab=="upgrade":
  var preview: GuildMemberState=GuildMemberState.new();preview.unit_type_id=selected.unit_type_id;preview.level=selected.level+1;preview.stars=selected.stars;preview.member_id=selected.member_id;preview.fang_kills=selected.fang_kills
  var next: UnitCombatStats=GuildMemberCombatStats.assemble(guild.definition(selected.unit_type_id),preview,controller.content.inventory)
  details.text+="\n다음 강화 · Lv. %d → %d\nHP %s → %s · 공격 %s → %s\n방어 %s → %s · 이동 %s → %s"%[selected.level,selected.level+1,ArenaUI.number(stats.max_hp),ArenaUI.number(next.max_hp),ArenaUI.number(stats.attack),ArenaUI.number(next.attack),ArenaUI.number(stats.defense),ArenaUI.number(next.defense),ArenaUI.number(stats.speed),ArenaUI.number(next.speed)]
 if active_tab=="inventory":details.text="선택한 유닛에게 아이템을 장착하세요.\n장착한 아이템은 재각인으로 회수할 수 있습니다."
 inventory_name.text="%s · %d/%d"%[guild.definition(selected.unit_type_id).display_name,items.size(),GuildMemberCombatStats.equipment_limit(selected)]
 inventory_count.text="아이템 %d개 · 전략카드 %d장"%[controller.content.inventory.available().size(),guild.state.strategy_cards.filter(func(c):return not c.consumed).size()]
 upgrade_summary.member_name=guild.definition(selected.unit_type_id).display_name;upgrade_summary.level=selected.level;upgrade_summary.hp=selected.current_hp;upgrade_summary.max_hp=stats.max_hp;upgrade_summary.energy=selected.energy;upgrade_summary.maxed=selected.level>=10;upgrade_summary.queue_redraw()
 upgrade_button.text="Lv.10 · 최대 레벨" if selected.level>=10 else "강화 · %dG"%GuildMemberCombatStats.upgrade_cost(selected)
 upgrade_button.disabled=selected.level>=10 or guild.state.gold<GuildMemberCombatStats.upgrade_cost(selected) or guild.state.tower.phase not in [&"route",&"deploy"]
 for instance in controller.content.inventory.available():
  var data: ItemData=ItemCatalog.get_item(instance.kind);var button:=ArenaCard.new();button.card_type="item";button.kind=String(instance.kind);button.title=data.display_name;button.description=data.description;button.name="item_%d"%instance.item_id;button.text="%s %s · 설명 / %s"%[data.emoji,data.display_name,"사용" if data.consumable else "장착"]
  button.status_text="아이템";button.price="소모" if data.consumable else "장비";button.card_type="slot";button.custom_minimum_size=Vector2(60,64);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.tooltip_text=data.description;ArenaUI.bind(button,_inspect.bind(instance.item_id));inventory_grid.add_child(button)
 for card in guild.state.strategy_cards:
  if card.consumed:continue
  var button:=ArenaCard.new();var data: StrategyCardData=StrategyCardCatalog.get_card(card.kind);button.card_type="strategy";button.kind=String(card.kind);button.title=data.display_name;button.description=data.description;button.text="🃏 %s · 전략카드"%data.display_name;button.status_text="전략";button.price="일회성" if data.usage_rule==StrategyCardData.Usage.ONCE else "층당 1회" if data.usage_rule==StrategyCardData.Usage.FLOOR else "두 층 쿨타임";button.card_type="slot";button.custom_minimum_size=Vector2(60,64);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.tooltip_text=data.description
  ArenaUI.bind(button,_inspect_card.bind(data));inventory_grid.add_child(button)
 while inventory_grid.get_child_count()<24:
  var empty:=PanelContainer.new();empty.custom_minimum_size=Vector2(60,64);empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL;empty.mouse_filter=Control.MOUSE_FILTER_IGNORE;empty.add_theme_stylebox_override("panel",ArenaUI.box(Color("13221a"),Color("334538")));inventory_grid.add_child(empty)
func _select(id: String) -> void:selected_member_id=id;call_deferred("render")
func _upgrade() -> void:
 get_tree().root.set_meta("action_point",ArenaUI.control_center(upgrade_button))
 var result: Dictionary=controller.content_action(&"upgrade",{"member_id":selected_member_id});status.text="강화 완료" if result.ok else "강화 불가 · "+String(result.code)
 modified.emit();call_deferred("render")
func _inspect(id: int) -> void:
 var item: ItemInstance=controller.content.inventory.get_item(id);var data: ItemData=ItemCatalog.get_item(item.kind)
 pending_item_id=id;pending_member_id=selected_member_id;item_dialog.title=data.display_name;item_dialog.dialog_text=data.description
 item_dialog.get_ok_button().text="사용" if data.consumable else "장착";item_dialog.get_ok_button().disabled=not controller.content.can_manage()
 item_dialog.popup_centered(Vector2i(mini(360,int(get_viewport_rect().size.x)-25),190))
func _inspect_card(data: StrategyCardData) -> void:
 pending_item_id=0;item_dialog.title=data.display_name;item_dialog.dialog_text=data.description;item_dialog.get_ok_button().text="터닝포인트에서 사용";item_dialog.get_ok_button().disabled=true
 item_dialog.popup_centered(Vector2i(mini(360,int(get_viewport_rect().size.x)-25),190))
func _confirm_item() -> void:
 if pending_item_id==0:return
 var result: Dictionary=controller.content_action(&"equip",{"item_id":pending_item_id,"member_id":pending_member_id});status.text="장비 적용" if result.ok else "장비 적용 불가 · "+String(result.code)
 pending_item_id=0;modified.emit();call_deferred("render")
