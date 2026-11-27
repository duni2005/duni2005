class_name Turret
extends Building
## 터렛 (샌드박스용): 생물이 없어서 탄약만 받아 두고 전력만 써요.

var ammo := 0


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	var a: String = def.get("ammo", "")
	if a == "" or it.id != a or ammo >= 20:
		return false
	ammo += 1
	return true


func power_demand() -> float:
	return float(def.get("power", 0.0))


func info() -> String:
	var a: String = def.get("ammo", "")
	return super.info() + ("\n탄약 %d/20" % ammo if a != "" else "\n탄약 없음 (전력형)")
