# How top match-3 games pace new mechanics and difficulty

Research brief, 2026-10-17. Numbers come from the fan wikis (parsed through the MediaWiki API),
Gamigion, mobilegamer.biz, TechTarget, GDC and papers. Level numbers reflect each game's
current order (they re-order over time): treat them as ±a few. [uncertain] marks weak claims.

## 1. When a new element appears

- **Royal Match** (royalmatch.fandom.com, per-element pages): Box 1, Grass 4, Cupboard 11,
  Mailbox 21, Royal Egg 31, Potion 41, Vase 51, Owl 61, Bush 71, Honey 81, Safe 91, Bird 101,
  Color Box 121, Ice 141, Piggy 161, Curtain 181, Oyster 201, Magic Hat 231, Flowerpot 261,
  Stone 301, Dynamite 351, Shelf 401, Bird House 451, Rock 501; then one per 50 levels to
  L1000, one per 100 to ~L2000, then ~one per 200. Every new element lands on an area's first
  level (and on the midpoint of the early 20-level areas).
- **Homescapes** (homescapes.fandom.com/wiki/Elements): 6, 8, 18, 22, 25, 31, 41, 51, 71, 91,
  111, 131, 161, 191, 221, 251, 301, 351, 401, 476, then ~100, later ~150 apart.
- **Gardenscapes**: 5, 9, 11, 18, 26, 31, 41, 50, 51, 61, 71, 95, 101, 190, 200, 221 …
- **Candy Crush Saga** (post-redesign): Frosting 2, Teleporter 10, Marmalade/Bubblegum 11,
  Liquorice Lock 21, Liquorice Swirl 36, Candy Bomb 96, Chocolate 141, … then 300–1000 apart.
  Layer counts also arrive gradually (frosting 1 layer at L2 … 5 layers at L156).

| Level range | Royal Match | Homescapes | Gardenscapes | Candy Crush |
|---|---|---|---|---|
| 1–100 | ~9 | ~9 | ~8 | ~15–20 |
| 100–500 | ~30 | ~37 | ~36 | ~50 |
| 500–1000 | 50 | ~95 | ~55 | ~100+ |
| 1000+ | 100–200 | ~150 | 75–400 | 300–1000 |

Every game front-loads novelty; the gap roughly doubles at ~L100, L300, L1000.

## 2. Chapters

- Candy Crush: episodes of 10 (first two) then 15 levels; early episodes open with a new
  element, later most do not.
- Royal Match areas: 10, 10, then 20 levels (L21–200), 30/30/40 (L201–300), 50 (to L1000), 100
  after. Up to ~L2000 every area opens with one new element (two in early 20-level areas).
- Toon Blast: 50-level episodes every 2 weeks.

## 3. Novelty without new mechanics

- **Archetypes in new costumes:** ~24 of Royal Match's ~85 elements are plain "layered"
  blockers that look and react differently (Box, Egg, Vase, Owl, Bush, Safe, Stone, Rock …).
- King's GDC 2020 kit: 16 core blockers in families.
- **A "first level with…" twist every 2–5 levels** (Homescapes L1–135: multiple boards,
  3/4/5-layer variants, chained power-ups, two gravity directions, new goal types).
- **Combinations** (Candy Crush: marmalade over striped, then over colour bombs …).
- **Meta and live-ops:** Royal Match unlocks boosters at L8, 14, 17, 19; first live-op at L23;
  a bonus level every 10th level.

## 4. Teaching

- The introduction level is always normal and easy; no new element debuts on a hard level
  (Royal Match, Homescapes). Royal Match: "2–3 learning boards", then a hard spike.
- Homescapes: introduced → paired with another goal next level → in a hard level 3–5 levels
  after (Apples 51/52/54, Suds 91/92/95, Ice 131/133/135). *Variants* (more layers) may debut
  on hard levels; new elements never do.

## 5. Flow

| Share of hard levels | Royal Match | Homescapes | Gardenscapes | Candy Crush |
|---|---|---|---|---|
| L1–100 | 13% | 10% | 16% | ~9% |
| later | – | 21–27% | 33% (101–200) | 20–27% |

- First hard: Royal Match L39 (super-hard L59), Homescapes L54 (L60), Gardenscapes L25.
- Royal Match after L40: new element at x1, hard x5, super-hard x9, bonus level x0.
  Attempts per win: normal ~1.2, hard ~1.6, super-hard ≤2.5. Moves shrink 30–38 → 23–27 by L100.
- Sawtooth confirmed in ~1,000 players' data ("rise for 5, drop at 6"):
  https://arxiv.org/abs/1905.06379
- Candy Crush L65: top revenue level and the biggest churn point; "crazy hard levels never
  pay off, at least in the long term"; fixing the 100 least fun levels lifted engagement.
  https://mobilegamer.biz/how-king-defines-a-good-candy-crush-saga-level-and-why-it-constantly-prunes-the-bad-ones/
- "The longer the level is, the less likely it is to be fun"; the longest acceptable level
  shortens as difficulty rises (same source).
- Quit risk falls as players progress (12M players, https://doi.org/10.1038/s41598-020-60742-8):
  early setbacks matter most.

## 6. Content

Royal Match 12,400+ levels (new every 2 weeks), Candy Crush ~15,900, Homescapes 21,000+.
At ~2 min per attempt and 1.2–1.6 attempts per level, 100 levels ≈ 4–6 hours [estimate].
