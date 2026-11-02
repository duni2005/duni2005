shader_type canvas_item;
render_mode unshaded, blend_mix;
// Lightning between the quad's ends (UV.x 0..1): a jagged path that re-forms many times a second,
// a white core and a soft blue glow.
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float fade = 1.0;
uniform float seed = 0.0;
uniform vec4 tint : source_color = vec4(.55, .82, 1.0, 1.0);
// Zigzag: straight segments between noisy kink points (coarse K and fine K2), re-rolled each frame.
float kinks(float x, float k, float row, float s) {
	float i = floor(x * k);
	float a = texture(noise_tex, vec2(i * .61 + s, row + i * .37)).r;
	float b = texture(noise_tex, vec2((i + 1.0) * .61 + s, row + (i + 1.0) * .37)).r;
	return (mix(a, b, fract(x * k)) - .5) * 2.6;
}
void fragment() {
	float x = UV.x;
	float y = UV.y * 2.0 - 1.0;
	float frame = floor(clock * 22.0);
	float jag = kinks(x, 8.0, frame * .137, seed) * .6 + kinks(x, 23.0, frame * .311, seed * 1.7) * .16;
	float env = sin(x * 3.14159);
	float d = abs(y - jag * env);
	float branch = abs(y - (jag * env + kinks(x, 11.0, frame * .21, -seed) * .55 * smoothstep(.3, .9, x)));
	float core = exp(-d * d * 70.0) + exp(-branch * branch * 200.0) * .6 * smoothstep(.35, .7, x);
	float glow = exp(-d * d * 10.0) * .7 + exp(-d * 3.5) * .25;
	vec3 col = mix(vec3(.2, .45, 1.0), mix(tint.rgb, vec3(1.0), clamp(core * 1.2, 0.0, 1.0)), clamp(core + glow * .6, 0.0, 1.0));
	COLOR = vec4(col, clamp(core * 1.6 + glow, 0.0, 1.0) * fade);
}
