extends Node3D

# Corridor scenes to generate
@export var corridor_scene: PackedScene
@export var turn_corridor_scene: PackedScene  # For corridor4 (turn corridor)
@export var dog_character: CharacterBody3D
@export var corridor2_scene: PackedScene

# Coin spawning variables
@export var coin_scene: PackedScene
const COIN_SPAWN_CHANCE = 0.8  # 80% chance to spawn coins per corridor (same as World 1)
const MAX_COINS_PER_CORRIDOR = 8  # Maximum 8 coins per corridor (same as World 1)

# Coin lane positions - exactly matching World 1
const COIN_LEFT_OFFSET = -6.0   # Same as World 1
const COIN_MIDDLE_OFFSET = 0.0  # Same as World 1
const COIN_RIGHT_OFFSET = 6.0    # Same as World 1

# Professional zig-zag patterns
const ZIG_ZAG_PATTERNS = [
	[0, 1, 0, -1, 0],           # Middle-Right-Middle-Left-Middle
	[-1, 0, 1, 0, -1],          # Left-Middle-Right-Middle-Left
	[1, 0, -1, 0, 1],           # Right-Middle-Left-Middle-Right
	[0, -1, 1, -1, 0],          # Middle-Left-Right-Left-Middle
	[1, 1, 0, -1, -1],          # Right-Right-Middle-Left-Left
	[-1, -1, 0, 1, 1],          # Left-Left-Middle-Right-Right
	[0, 0, 1, 0, 0],            # Middle-Middle-Right-Middle-Middle
	[0, 0, -1, 0, 0],           # Middle-Middle-Left-Middle-Middle
]

# Generation parameters
const MAX_CORRIDORS = 10
const SPAWN_DISTANCE = 90.0  # Spawn when player is about 20% through corridor for very smooth experience
const DESPAWN_DISTANCE = 150.0  # Increased to avoid premature removal
const CORRIDORS_AHEAD = 2  # Always keep 2 corridors ahead of the player
# Removed TURN_PROBABILITY - now using deterministic pattern

# State variables
var active_corridors: Array[Node3D] = []
var active_collectibles: Array[Node3D] = []
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
	
	# Debug player position and lane changing
	if Engine.get_frames_drawn() % 120 == 0:  # Print every 2 seconds (assuming 60 FPS)
		print("=== DEBUG INFO ===")
		print("Player pos: ", player.global_position)
		print("Player forward: ", player.forward_direction if player.has_method("get") else "N/A")
		print("Active corridors: ", active_corridors.size())
		print("Active coins: ", active_collectibles.size())
		
		# Show coin positions
		for i in range(min(3, active_collectibles.size())):
			var coin = active_collectibles[i]
			if is_instance_valid(coin):
				print("Coin ", i+1, " pos: ", coin.global_position)
		print("================")
	
	# Check if we need to spawn new corridor
	# Get the first corridor's end position for spawning trigger
	var first_corridor_end_position = get_first_corridor_end_position()
	var player_distance_to_first = player.global_position.distance_to(first_corridor_end_position)
	
	# Spawn corridors to maintain CORRIDORS_AHEAD
	var corridors_needed = CORRIDORS_AHEAD
	if player_distance_to_first < SPAWN_DISTANCE and active_corridors.size() < MAX_CORRIDORS:
		spawn_next_corridor()
	
	# Clean up old corridors and coins
	cleanup_old_corridors()
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
		
		# Spawn coins on this corridor
		_spawn_coins_on_corridor(corridor.global_position)
		
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
	
	print("=== SPAWNING NEXT CORRIDOR ===")
	print("Current spawn_counter: ", spawn_counter)
	
	var last_corridor = active_corridors[-1]
	var last_end_marker = last_corridor.get_node("EndPoint")
	if not last_end_marker:
		return

	var last_end_world_pos = last_end_marker.global_position
	spawn_counter += 1

	# Pick corridor to spawn
	var corridor_to_spawn: PackedScene
	if spawn_counter == 1:
		corridor_to_spawn = corridor2_scene           # corridor 2 (only first spawn)
		print("Spawning corridor2 (spawn_counter=1)")
	else:
		corridor_to_spawn = corridor_scene            # corridor 1 (all other spawns)
		print("Spawning corridor1 (spawn_counter=", spawn_counter, ")")

	var new_corridor = corridor_to_spawn.instantiate()
	add_child(new_corridor)

	# ROTATION LOGIC - rotate corridor1 once and keep same rotation for all后续 corridor1
	if spawn_counter >= 2:  # All corridor1 spawns after corridor2
		new_corridor.rotation_degrees.y -= 90
		current_rotation -= deg_to_rad(90)
		print("Applied -90 degree rotation, current_rotation: ", current_rotation, " (", rad_to_deg(current_rotation), " degrees)")

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

	print("Corridor positioned at: ", new_corridor.global_position)
	print("Next spawn position updated to: ", next_spawn_position)

	active_corridors.append(new_corridor)
	
	# Spawn coins on this corridor
	print("About to spawn coins on corridor ", spawn_counter)
	_spawn_coins_on_corridor(new_corridor.global_position)
	
	print("Corridor added. Active corridors: ", active_corridors.size())
	print("==========================")


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

