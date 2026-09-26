extends Sprite2D
@onready var point_light_2d: PointLight2D = $PointLight2D


func _ready() -> void:
	desliga_luz()


func liga_luz() -> void:
	point_light_2d.show()


func desliga_luz() -> void:
	point_light_2d.hide()


func ligar_luz() -> void:
	liga_luz()


func desligar_luz() -> void:
	desliga_luz()
