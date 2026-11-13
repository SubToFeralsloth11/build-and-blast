# Build & Blast

A Trailmakers-style vehicle sandbox for Godot 4.7. Build cars, planes, helicopters, boats and other machines out of blocks, then take them to the desert, the sea or the sky. Everything is made in code: meshes, sounds, terrain and UI. The project has no asset files, so it runs as soon as you open it.

## Run

Open the folder in Godot 4.7 and press Play, or run `godot --path .`

## Garage controls

| Input | Action |
|---|---|
| Left click | Place a block (Build), paint (Paint), select a block (Configure) |
| Right click / right drag | Delete a block / orbit the camera |
| Middle drag / middle click | Pan / pick up the hovered block type |
| Mouse wheel | Zoom |
| R / T / F (Shift reverses) | Rotate the block around Y / X / Z, 45 degrees per press |
| G | Switch the rotation step between 45 and 90 degrees |
| [ / ] | Shrink / grow the next structure block (all sides) |
| M | Toggle mirror building |
| B / P / C | Build / Paint / Configure tool |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Enter | Test drive at the place picked under TEST |

In the garage, a yellow marker shows the centre of mass and a blue marker shows the centre of lift. Blocks that are not connected to the seat turn red, and they fall off when you test the vehicle. The bottom bar shows mass, thrust-to-weight, an estimated takeoff speed, lift and whether the vehicle floats.

New blocks snap flush against the face you point at, so they sit right on top of half blocks and plates, against sideways half blocks, along the sides of resized blocks, and against blocks turned 45 degrees (they line up with the turned block). On a long face, a block slides along it in whole-block steps (half-block steps for blocks smaller than 1).

**Sizes:** every Structure block except the pilot seat can be 0.25 to 8 blocks along each side, in 0.25 steps. Set the size before placing with the Width/Height/Length buttons in the right panel or [ / ], or select a placed block with Configure to resize it (it grows around its centre). Mass, armor and buoyancy scale with volume. Mechanical parts, wheels, engines, weapons and gadgets keep their size.

**Configure** sets each engine, weapon, mechanism or gadget's control (any of 16 channels), inverts it, and sets its power from 25% to 200%. You can also set the steering mode (including tank steering) and drive for each wheel, and the movement mode, cycle start and tank steering for pistons and hinges. **Apply to all** copies a block's settings to every block of the same type (each mechanism keeps its own cycle start).

## Test drive controls

| Input | Action |
|---|---|
| W / S | Throttle and brake (wheels, thrusters, jets, propellers, boat props) |
| A / D | Steer (wheels), yaw (flaps, gyros) |
| Arrows (or I J K L) | Pitch and roll (flaps, gyros) |
| Q / E | Yaw |
| Space / C | Lift (helicopter rotors, Spring Jump) |
| Shift | Boost (Rocket Booster) |
| Left / Right mouse, G | Fire 1 / 2 / 3 |
| 1 2 3 | Toggles (magnet, parachute, lights) |
| 4 | Trigger (TNT) |
| R / F / V | Respawn / flip upright / camera: chase, free orbit, first person |
| X | Get out of the vehicle / get back in (stand within about 4 m of it) |
| Tab / Esc / F1 | Back to the garage / pause menu / hide the help |

On foot: WASD to walk, Shift to sprint, Space to jump (and to swim up in water), mouse to look, V switches first and third person. While you are out, the vehicle gets no driving input, but toggles you switched on stay on. R puts you back in the seat of a fresh vehicle.

## Places

Pick a place in the **TEST** dropdown at the top right of the garage, then press **Test drive** (or Enter). The pause menu (Esc) teleports between them.

- **Desert:** stunt park with ramps, a loop, crates, explosive barrels, practice targets and enemy turrets on the mesas.
- **Race Track:** a looped circuit in the dunes south of the stunt park, with curbs, a start/finish gantry, a grandstand and barriers on the outside of the corners. You start just before the line. Crossing it starts the lap clock; a lap counts once you pass all three sectors in order. The HUD shows the running lap time, and the best lap stays in the stats panel.
- **Sea:** harbor with a pier and launch ramp, open sea, islands and enemy boats.
- **Carrier:** a stationary aircraft carrier out at sea, 290 m long with an 18 m high flight deck, an angled landing deck, catapult tracks and an island with a turning radar. You spawn on the stern end of the deck facing the bow, so planes can take off, and you can land back on it.
- **Runway / Sky:** the airfield, or a mid-air start at 230 m.
- **Test Zone:** a separate 4 km by 4 km flat white floor with a 1 m grid (darker lines every 10 m and 100 m, a red X axis and a blue Z axis through the spawn). Nothing else is there. Drive off the yellow edge and you respawn.

