class_name Player extends CharacterBody2D

const STARTING_GUN := preload("res://Objects/arma.tscn")


@export var checkpoint_enabled: bool = true
@export var starting_gun_enabled: bool = true


@onready var camera_2d: Camera2D = $Camera2D
@onready var sfx_walking: AudioStreamPlayer2D = $sfx_walking
@onready var occluder_side: LightOccluder2D = $Sprite2D/OccluderSide
@onready var occluder_back: LightOccluder2D = $Sprite2D/OccluderBack
@onready var occluder_front: LightOccluder2D = $Sprite2D/OccluderFront
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var crowd_obstacle: NavigationObstacle2D = $CrowdObstacle

@onready var inteligencia: TextureProgressBar = $CanvasLayer/Control/Inteligencia
@onready var vida_1: TextureProgressBar = $CanvasLayer/Control/Vida1
@onready var vida_2: TextureProgressBar = $CanvasLayer/Control/Vida2
@onready var vida_3: TextureProgressBar = $CanvasLayer/Control/Vida3
@onready var inventory: Inventory = $Inventory

@onready var grab_left: Area2D = $GrabLeft
@onready var grab_right: Area2D = $GrabRight


@onready var control: Control = $CanvasLayer/Control
@onready var morreu: Control = $CanvasLayer/Morreu
@onready var alarm_tip: Button = $CanvasLayer/AlarmTip
@onready var ammo_panel: Panel = $CanvasLayer/AmmoPanel
@onready var ammo_label: Label = $CanvasLayer/AmmoPanel/AmmoLabel
@onready var npc_warning_layer: CanvasLayer = $NonLethalWarning
@onready var npc_warning_root: Control = $NonLethalWarning/Root
@onready var npc_warning_black: ColorRect = $NonLethalWarning/Root/BlackFade

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed: float = 40.0
var state: String = "idle"

var andando_de_costas: bool = false
var alarm_tip_tween: Tween
var npc_warning_active: bool = false
var npc_warning_previous_time_scale: float = 1.0

const MOUSE_DEAD_ZONE_SQUARED: float = 16.0

var usando_lanterna: bool = false
var usando_arma: bool = false
var usando_cartao: bool = false
var usando_laptop: bool = false
var usando_cabo: bool = false
var usando_extintor: bool = false
var empurrando: bool = false

var objeto_manipulado: ObjetoEmpurravel = null
var lado_objeto_manipulado: Vector2 = Vector2.ZERO
var drag_sfx: AudioStreamPlayer2D

class MovementAudioGuard extends Node:
	func _physics_process(_delta: float) -> void:
		var player := get_parent() as Player
		if not player.is_physics_processing() or not player.can_process() or not player.is_visible_in_tree():
			player._stop_movement_sfx()
			player.crowd_obstacle.velocity = Vector2.ZERO

var objetos_grab_left: Array[ObjetoEmpurravel] = []
var objetos_grab_right: Array[ObjetoEmpurravel] = []
var objetos_grab_up: Array[ObjetoEmpurravel] = []
var objetos_grab_down: Array[ObjetoEmpurravel] = []

var correndo: bool = false
var andando: bool = false
var cansaco: float = 0.0

const vida_total: float = 300.0
const DIFFICULTY_SETTINGS := preload("res://Scripts/Data/difficulty_settings.gd")

var tempo_sem_tomar_dano: float = 0.0
var progresso_regeneracao_vida: float = 0.0
var atraso_regeneracao_vida: float = 20.0
var regeneracao_vida_por_segundo: float = 0.5

const VELOCIDADE_NORMAL: float = 40.0
const VELOCIDADE_CORRIDA: float = 80.0

const CONSUMO_CANSACO: float = 0.06
const RECUPERACAO_CANSACO: float = 0.05
@onready var balao_de_pensamento: Sprite2D = $BalaoDePensamento

signal jogador_morreu

