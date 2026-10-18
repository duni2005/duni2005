class_name ArenaModalBackdrop
extends ColorRect
## UI-only blur/dim behind a Window; does not pause any gameplay clock.
func _init() -> void:
	var shader:=Shader.new();shader.code="shader_type canvas_item; uniform sampler2D image : hint_screen_texture, filter_linear_mipmap; void fragment(){ COLOR=vec4(textureLod(image,SCREEN_UV,2.0).rgb*0.32,1.0); }"
	var fx:=ShaderMaterial.new();fx.shader=shader;material=fx;mouse_filter=Control.MOUSE_FILTER_STOP;z_index=200
func connect_window(window: Window,parent: Control) -> void:
	parent.add_child(self);set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hide()
	window.about_to_popup.connect(show);window.visibility_changed.connect(func():if not window.visible:hide())
