class_name BattleStatsView
extends Control
## The result screen's 통계 page: every unit grouped by side, with a bar per unit for the chosen
## metric (가한 피해, 받은 피해, 가한 치유, 받은 치유, 처치, 궁극기) scaled to the largest value.
const ROW_H: float = 44
const GROUP_H: float = 30
var rows: Array = []
var metric: StringName = &"dealt"
var age: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(UiMotion.enabled)
	if not UiMotion.enabled:age = 10

func show_rows(list: Array) -> void:
	rows = list;age = 0 if UiMotion.enabled else 10
	custom_minimum_size.y = _groups().size() * GROUP_H + rows.size() * ROW_H + 6;queue_redraw()

func choose(value: StringName) -> void:
	metric = value;age = 0 if UiMotion.enabled else 10;queue_redraw()

func _process(dt: float) -> void:
	if age < 1:age += dt;queue_redraw()

func _groups() -> Array:
	var out: Array = []
	for row in rows:
		if out.is_empty() or out[-1].label != row.group:out.append({"label": row.group, "color": row.color, "rows": []})
		out[-1].rows.append(row)
	return out

static func value_text(m: StringName, v: float) -> String:
	return str(int(v)) if m in [&"kills", &"ultimates"] else ArenaUI.grouped(roundi(v))

func _draw() -> void:
	var font: Font = get_theme_default_font();var numbers: Font = ArenaUI.numbers_font()
	var top: float = 1.0
	for row in rows:top = maxf(top, float(row[metric]))
	var grow: float = 1 - pow(1 - clampf(age / .55, 0, 1), 3)
	var y: float = 0;var w: float = size.x
	for group in _groups():
		var total: float = 0
		for row in group.rows:total += float(row[metric])
		var tint: Color = group.color
		draw_rect(Rect2(0, y + 6, 4, GROUP_H - 12), tint)
		draw_string(ArenaUI.heading_font(), Vector2(12, y + 21), group.label, HORIZONTAL_ALIGNMENT_LEFT, w * .5, 15, tint.lightened(.35))
		draw_string(font, Vector2(w * .5, y + 20), "합계 " + value_text(metric, total), HORIZONTAL_ALIGNMENT_RIGHT, w * .5 - 4, 12, ArenaUI.MUTED)
		y += GROUP_H
		for row in group.rows:
			var alive: bool = row.alive;var c: Color = row.color;var fade: float = 1.0 if alive else .55
			draw_rect(Rect2(0, y + 2, w, ROW_H - 4), Color(1, 1, 1, .035))
			var at := Vector2(22, y + ROW_H * .5)
			draw_circle(at, 17, Color("0c1220"));UnitIcon.draw(self, Rect2(at - Vector2(14, 14), Vector2(28, 28)), int(row.type), fade)
			draw_arc(at, 17, 0, TAU, 32, Color(c, .9 * fade), 2, true)
			if not alive:draw_line(at + Vector2(-9, -9), at + Vector2(9, 9), ArenaUI.DANGER, 2.5, true);draw_line(at + Vector2(9, -9), at + Vector2(-9, 9), ArenaUI.DANGER, 2.5, true)
			# Name and a small K · 궁 line on the left; the bar fills the rest.
			var name_w: float = clampf(w * .3, 84, 150)
			draw_string(font, Vector2(46, y + 19), String(row.name), HORIZONTAL_ALIGNMENT_LEFT, name_w - 6, 13, Color(ArenaUI.TEXT, fade))
			draw_string(font, Vector2(46, y + 35), "처치 %d · 궁 %d%s" % [int(row.kills), int(row.ultimates), "" if alive else " · 사망"], HORIZONTAL_ALIGNMENT_LEFT, name_w - 6, 11, ArenaUI.DANGER if not alive else ArenaUI.MUTED)
			var bar := Rect2(Vector2(40 + name_w, y + 13), Vector2(maxf(20, w - 40 - name_w - 4), 18))
			draw_rect(bar, Color("0c1220"))
			var share: float = float(row[metric]) / top * grow
			if share > 0:
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), Color(c, .85))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, 4)), Color(c.lightened(.4), .7))
			draw_string(numbers, bar.position + Vector2(6, 14), value_text(metric, float(row[metric]) * grow), HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - 8, 13, Color(1, 1, 1, .95))
			y += ROW_H

## A dialog with metric tabs over a scrolling unit list (the list is the only part that scrolls).
static func make_dialog(host: Control) -> AcceptDialog:
	var dialog := AcceptDialog.new();host.add_child(dialog)
	var col := VBoxContainer.new();col.add_theme_constant_override("separation", 8);dialog.add_child(col)
	ArenaUI.dialog_header(dialog, col, "전투 통계");ArenaModalBackdrop.new().connect_window(dialog, host)
	var tabs := GridContainer.new();tabs.columns = 3;tabs.add_theme_constant_override("h_separation", 6);tabs.add_theme_constant_override("v_separation", 6);col.add_child(tabs)
	var view := BattleStatsView.new();view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group := ButtonGroup.new()
	for m in BattleStats.METRICS:
		var b := Button.new();b.text = BattleStats.LABELS[m];b.toggle_mode = true;b.button_group = group;b.button_pressed = m == &"dealt"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL;b.add_theme_font_size_override("font_size", 12);ArenaUI.tab(b)
		b.toggled.connect(func(on: bool):if on:view.choose(m))
		tabs.add_child(b)
	var scroll := ScrollContainer.new();scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;col.add_child(scroll)
	scroll.add_child(view)
	dialog.set_meta("view", view);dialog.set_meta("tabs", tabs);dialog.set_meta("scroll", scroll)
	return dialog

static func open(dialog: AcceptDialog, host: Control, list: Array) -> void:
	var screen: Vector2 = host.get_viewport_rect().size
	var width: int = mini(560, int(screen.x) - 24);var height: int = mini(680, int(screen.y) - 48)
	var tabs: GridContainer = dialog.get_meta("tabs");tabs.columns = 6 if width >= 520 else 3
	var view: BattleStatsView = dialog.get_meta("view");view.show_rows(list)
	var scroll: ScrollContainer = dialog.get_meta("scroll");scroll.custom_minimum_size = Vector2(width - 40, minf(view.custom_minimum_size.y, height - (130 if tabs.columns == 6 else 170)))
	dialog.popup_centered(Vector2i(width, 0))
