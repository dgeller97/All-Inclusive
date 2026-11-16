# Revision 12: mirrored guest alignment

The user's follow-up screenshot exposed a second rendering defect after R11 corrected seated proportions. A left-facing diner’s upper body was displaced from the chair, arms and feet. The shared actor renderer shifted the texture destination right by its width before passing a negative width to Godot. Godot already mirrors that texture in place, retaining the destination origin, so the shift was wrong: 11 pixels for seated crops and 20 pixels for full actor frames.

Root and PM independently verified the behavior against the exact engine version's [RendererCanvasCull implementation](https://github.com/godotengine/godot/blob/ed1daf0bf/servers/rendering/renderer_canvas_cull.cpp). The correction removes the extra position offset and retains the negative width for horizontal mirroring. It preserves R11 native pixel proportions, opposite-side seat selection, chairs, legs and constrained-layout fallback. No layout, simulation, economy or save schema change is needed.

The CPU preview probes previously subtracted the mirrored frame width, incorrectly masking the production defect. They now flip pixels without changing the origin. Region/head/overlay bounds use the original destination position with absolute dimensions, rather than mathematical `Rect2.abs()` normalization. This distinction is part of the regression contract, not merely a preview adjustment.

Root owns the production fix, tests, generated preview, Windows export, README/launch notes and packaging. PM independently reviews engine semantics, code and the generated before/after and records acceptance. No specialist or native tester is needed for this narrow correction. All R9–R11 work remains; no desktop interaction, capture, visible window, Git push or release is authorized.

See `revision-12-validation.md` for evidence and package identity. `screenshots/diner-facing-fix.png` is a generated reproduction using corrected engine semantics, not a screenshot of a running native game.
