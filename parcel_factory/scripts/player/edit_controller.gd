extends Node
## 이동·철거 모드와 범위 선택 (docs/CONTROLS.md).
##   월드 누르기: HOLD_SEC 전에 DRAG_PX 넘게 움직이면 '끌기'(10단계 둘러보기), 아니면 짧게 = 탭, 길게 = 꾹.
##   철거 모드 : 설비 꾹 → 원형 게이지(DECON_SEC) → 철거. 탭 = '꾹 눌러서 철거' 안내
##   이동 모드 : 설비 꾹 → 들어서 손가락을 따라 미리보기, 놓으면 그 칸으로. 막히면 제자리로 스르륵(SNAP_SEC)
##   상호작용 버튼(F): 이동·철거 모드에선 지금 대상(흰 테두리)에 같은 동작. 옮길 땐 버튼을 끌어 조준
##   범위 선택(모든 모드): 빈 칸 꾹 → 끌어서 사각형 → 놓으면 '동시 선택'. 선택된 설비를 꾹 = 묶음 철거·이동
## 대상은 플레이어로부터 BUILD_RANGE칸 안. 지급 설비·지형은 철거·이동 못 해요 (factory.can_deconstruct).
## 공장은 factory.deconstruct_many / move_check / move_buildings / set_held로만 바꿔요.

const Player := preload("res://scripts/player/player.gd")
const BuildController := preload("res://scripts/player/build_controller.gd")
const HOLD_SEC := Player.HOLD_SEC          # 0.35초: '꾹'
const TILE := 32.0
const DRAG_PX := 12.0                      # 꾹 판정 전에 이만큼 움직이면 '끌기'
const DECON_SEC := 0.6                     # 철거 게이지
const DECON_SEC_MANY := 1.2                # MANY개 넘게 한 번에 철거할 때 (되돌리기가 없어서 길게)
const MANY := 20
const SNAP_SEC := 0.15                     # 못 놓으면 제자리로 돌아가는 연출
const HINT_SEC := 1.5
const EDGE := 0.15                         # 범위 선택 중 화면 가장자리 15%에 닿으면 카메라 이동
const EDGE_PAN_CELLS := 10.0               # 칸/초
const SECOND_TAP_SEC := 0.2                # 옮기는 중 두 번째 손가락 탭 = 회전

var main = null
var factory: Factory = null
var player = null
var view = null

var sel: Array = []              # 선택: Building 또는 {layer: "wire"/"pipe", pos}
var state := ""                  # "" · "gauge" · "move" · "select"
var press := {}                  # {src: world/button, index, p, p0, t, cell, b, moved, held, player}
var gauge_t := 0.0
var gauge_list: Array = []
var gauge_b = null               # 게이지를 그릴 설비
var move_list: Array = []
var move_rot := 0
var move_ok := false
var move_offset := Vector2i.ZERO
var move_armed := false          # 선택 바 [이동]: 다음 월드 누르기로 바로 들어요
var grab := Vector2i.ZERO        # 잡은 칸
var grab_b = null                # 잡은 설비 (거리 기준)
var sel_from := Vector2i.ZERO
var sel_to := Vector2i.ZERO
var snap := {}                   # {list, from(px), t}
var hint := {}                   # {rect, text, t}
var _btn_off := Vector2.ZERO
var _second := {}                # {index, t}
var _rev := -1
var _sfx: AudioStreamPlayer


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = _break_sound()
	_sfx.volume_db = -6.0
	add_child(_sfx)
	main.play_mode.changed.connect(func(_m) -> void: _on_mode_changed())


# ---------- 상태 ----------

func moving() -> bool:
	return state == "move"


func button_moving() -> bool:
	return state == "move" and press.get("src", "") == "button"


func owns(index: int) -> bool:
	## 이 손가락을 지금 이쪽이 쓰고 있는지
	return press.get("src", "") == "world" and int(press["index"]) == index


func busy() -> bool:
	## 꾹 동작(게이지·옮기기·범위 선택) 중이면 두 번째 손가락은 핀치가 아니라 이쪽으로
	return state != ""


func in_sel(b) -> bool:
	return b != null and sel.has(b)


