class_name PredictionModeScreen
extends Control
## 전투 예측 mode (main menu): a random situation from PredictionRules, pick the team you think
## will win and watch the AI fight it out. The situation can be rerolled until the battle starts.
## Hits and streaks count for this visit only; no run, gold or save is touched.
signal closed
var rng := RandomNumberGenerator.new()
var state: PredictionState
var battle: BattleManager
var board: DeploymentBoard
var pick_page: VBoxContainer
var watch_page: VBoxContainer
var result_page: VBoxContainer
var section: Label
var teams_box: VBoxContainer
var start_button: Button
var score_label: Label
var speed_buttons: Dictionary = {}
var ending: RetreatPresentation
var battle_cue: BattleCueOverlay
var stats_dialog: AcceptDialog
## Shown once the picked team is wiped out while the others fight on.
var fail_row: HBoxContainer
var hits: int = 0
var tries: int = 0
var streak: int = 0
var best: int = 0

func _ready() -> void:
	ArenaUI.install(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);rng.randomize()
	var back := ColorRect.new();back.color = ArenaUI.BACKGROUND;back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(back)
	var margin := MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin);ArenaUI.safe_margin(margin)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 8);margin.add_child(column)
	var header := HBoxContainer.new();header.custom_minimum_size.y = 44;column.add_child(header)
	var title := Label.new();title.text = "전투 예측";title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;title.add_theme_font_override("font", ArenaUI.heading_font());title.add_theme_font_size_override("font_size", 20);title.add_theme_color_override("font_color", ArenaUI.GOLD);header.add_child(title)
	var home := _button(header, "메인으로", func():closed.emit());ArenaUI.quiet(home)
	score_label = Label.new();score_label.add_theme_font_size_override("font_size", 12);score_label.add_theme_color_override("font_color", ArenaUI.MUTED);column.add_child(score_label)
	# Pick page: the situation, the team cards and reroll / start.
	pick_page = VBoxContainer.new();pick_page.size_flags_vertical = Control.SIZE_EXPAND_FILL;pick_page.add_theme_constant_override("separation", 10);column.add_child(pick_page)
	section = Label.new();section.add_theme_font_override("font", ArenaUI.heading_font());section.add_theme_font_size_override("font_size", 16);section.add_theme_color_override("font_color", Color("e8d6a6"));pick_page.add_child(section)
	var hint := Label.new();hint.text = "이길 것 같은 팀을 고른 뒤 관전하세요.";hint.add_theme_font_size_override("font_size", 12);hint.add_theme_color_override("font_color", ArenaUI.MUTED);pick_page.add_child(hint)
	teams_box = VBoxContainer.new();pick_page.add_child(teams_box)
	var gap := Control.new();gap.size_flags_vertical = Control.SIZE_EXPAND_FILL;pick_page.add_child(gap)
	var row := HBoxContainer.new();row.add_theme_constant_override("separation", 8);pick_page.add_child(row)
	var reroll := _button(row, "↻ 상황 새로고침", new_situation);reroll.name = "Reroll";reroll.custom_minimum_size = Vector2(140, 52);ArenaUI.quiet(reroll)
	start_button = _button(row, "관전 시작", start_watch);start_button.name = "Watch";start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL;start_button.custom_minimum_size.y = 52;ArenaUI.primary(start_button);ArenaUI.with_icon(start_button, "battle", 14)
	start_button.add_theme_color_override("font_disabled_color", ArenaUI.MUTED)
	# Watch page: the field and the speed buttons.
	watch_page = VBoxContainer.new();watch_page.size_flags_vertical = Control.SIZE_EXPAND_FILL;watch_page.add_theme_constant_override("separation", 6);column.add_child(watch_page);watch_page.hide()
	# Result page: the outcome card and what to do next.
	result_page = VBoxContainer.new();result_page.size_flags_vertical = Control.SIZE_EXPAND_FILL;result_page.add_theme_constant_override("separation", 10);column.add_child(result_page);result_page.hide()
	new_situation()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new();b.text = text;b.custom_minimum_size.y = 44;ArenaUI.bind(b, callback);parent.add_child(b);return b

