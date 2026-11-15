class_name PassiveStrip
extends Control
## Battle HUD: a small icon for each passive card on in this battle, down the board's left edge.
## An icon flashes when its effect fires (BattlePassives.fire); a passive whose condition does not
## hold is dimmed. 지휘 깃발 also draws a small flag beside the turning-point clock (TurningPointPanel).
const ICON := 26.0
const FLASH := .9
var battle: BattleManager
var seen: Dictionary = {}
var flash: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE;z_index = 12

func _process(dt: float) -> void:
	var kinds: Array = BattlePassives.active(battle) if is_instance_valid(battle) and battle.started else []
	visible = not kinds.is_empty()
	if not visible:return
	var fired: Dictionary = battle.get_meta("passive_fired", {})
	for kind in fired:
		if float(fired[kind]) != float(seen.get(kind, -1.0)):seen[kind] = fired[kind];flash[kind] = 0.0 if GameSettings.motion else FLASH
	for kind in flash.keys():flash[kind] = float(flash[kind]) + dt
	custom_minimum_size = Vector2(ICON + 8, kinds.size() * (ICON + 6) + 4);size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(battle):return
	var y: float = 2
	for kind in BattlePassives.active(battle):
		var data: StrategyCardData = StrategyCardCatalog.get_card(kind)
		var on: bool = BattlePassives.condition_holds(battle, data)
		var at := Vector2(4 + ICON * .5, y + ICON * .5)
		var f: float = clampf(1.0 - float(flash.get(kind, FLASH)) / FLASH, 0, 1)
		if f > 0:VfxArt.glow(self, at, ICON * (1.2 + f), ArenaUI.GOLD, .55 * f)
		draw_circle(at, ICON * .5, Color(.12, .09, .03, .85))
		draw_arc(at, ICON * .5, 0, TAU, 24, Color(StrategyCardArt.FRAME[&"passive"], 1.0 if on else .4), 1.5 + f * 2, true)
		ArenaIcon.draw(self, at, String(kind), ICON * (.72 + .18 * f), Color(1, 1, 1, 1.0 if on else .35))
		y += ICON + 6
