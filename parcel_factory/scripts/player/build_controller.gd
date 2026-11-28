extends Node
## 설치 조종: 핫바에서 '[설비] 이름'을 든 상태(일반 모드)에서
##   모바일: 상호작용 버튼 꾹 → 설치 모드. 누른 채로 끌면 끈 방향·거리만큼 플레이어 앞 칸에서 미리보기가 움직여요
##           (DRAG_PX_PER_CELL px = 1칸, 조준 스틱처럼). 월드를 직접 눌러도 그 칸으로 옮겨져요(누른 채 끌면 따라와요).
##           월드를 짧게 탭(두 번째 손가락) = 회전. 손을 떼면 설치, 버튼 가운데로 되돌아와 떼면 취소.
##   PC   : 마우스를 올린 칸에 미리보기, 왼쪽 클릭 = 설치, 오른쪽 클릭 = 취소, R = 회전.
## 레일·전선·파이프(물 샘)는 두 점 설치: 첫 설치가 A(깃발), 다음 설치가 B → A~B를 직선·ㄱ자로 이어요.
##   꺾는 방향은 끄는 방향, 회전 = 꺾는 방향 바꾸기. B = A면 A 고정 해제. 설치 후 B가 새 A. 취소 = A 고정 해제.
## 공장은 factory.place_reason / player_place / place_line으로만 바꿔요. 미리보기는 view.ghost에 넣어요.

signal placed(cells: Array)

const DRAG_PX_PER_CELL := 40.0   # 버튼을 이만큼 끌면 미리보기 1칸
const AHEAD := 2                 # 끌지 않았을 때 미리보기: 플레이어 앞 몇 칸
const WORLD_TAP_SEC := 0.2       # 월드를 이보다 짧게 탭하면 회전 (이동 없이)
const WORLD_TAP_PX := 14.0

var main = null
var factory: Factory = null
var player = null
var view = null

var active := false              # 모바일·F키 설치 모드 (누르는 중)
var anchor = null                # 두 점 설치의 A (Vector2i) 또는 null
var corner_flip := false         # 회전 버튼으로 꺾는 방향 바꾸기
var aim := Vector2i.ZERO
var plan := {}                   # 마지막 계획 (미리보기·설치에 같이 써요)
var _rot_by_def := {}            # 설비 종류별 마지막 회전
var _offset := Vector2.ZERO      # 버튼을 끈 거리 (px)
var _world_aim = null            # 월드를 직접 눌러 고른 칸
var _world_touch := {}           # {index, pos, t, moved}
var _layers_before = null        # 전선·파이프를 들기 전 '층 보기'
var _last_def := ""              # 다른 설비로 바꿔 들면 A 고정을 풀어요
var _sfx: AudioStreamPlayer


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = _click_sound()
	_sfx.volume_db = -6.0
	add_child(_sfx)


# ---------- 상태 ----------

func held_def() -> String:
	## 손에 든 것이 설비 아이템이면 그 설비 이름
	var id: String = player.held_id()
	if not id.begins_with("[설비] "):
		return ""
	var n := id.substr(5)
	return n if DB.buildings.has(n) else ""


func is_line(def_name: String) -> bool:
	return bool(DB.buildings[def_name].get("drag", false))


func is_layer(def_name: String) -> bool:
	return DB.buildings[def_name]["kind"] in Factory.LAYER_KINDS


func rot_of(def_name: String) -> int:
	return _rot_by_def.get(def_name, 0)


func busy() -> bool:
	## 설치 쪽이 입력을 가져가는 중인지 (월드 탭이 정보창 열기로 가지 않게)
	return held_def() != "" and main.play_mode.mode == PlayMode.Mode.NORMAL


# ---------- 매 프레임: 미리보기 ----------

func _process(_dt: float) -> void:
	var d := held_def()
	if d != _last_def:
		_last_def = d
		anchor = null
		corner_flip = false
	var on: bool = d != "" and main.play_mode.mode == PlayMode.Mode.NORMAL and not main.hud.info_open()
	_auto_layers(on and is_layer(d))
	if not on:
		if active or anchor != null:
			active = false
			anchor = null
		_set_ghost({})
		return
	if active:
		var base: Vector2i = player.cell() + Vector2i(player.facing_vec()) * AHEAD
		aim = _world_aim if _world_aim != null else base + Vector2i((_offset / DRAG_PX_PER_CELL).round())
	elif not main.hud.touch_mode:
		var mp: Vector2 = main.get_viewport().get_mouse_position()
		if main.hud.is_over_ui(mp):
			_set_ghost({})
			return
		aim = main.screen_to_cell(mp)
	elif anchor == null:
		_set_ghost({})
		return
	else:
		# 터치: 누르지 않을 땐 A 깃발만
		_set_ghost({"cells": [], "anchor": anchor, "build": true})
		return
	plan = make_plan(d, aim)
	_set_ghost(plan)


