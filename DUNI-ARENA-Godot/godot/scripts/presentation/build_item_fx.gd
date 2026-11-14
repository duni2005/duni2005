class_name BuildItemFx
extends RefCounted
## Visuals of the 0.97 빌드 지원 아이템, called by ItemFx: one-off effects (event), short marks
## (draw_mark), lasting looks with the unit (draw_unit), the 군단장의 깃발 on the ground and the
## 블랙홀 above everything. Companions (정령, 새끼 용) and forms (야수, 영혼, 시간 정지) are drawn
## here every frame from the unit's state.

const EL = ItemFx.ELEMENT_COLORS
## Effects that fire on many hits: rate-limited by ItemFx, small burst only.
const LIMITED = ["emberFlint", "fangNecklace", "frostOrb", "shieldHammer", "radiantLamp", "shadowClaw", "tailwindFan", "stormWings", "lightningRod", "giantSpear", "dawnSword", "rainbowStone", "powderKeg", "heroBadge", "twinCrossbow", "abyssScythe", "beastHide"]

static func _v(m: Dictionary, key: String, at: Vector2) -> Vector2:return CharacterPersistence.vector(m.get(key, {}), at)

static func event(fx, item: String, m: Dictionary, at: Vector2, targets: Array, g: float) -> bool:
	var host = fx.host;var p = host.particles;var shader: bool = host.use_shader_fx
	match item:
		# ---- 희귀 ----
		"emberFlint":p.burst(at, EL.fire, int(10 * g), 160, -PI * .5, "flame", true);fx._mark("ember", at, .55, {"size": g})
		"fangNecklace":fx._mark("venom", at, .6, {"size": g});p.burst(at, EL.poison, int(8 * g), 140, PI * .5, "spark", true)
		"frostOrb":fx._mark("frost_star", at, .5, {"size": g});p.burst(at, EL.ice, int(10 * g), 200, 0, "shard", true)
		"lightningRod":
			if shader:host.shader_fx.bolt(at + Vector2(0, -160), at)
			fx._mark("bolt", at, .35, {"size": g});p.burst(at, EL.lightning, int(10 * g), 240, 0, "spark", true)
		"tailwindFan", "stormWings":
			fx._mark("gust", at, .7, {"size": g, "color": EL.wind if item == "tailwindFan" else Color("d8fff4")})
			p.burst(at, EL.wind, int(8 * g), 180, 0, "mote", true)
		"radiantLamp":fx._mark("rays", at, .5, {"color": EL.light, "size": g * .7});p.burst(at, EL.light, int(10 * g), 150, -PI * .5, "heal", true)
		"shadowClaw":fx._mark("claws", at, .45, {"size": g, "color": EL.dark});p.burst(at, EL.dark, int(8 * g), 180, 0, "shard", true)
		"practiceSword":
			fx._mark("cross", at, .6, {"size": g, "color": Color("d9b77a")});p.burst(at, Color("b9f08f"), int(14 * g), 140, -PI * .5, "heal", true)
			host.add_effect("shield_hit", at, Color("ffe2a8"), 50 * g)
		"wallGlove":
			fx._mark("impact", at, .5, {"size": g});p.burst(at, Color("c9b08a"), int(14 * g), 220, 0, "smoke", true);host.camera.impact(5, at)
			fx._mark("text", at, .8, {"text": "충돌!", "color": Color("ffd08a")})
		"shieldHammer":fx._mark("shield_flash", at, .35, {"size": g * .8});p.burst(at, Color("ffe08a"), int(8 * g), 220, 0, "spark", true)
		# ---- 영웅 ----
		"twinCrossbow":fx._mark("twin", at, .3, {"angle": float(m.get("angle", 0)), "size": g})
		"powderKeg":p.burst(at, Color("ffb46a"), int(10 * g), 240, 0, "smoke", true);host.add_effect("slime_ring", at, Color("ff9a52"), 48 * g, .4)
		"plagueCenser":
			var to: Vector2 = _v(m, "to", at)
			fx._mark("orb", at, .6, {"to": to, "color": Color("a6e36b"), "size": 7.0 * g, "trail": true});p.burst(at, Color("7a5aa8"), int(14 * g), 140, -PI * .5, "smoke", true)
		"giantSpear":fx._mark("pierce", at, .4, {"size": g * 1.3, "angle": -PI * .5 + .4, "color": Color("ffcf8a")});p.burst(at, Color("ffcf8a"), int(8 * g), 220, 0, "shard", false)
		"duelCape":
			fx._mark("swirl", at, .5, {"size": g});fx._mark("pips", at, .8, {"count": int(m.get("stacks", 1)), "color": Color("ff6a86"), "size": g})
			p.burst(at, Color("ff8aa0"), int(10 * g), 200, 0, "spark", true)
		"chargeHorn":
			if m.get("stun", false):
				fx._mark("star", at, .5, {"color": Color("ffe066"), "size": g});fx._mark("text", at, .8, {"text": "기절", "color": Color("ffe066")})
				host.add_effect("hero_shock", at, Color("ffd08a"), 90 * g, .45);host.camera.impact(6, at);p.burst(at, Color("ffe066"), int(18 * g), 280, 0, "spark", true)
			else:
				fx._mark("dash", at, .7, {"to": _v(m, "to", at), "size": g});fx._mark("horns", at, .8, {"size": g});host.camera.impact(3, at)
		"knightCrest":
			fx._mark("icon", at + Vector2(0, -62), .9, {"icon": "knightCrest", "size": 28 * g})
			for to in targets:
				var hit: Vector2 = CharacterPersistence.vector(to, at)
				fx._mark("beam", hit, .9, {"to": at, "color": Color("ff6a5a")});fx._mark("crosshair", hit, .7, {"size": g, "color": Color("ff6a5a")})
			host.add_effect("hero_shock", at, Color("7fb8ff"), 80 * g, .5)
		"ultScore":
			for to in targets:fx._mark("note", at, 1.0, {"to": CharacterPersistence.vector(to, at), "size": g})
			p.burst(at, Color("ffe9a0"), int(16 * g), 160, -PI * .5, "mote", true)
		"spiritLantern":
			var col: Color = EL.get(str(m.get("element", "light")), Color("a8fff0"));var to: Vector2 = _v(m, "to", at)
			fx._mark("orb", at, .4, {"to": to, "color": col, "size": 6.0 * g, "trail": true});p.burst(to, col, int(8 * g), 160, 0, "spark", true)
		"vengeanceMask":
			fx._mark("icon", at + Vector2(0, -64), .9, {"icon": "vengeanceMask", "size": 30 * g});host.add_effect("hero_shock", at, Color("ff4a4a"), 80 * g, .5)
			fx._mark("text", at, 1.0, {"text": "복수 +%d%%" % (int(m.get("stacks", 1)) * roundi(ItemTuning.VENGEANCE_STEP * 100)), "color": Color("ff7a6a"), "delay": .2})
			p.burst(at, Color("ff4a4a"), int(16 * g), 200, -PI * .5, "flame", true)
		# ---- 전설 ----
		"volcanoHeart":
			if m.has("radius"):
				var rad: float = float(m.radius);host.add_effect("fireball", at, Color("ff6a2a"), rad * .9, .9, 0);fx._mark("flames", at, .8, {"radius": rad})
				if shader:host.shader_fx.shock(at, rad * 1.4, .55, Color("ff6a2a"))
				p.burst(at, Color("ffb46a"), int(26 * g), rad * 3, 0, "flame", true);host.camera.impact(8, at)
			else:fx._mark("ember", at, .6, {"size": g * 1.3});p.burst(at, Color("ff5a2a"), int(10 * g), 180, -PI * .5, "flame", true)
		"plagueChalice":
			fx._mark("orb", at, .7, {"to": _v(m, "to", at), "color": Color("8fe36b"), "size": 9.0 * g, "trail": true})
			host.add_effect("slime_ring", at, Color("8fe36b"), 60 * g, .6);p.burst(at, Color("8fe36b"), int(20 * g), 160, -PI * .5, "mote", true)
		"permafrostScepter":
			fx._mark("ice_block", at, 1.0, {"size": g});host.add_effect("hero_shock", at, Color("bfeaff"), 90 * g, .5)
			if shader:host.shader_fx.shock(at, 90 * g, .45, Color("bfeaff"))
			p.burst(at, Color("e2f6ff"), int(20 * g), 260, 0, "shard", true);host.camera.impact(4, at)
		"thunderHammer":
			var rad: float = float(m.get("radius", 90))
			if shader:host.shader_fx.bolt(at + Vector2(0, -260), at)
			fx._mark("bolt", at, .45, {"size": g});fx._mark("ring_fill", at, .45, {"radius": rad, "color": EL.lightning})
			host.add_effect("hero_shock", at, Color("fff27a"), rad * 1.3, .45);p.burst(at, Color("fff8c0"), int(20 * g), 320, 0, "spark", true);host.camera.impact(7, at)
			for to in targets:p.burst(CharacterPersistence.vector(to, at), EL.lightning, int(6 * g), 200, 0, "spark", true)
		"dawnSword":
			var to: Vector2 = _v(m, "to", at)
			fx._mark("beam", at, .5, {"to": to, "color": Color("ffe9a0")});fx._mark("orb", at, .5, {"to": to, "color": Color("fff3c8"), "size": 6.0, "trail": true})
			p.burst(to, Color("ffe9a0"), int(10 * g), 120, -PI * .5, "heal", true)
		"abyssScythe":fx._mark("abyss", at, .55, {"size": g});p.burst(at, EL.dark, int(14 * g), 260, 0, "shard", true);host.camera.impact(3, at)
		"overlordGauntlet":
			var rad: float = float(m.get("radius", 120))
			fx._mark("ring_fill", at, .5, {"radius": rad, "color": Color("ffb36b")});host.add_effect("hero_shock", at, Color("ffb36b"), rad * 1.4, .55)
			if shader:host.shader_fx.shock(at, rad * 1.5, .5, Color("ffb36b"))
			fx._mark("icon", at + Vector2(0, -62), .8, {"icon": "overlordGauntlet", "size": 30 * g});p.burst(at, Color("ffd08a"), int(24 * g), rad * 3, 0, "shard", true);host.camera.impact(8, at)
		"legionBanner":fx._mark("flag_drop", at, .9, {"size": g});fx._mark("ring_fill", at, .8, {"radius": float(m.get("radius", 170)), "color": Color("ff6a6a")});host.camera.impact(4, at)
		"gunnerSight":
			if m.get("blast", false):
				var rad: float = float(m.get("radius", 105))
				host.add_effect("fireball", at, Color("ff9a3d"), rad * .9, .8, 0);fx._mark("ring_fill", at, .5, {"radius": rad, "color": Color("ffb46a")})
				if shader:host.shader_fx.shock(at, rad * 1.5, .5, Color("ffb46a"))
				p.burst(at, Color("ffd08a"), int(24 * g), rad * 3, 0, "shard", true);p.burst(at, Color("6a5a4a"), int(10 * g), 120, -PI * .5, "smoke", true);host.camera.impact(9, at)
			else:fx._mark("muzzle", at, .3, {"angle": float(m.get("angle", 0)), "size": g});host.camera.impact(3, at)
		"heroBadge":fx._mark("icon", at + Vector2(0, -62), .8, {"icon": "heroBadge", "size": 28 * g});p.burst(at, Color("ffd54a"), int(10 * g), 180, -PI * .5, "spark", true)
		# ---- 고대 ----
		"rainbowStone":
			var col: Color = EL.get(str(m.get("element", "fire")), Color.WHITE)
			host.add_effect("slime_ring", at, col, 34 * g * .7, .35);p.burst(at, col, int(8 * g), 200, 0, "spark", true)
		"dragonEgg":
			if m.get("hatch", false):fx._mark("egg", at, 1.0, {"size": g});p.burst(at + Vector2(0, -40), Color("ffd08a"), int(16 * g), 160, -PI * .5, "shard", true)
			else:
				var to: Vector2 = _v(m, "to", at)
				fx._mark("breath", at, .55, {"to": to, "stage": int(m.get("stage", 1)), "radius": float(m.get("radius", 50))})
				p.burst(to, Color("ff8a3d"), int((10 + int(m.get("stage", 1)) * 2) * g * .6), 180, 0, "flame", true)
		"giantRing":
			if m.has("radius"):fx._mark("ring_fill", at, .35, {"radius": float(m.radius), "color": Color("ffd36b")});p.burst(at, Color("ffe08a"), int(8 * g), 220, 0, "shard", false)
			else:fx._mark("ripple", at, 1.0, {"size": g * 1.6});host.camera.impact(5, at)
		"thiefWatch":
			fx._mark("clock", at, 1.4, {"size": g})
			for to in targets:fx._mark("stopped", CharacterPersistence.vector(to, at), .6, {"size": 1.0})
			if shader:host.shader_fx.shock(at, 260, .8, Color("c8d6ff"))
			host.impact_pause(120);host.camera.impact(6, at)
		"soulLantern":
			fx._mark("orb", _v(m, "from", at), .6, {"to": at, "color": Color("a8fff0"), "size": 7.0, "trail": true})
			fx._mark("soul_rise", at, 1.1, {"size": g});p.burst(at, Color("c8fff4"), int(18 * g), 140, -PI * .5, "mote", true)
		"mirrorShield":
			fx._mark("shield_flash", at, .45, {"size": g});fx._mark("twin", at, .35, {"angle": float(m.get("angle", 0)), "size": g, "color": Color("dfe8ff")})
			p.burst(at, Color("eef3fa"), int(10 * g), 240, float(m.get("angle", 0)), "shard", true)
		"ultScepter":
			var to: Vector2 = _v(m, "to", at)
			fx._mark("beam", at, .9, {"to": to, "color": Color("ffd36b")});fx._mark("crown_mark", to, 1.0, {"color": Color("ffd36b")})
			host.add_effect("hero_shock", to, Color("ffd36b"), 90 * g, .55);p.burst(to, Color("ffe08a"), int(20 * g), 200, -PI * .5, "spark", true)
		"blackHoleOrb":p.burst(at, Color("6a3aa8"), int(20 * g), 260, 0, "mote", true);host.camera.impact(5, at)
		"beastHide":
			if m.get("transform", false):
				host.add_effect("hero_shock", at, Color("ff5a3a"), 120 * g, .6);fx._mark("claws", at, .7, {"size": g * 1.6, "color": Color("ff6a3a")})
				fx._mark("text", at, 1.1, {"text": "야수화!", "color": Color("ff8a5a")});p.burst(at, Color("ff7a3a"), int(30 * g), 300, -PI * .5, "flame", true)
				if shader:host.shader_fx.shock(at, 140, .6, Color("ff5a3a"))
				host.camera.impact(9, at)
			elif m.get("end", false):p.burst(at, Color("8a7a6a"), int(16 * g), 120, -PI * .5, "smoke", true)
			else:p.burst(at, Color("ff5a4a"), int(6 * g), 140, -PI * .5, "heal", false)
		"lonelyKingSword":
			fx._mark("crown_mark", at, 1.2, {"color": Color("dfe8ff")})
			fx._mark("text", at, 1.4, {"text": "고독 +%d%%" % (int(m.get("count", 1)) * roundi(ItemTuning.LONELY_STEP * 100)), "color": Color("dfe8ff"), "delay": .3})
		"pactSeal":
			if m.get("off", false):fx._mark("text", at, 1.4, {"text": "계약 중단", "color": Color("ff6b6b")})
			else:fx._mark("text", at, 1.2, {"text": "계약 -%d G" % ItemTuning.PACT_GOLD, "color": Color("ffd54a")});p.burst(at, Color("ffd54a"), int(10 * g), 160, -PI * .5, "spark", true)
		"commanderCompass":
			var to: Vector2 = _v(m, "to", at)
			fx._mark("icon", at + Vector2(0, -62), 1.0, {"icon": "commanderCompass", "size": 30 * g});fx._mark("cancel", to, 1.0, {"size": g})
			fx._mark("beam", at, .8, {"to": to, "color": Color("b9d8ff")})
		"lastStandSeal":fx._mark("text", at, 1.2, {"text": "배수진", "color": Color("ff4f6d")});host.add_effect("hero_shock", at, Color("ff4f6d"), 100, .6);p.burst(at, Color("ff4f6d"), 24, 220, 0, "shard", true)
		_:return false
	return true

