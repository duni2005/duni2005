class_name TowerController
extends RefCounted
## Progression orchestrator; combat mechanics remain RoomBattleSession's concern.
signal changed
## Event rooms roll one of these when first discovered (types already met weigh less).
const EVENT_TYPES: Array=[&"prediction",&"hotSpring",&"supply",&"tokenShop",&"mangoSapling",&"gambler"]
## The blacksmith event room is placed by the map generator, never rolled on discovery.
const BLACKSMITH: StringName = &"blacksmith"
var guild: GuildManager
var generator := TowerMapGenerator.new()
var combat_rng := RandomNumberGenerator.new()
var content_rng := RandomNumberGenerator.new()
var content: TowerContentService
var prediction_battle: BattleManager
var session: RoomBattleSession
var battle: BattleManager
var save_manager: SaveManager # Optional for isolated domain/regression tests.
var recovery_checkpoint: Dictionary = {} # Reserved attempt seed; no battle-frame data.
var _defer_save: bool = false
var battle_preparing: bool=false
func release_runtime_connections() -> void:
	# Disposing a view/run must not leave a RefCounted session -> controller cycle.
	# This does not settle or save a battle; its prebattle checkpoint remains on disk.
	if session!=null and session.settled.is_connected(_settled):session.settled.disconnect(_settled)
	if is_instance_valid(prediction_battle) and prediction_battle.battle_finished.is_connected(_prediction_finished):prediction_battle.battle_finished.disconnect(_prediction_finished)
	session=null;battle=null;prediction_battle=null
func _autosave() -> void:
	if save_manager!=null and not _defer_save:save_manager.request_autosave(self)
func _attempt_seed(kind: String) -> int:
	if recovery_checkpoint.get("kind")==kind and recovery_checkpoint.get("room_id")==guild.state.tower.selected_room_id:return int(recovery_checkpoint.seed)
	return int(combat_rng.randi())
func new_run(map_seed: int=1,combat_seed: int=2) -> bool:
	if guild != null and guild.state.tower.phase in [&"deploy", &"battle", &"event_active"]: return false
	release_runtime_connections()
	var run:=RunState.new();guild=GuildManager.new(run);run.gold=1200;run.tokens=5;run.tower=TowerRunState.new()
	for type in [0,0,1,5]:guild.create_member(type)
	for kind in [&"mango",&"evade",&"shield",&"shield"]:run.give_strategy_card(kind)
	run.tower.map=generator.generate(map_seed,run.run_id);combat_rng.seed=combat_seed;session=null;battle=null
	content_rng.seed=map_seed^0x628da7;content=TowerContentService.new(guild,content_rng);prediction_battle=null
	for node in run.tower.map.rooms.values():
		if node.room_type==RoomType.RECRUIT:content.ensure_recruit(node)
	recovery_checkpoint={};_autosave();changed.emit();return true
func current_room() -> RoomState:
	return guild.state.tower.map.get_room(guild.state.tower.selected_room_id)
func select_room(id: String) -> TowerNavigationPolicy.Code:
	update_gameover()
	var code: TowerNavigationPolicy.Code=TowerNavigationPolicy.check(guild.state,id)
	if code!=TowerNavigationPolicy.Code.OK:return code
	var room: RoomState=guild.state.tower.map.get_room(id)
	if not room.discovered:
		if room.room_type==RoomType.EVENT and room.event_type not in EVENT_TYPES and room.event_type!=BLACKSMITH:
			var encountered: Array=[]
			for other in guild.state.tower.map.rooms.values():
				if other.discovered and other.room_type==RoomType.EVENT:encountered.append(other.event_type)
			var options: Array=EVENT_TYPES;var total: int=0
			for type in options:total+=1 if type in encountered else 4
			var roll: float=generator.rng.randf()*total
			for type in options:
				roll-=1 if type in encountered else 4
				if roll<0:room.event_type=type;break
		guild.state.gold+=50;room.discovered=true
	room.visited=true
	var state: TowerRunState=guild.state.tower;state.visited_rooms[id]=true;state.selected_room_id=id;state.current_chapter=room.chapter_index
	room.content_visits+=1
	var reenter: bool=room.room_type in [RoomType.SHOP,RoomType.RECRUIT]
	state.phase=&"cleared" if room.cleared and not reenter else &"deploy" if RoomType.is_combat(room.room_type) else &"event_active" if room.room_type==RoomType.EVENT else room.room_type
	if state.phase==RoomType.SHOP:content.ensure_shop(room)
	if state.phase==&"event_active":
		content.ensure_event(room)
	guild.state.strategy_progress.current_depth=room.floor_index
	_autosave();changed.emit();return code
