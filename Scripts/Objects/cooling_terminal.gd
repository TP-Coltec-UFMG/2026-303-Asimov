extends Node2D

@onready var interaction: Area2D = $Interectable


func _ready() -> void:
	interaction.interact = _start_cooling_puzzle
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var state := SaveGame.office_mission_state(scene_manager.player)
	interaction.is_interactable = (
		bool(state.get("cooling_optional_task_active", false))
		and not bool(state.get("cooling_optional_task_completed", false))
	)


func _start_cooling_puzzle() -> void:
	if not interaction.is_interactable:
		return
	Progresso.iniciar_refrigeracao_ia(scene_manager.player)
