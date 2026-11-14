class_name CodexScreen
extends Control
## 도감 from the main menu: every unit, item, strategy card, room event, damage tag, boss and
## 상태이상 (StatusCatalog), as a
## card grid (the only part that scrolls) above a fixed detail panel (beside it on wide screens).
## Read-only: built from the same catalogues the game plays with.
signal closed
const TABS = [["unit","유닛"],["item","아이템"],["card","전략카드"],["event","이벤트"],["tag","피해태그"],["status","상태이상"],["boss","보스"]]
## Rooms and events: [key, icon, name, description].
const EVENTS = [
	["battle","battle","전투","적을 모두 쓰러뜨리면 골드와 토큰을 얻는다. 지면 플레이어 HP가 줄고, 남은 적의 상태 그대로 다시 도전할 수 있다."],
	["miniboss","miniboss","미니보스","각 챕터 3층. 정예 적 1명(HP ×2.5 · 공격 ×1.65 · 방어 ×1.5)과 호위가 나온다. 보상 700 G · 토큰 2."],
	["boss","boss","챕터 보스","각 챕터 5층(5 · 10 · 15층). 보스 1명(HP ×3.6 · 공격 ×2.15 · 방어 ×2)과 호위. 보상 1,000 G · 토큰 3, 쓰러뜨리면 다음 챕터가 열린다."],
	["recruit","recruit","길드원 모집","후보 4명 중 토큰으로 영입한다. 후보는 영입 가격(희귀도)별 확률로 뜨고, 리롤은 200 G."],
	["shop","shop","상점","아이템과 전략카드를 골드로 산다. 인벤토리와 강화 탭도 함께 있다."],
	["rest","rest","길드 휴식소","넷 중 하나: 플레이어 HP +15 · 골드 350과 토큰 1 · 생존 유닛 HP +35% · 사망 유닛 최대 3명 부활(HP 20%)."],
	["hotSpring","hotSpring","온천","온천욕(생존 유닛 HP +10%) 또는 200 G 복권(아이템 · 골드 · 토큰 · 전략카드 · 유닛 중 하나)."],
	["supply","supply","보물상자","넷 중 하나: 플레이어 HP +10 · 길드 HP +10% · 골드 300과 토큰 1 · 숨은 보물(아이템 또는 카드)."],
	["prediction","prediction","전투 예측","AI끼리 싸우는 판에 50 · 100 · 200 G를 건다. 맞히면 2배와 토큰 1, 무승부면 원금."],
	["tokenShop","tokenShop","토큰 상점","토큰으로 부활 · 전원 회복 · 무작위 아이템 · 전략카드 · 완전 회복을 산다."],
	["blacksmith","blacksmith","대장장이","희귀 · 영웅 · 전설 아이템을 +5까지 강화하고, 일반 · 희귀 아이템을 상점 가격의 절반에 판다."],
	["mangoSapling","mango","망고나무 묘목","무료 부활 1회. 200 G 재물로 망고 신앙을 쌓고, 신앙이 있으면 축복으로 모두 바꿔 큰 골드를 받는다."],
	["gambler","dice","도박꾼의 방","200 G씩 룰렛(꽝 ~ 1,000 G)과 주사위(3개 합 대결, 이기면 400 G)를 한 번씩."]]
