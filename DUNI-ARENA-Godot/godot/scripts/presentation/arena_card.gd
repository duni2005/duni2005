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
## Deploy roster: already placed on the board.
var deployed: bool=false
## Inventory slot kind: "equipment", "consumable", "equipped", "strategy" or "cooldown".
var slot_kind: String=""
## Owner unit type for an equipped item (-1 when none).
var owner_type: int=-1
## Item grade colour (ItemCatalog.GRADE_COLORS); transparent for non-items.
var rarity: Color=Color(0,0,0,0)
const SLOT_COLORS={"equipment":["1b2440","5a7ad0","장비"],"consumable":["1a2e2a","5fb592","소모품"],"equipped":["1c3438","4fc6c0","장착"],"strategy":["2a2142","a07ad8","전략"],"cooldown":["1a1826","5a4f72","대기"]}
var cached_style: StyleBoxFlat
## Entrance (UiMotion.enter): seconds since the card's mask started opening (negative while it
## waits its turn). The mask opens bottom to top as the content rises into place, then a light
## streak crosses the face once.
var reveal_age: float=99
# Visual tiers: units read as information, choices as warm actions, inventory as slots.
const UNIT_TYPES: Array=["member","deploy_member","mini_member","party","revival_member","promotion_member","ally","library"]
const ACTION_TYPES: Array=["event_option","product","choice","recruit","stake","prediction_team","item"]
const SHOP_TYPES: Array=["product","recruit"]
## Cards that show one unit carry its rarity (UnitRarity): coloured band and border, ◆ per token.
const RARITY_TYPES: Array=["member","deploy_member","mini_member","revival_member","promotion_member","library","recruit"]
func show_member(guild: GuildManager,member: GuildMemberState) -> void:
	# Copy presentation values. Inventory ownership remains run data.
	source_id=member.member_id;type_id=member.unit_type_id;title=guild.definition(type_id).display_name
	hp=member.current_hp;hp_max=guild.member_max_hp(member);level=member.level;stars=member.stars;dead=not member.is_alive()
	equipment_slots=GuildMemberCombatStats.equipment_limit(member);equipment_kinds.clear()
	for item in guild.state.inventory:
		if not item.consumed and item.equipped_to_member_id==member.member_id:equipment_kinds.append(String(item.kind))
	tooltip_text="%s · %s\nHP %s\n장비: %s"%[title,ArenaUI.member_label(member.member_id),ArenaUI.hp(hp,hp_max),"없음" if equipment_kinds.is_empty() else " / ".join(equipment_kinds.map(func(k):return ItemCatalog.get_item(k).display_name))]
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
		return
	if compact:
		var tiny: bool=size.y<84;var p: float=24 if tiny else 28
		UnitIcon.draw(self,Rect2(size.x*.5-p*.5,4,p,p),type_id,.4 if dead else 1)
		if not tiny:write(Vector2(0,42),subtitle if not subtitle.is_empty() else title,9,ArenaUI.MUTED,size.x,true)
		var hp_y: float=37 if tiny else 54
		write(Vector2(0,hp_y),"사망" if dead else "HP %d/%d"%[ceili(hp),ceili(hp_max)],9,tint,size.x,true)
		draw_rect(Rect2(6,hp_y+3,size.x-12,2),Color("0e1424"));draw_rect(Rect2(6,hp_y+3,(size.x-12)*clampf(hp/maxf(1,hp_max),0,1),2),tint)
		draw_equipment(hp_y+12,12)
		return
	var small: bool=card_type=="deploy_member"
	write(Vector2(0,17),title,12 if small else 13,Color("eef1fa"),size.x,true)
	var portrait: float=32 if small else 42
	UnitIcon.draw(self,Rect2(size.x*.5-portrait*.5,21,portrait,portrait),type_id,.4 if dead else 1)
	write(Vector2(0,65 if small else 76),subtitle,9 if small else 10,ArenaUI.MUTED,size.x,true)
	var hp_y: float=80 if small else 91
	write(Vector2(0,hp_y),"사망" if dead else "HP "+ArenaUI.hp(hp,hp_max),10,tint,size.x,true)
	draw_rect(Rect2(10,hp_y+4,size.x-20,3),Color("0e1424"));draw_rect(Rect2(10,hp_y+4,(size.x-20)*clampf(hp/maxf(1,hp_max),0,1),3),tint)
	draw_equipment(hp_y+16,13 if small else 15)
	if not small:write(Vector2(0,size.y-7),"사망 · 배치 불가" if dead else status_text,10,ArenaUI.DANGER if dead else ArenaUI.MUTED,size.x,true)
	for i in range(stars):ArenaIcon.draw(self,Vector2(size.x-11-i*12,33),"star",11,ArenaUI.GOLD)
	# Deploy cards are narrow: the diamonds run down the left edge under the state chip.
	if small:UnitRarity.draw_pips(self,Vector2(9,42),type_id,2.6,dead,Vector2.DOWN)
	else:UnitRarity.draw_pips(self,Vector2(9,33),type_id,3,dead)
	if small and not dead:
		# Deploy state chip in the corner: green "배치" once placed, muted "대기" otherwise.
		var label: String="배치" if deployed else "대기";var c: Color=Color("5fc9a0") if deployed else Color("6d7aa0")
		var w: float=get_theme_default_font().get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x+8
		draw_style_box(ArenaUI.box(Color(c,.3),Color(c,.85)),Rect2(4,22,w,13));write(Vector2(8,32),label,8,c.lightened(.35))
