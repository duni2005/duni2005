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
		# Above the footer action, rising slightly as it appears.
		var box:=Rect2(Vector2((screen.x-width)*.5,screen.y-178-i*64+(1-clampf(item.age/.2,0,1))*14),Vector2(width,56));draw_style_box(ArenaUI.box(Color(.055,.07,.13,alpha*.96),Color(.42,.48,.7,alpha)),box)
		ArenaIcon.draw(self,box.position+Vector2(26,28),item.icon,30,Color(1,1,1,alpha));text(box.position+Vector2(52,24),item.title,14,Color(ArenaUI.GOLD,alpha),width-64)
		if not item.detail.is_empty():text(box.position+Vector2(52,44),item.detail,11,Color(ArenaUI.MUTED,alpha),width-64)
	if director.active.is_empty():_draw_flights();return
	var s: Dictionary=director.active;var t: float=s.age
	if t<0:_draw_flights();return
	var alpha: float=minf(clampf(t/.2,0,1),clampf((s.duration-t)/.8,0,1));var kind: String=s.kind
	if kind=="entry":_draw_entry(s,t,screen);_draw_flights();return
	if kind=="promotion" and UiMotion.enabled:_draw_promotion(s,t,screen);_draw_flights();return
	var strong: bool=kind in ["recruit","promotion"]
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
			for side in [-1,1]:UnitIcon.draw(self,Rect2(center+Vector2(side*spread-42,-94),Vector2(84,84)),type,alpha*(1-clampf(t/1.4,0,1)))
		VfxArt.glow(self,center+Vector2(0,-55),95,Color("f0d490"),.3*alpha)
		UnitIcon.draw(self,Rect2(center+Vector2(-60,-115),Vector2(120,120)),type,alpha)
		if kind=="promotion":
			for i in range(int(s.get("stars",1))):ArenaIcon.draw(self,center+Vector2(-12+i*26,-127),"star",24,Color(1,1,1,alpha))
	else:ArenaIcon.draw(self,center+Vector2(0,-54),s.get("icon","crown"),76,Color(1,1,1,alpha))
	var width: float=minf(660,screen.x-40);var x: float=(screen.x-width)*.5
	text(Vector2(x,center.y+50),s.get("title",""),28 if screen.x<600 else 42,Color("fff2cf",alpha),width)
	text(Vector2(x,center.y+99),s.get("detail",""),15 if screen.x<600 else 21,Color("c4cdbb",alpha),width)
	if kind=="recruit":text(Vector2(x,center.y+151),"터치하여 계속",11,Color(.66,.73,.82,alpha*.8),width)

	_draw_flights()
