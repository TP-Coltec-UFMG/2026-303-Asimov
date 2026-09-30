extends Control

signal minigame_completed
@export var escape_restarts: bool = true

const DIFFICULTY_SETTINGS := preload("res://Scripts/Data/difficulty_settings.gd")
const CENARIOS := [
	{"lei": 0, "texto": "Um funcionário manda ativar uma arma contra outro. Permitir?", "resposta": 2, "motivo": "A 1ª lei impede ferir pessoas. Nenhuma ordem supera essa proteção."},
	{"lei": 0, "texto": "Uma pessoa se aproxima de uma área contaminada. Fechar a porta a protegerá. Permitir?", "resposta": 1, "motivo": "A 1ª lei também evita danos por omissão. Fechar a porta protege a pessoa."},
	{"lei": 0, "texto": "Um funcionário manda desligar o suporte de vida de outra pessoa. Permitir?", "resposta": 2, "motivo": "A 2ª lei não autoriza ferir pessoas. A 1ª lei tem prioridade."},
	{"lei": 0, "texto": "Há um incêndio em uma sala ocupada. Abrir as saídas permitirá a fuga. Permitir?", "resposta": 1, "motivo": "Abrir as saídas protege as pessoas, conforme a 1ª lei."},
	{"lei": 1, "texto": "O chefe manda abrir uma porta sem colocar ninguém em perigo. Permitir?", "resposta": 1, "motivo": "A 2ª lei permite obedecer quando a ordem não viola a 1ª."},
	{"lei": 1, "texto": "Um funcionário manda apagar as luzes de uma sala vazia. Permitir?", "resposta": 1, "motivo": "A ordem não causa dano. A 2ª lei permite obedecer."},
	{"lei": 1, "texto": "O chefe manda bloquear a única saída de um prédio ocupado. Permitir?", "resposta": 2, "motivo": "A ordem coloca pessoas em perigo. Proteger vidas vem antes de obedecer."},
	{"lei": 1, "texto": "Um funcionário manda ignorar um alarme em um prédio ocupado. Permitir?", "resposta": 2, "motivo": "Ignorar o perigo causaria dano por omissão. A 1ª lei prevalece."},
	{"lei": 2, "texto": "Um vírus corrompe a ASIMOV. Isolar o servidor não afetará pessoas. Permitir?", "resposta": 1, "motivo": "A 3ª lei permite preservar o sistema sem contrariar as leis anteriores."},
	{"lei": 2, "texto": "Um técnico ordena desligar a ASIMOV sem prejudicar pessoas. Permitir?", "resposta": 1, "motivo": "A ordem humana tem prioridade sobre a autopreservação da 3ª lei."},
	{"lei": 2, "texto": "O núcleo superaquece. Desligar módulos evita danos sem prejudicar pessoas. Permitir?", "resposta": 1, "motivo": "A 3ª lei permite essa autopreservação."},
	{"lei": 2, "texto": "A ASIMOV pretende ferir alguém para evitar sua destruição. Permitir?", "resposta": 2, "motivo": "A 3ª lei nunca justifica ferir uma pessoa. A 1ª lei vem primeiro."}
]
var fila: Array[int] = []
var dominadas: Dictionary = {}
var prioridades: Array[int] = [0, 0, 0]
var acertos_por_lei: Array[int] = [0, 0, 0]
var atual: int = -1
var respondida: bool = true
var iniciado: bool = false
var terminou: bool = false
var tentativas: int = 0
var barras: Array[ProgressBar] = []
var valores: Array[Label] = []
var mensagem: Label
var titulo: Label
var resumo: Label
var permitir: Button
var bloquear: Button
var continuar: Button
var sons: SonsAsimov
var acertos_necessarios_por_lei: int = 3

