extends Node2D

const OUTLINE := preload("res://Scenes/Utils/color_accessibility_cue.tscn")

var target: Node2D
var outline: Node2D
var strength := 0.6
var fading := false
var pulse: Tween
var lifetime: Tween


func _ready() -> void:
	target = get_parent() as Node2D
	if not target is Sprite2D:
		queue_free()
		return
	outline = OUTLINE.instantiate()
	outline.name = "ObjectiveOutline"
	target.add_child(outline)
	outline.set_forced_outline(true)
	modulate.a = 0.0
	pulse = create_tween().set_loops()
	pulse.tween_property(self, "strength", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(self, "strength", 0.5, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lifetime = create_tween()
	lifetime.tween_property(self, "modulate:a", 1.0, 0.4)
	lifetime.tween_interval(9.0)
	lifetime.tween_callback(fade_out)


func _process(_delta: float) -> void:
	if is_instance_valid(outline):
		outline.modulate.a = strength * modulate.a


func fade_out() -> void:
	if fading:
		return
	fading = true
	if lifetime != null and lifetime.is_valid():
		lifetime.kill()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.65)
	fade.tween_callback(queue_free)


func _exit_tree() -> void:
	if is_instance_valid(outline):
		outline.queue_free()

