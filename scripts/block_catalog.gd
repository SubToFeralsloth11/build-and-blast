extends RefCounted
## Every block definition. `kind` picks the simulation behaviour in vehicle.gd,
## `vis` the procedural model in blocks.gd, `shape` the collider.

static func ch(c: String, extra := {}) -> Dictionary:
	var d := {"ch": c, "inv": false, "pow": 100}
	d.merge(extra, true)
	return d


## Adds every entry of `list` ([id, name, mass, hp, color, desc, params]) to `cat`.
static func _many(B: Node, cat: String, base: Dictionary, list: Array) -> void:
	for e in list:
		var x: Dictionary = base.duplicate(true)
		x.merge(e[6], true)
		B._d(e[0], e[1], cat, e[2], e[3], e[4], e[5], x)


static func define(B: Node) -> void:
	_structure(B)
	_wheels(B)
	_mechanical(B)
	_propulsion(B)
	_flight(B)
	_water(B)
	_weapons(B)
	_gadgets(B)


static func _structure(B: Node) -> void:
	var TI := {"m": 0.75, "r": 0.3}
	var CF := {"m": 0.3, "r": 0.35, "deco": "weave"}
	var GL := {"a": 0.32, "m": 0.2, "r": 0.05}
	var WD := {"m": 0.0, "r": 0.85, "deco": "planks"}
	var AR := {"m": 0.6, "r": 0.4, "deco": "rivets"}
	var S := "Structure"
	B._d("seat", "Pilot Seat", S, 80, 400, "#ff7a2f", "The core of every vehicle. Lose it and you are wrecked.", {"kind": "seat", "buoy": 0.18, "unique": true})
	B._d("cube", "Block", S, 25, 90, "#d9dee5", "Sturdy all-round building block.", {"kind": "struct", "buoy": 0.14})
	B._d("wood", "Wood Block", S, 10, 50, "#b67a44", "Light and floats great. Perfect for boats.", {"kind": "struct", "buoy": 0.4})
	B._d("armor", "Armor Block", S, 90, 320, "#59616c", "Heavy plate that soaks up bullets and blasts.", {"kind": "struct", "buoy": 0.05})
	B._d("wedge", "Wedge", S, 18, 70, "#d9dee5", "Sloped block for noses, ramps and style.", {"kind": "struct", "shape": "wedge", "buoy": 0.1})
	B._d("plate", "Thin Plate", S, 8, 40, "#cfd5dd", "Flat floor plate. Very light.", {"kind": "struct", "shape": "plate", "buoy": 0.05})
	# [id, name, mass, hp, color, desc, {shape, surf, buoy, ...}]
	_many(B, S, {"kind": "struct", "vis": "solid"}, [
		["corner", "Corner Slope", 9, 35, "#d9dee5", "Three-way slope for nose cones and roof corners.", {"shape": "corner", "buoy": 0.05}],
		["inner", "Inner Corner", 21, 75, "#d9dee5", "A block with one corner sliced off. Joins two wedges.", {"shape": "inner", "buoy": 0.12}],
		["half", "Half Block", 13, 50, "#d9dee5", "Half-height block for low decks and steps.", {"shape": "half", "buoy": 0.07}],
		["lowwedge", "Low Wedge", 7, 30, "#d9dee5", "Gentle half-height slope. Great hoods and ramps.", {"shape": "lowwedge", "buoy": 0.05}],
		["cyl", "Cylinder", 20, 75, "#d9dee5", "Round block for barrels, fuselages and towers.", {"shape": "cyl", "buoy": 0.11}],
		["beam", "Steel Beam", 6, 40, "#c7ccd3", "Thin girder. Light frames and long arms.", {"shape": "beam", "surf": {"m": 0.6}, "buoy": 0.02}],
		["ball", "Ball Block", 13, 55, "#d9dee5", "A sphere. Rounded bumpers, heads, wheels for show.", {"shape": "ball", "buoy": 0.07}],
		["pyramid", "Pyramid", 8, 35, "#d9dee5", "Pointy cap for spikes, noses and roofs.", {"shape": "pyramid", "buoy": 0.04}],
		["truss", "Truss Frame", 9, 45, "#ff9a1f", "Open lattice frame. Strong for its weight.", {"surf": {"deco": "truss", "m": 0.5}, "buoy": 0.03}],
		["wood_wedge", "Wood Wedge", 5, 25, "#b67a44", "Floaty wooden slope.", {"shape": "wedge", "surf": WD, "buoy": 0.2}],
		["wood_half", "Wood Half", 5, 25, "#b67a44", "Half-height wooden deck.", {"shape": "half", "surf": WD, "buoy": 0.2}],
		["wood_plate", "Wood Floor", 2, 12, "#c08a52", "Thin wooden floor plank.", {"shape": "plate", "surf": WD, "buoy": 0.08}],
		["wood_corner", "Wood Corner", 3, 18, "#b67a44", "Wooden corner slope.", {"shape": "corner", "surf": WD, "buoy": 0.13}],
		["wood_beam", "Wood Pole", 3, 20, "#a26a38", "Thin wooden pole. Masts, rails, fences.", {"shape": "beam", "surf": WD, "buoy": 0.12}],
		["armor_wedge", "Armor Wedge", 45, 170, "#59616c", "Sloped armor for the front of tanks.", {"shape": "wedge", "surf": AR, "buoy": 0.03}],
		["armor_plate", "Armor Plate", 20, 110, "#59616c", "Thin bolt-on armor plate.", {"shape": "plate", "surf": AR, "buoy": 0.02}],
		["armor_corner", "Armor Corner", 30, 110, "#59616c", "Armored corner slope.", {"shape": "corner", "surf": AR, "buoy": 0.02}],
		["armor_half", "Armor Half", 45, 170, "#59616c", "Half-height armor slab.", {"shape": "half", "surf": AR, "buoy": 0.03}],
		["heavy_armor", "Heavy Armor", 160, 650, "#3d434b", "Tank-grade plate. Shrugs off cannon fire. Extremely heavy.", {"surf": {"m": 0.7, "r": 0.35, "deco": "rivets"}, "buoy": 0.03}],
		["ti_block", "Titanium Block", 15, 200, "#b0bec5", "Light and twice as tough as steel.", {"surf": TI, "buoy": 0.14}],
		["ti_wedge", "Titanium Wedge", 8, 100, "#b0bec5", "Light, tough slope.", {"shape": "wedge", "surf": TI, "buoy": 0.07}],
		["ti_corner", "Titanium Corner", 5, 70, "#b0bec5", "Light, tough corner.", {"shape": "corner", "surf": TI, "buoy": 0.05}],
		["ti_half", "Titanium Half", 8, 100, "#b0bec5", "Light, tough half block.", {"shape": "half", "surf": TI, "buoy": 0.07}],
		["ti_plate", "Titanium Plate", 3, 45, "#b0bec5", "Light, tough plate.", {"shape": "plate", "surf": TI, "buoy": 0.03}],
		["cf_block", "Carbon Block", 6, 70, "#263238", "Featherweight carbon fibre. Racers and planes love it.", {"surf": CF, "buoy": 0.16}],
		["cf_wedge", "Carbon Wedge", 3, 35, "#263238", "Featherweight slope.", {"shape": "wedge", "surf": CF, "buoy": 0.08}],
		["cf_corner", "Carbon Corner", 2, 25, "#263238", "Featherweight corner.", {"shape": "corner", "surf": CF, "buoy": 0.05}],
		["cf_plate", "Carbon Plate", 1.5, 18, "#263238", "Almost weightless floor plate.", {"shape": "plate", "surf": CF, "buoy": 0.03}],
		["glass", "Glass Block", 12, 25, "#9fd8ff", "See-through. Shatters easily.", {"surf": GL, "buoy": 0.1}],
		["glass_wedge", "Glass Wedge", 6, 14, "#9fd8ff", "Sloped glass for cockpits.", {"shape": "wedge", "surf": GL, "buoy": 0.05}],
		["glass_plate", "Windshield", 3, 10, "#9fd8ff", "Thin glass pane.", {"shape": "plate", "surf": GL, "buoy": 0.03}],
		["glass_corner", "Glass Corner", 4, 10, "#9fd8ff", "Glass corner for bubble canopies.", {"shape": "corner", "surf": GL, "buoy": 0.03}],
		["ballast", "Lead Ballast", 250, 300, "#4a4f57", "Ultra heavy. Put it low to stop rollovers or to balance a plane.", {"surf": {"m": 0.4, "r": 0.6, "deco": "ballast"}, "buoy": 0.02}],
		["foam", "Foam Block", 2, 15, "#f4f1de", "Almost weightless and floats like crazy.", {"surf": {"m": 0.0, "r": 1.0}, "buoy": 0.6}],
		["concrete", "Concrete Block", 60, 200, "#9e9e9e", "Heavy, cheap, solid.", {"surf": {"m": 0.0, "r": 0.95, "deco": "bricks"}, "buoy": 0.06}],
		["gold", "Gold Block", 120, 120, "#ffcc33", "Pure bling. Heavy and soft.", {"surf": {"m": 0.6, "r": 0.25}, "buoy": 0.03}],
		["neon", "Neon Block", 10, 40, "#39e1ff", "Glows in its paint color.", {"surf": {"glow": 2.2}, "buoy": 0.12}],
		["hazard", "Hazard Block", 25, 90, "#ffcc00", "Yellow and black warning stripes.", {"surf": {"deco": "stripes"}, "buoy": 0.14}],
		["crate", "Crate Block", 12, 45, "#b8864b", "Wooden shipping crate. Floats.", {"surf": {"m": 0.0, "r": 0.9, "deco": "crate"}, "buoy": 0.3}],
		["scrap", "Scrap Block", 20, 60, "#8d6e63", "Rusty junk. Wasteland style.", {"surf": {"m": 0.4, "r": 0.85, "deco": "rust"}, "buoy": 0.12}],
		["chrome", "Chrome Block", 30, 100, "#e0e6ee", "Mirror-polished metal.", {"surf": {"m": 0.7, "r": 0.12}, "buoy": 0.12}],
		["bumper", "Rubber Bumper", 15, 220, "#1d1f23", "Soaks up crashes: blocks near it take 75% less crash damage.", {"surf": {"m": 0.0, "r": 1.0, "deco": "bumper"}, "buoy": 0.25, "absorb": true}],
		["camo", "Camo Block", 25, 90, "#5c6b4a", "Military camouflage pattern.", {"surf": {"deco": "camo"}, "buoy": 0.14}],
		["checker", "Checker Block", 25, 90, "#f2f2f2", "Race-flag checkers.", {"surf": {"deco": "checker"}, "buoy": 0.14}],
	])
	B._d("passenger", "Passenger Seat", S, 30, 120, "#3fa9ff", "Bring a friend. A little robot buddy rides along.", {"kind": "struct", "buoy": 0.15})
	B._d("canopy", "Cockpit Canopy", S, 8, 30, "#9fd8ff", "Glass bubble. Put it over the seat for the fighter-jet look.", {"kind": "struct", "buoy": 0.08})


