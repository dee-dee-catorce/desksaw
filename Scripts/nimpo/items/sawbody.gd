extends RigidBody2D


# Called every frame. 'delta' is the elapsed time since the previous frame.


#fisx this shit
func _process(delta: float) -> void:
	global_position = get_parent().global_position 
	pass
