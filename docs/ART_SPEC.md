# Art Specification (placeholder stage)

All art must be original or licensed for commercial use. Keep the file names
below so code never changes when real art lands. See `docs/LEGAL_NOTES.md`.

## Per unit
| Asset | Path | Size | Notes |
|---|---|---|---|
| Portrait | `assets/portraits/<id>.svg` or `.png` | 256×256 | Square, face-centred. Placeholder: `tools/gen_portraits.py` |
| Idle sprite | `assets/sprites/<id>/idle.png` | 512×512 | Transparent, feet at y=460, facing right |
| Attack sprite | `assets/sprites/<id>/attack.png` | 512×512 | Same anchor as idle |
| Hit sprite | `assets/sprites/<id>/hit.png` | 512×512 | Optional; falls back to idle tinted red |
| Skill VFX | `assets/vfx/<skill_id>.tscn` | — | Optional scene; falls back to a generic flash |

Enemy units face left in battle; the engine flips sprites horizontally.

## Shared UI
- Element icons: `assets/ui/element_<flame|frost|verdant|radiant|umbral>.svg`, 64×64,
  colour-blind safe (distinct shapes, not only colours).
- Rarity star: `assets/ui/star.svg`.
- Status icons: `assets/ui/status_<effect_id>.svg`, 32×32.

## Style direction (working)
Painterly fantasy with strong silhouettes, readable at 128 px. Five element
palettes are defined in `tools/gen_portraits.py` and should carry into final
art. Avoid any resemblance to specific characters from existing games.
