class_name Settings
extends RefCounted
## 기기별 설정 (user://settings.cfg). 게임 저장과는 따로예요.
##   ui_scale   : UI 확대 0.8~1.5
##   input_mode : "auto"(터치·키보드 자동 전환) / "touch" / "keyboard"

const PATH := "user://settings.cfg"
const UI_SCALE_MIN := 0.8
const UI_SCALE_MAX := 1.5
const UI_SCALE_STEP := 0.1
const INPUT_MODES := ["auto", "touch", "keyboard"]

var ui_scale := 1.0
var input_mode := "auto"


func load_file() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	ui_scale = clampf(float(cf.get_value("ui", "scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)
	var m := str(cf.get_value("input", "mode", "auto"))
	input_mode = m if m in INPUT_MODES else "auto"


func save_file() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ui", "scale", ui_scale)
	cf.set_value("input", "mode", input_mode)
	cf.save(PATH)


func step_scale(dir: int) -> void:
	ui_scale = clampf(snappedf(ui_scale + dir * UI_SCALE_STEP, UI_SCALE_STEP), UI_SCALE_MIN, UI_SCALE_MAX)
	save_file()


func next_input_mode() -> void:
	input_mode = INPUT_MODES[(INPUT_MODES.find(input_mode) + 1) % INPUT_MODES.size()]
	save_file()
