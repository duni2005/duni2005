class_name TowerSceneSurface
extends Control
## Decorative screen-space symbols, ray fan and real-time reveal. No gameplay input.
var director: TowerSceneDirector
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;theme=ArenaUI.get_theme()
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		director.skip_recruit();accept_event()
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE] and director.skip_recruit():get_viewport().set_input_as_handled()
func text(at: Vector2,value: String,font_size: int,color: Color,width: float) -> void:
	draw_multiline_string(get_theme_default_font(),at,value,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,3,color)
func _draw() -> void:
	if director==null:return
	var screen: Vector2=get_viewport_rect().size
	for i in range(director.toasts.size()):
		var item: Dictionary=director.toasts[i];var alpha: float=minf(clampf(item.age/.16,0,1),clampf((2.2-item.age)/.4,0,1));var width: float=minf(340,screen.x-32)
		var box:=Rect2(Vector2((screen.x-width)*.5,screen.y-88-i*64),Vector2(width,56));draw_style_box(ArenaUI.box(Color(.055,.07,.13,alpha*.96),Color(.42,.48,.7,alpha)),box)
		ArenaIcon.draw(self,box.position+Vector2(26,28),item.icon,30,Color(1,1,1,alpha));text(box.position+Vector2(52,24),item.title,14,Color(ArenaUI.GOLD,alpha),width-64)
		if not item.detail.is_empty():text(box.position+Vector2(52,44),item.detail,11,Color(ArenaUI.MUTED,alpha),width-64)
	if director.active.is_empty():_draw_flights();return
	var s: Dictionary=director.active;var t: float=s.age
	if t<0:_draw_flights();return
	var alpha: float=minf(clampf(t/.2,0,1),clampf((s.duration-t)/.8,0,1));var kind: String=s.kind
	if kind=="entry":_draw_entry(s,t,screen);_draw_flights();return
	var strong: bool=kind in ["recruit","promotion","chapterConquest"]
	draw_rect(Rect2(Vector2.ZERO,screen),Color(.02,.025,.055,alpha*(.94 if strong else .72)))
	var center: Vector2=screen*.5+Vector2(0,-18+(1-clampf(t/.3,0,1))*8)
	var accent:=Color("f0d490") if kind!="entry" else Color("c4cdbb")
	for i in range(18 if strong else 10):
		var angle: float=i*TAU/(18 if strong else 10)+t*.035;var reach: float=minf(screen.x,screen.y)*.85
		var points:=PackedVector2Array([center,center+Vector2.from_angle(angle)*reach,center+Vector2.from_angle(angle+.055)*reach])
		draw_colored_polygon(points,Color(accent,alpha*(.035 if strong else .012)))
	for radius in range(90,15,-6):draw_circle(center+Vector2(0,-42),radius,Color(accent,alpha*.008))
	if kind in ["recruit","promotion"]:
		var type: int=s.get("type",0);var spread: float=84*(1-clampf(t/1.1,0,1)) if kind=="promotion" else 0
		if kind=="promotion":
			for side in [-1,1]:CharacterPainter.draw_portrait(self,Rect2(center+Vector2(side*spread-42,-94),Vector2(84,84)),type,alpha*(1-clampf(t/1.4,0,1)))
		CharacterPainter.draw_portrait(self,Rect2(center+Vector2(-60,-115),Vector2(120,120)),type,alpha)
		if kind=="promotion":
			for i in range(int(s.get("stars",1))):ArenaIcon.draw(self,center+Vector2(-12+i*26,-127),"star",24,Color(1,1,1,alpha))
	else:ArenaIcon.draw(self,center+Vector2(0,-54),s.get("icon","crown"),96 if kind=="chapterConquest" else 76,Color(1,1,1,alpha))
	var width: float=minf(660,screen.x-40);var x: float=(screen.x-width)*.5
	text(Vector2(x,center.y+50),s.get("title",""),28 if screen.x<600 else 42,Color("fff2cf",alpha),width)
	text(Vector2(x,center.y+99),s.get("detail",""),15 if screen.x<600 else 21,Color("c4cdbb",alpha),width)
	if kind=="recruit":text(Vector2(x,center.y+151),"터치하여 계속",11,Color(.66,.73,.82,alpha*.8),width)

	_draw_flights()
