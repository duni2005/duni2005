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
var item_icon: TextureRect
var item_name: Label
var item_kind: Label
var item_desc: Label
var item_target: PanelContainer
var item_portrait: TextureRect
var item_member: Label
var item_slots: Label
var item_note: Label
signal home_requested
## A promotion finished; the event drives the promotion cutscene.
signal promoted(event: Dictionary)
var level_up_button: Button
var growth_frame: PanelContainer
var promote_button: Button
var promote_caption: Label
var sortie_button: Button
var sortie_caption: Label
var promotion_dialog: PromotionDialog
func _ready() -> void:
 theme=ArenaUI.get_theme();var outer:=StyleBoxFlat.new();outer.bg_color=ArenaUI.BACKGROUND;add_theme_stylebox_override("panel",outer)
 custom_minimum_size.x=280
 var margin:=MarginContainer.new();add_child(margin);ArenaUI.safe_margin(margin)
 column=VBoxContainer.new();margin.add_child(column);column.add_theme_constant_override("separation",6)
 var window: Window=get_window()
 if window is AcceptDialog:
  window.borderless=true;window.get_ok_button().hide();window.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
  var heading:=HBoxContainer.new();heading.custom_minimum_size.y=44;column.add_child(heading)
  var context_room: RoomState=prebattle_room if prebattle_room!=null else header_room
  page_title=Label.new();page_title.text=ArenaUI.room_title(context_room) if context_room!=null else "길드 관리";page_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page_title.add_theme_font_override("font",ArenaUI.heading_font());page_title.add_theme_font_size_override("font_size",19);page_title.clip_text=true;heading.add_child(page_title)
  var title_fx:=TitleFx.attach(page_title,TypeArt.word(&"guild"));window.about_to_popup.connect(func():title_fx.play())
  close_button=ArenaUI.nav_button("close",window.hide);close_button.tooltip_text="배치로 돌아가기" if prebattle_room!=null else "유닛 창 닫기";heading.add_child(close_button)
  menu_button=ArenaUI.nav_button("menu",_open_page_menu);heading.add_child(menu_button)
  var wallet:=WalletBar.new();wallet.guild=controller.guild;column.add_child(wallet)
 page_frame=PanelContainer.new();page_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(page_frame)
 var style: StyleBoxFlat=ArenaUI.card_style(ArenaUI.BORDER,ArenaUI.PANEL);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=14;style.content_margin_bottom=12;page_frame.add_theme_stylebox_override("panel",style)
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
  ArenaUI.tab(tab)
 roster_scroll=ScrollContainer.new();roster_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(roster_scroll)
 roster=GridContainer.new();roster.columns=2;roster_scroll.add_child(roster)
 content.add_child(HSeparator.new())
 inventory_heading=HBoxContainer.new();content.add_child(inventory_heading)
 inventory_name=Label.new();inventory_name.add_theme_font_override("font",ArenaUI.heading_font());inventory_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inventory_heading.add_child(inventory_name)
 inventory_count=Label.new();inventory_count.add_theme_font_size_override("font_size",10);inventory_count.add_theme_color_override("font_color",ArenaUI.MUTED);inventory_heading.add_child(inventory_count)
 details=Label.new();details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;details.add_theme_font_size_override("font_size",12);content.add_child(details)
 upgrade_frame=PanelContainer.new();upgrade_frame.add_theme_stylebox_override("panel",ArenaUI.card_style());content.add_child(upgrade_frame)
 var upgrade_column:=VBoxContainer.new();upgrade_frame.add_child(upgrade_column)
 upgrade_summary=UpgradeSummary.new();upgrade_column.add_child(upgrade_summary)
 # Experience: one pack at a time, or exactly the packs the next level needs.
 var exp_row:=HBoxContainer.new();exp_row.add_theme_constant_override("separation",8);upgrade_column.add_child(exp_row)
 upgrade_button=Button.new();upgrade_button.custom_minimum_size.y=44;upgrade_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ArenaUI.bind(upgrade_button,_upgrade);exp_row.add_child(upgrade_button)
 level_up_button=Button.new();level_up_button.custom_minimum_size.y=44;level_up_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ArenaUI.primary(level_up_button);ArenaUI.bind(level_up_button,_level_up);exp_row.add_child(level_up_button)
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",12);content.add_child(status)
 inventory_scroll=ScrollContainer.new();inventory_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;inventory_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(inventory_scroll)
 # Guild growth, right under the member card: promotion and the guild-wide sortie upgrade, one
 # row each (icon, name, what it does, action button on the right).
 growth_frame=PanelContainer.new();growth_frame.add_theme_stylebox_override("panel",ArenaUI.card_style());content.add_child(growth_frame);content.move_child(growth_frame,upgrade_frame.get_index()+1)
 var growth_column:=VBoxContainer.new();growth_column.add_theme_constant_override("separation",10);growth_frame.add_child(growth_column)
 var growth_title:=Label.new();growth_title.text="길드 성장";growth_title.add_theme_font_override("font",ArenaUI.heading_font());growth_title.add_theme_font_size_override("font_size",14);growth_title.add_theme_color_override("font_color",Color("e8d6a6"));growth_column.add_child(growth_title)
 var promote: Array=_growth_row(growth_column,"star","승급",_open_promotion);promote_button=promote[0];promote_caption=promote[1];promote_button.text="승급하기"
 growth_column.add_child(HSeparator.new())
 var sortie: Array=_growth_row(growth_column,"flag","출정 수",_upgrade_sortie);sortie_button=sortie[0];sortie_caption=sortie[1]
 inventory_grid=GridContainer.new();inventory_grid.columns=4;inventory_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inventory_grid.add_theme_constant_override("h_separation",6);inventory_grid.add_theme_constant_override("v_separation",6);inventory_scroll.add_child(inventory_grid)
 promotion_dialog=PromotionDialog.new();promotion_dialog.controller=controller;add_child(promotion_dialog);ArenaModalBackdrop.new().connect_window(promotion_dialog,self)
 promotion_dialog.promoted.connect(func(event):status.text="";modified.emit();call_deferred("render");promoted.emit(event))
 item_dialog=ConfirmationDialog.new();add_child(item_dialog);item_dialog.confirmed.connect(_confirm_item);ArenaModalBackdrop.new().connect_window(item_dialog,self)
 _build_item_dialog()
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
  var target: Rect2i=ArenaUI.page_rect(self)
  if window.size!=target.size or window.position!=target.position:window.size=target.size;window.position=target.position
