extends Node
## Vehicle designs: presets, a random contraption generator, save/load and stats.
## A design is {"name": String, "blocks": [{"id", "p": [x, y, z], "r", "c", "cfg"}]}.

const DIR := "user://designs"
const NEIGHBORS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const SCHEMES := [
	["#3fa9ff", "#2b2f36"], ["#ff7a2f", "#2b2f36"], ["#e53935", "#f2f2f2"], ["#3ddc84", "#1d3b2a"],
	["#ffcc00", "#2b2f36"], ["#b98cff", "#2a2140"], ["#f2f2f2", "#e53935"], ["#ff5ec4", "#3fd6c6"],
	["#59616c", "#ffcc00"], ["#1e88e5", "#ffcc00"], ["#8d6e63", "#3ddc84"], ["#26c6da", "#ff7043"],
]
const WEAPONS := ["mg", "cannon", "rockets", "laser", "flamer", "turret"]


class DB:
	var blocks := []
	var cells := {}

	func has(x: int, y: int, z: int) -> bool:
		return cells.has(Vector3i(x, y, z))

	func add(id: String, x: int, y: int, z: int, r := 0, c := "", cfg := {}) -> void:
		var k := Vector3i(x, y, z)
		if cells.has(k):
			return
		var b := {"id": id, "p": [x, y, z], "r": r, "c": c, "cfg": cfg.duplicate()}
		cells[k] = b
		blocks.append(b)

	func put(id: String, x: int, y: int, z: int, r := 0, c := "", cfg := {}) -> void:
		remove(x, y, z)
		add(id, x, y, z, r, c, cfg)

	func remove(x: int, y: int, z: int) -> void:
		var k := Vector3i(x, y, z)
		if cells.has(k):
			blocks.erase(cells[k])
			cells.erase(k)

	## Adds at x and at -x (mirrored orientation).
	func sym(id: String, x: int, y: int, z: int, r := 0, c := "", cfg := {}) -> void:
		add(id, x, y, z, r, c, cfg)
		if x != 0:
			add(id, -x, y, z, Blocks.mirror_index(r), c, cfg)

	func done(nm: String) -> Dictionary:
		return {"name": nm, "blocks": blocks}


# ---------------------------------------------------------------- presets

func presets() -> Array:
	var out := []
	out.append(_car({"name": "Starter Buggy", "len": 5, "hw": 1, "scheme": ["#3fa9ff", "#2b2f36"], "gadgets": ["light", "horn"]}))
	out.append(_car({"name": "Battle Buggy", "len": 5, "hw": 1, "scheme": ["#ffcc00", "#2b2f36"], "weapons": ["mg", "mg"], "gadgets": ["jump", "smoke", "light"]}))
	out.append(_car({"name": "Monster Masher", "len": 6, "hw": 1, "big": true, "scheme": ["#3ddc84", "#1d3b2a"], "gadgets": ["jump", "light", "horn"], "rockets": 1, "weapons": ["flamer"]}))
	out.append(_car({"name": "Iron Rhino Tank", "len": 7, "hw": 1, "armor": true, "six": true, "scheme": ["#5c6b4a", "#2b2f36"], "weapons": ["cannon", "turret"], "gadgets": ["light", "tnt"]}))
	out.append(_car({"name": "Nitro Rocket Car", "len": 6, "hw": 1, "scheme": ["#e53935", "#f2f2f2"], "rockets": 2, "spoiler": true, "gadgets": ["parachute", "smoke"]}))
	out.append(_plane({"name": "Sky Sparrow", "engine": "prop", "span": 4, "rows": 1, "nose": 2, "tail": 3, "scheme": ["#f2f2f2", "#e53935"], "weapons": ["mg", "mg"], "gadgets": ["smoke"]}))
	out.append(_plane({"name": "Thunder Jet", "engine": "jet2", "span": 4, "rows": 2, "nose": 3, "tail": 3, "scheme": ["#59616c", "#ffcc00"], "weapons": ["mg", "mg", "rockets", "rockets"], "gadgets": []}))
	out.append(_plane({"name": "Bomber Pelican", "engine": "prop2", "span": 5, "rows": 2, "nose": 2, "tail": 4, "scheme": ["#8d6e63", "#3ddc84"], "weapons": ["turret"], "bombs": 2, "gadgets": ["parachute"]}))
	out.append(_heli({"name": "Hornet Chopper", "scheme": ["#1e88e5", "#ffcc00"], "weapons": ["rockets", "rockets", "mg"]}))
	out.append(_boat({"name": "Wave Rider", "len": 6, "hw": 1, "scheme": ["#f2f2f2", "#1e88e5"], "weapons": ["mg"], "gadgets": ["smoke", "horn"]}))
	out.append(_boat({"name": "Gunboat Kraken", "len": 8, "hw": 2, "scheme": ["#59616c", "#e53935"], "weapons": ["cannon", "turret", "rockets"], "gadgets": ["light"]}))
	out.append(_barge())
	return out


