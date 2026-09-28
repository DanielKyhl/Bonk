class_name Terrain
extends Node3D
## Ground for one map: an analytic heightfield (smooth, so launches off crests
## are real physics), cliffs and ravines, and solid landmark footprints.
##
## height(x, z) is exact and used by the player. grid_height(x, z) is a fast
## lookup used by enemies, pickups and decoration.

const CELL := 1.0          ## Height grid spacing (m).
const TINT_CELL := 4.0     ## Spacing of the precomputed ground color grid (m).
const CHUNK := 32          ## Mesh chunk size in cells.
const GBIN := 20.0         ## Bin size for hill lookups.
const SBIN := 16.0         ## Bin size for structure lookups.
const GS := 8              ## Floats per hill: x z h ax az cos sin cut2
const MS := 5              ## Floats per mesa: x z h r0 r1
const SS := 12             ## Floats per solid: kind x z a b cos sin top minx maxx minz maxz
const CS := 21             ## Floats per cliff: x z h rx rz cos sin edge rough ph1 ph2 ph3 sdx sdz slen scos minx maxx minz maxz kick
const RV := 10             ## Ravine header: npts hw depth edge total taper minx maxx minz maxz (then x z cum per point)
const CLIFF_W := 6.0
const CLIFF_H := 16.0

var map: MapDef
var half := 160.0
var _rim_band := 30.0                ## Width of the quarter-pipe band inside the edge cliffs.
var _rim_h := 10.0
## Gradient of the last height()/base_height() call.
var gx := 0.0
var gz := 0.0

var _hills := PackedFloat32Array()
var _hill_bins: Array[PackedInt32Array] = []
var _hbn := 0
var _mesas := PackedFloat32Array()
var _cliffs := PackedFloat32Array()
var _cliff_bins: Array[PackedInt32Array] = []   ## Cliff indices per GBIN cell.
var _ravines := PackedFloat32Array()
var _solids := PackedFloat32Array()
var _solid_bins: Array[PackedInt32Array] = []
var _sbn := 0

var _n := 0                          ## Grid samples per side.
var _base := PackedFloat32Array()    ## Terrain only (mesh).
var _full := PackedFloat32Array()    ## Terrain + solid tops (enemies, props).
var _path := PackedFloat32Array()    ## 0..1 dirt path mask.
var _rows: Array = []                ## Grid rows from worker threads.
var _rows_lock := Mutex.new()
var _chunk_data: Array = []          ## Mesh arrays per chunk from worker threads.
var _tints := PackedColorArray()     ## Base ground color (patches + region tints) every TINT_CELL meters.
var _tn := 0
static var _cache := {}              ## title|seed -> built grids and meshes


func setup(m: MapDef) -> void:
	map = m
	half = m.half_size
	_rim_band = m.rim_band
	_rim_h = m.rim_height
	_build_features()
	# The layout never changes, so a second run on the same map reuses the
	# grids and meshes built the first time.
	var key := "%s|%d" % [m.title, m.layout_seed]
	if _cache.has(key):
		var c: Dictionary = _cache[key]
		_n = c.n
		_base = c.base
		_full = c.full
		_path = c.path
		_tints = c.tints
		_tn = int(2.0 * half / TINT_CELL) + 1
		_add_chunks(c.meshes)
		return
	_build_tints()
	_build_grids()
	var meshes := _build_meshes()
	_add_chunks(meshes)
	_cache[key] = {"n": _n, "base": _base, "full": _full, "path": _path, "tints": _tints, "meshes": meshes}


# -----------------------------------------------------------------------------
# Queries
# -----------------------------------------------------------------------------
## Terrain height without solids. Sets gx/gz.
func base_height(x: float, z: float) -> float:
	var r := _eval(x, z, true)
	gx = r.y
	gz = r.z
	return r.x


