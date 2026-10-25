shader_type canvas_item;
render_mode unshaded;
// Hand-painted arena floor, rendered once into a texture (see ArenaFloor). Coordinates are
// arena units: the 800-unit arena sits inside `margin` units of scenery on every side.
uniform float margin = 320.0;

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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= .5;
	}
	return v;
}
// Voronoi cells: x = distance to the nearest border, y = cell id, z = distance to the seed.
vec3 cells(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * .8 + .1 - f;
			float d = dot(r, r);
			if (d < md) { md = d; mr = r; mg = g; }
		}
	}
	float border = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) * .8 + .1 - f;
			if (dot(mr - r, mr - r) > .00001) border = min(border, dot(.5 * (mr + r), normalize(r - mr)));
		}
	}
	return vec3(border, hash(n + mg), length(mr));
}

// Worn cream flagstones: big and small slabs, soft darker rims, mottled faces.
vec3 flagstones(vec2 p) {
	vec2 warped = p + (vec2(fbm(p * .01), fbm(p * .01 + 7.3)) - .5) * 30.0;
	float size = 96.0;
	vec3 c = cells(warped / size);
	float edge = c.x * size;
	float id = c.y;
	if (id > .7) {
		// Some slabs are cracked into smaller stones.
		vec3 s = cells(warped / (size * .5) + 31.7);
		edge = min(edge, s.x * size * .5);
		id = fract(id + s.y * 3.1);
	}
	vec3 base = mix(vec3(.93, .89, .77), vec3(.89, .85, .73), id);
	base = mix(base, vec3(.95, .91, .80), step(.75, fract(id * 7.0)) * .6);
	base *= .975 + .05 * fbm(p * .03 + id * 10.0);
	// A soft darker rim inside each slab, a lighter centre, a thin warm grout line.
	vec3 rim = base * vec3(.9, .875, .82);
	vec3 col = mix(rim, base, smoothstep(1.0, 7.0, edge));
	col += vec3(.03, .025, .015) * smoothstep(10.0, 30.0, edge);
	vec3 grout = vec3(.78, .72, .58);
	return mix(grout, col, smoothstep(.5, 1.6, edge));
}

// Broad moss patches with ragged edges, darker blotches and lighter tops; creeping into cracks.
vec4 moss(vec2 p, float crack) {
	float m = fbm(p * .0052 + 3.7) + (noise(p * .09) - .5) * .05 + crack * .05;
	float cover = smoothstep(.565, .575, m);
	vec3 fill = mix(vec3(.62, .73, .28), vec3(.72, .80, .36), fbm(p * .03));
	fill = mix(fill, vec3(.53, .64, .24), smoothstep(.6, .75, fbm(p * .05 + 4.0)) * .7);
	vec3 col = mix(vec3(.50, .60, .22), fill, smoothstep(.575, .6, m));
	return vec4(col, cover);
}

vec3 grass(vec2 p) {
	vec3 col = mix(vec3(.58, .74, .29), vec3(.70, .82, .36), fbm(p * .008));
	col = mix(col, vec3(.47, .64, .25), smoothstep(.55, .75, fbm(p * .02 + 2.0)) * .6);
	// Tiny white and blue flowers.
	vec2 g = floor(p / 16.0);
	vec2 o = hash2(g) * 16.0;
	float flower = step(.86, hash(g + 5.0)) * (1.0 - smoothstep(1.2, 2.2, length(p - g * 16.0 - o)));
	return mix(col, mix(vec3(.97, .96, .9), vec3(.62, .78, .95), step(.5, hash(g + 9.0))), flower);
}

// Cream blocks in courses: x = along the run, y = across it (0 at the inner edge).
vec3 blocks(vec2 q, float course, float span, float seed) {
	float row = floor(q.y / course);
	float u = (q.x + row * span * .5) / span;
	float cell = floor(u);
	float tone = hash(vec2(cell, row + seed));
	vec3 col = mix(vec3(.90, .86, .74), vec3(.84, .81, .70), tone);
	float fu = fract(u) * span;
	float fv = fract(q.y / course) * course;
	float edge = min(min(fu, span - fu), min(fv, course - fv));
	col = mix(col * vec3(.85, .84, .8), col, smoothstep(1.0, 4.0, edge));
	return mix(vec3(.42, .5, .44), col, smoothstep(.6, 1.6, edge));
}

