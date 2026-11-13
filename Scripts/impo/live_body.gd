extends Node
## Living body (inspired by Casualties: Unknown - Body.HandleVisuals and TailScript).
## Runs every frame on top of the animation and IK while the pet is on its feet:
## 1) the whole body leans around the hip from acceleration and braking (movementHandler.lean);
## 2) crouch (movementHandler.crouch: landing; also a bit while leaning) - hip lower, feet stay where they are;
## 3) after stepping up onto a low object the picture lags behind the body and catches up (movementHandler.visualOffset);
## 4) the torso turns a bit towards where the head looks; the arms keep hanging (they don't turn with the torso),
##    the head keeps its look - arm, leg and head IK are recalculated after our changes;
## 5) arm and head inertia - damped springs;
## 6) the tail is pulled against the movement (back and a bit up when walking, down when jumping, up when falling);
##    standing, it moves on its own - unevenly, with an occasional bigger swish.
## Physics of the body parts is NOT used while standing (same as in CU) - only bones are changed.
## Settings: movementHandler.livePhysics (on/off) and movementHandler.livePhysicsStrength (0..3, default 2).

## Arm and head inertia comes from the movement of the WHOLE body (the movement capsule), not from the bones:
## the animation changes bone speeds in jumps on keyframes and the springs would shake.
const MAX_ACCEL := 4000.0 # px/s^2 - stronger is cut (a jerk, a teleport)
const ACCEL_SMOOTH := 0.10 # s - acceleration smoothing
const ACCEL_DEADZONE := 300.0 # px/s^2 - weaker is ignored (the body bounces a little on the floor every physics step)

## Springs: bone path from Skeleton2D, frequency (Hz), damping (share of critical), limit (rad), inertia gain,
## is it a forearm (the elbow never straightens further than straight).
const SPRINGS := [
	["hip/back/head", 2.4, 0.60, 0.22, 0.5, false],
	["hip/back/fArm", 1.1, 0.55, 0.55, 0.20, false],
	["hip/back/fArm/fLArm", 1.3, 0.60, 0.35, 0.12, true],
	["hip/back/BArm", 1.1, 0.55, 0.55, 0.20, false],
	["hip/back/BArm/BLArm", 1.3, 0.60, 0.35, 0.12, true],
]

## CU units: 1 CU unit is ~53 px (a CU character is ~3.6 units tall, a DeskSaw pet ~190 px).
const LEAN_DIP := 0.8 # px of crouch per degree of lean
const ELBOW_RETURN := 3.0 # rad/s - the forearm returns to the IK pose this fast if it ended up on the wrong side
const FOOT_CLEARANCE := 18.0 # px (at scale 4) - leg targets never go lower than the capsule bottom minus this
const CROUCH_IN_SPEED := 300.0 # px/s - the crouch grows smoothly (~0.1 s), not in one frame
const ARM_MAX_SPEED := 8.0 # rad/s - an arm never turns faster than this in one frame (any IK or spring jump is spread over 2-3 frames)
const OFFSET_RATE := 8.0 # CU: visualBodyOffset = Lerp(.., 0, dt * 8)
const CROUCH_RATE := 6.0 # CU: crouchAmount = Lerp(.., 0, dt * 6)
const TORSO_LOOK := 0.207 # share of the look angle the torso turns
const TORSO_RATE := 4.0 # CU: torsoLookSmooth = Lerp(.., .., dt * 4)
const TORSO_MAX_LOOK := PI / 2.0 # look angles over 90 degrees are not counted
const TAIL_UNIT := 53.0 # px in one CU unit
const TAIL_RATE := 0.14 # CU: LerpAngle(.., .., dt * |v| * 0.14)
const TAIL_IDLE_RATE := 0.78 # CU: standing - LerpAngle(.., .., dt * 0.78)
const TAIL_MOVING := 75.0 # px/s - faster than this the tail is pulled by the movement
const TAIL_MAX := 1.3962634 # 80 degrees - not further from "straight back"
const TAIL_DOWN := 0.1 # CU: (movement direction + down * 0.1)
const TAIL_IDLE_SMALL := 0.07 # rad (~4 degrees) - small uneven tail moves while standing
const TAIL_IDLE_SWISH := 0.20 # rad (~11 degrees) - an occasional bigger swish
const TAIL_SWISH_CHANCE := 0.15
const TAIL_STRENGTH_OFFSET := 1.5 # the tail lives only when the strength is above 1.5
## the hip never goes so low that the foot gets closer to the thigh than this share of the leg (the leg IK would flip)
const LEG_MIN_REACH := 0.45

