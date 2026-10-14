# Level plan (master sheet), draft 1

Built from `docs/research/match3-level-design.md`. Every level gets one idea, at most 3
elements (at most 1 new), a planned role in the chapter's sawtooth, an energy budget and a
board shape that differs from its neighbour. Levels are built from this sheet, then tuned by
playing each ~10 times (energy left on wins, goals left on losses).

## Elements

| Code | Element | Property (King's framework terms) |
|---|---|---|
| SW | Robot swap + lines of 3 | the core verb |
| VE | Veins and depth | layered ground: a match digs a layer, new ore rises, the cell runs dry |
| R1 | Rubble (1-layer rock) | stationary, colourless, removable by a match beside it |
| CR | Crystal | hidden under rock, picked up by driving onto it |
| EC | Energy cell | hidden under rock, refills the battery |
| CH | Blast charge | made by a line of 4+, clears 3×3, breaks thick rock |
| R3 | Stone / basalt (2–3 layers) | layered version of R1, introduced after R1 is familiar |
| P / W / L | Power Station / Workshop drill / Lab scanner | building tools, each with its own level |

Shapes: cells outside the play area are bedrock, so boards can be diamonds, rings, rooms,
corridors. Neighbouring levels never share a shape.

## Guidance budget

- **First encounter only:** one Mira line, the screen dimmed except the element, the first
  move highlighted. Never repeated on a retry or later level.
- **Hint arrow:** on request (Hint button) only. In levels 1–5 it also appears after 8 s idle.
- **Colony:** Mira speaks when something new happens (unlock, building built, first time an
  upgrade is affordable). Otherwise she is quiet.
- Mira's action lines that stay up during play ("swipe up…") exist only in levels 1, 5, 11, 15,
  21, 22, i.e. the first encounter of each element. Everywhere else the board teaches.

## Chapter 1: Landing Zone (levels 1–10). New: SW, VE, R1. Ends with the Power Station.

| # | Role | Idea (one sentence) | Elements | Goal | Energy | Shape |
|---|---|---|---|---|---|---|
| 1 | learn | One obvious move lines up Ferrite; the next line needs two steps. | **SW** | 6 Ferrite | 20 | 4×4 square |
| 2 | learn | A chunk has to be dragged two cells to complete each line. | SW | 9 Cryo | 20 | 5×5 plus |
| 3 | learn | The middle column is a deep vein: matching there keeps paying, the edges dry up fast. | SW **VE** | 15 ore | 20 | 5×6 |
| 4 | breather | Big open field full of ore. | SW VE | 12 Lumen | 22 | 7×8 symmetric |
| 5 | learn | A rubble band seals the top half; matches under it crack it open. | VE **R1** | break 4 | 20 | 7×6, band in row 2 |
| 6 | vary | A ring of rubble guards a deep pocket in the centre. | VE R1 | break 6 + 10 Ferrite | 20 | ring |
| 7 | **hard** | Two shallow rooms; open the wall between them before the first room runs dry. | VE R1 | 18 Cryo | 18 | two rooms |
| 8 | breather | Hourglass of deep veins, generous goal. | SW VE | 20 ore | 22 | hourglass |
| 9 | **super-hard, short** | Zig-zag corridor of rubble; every match has to crack forward. | R1 | break 10 | 16 | zig-zag |
| 10 | reward | Mother lode: deep veins everywhere. Unlocks the Power Station. | SW VE | 25 ore | 24 | full board |

## Chapter 2: Glint Fields (11–20). New: CR, EC, P. Ends with the Workshop.

| # | Role | Idea | Elements | Goal | Energy | Shape |
|---|---|---|---|---|---|---|
| 11 | learn | One rubble rock glints: crack it and drive onto the crystal. | R1 **CR** | 1 crystal | 22 | small diamond |
| 12 | learn | Three crystal rocks across the top: plan the route between them. | R1 CR | 3 crystals | 22 | T |
| 13 | **P level** | A long bare tunnel to a crystal: only the bigger battery reaches it (reworked `longhaul`, field no longer cramped). | R1 CR **P** | 1 crystal | 26 | tunnel + field |
| 14 | breather | Crystals near the start, lots of ore. | CR VE | 2 crystals | 24 | wide |
| 15 | learn | Start nearly empty; the rock next to you hides an energy cell. | R1 **EC** | 12 Ferrite | 6 | small |
| 16 | vary | A rock field with crystals and cells: which to open first? | R1 CR EC | 2 crystals | 20 | checkerboard |
| 17 | **hard** | Shallow ground, crystals far apart, cells needed on the way. | VE CR EC | 3 crystals | 18 | long |
| 18 | breather | Deep veins and a free crystal. | VE CR | 1 crystal + 15 ore | 24 | round |
| 19 | **super-hard, short** | Crystal at the bottom of a rubble well; every step down costs. | R1 CR EC | 1 crystal | 14 | well |
| 20 | reward | Crystal garden. Unlocks the Workshop. | CR VE | 4 crystals | 26 | full |

## Chapter 3: Basalt Shelf (21–30). New: W, CH, R3. Ends with the Lab.

| # | Role | Idea | Elements | Goal | Energy | Shape |
|---|---|---|---|---|---|---|
| 21 | **W level** | Crystals in basalt vaults behind doorways: drill in (reworked `vaults`, fewer elements). | **W** CR | 2 crystals | 26 | two vaults |
| 22 | learn | A line of 4 leaves a charge; step on it. | **CH** SW | 2 charges used | 24 | 6×6 |
| 23 | learn | Stone (2 layers): one match isn't enough, a charge is. | **R3** CH | break 4 stone | 24 | stone band |
| 24 | breather | Charges everywhere. | CH VE | 25 ore | 26 | wide |
| 25 | vary | Drill or charge: basalt pockets, enough energy for only some drilling. | W CH R3 | 3 crystals | 20 | pockets |
| 26 | **hard** | Basalt maze, drill sparingly. | W R3 | 2 crystals | 18 | maze |
| 27 | breather | Soft rubble field, lots of cells. | R1 EC | break 12 | 24 | open |
| 28 | vary | Charge chains: one blast sets off the next. | CH R3 | break 8 | 20 | grid of charges |
| 29 | **super-hard, short** | Basalt core with 3 crystals (reworked `core`). | W CH R3 | 3 crystals | 18 | shell |
| 30 | reward | Open seam. Unlocks the Lab (its level opens chapter 4). | VE CH | 30 ore | 26 | full |

## What happens to today's levels

- `first`, `rocks`, `power` (lessons): replaced by 1–3, 5, 11, 15, 22. Their good parts (hand
  placed first moves) stay; the 4-mechanics-at-once `power` dig goes.
- `landing`, `rubble`, `glint`, `shale`, `vein`, `core`: become 4, 6, 14, 17, 24, 29 with new
  shapes and an idea each.
- `longhaul`, `vaults`, `readings`: 13, 21, and chapter 4's first level, reworked to fewer
  elements.

## Open questions

- Does every level keep a fixed layout (same every attempt), or a fixed shape with random ore?
  Industry practice is a fixed shape with random ore, plus fixed boards for tutorials. This
  sheet assumes that.
- Chapter 4 (scanner, Lab upgrades) is left for after chapters 1–3 are playtested.
