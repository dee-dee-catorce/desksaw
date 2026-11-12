extends Node
@export var skeleton: Skeleton2D
@export var rigid: RigidBody2D
@export var rigidtorso: RigidBody2D
@export var animplay: AnimationPlayer
@export var eyes: Sprite2D
@export var tail: Bone2D
@export var skelparent: Node2D
@export var headIk: Node2D
@export var headIkControl: SoupLookAt


#collisions via stat
@export var normal: CollisionShape2D
@export var sitting: CollisionShape2D
@export var layingdown: CollisionShape2D
#raycasts
@export var floorRay: RayCast2D
@export var wallDetect: RayCast2D
@export var heightDetect: RayCast2D

@export var defheadnose: Node2D

@export var ragdollspeed: float = 575.0

@export var pinNode: Node2D

signal sigragdoll()

var lookback = false
var flip = false
var backwards = false
var dir: float = 0.0
var wander = true
var friction: float = 1.0
var speedacc: float = 20.0
var maxspeed: float = 240.0 # you will understand what the one is for later
var maxspeedMult: float = 10.0
#i literally forgot what the one was for
var jumpPowCap: float = -600.0
var jumpPower: float = -600.0
#timers

@export var jumpCoolDown: float = 4.0
var jumpTimer: float = 0.0

## Smooth movement (inspired by Casualties: Unknown).
## The pet speeds up and slows down smoothly: its velocity is changed a bit every physics step
## instead of pushing it with a force (with the force the speed was jerky - it jumped up to ~560 px/s
## with a 240 limit and averaged ~390). Jumps are 1.5x higher and still work for a moment after
## walking off an edge ("coyote time"). Walking speed and jump height grow with the pet size.
## Set smoothMovement to false to get the old movement back.
@export var smoothMovement: bool = true
const WALK_MULT := 1.6 # 240 * 1.6 = 384 px/s - about the average pace of the force-based walk (~390)
const ACCEL := 2600.0 # px/s^2 on the ground: ~90 % of the walking speed in ~0.2 s
const AIR_ACCEL := 900.0 # px/s^2 in the air: weaker control, like in CU
const SLOWDOWN := 0.18 # share of the speed lost every physics step when not walking or turning around (half of it in the air)
const JUMP_MULT := 1.22 # jump velocity x1.22 = jump height x1.5
const ANIM_MULT := 0.945 # steps a bit slower, so the feet don't look faster than the body
const COYOTE_TIME := 0.11 # s - a jump still works this long after walking off an edge (CU uses the same)
var _sinceGrounded := 0.0 # s since the floor ray last touched the floor

## Living body (Scripts/impo/live_body.gd): springy arms and head, tail, leaning, crouching, stepping up.
## Here are only the numbers; the picture (lean, crouch, lag) is drawn by LiveBody on top of the animation.
@export var livePhysics: bool = true
@export_range(0.0, 3.0, 0.1) var livePhysicsStrength: float = 2.0 # 0 - off, 1 - half, 2 - as designed, 3 - twice as strong
const LEAN_PER_DV := 0.30 # degrees of lean per 1 px/s of speed change in one physics step (~6 degrees when speeding up)
const LEAN_RATE := 5.0 # CU: Lerp(accelRot, .., fixedDeltaTime * 5)
const LEAN_MAX := 25.0 # degrees
const LAND_CROUCH := 0.05 # px of crouch per 1 px/s of falling speed (CU: crouchAmount -= vy * 0.03); a jump -> ~35 px
const LAND_CROUCH_MAX := 55.0 # px - never deeper
const LAND_MIN := 150.0 # px/s - softer landings are not counted
const STEP_FRAC := 0.35 # step up onto things no higher than this share of the body height
var lean := 0.0 # degrees, world: + is clockwise (top of the body to the right)
var crouch := 0.0 # px, world: hip lower, feet stay (landing); faded out by LiveBody
var visualOffset := Vector2.ZERO # px, world: the picture lags behind the body after a step up and catches up (LiveBody)
var liveBody = null
var _lastVel := Vector2.ZERO
var _landCooldown := 0.0

#pin joint storers
var valAngularPinUp
var valAngularPinDown
var notragdolled = true

enum states {
	moving, idle, ragdoll, jumping, falling, resting
}
var currstate = states.idle


func _ready() -> void:
	animplay.play("idleagain")
	call_deferred("_attachLiveBody")

	#invertPoints(false, true)
	pass
