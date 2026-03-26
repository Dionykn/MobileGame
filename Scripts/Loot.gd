extends Control

# ==============================================================================
# Loot — Item pickup popup
# ------------------------------------------------------------------------------
# Shown when the player searches an area. Displays found items as buttons
# and lets the player take all or leave them behind.
#
# Call show_loot(items) from Adventure.gd to populate and display this panel.
# ==============================================================================

# --- Node references ----------------------------------------------------------
@onready var found_label:    Label         = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer2/Label
@onready var grid_container: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer/PanelContainer/GridContainer

# The items currently shown in the popup
var _current_loot: Array = []


# ==============================================================================
# Public API
# ==============================================================================

# Populates the grid with item buttons and displays the popup.
# Called by Adventure.gd with an Array of item Dictionaries.
func show_loot(items: Array) -> void:
	_current_loot = items
	_clear_grid()

	var count := items.size()

	# Update the header label
	if count == 1:
		found_label.text = "You found 1 item"
	else:
		found_label.text = "You found %d items" % count

	# Create one button per item — button text is the item name
	for item in items:
		var btn := Button.new()
		btn.text = "   " + item["Item Name"] + "   "
		btn.custom_minimum_size = Vector2(64, 64)
		# Individual item selection can be wired here in the future
		grid_container.add_child(btn)

# ==============================================================================
# Button handlers (wired in the editor)
# ==============================================================================

func _on_take_all_pressed() -> void:
	# Add every item in the current loot to the player's inventory
	for item in _current_loot:
		PlayerData.add_to_inventory(item)
	_close()


func _on_leave_pressed() -> void:
	_close()


# ==============================================================================
# Internal helpers
# ==============================================================================

func _close() -> void:
	_current_loot = []
	_clear_grid()
	visible = false


# Removes all dynamically created item buttons from the grid
func _clear_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
