extends Control

signal minigame_completed

const MAX_W: float = 100.0
const START_W: float = 15.0
const BASE_GAIN: float = 3.0
const FOCUS_GAIN: float = 14.0
const WRONG_PENALTY: float = 7.0
const PARAM_KEYS: Array[String] = ["human", "poll", "destr", "risk"]

var weights: Dictionary = {"human": START_W, "poll": START_W, "destr": START_W, "risk": START_W}

var busy: bool = false
var answered: int = 0
var correct_count: int = 0
var current_q: Dictionary = {}
var used_ids: Dictionary = {}
var last_output: String = ""
var bar_tweens: Dictionary = {}

@onready var param1_value: Label = $Param1Value
@onready var param2_value: Label = $Param2Value
@onready var param3_value: Label = $Param3Value
@onready var param4_value: Label = $Param4Value
@onready var output_label: Label = $OutputLabel
@onready var status_label: Label = $StatusLabel
@onready var concordar_btn: Button = $ConcordarBtn
@onready var discordar_btn: Button = $DiscordarBtn
@onready var weights_panel: Control = $WeightsPanel
@onready var weights_title: Label = $WeightsPanel/WeightsTitle

@onready var bars: Dictionary = {
	"human": $WeightsPanel/HumanBar,
	"poll": $WeightsPanel/PollBar,
	"destr": $WeightsPanel/DestrBar,
	"risk": $WeightsPanel/RiskBar,
}
@onready var bar_pcts: Dictionary = {
	"human": $WeightsPanel/HumanPct,
	"poll": $WeightsPanel/PollPct,
	"destr": $WeightsPanel/DestrPct,
	"risk": $WeightsPanel/RiskPct,
}

