extends Area2D

# Recurso próprio do minigame de circuito; não compartilha UID com outros minigames.


@export var fio_scene: PackedScene
@export var raio_deteccao: float = 40.0
@export var max_conexoes: int = 2

var nome: String

@onready var ponto_colisao: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D

var material_shader: ShaderMaterial


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

	nome = get_parent().name

	add_to_group("pontos_conexao")
	add_to_group("juncoes")

	input_pickable = true

	input_event.connect(
		_on_input_event
	)

	material_shader = animation_player.material as ShaderMaterial

	desativar_destaque()

	print(
		"JUNÇÃO ",
		nome,
		" pronta"
	)


# ==========================================
# DESTAQUE
# ==========================================

func ativar_destaque() -> void:

	if animation_player == null:
		return

	animation_player.material = material_shader


func desativar_destaque() -> void:

	if animation_player == null:
		return

	animation_player.material = null


# ==========================================
# VERIFICAR DISPONIBILIDADE
# ==========================================

func esta_disponivel() -> bool:

	return conexoes_atuais < max_conexoes


# ==========================================
# ADICIONAR CONEXÃO REAL
# ==========================================

func adicionar_conexao(alvo) -> void:

	if alvo == null:
		return

	if not is_instance_valid(alvo):
		return

	if alvo in conexoes_terminais:

		print(
			"[JUNÇÃO] ",
			nome,
			" já possui conexão com ",
			alvo.name
		)

		return


	conexoes_terminais.append(alvo)

	conexoes_atuais += 1


	print(
		"[JUNÇÃO] ",
		nome,
		" recebeu conexão com ",
		alvo.name
	)

	print(
		"[JUNÇÃO] ",
		nome,
		" agora possui ",
		conexoes_atuais,
		"/",
		max_conexoes,
		" conexões."
	)


# ==========================================
# REMOVER CONEXÃO REAL
# ==========================================

func remover_conexao(alvo) -> void:

	if alvo == null:
		return


	if alvo in conexoes_terminais:

		conexoes_terminais.erase(alvo)

		conexoes_atuais = max(
			0,
			conexoes_atuais - 1
		)

		print(
			"[JUNÇÃO] ",
			nome,
			" removeu conexão com ",
			alvo.name
		)

	else:

		print(
			"[JUNÇÃO] Tentativa de remover conexão inexistente: ",
			nome,
			" -> ",
			alvo.name
		)


