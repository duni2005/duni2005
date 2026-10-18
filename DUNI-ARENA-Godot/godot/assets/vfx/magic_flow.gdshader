shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D flow_noise : repeat_enable, filter_linear;
uniform float clock = 0.0;
uniform float strength = 1.0;
uniform int kind = 0;
uniform vec4 tint : source_color = vec4(.6, .4, 1., 1.);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float rim = 1.0 - smoothstep(.88, 1.0, r);
	float angle = atan(p.y, p.x);
	float grain = texture(flow_noise, p * .65 + vec2(clock * .03, -clock * .07)).r;
	float light = 0.0;
	vec3 ink = tint.rgb;
	if (kind == 0) {
		float noise = texture(flow_noise, vec2(r * .7 - clock * .12, angle * .2 + clock * .04)).r;
		float spiral = pow(max(0., sin(angle * 5.0 + r * 18.0 - clock * 2.7 + noise * 3.0)), 5.0);
		float ring = exp(-abs(r - .255) * 100.0);
		light = spiral * rim * smoothstep(.22, .4, r) * (.18 + grain * .4) + ring * .6;
		ink = mix(vec3(.35,.18,.9), vec3(.9,.7,1.), spiral * .55 + ring * .4);
	} else if (kind == 1) {
		vec2 flow = vec2(p.x * .32, p.y * .6 + clock * .26);
		float n = texture(flow_noise, flow + vec2(sin(p.y*4. + clock)*.08, 0.)).r;
		float hot = smoothstep(.32, .74, n) * rim;
		float plume = pow(max(0., cos(p.x * 12.0 + n * 4.0)), 4.0);
		light = plume * hot * .5;
		ink = mix(vec3(1.,.18,.025), vec3(1.,.85,.3), hot);
	} else if (kind == 2) {
		float stream = pow(max(0., sin(angle * 6.0 - r * 9.0 + clock)), 10.0);
		float wave = exp(-abs(fract(r * 1.4 - clock * .12) - .6)*40.);
		light = (stream * .12 + wave * .12) * rim * smoothstep(.12, .6, r);
		ink = mix(tint.rgb, vec3(.8,1.,.88), grain * .4);
	} else {
		float spiral = pow(max(0., cos(angle * 4.0 + r * 11.0 - clock * .5 + grain * 2.0)), 8.0);
		light = spiral * rim * (.15 + grain * .24);
		ink = mix(vec3(.22,.28,.9), vec3(.8,.65,1.), grain);
	}
	COLOR = vec4(ink, clamp(light * strength, 0., .7));
}
