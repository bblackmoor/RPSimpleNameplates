-- Simple Nameplates: readable entity observations, independent of category/style.
local _, ns = ...
local Value, Boolean, Number = ns.AccessibleValue, ns.AccessibleBoolean, ns.AccessibleNumber
local GetContext = ns.WorldContext.Get

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Value(value) end
end

-- Tri-state OR: false only when every input is known false.
local function Either(a, b)
    if a == true or b == true then return true end
    if a == false and b == false then return false end
end

local function TargetsPlayerControlledUnit(unit)
    local target = unit .. "target"
    local direct = Either(Boolean(Read(UnitIsUnit, target, "player")),
        Boolean(Read(UnitIsUnit, target, "pet")))
    return Either(direct, Boolean(Read(UnitIsOwnerOrControllerOfUnit, "player", target)))
end

local function ThreatOn(who, unit)
    local value = Number(Read(UnitThreatSituation, who, unit))
    if value ~= nil then return value >= 2, value end
end

local function Collect(unit, context)
    context = context or GetContext()
    local player = Boolean(Read(UnitIsPlayer, unit))
    local controlled = Either(player, Boolean(Read(UnitPlayerControlled, unit)))
    local owned = Boolean(Read(UnitIsOwnerOrControllerOfUnit, "player", unit))
    if owned == true then controlled = true end
    local reaction = Number(Read(UnitReaction, unit, "player"))
    local canAttackYou = Boolean(Read(UnitCanAttack, unit, "player"))
    local canAttackThem = Boolean(Read(UnitCanAttack, "player", unit))
    local unitFaction = Read(UnitFactionGroup, unit)
    if type(unitFaction) ~= "string" then unitFaction = nil end
    local guid = Read(UnitGUID, unit)
    if type(guid) ~= "string" then guid = nil end
    local facts = {
        unit = unit, guid = guid, contextRevision = context.revision,
        isPlayer = player, playerControlled = controlled, ownedByPlayer = owned,
        reaction = reaction, faction = unitFaction, playerFaction = context.playerFaction,
        canAttackYou = canAttackYou, canAttackThem = canAttackThem,
        pvpFlagged = Boolean(Read(UnitIsPVP, unit)),
        interactable = Boolean(Read(UnitIsInteractable, unit)),
        widgetsOnly = Boolean(Read(UnitNameplateShowsWidgetsOnly, unit)),
        targetsYourControlledUnit = TargetsPlayerControlledUnit(unit),
    }
    if unitFaction and context.playerFaction then
        facts.oppositeFaction = unitFaction ~= context.playerFaction
    end
    if player == false and controlled == false then facts.isNPC = true
    elseif controlled == true then facts.isNPC = false end
    if facts.isNPC == true and reaction ~= nil then
        facts.aggressiveNPC = reaction <= 3
    elseif facts.isNPC == false then facts.aggressiveNPC = false end
    local combatAvailable = Either(canAttackYou, canAttackThem)
    if controlled == true then
        -- Actual readable permissions outrank contextual expectations (e.g. duels).
        -- A PvP flag, faction, or desired War Mode alone never proves eligibility.
        facts.eligiblePvPOpponent = combatAvailable
        if combatAvailable ~= true and context.sanctuary == true then
            facts.eligiblePvPOpponent = false
        end
    elseif controlled == false then facts.eligiblePvPOpponent = false end
    local aggroPlayer, playerThreat = ThreatOn("player", unit)
    local aggroPet, petThreat = ThreatOn("pet", unit)
    facts.playerThreat, facts.petThreat = playerThreat, petThreat
    facts.aggroOnYourControlledUnit = Either(aggroPlayer, aggroPet)
    local targetAttack
    local dangerous = Either(canAttackYou, Either(facts.aggressiveNPC, facts.eligiblePvPOpponent))
    if facts.targetsYourControlledUnit == false or dangerous == false then targetAttack = false
    elseif facts.targetsYourControlledUnit == true and dangerous == true then targetAttack = true end
    facts.attacking = Either(facts.aggroOnYourControlledUnit, targetAttack)
    -- Friendliness and overhead color are not evidence of useful interaction.
    if facts.isNPC == true then
        local titleUseful
        if ns.NPCTitles then
            facts.npcTitle, facts.npcTitleSource, titleUseful = ns.NPCTitles.GetTitle(unit, facts)
        end
        -- A subtitle alone does not prove a service. Carry affirmative
        -- interaction evidence only from the same verified NPC.
        facts.usefulNPC = titleUseful == true or facts.interactable
    elseif facts.isNPC == false then facts.usefulNPC = false end
    return facts
end

ns.EntityFacts = {
    Collect = Collect, TargetsPlayerControlledUnit = TargetsPlayerControlledUnit,
}
