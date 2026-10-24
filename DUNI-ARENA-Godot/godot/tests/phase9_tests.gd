class_name Phase9Tests
extends RefCounted
var host: SceneTree
var checks: int=0
var failures: int=0
var groups: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PHASE9 FAIL: "+label)
func make_tower(seed_value: int=19) -> TowerController:
	var t:=TowerController.new();t.new_run(seed_value,73);return t
func signature(map: TowerMapState) -> Array:
	var result: Array=[]
	for room in map.rooms.values():
		var enemies: Array=[]
		for e in room.encounter.enemies:enemies.append([e.enemy_id,e.unit_type_id,e.rank,e.level,e.initial_position])
		result.append([room.room_id,room.room_type,enemies])
	return result
func battle(t: TowerController,member_ids: Array=[]) -> BattleManager:
	var room: RoomState=t.current_room();var points: Array[Vector2]=[]
	for e in room.living_enemies():points.append(e.position)
	var plan:=DeploymentPlan.new(t.guild,points)
	var ids: Array=member_ids if not member_ids.is_empty() else [t.guild.all_members()[0].member_id]
	for i in range(ids.size()):verify(plan.place(ids[i],Vector2(100,180+i*100))==DeploymentRules.Code.OK,"real member placement")
	var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b)
	verify(t.start_battle(plan,b),"actual map room starts real session")
	verify(b.common_combat_enabled and b.full_characters_enabled,"tower always common/full")
	for u in b.units:u.combat.cooldown=1000;u.move_speed=0;u.parry_cooldown=1000
	return b
func kill_enemies(b: BattleManager) -> void:
	var ally: BattleUnit=b.units.filter(func(u):return u.original_team==0)[0]
	for e in b.units:
		if e.original_team==1:e.receive_damage(e.current_hp+1,ally)
	b.check_outcome()
func map_tests() -> void:
	groups+=1
	var t:=make_tower();var map: TowerMapState=t.guild.state.tower.map
	verify(map.floors.size()==15 and TowerMapGenerator.CHAPTERS==3,"3 chapters /15 floors")
	verify(map.rooms.size()==120,"120 pure room records")
	verify(t.guild.state.gold==1200 and t.guild.state.tokens==5 and t.guild.state.player_hp==100,"actual initial resources")
	verify(t.guild.all_members().map(func(m):return m.unit_type_id)==[0,0,1,5],"web initial guild")
	verify(t.guild.state.strategy_cards.map(func(c):return c.kind)==[&"mango",&"evade",&"shield",&"shield"],"web initial cards")
	for depth in range(15):
		var floor: FloorState=map.floors[depth];var count: int=6+depth/3
		verify(floor.room_ids.size()==count,"depth room count")
		verify(floor.required_clear_count==ceili(count/2.0),"ceil half unlock")
		var rooms: Array=floor.room_ids.map(func(id):return map.get_room(id))
		if depth%5 in [2,4]:
			var milestone: RoomState=rooms[floori(count/2.0)]
			verify(milestone.room_type==(RoomType.BOSS if depth%5==4 else RoomType.MINIBOSS) and milestone.publicly_visible,"central public milestone")
		if depth%5==4:verify(rooms.all(func(r):return r.room_type in [RoomType.BOSS,RoomType.REST,RoomType.EVENT]),"boss floor composition")
		var q: Dictionary=TowerMapGenerator.quotas(count)
		verify(rooms.filter(func(r):return r.room_type==RoomType.REST).size()==q.rest,"rest quota")
		if depth%5!=4:verify(rooms.filter(func(r):return RoomType.is_combat(r.room_type)).size()==q.battle,"combat quota incl miniboss")
		for room in rooms:
			verify(room.room_id=="%d:%d"%[depth,room.lane] and room.source_run_id==t.guild.state.run_id,"stable room ID /run ownership")
			verify(not room.discovered and not room.visited and not room.cleared,"separate initial flags")
			verify(room.visible_kind()==(room.room_type if room.publicly_visible else &"hidden"),"hidden room rules")
	verify(signature(map)==signature(make_tower().guild.state.tower.map),"seed reproduces rooms/enemies/positions")
	verify(map.floors[0].room_ids.map(func(id):return map.get_room(id).room_type)==[RoomType.RECRUIT,RoomType.SHOP,RoomType.REST,RoomType.BATTLE,RoomType.EVENT,RoomType.BATTLE],"special starting slots")
