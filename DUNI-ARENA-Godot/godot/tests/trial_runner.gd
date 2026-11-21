extends SceneTree
func _initialize() -> void:call_deferred("go")
func go() -> void:
	var t := TrialTests.new();t.run(self);quit(1 if t.failures > 0 else 0)
