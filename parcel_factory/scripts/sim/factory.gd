class_name Factory
extends Node
## 공장 시뮬레이션 본체.
## 고정 틱(0.05초)으로 모든 설비를 돌려요. 화면 프레임과 상관없이 결과가 같아서,
## '분당 몇 개'가 기획서 수치와 그대로 맞아요.

signal topology_changed
signal shipment(parcel, ok)
signal items_popped(pile, cell, items)
signal day_ended(day)                  # 18:00이 되어 멈췄어요
signal cells_changed(cells)            # 설비가 생기거나 없어지거나 옮겨진 칸 (빈 목록 = 전부) — 직원 길 찾기 격자가 그 칸만 갱신   # 손으로 뒤져 물건이 튀어나왔을 때 (화면 연출용)

const DT := 0.05
const MAX_STEPS_PER_FRAME := 80   # 프레임이 밀려도 한 번에 이만큼만 따라잡아요
const SAVE_VERSION := 3
const SAVE_VERSION_MIN := 2   # 이 버전부터는 읽을 수 있어요 (바닥 아이템은 3부터)
const KINDS := {
	"rail": preload("res://scripts/sim/conveyor.gd"),
	"exit": preload("res://scripts/sim/exit_port.gd"),
	"entrance": preload("res://scripts/sim/entrance_port.gd"),
	"storage": preload("res://scripts/sim/storage.gd"),
	"sorter": preload("res://scripts/sim/sorter.gd"),
	"splitter": preload("res://scripts/sim/splitter.gd"),
	"merger": preload("res://scripts/sim/merger.gd"),
	"bridge": preload("res://scripts/sim/bridge.gd"),
	"shelf": preload("res://scripts/sim/shelf.gd"),
	"packer": preload("res://scripts/sim/packer.gd"),
	"combiner": preload("res://scripts/sim/combiner.gd"),
	"detector": preload("res://scripts/sim/detector.gd"),
	"judge": preload("res://scripts/sim/judge.gd"),
	"gift": preload("res://scripts/sim/gift_packer.gd"),
	"computer": preload("res://scripts/sim/computer.gd"),
	"machine": preload("res://scripts/sim/machine.gd"),
	"pump": preload("res://scripts/sim/pump.gd"),
	"injector": preload("res://scripts/sim/injector.gd"),
	"generator": preload("res://scripts/sim/generator.gd"),
	"turret": preload("res://scripts/sim/turret.gd"),
	"pile": preload("res://scripts/sim/pile.gd"),
	"source": preload("res://scripts/sim/source.gd"),
	"void": preload("res://scripts/sim/void_sink.gd"),
}
const LAYER_KINDS := ["wire", "pipe", "water"]

var buildings: Array = []
var grid := {}        # Vector2i -> Building
var wires := {}       # Vector2i -> true
var pipes := {}
var water := {}       # 물 샘 칸
var power_nets: Array = []
var water_nets: Array = []

var room: Room = null     # 지형 (없으면 무한 격자)
var floor_items := FloorItems.new()   # 바닥에 떨어진 아이템 (시뮬레이션에는 영향 없음)
var creative := false     # 켜면 지형 규칙을 무시하고 어디든 설치·철거
var held := {}            # 이동 모드로 들려 있는 설비 (그동안 멈춰요)
var _rng := RandomNumberGenerator.new()

var paused := false
var speed := 1.0
var sim_time := 0.0
var revision := 0     # 설치·철거·회전·불러오기마다 1씩 늘어요 (화면이 다시 그릴지 판단)
var tick_count := 0   # 지금까지 돈 틱 수 (디버그 오버레이가 틱/초 계산에 써요)
var shipped := 0
var shipped_ok := 0
var day := 1              # 며칠째
var day_over := false     # 18:00: 다음 날(next_day)까지 시뮬레이션이 멈춰요
var today_ok := 0         # 오늘 정상 배달
var today_bad := 0        # 오늘 오배송
var courier_count := 0    # 배달 아르바이트 수 (1명 이상이면 출하대 자동 배달이 꺼져요)
var _acc := 0.0
var _dirty := true


