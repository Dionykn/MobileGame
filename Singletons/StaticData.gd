extends Node

# ==============================================================================
# StaticData — Autoload Singleton
# ------------------------------------------------------------------------------
# Loads and holds all read-only game data from JSON files.
# Accessible globally as StaticData.itemData, StaticData.areaData, etc.
# ==============================================================================

var itemData: Dictionary = {}
var areaData: Dictionary = {}

const ITEM_DATA_PATH := "res://Data/Items.json"
const AREA_DATA_PATH := "res://Data/Areas.json"


func _ready() -> void:
	itemData = _load_json(ITEM_DATA_PATH)
	areaData = _load_json(AREA_DATA_PATH)
	_normalise_item_categories()


# ------------------------------------------------------------------------------
# Returns the item dictionary for a given numeric ID, or null if not found.
# Usage: StaticData.get_item(1007)
# ------------------------------------------------------------------------------
func get_item(id: int) -> Variant:
	var key := str(id)
	if itemData.has(key):
		return itemData[key]
	push_warning("StaticData: item ID %d not found." % id)
	return null


# ------------------------------------------------------------------------------
# Loads a JSON file and returns it as a Dictionary.
# Returns an empty Dictionary and prints an error if anything goes wrong.
# ------------------------------------------------------------------------------
func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("StaticData: file not found — %s" % path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())

	if parsed == null:
		push_error("StaticData: failed to parse JSON — %s" % path)
		return {}

	if not parsed is Dictionary:
		push_error("StaticData: expected a Dictionary in — %s" % path)
		return {}

	print("StaticData: loaded %s" % path)
	return parsed


# ------------------------------------------------------------------------------
# Normalises the "Loot Category" field on every item so it is always an Array.
# In the raw JSON some items have a String, others already have an Array.
# After this runs, all code can safely treat Loot Category as an Array.
# ------------------------------------------------------------------------------
func _normalise_item_categories() -> void:
	for key in itemData:
		var item: Dictionary = itemData[key]
		if item.has("Loot Category") and item["Loot Category"] is String:
			item["Loot Category"] = [item["Loot Category"]]