func _ready() -> void:
	atraso_regeneracao_vida = DIFFICULTY_SETTINGS.health_regeneration_delay()
	regeneracao_vida_por_segundo = DIFFICULTY_SETTINGS.health_regeneration_per_second()
	add_to_group("player")
	drag_sfx = AudioStreamPlayer2D.new()
	drag_sfx.name = "DraggingSound"
	drag_sfx.bus = &"sfx"
	drag_sfx.volume_db = -7.0
	drag_sfx.max_distance = 350.0
	add_child(drag_sfx)
	var audio_guard := MovementAudioGuard.new()
	audio_guard.name = "MovementAudioGuard"
	audio_guard.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio_guard)
	UpdateAnimation()
	UpdateOccluderLight()
	call_deferred("_ensure_starting_gun")


func _stop_movement_sfx() -> void:
	if is_instance_valid(sfx_walking):
		sfx_walking.stop()
	if is_instance_valid(drag_sfx):
		drag_sfx.stop()


func _exit_tree() -> void:
	_stop_movement_sfx()
	if npc_warning_active:
		Engine.time_scale = npc_warning_previous_time_scale


func _ensure_starting_gun() -> void:
	if not starting_gun_enabled:
		return
	if not is_instance_valid(inventory):
		return
	if not inventory.get_item_on_inventary("gun"):
		inventory.add_item("gun", STARTING_GUN)
	SaveGame.save_global_state("player_starting_gun", true)
	var inventory_gun := inventory.get_item_control("gun")
	for candidate: Node in get_tree().get_nodes_in_group(&"gun_pickup"):
		if candidate != inventory_gun and not bool(candidate.get("no_inventario")):
			candidate.queue_free()


func update_weapon_hud(current_ammo: int, magazine_size: int, reserve_ammo: int, reloading: bool) -> void:
	ammo_panel.visible = usando_arma
	if not usando_arma:
		return
	if reloading:
		ammo_label.text = "RECARREGANDO...  %d" % reserve_ammo
	else:
		ammo_label.text = "%d / %d  |  RESERVA %d" % [current_ammo, magazine_size, reserve_ammo]


func show_ammo_pickup(amount: int) -> void:
	_show_alarm_status("Munição +%d" % amount)


func show_protected_npc_warning() -> void:
	_show_restart_warning("NÃO SERÁ PERMITIDO CAUSAR DANO EM OUTROS NPCS.")


func show_hall_extinguisher_failure() -> void:
	_show_restart_warning("OS EXTINTORES ACABARAM. TODOS FICARAM PRESOS...", true)


func _show_restart_warning(message: String, restart_from_beginning: bool = false) -> void:
	if npc_warning_active or not is_inside_tree():
		return
	ContextualTutorial.cancelar_atual()
	npc_warning_active = true
	npc_warning_previous_time_scale = Engine.time_scale
	Engine.time_scale = maxf(0.05, npc_warning_previous_time_scale * 0.22)
	npc_warning_layer.show()
	npc_warning_root.modulate.a = 0.0
	npc_warning_black.color.a = 0.0
	var warning_label := $NonLethalWarning/Root/MessagePanel/Label as Label
	warning_label.text = message
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(message)
	if restart_from_beginning:
		direction = Vector2.ZERO
		velocity = Vector2.ZERO
		correndo = false
		set_physics_process(false)
		set_process_input(false)
		_stop_movement_sfx()
	var fade_in := create_tween()
	fade_in.set_ignore_time_scale(true)
	fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(npc_warning_root, "modulate:a", 1.0, 0.35)
	await fade_in.finished
	await get_tree().create_timer(1.05, true, false, true).timeout
	var fade_to_black := create_tween()
	fade_to_black.set_ignore_time_scale(true)
	fade_to_black.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_to_black.tween_property(npc_warning_black, "color:a", 1.0, 0.8)
	await fade_to_black.finished
	Engine.time_scale = npc_warning_previous_time_scale
	npc_warning_active = false
	if restart_from_beginning:
		SaveGame.restart_from_hall()
		return
	if SaveGame.load_last_checkpoint():
		return
	var recovery := create_tween()
	recovery.set_ignore_time_scale(true)
	recovery.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	recovery.tween_property(npc_warning_root, "modulate:a", 0.0, 0.3)
	await recovery.finished
	npc_warning_layer.hide()
	npc_warning_black.color.a = 0.0


