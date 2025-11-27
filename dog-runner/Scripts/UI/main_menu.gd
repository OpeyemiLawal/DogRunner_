extends Control

func _ready() -> void:
	# Remove white outline from all menu buttons
	for child in get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/World1.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
