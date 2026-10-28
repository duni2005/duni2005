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
## What the member picker is choosing for: &"rest" (up to REST_REVIVE_LIMIT dead members),
## &"revive" (one dead member, token shop), &"restore" (one hurt living member, token shop) or
## &"mango" (one dead member, mango sapling).
var pick_mode: StringName = &"rest"
var board: DeploymentBoard
## Watch speed for the prediction battle (1×/2×/4×), shown under its field while it runs.
var speed_row: HBoxContainer
var speed_buttons: Dictionary={}
var battle: BattleManager
var rendered_prediction_finished: bool = false
var content_tab: String="equipment"
const SHOP_TABS=[["equipment","장비 구매"],["card","전략카드"],["inventory","인벤토리"]]
const BLACKSMITH_TABS=[["enhance","강화"],["trade","교환"],["sell","판매"]]
## Blacksmith: the rare item chosen on the 강화 tab and the basic items put in for a trade.
var forge_pick: int=0
var trade_pick: Array[int]=[]
## Gambler's room: the game just played (its result animates once) and its toast, held until the
## animation ends so the wallet and toast do not give the result away.
var gamble_fresh: StringName=&""
var gamble_toast: Dictionary={}
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
	var top:=HBoxContainer.new();top.custom_minimum_size.y=44;column.add_child(top)
	heading=Label.new();heading.add_theme_font_override("font",ArenaUI.heading_font());heading.add_theme_font_size_override("font_size",19);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.clip_text=true;top.add_child(heading);TitleFx.attach(heading).play()
	guild_button=ArenaUI.nav_button("guild",_open_guild);top.add_child(guild_button)
	menu_button=ArenaUI.nav_button("menu",_open_menu);top.add_child(menu_button)
	wallet=WalletBar.new();wallet.guild=controller.guild;column.add_child(wallet)
	room_frame=PanelContainer.new();room_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(room_frame)
	room_frame.add_theme_stylebox_override("panel",ArenaUI.card_style(ArenaUI.CARD_LINE,ArenaUI.PANEL))
	emblem=PanelEmblem.new();room_frame.add_child(emblem)
	var room_column:=VBoxContainer.new();room_frame.add_child(room_column)
	var actions:=HBoxContainer.new();room_column.add_child(actions)
	room_title=Label.new();room_title.text=RoomType.LABELS[controller.current_room().room_type];room_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;room_title.add_theme_font_override("font",ArenaUI.heading_font());room_title.add_theme_font_size_override("font_size",20);room_title.add_theme_color_override("font_color",ArenaUI.GOLD);actions.add_child(room_title)
	var rule:=StyleBoxFlat.new();rule.bg_color=Color.TRANSPARENT;rule.content_margin_bottom=5;room_title.add_theme_stylebox_override("normal",rule)
	# The gold rule under the title is drawn by its TitleFx, out from the centre.
	TitleFx.attach(room_title,TypeArt.room_word(controller.current_room()),true).play(.1)
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
	var forge: bool=controller.current_room().event_type==TowerController.BLACKSMITH
	if forge:content_tab="enhance"
	for pair in BLACKSMITH_TABS if forge else SHOP_TABS:
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
	guild_panel=GuildManagementPanel.new();guild_panel.controller=controller;guild_panel.header_room=controller.current_room();guild_dialog.add_child(guild_panel);guild_panel.modified.connect(refresh_wallet);guild_panel.promoted.connect(func(e):guild_dialog.hide();presentation_requested.emit(e));guild_panel.home_requested.connect(func():main_menu_requested.emit())
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
	room_title.text=ArenaUI.EVENT_NAMES.get(current.event_type,RoomType.LABELS[current.room_type])
	emblem.icon=String(current.room_type) if current.room_type!=RoomType.EVENT else String(current.event_type)
	emblem.caption="%d층 · %d번 방"%[current.floor_index+1,current.lane+1];emblem.visible=current.room_type!=RoomType.SHOP or content_tab!="inventory"
	party_strip.visible=current.room_type==RoomType.REST or current.event_type in [&"hotSpring",&"supply",&"tokenShop",&"mangoSapling"]
	if party_strip.visible:_refresh_party()
	status.visible=not status.text.is_empty()
	var node: RoomState=controller.current_room();var phase: StringName=controller.guild.state.tower.phase
	content_tabs.visible=node.room_type==RoomType.SHOP or node.event_type==TowerController.BLACKSMITH and phase==&"event_active"
	for tab in content_tabs.get_children():tab.button_pressed=tab.get_meta("tab")==content_tab
	map_button.disabled=not TowerNavigationPolicy.can_return(controller.guild.state)
	# The original hides the map action until an event has actually resolved.
	map_button.visible=node.room_type!=RoomType.EVENT or node.cleared
	map_button.text="지도로"
	# The token shop and the blacksmith are left like a shop: the button ends the event and returns to the map.
	if node.event_type in [&"tokenShop",TowerController.BLACKSMITH,&"mangoSapling",&"gambler"] and not node.cleared and phase==&"event_active":map_button.visible=true;map_button.disabled=false;map_button.text="상점 나가기" if node.event_type==&"tokenShop" else "지도로"
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
		var panel:=GuildManagementPanel.new();panel.controller=controller;panel.custom_minimum_size.y=420;content_box.add_child(panel);panel.show_tab("inventory");panel.modified.connect(refresh_wallet);panel.promoted.connect(presentation_requested.emit);return
	offers_grid=GridContainer.new();offers_grid.columns=3;offers_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content_box.add_child(offers_grid)
	for offer in node.shop.offers:
		if String(offer.category)!=content_tab:continue
		var item: ItemData=ItemCatalog.get_item(offer.kind) if offer.category==&"equipment" else null
		var card: StrategyCardData=StrategyCardCatalog.get_card(offer.kind) if offer.category==&"card" else null
		var b:=ArenaCard.new();b.text=(item.display_name if item!=null else card.display_name)+" · 구매";b.name=offer.offer_id
		b.card_type="product";b.rarity=ItemCatalog.grade_color(offer.kind) if item!=null and not item.consumable else Color(0,0,0,0);b.title=item.display_name if item!=null else card.display_name;b.description=item.description if item!=null else card.description;b.kind=String(offer.kind);b.price="구매 완료" if offer.purchased else "%d G"%offer.gold_price;b.sold=offer.purchased;b.custom_minimum_size=Vector2(0,168);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.tooltip_text=b.description;ArenaUI.bind(b,_action.bind(&"buy",{"offer_id":offer.offer_id}));offers_grid.add_child(b);b.disabled=offer.purchased or controller.guild.state.gold<offer.gold_price
