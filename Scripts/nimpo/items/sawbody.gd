extends RigidBody2D


# Called every frame. 'delta' is the elapsed time since the previous frame.


#fisx this shit
func _process(delta: float) -> void:
	position = get_parent().position * .5
	pass