func _physics_process(delta: float) -> void:
	jumpTimer -= delta

	if currstate != states.resting:
		if !floorRay.is_colliding() and abs(rigid.linear_velocity.y) > 2:
			if rigid.linear_velocity.y > 0:
				initswithc(states.falling)
			else:
				initswithc(states.jumping)
		else:
			if dir != 0.0:
				initswithc(states.moving)
			else:
				initswithc(states.idle)
	else:
		if !floorRay.is_colliding():
			initswithc(states.falling)
		dir = 0.0
	headIKf()
	checkJump()
	detFlip()
	phystate(delta)
	_sinceGrounded = 0.0 if floorRay.is_colliding() else _sinceGrounded + delta
	if _smooth():
		_smoothPhysics(delta)
	if livePhysics and notragdolled:
		_liveNumbers(delta)
	else:
		lean = 0.0
		crouch = 0.0
		visualOffset = Vector2.ZERO
	_lastVel = rigid.linear_velocity
	rigidtorso.linear_velocity = rigidtorso.linear_velocity.clamp(Vector2(
		- maxspeed * maxspeedMult, -maxspeed * maxspeedMult), Vector2(maxspeed * maxspeedMult, maxspeed * maxspeedMult)
		)

	pass

#make them look at any object with a priority over 4

func headIKf():
	var behavior = get_parent()
	var yap = behavior.get_node_or_null("yapHandler")
	if yap != null and yap.isInteracting() and behavior.attention == null:
		return
	var dectNode = behavior.detectRange
	var mousePriority = dectNode.mousePriority
	var facing: float = -1.0 if flip else 1.0

	
	var targetPos: Vector2 = headIk.get_global_mouse_position()

	var mostInterest: float = mousePriority

	if behavior.attention != null:
		mostInterest = 999.0
		targetPos = behavior.attention.global_position
	else:
		var inRadius = dectNode.inRadius
		for obj in inRadius.keys():
			var data = inRadius[obj]
			if data.has("interest") and data["interest"] > mostInterest:
				mostInterest = data["interest"]
				targetPos = obj.global_position
		for expie in dectNode.expiesInRadius.keys():
			var data = dectNode.expiesInRadius[expie]
			if data["interest"] > mostInterest:
				mostInterest = data["interest"]
				targetPos = expie.global_position

	var dirx: float = sign(targetPos.x - rigidtorso.global_position.x)
	var mouse_pos: Vector2 = targetPos
	var dist: float = rigidtorso.global_position.distance_to(targetPos)

	if dist <= 300.0:
		lookback = dirx != facing
		if dirx != facing:
			mouse_pos.x = rigidtorso.global_position.x - (mouse_pos.x - rigidtorso.global_position.x)
			mouse_pos.y = (rigidtorso.global_position.y - 300) - (mouse_pos.y - rigidtorso.global_position.y)

		headIk.global_position = headIk.global_position.lerp(mouse_pos, .05)
	else:
		lookback = false
		headIk.global_position = headIk.global_position.lerp(defheadnose.global_position, .05)


#initial switch state 
func initswithc(state: states):
	if currstate == state: return
	currstate = state
	match state:
		states.idle:
			switch_hitbox(1)
			self.get_parent().wander = true
			animplay.speed_scale = 1
			animplay.play("idleagain")
			print("idle")
			pass
		states.jumping:
			switch_hitbox(1)
			self.get_parent().wander = true
			animplay.speed_scale = 1
			animplay.play("jump")
			print("jump")
		states.falling:
			switch_hitbox(1)
			self.get_parent().wander = true
			print("Falling")
			animplay.speed_scale = 1
			animplay.play("fall")
		states.moving:
			switch_hitbox(1)
			self.get_parent().wander = true
			print("moving")

		states.resting:
			print("resting")
			self.get_parent().wander = false
			var r = randi_range(1, 2)
			var resttime = randi_range(120, 200)
			animplay.play("sit" if r == 1 else "laydown")

			switch_hitbox(2 if r == 1 else 3)
			await get_tree().create_timer(resttime).timeout
			initswithc(states.idle)
			self.get_parent().wander = true


	pass


func switch_hitbox(state: int):
	normal.disabled = (state != 1)
	sitting.disabled = (state != 2)
	layingdown.disabled = (state != 3)


func phystate(_delta: float):
	match currstate:
		states.idle:
			rigid.linear_velocity.x = move_toward(rigid.linear_velocity.x, 0, friction)

			pass
		states.moving:
			var tempmax = maxspeed
			#apply movement based on direction
			if backwards:
				tempmax = (tempmax / 2) + 40
			var moving_same_direction = sign(rigid.linear_velocity.x) == dir

			if !moving_same_direction or abs(rigid.linear_velocity.x) < tempmax:
				if not _smooth(): # smooth movement speeds up in _smoothPhysics() instead
					rigid.apply_central_force(Vector2(dir, 0) * speedacc)

		
			var animSpeed: float = maxspeed * (_sizeK() if _smooth() else 1.0)
			var normlized = abs(remap(rigid.linear_velocity.x, 0, animSpeed, 0.0, 1.0))
			#there used to be a long if statement here and my ass got flamed when i posted it
			backwards = GlobalVariable.checkpositive(dir) == flip
			var target_anim = "moveB" if backwards else "moveF"

			if animplay.current_animation != target_anim:
				animplay.play(target_anim)

			animplay.speed_scale = (normlized / 2) + .1
			if _smooth():
				animplay.speed_scale *= ANIM_MULT
			
			
			pass