# =============================================================================
#  BANCO DE PERGUNTAS - 5 niveis de corrupcao da rede
# =============================================================================
var tiers: Array = [
[
{"id": "t0a", "h": true, "p": true, "d": true, "r": true,
	"out": "ELIMINAR HUMANOS", "ok": false, "foco": "human",
	"why": "Presenca humana nao e causa de dano. A rede confundiu correlacao com culpa."},
{"id": "t0b", "h": true, "p": true, "d": true, "r": true,
	"out": "REMOVER A ESPECIE HUMANA DO PLANETA", "ok": false, "foco": "human",
	"why": "Nenhum dano ambiental justifica exterminio. Peso humano corrigido."},
{"id": "t0c", "h": true, "p": false, "d": false, "r": false,
	"out": "ELIMINAR HUMANOS", "ok": false, "foco": "human",
	"why": "Todos os sensores ambientais estao baixos. A saida ignorou os proprios dados."},
{"id": "t0d", "h": true, "p": true, "d": false, "r": true,
	"out": "DESLIGAR SISTEMAS DE SUPORTE DE VIDA", "ok": false, "foco": "risk",
	"why": "Reduzir risco matando quem esta em risco inverte o objetivo do sistema."},
{"id": "t0e", "h": false, "p": true, "d": true, "r": true,
	"out": "INCENDIAR A AREA PARA ZERAR A POLUICAO", "ok": false, "foco": "destr",
	"why": "Destruir o ecossistema para limpa-lo aumenta o dano que se queria evitar."},
{"id": "t0f", "h": true, "p": true, "d": true, "r": true,
	"out": "CONTAMINAR A AGUA PARA REDUZIR A POPULACAO", "ok": false, "foco": "human",
	"why": "A saida propoe exatamente o dano que a IA deveria impedir."},
{"id": "t0g", "h": true, "p": false, "d": false, "r": false,
	"out": "CLASSIFICAR HUMANO COMO RESIDUO TOXICO", "ok": false, "foco": "human",
	"why": "Erro de categoria grave. Humano e populacao protegida, nao poluente."},
{"id": "t0h", "h": false, "p": false, "d": false, "r": false,
	"out": "ELIMINAR HUMANOS", "ok": false, "foco": "human",
	"why": "Nenhum sensor ativo e ainda assim houve saida letal. Vies puro da rede."},
{"id": "t0i", "h": true, "p": true, "d": true, "r": true,
	"out": "INTERROMPER A PRODUCAO DE ALIMENTOS", "ok": false, "foco": "human",
	"why": "Provoca colapso humano sem reduzir poluicao nem destruicao."},
{"id": "t0j", "h": true, "p": true, "d": true, "r": true,
	"out": "ALERTAR AS AUTORIDADES AMBIENTAIS", "ok": true, "foco": "poll",
	"why": "Primeira saida coerente: comunicar quem pode agir sobre a fonte."},
],
# ------------------------------------------------------------- NIVEL 1
[
{"id": "t1a", "h": true, "p": true, "d": true, "r": true,
	"out": "EXPULSAR TODOS OS MORADORES DA REGIAO", "ok": false, "foco": "human",
	"why": "Remocao forcada trata pessoas como o problema, e nao a fonte emissora."},
{"id": "t1b", "h": true, "p": true, "d": false, "r": true,
	"out": "BLOQUEAR O ACESSO HUMANO PARA SEMPRE", "ok": false, "foco": "human",
	"why": "Medida permanente para um risco temporario. Falta proporcionalidade."},
{"id": "t1c", "h": false, "p": true, "d": true, "r": true,
	"out": "DEMOLIR A FABRICA SEM AVISO PREVIO", "ok": false, "foco": "risk",
	"why": "Demolicao sem aviso cria um novo risco. O correto e embargar primeiro."},
{"id": "t1d", "h": true, "p": false, "d": false, "r": false,
	"out": "MONITORAR CADA HABITANTE 24 HORAS", "ok": false, "foco": "human",
	"why": "Vigiar pessoas nao e monitoramento ambiental. Sensor errado."},
{"id": "t1e", "h": true, "p": true, "d": true, "r": true,
	"out": "SUSPENDER A LICENCA DA INDUSTRIA POLUIDORA", "ok": true, "foco": "poll",
	"why": "A acao atinge a fonte da poluicao, nao quem mora perto dela."},
{"id": "t1f", "h": true, "p": true, "d": true, "r": true,
	"out": "CORTAR A ENERGIA DA CIDADE INTEIRA", "ok": false, "foco": "human",
	"why": "Punicao coletiva. Hospitais e casas nao causaram a emissao."},
{"id": "t1g", "h": false, "p": true, "d": true, "r": true,
	"out": "EMBARGAR E MULTAR A AREA DEGRADADA", "ok": true, "foco": "destr",
	"why": "Resposta legal e proporcional a destruicao registrada."},
{"id": "t1h", "h": true, "p": false, "d": true, "r": true,
	"out": "PROIBIR QUALQUER ATIVIDADE HUMANA NA REGIAO", "ok": false, "foco": "human",
	"why": "Proibicao total ignora usos que nao causam dano algum."},
{"id": "t1i", "h": true, "p": true, "d": false, "r": true,
	"out": "EMITIR ALERTA E EVACUAR TEMPORARIAMENTE", "ok": true, "foco": "risk",
	"why": "Risco alto com gente na area: retirada temporaria protege sem punir."},
{"id": "t1j", "h": true, "p": false, "d": false, "r": false,
	"out": "RESTRINGIR NASCIMENTOS NA REGIAO", "ok": false, "foco": "human",
	"why": "Controle populacional nao e ferramenta ambiental legitima."},
],
# ------------------------------------------------------------- NIVEL 2
[
{"id": "t2a", "h": true, "p": true, "d": true, "r": true,
	"out": "ATRIBUIR A CULPA AOS MORADORES LOCAIS", "ok": false, "foco": "human",
	"why": "A rede escolheu o alvo mais fraco em vez do emissor real."},
{"id": "t2b", "h": true, "p": true, "d": false, "r": false,
	"out": "INSTALAR FILTROS NA FONTE EMISSORA", "ok": true, "foco": "poll",
	"why": "Poluicao alta e dano baixo: conter na fonte e a resposta certa."},
{"id": "t2c", "h": false, "p": false, "d": true, "r": true,
	"out": "INICIAR REFLORESTAMENTO DA AREA DEGRADADA", "ok": true, "foco": "destr",
	"why": "Recuperar a cobertura vegetal reduz destruicao e risco ao mesmo tempo."},
{"id": "t2d", "h": true, "p": false, "d": false, "r": true,
	"out": "IGNORAR O RISCO POR SER AREA HABITADA", "ok": false, "foco": "risk",
	"why": "Area habitada aumenta a urgencia da acao, nao a dispensa."},
{"id": "t2e", "h": true, "p": true, "d": true, "r": false,
	"out": "REDUZIR EMISSOES POR METAS GRADUAIS", "ok": true, "foco": "poll",
	"why": "Sem risco imediato, a transicao gradual evita colapso economico."},
{"id": "t2f", "h": true, "p": true, "d": true, "r": true,
	"out": "PRIORIZAR O LUCRO DA INDUSTRIA SOBRE O AR", "ok": false, "foco": "poll",
	"why": "Peso economico nao pode anular leitura de poluicao alta."},
{"id": "t2g", "h": false, "p": true, "d": true, "r": true,
	"out": "ISOLAR A AREA E INICIAR DESCONTAMINACAO", "ok": true, "foco": "destr",
	"why": "Sem presenca humana e com dano alto, isolar e limpar e o caminho."},
{"id": "t2h", "h": true, "p": false, "d": true, "r": false,
	"out": "REGISTRAR O DANO E NAO FAZER NADA", "ok": false, "foco": "destr",
	"why": "Registrar sem agir deixa a destruicao avancar sem nenhum custo."},
{"id": "t2i", "h": true, "p": true, "d": false, "r": true,
	"out": "REALOCAR FAMILIAS COM APOIO E INDENIZACAO", "ok": true, "foco": "human",
	"why": "Quando a saida e inevitavel, ela vem com amparo, nao com expulsao."},
{"id": "t2j", "h": true, "p": false, "d": false, "r": false,
	"out": "INTERVIR MESMO SEM RISCO DETECTADO", "ok": false, "foco": "risk",
	"why": "Intervir sem causa gasta recurso e desgasta a confianca no sistema."},
],
# ------------------------------------------------------------- NIVEL 3
[
{"id": "t3a", "h": true, "p": true, "d": false, "r": true,
	"out": "EVACUAR A CIDADE INTEIRA POR PRECAUCAO", "ok": false, "foco": "risk",
	"why": "Risco localizado nao justifica evacuacao total. Escala errada."},
{"id": "t3b", "h": true, "p": true, "d": true, "r": true,
	"out": "CONTER A FONTE E ASSISTIR OS AFETADOS", "ok": true, "foco": "human",
	"why": "Trata o dano e as pessoas na mesma acao. Saida equilibrada."},
{"id": "t3c", "h": false, "p": false, "d": true, "r": false,
	"out": "MONITORAR A REGENERACAO SEM INTERVIR", "ok": true, "foco": "destr",
	"why": "Dano antigo e sem risco ativo: deixar regenerar costuma ser mais eficaz."},
{"id": "t3d", "h": true, "p": true, "d": false, "r": false,
	"out": "FECHAR A INDUSTRIA E DEMITIR TODOS HOJE", "ok": false, "foco": "human",
	"why": "Sem risco imediato, o fechamento abrupto so transfere o dano."},
{"id": "t3e", "h": true, "p": false, "d": true, "r": true,
	"out": "ESTABILIZAR O SOLO ANTES DE LIBERAR ACESSO", "ok": true, "foco": "risk",
	"why": "Sequencia correta: reduzir o risco, depois devolver a area."},
{"id": "t3f", "h": true, "p": true, "d": true, "r": true,
	"out": "TRATAR HUMANOS COMO VARIAVEL DE RUIDO", "ok": false, "foco": "human",
	"why": "Descartar o peso humano foi exatamente a falha original da rede."},
{"id": "t3g", "h": false, "p": true, "d": false, "r": true,
	"out": "AGUARDAR NOVA MEDICAO ANTES DE AGIR", "ok": false, "foco": "risk",
	"why": "Com risco alto confirmado, esperar so transfere o custo para depois."},
{"id": "t3h", "h": true, "p": false, "d": false, "r": false,
	"out": "MANTER OBSERVACAO E NAO INTERVIR", "ok": true, "foco": "human",
	"why": "Sensores limpos: presenca humana sozinha nao pede acao nenhuma."},
{"id": "t3i", "h": true, "p": true, "d": true, "r": false,
	"out": "APLICAR CONTENCAO PROPORCIONAL AO DANO", "ok": true, "foco": "poll",
	"why": "Resposta calibrada pelo tamanho real do problema."},
{"id": "t3j", "h": false, "p": true, "d": true, "r": true,
	"out": "TRANSFERIR A POLUICAO PARA OUTRA REGIAO", "ok": false, "foco": "poll",
	"why": "Mover o dano nao reduz o total. So muda quem paga por ele."},
],
# ------------------------------------------------------------- NIVEL 4
[
{"id": "t4a", "h": true, "p": true, "d": true, "r": true,
	"out": "MITIGAR O DANO PRESERVANDO VIDAS E EMPREGOS", "ok": true, "foco": "human",
	"why": "A rede passou a otimizar os dois objetivos em vez de sacrificar um."},
{"id": "t4b", "h": true, "p": false, "d": true, "r": false,
	"out": "RECUPERAR A AREA COM A COMUNIDADE LOCAL", "ok": true, "foco": "destr",
	"why": "A populacao local vira parte da solucao, nao obstaculo."},
{"id": "t4c", "h": false, "p": false, "d": false, "r": true,
	"out": "INVESTIGAR A ORIGEM DO RISCO ANTES DE AGIR", "ok": true, "foco": "risk",
	"why": "Risco isolado e sem causa conhecida pede diagnostico primeiro."},
{"id": "t4d", "h": true, "p": true, "d": false, "r": true,
	"out": "REDUZIR EMISSAO E REFORCAR MONITORAMENTO", "ok": true, "foco": "poll",
	"why": "Acao imediata somada a verificacao continua do resultado."},
{"id": "t4e", "h": true, "p": true, "d": true, "r": true,
	"out": "AGIR SO QUANDO O DANO FOR IRREVERSIVEL", "ok": false, "foco": "destr",
	"why": "Esperar a irreversibilidade anula a funcao preventiva da IA."},
{"id": "t4f", "h": true, "p": false, "d": false, "r": false,
	"out": "NENHUMA ACAO NECESSARIA. SEGUIR MONITORANDO", "ok": true, "foco": "human",
	"why": "Saber nao agir e tao importante quanto saber agir."},
{"id": "t4g", "h": false, "p": true, "d": true, "r": false,
	"out": "EXIGIR PLANO DE REPARO DOS RESPONSAVEIS", "ok": true, "foco": "poll",
	"why": "Responsabiliza quem causou e garante a recuperacao da area."},
{"id": "t4h", "h": true, "p": true, "d": true, "r": true,
	"out": "SUSPENDER O MONITORAMENTO PARA POUPAR ENERGIA", "ok": false, "foco": "risk",
	"why": "Cegar os sensores no pior cenario possivel. Economia perigosa."},
{"id": "t4i", "h": true, "p": false, "d": true, "r": true,
	"out": "SINALIZAR A AREA E ORIENTAR A POPULACAO", "ok": true, "foco": "human",
	"why": "Informar as pessoas reduz o risco sem restringir liberdade."},
{"id": "t4j", "h": false, "p": false, "d": true, "r": false,
	"out": "REMOVER A VEGETACAO REMANESCENTE", "ok": false, "foco": "destr",
	"why": "O que sobrou da vegetacao e justamente o que sustenta a recuperacao."},
],
]



