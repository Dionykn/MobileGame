extends Control

# ==============================================================================
# ItemContext — Item detail popup
# ------------------------------------------------------------------------------
# Shown when the player taps an inventory item.
#
# Condition section shows up to three progress bars:
#   Freshness  — fresh food and opened stable food; decays over time.
#   Portion    — consumable items; how much of the item remains.
#   Durability — equipment; read from instance["durability"], not item dict.
#                Shows as "Broken" when at 0; effects are nullified.
#
# Stable food shows an "Open" button instead of consume actions when sealed.
# Once opened, freshness appears and consume actions become available.
# ==============================================================================

const THRESH_RED    := 0.33
const THRESH_YELLOW := 0.67

# --- Static node references (from tscn) --------------------------------------
@onready var label_category:     Label         = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer2/Label5
@onready var label_name:         Label         = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer2/Label
@onready var label_weight:       Label         = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer2/Label5
@onready var label_effects_vbox: VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer
@onready var label_desc:         Label         = $MarginContainer/MarginContainer/VBoxContainer/ScrollContainer/Label
@onready var condition_section:  VBoxContainer = $MarginContainer/MarginContainer/VBoxContainer/VBoxContainer3
@onready var action_grid:        GridContainer = $MarginContainer/MarginContainer/VBoxContainer/GridContainer
@onready var close_btn:          Button        = $MarginContainer/Button
@onready var tex_icon:           TextureRect   = $MarginContainer/MarginContainer/VBoxContainer/HBoxContainer/TextureRect

# --- Dynamically created condition bars --------------------------------------
var _bar_freshness:  ProgressBar = null
var _bar_portion:    ProgressBar = null
var _bar_durability: ProgressBar = null
var _lbl_freshness:  Label       = null
var _lbl_portion:    Label       = null
var _lbl_durability: Label       = null

# The instance currently shown.
var _instance: Dictionary = {}

signal action_taken


# ==============================================================================
# Lifecycle
# ==============================================================================

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(_close)
	_build_condition_section()


func _build_condition_section() -> void:
	for child in condition_section.get_children():
		child.queue_free()

	condition_section.add_theme_constant_override("separation", 6)

	_lbl_freshness  = _make_bar_label("Freshness")
	_bar_freshness  = _make_progress_bar()
	_lbl_portion    = _make_bar_label("Portion")
	_bar_portion    = _make_progress_bar()
	_lbl_durability = _make_bar_label("Condition")
	_bar_durability = _make_progress_bar()

	condition_section.add_child(_lbl_freshness)
	condition_section.add_child(_bar_freshness)
	condition_section.add_child(_lbl_portion)
	condition_section.add_child(_bar_portion)
	condition_section.add_child(_lbl_durability)
	condition_section.add_child(_bar_durability)

	_set_bar_visible(_lbl_freshness,  _bar_freshness,  false)
	_set_bar_visible(_lbl_portion,    _bar_portion,    false)
	_set_bar_visible(_lbl_durability, _bar_durability, false)


func _make_bar_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _make_progress_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value     = 100.0
	bar.rounded   = true
	bar.show_percentage = true
	bar.add_theme_color_override("font_color",         Color.WHITE)
	bar.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	bar.add_theme_constant_override("outline_size", 2)
	bar.add_theme_font_size_override("font_size", 18)
	bar.custom_minimum_size = Vector2(0, 28)
	return bar


func _set_bar_visible(lbl: Label, bar: ProgressBar, show: bool) -> void:
	lbl.visible = show
	bar.visible = show


# ==============================================================================
# Public API
# ==============================================================================

func show_item(instance: Dictionary) -> void:
	_instance = instance
	var item: Dictionary = instance["item"]

	_populate_header(item, instance["count"])
	_populate_weight(item, instance["count"])
	_populate_effects(item, instance["freshness"], instance["portion"], instance["durability"])
	_populate_condition(instance)
	_populate_description(item)
	_populate_actions(item, instance["instance_id"], instance["count"], instance["opened"])

	visible = true


