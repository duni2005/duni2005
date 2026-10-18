class_name FormationState
extends RefCounted
## Last successfully started player deployment, not current/ending battle positions.
var entries: Array[DeploymentEntry] = []

func capture(deployment: Array[DeploymentEntry]) -> void:
	entries.clear()
	for entry in deployment:
		entries.append(entry.copy())

func snapshot() -> Array[DeploymentEntry]:
	var saved: Array[DeploymentEntry] = []
	for entry in entries:
		if entry != null:
			saved.append(entry.copy())
	return saved
