class_name TowerFailure
extends CanvasLayer
## "타워 정복 실패": the end of a run (player HP 0, no living guild member, or abandon).
## The screen drains to grey, slanted panels close in, "FAILED" drifts large behind and the title
## comes down heavily letter by letter. A tap skips straight to the three choices:
## 결과 확인 (run summary), 메인화면 and 다시하기.
signal main_menu
signal retry
## Seconds before the choices appear by themselves.
const REVEAL: float = 2.2
var controller: TowerController
var cover: Control
var choices: VBoxContainer
var summary: PanelContainer
var summary_label: Label
var age: float = 0
var reason: String = ""

static func reason_text(run: RunState) -> String:
	if run.game_over_reason == RunState.GameOverReason.ABANDON:return "탐험을 포기했습니다"
	if run.player_hp <= 0:return "플레이어 HP가 모두 소진되었습니다"
	return "살아 있는 길드원이 없습니다"

func open(run_controller: TowerController) -> void:
	controller = run_controller;reason = reason_text(controller.guild.state)
	BackgroundMusic.play_after_silence(&"defeat")
	if not UiMotion.enabled:age = REVEAL
	_show_choices(not UiMotion.enabled)

func _ready() -> void:
	layer = 1150
	cover = Control.new();cover.theme = ArenaUI.get_theme();cover.mouse_filter = Control.MOUSE_FILTER_STOP;cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(cover)
	cover.draw.connect(_paint);cover.gui_input.connect(_skip)
	choices = VBoxContainer.new();choices.add_theme_constant_override("separation",10);cover.add_child(choices)
	choices.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);choices.grow_horizontal = Control.GROW_DIRECTION_BOTH;choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	choices.custom_minimum_size.x = 260;choices.offset_left = -130;choices.offset_right = 130;choices.offset_bottom = -64
	for row in [["결과 확인","flag",_open_summary],["메인화면","home",func():main_menu.emit()],["다시하기","reengrave",func():retry.emit()]]:
		var button := Button.new();button.text = row[0];button.name = row[0];button.custom_minimum_size.y = 52;button.add_theme_font_override("font",ArenaUI.heading_font());button.add_theme_font_size_override("font_size",17)
		ArenaUI.with_icon(button,row[1],18);ArenaUI.bind(button,row[2]);choices.add_child(button)
		if row[0] == "다시하기":ArenaUI.primary(button)
	choices.hide()
	_build_summary()

func _build_summary() -> void:
	summary = PanelContainer.new();summary.add_theme_stylebox_override("panel",ArenaUI.window_style());cover.add_child(summary)
	summary.set_anchors_and_offsets_preset(Control.PRESET_CENTER);summary.grow_horizontal = Control.GROW_DIRECTION_BOTH;summary.grow_vertical = Control.GROW_DIRECTION_BOTH;summary.custom_minimum_size.x = 300
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",12);summary.add_child(column)
	var title := Label.new();title.text = "탐험 결과";title.add_theme_font_override("font",ArenaUI.heading_font());title.add_theme_font_size_override("font_size",19);column.add_child(title)
	column.add_child(HSeparator.new())
	summary_label = Label.new();summary_label.add_theme_font_size_override("font_size",14);summary_label.add_theme_constant_override("line_spacing",6);column.add_child(summary_label)
	var close := Button.new();close.text = "닫기";close.custom_minimum_size.y = 46;ArenaUI.bind(close,func():summary.hide();choices.show());column.add_child(close)
	summary.hide()

## Run summary for 결과 확인.
func summary_text() -> String:
	var run: RunState = controller.guild.state;var tower: TowerRunState = run.tower
	return "사유 · %s\n도달 · 챕터 %d · %d층\n정복한 방 · %d곳\n남은 골드 · %s G   토큰 · %d\n길드원 · %d명 (생존 %d명)\n플레이어 HP · %d / %d" % [reason, tower.current_chapter, controller.current_floor() + 1, tower.cleared_rooms.size(), ArenaUI.grouped(run.gold), run.tokens, controller.guild.all_members().size(), controller.guild.living_members().size(), ceili(run.player_hp), ceili(run.player_max_hp)]

