extends SceneTree
var b: BattleManager
class Gallery extends Control:
	var samples: Array[Dictionary]=[]
	func _draw():
		draw_rect(Rect2(Vector2.ZERO,size),Color("10181e"))
		for i in range(samples.size()):
			var row: Dictionary=samples[i];var origin:=Vector2(10+(i%4)*250,25+(i/4)*165)
			draw_string(ThemeDB.fallback_font,origin,row.title,HORIZONTAL_ALIGNMENT_LEFT,240,15,AttackVisuals.ink(row.p.source.data.type_id))
			var parent:=Transform2D(0,Vector2.ONE*.75,0,origin+Vector2(30,60))
			draw_set_transform_matrix(parent);AttackVisuals.projectile(self,row.p,[Vector2(0,50),Vector2(30,50),Vector2(60,50)],.35,parent,Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1020,870);root.content_scale_size=root.size
	b=BattleManager.new();b.auto_start=false;root.add_child(b)
	var entries: Array[Dictionary]=[]
	for type in range(26):entries.append({"data":CharacterCatalog.all()[type],"team":type%2,"position":Vector2(100+type%6*100,100+type/6*100)})
	b.start_battle(entries,731);b.set_physics_process(false);b.hide()
	var gallery:=Gallery.new();gallery.size=Vector2(1020,870);root.add_child(gallery)
	for row in [[1,""],[1,"giantArrow"],[2,""],[5,""],[6,"sniper"],[7,"pellet"],[23,"machineBullet"],[18,"tankShell"],[15,"missile"],[0,"swordWave"],[10,"greatImpact"],[21,"mirrorLight"],[21,"mirrorReflection"],[22,"star"],[20,"lightning"],[25,"controlThread"],[25,"sharpThread"],[24,"frogTongue"],[24,"frogBody"],[13,"bomb"]]:
		var u: BattleUnit=b.units[row[0]];u.position=Vector2.ZERO
		var p: BattleProjectile=CharacterAbility.shoot(u,.1,1,{"kind":row[1],"cargo":b.units[0].actor_id(),"fuse":1.2,"flight":0.0,"blast_radius":65})
		p.position=Vector2(130,50);p.previous_position=Vector2(100,45)
		gallery.samples.append({"p":p,"title":u.data.display_name+" · "+str(row[1])})
	gallery.queue_redraw()
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://migration/attack-motion/projectile-coverage.png")
	gallery.free();b.free();quit()