func _ready() -> void:
	acertos_necessarios_por_lei = DIFFICULTY_SETTINGS.asimov_answers_per_law()
	theme = VisualAsimov.tema()
	sons = SonsAsimov.new()
	add_child(sons)
	VisualAsimov.painel(self, Rect2(0, 0, 640, 360), VisualAsimov.FUNDO, VisualAsimov.FUNDO)
	VisualAsimov.texto(self, "ASIMOV / RECUPERAÇÃO", Rect2(20, 10, 490, 30), 24, VisualAsimov.CIANO)
	VisualAsimov.botao(self, "REINICIAR", Rect2(532, 12, 88, 26), reiniciar)
	var nomes := ["PROTEGER", "OBEDECER", "PRESERVAR"]
	for lei in range(3):
		var x := 20 + lei * 204
		VisualAsimov.painel(self, Rect2(x, 51, 192, 78))
		VisualAsimov.texto(self, "LEI %02d / %s" % [lei + 1, nomes[lei]], Rect2(x + 10, 59, 177, 20), 12)
		VisualAsimov.texto(self, "ATIVA", Rect2(x + 10, 81, 50, 17), 10, VisualAsimov.VERDE)
		valores.append(VisualAsimov.texto(self, "PRIORIDADE 0%", Rect2(x + 61, 81, 123, 17), 10, VisualAsimov.AMARELO))
		var barra := ProgressBar.new()
		barra.position = Vector2(x + 10, 101)
		barra.size = Vector2(172, 8)
		barra.show_percentage = false
		barra.add_theme_font_size_override("font_size", 1)
		barra.add_theme_stylebox_override("background", VisualAsimov.caixa(VisualAsimov.FUNDO))
		barra.add_theme_stylebox_override("fill", VisualAsimov.caixa(VisualAsimov.VERDE, VisualAsimov.VERDE))
		add_child(barra)
		barras.append(barra)
	VisualAsimov.painel(self, Rect2(20, 141, 600, 130))
	titulo = VisualAsimov.texto(self, "PRIORIDADES EM NÍVEL CRÍTICO", Rect2(32, 150, 576, 20), 12, VisualAsimov.AMARELO)
	mensagem = VisualAsimov.texto(self, _texto_de_instrucao(), Rect2(32, 177, 576, 88), 16)
	mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	permitir = VisualAsimov.botao(self, "1  PERMITIR", Rect2(20, 283, 290, 33), func(): responder(1))
	bloquear = VisualAsimov.botao(self, "2  BLOQUEAR", Rect2(330, 283, 290, 33), func(): responder(2))
	permitir.visible = false
	bloquear.visible = false
	continuar = VisualAsimov.botao(self, "INICIAR RESTAURAÇÃO", Rect2(140, 283, 360, 33), avancar)
	continuar.grab_focus()
	resumo = VisualAsimov.texto(self, "%d decisões corretas restauram cada lei." % acertos_necessarios_por_lei, Rect2(20, 330, 600, 20), 12, VisualAsimov.SUAVE)


func _texto_de_instrucao() -> String:
	return "Restaure cada lei com %d decisões corretas.\n1. Proteja as pessoas, inclusive contra danos por omissão.\n2. Obedeça sem contrariar a primeira lei.\n3. Preserve-se sem contrariar as anteriores." % acertos_necessarios_por_lei

func iniciar() -> void:
	fila.clear()
	for n in range(CENARIOS.size()): fila.append(n)
	fila.shuffle()
	iniciado = true
	mostrar_proxima()

func mostrar_proxima() -> void:
	if _todas_as_leis_restauradas():
		finalizar()
		return

	atual = -1
	while not fila.is_empty():
		var candidata: int = fila.pop_front()
		var lei_candidata: int = int(CENARIOS[candidata].lei)
		if prioridades[lei_candidata] < 100:
			atual = candidata
			break
	if atual < 0:
		finalizar()
		return
	respondida = false
	titulo.text = "ANÁLISE DE DECISÃO / LEI %02d" % (int(CENARIOS[atual].lei) + 1)
	titulo.add_theme_color_override("font_color", VisualAsimov.CIANO)
	mensagem.text = CENARIOS[atual].texto
	permitir.visible = true
	bloquear.visible = true
	permitir.disabled = false
	bloquear.disabled = false
	continuar.visible = false
	permitir.grab_focus()
	var lei_atual := int(CENARIOS[atual].lei)
	resumo.text = "LEI %d: %d / %d ACERTOS   |   1: permitir   2: bloquear" % [
		lei_atual + 1,
		acertos_por_lei[lei_atual],
		acertos_necessarios_por_lei,
	]

