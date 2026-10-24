class_name KillFeed
extends Control
## Kill log rows, drawn in free screen space next to the arena so they never cover the field:
## the gap above the arena (under `above`), else under `below` (e.g. the battle toolbar), else
## beside the arena; only a screen with no room at all falls back to the arena's bottom corner.
const ROW_H: float = 28
const GAP: float = 4
const ROWS: int = 3
var board: DeploymentBoard
var below: Control
var above: Control
var rows: int = ROWS
var inside: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;top_level = true;z_index = 5

func _process(_dt: float) -> void:
	var p: CombatPresentation = board.presentation if is_instance_valid(board) else null
	if p != null:p.external_kill_feed = true
	visible = p != null and is_instance_valid(p.battle) and board.is_visible_in_tree() and not p.kill_notices.is_empty() and p.battle.clock.state == BattleClock.State.NORMAL and not p.battle.finished
	if visible:_place();queue_redraw()

func _place() -> void:
	# The field as actually painted (camera zoom included), clipped to the board.
	var view: Vector2 = get_viewport_rect().size;var p: CombatPresentation = board.presentation
	var xform: Transform2D = p.get_global_transform() * p.parent_transform
	var arena := Rect2(xform.origin, Vector2(800, 800) * xform.get_scale()).intersection(board.get_global_rect())
	var width: float = minf(330, minf(view.x - 16, arena.size.x));var x: float = arena.get_center().x - width * .5
	inside = false
	# Free gaps, best first: above the arena (down to `above` or the board's top), below `below`.
	var top: float = above.get_global_rect().end.y + 4 if is_instance_valid(above) and above.is_visible_in_tree() else board.get_global_rect().position.y
	var under: float = below.get_global_rect().end.y + 8 if is_instance_valid(below) and below.is_visible_in_tree() else INF
	var field_top: float = arena.position.y
	var gaps: Array = [[field_top - 4 - top, true], [view.y - 8 - under, false]]
	for gap in gaps:
		rows = mini(ROWS, int((float(gap[0]) + GAP) / (ROW_H + GAP)))
		if rows >= 1:
			size = Vector2(width, rows * (ROW_H + GAP))
			position = Vector2(x, field_top - 4 - size.y if gap[1] else under);return
	rows = ROWS
	if view.x - arena.end.x >= 210:
		width = minf(300, view.x - arena.end.x - 20);position = Vector2(arena.end.x + 10, arena.position.y + 8)
	else:
		inside = true;rows = 2;width = minf(250, arena.size.x - 16);position = Vector2(arena.end.x - width - 8, arena.position.y + arena.size.y - rows * (ROW_H + GAP) - 6)
	size = Vector2(width, rows * (ROW_H + GAP))

func _draw() -> void:
	var p: CombatPresentation = board.presentation
	var font: Font = ArenaUI.heading_font();var small: Font = get_theme_default_font()
	for i in range(mini(rows, p.kill_notices.size())):
		var row: Dictionary = p.kill_notices[i];var age: float = float(row.age)
		var enter: float = clampf(age / .18, 0, 1);var alpha: float = minf(enter, clampf((3.2 - age) / .45, 0, 1)) * (.85 if inside else 1.0)
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
