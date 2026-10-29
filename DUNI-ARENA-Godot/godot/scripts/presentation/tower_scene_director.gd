class_name TowerSceneDirector
extends CanvasLayer
## Transient real-time presentation queue. Never applies a reward/transaction.
const DURATIONS={"entry":Motion.CINEMATIC,"recruit":2.5,"promotion":4.2,"conquest":2.8}
const CHAPTER_NAMES={1:"무너진 회랑",2:"붉은 첨탑",3:"망고의 정상"}
const LIMIT=8
var active: Dictionary={}
var queue: Array[Dictionary]=[]
var played: Dictionary={}
var flights: Array[Dictionary]=[]
var toasts: Array[Dictionary]=[]
var run_id: String=""
var room_id: String=""
var phase: String=""
var surface: Control
var shown_count: int=0
var sparks: Array[Dictionary]=[]
var deltas: Array[Dictionary]=[]
var balances: Dictionary={}
var targets: Dictionary={}
func rebase_wallet(gold: int,tokens: int) -> void:balances={"gold":gold,"gem":tokens}
func sync_wallet(wallet: WalletBar,origin: Vector2,outcome: Dictionary={}) -> void:
	if wallet==null or wallet.guild==null:return
	targets={"gold":wallet.anchor("gold"),"gem":wallet.anchor("gem")}
	var actual: Dictionary={"gold":wallet.guild.state.gold,"gem":wallet.guild.state.tokens}
	if balances.is_empty():balances=actual;return
	for kind in actual:
		var delta: int=int(actual[kind])-int(balances[kind])
		if delta==0:continue
		var gain: int=int(outcome.get("gold",outcome.get("payout",0))) if kind=="gold" else int(outcome.get("tokens",0))
		var spent: int=maxi(0,gain-delta)
		var exchange: bool=gain>0 and spent>0 and gain-spent==delta
		var flows: Array=[[spent,"spend"],[gain,"gain"]] if exchange else [[absi(delta),"spend" if delta<0 else "gain"]]
		for flow in flows:
			var spending: bool=flow[1]=="spend"
			fly(kind,flow[0],targets[kind] if spending else origin,origin if spending else targets[kind],flow[1])
			if deltas.size()>=8:deltas.pop_front()
			deltas.append({"kind":kind,"value":-flow[0] if spending else flow[0],"point":origin+Vector2(0,(-20 if exchange and spending else 0)+(25 if kind=="gem" else 0)),"age":0.0,"duration":1.1})
		if exchange:wallet.animate_exchange(kind,int(balances[kind]),spent,int(actual[kind]))
		else:wallet.animate_resource(kind,int(balances[kind]),int(actual[kind]),0 if delta<0 else .72)
	balances=actual

func _ready() -> void:
	layer=1100;surface=TowerSceneSurface.new();surface.director=self;add_child(surface);surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func context(run: String,room: String,current_phase: String) -> void:
	if run_id!=run:clear();run_id=run
	room_id=room;phase=current_phase
	if phase=="gameover":active.clear();queue.clear()
	queue=queue.filter(_valid)
	if not active.is_empty() and not _valid(active):active.clear()
	_next()
func _valid(scene: Dictionary) -> bool:
	if scene.get("run",run_id)!=run_id:return false
	if scene.kind=="entry":return scene.room_id==room_id and phase not in ["battle","result","route","gameover"]
	if scene.kind=="recruit":return scene.room_id==room_id and phase=="recruit"
	return phase!="battle" and phase!="gameover"
func enqueue(scene: Dictionary) -> bool:
	var item: Dictionary=scene.duplicate(true);item["run"]=run_id
	var key: String=item.get("key","")
	if not key.is_empty() and played.has(key):return false
	if not _valid(item):return false
	if item.kind in ["entry","promotion"]:
		queue=queue.filter(func(s):return s.kind!="entry")
		if active.get("kind","")=="entry":active.clear()
	if queue.size()>=LIMIT:return false
	if not key.is_empty():played[key]=true
	item["duration"]=DURATIONS.get(item.kind,2.1);item["age"]=-float(item.get("delay",0))
	queue.append(item);_next();return true
func _next() -> void:
	if active.is_empty() and not queue.is_empty():active=queue.pop_front();shown_count+=1
func skip_recruit() -> bool:
	if active.get("kind","") not in ["recruit","promotion"] or float(active.age)<0:return false
	active.clear();_next();return true
func clear() -> void:
	active.clear();queue.clear();played.clear();flights.clear();toasts.clear();sparks.clear();deltas.clear();balances.clear();targets.clear();shown_count=0
func toast(title: String,icon: String="gold",detail: String="") -> void:
	if toasts.size()>=3:toasts.pop_front()
	toasts.append({"title":title,"icon":icon,"detail":detail,"age":0.0})
func fly(kind: String,amount: int,origin: Vector2,destination: Vector2,direction: String="gain") -> void:
	if amount<=0 or not origin.is_finite() or not destination.is_finite():return
	var count: int=clampi(ceili(sqrt(float(amount))/3),3,9) if kind=="gold" else clampi(amount,1,5)
	for i in range(count):
		if flights.size()>=96:flights.pop_front()
		var side: float=-1 if i%2==0 else 1
		flights.append({"kind":kind,"origin":origin+Vector2(side*3,i%3-1),"control":origin+Vector2(side*(25+i*5),55 if direction=="spend" else -65),"destination":destination,"direction":direction,"room":room_id,"age":-i*.035,"duration":.72+i*.012})
func impact(point: Vector2,kind: String,age: float=0) -> void:
	for i in range(8):
		if sparks.size()>=180:sparks.pop_front()
		sparks.append({"kind":kind,"point":point,"velocity":Vector2.from_angle(i*TAU/8)*(45+i*4),"age":age,"duration":.32})
func _process(dt: float) -> void:advance(dt)
func advance(dt: float) -> void:
	dt=maxf(0,dt)
	if not active.is_empty():
		active.age=float(active.age)+dt
		if active.age>=active.duration:active.clear();_next()
	for flight in flights:
		if flight.direction=="gain" and targets.has(flight.kind):flight.destination=targets[flight.kind]
		if flight.direction=="spend" and flight.room!=room_id:flight.age=flight.duration
		var before: float=flight.age
		if before<flight.duration and before+dt>=flight.duration:impact(flight.destination,flight.kind,maxf(0,before+dt-flight.duration))
	for collection in [flights,toasts,sparks,deltas]:
		for row in collection:row.age=float(row.age)+dt
		for i in range(collection.size()-1,-1,-1):
			if collection[i].age>=float(collection[i].get("duration",2.2)):collection.remove_at(i)
	if surface!=null:
		surface.mouse_filter=Control.MOUSE_FILTER_STOP if active.get("kind","") in ["recruit","promotion"] and float(active.get("age",-1))>=0 else Control.MOUSE_FILTER_IGNORE
		surface.queue_redraw()
