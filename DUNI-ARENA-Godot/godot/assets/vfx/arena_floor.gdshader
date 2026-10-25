shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Arena floor as a clean vector-style meadow, rendered once into textures (see ArenaFloor).
// Coordinates are arena units: the 800-unit arena sits inside `margin` units of scenery.
// layer 0: the floor — flat grass tones, a winding worn path with a few stepping stones and
//          puddles, sparse flowers and tufts, the static shade of the bush fringe and pillars;
//          outside (the arena sits inside the tower), a bush fringe, rune pillars, boulders,
//          standing and broken columns, statues, fallen columns and a few trees, with larger
//          rocks further out.
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

// Irregular stone: radius sampled at seven corners round the centre and joined in straight
// runs, so the outline is angular like a broken rock. Positive inside.
float rock(vec2 v, float r, float seed) {
	float a = (atan(v.y, v.x) + 3.14159) / 6.28318 * 7.0;
	float k = floor(a);
	float r0 = r * (.72 + .4 * hash(vec2(seed, mod(k, 7.0))));
	float r1 = r * (.72 + .4 * hash(vec2(seed, mod(k + 1.0, 7.0))));
	return mix(r0, r1, fract(a)) - length(v);
}
const vec3 ROCK_TOP = vec3(.76, .74, .69);
const vec3 ROCK_LIT = vec3(.83, .81, .76);
const vec3 ROCK_SIDE = vec3(.50, .49, .50);
const vec3 ROCK_DARK = vec3(.36, .36, .39);
const vec3 MOSS = vec3(.47, .63, .29);

// A boulder seen from above and in front: angular top face split into two lit facets, a shaded
// front face h units tall, a crack and a little moss.
void boulder(vec2 p, vec2 c, float r, float h, float seed, inout vec3 col) {
	vec2 top_c = c - vec2(0.0, h);
	float side = -1.0;
	for (int k = 0; k <= 8; k++) side = max(side, rock(p - c + vec2(0.0, h * float(k) / 8.0), r, seed));
	if (side > -1.5) {
		vec3 face = mix(ROCK_SIDE, ROCK_DARK, smoothstep(-.6, .9, (p.x - c.x) / r));
		face *= 1.0 - .1 * step(.5, fract((p.y - top_c.y) / 9.0 + hash(vec2(seed, 3.0))));
		col = mix(col, face, fill(side));
	}
	float top = rock(p - top_c, r, seed);
	if (top > -1.5) {
		vec2 cut = vec2(cos(seed * 7.0), sin(seed * 7.0));
		vec3 face = dot(p - top_c, cut) < 0.0 ? ROCK_LIT : ROCK_TOP;
		face = mix(face, ROCK_SIDE, (1.0 - fill(top - 3.0)) * .35);
		vec2 q = p - top_c;
		float crack = abs(dot(q, vec2(-cut.y, cut.x)) - r * .15 * sin(dot(q, cut) * .08 + seed));
		face = mix(face, ROCK_DARK, (1.0 - fill(crack - 1.0)) * step(abs(dot(q, cut)), r * .5) * step(.4, hash(vec2(seed, 9.0))));
		face = mix(face, MOSS, fill((fbm(p * .06 + seed) - .6) * 40.0) * step(q.y, r * .1));
		col = mix(col, face, fill(top));
	}
}
float boulder_shadow(vec2 p, vec2 c, float r, float h, float seed) {
	return rock(p - c - vec2(h * .55 + 6.0, h * .3 + 6.0), r * 1.04, seed);
}

// A column standing on a plinth, lit from the left with fluting; topped by a capital and, on
// some, a weathered statue; broken ones end in a jagged stump.
void column(vec2 p, vec2 base, float r, float h, float kind, float seed, inout vec3 col) {
	vec2 q = p - base;
	float ry = r * .4;
	// Plinth.
	if (abs(q.x) < r * 1.45 && q.y < 4.0 && q.y > -12.0) col = q.y < -7.0 ? ROCK_LIT : ROCK_SIDE;
	float broken = kind < .35 ? 1.0 : 0.0;
	float top_y = -h + broken * (6.0 * sin(q.x * .5 + seed * 9.0) + 4.0 * sin(q.x * 1.3 + seed));
	if (abs(q.x) < r && q.y <= -10.0 && q.y > top_y) {
		float u = q.x / r;
		vec3 stone = mix(ROCK_LIT, ROCK_DARK, smoothstep(-.55, .95, u));
		float flute = fract(asin(clamp(u, -1.0, 1.0)) * 2.4 + .5);
		stone *= 1.0 - .1 * (1.0 - fill(min(flute, 1.0 - flute) * 10.0 - .6));
		stone = mix(stone, MOSS, fill((fbm(p * .07 + seed) - .64) * 40.0) * step(-h * .45, q.y));
		col = stone;
	}
	if (broken > .5) {
		if (abs(q.x) < r && abs(q.y - top_y) < 3.0) col = ROCK_TOP;
		return;
	}
	// Capital slab.
	if (abs(q.x) < r * 1.35 && q.y <= -h + 2.0 && q.y > -h - 10.0) col = q.y < -h - 5.0 ? ROCK_LIT : ROCK_SIDE;
	if (kind > .7) {
		// A statue on top: shoulders and a head, lit from the left.
		vec2 sq = q - vec2(0.0, -h - 10.0);
		float shoulders = min(r * 1.05 - abs(sq.x), min(-sq.y, sq.y + r * 1.3));
		float head = r * .55 - length(sq - vec2(0.0, -r * 1.75));
		float figure = max(shoulders, head);
		if (figure > -1.0) col = mix(col, mix(ROCK_TOP, ROCK_SIDE, smoothstep(-.4, 1.0, sq.x / r)), fill(figure));
	}
}
float column_shadow(vec2 p, vec2 base, float r, float h) {
	vec2 dir = vec2(.85, .42) * h;
	float t = clamp(dot(p - base, dir) / dot(dir, dir), 0.0, 1.0);
	return r * 1.1 - length(p - base - dir * t);
}

