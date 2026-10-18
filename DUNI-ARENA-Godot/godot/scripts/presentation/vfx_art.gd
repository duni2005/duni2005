class_name VfxArt
extends RefCounted
## Small shared masks, smooth gradient ribbons and hand-shaped magic geometry.
## All randomness is local deterministic decoration. No gameplay writes or RNG reads.
const GLOW=preload("res://assets/vfx/glow.png")
const FLARE=preload("res://assets/vfx/flare.png")
const GLINT=preload("res://assets/vfx/glint.png")
const SMOKE=preload("res://assets/vfx/smoke.png")
const PRESSURE=preload("res://assets/vfx/pressure_wave.png")
const DEATH_WAVE=preload("res://assets/vfx/death_wave.svg")
static func glow(c: CanvasItem,p: Vector2,r: float,color: Color,alpha: float=1,aspect: float=1) -> void:
	if r<=0 or alpha<=0:return
	c.draw_texture_rect(GLOW,Rect2(p-Vector2(r,r*aspect),Vector2(r*2,r*2*aspect)),false,Color(color,alpha*color.a))
static func quad(c: CanvasItem,texture: Texture2D,p: Vector2,extent: Vector2,angle: float,color: Color) -> void:
	var d:=Vector2.from_angle(angle);var n:=d.orthogonal();var x:=d*extent.x;var y:=n*extent.y
	c.draw_polygon(PackedVector2Array([p-x-y,p+x-y,p+x+y,p-x+y]),PackedColorArray([color]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),texture)
static func flare(c: CanvasItem,p: Vector2,angle: float,length: float,color: Color,alpha: float=1) -> void:
	quad(c,FLARE,p,Vector2(length,length*.17),angle,Color(color,alpha))
static func star(c: CanvasItem,p: Vector2,r: float,color: Color,alpha: float=1,angle: float=0) -> void:
	quad(c,GLINT,p,Vector2.ONE*r,angle,Color(color,alpha))
static func ribbon(c: CanvasItem,p: Vector2,r: float,start: float,end: float,width: float,color: Color,alpha: float=1) -> void:
	if r<=.01 or alpha<=0 or absf(end-start)<.001:return
	var points:=PackedVector2Array();var colors:=PackedColorArray();var steps: int=24
	width=minf(width,r*.9)
	for side in [1,-1]:
		for j in (range(steps+1) if side==1 else range(steps-1,0,-1)):
			var t: float=float(j)/steps
			var w: float=width*pow(maxf(0,sin(t*PI)),.7);var a: float=lerpf(start,end,t)
			points.append(p+Vector2.from_angle(a)*(r+w*(.13 if side==1 else -.85)))
			colors.append(Color(color,alpha*sin(t*PI)*(.55+.45*t)))
	c.draw_polygon(points,colors)
static func ellipse(c: CanvasItem,p: Vector2,r: float,height: float,color: Color,width: float=2,start: float=0,end: float=TAU) -> void:
	var points:=PackedVector2Array()
	for i in range(49):
		var a: float=lerpf(start,end,float(i)/48);points.append(p+Vector2(cos(a)*r,sin(a)*r*height))
	c.draw_polyline(points,color,width,true)
static func sigil(c: CanvasItem,p: Vector2,r: float,time: float,color: Color,alpha: float=.6) -> void:
	for i in range(8):
		var a: float=i*TAU/8+time*.14;var d:=Vector2.from_angle(a);var n:=d.orthogonal();var at: Vector2=p+d*r
		c.draw_polyline(PackedVector2Array([at-n*3-d*5,at+d*3,at+n*3-d*5]),Color(color,alpha),1.3,true)
		c.draw_line(at+d*7,at+d*11,Color(color,alpha*.65),1)
	for i in range(3):c.draw_arc(p,r*.95,time*.2+i*TAU/3,time*.2+i*TAU/3+1.65,22,Color(color,alpha*.55),1.2,true)
static func shield(c: CanvasItem,p: Vector2,r: float,color: Color,time: float) -> void:
	glow(c,p,r*1.4,color,.16)
	var points:=PackedVector2Array()
	for i in range(7):points.append(p+Vector2.from_angle(PI/6+i*TAU/6)*r)
	c.draw_colored_polygon(points,Color(color,.055));c.draw_polyline(points,Color(color,.6),1.5,true)
	for i in range(6):
		var a: float=PI/6+i*TAU/6
		var at: Vector2=p+Vector2.from_angle(a)*r*.63;var cell:=PackedVector2Array()
		for j in range(7):cell.append(at+Vector2.from_angle(PI/6+j*TAU/6)*r*.25)
		c.draw_polyline(cell,Color(color,.12+.1*sin(time*2+i)),.8,true)
	c.draw_arc(p,r+2,time*.5,time*.5+PI*.7,24,Color("e6fcff",.75),2,true)
