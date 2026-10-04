extends Control

const NEXT_SCENE: String = "res://Scenes/andar_hall.tscn"
const HOLD_DURATION: float = 5.0
const OPENING_BLUR_META: StringName = &"intro_opening_blur"

@onready var video: VideoStreamPlayer = $Video
@onready var black: ColorRect = $Black
@onready var skip_indicator: Control = $SkipIndicator

var skip_allowed: bool = false
var hold_elapsed: float = 0.0
var finishing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	MusicController.pausar_todos_audios()
	skip_allowed = bool(Configs.configs.get("intro_cutscene_seen", false))
	skip_indicator.hide()
	black.visible = false
	video.finished.connect(_on_video_finished)
	video.play()


func _process(delta: float) -> void:
	if finishing or not skip_allowed:
		return
	if Input.is_key_pressed(KEY_SPACE):
		skip_indicator.show()
		hold_elapsed = minf(hold_elapsed + delta, HOLD_DURATION)
	else:
		hold_elapsed = 0.0
		skip_indicator.hide()
	skip_indicator.set("progress", hold_elapsed / HOLD_DURATION)
	if hold_elapsed >= HOLD_DURATION:
		_finish_cutscene()


func _on_video_finished() -> void:
	_finish_cutscene()


func _finish_cutscene() -> void:
	if finishing:
		return
	finishing = true
	video.stop()
	skip_indicator.hide()
	black.show()
	Configs.configs["intro_cutscene_seen"] = true
	SaveLoad.save_data = Configs.configs.duplicate(true)
	SaveLoad._save()
	get_tree().set_meta(OPENING_BLUR_META, true)
	MusicController.parar_todos_audios()
	MusicController.permitir_audio_cena()
	await get_tree().process_frame
	get_tree().change_scene_to_file(NEXT_SCENE)
