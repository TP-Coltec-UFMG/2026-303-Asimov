extends Node

const FILE_PATH: String = "user://SaveFileGameState.json"
const CHARACTER_SELECTION_SCENE: String = "res://Scenes/slectionpage.tscn"

const INVALID_CHECKPOINT_POS: Vector2 = Vector2(-999, -999)
const SAVE_VERSION: int = 3

# Tempo registrado no último checkpoint.
var tempo_restante: float = -1.0

# Tempo atual da partida, mantido durante mudanças de andar.
var tempo_atual: float = -1.0

var save_data: Dictionary = {}

var checkpoint_scene_path: String = ""
var checkpoint_player_scene_path: String = ""
var checkpoint_pos: Vector2 = INVALID_CHECKPOINT_POS
var state_player: Dictionary = {}
var checkpoint_world_state: Dictionary = {}
var checkpoint_progress: Dictionary = {}

var restore_checkpoint_pending: bool = false


func _ready() -> void:
	_load()


func _save() -> void:
	if checkpoint_scene_path.is_empty():
		return

	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Não foi possível salvar o checkpoint.")
		return

	var data: Dictionary = {
		"version": SAVE_VERSION,
		"scene_path": checkpoint_scene_path,
		"player_scene_path": checkpoint_player_scene_path,
		"checkpoint_pos": checkpoint_pos,
		"state_player": state_player.duplicate(true),
		"world_state": checkpoint_world_state.duplicate(true),
		"progress": checkpoint_progress.duplicate(true),
		"tempo_restante": tempo_restante
	}

	file.store_var(data)
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		return

	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.READ)

	if file == null:
		return

	var loaded_data: Variant = file.get_var()
	file.close()

	if not loaded_data is Dictionary:
		return

	var data: Dictionary = loaded_data

	if not data.has("scene_path"):
		return

	checkpoint_scene_path = str(
		data.get("scene_path", "")
	)

	checkpoint_player_scene_path = str(
		data.get("player_scene_path", "")
	)

	var loaded_position: Variant = data.get(
		"checkpoint_pos",
		INVALID_CHECKPOINT_POS
	)

	if loaded_position is Vector2:
		checkpoint_pos = loaded_position

	var loaded_player: Variant = data.get(
		"state_player",
		{}
	)

	if loaded_player is Dictionary:
		state_player = loaded_player.duplicate(true)

	var loaded_world: Variant = data.get(
		"world_state",
		{}
	)

	if loaded_world is Dictionary:
		checkpoint_world_state = loaded_world.duplicate(true)

	var loaded_progress: Variant = data.get(
		"progress",
		{}
	)

	if loaded_progress is Dictionary:
		checkpoint_progress = loaded_progress.duplicate(true)

	tempo_restante = float(
		data.get("tempo_restante", -1.0)
	)

	save_data = checkpoint_world_state.duplicate(true)


func create_player_from_checkpoint() -> Player:
	if checkpoint_player_scene_path.is_empty():
		push_error("Checkpoint não possui uma cena de Player salva.")
		return null

	var player_scene: PackedScene = load(
		checkpoint_player_scene_path
	) as PackedScene

	if player_scene == null:
		push_error(
			"Não foi possível carregar o Player: "
			+ checkpoint_player_scene_path
		)
		return null

	var novo_player: Player = player_scene.instantiate() as Player

	if novo_player == null:
		push_error(
			"A cena salva não possui Player como nó raiz: "
			+ checkpoint_player_scene_path
		)
		return null

	return novo_player


func capturar_tempo_atual() -> void:
	var temporizador: Node = get_tree().get_first_node_in_group(
		"temporizador_jogo"
	)

	if not is_instance_valid(temporizador):
		return

	if temporizador.has_method("get_tempo_restante"):
		tempo_atual = float(
			temporizador.call("get_tempo_restante")
		)


func create_checkpoint(player: Player) -> void:
	if player == null:
		return

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return

	checkpoint_scene_path = current_scene.scene_file_path
	checkpoint_player_scene_path = player.scene_file_path
	checkpoint_pos = player.global_position

	state_player = player.get_checkpoint_state().duplicate(true)
	checkpoint_world_state = save_data.duplicate(true)

	checkpoint_progress = {
		"job": Configs.configs.get("job", ""),
		"character": Configs.configs.get("character", ""),
		"difficulty": Configs.configs.get("difficulty", "")
	}

	capturar_tempo_atual()
	tempo_restante = tempo_atual

	_save()