func _init() -> void:
	# Set variation before text/parenting: six late font overrides reshaped every card.
	clip_text=true;theme=ArenaUI.get_theme();theme_type_variation=&"ArenaCard"
func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	cached_style=ArenaUI.box(Color("1b2338"),Color("36446a"));cached_style.shadow_size=1
	if card_type=="nav":cached_style.set_corner_radius_all(22)
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw);toggled.connect(func(_v):queue_redraw())
func reveal(delay: float=0) -> void:
	if not UiMotion.enabled:return
	reveal_age=-delay;set_process(true);queue_redraw()
func _revealing() -> bool:return reveal_age<Motion.ENTER+.45
func _process(dt: float) -> void:
	reveal_age+=dt;queue_redraw()
	# Keep running only for the entrance and for the selected card's or a 전설 unit's travelling light.
	if not _revealing() and not ((selected or button_pressed) and UiMotion.enabled) and not _shimmers():set_process(false)
## 전설 units keep a light running round the border.
func _shimmers() -> bool:return UiMotion.enabled and card_type in RARITY_TYPES and UnitRarity.tier(type_id)==5 and not (dead or sold or disabled or selected or button_pressed)
func write(at: Vector2,value: String,font_size: int=14,color: Color=Color("eef1fa"),width: float=-1,center: bool=false) -> void:
	draw_string(get_theme_default_font(),at,ArenaUI.plain(value),HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)