static func effect(c: CanvasItem,e: Dictionary) -> bool:
	var t: float=clampf(float(e.age)/maxf(.001,float(e.life)),0,1);var fade: float=pow(1-t,1.6)
	var p: Vector2=e.point;var r: float=e.radius;var color: Color=e.color;var angle: float=e.get("angle",0)
	match String(e.kind):
		"hit","critical","projectile_hit":
			var critical: bool=e.kind=="critical";var size: float=(r*.9 if critical else r*.62)*(1-pow(t,.7))
			glow(c,p,size*2.5,color,fade*.65);flare(c,p,angle+.65,size*2.3,Color("fff7e6"),fade)
			flare(c,p,angle-1.1,size*1.3,color,fade*.8)
			for i in range(9 if critical else 6):
				var a: float=angle+(i-3)*.45;var d:=Vector2.from_angle(a);var at: Vector2=p+d*r*(.22+t*1.05)
				c.draw_line(at-d*12*(1-t),at,Color(color,fade),2 if critical else 1,true)
			star(c,p,size*1.15,Color.WHITE,fade)
			if t<.55:pressure(c,p,angle,r*(.2+t*1.4),color,fade*.65)
			return true
		"parry_success","warrior_parry":
			var contact: Vector2=p+Vector2.from_angle(angle)*24
			glow(c,contact,105*(1-t)+18,Color("75e8ff"),fade*.95)
			flare(c,contact,angle+PI/2,125*(1-t),Color("efffff"),fade)
			for i in range(3):
				var phase: float=clampf((t-i*.12)/maxf(.01,1-i*.12),0,1)
				if t<i*.12:continue
				var radius: float=r*(.22+1.38*(1-pow(1-phase,2.6)))
				pressure(c,p,angle,radius,Color("dcffff") if i==0 else Color("75d9ef"),pow(1-phase,1.6)*(.95-i*.15))
			for i in range(8):
				var a: float=angle+(i-3.5)*.3;var d:=Vector2.from_angle(a)
				var at: Vector2=contact+d*(35+(1-pow(1-t,3))*120)
				flare(c,at,a,18*(1-t),Color("c5faff"),fade*.75)
			return true
		"clash":
			var expand: float=1-pow(1-t,3);var radius: float=r*(.15+.68*expand)
			glow(c,p,r*.8,Color("ff9f66"),fade*.7)
			flare(c,p,angle+.65,r*(1-t),Color("fff0c8"),fade);flare(c,p,angle-.85,r*.8*(1-t),Color("b5dfff"),fade)
			for i in range(6):
				var a: float=i*TAU/6+angle;var at: Vector2=p+Vector2.from_angle(a)*radius
				c.draw_arc(p,radius,a+.06,a+.7,9,Color("ffd18c" if i%2==0 else "a9e9ff",fade),2,true)
				star(c,at,7,Color("fff1c9"),fade,a)
			return true
		"explosion":
			var expand: float=1-pow(1-t,3);var radius: float=r*expand
			glow(c,p,r*.8,Color("ff762f"),fade*.8)
			if t<.25:glow(c,p,r*.55*(1-t*2),Color("fff0c7"),(1-t*4)*.95)
			for i in range(7):
				var a: float=i*2.399;var at: Vector2=p+Vector2.from_angle(a)*r*(.1+expand*.38)+Vector2(0,-t*r*.2)
				quad(c,SMOKE,at,Vector2.ONE*r*(.28+t*.2),a,Color("593d37",sin(t*PI)*.5))
				ribbon(c,p,radius*(.65+i*.04),a,a+.9,16*(1-t),Color("ffb057"),fade*.65)
			c.draw_arc(p,radius,0,TAU,64,Color("ffc783",fade*.8),maxf(1,6*(1-t)),true)
			ellipse(c,p+Vector2(0,12),radius,.38,Color("ffe4af",fade*.6),2)
			if t<.4:flare(c,p,-.2,r*(1-t),Color("fff0cb"),fade)
			return true
		"shield_hit","shield_break","invincible","hero_rescue":
			var shatter: bool=e.kind=="shield_break";var radius: float=r*(.65+.5*t)
			glow(c,p,r*1.6,color,fade*.5)
			for i in range(6):
				var a: float=i*TAU/6+PI/6;var d:=Vector2.from_angle(a);var at: Vector2=p+d*(radius+(t*r*.8 if shatter else 0))
				var n:=d.orthogonal()
				c.draw_colored_polygon(PackedVector2Array([at+d*9,at-d*5+n*8,at-d*8-n*5]),Color(color,fade*.6))
				if not shatter:c.draw_line(at, p+Vector2.from_angle(a+TAU/6)*radius,Color("e8ffff",fade*.65),1.5,true)
			star(c,p,r*.4,Color("e4ffff"),fade*.7)
			return true
		"heal","vigor_totem","charge_totem":
			var color_heal:=Color("83efc4") if e.kind!="charge_totem" else Color("a4baff")
			glow(c,p,r*2,color_heal,fade*.35);ellipse(c,p+Vector2(0,20),r*(.5+t*.6),.28,Color(color_heal,fade*.75),2)
			for i in range(7):
				var phase: float=fposmod(i*.137+t*.8,1);var at: Vector2=p+Vector2(sin(i*6.3)*r*.65,25-phase*r*1.7)
				star(c,at,7*sin(phase*PI)+2,Color("caffeb"),sin(phase*PI)*fade,.3)
			return true
		"reflect":
			glow(c,p,r*1.8,Color("b3a5ff"),fade*.55)
			for i in range(5):
				var a: float=i*TAU/5+t*.8;var at: Vector2=p+Vector2.from_angle(a)*r*(.4+t*.8);var d:=Vector2.from_angle(a)
				c.draw_colored_polygon(PackedVector2Array([at+d*15,at+d.orthogonal()*7,at-d*9,at-d.orthogonal()*7]),Color("c4f6ff",fade*.65))
				c.draw_line(at-d*8,at+d*9,Color("ffffff",fade),1,true)
			flare(c,p,angle,r,Color("e9cfff"),fade)
			return true
		"ultimate","transcendence","final_kill":
			var violet:=Color("bfa2ff") if e.kind=="transcendence" else color
			glow(c,p,r*1.35,violet,fade*.55);sigil(c,p,r*(.45+.3*t),t*4,violet,fade*.8)
			for i in range(8):
				var a: float=i*2.399;var at: Vector2=p+Vector2.from_angle(a)*r*(.5+sin(t*PI)*.3)
				star(c,at,5+sin(t*PI)*5,Color("f2e3ff"),fade,a)
			flare(c,p,angle,r*(1-t),Color("fff0e7"),fade*.9)
			return true
		"launch":
			glow(c,p,r*1.5,color,fade*.6);flare(c,p,angle,r*(1-t),Color("fff1d5"),fade)
			for side in [-1,1]:flare(c,p,angle+side*.55,r*.45*(1-t),color,fade*.65)
			return true
		"stun","wave_stun":
			glow(c,p,r,color,fade*.2)
			for i in range(3):
				var a: float=i*TAU/3+t*3;var at: Vector2=p+Vector2(cos(a)*r*.5,-25+sin(a)*5)
				star(c,at,8,Color("ffe49c"),fade,a)
			return true
		"death":
			death_burst(c,p,r,t,color)
			return false # The body dissolve is drawn separately.
		"warrior_release":
			var swing: float=1-pow(1-t,3)
			for i in range(3):ribbon(c,p,r-i*9,angle-1.65,angle-1.65+swing*3.0,48-i*12,Color("fff0c3") if i==2 else Color("ffb36b"),fade*(.9-i*.15))
			glow(c,p+Vector2.from_angle(angle)*55,70,Color("ffc174"),fade*.4)
			return true
	return false
