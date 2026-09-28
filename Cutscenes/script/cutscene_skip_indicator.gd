extends Control

@export_range(0.0, 1.0, 0.001) var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.34
	draw_circle(center, radius + 3.0, Color(0.0, 0.0, 0.0, 0.58))
	draw_arc(center, radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.28), 2.0, true)
	if progress > 0.0:
		draw_arc(
			center,
			radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			40,
			Color.WHITE,
			3.0,
			true
		)
