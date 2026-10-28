class_name ArenaIcon
extends RefCounted
## Local vector pictograms. No emoji font, no dependency on OS glyph rendering.
static var textures: Dictionary={}
static func texture(kind: String) -> Texture2D:
	var key: String={"boss":"crown","miniboss":"skull","heal":"heart","vital":"heart","conquest":"crown","chapterConquest":"crown","promotion":"star","ironDefense":"iron","lightning":"charge","tokens":"gem","token":"gem","tokenShop":"gem","blacksmith":"anvil","enhance":"anvil"}.get(kind,kind)
	if not textures.has(key):
		if "+" in key:textures[key]=_combined(key.get_slice("+",0),key.get_slice("+",1));return textures[key]
		var path: String="res://assets/ui/symbols/"+key+".svg"
		textures[key]=load(path) if ResourceLoader.exists(path) else null
	return textures[key]
## Combined item icon: its two basic components overlapped on a diagonal.
static func _combined(a: String,b: String) -> Texture2D:
	var first: Texture2D=texture(a);var second: Texture2D=texture(b)
	if first==null or second==null:return first
	var out: Image=Image.create(128,128,false,Image.FORMAT_RGBA8)
	for pair in [[first,Vector2i(0,0)],[second,Vector2i(42,42)]]:
		var part: Image=pair[0].get_image();part.decompress();part.convert(Image.FORMAT_RGBA8);part.resize(86,86,Image.INTERPOLATE_BILINEAR)
		out.blend_rect(part,Rect2i(0,0,86,86),pair[1])
	return ImageTexture.create_from_image(out)
static func draw(canvas: CanvasItem,at: Vector2,kind: String,size: float,color: Color) -> void:
	var image: Texture2D=texture(kind)
	if image!=null:
		canvas.draw_texture_rect(image,Rect2(at-Vector2.ONE*size*.5,Vector2.ONE*size),false,Color(1,1,1,color.a));return
	var s: float=size/32
	var x: Vector2=Vector2.RIGHT*s;var y: Vector2=Vector2.DOWN*s
	match kind:
		"clock":
			canvas.draw_arc(at,size*.38,0,TAU,36,color,2*s,true)
			canvas.draw_polyline(PackedVector2Array([at-8*y,at,at+6*x+3*y]),color,2*s,true)
		"battle","miniboss","boss":
			for side in [-1,1]:
				var v: Vector2=Vector2(side,-1).normalized();var n:=Vector2(-v.y,v.x)
				canvas.draw_line(at-v*size*.34,at+v*size*.38,color,3*s)
				canvas.draw_line(at-v*size*.17-n*size*.12,at-v*size*.17+n*size*.12,color,3*s)
			if kind!="battle":canvas.draw_arc(at,size*.48,PI,TAU,12,color,2*s);canvas.draw_rect(Rect2(at+Vector2(-3,-19)*s,Vector2(6,5)*s),color)
		"shop","gold":
			canvas.draw_rect(Rect2(at+Vector2(-12,-7)*s,Vector2(24,20)*s),color,false,2*s)
			canvas.draw_arc(at+Vector2(0,-6)*s,7*s,PI,TAU,12,color,2*s);canvas.draw_line(at-7*y,at+10*y,color,2*s)
		"recruit","guild":
			canvas.draw_circle(at-7*y,6*s,color);canvas.draw_arc(at+12*y,12*s,PI,TAU,16,color,3*s)
		"rest","heal","mango","greenNecklace","vital","vigorTotem":
			canvas.draw_rect(Rect2(at+Vector2(-3,-12)*s,Vector2(6,24)*s),color);canvas.draw_rect(Rect2(at+Vector2(-12,-3)*s,Vector2(24,6)*s),color)
		"event","hidden":
			canvas.draw_arc(at-6*y,7*s,PI,TAU+PI*.5,18,color,3*s);canvas.draw_line(at+Vector2(0,-1)*s,at+Vector2(0,6)*s,color,3*s);canvas.draw_circle(at+12*y,2*s,color)
		"shield","iron","ironDefense":
			var p:=PackedVector2Array([at+Vector2(-12,-12)*s,at+Vector2(12,-12)*s,at+Vector2(10,5)*s,at+Vector2(0,15)*s,at+Vector2(-10,5)*s]);canvas.draw_colored_polygon(p,Color(color,.18));p.append(p[0]);canvas.draw_polyline(p,color,2*s)
		"charge","chargeTotem","lightning":
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(2,-15)*s,at+Vector2(-11,3)*s,at+Vector2(-1,3)*s,at+Vector2(-3,15)*s,at+Vector2(11,-4)*s,at+Vector2(2,-4)*s]),color)
		"boots","evade":
			canvas.draw_polyline(PackedVector2Array([at+Vector2(-7,-14)*s,at+Vector2(4,-14)*s,at+Vector2(4,4)*s,at+Vector2(12,8)*s,at+Vector2(12,13)*s,at+Vector2(-9,13)*s,at+Vector2(-7,-14)*s]),color,3*s)
		"fang","predatorFang","thickAwl":
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-10,-12)*s,at+Vector2(10,-12)*s,at+Vector2(5,4)*s,at+Vector2(-7,15)*s,at+Vector2(-2,-1)*s]),color)
		"taunt":
			canvas.draw_arc(at,size*.35,-PI*.7,PI*.7,22,color,2*s)
			canvas.draw_line(at-9*y,at+5*y,color,4*s);canvas.draw_circle(at+11*y,2*s,color)
			for i in [-1,1]:canvas.draw_line(at+Vector2(i*12,-8)*s,at+Vector2(i*18,-12)*s,color,2*s)
		"reengrave":
			canvas.draw_arc(at,12*s,-PI*.8,PI*.8,24,color,3*s)
			canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-13,-12)*s,at+Vector2(-3,-13)*s,at+Vector2(-8,-4)*s]),color)
		"goldToken":
			canvas.draw_circle(at,12*s,Color(color,.15));canvas.draw_arc(at,12*s,0,TAU,28,color,2*s)
			canvas.draw_rect(Rect2(at-Vector2(3,7)*s,Vector2(6,14)*s),color)
		"locked":
			canvas.draw_arc(at-4*y,8*s,PI,TAU,12,color,2*s);canvas.draw_rect(Rect2(at+Vector2(-11,-4)*s,Vector2(22,17)*s),color,false,2*s);canvas.draw_circle(at+4*y,2*s,color)
		_:
			canvas.draw_arc(at,size*.35,0,TAU,20,color,2*s);canvas.draw_line(at-10*x,at+10*x,color,2*s);canvas.draw_line(at-10*y,at+10*y,color,2*s)
