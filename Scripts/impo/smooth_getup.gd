extends Node
## Blend the frozen ragdoll back to its animated pose, after animation, IK and LiveBody.
## The root travels in world space; each limb blends relative to its parent limb.
## This avoids stretched arms/legs when the torso turns during the rise.

var movement = null
var active := false
var elapsed := 0.0
var limbs: Array = []


func setup(handler) -> void:
	movement = handler
	process_priority = 20 # LiveBody runs at 10, so its pose is our target.


func begin(from_pose: Dictionary, remotes: Array) -> void:
	limbs.clear()
	elapsed = 0.0
	var by_bone := {}
	for remote in remotes:
		var body := remote.get_node_or_null(remote.remote_path) as RigidBody2D
		var bone := remote.get_parent() as Bone2D
		if body == null or bone == null or not from_pose.has(body):
			continue
		by_bone[bone] = limbs.size()
		limbs.append({"body": body, "remote": remote, "bone": bone,
			"parent": -1, "depth": 0, "from": from_pose[body]})
	for limb in limbs:
		var ancestor: Node = limb["bone"].get_parent()
		while ancestor is Bone2D:
			limb["depth"] += 1
			if limb["parent"] == -1 and by_bone.has(ancestor):
				limb["parent"] = by_bone[ancestor]
			ancestor = ancestor.get_parent()
	# Store parent relationships as nodes before sorting the entries.
	for limb in limbs:
		var parent_index: int = limb["parent"]
		limb["parent_body"] = limbs[parent_index]["body"] if parent_index >= 0 else null
		if parent_index >= 0:
			var parent_from: Transform2D = limbs[parent_index]["from"]
			limb["local_from"] = parent_from.affine_inverse() * (limb["from"] as Transform2D)
	limbs.sort_custom(func(a, b): return int(a["depth"]) < int(b["depth"]))
	active = not limbs.is_empty()
	# Moving the capsule moves its children too. Restore the captured pose immediately,
	# before the first rendered frame, not one frame later in _process().
	for limb in limbs:
		(limb["body"] as Node2D).global_transform = limb["from"]


func cancel() -> void:
	# MovementHandler owns RemoteTransform flags while ragdolled.
	active = false
	limbs.clear()
	elapsed = 0.0


func finish() -> void:
	for limb in limbs:
		var remote: RemoteTransform2D = limb["remote"]
		if is_instance_valid(remote):
			remote.update_position = true
			remote.update_rotation = true
			remote.update_scale = true
	cancel()


func _process(delta: float) -> void:
	if not active:
		return
	if not movement.notragdolled:
		cancel()
		return
	if not movement.smoothGetup:
		finish()
		return
	elapsed += delta
	var progress := clampf(elapsed / maxf(movement.getupDuration, 0.05), 0.0, 1.0)
	var weight := progress * progress * (3.0 - 2.0 * progress)
	var targets := {}
	for limb in limbs:
		var remote: RemoteTransform2D = limb["remote"]
		if is_instance_valid(remote) and is_instance_valid(limb["body"]):
			targets[limb["body"]] = remote.global_transform
	for limb in limbs:
		var body: Node2D = limb["body"]
		if not is_instance_valid(body) or not targets.has(body):
			continue
		var target: Transform2D = targets[body]
		var parent: Node2D = limb["parent_body"]
		if is_instance_valid(parent) and targets.has(parent):
			var parent_target: Transform2D = targets[parent]
			var local_target := parent_target.affine_inverse() * target
			var local_from: Transform2D = limb["local_from"]
			body.global_transform = parent.global_transform * local_from.interpolate_with(local_target, weight)
		else:
			var from: Transform2D = limb["from"]
			body.global_transform = from.interpolate_with(target, weight)
	if progress >= 1.0:
		finish()
