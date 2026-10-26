class_name Phase12Tests
extends RefCounted
var checks: int=0
var failures: int=0
var tree: SceneTree
var snapshots: Array[String]=[]
var peak_effects: int=0
var peak_numbers: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE12: "+label)
func frames() -> void:
	for i in range(3):await tree.process_frame
func click(control: Control) -> void:
	var parent: Node=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await frames()
	var logical: Vector2=control.get_global_rect().get_center()
	var viewport: Viewport=control.get_viewport()
	if viewport is Window and viewport!=tree.root:logical+=Vector2(viewport.position)
	var point: Vector2=tree.root.get_final_transform()*logical
	if tree.root.size.x==390:
		var down:=InputEventScreenTouch.new();down.position=point;down.pressed=true;Input.parse_input_event(down);await tree.process_frame
		var up:=InputEventScreenTouch.new();up.position=point;Input.parse_input_event(up);await frames()
	else:
		var down:=InputEventMouseButton.new();down.position=point;down.global_position=point;down.pressed=true;down.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(down);await tree.process_frame
		var up:=InputEventMouseButton.new();up.position=point;up.global_position=point;up.button_index=MOUSE_BUTTON_LEFT;Input.parse_input_event(up);await frames()

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	var path: String="res://migration/phase12-"+label+".png"
	tree.root.get_texture().get_image().save_png(path);snapshots.append(path)
## Entering the tower dives the title camera in first (about 1.5 s with UI motion on).
func tower_opened(menu: MainMenuScreen) -> void:
	for i in range(240):
		if menu.tower_screen!=null:break
		await tree.process_frame
	await frames()
func inside(c: Control) -> bool:
	return c.get_global_rect().position.x>=-1 and c.get_global_rect().end.x<=tree.root.content_scale_size.x+1 and c.get_global_rect().end.y<=tree.root.content_scale_size.y+1
