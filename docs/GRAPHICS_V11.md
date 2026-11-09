# v0.11 CGA materials and presentation

* **Water**: dark background, three horizontal moving-water wave silhouettes,
  with open space between broad crest clusters. It's intentionally not a solid
  green tile: recognizable on both standard CGA four-color palettes.
* **Ice**: bright hard-edged plate with a diagonal fracture shaped by negative
  space. A filled angular slab contrasts with the sparse waves, rounded forest
  canopies, riveted steel and staggered mortar of bricks.
* All four combinations of CGA palette selection / intensity are retained on
  the `C` key. Texture identity is based on shape, not hue alone.
* `GAME OVER`, `SCORE`, `R - RESTART` are centered as a group over the
  battlefield; AUTO/MAN state uses four compact monochrome HUD glyphs.
* Static tile bitmaps are generated in advance from 16×12 source pixels; there
  is no per-frame procedural texture generation on the 8088.

Visual readability is not certified by tests alone; validate at native 320×200,
not just zoomed screenshots. Keep a previous playable binary to roll back.
