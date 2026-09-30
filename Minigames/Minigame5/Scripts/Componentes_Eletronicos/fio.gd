extends Node2D


@onready var linha: Line2D = $Line2D

@onready var terminal_a: Area2D = $Terminal_A
@onready var terminal_b: Area2D = $Terminal_B

@onready var sprite_a: Sprite2D = $Terminal_A/Sprite2D
@onready var sprite_b: Sprite2D = $Terminal_B/Sprite2D

@onready var pos_a: CollisionShape2D = $Terminal_A/CollisionShape2D
@onready var pos_b: CollisionShape2D = $Terminal_B/CollisionShape2D

@onready var colisao_fio: CollisionShape2D = $Area2D/CollisionShape2D



@export var quantidade_pontos: int = 20

@export var raio_deteccao_ponta: float = 40.0

@export var offset_ponta_a: Vector2 = Vector2.ZERO
@export var offset_ponta_b: Vector2 = Vector2.ZERO

@export var comprimento_reto: float = 10.0

@export var velocidade_rotacao_terminal: float = 900.0

@export var folga_fio: float = 1.25

@export var comprimento_maximo: float = 195.0

@export var inicio_esticar: float = 0.75

@export var gravidade_fio: float = 260.0

@export var amortecimento: float = 0.985

@export var iteracoes_restricao: int = 8


var origem: Node2D = null
var destino: Node2D = null

var arrastando: bool = false

var origem_e_juncao: bool = false
var destino_e_juncao: bool = false

var arrastando_ponta: bool = false
var ponta_arrastada: String = ""
var mouse_follow_ponta: Node2D = null

var _posicao_inicial_ponta: Dictionary = {}

const DURACAO_VOLTA_PONTA: float = 0.25

var pontos_pos: PackedVector2Array = PackedVector2Array()
var pontos_pos_anterior: PackedVector2Array = PackedVector2Array()

var _direcao_terminal_a: Vector2 = Vector2.UP
var _direcao_terminal_b: Vector2 = Vector2.UP


func _ready() -> void:

	add_to_group("fios")

	colisao_fio.shape = ConcavePolygonShape2D.new()

	linha.clear_points()

	for i in range(quantidade_pontos):
		linha.add_point(Vector2.ZERO)


	terminal_a.input_pickable = true

	if not terminal_a.input_event.is_connected(_on_terminal_a_input_event):
		terminal_a.input_event.connect(_on_terminal_a_input_event)

	terminal_b.input_pickable = true

	if not terminal_b.input_event.is_connected(_on_terminal_b_input_event):
		terminal_b.input_event.connect(_on_terminal_b_input_event)


func conectar(
	ponto_origem: Node2D,
	ponto_destino: Node2D
) -> void:

	if ponto_origem == null:
		return

	if ponto_destino == null:
		return


	origem = ponto_origem
	destino = ponto_destino

	arrastando = true

	origem_e_juncao = true
	destino_e_juncao = false

	_inicializar_pontos(origem.global_position, destino.global_position)

	pass
	pass



func fixar() -> void:

	if destino == null:
		return

	if not is_instance_valid(destino):
		return


	var posicao_final := destino.global_position

	var ponto_fixo := Node2D.new()
	ponto_fixo.name = "PontoFixoFio"

	add_child(ponto_fixo)
	ponto_fixo.global_position = posicao_final

	destino = ponto_fixo
	destino_e_juncao = false

	arrastando = false

	pass



func _on_terminal_a_input_event(_viewport, event, _shape_idx) -> void:
	_tentar_iniciar_arraste_ponta(event, "origem")


func _on_terminal_b_input_event(_viewport, event, _shape_idx) -> void:
	_tentar_iniciar_arraste_ponta(event, "destino")


func _tentar_iniciar_arraste_ponta(event, qual: String) -> void:

	if not is_visible_in_tree() or not can_process():
		return
	if arrastando or arrastando_ponta:
		return

	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not event.pressed:
		return

	if qual == "origem" and origem_e_juncao:
		return

	if qual == "destino" and destino_e_juncao:
		return

	_iniciar_arraste_ponta(qual)
	get_viewport().set_input_as_handled()


func _iniciar_arraste_ponta(qual: String) -> void:

	var ponto_atual = origem if qual == "origem" else destino

	if (
		not _posicao_inicial_ponta.has(qual)
		and ponto_atual != null
		and is_instance_valid(ponto_atual)
	):
		_posicao_inicial_ponta[qual] = ponto_atual.global_position

	ponta_arrastada = qual
	arrastando_ponta = true

	mouse_follow_ponta = Node2D.new()
	add_child(mouse_follow_ponta)
	mouse_follow_ponta.global_position = get_global_mouse_position()

	if qual == "origem":
		_remover_ponto_fixo(origem)
		origem = mouse_follow_ponta
	else:
		_remover_ponto_fixo(destino)
		destino = mouse_follow_ponta


	pass


