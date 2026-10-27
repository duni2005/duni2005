class_name WalletBar
extends Label
## Persistent wallet presentation. The Label text remains a semantic/accessibility summary.
var battle: BattleManager
var guild: GuildManager
var caption: String="DUNI TOWER"
## Single-row battle variant; frees arena height while the fight runs.
var compact: bool=false:
	set(value):
		if compact==value:return
		compact=value;custom_minimum_size.y=42 if compact else 70;queue_redraw()
var previous_gold: int=-1
var gold_pulse: float=0
var gold_delta: int=0
func _ready() -> void:
	custom_minimum_size.y=70;clip_text=true;autowrap_mode=TextServer.AUTOWRAP_OFF;add_theme_font_size_override("font_size",1);add_theme_color_override("font_color",Color.TRANSPARENT)
var updates_suspended: bool=false
var shown_gold: float=-1
var shown_tokens: float=-1
var tracks: Dictionary={}
var pulses: Dictionary={}
## Number rolls: seconds of rolling; when one lands the figure pops and flashes for LAND seconds.
const ROLL: float=.5
const LAND: float=.22
## A gain at least this big also floats a "+N" next to the figure.
const BIG_GAIN: Dictionary={"gold":100,"gem":2}
var lands: Dictionary={}
var floats: Array[Dictionary]=[]
var _paint_state: Array=[]
var _panel_style: StyleBoxFlat
func anchor(kind: String) -> Vector2:
	var offset: Vector2=(Vector2(18,21) if kind=="gold" else Vector2(size.x*.30+16,21)) if compact else Vector2(18,16) if kind=="gold" else Vector2(size.x*.30+16,16)
	return ArenaUI.control_center(self)-size*.5+offset
func animate_resource(kind: String,from_value: int,to_value: int,delay: float) -> void:
	if kind=="gold":shown_gold=from_value;previous_gold=to_value
	else:shown_tokens=from_value
	tracks[kind]={"from":float(from_value),"to":float(to_value),"age":-delay,"duration":ROLL}
	if to_value<from_value:pulses[kind]=.32
	if UiMotion.enabled and to_value-from_value>=int(BIG_GAIN[kind]):
		if floats.size()>=4:floats.pop_front()
		floats.append({"kind":kind,"value":to_value-from_value,"age":-delay})
## Show the current balance at once; used when a wallet comes back after changes were shown elsewhere.
func snap() -> void:
	tracks.clear();pulses.clear()
	if guild!=null:shown_gold=guild.state.gold;shown_tokens=guild.state.tokens;previous_gold=guild.state.gold
	queue_redraw()
func animate_exchange(kind: String,from_value: int,spent: int,to_value: int) -> void:
	animate_resource(kind,from_value,from_value-spent,0)
	tracks[kind]["next"]={"from":float(from_value-spent),"to":float(to_value),"age":-.4,"duration":ROLL}
func _process(dt: float) -> void:
	if is_visible_in_tree() and not updates_suspended:advance_view(dt)
func advance_view(dt: float) -> void:
	if guild==null:return
	if shown_gold<0:shown_gold=guild.state.gold
	if shown_tokens<0:shown_tokens=guild.state.tokens
	for kind in ["gold","gem"]:
		var actual: int=guild.state.gold if kind=="gold" else guild.state.tokens
		var shown: float=shown_gold if kind=="gold" else shown_tokens
		if not tracks.has(kind) and int(round(shown))!=actual:animate_resource(kind,int(round(shown)),actual,.72 if actual>shown else 0)
	for kind in tracks.keys():
		var track: Dictionary=tracks[kind];var old: float=track.age;track.age+=dt
		if track.age>=track.duration and track.has("next"):
			var leftover: float=track.age-track.duration;track=track.next;old=track.age;track.age+=leftover;tracks[kind]=track
		if old<0 and track.age>=0:pulses[kind]=.32
		var t: float=clampf(track.age/track.duration,0,1);var value: float=lerpf(track.from,track.to,Motion.out_expo(t))
		if kind=="gold":shown_gold=value
		else:shown_tokens=value
		if t>=1:
			tracks.erase(kind)
			if UiMotion.enabled and not track.has("next"):lands[kind]=0.0
	for kind in pulses.keys():
		pulses[kind]=maxf(0,pulses[kind]-dt)
		if pulses[kind]<=0:pulses.erase(kind)
	for kind in lands.keys():
		lands[kind]+=dt
		if lands[kind]>=LAND:lands.erase(kind)
	for i in range(floats.size()-1,-1,-1):
		floats[i].age+=dt
		if floats[i].age>=.8:floats.remove_at(i)
	var state: Array=[shown_gold,shown_tokens,guild.state.player_hp,guild.state.player_max_hp,size,pulses.duplicate(),lands.duplicate(),floats.size()]
	if not lands.is_empty() or not floats.is_empty():_paint_state=[]
	if state!=_paint_state:_paint_state=state;queue_redraw()