func _refresh_party() -> void:
	clear(party_members)
	for member in controller.guild.all_members():
		var c:=ArenaCard.new();c.card_type="mini_member";c.type_id=member.unit_type_id;c.subtitle="%s · Lv.%d"%[ArenaUI.member_label(member.member_id),member.level];c.hp=member.current_hp;c.hp_max=controller.guild.member_max_hp(member);c.dead=not member.is_alive();c.custom_minimum_size=Vector2(76,90);c.show_member(controller.guild,member);party_members.add_child(c)
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
	var revive:=_choice(grid,"Revival","사망 유닛 부활","최대 %d명 · HP 20%%"%TowerContentService.REST_REVIVE_LIMIT,"star",_show_revive.bind(&"rest"))
	revive.disabled=controller.guild.all_members().all(func(m):return m.is_alive())
func _pick_limit() -> int:return TowerContentService.REST_REVIVE_LIMIT if pick_mode==&"rest" else 1
func _show_revive(mode: StringName=&"rest") -> void:
	pick_mode=mode;selecting_revive=true;revive_selection.clear()
	var title: String="유닛 HP 전부 회복" if mode==&"restore" else "사망 유닛 부활"
	revive_dialog.title=title;revive_confirm.text="회복" if mode==&"restore" else "부활"
	var heading: Label=revive_dialog.get_child(0).get_child(0).get_child(0) if revive_dialog.get_child(0).get_child_count()>0 else null
	if heading!=null:heading.text=title
	_refresh_revive()
	revive_dialog.popup_centered(Vector2i(mini(520,int(get_viewport_rect().size.x)-32),300))
