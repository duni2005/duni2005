class_name TowerMapGenerator
extends RefCounted
## Executable dist/tower.js functions, translated with explicit map RNG.
const CHAPTERS = 3
const CHAPTER_FLOORS = 5
const DEPTH = 15
const FRONT = [0,3,4,7,8,9,10,11,12,14,16,17,19,26]
const RANGED = [1,2,6,13,15,18,20,21,22,23,24,25,28,30,31,32]
const SUPPORT = [4,5,15,16,17,19,24,25,27,29]
const BOSS_POOL = [0,2,4,7,9,10,11,12,13]
const FORMATIONS = [&"전열", &"분산", &"쌍익", &"포위", &"밀집"]
const ITEMS = ItemCatalog.KINDS
## Chance that a floor's second service room is the blacksmith instead of the shop.
const BLACKSMITH_CHANCE: float = .5
var rng := RandomNumberGenerator.new()
var catalog: Dictionary = CharacterCatalog.all()
static func room_count(depth: int) -> int: return 6 + floori(maxi(0,depth)/3.0)
static func average_level(depth: int) -> int: return maxi(0,floori(depth*1.6+.5))
static func quotas(count: int) -> Dictionary:
	var combat: int=mini(count,floori(count*.4+.5))
	var rest: int=mini(count-combat,maxi(1,floori(count*.15+.5)))
	var service: int=mini(count-combat-rest,clampi(floori(count*.25+.5),1,4))
	return {"battle":combat,"rest":rest,"services":service,"event":count-combat-rest-service}
func shuffle(list: Array) -> void:
	for i in range(list.size()-1,0,-1):
		var j: int=rng.randi_range(0,i);var v=list[i];list[i]=list[j];list[j]=v
func kinds(depth: int) -> Array:
	var count: int=room_count(depth);var q: Dictionary=quotas(count)
	if depth==0: return [RoomType.RECRUIT,RoomType.SHOP,RoomType.REST,RoomType.BATTLE,RoomType.EVENT,RoomType.BATTLE]
	var chapter_floor: int=depth%5+1
	var milestone: StringName=RoomType.MINIBOSS if chapter_floor==3 else RoomType.BOSS if chapter_floor==5 else &""
	var list: Array=[]
	if milestone==RoomType.BOSS:
		for i in range(q.rest):list.append(RoomType.REST)
		for i in range(count-q.rest-1):list.append(RoomType.EVENT)
	else:
		for i in range(q.battle-int(milestone==RoomType.MINIBOSS)):list.append(RoomType.BATTLE)
		for i in range(q.rest):list.append(RoomType.REST)
		# Services: a recruit, then the shop or the blacksmith, then any of the three.
		for i in range(q.services):
			if i==0:list.append(RoomType.RECRUIT)
			elif i==1:list.append(TowerController.BLACKSMITH if rng.randf()<BLACKSMITH_CHANCE else RoomType.SHOP)
			else:list.append([RoomType.RECRUIT,RoomType.SHOP,TowerController.BLACKSMITH][rng.randi_range(0,2)])
		for i in range(q.event):list.append(RoomType.EVENT)
	shuffle(list)
	if milestone!=&"":list.insert(floori(count/2.0),milestone)
	return list
func pick(pool: Array,chosen: Array[EnemySpawnEntry],depth: int) -> int:
	var available: Array=pool.filter(func(t):return chosen.filter(func(e):return e.unit_type_id==t).size()<2)
	var fresh: Array=available.filter(func(t):return not chosen.any(func(e):return e.unit_type_id==t))
	var options: Array=fresh if not fresh.is_empty() and rng.randf()<.68 else available
	var weights: Array=[];var total: float=0
	for type in options:
		var weight: float=maxf(.35,180.0/catalog[type].base_gold_cost) if depth<3 else 1
		weights.append(weight);total+=weight
	var roll: float=rng.randf()*total
	for i in range(options.size()):
		roll-=weights[i]
		if roll<=0:return options[i]
	return options.back()
func add_enemy(encounter: EncounterState,type: int,rank: StringName=&"normal") -> void:
	var e:=EnemySpawnEntry.new();e.unit_type_id=type;e.set_rank(rank);encounter.enemies.append(e)
func enemy_count(kind: StringName,depth: int) -> int:
	var extra: int=mini(1,floori(rng.randf()*2)) # JS random is <1; Godot randf can include1.
	return mini(7,4+floori(depth/5.0)+extra) if kind==RoomType.BOSS else mini(6,2+floori(depth/6.0)+extra) if kind==RoomType.MINIBOSS else mini(12,3+floori(depth*.7)+extra)
func position_valid(point: Vector2,enemy: EnemySpawnEntry,placed: Array[EnemySpawnEntry]) -> bool:
	var radius: float=27*enemy.body_scale
	return point.x>=415+radius and point.x<=780-radius and point.y>=28+radius and point.y<=772-radius and placed.all(func(p):return p.initial_position.distance_to(point)>=radius+27*p.body_scale+18)
