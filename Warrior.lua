-- Warrior rotations: Fury and Protection (single-target, AoE each).

local _, class = UnitClass("player")
if class ~= "WARRIOR" then return end

local S = {
    BATTLE_SHOUT     = "Battle Shout",
    BERSERKER_STANCE = "Berserker Stance",
    BLOODRAGE        = "Bloodrage",
    BLOODTHIRST      = "Bloodthirst",
    CLEAVE           = "Cleave",
    CONCUSSION_BLOW  = "Concussion Blow",
    DEFENSIVE_STANCE = "Defensive Stance",
    DEMO_SHOUT       = "Demoralizing Shout",
    EXECUTE          = "Execute",
    HEROIC_STRIKE    = "Heroic Strike",
    REVENGE          = "Revenge",
    SHIELD_BLOCK     = "Shield Block",
    SHIELD_SLAM      = "Shield Slam",
    SUNDER_ARMOR     = "Sunder Armor",
    WHIRLWIND        = "Whirlwind",
}

local SHIELDS = "Shields"   -- GetItemInfo item subtype

--------------------------------------------------
-- Helpers

local function HasShield()
    local link = GetInventoryItemLink("player", 17)
    if not link or GetInventoryItemBroken("player", 17) then return false end
    local _, _, id = string.find(link, "item:(%d+)")
    local _, _, _, _, _, subType = GetItemInfo(id)
    return subType == SHIELDS
end

-- Entry that fires whenever the spell can be cast; unlearned spells never can
local function Always(spell)
    return {
        name = spell,
        spell = spell,
        when = function() return SDL.CanCast(spell) end,
    }
end

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

local bloodthirst = Always(S.BLOODTHIRST)
local whirlwind = Always(S.WHIRLWIND)

-- Keep the configured number of Sunder Armor stacks (anyone's) on a non-player target
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

--------------------------------------------------
-- Protection

local shieldBlock = {
    name = "Shield Block",
    spell = S.SHIELD_BLOCK,
    when = function()
        return HasShield() and UnitIsUnit("targettarget", "player") and SDL.CanCast(S.SHIELD_BLOCK)
    end,
}

-- Kept on the target at all times; refreshed just before it falls off
local demoShout = {
    name = "Demoralizing Shout",
    spell = S.DEMO_SHOUT,
    when = function()
        if not SDL.CanCast(S.DEMO_SHOUT) then return false end
        local aura = SDL.Aura("target", S.DEMO_SHOUT, "HARMFUL")
        if not aura then return true end
        local remaining = SDL.AuraRemaining(aura)
        return remaining ~= nil and remaining < 3
    end,
}

-- Revenge is only usable right after a block, dodge or parry
local revenge = Always(S.REVENGE)

-- Reworked on Turtle into a high-threat ability, so it's a filler, not a stun
local concussionBlow = Always(S.CONCUSSION_BLOW)

local sunderFiller = {
    name = "Sunder Armor (filler)",
    spell = S.SUNDER_ARMOR,
    when = function() return not UnitIsPlayer("target") and SDL.CanCast(S.SUNDER_ARMOR) end,
}

SDL.Register("prot_st", {
    melee = true,
    entries = {
        Stance(S.DEFENSIVE_STANCE),
        battleShout,
        bloodrage,
        shieldBlock,
        demoShout,
        revenge,
        Always(S.SHIELD_SLAM),
        bloodthirst,
        Sunder("prot"),
        concussionBlow,
        RageDump(S.HEROIC_STRIKE, {}),
        sunderFiller,
    },
})

SDL.Register("prot_aoe", {
    melee = true,
    entries = {
        Stance(S.DEFENSIVE_STANCE),
        battleShout,
        bloodrage,
        shieldBlock,
        demoShout,
        revenge,
        concussionBlow,
        RageDump(S.CLEAVE, {}),
    },
})
