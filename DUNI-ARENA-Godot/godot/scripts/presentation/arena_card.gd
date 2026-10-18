class_name ArenaCard
extends Button
## Semantic Button API, authored card drawing. Domain values are copied for display only.
var card_type: String="member"
var type_id: int=0
var title: String=""
var subtitle: String=""
var description: String=""
var kind: String=""
var status_text: String=""
var hp: float=1
var hp_max: float=1
var energy: int=5
var level: int=0
var stars: int=0
var gauge: float=0
var price: String=""
var stats_summary: String=""
var portrait_types: Array[int]=[]
var dead: bool=false
var sold: bool=false
var spent: bool=false
var selected: bool=false
var source_id: String=""
var equipment_kinds: Array[String]=[]
var equipment_slots: int=2
var strip_style: bool=false
var cached_style: StyleBoxFlat
# Visual tiers: units read as information, choices as warm actions, inventory as slots.
const UNIT_TYPES: Array=["member","deploy_member","mini_member","party","revival_member","promotion_member","ally"]
const ACTION_TYPES: Array=["event_option","product","choice","recruit","stake","prediction_team","item"]
const SHOP_TYPES: Array=["product","recruit"]
func show_member(guild: GuildManager,member: GuildMemberState) -> void:
	# Copy presentation values. Inventory ownership remains run data.
	source_id=member.member_id;type_id=member.unit_type_id;title=guild.definition(type_id).display_name
	hp=member.current_hp;hp_max=guild.member_max_hp(member);energy=member.energy;level=member.level;stars=member.stars;dead=not member.is_alive()
	equipment_slots=GuildMemberCombatStats.equipment_limit(member);equipment_kinds.clear()
	for item in guild.state.inventory:
		if not item.consumed and item.equipped_to_member_id==member.member_id:equipment_kinds.append(String(item.kind))
	tooltip_text="%s · %s\nHP %s · 기력 %d / 5\n장비: %s"%[title,ArenaUI.member_label(member.member_id),ArenaUI.hp(hp,hp_max),energy,"없음" if equipment_kinds.is_empty() else " / ".join(equipment_kinds.map(func(k):return ItemCatalog.get_item(k).display_name))]
	queue_redraw()
func draw_equipment(y: float,slot_size: float=15) -> void:
	var spacing: float=slot_size+3;var start: float=(size.x-(equipment_slots*spacing-3))*.5
	for i in range(equipment_slots):
		var at:=Vector2(start+i*spacing,y)
		draw_style_box(ArenaUI.box(Color("121a2c"),Color("3a4a72")),Rect2(at,Vector2.ONE*slot_size))
		if i<equipment_kinds.size():ArenaIcon.draw(self,at+Vector2.ONE*slot_size*.5,equipment_kinds[i],slot_size-2,Color.WHITE)
		else:draw_line(at+Vector2(5,slot_size*.5),at+Vector2(slot_size-5,slot_size*.5),Color("6d7aa0"),1)
