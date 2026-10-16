# Legal guardrails for a commercial release

This is engineering guidance, not legal advice. Talk to a games lawyer before
the Steam store page goes live.

## What can be reused from an existing game
Game **mechanics and rules** are generally not protected by copyright: a
speed-based turn meter, element triangles, six-slot gear with substats, pity
counters, cooldowns. Implementing those ideas in your own code is fine.

## What must be original (never copy)
- Character names, designs, portraits, sprites, animations, voice lines
- Skill names, skill descriptions, item names, set names, location names
- Story, dialogue, lore, world names
- Music, sound effects
- UI layouts and visual style that are distinctive enough to be "trade dress"
- Logos, fonts bundled with another game, the game's name or anything
  confusingly similar to it
- Data files ripped from another game (stat tables, skill tables)

Rule of thumb: if you could win a lawsuit only by arguing "but it is a
different art style", it is too close. Clean-room design: write the rules you
want from memory in `docs/DESIGN.md`, then implement from that document, not
from the other game's wiki.

## Calibration data
Aggregate numbers from a player's own account export (stat magnitudes, roll
ranges) are used only to sanity-check our tuning. Nothing is imported
verbatim; see `docs/CALIBRATION.md`.

## Asset sourcing
- Code: this repository (MIT-style licensing of your own code is your choice).
- Art/music: commission with written transfer of rights, or use assets whose
  licence explicitly allows commercial use (CC0, CC-BY with attribution,
  paid asset packs with commercial licence). Keep a `CREDITS.md`.
- Fonts: check the licence; many free fonts forbid redistribution in games.
- Do not use AI-generated art of recognisable characters from other games.

## Monetisation on Steam
- Steam allows randomised item purchases but requires odds disclosure; keep
  the in-game rate panel accurate and version it.
- Several countries restrict or ban paid loot boxes (e.g. Belgium). Plan either
  region gating or a cosmetic-only / premium-purchase model.
- Age ratings (ESRB/PEGI/IARC) ask about randomised paid items; answer
  truthfully.
- If real-money purchases exist, the server must be the authority on
  inventory. An offline game can be edited by the player; that is acceptable
  only if nothing purchasable affects other players.

## Trademarks
Search the USPTO/EUIPO before committing to a final title. "Covenant of
Stars" is a placeholder and has not been checked.
