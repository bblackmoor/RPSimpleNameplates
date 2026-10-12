-- Readable NPC tooltip subtitles; no player data or visible tooltip scanning.
local secret = {}
local ns = {
    AccessibleValue = function(v) if v ~= secret then return v end end,
    AccessibleNumber = function(v) if type(v) == "number" then return v end end,
}
Enum = {TooltipDataLineType = {None = 0, UnitName = 2, UnitLevel = 47, QuestTitle = 17}}
assert(loadfile("RPSimpleNameplates/Profiler.lua"))("RPSimpleNameplates", ns)
assert(loadfile("RPSimpleNameplates/NPCTitles.lua"))("RPSimpleNameplates", ns)
local function tooltip(title)
    return {lines = {
        {type = 2, leftText = "Orin Straylight"},
        {type = 0, leftText = title},
        {type = 47, leftText = "Level 90"},
    }}
end
local function equal(a, b, label) assert(a == b, label) end
equal(ns.NPCTitles.Extract(tooltip("Voidforge Steward")), "<Voidforge Steward>", "NPC subtitle")
equal(ns.NPCTitles.Extract(tooltip("|cffffffff<Forgeron du Vide>|r")), "<Forgeron du Vide>", "localized colored subtitle")
equal(ns.NPCTitles.Extract(tooltip("")), nil, "empty title")
equal(ns.NPCTitles.Extract(tooltip(secret)), nil, "secret text")
equal(ns.NPCTitles.Extract(secret), nil, "secret tooltip")
equal(ns.NPCTitles.Extract(tooltip("|Ticon:16|t")), nil, "texture markup")
equal(ns.NPCTitles.Extract({lines = {{type = 2}, {type = 47, leftText = "Level 90"}}}), nil, "no title")
local data = tooltip("Quest text")
data.lines[2].type = 17
equal(ns.NPCTitles.Extract(data), nil, "quest is not a title")
data = tooltip("Status text")
data.lines[3].type = 0
equal(ns.NPCTitles.Extract(data), nil, "ambiguous layout")
data = tooltip("Title")
data.lines[2].rightText = "Other information"
equal(ns.NPCTitles.Extract(data), nil, "two-column line")
data = tooltip("Title")
data.lines[2] = setmetatable({}, {__index = function() error("restricted field") end})
equal(ns.NPCTitles.Extract(data), nil, "unreadable field")
local calls = 0
C_TooltipInfo = {GetUnit = function(unit)
    calls = calls + 1
    equal(unit, "nameplate1", "exact supplied token")
    return tooltip("Voidforge Steward")
end}
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), "<Voidforge Steward>", "API read")
equal(ns.NPCTitles.GetTitle("player", {isNPC = false}), nil, "player excluded")
equal(ns.NPCTitles.GetTitle("unknown", {}), nil, "unknown excluded")
equal(calls, 1, "no player or unknown tooltip reads")
local info = ns.NPCTitles.Inspect("nameplate1", {isNPC = true})
equal(calls, 2, "inspection reads tooltip once")
equal(info.title, "<Voidforge Steward>", "inspection title")
equal(info.reason, "title extracted", "successful extraction reason")
equal(#info.lines, 3, "snapshot ends at absent line")
equal(info.lines[2].lineType, 0, "subtitle type snapshot")
equal(info.lines[2].left, "Voidforge Steward", "subtitle text snapshot")
equal(info.lines[2].rightStatus, "absent", "missing right column explicit")
equal(info.truncated, false, "short snapshot not truncated")
data = tooltip("Quest text")
data.lines[2].type = 17
C_TooltipInfo.GetUnit = function() return data end
info = ns.NPCTitles.Inspect("nameplate1", {isNPC = true})
equal(info.reason, "layout rejected: line 2 type 17; expected 0", "layout rejection distinguished")
equal(info.lines[2].left, "Quest text", "rejected layout still readable")
equal(data.lines[2].type, 17, "inspection preserves source")
data = tooltip(secret)
C_TooltipInfo.GetUnit = function() return data end
info = ns.NPCTitles.Inspect("nameplate1", {isNPC = true})
equal(info.reason, "subtitle left text restricted", "restricted field distinguished")
equal(info.lines[2].leftStatus, "restricted", "restricted snapshot status")
equal(info.lines[2].left, nil, "restricted value omitted")
data = tooltip("Title")
for i = 4, 13 do data.lines[i] = {type = 0, leftText = "Extra"} end
C_TooltipInfo.GetUnit = function() return data end
info = ns.NPCTitles.Inspect("nameplate1", {isNPC = true})
equal(#info.lines, 12, "snapshot bounded")
equal(info.truncated, true, "extra lines reported")
C_TooltipInfo.GetUnit = function() return nil end
equal(ns.NPCTitles.Inspect("nameplate1", {isNPC = true}).reason, "no tooltip data returned", "missing data distinguished")
C_TooltipInfo.GetUnit = function() error("blocked") end
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), nil, "blocked API")
equal(ns.NPCTitles.Inspect("nameplate1", {isNPC = true}).reason, "tooltip API call failed", "failed API distinguished")
C_TooltipInfo = nil
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), nil, "missing API")
equal(ns.NPCTitles.Inspect("nameplate1", {isNPC = true}).reason, "tooltip API unavailable", "missing API distinguished")