func _draw() -> void:
	if guild==null:return
	if _panel_style==null:_panel_style=ArenaUI.card_style(Color("4a5680"),Color("141b2d"))
	if compact:_draw_compact();return
	draw_style_box(_panel_style,Rect2(0,0,size.x,68))
	var font: Font=get_theme_default_font();var numbers: Font=ArenaUI.numbers_font();var w: float=size.x*.30
	for kind in pulses:
		var c: Color=Color("ffdb75") if kind=="gold" else Color("92e6ff")
		draw_style_box(ArenaUI.box(Color(c,float(pulses[kind])*.22),Color(c,float(pulses[kind])*1.4)),Rect2(2 if kind=="gold" else w,2,w-3,64))
	ArenaIcon.draw(self,Vector2(18,16),"gold",16,Color.WHITE);ArenaIcon.draw(self,Vector2(w+16,16),"gem",16,Color.WHITE);ArenaIcon.draw(self,Vector2(w*2+14,16),"heart",16,Color.WHITE)
	draw_string(font,Vector2(30,20),"골드",HORIZONTAL_ALIGNMENT_LEFT,-1,10,ArenaUI.MUTED)
	var amount: String=ArenaUI.grouped(int(round(shown_gold if shown_gold>=0 else guild.state.gold)))
	_figure(numbers,Vector2(12,48),amount,30,"gold")
	var gold_width: float=numbers.get_string_size(amount,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
	draw_string(numbers,Vector2(14+gold_width,48),"G",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ArenaUI.MUTED)
	draw_string(font,Vector2(w+28,20),"토큰",HORIZONTAL_ALIGNMENT_LEFT,-1,10,ArenaUI.MUTED)
	_figure(numbers,Vector2(w+10,48),str(int(round(shown_tokens if shown_tokens>=0 else guild.state.tokens))),30,"gem")
	draw_string(font,Vector2(w*2+26,20),"플레이어 HP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,ArenaUI.MUTED)
	var health: String=str(ceili(guild.state.player_hp));var health_width: float=numbers.get_string_size(health,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
	draw_string(numbers,Vector2(w*2+8,48),health,HORIZONTAL_ALIGNMENT_LEFT,-1,30,ArenaUI.HP)
	draw_string(numbers,Vector2(w*2+13+health_width,48),"/ %d"%ceili(guild.state.player_max_hp),HORIZONTAL_ALIGNMENT_LEFT,-1,14,ArenaUI.MUTED)
	draw_rect(Rect2(w*2+8,61,size.x-w*2-20,3),Color("26304a"));draw_rect(Rect2(w*2+8,61,(size.x-w*2-20)*clampf(guild.state.player_hp/maxf(1,guild.state.player_max_hp),0,1),3),ArenaUI.HP)
	_draw_floats(numbers,{"gold":Vector2(16+gold_width+12,40),"gem":Vector2(w+52,40)})
func _draw_compact() -> void:
	draw_style_box(_panel_style,Rect2(0,0,size.x,40))
	var numbers: Font=ArenaUI.numbers_font();var w: float=size.x*.30
	for kind in pulses:
		var c: Color=Color("ffdb75") if kind=="gold" else Color("92e6ff")
		draw_style_box(ArenaUI.box(Color(c,float(pulses[kind])*.22),Color(c,float(pulses[kind])*1.4)),Rect2(2 if kind=="gold" else w,2,w-3,36))
	ArenaIcon.draw(self,Vector2(18,21),"gold",16,Color.WHITE);ArenaIcon.draw(self,Vector2(w+16,21),"gem",16,Color.WHITE);ArenaIcon.draw(self,Vector2(w*2+14,21),"heart",16,Color.WHITE)
	_figure(numbers,Vector2(32,29),ArenaUI.grouped(int(round(shown_gold if shown_gold>=0 else guild.state.gold))),22,"gold")
	_figure(numbers,Vector2(w+30,29),str(int(round(shown_tokens if shown_tokens>=0 else guild.state.tokens))),22,"gem")
	_draw_floats(numbers,{"gold":Vector2(w-34,26),"gem":Vector2(w+64,26)})
	var health: String="%d / %d"%[ceili(guild.state.player_hp),ceili(guild.state.player_max_hp)];var hw: float=numbers.get_string_size(health,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
	draw_string(numbers,Vector2(w*2+28,29),health,HORIZONTAL_ALIGNMENT_LEFT,-1,22,ArenaUI.HP)
	var bar_x: float=w*2+36+hw;var bar_w: float=size.x-bar_x-14
	if bar_w>24:
		draw_rect(Rect2(bar_x,18,bar_w,5),Color("26304a"));draw_rect(Rect2(bar_x,18,bar_w*clampf(guild.state.player_hp/maxf(1,guild.state.player_max_hp),0,1),5),ArenaUI.HP)
## A wallet figure; right after a roll lands it pops up a little and flashes from white back to gold.
func _figure(font: Font,at: Vector2,text: String,font_size: int,kind: String) -> void:
	var color: Color=ArenaUI.GOLD
	if lands.has(kind):
		var k: float=clampf(float(lands[kind])/LAND,0,1);var grow: float=1+.16*sin(k*PI)
		var center: Vector2=at+Vector2(font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5,-font_size*.35)
		draw_set_transform(center*(1-grow),0,Vector2.ONE*grow);color=Color.WHITE.lerp(ArenaUI.GOLD,k)
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
	draw_set_transform(Vector2.ZERO)
## "+N" for big gains, popping up beside the figure and fading as it rises.
func _draw_floats(font: Font,anchors: Dictionary) -> void:
	for item in floats:
		if item.age<0:continue
		var k: float=clampf(item.age/.8,0,1);var at: Vector2=anchors[item.kind]+Vector2(0,-16*Motion.out_expo(k))
		var c: Color=Color("ffdb75") if item.kind=="gold" else Color("92e6ff")
		draw_string_outline(font,at,"+%d"%item.value,HORIZONTAL_ALIGNMENT_LEFT,-1,16,3,Color(.03,.05,.1,(1-k)*.8))
		draw_string(font,at,"+%d"%item.value,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(c,minf(1,(1-k)*2)))