void fragment() {
	vec2 p = UV * (800.0 + margin * 2.0) - margin;
	float out_d = max(max(-p.x, p.x - 800.0), max(-p.y, p.y - 800.0));
	bool vertical_side = abs(p.x - 400.0) > abs(p.y - 400.0);
	float along = vertical_side ? p.y : p.x;
	vec3 col;
	if (out_d <= 0.0) {
		vec3 stone = flagstones(p);
		float crack = 1.0 - smoothstep(.0, 3.0, cells((p + (vec2(fbm(p * .01), fbm(p * .01 + 7.3)) - .5) * 30.0) / 96.0).x * 96.0);
		// Worn sandy patches where the slabs have sunk away.
		float sand = smoothstep(.63, .68, fbm(p * .0045 + 9.1));
		col = mix(stone, vec3(.92, .82, .6) * (.97 + .05 * fbm(p * .03)), sand * .85);
		vec4 m = moss(p, crack);
		col = mix(col, m.rgb, m.a);
		// Cool tree shade drifting in from the edges.
		float inside = min(min(p.x, 800.0 - p.x), min(p.y, 800.0 - p.y));
		float shade = smoothstep(.5, .56, fbm(p * .0065 + 20.0) + .3 * (1.0 - smoothstep(0.0, 140.0, inside)));
		col *= mix(vec3(1.0), vec3(.78, .86, .82), shade * (1.0 - smoothstep(40.0, 160.0, inside)));
	} else {
		col = grass(p);
		// Low curb wall right around the arena.
		if (out_d < 26.0) {
			col = blocks(vec2(along, out_d), 13.0, 42.0, vertical_side ? 1.0 : 2.0);
			col = mix(col, vec3(.62, .73, .28), smoothstep(.6, .64, fbm(p * .03 + 1.0)) * .9);
			col *= mix(.92, 1.0, smoothstep(0.0, 26.0, out_d));
		} else if (out_d < 40.0) {
			col *= mix(.72, 1.0, smoothstep(26.0, 40.0, out_d));
		}
		// Ruined wall stretches beyond the curb: block tops, a shaded front face, a cast shadow.
		float run = floor(along / 150.0);
		bool standing = hash(vec2(run, vertical_side ? 3.0 : 7.0)) > .35 && fract(along / 150.0) > .12 && fract(along / 150.0) < .82;
		float side_y = p.y < 400.0 ? -1.0 : 1.0;
		if (standing && out_d > 50.0 && out_d < 74.0) {
			col = blocks(vec2(along, out_d - 50.0), 12.0, 32.0, run);
			col = mix(col, vec3(.62, .73, .28), smoothstep(.6, .64, fbm(p * .04 + 3.0)) * .9);
		} else if (standing && !vertical_side && ((side_y < 0.0 && out_d > 40.0 && out_d <= 50.0) || (side_y > 0.0 && out_d >= 74.0 && out_d < 84.0))) {
			col = mix(vec3(.50, .64, .58), vec3(.43, .57, .52), fract(along / 30.0 + floor(out_d / 5.0) * .5) < .06 ? 1.0 : 0.0);
		} else if (standing && ((vertical_side && out_d >= 74.0 && out_d < 86.0 && p.x > 400.0) || (vertical_side && out_d > 38.0 && out_d <= 50.0 && p.x < 400.0) || (!vertical_side && side_y > 0.0 && out_d >= 84.0 && out_d < 96.0))) {
			col *= .76;
		}
		// Corner pillars: a capped block with its front face and shadow.
		vec2 corner = vec2(p.x < 400.0 ? -52.0 : 852.0, p.y < 400.0 ? -52.0 : 852.0);
		vec2 k = p - corner;
		if (abs(k.x) < 22.0 && abs(k.y) < 22.0) {
			col = mix(vec3(.95, .91, .80), vec3(.85, .81, .70), smoothstep(10.0, 22.0, max(abs(k.x), abs(k.y))));
			col = mix(col, vec3(.62, .73, .28), smoothstep(.55, .6, fbm(p * .06)) * .8);
		} else if (abs(k.x) < 22.0 && k.y >= 22.0 && k.y < 36.0) {
			col = vec3(.50, .64, .58);
		} else if (k.x >= 22.0 && k.x < 34.0 && k.y > -14.0 && k.y < 42.0) {
			col *= .76;
		}
		// Round leafy canopies on a coarse grid, thickening away from the arena.
		vec2 cell = floor(p / 130.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 g = cell + vec2(float(i), float(j));
				vec2 c = (g + .2 + hash2(g + 3.0) * .6) * 130.0;
				float cd = max(max(-c.x, c.x - 800.0), max(-c.y, c.y - 800.0));
				if (cd < 95.0 || hash(g + 11.0) > .35 + smoothstep(100.0, 260.0, cd) * .6) continue;
				float r = 46.0 + hash(g + 4.0) * 30.0;
				vec2 d = p - c;
				float ang = atan(d.y, d.x);
				float wobble = 1.0 + .08 * sin(ang * 7.0 + hash(g) * 20.0) + .05 * sin(ang * 13.0 + hash(g) * 9.0);
				// Shadow first, offset down-right.
				if (length(d - vec2(16.0, 22.0)) < r * wobble) col *= .7;
				float q = length(d) / (r * wobble);
				if (q < 1.0) {
					bool autumn = hash(g + 21.0) > .85;
					vec3 dark = autumn ? vec3(.62, .45, .16) : vec3(.12, .34, .32);
					vec3 mid = autumn ? vec3(.85, .66, .24) : vec3(.20, .47, .40);
					vec3 light = autumn ? vec3(.96, .84, .44) : vec3(.42, .66, .42);
					float lit = dot(normalize(d + vec2(.001)), vec2(-.7, -.7)) * .5 + .5;
					vec3 leaf = mix(mid, light, smoothstep(.55, .9, lit * (1.0 - q * .5) + (fbm(p * .05) - .5) * .4));
					// Soft leaf clusters rather than a flat disc.
					leaf = mix(leaf * .84, leaf, smoothstep(.42, .56, fbm(p * .07 + hash(g) * 9.0)));
					col = mix(dark, leaf, smoothstep(.0, .12, 1.0 - q));
				}
			}
		}
	}
	// Warm sunlight overall.
	col *= vec3(1.02, 1.0, .95);
	COLOR = vec4(col, 1.0);
}
