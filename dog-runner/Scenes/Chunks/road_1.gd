extends Node3D

#left prop
@onready var left_prop_1: Node3D = $leftProps/prop1
@onready var left_prop_2: Node3D = $leftProps/prop2
@onready var left_prop_3: Node3D = $leftProps/prop3
@onready var left_prop_4: Node3D = $leftProps/prop4
@onready var left_prop_5: Node3D = $leftProps/prop5
@onready var left_prop_6: Node3D = $leftProps/prop6
@onready var left_prop_7: Node3D = $leftProps/prop7
@onready var left_prop_8: Node3D = $leftProps/prop8
@onready var left_prop_9: Node3D = $leftProps/prop9
@onready var left_prop_10: Node3D = $leftProps/prop10
@onready var left_prop_11: Node3D = $leftProps/prop11
@onready var left_prop_12: Node3D = $leftProps/prop12
@onready var left_prop_13: Node3D = $leftProps/prop13
@onready var left_prop_14: Node3D = $leftProps/prop14
@onready var left_prop_15: Node3D = $leftProps/prop15

#right prop
@onready var right_prop_1: Node3D = $PropsPlaceholderRight/RightProp1
@onready var right_prop_2: Node3D = $PropsPlaceholderRight/RightProp2
@onready var right_prop_3: Node3D = $PropsPlaceholderRight/RightProp3
@onready var right_prop_4: Node3D = $PropsPlaceholderRight/RightProp4
@onready var right_prop_5: Node3D = $PropsPlaceholderRight/RightProp5
@onready var right_prop_6: Node3D = $PropsPlaceholderRight/RightProp6
@onready var right_prop_7: Node3D = $PropsPlaceholderRight/RightProp7
@onready var right_prop_8: Node3D = $PropsPlaceholderRight/RightProp8
@onready var right_prop_9: Node3D = $PropsPlaceholderRight/RightProp9
@onready var right_prop_10: Node3D = $PropsPlaceholderRight/RightProp10
@onready var right_prop_11: Node3D = $PropsPlaceholderRight/RightProp11
@onready var right_prop_12: Node3D = $PropsPlaceholderRight/RightProp12
@onready var right_prop_13: Node3D = $PropsPlaceholderRight/RightProp13
@onready var right_prop_14: Node3D = $PropsPlaceholderRight/RightProp14

var rng: RandomNumberGenerator

# Arrays to hold all prop references
var left_props: Array[Node3D] = []
var right_props: Array[Node3D] = []

func _ready():
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Initialize prop arrays
	left_props = [left_prop_1, left_prop_2, left_prop_3, left_prop_4, left_prop_5, 
				  left_prop_6, left_prop_7, left_prop_8, left_prop_9, left_prop_10,
				  left_prop_11, left_prop_12, left_prop_13, left_prop_14, left_prop_15]
	
	right_props = [right_prop_1, right_prop_2, right_prop_3, right_prop_4, right_prop_5,
				   right_prop_6, right_prop_7, right_prop_8, right_prop_9, right_prop_10,
				   right_prop_11, right_prop_12, right_prop_13, right_prop_14]
	
	# Hide all props initially and ensure clean state
	_hide_all_props()
	
	# Randomly show 1 left and 1 right prop
	call_deferred("_show_random_props")

func _exit_tree():
	# Clean up when chunk is removed
	_hide_all_props()

func _hide_all_props():
	# Aggressively hide all left props
	for prop in left_props:
		if prop:
			prop.visible = false
			prop.process_mode = Node.PROCESS_MODE_DISABLED  # Disable processing too
	
	# Aggressively hide all right props
	for prop in right_props:
		if prop:
			prop.visible = false
			prop.process_mode = Node.PROCESS_MODE_DISABLED  # Disable processing too

func _show_random_props():
	# First ensure all props are hidden (safety check)
	_hide_all_props()
	
	# Define primary props that should always be active
	var primary_props = [1, 7, 14, 13, 11, 10, 9]  # prop numbers
	var secondary_props = [2, 3, 4, 5, 6, 8, 12, 15]  # remaining props
	
	# Select 1 random primary prop
	var random_primary_index = rng.randi() % primary_props.size()
	var selected_primary = primary_props[random_primary_index]
	
	# Select 1 random secondary prop
	var random_secondary_index = rng.randi() % secondary_props.size()
	var selected_secondary = secondary_props[random_secondary_index]
	
	# Randomly assign primary and secondary to left/right sides
	if rng.randf() < 0.5:
		# Primary on left, secondary on right
		_show_prop_by_number(selected_primary, "left")
		_show_prop_by_number(selected_secondary, "right")
	else:
		# Secondary on left, primary on right
		_show_prop_by_number(selected_secondary, "left")
		_show_prop_by_number(selected_primary, "right")
	
	# Debug: Count visible props to ensure only 2 are showing
	_debug_visible_props()

