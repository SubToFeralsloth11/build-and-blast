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

**Configure** sets each engine, weapon or gadget's control (any of 16 channels), inverts it, and sets its power from 25% to 200%. You can also set steering mode and drive for each wheel. **Apply to all** copies a block's settings to every block of the same type.

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

## Blocks (33)

- **Structure:** pilot seat, block, wood (floats), armor, wedge, thin plate
- **Wheels:** wheel, monster wheel. Both have raycast suspension, and front wheels steer by default.
- **Propulsion:** thruster, jet engine (air only), rocket booster, propeller, helicopter rotor (holds altitude, W/S tilts it), balloon
- **Flight:** wing, control flap, gyro stabilizer, parachute. Flaps steer automatically from where you place them: behind the centre of mass they control pitch, out on the wings they control roll, and upright ones control yaw.
- **Water:** float, boat propeller
- **Weapons:** machine gun, cannon, homing rocket pod, laser, flamethrower, bomb bay, auto turret. Guns lock onto the crosshair when it is close to where they point.
- **Gadgets:** spring jump, magnet, TNT, smoke trail (takes its paint colour), headlight, horn

Each block has its own health. Bullets, explosions and hard crashes knock blocks off. Any part that loses its connection to the seat falls away as debris, and losing the seat wrecks the vehicle.

## World

- **Desert Stunt Park:** ramps, a mega ramp, a gap jump, a loop, crate stacks, explosive barrels and practice targets
- **Airfield:** a runway, a hangar, drones, and a 12-ring sky course with lap times
- **Sea:** a pier with a launch ramp, islands and target boats
- **Mesas:** enemy plasma turrets. You can turn them off in the pause menu.
- **Score:** points for targets, barrels, rings, laps and airtime

## Presets and random builds

There are 12 presets: Starter Buggy, Battle Buggy, Monster Masher, Iron Rhino Tank, Nitro Rocket Car, Sky Sparrow, Thunder Jet, Bomber Pelican, Hornet Chopper, Wave Rider, Gunboat Kraken and Balloon Barge. **Random!** generates a new car, monster truck, plane, helicopter or boat with random size, colours, weapons and gadgets. Planes are balanced so their centre of mass sits ahead of their lift. Helicopters get enough rotors to hover. Saved designs go to `user://designs/*.json`.

## Developer checks

```sh
# drive every preset + N random builds through scripted inputs, crash tests, builder tests
godot --headless --fixed-fps 60 --path . -- --simtest --random=30
# trace one design frame by frame
godot --headless --fixed-fps 60 --path . -- --simtest --random=0 --only=Sparrow --verbose
# windowed screenshots into tools/out/
godot --path . -- --shots
```
