extends Node

const PLAYER_SCENE := preload("res://Player/ManPlayer.tscn")
const TIMER_SCENE := preload("res://Objects/controle_de_tempo.tscn")

var failures: Array[String] = []
var original_save: Dictionary
var original_time: float


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--cooling-test"):
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	original_save = SaveGame.save_data.duplicate(true)
	original_time = SaveGame.tempo_atual
	SaveGame.save_data = {}
	var state := SaveGame.office_mission_state()
	state["data_center_power_outage"] = true
	state["data_center_breaker_restored"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	SaveGame.tempo_atual = 119.0
	var timer := TIMER_SCENE.instantiate()
	add_child(timer)
	timer.set_process(false)
	timer.call("_verificar_evento_refrigeracao", 119.0)
	_expect(not bool(state.get("cooling_opportunity_pending", false)), "A queda de energia não pode antecipar a oportunidade.")
	state["data_center_breaker_restored"] = true
	timer.call("_verificar_evento_refrigeracao", 119.0)
	_expect(bool(state.get("cooling_opportunity_pending", false)), "O tempo normal abaixo de dois minutos deve deixar o evento pendente.")
	_expect(bool(state.get("cooling_opportunity_triggered", false)), "O gatilho precisa impedir eventos duplicados.")

	var player := PLAYER_SCENE.instantiate() as Player
	player.checkpoint_enabled = false
	add_child(player)
	player.set_physics_process(true)
	var quest := player.get_node("QUEST_MISSION") as QuestMissionUI
	quest.set_process(false)
	player.balao_de_pensamento.enfileirar("test:busy", "Ainda estou ocupado.")
	quest.call("_process", 5.0)
	_expect(not player.balao_de_pensamento.tem_pensamento(QuestMissionUI.COOLING_THOUGHT_TIME), "O evento deve esperar qualquer pensamento já em andamento.")
	player.balao_de_pensamento.pular_pensamento()
	await get_tree().process_frame
	quest.call("_process", 2.9)
	_expect(not player.balao_de_pensamento.tem_pensamento(QuestMissionUI.COOLING_THOUGHT_TIME), "O pensamento deve respeitar os três segundos livres.")
	quest.call("_process", 0.2)
	_expect(player.balao_de_pensamento.tem_pensamento(QuestMissionUI.COOLING_THOUGHT_TIME), "O pensamento deve começar depois do intervalo.")
	for _index in range(3):
		player.balao_de_pensamento.pular_pensamento()
		await get_tree().process_frame
	_expect(bool(state.get("cooling_optional_task_active", false)), "A tarefa deve ser ativada somente após os três pensamentos.")
	_expect((quest.rows[QuestMissionUI.COOLING_TASK_INDEX] as CanvasItem).visible, "A tarefa opcional deve aparecer no painel.")

	var menu := load("res://Minigames/PuzzleDosCanos/tscn/menu.tscn") as PackedScene
	var gameplay := load("res://Minigames/PuzzleDosCanos/tscn/gameplay.tscn") as PackedScene
	_expect(menu != null and gameplay != null, "As duas cenas do puzzle precisam carregar pelos caminhos corrigidos.")

	timer.call("carregar_tempo_restante", 60.0)
	timer.queue_free()
	await get_tree().process_frame
	scene_manager.player = player
	Progresso.retorno_refrigeracao_ia = true
	# O teste valida o prêmio sem trocar a cena que está executando o próprio teste.
	Progresso.cena_de_retorno = ""
	Progresso.marcador_de_retorno = ""
	var gameplay_instance := gameplay.instantiate()
	add_child(gameplay_instance)
	gameplay_instance.set("puzzle_concluido", true)
	(gameplay_instance.get_node("anim") as AnimationPlayer).play(&"clear")
	await get_tree().create_timer(2.1).timeout
	gameplay_instance.queue_free()
	var rewarded_time := SaveGame.tempo_atual
	_expect(rewarded_time > 147.0 and rewarded_time <= 150.0, "Concluir o puzzle deve acrescentar noventa segundos ao tempo restante após a animação.")
	_expect(bool(state.get("cooling_time_reward_granted", false)), "O bônus precisa ser marcado como concedido uma única vez.")
	_expect(bool(state.get("cooling_optional_task_completed", false)), "A tarefa opcional precisa ser concluída.")
	Progresso.retorno_refrigeracao_ia = true
	Progresso.concluir_refrigeracao_ia()
	_expect(is_equal_approx(SaveGame.tempo_atual, rewarded_time), "O bônus não pode ser concedido uma segunda vez.")

	SaveGame.save_data = original_save
	SaveGame.tempo_atual = original_time
	if failures.is_empty():
		print("COOLING_OPTIONAL_TEST_PASSED")
		get_tree().quit(0)
	else:
		print("COOLING_OPTIONAL_TEST_FAILED: ", failures)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
