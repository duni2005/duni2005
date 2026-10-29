class_name GambleShow
extends Control
## Gambler's room result, drawn and paced for tension. The roulette spins hard, then crawls slot by
## slot under a flapping pointer before it settles; at dice, the player's three dice stop one by
## one, then the gambler's, the last of them tumbling longest under a heartbeat glow. Then the
## verdict lands: a gold burst for a win, a red jolt for a loss. The outcome is decided before the
## animation starts; a tap jumps to the end. `finished` fires once when the result is shown.
signal finished
const SLOT_LABELS = {&"miss":"꽝",&"gold100":"100 G",&"gold300":"300 G",&"gold600":"600 G",&"gold1000":"1,000 G",&"tokens2":"토큰 2",&"item":"아이템",&"card":"전략카드"}
const SPIN: float = 5.2
const SPIN_TURNS: int = 6
## Player's dice stop, then the gambler's; the last one tumbles longest.
const DICE_STOP: Array = [1.0,1.7,2.4,3.5,4.2,5.4]
const VERDICT: float = 5.8
## Seconds the verdict plays before the result counts as shown.
const REVEAL: float = 1.2
const WIN := Color("ffd54a")
const LOSE := Color("ff5a6a")
const DRAW := Color("9fb4d8")
## &"roulette" or &"dice"; `outcome` is the service's outcome for that game.
var game: StringName = &"roulette"
var outcome: Dictionary = {}
var age: float = 99

func play(animate: bool) -> void:
	age=0.0 if animate and UiMotion.enabled else _end();set_process(age<_end())
	if age>=_end():finished.emit.call_deferred()

func _ready() -> void:
	custom_minimum_size.y=200;mouse_filter=Control.MOUSE_FILTER_STOP;clip_contents=true;set_process(false)
	gui_input.connect(func(event):if age<_end() and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:age=_end()-.001)

func _verdict_at() -> float:return SPIN+.15 if game==&"roulette" else VERDICT
func _end() -> float:return _verdict_at()+REVEAL

func _process(dt: float) -> void:
	age+=dt;queue_redraw()
	if age>=_end():set_process(false);finished.emit()

## How the game ended: &"win", &"draw" or &"lose" (a roulette miss counts as a loss).
func _result() -> StringName:
	if game==&"roulette":return &"lose" if outcome.get("reward",&"miss")==&"miss" else &"win"
	return outcome.get("result",&"lose")

func _draw() -> void:
	var v: float=age-_verdict_at();var result: StringName=_result()
	# A loss jolts the panel for a moment.
	var jolt: Vector2=Vector2(sin(age*70),cos(age*55))*7*(1-clampf(v/.35,0,1)) if v>0 and result==&"lose" else Vector2.ZERO
	draw_set_transform(jolt)
	draw_style_box(ArenaUI.box(Color("121a2c"),Color("4b5a86")),Rect2(Vector2.ZERO,size))
	if game==&"roulette":_wheel(jolt)
	else:_dice(jolt)
	draw_set_transform(jolt)
	_verdict(v,result)
	draw_set_transform(Vector2.ZERO)

