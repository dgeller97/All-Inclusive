# Revision 8: consistent facility construction controls

The user asked for volleyball courts, beach bars, stages and other facilities to be buyable and removable like the existing assets. Their model costs/removal support already existed, but the catalog was hidden under Landscape and Select/Bulldoze ignored outdoor objects in the default Buildings category.

## Accepted changes

- Add a top-level **Facilities** category (`facilities`) beside Buildings, Furniture and Landscape. It exposes the four existing amenity types directly. Remove the nested Amenities tab from the visible Landscape groups.
- Show Regular prices or Developer **Free** directly on the facility catalog tiles, not only in hover tooltips. Keep the compact pixel icons and readable layout.
- Make Select and Bulldoze work across furnishings, buildings and outdoor props regardless of the active catalog. Hit priority is furnishing, then building, then outdoor prop; a building's footprint protects against an overlapping palm canopy selecting or removing the wrong object.
- Show/enable Move whenever an outdoor prop is selected in any category, with rotation available during Move. Building settings similarly depend on the selected object rather than the active catalog.
- Preserve the existing staged design workflow. Active guests keep the live resort until Apply Tomorrow; costs/refunds are committed through the existing transaction model. Starter objects remain removable with zero paid-cost refund, purchased objects retain their existing half-paid-cost refund, and Developer purchases remain free with no resale windfall.

No new facility types, economy changes, save schemas or starter-layout changes. The model and simulation remain unchanged. No computer use, desktop capture, visible game/editor windows or tester resumption; headless verification only.

## Reproduced defect and ownership

Before edits, the integrator clicked the actual starter footprints in the default Buildings category: lounge `(496,124)`, court `(388,112)`, bar `(440,272)` and stage `(352,276)`. All four remained unselected and unremoved. Root's independent consistency test initially ran 76 checks with 39 failures before early exits.

The Sol/xhigh UI/core integrator owns `design_ui.gd`, `resort_design.gd`, affected scene tests and export. Root owns the independent `tests/construction_consistency_test.gd`, README/launch notes and packaging. The Astra/high PM owns scope, documentation and acceptance. Only one specialist slot is needed. No GitHub release is part of this fix; root owns any Git operations.
