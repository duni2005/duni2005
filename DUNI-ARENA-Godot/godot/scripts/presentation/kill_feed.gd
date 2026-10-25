class_name KillFeed
extends Control
## The latest kill as one fixed-size capsule in the status line above the field, between the
## "전투 중" label and the clock. A new kill slides in from above and pushes the previous one out.
const ROW_H: float = 24
const MAX_W: float = 250
const LEFT_TEXT: float = 54 # "전투 중" / "일시정지"
const CLOCK_W: float = 92
const SLIDE: float = .22
var board: DeploymentBoard
var status: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;top_level = true;z_index = 5

func _process(_dt: float) -> void:
	var p: CombatPresentation = board.presentation if is_instance_valid(board) else null
	if p != null:p.external_kill_feed = true
	visible = p != null and is_instance_valid(p.battle) and is_instance_valid(status) and status.is_visible_in_tree() and not p.kill_notices.is_empty() and p.battle.clock.state == BattleClock.State.NORMAL and not p.battle.finished
	if visible:_place();queue_redraw()

func _place() -> void:
	var line: Rect2 = status.get_global_rect();var x0: float = line.position.x + LEFT_TEXT;var x1: float = line.end.x - CLOCK_W
	var width: float = minf(MAX_W, x1 - x0)
	size = Vector2(width, ROW_H);position = Vector2((x0 + x1 - width) * .5, line.get_center().y - ROW_H * .5)

func _draw() -> void:
	var p: CombatPresentation = board.presentation if is_instance_valid(board) else null
	if p == null or p.kill_notices.is_empty():return
	var newest: Dictionary = p.kill_notices[0]
	var slide: float = clampf(float(newest.age) / SLIDE, 0, 1);slide = 1 - pow(1 - slide, 3)
	if p.kill_notices.size() > 1 and slide < 1:_row(p.kill_notices[1], ROW_H * .9 * slide, 1 - slide)
	_row(newest, -ROW_H * .9 * (1 - slide), minf(slide, clampf((3.2 - float(newest.age)) / .45, 0, 1)))

func _row(row: Dictionary, dy: float, alpha: float) -> void:
	if alpha <= 0:return
	var rect := Rect2(Vector2(0, dy), size);var mid: float = rect.size.x * .5;var y: float = rect.get_center().y
	var killer: Color = row.get("source_color", Color("a9c9f0"));var victim: Color = row.get("target_color", ArenaUI.DANGER)
	var bg: StyleBoxFlat = ArenaUI.box(Color(.035, .05, .085, .92 * alpha), Color(1, 1, 1, .1 * alpha));bg.set_corner_radius_all(int(ROW_H * .5));draw_style_box(bg, rect)
	# Team colour washes in from each end towards the middle.
	var inset: float = ROW_H * .5
	for side in [[killer, 0.0], [victim, 1.0]]:
		var edge: float = lerpf(inset, rect.size.x - inset, side[1]);var c: Color = side[0]
		draw_polygon(PackedVector2Array([Vector2(edge, rect.position.y + 2), Vector2(mid, rect.position.y + 2), Vector2(mid, rect.end.y - 2), Vector2(edge, rect.end.y - 2)]),
			PackedColorArray([Color(c, .3 * alpha), Color(c, 0), Color(c, 0), Color(c, .3 * alpha)]))
	var font: Font = ArenaUI.heading_font();var icon: float = ROW_H - 6;var space: float = mid - 14 - icon - 10
	# Killer on the left.
	if int(row.source) >= 0:
		var at := Vector2(3 + icon * .5, y)
		draw_circle(at, icon * .5 + 1, Color(killer, alpha));UnitIcon.draw_team(self, Rect2(at - Vector2.ONE * icon * .5, Vector2.ONE * icon), int(row.source), killer, alpha)
		draw_string(font, Vector2(icon + 9, y + 4.5), String(row.source_name), HORIZONTAL_ALIGNMENT_LEFT, space, 12, Color(killer.lightened(.5), alpha))
	else:draw_string(font, Vector2(12, y + 4.5), "쓰러짐", HORIZONTAL_ALIGNMENT_LEFT, space, 12, Color(ArenaUI.MUTED, alpha))
	# A gold slash between them.
	draw_line(Vector2(mid - 5, y + 6), Vector2(mid + 5, y - 6), Color(ArenaUI.GOLD, alpha), 2.5, true)
	draw_line(Vector2(mid - 3, y + 7), Vector2(mid + 7, y - 5), Color(1, 1, 1, .35 * alpha), 1, true)
	# Victim on the right, struck through.
	var at := Vector2(rect.size.x - 3 - icon * .5, y)
	draw_circle(at, icon * .5 + 1, Color(victim, .7 * alpha));UnitIcon.draw_team(self, Rect2(at - Vector2.ONE * icon * .5, Vector2.ONE * icon), int(row.target), victim, alpha * .75)
	draw_line(at + Vector2(-icon * .32, -icon * .32), at + Vector2(icon * .32, icon * .32), Color(1, .35, .3, .9 * alpha), 2, true)
	draw_string(get_theme_default_font(), Vector2(mid + 14, y + 4.5), String(row.target_name), HORIZONTAL_ALIGNMENT_RIGHT, space, 12, Color(victim.lightened(.35), .9 * alpha))
