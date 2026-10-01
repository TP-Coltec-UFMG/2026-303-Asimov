extends Node2D

const GRANTED_COLOR := Color(0.2, 1.0, 0.35)
const DENIED_COLOR := Color(1.0, 0.18, 0.12)

@export var door_offset := Vector2(0, -8)

var granted := false
var status_color := DENIED_COLOR
var status_tween: Tween


func _ready() -> void:
	hide()


func show_status(access_granted: bool) -> void:
	var trigger := get_parent() as SceneTrigger
	if trigger == null or trigger.eh_elevador:
		return
	var collision := trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or collision.shape == null:
		return
	var door_rect := collision.shape.get_rect()
	position = trigger.to_local(collision.to_global(Vector2(door_rect.get_center().x, door_rect.position.y))) + door_offset
	granted = access_granted
	status_color = GRANTED_COLOR if granted else DENIED_COLOR
	if status_tween != null and status_tween.is_valid():
		status_tween.kill()
	modulate.a = 0.0
	show()
	queue_redraw()
	status_tween = create_tween()
	status_tween.tween_property(self, "modulate:a", 1.0, 0.12)


func _draw() -> void:
	draw_rect(Rect2(-10, -7, 20, 14), Color(status_color, 0.08))
	draw_rect(Rect2(-8, -5, 16, 10), Color(status_color, 0.2))
	draw_rect(Rect2(-6, -4, 12, 8), Color(0.02, 0.025, 0.03))
	draw_rect(Rect2(-5, -3, 10, 6), status_color)
	var icon_color := Color(0.015, 0.08, 0.03) if granted else Color(0.12, 0.015, 0.01)
	if granted:
		draw_polyline(PackedVector2Array([Vector2(-3, 0), Vector2(-1, 2), Vector2(3, -2)]), icon_color, 1.0)
	else:
		draw_line(Vector2(-2, -2), Vector2(2, 2), icon_color, 1.0)
		draw_line(Vector2(-2, 2), Vector2(2, -2), icon_color, 1.0)