# ---------------------------------------------------------------- generators

func _slots(b: DB, cand: Array) -> Array:
	var out := []
	for c: Vector3i in cand:
		if not b.has(c.x, c.y, c.z):
			out.append(c)
	return out


func _car(o: Dictionary) -> Dictionary:
	var b := DB.new()
	var L: int = o.get("len", 5)
	var hw: int = o.get("hw", 1)
	var big: bool = o.get("big", false)
	var col: String = o.scheme[0]
	var acc: String = o.scheme[1]
	var mat := "armor" if o.get("armor", false) else "cube"
	var y := 1 if big else 0
	var z0 := -(L / 2)
	var z1 := z0 + L - 1
	for z in range(z0, z1 + 1):
		for x in range(-hw, hw + 1):
			b.add(mat, x, y, z, 0, col)
	b.put("seat", 0, y, 0)
	for x in range(-hw, hw + 1):
		b.add("wedge", x, y, z0 - 1, 0, acc if mat == "armor" else col)
	# wheels
	var wz := [z0, z1]
	if o.get("six", false) or mat == "armor":
		wz = [z0, (z0 + z1) / 2, z1]
	var wid := "bigwheel" if big else "wheel"
	# heavy armor gets beefier wheel motors
	var wcfg: Dictionary = Blocks.defs[wid].cfg.duplicate()
	if mat == "armor":
		wcfg["pow"] = 175
	for z in wz:
		if big:
			b.sym("cube", hw + 1, y, z, 0, acc)
			b.sym(wid, hw + 1, y - 1, z, 0, "", wcfg)
		else:
			b.sym(wid, hw + 1, y, z, 0, "", wcfg)
	# rear deck / roll bar
	b.sym("cube", hw, y + 1, 1, 0, acc)
	if hw > 0:
		b.add("cube", 0, y + 1, 1, 0, acc)
	# weapons on the front deck
	var top := y + 1
	var slots := _slots(b, [Vector3i(1, top, z0), Vector3i(-1, top, z0), Vector3i(0, top, z0), Vector3i(1, top, z0 + 1), Vector3i(-1, top, z0 + 1), Vector3i(0, top, -1)])
	for w in o.get("weapons", []):
		if slots.is_empty():
			break
		var s: Vector3i = slots.pop_front()
		b.add(w, s.x, s.y, s.z)
	# rockets
	var rk: int = o.get("rockets", 0)
	if rk == 1:
		b.add("rocket", 0, y, z1 + 1)
	elif rk >= 2:
		b.sym("rocket", 1, y, z1 + 1)
	if o.get("spoiler", false):
		var down := Blocks.rot_toward(Vector3.FORWARD, Vector3.DOWN)
		for x in range(-hw, hw + 1):
			b.add("wing", x, y + 2, 1, down, acc)
	for g in o.get("gadgets", []):
		match g:
			"light":
				b.sym("light", hw, top, z0)
			"jump":
				if big:
					b.add("jump", 0, y - 1, 0)
				else:
					b.add("jump", 0, top, 0, 0, acc)
			"smoke":
				b.add("smoke", 0, top, z1, 0, acc)
			"horn":
				b.add("horn", 0, top, z0 + 1)
			"parachute":
				b.add("parachute", 0, top, z1 - 1)
			"tnt":
				b.add("tnt", 0, top, z1)
			"magnet":
				b.add("magnet", 0, y, z1 + 1)
	return b.done(o.get("name", "Car"))


