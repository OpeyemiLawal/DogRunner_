extends CharacterBody3D

var SPEED = 10.0
const ACCEL = 15.0

const LANE_WIDTH = 37.0
var lane_index := 0
var lane_change_speed := 10.0
var base_forward_position: Vector3

var swipe_start_pos := Vector2.ZERO
var swipe_end_pos := Vector2.ZERO
const SWIPE_THRESHOLD := 80.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer

var forward_direction: Vector3 = Vector3.FORWARD
var processed_turn_areas = {}
var health = 100
var hit_obstacles = {}

# Jump system
var vertical_velocity := 0.0
const GRAVITY := -30.0
const JUMP_FORCE := 15.0
const COYOTE_TIME := 0.12
var coyote_timer := 0.0
var is_jumping := false

# Coin system
var coins_collected := 0


func _ready():
	anim_player.play("Dog|Run")
	velocity = forward_direction * SPEED
	_update_rotation()
	base_forward_position = global_transform.origin
	
	# Add to player group for coin detection
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_handle_lane_input()
	_handle_swipe_input()

	_apply_lane_movement(delta)

	# Forward movement
	var target_forward_velocity = forward_direction * SPEED
	velocity.x = lerp(velocity.x, target_forward_velocity.x, ACCEL * delta)
	velocity.z = lerp(velocity.z, target_forward_velocity.z, ACCEL * delta)

	# Jump and gravity update
	_update_jump_physics(delta)

	_cleanup_hit_obstacles()
	_update_animation()
	_update_jump_animation()

	move_and_slide()

	base_forward_position = global_transform.origin - (forward_direction.cross(Vector3.UP).normalized() * (lane_index * LANE_WIDTH))

	_update_rotation()
	_check_for_turns()
	_check_obstacle_collisions()



# Animation handling
func _update_animation():
	if velocity.length() > 1.0:
		if anim_player.current_animation != "Dog|Run" and not anim_player.current_animation.begins_with("Dog|Jump"):
			anim_player.play("Dog|Run")
	else:
		if anim_player.current_animation != "Dog|Idle":
			anim_player.play("Dog|Idle")



# Lane input
func _handle_lane_input():
	if Input.is_action_just_pressed("ui_left"):
		_change_lane(-1)

	if Input.is_action_just_pressed("ui_right"):
		_change_lane(1)

	if Input.is_action_just_pressed("ui_accept"):
		_start_jump()



# Swipe input
func _handle_swipe_input():
	if Input.is_action_just_pressed("click"):
		swipe_start_pos = get_viewport().get_mouse_position()
	
	if Input.is_action_just_released("click"):
		swipe_end_pos = get_viewport().get_mouse_position()
		var swipe_vector = swipe_end_pos - swipe_start_pos
		
		if swipe_vector.length() > SWIPE_THRESHOLD:
			
			if abs(swipe_vector.x) > abs(swipe_vector.y):
				if swipe_vector.x > 0:
					_change_lane(1)
				else:
					_change_lane(-1)
			
			else:
				if swipe_vector.y < 0:
					_start_jump()



# Lane change
func _change_lane(dir: int):
	var new_lane = lane_index + dir
	if new_lane >= -1 and new_lane <= 1:
		lane_index = new_lane


func _apply_lane_movement(delta):
	var right_direction = forward_direction.cross(Vector3.UP).normalized()
	var lane_target = base_forward_position + right_direction * (lane_index * LANE_WIDTH)
	global_transform.origin = global_transform.origin.lerp(lane_target, delta * lane_change_speed)



# Jump system
func _start_jump():
	if coyote_timer > 0.0 and not is_jumping:
		is_jumping = true
		vertical_velocity = JUMP_FORCE
		
		if anim_player.has_animation("Dog|Jump"):
			anim_player.play("Dog|Jump")


