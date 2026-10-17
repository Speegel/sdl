-- SDL core: namespace, client-mod check, config, state queries, the
-- rotation runner, and the /sdl slash command. See GLOSSARY.md for terms.

SDL = {
    ok = false,       -- true once every required client mod is present (ADR-0001)
    rotations = {},   -- key -> rotation, filled by the class files
    defaults = {
        debug = false,
        sunder = { fury = 0, prot = 5 },
        bleedImmune = {},   -- target name -> true; persists across sessions
    },
    handlers = {},    -- event -> list of functions, see SDL.On
}

BINDING_HEADER_SDL = "SDL"
BINDING_NAME_SDL_FURY_ST = "Fury - single target"
BINDING_NAME_SDL_FURY_AOE = "Fury - AoE"
BINDING_NAME_SDL_PROT_ST = "Protection - single target"
BINDING_NAME_SDL_PROT_AOE = "Protection - AoE"
BINDING_NAME_SDL_ARCANE_ST = "Arcane - single target"
BINDING_NAME_SDL_ARCANE_AOE = "Arcane - AoE"
BINDING_NAME_SDL_FROST_ST = "Frost - single target"
BINDING_NAME_SDL_MAGE_BURST = "Mage - burst cooldowns"
BINDING_NAME_SDL_CAT_ST = "Cat - single target"
BINDING_NAME_SDL_BEAR_ST = "Bear - single target"
BINDING_NAME_SDL_BEAR_AOE = "Bear - AoE"
BINDING_NAME_SDL_BALANCE_ST = "Balance - single target"

CreateFrame("Frame", "SDLFrame")

--------------------------------------------------
-- Output

function SDL.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800SDL|r: " .. msg)
end

function SDL.Debug(msg)
    if SDL_Config and SDL_Config.debug then
        SDL.Print(msg)
    end
end

--------------------------------------------------
-- Client mods (ADR-0001)

local function MissingClientMods()
    local missing = {}
    if type(QueueSpellByName) ~= "function" then table.insert(missing, "Nampower") end
    if not SUPERWOW_VERSION then table.insert(missing, "SuperWoW") end
    if type(C_UnitAuras) ~= "table" or type(C_Spell) ~= "table" then table.insert(missing, "ClassicAPI") end
    if type(UnitXP) ~= "function" then table.insert(missing, "UnitXP_SP3") end
    return missing
end

--------------------------------------------------
-- Config: fill in any default the saved table lacks, one level deep

local function ApplyDefaults(saved, defaults)
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            if type(v) == "table" then
                saved[k] = {}
                ApplyDefaults(saved[k], v)
            else
                saved[k] = v
            end
        elseif type(v) == "table" and type(saved[k]) == "table" then
            ApplyDefaults(saved[k], v)
        end
    end
end

--------------------------------------------------
-- State queries: every press reads live game state

-- Nampower's queue window in seconds; a spell whose cooldown ends within
-- it counts as ready, so a press during the GCD queues it instead of
-- falling through to a lower entry.
local function QueueWindow()
    local ok, ms = pcall(GetCVar, "NP_SpellQueueWindowMs")
    ms = ok and tonumber(ms) or 0
    return ms / 1000
end

function SDL.Cooldown(spell)
    local info = C_Spell.GetSpellCooldown(spell)
    if not info or info.duration == 0 then return 0 end
    local remaining = info.startTime + info.duration - GetTime()
    if remaining < 0 then return 0 end
    return remaining
end

function SDL.Ready(spell)
    return SDL.Cooldown(spell) <= QueueWindow()
end

-- Known, not blocked, enough resource (cooldown ignored)
function SDL.Usable(spell)
    local usable = C_Spell.IsSpellUsable(spell)
    return usable and true or false
end

function SDL.CanCast(spell)
    return SDL.Usable(spell) and SDL.Ready(spell)
end

-- Aura by name; filter "HELPFUL"/"HARMFUL" or nil for both
function SDL.Aura(unit, name, filter)
    return C_UnitAuras.GetAuraDataBySpellName(unit, name, filter)
end

-- The player's own copy of an aura (another druid's Moonfire doesn't count).
-- An aura whose caster wasn't observed this session is assumed to be ours.
function SDL.MyAura(unit, name, filter)
    local i = 1
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
    while aura do
        if aura.name == name and (aura.sourceUnit == "player" or aura.sourceUnit == nil) then return aura end
        i = i + 1
        aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
    end
    return nil
end

-- Seconds left on an aura, or nil when the client doesn't know the timer
function SDL.AuraRemaining(aura)
    if not aura or not aura.expirationTime or aura.expirationTime == 0 then return nil end
    return aura.expirationTime - GetTime()
end

function SDL.Power()
    return UnitMana("player")
end

function SDL.HealthPercent(unit)
    local max = UnitHealthMax(unit)
    if not max or max == 0 then return 100 end
    return UnitHealth(unit) / max * 100
end

function SDL.HasForm(name)
    for i = 1, GetNumShapeshiftForms() do
        local _, formName = GetShapeshiftFormInfo(i)
        if formName == name then return true end
    end
    return false
end

