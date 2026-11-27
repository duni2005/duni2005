class_name VoidSink
extends Building
## 소각기 (크리에이티브): 들어온 물건을 없애고 종류별로 세요.

var counts := {}
var total := 0


func try_insert(it: Item, _from_cell: Vector2i) -> bool:
	counts[it.id] = counts.get(it.id, 0) + 1
	total += 1
	return true


func info() -> String:
	var parts := []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	return super.info() + "\n없앤 수 %d\n%s" % [total, ", ".join(parts)]
