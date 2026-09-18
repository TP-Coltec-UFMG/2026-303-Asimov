extends ColorRect

enum TipoCano {
	Horizontal,
	Vertical,
	EsquerdaBaixo,
	DireitaBaixo,
	CimaEsquerda,
	CimaDireita,
}

enum DirecaoFluxo {
	Direita,
	Cima,
	Esquerda,
	Baixo,
}

const TEMPO_TOTAL: int = 30
const QUANTIDADE_TIPOS_CANOS: int = 6
const LIMITE_GRADE: Vector2i = Vector2i(7, 6)
const INICIO_PREENCHIMENTO: Vector2i = Vector2i(0, 0)
const SAIDA_GRADE: Vector2i = Vector2i(7, 6)

const SOM_VIRAR_CANO: AudioStream = preload("res://Minigames/PuzzleDosCanos/sounds/drop_002.ogg")
const SOM_ERRO: AudioStream = preload("res://Minigames/PuzzleDosCanos/sounds/soundshelfstudio-ui-error-pop-515668.mp3")
const SOM_ACERTO: AudioStream = preload("res://Minigames/PuzzleDosCanos/sounds/confirmation_002.ogg")

var cursor: Vector2i = Vector2i.ZERO
var parado: bool = false
var puzzle_concluido: bool = false
var puzzle_expirado: bool = false
var mutex_preenchimento: Mutex = Mutex.new()

var estado_preenchimento: Dictionary
var solucao_tipos: Dictionary = {}
var caminho_solucao: Array[Vector2i] = []

var grade: Array = [
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
	[null, null, null, null, null, null, null, null],
]


func _ready() -> void:
	if not $time.finished.is_connected(tempo_finalizado):
		$time.finished.connect(tempo_finalizado)
	iniciar_grade()
	$fader.show()
	reiniciar()
	$tm_blink.start()
	$time/tm.start()
	$music.play()
	$anim.play("fade_out")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		ao_apertar_tecla(event.keycode)


func iniciar_grade() -> void:
	var canos: Array = $pipes.get_children()

	for y in range(7):
		for x in range(8):
			if x == 7 and y == 6:
				pass # cano final
			else:
				grade[y][x] = canos[x * 7 + y]


func configurar_canos() -> void:
	# Primeiro preenche o tabuleiro com distrações aleatórias.
	for y in range(7):
		for x in range(8):
			if Vector2i(x, y) == SAIDA_GRADE:
				continue
			grade[y][x].set_type(randi() % QUANTIDADE_TIPOS_CANOS)

	# Depois constrói uma rota monotônica e válida. Ela sempre usa exatamente
	# seis movimentos para baixo e seis para a direita, mas em ordem aleatória.
	# Isso mantém o formato variável sem criar becos sem saída impossíveis.
	var passos: Array[int] = []
	for _index in range(6):
		passos.append(DirecaoFluxo.Baixo)
		passos.append(DirecaoFluxo.Direita)
	passos.shuffle()

	solucao_tipos.clear()
	caminho_solucao.clear()
	var posicao := INICIO_PREENCHIMENTO
	var direcao_entrada := DirecaoFluxo.Baixo
	for indice in range(passos.size() + 1):
		var direcao_saida: int = (
			passos[indice]
			if indice < passos.size()
			else DirecaoFluxo.Direita
		)
		var tipo_correto := _tipo_para_conexao(
			direcao_entrada,
			direcao_saida
		)
		solucao_tipos[posicao] = tipo_correto
		caminho_solucao.append(posicao)
		grade[posicao.y][posicao.x].set_type(
			_orientacao_aleatoria_do_mesmo_formato(tipo_correto)
		)
		if indice < passos.size():
			posicao += _vetor_da_direcao(direcao_saida)
			@warning_ignore("int_as_enum_without_cast")
			direcao_entrada = direcao_saida

	assert(_caminho_gerado_e_valido())