func sel_count() -> Array:
	## [설비 수, 전선·파이프 칸 수]
	var n := 0
	for e in sel:
		if e is Building:
			n += 1
	return [n, sel.size() - n]


func in_range_b(b) -> bool:
	for c in b.cells():
		if main.in_build_range(c):
			return true
	return false


func gauge_need() -> float:
	return decon_sec(gauge_list.size())


func decon_sec(n: int) -> float:
	## 철거 게이지 시간: MANY개 넘게 한 번에 철거하면 길게 (되돌리기가 아직 없어요)
	return DECON_SEC_MANY if n > MANY else DECON_SEC


# ---------- 매 프레임 ----------

func _process(dt: float) -> void:
	if factory.revision != _rev:
		_rev = factory.revision
		_prune_sel()
	if not press.is_empty() and state == "" and not press["held"]:
		press["t"] += dt
		if not press["moved"] and press["t"] >= HOLD_SEC:
			press["held"] = true
			_on_hold()
	match state:
		"gauge":
			if not factory.buildings.has(gauge_b):
				_end_press()
			else:
				gauge_t += dt
				if gauge_t >= gauge_need():
					_deconstruct(gauge_list)
					_end_press()
		"select":
			_edge_pan(dt, press["p"])
			sel_to = main.screen_to_cell(press["p"])
		"move":
			_update_move()
	if not snap.is_empty():
		snap["t"] += dt
		var k: float = clampf(snap["t"] / SNAP_SEC, 0.0, 1.0)
		if k >= 1.0:
			snap = {}
			factory.set_held([])
			view.ghost = {}
		else:
			view.ghost = _ghost_of(snap["list"], Vector2i.ZERO, 0, "")
			view.ghost["shift"] = snap["from"] * (1.0 - k)
	if not hint.is_empty():
		hint["t"] -= dt
		if hint["t"] <= 0.0:
			hint = {}


func _prune_sel() -> void:
	## 다른 길(정보창 철거 등)로 사라진 것은 선택에서 빼요
	sel = sel.filter(func(e) -> bool: return (e is Dictionary and (factory.wires if e["layer"] == "wire" else factory.pipes).has(e["pos"])) or (e is Building and factory.buildings.has(e)))


func _on_mode_changed() -> void:
	move_armed = false
	if state == "gauge" or state == "move":
		cancel()


# ---------- 월드 누르기 (main이 손가락 하나만 넘겨줘요) ----------

func world_press(index: int, sp: Vector2) -> void:
	var c: Vector2i = main.screen_to_cell(sp)
	var b = factory.get_at(c)
	press = {"src": "world", "index": index, "p": sp, "p0": sp, "t": 0.0, "cell": c, "b": b, "moved": false, "held": false, "player": false}
	if move_armed:
		move_armed = false
		press["held"] = true
		var g = _nearest_sel(c)
		if g == null:
			return
		if not in_range_b(g):
			_say(g, "너무 멀어요")
			return
		_lift(sel, g, c)
		return
	# 일반 모드: 손 닿는 설비는 지금처럼 플레이어가 처리해요 (탭 = 정보창, 들고 꾹 = 빠른 넣기)
	if main.play_mode.mode == PlayMode.Mode.NORMAL and b != null and player.in_reach(b) and not (not sel.is_empty() and not _sel_has_cell(c)):
		press["player"] = true
		player.action_press(b)


func world_drag(index: int, sp: Vector2) -> bool:
	## 처리했으면 true (main은 그 손가락으로 아무것도 안 해요)
	if not owns(index):
		return false
	press["p"] = sp
	if state == "" and not press["held"] and not press["moved"] and (sp - press["p0"]).length() > DRAG_PX:
		press["moved"] = true   # 끌기: 10단계 둘러보기 자리
		if press["player"]:
			press["player"] = false
			player.action_abort()
	return state != ""


func world_release(index: int, sp: Vector2) -> void:
	if not owns(index):
		return
	press["p"] = sp
	match state:
		"select":
			_finish_select()
		"move":
			_drop()
		"gauge":
			main.hud.show_message("철거 취소")
		_:
			if press["player"]:
				player.action_release()
			elif not press["held"] and not press["moved"]:
				_tap(press["cell"], press["b"], sp)
	_end_press()


