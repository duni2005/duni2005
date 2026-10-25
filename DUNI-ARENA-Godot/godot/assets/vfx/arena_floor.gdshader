shader_type canvas_item;
render_mode unshaded;
// Arena floor as a clean vector-style meadow, rendered once into a texture (see ArenaFloor).
// Coordinates are arena units: the 800-unit arena sits inside `margin` units of scenery.
// Flat colour areas with crisp edges: grass tones, a worn sandy path with stepping stones and
// puddles, sparse flowers and tufts; soft tree, bush and pillar shadows reaching in from the
// edges; outside, a bush fringe, rocks, rune pillars and round tree canopies.
uniform float margin = 320.0;

const vec3 GRASS = vec3(.42, .64, .26);
const vec3 GRASS_LIGHT = vec3(.50, .71, .30);
const vec3 GRASS_DARK = vec3(.36, .56, .23);
const vec3 SAND = vec3(.83, .78, .62);
const vec3 STONE = vec3(.86, .82, .70);
const vec3 SHADE = vec3(.68, .76, .72);

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * .1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = .5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= .5;
	}
	return v;
}
// Crisp edge for a signed distance in arena units (positive inside); one texel is ~1.4 units.
float fill(float d) {
	return smoothstep(-.8, .8, d);
}
// Signed distance to a lobed (cloud / bush) circle.
float lobed(vec2 v, float r, float lobes, float depth, float phase) {
	float a = atan(v.y, v.x);
	return r * (1.0 + depth * sin(a * lobes + phase) + depth * .5 * sin(a * (lobes * 2.0 + 1.0) + phase * 1.7)) - length(v);
}
mat2 turn(float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

float path_x(float y) {
	return 400.0 + 180.0 * sin(y * .0055 + 1.1) + 45.0 * sin(y * .017 + 2.0);
}
// A worn path winding down the arena with a branch to the right; grass breaks across it.
float path(vec2 p) {
	float d = 28.0 + 12.0 * noise(vec2(p.y * .012, 3.0)) - abs(p.x - path_x(p.y));
	float y2 = 600.0 + 60.0 * sin(p.x * .008);
	float d2 = 22.0 + 8.0 * noise(vec2(p.x * .015, 7.0)) - abs(p.y - y2);
	if (p.x > path_x(600.0)) d = max(d, d2);
	d += (noise(p * .16) - .5) * 8.0;
	d -= smoothstep(.66, .8, noise(vec2(p.y * .01 + p.x * .004, 1.0))) * 50.0;
	return d;
}

vec3 meadow(vec2 p) {
	// Two or three flat grass tones in broad, clean-edged patches.
	float t = fbm(p * .0032);
	vec3 col = mix(GRASS, GRASS_LIGHT, fill((t - .56) * 260.0));
	col = mix(col, GRASS_DARK, fill((.34 - t) * 260.0));
	// Sparse grass tufts: three short blades.
	vec2 g = floor(p / 30.0);
	if (hash(g + 1.3) > .86) {
		vec2 q = p - (g + .2 + hash2(g + 2.0) * .6) * 30.0;
		float blades = 0.0;
		for (int k = -1; k <= 1; k++) {
			float lean = float(k) * .45;
			float along = clamp(-q.y, 0.0, 7.0 - abs(float(k)) * 2.0);
			blades = max(blades, fill(1.0 - length(q - vec2(lean * along + float(k) * 1.5, -along))));
		}
		col = mix(col, GRASS_DARK * .9, blades * .8);
	}
	return col;
}

void sand_and_stones(vec2 p, inout vec3 col) {
	float d = path(p);
	col = mix(col, SAND, fill(d));
	col = mix(col, SAND * .93, fill(d) * fill(4.0 - d) * .6);
	// Puddles sitting on the path, ringed with sand.
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? 280.0 : 650.0;
		vec2 c = vec2(path_x(y) + (k == 0 ? -18.0 : 22.0), y);
		vec2 v = (p - c) * vec2(1.0, 1.45);
		float rim = lobed(v, 46.0, 3.0, .12, float(k) * 2.0);
		float water = lobed(v, 34.0, 3.0, .12, float(k) * 2.0);
		col = mix(col, SAND * 1.02, fill(rim));
		col = mix(col, vec3(.60, .78, .74), fill(water));
		col = mix(col, vec3(.72, .86, .82), fill(water) * fill(lobed(v - vec2(-9.0, -7.0), 18.0, 2.0, .1, 1.0)));
	}
	// Flat stepping stones, mostly along the path.
	vec2 cell = floor(p / 64.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = cell + vec2(float(i), float(j));
			vec2 c = (g + .25 + hash2(g) * .5) * 64.0;
			float on_path = step(-24.0, path(c));
			if (hash(g + 2.0) > .12 + on_path * .5) continue;
			float rx = 11.0 + hash(g + 6.0) * 11.0;
			float ry = rx * (.6 + hash(g + 7.0) * .3);
			mat2 m = turn(hash(g + 5.0) * 3.14);
			vec2 q = m * (p - c);
			vec2 qs = m * (p - c - vec2(2.0, 4.0));
			float shadow = (1.0 - length(qs / vec2(rx, ry))) * ry;
			float stone = (1.0 - length(q / vec2(rx, ry))) * ry;
			col = mix(col, col * .78, fill(shadow) * (1.0 - fill(stone)));
			vec3 face = mix(STONE * .9, STONE, fill(stone - 2.5));
			col = mix(col, face, fill(stone));
		}
	}
	// Tiny flowers on the grass.
	vec2 f = floor(p / 26.0);
	if (hash(f + 8.0) > .9 && d < -6.0) {
		vec2 o = (f + .25 + hash2(f + 9.0) * .5) * 26.0;
		vec3 petal = hash(f + 3.0) > .4 ? vec3(.96, .95, .9) : vec3(.98, .88, .5);
		col = mix(col, petal, fill(2.2 - length(p - o)));
	}
}

