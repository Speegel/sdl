# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SDL (Spiegel DPS Library) is a World of Warcraft AddOn for the Turtle WoW 1.12.1 client: one-button combat rotations for Warrior (Fury, Protection), Mage (Arcane, Frost) and Druid (Balance, Cat, Bear). It replaces the legacy `../waaagh` and `../WaaaghDruid` addons, which stay installed as a fallback and reference until each class is ported. Read `GLOSSARY.md` for the vocabulary (Spec, Rotation, Entry, Press, ...) and `docs/adr/` for the decisions behind the design.

There is no build system or test suite; behavior can only be verified in-game. Code is strict Lua 5.0 syntax (no `#`, use `table.getn`; varargs via `arg`; `string.gfind`, not `gmatch`), even though ClassicAPI backports a few 5.1 functions.

## Ground rules

- Requires the Nampower (brues-code fork), SuperWoW and ClassicAPI client mods (ADR-0001). Cursive, TWThreat and pfUI are optional and must be guarded.
- Everything lives under the single global namespace table `SDL`; the only other globals are the SavedVariable and the binding strings `Bindings.xml` needs.
- A rotation is an ordered list of named entries (ADR-0002). One press evaluates it once and performs at most one action. The first entry puts the player in the spec's stance/form. While channeling, only entries marked `interrupts` run. The one exception to one-action-per-press is a burst key (off-GCD cooldowns all at once).
- Decide from live game state only; any state the addon tracks itself must have a documented reason.
- Spells and auras are referenced by name through one constants table per class file. enUS only.
- Each spec's agreed priority list is a GitHub issue on `Speegel/sdl`; implement against that issue.

## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues on `Speegel/sdl` (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `GLOSSARY.md` plus `docs/adr/`. See `docs/agents/domain.md`.
