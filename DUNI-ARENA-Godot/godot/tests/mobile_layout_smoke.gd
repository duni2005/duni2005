extends SceneTree
## Layout regression: real room/TP/retreat + presentation-only outcome variants.
var checks: int=0
var failures: int=0
var bounds: Array=[]
func _initialize() -> void:call_deferred("run")
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("MOBILE LAYOUT: "+label)
func frames() -> void:
	for i in range(5):await process_frame
func fits(c: Control) -> bool:
	var r: Rect2=c.get_global_rect()
	return r.position.x>=-1 and r.position.y>=-1 and r.end.x<=root.content_scale_size.x+1 and r.end.y<=root.content_scale_size.y+1
func touch(c: Control) -> void:
	var at: Vector2=root.get_final_transform()*c.get_global_rect().get_center()
	var down:=InputEventScreenTouch.new();down.position=at;down.pressed=true;Input.parse_input_event(down);await process_frame
	var up:=InputEventScreenTouch.new();up.position=at;Input.parse_input_event(up);await frames()
func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://migration/mobile-ui-fix/"+name+".png")
func rect(c: Control) -> Dictionary:
	var r: Rect2=c.get_global_rect();return {"x":r.position.x,"y":r.position.y,"w":r.size.x,"h":r.size.y}
func run() -> void:
	for resolution in [Vector2i(1280,720),Vector2i(390,844),Vector2i(390,700),Vector2i(360,640)]:
		root.size=resolution;root.content_scale_size=resolution
		var screen:=TowerScreen.new();root.add_child(screen);screen.controller.new_run(19,73);screen.show_map();await frames()
		screen.select_room("0:3");await frames()
		var room: TowerBattleScreen=screen.battle_screen
		var members: Array[GuildMemberState]=screen.controller.guild.all_members()
		for i in range(members.size()):room.plan.place(members[i].member_id,Vector2(140+100*(i%2),260+220*(i/2)))
		room._refresh_roster();await frames()
		verify(fits(room.start_button) and fits(room.board),"deployment fits "+str(resolution))
		bounds.append({"size":[resolution.x,resolution.y],"state":"deploy","board":rect(room.board),"roster":rect(room.roster),"start":rect(room.start_button)})
		await shot("native-%dx%d-deploy"%[resolution.x,resolution.y])
		await touch(room.start_button);room.battle.set_physics_process(false);await frames()
		verify(room.battle.started,"start touch")
		verify(not room.desktop_dock and room.board.get_parent()==room.arena_home,"normal arena never uses top-right dock")
		verify(room.room_hud.get_global_rect().end.y<=room.board.get_global_rect().position.y,"HUD above arena")
		verify(room.retreat_button.get_global_rect().position.y>=room.board.get_global_rect().end.y,"retreat below arena")
		verify(fits(room.retreat_button) and room.retreat_button.size.y>=44,"retreat reachable")
		await shot("native-%dx%d-battle"%[resolution.x,resolution.y])
		room.battle.clock.elapsed=12;room.battle.turning.advance(.01);room.battle.turning.advance(2);await frames()
		verify(room.battle.turning.is_paused(),"real TP hold")
		verify(fits(room.turning_panel.resume_button) and fits(room.turning_panel.use_button),"TP key actions reachable")
		verify(fits(room.turning_panel.choices[CombatStance.COVER]),"all stances reachable")
		verify(fits(room.room_hud),"TP persistent status reachable")
		await shot("native-%dx%d-tp"%[resolution.x,resolution.y])
		await touch(room.turning_panel.resume_button);verify(not room.battle.turning.is_paused(),"resume touch")
		room.battle.clock.elapsed=20;verify(room.session.request_retreat(),"actual retreat settlement")
		await frames()
		# Isolate static result-page geometry from the separately tested end storyboard.
		room.retreat_routed=true
		room.board.presentation.advance(BattleCinematicState.DURATION);await frames()
		room.retreat_presenting=false;room.retreat_scene.hide()
		var energy: int=members[0].energy
		for reason in [BattleEndReason.Value.VICTORY,BattleEndReason.Value.DEFEAT,BattleEndReason.Value.RETREAT]:
			# Show existing result data; do not call a settlement/reward to animate it.
			var view:=BattleResult.new();view.result_id=room.battle.result.result_id;view.end_reason=reason;view.elapsed=20
			room._room_finished(view,BattleSettlement.Status.APPLIED)
			room.retreat_presenting=false;room.retreat_scene.hide();await frames()
			verify(room.result_overlay.visible and fits(room.result_panel),"result fits "+str(reason))
			verify(fits(room.next_button) and room.next_button.size.y>=44,"result CTA reachable "+str(reason))
			verify(absf(room.result_panel.get_global_rect().get_center().x-resolution.x*.5)<2,"result centered")
			verify(members[0].energy==energy,"result rendering never settles again")
			await shot("native-%dx%d-result-%d"%[resolution.x,resolution.y,reason])
		await touch(room.next_button);verify(screen.battle_screen==null,"return-map touch")
		screen.free();await frames()
	var f:=FileAccess.open("res://migration/mobile-ui-fix/native-bounds.json",FileAccess.WRITE);f.store_string(JSON.stringify(bounds,"  "));f.close()
	print("MOBILE LAYOUT RESULT: ",checks," checks; ",failures," failures; display=",DisplayServer.get_name());quit(1 if failures else 0)