func _process(_dt: float) -> void:
 var wide: bool=size.x>650
 roster.columns=(4 if wide else 2) if active_tab=="guild" else maxi(1,controller.guild.all_members().size())
 inventory_grid.columns=6 if wide else 4
func clear(node: Node) -> void:
 for child in node.get_children():node.remove_child(child);child.queue_free()
func render() -> void:
 var guild: GuildManager=controller.guild
 if guild.get_member(selected_member_id)==null:selected_member_id=guild.all_members()[0].member_id if not guild.all_members().is_empty() else ""
 for key in tabs:tabs[key].button_pressed=key==active_tab
 var main_list: bool=active_tab=="guild"
 roster_scroll.custom_minimum_size.y=220 if main_list else 92
 roster_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED if main_list else ScrollContainer.SCROLL_MODE_AUTO
 roster.size_flags_horizontal=Control.SIZE_EXPAND_FILL if main_list else Control.SIZE_SHRINK_BEGIN
 roster_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL if main_list else Control.SIZE_FILL
 roster_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO if main_list else ScrollContainer.SCROLL_MODE_DISABLED
 details.visible=active_tab=="inventory";upgrade_frame.visible=active_tab=="upgrade";growth_frame.visible=active_tab=="upgrade";inventory_heading.visible=active_tab=="inventory"
 inventory_scroll.visible=active_tab=="inventory";status.visible=not status.text.is_empty()
 if active_tab=="inventory":inventory_scroll.custom_minimum_size.y=0
 # Cards are reused across renders: re-adding them reshapes every Korean label, which is what
 # made each tap (select, tab, upgrade) stall on phones.
 var members: Array=guild.all_members()
 if roster.get_children().map(func(c):return String(c.name))!=members.map(func(m):return m.member_id):
  clear(roster)
  for member in members:
   var card:=ArenaCard.new();card.name=member.member_id;card.toggle_mode=true;ArenaUI.bind(card,_select.bind(member.member_id));roster.add_child(card)
 for member in members:
  var data: UnitData=guild.definition(member.unit_type_id);var stats: UnitCombatStats=guild.member_stats(member)
  var button: ArenaCard=roster.get_node(NodePath(member.member_id))
  # Assigned once: an unchanged label is not reshaped.
  button.text="%s %s%s\nLv.%d · %s\n❤️ %d/%d\n%s"%[data.emoji,data.display_name,"⭐".repeat(member.stars),member.level,ArenaUI.member_label(member.member_id),ceili(member.current_hp),int(stats.max_hp),"사망 · 배치 불가" if not member.is_alive() else ArenaUI.stance(member.stance)]
  button.card_type="member";button.type_id=member.unit_type_id;button.title=data.display_name;button.subtitle="%s · Lv. %d"%[ArenaUI.member_label(member.member_id),member.level];button.hp=member.current_hp;button.hp_max=stats.max_hp;button.stars=member.stars;button.dead=not member.is_alive();button.status_text=ArenaUI.stance(member.stance)+" · 장비 %d/%d"%[controller.content.inventory.equipped(member.member_id).size(),GuildMemberCombatStats.equipment_limit(member)]
  button.show_member(guild,member);button.strip_style=not main_list
  button.card_type="member" if active_tab=="guild" else "mini_member"
  button.custom_minimum_size=Vector2(0 if main_list else 70,152 if main_list else 88);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL if main_list else Control.SIZE_FILL;button.set_pressed_no_signal(member.member_id==selected_member_id);button.queue_redraw()
 var selected: GuildMemberState=guild.get_member(selected_member_id)
 if selected==null:return
 var stats: UnitCombatStats=guild.member_stats(selected);var items: Array[ItemInstance]=controller.content.inventory.equipped(selected_member_id)
 details.text="%s%s · Lv.%d · %s 피해\nHP %d/%d · 장비 %d/%d\n공격력 %d%% · 물리 %s · 마법 %s · 방어 %s · 이동 %s\n%s"%[guild.definition(selected.unit_type_id).display_name,"★".repeat(selected.stars),selected.level,CharacterCatalog.damage_label(selected.unit_type_id),ceili(selected.current_hp),int(stats.max_hp),items.size(),GuildMemberCombatStats.equipment_limit(selected),roundi(stats.attack*100),ArenaUI.number(stats.physical_damage),ArenaUI.number(stats.magic_damage),ArenaUI.number(stats.defense+stats.armor),ArenaUI.number(stats.speed)," / ".join(items.map(func(i):return ItemCatalog.get_item(i.kind).display_name))]
 if active_tab=="upgrade":
  var preview: GuildMemberState=GuildMemberState.new();preview.unit_type_id=selected.unit_type_id;preview.level=selected.level+1;preview.stars=selected.stars;preview.member_id=selected.member_id;preview.fang_kills=selected.fang_kills
  var next: UnitCombatStats=GuildMemberCombatStats.assemble(guild.definition(selected.unit_type_id),preview,controller.content.inventory)
  details.text+="\n다음 강화 · Lv. %d → %d\nHP %s → %s · 물리 %s → %s · 마법 %s → %s\n방어 %s → %s · 이동 %s → %s"%[selected.level,selected.level+1,ArenaUI.number(stats.max_hp),ArenaUI.number(next.max_hp),ArenaUI.number(stats.physical_damage),ArenaUI.number(next.physical_damage),ArenaUI.number(stats.magic_damage),ArenaUI.number(next.magic_damage),ArenaUI.number(stats.defense),ArenaUI.number(next.defense),ArenaUI.number(stats.speed),ArenaUI.number(next.speed)]
 if active_tab=="inventory":details.text="선택한 유닛에게 아이템을 장착하세요.\n장착한 아이템은 재각인으로 회수할 수 있습니다."
 inventory_name.text="%s · %d/%d"%[guild.definition(selected.unit_type_id).display_name,items.size(),GuildMemberCombatStats.equipment_limit(selected)]
 var owned_cards: Array=guild.state.strategy_cards.filter(func(c):return not c.consumed)
 inventory_count.text="장비 %d · 소모품 %d · 장착 %d · 전략카드 %d"%[controller.content.inventory.available().filter(func(i):return not ItemCatalog.get_item(i.kind).consumable).size(),controller.content.inventory.available().filter(func(i):return ItemCatalog.get_item(i.kind).consumable).size(),guild.state.inventory.filter(func(i):return not i.consumed and not i.equipped_to_member_id.is_empty()).size(),owned_cards.size()]
 upgrade_summary.member_name=guild.definition(selected.unit_type_id).display_name;upgrade_summary.level=selected.level;upgrade_summary.hp=selected.current_hp;upgrade_summary.max_hp=stats.max_hp
 upgrade_summary.exp_progress=GrowthRules.exp_progress(selected.total_exp);upgrade_summary.exp_needed=GrowthRules.exp_to_next(selected.level);upgrade_summary.total_exp=selected.total_exp;upgrade_summary.queue_redraw()
 var pack: int=GrowthRules.pack_cost();var level_cost: int=GrowthRules.packs_to_level(selected.total_exp)*pack
 upgrade_button.text="EXP +%d · %dG"%[GrowthRules.EXP_PACK,pack];upgrade_button.disabled=guild.state.gold<pack or not controller.content.can_manage()
 level_up_button.text="즉시 레벨업 · %dG"%level_cost;level_up_button.disabled=guild.state.gold<level_cost or not controller.content.can_manage()
 var can_promote: bool=guild.living_members().any(controller.content.promotion_eligible)
 promote_button.disabled=not controller.content.can_manage() or not can_promote
 promote_caption.text="같은 유닛 3명을 합쳐 ★ +1" if can_promote else "같은 유닛 3명이 모이면 가능"
 var sortie_cost: int=GrowthRules.sortie_cost(guild.state);var limit: int=GrowthRules.sortie_limit(guild.state)
 sortie_caption.text="최대 출정 %d명 (최대치)"%limit if sortie_cost<0 else "출정 %d명 → %d명"%[limit,limit+1]
 sortie_button.text="최대" if sortie_cost<0 else "%s G"%ArenaUI.grouped(sortie_cost)
 sortie_button.disabled=sortie_cost<0 or guild.state.gold<sortie_cost or not controller.content.can_manage()
 # Slots in reading order: spare equipment, consumables, equipped gear, ready cards, waiting cards.
 var spare: Array=controller.content.inventory.available().filter(func(i):return not ItemCatalog.get_item(i.kind).consumable)
 var consumables: Array=controller.content.inventory.available().filter(func(i):return ItemCatalog.get_item(i.kind).consumable)
 var worn: Array=guild.state.inventory.filter(func(i):return not i.consumed and not i.equipped_to_member_id.is_empty())
 var cards: Array=guild.state.strategy_cards.filter(func(c):return not c.consumed)
 var ready: Array=cards.filter(func(c):return StrategyCardExecutor.availability(c,guild.state.strategy_progress))
 var waiting: Array=cards.filter(func(c):return not StrategyCardExecutor.availability(c,guild.state.strategy_progress))
 # Slots are kept per item/card and only created for new ones: adding a slot reshapes its label.
 var pool: Dictionary={}
 for child in inventory_grid.get_children():pool[String(child.name)]=child
 var order: Array[Control]=[]
 for group in [[spare,"equipment"],[consumables,"consumable"],[worn,"equipped"]]:
  for instance in group[0]:
   var key: String="item_%d"%instance.item_id;var button: ArenaCard=pool.get(key);pool.erase(key)
   if button==null:button=ArenaCard.new();button.name=key;ArenaUI.bind(button,_inspect.bind(instance.item_id))
   var data: ItemData=ItemCatalog.of(instance);button.kind=String(instance.kind);button.title=data.display_name;button.description=data.description;button.text="%s %s · 설명 / %s"%[data.emoji,data.display_name,"사용" if data.consumable else "장착"]
   button.status_text="아이템";button.card_type="slot";button.slot_kind=group[1];button.rarity=ItemCatalog.instance_color(instance) if not data.consumable else Color(0,0,0,0);button.custom_minimum_size=Vector2(60,64);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.tooltip_text=data.description
   if group[1]=="equipped":
    var owner: GuildMemberState=guild.get_member(instance.equipped_to_member_id)
    button.owner_type=owner.unit_type_id if owner!=null else -1;button.price=ArenaUI.member_label(instance.equipped_to_member_id)+" 장착" if owner!=null else "장착 중"
   else:button.price="소모" if data.consumable else "장비"
   button.queue_redraw();order.append(button)
 for card in ready+waiting:
  var data: StrategyCardData=StrategyCardCatalog.get_card(card.kind);var on_hold: bool=card in waiting
  var key: String="card_%d_%s"%[card.card_id,on_hold];var button: ArenaCard=pool.get(key);pool.erase(key)
  if button==null:button=ArenaCard.new();button.name=key;ArenaUI.bind(button,_inspect_card.bind(data,on_hold))
  button.kind=String(card.kind);button.title=data.display_name;button.description=data.description;button.text="🃏 %s · 전략카드"%data.display_name;button.status_text="전략"
  button.price=("%d층부터"%(card.ready_floor+1) if data.usage_rule==StrategyCardData.Usage.COOLDOWN else "다음 층") if on_hold else "일회성" if data.usage_rule==StrategyCardData.Usage.ONCE else "층당 1회" if data.usage_rule==StrategyCardData.Usage.FLOOR else "두 층 쿨타임"
  button.card_type="slot";button.slot_kind="cooldown" if on_hold else "strategy";button.custom_minimum_size=Vector2(60,64);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.tooltip_text=data.description
  button.queue_redraw();order.append(button)
 for i in range(maxi(0,24-order.size())):
  var key: String="empty_%d"%i;var empty: Control=pool.get(key);pool.erase(key)
  if empty==null:empty=PanelContainer.new();empty.name=key;empty.custom_minimum_size=Vector2(60,64);empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL;empty.mouse_filter=Control.MOUSE_FILTER_IGNORE;empty.add_theme_stylebox_override("panel",ArenaUI.box(Color("0b0f1a"),Color("1b2236")))
  order.append(empty)
 for node in pool.values():inventory_grid.remove_child(node);node.queue_free()
 for i in range(order.size()):
  if order[i].get_parent()==null:inventory_grid.add_child(order[i])
  inventory_grid.move_child(order[i],i)
