extends Node3D

# Road chunk scenes
@export var road_chunk_scenes: Array[PackedScene] = []
@export var turn_road_scene: PackedScene
@export var dog_character: CharacterBody3D

# HUD reference
@onready var player_hud: Control = $PlayerHUD

# Obstacle scenes for AAA-style endless runner
@export var obstacle_scenes: Array[PackedScene] = []
@export var coin_scenes: Array[PackedScene] = []
@export var powerup_scenes: Array[PackedScene] = []
@onready var missonUI: Control = $Misson

# Road generation parameters
const ROAD_LENGTH = 85.0
const STRAIGHT_ROAD_LENGTH = 450.0
const SPAWN_DISTANCE = 200.0
const DESPAWN_DISTANCE = 150.0
const MAX_ROADS = 6

# State variables
var next_spawn_position: Vector3 = Vector3.ZERO
var current_direction: Vector3 = Vector3.FORWARD
var current_rotation: float = 0.0
var active_roads: Array[Node3D] = []
var active_obstacles: Array[Node3D] = []
var active_collectibles: Array[Node3D] = []
var rng: RandomNumberGenerator
var mission_timer: float = 0.0
const MISSION_DISPLAY_TIME = 3.5
var mission_ui_alpha: float = 0.0
var mission_ui_state: String = "hidden"  # "hidden", "fading_in", "visible", "fading_out"
const FADE_DURATION = 0.8
var is_game_paused: bool = false
var victory_coins_required: int = 20
var current_coins_collected: int = 0

# AAA-style obstacle parameters
const LANE_WIDTH = 37.0  # Updated to match dog lane width
const OBSTACLE_SPAWN_CHANCE = 1.0  # 100% chance to spawn obstacles per road
const COIN_SPAWN_CHANCE = 0.8  # 80% chance to spawn coins per road
const POWERUP_SPAWN_CHANCE = 0.1  # 10% chance to spawn powerups per road
const MAX_OBSTACLES_PER_ROAD = 15  # Increased from 8 to 15
const MAX_COINS_PER_ROAD = 8

# Lane spacing adjustments - using requested positions
const MIDDLE_LANE_OFFSET = 0.0

# Obstacle1 lane positions
const OBSTACLE1_LEFT_OFFSET = -5.8
const OBSTACLE1_MIDDLE_OFFSET = 0.0
const OBSTACLE1_RIGHT_OFFSET = 5.5

# Obstacle2 lane positions  
const OBSTACLE2_LEFT_OFFSET = -6.8
const OBSTACLE2_MIDDLE_OFFSET = -1.041  # Updated to 1.041
const OBSTACLE2_RIGHT_OFFSET = 5.2

# Obstacle3 lane positions (only left and right lanes)
const OBSTACLE3_LEFT_OFFSET = -1.5
const OBSTACLE3_RIGHT_OFFSET = 3.5
# Note: Obstacle3 does NOT spawn in middle lane

# Obstacle4 lane positions (only middle lane)
const OBSTACLE4_MIDDLE_OFFSET = 0.0  # Changed from 0.5 to 0.0
# Note: Obstacle4 does NOT spawn in left or right lanes

# Obstacle5 lane positions (only left and right lanes)
const OBSTACLE5_LEFT_OFFSET = -3.8
const OBSTACLE5_RIGHT_OFFSET = 3.8
# Note: Obstacle5 does NOT spawn in middle lane

# Obstacle6 lane positions (can spawn in all lanes)
const OBSTACLE6_LEFT_OFFSET = -6.9
const OBSTACLE6_MIDDLE_OFFSET = -1.3
const OBSTACLE6_RIGHT_OFFSET = 4.5

# Obstacle7 lane positions (can spawn in all lanes)
const OBSTACLE7_LEFT_OFFSET = -4.5
const OBSTACLE7_MIDDLE_OFFSET = 0  # 0.0 + 2.4 = 2.4
const OBSTACLE7_RIGHT_OFFSET = 5.5 # 4.5 + 2.4 = 6.9

# Obstacle8 lane positions (can spawn in all lanes)
const OBSTACLE8_LEFT_OFFSET = -6.9
const OBSTACLE8_MIDDLE_OFFSET = -0.8
const OBSTACLE8_RIGHT_OFFSET = 4.5

# Obstacle9 lane positions (only left and right lanes)
const OBSTACLE9_LEFT_OFFSET = -5.0
const OBSTACLE9_RIGHT_OFFSET = 6.0
# Note: Obstacle9 does NOT spawn in middle lane

# Obstacle10 lane positions (only left and middle lanes)
const OBSTACLE10_LEFT_OFFSET = -5.0
const OBSTACLE10_MIDDLE_OFFSET = 0.0
# Note: Obstacle10 does NOT spawn in right lane

# Obstacle11 lane positions (only left lane)
const OBSTACLE11_LEFT_OFFSET = -6.0
# Note: Obstacle11 does NOT spawn in middle or right lanes

