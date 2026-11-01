class_name TowerCinematic
extends Control
## Full-screen tower cutscenes in the typographic motion language of the other UI cutscenes
## (TypeArt): a deep navy field with fine slanted lines, the tower as a typographic stack of fifteen
## numbered floor bars in the chapter colours, slanted panels, huge drifting English words, titles
## rising letter by letter over centre-out gold rules, and gold motes.
## "intro" — the stack builds floor by floor under "두니 타워", then the first chapter's card.
## "clear" — the cleared chapter's five bars fill with gold one by one and burst; "CHAPTER N
##           CLEAR" is stamped; then the next chapter's card.
## "enter" — only the chapter card (resuming a run, climbing into a new chapter).
## Tapping skips to the fade-out. The screen's own UI fades out while this plays.
signal finished
const FLOORS: int = 15
const GOLD := Color("f0d490")
const INK := Color(.02, .04, .1)
var mode: String = ""
var chapter: int = 1 # chapter introduced (for "clear": the one after the cleared chapter)
var t: float = 0
var duration: float = 0
var fade_at: float = 0
var view := Vector2(390, 844)
var shards: Array = [] # chapter clear: [bar 0..4, x 0..1, velocity, spin, size]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter = Control.MOUSE_FILTER_STOP;visible = false
	gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed and t < fade_at:t = fade_at)

func active() -> bool:return visible
## Cutscenes play by themselves only in the real game with motion on: not with the motion
## setting off, and not under a scripted test/capture harness (a custom main loop script).
static func auto_play() -> bool:
	return UiMotion.enabled and Engine.get_main_loop().get_script() == null

func play(kind: String, intro_chapter: int) -> void:
	mode = kind;chapter = intro_chapter;t = 0
	duration = {"intro":8.0, "clear":8.6, "enter":3.8}[kind];fade_at = duration - .6
	shards.clear()
	var rng := RandomNumberGenerator.new();rng.seed = hash(kind + str(intro_chapter))
	for i in range(70):shards.append([i % 5, rng.randf(), Vector2(rng.randf_range(-260, 260), rng.randf_range(-420, -60)), rng.randf_range(-8, 8), rng.randf_range(3, 9)])
	visible = true;view = get_viewport_rect().size;queue_redraw()

func _process(dt: float) -> void:
	if not visible:return
	t += dt;view = get_viewport_rect().size
	# Once skipped (or fading anyway) taps go straight through to the screen underneath.
	mouse_filter = Control.MOUSE_FILTER_IGNORE if t >= fade_at else Control.MOUSE_FILTER_STOP
	if t >= duration:visible = false;finished.emit();return
	queue_redraw()

func _draw() -> void:
	modulate.a = minf(Motion.phase(t, 0, .35), clampf((duration - t) / .6, 0, 1))
	_backdrop()
	match mode:
		"intro":_intro()
		"clear":_clear()
		_:_stack(1.0, .35, -1, 0);_chapter_card(t - .2, fade_at + .1)
	if t < fade_at:draw_string(get_theme_default_font(), Vector2(0, view.y - 18), "화면을 누르면 건너뜁니다  ", HORIZONTAL_ALIGNMENT_RIGHT, view.x, 11, Color(1, 1, 1, .4))

# ---- Backdrop ----
## Deep navy to indigo, fine slanted lines drifting slowly, the chapter's colour glowing low.
func _backdrop() -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]), PackedColorArray([TypeArt.NAVY, TypeArt.NAVY, Color("161f44"), Color("161f44")]))
	var step: float = 26;var slant: float = view.y * .35;var shift: float = fposmod(t * 12, step)
	for i in range(int((view.x + slant) / step) + 2):
		var x: float = i * step - slant + shift
		draw_line(Vector2(x + slant, 0), Vector2(x, view.y), Color(1, 1, 1, .025), 1)
	VfxArt.glow(self, Vector2(view.x * .5, view.y * .82), view.x * .9, _tint(chapter), .18, .5)
	VfxArt.glow(self, Vector2(view.x * .5, view.y * .2), view.x * .7, Color("3a4f9a"), .2, .6)

func _tint(ch: int) -> Color:return TowerArt.chapter_tint(ch).lightened(.25)

