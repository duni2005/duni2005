class_name TowerContentScreen
extends Control
## Functional room UI. Cards/choices only invoke ID-based domain operations.
signal map_requested
signal abandon_requested
signal presentation_requested(event: Dictionary)
signal main_menu_requested
var battle_cue: BattleCueOverlay
var prediction_end: RetreatPresentation
var wallet: WalletBar
var controller: TowerController
var heading: Label
var status: Label
var column: VBoxContainer
var scroll: ScrollContainer
var content_box: VBoxContainer
var map_button: Button
var footer_gap: Control
const FOOTER_LIFT: float=49
var abandon_button: Button
var guild_dialog: AcceptDialog
var guild_panel: GuildManagementPanel
var revive_selection: Array[String] = []
var selecting_revive: bool = false
var board: DeploymentBoard
var battle: BattleManager
var rendered_prediction_finished: bool = false
var content_tab: String="equipment"
var motion_tab: String=""
var emblem: PanelEmblem
var deal_cards: bool=false
var content_tabs: HBoxContainer
var offers_grid: GridContainer
var content_menu: AcceptDialog
var storage_status: Label
var room_frame: PanelContainer
var room_title: Label
var party_strip: ScrollContainer
var party_members: HBoxContainer
var event_grid: GridContainer
var revive_dialog: AcceptDialog
var revival_units: HBoxContainer
var revival_count: Label
var revive_confirm: Button
var guild_button: Button
var menu_button: Button
var map_footer: CenterContainer
var footer_width: float=-1
func _ready() -> void:
	ArenaUI.install(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	ArenaUI.safe_margin(margin)
	column=VBoxContainer.new();margin.add_child(column)
	var brand:=ArenaBrandBar.new();column.add_child(brand)
	var top:=HBoxContainer.new();top.custom_minimum_size.y=44;column.add_child(top)
	heading=Label.new();heading.add_theme_font_size_override("font_size",18);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.clip_text=true;top.add_child(heading)
	guild_button=ArenaUI.nav_button("guild",_open_guild);top.add_child(guild_button)
	menu_button=ArenaUI.nav_button("menu",_open_menu);top.add_child(menu_button)
	wallet=WalletBar.new();wallet.guild=controller.guild;column.add_child(wallet)
	room_frame=PanelContainer.new();room_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(room_frame)
	room_frame.add_theme_stylebox_override("panel",ArenaUI.box(Color("131a2b"),Color("34406a")))
	emblem=PanelEmblem.new();room_frame.add_child(emblem)
	var room_column:=VBoxContainer.new();room_frame.add_child(room_column)
	var actions:=HBoxContainer.new();room_column.add_child(actions)
	room_title=Label.new();room_title.text=RoomType.LABELS[controller.current_room().room_type];room_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;room_title.add_theme_font_override("font",ArenaUI.heading_font());room_title.add_theme_font_size_override("font_size",20);room_title.add_theme_color_override("font_color",ArenaUI.GOLD);actions.add_child(room_title)
	var rule:=StyleBoxFlat.new();rule.bg_color=Color.TRANSPARENT;rule.border_color=Color(ArenaUI.GOLD,.28);rule.border_width_bottom=1;rule.content_margin_bottom=5;room_title.add_theme_stylebox_override("normal",rule)
	map_footer=CenterContainer.new();column.add_child(map_footer)
	map_button=button(map_footer,"지도로",_return_map);map_button.custom_minimum_size.y=48;ArenaUI.primary(map_button);ArenaUI.with_icon(map_button,"play",12,true)
	# Lift the footer to the deploy screen's "전투 시작" height.
	footer_gap=Control.new();footer_gap.custom_minimum_size.y=FOOTER_LIFT;footer_gap.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(footer_gap)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",12);room_column.add_child(status)
	content_menu=AcceptDialog.new();content_menu.title="메뉴";content_menu.get_ok_button().text="닫기";add_child(content_menu);ArenaModalBackdrop.new().connect_window(content_menu,self)
	var menu_actions:=VBoxContainer.new();content_menu.add_child(menu_actions);ArenaUI.dialog_header(content_menu,menu_actions,"메뉴")
	abandon_button=button(menu_actions,"탐험 포기",func():content_menu.hide();abandon_requested.emit())
	var home: Button=button(menu_actions,"메인화면",func():if not _watch_running():content_menu.hide();main_menu_requested.emit())
	# Same icons as the map menu.
	ArenaUI.with_icon(abandon_button,"flag",16);ArenaUI.with_icon(home,"home",16)
	if controller.save_manager!=null:
		storage_status=Label.new();storage_status.text="";storage_status.add_theme_font_size_override("font_size",11);storage_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;storage_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);storage_status.offset_left=-250;storage_status.offset_top=-20;add_child(storage_status)
		controller.save_manager.status_changed.connect(_storage_status)
	content_tabs=HBoxContainer.new();room_column.add_child(content_tabs)
	for pair in [["equipment","장비 구매"],["card","전략카드"],["inventory","인벤토리"]]:
		var tab:=Button.new();tab.text=pair[1];tab.toggle_mode=true;tab.custom_minimum_size.y=36;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.set_meta("tab",pair[0]);ArenaUI.tab(tab);content_tabs.add_child(tab)
		tab.pressed.connect(func():content_tab=pair[0];render())
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;room_column.add_child(scroll)
	content_box=VBoxContainer.new();content_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content_box.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.add_child(content_box)
	party_strip=ScrollContainer.new();party_strip.custom_minimum_size.y=82;party_strip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;room_column.add_child(party_strip);room_column.move_child(party_strip,1)
	party_members=HBoxContainer.new();party_strip.add_child(party_members)
	revive_dialog=AcceptDialog.new();revive_dialog.title="사망 유닛 부활";revive_dialog.get_ok_button().text="부활";add_child(revive_dialog);ArenaModalBackdrop.new().connect_window(revive_dialog,self)
	var revival_column:=VBoxContainer.new();revive_dialog.add_child(revival_column);ArenaUI.dialog_header(revive_dialog,revival_column,"사망 유닛 부활")
	var revival_scroll:=ScrollContainer.new();revival_scroll.custom_minimum_size=Vector2(270,180);revival_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;revival_column.add_child(revival_scroll)
	revival_units=HBoxContainer.new();revival_scroll.add_child(revival_units)
	var revival_footer:=HBoxContainer.new();revival_column.add_child(revival_footer)
	revival_count=Label.new();revival_count.size_flags_horizontal=Control.SIZE_EXPAND_FILL;revival_footer.add_child(revival_count)
	revive_confirm=button(revival_footer,"부활",_confirm_revive);revive_confirm.custom_minimum_size=Vector2(112,44);ArenaUI.primary(revive_confirm)
	revive_dialog.canceled.connect(func():selecting_revive=false;revive_selection.clear())
	guild_dialog=AcceptDialog.new();guild_dialog.title="길드 / 인벤토리";guild_dialog.get_ok_button().text="닫기";add_child(guild_dialog)
	guild_panel=GuildManagementPanel.new();guild_panel.controller=controller;guild_panel.header_room=controller.current_room();guild_dialog.add_child(guild_panel);guild_panel.modified.connect(refresh_wallet);guild_panel.home_requested.connect(func():main_menu_requested.emit())
	render()