## Terrain height (x) and its gradient (y, z; only when grad is true).
## Touches no member state, so grid rows can be built on worker threads.
func _eval(x: float, z: float, grad: bool) -> Vector3:
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

	# Plateaus, pits and ravines: sharp features, so a numeric gradient.
	if _carve_active(x, z):
		h += _carve(x, z)
		if grad:
			var e := 0.05
			dx += (_carve(x + e, z) - _carve(x - e, z)) / (2.0 * e)
			dz += (_carve(x, z + e) - _carve(x, z - e)) / (2.0 * e)

	# Quarter-pipe band, then cliffs, along every edge.
	var edge := half - CLIFF_W
	var band := edge - _rim_band
	var ax_ := absf(x)
	if ax_ > band:
		var sg := signf(x)
		var t := minf((ax_ - band) / _rim_band, 1.0)
		h += _rim_h * t * t
		dx += sg * 2.0 * _rim_h * t / _rim_band if ax_ < edge else 0.0
		if ax_ > edge:
			var t2 := (ax_ - edge) / CLIFF_W
			h += CLIFF_H * t2 * t2
			dx += sg * 2.0 * CLIFF_H * t2 / CLIFF_W
	var az_ := absf(z)
	if az_ > band:
		var sg := signf(z)
		var t := minf((az_ - band) / _rim_band, 1.0)
		h += _rim_h * t * t
		dz += sg * 2.0 * _rim_h * t / _rim_band if az_ < edge else 0.0
		if az_ > edge:
			var t2 := (az_ - edge) / CLIFF_W
			h += CLIFF_H * t2 * t2
			dz += sg * 2.0 * CLIFF_H * t2 / CLIFF_W

	return Vector3(h, dx, dz)


## Exact ground height for the player: terrain and solid tops. Sets gx/gz.
func height(x: float, z: float) -> float:
	var h := base_height(x, z)
	var top_s := _solid_top(x, z, 0.0)
	if top_s > h:
		h = top_s
		gx = 0.0
		gz = 0.0
	return h


## Fast bilinear ground height (includes solid tops).
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


## Ground color at a point, matching the terrain mesh palette. Colors stay in
## sRGB: the Compatibility renderer treats shader albedo as sRGB.
func color_at(x: float, z: float) -> Color:
	var ix := clampi(int((x + half) / CELL + 0.5), 1, _n - 2)
	var iz := clampi(int((z + half) / CELL + 0.5), 1, _n - 2)
	var o := iz * _n + ix
	var nrm := Vector3(_base[o - 1] - _base[o + 1], 2.0 * CELL, _base[o - _n] - _base[o + _n]).normalized()
	return _ground_color(x, z, _base[o], nrm.y, _path[o])


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
	var rng := RandomNumberGenerator.new()
	rng.seed = map.layout_seed * 31 + 5
	for c in map.cliffs:
		var p: Vector2 = c.pos
		var sdir := Vector2.ZERO
		var slen := 0.0
		var scos := 1.0
		if c.slope != INF:
			sdir = Vector2(cos(deg_to_rad(c.slope)), sin(deg_to_rad(c.slope)))
			slen = c.slope_len
			scos = cos(deg_to_rad(c.slope_width * 0.5))
		var ext: float = maxf(c.rx, c.rz) * (1.0 + c.rough) + c.edge + slen
		_cliffs.append_array([p.x, p.y, c.h, c.rx, c.rz, cos(c.rot), sin(c.rot), c.edge, c.rough,
				rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, sdir.x, sdir.y, slen, scos,
				p.x - ext, p.x + ext, p.y - ext, p.y + ext, 1.0 if c.get("kick", false) else 0.0])
	_cliff_bins.resize(_hbn * _hbn)
	for i in _cliff_bins.size():
		_cliff_bins[i] = PackedInt32Array()
	for ci in _cliffs.size() / CS:
		var o := ci * CS
		var bx0 := clampi(int((_cliffs[o + 16] + half) / GBIN), 0, _hbn - 1)
		var bx1 := clampi(int((_cliffs[o + 17] + half) / GBIN), 0, _hbn - 1)
		var bz0 := clampi(int((_cliffs[o + 18] + half) / GBIN), 0, _hbn - 1)
		var bz1 := clampi(int((_cliffs[o + 19] + half) / GBIN), 0, _hbn - 1)
		for bz in range(bz0, bz1 + 1):
			for bx in range(bx0, bx1 + 1):
				_cliff_bins[bz * _hbn + bx].append(ci)
	for rv in map.ravines:
		var pts: PackedVector2Array = rv.points
		var total := 0.0
		var body := PackedFloat32Array()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for k in pts.size():
			if k > 0:
				total += pts[k].distance_to(pts[k - 1])
			body.append_array([pts[k].x, pts[k].y, total])
			lo = lo.min(pts[k])
			hi = hi.max(pts[k])
		var m: float = rv.width * 0.5 + rv.edge
		_ravines.append_array([pts.size(), rv.width * 0.5, rv.depth, rv.edge, total, rv.taper, lo.x - m, hi.x + m, lo.y - m, hi.y + m])
		_ravines.append_array(body)

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


func _cliff_bin(x: float, z: float) -> PackedInt32Array:
	var bx := clampi(int((x + half) / GBIN), 0, _hbn - 1)
	var bz := clampi(int((z + half) / GBIN), 0, _hbn - 1)
	return _cliff_bins[bz * _hbn + bx]