# Obstacle12 lane positions (only right lane)
const OBSTACLE12_RIGHT_OFFSET = 7.0
# Note: Obstacle12 does NOT spawn in left or middle lanes

# Coin lane positions - closer to center than obstacles
const COIN_LEFT_OFFSET = -6.0
const COIN_MIDDLE_OFFSET = 0.0
const COIN_RIGHT_OFFSET = 6.0

# Procedural difficulty scaling
var difficulty_multiplier: float = 1.0
var roads_spawned: int = 0
var game_time: float = 0.0  # Track total game time
const DIFFICULTY_INCREASE_RATE = 0.15  # Increased from 0.1 to 0.15
var base_obstacles: int = 2  # Made variable instead of constant
const TIME_BASED_INCREASE_INTERVAL = 20.0  # Increase difficulty every 20 seconds
const TIME_BASED_INCREASE_AMOUNT = 1  # Add 1 more obstacle every 20 seconds

func _ready():
	add_to_group("world_generator")
	
	# Find the dog character
	dog_character = get_tree().get_first_node_in_group("player")
	if not dog_character:
		return
	
	# Initialize HUD
	if player_hud:
		player_hud.reset_hud()
	
	# Hide mission screen initially
	if has_node("MissonScreen"):
		$MissonScreen.visible = false
		# Enable mission screen to process while paused
		$MissonScreen.process_mode = Node.PROCESS_MODE_ALWAYS
		
		# Enable close button to process while paused
		var close_button = $MissonScreen.get_node_or_null("CloseMisson")
		if close_button:
			close_button.process_mode = Node.PROCESS_MODE_ALWAYS
			# Remove white outline
			close_button.focus_mode = Control.FOCUS_NONE
	
	# Hide victory screen initially
	if has_node("Victory"):
		$Victory.visible = false
		# Enable victory screen to process while paused
		$Victory.process_mode = Node.PROCESS_MODE_ALWAYS
		
		# Enable victory close button to process while paused
		var victory_close_button = $Victory.get_node_or_null("CloseVictory")
		if victory_close_button:
			victory_close_button.process_mode = Node.PROCESS_MODE_ALWAYS
			# Remove white outline
			victory_close_button.focus_mode = Control.FOCUS_NONE
	
	# Remove white outline from all navbar buttons
	if has_node("NavBar"):
		var navbar = $NavBar
		for child in navbar.get_children():
			if child is Button:
				child.focus_mode = Control.FOCUS_NONE
	
	# Create a separate input handler for paused state
	var input_handler = Control.new()
	input_handler.name = "PauseInputHandler"
	input_handler.process_mode = Node.PROCESS_MODE_ALWAYS
	input_handler.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_handler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(input_handler)
	
	# Show mission UI at start with professional fade-in
	if missonUI:
		missonUI.visible = true
		mission_timer = 0.0
		mission_ui_state = "fading_in"
		mission_ui_alpha = 0.0
		_set_mission_ui_alpha(0.0)
	
	# Load scenes
	_load_road_scenes()
	_load_obstacle_scenes()
	
	# Initialize RNG
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if obstacle_scenes.is_empty():
		_load_obstacle_scenes()
	
	# Spawn initial roads
	_spawn_initial_roads()

func _process(delta):
	# Only process game logic if not paused
	if not is_game_paused:
		# Track game time for procedural difficulty
		game_time += delta
		
		# Update difficulty based on time
		_update_time_based_difficulty()
		
		# Handle professional mission UI animations
		if missonUI and missonUI.visible:
			_update_mission_ui(delta)
		
		if not dog_character:
			return
		
		# Check if we need to spawn more roads (this also handles removal)
		_check_and_spawn_roads()

#func _input(event):
	# Check for ESC key to close mission screen (works even when paused)
	#if event.is_action_pressed("ui_cancel") and is_game_paused:
		#print("ESC pressed - closing mission screen")
		#_hide_mission_screen()

func _update_time_based_difficulty():
	# Increase difficulty every 20 seconds
	var time_intervals = int(game_time / TIME_BASED_INCREASE_INTERVAL)
	var additional_obstacles = time_intervals * TIME_BASED_INCREASE_AMOUNT
	
	# Update base obstacles based on time
	base_obstacles = 2 + additional_obstacles
	
	# Increase player speed every 20 seconds by 2
	if dog_character and dog_character.has_method("set_speed"):
		var speed_increase = time_intervals * 2.0
		var new_speed = 10.0 + speed_increase  # Base speed 10 + increase
		dog_character.set_speed(new_speed)
	
func _load_road_scenes():
	# Only load road1.tscn for now
	var file_path = "res://Scenes/Chunks/road1.tscn"
	if ResourceLoader.exists(file_path):
		var scene = load(file_path) as PackedScene
		if scene:
			road_chunk_scenes.append(scene)
		

