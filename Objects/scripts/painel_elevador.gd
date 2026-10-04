extends Node2D

@export var scene_trigger : SceneTrigger
@onready var bt_andar_normal: Sprite2D = $BtAndarNormal
@onready var bt_andar_01_apertado: Sprite2D = $BtAndar01Apertado
@onready var bt_andar_01_selecionado: Sprite2D = $BtAndar01Selecionado
@onready var bt_andar_02_apertado: Sprite2D = $BtAndar02Apertado
@onready var bt_andar_02_selecionado: Sprite2D = $BtAndar02Selecionado
@onready var bt_andar_03_apertado: Sprite2D = $BtAndar03Apertado
@onready var bt_andar_03_selecionado: Sprite2D = $BtAndar03Selecionado
@onready var bt_andar_04_apertado: Sprite2D = $BtAndar04Apertado
@onready var bt_andar_04_selecionado: Sprite2D = $BtAndar04Selecionado
@onready var bt_andar_05_apertado: Sprite2D = $BtAndar05Apertado
@onready var bt_andar_05_selecionado: Sprite2D = $BtAndar05Selecionado
@onready var bt_andar_06_apertado: Sprite2D = $BtAndar06Apertado
@onready var bt_andar_06_selecionado: Sprite2D = $BtAndar06Selecionado
@onready var bt_andar_porta_apertado: Sprite2D = $BtAndarPortaApertado
@onready var bt_andar_porta_selecionado: Sprite2D = $BtAndarPortaSelecionado
@onready var abrindo: AnimatedSprite2D = $Abrindo
@onready var elevator_moving: AudioStreamPlayer = $ElevatorMoving

@onready var label: Label = $Label

var mission_border: Panel
var mission_border_tween: Tween
var mission_floor: int = -1
var mission_hint_enabled := true


static func mission_destination(state: Dictionary) -> int:
	if bool(state.get("data_center_power_outage", false)) and not bool(state.get("data_center_breaker_restored", false)):
		return 4 if bool(state.get("data_center_power_dialog_finished", false)) else 6
	if bool(state.get("data_center_return_task_active", false)) or bool(state.get("data_center_return_task_pending", false)):
		return 6
	if bool(state.get("office_data_center_task_active", false)) or bool(state.get("office_data_center_task_pending", false)) or bool(state.get("office_boss_card_collected", false)) or bool(state.get("data_center_card_delivered", false)):
		return 6
	if bool(state.get("elevator_third_floor_unlocked", false)):
		return 3
	return -1


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not mission_hint_enabled or scene_trigger == null:
		_clear_mission_border()
		return
	var destination := mission_destination(SaveGame.office_mission_state(scene_trigger.jogador))
	if destination == scene_trigger.andar_atual or not scene_trigger.pode_acessar_andar(destination):
		destination = -1
	if destination == mission_floor:
		return
	_clear_mission_border()
	if destination < 1:
		return
	mission_floor = destination
	var floor_button := get_node("andar%d" % destination) as Button
	mission_border = Panel.new()
	mission_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.set_border_width_all(2)
	border.border_color = Color.WHITE
	border.set_corner_radius_all(4)
	border.shadow_color = Color(1.0, 1.0, 1.0, 0.45)
	border.shadow_size = 4
	mission_border.add_theme_stylebox_override("panel", border)
	floor_button.add_child(mission_border)
	mission_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mission_border_tween = create_tween().set_loops()
	mission_border_tween.tween_property(mission_border, "modulate:a", 0.35, 0.75)
	mission_border_tween.tween_property(mission_border, "modulate:a", 1.0, 0.75)


func _clear_mission_border() -> void:
	if mission_border_tween != null and mission_border_tween.is_valid():
		mission_border_tween.kill()
	if is_instance_valid(mission_border):
		mission_border.queue_free()
	mission_border = null
	mission_floor = -1