func _toggle_alarm_from_player() -> bool:
	if not MusicController.toggle_alarm_by_player():
		return false
	if MusicController.alarm_user_muted:
		balao_de_pensamento.enfileirar_dialogo("alarm.disabled_by_player", "alarm:disabled_by_player")
		_show_alarm_status("Alarme desativado")
	else:
		_show_alarm_status("Alarme ativado")
	return true


func _show_alarm_status(message: String) -> void:
	if alarm_tip_tween != null and alarm_tip_tween.is_valid():
		alarm_tip_tween.kill()
	alarm_tip.text = message
	alarm_tip.modulate.a = 1.0
	alarm_tip.show()
	alarm_tip_tween = create_tween()
	alarm_tip_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	alarm_tip_tween.tween_interval(0.35)
	alarm_tip_tween.tween_callback(alarm_tip.hide)
	alarm_tip_tween.tween_interval(0.16)
	alarm_tip_tween.tween_callback(alarm_tip.show)
	alarm_tip_tween.tween_interval(0.28)
	alarm_tip_tween.tween_callback(alarm_tip.hide)
	alarm_tip_tween.tween_interval(0.16)
	alarm_tip_tween.tween_callback(alarm_tip.show)
	alarm_tip_tween.tween_interval(1.0)
	alarm_tip_tween.tween_property(alarm_tip, "modulate:a", 0.0, 0.3)
	alarm_tip_tween.tween_callback(_hide_alarm_status)


func show_alarm_hint() -> void:
	if MusicController.alarm_user_muted:
		return
	if alarm_tip_tween != null and alarm_tip_tween.is_valid():
		alarm_tip_tween.kill()
	alarm_tip.text = "Aperte P para desligar o alarme"
	alarm_tip.modulate.a = 1.0
	alarm_tip.show()
	alarm_tip_tween = create_tween()
	alarm_tip_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	alarm_tip_tween.tween_interval(8.0)
	alarm_tip_tween.tween_property(alarm_tip, "modulate:a", 0.0, 0.3)
	alarm_tip_tween.tween_callback(_hide_alarm_status)


func _hide_alarm_status() -> void:
	alarm_tip.hide()
	alarm_tip.modulate.a = 1.0
	alarm_tip_tween = null
	
func _mostrar_no_balao_de_pensamento(texto: String) -> void:
	await balao_de_pensamento.mostrar_texto(texto)

func get_checkpoint_state() -> Dictionary:
	return {
		"cansaco": cansaco,
		"cardinal_direction": cardinal_direction,
		"inteligencia": inteligencia.value,
		"vida_1": vida_1.value,
		"vida_2": vida_2.value,
		"vida_3": vida_3.value,
		"inventario": inventory.get_save_state(),
		"pensamentos": balao_de_pensamento.get_checkpoint_state()
	}

func load_checkpoint_state(checkpoint_state: Dictionary) -> void:
	cansaco = checkpoint_state.get(
		"cansaco",
		cansaco
	)

	cardinal_direction = checkpoint_state.get(
		"cardinal_direction",
		cardinal_direction
	)

	inteligencia.value = checkpoint_state.get(
		"inteligencia",
		inteligencia.value
	)

	vida_1.value = checkpoint_state.get(
		"vida_1",
		vida_1.value
	)

	vida_2.value = checkpoint_state.get(
		"vida_2",
		vida_2.value
	)

	vida_3.value = checkpoint_state.get(
		"vida_3",
		vida_3.value
	)

	var inventario_salvo: Variant = checkpoint_state.get(
		"inventario",
		{}
	)

	if inventario_salvo is Dictionary:
		inventory.load_save_state(inventario_salvo)

	var pensamentos_salvos: Variant = checkpoint_state.get("pensamentos", {})
	balao_de_pensamento.load_checkpoint_state(
		pensamentos_salvos if pensamentos_salvos is Dictionary else {}
	)

	direction = Vector2.ZERO
	velocity = Vector2.ZERO
	crowd_obstacle.velocity = Vector2.ZERO
	state = "idle"

	correndo = false
	andando = false
	andando_de_costas = false
	tempo_sem_tomar_dano = 0.0
	progresso_regeneracao_vida = 0.0

	move_speed = VELOCIDADE_NORMAL

	usando_lanterna = false
	usando_arma = false
	usando_cartao = false
	usando_laptop = false
	usando_cabo = false
	usando_extintor = false
	inventory.set_equipped_item("")

	empurrando = false
	if is_instance_valid(objeto_manipulado):
		objeto_manipulado.set_manipulated_outline(false)
	objeto_manipulado = null
	lado_objeto_manipulado = Vector2.ZERO
	_stop_movement_sfx()

	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	occluder_side.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1

	UpdateAnimation()
	UpdateOccluderLight()

