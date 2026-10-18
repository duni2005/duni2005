extends "res://tests/blue_touch_runner.gd"
func run():
	for row in [[Vector2i(1080,2340),480,Vector2i(360,780)],[Vector2i(1080,2340),440,Vector2i(393,851)],[Vector2i(1440,3088),640,Vector2i(360,772)],[Vector2i(720,1560),320,Vector2i(360,780)],[Vector2i(1600,2560),320,Vector2i(800,1280)],[Vector2i(390,844),0,Vector2i(390,844)],[Vector2i(1440,3088),960,Vector2i(360,772)],[Vector2i.ZERO,320,Vector2i.ONE]]:
		verify(ArenaUI.android_logical_size(row[0],row[1])==row[2],"native Android logical dp scale "+str(row))
	root.size=Vector2i(1080,2340);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE;root.content_scale_size=ArenaUI.android_logical_size(root.size,480)
	var holder:=Control.new();holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(holder)
	var button:=Button.new();button.position=Vector2(30,80);button.custom_minimum_size=Vector2(120,44);button.text="터치";holder.add_child(button);var calls: Array=[0];ArenaUI.bind(button,func():calls[0]+=1)
	await frames();verify(button.size.y>=44 and (root.get_final_transform()*Vector2(0,44)).y>=88,"dp touch target retains physical size on a high density display")
	var p: Vector2=root.get_final_transform()*ArenaUI.control_center(button)
	pointer(p,true);await process_frame;pointer(p,false);await frames();verify(calls[0]==1,"actual high-density touch maps to the logical button once")
	holder.free();await frames()
	await super.run()
