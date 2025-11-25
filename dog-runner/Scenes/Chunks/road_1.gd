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
@onready var right_prop_15: Node3D = $PropsPlaceholderRight/RightProp15

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
				   right_prop_11, right_prop_12, right_prop_13, right_prop_14,right_prop_15]
	
	# Hide all props initially
	_hide_all_props()
	
	# Randomly show 1 left and 1 right prop
	call_deferred("_show_random_props")

func _hide_all_props():
	# Hide all left props
	for prop in left_props:
		if prop:
			prop.visible = false
	
	# Hide all right props
	for prop in right_props:
		if prop:
			prop.visible = false

func _show_random_props():
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
