extends Node2D

@export var terminal_id: StringName = &""
@export var return_marker: StringName = &"ANDAR_DATA_CENTER"
@onready var interaction: Area2D = $Interectable

var resolved_terminal_id: String = ""


func _ready() -> void:
	resolved_terminal_id = _resolve_terminal_id()
	interaction.interact = _start_cooling_puzzle
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var state := SaveGame.office_mission_state(scene_manager.player)
	interaction.is_interactable = (
		bool(state.get("cooling_optional_task_active", false))
		and Progresso.terminal_refrigeracao_disponivel(
			state,
			resolved_terminal_id
		)
	)


func _start_cooling_puzzle() -> void:
	if not interaction.is_interactable:
		return
	GameAudio.play_world(self, GameAudio.TERMINAL_KEY, -10.0)
	Progresso.iniciar_refrigeracao_ia(
		scene_manager.player,
		resolved_terminal_id,
		String(return_marker)
	)


func _resolve_terminal_id() -> String:
	if not terminal_id.is_empty():
		return Progresso.normalizar_terminal_refrigeracao(String(terminal_id))
	var compact_name := String(name).to_lower().replace("_", "").replace(" ", "")
	if compact_name.ends_with("2"):
		return "terminal_2"
	return "terminal_1"