func _tipo_para_conexao(entrada: int, saida: int) -> int:
	if entrada == saida:
		if entrada == DirecaoFluxo.Direita or entrada == DirecaoFluxo.Esquerda:
			return TipoCano.Horizontal
		return TipoCano.Vertical
	match Vector2i(entrada, saida):
		Vector2i(DirecaoFluxo.Baixo, DirecaoFluxo.Direita):
			return TipoCano.CimaDireita
		Vector2i(DirecaoFluxo.Direita, DirecaoFluxo.Baixo):
			return TipoCano.EsquerdaBaixo
		Vector2i(DirecaoFluxo.Baixo, DirecaoFluxo.Esquerda):
			return TipoCano.CimaEsquerda
		Vector2i(DirecaoFluxo.Esquerda, DirecaoFluxo.Baixo):
			return TipoCano.DireitaBaixo
		Vector2i(DirecaoFluxo.Cima, DirecaoFluxo.Direita):
			return TipoCano.DireitaBaixo
		Vector2i(DirecaoFluxo.Direita, DirecaoFluxo.Cima):
			return TipoCano.CimaEsquerda
		Vector2i(DirecaoFluxo.Cima, DirecaoFluxo.Esquerda):
			return TipoCano.EsquerdaBaixo
		Vector2i(DirecaoFluxo.Esquerda, DirecaoFluxo.Cima):
			return TipoCano.CimaDireita
	return -1


func _orientacao_aleatoria_do_mesmo_formato(tipo_correto: int) -> int:
	if tipo_correto == TipoCano.Horizontal or tipo_correto == TipoCano.Vertical:
		return TipoCano.Horizontal if randi() % 2 == 0 else TipoCano.Vertical
	return TipoCano.EsquerdaBaixo + (randi() % 4)


func _vetor_da_direcao(direcao: int) -> Vector2i:
	match direcao:
		DirecaoFluxo.Direita:
			return Vector2i.RIGHT
		DirecaoFluxo.Cima:
			return Vector2i.UP
		DirecaoFluxo.Esquerda:
			return Vector2i.LEFT
		DirecaoFluxo.Baixo:
			return Vector2i.DOWN
	return Vector2i.ZERO


func _proxima_direcao(tipo: int, entrada: int) -> int:
	match [entrada, tipo]:
		[DirecaoFluxo.Direita, TipoCano.Horizontal]:
			return DirecaoFluxo.Direita
		[DirecaoFluxo.Direita, TipoCano.EsquerdaBaixo]:
			return DirecaoFluxo.Baixo
		[DirecaoFluxo.Direita, TipoCano.CimaEsquerda]:
			return DirecaoFluxo.Cima
		[DirecaoFluxo.Baixo, TipoCano.Vertical]:
			return DirecaoFluxo.Baixo
		[DirecaoFluxo.Baixo, TipoCano.CimaEsquerda]:
			return DirecaoFluxo.Esquerda
		[DirecaoFluxo.Baixo, TipoCano.CimaDireita]:
			return DirecaoFluxo.Direita
		[DirecaoFluxo.Esquerda, TipoCano.Horizontal]:
			return DirecaoFluxo.Esquerda
		[DirecaoFluxo.Esquerda, TipoCano.DireitaBaixo]:
			return DirecaoFluxo.Baixo
		[DirecaoFluxo.Esquerda, TipoCano.CimaDireita]:
			return DirecaoFluxo.Cima
		[DirecaoFluxo.Cima, TipoCano.Vertical]:
			return DirecaoFluxo.Cima
		[DirecaoFluxo.Cima, TipoCano.EsquerdaBaixo]:
			return DirecaoFluxo.Esquerda
		[DirecaoFluxo.Cima, TipoCano.DireitaBaixo]:
			return DirecaoFluxo.Direita
	return -1


func _caminho_gerado_e_valido() -> bool:
	var posicao := INICIO_PREENCHIMENTO
	var direcao := DirecaoFluxo.Baixo
	var visitados: Dictionary = {}
	for _passo in range(grade.size() * grade[0].size()):
		if posicao == SAIDA_GRADE:
			return true
		if (
			posicao.x < 0
			or posicao.y < 0
			or posicao.y >= grade.size()
			or posicao.x >= grade[0].size()
			or visitados.has(posicao)
			or not solucao_tipos.has(posicao)
		):
			return false
		visitados[posicao] = true
		@warning_ignore("int_as_enum_without_cast")
		direcao = _proxima_direcao(int(solucao_tipos[posicao]), direcao)
		if direcao < 0:
			return false
		posicao += _vetor_da_direcao(direcao)
	return false


func pegar_cano_em(posicao: Vector2i):
	var posicao_visual: Vector2 = Vector2(posicao * 8)

	for cano in $pipes.get_children():
		if cano.position == posicao_visual:
			return cano

	return null


