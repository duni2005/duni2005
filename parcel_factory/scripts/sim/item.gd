class_name Item
extends RefCounted
## 레일 위를 움직이는 물건 하나.
## 박스·택배는 내용물(contents)과 요청(request)을 함께 들고 다녀요.

var id: String = ""
var contents: Array = []       # 박스·택배 안의 물건 이름들
var request: Dictionary = {}   # {"items": {이름: 개수}, "fragile": bool, "gift": bool}
var cushion: bool = false      # 완충재가 들어갔는지


func _init(p_id: String = "") -> void:
	id = p_id


func is_plain() -> bool:
	return contents.is_empty() and request.is_empty() and not cushion


func has_request() -> bool:
	return not request.is_empty()


func capacity() -> int:
	return int(DB.box_capacity.get(id, 0))


func count_of(n: String) -> int:
	var c := 0
	for x in contents:
		if x == n:
			c += 1
	return c


func need_of(n: String) -> int:
	## 요청서 기준으로 이 물건이 몇 개 더 필요한지
	if request.is_empty():
		return 0
	var want: int = int(request["items"].get(n, 0))
	return maxi(0, want - count_of(n))


func request_done() -> bool:
	## 요청과 내용물이 정확히 같은지 (더 많거나 다른 물건이 있으면 실패)
	if request.is_empty():
		return false
	var want: Dictionary = request["items"]
	var total := 0
	for n in want:
		if count_of(n) != int(want[n]):
			return false
		total += int(want[n])
	if contents.size() != total:
		return false
	if request.get("fragile", false) and not cushion:
		return false
	return true


func sale_ready() -> bool:
	## 요청서 없는 박스에 같은 온전한 물건 4개가 들었는지
	if not request.is_empty() or contents.size() != 4:
		return false
	var first: String = contents[0]
	if not DB.sale_map.has(first):
		return false
	for x in contents:
		if x != first:
			return false
	return true


func copy_payload_from(other: Item) -> void:
	contents = other.contents.duplicate()
	request = other.request.duplicate(true)
	cushion = other.cushion


func describe() -> String:
	var s := id
	if not request.is_empty():
		var parts := []
		for n in request["items"]:
			parts.append("%s %d" % [n, int(request["items"][n])])
		s += "\n  요청: " + ", ".join(parts)
		if request.get("fragile", false):
			s += " (깨지기 쉬움)"
		if request.get("gift", false):
			s += " (선물용)"
	if not contents.is_empty():
		s += "\n  내용물: " + ", ".join(contents)
	if cushion:
		s += "\n  완충재 있음"
	return s