func _process(delta: float) -> void:
	if paused or day_over:
		return
	_acc += delta * speed
	var n := 0
	while _acc >= DT and n < MAX_STEPS_PER_FRAME:
		step(DT)
		_acc -= DT
		n += 1
		if sim_time >= GameClock.DAY_REAL_SEC:
			# 하루 끝(18:00): 밤 시스템은 아직 없어서 멈추고 '다음 날'을 기다려요
			day_over = true
			_acc = 0.0
			day_ended.emit(day)
			return
	if n >= MAX_STEPS_PER_FRAME:
		_acc = 0.0


func step(dt: float) -> void:
	if _dirty:
		_rebuild()
	_update_power()
	_update_water()
	for b in buildings:
		if not held.has(b) and not b.broken:
			b.tick(dt)
	sim_time += dt
	tick_count += 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear_all()


# ---------- 설치·철거 ----------

func get_at(c: Vector2i):
	return grid.get(c, null)


func footprint(def: Dictionary, p: Vector2i, r: int) -> Array:
	var s: Vector2i = def["size"]
	if r % 2 == 1:
		s = Vector2i(s.y, s.x)
	var out := []
	for y in s.y:
		for x in s.x:
			out.append(p + Vector2i(x, y))
	return out


func cell_ok(c: Vector2i) -> bool:
	## 지형상 이 칸에 무언가를 놓을 수 있는지 (크리에이티브면 어디든)
	return creative or room == null or room.is_buildable(c)


func can_place(def: Dictionary, p: Vector2i, r: int) -> bool:
	if def["kind"] in LAYER_KINDS:
		return cell_ok(p)
	for c in footprint(def, p, r):
		if grid.has(c) or not cell_ok(c):
			return false
	if def["kind"] == "pump" and not water.has(p):
		return false
	if def["kind"] == "exit" and not creative:
		var src = get_at(p - Building.DIRV[r])
		if src is ItemPile and not src.accepts_exit_at(p):
			return false
	return true


func place_reason(def_name: String, p: Vector2i, r: int) -> String:
	## 놓을 수 없는 이유 ("" = 놓을 수 있어요). 미리보기에 그대로 보여줘요.
	## 전선·파이프·물 샘은 설비 밑에도 깔려서 벽만 막혀요. 같은 종류 레일이 이미 있으면 '덮어쓰기'로 놓을 수 있어요
	var def: Dictionary = DB.buildings[def_name]
	var cells: Array = [p] if def["kind"] in LAYER_KINDS else footprint(def, p, r)
	for c in cells:
		var why := _terrain_reason(c)
		if why != "":
			return why
	if def["kind"] in LAYER_KINDS:
		return ""
	for c in cells:
		var b = grid.get(c, null)
		if b != null and not (b.name == def_name and b.is_conveyor() and def["size"] == Vector2i.ONE):
			return "다른 설비"
	if def["kind"] == "pump" and not water.has(p):
		return "물 샘 위에만"
	if def["kind"] == "exit" and not creative:
		var src = get_at(p - Building.DIRV[r])
		if src is ItemPile and not src.accepts_exit_at(p):
			return "출구 자리 아님"
	return ""


func _terrain_reason(c: Vector2i) -> String:
	if creative or room == null or room.is_buildable(c):
		return ""
	match room.terrain_at(c):
		Room.T.NO_BUILD:
			return "통로"
		Room.T.RESERVED:
			return "작업대 자리"
	return "벽"


func layer_has(def_name: String, c: Vector2i) -> bool:
	## 전선·파이프·물 샘 칸이 이미 깔려 있는지
	match DB.buildings[def_name]["kind"]:
		"wire":
			return wires.has(c)
		"pipe":
			return pipes.has(c)
		"water":
			return water.has(c)
	return false