function SDL.InForm(name)
    for i = 1, GetNumShapeshiftForms() do
        local _, formName, active = GetShapeshiftFormInfo(i)
        if formName == name then return active and true or false end
    end
    return false
end

function SDL.InGroup()
    return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0
end

-- Threat percent from the optional TWThreat addon; 0 when it's absent
function SDL.ThreatPercent()
    if not (TWT and TWT.threats and TWT.name) then return 0 end
    local data = TWT.threats[TWT.name]
    return (data and data.perc) or 0
end

function SDL.IsBleedImmune()
    local name = UnitName("target")
    return name ~= nil and SDL_Config.bleedImmune[name] == true
end

--------------------------------------------------
-- Events: class files subscribe with SDL.On(event, fn); fn reads the
-- usual `event`/`arg1` globals

function SDL.On(eventName, fn)
    if not SDL.handlers[eventName] then
        SDL.handlers[eventName] = {}
        SDLFrame:RegisterEvent(eventName)
    end
    table.insert(SDL.handlers[eventName], fn)
end

local function HasHostileTarget()
    return UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target")
end

--------------------------------------------------
-- Rotation runner (ADR-0002)
--
-- A rotation is { melee = bool, entries = { { name, spell, when, cast, interrupts }, ... } }.
-- `when` is required; `cast` defaults to CastSpellByName(spell).
-- While the player channels, only entries with `interrupts = true` are
-- considered, and they stop the channel before casting. During a regular
-- cast every entry is considered: Nampower queues the result.
--
-- A burst ({ burst = true, entries = ... }) is the one exception to
-- one-action-per-press: it fires every entry whose condition holds, needs
-- no target, and is meant only for off-GCD cooldowns.

function SDL.Register(key, rotation)
    SDL.rotations[key] = rotation
end

local function Fire(entry)
    if entry.cast then
        entry.cast()
    else
        CastSpellByName(entry.spell)
    end
end

local function PressBurst(key, entries)
    local fired = false
    for i = 1, table.getn(entries) do
        local entry = entries[i]
        if entry.when() then
            Fire(entry)
            SDL.Debug(key .. ": " .. entry.name)
            fired = true
        end
    end
    if not fired then SDL.Debug(key .. ": nothing ready") end
end

function SDL.Press(key)
    if not SDL.ok then return end

    local rotation = SDL.rotations[key]
    if not rotation then
        SDL.Debug(key .. ": not available for this character")
        return
    end

    if rotation.burst then
        PressBurst(key, rotation.entries)
        return
    end

    if not HasHostileTarget() then
        TargetNearestEnemy()
        if not HasHostileTarget() then
            SDL.Debug(key .. ": nothing (no hostile target)")
            return
        end
    end

    if rotation.melee then
        StartAttack()
    end

    local channeling = C_Spell.ChannelInfo() ~= nil
    local entries = rotation.entries
    for i = 1, table.getn(entries) do
        local entry = entries[i]
        if (entry.interrupts or not channeling) and entry.when() then
            if channeling then SpellStopCasting() end
            Fire(entry)
            SDL.Debug(key .. ": " .. entry.name)
            return
        end
    end
    SDL.Debug(key .. (channeling and ": nothing (channeling)" or ": nothing (no entry's condition held)"))
end

--------------------------------------------------
-- Slash command

local function SlashCommand(msg)
    local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")

    if cmd == "debug" then
        SDL_Config.debug = not SDL_Config.debug
        SDL.Print("debug " .. (SDL_Config.debug and "on" or "off"))
    elseif cmd == "resetimmune" then
        SDL_Config.bleedImmune = {}
        SDL.Print("bleed-immune list cleared")
    elseif cmd == "sunder" then
        local _, _, spec, n = string.find(rest, "^(%a+)%s+(%d)$")
        if spec and SDL_Config.sunder[spec] ~= nil and tonumber(n) <= 5 then
            SDL_Config.sunder[spec] = tonumber(n)
            SDL.Print("sunder " .. spec .. " = " .. n)
        else
            SDL.Print("usage: /sdl sunder <fury|prot> <0-5>")
        end
    else
        SDL.Print("/sdl debug - toggle per-press debug output")
        SDL.Print("/sdl sunder <spec> <0-5> - Sunder Armor stacks to maintain (0 = off)")
        SDL.Print("/sdl resetimmune - forget remembered bleed-immune targets")
    end
end

--------------------------------------------------
-- Lifecycle

SDLFrame:RegisterEvent("ADDON_LOADED")
SDLFrame:SetScript("OnEvent", function()
    local handlers = SDL.handlers[event]
    if handlers and SDL.ok then
        for i = 1, table.getn(handlers) do handlers[i]() end
    end

    if event == "ADDON_LOADED" and string.lower(arg1 or "") == "sdl" then
        if type(SDL_Config) ~= "table" then SDL_Config = {} end
        ApplyDefaults(SDL_Config, SDL.defaults)

        SLASH_SDL1 = "/sdl"
        SlashCmdList["SDL"] = SlashCommand

        local missing = MissingClientMods()
        if table.getn(missing) > 0 then
            SDL.Print(table.concat(missing, ", ") .. " not loaded, rotations disabled")
        else
            SDL.ok = true
        end
    end
end)
