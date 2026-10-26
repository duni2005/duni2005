class_name ConquestRewardButton
extends Button
var fraction: float=0
func _ready() -> void:
	ArenaUI.secondary(self);add_theme_font_size_override("font_size",11)
func _draw() -> void:
	if fraction<=0:return
	# Clockwise progress around the reward frame, as in the source conic border.
	var points:=PackedVector2Array([Vector2(size.x*.5,1)])
	for corner in [Vector3(size.x-6,6,-PI/2),Vector3(size.x-6,size.y-6,0),Vector3(6,size.y-6,PI/2),Vector3(6,6,PI)]:
		for i in range(9):points.append(Vector2(corner.x,corner.y)+Vector2.from_angle(corner.z+i*PI/16)*5)
	points.append(points[0]);var total: float=0
	for i in range(1,points.size()):total+=points[i-1].distance_to(points[i])
	var remaining: float=total*clampf(fraction,0,1)
	for i in range(1,points.size()):
		var segment: float=points[i-1].distance_to(points[i]);var to: Vector2=points[i-1].lerp(points[i],minf(1,remaining/maxf(.001,segment)))
		draw_line(points[i-1],to,Color("86e3a4"),2,true);remaining-=segment
		if remaining<=0:break