func player_place(def_name: String, p: Vector2i, r: int, inv: Inventory, slot: int = -1) -> bool:
	## 인벤토리의 '[설비] 이름' 1개를 써서 놓아요. 같은 종류 레일이 이미 있으면 방향만 바꾸고 아이템은 안 써요
	if place_reason(def_name, p, r) != "":
		return false
	var existing = get_at(p)
	if existing != null and existing.name == def_name:
		rotate_conveyor(existing, r)
		return true
	if layer_has(def_name, p):
		return true
	var item := DB.building_item(def_name)
	if inv.count(item) < 1:
		return false
	var k: String = DB.buildings[def_name]["kind"]
	var b = place(def_name, p, r)
	if b == null and not (k in LAYER_KINDS):
		return false
	inv.remove(item, 1, slot)
	return true


func place_line(def_name: String, cells: Array, inv: Inventory, slot: int = -1) -> int:
	## 두 점 설치: cells = [{pos, rot}, ...]. 놓거나 방향을 바꾼 칸 수를 돌려줘요
	var n := 0
	for e in cells:
		if player_place(def_name, e["pos"], e["rot"], inv, slot):
			n += 1
	return n


func place(def_name: String, p: Vector2i, r: int):
	var def: Dictionary = DB.buildings[def_name]
	var k: String = def["kind"]
	if k in LAYER_KINDS and not cell_ok(p):
		return null
	if k == "wire":
		wires[p] = true
		mark_dirty()
		return null
	if k == "pipe":
		pipes[p] = true
		mark_dirty()
		return null
	if k == "water":
		water[p] = true
		mark_dirty()
		return null
	if not can_place(def, p, r):
		return null
	var b: Building = KINDS[k].new()
	b.setup(self, def, p, r)
	buildings.append(b)
	for c in b.cells():
		grid[c] = b
	mark_dirty()
	cells_changed.emit(b.cells())
	return b


func rotate_conveyor(b: Building, r: int) -> void:
	## 드래그로 레일을 깔 때 이미 있는 레일의 방향만 바꿔요
	b.rot = r
	mark_dirty()


func remove_at(c: Vector2i) -> bool:
	var b = grid.get(c, null)
	if b == null:
		return false
	if is_fixed(b) and not creative:
		return false
	for cc in b.cells():
		grid.erase(cc)
	buildings.erase(b)
	_release(b)
	mark_dirty()
	cells_changed.emit(b.cells())
	return true


func is_fixed(b: Building) -> bool:
	return bool(b.def.get("fixed", false))


# ---------- 플레이어 손으로 하는 일 ----------
## 화면·입력 쪽은 이 함수들만 불러서 공장을 바꿔요.

func hand_pull(pile: ItemPile, at_cell: Vector2i, inv: Inventory) -> Array:
	## 손으로 더미를 뒤져 정의의 hand_pull 범위만큼 꺼내 가방에 넣어요 (못 넣은 건 그 자리 바닥에)
	var r := pile.hand_pull_range()
	if r == Vector2i.ZERO:
		return []
	var got := pile.hand_pull(_rng.randi_range(r.x, r.y))
	for it in got:
		if inv.add(it, 1) > 0:
			floor_items.spawn(it, 1, Vector2(at_cell) + Vector2(0.5, 0.5))
	items_popped.emit(pile, at_cell, got)
	return got


func pick_item(b, inv: Inventory) -> bool:
	## 레일 위 물건 줍기
	if not (b is Conveyor) or b.item == null or not inv.can_accept(b.item):
		return false
	inv.add(b.item, 1)
	b.item = null
	b.progress = 0.0
	return true


func player_insert(b: Building, item, n: int) -> int:
	## 플레이어가 손으로 설비에 넣어요. 어느 칸에 들어갈지는 설비(try_insert)가 정해요. 넣은 수를 돌려줘요.
	## item: 아이템 이름(String) 또는 Item (내용물이 있는 물건이면 1개만)
	var done := 0
	var unique: bool = item is Item and not item.is_plain()
	for i in (1 if unique else n):
		var it: Item = item if unique else Item.new(item.id if item is Item else str(item))
		if not _insert_one(b, it):
			break
		done += 1
	return done


func _insert_one(b: Building, it: Item) -> bool:
	var cells := [b.pos - Vector2i(1, 0)]
	if b is Detector:
		cells = [b.left_cell(), b.right_cell(), b.back_cell()]
	elif b is Conveyor:
		cells = [b.back_cell(), b.left_cell(), b.right_cell()]
	for c in cells:
		if b.try_insert(it, c):
			return true
	return false


