class_name NPCPath
extends Line2D

signal solicitou_inicio(path)

enum MovementType {
	WALK,
	RUN
}

@export_category("Path Settings")

@export var tipo_movimento: MovementType = MovementType.WALK
@export var repetir_caminho: bool = false
@export var sortear_ao_terminar: bool = true
@export var remover_npc_ao_terminar: bool = false
@export var iniciar_automaticamente: bool = false
@export var ocultar_no_jogo: bool = true


func _ready() -> void:
	if ocultar_no_jogo:
		visible = false


func iniciar_caminho() -> void:
	solicitou_inicio.emit(self)
