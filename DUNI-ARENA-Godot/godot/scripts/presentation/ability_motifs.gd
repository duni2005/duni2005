class_name AbilityMotifs
extends RefCounted
## One motif per real ability identity. Exact gameplay telegraphs are rendered separately.
const MOTIFS=["blade","arrow","vortex","veil","aegis","lotus","reticle","pellets","duel","fists","greatsword","ripples","jaws","fuse","issen","orbit","cross","comet","tracks","halo","storm","shards","spiral","tracers","tongue","threads"]
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