func _confirm_revive() -> void:
	if pick_mode==&"rest":_action(&"rest",{"choice":&"revive","members":revive_selection.duplicate()})
	elif pick_mode==&"mango" and not revive_selection.is_empty():_action(&"mango",{"choice":&"revive","member_id":revive_selection[0]})
	elif not revive_selection.is_empty():_action(&"token_shop",{"choice":pick_mode,"member_id":revive_selection[0]})
	revive_dialog.hide()
func _refresh_revive() -> void:
	clear(revival_units)
	for member in controller.guild.all_members():
		if pick_mode==&"restore":
			# Living members who are missing HP.
			if not member.is_alive() or member.current_hp>=controller.guild.member_max_hp(member):continue
			var card:=ArenaCard.new();card.name=member.member_id;card.card_type="member";card.custom_minimum_size=Vector2(108,156);card.show_member(controller.guild,member);card.subtitle="Lv.%d"%member.level;card.selected=member.member_id in revive_selection;ArenaUI.bind(card,_toggle_revive.bind(member.member_id));revival_units.add_child(card)
			continue
		if member.is_alive():continue
		var maximum: float=controller.guild.member_max_hp(member)
		var hp: float=maximum*.2*controller.guild.member_stats(member).healing_received
		var c:=ArenaCard.new();c.name=member.member_id;c.card_type="revival_member";c.type_id=member.unit_type_id;c.title=controller.guild.definition(member.unit_type_id).display_name;c.stats_summary="Lv.%d"%member.level;c.description="HP %s / %s"%[ArenaUI.number(hp),ArenaUI.number(maximum)];c.custom_minimum_size=Vector2(108,156);c.show_member(controller.guild,member);c.selected=member.member_id in revive_selection;c.disabled=revive_selection.size()>=2 and not c.selected;ArenaUI.bind(c,_toggle_revive.bind(member.member_id));revival_units.add_child(c)
	revival_count.text="%d / %d명 선택"%[revive_selection.size(),_pick_limit()];revive_confirm.disabled=revive_selection.is_empty()
func _toggle_revive(id: String) -> void:
	if id in revive_selection:revive_selection.erase(id)
	elif _pick_limit()==1:revive_selection=[id]
	elif revive_selection.size()<_pick_limit():revive_selection.append(id)
	call_deferred("_refresh_revive")
## Token shop: five offers bought with tokens, each up to its limit; 상점 나가기 ends the event.
func render_token_shop(node: RoomState) -> void:
	var grid: GridContainer=_event_choices();var guild: GuildManager=controller.guild;var tokens: int=guild.state.tokens
	var offers: Array=[[&"revive","유닛 부활","사망 유닛 1명 · HP 20%","star"],[&"heal","전체 회복","모든 유닛 HP +5%","rest"],[&"item","일반 아이템","무작위 1개","supply"],[&"card","전략카드","무작위 1장","event"],[&"restore","완전 회복","생존 유닛 1명 HP 전부","heart"]]
	for row in offers:
		var choice: StringName=row[0];var offer: Dictionary=TowerContentService.TOKEN_SHOP[choice];var bought: int=int(node.event.purchases.get(String(choice),0));var limit: int=int(offer.limit)
		var left: String="남은 구매 %d / %d"%[limit-bought,limit] if limit>0 else "구매 제한 없음"
		var callback: Callable=_show_revive.bind(choice) if choice in [&"revive",&"restore"] else _action.bind(&"token_shop",{"choice":choice})
		var card: ArenaCard=_choice(grid,"Token_"+String(choice),row[1],"%s\n%s"%[row[2],left],row[3],callback,"토큰 %d"%int(offer.tokens))
		var target: bool=true
		if choice==&"revive":target=guild.all_members().any(func(m):return not m.is_alive())
		elif choice==&"restore":target=guild.living_members().any(func(m):return m.current_hp<guild.member_max_hp(m))
		elif choice==&"heal":target=not guild.living_members().is_empty()
		card.disabled=(limit>0 and bought>=limit) or tokens<int(offer.tokens) or not target