## Damage tags: [key, icon, description].
const TAGS = [
	[&"physical","woodSword","물리 피해량으로 계산하고 방어력 · 물리 방어력으로 줄어든다."],
	[&"magic","staff","마법 피해량으로 계산하고 방어력 · 마법 방어력으로 줄어든다."],
	[&"fire","phoenixFeather","화염 공격은 50% 확률로 화염 2스택(최대 10). 0.5초마다 1스택씩 타며 지속 피해를 주고, 불붙은 유닛 곁의 아군도 그을린다(스택은 옮지 않음)."],
	[&"ice","ether","얼음 공격은 50% 확률로 빙결 1스택(4초간 새로 안 쌓이면 녹음). 10스택이면 4초 기절, 풀리면 4초 동상: 받는 피해 +10%, 빙결 대신 추가 피해 5. 빙결·동상 중엔 쌓이지 않는다."],
	[&"lightning","charge","번개 피해마다 감전 1스택, 5스택이면 2초 기절(기절 중엔 쌓이지 않음). 번개 공격은 준 피해의 60%를 가까운 다른 적에게 최대 5번 튕긴다."],
	[&"poison","verdantStone","맹독 공격은 50% 확률로 맹독 1스택. 스택은 전투 내내 남아 매초 스택당 1 마법 지속 피해. 중독된 유닛은 주는·받는 치유 -40%."],
	[&"wind","hawkFeather","바람 공격마다 기류 스택(최대 10): 공격속도 +5%, 바람 피해 +3%씩. 직접 공격에 HP가 깎이면 0(지속 피해·보호막은 제외). 맞은 적은 2초간 둔화·공격속도 -20%."],
	[&"light","star","빛 피해의 10%만큼 공격한 유닛 주변 아군(자신 포함) 회복. 맞은 적에 광휘 표식, 다른 유닛이 직접 공격으로 터뜨리면 그 유닛이 최대 HP 5% 회복."],
	[&"dark","skull","맞으면 2초 침식: 이동 외 행동(공격·패링·회피·궁극기)마다 마법 피해 6, 받는 치명타 피해 +25%. 어둠 표식을 다른 유닛이 직접 공격으로 터뜨리면 그 공격 피해 +20%."],
	[&"explosion","dragonHeart","폭발 태그. 폭발 피해 보너스가 붙는다."],
	[&"area","event","범위 태그. 여러 적을 한 번에 맞히는 공격."],
	[&"projectile","evade","투사체 태그. 날아가 맞히는 공격."],
	[&"dot","hourglass","지속 태그. 시간을 두고 반복해서 맞히는 공격."],
	[&"melee","woodSword","근접공격 태그. 가까이 붙어 베고 찌르고 치는 공격."]]
var tab: String = "unit"
var selected: String = ""
var tab_buttons: Dictionary = {}
var grid: GridContainer
var scroll: ScrollContainer
var body: BoxContainer
var detail: PanelContainer
var detail_icon: Control
var detail_title: Label
var detail_sub: Label
var detail_text: Label
var detail_units: HFlowContainer
var detail_action: Button
var icon_kind: String = ""
var icon_unit: int = -1
## Unit whose full info sheet the detail panel's button opens (-1: none).
var info_type: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme = ArenaUI.get_theme()
	var back := ColorRect.new();back.color = ArenaUI.BACKGROUND;back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(back)
	var margin := MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left", "right", "top", "bottom"]:margin.add_theme_constant_override("margin_" + side, 14)
	ArenaUI.safe_margin(margin)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 8);margin.add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var title := Label.new();title.text = "도감";title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;title.add_theme_font_override("font", ArenaUI.heading_font());title.add_theme_font_size_override("font_size", 22);header.add_child(title)
	TitleFx.attach(title, "CODEX").play()
	header.add_child(ArenaUI.nav_button("close", func():closed.emit()))
	var tabs := GridContainer.new();tabs.name = "Tabs";tabs.columns = TABS.size() if get_viewport_rect().size.x >= 600 else 4;tabs.add_theme_constant_override("h_separation", 6);tabs.add_theme_constant_override("v_separation", 6);column.add_child(tabs)
	for pair in TABS:
		var button := Button.new();button.text = pair[1];button.toggle_mode = true;button.custom_minimum_size.y = 36;button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ArenaUI.tab(button);button.pressed.connect(show_tab.bind(pair[0]));tabs.add_child(button);tab_buttons[pair[0]] = button
	# The grid scrolls; the detail panel stays put (below on a phone, beside on a wide screen).
	var wide: bool = get_viewport_rect().size.x >= 700
	body = HBoxContainer.new() if wide else VBoxContainer.new();body.size_flags_vertical = Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation", 10);column.add_child(body)
	scroll = ScrollContainer.new();scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	grid = GridContainer.new();grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation", 6);grid.add_theme_constant_override("v_separation", 6);scroll.add_child(grid)
	_build_detail(wide)
	show_tab("unit")