func _select(id: String) -> void:
 # Tapping the unit that is already selected opens its description sheet.
 var member: GuildMemberState=controller.guild.get_member(id)
 if id==selected_member_id and member!=null:UnitInfoSheet.open(self,member.unit_type_id,controller.guild.member_stats(member),member);call_deferred("render");return
 selected_member_id=id;call_deferred("render")
func _upgrade() -> void:
 get_tree().root.set_meta("action_point",ArenaUI.control_center(upgrade_button))
 var result: Dictionary=controller.content_action(&"upgrade",{"member_id":selected_member_id});status.text="" if result.ok else "강화 불가 · "+String(result.code)
 modified.emit();call_deferred("render")
func _level_up() -> void:
 get_tree().root.set_meta("action_point",ArenaUI.control_center(level_up_button))
 var result: Dictionary=controller.content_action(&"level_up",{"member_id":selected_member_id});status.text="" if result.ok else "레벨업 불가 · "+String(result.code)
 modified.emit();call_deferred("render")
## One growth row: icon, name and caption on the left, the action button on the right; returns
## [button, caption].
func _growth_row(column: VBoxContainer,icon: String,label: String,callback: Callable) -> Array:
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);column.add_child(row)
 var badge:=TextureRect.new();badge.texture=ArenaIcon.texture(icon);badge.custom_minimum_size=Vector2(30,30);badge.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;badge.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;badge.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(badge)
 var text:=VBoxContainer.new();text.add_theme_constant_override("separation",1);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_child(text)
 var title:=Label.new();title.text=label;title.add_theme_font_override("font",ArenaUI.heading_font());title.add_theme_font_size_override("font_size",15);text.add_child(title)
 var caption:=Label.new();caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.add_theme_font_size_override("font_size",11);caption.add_theme_color_override("font_color",ArenaUI.MUTED);text.add_child(caption)
 var button:=Button.new();button.custom_minimum_size=Vector2(108,44);button.size_flags_vertical=Control.SIZE_SHRINK_CENTER;ArenaUI.bind(button,callback);row.add_child(button)
 if icon=="flag":ArenaUI.style_button(button,Color("7a5a22"),ArenaUI.GOLD);ArenaUI.with_icon(button,"gold",16)
 else:ArenaUI.secondary(button)
 return [button,caption]
