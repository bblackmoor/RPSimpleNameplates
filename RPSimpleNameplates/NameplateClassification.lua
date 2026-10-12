-- Simple Nameplates: first matching priority, independent of presentation.
local _, ns = ...
local Collect = ns.EntityFacts.Collect

local function Classify(facts)
    if facts.attacking == true then return "attacking", "attacking your controlled unit" end
    if facts.eligiblePvPOpponent == true then return "hostile", "eligible PvP opponent" end
    if facts.aggressiveNPC == true then return "hostile", "aggressive NPC" end
    if facts.canAttackYou == true then return "neutral", "can attack you" end
    if facts.isPlayer == true then return "friendly", "player without higher priority" end
    if facts.usefulNPC == true then return "useful", "NPC interaction evidence" end
    return "useless", "remaining entity; unknown facts are not negative evidence"
end

local function StateForUnit(unit, context)
    local facts = Collect(unit, context)
    local state, rule = Classify(facts)
    return state, rule, facts
end

StateForUnit = ns.Profiler.Wrap("Classification", StateForUnit)

ns.NameplateClassification = {
    StateForUnit = StateForUnit, Classify = Classify,
    TargetsPlayerControlledUnit = ns.EntityFacts.TargetsPlayerControlledUnit,
}