## True if (x, z) is inside the bounds of any plateau, pit or ravine.
func _carve_active(x: float, z: float) -> bool:
	for ci in _cliff_bin(x, z):
		var o := ci * CS
		if x >= _cliffs[o + 16] and x <= _cliffs[o + 17] and z >= _cliffs[o + 18] and z <= _cliffs[o + 19]:
			return true
	var o := 0
	while o < _ravines.size():
		if x >= _ravines[o + 6] and x <= _ravines[o + 7] and z >= _ravines[o + 8] and z <= _ravines[o + 9]:
			return true
		o += RV + int(_ravines[o]) * 3
	return false


## Height added by plateaus and pits, minus ravines.
func _carve(x: float, z: float) -> float:
	var h := 0.0
	for ci in _cliff_bin(x, z):
		var o := ci * CS
		if x < _cliffs[o + 16] or x > _cliffs[o + 17] or z < _cliffs[o + 18] or z > _cliffs[o + 19]:
			continue
		var ox := x - _cliffs[o]
		var oz := z - _cliffs[o + 1]
		var c := _cliffs[o + 5]
		var s := _cliffs[o + 6]
		var u := (c * ox + s * oz) / _cliffs[o + 3]
		var v := (-s * ox + c * oz) / _cliffs[o + 4]
		var e := sqrt(u * u + v * v)
		var th := atan2(v, u)
		var wob := 1.0 + _cliffs[o + 8] * (0.5 * sin(3.0 * th + _cliffs[o + 9]) + 0.3 * sin(5.0 * th + _cliffs[o + 10]) + 0.2 * sin(11.0 * th + _cliffs[o + 11]))
		# Roughly how many meters inside the rim this point is.
		var inside := (1.0 - e / wob) * minf(_cliffs[o + 3], _cliffs[o + 4])
		var half_edge := _cliffs[o + 7] * 0.5
		var out := half_edge
		var slen := _cliffs[o + 14]
		if slen > 0.0:
			var dl := maxf(sqrt(ox * ox + oz * oz), 0.0001)
			var k := (ox * _cliffs[o + 12] + oz * _cliffs[o + 13]) / dl
			var w := clampf((k - _cliffs[o + 15]) / maxf(1.0 - _cliffs[o + 15], 0.001), 0.0, 1.0)
			out = lerpf(half_edge, slen, w * w * (3.0 - 2.0 * w))
		var t := clampf((inside + out) / (half_edge + out), 0.0, 1.0)
		# Kickers curve up like a quarter-pipe (steepest at the lip); the rest ease in and out.
		h += _cliffs[o + 2] * (t * t if _cliffs[o + 20] > 0.5 else t * t * (3.0 - 2.0 * t))
	var o := 0
	while o < _ravines.size():
		var n := int(_ravines[o])
		if x >= _ravines[o + 6] and x <= _ravines[o + 7] and z >= _ravines[o + 8] and z <= _ravines[o + 9]:
			var best := INF
			var along := 0.0
			for k in n - 1:
				var a := o + RV + k * 3
				var ax := _ravines[a]
				var az := _ravines[a + 1]
				var bx := _ravines[a + 3]
				var bz := _ravines[a + 4]
				var sx := bx - ax
				var sz := bz - az
				var l2 := sx * sx + sz * sz
				var t := clampf(((x - ax) * sx + (z - az) * sz) / maxf(l2, 0.0001), 0.0, 1.0)
				var qx := ax + sx * t - x
				var qz := az + sz * t - z
				var d := qx * qx + qz * qz
				if d < best:
					best = d
					along = _ravines[a + 2] + (_ravines[a + 5] - _ravines[a + 2]) * t
			var half_edge := _ravines[o + 3] * 0.5
			var t2 := clampf((_ravines[o + 1] - sqrt(best) + half_edge) / (2.0 * half_edge), 0.0, 1.0)
			var taper := _ravines[o + 5]
			var total := _ravines[o + 4]
			var fade := clampf(along / taper, 0.0, 1.0) * clampf((total - along) / taper, 0.0, 1.0)
			h -= _ravines[o + 2] * t2 * t2 * (3.0 - 2.0 * t2) * fade * fade * (3.0 - 2.0 * fade)
		o += RV + n * 3
	return h


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
	_path.resize(count)
	_path.fill(0.0)
	# Rows are independent: build them on every core.
	_rows.resize(_n)
	var task := WorkerThreadPool.add_group_task(_grid_row, _n)
	WorkerThreadPool.wait_for_group_task_completion(task)
	_base = PackedFloat32Array()
	for iz in _n:
		_base.append_array(_rows[iz])
	_rows.clear()
	# Solid tops (buildings) only matter inside their footprints.
	_full = _base.duplicate()
	for o in range(0, _solids.size(), SS):
		var x0 := clampi(int((_solids[o + 8] - 1.0 + half) / CELL), 0, _n - 1)
		var x1 := clampi(int((_solids[o + 9] + 1.0 + half) / CELL) + 1, 0, _n - 1)
		var z0 := clampi(int((_solids[o + 10] - 1.0 + half) / CELL), 0, _n - 1)
		var z1 := clampi(int((_solids[o + 11] + 1.0 + half) / CELL) + 1, 0, _n - 1)
		for iz in range(z0, z1 + 1):
			for ix in range(x0, x1 + 1):
				var i := iz * _n + ix
				_full[i] = maxf(_full[i], _solid_top(-half + ix * CELL, -half + iz * CELL, 0.0))
	# Rasterize dirt paths into a mask.
	for poly in map.paths:
		for k in poly.size() - 1:
			_stamp_segment(poly[k], poly[k + 1], 1.1, 2.4)