## Mango sapling: a free revive, an offering for one faith stack and, when the party arrived with
## faith, the blessing that turns all of it into gold. 지도로 ends the event.
func render_mango(node: RoomState) -> void:
	var run: RunState=controller.guild.state;var faith: int=run.mango_faith
	var left:=func(choice: StringName) -> int:return int(TowerContentService.MANGO_LIMITS[choice].limit)-int(node.event.purchases.get(String(choice),0))
	_section("망고 신앙 %d스택"%faith)
	var grid: GridContainer=_event_choices()
	var revive: ArenaCard=_choice(grid,"MangoRevive","아군 부활","사망 유닛 1명 · HP 20%%\n남은 사용 %d / 1"%left.call(&"revive"),"star",_show_revive.bind(&"mango"))
	revive.disabled=left.call(&"revive")<=0 or controller.guild.all_members().all(func(m):return m.is_alive())
	var offer: ArenaCard=_choice(grid,"MangoOffer","재물 올리기","망고 신앙 +1 · 방당 1회\n"+("사용 완료" if left.call(&"offer")<=0 else "신앙 %d → %d"%[faith,faith+1]),"mango",_action.bind(&"mango",{"choice":&"offer"}),"%d G"%TowerContentService.MANGO_OFFERING)
	offer.disabled=left.call(&"offer")<=0 or run.gold<TowerContentService.MANGO_OFFERING
	if &"bless" in node.event.choices:
		var bless: ArenaCard=_choice(grid,"MangoBless","망고 나무의 축복","사용 완료" if left.call(&"bless")<=0 else "신앙 %d 모두 소모\n+%s G"%[faith,ArenaUI.grouped(TowerContentService.blessing_gold(faith))],"gold",_action.bind(&"mango",{"choice":&"bless"}))
		bless.disabled=left.call(&"bless")<=0 or faith<=0
	_hint("축복 보상 (신앙 1 · 2 · 3 · 4 · 5)\n%s G\n신앙을 가진 채 들어오면 축복을 받을 수 있습니다."%" · ".join([1,2,3,4,5].map(func(n):return ArenaUI.grouped(TowerContentService.blessing_gold(n)))))
## Gambler's room: roulette and dice, GAMBLE_COST each, once per visit; results stay on show.
func render_gambler(node: RoomState) -> void:
	var run: RunState=controller.guild.state;var cost: int=TowerContentService.GAMBLE_COST
	var grid: GridContainer=_event_choices()
	var rows: Array=[[&"roulette","룰렛","8칸 중 무작위 보상\n꽝 · 골드 · 토큰 · 아이템 · 카드","event"],[&"dice","주사위","주사위 3개 합이 도박꾼보다\n높으면 2배 · 같으면 반환","dice"]]
	for row in rows:
		var played: bool=int(node.event.purchases.get(String(row[0]),0))>=int(TowerContentService.GAMBLE_LIMITS[row[0]].limit)
		var card: ArenaCard=_choice(grid,"Gamble_"+String(row[0]),row[1],"사용 완료" if played else row[2],row[3],_action.bind(&"gamble",{"choice":row[0]}),"%d G"%cost)
		card.disabled=played or run.gold<cost
	for row in rows:
		var result: Dictionary=node.event.outcome.get(String(row[0]),{})
		if result.is_empty():continue
		_section(row[1]+" 결과")
		var show:=GambleShow.new();show.game=row[0];show.outcome=result;content_box.add_child(show)
		# A re-render while it plays starts it over; the flag clears only when it has been seen.
		var fresh: bool=gamble_fresh==row[0];show.finished.connect(_gamble_shown.bind(fresh));show.play(fresh)
		if fresh:_scroll_to.call_deferred(show)