func _plane(o: Dictionary) -> Dictionary:
	var best := {}
	var best_err := 999.0
	for wz in [-1, 0, 1, 2]:
		var d := _plane_at(o, wz)
		var err := absf((_com_z(d.blocks) - _lift_z(d.blocks)) + 0.35)
		if err < best_err:
			best_err = err
			best = d
	return best


func _plane_at(o: Dictionary, wz: int) -> Dictionary:
	var b := DB.new()
	var col: String = o.scheme[0]
	var acc: String = o.scheme[1]
	var nose: int = o.get("nose", 2)
	var tail: int = o.get("tail", 3)
	var span: int = o.get("span", 4)
	var rows: int = o.get("rows", 1)
	var eng: String = o.get("engine", "prop")
	b.add("seat", 0, 0, 0)
	for z in range(-nose, tail + 1):
		b.add("cube", 0, 0, z, 0, col)
	match eng:
		"prop":
			b.add("prop", 0, 0, -nose - 1, 0, acc)
		"prop2":
			b.add("wedge", 0, 0, -nose - 1, 0, col)
		_:
			b.add("wedge", 0, 0, -nose - 1, 0, col)
	# engines
	match eng:
		"jet":
			b.add("jet", 0, 0, tail + 1)
		"jet2":
			b.sym("jet", 1, 0, tail - 1)
		"thruster":
			b.sym("thruster", 1, 0, tail - 1)
			b.add("thruster", 0, 0, tail + 1)
		"prop2":
			b.sym("prop", 2, 0, wz - 1, 0, acc)
	# wings
	for r in rows:
		for x in range(1, span + 1 - r):
			b.sym("wing", x, 0, wz + r, 0, col)
	# ailerons on the trailing edge of the outer wing
	var az := wz + rows
	for x in [span - rows, span - rows - 1]:
		if x >= 1:
			b.sym("flap", x, 0, az, 0, acc)
	# tail
	b.sym("flap", 1, 0, tail, 0, acc)
	b.sym("flap", 2, 0, tail, 0, acc)
	var fin := Blocks.rot_toward(Vector3.FORWARD, Vector3.RIGHT)
	b.add("flap", 0, 1, tail, fin, acc)
	b.add("wing", 0, 1, tail - 1, fin, col)
	# landing gear
	b.add("wheel", 0, -1, -nose)
	b.sym("wheel", 1, -1, wz)
	# weapons
	var slots := _slots(b, [Vector3i(1, 0, -nose), Vector3i(-1, 0, -nose), Vector3i(3, -1, wz), Vector3i(-3, -1, wz), Vector3i(0, 1, -1), Vector3i(0, -1, 1)])
	for w in o.get("weapons", []):
		if slots.is_empty():
			break
		var s: Vector3i = slots.pop_front()
		b.add(w, s.x, s.y, s.z)
	# make sure it can actually get off the ground
	var spots := [2, 4, 1, 3]
	while _thrust(b.blocks) < _mass(b.blocks) * 9.8 * 0.55 and not spots.is_empty():
		var x: int = spots.pop_front()
		if x <= span - 1:
			b.sym("thruster", x, -1, wz, 0, acc)
	for i in o.get("bombs", 0):
		b.add("bombs", 0, -1, i + 2)
	for g in o.get("gadgets", []):
		match g:
			"smoke":
				b.sym("smoke", span - rows, 1, wz, 0, acc)
			"parachute":
				b.add("parachute", 0, 1, 0)
			"light":
				b.add("light", 0, -1, -nose + 1)
	return b.done(o.get("name", "Plane"))


