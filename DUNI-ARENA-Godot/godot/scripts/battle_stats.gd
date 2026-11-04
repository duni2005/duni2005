class_name BattleStats
extends RefCounted
## Per-unit battle totals for the result screen's 통계 page: damage dealt / taken (HP plus shield),
## healing done / received, kills and ultimates cast. Units born mid-fight (슬라임 분열) add to the
## row of the unit they split from, and a row's kill only counts once its whole family is down.
const METRICS: Array[StringName] = [&"dealt", &"taken", &"healed", &"heal_received", &"kills", &"ultimates"]
const LABELS: Dictionary = {&"dealt": "가한 피해", &"taken": "받은 피해", &"healed": "가한 치유", &"heal_received": "받은 치유", &"kills": "처치", &"ultimates": "궁극기"}
var rows: Dictionary = {} # row id -> totals
var owner: Dictionary = {} # battle_id -> row id

func register(u, parent = null) -> void:
	if parent != null and owner.has(parent.battle_id):
		owner[u.battle_id] = owner[parent.battle_id];return
	owner[u.battle_id] = u.battle_id
	rows[u.battle_id] = {"type": u.data.type_id, "name": u.data.display_name, "team": u.original_team, "color": u.team_color(), "dealt": 0.0, "taken": 0.0, "healed": 0.0, "heal_received": 0.0, "kills": 0, "ultimates": 0}

func _row(u):
	if u == null or not is_instance_valid(u) or not owner.has(u.battle_id):return null
	return rows[owner[u.battle_id]]

func damage(source, target, amount: float) -> void:
	if amount <= 0:return
	var hit = _row(target)
	if hit != null:hit.taken += amount
	var by = _row(source)
	if by != null and source != target:by.dealt += amount

func heal(source, target, amount: float) -> void:
	if amount <= 0:return
	var got = _row(target)
	if got != null:got.heal_received += amount
	var by = _row(source)
	if by != null:by.healed += amount

func kill(source, victim) -> void:
	var by = _row(source)
	if by == null or source == victim or not owner.has(victim.battle_id):return
	var family = owner[victim.battle_id]
	for v in victim.battle.units:
		if v != victim and v.alive and owner.get(v.battle_id) == family:return
	by.kills += 1

func ultimate(u) -> void:
	var row = _row(u)
	if row != null:row.ultimates += 1

## Detached rows for the result: each with its group label and whether any of its family survived.
func snapshot(battle) -> Array:
	var out: Array = []
	for id in rows:
		var row: Dictionary = rows[id].duplicate()
		row["alive"] = battle.units.any(func(v):return v.alive and owner.get(v.battle_id) == id)
		var team: int = int(row.team)
		if battle.custom_mode:row["group"] = "개인" if team >= CustomBattleSetup.SOLO_FACTION_BASE else CustomBattleSetup.TEAM_NAMES.get(team, "팀") + " 팀"
		else:row["group"] = "아군" if team == 0 else "적"
		out.append(row)
	out.sort_custom(func(a, b):return a.team < b.team if a.team != b.team else a.dealt > b.dealt)
	return out