func abort() -> void:
	## 두 번째 손가락이 와서 핀치가 됐어요: 탭·꾹 없이 끝
	if press.is_empty() or state != "":
		return
	if press["player"]:
		player.action_abort()
	press = {}


func second_press(index: int) -> void:
	_second = {"index": index, "t": Time.get_ticks_msec()}


func second_release(index: int) -> bool:
	if _second.is_empty() or int(_second["index"]) != index:
		return false
	if state == "move" and Time.get_ticks_msec() - int(_second["t"]) < SECOND_TAP_SEC * 1000.0:
		rotate()
	_second = {}
	return true


func _tap(c: Vector2i, b, sp: Vector2) -> void:
	if not sel.is_empty() and not _sel_has_cell(c):
		clear_selection()
		return
	match main.play_mode.mode:
		PlayMode.Mode.DECONSTRUCT:
			if b != null:
				_say(b, "꾹 눌러서 철거")
		PlayMode.Mode.MOVE:
			if b != null:
				_say(b, "꾹 눌러서 옮기기")
		_:
			main.far_tap(sp)


func _on_hold() -> void:
	var b = press["b"]
	if press["src"] == "world" and b == null:
		state = "select"   # 빈 칸 꾹: 범위 선택
		sel_from = press["cell"]
		sel_to = sel_from
		return
	var m: int = main.play_mode.mode
	if m == PlayMode.Mode.NORMAL:
		return   # 일반 모드의 설비 꾹은 플레이어가 (빠른 넣기·뒤지기)
	if b == null:
		main.hud.show_message("대상이 없어요")
		return
	var group := in_sel(b)
	if not group and not factory.can_deconstruct(b):
		_say(b, "%s 수 없어요" % ("철거할" if m == PlayMode.Mode.DECONSTRUCT else "옮길"))
		return
	if not in_range_b(b):
		_say(b, "너무 멀어요")
		return
	var list: Array = sel.duplicate() if group else [b]
	if m == PlayMode.Mode.DECONSTRUCT:
		state = "gauge"
		gauge_t = 0.0
		gauge_list = list
		gauge_b = b
	else:
		_lift(list, b, press["cell"] if press["src"] == "world" else b.pos)


func _end_press() -> void:
	if state == "select":
		main.cam_pan_hold = false
	state = ""
	press = {}
	gauge_list = []
	gauge_b = null


# ---------- 상호작용 버튼 · F (이동·철거 모드) ----------

func button_press() -> bool:
	## 처리했으면 true (일반 모드는 플레이어가 받아요)
	if main.play_mode.mode == PlayMode.Mode.NORMAL or state != "":
		return false
	var t = player.shown_target()
	press = {"src": "button", "index": -9, "p": Vector2.ZERO, "p0": Vector2.ZERO, "t": 0.0, "cell": t.pos if t != null else Vector2i.ZERO, "b": t, "moved": false, "held": false, "player": false}
	_btn_off = Vector2.ZERO
	return true


func button_drag(off: Vector2) -> void:
	_btn_off = off


func button_active() -> bool:
	return press.get("src", "") == "button"


func button_release(cancel_zone: bool) -> void:
	if not button_active():
		return
	match state:
		"move":
			if cancel_zone:
				_snap_back(move_offset, "옮기기 취소")
			else:
				_drop()
		"gauge":
			main.hud.show_message("철거 취소")
		_:
			if not press["held"]:
				if press["b"] != null:
					_say(press["b"], "꾹 눌러서 %s" % ("철거" if main.play_mode.mode == PlayMode.Mode.DECONSTRUCT else "옮기기"))
				else:
					main.hud.show_message("가까이 있는 설비가 없어요")
	_end_press()


# ---------- 옮기기 ----------

func _lift(list: Array, b, c: Vector2i) -> void:
	state = "move"
	move_list = list
	grab_b = b
	grab = c
	move_rot = 0
	move_offset = Vector2i.ZERO
	snap = {}
	factory.set_held(list)
	_update_move()


