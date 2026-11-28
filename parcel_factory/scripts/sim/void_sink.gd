class_name VoidSink
extends Building
## 소각기 (크리에이티브): 들어온 물건을 없애고 종류별로 세요.

const ACTIVE_SEC := 0.5   # 마지막으로 받은 뒤 이만큼은 '타는 중'
var counts := {}
var total := 0
var _recent := 0.0


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	counts[it.id] = counts.get(it.id, 0) + 1
	total += 1
	_recent = ACTIVE_SEC
	return true


func tick(dt: float) -> void:
	_recent = maxf(0.0, _recent - dt)


func is_active() -> bool:
	return _recent > 0.0


func info() -> String:
	var parts := []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	return super.info() + "\n없앤 수 %d\n%s" % [total, ", ".join(parts)]
