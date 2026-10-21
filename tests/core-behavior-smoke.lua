-- Characterization of the current Core.lua contract.
-- Run from the repository root: lua tests/core-behavior-smoke.lua
-- LuaTeX can also run it with: luatex --luaonly tests/core-behavior-smoke.lua

local function equal(actual, expected, message)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(message, tostring(expected), tostring(actual)), 2)
    end
end

local character = "Player-One"
local inCombat = false
local cvars = {}
local writes = {}
local rejectedWrites = {}

function UnitGUID() return character end
function UnitFullName() return "Fallback", "Realm" end
function strtrim(value) return value:match("^%s*(.-)%s*$") end
function InCombatLockdown() return inCombat end
function wipe(t) for key in pairs(t) do t[key] = nil end end
C_CVar = {
    GetCVar = function(name) return cvars[name] or "1" end,
    SetCVar = function(name, value)
        if rejectedWrites[name] == "silent" then return end
        if rejectedWrites[name] then error("CVar write blocked") end
        cvars[name] = value
        writes[#writes + 1] = { name, value }
    end,
}
local function loadCore()
    local namespace = {}
    for _, file in ipairs({ "Defaults.lua", "FontMedia.lua", "Core.lua", "ManagedNames.lua", "Database.lua" }) do
        assert(loadfile("RPSimpleNameplates/" .. file))("RPSimpleNameplates", namespace)
    end
    return namespace
end
local function fresh()
    SimpleNameplatesDB = nil
    cvars, writes, rejectedWrites = {}, {}, {}
    inCombat, character = false, "Player-One"
    return loadCore()
end

-- Width defaults, clamps, survives profile copying/reload, and resets.
local widthNS = fresh()
equal(widthNS.GetAppearanceSetting("healthBarWidth"), 120, "wider bar default")
widthNS.SetAppearanceSetting("healthBarWidth", 300)
equal(widthNS.GetAppearanceSetting("healthBarWidth"), 150, "width upper clamp")
widthNS.SetAppearanceSetting("healthBarWidth", 10)
equal(widthNS.GetAppearanceSetting("healthBarWidth"), 80, "width lower clamp")
widthNS.SetAppearanceSetting("healthBarWidth", 124)
equal(widthNS.GetAppearanceSetting("healthBarWidth"), 125, "width uses five-percent steps")
widthNS.SetAppearanceSetting("healthBarWidth", 0/0)
equal(widthNS.GetAppearanceSetting("healthBarWidth"), 125, "invalid width ignored")
widthNS.CopyActiveProfile("Wider bars")
widthNS = loadCore()
equal(widthNS.GetAppearanceSetting("healthBarWidth"), 125, "copied width survives reload")
widthNS.ResetAppearance()
equal(widthNS.GetAppearanceSetting("healthBarWidth"), 120, "Appearance reset restores wider default")

-- Cast activation is profile-specific, survives reload, and resets with Colors.
local effectNS = fresh()
equal(effectNS.GetInterruptibleEffect(), "PULSE", "effect defaults pulse")
effectNS.SetInterruptibleEffect("SOLID")
equal(effectNS.GetInterruptibleHighlightEnabled(), false, "highlight defaults off")
effectNS.SetInterruptibleHighlightEnabled(true)
effectNS.CopyActiveProfile("Pulse cast bars")
effectNS = loadCore()
equal(effectNS.GetInterruptibleEffect(), "SOLID", "copied effect survives reload")
effectNS.SetInterruptibleEffect("invalid")
equal(effectNS.GetInterruptibleEffect(), "SOLID", "invalid effect setter ignored")
equal(effectNS.GetInterruptibleHighlightEnabled(), true, "copied activation survives reload")
effectNS.ResetAppearance()
equal(effectNS.GetInterruptibleEffect(), "SOLID", "Appearance reset preserves effect")
equal(effectNS.GetInterruptibleHighlightEnabled(), true, "Appearance reset preserves activation")
effectNS.ResetAllColors()
equal(effectNS.GetInterruptibleEffect(), "SOLID", "Colors reset preserves cast effect")
effectNS.EnsureDB().profiles[effectNS.GetActiveProfileName()].interruptibleEffect = "invalid"
effectNS = loadCore()
equal(effectNS.GetInterruptibleEffect(), "PULSE", "invalid saved effect defaults pulse")
equal(effectNS.GetInterruptibleHighlightEnabled(), true, "Colors reset preserves cast activation")
-- Retired style settings are discarded without supplying activation.
for _, legacy in ipairs({{true, "PIXEL", true}, {false, "PROC", false},
    {nil, "NONE", false}, {nil, "PIXEL", false}, {nil, "AUTOCAST", false},
    {nil, "BUTTON", false}, {nil, "PROC", false}}) do
    effectNS = fresh()
    local profile = effectNS.EnsureDB().profiles.Default
    profile.interruptibleHighlight, profile.interruptibleCastStyle = legacy[1], legacy[2]
    effectNS = loadCore()
    equal(effectNS.GetInterruptibleHighlightEnabled(), legacy[3], "current activation retained or defaulted")
    equal(effectNS.EnsureDB().profiles.Default.interruptibleCastStyle, nil, "retired style removed")
end

-- Pulse and Alert have independent validated controls; no obsolete migration.
local borders = fresh()
equal(borders.GetCastBorderSetting("PULSE", "thickness"), 4, "shared thickness default")
equal(borders.GetCastBorderSetting("PULSE", "offset"), 3, "shared outward offset default")
equal(borders.GetCastBorderSetting("PULSE", "fadeIn"), 0.1, "original fade-in default")
equal(borders.GetCastBorderSetting("PULSE", "fadeOut"), 0.1, "original fade-out default")
equal(borders.GetCastBorderSetting("ALERT", "minLength"), 20, "Alert minimum default")
equal(borders.GetCastBorderSetting("ALERT", "maxLength"), 100, "Alert maximum default")
local saved = borders.EnsureDB().profiles.Default
saved.castAdvanced = {PULSE = {thickness=7, fadeIn=0.55, fadeOut=99, minLength=30},
    ALERT={minLength=25, maxLength=85, shrinkTime=0.45, endOpacity=40, centerOpacity=80},
    SOLID={thickness=2}, SOFT={thickness=8}, ANTS={frames=11}, GLOW={offsetX=5}}
saved.interruptibleEffect = "ALERT"
borders = loadCore()
equal(borders.GetInterruptibleEffect(), "ALERT", "Alert selection survives reload")
equal(borders.GetCastBorderSetting("PULSE", "thickness"), 7, "valid thickness retained")
equal(borders.GetCastBorderSetting("PULSE", "fadeIn"), 0.55, "valid pulse timing retained")
equal(borders.GetCastBorderSetting("PULSE", "fadeOut"), 0.1, "invalid pulse timing defaults")
equal(borders.GetCastBorderSetting("PULSE", "minLength"), nil, "old pulse length discarded without migration")
equal(borders.GetCastBorderSetting("ALERT", "minLength"), 25, "valid Alert length retained")
local retained = borders.EnsureDB().profiles.Default.castAdvanced
for _, key in ipairs({"SOLID", "SOFT", "ANTS", "GLOW"}) do equal(retained[key], nil, "obsolete controls discarded") end
borders.SetCastBorderSetting("ALERT", "maxLength", 5)
equal(borders.GetCastBorderSetting("ALERT", "maxLength"), 25, "maximum cannot pass minimum")
borders.CopyActiveProfile("Borders")
borders = loadCore()
equal(borders.GetCastBorderSetting("ALERT", "endOpacity"), 40, "Alert gradient survives copy/reload")
local profile = borders.EnsureDB().profiles[borders.GetActiveProfileName()]
profile.castAdvanced.ALERT.minLength, profile.castAdvanced.ALERT.maxLength = 90, 20
borders = loadCore()
equal(borders.GetCastBorderSetting("ALERT", "minLength"), 20, "invalid saved length pair defaults")
equal(borders.GetCastBorderSetting("ALERT", "maxLength"), 100, "invalid saved length pair defaults")
borders.ResetHighlightSettings()
equal(borders.GetCastBorderSetting("PULSE", "thickness"), 4, "Colors reset thickness")
equal(borders.GetCastBorderSetting("PULSE", "fadeIn"), 0.1, "Colors reset original pulse")
equal(borders.GetCastBorderSetting("ALERT", "minLength"), 20, "Colors reset Alert")

borders.SetInterruptibleHighlightEnabled(true)
borders.SetEffectColor("interruptible", 0.4, 0.5, 0.6)
borders.SetInterruptibleEffect("ALERT")
borders.SetCastBorderSetting("PULSE", "fadeIn", 0.5)
borders.ResetHighlightSettings()
equal(borders.GetInterruptibleEffect(), "PULSE", "Highlight reset restores effect")
equal(borders.GetCastBorderSetting("PULSE", "fadeIn"), 0.1, "Highlight reset restores timing")
equal(borders.GetInterruptibleHighlightEnabled(), false, "Highlight reset disables highlight")
local r, g, b = borders.EffectColor("interruptible")
equal(r, 0.2, "Highlight reset restores cast color")
borders.ResetAllColors()
r, g, b = borders.EffectColor("interruptible")
equal(r, 0.2, "new factory red component")
equal(g, 0, "new factory green component")
equal(b, 1, "new factory blue component")

-- Background dimming validation and persistence.
local dim = fresh()
equal(dim.GetDimBackgroundNames(), true, "dim defaults on")
dim.SetDimBackgroundNames(false)
dim = loadCore()
equal(dim.GetDimBackgroundNames(), false, "saved dim Off survives reload")
dim.EnsureDB().profiles.Default.dimBackgroundNames = "invalid"
dim = loadCore()
equal(dim.GetDimBackgroundNames(), true, "invalid dim uses default")

-- Fresh defaults and independent character selection.
local ns = fresh()
local db = ns.EnsureDB()
equal(db.schemaVersion, 2, "schema")
equal(ns.GetActiveProfileName(), "Default", "fresh selection")
equal(ns.GetStylingEnabled(), true, "master default")
equal(ns.GetCategoryMode("friendly"), "active", "category default")
equal(ns.GetTRP3Enabled(), false, "TRP3 default")
equal(ns.GetThreatEnabled(), true, "threat default")
equal(ns.GetInterruptibleHighlightEnabled(), false, "cast default")
equal(ns.GetAppearanceSetting("useSlugRendering"), true, "Slug defaults on")
ns.SetAppearanceSetting("useSlugRendering", false)
equal(ns.CopyActiveProfile("Slug copy"), true, "copy Slug choice")
ns = loadCore()
equal(ns.GetAppearanceSetting("useSlugRendering"), false, "copied disabled Slug survives reload")
ns.ResetAppearance()
equal(ns.GetAppearanceSetting("useSlugRendering"), true, "reset enables Slug")
ns.DeleteActiveProfile()
equal(ns.GetAppearanceSetting("useSlugRendering"), false, "Slug profile choices are independent")
ns.SetAppearanceSetting("useSlugRendering", "true")
equal(ns.GetAppearanceSetting("useSlugRendering"), false, "invalid Slug setter ignored")
ns.EnsureDB().profiles.Default.appearance.useSlugRendering = "invalid"
ns = loadCore()
equal(ns.GetAppearanceSetting("useSlugRendering"), true, "invalid saved Slug value uses default")
db = ns.EnsureDB()
equal(ns.GetAppearanceSetting("matchSanctuaryFont"), true, "sanctuary matching default")
ns.SetAppearanceSetting("matchSanctuaryFont", false)
equal(ns.CopyActiveProfile("Font copy"), true, "copy sanctuary font choice")
equal(ns.GetAppearanceSetting("matchSanctuaryFont"), false, "copied sanctuary font choice")
ns.ResetAppearance()
equal(ns.GetAppearanceSetting("matchSanctuaryFont"), true, "reset sanctuary matching default")
ns.DeleteActiveProfile()
equal(ns.GetAppearanceSetting("matchSanctuaryFont"), false, "profile choice independent")
ns.ResetAppearance()
ns.SetAppearanceSetting("matchSanctuaryFont", "false")
equal(ns.GetAppearanceSetting("matchSanctuaryFont"), true, "invalid setter ignored")
equal(ns.GetAppearanceSetting("nameFont"), "FRIZQT", "name font default")
equal(ns.GetAppearanceSetting("nameSize"), 18, "name size default")
equal(ns.GetAppearanceSetting("namePlacement"), "INSIDE", "placement default")
equal(ns.PriorityColorForState("attacking"), 1, "default red component")
for _, case in ipairs({
    {"friendly", 0, 0, 255},
    {"useful", 0, 255, 0},
    {"useless", 153, 153, 153},
}) do
    local r, g, b = ns.PriorityColorForState(case[1])
    equal(r, case[2] / 255, "sanctuary default red")
    equal(g, case[3] / 255, "sanctuary default green")
    equal(b, case[4] / 255, "sanctuary default blue")
    ns.SetPriorityColor(case[1], 0.2, 0.3, 0.4)
    equal(ns.CopyActiveProfile("Sanctuary copy"), true, "copy sanctuary colors")
    equal(ns.PriorityColorForState(case[1]), 0.2, "copied sanctuary customization")
    ns.ResetPriorityColor(case[1])
    equal(ns.PriorityColorForState(case[1]), case[2] / 255, "reset sanctuary color")
    ns.DeleteActiveProfile()
    ns.ResetPriorityColor(case[1])
end
equal(ns.EnsureDB().profiles.Default.priorityColors.sanctuaryUseful, nil, "no separate useful sanctuary setting")
equal(ns.EnsureDB().profiles.Default.priorityColors.sanctuaryUseless, nil, "no separate useless sanctuary setting")
-- Colors-page reset uses the displayed profile name, including global modes.
equal(ns.CreateProfile("Color reset test"), true, "create custom reset target")
local expectedPalettes = {
    {"Default", ns.Defaults.priorityColors, ns.Defaults.effectColors},
    {"High Contrast", ns.Defaults.colorPresets.highContrast.priorityColors, ns.Defaults.colorPresets.highContrast.effectColors},
    {"Color reset test", ns.Defaults.priorityColors, ns.Defaults.effectColors},
}
for _, case in ipairs(expectedPalettes) do
    ns.SetActiveProfileName(case[1])
    for state in pairs(ns.Defaults.categoryModes) do
        ns.SetPriorityColor(state, 0.1, 0.2, 0.3)
        ns.SetCategoryMode(state, "inactive")
    end
    ns.SetEffectColor("interruptible", 0.2, 0.3, 0.4)
    ns.SetInterruptibleHighlightEnabled(true)
    ns.SetAppearanceSetting("nameSize", 30)
    ns.SetThreatEnabled(false)
    ns.SetStylingEnabled(false)
    ns.ResetAllColors()
    for state, expected in pairs(case[2]) do
        local r, g, b = ns.PriorityColorForState(state)
        equal(r, expected.r, case[1] .. " reset " .. state .. " red")
        equal(g, expected.g, case[1] .. " reset " .. state .. " green")
        equal(b, expected.b, case[1] .. " reset " .. state .. " blue")
        equal(ns.GetCategoryMode(state), "inactive", "Colors reset preserves legacy category modes")
    end
    local r, g, b = ns.EffectColor("interruptible")
    local expected = {r=0.2, g=0.3, b=0.4}
    equal(r, expected.r, case[1] .. " reset cast red")
    equal(g, expected.g, case[1] .. " reset cast green")
    equal(b, expected.b, case[1] .. " reset cast blue")
    equal(ns.GetInterruptibleHighlightEnabled(), true, "Colors reset preserves cast activation")
    equal(ns.GetAppearanceSetting("nameSize"), 30, "Colors reset preserves Appearance settings")
    equal(ns.GetThreatEnabled(), false, "Colors reset preserves threat display")
    equal(ns.GetStylingEnabled(), false, "Colors reset preserves addon activation")
    ns.ResetAppearance()
    ns.SetThreatEnabled(true)
    ns.SetStylingEnabled(true)
end
ns.SetActiveProfileName("Color reset test")
ns.DeleteActiveProfile()
equal(ns.SetActiveProfileName("High Contrast"), true, "select bundled")
equal(ns.GetActiveProfileName(), "High Contrast", "bundled selected")
equal(ns.PriorityColorForState("attacking"), 1, "contrast red component")
local _, green = ns.PriorityColorForState("attacking")
equal(green, 0, "contrast magenta green component")
character = "Player-Two"
equal(ns.GetActiveProfileName(), "Default", "other character untouched")
character = "Player-One"
equal(ns.GetActiveProfileName(), "High Contrast", "first character selection retained")

-- Profile lifecycle, independent copies, name validation, and reassignment.
equal(ns.CreateProfile("Test"), true, "create")
equal(ns.GetAppearanceSetting("nameSize"), 18, "create factory values")
ns.SetAppearanceSetting("nameSize", 17)
ns.SetPriorityColor("attacking", 0.1, 0.2, 0.3)
equal(ns.CopyActiveProfile("Copy"), true, "copy")
equal(ns.GetAppearanceSetting("nameSize"), 17, "copy settings")
equal(ns.PriorityColorForState("attacking"), 0.1, "copy color")
ns.SetPriorityColor("attacking", 0.7, 0.2, 0.3)
equal(ns.SetActiveProfileName("Test"), true, "switch original")
equal(ns.PriorityColorForState("attacking"), 0.1, "copy independent")
character = "Player-Two"
equal(ns.SetActiveProfileName("Test"), true, "second character selects original")
character = "Player-One"
equal(ns.RenameActiveProfile("Renamed"), true, "rename")
equal(db.profileKeys["Player-Two"], "Renamed", "rename all assignments")
equal(ns.DeleteActiveProfile(), true, "delete")
equal(db.profileKeys["Player-Two"], "Default", "delete reassigns second")
equal(ns.GetActiveProfileName(), "Default", "delete reassigns active")
equal(ns.DeleteActiveProfile(), false, "Default protected")
equal(ns.RenameActiveProfile("Anything"), false, "Default rename protected")
equal(ns.CreateProfile(" copy "), false, "case-insensitive duplicate")
ns.SetActiveProfileName("High Contrast")
ns.SetPriorityColor("attacking", 0.2, 0.2, 0.2)
ns.RestoreBundledProfiles()
local red, contrastGreen, blue = ns.PriorityColorForState("attacking")
equal(red, 1, "restore red")
equal(contrastGreen, 0, "restore green")
equal(blue, 1, "restore blue")

-- Valid version-2 values survive reload; malformed values fall back individually.
SimpleNameplatesDB = {
    schemaVersion = 2,
    global = {
        stylingEnabled = false, categoryModes = { friendly = "hide", hostile = "bad" },
        trp3 = { enabled = true, showOOC = "wrong" },
        managedNameCVarOriginals = {
            UnitNameFriendlyPlayerName = "original",
            InventedCVar = "discard",
        },
    },
    profiles = {
        Default = {
            appearance = { nameSize = 25, nameFont = "bad", namePlacement = "INSIDE" },
            priorityColors = { attacking = { r = 0.4, g = 0.2, b = 0.1 } },
            showThreat = false,
        },
        ["High Contrast"] = {},
    },
    profileKeys = { ["Player-One"] = "Missing" },
}
ns = loadCore()
db = ns.EnsureDB()
equal(ns.GetStylingEnabled(), true, "retired global activation discarded; character defaults enabled")
equal(ns.GetCategoryMode("friendly"), "active", "removed category mode discarded")
equal(ns.GetCategoryMode("hostile"), "active", "invalid category reset")
equal(ns.GetTRP3Enabled(), true, "valid TRP3 retained")
equal(ns.GetTRP3Setting("showOOC"), true, "invalid TRP3 reset")
equal(ns.GetAppearanceSetting("nameSize"), 25, "valid appearance retained")
equal(ns.GetAppearanceSetting("nameFont"), "FRIZQT", "invalid font reset")
equal(ns.GetAppearanceSetting("namePlacement"), "INSIDE", "valid placement retained")
equal(ns.GetThreatEnabled(), false, "valid profile toggle retained")
equal(ns.PriorityColorForState("attacking"), 0.4, "valid color retained")
equal(ns.GetActiveProfileName(), "Default", "invalid assignment reset")
equal(db.global.managedNameCVarOriginals.UnitNameFriendlyPlayerName, "original", "ledger retained")
equal(db.global.managedNameCVarOriginals.InventedCVar, nil, "unknown ledger entry dropped")
ns.SetCategoryMode("friendly", "inactive")
ns.SetCategoryMode("friendly", "hide")
equal(ns.GetCategoryMode("friendly"), "inactive", "removed category mode rejected by setter")
-- A schema marker does not discard valid fields; no legacy aliases are converted.
for _, marker in ipairs({ 999, false }) do
    SimpleNameplatesDB = {
        schemaVersion = marker,
        global = {
            stylingEnabled = false,
            hideBlizzardMinionNames = true,
            hideCritterCompanionNames = true,
            categoryModes = { hostile = "inactive", useless = "invalid" },
            legacyStylingEnabled = true,
        },
        profiles = {
            Default = { appearance = { nameSize = 25, nameFont = "invalid" } },
            Custom = { showThreat = false },
        },
        profileKeys = { ["Player-One"] = "Custom" },
        legacyAppearance = { nameSize = 30 },
    }
    ns = loadCore()
    db = ns.EnsureDB()
    equal(db.schemaVersion, 2, "current schema marker")
    equal(ns.GetStylingEnabled(), true, "retired global activation is not a character preference")
    equal(ns.GetCategoryMode("hostile"), "inactive", "valid mode retained")
    equal(ns.GetCategoryMode("useless"), "active", "invalid mode discarded")
    equal(db.profiles.Default.appearance.nameSize, 25, "valid appearance retained")
    equal(db.profiles.Default.appearance.nameFont, "FRIZQT", "invalid font discarded")
    equal(ns.GetActiveProfileName(), "Custom", "valid selection retained")
    equal(db.global.hideBlizzardMinionNames, nil, "removed setting discarded")
    equal(db.global.legacyStylingEnabled, nil, "unknown setting discarded")
    equal(db.legacyAppearance, nil, "legacy layout not converted")
    equal(ns.GetHideCritterCompanionNames(), true, "critter toggle retained")
end

-- Removed replacement setting is discarded, while valid originals restore.
ns = fresh()
db = ns.EnsureDB()
db.global.replaceBlizzardOverheadNames = true
db.global.managedNameCVarOriginals.UnitNameFriendlyPlayerName = "original"
db.global.managedNameCVarOriginals.nameplateShowFriendlyPlayers = "original-plates"
cvars.UnitNameFriendlyPlayerName, cvars.nameplateShowFriendlyPlayers = "0", "1"
ns = loadCore()
db = ns.EnsureDB()
equal(db.global.replaceBlizzardOverheadNames, nil, "removed preference discarded")
equal(ns.GetReplaceBlizzardOverheadNames, nil, "replacement getter removed")
equal(ns.SetReplaceBlizzardOverheadNames, nil, "replacement setter removed")
equal(ns.ApplyOverheadNameReplacement, nil, "replacement action removed")
ns.ApplyManagedNameSettings()
equal(cvars.UnitNameFriendlyPlayerName, "original", "world name original restored")
equal(cvars.nameplateShowFriendlyPlayers, "original-plates", "plate original restored")
equal(next(db.global.managedNameCVarOriginals), nil, "successful restore clears ledger")
local before = #writes
ns.ApplyManagedNameSettings()
for _, state in ipairs({"attacking", "hostile", "neutral", "friendly", "useful", "useless"}) do
    ns.SetCategoryMode(state, "inactive")
    ns.SetCategoryMode(state, "active")
end
equal(#writes, before, "replacement never recaptures or rewrites restored values")

-- Every former replacement CVar remains eligible for restoration only.
ns = fresh()
db = ns.EnsureDB()
for _, cvar in ipairs(ns.MANAGED_NAME_CVARS) do
    if cvar ~= "UnitNameNonCombatCreatureName" then
        db.global.managedNameCVarOriginals[cvar] = "original-" .. cvar
        cvars[cvar] = "modified"
    end
end
ns = loadCore()
db = ns.EnsureDB()
ns.ApplyManagedNameSettings()
for _, cvar in ipairs(ns.MANAGED_NAME_CVARS) do
    if cvar ~= "UnitNameNonCombatCreatureName" then
        equal(cvars[cvar], "original-" .. cvar, "restoration allowlist: " .. cvar)
    end
end
equal(next(db.global.managedNameCVarOriginals), nil, "all original entries restored")

-- Failed or silently rejected restoration retains its original for retry.
ns = fresh()
db = ns.EnsureDB()
db.global.managedNameCVarOriginals.UnitNameFriendlyPlayerName = "custom"
cvars.UnitNameFriendlyPlayerName = "0"
rejectedWrites.UnitNameFriendlyPlayerName = true
ns.ApplyManagedNameSettings()
equal(cvars.UnitNameFriendlyPlayerName, "0", "failed restore leaves current value")
equal(db.global.managedNameCVarOriginals.UnitNameFriendlyPlayerName, "custom", "failed restore retains original")
rejectedWrites.UnitNameFriendlyPlayerName = "silent"
ns.ApplyPendingManagedNameSettings()
equal(db.global.managedNameCVarOriginals.UnitNameFriendlyPlayerName, "custom", "silent failure retains original")
rejectedWrites.UnitNameFriendlyPlayerName = nil
ns.ApplyPendingManagedNameSettings()
equal(cvars.UnitNameFriendlyPlayerName, "custom", "restoration retries")
equal(db.global.managedNameCVarOriginals.UnitNameFriendlyPlayerName, nil, "successful retry clears original")

-- Removed-feature restoration works with styling disabled and defers in combat.
ns = fresh()
db = ns.EnsureDB()
ns.SetStylingEnabled(false)
db.global.managedNameCVarOriginals.nameplateShowOnlyNameForFriendlyPlayerUnits = "bar-original"
cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = "1"
inCombat = true
before = #writes
ns.ApplyManagedNameSettings()
equal(#writes, before, "combat defers restoration")
equal(db.global.managedNameCVarOriginals.nameplateShowOnlyNameForFriendlyPlayerUnits,
    "bar-original", "combat retains original")
inCombat = false
ns.ApplyPendingManagedNameSettings()
equal(cvars.nameplateShowOnlyNameForFriendlyPlayerUnits, "bar-original", "disabled styling restoration retries")
equal(next(db.global.managedNameCVarOriginals), nil, "deferred restore clears ledger")

-- Critter hiding remains independent and does not request minion replacements.
ns = fresh()
cvars.UnitNameFriendlyPetName = "pet-original"
cvars.UnitNameNonCombatCreatureName = "critter-original"
equal(ns.GetHideBlizzardMinionNames, nil, "minion getter removed")
equal(ns.SetHideBlizzardMinionNames, nil, "minion setter removed")
ns.SetHideCritterCompanionNames(true)
equal(cvars.UnitNameFriendlyPetName, "pet-original", "critter hide leaves pets alone")
equal(cvars.UnitNameNonCombatCreatureName, "0", "dedicated critter hide retained")
ns.SetHideCritterCompanionNames(false)
equal(cvars.UnitNameNonCombatCreatureName, "critter-original", "critter original restored")

-- Valid restoration records remain usable after an obsolete setting is discarded.
ns = fresh()
db = ns.EnsureDB()
db.global.hideBlizzardMinionNames = true
db.global.managedNameCVarOriginals.UnitNameFriendlyPetName = "pre-addon-pet"
cvars.UnitNameFriendlyPetName = "0"
ns = loadCore()
db = ns.EnsureDB()
equal(db.global.hideBlizzardMinionNames, nil, "obsolete minion toggle discarded")
ns.ApplyManagedNameSettings()
equal(cvars.UnitNameFriendlyPetName, "pre-addon-pet", "valid pet original restored")

-- Removed Hide values fall back for every category and old CVar claims restore.
ns = fresh()
db = ns.EnsureDB()
for state in pairs(db.global.categoryModes) do db.global.categoryModes[state] = "hide" end
db.global.managedNameCVarOriginals.UnitNameFriendlyPlayerName = "pre-hide-original"
cvars.UnitNameFriendlyPlayerName = "0"
ns = loadCore()
db = ns.EnsureDB()
for state in pairs(db.global.categoryModes) do
    equal(ns.GetCategoryMode(state), "active", "old hide resets: " .. state)
end
ns.ApplyManagedNameSettings()
equal(cvars.UnitNameFriendlyPlayerName, "pre-hide-original", "old category hide CVar restored")
equal(next(db.global.managedNameCVarOriginals), nil, "old category claims cleared")

-- Current category fields survive; obsolete category keys are discarded without conversion.
SimpleNameplatesDB = {
    schemaVersion = 999,
    global = {categoryModes = {
        attacking = "inactive", hostile = "active", neutral = "inactive", friendly = "active",
        useful = "inactive", useless = "active", friendlyPC = "inactive", unfriendlyPC = "inactive",
        unfriendlyNPC = "inactive", other = "inactive",
    }},
    profiles = {Default = {priorityColors = {
        attacking = {r = 0.1, g = 0.2, b = 0.3}, neutral = {r = 0.4, g = 0.5, b = 0.6},
        sanctuaryFriendly = {r = 0.1, g = 0.2, b = 0.3},
        sanctuaryUseful = {r = 0.2, g = 0.2, b = 0.2},
        sanctuaryUseless = {r = 0.3, g = 0.3, b = 0.3},
        useful = {r = 0.7, g = 0.8, b = 0.9}, friendlyPC = {r = 1, g = 0, b = 1},
        unfriendlyPC = {r = 1, g = 0, b = 1}, unfriendlyNPC = {r = 1, g = 0, b = 1},
        other = {r = 1, g = 0, b = 1},
    }, appearance = {nameSize = 19, matchSanctuaryFont = false}}},
}
ns = loadCore()
db = ns.EnsureDB()
equal(ns.GetCategoryMode("neutral"), "inactive", "valid new mode retained")
equal(ns.PriorityColorForState("neutral"), 0.4, "valid new color retained")
equal(ns.PriorityColorForState("useful"), 0.7, "useful color retained")
equal(ns.GetAppearanceSetting("nameSize"), 19, "unrelated appearance retained")
equal(ns.GetAppearanceSetting("matchSanctuaryFont"), false, "saved false matching choice retained")
for _, key in ipairs({"friendlyPC", "unfriendlyPC", "unfriendlyNPC", "other", "sanctuaryFriendly", "sanctuaryUseful", "sanctuaryUseless"}) do
    equal(db.global.categoryModes[key], nil, "obsolete mode discarded: " .. key)
    equal(db.profiles.Default.priorityColors[key], nil, "obsolete color discarded: " .. key)
end
equal(ns.PriorityColorForState("friendly"), 0, "old player color not converted")
equal(db.profiles.Default.priorityColors.sanctuaryFriendly, nil, "no separate sanctuary player color")
local categoryCount = 0
for _ in pairs(db.global.categoryModes) do categoryCount = categoryCount + 1 end
equal(categoryCount, 6, "exactly six current categories")

-- Class-color CVars must remain unchanged across category toggles and retries.
ns = fresh()
for _, cvar in ipairs(ns.FRIENDLY_COLOR_CVARS) do cvars[cvar] = "class-before" end
for _, state in ipairs({"hostile", "attacking", "friendly"}) do
    for _, mode in ipairs({"inactive", "active", "inactive", "active"}) do
        ns.SetCategoryMode(state, mode)
        ns.ApplyManagedNameSettings()
        ns.ApplyPendingManagedNameSettings()
    end
end
for _, cvar in ipairs(ns.FRIENDLY_COLOR_CVARS) do
    equal(cvars[cvar], "class-before", "category toggle preserves native class-color CVar")
end
equal(#writes, 0, "category toggles never rebuild plates through CVar writes")
equal(ns.DisableFriendlyClassColors, nil, "unsafe CVar writer removed")
equal(ns.RestoreFriendlyClassColors, nil, "unsafe CVar restorer removed")

-- All declared addon modules must exist, compile, and load in dependency order.
local toc = assert(io.open("RPSimpleNameplates/RPSimpleNameplates.toc", "r"))
local modules = {}
local function CompileXML(path)
    local file = assert(io.open("RPSimpleNameplates/" .. path, "r"))
    local text = file:read("*a")
    file:close()
    local directory = path:match("^(.*[/])") or ""
    for _, name in text:gmatch('<(%w+)%s+file%s*=%s*"([^"]+)"') do
        if name:match("%.xml$") then
            CompileXML(directory .. name)
        else
            assert(loadfile("RPSimpleNameplates/" .. directory .. name), name .. " must compile")
        end
    end
end
for line in toc:lines() do
    line = line:gsub("\\", "/") -- Native TOC paths may use Windows separators.
    if line:match("%.lua$") then
        modules[#modules + 1] = line
        assert(loadfile("RPSimpleNameplates/" .. line), line .. " must compile")
    elseif line:match("%.xml$") then
        modules[#modules + 1] = line
        CompileXML(line)
    end
end
toc:close()
equal(table.concat(modules, ","),
    "Libs/LibStub/LibStub.lua,Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua,Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua,Libs/DetailsFramework/load.xml,Defaults.lua,FontMedia.lua,Core.lua,Profiler.lua,PeriodicWork.lua,WorldContext.lua,ManagedNames.lua,NameplateSetup.lua,Database.lua,Themes.lua,TRP3.lua,EntityFacts.lua,NameplateClassification.lua,PresentationCapabilities.lua,PresentationRules.lua,FontRendering.lua,HealthGradient.lua,NameplateFrames.lua,NPCTitles.lua,NameplateText.lua,NameplateThreat.lua,CastHighlight.lua,NameplateRestoration.lua,NameplatePresentation.lua,Nameplates.lua,Diagnostics.lua,SettingsControls.lua,SettingsColorPicker.lua,SettingsWidgets.lua,SettingsAbout.lua,SettingsBehavior.lua,SettingsProfileDialogs.lua,SettingsThemes.lua,SettingsProfiles.lua,SettingsPreview.lua,SettingsAppearance.lua,SettingsHighlight.lua,SettingsColors.lua,SettingsTRP3.lua,Settings.lua",
    "TOC module order")

-- Removing the optional bundle persists until an explicit bundled restore.
for _, action in ipairs({"delete", "rename"}) do
    local lifecycle = fresh()
    lifecycle.SetActiveProfileName("High Contrast")
    lifecycle.SetAppearanceSetting("nameSize", 29)
    if action == "delete" then lifecycle.DeleteActiveProfile()
    else lifecycle.RenameActiveProfile("My contrast") end
    equal(lifecycle.GetProfile("High Contrast"), nil, "optional bundle removed")
    lifecycle = loadCore()
    equal(lifecycle.GetProfile("High Contrast"), nil, "optional bundle removal survives reload")
    if action == "rename" then
        equal(lifecycle.GetActiveProfileName(), "My contrast", "renamed bundle remains selected")
        equal(lifecycle.GetAppearanceSetting("nameSize"), 29, "renamed bundle values survive")
    end
    lifecycle.RestoreBundledProfiles()
    lifecycle = loadCore()
    assert(lifecycle.GetProfile("High Contrast"), "explicit restore recreates optional bundle")
    if action == "rename" then
        equal(lifecycle.GetAppearanceSetting("nameSize"), 29, "restoring bundles preserves renamed custom profile")
    end
end

-- Modern and legacy enable-state APIs have different argument orders.
do
    local savedAddOns, savedUnitName = C_AddOns, UnitName
    local savedEnableState = GetAddOnEnableState
    local savedDialogs, savedPopup = StaticPopupDialogs, StaticPopup_Show
    local shown, enableCalls = {}, 0
    local installed = {"EnabledPlate", "DisabledPlate", "LoadedPlate", "Blizzard_Plate", "RPSimpleNameplates"}
    UnitName = function(token) equal(token, "player", "enable-state character token"); return "Tester" end
    StaticPopupDialogs = {}
    StaticPopup_Show = function(_, text) shown[#shown + 1] = text end
    local function checkState(name, character)
        equal(character, "Tester", "enable-state character")
        assert(name == "EnabledPlate" or name == "DisabledPlate", "unexpected enable-state addon")
        enableCalls = enableCalls + 1
        return name == "EnabledPlate" and 2 or 0
    end
    C_AddOns = {
        GetAddOnMetadata = function() return "test" end,
        GetNumAddOns = function() return #installed end,
        GetAddOnInfo = function(index) return installed[index], installed[index] end,
        IsAddOnLoaded = function(name) return name == "LoadedPlate" end,
        GetAddOnEnableState = checkState,
    }
    GetAddOnEnableState = function() error("modern API must take precedence") end
    local conflictNS = {}
    assert(loadfile("RPSimpleNameplates/Core.lua"))("RPSimpleNameplates", conflictNS)
    conflictNS.ShowNameplateConflictWarning()
    equal(enableCalls, 2, "modern API checks only unloaded third-party plate addons")
    equal(shown[1], "EnabledPlate\nLoadedPlate", "modern warning excludes disabled/self/Blizzard addons")
    C_AddOns.GetAddOnEnableState = nil
    GetAddOnEnableState = function(character, name) return checkState(name, character) end
    conflictNS.ShowNameplateConflictWarning()
    equal(enableCalls, 4, "legacy enable-state path exercised")
    equal(shown[2], shown[1], "legacy warning matches modern warning")
    C_AddOns, UnitName, GetAddOnEnableState = savedAddOns, savedUnitName, savedEnableState
    StaticPopupDialogs, StaticPopup_Show = savedDialogs, savedPopup
end

-- Preserve both UnitFullName results when GUID-based identity is unavailable.
do
    local savedFullName = UnitFullName
    local fallback = fresh()
    character = nil
    local realm = "RealmA"
    UnitFullName = function() return "SameName", realm end
    assert(fallback.CreateProfile("Realm A profile"))
    equal(fallback.EnsureDB().profileKeys["SameName-RealmA"], "Realm A profile", "fallback retains realm")
    realm = "RealmB"
    equal(fallback.GetActiveProfileName(), "Default", "same name on another realm has independent selection")
    assert(fallback.CreateProfile("Realm B profile"))
    realm = "RealmA"
    equal(fallback.GetActiveProfileName(), "Realm A profile", "first realm selection retained")
    realm = "RealmB"
    equal(fallback.GetActiveProfileName(), "Realm B profile", "second realm selection retained")
    realm = nil
    equal(fallback.GetActiveProfileName(), "Default", "missing realm remains a separate fallback")
    equal(fallback.EnsureDB().profileKeys["SameName-Unknown"], "Default", "missing realm fallback preserved")
    character = "Player-Guid"
    equal(fallback.GetActiveProfileName(), "Default", "available GUID takes precedence")
    assert(fallback.CreateProfile("GUID profile"))
    realm = "RealmA"
    equal(fallback.GetActiveProfileName(), "GUID profile", "GUID identity independent of realm fallback")
    UnitFullName = nil
    character = nil
    equal(fallback.GetActiveProfileName(), "Default", "missing full-name API remains safe")
    UnitFullName = savedFullName
end

do
    local bars = fresh()
    equal(bars.GetAppearanceSetting("nameSize"), 18, "new default font size")
    for state in pairs(bars.Defaults.priorityColors) do
        equal(bars.GetHealthBarEnabled(state), state ~= "useless", "missing bar settings use category defaults")
        bars.SetHealthBarEnabled(state, false)
    end
    assert(bars.CopyActiveProfile("Bars copy"))
    equal(bars.GetHealthBarEnabled("friendly"), false, "copy retains bar preference")
    bars.ResetAppearance()
    equal(bars.GetHealthBarEnabled("friendly"), false, "appearance reset preserves bars")
    bars.ResetAllColors()
    equal(bars.GetHealthBarEnabled("friendly"), true, "colors reset restores bars")
    equal(bars.GetHealthBarEnabled("useless"), false, "colors reset disables background bars")
    bars.SetHealthBarEnabled("useless", true)
    bars = loadCore()
    equal(bars.GetHealthBarEnabled("useless"), true, "saved background bar On survives reload")
    bars.SetActiveProfileName("Default")
    equal(bars.GetHealthBarEnabled("friendly"), false, "other profile remains independent")
    local reloaded = loadCore()
    equal(reloaded.GetHealthBarEnabled("friendly"), false, "reload preserves false")
    reloaded.SetHealthBarEnabled("friendly", "bad")
    equal(reloaded.GetHealthBarEnabled("friendly"), false, "setter rejects invalid boolean")
end

do
    local gradients = fresh()
    equal(gradients.GetGradientOpacity(), 100, "Default opacity default")
    gradients.SetActiveProfileName("High Contrast")
    equal(gradients.GetGradientOpacity(), 0, "High Contrast opacity default")
    gradients.SetGradientOpacity(50)
    gradients.ResetAllColors()
    equal(gradients.GetGradientOpacity(), 0, "High Contrast reset")
    gradients.SetActiveProfileName("Default")
    gradients.SetGradientOpacity(37)
    assert(gradients.CopyActiveProfile("Gradient copy"))
    equal(gradients.GetGradientOpacity(), 37, "copy opacity")
    gradients.SetGradientOpacity(0)
    gradients.SetActiveProfileName("Default")
    equal(gradients.GetGradientOpacity(), 37, "copy independent")
    gradients.ResetAppearance()
    equal(gradients.GetGradientOpacity(), 37, "appearance reset preserves opacity")
    gradients = loadCore()
    equal(gradients.GetGradientOpacity(), 37, "reload preserves opacity")
    for _, value in ipairs({"bad", true, math.huge, 0/0}) do
        gradients.SetGradientOpacity(value)
        equal(gradients.GetGradientOpacity(), 37, "invalid setter ignored")
    end
    gradients.SetGradientOpacity(120)
    equal(gradients.GetGradientOpacity(), 100, "setter upper clamp")
    gradients.SetGradientOpacity(-2)
    equal(gradients.GetGradientOpacity(), 0, "setter lower clamp")
    gradients.SetGradientOpacity(37.6)
    equal(gradients.GetGradientOpacity(), 38, "whole-percent steps")
    gradients.ResetAllColors()
    equal(gradients.GetGradientOpacity(), 100, "Default reset")
    for _, value in ipairs({-1, 101, true, "bad", math.huge, 0/0}) do
        SimpleNameplatesDB.profiles.Default.gradientOpacity = value
        gradients = loadCore()
        equal(gradients.GetGradientOpacity(), 100, "invalid saved opacity defaults")
    end
    SimpleNameplatesDB.profiles.Default.gradientOpacity = nil
    SimpleNameplatesDB.profiles.Default.gradients = false
    gradients = loadCore()
    equal(gradients.GetGradientOpacity(), 100, "retired toggle not converted")
    equal(SimpleNameplatesDB.profiles.Default.gradients, nil, "retired toggle discarded")
    gradients.SetGradientOpacity(0)
    gradients = loadCore()
    equal(gradients.GetGradientOpacity(), 0, "zero survives reload")

end

do
    local placement = fresh()
    equal(placement.GetAppearanceSetting("namePlacement"), "INSIDE", "Default placement inside")
    placement.SetAppearanceSetting("namePlacement", "ABOVE")
    placement.ResetAppearance()
    equal(placement.GetAppearanceSetting("namePlacement"), "INSIDE", "Default reset inside")
    placement.SetActiveProfileName("High Contrast")
    equal(placement.GetAppearanceSetting("namePlacement"), "ABOVE", "High Contrast placement above")
    placement.SetAppearanceSetting("namePlacement", "INSIDE")
    placement.ResetAppearance()
    equal(placement.GetAppearanceSetting("namePlacement"), "ABOVE", "High Contrast reset above")
    SimpleNameplatesDB.profiles.Default.appearance.namePlacement = "bad"
    SimpleNameplatesDB.profiles["High Contrast"].appearance.namePlacement = nil
    placement = loadCore()
    equal(placement.GetAppearanceSetting("namePlacement"), "ABOVE", "missing High Contrast placement above")
    placement.SetActiveProfileName("Default")
    equal(placement.GetAppearanceSetting("namePlacement"), "INSIDE", "invalid Default placement inside")
    placement.SetAppearanceSetting("namePlacement", "ABOVE")
    assert(placement.CopyActiveProfile("Placement copy"))
    equal(placement.GetAppearanceSetting("namePlacement"), "ABOVE", "copy preserves placement")
    placement.SetActiveProfileName("High Contrast")
    placement.SetAppearanceSetting("namePlacement", "INSIDE")
    placement = loadCore()
    equal(placement.GetAppearanceSetting("namePlacement"), "INSIDE", "saved High Contrast inside preserved")
    placement.SetActiveProfileName("Default")
    equal(placement.GetAppearanceSetting("namePlacement"), "ABOVE", "saved Default above preserved")
end

print("Core behavior smoke: passed")



