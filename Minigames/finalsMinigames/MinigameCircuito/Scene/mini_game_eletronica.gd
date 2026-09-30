extends Node2D

signal minigame_completed
signal minigame_failed


enum ModoObjetivo {
	QUEIMAR_RESISTOR,
	QUEIMAR_LED,
	QUEIMAR_BATERIA,
	QUEIMAR_LED_E_RESISTOR,
	QUEIMAR_LED_E_BATERIA,
	QUEIMAR_RESISTOR_E_BATERIA
}

@export var modo_objetivo: ModoObjetivo = ModoObjetivo.QUEIMAR_RESISTOR


const MENSAGEM_BATERIA_ANTES: String = "NÃO QUEIME A BATERIA ANTES\nDE QUEIMAR OS COMPONENTES!"
const TEMPO_MENSAGEM_REINICIO: float = 5.0


@onready var circuito: Node2D = $Circuito
@onready var bateria = $Circuito/Bateria
@onready var resistor = $Circuito/Resistor
@onready var led = $Circuito/Led
@onready var alicate = $Circuito/Alicate
@onready var interface_jogo = $Circuito/Interface

@onready var juncao01 = $Circuito/Juncao01/Juncao
@onready var juncao02 = $Circuito/Juncao02/Juncao
@onready var juncao03 = $Circuito/Juncao03/Juncao
@onready var juncao04 = $Circuito/Juncao04/Juncao

@onready var resistor_terminal_positivo = $Circuito/Resistor/Terminal_positivo
@onready var resistor_terminal_negativo = $Circuito/Resistor/Terminal_negativo

@onready var led_terminal_positivo = $Circuito/Led/Terminal_positivo
@onready var led_terminal_negativo = $Circuito/Led/Terminal_negativo
@onready var colison_led_terminal_positivo = $Circuito/Led/Terminal_positivo/CollisionShape2D
@onready var colison_led_terminal_negativo = $Circuito/Led/Terminal_negativo/CollisionShape2D

@onready var componente1 = $Circuito/Led/AnimatedSprite2D
@onready var Componente2 = $Circuito/Led/AnimatedSprite2D2

@onready var painel_orientacao: Panel = $Fundo_preto_tutorial
@onready var texto_orientacao: Label = $Fundo_preto_tutorial/Label
@onready var botao_continuar: Button = $Fundo_preto_tutorial/Button


var passo_atual: int = 0
var passo_pronto: bool = false

var _nos_destacados: Array = []

var _proximo_passo_do_botao: int = -1


var _aviso_ativo: bool = false
var _passo_antes_do_aviso: int = 0


var _corte_j03_resistor_existia: bool = false
var _corte_j04_led_existia: bool = false
var _conexao_j03_led_existia: bool = false


# Verdadeiro enquanto a mensagem de "bateria queimada cedo demais" está
# na tela e o circuito está sendo reiniciado.
var _reiniciando: bool = false


func notificar_vitoria() -> void:
	minigame_completed.emit()


func notificar_derrota() -> void:
	minigame_failed.emit()


func _ready() -> void:
	_configurar_componente_led()

	await get_tree().process_frame

	add_to_group("tutorial_objetivo")


	if interface_jogo.has_method("definir_objetivo"):
		interface_jogo.definir_objetivo(_objetivo_da_interface())

	if not botao_continuar.pressed.is_connected(_on_button_pressed):
		botao_continuar.pressed.connect(_on_button_pressed)

	_iniciar_passo(0)


func _process(_delta: float) -> void:

	if _reiniciando:
		return

	# Verifica se a bateria TERMINOU de queimar antes dos componentes.
	# Enquanto ela estiver apenas queimando, o circuito continua normalmente.
	if _bateria_queimada_cedo_demais():
		_reiniciar_por_bateria_antecipada()
		return

	if not passo_pronto:
		return

	if _aviso_ativo:
		return

	_verificar_passo_atual()


