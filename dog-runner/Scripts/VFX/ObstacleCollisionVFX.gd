extends Node3D

@onready var impact_sparks: GPUParticles3D = $ImpactSparks
@onready var impact_smoke: GPUParticles3D = $ImpactSmoke
@onready var burst_impact: GPUParticles3D = $BurstImpact
@onready var impact_light: OmniLight3D = $ImpactLight
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var damage_flash: ColorRect = $DamageFlash

var impact_sound: AudioStream
var player_camera: Camera3D
var screen_shake_timer: Timer

func _ready():
	# Load impact sound
	_load_impact_sound()
	
	# Find player camera
	_find_player_camera()
	
	# Connect to particle finish signal for cleanup
	impact_sparks.finished.connect(_on_particles_finished)

func _load_impact_sound():
	# Try to load impact sound effects
	var sound_paths = [
		"res://Assets/Audio/obstacle_hit.mp3",
		"res://Assets/Audio/impact.wav",
		"res://Assets/Audio/collision.ogg",
		"res://Assets/Sounds/hit.wav"
	]
	
	for path in sound_paths:
		if ResourceLoader.exists(path):
			impact_sound = load(path)
			audio.stream = impact_sound
			print("Loaded impact sound: ", path)
			break
	
	# If no sound file exists, create a simple tone
	if not impact_sound:
		_create_impact_sound()

func _create_impact_sound():
	# For now, skip creating a procedural sound
	impact_sound = null
	audio.stream = null

func _find_player_camera():
	# Find the player's camera for screen effects
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Look for camera in player's children
		for child in player.get_children():
			if child is Camera3D:
				player_camera = child
				break

func play_collision_vfx(impact_direction: Vector3 = Vector3.UP):
	# Play particle effects
	_play_particle_effects(impact_direction)
	
	# Flash the light
	_flash_impact_light()
	
	# Play screen effects
	_play_screen_effects()
	
	# Play sound effect
	_play_impact_sound()
	
	# Auto-cleanup after effects finish
	_start_cleanup_timer()

func _play_particle_effects(impact_direction: Vector3):
	# Rotate particle systems to match impact direction
	var rotation_basis = Basis.looking_at(impact_direction.normalized(), Vector3.UP)
	
	impact_sparks.global_transform.basis = rotation_basis
	impact_smoke.global_transform.basis = rotation_basis
	burst_impact.global_transform.basis = rotation_basis
	
	# Restart all particle systems
	impact_sparks.restart()
	impact_smoke.restart()
	burst_impact.restart()

func _flash_impact_light():
	# Create a red-orange flash effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Light intensity flash
	impact_light.light_energy = 4.0
	impact_light.light_color = Color(1, 0.3, 0, 1)  # Red-orange
	
	tween.tween_property(impact_light, "light_energy", 0.0, 0.8)
	tween.tween_property(impact_light, "light_color", Color(0.5, 0.1, 0, 1), 0.4)
	tween.tween_property(impact_light, "light_color", Color(1, 0.3, 0, 1), 0.4)

func _play_screen_effects():
	# Screen shake effect
	if player_camera:
		_shake_camera()
	
	# Damage flash effect
	_flash_damage_screen()

func _shake_camera():
	if player_camera:
		# Create simple screen shake using camera transform
		var original_transform = player_camera.global_transform
		var shake_duration = 0.5
		var shake_intensity = 0.1
		
		screen_shake_timer = Timer.new()
		add_child(screen_shake_timer)
		screen_shake_timer.wait_time = shake_duration
		screen_shake_timer.timeout.connect(_stop_camera_shake.bind(original_transform))
		
		# Start shake
		_update_camera_shake(original_transform, shake_intensity)
		screen_shake_timer.start()

func _update_camera_shake(original_transform: Transform3D, intensity: float):
	if not screen_shake_timer or not screen_shake_timer.time_left:
		return
		
	# Apply random offset
	var offset = Vector3(
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity),
		randf_range(-intensity, intensity)
	)
	
	player_camera.global_transform = original_transform.translated(offset)
	
	# Continue shaking
	await get_tree().create_timer(0.05).timeout
	if screen_shake_timer and screen_shake_timer.time_left > 0:
		_update_camera_shake(original_transform, intensity * 0.8)  # Decrease intensity over time

func _stop_camera_shake(original_transform: Transform3D):
	if player_camera:
		player_camera.global_transform = original_transform
	
	if screen_shake_timer:
		screen_shake_timer.queue_free()
		screen_shake_timer = null

func _flash_damage_screen():
	# Create a red damage flash
	damage_flash.visible = true
	damage_flash.color = Color(1, 0, 0, 0.3)
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Flash effect
	tween.tween_property(damage_flash, "color:a", 0.0, 0.3)
	tween.tween_callback(func(): damage_flash.visible = false).set_delay(0.3)

func _play_impact_sound():
	if audio.stream:
		audio.pitch_scale = randf_range(0.8, 1.2)  # Pitch variation
		audio.volume_db = randf_range(-3, 0)  # Slight volume variation
		audio.play()

func _start_cleanup_timer():
	# Remove the VFX node after effects complete
	var cleanup_timer = Timer.new()
	add_child(cleanup_timer)
	cleanup_timer.wait_time = 3.0
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
static func create_collision_vfx_at_position(position: Vector3, impact_direction: Vector3, parent_node: Node) -> Node3D:
	var vfx_scene = preload("res://Scenes/VFX/ObstacleCollisionVFX.tscn")
	var vfx_instance = vfx_scene.instantiate()
	
	# Add to parent and set position
	parent_node.add_child(vfx_instance)
	vfx_instance.global_position = position
	
	# Play the effects
	vfx_instance.play_collision_vfx(impact_direction)
	
	return vfx_instance
