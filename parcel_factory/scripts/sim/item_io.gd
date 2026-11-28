class_name ItemIO
extends RefCounted
## 물건(Item) 저장·불러오기. Item 안에서 자기 클래스를 부르면 Godot 4.3에서 끌 때 누수로
## 보고돼서 따로 뒀어요.


static func to_dict(it: Item) -> Dictionary:
	return {"id": it.id, "contents": it.contents.duplicate(), "request": it.request.duplicate(true), "cushion": it.cushion}


static func from_dict(d: Dictionary) -> Item:
	var it := Item.new(str(d.get("id", "")))
	for c in d.get("contents", []):
		it.contents.append(str(c))
	var req = d.get("request", {})
	if req is Dictionary and not req.is_empty():
		var items := {}
		for k in req.get("items", {}):
			items[str(k)] = int(req["items"][k])
		it.request = {"items": items, "fragile": bool(req.get("fragile", false)), "gift": bool(req.get("gift", false))}
	it.cushion = bool(d.get("cushion", false))
	return it
