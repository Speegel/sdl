-- Druid rotations: Cat (single-target), Bear (single-target, AoE),
-- Balance (single-target).

local _, class = UnitClass("player")
if class ~= "DRUID" then return end

local S = {
    ARCANE_ECLIPSE    = "Arcane Eclipse",
    ARCANE_SOLSTICE   = "Arcane Solstice",
    BEAR_FORM         = "Bear Form",
    CAT_FORM          = "Cat Form",
    CLAW              = "Claw",
    CLEARCASTING      = "Clearcasting",
    COWER             = "Cower",
    DEMO_ROAR         = "Demoralizing Roar",
    DIRE_BEAR_FORM    = "Dire Bear Form",
    FAERIE_FIRE_FERAL = "Faerie Fire (Feral)",
    FEROCIOUS_BITE    = "Ferocious Bite",
    INSECT_SWARM      = "Insect Swarm",
    MAUL              = "Maul",
    MOONFIRE          = "Moonfire",
    MOONKIN_FORM      = "Moonkin Form",
    NATURAL_SOLSTICE  = "Natural Solstice",
    NATURE_ECLIPSE    = "Nature Eclipse",
    PROWL             = "Prowl",
    RAKE              = "Rake",
    RAVAGE            = "Ravage",
    RIP               = "Rip",
    SAVAGE_BITE       = "Savage Bite",
    SHRED             = "Shred",
    STARFIRE          = "Starfire",
    SWIPE             = "Swipe",
    TIGERS_FURY       = "Tiger's Fury",
    WRATH             = "Wrath",
}

-- Combat-log message for a bleed-immune target (elementals, mechanicals, ...)
local BLEED_IMMUNE_PATTERNS = {
    "Your Rip failed%. (.+) is immune%.",
    "Your Rake failed%. (.+) is immune%.",
}

--------------------------------------------------
-- Tracked state: the bleed-immune list. The game can't tell us a target is
-- immune to bleeds until a bleed fails on it, so the name is remembered
-- (in SDL_Config, so it survives sessions) and both bleeds are skipped.

local function RememberBleedImmune()
    if not arg1 then return end
    for i = 1, table.getn(BLEED_IMMUNE_PATTERNS) do
        local _, _, name = string.find(arg1, BLEED_IMMUNE_PATTERNS[i])
        if name and not SDL_Config.bleedImmune[name] then
            SDL_Config.bleedImmune[name] = true
            SDL.Print(name .. " is bleed-immune, remembered")
        end
    end
end

SDL.On("CHAT_MSG_SPELL_SELF_DAMAGE", RememberBleedImmune)

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

local function Form(name)
    return {
        name = name,
        when = function() return not SDL.InForm(name) end,
        cast = function() CastSpellNoToggle(name) end,
    }
end

-- Dire Bear Form once learned, Bear Form before
local bearForm = {
    name = "Bear Form",
    when = function()
        local form = SDL.HasForm(S.DIRE_BEAR_FORM) and S.DIRE_BEAR_FORM or S.BEAR_FORM
        return not SDL.InForm(form)
    end,
    cast = function()
        CastSpellNoToggle(SDL.HasForm(S.DIRE_BEAR_FORM) and S.DIRE_BEAR_FORM or S.BEAR_FORM)
    end,
}