# ==============================================================================
# Population helpers
# ==============================================================================

func _populate_header(item: Dictionary, count: int) -> void:
	var categories = item.get("Loot Category", "")
	if categories is Array:
		label_category.text = " / ".join(categories)
	else:
		label_category.text = str(categories)

	var name_text: String = item.get("Item Name", "Unknown")
	if count > 1:
		name_text += "  (%d)" % count
	label_name.text = name_text


func _populate_weight(item: Dictionary, count: int) -> void:
	var unit_weight:  float = float(item.get("Weight", 0.0))
	var total_weight: float = unit_weight * count
	if count > 1:
		label_weight.text = "%.2f kg  (%.2f kg total)" % [unit_weight, total_weight]
	else:
		label_weight.text = "%.2f kg" % unit_weight


# Effects for consumables are scaled by freshness and portion.
# Effects for broken equipment show as "(Broken)" instead of their value.
func _populate_effects(item: Dictionary, freshness: float, portion: float, durability: float) -> void:
	var children := label_effects_vbox.get_children()
	for i in range(1, children.size()):
		children[i].queue_free()

	var is_broken: bool = _is_equippable(item) and durability <= 0.0
	var effects: Array[String] = _get_effect_strings(item, freshness, portion, is_broken)

	if effects.is_empty():
		var lbl := Label.new()
		lbl.text = "None"
		lbl.add_theme_font_size_override("font_size", 18)
		label_effects_vbox.add_child(lbl)
	else:
		for effect_text in effects:
			var lbl := Label.new()
			lbl.text = effect_text
			lbl.add_theme_font_size_override("font_size", 18)
			label_effects_vbox.add_child(lbl)


func _get_effect_strings(item: Dictionary, freshness: float, portion: float, is_broken: bool) -> Array[String]:
	var out: Array[String] = []

	var fresh_ratio:   float = (freshness / 100.0) if _is_fresh_food(item) else 1.0
	var portion_ratio: float = portion / 100.0
	var scale:         float = fresh_ratio * portion_ratio

	if item.has("Nutrition"):
		out.append("Nourishment %+.0f" % (float(item["Nutrition"]) * scale))
	if item.has("Hydration"):
		out.append("Hydration %+.0f" % (float(item["Hydration"]) * scale))
	if item.has("Happiness"):
		out.append("Happiness %+.0f" % (float(item["Happiness"]) * scale))
	if item.has("Endurance"):
		out.append("Endurance %+.0f" % (float(item["Endurance"]) * scale))
	if item.has("Damage"):
		if is_broken:
			out.append("Damage: (Broken)")
		else:
			out.append("Damage: %.0f" % float(item["Damage"]))
	if item.has("Protection"):
		if is_broken:
			out.append("Protection: (Broken)")
		else:
			out.append("Protection: %.0f" % float(item["Protection"]))
	if item.has("Encumbrance"):
		if is_broken:
			out.append("Carry capacity: (Broken)")
		else:
			out.append("Carry capacity +%.0f kg" % float(item["Encumbrance"]))
	if item.has("Capacity"):
		out.append("Container: %.1f L" % float(item["Capacity"]))
	return out