static func _wheels(B: Node) -> void:
	var base := {"kind": "wheel", "vis": "wheel", "shape": "wheel", "auto_rot": true, "radius": 0.48, "travel": 0.4,
		"drive": 1150.0, "cfg": {"steer": "auto", "drive": true, "pow": 100}}
	var free := {"steer": "off", "drive": false, "pow": 100}
	_many(B, "Wheels", base, [
		["wheel", "Wheel", 35, 120, "#e8b23a", "Sprung wheel. Front wheels steer automatically.", {}],
		["bigwheel", "Monster Wheel", 70, 220, "#e8b23a", "Huge off-road wheel with long suspension.", {"radius": 0.8, "travel": 0.55, "drive": 1700.0, "icon_ext": 1.7}],
		["small_wheel", "Small Wheel", 18, 70, "#e8b23a", "Little wheel for karts and light builds.", {"radius": 0.34, "travel": 0.3, "drive": 700.0}],
		["racing", "Racing Slick", 30, 100, "#e53935", "Sticky, stiff and fast. Much higher top speed.", {"radius": 0.45, "travel": 0.25, "drive": 1400.0, "grip": 1.6, "vmax": 64.0, "slick": true, "stiff": 1.5}],
		["offroad", "Off-Road Wheel", 45, 150, "#8d6e63", "Chunky tread and long travel for rough ground.", {"radius": 0.55, "travel": 0.55, "drive": 1300.0, "grip": 1.2, "wf": 1.1}],
		["tractor", "Tractor Wheel", 95, 260, "#3ddc84", "Massive torque, low top speed. Pulls anything.", {"radius": 0.9, "travel": 0.35, "drive": 2600.0, "vmax": 24.0, "grip": 1.5, "wf": 1.05, "icon_ext": 1.8}],
		["mega", "Mega Wheel", 150, 380, "#e8b23a", "Gigantic wheel. Crush everything.", {"radius": 1.2, "travel": 0.8, "drive": 3200.0, "vmax": 40.0, "icon_ext": 2.4}],
		["caster", "Caster Wheel", 8, 50, "#c8ced8", "Unpowered free-swivel wheel. Rolls in any direction.", {"radius": 0.25, "travel": 0.2, "drive": 0.0, "lat": 0.06, "cfg": free}],
		["spiked", "Spiked Wheel", 50, 170, "#59616c", "Spikes dig in for monster grip.", {"radius": 0.5, "travel": 0.4, "drive": 1300.0, "grip": 1.8, "spikes": true}],
		["drift", "Drift Wheel", 32, 100, "#ff5ec4", "Low side grip. Hold A or D and slide.", {"radius": 0.45, "travel": 0.35, "drive": 1250.0, "lat": 0.11, "grip": 0.85}],
		["bike", "Bike Wheel", 15, 60, "#c8ced8", "Skinny and light.", {"radius": 0.5, "wf": 0.35, "travel": 0.3, "drive": 900.0}],
		["track", "Tank Track", 90, 300, "#59616c", "Skid-steer tread. Huge grip, turns on the spot.", {"vis": "track", "radius": 0.5, "travel": 0.25, "drive": 2200.0, "vmax": 22.0, "grip": 2.0, "lat": 0.5, "cfg": {"steer": "tank", "drive": true, "pow": 100}}],
		["ski", "Ski", 10, 60, "#e53935", "Slides on sand. No power, almost no drag.", {"vis": "ski", "radius": 0.2, "travel": 0.3, "drive": 0.0, "roll": 0.0, "lat": 0.25, "grip": 0.6, "cfg": free}],
		["rally", "Rally Wheel", 38, 130, "#3fa9ff", "Balanced grip, travel and speed.", {"radius": 0.5, "travel": 0.5, "drive": 1350.0, "grip": 1.3, "vmax": 54.0}],
		["classic", "Whitewall Wheel", 34, 110, "#e0e6ee", "Old-school cruiser style.", {"radius": 0.45, "whitewall": true, "drive": 1100.0}],
		["hubmotor", "Hub Motor Wheel", 45, 120, "#39e1ff", "Electric in-wheel motor. Instant torque.", {"radius": 0.4, "drive": 2400.0, "vmax": 36.0, "glowrim": true}],
		["skate", "Skate Wheel", 5, 30, "#ffcc00", "Tiny roller. Sits very low.", {"radius": 0.2, "travel": 0.15, "drive": 400.0}],
	])


