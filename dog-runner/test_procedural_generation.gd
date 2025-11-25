extends Node

# Test script for procedural generation
func _ready():
	print("=== Testing Procedural Generation System ===")
	
	# Create a test WorldGenerator
	var world_gen = preload("res://Scripts/ProceduralGeneration/WorldGenerator.gd").new()
	add_child(world_gen)
	
	# Test loading scenes
	world_gen._load_road_scenes()
	world_gen._load_prop_scenes()
	
	print("Road scenes loaded: ", world_gen.road_chunk_scenes.size())
	print("Prop scenes loaded: ", world_gen.prop_scenes.size())
	
	# Test initial spawning
	world_gen._spawn_initial_chunks()
	print("Active chunks after initial spawn: ", world_gen.get_chunk_count())
	
	# Test chunk spawning
	var test_pos = Vector3(0, 0, 90)
	var chunk = world_gen._spawn_road_chunk(test_pos)
	if chunk:
		print("Successfully spawned test chunk at: ", test_pos)
	else:
		print("Failed to spawn test chunk")
	
	print("Final chunk count: ", world_gen.get_chunk_count())
	print("Next spawn position: ", world_gen.get_next_spawn_position())
	
	# Clean up
	world_gen.clear_all_chunks()
	print("Chunks cleared after test")
	
	print("=== Test Complete ===")
	
	# Quit after test
	get_tree().quit()
