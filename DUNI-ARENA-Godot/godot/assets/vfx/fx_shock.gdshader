shader_type canvas_item;
render_mode unshaded, blend_mix;
// Expanding shockwave: a noisy bright front, a white-hot core flash and radial streaks.
// cone > 0 throws most of the energy toward `angle` (a punch); 0 is a full ring (a landing).
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform float progress = 0.0;
uniform float clock = 0.0;
uniform float angle = 0.0;
uniform float cone = 0.0;
uniform vec4 tint : source_color = vec4(1.0, .72, .3, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = clamp(progress, 0.0, 1.0);
	float front = (1.0 - pow(1.0 - t, 3.0)) * .9;
	float n = texture(noise_tex, vec2(a * .16 + clock * .03, r * .3 - clock * .35)).r;
	float width = mix(.1, .03, t);
	float ring = exp(-pow((r - front + (n - .5) * .09) / width, 2.0));
	float dir = 1.0;
	if (cone > 0.0) {
		float d = cos(a - angle);
		dir = mix(1.0, smoothstep(-.35, .95, d) * 1.7 + .12, cone);
	}
	float flash = exp(-r * r * 34.0) * pow(1.0 - t, 2.5) * 1.5;
	float streaks = pow(max(0.0, sin(a * 23.0 + n * 7.0)), 14.0) * smoothstep(front + .05, front * .25, r) * pow(1.0 - t, 1.5) * dir;
	float inner = smoothstep(front, 0.0, r) * (1.0 - t) * .07 * (.4 + n);
	float light = ring * (1.15 - t) * dir + flash + streaks * .75 + inner * dir;
	vec3 hot = mix(tint.rgb, vec3(1.0, .97, .88), clamp(flash + ring * .45, 0.0, 1.0));
	COLOR = vec4(hot, clamp(light, 0.0, .95) * step(r, 1.0));
}
