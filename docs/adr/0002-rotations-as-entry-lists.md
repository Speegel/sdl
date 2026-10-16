# Rotations are lists of named entries, not if/elseif functions

Each rotation is declared as an ordered list of named entries (name, condition, action) that the core walks on every press, casting the first entry whose condition holds. We chose this over the legacy hand-written `if/elseif` chains so that priority order is the list order, `/sdl debug` can always report exactly which entry fired (or why none did), and inserting at a priority slot is a one-line change. The trade-off is that an entry can't do several things in one press — which the one-press-one-action rule already forbids.
