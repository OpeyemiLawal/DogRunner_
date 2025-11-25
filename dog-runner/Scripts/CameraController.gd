extends Camera3D

@onready var dog: CharacterBody3D = $".."

const BASE_OFFSET = Vector3(0, 4, -10)  # Behind and above the dog (relative to forward direction)
const SMOOTH_SPEED = 5.0  # How fast the camera follows

func _process(delta):
	if dog:
		# Get dog's forward direction to calculate offset
		# forward_direction is defined in dog.gd, so we can access it directly
		var forward_direction = dog.forward_direction
		
		# Calculate right direction for camera offset
		var right_direction = forward_direction.cross(Vector3.UP).normalized()
		var up_direction = Vector3.UP
		
		# Calculate camera offset relative to dog's forward direction
		# Camera should be behind and above the dog
		var camera_offset = -forward_direction * abs(BASE_OFFSET.z) + up_direction * BASE_OFFSET.y
		
		# Smoothly interpolate camera position
		var target_position = dog.global_position + camera_offset
		global_position = global_position.lerp(target_position, SMOOTH_SPEED * delta)
		
		# Make camera look at the dog
		look_at(dog.global_position, Vector3.UP)
 
