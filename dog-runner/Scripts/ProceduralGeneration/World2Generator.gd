extends Node3D


# Corridor scenes to generate
@export var corridor_scene: PackedScene
@export var turn_corridor_scene: PackedScene  # For corridor4 (turn corridor)
@export var dog_character: CharacterBody3D
@export var corridor2_scene: PackedScene

# Coin scene for spawning
@export var coin_scene: PackedScene






# Generation parameters
const MAX_CORRIDORS = 10
const SPAWN_DISTANCE = 90.0  # Spawn when player is about 20% through corridor for very smooth experience
const DESPAWN_DISTANCE = 150.0  # Increased to avoid premature removal
const CORRIDORS_AHEAD = 2  # Always keep 2 corridors ahead of the player
# Removed TURN_PROBABILITY - now using deterministic pattern

# AAA-STYLE COIN SPAWNING PARAMETERS
const COIN_SPAWN_CHANCE = 0.85  # 85% chance to spawn coins per corridor
const MIN_COINS_PER_CORRIDOR = 4
const MAX_COINS_PER_CORRIDOR = 10
const COIN_HEIGHT = 0.3  # Height above corridor floor (lowered)
const COIN_SCALE = 0.4 # Scale coins to 40% of original size

# Lane positions for coins (adjusted for corridor width and coordinate system)
const COIN_LEFT_LANE = -1.5
const COIN_MIDDLE_LANE = 0.0
const COIN_RIGHT_LANE = 1.5

# Corridor-specific coin patterns
const STRAIGHT_CORRIDOR_LENGTH = 90.0
const TURN_CORRIDOR_LENGTH = 90.0
const COIN_SPACING_MIN = 8.0
const COIN_SPACING_MAX = 15.0

# State variables
var active_corridors: Array[Node3D] = []
var next_spawn_position: Vector3 = Vector3.ZERO
var next_end_position: Vector3 = Vector3.ZERO
var current_rotation: float = 0.0
var rng: RandomNumberGenerator
var player: CharacterBody3D
var spawn_counter: int = 0  # Track spawn pattern
var active_coins: Array[Node3D] = []  # Track spawned coins

func _ready():
	# Initialize random number generator
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Get reference to player
	if dog_character:
		player = dog_character
	else:
		player = get_node_or_null("player")
	
	# Load coin scene if not assigned
	if not coin_scene:
		_load_coin_scene()

	# Start generation
	spawn_initial_corridors()

func _physics_process(delta):
	if not player:
		return
	
	# Check if we need to spawn new corridor
	var first_corridor_end_position = get_first_corridor_end_position()
	var player_distance_to_first = player.global_position.distance_to(first_corridor_end_position)
	
	# Spawn corridors to maintain CORRIDORS_AHEAD
	if player_distance_to_first < SPAWN_DISTANCE and active_corridors.size() < MAX_CORRIDORS:
		spawn_next_corridor()
	
	# Clean up old corridors
	cleanup_old_corridors()
	
	# Clean up old coins
	cleanup_old_coins()

func spawn_initial_corridors():
	# Spawn the first corridor
	spawn_initial_corridor()
	
	# Spawn additional corridors to have CORRIDORS_AHEAD ready
	for i in range(1, CORRIDORS_AHEAD):
		spawn_next_corridor()

