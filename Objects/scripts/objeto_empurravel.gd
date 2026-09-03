class_name ObjetoEmpurravel
extends CharacterBody2D

@export var velocidade_empurrao: float = 40.0
@export var save_id: String = "empurravel01"
@export var save_enabled: bool = true

var ultima_posicao_x: float


func _ready() -> void:
	add_to_group("empurravel")

	if not save_enabled:
		ultima_posicao_x = position.x
		return

	var estado_salvo = SaveGame.load_object_state(save_id)

	if estado_salvo != null:
		position.x = estado_salvo.get("position_x", position.x)

	ultima_posicao_x = position.x


func _process(_delta: float) -> void:
	if not save_enabled:
		return

	if position.x != ultima_posicao_x:
		ultima_posicao_x = position.x

		SaveGame.save_object_state(save_id, {
			"position_x": position.x
		})