static func pressure(c: CanvasItem,p: Vector2,angle: float,radius: float,color: Color,alpha: float=1) -> void:
	if radius<=0 or alpha<=0:return
	quad(c,PRESSURE,p,Vector2(radius,radius*.82),angle,Color(color,alpha))
static func death_burst(c: CanvasItem,p: Vector2,r: float,t: float,color: Color) -> void:
	var expand: float=1-pow(1-t,3);var fade: float=pow(1-t,1.5)
	glow(c,p,r*(.75-t*.4),Color("fff0d5"),fade*.85)
	quad(c,DEATH_WAVE,p,Vector2.ONE*r*(.18+expand*1.7),0,Color(color,fade*.95))
	if t>.08:
		var second: float=(t-.08)/.92
		quad(c,DEATH_WAVE,p,Vector2.ONE*r*(.1+(1-pow(1-second,3))*1.3),0,Color("fff3d9",pow(1-second,2)*.5))
	for i in range(12):
		var a: float=i*2.399;var d:=Vector2.from_angle(a);var at: Vector2=p+d*r*(.2+expand*.95)
		flare(c,at,a,22*(1-t)+3,color,fade*.7)
		star(c,at,8*(1-t)+2,Color("fff3da"),fade,a)
static func crescent(c: CanvasItem,p: Vector2,angle: float,scale: float=1,alpha: float=1) -> void:
	var dir:=Vector2.from_angle(angle)
	for i in range(3,0,-1):
		var tail: Vector2=p-dir*i*19*scale
		ribbon(c,tail,(60-i*3)*scale,angle-1.6,angle+1.6,(28-i*4)*scale,Color("ee965b"),alpha*(.22-i*.045))
	glow(c,p+dir*32*scale,75*scale,Color("ffab57"),alpha*.3)
	ribbon(c,p,64*scale,angle-1.62,angle+1.62,43*scale,Color("ffb56d"),alpha*.95)
	ribbon(c,p+dir*3*scale,62*scale,angle-1.52,angle+1.52,24*scale,Color("fff0c7"),alpha)
	ribbon(c,p+dir*5*scale,60*scale,angle-1.4,angle+1.4,8*scale,Color("ffffff"),alpha)
	for side in [-1,1]:flare(c,p+Vector2.from_angle(angle+side*1.3)*54*scale,angle+side*.65,27*scale,Color("ffe4b0"),alpha*.65)