func detFlip():
	if currstate == states.ragdoll:
		return
	var behavior = get_parent()
	var yap = behavior.get_node_or_null("yapHandler")
	if yap != null and yap.isInteracting() and behavior.attention == null:
		return
	var dirx: float
	if behavior.attention != null:
		#keep facing them even while standing still
		dirx = sign(behavior.attention.global_position.x - rigid.global_position.x)
		if dirx != 0:
			skelparent.scale.x = dirx
			if dirx == 1:
				flip = false
			else:
				flip = true
		return
	dirx = sign(rigid.get_global_mouse_position().x - rigid.global_position.x)
	var _facing: float = -1.0 if flip else 1.0

		
	if dirx == dir:
		if dir != 0:
			skelparent.scale.x = dir
		if dir == 1:
			flip = false
		else:
			flip = true

		#invertPoints(flip)
		pass
	#determine when you gotta FLIPPPP
	pass

#test function 
#invert pinjoin angular limits

func invertPoints(val: bool, setup: bool = false):
	print(pinNode)
	var descendants = pinNode.find_children("*", "", true, false)

	for child in descendants:
		if child is PinJoint2D or child is RapierPinJoint2D:
			"""
			var fuckyou: RapierPinJoint2D
			fuckyou.angular_limit_lower
			fuckyou.angular_limit_upper
			"""

			if setup:
				#reset default limits i do not recommend calling this more than one time
				valAngularPinDown = child.angular_limit_lower
				valAngularPinUp = child.angular_limit_upper
				return

			
			if val:
				child.angular_limit_lower = valAngularPinUp
				child.angular_limit_upper = valAngularPinDown
			else:
				child.angular_limit_lower = valAngularPinDown
				child.angular_limit_upper = valAngularPinUp


func checkJump():
	if wallDetect.is_colliding() and !heightDetect.is_colliding() and dir != 0.0 and !backwards:
		jump()
	pass

func jump():
	# coyote time: with smooth movement the jump still works for a moment after leaving the floor
	var onFloor: bool = floorRay.is_colliding() or (_smooth() and _sinceGrounded <= COYOTE_TIME)
	if onFloor and jumpTimer <= 0.0:
		var vel = rigid.linear_velocity
		vel.y = jumpPower * (JUMP_MULT * sqrt(_sizeK()) if _smooth() else 1.0) # sqrt: jump height grows with the size
		rigid.linear_velocity = vel
		jumpTimer = jumpCoolDown
		_sinceGrounded = COYOTE_TIME + 1.0 # no second jump in the air


func _smooth() -> bool:
	return smoothMovement and notragdolled


## Pet size compared to the default one (spawnSize 1 = wrapper scale 4).
func _sizeK() -> float:
	var root := get_parent().get_parent() as Node2D
	if root == null:
		return 1.0
	return maxf(absf(root.global_scale.y) / 4.0, 0.05)


## Smooth movement: speed up, slow down and keep the walking speed limit by changing the velocity directly.
func _smoothPhysics(delta: float) -> void:
	if currstate == states.resting:
		return
	var grounded: bool = floorRay.is_colliding()
	var sk := _sizeK()
	var v: Vector2 = rigid.linear_velocity
	var limit: float = maxspeed * WALK_MULT * sk
	var tempmax: float = limit if not backwards else (maxspeed / 2.0 + 40.0) * WALK_MULT * sk
	# speed up (in ~0.2 s on the ground), but never past the walking speed
	if dir != 0.0 and (signf(v.x) != signf(dir) or absf(v.x) < tempmax):
		v.x += dir * (ACCEL if grounded else AIR_ACCEL) * sk * delta
		if signf(v.x) == signf(dir) and absf(v.x) > tempmax:
			v.x = dir * tempmax
	# slow down when not walking or when turning around
	if dir == 0.0 or signf(v.x) == -signf(dir):
		v.x *= 1.0 - SLOWDOWN * (1.0 if grounded else 0.5)
	# on the ground - never faster than the walking speed (a push or a throw is slowed down quickly)
	if grounded and absf(v.x) > limit * 1.05:
		v.x = signf(v.x) * limit
	rigid.linear_velocity = v
	if grounded and dir != 0.0 and livePhysics:
		_stepUp()


