extends Node
## Estado pequeno e independente. As fases ficam abertas para testar no editor.
var concluidas: Array = [[false, false, false, false], [false, false, false, false], [false]]
var som_ativo: bool = true
var modo_teste: bool = false
var retorno_da_sala_do_chefe: bool = false
var retorno_reparo_rfid: bool = false
var cena_de_retorno: String = ""
var marcador_de_retorno: String = ""
const ARQUIVO := "user://asimov_progresso.cfg"
const CAMINHOS := [
	["res://Minigames/Minigame1/levels/UnlockSecurity.tscn", "res://Minigames/Minigame1/levels/unlock_security_2.tscn", "res://Minigames/Minigame1/levels/unlock_security_3.tscn", "res://Minigames/Minigame1/levels/unlock_security_4.tscn"],
	["res://MinigamesProgramador/Minigame2/levels/slider_hacking.tscn", "res://MinigamesProgramador/Minigame2/levels/slider_hacking_2.tscn", "res://MinigamesProgramador/Minigame2/levels/slider_hacking_3.tscn", "res://MinigamesProgramador/Minigame2/levels/slider_hacking_4.tscn"],
	["res://MinigamesProgramador/Minigame3/recovery_system.tscn"]
]

func _ready() -> void:
	modo_teste = OS.get_cmdline_user_args().has("--test")
	if modo_teste:
		return
	var arquivo := ConfigFile.new()
	if arquivo.load(ARQUIVO) == OK:
		for jogo in range(3):
			for fase in range(concluidas[jogo].size()):
				concluidas[jogo][fase] = bool(arquivo.get_value("fases", "%d_%d" % [jogo, fase], false))
		som_ativo = bool(arquivo.get_value("opcoes", "som", true))

func salvar() -> void:
	if modo_teste:
		return
	var arquivo := ConfigFile.new()
	for jogo in range(3):
		for fase in range(concluidas[jogo].size()):
			arquivo.set_value("fases", "%d_%d" % [jogo, fase], concluidas[jogo][fase])
	arquivo.set_value("opcoes", "som", som_ativo)
	arquivo.save(ARQUIVO)

func concluir(jogo: int, fase: int) -> void:
	concluidas[jogo][fase] = true
	salvar()
	if retorno_da_sala_do_chefe and jogo == 0 and fase == 3:
		_liberar_sala_do_chefe()


func iniciar_hack_da_sala_do_chefe(player: Player) -> void:
	if not is_instance_valid(player):
		return
	SaveGame.capturar_tempo_atual()
	MusicController.set_alarm_quiet_context(&"minigame", true)
	retorno_da_sala_do_chefe = true
	cena_de_retorno = "res://Scenes/andar_escritorio.tscn"
	marcador_de_retorno = "SALA_CHEFE"
	scene_manager.player = player
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	get_tree().paused = false
	get_tree().change_scene_to_file(CAMINHOS[0][0])


func iniciar_reparo_leitor_rfid(player: Player) -> void:
	if not is_instance_valid(player):
		return
	SaveGame.capturar_tempo_atual()
	MusicController.set_alarm_quiet_context(&"minigame", true)
	retorno_reparo_rfid = true
	cena_de_retorno = "res://Scenes/andar_data_center.tscn"
	marcador_de_retorno = "DATA_CENTER_FORTE"
	scene_manager.player = player
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Minigames/Minigame2/Main.tscn")


func concluir_reparo_leitor_rfid() -> void:
	if not retorno_reparo_rfid:
		return
	SaveGame.capturar_tempo_atual()
	var estado := SaveGame.office_mission_state(scene_manager.player)
	estado["data_center_rfid_wires_task_active"] = true
	estado["data_center_rfid_wires_repaired"] = true
	estado["data_center_rfid_reading_task_active"] = true
	estado["data_center_rfid_repair_checkpointed"] = false
	SaveGame.save_global_state("hall_quest_01", estado)
	_retornar_ao_data_center()


func cancelar_reparo_leitor_rfid() -> void:
	if not retorno_reparo_rfid:
		return
	SaveGame.capturar_tempo_atual()
	_retornar_ao_data_center()


func texto_saida() -> String:
	if retorno_reparo_rfid:
		return "VOLTAR AO LEITOR"
	return "VOLTAR AO ESCRITÓRIO" if retorno_da_sala_do_chefe else "SAIR DO HACKER"

func abrir(jogo: int, fase: int) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(CAMINHOS[jogo][fase])

func menu() -> void:
	if retorno_reparo_rfid:
		cancelar_reparo_leitor_rfid()
		return
	if retorno_da_sala_do_chefe:
		_retornar_ao_escritorio()
		return
	MusicController.set_alarm_quiet_context(&"minigame", false)
	get_tree().paused = false
	get_tree().change_scene_to_file("")


func _liberar_sala_do_chefe() -> void:
	var estado := SaveGame.office_mission_state()
	estado["office_boss_room_access_found"] = true
	estado["office_boss_room_hacked"] = true
	SaveGame.save_global_state("hall_quest_01", estado)


func _retornar_ao_escritorio() -> void:
	var destino := cena_de_retorno
	var marcador := marcador_de_retorno
	retorno_da_sala_do_chefe = false
	cena_de_retorno = ""
	marcador_de_retorno = ""
	if destino.is_empty():
		MusicController.set_alarm_quiet_context(&"minigame", false)
		return
	MusicController.set_alarm_quiet_context(&"minigame", false)
	scene_manager.last_scene_name = marcador
	get_tree().paused = false
	get_tree().change_scene_to_file(destino)


func _retornar_ao_data_center() -> void:
	var destino := cena_de_retorno
	var marcador := marcador_de_retorno
	retorno_reparo_rfid = false
	cena_de_retorno = ""
	marcador_de_retorno = ""
	if destino.is_empty():
		MusicController.set_alarm_quiet_context(&"minigame", false)
		return
	MusicController.set_alarm_quiet_context(&"minigame", false)
	scene_manager.last_scene_name = marcador
	get_tree().paused = false
	get_tree().change_scene_to_file(destino)
