# Revision 15: animation depth and rotation audit

The user's Animation Viewer screenshot shows climbing-wall guests and rope drawn over the wrong wall face at 180°/270°, sampled at Activity 5.47/12 seconds, frame 164. Audit and correct animation/asset layering across all fourteen activity venues plus dining, buffet collection and the main pool, including four rotations, full occupancy and approach/use/departure. This is a production visual-correctness revision, not another catalog expansion or a viewer-only workaround.

## Confirmed architectural issue

The existing world stack draws complete landscape props and building furniture before all guest sprites. Actor sorting only resolves actor-to-actor order. Consequently an upright wall, cabinet, counter, net, roof or canopy cannot cover a guest standing behind it. Transition/incidental walkers also need correct depth even when they have no activity tag. Effects such as climbing ropes and balls need meaningful contact/ground depth, rather than an unconditional final overlay.

Inspect static art's internal painter order as well. Rotating ground geometry does not automatically make a front-facing climbing wall/backboard/cabinet correct from its rear. Fixing actor foreground masks alone cannot correct a malformed rotated asset.

## Implementation contract

Use reusable semantic geometry and a common actual-world draw ordering/occlusion mechanism. Separate ground/surface layers from solid foreground elements and compare physical ground/contact depths. Do not redraw every entire prop above every actor: guests in front must stay visible, moving guests must cross depth boundaries correctly, and interaction effects must remain attached to the proper surface. The main game and Animation Viewer must use the identical production implementation.

Preserve R12's engine-correct texture mirroring, R11 native seated proportions, R13 editable showcase and R14 controls. No save/economy/catalog changes are required unless a demonstrated geometry dependency is coordinated. Preserve all local uncommitted work and the user's running old executable; use a new versioned output if necessary.

## Audit targets

Audit targets below are acceptance questions, not claims of completed fixes:

| Asset / interaction | Depth and rotation questions |
| --- | --- |
| Climbing wall | Correct visible rock face/holds; raised climber ground anchor; belayer and rope across front/back/side surfaces |
| Waterpark | Raised platforms, supports and overlapping slide segments; rider and splash depth throughout travel |
| Basketball | Upright backboard, hoop/net and airborne ball; players on either side |
| Volleyball | Net/post occlusion, near/far players and ball flight |
| Arcade | Cabinet fronts/sides/backs cover or reveal bodies/hands consistently |
| Beach bar / cafe | Counter/canopy/table/chair occlusion; cups, hands and plates remain on the appropriate visible surface |
| Beach lounge | Umbrella/canopy and lounger occlusion without hiding front-side resting guests |
| Stage / nightclub | Upright equipment/lights/backdrop vs guests, foreground fixtures and layered effects |
| Lap / lagoon / kids pools / hot tub | Basin coping and water surface vs swimming/soaking/supervision poses and gates |
| Core pool | Coping/ladders, loungers/umbrellas, swimmers and dry approach/departure |
| Dining / buffet | Counter/table/chair tops and fronts, actual food/hands, native seated proportions and mirrored bodies |
| Ordinary furniture/scenery and exterior architecture | Incidental walkers pass correctly in front/behind; design preview and exterior concealment remain functional |

## Ownership and acceptance

- Sol/xhigh visual specialist `visual_r9`: sole production owner of map, landscape, facility/amenity renderers and activity poses, necessary depth helpers and orientation art.
- Sol/xhigh systems specialist `systems_r9`: independent semantic audit, tests and findings only; no production edits.
- Root: `building_renderer.gd` and new `furniture_depth.gd` for core furniture/base/foreground layers and visibility, integration review, final export/packaging and launch documentation. Visual confirmed no BuildingRenderer edits before ownership transfer; map integration remains visual-owned.
- Astra/high PM: architecture/ownership coordination, scope, visual review and acceptance records.

Require actual runtime draw-order/depth checks with independently justified front/behind cases, all seventeen clips across four rotations and phase/capacity samples, stable materials, correct effect attachment, incidental walkers and unchanged existing behavior. Review generated exact climbing 5.47-second comparisons plus representative upright facilities and full-capacity transition views. Generated artifacts must use production semantics; they do not substitute for native pixel output under the headless dummy renderer. Do not accept based only on assertion counts.

No desktop use, screen capture, visible game/editor launch, native tester resumption, Git push or release. Supplied screenshots and locally generated files may be inspected.