static func _mechanical(B: Node) -> void:
	var M := "Carries every block attached to its top face. Return mode follows the key; Hold mode stays where you leave it."
	var list := []
	for p in [
		["piston_s", "Small Piston", 30, 100, "#9ccc65", 1.0, 3.0, "lift", "return", "Short, snappy piston."],
		["piston", "Piston", 40, 120, "#9ccc65", 2.0, 3.0, "lift", "return", "Pushes 2 blocks out."],
		["piston_l", "Long Piston", 50, 120, "#9ccc65", 3.5, 3.5, "lift", "return", "Long reach for cranes, lifts and ladders."],
		["piston_t", "Telescopic Piston", 60, 110, "#c5e1a5", 6.0, 4.0, "lift", "return", "Extends 6 blocks. Sky-high reach."],
		["piston_q", "Quick Piston", 35, 100, "#ffcc00", 1.0, 14.0, "fire3", "return", "Shoots out almost instantly."],
		["ram", "Hydraulic Ram", 90, 320, "#ff9a1f", 2.0, 1.5, "lift", "hold", "Slow, armored, holds position."],
		["hydro", "Hydraulic Cylinder", 70, 220, "#ff9a1f", 3.0, 2.0, "pitch", "hold", "Smooth hydraulic push on the arrow keys."],
		["kicker", "Pneumatic Kicker", 40, 140, "#e53935", 1.2, 25.0, "fire3", "return", "Violent punch. Launch things, or yourself."],
		["jack", "Lift Jack", 60, 260, "#ffcc00", 2.5, 1.2, "lift", "hold", "Jacks the vehicle up and keeps it there."],
		["pump", "Pump Piston", 40, 120, "#26c6da", 1.0, 2.5, "always", "osc", "Pumps up and down on its own. Hoppers and walkers."],
	]:
		list.append([p[0], p[1], p[2], p[3], p[4], "%s %s" % [p[9], M], {"stroke": p[5], "speed": p[6], "cfg": ch(p[7], {"mode": p[8]})}])
	_many(B, "Mechanical", {"kind": "piston", "vis": "piston", "out": Vector3.UP, "axis": Vector3.UP}, list)
	list = []
	var H := "Swings every block attached to its output face (the striped side)."
	for h in [
		["hinge", "Hinge", 25, 100, "#9ccc65", 45, 90, "pitch", "return", Vector3.RIGHT, Vector3.UP, "Swings up to 45 degrees."],
		["servo", "Servo", 35, 120, "#9ccc65", 90, 120, "pitch", "return", Vector3.RIGHT, Vector3.UP, "Swings up to 90 degrees."],
		["servo_w", "Wide Servo", 40, 120, "#c5e1a5", 180, 150, "roll", "return", Vector3.RIGHT, Vector3.UP, "Swings 180 degrees. Folding wings and arms."],
		["servo_h", "Heavy Servo", 80, 300, "#ff9a1f", 90, 50, "pitch", "hold", Vector3.RIGHT, Vector3.UP, "Slow, armored, holds its angle."],
		["servo_f", "Fast Servo", 30, 100, "#ffcc00", 60, 400, "steer", "return", Vector3.RIGHT, Vector3.UP, "Snaps into position instantly."],
		["steer_hinge", "Steering Hinge", 30, 140, "#e0b341", 30, 150, "steer", "return", Vector3.UP, Vector3.RIGHT, "Turns with A/D. Put it beside the chassis with a wheel on its striped side."],
		["gimbal_p", "Pitch Gimbal", 30, 110, "#5fb8ff", 25, 120, "pitch", "return", Vector3.RIGHT, Vector3.BACK, "Thrust vectoring: an engine behind it tilts with the arrows."],
		["gimbal_y", "Yaw Gimbal", 30, 110, "#5fb8ff", 25, 120, "yaw", "return", Vector3.UP, Vector3.BACK, "Thrust vectoring left and right on Q/E."],
		["gimbal_r", "Roll Gimbal", 30, 110, "#5fb8ff", 45, 120, "roll", "return", Vector3.FORWARD, Vector3.BACK, "Twists whatever is behind it on Left/Right."],
		["gear_hinge", "Landing Gear Hinge", 30, 140, "#e0b341", 90, 90, "act1", "return", Vector3.RIGHT, Vector3.DOWN, "Folds wheels away on Toggle 1."],
		["tilt_hinge", "Tilt-Rotor Hinge", 40, 150, "#5fb8ff", 90, 60, "act2", "return", Vector3.RIGHT, Vector3.UP, "Tilts rotors or engines 90 degrees on Toggle 2. Build an Osprey."],
		["flipper", "Flipper Arm", 50, 200, "#e53935", 120, 600, "fire3", "return", Vector3.RIGHT, Vector3.UP, "Flings up on G. Flip crates, barrels and cars."],
		["wiggle", "Wiggle Servo", 30, 100, "#26c6da", 45, 3.0, "always", "osc", Vector3.RIGHT, Vector3.UP, "Swings back and forth by itself. Legs, tails, flappy wings."],
		["sweep", "Sweep Servo", 40, 120, "#26c6da", 80, 1.2, "always", "osc", Vector3.UP, Vector3.UP, "Slowly sweeps side to side by itself."],
	]:
		var spd: float = deg_to_rad(h[6]) if h[8] != "osc" else float(h[6])
		list.append([h[0], h[1], h[2], h[3], h[4], "%s %s" % [h[11], H], {"max": deg_to_rad(h[5]), "speed": spd, "axis": h[9], "out": h[10], "cfg": ch(h[7], {"mode": h[8]})}])
	_many(B, "Mechanical", {"kind": "hinge", "vis": "hinge"}, list)
	# walker kit: same cycle speed, so a hip and its lifter stay in step
	var W := "Runs on W/S (backward on S) and skid-steers with A/D. Give each leg's hip and lifter phases 90 degrees apart, and opposite legs 180 degrees apart."
	B._d("leg_servo", "Leg Servo", "Mechanical", 30, 160, "#b98cff", "Walker hip: swings a leg forward and back. " + W,
		{"kind": "hinge", "vis": "hinge", "max": deg_to_rad(20.0), "speed": 4.0, "axis": Vector3.UP, "out": Vector3.RIGHT, "cfg": ch("throttle", {"mode": "osc", "tank": true, "phase": 0})})
	B._d("leg_lift", "Leg Lifter", "Mechanical", 35, 160, "#b98cff", "Walker knee: lifts the leg on its forward swing and plants it for the push. " + W,
		{"kind": "piston", "vis": "piston", "stroke": 1.0, "speed": 4.0, "axis": Vector3.UP, "out": Vector3.UP, "cfg": ch("throttle", {"mode": "step", "tank": true, "phase": 0})})
	_many(B, "Mechanical", {"kind": "rotator", "vis": "rotator", "axis": Vector3.UP, "out": Vector3.UP}, [
		["spinner", "Spinner", 30, 120, "#9ccc65", "Spins the blocks on its top face with Q/E.", {"speed": 6.0, "cfg": ch("yaw")}],
		["turntable", "Turntable", 50, 200, "#9ccc65", "Slow rotating base for cranes and turrets (Q/E).", {"speed": 1.2, "cfg": ch("yaw")}],
		["heavymotor", "Heavy Motor", 80, 300, "#ff9a1f", "Armored rotator (Q/E).", {"speed": 3.0, "cfg": ch("yaw")}],
		["turbospin", "Turbo Spinner", 30, 100, "#e53935", "Always spinning, very fast. Saw arms, fans, chaos.", {"speed": 25.0, "cfg": ch("always")}],
	])
	var SD := "Wheels touching it get its travel and stiffness. Without a wheel it is a springy leg pushing out of its bottom."
	_many(B, "Mechanical", {"kind": "susp", "vis": "susp", "axis": Vector3.UP, "out": Vector3.DOWN}, [
		["spring", "Coil Spring", 20, 120, "#e53935", "Soft and bouncy. " + SD, {"travel": 0.5, "stiff": 0.7, "damp": 0.6}],
		["shock", "Shock Absorber", 25, 140, "#ffcc00", "Well damped, smooth ride. " + SD, {"travel": 0.4, "stiff": 1.0, "damp": 1.4}],
		["heavysusp", "Heavy Suspension", 60, 300, "#59616c", "For trucks and tanks. " + SD, {"travel": 0.5, "stiff": 1.8, "damp": 1.2}],
		["racesusp", "Racing Suspension", 20, 120, "#3fa9ff", "Stiff and low, corners flat. " + SD, {"travel": 0.2, "stiff": 2.2, "damp": 1.5}],
		["longsusp", "Long-Travel Suspension", 35, 150, "#3ddc84", "Huge travel for jumps and dunes. " + SD, {"travel": 1.1, "stiff": 0.8, "damp": 1.0}],
		["airsusp", "Air Suspension", 35, 140, "#26c6da", "Space/C raises and lowers the ride height. Lowrider hops! " + SD, {"travel": 0.6, "stiff": 1.0, "damp": 1.0, "ride": 1.2, "cfg": ch("lift")}],
		["leaf", "Leaf Spring", 30, 160, "#8d6e63", "Old-school truck spring. " + SD, {"travel": 0.3, "stiff": 1.4, "damp": 0.5}],
		["pogo", "Pogo Leg", 25, 120, "#ff5ec4", "Barely damped. Boing boing boing. " + SD, {"travel": 0.8, "stiff": 2.5, "damp": 0.08}],
	])
	B._d("decoupler", "Decoupler", "Mechanical", 15, 60, "#ffcc00", "Pops off on Trigger 4 and drops everything beyond it. Rocket stages, cargo drops, escape pods.", {"cfg": ch("act4")})


