extends Node2D

# Clock variables
@export var hours = 6
@export var minutes = 0
@export var days = 1
@export var formatted_time = "%02d:" % hours + "%02d" % minutes


func _ready():
	$Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Date.text = "Day 1   06:00"
	

# Runs every 10s
func _on_clock_timeout():
	# Increment minutes directly
	minutes += 1


# Runs every frame
func _process(_delta):
	# Disable navigation button to current scene
	disable_navbutton()
	# Handle time rollovers
	if minutes >= 60:
		minutes -= 60
		hours += 1
	if hours >= 24:
		hours -= 24
		days += 1
	# Format and update the time
	var previous_time = formatted_time
	formatted_time = "%02d:" % hours + "%02d" % minutes
	if formatted_time != previous_time:
		$Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Date.text = "Day " + str(days) +"   "+ str(formatted_time)

# Set Home as visible scene
func _on_home_pressed():
	$Gameplay/Home_tscn.visible = true
	$Gameplay/Survivor_tscn.visible = false
	$Gameplay/Adventure_tscn.visible = false

# Set Adventure as visible scene
func _on_adventure_pressed():
	$Gameplay/Home_tscn.visible = false
	$Gameplay/Survivor_tscn.visible = false
	$Gameplay/Adventure_tscn.visible = true

# Set Survivor as visible scene	
func _on_survivor_pressed():
	$Gameplay/Home_tscn.visible = false
	$Gameplay/Survivor_tscn.visible = true
	$Gameplay/Adventure_tscn.visible = false

# Disable navigation button to current scene
func disable_navbutton():
	if $Gameplay/Home_tscn.visible == true:
		$Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Home.disabled = true
	else:
		$Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Home.disabled = false
	
	if $Gameplay/Survivor_tscn.visible == true:
		$Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Survivor.disabled = true
	else:
		$Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Survivor.disabled = false
	
	if $Gameplay/Adventure_tscn.visible == true:
		$Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Adventure.disabled = true
	else:
		$Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Adventure.disabled = false

