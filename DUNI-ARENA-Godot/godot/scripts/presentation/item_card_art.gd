class_name ItemCardArt
extends RefCounted
## An item drawn as a card (the shop and inventory details), in the strategy card's style
## (CardFace): the name plate at the top centre, the item icon in the picture, the grade in the
## centre band ("◆◆ 희귀", "소모품"), the effect below, and a 대가 line in red when it has one.
## The frame takes the grade colour (a fully enhanced item: gold).
static func draw(c: CanvasItem, rect: Rect2, kind: StringName, data: ItemData, grade_color: Color = Color(0, 0, 0, 0)) -> void:
	if data == null:return
	var w: float = rect.size.x;var h: float = rect.size.y
	var col: Color = grade_color if grade_color.a > 0 else Color("c9b48a") if data.consumable else ItemCatalog.grade_color(kind)
	CardFace.frame(c, rect, col.darkened(.82), col, false, false)
	var inset: float = maxf(3, w * .06)
	var plate := Rect2(rect.position + Vector2(inset * .7, h * .035), Vector2(w - inset * 1.4, h * .085))
	var pic := Rect2(Vector2(rect.position.x + inset, plate.end.y + h * .02), Vector2(w - inset * 2, h * .34))
	var band := Rect2(Vector2(rect.position.x + inset * .6, pic.end.y + h * .015), Vector2(w - inset * 1.2, h * .07))
	CardFace.picture(c, pic, String(kind), col.darkened(.45), col.darkened(.85), col, false)
	CardFace.plate(c, plate, data.display_name, col, false)
	var rank: int = ItemCatalog.grade_rank(kind)
	CardFace.band(c, band, "소모품" if data.consumable else "%s %s" % ["◆".repeat(maxi(1, rank + 1)), ItemCatalog.grade_name(kind)], col, false)
	var cost: String = ItemCatalog.cost_text(kind)
	# One line per stat / effect (the description joins them with " · ").
	var lines: Array = Array(ItemCatalog.body_text(data).split(" · ", false)).map(func(t): return [t, Color(0, 0, 0, 0)])
	if not cost.is_empty():lines.append([cost, ArenaUI.COST_RED])
	var body := Rect2(Vector2(rect.position.x + inset * 1.2, band.end.y + h * .025), Vector2(w - inset * 2.4, rect.end.y - band.end.y - h * .06))
	CardFace.text(c, body, lines, int(clampf(w * .068, 9, 17)), Color("e8ecf6"), col.lightened(.35))