## Brings a freshly added control into view once the scroll has laid it out.
func _scroll_to(target: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(target):scroll.ensure_control_visible(target)
func _gamble_shown(fresh: bool) -> void:
	if not fresh:return
	gamble_fresh=&"";wallet.updates_suspended=false
	if not gamble_toast.is_empty():presentation_requested.emit(gamble_toast);gamble_toast={}
func render_event(node: RoomState) -> void:
	if node.event_type==&"tokenShop":render_token_shop(node);return
	if node.event_type==TowerController.BLACKSMITH:render_blacksmith(node);return
	if node.event_type==&"mangoSapling":render_mango(node);return
	if node.event_type==&"gambler":render_gambler(node);return
	if node.event.resolved:
		if node.event.selected_choice==&"bathe":_result("hotSpring","온천욕 완료","따뜻한 온천에서 생존 유닛들이 회복했습니다.",Color("7fd8e8"),["HP +10%"])
		else:_result("gold","복권 당첨","온천 복권에서 보상을 얻었습니다.",ArenaUI.GOLD,[_event_reward_text(node.event.outcome)])
		return
	var grid: GridContainer=_event_choices()
	var options: Dictionary={&"bathe":["온천에 들어가기","생존 유닛 HP +10%","hotSpring"],&"lottery":["온천 복권 구매","무작위 보상","gold"],&"heal":["플레이어 회복","HP +10","heart"],&"guild":["생존 유닛 회복","HP +10%","rest"],&"gold":["자원 획득","골드 +300 · 토큰 +1","gold"],&"loot":["무작위 아이템" if node.event.treasure_kind==&"item" else "무작위 전략카드","아이템 1개" if node.event.treasure_kind==&"item" else "전략카드 1장","supply" if node.event.treasure_kind==&"item" else "prediction"]}
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
	# Say why it is not ready instead of a red disabled label.
	start.add_theme_color_override("font_disabled_color",ArenaUI.MUTED)
	if state.picked_team<0:start.text="승리할 팀을 먼저 선택하세요"
	elif controller.guild.state.gold<state.stake:start.text="골드가 부족합니다"
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
	speed_row=HBoxContainer.new();speed_row.alignment=BoxContainer.ALIGNMENT_END;speed_row.add_theme_constant_override("separation",4);column.add_child(speed_row);column.move_child(speed_row,board.get_index()+1)
	var label:=Label.new();label.text="배속";label.add_theme_font_size_override("font_size",12);label.add_theme_color_override("font_color",ArenaUI.MUTED);speed_row.add_child(label)
	speed_buttons.clear()
	for speed in [1,2,4]:
		var choice:=Button.new();choice.name="Speed%d"%speed;choice.text="%d×"%speed;choice.toggle_mode=true;choice.custom_minimum_size=Vector2(44,40);choice.add_theme_font_size_override("font_size",13)
		ArenaUI.bind(choice,func():if is_instance_valid(battle):battle.clock.set_speed(float(speed)));ArenaUI.quiet(choice);speed_row.add_child(choice);speed_buttons[speed]=choice
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
	for speed in speed_buttons:
		var choice: Button=speed_buttons[speed]
		choice.disabled=not is_instance_valid(battle) or battle.finished or battle.clock.state!=BattleClock.State.NORMAL
		choice.set_pressed_no_signal(is_instance_valid(battle) and int(battle.clock.speed)==speed)
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
		if is_instance_valid(speed_row):speed_row.queue_free();speed_row=null;speed_buttons.clear()
		call_deferred("render")
func _return_map() -> void:
	var node: RoomState=controller.current_room()
	if node!=null and node.event_type in [&"tokenShop",TowerController.BLACKSMITH,&"mangoSapling",&"gambler"] and not node.cleared and controller.guild.state.tower.phase==&"event_active":
		if not controller.content_action(&"event",{"choice":&"leave"}).ok:return
	if controller.return_map():map_requested.emit()

func _present_action(action: StringName,outcome: Dictionary) -> void:
	var event: Dictionary=outcome.duplicate(true);event["point"]=get_tree().root.get_meta("action_point",get_viewport_rect().size*.5)
	if action==&"recruit" and outcome.has("member_id"):
		var member: GuildMemberState=controller.guild.get_member(outcome.member_id)
		if member==null:return
		event.merge({"kind":"recruit","key":"%s:%s:%d"%[action,member.member_id,member.stars],"title":controller.guild.definition(member.unit_type_id).display_name,"type":member.unit_type_id,"stars":member.stars,"slots":GuildMemberCombatStats.equipment_limit(member)})
	elif action==&"buy":
		var gained: Dictionary=outcome.duplicate();gained.erase("gold_spent");gained.erase("tokens_spent")
		event.merge({"title":"구매 완료","icon":"shop","detail":outcome_text(gained)})
	elif action==&"reroll":event.merge({"title":"새로운 모집 후보","icon":"recruit","detail":"리롤 완료"})
	elif action==&"token_shop":event.merge({"title":"토큰 상점","icon":"gem","detail":_token_detail(outcome)})
	elif action==&"enhance":event.merge({"title":"강화 성공","icon":"anvil","detail":_item_name(outcome.item_id)})
	elif action==&"trade":trade_pick.clear();event.merge({"title":"교환 완료","icon":"anvil","detail":_item_name(outcome.item_id)})
	elif action==&"gamble":
		# Shown when the wheel or the dice stop.
		gamble_fresh=StringName(outcome.choice);wallet.updates_suspended=true
		var reward: String=GambleShow.SLOT_LABELS.get(outcome.get("reward",&""),"") if outcome.choice==&"roulette" else {&"win":"승리",&"draw":"무승부",&"lose":"패배"}[outcome.result]
		if outcome.has("item_id") or outcome.has("card_id"):reward=_event_reward_text(outcome)
		gamble_toast=event.merged({"title":"룰렛" if outcome.choice==&"roulette" else "주사위","icon":"dice","detail":reward});return
	elif action==&"mango":
		match StringName(outcome.get("choice",&"")):
			&"revive":event.merge({"title":"유닛 부활","icon":"mango","detail":"망고나무 아래에서 되살아났습니다"})
			&"offer":event.merge({"title":"망고 신앙 +1","icon":"mango","detail":"보유 신앙 %d"%int(outcome.faith)})
			&"bless":event.merge({"title":"망고 나무의 축복","icon":"gold","detail":"신앙 %d · +%s G"%[int(outcome.faith_spent),ArenaUI.grouped(int(outcome.gold))]})
	elif action==&"sell":event.merge({"title":"판매 완료","icon":"gold","detail":"+%d G"%int(outcome.gold)})
	elif action in [&"rest",&"event"]:event.merge({"title":"휴식 완료" if action==&"rest" else "이벤트 완료","icon":"rest" if action==&"rest" else "event","detail":outcome_text(outcome)})
	presentation_requested.emit(event)
func _item_name(id: int) -> String:
	var item: ItemInstance=controller.content.inventory.get_item(id)
	return ItemCatalog.of(item).display_name if item!=null else ""
## Blacksmith: 강화 (rare items to +5), 교환 (two basics for one of three rares), 판매 (basics at half price).
func render_blacksmith(node: RoomState) -> void:
	match content_tab:
		"trade":_render_trade(node)
		"sell":_render_sell()
		_:_render_enhance()
func _hint(text: String) -> void:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",13);label.add_theme_color_override("font_color",ArenaUI.MUTED);label.custom_minimum_size.y=48;content_box.add_child(label)
func _grid(columns: int) -> GridContainer:
	var grid:=GridContainer.new();grid.columns=columns;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);content_box.add_child(grid);return grid
