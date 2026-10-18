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
	var tint: Color={"turning":Color("a4e1db"),"victory":Color("f6d48a"),"defeat":Color("ed9e99"),"retreat":Color("ff7878")}.get(motif,Color("d9d7d0"))
	var shade: float=darkness(kind,age);var alpha: float=title_alpha(kind,age)
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color(.015,.025,.035,shade))
	# A soft vignette preserves the arena center; no solid title box.
	for i in range(10):
		var inset: float=i*arena.size.x*.014
		canvas.draw_rect(arena.grow(-inset),Color(.005,.012,.018,shade*.075),false,maxf(1,arena.size.x*.014))
	if alpha<=0:return
	var center: Vector2=arena.get_center();var mobile: bool=arena.size.x<500
	if kind=="turning":
		# A translucent clock dial reads as time stopping, rather than an attack AoE.
		var radius: float=arena.size.x*.29
		for i in range(32):
			var direction: Vector2=Vector2.from_angle(i*TAU/32-PI/2)
			canvas.draw_line(center+direction*(radius-(7 if i%4==0 else 3)),center+direction*radius,Color(tint,alpha*(.2 if i%4==0 else .09)),1,true)
		canvas.draw_arc(center,radius+5,-age*.16,PI*.72-age*.16,56,Color(tint,alpha*.12),1,true)
		canvas.draw_arc(center,radius-9,PI+age*.11,PI*1.58+age*.11,40,Color(tint,alpha*.1),1,true)
	else:
		# Directional light sheets settle behind the result title, never a hitbox.
		for side in [-1,1]:
			var side_x: float=center.x+side*arena.size.x*.46
			canvas.draw_line(Vector2(side_x,center.y-70),Vector2(side_x,center.y+70),Color(tint,alpha*.11),1,true)
		if kind=="retreat":
			for i in range(7):
				var x: float=arena.position.x+fposmod(age*90+i*53,arena.size.x)
				var y_line: float=center.y-85+i*28
				canvas.draw_line(Vector2(x,y_line),Vector2(maxf(arena.position.x,x-25-i*3),y_line),Color(tint,alpha*.09),1,true)
	var font: Font=canvas.get_theme_default_font()
	var font_size: int=(25 if mobile else 34) if kind=="turning" else (42 if mobile else 58)
	var title: String={"turning":"터닝포인트","victory":"승리","defeat":"패배","retreat":"후퇴","prediction_success":"예측 성공","prediction_failure":"예측 실패","prediction_draw":"무승부"}.get(kind,"전투 종료")
	var width: float=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var y: float=(1-ramp(age,0.0 if kind=="turning" else BattleCinematicState.TITLE_START,.6))*8
	var settle: float=1+.08*(1-ramp(age,0.0 if kind=="turning" else BattleCinematicState.TITLE_START,.7))
	canvas.draw_set_transform_matrix(Transform2D(0,Vector2.ONE*settle,0,center*(1-settle)))
	var total: float=width+(42 if kind=="turning" else 0)
	var text_at: Vector2=center+Vector2(-total*.5+(42 if kind=="turning" else 0),font_size*.34+y)
	# Layered low-opacity lettering gives the release a restrained luminous edge.
	for i in range(3,0,-1):canvas.draw_string(font,text_at+Vector2(0,i),title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(tint,alpha*.07))
	canvas.draw_string(font,text_at,title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(tint,alpha))
	var spread: float=minf(190,arena.size.x*.42)*ramp(age,0.0 if kind=="turning" else 2.0,.8)
	for side in [-1,1]:
		var inner: Vector2=center+Vector2(side*(total*.5+18),2+y)
		var outer: Vector2=center+Vector2(side*spread,2+y)
		if inner.distance_to(center)<outer.distance_to(center):
			canvas.draw_line(inner,outer,Color(tint,alpha*.6),1.2,true)
			canvas.draw_circle(outer,1.8,Color(tint,alpha*.8))
	if kind=="turning":
		var clock: Vector2=center+Vector2(-total*.5+14,y)
		canvas.draw_arc(clock,13,-PI/2,TAU-PI/2,40,Color(tint,alpha),2,true)
		var angle: float=-PI/2+ramp(age,0,.8)*TAU
		canvas.draw_line(clock,clock+Vector2.from_angle(angle)*9,Color(tint,alpha),2,true)
		canvas.draw_line(clock,clock+Vector2(5,-3),Color(tint,alpha),2,true)
		canvas.draw_arc(clock,19,-age,PI*.6-age,28,Color(tint,alpha*.35),1,true)
	else:
		ArenaIcon.draw(canvas,center+Vector2(0,-54+y),"crown" if motif=="victory" else "skull" if motif=="defeat" else "flag",33,Color(1,1,1,alpha))
		for side in [-1,1]:
			for i in range(3):
				var at: Vector2=center+Vector2(side*(30+i*10),-49+i*4+y)
				canvas.draw_line(at,at+Vector2(side*10,-9 if motif=="victory" else 7),Color(tint,alpha*(.48-i*.1)),2,true)
	# Small finite motes move outside the title and never obscure controls.
	canvas.draw_set_transform(Vector2.ZERO)
	for i in range(22):
		var seed_value: float=sin(i*12.98+3.14)*.5+.5
		var progress: float=fposmod(age*.12+i*.177,1)
		var at: Vector2=center+Vector2((seed_value-.5)*arena.size.x*.9,(.5-progress)*140)
		var opacity: float=sin(progress*PI)*alpha*.3
		canvas.draw_line(at,at+Vector2(0,-2-i%3),Color(tint,opacity),1,true)
