extends Control

@export_range(0.0, 1.0, 0.001) var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.36
	draw_circle(center, radius + 8.0, Color(0.0, 0.0, 0.0, 0.72))
	draw_arc(center, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.3), 5.0, true)
	if progress > 0.0:
		draw_arc(
			center,
			radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * progress,
			64,
			Color.WHITE,
			5.0,
			true
		)
	var icon_size := radius * 0.65
	draw_rect(
		Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)),
		Color(1.0, 1.0, 1.0, 0.9),
		false,
		2.0
	)
