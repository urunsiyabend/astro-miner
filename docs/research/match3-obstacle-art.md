# How match-3 games draw their obstacles (and what we got wrong)

2026-10-23. Why: our rock "looks disabled" and the web "looks detached from the game"; four
attempts in a row (a merged stone wall, a silk carpet, four repainted boards) missed. We looked
at Royal Match, Homescapes and Toon Blast frames and at what the studios say.

## What the big games do

1. **The board is quiet.** Royal Match: flat pale lilac-blue; Homescapes: translucent pale
   grey-blue cells; Toon Blast: a calm blue. Low saturation, almost no texture: everything on it
   pops. Contrast peaks are kept for the pieces (squint test: blur the screen, the play area and
   the pieces still read).
2. **Obstacles are props, not terrain.** Boxes, cupboards, mailboxes, cookies, balloons. Playrix:
   every element is a real thing from the game's world ("an item that could realistically be
   found in one of Austin's closets"); a breakable reads as something to open, a reward.
   Rock and soil read as level geometry that can't be broken.
3. **Obstacles are bright and simple.** Homescapes' cardboard box is pale beige with one strip
   of tape; little inner texture, chunky rounded shape, fills ~90% of the cell, drawn in the same
   glossy toy-like 3D as the gems (lit top face, darker front, soft contact shadow). Grey or dark
   means "inactive" in UI language and is not used for things to hit.
4. **A blocker takes a hue the gems don't use** (Royal Match's wood-orange box against red, blue,
   green, yellow, pink gems).
5. **Layers change shape, not just shade.** Royal Match: crown box → studded box; Homescapes
   Cat Treat: nested packets, smaller each hit; Candy Crush frosting changes per layer.
6. **Floor layers belong to the board.** Grass / carpet / jelly: lighter and more saturated than
   the empty cell, one continuous sheet with a rounded rim, flat under the pieces.

Sources: Game World Observer (Playrix on elements, 2019), Deconstructor of Fun (Royal Match),
PocketGamer.biz (the art of Candy Crush), match3place deconstruction guide, Sunstrike Studios
(backgrounds, art styles), Playrix help center (Homescapes elements).

## Our diagnosis

- **The soil board** is dark, warm and textured: the same family as the orange gem, and mud
  under everything. Whatever the obstacles look like, they sit in it.
- **The rock** is grey-purple painted terrain in the board's own value range: it reads as an
  empty, disabled cell.
- **The web** is thin line art in a different technique from the gems: a pasted overlay.

## Direction (to try as one concept board first)

- A light, cool, quiet floor: pale lilac-blue crystal panels or base deck plates.
- Rock as a mining prop: an ore crate with metal straps (or a geode with light leaking out),
  warm and bright, in a hue the gems don't use; the tough version changes shape (steel bands).
- Web as a thick, opaque, glossy white-silver sheet with mass and a rim, under the gems.
