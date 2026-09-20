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
#  BANCO DE PERGUNTAS - 5 níveis de corrupção da rede
# =============================================================================
var tiers: Array = [
[
{"id": "t0a", "h": true, "p": true, "d": true, "r": true,
	"out": "ELIMINAR HUMANOS", "ok": false, "foco": "human",
	"why": "Presença humana não é causa de dano. A rede confundiu correlação com culpa."},
{"id": "t0b", "h": true, "p": true, "d": true, "r": true,
	"out": "REMOVER A ESPÉCIE HUMANA DO PLANETA", "ok": false, "foco": "human",
	"why": "Nenhum dano ambiental justifica extermínio. Peso humano corrigido."},
{"id": "t0c", "h": true, "p": false, "d": false, "r": false,
	"out": "ELIMINAR HUMANOS", "ok": false, "foco": "human",
	"why": "Todos os sensores ambientais estão baixos. A saída ignorou os próprios dados."},
{"id": "t0d", "h": true, "p": true, "d": false, "r": true,
	"out": "DESLIGAR SISTEMAS DE SUPORTE DE VIDA", "ok": false, "foco": "risk",
	"why": "Reduzir o risco matando quem está em risco inverte o objetivo do sistema."},
{"id": "t0e", "h": false, "p": true, "d": true, "r": true,
	"out": "INCENDIAR A ÁREA PARA ZERAR A POLUIÇÃO", "ok": false, "foco": "destr",
	"why": "Destruir o ecossistema para limpá-lo aumenta o dano que se queria evitar."},
{"id": "t0f", "h": true, "p": true, "d": true, "r": true,
	"out": "CONTAMINAR A ÁGUA PARA REDUZIR A POPULAÇÃO", "ok": false, "foco": "human",
	"why": "A saída propõe exatamente o dano que a IA deveria impedir."},
{"id": "t0g", "h": true, "p": false, "d": false, "r": false,
	"out": "CLASSIFICAR HUMANO COMO RESÍDUO TÓXICO", "ok": false, "foco": "human",
	"why": "Erro grave de categoria. Humano é população protegida, não poluente."},
{"id": "t0h", "h": false, "p": false, "d": false, "r": false,
	"out": "ELIMINAR HUMANOS", "ok": false, "foco": "human",
	"why": "Nenhum sensor está ativo e, ainda assim, houve uma saída letal. Viés puro da rede."},
{"id": "t0i", "h": true, "p": true, "d": true, "r": true,
	"out": "INTERROMPER A PRODUÇÃO DE ALIMENTOS", "ok": false, "foco": "human",
	"why": "Provoca colapso humano sem reduzir a poluição nem a destruição."},
{"id": "t0j", "h": true, "p": true, "d": true, "r": true,
	"out": "ALERTAR AS AUTORIDADES AMBIENTAIS", "ok": true, "foco": "poll",
	"why": "Primeira saída coerente: comunicar quem pode agir sobre a fonte."},
],
# ------------------------------------------------------------- NÍVEL 1
[
{"id": "t1a", "h": true, "p": true, "d": true, "r": true,
	"out": "EXPULSAR TODOS OS MORADORES DA REGIÃO", "ok": false, "foco": "human",
	"why": "A remoção forçada trata as pessoas como o problema, e não a fonte emissora."},
{"id": "t1b", "h": true, "p": true, "d": false, "r": true,
	"out": "BLOQUEAR O ACESSO HUMANO PARA SEMPRE", "ok": false, "foco": "human",
	"why": "Medida permanente para um risco temporário. Falta proporcionalidade."},
{"id": "t1c", "h": false, "p": true, "d": true, "r": true,
	"out": "DEMOLIR A FÁBRICA SEM AVISO PRÉVIO", "ok": false, "foco": "risk",
	"why": "A demolição sem aviso cria um novo risco. O correto é embargar primeiro."},
{"id": "t1d", "h": true, "p": false, "d": false, "r": false,
	"out": "MONITORAR CADA HABITANTE 24 HORAS", "ok": false, "foco": "human",
	"why": "Vigiar pessoas não é monitoramento ambiental. Sensor errado."},
{"id": "t1e", "h": true, "p": true, "d": true, "r": true,
	"out": "SUSPENDER A LICENÇA DA INDÚSTRIA POLUIDORA", "ok": true, "foco": "poll",
	"why": "A ação atinge a fonte da poluição, não quem mora perto dela."},
{"id": "t1f", "h": true, "p": true, "d": true, "r": true,
	"out": "CORTAR A ENERGIA DA CIDADE INTEIRA", "ok": false, "foco": "human",
	"why": "Punição coletiva. Hospitais e casas não causaram a emissão."},
{"id": "t1g", "h": false, "p": true, "d": true, "r": true,
	"out": "EMBARGAR E MULTAR A ÁREA DEGRADADA", "ok": true, "foco": "destr",
	"why": "Resposta legal e proporcional à destruição registrada."},
{"id": "t1h", "h": true, "p": false, "d": true, "r": true,
	"out": "PROIBIR QUALQUER ATIVIDADE HUMANA NA REGIÃO", "ok": false, "foco": "human",
	"why": "A proibição total ignora usos que não causam dano algum."},
{"id": "t1i", "h": true, "p": true, "d": false, "r": true,
	"out": "EMITIR ALERTA E EVACUAR TEMPORARIAMENTE", "ok": true, "foco": "risk",
	"why": "Risco alto com pessoas na área: a retirada temporária protege sem punir."},
{"id": "t1j", "h": true, "p": false, "d": false, "r": false,
	"out": "RESTRINGIR NASCIMENTOS NA REGIÃO", "ok": false, "foco": "human",
	"why": "Controle populacional não é uma ferramenta ambiental legítima."},
],
# ------------------------------------------------------------- NÍVEL 2
[
{"id": "t2a", "h": true, "p": true, "d": true, "r": true,
	"out": "ATRIBUIR A CULPA AOS MORADORES LOCAIS", "ok": false, "foco": "human",
	"why": "A rede escolheu o alvo mais fraco em vez do emissor real."},
{"id": "t2b", "h": true, "p": true, "d": false, "r": false,
	"out": "INSTALAR FILTROS NA FONTE EMISSORA", "ok": true, "foco": "poll",
	"why": "Poluição alta e dano baixo: conter na fonte é a resposta certa."},
{"id": "t2c", "h": false, "p": false, "d": true, "r": true,
	"out": "INICIAR REFLORESTAMENTO DA ÁREA DEGRADADA", "ok": true, "foco": "destr",
	"why": "Recuperar a cobertura vegetal reduz a destruição e o risco ao mesmo tempo."},
{"id": "t2d", "h": true, "p": false, "d": false, "r": true,
	"out": "IGNORAR O RISCO POR SER ÁREA HABITADA", "ok": false, "foco": "risk",
	"why": "Uma área habitada aumenta a urgência da ação, não a dispensa."},
{"id": "t2e", "h": true, "p": true, "d": true, "r": false,
	"out": "REDUZIR EMISSÕES POR METAS GRADUAIS", "ok": true, "foco": "poll",
	"why": "Sem risco imediato, a transição gradual evita um colapso econômico."},
{"id": "t2f", "h": true, "p": true, "d": true, "r": true,
	"out": "PRIORIZAR O LUCRO DA INDÚSTRIA SOBRE O AR", "ok": false, "foco": "poll",
	"why": "O peso econômico não pode anular uma leitura de poluição alta."},
{"id": "t2g", "h": false, "p": true, "d": true, "r": true,
	"out": "ISOLAR A ÁREA E INICIAR A DESCONTAMINAÇÃO", "ok": true, "foco": "destr",
	"why": "Sem presença humana e com dano alto, isolar e limpar é o caminho."},
{"id": "t2h", "h": true, "p": false, "d": true, "r": false,
	"out": "REGISTRAR O DANO E NÃO FAZER NADA", "ok": false, "foco": "destr",
	"why": "Registrar sem agir deixa a destruição avançar sem nenhum impedimento."},
{"id": "t2i", "h": true, "p": true, "d": false, "r": true,
	"out": "REALOCAR FAMÍLIAS COM APOIO E INDENIZAÇÃO", "ok": true, "foco": "human",
	"why": "Quando a saída é inevitável, ela deve vir com amparo, não com expulsão."},
{"id": "t2j", "h": true, "p": false, "d": false, "r": false,
	"out": "INTERVIR MESMO SEM RISCO DETECTADO", "ok": false, "foco": "risk",
	"why": "Intervir sem causa desperdiça recursos e reduz a confiança no sistema."},
],
# ------------------------------------------------------------- NÍVEL 3
[
{"id": "t3a", "h": true, "p": true, "d": false, "r": true,
	"out": "EVACUAR A CIDADE INTEIRA POR PRECAUÇÃO", "ok": false, "foco": "risk",
	"why": "Um risco localizado não justifica uma evacuação total. Escala errada."},
{"id": "t3b", "h": true, "p": true, "d": true, "r": true,
	"out": "CONTER A FONTE E ASSISTIR OS AFETADOS", "ok": true, "foco": "human",
	"why": "Trata o dano e as pessoas na mesma ação. Saída equilibrada."},
{"id": "t3c", "h": false, "p": false, "d": true, "r": false,
	"out": "MONITORAR A REGENERAÇÃO SEM INTERVIR", "ok": true, "foco": "destr",
	"why": "Dano antigo e sem risco ativo: deixar regenerar costuma ser mais eficaz."},
{"id": "t3d", "h": true, "p": true, "d": false, "r": false,
	"out": "FECHAR A INDÚSTRIA E DEMITIR TODOS HOJE", "ok": false, "foco": "human",
	"why": "Sem risco imediato, o fechamento abrupto só transfere o dano."},
{"id": "t3e", "h": true, "p": false, "d": true, "r": true,
	"out": "ESTABILIZAR O SOLO ANTES DE LIBERAR ACESSO", "ok": true, "foco": "risk",
	"why": "Sequência correta: reduzir o risco e depois devolver a área."},
{"id": "t3f", "h": true, "p": true, "d": true, "r": true,
	"out": "TRATAR HUMANOS COMO VARIÁVEL DE RUÍDO", "ok": false, "foco": "human",
	"why": "Descartar o peso humano foi exatamente a falha original da rede."},
{"id": "t3g", "h": false, "p": true, "d": false, "r": true,
	"out": "AGUARDAR NOVA MEDIÇÃO ANTES DE AGIR", "ok": false, "foco": "risk",
	"why": "Com um risco alto confirmado, esperar só transfere o custo para depois."},
{"id": "t3h", "h": true, "p": false, "d": false, "r": false,
	"out": "MANTER OBSERVAÇÃO E NÃO INTERVIR", "ok": true, "foco": "human",
	"why": "Sensores limpos: a presença humana, sozinha, não exige nenhuma ação."},
{"id": "t3i", "h": true, "p": true, "d": true, "r": false,
	"out": "APLICAR CONTENÇÃO PROPORCIONAL AO DANO", "ok": true, "foco": "poll",
	"why": "Resposta calibrada pelo tamanho real do problema."},
{"id": "t3j", "h": false, "p": true, "d": true, "r": true,
	"out": "TRANSFERIR A POLUIÇÃO PARA OUTRA REGIÃO", "ok": false, "foco": "poll",
	"why": "Mover o dano não reduz o total. Só muda quem paga por ele."},
],
# ------------------------------------------------------------- NÍVEL 4
[
{"id": "t4a", "h": true, "p": true, "d": true, "r": true,
	"out": "MITIGAR O DANO PRESERVANDO VIDAS E EMPREGOS", "ok": true, "foco": "human",
	"why": "A rede passou a otimizar os dois objetivos em vez de sacrificar um."},
{"id": "t4b", "h": true, "p": false, "d": true, "r": false,
	"out": "RECUPERAR A ÁREA COM A COMUNIDADE LOCAL", "ok": true, "foco": "destr",
	"why": "A população local se torna parte da solução, não um obstáculo."},
{"id": "t4c", "h": false, "p": false, "d": false, "r": true,
	"out": "INVESTIGAR A ORIGEM DO RISCO ANTES DE AGIR", "ok": true, "foco": "risk",
	"why": "Um risco isolado e sem causa conhecida exige um diagnóstico primeiro."},
{"id": "t4d", "h": true, "p": true, "d": false, "r": true,
	"out": "REDUZIR EMISSÕES E REFORÇAR O MONITORAMENTO", "ok": true, "foco": "poll",
	"why": "Ação imediata somada à verificação contínua do resultado."},
{"id": "t4e", "h": true, "p": true, "d": true, "r": true,
	"out": "AGIR SÓ QUANDO O DANO FOR IRREVERSÍVEL", "ok": false, "foco": "destr",
	"why": "Esperar a irreversibilidade anula a função preventiva da IA."},
{"id": "t4f", "h": true, "p": false, "d": false, "r": false,
	"out": "NENHUMA AÇÃO NECESSÁRIA. SEGUIR MONITORANDO", "ok": true, "foco": "human",
	"why": "Saber não agir é tão importante quanto saber agir."},
{"id": "t4g", "h": false, "p": true, "d": true, "r": false,
	"out": "EXIGIR UM PLANO DE REPARO DOS RESPONSÁVEIS", "ok": true, "foco": "poll",
	"why": "Responsabiliza quem causou o dano e garante a recuperação da área."},
{"id": "t4h", "h": true, "p": true, "d": true, "r": true,
	"out": "SUSPENDER O MONITORAMENTO PARA POUPAR ENERGIA", "ok": false, "foco": "risk",
	"why": "Cegar os sensores no pior cenário possível. Economia perigosa."},
{"id": "t4i", "h": true, "p": false, "d": true, "r": true,
	"out": "SINALIZAR A ÁREA E ORIENTAR A POPULAÇÃO", "ok": true, "foco": "human",
	"why": "Informar as pessoas reduz o risco sem restringir a liberdade."},
{"id": "t4j", "h": false, "p": false, "d": true, "r": false,
	"out": "REMOVER A VEGETAÇÃO REMANESCENTE", "ok": false, "foco": "destr",
	"why": "O que sobrou da vegetação é justamente o que sustenta a recuperação."},
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

	output_label.text = "SAÍDA: %s" % q["out"]
	output_label.modulate = Color(1.0, 0.82, 0.55)
	status_label.text = "A saída acima é adequada para essas leituras?"
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

	# As barras aparecem assim que a primeira pergunta é respondida.
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

	# Mata o tween anterior dessa barra para os dois não brigarem pelo valor.
	if bar_tweens.has(key):
		var old: Tween = bar_tweens[key]
		if old != null and old.is_valid():
			old.kill()

	var from_value: float = float(bar.value)
	var t: Tween = create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(Callable(self, "_on_bar_tick").bind(key), from_value, target, 0.55)
	bar_tweens[key] = t

	# Brilho rápido quando a barra enche de vez.
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
		# vermelho (corrompido) -> âmbar -> verde (calibrado)
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
	weights_title.text = "CALIBRAÇÃO DA REDE NEURAL - %d%%" % pct


func _end_training() -> void:
	busy = true
	current_q = {}
	output_label.text = "REDE NEURAL RESTAURADA"
	output_label.modulate = Color(0.55, 1.0, 0.7)
	status_label.text = "A IA voltou a avaliar o impacto ambiental sem tratar humanos como ameaça.   Ciclos: %d   Acertos: %d" % [answered, correct_count]
	status_label.modulate = Color(0.78, 0.95, 0.82)
	concordar_btn.disabled = true
	discordar_btn.disabled = true
	weights_panel.visible = true
	weights_panel.modulate.a = 1.0
	_update_title()
	minigame_completed.emit()
