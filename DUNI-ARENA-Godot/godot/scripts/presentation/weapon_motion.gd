class_name WeaponMotion
extends RefCounted
## Read-only source animation adapter. No target tracking, simulation timers or combat RNG.
const DATA=preload("res://scripts/presentation/weapon_motion_data.gd").DATA
static var sheets: Array[Texture2D]=[]
static func phase_progress(u: BattleUnit) -> float:
	var p: AttackData=u.combat.profile(u)
	var duration: float=p.windup if u.combat_state==CombatController.State.WINDUP else p.active if u.combat_state==CombatController.State.ACTIVE else p.recovery
	return clampf(u.combat.phase_time/maxf(.00001,duration),0,1)
static func sword_attack(u: BattleUnit) -> bool:
	if u.data.type_id not in [0,3,10,14,16,19]:return false
	if u.data.type_id==10 and not u.lost_sword.is_empty():return false
	if u.data.type_id==16:
		var swing: int=int(u.state_value("paladinSwings"))-(0 if u.combat_state==CombatController.State.WINDUP else 1)
		return posmod(swing,2)==1
	return true
static func pose_progress(u: BattleUnit) -> float:
	var t: float=phase_progress(u)
	if not sword_attack(u):return t
	# Visual anticipation and snap only; actual windup/active/recovery are untouched.
	if u.combat_state==CombatController.State.WINDUP:return 1-pow(1-t,2.5)
	if u.combat_state==CombatController.State.ACTIVE:return 1-pow(1-t,3)
	return t
static func pose(u: BattleUnit) -> Dictionary:
	var variant: String="basic";var type: int=u.data.type_id;var index: int=0;var angle: float=u.facing;var weapon_scale: float=1
	if not u.ultimate.cast.is_empty():
		variant="ultimate";index=roundi(clampf(float(u.ultimate.cast.t)/maxf(.001,float(u.ultimate.cast.duration)),0,1)*(DATA.samples-1));angle=float(u.ultimate.cast.angle)
		if type==0:
			var charge: float=clampf(float(u.ultimate.cast.t)/maxf(.001,float(u.ultimate.cast.duration)),0,1)
			variant="basic";index=1+roundi((1-pow(1-charge,2.5))*(DATA.samples-1));weapon_scale=1.12+.28*charge
	elif type==10 and u.state_value("guardRemaining")>0:variant="guard"
	elif type in [6,7,23] and u.state_value("reloadRemaining")>0:
		variant="reload";index=1+int(fposmod(u.battle.clock.elapsed*8,DATA.samples))
	elif u.combat_state!=CombatController.State.IDLE:
		angle=u.combat.aim_angle
		var combo: int=int(u.combat.attack_metadata.get("combo",0))
		if type in [9,14] and combo>0:variant="combo%d"%mini(2,combo)
		if type==16:
			# Swings increments at release: active/recovery refer to the previous swing.
			var swing: int=int(u.state_value("paladinSwings"))-(0 if u.combat_state==CombatController.State.WINDUP else 1)
			if posmod(swing,2)==1:variant="sword"
		index=1+(u.combat_state-1)*int(DATA.samples)+roundi(pose_progress(u)*(DATA.samples-1))
	elif type==19 and bool(u.character_specific_state.get("saintFallen",false)):variant="fallen"
	elif type==18 and bool(u.character_specific_state.get("tankFlameReady",false)):variant="flame"
	return {"key":"%d:%s"%[type,variant],"index":index,"angle":angle,"weapon_scale":weapon_scale}
static func draw(canvas: CanvasItem,pose_data: Dictionary,alpha: float=1) -> void:
	if sheets.is_empty():
		for i in range(DATA.sheets):sheets.append(load("res://assets/motion/weapons_%d.png"%i))
	var bank: Array=DATA.banks[pose_data.key]
	var frame: Dictionary=DATA.frames[int(bank[clampi(int(pose_data.index),0,bank.size()-1)])]
	var r: Array=frame.rect;var offset: Array=frame.offset
	canvas.draw_texture_rect_region(sheets[int(frame.sheet)],Rect2(offset[0],offset[1],r[2],r[3]),Rect2(r[0],r[1],r[2],r[3]),Color(1,1,1,alpha))