func _spawn_coins_on_corridor(corridor_position: Vector3):
	if not coin_scene:
		print("ERROR: No coin scene assigned!")
		return
		
	print("=== COIN SPAWN DEBUG ===")
	print("Spawn counter: ", spawn_counter)
	print("Active corridors: ", active_corridors.size())
	print("Coin scene valid: ", coin_scene != null)
	
	var coin_roll = rng.randf()
	print("Coin spawn roll: ", coin_roll, " (need < ", COIN_SPAWN_CHANCE, " to spawn)")
	
	if coin_roll < COIN_SPAWN_CHANCE:
		# Choose a professional zig-zag pattern
		var pattern_index = rng.randi() % ZIG_ZAG_PATTERNS.size()
		var pattern = ZIG_ZAG_PATTERNS[pattern_index]
		var num_coins = pattern.size()
		
		print("Spawning ", num_coins, " coins with ZIG-ZAG pattern ", pattern_index, ": ", pattern)
		print("Pattern: ", _get_pattern_description(pattern))
		
		for i in range(num_coins):
			var lane = pattern[i]  # Use pattern instead of random
			var forward_offset = 20.0 + i * 25.0  # More spread out - start at 20, 25 units apart
			
			# Use specific coin lane offsets
			var lane_offset = 0.0
			var lane_name = ""
			match lane:
				-1:  # Left lane
					lane_offset = COIN_LEFT_OFFSET
					lane_name = "LEFT"
				0:   # Middle lane
					lane_offset = COIN_MIDDLE_OFFSET
					lane_name = "MIDDLE"
				1:   # Right lane
					lane_offset = COIN_RIGHT_OFFSET
					lane_name = "RIGHT"
			
			# Create coin instance
			var coin_instance = coin_scene.instantiate()
			
			# Calculate world position based on current rotation
			var forward_dir = Vector3.FORWARD.rotated(Vector3.UP, current_rotation)
			var right_dir = forward_dir.cross(Vector3.UP).normalized()
			
			# Start with corridor position but adjust height to player level (reduced)
			var base_position = corridor_position
			base_position.y = 0.5  # Reduced from 1.0 for better visual height
			
			# Apply rotation-aware positioning
			var world_pos = base_position + forward_dir * forward_offset + right_dir * lane_offset
			
			print("Coin ", i+1, ": lane=", lane_name, " forward_offset=", forward_offset, " lane_offset=", lane_offset)
			print("Coin ", i+1, ": corridor_pos=", corridor_position, " base_pos=", base_position)
			print("Coin ", i+1, ": current_rotation=", current_rotation, " (", rad_to_deg(current_rotation), " degrees)")
			print("Coin ", i+1, ": forward_dir=", forward_dir, " right_dir=", right_dir)
			print("Coin ", i+1, ": calculated world_pos=", world_pos)
			
			# Add to scene and set position
			add_child(coin_instance)
			coin_instance.global_position = world_pos
			coin_instance.global_rotation.y = current_rotation
			
			print("Coin ", i+1, ": final position=", coin_instance.global_position)
			
			# Track the coin
			active_collectibles.append(coin_instance)
		
		print("Total coins after spawn: ", active_collectibles.size())
		print("=======================")
	else:
		print("No coins spawned this corridor")
		print("=======================")

func _get_pattern_description(pattern: Array) -> String:
	var description = ""
	for i in range(pattern.size()):
		var lane = pattern[i]
		var lane_name = ""
		match lane:
			-1: lane_name = "L"
			0: lane_name = "M"
			1: lane_name = "R"
		
		if i == 0:
			description = lane_name
		else:
			description += "-" + lane_name
	
	return description

func cleanup_old_coins():
	if not player:
		return
	
	# Use a simple while loop to safely remove invalid coins
	var i = 0
	while i < active_collectibles.size():
		var coin = active_collectibles[i]
		
		# Remove invalid or distant coins
		if not coin or not is_instance_valid(coin):
			active_collectibles.remove_at(i)
			continue
			
		var distance = player.global_position.distance_to(coin.global_position)
		if distance > DESPAWN_DISTANCE:
			coin.queue_free()
			active_collectibles.remove_at(i)
			continue
			
		i += 1
