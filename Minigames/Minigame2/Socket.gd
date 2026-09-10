extends Node2D
class_name Socket

const COLORS := [
	Color(0.85, 0.15, 0.15), 
	Color(0.60, 0.20, 0.85), 
	Color(0.20, 0.75, 0.25),
	Color(0.95, 0.85, 0.15), 
	Color(0.15, 0.40, 0.90), 
	Color(0.15, 0.85, 0.85), 
	Color(0.95, 0.55, 0.10), 
]

const SHAPE_FILES := [
	"triangle", "star", "square", "diamond", "cross", "plus", "circle",
]

@export_range(0, 6) var socket_id: int = 0:
	set(value):
		socket_id = value
		_aplicar_visual()

@onready var plug: Sprite2D = $Plug


func _ready() -> void:
	_aplicar_visual()


func _aplicar_visual() -> void:
	if plug == null:
		plug = get_node_or_null("Plug")

	if plug == null:
		return

	plug.texture = load("res://Minigames/Minigame2/assets/shapes/%s.png" % SHAPE_FILES[socket_id])
