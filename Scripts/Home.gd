extends Control

# ==============================================================================
# Home — Base of operations screen
# ------------------------------------------------------------------------------
# Handles all at-home activities: sleeping, cooking, reading, etc.
# Time advancement and stat changes go through PlayerData so this script
# does not need any reference to the main scene tree.
# ==============================================================================


# ==============================================================================
# Button handlers (wired in the editor)
# ==============================================================================

func _on_sleep_pressed() -> void:
	PlayerData.add_time(8, 0)
	# TODO: restore stamina, reduce sickness, etc.


func _on_watch_tv_pressed() -> void:
	# TODO: advance time, improve happiness via PlayerData
	pass


func _on_prepare_food_pressed() -> void:
	# TODO: open cooking interface
	pass


func _on_read_pressed() -> void:
	# TODO: advance time, improve happiness or skill via PlayerData
	pass


func _on_generator_pressed() -> void:
	# TODO: open generator management interface
	pass
