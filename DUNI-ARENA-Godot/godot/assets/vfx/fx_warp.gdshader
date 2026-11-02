shader_type canvas_item;
// Heat-haze ring: bends what is behind the shockwave front.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float progress = 0.0;
uniform float strength = .012;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = clamp(progress, 0.0, 1.0);
	float front = (1.0 - pow(1.0 - t, 3.0)) * .9;
	float w = exp(-pow((r - front) / .09, 2.0)) * (1.0 - t);
	vec2 off = (p / max(r, .001)) * w * strength;
	vec4 behind = texture(screen_tex, SCREEN_UV - off);
	COLOR = vec4(behind.rgb, clamp(w * 3.0, 0.0, 1.0) * step(r, 1.0));
}