# ---- The typographic tower ----
## Fifteen floor bars stacked bottom to top, five per chapter. Conquered chapters are solid gold,
## the introduced chapter lights up in its colour, the rest are faint outlines. `build` (0..1)
## raises the bars one by one from the bottom; `focus` dims bars outside the introduced chapter;
## `filled` bars of the cleared chapter (index 0..5) fill with gold; after the `burst` they are gone
## (shattered) and grow back as solid gold a moment later.
func _stack(build: float, focus: float, cleared: int, filled: int, burst: bool = false) -> void:
	var bar_h: float = clampf(view.y * .022, 12, 20);var gap: float = bar_h * .5;var bar_w: float = minf(view.x * .46, 240)
	var bottom: float = view.y * .9;var x0: float = view.x * .5 - bar_w * .5
	for f in range(FLOORS):
		var k: float = Motion.out_expo(Motion.phase(build * (FLOORS * .12 + .4), f * .12, .4))
		if k <= 0:continue
		var ch: int = f / 5 + 1;var y: float = bottom - (f + 1) * (bar_h + gap)
		var side: float = -1.0 if f % 2 else 1.0;var rect := Rect2(Vector2(x0 + side * (1 - k) * 60, y), Vector2(bar_w, bar_h))
		var conquered: bool = ch < chapter and not (cleared >= 0 and ch == chapter - 1 and f - (ch - 1) * 5 >= filled)
		var current: bool = ch == chapter
		var regrow: float = 1.0
		if burst and cleared >= 0 and ch == chapter - 1:conquered = true;regrow = Motion.phase(t, 2.8, .5)
		var dim: float = (1.0 if current or conquered else focus) * regrow
		var col: Color = GOLD if conquered else _tint(ch) if current else Color(.6, .68, .9)
		var a: float = k * dim
		if conquered:draw_rect(rect, Color(col, .85 * a))
		elif current:draw_rect(rect, Color(col, .28 * a))
		draw_rect(rect, Color(col, (.9 if current or conquered else .35) * a), false, 1.5)
		# Floor number on the left, chapter mark on the right of each five.
		draw_string(ArenaUI.numbers_font(), Vector2(rect.position.x - 34, rect.end.y - 2), "%02d" % (f + 1), HORIZONTAL_ALIGNMENT_RIGHT, 26, 12, Color(col, .8 * a))
		if f % 5 == 4:draw_string(ArenaUI.numbers_font(), Vector2(rect.end.x + 8, rect.end.y + bar_h * 1.2), "CH.%d" % ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, .7 * a))
		if f % 5 == 4 and f < FLOORS - 1:draw_line(Vector2(rect.position.x - 40, rect.position.y - gap * .5), Vector2(rect.end.x + 40, rect.position.y - gap * .5), Color(1, 1, 1, .08 * a), 1)
func _bar_rect(f: int) -> Rect2:
	var bar_h: float = clampf(view.y * .022, 12, 20);var gap: float = bar_h * .5;var bar_w: float = minf(view.x * .46, 240)
	return Rect2(Vector2(view.x * .5 - bar_w * .5, view.y * .9 - (f + 1) * (bar_h + gap)), Vector2(bar_w, bar_h))

# ---- Intro ----
func _intro() -> void:
	# The stack builds while the title rises; at 3.2 s the first chapter lights up and its card opens.
	var focus: float = lerpf(.6, .3, Motion.phase(t, 3.0, .6))
	_stack(Motion.phase(t, .3, 2.4), focus, -1, 0)
	var out: float = Motion.in_cubic(Motion.phase(t, 2.9, .45));var a: float = Motion.phase(t, .4, .3) * (1 - out)
	if a > 0:
		var y: float = view.y * .2 - out * 30;var size: int = int(clampf(view.x * .15, 44, 86))
		TypeArt.watermark(self, TypeArt.word(&"tower"), Vector2(view.x * .5 + 40 * (1 - Motion.out_quint(Motion.phase(t, .4, 1.6))), y), int(clampf(view.x * .24, 80, 180)), Color(1, 1, 1, .06 * a), -.22, 6)
		_title(ArenaUI.numbers_font(), "DUNI ARENA", Vector2(view.x * .5, y - size * .9), 18, Color(GOLD, a), t - .5)
		TypeArt.rule(self, Vector2(view.x * .5, y - size * .9 + 9), 70, Motion.phase(t, .7, Motion.ENTER), Color(GOLD, .8 * a), 2)
		_title(ArenaUI.heading_font(), "두니 타워", Vector2(view.x * .5, y), size, Color(1, .98, .92, a), t - .7)
		_line("끝없이 하늘로 뻗은 탑", y + size * .55, 15, Color(.82, .87, 1, .9 * a * Motion.phase(t, 1.2, .5)))
		TypeArt.motes(self, Rect2(0, y - size, view.x, size * 2), t, Color(GOLD, .5 * a), 16, true, .2)
	_chapter_card(t - 3.4, fade_at + .1)