func _physics_process(delta: float) -> void:
	_atualizar_regeneracao_vida(delta)
	if DialogManager.is_showing_dialog:
		direction = Vector2.ZERO
		velocity = Vector2.ZERO
		correndo = false
		move_speed = VELOCIDADE_NORMAL
		if state != "idle":
			state = "idle"
			UpdateAnimation()
		_stop_movement_sfx()
		crowd_obstacle.velocity = Vector2.ZERO
		return

	direction = Input.get_vector("left", "right", "up", "down")
	
	var mudou_estado: bool = SetState()
	var mudou_direcao: bool = SetDirection()
	var mudou_sentido_animacao: bool = SetWalkingBackwards()
	var correndo_antes: bool = correndo
	var animacao_corrida_rapida_antes: bool = correndo and cansaco <= 0.5
	atualizar_corrida(delta)
	var animacao_corrida_rapida_agora: bool = correndo and cansaco <= 0.5
	velocity = direction * move_speed
	
	if mudou_estado or mudou_direcao or mudou_sentido_animacao or correndo != correndo_antes or animacao_corrida_rapida_antes != animacao_corrida_rapida_agora:
		UpdateAnimation()
	
	if mudou_direcao:
		UpdateOccluderLight()
		if empurrando and objeto_manipulado == null:
			tentar_pegar_objeto()
	
	var posicao_antes := global_position
	if objeto_manipulado != null:
		_physics_manipulando(delta)
	else:
		move_and_slide()
	crowd_obstacle.velocity = (global_position - posicao_antes) / delta
	_update_walking_sfx(global_position.distance_squared_to(posicao_antes) > 0.000001)

func atualizar_corrida(delta: float) -> void:
	if Input.is_action_pressed("correr") and state != "idle" and objeto_manipulado == null and cansaco < 1.0:
		correndo = true
		andando = false
		move_speed = VELOCIDADE_CORRIDA - float(int(40.0 * cansaco))
		cansaco += CONSUMO_CANSACO * delta
		cansaco = minf(cansaco, 1.0)
	else:
		correndo = false
		move_speed = VELOCIDADE_NORMAL
		var cansaco_minimo: float = 1.0 - (get_vida() / vida_total)
		if cansaco > cansaco_minimo:
			cansaco -= RECUPERACAO_CANSACO * delta
			cansaco = maxf(cansaco, cansaco_minimo)

func _update_walking_sfx(moved: bool = false) -> void:
	var esta_andando: bool = moved and direction.length_squared() > 0.0
	if esta_andando:
		if not sfx_walking.playing:
			sfx_walking.play()
		var novo_pitch: float = 1.0
		if move_speed > VELOCIDADE_NORMAL:
			novo_pitch = lerpf(1.0, 1.8, clampf(move_speed / VELOCIDADE_CORRIDA, 0.0, 1.0))
		if not is_equal_approx(sfx_walking.pitch_scale, novo_pitch):
			sfx_walking.pitch_scale = novo_pitch
	elif sfx_walking.playing:
		sfx_walking.stop()

func tentar_pegar_objeto() -> void:
	if objeto_manipulado != null:
		return
	var candidates := _grab_candidates(cardinal_direction)
	for i in range(candidates.size() - 1, -1, -1):
		var objeto: ObjetoEmpurravel = candidates[i]
		if not is_instance_valid(objeto):
			candidates.remove_at(i)
			continue
		pegar_objeto(objeto, cardinal_direction)
		return