func player_extract(b: Building, slot_index: int, n: int) -> Array:
	## 정보창 slot_index칸에서 최대 n개를 꺼내 Item 목록으로 돌려줘요
	if slot_index < 0 or slot_index >= b.get_slots().size() or n <= 0:
		return []
	return b.extract_slot(slot_index, n)


func change_recipe(b, r, inv: Inventory) -> void:
	## 레시피 바꾸기: 새 레시피에 안 쓰이는 재료는 가방으로, 넘치면 설비 자리 바닥에
	var back: Array = b.set_recipe(r)
	var center := Vector2(b.pos) + Vector2(b.size) * 0.5
	for it in back:
		if inv.add(it, 1) > 0:
			floor_items.spawn(it, 1, center)


func can_deconstruct(b: Building) -> bool:
	## 지급 설비·지형(쓰레기 더미·물 샘 등)은 철거할 수 없어요 (크리에이티브면 지형 설비만 예외)
	if b.given:
		return false
	return not is_fixed(b) or creative


func deconstruct(b) -> Array:
	## 철거: 설비 안의 모든 물건 + 제작 재료(또는 설비 아이템)를 설비 자리에 바닥 아이템으로 쏟아요.
	## 쏟은 물건 목록을 돌려줘요 (철거할 수 없으면 빈 목록)
	if b == null or not can_deconstruct(b):
		return []
	var out: Array = b.contents()
	if b is StorageBlock:
		# 묶음에서 이 블록이 빠지면 줄어든 용량만큼 넘치는 것만 나와요
		var g = b.group
		var keep: int = 20 * (g.members.size() - 1)
		while g.items.size() > keep:
			out.append(g.items.pop_back())
		g.members.erase(b)   # 여러 개를 한 번에 철거할 때 다음 블록이 줄어든 묶음으로 계산하게
	for m in DB.build_materials(b.name):
		out.append_array(Building.items_of(m[0], m[1]))
	var center := Vector2(b.pos) + Vector2(b.size) * 0.5
	if not remove_at(b.pos):
		return []
	for it in out:
		floor_items.spawn(it, 1, center)
	return out


func deconstruct_many(list: Array) -> Array:
	## 여러 개 한 번에 철거: list = 설비 또는 {layer: "wire"/"pipe", pos} (전선·파이프 칸).
	## 결과물은 각자 자리에 쏟아요. 연결·전력망·물망·창고 묶음은 다음 틱에 한 번만 다시 계산돼요
	var out := []
	for e in list:
		if e is Dictionary:
			out.append_array(_deconstruct_layer(e["layer"], e["pos"]))
		else:
			out.append_array(deconstruct(e))
	return out


func _deconstruct_layer(layer: String, c: Vector2i) -> Array:
	if not remove_layer(layer, c):
		return []
	var out := []
	for m in DB.build_materials("전선" if layer == "wire" else "파이프"):
		out.append_array(Building.items_of(m[0], m[1]))
	for it in out:
		floor_items.spawn(it, 1, Vector2(c) + Vector2(0.5, 0.5))
	return out


# ---------- 옮기기 (이동 모드) ----------

func can_move(b) -> bool:
	## 옮길 수 없는 것도 철거와 같아요: 지급 설비·지형
	return b != null and can_deconstruct(b)


func set_held(list: Array) -> void:
	## 들고 옮기는 동안 멈출 설비 (화면은 원래 자리에 점선만 그려요)
	held.clear()
	for b in list:
		if b is Building:
			held[b] = true
	revision += 1


func move_check(list: Array, offset: Vector2i, rot: int) -> Array:
	## list를 offset만큼 (한 개면 rot번 더 돌려서) 옮길 때 하나하나 놓을 수 없는 이유 ("" = 괜찮아요).
	## 함께 옮기는 것끼리, 자기 원래 자리와는 겹쳐도 돼요
	var moving := {}
	for e in list:
		if e is Building:
			moving[e] = true
	var out := []
	for e in list:
		if e is Dictionary:
			out.append(_terrain_reason(e["pos"] + offset))
			continue
		var b: Building = e
		var r := (b.rot + rot) % 4
		var why := ""
		if not can_move(b):
			why = "옮길 수 없음"
		for c in footprint(b.def, b.pos + offset, r):
			if why != "":
				break
			why = _terrain_reason(c)
			var o = grid.get(c, null)
			if why == "" and o != null and not moving.has(o):
				why = "다른 설비"
		if why == "" and b.kind == "pump" and not water.has(b.pos + offset):
			why = "물 샘 위에만"
		out.append(why)
	return out