// A toppled column lying in pieces, rounded along its length.
void fallen(vec2 p, vec2 c, float r, float len, float ang, float seed, inout vec3 col) {
	vec2 q = turn(-ang) * (p - c);
	float gap = fract(q.x / len * 2.6 + seed);
	if (abs(q.x) < len * .5 && abs(q.y) < r && gap > .06) {
		float v = q.y / r;
		vec3 stone = mix(ROCK_LIT, ROCK_DARK, smoothstep(-.7, .95, v));
		stone *= 1.0 - .08 * step(.5, fract(q.x / 11.0));
		col = stone;
	}
	vec2 cap = vec2(abs(q.x) - len * .5, q.y);
	if (abs(cap.x) < r * .35 && abs(q.y) < r) col = mix(col, ROCK_TOP, fill(r * .35 - length(cap / vec2(1.0, 2.8))));
}

// One scenery object per cell: x = kind (0 none, 1 boulders, 2 column, 3 fallen column, 4 tree),
// y = size, z = height or length, w = variant. Objects gather in clumps near the arena, grow
// with distance, and far out every cell holds a big boulder pile so the edge is all stone.
vec4 object_in(vec2 cell, out vec2 at) {
	at = (cell + .25 + hash2(cell + 3.0) * .5) * 190.0;
	float d = outside(at);
	float far = smoothstep(260.0, 680.0, d);
	if (fbm(cell * .55 + 3.1) + far * .9 < .6) return vec4(0.0);
	float t = hash(cell + 11.0);
	float grow = 1.0 + far * 1.2;
	if (t < .42 + far * .5) {
		float r = (24.0 + hash(cell + 4.0) * 22.0) * grow;
		if (d < r + 34.0) return vec4(0.0);
		return vec4(1.0, r, r * (.3 + hash(cell + 5.0) * .25), hash(cell + 6.0));
	}
	if (t < .64 + far * .3) {
		float r = (15.0 + hash(cell + 4.0) * 7.0) * (1.0 + far * .6);
		float h = (100.0 + hash(cell + 5.0) * 70.0) * (1.0 + far * .5);
		if (min(d, outside(at - vec2(0.0, h))) < r * 1.5 + 30.0) return vec4(0.0);
		return vec4(2.0, r, h, hash(cell + 6.0));
	}
	if (t < .82) {
		float len = (100.0 + hash(cell + 4.0) * 60.0) * (1.0 + far * .4);
		if (d < len * .5 + 30.0) return vec4(0.0);
		return vec4(3.0, (14.0 + hash(cell + 5.0) * 6.0) * (1.0 + far * .4), len, hash(cell + 6.0));
	}
	float r = 44.0 + hash(cell + 4.0) * 20.0;
	if (d < r + 34.0) return vec4(0.0);
	return vec4(4.0, r, 0.0, hash(cell + 6.0));
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
	// Far out, the ground itself turns to rubble under the boulder piles.
	col = mix(col, vec3(.40, .40, .41) * (.9 + .15 * fbm(p * .02)), fill((out_d - 600.0 + (fbm(p * .006) - .5) * 160.0) * .2));
	// Scenery objects: all shadows first, then the objects row by row (lower ones in front).
	vec2 cell = floor(p / 190.0);
	for (int pass = 0; pass < 2; pass++) {
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 g = cell + vec2(float(i), float(j));
				vec2 at;
				vec4 o = object_in(g, at);
				if (o.x < .5) continue;
				float seed = hash(g + 17.0) * 10.0;
				if (o.x < 1.5) {
					// A cluster of one to three boulders.
					for (int k = 0; k < 3; k++) {
						if (k > 0 && hash(g + float(k) * 13.0) < .45) continue;
						float r = o.y * (k == 0 ? 1.0 : .45 + hash(g + float(k) * 7.0) * .3);
						vec2 c = at + (k == 0 ? vec2(0.0) : (hash2(g + float(k) * 5.0) - .5) * o.y * 1.7);
						if (pass == 0) col = mix(col, col * .62, fill(boulder_shadow(p, c, r, o.z * r / o.y, seed + float(k))));
						else boulder(p, c, r, o.z * r / o.y, seed + float(k), col);
					}
				} else if (o.x < 2.5) {
					if (pass == 0) col = mix(col, col * .62, fill(column_shadow(p, at, o.y, o.z)));
					else column(p, at, o.y, o.z, o.w, seed, col);
				} else if (o.x < 3.5) {
					float ang = (hash(g + 8.0) - .5) * .7;
					if (pass == 0) col = mix(col, col * .62, fill(min(o.y + 4.0 - abs((turn(-ang) * (p - at - vec2(7.0, 12.0))).y), o.z * .5 - abs((turn(-ang) * (p - at - vec2(7.0, 12.0))).x))));
					else fallen(p, at, o.y, o.z, ang, seed, col);
				} else {
					vec2 v = p - at;
					float r = o.y;
					if (pass == 0) {
						col = mix(col, col * .62, fill(lobed(v - vec2(24.0, 32.0), r * 1.02, 7.0, .06, seed)));
					} else {
						col = mix(col, vec3(.15, .35, .25), fill(lobed(v, r, 7.0, .06, seed)));
						col = mix(col, vec3(.22, .47, .30), fill(lobed(v + vec2(r * .12, r * .16), r * .78, 6.0, .08, seed)));
						col = mix(col, vec3(.36, .60, .34), fill(lobed(v + vec2(r * .3, r * .34), r * .42, 5.0, .1, seed)));
					}
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
