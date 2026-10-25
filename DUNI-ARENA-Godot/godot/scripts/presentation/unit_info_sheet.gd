class_name UnitInfoSheet
extends Control
## Unit description sheet that slides up from the bottom: portrait, name, a one-line story, every
## stat as a small icon and value, the unit's traits, basic attack, passive, ultimate and
## transcendence. Opened by tapping an already selected unit; closes on the backdrop or ✕.
var type_id: int
var stats: UnitCombatStats
var member: GuildMemberState
var panel: PanelContainer
var backdrop: ColorRect

## Shows the sheet over `host`'s window. `stats`/`member` add the member's own numbers and
## level; without them the unit's base numbers are shown.
static func open(host: Node, unit_type: int, unit_stats: UnitCombatStats = null, unit_member: GuildMemberState = null) -> UnitInfoSheet:
	var sheet := UnitInfoSheet.new();sheet.type_id = unit_type;sheet.stats = unit_stats;sheet.member = unit_member
	host.get_window().add_child(sheet)
	return sheet

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;z_index = 50
	backdrop = ColorRect.new();backdrop.color = Color(0, 0, .02, .6);backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(backdrop)
	backdrop.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:close())
	panel = PanelContainer.new()
	var style: StyleBoxFlat = ArenaUI.box(Color("111a2c"), Color("3a4a74"));style.corner_radius_top_left = 18;style.corner_radius_top_right = 18;style.corner_radius_bottom_left = 0;style.corner_radius_bottom_right = 0
	style.border_width_bottom = 0;style.shadow_color = Color(0, 0, 0, .5);style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style);add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 8);margin.add_theme_constant_override("margin_bottom", 12);panel.add_child(margin)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 10);margin.add_child(column)
	_build(column)
	get_viewport().size_changed.connect(_layout);_layout()
	# Slide up from below.
	if UiMotion.enabled:
		var rest: float = panel.position.y;panel.position.y = size.y;backdrop.modulate.a = 0
		var t := create_tween().set_parallel(true)
		t.tween_property(panel, "position:y", rest, .32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(backdrop, "modulate:a", 1.0, .2)

func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	var w: float = minf(560, view.x);var h: float = minf(view.y * .84, 760)
	panel.size = Vector2(w, h);panel.position = Vector2((view.x - w) * .5, view.y - h)

func close() -> void:
	if not UiMotion.enabled:queue_free();return
	var t := create_tween().set_parallel(true)
	t.tween_property(panel, "position:y", get_viewport_rect().size.y, .22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(backdrop, "modulate:a", 0.0, .22)
	t.chain().tween_callback(queue_free)

func _build(column: VBoxContainer) -> void:
	var data: UnitData = CharacterCatalog.all()[type_id]
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
		VfxArt.glow(portrait, c, 46, ArenaUI.GOLD, .18)
		portrait.draw_circle(c, 34, Color("0b1120"));UnitIcon.draw(portrait, Rect2(c - Vector2(30, 30), Vector2(60, 60)), type_id)
		portrait.draw_arc(c, 34, 0, TAU, 48, ArenaUI.GOLD, 2.5, true))
	head.add_child(portrait)
	var names := VBoxContainer.new();names.size_flags_horizontal = Control.SIZE_EXPAND_FILL;names.add_theme_constant_override("separation", 2);names.alignment = BoxContainer.ALIGNMENT_CENTER;head.add_child(names)
	var name_label := Label.new();name_label.text = data.display_name + ("  " + "★".repeat(member.stars) if member != null and member.stars > 0 else "")
	name_label.add_theme_font_override("font", ArenaUI.heading_font());name_label.add_theme_font_size_override("font_size", 22);name_label.add_theme_color_override("font_color", ArenaUI.GOLD);names.add_child(name_label)
	var line := Label.new();line.add_theme_font_size_override("font_size", 12);line.add_theme_color_override("font_color", ArenaUI.MUTED)
	line.text = ("%s · Lv.%d" % [ArenaUI.member_label(member.member_id), member.level] if member != null else "기본 능력치") + "  ·  " + CharacterCatalog.damage_label(type_id) + " 피해"
	names.add_child(line)
	var story := Label.new();story.text = "“%s”" % UnitLore.story(type_id);story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;story.add_theme_font_size_override("font_size", 13);story.add_theme_color_override("font_color", Color("c9d2ea"));names.add_child(story)
	# Everything below the header scrolls.
	var scroll := ScrollContainer.new();scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER;column.add_child(scroll)
	var body := VBoxContainer.new();body.size_flags_horizontal = Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation", 10);scroll.add_child(body)
	body.add_child(_stats_grid(data))
	var traits: Array = Array(data.tags).filter(func(t):return UnitLore.TRAITS.has(t))
	var trait_text: String = "\n".join(traits.map(func(t):return "[b]%s[/b]  %s" % [t, UnitLore.TRAITS[t]]))
	if member != null:trait_text += "\n[color=#8fe3ff]현재 성향 · %s[/color]  %s" % [ArenaUI.stance(member.stance), ArenaUI.STANCE_HELP.get(member.stance, "")]
	body.add_child(_section("guild", "행동성향", trait_text, Color("8fe3ff")))
	body.add_child(_section("battle", "기본공격", UnitLore.attack(type_id), Color("f3d48e")))
	body.add_child(_section("evade", "패시브", UnitLore.passive(type_id), Color("9fe08a")))
	body.add_child(_section("charge", "궁극기", UnitLore.ultimate(type_id), Color("c49dff")))
	body.add_child(_section("star", "초월 스킬", UnitLore.TRANSCENDENCE, Color("ff9ec4")))

## All stats as small icon + value chips, four to a row.
func _stats_grid(data: UnitData) -> GridContainer:
	var grid := GridContainer.new();grid.columns = 4;grid.add_theme_constant_override("h_separation", 6);grid.add_theme_constant_override("v_separation", 6)
	var hp: float = stats.max_hp if stats != null else data.max_hp
	var attack: float = stats.attack if stats != null else data.attack
	var defense: float = stats.defense if stats != null else data.defense_power
	var speed: float = stats.speed if stats != null else data.move_speed
	var interval: float = data.attack_interval / (stats.attack_speed if stats != null else 1.0)
	var crit: float = data.critical_chance + (stats.crit if stats != null else 0.0)
	var magic: bool = CharacterCatalog.damage_kind(type_id) == &"magic"
	var rows: Array = [
		["heart", "HP", ArenaUI.number(hp)], ["woodSword", "공격력", ArenaUI.number(attack)], ["shield", "방어력", ArenaUI.number(defense)], ["boots", "이동속도", ArenaUI.number(speed)],
		["flag", "사거리", "—" if data.attack_interval <= 0 or data.attack_range <= 0 else ArenaUI.number(data.attack_range)], ["hawkFeather", "공격 간격", "—" if data.attack_interval <= 0 else "%.2f초" % interval],
		["redThorn", "치명타", "%d%%" % roundi(crit * 100)], ["staff" if magic else "woodSword", "피해 유형" if CharacterCatalog.element(type_id) == &"" else "피해 · " + CharacterCatalog.ELEMENT_NAMES[CharacterCatalog.element(type_id)], "마법" if magic else "물리"],
	]
	if stats != null:rows.append_array([["currentOrb", "궁극 위력", "%d%%" % roundi(stats.ultimate_power * 100)], ["leatherArmor", "추가 방어", ArenaUI.number(stats.armor)], ["warmNecklace", "치유량", "%d%%" % roundi(stats.healing_power * 100)], ["ether", "원소 위력", "%d%%" % roundi(stats.element_power * 100)]])
	for row in rows:grid.add_child(_stat_chip(row[0], row[1], row[2]))
	return grid
func _stat_chip(icon: String, caption: String, value: String) -> Control:
	var chip := Control.new();chip.custom_minimum_size = Vector2(0, 44);chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.draw.connect(func():
		chip.draw_style_box(ArenaUI.box(Color("0c1322"), Color("26324f")), Rect2(Vector2.ZERO, chip.size))
		ArenaIcon.draw(chip, Vector2(15, chip.size.y * .5), icon, 18, Color.WHITE)
		chip.draw_string(get_theme_default_font(), Vector2(28, 17), caption, HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 30, 10, ArenaUI.MUTED)
		chip.draw_string(ArenaUI.numbers_font(), Vector2(28, 36), value, HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 30, 15, Color("eef1fa")))
	return chip
## A titled card: icon, coloured title, wrapped text (BBCode allowed).
func _section(icon: String, title: String, text: String, tint: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var style: StyleBoxFlat = ArenaUI.box(Color("0c1322"), Color(tint, .35));style.border_width_left = 3;style.content_margin_left = 12;style.content_margin_right = 10;style.content_margin_top = 8;style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 4);card.add_child(column)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation", 6);column.add_child(row)
	var glyph := Control.new();glyph.custom_minimum_size = Vector2(18, 18);glyph.draw.connect(func():ArenaIcon.draw(glyph, Vector2(9, 9), icon, 16, tint));row.add_child(glyph)
	var heading := Label.new();heading.text = title;heading.add_theme_font_override("font", ArenaUI.heading_font());heading.add_theme_font_size_override("font_size", 15);heading.add_theme_color_override("font_color", tint);row.add_child(heading)
	var label := RichTextLabel.new();label.bbcode_enabled = true;label.fit_content = true;label.scroll_active = false;label.text = text;label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 13);label.add_theme_font_size_override("bold_font_size", 13);label.add_theme_color_override("default_color", Color("dfe6f7"));column.add_child(label)
	return card