var moveSys = null
var springs: Array = [] # {bone, k, c, max, gain, d, w, base, written, len, elbow, straight, flex, prevA}
var _wasLive := false
var _pv := Vector2.INF # body velocity on the last physics step
var bodyAcc := Vector2.ZERO # smoothed body acceleration, px/s^2 (global)

# bones and IK
var _hip: Bone2D = null
var _back: Bone2D = null
var _tail: Bone2D = null
var _ikLegs: Array = [] # SoupTwoBoneIK of the legs
var _feet: Array = [] # foot Bone2D (same order as _ikLegs) - they keep their angle while crouching
var _footBase: Array = [] # their rotation without us
var _footWritten: Array = []
var _footFlat: Array = [] # the foot angle (skeleton space) while standing calmly - this is how it stands on the floor
var _ikArms: Array = [] # [SoupTwoBoneIK, shoulder Bone2D]
var _lookAt = null # SoupLookAt of the head
# what we wrote into bones (if nobody touched the bone since our last write, the base stays the old one)
var _hipBasePos := Vector2.ZERO
var _hipBaseRot := 0.0
var _hipWrittenPos := Vector2.INF
var _hipWrittenRot := INF
var _backBase := 0.0
var _backWritten := INF
var _tailBase := 0.0
var _tailWritten := INF
var _torso := 0.0 # rad, torso towards the look (smoothed, skeleton space)
var _crouchShown := 0.0 # px, crouch on the picture (grows smoothly)
var _tailOff := 0.0 # rad, tail offset from the animation
var _tailMean := INF # rad, average tail angle in the animation (smoothed over ~2 s)
var _tailIdle := 0.0 # rad, uneven tail movement while standing
var _tailIdleFrom := 0.0
var _tailIdleTo := 0.0
var _tailIdleT := 1.0
var _tailIdleDur := 1.0
var _tailIdleW := 0.0 # 0 - tail as in the animation, 1 - its own movement while standing


func enabled() -> bool:
	return moveSys != null and bool(moveSys.livePhysics)


func strength() -> float:
	return clampf(float(moveSys.livePhysicsStrength), 0.0, 3.0)


## How much livelier than at strength 2: 0 - off, 1 - half, 2 - as designed, 3 - twice as strong.
func _k(st: float) -> float:
	return st / 2.0 if st <= 2.0 else st - 1.0


func setup(ms) -> void:
	moveSys = ms
	process_priority = 10 # after AnimationPlayer and IK (SoupMod) - otherwise they overwrite our changes
	var sk: Node = moveSys.skeleton
	for spec in SPRINGS:
		var b := sk.get_node_or_null(spec[0]) as Bone2D
		if b == null:
			continue
		var w := TAU * float(spec[1])
		var boneLen: float = b.get_length() if b.get_length() > 1.0 else 12.0
		var elbow: bool = spec[5]
		var straight := 0.0
		if elbow and b.get_parent() is Bone2D:
			straight = (b.get_parent() as Bone2D).get_bone_angle() - b.get_bone_angle() # straight elbow
		springs.append({"bone": b, "k": w * w, "c": 2.0 * float(spec[2]) * w, "max": float(spec[3]),
			"gain": float(spec[4]), "d": 0.0, "w": 0.0, "base": b.rotation, "written": INF, "len": boneLen,
			"elbow": elbow, "straight": straight, "flex": 0.0, "prevA": INF})
	_hip = sk.get_node_or_null("hip") as Bone2D
	_back = sk.get_node_or_null("hip/back") as Bone2D
	_tail = sk.get_node_or_null("hip/Tail") as Bone2D
	for n in sk.find_children("*", "", true, false):
		if n is SoupTwoBoneIK:
			var j1: Bone2D = n.joint_one_bone_node
			if j1 == null or n.target_node == null:
				continue
			if j1.get_parent() == _hip:
				_ikLegs.append(n)
				var j2: Bone2D = n.joint_two_bone_node
				var fbone: Bone2D = j2.get_node_or_null("Foot") as Bone2D if j2 != null else null
				_feet.append(fbone)
				_footBase.append(fbone.rotation if fbone != null else 0.0)
				_footWritten.append(INF)
				_footFlat.append(INF)
			else:
				_ikArms.append([n, j1])
		elif n is SoupLookAt and n.target_node != null:
			_lookAt = n


