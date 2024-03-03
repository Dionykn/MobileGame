extends Node

var itemData = {}
var areaData = {}
var item_data_path = "res://Data/Items.json"
var area_data_path = "res://Data/Areas.json"

func _ready():
	itemData = load_json_file(item_data_path)
	areaData = load_json_file(area_data_path)


func load_json_file(filePath : String):
	if FileAccess.file_exists(filePath):
		var dataFile = FileAccess.open(filePath, FileAccess.READ)
		var parsedResult = JSON.parse_string(dataFile.get_as_text())
		if parsedResult is Dictionary:
			print("Data imported")
			return parsedResult
		else:
			print("Error reading file")
	else:
		print("File doesn't exist!")
