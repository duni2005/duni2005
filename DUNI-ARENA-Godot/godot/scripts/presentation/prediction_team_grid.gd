class_name PredictionTeamGrid
extends RefCounted
## 전투 예측 team choices: one column for up to three teams (and four big squads), two columns for
## four to six, so the page never needs scrolling. Shared by the tower event and the 전투 예측 mode.

## "궁수 ×3 · 전사" style names for a team.
static func names(types: Array) -> String:
	var order: Array = [];var counts: Dictionary = {}
	for t in types:
		if not counts.has(t):order.append(t)
		counts[t] = int(counts.get(t, 0)) + 1
	return " · ".join(order.map(func(t):return CharacterCatalog.all()[t].display_name + (" ×%d" % counts[t] if counts[t] > 1 else "")))

## A prediction unit's sheet: its stats with its items, and a 상태 tab at full HP.
static func open_unit(host: Node, team: Dictionary, index: int) -> UnitInfoSheet:
	var type: int = team.types[index];var items: Array = team.get("items", [])[index] if index < team.get("items", []).size() else []
	var stats: UnitCombatStats = PredictionRules.stats_for(type, items)
	var unit := GuildMemberState.new();unit.unit_type_id = type;unit.current_hp = stats.max_hp
	return UnitInfoSheet.open(host, type, stats, null, unit)
static func build(parent: Container, state: PredictionState, picked: int, on_pick: Callable) -> GridContainer:
	# Four teams of big squads get one wide card each so their portraits stay readable.
	var biggest: int = state.teams.map(func(t):return t.types.size()).max()
	var grid := GridContainer.new();grid.columns = 1 if state.teams.size() <= 3 or state.teams.size() == 4 and biggest > 5 else 2
	grid.add_theme_constant_override("h_separation", 6);grid.add_theme_constant_override("v_separation", 6);parent.add_child(grid)
	for team in state.teams:
		var card := ArenaCard.new();card.name = "team_%d" % team.team
		card.text = "%d팀\n%s" % [team.team + 1, names(team.types)];card.card_type = "prediction_team";card.title = "%d팀" % (team.team + 1);card.kind = "battle"
		card.description = names(team.types);card.portrait_types.assign(team.types);card.team_tint = PredictionRules.team_color(team.team)
		card.portrait_items = team.get("items", []);card.team_power = PredictionRules.team_power(team)
		card.custom_minimum_size.y = 70 if grid.columns == 1 else 66;card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true;card.selected = picked == team.team;card.set_pressed_no_signal(card.selected)
		# On the chosen team's card a portrait opens that unit's sheet (its items in 상태).
		var row: Dictionary = team
		# Where the press landed, in card coordinates (touch or mouse).
		card.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:card.set_meta("press_at", e.position))
		ArenaUI.bind(card, func():
			var index: int = card.portrait_at(card.get_meta("press_at", Vector2(-1, -1)))
			if card.selected and index >= 0:card.set_pressed_no_signal(true);open_unit(card, row, index);return
			on_pick.call(row.team));grid.add_child(card)
	return grid
