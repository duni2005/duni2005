class_name TurningPointPanel
extends VBoxContainer
## Tactical selection surface. Rules/time/plans belong to the manager, not Controls.
## Layout: a compact frame (time · resume · retreat, unit strip with allies then enemies, stance
## segments), then the strategy card hand (StrategyHand) fanned below it. Cards are played by
## swiping them up: unit cards on the unit selected on the field or in the strip (allies and
## enemies), position cards by dropping them on the field, instant cards at once. Tapping a card
## shows its details.
var manager: TurningPointManager
var heading: Label
var resume_button: Button
var allies: HBoxContainer
var stances: BoxContainer
var plans: Label
var choices: Dictionary = {}
var hand: StrategyHand
var detail: StrategyCardDetail
var detail_layer: CanvasLayer
var card_result: Label
var hand_signature: String = ""
var signature: String = ""
var debug_enabled: bool=false
## The field (DeploymentBoard): targets, drop points and highlights.
var board
var held_card: int = 0
const STANCE_ICONS := {&"normal":"normal",&"cautious":"defense",&"rush":"battle",&"cover":"recruit"}

func _ready() -> void:
	theme=ArenaUI.get_theme();add_theme_constant_override("separation",4)
	# Compact frame: time/resume row, ally chips, stance segments. The card hand sits below it, unframed.
	var box := PanelContainer.new();box.name="Frame"
	var frame: StyleBoxFlat=ArenaUI.window_style(ArenaUI.WINDOW_RIM,Color(ArenaUI.PANEL,.95))
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
	hand = StrategyHand.new();hand.name = "Hand";hand.size_flags_horizontal = Control.SIZE_FILL;add_child(hand)
	hand.card_tapped.connect(_card_tapped);hand.lift_started.connect(_lift_started);hand.lift_moved.connect(_lift_moved)
	hand.lift_ended.connect(_lift_ended);hand.play_requested.connect(_play_requested)
	detail_layer = CanvasLayer.new();detail_layer.layer = 70;add_child(detail_layer)
	detail = StrategyCardDetail.new();detail_layer.add_child(detail)
	visible = false

func refresh(value: TurningPointManager) -> void:
	manager = value
	var active: bool = manager != null and manager.enabled and not manager.battle.finished and manager.current != null and not manager.current.resolved
	visible = active
	if not active:
		resume_button.disabled = true;detail.hide();_clear_focus()
		return
	var paused: bool = manager.is_paused()
	heading.text = "       %d초" % ceili(manager.current.remaining_real_time) if paused else "       감속"
	resume_button.disabled = not paused
	allies.get_parent().visible = paused
	stances.visible = paused
	plans.get_parent().visible = paused and debug_enabled
	hand.visible = paused;card_result.visible = paused
	if not paused:
		detail.hide();_clear_focus()
		return
	var rows: Array[String] = []
	for unit in manager.battle.units:
		if unit.alive and (not unit.source_member_id.is_empty() or not unit.source_enemy_id.is_empty()):
			rows.append(unit.actor_id())
	var new_signature: String = "|".join(rows) + manager.current.turning_point_id
	if signature != new_signature:
		signature = new_signature
		# Defer removal until a clicked button callback is no longer on the stack.
		call_deferred("_rebuild_allies")
	for button in allies.get_children():
		if not button is ArenaCard:continue
		var unit: BattleUnit=manager.battle.find_actor(String(button.get_meta("actor","")))
		if unit!=null and unit.alive:button.hp=unit.current_hp;button.hp_max=unit.max_hp;button.status_text=ArenaUI.stance(unit.stance) if unit.team==0 else ("전략 준비" if manager.plan_of(unit)!=null else "적");button.kind=STANCE_ICONS.get(unit.stance,"normal")
		button.set_pressed_no_signal(String(button.get_meta("actor",""))==manager.current.selected_actor_id);button.queue_redraw()
	var selected: BattleUnit = EnemyPlanExecutor.find_member(manager.battle, manager.current.selected_member_id)
	var target: BattleUnit = manager.battle.find_actor(manager.current.selected_actor_id) if not manager.current.selected_actor_id.is_empty() else null
	var ally_chosen: bool = target == null or target.team == 0
	for stance in choices:
		choices[stance].disabled = selected == null or not ally_chosen
		choices[stance].set_pressed_no_signal(selected != null and ally_chosen and selected.stance == stance)
	var lines: Array[String] = []
	for plan in manager.current.enemy_plans:
		var enemy: BattleUnit = EnemyPlanExecutor.find_enemy(manager.battle, plan.source_enemy_id)
		var type_name: String = enemy.data.display_name if enemy != null else "DEAD"
		lines.append("%s %s · %s" % [type_name, plan.source_enemy_id.trim_prefix("enemy_room_01_"), EnemyTurningPlan.NAMES[plan.plan_type]])
	plans.text = "\n".join(lines)
	# The hand: the cards taken into this battle; used 일반 / 쿨타임 cards face down.
	var hand_rows: Array = []
	for card in manager.hand_cards():
		var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
		var state: StringName = StrategyCardExecutor.hand_state(manager, card)
		var note: String = {&"used":"사용함", &"cooldown":"%d승 후" % card.wins_left, &"blocked":"대상 없음"}.get(state, "")
		hand_rows.append({"id": card.card_id, "kind": card.kind, "title": data.display_name, "state": "ready" if state == &"ready" else "used" if state == &"used" else "waiting", "note": note})
	var new_hand: String = str(hand_rows)
	if new_hand != hand_signature:hand_signature = new_hand;hand.set_rows(hand_rows)
	var pending: Array[String] = []
	for command in manager.current.pending_commands:
		if not command.executed:pending.append(StrategyCardCatalog.get_card(command.command_type).display_name)
	var description: String = "카드를 위로 밀어 올려 사용 · 누르면 설명" if not hand_rows.is_empty() else "가지고 들어온 전략카드가 없습니다"
	if target != null:description = "선택: %s%s · %s" % ["아군 " if target.team == 0 else "적 ", target.data.display_name, description]
	if not manager.current.last_card_result.is_empty() and manager.current.last_card_result.code == StrategyCardExecutor.Code.OK:description = "사용 완료 · " + description
	if not pending.is_empty(): description += " · 대기: " + ",".join(pending)
	card_result.text = description

