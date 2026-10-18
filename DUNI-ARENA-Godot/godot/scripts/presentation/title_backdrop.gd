class_name TitleBackdrop
extends Control
## Main menu scenery: night sky glow, light rays and the 15-floor tower silhouette.
var time: float=0
var glow: GradientTexture2D
var sky: GradientTexture2D
var fade: GradientTexture2D
func _ready() -> void:
	sky=_vertical(Color("17302c"),ArenaUI.BACKGROUND);fade=_vertical(Color(ArenaUI.BACKGROUND,0),Color(ArenaUI.BACKGROUND,.92))
	var g:=Gradient.new();g.set_color(0,Color(ArenaUI.ACCENT,.34));g.set_color(1,Color(ArenaUI.ACCENT,0));g.add_point(.35,Color(ArenaUI.ACCENT,.12))
	glow=GradientTexture2D.new();glow.gradient=g;glow.fill=GradientTexture2D.FILL_RADIAL;glow.fill_from=Vector2(.5,.5);glow.fill_to=Vector2(1,.5);glow.width=256;glow.height=256
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);resized.connect(queue_redraw)
func _process(dt: float) -> void:
	if is_visible_in_tree():time+=dt;queue_redraw()
func _draw() -> void:
	var w: float=size.x;var h: float=size.y;var cx: float=w*.5
	# Vertical gradient from deep teal to the shared background.
	draw_texture_rect(sky,Rect2(0,0,w,h),false)
	# Warm glow behind the tower top.
	var glow_y: float=h*.2
	var r: float=maxf(w,h)*.55
	draw_texture_rect(glow,Rect2(cx-r,glow_y-r,r*2,r*2),false)
	# Slowly rotating light rays.
	for i in range(12):
		var a: float=time*.05+i*TAU/12
		var tip: Vector2=Vector2(cx,glow_y)+Vector2.from_angle(a)*maxf(w,h)
		var side: Vector2=Vector2.from_angle(a+PI/2)*maxf(w,h)*.06
		draw_colored_polygon(PackedVector2Array([Vector2(cx,glow_y),tip+side,tip-side]),Color(ArenaUI.GOLD,.018))
	# Tower silhouette: 15 floors, narrowing towards the top, a few lit windows.
	var floors: int=15;var base_y: float=h*1.02;var floor_h: float=clampf(h*.032,18,30);var base_w: float=clampf(w*.5,180,420)
	for i in range(floors):
		var t: float=float(i)/floors;var fw: float=base_w*(1-t*.62);var y: float=base_y-(i+1)*floor_h
		var body:=Color(Color("0e1719").lerp(Color("15241f"),t),.8)
		draw_rect(Rect2(cx-fw*.5,y,fw,floor_h-2),body)
		draw_rect(Rect2(cx-fw*.5-4,y+floor_h-4,fw+8,3),Color("1d2d29"))
		var windows: int=maxi(2,int(fw/34))
		for k in range(windows):
			var lit: bool=(i*7+k*3)%5==0
			var wx: float=cx-fw*.5+(k+.5)*fw/windows-3
			draw_rect(Rect2(wx,y+floor_h*.35,6,floor_h*.35),Color(ArenaUI.ACCENT,.28+.14*sin(time*1.6+i+k)) if lit else Color("0a1012",.6))
	# Spire.
	var top_y: float=base_y-floors*floor_h
	draw_colored_polygon(PackedVector2Array([Vector2(cx-base_w*.19,top_y),Vector2(cx+base_w*.19,top_y),Vector2(cx,top_y-floor_h*2.4)]),Color("142420"))
	# Bottom fade so the menu panel reads cleanly over the tower.
	draw_texture_rect(fade,Rect2(0,h*.3,w,h*.7),false)
func _vertical(top: Color,bottom: Color) -> GradientTexture2D:
	var g:=Gradient.new();g.set_color(0,top);g.set_color(1,bottom)
	var t:=GradientTexture2D.new();t.gradient=g;t.fill_from=Vector2(0,0);t.fill_to=Vector2(0,1);t.width=4;t.height=256;return t
