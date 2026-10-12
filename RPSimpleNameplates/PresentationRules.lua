-- Simple Nameplates: category health-bar presentation for accessible plates.
local _, ns = ...
local function Resolve(context, facts, state, capabilities, enabled, healthBarEnabled)
    local result = {ruleID = "uniform", contextRevision = context.revision,
        state = state, colorState = state}
    if not capabilities.canAccess then
        result.action, result.reason = "skip", capabilities.status
    elseif not enabled then
        result.action, result.reason = "restore", "Blizzard presentation"
    elseif facts.widgetsOnly == true then
        -- This is a widget anchor, not another actor label. Preserve its widgets.
        result.action, result.reason = "style", "widget-only plate: suppress text"
        result.suppressText, result.nameOnly, result.showFullTitle = true, true, false
    else
        result.action, result.reason = "style", "category health-bar preference"
        result.showHealthBar = capabilities.hasHealthBar == true and healthBarEnabled ~= false
        result.showCastBar = capabilities.hasCastBar == true
        result.showCombatIndicators = true
        result.nameOnly = not result.showHealthBar
        result.showFullTitle = true
    end
    return result
end
ns.PresentationRules = {Resolve = Resolve}
