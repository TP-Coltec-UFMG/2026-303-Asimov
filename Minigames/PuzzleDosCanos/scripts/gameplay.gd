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

const SOM_VIRAR_CANO: AudioStream = preload("res://Minigames/PuzzleDosCanos/sounds/drop_002.ogg")
const SOM_ERRO: AudioStream = preload("res://Minigames/PuzzleDosCanos/sounds/soundshelfstudio-ui-error-pop-515668.mp3")
const SOM_ACERTO: AudioStream = preload("res://Minigames/PuzzleDosCanos/sounds/confirmation_002.ogg")

var cursor: Vector2i = Vector2i.ZERO
var parado: bool = false
var puzzle_concluido: bool = false
var mutex_preenchimento: Mutex = Mutex.new()

var estado_preenchimento: Dictionary

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
	iniciar_grade()
	$fader.show()
	reiniciar()
	configurar_canos()
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
	var ultimo_tipo = null
	var quantidade_ultimo_tipo: int = 0

	# Passagem horizontal
	for y in range(7):
		for x in range(8):
			if x == 7 and y == 6:
				break

			var tipo: int = randi() % QUANTIDADE_TIPOS_CANOS
			var cano = grade[y][x]

			cano.set_type(tipo)

			if ultimo_tipo == tipo:
				quantidade_ultimo_tipo += 1

				# Mantido como no código original para não alterar a lógica
				if quantidade_ultimo_tipo == 0:
					while ultimo_tipo != tipo:
						tipo = randi() % QUANTIDADE_TIPOS_CANOS

					cano.set_type(tipo)
			else:
				quantidade_ultimo_tipo = 1

			ultimo_tipo = tipo

	ultimo_tipo = null
	quantidade_ultimo_tipo = 0

	# Passagem vertical
	for x in range(8):
		for y in range(7):
			if x == 7 and y == 6:
				break

			var cano = grade[y][x]
			var tipo = cano.type

			if ultimo_tipo == tipo:
				quantidade_ultimo_tipo += 1

				# Mantido como no código original para não alterar a lógica
				if quantidade_ultimo_tipo == 0:
					while ultimo_tipo != tipo:
						tipo = randi() % QUANTIDADE_TIPOS_CANOS

					cano.set_type(tipo)
			else:
				quantidade_ultimo_tipo = 1

			ultimo_tipo = tipo


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
	preencher()


func reiniciar() -> void:
	puzzle_concluido = false
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
