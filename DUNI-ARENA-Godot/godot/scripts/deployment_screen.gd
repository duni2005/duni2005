class_name DeploymentScreen
extends Control
## Debug session flow. Owns presentation and calls settlement on completed results;
## deployment data/rules have no dependency on this screen.
@export var debug_comparison_minimal: bool = false
var guild := GuildManager.new()
var plan: DeploymentPlan
var board: DeploymentBoard
var status: BattleStatusLine
var roster: HBoxContainer
var start_button: Button
var clear_button: Button
var remove_button: Button
var restore_button: Button
var next_button: Button
var deploy_tools: PopupMenu
var deploy_tools_button: Button
var undo_button: Button
var redo_button: Button
var erase_button: Button
var tools_row: HBoxContainer
var tool_mode_label: Label
var sortie_label: Label
var undo_history: Array[Array]=[]
var redo_history: Array[Array]=[]
var edit_before: Array=[]
var roster_refresh_pending: bool=false
var tool_view_state: Array=[]
var battle: BattleManager
var settlement := BattleSettlement.new()
var settlement_status: BattleSettlement.Status = BattleSettlement.Status.INVALID_RESULT
var enemies: Array[Dictionary] = []

func _ready() -> void:
	for index in range(6):
		var member: GuildMemberState = guild.create_member(0 if index < 3 else 1)
		member.current_hp -= index * 5
		member.ultimate_gauge = index * 7
		member.transcendence_gauge = index * 3
	enemies = [
		{"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(640, 260)},
		{"data": BattleManager.WARRIOR, "team": 1, "position": Vector2(640, 540)},
		{"data": BattleManager.ARCHER, "team": 1, "position": Vector2(720, 400)},
	]
	_build_ui()
	begin_deployment()

func _build_ui() -> void:
	ArenaUI.install(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	ArenaUI.safe_margin(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var title := Label.new()
	title.text = "전투 준비 · 길드원 배치"
	title.add_theme_font_size_override("font_size", 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.y = 24
	column.add_child(title)
	status = BattleStatusLine.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 18
	status.add_theme_font_size_override("font_size",12)
	column.add_child(status)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	start_button = _button(actions, "전투 시작", start_battle)
	remove_button = _button(actions, "배치 해제", remove_selected)
	clear_button = _button(actions, "초기화", clear_draft)
	restore_button = _button(actions, "진형 복원", restore_formation)
	next_button = _button(actions, "다음 배치", begin_deployment)
	tools_row=HBoxContainer.new();actions.add_child(tools_row);tools_row.add_theme_constant_override("separation",4)
	undo_button=_tool(tools_row,"undo","실행 취소",undo_draft)
	redo_button=_tool(tools_row,"redo","다시 실행",redo_draft)
	erase_button=_tool(tools_row,"eraser","지우개 · 배치된 유닛을 눌러 해제",toggle_eraser);erase_button.toggle_mode=true
	deploy_tools_button=erase_button # Retained inspection handle; no popup action.
	var clear_tool: Button=_tool(tools_row,"clear_all","모두 지우기",clear_draft);clear_tool.name="ClearAll"
	tool_mode_label=Label.new();tool_mode_label.add_theme_font_size_override("font_size",11);tools_row.add_child(tool_mode_label)
	sortie_label=Label.new();sortie_label.name="Sortie";sortie_label.add_theme_font_size_override("font_size",13);tools_row.add_child(sortie_label)
	deploy_tools=PopupMenu.new();add_child(deploy_tools)
	for label in ["선택 길드원 배치 해제","전체 배치 초기화","마지막 진형 복원"]:deploy_tools.add_item(label)
	deploy_tools.id_pressed.connect(func(id):
		if id==0:remove_selected()
		elif id==1:clear_draft()
		elif id==2:restore_formation())
	board = DeploymentBoard.new()
	board.name = "Board"
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, 240)
	board.selection_changed.connect(_selection_changed)
	board.unit_info_requested.connect(_open_unit_info)
	var field:=ArenaFieldBackdrop.new();field.board=board;add_child(field)
	board.placement_changed.connect(_placement_changed)
	board.edit_started.connect(_begin_edit)
	board.edit_finished.connect(_commit_edit)
	column.add_child(board)
	var legend := Label.new()
	legend.text = "길드원 선택 → 아군 영역을 터치하세요. 배치된 아군은 드래그해서 옮길 수 있습니다."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(legend)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 126
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	roster = HBoxContainer.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(roster)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if text=="전투 시작":ArenaUI.primary(button);ArenaUI.with_icon(button,"play",12,true)
	button.custom_minimum_size.y = 42
	ArenaUI.bind(button,callback)
	parent.add_child(button)
	return button

func _refresh_roster() -> void:
	# Never remove a Button while its GUI pressed callback is on the stack.
	if roster_refresh_pending:return
	roster_refresh_pending=true
	call_deferred("_rebuild_roster")

func _rebuild_roster() -> void:
	roster_refresh_pending=false
	var ids: Array=[]
	for member in guild.all_members():
		ids.append(member.member_id)
		var data: UnitData = guild.definition(member.unit_type_id)
		var placed: bool = plan.get_entry(member.member_id) != null
		var label: String = "%s %s %s\nHP %s\n%s · %s" % [data.emoji,data.display_name,ArenaUI.member_label(member.member_id),ArenaUI.hp(member.current_hp,guild.member_max_hp(member)),ArenaUI.stance(member.stance),"사망 · 배치 불가" if not member.is_alive() else "배치됨" if placed else "대기"]
		var button: ArenaCard=roster.get_node_or_null(member.member_id)
		if button==null:
			button=ArenaCard.new();button.name=member.member_id;ArenaUI.bind(button,_roster_pressed.bind(member.member_id));roster.add_child(button)
		button.text=label;button.card_type="deploy_member";button.show_member(guild,member);button.deployed=placed;button.subtitle="%s · Lv.%d"%[ArenaUI.member_label(member.member_id),member.level];button.status_text=ArenaUI.stance(member.stance)+(" · 배치됨" if placed else " · 대기")
		button.name = member.member_id
		button.custom_minimum_size = Vector2(88, 122)
		button.toggle_mode = true
		button.set_pressed_no_signal(member.member_id == board.selected_id)
		button.disabled = not board.editing or not member.is_alive()
		button.queue_redraw()
	for child in roster.get_children():
		if child.name not in ids:roster.remove_child(child);child.queue_free()
	_update_tools()

## Field taps: an ally shows its own numbers, an enemy its preview numbers or base stats.
func _open_unit_info(unit_type: int, member_id: String, stats: UnitCombatStats) -> void:
	var member: GuildMemberState=guild.get_member(member_id) if not member_id.is_empty() else null
	UnitInfoSheet.open(self,unit_type,stats if stats!=null else guild.member_stats(member) if member!=null else null,member)
## Tapping the selected roster unit again opens its description sheet.
func _roster_pressed(member_id: String) -> void:
	var member: GuildMemberState=guild.get_member(member_id)
	if member_id==board.selected_id and member!=null:UnitInfoSheet.open(self,member.unit_type_id,guild.member_stats(member),member);_refresh_roster();return
	board.select(member_id)

func begin_deployment() -> void:
	# No leaving active battles; this is next completed battle, not retreat/retry.
	if is_instance_valid(battle) and not battle.finished:
		return
	if is_instance_valid(battle):
		board.remove_child(battle)
		battle.queue_free()
		battle = null
	board.battle = null
	var blockers: Array[Vector2] = []
	for enemy in enemies:
		blockers.append(enemy.position)
	plan = DeploymentPlan.new(guild, blockers)
	board.plan = plan
	board.enemies = enemies
	board.editing = true
	board.selected_id = ""
	var restored: int = plan.restore(guild.state.last_formation)
	undo_history.clear();redo_history.clear();board.erase_mode=false;erase_button.set_pressed_no_signal(false)
	status.text = "아군 영역에 배치하세요. 이전 진형 %d명 복원" % restored
	for button in [start_button, clear_button, remove_button, restore_button]:
		button.disabled = false
	next_button.disabled = true
	_refresh_roster()

func _selection_changed(member_id: String) -> void:
	status.text = "%s %s 선택 · 이동할 위치를 터치하세요." % [guild.definition(guild.get_member(member_id).unit_type_id).display_name,ArenaUI.member_label(member_id)]
	_refresh_roster()

func _placement_changed(error: DeploymentRules.Code) -> void:
	status.text = "배치가 변경되었습니다." if error == DeploymentRules.Code.OK else ArenaUI.reason(DeploymentRules.Code.keys()[error])
	_refresh_roster()

func remove_selected() -> void:
	if not board.editing:
		return
	_begin_edit();status.text = "이번 전투 배치를 해제했습니다." if plan.remove(board.selected_id) else "선택한 길드원이 아직 배치되지 않았습니다.";_commit_edit()
	_refresh_roster()

func clear_draft() -> void:
	if board.editing:
		_begin_edit()
		plan.clear()
		_commit_edit()
		status.text = "배치 초기화 · 길드원 상태는 유지됩니다."
		_refresh_roster()

func restore_formation() -> void:
	if board.editing:
		_begin_edit()
		status.text = "이전 진형에서 생존 길드원 %d명을 복원했습니다." % plan.restore(guild.state.last_formation)
		_commit_edit()
		_refresh_roster()

func start_battle() -> void:
	if not board.editing:
		return
	battle = BattleManager.new()
	if debug_comparison_minimal:
		battle.common_combat_enabled=false
		battle.full_characters_enabled=false
	battle.auto_start = false
	board.add_child(battle)
	battle.battle_finished.connect(_finished)
	if not plan.launch(battle, enemies):
		board.remove_child(battle)
		battle.queue_free()
		battle = null
		status.text = "생존 길드원을 유효한 위치에 배치하세요."
		return
	board.battle = battle
	board.editing = false
	for button in [start_button, clear_button, remove_button, restore_button]:
		button.disabled = true
	_refresh_roster()

func _finished(result: BattleResult) -> void:
	settlement_status = settlement.apply(result, guild)
	status.text = "%s | %.1f s | settlement: %s. Next deployment restores survivors at their START positions." % ["DRAW" if result.draw else "BLUE WINS" if result.winner_team == 0 else "RED WINS", result.elapsed, BattleSettlement.Status.keys()[settlement_status]]
	next_button.disabled = settlement_status != BattleSettlement.Status.APPLIED
	_refresh_roster()

func _process(_delta: float) -> void:
	_update_tools()
	if is_instance_valid(battle) and battle.started and not battle.finished:
		status.text = "전투 %.1f초 · %d×" % [battle.clock.elapsed,int(battle.clock.speed)]

func _tool(parent: Node,kind: String,hint: String,callback: Callable) -> Button:
	var b:=DeploymentToolButton.new();b.tool_kind=kind;b.name=kind;b.tooltip_text=hint;ArenaUI.bind(b,callback);parent.add_child(b);return b
func _draft() -> Array:
	var rows: Array=[]
	if plan!=null:
		for entry in plan.entries():rows.append({"id":entry.member_id,"position":entry.position})
	return rows
func _begin_edit() -> void:edit_before=_draft()
func _commit_edit() -> void:
	if edit_before!=_draft():undo_history.append(edit_before.duplicate(true));redo_history.clear()
	if undo_history.size()>64:undo_history.pop_front()
	_update_tools()
func _apply_draft(rows: Array) -> void:
	plan.clear()
	for row in rows:plan.place(row.id,row.position)
	board.queue_redraw();_refresh_roster()
func undo_draft() -> void:
	if not board.editing or undo_history.is_empty():return
	redo_history.append(_draft());_apply_draft(undo_history.pop_back());status.text="배치를 한 단계 되돌렸습니다.";_update_tools()
func redo_draft() -> void:
	if not board.editing or redo_history.is_empty():return
	undo_history.append(_draft());_apply_draft(redo_history.pop_back());status.text="배치를 다시 적용했습니다.";_update_tools()
func toggle_eraser() -> void:
	if not board.editing:return
	board.erase_mode=erase_button.button_pressed;status.text="해제할 유닛을 누르세요." if board.erase_mode else "선택한 유닛을 배치하세요."
func _update_tools() -> void:
	if undo_button==null or board==null:return
	var view_state: Array=[board.editing,undo_history.size(),redo_history.size(),plan.entries().size() if plan!=null else 0,board.erase_mode,GrowthRules.sortie_limit(guild.state)]
	if view_state==tool_view_state:return
	tool_view_state=view_state
	tools_row.visible=board.editing;undo_button.disabled=not board.editing or undo_history.is_empty();redo_button.disabled=not board.editing or redo_history.is_empty()
	tools_row.get_node("ClearAll").disabled=not board.editing or plan==null or plan.entries().is_empty()
	for tool in [undo_button,redo_button,erase_button,tools_row.get_node("ClearAll")]:tool.queue_redraw()
	if tool_mode_label!=null:tool_mode_label.text="지우개 켜짐" if board.erase_mode else "";tool_mode_label.add_theme_color_override("font_color",ArenaUI.GOLD)
	# Units sent out of the guild's sortie limit; full turns gold.
	var placed: int=plan.entries().size() if plan!=null else 0;var limit: int=GrowthRules.sortie_limit(guild.state)
	sortie_label.text="출정 %d/%d"%[placed,limit];sortie_label.add_theme_color_override("font_color",ArenaUI.GOLD if placed>=limit else ArenaUI.MUTED)