func _upgrade_sortie() -> void:
 get_tree().root.set_meta("action_point",ArenaUI.control_center(sortie_button))
 var result: Dictionary=controller.content_action(&"sortie_upgrade");status.text="" if result.ok else "출정 수 업그레이드 불가 · "+String(result.code)
 modified.emit();call_deferred("render")
func _open_promotion() -> void:promotion_dialog.open(selected_member_id)
func _build_item_dialog() -> void:
 # Item sheet: what it is, what it does, and who receives it, before the player commits.
 item_dialog.borderless=true;item_dialog.title="";item_dialog.theme=ArenaUI.get_theme()
 item_dialog.add_theme_constant_override("buttons_min_height",48);item_dialog.add_theme_constant_override("buttons_min_width",132);item_dialog.add_theme_constant_override("buttons_separation",12)
 var sheet: StyleBoxFlat=ArenaUI.window_style();sheet.shadow_size=0;sheet.content_margin_left=18;sheet.content_margin_right=18;sheet.content_margin_top=16;sheet.content_margin_bottom=14;item_dialog.add_theme_stylebox_override("panel",sheet)
 var body:=VBoxContainer.new();body.add_theme_constant_override("separation",12);item_dialog.add_child(body)
 var head:=HBoxContainer.new();head.add_theme_constant_override("separation",12);body.add_child(head)
 var icon_frame:=PanelContainer.new();var icon_style: StyleBoxFlat=ArenaUI.card_style(Color("6a5a34"));icon_frame.add_theme_stylebox_override("panel",icon_style);head.add_child(icon_frame)
 item_icon=TextureRect.new();item_icon.custom_minimum_size=Vector2(48,48);item_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;item_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon_frame.add_child(item_icon)
 var names:=VBoxContainer.new();names.add_theme_constant_override("separation",2);names.size_flags_horizontal=Control.SIZE_EXPAND_FILL;names.alignment=BoxContainer.ALIGNMENT_CENTER;head.add_child(names)
 item_name=Label.new();item_name.add_theme_font_override("font",ArenaUI.heading_font());item_name.add_theme_font_size_override("font_size",20);item_name.add_theme_color_override("font_color",ArenaUI.GOLD);names.add_child(item_name)
 item_kind=Label.new();item_kind.add_theme_font_size_override("font_size",12);item_kind.add_theme_color_override("font_color",ArenaUI.MUTED);names.add_child(item_kind)
 item_desc=Label.new();item_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item_desc.add_theme_font_size_override("font_size",14);body.add_child(item_desc)
 item_target=PanelContainer.new();var target_style: StyleBoxFlat=ArenaUI.card_style();target_style.content_margin_left=10;target_style.content_margin_right=10;target_style.content_margin_top=8;target_style.content_margin_bottom=8;item_target.add_theme_stylebox_override("panel",target_style);body.add_child(item_target)
 var target_row:=HBoxContainer.new();target_row.add_theme_constant_override("separation",10);item_target.add_child(target_row)
 item_portrait=TextureRect.new();item_portrait.custom_minimum_size=Vector2(44,44);item_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;item_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;target_row.add_child(item_portrait)
 var who:=VBoxContainer.new();who.add_theme_constant_override("separation",0);who.size_flags_horizontal=Control.SIZE_EXPAND_FILL;who.alignment=BoxContainer.ALIGNMENT_CENTER;target_row.add_child(who)
 var caption:=Label.new();caption.text="장착 대상";caption.add_theme_font_size_override("font_size",11);caption.add_theme_color_override("font_color",ArenaUI.MUTED);who.add_child(caption)
 item_member=Label.new();item_member.add_theme_font_size_override("font_size",15);who.add_child(item_member)
 item_slots=Label.new();item_slots.add_theme_font_override("font",ArenaUI.numbers_font());item_slots.add_theme_font_size_override("font_size",18);target_row.add_child(item_slots)
 item_note=Label.new();item_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item_note.add_theme_font_size_override("font_size",12);body.add_child(item_note)
 var ok: Button=item_dialog.get_ok_button();var cancel: Button=item_dialog.get_cancel_button();cancel.text="취소"
 for button in [ok,cancel]:button.add_theme_font_size_override("font_size",15)
 ArenaUI.primary(ok);ok.add_theme_color_override("font_disabled_color",ArenaUI.MUTED)
