extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var tests:=Phase105Tests.new();tests.run(self);quit(1 if tests.failures else 0)