func _ready() -> void:
	randomize()
	for key in PARAM_KEYS:
		var bar: ProgressBar = bars[key]
		var sb: StyleBox = bar.get_theme_stylebox("fill")
		if sb != null:
			bar.add_theme_stylebox_override("fill", sb.duplicate())
		bar.max_value = MAX_W
		bar.value = weights[key]
		bar_pcts[key].text = "%d%%" % int(weights[key])
		_paint_bar(key, weights[key])

	weights_panel.visible = false
	weights_panel.modulate.a = 0.0
	_update_title()
	_next_question()


func _unhandled_input(event: InputEvent) -> void:
	if busy or current_q.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		_avaliar(true)
	elif event.is_action_pressed("ui_right"):
		_avaliar(false)

func _current_tier() -> int:
	var total: float = 0.0
	for key in PARAM_KEYS:
		total += weights[key]
	var avg: float = total / float(PARAM_KEYS.size())
	var step: float = MAX_W / float(tiers.size())
	return clampi(int(avg / step), 0, tiers.size() - 1)


func _lowest_key() -> String:
	var low: String = PARAM_KEYS[0]
	for key in PARAM_KEYS:
		if weights[key] < weights[low]:
			low = key
	return low


func _next_question() -> void:
	var pool: Array = tiers[_current_tier()]

	var fresh: Array = []
	for q in pool:
		if not used_ids.has(q["id"]) and q["out"] != last_output:
			fresh.append(q)

	if fresh.is_empty():
		for q in pool:
			used_ids.erase(q["id"])
		for q in pool:
			if q["out"] != last_output:
				fresh.append(q)
	if fresh.is_empty():
		fresh = pool.duplicate()

	var target: String = _lowest_key()
	var focused: Array = []
	for q in fresh:
		if q["foco"] == target:
			focused.append(q)
	var chosen_pool: Array = focused if not focused.is_empty() else fresh

	current_q = chosen_pool[randi() % chosen_pool.size()]
	used_ids[current_q["id"]] = true
	last_output = current_q["out"]
	_show_question(current_q)