func _show_prop_by_number(prop_number: int, side: String):
	var prop_node = null
	
	# Convert prop number to actual node (1-based index)
	var prop_index = prop_number - 1
	
	if side == "left":
		if prop_index >= 0 and prop_index < left_props.size():
			prop_node = left_props[prop_index]
	else:  # right side
		if prop_index >= 0 and prop_index < right_props.size():
			prop_node = right_props[prop_index]
	
	if prop_node:
		prop_node.visible = true
		print("Showing prop", prop_number, " on ", side, " side")

func _debug_visible_props():
	var left_visible_count = 0
	var right_visible_count = 0
	var left_visible_props = []
	var right_visible_props = []
	
	# Check left props with detailed info
	for i in range(left_props.size()):
		var prop = left_props[i]
		if prop and prop.visible:
			left_visible_count += 1
			left_visible_props.append("prop" + str(i + 1) + " at " + str(prop.global_position))
	
	# Check right props with detailed info
	for i in range(right_props.size()):
		var prop = right_props[i]
		if prop and prop.visible:
			right_visible_count += 1
			right_visible_props.append("prop" + str(i + 1) + " at " + str(prop.global_position))
	
	# Enhanced debug output with chunk identification
	var chunk_id = str(self.get_instance_id())[-4]  # Last 4 digits of instance ID
	print("=== CHUNK ", chunk_id, " DEBUG ===")
	print("Chunk position: ", global_position)
	print("Left props (", left_visible_count, "): ", left_visible_props)
	print("Right props (", right_visible_count, "): ", right_visible_props)
	print("Total: ", left_visible_count + right_visible_count, " props")
	
	# Safety warnings
	if left_visible_count > 1:
		print("❌ ERROR: Too many left props on chunk ", chunk_id, ": ", left_visible_props)
		print("🔧 HIDING EXTRA LEFT PROPS...")
		# Hide all but first left prop
		var hidden = 0
		for i in range(left_props.size()):
			var prop = left_props[i]
			if prop and prop.visible:
				if hidden > 0:
					prop.visible = false
					print("  → Hidden left prop", (i + 1))
				hidden += 1
	
	if right_visible_count > 1:
		print("❌ ERROR: Too many right props on chunk ", chunk_id, ": ", right_visible_props)
		print("🔧 HIDING EXTRA RIGHT PROPS...")
		# Hide all but first right prop
		var hidden = 0
		for i in range(right_props.size()):
			var prop = right_props[i]
			if prop and prop.visible:
				if hidden > 0:
					prop.visible = false
					print("  → Hidden right prop", (i + 1))
				hidden += 1
	
	if left_visible_count + right_visible_count > 2:
		print("❌ ERROR: Too many total props on chunk ", chunk_id)
		print("🔧 FORCING CLEANUP...")
		_hide_all_props()
		_show_random_props()  # Try again
	else:
		print("✅ OK: Chunk ", chunk_id, " has correct prop count")
	print("=========================")

# Strict validation - runs every frame to enforce prop limits
func _process(delta):
	_strict_prop_validation()

func _strict_prop_validation():
	var left_visible_count = 0
	var right_visible_count = 0
	
	# Count visible left props
	for prop in left_props:
		if prop and prop.visible:
			left_visible_count += 1
	
	# Count visible right props  
	for prop in right_props:
		if prop and prop.visible:
			right_visible_count += 1
	
	# Strict enforcement: max 1 prop per side
	if left_visible_count > 1:
		print("STRICT: Too many left props (", left_visible_count, "), hiding extras...")
		var hidden_count = 0
		for prop in left_props:
			if prop and prop.visible:
				if hidden_count > 0:  # Keep first visible, hide rest
					prop.visible = false
					prop.process_mode = Node.PROCESS_MODE_DISABLED
				hidden_count += 1
	
	if right_visible_count > 1:
		print("STRICT: Too many right props (", right_visible_count, "), hiding extras...")
		var hidden_count = 0
		for prop in right_props:
			if prop and prop.visible:
				if hidden_count > 0:  # Keep first visible, hide rest
					prop.visible = false
					prop.process_mode = Node.PROCESS_MODE_DISABLED
				hidden_count += 1
