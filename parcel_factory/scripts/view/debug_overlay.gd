extends PanelContainer
## 디버그 오버레이 (F3 또는 왼쪽 위 'F3' 버튼).
## FPS · 틱/초 · 설비 수 · 레일 위 물건 수 · 전력망별 공급/수요를 보여줘요.
## 시뮬레이션 상태는 읽기만 해요.

const REFRESH_SEC := 0.5    # 글자를 고치는 간격 (틱/초도 이 간격으로 재요)
const MAX_NETS := 6         # 화면에 보여줄 전력망 수 (나머지는 개수만)
const FONT_SIZE := 16

var factory: Factory = null
var _label: Label
var _t := 0.0
var _last_ticks := 0
var _tps := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_content_margin_all(8)
	add_theme_stylebox_override("panel", sb)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible and factory != null:
		_last_ticks = factory.tick_count
		_t = 0.0
		_tps = 0.0
		_refresh()


func _process(dt: float) -> void:
	if not visible or factory == null:
		return
	_t += dt
	if _t < REFRESH_SEC:
		return
	var ticks: int = factory.tick_count
	_tps = float(ticks - _last_ticks) / _t
	_last_ticks = ticks
	_t = 0.0
	_refresh()


func _refresh() -> void:
	var lines := []
	lines.append("FPS %d · 틱/초 %.1f (기준 %d × 속도 %s)" % [Engine.get_frames_per_second(), _tps, int(round(1.0 / Factory.DT)), _speed_text()])
	lines.append("설비 %d · 레일 위 물건 %d · 크리에이티브 %s" % [factory.buildings.size(), factory.items_on_rails(), "켬" if factory.creative else "끔"])
	lines.append("전력망 %d개" % factory.power_nets.size())
	var i := 0
	for net in factory.power_nets:
		if i >= MAX_NETS:
			lines.append("  …외 %d개" % (factory.power_nets.size() - MAX_NETS))
			break
		var sup: float = net["supply"]
		var dem: float = net["demand"]
		var sat: float = net["sat"]
		lines.append("  망 %d: 공급 %d / 수요 %d · %d%% · 설비 %d" % [i + 1, int(sup), int(dem), int(round(sat * 100.0)), net["buildings"].size()])
		i += 1
	_label.text = "\n".join(lines)


func _speed_text() -> String:
	if factory.paused:
		return "멈춤"
	return "×%d" % int(factory.speed)
