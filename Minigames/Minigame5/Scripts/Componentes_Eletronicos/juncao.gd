extends Area2D


# =========================================================
# CONFIGURAÇÕES
# =========================================================

@export var fio_scene: PackedScene
@export var raio_deteccao: float = 40.0
@export var max_conexoes: int = 1

# Distância do fio automático para a esquerda
@export var distancia_fio_automatico: float = 25.0


# =========================================================
# REFERÊNCIA DO PONTO DE CONEXÃO
# =========================================================

@onready var ponto_colisao: CollisionShape2D = $CollisionShape2D


# =========================================================
# CONEXÕES
# =========================================================

var nome: String

var conexoes_terminais: Array = []

var conexoes_atuais: int = 0


# =========================================================
# ARRASTO
# =========================================================

var arrastando: bool = false

var fio_atual: Node2D = null

var mouse_follow: Node2D = null


# =========================================================
# FIO AUTOMÁTICO
# =========================================================

var fio_automatico: Node2D = null

var ponto_automatico: Node2D = null


# =========================================================
# RESERVA
# =========================================================

var conexao_reservada: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:

	nome = get_parent().name

	add_to_group("pontos_conexao")
	add_to_group("juncoes")
	get_parent().add_to_group("juncao") 
	input_pickable = true

	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

	print("[JUNÇÃO] ", nome, " pronta")


	# -----------------------------------------------------
	# CRIAR FIO AUTOMÁTICO
	# -----------------------------------------------------
	#
	# Só acontece se o pai desta Area2D
	# tiver o nome "juncao".
	#

	if get_parent().nome == "juncao":

		call_deferred("_criar_fio_automatico")


# =========================================================
# CRIAR FIO AUTOMÁTICO
# =========================================================

func _criar_fio_automatico() -> void:

	# -----------------------------------------------------
	# VERIFICAR SE JÁ EXISTE
	# -----------------------------------------------------

	if fio_automatico != null:

		if is_instance_valid(fio_automatico):
			return


	# -----------------------------------------------------
	# VERIFICAR FIO SCENE
	# -----------------------------------------------------

	if fio_scene == null:

		print(
			"[JUNÇÃO] ERRO: fio_scene não configurada para ",
			nome
		)

		return


	# -----------------------------------------------------
	# CRIAR PONTO FIXO
	# -----------------------------------------------------

	ponto_automatico = Node2D.new()

	ponto_automatico.name = "PontoAutomatico"


	_obter_mundo().add_child(
		ponto_automatico
	)


	# -----------------------------------------------------
	# POSIÇÃO DO PONTO
	# -----------------------------------------------------
	#
	# Pega o centro do CollisionShape2D
	# e coloca o ponto um pouco para a esquerda.
	#

	ponto_automatico.global_position = (
		ponto_colisao.global_position +
		Vector2(-distancia_fio_automatico, 0)
	)


	# -----------------------------------------------------
	# CRIAR FIO
	# -----------------------------------------------------

	fio_automatico = fio_scene.instantiate()

	fio_automatico.name = "FioAutomatico"


	_obter_mundo().add_child(
		fio_automatico
	)


	# -----------------------------------------------------
	# CONECTAR FIO
	# -----------------------------------------------------
	#
	# O fio começa no centro da junção
	# e termina no ponto fixo à esquerda.
	#

	fio_automatico.conectar(
		ponto_colisao,
		ponto_automatico
	)

	# Libera a ponta solta para ser clicada e arrastada,
	# assim como qualquer outro fio
	fio_automatico.arrastando = false
	adicionar_conexao(fio_automatico)


	print(
		"[JUNÇÃO] Fio automático criado em ",
		nome
	)


# =========================================================
# DISPONIBILIDADE
# =========================================================

func esta_disponivel() -> bool:

	var conexoes_ocupadas := conexoes_atuais
	
	if conexao_reservada:
		conexoes_ocupadas += 1

	return conexoes_ocupadas < max_conexoes


# =========================================================
# ADICIONAR CONEXÃO
# =========================================================

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
	print(
		"[JUNÇÃO] ",
		nome,
		" conectada com ",
		alvo.name
	)

	print(
		"[JUNÇÃO] ",
		nome,
		": ",
		conexoes_atuais,
		"/",
		max_conexoes
	)


# =========================================================
# REMOVER CONEXÃO
# =========================================================

