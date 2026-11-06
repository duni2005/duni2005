class_name UnitInfoSheet
extends Control
## Unit description sheet that slides up from the bottom: portrait, name, a one-line story, base
## and special stats as small icon + value chips, the unit's traits, basic attack, passive,
## ultimate and transcendence. Each skill can unfold its damage instances (kind, tags, base +
## ratio and the damage expected from the current stats). Opened by tapping an already selected
## unit; closes on the backdrop or ✕.
## With a `subject` (a unit on the field, a placed enemy, or a guild member waiting to be placed)
## the sheet has two tabs: 유닛 정보 and 상태 — current HP, ultimate and transcendence gauges and
## every 상태이상 (StatusCatalog) the unit carries; a live battle unit refreshes as it changes.
var type_id: int
var subject = null
var info_body: VBoxContainer
var status_body: VBoxContainer
var tab_buttons: Array[Button] = []
var refresh_wait: float = 0
## True when the subject is a unit on the field (it may be freed when the battle ends).
var live: bool = false
## The tab last chosen, kept for the next sheet.
static var last_tab: String = "info"
var stats: UnitCombatStats
var member: GuildMemberState
var panel: PanelContainer
var backdrop: ColorRect

## Shows the sheet over `host`'s window. `stats`/`member` add the member's own numbers and
## level; without them the unit's base numbers are shown.
static func open(host: Node, unit_type: int, unit_stats: UnitCombatStats = null, unit_member: GuildMemberState = null, unit_subject = null) -> UnitInfoSheet:
	# An owned unit (guild member) always gets the 상태 tab, wherever the sheet is opened from.
	if unit_subject == null and unit_member != null:unit_subject = unit_member
	var sheet := UnitInfoSheet.new();sheet.type_id = unit_type;sheet.stats = unit_stats;sheet.member = unit_member;sheet.subject = unit_subject;sheet.live = unit_subject is BattleUnit
	host.get_window().add_child(sheet)
	return sheet

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 50
	backdrop = ColorRect.new();backdrop.color = Color(0, 0, .02, .6);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(backdrop)
	backdrop.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:close())
	panel = PanelContainer.new()
	# A bottom sheet: the window frame, open at the bottom edge.
	var style: StyleBoxFlat = ArenaUI.window_style();style.corner_radius_bottom_left = 0;style.corner_radius_bottom_right = 0;style.border_width_bottom = 0
	for side in ["left", "right", "top", "bottom"]:style.set("content_margin_" + side, 8 if side in ["left", "right"] else 5)
	panel.add_theme_stylebox_override("panel", style);add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 8);margin.add_theme_constant_override("margin_bottom", 12);panel.add_child(margin)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 10);margin.add_child(column)
	_build(column)
	get_viewport().size_changed.connect(_layout);_layout()
	# Wrapped labels report a tall minimum before their width is known, which stretched the sheet
	# past the screen (the end of the page could not be scrolled into view): fit it again.
	panel.minimum_size_changed.connect(func():call_deferred("_layout"));call_deferred("_layout")
	# Slide up from below.
	if UiMotion.enabled:
		var rest: float = panel.position.y;panel.position.y = size.y;backdrop.modulate.a = 0
		var t := create_tween().set_parallel(true)
		t.tween_property(panel, "position:y", rest, .32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(backdrop, "modulate:a", 1.0, .2)

func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	var w: float = minf(560, view.x);var h: float = minf(view.y * .84, 760)
	var y: float = panel.position.y if panel.position.y > view.y - h + 1 else view.y - h # keep a running slide-up
	panel.size = Vector2(w, h);panel.position = Vector2((view.x - w) * .5, y)

func close() -> void:
	if not UiMotion.enabled:queue_free();return
	var t := create_tween().set_parallel(true)
	t.tween_property(panel, "position:y", get_viewport_rect().size.y, .22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(backdrop, "modulate:a", 0.0, .22)
	t.chain().tween_callback(queue_free)

## "◆◆◆ 희귀" chip in the rarity colour.
func _rarity_chip() -> Control:
	var chip := Control.new();var label: String = UnitRarity.label(type_id);var col: Color = UnitRarity.color(type_id)
	var font: Font = get_theme_default_font();var text_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	chip.custom_minimum_size = Vector2(UnitRarity.pips_width(type_id, 3) + text_w + 19, 20);chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.draw.connect(func():
		chip.draw_style_box(ArenaUI.box(Color(col, .16), Color(col, .7)), Rect2(Vector2.ZERO, chip.size))
		UnitRarity.draw_pips(chip, Vector2(8.4, chip.size.y * .5), type_id, 3)
		chip.draw_string(font, Vector2(UnitRarity.pips_width(type_id, 3) + 12, chip.size.y * .5 + 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col.lightened(.25)))
	return chip

func _build(column: VBoxContainer) -> void:
	var data: UnitData = CharacterCatalog.all()[type_id]
	if stats == null:stats = UnitCombatStats.from_table(data)
	# Grab handle and close button.
	var top := HBoxContainer.new();column.add_child(top)
	var handle := Control.new();handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL;handle.custom_minimum_size.y = 8
	handle.draw.connect(func():handle.draw_style_box(ArenaUI.box(Color("3a4a74"), Color.TRANSPARENT), Rect2(Vector2(handle.size.x * .5 - 2, 2), Vector2(44, 5))));top.add_child(handle)
	var close_button := ArenaUI.nav_button("close", close);close_button.custom_minimum_size = Vector2(40, 40);top.add_child(close_button)
	# Header: portrait, name, level line, damage type.
	var head := HBoxContainer.new();head.add_theme_constant_override("separation", 12);column.add_child(head)
	var portrait := Control.new();portrait.custom_minimum_size = Vector2(72, 72)
	portrait.draw.connect(func():
		var c := Vector2(36, 36)
		# The ring takes the unit's rarity colour.
		var ring: Color = UnitRarity.color(type_id)
		VfxArt.glow(portrait, c, 46, ring, .18 + .04 * UnitRarity.tier(type_id))
		portrait.draw_circle(c, 34, Color("0b1120"));UnitIcon.draw(portrait, Rect2(c - Vector2(30, 30), Vector2(60, 60)), type_id)
		portrait.draw_arc(c, 34, 0, TAU, 48, ring, 2.5, true))
	head.add_child(portrait)
	var names := VBoxContainer.new();names.size_flags_horizontal = Control.SIZE_EXPAND_FILL;names.add_theme_constant_override("separation", 2);names.alignment = BoxContainer.ALIGNMENT_CENTER;head.add_child(names)
	var name_label := Label.new();name_label.text = data.display_name + ("  " + "★".repeat(member.stars) if member != null and member.stars > 0 else "")
	name_label.add_theme_font_override("font", ArenaUI.heading_font());name_label.add_theme_font_size_override("font_size", 22);name_label.add_theme_color_override("font_color", ArenaUI.GOLD)
	var title_row := HBoxContainer.new();title_row.add_theme_constant_override("separation", 8);title_row.add_child(name_label);title_row.add_child(_rarity_chip());names.add_child(title_row)
	var line := Label.new();line.add_theme_font_size_override("font_size", 12);line.add_theme_color_override("font_color", ArenaUI.MUTED)
	line.text = ("%s · Lv.%d" % [ArenaUI.member_label(member.member_id), member.level] if member != null else "기본 능력치") + "  ·  " + CharacterCatalog.damage_label(type_id) + " 피해"
	names.add_child(line)
	var story := Label.new();story.text = "“%s”" % UnitLore.story(type_id);story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;story.add_theme_font_size_override("font_size", 13);story.add_theme_color_override("font_color", Color("c9d2ea"));names.add_child(story)
	if subject != null:
		var tabs := HBoxContainer.new();tabs.add_theme_constant_override("separation", 6);column.add_child(tabs)
		for pair in [["info", "유닛 정보"], ["status", "상태"]]:
			var b := Button.new();b.text = pair[1];b.toggle_mode = true;b.custom_minimum_size.y = 36;b.size_flags_horizontal = Control.SIZE_EXPAND_FILL;b.set_meta("tab", pair[0]);ArenaUI.tab(b)
			b.pressed.connect(_show_tab.bind(pair[0]));tabs.add_child(b);tab_buttons.append(b)
	# Everything below the header scrolls.
	var scroll := ScrollContainer.new();scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER;column.add_child(scroll)
	var pages := VBoxContainer.new();pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL;scroll.add_child(pages)
	var body := VBoxContainer.new();body.size_flags_horizontal = Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation", 10);pages.add_child(body);info_body = body
	status_body = VBoxContainer.new();status_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL;status_body.add_theme_constant_override("separation", 8);pages.add_child(status_body)
	_stat_sections(body, data)
	var traits: Array = TacticalMind.trait_names(data).filter(func(t):return UnitLore.TRAITS.has(t))
	var trait_text: String = "\n".join(traits.map(func(t):return "[b]%s[/b]  %s" % [t, UnitLore.TRAITS[t]]))
	if member != null:trait_text += "\n[color=#8fe3ff]현재 성향 · %s[/color]  %s" % [ArenaUI.stance(member.stance), ArenaUI.STANCE_HELP.get(member.stance, "")]
	body.add_child(_section("guild", "행동성향", trait_text, Color("8fe3ff")))
	body.add_child(_section("battle", "기본공격", UnitLore.attack(type_id), Color("f3d48e"), _instances(&"basic"), UnitLore.effects(type_id, &"basic")))
	body.add_child(_section("evade", "패시브", UnitLore.passive(type_id), Color("9fe08a"), _instances(&"passive"), UnitLore.effects(type_id, &"passive")))
	body.add_child(_section("charge", "궁극기", UnitLore.ultimate(type_id), Color("c49dff"), _instances(&"ultimate"), UnitLore.effects(type_id, &"ultimate")))
	body.add_child(_section("star", "초월 스킬", UnitLore.TRANSCENDENCE, Color("ff9ec4"), _instances(&"transcend")))
	# Units on the field reopen on the last tab; owned or placed units start on 유닛 정보.
	_show_tab(last_tab if live else "info")

func _show_tab(key: String) -> void:
	if subject == null:key = "info"
	else:last_tab = key
	for b in tab_buttons:b.set_pressed_no_signal(b.get_meta("tab") == key)
	info_body.visible = key == "info";status_body.visible = key == "status"
	if key == "status":_render_status()

## A live battle unit's status follows the fight while the 상태 tab is open.
func _process(dt: float) -> void:
	if not live or not is_instance_valid(subject) or status_body == null or not status_body.visible:return
	refresh_wait += dt
	if refresh_wait >= .3:refresh_wait = 0;_render_status()

## Current HP / ultimate / transcendence gauges, then every 상태이상 with its kind, value and a line
## of explanation.
func _render_status() -> void:
	for child in status_body.get_children():status_body.remove_child(child);child.queue_free()
	if live and not is_instance_valid(subject):return
	var data: UnitData = CharacterCatalog.all()[type_id]
	var hp: float = 0;var hp_max: float = 1;var ult = null;var trans = null
	if subject is BattleUnit:
		hp = subject.current_hp;hp_max = subject.max_hp;ult = subject.ultimate_gauge;trans = subject.transcendence_gauge
	elif subject is GuildMemberState:
		hp = subject.current_hp;hp_max = stats.max_hp;ult = subject.ultimate_gauge;trans = subject.transcendence_gauge
	elif subject is EnemyRoomState:
		hp = subject.current_hp;hp_max = subject.max_hp(data);ult = subject.ultimate_gauge
	if data.ultimate_windup < 0:ult = null
	var dead: bool = subject is BattleUnit and not subject.alive
	status_body.add_child(_heading("현재 상태" + ("  ·  사망" if dead else ""), null))
	status_body.add_child(_gauge("heart", "HP", hp, hp_max, "%s / %s" % [ArenaUI.number(hp), ArenaUI.number(hp_max)], Color("7fe0a0")))
	status_body.add_child(_gauge("charge", "궁극기", float(ult) if ult != null else 0.0, 100, "%d%%" % roundi(float(ult)) if ult != null else "없음", Color("ffe28a") if ult != null and float(ult) >= 100 else Color("c49dff")))
	status_body.add_child(_gauge("star", "초월", float(trans) if trans != null else 0.0, 100, "%d%%" % roundi(float(trans)) if trans != null else "—", Color("ff9ec4")))
	var rows: Array[Dictionary] = StatusCatalog.collect(subject, stats, type_id)
	status_body.add_child(_heading("상태이상  %d" % rows.size(), null))
	if rows.is_empty():
		var none := Label.new();none.text = "걸려 있는 상태이상이 없습니다.";none.add_theme_font_size_override("font_size", 13);none.add_theme_color_override("font_color", ArenaUI.MUTED);status_body.add_child(none)
	for row in rows:status_body.add_child(_status_row(row.key, row.value))

func _gauge(icon: String, caption: String, value: float, maximum: float, text: String, tint: Color) -> Control:
	var bar := Control.new();bar.custom_minimum_size = Vector2(0, 30);bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func():
		var font: Font = get_theme_default_font()
		ArenaIcon.draw(bar, Vector2(11, 15), icon, 18, Color.WHITE)
		bar.draw_string(font, Vector2(26, 20), caption, HORIZONTAL_ALIGNMENT_LEFT, 60, 12, ArenaUI.MUTED)
		var track := Rect2(Vector2(78, 9), Vector2(maxf(10, bar.size.x - 78 - 92), 12))
		bar.draw_style_box(ArenaUI.box(Color("0b111d"), Color("26324f")), track)
		var fill: float = clampf(value / maxf(.001, maximum), 0, 1)
		if fill > 0:bar.draw_rect(Rect2(track.position + Vector2(1, 1), Vector2((track.size.x - 2) * fill, track.size.y - 2)), tint)
		bar.draw_string(ArenaUI.numbers_font(), Vector2(bar.size.x - 86, 21), text, HORIZONTAL_ALIGNMENT_RIGHT, 86, 14, Color("eef1fa")))
	return bar

func _status_row(key: StringName, value: String) -> PanelContainer:
	var tint: Color = StatusCatalog.kind_color(key);var e: Array = StatusCatalog.entry(key)
	var card := PanelContainer.new()
	var style: StyleBoxFlat = ArenaUI.box(Color("0c1322"), Color(tint, .3));style.border_width_left = 3;style.content_margin_left = 10;style.content_margin_right = 10;style.content_margin_top = 6;style.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 2);card.add_child(column)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation", 6);column.add_child(row)
	var glyph := Control.new();glyph.custom_minimum_size = Vector2(18, 18);glyph.draw.connect(func():ArenaIcon.draw(glyph, Vector2(9, 9), e[2], 16, tint));row.add_child(glyph)
	var title := Label.new();title.text = e[0];title.add_theme_font_override("font", ArenaUI.heading_font());title.add_theme_font_size_override("font_size", 14);title.add_theme_color_override("font_color", Color("eef1fa"));row.add_child(title)
	row.add_child(_chip(StatusCatalog.kind_label(key), tint))
	var spacer := Control.new();spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(spacer)
	if not value.is_empty():
		var v := Label.new();v.text = value;v.add_theme_font_override("font", ArenaUI.numbers_font());v.add_theme_font_size_override("font_size", 15);v.add_theme_color_override("font_color", tint.lightened(.2));row.add_child(v)
	var text := Label.new();text.text = e[3];text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;text.add_theme_font_size_override("font_size", 12);text.add_theme_color_override("font_color", Color("b9c3dc"));column.add_child(text)
	return card
func _instances(skill: StringName) -> Array:
	return UnitStatTable.instances(type_id).filter(func(d):return d.skill == skill)

## Base stats, four to a row; the special stats unfold under them with "전체 보기".
func _stat_sections(body: VBoxContainer, data: UnitData) -> void:
	var interval: float = data.attack_interval / stats.attack_speed
	var none: bool = data.attack_interval <= 0 or data.attack_range <= 0
	var base: Array = [
		["heart", "최대 HP", ArenaUI.number(stats.max_hp)], ["woodSword", "공격력", _pct(stats.attack)], ["woodSword", "물리 피해", ArenaUI.number(stats.physical_damage)], ["staff", "마법 피해", ArenaUI.number(stats.magic_damage)],
		["shield", "방어력", ArenaUI.number(stats.defense + stats.armor)], ["leatherArmor", "물리 방어력", ArenaUI.number(stats.physical_defense)], ["defense", "마법 방어력", ArenaUI.number(stats.magic_defense)], ["boots", "이동속도", ArenaUI.number(stats.speed)],
		["hawkFeather", "공격속도", "—" if none else String.num(1.0 / interval, 2)], ["flag", "사거리", "—" if none else ArenaUI.number(data.attack_range)], ["redThorn", "치명타 확률", _pct(stats.crit)], ["fang", "치명타 피해량", _pct(stats.crit_damage)],
	]
	var extra := VBoxContainer.new();extra.add_theme_constant_override("separation", 6);extra.visible = false
	var more := Button.new();more.text = "전체 보기";more.flat = true;more.custom_minimum_size = Vector2(80, 32);more.add_theme_font_size_override("font_size", 12);more.add_theme_color_override("font_color", Color("8fe3ff"))
	more.pressed.connect(func():extra.visible = not extra.visible;more.text = "접기" if extra.visible else "전체 보기")
	body.add_child(_heading("기본 스탯", more))
	body.add_child(_grid(base))
	body.add_child(extra)
	var special: Array = [["warmNecklace", "주는 치유량", _pct(stats.healing_power)], ["greenNecklace", "받는 치유량", _pct(stats.healing_received)], ["charge", "궁극기 피해량", _pct(stats.ult_damage)], ["currentOrb", "궁극기 충전률", _pct(stats.ultimate_power)], ["ether", "속성 피해", _pct(stats.element_power)]]
	var folded: Array = []
	for tag in UnitStatTable.ELEMENTS + UnitStatTable.DAMAGE_TAGS:
		var value: float = float(stats.element_bonus.get(tag, 0)) + float(stats.tag_bonus.get(tag, 0))
		(special if not is_zero_approx(value) else folded).append(["ether" if tag in UnitStatTable.ELEMENTS else "dragonHeart", UnitStatTable.TAG_NAMES[tag] + " 피해", "+" + _pct(value)])
	# Special stats (all of them, bonuses at 0% included) only after 전체 보기.
	extra.add_child(_heading("특수 스탯", null))
	extra.add_child(_grid(special + folded))
func _pct(value: float) -> String:return "%d%%" % roundi(value * 100)
func _heading(text: String, side: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new();label.text = text;label.size_flags_horizontal = Control.SIZE_EXPAND_FILL;label.add_theme_font_override("font", ArenaUI.heading_font());label.add_theme_font_size_override("font_size", 14);label.add_theme_color_override("font_color", ArenaUI.MUTED);row.add_child(label)
	if side != null:row.add_child(side)
	return row
## Small icon + value chips, four to a row.
func _grid(rows: Array) -> GridContainer:
	var grid := GridContainer.new();grid.columns = 4;grid.add_theme_constant_override("h_separation", 4);grid.add_theme_constant_override("v_separation", 4)
	for row in rows:grid.add_child(_stat_chip(row[0], row[1], row[2]))
	return grid
func _stat_chip(icon: String, caption: String, value: String) -> Control:
	var chip := Control.new();chip.custom_minimum_size = Vector2(0, 36);chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.draw.connect(func():
		chip.draw_style_box(ArenaUI.box(Color("0c1322"), Color("26324f")), Rect2(Vector2.ZERO, chip.size))
		ArenaIcon.draw(chip, Vector2(11, chip.size.y * .5), icon, 13, Color.WHITE)
		chip.draw_string(get_theme_default_font(), Vector2(21, 14), caption, HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 22, 9, ArenaUI.MUTED)
		chip.draw_string(ArenaUI.numbers_font(), Vector2(21, 30), value, HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 22, 13, Color("eef1fa")))
	return chip
## A titled card: icon, coloured title, wrapped text (BBCode allowed); with damage instances, a
## "자세히 보기" toggle unfolds one row per instance.
func _section(icon: String, title: String, text: String, tint: Color, instances: Array = [], effects: Array = []) -> PanelContainer:
	var card := PanelContainer.new()
	var style: StyleBoxFlat = ArenaUI.box(Color("0c1322"), Color(tint, .35));style.border_width_left = 3;style.content_margin_left = 12;style.content_margin_right = 10;style.content_margin_top = 8;style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 4);card.add_child(column)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation", 6);column.add_child(row)
	var glyph := Control.new();glyph.custom_minimum_size = Vector2(18, 18);glyph.draw.connect(func():ArenaIcon.draw(glyph, Vector2(9, 9), icon, 16, tint));row.add_child(glyph)
	var heading := Label.new();heading.text = title;heading.add_theme_font_override("font", ArenaUI.heading_font());heading.add_theme_font_size_override("font_size", 15);heading.add_theme_color_override("font_color", tint);row.add_child(heading)
	# Plain wrapped labels: a fitted RichTextLabel reported too little height for long texts, so
	# the end of the sheet could not be scrolled to. "[b]x[/b]" marks a line's bold lead-in and
	# "[color=#rrggbb]...[/color]" a coloured line.
	# The first line is the summary; "• " lines are one effect each, a little smaller and indented.
	for line in text.split("\n"):
		var tint_line: Color = Color("eef1fa")
		var plain: String = line
		var colour := RegEx.create_from_string("^\\[color=(#[0-9a-fA-F]{6})\\](.*)\\[/color\\]$").search(plain)
		if colour != null:tint_line = Color(colour.get_string(1));plain = colour.get_string(2)
		plain = plain.replace("[b]", "").replace("[/b]", " ·")
		var bullet: bool = plain.begins_with("• ")
		if plain == "없음":tint_line = ArenaUI.MUTED
		var label := Label.new();label.text = plain;label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 12 if bullet else 13);label.add_theme_color_override("font_color", Color("c9d2ea") if bullet else tint_line)
		if bullet:
			var indent := MarginContainer.new();indent.add_theme_constant_override("margin_left", 6);indent.add_child(label);column.add_child(indent)
		else:column.add_child(label)
	if instances.is_empty() and effects.is_empty():return card
	var heading_spacer := Control.new();heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(heading_spacer)
	var list := VBoxContainer.new();list.visible = false;list.add_theme_constant_override("separation", 6);column.add_child(list)
	list.add_child(HSeparator.new())
	for d in instances:list.add_child(_instance_row(d))
	for e in effects:list.add_child(_effect_row(e))
	var more := Button.new();more.text = "자세히 보기";more.flat = true;more.custom_minimum_size = Vector2(88, 32);more.add_theme_font_size_override("font_size", 12);more.add_theme_color_override("font_color", tint)
	more.pressed.connect(func():list.visible = not list.visible;more.text = "접기" if list.visible else "자세히 보기")
	row.add_child(more)
	return card
