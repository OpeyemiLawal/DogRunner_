extends Control

@onready var health_label: Label = $HealthHUD/HealthLabel
@onready var coin_label: Label = $TextureRect/CoinLabel

# Health bar segments
@onready var health_hud: TextureRect = $HealthHUD
@onready var bar1: TextureRect = $HealthHUD/Bar1
@onready var bar2: TextureRect = $HealthHUD/Bar2
@onready var bar3: TextureRect = $HealthHUD/Bar3
@onready var bar4: TextureRect = $HealthHUD/Bar4
@onready var bar5: TextureRect = $HealthHUD/Bar5
@onready var bar6: TextureRect = $HealthHUD/Bar6
@onready var bar7: TextureRect = $HealthHUD/Bar7
@onready var bar8: TextureRect = $HealthHUD/Bar8
@onready var bar9: TextureRect = $HealthHUD/Bar9
@onready var bar10: TextureRect = $HealthHUD/Bar10

var player: CharacterBody3D
var world_generator: Node

func _ready():
	# Find the player and world generator
	player = get_tree().get_first_node_in_group("player")
	world_generator = get_tree().get_first_node_in_group("world_generator")
	
	if player:
		# Connect to player signals if they exist
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
	
	# Update display every frame
	set_process(true)

func _process(delta):
	if player:
		update_health_display()
		update_coin_display()

func update_health_display():
	if player and health_label:
		var health = player.get("health") if player.has_method("get") else 100
		health_label.text = str(health) + "/100"
		
		# Update health bar segments
		_update_health_bars(health)
		
		# Change color based on health
		#if health <= 30:
			#health_label.modulate = Color.RED
		#elif health <= 60:
			#health_label.modulate = Color.YELLOW
		#else:
			#health_label.modulate = Color.GREEN

func _update_health_bars(health: int):
	# Show/hide health bar segments based on health
	# Each bar represents 10 health points
	
	# Bar 10 (90-100 health)
	bar10.visible = health >= 90
	
	# Bar 9 (80-89 health)
	bar9.visible = health >= 80
	
	# Bar 8 (70-79 health)
	bar8.visible = health >= 70
	
	# Bar 7 (60-69 health)
	bar7.visible = health >= 60
	
	# Bar 6 (50-59 health)
	bar6.visible = health >= 50
	
	# Bar 5 (40-49 health)
	bar5.visible = health >= 40
	
	# Bar 4 (30-39 health)
	bar4.visible = health >= 30
	
	# Bar 3 (20-29 health)
	bar3.visible = health >= 20
	
	# Bar 2 (10-19 health)
	bar2.visible = health >= 10
	
	# Bar 1 (0-9 health)
	bar1.visible = health >= 0

func _on_health_changed(new_health: int):
	update_health_display()

func reset_hud():
	if player:
		update_health_display()

func update_coin_display():
	if player and coin_label:
		var coins = player.get_coins() if player.has_method("get_coins") else 0
		coin_label.text = str(coins)
		
		# Make coins golden color
		coin_label.modulate = Color.GOLD

func update_all_displays():
	update_health_display()
	update_coin_display()

func set_coin_display(coin_count: int):
	if coin_label:
		coin_label.text = str(coin_count)
		coin_label.modulate = Color.GOLD