func _text(at: Vector2,text: String,font_size: int,color: Color,width: float=-1,font: Font=null) -> void:
	var f: Font=font if font!=null else get_theme_default_font()
	draw_string(f,at,text,HORIZONTAL_ALIGNMENT_CENTER if width>0 else HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

## Heartbeat glow around the panel while the outcome hangs in the balance.
func _heartbeat(strength: float,color: Color) -> void:
	if strength<=0:return
	var beat: float=pow(maxf(0,sin(age*TAU*1.4)),6)
	for i in range(3):draw_style_box(ArenaUI.box(Color(0,0,0,0),Color(color,(.35+.4*beat)*strength*(1-i*.3))),Rect2(Vector2.ONE*(2+i*3),size-Vector2.ONE*(4+i*6)))

func _wheel(jolt: Vector2) -> void:
	var slots: Array=TowerContentService.ROULETTE;var n: int=slots.size();var step: float=TAU/n
	var slot: int=int(outcome.get("slot",0));var r: float=minf(size.x*.3,(size.y-64)*.5);var c:=Vector2(size.x*.5,(size.y-40)*.5+8)
	# Lands with the chosen slot under the pointer after several turns; out-quart leaves a long crawl.
	var final: float=-PI*.5-(slot+.5)*step-TAU*SPIN_TURNS
	var x: float=clampf(age/SPIN,0,1);var turn: float=final*(1-pow(1-x,4))
	var done: bool=age>=SPIN;var won: bool=_result()==&"win";var v: float=age-_verdict_at()
	_heartbeat(Motion.phase(age,SPIN-2.2,.6)*(1-Motion.phase(age,SPIN,.2)),Color("ffb347"))
	if done and won:_rays(c,r*1.9,v,WIN if slots[slot]!=&"gold1000" else Color("ffe27a"))
	draw_circle(c+Vector2(0,4),r+8,Color(0,0,0,.35));draw_circle(c,r+8,Color("2a2142"));draw_arc(c,r+8,0,TAU,64,ArenaUI.GOLD,2,true)
	# Bulbs on the rim chase while it spins and blink together once it lands.
	for i in range(24):
		var lit: bool=(int(age*10)+i)%3==0 if not done else int(age*6)%2==0
		draw_circle(c+Vector2.from_angle(i*TAU/24)*(r+4),2.2,Color(ArenaUI.GOLD,.9 if lit else .25))
	# The slot under the pointer right now.
	var under: int=posmod(int(floor((-PI*.5-turn)/step)),n)
	for i in range(n):
		var a0: float=turn+i*step;var points:=PackedVector2Array([c])
		for j in range(9):points.append(c+Vector2.from_angle(a0+step*j/8.0)*r)
		var fill: Color=Color("e0a43a") if slots[i]==&"gold1000" else Color("3a2f6a") if i%2==0 else Color("26325c")
		if i==under and not done:fill=fill.lightened(.18)
		if done and i==slot:fill=fill.lightened(.3+.15*sin(age*10)) if won else fill.darkened(.2)
		elif done:fill=fill.darkened(.45*Motion.phase(age,SPIN,.4))
		draw_colored_polygon(points,fill);draw_line(c,c+Vector2.from_angle(a0)*r,Color(1,1,1,.25),1,true)
		var mid: Vector2=c+Vector2.from_angle(a0+step*.5)*r*.66;var label: String=SLOT_LABELS[slots[i]]
		var w: float=get_theme_default_font().get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		_text(mid+Vector2(-w*.5,4),label,11,Color("1a1206") if slots[i]==&"gold1000" else Color("eef1fa"))
	draw_circle(c,11,Color("10182b"));draw_arc(c,11,0,TAU,24,ArenaUI.GOLD,2,true)
	# The pointer flaps back as each slot edge passes under it.
	var frac: float=fposmod((-PI*.5-turn)/step,1.0);var flap: float=-.45*pow(1-frac,4) if not done else 0.0
	var tip:=c+Vector2(0,-r+8);var pivot:=c+Vector2(0,-r-14)
	draw_set_transform(jolt+pivot,flap,Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-10,0),Vector2(10,0),tip-pivot]),ArenaUI.GOLD)
	draw_circle(Vector2.ZERO,4,Color("fff2cf"))
	draw_set_transform(jolt)
	if not done:_text(Vector2(0,size.y-14),"돌아가는 중…" if age<SPIN-1.6 else "멈춰라…!",14,Color(ArenaUI.MUTED,.6+.4*sin(age*8)),size.x,ArenaUI.heading_font())

func _dice(jolt: Vector2) -> void:
	var player: Array=outcome.get("player",[1,1,1]);var gambler: Array=outcome.get("gambler",[1,1,1]);var die: float=clampf((size.x-170)/3.3,34,52)
	var result: StringName=_result();var v: float=age-VERDICT
	_heartbeat(Motion.phase(age,DICE_STOP[4],.3)*(1-Motion.phase(age,DICE_STOP[5],.15)),LOSE)
	var rows: Array=[["나",player,size.y*.28,0],["도박꾼",gambler,size.y*.6,3]]
	for row in rows:
		var faces: Array=row[1];var y: float=row[2];var first: int=row[3]
		var winner: bool=v>0 and (result==&"win" and first==0 or result==&"lose" and first==3)
		if winner:draw_rect(Rect2(8,y-die*.5-8,size.x-16,die+16),Color(WIN if first==0 else LOSE,.14+.06*sin(age*8)))
		var turn_on: bool=age>=(0.0 if first==0 else DICE_STOP[2]+.2)
		_text(Vector2(16,y+6),row[0],14,Color("eef1fa",1.0 if turn_on else .45),-1,ArenaUI.heading_font())
		var start: float=maxf(74,size.x*.5-(die*3+16)*.5);var total: int=0
		for i in range(3):
			var stop: float=DICE_STOP[first+i];var rolling: bool=age<stop;var center:=Vector2(start+die*.5+i*(die+8),y)
			if not turn_on:
				draw_style_box(ArenaUI.box(Color(1,1,1,.04),Color(1,1,1,.12)),Rect2(center-Vector2.ONE*die*.5,Vector2.ONE*die));continue
			# The faces flicker more slowly as the stop nears.
			var left: float=stop-age;var rate: float=clampf(left*12,3,16)
			var face: int=(int(age*rate)+i*3+first)%6+1 if rolling else int(faces[i])
			var wobble: float=sin(age*40+i)*.3*clampf(left,0,1) if rolling else 0.0
			var thud: float=1+.28*(1-Motion.phase(age,stop,.22)) if not rolling else 1.0
			draw_set_transform(jolt+center+Vector2(0,-6*absf(sin(age*18+i)) if rolling else 0),wobble,Vector2.ONE*thud)
			var rect:=Rect2(-Vector2.ONE*die*.5,Vector2.ONE*die)
			draw_style_box(ArenaUI.box(Color("f3ecdc") if first==0 else Color("e0485a"),Color("3a3326") if first==0 else Color("5a1424")),rect)
			_pips(face,die,Color("2c2620") if first==0 else Color.WHITE)
			draw_set_transform(jolt)
			if not rolling:
				total+=int(faces[i])
				var dust: float=Motion.phase(age,stop,.35)
				if dust<1:draw_arc(center,die*.6+18*dust,0,TAU,24,Color(1,1,1,.4*(1-dust)),2,true)
		if total>0:_text(Vector2(start+die*3+16+12,y+8),"합 %d"%total,17,ArenaUI.GOLD,-1,ArenaUI.numbers_font())
	if v<0:
		var caption: String="나의 차례" if age<DICE_STOP[2]+.2 else "도박꾼의 차례…" if age<DICE_STOP[5] else "결과는…?"
		_text(Vector2(0,size.y-14),caption,14,Color(ArenaUI.MUTED,.6+.4*sin(age*8)),size.x,ArenaUI.heading_font())