func _update_jump_physics(delta):
	vertical_velocity += GRAVITY * delta
	velocity.y = vertical_velocity

	if not is_on_floor():
		coyote_timer -= delta
	else:
		if is_jumping:
			is_jumping = false
		coyote_timer = COYOTE_TIME

	if is_on_floor() and vertical_velocity < 0.0:
		vertical_velocity = 0.0


func _update_jump_animation():
	if is_on_floor():
		if anim_player.current_animation == "Dog|Jump":
			anim_player.play("Dog|Run")



# Turning
func _handle_right_turn():
	forward_direction = forward_direction.rotated(Vector3.UP, -PI / 2.0).normalized()
	velocity = forward_direction * velocity.length()

	lane_index = 0
	base_forward_position = global_transform.origin
	
	var world_gen = get_node_or_null("/root/WorldGenerator")
	if world_gen and world_gen.has_method("on_dog_detected_turn"):
		world_gen.on_dog_detected_turn()


func _update_rotation():
	var angle = atan2(forward_direction.x, forward_direction.z)
	rotation.y = angle



# Turn detection
func _check_for_turns():
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()

	var detection_shape = SphereShape3D.new()
	detection_shape.radius = 2.0

	query.shape = detection_shape
	query.transform = global_transform
	query.collide_with_areas = true

	var results = space_state.intersect_shape(query)
	for result in results:
		if result.has("collider"):
			var area = result.collider as Area3D
			if area and area.name == "TurnDetector":
				var area_id = area.get_instance_id()
				if not processed_turn_areas.has(area_id):
					_handle_right_turn()
					processed_turn_areas[area_id] = true
					break



# Obstacle collisions
func _check_obstacle_collisions():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("obstacle"):
			_handle_obstacle_collision(collider)


func _handle_obstacle_collision(obstacle):
	var obstacle_id = obstacle.get_instance_id()
	if not hit_obstacles.has(obstacle_id):
		health -= 1
		hit_obstacles[obstacle_id] = true
		
		# Play collision VFX
		_play_collision_vfx(obstacle)
		
		_handle_collision_feedback()


func _handle_collision_feedback():
	var knockback_direction = -forward_direction
	velocity = knockback_direction * SPEED * 0.5
	
	if anim_player.has_animation("Dog|Hit"):
		anim_player.play("Dog|Hit")
	else:
		anim_player.play("Dog|Run")


func _cleanup_hit_obstacles():
	var obstacles_to_remove = []
	for obstacle_id in hit_obstacles.keys():
		var obstacle = instance_from_id(obstacle_id)
		if not obstacle or not is_instance_valid(obstacle):
			obstacles_to_remove.append(obstacle_id)
	
	for obstacle_id in obstacles_to_remove:
		hit_obstacles.erase(obstacle_id)



func set_speed(new_speed: float):
	SPEED = new_speed
	velocity = forward_direction * SPEED

# Coin system methods
func add_coin():
	coins_collected += 1
	print("Coins collected: ", coins_collected)
	
	# Update HUD if available
	var world_gen = get_tree().get_first_node_in_group("world_generator")
	if world_gen and world_gen.has_method("update_coin_display"):
		world_gen.update_coin_display(coins_collected)

func get_coins() -> int:
	return coins_collected

# Collision VFX method
func _play_collision_vfx(obstacle):
	# Calculate impact direction (from obstacle to player)
	var impact_direction = (global_position - obstacle.global_position).normalized()
	
	# Create collision VFX at collision point
	var vfx_scene = preload("res://Scenes/VFX/ObstacleCollisionVFX.tscn")
	if vfx_scene:
		var vfx_instance = vfx_scene.instantiate()
		
		# Add VFX to the world (roadHolder is a good parent)
		var world_gen = get_tree().get_first_node_in_group("world_generator")
		if world_gen and world_gen.has_node("roadHolder"):
			world_gen.get_node("roadHolder").add_child(vfx_instance)
			vfx_instance.global_position = global_position
			
			# Play the VFX with impact direction
			if vfx_instance.has_method("play_collision_vfx"):
				vfx_instance.play_collision_vfx(impact_direction)
