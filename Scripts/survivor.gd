extends Control

# ==============================================================================
# Survivor — Player status screen
# ==============================================================================

const HEALTH_THRESHOLDS := { "red": 0.33, "yellow": 0.67 }

const BODY_PART_FILENAMES: Dictionary = {
	"head":       "Head",
	"abdomen":    "Abdomen",
	"left_arm":   "Left arm",
	"left_hand":  "Left hand",
	"left_leg":   "Left leg",
	"right_arm":  "Right arm",
	"right_hand": "Right hand",
	"right_leg":  "Right leg",
}

const CONDITION_FOLDERS: Dictionary = {
	"Healthy":  "Healthy",
	"Hurt":     "Hurt",
	"Healed":   "Healed",
	"Bleeding": "Bleeding",
}

const SLOT_NODE_NAMES: Dictionary = {
	"Hat":        "HBoxContainer",
	"Top":        "HBoxContainer2",
	"Pants":      "HBoxContainer3",
	"Shoes":      "HBoxContainer4",
	"Gloves":     "HBoxContainer5",
	"Backpack":   "HBoxContainer6",
	"Sling":      "HBoxContainer7",
	"Waist":      "HBoxContainer8",
	"Left hand":  "HBoxContainer9",
	"Right hand": "HBoxContainer10",
}

# --- Section containers -------------------------------------------------------
@onready var section_body_condition: Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext
@onready var section_vital_signs:    Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext
@onready var section_equipment:      Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/EquipmentContext
@onready var section_inventory:      Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/InventoryContext
@onready var section_skills:         Control = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/SkillsContext

# --- Vital signs bars ---------------------------------------------------------
@onready var bar_health:       TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Health/TextureProgressBar
@onready var bar_hydration:    TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Hydration/TextureProgressBar
@onready var bar_nourishment:  TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Nourishment/TextureProgressBar
@onready var bar_stamina:      TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Stamina/TextureProgressBar
@onready var bar_endurance:    TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Endurance/TextureProgressBar
@onready var bar_happiness:    TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Happiness/TextureProgressBar
@onready var bar_encumbrance:  TextureProgressBar = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/VitalSignsContext/VBoxContainer/Encumbrance/TextureProgressBar

# --- Body condition buttons ---------------------------------------------------
@onready var btn_head:       Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer/Button
@onready var btn_torso:      Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer2/Button
@onready var btn_left_arm:   Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer3/Button
@onready var btn_left_hand:  Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer4/Button
@onready var btn_left_leg:   Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer5/Button
@onready var btn_right_arm:  Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer6/Button
@onready var btn_right_hand: Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer7/Button
@onready var btn_right_leg:  Button = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/VBoxContainer/HBoxContainer8/Button

# --- Body part TextureRects ---------------------------------------------------
@onready var tex_head:       TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/Head
@onready var tex_torso:      TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/Torso
@onready var tex_left_arm:   TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/LeftArm
@onready var tex_left_hand:  TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/LeftHand
@onready var tex_left_leg:   TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/LeftLeg
@onready var tex_right_arm:  TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/RightArm
@onready var tex_right_hand: TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/RightHand
@onready var tex_right_leg:  TextureRect = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/BodyConditionContext/HBoxContainer/BodyTextures/RightLeg

var _body_textures: Dictionary = {}

# --- Equipment grid -----------------------------------------------------------
@onready var equipment_grid: GridContainer = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/EquipmentContext/GridContainer

# --- Inventory grid -----------------------------------------------------------
@onready var inventory_grid: GridContainer = $MarginContainer/PanelContainer/ScrollContainer/VBoxContainer/InventoryContext/GridContainer

# --- Item context popup -------------------------------------------------------
# Loaded from ItemContext.tscn and added as a child so it renders on top.
var _item_context: Control = null

# --- Slot picker popup --------------------------------------------------------
var _slot_picker:         Control = null
var _pending_instance_id: int     = -1


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	_body_textures = {
		"head":       tex_head,
		"abdomen":    tex_torso,
		"left_arm":   tex_left_arm,
		"left_hand":  tex_left_hand,
		"left_leg":   tex_left_leg,
		"right_arm":  tex_right_arm,
		"right_hand": tex_right_hand,
		"right_leg":  tex_right_leg,
	}

	const BAR_RATIO := 100.0 / 1000.0
	for bar in [bar_health, bar_hydration, bar_nourishment,
				bar_stamina, bar_endurance, bar_happiness, bar_encumbrance]:
		bar.resized.connect(func():
			bar.custom_minimum_size.y = bar.size.x * BAR_RATIO
		)

	inventory_grid.size_flags_horizontal = Control.SIZE_FILL
	inventory_grid.resized.connect(_update_grid_columns)

	_wire_equipment_slot_buttons()
	_build_slot_picker()
	_build_item_context()

	PlayerData.stats_changed.connect(_refresh_ui)
	PlayerData.item_added.connect(_on_item_added)
	PlayerData.item_updated.connect(_on_item_updated)
	PlayerData.item_removed.connect(_on_item_removed)

	_refresh_ui()
	_rebuild_inventory_grid()


