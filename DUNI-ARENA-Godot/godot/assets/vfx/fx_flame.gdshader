shader_type canvas_item;
render_mode unshaded, blend_mix;
// A small blaze: a tall centre tongue and two shorter side tongues, each carved from smooth noise
// that is warped and scrolls upward. Deep red edges, orange body, pale-yellow core.
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float intensity = 1.0;
uniform float seed = 0.0;
float tongue(vec2 uv, float centre, float height, float s) {
	float y = (1.0 - uv.y) / height;
	float x = (uv.x - centre) * 2.0 / height;
	vec2 warp = vec2(texture(noise_tex, vec2(uv.x * .35 + s, uv.y * .3 + clock * .45)).r,
		texture(noise_tex, vec2(uv.x * .35 + s + .5, uv.y * .3 + clock * .6)).r) - .5;
	float n = texture(noise_tex, vec2(uv.x * .8 + warp.x * .5 + s, uv.y * .7 + clock * 1.1 + warp.y * .4)).r;
	float n2 = texture(noise_tex, vec2(uv.x * 1.7 - s, uv.y * 1.5 + clock * 1.9)).r;
	float noise = n * .65 + n2 * .35;
	float width = mix(.55, .08, pow(clamp(y, 0.0, 1.0), .7));
	float body = 1.0 - smoothstep(width * .3, width, abs(x + warp.x * 1.2 * y));
	float heat = body * (1.35 - y * .95) + (noise - .5) * 2.0 * (.15 + y) * (.25 + body);
	return smoothstep(.1, .55, heat) * smoothstep(1.15, .75, y);
}
void fragment() {
	float fire = max(tongue(UV, .5, 1.0, seed), max(tongue(UV, .3, .62, seed + .31) * .9, tongue(UV, .7, .7, seed + .67) * .9));
	vec3 col = mix(vec3(.62, .08, .02), vec3(1.0, .42, .05), smoothstep(.08, .45, fire));
	col = mix(col, vec3(1.0, .9, .55), smoothstep(.6, .95, fire));
	COLOR = vec4(col, clamp(fire * 1.25, 0.0, 1.0) * smoothstep(0.0, .25, 1.0 - UV.y) * intensity);
}
