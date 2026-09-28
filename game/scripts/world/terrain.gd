class_name Terrain
extends Node3D
## Ground for one map: an analytic heightfield (smooth, so launches off crests
## are real physics), wooden ramps, and solid landmark footprints.
##
## height(x, z) is exact and used by the player. grid_height(x, z) is a fast
## lookup used by enemies, pickups and decoration.

const CELL := 1.0          ## Height grid spacing (m).
const CHUNK := 32          ## Mesh chunk size in cells.
const GBIN := 20.0         ## Bin size for hill lookups.
const SBIN := 16.0         ## Bin size for structure lookups.
const GS := 8              ## Floats per hill: x z h ax az cos sin cut2
const MS := 5              ## Floats per mesa: x z h r0 r1
const RS := 13             ## Floats per ramp: x z dx dz len hw slope h0 minx maxx minz maxz H
const SS := 12             ## Floats per solid: kind x z a b cos sin top minx maxx minz maxz
const RIM_BAND := 30.0     ## Width of the quarter-pipe band inside the cliffs.
const RIM_H := 10.0
const CLIFF_W := 6.0
const CLIFF_H := 16.0

var map: MapDef
var half := 160.0
## Gradient of the last height()/base_height() call.
var gx := 0.0
var gz := 0.0

var _hills := PackedFloat32Array()
var _hill_bins: Array[PackedInt32Array] = []
var _hbn := 0
var _mesas := PackedFloat32Array()
var _ramps := PackedFloat32Array()
var _solids := PackedFloat32Array()
var _solid_bins: Array[PackedInt32Array] = []
var _sbn := 0

var _n := 0                          ## Grid samples per side.
var _base := PackedFloat32Array()    ## Terrain only (mesh).
var _full := PackedFloat32Array()    ## Terrain + ramps + solids (enemies, props).
var _path := PackedFloat32Array()    ## 0..1 dirt path mask.


func setup(m: MapDef) -> void:
	map = m
	half = m.half_size
	_build_features()
	_build_grids()
	_build_mesh()
	_build_ramp_meshes()


# -----------------------------------------------------------------------------
# Queries
# -----------------------------------------------------------------------------
## Terrain height without ramps or solids. Sets gx/gz.
func base_height(x: float, z: float) -> float:
	var r := map.rolling
	var k1 := 1.0 / r.y
	var k1z := k1 * 1.15
	var k2 := 1.0 / r.w
	var sx := sin(x * k1)
	var cx := cos(x * k1)
	var sz := sin(z * k1z)
	var cz := cos(z * k1z)
	var sxz := sin((x + z) * k2)
	var cxz := cos((x + z) * k2)
	var h := r.x * sx * cz + r.z * sxz
	var dx := r.x * k1 * cx * cz + r.z * k2 * cxz
	var dz := -r.x * k1z * sx * sz + r.z * k2 * cxz

	var bx := clampi(int((x + half) / GBIN), 0, _hbn - 1)
	var bz := clampi(int((z + half) / GBIN), 0, _hbn - 1)
	for i in _hill_bins[bz * _hbn + bx]:
		var o := i * GS
		var ox := x - _hills[o]
		var oz := z - _hills[o + 1]
		if ox * ox + oz * oz > _hills[o + 7]:
			continue
		var c := _hills[o + 5]
		var s := _hills[o + 6]
		var u := c * ox + s * oz
		var v := -s * ox + c * oz
		var ax := _hills[o + 3]
		var az := _hills[o + 4]
		var e := _hills[o + 2] * exp(-(u * u * ax + v * v * az))
		h += e
		var du := -2.0 * ax * u * e
		var dv := -2.0 * az * v * e
		dx += du * c - dv * s
		dz += du * s + dv * c

	for o in range(0, _mesas.size(), MS):
		var ox := x - _mesas[o]
		var oz := z - _mesas[o + 1]
		var r1 := _mesas[o + 4]
		var d2 := ox * ox + oz * oz
		if d2 >= r1 * r1:
			continue
		var d := sqrt(d2)
		var r0 := _mesas[o + 3]
		var t := clampf((r1 - d) / (r1 - r0), 0.0, 1.0)
		h += _mesas[o + 2] * t * t * (3.0 - 2.0 * t)
		if t > 0.0 and t < 1.0 and d > 0.001:
			var k := _mesas[o + 2] * 6.0 * t * (1.0 - t) * (-1.0 / (r1 - r0)) / d
			dx += k * ox
			dz += k * oz

	# Quarter-pipe band, then cliffs, along every edge.
	var edge := half - CLIFF_W
	var band := edge - RIM_BAND
	var ax_ := absf(x)
	if ax_ > band:
		var sg := signf(x)
		var t := minf((ax_ - band) / RIM_BAND, 1.0)
		h += RIM_H * t * t
		dx += sg * 2.0 * RIM_H * t / RIM_BAND if ax_ < edge else 0.0
		if ax_ > edge:
			var t2 := (ax_ - edge) / CLIFF_W
			h += CLIFF_H * t2 * t2
			dx += sg * 2.0 * CLIFF_H * t2 / CLIFF_W
	var az_ := absf(z)
	if az_ > band:
		var sg := signf(z)
		var t := minf((az_ - band) / RIM_BAND, 1.0)
		h += RIM_H * t * t
		dz += sg * 2.0 * RIM_H * t / RIM_BAND if az_ < edge else 0.0
		if az_ > edge:
			var t2 := (az_ - edge) / CLIFF_W
			h += CLIFF_H * t2 * t2
			dz += sg * 2.0 * CLIFF_H * t2 / CLIFF_W

	gx = dx
	gz = dz
	return h


