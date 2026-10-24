class_name TurningPointPanel
extends VBoxContainer
## Tactical selection surface. Rules/time/plans belong to the manager, not Controls.
## Layout: a compact frame (time · resume · retreat, ally strip, stance segments), then the
## strategy card hand below it. Tapping a card (or flicking it up) lifts it out of the hand,
## enlarged over the bottom UI rather than the field, with a "use on the selected ally" button;
## touching anywhere else drops it back into the hand.
var manager: TurningPointManager
var heading: Label
var resume_button: Button
var allies: HBoxContainer
var stances: BoxContainer
var plans: Label
var choices: Dictionary = {}
var card_row: HBoxContainer
var use_button: Button
var cancel_button: Button
var card_result: Label
var card_buttons: Dictionary = {}
var card_signature: String = ""
var signature: String = ""
var debug_enabled: bool=false
var card_scroll: ScrollContainer
var pads: Array[Control] = []
var focus_layer: CanvasLayer
var focus_root: Control
var focus_dim: ColorRect
var focus_view: Control
var focus_target_icon: TextureRect
var focus_target: Label
var focus_card_id: int = 0
var focus_from: Rect2
var focus_t: float = 0
const CARD_SIZE := Vector2(74, 104)
const STANCE_ICONS := {&"normal":"normal",&"cautious":"defense",&"rush":"battle",&"cover":"recruit"}

