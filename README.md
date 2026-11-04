# Car-Demo

A simple Godot 4 demo focused on building and driving modular car setups.

![Car demo screenshot](cars/Screenshot.png)

![Doge icon](cars/doge-icon.png)

## Overview

Car-Demo is a lightweight learning project for vehicle gameplay in Godot. It includes a reusable base car setup, a follow camera, and scene examples that make it easier to prototype your own vehicle variations.

## Features

- Playable base car controller
- Dynamic follow camera system
- GLTF-based car and wheel model workflow
- Inheritance-friendly scene structure for rapid variants
- Extra environment elements (spinning and bobbing platforms) for testing

## Project Structure

- `cars/` contains car scenes, models, and camera logic
- `Scripts/` contains reusable gameplay scripts (reset, spinning, bobbing)
- `Scenes/` contains test and environment scenes

## Getting Started

1. Open the project in Godot 4.
2. Run the project, click Start, then select a vehicle card and a scene card.
3. Duplicate or inherit from `cars/BaseCar.tscn` to create your own car variants.

## Credits

- **Project Creator:** Manik Sharma
- **Contributors:**
  - ShadowDara
  - Weasel On A Stick

## Vehicle garage

Click **开始游戏** (Start), choose a vehicle, then choose a scene to drive. The sedan is preserved; the new **牧马人 · 越野** is an original procedural
Wrangler-style model inspired by the restrained, low-poly look of *over the hill*.
It does not use assets extracted from that game.

- **WASD / arrow keys:** accelerate, reverse and steer.
- **Space:** brake (the sedan also drifts).
- **R:** sedan gears / off-roader high and low range.
- **Esc:** reset the selected vehicle.
- **V:** cycle rear → side → first-person → top view.
- **Left / right mouse drag:** orbit the vehicle, or look around in first-person.
- **Mouse wheel:** zoom (adjust field of view in first-person).
- **C:** restore the current view after inspection.
- **G / 选车 / 场景:** return to vehicle selection, then choose another scene.

The off-roader uses a 1,800 kg rigid body with four raycast tire contacts,
34 kN/m springs, separate compression/rebound damping, progressive bump stops,
load-limited tire grip, four-wheel drive and modest anti-roll coupling. Wheel
positions, shock lengths and axle articulation follow the simulated suspension.
The four HUD bars display suspension compression; dim bars mean no ground contact.
This is a game-oriented suspension simulation, not a full multibody model of the
Wrangler's solid axles. Tune its exported parameters in `cars/OffroadCar.gd`.

Run with a Godot 4.6 editor binary (export templates cannot open source projects):

```sh
./run.sh
# Or: GODOT_BIN=/path/to/Godot ./run.sh
```

Regression checks (menu selection, both cars, settling, obstacle articulation,
braking, low range and airborne traction):

```sh
godot --headless --path . --fixed-fps 60 --script tests/VehicleChecks.gd
```

Visual review on a desktop session (writes screenshots to `/tmp/car-*.png`):

```sh
godot --path . --script tests/VisualReview.gd --resolution 1440x810
```

## Scene selection

All three vehicles can drive in any of the three locations. The scene screen remembers the last
choice; its Back button (or Esc) returns to vehicle selection.

- **松林山谷 / Pine Valley:** a deterministic 320 × 320 metre landscape with rolling
  hills, a dirt-road loop, three shallow water pits, pine trees, rocks and signs.
  Start on the flat clearing and follow the road ahead to the first water crossing.
- **原型测试场 / Prototype:** the original purple ramps and suspension test area (second card).
- **滨海道路 / Coastal Drive:** a 1.10 km paved island loop, turquoise sea, coastal
  guardrails, wooded hills, roadside houses, and distant snowy mountains (third card).

The landscape's collision mesh matches its visible terrain, including the pond
basins. Tree trunks and rocks also collide with cars. Water adds mass-scaled drag,
reduces the off-roader's tire grip, and generates spray and wake rings while moving.
This is shallow-water driving feedback, not a fluid or buoyancy simulation.
A terrain-aware camera avoids hills and tree trunks; Esc returns to the clearing.
Leaving the playable map also resets the vehicle to its spawn.

Terrain generation and route/puddle definitions live in
`Scenes/offroad/OffroadTerrain.gd`; water feedback and lighting are in
`Scenes/offroad/OffroadWorld.gd`. Preview and playable terrain share the same seed.

```sh
./run.sh --headless --fixed-fps 60 --script tests/TerrainChecks.gd
./run.sh --script tests/TerrainVisualReview.gd --resolution 1440x810
```