func _show_item_sheet(icon: String,name: String,kind: String,description: String,grade: Color=Color(0,0,0,0)) -> void:
 item_icon.texture=ArenaIcon.texture(icon);item_name.text=name;item_kind.text=kind;item_desc.text=description.replace(" · ","\n")
 item_name.add_theme_color_override("font_color",grade.lightened(.2) if grade.a>0 else ArenaUI.GOLD);item_kind.add_theme_color_override("font_color",grade if grade.a>0 else ArenaUI.MUTED)
 # Fix the text width first so wrapped lines size the sheet, not the other way round.
 var width: int=mini(380,int(get_viewport_rect().size.x)-24)
 for label in [item_desc,item_note]:label.custom_minimum_size.x=width-36
 item_dialog.popup_centered(Vector2i(width,0));call_deferred("_settle_item_sheet",width)
func _settle_item_sheet(width: int) -> void:
 # The first layout pass can wrap text at a stale width and over-grow the window; shrink to content.
 await get_tree().process_frame
 if not item_dialog.visible:return
 item_dialog.size=Vector2i(width,ceili(item_dialog.get_contents_minimum_size().y));item_dialog.move_to_center()
func _inspect(id: int) -> void:
 var item: ItemInstance=controller.content.inventory.get_item(id);var data: ItemData=ItemCatalog.of(item)
 if not item.equipped_to_member_id.is_empty():
  # Already worn: show who wears it; it cannot be equipped again from here.
  var owner: GuildMemberState=controller.guild.get_member(item.equipped_to_member_id);pending_item_id=0;item_target.visible=owner!=null
  if owner!=null:
   item_portrait.texture=UnitIcon.texture(owner.unit_type_id);item_member.text="%s %s · Lv. %d"%[controller.guild.definition(owner.unit_type_id).display_name,ArenaUI.member_label(owner.member_id),owner.level]
   item_slots.text="장착 중";item_slots.add_theme_color_override("font_color",Color("4fc6c0"))
  item_note.text="이 장비는 장착 중입니다. 회수하려면 재각인을 사용하세요.";item_note.add_theme_color_override("font_color",ArenaUI.MUTED)
  item_dialog.get_ok_button().text="장착 중";item_dialog.get_ok_button().disabled=true
  _show_item_sheet(String(item.kind),data.display_name,"%s 장비 · 장착 중"%ItemCatalog.grade_name(item.kind),data.description,ItemCatalog.instance_color(item));return
 pending_item_id=id;pending_member_id=selected_member_id
 var member: GuildMemberState=controller.guild.get_member(selected_member_id)
 var used: int=controller.content.inventory.equipped(selected_member_id).size();var limit: int=GuildMemberCombatStats.equipment_limit(member) if member!=null else 0
 # A basic item fuses with a basic already on the unit, so it never needs a free slot.
 var partner: ItemInstance=null
 if data.grade==&"common":
  for gear in controller.content.inventory.equipped(selected_member_id):
   if ItemCatalog.get_item(gear.kind).grade==&"common":partner=gear;break
 var full: bool=not data.consumable and used>=limit and partner==null
 item_target.visible=member!=null
 if member!=null:
  item_portrait.texture=UnitIcon.texture(member.unit_type_id)
  item_member.text="%s %s · Lv. %d"%[controller.guild.definition(member.unit_type_id).display_name,ArenaUI.member_label(member.member_id),member.level]
  item_slots.text="%d/%d"%[used,limit] if data.consumable else "조합" if partner!=null else "%d → %d / %d"%[used,mini(used+1,limit),limit]
  item_slots.add_theme_color_override("font_color",ArenaUI.DANGER if full else ArenaUI.HP)
 item_note.text="장비 칸이 가득 찼습니다. 재각인으로 회수한 뒤 장착하세요." if full else "사용하면 사라집니다." if data.consumable else "장착한 장비는 자유롭게 해제할 수 없습니다. 회수하려면 재각인이 필요합니다."
 if partner!=null:
  var made: ItemData=ItemCatalog.get_item(ItemCatalog.combined_kind(partner.kind,data.kind))
  item_note.text="장착 중인 %s와 조합되어 [희귀] %s이(가) 됩니다.\n%s"%[ItemCatalog.get_item(partner.kind).display_name,made.display_name,made.description]
 item_note.add_theme_color_override("font_color",ArenaUI.DANGER if full else ItemCatalog.GRADE_COLORS[&"rare"] if partner!=null else ArenaUI.MUTED)
 item_dialog.get_ok_button().text="사용" if data.consumable else "조합" if partner!=null else "장착";item_dialog.get_ok_button().disabled=not controller.content.can_manage() or full or member==null
 _show_item_sheet(String(item.kind),data.display_name,"소모품" if data.consumable else "%s 장비"%ItemCatalog.grade_name(item.kind),data.description,Color(0,0,0,0) if data.consumable else ItemCatalog.instance_color(item))
