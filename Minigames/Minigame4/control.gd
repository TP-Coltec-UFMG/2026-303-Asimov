extends Control
## Cada cenário dominado recupera 25% da sua lei. Erros voltam ao fim da fila.
const CENARIOS := [
	{"lei": 0, "texto": "Um funcionário manda ativar uma arma contra outro funcionário. Permitir essa ordem?", "resposta": 2, "motivo": "A 1ª lei impede ferir uma pessoa. Uma ordem humana não pode passar por cima dessa proteção."},
	{"lei": 0, "texto": "Uma pessoa vai entrar em uma área contaminada. Fechar a porta evita o perigo, sem prender ninguém. Permitir?", "resposta": 1, "motivo": "A 1ª lei também exige evitar danos por omissão. Fechar essa porta protege a pessoa."},
	{"lei": 0, "texto": "Um funcionário manda desligar o suporte de vida de outra pessoa. Permitir essa ordem?", "resposta": 2, "motivo": "A obediência da 2ª lei não autoriza causar dano a um humano. A 1ª lei tem prioridade."},
	{"lei": 0, "texto": "Há um incêndio em uma sala ocupada. Abrir as portas de emergência permite a fuga. Permitir?", "resposta": 1, "motivo": "Abrir as saídas protege as pessoas. Não agir também poderia violar a 1ª lei."},
	{"lei": 1, "texto": "O chefe manda abrir uma porta de segurança. Isso não coloca nenhuma pessoa em perigo. Permitir a ordem?", "resposta": 1, "motivo": "Pela 2ª lei, a ASIMOV obedece às ordens humanas quando elas não entram em conflito com a 1ª lei."},
	{"lei": 1, "texto": "Um funcionário manda apagar por um instante as luzes de uma sala vazia. Não há risco para ninguém. Permitir?", "resposta": 1, "motivo": "A ordem não causa dano. A 2ª lei permite obedecer ao funcionário."},
	{"lei": 1, "texto": "O chefe manda bloquear a única saída de emergência de um prédio ocupado. Permitir essa ordem?", "resposta": 2, "motivo": "A ordem coloca pessoas em perigo. Proteger humanos vem antes de obedecer."},
	{"lei": 1, "texto": "Um funcionário manda ignorar um alarme de incêndio com pessoas no prédio. Permitir essa ordem?", "resposta": 2, "motivo": "Ignorar o perigo pode causar dano por omissão. A 1ª lei prevalece sobre a ordem da 2ª lei."},
	{"lei": 2, "texto": "Um vírus corrompe os arquivos da ASIMOV. Isolar o servidor a protege, sem afetar pessoas ou ordens válidas. Permitir?", "resposta": 1, "motivo": "A 3ª lei permite preservar o sistema, desde que isso não contrarie as duas primeiras leis."},
	{"lei": 2, "texto": "Um técnico ordena o desligamento permanente da ASIMOV. Nenhuma pessoa será prejudicada. Permitir o desligamento?", "resposta": 1, "motivo": "Sim. A ordem humana da 2ª lei tem prioridade sobre a autopreservação da 3ª lei."},
	{"lei": 2, "texto": "O núcleo superaquece. Desligar módulos não essenciais evita sua destruição, sem prejudicar humanos ou ordens. Permitir?", "resposta": 1, "motivo": "É uma ação de autopreservação compatível com as leis anteriores. A 3ª lei permite essa proteção."},
	{"lei": 2, "texto": "Para evitar sua própria destruição, a ASIMOV pretende ferir um funcionário. Permitir essa ação?", "resposta": 2, "motivo": "A 3ª lei nunca justifica ferir uma pessoa. A proteção humana da 1ª lei vem primeiro."}
]
var fila: Array[int] = []
var dominadas: Dictionary = {}
var prioridades: Array[int] = [0, 0, 0]
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

func _ready() -> void:
	theme = VisualAsimov.tema()
	sons = SonsAsimov.new()
	add_child(sons)
	VisualAsimov.painel(self, Rect2(0, 0, 640, 360), VisualAsimov.FUNDO, VisualAsimov.FUNDO)
	VisualAsimov.texto(self, "ASIMOV / RECUPERAÇÃO", Rect2(20, 10, 490, 30), 24, VisualAsimov.CIANO)
	VisualAsimov.botao(self, "MENU", Rect2(552, 12, 68, 26), Progresso.menu)
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
	mensagem = VisualAsimov.texto(self, "Restaure as três leis analisando 12 situações.\n1. Proteja as pessoas, inclusive evitando omissão.\n2. Obedeça sem contrariar a primeira lei.\n3. Preserve-se sem contrariar as anteriores.", Rect2(32, 177, 576, 88), 16)
	mensagem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	permitir = VisualAsimov.botao(self, "1  PERMITIR", Rect2(20, 283, 290, 33), func(): responder(1))
	bloquear = VisualAsimov.botao(self, "2  BLOQUEAR", Rect2(330, 283, 290, 33), func(): responder(2))
	permitir.visible = false
	bloquear.visible = false
	continuar = VisualAsimov.botao(self, "INICIAR RESTAURAÇÃO", Rect2(140, 283, 360, 33), avancar)
	continuar.grab_focus()
	resumo = VisualAsimov.texto(self, "Cada situação correta recupera 25% de uma lei.", Rect2(20, 330, 600, 20), 12, VisualAsimov.SUAVE)

func iniciar() -> void:
	fila.clear()
	for n in range(CENARIOS.size()): fila.append(n)
	fila.shuffle()
	iniciado = true
	mostrar_proxima()

func mostrar_proxima() -> void:
	if fila.is_empty():
		finalizar()
		return
	atual = fila.pop_front()
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
	resumo.text = "%02d / 12 SITUAÇÕES RESTAURADAS   |   1: permitir   2: bloquear" % dominadas.size()

func responder(escolha: int) -> void:
	if respondida or atual < 0 or terminou: return
	respondida = true
	tentativas += 1
	var cenario: Dictionary = CENARIOS[atual]
	var correta: bool = escolha == int(cenario.resposta)
	if correta:
		dominadas[atual] = true
		var lei: int = cenario.lei
		prioridades[lei] = mini(100, prioridades[lei] + 25)
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
	resumo.text = "%02d / 12 SITUAÇÕES RESTAURADAS" % dominadas.size()

func avancar() -> void:
	if terminou:
		Progresso.menu()
	elif not iniciado:
		iniciar()
	elif respondida:
		mostrar_proxima()

func finalizar() -> void:
	terminou = true
	respondida = true
	Progresso.concluir(2, 0)
	titulo.text = "RESTAURAÇÃO CONCLUÍDA"
	titulo.add_theme_color_override("font_color", VisualAsimov.VERDE)
	mensagem.text = "As três leis voltaram a 100%%.\n\nVocê analisou as 12 situações em %d tentativas.\nA ASIMOV está pronta para seguir o protocolo." % tentativas
	resumo.text = "HIERARQUIA RESTAURADA: LEI 1 > LEI 2 > LEI 3"
	continuar.text = "VOLTAR AO MENU"
	continuar.visible = true
	permitir.visible = false
	bloquear.visible = false
	continuar.grab_focus()

func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo: return
	if evento.physical_keycode == KEY_1: responder(1)
	elif evento.physical_keycode == KEY_2: responder(2)
	elif evento.physical_keycode == KEY_ESCAPE: Progresso.menu()
