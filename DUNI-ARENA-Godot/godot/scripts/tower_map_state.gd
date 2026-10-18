class_name TowerMapState
extends RefCounted
var floors: Array[FloorState] = []
var rooms: Dictionary = {} # stable depth:lane -> RoomState
func get_room(id: String) -> RoomState:
	return rooms.get(id)
