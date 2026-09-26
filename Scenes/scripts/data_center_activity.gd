extends Node2D

@onready var monitor_lights: Array[PointLight2D] = [
	$MonitorEsquerdo,
	$MonitorDireito
]

var elapsed: float = 0.0


func _process(delta: float) -> void:
	elapsed += delta
	# Um pulso discreto dos monitores; o controlador da queda de energia
	# ainda pode ocultar estas luzes junto das demais luzes normais.
	for index in range(monitor_lights.size()):
		var phase := elapsed * 1.35 + float(index) * 1.8
		monitor_lights[index].energy = 0.09 + 0.025 * sin(phase)