func _draw() -> void:
	if cached_style==null:return
	var opened: float=Motion.out_expo(Motion.phase(reveal_age,0,Motion.ENTER))
	if opened<1:
		# Mask: only the opened part (growing from the bottom edge, lip included) is drawn.
		RenderingServer.canvas_item_set_custom_rect(get_canvas_item(),true,Rect2(-4,size.y*(1-opened),size.x+8,size.y*opened+ArenaUI.LIP+4))
		RenderingServer.canvas_item_set_clip(get_canvas_item(),true)
		draw_set_transform(Vector2(0,(1-opened)*12))
	if card_type=="hand_card":
		# Strategy card in the turning-point hand: drawn as a real card.
		var state: String="selected" if button_pressed else ("waiting" if status_text!="사용함" else "used") if disabled else "ready"
		StrategyCardArt.draw(self,Rect2(Vector2(3,3),size-Vector2(6,8)),kind,title,description,"",state,status_text)
		return
	if card_type=="tp_member":
		_draw_tp_member();return
	if card_type=="dungeon_room":
		_draw_dungeon_room();return
	if card_type=="stairs":
		_draw_stairs();return
	var active: bool=selected or button_pressed
	# Touch screens have no hover, and a tap leaves focus behind; neither may stay lit.
	var hovered: bool=is_hovered() and not ArenaUI.touch_ui();var focused: bool=has_focus() and not ArenaUI.touch_ui()
	var held: bool=ArenaUI.is_held(self)
	if held:draw_set_transform(size*.015+Vector2(0,(1-opened)*12),0,Vector2.ONE*.97)
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
	cached_style.set_corner_radius_all(int(minf(size.x,size.y)*.5) if card_type=="nav" else ArenaUI.RADIUS_CARD)
	if card_type in UNIT_TYPES:
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
		cached_style.set_corner_radius_all(10)
		if plain:cached_style.bg_color=Color("1b2440");cached_style.border_color=Color("5a6aa0")
		if plain and SLOT_COLORS.has(slot_kind):cached_style.bg_color=Color(SLOT_COLORS[slot_kind][0]);cached_style.border_color=Color(SLOT_COLORS[slot_kind][1])
	if card_type=="deploy_member" and plain:
		# Placed members read teal with a green rim; the rest stay dark and quiet.
		cached_style.bg_color=Color("1c3a3a") if deployed else Color("161d30");cached_style.border_color=Color("5fc9a0") if deployed else Color("37425f")
		if deployed:cached_style.set_border_width_all(2)
	if held:cached_style.bg_color=cached_style.bg_color.lightened(.12);cached_style.border_color=ArenaUI.ACCENT
	# Every card is a button: a darker lip underneath that it sinks onto when held; disabled ones lie flat.
	var lip: float=0 if disabled and not active else 1 if held else 3
	cached_style.shadow_offset=Vector2(0,lip);cached_style.shadow_color=Color(cached_style.bg_color.darkened(.6),cached_style.bg_color.a if lip>0 else 0)
	draw_style_box(cached_style,Rect2(Vector2.ONE,size-Vector2.ONE*2))
	if card_type!="nav" and lip>0:
		# Thin top sheen catches the light on the raised face.
		var r: float=cached_style.corner_radius_top_left
		draw_line(Vector2(r,2.5),Vector2(size.x-r,2.5),Color(1,1,1,.1),1)
	# The selected card keeps its own gold rim, deploy cards their placed/waiting border.
	if card_type in RARITY_TYPES and not active:
		UnitRarity.draw_frame(self,Rect2(Vector2.ONE,size-Vector2.ONE*2),type_id,cached_style.corner_radius_top_left,dead or sold or disabled,card_type!="deploy_member")
		if _shimmers() and not is_processing():set_process(true)
	if UiMotion.enabled:
		TypeArt.sweep(self,Rect2(Vector2(3,3),size-Vector2(6,6)),Motion.phase(reveal_age,Motion.ENTER*.5,.4),.2,minf(30,size.x*.25))
		if active and card_type!="nav":_rim_light(cached_style.corner_radius_top_left)
		if (active or _revealing()) and not is_processing():set_process(true)
	var muted: Color=Color("9aa5c2");var gold: Color=ArenaUI.GOLD
	if dead or (disabled and card_type not in ["room","nav","promotion_slot"]):muted=ArenaUI.DANGER;gold=ArenaUI.DANGER
	if sold and card_type in SHOP_TYPES:muted=Color("8d8a85");gold=Color("8d8a85")
	if card_type=="party":
		# Source compact party: portrait, purple readiness meter, percentage.
		# HP/equipment remain in tooltip + selected details, not a text stack.
		UnitIcon.draw(self,Rect2(size.x*.5-16,3,32,32),type_id,.28 if dead else 1)
		draw_rect(Rect2(6,34,size.x-12,2),Color("0c1220"));draw_rect(Rect2(6,34,(size.x-12)*clampf(hp/maxf(1,hp_max),0,1),2),ArenaUI.HP)
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
		elif kind=="guild":ArenaIcon.draw(self,center,"guild",24,Color("9ac8df"))
		else:ArenaIcon.draw(self,center,kind,minf(size.x,size.y)*.46,Color(1,1,1,.35 if disabled else 1))
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
		# Badge, title and description each keep their own band so nothing overlaps.
		draw_badge(Vector2(size.x*.5,31),21,gold)
		ArenaIcon.draw(self,Vector2(size.x*.5,31),kind,26,Color.WHITE if not disabled else Color(1,1,1,.4))
		# Long titles shrink to fit a narrow card instead of being cut off.
		var heading: String=ArenaUI.plain(title);var fs: int=15
		while fs>11 and ArenaUI.heading_font().get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>size.x-10:fs-=1
		draw_string(ArenaUI.heading_font(),Vector2(5,73),heading,HORIZONTAL_ALIGNMENT_CENTER,size.x-10,fs,muted if disabled else Color("fff3dc"))
		draw_multiline_string(get_theme_default_font(),Vector2(8,93),description,HORIZONTAL_ALIGNMENT_CENTER,size.x-16,12,2,muted)
		if not price.is_empty():draw_price_chip(Rect2(size.x*.5-46,size.y-36,92,28),"완료")
		return
	if card_type=="revival_member":
		UnitIcon.draw(self,Rect2(size.x*.5-20,12,40,40),type_id,1)
		write(Vector2(0,67),title,12,Color("eef1fa"),size.x,true)
		write(Vector2(0,82),stats_summary+" · 사망",10,ArenaUI.DANGER,size.x,true)
		write(Vector2(0,97),"HP 0 / %d"%ceili(hp_max),10,ArenaUI.DANGER,size.x,true)
		draw_equipment(108,12)
		write(Vector2(0,145),"부활 "+description,9,ArenaUI.HP,size.x,true)
		return
	if card_type=="promotion_member":
		UnitIcon.draw(self,Rect2(size.x*.5-18,9,36,36),type_id,.4 if dead else 1)
		write(Vector2(0,64),title,12,Color("eef1fa"),size.x,true)
		write(Vector2(0,81),subtitle,10,muted,size.x,true)
		draw_rect(Rect2(10,88,size.x-20,3),Color("0e1424"));draw_rect(Rect2(10,88,(size.x-20)*clampf(hp/maxf(1,hp_max),0,1),3),ArenaUI.HP)
		write(Vector2(0,107),"HP %d/%d"%[ceili(hp),ceili(hp_max)],9,ArenaUI.DANGER if dead else ArenaUI.HP,size.x,true)
		draw_equipment(116,12)
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
	if card_type=="product" and slot_kind=="card":
		# Strategy cards on the shop shelf look like the cards in hand, with the price below.
		StrategyCardArt.draw(self,Rect2(Vector2(4,4),size-Vector2(8,48)),kind,title,description,"","used" if sold else "ready","")
		_shelf_tag("전략카드",Color("a07ad8"))
		draw_price_chip(Rect2(6,size.y-37,size.x-12,30),"구매 완료")
		return
	if card_type=="product":
		if slot_kind=="item":_shelf_tag("아이템",rarity if rarity.a>0 else Color("7f8aa6"))
		if rarity.a>0:VfxArt.glow(self,Vector2(size.x*.5,28),30,rarity,.25)
		draw_badge(Vector2(size.x*.5,28),20,gold)
		ArenaIcon.draw(self,Vector2(size.x*.5,28),kind,25,gold)
		write(Vector2(4,66),title,12,rarity.lightened(.3) if rarity.a>0 else Color("eef1fa"),size.x-8,true)
		draw_multiline_string(get_theme_default_font(),Vector2(6,86),description,HORIZONTAL_ALIGNMENT_CENTER,size.x-12,11,3,muted)
		draw_price_chip(Rect2(6,size.y-37,size.x-12,30),"구매 완료")
		return
	if card_type=="library":
		# Custom battle character card: name, portrait, temporary cost.
		write(Vector2(0,17),title,11,Color("eef1fa"),size.x,true)
		UnitIcon.draw(self,Rect2(size.x*.5-20,22,40,40),type_id)
		UnitRarity.draw_pips(self,Vector2((size.x-UnitRarity.pips_width(type_id,2.6))*.5+2.1,69),type_id,2.6)
		ArenaIcon.draw(self,Vector2(size.x*.5-16,size.y-12),"gold",11,Color.WHITE)
		draw_string(ArenaUI.numbers_font(),Vector2(size.x*.5-8,size.y-6),price,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ArenaUI.GOLD)
		return
	if card_type=="slot":
		var waiting: bool=slot_kind=="cooldown";var rim: Color=Color(SLOT_COLORS[slot_kind][1]) if SLOT_COLORS.has(slot_kind) else muted
		if rarity.a>0:
			# Grade: soft glow behind the icon and a coloured base line.
			VfxArt.glow(self,Vector2(size.x*.5,24),22,rarity,.22);draw_rect(Rect2(6,size.y-2,size.x-12,2),Color(rarity,.85))
		ArenaIcon.draw(self,Vector2(size.x*.5,24),kind,22,Color(gold,.45) if waiting else gold)
		write(Vector2(0,47),title,10,Color(muted,.8) if waiting else rarity.lightened(.25) if rarity.a>0 else gold,size.x,true)
		write(Vector2(0,size.y-5),price if not price.is_empty() else "설명",9,Color(rim.lightened(.3),.9) if waiting else muted,size.x,true)
		var tag: String=SLOT_COLORS[slot_kind][2] if SLOT_COLORS.has(slot_kind) else status_text
		if not tag.is_empty():
			# Kind tag: a small coloured chip in the top-left corner, clear of the centred icon.
			var tag_w: float=get_theme_default_font().get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x+8
			draw_style_box(ArenaUI.box(Color(rim,.28),Color(rim,.8)),Rect2(4,4,tag_w,13))
			write(Vector2(8,14),tag,8,rim.lightened(.45))
		if waiting:
			var clock:=Vector2(size.x-12,12);draw_arc(clock,6,0,TAU,20,rim.lightened(.3),1.5,true);draw_line(clock,clock+Vector2(0,-4),rim.lightened(.3),1.5);draw_line(clock,clock+Vector2(3,0),rim.lightened(.3),1.5)
		if owner_type>=0:UnitIcon.draw(self,Rect2(size.x-21,3,18,18),owner_type)
		return
	if card_type=="mini_member":
		UnitIcon.draw(self,Rect2(size.x*.5-16,4,32,32),type_id,.4 if dead else 1)
		write(Vector2(0,49),subtitle,10,muted,size.x,true)
		draw_rect(Rect2(6,56,size.x-12,3),Color("0e1424"));draw_rect(Rect2(6,56,(size.x-12)*clampf(hp/maxf(1,hp_max),0,1),3),Color("86e3a4"))
		return
	if card_type=="recruit":
		# Tapping shows the unit's info (the 영입 button sits under the card). Narrow cards (four in a
		# phone row) stack the rarity and stats instead of using the pill and one stat line.
		var narrow: bool=size.x<120
		write(Vector2(2,20),title,11 if narrow else 13,Color("eef1fa"),size.x-4,true)
		var icon: float=clampf(minf(size.x-14,size.y-(104 if narrow else 96)),30,64);var mid: Vector2=Vector2(size.x*.5,27+icon*.5)
		if UnitRarity.tier(type_id)>=4 and not sold:VfxArt.glow(self,mid,icon*.7,UnitRarity.color(type_id),.22)
		UnitIcon.draw(self,Rect2(mid-Vector2.ONE*icon*.5,Vector2.ONE*icon),type_id,.4 if sold else 1)
		var col: Color=Color(UnitRarity.color(type_id).lightened(.25),.5 if sold else 1.0)
		if narrow:
			UnitRarity.draw_pips(self,Vector2((size.x-UnitRarity.pips_width(type_id,2.8))*.5+2.24,38+icon),type_id,2.8,sold)
			write(Vector2(0,55+icon),UnitRarity.label(type_id),10,col,size.x,true)
			var lines: PackedStringArray=stats_summary.split(" · ")
			for i in range(lines.size()):write(Vector2(0,72+icon+i*13),lines[i],9,muted,size.x,true)
		else:
			_rarity_line(38+icon,sold)
			write(Vector2(0,62+icon),stats_summary,10,muted,size.x,true)
			draw_string(get_theme_default_font(),Vector2(6,77+icon),description,HORIZONTAL_ALIGNMENT_CENTER,size.x-12,10,muted)
		var info:=Vector2(size.x-10,10);draw_arc(info,5.5,0,TAU,20,Color(muted,.8),1.2,true);write(info+Vector2(-1.5,3.5),"i",9,Color(muted,.9))
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
	write(Vector2(0,138 if compact else 174),"사망 · 배치 불가" if dead else status_text,10 if compact else 11,Color("e3a0a5") if dead else gold,size.x,true)
	if stars>0:
		for i in range(stars):
			var points:=PackedVector2Array();var at:=Vector2(size.x-15-i*13,38)
			for j in range(10):points.append(at+Vector2.from_angle(-PI/2+j*PI/5)*(6 if j%2==0 else 2.5))
			draw_colored_polygon(points,gold)