func run(owner: SceneTree) -> void:
	tree=owner
	for window_size in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1000,1100),Vector2i(390,844)]:
		tree.root.size=window_size;tree.root.content_scale_size=window_size
		print("PHASE12 UI begin ",window_size)
		var mobile: bool=window_size.x==390
		var menu:=MainMenuScreen.new();menu.save_manager=SaveManager.new("user://phase12-tests/menu-"+DisplayServer.get_name()+".json");tree.root.add_child(menu);await frames()
		verify([menu.tower_button,menu.custom_button,menu.settings_button].all(func(b):return inside(b) and b.size.y>=44),"three menu buttons fit with touch height %s"%window_size)
		verify(not menu.continue_button.is_visible_in_tree() and not menu.find_children("*","Label",true,false).any(func(l):return "길드원" in l.text),"title shows the wordmark and three buttons only")
		verify(menu.theme==ArenaUI.get_theme(),"shared theme")
		if mobile or window_size==Vector2i(1280,720):await capture(("mobile" if mobile else "desktop")+"-menu")
		menu.free();await frames()
		var screen:=TowerScreen.new();tree.root.add_child(screen);screen.controller.new_run(19,73);screen.show_map();await frames()
		var controller: TowerController=screen.controller
		verify(screen.room_buttons.size()==120,"all room buttons")
		verify(inside(screen.wallet) and inside(screen.map_scroll),"map fits")
		verify(not "hotSpring" in str(screen.room_buttons.values().map(func(b):return b.text)),"no hidden event type leak")
		verify(screen.room_buttons["14:4"].disabled,"locked floor disabled")
		verify(controller.guild.state.tower.map.rooms.values().any(func(r):return r.room_type==RoomType.BOSS and r.publicly_visible),"boss marker public")
		if mobile or window_size==Vector2i(1280,720):await capture(("mobile" if mobile else "desktop")+"-map")
		await click(screen.room_buttons["0:3"])
		var room: TowerBattleScreen=screen.battle_screen
		verify(room!=null and room.board.editing,"real room/deployment routing")
		verify(not room.debug_enabled and not room.ai_debug_panel.visible,"debug default hidden")
		var members: Array[GuildMemberState]=controller.guild.all_members();var original: float=members[0].current_hp
		room.board.select(members[0].member_id);room._placement_changed(room.plan.place(members[0].member_id,Vector2(390,400)))
		verify("영역" in room.status.text,"invalid placement reason")
		verify(members[0].current_hp==original,"presentation placement read-only")
		verify(room.plan.place(members[0].member_id,Vector2(180,400))==DeploymentRules.Code.OK,"free placement")
		room._refresh_roster();await frames()
		verify(inside(room.start_button) and inside(room.board),"deployment controls fit")
		if mobile or window_size==Vector2i(1280,720):await capture(("mobile" if mobile else "desktop")+"-deployment")
		await click(room.start_button);var battle: BattleManager=room.battle;battle.set_physics_process(false);await frames()
		verify(battle.full_characters_enabled and battle.common_combat_enabled,"actual full common mode")
		verify(room.board.presentation.battle==battle and not battle.visible,"read-only presentation renderer")
		verify(inside(room.retreat_button),"battle retreat reachable")
		var unit: BattleUnit=battle.units[0];unit.shield_hp=100;unit.shield_remaining=8;unit.stun_remaining=.6;unit.invincible_remaining=.5
		room.board.selected_actor_id=unit.actor_id();room.ai_debug_actor=unit.actor_id();await frames()
		verify(not room.selected_details.visible and "궁극기" in room.selected_details.text,"selection detail stays hidden outside debug")
		room.toggle_debug();await frames();verify(room.ai_debug_panel.visible,"explicit debug toggle preserved")
		room.toggle_debug();await frames();verify(not room.ai_debug_panel.visible,"return to normal HUD")
		if mobile or window_size==Vector2i(1280,720):await capture(("mobile" if mobile else "desktop")+"-battle")
		battle.clock.elapsed=12;battle.turning.advance(.01);await frames();verify(battle.clock.state==BattleClock.State.TURNING_SLOWDOWN,"TP entry feedback")
		battle.turning.advance(2);await frames();verify(battle.turning.is_paused(),"TP hold")
		verify(not room.turning_panel.plans.get_parent().visible,"web UX hides enemy internal forecast")
		verify(inside(room.turning_panel.resume_button) and room.turning_panel.resume_button.size.y>=44,"TP mobile resume")
		verify(inside(room.turning_panel.choices[CombatStance.COVER]),"stance buttons reachable")
		await click(room.turning_panel.allies.get_child(0));await click(room.turning_panel.choices[CombatStance.COVER])
		verify(unit.stance==CombatStance.COVER,"actual stance selection")
		verify(room.turning_panel.card_buttons.size()==controller.guild.state.strategy_cards.size(),"card listing")
		if mobile or window_size==Vector2i(1280,720):await capture(("mobile" if mobile else "desktop")+"-tp")
		var before: float=battle.clock.elapsed;var rng: int=battle.rng.state;room.board.presentation.advance(1)
		verify(before==battle.clock.elapsed and rng==battle.rng.state and unit.stun_remaining==.6,"VFX never advances simulation or RNG")
		await click(room.turning_panel.resume_button);verify(not battle.turning.is_paused(),"manual resume")
		unit.stun_remaining=0;unit.invincible_remaining=0;unit.transcendence_gauge=100;unit.ultimate.cast.clear();unit.combat.cancel(unit)
		verify(battle.transcendence.begin(unit,Vector2(190,230)),"transcendence aim")
		battle.transcendence.update(Vector2(190,300));verify(battle.transcendence.release(),"downward transcendence cast")
		await frames();verify(room.trans_cutin.visible,"cast emphasis")
		if mobile or window_size==Vector2i(1280,720):await capture(("mobile" if mobile else "desktop")+"-transcendence")
		battle.simulate(1.16);verify(battle.clock.state==BattleClock.State.NORMAL,"cast 1.15 second contract")
		battle.clock.elapsed=20;verify(controller.session.request_retreat(),"retreat actual settlement")
		await frames();verify("후퇴" in room.result_label.text and "유지" in room.result_label.text,"retreat result distinct")
		var energy: int=members[0].energy;room._room_finished(battle.result,BattleSettlement.Status.APPLIED)
		verify(members[0].energy==energy,"result animation does not settle twice")
		room.board.presentation.advance(BattleCinematicState.DURATION);verify(room.board.presentation.effects.is_empty() and room.board.presentation.numbers.is_empty() and room.board.presentation.camera.offset==Vector2.ZERO,"end cleanup/camera reset")
		if mobile or window_size==Vector2i(1280,720):await capture(("mobile" if mobile else "desktop")+"-result")
		screen.free();await frames()
	print("PHASE12 UI content/save")
	await content_and_save()
	print("PHASE12 UI paired/stress")
	# No save: 타워 입장 starts a run at once (the camera dive is skipped without UI motion).
	var fresh:=MainMenuScreen.new();fresh.save_manager=SaveManager.new("user://phase12-tests/fresh-"+Crypto.new().generate_random_bytes(6).hex_encode()+".json");tree.root.add_child(fresh);await frames()
	fresh.enter_tower();await tower_opened(fresh)
	verify(fresh.tower_screen!=null and not fresh.tower_dialog.visible,"no save: 타워 입장 starts at once")
	fresh.free();await frames()
	await stress()
	print("PHASE12 RESULT: ",checks," checks; ",failures," failures; effects<=",peak_effects," numbers<=",peak_numbers," display=",DisplayServer.get_name())