func _storage_status(result: SaveLoadResult) -> void:
	storage_status.text="저장 완료" if result.ok() else "전투 종료 후 저장할 수 있습니다." if result.code==SaveLoadResult.Code.BUSY else "저장 실패 · "+result.detail
func button(parent: Node,text: String,callback: Callable,name: String="") -> Button:
	var b:=ArenaCard.new() if parent==content_box else Button.new();b.text=text;b.custom_minimum_size.y=44;ArenaUI.bind(b,callback);if name!="":b.name=name
	if b is ArenaCard:
		b.card_type="choice";b.title=text.split("\n")[0];b.title=ArenaUI.plain(b.title);b.description="\n".join(text.split("\n").slice(1));b.kind={"player":"heal","resources":"gold","guild":"guild","Revival":"rest","bathe":"rest","Reroll":"recruit","Promote":"guild","PromotionDone":"guild","Watch":"battle"}.get(name,"event");b.custom_minimum_size.y=70
	parent.add_child(b);return b
func clear(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func refresh_wallet() -> void:
	var run: RunState=controller.guild.state;var room: RoomState=controller.current_room()
	heading.text=ArenaUI.room_title(room)
func _open_guild() -> void:
	if _watch_running():return
	guild_panel.show_tab("guild");guild_dialog.popup(ArenaUI.page_rect(self))
func _open_menu() -> void:
	if not _watch_running():content_menu.popup_centered(Vector2i(280,0))
func _watch_running() -> bool:
	return is_instance_valid(battle) and (not battle.finished or not rendered_prediction_finished)
func _action(action: StringName,options: Dictionary={}) -> void:
	var result: Dictionary=controller.content_action(action,options)
	status.text=outcome_text(result.get("outcome",{})) if result.ok else "사용 불가 · "+ArenaUI.reason(String(result.code).to_upper())
	if result.ok:
		# Spending already shows in the wallet animation and the action's toast; no "GOLD -n" line.
		status.text=""
		# A reroll deals the new candidates face-down and flips them over.
		if action==&"reroll":deal_cards=true
		_present_action(action,result.get("outcome",{}))
	if result.ok and controller.guild.state.tower.phase==&"route":map_requested.emit()
	else:call_deferred("render")
static func outcome_text(outcome: Dictionary) -> String:
	var parts: Array[String]=[]
	for pair in [["gold","GOLD +"],["tokens","TOKEN +"],["gold_spent","GOLD -"],["tokens_spent","TOKEN -"],["hp_gained","HP +"],["player_hp_gained","플레이어 HP +"],["payout","GOLD +"]]:
		if outcome.has(pair[0]):parts.append(pair[1]+ArenaUI.number(float(outcome[pair[0]])))
	if outcome.has("reward"):parts.append("보상: "+String(outcome.reward))
	if outcome.has("result"):parts.append("예측: "+String(outcome.result))
	if outcome.has("member_id"):parts.append("새 길드원 "+ArenaUI.member_label(String(outcome.member_id)))
	if outcome.has("item_id") or outcome.has("items"):parts.append("아이템 획득")
	if outcome.has("card_id"):parts.append("전략카드 획득")
	return " · ".join(parts) if not parts.is_empty() else "완료"
func render() -> void:
	refresh_wallet();clear(content_box)
	event_grid=null
	var current: RoomState=controller.current_room()
	room_title.text={&"hotSpring":"온천",&"supply":"보물상자",&"promotion":"승급",&"prediction":"전투 예측"}.get(current.event_type,RoomType.LABELS[current.room_type])
	emblem.icon=String(current.room_type) if current.room_type!=RoomType.EVENT else String(current.event_type)
	emblem.caption="%d층 · %d번 방"%[current.floor_index+1,current.lane+1];emblem.visible=current.room_type!=RoomType.SHOP or content_tab!="inventory"
	party_strip.visible=current.room_type==RoomType.REST or current.event_type in [&"hotSpring",&"supply"]
	if party_strip.visible:_refresh_party()
	status.visible=not status.text.is_empty()
	content_tabs.visible=controller.current_room().room_type==RoomType.SHOP
	for tab in content_tabs.get_children():tab.button_pressed=tab.get_meta("tab")==content_tab
	var node: RoomState=controller.current_room();var phase: StringName=controller.guild.state.tower.phase
	map_button.disabled=not TowerNavigationPolicy.can_return(controller.guild.state)
	# The original hides the map action until an event has actually resolved.
	map_button.visible=node.room_type!=RoomType.EVENT or node.event_type==&"promotion" or node.cleared
	if node.event_type==&"promotion":map_button.text="완료 · 지도로";map_button.disabled=false
	else:map_button.text="지도로"
	map_footer.visible=map_button.visible;footer_gap.visible=map_footer.visible
	abandon_button.disabled=controller.guild.state.game_over or is_instance_valid(battle) and not battle.finished
	if content_tabs.visible and motion_tab!=content_tab:
		if not motion_tab.is_empty():UiMotion.pop.call_deferred(content_box,0,.97,.24)
		motion_tab=content_tab
	if phase==&"cleared":
		_result("star","완료한 방","이 방의 보상은 이미 받았습니다.\n지도에서 다음 방을 선택하세요.",ArenaUI.GOLD,[]);return
	if node.room_type==RoomType.RECRUIT:render_recruit(node)
	elif node.room_type==RoomType.SHOP:render_shop(node)
	elif node.room_type==RoomType.REST:render_rest()
	elif node.event_type==&"promotion":render_promotion(node)
	elif node.event_type==&"prediction":render_prediction(node)
	else:render_event(node)
func render_recruit(node: RoomState) -> void:
	var strip:=ScrollContainer.new();strip.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;strip.custom_minimum_size.y=216;content_box.add_child(strip)
	# Reroll sits centred under the recruit cards.
	var reroll_row:=HBoxContainer.new();reroll_row.alignment=BoxContainer.ALIGNMENT_CENTER;content_box.add_child(reroll_row)
	var row:=HBoxContainer.new();strip.add_child(row)
	for offer in node.recruit.offers:
		var data: UnitData=controller.guild.definition(offer.unit_type_id)
		var b:=ArenaCard.new();b.text=data.display_name+" · 영입";b.card_type="recruit";b.type_id=offer.unit_type_id;b.title=data.display_name;b.description=" / ".join(data.tags);b.stats_summary="HP %d · ATK %s"%[int(data.max_hp),ArenaUI.number(data.attack)];b.price="토큰 %d · 영입"%offer.token_price;b.sold=offer.purchased;b.name=offer.offer_id
		ArenaUI.bind(b,_action.bind(&"recruit",{"offer_id":offer.offer_id}));row.add_child(b);b.custom_minimum_size=Vector2(maxf(100,(minf(760,get_viewport_rect().size.x)-32)/3-4),210);b.disabled=offer.purchased or controller.guild.state.tokens<offer.token_price
	var reroll: Button=button(reroll_row,"리롤 · %d G"%TowerContentService.REROLL_COST,_action.bind(&"reroll"),"Reroll");reroll.disabled=controller.guild.state.gold<TowerContentService.REROLL_COST;ArenaUI.price_button(reroll,"리롤","gold",TowerContentService.REROLL_COST)
	if deal_cards:deal_cards=false;UiMotion.deal(row.get_children())
func render_shop(node: RoomState) -> void:
	if content_tab=="inventory":
		var panel:=GuildManagementPanel.new();panel.controller=controller;panel.custom_minimum_size.y=420;content_box.add_child(panel);panel.show_tab("inventory");panel.modified.connect(refresh_wallet);return
	offers_grid=GridContainer.new();offers_grid.columns=3;offers_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content_box.add_child(offers_grid)
	for offer in node.shop.offers:
		if String(offer.category)!=content_tab:continue
		var item: ItemData=ItemCatalog.get_item(offer.kind) if offer.category==&"equipment" else null
		var card: StrategyCardData=StrategyCardCatalog.get_card(offer.kind) if offer.category==&"card" else null
		var b:=ArenaCard.new();b.text=(item.display_name if item!=null else card.display_name)+" · 구매";b.name=offer.offer_id
		b.card_type="product";b.title=item.display_name if item!=null else card.display_name;b.description=item.description if item!=null else card.description;b.kind=String(offer.kind);b.price="구매 완료" if offer.purchased else "%d G"%offer.gold_price;b.sold=offer.purchased;b.custom_minimum_size=Vector2(0,168);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.tooltip_text=b.description;ArenaUI.bind(b,_action.bind(&"buy",{"offer_id":offer.offer_id}));offers_grid.add_child(b);b.disabled=offer.purchased or controller.guild.state.gold<offer.gold_price
func _refresh_party() -> void:
	clear(party_members)
	for member in controller.guild.all_members():
		var c:=ArenaCard.new();c.card_type="mini_member";c.type_id=member.unit_type_id;c.subtitle="%s · Lv.%d"%[ArenaUI.member_label(member.member_id),member.level];c.hp=member.current_hp;c.hp_max=controller.guild.member_max_hp(member);c.energy=member.energy;c.dead=not member.is_alive();c.custom_minimum_size=Vector2(76,90);c.show_member(controller.guild,member);party_members.add_child(c)
func _event_choices() -> GridContainer:
	var center:=CenterContainer.new();content_box.add_child(center)
	event_grid=GridContainer.new();event_grid.columns=2;event_grid.add_theme_constant_override("h_separation",7);event_grid.add_theme_constant_override("v_separation",7);event_grid.custom_minimum_size.x=minf(580,get_viewport_rect().size.x-50);center.add_child(event_grid);return event_grid
func _choice(parent: Node,id: String,title: String,detail: String,icon: String,callback: Callable,price: String="") -> ArenaCard:
	var c:=ArenaCard.new();c.name=id;c.text=title+" · "+detail;c.card_type="event_option";c.kind=icon;c.title=title;c.description=detail;c.price=price;c.size_flags_horizontal=Control.SIZE_EXPAND_FILL;c.custom_minimum_size=Vector2(0,146 if not price.is_empty() else 120);ArenaUI.bind(c,callback);parent.add_child(c);return c
func render_rest() -> void:
	var grid: GridContainer=_event_choices()
	_choice(grid,"player","플레이어 회복","HP +15","heart",_action.bind(&"rest",{"choice":&"player"}))
	_choice(grid,"resources","자원 획득","골드 +350 · 토큰 +1","gold",_action.bind(&"rest",{"choice":&"resources"}))
	_choice(grid,"guild","생존 유닛 회복","HP +35%","rest",_action.bind(&"rest",{"choice":&"guild"}))
	var revive:=_choice(grid,"Revival","사망 유닛 부활","최대 2명 · HP 20%","star",_show_revive)
	revive.disabled=controller.guild.all_members().all(func(m):return m.is_alive())
func _show_revive() -> void:
	selecting_revive=true;revive_selection.clear();_refresh_revive()
	revive_dialog.popup_centered(Vector2i(mini(520,int(get_viewport_rect().size.x)-32),300))
func _confirm_revive() -> void:
	_action(&"rest",{"choice":&"revive","members":revive_selection.duplicate()});revive_dialog.hide()
func _refresh_revive() -> void:
	clear(revival_units)
	for member in controller.guild.all_members():
		if member.is_alive():continue
		var maximum: float=controller.guild.member_max_hp(member)
		var hp: float=maximum*.2*controller.guild.member_stats(member).healing_power
		var c:=ArenaCard.new();c.name=member.member_id;c.card_type="revival_member";c.type_id=member.unit_type_id;c.title=controller.guild.definition(member.unit_type_id).display_name;c.stats_summary="Lv.%d"%member.level;c.description="HP %s / %s"%[ArenaUI.number(hp),ArenaUI.number(maximum)];c.custom_minimum_size=Vector2(108,156);c.show_member(controller.guild,member);c.selected=member.member_id in revive_selection;c.disabled=revive_selection.size()>=2 and not c.selected;ArenaUI.bind(c,_toggle_revive.bind(member.member_id));revival_units.add_child(c)
	revival_count.text="%d / 2명 선택"%revive_selection.size();revive_confirm.disabled=revive_selection.is_empty()
func _toggle_revive(id: String) -> void:
	if id in revive_selection:revive_selection.erase(id)
	elif revive_selection.size()<2:revive_selection.append(id)
	call_deferred("_refresh_revive")
func render_promotion(node: RoomState) -> void:
	var event: EventState=node.event
	_section("남은 승급 %d회"%(event.promotion_limit-event.promotion_used))
	var info:=Label.new();info.text="같은 종류·성급의 Lv.10 유닛 3명을 고르세요";info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_theme_font_size_override("font_size",11);info.add_theme_color_override("font_color",ArenaUI.MUTED);content_box.add_child(info)
	var slots:=HBoxContainer.new();slots.alignment=BoxContainer.ALIGNMENT_CENTER;content_box.add_child(slots)
	var first: GuildMemberState=controller.guild.get_member(event.selected_members[0]) if not event.selected_members.is_empty() else null
	for i in range(3):
		var slot:=ArenaCard.new();slot.card_type="promotion_slot";slot.custom_minimum_size=Vector2(48,58);slot.type_id=-1
		if i<event.selected_members.size():
			var member: GuildMemberState=controller.guild.get_member(event.selected_members[i]);slot.type_id=member.unit_type_id;slot.subtitle="유지" if i==0 else "소비";ArenaUI.bind(slot,_action.bind(&"promotion_select",{"member_id":member.member_id}))
		else:slot.disabled=true
		slots.add_child(slot)
	var arrow:=Label.new();arrow.text="→";slots.add_child(arrow)
	var preview:=ArenaCard.new();preview.card_type="promotion_slot";preview.type_id=first.unit_type_id if first!=null else -1;preview.subtitle="%d성"%(first.stars+1) if first!=null else "승급";preview.custom_minimum_size=Vector2(58,58);preview.disabled=true;slots.add_child(preview)
	var grid:=GridContainer.new();grid.columns=3;content_box.add_child(grid)
	for member in controller.guild.all_members():
		var selected: bool=member.member_id in event.selected_members
		var matching: bool=first==null or first.unit_type_id==member.unit_type_id and first.stars==member.stars
		var eligible: bool=controller.content.promotion_eligible(member) and matching
		var c:=ArenaCard.new();c.name=member.member_id;c.card_type="promotion_member";c.type_id=member.unit_type_id;c.title=controller.guild.definition(member.unit_type_id).display_name;c.subtitle="%s · Lv.%d"%[ArenaUI.member_label(member.member_id),member.level];c.hp=member.current_hp;c.hp_max=controller.guild.member_max_hp(member);c.energy=member.energy;c.dead=not member.is_alive();c.status_text="선택됨" if selected else "사망" if c.dead else "최고 성급" if member.stars>=2 else "Lv.10 필요" if member.level<10 else "승급 가능" if matching else "종류·성급 다름";c.selected=selected;c.custom_minimum_size=Vector2(0,158);c.show_member(controller.guild,member);c.size_flags_horizontal=Control.SIZE_EXPAND_FILL;c.disabled=not selected and (not eligible or event.selected_members.size()>=3 or event.promotion_used>=event.promotion_limit);ArenaUI.bind(c,_action.bind(&"promotion_select",{"member_id":member.member_id}));grid.add_child(c)
	var footer:=HBoxContainer.new();content_box.add_child(footer)
	var count:=Label.new();count.size_flags_horizontal=Control.SIZE_EXPAND_FILL;count.text="%d / 3명 선택"%event.selected_members.size();count.add_theme_font_size_override("font_size",12);footer.add_child(count)
	var promote: Button=button(footer,"승급",_action.bind(&"promote"),"Promote");ArenaUI.primary(promote);promote.custom_minimum_size.x=112;promote.disabled=event.selected_members.size()!=3 or event.promotion_used>=event.promotion_limit
	if first!=null:
		var detail:=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",11);detail.text="첫 길드원과 장비는 유지됩니다. 다른 두 길드원은 소비되며 장비는 인벤토리로 반환됩니다.";content_box.add_child(detail)
func render_event(node: RoomState) -> void:
	if node.event.resolved:
		if node.event.selected_choice==&"bathe":_result("hotSpring","온천욕 완료","따뜻한 온천에서 생존 유닛들이 회복했습니다.",Color("7fd8e8"),["HP +10%","기력 +2칸"])
		else:_result("gold","복권 당첨","온천 복권에서 보상을 얻었습니다.",ArenaUI.GOLD,[_event_reward_text(node.event.outcome)])
		return
	var grid: GridContainer=_event_choices()
	var options: Dictionary={&"bathe":["온천에 들어가기","생존 유닛 HP +10%\n기력 +2칸","hotSpring"],&"lottery":["온천 복권 구매","무작위 보상","gold"],&"heal":["플레이어 회복","HP +10","heart"],&"guild":["생존 유닛 회복","HP +10% · 기력 +1","rest"],&"gold":["자원 획득","골드 +300 · 토큰 +1","gold"],&"loot":["무작위 아이템" if node.event.treasure_kind==&"item" else "무작위 전략카드","아이템 1개" if node.event.treasure_kind==&"item" else "전략카드 1장","supply" if node.event.treasure_kind==&"item" else "prediction"]}
	for choice in node.event.choices:
		var data: Array=options[choice];var c:=_choice(grid,String(choice),data[0],data[1],data[2],_action.bind(&"event",{"choice":choice}),"200 G" if choice==&"lottery" else "")
		if node.event_type==&"hotSpring":c.custom_minimum_size.y=146
		c.disabled=choice==&"lottery" and controller.guild.state.gold<TowerContentService.HOT_SPRING_COST
func _event_reward_text(outcome: Dictionary) -> String:
	if outcome.has("member_id"):
		var member: GuildMemberState=controller.guild.get_member(outcome.member_id)
		return controller.guild.definition(member.unit_type_id).display_name+" 영입" if member!=null else "길드원 영입"
	var names: Array[String]=[]
	var ids: Array=outcome.get("items",[outcome.item_id] if outcome.has("item_id") else [])
	for id in ids:
		var item: ItemInstance=controller.content.inventory.get_item(id)
		if item!=null:names.append(ItemCatalog.get_item(item.kind).display_name)
	if not names.is_empty():return " · ".join(names)
	if outcome.has("card_id"):return StrategyCardCatalog.get_card(controller.guild.state.get_strategy_card(outcome.card_id).kind).display_name+" 전략카드"
	return outcome_text(outcome)
func render_prediction(node: RoomState) -> void:
	var state: PredictionState=node.event.prediction
	if state.status==&"resolved":
		var picked: Array[int]=[]
		for team in state.teams:
			if team.team==state.picked_team:picked.assign(team.types)
		var caption: String="예측한 팀 · %d팀"%(state.picked_team+1)
		if state.result==&"correct":_result("crown","예측 성공!","%d팀의 승리를 맞혔습니다."%(state.picked_team+1),ArenaUI.GOLD,["+%d G"%state.payout,"토큰 +1"],picked,caption)
		elif state.result==&"draw":_result("prediction","무승부","승부가 나지 않아 판돈을 돌려받았습니다.",Color("9fb4d8"),["%d G 반환"%state.stake],picked,caption)
		else:_result("skull","예측 실패","%d팀이 승리하지 못했습니다."%(state.picked_team+1),Color("ff8a8a"),["-%d G"%state.stake],picked,caption)
		return
	_section("승리할 팀 예측")
	for team in state.teams:
		var choice: ArenaCard=button(content_box,"%d팀\n%s"%[team.team+1," / ".join(team.types.map(func(t):return controller.guild.definition(t).display_name))],_pick_prediction.bind(team.team),"team_%d"%team.team)
		choice.card_type="prediction_team";choice.title="%d팀"%(team.team+1);choice.kind="battle";choice.portrait_types.assign(team.types);choice.custom_minimum_size.y=92;choice.toggle_mode=true;choice.set_pressed_no_signal(state.picked_team==team.team);choice.selected=state.picked_team==team.team
	_section("판돈 선택")
	var row:=HBoxContainer.new();content_box.add_child(row)
	for stake in [50,100,200]:
		var b:=ArenaCard.new();b.name="stake_%d"%stake;b.text="GOLD %d"%stake;b.card_type="stake";b.title="%d G"%stake;b.custom_minimum_size=Vector2(0,44);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.toggle_mode=true;b.selected=state.stake==stake;b.set_pressed_no_signal(b.selected);b.disabled=controller.guild.state.gold<stake;row.add_child(b);ArenaUI.bind(b,_stake_prediction.bind(stake))
	# Payout rules as three small chips.
	var odds:=HBoxContainer.new();odds.alignment=BoxContainer.ALIGNMENT_CENTER;odds.add_theme_constant_override("separation",6);content_box.add_child(odds)
	for pair in [["성공 +%d G · 토큰 1"%(state.stake*2),ArenaUI.GOLD],["실패 -%d G"%state.stake,Color("ff8a8a")],["무승부 반환",Color("9fb4d8")]]:
		var chip:=Label.new();chip.text=pair[0];chip.add_theme_font_size_override("font_size",11);chip.add_theme_color_override("font_color",pair[1])
		var box: StyleBoxFlat=ArenaUI.box(Color(pair[1],.12),Color(pair[1],.5));box.set_corner_radius_all(10);box.content_margin_left=8;box.content_margin_right=8;box.content_margin_top=3;box.content_margin_bottom=3;chip.add_theme_stylebox_override("normal",box);odds.add_child(chip)
	var start:=Button.new();start.name="Watch";start.text="%d G 걸고 관전하기"%state.stake;start.custom_minimum_size.y=52;ArenaUI.primary(start);ArenaUI.with_icon(start,"battle",14);ArenaUI.bind(start,_start_prediction);content_box.add_child(start)
	start.disabled=state.picked_team<0 or controller.guild.state.gold<state.stake
## Finished-room page: replaces the room content and the panel watermark.
func _result(icon: String,title: String,detail: String,accent: Color,chips: Array,types: Array[int]=[],caption: String="") -> void:
	emblem.visible=false
	var card:=ResultCard.new();card.icon=icon;card.title=title;card.detail=detail;card.accent=accent;card.chips.assign(chips);card.types=types;card.types_caption=caption;content_box.add_child(card)
func _section(text: String) -> void:
	var label:=Label.new();label.text=text;label.add_theme_font_override("font",ArenaUI.heading_font());label.add_theme_font_size_override("font_size",15);label.add_theme_color_override("font_color",Color("e8d6a6"))
	var rule:=StyleBoxFlat.new();rule.bg_color=Color.TRANSPARENT;rule.border_color=Color(ArenaUI.GOLD,.2);rule.border_width_bottom=1;rule.content_margin_top=6;rule.content_margin_bottom=3;label.add_theme_stylebox_override("normal",rule);content_box.add_child(label)
func _pick_prediction(team: int) -> void:controller.choose_prediction_team(team);call_deferred("render")
func _stake_prediction(stake: int) -> void:controller.choose_prediction_stake(stake);call_deferred("render")
func _start_prediction() -> void:
	battle=BattleManager.new();battle.auto_start=false
	board=DeploymentBoard.new();board.editing=false;board.size_flags_vertical=Control.SIZE_EXPAND_FILL;board.custom_minimum_size.y=240;column.add_child(board);board.add_child(battle)
	if not controller.start_prediction(battle):column.remove_child(board);board.queue_free();board=null;battle=null;status.text="예측 시작 불가";return
	board.battle=battle;room_frame.hide();scroll.hide();refresh_wallet();map_button.disabled=true;abandon_button.disabled=true
	if battle_cue==null:battle_cue=BattleCueOverlay.new();add_child(battle_cue)
	battle_cue.board=board
	presentation_requested.emit({"point":get_tree().root.get_meta("action_point",get_viewport_rect().size*.5)})
func _process(_delta: float) -> void:
	var width: float=get_viewport_rect().size.x
	if width!=footer_width:footer_width=width;map_button.custom_minimum_size.x=maxf(0,minf(520,width-32))
	var watching: bool=_watch_running()
	guild_button.disabled=watching;menu_button.disabled=watching
	map_footer.visible=map_button.visible and not watching;footer_gap.visible=map_footer.visible
	if battle_cue!=null:battle_cue.observe(battle,_delta)
	if is_instance_valid(battle) and battle.finished and not rendered_prediction_finished:
		if prediction_end==null:
			if board.presentation.battle!=battle:board.presentation.attach(battle)
			prediction_end=RetreatPresentation.new();add_child(prediction_end)
			var sequence: BattleCinematicState=board.presentation.ensure_cinematic(battle.result.end_reason)
			var outcome: StringName=controller.current_room().event.prediction.result
			sequence.kind="prediction_success" if outcome==&"correct" else "prediction_draw" if outcome==&"draw" else "prediction_failure"
			prediction_end.begin(sequence,board);wallet.updates_suspended=true
		if not prediction_end.sequence.complete:return
		prediction_end.hide();wallet.updates_suspended=false
		rendered_prediction_finished=true;map_button.disabled=false;room_frame.show();scroll.show()
		presentation_requested.emit({"title":"승부예측 완료","icon":"gold","point":ArenaUI.control_center(board)})
		if is_instance_valid(board):column.remove_child(board);board.queue_free();board=null
		call_deferred("render")
func _return_map() -> void:
	if controller.current_room().event_type==&"promotion" and controller.guild.state.tower.phase==&"event_active":_action(&"finish");return
	if controller.return_map():map_requested.emit()

func _present_action(action: StringName,outcome: Dictionary) -> void:
	var event: Dictionary=outcome.duplicate(true);event["point"]=get_tree().root.get_meta("action_point",get_viewport_rect().size*.5)
	if action in [&"recruit",&"promote"] and outcome.has("member_id"):
		var member: GuildMemberState=controller.guild.get_member(outcome.member_id)
		if member==null:return
		event.merge({"kind":"recruit" if action==&"recruit" else "promotion","key":"%s:%s:%d"%[action,member.member_id,member.stars],"title":controller.guild.definition(member.unit_type_id).display_name,"type":member.unit_type_id,"stars":member.stars,"slots":GuildMemberCombatStats.equipment_limit(member)})
	elif action==&"buy":
		var gained: Dictionary=outcome.duplicate();gained.erase("gold_spent");gained.erase("tokens_spent")
		event.merge({"title":"구매 완료","icon":"shop","detail":outcome_text(gained)})
	elif action==&"reroll":event.merge({"title":"새로운 모집 후보","icon":"recruit","detail":"리롤 완료"})
	elif action in [&"rest",&"event"]:event.merge({"title":"휴식 완료" if action==&"rest" else "이벤트 완료","icon":"rest" if action==&"rest" else "event","detail":outcome_text(outcome)})
	presentation_requested.emit(event)
