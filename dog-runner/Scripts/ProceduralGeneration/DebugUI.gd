extends Control

@onready var chunk_count_label: Label = $ChunkCount
@onready var position_label: Label = $Position
@onready var debug_info: Label = $DebugInfo

var world_generator: Node3D

func _ready():
	# Find the WorldGenerator - try multiple methods
	world_generator = $"../.."
	if not world_generator:
		# Try to find it by name from current scene
		world_generator = get_tree().current_scene.get_node_or_null("WorldGenerator")
	if not world_generator:
		# Try to find parent WorldGenerator
		world_generator = get_parent().get_node_or_null("WorldGenerator")
	if not world_generator:
		# Try to find any node with WorldGenerator script
		var nodes = get_tree().get_nodes_in_group("world_generator")
		if nodes.size() > 0:
			world_generator = nodes[0]
	
	if not world_generator:
		print("DebugUI: WorldGenerator not found!")
		hide()
		return
	
	print("DebugUI: Connected to WorldGenerator")

func _process(delta):
	if not world_generator:
		return
	
	# Update chunk count
	chunk_count_label.text = "Chunks: " + str(world_generator.get_chunk_count())
	
	# Update player position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		position_label.text = "Player: " + str(player.global_position)
	
	# Update debug info
	if world_generator.has_method("get_dog_distance_to_next_chunk"):
		var distance = world_generator.get_dog_distance_to_next_chunk()
		debug_info.text = "Distance to next spawn: " + str(distance)
