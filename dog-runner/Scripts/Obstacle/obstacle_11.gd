extends StaticBody3D

var move_front = true
var move_back = false
var speed = 5

func _process(delta: float) -> void:
	if move_front:
		position.x += speed * delta
	if move_back:
		move_front = false
		position.x -= speed * delta




func _on_wall_detector_area_entered(area: Area3D) -> void:
	if area.is_in_group("FrontDetection"):
		move_back = true
		move_front = false
	
	if area.is_in_group("BackDetection"):
		move_front = true
		move_back = false
