class_name CustomBattleTests
extends RefCounted
## Custom battle (web custom mode): roster rules and real multi-team / free-for-all battles.
var checks: int=0
var failures: int=0
func verify(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("CUSTOM: "+label)
func run(tree: SceneTree) -> void:
	var setup:=CustomBattleSetup.new()
	verify(setup.validate()!="","empty roster cannot start")
	verify(setup.add(0,0,Vector2(100,100))=="","place warrior for blue")
	verify(setup.add(0,0,Vector2(130,100))!="","58 spacing enforced")
	verify(setup.add(1,0,Vector2(400,400))=="","second blue unit")
	verify(setup.validate()!="","one faction cannot start")
	verify(setup.add(5,1,Vector2(5,900))=="" and setup.entries[-1].position==Vector2(40,760),"placement clamps to 40..760 over the whole map")
	verify(setup.validate()=="","two factions can start")
	verify(setup.move(int(setup.entries[0].id),Vector2(700,700))=="" and setup.entries[0].position==Vector2(700,700),"free move")
	verify(setup.move(int(setup.entries[0].id),setup.entries[1].position)!="","move respects spacing")
	verify(setup.team_spending(0)==int(CharacterCatalog.all()[0].base_gold_cost+CharacterCatalog.all()[1].base_gold_cost),"team cost sums base cost")
	var id: int=int(setup.entries[0].id)
	verify(setup.equip(id,&"fang")=="" and setup.equip(id,&"vital")=="","two free items")
	verify(setup.equip(id,&"boots")!="","item slots capped at two")
	verify(setup.equip(id,&"reengrave")!="","consumables are not equippable")
	verify(setup.stats_for(setup.get_entry(id)).attack>CharacterCatalog.all()[0].attack,"items change stats")
	verify(setup.unequip(id,0) and setup.get_entry(id).items.size()==1,"items removable")
	setup.set_stance(id,CombatStance.RUSH);verify(setup.get_entry(id).stance==CombatStance.RUSH,"per-unit stance")
	verify(setup.remove(id) and setup.entries.size()==2,"eraser removes one")
	setup.clear();verify(setup.entries.is_empty(),"clear all")
	for i in range(CustomBattleSetup.MAX_PARTICIPANTS):setup.add(i%26,CustomBattleSetup.TEAM_ORDER[i%5])
	verify(setup.entries.size()==CustomBattleSetup.MAX_PARTICIPANTS and setup.add(0,0)!="","24 participant cap with auto placement")
	# Four teams plus free-for-all solo units fight to a single winner.
	setup.clear()
	var spots: Array=[Vector2(150,150),Vector2(650,150),Vector2(150,650),Vector2(650,650),Vector2(400,400),Vector2(400,120)]
	for i in range(4):setup.add(0,i,spots[i])
	setup.add(1,CustomBattleSetup.SOLO,spots[4]);setup.add(1,CustomBattleSetup.SOLO,spots[5])
	verify(setup.faction_count()==6,"two solo units are separate factions")
	var b:=BattleManager.new();b.auto_start=false;b.custom_mode=true;tree.root.add_child(b)
	verify(b.start_battle(setup.placements(),77),"custom placements start")
	b.set_physics_process(false)
	verify(b.units[0].team_color()==CustomBattleSetup.TEAM_COLORS[0] and b.units[3].team_color()==CustomBattleSetup.TEAM_COLORS[3],"four team colours")
	verify(b.units[4].team_color()==CustomBattleSetup.TYPE_COLORS[1],"solo unit uses its character colour")
	b.units[2].transcendence_gauge=100
	verify(b.transcendence.ready(b.units[2]),"any team may use transcendence in custom mode")
	var guard: int=0
	while not b.finished and guard<60*240:b.simulate(1.0/60);guard+=1
	verify(b.finished,"multi-faction battle reaches an end")
	var alive: Dictionary={}
	for u in b.units:
		if u.alive:alive[u.original_team]=true
	verify(alive.size()<=1,"at most one faction survives")
	b.queue_free()
	print("CUSTOM BATTLE RESULT: ",checks," checks; ",failures," failures")