## The strip: allies (with stance) then, after a gap, the enemies; tapping one chooses it as the
## target of unit cards (an ally also for the stance buttons).
func _rebuild_allies() -> void:
	for child in allies.get_children():
		allies.remove_child(child)
		child.queue_free()
	if manager == null or not manager.is_paused():
		return
	var gap_added: bool = false
	for side in [0, 1]:
		for unit in manager.battle.units:
			if not unit.alive or (side == 0 and unit.source_member_id.is_empty()) or (side == 1 and unit.source_enemy_id.is_empty()):
				continue
			if side == 1 and not gap_added:
				var gap := VSeparator.new();gap.custom_minimum_size.x = 8;allies.add_child(gap);gap_added = true
			var actor: String = unit.actor_id()
			var button := ArenaCard.new()
			if side == 0:button.show_member(manager.guild,manager.guild.get_member(unit.source_member_id))
			button.card_type="tp_member";button.type_id=unit.data.type_id;button.title=unit.data.display_name
			button.hp=unit.current_hp;button.hp_max=unit.max_hp;button.status_text=ArenaUI.stance(unit.stance) if side == 0 else "적";button.kind=STANCE_ICONS.get(unit.stance,"normal")
			button.description=(ArenaUI.member_label(unit.source_member_id)+" · "+ArenaUI.stance(unit.stance)) if side == 0 else "적 · " + unit.data.display_name
			button.name = unit.source_member_id if side == 0 else "enemy_%d" % unit.battle_id
			button.set_meta("actor", actor)
			button.text = "%s\n%s" % [unit.data.display_name, "아군" if side == 0 else "적"]
			button.custom_minimum_size = Vector2(50, 54)
			button.toggle_mode = true
			if side == 1:button.modulate = Color(1, .86, .86)
			button.button_pressed = actor == manager.current.selected_actor_id
			ArenaUI.bind(button,func():select_actor(actor))
			allies.add_child(button)

## Chooses a unit as the card target (and, for an ally, the stance subject); the field ring follows.
func select_actor(actor: String) -> void:
	if manager == null or not manager.is_paused():return
	var unit: BattleUnit = manager.battle.find_actor(actor)
	if unit == null or not unit.alive:return
	manager.current.selected_actor_id = actor
	if unit.team == 0 and not unit.source_member_id.is_empty():manager.current.selected_member_id = unit.source_member_id

# ---- The hand ----
## Where a hand card is on screen (tests and input helpers).
func card_global_point(id: int) -> Vector2:
	return hand.get_global_transform() * Vector2(hand.looks[id].pos) if hand.looks.has(id) else Vector2.INF