func _remover_ponto_fixo(ponto: Node2D) -> void:

	if ponto == null:
		return

	if not is_instance_valid(ponto):
		return

	if ponto.name == "PontoFixoFio" or ponto.name == "PontoAutomatico":
		ponto.queue_free()


func _input(event: InputEvent) -> void:

	if not is_visible_in_tree() or not can_process():
		cancelar_arraste()
		return
	if not arrastando_ponta:
		return

	if event is InputEventMouseMotion:

		if mouse_follow_ponta == null:
			return

		if not is_instance_valid(mouse_follow_ponta):
			return

		mouse_follow_ponta.global_position = _limitar_por_comprimento_maximo(get_global_mouse_position())

	elif event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if not event.pressed:
			_finalizar_arraste_ponta()
func _limitar_por_comprimento_maximo(pos_desejada: Vector2) -> Vector2:

	var ancora = _obter_ancora_oposta()

	if ancora == null:
		return pos_desejada

	var vetor = pos_desejada - ancora
	var distancia = vetor.length()


	if distancia >= comprimento_maximo:

		pass

		return ancora + vetor.normalized() * comprimento_maximo

	return pos_desejada

func _obter_ancora_oposta() -> Variant:

	if ponta_arrastada == "destino":
		if origem != null and is_instance_valid(origem):
			return origem.global_position

	elif ponta_arrastada == "origem":
		if destino != null and is_instance_valid(destino):
			return destino.global_position

	return null


func _finalizar_arraste_ponta() -> void:

	arrastando_ponta = false

	var alvo = _encontrar_juncao_proxima()

	if alvo != null and not _tutorial_permite_conexao():
		_recusar_conexao()
	elif alvo != null:
		_conectar_ponta_em_juncao(alvo)
	else:
		_fixar_ponta_solta()

	if mouse_follow_ponta != null:
		if is_instance_valid(mouse_follow_ponta):
			mouse_follow_ponta.queue_free()

	mouse_follow_ponta = null
	ponta_arrastada = ""
func _encontrar_juncao_proxima() -> Variant:
	var ancora: Variant = _obter_ancora_oposta()
	var mouse_pos := get_global_mouse_position()
	var melhor_dist: float = raio_deteccao_ponta
	var melhor: Variant = null

	for p in get_tree().get_nodes_in_group("juncoes"):
		if not is_instance_valid(p) or not p.is_visible_in_tree() or not p.esta_disponivel():
			continue
		if not is_instance_valid(p.ponto_colisao):
			continue
		if ponta_arrastada == "destino" and origem_e_juncao and origem == p.ponto_colisao:
			continue
		if ponta_arrastada == "origem" and destino_e_juncao and destino == p.ponto_colisao:
			continue

		if ancora != null and ancora.distance_to(p.ponto_colisao.global_position) > comprimento_maximo:
			continue
		var dist: float = mouse_pos.distance_to(p.ponto_colisao.global_position)
		if dist < melhor_dist:
			melhor_dist = dist
			melhor = p
	return melhor



func _tutorial_permite_conexao() -> bool:

	var gerente = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if gerente == null:
		return true

	if not gerente.has_method("pode_conectar_cabo"):
		return true

	return gerente.pode_conectar_cabo()


