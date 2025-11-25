extends Node3D

# Road chunk scenes
@export var road_chunk_scenes: Array[PackedScene] = []

# Generation parameters
const ROAD_LENGTH = 90.0  # Length of each road chunk
const SPAWN_DISTANCE = 120.0  # Distance from player to spawn next road (increased)
const DESPAWN_DISTANCE = 100.0  # Distance behind player to remove road (reduced)
const MAX_ROADS = 2  # Maximum roads to keep on screen

# Track spawned roads
var active_roads: Array[Node3D] = []
var dog_character: CharacterBody3D
var next_spawn_z: float = 0.0  # Next Z position to spawn road

func _ready():
	add_to_group("world_generator")
	
	# Find the dog character
	dog_character = get_tree().get_first_node_in_group("player")
	if not dog_character:
		print("Warning: Dog character not found! Make sure it's in the 'player' group.")
		return
	
	# Load road chunk scenes if not assigned
	if road_chunk_scenes.is_empty():
		_load_road_scenes()
		print("Road loaded ")
	
	# Spawn initial roads
	_spawn_initial_roads()

func _process(delta):
	if not dog_character:
		return
	
	# Check if we need to spawn more roads (this also handles removal)
	_check_and_spawn_roads()

func _load_road_scenes():
	# Only load road1.tscn for now
	var file_path = "res://Scenes/Chunks/road1.tscn"
	if ResourceLoader.exists(file_path):
		var scene = load(file_path) as PackedScene
		if scene:
			road_chunk_scenes.append(scene)
			print("Loaded road scene: ", file_path)
		else:
			print("Failed to load road scene: ", file_path)
	else:
		print("Road scene not found: ", file_path)

func _spawn_initial_roads():
	print("Spawning initial road...")
	
	# Spawn only one road at origin
	_spawn_road_at_z(0.0)
	
	print("Initial road spawned: ", active_roads.size())

func _spawn_road_at_z(z_position: float):
	if road_chunk_scenes.is_empty():
		print("Error: No road scenes loaded!")
		return
	
	var road_scene = road_chunk_scenes[0]
	var road_chunk = road_scene.instantiate()
	
	if road_chunk:
		# Add to scene tree
		$roadHolder.add_child(road_chunk)
		road_chunk.global_position = Vector3(0, 0, z_position)
		active_roads.append(road_chunk)
		
		print("Spawned road at Z: ", z_position, " | Total roads: ", active_roads.size())
		
		# Update next spawn position
		next_spawn_z = z_position - ROAD_LENGTH
		
		return road_chunk
	else:
		print("Error: Failed to instantiate road chunk!")
		return null

func _check_and_spawn_roads():
	if active_roads.is_empty():
		return
	
	var player_z = dog_character.global_position.z
	var distance_to_next = abs(player_z - next_spawn_z)
	
	# Spawn new road when player gets close to next spawn position
	if distance_to_next < SPAWN_DISTANCE and active_roads.size() < MAX_ROADS:
		_spawn_road_at_z(next_spawn_z)
	
	# Remove roads that are too far behind
	_check_and_remove_roads()

func _check_and_remove_roads():
	if active_roads.is_empty():
		return
	
	var player_z = dog_character.global_position.z
	var roads_to_remove = []
	
	# Check if any road is too far behind the player
	for road in active_roads:
		var road_z = road.global_position.z
		var distance_behind = abs(player_z - road_z)
		
		# Remove road if it's too far behind player
		if distance_behind > DESPAWN_DISTANCE:
			roads_to_remove.append(road)
	
	# Remove marked roads
	for road in roads_to_remove:
		_remove_road(road)

func _remove_road(road: Node3D):
	if is_instance_valid(road):
		road.queue_free()
		active_roads.erase(road)
