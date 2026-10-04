extends Node2D

var em_uso: bool = false
var som_terminou: bool = true
var animacao_terminou: bool = true

@onready var brilho: Sprite2D = $Brilho
@onready var som: AudioStreamPlayer2D = $Som
@onready var animacao: AnimationPlayer = $Animacao


func iniciar(posicao: Vector2, destruicao: bool, escala_tempo: float = 1.0) -> void:
	animacao.stop()
	som.stop()
	em_uso = true
	som_terminou = false
	animacao_terminou = false
	global_position = posicao
	brilho.show()
	modulate.a = 0.94 if destruicao else 0.86
	brilho.modulate = Color(1.0, randf_range(0.28, 0.52), 0.08) if destruicao else Color(1.0, 0.44, 0.12)
	brilho.z_index = 95 if destruicao else 90
	som.volume_db = randf_range(-6.0, -2.0) if destruicao else -5.0
	som.max_distance = 650.0 if destruicao else 480.0
	som.play()
	animacao.speed_scale = 1.0 / maxf(escala_tempo, 0.01) if destruicao else 1.0
	animacao.play(&"destruicao" if destruicao else &"componente")
	animacao.advance(0.0)


func _ao_terminar_som() -> void:
	som_terminou = true
	_atualizar_disponibilidade()


func _ao_terminar_animacao(_nome: StringName) -> void:
	animacao_terminou = true
	brilho.hide()
	_atualizar_disponibilidade()


func _atualizar_disponibilidade() -> void:
	em_uso = not (som_terminou and animacao_terminou)
