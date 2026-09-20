extends Control

signal minigame_completed
signal minigame_exit_requested

const MAX_W: float = 100.0
const START_W: float = 15.0
const CORRECT_ANSWERS_PER_PARAMETER: int = 3
const WRONG_PENALTY: float = 7.0
const FEEDBACK_DURATION: float = 3.2
const PARAM_KEYS: Array[String] = ["human", "poll", "destr", "risk"]
const KEY_LABELS: Dictionary = {
	"human": "PRESENÇA HUMANA",
	"poll": "POLUIÇÃO",
	"destr": "DESTRUIÇÃO AMBIENTAL",
	"risk": "RISCO AMBIENTAL",
}
const KEY_CONCEPTS: Dictionary = {
	"human": "CORRELAÇÃO NÃO É CAUSA",
	"poll": "AJA SOBRE A FONTE DO PROBLEMA",
	"destr": "NÃO CRIE UM DANO MAIOR",
	"risk": "USE UMA RESPOSTA PROPORCIONAL",
}

var weights: Dictionary = {"human": START_W, "poll": START_W, "destr": START_W, "risk": START_W}

var busy: bool = false
var answered: int = 0
var correct_count: int = 0
var current_q: Dictionary = {}
var used_ids: Dictionary = {}
var last_output: String = ""
var bar_tweens: Dictionary = {}
var connection_tweens: Dictionary = {}
var current_inputs: Dictionary = {"human": false, "poll": false, "destr": false, "risk": false}
var correct_by_parameter: Dictionary = {"human": 0, "poll": 0, "destr": 0, "risk": 0}
var pause_open: bool = false
var training_completed: bool = false
var run_generation: int = 0
var animation_was_playing: bool = false

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
@onready var intro_panel: Control = $IntroPanel
@onready var status_panel: Panel = $StatusPanel
@onready var output_panel: Panel = $OutputPanel
@onready var output_node: Polygon2D = $NeuralNetwork/OutputNode
@onready var output_halo: Polygon2D = $NeuralNetwork/OutputHalo
@onready var neural_animation: AnimationPlayer = $NeuralAnimation
@onready var pause_overlay: Control = $PauseOverlay
@onready var continue_button: Button = $PauseOverlay/PausePanel/ContinueButton

@onready var input_nodes: Dictionary = {
	"human": $NeuralNetwork/Input1,
	"poll": $NeuralNetwork/Input2,
	"destr": $NeuralNetwork/Input3,
	"risk": $NeuralNetwork/Input4,
}
@onready var input_text_lines: Dictionary = {
	"human": $NeuralNetwork/TextConnections/HumanPresence,
	"poll": $NeuralNetwork/TextConnections/Pollution,
	"destr": $NeuralNetwork/TextConnections/EnvironmentalDestruction,
	"risk": $NeuralNetwork/TextConnections/EnvironmentalRisk,
}
@onready var input_network_lines: Dictionary = {
	"human": [$NeuralNetwork/InputConnections/L01, $NeuralNetwork/InputConnections/L02],
	"poll": [$NeuralNetwork/InputConnections/L03, $NeuralNetwork/InputConnections/L04, $NeuralNetwork/InputConnections/L05],
	"destr": [$NeuralNetwork/InputConnections/L06, $NeuralNetwork/InputConnections/L07, $NeuralNetwork/InputConnections/L08],
	"risk": [$NeuralNetwork/InputConnections/L09, $NeuralNetwork/InputConnections/L10, $NeuralNetwork/InputConnections/L11],
}
@onready var focus_paths: Dictionary = {
	"human": $NeuralNetwork/FocusHuman,
	"poll": $NeuralNetwork/FocusPollution,
	"destr": $NeuralNetwork/FocusDestruction,
	"risk": $NeuralNetwork/FocusRisk,
}

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
	pause_overlay.hide()
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
	intro_panel.visible = true
	intro_panel.modulate.a = 1.0
	status_panel.modulate = Color.WHITE
	output_panel.modulate = Color.WHITE
	for path in focus_paths.values():
		(path as Line2D).modulate.a = 0.0
	_update_title()
	_next_question()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if event.is_echo() or training_completed:
			return
		if pause_open:
			_resume_minigame()
		else:
			_pause_minigame()
		return
	if pause_open:
		get_viewport().set_input_as_handled()
		return
	if busy or current_q.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_avaliar(true)
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_avaliar(false)


