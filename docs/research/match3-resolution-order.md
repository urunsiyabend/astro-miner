# In what order does a match-3 move resolve?

2026-10-26. Why: the user asked in what order matching, power-up creation and power-up use run
in match-3 games. H = written source or code read, M = inferred.

## The usual pipeline

1. **Swap.** Power-up + power-up: a combo, instead of matching (H). Power-up + gem: in Royal
   Match and Homescapes any power-up goes off (a tap does too); in Candy Crush only the colour
   bomb, the others need a colour match (H). Else match the two swapped cells; no match, swap back.
2. **Detect** groups (after a swap only around the swapped cells; cascades: see 7).
3. **Classify** each group by shape and reserve its cells (Gem Hunter: a reserved gem can't fall).
4. **Clear** on a short timer (Gem Hunter 0.3 s, MY.GAMES a tick count); obstacles under and
   beside the match take damage; goals count when the piece is really deleted (H).
5. **Create** the power-up in place of one matched piece: it is not cleared by its own match (H).
6. **Power-up effects**; one an effect reaches goes off too, in the open engines at once, in the
   same step (H). Gem Hunter freezes gravity while a rocket flies.
7. **Gravity and refill**, diagonal slides included. Then cascades: Candy Crush Saga (and
   emthree) settle the whole board first, then match; the sequels, Royal Match and Homescapes
   match pieces while others still fall ("concurrent matching"), Gem Hunter checks a gem when
   its landing bounce ends (H). Delayed effects here: the wrapped candy explodes, "waits until
   all candies are fully dropped and then explodes a second time" (H).
8. **Repeat** until nothing moves; then goals, then the end bonus (Candy Crush's Sugar Crush:
   specials on the board go off, leftover moves become striped candies; Royal Match: leftover
   moves become power-ups that fire for coins, M).

MY.GAMES' deterministic engine runs one fixed order every 20 Hz tick: cell objects, matches,
replaces, spawner, gravity, goals, turns, shuffle, combo, field zone (H).

## Shape priority and where the power-up appears

- 5 in a line beats everything (Candy Crush: even when the same group also makes an L);
  an L/T beats a 4-line even when an arm has 4; then 4 in a line; then a 2x2 square (H).
  Royal Match: rocket (4), propeller (2x2), TNT (L/T of 5), light ball (5) (H).
- After a swap: on the swapped piece's cell (H). After a cascade: Candy Crush "any one of the
  matched candies", Gem Hunter the piece whose landing set off the check (H).
- A rocket's direction: Candy Crush follows the swipe; Royal Match perpendicular to the line;
  Toon Blast random (H).

## Us (Board.try_path, Board._resolve, Powers)

| | Genre | Us |
|---|---|---|
| Swap | a swap | a drawn path; no matching on the way |
| Power-up moved by the move | goes off when swapped | the path's own lines match first and leave their power-ups (`Board._match_pass`), then the dragged one goes off and leaves the new ones be (`Board.fresh`) |
| Two power-ups | combo | a path dragging 2+ merges them (`Powers.combo`) |
| Shape priority | 5 > L/T > 4 > 2x2 | the same (`Powers.by_shape`) |
| Where | the swapped piece; any cell in a cascade | the last swapped gem (pivot); the middle of the group in a cascade |
| Chains | at once, same step | a queue, in waves of 3 with gravity between (`Powers.WAVE`), like the wrapped candy |
| Cascades | settle first (CCS) or while falling (RM) | settle first: gravity, then every group on the board |
| End of level | leftover moves turn into power-ups | Coin per move left (`Economy`), no show |

Open questions:
- Fixed 2026-10-26: power-ups dragged by a path went off before the path's matches, so the beam
  took the very gems the path lined up and the 4-line's power-up never appeared (the user).
- An end-of-level show (leftover moves become Pulsars that go off) is missing.

## Sources

- candycrush.fandom.com/wiki/Wrapped_Candy, /Sugar_Crush, /Striped_Candy, /Special_Candy,
  /Colour_Bomb_(special_candy), /Differences_between_Flash_and_HTML5_versions
- 80.lv/articles/divide-and-conquer-deterministic-and-scripted-match3-engine/
- github.com/legendlau/Gem-Hunter-Match (mirror of Unity's sample: Board.cs, BonusGem.cs, LineRocket.cs)
- github.com/britzl/emthree
- deconstructoroffun.com/blog/2021/3/21/royal-match-the-new-king-from-turkey
- royalmatch.fandom.com/wiki/Rocket, /TNT, /Propeller, /Light_Ball, /Power-up_Combinations
- homescapes.fandom.com/wiki/Power-ups; toonblast.fandom.com/wiki/Rocket, /Bomb, /Disco_Ball
- esports.net/news/mobile-games/royal-match-tips-and-tricks/