func rotate() -> void:
	## 옮기는 중 회전 (한 개만, 묶음 회전은 TODO)
	if state != "move":
		return
	if move_list.size() > 1:
		main.hud.show_message("묶음 회전은 아직 없어요")
		return
	move_rot = (move_rot + 1) % 4


func _update_move() -> void:
	var aim: Vector2i
	if press.get("src", "") == "button":
		aim = grab + Vector2i((_btn_off / BuildController.DRAG_PX_PER_CELL).round())
	else:
		aim = main.screen_to_cell(press["p"])
	move_offset = aim - grab
	var why := ""
	var reasons: Array = factory.move_check(move_list, move_offset, move_rot)
	for r in reasons:
		if r != "":
			why = r
			break
	if why == "" and not _dest_in_range():
		why = "너무 멀어요"
	move_ok = why == ""
	var label := "설비 %d개" % move_list.size() if move_list.size() > 1 else ""
	view.ghost = _ghost_of(move_list, move_offset, move_rot, why, label)


func _dest_in_range() -> bool:
	var r: int = (grab_b.rot + move_rot) % 4
	for c in factory.footprint(grab_b.def, grab_b.pos + move_offset, r):
		if main.in_build_range(c):
			return true
	return false


func _ghost_of(list: Array, offset: Vector2i, rot: int, why: String, label := "") -> Dictionary:
	## view.ghost (설치 미리보기와 같은 모양): 하나라도 막히면 전체 빨강
	var cells := []
	for i in list.size():
		var e = list[i]
		var bad: bool = why != ""
		if e is Dictionary:
			cells.append({"pos": e["pos"] + offset, "rot": 0, "row": 0, "ok": not bad, "def": DB.buildings["전선" if e["layer"] == "wire" else "파이프"]})
		else:
			var r: int = (e.rot + rot) % 4
			cells.append({"pos": e.pos + offset, "rot": r, "row": r, "ok": not bad, "def": e.def})
	return {"build": true, "cells": cells, "line": list.size() > 1, "reason": why, "label": label, "anchor": null}


func _drop() -> void:
	if move_ok and factory.move_buildings(move_list, move_offset, move_rot):
		factory.set_held([])
		view.ghost = {}
		for i in sel.size():
			if sel[i] is Dictionary and move_list.has(sel[i]):
				sel[i] = {"layer": sel[i]["layer"], "pos": sel[i]["pos"] + move_offset}
		_feedback_place(move_list)
		main.hud.show_message("옮겼어요" if move_list.size() == 1 else "설비 %d개를 옮겼어요" % move_list.size())
	else:
		var why: String = view.ghost.get("reason", "")
		_snap_back(move_offset, "놓을 수 없어요" + (": " + why if why != "" else ""))


func _snap_back(offset: Vector2i, msg: String) -> void:
	## 원래 자리로 0.15초 스르륵
	snap = {"list": move_list, "from": Vector2(offset) * TILE, "t": 0.0}
	if msg != "":
		main.hud.show_message(msg)


func _feedback_place(list: Array) -> void:
	main.build._feedback([])
	for e in list:
		if e is Building:
			main.dust.puff(Vector2(e.pos) + Vector2(e.size) * 0.5)


# ---------- 철거 ----------

func _deconstruct(list: Array) -> void:
	var spots := []
	for e in list:
		if e is Building:
			spots.append([Vector2(e.pos) + Vector2(e.size) * 0.5, Vector2(e.size)])
		else:
			spots.append([Vector2(e["pos"]) + Vector2(0.5, 0.5), Vector2.ONE])
	var out: Array = factory.deconstruct_many(list)
	for s in spots:
		main.dust.burst(s[0], s[1])
	_sfx.play()
	Input.vibrate_handheld(40)
	main.hud.show_message("%d개 철거 · %d개가 바닥에 쏟아졌어요" % [list.size(), out.size()])


func deconstruct_selection() -> void:
	## 선택 바 [철거]·Delete: 잡은 설비가 없으니 플레이어에게 가장 가까운 선택 설비로 거리를 봐요
	if sel.is_empty():
		return
	var g = _nearest_sel(player.cell())
	if g != null and not in_range_b(g):
		main.hud.show_message("너무 멀어요")
		return
	_deconstruct(sel.duplicate())


