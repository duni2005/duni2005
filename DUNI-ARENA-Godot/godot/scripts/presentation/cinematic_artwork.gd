class_name CinematicArtwork
extends RefCounted
## Bounded deterministic screen art; no Nodes, random generator or game writes.
static func ramp(time: float,start: float,length: float) -> float:
	var t: float=clampf((time-start)/length,0,1);return t*t*(3-2*t)
static func title_alpha(kind: String,age: float) -> float:
	return ramp(age,0.0 if kind=="turning" else BattleCinematicState.TITLE_START,.48)*(1-ramp(age,4.2, .55) if kind=="turning" else 1)
static func darkness(kind: String,age: float) -> float:
	return ramp(age,0.1 if kind=="turning" else BattleCinematicState.DIM_START,.4)*(.25 if kind=="turning" else .38)*(1-ramp(age,4.2,.55) if kind=="turning" else 1)
static func paint(canvas: Control,arena: Rect2,kind: String,age: float) -> void:
	var motif: String="victory" if kind=="prediction_success" else "defeat" if kind=="prediction_failure" else kind
	var tint: Color={"turning":Color("8fe3ff"),"victory":Color("ffd36b"),"defeat":Color("ff8a8a"),"retreat":Color("ffb27a")}.get(motif,Color("d9d7d0"))
	var shade: float=darkness(kind,age);var alpha: float=title_alpha(kind,age)
	# Colour grade: cold blue for frozen time, warm/neutral for endings.
	var grade: Color=Color(.02,.05,.11,shade*1.35) if kind=="turning" else Color(.02,.02,.04,shade*1.15) if motif!="defeat" else Color(.08,.01,.02,shade*1.25)
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),grade)
	# The field fills the whole screen, so the vignette frame and the letterbox bars sit on the
	# screen's own edges.
	var screen:=Rect2(Vector2.ZERO,canvas.size)
	for i in range(10):
		var inset: float=i*arena.size.x*.014
		canvas.draw_rect(screen.grow(-inset),Color(0,0,.01,shade*.09),false,maxf(1,arena.size.x*.014))
	# Cinematic letterbox bars slide in from the top and bottom of the screen.
	var bars: float=ramp(age,0.0 if kind=="turning" else BattleCinematicState.DIM_START,.35)*(1-ramp(age,4.2,.4) if kind=="turning" else 1)*canvas.size.y*.085
	if bars>0:
		var w: float=canvas.size.x;var h: float=canvas.size.y
		canvas.draw_rect(Rect2(0,0,w,bars),Color(0,0,0,.82))
		canvas.draw_rect(Rect2(0,h-bars,w,bars),Color(0,0,0,.82))
		canvas.draw_line(Vector2(0,bars),Vector2(w,bars),Color(tint,.35*alpha),1)
		canvas.draw_line(Vector2(0,h-bars),Vector2(w,h-bars),Color(tint,.35*alpha),1)
	if alpha<=0:return
	var center: Vector2=arena.get_center();var mobile: bool=arena.size.x<500
	var start: float=0.0 if kind=="turning" else BattleCinematicState.TITLE_START
	var pop: float=ramp(age,start,.28);var t: float=age-start
	if kind=="turning":
		_paint_turning(canvas,arena,center,tint,alpha,age)
	else:
		_paint_ending(canvas,arena,center,motif,tint,alpha,t,pop)
	# Title on a ribbon, with a short English kicker above it.
	var font: Font=ArenaUI.heading_font();var kicker_font: Font=ArenaUI.numbers_font()
	var font_size: int=(26 if mobile else 36) if kind=="turning" else (44 if mobile else 62)
	var title: String={"turning":"터닝포인트","victory":"승리","defeat":"패배","retreat":"후퇴","prediction_success":"예측 성공","prediction_failure":"예측 실패","prediction_draw":"무승부"}.get(kind,"전투 종료")
	var kicker: String={"turning":"TURNING POINT","victory":"VICTORY","defeat":"DEFEAT","retreat":"RETREAT"}.get(motif,"")
	var width: float=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var settle: float=1+.35*(1-pop) if kind!="turning" else 1+.08*(1-ramp(age,0,.7))
	canvas.draw_set_transform_matrix(Transform2D(0,Vector2.ONE*settle,0,center*(1-settle)))
	var ribbon_w: float=minf(arena.size.x*.92,width+(150 if kind=="turning" else 120));var ribbon_h: float=font_size*1.5
	var ribbon:=Rect2(center-Vector2(ribbon_w,ribbon_h)*.5,Vector2(ribbon_w,ribbon_h))
	var notch: float=ribbon_h*.5
	var shape:=PackedVector2Array([ribbon.position,ribbon.position+Vector2(ribbon_w,0),ribbon.position+Vector2(ribbon_w-notch*.6,notch),ribbon.end,ribbon.position+Vector2(0,ribbon_h),ribbon.position+Vector2(notch*.6,notch)])
	canvas.draw_colored_polygon(shape,Color(.03,.04,.08,.78*alpha))
	canvas.draw_line(ribbon.position+Vector2(notch,2),ribbon.position+Vector2(ribbon_w-notch,2),Color(tint,.85*alpha),2)
	canvas.draw_line(ribbon.position+Vector2(notch,ribbon_h-2),ribbon.position+Vector2(ribbon_w-notch,ribbon_h-2),Color(tint,.85*alpha),2)
	var offset: float=34 if kind=="turning" else 0
	var text_at: Vector2=center+Vector2(-(width+offset)*.5+offset,font_size*.36)
	for d in [Vector2(0,3),Vector2(2,2),Vector2(-2,2)]:canvas.draw_string(font,text_at+d,title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(0,0,0,.55*alpha))
	canvas.draw_string(font,text_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(tint,alpha))
	canvas.draw_string(font,text_at+Vector2(0,-1),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(1,1,1,.25*alpha))
	if not kicker.is_empty():
		var ks: int=12 if mobile else 15;var kw: float=kicker_font.get_string_size(kicker,HORIZONTAL_ALIGNMENT_LEFT,-1,ks).x
		canvas.draw_string(kicker_font,center+Vector2(-kw*.5,-ribbon_h*.5-8),kicker,HORIZONTAL_ALIGNMENT_LEFT,-1,ks,Color(tint,.9*alpha))
	if kind=="turning":
		var clock: Vector2=center+Vector2(-(width+offset)*.5+12,0)
		canvas.draw_circle(clock,14,Color(tint,.15*alpha));canvas.draw_arc(clock,13,0,TAU,40,Color(tint,alpha),2,true)
		var angle: float=-PI/2+ramp(age,0,.8)*TAU+age*.6
		canvas.draw_line(clock,clock+Vector2.from_angle(angle)*9,Color(tint,alpha),2,true)
		canvas.draw_line(clock,clock+Vector2(5,-3),Color(tint,alpha),2,true)
	canvas.draw_set_transform(Vector2.ZERO)
