shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Arena floor as a clean vector-style meadow, rendered once into textures (see ArenaFloor).
// Coordinates are arena units: the 800-unit arena sits inside `margin` units of scenery.
// layer 0: the floor — flat grass tones, a winding worn path with a few stepping stones and
//          puddles, sparse flowers and tufts, the static shade of the bush fringe, pillars and
//          towers; outside, a bush fringe, rocks, rune pillars, round stone towers and trees.
// layer 1, 2: two sets of canopy shadows as an alpha mask; drawn every frame with a little
//          sway so the shade moves like leaves in the wind.
uniform float margin = 320.0;
uniform int layer = 0;

const vec3 GRASS = vec3(.42, .64, .26);
const vec3 GRASS_LIGHT = vec3(.50, .71, .30);
const vec3 GRASS_DARK = vec3(.36, .56, .23);
const vec3 SAND = vec3(.83, .77, .60);
const vec3 STONE = vec3(.86, .82, .70);
const vec3 SHADE = vec3(.60, .70, .66);

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
float outside(vec2 c) {
	return max(max(-c.x, c.x - 800.0), max(-c.y, c.y - 800.0));
}

float path_x(float y) {
	return 400.0 + 180.0 * sin(y * .0055 + 1.1) + 45.0 * sin(y * .017 + 2.0);
}
// A broad worn path winding down the arena with branches left and right; grass breaks it here
// and there.
float path(vec2 p) {
	float d = 36.0 + 14.0 * noise(vec2(p.y * .012, 3.0)) - abs(p.x - path_x(p.y));
	float right = 28.0 + 10.0 * noise(vec2(p.x * .015, 7.0)) - abs(p.y - (600.0 + 60.0 * sin(p.x * .008)));
	if (p.x > path_x(600.0)) d = max(d, right);
	float left = 26.0 + 10.0 * noise(vec2(p.x * .013, 11.0)) - abs(p.y - (220.0 + 55.0 * sin(p.x * .01 + 1.0)));
	if (p.x < path_x(220.0)) d = max(d, left);
	d += (noise(p * .16) - .5) * 8.0;
	d -= smoothstep(.8, .9, noise(vec2(p.y * .01 + p.x * .004, 1.0))) * 50.0;
	return d;
}

