class_name BattleResultBanner
extends Control
var kind: String="victory"
var age: float=0
func _ready() -> void:
	custom_minimum_size.y=76;mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func reveal(value: String) -> void:kind=value;age=0;queue_redraw()
func _process(dt: float) -> void:age+=dt;queue_redraw()
func _draw() -> void:
	var c:=Color("f3d48e") if kind=="victory" else Color("e3ba8a") if kind=="retreat" else Color("dc8d7c")
	var at:=Vector2(size.x*.5,38);var radius: float=25+4*exp(-age*5)
	for side in [-1,1]:
		for i in range(4):
			var p:=at+Vector2(side*(34+i*8),i*3-10)
			draw_line(p,p+Vector2(side*11,-8 if kind=="victory" else 8),Color(c,.7-i*.13),3,true)
	draw_circle(at,radius+7,Color(c,.08));draw_arc(at,radius+3,-PI,PI,48,Color(c,.55),1.5,true)
	ArenaIcon.draw(self,at,"crown" if kind=="victory" else "flag" if kind=="retreat" else "skull",43,Color.WHITE)
	if age<1.3:
		for i in range(12):
			var direction: Vector2=Vector2.from_angle(i*TAU/12);var p: Vector2=at+direction*(25+age*(25+i%3*10))
			draw_line(p,p-direction*4,Color(c,(1-age/1.3)*.8),2,true)