func _card(id: int) -> StrategyCardInstance:return manager.guild.state.get_strategy_card(id) if manager != null else null
func _data(id: int) -> StrategyCardData:
	var card: StrategyCardInstance = _card(id);return StrategyCardCatalog.get_card(card.kind) if card != null else null

func _card_tapped(id: int) -> void:
	var card: StrategyCardInstance = _card(id)
	if card == null:return
	var state: StringName = StrategyCardExecutor.hand_state(manager, card)
	var status: String = {&"used":"이번 전투에서 이미 사용함", &"cooldown":"%d승 후 사용 가능" % card.wins_left, &"blocked":"지금은 조건에 맞는 대상이 없음"}.get(state, "위로 밀어 올려 사용")
	detail.open(id, card.kind, status)

func _lift_started(id: int) -> void:
	held_card = id
	var data: StrategyCardData = _data(id)
	if data == null or board == null:return
	if data.unit_target():
		board.card_focus_on = true
		board.card_focus_ids = StrategyCardExecutor.targets(manager, data).map(func(u): return u.actor_id())

func _over_field(global_point: Vector2) -> bool:
	return board != null and board.get_global_rect().has_point(global_point) and global_point.y < hand.get_global_rect().position.y - 10

func _lift_moved(id: int, global_point: Vector2, _past: bool) -> void:
	var data: StrategyCardData = _data(id)
	if data == null or data.use_mode != &"position" or board == null:return
	hand.over_field = _over_field(global_point)
	if not hand.over_field:hand.preview = {};return
	var at: Vector2 = board.logical_from_screen(global_point);var px: float = board.pixels_per_unit()
	var valid: bool = at.x > 20 and at.y > 20 and at.x < ArenaMap.side - 20 and at.y < ArenaMap.side - 20
	hand.preview = {"shape": "wall", "size": Vector2(data.amount * px, StrategyCardTuning.WALL_THICKNESS * px), "angle": _wall_angle(at), "valid": valid}

## The wall faces the enemies (as TurningPointManager.add_wall places it).
func _wall_angle(at: Vector2) -> float:
	var foes: Array = manager.battle.units.filter(func(u): return u.alive and u.team == 1)
	if foes.is_empty():return PI * .5
	var c := Vector2.ZERO
	for f in foes:c += f.position
	c /= foes.size()
	return (c - at).orthogonal().angle()

func _lift_ended(_id: int) -> void:
	_clear_focus()
func _clear_focus() -> void:
	held_card = 0
	if board != null:board.card_focus_on = false;board.card_focus_ids = []

func _play_requested(id: int, global_point: Vector2) -> void:
	var data: StrategyCardData = _data(id)
	if data == null or manager == null or not manager.is_paused():hand.refuse(id, "지금은 사용할 수 없습니다");return
	match data.use_mode:
		&"position":
			if not _over_field(global_point):hand.refuse(id, "필드 위에 놓으세요");return
			var result: Dictionary = manager.play(id, "", board.logical_from_screen(global_point))
			if result.code == StrategyCardExecutor.Code.OK:hand.play(id, &"position", global_point)
			else:hand.refuse(id, _reason(result, data))
		&"instant":
			var result: Dictionary = manager.play(id)
			if result.code == StrategyCardExecutor.Code.OK:hand.play(id, &"instant")
			else:hand.refuse(id, _reason(result, data))
		_:
			var target: BattleUnit = manager.battle.find_actor(manager.current.selected_actor_id) if not manager.current.selected_actor_id.is_empty() else null
			if target == null or not StrategyCardExecutor.valid_target(manager, data, target):
				hand.refuse(id, StrategyCardExecutor.target_hint(data));return
			var result: Dictionary = manager.play(id, target.actor_id())
			if result.code == StrategyCardExecutor.Code.OK:hand.play(id, &"unit", board.screen_point(target.position) if board != null else Vector2.INF)
			else:hand.refuse(id, _reason(result, data))
	hand_signature = ""

func _reason(result: Dictionary, data: StrategyCardData) -> String:
	if result.has("hint"):return str(result.hint)
	match int(result.code):
		StrategyCardExecutor.Code.NO_EFFECT:return "지금은 효과가 없습니다"
		StrategyCardExecutor.Code.CONDITION:return "조건이 맞지 않습니다 (%s)" % data.condition_text()
		StrategyCardExecutor.Code.USED:return "이번 전투에서 이미 사용했습니다"
		StrategyCardExecutor.Code.COOLDOWN:return "쿨타임 중입니다"
		StrategyCardExecutor.Code.NO_POSITION:return "놓을 수 없는 위치입니다"
	return "사용할 수 없습니다"