func _ready() -> void:
	theme=ArenaUI.get_theme();add_theme_constant_override("separation",4)
	# Compact frame: time/resume row, ally chips, stance segments. The card hand sits below it, unframed.
	var box := PanelContainer.new();box.name="Frame"
	var frame: StyleBoxFlat=ArenaUI.box(Color(.05,.07,.12,.94),Color("3c4a72"));frame.set_corner_radius_all(14)
	for side in ["left","right"]:frame.set("content_margin_"+side,8)
	frame.content_margin_top=6;frame.content_margin_bottom=6;frame.border_width_top=2;frame.border_color=Color("8fe3ff",.55)
	box.add_theme_stylebox_override("panel",frame);add_child(box)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",4)
	box.add_child(column)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",8)
	column.add_child(row)
	heading = Label.new()
	heading.add_theme_font_override("font",ArenaUI.numbers_font());heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",Color("8fe3ff"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL;heading.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	row.add_child(heading)
	heading.draw.connect(func():ArenaIcon.draw(heading,Vector2(10,heading.size.y*.5),"clock",18,Color("8fe3ff")))
	resume_button = Button.new()
	resume_button.text = "전투 재개"
	ArenaUI.with_icon(resume_button,"play",12,true)
	ArenaUI.primary(resume_button)
	resume_button.custom_minimum_size = Vector2(112, 44)
	ArenaUI.bind(resume_button,func():
		if manager != null: manager.resolve())
	row.add_child(resume_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 56
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	column.add_child(scroll)
	allies = HBoxContainer.new();allies.add_theme_constant_override("separation",4)
	scroll.add_child(allies)
	# Stance segments for the selected ally.
	stances = HBoxContainer.new();stances.add_theme_constant_override("separation",4)
	column.add_child(stances)
	var names := ["기본", "신중함", "저돌적", "엄호"]
	for index in range(CombatStance.VALUES.size()):
		var value: StringName = CombatStance.VALUES[index]
		var button := Button.new()
		button.text = names[index]
		button.tooltip_text=ArenaUI.STANCE_HELP.get(value,"")
		ArenaUI.with_icon(button,STANCE_ICONS[value],14)
		button.custom_minimum_size = Vector2(0, 34);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.toggle_mode = true;ArenaUI.tab(button)
		ArenaUI.bind(button,func():
			if manager != null and manager.current != null:
				manager.change_stance(manager.current.selected_member_id, value))
		stances.add_child(button)
		choices[value] = button
	var plan_scroll := ScrollContainer.new()
	plan_scroll.custom_minimum_size.y = 36
	plan_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(plan_scroll)
	plans = Label.new()
	plans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plans.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plans.add_theme_font_size_override("font_size", 12)
	plan_scroll.add_child(plans)
	# Strategy card hand: outside the frame, pushed to the bottom edge when there is room.
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	var gap := Control.new();gap.size_flags_vertical=Control.SIZE_EXPAND_FILL;gap.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(gap)
	card_result = Label.new()
	card_result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card_result.clip_text=true;card_result.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	card_result.add_theme_font_size_override("font_size", 11);card_result.add_theme_color_override("font_color",Color("9aa5c2"))
	add_child(card_result)
	card_scroll = ScrollContainer.new()
	card_scroll.custom_minimum_size.y = CARD_SIZE.y + 4
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	card_scroll.scroll_ended.connect(_snap_to_nearest)
	add_child(card_scroll)
	card_row = HBoxContainer.new();card_row.add_theme_constant_override("separation",0)
	card_scroll.add_child(card_row)
	_build_focus()
	visible = false

## Full-screen layer for the lifted card: dim backdrop, big card, target and use/cancel buttons.
func _build_focus() -> void:
	focus_layer=CanvasLayer.new();focus_layer.layer=60;add_child(focus_layer)
	focus_root=Control.new();focus_root.theme=ArenaUI.get_theme();focus_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);focus_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_layer.add_child(focus_root)
	focus_dim=ColorRect.new();focus_dim.color=Color(.01,.02,.05,0);focus_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);focus_root.add_child(focus_dim)
	focus_dim.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			if manager != null: manager.cancel_card_selection())
	focus_view=Control.new();focus_view.mouse_filter=Control.MOUSE_FILTER_IGNORE;focus_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);focus_root.add_child(focus_view)
	focus_view.draw.connect(_draw_focus)
	var dock:=VBoxContainer.new();dock.name="FocusDock";dock.add_theme_constant_override("separation",8);focus_root.add_child(dock)
	var target_row:=HBoxContainer.new();target_row.add_theme_constant_override("separation",6);dock.add_child(target_row)
	focus_target_icon=TextureRect.new();focus_target_icon.custom_minimum_size=Vector2(34,34);focus_target_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;focus_target_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;target_row.add_child(focus_target_icon)
	focus_target=Label.new();focus_target.add_theme_font_size_override("font_size",12);focus_target.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;focus_target.size_flags_horizontal=Control.SIZE_EXPAND_FILL;focus_target.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;target_row.add_child(focus_target)
	use_button = Button.new()
	use_button.text = "사용"
	use_button.custom_minimum_size = Vector2(0, 52);use_button.clip_text=true;use_button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	ArenaUI.primary(use_button);ArenaUI.with_icon(use_button,"play",12,true)
	ArenaUI.bind(use_button,func():
		if manager != null: manager.use_selected_card())
	dock.add_child(use_button)
	cancel_button = Button.new()
	cancel_button.text = "취소"
	cancel_button.custom_minimum_size = Vector2(0, 40);cancel_button.clip_text=true;cancel_button.add_theme_font_size_override("font_size",12)
	ArenaUI.bind(cancel_button,func():
		if manager != null: manager.cancel_card_selection())
	dock.add_child(cancel_button)
	focus_root.visible=false

## The lifted card stays over the bottom UI (frame and hand) so the field remains visible:
## card on the left, target and use/cancel buttons beside it.
func _focus_region() -> Rect2:
	var view: Vector2=get_viewport_rect().size;var top: float=minf(get_child(0).get_global_rect().position.y-6,view.y-200)
	return Rect2(0,top,view.x,view.y-top)
func _focus_rect() -> Rect2:
	var view: Vector2=get_viewport_rect().size;var region: Rect2=_focus_region()
	var h: float=clampf(region.size.y-20,170,320);var w: float=minf(h/1.3,view.x*.56);h=w*1.3
	var dock_w: float=clampf(view.x-w-42,120,240);var x: float=(view.x-w-14-dock_w)*.5
	return Rect2(Vector2(x,region.position.y+(region.size.y-h)*.5),Vector2(w,h))

