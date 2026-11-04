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
- `docs/` contains practical guides, including [写实车模制作与接入经验](docs/vehicle-modeling-guide.md)

## Getting Started

1. Open the project in Godot 4.
2. Run the project, click Start, then select a vehicle card and a scene card.
3. Duplicate or inherit from `cars/BaseCar.tscn` to create your own car variants.

## Credits

- **Project Creator:** Manik Sharma
- **Jimny body asset:** [2023 Suzuki Jimny Sierra](https://sketchfab.com/3d-models/2023-suzuki-jimny-sierra-8b7c4d136f6742e180faf654d874f14a)
  by [tonielpro520](https://sketchfab.com/tonielpro520), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
  Adapted materials, dimensions, wheel rig and running gear; see [asset notes](cars/Models/Jimny/ASSET_NOTES.md).
- **Contributors:**
  - ShadowDara
  - Weasel On A Stick

## Vehicle garage

Click **开始游戏** (Start), choose a vehicle, then choose a scene to drive. The sedan is preserved; the new **牧马人 · 越野** is an original procedural
Wrangler-style model inspired by the restrained, low-poly look of *over the hill*.
It does not use assets extracted from that game.

- **WASD / arrow keys:** accelerate, reverse and steer.
- **Space:** brake (the sedan also drifts).
- **P:** toggle parking on all vehicles after slowing below 3 km/h with wheels on the ground.
  The HUD shows P; press P again to release before accelerating.
- **R:** sedan gears / off-roader high and low range / A6 allroad comfort and terrain modes.
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

Parking uses a ground-relative constraint along the contact plane, leaving suspension
compression and body roll active. Throttle cannot release P. Airborne engagement is
rejected, and an already parked car falls naturally if its support disappears.
Esc preserves P and acquires a new parking anchor after landing at the spawn point.

Both Wrangler models include articulated solid axles, differential housings with
bolted covers, front/rear propeller shafts and universal joints, control arms,
Panhard bars, steering knuckles and tie rod, telescoping dampers and coil springs.
Frame crossmembers, transmission/transfer case, skid plates, fuel tank protection
and exhaust complete the underside. The running gear follows the same suspension
travel as the wheels; cylinder length is scaled in its local axis so transverse
axles actually reach both hubs. These are visual components, sharing the existing
contact-based physics rather than adding separate rigid-body joints.

```sh
./run.sh --headless --fixed-fps 60 --script tests/ParkingChecks.gd
./run.sh --headless --script tests/ChassisChecks.gd
./run.sh --script tests/ChassisVisualReview.gd --resolution 1152x648
```

Parking checks cover all three vehicles on uphill, downhill and cross slopes,
accelerator interlock, release, high-speed/airborne rejection, loss of support,
key-repeat suppression, reset and both HUDs. Chassis checks exercise axle and
propshaft endpoints through suspension articulation; visual review saves
`/tmp/chassis-{Wrangler,Rubicon}-{under,articulation}.png` and `/tmp/parking-coast.png`.

Both off-roaders now use full low-speed drive force followed by a constant-power
region, with a smooth governor near the range limit. The cartoon Wrangler uses
11 kN / 110 kW at the wheels; the heavier Rubicon uses 14 kN / 140 kW. These are
simulation tuning values. Low range multiplies starting torque by 1.8 and limits
speed to 10 m/s; reverse has its own 8 m/s limit. Rolling resistance follows tire
load, and explicit body damping replaces the project default rather than stacking
with it. Contact/load-based grip and lift-off engine braking remain part of the model.

```sh
./run.sh --headless --fixed-fps 60 --script tests/OffroadPowerChecks.gd
```

The power checks measure flat-road acceleration, 18% high-range hill starts,
30% low-range climbs, chassis stability, and braking from road speed.


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

- **滨海道路 / Coastal Drive:** a 2.63 km mountain-coast loop inspired by Laoshan,
  with granite headlands, coves, red-tiled villages, wooded slopes, and tea terraces (first card).
- **松林山谷 / Pine Valley:** a deterministic 320 × 320 metre landscape with rolling
  hills, a dirt-road loop, three shallow water pits, pine trees, rocks and signs (second card).
  Start on the flat clearing and follow the road ahead to the first water crossing.
- **原型测试场 / Prototype:** the original purple ramps and suspension test area (third card).

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

## Audi A6 allroad — quattro touring wagon

The fifth card, **奥迪 A6 allroad**, adds a C8-inspired wagon authored by
`tools/build_allroad.py`: green metallic paint, gray arch cladding, aluminum trim,
transparent glazing, a long roof with rails, segmented lights and a modeled cabin.
Its 2.925 m wheelbase and 235/55 R18 tires are shared by the visual and physics rig.
This is a dimensioned game interpretation, with simplified surfaces and details.

The underbody uses independent five-link corners, air-spring visuals, four CV
halfshafts, fixed differentials, adaptive-damper visuals, undertrays and exhausts.
R selects comfort / terrain damping; it does not engage a low-range gearbox.
All locations, P parking, V views and mouse inspection work with this vehicle.
Scroll the vehicle cards horizontally to reach all five cars. See
[Allroad model notes](cars/Models/Allroad/ASSET_NOTES.md) for references and checks.

## Jimny JB74 — compact three-door 4×4

The fourth vehicle card, **吉姆尼 · JB74**, adds a Kinetic Yellow / black-roof
Jimny Sierra with transparent windows, a detailed cabin, lamps and a rear spare.
The adapted body retains the credited source mesh and textures; the independently
animated chassis uses radius arms and Panhard rods, front disc / rear drum brakes,
an X-braced ladder frame, transfer case, propshafts, tank and exhaust.

The 2.25 m wheelbase and 195/80 R15 tire envelope match the physics. Its lighter
1,100 kg body has separate spring, damping and power tuning. All three locations,
P parking, R low range, mouse inspection and the four V views are supported.
See [Jimny asset notes](cars/Models/Jimny/ASSET_NOTES.md) for the source credit,
modeling choices, reference links and rebuild / verification commands.

## Rubicon 35 — detailed vehicle

The third card, **牧马人 · 卢比肯**, uses an adapted detailed Wrangler body from
the local `jeep-wrangler-adventure-rubicon-wwwvecarzcom` asset package. The original
sedan and cartoon Wrangler remain available. The open source body has been adapted
with four sculpted doors, separate framed windows, a curved hardtop and rear glazing.
Paint, molded trim, leather and hardtop use embedded normal/roughness maps; supplied
interior, tire, badge and carpet textures are reconnected. See
[cars/Models/Rubicon/ASSET_NOTES.md](cars/Models/Rubicon/ASSET_NOTES.md) for provenance,
reference photos and rebuild details.

The four running tires have a measured 0.889 m / 35-inch outside diameter, matched
by the physics radius of 0.4445 m. Wheel and rotor pivots preserve the 3.008 m
wheelbase, steering and suspension animation. The driver viewpoint and body
collision envelope fit the revised body. Mass, spring/damper rates and power remain
gameplay tuning values.

`cars/RubiconChassis.gd` provides a separate detailed underbody: shaped boxed frame
rails, axle housings and bolted differential covers, offset front differential,
gearbox/transfer case, articulated propshafts, upper/lower control arms, Panhard
bars, spring seats, dampers, steering links/stabilizer, brake hoses, tank cradle,
separate ribbed protective plates and an over-axle exhaust with transverse muffler.
Its layout follows real JL underbody photographs; this is a game model, not CAD
or a full multibody suspension solver. The cartoon model retains its own chassis.

The game uses the exported `cars/Models/Rubicon/Rubicon.glb`, with textures embedded;
Blender and the source download are only required to rebuild. Godot also extracts
texture files alongside the GLB during import. `tools/build_rubicon.py` is the
previous procedural prototype generator; rebuilding that script replaces the new
body with the historical prototype. The current pipeline is:

```sh
blender --background --python tools/import_rubicon.py -- --source /path/to/jeep-wrangler-adventure-rubicon-wwwvecarzcom
./run.sh --headless --editor --import --quit
./run.sh --headless --fixed-fps 60 --script tests/RubiconChecks.gd
./run.sh --headless --script tests/RubiconAssetChecks.gd
./run.sh --headless --script tests/ChassisChecks.gd
./run.sh --script tests/RubiconRealismReview.gd --resolution 1440x810
./run.sh --script tests/ChassisVisualReview.gd --resolution 1440x810
```

Checks cover actual tire mesh diameter, runtime material maps and glazing, wheel
and shaft attachment through articulation, card selection, suspension, low range,
reset, water crossings and braking. Exterior/cockpit screenshots are saved as
`/tmp/rubicon-realism-*.png`; underside views as `/tmp/chassis-Rubicon-*.png`.

Camera input and all vehicle/location combinations:

```sh
./run.sh --headless --fixed-fps 60 --script tests/CameraChecks.gd
./run.sh --fixed-fps 60 --script tests/CameraChecks.gd # Includes real-window HUD hit testing
./run.sh --script tests/CameraVisualReview.gd --resolution 1152x648
```

## Coastal Drive

The coastal scene now draws on Laoshan's granite coast and the Taiqing–Qingshan
mountain-road landscape. This is an original compact driving layout inspired by the
region, not a surveyed or one-to-one reproduction. The continuous two-lane road runs
2.63 km through alternating S bends and climbs from approximately 10 to 71 metres,
with a maximum grade of about 17.3%. A mountain neck, multiple rocky headlands,
recessed coves, forested ridges, three red-roofed hamlets (42 houses), and 27 tea rows
replace the former low, oval island and distant snow peaks. Signs warn of successive
bends, and guardrails follow the road elevation.

Terrain and architecture references:
[Laoshan scenic area's coastal geology](https://qdlaoshan.cn/Jing-info-jid-379.html),
[Qingdao Government Information Office's Taiqing coastal-road feature](https://m.thepaper.cn/newsDetail_forward_22542717).
The first describes granite cliffs, headlands, reefs, and bays; the second shows
winding coastal roads, red-tiled fishing villages, wooded hills, and tea terraces.

A circular north-up minimap at bottom left shows the actual loop, start marker, and
live vehicle position/heading. The bottom-right speedometer displays actual km/h,
a smoothed needle, and direction/gear or 4H/4L; suspension travel moves to the top right.
The instruments do not intercept mouse orbit controls.

All three vehicles and all four camera views work here. The terrain, road, guardrails,
houses, and tree trunks have collision; the sea is scenery. Falling into the water
returns the car to the last safe road section, while Esc returns to the starting point.

`Scenes/coastal/CoastalTerrain.gd` builds the playable landscape and a lighter scene-card
preview from the same geometry. Mesh instances batch trees, building details, and road
furniture; local shaders animate the sea and shade foliage, granite, and clouds. A height
texture derived from the actual terrain keeps water depth color and foam aligned with
the new coastline. Fine road-bed geometry replaces coarse ground triangles near the
asphalt so terrain cannot cut through the road surface. No downloaded
assets or reference-image file are needed to run the scene.

```sh
./run.sh --headless --fixed-fps 60 --script tests/CoastalChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/CoastalHUDChecks.gd
./run.sh --headless --fixed-fps 60 --script tests/CoastalLapChecks.gd
./run.sh --script tests/CoastalVisualReview.gd --resolution 1152x648
```

Checks cover menu selection, both lanes around the full loop, guardrail collision,
all vehicles and camera views, acceleration, reset, and recovery from the sea. The
mountain checks also measure grades, elevation gain, and alternating turns. A separate
physical driving check steers the Rubicon through a complete lap, including the climbs.
Visual review saves `/tmp/coast-scene-cards.png`, `/tmp/coast-drive.png`,
`/tmp/coast-cockpit.png`, and `/tmp/coast-overview.png`.