static func field(c: CanvasItem,z: Dictionary,time: float,color: Color) -> void:
	var p: Vector2=CharacterPersistence.vector(z.point);var r: float=z.radius;var kind: String=z.kind
	var fade: float=clampf(float(z.life)*3,0,1)
	# Boundary always denotes the actual gameplay radius; decoration stays inside it.
	c.draw_circle(p,r,Color(color,.035*fade));c.draw_arc(p,r,0,TAU,64,Color(color,.45*fade),1.4,true)
	if kind=="blackhole":
		glow(c,p,r,Color("6f36cb"),.4*fade)
		for arm in range(5):
			var points:=PackedVector2Array();var colors:=PackedColorArray()
			for j in range(32):
				var t: float=float(j)/31;var a: float=arm*TAU/5+time*.8+t*4.5
				points.append(p+Vector2.from_angle(a)*r*(.92-t*.68));colors.append(Color("d0a9ff",sin(t*PI)*.5*fade))
			c.draw_polyline_colors(points,colors,1.2,true)
		for i in range(24):
			var t: float=fposmod(time*.35+i*.117,1);var a: float=i*2.399+time+t*2;var at: Vector2=p+Vector2.from_angle(a)*r*(.9-t*.64)
			star(c,at,2+3*t,Color("ceb2ff"),sin(t*PI)*.8*fade,a)
		c.draw_circle(p,r*.22,Color("080913",fade))
		ellipse(c,p,r*.29,.44,Color("f1cfff",fade*.85),2);ellipse(c,p,r*.34,.42,Color("a57cff",fade*.6),3)
		sigil(c,p,r*.9,time,Color("b89bfa"),.35*fade)
	elif kind in ["healing","holy"]:
		glow(c,p,r,color,.18*fade);sigil(c,p,r*.85,time,color,.55*fade)
		for i in range(6):ribbon(c,p,r*.59,time*.12+i*TAU/6,time*.12+i*TAU/6+.72,10,color,.2*fade)
		for i in range(16):
			var t: float=fposmod(time*.27+i*.137,1);var at: Vector2=p+Vector2(sin(i*12.8)*r*.75,(1-t)*r*1.4-r*.7)
			star(c,at,5+2*sin(t*PI),Color("c8ffe5") if kind=="healing" else Color("fff0be"),sin(t*PI)*.75*fade)
	elif kind=="tankFire":
		glow(c,p,r,Color("ef6b27"),.25*fade)
		for i in range(22):
			var t: float=fposmod(time*.9+i*.163,1);var base: Vector2=p+Vector2.from_angle(i*2.399)*r*sqrt(VisualParticles.noise(i+1))*.8
			var at: Vector2=base+Vector2(sin(time*3+i)*8,-t*42);var alpha: float=sin(t*PI)*fade
			quad(c,SMOKE,at,Vector2(15*(1-t)+5,30*(1-t)+7),sin(i)*.3,Color("ff6b25",alpha*.6))
			flare(c,at,-PI/2,15*(1-t)+7,Color("ffdc82"),alpha*.85)
			star(c,at+Vector2(sin(i)*9,-12-t*25),3,Color("ffd593"),alpha*.8)
	elif kind in ["galaxy","cosmic"]:
		glow(c,p,r,Color("5f61c8"),.25*fade)
		for arm in range(4):
			var points:=PackedVector2Array()
			for j in range(24):
				var t: float=float(j)/23;var a: float=arm*TAU/4+time*.12+t*3
				points.append(p+Vector2.from_angle(a)*r*(.15+t*.75))
			c.draw_polyline(points,Color("a598ed",.12*fade),1.2,true)
		for i in range(28):
			var a: float=i*2.399+time*.15;var at: Vector2=p+Vector2.from_angle(a)*r*sqrt(float(i)/29)*.94
			star(c,at,4+VisualParticles.noise(i)*5,Color("d5d8ff"),(.3+.4*sin(time+i))*fade,i)
	elif kind=="discharge":
		glow(c,p,r,Color("7bbfff"),.35*fade)
		for i in range(8):
			var at: Vector2=p+Vector2.from_angle(i*TAU/8+time)*r
			star(c,at,15,Color("deffff"),fade)