## The floor the party stands on (the map shows only this floor's rooms).
func current_floor() -> int:return guild.state.strategy_progress.current_depth
## The stairs appear once this floor's clear requirement has unlocked the next floor.
func can_ascend() -> bool:
	var state: TowerRunState=guild.state.tower
	return not guild.state.game_over and state.phase==&"route" and current_floor()<state.map.floors.size()-1 and state.unlocked_floor>current_floor()
func ascend() -> bool:
	if not can_ascend():return false
	guild.state.strategy_progress.current_depth+=1
	guild.state.tower.current_chapter=guild.state.tower.map.floors[current_floor()].chapter_index
	_autosave();changed.emit();return true
func start_battle(plan: DeploymentPlan,manager: BattleManager) -> bool:
	if battle_preparing:return false
	var prepared: Dictionary=_prepare_battle(plan,manager)
	if prepared.is_empty():return false
	if save_manager!=null and not save_manager.checkpoint(self,"battle",prepared.seed,prepared.formation).ok():
		combat_rng.state=prepared.previous_rng;session=null;return false
	return _launch_prepared(plan,manager,prepared.seed)
func start_battle_async(plan: DeploymentPlan,manager: BattleManager) -> bool:
	if battle_preparing:return false
	var prepared: Dictionary=_prepare_battle(plan,manager)
	if prepared.is_empty():return false
	battle_preparing=true
	if save_manager!=null:
		var saved: SaveLoadResult=await save_manager.checkpoint_async(self,"battle",prepared.seed,prepared.formation)
		if not saved.ok():
			combat_rng.state=prepared.previous_rng;session=null;battle_preparing=false;return false
	battle_preparing=false
	return _launch_prepared(plan,manager,prepared.seed)
func _prepare_battle(plan: DeploymentPlan,manager: BattleManager) -> Dictionary:
	var room: RoomState=current_room()
	if guild.state.tower.phase!=&"deploy" or room==null or manager==null:return {}
	manager.common_combat_enabled=true;manager.full_characters_enabled=true
	session=RoomBattleSession.new(guild,room);session.settled.connect(_settled)
	if save_manager!=null:
		if plan==null or plan.guild!=guild or manager.started or not session.can_enter():session=null;return {}
		var blockers: Array[Vector2]=[]
		for enemy in CombatPersistence.placements(room,guild):blockers.append(enemy.position)
		if DeploymentRules.validate_all(guild,plan.entries(),blockers)!=DeploymentRules.Code.OK:session=null;return {}
	var previous_rng: int=combat_rng.state;var seed_value: int=_attempt_seed("battle")
	var formation:=FormationState.new();formation.capture(plan.entries() if plan!=null else [])
	return {"previous_rng":previous_rng,"seed":seed_value,"formation":formation}
func _launch_prepared(plan: DeploymentPlan,manager: BattleManager,seed_value: int) -> bool:
	if not is_instance_valid(manager):session=null;return false
	if not session.start(plan,manager,seed_value):session=null;return false
	battle=manager;guild.state.tower.phase=&"battle";changed.emit();return true
