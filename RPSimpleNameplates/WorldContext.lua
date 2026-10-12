-- Simple Nameplates: event-driven, read-only-by-convention world snapshots.
local _, ns = ...
local AccessibleValue = ns.AccessibleValue
local fields = {
    "instanceType", "instanceName", "inInstance", "zone", "subzone", "mapID",
    "territory", "subzonePvP", "territoryFaction", "sanctuary", "playerFaction",
    "warModeDesired", "warModeActive", "playerPvP", "freeForAll",
    "inCombat", "combatLockdown",
}
local snapshot = { revision = 0, initialized = false }

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return nil end
    return AccessibleValue(a), AccessibleValue(b), AccessibleValue(c)
end

-- A false value is meaningful and must not be collapsed by Lua's and/or idiom.
local function Bool(value)
    if type(value) == "boolean" then return value end
end
local function String(value) if type(value) == "string" then return value end end

local function Observe(event)
    local inInstance, instanceType = Read(IsInInstance)
    local instanceName = Read(GetInstanceInfo)
    local territory, subzonePvP, territoryFaction = Read(
        C_PvP and C_PvP.GetZonePVPInfo or GetZonePVPInfo)
    territory = String(territory)
    local context = {
        inInstance = Bool(inInstance), instanceType = String(instanceType),
        instanceName = String(instanceName),
        zone = String(Read(GetZoneText)), subzone = String(Read(GetSubZoneText)),
        territory = territory, subzonePvP = Bool(subzonePvP),
        territoryFaction = String(territoryFaction),
        playerFaction = String(Read(UnitFactionGroup, "player")),
        warModeDesired = Bool(Read(C_PvP and C_PvP.IsWarModeDesired)),
        warModeActive = Bool(Read(C_PvP and C_PvP.IsWarModeActive)),
        playerPvP = Bool(Read(UnitIsPVP, "player")),
        freeForAll = Bool(Read(UnitIsPVPFreeForAll, "player")),
        inCombat = Bool(Read(UnitAffectingCombat, "player")),
        combatLockdown = Bool(Read(InCombatLockdown)),
    }
    local mapID = Read(C_Map and C_Map.GetBestMapForUnit, "player")
    if type(mapID) == "number" then context.mapID = mapID end
    if territory then context.sanctuary = territory == "sanctuary" end
    if event == "PLAYER_REGEN_DISABLED" then context.inCombat = true end
    if event == "PLAYER_REGEN_ENABLED" then context.inCombat = false end
    return context
end

local contextEvents = {
    PLAYER_LOGIN = true, PLAYER_ENTERING_WORLD = true,
    ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, ZONE_CHANGED_NEW_AREA = true,
    WAR_MODE_STATUS_UPDATE = true, PLAYER_FLAGS_CHANGED = true, PVP_TIMER_UPDATE = true,
    PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true,
}
local function HandlesEvent(event, unit)
    if contextEvents[event] then return true end
    return (event == "UNIT_FLAGS" or event == "UNIT_FACTION") and unit == "player"
end

local function Refresh(event)
    local observed = Observe(event)
    local changed = not snapshot.initialized
    for _, key in ipairs(fields) do
        if observed[key] ~= snapshot[key] then changed = true; break end
    end
    if changed then
        observed.revision = snapshot.revision + 1
        observed.initialized = true
        observed.lastEvent = event
        snapshot = observed
    end
    return snapshot, changed
end

ns.WorldContext = {
    Get = function() return snapshot end,
    Refresh = Refresh,
    HandlesEvent = HandlesEvent,
}
