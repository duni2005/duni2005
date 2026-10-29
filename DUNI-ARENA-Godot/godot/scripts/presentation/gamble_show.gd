class_name GambleShow
extends Control
## Gambler's room result, drawn: the roulette wheel spins down onto the slot the service picked,
## or three dice per side tumble and stop one after another. The outcome is decided before the
## animation starts; a tap jumps to the end. `finished` fires once when the result is shown.
signal finished
const SLOT_LABELS = {&"miss":"꽝",&"gold100":"100 G",&"gold300":"300 G",&"gold600":"600 G",&"gold1000":"1,000 G",&"tokens2":"토큰 2",&"item":"아이템",&"card":"전략카드"}
const SPIN: float = 2.6
const DICE_STOP: Array = [.5,.8,1.1,1.6,1.9,2.2]
const DICE_END: float = 2.5
## &"roulette" or &"dice"; `outcome` is the service's outcome for that game.
var game: StringName = &"roulette"
var outcome: Dictionary = {}
var age: float = 99

func play(animate: bool) -> void:
	age=0.0 if animate and UiMotion.enabled else _end();set_process(age<_end())
	if age>=_end():finished.emit.call_deferred()

func _ready() -> void:
	custom_minimum_size.y=200;mouse_filter=Control.MOUSE_FILTER_STOP;set_process(false)
	gui_input.connect(func(event):if age<_end() and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:age=_end()-.001)

func _end() -> float:return SPIN+.3 if game==&"roulette" else DICE_END

func _process(dt: float) -> void:
	age+=dt;queue_redraw()
	if age>=_end():set_process(false);finished.emit()

func _draw() -> void:
	draw_style_box(ArenaUI.box(Color("121a2c"),Color("4b5a86")),Rect2(Vector2.ZERO,size))
	if game==&"roulette":_wheel()
	else:_dice()

func _text(at: Vector2,text: String,font_size: int,color: Color,width: float=-1,font: Font=null) -> void:
	var f: Font=font if font!=null else get_theme_default_font()
	draw_string(f,at,text,HORIZONTAL_ALIGNMENT_CENTER if width>0 else HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func _wheel() -> void:
	var slots: Array=TowerContentService.ROULETTE;var n: int=slots.size();var step: float=TAU/n
	var slot: int=int(outcome.get("slot",0));var r: float=minf(size.x*.3,(size.y-54)*.5);var c:=Vector2(size.x*.5,(size.y-30)*.5+6)
	# Ends with the chosen slot's centre under the pointer at the top, after four full turns.
	var final: float=-PI*.5-(slot+.5)*step-TAU*4
	var k: float=Motion.out_quint(age/SPIN);var turn: float=final*k
	draw_circle(c+Vector2(0,4),r+6,Color(0,0,0,.35));draw_circle(c,r+6,Color("2a2142"));draw_arc(c,r+6,0,TAU,64,ArenaUI.GOLD,2,true)
	var done: bool=age>=SPIN
	for i in range(n):
		var a0: float=turn+i*step;var points:=PackedVector2Array([c])
		for j in range(9):points.append(c+Vector2.from_angle(a0+step*j/8.0)*r)
		var fill: Color=Color("e0a43a") if slots[i]==&"gold1000" else Color("3a2f6a") if i%2==0 else Color("26325c")
		if done and i==slot:fill=fill.lightened(.35)
		draw_colored_polygon(points,fill);draw_line(c,c+Vector2.from_angle(a0)*r,Color(1,1,1,.25),1,true)
		var mid: Vector2=c+Vector2.from_angle(a0+step*.5)*r*.66;var label: String=SLOT_LABELS[slots[i]]
		var w: float=get_theme_default_font().get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		_text(mid+Vector2(-w*.5,4),label,11,Color("1a1206") if slots[i]==&"gold1000" else Color("eef1fa"))
	draw_circle(c,10,Color("10182b"));draw_arc(c,10,0,TAU,24,ArenaUI.GOLD,2,true)
	# Pointer at the top.
	draw_colored_polygon(PackedVector2Array([c+Vector2(-9,-r-12),c+Vector2(9,-r-12),c+Vector2(0,-r+6)]),ArenaUI.GOLD)
	if done:
		var reward: StringName=outcome.get("reward",&"miss")
		_text(Vector2(0,size.y-10),"꽝! 아무것도 얻지 못했습니다" if reward==&"miss" else "당첨 · "+SLOT_LABELS[reward],15,ArenaUI.MUTED if reward==&"miss" else ArenaUI.GOLD,size.x,ArenaUI.heading_font())

func _dice() -> void:
	var player: Array=outcome.get("player",[1,1,1]);var gambler: Array=outcome.get("gambler",[1,1,1]);var die: float=44
	var rows: Array=[["나",player,size.y*.3,0],["도박꾼",gambler,size.y*.64,3]]
	for row in rows:
		var faces: Array=row[1];var y: float=row[2];var settled: bool=age>=DICE_STOP[row[3]+2]
		_text(Vector2(16,y+6),row[0],13,Color("eef1fa"),-1,ArenaUI.heading_font())
		var start: float=size.x*.5-(die*3+16)*.5
		for i in range(3):
			var stop: float=DICE_STOP[row[3]+i];var rolling: bool=age<stop
			var face: int=(int(age*14)+i*3+row[3])%6+1 if rolling else int(faces[i])
			var wobble: float=sin(age*40+i)*.25 if rolling else 0.0
			var center:=Vector2(start+die*.5+i*(die+8),y)
			draw_set_transform(center,wobble,Vector2.ONE)
			var rect:=Rect2(-Vector2.ONE*die*.5,Vector2.ONE*die)
			draw_style_box(ArenaUI.box(Color("f3ecdc") if row[3]==0 else Color("e0485a"),Color("3a3326") if row[3]==0 else Color("5a1424")),rect)
			_pips(face,die,Color("2c2620") if row[3]==0 else Color.WHITE)
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		if settled:
			var total: int=faces.reduce(func(s,v):return s+int(v),0)
			_text(Vector2(size.x-62,y+8),"합 %d"%total,16,ArenaUI.GOLD,-1,ArenaUI.numbers_font())
	if age>=DICE_END:
		var result: StringName=outcome.get("result",&"lose")
		var text: String={&"win":"승리! +%s G"%ArenaUI.grouped(int(outcome.get("payout",0))),&"draw":"무승부 · %d G 반환"%int(outcome.get("payout",0)),&"lose":"패배 · 도박꾼의 승리"}[result]
		_text(Vector2(0,size.y-12),text,16,ArenaUI.GOLD if result==&"win" else Color("9fb4d8") if result==&"draw" else Color("ff8a8a"),size.x,ArenaUI.heading_font())

## Standard pip layout for `face` on a die centred at the origin.
func _pips(face: int,die: float,color: Color) -> void:
	var o: float=die*.27
	var spots: Dictionary={1:[Vector2.ZERO],2:[Vector2(-o,-o),Vector2(o,o)],3:[Vector2(-o,-o),Vector2.ZERO,Vector2(o,o)],4:[Vector2(-o,-o),Vector2(o,-o),Vector2(-o,o),Vector2(o,o)],5:[Vector2(-o,-o),Vector2(o,-o),Vector2.ZERO,Vector2(-o,o),Vector2(o,o)],6:[Vector2(-o,-o),Vector2(o,-o),Vector2(-o,0),Vector2(o,0),Vector2(-o,o),Vector2(o,o)]}
	for p in spots[face]:draw_circle(p,die*.08,color)
