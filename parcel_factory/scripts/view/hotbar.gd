extends HBoxContainer
## 화면 아래 가운데 핫바 9칸 + 오른쪽 가방 버튼.
## 탭 = 그 칸 고르기(손에 들기), 같은 칸 다시 = 맨손, 위로 쓸기·가방 버튼 = 가방 열기.
## 플레이어·인벤토리는 읽기만 하고, 고르기는 player.select_hotbar()로 해요.

signal open_bag

const InvSlot := preload("res://scripts/view/inv_slot.gd")

var player = null
var _slots: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in Inventory.HOTBAR:
		var s = InvSlot.new()
		s.index = i
		s.draggable = false
		s.clicked.connect(func(idx, _sh) -> void: player.select_hotbar(idx))
		s.split.connect(func(_idx) -> void: pass)   # 핫바에선 길게 눌러도 나누지 않아요
		s.swiped_up.connect(func() -> void: open_bag.emit())
		add_child(s)
		_slots.append(s)
	var bag := Button.new()
	bag.text = "가방"
	bag.focus_mode = Control.FOCUS_NONE
	bag.custom_minimum_size = Vector2(88, InvSlot.SIZE)
	bag.pressed.connect(func() -> void: open_bag.emit())
	add_child(bag)
	player.inventory.changed.connect(refresh)
	player.hotbar_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var inv: Inventory = player.inventory
	for i in _slots.size():
		var e = inv.slots[i]
		_slots[i].show_item("" if e == null else e["id"], 0 if e == null else int(e["n"]))
		_slots[i].set_marks(false, i == player.hotbar)
