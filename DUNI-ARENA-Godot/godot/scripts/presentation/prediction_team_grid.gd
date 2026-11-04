class_name PredictionTeamGrid
extends RefCounted
## 전투 예측 team choices: one column for up to three teams, two columns for four or five, so the
## page never needs scrolling. Shared by the tower event and the 전투 예측 mode.

## "궁수 ×3 · 전사" style names for a team.
static func names(types: Array) -> String:
	var order: Array = [];var counts: Dictionary = {}
	for t in types:
		if not counts.has(t):order.append(t)
		counts[t] = int(counts.get(t, 0)) + 1
	return " · ".join(order.map(func(t):return CharacterCatalog.all()[t].display_name + (" ×%d" % counts[t] if counts[t] > 1 else "")))

static func build(parent: Container, state: PredictionState, picked: int, on_pick: Callable) -> GridContainer:
	var grid := GridContainer.new();grid.columns = 1 if state.teams.size() <= 3 else 2
	grid.add_theme_constant_override("h_separation", 6);grid.add_theme_constant_override("v_separation", 6);parent.add_child(grid)
	for team in state.teams:
		var card := ArenaCard.new();card.name = "team_%d" % team.team
		card.text = "%d팀\n%s" % [team.team + 1, names(team.types)];card.card_type = "prediction_team";card.title = "%d팀" % (team.team + 1);card.kind = "battle"
		card.description = names(team.types);card.portrait_types.assign(team.types);card.team_tint = PredictionRules.team_color(team.team)
		card.custom_minimum_size.y = 70 if grid.columns == 1 else 66;card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.toggle_mode = true;card.selected = picked == team.team;card.set_pressed_no_signal(card.selected)
		ArenaUI.bind(card, on_pick.bind(team.team));grid.add_child(card)
	return grid