func _load_obstacle_scenes():
	# Load obstacle1, obstacle2, obstacle3, obstacle4, obstacle5, obstacle6, obstacle7, obstacle8, obstacle9, obstacle10, obstacle11, and obstacle12 scenes
	var obstacle_files = ["obstacle1.tscn", "obstacle2.tscn", "obstacle3.tscn", "obstacle4.tscn", "obstacle5.tscn", "obstacle6.tscn", "obstacle7.tscn", "obstacle8.tscn", "obstacle9.tscn", "obstacle10.tscn", "obstacle11.tscn", "obstacle12.tscn"]
	
	for file_name in obstacle_files:
		var file_path = "res://Scenes/Obstacle/" + file_name
		if ResourceLoader.exists(file_path):
			var scene = load(file_path) as PackedScene
			if scene:
				obstacle_scenes.append(scene)
	
	# Load coin scenes
	var coin_file_path = "res://Scenes/Collectiables/coin.tscn"
	if ResourceLoader.exists(coin_file_path):
		var coin_scene = load(coin_file_path) as PackedScene
		if coin_scene:
			coin_scenes.append(coin_scene)
				
func _spawn_initial_roads():
	
	# Spawn only one road at origin
	var initial_road = _spawn_road_at_position(Vector3.ZERO, false)
		
	# Spawn a few more roads to get started
	for i in range(2):
		if active_roads.size() > 0:
			_spawn_road_at_position(next_spawn_position, false)

func _spawn_road_at_position(position: Vector3, is_turn: bool = false, is_long_straight: bool = false):
	if road_chunk_scenes.is_empty():
		return
	
	# Always use straight road scene
	var road_scene = road_chunk_scenes[0]
	var road_type = "STRAIGHT"
	var road_length = ROAD_LENGTH
	
	var road_chunk = road_scene.instantiate()
	
	if road_chunk:
		# Add to scene tree
		$roadHolder.add_child(road_chunk)
		road_chunk.global_position = position
		road_chunk.rotation.y = current_rotation
		
		active_roads.append(road_chunk)
		
		# Update difficulty and roads counter
		roads_spawned += 1
		_update_difficulty()
		
		# Spawn AAA-style obstacles and collectibles on this road
		_spawn_road_content(road_chunk, position)
		
		# Update next spawn position
		next_spawn_position = position + current_direction * road_length
		
		return road_chunk
	else:
		return null

func _update_difficulty():
	# Increase difficulty every 10 roads
	if roads_spawned % 10 == 0:
		difficulty_multiplier += DIFFICULTY_INCREASE_RATE
		
	# Cap maximum difficulty to prevent impossible scenarios
	difficulty_multiplier = min(difficulty_multiplier, 3.0)
		
	


func _check_and_spawn_roads():
	if active_roads.is_empty():
		return
	
	var player_pos = dog_character.global_position
	var distance_to_next = player_pos.distance_to(next_spawn_position)
	
	# Spawn new road when player gets close to next spawn position
	if distance_to_next < SPAWN_DISTANCE and active_roads.size() < MAX_ROADS:
		# Always spawn straight roads
		_spawn_road_at_position(next_spawn_position, false)
	
	# Remove roads that are too far behind
	_check_and_remove_roads()
	
	# Also remove obstacles that are too far behind
	_check_and_remove_obstacles()
	
	# Also remove collectibles that are too far behind
	_check_and_remove_collectibles()

func _check_and_remove_roads():
	if active_roads.is_empty():
		return
	
	var player_pos = dog_character.global_position
	var player_forward = dog_character.forward_direction if dog_character else Vector3.FORWARD
	var roads_to_remove = []
	
	# Check if any road is too far behind the player
	for road in active_roads:
		var road_to_player = road.global_position - player_pos
		var distance_behind = road_to_player.length()
		
		# Check if road is behind the player (dot product < 0)
		var is_behind = road_to_player.dot(player_forward) < 0
		
		# Remove road if it's behind and too far away
		if is_behind and distance_behind > DESPAWN_DISTANCE:
			roads_to_remove.append(road)
			
	# Remove marked roads
	for road in roads_to_remove:
		_remove_road(road)

func _remove_road(road: Node3D):
	if is_instance_valid(road):
		road.queue_free()
		active_roads.erase(road)

func _check_and_remove_obstacles():
	if active_obstacles.is_empty():
		return
	
	var player_pos = dog_character.global_position
	var player_forward = dog_character.forward_direction if dog_character else Vector3.FORWARD
	var obstacles_to_remove = []
	
	# Check if any obstacle is too far behind the player
	for obstacle in active_obstacles:
		if not is_instance_valid(obstacle):
			obstacles_to_remove.append(obstacle)
			continue
			
		var obstacle_to_player = obstacle.global_position - player_pos
		var distance_behind = obstacle_to_player.length()
		
		# Check if obstacle is behind the player (dot product < 0)
		var is_behind = obstacle_to_player.dot(player_forward) < 0
		
		# Remove obstacle if it's behind and too far away
		if is_behind and distance_behind > DESPAWN_DISTANCE:
			obstacles_to_remove.append(obstacle)
	
	# Remove marked obstacles
	for obstacle in obstacles_to_remove:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
			active_obstacles.erase(obstacle)