func _recusar_conexao() -> void:

	pass

	var gerente = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if gerente != null and gerente.has_method("mostrar_ainda_nao"):
		gerente.mostrar_ainda_nao()

	var posicao_atual: Vector2 = get_global_mouse_position()

	if mouse_follow_ponta != null and is_instance_valid(mouse_follow_ponta):
		posicao_atual = mouse_follow_ponta.global_position

	var posicao_volta: Vector2 = _posicao_inicial_ponta.get(
		ponta_arrastada,
		posicao_atual
	)

	var ponto_fixo := Node2D.new()
	ponto_fixo.name = "PontoFixoFio"

	add_child(ponto_fixo)
	ponto_fixo.global_position = posicao_atual

	if ponta_arrastada == "origem":
		origem = ponto_fixo
		origem_e_juncao = false
	else:
		destino = ponto_fixo
		destino_e_juncao = false

	var tween := ponto_fixo.create_tween()

	tween.tween_property(
		ponto_fixo,
		"global_position",
		posicao_volta,
		DURACAO_VOLTA_PONTA
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _conectar_ponta_em_juncao(alvo) -> void:

	if ponta_arrastada == "origem":
		origem = alvo.ponto_colisao
		origem_e_juncao = true
	else:
		destino = alvo.ponto_colisao
		destino_e_juncao = true

	alvo.adicionar_conexao(self)
	_atualizar_juncoes()


	pass


func _fixar_ponta_solta() -> void:

	var posicao_atual := get_global_mouse_position()

	posicao_atual = _limitar_por_comprimento_maximo(posicao_atual)

	var ponto_fixo := Node2D.new()
	ponto_fixo.name = "PontoFixoFio"

	add_child(ponto_fixo)
	ponto_fixo.global_position = posicao_atual

	if ponta_arrastada == "origem":
		origem = ponto_fixo
		origem_e_juncao = false
	else:
		destino = ponto_fixo
		destino_e_juncao = false

	pass


func _process(delta: float) -> void:

	if origem == null or destino == null:
		return

	if not is_instance_valid(origem):
		return

	if not is_instance_valid(destino):
		return



	terminal_a.global_position = origem.global_position
	terminal_b.global_position = destino.global_position



	pos_a.global_position = sprite_a.global_position
	pos_b.global_position = sprite_b.global_position

	pos_a.global_rotation = sprite_a.global_rotation
	pos_b.global_rotation = sprite_b.global_rotation



	var socket_a := sprite_a.to_global(offset_ponta_a)
	var socket_b := sprite_b.to_global(offset_ponta_b)



	if socket_a.distance_to(socket_b) > comprimento_maximo:

		var direcao: Vector2

		if ponta_arrastada == "destino":

			direcao = (
				socket_b - socket_a
			).normalized()

			socket_b = (
				socket_a +
				direcao * comprimento_maximo
			)

		elif ponta_arrastada == "origem":

			direcao = (
				socket_a - socket_b
			).normalized()

			socket_a = (
				socket_b +
				direcao * comprimento_maximo
			)



	if pontos_pos.size() != quantidade_pontos:

		_inicializar_pontos(
			socket_a,
			socket_b
		)



	_simular_fio(
		delta,
		socket_a,
		socket_b
	)



	atualizar_rotacao_terminais()



	atualizar_fio()


func _inicializar_pontos(global_a: Vector2, global_b: Vector2) -> void:

	pontos_pos.resize(quantidade_pontos)
	pontos_pos_anterior.resize(quantidade_pontos)

	for i in range(quantidade_pontos):
		var t := float(i) / float(quantidade_pontos - 1)
		var p := global_a.lerp(global_b, t)
		pontos_pos[i] = p
		pontos_pos_anterior[i] = p

	var direcao_inicial := (global_b - global_a)
	if direcao_inicial.length() > 0.001:
		_direcao_terminal_a = direcao_inicial.normalized()
		_direcao_terminal_b = -direcao_inicial.normalized()


func _simular_fio(delta: float, socket_a: Vector2, socket_b: Vector2) -> void:

	var n := pontos_pos.size()

	for i in range(1, n - 1):
		var atual := pontos_pos[i]
		var velocidade := (atual - pontos_pos_anterior[i]) * amortecimento
		pontos_pos_anterior[i] = atual
		pontos_pos[i] = atual + velocidade + Vector2(0.0, gravidade_fio) * delta * delta

	pontos_pos[0] = socket_a
	pontos_pos[n - 1] = socket_b

	var distancia_pontas := socket_a.distance_to(socket_b)

	var limite_inicio_esticar: float = comprimento_maximo * inicio_esticar
	var folga_efetiva := folga_fio

	if distancia_pontas > limite_inicio_esticar:
		var margem: float = max(comprimento_maximo - limite_inicio_esticar, 0.001)
		var t: float = clamp((distancia_pontas - limite_inicio_esticar) / margem, 0.0, 1.0)
		folga_efetiva = lerp(folga_fio, 1.0, t)

	var comprimento_total: float = clamp(distancia_pontas * folga_efetiva, 4.0, comprimento_maximo)
	var comprimento_segmento := comprimento_total / float(n - 1)

	for _iter in range(iteracoes_restricao):

		for i in range(n - 1):

			var p1 := pontos_pos[i]
			var p2 := pontos_pos[i + 1]
			var diff := p2 - p1
			var dist := diff.length()

			if dist < 0.0001:
				continue

			var erro := comprimento_segmento - dist
			var correcao := diff.normalized() * erro * 0.5

			if i > 0:
				pontos_pos[i] -= correcao

			if i + 1 < n - 1:
				pontos_pos[i + 1] += correcao

		pontos_pos[0] = socket_a
		pontos_pos[n - 1] = socket_b

	var reto_efetivo: float = clamp(comprimento_reto, 0.0, comprimento_total * 0.4)
	var qtd := _qtd_pontos_trecho(reto_efetivo, comprimento_segmento, n)

	var alvo_dir_a := _direcao_ponto_flexivel(socket_a, pontos_pos[qtd])
	var alvo_dir_b := _direcao_ponto_flexivel(socket_b, pontos_pos[n - 1 - qtd])

	if origem_e_juncao:
		alvo_dir_a = _travar_horizontal(_direcao_terminal_a, alvo_dir_a)

	if destino_e_juncao:
		alvo_dir_b = _travar_horizontal(_direcao_terminal_b, alvo_dir_b)

	_direcao_terminal_a = _girar_direcao(_direcao_terminal_a, alvo_dir_a, delta)
	_direcao_terminal_b = _girar_direcao(_direcao_terminal_b, alvo_dir_b, delta)

	_endireitar_trecho(0, 1, socket_a, qtd, comprimento_segmento, _direcao_terminal_a)
	_endireitar_trecho(n - 1, -1, socket_b, qtd, comprimento_segmento, _direcao_terminal_b)


func _qtd_pontos_trecho(comprimento: float, comprimento_segmento: float, n: int) -> int:

	var qtd := int(round(comprimento / max(comprimento_segmento, 0.001)))
	return clampi(qtd, 0, int(n / 2.0) - 1)


func _direcao_ponto_flexivel(socket: Vector2, ponto: Vector2) -> Vector2:

	var d := ponto - socket

	if d.length() < 0.001:
		return Vector2.UP

	return d.normalized()


func _travar_horizontal(atual: Vector2, alvo: Vector2) -> Vector2:

	var preferir_direita := alvo.x >= 0.0

	if absf(alvo.x) < 4.0:
		preferir_direita = atual.x >= 0.0

	return Vector2.RIGHT if preferir_direita else Vector2.LEFT


func _girar_direcao(atual: Vector2, alvo: Vector2, delta: float) -> Vector2:

	var atual_n := atual.normalized() if atual.length() > 0.001 else Vector2.UP
	var alvo_n := alvo.normalized() if alvo.length() > 0.001 else atual_n

	var passo_max := deg_to_rad(velocidade_rotacao_terminal) * delta
	var angulo := atual_n.angle_to(alvo_n)
	var passo: float = clamp(angulo, -passo_max, passo_max)

	return atual_n.rotated(passo)


func _endireitar_trecho(indice_inicial: int, passo: int, socket: Vector2, qtd: int, comprimento_segmento: float, direcao: Vector2) -> void:

	for i in range(qtd + 1):
		var idx := indice_inicial + i * passo
		var p := socket + direcao * (comprimento_segmento * i)
		pontos_pos[idx] = p
		pontos_pos_anterior[idx] = p


func atualizar_rotacao_terminais() -> void:

	sprite_a.global_rotation = _direcao_terminal_a.angle() + deg_to_rad(-90)
	sprite_b.global_rotation = _direcao_terminal_b.angle() + deg_to_rad(-90)


func atualizar_fio() -> void:

	if origem == null or destino == null:
		return

	for i in range(pontos_pos.size()):
		linha.set_point_position(i, linha.to_local(pontos_pos[i]))

	atualizar_colisao()


func atualizar_colisao() -> void:

	if colisao_fio == null:
		return

	var forma := colisao_fio.shape as ConcavePolygonShape2D

	if forma == null:
		forma = ConcavePolygonShape2D.new()

	var segmentos := PackedVector2Array()

	for i in range(pontos_pos.size() - 1):
		segmentos.append(colisao_fio.to_local(pontos_pos[i]))
		segmentos.append(colisao_fio.to_local(pontos_pos[i + 1]))

	forma.segments = segmentos
	colisao_fio.shape = forma
	colisao_fio.disabled = false


func esta_conectado() -> bool:
	return origem_e_juncao and destino_e_juncao and is_instance_valid(origem) and is_instance_valid(destino)


func _atualizar_juncoes() -> void:
	for ponto in [origem, destino]:
		if is_instance_valid(ponto) and ponto.get_parent().has_method("atualizar_estado_conexao"):
			ponto.get_parent().atualizar_estado_conexao()


func cancelar_arraste() -> void:
	if not arrastando_ponta:
		return

	var ponto_fixo := Node2D.new()
	ponto_fixo.name = "PontoFixoFio"
	add_child(ponto_fixo)
	ponto_fixo.global_position = mouse_follow_ponta.global_position
	if ponta_arrastada == "origem":
		origem = ponto_fixo
	else:
		destino = ponto_fixo
	mouse_follow_ponta.queue_free()
	mouse_follow_ponta = null
	ponta_arrastada = ""
	arrastando_ponta = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancelar_arraste()


func _exit_tree() -> void:
	for juncao in get_tree().get_nodes_in_group("juncoes"):
		juncao.remover_conexao(self)
	_remover_ponto_fixo(origem)
	_remover_ponto_fixo(destino)
