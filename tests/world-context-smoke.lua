-- Event-driven world snapshots and conservative presentation access.
-- Run: lua tests/world-context-smoke.lua (or luatex --luaonly).
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local secret = {}
function issecretvalue(value) return value == secret end
function canaccessvalue(value) return value ~= secret end
local ns = {}
assert(loadfile("RPSimpleNameplates/Core.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/WorldContext.lua"))("RPSimpleNameplates", ns)
local world = ns.WorldContext
equal(world.Get().initialized, false, "uninitialized")
local territory, subzone, map, lockdown = "sanctuary", "Shared", 1, false
local reads = 0
function IsInInstance() reads = reads + 1; return false, "none" end
function GetInstanceInfo() return "Outdoor", "none" end
function GetZoneText() return "Silvermoon City" end
function GetSubZoneText() return subzone end
function UnitFactionGroup() return "Horde" end
function UnitIsPVP() return false end
function UnitIsPVPFreeForAll() return false end
function UnitAffectingCombat() return false end
function InCombatLockdown() return lockdown end
C_Map = { GetBestMapForUnit = function() return map end }
C_PvP = {
    GetZonePVPInfo = function() return territory, false, "Horde" end,
    IsWarModeDesired = function() return true end,
    IsWarModeActive = function() return false end,
}
local context, changed = world.Refresh("PLAYER_LOGIN")
equal(changed, true, "first observation")
equal(context.revision, 1, "initial revision")
equal(context.sanctuary, true, "sanctuary")
equal(context.inInstance, false, "outdoor is false")
equal(context.warModeDesired, true, "desired")
equal(context.warModeActive, false, "active remains false")
local queryCount = reads
for _ = 1, 100 do equal(world.Get(), context, "stable cached identity") end
equal(reads, queryCount, "cached reads do not query")
local same, unchanged = world.Refresh("ZONE_CHANGED")
equal(unchanged, false, "unchanged observation")
equal(same, context, "unchanged snapshot retained")
subzone, territory, map = "Horde", "friendly", 2
context, changed = world.Refresh("ZONE_CHANGED")
equal(changed, true, "subzone transition")
equal(context.sanctuary, false, "not sanctuary")
equal(context.mapID, 2, "map transition")
context = world.Refresh("PLAYER_REGEN_DISABLED")
equal(context.inCombat, true, "combat event authoritative")
equal(context.combatLockdown, false, "lockdown independent")
lockdown = true
context = world.Refresh("PLAYER_REGEN_ENABLED")
equal(context.inCombat, false, "combat exit")
equal(context.combatLockdown, true, "independent lockdown retained")
equal(world.HandlesEvent("UNIT_FLAGS", "nameplate1"), false, "entity flags excluded")
equal(world.HandlesEvent("UNIT_FLAGS", "player"), true, "player flags")
equal(world.HandlesEvent("UNIT_FACTION", "player"), true, "player faction")
C_PvP.IsWarModeDesired = function() error("unavailable") end
C_PvP.IsWarModeActive = nil
C_PvP.GetZonePVPInfo = function() return secret, secret, secret end
UnitIsPVP = function() return secret end
context = world.Refresh("WAR_MODE_STATUS_UPDATE")
equal(context.warModeDesired, nil, "failed API unknown")
equal(context.warModeActive, nil, "missing API unknown")
equal(context.territory, nil, "secret territory unknown")
equal(context.sanctuary, nil, "unknown not non-sanctuary")
equal(context.playerPvP, nil, "secret boolean unknown")
GetZonePVPInfo = function() return "contested", false end
C_PvP.GetZonePVPInfo = nil
context = world.Refresh("ZONE_CHANGED_NEW_AREA")
equal(context.territory, "contested", "legacy API fallback")