func _input(event: InputEvent) -> void:

	if _reiniciando:
		return

	if not event is InputEventMouseButton:
		return

	var click := event as InputEventMouseButton

	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return

	if not is_visible_in_tree() or circuito == null:
		return

	var nearest: Area2D = null
	var nearest_distance := INF

	for candidate in get_tree().get_nodes_in_group("pontos_conexao"):

		if not circuito.is_ancestor_of(candidate):
			continue

		if candidate.arrastando:
			return

		var collider := candidate.get_node_or_null("CollisionShape2D") as CollisionShape2D

		if collider == null or collider.disabled or collider.shape == null:
			continue

		var transform_to_screen := collider.get_global_transform_with_canvas()
		var local_click := transform_to_screen.affine_inverse() * click.position

		if not collider.shape.get_rect().grow(1.5).has_point(local_click):
			continue

		var distance := click.position.distance_squared_to(
			transform_to_screen.origin
		)

		if distance < nearest_distance:
			nearest = candidate as Area2D
			nearest_distance = distance

	if nearest != null:
		nearest.iniciar_fio()
		get_viewport().set_input_as_handled()



# ---------------------------------------------------------------------------
# BATERIA QUEIMADA ANTES DOS COMPONENTES
# ---------------------------------------------------------------------------

func _bateria_queimada_cedo_demais() -> bool:

	# No modo em que a bateria é o único alvo,
	# queimá-la é exatamente o objetivo.
	if modo_objetivo == ModoObjetivo.QUEIMAR_BATERIA:
		return false

	# IMPORTANTE:
	# Aqui verificamos SOMENTE se a bateria TERMINOU de queimar.
	#
	# Enquanto:
	# circuito.bateria_queimando == true
	#
	# o tutorial NÃO interrompe o circuito.
	#
	# Somente quando:
	# circuito.bateria_queimada == true
	#
	# a mensagem será exibida.
	if not circuito.bateria_queimada:
		return false

	# Depois que a bateria terminou de queimar,
	# verifica se os componentes necessários já foram queimados.
	return not _componentes_alvo_queimados()


func _componentes_alvo_queimados() -> bool:

	var resistor_ok: bool = (
		circuito.resistor_queimando
		or circuito.resistor_queimado
	)

	var led_ok: bool = (
		circuito.led_queimando
		or circuito.led_queimado
	)

	match modo_objetivo:

		ModoObjetivo.QUEIMAR_RESISTOR, ModoObjetivo.QUEIMAR_RESISTOR_E_BATERIA:
			return resistor_ok

		ModoObjetivo.QUEIMAR_LED, ModoObjetivo.QUEIMAR_LED_E_BATERIA:
			return led_ok

		ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			return resistor_ok and led_ok

	return true


func _reiniciar_por_bateria_antecipada() -> void:

	_reiniciando = true
	passo_pronto = false
	_aviso_ativo = false

	_limpar_destaques()

	painel_orientacao.visible = false
	texto_orientacao.visible = false
	botao_continuar.visible = false

	# Congela o circuito somente DEPOIS que a bateria terminou
	# de queimar, para impedir qualquer outra alteração enquanto
	# a mensagem estiver aparecendo.
	circuito.process_mode = Node.PROCESS_MODE_DISABLED
	interface_jogo.process_mode = Node.PROCESS_MODE_ALWAYS

	_mostrar_mensagem_objetivo(MENSAGEM_BATERIA_ANTES)

	await get_tree().create_timer(TEMPO_MENSAGEM_REINICIO).timeout

	_reiniciar_circuito()


func _mostrar_mensagem_objetivo(texto: String) -> void:

	# 1) Método próprio da interface, se existir.
	var metodos: Array = [
		"mostrar_objetivo_concluido",
		"mostrar_mensagem_objetivo_concluido",
		"mostrar_painel_objetivo_concluido",
		"mostrar_mensagem_concluido",
		"mostrar_mensagem"
	]

	for metodo in metodos:

		if interface_jogo.has_method(metodo):
			interface_jogo.call(metodo, texto)
			return


	# 2) Procura o painel de "objetivo concluído" pelo nome do nó.
	var painel: Node = _achar_no_por_nome(interface_jogo, "conclu")

	if painel != null:

		if painel is CanvasItem:
			painel.visible = true

		var label: Label = null

		if painel is Label:
			label = painel
		else:
			var labels: Array = painel.find_children(
				"*",
				"Label",
				true,
				false
			)

			if not labels.is_empty():
				label = labels[0]

		if label != null:
			label.text = texto
			label.visible = true
			return


	# 3) Último recurso: usa o painel do tutorial
	# para a mensagem não se perder.
	painel_orientacao.visible = true
	texto_orientacao.visible = true
	texto_orientacao.text = texto
	botao_continuar.visible = false
	painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _achar_no_por_nome(raiz: Node, trecho: String) -> Node:

	for filho in raiz.get_children():

		if String(filho.name).to_lower().contains(trecho):
			return filho

		var achado: Node = _achar_no_por_nome(filho, trecho)

		if achado != null:
			return achado

	return null


