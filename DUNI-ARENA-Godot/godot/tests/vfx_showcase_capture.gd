extends SceneTree
var board: DeploymentBoard
var battle: BattleManager
var stage: String="before"
class Captions extends Control:
	var labels: Array[Dictionary]=[]
	func _draw():
		for row in labels:draw_string(ThemeDB.fallback_font,row.at,row.label,HORIZONTAL_ALIGNMENT_CENTER,190,16,Color("e6dfd0"))
func _initialize():call_deferred("run")
func snap(name: String):
	board.presentation.camera.reset();board.presentation.queue_redraw()
	for i in range(3):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://migration/vfx-upgrade/"+stage+"-"+name+".png")
func run():
	if "--after" in OS.get_cmdline_user_args():stage="after"
	root.size=Vector2i(800,800);root.content_scale_size=root.size
	board=DeploymentBoard.new();board.size=Vector2(800,800);board.editing=false;root.add_child(board)
	battle=BattleManager.new();battle.auto_start=false;board.add_child(battle)
	var entries: Array[Dictionary]=[{"data":CharacterCatalog.all()[2],"team":0,"position":Vector2(50,30)},{"data":CharacterCatalog.all()[20],"team":1,"position":Vector2(750,30)}]
	battle.start_battle(entries,731);battle.set_physics_process(false);board.battle=battle
	for u in battle.units:u.combat.cooldown=10000;u.velocity=Vector2.ZERO
	board.presentation.attach(battle);board.presentation.set_process(false)
	var captions:=Captions.new();captions.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(captions)
	var kinds: Array=["hit","critical","parry_success","clash","explosion","shield_break","heal","reflect","ultimate","transcendence","death","launch"]
	for i in range(kinds.size()):
		var point:=Vector2(100+(i%4)*200,135+(i/4)*245)
		captions.labels.append({"at":point+Vector2(-95,90),"label":["타격","치명타","패링","상쇄","폭발","보호막 파괴","치유","반사","궁극기","초월","사망","발사"][i]})
		board.presentation.add_effect(kinds[i],point,Color("8bdfff") if i%3==0 else Color("ffb772") if i%3==1 else Color("c7a1ff"),75,.75)
		board.presentation.effects[-1].angle=-.3
	for frame in range(9):
		board.presentation.advance(.05);await snap("impacts-%02d"%frame)
	board.presentation.effects.clear();board.presentation.particles.clear();captions.labels.clear()
	for i in range(4):
		var point:=Vector2(210+(i%2)*380,240+(i/2)*360)
		battle.zones.add(battle.units[0],["blackhole","healing","tankFire","galaxy"][i],point,145,10)
		captions.labels.append({"at":point+Vector2(-95,158),"label":["블랙홀","치유 영역","화염","은하 영역"][i]})
	captions.queue_redraw()
	for frame in range(9):
		battle.clock.elapsed=frame*.12;board.presentation.advance(.12);await snap("fields-%02d"%frame)
	captions.free();board.free();quit()
