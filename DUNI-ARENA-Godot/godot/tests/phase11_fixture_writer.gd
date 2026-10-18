extends SceneTree
## Invoked once intentionally; regression tests only read the committed fixture.
func _initialize() -> void:
	var c: TowerController=Phase11Fixture.make();var snapshot: SaveLoadResult=SaveSnapshotBuilder.build(c,"save_fixed_v1",1700000000)
	if not snapshot.ok():push_error(snapshot.detail);quit(1);return
	snapshot.document.created_at=1700000000;snapshot.document.updated_at=1700000000;snapshot.document.metadata=SaveSnapshotBuilder.metadata_for(c.guild.state,"save_fixed_v1",1700000000,false)
	if not SaveValidator.validate(snapshot.document).ok():quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/fixtures"))
	FileAccess.open("res://tests/fixtures/save_v1.json",FileAccess.WRITE).store_string(JSON.stringify(snapshot.document,"  "))
	print("FIXED V1 FIXTURE WRITTEN");quit()
