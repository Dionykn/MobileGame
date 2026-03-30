extends Control

# ==============================================================================
# Loot — Item pickup popup
# ------------------------------------------------------------------------------
# Shown when the player searches an area. Displays found items as buttons
# and lets the player take all, take individual items, or leave them behind.
#
# Call show_loot(items) from Adventure.gd to populate and display this panel.
# ==============================================================================

# --- Node references ----------------------------------------------------------
@onready var found_label:    Label         = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer2/Label
@onready var grid_container: GridContainer = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer/PanelContainer/GridContainer
@onready var btn_take_all:   Button        = $MarginContainer/PanelContainer/VBoxContainer/MarginContainer3/HBoxContainer/TakeAll

# The items currently shown in the popup.
# Stored as an Array of Dictionaries so individual items can be spliced out.
var _current_loot: Array = []


# ==============================================================================
# Public API
# ==============================================================================

# Populates the grid with item buttons and displays the popup.
# Called by Adventure.gd with an Array of item Dictionaries.
func show_loot(items: Array) -> void:
	_current_loot = items.duplicate()
	_rebuild_grid()


# ==============================================================================
# Grid helpers
# ==============================================================================

# Clears and rebuilds the grid to match _current_loot.
# Called on first show and after any individual item is taken.
func _rebuild_grid() -> void:
	_clear_grid()
	_update_header_label()

	btn_take_all.visible = not _current_loot.is_empty()

	for i in _current_loot.size():
		var item: Dictionary = _current_loot[i]
		var btn              := Button.new()
		btn.text             = "   " + item["Item Name"] + "   "
		btn.custom_minimum_size = Vector2(64, 64)
		btn.set_meta("loot_index", i)
		btn.pressed.connect(_on_item_button_pressed.bind(i))
		grid_container.add_child(btn)


func _update_header_label() -> void:
	var count := _current_loot.size()
	if count == 0:
		found_label.text = "No items found"
	elif count == 1:
		found_label.text = "You found 1 item"
	else:
		found_label.text = "You found %d items" % count


# ==============================================================================
# Button handlers
# ==============================================================================

func _on_item_button_pressed(index: int) -> void:
	if index < 0 or index >= _current_loot.size():
		return

	var item: Dictionary = _current_loot[index]
	PlayerData.add_to_inventory(item)
	_current_loot.remove_at(index)

	if _current_loot.is_empty():
		_close()
	else:
		_rebuild_grid()


func _on_take_all_pressed() -> void:
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


func _clear_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
