class_name Factory
extends Node
## 공장 시뮬레이션 본체.
## 고정 틱(0.05초)으로 모든 설비를 돌려요. 화면 프레임과 상관없이 결과가 같아서,
## '분당 몇 개'가 기획서 수치와 그대로 맞아요.

signal topology_changed
signal shipment(parcel, ok)

const DT := 0.05
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

var paused := false
var speed := 1.0
var sim_time := 0.0
var shipped := 0
var shipped_ok := 0
var _acc := 0.0
var _dirty := true


func _process(delta: float) -> void:
	if paused:
		return
	_acc += delta * speed
	var n := 0
	while _acc >= DT and n < 80:
		step(DT)
		_acc -= DT
		n += 1
	if n >= 80:
		_acc = 0.0


func step(dt: float) -> void:
	if _dirty:
		_rebuild()
	_update_power()
	_update_water()
	for b in buildings:
		b.tick(dt)
	sim_time += dt


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


func can_place(def: Dictionary, p: Vector2i, r: int) -> bool:
	if def["kind"] in LAYER_KINDS:
		return true
	for c in footprint(def, p, r):
		if grid.has(c):
			return false
	if def["kind"] == "pump" and not water.has(p):
		return false
	return true


func place(def_name: String, p: Vector2i, r: int):
	var def: Dictionary = DB.buildings[def_name]
	var k: String = def["kind"]
	if k == "wire":
		wires[p] = true
		_dirty = true
		return null
	if k == "pipe":
		pipes[p] = true
		_dirty = true
		return null
	if k == "water":
		water[p] = true
		_dirty = true
		return null
	if not can_place(def, p, r):
		return null
	var b: Building = KINDS[k].new()
	b.setup(self, def, p, r)
	buildings.append(b)
	for c in b.cells():
		grid[c] = b
	_dirty = true
	return b


func rotate_conveyor(b: Building, r: int) -> void:
	## 드래그로 레일을 깔 때 이미 있는 레일의 방향만 바꿔요
	b.rot = r
	_dirty = true


func remove_at(c: Vector2i) -> bool:
	var b = grid.get(c, null)
	if b == null:
		return false
	for cc in b.cells():
		grid.erase(cc)
	buildings.erase(b)
	_dirty = true
	return true


func remove_layer(layer: String, c: Vector2i) -> bool:
	var d: Dictionary = wires if layer == "wire" else (pipes if layer == "pipe" else water)
	if d.has(c):
		d.erase(c)
		_dirty = true
		return true
	return false


func clear_all() -> void:
	buildings.clear()
	grid.clear()
	wires.clear()
	pipes.clear()
	water.clear()
	shipped = 0
	shipped_ok = 0
	_dirty = true


func mark_dirty() -> void:
	_dirty = true


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


# ---------- 요약 ----------

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