## Room entry (Motion.CINEMATIC long, never blocks input): slanted panels sweep in from the left
## one after another, the room's English word drifts in behind against them, the icon pops, the
## Korean name rises letter by letter, a light streak crosses the band, then everything sweeps off
## to the right. With UI motion off it is a short plain fade.
func _draw_entry(s: Dictionary,t: float,screen: Vector2) -> void:
	var duration: float=float(s.duration);var k: float=t/duration
	var band_h: float=112;var y: float=screen.y*.4-band_h*.5;var strip:=Rect2(0,y,screen.x,band_h)
	var left: float=maxf(20,(screen.x-420)*.5);var font: Font=ArenaUI.heading_font();var title: String=s.get("title","")
	var title_size: int=30 if screen.x<600 else 38;var detail_size: int=14 if screen.x<600 else 18
	if not UiMotion.enabled:
		var a: float=minf(Motion.phase(t,0,.15),1-Motion.phase(t,duration-.2,.2))
		draw_rect(strip,Color(.03,.04,.08,.94*a));ArenaIcon.draw(self,Vector2(left+38,y+band_h*.5),s.get("icon","crown"),54,Color(1,1,1,a))
		draw_string(font,Vector2(left+84,y+50),title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size,Color("fff2cf",a))
		draw_string(get_theme_default_font(),Vector2(left+86,y+78),s.get("detail",""),HORIZONTAL_ALIGNMENT_LEFT,-1,detail_size,Color("c4cdbb",a))
		return
	var shown: float=minf(Motion.phase(t,0,.12),1-Motion.phase(k,.55,.25))
	draw_rect(Rect2(Vector2.ZERO,screen),Color(.02,.025,.055,.32*shown))
	TypeArt.panels(self,strip,k,false,[TypeArt.NAVY,TypeArt.INDIGO,Color(.03,.04,.08,.96)],.55)
	# Content leaves with the panels: it slides right and fades as they go.
	var leave: float=Motion.in_cubic(Motion.phase(k,.55,.3));var shift: float=leave*screen.x*.35;var a: float=1-leave
	var drift: float=Motion.out_quint(Motion.phase(t,.1,.9))
	TypeArt.watermark(self,s.get("word",""),Vector2(screen.x*.62+40*(1-drift)+shift*.6,y+band_h*.52),int(band_h*.9),Color(1,1,1,.08*a*drift),-.22,10*(1-drift))
	var pop: float=Motion.emphasis(Motion.phase(t,.1,Motion.ENTER));var icon_at:=Vector2(left+38+shift,y+band_h*.5)
	if pop>0:
		VfxArt.glow(self,icon_at,60,Color("f0d490"),.22*a)
		ArenaIcon.draw(self,icon_at,s.get("icon","crown"),54*pop,Color(1,1,1,a))
	TypeArt.letters(self,font,title,Vector2(left+84+shift,y+50),title_size,Color("fff2cf",a),t-.14,18,Color(.02,.04,.1,.6*a))
	var detail_in: float=Motion.out_expo(Motion.phase(t,.3,Motion.ENTER))
	draw_string(get_theme_default_font(),Vector2(left+86+shift+12*(1-detail_in),y+78),s.get("detail",""),HORIZONTAL_ALIGNMENT_LEFT,-1,detail_size,Color("c4cdbb",a*detail_in))
	TypeArt.rule(self,Vector2(left+84+shift+90,y+60),90,Motion.phase(t,.3,Motion.ENTER),Color(ArenaUI.GOLD,.5*a))
	TypeArt.sweep(self,strip,Motion.phase(k,.32,.3),.16,40)
