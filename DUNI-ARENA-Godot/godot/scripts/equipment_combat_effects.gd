class_name EquipmentCombatEffects
extends RefCounted
## Runtime equipment from Phase10 ownership/stats; no inventory read by Nodes.
static func advance(u,dt: float) -> void:
	if not u.alive:return
	if u.vigor_totem_count>0:
		u.set_state("totemClock",u.state_value("totemClock",5)-dt)
		while u.state_value("totemClock")<=1e-8:
			u.set_state("totemClock",u.state_value("totemClock")+5)
			u.battle.emit_combat_event(&"vigor_totem",u.position,{"radius":165*u.combat_scale()})
			for a in u.battle.units.filter(func(actor):return actor.alive and actor.team==u.team):
				if a.position.distance_to(u.position)<=165*u.combat_scale():CharacterAbility.restore_hp(a,6*_power(u,&"vigor_totem_power",u.vigor_totem_count)*(.6 if a==u else 1),u)
	if _stat(u,&"dragon_heart_count",0)>0:
		# 용의 심장: every 4s, fire bursts around the bearer.
		u.set_state("dragonClock",u.state_value("dragonClock",4)-dt)
		if u.state_value("dragonClock")<=0:
			u.set_state("dragonClock",4)
			var radius: float=130*u.combat_scale()
			u.battle.emit_combat_event(&"dragon_heart",u.position,{"radius":radius,"actor_id":u.battle_id})
			CharacterAbility.area_damage(u,u.position,radius,UnitStatTable.raw(u,&"dragon_heart")*_stat(u,&"dragon_heart_count",0),60,{"dmg":&"dragon_heart","critical":false,"damage_kind":&"magic","element":&"fire"})
	if u.charge_totem_count>0:
		u.set_state("chargeTotemClock",u.state_value("chargeTotemClock",4)-dt)
		while u.state_value("chargeTotemClock")<=1e-8:
			u.set_state("chargeTotemClock",u.state_value("chargeTotemClock")+4)
			u.battle.emit_combat_event(&"charge_totem",u.position,{"radius":165*u.combat_scale()})
			for a in u.battle.units.filter(func(actor):return actor.alive and actor.team==u.team):
				if a.position.distance_to(u.position)<=165*u.combat_scale():a.ultimate.gain(a,4*_power(u,&"charge_totem_power",u.charge_totem_count)*(.6 if a==u else 1)*a.ultimate.efficiency(a))

static func _power(u,field: StringName,fallback: float) -> float:
	var power: float=float(u.combat_stats.get(field)) if u.combat_stats!=null else 0.0
	return power if power>0 else fallback

## Item stat lines; units without item stats (enemies, tests) read neutral values.
static func _stat(u,field: StringName,neutral: float) -> float:
	return float(u.combat_stats.get(field)) if is_instance_valid(u) and u.combat_stats!=null else neutral
static func crit(u) -> float:return _stat(u,&"crit",0)
static func armor(u) -> float:return _stat(u,&"armor",0)
static func attack_speed(u) -> float:return maxf(.2,_stat(u,&"attack_speed",1))
static func ultimate_power(u) -> float:return _stat(u,&"ultimate_power",1)
## Physical or magic power, times elemental power for elemental hits.
static func damage_factor(u,options: Dictionary) -> float:
	if not is_instance_valid(u) or u.combat_stats==null:return 1
	var kind: StringName=options.get("damage_kind",CharacterCatalog.damage_kind(u.data.type_id))
	var element: StringName=options.get("element",CharacterCatalog.element(u.data.type_id))
	return (u.combat_stats.physical_power if kind==&"physical" else u.combat_stats.magic_power)*(u.combat_stats.element_power if element!=&"" else 1.0)
static func awl_strength(u) -> float:
	return _stat(u,&"awl_power",0)/u.opening_awl_count if is_instance_valid(u) and u.opening_awl_count>0 and _stat(u,&"awl_power",0)>0 else 1.0
## 불사조의 깃털: once per battle a lethal blow revives at 40% HP with 2s invulnerability.
static func phoenix(u) -> bool:
	if _stat(u,&"phoenix_count",0)<=0 or u.phoenix_used:return false
	u.phoenix_used=true;u.current_hp=maxf(u.current_hp,u.max_hp*.4);u.invincible_remaining=maxf(u.invincible_remaining,2)
	u.battle.emit_combat_event(&"phoenix",u.position,{"actor_id":u.battle_id});return true
## 시간의 모래시계: the gauge refills 35% right after an ultimate.
static func after_ultimate(u) -> void:
	var glasses: float=_stat(u,&"hourglass_count",0)
	if glasses>0:u.ultimate_gauge=clampf(u.ultimate_gauge+35*glasses,0,100)

static func on_kill(source) -> void:
	if source.source_member_id.is_empty() or source.fang_count<=0 or source.combat_stats==null:return
	source.equipment_fang_kills+=source.fang_count
	source.combat_stats.attack=source.combat_stats.equipment_attack_without_growth*(1+source.equipment_fang_kills*source.combat_stats.fang_rate())
static func launch_opening(battle: BattleManager) -> void:
	for u in battle.units:
		if not u.alive:continue
		for i in range(u.opening_awl_count):
			var scale: float=u.combat_scale()
			var p: BattleProjectile=CharacterAbility.shoot(u,0,0,{"kind":"openingAwl","offset":30/scale,"radius":28/scale,"visual_scale":1,"speed":1050,"life":1.1,"power":45,"impulse":0})
			p.hidden_launch=false;p.attack_instance.hidden_launch=false
			p.attack_instance.clash_radius=13 if u.data.type_id==2 else 7 if u.data.type_id==1 else 9
			battle.emit_combat_event(&"opening_awl",u.position,{"source":u.actor_id()})