func pegar_cano_no_cursor():
	return pegar_cano_em(cursor)


func preencher() -> void:
	parar_tudo()
	$start/fill.show()
	$tm_fill.start()
	$water.play()


func remover_preenchimento() -> void:
	for cano in $pipes.get_children():
		cano.unfill()

	$start/fill.hide()
	$end/fill.hide()


func virar_cano() -> void:
	var cano = pegar_cano_no_cursor()
	assert(cano != null)

	$sfx.play()
	cano.flip()


func ao_apertar_tecla(tecla: int) -> void:
	if parado:
		return

	if tecla == KEY_R:
		fazer_reinicio()

	elif tecla == KEY_SPACE:
		virar_cano()

	elif tecla == KEY_F:
		preencher()

	elif tecla == KEY_RIGHT and cursor.x < LIMITE_GRADE.x:
		if cursor.y == 6 and cursor.x + 1 == 7:
			return

		cursor.x += 1
		atualizar_cursor()

	elif tecla == KEY_LEFT and cursor.x > 0:
		cursor.x -= 1
		atualizar_cursor()

	elif tecla == KEY_UP and cursor.y > 0:
		cursor.y -= 1
		atualizar_cursor()

	elif tecla == KEY_DOWN and cursor.y < LIMITE_GRADE.y:
		if cursor.x == 7 and cursor.y + 1 == 6:
			return

		cursor.y += 1
		atualizar_cursor()


func tempo_finalizado() -> void:
	if parado or puzzle_concluido or puzzle_expirado:
		return
	puzzle_expirado = true
	parar_tudo()
	$sfx.stream = SOM_ERRO
	$sfx.play()
	$anim.play("ohno")


func reiniciar() -> void:
	puzzle_concluido = false
	puzzle_expirado = false
	estado_preenchimento = {
		"passavel": true,
		"objetivo": false,
		"cursor": Vector2i(0, -1),
		"direcao_fluxo": DirecaoFluxo.Baixo,
		"ultimo_cano": null,
	}

	$sfx.stream = SOM_VIRAR_CANO

	remover_preenchimento()
	$endround.hide()

	$time.pause()
	$time.time = TEMPO_TOTAL

	cursor = Vector2i.ZERO
	atualizar_cursor()

	configurar_canos()

	$time.start()
	$cursor.show()
	$tm_blink.start()

	parado = false


func fazer_reinicio() -> void:
	parar_tudo()
	$anim.play("fade_in")


func funcao_fade() -> void:
	reiniciar()
	$anim.play("fade_out")


func parar_tudo() -> void:
	parado = true
	$time.pause()
	$tm_blink.stop()
	$cursor.hide()


func atualizar_cursor() -> void:
	var posicao_visual: Vector2 = Vector2(cursor * 8)
	$cursor.position = $pipes.position + posicao_visual


func _on_tm_blink_timeout() -> void:
	$cursor.visible = not $cursor.visible


