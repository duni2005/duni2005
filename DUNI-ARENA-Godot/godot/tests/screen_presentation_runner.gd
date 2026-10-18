extends SceneTree
var checks:=0
var failures:=0
const OUT="res://migration/screen-presentation/"
func _initialize():call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("SCREEN FX: "+label)
func frames() -> void:
	for i in range(6):await process_frame
func snapshot(run: RunState) -> String:return JSON.stringify(SaveDomainCodec.new().encode(run,"run"))
func run() -> void:
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"camera-reference.json"))
	for item in cases:
		var rows: Array=[]
		for row in item.actors:rows.append({"position":Vector2(row.x,row.y),"velocity":Vector2(row.vx,row.vy),"scale":row.scale})
		var cam:=ArenaCameraController.new();cam.set_framing(rows)
		verify(ArenaCameraController.framing_for(rows).center.distance_to(Vector2(item.framing.x,item.framing.y))<.001,"source framing center")
		verify(absf(ArenaCameraController.framing_for(rows).zoom-item.framing.zoom)<.0001,"source framing zoom")
		verify(absf(cam.framing.zoom-minf(2.5,item.framing.zoom*1.12))<.0001,"requested closer presentation target")
		for i in range(int(item.fps)):cam.advance(1.0/item.fps)
		verify(cam.center.distance_to(Vector2(item.closer.center.x,item.closer.center.y))<.01,"source pan cadence %s"%item.fps)
		verify(absf(cam.zoom-item.closer.zoom)<.001,"closer zoom with source cadence and body fit")
		var point:=Vector2(245,583);verify((cam.transform().affine_inverse()*(cam.transform()*point)).distance_to(point)<.001,"inverse touch coordinates")
		cam.advance(.1,true);verify(cam.zoom==1 and cam.pan==Vector2.ZERO,"TP/aim overview")
		cam.finish(Vector2(550,350));cam.advance(.1);verify(cam.zoom>1,"finale focus")
		cam.reset();verify(cam.framing.is_empty() and cam.zoom==1,"camera cleanup")
	for kind in ItemCatalog.KINDS:verify(ArenaIcon.texture(String(kind))!=null,"item symbol "+String(kind))
	for kind in ["gold","gem","heart","mango","evade","shield","iron","charge","crown","recruit","shop","rest","boss"]:verify(ArenaIcon.texture(kind)!=null,"colored symbol "+kind)
	root.size=Vector2i(390,844);root.content_scale_size=root.size
	var ui:=TowerScreen.new();root.add_child(ui);ui.controller.new_run(19,73);ui.show_map();await frames();ui.fx.set_process(false)
	var fx: TowerSceneDirector=ui.fx;var run_state: RunState=ui.controller.guild.state
	ui.select_room("0:0");await frames();verify(fx.active.get("kind","")=="entry","actual first-discovery entry")
	verify(fx.flights.size()>0,"actual discovery gold flight")
	var old: String=snapshot(run_state);fx.advance(2.2);verify(snapshot(run_state)==old,"entry does not grant reward again")
	var offer: RecruitOffer=ui.controller.current_room().recruit.offers[0];var count: int=run_state.guild_members.size()
	ui.content_screen._action(&"recruit",{"offer_id":offer.offer_id});await frames();fx.advance(.7)
	verify(run_state.guild_members.size()==count+1 and fx.active.get("kind","")=="recruit","real recruit transaction creates reveal")
	verify(fx.surface.mouse_filter==Control.MOUSE_FILTER_STOP,"recruit tap cannot purchase underlying card")
	old=snapshot(run_state);var e:=InputEventScreenTouch.new();e.position=Vector2(195,420);e.pressed=true;Input.parse_input_event(e);await frames()
	verify(fx.active.is_empty(),"touch skips recruit sequence")
	verify(snapshot(run_state)==old,"skip has no transaction side effect")
	verify(not fx.enqueue({"kind":"recruit","key":"recruit:"+run_state.guild_members.keys().back()+":0","room_id":"0:0","title":"duplicate"}),"recruit receipt not replayed")
	fx.clear();ui._update_fx_context();fx.set_process(false)
	for i in range(20):fx.enqueue({"kind":"conquest","key":"test:%d"%i,"title":"test"})
	verify(fx.queue.size()<=TowerSceneDirector.LIMIT,"bounded scene queue")
	fx.clear();ui._update_fx_context();old=snapshot(run_state)
	fx.enqueue({"kind":"recruit","room_id":"0:0","key":"timer","title":"전사"});fx.advance(2.49);verify(not fx.active.is_empty(),"source recruit duration before boundary");fx.advance(.01);verify(fx.active.is_empty(),"source recruit duration 2.5")
	verify(snapshot(run_state)==old,"real-time queue does not alter run/save/RNG")
	fx.enqueue({"kind":"promotion","title":"승급"});verify(not fx.skip_recruit(),"promotion is not recruit skip")
	fx.advance(3);verify(fx.active.is_empty(),"source promotion duration")
	fx.enqueue({"kind":"entry","room_id":"0:0","title":"entry"});fx.context(run_state.run_id,"0:0","battle");verify(fx.active.is_empty(),"entry removed on battle start")
	fx.context(run_state.run_id,"0:0","recruit");fx.enqueue({"kind":"recruit","room_id":"0:0","title":"stale"});fx.context(run_state.run_id,"0:1","shop");verify(fx.active.is_empty(),"stale room recruit canceled")
	fx.enqueue({"kind":"conquest","title":"clear"});fx.context(run_state.run_id,"0:1","gameover");verify(fx.active.is_empty() and fx.queue.is_empty(),"gameover cleanup")
	fx.fly("gold",99,Vector2.ZERO,Vector2(100,100));fx.fly("gem",99,Vector2.ZERO,Vector2(100,100));fx.advance(2);verify(fx.flights.is_empty(),"currency flight lifetime")
	verify(not "TowerScene" in snapshot(run_state),"no presentation object in save")
	ui.free();await frames()
	print("SCREEN PRESENTATION RESULT: ",checks," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
