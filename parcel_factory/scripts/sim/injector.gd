class_name Injector
extends Conveyor
## 주입기: 레일 위에 놓고 파이프를 이어요.
## 지나가는 양동이는 물 양동이로, 페트병은 생수로 채워요 (6초).

const FILL := {"양동이": "물 양동이", "페트병": "생수"}
var fill_t := 0.0


func _init_state() -> void:
	speed = 2.0


func accepts_from(from_cell: Vector2i) -> bool:
	return from_cell == back_cell()


func water_demand() -> float:
	return float(def.get("water", 10.0)) if (item != null and FILL.has(item.id)) else 0.0


func power_demand() -> float:
	return float(def.get("power", 0.0)) if (item != null and FILL.has(item.id)) else 0.0


func tick(dt: float) -> void:
	if item != null and FILL.has(item.id):
		var w: float = water_net["sat"] if water_net != null else 0.0
		var m := power_mult() * w
		if m <= 0.0:
			status = "물 또는 전력 부족"
			return
		fill_t += dt * m
		status = "채우는 중 %d%%" % int(fill_t / def.get("time", 6.0) * 100.0)
		if fill_t >= float(def.get("time", 6.0)):
			fill_t = 0.0
			item.id = FILL[item.id]
		return
	status = ""
	super.tick(dt)
