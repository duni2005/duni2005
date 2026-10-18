class_name UnitIcon
extends RefCounted
## Original EMOJIS/type rim colors baked with the bundled color font. UI only.
static var icons: Dictionary={}
static func texture(type: int) -> Texture2D:
	if not icons.has(type):icons[type]=load("res://assets/ui/unit-icons/%02d.png"%type)
	return icons[type]
static func draw(canvas: CanvasItem,rect: Rect2,type: int,alpha: float=1) -> void:
	canvas.draw_texture_rect(texture(type),rect,false,Color(1,1,1,alpha))
