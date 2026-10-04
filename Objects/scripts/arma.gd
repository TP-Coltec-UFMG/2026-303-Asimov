extends "res://Objects/scripts/item_coletavel.gd"


@onready var posicao_no_jogador: Sprite2D = $Position_on_player
@onready var origem_projetil: Marker2D = $Position_on_player/BulletSpawn
@onready var intervalo_tiros: Timer = $Timer
@onready var reticula: Sprite2D = $reticula
@onready var som_tiro: AudioStreamPlayer2D = $ShotSfx
@onready var temporizador_recarga: Timer = $TemporizadorRecarga
@onready var som_sem_municao: AudioStreamPlayer = $EmptySfx
@onready var som_recarga: AudioStreamPlayer = $ReloadSfx

const CENA_PROJETIL = preload("res://Objects/bullet.tscn")
const CENA_DISPARO = preload("res://Objects/gun_muzzle_effect.tscn")
const CENA_ESTOJO = preload("res://Objects/gun_casing.tscn")
const TAMANHO_PENTE: int = 7
const RESERVA_INICIAL: int = 7
const LIMITE_RESERVA: int = 28
const ALCANCE_ASSISTENCIA: float = 260.0
const CONE_ASSISTENCIA: float = 0.24

var municao_atual: int = TAMANHO_PENTE
var municao_reserva: int = RESERVA_INICIAL
var recarregando: bool = false
var mira_assistida_travada: bool = false
var reticula_ativa: bool = false
var modo_mouse_anterior: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _init() -> void:
	save_id = "arma"


func _ready() -> void:
	if not no_inventario:
		if (
			SaveGame.is_object_collected(save_id)
			or SaveGame.load_global_state("player_starting_gun") == true
		):
			queue_free()
			return
			
	reticula.hide()
	set_process(false)


func _exit_tree() -> void:
	_definir_reticula_ativa(false)


func definir_jogador(novo_jogador: Player) -> void:
	jogador = novo_jogador
	set_process(true)
	atualizar_painel_arma()


func atualizar_painel_arma() -> void:
	if is_instance_valid(jogador):
		jogador.update_weapon_hud(municao_atual, TAMANHO_PENTE, municao_reserva, recarregando)


func get_checkpoint_state() -> Dictionary:
	return {
		"current_ammo": municao_atual,
		"reserve_ammo": municao_reserva
	}


func load_checkpoint_state(estado: Dictionary) -> void:
	municao_atual = clampi(int(estado.get("current_ammo", TAMANHO_PENTE)), 0, TAMANHO_PENTE)
	municao_reserva = clampi(int(estado.get("reserve_ammo", RESERVA_INICIAL)), 0, LIMITE_RESERVA)
	recarregando = false
	temporizador_recarga.stop()
	atualizar_painel_arma()


func adicionar_municao(quantidade: int) -> int:
	if quantidade <= 0:
		return 0
	var reserva_anterior := municao_reserva
	municao_reserva = mini(LIMITE_RESERVA, municao_reserva + quantidade)
	atualizar_painel_arma()
	return municao_reserva - reserva_anterior


func _process(_delta: float) -> void:
	if not is_instance_valid(jogador):
		_definir_reticula_ativa(false)
		return
	var arma_ativa: bool = (
		bool(jogador.usando_arma)
		and bool(jogador.is_physics_processing())
		and not bool(get_tree().paused)
		and not bool(DialogManager.is_showing_dialog)
	)
	_definir_reticula_ativa(arma_ativa)
	if not arma_ativa:
		return
	if Input.is_action_just_pressed("reload") and jogador.usando_arma:
		_iniciar_recarga()
	var alvo_mouse := jogador.get_global_mouse_position()
	var posicao_arma := jogador.global_position + posicao_no_jogador.position
	var alvo_assistido := _obter_alvo_assistido(posicao_arma, alvo_mouse)
	reticula.global_position = alvo_assistido
	reticula.self_modulate = Color(0.45, 1.0, 0.55, 1.0) if mira_assistida_travada else Color.WHITE
	reticula.scale = Vector2.ONE * (0.21 if mira_assistida_travada else 0.18)
	var direcao_arma := alvo_assistido - posicao_arma
	if direcao_arma.length_squared() <= 0.01:
		return
	direcao_arma = direcao_arma.normalized()
	var angulo_mira := direcao_arma.angle()
	var posicao_tiro := posicao_arma + origem_projetil.position.rotated(angulo_mira)
	var direcao_mira := alvo_assistido - posicao_tiro
	if direcao_mira.length_squared() <= 0.01:
		return
	direcao_mira = direcao_mira.normalized()
	posicao_no_jogador.rotation = direcao_mira.angle()
	posicao_tiro = posicao_arma + origem_projetil.position.rotated(posicao_no_jogador.rotation)
	if (
		Input.is_action_just_pressed("fire")
		and jogador.usando_arma
		and intervalo_tiros.is_stopped()
		and not recarregando
	):
		if municao_atual <= 0:
			som_sem_municao.play()
			atualizar_painel_arma()
			return
		municao_atual -= 1
		var projetil = CENA_PROJETIL.instantiate()
		get_tree().current_scene.add_child(projetil)
		projetil.global_position = posicao_tiro
		projetil.configurar(direcao_mira, jogador)
		projetil.show()
		_criar_efeitos_tiro(direcao_mira, posicao_tiro)
		_reproduzir_tiro()
		intervalo_tiros.start()
		atualizar_painel_arma()