func _build_detail(wide: bool) -> void:
	detail = PanelContainer.new();detail.name = "Detail";detail.add_theme_stylebox_override("panel", ArenaUI.card_style(Color("4b5a86"), Color("121a2c")))
	detail.custom_minimum_size = Vector2(340, 0) if wide else Vector2(0, 214);body.add_child(detail)
	var box := VBoxContainer.new();box.add_theme_constant_override("separation", 6);detail.add_child(box)
	var top := HBoxContainer.new();top.add_theme_constant_override("separation", 10);box.add_child(top)
	detail_icon = Control.new();detail_icon.custom_minimum_size = Vector2(52, 52);detail_icon.draw.connect(_draw_detail_icon);top.add_child(detail_icon)
	var names := VBoxContainer.new();names.size_flags_horizontal = Control.SIZE_EXPAND_FILL;names.alignment = BoxContainer.ALIGNMENT_CENTER;top.add_child(names)
	detail_title = Label.new();detail_title.add_theme_font_override("font", ArenaUI.heading_font());detail_title.add_theme_font_size_override("font_size", 18);names.add_child(detail_title)
	detail_sub = Label.new();detail_sub.add_theme_font_size_override("font_size", 12);detail_sub.add_theme_color_override("font_color", ArenaUI.MUTED);names.add_child(detail_sub)
	detail_action = Button.new();detail_action.text = "상세 정보";detail_action.custom_minimum_size = Vector2(96, 40);ArenaUI.secondary(detail_action);top.add_child(detail_action)
	ArenaUI.bind(detail_action, func():if info_type >= 0:UnitInfoSheet.open(self, info_type))
	detail_text = Label.new();detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;detail_text.add_theme_font_size_override("font_size", 13);detail_text.add_theme_color_override("font_color", Color("dfe6f6"));box.add_child(detail_text)
	detail_units = HFlowContainer.new();detail_units.add_theme_constant_override("h_separation", 4);detail_units.add_theme_constant_override("v_separation", 4);box.add_child(detail_units)

func _draw_detail_icon() -> void:
	var c := Vector2(26, 26)
	if icon_unit >= 0:
		detail_icon.draw_circle(c, 25, Color("0b1120"));UnitIcon.draw(detail_icon, Rect2(c - Vector2(22, 22), Vector2(44, 44)), icon_unit)
		detail_icon.draw_arc(c, 25, 0, TAU, 40, UnitRarity.color(icon_unit), 2, true)
	elif not icon_kind.is_empty():
		detail_icon.draw_circle(c, 25, Color("0b1120"));detail_icon.draw_arc(c, 25, 0, TAU, 40, ArenaUI.GOLD, 1.5, true)
		ArenaIcon.draw(detail_icon, c, icon_kind, 34, Color.WHITE)

func show_tab(key: String) -> void:
	tab = key;selected = ""
	for k in tab_buttons:tab_buttons[k].button_pressed = k == key
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	var width: float = get_viewport_rect().size.x - (380 if get_viewport_rect().size.x >= 700 else 30)
	match key:
		"unit":
			grid.columns = maxi(3, int(width / 80))
			var types: Array = CharacterCatalog.all().keys();types.sort_custom(func(a, b):return [UnitRarity.tier(a), a] < [UnitRarity.tier(b), b])
			for type in types:_unit_card(type, "")
		"boss":
			grid.columns = maxi(3, int(width / 80))
			for type in TowerMapGenerator.BOSS_POOL:_unit_card(type, "boss")
			for type in TowerMapGenerator.FRONT:_unit_card(type, "miniboss")
		"item":
			grid.columns = maxi(4, int(width / 74))
			# Grade order (일반 → 고대), then catalog order within a grade.
			for kind in ItemCatalog.current():
				var data: ItemData = ItemCatalog.get_item(kind)
				var card: ArenaCard = _card(String(kind), "slot", String(kind), data.display_name, ItemCatalog.grade_name(kind), ItemCatalog.grade_color(kind), Vector2(66, 72));card.item_grade = data.grade
		"card":
			grid.columns = maxi(3, int(width / 112))
			for kind in StrategyCardCatalog.DEFINITIONS:
				var data: StrategyCardData = StrategyCardCatalog.get_card(kind)
				var c: ArenaCard = _card(String(kind), "product", String(kind), data.display_name, "%d G" % data.gold_price, Color(0, 0, 0, 0), Vector2(104, 168));c.slot_kind = "card";c.description = data.description;c.rule_text = data.rule_line()
		"event":
			grid.columns = maxi(3, int(width / 96))
			for row in EVENTS:_card(row[0], "slot", row[1], row[2], "", Color(0, 0, 0, 0), Vector2(86, 72))
		"tag":
			grid.columns = maxi(3, int(width / 96))
			for row in TAGS:
				var key_name: StringName = row[0]
				_card(String(key_name), "slot", row[1], UnitStatTable.KIND_NAMES.get(key_name, UnitStatTable.TAG_NAMES.get(key_name, "")), "%d종" % _dealers(key_name).size(), Color("ffd36b") if key_name in UnitStatTable.ELEMENTS else Color(0, 0, 0, 0), Vector2(86, 72))
		"status":
			grid.columns = maxi(3, int(width / 96))
			for kind in StatusCatalog.KIND_ORDER:
				for status in StatusCatalog.ENTRIES:
					var e: Array = StatusCatalog.ENTRIES[status]
					if e[1] == kind:_card(String(status), "slot", e[2], e[0], StatusCatalog.kind_label(status), StatusCatalog.kind_color(status), Vector2(86, 72))
	scroll.scroll_vertical = 0
	if grid.get_child_count() > 0:_select(String(grid.get_child(0).name))