## An inventory slot for an owned item, showing who wears it.
func _item_slot(parent: Node,item: ItemInstance,caption: String,callback: Callable) -> ArenaCard:
	var data: ItemData=ItemCatalog.of(item);var owner: GuildMemberState=controller.guild.get_member(item.equipped_to_member_id) if not item.equipped_to_member_id.is_empty() else null
	var card:=ArenaCard.new();card.name="item_%d"%item.item_id;card.card_type="slot";card.slot_kind="equipped" if owner!=null else "equipment";card.kind=String(item.kind);card.title=data.display_name;card.description=data.description;card.text=data.display_name
	card.rarity=ItemCatalog.instance_color(item);card.owner_type=owner.unit_type_id if owner!=null else -1;card.price=caption;card.tooltip_text=data.description
	card.custom_minimum_size=Vector2(60,64);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ArenaUI.bind(card,callback);parent.add_child(card);return card
func _render_enhance() -> void:
	var rares: Array=controller.guild.state.inventory.filter(func(i):return not i.consumed and ItemCatalog.get_item(i.kind).grade==&"rare")
	if rares.is_empty():_hint("강화할 희귀 아이템이 없습니다.\n교환 탭에서 일반 아이템 2개로 희귀 아이템을 만들 수 있습니다.");return
	if not rares.any(func(i):return i.item_id==forge_pick):forge_pick=rares[0].item_id
	_section("희귀 아이템 · 장착 중인 아이템도 강화할 수 있습니다")
	var grid: GridContainer=_grid(4)
	for item in rares:
		var caption: String="최대" if item.enhance>=ItemCatalog.MAX_ENHANCE else "+%d → +%d"%[item.enhance,item.enhance+1]
		var slot: ArenaCard=_item_slot(grid,item,caption,func():forge_pick=item.item_id;call_deferred("render"));slot.selected=item.item_id==forge_pick
	var picked: ItemInstance=controller.content.inventory.get_item(forge_pick);var level: int=picked.enhance
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",ArenaUI.card_style(Color("4b5a86"),Color("121a2c")));content_box.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6);panel.add_child(box)
	var heading_label:=Label.new();heading_label.text=ItemCatalog.of(picked).display_name;heading_label.add_theme_font_override("font",ArenaUI.heading_font());heading_label.add_theme_font_size_override("font_size",16);heading_label.add_theme_color_override("font_color",ItemCatalog.instance_color(picked));box.add_child(heading_label)
	var lines: Array[String]=[]
	if level>=ItemCatalog.MAX_ENHANCE:lines.append("최대 강화 · 스탯 +%d%%"%roundi(ItemCatalog.ENHANCE_BOOST[level]*100));lines.append(ItemCatalog.of(picked).description)
	else:
		lines.append("+%d → +%d · 스탯 +%d%% → +%d%%"%[level,level+1,roundi(ItemCatalog.ENHANCE_BOOST[level]*100),roundi(ItemCatalog.ENHANCE_BOOST[level+1]*100)])
		lines.append("지금 · "+ItemCatalog.of(picked).description);lines.append("강화 후 · "+ItemCatalog.enhanced(picked.kind,level+1).description)
	var detail:=Label.new();detail.text="\n".join(lines);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size",12);detail.add_theme_constant_override("line_spacing",4);box.add_child(detail)
	var go:=Button.new();go.name="Enhance";go.custom_minimum_size.y=46;box.add_child(go)
	if level>=ItemCatalog.MAX_ENHANCE:go.text="최대 강화";go.disabled=true
	else:
		var cost: int=ItemCatalog.ENHANCE_COSTS[level];ArenaUI.price_button(go,"강화","gold",cost);ArenaUI.bind(go,_action.bind(&"enhance",{"item_id":picked.item_id}));go.disabled=controller.guild.state.gold<cost
