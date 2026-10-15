# Astro Miner: art direction (visual target v2, "floating island")

One visual rulebook so every generated or hand-made asset (tiles, rock, ore, robot, colony,
UI) looks like it belongs to the same game. Generated images are drafts until they pass the
checks at the end.

v1 kept the flat code-drawn look with a seamless soil texture. That was rejected: the target is
the chunky "floating island" board of modern casual puzzle games (Sliding Seas, Dream Games,
Spyke), where every cell is a little block and the board floats over the background.

## Visual target

- **Style target:** `docs/art/style-target-c2.png` (option C2 of four style tests: cartoon
  outline, glossy 3D, hand-painted, pastel vector). C2, hand-painted, was chosen.
- **Board camera:** `docs/art/topdown-blockout.png`. This is the geometry every tile follows.
- **In game:** the first four tiles are in `assets/tiles/` and drawn by `BoardView._draw_tile`.
- Old flat look, for comparison: `docs/art/ref-dig.png`, `docs/art/ref-colony.png`.

## Game frame

- **Player fantasy:** a cheerful little mining robot digging up a strange purple planet, one
  floating chunk of ground at a time, for a growing colony.
- **Engine:** Godot 4.7, GL Compatibility renderer, 2D, Android-first.
- **Native viewport:** 1080×1920 portrait. The board is 7×8 cells of about **136 px**.
- **View:** straight **top-down**. Each tile shows its square top face plus a thin band of its
  front (south) face, about 20 % of the top's height. No side faces, **never isometric**.
  The style target is isometric; only its look is used, never its camera.

## Visual system

| Property | Rule |
|---|---|
| Shape language | Chunky, toy-like blocks. Square tops with softly rounded corners; boulders are lumpy and rounded, crystals are the only sharp shapes. |
| Board | One block per playable cell, tiny gaps between blocks. Bedrock cells are empty, so the board outline is irregular and reads as a floating island. The front band shows only where the cell below is empty (island edge). |
| Brushwork | Hand-painted: visible soft brush strokes, painterly texture, low detail. Never photographic, never pixel art. |
| Edges | Thin warm-brown outline around every block and object. |
| Light | Soft warm key light from the top of the screen; tops are lighter than front bands. |
| Value structure | Ground stays mid-value (lavender tops, warm brown earth). Things you interact with (ore, crystals, energy cells, robot) are brighter and more saturated than any tile. |
| Depth (dug cells) | A dug cell is the same block with a square pit cut into its top; deeper means darker (and later, a separate tile per depth). |
| Materials | Lavender dusty soil with a few pebbles; warm brown layered earth with strata; grey boulders with glowing violet crystal veins. |
| Background | Deep indigo space, soft stars, faint planets: dark and calm behind the island. |
| **Never** | Isometric or 3/4 camera, side faces, text or numbers in art, grass or trees, photorealism, busy texture that competes with the ore. |

### Palette

Tiles are painted, so these are target colours, not exact pixels.

| Role | Colours |
|---|---|
| Soil top | lavender `#b59ad6` mid, `#9c7fc2` shade, `#d2bce8` highlight |
| Earth band and pit walls | warm brown `#a8724e`, `#7a4f37` shade |
| Outline | `#5a3a2c` |
| Rock | grey `#a9a9b5`, dark `#6c6c7a`, crystal veins `#a35ad9` |
| Background | indigo `#151632` to `#24204a` |
| Gameplay colours (unchanged, from `Pal.gd`) | Ferrite `#ff8a3d`, Cryo `#4fd8ff`, Lumen `#ffe14d`, crystal `#c88bff`, cell `#6dff8a`, charge `#ff4f6d`, robot `#e9f6ff` |

Ore keeps its colour and shape code (Ferrite = orange square, Cryo = cyan circle, Lumen =
yellow triangle). The painted versions must stay readable by shape alone.

## Technical contract

| Item | Rule |
|---|---|
| Tile sprite | 256 px wide, 307 px tall (square top 256 + front band ~51), transparent, no shadow baked in. |
| Placement | Drawn one cell wide from the cell's top-left; rows draw top to bottom so a row covers the front band of the row above. |
| Pickups and robot | 256×256, transparent, centred, fits inside ~80 % of the cell. |
| Filtering | Linear with mipmaps (painted art). |
| Naming | `assets/tiles/<name>.png`, see the manifest. |
| Provenance | Every file has a row in `docs/art/asset-manifest.json`. |

## Production pipeline (what worked)

1. **Geometry from a blockout, style from a reference.** Prompting for "top-down" alone gave
   isometric tiles, because the model copies the style reference's camera. What works:
   - Draw a flat blockout of the sheet (`topdown-blockout.png`: 2×2 tiles on pure green,
     square tops plus a thin front band).
   - Pass it as `init_image` (weight 0.8) and the style target as `reference_image`.
   - Say in the prompt which image sets the camera and which sets the style.