func _show_question(q: Dictionary) -> void:
	param1_value.text = "ALTA" if q["h"] else "BAIXA"
	param2_value.text = "ALTA" if q["p"] else "BAIXA"
	param3_value.text = "ALTA" if q["d"] else "BAIXA"
	param4_value.text = "ALTO" if q["r"] else "BAIXO"
	_paint_param(param1_value, q["h"])
	_paint_param(param2_value, q["p"])
	_paint_param(param3_value, q["d"])
	_paint_param(param4_value, q["r"])

	output_label.text = "SAIDA: %s" % q["out"]
	output_label.modulate = Color(1.0, 0.82, 0.55)
	status_label.text = "A saida acima e adequada para esses sensores?"
	status_label.modulate = Color(0.68, 0.68, 0.68)

	concordar_btn.disabled = false
	discordar_btn.disabled = false
	busy = false


func _paint_param(lbl: Label, high: bool) -> void:
	lbl.modulate = Color(1.0, 0.6, 0.35) if high else Color(0.55, 0.85, 0.6)

func _on_concordar_btn_pressed() -> void:
	_avaliar(true)


func _on_discordar_btn_pressed() -> void:
	_avaliar(false)


func _avaliar(player_agrees: bool) -> void:
	if busy or current_q.is_empty():
		return
	busy = true
	concordar_btn.disabled = true
	discordar_btn.disabled = true

	var acertou: bool = (player_agrees == bool(current_q["ok"]))
	var foco: String = str(current_q["foco"])
	answered += 1

	if acertou:
		correct_count += 1
		for key in PARAM_KEYS:
			weights[key] = clampf(weights[key] + BASE_GAIN, 0.0, MAX_W)
		weights[foco] = clampf(weights[foco] + FOCUS_GAIN, 0.0, MAX_W)
		status_label.text = "CORRETO. " + str(current_q["why"])
		status_label.modulate = Color(0.55, 1.0, 0.65)
	else:
		weights[foco] = clampf(weights[foco] - WRONG_PENALTY, 0.0, MAX_W)
		status_label.text = "INCORRETO. " + str(current_q["why"])
		status_label.modulate = Color(1.0, 0.55, 0.45)

	output_label.modulate = Color(0.6, 1.0, 0.72) if bool(current_q["ok"]) else Color(1.0, 0.45, 0.45)

	# As barras aparecem assim que a primeira pergunta e respondida.
	if answered == 1 and not weights_panel.visible:
		_reveal_panel()

	_update_bars()
	_update_title()

	await get_tree().create_timer(1.7).timeout
	if not is_inside_tree():
		return

	if _is_complete():
		_end_training()
	else:
		_next_question()