-- The live target layout has a plain localized level line, not UnitLevel type.
UNIT_LEVEL_TEMPLATE = "Level %d"
UnitLevel = function() return 90 end
data = tooltip("Voidforge Steward")
data.lines[3].type = 0
equal(ns.NPCTitles.Extract(data, "target"), "<Voidforge Steward>", "plain level verified against unit")
UNIT_LEVEL_TEMPLATE = "Niveau %d"
data.lines[3].leftText = "Niveau 90"
equal(ns.NPCTitles.Extract(data, "target"), "<Voidforge Steward>", "localized plain level")
data.lines[3].leftText = "Niveau 89"
equal(ns.NPCTitles.Extract(data, "target"), nil, "wrong level rejected")
data.lines[3].leftText = "Quest status"
equal(ns.NPCTitles.Extract(data, "target"), nil, "generic status rejected")
UNIT_LEVEL_TEMPLATE = "Level %d"
data.lines[3].leftText = "Level 90"
local plateGUID = "Creature-Orin"
UnitGUID = function(token)
    if token == "nameplate1" then return plateGUID end
    if token == "target" then return "Creature-Orin" end
end
UnitIsUnit = function() return false end
UnitIsPlayer = function() return false end
UnitPlayerControlled = function() return false end
UnitIsInteractable = function(token) return token == "target" end
C_TooltipInfo = {GetUnit = function(token)
    if token == "target" then return data end
    return {lines = {{type = 2, leftText = "Orin Straylight"}, {type = 0, leftText = "Level 90"}}}
end}
local title, source, useful = ns.NPCTitles.GetTitle("nameplate1", {isNPC = true, interactable = false})
equal(title, "<Voidforge Steward>", "full target subtitle fills sparse plate tooltip")
equal(source, "target tooltip (verified GUID)", "GUID equality works despite false UnitIsUnit")
equal(useful, true, "verified interaction evidence carried")
UnitGUID = function(token) if token == "nameplate1" then return plateGUID end end
title, source, useful = ns.NPCTitles.GetTitle("nameplate1", {isNPC = true})
equal(title, "<Voidforge Steward>", "title retained after target changes")
equal(source, "cached verified GUID", "session cache source")
plateGUID = "Creature-Other"
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), nil, "reused token cannot inherit title")
plateGUID = secret
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), nil, "restricted identity cannot inherit title")
plateGUID = nil
UnitName = function(token)
    if token == "nameplate1" or token == "target" then return "Orin Straylight" end
end
-- Relearn the verified target title so the no-GUID plate can use the bounded
-- name fallback observed in the live client.
UnitGUID = function(token) if token == "target" then return "Creature-Orin" end end
ns.NPCTitles.GetTitle("target", {isNPC = true, interactable = true})
local fallbackTitle, fallbackSource = ns.NPCTitles.GetTitle("nameplate1", {isNPC = true})
equal(fallbackTitle, "<Voidforge Steward>", "no-GUID plate uses cached verified NPC name")
equal(fallbackSource, "cached NPC name (GUID unavailable)", "name fallback source reported")

