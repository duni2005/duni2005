class_name Art
extends RefCounted
## 도트 텍스처 창고. 기본 도트 16×16, 화면에는 2배(칸 32px)로 그려요.
## 텍스처를 찾는 순서
##   1. assets/sprites/<이름>.png  — 사람이 그린 교체용 (같은 이름·같은 배치로 넣으면 바로 바뀌어요)
##   2. assets/gen/<이름>.png      — tools/gen_assets.gd가 구워 둔 임시 도트
##   3. 코드로 즉석 생성 (SpriteGen)
## 시트 배치 규칙은 assets/sprite_gen.gd 맨 위 설명을 보세요.

const DOT := 16
const SCALE := 2
const OVERRIDE_DIR := "res://assets/sprites/"
const GEN_DIR := "res://assets/gen/"

## 설비 이름 -> 스프라이트 이름
const BUILDINGS := {
	"레일 Mk1": "rail_mk1", "레일 Mk2": "rail_mk2", "레일 Mk3": "rail_mk3",
	"출구": "exit", "입구": "entrance", "창고 블록": "storage", "분류기": "sorter",
	"분배기": "splitter", "병합기": "merger", "레일 다리": "bridge",
	"출하대": "shelf", "포장기": "packer", "요청 결합기": "combiner", "요청 감지기": "detector",
	"완료 판정기": "judge", "출하 도크": "dock", "선물 포장기": "gift_packer", "작업 컴퓨터": "computer",
	"설비 제작대": "workbench", "분해기": "disassembler", "가공기": "processor", "제작기": "crafter",
	"용광로": "furnace", "생산기": "producer", "현금인쇄기": "cash_printer",
	"펌프": "pump", "주입기": "injector",
	"바이오 발전기": "bio_generator", "석탄 발전기": "coal_generator",
	"경비 터렛": "turret_guard", "전기 터렛": "turret_electric",
	"물건 더미": "pile", "무한 공급기": "source", "소각기": "incinerator",
	"엄청난 쓰레기 더미": "trash_heap",
}
## 설비 방향대로 돌려 그리는 스프라이트 (나머지는 방향과 상관없이 똑바로)
const DIRECTIONAL := ["exit", "entrance", "sorter", "splitter", "merger", "bridge", "detector", "judge", "injector", "combiner", "source", "dock"]
const OTHER_SHEETS := ["tiles", "items8", "items16", "trash_heap", "player", "ui_icons", "worker_delivery", "worker_repair"]

const STORE := "art_cache"   # 캐시는 Engine 메타데이터 한 곳에 둬요 (정적 변수는 Godot 4.3에서 끌 때 누수로 보고돼서)


static func _store(part: String) -> Dictionary:
	if not Engine.has_meta(STORE):
		Engine.set_meta(STORE, {"tex": {}, "index": {}, "region": {}})
	return Engine.get_meta(STORE)[part]


static func tex(key: String) -> Texture2D:
	var _cache := _store("tex")
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	for dir in [OVERRIDE_DIR, GEN_DIR]:
		var path: String = dir + key + ".png"
		if ResourceLoader.exists(path):
			t = load(path)
			break
	if t == null:
		t = ImageTexture.create_from_image(SpriteGen.make(key, cells_of(key)))
	_cache[key] = t
	return t


static func clear_cache() -> void:
	## 끌 때 불러요: 캐시에 남은 텍스처가 렌더러보다 오래 살아 '누수'로 보고되지 않게
	if Engine.has_meta(STORE):
		Engine.remove_meta(STORE)


static func all_keys() -> Array:
	var out: Array = OTHER_SHEETS.duplicate()
	for n in BUILDINGS:
		var k: String = BUILDINGS[n]
		if not out.has(k):
			out.append(k)
	return out


static func building_key(def_name: String) -> String:
	return BUILDINGS.get(def_name, "")


static func cells_of(key: String) -> Vector2i:
	# 자동 로드 DB를 이름으로 찾아요 (도구 스크립트에서도 컴파일되게)
	var tree = Engine.get_main_loop()
	var db = tree.root.get_node_or_null("DB")
	for n in BUILDINGS:
		if BUILDINGS[n] == key and db != null and db.buildings.has(n):
			return db.buildings[n]["size"]
	return Vector2i.ONE


static func vframes(key: String) -> int:
	if key.begins_with("rail_"):
		return 12
	if key == "sorter":
		return 2
	return 1


# ---------- 아이템 ----------

static func item_index(item_name: String) -> int:
	var _item_index := _store("index")
	if _item_index.is_empty():
		var i := 0
		for n in SpriteGen.ITEMS:
			_item_index[n] = i
			i += 1
	if _item_index.has(item_name):
		return _item_index[item_name]
	if item_name.begins_with("[설비]"):
		return _item_index["[설비]"]
	return _item_index["?"]


static func item_region(item_name: String, size: int) -> Rect2:
	var _regions := _store("region")
	var key := item_name if size == 8 else "%d:%s" % [size, item_name]
	if _regions.has(key):
		return _regions[key]
	var i := item_index(item_name)
	var cols := SpriteGen.ATLAS_COLS
	var r := Rect2((i % cols) * size, int(i / float(cols)) * size, size, size)
	_regions[key] = r
	return r


static func item_icon(item_name: String, size: int = 16) -> AtlasTexture:
	## 인벤토리·바닥·손에 든 것에 쓰는 아이콘.
	## 아이템 아틀라스에 있으면 그 칸, '[설비] 이름'이면 그 설비 그림의 첫 프레임, 아니면 상자 아이콘.
	var _cache := _store("tex")
	var key := "icon%d:%s" % [size, item_name]
	if _cache.has(key):
		return _cache[key]
	var a := AtlasTexture.new()
	var bkey := ""
	if item_name.begins_with("[설비] ") and not SpriteGen.ITEMS.has(item_name):
		bkey = building_key(item_name.substr(5))
	if bkey != "" and bkey != "trash_heap":
		var t := tex(bkey)
		a.atlas = t
		a.region = Rect2(0, 0, t.get_width() / float(SpriteGen.FRAMES), t.get_height() / float(vframes(bkey)))
	else:
		a.atlas = tex("items%d" % size)
		a.region = item_region(item_name, size)
	_cache[key] = a
	return a


static func tile_index(tile_name: String) -> int:
	return SpriteGen.TILES.find(tile_name)