func content_and_save() -> void:
	tree.root.size=Vector2i(390,844);tree.root.content_scale_size=tree.root.size
	var c:=Phase11Fixture.make();var save:=SaveManager.new("user://phase12-tests/complex-"+DisplayServer.get_name()+".json");save.attach(c)
	var original_rng: int=c.content_rng.state
	verify(save.manual_save(c).ok(),"autosave compatible")
	var menu:=MainMenuScreen.new();menu.save_manager=save;tree.root.add_child(menu);await frames()
	verify("마지막 저장" in menu.status.text and "챕터" in menu.status.text,"Continue metadata timestamp")
	verify(c.content_rng.state==original_rng,"metadata no content RNG")
	await click(menu.tower_button);await frames();verify(menu.tower_dialog.visible and menu.tower_screen==null,"a save makes 타워 입장 ask continue or start over")
	await click(menu.continue_button);await tower_opened(menu);verify(menu.tower_screen!=null and menu.tower_screen.content_screen!=null,"Continue routes incomplete event")
	verify("온천" in menu.tower_screen.content_screen.heading.text,"event content display")
	await capture("mobile-event");menu.return_menu();await frames()
	# Corrupt primary with backup intact: UI warning only, never replay a result.
	verify(save.manual_save(c).ok(),"normal backup generation")
	var f:=FileAccess.open(save.path,FileAccess.WRITE);f.store_string("broken");f.close()
	menu.refresh();await frames();verify(not menu.continue_button.disabled and "백업" in menu.status.text,"backup recovery preview")
	await click(menu.tower_button);await frames();await click(menu.continue_button);await tower_opened(menu);verify("복구" in menu.tower_screen.notice.text,"backup recovery notice")
	menu.free();c.release_runtime_connections();await frames()
	var tower:=TowerScreen.new();tree.root.add_child(tower);tower.controller.new_run(19,73);tower.show_map();await frames()
	var dead: GuildMemberState=tower.controller.guild.all_members().back();dead.current_hp=0
	tower.open_guild();await frames();verify("사망" in tower.guild_panel.roster.get_children().back().text,"dead roster retained")
	await click(tower.guild_panel.tabs["upgrade"]);await frames()
	verify("다음 강화" in tower.guild_panel.details.text,"upgrade preview")
	verify(inside(tower.guild_panel.upgrade_button),"guild mobile actions")
	await capture("mobile-guild");tower.guild_dialog.hide()
	for room in tower.controller.guild.state.tower.map.rooms.values():
		if room.floor_index==0 and room.room_type in [RoomType.RECRUIT,RoomType.SHOP]:
			tower.select_room(room.room_id);await frames()
			var content: TowerContentScreen=tower.content_screen
			verify(content!=null and inside(content.scroll),"content mobile scroll "+String(room.room_type))
			await capture("mobile-"+String(room.room_type))
			if room.room_type==RoomType.RECRUIT:verify(room.recruit.offers.size()==3,"three persistent recruit candidates")
			else:
				verify(content.offers_grid.get_child_count()==room.shop.offers.filter(func(o):return o.category==&"equipment").size(),"equipment stock tab presentation")
				var card_tab: Button=content.content_tabs.get_child(1);await click(card_tab);await frames()
				verify(content.offers_grid.get_child_count()==room.shop.offers.filter(func(o):return o.category==&"card").size(),"strategy card stock tab presentation")
			content._return_map();await frames()
	var guard:=Button.new();tower.add_child(guard);var result: Array=[0];ArenaUI.bind(guard,func():result[0]+=1)
	guard.pressed.emit();guard.pressed.emit();verify(result[0]==1,"duplicate frame click guarded")
	await frames();guard.set_meta("drag_canceled",true);guard.pressed.emit();verify(result[0]==1,"scroll drag cancels tap")
	tower.free();await frames()