func remover_conexao(alvo) -> void:

	if alvo == null:
		return

	if alvo not in conexoes_terminais:
		return


	conexoes_terminais.erase(alvo)

	conexoes_atuais = conexoes_terminais.size()
	atualizar_estado_conexao()


	print(
		"[JUNÇÃO] ",
		nome,
		" desconectada de ",
		alvo.name
	)


# =========================================================
# INPUT DA JUNÇÃO
# =========================================================

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


# =========================================================
# INICIAR FIO
# =========================================================

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
	# -----------------------------------------------------
	# VERIFICAR CENA DO FIO
	# -----------------------------------------------------

	if fio_scene == null:

		print(
			"[JUNÇÃO] ERRO: fio_scene não configurada em ",
			nome
		)

		return


	# -----------------------------------------------------
	# RESERVAR ESPAÇO
	# -----------------------------------------------------

	conexao_reservada = true

	arrastando = true


	# -----------------------------------------------------
	# CRIAR MOUSE FOLLOW
	# -----------------------------------------------------

	mouse_follow = Node2D.new()

	_obter_mundo().add_child(
		mouse_follow
	)

	mouse_follow.global_position = \
		get_global_mouse_position()


	# -----------------------------------------------------
	# CRIAR FIO
	# -----------------------------------------------------

	fio_atual = fio_scene.instantiate()

	_obter_mundo().add_child(
		fio_atual
	)


	# -----------------------------------------------------
	# CONECTAR FIO AO MOUSE
	# -----------------------------------------------------

	fio_atual.conectar(
		ponto_colisao,
		mouse_follow
	)


	print(
		"[JUNÇÃO] ",
		nome,
		" iniciou um fio."
	)


# =========================================================
# INPUT GLOBAL
# =========================================================

func _input(event) -> void:

	if not is_visible_in_tree() or not can_process():
		if arrastando:
			cancelar_fio()
		return
	if not arrastando:
		return


	# =====================================================
	# MOVIMENTO DO MOUSE
	# =====================================================

	if event is InputEventMouseMotion:

		if mouse_follow == null:
			return

		if not is_instance_valid(mouse_follow):
			return


		mouse_follow.global_position = \
			get_global_mouse_position()


	# =====================================================
	# SOLTOU O BOTÃO
	# =====================================================

	elif event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if not event.pressed:
			finalizar_fio()


# =========================================================
# FINALIZAR FIO
# =========================================================

func finalizar_fio() -> void:

	arrastando = false


	if fio_atual == null:
		cancelar_fio()
		return

	if not is_instance_valid(fio_atual):
		cancelar_fio()
		return


	var alvo = encontrar_ponto_alvo()


	# Tutorial: o cabo só pode ser conectado depois de passar
	# pelas etapas anteriores. Sem isso, o fio some (volta
	# para a junção de origem) e aparece "Ainda não".
	if (
		alvo != null
		and conexao_permitida(alvo)
		and not _tutorial_permite_conexao()
	):

		print("[JUNÇÃO] Ainda não: o tutorial não liberou o cabo.")

		var gerente = get_tree().get_first_node_in_group(
			"tutorial_manager"
		)

		if gerente != null and gerente.has_method("mostrar_ainda_nao"):
			gerente.mostrar_ainda_nao()

		cancelar_fio()

		return


	if alvo != null and conexao_permitida(alvo):

		# =====================================================
		# CONEXÃO DEFINITIVA COM UMA JUNÇÃO
		# =====================================================

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
		print(self.get_parent().conectado1)
		
		print("[JUNÇÃO] CONEXÃO REALIZADA: ", nome, " <-> ", alvo.name)
		print("[JUNÇÃO] ", nome, ": ", conexoes_atuais, "/", max_conexoes)
		print("[JUNÇÃO] ", alvo.name, ": ", alvo.conexoes_atuais, "/", alvo.max_conexoes)

	else:

		# =====================================================
		# NENHUMA JUNÇÃO VÁLIDA: FIXA O FIO ONDE ESTÁ
		# =====================================================
		#
		# Em vez de apagar o fio, ele fica solto na posição
		# atual e pode ser clicado e arrastado de novo depois.
		#

		print("[JUNÇÃO] Nenhuma junção válida — fio deixado solto em ", nome)

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


# =========================================================
# CANCELAR FIO
# =========================================================

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


	print(
		"[JUNÇÃO] Fio cancelado em ",
		nome
	)


# =========================================================
# VERIFICAR CONEXÃO
# =========================================================

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


# =========================================================
# ENCONTRAR JUNÇÃO
# =========================================================

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