# ============================
# AAA-STYLE OBSTACLE SPAWNING
# ============================

func _spawn_road_content(road_chunk: Node3D, road_position: Vector3):
	var obstacle_roll = rng.randf()
	
	# Spawn obstacles with high probability
	if obstacle_roll < OBSTACLE_SPAWN_CHANCE:
		_spawn_obstacles_on_road(road_position)
	
	# Spawn coins
	var coin_roll = rng.randf()
	if coin_roll < COIN_SPAWN_CHANCE:
		_spawn_coins_on_road(road_position)
	

func _spawn_obstacles_on_road(road_position: Vector3):
	# Calculate difficulty-based obstacle count
	var base_count = int(base_obstacles * difficulty_multiplier)
	var max_count = int(MAX_OBSTACLES_PER_ROAD * difficulty_multiplier)
	
	# Cap at reasonable maximum
	max_count = min(max_count, 12)
	base_count = min(base_count, max_count)
	
	var num_obstacles = rng.randi_range(base_count, max_count)
	
	# Spawn obstacles across all 3 lanes
	var lanes = [-1, 0, 1]  # Left, Center, Right
	var obstacles_per_lane = {}
	
	# Distribute obstacles across lanes (obstacle3 only in lanes 1 and -1, obstacle4 only in lane 0, obstacle5 only in lanes 1 and -1, obstacle9 only in lanes 1 and -1, obstacle10 only in lanes -1 and 0, obstacle11 only in lane -1, obstacle12 only in lane 1)
	for i in range(num_obstacles):
		var lane = lanes[i % 3]  # Cycle through all 3 lanes
		if not obstacles_per_lane.has(lane):
			obstacles_per_lane[lane] = 0
		
		# Check lane restrictions for specific obstacles
		var potential_obstacle_index = rng.randi() % obstacle_scenes.size()
		
		# For testing: Force obstacle12 to spawn more frequently (50% chance)
		if rng.randf() < 0.5:
			potential_obstacle_index = 11  # obstacle12 index
		
		# Skip if obstacle3 trying to spawn in middle lane
		if potential_obstacle_index == 2 and lane == 0:
			continue
		
		# Skip if obstacle4 trying to spawn in non-middle lanes
		if potential_obstacle_index == 3 and lane != 0:
			continue
		
		# Skip if obstacle5 trying to spawn in middle lane
		if potential_obstacle_index == 4 and lane == 0:
			continue
		
		# Skip if obstacle9 trying to spawn in middle lane
		if potential_obstacle_index == 8 and lane == 0:
			continue
		
		# Skip if obstacle10 trying to spawn in right lane
		if potential_obstacle_index == 9 and lane == 1:
			continue
		
		# Skip if obstacle11 trying to spawn in non-left lanes
		if potential_obstacle_index == 10 and lane != -1:
			continue
		
		# Skip if obstacle12 trying to spawn in non-right lanes
		if potential_obstacle_index == 11 and lane != 1:
			continue
		
		obstacles_per_lane[lane] += 1
	
	# Track used positions to prevent overlapping
	var used_positions = []
	var min_distance_between_obstacles = 15.0  # Increased from 8.0 to 15.0 for more spacing
	
	# Spawn obstacles for each lane
	for lane in lanes:
		var obstacles_in_lane = obstacles_per_lane.get(lane, 0)
				
		for i in range(obstacles_in_lane):
			# Randomly choose between all available obstacles
			if obstacle_scenes.is_empty():
				continue
			
			var obstacle_scene_index = rng.randi() % obstacle_scenes.size()
			
			# Enforce lane restrictions during actual spawning
			if lane == 0 and obstacle_scene_index == 2:  # obstacle3 in middle lane
				continue
			elif lane != 0 and obstacle_scene_index == 3:  # obstacle4 in non-middle lanes
				continue
			elif lane == 0 and obstacle_scene_index == 4:  # obstacle5 in middle lane
				continue
			elif lane == 0 and obstacle_scene_index == 8:  # obstacle9 in middle lane
				continue
			elif lane == 1 and obstacle_scene_index == 9:  # obstacle10 in right lane
				continue
			elif lane != -1 and obstacle_scene_index == 10:  # obstacle11 in non-left lanes
				continue
			elif lane != 1 and obstacle_scene_index == 11:  # obstacle12 in non-right lanes
				continue
			
			var obstacle_scene = obstacle_scenes[obstacle_scene_index]
			var obstacle_instance = obstacle_scene.instantiate()
			
			# Find a non-overlapping position
			var position_found = false
			var attempts = 0
			var max_attempts = 30  # Increased attempts for better positioning
			var forward_offset = 0.0
			var lane_offset = 0.0
			
			while not position_found and attempts < max_attempts:
				# Position on the road with increased minimum spacing
				var min_offset = max(15.0, 20.0 - (difficulty_multiplier * 1.5))  # Increased from 8.0 to 15.0
				var max_offset = 85.0
				forward_offset = rng.randf_range(min_offset, max_offset)
				
				# Use correct lane offsets based on obstacle type
				match lane:
					-1:  # Left lane
						if obstacle_scene_index == 0:  # obstacle1
							lane_offset = OBSTACLE1_LEFT_OFFSET
						elif obstacle_scene_index == 1:  # obstacle2
							lane_offset = OBSTACLE2_LEFT_OFFSET
						elif obstacle_scene_index == 2:  # obstacle3
							lane_offset = OBSTACLE3_LEFT_OFFSET
						elif obstacle_scene_index == 3:  # obstacle4 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_LEFT_OFFSET  # Fallback
						elif obstacle_scene_index == 4:  # obstacle5
							lane_offset = OBSTACLE5_LEFT_OFFSET
						elif obstacle_scene_index == 5:  # obstacle6
							lane_offset = OBSTACLE6_LEFT_OFFSET
						elif obstacle_scene_index == 6:  # obstacle7
							lane_offset = OBSTACLE7_LEFT_OFFSET
						elif obstacle_scene_index == 7:  # obstacle8
							lane_offset = OBSTACLE8_LEFT_OFFSET
						elif obstacle_scene_index == 8:  # obstacle9
							lane_offset = OBSTACLE9_LEFT_OFFSET
						elif obstacle_scene_index == 9:  # obstacle10
							lane_offset = OBSTACLE10_LEFT_OFFSET
						elif obstacle_scene_index == 10:  # obstacle11
							lane_offset = OBSTACLE11_LEFT_OFFSET
						else:  # obstacle12 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_LEFT_OFFSET  # Fallback
					0:   # Middle lane
						if obstacle_scene_index == 0:  # obstacle1
							lane_offset = OBSTACLE1_MIDDLE_OFFSET
						elif obstacle_scene_index == 1:  # obstacle2
							lane_offset = OBSTACLE2_MIDDLE_OFFSET
						elif obstacle_scene_index == 2:  # obstacle3 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_MIDDLE_OFFSET  # Fallback
						elif obstacle_scene_index == 3:  # obstacle4
							lane_offset = OBSTACLE4_MIDDLE_OFFSET
						elif obstacle_scene_index == 4:  # obstacle5 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_MIDDLE_OFFSET  # Fallback
						elif obstacle_scene_index == 5:  # obstacle6
							lane_offset = OBSTACLE6_MIDDLE_OFFSET
						elif obstacle_scene_index == 6:  # obstacle7
							lane_offset = OBSTACLE7_MIDDLE_OFFSET
						elif obstacle_scene_index == 7:  # obstacle8
							lane_offset = OBSTACLE8_MIDDLE_OFFSET
						elif obstacle_scene_index == 8:  # obstacle9 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_MIDDLE_OFFSET  # Fallback
						elif obstacle_scene_index == 9:  # obstacle10
							lane_offset = OBSTACLE10_MIDDLE_OFFSET
						elif obstacle_scene_index == 10:  # obstacle11 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_MIDDLE_OFFSET  # Fallback
						else:  # obstacle12 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_MIDDLE_OFFSET  # Fallback
					1:   # Right lane
						if obstacle_scene_index == 0:  # obstacle1
							lane_offset = OBSTACLE1_RIGHT_OFFSET
						elif obstacle_scene_index == 1:  # obstacle2
							lane_offset = OBSTACLE2_RIGHT_OFFSET
						elif obstacle_scene_index == 2:  # obstacle3
							lane_offset = OBSTACLE3_RIGHT_OFFSET
						elif obstacle_scene_index == 3:  # obstacle4 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_RIGHT_OFFSET  # Fallback
						elif obstacle_scene_index == 4:  # obstacle5
							lane_offset = OBSTACLE5_RIGHT_OFFSET
						elif obstacle_scene_index == 5:  # obstacle6
							lane_offset = OBSTACLE6_RIGHT_OFFSET
						elif obstacle_scene_index == 6:  # obstacle7
							lane_offset = OBSTACLE7_RIGHT_OFFSET
						elif obstacle_scene_index == 7:  # obstacle8
							lane_offset = OBSTACLE8_RIGHT_OFFSET
						elif obstacle_scene_index == 8:  # obstacle9
							lane_offset = OBSTACLE9_RIGHT_OFFSET
						elif obstacle_scene_index == 9:  # obstacle10 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_RIGHT_OFFSET  # Fallback
						elif obstacle_scene_index == 10:  # obstacle11 - should not happen due to lane restriction
							lane_offset = OBSTACLE1_RIGHT_OFFSET  # Fallback
						else:  # obstacle12
							lane_offset = OBSTACLE12_RIGHT_OFFSET
					_:
						lane_offset = lane * LANE_WIDTH  # Fallback
				
				# Calculate actual world position
				var test_world_pos = road_position + current_direction * forward_offset + current_direction.cross(Vector3.UP).normalized() * lane_offset
				
				# Check if this position is too close to any existing obstacle
				var position_valid = true
				for used_pos in used_positions:
					var distance = test_world_pos.distance_to(used_pos)
					if distance < min_distance_between_obstacles:
						position_valid = false
						break
				
				if position_valid:
					used_positions.append(test_world_pos)
					position_found = true
				
				attempts += 1
			
			if not position_found:
				obstacle_instance.queue_free()
				continue
			
			var world_pos = road_position + current_direction * forward_offset + current_direction.cross(Vector3.UP).normalized() * lane_offset
			
			# Add to scene FIRST, then set position
			$roadHolder.add_child(obstacle_instance)
			obstacle_instance.global_position = world_pos
			obstacle_instance.global_rotation.y = current_rotation
			
			# Track the obstacle
			active_obstacles.append(obstacle_instance)
		

