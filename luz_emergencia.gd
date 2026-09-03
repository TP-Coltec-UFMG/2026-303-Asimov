extends Node2D

@export var sprite_2d: Texture2D
@export var cor_lanterna: Color

@onready var lanterna: Sprite2D = $Sprite2D
@onready var point_light_2d: PointLight2D = $PointLight2D

var tempo := 0.0

func _ready() -> void:
	lanterna.texture = sprite_2d
	point_light_2d.color = cor_lanterna
	set_process(false)
	liga_luz()

func liga_luz() -> void:
	point_light_2d.show()
	MusicController._start_som_alarme()
	set_process(true)
	
func desliga_luz() -> void:
	point_light_2d.hide()
	MusicController._stop_som_alarme()
	set_process(false)

func _process(delta: float) -> void:
	tempo += delta
	point_light_2d.energy = 1.5 + sin(tempo * 6.0) * 0.7
