class_name NPCPath
extends Line2D

signal start_requested(path)

enum MovementType {
	WALK,
	RUN
}

@export_category("Path Settings")

@export var movement_type: MovementType = MovementType.WALK
@export var loop_path: bool = false
@export var random_at_end: bool = true
@export var delete_npc_at_end: bool = false
@export var start_automatically: bool = false
@export var hide_in_game: bool = true


func _ready() -> void:
	if hide_in_game:
		visible = false


func start_path() -> void:
	start_requested.emit(self)
