extends "res://tests/layout_parity_runner.gd"
func run():
	root.gui_embed_subwindows=true
	for res in [Vector2i(390,844),Vector2i(1280,800)]:
		root.size=res;root.content_scale_size=res;tag="mobile" if res.x<500 else "desktop"
		for room_id in ["0:0","0:1","0:2"]:
			await fresh();ui.select_room(room_id);await frames();ui.fx.advance(3)
			var c: TowerContentScreen=ui.content_screen
			verify(c!=null and fits(c.room_frame),"content frame fits "+room_id)
			verify(fits(c.map_button),"content return action visible "+room_id)
			await shot("recruit" if room_id=="0:0" else "shop" if room_id=="0:1" else "rest")
		await fresh();await shot("tower")
	ui.free();await frames();print("LAYOUT AUDIT RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
