class_name NPCPath
extends Line2D


# ============================================================
# SIGNAL
# ============================================================

signal start_requested(path: NPCPath)


# ============================================================
# MOVEMENT TYPE
# ============================================================

enum MovementType {
	WALK,
	RUN
}


# ============================================================
# CONFIGURAÇÃO
# ============================================================

@export_category("Path Settings")

# Se o NPC anda ou corre neste caminho.
@export var movement_type: MovementType = MovementType.WALK

# Se deve voltar ao início quando chegar ao final.
@export var loop_path: bool = false

# Se deve entrar no movimento desesperado ao terminar.
@export var desperate_at_end: bool = true

# Se este caminho deve começar automaticamente
# quando a cena iniciar.
@export var start_automatically: bool = false

# Esconde a Line2D durante o jogo.
@export var hide_in_game: bool = true


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	if hide_in_game:
		visible = false


# ============================================================
# COMEÇAR ESTE CAMINHO
# ============================================================

func start_path() -> void:
	start_requested.emit(self)