## The pet went limp (ragdoll): everything living starts from zero.
func onRagdoll() -> void:
	_releaseBody()


func _resetSprings() -> void:
	for s in springs:
		s["d"] = 0.0
		s["w"] = 0.0
		s["written"] = INF
		s["prevA"] = INF
	_pv = Vector2.INF
	bodyAcc = Vector2.ZERO


## Body acceleration - per physics step (the capsule velocity changes only there; per frame it would be zero or a spike).
func _physics_process(delta: float) -> void:
	if moveSys == null or delta <= 0.0 or not moveSys.notragdolled:
		_pv = Vector2.INF
		bodyAcc = Vector2.ZERO
		return
	var v: Vector2 = moveSys.rigid.linear_velocity
	if _pv != Vector2.INF:
		var a := (v - _pv) / delta
		var al := a.length()
		if al > MAX_ACCEL:
			a = a * (MAX_ACCEL / al)
		al = a.length()
		a = a * (maxf(0.0, al - ACCEL_DEADZONE) / al) if al > 0.0 else Vector2.ZERO
		bodyAcc = bodyAcc.lerp(a, clampf(delta / ACCEL_SMOOTH, 0.0, 1.0))
	_pv = v


func _process(delta: float) -> void:
	if moveSys == null or delta <= 0.0:
		return
	if not moveSys.notragdolled or not enabled():
		if _wasLive:
			_releaseBody()
		_wasLive = false
		return
	_wasLive = true
	var st := strength()
	_applyBody(delta, st)
	var sdt := minf(delta, 1.0 / 30.0) # the game dropped to 10 fps - a big step would blow the spring up
	for s in springs:
		_stepSpring(s, sdt, st)
	_limitArms(delta)
	_stepTail(delta, st)


## An arm (in skeleton space) never turns faster than ARM_MAX_SPEED - a jump from IK or a spring is spread over frames.
func _limitArms(delta: float) -> void:
	var skInv := (moveSys.skeleton as Node2D).global_transform.affine_inverse()
	var lim := ARM_MAX_SPEED * delta
	for s in springs:
		var b: Bone2D = s["bone"]
		if not is_instance_valid(b) or b.name == "head":
			continue
		var a := (skInv * b.global_transform).get_rotation()
		var pa := float(s["prevA"])
		if pa != INF:
			var da := wrapf(a - pa, -PI, PI)
			if absf(da) > lim:
				b.rotation -= da - signf(da) * lim
				s["written"] = b.rotation
				a = pa + signf(da) * lim
		s["prevA"] = a