// Round stone towers around the arena on a coarse grid: x, y = top centre, z = radius,
// w = body height (0 when the cell has none).
vec4 tower_in(vec2 cell) {
	vec2 c = (cell + .25 + hash2(cell + 70.0) * .5) * 210.0;
	float r = 26.0 + hash(cell + 71.0) * 14.0;
	float h = 70.0 + hash(cell + 73.0) * 60.0;
	// The body hangs below the top centre, so keep the whole tower clear of the arena.
	if (min(outside(c), outside(c + vec2(0.0, h + r))) < r + 26.0 || hash(cell + 72.0) > .7) return vec4(0.0);
	return vec4(c, r, h);
}
// Distance to a tower's long shadow falling down-right from its foot.
float tower_shadow(vec2 p, vec4 t) {
	vec2 foot = t.xy + vec2(0.0, t.w);
	vec2 dir = vec2(.85, .42) * t.w * 1.1;
	float h = clamp(dot(p - foot, dir) / dot(dir, dir), 0.0, 1.0);
	return t.z * (1.0 - h * .25) - length(p - foot - dir * h);
}
void draw_tower(vec2 p, vec4 t, float seed, inout vec3 col) {
	float r = t.z;
	vec2 q = p - t.xy;
	float ry = r * .45;
	// Body: a cylinder seen from above and in front, lit from the left.
	float body = min(r - abs(q.x), min(q.y, t.w - q.y + ry * sqrt(max(0.0, 1.0 - q.x * q.x / (r * r)))));
	if (body > -1.0) {
		float u = clamp(q.x / r, -1.0, 1.0);
		vec3 lit = vec3(.82, .79, .72);
		vec3 dark = vec3(.47, .50, .55);
		vec3 stone = mix(lit, dark, smoothstep(-.5, .95, u));
		float curve = ry * sqrt(max(0.0, 1.0 - u * u));
		float course = fract((q.y - curve) / 11.0);
		stone *= 1.0 - .12 * (1.0 - fill(min(course, 1.0 - course) * 11.0 - .6));
		float joint = fract(asin(u) * 2.2 + floor((q.y - curve) / 11.0) * .5);
		stone *= 1.0 - .08 * (1.0 - fill(min(joint, 1.0 - joint) * 14.0 - .5));
		// Arrow slits, an arched door at the foot, some ivy.
		for (int k = 0; k < 2; k++) {
			vec2 slit = vec2(q.x + r * (.1 - float(k) * .35), q.y - t.w * (.3 + float(k) * .28));
			stone = mix(stone, vec3(.2, .22, .26), fill(min(2.5 - abs(slit.x), 6.0 - abs(slit.y))));
		}
		vec2 door = vec2(q.x + r * .05, q.y - t.w - curve);
		float arch = min(7.0 - abs(door.x), -door.y) ;
		arch = max(arch, 7.0 - length(door + vec2(0.0, 14.0)));
		stone = mix(stone, vec3(.24, .2, .18), fill(min(arch, 20.0 + door.y)) * step(.5, hash(t.xy)));
		stone = mix(stone, vec3(.33, .52, .28), fill((fbm(p * .08 + seed) - .62) * 60.0) * step(.0, q.y - t.w * .4));
		col = mix(col, stone, fill(body));
	}
	vec2 e = q / vec2(r, ry);
	float top = (1.0 - length(e)) * ry;
	if (seed > .55) {
		// A slate cone roof, lit on the left.
		float rise = r * 1.5;
		float k = clamp((q.y + rise) / rise, 0.0, 1.0);
		float cone = min(min(r * k - abs(q.x), q.y + rise), -q.y);
		cone = max(cone, top);
		vec3 slate = mix(vec3(.42, .55, .66), vec3(.24, .33, .44), smoothstep(-.4, .9, q.x / max(1.0, r * k)));
		slate *= 1.0 - .1 * step(.5, fract((q.y + rise) / 9.0));
		col = mix(col, slate, fill(cone));
		col = mix(col, vec3(.86, .74, .4), fill(2.5 - length(q + vec2(0.0, rise + 2.0))));
	} else if (top > -8.0) {
		// Battlements: a walkway ring with merlons round a darker inner floor.
		vec3 ring = vec3(.84, .81, .74);
		vec3 face = mix(ring, vec3(.55, .54, .51), fill((.7 - length(e)) * ry));
		col = mix(col, face, fill(top));
		for (int m = 0; m < 8; m++) {
			float a = float(m) * .785 + seed * 3.0;
			vec2 mc = vec2(cos(a) * r * .86, sin(a) * ry * .86 - 4.0);
			vec2 mq = q - mc;
			float block = min(4.0 - abs(mq.x), 4.0 - abs(mq.y));
			col = mix(col, vec3(.6, .61, .63), fill(min(4.0 - abs(mq.x), 2.5 - abs(mq.y - 4.5))));
			col = mix(col, vec3(.92, .9, .84), fill(block));
		}
	}
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
	col = mix(col, SAND * .93, fill(d) * fill(5.0 - d) * .6);
	// Puddles sitting on the path, ringed with sand.
	for (int k = 0; k < 2; k++) {
		float y = k == 0 ? 300.0 : 680.0;
		vec2 c = vec2(path_x(y) + (k == 0 ? -14.0 : 18.0), y);
		vec2 v = (p - c) * vec2(1.0, 1.45);
		float rim = lobed(v, 46.0, 3.0, .12, float(k) * 2.0);
		float water = lobed(v, 34.0, 3.0, .12, float(k) * 2.0);
		col = mix(col, SAND * 1.02, fill(rim));
		col = mix(col, vec3(.60, .78, .74), fill(water));
		col = mix(col, vec3(.72, .86, .82), fill(water) * fill(lobed(v - vec2(-9.0, -7.0), 18.0, 2.0, .1, 1.0)));
	}
	// A few flat stepping stones, only on the path.
	vec2 cell = floor(p / 70.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = cell + vec2(float(i), float(j));
			vec2 c = (g + .25 + hash2(g) * .5) * 70.0;
			if (path(c) < 6.0 || hash(g + 2.0) > .3) continue;
			float rx = 11.0 + hash(g + 6.0) * 9.0;
			float ry = rx * (.6 + hash(g + 7.0) * .3);
			mat2 m = turn(hash(g + 5.0) * 3.14);
			vec2 q = m * (p - c);
			vec2 qs = m * (p - c - vec2(2.0, 4.0));
			float shadow = (1.0 - length(qs / vec2(rx, ry))) * ry;
			float stone = (1.0 - length(q / vec2(rx, ry))) * ry;
			col = mix(col, col * .8, fill(shadow) * (1.0 - fill(stone)));
			col = mix(col, mix(STONE * .9, STONE, fill(stone - 2.5)), fill(stone));
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

// Canopy shadows reaching in from beyond each edge; `set` picks one of two alternating sets.
float canopy_shadow(vec2 p, int set) {
	float shade = 0.0;
	for (int side = 0; side < 4; side++) {
		float along = side < 2 ? p.x : p.y;
		float across = side == 0 ? p.y : side == 1 ? 800.0 - p.y : side == 2 ? p.x : 800.0 - p.x;
		float slot = floor(along / 150.0);
		for (int k = -1; k <= 1; k++) {
			float s = slot + float(k);
			if (int(mod(s + float(side), 2.0)) != set || hash(vec2(s, float(side) + 40.0)) < .2) continue;
			float centre = (s + .2 + hash(vec2(s, float(side) + 41.0)) * .6) * 150.0;
			float r = 70.0 + hash(vec2(s, float(side) + 42.0)) * 55.0;
			vec2 v = vec2(along - centre, across + r * .4);
			shade = max(shade, fill(lobed(v, r, 6.0, .07, s * 3.0 + float(side))));
		}
	}
	return shade;
}

// Static shade inside the arena: under the bush fringe and from pillars.
float fixed_shade(vec2 p) {
	float inside = min(min(p.x, 800.0 - p.x), min(p.y, 800.0 - p.y));
	float shade = (1.0 - smoothstep(0.0, 12.0, inside)) * .8;
	for (int k = 0; k < 4; k++) {
		vec2 base = k == 0 ? vec2(320.0, -34.0) : k == 1 ? vec2(480.0, -34.0) : k == 2 ? vec2(-34.0, 520.0) : vec2(834.0, 280.0);
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
	// Rocks scattered about.
	vec2 g = floor(p / 90.0);
	vec2 c = (g + .25 + hash2(g + 30.0) * .5) * 90.0;
	if (hash(g + 31.0) > .8 && outside(c) > 50.0) {
		vec2 v = (p - c) * vec2(1.0, 1.3);
		float r = 9.0 + hash(g + 32.0) * 9.0;
		col = mix(col, col * .7, fill(lobed(v - vec2(4.0, 6.0), r, 3.0, .1, 1.0)));
		col = mix(col, vec3(.58, .62, .64), fill(lobed(v, r, 3.0, .1, 1.0)));
		col = mix(col, vec3(.74, .77, .77), fill(lobed(v + vec2(2.0, 3.0), r * .7, 3.0, .1, 1.0)));
	}
	// Shadows first (trees, towers), then trees, then towers on top.
	vec2 tcell = floor(p / 210.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec4 t = tower_in(tcell + vec2(float(i), float(j)));
			if (t.z > 0.0) col = mix(col, col * SHADE * .85, fill(tower_shadow(p, t)));
		}
	}
	vec2 cell = floor(p / 120.0);
	for (int pass = 0; pass < 2; pass++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 t = cell + vec2(float(i), float(j));
				vec2 tc = (t + .2 + hash2(t + 3.0) * .6) * 120.0;
				float r = 48.0 + hash(t + 4.0) * 28.0;
				if (outside(tc) < r + 42.0 || hash(t + 11.0) > .42 + smoothstep(120.0, 260.0, outside(tc)) * .5) continue;
				// Leave room around the towers.
				bool clear = true;
				vec2 near = floor(tc / 210.0);
				for (int b = -1; b <= 1; b++) {
					for (int a = -1; a <= 1; a++) {
						vec4 tw = tower_in(near + vec2(float(a), float(b)));
						if (tw.z > 0.0 && length(tc - tw.xy - vec2(0.0, tw.w * .5)) < r + tw.z + tw.w * .5) clear = false;
					}
				}
				if (!clear) continue;
				vec2 v = p - tc;
				if (pass == 0) {
					col = mix(col, col * SHADE * .85, fill(lobed(v - vec2(26.0, 34.0), r * 1.02, 7.0, .06, hash(t) * 9.0)));
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
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 tc = tcell + vec2(float(i), float(j));
			vec4 t = tower_in(tc);
			if (t.z > 0.0) draw_tower(p, t, hash(tc), col);
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
	float out_d = outside(p);
	if (layer > 0) {
		// Shadow mask only (inside the arena and a little beyond its edge).
		float a = canopy_shadow(p, layer - 1) * (1.0 - smoothstep(0.0, 40.0, out_d));
		COLOR = vec4(.04, .14, .1, a * .4);
	} else {
		vec3 col;
		if (out_d <= 0.0) {
			col = meadow(p);
			sand_and_stones(p, col);
			col = mix(col, col * SHADE, fixed_shade(p));
		} else {
			scenery(p, out_d, col);
		}
		// A touch dimmer and warmer than the raw palette.
		col *= vec3(.95, .93, .88);
		COLOR = vec4(col, 1.0);
	}
}
