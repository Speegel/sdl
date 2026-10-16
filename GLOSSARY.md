# SDL (Spiegel DPS Library)

A one-button combat helper for Turtle WoW (1.12 client): the player spams a key, and on each press the addon picks the single best action for the player's current spec.

## Language

**Spec**:
One of the supported class roles the addon has a rotation for: Druid Balance, Druid Cat, Druid Bear, Mage Arcane, Mage Frost, Warrior Fury, Warrior Protection.
_Avoid_: Build, role, class mode

**Rotation**:
The ordered priority list of entries for one spec and target count; earlier entries preempt later ones.
_Avoid_: Sequence, combo, routine

**Entry**:
One named line of a rotation: a condition and the single action taken when it is the first entry whose condition holds.
_Avoid_: Step, branch, rule

**Press**:
One player keypress on a rotation's keybind or macro, which evaluates the rotation once and performs at most one action.
_Avoid_: Tick, frame, update, spam

**Ready**:
A spell whose cooldown ends soon enough that pressing now would queue it, so it is cast the moment the cooldown is over.
_Avoid_: Off cooldown, available

**Single-target / AoE**:
The two situations a rotation can be pressed for; the player chooses which by pressing a different keybind, never by the addon guessing.
_Avoid_: Mono, normal, multi, isMulti

**Client mod**:
A DLL loaded into the game client (Nampower, SuperWoW, ClassicAPI) that extends the Lua API; distinct from an addon.
_Avoid_: Plugin, extension, library

**Legacy addon**:
Waaagh or WaaaghDruid as they exist before the rework, kept installed as a fallback and reference until SDL has caught up.
_Avoid_: Old version, v1
