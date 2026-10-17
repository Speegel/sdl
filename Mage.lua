-- Mage rotations: Arcane (single-target, AoE), Frost (single-target),
-- and the Mage burst key.

local _, class = UnitClass("player")
if class ~= "MAGE" then return end

local S = {
    ARCANE_EXPLOSION     = "Arcane Explosion",
    ARCANE_MISSILES      = "Arcane Missiles",
    ARCANE_POWER         = "Arcane Power",
    ARCANE_RUPTURE       = "Arcane Rupture",
    ARCANE_SURGE         = "Arcane Surge",
    FLASH_FREEZE         = "Flash Freeze",
    FROST_NOVA           = "Frost Nova",
    FROST_NOVA_R1        = "Frost Nova(Rank 1)",
    FROSTBOLT            = "Frostbolt",
    ICE_BARRIER          = "Ice Barrier",
    ICICLES              = "Icicles",
    MIND_QUICKENING_GEM  = "Mind Quickening Gem",
    PRESENCE_OF_MIND     = "Presence of Mind",
    TEMPORAL_CONVERGENCE = "Temporal Convergence",
}

local TRINKET_SLOTS = { 13, 14 }

--------------------------------------------------
-- Helpers

local function Always(spell)
    return {
        name = spell,
        spell = spell,
        when = function() return SDL.CanCast(spell) end,
    }
end

local function HasBuff(name)
    return SDL.Aura("player", name, "HELPFUL") ~= nil
end

-- Equipped trinket slot holding `name` whose cooldown is over, or nil
local function ReadyTrinket(name)
    for i = 1, table.getn(TRINKET_SLOTS) do
        local slot = TRINKET_SLOTS[i]
        local link = GetInventoryItemLink("player", slot)
        if link and string.find(link, "[" .. name .. "]", 1, true) then
            local start, duration = GetInventoryItemCooldown("player", slot)
            if duration == 0 or start + duration <= GetTime() then return slot end
        end
    end
    return nil
end

--------------------------------------------------
-- Arcane

-- Turtle's Arcane Surge is only usable right after a resist
local arcaneSurge = Always(S.ARCANE_SURGE)

-- Temporal Convergence makes Rupture worth cutting a Missiles channel for
local ruptureOnConvergence = {
    name = "Arcane Rupture (Temporal Convergence)",
    spell = S.ARCANE_RUPTURE,
    interrupts = true,
    when = function() return HasBuff(S.TEMPORAL_CONVERGENCE) and SDL.CanCast(S.ARCANE_RUPTURE) end,
}

SDL.Register("arcane_st", {
    entries = {
        arcaneSurge,
        ruptureOnConvergence,
        Always(S.ARCANE_RUPTURE),
        Always(S.ARCANE_MISSILES),
    },
})

SDL.Register("arcane_aoe", {
    entries = {
        arcaneSurge,
        Always(S.ARCANE_EXPLOSION),
    },
})

--------------------------------------------------
-- Frost

-- Ice Barrier's buff adds 15% frost damage on Turtle: keep it up at all times
local iceBarrier = {
    name = "Ice Barrier",
    spell = S.ICE_BARRIER,
    when = function() return not HasBuff(S.ICE_BARRIER) and SDL.CanCast(S.ICE_BARRIER) end,
}

-- Flash Freeze resets Icicles and makes it faster: spend it on the proc only
local icicles = {
    name = "Icicles",
    spell = S.ICICLES,
    when = function() return HasBuff(S.FLASH_FREEZE) and SDL.CanCast(S.ICICLES) end,
}

-- A resisted Nova procs Flash Freeze, so Rank 1 goes out on cooldown
-- whenever the target is inside its radius (~10 yd)
local frostNova = {
    name = "Frost Nova (Rank 1)",
    when = function()
        return CheckInteractDistance("target", 3) and SDL.CanCast(S.FROST_NOVA)
    end,
    cast = function() CastSpellByName(S.FROST_NOVA_R1) end,
}

SDL.Register("frost_st", {
    entries = {
        iceBarrier,
        icicles,
        frostNova,
        arcaneSurge,
        Always(S.FROSTBOLT),
    },
})

--------------------------------------------------
-- Burst: all off-GCD cooldowns together

SDL.Register("mage_burst", {
    burst = true,
    entries = {
        {
            name = S.ARCANE_POWER,
            spell = S.ARCANE_POWER,
            when = function() return not HasBuff(S.ARCANE_POWER) and SDL.CanCast(S.ARCANE_POWER) end,
        },
        {
            name = S.PRESENCE_OF_MIND,
            spell = S.PRESENCE_OF_MIND,
            when = function() return not HasBuff(S.PRESENCE_OF_MIND) and SDL.CanCast(S.PRESENCE_OF_MIND) end,
        },
        {
            name = S.MIND_QUICKENING_GEM,
            when = function() return ReadyTrinket(S.MIND_QUICKENING_GEM) ~= nil end,
            cast = function() UseInventoryItem(ReadyTrinket(S.MIND_QUICKENING_GEM)) end,
        },
    },
})