func _settled(result: BattleResult,status: BattleSettlement.Status) -> void:
	if status!=BattleSettlement.Status.APPLIED:return
	var state: TowerRunState=guild.state.tower
	if state.processed_results.has(result.result_id):return
	_defer_save=true
	state.processed_results[result.result_id]=true
	var room: RoomState=current_room()
	# Settlement already performed healing and room clear before checking guild death.
	if room.cleared:
		state.cleared_rooms[room.room_id]=true
		if result.end_reason==BattleEndReason.Value.VICTORY and not room.reward_claimed:
			guild.state.gold+=room.gold_reward
			for id in result.surviving_member_ids:guild.state.gold+=int(result.member_victory_gold.get(id,0))
			guild.state.tokens+=room.token_reward;room.reward_claimed=true
			if room.room_type==RoomType.MINIBOSS:
				var keys: Array=StrategyCardCatalog.DEFINITIONS.keys();guild.state.give_strategy_card(keys[generator.rng.randi_range(0,keys.size()-1)])
		room.consumed=true;refresh_progress(room.floor_index)
		# Web applies conquest before checkTowerGameOver. Its heal bonus may revive
		# the last dead guild member after a draw; preserve that ordering.
		if guild.state.player_hp > 0 and not guild.living_members().is_empty() and guild.state.game_over_reason == RunState.GameOverReason.NO_LIVING_MEMBERS:
			guild.state.game_over=false;guild.state.game_over_reason=RunState.GameOverReason.NONE
	state.phase=&"gameover" if guild.state.game_over else &"result"
	if guild.state.game_over:
		state.result=&"gameover"
		for member in guild.all_members():member.stance=CombatStance.NORMAL
	recovery_checkpoint={};_defer_save=false;_autosave();changed.emit()
func return_map() -> bool:
	if guild.state.tower.phase in [RoomType.SHOP,RoomType.RECRUIT]:return content_action(&"finish").ok
	if not TowerNavigationPolicy.can_return(guild.state):return false
	guild.state.tower.phase=&"gameover" if guild.state.game_over else &"route";_autosave();changed.emit();return true
func floor_reward(depth: int) -> FloorState:
	var floor: FloorState=guild.state.tower.map.floors[depth]
	if floor.bonus==&"":
		floor.bonus=[&"heal",&"item",&"tokens"][generator.rng.randi_range(0,2)]
		if floor.bonus==&"item":floor.bonus_item_kind=TowerMapGenerator.ITEMS[generator.rng.randi_range(0,TowerMapGenerator.ITEMS.size()-1)]
		_autosave()
	return floor
func refresh_progress(changed_depth: int) -> void:
	var state: TowerRunState=guild.state.tower
	for floor in state.map.floors:
		floor.cleared_count=0
		for id in floor.room_ids:
			if state.map.get_room(id).cleared:floor.cleared_count+=1;state.cleared_rooms[id]=true
	while state.unlocked_floor<14:
		var floor: FloorState=state.map.floors[state.unlocked_floor]
		var boss_dead: bool=floor.room_ids.any(func(id):return state.map.get_room(id).room_type==RoomType.BOSS and state.map.get_room(id).cleared)
		if floor.cleared_count<floor.required_clear_count or floor.floor_index%5==4 and not boss_dead:break
		state.unlocked_floor+=1
	for floor in state.map.floors:floor.unlocked=floor.floor_index<=state.unlocked_floor
	guild.state.strategy_progress.unlocked_floor=state.unlocked_floor
	var last: FloorState=state.map.floors[14]
	state.conquered=last.cleared_count>=last.required_clear_count and last.room_ids.any(func(id):return state.map.get_room(id).room_type==RoomType.BOSS and state.map.get_room(id).cleared)
	if state.conquered:state.result=&"conquered"
	var changed_floor: FloorState=state.map.floors[changed_depth]
	if changed_depth%5==4 and changed_floor.room_ids.any(func(id):return state.map.get_room(id).room_type==RoomType.BOSS and state.map.get_room(id).cleared):state.chapter_progress[changed_floor.chapter_index]=true
	if changed_floor.cleared_count==changed_floor.room_ids.size() and not changed_floor.conquered:
		changed_floor.conquered=true;state.floor_conquest[changed_depth]=true
		# Actual web: restore PLAYER HP, do not increase guild maxHP.
		guild.state.player_hp+=guild.state.player_max_hp*.1
		var reward: FloorState=floor_reward(changed_depth)
		if reward.bonus==&"tokens":guild.state.tokens+=2
		elif reward.bonus==&"item":
			var request:=RewardRequest.new();request.reward_id="floor:%d"%changed_depth;request.kind=&"item";request.item_kind=reward.bonus_item_kind;state.reward_requests.append(request)
		else:
			# Web includes dead members and recipient healingPower.
			for member in guild.all_members():
				var dead: bool=not member.is_alive()
				GuildMemberCombatStats.heal(guild,member,guild.member_stats(member).max_hp*.2,true)
				if dead and member.is_alive():GuildMemberCombatStats.reset_bomber(member)
	process_reward_requests()