## Shop shelf tag in the top-left corner: 아이템 or 전략카드.
func _shelf_tag(label: String,col: Color) -> void:
	var w: float=get_theme_default_font().get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,8).x+8
	draw_style_box(ArenaUI.box(Color(col,.3),Color(col,.85)),Rect2(5,5,w,13));write(Vector2(9,15),label,8,col.lightened(.45))
## "◆◆◆ 희귀" pill centred on `y`.
func _rarity_line(y: float,dim: bool) -> void:
	var label: String=UnitRarity.label(type_id);var font: Font=get_theme_default_font();var col: Color=UnitRarity.color(type_id)
	var pips: float=UnitRarity.pips_width(type_id,3.4);var w: float=pips+5+font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	var x: float=(size.x-w)*.5;var a: float=.5 if dim else 1.0
	draw_style_box(ArenaUI.box(Color(col,.14*a),Color(col,.55*a)),Rect2(x-7,y-8,w+14,16))
	UnitRarity.draw_pips(self,Vector2(x+2.7,y),type_id,3.4,dim)
	write(Vector2(x+pips+5,y+4),label,11,Color(col.lightened(.25),a))
## A short bright segment of light running around the selected card's border.
func _rim_light(radius: float) -> void:
	var rect:=Rect2(Vector2.ONE,size-Vector2.ONE*2);var head: float=Time.get_ticks_msec()/1000.0*.42
	var points:=PackedVector2Array();var colors:=PackedColorArray()
	for i in range(13):
		var k: float=i/12.0
		points.append(Motion.perimeter_point(rect,radius,head-.16*(1-k)));colors.append(Color(1,.95,.78,k*k*.95))
	draw_polyline_colors(points,colors,2.5,true)
