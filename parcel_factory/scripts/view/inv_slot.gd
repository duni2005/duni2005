extends Control
## 인벤토리 칸 하나 (가방 창·핫바·크리에이티브 보관함이 함께 써요). 16×16 아이콘 + 개수.
## 이 칸은 무슨 일이 있었는지 신호로 알리기만 하고, 실제로 바꾸는 건 가방 창·핫바가 해요.
##   클릭/탭 → clicked(i, shift) · 오른쪽 클릭 → split(i) · 길게 누르기 → split(i)
##   끌어다 놓기 → moved(from, to) · 창 밖으로 끌어 놓기 → dragged_out(i) · 위로 쓸기 → swiped_up

signal clicked(index: int, shift: bool)
signal split(index: int)
signal moved(from_index: int, to_index: int)
signal dragged_out(index: int)
signal swiped_up

const SIZE := 64.0
const ICON := 48.0           # 16×16 아이콘 3배
const LONG_PRESS := 0.5      # 길게 누르기 (초)
const SWIPE := 40.0          # 이만큼 위로 쓸면 swiped_up

var index := -1
var draggable := true
var id := ""                 # 보여줄 아이템 ("" = 빈 칸)
var count := 0
var picked := false          # 교환하려고 먼저 고른 칸 (노란 테두리)
var held := false            # 손에 든 핫바 칸 (주황 테두리)
var _press := false
var _press_t := 0.0
var _press_pos := Vector2.ZERO
var _long_fired := false
var _dragging := false


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func show_item(p_id: String, p_count: int) -> void:
	if p_id != id or p_count != count:
		id = p_id
		count = p_count
		queue_redraw()


func set_marks(p_picked: bool, p_held: bool) -> void:
	if p_picked != picked or p_held != held:
		picked = p_picked
		held = p_held
		queue_redraw()


func _process(dt: float) -> void:
	if not _press:
		return
	_press_t += dt
	if not _long_fired and not _dragging and _press_t >= LONG_PRESS and id != "":
		_long_fired = true
		split.emit(index)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			split.emit(index)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = true
				_press_t = 0.0
				_press_pos = mb.position
				_long_fired = false
			elif _press:
				_press = false
				if not _long_fired and not _dragging:
					clicked.emit(index, mb.shift_pressed)
			accept_event()
	elif e is InputEventMouseMotion and _press:
		var mm := e as InputEventMouseMotion
		if _press_pos.y - mm.position.y > SWIPE and absf(mm.position.x - _press_pos.x) < SWIPE:
			_press = false
			_long_fired = true
			swiped_up.emit()


func _get_drag_data(_at: Vector2):
	if not draggable or id == "":
		return null
	_dragging = true
	_press = false
	var prev := TextureRect.new()
	prev.texture = Art.item_icon(id, 16)
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.size = Vector2(ICON, ICON)
	prev.position = -Vector2(ICON, ICON) * 0.5
	var holder := Control.new()
	holder.add_child(prev)
	set_drag_preview(holder)
	return {"inv_slot": index}


func _can_drop_data(_at: Vector2, data) -> bool:
	return draggable and data is Dictionary and data.has("inv_slot")


func _drop_data(_at: Vector2, data) -> void:
	moved.emit(int(data["inv_slot"]), index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		if not get_viewport().gui_is_drag_successful():
			dragged_out.emit(index)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.c(Palette.G1))
	var border := Palette.c(Palette.G3)
	if held:
		border = Palette.c(Palette.ORANGE)
	if picked:
		border = Palette.c(Palette.YELLOW)
	draw_rect(r.grow(-1), border, false, 3.0 if (held or picked) else 2.0)
	if id == "":
		return
	var tex := Art.item_icon(id, 16)
	var ir := Rect2((size - Vector2(ICON, ICON)) * 0.5 - Vector2(0, 3), Vector2(ICON, ICON))
	var ts := tex.get_size()
	if ts.x != ts.y:
		# 출하 도크처럼 가로로 긴 그림은 비율을 지켜요
		var k := minf(ICON / ts.x, ICON / ts.y)
		ir = Rect2(ir.get_center() - ts * k * 0.5, ts * k)
	draw_texture_rect(tex, ir, false)
	if count > 1:
		var font := ThemeDB.fallback_font
		var txt := str(count)
		var fs := 18
		var p := Vector2(4, size.y - 6)
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, fs, 4, Palette.c(Palette.INK))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, fs, Palette.c(Palette.PAPER))