// Shade cast into the arena by trees, bushes and pillars outside it (down-right light).
float edge_shade(vec2 p) {
	float shade = 0.0;
	// Big canopy shadows reaching in from beyond each edge.
	for (int side = 0; side < 4; side++) {
		float along = side < 2 ? p.x : p.y;
		float across = side == 0 ? p.y : side == 1 ? 800.0 - p.y : side == 2 ? p.x : 800.0 - p.x;
		float slot = floor(along / 190.0);
		for (int k = -1; k <= 1; k++) {
			float s = slot + float(k);
			if (hash(vec2(s, float(side) + 40.0)) < .3) continue;
			float centre = (s + .2 + hash(vec2(s, float(side) + 41.0)) * .6) * 190.0;
			float r = 70.0 + hash(vec2(s, float(side) + 42.0)) * 50.0;
			vec2 v = vec2(along - centre, across + r * .45);
			shade = max(shade, fill(lobed(v, r, 6.0, .07, s * 3.0 + float(side))));
		}
	}
	// Thin shade right under the bush fringe.
	float inside = min(min(p.x, 800.0 - p.x), min(p.y, 800.0 - p.y));
	shade = max(shade, (1.0 - smoothstep(0.0, 12.0, inside)) * .7);
	// Rune pillar shadows.
	for (int k = 0; k < 4; k++) {
		vec2 base = k == 0 ? vec2(320.0, -34.0) : k == 1 ? vec2(480.0, -34.0) : k == 2 ? vec2(-34.0, 520.0) : vec2(834.0, 280.0);
		// Slanted down-right, away from the light.
		vec2 q = p - base;
		q.x -= max(q.y, 0.0) * .45;
		shade = max(shade, fill(min(min(q.x + 13.0, 13.0 - q.x), min(q.y, 74.0 - q.y))));
	}
	return shade;
}

vec3 bush(vec2 v, float r, float seed, vec3 col) {
	float body = lobed(v, r, 5.0, .12, seed);
	float top = lobed(v + vec2(r * .22, r * .26), r * .62, 4.0, .14, seed + 1.0);
	col = mix(col, vec3(.20, .40, .22), fill(body));
	col = mix(col, vec3(.28, .51, .27), fill(body - 3.0));
	col = mix(col, vec3(.40, .63, .32), fill(top));
	return col;
}

