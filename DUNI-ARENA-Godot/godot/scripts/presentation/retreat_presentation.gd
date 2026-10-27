class_name RetreatPresentation
extends Control
## Shared ending overlay. The retained class name keeps earlier UI clients compatible.
## Presentation age is owned by CombatPresentation, never by the battle simulation.
const DURATION: float=BattleCinematicState.DURATION
var sequence: BattleCinematicState
var board: DeploymentBoard
var age: float:
	get:return sequence.age if sequence!=null else 0
func _ready() -> void:
	z_index=30;mouse_filter=Control.MOUSE_FILTER_STOP;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hide()
func begin(value: BattleCinematicState,arena_board: DeploymentBoard) -> void:
	sequence=value;board=arena_board;show();queue_redraw()
func _process(_dt: float) -> void:queue_redraw()
## A tap skips straight to the end of the cinematic (the result appears).
func _gui_input(event: InputEvent) -> void:
	if sequence!=null and sequence.active and ((event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed):
		sequence.advance(DURATION);accept_event()
func _draw() -> void:
	if sequence==null or not sequence.started or not is_instance_valid(board):return
	var rect: Rect2=board.board_rect();rect.position+=board.global_position-global_position
	CinematicArtwork.paint(self,rect,sequence.kind,sequence.age)
