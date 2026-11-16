# Revision 17: seasonal floating sargassum and swim buoys

The user wants to see sargassum arrive from deep ocean as its season begins, retain floating patches across the ocean during the season, and mark the actual swimming area with buoys. Root owns Ocean/Map production and the visual preview harness. One Sol/xhigh systems reviewer owns independent `tests/ocean_season_test.gd`; PM performs read-only geometry/contract review and maintains records.

## Seasonal visual contract

Use the existing compressed calendar's March–October sargassum pressure. Deterministic batches start offshore and travel shoreward over roughly 70–110 simulation seconds, repeating throughout the season with pressure-dependent intensity. Stop new births in November and let existing arrivals finish within their remaining travel time. Derive appearance from persisted simulation time rather than wall clock or random draws, so pausing, seeking a fixed time and loading preserve the field.

Floating patches are clipped to actual ocean pixels throughout the enlarged map. The existing saved shore-buildup amount, beach cleaning cost and guest satisfaction mechanism remain separate. Cleaning the beach removes deposited shore material; it does not erase offshore incoming patches. The visible drift supports the seasonal explanation without claiming that each displayed patch is a mass-conserving simulation deposit.

Public inspection API: `floating_sargassum(time = NAN)` returns patch records with `id`, `point`, `progress`, `opacity` and `variant`. Root's visual harness inspects actual patch drawing; independent tests verify lifecycle, intensity, determinism and geometry.

## Truthful swimming boundary

Use `set_swim_access(access)` from the current layout's actual `ocean_access()` and expose `swim_buoy_points()` as a world-coordinate U-shaped outline. The coastline forms the fourth side. Place all rope/buoy anchors in water and derive the perimeter from real guest targets, rather than drawing an unrelated decorative rectangle.

For lanes 0–3, adult targets are `access.water + (3*lane, [0,-12,12,20][lane])`; child targets add `(-7,8)`. Each target uses the same coast-aware offshore clamp as the production swimmer pose. Include all eight clamped targets, visible sprite/bob margin and wet portions of the shore-to-target wading segments. Relocated access changes the marked area; no usable ocean access means no advertised swimming zone.

Buoys remain year-round and indicate location, not immunity from red-flag risk. Existing swimming policies and flag consequences remain authoritative. Coast geometry remains fixed; no new editable-water, cleanup economy or navigation feature is introduced.

## Acceptance

Require deep-water seasonal arrival, inward progression, repeated broad ocean distribution, summer/low-season differences, seasonal stop/drain, fixed-time/save/pause reproducibility and independent beach cleanup. Validate actual swimmer containment, wet boundary points, moved/removed access and unchanged risk behavior. Inspect generated seasonal/buoy artifacts and run headless regressions/standalone Windows checks. Distinguish generated command evidence from native pixel output.

No desktop use, native capture, visible game/editor launch, process termination or Git publication. Preserve older running builds and all prior local changes; deliver a versioned Windows R17 package.