## CU HandleVisuals: lean, crouch, picture lag, torso towards the look, hanging arms, head keeps the look.
func _applyBody(delta: float, st: float) -> void:
	var ms = moveSys
	var k := _k(st)
	# fade out (CU: visualBodyOffset - dt * 8, crouchAmount - dt * 6)
	var vo: Vector2 = ms.visualOffset
	ms.visualOffset = vo.lerp(Vector2.ZERO, clampf(delta * OFFSET_RATE, 0.0, 1.0))
	ms.crouch = lerpf(float(ms.crouch), 0.0, clampf(delta * CROUCH_RATE, 0.0, 1.0))
	if _hip == null:
		return
	var skXf: Transform2D = (ms.skeleton as Node2D).global_transform
	var skInv := skXf.affine_inverse()
	var mirror := signf(skXf.determinant())
	if mirror == 0.0:
		mirror = 1.0
	var resting: bool = ms.currstate == ms.states.resting
	# hip base - what the animation set (if nobody touched it since our last write - the old base,
	# otherwise our changes would pile up after the animation ends)
	if _hip.position.distance_squared_to(_hipWrittenPos) > 1e-8:
		_hipBasePos = _hip.position
	if absf(_hip.rotation - _hipWrittenRot) > 1e-6:
		_hipBaseRot = _hip.rotation
	_hip.position = _hipBasePos
	_hip.rotation = _hipBaseRot
	for i in _feet.size():
		var fb0: Bone2D = _feet[i]
		if fb0 == null:
			continue
		if absf(fb0.rotation - float(_footWritten[i])) <= 1e-6:
			fb0.rotation = float(_footBase[i]) # our last write - back to the base
		else:
			_footBase[i] = fb0.rotation
		_footWritten[i] = INF
	# torso towards the look - before the hip changes (CU torsoLookSmooth); not while sitting or lying
	var torsoWant := 0.0
	if not resting and _back != null and ms.headIk != null and ms.defheadnose != null:
		var c: Vector2 = skInv * _back.global_position
		var look: Vector2 = skInv * (ms.headIk as Node2D).global_position - c
		var rest: Vector2 = skInv * (ms.defheadnose as Node2D).global_position - c
		if look.x > 1.0 and rest.length() > 1.0:
			torsoWant = clampf(wrapf(look.angle() - rest.angle(), -PI, PI), -TORSO_MAX_LOOK, TORSO_MAX_LOOK) * TORSO_LOOK * k
	_torso = lerpf(_torso, torsoWant, clampf(delta * TORSO_RATE, 0.0, 1.0))
	# arms before the changes: shoulder and IK target - the arms will hang instead of turning with the torso
	var armsBefore: Array = []
	for a in _ikArms:
		armsBefore.append([(a[1] as Node2D).global_position, (a[0].target_node as Node2D).global_position])
	# 1) lean: the whole body around the hip (CU: RotateAround(limbs[2], accelRot)); not while sitting or lying
	var leanDeg: float = 0.0 if resting else float(ms.lean) * k
	_hip.rotation = _hipBaseRot + deg_to_rad(leanDeg) * mirror
	var feet: Array = []
	var grounded: bool = ms.floorRay.is_colliding()
	var calm: bool = grounded and not resting and ms.currstate == ms.states.idle and float(ms.crouch) < 0.5 and absf(float(ms.lean)) < 1.0
	for i in _ikLegs.size():
		feet.append((_ikLegs[i].target_node as Node2D).global_position)
		var fb1: Bone2D = _feet[i]
		if fb1 != null and calm:
			var a1 := (skInv * fb1.global_transform).get_rotation()
			_footFlat[i] = a1 if float(_footFlat[i]) == INF else lerp_angle(float(_footFlat[i]), a1, clampf(delta * 2.0, 0.0, 1.0))
	# 2) crouch (hip lower, feet stay) and the picture lag (the whole picture)
	var cWant := float(ms.crouch)
	_crouchShown = move_toward(_crouchShown, cWant, CROUCH_IN_SPEED * delta) if cWant > _crouchShown else cWant
	var crouchPx: float = 0.0 if resting else (_crouchShown + absf(float(ms.lean)) * LEAN_DIP) * k
	var off: Vector2 = ms.visualOffset
	# feet never below the floor: while jumping and falling the leg targets of the animation are low (legs stretched)
	var skScale := absf(skXf.get_scale().y)
	var floorY: float = (ms.rigid as Node2D).global_position.y + off.y - FOOT_CLEARANCE * skScale / 4.0
	var legWant: Array = []
	for i in _ikLegs.size():
		var w0: Vector2 = feet[i] + off
		w0.y = minf(w0.y, floorY)
		legWant.append(w0)
		# the hip never lower than the leg allows (otherwise the IK jumps to the other solution)
		var j1: Bone2D = _ikLegs[i].joint_one_bone_node
		var j2: Bone2D = _ikLegs[i].joint_two_bone_node
		if j1 != null and j2 != null:
			var minD: float = (j1.get_length() + j2.get_length()) * skScale * LEG_MIN_REACH
			var hp: Vector2 = j1.global_position + off
			var dx: float = w0.x - hp.x
			var room: float = (w0.y - hp.y) - sqrt(maxf(minD * minD - dx * dx, 0.0))
			crouchPx = minf(crouchPx, maxf(room, 0.0))
	_hip.position = _hipBasePos + skInv.basis_xform(off + Vector2(0.0, crouchPx))
	if crouchPx > 0.01:
		for i in _ikLegs.size():
			var tgt: Node2D = _ikLegs[i].target_node
			var keep := tgt.position
			var want: Vector2 = legWant[i]
			tgt.global_position = want
			_ikLegs[i]._process_loop(0.0)
			tgt.position = keep
			# landed - the foot stands flat, as when standing (otherwise it keeps the falling pose, toes down, and goes into the floor)
			var fb2: Bone2D = _feet[i]
			var flat := float(_footFlat[i])
			if fb2 != null and grounded and flat != INF and _crouchShown > 1.0:
				var wt := clampf(_crouchShown * k / 20.0, 0.0, 1.0)
				var a2 := (skInv * fb2.global_transform).get_rotation()
				fb2.rotation += wrapf(flat - a2, -PI, PI) * wt
				_footWritten[i] = fb2.rotation
	_hipWrittenPos = _hip.position
	_hipWrittenRot = _hip.rotation
	# 3) torso (the animation doesn't touch the back bone)
	if _back != null:
		if absf(_back.rotation - _backWritten) > 1e-6:
			_backBase = _back.rotation
		_back.rotation = _backBase + _torso
		_backWritten = _back.rotation
	# 4) arms hang: the IK target moves with the shoulder, but doesn't turn
	for i in _ikArms.size():
		var ik = _ikArms[i][0]
		var tgt: Node2D = ik.target_node
		var keep := tgt.position
		tgt.global_position = armsBefore[i][1] + ((_ikArms[i][1] as Node2D).global_position - armsBefore[i][0])
		ik._process_loop(0.0)
		tgt.position = keep
	# 5) the head keeps its look
	if _lookAt != null:
		_lookAt._process_loop(0.0)