# ---- Chapter clear ----
func _clear() -> void:
	var cleared: int = chapter - 1;var burst_at: float = 1.9
	# The cleared chapter's bars fill with gold one by one, flash and shatter.
	var filled: int = clampi(int((t - .5) / .24) + 1, 0, 5) if t >= .5 else 0
	var shake := Vector2(sin(t * 61), cos(t * 47)) * 7 * (1 - Motion.phase(t, burst_at, .5)) if t >= burst_at else Vector2.ZERO
	draw_set_transform(shake)
	_stack(1.0, .3, cleared, filled, t >= burst_at)
	var first: int = (cleared - 1) * 5
	if t < burst_at:
		for i in range(filled):VfxArt.glow(self, _bar_rect(first + i).get_center(), _bar_rect(first).size.x * .45, GOLD, .25)
		VfxArt.glow(self, _bar_rect(first + 2).get_center(), _bar_rect(first).size.x * (.6 + .3 * Motion.phase(t, 1.2, .7)), Color("fff4d2"), .35 * Motion.phase(t, 1.2, .7))
	else:
		var age: float = t - burst_at;var center: Vector2 = _bar_rect(first + 2).get_center()
		VfxArt.glow(self, center, view.x * (.4 + age), Color("fff4d2"), .9 * (1 - Motion.phase(age, 0, .6)))
		for ring in [1.0, 1.6]:draw_arc(center, 30 + view.x * .7 * ring * Motion.out_expo(Motion.phase(age, 0, .9)), 0, TAU, 64, Color(GOLD, .8 * (1 - Motion.phase(age, 0, .9))), 3, true)
		for s in shards:
			var rect: Rect2 = _bar_rect(first + s[0]);var p: Vector2 = Vector2(rect.position.x + s[1] * rect.size.x, rect.get_center().y) + s[2] * age + Vector2(0, 520 * age * age)
			var fade: float = 1 - Motion.phase(age, .2, 1.1)
			if fade <= 0:continue
			draw_set_transform(p + shake, s[3] * age, Vector2.ONE)
			draw_rect(Rect2(Vector2(-s[4], -s[4] * .4), Vector2(s[4] * 2, s[4] * .8)), Color(GOLD.lightened(.2), fade))
		draw_set_transform(shake)
		TypeArt.motes(self, Rect2(center.x - view.x * .3, center.y - view.y * .3, view.x * .6, view.y * .35), t, Color(GOLD, .7 * (1 - Motion.phase(age, 1.5, 1.0))), 26, true, .4)
	draw_set_transform(Vector2.ZERO)
	# "CHAPTER N CLEAR" stamped at the top over a huge drifting "CLEAR".
	var lt: float = t - (burst_at + .05);var a: float = Motion.phase(lt, 0, .12) * (1 - Motion.in_cubic(Motion.phase(t, 3.6, .4)))
	if lt > 0 and a > 0:
		var y: float = view.y * .2
		TypeArt.panels(self, Rect2(0, y - 52, view.x, 110), lt, false, [Color(INK, .6), Color(GOLD.darkened(.6), .7), Color(.04, .06, .14, .9)], 3.6 - burst_at - .45, GOLD)
		TypeArt.watermark(self, TypeArt.word(&"clear"), Vector2(view.x * .5 + 40 * (1 - Motion.out_quint(Motion.phase(lt, .05, .9))), y), int(clampf(view.x * .3, 100, 220)), Color(GOLD, .14 * a), -.22, 14 * (1 - Motion.phase(lt, .05, .9)))
		var stamp: float = lerpf(1.6, 1.0, Motion.emphasis(Motion.phase(lt, 0, .35)))
		draw_set_transform(Vector2(view.x * .5, y) * (1 - stamp), 0, Vector2.ONE * stamp)
		_title(ArenaUI.numbers_font(), "CHAPTER %d CLEAR" % cleared, Vector2(view.x * .5, y + 8), clampf(view.x * .1, 28, 60), Color(GOLD, a), lt)
		draw_set_transform(Vector2.ZERO)
		TypeArt.rule(self, Vector2(view.x * .5, y + 22), minf(150, view.x * .32), Motion.phase(lt, .3, Motion.ENTER), Color(GOLD, .8 * a), 2)
		_title(ArenaUI.heading_font(), "%s 정복" % TowerSceneDirector.CHAPTER_NAMES.get(cleared, ""), Vector2(view.x * .5, y + 48), 18, Color(1, 1, 1, a), lt - .35)
	_chapter_card(t - 4.0, fade_at + .1)