static func _propulsion(B: Node) -> void:
	var P := "Propulsion"
	_many(B, P, {"kind": "engine", "cfg": ch("throttle"), "medium": "air"}, [
		["thruster", "Thruster", 40, 80, "#c8ced8", "Small jet that pushes toward its pointy end. Works anywhere.", {"thrust": 1900.0, "medium": "any", "flame": 1.2}],
		["jet", "Jet Engine", 100, 140, "#9aa3ad", "Powerful air-breathing engine. Dies underwater.", {"thrust": 6200.0, "flame": 2.2, "loud": true}],
		["rocket", "Rocket Booster", 70, 100, "#f2f2f2", "Insane burst of thrust on Shift. Hold on tight!", {"thrust": 14000.0, "medium": "any", "flame": 3.5, "loud": true, "cfg": ch("boost")}],
		["prop", "Propeller", 50, 90, "#f0c419", "Classic airplane propeller. Strong at low speed.", {"thrust": 4200.0, "propfall": 95.0}],
		["mini_thruster", "Mini Thruster", 15, 50, "#c8ced8", "Tiny thruster for trimming and drones.", {"vis": "thruster", "vs": 0.7, "thrust": 800.0, "medium": "any", "flame": 1.0}],
		["big_thruster", "Big Thruster", 90, 160, "#c8ced8", "Chunky thruster. Works in air and water.", {"vis": "thruster", "vs": 1.35, "thrust": 4200.0, "medium": "any", "flame": 1.6}],
		["ion", "Ion Drive", 25, 70, "#5fd0ff", "Quiet glowing drive. Weak, but works anywhere.", {"thrust": 1100.0, "medium": "any", "glow": "#5fd0ff"}],
		["afterburner", "Afterburner Jet", 120, 150, "#59616c", "Jet that more than doubles its thrust while you hold Shift.", {"vis": "jet", "thrust": 5500.0, "flame": 2.6, "afterburn": 2.2, "loud": true}],
		["turbofan", "Turbofan", 140, 180, "#e6ebf2", "Big airliner engine. Massive steady thrust.", {"vis": "jet", "vs": 1.25, "thrust": 8000.0, "flame": 1.8, "loud": true}],
		["ramjet", "Ramjet", 70, 120, "#8b949e", "Weak at low speed, monstrous when you are already fast.", {"thrust": 4000.0, "ram": true, "flame": 2.8, "loud": true}],
		["pulsejet", "Pulse Jet", 50, 90, "#a1887f", "Buzzing, pulsing old-timey jet.", {"thrust": 3600.0, "pulse": true, "flame": 2.0, "loud": true}],
		["twinjet", "Twin Jet", 180, 220, "#9aa3ad", "Two jets in one block.", {"thrust": 9000.0, "flame": 2.0, "loud": true}],
		["mini_rocket", "Mini Rocket", 30, 60, "#f2f2f2", "Small boost rocket on Shift.", {"vis": "rocket", "vs": 0.7, "thrust": 6000.0, "medium": "any", "flame": 2.4, "loud": true, "cfg": ch("boost")}],
		["mega_rocket", "Mega Rocket", 160, 160, "#f2f2f2", "Absurd thrust on Shift. To the moon.", {"vis": "rocket", "vs": 1.5, "thrust": 30000.0, "medium": "any", "flame": 5.0, "loud": true, "icon_ext": 1.4, "cfg": ch("boost")}],
		["srb", "Solid Booster", 90, 110, "#f2f2f2", "Press Shift once: burns flat out for 4 seconds, then it is spent.", {"thrust": 22000.0, "medium": "any", "fuel": 4.0, "flame": 4.5, "loud": true, "cfg": ch("boost")}],
		["plasma_drive", "Plasma Drive", 70, 120, "#c05cff", "Sci-fi engine with a violet glow. Works anywhere.", {"vis": "ion", "vs": 1.15, "thrust": 7000.0, "medium": "any", "glow": "#c05cff", "loud": true}],
		["bigprop", "Big Propeller", 80, 130, "#f0c419", "Huge propeller for heavy planes.", {"vis": "prop", "vs": 1.45, "thrust": 7500.0, "propfall": 90.0, "icon_ext": 1.4}],
		["coax", "Contra-Prop", 70, 110, "#e53935", "Two counter-rotating propellers. Lots of grunt.", {"thrust": 6000.0, "propfall": 100.0}],
		["ducted", "Ducted Fan", 45, 110, "#3fa9ff", "Fan in a ring. Keeps pushing at high speed.", {"thrust": 3200.0, "propfall": 160.0}],
		["vtol", "VTOL Lifter", 60, 120, "#59616c", "Fan that blows straight down on Space. Hover without a rotor.", {"thrust": 5000.0, "tdir": Vector3.UP, "lift_only": true, "cfg": ch("lift")}],
	])
	_many(B, P, {"kind": "hover", "vis": "hover", "shape": "plate", "cfg": ch("always")}, [
		["hover", "Hover Pad", 30, 90, "#26c6da", "Floats 2 blocks above ground or water. Use 3 or more for a hovercraft.", {"height": 2.0, "force": 3500.0}],
		["bighover", "Big Hover Pad", 70, 160, "#c05cff", "Strong pad that holds you 3 blocks up.", {"height": 3.0, "force": 9000.0}],
	])
	_many(B, P, {"kind": "rotor", "vis": "rotor", "cfg": ch("lift")}, [
		["rotor", "Heli Rotor", 60, 110, "#7c8794", "Helicopter rotor with altitude hold. Space/C to climb or sink.", {"thrust": 5200.0, "icon_ext": 3.6}],
		["minirotor", "Mini Rotor", 30, 70, "#7c8794", "Small rotor for drones and quadcopters.", {"vs": 0.6, "thrust": 2600.0, "icon_ext": 2.4}],
		["bigrotor", "Big Rotor", 120, 200, "#59616c", "Heavy-lift rotor. Carries tanks.", {"vs": 1.35, "thrust": 11000.0, "icon_ext": 4.6}],
	])
	_many(B, P, {"kind": "balloon", "vis": "balloon", "cfg": ch("always")}, [
		["balloon", "Balloon", 12, 30, "#ff4f6d", "Floats up forever. Pops if shot.", {"lift": 1500.0, "cap": 700.0, "icon_ext": 3.2, "icon_focus": Vector3(0, 1.1, 0)}],
		["hydrogen", "Hydrogen Balloon", 15, 25, "#f2f2f2", "Bigger balloon, double the lift.", {"vs": 1.25, "lift": 3200.0, "cap": 900.0, "icon_ext": 4.0, "icon_focus": Vector3(0, 1.5, 0)}],
		["hotair", "Hot-Air Balloon", 25, 40, "#ff7a2f", "Space burns for more lift, C vents it. Steerable altitude.", {"vis": "hotair", "lift": 4200.0, "ctrl": true, "cap": 1200.0, "cfg": ch("lift"), "icon_ext": 4.2, "icon_focus": Vector3(0, 1.6, 0)}],
		["blimp", "Blimp Envelope", 40, 60, "#cfd5dd", "Giant gas bag. Lifts a whole airship.", {"vis": "blimp", "lift": 9000.0, "cap": 1500.0, "icon_ext": 3.4, "icon_focus": Vector3(0, 1.4, 0)}],
		["antigrav", "Anti-Grav Core", 50, 80, "#c05cff", "Mystery tech that cancels 600 kg of gravity. No height limit.", {"vis": "antigrav", "lift": 5900.0, "cap": 100000.0}],
	])


