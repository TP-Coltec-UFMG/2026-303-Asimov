extends Node2D

const RAIO_ACERTO := 17.0
const ESPESSURA_FIO := 6.0
const TEMPO_ERRO := 0.28

@onready var conectores_esquerda: Node2D = $LeftSockets
@onready var conectores_direita: Node2D = $RightSockets
@onready var container_fios: Node2D = $WiresContainer
@onready var indicador_selecao: Sprite2D = $SelectIndicator
@onready var indicador_erro: Sprite2D = $WrongIndicator
@onready var texto_vitoria: Label = $WinLabel

var textura_fio: Texture2D

var esquerda := []
var direita := []

var fios := {}
var quantidade_conectados := 0
var tarefa_concluida := false

var lado_selecionado := ""
var indice_selecionado := -1

var temporizador_erro := 0.0
var retornando_ao_jogo := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	randomize()
	textura_fio = load("res://Minigames/Minigame2/assets/wire.png")
	_coletar_conectores()
	_configurar_tabuleiro()


func _coletar_conectores() -> void:
	esquerda.clear()
	direita.clear()

	for node in conectores_esquerda.get_children():
		esquerda.append({"id": 0, "conectado": false, "node": node})

	for node in conectores_direita.get_children():
		direita.append({"id": 0, "conectado": false, "node": node})


func _configurar_tabuleiro() -> void:
	for c in fios:
		fios[c].queue_free()

	fios.clear()
	quantidade_conectados = 0
	tarefa_concluida = false
	lado_selecionado = ""
	indice_selecionado = -1

	indicador_selecao.visible = false
	indicador_erro.visible = false
	texto_vitoria.visible = false

	var ordem: Array = range(7)
	ordem.shuffle()

	for i in range(7):
		var entrada = esquerda[i]
		entrada.id = i
		entrada.conectado = false
		entrada.node.socket_id = i

	for i in range(7):
		var entrada = direita[i]
		entrada.id = ordem[i]
		entrada.conectado = false
		entrada.node.socket_id = ordem[i]


func _process(delta: float) -> void:
	if temporizador_erro > 0.0:
		temporizador_erro -= delta

		if temporizador_erro <= 0.0:
			indicador_erro.visible = false


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (
			event.is_action_pressed("esc")
			or event.keycode == KEY_ESCAPE
			or event.physical_keycode == KEY_ESCAPE
		)
	):
		get_viewport().set_input_as_handled()
		Progresso.cancelar_reparo_leitor_rfid()
		return

	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode == KEY_R or event.physical_keycode == KEY_R)
	):
		get_viewport().set_input_as_handled()
		_configurar_tabuleiro()
		return

	if tarefa_concluida:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_tratar_clique(to_local(event.position))


func _tratar_clique(posicao: Vector2) -> void:
	var lado_clicado := ""
	var indice_clicado := -1

	for i in range(esquerda.size()):
		if posicao.distance_to(esquerda[i].node.position) <= RAIO_ACERTO:
			lado_clicado = "esquerda"
			indice_clicado = i
			break

	if lado_clicado == "":
		for i in range(direita.size()):
			if posicao.distance_to(direita[i].node.position) <= RAIO_ACERTO:
				lado_clicado = "direita"
				indice_clicado = i
				break

	if lado_clicado == "":
		return

	var lista: Array = esquerda if lado_clicado == "esquerda" else direita
	var conector = lista[indice_clicado]

	if conector.conectado:
		_desconectar(conector.id)
		return

	if lado_selecionado == "":
		lado_selecionado = lado_clicado
		indice_selecionado = indice_clicado
		indicador_selecao.position = conector.node.position
		indicador_selecao.visible = true
		return

	if lado_selecionado == lado_clicado and indice_selecionado == indice_clicado:
		lado_selecionado = ""
		indice_selecionado = -1
		indicador_selecao.visible = false
		return

	if lado_selecionado == lado_clicado:
		lado_selecionado = lado_clicado
		indice_selecionado = indice_clicado
		indicador_selecao.position = conector.node.position
		indicador_selecao.visible = true
		return

	var primeira_lista: Array = esquerda if lado_selecionado == "esquerda" else direita
	var primeiro = primeira_lista[indice_selecionado]

	indicador_selecao.visible = false

	if primeiro.id == conector.id:
		primeiro.conectado = true
		conector.conectado = true

		_criar_fio(
			primeiro.id,
			primeiro.node.position,
			conector.node.position
		)

		quantidade_conectados += 1

		if quantidade_conectados >= 7:
			tarefa_concluida = true
			texto_vitoria.visible = true
			_concluir_reparo()
	else:
		indicador_erro.position = conector.node.position
		indicador_erro.visible = true
		temporizador_erro = TEMPO_ERRO

	lado_selecionado = ""
	indice_selecionado = -1


func _criar_fio(id: int, posicao_inicial: Vector2, posicao_final: Vector2) -> void:
	var fio := Sprite2D.new()

	fio.texture = textura_fio
	fio.modulate = Socket.COLORS[id]
	fio.position = (posicao_inicial + posicao_final) / 2.0
	fio.rotation = posicao_inicial.angle_to_point(posicao_final)

	var distancia = posicao_inicial.distance_to(posicao_final)
	var tamanho_base: Vector2 = textura_fio.get_size()

	fio.scale = Vector2(
		distancia / tamanho_base.x,
		ESPESSURA_FIO / tamanho_base.y
	)

	container_fios.add_child(fio)
	fios[id] = fio


func _desconectar(id: int) -> void:
	for esquerda_item in esquerda:
		if esquerda_item.id == id:
			esquerda_item.conectado = false

	for direita_item in direita:
		if direita_item.id == id:
			direita_item.conectado = false

	if fios.has(id):
		fios[id].queue_free()
		fios.erase(id)

	quantidade_conectados -= 1
	tarefa_concluida = false
	texto_vitoria.visible = false


func _concluir_reparo() -> void:
	if retornando_ao_jogo:
		return
	retornando_ao_jogo = true
	await get_tree().create_timer(1.0).timeout
	if Progresso.retorno_reparo_rfid:
		Progresso.concluir_reparo_leitor_rfid()
