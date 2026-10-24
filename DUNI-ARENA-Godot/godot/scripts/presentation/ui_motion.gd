class_name UiMotion
extends RefCounted
## Game-feel motion for menus: pages fade in while their rows and cards pop in order, buttons
## squash on press and spring back, dialogs pop open. Visual only: modulate and scale around
## the pivot are animated, layout and hit areas never move. Off in headless runs.
static var enabled: bool = DisplayServer.get_name() != "headless"

static func _tween(c: Control) -> Tween:
	if c.has_meta("motion_tween"):
		var old = c.get_meta("motion_tween")
		if old is Tween and old.is_valid():old.kill()
	var t: Tween = c.create_tween();c.set_meta("motion_tween", t);return t

## Fade + springy scale-in for one control; keeps whatever alpha it was meant to have.
static func pop(c: Control, delay: float = 0, from_scale: float = .92, time: float = .28) -> void:
	if not enabled or not is_instance_valid(c) or not c.is_inside_tree():return
	var alpha: float = float(c.get_meta("motion_alpha", c.modulate.a));c.set_meta("motion_alpha", alpha)
	c.pivot_offset = c.size * .5;c.modulate.a = 0;c.scale = Vector2.ONE * from_scale
	var t: Tween = _tween(c).set_parallel(true)
	t.tween_property(c, "modulate:a", alpha, time * .7).set_delay(delay)
	t.tween_property(c, "scale", Vector2.ONE, time).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(func():c.remove_meta("motion_alpha"))

## Fade only (no scale), for rows whose position must stay pixel-stable.
static func fade(c: Control, delay: float = 0, time: float = .22) -> void:
	if not enabled or not is_instance_valid(c) or not c.is_inside_tree():return
	var alpha: float = float(c.get_meta("motion_alpha", c.modulate.a));c.set_meta("motion_alpha", alpha);c.modulate.a = 0
	var t: Tween = _tween(c);t.tween_property(c, "modulate:a", alpha, time).set_delay(delay)
	t.tween_callback(func():c.remove_meta("motion_alpha"))

## Page entrance: rows of the main column fade in, then the on-screen cards pop in one by one.
## The brand bar and wallet header stay put so pages share one steady header.
static func enter(root: Control) -> void:
	if not enabled or not is_instance_valid(root) or not root.is_inside_tree():return
	await root.get_tree().process_frame
	if not is_instance_valid(root):return
	var column: BoxContainer = _column(root)
	var rows: Array = [] if column == null else column.get_children().filter(func(c):return c is Control and c.visible and not (c is ArenaBrandBar or c is WalletBar))
	for i in range(mini(rows.size(), 10)):fade(rows[i], i * .04)
	var view: Rect2 = root.get_viewport_rect();var cards: Array = []
	_collect_cards(root, view, cards)
	# Cards sharing a row pop together, rows follow one another down the page.
	var rows_y: Array = []
	for card in cards:
		var y: int = roundi(card.get_global_rect().position.y)
		if y not in rows_y:rows_y.append(y)
	rows_y.sort()
	for card in cards.slice(0, 24):pop(card, .12 + rows_y.find(roundi(card.get_global_rect().position.y)) * .06, .86, .32)

static func _column(node: Node) -> BoxContainer:
	var queue: Array = [node]
	while not queue.is_empty():
		var n: Node = queue.pop_front()
		if n is BoxContainer and n.get_children().filter(func(c):return c is Control and c.visible).size() >= 3:return n
		for child in n.get_children():
			if child is Control and child.visible:queue.append(child)
	return null

static func _collect_cards(node: Node, view: Rect2, out: Array) -> void:
	for child in node.get_children():
		# The dungeon map unrolls its own rooms.
		if not (child is Control) or not child.visible or child is DungeonMap:continue
		if child is ArenaCard:
			# Header nav buttons stay fixed with the rest of the shared header.
			if child.card_type!="nav" and view.intersects(child.get_global_rect()):out.append(child)
		else:_collect_cards(child, view, out)

static func press(b: BaseButton) -> void:
	if not enabled or b.disabled or not b.is_inside_tree():return
	b.pivot_offset = b.size * .5
	_tween(b).tween_property(b, "scale", Vector2.ONE * .94, .07).set_ease(Tween.EASE_OUT)