static func _paint_turning(canvas: Control,arena: Rect2,center: Vector2,tint: Color,alpha: float,age: float) -> void:
	# A translucent clock dial with counter-rotating rings reads as time stopping.
	var radius: float=arena.size.x*.31
	for i in range(60):
		var direction: Vector2=Vector2.from_angle(i*TAU/60-PI/2)
		var major: bool=i%5==0
		canvas.draw_line(center+direction*(radius-(10 if major else 4)),center+direction*radius,Color(tint,alpha*(.32 if major else .12)),2 if major else 1,true)
	canvas.draw_arc(center,radius+8,-age*.3,PI*.8-age*.3,64,Color(tint,alpha*.28),2,true)
	canvas.draw_arc(center,radius-16,PI+age*.22,PI*1.7+age*.22,48,Color(tint,alpha*.2),1.5,true)
	canvas.draw_arc(center,radius*.62,age*.5,age*.5+PI*.35,32,Color(tint,alpha*.16),1,true)
	# Sweeping second hand.
	var hand: float=-PI/2+age*1.4
	canvas.draw_line(center,center+Vector2.from_angle(hand)*radius*.9,Color(tint,alpha*.22),1.5,true)
	# Frozen-time scanlines drift slowly upwards.
	for i in range(6):
		var y: float=arena.position.y+fposmod(-age*40+i*arena.size.y/6,arena.size.y)
		canvas.draw_line(Vector2(arena.position.x,y),Vector2(arena.end.x,y),Color(tint,alpha*.05),2)
	# Floating motes hang still, as if suspended.
	for i in range(26):
		var sx: float=sin(i*12.98+3.14)*.5+.5;var sy: float=sin(i*78.23+1.7)*.5+.5
		var at: Vector2=arena.position+Vector2(sx,sy)*arena.size+Vector2(0,sin(age*.8+i)*3)
		canvas.draw_circle(at,1.2+i%3*.6,Color(tint,alpha*(.25+.2*sin(age*2+i))))
