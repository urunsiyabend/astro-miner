# Astro Miner: art direction (visual target v1)

Purpose: one visual rulebook so every generated or hand-made asset (tiles, rock, ore, robot,
colony, UI) looks like it belongs to the same game. Generated images are drafts until they
pass the checks at the end. Built from the current game (`scripts/ui/Pal.gd`,
`BoardView.gd`), which already has a coherent look worth keeping.

Reference captures of the current game: `docs/art/ref-dig.png`, `docs/art/ref-colony.png`.

## Game frame

- **Player fantasy:** a cheerful little mining robot digging on a strange purple planet for a
  growing colony.
- **Core verbs:** move (swap), line up 3, dig down, crack rock, pick up.
- **Engine:** Godot 4.7, GL Compatibility renderer, 2D, Android-first.
- **View:** straight top-down (orthographic, camera looking down), square grid. Not isometric.
- **Native viewport:** 1080×1920 portrait. The board is 7×8 cells of about **136 px**.
- **On-screen size:** a cell is about 2 cm on a phone; everything must read at that size.

## Visual system

| Property | Rule |
|---|---|
| Shape language | Soft and chunky. Rounded corners everywhere; rock is a rounded octagon; ore is a simple geometric primitive (square, circle, triangle). No spikes except crystals. |
| Silhouettes | Each gameplay object must be recognisable from its outline alone at 64 px: ore by shape, rock by its lumpy octagon and stacked slabs, crystal by its diamond, cell by its battery, robot by its visor. |
| Value structure | Dark world, bright actors. Ground and walls stay in the low/mid values of the purple ramp; everything you interact with (ore, crystals, robot, UI accents) is high value and saturated. Depth always reads darker. |
| Lighting | One key light from the **top of the screen** (north). North walls of pits are in shadow, south walls are lit; raised rock casts a short soft shadow to the south. |
| Edge treatment | No black outlines. Shapes are separated by a darker rim of their own hue (as `ORE_DARK` does) plus a small light highlight at the upper left. |
| Materials | Matte dusty soil (fine speckle, no grass), layered rock with chips and cracks, glassy crystals, smooth white robot plastic. Painted, not photographic. |
| Detail density | Low. Textures carry fine noise and a few features per tile, never busy patterns that fight the ore on top. |
| Style | Clean stylised 2D game art, flat colour with soft gradients; think "mobile puzzle game", not pixel art and not realistic. |
| Motion | Snappy and bouncy (back-out easing, squash on landing), short (0.1–0.25 s). |
| **Never** | Text or numbers baked into art, grass, trees, water, sky, humans in tiles, isometric perspective, perspective camera, black outlines, photorealism, busy patterns, glow on terrain. |

### Palette (exact swatches, from `Pal.gd`)

| Role | Swatches |
|---|---|
| Background / UI | `#120d18` bg, `#1f1729` panel, `#2c2139` panel hi, `#3d3050` line |
| Text | `#f3ecff` text, `#a596bd` dim, `#6c5f80` muted |
| Ground by depth (surface → deepest) | `#74546d` `#5a4058` `#443047` `#322337` `#241a29` |
| Exhausted floor | `#2c2732` |
| Rock by layers (rubble, stone, basalt) | `#b3a9c2` `#75698f` `#3e3452` |
| Bedrock / void | `#0b0810` |
| Ferrite (ore 1) | `#ff8a3d`, rim `#9c4517` |
| Cryo (ore 2) | `#4fd8ff`, rim `#1f7896` |
| Lumen (ore 3) | `#ffe14d`, rim `#a08414` |
| Crystal | `#c88bff`, rim `#6d3aa8` |
| Energy cell | `#6dff8a` |
| Blast charge | `#ff4f6d` |
| Robot | `#e9f6ff`, shade `#5b7a99`, visor eyes `#5ad1e6` |
| Accents | good `#7dff9b`, warn `#ffb347`, bad `#ff5c7a`, accent `#5ad1e6`, vein pips `#ffc970` |

Terrain uses only the purple/grey ramp. Saturated colours are reserved for things the player
acts on, so the board stays readable.

## Technical contract

| Item | Rule |
|---|---|
| Terrain tiles | 256×256 source, shown at ~136 px. Square, top-down, **seamless on all four edges** (tested in a 3×3 repeat). Opaque. |
| Depth variants | One base soil texture; pit levels are drawn by code (stepped walls + darker tint) on top of the same texture, so they stay consistent. |
| Rock sprites | 256×256, transparent background, centred, the rock fills ~85 % of the cell. Three variants: rubble (1 layer), stone (2), basalt (3). Shadows are drawn by code, not baked. |
| Ore / pickups / robot | Stay code-drawn for now (they already read well and animate). Optional later: painted versions on 256×256 transparent canvases with the same shapes and colours. |
| Filtering | Linear filtering with mipmaps (painted art, not pixel art). |
| Naming | `assets/tiles/<name>_<variant>.png`, e.g. `soil_a.png`, `rock_stone.png`. |
| Provenance | Every file gets a row in `docs/art/asset-manifest.json` (tool, model, prompt, date, status). |

## Small tileset to make first

| File | What | Notes |
|---|---|---|
| `soil_a.png`, `soil_b.png` | Dusty purple soil, two variants | Seamless; variant B is used at random to break repetition |
| `floor_bare.png` | Exhausted, cracked floor | Seamless, darker, a few dry cracks |
| `bedrock.png` | Dark void rock for walls and the board frame | Seamless, very dark, low contrast |
| `rock_rubble.png` | 1-layer rock | Transparent; light grey-violet, chipped |
| `rock_stone.png` | 2-layer rock | Transparent; mid violet-grey, visible strata |
| `rock_basalt.png` | 3-layer rock | Transparent; dark, dense, angular cracks |

Order: generate `soil_a` first as the **visual target**. Approve it in the game at native size.
Then generate every other tile with `soil_a` attached as a reference image, so the family
keeps the same palette, light and texture density.

## Prompt template (for Layer)

```text
ROLE: production game tile for a top-down mobile puzzle game
SUBJECT: <e.g. dusty alien soil ground>
VIEW: straight top-down orthographic, camera looking straight down, no perspective
ART DIRECTION: clean stylised 2D mobile game art, soft painted gradients, matte surface,
  fine speckle, purple-violet palette (#74546d base, #5a4058 shade, #8a6a83 highlight),
  light from the top edge, low detail density
GAME-SCALE READ: must read as calm background under bright gems at 136 px
TECHNICAL: square 1:1, seamless tileable on all edges, fully filled, no border
EXCLUDE: text, letters, numbers, grass, plants, water, sky, objects, characters,
  isometric view, black outlines, photorealism, frame, vignette
```

For rock sprites, the same blocks, but `SUBJECT: a single chunky rounded-octagon rock seen from
above, <n> stacked layers`, `TECHNICAL: centred on a plain solid background for removal`, then
background removal.

## Acceptance checks

1. 3×3 repeat shows no seams or obvious repeating marks (`build_preview_sheet.py`).
2. Size, alpha and colour count pass `asset_report.py`.
3. In the game at native size, ore on top of the soil reads instantly, and the depth ramp
   still reads (surface lighter, pits darker).
4. Side by side with the current screens, the new art keeps the palette and light direction.