func _grab_candidates(lado: Vector2) -> Array[ObjetoEmpurravel]:
	match lado:
		Vector2.LEFT:
			return objetos_grab_left
		Vector2.UP:
			return objetos_grab_up
		Vector2.DOWN:
			return objetos_grab_down
	return objetos_grab_right


func has_grab_object_nearby() -> bool:
	return not objetos_grab_left.is_empty() or not objetos_grab_right.is_empty() or not objetos_grab_up.is_empty() or not objetos_grab_down.is_empty()

func pegar_objeto(objeto: ObjetoEmpurravel, lado: Vector2) -> void:
	if objeto_manipulado != null:
		return
	
	if not is_instance_valid(objeto):
		return
	
	objeto_manipulado = objeto
	objeto_manipulado.set_manipulated_outline(true)
	lado_objeto_manipulado = lado
	cardinal_direction = lado
	add_collision_exception_with(objeto_manipulado)
	objeto_manipulado.add_collision_exception_with(self)
	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	occluder_side.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	UpdateAnimation()
	UpdateOccluderLight()

func soltar_objeto() -> void:
	if objeto_manipulado != null and is_instance_valid(objeto_manipulado):
		objeto_manipulado.set_manipulated_outline(false)
		remove_collision_exception_with(objeto_manipulado)
		objeto_manipulado.remove_collision_exception_with(self)

	if checkpoint_enabled:
		SaveGame.create_checkpoint(self)
	
	objeto_manipulado = null
	lado_objeto_manipulado = Vector2.ZERO
	if is_instance_valid(drag_sfx):
		drag_sfx.stop()

func _physics_manipulando(delta: float) -> void:
	if objeto_manipulado == null:
		return
	
	if not is_instance_valid(objeto_manipulado):
		soltar_objeto()
		return
	
	var movimento: Vector2 = direction * move_speed * delta
	
	if movimento.is_zero_approx():
		if drag_sfx.playing:
			drag_sfx.stop()
		return
	
	mover_com_objeto(movimento)

func mover_com_objeto(movimento: Vector2) -> void:
	if objeto_manipulado == null:
		return
	
	var player_bloqueado: bool = test_move(global_transform, movimento)
	var objeto_bloqueado: bool = objeto_manipulado.test_move(objeto_manipulado.global_transform, movimento)
	
	if not player_bloqueado and not objeto_bloqueado:
		move_and_collide(movimento)
		objeto_manipulado.move_and_collide(movimento)
		if not drag_sfx.playing:

			drag_sfx.stream = GameAudio.SCRAPES[randi_range(0, 1)]
			drag_sfx.play()
	elif drag_sfx.playing:
		drag_sfx.stop()

func _on_grab_body_entered(body: Node2D, lado: Vector2) -> void:
	if not body is ObjetoEmpurravel:
		return
		
	var objeto: ObjetoEmpurravel = body as ObjetoEmpurravel
	var candidates := _grab_candidates(lado)
	if not objeto in candidates:
		candidates.append(objeto)
		
	if empurrando and objeto_manipulado == null and cardinal_direction == lado:
		pegar_objeto(objeto, lado)

func _on_grab_body_exited(body: Node2D, lado: Vector2) -> void:
	if not body is ObjetoEmpurravel:
		return
		
	var objeto: ObjetoEmpurravel = body as ObjetoEmpurravel
	_grab_candidates(lado).erase(objeto)

func usando_item_com_mira() -> bool:
	return usando_lanterna or usando_arma or usando_extintor

func GetMouseCardinalDirection() -> Vector2:
	var mouse_offset: Vector2 = get_global_mouse_position() - global_position
	if mouse_offset.length_squared() < MOUSE_DEAD_ZONE_SQUARED:
		return cardinal_direction
	if abs(mouse_offset.x) > abs(mouse_offset.y):
		return Vector2.LEFT if mouse_offset.x < 0.0 else Vector2.RIGHT
	return Vector2.UP if mouse_offset.y < 0.0 else Vector2.DOWN

