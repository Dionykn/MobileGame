extends Control

@onready var MainScene = get_node("/root/Node2D")

func _ready():
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass


func _on_sleep_pressed():
	MainScene.hours += 8
