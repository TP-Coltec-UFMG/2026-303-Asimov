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
	state["data_center_return_task_pending"] = true
	state["data_center_return_task_active"] = false
	state["data_center_return_task_completed"] = false
	var elevator_trigger := SceneTrigger.new()
	elevator_trigger.body_p = player
	elevator_trigger.call("_concluir_tarefa_do_sexto_andar", 6)
	_expect(bool(state.get("data_center_return_task_pending", false)), "A chegada antecipada precisa continuar pendente até o fim dos balões.")
	_expect(bool(state.get("data_center_return_task_completed", false)), "O elevador precisa registrar a chegada antecipada ao sexto andar.")
	elevator_trigger.free()
	quest.call("_activate_return_to_data_center_task")
	_expect(not bool(state.get("data_center_return_task_pending", true)), "A chegada antecipada precisa encerrar o estado pendente quando a tarefa aparecer.")
	_expect(not bool(state.get("data_center_return_task_active", true)), "A tarefa não pode ficar ativa se o jogador já chegou ao data center.")
	_expect(bool(state.get("data_center_return_task_completed", false)), "A tarefa precisa aparecer concluída após uma chegada antecipada ao sexto andar.")
	state.erase("data_center_return_task_pending")
	state.erase("data_center_return_task_active")
	state.erase("data_center_return_task_completed")
	await get_tree().process_frame
	var vbox := quest.get_node("VBoxContainer") as VBoxContainer
	var panel := quest.get_node("ColorRect") as ColorRect
	for row in quest.rows:
		row.hide()
	quest.show()
	quest.rows[0].show()
	await get_tree().process_frame
	var fixed_x := vbox.position.x
	var fixed_width := vbox.size.x
	quest.rows[0].hide()
	quest.rows[7].show()
	await get_tree().process_frame
	_expect(is_equal_approx(vbox.position.x, fixed_x) and is_equal_approx(vbox.size.x, fixed_width), "Uma tarefa com quebra de linha não pode deslocar o painel horizontalmente.")
	quest.rows[7].hide()
	quest.rows[QuestMissionUI.COOLING_TASK_INDEX].show()
	await get_tree().process_frame
	_expect(is_equal_approx(vbox.position.x, fixed_x) and is_equal_approx(vbox.size.x, fixed_width), "A tarefa opcional não pode alterar a posição horizontal das outras tarefas.")
	_expect(vbox.position.x >= panel.position.x and vbox.position.x + vbox.size.x <= panel.position.x + panel.size.x + 0.01, "Os textos precisam permanecer dentro dos limites laterais do painel.")
	for row in quest.rows:
		row.hide()
	quest.hide()
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

	state["programmer_ending_started"] = true
	state["programmer_launch_isolated"] = true
	quest.show_programmer_ending_tasks(1)
	var visible_programmer_rows := 0
	var cooling_task_integrated := false
	for row in quest.rows:
		if not row.visible:
			continue
		visible_programmer_rows += 1
		var label := row.get_node("Label3") as Label
		cooling_task_integrated = cooling_task_integrated or label.text.begins_with("OPCIONAL:")
	_expect(visible_programmer_rows <= 3, "A tarefa opcional não pode criar uma quarta linha no final do programador.")
	_expect(cooling_task_integrated, "A tarefa de refrigeração deve continuar visível durante o final do programador.")
	state.erase("programmer_ending_started")
	state.erase("programmer_launch_isolated")
	quest.call("_sync_optional_cooling_row")

	for scene_path in [
		"res://Scenes/andar_data_center.tscn",
		"res://Scenes/data_center_forte.tscn",
		"res://Scenes/data_center_refrigeracao.tscn",
	]:
		var data_center_scene := load(scene_path) as PackedScene
		_expect(data_center_scene != null, "A cena do data center precisa carregar: " + scene_path)
		if data_center_scene == null:
			continue
		var data_center_instance := data_center_scene.instantiate()
		_expect(data_center_instance.has_node("CoolingLocationGuide"), "A indicação da refrigeração precisa existir em " + scene_path)
		data_center_instance.free()

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
	_expect(bool(state.get("cooling_terminal_1_completed", false)), "O primeiro terminal precisa ter seu próprio estado concluído.")
	_expect(bool(state.get("cooling_optional_task_completed", false)), "A tarefa opcional precisa ser concluída.")
	_expect(bool(state.get("cooling_other_terminal_available", false)), "O segundo terminal deve continuar disponível depois do primeiro.")
	quest.call("_process", 0.0)
	_expect(not player.balao_de_pensamento.tem_pensamento("cooling:second_terminal_option"), "A conclusão não deve mais anunciar o segundo terminal.")
	Progresso.retorno_refrigeracao_ia = true
	Progresso.concluir_refrigeracao_ia()
	_expect(is_equal_approx(SaveGame.tempo_atual, rewarded_time), "O bônus não pode ser concedido uma segunda vez.")

	Progresso.retorno_refrigeracao_ia = true
	Progresso.terminal_refrigeracao_ativo = "terminal_2"
	Progresso.concluir_refrigeracao_ia()
	var second_reward_time := SaveGame.tempo_atual
	_expect(is_equal_approx(second_reward_time, rewarded_time + 90.0), "O segundo terminal precisa conceder seu próprio bônus de noventa segundos.")
	_expect(bool(state.get("cooling_terminal_2_completed", false)), "O segundo terminal precisa ter seu próprio estado concluído.")
	_expect(bool(state.get("cooling_all_terminals_completed", false)), "Os dois terminais devem ficar registrados como concluídos.")
	_expect(not bool(state.get("cooling_other_terminal_available", true)), "Depois dos dois terminais não pode restar outra oportunidade.")
	Progresso.retorno_refrigeracao_ia = true
	Progresso.terminal_refrigeracao_ativo = "terminal_2"
	Progresso.concluir_refrigeracao_ia()
	_expect(is_equal_approx(SaveGame.tempo_atual, second_reward_time), "O segundo terminal também não pode repetir seu bônus.")

	var terminal_script := load("res://Scripts/Objects/cooling_terminal.gd") as GDScript
	var terminal_2 := Node2D.new()
	terminal_2.set_script(terminal_script)
	terminal_2.name = "CoolingTerminal2"
	_expect(terminal_2.call("_resolve_terminal_id") == "terminal_2", "CoolingTerminal2 precisa ser reconhecido automaticamente como o segundo terminal.")
	terminal_2.free()

	SaveGame.save_data = {}
	state = SaveGame.office_mission_state(player)
	state["cooling_optional_task_active"] = true
	state["cooling_optional_task_completed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	scene_manager.player = player
	Progresso.retorno_refrigeracao_ia = true
	Progresso.terminal_refrigeracao_ativo = "terminal_1"
	Progresso.cena_de_retorno = ""
	Progresso.marcador_de_retorno = ""
	var expired_gameplay := gameplay.instantiate()
	add_child(expired_gameplay)
	expired_gameplay.call("tempo_finalizado")
	_expect(bool(expired_gameplay.get("puzzle_expirado")), "O fim dos trinta segundos precisa expirar a tentativa.")
	_expect(bool(expired_gameplay.get("parado")), "O puzzle precisa bloquear a entrada quando o tempo acabar.")
	await get_tree().create_timer(2.1).timeout
	expired_gameplay.queue_free()
	state = SaveGame.office_mission_state(player)
	_expect(bool(state.get("cooling_terminal_1_failed", false)), "O terminal cujo tempo acabou precisa ficar indisponível.")
	_expect(Progresso.terminal_refrigeracao_disponivel(state, "terminal_2"), "O outro terminal precisa continuar disponível após a falha.")
	_expect(not Progresso.terminal_refrigeracao_disponivel(state, "terminal_1"), "O terminal que falhou não pode ser iniciado novamente.")
	_expect(bool(state.get("cooling_optional_task_active", false)), "A tarefa deve continuar ativa enquanto existir outro terminal.")
	quest.call("_process", 0.0)
	_expect(player.balao_de_pensamento.tem_pensamento(QuestMissionUI.COOLING_THOUGHT_FAILURE), "A falha precisa gerar o pensamento de frustração.")
	_expect(player.balao_de_pensamento.tem_pensamento(QuestMissionUI.COOLING_THOUGHT_FAILURE_ALTERNATIVE), "A falha precisa avisar sobre o outro sistema de refrigeração.")

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