-- A target debuff that is missing (anyone's copy counts)
local function KeepDebuff(spell)
    return {
        name = spell,
        spell = spell,
        when = function()
            return not SDL.Aura("target", spell, "HARMFUL") and SDL.CanCast(spell)
        end,
    }
end

-- Shred from behind, Claw otherwise
local function Builder(name, extra)
    return {
        name = name,
        when = function()
            if extra and not extra() then return false end
            local spell = UnitXP("behind", "player", "target") and S.SHRED or S.CLAW
            return SDL.CanCast(spell)
        end,
        cast = function()
            CastSpellByName(UnitXP("behind", "player", "target") and S.SHRED or S.CLAW)
        end,
    }
end

--------------------------------------------------
-- Cat

SDL.Register("cat_st", {
    melee = true,
    entries = {
        Form(S.CAT_FORM),
        {
            name = "Cower (threat > 80%)",
            spell = S.COWER,
            when = function()
                return SDL.InGroup() and SDL.ThreatPercent() > 80 and SDL.CanCast(S.COWER)
            end,
        },
        -- No cooldown check: in this client Tiger's Fury only has the GCD,
        -- and a readiness check kept it from ever being cast
        {
            name = S.TIGERS_FURY,
            spell = S.TIGERS_FURY,
            when = function() return not HasBuff(S.TIGERS_FURY) and SDL.Usable(S.TIGERS_FURY) end,
        },
        {
            name = S.RAVAGE,
            spell = S.RAVAGE,
            when = function() return HasBuff(S.PROWL) and SDL.CanCast(S.RAVAGE) end,
        },
        Builder("Clearcasting builder", function() return HasBuff(S.CLEARCASTING) end),
        {
            name = S.RIP,
            spell = S.RIP,
            when = function()
                if GetComboPoints() < 4 or SDL.HealthPercent("target") < 20 or SDL.IsBleedImmune() then return false end
                local aura = SDL.MyAura("target", S.RIP, "HARMFUL")
                local remaining = SDL.AuraRemaining(aura)
                return (not aura or (remaining and remaining < 3)) and SDL.CanCast(S.RIP)
            end,
        },
        {
            name = S.FEROCIOUS_BITE,
            spell = S.FEROCIOUS_BITE,
            when = function() return GetComboPoints() >= 4 and SDL.CanCast(S.FEROCIOUS_BITE) end,
        },
        -- At 4+ combo points, wait for energy instead of spending it on a builder
        {
            name = "pool energy for finisher",
            when = function() return GetComboPoints() >= 4 end,
            cast = function() end,
        },
        KeepDebuff(S.FAERIE_FIRE_FERAL),
        {
            name = S.RAKE,
            spell = S.RAKE,
            when = function()
                return not SDL.IsBleedImmune() and not SDL.MyAura("target", S.RAKE, "HARMFUL") and SDL.CanCast(S.RAKE)
            end,
        },
        Builder("builder"),
    },
})

--------------------------------------------------
-- Bear

-- On-next-swing; skipped while already queued
local maul = {
    name = S.MAUL,
    spell = S.MAUL,
    when = function() return not C_Spell.IsCurrentSpell(S.MAUL) and SDL.CanCast(S.MAUL) end,
}

SDL.Register("bear_st", {
    melee = true,
    entries = {
        bearForm,
        KeepDebuff(S.DEMO_ROAR),
        KeepDebuff(S.FAERIE_FIRE_FERAL),
        maul,
        Always(S.SAVAGE_BITE),
    },
})

SDL.Register("bear_aoe", {
    melee = true,
    entries = {
        bearForm,
        KeepDebuff(S.DEMO_ROAR),
        Always(S.SWIPE),
        maul,
    },
})

--------------------------------------------------
-- Balance

-- Our own DoT, missing or about to fall off
local function KeepDot(spell)
    return {
        name = spell,
        spell = spell,
        when = function()
            local aura = SDL.MyAura("target", spell, "HARMFUL")
            local remaining = SDL.AuraRemaining(aura)
            return (not aura or (remaining and remaining <= 1)) and SDL.CanCast(spell)
        end,
    }
end

local function OnAura(name, spell, extra)
    return {
        name = spell .. " (" .. name .. ")",
        spell = spell,
        when = function()
            if not SDL.Aura("player", name) then return false end
            if extra and not extra() then return false end
            return SDL.CanCast(spell)
        end,
    }
end

SDL.Register("balance_st", {
    entries = {
        Form(S.MOONKIN_FORM),
        KeepDot(S.MOONFIRE),
        KeepDot(S.INSECT_SWARM),
        OnAura(S.ARCANE_ECLIPSE, S.STARFIRE),
        OnAura(S.NATURE_ECLIPSE, S.WRATH),
        OnAura(S.NATURAL_SOLSTICE, S.STARFIRE, function() return not SDL.Aura("player", S.ARCANE_SOLSTICE) end),
        Always(S.WRATH),
    },
})
