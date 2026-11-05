class_name AbilityMotifs
extends RefCounted
## One motif per real ability identity. Exact gameplay telegraphs are rendered separately.
const MOTIFS=["blade","arrow","vortex","veil","aegis","lotus","reticle","pellets","duel","fists","greatsword","ripples","jaws","fuse","issen","orbit","cross","comet","tracks","halo","storm","shards","spiral","tracers","tongue","threads","stake","rails","prism","parcel","magnet","frost","flame","gust","crosshair","slime","feathers","heart","miasma","glacier","flameblade","snowball","gift","spin","bounty"]
static func draw(canvas: CanvasItem,u: BattleUnit,p: Vector2,time: float,fade: float=0) -> void:
	var c: Color=CharacterVisuals.PROJECTILE_COLORS.get("star",Color("e8c78e"))
	c=Color(AttackVisuals.ink(u.data.type_id),1-fade)
	VfxArt.glow(canvas,p,90*u.combat_scale(),c,.2*(1-fade))
	VfxArt.sigil(canvas,p,53*u.combat_scale(),time,c,.4*(1-fade))
	var a: float=u.facing;var r: float=52*u.combat_scale();var motif: String=MOTIFS[u.data.type_id]
	match motif:
		"blade","greatsword","issen":VisualShapes.slash(canvas,p,r*1.5,a-1.4,a+.8,c,24 if motif=="greatsword" else 13,1-fade)
		"arrow","comet","tracers":
			for i in range(3):VisualShapes.streak(canvas,p+Vector2.from_angle(a+PI/2)*(i-1)*13,a,r*2,5,c,1-fade)
		"vortex","spiral","orbit":
			for i in range(18):
				var angle: float=i*2.399+time;var point: Vector2=p+Vector2.from_angle(angle)*(r*(.4+fmod(i*.17,1)))
				canvas.draw_circle(point,2+(i%3),c)
		"aegis","halo","veil":VisualShapes.barrier(canvas,p,r,c,time)
		"lotus","cross":
			for i in range(5):ArenaIcon.draw(canvas,p+Vector2.from_angle(i*TAU/5-time)*r,"heal",15,c)
		"reticle":
			canvas.draw_arc(p,r,0,TAU,40,c,2)
			for i in range(4):canvas.draw_line(p+Vector2.from_angle(i*PI/2)*r*.7,p+Vector2.from_angle(i*PI/2)*r*1.3,c,2)
		"flame":
			# Tongues of flame licking upward around the centre.
			for i in range(7):
				var x: float=(i-3)*r*.28;var h: float=r*(.55+.35*sin(time*6+i*1.7))
				canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(x-9,r*.45),p+Vector2(x+9,r*.45),p+Vector2(x+sin(time*4+i)*6,r*.45-h)]),Color(c,.75))
		"feathers":
			# A fan of feathers sweeping back and forth.
			for i in range(5):
				var ang: float=-PI/2+(i-2)*.32+sin(time*2)*.12;var q: Vector2=p+Vector2.from_angle(ang)*r*.75
				canvas.draw_line(q-Vector2.from_angle(ang)*r*.2,q+Vector2.from_angle(ang)*r*.2,Color(c,.85),2.5,true)
		"heart":
			# A heart beating at the centre.
			var hs: float=r*.45*(1+.1*sin(time*6));var pts:=PackedVector2Array()
			for i in range(24):
				var t: float=TAU*i/24.0
				pts.append(p+Vector2(16*pow(sin(t),3),-(13*cos(t)-5*cos(2*t)-2*cos(3*t)-cos(4*t)))/16.0*hs)
			canvas.draw_colored_polygon(pts,Color(c,.85))
		"miasma":
			# Slow green-violet fog puffs drifting around.
			for i in range(5):
				var q: Vector2=p+Vector2(cos(time*.6+i*1.3),sin(time*.5+i*2.1))*r*.55
				canvas.draw_circle(q,r*(.22+.06*sin(time*2+i)),Color(c,.35))
		"glacier":
			# A ring of ice shards breathing in and out.
			for i in range(8):
				var a2: float=i*TAU/8+time*.3;var q: Vector2=p+Vector2.from_angle(a2)*r*(.6+.08*sin(time*3+i))
				canvas.draw_colored_polygon(PackedVector2Array([q+Vector2.from_angle(a2)*r*.18,q+Vector2.from_angle(a2+1.6)*r*.06,q+Vector2.from_angle(a2-1.6)*r*.06]),Color(c,.85))
		"flameblade":
			# A burning blade arc sweeping around.
			var sw: float=time*2.4
			canvas.draw_arc(p,r*.7,sw,sw+2.2,24,Color(c,.85),r*.14,true)
			canvas.draw_arc(p,r*.7,sw,sw+1.2,16,Color("fff1c4",.8),r*.06,true)
		"snowball":
			# A snowball rolling round with its tumbling streaks.
			var q: Vector2=p+Vector2.from_angle(time*1.2)*r*.25
			canvas.draw_circle(q,r*.42,Color(c,.9));canvas.draw_arc(q,r*.3,time*4,time*4+1.8,10,Color(1,1,1,.8),2,true)
		"gift":
			# A gift box bobbing with a ribbon.
			var q: Vector2=p+Vector2(0,sin(time*2.5)*r*.12);var s2: float=r*.32
			canvas.draw_rect(Rect2(q-Vector2(s2,s2),Vector2(s2,s2)*2),Color(c,.9))
			canvas.draw_line(q-Vector2(0,s2),q+Vector2(0,s2),Color(1,.9,.4),3);canvas.draw_line(q-Vector2(s2,0),q+Vector2(s2,0),Color(1,.9,.4),3)
		"spin":
			# A spinning top: a whirl of curved strokes round a bright core.
			for k in range(3):
				var turn: float=time*9+k*TAU/3;canvas.draw_arc(p,r*(.28+.08*k),turn,turn+2.2,14,Color(c,.85-.2*k),3,true)
			canvas.draw_circle(p,r*.12,Color(1,1,1,.9))
		"bounty":
			# A wanted target: crosshair ring with a gold coin at its centre.
			canvas.draw_arc(p,r*.36,0,TAU,32,Color(c,.9),2.5,true)
			for k in range(4):
				var arm: Vector2=Vector2.from_angle(k*PI*.5+time*.6);canvas.draw_line(p+arm*r*.22,p+arm*r*.48,Color(c,.9),2.5,true)
			canvas.draw_circle(p,r*.13,Color(1,.84,.35))
		"slime":
			# Bouncing droplets around the centre.
			for i in range(6):
				var q: Vector2=p+Vector2.from_angle(i*TAU/6+time*.7)*r*.8+Vector2(0,-absf(sin(time*5+i))*r*.25)
				canvas.draw_circle(q,r*.16,Color(c,.85));canvas.draw_circle(q+Vector2(-r*.05,-r*.05),r*.05,Color(1,1,1,.7))
		"gust":
			# Curling gusts sweeping round the centre.
			for i in range(5):
				var turn: float=time*1.6+i*TAU/5
				canvas.draw_arc(p,r*(.5+.12*i),turn,turn+1.6,16,Color(c,.8-i*.1),3,true)
		"crosshair":
			canvas.draw_arc(p,r*.8,0,TAU,40,c,2.5)
			for i in range(4):
				var d: Vector2=Vector2.from_angle(i*PI/2+time*.5);canvas.draw_line(p+d*r*.35,p+d*r*1.15,c,2.5)
			canvas.draw_circle(p,4,c)
		"frost":
			for i in range(6):
				var d: Vector2=Vector2.from_angle(time*.4+i*TAU/6)
				canvas.draw_line(p+d*r*.3,p+d*r,c,3);canvas.draw_line(p+d*r*.7,p+d*r*.7+d.rotated(.7)*12,c,2);canvas.draw_line(p+d*r*.7,p+d*r*.7+d.rotated(-.7)*12,c,2)
		"storm":
			for i in range(5):VisualShapes.bolt(canvas,p,p+Vector2.from_angle(time+i*TAU/5)*r*1.6,c,i+floor(time*10),2)
		"shards":
			for i in range(8):
				var q: Vector2=p+Vector2.from_angle(time*.3+i*TAU/8)*r
				canvas.draw_colored_polygon(PackedVector2Array([q+Vector2(0,-9),q+Vector2(7,6),q+Vector2(-5,4)]),c)
		"tongue","threads":
			for i in range(4):canvas.draw_line(p+Vector2((i-1.5)*14,-r),p+Vector2((i-1.5)*26,r*.6),c,2)
		"jaws":
			for i in range(7):
				var q: Vector2=p+Vector2(-r+i*r/3,-r*.4)
				canvas.draw_colored_polygon(PackedVector2Array([q,q+Vector2(10,20),q+Vector2(18,0)]),c)
		"fuse":
			for i in range(10):VisualShapes.streak(canvas,p+Vector2.from_angle(i*TAU/10)*r,i*TAU/10,22,4,c,1-fade)
		"duel":
			for i in range(3):ArenaIcon.draw(canvas,p+Vector2.from_angle(time+i*TAU/3)*r,["fang","shield","battle"][i],20,c)
		"fists":
			for i in range(3):canvas.draw_rect(Rect2(p+Vector2.from_angle(a)*r+Vector2((i-1)*18,-10),Vector2(13,16)),c)
		"tracks":
			for i in [-1,1]:canvas.draw_line(p+Vector2(-r,i*22),p+Vector2(r,i*22),c,5)
		"pellets":
			for i in range(7):VisualShapes.streak(canvas,p+Vector2.from_angle(a+(i-3)*.12)*r,a+(i-3)*.12,24,3,c)
		_:
			for i in range(3):canvas.draw_arc(p,r*(.65+i*.25),time+i,time+i+PI*.7,20,c,2)
