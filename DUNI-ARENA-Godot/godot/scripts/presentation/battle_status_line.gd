class_name BattleStatusLine
extends Label
var battle: BattleManager
var combat_active: bool=false
var spectator_paused: bool=false
func _ready() -> void:
	add_theme_font_size_override("font_size",1);add_theme_color_override("font_color",Color.TRANSPARENT);custom_minimum_size.y=26;mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_dt: float) -> void:queue_redraw()
func _draw() -> void:
	var font: Font=get_theme_default_font()
	if combat_active and is_instance_valid(battle) and not battle.finished:
		var allies: int=battle.units.filter(func(u):return u.alive and u.original_team==0).size();var enemies: int=battle.units.filter(func(u):return u.alive and u.original_team==1).size()
		tooltip_text="생존 아군 %d / 적 %d"%[allies,enemies]
		draw_string(font,Vector2(0,18),"일시정지" if spectator_paused else "전투 중",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c6dfce"))
		draw_string(ArenaUI.numbers_font(),Vector2(size.x-80,23),"%02d:%02d"%[int(battle.clock.elapsed)/60,int(battle.clock.elapsed)%60],HORIZONTAL_ALIGNMENT_RIGHT,80,27,Color("edf1ef"))
	else:draw_string(font,Vector2(0,18),text,HORIZONTAL_ALIGNMENT_LEFT,size.x,11,ArenaUI.MUTED)