static func _paint_ending(canvas: Control,arena: Rect2,center: Vector2,motif: String,tint: Color,alpha: float,t: float,pop: float) -> void:
	var victory: bool=motif=="victory"
	# Light burst: rotating wedges behind the title.
	var rays: int=16 if victory else 10;var reach: float=arena.size.x*(.5 if victory else .4)*pop
	for i in range(rays if reach>4 else 0):
		var a: float=i*TAU/rays+t*(.25 if victory else .08)
		var side: Vector2=Vector2.from_angle(a+PI/2)*reach*.09
		var tip: Vector2=center+Vector2.from_angle(a)*reach
		canvas.draw_colored_polygon(PackedVector2Array([center,tip+side,tip-side]),Color(tint,alpha*(.09 if victory else .05)))
	canvas.draw_circle(center,arena.size.x*.22*pop,Color(tint,alpha*.07))
	# Shockwave ring at the reveal.
	if t>=0 and t<.7:
		var k: float=t/.7
		canvas.draw_arc(center,arena.size.x*(.1+.45*k),0,TAU,72,Color(tint,(1-k)*.8*alpha),3*(1-k)+1,true)
		canvas.draw_circle(center,arena.size.x*.12*(1-k),Color(1,1,1,(1-k)*.25*alpha))
	# Emblem and rating stars above the ribbon.
	var mobile: bool=arena.size.x<500;var lift: float=(64 if mobile else 86)
	ArenaIcon.draw(canvas,center+Vector2(0,-lift-8),"crown" if victory else "skull" if motif=="defeat" else "flag",(34 if mobile else 44)*(.6+.4*pop),Color(1,1,1,alpha))
	if victory:
		for i in range(3):
			var star_pop: float=clampf((t-.15-i*.12)/.18,0,1)
			if star_pop<=0:continue
			var at: Vector2=center+Vector2((i-1)*(28 if mobile else 38),(33 if mobile else 47)+(20 if i==1 else 16))
			var r: float=(9 if i!=1 else 12)*(1.4-.4*star_pop)
			var points:=PackedVector2Array()
			for j in range(10):points.append(at+Vector2.from_angle(-PI/2+j*PI/5)*(r if j%2==0 else r*.45))
			canvas.draw_colored_polygon(points,Color(tint,alpha*star_pop))
		# Confetti: deterministic pieces falling with a slow spin.
		var colors: Array=[Color("ffd36b"),Color("ffb15c"),Color("8fe3ff"),Color("86e3a4"),Color("ff8fb0")]
		for i in range(48):
			var sx: float=sin(i*12.98+3.14)*.5+.5;var speed: float=.35+(sin(i*4.1)*.5+.5)*.4
			var fall: float=fposmod(t*speed+sin(i*7.7)*.5+.5,1.0)
			var at: Vector2=Vector2(arena.position.x+sx*arena.size.x+sin(t*2+i)*10,arena.position.y+fall*arena.size.y)
			var spin: float=t*3+i;var len: float=5+i%3*2
			var dir: Vector2=Vector2(cos(spin),sin(spin)*.4)*len
			canvas.draw_line(at-dir,at+dir,Color(colors[i%colors.size()],alpha*.9*clampf(t*3,0,1)),3)
	elif motif=="defeat":
		# Ash drifting down.
		for i in range(30):
			var sx: float=sin(i*12.98+3.14)*.5+.5
			var fall: float=fposmod(t*.15+sin(i*5.3)*.5+.5,1.0)
			canvas.draw_circle(Vector2(arena.position.x+sx*arena.size.x,arena.position.y+fall*arena.size.y),1.5+i%3,Color(.6,.55,.55,alpha*.35))
	else:
		# Retreat: horizontal speed streaks.
		for i in range(9):
			var x: float=arena.position.x+fposmod(t*260+i*97,arena.size.x+80)-40
			var y: float=center.y-110+i*27
			canvas.draw_line(Vector2(x,y),Vector2(x-40-i*4,y),Color(tint,alpha*.18),2,true)