func _heli(o: Dictionary) -> Dictionary:
	var b := DB.new()
	var col: String = o.scheme[0]
	var acc: String = o.scheme[1]
	b.add("seat", 0, 0, 0)
	b.add("wedge", 0, 0, -2, 0, acc)
	b.add("cube", 0, 0, -1, 0, col)
	b.sym("cube", 1, 0, 0, 0, col)
	b.sym("cube", 1, 0, -1, 0, col)
	for z in range(1, 6):
		b.add("cube", 0, 0, z, 0, col)
	b.add("rotor", 0, 1, -1)
	b.add("rotor", 0, 1, 3)
	b.add("gyro", 0, 1, 1)
	b.add("thruster", 0, 0, 6)
	var fin := Blocks.rot_toward(Vector3.FORWARD, Vector3.RIGHT)
	b.add("wing", 0, 1, 5, fin, acc)
	b.sym("wheel", 1, -1, 0, 0, acc, {"drive": false, "steer": "off", "pow": 100})
	b.add("wheel", 0, -1, 4, 0, acc, {"drive": false, "steer": "off", "pow": 100})
	var slots := _slots(b, [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, -1, -1), Vector3i(2, 0, -1), Vector3i(-2, 0, -1)])
	for w in o.get("weapons", []):
		if slots.is_empty():
			break
		var s: Vector3i = slots.pop_front()
		b.add(w, s.x, s.y, s.z)
	# enough rotors to hover with a healthy margin
	var extra := [Vector3i(1, 1, -1), Vector3i(1, 1, 3)]
	while _mass(b.blocks) * 9.8 > 0.72 * _rotors(b.blocks) * Blocks.defs["rotor"].thrust and not extra.is_empty():
		var e: Vector3i = extra.pop_front()
		b.sym("cube", e.x, 0, e.z, 0, col)
		b.sym("rotor", e.x, 1, e.z)
	return b.done(o.get("name", "Chopper"))


func _mass(blocks: Array) -> float:
	var m := 0.0
	for b in blocks:
		m += Blocks.defs[b.id].mass
	return m


func _thrust(blocks: Array) -> float:
	var t := 0.0
	for b in blocks:
		if b.id in ["thruster", "jet", "prop"]:
			t += Blocks.defs[b.id].thrust
	return t


func _rotors(blocks: Array) -> int:
	var n := 0
	for b in blocks:
		if b.id == "rotor":
			n += 1
	return n


func _boat(o: Dictionary) -> Dictionary:
	var b := DB.new()
	var L: int = o.get("len", 6)
	var hw: int = o.get("hw", 1)
	var col: String = o.scheme[0]
	var acc: String = o.scheme[1]
	var z0 := -(L / 2)
	var z1 := z0 + L - 1
	for z in range(z0, z1 + 1):
		for x in range(-hw, hw + 1):
			b.add("wood", x, 0, z, 0, col)
	for x in range(-hw, hw + 1):
		b.add("wedge", x, 0, z0 - 1, 0, col)
	b.add("seat", 0, 1, 0)
	b.add("plate", 0, 1, -1, 0, acc)
	b.sym("float", hw + 1, 0, z0 + 1)
	b.sym("float", hw + 1, 0, z1 - 1)
	b.sym("boatprop", 1, -1, z1)
	var fin := Blocks.rot_toward(Vector3.FORWARD, Vector3.RIGHT)
	b.add("flap", 0, -1, z1, fin, acc)
	var top := 1
	var slots := _slots(b, [Vector3i(0, top, z0), Vector3i(1, top, z0 + 1), Vector3i(-1, top, z0 + 1), Vector3i(0, top, z1), Vector3i(hw, top, 1), Vector3i(-hw, top, 1)])
	for w in o.get("weapons", []):
		if slots.is_empty():
			break
		var s: Vector3i = slots.pop_front()
		b.add(w, s.x, s.y, s.z)
	for g in o.get("gadgets", []):
		match g:
			"smoke":
				b.sym("smoke", hw, top, z1, 0, acc)
			"horn":
				b.add("horn", 0, top, -2)
			"light":
				b.sym("light", hw, top, z0)
	return b.done(o.get("name", "Boat"))


