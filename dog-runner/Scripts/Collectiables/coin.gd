extends Area3D

func _on_body_entered(body: Node3D) -> void:
	# Check if the body is the player
	if body.is_in_group("player"):
		# Add coin to player's counter
		if body.has_method("add_coin"):
			body.add_coin()
		
		# Play collection VFX
		_play_collection_vfx()
		
		# Remove the coin
		queue_free()

func _play_collection_vfx():
	# Create coin collection VFX at coin position
	var vfx_scene = preload("res://Scenes/VFX/CoinCollectionVFX.tscn")
	if vfx_scene:
		var vfx_instance = vfx_scene.instantiate()
		
		# Add VFX to the same parent as the coin
		var parent = get_parent()
		if parent:
			parent.add_child(vfx_instance)
			vfx_instance.global_position = global_position
			
			# Play the VFX
			if vfx_instance.has_method("play_coin_collection"):
				vfx_instance.play_coin_collection()

func _collect_coin():
	# Placeholder for collection effects
	# Could add sound, particles, etc.
	pass
