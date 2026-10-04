
extends "res://Objects/scripts/item_coletavel.gd"


@onready var ligando: AudioStreamPlayer2D = $ligando
@onready var luz: PointLight2D = $Luz
@onready var interectable: Area2D = $Interectable
@onready var point_light_2d: PointLight2D = $PointLight2D

var lanterna_acessa: bool = false
var no_chao: bool = true

var ultima_animacao: StringName = &""
var ultimo_frame: int = -1
var ultima_direcao: Vector2 = Vector2.ZERO
var offset_luz: Vector2 = Vector2.ZERO
var angulo_base: float = 0.0

const LIMITE_LANTERNA: float = 45.0

func _init() -> void:
	save_id = "lanterna"


func _ready() -> void:
	if restaurar_coleta():
		return
	luz.visible = false
	point_light_2d.visible = false
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if jogador == null or not (jogador.usando_lanterna or jogador.usando_arma) or not lanterna_acessa:
		set_physics_process(false)
		return

	atualizar_posicao_luz()

func definir_jogador(novo_jogador: Player) -> void:
	jogador = novo_jogador
	no_chao = false

func definir_luz(ligada: bool) -> void:
	lanterna_acessa = ligada
	luz.visible = ligada
	point_light_2d.visible = ligada
	set_physics_process(ligada)
	if ligada:
		ultima_animacao = &""
		ultimo_frame = -1
		ultima_direcao = Vector2.ZERO
		atualizar_posicao_luz()

func alternar_luz() -> void:
	ligando.play()
	definir_luz(not lanterna_acessa)

func atualizar_posicao_luz() -> void:
	if jogador == null:
		return

	var animation: StringName = jogador.animation_player.current_animation
	var animation_frame: int = jogador.sprite.frame
	var direcao: Vector2 = jogador.cardinal_direction

	if animation != ultima_animacao or animation_frame != ultimo_frame or direcao != ultima_direcao:
		atualizar_configuracao_luz(animation, animation_frame, direcao)
		ultima_animacao = animation
		ultimo_frame = animation_frame
		ultima_direcao = direcao

	luz.global_position = jogador.global_position + offset_luz

	var mouse_position: Vector2 = get_global_mouse_position()

	if luz.global_position.distance_squared_to(mouse_position) < 0.001:
		luz.rotation_degrees = angulo_base
		return

	luz.look_at(mouse_position)
	luz.rotation_degrees -= 90.0

	var diferenca: float = wrapf(luz.rotation_degrees - angulo_base, -180.0, 180.0)
	diferenca = clampf(diferenca, -LIMITE_LANTERNA, LIMITE_LANTERNA)

	luz.rotation_degrees = angulo_base + diferenca

func atualizar_configuracao_luz(animation: StringName, animation_frame: int, direcao: Vector2) -> void:
	match animation:
		&"walk_down":
			offset_luz = Vector2(-6.0, 4.0)
			angulo_base = 0.0

			if animation_frame == 66:
				offset_luz = Vector2(-5.0, 5.0)
			elif animation_frame == 67:
				offset_luz = Vector2(-4.0, 6.0)
			elif animation_frame == 68:
				offset_luz = Vector2(-4.5, 6.5)
			elif animation_frame == 69 or animation_frame == 70:
				offset_luz = Vector2(-7.0, 2.0)

		&"idle_down":
			offset_luz = Vector2(-6.0, 4.0)
			angulo_base = 0.0

			if animation_frame == 45:
				offset_luz = Vector2(-7.0, 3.0)

		&"walk_up":
			offset_luz = Vector2(6.0, -14.0)
			angulo_base = 180.0

			if animation_frame == 54:
				offset_luz = Vector2(6.0, -16.0)
			elif animation_frame == 55:
				offset_luz = Vector2(6.0, -17.0)
			elif animation_frame == 56:
				offset_luz = Vector2(6.0, -15.0)
			elif animation_frame == 57 or animation_frame == 58:
				offset_luz = Vector2(7.0, -15.0)

		&"idle_up":
			offset_luz = Vector2(6.0, -14.0)
			angulo_base = 180.0

			if animation_frame == 33:
				offset_luz = Vector2(6.0, -15.0)

		&"walk_side":
			if direcao == Vector2.LEFT:
				offset_luz = Vector2(-4.0, 1.0)
				angulo_base = 90.0
			else:
				offset_luz = Vector2(4.0, 1.0)
				angulo_base = -90.0

			if animation_frame == 48:
				offset_luz = Vector2(-3.5 if direcao == Vector2.LEFT else 3.5, 1.0)
			elif animation_frame == 49:
				offset_luz = Vector2(-3.5 if direcao == Vector2.LEFT else 3.5, 0.5)
			elif animation_frame == 50:
				offset_luz = Vector2(-4.0 if direcao == Vector2.LEFT else 4.0, 1.0)
			elif animation_frame == 51:
				offset_luz = Vector2(-4.5 if direcao == Vector2.LEFT else 4.5, 0.5)
			elif animation_frame == 52:
				offset_luz = Vector2(-5.0 if direcao == Vector2.LEFT else 5.0, 0.0)
			elif animation_frame == 53:
				offset_luz = Vector2(-4.0 if direcao == Vector2.LEFT else 4.0, 1.0)

		&"idle_side":
			if direcao == Vector2.LEFT:
				offset_luz = Vector2(-4.0, 1.0)
				angulo_base = 90.0
			else:
				offset_luz = Vector2(4.0, 1.0)
				angulo_base = -90.0

			if animation_frame == 27:
				offset_luz = Vector2(-4.0 if direcao == Vector2.LEFT else 4.0, 0.0)

func _input(event: InputEvent) -> void:
	if no_chao:
		return

	if jogador == null:
		return

	if not jogador.usando_lanterna and not jogador.usando_arma:
		return

	if event.is_action_pressed("acende_lanterna"):
		if jogador.usando_arma and event.is_action_pressed("fire"):
			return
		alternar_luz()
