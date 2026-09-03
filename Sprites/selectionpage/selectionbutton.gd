extends TextureButton

@export var button: String = ""
var selected = false

@onready var control: Control = $"../.."


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	var label: Label = get_node_or_null("Label") as Label
	if label != null:
		accessibility_name = label.text
	accessibility_description = tr("TUTORIAL_SELECTION_DESCRIPTION")


func _on_focus_entered() -> void:
	_on_mouse_entered()
	_announce_selection()


func _on_focus_exited() -> void:
	_on_mouse_exited()


func _announce_selection() -> void:
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(accessibility_name)

func _on_mouse_entered() -> void:
	if not selected:
		scale = Vector2(1.05, 1.05)
		modulate.a = 1


func _on_mouse_exited() -> void:
	if not selected:
		self.scale = Vector2(1.0, 1.0)
		modulate.a = 0.8


func _on_pressed() -> void:
	if not selected:
		selected = true
		control.option_selected = button
		control.SELECTED()
