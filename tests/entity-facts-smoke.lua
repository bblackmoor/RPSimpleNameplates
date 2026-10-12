-- Entity observation, priority precedence, and unknown/secret handling.
-- Run: lua tests/entity-facts-smoke.lua (or luatex --luaonly).
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local secret = {}
function issecretvalue(value) return value == secret end
function canaccessvalue(value) return value ~= secret end
local data = {}
function UnitIsPlayer() return data.player end
function UnitPlayerControlled() return data.controlled end
function UnitIsOwnerOrControllerOfUnit(_, unit)
    if unit == "nameplate1target" then return data.targetOwned end
    return data.owned
end
function UnitIsUnit(_, target)
    if target == "player" then return data.targetPlayer end
    return data.targetPet
end
function UnitThreatSituation(who)
    if who == "player" then return data.playerThreat end
    return data.petThreat
end
function UnitCanAttack(who)
    if who == "player" then return data.canAttackThem end
    return data.canAttackYou
end
function UnitReaction() return data.reaction end
function UnitIsPVP() return data.pvp end
function UnitIsInteractable() return data.interactable end
function UnitFactionGroup(unit)
    assert(unit ~= "player", "entity collection must use cached player faction")
    return data.faction
end
function UnitGUID() return data.guid end
local ns = {}
for _, file in ipairs({"Core.lua", "Profiler.lua", "WorldContext.lua", "EntityFacts.lua", "NameplateClassification.lua"}) do
    assert(loadfile("RPSimpleNameplates/" .. file))("RPSimpleNameplates", ns)
end
local context = {revision = 7, sanctuary = false, playerFaction = "Alliance", warModeDesired = true}
local function sample(values)
    data = {
        player = false, controlled = false, owned = false, reaction = 5,
        canAttackYou = false, canAttackThem = false, pvp = false, interactable = false,
        targetOwned = false, targetPlayer = false, targetPet = false, playerThreat = 0, petThreat = 0,
    }
    for key, value in pairs(values) do data[key] = value end
    return ns.NameplateClassification.StateForUnit("nameplate1", context)
end
local cases = {
    {"aggressive NPC", {reaction = 3}, "hostile"},
    {"hostile vendor", {reaction = 3, interactable = true}, "hostile"},
    {"vendor attacking", {reaction = 3, interactable = true, playerThreat = 2}, "attacking"},
    {"neutral can attack you", {reaction = 4, canAttackYou = true}, "neutral"},
    {"neutral vendor", {reaction = 4, canAttackYou = true, interactable = true}, "neutral"},
    {"attackable only by you", {reaction = 4, canAttackThem = true}, "useless"},
    {"opposing eligible player", {player = true, faction = "Horde", canAttackThem = true}, "hostile"},
    {"one-way eligible opponent", {player = true, faction = "Horde", canAttackYou = true}, "hostile"},
    {"same-faction duel", {player = true, faction = "Alliance", canAttackThem = true}, "hostile"},
    {"enemy targeting your pet", {player = true, canAttackYou = true, targetPet = true}, "attacking"},
    {"friendly player looking at you", {player = true, targetPlayer = true}, "friendly"},
    {"friendly NPC looking at you", {targetPlayer = true}, "useless"},
    {"attacking pet", {controlled = true, canAttackYou = true, targetOwned = true}, "attacking"},
    {"eligible enemy minion", {controlled = true, canAttackYou = true}, "hostile"},
    {"friendly minion", {controlled = true, interactable = true}, "useless"},
    {"owned guardian", {owned = true, interactable = true}, "useless"},
    {"useful NPC", {interactable = true}, "useful"},
    {"unmatched NPC", {}, "useless"},
    {"restricted interaction", {interactable = secret}, "useless"},
    {"PvP flag alone", {player = true, pvp = true, canAttackYou = secret, canAttackThem = secret}, "friendly"},
}
for _, case in ipairs(cases) do equal(sample(case[2]), case[3], case[1]) end
context.sanctuary = true
local state, rule, facts = sample({player = true, faction = "Horde", pvp = true, targetPlayer = true})
equal(state, "friendly", "sanctuary player")
equal(facts.oppositeFaction, true, "faction fact retained independently")
equal(facts.eligiblePvPOpponent, false, "flag not eligibility")
equal(facts.attacking, false, "looking not attacking")
equal(facts.contextRevision, 7, "explicit context used")
equal(sample({player = true, canAttackThem = true}), "hostile", "actual permission outranks context expectation")
local _, _, unknown = sample({canAttackYou = secret, canAttackThem = secret, interactable = secret,
    reaction = secret, player = secret, controlled = secret, owned = secret,
    targetPlayer = secret, targetPet = secret, targetOwned = secret,
    playerThreat = secret, petThreat = secret, faction = secret, guid = secret})
for _, key in ipairs({"isPlayer", "playerControlled", "reaction", "faction", "guid",
    "canAttackYou", "canAttackThem", "interactable", "attacking", "usefulNPC"}) do
    equal(unknown[key], nil, "secret preserved as unknown: " .. key)
end
UnitIsInteractable = function() error("API unavailable") end
equal(sample({}), "useless", "failed interaction API handled")
local _, _, failed = sample({})
equal(failed.interactable, nil, "failed interaction unknown")
UnitIsInteractable = nil
equal(sample({}), "useless", "missing interaction API handled")

-- Classification accepts facts directly; no game APIs are queried here.
local classify = ns.NameplateClassification.Classify
equal(classify({attacking = true, eligiblePvPOpponent = true, aggressiveNPC = true,
    canAttackYou = true, isPlayer = true, usefulNPC = true}), "attacking", "highest priority")
equal(classify({eligiblePvPOpponent = true, canAttackYou = true, isPlayer = true}), "hostile", "PvP override")
equal(classify({canAttackYou = true, isPlayer = true, usefulNPC = true}), "neutral", "neutral override")
equal(classify({isPlayer = true, usefulNPC = true}), "friendly", "player override")
equal(classify({usefulNPC = true}), "useful", "useful")
equal(classify({}), "useless", "unknown fallback")
print("Entity facts and classification smoke: passed")
