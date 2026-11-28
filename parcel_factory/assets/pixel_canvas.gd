class_name PixelCanvas
extends RefCounted
## 도트 그리기 도구. 팔레트 번호로만 칠해요.
## frame()으로 시트 안의 한 칸(프레임)을 고르고 그 안 좌표로 그려요.
## k: 단위 배율. 아이템 아이콘은 16칸 기준으로 그리고 8×8에서는 k=0.5로 줄여 그려요.

var img: Image
var ox := 0
var oy := 0
var fw := 16
var fh := 16
var k := 1.0


func _init(w: int, h: int) -> void:
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)


func frame(x: int, y: int, w: int, h: int) -> void:
	ox = x
	oy = y
	fw = w
	fh = h


func px(x: int, y: int, ci: int) -> void:
	if x < 0 or y < 0 or x >= fw or y >= fh:
		return
	img.set_pixel(ox + x, oy + y, Palette.c(ci))


func is_set(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= fw or y >= fh:
		return false
	return img.get_pixel(ox + x, oy + y).a > 0.0


func rect(x: float, y: float, w: float, h: float, ci: int) -> void:
	var x0 := int(floor(x * k))
	var y0 := int(floor(y * k))
	var x1 := maxi(x0 + 1, int(ceil((x + w) * k)))
	var y1 := maxi(y0 + 1, int(ceil((y + h) * k)))
	for yy in range(y0, y1):
		for xx in range(x0, x1):
			px(xx, yy, ci)


func disc(cx: float, cy: float, r: float, ci: int) -> void:
	var rr := r * k
	var ccx := cx * k
	var ccy := cy * k
	if rr < 0.75:
		px(int(ccx), int(ccy), ci)
		return
	for yy in range(int(floor(ccy - rr)), int(ceil(ccy + rr)) + 1):
		for xx in range(int(floor(ccx - rr)), int(ceil(ccx + rr)) + 1):
			var dx := xx + 0.5 - ccx
			var dy := yy + 0.5 - ccy
			if dx * dx + dy * dy <= rr * rr:
				px(xx, yy, ci)


func line(x0: float, y0: float, x1: float, y1: float, ci: int) -> void:
	var n := int(maxf(absf(x1 - x0), absf(y1 - y0)) * k * 2.0) + 1
	for i in n + 1:
		var t := float(i) / float(n)
		px(int(floor(lerpf(x0, x1, t) * k)), int(floor(lerpf(y0, y1, t) * k)), ci)


func outline(ci: int = Palette.INK) -> void:
	## 그린 모양 둘레(상하좌우로 맞닿은 빈 칸)에 1px 테두리
	var add := []
	for y in fh:
		for x in fw:
			if is_set(x, y):
				continue
			if is_set(x - 1, y) or is_set(x + 1, y) or is_set(x, y - 1) or is_set(x, y + 1):
				add.append(Vector2i(x, y))
	for p in add:
		px(p.x, p.y, ci)