func spawn_initial_corridor():
	# Spawn the first corridor at origin
	var corridor = corridor_scene.instantiate()
	add_child(corridor)
	
	# Get the start and end points first (before positioning)
	var start_marker = corridor.get_node("StartPoint")
	var end_marker = corridor.get_node("EndPoint")
	
	if start_marker and end_marker:
		# Get the local positions of markers
		var start_local_pos = start_marker.position
		var end_local_pos = end_marker.position
		
		# Position the corridor at origin first
		corridor.global_position = Vector3.ZERO
		active_corridors.append(corridor)
		
		# Now get the actual world positions of the markers
		var start_world_pos = start_marker.global_position
		var end_world_pos = end_marker.global_position
		
		# Calculate offset to move start point to origin
		var offset = -start_world_pos
		
		# Apply the offset
		corridor.global_position = offset
		
		# Recalculate world positions after offset
		start_world_pos = start_marker.global_position
		end_world_pos = end_marker.global_position
		
		# Update next spawn position
		next_spawn_position = end_world_pos
		next_end_position = next_spawn_position
		
		
		# Position player at the start of the first corridor
		if player:
			player.global_position = Vector3(0, 1.0, 1.0)  # Start near the beginning, facing +Z direction
			# Make sure player is facing forward (positive Z direction)
			player.rotation_degrees = Vector3(0, 0, 0)
			# IMPORTANT: Set forward_direction to positive Z (Vector3.BACK in Godot terms)
			player.forward_direction = Vector3.BACK  # Vector3.BACK is (0, 0, 1) in Godot
			# Also update the initial velocity
			player.velocity = player.forward_direction * 10.0

func spawn_next_corridor():
	if not player:
		return
	
	var last_corridor = active_corridors[-1]
	var last_end_marker = last_corridor.get_node("EndPoint")
	if not last_end_marker:
		return

	var last_end_world_pos = last_end_marker.global_position
	spawn_counter += 1

	# Pick corridor to spawn
	var corridor_to_spawn: PackedScene
	var is_turn_corridor = false
	if spawn_counter == 1:
		corridor_to_spawn = corridor2_scene
	else:
		corridor_to_spawn = corridor_scene
		is_turn_corridor = (spawn_counter >= 2)  # All corridor1 instances after first are turns

	var new_corridor = corridor_to_spawn.instantiate()
	add_child(new_corridor)

	# ROTATION LOGIC - rotate corridor1 once and keep same rotation for all subsequent corridor1
	if spawn_counter >= 2:
		new_corridor.rotation_degrees.y -= 90
		current_rotation -= deg_to_rad(90)

	# POSITIONING
	var new_start_marker = new_corridor.get_node("StartPoint")
	var new_end_marker = new_corridor.get_node("EndPoint")

	new_corridor.global_position = Vector3.ZERO
	var new_start_world_pos = new_start_marker.global_position
	var offset = last_end_world_pos - new_start_world_pos
	new_corridor.global_position = offset

	# Recalculate end position after positioning
	var new_end_world_pos = new_end_marker.global_position
	next_spawn_position = new_end_world_pos

	active_corridors.append(new_corridor)
	
	# Spawn coins for this corridor
	_spawn_coins_for_corridor(new_corridor, is_turn_corridor)
	



func cleanup_old_corridors():
	if not player:
		return
		
	var corridors_to_remove: Array[Node3D] = []
	
	for corridor in active_corridors:
		# Get the start marker of this corridor
		var start_marker = corridor.get_node("StartPoint")
		if start_marker:
			var distance = player.global_position.distance_to(start_marker.global_position)
			# Only remove if player has passed this corridor's start by a good margin
			if distance > DESPAWN_DISTANCE:
				corridors_to_remove.append(corridor)
		else:
			# Fallback to corridor position if no start marker
			var distance = player.global_position.distance_to(corridor.global_position)
			if distance > DESPAWN_DISTANCE:
				corridors_to_remove.append(corridor)
	
	for corridor in corridors_to_remove:
		active_corridors.erase(corridor)
		corridor.queue_free()

func get_first_corridor_end_position():
	if active_corridors.size() > 0:
		var first_corridor = active_corridors[0]
		var end_marker = first_corridor.get_node("EndPoint")
		if end_marker:
			return end_marker.global_position
	return Vector3.ZERO

func get_current_end_point():
	if active_corridors.size() > 0:
		var last_corridor = active_corridors[-1]
		var end_marker = last_corridor.get_node("EndPoint")
		if end_marker:
			return end_marker.global_position
	return Vector3.ZERO

# ============================
# AAA-STYLE COIN SPAWNING SYSTEM
# ============================

func _load_coin_scene():
	var coin_file_path = "res://Scenes/Collectiables/coin.tscn"
	if ResourceLoader.exists(coin_file_path):
		coin_scene = load(coin_file_path) as PackedScene
		print("Loaded coin scene successfully")
	else:
		print("ERROR: Could not load coin scene at: ", coin_file_path)