assert(loadfile("RPSimpleNameplates/Profiler.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/PresentationCapabilities.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/NameplateFrames.lua"))("RPSimpleNameplates", ns)
local cap = ns.PresentationCapabilities
local safe = { combatLockdown = false }
local forbidden = setmetatable({ IsForbidden = function() return true end }, {
    __index = function(_, key) error("forbidden access: " .. key) end,
})
equal(cap.ObjectStatus(forbidden, safe), "forbidden", "forbidden frame")
equal(cap.InspectFrame(forbidden, safe).canAccess, false, "forbidden not inspected")
equal(cap.ReadRegion(forbidden, "GetText", safe), nil, "forbidden read skipped")
equal(cap.ObjectStatus(secret, safe), "unknown", "secret reference")
equal(cap.ObjectStatus({ IsForbidden = function() return secret end }, safe), "unknown", "secret access query")
equal(cap.ObjectStatus({ IsForbidden = function() error("blocked") end }, safe), "unknown", "failed access query")
local protected = { IsProtected = function() return true end, name = {} }
equal(cap.InspectFrame(protected, {combatLockdown = true}).status, "restricted", "protected in combat")
equal(cap.InspectFrame(protected, {}).status, "unknown", "unknown lockdown")
equal(cap.InspectFrame(protected, safe).canAccess, true, "protected accessible after combat")
local frame = { name = {}, healthBar = {}, castBarAnchor = forbidden }
equal(cap.InspectFrame(frame, safe).canAccess, false, "forbidden secondary region")
equal(ns.NameplateFrames.GetHealthBar(frame, safe), nil, "partial assessment never leaks bar")
frame.castBarAnchor = nil
frame.name = secret
equal(cap.InspectFrame(frame, safe).status, "unknown", "secret region reference unknown")
frame.name = {}
equal(cap.InspectFrame(frame, safe).hasHealthBar, true, "supported region")
frame.healthBar = nil
equal(cap.InspectFrame(frame, safe).hasHealthBar, false, "missing bar distinguished")
equal(cap.InspectUnit("target", safe).status, "unknown", "missing API")
C_NamePlate = { GetNamePlateForUnit = function() return nil end }
equal(cap.InspectUnit("target", safe).status, "missing", "missing plate")
C_NamePlate.GetNamePlateForUnit = function() return forbidden end
equal(cap.InspectUnit("target", safe).status, "forbidden", "forbidden base plate")
-- Current Retail templates nest casts inside CastBarsContainer.
local nestedBar = {Icon = {}}
local nestedFrame = {name = {}, CastBarsContainer = {castBar = nestedBar}}
equal(cap.InspectFrame(nestedFrame, safe).castBar, nestedBar, "native nested cast bar found")
equal(cap.InspectFrame(nestedFrame, safe).hasCastBar, true, "native nested cast capability")
equal(ns.NameplateFrames.GetCastBar(nestedFrame, safe), nestedBar, "shared accessor returns nested cast")
local legacyBar = {}
nestedFrame.castBar = legacyBar
equal(cap.InspectFrame(nestedFrame, safe).castBar, legacyBar, "legacy direct cast alias retains precedence")
nestedFrame.castBar, nestedFrame.CastBar = nil, legacyBar
equal(cap.InspectFrame(nestedFrame, safe).castBar, legacyBar, "capitalized cast alias retained")
nestedFrame.CastBar = nil
nestedFrame.CastBarsContainer = forbidden
equal(cap.InspectFrame(nestedFrame, safe).status, "forbidden", "forbidden cast container not inspected")
nestedFrame.CastBarsContainer = secret
equal(cap.InspectFrame(nestedFrame, safe).status, "unknown", "secret cast container rejected")
nestedFrame.CastBarsContainer = {IsProtected = function() return true end, castBar = nestedBar}
equal(cap.InspectFrame(nestedFrame, {combatLockdown = true}).status, "restricted", "cast container protected during combat")
equal(cap.InspectFrame(nestedFrame, safe).castBar, nestedBar, "cast container accessible after combat")
nestedFrame.CastBarsContainer = {castBar = forbidden}
equal(cap.InspectFrame(nestedFrame, safe).status, "forbidden", "nested forbidden bar rejected")
nestedFrame.CastBarsContainer = {castBar = secret}
equal(cap.InspectFrame(nestedFrame, safe).status, "unknown", "secret nested bar rejected")
nestedFrame.CastBarsContainer = setmetatable({}, {__index = function(_, key)
    if key == "castBar" then error("cast field unavailable") end
end})
equal(cap.InspectFrame(nestedFrame, safe).canAccess, false, "failed nested field read cannot masquerade as missing bar")
nestedFrame.CastBarsContainer = {castBar = nestedBar}
nestedBar.Icon = forbidden
equal(cap.InspectFrame(nestedFrame, safe).canAccess, false, "nested forbidden icon rejected")
nestedBar.Icon = {}
equal(cap.InspectFrame(nestedFrame, safe).canAccess, true, "nested cast access recovers")

print("World context and capabilities smoke: passed")

