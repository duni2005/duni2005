class_name KillFeed
extends Control
## Kill log rows at the top-right corner of the painted field, compact and team-coloured.
const ROW_H: float = 26
const GAP: float = 4
const ROWS: int = 3
var board: DeploymentBoard

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;top_level = true;z_index = 5

func _process(_dt: float) -> void:
	var p: CombatPresentation = board.presentation if is_instance_valid(board) else null
	if p != null:p.external_kill_feed = true
	visible = p != null and is_instance_valid(p.battle) and board.is_visible_in_tree() and not p.kill_notices.is_empty() and p.battle.clock.state == BattleClock.State.NORMAL and not p.battle.finished
	if visible:_place();queue_redraw()

func _place() -> void:
	# The field as actually painted (camera zoom included), clipped to the board.
	var p: CombatPresentation = board.presentation;var xform: Transform2D = p.get_global_transform() * p.parent_transform
	var field := Rect2(xform.origin, Vector2(800, 800) * xform.get_scale()).intersection(board.get_global_rect())
	var width: float = minf(240, field.size.x * .62)
	size = Vector2(width, ROWS * (ROW_H + GAP));position = Vector2(field.end.x - width - 8, field.position.y + 8)

func _draw() -> void:
	var p: CombatPresentation = board.presentation
	var font: Font = ArenaUI.heading_font();var small: Font = get_theme_default_font()
	for i in range(mini(ROWS, p.kill_notices.size())):
		var row: Dictionary = p.kill_notices[i];var age: float = float(row.age)
		var enter: float = clampf(age / .18, 0, 1);var alpha: float = minf(enter, clampf((3.2 - age) / .45, 0, 1))
		var rect := Rect2(Vector2((1 - enter) * 18, i * (ROW_H + GAP)), Vector2(size.x, ROW_H))
		var killer: Color = row.get("source_color", Color("a9c9f0"));var victim: Color = row.get("target_color", ArenaUI.DANGER)
		var bg: StyleBoxFlat = ArenaUI.box(Color(.035, .05, .085, .9 * alpha), Color(killer, .55 * alpha));bg.set_corner_radius_all(9);draw_style_box(bg, rect)
		draw_rect(Rect2(rect.position + Vector2(0, 5), Vector2(3, ROW_H - 10)), Color(killer, alpha))
		var half: float = rect.size.x * .5;var icon: float = ROW_H - 8
		if int(row.source) >= 0:
			UnitIcon.draw_team(self, Rect2(rect.position + Vector2(8, 4), Vector2.ONE * icon), int(row.source), killer, alpha)
			draw_string(font, rect.position + Vector2(12 + icon, ROW_H * .5 + 5), String(row.source_name), HORIZONTAL_ALIGNMENT_LEFT, half - icon - 26, 13, Color(killer.lightened(.35), alpha))
		ArenaIcon.draw(self, rect.position + Vector2(half, ROW_H * .5), "battle", 16, Color(1, 1, 1, alpha))
		UnitIcon.draw_team(self, Rect2(rect.position + Vector2(rect.size.x - 8 - icon, 4), Vector2.ONE * icon), int(row.target), victim, alpha * .9)
		draw_string(small, rect.position + Vector2(half + 14, ROW_H * .5 + 5), String(row.target_name), HORIZONTAL_ALIGNMENT_RIGHT, half - icon - 30, 12, Color(victim.lightened(.2), alpha * .85))
