class_name ArenaFieldBackdrop
extends Control
## The field's surroundings painted behind a battle screen's UI, lined up with the board and the
## battle camera, so the scenery shows all around the square arena instead of the plain screen
## background. Sits just above the screen background and ignores input.
var board: DeploymentBoard

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: Node = get_parent().get_node_or_null("PresentationBackground")
	get_parent().move_child.call_deferred(self, background.get_index() + 1 if background != null else 0)

func _process(_dt: float) -> void:queue_redraw()

func _draw() -> void:
	if not is_instance_valid(board) or not board.is_visible_in_tree():return
	var rect: Rect2 = board.board_rect()
	if rect.size.x < 2:return
	var view := Transform2D(0, Vector2.ONE * rect.size.x / 800, 0, board.global_position - global_position + rect.position)
	if not board.editing and board.presentation != null and is_instance_valid(board.presentation.battle):view = view * board.presentation.camera.transform()
	draw_set_transform_matrix(view)
	VisualShapes.arena(self, ArenaFloor.MARGIN)
	# The screen darkens towards its top and bottom edges, stopping at the visible field.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var field := Rect2(board.global_position - global_position, board.size) if not board.editing else Rect2(board.global_position - global_position + rect.position, rect.size)
	var dark := Color(.03, .05, .1, .85);var clear := Color(dark, 0)
	if field.position.y > 0:draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, field.position.y), Vector2(0, field.position.y)]), PackedColorArray([dark, dark, clear, clear]))
	if field.end.y < size.y:draw_polygon(PackedVector2Array([Vector2(0, field.end.y), Vector2(size.x, field.end.y), size, Vector2(0, size.y)]), PackedColorArray([clear, clear, dark, dark]))