The terrain checks cover scene navigation, both vehicles, terrain and tree
collisions, water entry/exit, reduced grip and drag, reset, and returning to the
original playground. The visual review saves `/tmp/car-scene-cards.png` and
`/tmp/car-valley-*.png`.

## Rubicon 35 — detailed vehicle

The third card, **牧马人 · 卢比肯**, adds a separate four-door JL Rubicon-inspired
model. The original sedan and cartoon off-roader remain available. It has metallic
clearcoat paint, rounded panel edges, open grille slots, LED headlight rings,
individual windows, seats and dashboard, door hinges, hood badges, a winch, red
recovery hooks, and a matching rear spare.

The rubber mesh (including tread tips) has a measured 0.889 m / 35-inch outside
diameter, matched by the physics wheel radius of 0.4445 m. The 17-inch rims have
split spokes and separate lug/bead-ring bolts. Four moving wheels use the new
3.008 m wheelbase; suspension travel is constrained to fit the high-clearance
fenders. Its mass, spring/damper rates and drive force are gameplay tuning values,
not a manufacturer-certified vehicle dynamics model.

This is original, procedurally authored geometry with PBR materials, not a scanned
or licensed factory CAD asset. The current model approximates JL Rubicon styling;
it does not claim a photogrammetry-level reproduction. Public references used for
proportions and styling:

- [Jeep / Stellantis Wrangler specifications](https://stellantis-wn2025-assetlib.s3.amazonaws.com/resources/2025_JP_Wrangler_SP.pdf)
- [Jeep Xtreme 35 package announcement](https://blog.stellantisnorthamerica.com/2024/01/24/jeep-brand-brings-35-inch-tires-to-two-door-2024-wrangler-for-the-first-time-ever/)
- [2024 Rubicon exterior reference](https://www.carsales.com.au/editorial/details/2024-jeep-wrangler-coming-with-four-cylinder-turbo-petrol-power-143636/)

The reusable Blender generator is `tools/build_rubicon.py`; the game uses the
exported `cars/Models/Rubicon/Rubicon.glb`, so Blender is not needed to play.
Geometry is batched by material and the five wheel assemblies share meshes.

```sh
blender --background --factory-startup --python tools/build_rubicon.py
./run.sh --headless --editor --import --quit
./run.sh --headless --fixed-fps 60 --script tests/RubiconChecks.gd
./run.sh --script tests/RubiconVisualReview.gd --resolution 1440x810
```

The new checks cover card selection, dimensions, settled suspension, matching
visual wheel positions, low range, reset, both scenes, water crossings and braking.
The visual review saves `/tmp/rubicon-{home,cards,front,rear,tire}.png`.

Camera input and all vehicle/location combinations:

```sh
./run.sh --headless --fixed-fps 60 --script tests/CameraChecks.gd
./run.sh --fixed-fps 60 --script tests/CameraChecks.gd # Includes real-window HUD hit testing
./run.sh --script tests/CameraVisualReview.gd --resolution 1152x648
```

## Coastal Drive

The coastal scene follows the supplied reference's waterfront bends, roadside village,
wooded slopes, and distant mountain setting. The road is a continuous two-lane loop
with edge lines, dashed center markings, shoulders, metal guardrails, and street lamps.
A circular north-up minimap at bottom left shows the actual loop, start marker, and
live vehicle position/heading. The bottom-right speedometer displays actual km/h,
a smoothed needle, and direction/gear or 4H/4L; suspension travel moves to the top right.
The instruments do not intercept mouse orbit controls.

All three vehicles and all four camera views work here. The terrain, road, guardrails,
houses, and tree trunks have collision; the sea is scenery. Falling into the water
returns the car to the last safe road section, while Esc returns to the starting point.

`Scenes/coastal/CoastalTerrain.gd` builds the playable landscape and a lighter scene-card
preview from the same geometry. Mesh instances batch trees, building details, and road
furniture; local shaders animate the sea and shade foliage and clouds. No downloaded
assets or reference-image file are needed to run the scene.

```sh
./run.sh --headless --fixed-fps 60 --script tests/CoastalChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/CoastalHUDChecks.gd
./run.sh --script tests/CoastalVisualReview.gd --resolution 1152x648
```

Checks cover menu selection, both lanes around the full loop, guardrail collision,
all vehicles and camera views, acceleration, reset, and recovery from the sea.
Visual review saves `/tmp/coast-scene-cards.png`, `/tmp/coast-drive.png`,
`/tmp/coast-cockpit.png`, and `/tmp/coast-overview.png`.
