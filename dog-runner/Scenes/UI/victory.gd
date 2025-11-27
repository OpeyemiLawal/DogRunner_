extends Control

# Victory animation variables
var victory_alpha: float = 0.0
var victory_state: String = "hidden"  # "hidden", "fading_in", "visible", "fading_out"
const FADE_DURATION = 1.2  # Longer for more dramatic effect
var victory_timer: float = 0.0
var entrance_complete: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Remove white outline from all buttons
	for child in get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
	
	# Start hidden and with no transparency
	visible = true
	victory_state = "fading_in"
	victory_alpha = 0.0
	_set_victory_alpha(0.0)
	
	# Hide navbar for cleaner victory presentation
	_hide_navbar()
	
	# Start entrance animation
	_animate_victory_entrance()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Update victory animations
	_update_victory_animation(delta)

func _update_victory_animation(delta: float):
	match victory_state:
		"fading_in":
			victory_alpha += delta / FADE_DURATION
			if victory_alpha >= 1.0:
				victory_alpha = 1.0
				victory_state = "visible"
				victory_timer = 0.0
				entrance_complete = true
			_set_victory_alpha(victory_alpha)
			
		"visible":
			victory_timer += delta
			# Add very subtle pulse effect only to main victory text
			var pulse = sin(victory_timer * 1.5) * 0.01 + 1.0  # Gentler and slower
			var victory_sprite = get_node_or_null("Victory")
			if victory_sprite:
				victory_sprite.scale = Vector2(pulse, pulse)
			
		"fading_out":
			victory_alpha -= delta / (FADE_DURATION * 0.8)  # Faster fade out
			if victory_alpha <= 0.0:
				victory_alpha = 0.0
				victory_state = "hidden"
				visible = false
				_show_navbar()  # Show navbar again
				_reset_scales()
			_set_victory_alpha(victory_alpha)

func _set_victory_alpha(alpha: float):
	# Apply alpha to all child nodes with staggered timing for professional effect
	var delay = 0.0
	for child in get_children():
		if child is Sprite2D or child is Label or child is Button:
			var child_alpha = alpha
			# Stagger the fade-in for different elements
			if victory_state == "fading_in" and alpha < 1.0:
				if child.name == "Victory":
					child_alpha = max(0.0, alpha - delay * 2)  # Victory text first
				elif child.name == "MissonComplete":
					child_alpha = max(0.0, alpha - delay * 3)  # Mission complete second
				elif child.name.begins_with("Label"):
					child_alpha = max(0.0, alpha - delay * 4)  # Labels third
				else:  # Buttons
					child_alpha = max(0.0, alpha - delay * 5)  # Buttons last
				delay += 0.1
			
			var modulate = child.modulate
			modulate.a = child_alpha
			child.modulate = modulate

func _reset_scales():
	# Reset all scales to original values
	var victory_sprite = get_node_or_null("Victory")
	if victory_sprite:
		victory_sprite.scale = Vector2(1.2076701, 1.1759002)  # Original scale from scene
	
	var mission_complete = get_node_or_null("MissonComplete")
	if mission_complete:
		mission_complete.scale = Vector2(1.325615, 1.5457064)  # Original scale from scene

func _animate_victory_entrance():
	# Professional AAA-style entrance with multiple stages
	
	# Stage 1: Victory text dramatic entrance
	var victory_sprite = get_node_or_null("Victory")
	if victory_sprite:
		# Start very small and rotated for dramatic effect
		victory_sprite.scale = Vector2(0.1, 0.1)
		victory_sprite.rotation = deg_to_rad(15)
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Main bounce with rotation correction
		tween.tween_property(victory_sprite, "scale", Vector2(1.4, 1.4), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tween.tween_property(victory_sprite, "rotation", 0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Settle to final position
		tween.tween_property(victory_sprite, "scale", Vector2(1.2076701, 1.1759002), 0.4).set_delay(0.8).set_ease(Tween.EASE_IN)
	
	# Stage 2: Mission Complete text (no continuous animation)
	var mission_complete = get_node_or_null("MissonComplete")
	if mission_complete:
		# Start from above with rotation
		mission_complete.scale = Vector2(0.1, 0.1)
		mission_complete.rotation = deg_to_rad(-10)
		var original_pos = mission_complete.position
		mission_complete.position.y -= 100
		
		var tween2 = create_tween()
		tween2.set_parallel(true)
		
		# Drop in with bounce
		tween2.tween_property(mission_complete, "scale", Vector2(1.5, 1.8), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		tween2.tween_property(mission_complete, "position:y", original_pos.y, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		tween2.tween_property(mission_complete, "rotation", 0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Settle to final scale (no more animation)
		tween2.tween_property(mission_complete, "scale", Vector2(1.325615, 1.5457064), 0.3).set_delay(0.7).set_ease(Tween.EASE_IN)
	
	# Stage 3: Labels fade in with slight scale
	_animate_labels_entrance()
	
	# Stage 4: Buttons slide in from bottom
	_animate_buttons_entrance()

func _animate_labels_entrance():
	var labels = ["Label", "Label2", "Label3", "Label4", "Label5"]
	var delay = 0.0
	
	for label_name in labels:
		var label = get_node_or_null(label_name)
		if label:
			var original_scale = label.scale
			label.scale = Vector2(0.8, 0.8)
			
			# Create delayed tween using scene tree timer
			var timer = get_tree().create_timer(delay)
			timer.timeout.connect(func():
				var tween = create_tween()
				tween.tween_property(label, "scale", original_scale * 1.1, 0.3).set_ease(Tween.EASE_OUT)
				tween.tween_property(label, "scale", original_scale, 0.2).set_ease(Tween.EASE_IN).set_delay(0.3)
			)
			
			delay += 0.1

func _animate_buttons_entrance():
	var buttons = ["Next Misson2", "Next Misson3", "Next Misson4"]
	var delay = 0.0
	
	for button_name in buttons:
		var button = get_node_or_null(button_name)
		if button:
			var original_pos = button.position
			button.position.y += 200  # Start below screen
			button.scale = Vector2(0.9, 0.9)
			
			# Create delayed tween using scene tree timer
			var timer = get_tree().create_timer(delay)
			timer.timeout.connect(func():
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(button, "position:y", original_pos.y, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
			)
			
			delay += 0.15

func _hide_navbar():
	# Hide the navbar for cleaner victory screen
	var world_generator = get_tree().get_first_node_in_group("world_generator")
	if world_generator and world_generator.has_node("NavBar"):
		world_generator.get_node("NavBar").visible = false

func _show_navbar():
	# Show the navbar again when victory screen closes
	var world_generator = get_tree().get_first_node_in_group("world_generator")
	if world_generator and world_generator.has_node("NavBar"):
		world_generator.get_node("NavBar").visible = true

func start_victory_animation():
	# Reset and start victory animation
	victory_state = "fading_in"
	victory_alpha = 0.0
	entrance_complete = false
	_set_victory_alpha(0.0)
	_hide_navbar()
	_animate_victory_entrance()

func hide_victory_screen():
	# Start fade out animation
	victory_state = "fading_out"
