class_name UnitIcon
extends RefCounted
## Original EMOJIS/type rim colors baked with the bundled color font. UI only.
static var icons: Dictionary={}
static func texture(type: int) -> Texture2D:
	if not icons.has(type):icons[type]=load("res://assets/ui/unit-icons/%02d.png"%type)
	return icons[type]
static func draw(canvas: CanvasItem,rect: Rect2,type: int,alpha: float=1) -> void:
	canvas.draw_texture_rect(texture(type),rect,false,Color(1,1,1,alpha))
## Paint over the icon's built-in character-coloured rim with another colour (team colour).
## The rim sits at about 43-48 of the 96 px icon radius.
static func draw_ring(canvas: CanvasItem,rect: Rect2,color: Color,alpha: float=1) -> void:
	var d: float=minf(rect.size.x,rect.size.y)
	canvas.draw_arc(rect.get_center(),d*.462,0,TAU,48,Color(color,alpha),maxf(1.5,d*.07),true)
## Icon with a team-coloured rim.
static func draw_team(canvas: CanvasItem,rect: Rect2,type: int,color: Color,alpha: float=1) -> void:
	draw(canvas,rect,type,alpha);draw_ring(canvas,rect,color,alpha)
