# SDL requires Nampower, SuperWoW, ClassicAPI and UnitXP_SP3

SDL targets only the author's Turtle WoW setup, which loads the Nampower (brues-code fork), SuperWoW, ClassicAPI and UnitXP_SP3 client DLLs through VanillaFixes. We treat all four as hard requirements rather than optional, so rotations can rely on spell-ID cooldowns, real cast/channel info, aura lookup by spell name/ID, spell queueing and a reliable "behind the target" check (UnitXP_SP3, added for Cat's Shred/Claw choice) instead of the legacy addon's texture-matching and combat-log-parsing workarounds (`BuffQuery`, `GetTextureID`, last-cast timestamps). The cost is that SDL will not run on a bare 1.12 client; we accept that.

## Consequences

- On load, SDL checks that each DLL's API is present and refuses to register its rotations (with one clear chat message) if any is missing, instead of half-working.
- Addon-level integrations (Cursive, TWThreat, pfUI) remain optional and guarded.