## Living physics switched off or the pet fell: hip, torso and tail back to the animation, everything living from zero.
func _releaseBody() -> void:
	if _hip != null:
		if _hip.position.distance_squared_to(_hipWrittenPos) <= 1e-8:
			_hip.position = _hipBasePos
		if absf(_hip.rotation - _hipWrittenRot) <= 1e-6:
			_hip.rotation = _hipBaseRot
	if _back != null and absf(_back.rotation - _backWritten) <= 1e-6:
		_back.rotation = _backBase
	if _tail != null and absf(_tail.rotation - _tailWritten) <= 1e-6:
		_tail.rotation = _tailBase
	for i in _feet.size():
		var fb3: Bone2D = _feet[i]
		if fb3 != null and absf(fb3.rotation - float(_footWritten[i])) <= 1e-6:
			fb3.rotation = float(_footBase[i])
		_footWritten[i] = INF
	_hipWrittenPos = Vector2.INF
	_hipWrittenRot = INF
	_backWritten = INF
	_tailWritten = INF
	_torso = 0.0
	_crouchShown = 0.0
	_tailOff = 0.0
	_tailIdleW = 0.0
	_tailMean = INF
	for s in springs:
		var b: Bone2D = s["bone"]
		if is_instance_valid(b) and absf(b.rotation - float(s["written"])) < 1e-5:
			b.rotation = float(s["base"])
	_resetSprings()
	if moveSys != null:
		moveSys.lean = 0.0
		moveSys.crouch = 0.0
		moveSys.visualOffset = Vector2.ZERO


