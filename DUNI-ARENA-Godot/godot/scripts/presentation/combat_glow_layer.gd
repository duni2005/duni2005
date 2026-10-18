class_name CombatGlowLayer
extends Control
## One additive CanvasItem, bounded light sprites; no lights/shadows per particle.
const LIMIT=112
const PRIORITY=["ultimate","transcendence","explosion","parry_success","warrior_parry","clash","shield_break","final_kill"]
var host
var drawn: int=0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var blend:=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=blend
func _draw() -> void:
	drawn=0
	if host==null or not is_instance_valid(host.battle) or host.board==null:return
	if host.cinematic.complete:return
	draw_set_transform_matrix(host.parent_transform)
	for priority in [true,false]:
		for e in host.effects:
			if drawn>=LIMIT:return
			if (String(e.kind) in PRIORITY)!=priority:continue
			var t: float=clampf(float(e.age)/maxf(.001,float(e.life)),0,1);var fade: float=pow(1-t,2)
			var strong: bool=String(e.kind) in PRIORITY
			var r: float=float(e.radius)*(.9 if strong else .7)
			VfxArt.glow(self,e.point,r,e.color,fade*(.55 if strong else .2));drawn+=1
			if strong:
				VfxArt.flare(self,e.point,float(e.get("angle",0))+.15,r*.8,Color("fff1dd"),fade*.5)
	if host.battle.finished:return
	for u in host.battle.units:
		if drawn>=LIMIT:return
		if u.alive and not u.ultimate.cast.is_empty():
			VfxArt.glow(self,u.position,70*u.combat_scale(),AttackVisuals.ink(u.data.type_id),.18);drawn+=1
	var projectile_budget: int=0
	for p in host.battle.projectiles:
		if drawn>=LIMIT or projectile_budget>=48:break
		if not p.live or p.hidden_launch or p.kind in ["frogTongue","frogBody","bomb"]:continue
		var r: float=15 if p.kind in ["machineBullet","pellet"] else 28
		VfxArt.glow(self,p.position,r,AttackVisuals.ink(p.source.data.type_id),.3);drawn+=1;projectile_budget+=1
	draw_set_transform(Vector2.ZERO)
