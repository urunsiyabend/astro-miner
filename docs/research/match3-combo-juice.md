# How top match-3 games make cascades and combos feel juicy

Research brief, 2026-10-17. Fan wikis read through the MediaWiki API. Two sets of numbers are our
own measurements, not published: the pitch of Candy Crush's 12 cascade sounds (FFT of the wiki's
files, uploaded 2015) and Royal Match combo timings (frame-stepping the wiki's 10 fps GIFs, ±100
ms). No King or Dream Games talk gives exact timings; *(est.)* marks estimates.

## 1. Cascade escalation

- **Callouts (Candy Crush, per move;
  [Cascades](https://candycrush.fandom.com/wiki/Cascades)):** Sweet! (≥12 cleared or 4
  cascades), Tasty! (≥18 / 6), Delicious! (≥24 / 8), Divine! (>30 / ≥10). Text always shows; after
  the 10th-anniversary audio redesign the low tiers are voiced only ~25–33% of the time
  (anti-fatigue); "Sugar Crush" always.
- **Score** grows with cascade index (40/candy + 40 × index; formerly 120, 240, 360 …).
- **Audio ladder:** 12 separate cascade sounds. Measured: C4 F4 G4 C5 E5 G5 C6 E6 F6 G6 C7, then a
  C-E-G chord, i.e. a C-major chord-tone ladder (~+3.3 semitones/step, ~3 octaves), each a hard
  attack falling ~20 dB in 65–250 ms. Peggle locks its rising notes to the music's key
  ([Audiokinetic](https://blog.audiokinetic.com/en/peggle-blast-peg-hits-and-the-music-system)).
- **No tier-based screen shake or zoom on ordinary cascades** in Royal Match / Candy Crush
  captures: escalation is audio, text and score; shake and flash are kept for specials (obs.).

## 2. Power-up combos (two specials swapped together)

- Candy Crush: striped+striped = row+column; striped+wrapped = 3 rows + 3 columns; wrapped+wrapped
  = 5×5 twice, neighbours pushed back; colour bomb + special = that colour turns into the special
  and all fire; bomb+bomb = board. ([Special Candy](https://candycrush.fandom.com/wiki/Special_Candy))
- Royal Match: rocket+rocket = cross; rocket+TNT = 3 rows + 3 columns; TNT+TNT = radius 4;
  propeller carries the other to the best tile; light ball + X = most common colour becomes X;
  LB+LB = board + one layer of every obstacle.
  ([Combinations](https://royalmatch.fandom.com/wiki/Power-up_Combinations))
- **Staging (Royal Match GIFs):** merge (~100–200 ms) → swell/hold (TNT+TNT ~1.2–1.4 s, LB+LB ~2
  s of anticipation) → collapse to a point for one frame → full-board white flash → radial
  release; goal items stream to the counter **while the board already refills** (nothing waits).
  The bigger the combo, the longer the hold.

## 3. Hit-stop and anticipation

- No match-3 source states a value; action-game studies: 0.1–0.2 s hit-stop, 0.2–0.4 s slow-mo
  ([IEICE](https://ken.ieice.org/ken/paper/20230315OCSt/eng/)); scale with impact and cap it
  (Sakurai). Freeze the board only, never UI or audio.

## 4. Piece feedback

- Match pop (Candy Crush, 20 fps capture): matched candies shrink to nothing in ~300 ms while the
  new special grows past full size (~1.2×) and settles with glints.
- Falling: staggered start up a column, ~constant acceleration, a decaying-spring landing scaled
  by impact speed, 4 landing-sound variants.
- Goal flyers: items fly from where they were made to their counter, which ticks per arrival and
  pops a checkmark when done.

## 5. End-of-level bonus

- Sugar Crush: specials on the board fire in reading order, then leftover moves become striped
  candies that fire one by one (skippable); finishing on the last move = Super Sugar Crush.
- Royal Match: each leftover move throws a random power-up onto the board (unverified fan guide).

## 6. Why it matters

- Royal Match's "quick animations and concurrent matching" (no waiting for the board to settle)
  are credited for its feel ([DoF](https://www.deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey));
  short combo animations raise attempts per session ([Naavik](https://naavik.co/digest/why-dream-games-success-is-a-challenge-to-replicate/)).
- Medium/high juice beats none and extreme (Kao 2020, [arXiv](https://arxiv.org/pdf/2011.09201));
  heavy juice can lower perceived competence (2024). "The more common an action, the simpler the
  juice."

## Checklist for Astro Miner (impact ÷ effort)

1. Cascade pitch ladder on chord tones: 0, 4, 7, 12, 16, 19, 24, 28, 31, 36 semitones; cap at
   ~10–12, a stacked chord at the cap; reset per move.
2. Tiered callouts (space words: Nice! / Stellar! / Cosmic! / Supernova!) at ≥3/5/7/9 cascades
   or ≥12/18/24/30 cleared; pop 0→1.3→1.0 in 250 ms (back-out), hold 600 ms, rise 40 px + fade
   300 ms.
3. Score/count popup at the match centroid in the gem's colour, "×N" from cascade 2.
4. Goal flyers never block the refill: launch at 1.3×, arc 450–600 ms, stagger 30–50 ms; counter
   punches 1.25× per arrival; checkmark pop when a goal is done.
5. Match pop: pre-swell 1.15× + 60% white flash for 60–80 ms, then shrink to 0 in 150–200 ms;
   6–10 shards per gem.
6. Falling: gravity ~9–12 tiles/s² capped ~18 tiles/s; stagger 25–35 ms per piece up a column;
   landing squash (1.12, 0.88) on a damped spring ~150 ms scaled by impact; 3–4 landing sounds.
7. Special created: 0→1.25→1.0 in 200 ms with a glint and its own sound, source gems shrinking
   toward it.
8. Trauma-based shake for specials only (line +0.2, bomb +0.35, combo +0.6, board +1.0; offset
   trauma² × 10 px, decay 1.5/s).
9. Combo staging: slide-merge 150 ms → hold 350–600 ms (±6% pulse, rising charge sound) →
   implode 80 ms → hit-stop 60–90 ms → 2-frame flash → shockwave 300 ms → effect.
10. Hit-stop by tier: single special 0–30 ms, combo 60–90, board clear 120 (cap); board only.
11. Conversions one after another, 50–70 ms apart, each popping to 1.3×, then fire with jitter.
12. Particle density ×(1 + 0.15n) per cascade (cap 2.5×), board-edge glow +0.08 per tier.
13. End-of-dig "Overdrive": specials fire in order, each move left launches a special onto the
    board 120–180 ms apart, coins counted live, tap to skip.
14. Keep the pace: a normal match ≤ 650 ms from swap to settled; allow input during cascades if
    the rules permit.
15. Layered audio: pop ±1 semitone + ladder note + sub-thump for specials; duck music −4 dB on
    combo blasts.
16. Keep the ladder in the music's key.
17. Slow-motion 0.4 for 250–350 ms only on the very biggest events.
18. Juice ceiling: routine matches get only 5 and 6.
19. Debris 600–900 ms on a non-blocking FX layer; nudge neighbours outward 0.15 tiles and spring
    back on big blasts.
20. Reduced shake / flash accessibility toggles.
