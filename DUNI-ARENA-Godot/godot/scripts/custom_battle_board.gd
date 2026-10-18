class_name CustomBattleBoard
extends DeploymentBoard
## Custom battle map: tap empty ground to place, drag a unit to move it, tap a unit to open it.
## Battle rendering, camera and effects are inherited from DeploymentBoard unchanged.
signal empty_tapped(point: Vector2)
signal unit_tapped(id: int)
signal unit_moved(id: int, point: Vector2)
var setup: CustomBattleSetup
var drag_unit: int = -1
var drag_point := Vector2.ZERO

func pointer_down(local: Vector2, id: int) -> void:
	if setup == null or not board_rect().has_point(local):return
	var point: Vector2 = logical_point(local)
	pointer_id = id;drag_origin = point;dragged = false
	drag_unit = setup.hit(point);drag_point = point
func pointer_motion(local: Vector2, id: int) -> void:
	if drag_unit < 0 or id != pointer_id:return
	var point: Vector2 = logical_point(local)
	# Same 6px dead zone as the web drag, measured in screen pixels.
	if not dragged and (point - drag_origin).length() * board_rect().size.x / 800.0 < 6:return
	dragged = true;drag_point = setup.clamp_point(point);queue_redraw()
func pointer_up(local: Vector2, id: int, canceled: bool = false) -> void:
	if id != pointer_id:return
	var point: Vector2 = logical_point(local)
	var unit: int = drag_unit;drag_unit = -1;pointer_id = -2
	if canceled:queue_redraw();return
	if unit >= 0:
		if dragged:unit_moved.emit(unit, drag_point)
		else:unit_tapped.emit(unit)
	elif board_rect().has_point(local) and (point - drag_origin).length() < 20:empty_tapped.emit(setup.clamp_point(point))
	dragged = false;queue_redraw()

func _draw() -> void:
	if not editing or setup == null:return
	var rect: Rect2 = board_rect()
	draw_set_transform(rect.position, 0.0, Vector2.ONE * rect.size.x / 800.0)
	VisualShapes.arena(self)
	draw_rect(Rect2(40, 40, 720, 720), Color(1, 1, 1, .025))
	draw_rect(Rect2(40, 40, 720, 720), Color("5d6c96"), false, 1.5)
	var font: Font = ThemeDB.fallback_font
	for entry in setup.entries:
		var at: Vector2 = drag_point if dragged and int(entry.id) == drag_unit else entry.position
		var color: Color = CustomBattleSetup.faction_color(CustomBattleSetup.faction_of(entry), int(entry.type))
		draw_circle(at, 31, Color(color, .18));draw_arc(at, 31, 0, TAU, 40, color, 3, true)
		UnitIcon.draw(self, Rect2(at - Vector2.ONE * 25, Vector2.ONE * 50), int(entry.type))
		if entry.stance != CombatStance.NORMAL:
			draw_string(font, at + Vector2(-30, 47), ArenaUI.stance(entry.stance), HORIZONTAL_ALIGNMENT_CENTER, 60, 13, color)
		for i in range(entry.items.size()):
			ArenaIcon.draw(self, at + Vector2(18 - i * 15, -24), String(entry.items[i]), 15, Color.WHITE)
		if dragged and int(entry.id) == drag_unit and setup.crowded(at, drag_unit):
			draw_arc(at, 36, 0, TAU, 40, ArenaUI.DANGER, 2, true)
	draw_set_transform(Vector2.ZERO)