## Short marks of these items; false when the kind is not one of them.
static func draw_mark(c: CanvasItem, m: Dictionary, at: Vector2, k: float, fade: float, g: float, t: float) -> bool:
	match m.kind:
		"ember":
			for i in range(5):
				var q: Vector2 = at + Vector2((i - 2) * 8, -10 - 26 * k * (1 + (i % 2) * .4)) * g * .8
				VfxArt.glow(c, q, 10 * g * .8, Color("ff7a2a"), .7 * fade);c.draw_circle(q, 3 * g * .8, Color("ffd08a", fade))
		"venom":
			for side in [-1, 1]:c.draw_colored_polygon(PackedVector2Array([at + Vector2(side * 5, -66), at + Vector2(side * 14, -66), at + Vector2(side * 8, -46 + 4 * k)]), Color("e8ffe0", fade))
			c.draw_circle(at + Vector2(0, -40 + 18 * k), 3.5, Color("8fe36b", fade));VfxArt.glow(c, at + Vector2(0, -56), 18, Color("8fe36b"), .45 * fade)
		"frost_star":
			for i in range(6):
				var a: float = i * PI / 3 + k;c.draw_line(at, at + Vector2.from_angle(a) * 24 * g * (.6 + .4 * k), Color("e2f6ff", fade), 3, true)
			VfxArt.glow(c, at, 26 * g, Color("a8e4ff"), .4 * fade)
		"gust":
			for i in range(3):
				var a: float = k * 7 + i * TAU / 3;c.draw_arc(at, (22 + i * 7) * g * .8, a, a + 1.9, 14, Color(m.color, .85 * fade), 3, true)
		"claws":
			var col: Color = m.get("color", Color("b48cff"))
			for i in range(3):
				var o: Vector2 = Vector2((i - 1) * 11, 0) * g * .8;var len: float = 46 * g * .8 * minf(1, k * 3)
				c.draw_line(at + o + Vector2(-len * .5, -len * .5), at + o + Vector2(len * .5, len * .5), Color(col.lightened(.3), fade), 4, true)
		"cross":
			var r: float = 26 * g * .8
			c.draw_line(at + Vector2(-r, -r), at + Vector2(r, r), Color(m.color, fade), 5, true);c.draw_line(at + Vector2(r, -r), at + Vector2(-r, r), Color(m.color, fade), 5, true)
		"impact":
			for i in range(8):
				var a: float = i * TAU / 8;c.draw_line(at + Vector2.from_angle(a) * 12, at + Vector2.from_angle(a) * (20 + 26 * k) * g * .8, Color("ffe2a8", fade), 4, true)
		"twin":
			var dir: Vector2 = Vector2.from_angle(float(m.get("angle", 0)));var nrm: Vector2 = dir.orthogonal() * 7;var col: Color = m.get("color", Color("ffe9c0"))
			for side in [-1, 1]:c.draw_line(at + nrm * side + dir * 20, at + nrm * side + dir * (50 + 40 * k), Color(col, fade), 3, true)
		"dash":
			var to: Vector2 = m.to;var head: Vector2 = at.lerp(to, Motion.out_quint(minf(1, k * 1.6)))
			c.draw_line(at, head, Color("ffd08a", .7 * fade), 10 * fade + 2, true);c.draw_line(at, head, Color("fff6d8", fade), 3, true);VfxArt.glow(c, head, 24, Color("ffb36b"), .5 * fade)
		"note":
			var to: Vector2 = m.to;var q: Vector2 = at.lerp(to, Motion.out_quint(k)) + Vector2(0, -60 * sin(k * PI) - 30)
			c.draw_circle(q, 5, Color("ffe9a0", fade));c.draw_line(q + Vector2(4, 0), q + Vector2(4, -16), Color("ffe9a0", fade), 2, true);c.draw_line(q + Vector2(4, -16), q + Vector2(11, -12), Color("ffe9a0", fade), 2, true)
			VfxArt.glow(c, q, 12, Color("ffe9a0"), .4 * fade)
		"ice_block":
			var r: float = 30 * g * .8;var box: PackedVector2Array = PackedVector2Array()
			for i in range(6):box.append(at + Vector2.from_angle(i * TAU / 6 + .3) * r)
			c.draw_colored_polygon(box, Color("bfeaff", .3 * fade));box.append(box[0]);c.draw_polyline(box, Color("e2f6ff", fade), 3, true)
		"abyss":
			var a0: float = -2.6 + 2.8 * Motion.out_quint(k)
			c.draw_arc(at + Vector2(0, -6), 52 * g * .75, a0 - 1.3, a0, 22, Color("7a4ad8", .9 * fade), 10, true);c.draw_arc(at + Vector2(0, -6), 52 * g * .75, a0 - 1.0, a0, 22, Color("e6d6ff", fade), 3, true)
			c.draw_string(ArenaUI.heading_font(), at + Vector2(-28, -62 - 10 * k), "확정 치명", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("efe2ff", fade))
		"flag_drop":
			var drop: float = Motion.out_quint(minf(1, k * 2.2));var base: Vector2 = at + Vector2(0, 18)
			var top: Vector2 = base + Vector2(0, -70 - 120 * (1 - drop))
			c.draw_line(base + Vector2(0, -120 * (1 - drop)), top, Color("e8d8b0", fade), 3, true)
			c.draw_colored_polygon(PackedVector2Array([top, top + Vector2(34, 8), top + Vector2(0, 22)]), Color("ff5a5a", fade))
		"muzzle":
			var dir: Vector2 = Vector2.from_angle(float(m.get("angle", 0)));var q: Vector2 = at + dir * 30
			VfxArt.glow(c, q, 26 * g * .7, Color("ffb46a"), .8 * fade);c.draw_colored_polygon(PackedVector2Array([q - dir.orthogonal() * 9, q + dir * 30 * fade, q + dir.orthogonal() * 9]), Color("fff0c8", fade))
		"egg":
			var q: Vector2 = at + Vector2(30, -40);var crack: float = minf(1, k * 1.8)
			c.draw_circle(q, 11, Color("f4ead0", fade));c.draw_polyline(PackedVector2Array([q + Vector2(-10, 0), q + Vector2(-4, -4 * crack), q + Vector2(2, 3 * crack), q + Vector2(10, -2)]), Color("8a6a3a", fade), 2, true)
			VfxArt.glow(c, q, 22, Color("ffd08a"), .5 * fade)
		"breath":
			var to: Vector2 = m.to;var dir: Vector2 = (to - at).normalized();var nrm: Vector2 = dir.orthogonal();var reach: float = at.distance_to(to) * minf(1, k * 2.5)
			var w: float = float(m.radius) * .6
			c.draw_colored_polygon(PackedVector2Array([at, at + dir * reach + nrm * w, at + dir * reach - nrm * w]), Color("ff8a3d", .55 * fade))
			c.draw_colored_polygon(PackedVector2Array([at, at + dir * reach * .8 + nrm * w * .45, at + dir * reach * .8 - nrm * w * .45]), Color("ffe08a", .7 * fade))
			if k > .3:VfxArt.glow(c, to, float(m.radius), Color("ff6a2a"), .55 * fade)
		"clock":
			var r: float = 60 + 360 * Motion.out_quint(k)
			c.draw_arc(at, r, 0, TAU, 64, Color("c8d6ff", .7 * fade), 4, true)
			for i in range(12):
				var a: float = i * TAU / 12;c.draw_line(at + Vector2.from_angle(a) * (r - 14), at + Vector2.from_angle(a) * r, Color("e6ecff", .8 * fade), 3, true)
			var hub: Vector2 = at + Vector2(0, -70);c.draw_arc(hub, 22, 0, TAU, 32, Color("e6ecff", fade), 3, true)
			c.draw_line(hub, hub + Vector2.from_angle(-PI * .5 + k * 9) * 18, Color("ffffff", fade), 3, true);c.draw_line(hub, hub + Vector2.from_angle(-PI * .5 + k * 1.5) * 12, Color("ffffff", fade), 3, true)
		"stopped":
			c.draw_arc(at + Vector2(0, -46), 11, 0, TAU, 20, Color("c8d6ff", fade), 2.5, true);c.draw_line(at + Vector2(0, -46), at + Vector2(0, -54), Color.WHITE * Color(1, 1, 1, fade), 2, true)
		"soul_rise":
			for i in range(4):
				var q: Vector2 = at + Vector2((i - 1.5) * 12 + sin(k * 6 + i) * 6, -20 - 70 * k * (1 + i * .15))
				VfxArt.glow(c, q, 12, Color("a8fff0"), .6 * fade);c.draw_circle(q, 3, Color("e8fffa", fade))
		"cancel":
			var r: float = 18 * g * .8;var q: Vector2 = at + Vector2(0, -56)
			c.draw_arc(q, r, 0, TAU, 24, Color("ff6b6b", fade), 3, true);c.draw_line(q + Vector2(-r, -r) * .7, q + Vector2(r, r) * .7, Color("ff6b6b", fade), 4, true)
			c.draw_string(ArenaUI.heading_font(), q + Vector2(-30, -r - 8), "전략 취소", HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color("ffd0d0", fade))
		_:return false
	return true

