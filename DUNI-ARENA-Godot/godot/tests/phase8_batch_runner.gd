extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run() -> void:
	for batch in [[0,1,2,3,4,5],[6,7,8,9,10,11],[12,13,14,15,16,17],[18,19,20,21,22,23],[24,25]]:
		for type in batch:
			var b:=BattleManager.new();b.auto_start=false;b.set_physics_process(false);root.add_child(b)
			var data: UnitData=CharacterCatalog.all()[type]
			check(b.start_battle([{"data":data,"team":0,"position":Vector2(300,400)},{"data":BattleManager.WARRIOR,"team":1,"position":Vector2(380,400)},{"data":BattleManager.ARCHER,"team":0,"position":Vector2(200,200)}],100+type),"spawn %d"%type)
			var u: BattleUnit=b.units[0];var enemy: BattleUnit=b.units[1]
			check(u.ability!=null,"ability %d"%type)
			for other in b.units:
				if other!=u:other.combat.cooldown=10000;other.move_speed=0
			u.parry_cooldown=10000;u.defense_cooldown=10000
			for other in b.units:other.parry_cooldown=10000;other.defense_cooldown=10000
			u.target=enemy
			u.combat.force_start(u,enemy);u.combat.cooldown=10000
			for frame in range(360):
				if b.finished:break
				b.simulate(1.0/60)
			check(u.position.is_finite(),"finite %d"%type)
			check(u.combat.attacks_released>0 or type in [8,11],"release %d"%type)
			if not b.finished:
				CharacterLifecycle.cancel_duel(u);u.combat.cancel(u);u.ultimate.cast.clear();u.ultimate_gauge=100
				if type!=7 and type!=24:
					var t=u.ability.ultimate_target(u)
					check(u.ultimate.request(u,t),"ultimate request %d"%type)
					for frame in range(360):
						if b.finished:break
						b.simulate(1.0/60)
				check(UnitStateCodec.is_pure_data(StrategyEffects.snapshot(u)),"pure snapshot %d"%type)
			b.free()
		print("BATCH ",batch," checks=",checks," failures=",failures)
	print("PHASE8 BATCH RESULT: ",checks," / ",failures)
	quit(1 if failures else 0)