**Screen shake** (pause menu): Off, Low, Normal, Strong or Extreme. The choice is saved.

## Blocks (247)

Every block is listed in `scripts/block_catalog.gd`. Hover over a block in the palette to see its mass, armor and what it does.

- **Structure (51):** pilot seat, passenger seat, cockpit canopy. Shapes: block, wedge, plate, half block, low wedge, corner slope, inner corner, cylinder, beam, ball, pyramid, truss frame. Materials: steel, wood, armor, heavy armor, titanium (light and tough), carbon (featherweight), glass, lead ballast, foam, concrete, gold, chrome, neon (glows in its paint colour), rubber bumper (cuts crash damage nearby), plus hazard, crate, scrap, camo and checker looks.
- **Wheels (17):** wheel, monster, small, racing slick, off-road, tractor, mega, caster, spiked, drift, bike, rally, whitewall, hub motor, skate, ski, and tank tracks. Each has its own radius, travel, grip, side grip, torque and top speed. Tracks use **tank (skid) steering**, and any wheel can be switched to it in Configure.
- **Mechanical (39):** see below.
- **Propulsion (30):** thrusters (mini, normal, big), ion drive, plasma drive, jet, afterburner jet (more than double thrust on Shift), turbofan, ramjet (gets stronger with speed), pulse jet, twin jet, rockets (mini, normal, mega), solid booster (one 4-second burn), propellers (normal, big, contra-rotating, ducted fan), VTOL lifter, hover pads (normal and big, work over land and water), rotors (mini, normal, big), balloons (normal, hydrogen, steerable hot-air, blimp envelope), anti-grav core.
- **Flight (24):** wings (normal, small, thick, swept, delta, glider), tail fin, winglet, control flap, canard, big flap, elevator, aileron and rudder (each only does pitch, roll or yaw), air brake, spoilers and front splitter (downforce), parachute, drogue chute, gyros (mini, normal, super), auto leveler.
- **Water (17):** floats (normal, big), pontoon, inflatable tube, hull block, hull bow, keel (stops sideways sliding), boat rudder, hydrofoil, boat props (normal, big), water jet, paddle wheel, steerable outboard motor, **ballast tank** (C floods it to dive, Space blows it to surface) and anchor.
- **Weapons (36):** machine gun, minigun, heavy MG, sniper, shotgun, railgun (hits up to 4 things in a line), cannon, autocannon, howitzer, mortar, flak (shells burst at the crosshair), rocket pod, rocket barrage, homing missiles, homing torpedoes, plasma cannon, grenade launcher (bouncing grenades), laser, heavy laser, pulse laser, flamethrower, inferno cannon, auto turret, cannon turret, laser turret, tesla coil (lightning that jumps between targets), water cannon (pushes things, no damage), bomb bay, cluster bombs, mega bomb, mine layer, ram spike, buzz saw, drill, firework launcher, confetti cannon.
- **Gadgets (33):** spring jump, mega spring, magnet, super magnet, grabber claw, TNT, mega TNT, mini charge, smoke, rainbow and fire trails, headlight, searchlight, brake light, underglow, strobe, beacon, police lights with siren, horns (normal, air, clown), shield generator (75% less damage while on), repair bot, nitro, airbag, self-righter, blink drive (teleports 30 blocks forward), flares, drop weight, fuel tank (explodes if destroyed), flag, disco ball, cargo crate.

Each block has its own health. Bullets, explosions and hard crashes knock blocks off. Any part that loses its connection to the seat falls away as debris, and losing the seat wrecks the vehicle.

### Mechanisms

Pistons, hinges and rotators move every block attached to their **yellow/black striped face**, along with anything attached to those blocks. You can put mechanisms on top of other mechanisms (a turntable, then a hinge, then a piston makes a crane arm).

- **Pistons:** small, normal, long, telescopic (6 blocks), quick, hydraulic ram, hydraulic cylinder, pneumatic kicker, lift jack, pump piston, leg lifter.
- **Hinges:** hinge, servo, wide servo (180 degrees), heavy servo, fast servo, steering hinge, pitch/yaw/roll gimbals for thrust vectoring, landing gear hinge, tilt-rotor hinge, flipper arm, wiggle servo, sweep servo, leg servo.
- **Rotators:** spinner, turntable, heavy motor, turbo spinner (always on).
- **Suspension:** coil spring, shock absorber, heavy, racing, long-travel, air suspension (Space/C changes the ride height), leaf spring, pogo leg. A wheel touching a suspension block gets that block's extra travel, stiffness and damping. With no wheel, the block works as a springy leg along its bottom face.
- **Decoupler:** Trigger 4 drops everything beyond it.