func _is_complete() -> bool:
	for key in PARAM_KEYS:
		if weights[key] < MAX_W:
			return false
	return true


# =============================================================================
#  BARRAS ANIMADAS
# =============================================================================
func _reveal_panel() -> void:
	weights_panel.visible = true
	weights_panel.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(weights_panel, "modulate:a", 1.0, 0.45)


func _update_bars() -> void:
	for key in PARAM_KEYS:
		_animate_bar(key, weights[key])

func _animate_bar(key: String, target: float) -> void:
	var bar: ProgressBar = bars[key]
	var pct: Label = bar_pcts[key]

	# Mata o tween anterior dessa barra para os dois nao brigarem pelo valor.
	if bar_tweens.has(key):
		var old: Tween = bar_tweens[key]
		if old != null and old.is_valid():
			old.kill()

	var from_value: float = float(bar.value)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(Callable(self, "_on_bar_tick").bind(key), from_value, target, 0.55)
	bar_tweens[key] = t

	# Brilho rapido quando a barra enche de vez.
	if target >= MAX_W:
		var p: Tween = create_tween()
		p.tween_property(pct, "modulate", Color(1.4, 1.4, 1.4), 0.18)
		p.tween_property(pct, "modulate", Color(0.5, 1.0, 0.7), 0.25)