## One damage instance: name, kind and tag chips, "base + N% of the damage stat" and the damage
## expected from the current stats before the target's defense.
func _instance_row(d: Dictionary) -> Control:
	var box := VBoxContainer.new();box.add_theme_constant_override("separation", 3)
	var line := HFlowContainer.new();line.add_theme_constant_override("h_separation", 4);line.add_theme_constant_override("v_separation", 4);box.add_child(line)
	var title := Label.new();title.text = d.label;title.add_theme_font_size_override("font_size", 13);title.add_theme_color_override("font_color", Color("eef1fa"));line.add_child(title)
	line.add_child(_chip(UnitStatTable.KIND_NAMES[d.kind], Color("ff9f68") if d.kind == &"physical" else Color("7fb2ff")))
	for tag in d.tags:line.add_child(_chip(UnitStatTable.TAG_NAMES[tag], Color("ffd36b") if tag in UnitStatTable.ELEMENTS else Color("a9b6d6")))
	var stat_name: String = UnitStatTable.KIND_NAMES[d.kind] + " 피해"
	var parts: Array = []
	if d.base > 0:parts.append(ArenaUI.number(d.base))
	if d.ratio > 0:parts.append("%s의 %d%%" % [stat_name, roundi(d.ratio * 100)])
	var formula := Label.new();formula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;formula.add_theme_font_size_override("font_size", 12);formula.add_theme_color_override("font_color", ArenaUI.MUTED)
	formula.text = "%s  →  예상 %d" % [" + ".join(parts), roundi(UnitStatTable.estimate(d, stats, stats.physical_damage, stats.magic_damage))]
	box.add_child(formula)
	return box
