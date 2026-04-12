extends Node2D

# ==============================================================================
# MainScene — Root scene controller
# ------------------------------------------------------------------------------
# Manages the in-game clock and switches between the three main views:
# Home, Adventure and Survivor.
#
# Time and location state live in PlayerData. The status bar listens to
# stats_changed so it refreshes automatically whenever anything changes.
#
# SAVING
# ------
# A full save is written when the player arrives home.
# When the app goes to the background on Android, a resume-only save is written
# so the OS cannot silently kill a run. That resume save is deleted on the next
# clean home-arrival save.
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
	if PlayerData.new_game:
		# Initialise location to Home before showing the first scene.
		PlayerData.current_location = StaticData.get_area(1)
		_show_scene(home_scene)
		PlayerData.save_game()
	else:
		_show_scene(adventure_scene)
		PlayerData.notify_stats_changed()
	_update_status_bar()


# ==============================================================================
# Android background handling
# ==============================================================================

func _notification(what: int) -> void:
	if what == 2007: # NOTIFICATION_WM_GO_BACKGROUND
		PlayerData.save_resume()


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
	_arrive_home()


func _on_adventure_pressed() -> void:
	_show_scene(adventure_scene)


func _on_survivor_pressed() -> void:
	_show_scene(survivor_scene)


# Called when the player legitimately arrives home (nav bar or go-home button).
# Resets adventure state, saves, and switches to the home screen.
func _arrive_home() -> void:
	adventure_scene.set_location_to_home()
	_show_scene(home_scene)
	PlayerData.save_game()


# Shows the given scene and hides the others.
# Also disables the nav button for the currently active scene.
func _show_scene(scene: Control) -> void:
	home_scene.visible      = (scene == home_scene)
	adventure_scene.visible = (scene == adventure_scene)
	survivor_scene.visible  = (scene == survivor_scene)

	btn_home.disabled      = (scene == home_scene)
	btn_adventure.disabled = (scene == adventure_scene)
	btn_survivor.disabled  = (scene == survivor_scene)
