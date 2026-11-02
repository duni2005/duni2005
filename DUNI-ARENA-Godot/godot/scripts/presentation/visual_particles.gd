class_name VisualParticles
extends RefCounted
## Bounded textured motes / physical shards / soft smoke. Private visual noise only.
const LIMIT=640
const AMBIENT_LIMIT=420
var entries: Array[Dictionary]=[]
var serial: int=0
var peak: int=0
static func noise(i: float) -> float:return fposmod(sin(i*127.1+311.7)*43758.5453,1)
func burst(point: Vector2,color: Color,amount: int,force: float=190,angle: float=0,style: String="spark",priority: bool=false) -> void:
	serial+=1
	for i in range(amount):
		if entries.size()>=(LIMIT if priority else AMBIENT_LIMIT):
			if not priority:break
			entries.pop_front()
		var seed: float=serial*71+i*13;var a: float=angle+(noise(seed)*2-1)*PI
		var speed: float=force*(.35+noise(seed+2)*.9);var life: float=.26+noise(seed+3)*.5
		var velocity: Vector2=Vector2.from_angle(a)*speed
		if style in ["heal","mote"]:velocity=Vector2((noise(seed)-.5)*force*.35,-force*(.25+noise(seed+2)*.5))
		# Rising status puffs: tinted smoke (plume) and licking flames (flame) drift upward.
		elif style=="plume":velocity=Vector2((noise(seed)-.5)*force*.5,-force*(.3+noise(seed+2)*.4));life=.8+noise(seed+3)*.7
		elif style=="flame":velocity=Vector2((noise(seed)-.5)*force*.45,-force*(.6+noise(seed+2)*.6));life=.35+noise(seed+3)*.35
		entries.append({"p":point,"v":velocity,"age":0.0,"life":life,"color":color,"size":1.5+noise(seed+5)*3,"style":style,"spin":(noise(seed+6)*2-1)*5,"angle":a,"seed":seed})
	peak=maxi(peak,entries.size())
func advance(dt: float) -> void:
	for e in entries:
		e.age=float(e.age)+dt;e.p=Vector2(e.p)+Vector2(e.v)*dt;e.v=Vector2(e.v)*exp((-1.6 if e.style=="shard" else -1.1 if e.style in ["plume","flame"] else -3)*dt);e.angle+=float(e.spin)*dt
		if e.style=="smoke":e.v+=Vector2(0,-20)*dt
		elif e.style=="plume":e.v+=Vector2(sin(e.age*3+e.seed)*14,-16)*dt
		elif e.style=="flame":e.v+=Vector2(sin(e.age*14+e.seed)*40,-70)*dt
		elif e.style in ["heal","mote"]:e.v+=Vector2(sin(e.age*8+e.seed)*12,-25)*dt
		else:e.v+=Vector2(0,140 if e.style=="shard" else 60)*dt
	for i in range(entries.size()-1,-1,-1):
		if entries[i].age>=entries[i].life:entries.remove_at(i)
func draw(canvas: CanvasItem,dim: float=1) -> void:
	for e in entries:
		var t: float=e.age/e.life;var fade: float=pow(1-t,1.4)*dim;var color:=Color(e.color,fade);var point: Vector2=e.p;var velocity: Vector2=e.v
		match e.style:
			"smoke":
				VfxArt.quad(canvas,VfxArt.SMOKE,point,Vector2.ONE*(8+t*15)*e.size,e.angle,Color("5e514d",sin(t*PI)*.35*dim))
			"plume":
				VfxArt.quad(canvas,VfxArt.SMOKE,point,Vector2.ONE*(7+t*18)*e.size,e.angle,Color(e.color,sin(t*PI)*.7*dim))
			"flame":
				# White-hot core cooling to orange, then a dull red as it rises and shrinks.
				var hot: Color=Color("fff0b0").lerp(Color("ff8a2a"),clampf(t*1.8,0,1)).lerp(Color("b8341c"),clampf(t*1.6-.6,0,1))
				var size: float=e.size*(1.6-t*1.1)
				VfxArt.glow(canvas,point,size*4.5,e.color,fade*.5)
				canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(0,-size*2.6),point+Vector2(size,0),point+Vector2(0,size*.9),point+Vector2(-size,0)]),Color(hot,fade))
			"heal","mote":
				var size: float=e.size*(1+sin(t*PI))
				VfxArt.star(canvas,point,size*2.4,e.color,fade,e.angle*.15)
				canvas.draw_line(point+Vector2(0,5),point+Vector2(0,12),Color(e.color,fade*.3),1,true)
			"shard":
				var a:=Vector2.from_angle(e.angle);var n:=a.orthogonal();var size: float=e.size*(1-t*.4)
				canvas.draw_colored_polygon(PackedVector2Array([point+a*size*2.2,point-a*size+n*size*.65,point-a*size*1.5-n*size*.5]),color)
				canvas.draw_line(point-a*size,point+a*size*1.7,Color("fff4dd",fade*.9),1,true)
			"ember":
				VfxArt.glow(canvas,point,e.size*4,Color("ff922f"),fade*.45);VfxArt.star(canvas,point,e.size*1.7,Color("ffdfa1"),fade)
			_:
				var direction: Vector2=velocity.normalized();var n:=direction.orthogonal();var tail: float=clampf(velocity.length()*.075,3,30)*(1-t*.5)
				canvas.draw_colored_polygon(PackedVector2Array([point+direction*2,point-direction*tail+n*e.size*.45,point-direction*tail*1.25,point-direction*tail-n*e.size*.45]),color)
				canvas.draw_line(point-direction*tail*.6,point,Color("fff6de",fade),maxf(.8,e.size*.3),true)
func clear() -> void:entries.clear()
