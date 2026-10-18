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
				if a.position.distance_to(u.position)<=165*u.combat_scale():CharacterAbility.restore_hp(a,6*u.vigor_totem_count*(.6 if a==u else 1),u)
	if u.charge_totem_count>0:
		u.set_state("chargeTotemClock",u.state_value("chargeTotemClock",4)-dt)
		while u.state_value("chargeTotemClock")<=1e-8:
			u.set_state("chargeTotemClock",u.state_value("chargeTotemClock")+4)
			u.battle.emit_combat_event(&"charge_totem",u.position,{"radius":165*u.combat_scale()})
			for a in u.battle.units.filter(func(actor):return actor.alive and actor.team==u.team):
				if a.position.distance_to(u.position)<=165*u.combat_scale():a.ultimate.gain(a,4*u.charge_totem_count*(.6 if a==u else 1)*a.ultimate.efficiency(a))

static func on_kill(source) -> void:
	if source.source_member_id.is_empty() or source.fang_count<=0 or source.combat_stats==null:return
	source.equipment_fang_kills+=source.fang_count
	source.combat_stats.attack=source.combat_stats.equipment_attack_without_growth*(1+source.equipment_fang_kills*.015)
static func launch_opening(battle: BattleManager) -> void:
	for u in battle.units:
		if not u.alive:continue
		for i in range(u.opening_awl_count):
			var scale: float=u.combat_scale()
			var p: BattleProjectile=CharacterAbility.shoot(u,0,0,{"kind":"openingAwl","offset":30/scale,"radius":28/scale,"visual_scale":1,"speed":1050,"life":1.1,"power":45,"impulse":0})
			p.hidden_launch=false;p.attack_instance.hidden_launch=false
			p.attack_instance.clash_radius=13 if u.data.type_id==2 else 7 if u.data.type_id==1 else 9
			battle.emit_combat_event(&"opening_awl",u.position,{"source":u.actor_id()})