func _set_ghost(g: Dictionary) -> void:
	if main.tool == "build":
		return   # 디버그 설치 팔레트가 쓰는 중
	view.ghost = g


func _auto_layers(on: bool) -> void:
	## 전선·파이프를 들면 '층 보기'를 켜고, 내려놓으면 원래대로
	if on and _layers_before == null:
		_layers_before = view.show_layers
		view.show_layers = true
	elif not on and _layers_before != null:
		view.show_layers = _layers_before
		_layers_before = null


# ---------- 계획 (미리보기와 설치가 같이 써요) ----------

func make_plan(d: String, b: Vector2i) -> Dictionary:
	var def: Dictionary = DB.buildings[d]
	var item := DB.building_item(d)
	var have: int = player.inventory.count(item)
	var cells := []
	var line := is_line(d) and anchor != null
	if line:
		var path := path_cells(anchor, b)
		for i in path.size():
			var c: Vector2i = path[i]
			var r := rot_of(d)
			if path.size() > 1:
				var nxt: Vector2i = path[i + 1] if i + 1 < path.size() else c + (c - path[i - 1])
				r = Building.DIRV.find(nxt - c)
			cells.append({"pos": c, "rot": r, "row": _rail_row(path, i, r)})
	else:
		cells.append({"pos": b, "rot": rot_of(d), "row": rot_of(d)})
	var need := 0
	var bad := ""
	for e in cells:
		var why: String = factory.place_reason(d, e["pos"], e["rot"])
		var existing = factory.get_at(e["pos"])
		e["existing"] = factory.layer_has(d, e["pos"]) or (existing != null and existing.name == d)
		if why == "" and not _in_range(def, e["pos"], e["rot"]):
			why = "거리"
		e["ok"] = why == ""
		e["reason"] = why
		if why != "" and bad == "":
			bad = why
		if not e["existing"]:
			need += 1
	var reason := bad
	if reason == "" and have < need:
		reason = "%s %d개 필요 / %d개 있음" % [d, need, have] if line else "인벤토리 부족"
	if reason != "":
		for e in cells:
			if reason.find("필요") >= 0 or reason == "인벤토리 부족":
				e["ok"] = false
	var label := ""
	if line:
		label = "%d칸" % cells.size()
	elif def["kind"] == "machine":
		var rs: Array = DB.recipes_by_machine.get(d, [])
		if rs.size() == 1:
			label = _per_minute(rs[0])
	return {"def": def, "name": d, "cells": cells, "ok": reason == "", "reason": reason, "label": label, "anchor": anchor, "line": line, "build": true}


func path_cells(a: Vector2i, b: Vector2i) -> Array:
	## A → B 직선 또는 ㄱ자. 꺾는 방향: 더 많이 움직인 축 먼저 (회전 버튼으로 바꿔요)
	var d := b - a
	var h_first := (absi(d.x) >= absi(d.y)) != corner_flip
	var out := [a]
	var c := a
	for leg in 2:
		var horiz := h_first if leg == 0 else not h_first
		var target := b.x if horiz else b.y
		while (c.x if horiz else c.y) != target:
			if horiz:
				c.x += signi(target - c.x)
			else:
				c.y += signi(target - c.y)
			out.append(c)
	return out


func _rail_row(path: Array, i: int, r: int) -> int:
	## 미리보기 레일 모양: 옆에서 들어오면 꺾인 모양 (building_layer와 같은 규칙)
	if i == 0:
		return r
	var d_in: Vector2i = path[i] - path[i - 1]
	if d_in == Building.DIRV[r]:
		return r
	var left: Vector2i = Building.DIRV[(r + 3) % 4]
	return 4 + r * 2 + (0 if -d_in == left else 1)


func _in_range(def: Dictionary, p: Vector2i, r: int) -> bool:
	for c in factory.footprint(def, p, r):
		if main.in_build_range(c):
			return true
	return false


