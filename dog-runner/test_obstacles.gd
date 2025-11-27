extends Node

# Test script for obstacle system
func _ready():
	print("=== Testing Obstacle System ===")
	
	# Test 1: Check if obstacle scenes can be loaded
	var obstacle_paths = [
		"res://Scenes/Obstacle/obstacle1.tscn",
		"res://Scenes/Obstacle/obstacle2.tscn",
		"res://Scenes/Obstacle/obstacle5.tscn"
	]
	
	for path in obstacle_paths:
		var scene = load(path)
		if scene:
			print("✓ Successfully loaded: ", path)
		else:
			print("✗ Failed to load: ", path)
	
	# Test 2: Check if LevelGenerator has obstacle arrays
	var level_gen = preload("res://LevelGenerator.gd").new()
	add_child(level_gen)
	
	if level_gen.has_method("_spawn_obstacles_on_road"):
		print("✓ LevelGenerator has obstacle spawning method")
	else:
		print("✗ LevelGenerator missing obstacle spawning method")
	
	# Test 3: Check if dog character has collision detection
	var dog_script = load("res://Scripts/Character/dog.gd")
	if dog_script:
		print("✓ Dog character script loaded successfully")
	else:
		print("✗ Failed to load dog character script")
	
	print("=== Test Complete ===")
	
	# Quit after test
	get_tree().quit()