## Turning-point ally chip: unit icon in a ring (gold and glowing when selected), HP bar, stance.
func _draw_tp_member() -> void:
	# Compact chip: icon ring, HP bar, and a small stance badge on the ring.
	var on: bool=button_pressed;var c:=Vector2(size.x*.5,22)
	if on:VfxArt.glow(self,c,30,ArenaUI.GOLD,.35)
	draw_circle(c,19,Color("0c1220"))
	UnitIcon.draw(self,Rect2(c-Vector2(17,17),Vector2(34,34)),type_id)
	draw_arc(c,19,0,TAU,40,ArenaUI.GOLD if on else Color("4a5680"),2.5 if on else 1.2,true)
	var w: float=size.x-12
	draw_rect(Rect2(6,46,w,4),Color("0e1424"));draw_rect(Rect2(6,46,w*clampf(hp/maxf(1,hp_max),0,1),4),ArenaUI.HP)
	var badge:=c+Vector2(14,12)
	draw_circle(badge,7,Color("10182b"));draw_arc(badge,7,0,TAU,20,ArenaUI.GOLD if on else Color("5a6890"),1,true)
	ArenaIcon.draw(self,badge,kind,9,ArenaUI.GOLD if on else Color("c9d0e6"))
## Floor colour of each room kind on the tower map.
const ROOM_COLORS={"battle":"d9634f","miniboss":"ee9a3a","boss":"e8443c","recruit":"9f7ae6","shop":"4f9be0","blacksmith":"e3803f","rest":"4fb87a","hidden":"55607e"}
## A room on the tower map, seen from above like the tower itself: a round stone dais with a
## crenellated rim around a floor in the room's colour, its icon, a number on the rim and a
## name ribbon across the bottom. Unexplored rooms are misty; boss rooms are larger with a
## spiked rim; cleared rooms get a check.
func _draw_dungeon_room() -> void:
	var active: bool=button_pressed or ArenaUI.is_held(self);var hidden: bool=kind=="hidden";var boss: bool=kind in ["boss","miniboss"]
	var base: Color=Color(ROOM_COLORS.get(kind,"3fb3ad"))
	if spent:base=base.lerp(Color("6b7280"),.6)
	var at:=Vector2(size.x*.5,size.y*.46);var r: float=minf(size.x,size.y*.92)*.46
	var ring: Color=ArenaUI.GOLD if active else TowerArt.STONE_LIT if not boss else base.lightened(.25)
	_dais(at,r,base,ring,boss,active)
	if hidden:
		for i in range(3):VfxArt.glow(self,at+Vector2.from_angle(i*2.1+Time.get_ticks_msec()*.0004)*r*.25,r*.55,Color("c9d6f0"),.18)
		write(at+Vector2(-r,r*.22),"?",int(r*.62),Color(1,1,1,.85),r*2,true)
	else:ArenaIcon.draw(self,at+Vector2(0,-r*.06),kind,r*.78,Color(1,1,1,.5 if spent else 1))
	# Number on the rim, upper left.
	var badge: Vector2=at+Vector2.from_angle(PI*1.25)*r*.86
	draw_circle(badge,8.5,Color("1d2333"));draw_arc(badge,8.5,0,TAU,20,ring,1.5,true);write(badge+Vector2(-9,3.5),subtitle,10,Color.WHITE,18,true)
	_ribbon(Vector2(at.x,at.y+r*.86),title,base,spent)
	if sold:
		var stamp: Vector2=at+Vector2.from_angle(-PI*.25)*r*.86;draw_circle(stamp,9,Color("12301f"));draw_arc(stamp,9,0,TAU,20,ArenaUI.HP,2,true)
		draw_polyline(PackedVector2Array([stamp+Vector2(-4.5,0),stamp+Vector2(-1,3.5),stamp+Vector2(5,-4)]),ArenaUI.HP,2.2,true)