func _unit_card(type: int, rank: String) -> void:
	var data: UnitData = CharacterCatalog.all()[type]
	var card := ArenaCard.new();card.name = ("%s_%d" % [rank, type]) if not rank.is_empty() else str(type);card.card_type = "library";card.type_id = type;card.title = data.display_name;card.price = "";card.kind = rank
	card.text = data.display_name;card.custom_minimum_size = Vector2(72, 88);card.toggle_mode = true;card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ArenaUI.bind(card, _select.bind(String(card.name)));grid.add_child(card)
func _card(key: String, kind: String, icon: String, title: String, caption: String, color: Color, min_size: Vector2) -> ArenaCard:
	var card := ArenaCard.new();card.name = key.replace("+", "_");card.set_meta("key", key);card.card_type = kind;card.kind = icon;card.title = title;card.price = caption;card.rarity = color;card.text = title
	card.custom_minimum_size = min_size;card.size_flags_horizontal = Control.SIZE_EXPAND_FILL;card.toggle_mode = true
	ArenaUI.bind(card, _select.bind(String(card.name)));grid.add_child(card);return card

## Units that deal damage of this kind or tag (any of their damage instances).
func _dealers(tag: StringName) -> Array:
	var out: Array = []
	for type in CharacterCatalog.all():
		for spec in UnitStatTable.instances(type):
			if spec.key == &"transcend":continue
			if spec.kind == tag or tag in spec.tags:out.append(type);break
	return out

