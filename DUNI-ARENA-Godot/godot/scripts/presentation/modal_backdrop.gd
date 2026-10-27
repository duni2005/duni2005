class_name ArenaModalBackdrop
extends ColorRect
## UI-only blur/dim behind a Window; does not pause any gameplay clock.
## It darkens in as the window opens and clears faster as it closes, letting taps through while it does.
var fading: Tween
func _init() -> void:
	var shader:=Shader.new();shader.code="shader_type canvas_item; uniform sampler2D image : hint_screen_texture, filter_linear_mipmap; void fragment(){ COLOR=vec4(textureLod(image,SCREEN_UV,2.0).rgb*0.32,1.0); }"
	var fx:=ShaderMaterial.new();fx.shader=shader;material=fx;mouse_filter=Control.MOUSE_FILTER_STOP;z_index=200
func connect_window(window: Window,parent: Control) -> void:
	parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hide()
	window.about_to_popup.connect(_open);window.visibility_changed.connect(func():if not window.visible:_close())
func _open() -> void:
	if fading!=null:fading.kill()
	show();mouse_filter=Control.MOUSE_FILTER_STOP;modulate.a=1
	if not UiMotion.enabled:return
	modulate.a=0;fading=create_tween();Motion.enter_curve(fading.tween_property(self,"modulate:a",1.0,Motion.ENTER*.8))
func _close() -> void:
	if fading!=null:fading.kill()
	if not UiMotion.enabled or not visible:hide();return
	mouse_filter=Control.MOUSE_FILTER_IGNORE;fading=create_tween()
	Motion.exit_curve(fading.tween_property(self,"modulate:a",0.0,Motion.EXIT*.6));fading.tween_callback(hide)
