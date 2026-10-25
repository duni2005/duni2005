class_name VisualShapes
extends RefCounted
## Source pixels.js-inspired tapered silhouettes / bolts / textured arena primitives.
static func slash(canvas: CanvasItem,point: Vector2,radius: float,from: float,to: float,color: Color,width: float,alpha: float=1) -> void:
	var points:=PackedVector2Array();var steps: int=24
	for i in range(steps+1):
		var t: float=float(i)/steps;var w: float=width*sin(t*PI*.88)*sqrt(t)
		points.append(point+Vector2.from_angle(lerpf(from,to,t))*(radius+w*.22))
	for i in range(steps,-1,-1):
		var t: float=float(i)/steps;var w: float=width*sin(t*PI*.88)*sqrt(t)
		points.append(point+Vector2.from_angle(lerpf(from,to,t))*(radius-w))
	canvas.draw_colored_polygon(points,Color(color,alpha))
static func streak(canvas: CanvasItem,point: Vector2,angle: float,length: float,width: float,color: Color,alpha: float=1) -> void:
	var d:=Vector2.from_angle(angle);var n:=Vector2(-d.y,d.x)
	canvas.draw_colored_polygon(PackedVector2Array([point-d*length*.65,point+d*length*.1-n*width*.48,point+d*length*.65,point+d*length*.18+n*width*.45]),Color(color,alpha))
static func bolt(canvas: CanvasItem,a: Vector2,b: Vector2,color: Color,seed: float,width: float=3) -> void:
	var points:=PackedVector2Array([a]);var diff: Vector2=b-a;var n:=Vector2(-diff.y,diff.x).normalized()
	for i in range(1,9):points.append(a+diff*(float(i)/9)+n*(VisualParticles.noise(i+seed)*2-1)*10)
	points.append(b);canvas.draw_polyline(points,Color(color,.25),width*3);canvas.draw_polyline(points,color,width);canvas.draw_polyline(points,Color("f3fbff"),maxf(1,width*.35))
	canvas.draw_line(points[3],points[3]+n*14+diff.normalized()*18,Color(color,.6),1.5)
## Meadow arena; `margin` arena units of scenery show around it, fading out. Canopy shade sways.
static func arena(canvas: CanvasItem,margin: float=0) -> void:
	ArenaFloor.draw(canvas,margin,Time.get_ticks_msec()/1000.0)
	if margin<=0:return
	# The scenery darkens towards the edge of the view.
	var clear:=Color("173a35",0);var fade:=Color("173a35",.85)
	var inner:=Rect2(0,0,800,800).grow(margin*.5);var outer:=Rect2(0,0,800,800).grow(margin)
	var a: Array=[inner.position,Vector2(inner.end.x,inner.position.y),inner.end,Vector2(inner.position.x,inner.end.y)]
	var b: Array=[outer.position,Vector2(outer.end.x,outer.position.y),outer.end,Vector2(outer.position.x,outer.end.y)]
	for k in range(4):canvas.draw_polygon(PackedVector2Array([a[k],a[(k+1)%4],b[(k+1)%4],b[k]]),PackedColorArray([clear,clear,fade,fade]))
static func barrier(canvas: CanvasItem,point: Vector2,radius: float,color: Color,age: float) -> void:
	VfxArt.shield(canvas,point,radius,color,age)

static func hit_glyph(canvas: CanvasItem,p: Vector2,a: float,r: float,color: Color,t: float,alpha: float=1) -> void:
	var size: float=r*(1 if t<.22 else .8-t*.5)
	streak(canvas,p,a+.9,size*2.2,size*.35,color,alpha)
	streak(canvas,p,a+.9,size*1.9,size*.13,Color.WHITE,alpha)
	if t<.55:
		streak(canvas,p,a-1.15,size*1.25,size*.21,Color("fff4cb"),alpha);streak(canvas,p,a,size*.8,size*.15,Color.WHITE,alpha)
static func parry(canvas: CanvasItem,p: Vector2,a: float,r: float,t: float) -> void:
	var size: float=r*(.65+.35*sin(t*PI));var alpha: float=1-t
	slash(canvas,p,size,a-1.5,a+1.5,Color("77dbf1"),24,alpha)
	slash(canvas,p,size+4,a-1.25,a+1.3,Color("f4ffff"),8,alpha)
	hit_glyph(canvas,p+Vector2.from_angle(a)*36,a,r*.7,Color("ddfaff"),t,alpha)
static func clash(canvas: CanvasItem,p: Vector2,a: float,r: float,t: float) -> void:
	var flash: float=pow(1-t,1.8);var expand: float=1-pow(1-t,3);var radius: float=r*(.18+.82*expand)
	hit_glyph(canvas,p,a,r*.9,Color("ffc66b"),t,flash)
	if t<.48:hit_glyph(canvas,p,a,r*.62,Color("fff8e0"),t,flash)
	for side in [0,PI]:
		slash(canvas,p,radius,a+side-.7,a+side+.7,Color("ffca79"),maxf(2,15*(1-t)),(1-t)*.85)
		slash(canvas,p,radius+3,a+side-.55,a+side+.55,Color("fff7d7"),maxf(2,4.5*(1-t)),1-t)
