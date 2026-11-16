# Revision 11: seated guest proportions

The user's screenshot shows flattened, crowded diners at the small restaurant table. Source inspection confirms that the shared seated/resting branch rescales an adult 11×16-pixel crop into 11×10 and a child 11×12 crop into 11×7. Earlier destination-bounds tests did not detect the aspect-ratio defect and even encoded the compressed destination height; passing those tests is not evidence against the supplied screenshot.

## Focused correction

Use original-scale cropped heads/shirts or proper native pixel seated artwork, with natural hips, bent legs, chair placement and age-appropriate adult/child size. Do not vertically compress atlas content. Keep faces distinct, hands/plates reachable and the underlying table material unchanged in all four table orientations. Preserve actual reserved seat routes and model behavior unless a concrete visual-spacing defect requires a coordinated geometry correction.

The first native-scale after image fixed flattening but still placed both diners in front of the table with food above their hats. Root and PM therefore authorized a narrow physical seating correction: prefer reachable opposite west/east table-edge seats, retaining the prior same-edge/aisle fallback for tight layouts. Plate placement follows the actual seating arrangement rather than assuming the table texture's rotated axis. This is part of resolving the screenshot, not an unrelated construction change.

Audit every consumer of the shared resting path: cafe seating, beach lounge, stage, hot-tub companion and kids-pool supervision. Standing/swimming/climbing/dancing proportions and all R9/R10 behavior remain intact. No new feature, economy/save schema change or unrelated redesign.

## Ownership and acceptance

One Sol/xhigh visual/core specialist (`visual_r9`) owns `resort_map.gd`, necessary visual helpers/anchors, the coordinated `_table_seats` preference in `layout_model.gd`, focused tests and the R11 export. No other model/simulation changes are authorized without a demonstrated dependency. Root owns independent proportion/spacing tests, README/launch notes, final preview review and packaging. Astra/high PM owns this contract, task board and acceptance.

Reproduce the current defect in an offscreen zoomed before image. Generate after samples using actual eating phases in all four table orientations, normal standing comparisons and other resting consumers. Tests must verify source/destination scale or native pixel geometry, distinct head/body placement, reasonable reach and stable materials; bounding rectangles alone are insufficient. Export a tested standalone Windows candidate after PM/root preview acceptance. All existing uncommitted R9/R10 work must remain. No computer use, desktop capture, visible windows, native tester resumption, Git push or release.