func _on_tm_fill_timeout() -> void:
	mutex_preenchimento.lock()

	var ultimo_cano = estado_preenchimento["ultimo_cano"]
	var posicao_atual: Vector2i = estado_preenchimento["cursor"]
	var direcao_fluxo: int = estado_preenchimento["direcao_fluxo"]
	var passavel: bool = estado_preenchimento["passavel"]
	var objetivo: bool = estado_preenchimento["objetivo"]
	var cano = null

	if ultimo_cano != null:
		if not ultimo_cano.filled:
			mutex_preenchimento.unlock()
			return

	if not objetivo and not passavel:
		$tm_fill.stop()
		$water.stop()

		$sfx.stream = SOM_ERRO
		$sfx.play()

		$anim.play("ohno")

		mutex_preenchimento.unlock()
		return

	elif objetivo:
		$tm_fill.stop()
		$water.stop()
		puzzle_concluido = true

		$sfx.stream = SOM_ACERTO
		$sfx.play()

		$anim.play("clear")

		mutex_preenchimento.unlock()
		return

	if direcao_fluxo == DirecaoFluxo.Direita:
		cano = pegar_cano_em(posicao_atual + Vector2i(1, 0))

		if cano == null:
			# Verifica se o cursor de preenchimento está ao lado do cano final
			if posicao_atual.x == 6 and posicao_atual.y == 6:
				estado_preenchimento["objetivo"] = true
				$end/fill.show()
			else:
				estado_preenchimento["passavel"] = false

			mutex_preenchimento.unlock()
			return

		match cano.type:
			TipoCano.Horizontal, TipoCano.EsquerdaBaixo, TipoCano.CimaEsquerda:
				estado_preenchimento["cursor"].x += 1

				if cano.type == TipoCano.EsquerdaBaixo:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Baixo
				elif cano.type == TipoCano.CimaEsquerda:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Cima

				cano.fill(estado_preenchimento["direcao_fluxo"])

			_:
				estado_preenchimento["passavel"] = false

	elif direcao_fluxo == DirecaoFluxo.Cima:
		cano = pegar_cano_em(posicao_atual + Vector2i(0, -1))

		if cano == null:
			estado_preenchimento["passavel"] = false
			mutex_preenchimento.unlock()
			return

		match cano.type:
			TipoCano.Vertical, TipoCano.EsquerdaBaixo, TipoCano.DireitaBaixo:
				estado_preenchimento["cursor"].y -= 1

				if cano.type == TipoCano.EsquerdaBaixo:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Esquerda
				elif cano.type == TipoCano.DireitaBaixo:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Direita

				cano.fill(estado_preenchimento["direcao_fluxo"])

			_:
				estado_preenchimento["passavel"] = false

	elif direcao_fluxo == DirecaoFluxo.Esquerda:
		cano = pegar_cano_em(posicao_atual + Vector2i(-1, 0))

		if cano == null:
			estado_preenchimento["passavel"] = false
			mutex_preenchimento.unlock()
			return

		match cano.type:
			TipoCano.Horizontal, TipoCano.DireitaBaixo, TipoCano.CimaDireita:
				estado_preenchimento["cursor"].x -= 1

				if ultimo_cano != null:
					ultimo_cano.fill(direcao_fluxo)

				if cano.type == TipoCano.DireitaBaixo:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Baixo
				elif cano.type == TipoCano.CimaDireita:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Cima

				cano.fill(estado_preenchimento["direcao_fluxo"])

			_:
				estado_preenchimento["passavel"] = false

	elif direcao_fluxo == DirecaoFluxo.Baixo:
		cano = pegar_cano_em(posicao_atual + Vector2i(0, 1))

		if cano == null:
			estado_preenchimento["passavel"] = false
			mutex_preenchimento.unlock()
			return

		match cano.type:
			TipoCano.Vertical, TipoCano.CimaEsquerda, TipoCano.CimaDireita:
				estado_preenchimento["cursor"].y += 1

				if cano.type == TipoCano.CimaEsquerda:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Esquerda
				elif cano.type == TipoCano.CimaDireita:
					estado_preenchimento["direcao_fluxo"] = DirecaoFluxo.Direita

				cano.fill(estado_preenchimento["direcao_fluxo"])

			_:
				estado_preenchimento["passavel"] = false

	if estado_preenchimento["passavel"]:
		estado_preenchimento["ultimo_cano"] = cano

	mutex_preenchimento.unlock()


# Compatibilidade com nomes antigos de sinais/funções.
# Assim, se algum sinal antigo ainda chamar esses métodos, o jogo não quebra.

func on_time_finished() -> void:
	tempo_finalizado()


func reset() -> void:
	reiniciar()


func do_reset() -> void:
	# No último frame da animação, current_animation já pode estar vazio.
	# O resultado é registrado no instante em que a água alcança a saída.
	if puzzle_concluido and Progresso.retorno_refrigeracao_ia:
		Progresso.concluir_refrigeracao_ia()
		return
	if puzzle_expirado and Progresso.retorno_refrigeracao_ia:
		Progresso.falhar_refrigeracao_ia()
		return
	fazer_reinicio()


func fade_func() -> void:
	funcao_fade()


func stop_everything() -> void:
	parar_tudo()


func update_cursor() -> void:
	atualizar_cursor()


func fill() -> void:
	preencher()


func unfill() -> void:
	remover_preenchimento()


func flip_pipe() -> void:
	virar_cano()


func on_key_pressed(key: int) -> void:
	ao_apertar_tecla(key)


func get_pipe_at(vec: Vector2i):
	return pegar_cano_em(vec)


func get_pipe_at_cursor():
	return pegar_cano_no_cursor()
