class_name ComboAbility
extends CharacterAbility
## Common phased three-hit scheduler; profiles/damage belong to the character.
func after_recovery(u) -> void:
	var index: int=int(u.combat.attack_metadata.get("combo",0))
	if index>=2:return
	u.combat.attack_metadata.combo=index+1;u.combat.active_profile=next_profile(u,index+1)
	u.combat.phase_time=0;u.combat_state=CombatController.State.WINDUP;u.combat.attack_serial+=1
func next_profile(u,_index: int) -> AttackData:
	var p: AttackData=u.data.attack_profile.duplicate();p.windup=.12;return p