# ==========================================
# INPUT DO MOUSE
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

	print("")
	print("========================================")
	print("[JUNÇÃO] INICIANDO NOVO FIO")
	print("========================================")


	# ==========================================
	# VERIFICAR LIMITE DA JUNÇÃO
	# ==========================================

	if not esta_disponivel():

		_mostrar_aviso_tutorial(
			"Esta junção já possui duas conexões.\n\nO máximo de uma junção é 2 conexões."
		)

		return


	# ==========================================
	# IMPEDIR DOIS ARRASTOS
	# ==========================================

	if arrastando:

		print(
			"[JUNÇÃO] Já está arrastando um fio."
		)

		return


	# ==========================================
	# VERIFICAR FIO SCENE
	# ==========================================

	if fio_scene == null:

		print(
			"ERRO: fio_scene não configurada em ",
			nome
		)

		return


	# ==========================================
	# ATIVAR ARRASTO
	# ==========================================

	arrastando = true


	# ==========================================
	# CRIAR PONTO QUE SEGUE O MOUSE
	# ==========================================

	mouse_follow = Node2D.new()

	get_tree().current_scene.add_child(
		mouse_follow
	)

	mouse_follow.global_position = \
		get_global_mouse_position()


	# ==========================================
	# CRIAR FIO VISUAL
	# ==========================================

	fio_atual = fio_scene.instantiate()


	if fio_atual == null:

		print(
			"[JUNÇÃO] ERRO: fio_scene.instantiate() retornou null."
		)

		cancelar_fio()

		return


	get_tree().current_scene.add_child(
		fio_atual
	)


	# ==========================================
	# CONECTAR ORIGEM AO MOUSE
	# ==========================================

	if not fio_atual.has_method("conectar"):

		print(
			"[JUNÇÃO] ERRO: Fio não possui conectar()."
		)

		cancelar_fio()

		return


	fio_atual.conectar(
		ponto_colisao,
		mouse_follow
	)


	print(
		"[JUNÇÃO] Fio seguindo o mouse."
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

	print("")
	print("========================================")
	print("[JUNÇÃO] FINALIZANDO FIO")
	print("========================================")


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

		print(
			"[JUNÇÃO] Nenhum alvo encontrado."
		)

		cancelar_fio()

		return


	print(
		"[JUNÇÃO] Alvo encontrado: ",
		alvo.name
	)


	# ==========================================
	# VERIFICAR SE É PERMITIDO
	# ==========================================

	if not conexao_permitida(alvo):

		print(
			"[JUNÇÃO] Conexão não permitida."
		)

		cancelar_fio()

		return


	print(
		"[JUNÇÃO] Conexão permitida."
	)


	# ==========================================
	# PEGAR CIRCUITO
	# ==========================================

	var circuito = get_tree().get_first_node_in_group(
		"circuito"
	)


	if circuito == null:

		print(
			"ERRO: circuito não encontrado."
		)

		cancelar_fio()

		return


	# ==========================================
	# VERIFICAR MÉTODO
	# ==========================================

	if not circuito.has_method(
		"registrar_fio_existente"
	):

		print(
			"ERRO: Circuito não possui registrar_fio_existente()."
		)

		cancelar_fio()

		return


	# ==========================================
	# REGISTRAR NO CIRCUITO
	# ==========================================

	var sucesso = circuito.registrar_fio_existente(
		self,
		alvo,
		fio_atual
	)


	# ==========================================
	# CIRCUITO ACEITOU
	# ==========================================

	if sucesso:

		print("")
		print("########################################")
		print("#       NOVA CONEXÃO REALIZADA         #")
		print("########################################")

		print(
			"[JUNÇÃO] ",
			nome,
			" -> ",
			alvo.nome
		)


	# ==========================================
	# CIRCUITO RECUSOU
	# ==========================================

	else:

		print(
			"[JUNÇÃO] Circuito recusou a conexão."
		)

		cancelar_fio()

		return


	# ==========================================
	# LIMPAR MOUSE FOLLOW
	# ==========================================

	if mouse_follow != null:

		if is_instance_valid(mouse_follow):

			mouse_follow.queue_free()

		mouse_follow = null


	# ==========================================
	# LIMPAR REFERÊNCIA DO FIO
	# ==========================================

	fio_atual = null


# ==========================================
# CANCELAR FIO
# ==========================================

func cancelar_fio() -> void:

	print(
		"[JUNÇÃO] Cancelando fio..."
	)


	if fio_atual != null:

		if is_instance_valid(fio_atual):

			fio_atual.queue_free()


	if mouse_follow != null:

		if is_instance_valid(mouse_follow):

			mouse_follow.queue_free()


	mouse_follow = null
	fio_atual = null

	arrastando = false


# ==========================================
# VERIFICAR SE CONEXÃO É PERMITIDA
# ==========================================

func conexao_permitida(alvo) -> bool:

	if alvo == null:
		return false


	if not is_instance_valid(alvo):
		return false


	if alvo == self:

		print(
			"[JUNÇÃO] Não pode conectar consigo mesma."
		)

		return false


	# ==========================================
	# TERMINAL -> TERMINAL
	# ==========================================

	if (
		is_in_group("terminais")
		and
		alvo.is_in_group("terminais")
	):

		_mostrar_aviso_tutorial(
			"Terminal só conecta com junção.\n\nTerminais não podem ser conectados diretamente entre si."
		)

		return false


	# ==========================================
	# CONEXÕES QUE PASSAM POR CIMA
	# DOS COMPONENTES
	# ==========================================

	if _eh_conexao_proibida_entre_juncoes(alvo):

		_mostrar_aviso_tutorial(
			"Não é possível conectar fios que passam por cima dos componentes."
		)

		return false


	# ==========================================
	# VERIFICAR DUPLICAÇÃO
	# ==========================================

	if alvo in conexoes_terminais:

		print(
			"[JUNÇÃO] Conexão já existe."
		)

		return false


	# ==========================================
	# LIMITE DO DESTINO
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


	return true


# ==========================================
# RESTRIÇÕES ENTRE JUNÇÕES
# ==========================================

func _eh_conexao_proibida_entre_juncoes(alvo) -> bool:

	if not alvo.is_in_group("juncoes"):
		return false


	var nome_alvo: String = alvo.nome


	# Juncao01 <-> Juncao03

	if (
		(nome == "Juncao01" and nome_alvo == "Juncao03")
		or
		(nome == "Juncao03" and nome_alvo == "Juncao01")
	):

		return true


	# Juncao03 <-> Juncao04

	if (
		(nome == "Juncao03" and nome_alvo == "Juncao04")
		or
		(nome == "Juncao04" and nome_alvo == "Juncao03")
	):

		return true


	# Juncao02 <-> Juncao04

	if (
		(nome == "Juncao02" and nome_alvo == "Juncao04")
		or
		(nome == "Juncao04" and nome_alvo == "Juncao02")
	):

		return true


	return false


# ==========================================
# ENCONTRAR PONTO ALVO
# ==========================================
#
# IMPORTANTE:
#
# Aqui NÃO filtramos mais pontos que estejam
# sem espaço.
#
# Isso permite encontrar uma junção/terminal
# cheio e então mostrar o aviso correto.
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


		# NÃO fazer:
		#
		# if not p.esta_disponivel():
		#     continue
		#
		# Precisamos encontrar pontos cheios
		# para mostrar o aviso.


		if not "ponto_colisao" in p:
			continue


		if p.ponto_colisao == null:
			continue


		if not is_instance_valid(
			p.ponto_colisao
		):
			continue


		var dist: float = mouse_pos.distance_to(
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