func _spawn_coins_on_road(road_position: Vector3):
	if coin_scenes.is_empty():
		return
		
	var num_coins = rng.randi_range(3, MAX_COINS_PER_ROAD)
	
	for i in range(num_coins):
		var lane = rng.randi_range(-1, 1)  # Random lane
		var forward_offset = rng.randf_range(10.0, 80.0)
		
		# Use specific coin lane offsets
		var lane_offset = 0.0
		match lane:
			-1:  # Left lane
				lane_offset = COIN_LEFT_OFFSET
			0:   # Middle lane
				lane_offset = COIN_MIDDLE_OFFSET
			1:   # Right lane
				lane_offset = COIN_RIGHT_OFFSET
		
		# Create coin instance
		var coin_scene = coin_scenes[0]  # Use the first (and only) coin scene
		var coin_instance = coin_scene.instantiate()
		
		# Calculate world position
		var world_pos = road_position + current_direction * forward_offset + current_direction.cross(Vector3.UP).normalized() * lane_offset
		
		# Add to scene and set position
		$roadHolder.add_child(coin_instance)
		coin_instance.global_position = world_pos
		coin_instance.global_rotation.y = current_rotation
		
		# Track the coin
		active_collectibles.append(coin_instance)

func _spawn_powerup_on_road(road_position: Vector3):
	var lane = rng.randi_range(-1, 1)  # Random lane
	var forward_offset = rng.randf_range(30.0, 60.0)
	var lane_offset = lane * LANE_WIDTH
	
	var world_pos = road_position + current_direction * forward_offset + current_direction.cross(Vector3.UP).normalized() * lane_offset

