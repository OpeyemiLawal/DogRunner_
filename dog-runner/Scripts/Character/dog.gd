extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const ACCEL = 15.0

# Lane movement
const LANE_WIDTH = 20.0
var lane_index := 0
var lane_change_speed := 10.0
var base_forward_position: Vector3

# Swipe detection
var swipe_start_pos := Vector2.ZERO
var swipe_end_pos := Vector2.ZERO
const SWIPE_THRESHOLD := 80.0   # minimum swipe distance

@onready var anim_player: AnimationPlayer = $AnimationPlayer

var forward_direction: Vector3 = Vector3.FORWARD
var processed_turn_areas = {}

func _ready():
	anim_player.play("Dog|Run")
	velocity = forward_direction * SPEED
	_update_rotation()
	base_forward_position = global_transform.origin


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept"):
		print("Jump pressed - on floor:", is_on_floor())
		if is_on_floor():
			_do_jump()

	_handle_lane_input()
	_handle_swipe_input()

	_apply_lane_movement(delta)

	# Always move forward
	var target_forward_velocity = forward_direction * SPEED
	velocity = velocity.move_toward(target_forward_velocity, ACCEL * delta)

	# Animation
	if velocity.length() > 0:
		if anim_player.current_animation != "Dog|Run":
			anim_player.play("Dog|Run")
	else:
		if anim_player.current_animation != "Dog|Idle":
			anim_player.play("Dog|Idle")

	move_and_slide()

	# Update base forward position (no drift)
	base_forward_position = global_transform.origin - (forward_direction.cross(Vector3.UP).normalized() * (lane_index * LANE_WIDTH))

	_update_rotation()
	_check_for_turns()



# ============================
# BUTTON LEFT/RIGHT LANE INPUT
# ============================

func _handle_lane_input():
	if Input.is_action_just_pressed("ui_left"):
		_change_lane(-1)

	if Input.is_action_just_pressed("ui_right"):
		_change_lane(1)



# ============================
# SWIPE CONTROL SYSTEM
# ============================

func _handle_swipe_input():
	# Touch or mouse press start
	if Input.is_action_just_pressed("click"):
		swipe_start_pos = get_viewport().get_mouse_position()

	# Touch or mouse release end
	if Input.is_action_just_released("click"):
		swipe_end_pos = get_viewport().get_mouse_position()
		_process_swipe()



func _process_swipe():
	var swipe_vector = swipe_end_pos - swipe_start_pos

	# Too small = not a swipe
	if swipe_vector.length() < SWIPE_THRESHOLD:
		return

	# Horizontal swipe
	if abs(swipe_vector.x) > abs(swipe_vector.y):
		if swipe_vector.x > 0:
			_change_lane(1)  # swipe right
		else:
			_change_lane(-1) # swipe left

	# Vertical swipe (UP)
	else:
		if swipe_vector.y < 0:
			if is_on_floor():
				_do_jump()



func _do_jump():
	velocity.y = JUMP_VELOCITY
	print("Jumping! velocity.y=", velocity.y)
	if anim_player.has_animation("Dog|Jump"):
		anim_player.play("Dog|Jump")



# ============================
# LANE MANAGEMENT
# ============================

func _change_lane(dir: int):
	var new_lane = lane_index + dir
	if new_lane >= -1 and new_lane <= 1:
		lane_index = new_lane



func _apply_lane_movement(delta):
	var right_direction = forward_direction.cross(Vector3.UP).normalized()

	var lane_target = base_forward_position + right_direction * (lane_index * LANE_WIDTH)

	global_transform.origin = global_transform.origin.lerp(lane_target, delta * lane_change_speed)



# ============================
# TURNING + AUTO CENTER
# ============================

func _handle_right_turn():
	forward_direction = forward_direction.rotated(Vector3.UP, -PI / 2.0).normalized()
	velocity = forward_direction * velocity.length()

	# Auto center lane after turn
	lane_index = 0
	base_forward_position = global_transform.origin



func _update_rotation():
	var angle = atan2(forward_direction.x, forward_direction.z)
	rotation.y = angle



# ============================
# TURN DETECTOR CHECK
# ============================

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