func _select(node_name: String) -> void:
	selected = node_name
	for child in grid.get_children():
		child.set_pressed_no_signal(String(child.name) == node_name);child.selected = String(child.name) == node_name;child.queue_redraw()
	var card: ArenaCard = grid.get_node_or_null(NodePath(node_name))
	if card == null:return
	icon_unit = -1;icon_kind = "";info_type = -1;detail_action.visible = false
	for child in detail_units.get_children():child.queue_free()
	var key: String = card.get_meta("key", node_name)
	match tab:
		"unit", "boss":
			var type: int = card.type_id;var data: UnitData = CharacterCatalog.all()[type];icon_unit = type
			detail_title.text = data.display_name
			detail_sub.text = "%s · 영입 %d토큰 · %s 피해" % [UnitRarity.label(type), data.recruit_tokens, CharacterCatalog.damage_label(type)]
			var lines: Array[String] = []
			if tab == "boss":
				lines.append("챕터 보스 후보 · 5 · 10 · 15층 보스 방에 나온다. HP ×3.6 · 공격 ×2.15 · 방어 ×2 · 이동 ×1.12 · 몸집 ×1.85" if card.kind == "boss" else "미니보스(정예) 후보 · 각 챕터 3층에 나온다. HP ×2.5 · 공격 ×1.65 · 방어 ×1.5 · 이동 ×1.08 · 몸집 ×1.5")
			lines.append("“%s”" % UnitLore.story(type))
			lines.append("HP %d · %s" % [int(UnitBalance.max_hp(data)), " / ".join(data.tags)])
			detail_text.text = "\n".join(lines)
			detail_action.visible = true;info_type = type
		"item":
			var data: ItemData = ItemCatalog.get_item(StringName(key));icon_kind = key
			detail_title.text = data.display_name;detail_title.add_theme_color_override("font_color", ItemCatalog.grade_color(StringName(key)))
			var source: String = {&"common":"전투 보상 · 상점(%d G) · 보물상자 · 복권 · 토큰 상점 · 룰렛 · 대장장이 판매 %d G" % [data.gold_price, ItemCatalog.sell_price(StringName(key))], &"rare":"전투 · 미니보스 보상 · 상점(%d G) · 이벤트 · 대장장이 강화(+5) · 판매 %d G" % [data.gold_price, ItemCatalog.sell_price(StringName(key))], &"epic":"전투 · 미니보스 · 보스 보상 · 층 정복 · 상점(%d G) · 대장장이 강화(+5)" % data.gold_price, &"legendary":"전투 · 미니보스 · 보스 보상 · 층 정복 · 상점(%d G) · 대장장이 강화(+5) · 한 런에 하나만" % data.gold_price, &"ancient":"탑에서는 나오지 않음 · 커스텀 전투에서 선택 · 유닛당 1개"}.get(data.grade, "")
			detail_sub.text = "%s 등급" % ItemCatalog.grade_name(StringName(key))
			detail_text.text = "%s\n%s" % [data.description, source]
		"card":
			var data: StrategyCardData = StrategyCardCatalog.get_card(StringName(key));icon_kind = key
			detail_title.text = data.display_name;detail_sub.text = data.rule_line() + " · %d G" % data.gold_price
			detail_text.text = "%s\n소모는 쓰면 사라지고, 일반은 가지고 들어간 전투마다 1번, 쿨타임 N은 쓴 뒤 전투방을 N번 이기면 다시 쓸 수 있다. 전투방 배치 전에 최대 5장을 골라 들고 가고, 터닝포인트에서 패의 카드를 위로 밀어 올려 쓴다. 상점 · 보물상자 · 복권 · 토큰 상점에서 얻는다." % data.description
		"event":
			for row in EVENTS:
				if row[0] == key:icon_kind = row[1];detail_title.text = row[2];detail_text.text = row[3]
			detail_sub.text = "방 종류" if key in ["battle", "miniboss", "boss", "recruit", "shop", "rest"] else "이벤트 방"
		"tag":
			for row in TAGS:
				if String(row[0]) == key:icon_kind = row[1];detail_title.text = card.title + " 피해";detail_text.text = row[2]
			var dealers: Array = _dealers(StringName(key))
			detail_sub.text = ("피해 종류" if key in ["physical", "magic"] else "속성" if StringName(key) in UnitStatTable.ELEMENTS else "피해 태그") + " · 이 피해를 주는 유닛 %d종" % dealers.size()
			for type in dealers.slice(0, 24):
				var face := Control.new();face.custom_minimum_size = Vector2(26, 26);var t: int = type
				face.draw.connect(func():UnitIcon.draw(face, Rect2(Vector2.ZERO, Vector2(26, 26)), t));detail_units.add_child(face)
		"status":
			var e: Array = StatusCatalog.entry(StringName(key));icon_kind = e[2]
			detail_title.text = e[0];detail_title.add_theme_color_override("font_color", StatusCatalog.kind_color(StringName(key)))
			detail_sub.text = "%s · 상태이상" % StatusCatalog.kind_label(StringName(key))
			detail_text.text = "%s\n전투 중 유닛이나 배치 화면의 적 · 아군 · 대기 유닛을 다시 눌러 연 설명창의 '상태' 탭에서 볼 수 있다." % e[3]
	if tab not in ["item", "status"]:detail_title.remove_theme_color_override("font_color")
	detail_icon.queue_redraw()