func move_buildings(list: Array, offset: Vector2i, rot: int = 0) -> bool:
	## 전부 놓을 수 있을 때만 한 번에 옮겨요 (하나라도 안 되면 아무것도 안 바뀌어요).
	## 안의 물건·레시피·설정은 설비 객체에 그대로 있어요 (레일 위 물건도 같이 가요).
	## list: 설비 또는 {layer, pos}. rot: 더 돌릴 횟수 (묶음은 0)
	for why in move_check(list, offset, rot):
		if why != "":
			return false
	var bs := []
	var touched := []
	var layer_cells := {"wire": [], "pipe": []}
	for e in list:
		if e is Dictionary:
			var d: Dictionary = wires if e["layer"] == "wire" else pipes
			if d.has(e["pos"]):
				d.erase(e["pos"])
				layer_cells[e["layer"]].append(e["pos"] + offset)
		else:
			bs.append(e)
			for c in e.cells():
				grid.erase(c)
				touched.append(c)
	for b in bs:
		b.pos += offset
		b.rot = (b.rot + rot) % 4
		var s: Vector2i = b.def["size"]
		b.size = Vector2i(s.y, s.x) if b.rot % 2 == 1 else s
		for c in b.cells():
			grid[c] = b
			touched.append(c)
	for c in layer_cells["wire"]:
		wires[c] = true
	for c in layer_cells["pipe"]:
		pipes[c] = true
	mark_dirty()
	cells_changed.emit(touched)
	return true


# ---------- 고장 · 직원 ----------

func break_random(rng: RandomNumberGenerator = null) -> Building:
	## 디버그: 무작위 설비 하나를 고장 내요 (지형·레일 계열 제외). 고장 낸 설비를 돌려줘요
	var cands := []
	for b in buildings:
		if not b.broken and not is_fixed(b) and not b.is_conveyor():
			cands.append(b)
	if cands.is_empty():
		return null
	var r := rng if rng != null else _rng
	var b: Building = cands[r.randi_range(0, cands.size() - 1)]
	b.broken = true
	revision += 1
	return b


func repair(b: Building) -> void:
	if b != null and b.broken:
		b.broken = false
		revision += 1


func take_parcels(s: Shelf, n: int) -> Array:
	## 배달 아르바이트가 출하대에서 택배를 최대 n개 집어요
	return Building.take_front(s.stack, n)


func deliver(parcels: Array) -> int:
	## 직원이 배달을 마친 순간: 하나하나 정상/오배송을 세요. 정상 수를 돌려줘요
	var ok_n := 0
	for p in parcels:
		var ok := Shelf.parcel_ok(p)
		record_shipment(p, ok)
		if ok:
			ok_n += 1
	return ok_n


func drop_items(items: Array, origin: Vector2, delay: float) -> void:
	## 가방에서 버린 물건들을 origin(칸 단위) 근처 바닥에. 같은 물건은 한 무더기로
	var plain := {}
	for it in items:
		if it.is_plain():
			plain[it.id] = int(plain.get(it.id, 0)) + 1
		else:
			floor_items.spawn(it, 1, origin, delay)
	for id in plain:
		floor_items.spawn(id, plain[id], origin, delay)


func pickup_drop(d: Dictionary, inv: Inventory) -> int:
	## 바닥 아이템을 가방에 넣어요. 못 넣은 수를 돌려주고 바닥에 남겨요
	var left := inv.add(floor_items.item_of(d), int(d["n"]))
	floor_items.set_count(d, left)
	return left