static func _flight(B: Node) -> void:
	var F := "Flight"
	_many(B, F, {"kind": "wing", "shape": "wing", "buoy": 0.05}, [
		["wing", "Wing", 15, 70, "#e6ebf2", "Generates lift when moving forward. Leading edge faces forward.", {"lift": 0.26, "buoy": 0.06}],
		["smallwing", "Small Wing", 8, 40, "#e6ebf2", "Half the lift and half the weight.", {"vis": "wing2", "style": "small", "lift": 0.14}],
		["bigwing", "Thick Wing", 25, 110, "#e6ebf2", "Fat high-lift wing for heavy haulers.", {"vis": "wing2", "style": "thick", "lift": 0.38}],
		["sweptwing", "Swept Wing", 14, 70, "#cfd5dd", "Swept back for fast jets.", {"vis": "wing2", "style": "swept", "lift": 0.24}],
		["deltawing", "Delta Wing", 16, 80, "#b0bec5", "Triangular wing. Good at high speed.", {"vis": "wing2", "style": "delta", "lift": 0.3}],
		["gliderwing", "Glider Wing", 7, 35, "#f2f2f2", "Long, light and slippery. Float for miles.", {"vis": "wing2", "style": "glider", "lift": 0.34}],
		["tailfin", "Tail Fin", 8, 50, "#e6ebf2", "Upright stabilizer. Stops planes sliding sideways.", {"vis": "wing2", "style": "fin", "lift": 0.0, "nrm": Vector3.RIGHT}],
		["winglet", "Winglet", 4, 30, "#ffcc00", "Small upright fin for wing tips.", {"vis": "wing2", "style": "winglet", "lift": 0.0, "nrm": Vector3.RIGHT}],
		["spoiler", "Spoiler", 12, 60, "#2b2f36", "Pushes the car down at speed for more grip.", {"lift": -0.28}],
		["bigspoiler", "Big Spoiler", 20, 80, "#e53935", "Huge rear wing. Glued to the track.", {"vis": "spoiler", "vs": 1.2, "lift": -0.6}],
		["splitter", "Front Splitter", 8, 50, "#2b2f36", "Low front lip that adds downforce to the nose.", {"lift": -0.2, "shape": "plate"}],
	])
	_many(B, F, {"kind": "flap", "vis": "flap", "shape": "wing", "cfg": {"pow": 100}}, [
		["flap", "Control Flap", 15, 60, "#5fb8ff", "Moving surface. Auto-steers pitch, roll and yaw based on where you put it.", {"fp": 1.4}],
		["canard", "Canard", 10, 50, "#5fb8ff", "Small front flap for nimble pitch.", {"fp": 1.0, "vs": 0.7}],
		["bigflap", "Big Flap", 22, 90, "#5fb8ff", "Strong control surface for big planes.", {"fp": 2.0}],
		["elevator", "Elevator", 14, 60, "#3fa9ff", "Flap that only does pitch. Put it on the tail.", {"fp": 1.6, "only": "pitch"}],
		["aileron", "Aileron", 14, 60, "#ff7a2f", "Flap that only does roll. Put it near the wing tips.", {"fp": 1.6, "only": "roll"}],
		["rudder", "Rudder", 14, 60, "#e53935", "Upright flap that only does yaw (A/D, Q/E).", {"fp": 1.6, "only": "yaw", "nrm": Vector3.RIGHT}],
	])
	_many(B, F, {"kind": "gyro", "vis": "gyro", "cfg": {"pow": 100}}, [
		["gyro", "Gyro Stabilizer", 40, 80, "#5fd0ff", "Keeps you level and adds steering torque from arrows and A/D.", {"str": 1.0}],
		["gyrolite", "Mini Gyro", 15, 50, "#7fe7ff", "Light gyro with gentle correction.", {"vs": 0.7, "str": 0.45}],
		["supergyro", "Super Gyro", 80, 140, "#ff5ec4", "Monster stabilizer. Very hard to flip.", {"vs": 1.15, "str": 2.6}],
		["leveler", "Auto Leveler", 30, 80, "#3ddc84", "Only keeps you level. Never steers.", {"str": 1.2, "level_only": true}],
	])
	_many(B, F, {"kind": "parachute", "vis": "parachute", "cfg": ch("act2"), "icon_ext": 1.3}, [
		["parachute", "Parachute", 20, 50, "#ffffff", "Toggle with 2 for a soft landing or a drag-race stop.", {"drag": 1.0}],
		["drogue", "Drogue Chute", 12, 40, "#ff7a2f", "Small strong chute for dragsters (Toggle 2).", {"vs": 0.7, "drag": 2.0}],
	])
	B._d("airbrake", "Air Brake", F, 15, 70, "#e53935", "Pops up and adds huge drag while you hold S.", {"drag": 3.0, "cfg": ch("throttle", {"inv": true})})


