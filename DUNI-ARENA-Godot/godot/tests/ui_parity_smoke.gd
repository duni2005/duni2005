extends SceneTree
var screen: TowerScreen
var checks:=0
var failures:=0
const OUT="/workspace/arena/godot/migration/ui-parity-fix/"
func _initialize():call_deferred("run")
func frames():
 for i in range(8):await process_frame
func verify(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error(label)
 print("PARITY ",label," = ",ok)
func shot(label: String):
 await frames()
 if is_instance_valid(screen) and is_instance_valid(screen.guild_dialog) and screen.guild_dialog.visible:print("GUILD RECT ",label," dialog ",screen.guild_dialog.size," panel ",screen.guild_panel.size," min ",screen.guild_panel.get_combined_minimum_size()," roster ",screen.guild_panel.roster.size)
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OUT+label+".png")
func press(b: Button):b.pressed.emit();await frames()
func run():
 root.gui_embed_subwindows=true
 for res in [Vector2i(390,844),Vector2i(1280,720)]:
  root.size=res;root.content_scale_size=res
  var tag="mobile" if res.x==390 else "desktop"
  screen=load("res://scenes/tower.tscn").instantiate();root.add_child(screen);screen.controller.new_run(19,73);screen.show_map();await frames()
  verify(screen.menu_button.get_parent().get_child_count()==3,"heading + two map actions")
  verify(not screen.new_button.is_visible_in_tree(),"run operations inside menu")
  if res.x==390:
   verify(screen.room_buttons["0:5"].get_global_rect().end.x<390,"six first-floor rooms fit without scroll")
   verify(screen.map_scroll.size.y>570,"map retains screen space")
  await shot(tag+"-tower")
  await press(screen.menu_button);await shot(tag+"-menu");screen.menu_dialog.hide()
  screen.open_guild();await shot(tag+"-guild")
  verify(not screen.guild_panel.upgrade_button.visible and not screen.guild_panel.inventory_scroll.visible,"guild is a roster, tools live in tabs")
  screen.guild_panel.show_tab("inventory");await shot(tag+"-inventory")
  screen.guild_panel.show_tab("upgrade");await shot(tag+"-upgrade");screen.guild_dialog.hide()
  screen.select_room("0:0");await frames();await shot(tag+"-recruit")
  var cs=screen.content_screen
  var row=cs.content_box.get_child(1).get_child(0)
  verify(row.get_child(2).get_global_rect().end.x<=res.x,"three recruit candidates fit")
  await press(cs.map_button);screen.select_room("0:1");await shot(tag+"-shop")
  verify(screen.content_screen.content_tabs.visible,"shop has original category tabs")
  await press(screen.content_screen.map_button);screen.select_room("0:3");await frames()
  var room=screen.battle_screen
  await shot(tag+"-deploy")
  verify(not room.clear_button.visible and not room.restore_button.visible,"advanced placement tools tucked away")
  for i in range(4):room.plan.place(room.guild.all_members()[i].member_id,Vector2(100+i%2*140,240+i/2*200))
  room.start_battle();await frames();room.battle.set_physics_process(false)
  await shot(tag+"-battle")
  verify(room.board.board_rect().size.x>minf(res.x-40,350),"arena stays readable")
  room.battle.clock.elapsed=12;room.battle.turning.advance(.01);room.battle.turning.advance(2);await shot(tag+"-tp")
  verify(room.turning_panel.visible,"turning point usable")
  await press(room.turning_panel.resume_button)
  verify(not room.battle.turning.is_paused(),"resume still resolves")
  room.battle.clock.elapsed=20;room.session.request_retreat();await shot(tag+"-result")
  verify(room.next_button.get_global_rect().end.y<res.y,"result action fits")
  screen.free();await frames()
 print("UI PARITY RESULT: ",checks," checks; ",failures," failures")
 quit(0 if failures==0 else 1)
