class_name Palette
extends RefCounted
## 고정 팔레트: 투명 + 31색. 모든 도트 스프라이트는 이 색만 써요.
## 분위기: 백룸(누런 형광등 사무실) — 누런 벽지 · 깔끔한 어두운 바닥 타일 · 회색 설비 · 주황 택배 박스.
## tools/gen_assets.gd가 assets/palette.png(8×4)로도 저장해요.

enum {
	CLEAR, INK, BROWN_D, BROWN, CARD, ORANGE, ORANGE_L, CREAM, PAPER,
	WALL, WALL_D, FLOOR, FLOOR_D, LIGHT, G1, G2, G3, G4, G5,
	RED, RED_D, PINK, GREEN, GREEN_D, LIME, BLUE, BLUE_D, CYAN, PURPLE, YELLOW, SKIN, TEAL,
}

## 정적 변수 대신 상수로 둬요 (Godot 4.3에서 정적 변수가 있는 스크립트가 끌 때 '누수'로 보고돼서)
const COLORS := [
	Color("00000000"), Color("1b1612"), Color("3d2c1f"), Color("6e4b2e"), Color("b07a43"), Color("e0862a"),
	Color("f4b860"), Color("f2e4b0"), Color("f6f3ea"), Color("d6c477"), Color("a8954c"), Color("3a3e4b"),
	Color("2b2e38"), Color("fff8d6"), Color("26282d"), Color("42454c"), Color("646872"), Color("8f939b"),
	Color("c3c6ca"), Color("c4433a"), Color("7a2826"), Color("e88fa5"), Color("5b9c48"), Color("345a30"),
	Color("b2d95e"), Color("3f72b8"), Color("263f70"), Color("63c6dc"), Color("8c5bb8"), Color("f1d23d"),
	Color("d99878"), Color("2f7070"),
]


static func c(i: int) -> Color:
	return COLORS[i]


static func image() -> Image:
	## 팔레트 견본 8×4 (0번은 투명)
	var img := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	for i in COLORS.size():
		img.set_pixel(i % 8, int(i / 8.0), c(i))
	return img