static func _water(B: Node) -> void:
	var W := "Water"
	_many(B, W, {"kind": "struct"}, [
		["float", "Float", 10, 60, "#ff9a1f", "Huge buoyancy. Keeps anything above water.", {"buoy": 0.95}],
		["bigfloat", "Big Float", 16, 80, "#ff9a1f", "Even more float.", {"buoy": 1.6}],
		["pontoon", "Pontoon", 14, 90, "#e6ebf2", "Seaplane float. Smooth and very buoyant.", {"buoy": 1.2}],
		["tube", "Inflatable Tube", 4, 25, "#ffcc00", "Light rubber ring.", {"buoy": 1.1}],
		["hull", "Hull Block", 14, 80, "#f2f2f2", "Sealed boat hull. Floats and is tough.", {"vis": "solid", "surf": {"deco": "hull", "r": 0.4}, "buoy": 0.7}],
		["hullwedge", "Hull Bow", 8, 50, "#f2f2f2", "Pointy boat bow.", {"vis": "solid", "shape": "wedge", "surf": {"r": 0.4}, "buoy": 0.45}],
	])
	_many(B, W, {"kind": "engine", "medium": "water", "reverse": true, "hull": true, "cfg": ch("throttle")}, [
		["boatprop", "Boat Propeller", 40, 90, "#d4a542", "Pushes through water. Only works submerged.", {"thrust": 4600.0}],
		["bigboatprop", "Big Boat Prop", 70, 140, "#d4a542", "Big brass screw for ships.", {"vis": "boatprop", "vs": 1.3, "thrust": 9000.0}],
		["jetdrive", "Water Jet", 50, 120, "#3fa9ff", "Jet-ski drive. Fast and punchy.", {"thrust": 7000.0}],
		["paddle", "Paddle Wheel", 45, 120, "#b67a44", "Steamboat paddle. Works half out of the water.", {"thrust": 3500.0, "medium": "surface"}],
		["outboard", "Outboard Motor", 45, 100, "#2b2f36", "Clamp-on boat motor that also steers with A/D.", {"thrust": 5200.0, "steer_deg": 30.0}],
	])
	B._d("keel", "Keel", W, 30, 100, "#59616c", "Fin under the hull. Stops boats sliding sideways in turns.", {"kind": "keel", "keel": 70.0, "buoy": 0.05})
	B._d("waterrudder", "Boat Rudder", W, 15, 70, "#e53935", "Steers boats with A/D. Must be underwater.", {"kind": "rudder", "cfg": ch("steer")})
	B._d("hydrofoil", "Hydrofoil", W, 15, 80, "#26c6da", "Underwater wing. Lifts the hull out of the water at speed.", {"kind": "wing", "lift": 0.9, "water_only": true, "shape": "wing"})
	B._d("ballast", "Ballast Tank", W, 40, 120, "#ffcc00", "C floods it to dive, Space blows it to surface. Build a submarine!", {"buoy": 0.9, "cfg": ch("lift")})
	B._d("anchor", "Anchor", W, 60, 200, "#3d434b", "Toggle 2 drops it: holds you in place on water or ground.", {"cfg": ch("act2"), "buoy": 0.0})


