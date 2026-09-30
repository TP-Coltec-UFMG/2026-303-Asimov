extends Area2D



@export var fio_scene: PackedScene
@export var raio_deteccao: float = 40.0
@export var max_conexoes: int = 1

@export var distancia_fio_automatico: float = 25.0



@onready var ponto_colisao: CollisionShape2D = $CollisionShape2D



var nome: String

var conexoes_terminais: Array = []

var conexoes_atuais: int = 0



var arrastando: bool = false

var fio_atual: Node2D = null

var mouse_follow: Node2D = null



var fio_automatico: Node2D = null

var ponto_automatico: Node2D = null



var conexao_reservada: bool = false



func _ready() -> void:

	nome = get_parent().name

	add_to_group("pontos_conexao")
	add_to_group("juncoes")
	get_parent().add_to_group("juncao") 
	input_pickable = true

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	pass



	if get_parent().nome == "juncao":

		call_deferred("_criar_fio_automatico")



func _criar_fio_automatico() -> void:


	if fio_automatico != null:

		if is_instance_valid(fio_automatico):
			return



	if fio_scene == null:

		pass

		return



	ponto_automatico = Node2D.new()

	ponto_automatico.name = "PontoAutomatico"


	_obter_mundo().add_child(
		ponto_automatico
	)



	ponto_automatico.global_position = (
		ponto_colisao.global_position +
		Vector2(-distancia_fio_automatico, 0)
	)



	fio_automatico = fio_scene.instantiate()

	fio_automatico.name = "FioAutomatico"


	_obter_mundo().add_child(
		fio_automatico
	)



	fio_automatico.conectar(
		ponto_colisao,
		ponto_automatico
	)

	fio_automatico.arrastando = false
	adicionar_conexao(fio_automatico)


	pass



func esta_disponivel() -> bool:

	var conexoes_ocupadas := conexoes_atuais
	
	if conexao_reservada:
		conexoes_ocupadas += 1

	return conexoes_ocupadas < max_conexoes



func adicionar_conexao(alvo) -> void:

	if alvo == null:
		return

	if not is_instance_valid(alvo):
		return

	if alvo == self:
		return

	if alvo in conexoes_terminais:
		return

	if conexoes_atuais >= max_conexoes:
		return


	conexoes_terminais.append(alvo)

	conexoes_atuais += 1

	atualizar_estado_conexao()
	pass

	pass



func remover_conexao(alvo) -> void:

	if alvo == null:
		return

	if alvo not in conexoes_terminais:
		return


	conexoes_terminais.erase(alvo)

	conexoes_atuais = conexoes_terminais.size()
	atualizar_estado_conexao()


	pass



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

	if not is_visible_in_tree() or not can_process():
		return
	if arrastando:
		return

	if conexao_reservada:
		return

	if not esta_disponivel():
		return

	if self.get_parent().nome =="juncao1":
		return


	if fio_scene == null:

		pass

		return



	conexao_reservada = true

	arrastando = true



	mouse_follow = Node2D.new()

	_obter_mundo().add_child(
		mouse_follow
	)

	mouse_follow.global_position = \
		get_global_mouse_position()



	fio_atual = fio_scene.instantiate()

	_obter_mundo().add_child(
		fio_atual
	)



	fio_atual.conectar(
		ponto_colisao,
		mouse_follow
	)


	pass



func _input(event) -> void:

	if not is_visible_in_tree() or not can_process():
		if arrastando:
			cancelar_fio()
		return
	if not arrastando:
		return



	if event is InputEventMouseMotion:

		if mouse_follow == null:
			return

		if not is_instance_valid(mouse_follow):
			return


		mouse_follow.global_position = \
			get_global_mouse_position()



	elif event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if not event.pressed:
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


	if (
		alvo != null
		and conexao_permitida(alvo)
		and not _tutorial_permite_conexao()
	):

		pass

		var gerente = get_tree().get_first_node_in_group(
			"tutorial_manager"
		)

		if gerente != null and gerente.has_method("mostrar_ainda_nao"):
			gerente.mostrar_ainda_nao()

		cancelar_fio()

		return


	if alvo != null and conexao_permitida(alvo):


		fio_atual.conectar(ponto_colisao, alvo.ponto_colisao)
		fio_atual.origem_e_juncao = true
		fio_atual.destino_e_juncao = true

		conexao_reservada = false

		fio_atual.arrastando = false
		adicionar_conexao(fio_atual)
		alvo.adicionar_conexao(fio_atual)

		_remover_mouse_follow()

		fio_atual = null
		atualizar_estado_conexao()
		pass
		
		pass
		pass
		pass

	else:


		pass

		fio_atual.fixar()

		conexao_reservada = false
		adicionar_conexao(fio_atual)

		_remover_mouse_follow()

		fio_atual = null


func _tutorial_permite_conexao() -> bool:

	var gerente = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if gerente == null:
		return true

	if not gerente.has_method("pode_conectar_cabo"):
		return true

	return gerente.pode_conectar_cabo()


func _remover_mouse_follow() -> void:

	if mouse_follow != null:
		if is_instance_valid(mouse_follow):
			mouse_follow.queue_free()

	mouse_follow = null



func cancelar_fio() -> void:

	if fio_atual != null:

		if is_instance_valid(fio_atual):
			fio_atual.queue_free()


	if mouse_follow != null:

		if is_instance_valid(mouse_follow):
			mouse_follow.queue_free()


	fio_atual = null

	mouse_follow = null

	arrastando = false

	conexao_reservada = false


	pass



func conexao_permitida(alvo) -> bool:

	if alvo == null:
		return false

	if not is_instance_valid(alvo):
		return false

	if alvo == self:
		return false

	if not alvo.is_in_group("juncoes"):
		return false

	if not alvo.esta_disponivel():
		return false

	if ponto_colisao.global_position.distance_to(alvo.ponto_colisao.global_position) > fio_atual.comprimento_maximo:
		return false

	return true



func encontrar_ponto_alvo() -> Variant:

	var mouse_pos := get_global_mouse_position()

	var melhor_dist: float = raio_deteccao

	var melhor: Variant = null


	for p in get_tree().get_nodes_in_group("juncoes"):

		if p == self:
			continue

		if not is_instance_valid(p):
			continue

		if not p.has_method("esta_disponivel"):
			continue

		if not p.esta_disponivel():
			continue


		if not "ponto_colisao" in p:
			continue

		if p.ponto_colisao == null:
			continue

		if not is_instance_valid(p.ponto_colisao):
			continue


		var dist: float = mouse_pos.distance_to(
			p.ponto_colisao.global_position
		)


		if dist < melhor_dist:

			melhor_dist = dist

			melhor = p


	return melhor


func _obter_mundo() -> Node2D:
	return get_tree().current_scene.get_node("Home")


func atualizar_estado_conexao() -> void:
	var conectado := false
	for fio in conexoes_terminais:
		if is_instance_valid(fio) and not fio.is_queued_for_deletion() and fio.esta_conectado():
			conectado = true
			break
	get_parent().definir_conectado(conectado)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and arrastando:
		cancelar_fio()