func encounters() -> void:
	groups+=1
	var found: Dictionary={};var ids: Dictionary={}
	var before_nodes: int=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var started_at: int=Time.get_ticks_usec()
	var types: Dictionary=CharacterCatalog.all();var base: Dictionary={}
	for data in types.values():base[data.type_id]=[data.max_hp,data.attack,data.move_speed,data.defense_power,data.body_scale]
	for seed_value in [1,4,91]:
		var t:=make_tower(seed_value)
		for room in t.guild.state.tower.map.rooms.values():
			var total: float=0
			for entry in room.encounter.enemies:
				found[entry.unit_type_id]=true
				verify(not ids.has(str(seed_value)+entry.enemy_id),"globally room scoped enemy IDs")
				ids[str(seed_value)+entry.enemy_id]=true
				total+=entry.level
				var enemy: EnemyRoomState=room.enemy_state[entry.enemy_id];var stats: UnitCombatStats=enemy.combat_stats;var data: UnitData=types[entry.unit_type_id]
				verify(stats.max_hp==floorf(data.max_hp*.8*(1+entry.level*.12)*entry.hp_multiplier+.5),"actual enemy HP formula")
				verify(is_equal_approx(stats.attack,data.attack*.8*(1+entry.level*.08)*entry.damage_multiplier),"actual enemy attack formula")
				verify(is_equal_approx(stats.defense,data.defense_power*.8*(1+entry.level*.08)*entry.defense_multiplier),"actual enemy defense formula")
				verify(is_equal_approx(stats.speed,data.move_speed*.8*(1+entry.level*.02)*entry.speed_multiplier),"actual enemy speed formula")
				verify(entry.initial_position.is_finite() and entry.initial_position.x>=415+27*entry.body_scale,"enemy placement zone /radius")
				verify(enemy.current_hp==stats.max_hp and enemy.spawn==entry,"initial spawn/persistent state separated")
				for other in room.encounter.enemies:
					if other==entry:continue
					verify(entry.initial_position.distance_to(other.initial_position)>=27*(entry.body_scale+other.body_scale)+18,"initial size spacing")
			if not room.encounter.enemies.is_empty():verify(total/room.encounter.enemies.size()==TowerMapGenerator.average_level(room.floor_index),"balanced level average exact")
			if room.room_type==RoomType.BOSS:
				var e: EnemySpawnEntry=room.encounter.enemies[0]
				verify(e.rank==&"boss" and e.hp_multiplier==3.6 and e.damage_multiplier==2.15 and e.defense_multiplier==2 and e.speed_multiplier==1.12 and e.body_scale==1.85,"boss actual multipliers")
				verify(e.unit_type_id in TowerMapGenerator.BOSS_POOL and room.encounter.enemies[1].rank==&"elite","boss candidate/support rank")
			if room.room_type==RoomType.MINIBOSS:verify(room.encounter.enemies[0].rank==&"elite" and room.encounter.enemies[0].hp_multiplier==2.5,"miniboss actual rank")
	print("PHASE9 MAP PERFORMANCE: three full maps elapsed_ms=",(Time.get_ticks_usec()-started_at)/1000.0," node_delta=",int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))-before_nodes)
	verify(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==before_nodes,"pure maps do not create Scene Nodes")
	verify(found.size()==CharacterCatalog.NAMES.size(),"encounters can draw every type via actual pools")
	for data in types.values():verify(base[data.type_id]==[data.max_hp,data.attack,data.move_speed,data.defense_power,data.body_scale],"UnitData remains immutable")
