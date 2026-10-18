class_name BattleCinematicState
extends RefCounted
## Detached presentation data. Never resumes a stopped battle or changes an actor.
const CAMERA_DURATION: float=1.25
const BRAKE_START: float=.6
const BRAKE_END: float=1.85
const DIM_START: float=1.85
const TITLE_START: float=2.4
const DURATION: float=3.6
var kind: String="victory"
var age: float=0
var started: bool=false
var units: Array[Dictionary]=[]
var projectiles: Array[Dictionary]=[]
var active: bool:
	get:return started and age<DURATION
var complete: bool:
	get:return started and age>=DURATION
func begin(value: String,actors: Array[Dictionary],arrows: Array[Dictionary]) -> void:
	if started:return
	kind=value;units=actors.duplicate(true);projectiles=arrows.duplicate(true);age=0;started=true
func advance(dt: float) -> void:
	if started:age=minf(DURATION,age+maxf(0,dt))
static func motion_seconds(time: float) -> float:
	var early: float=minf(maxf(0,time),BRAKE_START)*.6
	var length: float=BRAKE_END-BRAKE_START
	var t: float=clampf((time-BRAKE_START)/length,0,1)
	return early+.6*length*(t-pow(t,3)+.5*pow(t,4))
func position_for(row: Dictionary) -> Vector2:
	var point: Vector2=row.position+row.velocity*motion_seconds(age)
	var scale: float=row.get("scale",1.0)
	return point.clamp(Vector2(32,52)*scale,Vector2(800,800)-Vector2(32,36)*scale)
func release_visuals() -> void:
	units.clear();projectiles.clear()
