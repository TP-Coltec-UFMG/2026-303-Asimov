extends Node2D

@export var lesson_title: String = ""
@export var accent: Color = Color(0.12, 0.22, 0.25)


func _ready() -> void:
	$Room/FloorInner.color = accent
	$Room/CenterPath.color = accent.lightened(0.15)
	$Room/DoorLabel.text = "SAÍDA"
	$Props/TargetCrate.save_enabled = false
	$Props/TargetCrate.hide()
	$Props/TargetCrate.process_mode = Node.PROCESS_MODE_DISABLED
	$Props/TargetCrate/CollisionShape2D.disabled = true
	$Props/TargetCrate/Interectable/CollisionShape2D.disabled = true
	$Props/FireLabel.hide()
	$Props/DarkZoneLabel.hide()
	$Room/Console.hide()
	$Room/Console/CollisionShape2D.disabled = true
	$Zones/ConsoleArea/CollisionShape2D.disabled = true
	for zone in [$Zones/MoveZone, $Zones/RunZone, $Zones/PushGoal, $Zones/ExitZone]:
		zone.hide()
	$Zones/MoveZone.position = Vector2(62, 30)
	$Zones/RunZone.position = Vector2(85, 30)
	$Zones/MoveZone/Label.text = "CHEGADA"
	$Zones/RunZone/Label.text = "CHEGADA"
	for label in [$Zones/MoveZone/Label, $Zones/RunZone/Label]:
		label.offset_left = -35.0
		label.offset_right = 35.0
	$Room/Console.position = Vector2(105, 10)
	$Zones/ConsoleArea.position = Vector2(146, 11)