## 군단장의 깃발: the flag at its spot and its reach on the ground.
static func draw_ground(fx, c: CanvasItem) -> void:
	var host = fx.host;var t: float = host.real_age
	for u in host.battle.units:
		if not u.alive or not u.character_specific_state.has("bannerX") or not ItemEffects.has(u, &"legionBanner"):continue
		var at: Vector2 = Vector2(u.state_value("bannerX"), u.state_value("bannerY"));var rad: float = ItemTuning.BANNER_RADIUS
		var squash := Transform2D(0, Vector2(1, .5), 0, at + Vector2(0, 16))
		c.draw_set_transform_matrix(host.parent_transform * squash)
		c.draw_circle(Vector2.ZERO, rad, Color("ff6a6a", .06));c.draw_arc(Vector2.ZERO, rad, 0, TAU, 64, Color("ff8a8a", .35 + .1 * sin(t * 2)), 2.5, true)
		c.draw_set_transform_matrix(host.parent_transform)
		var top: Vector2 = at + Vector2(0, -56)
		c.draw_line(at + Vector2(0, 16), top, Color("e8d8b0"), 3, true);c.draw_circle(top, 3, Color("ffd54a"))
		var wave: PackedVector2Array = PackedVector2Array([top + Vector2(0, 2)])
		for i in range(6):wave.append(top + Vector2(6 * (i + 1), 4 + sin(t * 4 + i * .8) * 3))
		for i in range(6):wave.append(top + Vector2(36 - 6 * i, 22 + sin(t * 4 + (5 - i) * .8) * 3))
		c.draw_colored_polygon(wave, Color(u.team_color(), .9) if u.has_method("team_color") else Color("ff5a5a"))
		ArenaIcon.draw(c, top + Vector2(18, 12), "legionBanner", 14, Color(1, 1, 1, .9))

