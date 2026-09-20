extends Area2D


@export var fio_scene: PackedScene
@export var raio_deteccao: float = 40.0
@export var max_conexoes: int = 1
@export var nome: String = "nome"

@onready var ponto_colisao: CollisionShape2D = $CollisionShape2D


# ==========================================
# CONEXÕES
# ==========================================

var conexoes_terminais: Array = []
var conexoes_atuais: int = 0


# ==========================================
# CONTROLE DO ARRASTO
# ==========================================

var arrastando: bool = false

var fio_atual: Node2D = null
var mouse_follow: Node2D = null


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:

	add_to_group("pontos_conexao")
	add_to_group("terminais")

	input_pickable = true

	input_event.connect(
		_on_input_event
	)


# ==========================================
# VERIFICAR DISPONIBILIDADE
# ==========================================

func esta_disponivel() -> bool:

	return conexoes_atuais < max_conexoes


# ==========================================
# ADICIONAR CONEXÃO
# ==========================================

func adicionar_conexao(alvo) -> void:

	if alvo == null:
		return


	if not is_instance_valid(alvo):
		return


	if alvo in conexoes_terminais:

		return


	conexoes_terminais.append(alvo)

	# O valor já pode ter sido reservado pelo
	# arrasto do terminal.
	#
	# Portanto só aumenta caso ainda não esteja
	# representando esta conexão.

	if conexoes_atuais < max_conexoes:

		conexoes_atuais += 1


# ==========================================
# REMOVER CONEXÃO
# ==========================================

func remover_conexao(alvo) -> void:

	if alvo in conexoes_terminais:

		conexoes_terminais.erase(alvo)

		conexoes_atuais = max(
			0,
			conexoes_atuais - 1
		)


# ==========================================
# IDENTIFICA O COMPONENTE DO TERMINAL
# ==========================================

func obter_componente() -> String:

	var partes = name.split("_")


	if partes.size() < 3:

		return ""


	return "_".join(
		partes.slice(2)
	)


# ==========================================
# CLIQUE PARA COMEÇAR UM FIO
# ==========================================

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


# ==========================================
# INICIAR FIO
# ==========================================

func iniciar_fio() -> void:

	# ==========================================
	# LIMITE DO TERMINAL
	# ==========================================

	if not esta_disponivel():

		_mostrar_aviso_tutorial(
			"Este terminal já possui uma conexão.\n\nO máximo de um terminal é 1 conexão."
		)

		return


	# ==========================================
	# VERIFICAR FIO
	# ==========================================

	if fio_scene == null:

		print(
			"ERRO: fio_scene não configurada em ",
			name
		)

		return


	# ==========================================
	# RESERVAR A CONEXÃO
	# ==========================================

	conexoes_atuais += 1


	arrastando = true


	# ==========================================
	# CRIAR MOUSE FOLLOW
	# ==========================================

	mouse_follow = Node2D.new()

	get_tree().current_scene.add_child(
		mouse_follow
	)

	mouse_follow.global_position = \
		get_global_mouse_position()


	# ==========================================
	# CRIAR FIO
	# ==========================================

	fio_atual = fio_scene.instantiate()


	if fio_atual == null:

		cancelar_fio()

		return


	get_tree().current_scene.add_child(
		fio_atual
	)


	# ==========================================
	# CONECTAR AO MOUSE
	# ==========================================

	if not fio_atual.has_method("conectar"):

		cancelar_fio()

		return


	fio_atual.conectar(
		ponto_colisao,
		mouse_follow
	)


# ==========================================
# INPUT GLOBAL
# ==========================================

func _input(event) -> void:

	if not arrastando:
		return


	if event is InputEventMouseMotion:

		if mouse_follow != null:

			if is_instance_valid(mouse_follow):

				mouse_follow.global_position = \
					get_global_mouse_position()


	elif event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return


		if not event.pressed:

			finalizar_fio()


# ==========================================
# FINALIZAR FIO
# ==========================================

