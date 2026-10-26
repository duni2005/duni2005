class_name PromotionDialog
extends AcceptDialog
## Promotion window: pick a lead and two materials of the same character and star rank. The rules
## are explained up front, but the resulting level is only revealed after promoting.
signal promoted(event: Dictionary)
var controller: TowerController
var lead_id: String = ""
var materials: Array[String] = []
var slots: HBoxContainer
var grid: GridContainer
var count: Label
var note: Label
var confirm: Button
var info: Label

func _ready() -> void:
	theme = ArenaUI.get_theme();title = "승급"
	var column := VBoxContainer.new();column.add_theme_constant_override("separation", 8);add_child(column)
	ArenaUI.dialog_header(self, column, "승급")
	info = Label.new();info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;info.add_theme_font_size_override("font_size", 11);info.add_theme_color_override("font_color", ArenaUI.MUTED)
	info.text = "같은 캐릭터·같은 성급의 생존 유닛 3명으로 승급합니다. 주 유닛은 남아 성급이 오르고, 재료 2명은 사라집니다.\n세 유닛의 경험치는 합쳐지고 승급 보너스가 더해집니다. 재료의 장비는 주 유닛의 빈 칸에 장착되고, 남는 장비는 인벤토리로 돌아갑니다."
	column.add_child(info)
	slots = HBoxContainer.new();slots.alignment = BoxContainer.ALIGNMENT_CENTER;column.add_child(slots)
	var scroll := ScrollContainer.new();scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	grid = GridContainer.new();grid.columns = 3;grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL;scroll.add_child(grid)
	note = Label.new();note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;note.add_theme_font_size_override("font_size", 11);column.add_child(note)
	var footer := HBoxContainer.new();column.add_child(footer)
	count = Label.new();count.size_flags_horizontal = Control.SIZE_EXPAND_FILL;count.add_theme_font_size_override("font_size", 12);footer.add_child(count)
	confirm = Button.new();confirm.name = "Promote";confirm.text = "승급";confirm.custom_minimum_size = Vector2(112, 44);ArenaUI.primary(confirm);ArenaUI.bind(confirm, _promote);footer.add_child(confirm)

## Opens with `member_id` as the lead when it can promote.
func open(member_id: String) -> void:
	lead_id = member_id if controller.content.promotion_eligible(controller.guild.get_member(member_id)) else ""
	materials.clear();note.text = ""
	_render()
	# Sized from the screen, not the guild window this dialog lives in. Wrapped labels get their
	# width first; the first layout pass still over-grows the window, so the size is set again.
	var view: Vector2 = get_tree().root.get_visible_rect().size;var target := Vector2i(mini(440, int(view.x) - 24), mini(660, int(view.y) - 40))
	for label in [info, note]:label.custom_minimum_size.x = target.x - 36
	popup_centered(target);_settle.call_deferred(target)

func _settle(target: Vector2i) -> void:
	await get_tree().process_frame
	if visible:size = target;move_to_center()

func _pick(member_id: String) -> void:
	if member_id == lead_id:lead_id = "";materials.clear()
	elif member_id in materials:materials.erase(member_id)
	elif lead_id.is_empty():lead_id = member_id
	elif materials.size() < 2:materials.append(member_id)
	call_deferred("_render")

func _matches(member: GuildMemberState) -> bool:
	var lead: GuildMemberState = controller.guild.get_member(lead_id)
	if lead == null:return controller.content.promotion_eligible(member)
	return member.member_id == lead_id or member.unit_type_id == lead.unit_type_id and member.stars == lead.stars

func _render() -> void:
	var guild: GuildManager = controller.guild;var lead: GuildMemberState = guild.get_member(lead_id)
	for node in [slots, grid]:
		for child in node.get_children():node.remove_child(child);child.queue_free()
	var picked: Array = [lead_id] + materials
	for i in range(3):
		var slot := ArenaCard.new();slot.card_type = "promotion_slot";slot.custom_minimum_size = Vector2(56, 62);slot.type_id = -1;slot.subtitle = "주 유닛" if i == 0 else "재료"
		var member: GuildMemberState = guild.get_member(picked[i]) if i < picked.size() else null
		if member != null:slot.type_id = member.unit_type_id;ArenaUI.bind(slot, _pick.bind(member.member_id))
		else:slot.disabled = true
		slots.add_child(slot)
	var arrow := Label.new();arrow.text = "→";slots.add_child(arrow)
	var result := ArenaCard.new();result.card_type = "promotion_slot";result.custom_minimum_size = Vector2(62, 62);result.disabled = true
	result.type_id = lead.unit_type_id if lead != null else -1;result.subtitle = "★%d" % (lead.stars + 1) if lead != null else "승급";slots.add_child(result)
	# Only units that can take part: any promotable unit, or once a lead is chosen, its matches.
	for member in guild.living_members().filter(func(m):return _matches(m) and controller.content.promotion_eligible(m)):
		var role: String = "주 유닛" if member.member_id == lead_id else "재료" if member.member_id in materials else ""
		var c := ArenaCard.new();c.name = member.member_id;c.card_type = "promotion_member";c.type_id = member.unit_type_id;c.title = guild.definition(member.unit_type_id).display_name
		c.subtitle = "%s%s · Lv.%d" % [ArenaUI.member_label(member.member_id), " ★%d" % member.stars if member.stars > 0 else "", member.level];c.hp = member.current_hp;c.hp_max = guild.member_max_hp(member)
		c.show_member(guild, member);c.status_text = role if not role.is_empty() else "선택";c.toggle_mode = true;c.set_pressed_no_signal(not role.is_empty())
		c.disabled = role.is_empty() and not lead_id.is_empty() and materials.size() >= 2
		c.custom_minimum_size = Vector2(0, 162);c.size_flags_horizontal = Control.SIZE_EXPAND_FILL;ArenaUI.bind(c, _pick.bind(member.member_id));grid.add_child(c)
	count.text = "%d / 3명 선택" % picked.filter(func(id):return not id.is_empty()).size()
	confirm.disabled = lead == null or materials.size() != 2 or not controller.content.can_manage()
	if grid.get_child_count() == 0:note.text = "승급할 수 있는 유닛이 없습니다. 같은 캐릭터·같은 성급의 생존 유닛 3명이 필요합니다."

func _promote() -> void:
	var outcome: Dictionary = controller.content_action(&"promote", {"member_id":lead_id, "materials":materials.duplicate()})
	if not outcome.ok:note.text = "승급 불가 · " + String(outcome.code);note.add_theme_color_override("font_color", ArenaUI.DANGER);return
	var member: GuildMemberState = controller.guild.get_member(outcome.outcome.member_id);var point: Vector2 = ArenaUI.control_center(confirm)
	hide()
	# The result (new level included) is revealed only now, by the promotion cutscene.
	promoted.emit({"kind":"promotion", "key":"promote:%s:%d" % [member.member_id, member.stars], "title":controller.guild.definition(member.unit_type_id).display_name, "type":member.unit_type_id, "stars":member.stars, "slots":GuildMemberCombatStats.equipment_limit(member), "level":member.level, "point":point})