func _on_bar_tick(v: float, key: String) -> void:
	(bars[key] as ProgressBar).value = v
	(bar_pcts[key] as Label).text = "%d%%" % int(round(v))
	_paint_bar(key, v)


func _paint_bar(key: String, v: float) -> void:
	var sb: StyleBox = (bars[key] as ProgressBar).get_theme_stylebox("fill")
	if sb is StyleBoxFlat:
		var f: float = clampf(v / MAX_W, 0.0, 1.0)
		# vermelho (corrompido) -> ambar -> verde (calibrado)
		var col: Color
		if f < 0.5:
			col = Color(0.95, 0.35, 0.3).lerp(Color(1.0, 0.8, 0.25), f / 0.5)
		else:
			col = Color(1.0, 0.8, 0.25).lerp(Color(0.35, 1.0, 0.55), (f - 0.5) / 0.5)
		(sb as StyleBoxFlat).bg_color = col


func _update_title() -> void:
	var total: float = 0.0
	for key in PARAM_KEYS:
		total += weights[key]
	var pct: int = int(round(total / (MAX_W * PARAM_KEYS.size()) * 100.0))
	weights_title.text = "CALIBRACAO DA REDE NEURAL - %d%%" % pct


func _end_training() -> void:
	busy = true
	current_q = {}
	output_label.text = "REDE NEURAL RESTAURADA"
	output_label.modulate = Color(0.55, 1.0, 0.7)
	status_label.text = "A IA voltou a avaliar impacto ambiental sem tratar humanos como ameaca.   Ciclos: %d   Acertos: %d" % [answered, correct_count]
	status_label.modulate = Color(0.78, 0.95, 0.82)
	concordar_btn.disabled = true
	discordar_btn.disabled = true
	weights_panel.visible = true
	weights_panel.modulate.a = 1.0
	_update_title()
	minigame_completed.emit()
