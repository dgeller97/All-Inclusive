# Revision 16: screen interface above world labels

The user's screenshot exposes an R15 regression: building plaques appear over the welcome modal. R15 gave the world plaque `Node2D` a positive `z_index`, while the screen controls remained in the same default canvas. Sibling ordering alone does not protect those controls from higher world drawing indices.

Root owns the narrow production correction: keep the world and its internal depth ordering in the default canvas, and place the HUD, design controls, modal overlay and lazily created Animation Viewer in one dedicated `CanvasLayer` at layer 1. Keep that canvas at the identity transform without following world movement. Controls retain their existing ordering within the screen layer. Also correct the welcome explanation/button vertical overlap using actual text layout dimensions.

The [official CanvasLayer contract](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html) specifies that layer ordering takes precedence over child `CanvasItem.z_index`. This creates an explicit world/interface boundary without changing R15's physical depth behavior. The designer's world preview remains in the world; only its screen controls move to the interface layer.

PM independently reviews source and evidence without production edits or specialist delegation. Require separate world/interface canvas identities, every screen surface in the intended layer, welcome text/control separation and viewport containment, modal input/focus preservation, viewer lifecycle and clean standalone Windows smoke. Do not claim framebuffer validation from headless structural checks. No desktop use, native capture, visible launch, process termination or Git publication; preserve running older builds and package R16 separately.