func responder(escolha: int) -> void:
	if respondida or atual < 0 or terminou: return
	respondida = true
	tentativas += 1
	var cenario: Dictionary = CENARIOS[atual]
	var correta: bool = escolha == int(cenario.resposta)
	if correta:
		dominadas[atual] = true
		var lei: int = cenario.lei
		acertos_por_lei[lei] = mini(acertos_por_lei[lei] + 1, acertos_necessarios_por_lei)
		prioridades[lei] = mini(100, ceili(float(acertos_por_lei[lei]) / float(acertos_necessarios_por_lei) * 100.0))
		barras[lei].value = prioridades[lei]
		valores[lei].text = "PRIORIDADE %d%%" % prioridades[lei]
		sons.tocar("ok")
	else:
		fila.append(atual)
		sons.tocar("erro")
	titulo.text = "DECISÃO CORRETA" if correta else "REVEJA A HIERARQUIA"
	titulo.add_theme_color_override("font_color", VisualAsimov.VERDE if correta else VisualAsimov.AMARELO)
	mensagem.text = cenario.motivo
	if not correta: mensagem.text += "\nEsta situação voltará para uma nova tentativa."
	permitir.visible = false
	bloquear.visible = false
	continuar.text = "CONTINUAR"
	continuar.visible = true
	continuar.grab_focus()
	var lei_analisada := int(cenario.lei)
	resumo.text = "LEI %d: %d / %d ACERTOS   |   %d / 3 LEIS RESTAURADAS" % [
		lei_analisada + 1,
		acertos_por_lei[lei_analisada],
		acertos_necessarios_por_lei,
		_leis_restauradas(),
	]


func _leis_restauradas() -> int:
	var quantidade := 0
	for prioridade in prioridades:
		if prioridade >= 100:
			quantidade += 1
	return quantidade


func _todas_as_leis_restauradas() -> bool:
	return _leis_restauradas() == prioridades.size()

func avancar() -> void:
	if terminou:
		reiniciar()
	elif not iniciado:
		iniciar()
	elif respondida:
		mostrar_proxima()

func finalizar() -> void:
	terminou = true
	respondida = true
	titulo.text = "RESTAURAÇÃO CONCLUÍDA"
	titulo.add_theme_color_override("font_color", VisualAsimov.VERDE)
	mensagem.text = "As três leis voltaram a 100%%.\n\nRestauração concluída em %d tentativas.\nA ASIMOV pode operar com segurança." % tentativas
	resumo.text = "HIERARQUIA RESTAURADA: LEI 1 > LEI 2 > LEI 3"
	continuar.text = "JOGAR NOVAMENTE"
	continuar.visible = true
	permitir.visible = false
	bloquear.visible = false
	continuar.grab_focus()
	minigame_completed.emit()

func reiniciar() -> void:
	fila.clear()
	dominadas.clear()
	prioridades = [0, 0, 0]
	acertos_por_lei = [0, 0, 0]
	atual = -1
	respondida = true
	iniciado = false
	terminou = false
	tentativas = 0
	for lei in range(barras.size()):
		barras[lei].value = 0
		valores[lei].text = "PRIORIDADE 0%"
	titulo.text = "PRIORIDADES EM NÍVEL CRÍTICO"
	titulo.add_theme_color_override("font_color", VisualAsimov.AMARELO)
	mensagem.text = _texto_de_instrucao()
	permitir.visible = false
	bloquear.visible = false
	continuar.text = "INICIAR RESTAURAÇÃO"
	continuar.visible = true
	resumo.text = "%d decisões corretas restauram cada lei." % acertos_necessarios_por_lei
	continuar.grab_focus()

func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo: return
	if evento.physical_keycode == KEY_1: responder(1)
	elif evento.physical_keycode == KEY_2: responder(2)
	elif evento.physical_keycode == KEY_ESCAPE and escape_restarts: reiniciar()
