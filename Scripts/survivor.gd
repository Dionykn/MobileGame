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

# --- Constants -------------------------------------------------------
const HEALTH_THRESHOLDS = {
	"red": 0.33,    # 0-33%
	"yellow": 0.67  # 34-66%, green is above this
}

# --- Section containers -------------------------------------------------------
@onready var section_body_condition: Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext
@onready var section_vital_signs:    Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext
@onready var section_equipment:      Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/EquipmentContext
@onready var section_inventory:      Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/InventoryContext
@onready var section_skills:         Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/SkillsContext

# --- Vital signs bars ---------------------------------------------------------
@onready var bar_health:      TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Health/TextureProgressBar
@onready var bar_hydration:   TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Hydration/TextureProgressBar
@onready var bar_nourishment: TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Nourishment/TextureProgressBar
@onready var bar_stamina:     TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Stamina/TextureProgressBar
@onready var bar_endurance:   TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Endurance/TextureProgressBar
@onready var bar_happiness:   TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Happiness/TextureProgressBar

# --- Body condition buttons ---------------------------------------------------
@onready var btn_head:       Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer/Button
@onready var btn_torso:      Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer2/Button
@onready var btn_left_arm:   Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer3/Button
@onready var btn_left_hand:  Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer4/Button
@onready var btn_left_leg:   Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer5/Button
@onready var btn_right_arm:  Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer6/Button
@onready var btn_right_hand: Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer7/Button
@onready var btn_right_leg:  Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer8/Button

# --- Inventory grid -----------------------------------------------------------
@onready var inventory_grid: GridContainer = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/InventoryContext/GridContainer


func _ready() -> void:
	inventory_grid.size_flags_horizontal = Control.SIZE_FILL
	inventory_grid.resized.connect(_update_grid_columns)
	PlayerData.stats_changed.connect(_refresh_ui)
	PlayerData.item_added.connect(_on_item_added)
	PlayerData.item_updated.connect(_on_item_updated)
	PlayerData.item_removed.connect(_on_item_removed)
	_refresh_ui()
	# Populate inventory grid from whatever PlayerData already holds.
	# This covers the load-from-save case where item_added fired before
	# this scene existed and connected its signals.
	_rebuild_inventory_grid()


# ==============================================================================
# UI refresh
# ==============================================================================

# Called on stats_changed — refreshes bars and body condition only.
# Inventory is handled surgically via item_added/updated/removed signals.
func _refresh_ui() -> void:
	_refresh_vital_signs()
	_refresh_body_condition()
	# TODO: refresh equipment slot labels from PlayerData.equipment


# Modify your _refresh_vital_signs function:
func _refresh_vital_signs() -> void:
	bar_health.value = PlayerData.health
	bar_hydration.value = PlayerData.hydration
	bar_nourishment.value = PlayerData.nourishment
	bar_stamina.value = PlayerData.stamina
	bar_endurance.value = PlayerData.endurance
	bar_happiness.value = PlayerData.happiness
	
	# Update colors based on current values
	_update_progress_bar_color(bar_health, PlayerData.health)
	_update_progress_bar_color(bar_hydration, PlayerData.hydration)
	_update_progress_bar_color(bar_nourishment, PlayerData.nourishment)
	_update_progress_bar_color(bar_stamina, PlayerData.stamina)
	_update_progress_bar_color(bar_endurance, PlayerData.endurance)
	_update_progress_bar_color(bar_happiness, PlayerData.happiness)


func _refresh_body_condition() -> void:
	btn_head.text       = PlayerData.body_condition.get("head",       "Healthy")
	btn_torso.text      = PlayerData.body_condition.get("abdomen",    "Healthy")
	btn_left_arm.text   = PlayerData.body_condition.get("left_arm",   "Healthy")
	btn_left_hand.text  = PlayerData.body_condition.get("left_hand",  "Healthy")
	btn_left_leg.text   = PlayerData.body_condition.get("left_leg",   "Healthy")
	btn_right_arm.text  = PlayerData.body_condition.get("right_arm",  "Healthy")
	btn_right_hand.text = PlayerData.body_condition.get("right_hand", "Healthy")
	btn_right_leg.text  = PlayerData.body_condition.get("right_leg",  "Healthy")


# Helpers
func _update_grid_columns() -> void:
	var column_width := 125 + inventory_grid.get_theme_constant("h_separation")
	inventory_grid.columns = max(1, int(inventory_grid.size.x / column_width))

# This function handles color updates for any progress bar
func _update_progress_bar_color(progress_bar: TextureProgressBar, value: float, max_value: float = 100.0) -> void:
	var percentage = value / max_value
	
	if percentage <= HEALTH_THRESHOLDS["red"]:
		progress_bar.tint_progress = Color(0.8, 0.2, 0.2)  # Red
	elif percentage <= HEALTH_THRESHOLDS["yellow"]:
		progress_bar.tint_progress = Color(0.9, 0.8, 0.2)  # Yellow
	else:
		progress_bar.tint_progress = Color(0.2, 0.8, 0.2)  # Green

# ==============================================================================
# Inventory — surgical updates via PlayerData signals
# ==============================================================================

# Reads PlayerData.inventory directly and builds a button for every stack.
# Called once on _ready() to catch items loaded from a save file.


func _rebuild_inventory_grid() -> void:
	for id in PlayerData.inventory:
		var entry: Dictionary = PlayerData.inventory[id]
		_create_inventory_button(entry["item"], entry["count"])


func _create_inventory_button(item: Dictionary, count: int) -> void:
	var btn := Button.new()
	btn.text = item["Item Name"] + "\nx" + str(count)
	btn.custom_minimum_size = Vector2(125, 125)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.set_meta("item_id", item["ID"])
	inventory_grid.add_child(btn)
	# TODO: connect button press to item use / drop context menu


# Called when a brand-new stack is added during gameplay.
func _on_item_added(item: Dictionary) -> void:
	_create_inventory_button(item, 1)


func _on_item_updated(item_id: int, new_count: int) -> void:
	for btn in inventory_grid.get_children():
		if btn.get_meta("item_id") == item_id:
			var item_name: String = PlayerData.inventory[item_id]["item"]["Item Name"]
			btn.text = item_name + "\nx" + str(new_count)
			return


func _on_item_removed(item_id: int) -> void:
	for btn in inventory_grid.get_children():
		if btn.get_meta("item_id") == item_id:
			btn.queue_free()
			return


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