static func _weapons(B: Node) -> void:
	var WP := "Weapons"
	_many(B, WP, {"kind": "gun", "muzzle": Vector3(0, -0.05, -1.1), "cfg": ch("fire1")}, [
		["mg", "Machine Gun", 30, 70, "#3c434c", "Rapid fire bullets. Aims near your crosshair.", {"rate": 0.07, "dmg": 9.0, "spread": 0.012, "muzzle": Vector3(0, -0.06, -1.1)}],
		["minigun", "Minigun", 45, 90, "#3c434c", "Six spinning barrels. Brrrrrt.", {"vis": "gun", "rate": 0.03, "dmg": 5.5, "spread": 0.03, "look": {"n": 6, "len": 1.0, "rad": 0.035, "spin": true}}],
		["hmg", "Heavy Machine Gun", 55, 110, "#4b5563", "Big slow bullets that hit hard.", {"vis": "gun", "rate": 0.13, "dmg": 20.0, "spread": 0.01, "look": {"n": 1, "len": 1.3, "rad": 0.08, "body": Vector3(0.45, 0.4, 0.8)}}],
		["sniper", "Sniper Cannon", 50, 90, "#2b2f36", "Long range, one heavy round at a time.", {"vis": "gun", "rate": 1.4, "dmg": 75.0, "spread": 0.0, "range": 1400.0, "tcol": "#7fe7ff", "snd": "cannon", "pitch": 1.8, "look": {"n": 1, "len": 1.7, "rad": 0.05, "scope": true}}],
		["shotgun", "Shotgun", 40, 90, "#6d4c41", "Ten pellets per blast. Brutal up close.", {"vis": "gun", "rate": 0.8, "dmg": 8.0, "pellets": 10, "spread": 0.07, "range": 140.0, "snd": "cannon", "pitch": 1.6, "look": {"n": 2, "len": 0.8, "rad": 0.09}}],
		["railgun", "Railgun", 90, 140, "#37474f", "Slow to recharge, pierces through up to 4 things.", {"rate": 2.5, "dmg": 140.0, "pierce": 4, "range": 1500.0, "tcol": "#39e1ff", "snd": "cannon", "pitch": 2.4, "recoil": 1500.0, "fat": true}],
	])
	_many(B, WP, {"kind": "launcher", "muzzle": Vector3(0, -0.02, -1.2), "cfg": ch("fire2")}, [
		["cannon", "Cannon", 90, 150, "#4b5563", "Explosive shells with a big kick.", {"proj": "shell", "pspeed": 190.0, "rate": 1.1, "recoil": 1100.0, "muzzle": Vector3(0, -0.02, -1.5)}],
		["rockets", "Rocket Pod", 60, 90, "#59616c", "Fires homing rockets toward your crosshair.", {"proj": "rocket", "pspeed": 45.0, "rate": 0.32, "homing": true, "barrels": [Vector3(-0.2, -0.2, -0.7), Vector3(0.2, -0.2, -0.7), Vector3(-0.2, 0.2, -0.7), Vector3(0.2, 0.2, -0.7)]}],
		["bombs", "Bomb Bay", 70, 110, "#4a5a3c", "Drops big bombs on G. Best from a plane.", {"proj": "bomb", "drop": true, "rate": 1.3, "cfg": ch("fire3")}],
		["autocannon", "Autocannon", 70, 130, "#4b5563", "Rapid small explosive shells.", {"vis": "gun", "proj": "shell", "power": 0.45, "pspeed": 230.0, "rate": 0.22, "recoil": 250.0, "look": {"n": 1, "len": 1.4, "rad": 0.09, "body": Vector3(0.5, 0.45, 0.8)}}],
		["howitzer", "Howitzer", 160, 220, "#5c6b4a", "Huge shells, huge recoil.", {"vis": "cannon", "vs": 1.3, "proj": "shell", "power": 2.2, "pspeed": 150.0, "rate": 2.6, "recoil": 3200.0, "muzzle": Vector3(0, -0.02, -1.9)}],
		["mortar", "Mortar", 60, 120, "#5c6b4a", "Lobs shells high over walls.", {"proj": "shell", "power": 1.6, "pspeed": 55.0, "loft": 1.1, "rate": 1.6, "noaim": true, "muzzle": Vector3(0, 0.3, -0.5)}],
		["missile", "Missile Launcher", 90, 120, "#e6ebf2", "Big homing missiles with a big bang.", {"proj": "missile", "pspeed": 25.0, "rate": 1.6, "homing": true}],
		["torpedo", "Torpedo Tube", 70, 120, "#37474f", "Homing torpedo. Launch it into the water.", {"proj": "torpedo", "pspeed": 12.0, "rate": 2.0, "homing": true}],
		["plasmacannon", "Plasma Cannon", 70, 110, "#c05cff", "Fast glowing bolts that burst on impact.", {"proj": "pbolt", "pspeed": 140.0, "rate": 0.45, "glow": "#c05cff", "cfg": ch("fire1")}],
		["grenade", "Grenade Launcher", 40, 90, "#6d7a4a", "Lobbed grenades that bounce, then blow.", {"proj": "grenade", "pspeed": 50.0, "loft": 0.2, "rate": 0.6}],
		["flak", "Flak Cannon", 90, 150, "#59616c", "Shells burst in the air right at your crosshair.", {"vis": "gun", "proj": "flak", "pspeed": 200.0, "rate": 0.35, "recoil": 400.0, "look": {"n": 2, "len": 1.3, "rad": 0.07, "body": Vector3(0.6, 0.5, 0.8)}}],
		["barrage", "Rocket Barrage", 80, 120, "#e53935", "Dumps 12 unguided rockets, then reloads.", {"proj": "rocket", "pspeed": 55.0, "rate": 0.07, "spread": 0.05, "mag": 12, "reload": 3.0, "barrels": [Vector3(-0.27, -0.27, -0.6), Vector3(0, -0.27, -0.6), Vector3(0.27, -0.27, -0.6), Vector3(-0.27, 0, -0.6), Vector3(0, 0, -0.6), Vector3(0.27, 0, -0.6), Vector3(-0.27, 0.27, -0.6), Vector3(0, 0.27, -0.6), Vector3(0.27, 0.27, -0.6)]}],
		["mines", "Mine Layer", 60, 110, "#3d434b", "Drops proximity mines behind you (G).", {"proj": "mine", "drop": true, "rate": 1.0, "cfg": ch("fire3")}],
		["clusterbombs", "Cluster Bomb Bay", 80, 120, "#6d4c41", "Bombs that split into eight bomblets.", {"vis": "bombs", "proj": "cluster", "drop": true, "rate": 1.8, "cfg": ch("fire3")}],
		["bigbomb", "Mega Bomb Bay", 150, 160, "#2b2f36", "One enormous bomb every 5 seconds. Fly high.", {"vis": "bombs", "vs": 1.0, "proj": "bigbomb", "drop": true, "rate": 5.0, "cfg": ch("fire3")}],
		["firework", "Firework Launcher", 30, 60, "#ff5ec4", "Shoots fireworks that burst into colors.", {"proj": "firework", "pspeed": 45.0, "loft": 0.6, "rate": 0.5, "noaim": true, "cfg": ch("fire3")}],
	])
	_many(B, WP, {"kind": "laser", "cfg": ch("fire1"), "vis": "laser"}, [
		["laser", "Laser", 40, 70, "#eef2f7", "Continuous beam that melts blocks.", {"dps": 85.0, "lcol": "#ff2244"}],
		["heavylaser", "Heavy Laser", 80, 120, "#2b2f36", "Thick orange beam that melts armor fast.", {"vs": 1.25, "dps": 200.0, "lcol": "#ff8a00", "width": 1.8}],
		["pulselaser", "Pulse Laser", 40, 70, "#3ddc84", "Green beam that pulses. Strong but stuttery.", {"dps": 150.0, "lcol": "#3ddc84", "pulse": true}],
	])
	_many(B, WP, {"kind": "flamer", "cfg": ch("fire1"), "vis": "flamer"}, [
		["flamer", "Flamethrower", 40, 70, "#d33c2c", "Short range torrent of fire.", {"dps": 70.0, "range": 11.0}],
		["bigflamer", "Inferno Cannon", 80, 120, "#ff7a2f", "Bigger, longer, hotter fire.", {"vs": 1.3, "dps": 150.0, "range": 18.0}],
	])
	_many(B, WP, {"kind": "turret", "vis": "turret", "cfg": ch("fire1")}, [
		["turret", "Auto Turret", 70, 140, "#5c6b4a", "Swivels to follow your crosshair and fires twin guns.", {"rate": 0.085, "dmg": 7.0, "tcol": "#9dff7a"}],
		["cannonturret", "Cannon Turret", 130, 260, "#4b5563", "Tank turret that swivels and fires shells.", {"vs": 1.2, "rate": 1.0, "proj": "shell", "power": 0.8, "pspeed": 190.0, "cfg": ch("fire2")}],
		["laserturret", "Laser Turret", 70, 120, "#eef2f7", "Swiveling pink zapper.", {"rate": 0.12, "dmg": 12.0, "tcol": "#ff5ec4"}],
	])
	_many(B, WP, {"cfg": ch("fire1")}, [
		["tesla", "Tesla Coil", 60, 100, "#b0bec5", "Zaps lightning at anything nearby. Chains between targets.", {"radius": 22.0, "dmg": 30.0, "rate": 0.3}],
		["watercannon", "Water Cannon", 50, 110, "#3fa9ff", "Blasts things away with water. No damage, lots of push.", {}],
		["confetti", "Confetti Cannon", 20, 50, "#ff5ec4", "Party time. Completely harmless.", {"cfg": ch("horn")}],
	])
	_many(B, WP, {"kind": "melee", "cfg": ch("always")}, [
		["ramspike", "Ram Spike", 40, 260, "#8b949e", "Ram things. Damage grows with speed.", {"dps": 0.0, "ram": 9.0, "reach": 1.1}],
		["saw", "Buzz Saw", 50, 160, "#c8ced8", "Spinning blade that chews through blocks.", {"dps": 130.0, "reach": 1.3, "spin": 30.0}],
		["drill", "Drill", 60, 200, "#ffcc00", "Grinding drill. Slow but brutal.", {"dps": 180.0, "reach": 1.4, "spin": 14.0}],
	])


