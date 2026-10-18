class_name ArenaCameraController
extends RefCounted
## Read-only spectator framing from dist/spectator.js. No actor/Clock/RNG writes.
const MAX_ZOOM: float=2.2
const PRESENTATION_ZOOM: float=1.12
const VIEW_ZOOM_LIMIT: float=2.5
var offset:=Vector2.ZERO
var strength: float=0
var age: float=0
var zoom: float=1
var pan:=Vector2.ZERO
var center:=Vector2(400,400)
var focus_point:=Vector2(400,400)
var focus_remaining: float=0
var finale_remaining: float=0
var framing: Dictionary={}
var body_bounds: Rect2
var overview_age: float=-1
var overview_zoom: float=1
var overview_center:=Vector2(400,400)
func advance_overview(real_delta: float,duration: float=2.0) -> void:
	# TP's two real-second slowdown reveals the entire logical arena.
	# Read-only camera interpolation; the simulation clock remains authoritative.
	if overview_age<0:overview_age=0;overview_zoom=zoom;overview_center=center
	overview_age+=maxf(0,real_delta)
	var t: float=clampf(overview_age/maxf(.01,duration),0,1);t=t*t*(3-2*t)
	zoom=lerpf(overview_zoom,1,t);center=overview_center.lerp(Vector2(400,400),t)
	pan=(Vector2(400,400)-center)*zoom;offset=Vector2.ZERO;strength=0
static func bounds(rows: Array,padding: float=0,predict: bool=false) -> Rect2:
	var lower:=Vector2(INF,INF);var upper:=Vector2(-INF,-INF)
	for row in rows:
		var at: Vector2=row.position;var velocity: Vector2=row.get("velocity",Vector2.ZERO);var scale: float=row.get("scale",1.0)
		if not at.is_finite() or not velocity.is_finite() or not is_finite(scale):continue
		var ahead: Vector2=at+Vector2(clampf(velocity.x*.25,-55,55),clampf(velocity.y*.25,-55,55)) if predict else at
		var left:=Vector2(32*scale+padding,52*scale+padding);var right:=Vector2(32*scale+padding,36*scale+padding)
		lower=lower.min(at-left).min(ahead-left);upper=upper.max(at+right).max(ahead+right)
	return Rect2(lower,upper-lower) if lower.is_finite() else Rect2()
static func framing_for(rows: Array) -> Dictionary:
	var box: Rect2=bounds(rows,48,true)
	if box.size==Vector2.ZERO:return {}
	return {"center":box.get_center(),"zoom":minf(MAX_ZOOM,800/maxf(1,maxf(box.size.x,box.size.y)))}
func set_framing(rows: Array) -> void:
	framing=framing_for(rows);body_bounds=bounds(rows,12)
	if not framing.is_empty():framing.zoom=minf(VIEW_ZOOM_LIMIT,float(framing.zoom)*PRESENTATION_ZOOM)
func impact(value: float,point: Vector2) -> void:
	strength=maxf(strength,minf(value,12));age=0;focus_point=point
func focus(point: Vector2,duration: float=.7) -> void:
	focus_point=point;focus_remaining=duration
func finish(point: Vector2) -> void:
	focus_point=point;finale_remaining=1.55
func advance(real_delta: float,paused: bool=false) -> void:
	overview_age=-1
	var dt: float=maxf(0,real_delta)
	age+=dt;strength=maxf(0,strength-dt*22);focus_remaining=maxf(0,focus_remaining-dt)
	if paused:
		offset=Vector2.ZERO;zoom=1;pan=Vector2.ZERO;center=Vector2(400,400);return
	var finale: bool=finale_remaining>0
	finale_remaining=maxf(0,finale_remaining-dt)
	offset=(Vector2(sin(age*61),cos(age*47))*.7+(Vector2(400,400)-focus_point).normalized()*.3)*strength
	if not framing.is_empty() or finale:
		var target: Vector2=focus_point if finale else framing.center
		var target_zoom: float=2.8 if finale else framing.zoom
		center=center.lerp(target,1-exp(-dt*(8 if finale else 2.7)))
		var rate: float=8 if finale else 5 if target_zoom<zoom else 1.5
		zoom=lerpf(zoom,target_zoom,1-exp(-dt*rate))
		if not finale and body_bounds.size!=Vector2.ZERO:
			var edge: float=maxf(maxf(center.x-body_bounds.position.x,body_bounds.end.x-center.x),maxf(center.y-body_bounds.position.y,body_bounds.end.y-center.y))
			zoom=minf(zoom,400/maxf(1,edge))
		pan=(Vector2(400,400)-center)*zoom
	else:
		# Standalone impact/focus remains useful for preview and isolated effects.
		zoom=lerpf(zoom,1.028 if focus_remaining>0 else 1,clampf(dt*12,0,1))
		pan=(Vector2(400,400)-focus_point)*(.025 if focus_remaining>0 else 0)
func transform() -> Transform2D:
	return Transform2D(0,Vector2.ONE*zoom,0,Vector2(400,400)*(1-zoom)+offset+pan)
func reset() -> void:
	overview_age=-1;zoom=1;pan=Vector2.ZERO;offset=Vector2.ZERO;strength=0;focus_remaining=0;finale_remaining=0;age=0;center=Vector2(400,400);focus_point=center;framing.clear();body_bounds=Rect2()