2. **One sheet per family.** Generate related pieces on one 1024² sheet (3×3 = 9 pieces) so they
   share light, palette and brushwork. Model: `muse-image`, 0.2 CU per image (see below).
3. **Key locally.** The background is pure `#00FF00`. `docs/art/tools/key.py` keys it out with
   despill and crops each quarter. Then resize to 256 wide.
4. **Check in game** at native size, then record the asset in the manifest.

Prompt skeleton:

```text
Image 1 is a flat blockout of four game tiles seen from straight above; Image 2 is the art
style reference. Paint the four tiles of Image 1 in the hand-painted stylised style of
Image 2 (...materials...). Keep Image 1's camera and geometry exactly: viewed from straight
above, each tile's top face is a square with softly rounded corners, and only a thin band of
the brown earth front face shows beneath it; no side faces, no isometric angle.
Top left: ... Top right: ... Bottom left: ... Bottom right: ...
Keep the flat solid pure green background, no shadows on it, no text.
```

## From art to game (alignment)

`python3 tools/art/build_assets.py` turns the generated sheets in `docs/art/sources/` into the
game's art and measures everything the code needs, so nothing is placed by eye:

| Output | What it fixes |
|---|---|
| `assets/ui/*.png` + `scripts/ui/UiMetrics.gd` | Per UI piece: **slice** = 9-slice margins (corners, border, top highlight and bottom lip never stretch); **face** = inset of the visible face. `Art.style()` builds a `StyleBoxTexture` whose content area is the face, so button text and panel content centre on what the eye sees, not on the outline or the darker lip. |
| `button_base`, `bar_fill_base` | Grey copies of the button and bar fill, tinted at runtime, so every button colour shares one shape and one set of margins. |
| `assets/ore/*.png` | One 256 px canvas per gem, every gem fitted to the same outer box (80% of the canvas) and centred on its outline box (the alpha centroid lifted the triangle). The crystal is the sapphire recoloured to crystal violet. |
| `assets/rocks/<form>_<state>.png` | 3 forms (boulder, stone, basalt = 1, 2, 3 starting layers) x 3 break states, one 320 px canvas, centred on the rock body (not on flying chips). `Art.rock(layers, left)` picks the sprite. |
| `assets/tiles/*.png` | Square top + layered earth band. Rows are drawn `pitch` apart (cell + `Art.BAND_VISIBLE`), so each block shows its thickness; `BoardView.cell_origin()` is the only place a cell's position is computed. |
| `assets/bg/space.jpg` | Background (painted navy night sky, calm empty middle), cropped to 1080×1920 and dimmed slightly; kept sharp. |
| `docs/art/ui-slices.png` | Review sheet: slice lines (magenta) and face boxes (cyan) on every piece. |

Rebuild after replacing a source sheet. The code reads the new numbers and needs no change.

## Keeping generation cheap

Measured on Layer, 2026-10-14. The same 3×3 blockout and references were run on both models.

| Model | Price | Result |
|---|---|---|
| `muse-image` | 0.2 CU per image | Keeps the blockout layout; style as good as gemini, hanging pieces better |
| `gemini-3.1-flash-image` | 2 CU per image | Good, but 10× the price |

Rules:
1. **Draft and produce with `muse-image`.** Use gemini only if muse fails at a specific task.
2. **Pack 9 pieces per image.** Use a 3×3 blockout; the 2×2 sheets gave only 4 pieces.
   `docs/art/tools/key.py` cuts a sheet.
3. **Batch 2 while exploring, then batch 1.** Muse has no reliable seed, so pick from 2 and
   then iterate on the winner with an edit instead of regenerating the family.
4. **Let the code multiply the art.**
   - Depth is the pit tile drawn darker per layer.
   - Variety comes from 3 soil variants placed in a scattered pattern.
   - The island underside comes from 3 hanging pieces, drawn under every cell whose cell
     below is empty.
   - Flips and small tints add more variants for free.
5. **Never regenerate a whole family for one bad piece.** Re-key it from the other batch image,
   or do an edit run on that one quarter.
6. **Use `estimate_forge_price` before every new kind of call.** Anything over 20 CU needs
   approval.

Sources for these practices:
- [SpriteCook: whole autotile set on one 4×4 sheet](https://www.spritecook.ai/ai-tileset-generator)
- [Sorceress: generate, then align and pack](https://sorceress.games/blog/ai-tileset-generator-game-ready-tilesets-from-a-prompt)
- [Dual-grid tiling: 15 tiles instead of 47](https://github.com/pablogila/TileMapDual)
- [Several items per generation cuts cost](https://hackernoon.com/how-i-cut-ai-video-generation-costs-by-8x)

## Acceptance checks

1. Camera: top face square, front band only, no side faces.
2. Alpha is clean after keying, with no green fringe (check over a dark background).
3. In game at native size: ore reads instantly on top of the tiles; dug, rock and plain cells
   are distinguishable at a glance; the island edge reads.
4. The tile matches the other tiles of its family (light, palette, outline weight).
