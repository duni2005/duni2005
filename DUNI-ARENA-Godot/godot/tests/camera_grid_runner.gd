extends SceneTree
## Native framebuffer regression: assert the actual rendered grid moves with
## world coordinates, not only the camera's numerical transform.
var checks: int=0
var failures: int=0
var board: DeploymentBoard
var battle: BattleManager
const OUT="res://migration/camera-grid/"
func _initialize():call_deferred("run")
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("CAMERA GRID: "+label)
func frames():
	for i in range(4):await process_frame
func state() -> String:
	return var_to_str([battle.clock.elapsed,battle.rng.state,battle.units.map(func(u):return [u.position,u.current_hp,u.combat_state])])
func luminance(im: Image,p: Vector2) -> float:
	var c: Color=im.get_pixelv(Vector2i(p.round()));return (c.r+c.g+c.b)*85
func stripe_contrast(im: Image,p: Vector2) -> float:
	var peak: float=0
	for dx in [-1,0,1]:peak=maxf(peak,luminance(im,p+Vector2(dx,0)))
	return peak-maxf(luminance(im,p+Vector2(-5,0)),luminance(im,p+Vector2(5,0)))
func capture(name: String) -> Image:
	board.presentation.queue_redraw();await frames();await RenderingServer.frame_post_draw
	var im: Image=root.get_texture().get_image();im.save_png(OUT+name+".png");return im
func run():
	if DisplayServer.get_name()=="headless":push_error("Framebuffer test requires a display");quit(1);return
	root.size=Vector2i(1000,1100);root.content_scale_size=root.size
	board=DeploymentBoard.new();root.add_child(board);board.position=Vector2(100,150);board.size=Vector2(800,800);board.editing=false
	battle=BattleManager.new();battle.auto_start=false;board.add_child(battle)
	verify(battle.start_battle([{"data":BattleManager.WARRIOR,"team":0,"position":Vector2(500,500)},{"data":BattleManager.WARRIOR,"team":1,"position":Vector2(700,700)}],1904),"real common/full battle starts")
	battle.set_physics_process(false);board.battle=battle;board.presentation.attach(battle);board.presentation.set_process(false)
	await frames();var saved: String=state();var c: ArenaCameraController=board.presentation.camera;var world:=Vector2(320,267)
	for pose in [{"zoom":1.0,"pan":Vector2.ZERO,"shake":Vector2.ZERO},{"zoom":1.6,"pan":Vector2(53,-37),"shake":Vector2(4,-3)},{"zoom":2.2,"pan":Vector2(-71,42),"shake":Vector2(2,1)}]:
		c.zoom=pose.zoom;c.pan=pose.pan;c.offset=pose.shake
		var im: Image=await capture("zoom-%s"%pose.zoom)
		var pixel: Vector2=board.position+c.transform()*world
		var contrast: float=stripe_contrast(im,pixel);print("GRID PIXEL zoom=",pose.zoom," contrast=",contrast," at=",pixel)
		verify(contrast>3,"actual grid stripe follows zoom/pan/shake %s"%pose.zoom)
		verify(board.logical_point(c.transform()*world).distance_to(world)<.001,"input inverse shares world grid coordinates")
		verify(state()==saved,"drawing cannot mutate simulation or RNG")
	c.overview_age=-1
	for dt in [.5,.5,1.0]:
		c.advance_overview(dt)
		var im: Image=await capture("overview-%s"%c.overview_age)
		verify(stripe_contrast(im,board.position+c.transform()*world)>3,"grid remains attached during TP/ending overview")
	verify(c.zoom==1 and c.pan==Vector2.ZERO,"overview reaches full map")
	c.zoom=1.6;c.pan=Vector2(53,-37);c.offset=Vector2(4,-3)
	var e:=InputEventScreenTouch.new();e.pressed=true;e.position=c.transform()*battle.units[0].position;board._gui_input(e)
	verify(board.selected_actor_id==battle.units[0].actor_id(),"real touch selects the visible actor under pan/zoom/shake")
	c.zoom=.8;c.pan=Vector2(650,0);c.offset=Vector2.ZERO
	var outside: Image=await capture("edge-underlay")
	verify(outside.get_pixelv(Vector2i(board.position+Vector2(3,3))).is_equal_approx(Color("122219")),"viewport beyond world edges has a solid backdrop")
	verify(state()==saved,"all camera poses preserve HP/positions/attack/RNG/time")
	root.size=Vector2i(390,844);root.content_scale_size=root.size;board.position=Vector2(8,190);board.size=Vector2(374,374)
	c.zoom=1.7;c.pan=Vector2(15,-20);c.offset=Vector2(2,0);await capture("mobile-zoom")
	var rect: Rect2=board.board_rect();var touch: Vector2=rect.position+c.transform()*battle.units[0].position*rect.size.x/800
	verify(board.logical_point(touch).distance_to(battle.units[0].position)<.001,"mobile CSS-scale camera inverse remains correct")
	c.advance_overview(2);await capture("mobile-overview")
	board.free();await frames();print("CAMERA GRID RESULT: ",checks," checks; ",failures," failures");quit(1 if failures else 0)
