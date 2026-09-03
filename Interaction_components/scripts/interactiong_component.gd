extends Node2D

@onready var interact_label: Label = $InteractLabel
@onready var interact_button: Sprite2D = $InteractButton
@onready var interact_button_label: Label = $InteractButton/Label

var current_interactions := []
var can_interact := true

var objeto_destacado: Node2D = null
var posicao_original_y: float = 0.0
var tempo_flutuando: float = 0.0

const ALTURA_FLUTUACAO := 1.0
const VELOCIDADE_FLUTUACAO := 5.0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_interact:
		if current_interactions:
			can_interact = false
			interact_label.hide()
			
			await current_interactions[0].interact.call()
			can_interact = true


func _process(delta: float) -> void:
	if current_interactions and can_interact:
		current_interactions.sort_custom(_sort_by_nearest)

		if current_interactions[0].is_interactable:
			if current_interactions[0].is_not_object:
				interact_label.text = current_interactions[0].interact_name
				interact_label.show()
				_mostra_interacao_not_object()
			else:
				interact_label.text = current_interactions[0].interact_name
				interact_label.show()
				_mostra_interacao(delta)
		else:
			interact_label.hide()
			_parar_interacao()
	else:
		interact_label.hide()
		_parar_interacao()


func _sort_by_nearest(area1, area2):
	var area1_dist = global_position.distance_to(area1.global_position)
	var area2_dist = global_position.distance_to(area2.global_position)
	return area1_dist < area2_dist


func _on_interact_range_area_entered(area: Area2D) -> void:
	current_interactions.push_back(area)


func _on_interact_range_area_exited(area: Area2D) -> void:
	if area == current_interactions[0] if current_interactions.size() > 0 else false:
		_parar_interacao()

	current_interactions.erase(area)


func _mostra_interacao(delta: float) -> void:
	var objeto_atual = current_interactions[0].get_parent()
	interact_button.visible = true
	interact_button_label.text = "E"

	if objeto_atual != objeto_destacado:
		_parar_interacao()
		objeto_destacado = objeto_atual
		posicao_original_y = objeto_destacado.position.y
		tempo_flutuando = 0.0

	tempo_flutuando += delta * VELOCIDADE_FLUTUACAO

	objeto_destacado.position.y = posicao_original_y + sin(tempo_flutuando) * ALTURA_FLUTUACAO


func _mostra_interacao_not_object() -> void:
	interact_button.visible = true

	if current_interactions[0].is_in_group("empurravel"):
		var event = InputMap.action_get_events("empurrar")[0]
		interact_button_label.text = OS.get_keycode_string(event.physical_keycode)

	elif current_interactions[0].is_in_group("Coletaveis"):
		var event = InputMap.action_get_events("interact")[0]
		interact_button_label.text = OS.get_keycode_string(event.physical_keycode)


func _parar_interacao() -> void:
	if objeto_destacado != null:
		objeto_destacado.position.y = posicao_original_y
	
	interact_button.visible = false
	objeto_destacado = null
	tempo_flutuando = 0.0