In **Configure**, each mechanism has a key, an invert option, a speed (Power) and a movement mode: **Return** follows the key and springs back, **Hold** stays wherever you leave it, **Auto** swings back and forth by itself, and **Step** (pistons only) pushes out for the first half of each cycle and stays retracted for the second half. Auto and Step cycles run forward on a positive key and backward on a negative one (W forward, S backward). **Cycle start** sets where in the cycle each one begins (0 to 315 degrees). **Tank steer** mixes in A/D so that the mechanisms on one side run backward while the other side runs forward. Configure also shows how many blocks the mechanism moves. It warns you if the moving side also touches the rest of the vehicle, because then the mechanism is jammed and can't move.

**Walkers:** a leg is a **Leg Servo** hip (swings 20 degrees forward and back) carrying a **Leg Lifter** (lifts the leg 1 block) with a suspension block as the foot. Both run on W/S with tank steer and **Sprint** (Shift nearly doubles the stride rate) on by default, and cycle at the same speed. Set the hip's cycle start 90 degrees behind its lifter on the right side and 90 degrees ahead on the left, and give neighbouring legs cycle starts 180 degrees apart. The ground grips a planted foot as it sweeps backward, so the vehicle walks. A Leg Servo turned to hang down makes a swinging arm. The Widowmaker Spider and Titan Mech presets are working examples. Two-legged walkers stand on one foot at a time, so they need gyros and should turn with them (tank steer off).

## World

- **Desert Stunt Park:** ramps, a mega ramp, a gap jump, a loop, crate stacks, explosive barrels and practice targets
- **Airfield:** a runway, a hangar, drones, and a 12-ring sky course with lap times
- **Sea:** a pier with a launch ramp, islands and target boats
- **Mesas:** enemy plasma turrets. You can turn them off in the pause menu.
- **Score:** points for targets, barrels, rings, laps and airtime

## Presets and random builds

There are 20 presets: Starter Buggy, Battle Buggy, Monster Masher, Iron Rhino Tank, Nitro Rocket Car, Sky Sparrow, Thunder Jet, Bomber Pelican, Hornet Chopper, Wave Rider, Gunboat Kraken, Balloon Barge, Mega Crane (turntable, heavy servo, telescopic piston and super magnet), Bouncy Lowrider (air suspension), Hover Viper (hover pads), Yellow Submarine (ballast tanks), Widowmaker Spider (an eight-legged walker: W/S walk, A/D turn on the spot, Shift pounces on four belly rockets, lasers and an auto turret on Fire 1, rocket pods on Fire 2, tesla coil on G), Titan Mech (a two-legged mech whose arms swing opposite its legs: W/S walk, Shift sprint, A/D turn with two super gyros, miniguns on Fire 1, missiles on Fire 2, head cannon on G), Blackbird (a long black recon jet with delta wings, nacelle afterburners and ramjets, Shift for afterburner) and Riptide Speedboat (hydrofoils, three propellers and two afterburning jets, Shift for afterburner). **Random!** generates a new car, monster truck, plane, helicopter or boat with random size, colours, wheel type, suspension, weapons and gadgets. Planes are balanced so their centre of mass sits ahead of their lift. Helicopters get enough rotors to hover. Saved designs go to `user://designs/*.json`.

## Battery use

- The game is capped at 60 FPS, so 120 Hz screens don't draw twice as many frames.
- The garage and the pause menu drop to 20 FPS after 1.5 seconds without input. Any input brings back 60.
- Clicking away from the window pauses the test drive and drops the game to 8 FPS.
- **Battery saver** (button in the garage's bottom bar and in the pause menu) cycles Auto / On / Off. Auto turns it on while the laptop is unplugged (checked every 30 s on macOS and Linux). It renders the 3D view at a lower resolution with FSR upscaling, halves the shadow map and turns off MSAA. The UI stays sharp and the game keeps 60 FPS. The choice is saved in `user://settings.cfg`.

## Developer checks

```sh
# drive every preset + N random builds, crash/TNT tests, mechanism + submarine tests,
# spawn every block in the catalog and pulse every control, builder tests,
# race track / carrier / test zone and missile particle tests
godot --headless --fixed-fps 60 --path . -- --simtest --random=30
# only the race track / carrier / test zone and missile tests
godot --headless --fixed-fps 60 --path . -- --simtest --worldtest
# trace one design frame by frame
godot --headless --fixed-fps 60 --path . -- --simtest --random=0 --only=Sparrow --verbose
# windowed screenshots into tools/out/ (add --worldshots for the new places only)
godot --path . -- --shots
```
