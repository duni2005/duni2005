extends SceneTree
## Browser QA save only. Never shipped or used by a production new run.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var c:=TowerController.new();c.new_run(19,73)
	c.guild.create_member(5);c.guild.create_member(5)
	assert(c.select_room("0:3")==TowerNavigationPolicy.Code.OK)
	var plan:=DeploymentPlan.new(c.guild)
	var points: Array[Vector2]=[Vector2(180,260),Vector2(180,520),Vector2(100,180),Vector2(80,400),Vector2(100,620),Vector2(80,700)]
	var members: Array[GuildMemberState]=c.guild.all_members()
	for i in range(members.size()):assert(plan.place(members[i].member_id,points[i])==DeploymentRules.Code.OK)
	var formation:=FormationState.new();formation.capture(plan.entries())
	var save: SaveLoadResult=SaveSnapshotBuilder.build(c,"save_mobile_layout_qa",int(Time.get_unix_time_from_system()),{"kind":"battle","room_id":"0:3","seed":73},formation)
	assert(save.ok(),save.detail)
	var f:=FileAccess.open("res://migration/mobile-ui-fix/browser-fixture.json",FileAccess.WRITE);f.store_string(JSON.stringify(save.document));f.close()
	c.release_runtime_connections();quit()