func _score() -> void:
	score_label.text = "적중 %d / %d   ·   연속 %d   ·   최고 연속 %d" % [hits, tries, streak, best]

## A fresh random situation (also the 새로고침 button). Nothing is picked yet.
func new_situation() -> void:
	if is_instance_valid(battle) and not battle.finished:return
	_clear_battle()
	state = PredictionRules.create(rng);state.picked_team = -1
	pick_page.show();watch_page.hide();result_page.hide();_render_pick()

func _render_pick() -> void:
	_score()
	section.text = "예측 상황 · " + PredictionRules.label(state)
	for child in teams_box.get_children():teams_box.remove_child(child);child.queue_free()
	PredictionTeamGrid.build(teams_box, state, state.picked_team, _pick)
	start_button.disabled = state.picked_team < 0
	start_button.text = "승리할 팀을 먼저 선택하세요" if state.picked_team < 0 else "%d팀에 걸고 관전하기" % (state.picked_team + 1)

func _pick(team: int) -> void:
	state.picked_team = team;call_deferred("_render_pick")

func start_watch() -> void:
	if state.picked_team < 0 or is_instance_valid(battle):return
	battle = BattleManager.new();battle.auto_start = false
	battle.common_combat_enabled = true;battle.full_characters_enabled = true;battle.team_colors = PredictionRules.TEAM_COLORS
	board = DeploymentBoard.new();board.editing = false;board.size_flags_vertical = Control.SIZE_EXPAND_FILL;board.custom_minimum_size.y = 240;watch_page.add_child(board);board.add_child(battle)
	if not battle.start_battle(PredictionRules.placements(state, rng), rng.randi_range(0, 1 << 30)):_clear_battle();return
	board.battle = battle
	var speeds := HBoxContainer.new();speeds.alignment = BoxContainer.ALIGNMENT_END;speeds.add_theme_constant_override("separation", 4);watch_page.add_child(speeds)
	var picked := Label.new();picked.text = "예측 · %d팀" % (state.picked_team + 1);picked.size_flags_horizontal = Control.SIZE_EXPAND_FILL;picked.add_theme_color_override("font_color", PredictionRules.team_color(state.picked_team));speeds.add_child(picked)
	speed_buttons.clear()
	for speed in [1, 2, 4]:
		var s := _button(speeds, "%d×" % speed, func():if is_instance_valid(battle):battle.clock.set_speed(float(speed)))
		s.toggle_mode = true;s.custom_minimum_size.x = 44;s.add_theme_font_size_override("font_size", 13);ArenaUI.quiet(s);speed_buttons[speed] = s
	fail_row = PredictionModeScreen.make_fail_row(watch_page, state.picked_team, quick_end)
	if battle_cue == null:battle_cue = BattleCueOverlay.new();battle_cue.subtitle = "예측한 팀이 이길까요?";add_child(battle_cue)
	battle_cue.board = board
	pick_page.hide();watch_page.show();result_page.hide()

func _clear_battle() -> void:
	if is_instance_valid(ending):ending.queue_free()
	ending = null
	for child in watch_page.get_children():watch_page.remove_child(child);child.queue_free()
	board = null;battle = null;speed_buttons.clear();fail_row = null

func _process(dt: float) -> void:
	if battle_cue != null:battle_cue.observe(battle, dt)
	for speed in speed_buttons:
		var choice: Button = speed_buttons[speed]
		choice.disabled = not is_instance_valid(battle) or battle.finished or battle.clock.state != BattleClock.State.NORMAL
		choice.set_pressed_no_signal(is_instance_valid(battle) and int(battle.clock.speed) == speed)
	if is_instance_valid(fail_row):fail_row.visible = PredictionModeScreen.picked_wiped(battle, state.picked_team)
	if not is_instance_valid(battle) or not battle.finished or result_page.visible:return
	var outcome: StringName = &"draw" if battle.result.draw else &"correct" if battle.result.winner_team == state.picked_team else &"incorrect"
	if ending == null:
		if board.presentation.battle != battle:board.presentation.attach(battle)
		ending = RetreatPresentation.new();add_child(ending)
		var sequence: BattleCinematicState = board.presentation.ensure_cinematic(battle.result.end_reason)
		sequence.kind = "prediction_success" if outcome == &"correct" else "prediction_draw" if outcome == &"draw" else "prediction_failure"
		ending.begin(sequence, board)
	if not ending.sequence.complete:return
	ending.queue_free();ending = null
	_show_result(outcome)