func _release(b: Building) -> void:
	## 설비 ↔ 전력망·창고 묶음이 서로를 붙잡아 메모리에 남지 않게 끊어요
	b.power_net = null
	b.water_net = null
	b.out_links.clear()
	if b is StorageBlock:
		b.group = null


func remove_layer(layer: String, c: Vector2i) -> bool:
	var d: Dictionary = wires if layer == "wire" else (pipes if layer == "pipe" else water)
	if d.has(c):
		d.erase(c)
		mark_dirty()
		return true
	return false


func clear_all() -> void:
	for b in buildings:
		_release(b)
	power_nets.clear()
	water_nets.clear()
	buildings.clear()
	held.clear()
	grid.clear()
	cells_changed.emit([])
	wires.clear()
	pipes.clear()
	water.clear()
	floor_items.clear()
	shipped = 0
	shipped_ok = 0
	day = 1
	day_over = false
	sim_time = 0.0
	today_ok = 0
	today_bad = 0
	mark_dirty()


func mark_dirty() -> void:
	_dirty = true
	revision += 1


# ---------- 연결 다시 계산 ----------

func _rebuild() -> void:
	_dirty = false
	_rebuild_storage_groups()
	for b in buildings:
		b.refresh_links()
	power_nets = _build_nets(wires, true)
	water_nets = _build_nets(pipes, false)
	topology_changed.emit()


func _rebuild_storage_groups() -> void:
	## 붙어 있는 창고 블록끼리 하나의 묶음으로 다시 묶어요.
	## 묶음이 둘로 갈라지면 물건은 먼저 찾은 쪽에 남아요 (복제되지 않게).
	var seen := {}
	var used_groups := {}
	for b in buildings:
		if b.kind != "storage" or seen.has(b):
			continue
		var members := []
		var items := []
		var stack := [b]
		seen[b] = true
		while not stack.is_empty():
			var cur = stack.pop_back()
			members.append(cur)
			if not used_groups.has(cur.group):
				used_groups[cur.group] = true
				items.append_array(cur.group.items)
			for d in Building.DIRV:
				var n = get_at(cur.pos + d)
				if n != null and n.kind == "storage" and not seen.has(n):
					seen[n] = true
					stack.append(n)
		var g = StorageBlock.Group.new()
		g.members = members
		g.cap = 20 * members.size()
		g.items = items
		while g.items.size() > g.cap:
			g.items.pop_back()
		for m in members:
			m.group = g


func _build_nets(layer: Dictionary, is_power: bool) -> Array:
	## 층(전선·파이프) 칸을 이어진 덩어리로 묶고, 그 위에 걸친 설비를 붙여요
	var cell_net := {}
	var nets := []
	for c in layer:
		if cell_net.has(c):
			continue
		var net := {"buildings": [], "sat": 1.0, "supply": 0.0, "demand": 0.0, "cells": 0}
		var stack := [c]
		cell_net[c] = net
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			net["cells"] += 1
			for d in Building.DIRV:
				var n: Vector2i = cur + d
				if layer.has(n) and not cell_net.has(n):
					cell_net[n] = net
					stack.append(n)
		nets.append(net)
	for b in buildings:
		var found = null
		for c in b.cells():
			if cell_net.has(c):
				found = cell_net[c]
				break
		if is_power:
			b.power_net = found
		else:
			b.water_net = found
		if found != null:
			found["buildings"].append(b)
	return nets


func _update_power() -> void:
	for net in power_nets:
		var sup := 0.0
		var dem := 0.0
		for b in net["buildings"]:
			sup += b.power_supply()
			dem += b.power_demand()
		net["supply"] = sup
		net["demand"] = dem
		if dem <= 0.0:
			net["sat"] = 1.0
		elif sup <= 0.0:
			net["sat"] = 0.0
		else:
			net["sat"] = clampf(sup / dem, 0.1, 1.0)


func _update_water() -> void:
	for net in water_nets:
		var sup := 0.0
		var dem := 0.0
		for b in net["buildings"]:
			if b.has_method("water_supply"):
				sup += b.water_supply()
			if b.has_method("water_demand"):
				dem += b.water_demand()
		net["supply"] = sup
		net["demand"] = dem
		if dem <= 0.0:
			net["sat"] = 1.0
		else:
			net["sat"] = clampf(sup / dem, 0.0, 1.0)


