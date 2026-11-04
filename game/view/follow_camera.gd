class_name FollowCamera
extends Camera3D
## The game camera: orthographic, tilted 35° from straight down and turned 5° (GDD "Camera & view"),
## easing toward a target. (35° from the horizon was tried first: 1-tile walls then hid ~1.4 tiles behind them.)

## Angle below the horizon: 90° - 35° tilt from vertical.
const PITCH_DEG: float = 55.0
const YAW_DEG: float = 5.0
const DISTANCE: float = 30.0
## Tiles visible vertically. The GDD rule "the camera always shows the tiles you could move to" needs >= 3.
const VISIBLE_TILES: float = 11.0
## Higher = snappier follow (exponential smoothing rate, 1/s).
const FOLLOW_RATE: float = 8.0

var _focus: Vector3 = Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = VISIBLE_TILES
	rotation = Vector3(deg_to_rad(-PITCH_DEG), deg_to_rad(YAW_DEG), 0.0)
	near = 0.1
	far = 100.0


## Jumps straight to the target (level start, respawn).
func snap_to(target: Vector3) -> void:
	_focus = target
	_place()


## Eases toward the target. Frame-rate independent.
func follow(target: Vector3, delta: float) -> void:
	_focus = _focus.lerp(target, 1.0 - exp(-FOLLOW_RATE * delta))
	_place()


func _place() -> void:
	position = _focus + global_basis.z * DISTANCE