func _check_and_remove_collectibles():
	if active_collectibles.is_empty():
		return
	
	var player_pos = dog_character.global_position
	var player_forward = dog_character.forward_direction if dog_character else Vector3.FORWARD
	var collectibles_to_remove = []
	
	# Check if any collectible is too far behind the player
	for collectible in active_collectibles:
		if not is_instance_valid(collectible):
			collectibles_to_remove.append(collectible)
			continue
			
		var collectible_to_player = collectible.global_position - player_pos
		var distance_behind = collectible_to_player.length()
		
		# Check if collectible is behind the player (dot product < 0)
		var is_behind = collectible_to_player.dot(player_forward) < 0
		
		# Remove collectible if it's behind and too far away
		if is_behind and distance_behind > DESPAWN_DISTANCE:
			collectibles_to_remove.append(collectible)
	
	# Remove marked collectibles
	for collectible in collectibles_to_remove:
		if is_instance_valid(collectible):
			collectible.queue_free()
			active_collectibles.erase(collectible)

func _get_random_available_lane(occupied_lanes: Array):
	var available_lanes = [-1, 0, 1]  # Left, center, right
	
	# Remove occupied lanes
	for lane in occupied_lanes:
		available_lanes.erase(lane)
	
	if available_lanes.is_empty():
		return -1
	
	return available_lanes[rng.randi() % available_lanes.size()]

# HUD functions
func increment_obstacles_passed():
	if player_hud:
		player_hud.increment_obstacles_passed()

func update_hud():
	if player_hud:
		player_hud.update_all_displays()

func update_coin_display(coin_count: int):
	if player_hud and player_hud.has_method("set_coin_display"):
		player_hud.set_coin_display(coin_count)
	else:
		print("Coins: ", coin_count)  # Fallback to console if HUD not available
	
	# Update coin counter and check for victory
	current_coins_collected = coin_count
	if current_coins_collected >= victory_coins_required and not is_game_paused:
		_show_victory_screen()


func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

# ============================
# PROFESSIONAL MISSION UI SYSTEM
# ============================