## The verdict: a stamp that slams in, with a gold burst for a win and a red flash for a loss.
func _verdict(v: float,result: StringName) -> void:
	if v<0:return
	var color: Color={&"win":WIN,&"draw":DRAW,&"lose":LOSE}[result];var k: float=Motion.phase(v,0,.35)
	if result==&"lose":draw_rect(Rect2(Vector2.ZERO,size),Color(LOSE,.28*(1-Motion.phase(v,0,.4))))
	elif result==&"win":
		draw_rect(Rect2(Vector2.ZERO,size),Color(1,.95,.75,.25*(1-Motion.phase(v,0,.3))))
		TypeArt.motes(self,Rect2(Vector2.ZERO,size),age,Color(WIN,.8),26,true,.35)
	var title: String;var detail: String=""
	if game==&"roulette":
		var reward: StringName=outcome.get("reward",&"miss")
		title="꽝!" if reward==&"miss" else "대박!" if reward==&"gold1000" else "당첨!"
		detail="" if reward==&"miss" else SLOT_LABELS[reward]
	else:
		title={&"win":"승리!",&"draw":"무승부",&"lose":"패배"}[result]
		detail={&"win":"+%s G"%ArenaUI.grouped(int(outcome.get("payout",0))),&"draw":"%d G 반환"%int(outcome.get("payout",0)),&"lose":"도박꾼의 승리"}[result]
	var font: Font=ArenaUI.heading_font();var scale: float=lerpf(2.4,1.0,Motion.emphasis(k));var at:=Vector2(size.x*.5,size.y-30)
	draw_set_transform(at,-.06,Vector2.ONE*scale)
	var w: float=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,26).x
	draw_string_outline(font,Vector2(-w*.5,0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,26,6,Color(0,0,0,.7*k))
	draw_string(font,Vector2(-w*.5,0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color(color.lightened(.2),minf(1,k*1.5)))
	draw_set_transform(Vector2.ZERO)
	if not detail.is_empty():
		var d: float=Motion.out_expo(Motion.phase(v,.3,Motion.ENTER))
		_text(Vector2(0,size.y-6+6*(1-d)),detail,13,Color(color,d),size.x,ArenaUI.numbers_font())

func _rays(c: Vector2,reach: float,v: float,color: Color) -> void:
	var k: float=Motion.out_expo(clampf(v/.5,0,1))
	for i in range(14):
		var a: float=i*TAU/14+age*.4
		draw_colored_polygon(PackedVector2Array([c,c+Vector2.from_angle(a)*reach*k,c+Vector2.from_angle(a+.1)*reach*k]),Color(color,.12))
	draw_arc(c,reach*.6*Motion.out_expo(clampf(v/.6,0,1)),0,TAU,48,Color(color,.7*(1-clampf(v/.6,0,1))),3,true)

## Standard pip layout for `face` on a die centred at the origin.
func _pips(face: int,die: float,color: Color) -> void:
	var o: float=die*.27
	var spots: Dictionary={1:[Vector2.ZERO],2:[Vector2(-o,-o),Vector2(o,o)],3:[Vector2(-o,-o),Vector2.ZERO,Vector2(o,o)],4:[Vector2(-o,-o),Vector2(o,-o),Vector2(-o,o),Vector2(o,o)],5:[Vector2(-o,-o),Vector2(o,-o),Vector2.ZERO,Vector2(-o,o),Vector2(o,o)],6:[Vector2(-o,-o),Vector2(o,-o),Vector2(-o,0),Vector2(o,0),Vector2(-o,o),Vector2(o,o)]}
	for p in spots[face]:draw_circle(p,die*.08,color)
