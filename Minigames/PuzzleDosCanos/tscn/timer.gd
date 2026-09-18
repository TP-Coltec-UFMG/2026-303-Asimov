extends Timer

@onready var label: Label = $Label


func _process(_delta: float) -> void:
	var tempo_restante := int(ceil(time_left))
	@warning_ignore("integer_division")
	var minutos := tempo_restante / 60
	var segundos := tempo_restante % 60

	label.text = "%02d:%02d" % [minutos, segundos]