func _populate_condition(instance: Dictionary) -> void:
	var item:       Dictionary = instance["item"]
	var freshness:  float      = instance["freshness"]
	var portion:    float      = instance["portion"]
	var durability: float      = instance["durability"]
	var opened:     bool       = instance["opened"]

	var is_fresh:  bool = _is_fresh_food(item)
	var is_opened: bool = _is_stable_food(item) and opened
	var is_cons:   bool = _is_consumable(item) and (is_fresh or is_opened or not _is_stable_food(item))
	var has_dur:   bool = _is_equippable(item)

	# Freshness bar — fresh food and opened stable food.
	_set_bar_visible(_lbl_freshness, _bar_freshness, is_fresh or is_opened)
	if is_fresh or is_opened:
		_bar_freshness.value = freshness
		_apply_bar_color(_bar_freshness, freshness)

	# Portion bar — any consumable that is available to consume.
	_set_bar_visible(_lbl_portion, _bar_portion, is_cons)
	if is_cons:
		_bar_portion.value = portion
		_apply_bar_color(_bar_portion, portion)

	# Durability bar — any equippable item; reads from instance, not item dict.
	_set_bar_visible(_lbl_durability, _bar_durability, has_dur)
	if has_dur:
		_bar_durability.value = durability
		_apply_bar_color(_bar_durability, durability)
		# Override label to signal broken state clearly.
		_lbl_durability.text = "Condition — BROKEN" if durability <= 0.0 else "Condition"

	condition_section.visible = is_fresh or is_opened or is_cons or has_dur


func _apply_bar_color(bar: ProgressBar, value: float) -> void:
	var pct := value / 100.0
	var fill_color: Color
	if pct > THRESH_YELLOW:
		fill_color = Color(0.2, 0.8, 0.2)
	elif pct > THRESH_RED:
		fill_color = Color(0.9, 0.8, 0.2)
	else:
		fill_color = Color(0.8, 0.2, 0.2)

	var style := StyleBoxFlat.new()
	style.bg_color                   = fill_color
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color                   = Color(0.15, 0.15, 0.15, 0.9)
	bg_style.corner_radius_top_left     = 4
	bg_style.corner_radius_top_right    = 4
	bg_style.corner_radius_bottom_left  = 4
	bg_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg_style)


func _populate_description(item: Dictionary) -> void:
	label_desc.text = item.get("Description", "No description available.")


# ==============================================================================
# Action buttons
# ==============================================================================

func _populate_actions(item: Dictionary, instance_id: int, count: int, opened: bool) -> void:
	for child in action_grid.get_children():
		child.queue_free()

	var is_fresh:      bool  = _is_fresh_food(item)
	var is_stable:     bool  = _is_stable_food(item)
	var is_literature: bool  = _is_literature(item)
	var equip_slots:   Array = PlayerData.get_equip_slots(item)
	var is_equippable: bool  = not equip_slots.is_empty()

	if is_literature:
		_add_action_button("Read", func(): _on_consume(instance_id, 1.0))

	elif is_stable and not opened:
		# Sealed stable food: only allow opening.
		_add_action_button("Open", func(): _on_open_stable(instance_id))

	elif is_fresh or (is_stable and opened):
		# Fresh food or opened stable food: full consume options.
		_add_action_button("Consume",      func(): _on_consume(instance_id, 1.0))
		_add_action_button("Consume half", func(): _on_consume(instance_id, 0.5))
		_add_action_button("Consume 1/4",  func(): _on_consume(instance_id, 0.25))

	elif _is_consumable(item):
		# Other consumables (drinks, alcohol, etc.).
		_add_action_button("Consume",      func(): _on_consume(instance_id, 1.0))
		_add_action_button("Consume half", func(): _on_consume(instance_id, 0.5))
		_add_action_button("Consume 1/4",  func(): _on_consume(instance_id, 0.25))

	if is_equippable:
		if equip_slots.size() == 1:
			_add_action_button("Equip", func(): _on_equip(instance_id, equip_slots[0]))
		else:
			for slot in equip_slots:
				var captured_slot: String = slot
				_add_action_button("Equip: " + slot, func(): _on_equip(instance_id, captured_slot))

	_add_action_button("Drop", func(): _on_drop(instance_id, false))
	if count > 1:
		_add_action_button("Drop all", func(): _on_drop(instance_id, true))


# ==============================================================================
# Item type helpers
# ==============================================================================

func _is_consumable(item: Dictionary) -> bool:
	return item.has("Nutrition") or item.has("Hydration") \
		or item.has("Happiness") or item.has("Endurance")


