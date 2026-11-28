class_name Factory
extends Node
## 공장 시뮬레이션 본체.
## 고정 틱(0.05초)으로 모든 설비를 돌려요. 화면 프레임과 상관없이 결과가 같아서,
## '분당 몇 개'가 기획서 수치와 그대로 맞아요.

signal topology_changed
signal shipment(parcel, ok)
signal items_popped(pile, cell, items)   # 손으로 뒤져 물건이 튀어나왔을 때 (화면 연출용)

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
var _rng := RandomNumberGenerator.new()

var paused := false
var speed := 1.0
var sim_time := 0.0
var revision := 0     # 설치·철거·회전·불러오기마다 1씩 늘어요 (화면이 다시 그릴지 판단)
var tick_count := 0   # 지금까지 돈 틱 수 (디버그 오버레이가 틱/초 계산에 써요)
var shipped := 0
var shipped_ok := 0
var _acc := 0.0
var _dirty := true


func _process(delta: float) -> void:
	if paused:
		return
	_acc += delta * speed
	var n := 0
	while _acc >= DT and n < MAX_STEPS_PER_FRAME:
		step(DT)
		_acc -= DT
		n += 1
	if n >= MAX_STEPS_PER_FRAME:
		_acc = 0.0


func step(dt: float) -> void:
	if _dirty:
		_rebuild()
	_update_power()
	_update_water()
	for b in buildings:
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


func take_outputs(b: Building, inv: Inventory, max_n: int) -> int:
	## 설비 결과물·보관물을 가방이 받을 수 있는 동안 꺼내요
	var n := 0
	while n < max_n and b.has_output():
		var it: Item = b.try_extract()
		if it == null:
			break
		if inv.add(it, 1) > 0:
			floor_items.spawn(it, 1, Vector2(b.pos) + Vector2(b.size) * 0.5)
			break
		n += 1
	return n


func insert_from(inv: Inventory, slot: int, b: Building) -> bool:
	## 가방 slot칸의 물건 하나를 설비·레일에 넣어요 (받으면 그 칸에서 하나 빼요)
	var it := inv.item_at(slot)
	if it == null:
		return false
	var cells := [b.pos - Vector2i(1, 0)]
	if b is Detector:
		cells = [b.left_cell(), b.right_cell(), b.back_cell()]
	elif b is Conveyor:
		cells = [b.back_cell(), b.left_cell(), b.right_cell()]
	for c in cells:
		if b.try_insert(it, c):
			inv.remove(it.id, 1, slot)
			return true
	return false


func deconstruct(b, inv: Inventory) -> bool:
	## 철거: 설비 아이템 + 안에 든 물건을 가방으로. 가방에 안 들어가는 건 그 자리 바닥에 떨어져요
	if is_fixed(b) and not creative:
		return false
	var back := [DB.building_item(b.name)]
	back.append_array(b.contents())
	if b is StorageBlock:
		# 묶음에서 이 블록이 빠지면 넘치는 만큼 돌려받아요
		var g = b.group
		var keep: int = 20 * (g.members.size() - 1)
		while g.items.size() > keep:
			back.append(g.items.pop_back())
	var center := Vector2(b.pos) + Vector2(b.size) * 0.5
	if not remove_at(b.pos):
		return false
	for it in back:
		if inv.add(it, 1) > 0:
			floor_items.spawn(it, 1, center)
	return true


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
	grid.clear()
	wires.clear()
	pipes.clear()
	water.clear()
	floor_items.clear()
	shipped = 0
	shipped_ok = 0
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
	shipment.emit(p, ok)


# ---------- 저장·불러오기 ----------
## 설비(이름·위치·방향·설정)와 전선·파이프·물 샘 칸만 저장해요. 물건 내용물은 아직 빼요.

func to_save() -> Dictionary:
	var bs := []
	for b in buildings:
		bs.append({"name": b.name, "pos": [b.pos.x, b.pos.y], "rot": b.rot, "state": b.save_state()})
	return {
		"version": SAVE_VERSION,
		"creative": creative,
		"buildings": bs,
		"wires": _cells_to_list(wires),
		"pipes": _cells_to_list(pipes),
		"water": _cells_to_list(water),
		"floor_items": floor_items.to_save(),
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
		var st = e.get("state", {})
		if st is Dictionary:
			b.load_state(st)
	floor_items.load_save(d.get("floor_items", []))
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