func golden_web_rules() -> void:
	groups+=1
	var file:=FileAccess.open("res://migration/phase9-web-rules.json",FileAccess.READ)
	var web: Dictionary=JSON.parse_string(file.get_as_text())
	for row in web.floors:
		verify(TowerMapGenerator.room_count(row.depth)==row.count,"executed JS floor count golden")
		verify(TowerMapGenerator.average_level(row.depth)==row.level,"executed JS level golden")
		for key in ["battle","rest","services","event"]:verify(TowerMapGenerator.quotas(row.count)[key]==row.quotas[key],"executed JS quotas golden")
	for row in web.samples:
		var entry:=EnemySpawnEntry.new();entry.level=row.level;entry.set_rank(StringName(row.rank))
		var stats:=TowerEnemyStatsAssembler.assemble(CharacterCatalog.all()[int(row.type)],entry)
		for pair in [["max_hp","hp"],["attack","dmg"],["defense","defensePower"],["speed","speed"],["scale","scale"]]:verify(is_equal_approx(stats.get(pair[0]),row.stats[pair[1]]),"executed JS stats golden")
	# Invalid per-spawn stats must be rejected before any Unit creation.
	var stats:=UnitCombatStats.new();stats.max_hp=NAN;stats.attack=2;stats.defense=2;stats.speed=2
	verify(not BattleUnitFactory.validate_placements([{"data":BattleManager.WARRIOR,"position":Vector2(500,500),"combat_stats":stats}]).ok,"invalid calculated stats rejected")

func navigation() -> void:
	groups+=1
	var t:=make_tower();var run: RunState=t.guild.state
	verify(t.select_room("missing")==TowerNavigationPolicy.Code.INVALID_ROOM,"unknown room rejected")
	verify(t.select_room("1:0")==TowerNavigationPolicy.Code.LOCKED_FLOOR,"locked floor rejected")
	verify(t.select_room("0:0")==TowerNavigationPolicy.Code.OK and run.gold==1250,"first discover50")
	var room: RoomState=t.current_room();verify(room.discovered and room.visited and not room.consumed and not room.cleared,"uncompleted recruit does not clear on entry")
	verify(t.return_map() and t.select_room("0:0")==TowerNavigationPolicy.Code.OK and run.gold==1250,"revisit no duplicate discovery")
	t.return_map();verify(t.select_room("0:3")==TowerNavigationPolicy.Code.OK,"battle routing")
	verify(not t.return_map() and not t.abandon(true),"unfinished deployment locks navigation")
	verify(t.select_room("0:1")==TowerNavigationPolicy.Code.UNFINISHED_BATTLE,"cannot switch rooms during deployment")
	var other:=make_tower();other.guild.state.tower.phase=&"event_active"
	verify(not other.return_map() and other.select_room("0:0")==TowerNavigationPolicy.Code.EVENT_IN_PROGRESS,"event active lock hook")
	other.guild.state.tower.phase=&"route"
	verify(not other.abandon(false) and other.abandon(true),"confirmation required for abandon")
	verify(other.guild.state.game_over and other.select_room("0:0")==TowerNavigationPolicy.Code.GAME_OVER,"gameover map lock")
	var previous: String=other.guild.state.run_id;other.new_run(4,73)
	verify(other.guild.state.run_id!=previous and not other.guild.state.game_over and other.guild.state.gold==1200,"new independent run")
	# Map RNG and combat RNG advance independently.
	var before: int=other.combat_rng.state;other.floor_reward(0);verify(other.combat_rng.state==before,"map reward draws do not consume combat RNG")
	var map_before: int=other.generator.rng.state;other.combat_rng.randi();verify(other.generator.rng.state==map_before,"combat draw does not consume map RNG")