func record_shipment(p, ok: bool) -> void:
	shipped += 1
	if ok:
		shipped_ok += 1
		today_ok += 1
	else:
		today_bad += 1
	shipment.emit(p, ok)


func next_day() -> void:
	## 다음 날 09:00부터 다시 (설비·물건은 그대로, 오늘 배달 수만 새로)
	day += 1
	sim_time = 0.0
	today_ok = 0
	today_bad = 0
	day_over = false


# ---------- 저장·불러오기 ----------
## 설비(이름·위치·방향·설정)와 전선·파이프·물 샘 칸, 날짜·시각·오늘 배달 수를 저장해요. 물건 내용물은 아직 빼요.

func to_save() -> Dictionary:
	var bs := []
	for b in buildings:
		bs.append({"name": b.name, "pos": [b.pos.x, b.pos.y], "rot": b.rot, "given": b.given, "broken": b.broken, "state": b.save_state()})
	return {
		"version": SAVE_VERSION,
		"creative": creative,
		"buildings": bs,
		"wires": _cells_to_list(wires),
		"pipes": _cells_to_list(pipes),
		"water": _cells_to_list(water),
		"floor_items": floor_items.to_save(),
		"day": {"n": day, "time": sim_time, "ok": today_ok, "bad": today_bad},
	}


func load_save(d) -> bool:
	if not (d is Dictionary) or not d.has("buildings"):
		return false
	var ver := int(d.get("version", 0))
	if ver < SAVE_VERSION_MIN or ver > SAVE_VERSION:
		push_warning("저장 파일 버전이 달라요 (%s ≠ %d). 새로 시작해요" % [str(d.get("version", "?")), SAVE_VERSION])
		return false
	clear_all()
	creative = bool(d.get("creative", false))
	sim_time = 0.0
	# 물 샘이 먼저 있어야 펌프를 놓을 수 있어요
	_list_to_cells(d.get("water", []), water)
	_list_to_cells(d.get("wires", []), wires)
	_list_to_cells(d.get("pipes", []), pipes)
	for e in d["buildings"]:
		var n := str(e.get("name", ""))
		if not DB.buildings.has(n):
			push_warning("저장 파일의 모르는 설비: " + n)
			continue
		var pp: Array = e.get("pos", [0, 0])
		var b = place(n, Vector2i(int(pp[0]), int(pp[1])), int(e.get("rot", 0)))
		if b == null:
			push_warning("저장된 설비를 놓지 못했어요: %s %s" % [n, str(pp)])
			continue
		b.given = bool(e.get("given", false))
		b.broken = bool(e.get("broken", false))
		var st = e.get("state", {})
		if st is Dictionary:
			b.load_state(st)
	floor_items.load_save(d.get("floor_items", []))
	var dd = d.get("day", {})
	if dd is Dictionary:
		day = int(dd.get("n", 1))
		sim_time = clampf(float(dd.get("time", 0.0)), 0.0, GameClock.DAY_REAL_SEC)
		today_ok = int(dd.get("ok", 0))
		today_bad = int(dd.get("bad", 0))
		day_over = sim_time >= GameClock.DAY_REAL_SEC
	mark_dirty()
	return true


func _cells_to_list(layer: Dictionary) -> Array:
	var out := []
	for c in layer:
		out.append([c.x, c.y])
	return out


func _list_to_cells(list, layer: Dictionary) -> void:
	for p in list:
		layer[Vector2i(int(p[0]), int(p[1]))] = true


# ---------- 요약 ----------

func items_on_rails() -> int:
	var n := 0
	for b in buildings:
		if b is Conveyor and b.item != null:
			n += 1
	return n

func power_summary() -> String:
	var sup := 0.0
	var dem := 0.0
	for net in power_nets:
		sup += net["supply"]
		dem += net["demand"]
	return "전력 %d / %d (망 %d개)" % [int(sup), int(dem), power_nets.size()]


func time_text() -> String:
	var s := int(sim_time)
	return "%02d:%02d" % [s / 60, s % 60]