func _show_result(outcome: StringName) -> void:
	tries += 1
	if outcome == &"correct":hits += 1;streak += 1;best = maxi(best, streak)
	elif outcome == &"incorrect":streak = 0
	_score()
	for child in result_page.get_children():result_page.remove_child(child);child.queue_free()
	var picked: Array[int] = []
	for team in state.teams:
		if team.team == state.picked_team:picked.assign(team.types)
	var card := ResultCard.new();card.types = picked;card.types_caption = "예측한 팀 · %d팀" % (state.picked_team + 1)
	var winner: int = battle.result.winner_team
	if outcome == &"correct":card.icon = "crown";card.title = "예측 성공!";card.accent = ArenaUI.GOLD;card.detail = "%d팀의 승리를 맞혔습니다." % (state.picked_team + 1)
	elif outcome == &"draw":card.icon = "prediction";card.title = "무승부";card.accent = Color("9fb4d8");card.detail = "승부가 나지 않았습니다."
	else:card.icon = "skull";card.title = "예측 실패";card.accent = Color("ff8a8a");card.detail = "%d팀이 승리했습니다." % (winner + 1) if winner >= 0 else "예측한 %d팀이 전멸했습니다." % (state.picked_team + 1)
	card.chips.assign(["적중 %d / %d" % [hits, tries], "연속 %d" % streak])
	result_page.add_child(card)
	var row := HBoxContainer.new();row.alignment = BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation", 8);result_page.add_child(row)
	var numbers := _button(row, "통계", _open_stats);numbers.custom_minimum_size = Vector2(84, 52);ArenaUI.quiet(numbers)
	var next := _button(row, "다음 예측", new_situation);next.name = "Next";next.custom_minimum_size = Vector2(160, 52);ArenaUI.primary(next);ArenaUI.with_icon(next, "play", 14, true)
	pick_page.hide();watch_page.hide();result_page.show()

func _open_stats() -> void:
	if not is_instance_valid(battle) or battle.result == null:return
	if stats_dialog == null:stats_dialog = BattleStatsView.make_dialog(self)
	BattleStatsView.open(stats_dialog, self, battle.result.stats)

## True while the battle runs on after every unit of the picked team has fallen.
static func picked_wiped(manager: BattleManager, team: int) -> bool:
	return is_instance_valid(manager) and manager.started and not manager.finished and not manager.units.any(func(u):return u.alive and u.original_team == team)

## "예측 실패 · N팀 전멸" with a 빠른 종료 button, hidden until the picked team is wiped out.
static func make_fail_row(parent: Container, team: int, on_end: Callable) -> HBoxContainer:
	var row := HBoxContainer.new();row.name = "PredictionFailed";row.add_theme_constant_override("separation", 8);parent.add_child(row);row.hide()
	var box: StyleBoxFlat = ArenaUI.box(Color(ArenaUI.DANGER, .14), Color(ArenaUI.DANGER, .6));box.set_corner_radius_all(10);box.content_margin_left = 12;box.content_margin_right = 12
	var text := Label.new();text.text = "예측 실패 · %d팀 전멸" % (team + 1);text.size_flags_horizontal = Control.SIZE_EXPAND_FILL;text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_override("font", ArenaUI.heading_font());text.add_theme_font_size_override("font_size", 15);text.add_theme_color_override("font_color", ArenaUI.DANGER);text.add_theme_stylebox_override("normal", box);row.add_child(text)
	var end := Button.new();end.name = "QuickEnd";end.text = "빠른 종료";end.custom_minimum_size = Vector2(108, 44);ArenaUI.danger(end);ArenaUI.bind(end, on_end);row.add_child(end)
	return row

## 빠른 종료: ends the battle at once; the prediction has already failed.
func quick_end() -> void:
	if not PredictionModeScreen.picked_wiped(battle, state.picked_team):return
	battle.finish_with_reason(BattleEndReason.Value.DEFEAT, -1)