void scenery(vec2 p, float out_d, inout vec3 col) {
	// Ground beyond the arena: darker grass.
	col = mix(GRASS_DARK * .92, GRASS_DARK, fill((fbm(p * .004) - .5) * 200.0));
	// Rocks and stones scattered about.
	vec2 g = floor(p / 90.0);
	vec2 c = (g + .25 + hash2(g + 30.0) * .5) * 90.0;
	float cd = max(max(-c.x, c.x - 800.0), max(-c.y, c.y - 800.0));
	if (hash(g + 31.0) > .78 && cd > 50.0) {
		vec2 v = (p - c) * vec2(1.0, 1.3);
		float r = 9.0 + hash(g + 32.0) * 9.0;
		col = mix(col, col * .7, fill(lobed(v - vec2(4.0, 6.0), r, 3.0, .1, 1.0)));
		col = mix(col, vec3(.58, .62, .64), fill(lobed(v, r, 3.0, .1, 1.0)));
		col = mix(col, vec3(.74, .77, .77), fill(lobed(v + vec2(2.0, 3.0), r * .7, 3.0, .1, 1.0)));
	}
	// Tree shadows, then canopies, on a coarse grid that thickens away from the arena.
	vec2 cell = floor(p / 120.0);
	for (int pass = 0; pass < 2; pass++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 t = cell + vec2(float(i), float(j));
				vec2 tc = (t + .2 + hash2(t + 3.0) * .6) * 120.0;
				float td = max(max(-tc.x, tc.x - 800.0), max(-tc.y, tc.y - 800.0));
				float r = 48.0 + hash(t + 4.0) * 28.0;
				if (td < r + 42.0 || hash(t + 11.0) > .45 + smoothstep(120.0, 260.0, td) * .5) continue;
				vec2 v = p - tc;
				if (pass == 0) {
					col = mix(col, col * SHADE * .9, fill(lobed(v - vec2(26.0, 34.0), r * 1.02, 7.0, .06, hash(t) * 9.0)));
				} else {
					float body = lobed(v, r, 7.0, .06, hash(t) * 9.0);
					float mid = lobed(v + vec2(r * .12, r * .16), r * .78, 6.0, .08, hash(t) * 7.0);
					float top = lobed(v + vec2(r * .3, r * .34), r * .42, 5.0, .1, hash(t) * 5.0);
					bool golden = hash(t + 21.0) > .86;
					col = mix(col, golden ? vec3(.62, .46, .18) : vec3(.15, .35, .25), fill(body));
					col = mix(col, golden ? vec3(.82, .63, .24) : vec3(.22, .47, .30), fill(mid));
					col = mix(col, golden ? vec3(.93, .80, .42) : vec3(.36, .60, .34), fill(top));
				}
			}
		}
	}
	// Bush fringe hugging the arena edge.
	bool vertical_side = abs(p.x - 400.0) > abs(p.y - 400.0);
	float along = vertical_side ? p.y : p.x;
	float slot = floor(along / 40.0);
	for (int k = -1; k <= 1; k++) {
		float s = slot + float(k);
		vec2 seed = vec2(s, vertical_side ? 50.0 : 60.0) + (p.x + p.y > 800.0 ? 7.0 : 0.0);
		if (hash(seed) < .14) continue;
		float r = 15.0 + hash(seed + 1.0) * 10.0;
		float centre = (s + .5 + (hash(seed + 2.0) - .5) * .4) * 40.0;
		vec2 v = vertical_side ? vec2(out_d - (r + 4.0), along - centre) : vec2(along - centre, out_d - (r + 4.0));
		if (vertical_side && p.x < 400.0) v.x = -v.x;
		if (!vertical_side && p.y < 400.0) v.y = -v.y;
		col = mix(col, col * .72, fill(lobed(v - vec2(5.0, 7.0), r, 5.0, .12, s)));
		col = bush(v, r, s, col);
	}
	// Rune pillars: grey stone with a lit cap and a glowing cyan mark.
	for (int k = 0; k < 4; k++) {
		vec2 base = k == 0 ? vec2(320.0, -34.0) : k == 1 ? vec2(480.0, -34.0) : k == 2 ? vec2(-34.0, 520.0) : vec2(834.0, 280.0);
		vec2 q = p - base;
		if (abs(q.x) < 15.0 && abs(q.y) < 17.0) {
			col = q.y < -7.0 ? vec3(.74, .77, .78) : vec3(.56, .60, .63);
			float rune = 5.5 - (abs(q.x) + abs(q.y - 3.0));
			col = mix(col, vec3(.55, .95, 1.0), fill(rune) * (1.0 - fill(rune - 2.5) * .6));
		}
	}
}

void fragment() {
	vec2 p = UV * (800.0 + margin * 2.0) - margin;
	float out_d = max(max(-p.x, p.x - 800.0), max(-p.y, p.y - 800.0));
	vec3 col;
	if (out_d <= 0.0) {
		col = meadow(p);
		sand_and_stones(p, col);
		col = mix(col, col * SHADE, edge_shade(p));
	} else {
		scenery(p, out_d, col);
	}
	// A touch dimmer and warmer than the raw palette.
	col *= vec3(.95, .93, .88);
	COLOR = vec4(col, 1.0);
}
