-- Simple Nameplates: targeted-unit relationship and presentation diagnostics.
local _, ns = ...
local UnitExists, UnitName = UnitExists, UnitName
local AccessibleBoolean, AccessibleValue = ns.AccessibleBoolean, ns.AccessibleValue
local StateForUnit = ns.NameplateClassification.StateForUnit
local Resolve = ns.PresentationRules.Resolve
local Capabilities = ns.PresentationCapabilities
local GetContext = ns.WorldContext.Get
local GetStylingEnabled = ns.GetStylingEnabled
local PriorityColorForState = ns.PriorityColorForState
local GetInterruptibleHighlightEnabled = ns.GetInterruptibleHighlightEnabled

local function DebugBoolean(value)
    value = AccessibleBoolean(value)
    if value == nil then return "restricted/unavailable" end
    return value and "yes" or "no"
end

local function DebugValue(value)
    value = AccessibleValue(value)
    return value == nil and "restricted/unavailable" or tostring(value)
end

local function DebugRegionValue(region, methodName, valueType, context)
    if not region then return "not found" end
    local value = Capabilities.ReadRegion(region, methodName, context)
    if valueType == "boolean" then return DebugBoolean(value) end
    return DebugValue(value)
end

local function ReadUnitAPI(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return AccessibleValue(value) end
end

local function SameUnit(candidate, unit)
    if type(candidate) ~= "string" then return nil end
    local same = AccessibleBoolean(ReadUnitAPI(UnitIsUnit, candidate, unit))
    if same ~= nil then return same end
    -- Never use displayed names for identity; readable GUIDs are a fallback.
    local a, b = ReadUnitAPI(UnitGUID, candidate), ReadUnitAPI(UnitGUID, unit)
    if type(a) == "string" and a ~= "" and type(b) == "string" and b ~= "" then
        return a == b
    end
end

local function FindDiagnosticPlates(unit, context)
    local matches, seen, candidates = {}, {}, {}
    local candidateSeen = {}
    local targetName = ReadUnitAPI(UnitName, unit)
    local direct = Capabilities.InspectUnit(unit, context)
    if direct.frame then
        matches[#matches + 1] = {assessment = direct, source = "direct lookup"}
        seen[direct.frame] = true
    end
    local plates = ReadUnitAPI(C_NamePlate and C_NamePlate.GetNamePlates)
    local scanned, unknown = 0, 0
    if type(plates) == "table" then
        for _, plate in pairs(plates) do
            scanned = scanned + 1
            local frame = Capabilities.SafeField(plate, "UnitFrame", context)
            local token = Capabilities.SafeField(frame, "unit", context)
            local same = SameUnit(token, unit)
            local unitName = type(token) == "string" and ReadUnitAPI(UnitName, token) or nil
            -- Name equality selects diagnostic candidates only, never unit identity.
            local nameMatch = type(targetName) == "string" and targetName ~= ""
                and type(unitName) == "string" and unitName == targetName
            local assessment
            if frame and not candidateSeen[frame]
                and (same == true or nameMatch or frame == direct.frame) then
                assessment = Capabilities.InspectFrame(frame, context)
                candidates[#candidates + 1] = {assessment = assessment, token = token,
                    unitName = unitName, nameMatch = nameMatch, targetMatch = same,
                    plateStatus = Capabilities.ObjectStatus(plate, context),
                    plateShown = Capabilities.ReadRegion(plate, "IsShown", context),
                    plateVisible = Capabilities.ReadRegion(plate, "IsVisible", context)}
                candidateSeen[frame] = true
            end
            if same == true and not seen[frame] then
                matches[#matches + 1] = {assessment = assessment or Capabilities.InspectFrame(frame, context),
                    source = "enumerated unit match", token = token}
                seen[frame] = true
            elseif same == nil then unknown = unknown + 1 end
        end
    end
    return matches, direct, scanned, unknown, type(plates) == "table", candidates
end

local function DebugAddonText(assessment, context)
    local frame = assessment.frame
    local function Field(object, key) return Capabilities.SafeField(object, key, context) end
    local cached = Field(frame, "SNPNameStyle")
    local decision = Field(frame, "SNPPresentation")
    print("  Simple Nameplates markers: state " .. DebugValue(Field(frame, "SNPState"))
        .. "; frame unit: " .. DebugValue(Field(frame, "unit"))
        .. "; original unit: " .. DebugValue(Field(frame, "SNPOriginalUnit"))
        .. "; restoring: " .. (assessment.canAccess and (Field(frame, "SNPRestoring") and "yes" or "no")
            or "restricted/unavailable"))
    print("  Last restoration error: " .. (Field(frame, "SNPRestoreError") or "(none)"))
    print("  Threat display: enabled " .. (ns.GetThreatEnabled() and "yes" or "no")
        .. "; status: " .. (Field(frame, "SNPThreatStatus") or "(none)")
        .. "; shown: " .. DebugRegionValue(Field(frame, "SNPThreatText"), "IsShown", "boolean", context))
    print("  Cached name style: " .. (cached and "found" or "not found")
        .. "; text: " .. DebugValue(Field(cached, "text"))
        .. "; name-only: " .. DebugBoolean(Field(cached, "nameOnly"))
        .. "; inside bar: " .. DebugBoolean(Field(cached, "inside")))
    print("  Cached presentation: action " .. DebugValue(Field(decision, "action"))
        .. "; color: " .. DebugValue(Field(decision, "colorState"))
        .. "; revision: " .. DebugValue(Field(decision, "contextRevision"))
        .. "; current revision: " .. context.revision)
    for _, key in ipairs({"SNPInsideName", "SNPFullTitleText"}) do
        local region = Field(frame, key)
        print("  " .. key .. ": " .. (region and "found" or "not found")
            .. "; text: " .. DebugRegionValue(region, "GetText", nil, context)
            .. "; shown: " .. DebugRegionValue(region, "IsShown", "boolean", context)
            .. "; visible: " .. DebugRegionValue(region, "IsVisible", "boolean", context)
            .. "; alpha: " .. DebugRegionValue(region, "GetAlpha", nil, context)
            .. "; effective alpha: " .. DebugRegionValue(region, "GetEffectiveAlpha", nil, context))
    end
end

local function DebugContext(context)
    print("|cff0cd29fSimple Nameplates context:|r revision " .. context.revision
        .. "; initialized: " .. DebugBoolean(context.initialized))
    print("  Zone: " .. DebugValue(context.zone) .. "; subzone: " .. DebugValue(context.subzone)
        .. "; map: " .. DebugValue(context.mapID) .. "; territory: " .. DebugValue(context.territory)
        .. "; sanctuary: " .. DebugBoolean(context.sanctuary)
        .. "; territory faction: " .. DebugValue(context.territoryFaction)
        .. "; subzone PvP: " .. DebugBoolean(context.subzonePvP))
    print("  Instance: " .. DebugBoolean(context.inInstance) .. "; type: " .. DebugValue(context.instanceType)
        .. "; name: " .. DebugValue(context.instanceName) .. "; player faction: " .. DebugValue(context.playerFaction))
    print("  War Mode desired: " .. DebugBoolean(context.warModeDesired)
        .. "; active: " .. DebugBoolean(context.warModeActive)
        .. "; player PvP: " .. DebugBoolean(context.playerPvP)
        .. "; free-for-all: " .. DebugBoolean(context.freeForAll)
        .. "; player combat: " .. DebugBoolean(context.inCombat)
        .. "; combat lockdown: " .. DebugBoolean(context.combatLockdown))
    local getter = C_CVar and C_CVar.GetCVar or GetCVar
    print("  Friendly NPC nameplates: nameplateShowFriendlyNpcs="
        .. DebugValue(ReadUnitAPI(getter, "nameplateShowFriendlyNpcs")))
end

local function DebugClassification(state, rule, assessment, context, facts)
    local hasNameplate = assessment.canAccess
    local decision = Resolve(context, facts, state, assessment, GetStylingEnabled(), ns.GetHealthBarEnabled(state))
    local enabled = GetStylingEnabled()
    local display, colorHex
    if not hasNameplate then
        display, colorHex = "no accessible nameplate; world-name display unknown", "unavailable"
    elseif decision.action == "restore" then
        display, colorHex = "Blizzard presentation", "Blizzard-controlled"
    else
        local r, g, b = PriorityColorForState(decision.colorState)
        colorHex = string.format("#%02X%02X%02X", math.floor(r * 255 + 0.5),
            math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
        display = decision.nameOnly and "colored name only" or "white name with colored health bar"
    end
    print("  Styling enabled: " .. (enabled and "yes" or "no")
        .. "; detected state: " .. state .. "; winning rule: " .. rule .. "; Health Bar: " .. DebugBoolean(ns.GetHealthBarEnabled(state))
        .. "; configured display: " .. display .. "; configured color: " .. colorHex)
    print("  Presentation rule: " .. decision.ruleID .. "; action: " .. decision.action
        .. "; reason: " .. decision.reason .. "; health bar requested: " .. DebugBoolean(decision.showHealthBar)
        .. "; full title permitted: " .. DebugBoolean(decision.showFullTitle))
end

local function DebugUnitRelationships(facts)
    print("  Player: " .. DebugBoolean(facts.isPlayer)
        .. "; player-controlled: " .. DebugBoolean(facts.playerControlled)
        .. "; owned/controlled by you: " .. DebugBoolean(facts.ownedByPlayer)
        .. "; NPC: " .. DebugBoolean(facts.isNPC))
    print("  Reaction: " .. DebugValue(facts.reaction)
        .. "; faction: " .. DebugValue(facts.faction)
        .. "; opposite faction: " .. DebugBoolean(facts.oppositeFaction)
        .. "; you can attack: " .. DebugBoolean(facts.canAttackThem)
        .. "; it can attack you: " .. DebugBoolean(facts.canAttackYou)
        .. "; PvP flagged: " .. DebugBoolean(facts.pvpFlagged)
        .. "; eligible PvP opponent: " .. DebugBoolean(facts.eligiblePvPOpponent))
    print("  Threat on you: " .. DebugValue(facts.playerThreat)
        .. "; threat on pet: " .. DebugValue(facts.petThreat)
        .. "; targeting your controlled unit: " .. DebugBoolean(facts.targetsYourControlledUnit)
        .. "; attacking: " .. DebugBoolean(facts.attacking))
    print("  Aggressive NPC: " .. DebugBoolean(facts.aggressiveNPC)
        .. "; interactable: " .. DebugBoolean(facts.interactable)
        .. "; useful NPC: " .. DebugBoolean(facts.usefulNPC)
        .. "; facts context revision: " .. DebugValue(facts.contextRevision))
end

local function DebugNameRegion(assessment, context)
    local nameRegion = assessment.canAccess and assessment.name or nil
    local nameParent = Capabilities.ReadRegion(nameRegion, "GetParent", context)
    print("  Name region: " .. (nameRegion and "found" or "not found")
        .. "; text: " .. DebugRegionValue(nameRegion, "GetText", nil, context)
        .. "; shown: " .. DebugRegionValue(nameRegion, "IsShown", "boolean", context)
        .. "; visible: " .. DebugRegionValue(nameRegion, "IsVisible", "boolean", context)
        .. "; alpha: " .. DebugRegionValue(nameRegion, "GetAlpha", nil, context))
    print("  Name parent shown: " .. DebugRegionValue(nameParent, "IsShown", "boolean", context)
        .. "; visible: " .. DebugRegionValue(nameParent, "IsVisible", "boolean", context))
end

local function DebugPresentation(assessment, context)
    print("  Presentation access: " .. assessment.status .. "; blocked region: " .. (assessment.reason or "(none)")
        .. "; name: " .. DebugBoolean(assessment.hasName)
        .. "; health bar: " .. DebugBoolean(assessment.hasHealthBar)
        .. "; cast bar: " .. DebugBoolean(assessment.hasCastBar))
    local bar = assessment.canAccess and assessment.healthBar or nil
    print("  Health bar shown: " .. DebugRegionValue(bar, "IsShown", "boolean", context)
        .. "; visible: " .. DebugRegionValue(bar, "IsVisible", "boolean", context))
    local castBar = assessment.canAccess and assessment.castBar or nil
    local icon = Capabilities.SafeField(castBar, "Icon", context)
    local highlight = Capabilities.SafeField(assessment.frame, "SNPInterruptibleHighlight", context)
    local overlay = Capabilities.SafeField(highlight, "frame", context)
    local hookedIcons = Capabilities.SafeField(highlight, "hookedIcons", context)
    local hookInstalled = icon and AccessibleBoolean(Capabilities.SafeField(hookedIcons, icon, context)) == true
    print("  Interruptible highlight: enabled "
        .. (GetInterruptibleHighlightEnabled() and "yes" or "no")
        .. "; cast icon found " .. (icon and "yes" or "no")
        .. "; hook installed " .. (hookInstalled and "yes" or "no")
        .. "; effect " .. (ns.GetInterruptibleEffect and ns.GetInterruptibleEffect() or "PULSE")
        .. "; resolved interruptible " .. DebugBoolean(Capabilities.SafeField(highlight, "interruptibleState", context))
        .. "; source " .. DebugValue(Capabilities.SafeField(highlight, "interruptibleSource", context))
        .. "; renderer " .. DebugValue(Capabilities.SafeField(highlight, "activeEffect", context))
        .. "; renderer error " .. (Capabilities.SafeField(highlight, "rendererError", context) or "(none)")
        .. "; highlight shown " .. DebugRegionValue(overlay, "IsShown", "boolean", context))
end

local function TooltipField(value, status)
    if status ~= "readable" then return "[" .. status .. "]" end
    if type(value) == "string" then
        return value:gsub("|", "||"):gsub("\n", " "):gsub("\r", " ")
    end
    if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
    return "[non-text value]"
end

local function DebugNPCTooltip(unit, facts)
    print("  Plate kind [" .. unit .. "]: softinteract match: "
        .. DebugBoolean(ReadUnitAPI(UnitIsUnit, unit, "softinteract"))
        .. "; widgets only: " .. DebugBoolean(ReadUnitAPI(UnitNameplateShowsWidgetsOnly, unit)))
    if facts.isNPC == true then
        print("  Resolved NPC title: " .. (facts.npcTitle or "(none)")
            .. "; source: " .. (facts.npcTitleSource or "unavailable"))
    end
    local info = ns.NPCTitles.Inspect(unit, facts)
    if facts.isNPC == true then
        print("  NPC hyperlink [" .. unit .. "]: title " .. (info.hyperlink.title or "(none)")
            .. "; result: " .. info.hyperlink.reason)
    end
    print("  NPC tooltip [" .. unit .. "]: title " .. (info.title or "(none)")
        .. "; result: " .. info.reason)
    for _, row in ipairs(info.lines) do
        print("  Tooltip line " .. row.index .. ": access " .. row.status
            .. "; type " .. TooltipField(row.lineType, row.typeStatus)
            .. "; left: " .. TooltipField(row.left, row.leftStatus)
            .. "; right: " .. TooltipField(row.right, row.rightStatus))
    end
    if info.truncated then print("  Tooltip lines truncated after 12.") end
end

local function DebugScannedPlates(candidates, context)
    for index, candidate in ipairs(candidates) do
        local assessment, token = candidate.assessment, candidate.token
        print("  Relevant nameplate " .. index .. ": token " .. DebugValue(token)
            .. "; unit name: " .. DebugValue(candidate.unitName)
            .. "; matches inspected unit: " .. DebugBoolean(candidate.targetMatch)
            .. "; same name: " .. DebugBoolean(candidate.nameMatch))
        if type(token) == "string" then
            local _, _, facts = StateForUnit(token, context)
            DebugNPCTooltip(token, facts)
        end
        print("  Base plate access: " .. candidate.plateStatus
            .. "; shown: " .. DebugBoolean(candidate.plateShown)
            .. "; visible: " .. DebugBoolean(candidate.plateVisible)
            .. "; unit frame access: " .. assessment.status
            .. "; blocked region: " .. (assessment.reason or "(none)"))
        print("  Unit frame shown: " .. DebugRegionValue(assessment.frame, "IsShown", "boolean", context)
            .. "; visible: " .. DebugRegionValue(assessment.frame, "IsVisible", "boolean", context))
        DebugNameRegion(assessment, context)
        DebugPresentation(assessment, context)
        DebugAddonText(assessment, context)
    end
end

local function DebugUnit(unit, context)
    context = context or GetContext()
    DebugContext(context)
    if AccessibleBoolean(ReadUnitAPI(UnitExists, unit)) ~= true then
        local message = unit == "mouseover" and "No mouseover unit available." or "No target selected."
        print("|cff0cd29fSimple Nameplates:|r " .. message)
        return
    end

    local name = DebugValue(ReadUnitAPI(UnitName, unit))
    local state, rule, facts = StateForUnit(unit, context)
    local matches, direct, scanned, unknown, enumerationAvailable, candidates = FindDiagnosticPlates(unit, context)
    local assessment = matches[1] and matches[1].assessment or direct
    print("|cff0cd29fSimple Nameplates debug [" .. unit .. "]:|r " .. name)
    print("  Nameplate lookup: direct " .. direct.status .. "; enumeration available: "
        .. DebugBoolean(enumerationAvailable) .. "; scanned: " .. scanned
        .. "; matching frames: " .. #matches .. "; identity unavailable: " .. unknown
        .. "; unique relevant frames: " .. #candidates)
    print("  Plate details limited to inspected-unit identity, direct lookup, or same readable name; unrelated plates omitted.")
    DebugClassification(state, rule, assessment, context, facts)
    DebugUnitRelationships(facts)
    DebugNPCTooltip(unit, facts)
    if #matches == 0 then
        DebugNameRegion(assessment, context)
        DebugPresentation(assessment, context)
        print("  No matching nameplate identified; world-name source remains unknown.")
    else
        for index, match in ipairs(matches) do
            print("  Matching nameplate " .. index .. ": " .. match.source
                .. "; token: " .. DebugValue(match.token
                    or Capabilities.SafeField(match.assessment.frame, "unit", context)))
            local enumerated = false
            for _, candidate in ipairs(candidates) do
                if candidate.assessment.frame == match.assessment.frame then enumerated = true; break end
            end
            -- Enumerated relevant frames are detailed once below.
            if not enumerated then
                DebugNameRegion(match.assessment, context)
                DebugPresentation(match.assessment, context)
                DebugAddonText(match.assessment, context)
            end
        end
    end
    DebugScannedPlates(candidates, context)
end

-- Inspect enumeration directly: direct unit lookups, classification and tooltip
-- collection can invoke native callbacks or change caches. Keep the failed
-- presentation intact so targeting/mouseover cannot mask the cause.
local function DebugNearby(filter)
    local context = GetContext()
    DebugContext(context)
    filter = type(filter) == "string" and string.lower(filter) or ""
    print("|cff0cd29fSimple Nameplates nearby snapshot:|r filter " .. (filter ~= "" and filter or "(all)")
        .. "; addon version " .. (ns.VERSION or "unknown"))
    local plates = ReadUnitAPI(C_NamePlate and C_NamePlate.GetNamePlates)
    if type(plates) ~= "table" then
        print("  Nameplate enumeration unavailable.")
        return
    end
    local seen, count = {}, 0
    for _, plate in pairs(plates) do
        if not seen[plate] then
            seen[plate] = true
            local frame = Capabilities.SafeField(plate, "UnitFrame", context)
            local token = Capabilities.SafeField(frame, "unit", context)
            local name = type(token) == "string" and ReadUnitAPI(UnitName, token) or nil
            if filter == "" or (type(name) == "string" and string.lower(name):find(filter, 1, true)) then
                count = count + 1
                if count > 20 then print("  Snapshot limited to 20 plates; narrow the name filter."); break end
                local assessment = Capabilities.InspectFrame(frame, context)
                local expected = Capabilities.SafeField(frame, "SNPNameStyle", context)
                print("  Plate " .. count .. ": " .. DebugValue(name) .. "; token " .. DebugValue(token)
                    .. "; access " .. assessment.status .. "; blocked " .. (assessment.reason or "(none)")
                    .. "; state " .. DebugValue(Capabilities.SafeField(frame, "SNPState", context))
                    .. "; inside " .. DebugBoolean(Capabilities.SafeField(expected, "inside", context)))
                local regionsSeen = {}
                local function Region(label, region)
                    if not region or regionsSeen[region] then return end
                    regionsSeen[region] = true
                    print("    " .. label .. ": access " .. Capabilities.ObjectStatus(region, context)
                        .. "; shown " .. DebugRegionValue(region, "IsShown", "boolean", context)
                        .. "; visible " .. DebugRegionValue(region, "IsVisible", "boolean", context)
                        .. "; alpha " .. DebugRegionValue(region, "GetAlpha", nil, context)
                        .. "; effective alpha " .. DebugRegionValue(region, "GetEffectiveAlpha", nil, context)
                        .. "; width " .. DebugRegionValue(region, "GetWidth", nil, context)
                        .. "; height " .. DebugRegionValue(region, "GetHeight", nil, context))
                end
                Region("Base plate", plate)
                Region("Unit frame", frame)
                Region("Health container", Capabilities.SafeField(frame, "HealthBarsContainer", context))
                Region("Health bar", assessment.healthBar)
                Region("Native name", assessment.name)
                local inside = Capabilities.SafeField(frame, "SNPInsideName", context)
                Region("Inside name", inside)
                local parent = inside
                for depth = 1, 8 do
                    parent = Capabilities.ReadRegion(parent, "GetParent", context)
                    if not parent then break end
                    Region("Inside ancestor " .. depth, parent)
                end
            end
        end
    end
    print("  Matching plates: " .. math.min(count, 20)
        .. "; snapshot does not target, hover, refresh or repair plates.")
end

ns.DebugNearby = DebugNearby
ns.DebugUnit = DebugUnit