func _draw_focus() -> void:
	if focus_card_id==0 or manager==null:return
	var card: StrategyCardInstance=manager.guild.state.get_strategy_card(focus_card_id)
	if card==null:return
	var data: StrategyCardData=StrategyCardCatalog.get_card(card.kind)
	var e: float=1-pow(1-clampf(focus_t,0,1),3)
	# Shade the bottom UI behind the card; the field above only gets the light backdrop.
	var region: Rect2=_focus_region();focus_view.draw_rect(region,Color(.02,.03,.07,.78*e))
	focus_view.draw_line(region.position,region.position+Vector2(region.size.x,0),Color(ArenaUI.GOLD,.5*e),2)
	var target: Rect2=_focus_rect();var r:=Rect2(focus_from.position.lerp(target.position,e),focus_from.size.lerp(target.size,e))
	StrategyCardArt.draw(focus_view,r,String(card.kind),data.display_name,_rule(data),data.description if e>.6 else "","ready")

func _rule(data: StrategyCardData) -> String:
	return "일회성" if data.usage_rule == StrategyCardData.Usage.ONCE else "층당 1회" if data.usage_rule == StrategyCardData.Usage.FLOOR else "두 층 쿨타임"

func _process(delta: float) -> void:
	if not visible or card_row==null:return
	_shape_hand()
	if focus_root.visible:
		focus_t=minf(1,focus_t+delta/.28)
		focus_dim.color.a=.22*minf(1,focus_t*1.5)
		var dock: Control=focus_root.get_node("FocusDock");var target: Rect2=_focus_rect()
		dock.size=Vector2(clampf(get_viewport_rect().size.x-target.size.x-42,120,240),0)
		dock.position=Vector2(target.end.x+14,target.get_center().y-dock.get_combined_minimum_size().y*.5);dock.modulate.a=clampf((focus_t-.4)/.6,0,1)
		focus_view.queue_redraw()

## Fan the hand: cards near the strip centre are full size and raised, edges shrink and tilt.
func _shape_hand() -> void:
	var view_w: float=card_scroll.size.x;var center: float=card_scroll.scroll_horizontal+view_w*.5
	for pad in pads:pad.custom_minimum_size.x=maxf(0,(view_w-CARD_SIZE.x)*.5)
	for button in card_buttons.values():
		if not is_instance_valid(button):continue
		var d: float=clampf((button.position.x+button.size.x*.5-center)/maxf(1,view_w*.5),-1.4,1.4)
		var k: float=1-.24*minf(1,absf(d))
		button.pivot_offset=Vector2(button.size.x*.5,button.size.y);button.scale=Vector2.ONE*k;button.rotation=d*.07
		button.z_index=int(10-absf(d)*8)
		button.self_modulate=Color(1,1,1).darkened(.25*minf(1,absf(d)))

func _snap_to_nearest() -> void:
	if card_buttons.is_empty():return
	var center: float=card_scroll.scroll_horizontal+card_scroll.size.x*.5;var best=null;var gap: float=INF
	for button in card_buttons.values():
		var g: float=absf(button.position.x+button.size.x*.5-center)
		if g<gap:gap=g;best=button
	if best!=null:_center_on(best)

