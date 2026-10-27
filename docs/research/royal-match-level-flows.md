# Royal Match levels, frame by frame: how a level flows

2026-10-23. Why: our levels pass the bot but don't play like Royal Match. This time we looked at
the real boards: AppTipper's walkthrough videos (one skilled player each), 8 frames per level
from the first move to the win. Goals and moves are AppTipper's.

## The six levels

| L | Goals / moves | Board | How it plays out (frames) |
|---|---|---|---|
| 13 | 40 cupboard / 27 | full 9x9; four 2x2 cupboards in a 2x2 grid, open ground all round | doors open on the first hits (each cupboard holds 10 rings); the open ground makes power-ups; a Light Ball combo empties two cupboards at once; won with 8 moves left |
| 18 | 15 box, 40 cupboard, 16 grass / 24 | a **spine**: a column of 4 cupboards (2, a wooden shelf, 2) down the middle; a column of boxes on each side of it; **grass under the cupboards** | boxes go first (by move 18); then the cupboards, top to bottom; the grass appears where a cupboard leaves and is the last goal (the hardest spot, the middle column); won with 9 left |
| 21 | 50 mail / 28 | full rectangle; mailboxes in a **U-frame** (left and right columns, bottom row) | every match next to the frame posts mail; the middle is the workshop; power-ups fired at the walls; won with 16 left |
| 23 | 22 box, 45 mail / 19 | an **L**: a narrow top-right tower and a wide bottom-left room; mailboxes down the left and along the bottom; the room is **packed with boxes** that shield the mailboxes | the boxes are cleared first (by move 13, from the tower side), which opens the room; then the mailboxes; won with 6 left |
| 28 | 120 cupboard, 30 box / 27 | cupboards stacked in **twin pillars** (both side columns) and a row along the bottom: a U of 2x2s; the middle 5 columns all boxes; a Light Ball waiting in the middle | the boxes go in 2 moves (the Light Ball); then the open middle feeds power-ups into the U; an end of chained rockets; won with 14 left |
| 38 | 36 cupboard, 21 egg, 23 grass / 23 | **two rooms with a gap**: the top room (eggs packed in 3 rows, a row of 4 cupboards as its floor: a **wall**) and a bottom room of grass that **starts with no gems at all** | eggs and the cupboard wall first; once the wall breaks, gems pour through the gap into the empty bottom room, which fills and becomes the grass field; won with 9 left |

## What makes them Royal Match

1. **Few, big goal objects.** A cupboard is a 2x2 that takes 10 hits; 4 of them are a level (40).
   The counts are big, but the board shows a handful of things to break. Ours are 30 one-hit
   rocks: the same count read as clutter.
2. **Shield, then goal.** A cheap obstacle (boxes) stands in front of or around the real goal
   (cupboards, mailboxes) and is gone in the first third of the moves (L18, L23, L28). The level
   has two acts.
3. **The last goal in the hardest spot.** Grass under the cupboards (L18) only appears late, in
   the middle column: the end is tense there.
4. **Shapes that read at once:** a 2x2 grid (13), a spine (18), a U-frame (21, 28), an L (23),
   two rooms (38). The goals hug the edges or form one line; the middle is open for power-ups.
5. **The board grows.** L38's bottom room starts empty: the wall's floor breaks and the gems pour
   down through the gap. L23's room is all boxes: it opens as they break.
6. **Power-ups decide it.** Every level is won by combos fired from the open middle at the goals;
   a skilled player finishes with 6–16 moves left.
7. **5 colours** on most boards (red, blue, green, yellow, pink), 4 early.

## What it means for us

- A big multi-hit 2x2 is missing: Royal Match's Cupboard (its third element, L11). Our
  generator (2x2, 6 charges, `Obstacles.KINDS`) is that piece; as a "break it" goal (a crate of
  ore? a boulder?) it would give levels few big things to aim at.
- Split boards now work (bedrock gaps, 2026-10-23). A room that starts **empty** (no gems)
  under a wall needs a cell code for "open ground, nothing in it".
- Design in two acts: a shield of thin rock around a thick goal, webs under rock in the hardest
  spot for the end.
