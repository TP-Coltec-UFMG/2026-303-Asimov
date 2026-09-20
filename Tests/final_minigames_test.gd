extends Node

const MINIGAME_4 := preload(
	"res://Minigames/finalsMinigames/Minigame4/recovery_system.tscn"
)
const MINIGAME_CIRCUITO := preload(
	"res://Minigames/finalsMinigames/MinigameCircuito/Scene/mini_game_eletronica.tscn"
)
const MINIGAME_REDE_NEURAL := preload(
	"res://Minigames/finalsMinigames/MinigameRedeNeural/minigame.tscn"
)

var failures: Array[String] = []
var completed_signals: int = 0
var failed_signals: int = 0


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--final-minigames-test"):
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	await _test_minigame_4()
	await _test_rede_neural()
	await _test_circuito()

	if failures.is_empty():
		print("FINAL_MINIGAMES_TEST_PASSED")
		get_tree().quit(0)
	else:
		print("FINAL_MINIGAMES_TEST_FAILED: ", failures)
		get_tree().quit(1)


func _test_minigame_4() -> void:
	var minigame := MINIGAME_4.instantiate()
	add_child(minigame)
	await get_tree().process_frame
	minigame.minigame_completed.connect(_on_completed)
	minigame.iniciar()
	while not minigame.terminou:
		var scenario: Dictionary = minigame.CENARIOS[minigame.atual]
		minigame.responder(int(scenario.resposta))
		minigame.mostrar_proxima()
	_expect(minigame.terminou, "O Minigame 4 precisa chegar à tela de conclusão.")
	_expect(minigame.prioridades == [100, 100, 100], "As três leis precisam chegar a 100%.")
	_expect(completed_signals == 1, "O Minigame 4 precisa avisar sua conclusão uma única vez.")
	minigame.reiniciar()
	_expect(not minigame.terminou and not minigame.iniciado, "O Minigame 4 precisa reiniciar sem sair do jogo.")
	minigame.queue_free()
	await get_tree().process_frame


func _test_rede_neural() -> void:
	var minigame := MINIGAME_REDE_NEURAL.instantiate()
	add_child(minigame)
	await get_tree().process_frame
	var before := completed_signals
	minigame.minigame_completed.connect(_on_completed)
	for key in minigame.PARAM_KEYS:
		minigame.weights[key] = minigame.MAX_W
	minigame.call("_end_training")
	_expect(minigame.busy, "A rede neural precisa bloquear novas respostas ao terminar.")
	_expect(minigame.current_q.is_empty(), "A rede neural precisa limpar a pergunta ao terminar.")
	_expect(completed_signals == before + 1, "A rede neural precisa avisar sua conclusão.")
	minigame.queue_free()
	await get_tree().process_frame


func _test_circuito() -> void:
	var minigame := MINIGAME_CIRCUITO.instantiate()
	add_child(minigame)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var circuit := minigame.get_node("Circuito")
	var interface := minigame.get_node("Circuito/Interface")
	minigame.minigame_completed.connect(_on_completed)
	minigame.minigame_failed.connect(_on_failed)
	_expect(get_tree().get_nodes_in_group("fios").size() == 7, "O circuito precisa iniciar com os sete fios carregados.")
	_expect(circuit.esta_fechado, "O circuito inicial precisa estar fechado e funcional.")

	var before_completed := completed_signals
	interface.definir_objetivo(interface.Objetivo.RESISTOR)
	circuit.resistor_queimado = true
	interface.verificar_objetivo()
	await get_tree().create_timer(2.1).timeout
	_expect(interface.jogo_terminado, "O circuito precisa reconhecer o objetivo concluído.")
	_expect(interface.tela_game_win.visible, "O circuito precisa mostrar a tela de vitória.")
	_expect(completed_signals == before_completed + 1, "O circuito precisa avisar sua conclusão sem fechar o jogo.")

	interface.jogo_terminado = false
	interface.game_over_ativo = false
	interface.tela_game_win.visible = false
	var before_failed := failed_signals
	interface.game_over()
	_expect(interface.tela_game_over.visible, "O circuito precisa mostrar a tela de derrota.")
	_expect(failed_signals == before_failed + 1, "O circuito precisa avisar a derrota sem fechar o jogo.")
	minigame.queue_free()
	await get_tree().process_frame


func _on_completed() -> void:
	completed_signals += 1


func _on_failed() -> void:
	failed_signals += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