func finalizar_fio() -> void:

	arrastando = false


	# ==========================================
	# VERIFICAR FIO
	# ==========================================

	if fio_atual == null:

		cancelar_fio()

		return


	if not is_instance_valid(fio_atual):

		cancelar_fio()

		return


	# ==========================================
	# ENCONTRAR ALVO
	# ==========================================

	var alvo = encontrar_ponto_alvo()


	if alvo == null:

		cancelar_fio()

		return


	# ==========================================
	# VERIFICAR CONEXÃO
	# ==========================================

	if not conexao_permitida(alvo):

		cancelar_fio()

		return


	# ==========================================
	# REGISTRAR CONEXÃO
	# ==========================================

	conexoes_terminais.append(
		alvo
	)


	alvo.adicionar_conexao(
		self
	)


	# ==========================================
	# DEFINIR DESTINO DO FIO
	# ==========================================

	fio_atual.destino = alvo.ponto_colisao


	print(
		"CONEXÃO: ",
		name,
		" -> ",
		alvo.name
	)


	# ==========================================
	# ANALISAR CIRCUITO
	# ==========================================

	get_tree().call_group(
		"circuito",
		"analisar_circuito"
	)


	# ==========================================
	# LIMPAR MOUSE FOLLOW
	# ==========================================

	if mouse_follow != null:

		if is_instance_valid(mouse_follow):

			mouse_follow.queue_free()

		mouse_follow = null


	fio_atual = null


# ==========================================
# CANCELAR FIO
# ==========================================

func cancelar_fio() -> void:

	# ==========================================
	# LIBERAR RESERVA DO TERMINAL
	# ==========================================

	conexoes_atuais = max(
		0,
		conexoes_atuais - 1
	)


	# ==========================================
	# REMOVER FIO
	# ==========================================

	if fio_atual != null:

		if is_instance_valid(fio_atual):

			fio_atual.queue_free()


	# ==========================================
	# REMOVER MOUSE FOLLOW
	# ==========================================

	if mouse_follow != null:

		if is_instance_valid(mouse_follow):

			mouse_follow.queue_free()


	# ==========================================
	# LIMPAR ESTADO
	# ==========================================

	mouse_follow = null
	fio_atual = null

	arrastando = false


# ==========================================
# VERIFICA SE A CONEXÃO É PERMITIDA
# ==========================================

func conexao_permitida(alvo) -> bool:

	if alvo == null:

		return false


	if not is_instance_valid(alvo):

		return false


	if alvo == self:

		return false


	# ==========================================
	# TERMINAL -> TERMINAL
	# ==========================================

	if alvo.is_in_group("terminais"):

		_mostrar_aviso_tutorial(
			"Terminal só conecta com junção.\n\nTerminais não podem ser conectados diretamente entre si."
		)

		return false


	# ==========================================
	# DUPLICAÇÃO
	# ==========================================

	if alvo in conexoes_terminais:

		return false


	# ==========================================
	# VERIFICAR DISPONIBILIDADE DO ALVO
	# ==========================================

	if not alvo.has_method("esta_disponivel"):

		return false


	if not alvo.esta_disponivel():

		if alvo.is_in_group("terminais"):

			_mostrar_aviso_tutorial(
				"Este terminal já possui uma conexão.\n\nO máximo de um terminal é 1 conexão."
			)

		elif alvo.is_in_group("juncoes"):

			_mostrar_aviso_tutorial(
				"Esta junção já possui duas conexões.\n\nO máximo de uma junção é 2 conexões."
			)

		else:

			_mostrar_aviso_tutorial(
				"Este ponto de conexão já atingiu seu limite."
			)

		return false


	# ==========================================
	# TERMINAL SÓ PODE IR PARA JUNÇÃO
	# ==========================================

	if not alvo.is_in_group("juncoes"):

		_mostrar_aviso_tutorial(
			"Terminal só conecta com junção."
		)

		return false


	return true


# ==========================================
# ENCONTRAR PONTO ALVO
# ==========================================
#
# IMPORTANTE:
#
# Diferente da versão anterior, aqui os terminais
# também são considerados.
#
# Assim uma tentativa:
#
# Terminal -> Terminal
#
# consegue chegar em conexao_permitida()
# e mostrar o aviso.
#
# Também não descartamos pontos cheios.
#
# ==========================================

func encontrar_ponto_alvo() -> Variant:

	var mouse_pos := get_global_mouse_position()

	var melhor_dist: float = raio_deteccao

	var melhor: Variant = null


	for p in get_tree().get_nodes_in_group(
		"pontos_conexao"
	):

		if p == self:
			continue


		if not is_instance_valid(p):
			continue


		if not p.has_method("esta_disponivel"):
			continue


		# NÃO filtramos disponibilidade aqui.
		#
		# Um terminal/junção cheio precisa continuar
		# sendo encontrado para gerar o aviso.


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


# ==========================================
# MOSTRAR AVISO DO TUTORIAL
# ==========================================

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