## Round stone dais: shadow, crenellated rim (spiked for boss rooms), a floor that is lighter in
## the middle, and a gold halo when selected.
func _dais(at: Vector2,r: float,floor: Color,ring: Color,boss: bool,active: bool) -> void:
	draw_circle(at+Vector2(2,4),r*1.02,Color(0,.08,0,.28))
	if active:VfxArt.glow(self,at,r*1.6,ArenaUI.GOLD,.35)
	elif boss:VfxArt.glow(self,at,r*1.5,floor,.3)
	if boss:
		for i in range(12):
			var d: Vector2=Vector2.from_angle(i*TAU/12)
			draw_colored_polygon(PackedVector2Array([at+d.rotated(-.13)*r*.92,at+d*r*1.16,at+d.rotated(.13)*r*.92]),ring.darkened(.15))
	draw_circle(at,r,ring.darkened(.35));draw_circle(at,r*.94,ring)
	var merlons: int=12 if r<40 else 16
	for i in range(merlons):
		var a: float=i*TAU/merlons;draw_arc(at,r*.88,a,a+TAU/merlons*.5,4,ring.lightened(.25),r*.1,false)
	draw_circle(at,r*.76,ring.darkened(.45))
	draw_circle(at,r*.72,floor.darkened(.15));draw_circle(at+Vector2(-r*.06,-r*.08),r*.56,floor);VfxArt.glow(self,at+Vector2(-r*.15,-r*.2),r*.5,Color.WHITE,.12)
	if active:draw_arc(at,r*1.04,0,TAU,40,ArenaUI.GOLD,2.5,true)
