extends SceneTree
func _initialize():call_deferred("run")
func run():
	var p12:=Phase12Tests.new();await p12.run(self)
	var p125:=Phase125Tests.new();await p125.run(self)
	print("SOURCE PRESENTATION RESULT: ",p12.checks+p125.checks," checks; ",p12.failures+p125.failures," failures")
	quit(1 if p12.failures+p125.failures else 0)