func _update_mission_ui(delta: float):
	match mission_ui_state:
		"fading_in":
			mission_ui_alpha += delta / FADE_DURATION
			if mission_ui_alpha >= 1.0:
				mission_ui_alpha = 1.0
				mission_ui_state = "visible"
				mission_timer = 0.0
			_set_mission_ui_alpha(mission_ui_alpha)
			
		"visible":
			mission_timer += delta
			# Add subtle pulse effect while visible
			var pulse = sin(mission_timer * 3.0) * 0.05 + 1.0
			_set_mission_ui_scale(Vector2(pulse, pulse))
			
			if mission_timer >= MISSION_DISPLAY_TIME:
				mission_ui_state = "fading_out"
				mission_timer = 0.0
				
		"fading_out":
			mission_ui_alpha -= delta / FADE_DURATION
			if mission_ui_alpha <= 0.0:
				mission_ui_alpha = 0.0
				mission_ui_state = "hidden"
				missonUI.visible = false
				_set_mission_ui_scale(Vector2(1.0, 1.0))
			_set_mission_ui_alpha(mission_ui_alpha)

func _set_mission_ui_alpha(alpha: float):
	if not missonUI:
		return
		
	# Apply alpha to all UI elements
	var texture_rect = missonUI.get_node_or_null("TextureRect")
	if texture_rect:
		var modulate = texture_rect.modulate
		modulate.a = alpha
		texture_rect.modulate = modulate
		
		# Apply to labels
		var label = texture_rect.get_node_or_null("Label")
		if label:
			var label_modulate = label.modulate
			label_modulate.a = alpha
			label.modulate = label_modulate
			
		var label2 = texture_rect.get_node_or_null("Label2")
		if label2:
			var label2_modulate = label2.modulate
			label2_modulate.a = alpha
			label2.modulate = label2_modulate
			
		var label3 = texture_rect.get_node_or_null("Label3")
		if label3:
			var label3_modulate = label3.modulate
			label3_modulate.a = alpha
			label3.modulate = label3_modulate
	
	# Apply to coin sprite
	var coin = missonUI.get_node_or_null("Coin")
	if coin:
		var coin_modulate = coin.modulate
		coin_modulate.a = alpha
		coin.modulate = coin_modulate

func _set_mission_ui_scale(scale: Vector2):
	if not missonUI:
		return
		
	var texture_rect = missonUI.get_node_or_null("TextureRect")
	if texture_rect:
		texture_rect.pivot_offset = texture_rect.size / 2
		texture_rect.scale = scale


func _on_customize_pressed() -> void:
	# Hide all clicked states first
	_hide_all_clicked_states()
	# Show customize clicked state
	$NavBar/CustomizeClicked.visible = true
	print("Customize clicked")

func _on_customize_clicked_pressed() -> void:
	# Hide customize clicked state
	$NavBar/CustomizeClicked.visible = false

func _on_misson_pressed() -> void:
	print("Mission button pressed!")
	# Hide all clicked states first
	_hide_all_clicked_states()
	# Show mission clicked state
	$NavBar/MissonClicked.visible = true
	# Show mission screen with pause and blur
	_show_mission_screen()

func _on_misson_clicked_pressed() -> void:
	# Hide mission clicked state
	$NavBar/MissonClicked.visible = false

func _on_close_misson_pressed() -> void:
	print("Close mission button pressed!")
	_hide_mission_screen()
	$NavBar/MissonClicked.visible = false

# ============================
# VICTORY SCREEN MANAGEMENT
# ============================

func _show_victory_screen():
	print("Victory! Player collected ", current_coins_collected, " coins!")
	
	# Pause the game
	is_game_paused = true
	get_tree().paused = true
	
	# Hide player HUD for cleaner victory screen
	if player_hud:
		player_hud.visible = false
	
	# Show victory screen
	if has_node("Victory"):
		var victory_screen = $Victory
		victory_screen.visible = true
		# Ensure victory screen is on top
		victory_screen.z_index = 100
		
		# Apply blur effect to game world
		_apply_blur_effect(true)
		
		# Start victory animation using its own method
		if victory_screen.has_method("start_victory_animation"):
			victory_screen.start_victory_animation()
		
		print("Victory screen animation started!")
	else:
		print("ERROR: Victory node not found!")

func _hide_victory_screen():
	# Resume the game
	is_game_paused = false
	get_tree().paused = false
	
	# Hide victory screen with animation
	if has_node("Victory"):
		var victory_screen = $Victory
		
		# Start fade out animation using its own method
		if victory_screen.has_method("hide_victory_screen"):
			victory_screen.hide_victory_screen()
		
		# Show player HUD again
		if player_hud:
			player_hud.visible = true
		
		# Remove blur effect
		_apply_blur_effect(false)
	else:
		print("ERROR: Victory node not found when hiding!")

func _on_close_victory_pressed() -> void:
	print("Close victory button pressed!")
	_hide_victory_screen()

func _on_settings_pressed() -> void:
	# Hide all clicked states first
	_hide_all_clicked_states()
	# Show settings clicked state
	$NavBar/SettingsClicked.visible = true

