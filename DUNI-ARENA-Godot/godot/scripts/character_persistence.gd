class_name CharacterPersistence
extends RefCounted
## Tower whitelist; points encoded as scalar dictionaries, actor references as IDs.
const FIELDS = ["cooldown","heal","totemClock","chargeTotemClock","dash","defenseCooldown","parryCooldown","parryTime","parryCounterUsed","parryPulseUsed","shieldHp","shieldTime","ironDefenseTime","stun","invincible","shadowTime","guardianUltTime","mirrorReflectTime","revealTime","curseTime","guardRemaining","guardStacks","guardReady","damageTakenTotal","dolphinStacks","predatorStacks","shotsFired","duelRounds","ammo","reloadRemaining","sniperBurstReady","ultReadyAge","ultUses","pickupTime","bomberRush","bomberRushTime","bomberFuse","transferUsed","strategyUltimateReady","satelliteBursts","paladinSwings","paladinBlessingTime","tankFlameReady","tankHeadingAngle","shockStacks","face"]
static func point(p: Vector2) -> Dictionary:return {"x":p.x,"y":p.y}
static func vector(p: Dictionary,fallback: Vector2=Vector2.ZERO) -> Vector2:
	var result:=Vector2(p.get("x",fallback.x),p.get("y",fallback.y));return result if result.is_finite() else fallback
static func restore(u) -> void:
	if not u.battle.full_characters_enabled:return
	var saved: Dictionary=u.character_specific_state
	u.persistent_extra_fields=saved.duplicate(true)
	if saved.has("cooldown"):u.combat.cooldown=float(saved.cooldown)
	if saved.has("lostSword"):
		u.lost_sword=saved.lostSword.duplicate(true);u.lost_sword["point"]=point((u.position+Vector2(u.lost_sword.get("dx",0),u.lost_sword.get("dy",0))).clamp(Vector2(35,35),Vector2(765,765)))
	if u.state_value("guardRemaining")>0:u.guard_anchor=u.position
	if not u.source_enemy_id.is_empty() and saved.get("ultCast") is Dictionary:u.ultimate.cast=saved.ultCast.duplicate(true);u.ultimate.serial+=1
	if saved.get("puppetControl") is Dictionary:
		u.restored_control=saved.puppetControl.duplicate(true)
static func snapshot(u,state: Dictionary) -> Dictionary:
	if not u.battle.full_characters_enabled:return state
	for key in state.keys():
		if key not in FIELDS+["lostSword","ultCast","puppetControl","retreatRemaining","specialRemaining"] and not u.persistent_extra_fields.has(key):state.erase(key)
	for key in FIELDS:
		if key not in StrategyEffects.FIELDS and key not in StrategyEffects.BOOL_FIELDS and key!="face" and u.character_specific_state.has(key):state[key]=u.character_specific_state[key].duplicate(true) if u.character_specific_state[key] is Array or u.character_specific_state[key] is Dictionary else u.character_specific_state[key]
	state.cooldown=u.combat.cooldown
	if not u.lost_sword.is_empty():
		state.lostSword=u.lost_sword.duplicate(true);var pos: Vector2=vector(state.lostSword.point)
		state.lostSword.erase("point");state.lostSword.dx=pos.x-u.position.x;state.lostSword.dy=pos.y-u.position.y
	else:state.erase("lostSword")
	if not u.source_enemy_id.is_empty() and not u.ultimate.cast.is_empty():state.ultCast=u.ultimate.cast.duplicate(true)
	else:state.erase("ultCast")
	if not u.puppet_control.is_empty():state.puppetControl=u.puppet_control.duplicate(true);state.puppetControl.team=u.team
	else:state.erase("puppetControl")
	return state

static func restore_control(u) -> void:
	if u.restored_control.is_empty():return
	u.puppet_control=u.restored_control.duplicate(true);u.restored_control.clear()
	u.team=int(u.puppet_control.get("team",u.original_team))
	CharacterLifecycle.reset_intent(u)
	if u.stance==CombatStance.COVER:CharacterLifecycle.bind_cover(u)