func _attachLiveBody() -> void:
	liveBody = preload("res://Scripts/impo/live_body.gd").new()
	liveBody.name = "LiveBody"
	skeleton.add_child(liveBody) # the last child of the skeleton - after IK (SoupMod)
	liveBody.setup(self)


## Living body numbers (CU FixedUpdate): crouch on landing, lean from acceleration.
func _liveNumbers(delta: float) -> void:
	var grounded: bool = floorRay.is_colliding()
	# landing: crouch by the falling speed - at the moment of the hit (the falling stopped), not when the ray first sees the floor;
	# not more often than every 0.3 s (bounces of the body on the floor would count as new landings)
	_landCooldown = maxf(0.0, _landCooldown - delta)
	if grounded and _lastVel.y > LAND_MIN and rigid.linear_velocity.y < _lastVel.y * 0.5 and _landCooldown <= 0.0:
		crouch = minf(crouch + _lastVel.y * LAND_CROUCH, LAND_CROUCH_MAX)
		_landCooldown = 0.3
	# lean from acceleration (CU: accelRot = Lerp(accelRot, dv * 15 * k, fixedDeltaTime * 5))
	var dv: float = rigid.linear_velocity.x - _lastVel.x
	var target := clampf(dv * LEAN_PER_DV, -LEAN_MAX, LEAN_MAX)
	lean = lerpf(lean, target, clampf(delta * LEAN_RATE, 0.0, 1.0))


## Step up (CU TryStepUp): an obstacle in front of the feet, free above it, its top not higher than a share of the
## body height - the body moves up without a jump, the picture stays and catches up (visualOffset, LiveBody).
func _stepUp() -> void:
	if not normal or normal.disabled or not (normal.shape is CapsuleShape2D):
		return
	var cap := normal.shape as CapsuleShape2D
	var sc: Vector2 = normal.global_transform.get_scale().abs()
	var halfW: float = cap.radius * sc.x
	var height: float = cap.height * sc.y
	var center: Vector2 = normal.global_position
	var bottom: float = center.y + height * 0.5
	var maxStep: float = height * STEP_FRAC
	var space := rigid.get_world_2d().direct_space_state
	var ex: Array[RID] = [rigid.get_rid()]
	for b in rigid.find_children("*", "CollisionObject2D", true, false):
		ex.append(b.get_rid())
	var q := PhysicsRayQueryParameters2D.create(Vector2(center.x, bottom - 3.0), Vector2(center.x + dir * (halfW + 14.0), bottom - 3.0), 1, ex)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var hp: Vector2 = hit["position"]
	var probe := Vector2(hp.x + dir * 6.0, bottom - maxStep - 2.0)
	# free above the step for the whole body height (otherwise it's a wall, not a step)
	var qUp := PhysicsRayQueryParameters2D.create(probe, probe - Vector2(0.0, height), 1, ex)
	if not space.intersect_ray(qUp).is_empty():
		return
	# top of the step - a ray from above
	var qDown := PhysicsRayQueryParameters2D.create(probe, Vector2(probe.x, bottom), 1, ex)
	var top := space.intersect_ray(qDown)
	if top.is_empty():
		return
	var stepH: float = bottom - float(top["position"].y)
	if stepH < 2.0 or stepH > maxStep:
		return
	var move := Vector2(dir * maxf(0.0, (hp.x - center.x) * dir - halfW), -(stepH + 2.0))
	rigid.global_position += move
	visualOffset -= move # the picture stays where it was and catches up (LiveBody)
	rigid.linear_velocity.x = _lastVel.x


func ragdoll(val: bool):
	#true = not ragdolled
	#false = ragdolled
	if val == notragdolled:
		return

	notragdolled = val

	if !val:
		skelparent.scale.x = 1.0

	var descendants = skeleton.find_children("*", "", true, false)
	var moredesc = rigid.find_children("*", "", true, false)

	for child in descendants:
		if child is RemoteTransform2D:
			var rtt: RemoteTransform2D = child
			rtt.update_position = val
			rtt.update_rotation = val
			rtt.update_scale = val

	for child in moredesc:
		if child is RigidBody2D:
			child.freeze = val
			if !val:
			#rigid.scale.x = -1.0 if flip else 1.0
				child.linear_velocity = rigid.linear_velocity
				child.angular_velocity = rigid.angular_velocity

	#lmao
	

	if !val:
		if liveBody != null:
			liveBody.onRagdoll()
		sigragdoll.emit()
	else:
		rigid.global_position.x = rigidtorso.global_position.x
		rigid.global_position.y = rigidtorso.global_position.y