# ==============================================================================
# Item context popup
# ==============================================================================

func _build_item_context() -> void:
	var packed: PackedScene = load("res://Scenes/ItemContext.tscn")
	if packed == null:
		push_error("Survivor: could not load res://Scenes/ItemContext.tscn")
		return
	_item_context = packed.instantiate()
	# Connect close / action signals before adding to tree.
	_item_context.action_taken.connect(_on_item_context_action_taken)
	# Add on top of everything in this scene.
	add_child(_item_context)


func _show_item_context(instance_id: int) -> void:
	if _item_context == null:
		return
	var instance = PlayerData.get_instance(instance_id)
	if instance == null:
		return
	_item_context.show_item(instance)


func _on_item_context_action_taken() -> void:
	# No extra work needed — PlayerData signals already drive the grid updates.
	pass


# ==============================================================================
# Equipment slot buttons
# ==============================================================================

func _wire_equipment_slot_buttons() -> void:
	for slot in SLOT_NODE_NAMES:
		var hbox = equipment_grid.get_node_or_null(SLOT_NODE_NAMES[slot])
		if hbox == null:
			push_warning("Survivor: could not find equipment HBox '%s'" % SLOT_NODE_NAMES[slot])
			continue
		var btn: Button = hbox.get_node_or_null("Button")
		if btn == null:
			continue
		var captured_slot: String = slot
		btn.pressed.connect(func(): _on_equipment_slot_pressed(captured_slot))


func _refresh_equipment_labels() -> void:
	for slot in SLOT_NODE_NAMES:
		var hbox = equipment_grid.get_node_or_null(SLOT_NODE_NAMES[slot])
		if hbox == null:
			continue
		var label: Label = hbox.get_node_or_null("Label")
		if label == null:
			continue
		label.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var equipped = PlayerData.equipment.get(slot, null)
		label.text = equipped["Item Name"] if equipped != null else "None"


func _on_equipment_slot_pressed(slot: String) -> void:
	if PlayerData.equipment.get(slot) == null:
		return
	PlayerData.unequip_slot(slot)


# ==============================================================================
# Slot picker popup
# ==============================================================================

func _build_slot_picker() -> void:
	_slot_picker = Control.new()
	_slot_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_picker.visible = false

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.6)
	_slot_picker.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	_slot_picker.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Equip in which slot?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(lbl)
	vbox.set_meta("slot_label", lbl)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.add_theme_font_size_override("font_size", 22)
	cancel.custom_minimum_size = Vector2(200, 64)
	cancel.pressed.connect(func(): _slot_picker.visible = false)
	vbox.add_child(cancel)
	vbox.set_meta("cancel_btn", cancel)

	add_child(_slot_picker)


func _show_slot_picker(instance_id: int, slots: Array) -> void:
	_pending_instance_id = instance_id
	var vbox: VBoxContainer = _slot_picker.get_child(1).get_child(0)

	var label_node  = vbox.get_meta("slot_label")
	var cancel_node = vbox.get_meta("cancel_btn")
	for child in vbox.get_children():
		if child != label_node and child != cancel_node:
			child.queue_free()

	for slot in slots:
		var btn := Button.new()
		btn.text = slot
		btn.add_theme_font_size_override("font_size", 22)
		btn.custom_minimum_size = Vector2(200, 64)
		var captured_slot: String = slot
		btn.pressed.connect(func(): _on_slot_picked(captured_slot))
		vbox.add_child(btn)
		vbox.move_child(cancel_node, vbox.get_child_count() - 1)

	_slot_picker.visible = true


func _on_slot_picked(slot: String) -> void:
	_slot_picker.visible = false
	if _pending_instance_id == -1:
		return
	PlayerData.equip_item(_pending_instance_id, slot)
	_pending_instance_id = -1


# ==============================================================================
# UI refresh
# ==============================================================================

func _refresh_ui() -> void:
	_refresh_vital_signs()
	_refresh_body_condition()
	_refresh_body_textures()
	_refresh_equipment_labels()


func _refresh_vital_signs() -> void:
	bar_health.value      = PlayerData.health
	bar_hydration.value   = PlayerData.hydration
	bar_nourishment.value = PlayerData.nourishment
	bar_stamina.value     = PlayerData.stamina
	bar_endurance.value   = PlayerData.endurance
	bar_happiness.value   = PlayerData.happiness

	_update_progress_bar_color(bar_health,      PlayerData.health)
	_update_progress_bar_color(bar_hydration,   PlayerData.hydration)
	_update_progress_bar_color(bar_nourishment, PlayerData.nourishment)
	_update_progress_bar_color(bar_stamina,     PlayerData.stamina)
	_update_progress_bar_color(bar_endurance,   PlayerData.endurance)
	_update_progress_bar_color(bar_happiness,   PlayerData.happiness)

	_refresh_encumbrance_bar()


