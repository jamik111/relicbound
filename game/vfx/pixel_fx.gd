class_name PixelFx
extends AnimatedSprite3D
## A baked pixelfx sheet played as a billboard (docs/09_ART_PIPELINE.md §2).
## One-shots free themselves when done; loops play until removed.
## Sheets live in res://assets/fx/<name>/sheet.png + sheet.json (made by tools/bake_fx).

const SCENE_PATH: String = "res://vfx/pixel_fx.tscn"
const FX_ROOT: String = "res://assets/fx/"
## 1 VFX pixel = 1/48 tile.
const VFX_PIXEL_SIZE: float = 1.0 / 48.0
const ANIM: StringName = &"default"

## Parsed sheets, shared by every instance: name -> {frames: SpriteFrames, offset: Vector2, loop: bool}.
static var _cache: Dictionary = {}

var fx_name: String = ""


## Spawns effect `name` under `parent` with its pivot at `position`.
static func spawn(parent: Node, name: String, position: Vector3) -> PixelFx:
	var fx: PixelFx = (load(SCENE_PATH) as PackedScene).instantiate() as PixelFx
	fx.fx_name = name
	fx.position = position
	parent.add_child(fx)
	return fx


static func load_sheet(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name] as Dictionary
	var json_path: String = FX_ROOT + name + "/sheet.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not parsed is Dictionary:
		push_error("PixelFx: cannot read %s" % json_path)
		return {}
	var data: Dictionary = parsed as Dictionary
	var meta: Dictionary = (data["meta"] as Dictionary)["pixelfx"] as Dictionary
	var atlas: Texture2D = load(FX_ROOT + name + "/sheet.png") as Texture2D

	var frames := SpriteFrames.new()
	frames.set_animation_speed(ANIM, float(meta["fps"]))
	frames.set_animation_loop(ANIM, bool(meta["loop"]))
	for entry: Variant in data["frames"] as Array:
		var rect: Dictionary = (entry as Dictionary)["frame"] as Dictionary
		var tex := AtlasTexture.new()
		tex.atlas = atlas
		tex.region = Rect2(float(rect["x"]), float(rect["y"]), float(rect["w"]), float(rect["h"]))
		frames.add_frame(ANIM, tex)

	# Move the sheet's pivot (image space, y down) onto the node origin (sprite space, y up).
	var size: Array = meta["frameSize"] as Array
	var pivot: Array = meta["pivot"] as Array
	var offset_px := Vector2(float(size[0]) / 2.0 - float(pivot[0]), float(pivot[1]) - float(size[1]) / 2.0)

	var sheet: Dictionary = {"frames": frames, "offset": offset_px, "loop": bool(meta["loop"])}
	_cache[name] = sheet
	return sheet


func _ready() -> void:
	var sheet: Dictionary = load_sheet(fx_name)
	if sheet.is_empty():
		queue_free()
		return
	sprite_frames = sheet["frames"] as SpriteFrames
	offset = sheet["offset"] as Vector2
	pixel_size = VFX_PIXEL_SIZE
	if not bool(sheet["loop"]):
		animation_finished.connect(queue_free)
	play(ANIM)