func _barge() -> Dictionary:
	var b := DB.new()
	for z in range(-2, 3):
		for x in range(-2, 3):
			b.add("wood", x, 0, z, 0, "#a1887f")
	b.put("seat", 0, 0, 0)
	for p in [Vector3i(2, 1, 2), Vector3i(2, 1, -2)]:
		b.sym("balloon", p.x, p.y, p.z, 0, "#ff4f6d")
	b.add("balloon", 0, 1, 0, 0, "#ffcc00")
	var up := Blocks.rot_toward(Vector3.UP, Vector3.BACK)
	b.sym("thruster", 2, -1, 0, up, "", {"ch": "lift", "inv": false, "pow": 100})
	b.sym("prop", 1, 0, -3, 0, "#ffcc00")
	b.add("gyro", 0, -1, 0)
	b.sym("bombs", 1, -1, 1)
	b.sym("wheel", 2, -1, -2, 0, "", {"drive": true, "steer": "auto", "pow": 100})
	b.sym("flap", 0 + 1, 0, 3, 0, "#3fa9ff")
	b.add("flap", 0, 1, 1, Blocks.rot_toward(Vector3.FORWARD, Vector3.RIGHT), "#3fa9ff")
	return b.done("Balloon Barge")


## A random but working contraption.
func random_design() -> Dictionary:
	var scheme: Array = SCHEMES.pick_random()
	var wpn := []
	for i in randi_range(1, 3):
		wpn.append(WEAPONS.pick_random())
	var adjectives := ["Mega", "Turbo", "Rusty", "Angry", "Sneaky", "Wobbly", "Hyper", "Cosmic", "Feral", "Grumpy", "Sparkly", "Atomic"]
	var nouns := ["Beetle", "Thunder", "Noodle", "Falcon", "Brick", "Dragon", "Toaster", "Shark", "Comet", "Llama", "Hornet", "Tractor"]
	var nm: String = "%s %s" % [adjectives.pick_random(), nouns.pick_random()]
	var kind: String = ["car", "car", "monster", "plane", "plane", "heli", "boat"].pick_random()
	match kind:
		"car", "monster":
			var g := []
			for gd in ["light", "jump", "smoke", "horn", "parachute", "tnt", "magnet"]:
				if randf() < 0.35:
					g.append(gd)
			return _car({"name": nm, "len": randi_range(4, 7), "hw": randi_range(1, 2), "big": kind == "monster",
				"armor": randf() < 0.25, "six": randf() < 0.3, "scheme": scheme, "weapons": wpn, "gadgets": g,
				"rockets": randi_range(0, 2) if randf() < 0.4 else 0, "spoiler": randf() < 0.4})
		"plane":
			var eng: String = ["prop", "prop2", "jet", "jet2", "thruster"].pick_random()
			return _plane({"name": nm, "engine": eng, "span": randi_range(3, 5), "rows": randi_range(1, 2),
				"nose": randi_range(2, 3), "tail": randi_range(3, 4), "scheme": scheme, "weapons": wpn,
				"bombs": randi_range(0, 1), "gadgets": ["smoke"] if randf() < 0.5 else []})
		"heli":
			return _heli({"name": nm, "scheme": scheme, "weapons": wpn})
	return _boat({"name": nm, "len": randi_range(5, 8), "hw": randi_range(1, 2), "scheme": scheme, "weapons": wpn,
		"gadgets": ["smoke", "horn"] if randf() < 0.5 else ["light"]})


