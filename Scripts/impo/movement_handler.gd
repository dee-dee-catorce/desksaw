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
		sigragdoll.emit()
	else:
		rigid.global_position.x = rigidtorso.global_position.x
		rigid.global_position.y = rigidtorso.global_position.y