func placements() -> Array[Dictionary]:
	var out: Array[Dictionary]=[]
	var types: Array=[0,1,2,4,5,13,16,20,21,22,23,25]
	for team in range(2):
		for i in range(12):out.append({"data":CharacterCatalog.all()[types[i]],"team":team,"position":Vector2(130+team*450+(i%3)*60,100+(i/3)*150)})
	return out
func stress() -> void:
	var orphan_before: int=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var peak_projectiles: int=0;var peak_zones: int=0
	var board:=DeploymentBoard.new();board.size=Vector2(800,800);board.editing=false;tree.root.add_child(board)
	var live:=BattleManager.new();live.auto_start=false;board.add_child(live);verify(live.start_battle(placements(),731),"mixed 12vs12")
	var reference:=BattleManager.new();reference.auto_start=false;tree.root.add_child(reference);verify(reference.start_battle(placements(),731),"reference same battle")
	live.set_physics_process(false);reference.set_physics_process(false);board.battle=live;await frames()
	for b in [live,reference]:
		for u in b.units:u.ultimate_gauge=100
	var visual: CombatPresentation=board.presentation
	for kind in ["hit","critical","heal","shield_hit","shield_break","parry_success","clash","stun","invincible","knockback","projectile_hit","explosion","blackhole","lightning","reflect","swallow","control","ultimate","transcendence","death"]:
		visual.add_effect(kind,Vector2(400,400));verify(visual.generated.get(kind)==1,"VFX cue "+kind)
	var start: int=Time.get_ticks_usec()
	for i in range(900):
		live.simulate(1.0/60);reference.simulate(1.0/60);visual.advance(1.0/60)
		verify(live.rng.state==reference.rng.state and live.clock.elapsed==reference.clock.elapsed,"presentation preserves RNG/clock")
		for j in range(live.units.size()):
			var a: BattleUnit=live.units[j];var b: BattleUnit=reference.units[j]
			verify(a.position==b.position and a.current_hp==b.current_hp and a.combat_state==b.combat_state and a.position.is_finite(),"presentation preserves 12vs12 actor")
		peak_projectiles=maxi(peak_projectiles,live.projectiles.size());peak_zones=maxi(peak_zones,live.zones.entries.size())
		peak_effects=maxi(peak_effects,visual.effects.size());peak_numbers=maxi(peak_numbers,visual.numbers.size())
		if i%120==0:await tree.process_frame
	verify(peak_effects<=CombatPresentation.MAX_EFFECTS and peak_numbers<=CombatPresentation.MAX_NUMBERS,"bounded VFX buffers")
	print("PHASE12 STRESS: 900 paired ticks / 24 actors / ",(Time.get_ticks_usec()-start)/1000.0,"ms; peak projectiles ",peak_projectiles," zones ",peak_zones,"; event counts ",live.combat_event_counts)
	visual.camera.impact(6,Vector2(300,400));visual.camera.advance(.01);verify(visual.camera.offset.length()>0,"camera shake presentation")
	visual.cleanup();verify(visual.effects.is_empty() and visual.numbers.is_empty() and visual.camera.strength==0,"explicit cleanup")
	board.free();reference.free();await frames()
	verify(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))<=orphan_before,"no orphan Node leak after 12vs12")
