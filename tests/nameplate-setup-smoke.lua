-- Startup consent, character CVar backups, and rejected/combat writes.
local function equal(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local cvars, writes, rejected, callbacks, shown
local inCombat, character, refreshes, restores
function UnitGUID() return character end
function UnitFullName() return "Player", "Realm" end
function strtrim(value) return value:match("^%s*(.-)%s*$") end
function InCombatLockdown() return inCombat end
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value)
        writes[#writes + 1] = { name, value }
        if rejected[name] == "error" then error("blocked") end
        if rejected[name] then return end
        cvars[name] = value
    end,
}
StaticPopupDialogs = {}
function StaticPopup_Show(key, text) shown = { key = key, text = text } end
function StaticPopup_Hide() shown = nil end
C_Timer = { After = function(_, callback) callbacks[#callbacks + 1] = callback end }
local function Flush()
    local current = callbacks
    callbacks = {}
    for _, callback in ipairs(current) do callback() end
end
local function Load()
    local ns = {}
    for _, file in ipairs({"Defaults", "FontMedia", "Core", "ManagedNames", "NameplateSetup", "Database"}) do
        assert(loadfile("RPSimpleNameplates/" .. file .. ".lua"))("RPSimpleNameplates", ns)
    end
    ns.RefreshAll = function() refreshes = refreshes + 1 end
    ns.RestoreAll = function() restores = restores + 1 end
    return ns
end
local function Fresh()
    SimpleNameplatesDB = nil
    cvars = {
        nameplateShowAll = "1", nameplateShowEnemies = "1",
        nameplateShowFriendlyPlayers = "1", nameplateShowFriendlyNpcs = "1",
        nameplateShowOnlyNameForFriendlyPlayerUnits = "0",
    }
    writes, rejected, callbacks, shown = {}, {}, {}, nil
    inCombat, character, refreshes, restores = false, "Player-One", 0, 0
    return Load()
end

local ns = Fresh()
equal(ns.CheckNameplateSetup(), true, "compatible startup")
equal(shown, nil, "no unnecessary popup")
equal(#writes, 0, "no silent setting changes")
equal(ns.GetStylingEnabled(), true, "compatible styling enabled")

cvars.nameplateShowFriendlyNpcs = "0"
cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "1"
equal(ns.CheckNameplateSetup(), false, "incompatible startup")
equal(ns.GetStylingEnabled(), false, "styling suspended awaiting choice")
equal(ns.GetCharacterEnabled(), true, "saved intent survives pending popup")
equal(#writes, 0, "no changes before consent")
equal(shown.key, "RPSN_NAMEPLATE_SETUP", "setup popup")
equal(shown.text:find("Friendly NPC Nameplates: Off -> On", 1, true) ~= nil, true, "current and required NPC setting")
equal(shown.text:find("Only Show Names: On -> Off", 1, true) ~= nil, true, "Only Show Names off requirement")
ns.ApplyManagedNameSettings()
equal(#writes, 0, "managed settings honor setup suspension")
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
equal(cvars.nameplateShowFriendlyNpcs, "1", "approved NPC visibility")
equal(cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "0", "approved bars control")
equal(ns.GetStylingEnabled(), true, "styling resumes after verified writes")
equal(refreshes, 1, "refresh after approval")
equal(#writes, 2, "only listed mismatches changed")
local originals = ns.EnsureDB().global.nameplateSetupOriginals[character]
equal(originals.nameplateShowFriendlyNpcs, "0", "NPC original captured")
equal(originals.nameplateShowOnlyNameForFriendlyPlayerUnits, "1", "names original captured")
equal(originals.nameplateShowAll, nil, "unchanged CVar not claimed")

-- Reload preserves backups; checking compatible values does not replace them.
ns = Load()
equal(ns.CheckNameplateSetup(), true, "approved reload")
ns.SetStylingEnabled(false)
equal(cvars.nameplateShowFriendlyNpcs, "0", "reload disable restores NPC original")
equal(cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "1", "reload disable restores names original")
equal(next(ns.EnsureDB().global.nameplateSetupOriginals[character]), nil, "successful originals released")

ns = Fresh()
cvars.nameplateShowFriendlyPlayers = "0"
ns.CheckNameplateSetup()
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnCancel()
equal(ns.GetStylingEnabled(), false, "disable choice")
equal(ns.GetCharacterEnabled(), false, "disable persisted")
equal(#writes, 0, "declining never changes WoW settings")
equal(ns.CheckNameplateSetup(), false, "disabled startup")
equal(shown, nil, "disabled startup has no popup")

ns = Fresh()
cvars.nameplateShowAll = "0"
inCombat = true
ns.CheckNameplateSetup()
equal(shown, nil, "review deferred in combat")
equal(#writes, 0, "combat startup has no writes")
inCombat = false
ns.RetryNameplateSetup()
equal(shown.key, "RPSN_NAMEPLATE_SETUP", "review after combat")
inCombat = true
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
equal(#writes, 0, "approval write deferred in combat")
inCombat = false
ns.RetryNameplateSetup()
equal(cvars.nameplateShowAll, "1", "approved change after combat")
inCombat = true
ns.SetStylingEnabled(false)
equal(cvars.nameplateShowAll, "1", "restore deferred in combat")
inCombat = false
ns.RetryNameplateSetup()
equal(cvars.nameplateShowAll, "0", "restore after combat")

for _, failure in ipairs({"silent", "error"}) do
    ns = Fresh()
    cvars.nameplateShowEnemies, cvars.nameplateShowFriendlyNpcs = "0", "0"
    rejected.nameplateShowFriendlyNpcs = failure
    ns.CheckNameplateSetup()
    StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
    equal(ns.GetStylingEnabled(), false, "failed apply remains suspended")
    Flush()
    equal(shown.text:find("could not be applied", 1, true) ~= nil, true, "failure reported")
    StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnCancel()
    equal(cvars.nameplateShowEnemies, "0", "partial apply restored on disable")
    -- A rejected restoration retains its backup and succeeds when retried.
    equal(ns.EnsureDB().global.nameplateSetupOriginals[character].nameplateShowFriendlyNpcs, nil, "unchanged failed CVar already at original")
end

ns = Fresh()
cvars.nameplateShowAll = "0"
ns.CheckNameplateSetup()
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
rejected.nameplateShowAll = "silent"
ns.SetStylingEnabled(false)
equal(ns.EnsureDB().global.nameplateSetupOriginals[character].nameplateShowAll, "0", "failed restore retains original")
rejected.nameplateShowAll = nil
ns.RetryNameplateSetup()
equal(cvars.nameplateShowAll, "0", "failed restore retries")

ns = Fresh()
cvars.nameplateShowAll = "0"
ns.CheckNameplateSetup()
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
character = "Player-Two"
cvars.nameplateShowAll = "1"
ns = Load()
ns.SetStylingEnabled(false)
equal(cvars.nameplateShowAll, "1", "other character originals not restored")
equal(ns.EnsureDB().global.nameplateSetupOriginals["Player-One"].nameplateShowAll, "0", "other character backup retained")

ns = Fresh()
cvars.nameplateShowFriendlyPlayers = nil
equal(ns.CheckNameplateSetup(), true, "unsupported CVar skipped")
equal(#writes, 0, "unsupported CVar not written")

ns = Fresh()
ns.EnsureDB().global.managedNameCVarOriginals.nameplateShowFriendlyNpcs = "0"
equal(ns.CheckNameplateSetup(), false, "review reads settings after legacy restoration")
equal(cvars.nameplateShowFriendlyNpcs, "0", "legacy original restored before review")
equal(shown.text:find("Friendly NPC Nameplates: Off -> On", 1, true) ~= nil, true, "review reflects restored value")

ns = Fresh()
cvars.nameplateShowAll = "0"
ns.CheckNameplateSetup()
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
inCombat = true
ns.SetStylingEnabled(false)
ns.SetStylingEnabled(true)
equal(ns.CheckNameplateSetup(), false, "reenable waits for combat to end")
inCombat = false
ns.RetryNameplateSetup()
equal(cvars.nameplateShowAll, "1", "canceled restoration not applied")

ns = Fresh()
character = nil
cvars.nameplateShowAll = "0"
ns.CheckNameplateSetup()
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
equal(#writes, 0, "no changes without character backup identity")
equal(ns.GetStylingEnabled(), false, "unknown character keeps styling suspended")
-- Setup cannot approve settings whose legacy restoration is still pending.
ns = Fresh()
ns.EnsureDB().global.managedNameCVarOriginals.nameplateShowFriendlyNpcs = "0"
rejected.nameplateShowFriendlyNpcs = "silent"
equal(ns.CheckNameplateSetup(), false, "legacy restore failure suspends setup")
equal(ns.GetStylingEnabled(), false, "styling paused until legacy originals restored")
equal(shown, nil, "no premature review of transient settings")
ns.ApplyManagedNameSettings()
rejected.nameplateShowFriendlyNpcs = nil
ns.ApplyPendingManagedNameSettings()
ns.RetryNameplateSetup()
equal(cvars.nameplateShowFriendlyNpcs, "0", "legacy retry releases original")
equal(ns.GetStylingEnabled(), false, "styling still paused for compatibility consent")
equal(shown.key, "RPSN_NAMEPLATE_SETUP", "review appears after restoration finishes")
StaticPopupDialogs.RPSN_NAMEPLATE_SETUP.OnAccept()
equal(ns.GetStylingEnabled(), true, "fresh consent resumes styling")
equal(cvars.nameplateShowFriendlyNpcs, "1", "consent reapplies required NPC plates")

print("Nameplate setup smoke: passed")
