extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var suite:=Phase11Tests.new();await suite.run(self);quit(1 if suite.failures else 0)
