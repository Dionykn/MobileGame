extends Node2D

# ==============================================================================
# MainScene — Root scene controller
# ------------------------------------------------------------------------------
# Manages the in-game clock and switches between the three main views:
# Home, Adventure and Survivor.
#
# Time and location state live in PlayerData. The status bar listens to
# stats_changed so it refreshes automatically whenever anything changes.
# ==============================================================================

# --- Node references ----------------------------------------------------------
@onready var date_label:     Label   = $Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Date
@onready var location_label: Label   = $Statusbar/Control/PanelContainer/MarginContainer/HBoxContainer/Location

@onready var home_scene:      Control = $Gameplay/Home_tscn
@onready var adventure_scene: Control = $Gameplay/Adventure_tscn
@onready var survivor_scene:  Control = $Gameplay/Survivor_tscn

@onready var btn_home:      Button = $Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Home
@onready var btn_adventure: Button = $Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Adventure
@onready var btn_survivor:  Button = $Navigationbar/Control/PanelContainer/MarginContainer/HBoxContainer/Survivor


func _ready() -> void:
	PlayerData.stats_changed.connect(_update_status_bar)
	# Initialise location to Home before showing the first scene
	PlayerData.current_location = StaticData.areaData["1"]
	_show_scene(home_scene)
	_update_status_bar()


# ==============================================================================
# Clock
# ==============================================================================

# Called by the Clock Timer node (set to fire every 6 seconds = 1 in-game minute).
# Delegates to PlayerData.add_time() which handles carry and emits stats_changed,
# so _update_status_bar fires automatically.
func _on_clock_timeout() -> void:
	PlayerData.add_time(0, 1)


func _update_status_bar() -> void:
	date_label.text     = "Day %d   %02d:%02d" % [PlayerData.days, PlayerData.hours, PlayerData.minutes]
	location_label.text = PlayerData.current_location.get("Area Name", "")


# ==============================================================================
# Navigation
# ==============================================================================

func _on_home_pressed() -> void:
	_show_scene(home_scene)
	adventure_scene.set_location_to_home()


func _on_adventure_pressed() -> void:
	_show_scene(adventure_scene)


func _on_survivor_pressed() -> void:
	_show_scene(survivor_scene)


# Shows the given scene and hides the others.
# Also disables the nav button for the currently active scene.
func _show_scene(scene: Control) -> void:
	home_scene.visible      = (scene == home_scene)
	adventure_scene.visible = (scene == adventure_scene)
	survivor_scene.visible  = (scene == survivor_scene)

	btn_home.disabled      = (scene == home_scene)
	btn_adventure.disabled = (scene == adventure_scene)
	btn_survivor.disabled  = (scene == survivor_scene)
