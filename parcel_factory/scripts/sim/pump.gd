class_name Pump
extends Building
## 펌프: 물 샘 위에서만 물 60/분을 파이프망에 보내요.


func on_water() -> bool:
	return factory.water.has(pos)


func power_demand() -> float:
	return float(def.get("power", 0.0)) if on_water() else 0.0


func water_supply() -> float:
	if not on_water():
		return 0.0
	return 60.0 * power_mult()


func tick(_dt: float) -> void:
	if not on_water():
		status = "물 샘 위에 놓아야 해요"
	elif water_net == null:
		status = "파이프가 연결 안 됨"
	else:
		status = "물 %d/분" % int(water_supply())