func _reiniciar_circuito() -> void:

	var caminho_cena: String = scene_file_path
	var pai: Node = get_parent()

	# Sem cena própria ou sendo a cena raiz:
	# recarrega a cena atual.
	if caminho_cena.is_empty() or pai == null or get_tree().current_scene == self:
		get_tree().reload_current_scene()
		return

	var cena: PackedScene = load(caminho_cena) as PackedScene

	if cena == null:
		get_tree().reload_current_scene()
		return

	var nova = cena.instantiate()

	# Copia o estado que o pai pode ter configurado nesta instância.
	nova.modo_objetivo = modo_objetivo
	nova.position = position
	nova.rotation = rotation
	nova.scale = scale
	nova.z_index = z_index
	nova.visible = visible

	# Reconecta quem estava ouvindo os sinais do minigame.
	for nome_sinal in ["minigame_completed", "minigame_failed"]:

		for conexao in get_signal_connection_list(nome_sinal):

			nova.connect(
				nome_sinal,
				conexao["callable"],
				conexao["flags"]
			)

	var indice: int = get_index()
	var nome_original: StringName = name

	pai.remove_child(self)

	nova.name = nome_original

	pai.add_child(nova)

	pai.move_child(nova, indice)

	queue_free()



func _configurar_componente_led() -> void:

	match modo_objetivo:

		ModoObjetivo.QUEIMAR_LED, \
		ModoObjetivo.QUEIMAR_LED_E_RESISTOR, \
		ModoObjetivo.QUEIMAR_LED_E_BATERIA:

			componente1.visible = false
			Componente2.visible = true

			colison_led_terminal_positivo.position = Vector2(80, 42)
			colison_led_terminal_negativo.position = Vector2(-50, 42)


		ModoObjetivo.QUEIMAR_RESISTOR, \
		ModoObjetivo.QUEIMAR_BATERIA, \
		ModoObjetivo.QUEIMAR_RESISTOR_E_BATERIA:

			componente1.visible = true
			Componente2.visible = false

			colison_led_terminal_positivo.position = Vector2(60, 40)
			colison_led_terminal_negativo.position = Vector2(-40, 40)



func _objetivo_da_interface():

	match modo_objetivo:

		ModoObjetivo.QUEIMAR_RESISTOR:
			return interface_jogo.Objetivo.RESISTOR

		ModoObjetivo.QUEIMAR_LED:
			return interface_jogo.Objetivo.LED

		ModoObjetivo.QUEIMAR_BATERIA:
			return interface_jogo.Objetivo.BATERIA

		ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			return interface_jogo.Objetivo.RESISTOR_LED

		ModoObjetivo.QUEIMAR_LED_E_BATERIA:
			return interface_jogo.Objetivo.BATERIA_LED

		ModoObjetivo.QUEIMAR_RESISTOR_E_BATERIA:
			return interface_jogo.Objetivo.BATERIA_RESISTOR

	return interface_jogo.Objetivo.RESISTOR



func _avancar_passo(proximo: int) -> void:

	passo_pronto = false

	_iniciar_passo(proximo)