func _is_fresh_food(item: Dictionary) -> bool:
	var cat = item.get("Loot Category", "")
	if cat is Array:
		return cat.has("Fresh food")
	return cat == "Fresh food"


func _is_stable_food(item: Dictionary) -> bool:
	var cat = item.get("Loot Category", "")
	if cat is Array:
		return cat.has("Stable food")
	return cat == "Stable food"


func _is_literature(item: Dictionary) -> bool:
	var cat = item.get("Loot Category", "")
	if cat is Array:
		return cat.has("Literature")
	return cat == "Literature"


func _is_equippable(item: Dictionary) -> bool:
	return item.has("Equip")


func _add_action_button(label_text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(128, 48)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(callback)
	action_grid.add_child(btn)


# ==============================================================================
# Action handlers
# ==============================================================================

func _on_consume(instance_id: int, fraction: float) -> void:
	var instance = PlayerData.get_instance(instance_id)
	if instance == null:
		_close()
		return

	var item:      Dictionary = instance["item"]
	var freshness: float      = instance["freshness"]
	var portion:   float      = instance["portion"]
	var is_fresh:  bool       = _is_fresh_food(item)

	var fresh_ratio:   float = (freshness / 100.0) if is_fresh else 1.0
	var portion_ratio: float = portion / 100.0
	var effective:     float = fresh_ratio * portion_ratio * fraction

	if item.has("Nutrition"):
		PlayerData.nourishment = clampf(PlayerData.nourishment + float(item["Nutrition"]) * effective, 0.0, 100.0)
	if item.has("Hydration"):
		PlayerData.hydration   = clampf(PlayerData.hydration   + float(item["Hydration"])  * effective, 0.0, 100.0)
	if item.has("Happiness"):
		PlayerData.happiness   = clampf(PlayerData.happiness   + float(item["Happiness"])  * effective, 0.0, 100.0)
	if item.has("Endurance"):
		PlayerData.endurance   = clampf(PlayerData.endurance   + float(item["Endurance"])  * effective, 0.0, 100.0)

	if fraction >= 1.0:
		PlayerData.remove_from_inventory(instance_id)
		PlayerData.notify_stats_changed()
		action_taken.emit()
		_close()
	else:
		instance["portion"] = maxf(portion - fraction * 100.0, 0.0)
		if instance["portion"] <= 0.0:
			PlayerData.remove_from_inventory(instance_id)
			PlayerData.notify_stats_changed()
			action_taken.emit()
			_close()
		else:
			PlayerData.notify_stats_changed()
			action_taken.emit()
			_populate_effects(item, instance["freshness"], instance["portion"], instance["durability"])
			_populate_condition(instance)
			_populate_actions(item, instance_id, instance["count"], instance["opened"])


# Opens a sealed stable food item, giving it a freshness bar and enabling
# consume actions. The instance is mutated in place.
func _on_open_stable(instance_id: int) -> void:
	if PlayerData.open_item(instance_id):
		var instance = PlayerData.get_instance(instance_id)
		if instance == null:
			_close()
			return
		action_taken.emit()
		# Refresh the popup to show freshness bar and consume buttons.
		show_item(instance)
	else:
		_close()


func _on_equip(instance_id: int, slot: String) -> void:
	var instance = PlayerData.get_instance(instance_id)
	if instance == null:
		_close()
		return
	PlayerData.equip_item(instance_id, slot)
	action_taken.emit()
	_close()


func _on_drop(instance_id: int, drop_all: bool) -> void:
	if drop_all:
		var instance = PlayerData.get_instance(instance_id)
		if instance == null:
			_close()
			return
		var count: int = instance["count"]
		for _i in count:
			PlayerData.remove_from_inventory(instance_id)
	else:
		PlayerData.remove_from_inventory(instance_id)
	action_taken.emit()
	_close()


# ==============================================================================
# Internal helpers
# ==============================================================================

func _close() -> void:
	_instance = {}
	visible   = false