func _inspect_card(data: StrategyCardData,on_hold: bool=false) -> void:
 pending_item_id=0;item_target.visible=false
 item_note.text="재사용 대기 중입니다. 표시된 층에 도달하면 다시 쓸 수 있습니다." if on_hold else "전투 중 터닝포인트에서 아군을 골라 사용합니다.";item_note.add_theme_color_override("font_color",ArenaUI.MUTED)
 item_dialog.get_ok_button().text="터닝포인트에서 사용";item_dialog.get_ok_button().disabled=true
 var usage: String="일회성" if data.usage_rule==StrategyCardData.Usage.ONCE else "층당 1회" if data.usage_rule==StrategyCardData.Usage.FLOOR else "두 층 쿨타임"
 _show_item_sheet(String(data.kind),data.display_name,"전략카드 · "+usage,data.description)
func _confirm_item() -> void:
 if pending_item_id==0:return
 var result: Dictionary=controller.content_action(&"equip",{"item_id":pending_item_id,"member_id":pending_member_id});status.text="장비 적용" if result.ok else "장비 적용 불가 · "+String(result.code)
 if result.ok and result.outcome.has("combined"):status.text="조합 완료 · [희귀] "+ItemCatalog.get_item(result.outcome.combined).display_name
 pending_item_id=0;modified.emit();call_deferred("render")