func _iniciar_passo(passo: int) -> void:

	passo_atual = passo
	passo_pronto = false

	_limpar_destaques()

	_proximo_passo_do_botao = -1

	botao_continuar.visible = false

	painel_orientacao.visible = true
	texto_orientacao.visible = true

	painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


	match modo_objetivo:

		ModoObjetivo.QUEIMAR_RESISTOR:
			_iniciar_passo_queimar_resistor(passo)

		ModoObjetivo.QUEIMAR_LED:
			_iniciar_passo_queimar_led(passo)

		ModoObjetivo.QUEIMAR_BATERIA:
			_iniciar_passo_queimar_bateria(passo)

		ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			_iniciar_passo_queimar_led_e_resistor(passo)

		ModoObjetivo.QUEIMAR_LED_E_BATERIA, \
		ModoObjetivo.QUEIMAR_RESISTOR_E_BATERIA:
			_iniciar_passo_queimar_componente_e_bateria(passo)

	passo_pronto = true



func _verificar_passo_atual() -> void:

	match modo_objetivo:

		ModoObjetivo.QUEIMAR_RESISTOR:
			_verificar_passo_queimar_resistor()

		ModoObjetivo.QUEIMAR_LED:
			_verificar_passo_queimar_led()

		ModoObjetivo.QUEIMAR_BATERIA:
			_verificar_passo_queimar_bateria()

		ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			_verificar_passo_queimar_led_e_resistor()

		ModoObjetivo.QUEIMAR_LED_E_BATERIA, \
		ModoObjetivo.QUEIMAR_RESISTOR_E_BATERIA:
			_verificar_passo_queimar_componente_e_bateria()



func _iniciar_passo_queimar_resistor(passo: int) -> void:

	match passo:

		0:
			texto_orientacao.text = \
				"Cada componente suporta uma quantidade limitada de energia."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 1


		1:
			texto_orientacao.text = \
				"O resistor reduz a tensão antes que ela chegue ao outro componente."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 2


		2:
			_destacar(bateria)
			_destacar(resistor)

			texto_orientacao.text = \
				"Para queimá-lo, aumente a tensão.\n\nClique no polo positivo da bateria."

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _verificar_passo_queimar_resistor() -> void:

	if passo_atual != 2:
		return

	if circuito.resistor_queimando or circuito.resistor_queimado:
		_finalizar_orientacao()



func _iniciar_passo_queimar_led(passo: int) -> void:

	match passo:

		0:
			texto_orientacao.text = \
				"Para queimar o componente, desvie o resistor."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 1


		1:
			_destacar(juncao03)
			_destacar(resistor)

			_corte_j03_resistor_existia = \
				_tem_conexao(
					juncao03,
					resistor_terminal_positivo
				)

			texto_orientacao.text = \
				"Corte o fio entre a primeira junção e o resistor com o botão direito."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


		2:
			_destacar(juncao04)
			_destacar(led)

			_corte_j04_led_existia = \
				_tem_conexao(
					juncao04,
					led_terminal_positivo
				)

			texto_orientacao.text = \
				"Agora corte o fio entre a junção e o componente."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


		3:
			_destacar(juncao03)
			_destacar(led)

			_conexao_j03_led_existia = \
				_tem_conexao(
					juncao03,
					led_terminal_positivo
				)

			texto_orientacao.text = \
				"Ligue a junção destacada diretamente ao componente."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _verificar_passo_queimar_led() -> void:

	match passo_atual:

		0:
			return

		1:
			if not _corte_j03_resistor_existia:
				return

			if not _tem_conexao(
				juncao03,
				resistor_terminal_positivo
			):
				_avancar_passo(2)


		2:
			if not _corte_j04_led_existia:
				return

			if not _tem_conexao(
				juncao04,
				led_terminal_positivo
			):
				_avancar_passo(3)


		3:
			if circuito.led_queimando or circuito.led_queimado:
				_finalizar_orientacao()



func _iniciar_passo_queimar_bateria(passo: int) -> void:

	match passo:

		0:
			_destacar(bateria)

			texto_orientacao.text = \
				"Um curto-circuito liga os polos sem componentes no caminho."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 1


		1:
			_destacar(bateria)

			texto_orientacao.text = \
				"Corte os fios e ligue o polo positivo diretamente ao negativo."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _verificar_passo_queimar_bateria() -> void:

	if passo_atual != 1:
		return

	if circuito.bateria_queimando or circuito.bateria_queimada:
		_finalizar_orientacao()