func SetDirection() -> bool:
	if objeto_manipulado != null:
		return false
		
	var new_direction: Vector2 = cardinal_direction
	
	if usando_item_com_mira():
		new_direction = GetMouseCardinalDirection()
	else:
		if direction == Vector2.ZERO:
			return false
		if direction.y == 0.0:
			new_direction = Vector2.LEFT if direction.x < 0.0 else Vector2.RIGHT
		elif direction.x == 0.0:
			new_direction = Vector2.UP if direction.y < 0.0 else Vector2.DOWN
	if new_direction == cardinal_direction:
		return false
		
	cardinal_direction = new_direction
	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	occluder_side.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	return true

func SetWalkingBackwards() -> bool:
	var novo_andando_de_costas: bool = false
	if usando_item_com_mira() and direction != Vector2.ZERO:
		var movimento_normalizado: Vector2 = direction.normalized()
		var alinhamento: float = movimento_normalizado.dot(cardinal_direction)
		novo_andando_de_costas = alinhamento < -0.01
	if novo_andando_de_costas == andando_de_costas:
		return false
	andando_de_costas = novo_andando_de_costas
	return true

func SetState() -> bool:
	var new_state: String = "idle" if direction == Vector2.ZERO else "walk"
	if new_state == state:
		return false
	state = new_state
	return true

func UpdateAnimation() -> void:
	var nova_animacao: String = state + "_" + AnimDirection()
	var nova_velocidade: float = 1.0
	
	if correndo and cansaco <= 0.5:
		nova_velocidade = 2.0
		
	if not is_equal_approx(animation_player.speed_scale, nova_velocidade):
		animation_player.speed_scale = nova_velocidade
		
	var mudou_animacao: bool = animation_player.current_animation != nova_animacao
	var esta_tocando_ao_contrario: bool = animation_player.get_playing_speed() < 0.0
	var mudou_sentido: bool = esta_tocando_ao_contrario != andando_de_costas
	
	if not mudou_animacao and not mudou_sentido:
		return
	if andando_de_costas:
		animation_player.play_backwards(nova_animacao)
	else:
		animation_player.play(nova_animacao)

func UpdateOccluderLight() -> void:
	var _direction: String = AnimDirection()
	occluder_front.visible = _direction == "down"
	occluder_back.visible = _direction == "up"
	occluder_side.visible = _direction == "side"

func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"

func reset_sprite_player() -> void:
	usando_lanterna = false
	var lanterna = inventory.get_item_control("lanterna")
	if lanterna != null:
		lanterna.set_luz(false)
	var extintor = inventory.get_item_control("extintor")
	if extintor != null:
		extintor.set_fumaca(false)
	usando_arma = false
	usando_cartao = false
	usando_laptop = false
	usando_cabo = false
	usando_extintor = false
	inventory.set_equipped_item("")
	ammo_panel.hide()
	soltar_objeto()
	empurrando = false
	$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16.png")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_alarm"):
		if not event.is_echo() and _toggle_alarm_from_player():
			get_viewport().set_input_as_handled()
		return
	if DialogManager.is_showing_dialog:
		return

	if event.is_action_pressed("use_lanterna") and inventory.get_item_on_inventary("lanterna"):
		var lanterna = inventory.get_item_control("lanterna")
		lanterna.set_player(self)
		if usando_arma:
			lanterna.toggle_luz()
			get_viewport().set_input_as_handled()
			return
		if usando_lanterna:
			lanterna.set_luz(false)
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_lanterna = true
			inventory.set_equipped_item("lanterna")
			lanterna.set_luz(true)
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_lanterna16x16.png")
			
			
	if event.is_action_pressed("use_arma") and inventory.get_item_on_inventary("gun"):
		var gun = inventory.get_item_control("gun")
		gun.set_player(self)
		if usando_arma:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_arma = true
			inventory.set_equipped_item("gun")
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_arma16x16.png")
		gun.refresh_hud()
			
			
	if event.is_action_pressed("use_extintor") and inventory.get_item_on_inventary("extintor"):
		var extintor = inventory.get_item_control("extintor")
		if usando_extintor:
			extintor.set_fumaca(false)
			reset_sprite_player()
		else:
			reset_sprite_player()
			extintor.set_player(self)
			usando_extintor = true
			inventory.set_equipped_item("extintor")
			extintor.set_fumaca(false)
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16_com_extintor.png")
			
			
	if event.is_action_pressed("use_cartao") and inventory.get_item_on_inventary("cartao"):
		var cartao = inventory.get_item_control("cartao")
		cartao.set_player(self)
		if usando_cartao:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_cartao = true
			inventory.set_equipped_item("cartao")
			if cartao.tipo == 3:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_chefe16x16.png")
			elif cartao.tipo == 2:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_forte16x16.png")
			else:
				$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_cartao_padrao16x16.png")
				
				
	if event.is_action_pressed("use_laptop") and inventory.get_item_on_inventary("laptop"):
		var laptop = inventory.get_item_control("laptop")
		laptop.set_player(self)
		if usando_laptop:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_laptop = true
			inventory.set_equipped_item("laptop")
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_com_laptop16x16.png")
			
			
	if event.is_action_pressed("use_cabo") and inventory.get_item_on_inventary("cabo"):
		var cabo = inventory.get_item_control("cabo")
		cabo.set_player(self)
		if usando_cabo:
			reset_sprite_player()
		else:
			reset_sprite_player()
			usando_cabo = true
			inventory.set_equipped_item("cabo")
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16_com_cabo.png")
			
			
	if event.is_action_pressed("empurrar") and not usando_algum_item():
		if empurrando:
			soltar_objeto()
			empurrando = false
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16.png")
		else:
			empurrando = true
			tentar_pegar_objeto()
			$Sprite2D.texture = preload("res://Player/Sprites/Alex_16x16_empurrando.png")