func arm_move() -> void:
	## 선택 바 [이동]: 다음에 월드를 누른 곳에서 선택 전체를 들어요
	if sel.is_empty():
		return
	move_armed = true
	main.hud.show_message("옮길 곳으로 끌어 주세요")


func move_one(b) -> void:
	## 정보창 [이동]: 그 설비만 선택하고 바로 옮길 준비
	if b == null or not factory.can_move(b):
		main.hud.show_message("옮길 수 없어요")
		return
	sel = [b]
	arm_move()


# ---------- 범위 선택 ----------

func _finish_select() -> void:
	var r := Rect2i(Vector2i(mini(sel_from.x, sel_to.x), mini(sel_from.y, sel_to.y)), (sel_from - sel_to).abs() + Vector2i.ONE)
	var found := []
	for b in factory.buildings:
		if r.intersects(Rect2i(b.pos, b.size)) and factory.can_deconstruct(b):
			found.append(b)
	if view.show_layers:
		for layer in ["wire", "pipe"]:
			for c in (factory.wires if layer == "wire" else factory.pipes):
				if r.has_point(c):
					found.append({"layer": layer, "pos": c})
	if Input.is_key_pressed(KEY_SHIFT):
		for e in found:
			if not sel.has(e):
				sel.append(e)
	else:
		sel = found
	if sel.is_empty():
		main.hud.show_message("선택된 설비가 없어요")


func clear_selection() -> void:
	sel = []
	move_armed = false


func _sel_has_cell(c: Vector2i) -> bool:
	for e in sel:
		if (e is Building and e.has_cell(c)) or (e is Dictionary and e["pos"] == c):
			return true
	return false


func _nearest_sel(c: Vector2i):
	var best = null
	var bd := INF
	for e in sel:
		if e is Building:
			var d := Vector2(c).distance_to(Vector2(e.pos) + Vector2(e.size) * 0.5)
			if d < bd:
				bd = d
				best = e
	return best


func _edge_pan(dt: float, sp: Vector2) -> void:
	## 범위를 끄는 손가락이 화면 가장자리 15%에 닿으면 카메라가 그쪽으로
	var vs: Vector2 = main.get_viewport().get_visible_rect().size
	var d := Vector2.ZERO
	if sp.x < vs.x * EDGE:
		d.x = -1.0
	elif sp.x > vs.x * (1.0 - EDGE):
		d.x = 1.0
	if sp.y < vs.y * EDGE:
		d.y = -1.0
	elif sp.y > vs.y * (1.0 - EDGE):
		d.y = 1.0
	if d != Vector2.ZERO:
		main.cam_pan_hold = true
		main.cam_pan += d * EDGE_PAN_CELLS * TILE * dt


# ---------- 취소 · 안내 ----------

func cancel() -> bool:
	## 오른쪽 클릭·Esc: 하던 꾹 동작 → 들고 있던 것 → 선택 해제. 무언가 취소했으면 true
	match state:
		"move":
			_snap_back(move_offset, "옮기기 취소")
			_end_press()
			return true
		"gauge":
			main.hud.show_message("철거 취소")
			_end_press()
			return true
		"select":
			_end_press()
			return true
	if move_armed or not sel.is_empty():
		clear_selection()
		return true
	return false


func _say(b, text: String) -> void:
	## 설비 위 안내 말풍선
	hint = {"rect": Rect2(Vector2(b.pos) * TILE, Vector2(b.size) * TILE), "text": text, "t": HINT_SEC}


func _break_sound() -> AudioStreamWAV:
	## 짧은 '와작': 거친 잡음이 두 번 (코드로 만든 16비트 소리)
	var rate := 22050
	var n := int(rate * 0.16)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 30.0) + 0.6 * exp(-maxf(0.0, t - 0.06) * 45.0) * float(t > 0.06)
		var v := (rng.randf_range(-1.0, 1.0) * 0.8 + sin(TAU * 90.0 * t) * 0.5) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 28000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