func abandon(confirmed: bool) -> bool:
	if not confirmed or guild.state.game_over or guild.state.tower.phase in [&"battle",&"deploy"] or is_instance_valid(prediction_battle) and not prediction_battle.finished:return false
	guild.state.game_over=true;guild.state.game_over_reason=RunState.GameOverReason.ABANDON;guild.state.tower.result=&"abandon";guild.state.tower.phase=&"gameover"
	for member in guild.all_members():member.stance=CombatStance.NORMAL
	recovery_checkpoint={};_autosave();changed.emit();return true

func process_reward_requests() -> void:
	if content==null:return
	for request in guild.state.tower.reward_requests:content.inventory.consume_reward(request)
	_autosave()
func content_action(action: StringName,options: Dictionary={}) -> Dictionary:
	update_gameover()
	_defer_save=true
	var result: Dictionary=content.execute(action,options)
	if result.ok and result.get("completion") is RoomContentResult:
		if not complete_room_content(current_room().room_id,result.completion):_defer_save=false;return {"ok":false,"code":&"completion_rejected"}
	if result.ok:update_gameover()
	_defer_save=false
	if result.ok:_autosave()
	changed.emit();return result
func complete_room_content(room_id: String,result: RoomContentResult) -> bool:
	var room: RoomState=current_room()
	if guild.state.game_over or room==null or room.room_id!=room_id or RoomType.is_combat(room.room_type) or result==null or result.room_id!=room_id:return false
	if content.pending_completions.get(result.receipt)!=result or guild.state.content_receipts.has(result.receipt):return false
	var deferred: bool=_defer_save;_defer_save=true
	guild.state.content_receipts[result.receipt]=result.outcome.duplicate(true);content.pending_completions.erase(result.receipt)
	if room.event!=null:room.event.reward_receipt=result.receipt
	room.cleared=true;guild.state.tower.cleared_rooms[room_id]=true
	room.consumed=room.room_type in [RoomType.REST,RoomType.EVENT]
	refresh_progress(room.floor_index)
	guild.state.tower.last_content_outcome=result.outcome.duplicate(true)
	guild.state.tower.phase=&"content_result" if result.stay_for_result else &"route"
	_defer_save=deferred;_autosave()
	return true
func choose_prediction(team: int,stake: int) -> bool:
	var room: RoomState=current_room()
	if guild.state.game_over or room==null or room.event_type!=&"prediction" or guild.state.tower.phase!=&"event_active":return false
	var state: PredictionState=room.event.prediction
	if state.status!=&"ready" or not stake in [50,100,200] or guild.state.gold<stake or not state.teams.any(func(t):return t.team==team):return false
	state.picked_team=team;state.stake=stake;_autosave();return true
