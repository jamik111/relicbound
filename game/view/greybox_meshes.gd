class_name GreyboxMeshes
extends RefCounted
## Grey-box meshes with fake directional shading baked into vertex colours, so they read as 3D with
## unshaded materials and no lights (docs/06: vertex lighting). Instance/material colour multiplies in.

## Direction the fake light comes from: above, slightly from the camera side and the west.
const LIGHT_DIR: Vector3 = Vector3(-0.35, 1.0, 0.55)
const SHADE_MIN: float = 0.45


## A box whose bottom sits at y = 0, centred on x/z.
static func box(size: Vector3) -> ArrayMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return _baked(bm.get_mesh_arrays(), Vector3(0.0, size.y / 2.0, 0.0))


## A sphere resting on y = 0. Few segments: chunky, readable at phone size.
static func ball(radius: float, segments: int = 12, rings: int = 6) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = rings
	return _baked(sm.get_mesh_arrays(), Vector3(0.0, radius, 0.0))


## A cut-gem shape (an octahedron-ish sphere with 4 sides) resting on y = 0.
static func gem(radius: float) -> ArrayMesh:
	return ball(radius, 4, 2)


## Parts for assemble(). `center` is the part's centre; `color` is multiplied into its baked shading.
static func part_box(size: Vector3, center: Vector3, color: Color = Color.WHITE) -> Dictionary:
	var m := BoxMesh.new()
	m.size = size
	return {"arrays": m.get_mesh_arrays(), "center": center, "color": color}


static func part_ball(radius: float, center: Vector3, color: Color = Color.WHITE, segments: int = 10,
		rings: int = 5) -> Dictionary:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = rings
	return {"arrays": m.get_mesh_arrays(), "center": center, "color": color}


## A cylinder, or a cone when top_radius is 0.
static func part_cyl(bottom_radius: float, top_radius: float, height: float, center: Vector3,
		color: Color = Color.WHITE, segments: int = 8) -> Dictionary:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom_radius
	m.top_radius = top_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return {"arrays": m.get_mesh_arrays(), "center": center, "color": color}


## Joins parts into one mesh (one draw call) with shading and part colour baked into vertex colours.
static func assemble(parts: Array[Dictionary]) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var light: Vector3 = LIGHT_DIR.normalized()
	for part: Dictionary in parts:
		var arrays: Array = part["arrays"]
		var part_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var part_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var part_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var center: Vector3 = part["center"]
		var color: Color = part["color"]
		var base: int = verts.size()
		for i: int in part_verts.size():
			verts.append(part_verts[i] + center)
			normals.append(part_normals[i])
			var k: float = SHADE_MIN + (1.0 - SHADE_MIN) * maxf(part_normals[i].dot(light), 0.0)
			colors.append(Color(color.r * k, color.g * k, color.b * k))
		for index: int in part_indices:
			indices.append(base + index)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## Unshaded material that multiplies `color` with the baked vertex shading (and MultiMesh instance colour).
static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	return mat


static func _baked(arrays: Array, offset: Vector3) -> ArrayMesh:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	var light: Vector3 = LIGHT_DIR.normalized()
	for i: int in verts.size():
		verts[i] += offset
		var k: float = SHADE_MIN + (1.0 - SHADE_MIN) * maxf(normals[i].dot(light), 0.0)
		colors[i] = Color(k, k, k)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