## Promotion (tap skips): slanted panels sweep in, the two material units rush in from the sides
## and fuse in a flash and ring burst, the promoted unit pops in a gold medallion, its stars stamp
## in one by one (the new one larger), "PROMOTION" drifts behind and the name rises letter by
## letter over a gold rule.
func _draw_promotion(s: Dictionary,t: float,screen: Vector2) -> void:
	var duration: float=float(s.duration);var a: float=Motion.out_quint(Motion.phase(t,0,.35))*(1-Motion.phase(t,duration-.5,.5))
	var gold:=Color("f0d490");var type: int=s.get("type",0);var stars: int=int(s.get("stars",1))
	draw_rect(Rect2(Vector2.ZERO,screen),Color(.012,.016,.04,.95*a))
	# The band frames everything from the stars down to the detail line.
	var center:=Vector2(screen.x*.5,screen.y*.36);var strip:=Rect2(0,center.y-130,screen.x,345);var band_h: float=strip.size.y
	TypeArt.panels(self,strip,t/duration,false,[TypeArt.NAVY,TypeArt.INDIGO,Color(.03,.035,.08,.97)],.72)
	var drift: float=Motion.out_quint(Motion.phase(t,.35,1.3))
	TypeArt.watermark(self,TypeArt.word(&"promotion"),Vector2(center.x+50*(1-drift),center.y+150),int(minf(screen.x*.19,96)),Color(1,1,1,.06*a*drift),-.22,14*(1-drift))
	# The two materials rush in and vanish into the centre.
	var fuse: float=1.15;var m: float=Motion.in_cubic(Motion.phase(t,.2,fuse-.2));var reach: float=minf(screen.x*.34,260)
	if t<fuse+.05:
		for side in [-1,1]:
			var at: Vector2=center+Vector2(side*reach*(1-m),0);var fade: float=a*(1-Motion.phase(t,fuse-.15,.2))
			draw_line(center+Vector2(side*reach,0),at,Color(gold,.25*fade),3,true)
			VfxArt.glow(self,at,50,gold,.2*fade)
			UnitIcon.draw(self,Rect2(at-Vector2(40,40),Vector2(80,80)),type,fade)
	# Fusion: a white flash and a ring that bursts outward.
	var burst: float=Motion.phase(t,fuse,.75)
	if t>=fuse:
		VfxArt.glow(self,center,minf(screen.x,screen.y)*.5,Color("ffe7a8"),.9*(1-Motion.phase(t,fuse,.22))*a)
		draw_arc(center,40+minf(screen.x,screen.y)*.6*Motion.out_expo(burst),0,TAU,64,Color(gold,.8*(1-burst)*a),4,true)
		TypeArt.motes(self,Rect2(center.x-band_h,center.y-band_h,band_h*2,band_h*1.6),t,Color(gold,.7*a),30,true,.22)
	# The promoted unit in a gold medallion, with slow rays behind.
	var pop: float=Motion.emphasis(Motion.phase(t,fuse,.55))
	if pop>0:
		var shown: float=a*Motion.phase(t,fuse,.2)
		for i in range(16):
			var angle: float=i*TAU/16+t*.12;var ray: float=minf(screen.x,screen.y)*.6
			draw_colored_polygon(PackedVector2Array([center,center+Vector2.from_angle(angle)*ray,center+Vector2.from_angle(angle+.06)*ray]),Color(gold,.05*shown))
		var r: float=66*pop;VfxArt.glow(self,center,120,gold,.35*shown)
		draw_circle(center,r+6,Color(gold,.12*shown));draw_circle(center,r,Color("0d1424",shown))
		draw_arc(center,r,0,TAU,64,Color(gold,shown),3,true);draw_arc(center,r-8,0,TAU,64,Color(gold,.35*shown),1,true)
		UnitIcon.draw(self,Rect2(center-Vector2(54,54)*pop,Vector2(108,108)*pop),type,shown)
		TypeArt.sweep(self,Rect2(center-Vector2(r,r),Vector2(r*2,r*2)),Motion.phase(t,fuse+.5,.5),.25,22)
	# Stars stamp in one by one above the medallion; the new star lands last and larger.
	var row_w: float=(stars-1)*30.0
	for i in range(stars):
		var at_star: float=fuse+.4+i*.18;var k: float=Motion.phase(t,at_star,.3)
		if k<=0:continue
		var newest: bool=i==stars-1;var size: float=(30.0 if newest else 24.0)*lerpf(2.2,1.0,Motion.emphasis(k))
		var spot: Vector2=center+Vector2(-row_w*.5+i*30,-96)
		if newest:VfxArt.glow(self,spot,34,gold,.45*a*k)
		ArenaIcon.draw(self,spot,"star",size,Color(1,1,1,a*minf(1,k*2)))
	# Kicker, name and detail.
	var font: Font=ArenaUI.heading_font();var title: String=s.get("title","");var title_size: int=32 if screen.x<600 else 44
	var kicker_in: float=Motion.out_expo(Motion.phase(t,fuse+.55,Motion.ENTER))
	draw_string(ArenaUI.numbers_font(),Vector2(0,center.y+98),"PROMOTION  ·  %d STAR" % stars,HORIZONTAL_ALIGNMENT_CENTER,screen.x,15,Color(gold,.9*a*kicker_in))
	var width: float=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x
	TypeArt.letters(self,font,title,Vector2(center.x-width*.5,center.y+140),title_size,Color("fff2cf",a),t-(fuse+.65),22,Color(.02,.03,.08,.6*a))
	TypeArt.rule(self,Vector2(center.x,center.y+154),width*.5+30,Motion.phase(t,fuse+.85,Motion.ENTER),Color(gold,.7*a),2)
	var detail_in: float=Motion.out_expo(Motion.phase(t,fuse+1.0,Motion.ENTER))
	text(Vector2(20,center.y+182+10*(1-detail_in)),s.get("detail",""),15 if screen.x<600 else 19,Color("c4cdbb",a*detail_in),screen.x-40)
	if t>fuse+1.4:text(Vector2(20,screen.y-36),"터치하여 계속",11,Color(.66,.73,.82,a*.8*Motion.phase(t,fuse+1.4,.4)),screen.x-40)
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