func start_prediction(manager: BattleManager) -> bool:
	var room: RoomState=current_room()
	if manager==null or manager.started or guild.state.game_over or room==null or room.event_type!=&"prediction" or guild.state.tower.phase!=&"event_active":return false
	var state: PredictionState=room.event.prediction
	var receipt: String="prediction:"+room.room_id
	if not PredictionRules.valid(state) or state.status!=&"ready" or state.picked_team<0 or not state.stake in [50,100,200] or not ResourceTransaction.can_spend(guild.state,state.stake,0,receipt):return false
	if not state.teams.any(func(t):return t.team==state.picked_team):return false
	# Isolated full-mode battle. No guild/room session, death loss or guild settlement.
	manager.common_combat_enabled=true;manager.full_characters_enabled=true
	var previous_rng: int=combat_rng.state
	var seed_value: int=_attempt_seed("prediction");var placement_rng:=RandomNumberGenerator.new();placement_rng.seed=seed_value
	var placements: Array[Dictionary]=PredictionRules.placements(state,placement_rng)
	if not BattleUnitFactory.validate_placements(placements).ok:combat_rng.state=previous_rng;return false
	if save_manager!=null and not save_manager.checkpoint(self,"prediction",seed_value).ok():combat_rng.state=previous_rng;return false
	ResourceTransaction.spend(guild.state,state.stake,0,receipt);state.status=&"running";prediction_battle=manager
	manager.battle_finished.connect(_prediction_finished)
	if not manager.start_battle(placements,seed_value):
		guild.state.gold+=state.stake;guild.state.transaction_receipts.erase(receipt);state.status=&"ready";prediction_battle=null;combat_rng.state=previous_rng;return false
	return true
func _prediction_finished(result: BattleResult) -> void:
	var room: RoomState=current_room();var state: PredictionState=room.event.prediction
	if not result.completed or not is_instance_valid(prediction_battle) or not prediction_battle.finished or result.result_id!=prediction_battle.battle_result_id:return
	if state.status!=&"running":return
	_defer_save=true
	state.status=&"resolved";state.result=&"draw" if result.draw else &"correct" if result.winner_team==state.picked_team else &"incorrect"
	state.payout=state.stake*2 if state.result==&"correct" else state.stake if state.result==&"draw" else 0;state.tokens=int(state.result==&"correct")
	guild.state.gold+=state.payout;guild.state.tokens+=state.tokens;room.event.resolved=true
	var proposal: Dictionary=content.completion(&"prediction",{"result":state.result,"payout":state.payout,"tokens":state.tokens},true)
	if proposal.ok:complete_room_content(room.room_id,proposal.completion)
	recovery_checkpoint={};_defer_save=false;_autosave();changed.emit()

func choose_prediction_team(team: int) -> bool:
	var node: RoomState=current_room()
	if guild.state.game_over or node==null or node.event_type!=&"prediction" or guild.state.tower.phase!=&"event_active":return false
	var state: PredictionState=node.event.prediction
	if state.status!=&"ready" or not state.teams.any(func(t):return t.team==team):return false
	state.picked_team=team;_autosave();return true
func choose_prediction_stake(stake: int) -> bool:
	var node: RoomState=current_room()
	if guild.state.game_over or node==null or node.event_type!=&"prediction" or guild.state.tower.phase!=&"event_active":return false
	var state: PredictionState=node.event.prediction
	if state.status!=&"ready" or not stake in [50,100,200] or guild.state.gold<stake:return false
	state.stake=stake;_autosave();return true

func update_gameover() -> void:
	if not guild.state.game_over and guild.living_members().is_empty():
		guild.state.game_over=true;guild.state.game_over_reason=RunState.GameOverReason.NO_LIVING_MEMBERS
	if guild.state.game_over:
		guild.state.tower.phase=&"gameover";guild.state.tower.result=&"gameover"
