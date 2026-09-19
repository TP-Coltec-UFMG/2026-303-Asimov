extends Node

const MINIGAME := preload(
	"res://Minigames/Minigame5/Scene/mini_game_cartao.tscn"
)

var failures: Array[String] = []
var original_save: Dictionary
var original_time: float


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--rfid-card-test"):
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	original_save = SaveGame.save_data.duplicate(true)
	original_time = SaveGame.tempo_atual
	SaveGame.save_data = {}
	SaveGame.tempo_atual = 300.0

	var minigame := MINIGAME.instantiate()
	get_tree().root.add_child(minigame)
	get_tree().current_scene = minigame
	await get_tree().process_frame

	var quest := minigame.get_node("QUEST_MISSION") as QuestMissionUI
	var campaign_timer := minigame.get_node("CampaignHUD/Controle_de_tempo") as Control
	var pause_menu := minigame.get_node("CampaignHUD/PauseMenu") as Control
	_expect(quest.standalone_mode, "O painel do minigame precisa operar isolado da campanha.")
	_expect((quest.get_node("ColorRect") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "O painel de tarefas não pode cobrir as interações do cenário.")
	_expect((quest.get_node("ColorRect") as Control).position.x <= 0.01, "Neste minigame, o painel de tarefas precisa ficar no lado esquerdo.")
	_expect((quest.get_node("StandaloneBorder") as Control).visible, "O painel deste minigame precisa exibir a borda branca.")
	_expect(campaign_timer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "A camada do cronômetro não pode bloquear os cliques do minigame.")
	_expect(pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "O menu de pausa precisa receber ESC durante a pausa.")
	_expect(_task_text(quest, 0) == "PASSE O CARTÃO NO LEITOR", "A primeira tarefa deve pedir o primeiro teste do cartão.")
	_expect(_task_text(quest, 1) == "CONECTE O CABO AO LEITOR", "O painel inicial precisa antecipar a segunda tarefa.")
	_expect(_task_text(quest, 2) == "ENTRE NO NOTEBOOK", "O painel inicial precisa mostrar três tarefas.")
	_expect(minigame.botao_continuar_tutorial.visible, "As mensagens precisam manter o botão Continuar.")

	minigame.mostrar_etapa_tutorial(3)
	_expect(_task_completed(quest, 0), "Passar o cartão precisa permanecer visível e marcado como concluído.")
	_expect(_task_text(quest, 1) == "CONECTE O CABO AO LEITOR", "O cartão recusado deve orientar a conexão do cabo.")
	minigame.mostrar_etapa_tutorial(4)
	_expect(_task_completed(quest, 1), "Conectar o cabo precisa receber o check antes da próxima etapa.")
	_expect(_task_text(quest, 2) == "ENTRE NO NOTEBOOK", "Após conectar, a tarefa deve orientar a entrada no notebook.")
	minigame.call("_mostrar_progresso_tarefas", 3, true)
	_expect(_task_text(quest, 0) == "ENTRE NO NOTEBOOK", "Ao renovar o painel, a última tarefa anterior precisa permanecer.")
	_expect(_task_text(quest, 1) == "COPIE O CÓDIGO DO CARTÃO", "O notebook deve orientar a cópia do código.")
	_expect(_task_text(quest, 2) == "ABRA O BANCO DE DADOS", "A renovação deve acrescentar mais duas tarefas.")
	minigame.mostrar_etapa_tutorial(5)
	_expect(_task_completed(quest, 1), "Copiar o código precisa ficar marcado como concluído.")
	minigame.mostrar_etapa_tutorial(6)
	_expect(_task_text(quest, 0) == "ABRA O BANCO DE DADOS", "A segunda renovação precisa preservar a última tarefa anterior.")
	_expect(_task_text(quest, 1) == "INSIRA O CÓDIGO DO CARTÃO", "O banco deve orientar a inserção do código.")
	_expect(_task_text(quest, 2) == "FECHE O NOTEBOOK", "A segunda renovação deve acrescentar duas tarefas.")
	minigame.mostrar_etapa_tutorial(7)
	_expect(_task_completed(quest, 1), "Inserir o código precisa ficar marcado como concluído.")
	minigame.mostrar_etapa_tutorial(8)
	_expect(_task_text(quest, 0) == "FECHE O NOTEBOOK", "A última renovação precisa preservar o fechamento do notebook.")
	_expect(_task_text(quest, 1) == "TESTE O CARTÃO NOVAMENTE", "A última tarefa prática deve pedir o segundo teste do cartão.")
	_expect(_task_text(quest, 2) == "CARTÃO RFID REPROGRAMADO", "O resultado final precisa permanecer visível no trio.")
	minigame.call("_on_continuar_tutorial_pressed")
	_expect(not minigame.painel_tutorial.visible, "Continuar deve dispensar as mensagens das etapas práticas.")

	await get_tree().create_timer(0.12).timeout
	_expect(SaveGame.tempo_atual < 300.0, "O cronômetro da campanha precisa continuar dentro do minigame.")
	campaign_timer.set_process(false)
	var escape_event := InputEventAction.new()
	escape_event.action = &"esc"
	escape_event.pressed = true
	pause_menu.call("_unhandled_input", escape_event)
	_expect(get_tree().paused, "ESC precisa abrir o menu de pausa dentro do minigame.")
	pause_menu.call("_unhandled_input", escape_event)
	_expect(not get_tree().paused, "ESC precisa fechar o menu de pausa e devolver o controle.")

	minigame.leitor_cartao.acesso_liberado.emit()
	await get_tree().process_frame
	_expect(bool(minigame.get("_finalizando")), "A segunda leitura aceita deve encerrar o fluxo uma única vez.")
	_expect(_task_completed(quest, 0) and _task_completed(quest, 1) and _task_completed(quest, 2), "O trio final precisa permanecer visível e concluído.")

	var state := SaveGame.office_mission_state()
	Progresso.retorno_cartao_rfid = true
	Progresso.cena_de_retorno = ""
	Progresso.marcador_de_retorno = ""
	Progresso.concluir_reprogramacao_cartao_rfid()
	_expect(bool(state.get("data_center_rfid_minigame_completed", false)), "A conclusão precisa ser salva na campanha.")
	_expect(bool(state.get("data_center_rfid_reading_checked", false)), "A tarefa RFID só deve concluir após este minigame.")
	_expect(not bool(state.get("data_center_rfid_reading_task_active", true)), "A tarefa RFID não pode continuar ativa após a leitura aceita.")

	SaveGame.save_data = original_save
	SaveGame.tempo_atual = original_time
	if failures.is_empty():
		print("RFID_CARD_MINIGAME_TEST_PASSED")
		get_tree().quit(0)
	else:
		print("RFID_CARD_MINIGAME_TEST_FAILED: ", failures)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _task_text(quest: QuestMissionUI, row_index: int) -> String:
	return str((quest.rows[row_index].get_node("Label3") as Label).text)


func _task_completed(quest: QuestMissionUI, row_index: int) -> bool:
	var marker := quest.markers[row_index]
	return (
		marker.is_playing()
		or marker.frame == marker.sprite_frames.get_frame_count(&"default") - 1
	)
