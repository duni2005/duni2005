extends SceneTree
var board: DeploymentBoard
var b: BattleManager
var frog: BattleUnit
var victim: BattleUnit
func _initialize():call_deferred("run")
func shot(name: String):
	board.presentation.advance(0);board.presentation.camera.reset();board.queue_redraw();board.presentation.queue_redraw()
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://migration/attack-motion/godot-frog-"+name+".png")
func run():
	root.size=Vector2i(800,800);root.content_scale_size=root.size
	board=DeploymentBoard.new();board.size=Vector2(800,800);board.editing=false;root.add_child(board)
	b=BattleManager.new();b.auto_start=false;board.add_child(b)
	var entries: Array[Dictionary]=[]
	for spec in [[24,0,Vector2(150,400)],[0,1,Vector2(500,400)],[1,1,Vector2(650,650)]]:entries.append({"data":CharacterCatalog.all()[spec[0]],"team":spec[1],"position":spec[2]})
	b.start_battle(entries,731);b.set_physics_process(false);frog=b.units[0];victim=b.units[1]
	for u in b.units:u.combat.cooldown=10000;u.parry_cooldown=10000;u.defense_cooldown=10000;u.velocity=Vector2.ZERO
	board.battle=b;board.presentation.attach(b);board.presentation.set_process(false)
	frog.combat.aim_angle=0;frog.ability.release_basic(frog)
	var projectile: BattleProjectile=b.projectiles[0];projectile.position=Vector2(410,400)
	await shot("extension")
	projectile.live=false;CharacterLifecycle.capture(frog,victim);CharacterLifecycle.advance_frog(frog,.2)
	await shot("pull")
	CharacterLifecycle.advance_frog(frog,.5)
	await shot("hold")
	CharacterLifecycle.advance_frog(frog,.7)
	var cargo: BattleProjectile=b.projectiles[-1];cargo.position+=cargo.velocity*.28;victim.position=cargo.position
	await shot("spit")
	board.free();quit()