# ---- Chapter card ----
## Slanted panels in the chapter's colour sweep in at the top, a huge outlined chapter number
## drifts behind, "CHAPTER N" and the chapter's name rise letter by letter over a gold rule, the
## floor range follows, five floor diamonds light up and a sheen crosses the band.
func _chapter_card(lt: float, until: float) -> void:
	if lt <= 0 or t >= until + .6:return
	var a: float = Motion.phase(lt, 0, .15) * clampf((until + .4 - t) / .4, 0, 1);var tint: Color = _tint(chapter)
	var y: float = view.y * .2;var first: int = (chapter - 1) * 5 + 1;var band := Rect2(0, y - 70, view.x, 170)
	TypeArt.panels(self, band, lt, false, [Color(INK, .7), Color(tint.darkened(.65), .75), Color(.03, .05, .12, .92)], until - (t - lt) - .1, tint)
	var drift: float = Motion.out_quint(Motion.phase(lt, .08, 1.0))
	TypeArt.watermark(self, "%02d" % chapter, Vector2(view.x * .5 + 50 * (1 - drift), y + 10), int(clampf(view.x * .45, 140, 300)), Color(tint, .12 * a * drift), -.22, 0)
	_title(ArenaUI.numbers_font(), "CHAPTER %02d" % chapter, Vector2(view.x * .5, y - 32), 18, Color(tint, a), lt)
	_title(ArenaUI.heading_font(), TowerSceneDirector.CHAPTER_NAMES.get(chapter, ""), Vector2(view.x * .5, y + 22), clampf(view.x * .11, 32, 62), Color(1, .98, .92, a), lt - .15)
	TypeArt.rule(self, Vector2(view.x * .5, y + 38), minf(150, view.x * .32), Motion.phase(lt, .3, Motion.ENTER), Color(tint, .85 * a), 2)
	var sub_in: float = Motion.out_expo(Motion.phase(lt, .4, Motion.ENTER))
	_line("%d층 – %d층" % [first, first + 4], y + 64 + 8 * (1 - sub_in), 15, Color(.85, .9, 1, .9 * a * sub_in))
	for i in range(5):
		var k: float = Motion.emphasis(Motion.phase(lt, .55 + i * .09, .3));var at := Vector2(view.x * .5 + (i - 2) * 22, y + 84)
		var s: float = 5 * k
		if s > .1:draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s, 0), at + Vector2(0, s), at + Vector2(-s, 0)]), Color(tint, a))
	TypeArt.sweep(self, band, Motion.phase(lt, .5, .7), .14, 50)
	TypeArt.motes(self, Rect2(0, band.position.y, view.x, band.size.y), lt, Color(tint, .55 * a), 16, true, .25)

# ---- Text ----
## A centred title whose letters rise into place one by one (UI motion off: all at once), with a
## soft drop shadow and a dark outline.
func _title(font: Font, text: String, center: Vector2, size: float, color: Color, age: float) -> void:
	if not UiMotion.enabled:age = 99
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x;var at := Vector2(center.x - width * .5, center.y)
	TypeArt.letters(self, font, text, at + Vector2(2, 3), int(size), Color(INK, .55 * color.a), age, size * .5)
	TypeArt.letters(self, font, text, at, int(size), color, age, size * .5, Color(INK, .75 * color.a))
func _line(text: String, y: float, size: int, color: Color) -> void:
	draw_string(ArenaUI.heading_font(), Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, view.x, size, color)
