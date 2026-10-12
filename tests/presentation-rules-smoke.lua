-- Uniform presentation across categories/contexts, with access exceptions.
-- Run: lua tests/presentation-rules-smoke.lua (or luatex --luaonly).
local ns = {}
assert(loadfile("RPSimpleNameplates/PresentationRules.lua"))("RPSimpleNameplates", ns)
local Resolve = ns.PresentationRules.Resolve
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local cap = {canAccess = true, hasHealthBar = true, hasCastBar = true}
for _, state in ipairs({"attacking", "hostile", "neutral", "friendly", "useful", "useless"}) do
    local out = Resolve({revision = 1, inCombat = false}, {}, state, cap, true, "active")

    equal(out.showHealthBar, true, "out of combat: " .. state)
    equal(out.showFullTitle, true, "title policy: " .. state)
    equal(out.showCastBar, true, "cast capability: " .. state)
    local combat = Resolve({revision = 2, inCombat = true}, {}, state, cap, true, "active")
    equal(combat.showHealthBar, true, "in combat: " .. state)
    equal(combat.nameOnly, false, "combat bar name: " .. state)
    equal(combat.showFullTitle, true, "combat title: " .. state)
    local missing = Resolve({inCombat = true}, {}, state, {canAccess = true}, true, "active")
    equal(missing.showHealthBar, false, "no bar support: " .. state)
    equal(missing.nameOnly, true, "missing bar uses colored name: " .. state)
    equal(missing.showFullTitle, true, "missing bar permits title: " .. state)
    equal(Resolve({inCombat = true}, {}, state, cap, true, "inactive").action, "style", "retired inactive mode ignored: " .. state)
end
local facts = {isPlayer = true, oppositeFaction = true, eligiblePvPOpponent = false}
local sanctuary = Resolve({sanctuary = true, inCombat = false}, facts, "friendly", cap, true, "active")
equal(sanctuary.ruleID, "uniform", "sanctuary rule")
equal(sanctuary.showHealthBar, true, "sanctuary uses available bar")
equal(sanctuary.colorState, "friendly", "opposite-faction color unchanged")
for _, case in ipairs({
    {facts = {isPlayer = true, oppositeFaction = false}, state = "friendly", color = "friendly"},
    {facts = {isNPC = true}, state = "useful", color = "useful"},
    {facts = {isNPC = true}, state = "useless", color = "useless"},
    {facts = {isPlayer = true}, state = "friendly", color = "friendly"},
    {facts = {playerControlled = true, isNPC = false}, state = "useless", color = "useless"},
    {facts = {isNPC = true, usefulNPC = true}, state = "hostile", color = "hostile"},
    {facts = {isPlayer = true, oppositeFaction = false}, state = "attacking", color = "attacking"},
    {facts = {isNPC = true}, state = "neutral", color = "neutral"},
}) do
    for _, inCombat in ipairs({false, true}) do
        equal(Resolve({sanctuary = true, inCombat = inCombat}, case.facts, case.state, cap, true, "active").colorState,
            case.color, "sanctuary color: " .. case.state)
    end
    equal(Resolve({sanctuary = false, inCombat = false}, case.facts, case.state, cap, true, "active").colorState,
        case.state, "outside sanctuary: " .. case.state)
end
equal(Resolve({sanctuary = true, inCombat = true}, facts, "friendly", cap, true, "active").showHealthBar,
    true, "sanctuary combat bar")
facts.eligiblePvPOpponent = true
local pvp = Resolve({sanctuary = false, inCombat = false}, facts, "hostile", cap, true, "active")
equal(pvp.ruleID, "uniform", "eligible opponent rule")
equal(pvp.showHealthBar, true, "eligible opponent bar")
facts.oppositeFaction = false
equal(Resolve({sanctuary = true, inCombat = false}, facts, "friendly", cap, true, "active").ruleID,
    "uniform", "same-faction rule independent")
equal(Resolve({inCombat = false}, {isNPC = true}, "useful", cap, true, "active").ruleID,
    "uniform", "NPC rule independent")
equal(Resolve({}, {}, "hostile", cap, true, "active").action, "style", "unknown combat does not prevent uniform layout")
equal(Resolve({inCombat = true}, {}, "hostile", cap, false, "active").action, "restore", "disabled")
equal(Resolve({inCombat = true}, {}, "hostile", {canAccess = false, status = "forbidden"}, true, "active").action,
    "skip", "forbidden")
local widget = Resolve({}, {widgetsOnly = true}, "friendly", cap, true, "active")
equal(widget.suppressText, true, "widget-only text suppressed")
equal(widget.showFullTitle, false, "widget-only title suppressed")
print("Presentation rules smoke: passed")

