extends SceneTree
var checks: int=0
var failures: int=0
var ui: TowerScreen
func _initialize():call_deferred("run")
func verify(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error("IMPACT UI: "+label)
func frames():
	for i in range(5):await process_frame
func click(control: Control):
	var p: Node=control.get_parent()
	while p!=null:
		if p is ScrollContainer:p.ensure_control_visible(control)
		p=p.get_parent()
	await frames()
	var point: Vector2=root.get_final_transform()*ArenaUI.control_center(control)
	var e:=InputEventScreenTouch.new();e.position=point;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventScreenTouch.new();e.position=point;Input.parse_input_event(e);await frames()
func pure() -> String:return JSON.stringify(SaveDomainCodec.new().encode(ui.controller.guild.state,"run"))
func run():
	root.gui_embed_subwindows=true;root.size=Vector2i(390,844);root.content_scale_size=root.size
	var focus: StyleBoxFlat=ArenaUI.get_theme().get_stylebox("focus","Button")
	verify(not focus.draw_center and focus.bg_color.a==0,"native focus is an outline, never an opaque cover")
	ui=TowerScreen.new();root.add_child(ui);ui.controller.new_run(19,73);ui.show_map();await frames();ui.fx.set_process(false)
	var run_state: RunState=ui.controller.guild.state;var initial: int=run_state.gold
	ui.select_room("0:0");var w: WalletBar=ui.content_screen.wallet;w.set_process(false);await frames()
	verify(run_state.gold==initial+50,"discovery domain reward still once")
	verify(not ui.fx.flights.is_empty() and ui.fx.flights[0].direction=="gain","discovery flies toward wallet")
	verify(ui.fx.flights[0].destination.distance_to(w.anchor("gold"))<1,"wallet icon destination follows layout")
	verify(w.shown_gold==initial,"positive display waits for arrival")
	var saved: String=pure();w.advance_view(.71);ui.fx.advance(.71)
	verify(w.shown_gold==initial and ui.fx.sparks.is_empty(),"no early gain or impact")
	w.advance_view(.11);ui.fx.advance(.11)
	verify(w.shown_gold>initial and w.shown_gold<run_state.gold,"gain counts up after first coin arrival")
	verify(not ui.fx.sparks.is_empty(),"arrival creates currency sparks")
	w.advance_view(1);ui.fx.advance(2)
	verify(int(w.shown_gold)==run_state.gold and ui.fx.flights.is_empty() and ui.fx.sparks.is_empty(),"currency count finishes and effects clean up")
	verify(pure()==saved,"currency animations never apply rewards/save/RNG again")
	var offer: RecruitOffer=ui.controller.current_room().recruit.offers[0];var old_tokens: int=run_state.tokens
	await click(ui.content_screen.content_box.get_child(0).get_child(0).get_child(0))
	verify(run_state.tokens==old_tokens-offer.token_price,"real recruit debit")
	var spending: Array=ui.fx.flights.filter(func(f):return f.direction=="spend" and f.kind=="gem")
	verify(not spending.is_empty() and spending[0].origin.distance_to(w.anchor("gem"))<12,"spend starts at wallet")
	verify(spending[0].destination.distance_to(root.get_meta("action_point"))<1,"spend ends at actual purchase card")
	saved=pure();var n: int=ui.fx.flights.size();ui.content_screen._action(&"recruit",{"offer_id":offer.offer_id})
	verify(pure()==saved and ui.fx.flights.size()==n,"rejected duplicate creates no effect or transaction")
	ui.fx.advance(4);w.advance_view(4);ui.content_screen._return_map();await frames()
	var room: RoomState=run_state.tower.map.get_room("0:4");room.event_type=&"prediction";room.event=null
	ui.select_room("0:4");await frames();ui.fx.advance(3)
	await click(ui.content_screen.content_box.get_node("team_1"))
	var team: ArenaCard=ui.content_screen.content_box.get_node("team_1")
	verify(team.selected and team.button_pressed and team.card_type=="prediction_team","prediction team has real persistent selected styling")
	verify(team.portrait_types.size()>0 and not ui.content_screen.content_box.get_node("team_0").selected,"prediction portraits and exclusive selection")
	await click(ui.content_screen.content_box.find_child("stake_200",true,false))
	var stake: ArenaCard=ui.content_screen.content_box.find_child("stake_200",true,false)
	verify(stake.selected and stake.button_pressed and stake.size.x>=44,"selected gold stake is readable/touch sized")
	verify(not ui.content_screen.content_box.find_child("stake_50",true,false).selected,"old gold selection removed")
	await click(ui.content_screen.content_box.get_node("Watch"))
	var b: BattleManager=ui.content_screen.battle;b.set_physics_process(false)
	verify(b.started and ui.fx.flights.any(func(f):return f.direction=="spend" and f.kind=="gold"),"prediction bet registers spend flight")
	var cue: BattleCueOverlay=ui.content_screen.battle_cue;cue.observe(b,.1)
	verify(cue.cue=="start" and cue.mouse_filter==Control.MOUSE_FILTER_IGNORE and cue.z_index<20,"battle start cue never blocks input")
	for u in b.units:
		if u.original_team==0:u.receive_damage(10000,b.units[-1])
	b.check_outcome();var settled: BattleResult=b.result;await frames()
	verify(settled.completed and run_state.tower.phase!=&"battle","prediction settlement still completes")
	var snapshot: String=pure();ui.fx.advance(5);await frames()
	verify(pure()==snapshot,"finished cue does not settle prediction twice")
	# A paid event can spend gold and grant gold in the same atomic transaction.
	var fx:=TowerSceneDirector.new();root.add_child(fx);fx.set_process(false)
	var guild:=GuildManager.new();guild.state.gold=1000;var wallet:=WalletBar.new();wallet.guild=guild;root.add_child(wallet);wallet.set_process(false);wallet.size=Vector2(374,70)
	fx.rebase_wallet(1000,guild.state.tokens);guild.state.gold=1050
	fx.sync_wallet(wallet,Vector2(190,400),{"gold":250})
	verify(fx.flights.any(func(f):return f.direction=="spend") and fx.flights.any(func(f):return f.direction=="gain"),"combined event shows both debit and reward flights")
	wallet.advance_view(.32);verify(int(wallet.shown_gold)==800,"combined event visibly spends its full cost first")
	wallet.advance_view(.39);verify(int(wallet.shown_gold)==800,"combined reward waits for arrival")
	wallet.advance_view(.2);verify(wallet.shown_gold>800 and wallet.shown_gold<1050,"combined reward then counts upward")
	wallet.advance_view(1);verify(int(wallet.shown_gold)==1050 and guild.state.gold==1050,"combined display settles to authoritative domain amount")
	var batches: int=fx.flights.size();fx.sync_wallet(wallet,Vector2(190,400),{"gold":250});verify(fx.flights.size()==batches,"replayed feedback cannot duplicate unchanged resources")
	fx.advance(3);verify(fx.flights.is_empty() and fx.sparks.is_empty() and fx.deltas.is_empty(),"all resource effects bounded/expired")
	wallet.free();fx.free()
	var cam:=ArenaCameraController.new();var actors: Array=[{"position":Vector2(350,400),"velocity":Vector2.ZERO,"scale":1.0},{"position":Vector2(450,400),"velocity":Vector2.ZERO,"scale":1.0}]
	var base: Dictionary=ArenaCameraController.framing_for(actors);cam.set_framing(actors)
	verify(cam.framing.zoom>base.zoom and cam.framing.zoom<=2.5,"slightly closer spectator target")
	for i in range(240):cam.advance(1.0/60)
	for row in actors:
		var top: Vector2=cam.transform()*(row.position-Vector2(32,52));var bottom: Vector2=cam.transform()*(row.position+Vector2(32,36))
		verify(top.x>=0 and top.y>=0 and bottom.x<=800 and bottom.y<=800,"closer camera keeps unit and HP bounds")
	ui.free();await frames()
	print("IMPACT UI RESULT: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)