## Lasting looks: companions, forms and marks (p: body centre, s: scale).
static func draw_unit(fx, c: CanvasItem, u, p: Vector2, s: float) -> void:
	var host = fx.host;var t: float = host.real_age;var stats: UnitCombatStats = u.combat_stats
	# 영혼: a pale ghost with rising wisps, fading as its time runs out.
	if u.character_specific_state.has("spiritOf"):
		var left: float = clampf(u.state_value("spiritTime") / ItemTuning.SOUL_TIME, 0, 1);var flick: float = .6 + .4 * sin(t * (6 if left > .3 else 18))
		VfxArt.glow(c, p, 46 * s, Color("a8fff0"), .35 * flick);c.draw_arc(p, 30 * s, 0, TAU, 32, Color("c8fff4", .6 * flick), 2.5, true)
		for i in range(3):
			var rise: float = fposmod(t * .8 + i * .33, 1.0);VfxArt.glow(c, p + Vector2((i - 1) * 12 * s, (10 - rise * 46) * s), 8 * s, Color("e8fffa"), .5 * (1 - rise))
		c.draw_arc(p + Vector2(0, -40 * s), 9 * s, -PI * .5, -PI * .5 + TAU * left, 20, Color("a8fff0", .9), 2, true)
	# 시간 정지: a stopped clock and a cold tint.
	if u.state_value("timeStopTime") > 0:
		VfxArt.glow(c, p, 40 * s, Color("8a9ac8"), .35);var q: Vector2 = p + Vector2(0, -48 * s)
		c.draw_circle(q, 12 * s, Color(.1, .12, .2, .75));c.draw_arc(q, 12 * s, 0, TAU, 24, Color("c8d6ff"), 2, true)
		c.draw_line(q, q + Vector2(0, -8) * s, Color.WHITE, 2, true);c.draw_line(q, q + Vector2(6, 0) * s, Color.WHITE, 2, true)
	# 영구 동토: an ice block around a deep-frozen unit.
	if u.state_value("frozenTime") > 0 and u.state_value("deepFreeze") > 0:
		var box: PackedVector2Array = PackedVector2Array()
		for i in range(6):box.append(p + Vector2.from_angle(i * TAU / 6 + .3) * 34 * s)
		c.draw_colored_polygon(box, Color("bfeaff", .22));box.append(box[0]);c.draw_polyline(box, Color("e2f6ff", .9), 2.5, true)
	# 수호 기사의 문장: the challenged enemy wears a red shield mark.
	if u.state_value("crestTaunt") > 0 and u.taunted_until > host.battle.clock.elapsed:
		var q: Vector2 = p + Vector2(18, -40) * s;VfxArt.glow(c, q, 10 * s, Color("ff6a5a"), .5)
		c.draw_colored_polygon(PackedVector2Array([q + Vector2(-6, -6) * s, q + Vector2(6, -6) * s, q + Vector2(6, 1) * s, q + Vector2(0, 7) * s, q + Vector2(-6, 1) * s]), Color("ff6a5a", .9))
	if stats == null or stats.effects.is_empty():return
	var head: Vector2 = p + Vector2(0, -44 * s)
	# 야수 변신: a burning feral aura and turning claws.
	if u.state_value("beastTime") > 0:
		var pulse: float = .5 + .5 * sin(t * 9)
		VfxArt.glow(c, p, 52 * s, Color("ff5a2a"), .3 + .15 * pulse);c.draw_arc(p, 36 * s, 0, TAU, 36, Color("ff7a3a", .6 + .3 * pulse), 3.5, true)
		for i in range(3):
			var a: float = t * 2.4 + i * TAU / 3;var q: Vector2 = p + Vector2.from_angle(a) * 40 * s
			c.draw_line(q, q + Vector2.from_angle(a + 1.2) * 12 * s, Color("ffd0a0", .85), 3, true)
		for side in [-1, 1]:VfxArt.glow(c, head + Vector2(side * 6, 6) * s, 5 * s, Color("ffe066"), .9)
	# 정령 등불: a small spirit floats by the bearer in its element.
	if stats.has(&"spiritLantern"):
		var col: Color = EL.get(String(BuildItems._element(u)), Color("a8fff0"));var q: Vector2 = p + Vector2(-26, -34 + sin(t * 3) * 4) * s
		VfxArt.glow(c, q, 14 * s, col, .55);c.draw_circle(q, 6 * s, col.lightened(.4))
		for side in [-1, 1]:c.draw_circle(q + Vector2(side * 2, -1) * s, 1.2 * s, Color(.1, .1, .15))
		c.draw_arc(q + Vector2(0, 8) * s, 4 * s, 0, PI, 8, Color(col, .6), 2, true)
	# 새끼 용: grows with its stage; wings beat.
	if stats.has(&"dragonEgg"):
		var stage: int = BuildItems.dragon_stage(stats);var z: float = (.75 + stage * .06) * s
		var q: Vector2 = p + Vector2(30, -38 + sin(t * 2.6) * 4) * s;var flap: float = sin(t * 10) * 6
		for side in [-1, 1]:c.draw_colored_polygon(PackedVector2Array([q + Vector2(side * 3, -2) * z, q + Vector2(side * 16, -10 - flap) * z, q + Vector2(side * 12, 4) * z]), Color("d8553a", .9))
		c.draw_circle(q, 8 * z, Color("ff7a4a"));c.draw_circle(q + Vector2(7, -5) * z, 5 * z, Color("ff8a5a"))
		c.draw_circle(q + Vector2(9, -6) * z, 1.4 * z, Color(.1, .05, .05));c.draw_colored_polygon(PackedVector2Array([q + Vector2(-6, 4) * z, q + Vector2(-16, 9) * z, q + Vector2(-5, 7) * z]), Color("d8553a"))
		if stage >= 5:VfxArt.glow(c, q, 16 * z, Color("ffb46a"), .3)
	# 시간 도둑의 회중시계: a pocket watch whose hand winds toward the next stop.
	if stats.has(&"thiefWatch"):
		var q: Vector2 = head + Vector2(-20, -8) * s;var k: float = 1 - clampf(u.state_value("watchClock") / ItemTuning.WATCH_EVERY, 0, 1)
		c.draw_circle(q, 7 * s, Color("2a2238"));c.draw_arc(q, 7 * s, 0, TAU, 20, Color("ffd36b"), 2, true)
		c.draw_line(q, q + Vector2.from_angle(-PI * .5 + k * TAU) * 6 * s, Color("fff3c8"), 1.5, true)
	# 블랙홀 구슬: a small dark orb circling.
	if stats.has(&"blackHoleOrb"):
		var q: Vector2 = p + Vector2.from_angle(t * 1.6) * 30 * s;VfxArt.glow(c, q, 10 * s, Color("6a3aa8"), .6);c.draw_circle(q, 4 * s, Color(.05, .02, .1))
	# 결투가의 망토 / 복수의 가면: stacks shown as pips and a red pulse.
	if u.state_value("capeTime") > 0:
		for i in range(int(u.state_value("capeStacks"))):c.draw_circle(head + Vector2((i - 1) * 8, -10) * s, 3 * s, Color("ff8aa0"))
	if u.state_value("vengeance") > 0:
		var n: float = minf(5, u.state_value("vengeance"));VfxArt.glow(c, p, (34 + n * 3) * s, Color("ff3a3a"), .12 + .05 * n * (.5 + .5 * sin(t * 5)))
	# 돌격 나팔: speed lines while it charges.
	if u.state_value("hornDash") > 0:
		var back: Vector2 = -Vector2.from_angle(u.facing)
		for i in range(4):c.draw_line(p + back * (20 + i * 6) * s + back.orthogonal() * (i - 1.5) * 9 * s, p + back * (48 + i * 10) * s + back.orthogonal() * (i - 1.5) * 9 * s, Color("ffd08a", .8), 3, true)
	# 방패 대장장이의 망치: the boost shows while the shield lasts.
	if stats.has(&"shieldHammer") and u.shield_hp > 0 and u.shield_remaining > 0:VfxArt.glow(c, p + Vector2.from_angle(u.facing) * 28 * s, 10 * s, Color("ffe08a"), .5)

