class_name TurningPointPanel
extends PanelContainer
## Tactical selection surface. Rules/time/plans belong to the manager, not Controls.
var manager: TurningPointManager
var heading: Label
var resume_button: Button
var allies: HBoxContainer
var stances: HFlowContainer
var plans: Label
var choices: Dictionary = {}
var card_row: HBoxContainer
var card_controls: HBoxContainer
var use_button: Button
var cancel_button: Button
var card_result: Label
var card_buttons: Dictionary = {}
var card_signature: String = ""
var signature: String = ""
var debug_enabled: bool=false

func _ready() -> void:
	theme=ArenaUI.get_theme()
	var column := VBoxContainer.new()
	add_child(column)
	var row := HFlowContainer.new()
	column.add_child(row)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",14)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	heading.draw.connect(func():ArenaIcon.draw(heading,Vector2(8,heading.size.y*.5),"clock",14,Color("a7e0d8")))
	resume_button = Button.new()
	resume_button.text = "전투 재개"
	ArenaUI.with_icon(resume_button,"play",12,true)
	ArenaUI.primary(resume_button)
	resume_button.custom_minimum_size.y = 44
	ArenaUI.bind(resume_button,func():
		if manager != null: manager.resolve())
	row.add_child(resume_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 62
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	allies = HBoxContainer.new()
	scroll.add_child(allies)
	stances = HFlowContainer.new()
	column.add_child(stances)
	var names := ["기본", "신중함", "저돌적", "엄호"]
	for index in range(CombatStance.VALUES.size()):
		var value: StringName = CombatStance.VALUES[index]
		var button := Button.new()
		button.text = names[index]
		button.tooltip_text=ArenaUI.STANCE_HELP.get(value,"")
		ArenaUI.with_icon(button,{&"normal":"normal",&"cautious":"defense",&"rush":"battle",&"cover":"recruit"}[value],14)
		button.custom_minimum_size = Vector2(72, 34)
		button.toggle_mode = true
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
	var card_scroll := ScrollContainer.new()
	card_scroll.custom_minimum_size.y = 48
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(card_scroll)
	card_row = HBoxContainer.new()
	card_scroll.add_child(card_row)
	card_controls = HBoxContainer.new()
	column.add_child(card_controls)
	use_button = Button.new()
	use_button.text = "사용"
	use_button.custom_minimum_size = Vector2(60, 44)
	ArenaUI.bind(use_button,func():
		if manager != null: manager.use_selected_card())
	card_controls.add_child(use_button)
	cancel_button = Button.new()
	cancel_button.text = "취소"
	cancel_button.custom_minimum_size = Vector2(60, 44)
	ArenaUI.bind(cancel_button,func():
		if manager != null: manager.cancel_card_selection())
	card_controls.add_child(cancel_button)
	card_result = Label.new()
	card_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_result.add_theme_font_size_override("font_size", 12)
	card_controls.add_child(card_result)
	visible = false

func refresh(value: TurningPointManager) -> void:
	manager = value
	var active: bool = manager != null and manager.enabled and not manager.battle.finished and manager.current != null and not manager.current.resolved
	visible = active
	if not active:
		resume_button.disabled = true
		return
	var paused: bool = manager.is_paused()
	heading.text = "      %d초" % ceili(manager.current.remaining_real_time) if paused else "      감속"
	resume_button.disabled = not paused
	allies.get_parent().visible = paused
	stances.visible = paused
	plans.get_parent().visible = paused and debug_enabled
	card_row.get_parent().visible = paused
	card_controls.visible = paused and (manager.current.selected_card_id!=0 or not manager.current.last_card_result.is_empty())
	if not paused:
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
		if ally!=null:button.hp=ally.current_hp;button.hp_max=ally.max_hp;button.status_text=ArenaUI.stance(ally.stance)
		button.set_pressed_no_signal(button.name==manager.current.selected_member_id);button.queue_redraw()
	var selected: BattleUnit = EnemyPlanExecutor.find_member(manager.battle, manager.current.selected_member_id)
	for stance in choices:
		choices[stance].disabled = selected == null
		choices[stance].button_pressed = selected != null and selected.stance == stance
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
	var pending: Array[String] = []
	for command in manager.current.pending_commands:
		if command.member_id == manager.current.selected_member_id and not command.executed:
			pending.append(StrategyCardCatalog.get_card(command.command_type).display_name)
	var description: String = "카드 → 아군 → 사용"
	if manager.current.selected_card_id != 0:
		description = StrategyCardCatalog.get_card(manager.guild.state.get_strategy_card(manager.current.selected_card_id).kind).description
	elif not manager.current.last_card_result.is_empty():
		var code: int = manager.current.last_card_result.code
		description = "사용 완료" if code == StrategyCardExecutor.Code.OK else "사용 불가 · " + ArenaUI.reason(StrategyCardExecutor.Code.keys()[code])
	if selected != null:
		description += "\nHP %d · 궁극기 %d · 보호막 %d" % [ceili(selected.current_hp), int(selected.ultimate_gauge), int(selected.shield_hp)]
	if not pending.is_empty(): description += " · 대기: " + ",".join(pending)
	card_result.text = description


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
		button.card_type="mini_member";button.type_id=unit.data.type_id;button.title=unit.data.display_name;button.subtitle=unit.data.display_name;button.hp=unit.current_hp;button.hp_max=unit.max_hp;button.status_text=ArenaUI.stance(unit.stance);button.energy=manager.guild.get_member(id).energy
		button.show_member(manager.guild,manager.guild.get_member(id));button.hp=unit.current_hp;button.hp_max=unit.max_hp
		button.description=ArenaUI.member_label(id)+" · "+ArenaUI.stance(unit.stance)
		button.name = id
		button.text = "%s %s\n%s" % [unit.data.display_name, ArenaUI.member_label(id), ArenaUI.stance(unit.stance)]
		button.custom_minimum_size = Vector2(72, 76)
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
	card_buttons.clear()
	if manager == null or not manager.is_paused(): return
	for card in manager.guild.state.strategy_cards:
		var data: StrategyCardData = StrategyCardCatalog.get_card(card.kind)
		var button := ArenaCard.new()
		var available: bool = StrategyCardExecutor.availability(card, manager.guild.state.strategy_progress)
		var rule: String = "1회" if data.usage_rule == StrategyCardData.Usage.ONCE else "층당 1회" if data.usage_rule == StrategyCardData.Usage.FLOOR else "두 층 쿨타임"
		if not available:
			rule = "사용함" if card.consumed or data.usage_rule == StrategyCardData.Usage.FLOOR else "해금 %d층" % (card.ready_floor + 1)
		button.card_type="strategy";button.kind=String(card.kind);button.title=data.display_name;button.description=rule
		button.text = data.display_name + "\n" + rule
		button.custom_minimum_size = Vector2(104, 44)
		button.toggle_mode = true
		button.button_pressed = manager.current.selected_card_id == card.card_id
		button.disabled = not available
		var id: int = card.card_id
		ArenaUI.bind(button,func():
			if manager != null: manager.select_card(id))
		card_row.add_child(button)
		card_buttons[id] = button
