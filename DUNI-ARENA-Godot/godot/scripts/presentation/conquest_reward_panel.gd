class_name ConquestRewardPanel
extends VBoxContainer
## Read-only floor progress/rewards. Opening this view cannot grant a reward.
var title_label: Label
var progress_label: Label
var percent_label: Label
var progress: ProgressBar
var rewards: VBoxContainer
var status_label: Label
var unlock_label: Label
func _ready() -> void:
	add_theme_constant_override("separation",14)
	var row:=HBoxContainer.new();add_child(row)
	progress_label=Label.new();progress_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(progress_label)
	percent_label=Label.new();percent_label.add_theme_color_override("font_color",ArenaUI.HP);row.add_child(percent_label)
	progress=ProgressBar.new();progress.custom_minimum_size.y=8;progress.show_percentage=false;progress.add_theme_stylebox_override("background",ArenaUI.box(Color("26304a"),Color.TRANSPARENT));progress.add_theme_stylebox_override("fill",ArenaUI.box(Color("b6dc8e"),Color.TRANSPARENT));add_child(progress)
	rewards=VBoxContainer.new();rewards.add_theme_constant_override("separation",8);add_child(rewards)
	status_label=Label.new();status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status_label.add_theme_font_size_override("font_size",12);add_child(status_label)
	unlock_label=Label.new();unlock_label.custom_minimum_size.x=260;unlock_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;unlock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;unlock_label.add_theme_font_size_override("font_size",11);unlock_label.add_theme_color_override("font_color",Color("95a98d"));add_child(unlock_label)
func set_floor(floor: FloorState) -> void:
	progress_label.text="%d / %d방 정복"%[floor.cleared_count,floor.room_ids.size()]
	progress.value=100.0*floor.cleared_count/maxi(1,floor.room_ids.size());percent_label.text="%d%%"%roundi(progress.value)
	for child in rewards.get_children():rewards.remove_child(child);child.queue_free()
	_reward("heart","플레이어 HP +10%")
	_reward("energy","모든 유닛 기력 +1")
	var bonus: String={&"heal":"모든 유닛 HP +20%",&"tokens":"토큰 +2",&"item":"무작위 아이템 1개"}.get(floor.bonus,"추가 보상")
	_reward("supply" if floor.bonus==&"item" else "gem" if floor.bonus==&"tokens" else "heal",bonus,true)
	status_label.text="✓ 보상 지급 완료" if floor.conquered else "모든 방 정복 시 자동 지급";status_label.add_theme_color_override("font_color",ArenaUI.HP if floor.conquered else Color("c3ceba"))
	unlock_label.text="다음 층 해금: %d방 클리어%s"%[floor.required_clear_count," · 보스 격파 필요" if floor.floor_index%5==4 else ""]
func _reward(icon: String,text: String,extra: bool=false) -> void:
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",ArenaUI.box(Color("1f2a44"),Color("3a4a72")));rewards.add_child(panel)
	var row:=HBoxContainer.new();row.custom_minimum_size.y=38;panel.add_child(row)
	var image:=TextureRect.new();image.texture=ArenaIcon.texture(icon);image.custom_minimum_size=Vector2(25,25);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(image)
	var label:=Label.new();label.text=text;label.custom_minimum_size.x=158;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",13);row.add_child(label)
	if extra:
		var hint:=Label.new();hint.text="추가 보상";hint.add_theme_font_size_override("font_size",10);hint.add_theme_color_override("font_color",ArenaUI.GOLD);row.add_child(hint)