# ---------------------------------------------------------------- analysis

static func cell_of(b: Dictionary) -> Vector3i:
	return Vector3i(int(b.p[0]), int(b.p[1]), int(b.p[2]))


func _com_z(blocks: Array) -> float:
	var m := 0.0
	var z := 0.0
	for b in blocks:
		var bm: float = Blocks.defs[b.id].mass
		m += bm
		z += bm * float(b.p[2])
	return z / maxf(m, 1.0)


func _lift_z(blocks: Array) -> float:
	var n := 0
	var z := 0.0
	for b in blocks:
		if b.id == "wing" and Blocks.rots[int(b.r)].y.y > 0.9:
			n += 1
			z += float(b.p[2])
	return z / maxf(n, 1)


## Returns the set of cells connected to the seat.
func connected(blocks: Array) -> Dictionary:
	var cells := {}
	var seat := Vector3i.MAX
	for b in blocks:
		var c := cell_of(b)
		cells[c] = b
		if b.id == "seat":
			seat = c
	var seen := {}
	if seat == Vector3i.MAX:
		return seen
	seen[seat] = true
	var stack := [seat]
	while not stack.is_empty():
		var c: Vector3i = stack.pop_back()
		for d in NEIGHBORS:
			var n: Vector3i = c + d
			if cells.has(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	return seen


func stats(d: Dictionary) -> Dictionary:
	var s := {"blocks": 0, "mass": 0.0, "thrust": 0.0, "wings": 0, "weapons": 0, "wheels": 0, "floats": 0.0,
		"lift_max": 0.0, "com": Vector3.ZERO, "col": Vector3.ZERO, "has_seat": false, "loose": 0}
	var com := Vector3.ZERO
	var col := Vector3.ZERO
	for b in d.blocks:
		var def: Dictionary = Blocks.defs.get(b.id, {})
		if def.is_empty():
			continue
		s.blocks += 1
		s.mass += def.mass
		com += Vector3(cell_of(b)) * def.mass
		s.floats += def.buoy * 9800.0
		match def.cat:
			"Weapons":
				s.weapons += 1
		if def.has("thrust") and b.id != "rotor":
			s.thrust += def.thrust
		if b.id == "rotor":
			s.lift_max += def.thrust
		if b.id == "balloon":
			s.lift_max += def.lift
		if b.id == "wing":
			s.wings += 1
			col += Vector3(cell_of(b))
		if b.id == "wheel" or b.id == "bigwheel":
			s.wheels += 1
		if b.id == "seat":
			s.has_seat = true
	if s.mass > 0:
		s.com = com / s.mass
	if s.wings > 0:
		s.col = col / s.wings
	s.loose = s.blocks - connected(d.blocks).size()
	return s


# ---------------------------------------------------------------- save / load

func _safe(nm: String) -> String:
	var out := ""
	for ch in nm.strip_edges():
		if ch.is_valid_identifier() or ch.is_valid_int() or ch == " " or ch == "-":
			out += ch
	out = out.strip_edges()
	return out if out != "" else "Untitled"


func save_design(d: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var nm := _safe(d.get("name", "Untitled"))
	var path := "%s/%s.json" % [DIR, nm]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(d, "\t"))
	return path


func list_saved() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out


func load_design(nm: String) -> Dictionary:
	var path := "%s/%s.json" % [DIR, nm]
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("blocks"):
		return {}
	return data


func delete_design(nm: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [DIR, nm])


func empty_design() -> Dictionary:
	return {"name": "My Vehicle", "blocks": [{"id": "seat", "p": [0, 0, 0], "r": 0, "c": "", "cfg": {}}]}