## 블랙홀 and the 포격수 shell, above everything.
static func draw_over(fx, c: CanvasItem) -> void:
	var host = fx.host;var t: float = host.real_age
	for u in host.battle.units:
		if not u.alive or u.state_value("holeTime") <= 0:continue
		var at: Vector2 = Vector2(u.state_value("holeX"), u.state_value("holeY"));var left: float = u.state_value("holeTime") / ItemTuning.BLACKHOLE_TIME
		var open: float = minf(1, (1 - left) * 6) * minf(1, left * 5);var rad: float = ItemTuning.BLACKHOLE_RADIUS
		VfxArt.glow(c, at, rad * .9 * open, Color("4a1a8a"), .45 * open)
		for i in range(6):
			var r: float = rad * fposmod(1 - t * .9 - i / 6.0, 1.0)
			c.draw_arc(at, r * open, t * 3 + i, t * 3 + i + 2.2, 20, Color("b48cff", .6 * open * (r / rad)), 2.5, true)
		for i in range(10):
			var a: float = i * TAU / 10 + t * 2;var r: float = rad * fposmod(1 - t * 1.3 - i * .1, 1.0)
			c.draw_circle(at + Vector2.from_angle(a) * r * open, 2.5, Color("e6d6ff", .8 * open))
		c.draw_circle(at, 26 * open, Color(.02, .0, .05, .95));c.draw_arc(at, 27 * open, 0, TAU, 32, Color("d9c2ff", .9 * open), 2.5, true)
	for pr in host.battle.projectiles:
		if not pr.live or pr.kind != "gunnerShell":continue
		var back: Vector2 = pr.position - pr.velocity.normalized() * 46
		c.draw_line(back, pr.position, Color("ffb46a", .7), 9, true);VfxArt.glow(c, pr.position, 26, Color("ff8a3d"), .6)
		c.draw_circle(pr.position, 10, Color("3a3030"));c.draw_circle(pr.position + Vector2(-3, -3), 3.5, Color("ffd08a"))