func _on_settings_clicked_pressed() -> void:
	# Hide settings clicked state
	$NavBar/SettingsClicked.visible = false

func _on_home_clicked_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/MainMenu.tscn")

# Helper function to hide all clicked states
func _hide_all_clicked_states():
	if $NavBar.has_node("CustomizeClicked"):
		$NavBar/CustomizeClicked.visible = false
	if $NavBar.has_node("MissonClicked"):
		$NavBar/MissonClicked.visible = false
	if $NavBar.has_node("SettingsClicked"):
		$NavBar/SettingsClicked.visible = false
	if $NavBar.has_node("HomeClicked"):
		$NavBar/HomeClicked.visible = false

# ============================
# MISSION SCREEN MANAGEMENT
# ============================

func _show_mission_screen():
	# Debug: Check mission screen structure
	if has_node("MissonScreen"):
		var mission_screen = $MissonScreen
		print("Mission screen node found!")
		print("Mission screen visible: ", mission_screen.visible)
		print("Mission screen modulate: ", mission_screen.modulate)
		print("Mission screen position: ", mission_screen.position)
		print("Mission screen size: ", mission_screen.size)
		print("Mission screen anchors: ", mission_screen.anchors_preset)
		
		# Check TextureRect
		var texture_rect = mission_screen.get_node_or_null("TextureRect")
		if texture_rect:
			print("TextureRect found!")
			print("TextureRect visible: ", texture_rect.visible)
			print("TextureRect modulate: ", texture_rect.modulate)
			print("TextureRect position: ", texture_rect.position)
			print("TextureRect size: ", texture_rect.size)
		else:
			print("ERROR: TextureRect not found!")
		
		# Check CloseMisson button
		var close_button = mission_screen.get_node_or_null("CloseMisson")
		if close_button:
			print("CloseMisson button found!")
			print("CloseMisson visible: ", close_button.visible)
			print("CloseMisson position: ", close_button.position)
			print("CloseMisson size: ", close_button.size)
			# Ensure close button is on top
			close_button.z_index = 200
		else:
			print("ERROR: CloseMisson button not found!")
	
	# Pause the game
	is_game_paused = true
	get_tree().paused = true
	
	# Show mission screen
	if has_node("MissonScreen"):
		var mission_screen = $MissonScreen
		mission_screen.visible = true
		# Force proper positioning and sizing
		mission_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Ensure mission screen is on top
		mission_screen.z_index = 100
		
		# Apply blur effect to game world
		_apply_blur_effect(true)
		
		print("After setting visible - Mission screen visible: ", mission_screen.visible)
		print("Mission screen should now be visible!")
	else:
		print("ERROR: MissonScreen node not found!")

func _hide_mission_screen():
	# Resume the game
	is_game_paused = false
	get_tree().paused = false
	
	# Hide mission screen
	if has_node("MissonScreen"):
		$MissonScreen.visible = false
		print("Mission screen hidden!")
		
		# Remove blur effect
		_apply_blur_effect(false)
	else:
		print("ERROR: MissonScreen node not found when hiding!")

func _apply_blur_effect(apply: bool):
	# Create a simple overlay blur effect using a semi-transparent ColorRect
	if apply:
		# Create blur overlay if it doesn't exist
		if not has_node("BlurOverlay"):
			var blur_overlay = ColorRect.new()
			blur_overlay.name = "BlurOverlay"
			blur_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			blur_overlay.color = Color(0.0, 0.0, 0.0, 0.3)  # Semi-transparent black
			blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks through
			add_child(blur_overlay)
			# Move blur overlay to be behind mission screen but in front of game
			blur_overlay.z_index = 10
	else:
		# Remove blur overlay if it exists
		if has_node("BlurOverlay"):
			$BlurOverlay.queue_free()

func _animate_mission_screen_in():
	if not has_node("MissonScreen"):
		return
		
	var mission_screen = $MissonScreen
	var texture_rect = mission_screen.get_node_or_null("TextureRect")
	
	if texture_rect:
		# Start with scaled down and transparent
		texture_rect.modulate.a = 0.0
		texture_rect.scale = Vector2(0.8, 0.8)
		texture_rect.pivot_offset = texture_rect.size / 2
		
		# Create smooth animation
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(texture_rect, "modulate:a", 1.0, 0.3)
		tween.tween_property(texture_rect, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)

func _animate_mission_screen_out():
	if not has_node("MissonScreen"):
		return
		
	var mission_screen = $MissonScreen
	var texture_rect = mission_screen.get_node_or_null("TextureRect")
	
	if texture_rect:
		# Animate out
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(texture_rect, "modulate:a", 0.0, 0.2)
		tween.tween_property(texture_rect, "scale", Vector2(0.9, 0.9), 0.2).set_ease(Tween.EASE_IN)
		
		# Hide screen after animation
		tween.tween_callback(func(): mission_screen.visible = false)