func resetar_sprites() -> void:
	mission_hint_enabled = true
	bt_andar_01_apertado.hide()
	bt_andar_02_apertado.hide()
	bt_andar_03_apertado.hide()
	bt_andar_04_apertado.hide()
	bt_andar_05_apertado.hide()
	bt_andar_06_apertado.hide()
	bt_andar_porta_apertado.hide()
	bt_andar_01_selecionado.hide()
	bt_andar_02_selecionado.hide()
	bt_andar_03_selecionado.hide()
	bt_andar_04_selecionado.hide()
	bt_andar_05_selecionado.hide()
	bt_andar_06_selecionado.hide()
	bt_andar_porta_apertado.hide()
	abrindo.hide()
	abrindo.frame = 0
	label.hide()
	bt_andar_normal.show()
	

func animacao() -> void:
	mission_hint_enabled = false
	_clear_mission_border()
	elevator_moving.stop()
	bt_andar_normal.hide()
	abrindo.show()
	abrindo.play("default")
	await abrindo.animation_finished
	return


func iniciar_movimento() -> void:
	if not elevator_moving.playing:
		elevator_moving.play()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if elevator_moving.stream is AudioStreamOggVorbis:
		var moving_loop := elevator_moving.stream.duplicate() as AudioStreamOggVorbis
		moving_loop.loop = true
		elevator_moving.stream = moving_loop
	visible = false

func escolher_andar(andar: int) -> void:
	if not scene_trigger.pode_acessar_andar(andar):
		mostrar_andar_bloqueado()
		return
	mission_hint_enabled = false
	_clear_mission_border()
	label.text = "CARREGANDO"
	label.show()
	scene_trigger.usar_elevador(andar)


func mostrar_andar_bloqueado() -> void:
	label.text = "Ainda não"
	label.show()

func _on_andar_1_pressed() -> void:
	bt_andar_01_apertado.show()
	escolher_andar(1)
	pass

func _on_andar_2_pressed() -> void:
	bt_andar_02_apertado.show()
	escolher_andar(2)
	pass

func _on_andar_3_pressed() -> void:
	bt_andar_03_apertado.show()
	escolher_andar(3)
	pass

func _on_andar_4_pressed() -> void:
	bt_andar_04_apertado.show()
	escolher_andar(4)

func _on_andar_5_pressed() -> void:
	bt_andar_05_apertado.show()
	escolher_andar(5)
	pass

func _on_andar_6_pressed() -> void:
	bt_andar_06_apertado.show()
	escolher_andar(6)
	pass
	
func _on_fechar_pressed() -> void:
	bt_andar_porta_selecionado.show()
	escolher_andar(-2)
	pass
	


func _on_andar_1_mouse_entered() -> void:
	bt_andar_01_selecionado.show()


func _on_andar_1_mouse_exited() -> void:
	bt_andar_01_selecionado.hide()


func _on_andar_2_mouse_entered() -> void:
	bt_andar_02_selecionado.show()


func _on_andar_2_mouse_exited() -> void:
	bt_andar_02_selecionado.hide()


func _on_andar_3_mouse_entered() -> void:
	bt_andar_03_selecionado.show()


func _on_andar_3_mouse_exited() -> void:
	bt_andar_03_selecionado.hide()


func _on_andar_4_mouse_entered() -> void:
	bt_andar_04_selecionado.show()


func _on_andar_4_mouse_exited() -> void:
	bt_andar_04_selecionado.hide()


func _on_andar_5_mouse_entered() -> void:
	bt_andar_05_selecionado.show()


func _on_andar_5_mouse_exited() -> void:
	bt_andar_05_selecionado.hide()


func _on_andar_6_mouse_entered() -> void:
	bt_andar_06_selecionado.show()


func _on_andar_6_mouse_exited() -> void:
	bt_andar_06_selecionado.hide()


func _on_fechar_mouse_entered() -> void:
	bt_andar_porta_selecionado.show()


func _on_fechar_mouse_exited() -> void:
	bt_andar_porta_selecionado.hide()
