extends Node2D
## Read-only debug presentation, driven by signals plus a separate UI frame loop.

@onready var battle: BattleManager = $Battle
@onready var status: Label = $HUD/Status

func _ready() -> void:
	battle.battle_finished.connect(_show_result)
	if battle.finished:
		_show_result(battle.result)

func _process(_delta: float) -> void:
	if not battle.finished:
		var living: int = 0
		for unit in battle.units:
			living += int(unit.alive)
		status.text = "1×  |  %.1f s  |  Alive %d / %d" % [battle.clock.elapsed, living, battle.units.size()]

func _show_result(final: BattleResult) -> void:
	var outcome: String = "DRAW" if final.draw else "BLUE WINS" if final.winner_team == 0 else "RED WINS"
	status.text = "%s  |  %.1f s  |  %d survivors  |  Simulation stopped" % [outcome, final.elapsed, final.survivors.size()]