func _iniciar_passo_queimar_led_e_resistor(passo: int) -> void:

	match passo:

		0:
			_destacar(bateria)
			_destacar(resistor)

			texto_orientacao.text = \
				"Há dois alvos. Primeiro, aumente a tensão e queime o resistor."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


		1:
			_destacar(alicate)
			_destacar(juncao03)
			_destacar(led)

			texto_orientacao.text = \
				"Agora desvie o resistor e ligue a junção ao componente."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _verificar_passo_queimar_led_e_resistor() -> void:

	match passo_atual:

		0:
			if circuito.resistor_queimando or circuito.resistor_queimado:
				_avancar_passo(1)


		1:
			if circuito.led_queimando or circuito.led_queimado:
				_finalizar_orientacao()



func _iniciar_passo_queimar_componente_e_bateria(passo: int) -> void:

	var primeiro_led := \
		modo_objetivo == ModoObjetivo.QUEIMAR_LED_E_BATERIA

	if passo == 0:

		if primeiro_led:

			_destacar(alicate)
			_destacar(juncao03)
			_destacar(led)

			texto_orientacao.text = \
				"Desvie o resistor e queime o componente. Deixe a bateria por último."

		else:

			_destacar(bateria)
			_destacar(resistor)

			texto_orientacao.text = \
				"Aumente a tensão e queime o resistor. Deixe a bateria por último."

	elif passo == 1:

		_destacar(alicate)
		_destacar(bateria)

		texto_orientacao.text = \
			"Agora ligue os polos sem componentes no caminho para criar um curto-circuito."



func _verificar_passo_queimar_componente_e_bateria() -> void:

	var primeiro_queimado: bool = \
		circuito.led_queimado \
		if modo_objetivo == ModoObjetivo.QUEIMAR_LED_E_BATERIA \
		else circuito.resistor_queimado

	if passo_atual == 0 and primeiro_queimado:

		_avancar_passo(1)

	elif passo_atual == 1 and circuito.bateria_queimada:

		_finalizar_orientacao()



func _on_button_pressed() -> void:

	if _reiniciando:
		return

	if not passo_pronto:
		return


	if _aviso_ativo:

		var passo_retorno := _passo_antes_do_aviso

		_aviso_ativo = false

		_iniciar_passo(passo_retorno)

		return


	if _proximo_passo_do_botao >= 0:

		_avancar_passo(_proximo_passo_do_botao)

		return


	_finalizar_orientacao()



func mostrar_aviso_conexao(mensagem: String) -> void:

	if _aviso_ativo or _reiniciando:
		return

	_passo_antes_do_aviso = passo_atual

	_aviso_ativo = true

	_limpar_destaques()

	painel_orientacao.visible = true
	texto_orientacao.visible = true

	painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

	texto_orientacao.text = mensagem

	_proximo_passo_do_botao = -1

	botao_continuar.visible = true

	passo_pronto = true



func _tem_conexao(a, b) -> bool:

	if a == null or b == null:
		return false

	if not is_instance_valid(a):
		return false

	if not is_instance_valid(b):
		return false

	if "conexoes_terminais" in a:

		if b in a.conexoes_terminais:
			return true

	if "conexoes_terminais" in b:

		if a in b.conexoes_terminais:
			return true

	return false



func _finalizar_orientacao() -> void:

	_aviso_ativo = false

	passo_pronto = false

	painel_orientacao.visible = false
	texto_orientacao.visible = false
	botao_continuar.visible = false

	_limpar_destaques()



func _destacar(no: Node, z_extra: int = 5) -> void:

	if no == null:
		return

	if not is_instance_valid(no):
		return

	if no in _nos_destacados:
		return

	_nos_destacados.append(no)

	no.set_meta(
		"_z_index_original_orientacao",
		no.z_index
	)

	if no.has_method("ativar_destaque"):
		no.ativar_destaque()

	no.z_index += z_extra



func _limpar_destaques() -> void:

	for no in _nos_destacados:

		if no == null:
			continue

		if not is_instance_valid(no):
			continue

		if no.has_method("desativar_destaque"):
			no.desativar_destaque()

		if no.has_meta("_z_index_original_orientacao"):

			no.z_index = no.get_meta(
				"_z_index_original_orientacao"
			)

	_nos_destacados.clear()
