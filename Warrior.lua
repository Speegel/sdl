-- Warrior rotations: Fury (single-target, AoE).

local _, class = UnitClass("player")
if class ~= "WARRIOR" then return end

local S = {
    BATTLE_SHOUT     = "Battle Shout",
    BERSERKER_STANCE = "Berserker Stance",
    BLOODRAGE        = "Bloodrage",
    BLOODTHIRST      = "Bloodthirst",
    CLEAVE           = "Cleave",
    EXECUTE          = "Execute",
    HEROIC_STRIKE    = "Heroic Strike",
    SUNDER_ARMOR     = "Sunder Armor",
    WHIRLWIND        = "Whirlwind",
}

--------------------------------------------------
-- Shared entries

local function Stance(name)
    return {
        name = name,
        when = function() return not SDL.InForm(name) end,
        cast = function() CastSpellNoToggle(name) end,
    }
end

local battleShout = {
    name = "Battle Shout",
    spell = S.BATTLE_SHOUT,
    when = function()
        local aura = SDL.Aura("player", S.BATTLE_SHOUT, "HELPFUL")
        local remaining = SDL.AuraRemaining(aura)
        return (not aura or (remaining and remaining < 10)) and SDL.CanCast(S.BATTLE_SHOUT)
    end,
}

local bloodrage = {
    name = "Bloodrage",
    spell = S.BLOODRAGE,
    when = function()
        return SDL.Power() <= 65 and SDL.HealthPercent("player") >= 40 and SDL.CanCast(S.BLOODRAGE)
    end,
}

local execute = {
    name = "Execute",
    spell = S.EXECUTE,
    when = function()
        return SDL.HealthPercent("target") < 20 and SDL.CanCast(S.EXECUTE)
    end,
}

local bloodthirst = {
    name = "Bloodthirst",
    spell = S.BLOODTHIRST,
    when = function() return SDL.CanCast(S.BLOODTHIRST) end,
}

local whirlwind = {
    name = "Whirlwind",
    spell = S.WHIRLWIND,
    when = function() return SDL.CanCast(S.WHIRLWIND) end,
}

-- Keep `stacks` of Sunder Armor (anyone's) on a non-player target
local function Sunder(spec)
    return {
        name = "Sunder Armor",
        spell = S.SUNDER_ARMOR,
        when = function()
            local wanted = SDL_Config.sunder[spec]
            if wanted == 0 or UnitIsPlayer("target") or not SDL.CanCast(S.SUNDER_ARMOR) then return false end
            local aura = SDL.Aura("target", S.SUNDER_ARMOR, "HARMFUL")
            if not aura or aura.applications < wanted then return true end
            local remaining = SDL.AuraRemaining(aura)
            return remaining ~= nil and remaining < 5
        end,
    }
end

-- On-next-swing rage dump; skipped while it's already queued
local function RageDump(spell, blockers)
    return {
        name = spell .. " (rage dump)",
        spell = spell,
        when = function()
            if SDL.Power() < 45 or C_Spell.IsCurrentSpell(spell) or not SDL.CanCast(spell) then return false end
            for i = 1, table.getn(blockers) do
                if SDL.Ready(blockers[i]) then return false end
            end
            return true
        end,
    }
end

--------------------------------------------------
-- Fury

SDL.Register("fury_st", {
    melee = true,
    entries = {
        Stance(S.BERSERKER_STANCE),
        battleShout,
        bloodrage,
        execute,
        bloodthirst,
        whirlwind,
        Sunder("fury"),
        RageDump(S.HEROIC_STRIKE, { S.BLOODTHIRST }),
    },
})

SDL.Register("fury_aoe", {
    melee = true,
    entries = {
        Stance(S.BERSERKER_STANCE),
        battleShout,
        bloodrage,
        execute,
        whirlwind,
        bloodthirst,
        RageDump(S.CLEAVE, { S.BLOODTHIRST, S.WHIRLWIND }),
    },
})