func draw_price_chip(rect: Rect2,sold_label: String) -> void:
	# Gold prices sit on a dark-gold chip, token prices on a dark-blue one: currency icon + amount.
	var m: RegExMatch=RegEx.create_from_string("(\\d+)\\s*G$").search(price)
	var currency: String="gold" if m!=null else ""
	if m==null:
		m=RegEx.create_from_string("토큰\\s*(\\d+)").search(price);currency="gem" if m!=null else ""
	if sold or currency.is_empty():
		draw_style_box(ArenaUI.box(Color("201f1d"),Color("3a3733")),rect)
		write(Vector2(rect.position.x,rect.get_center().y+5),sold_label if sold else price,12,Color("8d8a85"),rect.size.x,true);return
	var gold_chip: bool=currency=="gold";var dim: float=.35 if disabled else 1.0
	var chip: StyleBoxFlat=ArenaUI.box(Color("3a2f18") if gold_chip else Color("1a2a45"),Color(Color("c9a24a") if gold_chip else Color("5f9bd8"),dim));chip.set_corner_radius_all(7)
	draw_style_box(chip,rect)
	var font: Font=ArenaUI.numbers_font();var amount: String=m.get_string(1);var fs: int=17
	var width: float=18+5+font.get_string_size(amount,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x;var x: float=rect.get_center().x-width*.5
	ArenaIcon.draw(self,Vector2(x+9,rect.get_center().y),currency,17,Color(1,1,1,dim))
	# Unavailable price: faded chip, amount in red.
	draw_string(font,Vector2(x+23,rect.get_center().y+6),amount,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,ArenaUI.DANGER if disabled else ArenaUI.GOLD if gold_chip else Color("bfe0ff"))
func draw_badge(at: Vector2,radius: float,ring: Color) -> void:
	draw_circle(at,radius,Color("1d1a17"));draw_arc(at,radius,0,TAU,40,Color(ring,.45),1.5,true)
func draw_energy(y: float,width: float,height: float=4) -> void:
	# Five-segment energy meter, the same pips the unit strip uses, centred on the card.
	var gap: float=2;var cell: float=(width-gap*4)/5;var x: float=(size.x-width)*.5
	for i in range(5):draw_style_box(ArenaUI.pip_style(i<energy),Rect2(x+i*(cell+gap),y,cell,height))
func draw_member_summary(compact: bool=false) -> void:
	var tint: Color=ArenaUI.DANGER if dead else ArenaUI.HP
	if compact and strip_style:
		UnitIcon.draw(self,Rect2(size.x*.5-15,4,30,30),type_id,.4 if dead else 1)
		write(Vector2(0,45),subtitle,9,ArenaUI.MUTED,size.x,true)
		if not equipment_kinds.is_empty():
			for i in range(equipment_kinds.size()):ArenaIcon.draw(self,Vector2(size.x*.5+(i-(equipment_kinds.size()-1)*.5)*13,55),equipment_kinds[i],11,Color.WHITE)
		else:write(Vector2(0,57),"·",10,ArenaUI.MUTED,size.x,true)
		write(Vector2(0,69),"사망" if dead else "%d / %d"%[ceili(hp),ceili(hp_max)],9,tint,size.x,true)
		draw_rect(Rect2(5,73,size.x-10,3),Color("0e1424"));draw_rect(Rect2(5,73,(size.x-10)*clampf(hp/maxf(1,hp_max),0,1),3),tint)
		for i in range(5):draw_style_box(ArenaUI.pip_style(i<energy),Rect2(5+i*(size.x-10)/5,80,(size.x-10)/5-2,3))
		return
	if compact:
		var tiny: bool=size.y<84;var p: float=24 if tiny else 28
		UnitIcon.draw(self,Rect2(size.x*.5-p*.5,4,p,p),type_id,.4 if dead else 1)
		if not tiny:write(Vector2(0,42),subtitle if not subtitle.is_empty() else title,9,ArenaUI.MUTED,size.x,true)
		var hp_y: float=37 if tiny else 54
		write(Vector2(0,hp_y),"사망" if dead else "HP %d/%d"%[ceili(hp),ceili(hp_max)],9,tint,size.x,true)
		draw_rect(Rect2(6,hp_y+3,size.x-12,2),Color("0e1424"));draw_rect(Rect2(6,hp_y+3,(size.x-12)*clampf(hp/maxf(1,hp_max),0,1),2),tint)
		draw_energy(hp_y+9,size.x-12)
		draw_equipment(hp_y+20,12)
		return
	var small: bool=card_type=="deploy_member"
	write(Vector2(0,17),title,12 if small else 13,Color("eef1fa"),size.x,true)
	var portrait: float=32 if small else 42
	UnitIcon.draw(self,Rect2(size.x*.5-portrait*.5,21,portrait,portrait),type_id,.4 if dead else 1)
	write(Vector2(0,65 if small else 76),subtitle,9 if small else 10,ArenaUI.MUTED,size.x,true)
	var hp_y: float=80 if small else 91
	write(Vector2(0,hp_y),"사망" if dead else "HP "+ArenaUI.hp(hp,hp_max),10,tint,size.x,true)
	draw_rect(Rect2(10,hp_y+4,size.x-20,3),Color("0e1424"));draw_rect(Rect2(10,hp_y+4,(size.x-20)*clampf(hp/maxf(1,hp_max),0,1),3),tint)
	draw_energy(hp_y+12,size.x-20,5)
	draw_equipment(hp_y+24,13 if small else 15)
	if not small:write(Vector2(0,size.y-7),"사망 · 배치 불가" if dead else status_text,10,ArenaUI.DANGER if dead else ArenaUI.MUTED,size.x,true)
	for i in range(stars):ArenaIcon.draw(self,Vector2(size.x-11-i*12,33),"star",11,ArenaUI.GOLD)
func _init() -> void:
	# Set variation before text/parenting: six late font overrides reshaped every card.
	clip_text=true;theme=ArenaUI.get_theme();theme_type_variation=&"ArenaCard"
func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	cached_style=ArenaUI.box(Color("1b2338"),Color("36446a"));cached_style.shadow_color=Color(0,0,0,.2);cached_style.shadow_size=0;cached_style.shadow_offset=Vector2(0,3)
	if card_type=="nav":cached_style.set_corner_radius_all(22)
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw);toggled.connect(func(_v):queue_redraw())
func write(at: Vector2,value: String,font_size: int=14,color: Color=Color("eef1fa"),width: float=-1,center: bool=false) -> void:
	draw_string(get_theme_default_font(),at,ArenaUI.plain(value),HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)