func _obter_alvo_assistido(origem: Vector2, alvo_mouse: Vector2) -> Vector2:
	mira_assistida_travada = false
	if not bool(Configs.configs.get("assistencia_mira", false)):
		return alvo_mouse
	var direcao_mouse := alvo_mouse - origem
	if direcao_mouse.length_squared() <= 0.01:
		return alvo_mouse
	direcao_mouse = direcao_mouse.normalized()
	var melhor_alvo := alvo_mouse
	var melhor_pontuacao := INF
	for candidato: Node in get_tree().get_nodes_in_group(&"security_drones"):
		var drone := candidato as Node2D
		if drone == null or not drone.is_visible_in_tree() or bool(drone.get("destruido")):
			continue
		var posicao_tela := get_viewport().get_canvas_transform() * drone.global_position
		if not get_viewport_rect().grow(8.0).has_point(posicao_tela):
			continue
		var direcao_drone := drone.global_position - origem
		var distancia := direcao_drone.length()
		if distancia <= 0.01 or distancia > ALCANCE_ASSISTENCIA:
			continue
		var angulo := absf(direcao_mouse.angle_to(direcao_drone / distancia))
		if angulo > CONE_ASSISTENCIA:
			continue
		var pontuacao := angulo * 4.0 + distancia / ALCANCE_ASSISTENCIA
		if pontuacao < melhor_pontuacao:
			melhor_pontuacao = pontuacao
			melhor_alvo = drone.global_position
	mira_assistida_travada = melhor_pontuacao < INF
	return melhor_alvo


func _definir_reticula_ativa(ativa: bool) -> void:
	if ativa:
		if not reticula_ativa:
			modo_mouse_anterior = Input.mouse_mode
		reticula_ativa = true
		reticula.show()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		return
	if not reticula_ativa:
		reticula.hide()
		return
	reticula_ativa = false
	reticula.hide()
	Input.mouse_mode = modo_mouse_anterior


func _iniciar_recarga() -> void:
	if recarregando or municao_atual >= TAMANHO_PENTE or municao_reserva <= 0:
		if municao_atual <= 0 and municao_reserva <= 0:
			som_sem_municao.play()
		return
	recarregando = true
	som_recarga.play()
	atualizar_painel_arma()
	temporizador_recarga.start()


func _ao_terminar_recarga() -> void:
	if not recarregando:
		return
	var faltam := TAMANHO_PENTE - municao_atual
	var carregadas := mini(faltam, municao_reserva)
	municao_atual += carregadas
	municao_reserva -= carregadas
	recarregando = false
	atualizar_painel_arma()


func _criar_efeitos_tiro(direcao: Vector2, posicao_tiro: Vector2) -> void:
	var cena := get_tree().current_scene
	if cena == null or not is_instance_valid(jogador):
		return
	var efeito_disparo := CENA_DISPARO.instantiate() as Node2D
	cena.add_child(efeito_disparo)
	efeito_disparo.global_position = posicao_tiro
	efeito_disparo.rotation = direcao.angle()
	var estojo := CENA_ESTOJO.instantiate() as Node2D
	cena.add_child(estojo)
	estojo.global_position = posicao_tiro - direcao * 3.0
	estojo.call("lancar", direcao)


func _reproduzir_tiro() -> void:
	if not is_instance_valid(jogador) or som_tiro.stream == null:
		return
	som_tiro.global_position = jogador.global_position
	som_tiro.pitch_scale = randf_range(0.97, 1.03)
	som_tiro.play()