## Name ribbon across the bottom of a dais.
func _ribbon(center: Vector2,text: String,color: Color,dim: bool) -> void:
	var font_size: int=10 if size.x<80 else 11
	var w: float=minf(size.x-2,get_theme_default_font().get_string_size(ArenaUI.plain(text),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+16)
	var plate:=Rect2(Vector2(center.x-w*.5,center.y-8),Vector2(w,16))
	var style: StyleBoxFlat=ArenaUI.box(Color("1d2333",.94),Color(color.lightened(.3),.9));style.set_corner_radius_all(8);style.set_border_width_all(1);draw_style_box(style,plate)
	write(Vector2(plate.position.x,plate.end.y-4),text,font_size,ArenaUI.MUTED if dim else Color.WHITE,plate.size.x,true)
## The stairway to the next floor: a gold dais with a spiral stair winding down into light.
func _draw_stairs() -> void:
	var pulse: float=.5+.5*sin(Time.get_ticks_msec()*.004);var at:=Vector2(size.x*.5,size.y*.46);var r: float=minf(size.x,size.y*.92)*.46
	VfxArt.glow(self,at,r*1.7,Color("ffd27a"),.25+.2*pulse)
	_dais(at,r,Color("3a3550"),Color("e3c27a"),false,false)
	# Spiral steps: wedges turning inwards, brighter towards the lit centre.
	for i in range(10):
		var a0: float=i*TAU/10+Time.get_ticks_msec()*.0003;var k: float=i/10.0
		var outer: float=r*(.68-k*.3);var inner: float=outer-r*.14
		var pts:=PackedVector2Array()
		for j in range(4):pts.append(at+Vector2.from_angle(a0+j*TAU/10/3)*outer)
		for j in range(3,-1,-1):pts.append(at+Vector2.from_angle(a0+j*TAU/10/3)*inner)
		draw_colored_polygon(pts,Color("b9b0c8").lerp(Color("ffe3a0"),k))
	VfxArt.glow(self,at,r*.35,Color("fff3cf"),.7+.3*pulse)
	_ribbon(Vector2(at.x,at.y+r*.86),"다음 층  ▲",Color("e3c27a"),false)
	queue_redraw()