func enemy_position(enemy: EnemySpawnEntry,index: int,count: int,formation: StringName,placed: Array[EnemySpawnEntry]) -> Vector2:
	var radius: float=27*enemy.body_scale
	var min_x: float=415+radius;var max_x: float=780-radius;var min_y: float=28+radius;var max_y: float=772-radius
	var front: bool=catalog[enemy.unit_type_id].attack_range<100
	for attempt in range(160):
		var x: float=rng.randf_range(min_x,max_x);var y: float=rng.randf_range(min_y,max_y)
		if attempt<90:
			match formation:
				&"전열":
					x=rng.randf_range(min_x,min_x+85) if front or enemy.rank==&"boss" else rng.randf_range(max_x-95,max_x)
					y=65+(index+.5)*670/count+rng.randf_range(-55,55)
				&"쌍익":y=(590 if index%2 else 205)+rng.randf_range(-95,95)
				&"포위":
					var angle: float=-1.22+(index+.5)/count*2.44+rng.randf_range(-.1,.1);var distance: float=rng.randf_range(260,335)
					x=400+cos(angle)*distance;y=400+sin(angle)*distance
				&"밀집":x=(660 if index%2 else 520)+rng.randf_range(-65,65);y=(555 if index%2 else 235)+rng.randf_range(-95,95)
		var point:=Vector2(clampf(x,min_x,max_x),clampf(y,min_y,max_y))
		if position_valid(point,enemy,placed):return point
	var candidates: Array[Vector2]=[]
	var x: float=min_x
	while x<=max_x:
		var y: float=min_y
		while y<=max_y:
			var point:=Vector2(x,y)
			if position_valid(point,enemy,placed):candidates.append(point)
			y+=24
		x+=24
	# Web throws if none exist; never silently manufacture overlapping spawns.
	if candidates.is_empty():push_error("Tower encounter has no valid spawn space");return Vector2(NAN,NAN)
	return candidates[rng.randi_range(0,candidates.size()-1)]
func encounter_for(room: RoomState) -> EncounterState:
	var encounter:=EncounterState.new();encounter.room_kind=room.room_type;encounter.depth=room.floor_index
	if not RoomType.is_combat(room.room_type):return encounter
	var count: int=enemy_count(room.room_type,room.floor_index);var all: Array=range(CharacterCatalog.NAMES.size())
	encounter.formation=FORMATIONS[rng.randi_range(0,FORMATIONS.size()-1)]
	if room.room_type==RoomType.BOSS:
		var type: int=pick(BOSS_POOL,encounter.enemies,room.floor_index);add_enemy(encounter,type,&"boss")
		add_enemy(encounter,pick(all.filter(func(v):return v!=type),encounter.enemies,room.floor_index),&"elite")
	elif room.room_type==RoomType.MINIBOSS:add_enemy(encounter,pick(FRONT,encounter.enemies,room.floor_index),&"elite")
	for pool in [FRONT,RANGED,SUPPORT]:
		if encounter.enemies.size()>=count:break
		var fresh: Array=pool.filter(func(t):return not encounter.enemies.any(func(e):return e.unit_type_id==t))
		add_enemy(encounter,pick(fresh if not fresh.is_empty() else all.filter(func(t):return not encounter.enemies.any(func(e):return e.unit_type_id==t)),encounter.enemies,room.floor_index))
	while encounter.enemies.size()<count:add_enemy(encounter,pick(all,encounter.enemies,room.floor_index))
	var average: int=average_level(room.floor_index);var levels: Array=[]
	levels.resize(count);levels.fill(average)
	if average>0:
		for i in range(0,count-1,2):
			if i==0 or rng.randf()<.65:levels[i]-=1;levels[i+1]+=1
	shuffle(levels)
	var placed: Array[EnemySpawnEntry]=[]
	for i in range(count):
		var e: EnemySpawnEntry=encounter.enemies[i];e.level=levels[i];e.enemy_id="%s/enemy_%03d"%[room.room_id,i]
		e.initial_position=enemy_position(e,i,count,encounter.formation,placed);placed.append(e)
	return encounter
func generate(seed_value: int,run_id: String) -> TowerMapState:
	rng.seed=seed_value
	var map:=TowerMapState.new()
	for depth in range(DEPTH):
		var floor:=FloorState.new();floor.floor_index=depth;floor.chapter_index=depth/5+1;floor.unlocked=depth==0
		var types: Array=kinds(depth)
		floor.required_clear_count=ceili(types.size()/2.0)
		for lane in range(types.size()):
			var room:=RoomState.new("%d:%d"%[depth,lane]);room.source_run_id=run_id;room.floor_index=depth;room.chapter_index=floor.chapter_index;room.lane=lane;room.room_type=types[lane]
			# The blacksmith is an event room that comes from the service slots.
			if types[lane]==TowerController.BLACKSMITH:room.room_type=RoomType.EVENT;room.event_type=TowerController.BLACKSMITH
			room.publicly_visible=room.room_type in [RoomType.MINIBOSS,RoomType.BOSS]
			room.gold_reward=1000 if room.room_type==RoomType.BOSS else 700 if room.room_type==RoomType.MINIBOSS else 350+depth*50
			room.token_reward=3 if room.room_type==RoomType.BOSS else 2 if room.room_type==RoomType.MINIBOSS else 1 if RoomType.is_combat(room.room_type) else 0
			room.encounter=encounter_for(room)
			for e in room.encounter.enemies:
				var enemy: EnemyRoomState=room.add_enemy(e.enemy_id,catalog[e.unit_type_id],e.initial_position)
				enemy.spawn=e;enemy.combat_stats=TowerEnemyStatsAssembler.assemble(catalog[e.unit_type_id],e);enemy.current_hp=enemy.combat_stats.max_hp
			floor.room_ids.append(room.room_id);map.rooms[room.room_id]=room
		map.floors.append(floor)
	return map
