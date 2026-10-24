class_name TitleLogo
extends Control
## Main menu wordmark with a fanned line-up of starting guild unit icons.
const LINEUP: Array=[2,1,0,5,4]
var time: float=0
func _ready() -> void:
	custom_minimum_size.y=210;mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _process(dt: float) -> void:
	if is_visible_in_tree():time+=dt;queue_redraw()
func _draw() -> void:
	var cx: float=size.x*.5;var font: Font=ArenaUI.numbers_font()
	# Portrait line-up; the centre hero is larger and slightly raised.
	for i in range(LINEUP.size()):
		var offset: int=i-LINEUP.size()/2;var big: bool=offset==0
		var s: float=78.0 if big else 58.0
		var at: Vector2=Vector2(cx+offset*62,70-(10 if big else absi(offset)*-4)+sin(time*1.4+i)*2.5)
		# Same unit icons as everywhere else; the centre one gets a gold halo.
		UnitIcon.draw(self,Rect2(at-Vector2(s+6,s+6)*.5,Vector2(s+6,s+6)),LINEUP[i])
		if big:draw_arc(at,(s+6)*.5+3,0,TAU,48,ArenaUI.GOLD,2.0,true)
	# Wordmark.
	var duni: String="DUNI";var arena: String="ARENA";var fs: int=int(clampf(size.x*.14,44,64))
	var dw: float=font.get_string_size(duni,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x;var aw: float=font.get_string_size(arena,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	var x: float=cx-(dw+aw+10)*.5;var y: float=160+fs*.35
	for shadow in [Vector2(0,4),Vector2(0,2)]:
		draw_string(font,Vector2(x,y)+shadow,duni,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(0,0,0,.45))
		draw_string(font,Vector2(x+dw+10,y)+shadow,arena,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color(0,0,0,.45))
	draw_string(font,Vector2(x,y),duni,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color("eef1fa"))
	draw_string(font,Vector2(x+dw+10,y),arena,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,ArenaUI.ACCENT)
	# Tagline with flanking rules.
	var tag: String="TOWER OF FIFTEEN FLOORS";var ts: int=13;var tw: float=font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,ts).x
	var ty: float=y+22
	draw_string(font,Vector2(cx-tw*.5,ty),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,ts,ArenaUI.GOLD)
	draw_line(Vector2(cx-tw*.5-48,ty-5),Vector2(cx-tw*.5-10,ty-5),Color(ArenaUI.GOLD,.6),1)
	draw_line(Vector2(cx+tw*.5+10,ty-5),Vector2(cx+tw*.5+48,ty-5),Color(ArenaUI.GOLD,.6),1)