func _per_minute(r: Dictionary) -> String:
	var t: float = r["t"]
	var a := []
	for n in r["in"]:
		a.append("%s %d" % [n, int(round(int(r["in"][n]) * 60.0 / t))])
	var b := []
	for n in r["out"]:
		b.append("%s %d" % [n, int(round(int(r["out"][n]) * 60.0 / t))])
	return "분당 %s → %s" % [", ".join(a), ", ".join(b)]


# ---------- 조작 ----------

func begin() -> void:
	## 상호작용 버튼(또는 F)을 꾹: 설치 모드 시작 (일반 모드에서만)
	if held_def() == "" or main.play_mode.mode != PlayMode.Mode.NORMAL:
		return
	active = true
	_offset = Vector2.ZERO
	_world_aim = null


func drag(offset: Vector2) -> void:
	_offset = offset


func release(cancel: bool) -> void:
	## 손을 떼면 설치, 취소 표시 위에서 떼면 취소
	if not active:
		return
	active = false
	_world_aim = null
	if cancel:
		cancel_build()
	else:
		confirm()


func confirm() -> bool:
	var d := held_def()
	if d == "":
		return false
	var p := make_plan(d, aim)
	if not p["ok"]:
		main.hud.show_message("놓을 수 없어요: " + p["reason"])
		return false
	var cells: Array = p["cells"]
	if p["line"]:
		if cells.size() == 1:
			# B = A: 그 한 칸만 (이미 있으면 그대로) 놓고 A 고정 해제
			factory.player_place(d, cells[0]["pos"], cells[0]["rot"], player.inventory, player.hotbar)
			anchor = null
			main.hud.show_message("A 고정 해제")
		else:
			factory.place_line(d, cells, player.inventory, player.hotbar)
			anchor = cells[-1]["pos"]
	else:
		if not factory.player_place(d, cells[0]["pos"], cells[0]["rot"], player.inventory, player.hotbar):
			main.hud.show_message("놓을 수 없어요")
			return false
		if is_line(d):
			anchor = cells[0]["pos"]   # 첫 칸 = A
	_feedback(cells)
	placed.emit(cells)
	return true


func cancel_build() -> bool:
	## 취소: 설치 모드 끝 + A 고정 해제. 무언가 취소했으면 true
	var had: bool = active or anchor != null
	active = false
	_world_aim = null
	if anchor != null:
		anchor = null
		main.hud.show_message("A 고정 해제")
	return had


func rotate() -> void:
	var d := held_def()
	if d == "":
		return
	if is_line(d) and anchor != null:
		corner_flip = not corner_flip
	else:
		_rot_by_def[d] = (rot_of(d) + 1) % 4


# ---------- 설치 모드 중 월드 터치 ----------

func world_press(index: int, sp: Vector2) -> bool:
	## 설치 모드 중 월드를 누르면 그 칸으로 미리보기. 처리했으면 true
	if not active:
		return false
	_world_touch = {"index": index, "pos": sp, "t": Time.get_ticks_msec(), "moved": false}
	return true


func world_drag(index: int, sp: Vector2) -> bool:
	if _world_touch.is_empty() or _world_touch["index"] != index:
		return false
	if (sp - _world_touch["pos"]).length() > WORLD_TAP_PX:
		_world_touch["moved"] = true
	if _world_touch["moved"]:
		_world_aim = main.screen_to_cell(sp)
	return true


func world_release(index: int, sp: Vector2) -> bool:
	if _world_touch.is_empty() or _world_touch["index"] != index:
		return false
	var quick: bool = Time.get_ticks_msec() - int(_world_touch["t"]) < WORLD_TAP_SEC * 1000.0
	if not _world_touch["moved"] and quick:
		rotate()                       # 두 번째 손가락 탭 = 회전
	else:
		_world_aim = main.screen_to_cell(sp)
	_world_touch = {}
	return true


# ---------- 효과: '착' 소리 · 햅틱 · 먼지 ----------

func _feedback(cells: Array) -> void:
	_sfx.play()
	Input.vibrate_handheld(25)
	for e in cells:
		main.dust.puff(Vector2(e["pos"]) + Vector2(0.5, 0.5))


func _click_sound() -> AudioStreamWAV:
	## 짧은 '착': 잡음 + 낮은 퉁 소리가 빨리 사라져요 (코드로 만든 16비트 소리)
	var rate := 22050
	var n := int(rate * 0.07)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 70.0)
		var v := (rng.randf_range(-1.0, 1.0) * 0.6 + sin(TAU * 140.0 * t) * 0.8) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
