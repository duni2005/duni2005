extends CharacterAbility
## 놓침 (테스트용 유닛): a plain melee hit; its gauge fills fast (CHARGE ×) so the ultimate can be
## tried often. Ultimate: every enemy holding a weapon drops it (놓침, WeaponDrop).
const CHARGE: float = 6
func charge_rate(_u) -> float:return CHARGE
func can_ultimate(u,t) -> bool:return t!=null and u.enemies(false).any(func(e):return e.alive and WeaponDrop.holds_weapon(e) and not WeaponDrop.lost(e))
func release_ultimate(u,_a: Dictionary,_dt: float) -> bool:
	u.battle.emit_combat_event(&"fumble_wave",u.position,{"actor_id":u.battle_id})
	for e in u.enemies(false):
		if e.alive and not e.unavailable():WeaponDrop.drop(e,u)
	return true
func ultimate_danger(_u,_observer,_a: Dictionary) -> bool:return false
func cast_area(u,_a: Dictionary) -> Dictionary:return {"point":CharacterPersistence.point(u.position),"radius":80*u.combat_scale()}