## Room entry: a cinematic band slides in from the left, holds, then slides out to the right.
func _draw_entry(s: Dictionary,t: float,screen: Vector2) -> void:
	var duration: float=float(s.duration);var enter: float=1-pow(1-clampf(t/.35,0,1),3);var leave: float=pow(clampf((t-(duration-.45))/.45,0,1),3)
	var alpha: float=clampf(t/.15,0,1)*(1-leave)
	draw_rect(Rect2(Vector2.ZERO,screen),Color(.02,.025,.055,.42*alpha))
	var band_h: float=104;var y: float=screen.y*.4-band_h*.5;var shift: float=(enter-1)*screen.x+leave*screen.x
	var band:=Rect2(Vector2(shift,y),Vector2(screen.x,band_h))
	draw_rect(band,Color(.03,.04,.08,.94))
	var sheen: float=fposmod(t*.6,1.4)-.2
	draw_colored_polygon(PackedVector2Array([band.position+Vector2(screen.x*sheen,0),band.position+Vector2(screen.x*sheen+60,0),band.position+Vector2(screen.x*sheen+20,band_h),band.position+Vector2(screen.x*sheen-40,band_h)]),Color(1,.95,.8,.05))
	for edge in [y,y+band_h-2]:draw_rect(Rect2(shift,edge,screen.x,2),Color("f0d490"))
	draw_rect(Rect2(shift,y+6,screen.x,1),Color("f0d490",.35));draw_rect(Rect2(shift,y+band_h-7,screen.x,1),Color("f0d490",.35))
	var left: float=shift+maxf(20,(screen.x-420)*.5)
	VfxArt.glow(self,Vector2(left+38,y+band_h*.5),60,Color("f0d490"),.22)
	ArenaIcon.draw(self,Vector2(left+38,y+band_h*.5),s.get("icon","crown"),54,Color.WHITE)
	var font: Font=ArenaUI.heading_font()
	draw_string(font,Vector2(left+84,y+50),s.get("title",""),HORIZONTAL_ALIGNMENT_LEFT,screen.x-left-100,30 if screen.x<600 else 38,Color("fff2cf"))
	draw_string(get_theme_default_font(),Vector2(left+86,y+78),s.get("detail",""),HORIZONTAL_ALIGNMENT_LEFT,screen.x-left-100,14 if screen.x<600 else 18,Color("c4cdbb"))
func _draw_flights() -> void:
	for flight in director.flights:
		if flight.age<0:continue
		var t: float=clampf(flight.age/flight.duration,0,1);var p: float=t*t;var q: float=1-p
		var at: Vector2=Vector2(flight.origin)*q*q+Vector2(flight.control)*2*q*p+Vector2(flight.destination)*p*p
		var c: Color=Color("ffdb75") if flight.kind=="gold" else Color("92e6ff")
		draw_circle(at,12,Color(c,.12));ArenaIcon.draw(self,at,flight.kind,21*(1-t*.2),Color.WHITE)
		var trail: Vector2=(at-Vector2(flight.destination)).normalized()
		draw_line(at+trail*6,at+trail*17,Color(c,.4),2,true)
	for spark in director.sparks:
		var t: float=clampf(spark.age/spark.duration,0,1);var at: Vector2=spark.point+spark.velocity*spark.age
		var c: Color=Color("ffdb75") if spark.kind=="gold" else Color("92e6ff")
		draw_line(at,at-spark.velocity.normalized()*5,Color(c,1-t),2,true)
	for item in director.deltas:
		var t: float=clampf(item.age/item.duration,0,1);var at: Vector2=item.point+Vector2(-45,-20-28*t)
		var c: Color=Color("ffdb75") if item.kind=="gold" else Color("92e6ff")
		text(at,("+" if item.value>0 else "")+str(item.value)+(" G" if item.kind=="gold" else " 토큰"),17,Color(c,1-t),100)
