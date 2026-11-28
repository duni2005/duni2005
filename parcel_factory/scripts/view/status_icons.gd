extends RefCounted
## 설비 상태 한 곳에서 판단: 월드의 상태 아이콘(marker_layer)과 정보창(info_panel)이 같이 써요.
## 시뮬레이션 상태는 읽기만 해요. 아이콘 이름은 SpriteGen.UI_ICONS (8×8).
##   check 작동 중 · empty 재료 부족(빈 상자) · blocked 출력 막힘(빨간 화살표) · bolt_red 전력 없음
##   bolt 전력 부족(노랑) · question 레시피 없음 · drop 물 부족 · "" 표시할 것 없음

const RUNNING := "check"


static func classify(b) -> Dictionary:
	## {icon, color(팔레트 번호), text}
	var s: String = b.status
	if b is Machine and b.recipe == null and not b.available_recipes().is_empty():
		return _r("question", Palette.YELLOW, "레시피를 골라요")
	if b is Generator:
		return _r(RUNNING, Palette.GREEN, "가동 중") if b.running() else _r("empty", Palette.YELLOW, "연료 없음")
	if b is Pump:
		if b.water_supply() <= 0.0 or b.water_net == null:
			return _r("drop", Palette.RED, s if s != "" else "물 없음")
		return _r(RUNNING, Palette.GREEN, s)
	if b.needs_power() and b.power_net == null and _wants_work(b, s):
		return _r("bolt_red", Palette.RED, "전력 연결 안 됨")
	if b.needs_power() and b.power_mult() <= 0.0 and s.find("전력") >= 0:
		return _r("bolt_red", Palette.RED, "전력 없음")
	if b is Injector and s.find("물") >= 0:
		if b.water_net == null or float(b.water_net["sat"]) <= 0.0:
			return _r("drop", Palette.RED, "물 부족")
		return _r("bolt_red", Palette.RED, "전력 없음")
	if s.find("막힘") >= 0:
		return _r("blocked", Palette.RED, "출력 막힘")
	if b.is_active():
		if b.needs_power() and b.power_mult() < 1.0:
			return _r("bolt", Palette.YELLOW, "작동 중 (전력 부족)")
		return _r(RUNNING, Palette.GREEN, "작동 중")
	if s.find("기다") >= 0 or s.find("재료") >= 0 or s.find("모자라") >= 0:
		return _r("empty", Palette.YELLOW, "재료 부족")
	if s.find("레시피") >= 0:
		return _r("question", Palette.YELLOW, "레시피를 골라요")
	return _r("", Palette.G4, s if s != "" else "대기")


static func progress(b) -> float:
	## 레시피·작업 진행 0~1 (진행이 없는 설비는 -1)
	if b is Machine and b.recipe != null:
		return clampf(b.progress / float(b.recipe["t"]), 0.0, 1.0)
	if b is Packer or b is Combiner or b is GiftPacker:
		return clampf(b.t / float(b.def.get("time", 1.0)), 0.0, 1.0)
	if b is Injector:
		return clampf(b.fill_t / float(b.def.get("time", 6.0)), 0.0, 1.0)
	return -1.0


static func _wants_work(b, s: String) -> bool:
	## 전력이 연결 안 된 것만으로 '문제'인지: 할 일이 있을 때만 (빈 감지기 등은 조용히)
	return s != "" or b is Machine


static func _r(icon: String, col: int, text: String) -> Dictionary:
	return {"icon": icon, "color": col, "text": text}