## Tail (CU TailScript): when moving - against the movement (+ a bit up), not further than 80 degrees from
## "straight back", pulled faster the faster the body moves; standing - its own uneven movement around the animation.
func _stepTail(delta: float, st: float) -> void:
	if _tail == null or _hip == null:
		return
	var r := _tail.rotation
	var anim: float = _tailBase if absf(r - _tailWritten) < 1e-6 else r
	var w := clampf((st - TAIL_STRENGTH_OFFSET) * 2.0, 0.0, 1.0) # strength 2 - tail as in CU; 1.5 and less - animation only
	var v: Vector2 = moveSys.rigid.linear_velocity
	var speed := v.length()
	var resting: bool = moveSys.currstate == moveSys.states.resting
	# standing - uneven movement instead of the even swing of the idle animation
	_tailMean = anim if _tailMean == INF else lerpf(_tailMean, anim, clampf(delta / 2.0, 0.0, 1.0))
	_tailIdleT += delta
	if _tailIdleT >= _tailIdleDur:
		_tailIdleFrom = _tailIdle
		if randf() < TAIL_SWISH_CHANCE:
			_tailIdleTo = randf_range(0.6, 1.0) * TAIL_IDLE_SWISH * (1.0 if randf() < 0.5 else -1.0)
			_tailIdleDur = randf_range(0.5, 0.9)
		else:
			_tailIdleTo = randf_range(-1.0, 1.0) * TAIL_IDLE_SMALL
			_tailIdleDur = randf_range(1.2, 3.5)
		_tailIdleT = 0.0
	var u := clampf(_tailIdleT / _tailIdleDur, 0.0, 1.0)
	_tailIdle = lerpf(_tailIdleFrom, _tailIdleTo, u * u * (3.0 - 2.0 * u))
	_tailIdleW = move_toward(_tailIdleW, 1.0 if (speed <= TAIL_MOVING and not resting and w > 0.0) else 0.0, delta * 2.0)
	var baseRot := lerpf(anim, _tailMean + _tailIdle * w * maxf(1.0, _k(st)), _tailIdleW)
	var want := 0.0
	var rate := TAIL_IDLE_RATE
	if speed > TAIL_MOVING and not resting and w > 0.0:
		# in skeleton space the pet always faces +x, "back" is -x
		var m := (moveSys.skeleton as Node2D).global_transform.affine_inverse().basis_xform(v).normalized()
		var tip := -(m + Vector2(0.0, TAIL_DOWN)).normalized()
		var a := clampf(wrapf(tip.angle() - PI, -PI, PI), -TAIL_MAX, TAIL_MAX)
		var animTip := _hip.rotation + baseRot + _tail.get_bone_angle()
		want = wrapf(PI + a - animTip, -PI, PI) * w
		rate = speed / TAIL_UNIT * TAIL_RATE
	_tailOff = lerp_angle(_tailOff, want, clampf(delta * rate, 0.0, 1.0))
	_tail.rotation = baseRot + _tailOff
	_tailBase = anim
	_tailWritten = _tail.rotation


func _stepSpring(s: Dictionary, dt: float, st: float) -> void:
	var b: Bone2D = s["bone"]
	if not is_instance_valid(b):
		return
	# base - what the animation and IK set this frame; if nobody touched the bone since our last write - the old base
	var r := b.rotation
	var base: float = float(s["base"]) if absf(r - float(s["written"])) < 1e-5 else r
	# body acceleration in the space of the bone parent (the bone angle is there too, the mirror is accounted for)
	var parent := b.get_parent() as Node2D
	var aLocal := Vector2.ZERO
	if parent:
		# affine_inverse, not basis_xform_inv: that one doesn't divide by the scale (pets are scaled x4)
		aLocal = parent.global_transform.affine_inverse().basis_xform(bodyAcc)
	# inertia: the body accelerates - the limb lags behind (force -m*a on the arm length)
	var dir := Vector2.RIGHT.rotated(base + b.get_bone_angle())
	var kk := _k(st)
	var alpha := -(dir.x * aLocal.y - dir.y * aLocal.x) / float(s["len"]) * float(s["gain"]) * 2.0 * kk
	var d := float(s["d"])
	var w := float(s["w"])
	w += (-float(s["k"]) * d - float(s["c"]) * w + alpha) * dt
	d += w * dt
	var m := float(s["max"]) * maxf(1.0, kk)
	if absf(d) > m:
		d = clampf(d, -m, m)
		w = 0.0
	if s["elbow"]:
		# elbow: the spring can only bend the arm more (where IK bent it), never straighten past the IK pose.
		# Everything is continuous: an instant reset to zero made the hand jump by 8 px when IK switched the bend side.
		var e0 := wrapf(base - float(s["straight"]), -PI, PI)
		var fs := float(s["flex"])
		if absf(e0) > 0.15 or (fs == 0.0 and absf(e0) > 0.08):
			fs = signf(e0) # bend side - only from a confident bend
			s["flex"] = fs
		var dPrev := float(s["d"])
		if fs == 0.0:
			d = move_toward(dPrev, 0.0, ELBOW_RETURN * dt)
			w = 0.0
		elif d * fs < 0.0:
			if dPrev * fs >= 0.0:
				d = 0.0
			else:
				d = move_toward(dPrev, 0.0, ELBOW_RETURN * dt)
			w = 0.0
	if is_nan(d) or is_nan(w):
		d = 0.0
		w = 0.0
	s["d"] = d
	s["w"] = w
	s["base"] = base
	b.rotation = base + d
	s["written"] = b.rotation
