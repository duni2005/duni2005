class_name Generator
extends Building
## 발전기: 연료를 분당 fuel_rate개 태우며 전력 gen을 내요.
## 연료는 레일·입구로 넣어요 (최대 10개 보관).

var fuel := 0
var burn_left := 0.0


func fuel_item() -> String:
	return def.get("fuel", "")


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	if it.id != fuel_item() or not it.is_plain() or fuel >= 10:
		return false
	fuel += 1
	return true


func running() -> bool:
	return burn_left > 0.0


func power_supply() -> float:
	return float(def.get("gen", 0.0)) if running() else 0.0


func tick(dt: float) -> void:
	if burn_left > 0.0:
		burn_left -= dt
	# 다 탄 그 틱에 다음 연료를 넣어야 전력이 한 틱도 끊기지 않아요 (남은 시간은 이어 붙여요)
	if burn_left <= 0.0 and fuel > 0:
		fuel -= 1
		burn_left += 60.0 / float(def.get("fuel_rate", 1.0))
	if burn_left > 0.0:
		status = "가동 중 (+%d)" % int(def.get("gen", 0.0))
	else:
		status = "연료 없음"


func info() -> String:
	return super.info() + "\n연료: %s %d/10 (분당 %d개)" % [fuel_item(), fuel, int(def.get("fuel_rate", 0.0))]
