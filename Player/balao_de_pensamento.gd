extends Sprite2D

@onready var label: Label = $Label
@onready var interactiong_component: Node2D = $"../InteractiongComponent"

@export var caracteres_por_segundo: float = 8.0
@export var tempo_minimo: float = 3.0
@export var tempo_maximo: float = 10.0
@export var tempo_fade_out: float = 0.5

signal pensamento_concluido


func mostrar_texto(text: String) -> void:

	modulate.a = 1.0
	show()

	label.text = text

	var tempo: float = text.length() / caracteres_por_segundo
	tempo = clamp(tempo, tempo_minimo, tempo_maximo)

	await get_tree().create_timer(tempo).timeout

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, tempo_fade_out)

	await tween.finished

	hide()
	modulate.a = 1.0
	pensamento_concluido.emit()