func _spawn_coins_for_corridor(corridor: Node3D, is_turn: bool):
	# Check if we should spawn coins
	var coin_roll = rng.randf()
	if coin_roll > COIN_SPAWN_CHANCE:
		return
	
	if not coin_scene:
		print("ERROR: No coin scene available for spawning!")
		return
	
	# Determine number of coins based on corridor type
	var num_coins = rng.randi_range(MIN_COINS_PER_CORRIDOR, MAX_COINS_PER_CORRIDOR)
	
	# Generate coin pattern based on corridor type
	if is_turn:
		_spawn_turn_corridor_coins(corridor, num_coins)
	else:
		_spawn_straight_corridor_coins(corridor, num_coins)

func _spawn_straight_corridor_coins(corridor: Node3D, num_coins: int):
	# Create evenly spaced coin lines in straight corridors
	var lanes = [COIN_RIGHT_LANE, COIN_MIDDLE_LANE, COIN_LEFT_LANE]  # Reordered: right, middle, left
	var used_positions = []
	
	for i in range(num_coins):
		var lane = lanes[rng.randi() % lanes.size()]
		var forward_offset = rng.randf_range(10.0, 80.0)
		
		# Check minimum spacing
		var test_pos = Vector3(lane, COIN_HEIGHT, forward_offset)
		var position_valid = true
		
		for used_pos in used_positions:
			if test_pos.distance_to(used_pos) < COIN_SPACING_MIN:
				position_valid = false
				break
		
		if position_valid:
			_create_coin_at_position(corridor, test_pos)
			used_positions.append(test_pos)

func _spawn_turn_corridor_coins(corridor: Node3D, num_coins: int):
	# Create curved coin patterns for turning corridors
	var turn_radius = 8.0
	var angle_step = 90.0 / num_coins  # 90-degree turn distributed across coins
	
	for i in range(num_coins):
		var angle = i * angle_step
		var radius = turn_radius + rng.randf_range(-2.0, 2.0)  # Add some variation
		
		# Calculate position on the turn arc
		var x = radius * cos(deg_to_rad(angle))
		var z = radius * sin(deg_to_rad(angle))
		
		var coin_pos = Vector3(x, COIN_HEIGHT, z)
		_create_coin_at_position(corridor, coin_pos)

func _create_coin_at_position(corridor: Node3D, local_position: Vector3):
	var coin_instance = coin_scene.instantiate()
	corridor.add_child(coin_instance)
	coin_instance.position = local_position
	coin_instance.rotation_degrees.y = rng.randf() * 360.0  # Random rotation for visual variety
	coin_instance.scale = Vector3(COIN_SCALE, COIN_SCALE, COIN_SCALE)  # Scale down the coin
	
	# Track the coin
	active_coins.append(coin_instance)

func cleanup_old_coins():
	if active_coins.is_empty():
		return
	
	if not player:
		return
		
	var coins_to_remove: Array[Node3D] = []
	
	# First pass: identify coins to remove
	for coin in active_coins:
		if not is_instance_valid(coin):
			continue  # Skip invalid coins
			
		var coin_to_player = coin.global_position - player.global_position
		var distance_behind = coin_to_player.length()
		
		# Check if coin is behind the player
		var is_behind = coin_to_player.dot(player.forward_direction if player else Vector3.FORWARD) < 0
		
		# Mark coin for removal if it's behind and too far away
		if is_behind and distance_behind > DESPAWN_DISTANCE:
			coins_to_remove.append(coin)
	
	# Second pass: remove marked coins
	for coin in coins_to_remove:
		if is_instance_valid(coin):
			coin.queue_free()
			active_coins.erase(coin)
	
	# Third pass: clean up any remaining invalid coins
	var valid_coins: Array[Node3D] = []
	for coin in active_coins:
		if is_instance_valid(coin):
			valid_coins.append(coin)
	
	active_coins = valid_coins
