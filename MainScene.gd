extends Node2D

# Clock variables
var hours = 6
var minutes = 0
var days = 1

func _ready():
	$Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Date.text = "Day 1   06:00"

# Runs every 10s
func _on_clock_timeout():
	# Increment minutes directly
	minutes += 1
	print_debug(minutes)
	# Handle time rollovers
	if minutes >= 60:
		minutes = 0
		hours += 1
	if hours >= 24:
		hours = 0
		days += 1
	# Format and display the time
	var formatted_time = "%02d:" % hours + "%02d" % minutes
	$Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Date.text = "Day " + str(days) +"   "+ str(formatted_time)

# Runs every frame
func _process(_delta):
	disable_navbutton()

func _on_home_pressed():
	$Gameplay/Home_tscn.visible = true
	$Gameplay/Survivor_tscn.visible = false
	$Gameplay/Adventure_tscn.visible = false


func _on_adventure_pressed():
	$Gameplay/Home_tscn.visible = false
	$Gameplay/Survivor_tscn.visible = false
	$Gameplay/Adventure_tscn.visible = true
	
	
func _on_survivor_pressed():
	$Gameplay/Home_tscn.visible = false
	$Gameplay/Survivor_tscn.visible = true
	$Gameplay/Adventure_tscn.visible = false


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