## Exact ground height for the player: terrain, ramps and solid tops. Sets gx/gz.
func height(x: float, z: float) -> float:
	var h := base_height(x, z)
	for o in range(0, _ramps.size(), RS):
		if x < _ramps[o + 8] or x > _ramps[o + 9] or z < _ramps[o + 10] or z > _ramps[o + 11]:
			continue
		var ox := x - _ramps[o]
		var oz := z - _ramps[o + 1]
		var ddx := _ramps[o + 2]
		var ddz := _ramps[o + 3]
		var u := ox * ddx + oz * ddz
		if u < 0.0 or u > _ramps[o + 4]:
			continue
		if absf(-ox * ddz + oz * ddx) > _ramps[o + 5]:
			continue
		var top := _ramps[o + 7] + _ramps[o + 6] * u
		if top > h:
			h = top
			gx = _ramps[o + 6] * ddx
			gz = _ramps[o + 6] * ddz
	var top_s := _solid_top(x, z, 0.0)
	if top_s > h:
		h = top_s
		gx = 0.0
		gz = 0.0
	return h


## Fast bilinear ground height (includes ramps and solid tops).
func grid_height(x: float, z: float) -> float:
	var fx := clampf((x + half) / CELL, 0.0, _n - 1.001)
	var fz := clampf((z + half) / CELL, 0.0, _n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var o := iz * _n + ix
	var a := _full[o]
	var b := _full[o + 1]
	var c := _full[o + _n]
	var d := _full[o + _n + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


## Terrain-only bilinear height (for placing things on the ground mesh).
func base_grid_height(x: float, z: float) -> float:
	var fx := clampf((x + half) / CELL, 0.0, _n - 1.001)
	var fz := clampf((z + half) / CELL, 0.0, _n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var o := iz * _n + ix
	return lerpf(lerpf(_base[o], _base[o + 1], fx - ix), lerpf(_base[o + _n], _base[o + _n + 1], fx - ix), fz - iz)


## Pushes a circle of radius r out of solid footprints. Returns the new position.
func push_out(p: Vector2, r: float) -> Vector2:
	var b := _solid_bin(p.x, p.y)
	if b < 0:
		return p
	for i in _solid_bins[b]:
		var o := i * SS
		if p.x < _solids[o + 8] - r or p.x > _solids[o + 9] + r or p.y < _solids[o + 10] - r or p.y > _solids[o + 11] + r:
			continue
		var ox := p.x - _solids[o + 1]
		var oz := p.y - _solids[o + 2]
		if _solids[o] == 0.0:
			var c := _solids[o + 5]
			var s := _solids[o + 6]
			var u := ox * c - oz * s
			var w := ox * s + oz * c
			var pu := _solids[o + 3] + r - absf(u)
			var pw := _solids[o + 4] + r - absf(w)
			if pu <= 0.0 or pw <= 0.0:
				continue
			if pu < pw:
				u += signf(u) * pu
			else:
				w += signf(w) * pw
			p = Vector2(_solids[o + 1] + u * c + w * s, _solids[o + 2] - u * s + w * c)
		else:
			var rr := _solids[o + 3] + r
			var d2 := ox * ox + oz * oz
			if d2 >= rr * rr or d2 < 0.0001:
				continue
			var d := sqrt(d2)
			p = Vector2(_solids[o + 1] + ox / d * rr, _solids[o + 2] + oz / d * rr)
	return p


## True if the point is inside a solid footprint (grown by margin).
func in_solid(x: float, z: float, margin := 0.0) -> bool:
	return _solid_top(x, z, margin) > -INF


func clamp_to_map(p: Vector2, margin := 1.0) -> Vector2:
	var m := half - margin
	return Vector2(clampf(p.x, -m, m), clampf(p.y, -m, m))


## Smoothstep-weighted 0..1 dirt path mask (for placing things off paths).
func path_mask(x: float, z: float) -> float:
	var ix := clampi(int((x + half) / CELL + 0.5), 0, _n - 1)
	var iz := clampi(int((z + half) / CELL + 0.5), 0, _n - 1)
	return _path[iz * _n + ix]


## Ground color at a point (linear), matching the terrain mesh palette.
func color_at(x: float, z: float) -> Color:
	var ix := clampi(int((x + half) / CELL + 0.5), 1, _n - 2)
	var iz := clampi(int((z + half) / CELL + 0.5), 1, _n - 2)
	var o := iz * _n + ix
	var nrm := Vector3(_base[o - 1] - _base[o + 1], 2.0 * CELL, _base[o - _n] - _base[o + _n]).normalized()
	return _ground_color(x, z, _base[o], nrm.y, _path[o]).srgb_to_linear()


## Up-component of the terrain normal from the grid (1 = flat).
func grid_normal_y(x: float, z: float) -> float:
	var ix := clampi(int((x + half) / CELL + 0.5), 1, _n - 2)
	var iz := clampi(int((z + half) / CELL + 0.5), 1, _n - 2)
	var o := iz * _n + ix
	return Vector3(_base[o - 1] - _base[o + 1], 2.0 * CELL, _base[o - _n] - _base[o + _n]).normalized().y


func slope_at(x: float, z: float) -> float:
	base_height(x, z)
	return sqrt(gx * gx + gz * gz)


# -----------------------------------------------------------------------------
# Building
# -----------------------------------------------------------------------------
func _build_features() -> void:
	_hbn = int(ceil(2.0 * half / GBIN))
	_hill_bins.resize(_hbn * _hbn)
	for i in _hill_bins.size():
		_hill_bins[i] = PackedInt32Array()
	for hl in map.hills:
		var i := _hills.size() / GS
		var sx: float = hl.sx
		var sz: float = hl.sz
		var cut := 3.6 * maxf(sx, sz)
		_hills.append_array([hl.pos.x, hl.pos.y, hl.h, 1.0 / (2.0 * sx * sx), 1.0 / (2.0 * sz * sz), cos(hl.rot), sin(hl.rot), cut * cut])
		var bx0 := clampi(int((hl.pos.x - cut + half) / GBIN), 0, _hbn - 1)
		var bx1 := clampi(int((hl.pos.x + cut + half) / GBIN), 0, _hbn - 1)
		var bz0 := clampi(int((hl.pos.y - cut + half) / GBIN), 0, _hbn - 1)
		var bz1 := clampi(int((hl.pos.y + cut + half) / GBIN), 0, _hbn - 1)
		for bz in range(bz0, bz1 + 1):
			for bx in range(bx0, bx1 + 1):
				_hill_bins[bz * _hbn + bx].append(i)
	for m in map.mesas:
		_mesas.append_array([m.pos.x, m.pos.y, m.h, m.r0, m.r1])

	for rp in map.ramps:
		var d := Vector2(cos(rp.yaw), sin(rp.yaw))
		var p: Vector2 = rp.pos
		var hw: float = rp.width * 0.5
		var length: float = rp.length
		var n := Vector2(-d.y, d.x) * hw
		var lip := p + d * length
		var xs := [p.x + n.x, p.x - n.x, lip.x + n.x, lip.x - n.x]
		var zs := [p.y + n.y, p.y - n.y, lip.y + n.y, lip.y - n.y]
		var h0 := base_height(p.x, p.y)
		_ramps.append_array([p.x, p.y, d.x, d.y, length, hw, rp.height / length, h0,
				xs.min(), xs.max(), zs.min(), zs.max(), rp.height])

	_sbn = int(ceil(2.0 * half / SBIN))
	_solid_bins.resize(_sbn * _sbn)
	for i in _solid_bins.size():
		_solid_bins[i] = PackedInt32Array()
	for lm in map.landmarks:
		var sd: Dictionary = lm.solid
		if sd.is_empty():
			continue
		var p: Vector2 = lm.pos
		var base := base_height(p.x, p.y)
		var i := _solids.size() / SS
		var ext := 0.0
		if sd.kind == "box":
			var size: Vector2 = sd.size * 0.5
			var c := cos(lm.yaw)
			var s := sin(lm.yaw)
			ext = size.length()
			_solids.append_array([0.0, p.x, p.y, size.x, size.y, c, s, base + sd.height, p.x - ext, p.x + ext, p.y - ext, p.y + ext])
		else:
			ext = sd.radius
			_solids.append_array([1.0, p.x, p.y, sd.radius, 0.0, 1.0, 0.0, base + sd.height, p.x - ext, p.x + ext, p.y - ext, p.y + ext])
		var b0x := clampi(int((p.x - ext - 2.0 + half) / SBIN), 0, _sbn - 1)
		var b1x := clampi(int((p.x + ext + 2.0 + half) / SBIN), 0, _sbn - 1)
		var b0z := clampi(int((p.y - ext - 2.0 + half) / SBIN), 0, _sbn - 1)
		var b1z := clampi(int((p.y + ext + 2.0 + half) / SBIN), 0, _sbn - 1)
		for bz in range(b0z, b1z + 1):
			for bx in range(b0x, b1x + 1):
				_solid_bins[bz * _sbn + bx].append(i)


func _solid_bin(x: float, z: float) -> int:
	if absf(x) >= half or absf(z) >= half:
		return -1
	return clampi(int((z + half) / SBIN), 0, _sbn - 1) * _sbn + clampi(int((x + half) / SBIN), 0, _sbn - 1)


func _solid_top(x: float, z: float, margin: float) -> float:
	var b := _solid_bin(x, z)
	var best := -INF
	if b < 0:
		return best
	for i in _solid_bins[b]:
		var o := i * SS
		if x < _solids[o + 8] - margin or x > _solids[o + 9] + margin or z < _solids[o + 10] - margin or z > _solids[o + 11] + margin:
			continue
		var ox := x - _solids[o + 1]
		var oz := z - _solids[o + 2]
		var inside := false
		if _solids[o] == 0.0:
			var u := ox * _solids[o + 5] - oz * _solids[o + 6]
			var w := ox * _solids[o + 6] + oz * _solids[o + 5]
			inside = absf(u) <= _solids[o + 3] + margin and absf(w) <= _solids[o + 4] + margin
		else:
			var rr := _solids[o + 3] + margin
			inside = ox * ox + oz * oz <= rr * rr
		if inside:
			best = maxf(best, _solids[o + 7])
	return best


func _build_grids() -> void:
	_n = int(2.0 * half / CELL) + 1
	var count := _n * _n
	_base.resize(count)
	_full.resize(count)
	_path.resize(count)
	_path.fill(0.0)
	for iz in _n:
		var z := -half + iz * CELL
		for ix in _n:
			var x := -half + ix * CELL
			_base[iz * _n + ix] = base_height(x, z)
	for iz in _n:
		var z := -half + iz * CELL
		for ix in _n:
			var x := -half + ix * CELL
			var o := iz * _n + ix
			var h := _base[o]
			if _near_ramp_or_solid(x, z):
				h = height(x, z)
			_full[o] = h
	# Rasterize dirt paths into a mask.
	for poly in map.paths:
		for k in poly.size() - 1:
			_stamp_segment(poly[k], poly[k + 1], 1.1, 2.4)


func _near_ramp_or_solid(x: float, z: float) -> bool:
	for o in range(0, _ramps.size(), RS):
		if x >= _ramps[o + 8] - 1.0 and x <= _ramps[o + 9] + 1.0 and z >= _ramps[o + 10] - 1.0 and z <= _ramps[o + 11] + 1.0:
			return true
	return _solid_top(x, z, 0.5) > -INF


func _stamp_segment(a: Vector2, b: Vector2, inner: float, outer: float) -> void:
	var x0 := clampi(int((minf(a.x, b.x) - outer + half) / CELL), 0, _n - 1)
	var x1 := clampi(int((maxf(a.x, b.x) + outer + half) / CELL) + 1, 0, _n - 1)
	var z0 := clampi(int((minf(a.y, b.y) - outer + half) / CELL), 0, _n - 1)
	var z1 := clampi(int((maxf(a.y, b.y) + outer + half) / CELL) + 1, 0, _n - 1)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var p := Vector2(-half + ix * CELL, -half + iz * CELL)
			var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			# Wobble the edge a little so paths don't look ruler-straight.
			d += sin(p.x * 0.7) * 0.35 + cos(p.y * 0.9) * 0.35
			var m := 1.0 - smoothstep(inner, outer, d)
			var o := iz * _n + ix
			_path[o] = maxf(_path[o], m)


func _build_mesh() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var chunks := int(ceil(float(_n - 1) / CHUNK))
	for cz in chunks:
		for cx in chunks:
			var mi := MeshInstance3D.new()
			mi.mesh = _chunk_mesh(cx * CHUNK, cz * CHUNK, mini(CHUNK, _n - 1 - cx * CHUNK), mini(CHUNK, _n - 1 - cz * CHUNK))
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)


func _chunk_mesh(ix0: int, iz0: int, w: int, h: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	for j in h + 1:
		for i in w + 1:
			var gxi := ix0 + i
			var gzi := iz0 + j
			var o := gzi * _n + gxi
			var x := -half + gxi * CELL
			var z := -half + gzi * CELL
			var hh := _base[o]
			var hl := _base[o - 1] if gxi > 0 else hh
			var hr := _base[o + 1] if gxi < _n - 1 else hh
			var hd := _base[o - _n] if gzi > 0 else hh
			var hu := _base[o + _n] if gzi < _n - 1 else hh
			var nrm := Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			verts.append(Vector3(x, hh, z))
			normals.append(nrm)
			colors.append(_ground_color(x, z, hh, nrm.y, _path[o]).srgb_to_linear())
	var row := w + 1
	for j in h:
		for i in w:
			var a := j * row + i
			idx.append_array([a, a + 1, a + row, a + 1, a + row + 1, a + row])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _ground_color(x: float, z: float, h: float, ny: float, path: float) -> Color:
	# Patchy dry grass from a couple of low-frequency waves.
	var patch := 0.5 + 0.5 * sin(x * 0.045 + sin(z * 0.06) * 1.7) * cos(z * 0.038 - x * 0.02)
	var c := map.grass.lerp(map.grass_dry, smoothstep(0.55, 0.95, patch) * 0.8)
	for t in map.tints:
		var d := Vector2(x, z).distance_to(t.pos)
		if d < t.radius:
			c = c.lerp(t.color, (1.0 - smoothstep(t.radius * 0.55, t.radius, d)) * t.strength)
	if h < -1.5:
		c = c.lerp(map.low_tint, clampf((-1.5 - h) / 5.0, 0.0, 0.6))
	c = c.lerp(map.dirt, clampf(path, 0.0, 1.0) * 0.85)
	# Steeper ground turns to dirt, then rock.
	c = c.lerp(map.dirt, smoothstep(0.86, 0.72, ny) * 0.8)
	c = c.lerp(map.rock, smoothstep(0.72, 0.5, ny))
	return c


func _build_ramp_meshes() -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	for o in range(0, _ramps.size(), RS):
		var mi := MeshInstance3D.new()
		mi.mesh = _ramp_mesh(o)
		mi.material_override = mat
		add_child(mi)


func _ramp_mesh(o: int) -> ArrayMesh:
	var p := Vector2(_ramps[o], _ramps[o + 1])
	var d := Vector2(_ramps[o + 2], _ramps[o + 3])
	var n := Vector2(-d.y, d.x)
	var length := _ramps[o + 4]
	var hw := _ramps[o + 5]
	var slope := _ramps[o + 6]
	var h0 := _ramps[o + 7]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planks := int(length / 0.55)
	var wood_a := Color(0.55, 0.35, 0.20)
	var wood_b := Color(0.47, 0.29, 0.16)
	var side := Color(0.36, 0.22, 0.12)
	var gold := Color(0.93, 0.76, 0.34)
	var up := Vector3(-d.x * slope, 1.0, -d.y * slope).normalized()
	for k in planks:
		var u0 := length * k / planks
		var u1 := length * (k + 1) / planks
		var col := gold if k == planks - 1 else (wood_a if k % 2 == 0 else wood_b)
		var a0 := p + d * u0 - n * hw
		var b0 := p + d * u0 + n * hw
		var a1 := p + d * u1 - n * hw
		var b1 := p + d * u1 + n * hw
		var y0 := h0 + slope * u0 + 0.04
		var y1 := h0 + slope * u1 + 0.04
		_quad(st, Vector3(a0.x, y0, a0.y), Vector3(a1.x, y1, a1.y), Vector3(b1.x, y1, b1.y), Vector3(b0.x, y0, b0.y), up, col)
	# Sides and the lip face, down to below the ground.
	var steps := 6
	for sgn: float in [-1.0, 1.0]:
		var nrm := Vector3(n.x * sgn, 0, n.y * sgn)
		for k in steps:
			var u0 := length * k / steps
			var u1 := length * (k + 1) / steps
			var q0 := p + d * u0 + n * hw * sgn
			var q1 := p + d * u1 + n * hw * sgn
			var t0 := h0 + slope * u0 + 0.04
			var t1 := h0 + slope * u1 + 0.04
			var g0 := base_grid_height(q0.x, q0.y) - 0.3
			var g1 := base_grid_height(q1.x, q1.y) - 0.3
			if sgn > 0:
				_quad(st, Vector3(q0.x, g0, q0.y), Vector3(q1.x, g1, q1.y), Vector3(q1.x, t1, q1.y), Vector3(q0.x, t0, q0.y), nrm, side)
			else:
				_quad(st, Vector3(q1.x, g1, q1.y), Vector3(q0.x, g0, q0.y), Vector3(q0.x, t0, q0.y), Vector3(q1.x, t1, q1.y), nrm, side)
	var la := p + d * length - n * hw
	var lb := p + d * length + n * hw
	var top := h0 + _ramps[o + 12] + 0.04
	var ga := base_grid_height(la.x, la.y) - 0.3
	var gb := base_grid_height(lb.x, lb.y) - 0.3
	_quad(st, Vector3(la.x, ga, la.y), Vector3(la.x, top, la.y), Vector3(lb.x, top, lb.y), Vector3(lb.x, gb, lb.y), Vector3(d.x, 0, d.y), side)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, dd: Vector3, nrm: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(nrm)
	for v in [a, b, c, a, c, dd]:
		st.add_vertex(v)
