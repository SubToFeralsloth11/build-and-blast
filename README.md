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
| R / T / F (Shift reverses) | Rotate the block around Y / X / Z |
| M | Toggle mirror building |
| B / P / C | Build / Paint / Configure tool |
| Ctrl+Z / Ctrl+Y | Undo / redo |
| Enter | Test drive at the last location |

In the garage, a yellow marker shows the centre of mass and a blue marker shows the centre of lift. Blocks that are not connected to the seat turn red, and they fall off when you test the vehicle. The bottom bar shows mass, thrust-to-weight, an estimated takeoff speed, lift and whether the vehicle floats.

**Configure** sets each engine, weapon, mechanism or gadget's control (any of 16 channels), inverts it, and sets its power from 25% to 200%. You can also set the steering mode (including tank steering) and drive for each wheel, and the movement mode for pistons and hinges. **Apply to all** copies a block's settings to every block of the same type.

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
| H | Horn |
| R / F / V | Respawn / flip upright / switch between chase and free camera |
| Tab / Esc / F1 | Back to the garage / pause menu / hide the help |

## Blocks (245)

Every block is listed in `scripts/block_catalog.gd`. Hover over a block in the palette to see its mass, armor and what it does.

- **Structure (51):** pilot seat, passenger seat, cockpit canopy. Shapes: block, wedge, plate, half block, low wedge, corner slope, inner corner, cylinder, beam, ball, pyramid, truss frame. Materials: steel, wood, armor, heavy armor, titanium (light and tough), carbon (featherweight), glass, lead ballast, foam, concrete, gold, chrome, neon (glows in its paint colour), rubber bumper (cuts crash damage nearby), plus hazard, crate, scrap, camo and checker looks.
- **Wheels (17):** wheel, monster, small, racing slick, off-road, tractor, mega, caster, spiked, drift, bike, rally, whitewall, hub motor, skate, ski, and tank tracks. Each has its own radius, travel, grip, side grip, torque and top speed. Tracks use **tank (skid) steering**, and any wheel can be switched to it in Configure.
- **Mechanical (37):** see below.
- **Propulsion (30):** thrusters (mini, normal, big), ion drive, plasma drive, jet, afterburner jet (more than double thrust on Shift), turbofan, ramjet (gets stronger with speed), pulse jet, twin jet, rockets (mini, normal, mega), solid booster (one 4-second burn), propellers (normal, big, contra-rotating, ducted fan), VTOL lifter, hover pads (normal and big, work over land and water), rotors (mini, normal, big), balloons (normal, hydrogen, steerable hot-air, blimp envelope), anti-grav core.
- **Flight (24):** wings (normal, small, thick, swept, delta, glider), tail fin, winglet, control flap, canard, big flap, elevator, aileron and rudder (each only does pitch, roll or yaw), air brake, spoilers and front splitter (downforce), parachute, drogue chute, gyros (mini, normal, super), auto leveler.
- **Water (17):** floats (normal, big), pontoon, inflatable tube, hull block, hull bow, keel (stops sideways sliding), boat rudder, hydrofoil, boat props (normal, big), water jet, paddle wheel, steerable outboard motor, **ballast tank** (C floods it to dive, Space blows it to surface) and anchor.
- **Weapons (36):** machine gun, minigun, heavy MG, sniper, shotgun, railgun (hits up to 4 things in a line), cannon, autocannon, howitzer, mortar, flak (shells burst at the crosshair), rocket pod, rocket barrage, homing missiles, homing torpedoes, plasma cannon, grenade launcher (bouncing grenades), laser, heavy laser, pulse laser, flamethrower, inferno cannon, auto turret, cannon turret, laser turret, tesla coil (lightning that jumps between targets), water cannon (pushes things, no damage), bomb bay, cluster bombs, mega bomb, mine layer, ram spike, buzz saw, drill, firework launcher, confetti cannon.
- **Gadgets (33):** spring jump, mega spring, magnet, super magnet, grabber claw, TNT, mega TNT, mini charge, smoke, rainbow and fire trails, headlight, searchlight, brake light, underglow, strobe, beacon, police lights with siren, horns (normal, air, clown), shield generator (75% less damage while on), repair bot, nitro, airbag, self-righter, blink drive (teleports 30 blocks forward), flares, drop weight, fuel tank (explodes if destroyed), flag, disco ball, cargo crate.

Each block has its own health. Bullets, explosions and hard crashes knock blocks off. Any part that loses its connection to the seat falls away as debris, and losing the seat wrecks the vehicle.

### Mechanisms

Pistons, hinges and rotators move every block attached to their **yellow/black striped face**, along with anything attached to those blocks. You can put mechanisms on top of other mechanisms (a turntable, then a hinge, then a piston makes a crane arm).

- **Pistons:** small, normal, long, telescopic (6 blocks), quick, hydraulic ram, hydraulic cylinder, pneumatic kicker, lift jack, pump piston.
- **Hinges:** hinge, servo, wide servo (180 degrees), heavy servo, fast servo, steering hinge, pitch/yaw/roll gimbals for thrust vectoring, landing gear hinge, tilt-rotor hinge, flipper arm, wiggle servo, sweep servo.
- **Rotators:** spinner, turntable, heavy motor, turbo spinner (always on).
- **Suspension:** coil spring, shock absorber, heavy, racing, long-travel, air suspension (Space/C changes the ride height), leaf spring, pogo leg. A wheel touching a suspension block gets that block's extra travel, stiffness and damping. With no wheel, the block works as a springy leg along its bottom face.
- **Decoupler:** Trigger 4 drops everything beyond it.

In **Configure**, each mechanism has a key, an invert option, a speed (Power) and a movement mode: **Return** follows the key and springs back, **Hold** stays wherever you leave it, and **Auto** swings back and forth by itself. Configure also shows how many blocks the mechanism moves. It warns you if the moving side also touches the rest of the vehicle, because then the mechanism is jammed and can't move.

## World

- **Desert Stunt Park:** ramps, a mega ramp, a gap jump, a loop, crate stacks, explosive barrels and practice targets
- **Airfield:** a runway, a hangar, drones, and a 12-ring sky course with lap times
- **Sea:** a pier with a launch ramp, islands and target boats
- **Mesas:** enemy plasma turrets. You can turn them off in the pause menu.
- **Score:** points for targets, barrels, rings, laps and airtime

## Presets and random builds

There are 16 presets: Starter Buggy, Battle Buggy, Monster Masher, Iron Rhino Tank, Nitro Rocket Car, Sky Sparrow, Thunder Jet, Bomber Pelican, Hornet Chopper, Wave Rider, Gunboat Kraken, Balloon Barge, Mega Crane (turntable, heavy servo, telescopic piston and super magnet), Bouncy Lowrider (air suspension), Hover Viper (hover pads) and Yellow Submarine (ballast tanks). **Random!** generates a new car, monster truck, plane, helicopter or boat with random size, colours, wheel type, suspension, weapons and gadgets. Planes are balanced so their centre of mass sits ahead of their lift. Helicopters get enough rotors to hover. Saved designs go to `user://designs/*.json`.

## Developer checks

```sh
# drive every preset + N random builds, crash/TNT tests, mechanism + submarine tests,
# spawn every block in the catalog and pulse every control, builder tests
godot --headless --fixed-fps 60 --path . -- --simtest --random=30
# trace one design frame by frame
godot --headless --fixed-fps 60 --path . -- --simtest --random=0 --only=Sparrow --verbose
# windowed screenshots into tools/out/
godot --path . -- --shots
```
