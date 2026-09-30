extends Area2D


@export var fio_scene: PackedScene
@export var raio_deteccao: float = 40.0
@export var max_conexoes: int = 1
@export var nome: String = "nome"

@onready var ponto_colisao: CollisionShape2D = $CollisionShape2D



var conexoes_terminais: Array = []
var conexoes_atuais: int = 0



var arrastando: bool = false

var fio_atual: Node2D = null
var mouse_follow: Node2D = null



func _ready() -> void:

	add_to_group("pontos_conexao")
	add_to_group("terminais")

	input_pickable = true

	input_event.connect(
		_on_input_event
	)



func esta_disponivel() -> bool:

	return conexoes_atuais < max_conexoes



func adicionar_conexao(alvo) -> void:

	if alvo == null:
		return


	if not is_instance_valid(alvo):
		return


	if alvo in conexoes_terminais:

		return


	conexoes_terminais.append(alvo)


	if conexoes_atuais < max_conexoes:

		conexoes_atuais += 1



func remover_conexao(alvo) -> void:

	if alvo in conexoes_terminais:

		conexoes_terminais.erase(alvo)

		conexoes_atuais = max(
			0,
			conexoes_atuais - 1
		)



func obter_componente() -> String:

	var partes = name.split("_")


	if partes.size() < 3:

		return ""


	return "_".join(
		partes.slice(2)
	)



func _on_input_event(
	_viewport,
	event,
	_shape_idx
) -> void:

	if arrastando:
		return


	if not event is InputEventMouseButton:
		return


	if event.button_index != MOUSE_BUTTON_LEFT:
		return


	if event.pressed:

		iniciar_fio()



func iniciar_fio() -> void:


	if not esta_disponivel():

		_mostrar_aviso_tutorial(
			"Este terminal já atingiu o limite de uma conexão."
		)

		return



	if fio_scene == null:

		pass

		return



	var circuito := _obter_circuito()
	if circuito == null:
		return


	arrastando = true



	mouse_follow = Node2D.new()

	circuito.add_child(
		mouse_follow
	)

	mouse_follow.global_position = \
		get_global_mouse_position()



	fio_atual = fio_scene.instantiate()


	if fio_atual == null:

		cancelar_fio()

		return


	circuito.add_child(
		fio_atual
	)



	if not fio_atual.has_method("conectar"):

		cancelar_fio()

		return


	fio_atual.conectar(
		ponto_colisao,
		mouse_follow
	)



func _input(event) -> void:

	if not arrastando:
		return


	if event is InputEventMouseMotion:

		if mouse_follow != null:

			if is_instance_valid(mouse_follow):

				mouse_follow.global_position = get_canvas_transform().affine_inverse() * event.position


	elif event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return


		if not event.pressed:

			if is_instance_valid(mouse_follow):
				mouse_follow.global_position = get_canvas_transform().affine_inverse() * event.position
			finalizar_fio()



func finalizar_fio() -> void:

	arrastando = false



	if fio_atual == null:

		cancelar_fio()

		return


	if not is_instance_valid(fio_atual):

		cancelar_fio()

		return



	var alvo = encontrar_ponto_alvo()


	if alvo == null:

		cancelar_fio()

		return



	if not conexao_permitida(alvo):

		cancelar_fio()

		return



	var circuito := _obter_circuito()
	if circuito == null or not circuito.registrar_fio_existente(self, alvo, fio_atual):
		cancelar_fio()
		return



	fio_atual.destino = alvo.ponto_colisao


	pass



	get_tree().call_group(
		"circuito",
		"analisar_circuito"
	)



	if mouse_follow != null:

		if is_instance_valid(mouse_follow):

			mouse_follow.queue_free()

		mouse_follow = null


	fio_atual = null



func cancelar_fio() -> void:



	if fio_atual != null:

		if is_instance_valid(fio_atual):

			fio_atual.queue_free()



	if mouse_follow != null:

		if is_instance_valid(mouse_follow):

			mouse_follow.queue_free()



	mouse_follow = null
	fio_atual = null

	arrastando = false



func conexao_permitida(alvo) -> bool:

	if alvo == null:

		return false


	if not is_instance_valid(alvo):

		return false


	if alvo == self:

		return false



	if alvo.is_in_group("terminais"):

		_mostrar_aviso_tutorial(
			"Terminais só podem ser ligados a junções, nunca diretamente entre si."
		)

		return false



	if alvo in conexoes_terminais:

		return false



	if not alvo.has_method("esta_disponivel"):

		return false


	if not alvo.esta_disponivel():

		if alvo.is_in_group("terminais"):

			_mostrar_aviso_tutorial(
			"Este terminal já atingiu o limite de uma conexão."
			)

		elif alvo.is_in_group("juncoes"):

			_mostrar_aviso_tutorial(
			"Esta junção já atingiu o limite de duas conexões."
			)

		else:

			_mostrar_aviso_tutorial(
				"Este ponto de conexão já atingiu seu limite."
			)

		return false



	if not alvo.is_in_group("juncoes"):

		_mostrar_aviso_tutorial(
			"O terminal só pode ser ligado a uma junção."
		)

		return false


	return true



func encontrar_ponto_alvo() -> Variant:

	var mouse_pos := mouse_follow.global_position if is_instance_valid(mouse_follow) else get_global_mouse_position()
	var circuito := _obter_circuito()

	var melhor_dist: float = raio_deteccao

	var melhor: Variant = null


	for p in get_tree().get_nodes_in_group(
		"pontos_conexao"
	):

		if p == self:
			continue


		if not is_instance_valid(p):
			continue

		if circuito == null or not circuito.is_ancestor_of(p):
			continue


		if not p.has_method("esta_disponivel"):
			continue




		if not "ponto_colisao" in p:
			continue


		if p.ponto_colisao == null:
			continue


		if not is_instance_valid(
			p.ponto_colisao
		):

			continue


		var dist := mouse_pos.distance_to(
			p.ponto_colisao.global_position
		)


		if dist < melhor_dist:

			melhor_dist = dist
			melhor = p


	return melhor


func _obter_circuito() -> Node2D:
	var parent := get_parent()
	while parent != null:
		if parent.is_in_group("circuito"):
			return parent as Node2D
		parent = parent.get_parent()
	return null



func _mostrar_aviso_tutorial(
	mensagem: String
) -> void:

	var tutorial = get_tree().get_first_node_in_group(
		"tutorial_objetivo"
	)


	if tutorial == null:
		return


	if not is_instance_valid(tutorial):
		return


	if tutorial.has_method(
		"mostrar_aviso_conexao"
	):

		tutorial.mostrar_aviso_conexao(
			mensagem
		)