func progression() -> void:
	groups+=1
	var t:=make_tower();var state: TowerRunState=t.guild.state.tower
	for id in state.map.floors[0].room_ids.slice(0,2):state.map.get_room(id).cleared=true
	t.refresh_progress(0);verify(state.unlocked_floor==0,"below half remains locked")
	state.map.get_room("0:2").cleared=true;t.refresh_progress(0);verify(state.unlocked_floor==1,"half boundary unlocks next")
	for depth in range(1,5):
		var floor: FloorState=state.map.floors[depth]
		var selected: int=0
		for id in floor.room_ids:
			var room: RoomState=state.map.get_room(id)
			if room.room_type!=RoomType.BOSS and selected<floor.required_clear_count:room.cleared=true;selected+=1
		t.refresh_progress(depth)
	verify(state.unlocked_floor==4,"boss gate blocks next chapter despite half")
	var boss: RoomState=state.map.rooms.values().filter(func(r):return r.floor_index==4 and r.room_type==RoomType.BOSS)[0]
	boss.cleared=true;t.refresh_progress(4)
	verify(state.unlocked_floor==5 and state.chapter_progress.has(1),"boss gate chapter progression")
	var floor: FloorState=state.map.floors[0];floor.bonus=&"tokens";t.guild.state.player_hp=40
	for m in t.guild.all_members():m.energy=2
	for id in floor.room_ids:state.map.get_room(id).cleared=true
	t.refresh_progress(0)
	verify(floor.conquered and state.floor_conquest.has(0),"full floor conquest once")
	verify(t.guild.state.player_hp==50 and t.guild.state.player_max_hp==100,"ACTUAL player HP recovery10% no maxHP increase")
	verify(t.guild.all_members().all(func(m):return m.energy==2),"conquest no longer grants energy")
	var tokens: int=t.guild.state.tokens;t.refresh_progress(0)
	verify(t.guild.state.player_hp==50 and t.guild.state.tokens==tokens,"no duplicate conquest")
	floor=state.map.floors[1];floor.bonus=&"item";floor.bonus_item_kind=&"greenNecklace"
	for id in floor.room_ids:state.map.get_room(id).cleared=true
	t.refresh_progress(1)
	verify(state.reward_requests.size()==1 and state.reward_requests[0].item_kind==&"greenNecklace" and state.reward_requests[0].fulfilled and InventoryService.new(t.guild.state).available().any(func(i):return i.kind==&"greenNecklace"),"Phase10 consumes exact Phase9 reward hook once")
	floor=state.map.floors[2];floor.bonus=&"heal";var dead: GuildMemberState=t.guild.all_members()[0];dead.current_hp=0;dead.energy=0
	for id in floor.room_ids:state.map.get_room(id).cleared=true
	t.refresh_progress(2)
	verify(dead.current_hp==t.guild.definition(dead.unit_type_id).max_hp*.2,"actual conquest heal includes dead members")
	for depth in range(3,15):
		for id in state.map.floors[depth].room_ids:state.map.get_room(id).cleared=true
		t.refresh_progress(depth)
	verify(state.unlocked_floor==14 and state.conquered and state.chapter_progress.size()==3,"final conquest retains freely explorable map")
