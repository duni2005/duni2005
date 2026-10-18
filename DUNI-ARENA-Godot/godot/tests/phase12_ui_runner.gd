extends SceneTree
func _initialize():call_deferred("run")
func run():
 var suite:=Phase12Tests.new();await suite.run(self);quit(1 if suite.failures else 0)