## One heal / shield / buff / debuff / control effect: its name, a kind chip and the numbers.
const EFFECT_COLORS = {"회복": Color("7fe0a0"), "보호막": Color("8fd0ff"), "강화": Color("ffd36b"), "약화": Color("ff7f8a"), "제어": Color("ffb05e"), "기타": Color("a9b6d6")}
func _effect_row(e: Array) -> Control:
	var box := VBoxContainer.new();box.add_theme_constant_override("separation", 3)
	var line := HFlowContainer.new();line.add_theme_constant_override("h_separation", 4);line.add_theme_constant_override("v_separation", 4);box.add_child(line)
	var title := Label.new();title.text = e[2];title.add_theme_font_size_override("font_size", 13);title.add_theme_color_override("font_color", Color("eef1fa"));line.add_child(title)
	line.add_child(_chip(e[1], EFFECT_COLORS.get(e[1], Color("a9b6d6"))))
	var detail := Label.new();detail.text = e[3];detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_size_override("font_size", 12);detail.add_theme_color_override("font_color", ArenaUI.MUTED);box.add_child(detail)
	return box
func _chip(text: String, tint: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var style: StyleBoxFlat = ArenaUI.box(Color(tint, .14), Color(tint, .6));style.content_margin_left = 6;style.content_margin_right = 6;style.content_margin_top = 1;style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new();label.text = text;label.add_theme_font_size_override("font_size", 11);label.add_theme_color_override("font_color", tint);chip.add_child(label)
	return chip