static func release(b: BaseButton) -> void:
	if not enabled or not b.is_inside_tree():return
	_tween(b).tween_property(b, "scale", Vector2.ONE, .3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func hover(b: BaseButton, inside: bool) -> void:
	if not enabled or ArenaUI.touch_ui() or not b.is_inside_tree() or b.has_meta("breathing"):return
	var t: Tween = b.create_tween()
	t.tween_property(b, "self_modulate", Color(1.12, 1.12, 1.12) if inside and not b.disabled else Color.WHITE, .12)

## Dialog content fades in once the dialog has settled its size. No scale, so dialog headers
## (close / menu buttons) sit exactly where the page header buttons are.
static func dialog_opened(w: Window) -> void:
	if not enabled or not w.is_inside_tree():return
	var items: Array = w.get_children().filter(func(c):return c is Control and c.visible)
	for c in items:c.modulate.a = 0
	await w.get_tree().process_frame
	await w.get_tree().process_frame
	for c in items:
		if is_instance_valid(c):c.set_meta("motion_alpha", 1.0);fade(c, 0, .2)

## Slow glow on the main call-to-action.
static func breathe(c: Control) -> void:
	if not enabled or not is_instance_valid(c) or not c.is_inside_tree() or c.has_meta("breathing"):return
	var t: Tween = c.create_tween().set_loops();c.set_meta("breathing", t)
	t.tween_property(c, "self_modulate", Color(1.15, 1.13, 1.05), .9).set_trans(Tween.TRANS_SINE)
	t.tween_property(c, "self_modulate", Color.WHITE, .9).set_trans(Tween.TRANS_SINE)

## Recruit reroll: cards flip over one after another (scale.x 0 -> 1 with a springy settle).
static func deal(cards: Array) -> void:
	if not enabled or cards.is_empty():return
	var tree: SceneTree = cards[0].get_tree()
	if tree == null:return
	for c in cards:
		if c is Control:c.modulate.a = 0
	# Containers reset child scale when they lay out, so start the flip after that frame.
	await tree.process_frame
	for i in range(cards.size()):
		var c = cards[i]
		if not is_instance_valid(c):continue
		c.pivot_offset = c.size * .5;c.scale = Vector2(0, 1);c.modulate.a = 1
		var t: Tween = _tween(c).set_parallel(true)
		t.tween_property(c, "scale", Vector2.ONE, .34).set_delay(i * .09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(c, "modulate:a", 1.0, .2).from(0.3).set_delay(i * .09)

## Selected cards and tabs give a small bounce.
static func bump(c: Control) -> void:
	if not enabled or not c.is_inside_tree():return
	c.pivot_offset = c.size * .5;c.scale = Vector2.ONE * 1.06
	_tween(c).tween_property(c, "scale", Vector2.ONE, .28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Cards scrolled into view fade up from dim, once per pass; positions never change.
static func scrolled(sc: ScrollContainer, vertical: bool) -> void:
	if not enabled or not is_instance_valid(sc) or not sc.is_inside_tree():return
	var key: String = "motion_v" if vertical else "motion_h"
	var value: float = sc.scroll_vertical if vertical else sc.scroll_horizontal
	var last: float = float(sc.get_meta(key, value));sc.set_meta(key, value)
	var delta: float = value - last
	if absf(delta) < 1:return
	var view: Rect2 = sc.get_global_rect();var cards: Array = []
	_collect_cards(sc, Rect2(-1e6, -1e6, 2e6, 2e6), cards)
	for card in cards:
		var now: Rect2 = card.get_global_rect()
		var before: Rect2 = now;before.position += Vector2(0, delta) if vertical else Vector2(delta, 0)
		if now.intersects(view) and not before.intersects(view):
			var alpha: float = float(card.get_meta("motion_alpha", card.modulate.a));card.set_meta("motion_alpha", alpha);card.modulate.a = alpha * .25
			var t: Tween = _tween(card);t.tween_property(card, "modulate:a", alpha, .22)
			t.tween_callback(func():card.remove_meta("motion_alpha"))

static func calm(c: Control) -> void:
	if not is_instance_valid(c) or not c.has_meta("breathing"):return
	var t = c.get_meta("breathing")
	if t is Tween and t.is_valid():t.kill()
	c.remove_meta("breathing");c.self_modulate = Color.WHITE
