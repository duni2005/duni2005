class_name ItemRewards
extends RefCounted
## Rolls items from the shared grade table (ItemTuning.FLOOR_ODDS): a grade first, then an item
## of that grade, evenly. 전설 the run already owns never shows again, 고대 never in the tower, and
## one roll of several items never repeats an item.

## Grade odds (%) for a 0-based floor index, grades below `min_grade` cut out (the rest keep
## their ratio).
static func odds(floor_index: int,min_grade: StringName=&"common") -> Dictionary:
	var floor_number: int=clampi(floor_index+1,1,15);var row: Dictionary=ItemTuning.FLOOR_ODDS[0]
	for candidate in ItemTuning.FLOOR_ODDS:
		if floor_number>=int(candidate.floors[0]) and floor_number<=int(candidate.floors[1]):row=candidate
	var out: Dictionary={};var lowest: int=ItemTuning.GRADES.find(min_grade)
	for grade in [&"common",&"rare",&"epic",&"legendary"]:
		if ItemTuning.GRADES.find(grade)>=lowest:out[grade]=float(row.get(String(grade),0))
	return out
## Legendary items still unowned this run (owned = in the inventory, worn or not).
static func owned_legendaries(run: RunState) -> Array:
	var out: Array=[]
	for item in run.inventory:
		if not item.consumed and ItemCatalog.grade_of(item.kind)==&"legendary":out.append(item.kind)
	return out
## `count` different items rolled with `grade_odds`. Grades that have run out of candidates are
## skipped (their share goes to the others); fewer items come back only when nothing is left.
static func roll(rng: RandomNumberGenerator,grade_odds: Dictionary,count: int=1,exclude: Array=[]) -> Array[StringName]:
	var out: Array[StringName]=[]
	for i in range(count):
		var pools: Dictionary={};var total: float=0
		for grade in grade_odds:
			if grade==&"ancient":continue
			var pool: Array=ItemCatalog.POOLS[grade].filter(func(k):return not k in out and not k in exclude)
			if pool.is_empty() or float(grade_odds[grade])<=0:continue
			pools[grade]=pool;total+=float(grade_odds[grade])
		if pools.is_empty():break
		var pick: float=rng.randf()*total;var grade: StringName=pools.keys().back()
		for g in pools:
			pick-=float(grade_odds[g])
			if pick<0:grade=g;break
		var pool: Array=pools[grade];out.append(pool[rng.randi_range(0,pool.size()-1)])
	return out
## One item from the floor table for this run (owned 전설 excluded).
static func one(rng: RandomNumberGenerator,run: RunState,floor_index: int,min_grade: StringName=&"common") -> StringName:
	var picked: Array[StringName]=roll(rng,odds(floor_index,min_grade),1,owned_legendaries(run))
	return picked[0] if not picked.is_empty() else &"warmNecklace"