func _render_trade(node: RoomState) -> void:
	var left: int=TowerContentService.BLACKSMITH_TRADES-int(node.event.purchases.get("trade",0))
	var commons: Array=controller.content.inventory.available().filter(func(i):return ItemCatalog.get_item(i.kind).grade==&"common")
	trade_pick.assign(trade_pick.filter(func(id):return commons.any(func(i):return i.item_id==id)))
	_section("재료 · 일반 아이템 2개   남은 교환 %d / %d"%[left,TowerContentService.BLACKSMITH_TRADES])
	var slots: GridContainer=_grid(2)
	for i in range(2):
		if i<trade_pick.size():
			var id: int=trade_pick[i];_item_slot(slots,controller.content.inventory.get_item(id),"빼기",func():trade_pick.erase(id);call_deferred("render"))
		else:
			var empty:=ArenaCard.new();empty.name="material_%d"%i;empty.card_type="slot";empty.kind="hidden";empty.title="재료 %d"%(i+1);empty.price="아래에서 선택";empty.custom_minimum_size=Vector2(60,64);empty.size_flags_horizontal=Control.SIZE_EXPAND_FILL;empty.mouse_filter=Control.MOUSE_FILTER_IGNORE;slots.add_child(empty)
	if left<=0:_hint("이번 방문의 교환을 모두 사용했습니다.");return
	if trade_pick.size()==2:
		_section("희귀 아이템 3개 중 1개 선택")
		var offers: Array[StringName]=controller.content.trade_offers(trade_pick);var grid: GridContainer=_grid(3)
		for i in range(offers.size()):
			var data: ItemData=ItemCatalog.get_item(offers[i]);var b:=ArenaCard.new();b.name="offer_%d"%i;b.card_type="product";b.kind=String(offers[i]);b.title=data.display_name;b.text=data.display_name+" · 교환"
			b.description=("두 재료의 조합 · " if i==0 else "")+data.description;b.rarity=ItemCatalog.grade_color(offers[i]);b.price="교환";b.custom_minimum_size=Vector2(0,168);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.tooltip_text=data.description
			ArenaUI.bind(b,_action.bind(&"trade",{"items":trade_pick.duplicate(),"kind":offers[i]}));grid.add_child(b)
	else:_hint("재료를 2개 넣으면 희귀 아이템 3개가 제시됩니다.\n하나는 두 재료의 조합 결과, 나머지 둘은 무작위입니다.")
	_section("인벤토리 · 장착하지 않은 일반 아이템")
	var pool: Array=commons.filter(func(i):return not i.item_id in trade_pick)
	if pool.is_empty():_hint("재료로 쓸 일반 아이템이 없습니다.");return
	var grid: GridContainer=_grid(4)
	for item in pool:
		var card: ArenaCard=_item_slot(grid,item,"넣기",func():if trade_pick.size()<2:trade_pick.append(item.item_id);call_deferred("render"))
		card.disabled=trade_pick.size()>=2