func _draw() -> void:
	if cached_style==null:return
	var active: bool=selected or button_pressed
	# Touch screens have no hover, and a tap leaves focus behind; neither may stay lit.
	var hovered: bool=is_hovered() and not ArenaUI.touch_ui();var focused: bool=has_focus() and not ArenaUI.touch_ui()
	var held: bool=ArenaUI.is_held(self)
	if held:draw_set_transform(size*.015,0,Vector2.ONE*.97)
	cached_style.bg_color=Color("51432d") if active else Color("26314e") if hovered and not disabled else Color("171b28") if disabled else ArenaUI.SURFACE
	cached_style.border_color=ArenaUI.GOLD if active or focused else Color("d7bd7a") if hovered else Color("36446a")
	if active or focused:cached_style.border_color=ArenaUI.ACCENT
	if dead or (disabled and card_type not in ["room","nav","promotion_slot"]):cached_style.border_color=ArenaUI.DANGER if active else Color("6e5a7e");cached_style.bg_color=Color("3a2f4f") if active else Color("221e33")
	cached_style.set_border_width_all(2 if active else 1)
	cached_style.border_width_bottom=1
	if card_type=="room" and kind in ["boss","miniboss"]:cached_style.border_color=Color("d4ad6e") if kind=="boss" else Color("a2a275")
	if card_type=="room":
		cached_style.bg_color=Color("51432d") if active else Color("1a2440");cached_style.border_color=ArenaUI.GOLD if active else Color("4b5a86")
		if kind in ["boss","miniboss"]:cached_style.bg_color=Color("453a2b");cached_style.border_color=Color("e0b36b")
		if sold:cached_style.bg_color=Color("1d3a3a");cached_style.border_color=Color("5fb592")
		if spent:cached_style.bg_color=Color("111726");cached_style.border_color=Color("283250")
	var plain: bool=not active and not dead and not disabled
	cached_style.set_corner_radius_all(22 if card_type=="nav" else 7)
	if card_type in UNIT_TYPES:
		cached_style.set_corner_radius_all(10)
		if plain:cached_style.bg_color=Color("26314f") if hovered else Color("1e2846");cached_style.border_color=Color("4a5b90")
	elif card_type in ACTION_TYPES:
		cached_style.set_corner_radius_all(12)
		if plain:cached_style.bg_color=Color("34302b") if hovered else Color("2a2724");cached_style.border_color=Color("7a6a58") if hovered else Color("5b5045")
		elif disabled and not active:cached_style.bg_color=Color("1a1917");cached_style.border_color=Color("34302c")
		if card_type in SHOP_TYPES:
			# Item and recruit cards: cool blue-grey; an unaffordable one fades instead of going dark.
			if plain:cached_style.bg_color=Color("2f3542") if hovered else Color("262b36");cached_style.border_color=Color("6a7790") if hovered else Color("4f5a6e")
			elif disabled and not active:cached_style.bg_color=Color(Color("262b36"),.4 if not sold else .7);cached_style.border_color=Color(Color("4f5a6e"),.4 if not sold else .7)
	elif card_type=="slot":
		cached_style.set_corner_radius_all(9)
		if plain:cached_style.bg_color=Color("1b2440");cached_style.border_color=Color("5a6aa0")
	if held:cached_style.bg_color=cached_style.bg_color.lightened(.12);cached_style.border_color=ArenaUI.ACCENT
	draw_style_box(cached_style,Rect2(Vector2.ONE,size-Vector2.ONE*2))
	if card_type in UNIT_TYPES or card_type in ACTION_TYPES:
		# Thin top sheen lifts the card off the panel.
		var r: float=cached_style.corner_radius_top_left
		draw_line(Vector2(r,2.5),Vector2(size.x-r,2.5),Color(1,1,1,.08),1)
	var muted: Color=Color("9aa5c2");var gold: Color=ArenaUI.GOLD
	if dead or (disabled and card_type not in ["room","nav","promotion_slot"]):muted=ArenaUI.DANGER;gold=ArenaUI.DANGER
	if sold and card_type in SHOP_TYPES:muted=Color("8d8a85");gold=Color("8d8a85")
	if card_type=="party":
		# Source compact party: portrait, purple readiness meter, percentage.
		# HP/energy/equipment remain in tooltip + selected details, not a text stack.
		UnitIcon.draw(self,Rect2(size.x*.5-16,3,32,32),type_id,.28 if dead else 1)
		draw_rect(Rect2(6,34,size.x-12,2),Color("0c1220"));draw_rect(Rect2(6,34,(size.x-12)*clampf(hp/maxf(1,hp_max),0,1),2),ArenaUI.HP)
		for i in range(5):draw_rect(Rect2(7+i*3,30,2,2),ArenaUI.GOLD if i<energy else Color("26304a"))
		for i in range(mini(2,equipment_kinds.size())):ArenaIcon.draw(self,Vector2(size.x-8-i*9,30),equipment_kinds[i],8,Color.WHITE)
		draw_rect(Rect2(5,38,size.x-10,3),Color("0c1220"));draw_rect(Rect2(5,38,(size.x-10)*clampf(gauge/100,0,1),3),Color("b28bdf"))
		write(Vector2(0,51),"사망" if dead else "%d%%"%int(gauge),9,ArenaUI.DANGER if dead else Color("bdcad2"),size.x,true)
		draw_line(Vector2(2,7),Vector2(2,size.y-5),Color("8ebff3"),2,true)
		draw_circle(Vector2(size.x-6,6),2,Color("b9d8f9") if status_text.is_empty() else Color("d7a8ff"))
		return
	if card_type in ["member","deploy_member","mini_member","party"]:
		draw_member_summary(card_type in ["mini_member","party"])
		if card_type=="party":
			write(Vector2(size.x-29,14),"%d%%"%int(gauge),8,ArenaUI.GOLD)
			if not status_text.is_empty():draw_circle(Vector2(size.x-6,23),3,Color("c6b7db"))
		return
	if card_type=="nav":
		var center: Vector2=size*.5
		if kind=="close":
			draw_line(center+Vector2(-6,-6),center+Vector2(6,6),ArenaUI.MUTED,1.5,true);draw_line(center+Vector2(-6,6),center+Vector2(6,-6),ArenaUI.MUTED,1.5,true)
		elif kind=="menu":
			for y in [-6,0,6]:draw_line(center+Vector2(-8,y),center+Vector2(8,y),Color("e5dfc3"),2,true)
		else:ArenaIcon.draw(self,center,"guild",24,Color("9ac8df"))
		return
	if card_type=="prediction_team":
		write(Vector2(15,23),title,15,gold if active else Color("eef1fa"))
		if active:write(Vector2(size.x-76,23),"선택됨",12,gold)
		for i in range(portrait_types.size()):UnitIcon.draw(self,Rect2(14+i*42,33,38,38),portrait_types[i],1)
		var x: float=24+portrait_types.size()*42
		draw_multiline_string(get_theme_default_font(),Vector2(x,49),description,HORIZONTAL_ALIGNMENT_LEFT,maxf(40,size.x-x-12),12,3,muted)
		return
	if card_type=="stake":
		ArenaIcon.draw(self,Vector2(18,size.y*.5),"gold",18,Color.WHITE)
		write(Vector2(30,size.y*.5+5),title,13,gold if active else Color("eef1fa"),size.x-35,true)
		if active:draw_line(Vector2(10,size.y-5),Vector2(size.x-10,size.y-5),gold,2)
		return
	if card_type=="event_option":
		draw_badge(Vector2(size.x*.5,29),23,gold)
		ArenaIcon.draw(self,Vector2(size.x*.5,29),kind,28,Color.WHITE if not disabled else Color(1,1,1,.4))
		draw_string(ArenaUI.heading_font(),Vector2(5,62),ArenaUI.plain(title),HORIZONTAL_ALIGNMENT_CENTER,size.x-10,15,muted if disabled else Color("fff3dc"))
		draw_multiline_string(get_theme_default_font(),Vector2(8,84),description,HORIZONTAL_ALIGNMENT_CENTER,size.x-16,12,3,muted)
		if not price.is_empty():draw_price_chip(Rect2(size.x*.5-46,size.y-36,92,28),"완료")
		return
	if card_type=="revival_member":
		UnitIcon.draw(self,Rect2(size.x*.5-20,12,40,40),type_id,1)
		write(Vector2(0,67),title,12,Color("eef1fa"),size.x,true)
		write(Vector2(0,82),stats_summary+" · 사망",10,ArenaUI.DANGER,size.x,true)
		write(Vector2(0,97),"HP 0 / %d"%ceili(hp_max),10,ArenaUI.DANGER,size.x,true)
		draw_energy(105,size.x-20)
		draw_equipment(116,12)
		write(Vector2(0,145),"부활 "+description,9,ArenaUI.HP,size.x,true)
		return
	if card_type=="promotion_member":
		UnitIcon.draw(self,Rect2(size.x*.5-18,9,36,36),type_id,.4 if dead else 1)
		write(Vector2(0,64),title,12,Color("eef1fa"),size.x,true)
		write(Vector2(0,81),subtitle,10,muted,size.x,true)
		draw_rect(Rect2(10,88,size.x-20,3),Color("0e1424"));draw_rect(Rect2(10,88,(size.x-20)*clampf(hp/maxf(1,hp_max),0,1),3),ArenaUI.HP)
		write(Vector2(0,107),"HP %d/%d"%[ceili(hp),ceili(hp_max)],9,ArenaUI.DANGER if dead else ArenaUI.HP,size.x,true)
		draw_energy(113,size.x-20)
		draw_equipment(125,12)
		write(Vector2(0,153),status_text,9,gold if active else muted,size.x,true)
		return
	if card_type=="promotion_slot":
		if type_id>=0:UnitIcon.draw(self,Rect2(size.x*.5-16,5,32,32),type_id,1)
		else:write(Vector2(0,35),"+",26,muted,size.x,true)
		write(Vector2(0,size.y-6),subtitle,9,muted,size.x,true)
		return
	if card_type=="party":
		UnitIcon.draw(self,Rect2(size.x*.5-18,5,36,36),type_id,.35 if dead else 1)
		write(Vector2(0,46),"사망" if dead else "%d%%"%int(gauge),12,muted if dead else gold,size.x,true)
		draw_rect(Rect2(6,50,size.x-12,3),Color("0e1424"));draw_rect(Rect2(6,50,(size.x-12)*clampf(gauge/100,0,1),3),gold)
		if not status_text.is_empty():draw_circle(Vector2(size.x-8,9),4,Color("d7a8ff"))
		return
	if card_type=="room":
		var compact_room: bool=size.y<110
		write(Vector2(0,17 if compact_room else 22),subtitle,10 if compact_room else 12,muted,size.x,true)
		ArenaIcon.draw(self,Vector2(size.x*.5,41 if compact_room else 55),kind,22 if compact_room else 30,gold if not disabled else Color("4a5578"))
		write(Vector2(0,70 if compact_room else 92),title,11 if compact_room else 14,Color("eef1fa") if not disabled else muted,size.x,true)
		write(Vector2(0,89 if compact_room else 114),status_text,10 if compact_room else 11,muted,size.x,true)
		return
	if card_type=="product":
		draw_badge(Vector2(size.x*.5,28),22,gold)
		ArenaIcon.draw(self,Vector2(size.x*.5,28),kind,27,gold)
		draw_multiline_string(get_theme_default_font(),Vector2(4,59),title,HORIZONTAL_ALIGNMENT_CENTER,size.x-8,12,2,Color("eef1fa"))
		draw_multiline_string(get_theme_default_font(),Vector2(6,91),description,HORIZONTAL_ALIGNMENT_CENTER,size.x-12,11,3,muted)
		draw_price_chip(Rect2(6,size.y-37,size.x-12,30),"구매 완료")
		return
	if card_type=="slot":
		ArenaIcon.draw(self,Vector2(size.x*.5,21),kind,23,gold)
		write(Vector2(0,45),title,10,gold,size.x,true)
		write(Vector2(0,size.y-5),price if not price.is_empty() else "설명",9,muted,size.x,true)
		if not status_text.is_empty():write(Vector2(size.x-26,11),status_text,8,muted)
		return
	if card_type=="mini_member":
		UnitIcon.draw(self,Rect2(size.x*.5-16,4,32,32),type_id,.4 if dead else 1)
		write(Vector2(0,49),subtitle,10,muted,size.x,true)
		draw_rect(Rect2(6,56,size.x-12,3),Color("0e1424"));draw_rect(Rect2(6,56,(size.x-12)*clampf(hp/maxf(1,hp_max),0,1),3),Color("86e3a4"))
		draw_rect(Rect2(6,62,size.x-12,3),Color("0e1424"));draw_rect(Rect2(6,62,(size.x-12)*clampf(energy/5.0,0,1),3),gold)
		return
	if card_type=="recruit":
		write(Vector2(0,23),title,13,Color("eef1fa"),size.x,true)
		UnitIcon.draw(self,Rect2(size.x*.5-29,33,58,58),type_id,.4 if sold else 1)
		write(Vector2(0,114),stats_summary,10,muted,size.x,true)
		draw_multiline_string(get_theme_default_font(),Vector2(7,138),description,HORIZONTAL_ALIGNMENT_CENTER,size.x-14,10,2,muted)
		draw_price_chip(Rect2(7,size.y-42,size.x-14,32),"영입 완료")
		return
	if card_type=="strategy" and size.y<=64:
		ArenaIcon.draw(self,Vector2(17,size.y*.5),kind,22,gold)
		write(Vector2(34,23),title,11,gold,size.x-37)
		write(Vector2(34,40),description,9,muted,size.x-37)
		return
	if card_type=="ally":
		UnitIcon.draw(self,Rect2(6,8,40,40),type_id,.4 if dead else 1)
		write(Vector2(52,23),title,13,ArenaUI.GOLD if active else Color("eef1fa"))
		write(Vector2(52,43),description,11,muted)
		return
	if card_type in ["item","strategy","choice"]:
		var icon_size: float=34 if card_type!="strategy" else 27
		ArenaIcon.draw(self,Vector2(32,size.y*.5),kind,icon_size,gold)
		write(Vector2(62,27),title,15,gold if active else Color("eef1fa"))
		var width: float=maxf(20,size.x-76)
		draw_multiline_string(get_theme_default_font(),Vector2(62,49),description,HORIZONTAL_ALIGNMENT_LEFT,width,12,2,muted)
		if not price.is_empty():write(Vector2(62,size.y-13),price,14,gold)
		if sold:write(Vector2(size.x-72,25),"완료",12,muted)
		return
	var compact: bool=size.y<170 and card_type=="member"
	write(Vector2(0,20 if compact else 24),title,14 if compact else 15,Color("eef1fa"),size.x,true)
	var portrait_size: float=50 if compact else 68
	UnitIcon.draw(self,Rect2(Vector2(size.x*.5-portrait_size*.5,23 if compact else 29),Vector2.ONE*portrait_size),type_id,.4 if dead else 1)
	write(Vector2(0,86 if compact else 111),subtitle,10 if compact else 11,muted,size.x,true)
	if card_type=="recruit":
		draw_multiline_string(get_theme_default_font(),Vector2(12,133),description,HORIZONTAL_ALIGNMENT_CENTER,size.x-24,12,2,muted)
		write(Vector2(0,size.y-17),"영입 완료" if sold else price,16,gold,size.x,true)
		return
	write(Vector2(0,104 if compact else 131),"HP "+ArenaUI.hp(hp,hp_max),10 if compact else 11,muted,size.x,true)
	var bar_y: float=109 if compact else 137
	draw_rect(Rect2(12,bar_y,size.x-24,4),Color("0e1424"));draw_rect(Rect2(12,bar_y,(size.x-24)*clampf(hp/maxf(1,hp_max),0,1),4),Color("86e3a4"))
	var start: float=(size.x-66)*.5
	for i in range(5):draw_style_box(ArenaUI.pip_style(i<energy),Rect2(start+i*14,120 if compact else 148,12,5))
	write(Vector2(0,138 if compact else 174),"사망 · 배치 불가" if dead else status_text,10 if compact else 11,Color("e3a0a5") if dead else gold,size.x,true)
	if stars>0:
		for i in range(stars):
			var points:=PackedVector2Array();var at:=Vector2(size.x-15-i*13,38)
			for j in range(10):points.append(at+Vector2.from_angle(-PI/2+j*PI/5)*(6 if j%2==0 else 2.5))
			draw_colored_polygon(points,gold)
