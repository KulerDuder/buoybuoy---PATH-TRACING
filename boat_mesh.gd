# boat_mesh.gd
class_name BoatMesh
extends RefCounted

static func build_hull() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck_y: float = 0.35
	var keel_y: float = -0.45
	var outline_2d := [
		Vector2( 0.0,  2.5), Vector2( 0.7,  1.8), Vector2( 1.0,  0.5),
		Vector2( 1.0, -1.5), Vector2( 0.7, -2.0), Vector2(-0.7, -2.0),
		Vector2(-1.0, -1.5), Vector2(-1.0,  0.5), Vector2(-0.7,  1.8),
	]
	var deck_pts: Array[Vector3] = []
	var keel_pts: Array[Vector3] = []
	for p in outline_2d:
		deck_pts.append(Vector3(p.x, deck_y, p.y))
		keel_pts.append(Vector3(p.x * 0.35, keel_y, p.y * 0.85))

	var deck_center := Vector3(0, deck_y, 0)
	var keel_center := Vector3(0, keel_y, 0)
	var n: int = outline_2d.size()

	for i in n:
		_add_tri(st, deck_center, deck_pts[i], deck_pts[(i + 1) % n], Vector3.UP)
	for i in n:
		_add_tri(st, keel_center, keel_pts[i], keel_pts[(i + 1) % n], Vector3.DOWN)
	for i in n:
		var j := (i + 1) % n
		var d0 := deck_pts[i]; var d1 := deck_pts[j]
		var k0 := keel_pts[i]; var k1 := keel_pts[j]
		var mid := (d0 + d1) * 0.5
		var outward := Vector3(mid.x, 0.0, mid.z)
		_add_tri(st, d0, d1, k1, outward)
		_add_tri(st, d0, k1, k0, outward)
	return st.commit()

static func build_sail() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(0, 0.0, 0.0)
	var b := Vector3(0, 2.8, 0.0)
	var c := Vector3(0, 0.3, 1.4)
	st.set_normal(Vector3(1,0,0)); st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.set_normal(Vector3(-1,0,0)); st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	return st.commit()

static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, prefer_dir: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.length() < 0.0001: return
	if nrm.dot(prefer_dir) < 0.0:
		var tmp := b; b = c; c = tmp
		nrm = -nrm
	nrm = nrm.normalized()
	st.set_normal(nrm); st.add_vertex(a)
	st.set_normal(nrm); st.add_vertex(b)
	st.set_normal(nrm); st.add_vertex(c)
