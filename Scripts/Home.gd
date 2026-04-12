extends Control

# ==============================================================================
# Home — Base of operations screen
# ------------------------------------------------------------------------------
# Handles all at-home activities: sleeping, cooking, reading, etc.
# Time advancement and stat changes go through PlayerData so this script
# does not need any reference to the main scene tree.
#
# SLEEP
# -----
# The sleep button is only enabled when endurance is at or below 50.
# Sleeping runs minute-by-minute via PlayerData.sleep_minutes(), restoring
# endurance and draining nourishment and hydration until:
#   - endurance reaches 100, or
#   - any vital stat hits the interrupt threshold (10).
# Sleep runs for up to 8 in-game hours by default (480 minutes).
# ==============================================================================

const MAX_SLEEP_MINUTES := 480   # 8 hours
const SLEEP_ENABLE_THRESHOLD := 50.0


func _ready() -> void:
	PlayerData.stats_changed.connect(_on_stats_changed)
	_refresh_sleep_button()


# ==============================================================================
# Stats change handler
# ==============================================================================

func _on_stats_changed() -> void:
	_refresh_sleep_button()


func _refresh_sleep_button() -> void:
	var btn: Button = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/Sleep
	btn.disabled = PlayerData.endurance > SLEEP_ENABLE_THRESHOLD


# ==============================================================================
# Button handlers (wired in the editor)
# ==============================================================================

func _on_sleep_pressed() -> void:
	var slept :int = PlayerData.sleep_minutes(MAX_SLEEP_MINUTES)
	# slept contains the number of in-game minutes elapsed.
	# The clock and all stat changes have already been applied inside sleep_minutes().
	# TODO: show a brief summary to the player (e.g. "You slept for X hours.").
	_refresh_sleep_button()


func _on_watch_tv_pressed() -> void:
	# TODO: advance time, improve happiness via PlayerData.
	pass


func _on_prepare_food_pressed() -> void:
	# TODO: open cooking interface.
	pass


func _on_read_pressed() -> void:
	# TODO: advance time, improve happiness or skill via PlayerData.
	pass


func _on_generator_pressed() -> void:
	# TODO: open generator management interface.
	pass
