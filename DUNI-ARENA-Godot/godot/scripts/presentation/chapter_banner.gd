class_name ChapterBanner
extends Control
## Tower map divider that opens each five-floor chapter.
var chapter: int=1
func _ready() -> void:
	custom_minimum_size.y=34;mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _draw() -> void:
	var font: Font=ArenaUI.numbers_font();var text: String="CHAPTER %d"%chapter;var fs: int=16
	var tw: float=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x;var cx: float=size.x*.5;var y: float=size.y*.5
	draw_line(Vector2(4,y),Vector2(cx-tw*.5-14,y),Color(ArenaUI.GOLD,.35),1)
	draw_line(Vector2(cx+tw*.5+14,y),Vector2(size.x-4,y),Color(ArenaUI.GOLD,.35),1)
	for side in [-1,1]:
		var d: Vector2=Vector2(cx+side*(tw*.5+8),y)
		draw_colored_polygon(PackedVector2Array([d+Vector2(0,-4),d+Vector2(4,0),d+Vector2(0,4),d+Vector2(-4,0)]),ArenaUI.GOLD)
	draw_string(font,Vector2(cx-tw*.5,y+fs*.36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,ArenaUI.GOLD)