func _render_sell() -> void:
	var commons: Array=controller.content.inventory.available().filter(func(i):return ItemCatalog.get_item(i.kind).grade==&"common")
	_section("일반 아이템 판매 · 구매가의 50%")
	if commons.is_empty():_hint("판매할 일반 아이템이 없습니다.\n장착 중인 아이템과 희귀·고대 아이템은 팔 수 없습니다.");return
	var grid: GridContainer=_grid(3)
	for item in commons:
		var data: ItemData=ItemCatalog.get_item(item.kind);var b:=ArenaCard.new();b.name="sell_%d"%item.item_id;b.card_type="product";b.kind=String(item.kind);b.title=data.display_name;b.text=data.display_name+" · 판매"
		b.description=data.description;b.rarity=ItemCatalog.grade_color(item.kind);b.price="+%d G"%ItemCatalog.sell_price(item.kind);b.custom_minimum_size=Vector2(0,168);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.tooltip_text=data.description
		ArenaUI.bind(b,_action.bind(&"sell",{"item_id":item.item_id}));grid.add_child(b)
func _token_detail(outcome: Dictionary) -> String:
	match StringName(outcome.get("choice",&"")):
		&"revive":return "유닛 부활"
		&"heal":return "모든 유닛 HP +5%"
		&"restore":return "HP 전부 회복"
	return _event_reward_text(outcome)