func _center_on(button: Control) -> void:
	var goal: int=int(button.position.x+button.size.x*.5-card_scroll.size.x*.5)
	create_tween().tween_property(card_scroll,"scroll_horizontal",maxi(0,goal),.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func refresh(value: TurningPointManager) -> void:
	manager = value
	var active: bool = manager != null and manager.enabled and not manager.battle.finished and manager.current != null and not manager.current.resolved
	visible = active
	if not active:
		resume_button.disabled = true;focus_root.visible=false;focus_card_id=0
		return
	var paused: bool = manager.is_paused()
	heading.text = "       %d초" % ceili(manager.current.remaining_real_time) if paused else "       감속"
	resume_button.disabled = not paused
	allies.get_parent().visible = paused
	stances.visible = paused
	plans.get_parent().visible = paused and debug_enabled
	card_scroll.visible = paused;card_result.visible=paused
	if not paused:
		focus_root.visible=false
		return
	var rows: Array[String] = []
	for unit in manager.battle.units:
		if unit.alive and not unit.source_member_id.is_empty():
			rows.append(unit.source_member_id)
	var new_signature: String = "|".join(rows) + manager.current.turning_point_id
	if signature != new_signature:
		signature = new_signature
		# Defer removal until a clicked button callback is no longer on the stack.
		call_deferred("_rebuild_allies")
	for button in allies.get_children():
		var ally: BattleUnit=EnemyPlanExecutor.find_member(manager.battle,String(button.name))
		if ally!=null:button.hp=ally.current_hp;button.hp_max=ally.max_hp;button.status_text=ArenaUI.stance(ally.stance);button.kind=STANCE_ICONS.get(ally.stance,"normal")
		button.set_pressed_no_signal(button.name==manager.current.selected_member_id);button.queue_redraw()
	var selected: BattleUnit = EnemyPlanExecutor.find_member(manager.battle, manager.current.selected_member_id)
	for stance in choices:
		choices[stance].disabled = selected == null
		choices[stance].set_pressed_no_signal(selected != null and selected.stance == stance)
	var lines: Array[String] = []
	for plan in manager.current.enemy_plans:
		var enemy: BattleUnit = EnemyPlanExecutor.find_enemy(manager.battle, plan.source_enemy_id)
		var type_name: String = enemy.data.display_name if enemy != null else "DEAD"
		var kind: String = "특수 능력" if plan.plan_type == EnemyTurningPlan.SPECIAL else "집중" if plan.plan_type == EnemyTurningPlan.FOCUS else "후퇴"
		lines.append("%s %s · %s%s" % [type_name, plan.source_enemy_id.trim_prefix("enemy_room_01_"), kind, " → " + plan.target_member_id if plan.plan_type == EnemyTurningPlan.FOCUS else ""])
	plans.text = "\n".join(lines)
	var card_rows: Array[String] = []
	for card in manager.guild.state.strategy_cards:
		card_rows.append("%d:%s:%d:%s:%s" % [card.card_id, card.consumed, card.ready_floor, card.used_floors, manager.current.selected_card_id == card.card_id])
	var new_cards: String = "|".join(card_rows) + manager.current.turning_point_id + str(manager.guild.state.strategy_progress.unlocked_floor) + str(manager.guild.state.strategy_progress.current_depth)
	if new_cards != card_signature:
		card_signature = new_cards
		call_deferred("_rebuild_cards")
	use_button.disabled = selected == null or manager.current.selected_card_id == 0
	cancel_button.disabled = manager.current.selected_card_id == 0
	_update_focus(selected)
	var pending: Array[String] = []
	for command in manager.current.pending_commands:
		if command.member_id == manager.current.selected_member_id and not command.executed:
			pending.append(StrategyCardCatalog.get_card(command.command_type).display_name)
	var description: String = "카드를 눌러 크게 보고, 선택한 아군에게 사용하세요."
	if manager.current.selected_card_id != 0:
		description = StrategyCardCatalog.get_card(manager.guild.state.get_strategy_card(manager.current.selected_card_id).kind).description
	elif not manager.current.last_card_result.is_empty():
		var code: int = manager.current.last_card_result.code
		description = "사용 완료" if code == StrategyCardExecutor.Code.OK else "사용 불가 · " + ArenaUI.reason(StrategyCardExecutor.Code.keys()[code])
	if not pending.is_empty(): description += " · 대기: " + ",".join(pending)
	card_result.text = description

## Lift the selected card out of the hand, or drop it back when the selection clears.
func _update_focus(selected: BattleUnit) -> void:
	var id: int=manager.current.selected_card_id
	if id==0:
		if focus_root.visible:focus_root.visible=false;focus_card_id=0
		return
	if id!=focus_card_id:
		focus_card_id=id;focus_t=0
		var button=card_buttons.get(id)
		focus_from=button.get_global_rect() if is_instance_valid(button) else _focus_rect()
		focus_root.visible=true
	if selected!=null:
		focus_target_icon.texture=UnitIcon.texture(selected.data.type_id);focus_target_icon.visible=true
		focus_target.text="%s %s\nHP %d / %d"%[selected.data.display_name,ArenaUI.member_label(selected.source_member_id),ceili(selected.current_hp),ceili(selected.max_hp)]
		use_button.text="%s에게 사용"%selected.data.display_name
	else:
		focus_target_icon.visible=false;focus_target.text="먼저 아군을 선택하세요";use_button.text="사용"

func _rebuild_allies() -> void:
	for child in allies.get_children():
		allies.remove_child(child)
		child.queue_free()
	if manager == null or not manager.is_paused():
		return
	for unit in manager.battle.units:
		if not unit.alive or unit.source_member_id.is_empty():
			continue
		var id: String = unit.source_member_id
		var button := ArenaCard.new()
		button.show_member(manager.guild,manager.guild.get_member(id));button.card_type="tp_member";button.type_id=unit.data.type_id;button.title=unit.data.display_name
		button.hp=unit.current_hp;button.hp_max=unit.max_hp;button.status_text=ArenaUI.stance(unit.stance);button.kind=STANCE_ICONS.get(unit.stance,"normal")
		button.description=ArenaUI.member_label(id)+" · "+ArenaUI.stance(unit.stance)
		button.name = id
		button.text = "%s %s\n%s" % [unit.data.display_name, ArenaUI.member_label(id), ArenaUI.stance(unit.stance)]
		button.custom_minimum_size = Vector2(50, 54)
		button.toggle_mode = true
		button.button_pressed = id == manager.current.selected_member_id
		ArenaUI.bind(button,func():
			if manager != null and manager.is_paused() and EnemyPlanExecutor.find_member(manager.battle, id) != null:
				manager.current.selected_member_id = id)
		allies.add_child(button)

func _rebuild_cards() -> void:
	for child in card_row.get_children():
		card_row.remove_child(child)
		child.queue_free()
	card_buttons.clear();pads.clear()
	if manager == null or not manager.is_paused(): return
	var lead:=Control.new();lead.mouse_filter=Control.MOUSE_FILTER_IGNORE;card_row.add_child(lead);pads.append(lead)
	for card in manager.guild.state.strategy_cards:
		var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
		var button := ArenaCard.new()
		var available: bool = StrategyCardExecutor.availability(card, manager.guild.state.strategy_progress)
		var note: String = ""
		if not available:
			note = "사용함" if card.consumed or data.usage_rule == StrategyCardData.Usage.FLOOR else "%d층부터" % (card.ready_floor + 1)
		button.card_type="hand_card";button.kind=String(card.kind);button.title=data.display_name;button.description=_rule(data);button.status_text=note
		button.text = data.display_name + "\n" + (note if not available else _rule(data))
		button.tooltip_text=data.description
		button.custom_minimum_size = CARD_SIZE
		button.toggle_mode = true
		button.button_pressed = manager.current.selected_card_id == card.card_id
		button.disabled = not available
		var id: int = card.card_id
		ArenaUI.bind(button,func():
			if manager != null: manager.select_card(id))
		button.gui_input.connect(_flick.bind(button,id))
		card_row.add_child(button)
		card_buttons[id] = button
	var tail:=Control.new();tail.mouse_filter=Control.MOUSE_FILTER_IGNORE;card_row.add_child(tail);pads.append(tail)
	_shape_hand()

## Flicking a card upward lifts it, the same as tapping it.
func _flick(event: InputEvent,button: ArenaCard,id: int) -> void:
	if button.disabled or manager==null:return
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:button.set_meta("flick_from",event.position)
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and button.has_meta("flick_from"):
		var moved: Vector2=event.position-Vector2(button.get_meta("flick_from"))
		if moved.y<-36 and absf(moved.x)<absf(moved.y)*.7:
			button.remove_meta("flick_from")
			if manager.current!=null and manager.current.selected_card_id!=id:manager.select_card(id)