func _open_summary() -> void:
	summary_label.text = summary_text();choices.hide();summary.show();UiMotion.pop(summary,0,.94)

func _skip(event: InputEvent) -> void:
	if age < REVEAL and (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:age = REVEAL;_show_choices(false)

func _show_choices(at_once: bool) -> void:
	if age < REVEAL or choices.visible or summary.visible:return
	choices.show()
	if not at_once:
		for i in range(choices.get_child_count()):UiMotion.pop(choices.get_child(i),i * Motion.STAGGER,.92)

func _process(dt: float) -> void:
	var before: float = age;age += dt;cover.queue_redraw()
	if before < REVEAL and age >= REVEAL:_show_choices(false)

func _paint() -> void:
	var size: Vector2 = cover.size;var t: float = age;var screen := Rect2(Vector2.ZERO,size)
	# Drained, heavy backdrop: dark grey over everything, then a cold grey wash.
	var dim: float = Motion.out_quint(Motion.phase(t,0,.6))
	cover.draw_rect(screen,Color(.04,.045,.06,.93 * dim));cover.draw_rect(screen,Color(.4,.4,.43,.12 * dim))
	TypeArt.motes(cover,screen,t,Color(.7,.7,.72,.5 * dim),34,false,.1)
	var center := Vector2(size.x * .5,size.y * .36);var sink: float = Motion.out_quint(Motion.phase(t,.6,1.0)) * 10
	var font: Font = ArenaUI.heading_font();var title: String = "타워 정복 실패";var fs: int = int(clampf(size.x * .1,34,58))
	var strip := Rect2(0,center.y - fs * 1.05 + sink,size.x,fs * 2.1)
	TypeArt.panels(cover,strip,t * .8,false,[Color(.03,.03,.05,.85),Color("3a1a22"),Color(.05,.04,.06,.95)],99.0,Color("c06070"))
	var drift: float = Motion.out_quint(Motion.phase(t,.15,1.3))
	TypeArt.watermark(cover,"FAILED",center + Vector2(40 * (1 - drift),sink),int(fs * 2.2),Color(1,.45,.5,.12 * drift),-.22,14 * (1 - drift))
	var width: float = font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x;var at := Vector2(center.x - width * .5,center.y + fs * .36 + sink)
	TypeArt.letters(cover,font,title,at + Vector2(0,3),fs,Color(0,0,0,.55),t - .3,-fs * .7)
	TypeArt.letters(cover,font,title,at,fs,Color("ffb0b8"),t - .3,-fs * .7,Color(.08,.02,.04,.8))
	TypeArt.rule(cover,Vector2(center.x,center.y + fs + sink),width * .6 + 20,Motion.phase(t,.9,Motion.ENTER),Color("c06070"),2)
	var line_in: float = Motion.out_expo(Motion.phase(t,1.1,Motion.ENTER))
	cover.draw_string(ArenaUI.numbers_font(),Vector2(0,center.y - fs * 1.4 + sink),"TOWER CONQUEST FAILED",HORIZONTAL_ALIGNMENT_CENTER,size.x,15,Color(1,.7,.74,.8 * line_in))
	cover.draw_string(cover.get_theme_default_font(),Vector2(0,center.y + fs * 1.55 + sink + 8 * (1 - line_in)),reason,HORIZONTAL_ALIGNMENT_CENTER,size.x,15,Color(.86,.86,.9,line_in))
	if age < REVEAL:cover.draw_string(cover.get_theme_default_font(),Vector2(0,size.y - 18),"화면을 누르면 건너뜁니다  ",HORIZONTAL_ALIGNMENT_RIGHT,size.x,11,Color(1,1,1,.45))