func _save_state_game(body: Node2D) -> void:
	if body is Player:
		create_checkpoint(body as Player)


func has_checkpoint() -> bool:
	return (
		not checkpoint_scene_path.is_empty()
		and checkpoint_pos != INVALID_CHECKPOINT_POS
		and not state_player.is_empty()
	)


func load_last_checkpoint() -> bool:
	if not has_checkpoint():
		return false

	save_data = checkpoint_world_state.duplicate(true)

	_restore_progress_config()

	# Descarta o tempo atual e recupera o tempo do checkpoint.
	tempo_atual = tempo_restante
	restore_checkpoint_pending = true

	scene_manager.player = null
	scene_manager.last_scene_name = ""

	var erro: Error = get_tree().change_scene_to_file(
		checkpoint_scene_path
	)

	if erro != OK:
		restore_checkpoint_pending = false
		push_error(
			"Não foi possível carregar a cena do checkpoint: "
			+ checkpoint_scene_path
		)
		return false

	return true


func apply_pending_checkpoint(player: Player) -> bool:
	if not restore_checkpoint_pending:
		return false

	if player == null:
		return false

	player.global_position = checkpoint_pos
	player.load_checkpoint_state(state_player.duplicate(true))

	restaurar_tempo_checkpoint()

	restore_checkpoint_pending = false
	return true


func restaurar_tempo_checkpoint() -> void:
	if tempo_restante < 0.0:
		return

	tempo_atual = tempo_restante

	var temporizador: Node = get_tree().get_first_node_in_group(
		"temporizador_jogo"
	)

	if not is_instance_valid(temporizador):
		push_warning(
			"Temporizador não encontrado ao carregar o checkpoint."
		)
		return

	if temporizador.has_method("carregar_tempo_restante"):
		temporizador.call(
			"carregar_tempo_restante",
			tempo_restante
		)


func _restore_progress_config() -> void:
	if checkpoint_progress.has("job"):
		Configs.configs["job"] = checkpoint_progress["job"]

	if checkpoint_progress.has("character"):
		Configs.configs["character"] = checkpoint_progress["character"]

	if checkpoint_progress.has("difficulty"):
		Configs.configs["difficulty"] = checkpoint_progress["difficulty"]


func save_object_state(object_id: String, state: Variant) -> void:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return

	var scene_path: String = current_scene.scene_file_path

	if scene_path.is_empty():
		return

	if not save_data.has(scene_path):
		save_data[scene_path] = {}

	save_data[scene_path][object_id] = state


func load_object_state(object_id: String) -> Variant:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return null

	var scene_path: String = current_scene.scene_file_path

	if not save_data.has(scene_path):
		return null

	return save_data[scene_path].get(object_id, null)


func set_object_collected(object_id: String) -> void:
	save_object_state(object_id, true)


func is_object_collected(object_id: String) -> bool:
	return load_object_state(object_id) == true


func clear_save() -> void:
	save_data.clear()
	checkpoint_world_state.clear()
	state_player.clear()
	checkpoint_progress.clear()

	checkpoint_scene_path = ""
	checkpoint_player_scene_path = ""
	checkpoint_pos = INVALID_CHECKPOINT_POS
	restore_checkpoint_pending = false

	tempo_restante = -1.0
	tempo_atual = -1.0

	scene_manager.player = null
	scene_manager.last_scene_name = ""

	if FileAccess.file_exists(FILE_PATH):
		var absolute_path: String = ProjectSettings.globalize_path(
			FILE_PATH
		)

		DirAccess.remove_absolute(absolute_path)

	Configs.configs["job"] = ""
	Configs.configs["character"] = ""
	Configs.configs["difficulty"] = ""

	SaveLoad.save_data = Configs.configs.duplicate(true)
	SaveLoad._save()


func reset_progress() -> void:
	clear_save()

	get_tree().paused = false
	get_tree().change_scene_to_file(
		CHARACTER_SELECTION_SCENE
	)