func _refresh_encumbrance_bar() -> void:
	var carried  := PlayerData.get_carried_weight()
	var capacity := PlayerData.get_carry_capacity()
	var pct      := clampf((carried / capacity) * 100.0, 0.0, 100.0) if capacity > 0.0 else 0.0

	bar_encumbrance.value = pct

	# Inverted color logic: green when light, yellow when heavy, red when full.
	if pct >= HEALTH_THRESHOLDS["yellow"] * 100.0:
		bar_encumbrance.tint_progress = Color(0.8, 0.2, 0.2)
	elif pct >= HEALTH_THRESHOLDS["red"] * 100.0:
		bar_encumbrance.tint_progress = Color(0.9, 0.8, 0.2)
	else:
		bar_encumbrance.tint_progress = Color(0.2, 0.8, 0.2)


func _refresh_body_condition() -> void:
	btn_head.text       = PlayerData.body_condition.get("head",       "Healthy")
	btn_torso.text      = PlayerData.body_condition.get("abdomen",    "Healthy")
	btn_left_arm.text   = PlayerData.body_condition.get("left_arm",   "Healthy")
	btn_left_hand.text  = PlayerData.body_condition.get("left_hand",  "Healthy")
	btn_left_leg.text   = PlayerData.body_condition.get("left_leg",   "Healthy")
	btn_right_arm.text  = PlayerData.body_condition.get("right_arm",  "Healthy")
	btn_right_hand.text = PlayerData.body_condition.get("right_hand", "Healthy")
	btn_right_leg.text  = PlayerData.body_condition.get("right_leg",  "Healthy")


func _refresh_body_textures() -> void:
	for part_key in _body_textures:
		var tex_rect:  TextureRect = _body_textures[part_key]
		var condition: String      = PlayerData.body_condition.get(part_key, "Healthy")
		var filename:  String      = BODY_PART_FILENAMES.get(part_key, "")
		if filename.is_empty():
			continue
		var folder: String = CONDITION_FOLDERS.get(condition, "Healthy")
		var path:   String = "res://Images/%s/%s.png" % [folder, filename]
		var tex = load(path)
		if tex != null:
			tex_rect.texture = tex
		else:
			push_warning("Survivor: texture not found — %s" % path)


# ==============================================================================
# Helpers
# ==============================================================================

func _update_grid_columns() -> void:
	var col_width := 125 + inventory_grid.get_theme_constant("h_separation")
	inventory_grid.columns = max(1, int(inventory_grid.size.x / col_width))


func _update_progress_bar_color(bar: TextureProgressBar, value: float, max_value: float = 100.0) -> void:
	var pct := value / max_value
	if pct <= HEALTH_THRESHOLDS["red"]:
		bar.tint_progress = Color(0.8, 0.2, 0.2)
	elif pct <= HEALTH_THRESHOLDS["yellow"]:
		bar.tint_progress = Color(0.9, 0.8, 0.2)
	else:
		bar.tint_progress = Color(0.2, 0.8, 0.2)


# ==============================================================================
# Inventory grid — instance-based
# ==============================================================================

func _rebuild_inventory_grid() -> void:
	for child in inventory_grid.get_children():
		child.queue_free()
	for instance in PlayerData.inventory:
		_create_inventory_button(instance)


func _create_inventory_button(instance: Dictionary) -> void:
	var item:  Dictionary = instance["item"]
	var count: int        = instance["count"]
	var btn               := Button.new()
	btn.text                  = item["Item Name"] + ("\nx%d" % count if count > 1 else "")
	btn.custom_minimum_size   = Vector2(125, 125)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	btn.set_meta("instance_id", instance["instance_id"])
	btn.pressed.connect(_on_inventory_item_pressed.bind(instance["instance_id"]))
	inventory_grid.add_child(btn)


func _on_inventory_item_pressed(instance_id: int) -> void:
	# Always open the ItemContext popup — it handles all actions internally.
	_show_item_context(instance_id)


# --- Surgical inventory signal handlers ---------------------------------------

func _on_item_added(instance: Dictionary) -> void:
	_create_inventory_button(instance)
	_refresh_encumbrance_bar()


func _on_item_updated(instance_id: int, new_count: int) -> void:
	for btn in inventory_grid.get_children():
		if btn.get_meta("instance_id") == instance_id:
			var inst = PlayerData.get_instance(instance_id)
			if inst == null:
				return
			var item_name: String = inst["item"]["Item Name"]
			btn.text = item_name + ("\nx%d" % new_count if new_count > 1 else "")
			_refresh_encumbrance_bar()
			return


func _on_item_removed(instance_id: int) -> void:
	for btn in inventory_grid.get_children():
		if btn.get_meta("instance_id") == instance_id:
			btn.queue_free()
			_refresh_encumbrance_bar()
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