static func _gadgets(B: Node) -> void:
	var G := "Gadgets"
	_many(B, G, {"kind": "jump", "vis": "jump", "cfg": ch("lift")}, [
		["jump", "Spring Jump", 40, 90, "#3ddc84", "Launches you along its spring on Space.", {"impulse": 7.5}],
		["bigjump", "Mega Spring", 70, 140, "#ffcc00", "Launches you twice as hard.", {"vs": 1.2, "impulse": 15.0}],
	])
	_many(B, G, {"kind": "magnet", "vis": "magnet", "cfg": ch("act1")}, [
		["magnet", "Magnet", 60, 110, "#e53935", "Toggle with 1 to pull crates, barrels and debris.", {"range": 18.0, "str": 1.0}],
		["supermagnet", "Super Magnet", 110, 180, "#3fa9ff", "Huge range and pull.", {"vs": 1.3, "range": 32.0, "str": 2.6}],
		["grabber", "Grabber Claw", 50, 140, "#ffcc00", "Grips anything it touches while Toggle 1 is on. Carry crates!", {"vis": "grabber", "range": 3.2, "str": 9.0, "grip": true}],
	])
	_many(B, G, {"kind": "tnt", "vis": "tnt", "cfg": ch("act4")}, [
		["tnt", "TNT", 30, 30, "#d32f2f", "Detonate with 4. Also explodes when destroyed!", {"boom": 8.0, "bdmg": 160.0}],
		["megatnt", "Mega TNT", 70, 40, "#ff7a2f", "Massive blast. Stand back.", {"vs": 1.3, "boom": 16.0, "bdmg": 320.0}],
		["minitnt", "Mini Charge", 10, 20, "#ffcc00", "Small blast. Good for blowing parts off on purpose.", {"vs": 0.6, "boom": 3.5, "bdmg": 70.0}],
	])
	_many(B, G, {"kind": "smoke", "vis": "smoke", "cfg": ch("always")}, [
		["smoke", "Smoke Trail", 10, 40, "#ff5ec4", "Leaves a colorful trail. Paint it to change the color.", {}],
		["rainbowsmoke", "Rainbow Trail", 10, 40, "#ffffff", "Smoke that cycles through every color.", {"rainbow": true}],
		["firetrail", "Fire Trail", 10, 40, "#ff7a2f", "Leaves a trail of flames.", {"fire": true}],
	])
	_many(B, G, {"kind": "light", "cfg": ch("act3", {"inv": true})}, [
		["light", "Headlight", 8, 30, "#2b2f36", "Bright spotlight. Toggle with 3.", {"energy": 6.0, "range": 45.0, "angle": 28.0}],
		["spotlight", "Searchlight", 30, 60, "#59616c", "Huge long-range beam.", {"vis": "light", "vs": 1.4, "energy": 14.0, "range": 110.0, "angle": 16.0}],
		["brakelight", "Brake Light", 4, 20, "#2b2f36", "Lights up red when you brake.", {"vis": "brakelight", "brake": true, "cfg": ch("throttle", {"inv": true})}],
		["underglow", "Underglow", 6, 20, "#ff5ec4", "Neon glow under the car. Takes its paint color.", {"vis": "underglow", "omni": true, "shape": "lid"}],
	])
	_many(B, G, {"kind": "blinker", "cfg": ch("act3", {"inv": true})}, [
		["strobe", "Strobe", 6, 20, "#ffffff", "Rapid white flashes.", {"rate": 0.08, "lcol": "#ffffff"}],
		["beacon", "Beacon", 8, 25, "#ff9a1f", "Slow orange warning flash.", {"rate": 0.5, "lcol": "#ff9a1f"}],
		["siren", "Police Lights", 15, 40, "#2b2f36", "Red and blue lights with a wailing siren on Toggle 3.", {"rate": 0.25, "lcol": "#ff2040", "lcol2": "#2060ff", "siren": true, "cfg": ch("act3")}],
	])
	_many(B, G, {"kind": "horn", "vis": "horn", "cfg": ch("horn")}, [
		["horn", "Horn", 8, 30, "#e0b341", "HONK. Press H.", {"pitch": 1.0}],
		["airhorn", "Air Horn", 15, 40, "#c8ced8", "Truck horn. Deep and loud.", {"vs": 1.3, "pitch": 0.55, "vol": 8.0}],
		["clownhorn", "Clown Horn", 5, 20, "#ff5ec4", "Honk honk.", {"vis": "clownhorn", "pitch": 2.2}],
	])
	_many(B, G, {}, [
		["shield", "Shield Generator", 60, 120, "#39e1ff", "Bubble shield while Toggle 1 is on: all damage cut by 75%.", {"cfg": ch("act1")}],
		["repair", "Repair Bot", 30, 80, "#3ddc84", "Slowly fixes damaged blocks. Can't bring back lost ones.", {"heal": 18.0, "cfg": ch("always")}],
		["nitro", "Nitro Tank", 35, 50, "#3fa9ff", "Shift shoves the whole vehicle forward. Refills when idle.", {"push": 14.0, "fuel": 3.0, "cfg": ch("boost")}],
		["airbag", "Airbag", 10, 40, "#f2f2f2", "Each airbag cuts crash damage. Stack a few.", {}],
		["selfrighter", "Self-Righter", 40, 100, "#ff9a1f", "Rolls you back onto your wheels when you are upside down.", {"cfg": ch("always")}],
		["blink", "Blink Drive", 40, 80, "#c05cff", "Teleports you 30 blocks forward on G. 4 second recharge.", {"cfg": ch("fire3")}],
		["flares", "Flare Launcher", 25, 60, "#ffcc00", "Pops a burst of bright flares on G.", {"cfg": ch("fire3")}],
		["dropweight", "Drop Weight", 150, 200, "#3d434b", "Heavy weight that lets go on Trigger 4.", {"cfg": ch("act4")}],
		["fueltank", "Fuel Tank", 40, 40, "#e53935", "Explodes violently if it gets destroyed. Don't get shot.", {"boom": 9.0, "bdmg": 180.0}],
		["flag", "Flag", 5, 30, "#e53935", "Flaps in the wind. Paint it your team color.", {}],
		["discoball", "Disco Ball", 10, 30, "#e0e6ee", "Spins and throws colored lights. Toggle 3.", {"cfg": ch("act3", {"inv": true})}],
		["cargocrate", "Cargo Crate", 60, 100, "#3d7a4a", "Heavy cargo box with a handle. Haul it around.", {"kind": "struct", "buoy": 0.3}],
	])