-- A cold unmatched-GUID plate must discover the target's title without a
-- prior target GetTitle call or a debug command.
UnitName = function(token)
    if token == "nameplate1" or token == "target" then return "Cold Test Steward" end
end
UnitGUID = function(token)
    if token == "nameplate1" then return "Creature-Cold-Plate" end
    if token == "target" then return "Creature-Cold-Target" end
end
title, source, useful = ns.NPCTitles.GetTitle("nameplate1", {isNPC = true, interactable = false})
equal(title, "<Voidforge Steward>", "cold unmatched GUID learns matching-name target")
equal(source, "cached NPC name (GUID unmatched)", "unmatched GUID fallback source")
equal(useful, true, "name fallback carries observed interaction evidence")
data.lines[2].leftText = "Different Service"
ns.NPCTitles.GetTitle("target", {isNPC = true})
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), nil, "conflicting name titles block fallback")
-- Exact identity remains authoritative despite ambiguity in the name cache.
UnitGUID = function() return "Creature-Cold-Target" end
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), "<Different Service>", "GUID preferred over ambiguous name")

-- Prefer the GUID hyperlink and retain token reading when it cannot help.
UnitGUID = function() return "Creature-Hyperlink" end
UnitName = function() return "Hyperlink Test NPC" end
local linkCalls, unitCalls = 0, 0
C_TooltipInfo = {
    GetHyperlink = function(link)
        linkCalls = linkCalls + 1
        equal(link, "unit:Creature-Hyperlink", "readable unit GUID hyperlink")
        return tooltip("Hyperlink Service")
    end,
    GetUnit = function()
        unitCalls = unitCalls + 1
        return tooltip("Token Service")
    end,
}
title, source = ns.NPCTitles.GetTitle("nameplate1", {isNPC = true, interactable = true})
equal(title, "<Hyperlink Service>", "hyperlink title takes precedence")
equal(source, "GUID hyperlink tooltip", "hyperlink source explicit")
equal(unitCalls, 0, "successful hyperlink avoids token title read")
info = ns.NPCTitles.Inspect("nameplate1", {isNPC = true})
equal(info.hyperlink.title, "<Hyperlink Service>", "hyperlink diagnostic title")
equal(info.hyperlink.reason, "title extracted", "hyperlink diagnostic reason")
equal(info.title, "<Token Service>", "diagnostics retain independent token result")
C_TooltipInfo.GetHyperlink = function() error("blocked") end
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), "<Token Service>", "failed hyperlink falls back")
equal(ns.NPCTitles.Inspect("nameplate1", {isNPC = true}).hyperlink.reason,
    "hyperlink tooltip API call failed", "failed hyperlink diagnosed")
C_TooltipInfo.GetHyperlink = function() return {lines = {{type = 2}, {type = 47}}} end
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), "<Token Service>", "rejected hyperlink layout falls back")
issecretvalue = function(value) return value == secret end
C_TooltipInfo.GetHyperlink = function() return secret end
equal(ns.NPCTitles.GetTitle("nameplate1", {isNPC = true}), "<Token Service>", "restricted hyperlink data falls back")
equal(ns.NPCTitles.Inspect("nameplate1", {isNPC = true}).hyperlink.reason,
    "hyperlink tooltip data restricted", "restricted hyperlink diagnosed")
C_TooltipInfo.GetHyperlink = function() linkCalls = linkCalls + 1 end
local before = linkCalls
UnitGUID = function() return secret end
ns.NPCTitles.GetTitle("nameplate1", {isNPC = true})
equal(linkCalls, before, "restricted GUID never concatenated or queried")
ns.NPCTitles.GetTitle("player", {isNPC = false})
equal(linkCalls, before, "players excluded from hyperlink queries")
issecretvalue = nil
print("NPC titles smoke: passed")
