extends Node3D

@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var burst_particles: GPUParticles3D = $BurstParticles
@onready var light: OmniLight3D = $OmniLight3D
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var coin_collect_sound: AudioStream

func _ready():
	# Load coin collection sound
	_load_coin_sound()
	
	# Connect to particle finish signal for cleanup
	particles.finished.connect(_on_particles_finished)

func _load_coin_sound():
	# Try to load a coin sound effect
	var sound_paths = [
		"res://Assets/Audio/coin-collected.mp3",
		"res://Assets/Audio/coin_collect.wav",
		"res://Assets/Audio/coin_pickup.ogg",
		"res://Assets/Sounds/coin.wav"
	]
	
	for path in sound_paths:
		if ResourceLoader.exists(path):
			coin_collect_sound = load(path)
			audio.stream = coin_collect_sound
			break
	
	# If no sound file exists, create a simple tone
	if not coin_collect_sound:
		_create_coin_sound()

func _create_coin_sound():
	# For now, skip creating a procedural sound
	# The VFX will work without sound, or you can add a sound file manually
	coin_collect_sound = null
	audio.stream = null

func play_coin_collection():
	# Play the particle effects
	particles.restart()
	burst_particles.restart()
	
	# Flash the light
	_flash_light()
	
	# Play sound effect
	_play_sound()
	
	# Auto-cleanup after effects finish
	_start_cleanup_timer()

func _flash_light():
	# Create a flashing light effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Light intensity flash
	light.light_energy = 3.0
	tween.tween_property(light, "light_energy", 0.0, 0.5)
	
	# Light color pulse
	light.light_color = Color(1, 0.843, 0, 1)  # Gold
	tween.tween_property(light, "light_color", Color(1, 1, 0.2, 1), 0.3)
	tween.tween_property(light, "light_color", Color(1, 0.843, 0, 1), 0.2)

func _play_sound():
	if audio.stream:
		audio.pitch_scale = randf_range(0.9, 1.1)  # Slight pitch variation
		audio.play()

func _start_cleanup_timer():
	# Remove the VFX node after effects complete
	var cleanup_timer = Timer.new()
	add_child(cleanup_timer)
	cleanup_timer.wait_time = 2.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup_vfx)
	cleanup_timer.start()

func _on_particles_finished():
	# Called when main particles finish
	pass

func _cleanup_vfx():
	# Remove the VFX node from scene
	queue_free()

# Static method to create and play VFX at position
static func create_coin_vfx_at_position(position: Vector3, parent_node: Node) -> Node3D:
	var vfx_scene = preload("res://Scenes/VFX/CoinCollectionVFX.tscn")
	var vfx_instance = vfx_scene.instantiate()
	
	# Add to parent and set position
	parent_node.add_child(vfx_instance)
	vfx_instance.global_position = position
	
	# Play the effects
	vfx_instance.play_coin_collection()
	
	return vfx_instance