func _on_animation_player_current_animation_changed(_name: StringName) -> void:
	pass

func put_conhecimento() -> void:
	inteligencia.value += 10

func usando_algum_item() -> bool:
	if usando_arma or usando_cartao or usando_cabo or usando_lanterna or usando_laptop or usando_extintor:
		return true
	return false

func get_conhecimento() -> float:
	return inteligencia.value

func tomar_dano(dano: float) -> void:
	if ContextualTutorial.protege_jogador(self):
		return
	if dano <= 0.0:
		return
	tempo_sem_tomar_dano = 0.0
	progresso_regeneracao_vida = 0.0
	if vida_3.value + dano <= 100:
		vida_3.value += dano
		atualizar_estamina_apos_dano()
	else:
		var dano_restante: float = vida_3.value + dano - 100.0
		vida_3.value = 100
		if vida_2.value + dano_restante <= 100:
			vida_2.value += dano_restante
			atualizar_estamina_apos_dano()
		else:
			var dano_restante_2: float = vida_2.value + dano_restante - 100.0
			vida_2.value = 100
			if vida_1.value + dano_restante_2 < 100:
				vida_1.value += dano_restante_2
				atualizar_estamina_apos_dano()
			else:
				vida_1.value = 100
				tela_morreu()

func tela_morreu() -> void:
	get_tree().paused = true
	control.hide()
	morreu.show()
	jogador_morreu.emit()

func get_vida() -> float:
	return 300.0 - (vida_1.value + vida_2.value + vida_3.value)


func _atualizar_regeneracao_vida(delta: float) -> void:
	if get_vida() >= vida_total:
		tempo_sem_tomar_dano = 0.0
		progresso_regeneracao_vida = 0.0
		return
	if morreu.visible:
		return
	tempo_sem_tomar_dano += delta
	if tempo_sem_tomar_dano < atraso_regeneracao_vida:
		return
	progresso_regeneracao_vida += regeneracao_vida_por_segundo * delta
	var quantidade_inteira := floorf(progresso_regeneracao_vida)
	if quantidade_inteira < 1.0:
		return
	_regenerar_vida(quantidade_inteira)
	progresso_regeneracao_vida -= quantidade_inteira


func _regenerar_vida(quantidade: float) -> void:
	var restante := maxf(quantidade, 0.0)
	var barras: Array[TextureProgressBar] = [vida_1, vida_2, vida_3]
	for barra in barras:
		if restante <= 0.0:
			break
		var recuperado := minf(barra.value, restante)
		barra.value -= recuperado
		restante -= recuperado

func atualizar_estamina_apos_dano() -> void:
	cansaco = 1.0 - get_vida() / vida_total
