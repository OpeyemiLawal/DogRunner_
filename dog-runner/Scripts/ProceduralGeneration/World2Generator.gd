extends Node3D

# Corridor scenes to generate
@export var corridor_scene: PackedScene
@export var turn_corridor_scene: PackedScene  # For corridor4 (turn corridor)
@export var dog_character: CharacterBody3D

# Generation parameters
const MAX_CORRIDORS = 10
const SPAWN_DISTANCE = 90.0  # Spawn when player is about 20% through corridor for very smooth experience
const DESPAWN_DISTANCE = 150.0  # Increased to avoid premature removal
const CORRIDORS_AHEAD = 2  # Always keep 2 corridors ahead of the player
# Removed TURN_PROBABILITY - now using deterministic pattern

# State variables
var active_corridors: Array[Node3D] = []
var next_spawn_position: Vector3 = Vector3.ZERO
var next_end_position: Vector3 = Vector3.ZERO
var current_rotation: float = 0.0
var rng: RandomNumberGenerator
var player: CharacterBody3D
var spawn_counter: int = 0  # Track spawn pattern

func _ready():
	# Initialize random number generator
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Get reference to player
	if dog_character:
		player = dog_character
	else:
		player = get_node_or_null("player")
	
	# Start generation
	spawn_initial_corridors()

func _physics_process(delta):
	if not player:
		return
	
	# Debug player position (very infrequently)
	if Engine.get_frames_drawn() % 600 == 0:  # Print every 10 seconds (assuming 60 FPS)
		print("Player pos: ", player.global_position, " | Active corridors: ", active_corridors.size())
	
	# Check if we need to spawn new corridor
	# Get the first corridor's end position for spawning trigger
	var first_corridor_end_position = get_first_corridor_end_position()
	var player_distance_to_first = player.global_position.distance_to(first_corridor_end_position)
	
	# Spawn corridors to maintain CORRIDORS_AHEAD
	var corridors_needed = CORRIDORS_AHEAD
	if player_distance_to_first < SPAWN_DISTANCE and active_corridors.size() < MAX_CORRIDORS:
		spawn_next_corridor()
	
	# Clean up corridors that are too far behind
	cleanup_old_corridors()

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
	# Get the last corridor's end point
	var last_corridor = active_corridors[-1]
	var last_end_marker = last_corridor.get_node("EndPoint")
	
	if not last_end_marker:
		return
	
	# Get the world position of the last corridor's end point
	var last_end_world_pos = last_end_marker.global_position
	
	# Spawn corridor1 then corridor2, then repeat
	spawn_counter += 1
	var should_spawn_corridor2 = (spawn_counter % 2 == 0)  # Even numbers spawn corridor2
	var corridor_to_spawn = corridor_scene
	
	# Load corridor2 directly from file when needed
	if should_spawn_corridor2:
		var corridor2_scene = load("res://Scenes/Enviroment/World2/corridor2.tscn")
		if corridor2_scene:
			corridor_to_spawn = corridor2_scene
		else:
			print("ERROR: Could not load corridor2.tscn!")
	
	# Spawn new corridor
	var new_corridor = corridor_to_spawn.instantiate()
	add_child(new_corridor)
	
	# Debug: Show what was spawned for first few spawns
	if spawn_counter <= 4:
		print("Spawn ", spawn_counter, ": ", "CORRIDOR2" if should_spawn_corridor2 else "CORRIDOR1")
		print("Final position: ", new_corridor.global_position)
	
	# Get the new corridor's start and end points
	var new_start_marker = new_corridor.get_node("StartPoint")
	var new_end_marker = new_corridor.get_node("EndPoint")
	
	if new_start_marker and new_end_marker:
		# Position the new corridor at origin first to get marker positions
		new_corridor.global_position = Vector3.ZERO
		
		# Get the world positions of the markers
		var new_start_world_pos = new_start_marker.global_position
		var new_end_world_pos = new_end_marker.global_position
		
		# Calculate offset to align new corridor's start with last corridor's end
		var offset = last_end_world_pos - new_start_world_pos
		
		# Position the new corridor
		new_corridor.global_position = offset
		active_corridors.append(new_corridor)
		
		# Get final positions for straight corridor
		new_start_world_pos = new_start_marker.global_position
		new_end_world_pos = new_end_marker.global_position
		
		# Debug: Show what was spawned for first few spawns
		if spawn_counter <= 4:
			print("Spawn ", spawn_counter, ": ", "CORRIDOR2" if should_spawn_corridor2 else "CORRIDOR1")
			print("Final position: ", new_corridor.global_position)
			print("End point for next spawn: ", new_end_world_pos)
		
		# Update next spawn position
		next_spawn_position = new_end_world_pos
		next_end_position = next_spawn_position

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