func _grid_row(iz: int) -> void:
	var row := PackedFloat32Array()
	row.resize(_n)
	var z := -half + iz * CELL
	for ix in _n:
		row[ix] = _eval(-half + ix * CELL, z, false).x
	_rows_lock.lock()
	_rows[iz] = row
	_rows_lock.unlock()


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


func _build_meshes() -> Array:
	var chunks := int(ceil(float(_n - 1) / CHUNK))
	# Vertex data per chunk on worker threads; meshes are made here.
	_chunk_data.resize(chunks * chunks)
	var task := WorkerThreadPool.add_group_task(_chunk_arrays.bind(chunks), chunks * chunks)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var meshes: Array[ArrayMesh] = []
	for k in chunks * chunks:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _chunk_data[k])
		meshes.append(mesh)
	_chunk_data.clear()
	return meshes


func _add_chunks(meshes: Array) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	for mesh in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _chunk_arrays(k: int, chunks: int) -> void:
	var cx := k % chunks
	var cz := k / chunks
	var arrays := _chunk_mesh(cx * CHUNK, cz * CHUNK, mini(CHUNK, _n - 1 - cx * CHUNK), mini(CHUNK, _n - 1 - cz * CHUNK))
	_rows_lock.lock()
	_chunk_data[k] = arrays
	_rows_lock.unlock()


func _chunk_mesh(ix0: int, iz0: int, w: int, h: int) -> Array:
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
			colors.append(_ground_color(x, z, hh, nrm.y, _path[o]))
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
	return arrays


func _ground_color(x: float, z: float, h: float, ny: float, path: float) -> Color:
	var c := _tint_at(x, z)
	if h < -1.5:
		c = c.lerp(map.low_tint, clampf((-1.5 - h) / 5.0, 0.0, 0.6))
	c = c.lerp(map.dirt, clampf(path, 0.0, 1.0) * 0.85)
	# Steeper ground turns to dirt, then rock.
	c = c.lerp(map.dirt, smoothstep(0.86, 0.72, ny) * 0.8)
	c = c.lerp(map.rock, smoothstep(0.72, 0.5, ny))
	return c


## Patchy dry grass and the map's region tints, sampled from the coarse grid.
func _tint_at(x: float, z: float) -> Color:
	var fx := clampf((x + half) / TINT_CELL, 0.0, _tn - 1.001)
	var fz := clampf((z + half) / TINT_CELL, 0.0, _tn - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var o := iz * _tn + ix
	return _tints[o].lerp(_tints[o + 1], tx).lerp(_tints[o + _tn].lerp(_tints[o + _tn + 1], tx), fz - iz)


func _build_tints() -> void:
	_tn = int(2.0 * half / TINT_CELL) + 1
	_tints.resize(_tn * _tn)
	for iz in _tn:
		for ix in _tn:
			var x := -half + ix * TINT_CELL
			var z := -half + iz * TINT_CELL
			var patch := 0.5 + 0.5 * sin(x * 0.045 + sin(z * 0.06) * 1.7) * cos(z * 0.038 - x * 0.02)
			var c := map.grass.lerp(map.grass_dry, smoothstep(0.55, 0.95, patch) * 0.8)
			for t in map.tints:
				var d := Vector2(x, z).distance_to(t.pos)
				if d < t.radius:
					c = c.lerp(t.color, (1.0 - smoothstep(t.radius * 0.55, t.radius, d)) * t.strength)
			_tints[iz * _tn + ix] = c


