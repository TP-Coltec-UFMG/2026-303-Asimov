class_name NPCMovementPoint
extends Marker2D

enum MovementType {
	WALK,
	RUN
}

@export var enabled: bool = true
@export var movement_type: MovementType = MovementType.WALK
@export var wait_time: float = 0.0