func integration() -> void:
	groups+=1
	var t:=make_tower();t.select_room("0:3");var room: RoomState=t.current_room();var ids: Array=t.guild.all_members().map(func(m):return m.member_id)
	var b:=battle(t,[ids[0],ids[1]])
	var actors: Array=b.units.filter(func(u):return u.original_team==1)
	for e in actors:verify(e.max_hp==room.enemy_state[e.source_enemy_id].combat_stats.max_hp and e.data==t.guild.definition(e.data.type_id),"calculated stats injected with shared Resource")
	var ally: BattleUnit=b.units[0];ally.current_hp=30;ally.healing_power=1.1
	var reserve_hp: float=t.guild.get_member(ids[2]).current_hp
	var max_hp: float=ally.max_hp;kill_enemies(b)
	verify(room.cleared and room.reward_claimed and room.consumed,"victory clears real room /reward receipt")
	verify(is_equal_approx(t.guild.get_member(ids[0]).current_hp,30),"victory no longer heals survivors")
	verify(ally.current_hp==t.guild.get_member(ids[0]).current_hp and b.result.final_hp_by_member_id[ids[0]]==ally.current_hp,"victory heal before result snapshot /runtime HP matches guild")
	verify(t.guild.get_member(ids[2]).current_hp==reserve_hp,"reserve no victory heal")
	var gold: int=t.guild.state.gold;var hp: float=t.guild.get_member(ids[0]).current_hp
	t._settled(b.result,BattleSettlement.Status.APPLIED)
	verify(t.guild.state.gold==gold and t.guild.get_member(ids[0]).current_hp==hp,"duplicate result no rewards/heal")
	verify(t.return_map() and t.select_room("0:3")==TowerNavigationPolicy.Code.OK and t.guild.state.tower.phase==&"cleared","cleared room view only")
	verify(not t.start_battle(DeploymentPlan.new(t.guild),b),"cleared room no enemy regeneration")
	b.free()
	# Retreat with one dead enemy; retry with moved friendly placement.
	t=make_tower();t.select_room("0:5");room=t.current_room();room.living_enemies()[1].persistent_state={"test_counter":8};b=battle(t)
	actors=b.units.filter(func(u):return u.original_team==1);var dead_id: String=actors[0].source_enemy_id
	actors[0].receive_damage(actors[0].current_hp+1,b.units[0]);actors[1].current_hp=17;actors[1].position=Vector2(410,500)
	actors[1].ultimate_gauge=37;actors[1].character_specific_state["test_counter"]=8
	var damaged_id: String=actors[1].source_enemy_id;var ally_id: String=b.units[0].source_member_id
	b.units[0].current_hp=40;b.clock.elapsed=20
	verify(t.session.request_retreat(),"real tower retreat")
	verify(not room.cleared and not room.enemy_state[dead_id].alive,"retreat does not clear or resurrect enemy")
	verify(room.enemy_state[damaged_id].current_hp==17 and room.enemy_state[damaged_id].position==Vector2(410,500),"retreat enemy HP/position saved")
	verify(t.guild.get_member(ally_id).current_hp==40,"retreat participant hp, no heal")
	verify(t.guild.state.player_hp==100,"retreat no defeat penalty")
	var signature_before: Array=signature(t.guild.state.tower.map);t.return_map();t.select_room("0:5");b.free()
	var plan:=DeploymentPlan.new(t.guild);verify(plan.restore(t.guild.state.last_formation)==1,"formation restore")
	plan.move(ally_id,Vector2(160,250));b=BattleManager.new();b.auto_start=false;b.set_physics_process(false);host.root.add_child(b);verify(t.start_battle(plan,b),"same room retry")
	var saved: BattleUnit=b.units.filter(func(u):return u.source_enemy_id==damaged_id)[0]
	verify(saved.current_hp==17 and saved.position==Vector2(410,500) and saved.ultimate_gauge==37 and saved.state_value("test_counter")==8,"retry state inject exact")
	verify(not b.units.any(func(u):return u.source_enemy_id==dead_id),"dead enemy never respawns")
	verify(b.units[0].position==Vector2(160,250),"ally uses new deployment not old finish position")
	verify(signature_before==signature(t.guild.state.tower.map),"revisit cannot redraw encounter/map")
	b.units[0].receive_damage(10000,saved);b.check_outcome()
	verify(not room.cleared and t.guild.state.player_hp==75 and not t.guild.state.game_over,"loss cost5+20 reserves keep run alive")
	verify(t.guild.get_member(ally_id).current_hp==0,"defeat no heal")
	b.free()
	# Draw clear and run-ended ordering use unchanged Phase4 settlement.
	t=make_tower();t.select_room("0:3");b=battle(t)
	var source: BattleUnit=b.units[0]
	for u in b.units:u.receive_damage(10000,source)
	b.check_outcome()
	verify(t.current_room().cleared and b.result.end_reason==BattleEndReason.Value.DRAW,"draw all dead with HP permits room clear")
	b.free()
	t=make_tower();t.select_room("0:3");t.guild.state.player_hp=1;b=battle(t)
	source=b.units[0]
	for u in b.units:u.receive_damage(10000,source)
	b.check_outcome()
	verify(t.guild.state.game_over and not t.current_room().cleared and b.result.end_reason==BattleEndReason.Value.RUN_ENDED,"HP0 outranks room clear")
	b.free()
	# Actual settlement order: final-room draw can conquest-revive before gameover.
	t=make_tower();t.select_room("0:3")
	for member in t.guild.all_members().slice(1):member.current_hp=0
	for id in t.guild.state.tower.map.floors[0].room_ids:
		if id!="0:3":t.guild.state.tower.map.get_room(id).cleared=true
	t.guild.state.tower.map.floors[0].bonus=&"heal";b=battle(t);source=b.units[0]
	for u in b.units:u.receive_damage(10000,source)
	b.check_outcome()
	verify(t.current_room().cleared and t.guild.state.tower.map.floors[0].conquered and not t.guild.state.game_over,"conquest heal precedes guild wipe gameover")
	verify(t.guild.living_members().size()==4,"conquest revives eligible dead guild")
	b.free()
func run(tree: SceneTree) -> void:
	host=tree;map_tests();encounters();golden_web_rules();navigation();progression();integration()
	print("PHASE 9 RESULT: ",groups," groups; ",checks," checks; ",failures," failures")
