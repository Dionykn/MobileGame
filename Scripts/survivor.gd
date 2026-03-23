extends Control

# ==============================================================================
# Survivor — Player status screen
# ------------------------------------------------------------------------------
# Displays all player stats, body condition, equipment and inventory by reading
# from the PlayerData singleton. Updates whenever PlayerData emits stats_changed.
#
# The collapsible sections (Body Condition, Vital Signs, Equipment, Inventory)
# are toggled by CheckButtons wired in the editor.
# ==============================================================================

# --- Vital Signs labels -------------------------------------------------------
# Each stat row has a TextureRect for the bar — wire these in the editor
# once you have per-value bar textures. For now the labels show numeric values.
@onready var section_body_condition: Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext
@onready var section_vital_signs: Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext
@onready var section_equipment: Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/EquipmentContext
@onready var section_inventory: Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/InventoryContext
@onready var section_skills: Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/SkillsContext

# --- Inventory grid -----------------------------------------------------------
@onready var inventory_grid: GridContainer = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/InventoryContext/GridContainer


func _ready() -> void:
	# Listen for any stat or inventory changes so we can refresh the UI
	PlayerData.stats_changed.connect(_refresh_ui)
	_refresh_ui()


# ==============================================================================
# UI refresh
# ==============================================================================

# Called whenever PlayerData changes. Re-reads all values and updates labels.
func _refresh_ui() -> void:
	_refresh_inventory()
	# TODO: refresh vital signs bar textures once per-value assets are available
	# TODO: refresh equipment slot labels from PlayerData.equipment
	# TODO: refresh body condition labels from PlayerData.body_condition


# Clears and rebuilds the inventory grid from PlayerData.inventory
func _refresh_inventory() -> void:
	# Remove old buttons
	for child in inventory_grid.get_children():
		child.queue_free()

	# Create one button per item in the player's inventory
	for item in PlayerData.inventory:
		var btn := Button.new()
		btn.text = item["Item Name"]
		btn.custom_minimum_size = Vector2(125, 125)
		inventory_grid.add_child(btn)
		# TODO: connect button press to item use / drop context menu


# ==============================================================================
# Collapsible section toggles (wired in the editor)
# ==============================================================================

func _on_body_condition_toggled(toggled_on: bool) -> void:
	section_body_condition.visible = toggled_on

func _on_vital_signs_toggled(toggled_on: bool) -> void:
	section_vital_signs.visible = toggled_on

func _on_equipment_toggled(toggled_on: bool) -> void:
	section_equipment.visible = toggled_on

func _on_inventory_toggled(toggled_on: bool) -> void:
	section_inventory.visible = toggled_on

func _on_skills_toggled(toggled_on: bool) -> void:
	section_skills.visible = toggled_on
