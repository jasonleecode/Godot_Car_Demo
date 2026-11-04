# Rubicon asset and adaptation

The current body derives from the local asset package
`jeep-wrangler-adventure-rubicon-wwwvecarzcom`, specifically
`source/jeep wrangler adventure rubicon001.glb` and its `textures/` directory.
The original package was found under `~/Downloads/3D_model/car/`.
The entire vehicle geometry is therefore **not** an original procedural creation.

`tools/import_rubicon.py` restores material/texture links, normalizes the coordinate
system, creates separate steering/spinning wheel pivots, measures the 35-inch tire
envelope, removes duplicate wheel-face surfaces and static running gear, and
simplifies hidden engine/interior geometry. It generates deterministic seamless
normal and roughness maps for paint, molded trim, hardtop and leather.

The supplied vehicle has an open cabin. `tools/rubicon_body_panels.py` adds the
closed four-door body, sculpted door skins, frames, gaskets, separate glass,
interior door cards, handles/hinges and curved sectional hardtop. The GLB embeds
all referenced texture data; playing does not require the source download or
Blender. Godot extracts the embedded images beside the GLB at import time.

The source body includes styling details from an open 392-style Wrangler, while
the closed body and running gear are adapted for this game's Rubicon 35 vehicle.
The resulting vehicle is a JL-inspired game adaptation, not a year/trim-exact
factory model. Physics and visible wheels share a 3.008 m wheelbase and a
0.4445 m running tire radius.

## Underbody references

Reference photos were inspected for spatial layout and component shapes; they
are not packaged as game textures.

- [Ewagen JL 2.0T Rubicon photo set](https://www.ewagen.es/detail.php?id_car=1424)
- [Underbody overview: tank cradle, exhaust, gearbox and rear axle](https://www.ewagen.es/img/files/84412.jpg)
- [Rear axle, red dampers and transverse muffler](https://www.ewagen.es/img/files/84417.jpg)
- [Axle bracket and damper lower mount](https://www.ewagen.es/img/files/84410.jpg)
- [Additional JL underside view](https://www.ewagen.es/img/files/78952.jpg)
- [Stellantis: body-on-frame construction and five-link suspension](https://www.media.stellantis.com/uk-en/jeep/press/jeep-introduces-new-2024-wrangler-to-the-uk)
- [Jeep exterior gallery](https://www.jeep.com/am/en/wrangler/gallery.html)

`cars/RubiconChassis.gd` implements the visible frame and running gear separately
from the GLB. Upper/lower links, Panhard bars, axles, propshafts, springs, dampers,
steering links and brake hoses follow the simulated wheel positions. The existing
raycast suspension solver remains in use; visual link motion is an approximation
rather than a constrained, multi-body mechanical solver.

## Rebuilding

```sh
blender -b -t 4 --python tools/import_rubicon.py -- --source /path/to/package
./run.sh --headless --editor --import --quit
./run.sh --headless --script tests/RubiconAssetChecks.gd
./run.sh --headless --script tests/ChassisChecks.gd
```

The historical `tools/build_rubicon.py` generates the old prototype and should
not be used to rebuild this version.