func _pause_minigame() -> void:
	if pause_open or training_completed:
		return
	pause_open = true
	animation_was_playing = neural_animation.is_playing()
	if animation_was_playing:
		neural_animation.pause()
	_set_progress_tweens_paused(true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	MusicController.pause_all_audio()
	get_tree().paused = true
	pause_overlay.show()
	continue_button.grab_focus()


func _resume_minigame() -> void:
	if not pause_open:
		return
	pause_overlay.hide()
	pause_open = false
	get_tree().paused = false
	MusicController.resume_all_audio()
	_set_progress_tweens_paused(false)
	if animation_was_playing:
		neural_animation.play()
	animation_was_playing = false
	process_mode = Node.PROCESS_MODE_INHERIT


func _on_pause_continue_pressed() -> void:
	_resume_minigame()


func _on_pause_restart_pressed() -> void:
	_resume_minigame()
	_reset_training()


func _on_pause_exit_pressed() -> void:
	run_generation += 1
	_resume_minigame()
	minigame_exit_requested.emit()


func _exit_tree() -> void:
	if pause_open:
		pause_open = false
		get_tree().paused = false
		MusicController.resume_all_audio()


func _set_progress_tweens_paused(value: bool) -> void:
	for tween_value in bar_tweens.values():
		var tween := tween_value as Tween
		if tween != null and tween.is_valid():
			if value:
				tween.pause()
			else:
				tween.play()
	for tween_value in connection_tweens.values():
		var tween := tween_value as Tween
		if tween != null and tween.is_valid():
			if value:
				tween.pause()
			else:
				tween.play()


func _reset_training() -> void:
	run_generation += 1
	for tween_value in bar_tweens.values():
		var tween := tween_value as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	for tween_value in connection_tweens.values():
		var tween := tween_value as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	bar_tweens.clear()
	connection_tweens.clear()
	weights = {"human": START_W, "poll": START_W, "destr": START_W, "risk": START_W}
	correct_by_parameter = {"human": 0, "poll": 0, "destr": 0, "risk": 0}
	busy = false
	answered = 0
	correct_count = 0
	# current_q aponta para uma pergunta do banco; clear() apagaria o próprio
	# dicionário dentro de tiers e quebraria o próximo sorteio.
	current_q = {}
	used_ids.clear()
	last_output = ""
	training_completed = false
	status_panel.hide()
	status_label.hide()
	status_panel.modulate = Color.WHITE
	output_panel.modulate = Color.WHITE
	intro_panel.show()
	intro_panel.modulate.a = 1.0
	weights_panel.hide()
	weights_panel.modulate.a = 0.0
	for key in PARAM_KEYS:
		var bar := bars[key] as ProgressBar
		bar.value = START_W
		(bar_pcts[key] as Label).text = "%d%%" % int(START_W)
		_paint_bar(key, START_W)
		_set_connection_weight(START_W, key)
	for path_value in focus_paths.values():
		(path_value as Line2D).modulate.a = 0.0
	_update_title()
	_next_question()

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
	current_inputs = {
		"human": bool(q["h"]),
		"poll": bool(q["p"]),
		"destr": bool(q["d"]),
		"risk": bool(q["r"]),
	}
	param1_value.text = "ALTA" if q["h"] else "BAIXA"
	param2_value.text = "ALTA" if q["p"] else "BAIXA"
	param3_value.text = "ALTA" if q["d"] else "BAIXA"
	param4_value.text = "ALTO" if q["r"] else "BAIXO"
	_paint_param(param1_value, q["h"])
	_paint_param(param2_value, q["p"])
	_paint_param(param3_value, q["d"])
	_paint_param(param4_value, q["r"])

	for key in PARAM_KEYS:
		_paint_input_state(key, bool(current_inputs[key]))
	for path in focus_paths.values():
		(path as Line2D).modulate.a = 0.0
	_set_output_state(-1)
	_refresh_connection_weights()

	output_label.text = "SAÍDA: %s" % q["out"]
	output_label.modulate = Color(1.0, 0.82, 0.55)
	status_label.text = "COMPARE AS LEITURAS COM A SAÍDA. ELA É ADEQUADA?"
	status_label.modulate = Color(0.68, 0.68, 0.68)
	status_panel.modulate = Color.WHITE
	output_panel.modulate = Color.WHITE
	status_panel.hide()
	status_label.hide()
	concordar_btn.show()
	discordar_btn.show()

	concordar_btn.disabled = false
	discordar_btn.disabled = false
	busy = false


func _paint_param(lbl: Label, high: bool) -> void:
	lbl.modulate = Color(1.0, 0.6, 0.35) if high else Color(0.55, 0.85, 0.6)


func _paint_input_state(key: String, high: bool) -> void:
	var input_node: Polygon2D = input_nodes[key] as Polygon2D
	var text_line: Line2D = input_text_lines[key] as Line2D
	input_node.scale = Vector2.ONE * (1.22 if high else 0.76)
	input_node.modulate = Color(1.0, 1.0, 1.0, 1.0 if high else 0.38)
	text_line.width = 2.0 if high else 0.75
	text_line.default_color = Color(0.3, 1.0, 0.63, 0.9 if high else 0.3)


func _refresh_connection_weights() -> void:
	for key in PARAM_KEYS:
		_set_connection_weight(float(weights[key]), key)


func _set_connection_weight(value: float, key: String) -> void:
	var strength: float = clampf(value / MAX_W, 0.0, 1.0)
	var active_factor: float = 1.0 if bool(current_inputs[key]) else 0.62
	var line_width: float = (0.65 + strength * 1.75) * active_factor
	var alpha: float = (0.18 + strength * 0.62) * active_factor
	for item in input_network_lines[key]:
		var line: Line2D = item as Line2D
		line.width = line_width
		line.default_color = Color(0.24, 0.78, 0.62, alpha)


func _animate_connection_weight(key: String, from_value: float, target: float) -> void:
	if connection_tweens.has(key):
		var old: Tween = connection_tweens[key]
		if old != null and old.is_valid():
			old.kill()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(Callable(self, "_set_connection_weight").bind(key), from_value, target, 0.55)
	connection_tweens[key] = tween


func _set_output_state(state: int) -> void:
	var color: Color = Color(0.9, 0.75, 0.24, 1.0)
	if state == 1:
		color = Color(0.35, 1.0, 0.6, 1.0)
	elif state == 0:
		color = Color(1.0, 0.34, 0.28, 1.0)
	output_node.color = color
	output_halo.color = Color(color.r, color.g, color.b, 0.18)


func _flash_focus_path(key: String, output_is_safe: bool) -> void:
	for item in focus_paths.values():
		(item as Line2D).modulate.a = 0.0
	var path: Line2D = focus_paths[key] as Line2D
	path.default_color = Color(0.35, 1.0, 0.6, 1.0) if output_is_safe else Color(1.0, 0.32, 0.24, 1.0)
	path.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(path, "modulate:a", 1.0, 0.16)
	tween.tween_property(path, "modulate:a", 0.35, 0.32)
	tween.tween_property(path, "modulate:a", 0.9, 0.24)
	tween.tween_property(path, "modulate:a", 0.0, FEEDBACK_DURATION - 0.72)

func _on_concordar_btn_pressed() -> void:
	_avaliar(true)


func _on_discordar_btn_pressed() -> void:
	_avaliar(false)


func _avaliar(player_agrees: bool) -> void:
	if pause_open or busy or current_q.is_empty():
		return
	var evaluation_generation := run_generation
	busy = true
	concordar_btn.disabled = true
	discordar_btn.disabled = true
	concordar_btn.hide()
	discordar_btn.hide()
	status_panel.show()
	status_label.show()

	var acertou: bool = (player_agrees == bool(current_q["ok"]))
	var foco: String = str(current_q["foco"])
	var previous_weights: Dictionary = weights.duplicate()
	answered += 1

	if acertou:
		correct_count += 1
		var parameter_correct: int = mini(
			int(correct_by_parameter[foco]) + 1,
			CORRECT_ANSWERS_PER_PARAMETER
		)
		correct_by_parameter[foco] = parameter_correct
		var progress := float(parameter_correct) / float(CORRECT_ANSWERS_PER_PARAMETER)
		weights[foco] = lerpf(START_W, MAX_W, progress)
	else:
		weights[foco] = clampf(weights[foco] - WRONG_PENALTY, 0.0, MAX_W)

	var verdict: String = "DECISÃO CORRETA" if acertou else "DECISÃO INCORRETA"
	var adjustment: String = "PESO CORRIGIDO" if acertou else "RECALIBRAÇÃO REGREDIU"
	status_label.text = "%s · %s\n%s\n%s: %s  %d%% → %d%%" % [
		verdict,
		str(KEY_CONCEPTS[foco]),
		str(current_q["why"]),
		adjustment,
		str(KEY_LABELS[foco]),
		int(round(float(previous_weights[foco]))),
		int(round(float(weights[foco]))),
	]
	status_label.modulate = Color(0.55, 1.0, 0.65) if acertou else Color(1.0, 0.58, 0.48)
	status_panel.modulate = Color(0.72, 1.0, 0.78) if acertou else Color(1.0, 0.68, 0.62)

	output_label.modulate = Color(0.6, 1.0, 0.72) if bool(current_q["ok"]) else Color(1.0, 0.45, 0.45)
	output_panel.modulate = Color(0.72, 1.0, 0.78) if bool(current_q["ok"]) else Color(1.0, 0.67, 0.58)
	_set_output_state(1 if bool(current_q["ok"]) else 0)
	_flash_focus_path(foco, bool(current_q["ok"]))

	# As barras aparecem assim que a primeira pergunta é respondida.
	if answered == 1 and not weights_panel.visible:
		_reveal_panel()

	_update_bars()
	for key in PARAM_KEYS:
		_animate_connection_weight(key, float(previous_weights[key]), float(weights[key]))
	_update_title()

	await get_tree().create_timer(FEEDBACK_DURATION, false).timeout
	if not is_inside_tree() or evaluation_generation != run_generation:
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
	if intro_panel.visible:
		var intro_tween: Tween = create_tween()
		intro_tween.tween_property(intro_panel, "modulate:a", 0.0, 0.28)
		intro_tween.tween_callback(intro_panel.hide)
	weights_panel.visible = true
	weights_panel.modulate.a = 0.0
	var t: Tween = create_tween()
	t.set_parallel(false)
	t.tween_interval(0.12)
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
	var state: String
	if pct < 30:
		state = "REDE CORROMPIDA"
	elif pct < 65:
		state = "REDE EM RECALIBRAÇÃO"
	elif pct < 90:
		state = "REDE ESTÁVEL"
	elif pct < 100:
		state = "REDE QUASE RECALIBRADA"
	else:
		state = "REDE RECALIBRADA"
	weights_title.text = "%s — %d%%" % [state, pct]


func _end_training() -> void:
	busy = true
	training_completed = true
	current_q = {}
	concordar_btn.hide()
	discordar_btn.hide()
	status_panel.show()
	status_label.show()
	output_label.text = "REDE NEURAL RESTAURADA"
	output_label.modulate = Color(0.55, 1.0, 0.7)
	status_label.text = "RECALIBRAÇÃO CONCLUÍDA\nA IA voltou a avaliar o impacto ambiental sem tratar humanos como ameaça.\nCiclos: %d   Acertos: %d" % [answered, correct_count]
	status_label.modulate = Color(0.78, 0.95, 0.82)
	status_panel.modulate = Color(0.72, 1.0, 0.78)
	output_panel.modulate = Color(0.72, 1.0, 0.78)
	_set_output_state(1)
	concordar_btn.disabled = true
	discordar_btn.disabled = true
	weights_panel.visible = true
	weights_panel.modulate.a = 1.0
	_update_title()
	minigame_completed.emit()
