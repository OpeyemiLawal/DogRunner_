extends Node3D

# Road chunk scenes
@export var road_chunk_scenes: Array[PackedScene] = []

# Generation parameters
const CHUNK_LENGTH = 18.0  # Size of each road chunk based on the scene file
const BATCH_SIZE = 1       # Number of chunks to spawn at once
const INITIAL_BATCHES = 1  # Initial number of batches to spawn (start with 1 chunk)
const SPAWN_DISTANCE = 50.0  # Distance from dog to spawn new chunks
const DESPAWN_DISTANCE = 150.0  # Distance behind dog to remove chunks (increased)
const MAX_CHUNKS = 25     # Maximum chunks to keep in memory
const SPAWN_PROPS = false  # Disable prop spawning

# Track spawned chunks
var active_chunks: Array[Node3D] = []
var dog_character: CharacterBody3D
var next_spawn_position: Vector3 = Vector3.ZERO
var rng: RandomNumberGenerator

func _ready():
	add_to_group("world_generator")
	
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Find the dog character
	dog_character = get_tree().get_first_node_in_group("player")
	if not dog_character:
		print("Warning: Dog character not found! Make sure it's in the 'player' group.")
		return
	
	# Load road chunk scenes if not assigned
	if road_chunk_scenes.is_empty():
		_load_road_scenes()
		print("Road loaded ")
	
		
	# Spawn initial chunks
	_spawn_initial_chunks()

func _process(delta):
	if not dog_character:
		return
	
	# Check if we need to spawn more chunks
	_check_and_spawn_chunks()
	
	# Check if we need to remove old chunks
	_check_and_remove_chunks()
	
	# Debug: Show all chunks every 2 seconds
	if Time.get_ticks_msec() % 2000 < 16:  # Approximately every 2 seconds
		_debug_all_chunks()

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


func _spawn_initial_chunks():
	print("Spawning initial batches...")
	print("CHUNK_LENGTH: ", CHUNK_LENGTH)
	print("BATCH_SIZE: ", BATCH_SIZE)
	
	for batch in range(INITIAL_BATCHES):
		_spawn_chunk_batch()
	
	print("Initial chunks spawned: ", active_chunks.size())
	print("Active chunks array size: ", active_chunks.size())
	
	# Debug: Print all chunk positions
	for i in range(active_chunks.size()):
		var chunk = active_chunks[i]
		if is_instance_valid(chunk):
			print("Chunk ", i, " position: ", chunk.global_position)

func _check_and_spawn_chunks():
	# Check if dog is close to the last spawned chunk
	var dog_distance_to_next = dog_character.global_position.distance_to(next_spawn_position)
	
	# Spawn new batch when dog gets close to the next spawn position
	if dog_distance_to_next < SPAWN_DISTANCE and active_chunks.size() < MAX_CHUNKS:
		_spawn_chunk_batch()

func _spawn_chunk_batch():
	print("Spawning batch of ", BATCH_SIZE, " road chunks...")
	
	for i in range(BATCH_SIZE):
		var spawn_pos = next_spawn_position + Vector3(0, 0, -i * CHUNK_LENGTH)
		print("Attempting to spawn chunk ", i, " at position: ", spawn_pos)
		var chunk = _spawn_road_chunk(spawn_pos)
		if chunk:
			print("Successfully spawned chunk ", i)
		else:
			print("Failed to spawn chunk ", i)
	
	# Update next spawn position for next batch (continue from where this batch ended)
	next_spawn_position = next_spawn_position + Vector3(0, 0, -BATCH_SIZE * CHUNK_LENGTH)
	print("Batch completed. Next spawn position: ", next_spawn_position)

func _check_and_remove_chunks():
	# Remove chunks that are too far BEHIND the dog (not just far away)
	var chunks_to_remove = []
	for chunk in active_chunks:
		var chunk_pos = chunk.global_position
		var dog_pos = dog_character.global_position
		
		# Check if chunk is behind the dog (negative Z direction relative to dog's forward direction)
		var relative_pos = chunk_pos - dog_pos
		var distance_behind = -relative_pos.z  # Positive if chunk is behind
		
		if distance_behind > DESPAWN_DISTANCE:
			chunks_to_remove.append(chunk)
			print("Marking chunk for removal: behind dog by ", distance_behind)
	
	for chunk in chunks_to_remove:
		_remove_chunk(chunk)

func _spawn_road_chunk(position: Vector3):
	if road_chunk_scenes.is_empty():
		print("Error: No road chunk scenes available!")
		return null
	
	# Randomly select a road chunk
	var random_scene = road_chunk_scenes[rng.randi() % road_chunk_scenes.size()]
	var chunk = random_scene.instantiate()
	
	if not chunk:
		print("Error: Failed to instantiate road chunk scene!")
		return null
	
	# Check if roadHolder exists
	if not has_node("roadHolder"):
		print("ERROR: roadHolder node not found!")
		return null
	
	# Add to scene first, then set position (keep original rotation for proper road orientation)
	$roadHolder.add_child(chunk)
	chunk.global_position = position
	active_chunks.append(chunk)
	
	# Debug: Check actual position after setting
	var actual_pos = chunk.global_position
	print("Spawned road chunk at target: ", position, " | actual: ", actual_pos, " | Total chunks: ", active_chunks.size())
	
	return chunk



func _remove_chunk(chunk: Node3D):
	if is_instance_valid(chunk):
		chunk.queue_free()
		active_chunks.erase(chunk)
		print("Removed chunk. Remaining chunks: ", active_chunks.size())

func get_chunk_count():
	return active_chunks.size()

func _debug_all_chunks():
	print("\n🌍 === WORLD GENERATOR DEBUG === 🌍")
	print("Total active chunks: ", active_chunks.size())
	print("Dog position: ", dog_character.global_position)
	print("Next spawn position: ", next_spawn_position)
	
	for i in range(active_chunks.size()):
		var chunk = active_chunks[i]
		if is_instance_valid(chunk):
			var chunk_id = str(chunk.get_instance_id())[-4]
			print("Chunk ", i, " [", chunk_id, "]: ", chunk.global_position)
			
			# Count visible props on this chunk
			var left_visible = 0
			var right_visible = 0
			
			# Check left props
			for j in range(15):
				var prop_path = "leftProps/prop" + str(j + 1)
				var prop = chunk.get_node_or_null(prop_path)
				if prop and prop.visible:
					left_visible += 1
			
			# Check right props  
			for j in range(14):
				var prop_path = "PropsPlaceholderRight/RightProp" + str(j + 1)
				var prop = chunk.get_node_or_null(prop_path)
				if prop and prop.visible:
					right_visible += 1
			
			print("  → Left props: ", left_visible, " | Right props: ", right_visible, " | Total: ", (left_visible + right_visible))
			
			if left_visible > 1 or right_visible > 1:
				print("  ❌ ERROR: Too many props on this chunk!")
			else:
				print("  ✅ OK")
	
	print("===================================\n")

func clear_all_chunks():
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	active_chunks.clear()
	next_spawn_position = Vector3.ZERO
	print("All chunks cleared")

func get_next_spawn_position():
	return next_spawn_position

func get_dog_distance_to_next_chunk():
	if not dog_character:
		return INF
	return dog_character.global_position.distance_to(next_spawn_position)
