-- Simple Nameplates: runtime events, refresh queues, hooks, and plate lifecycle.
local addon, ns = ...
if not ns.EnsureDB then return end
local C_NamePlate = C_NamePlate
local WorldContext = ns.WorldContext
local GetFrameFromPlate = ns.NameplateFrames.GetFrameFromPlate
local GetStylingEnabled = ns.GetStylingEnabled
local StateForUnit = ns.NameplateClassification.StateForUnit
local GetUnitFrame, GetHealthBar = ns.NameplateFrames.GetUnitFrame, ns.NameplateFrames.GetHealthBar
local ApplySimpleStyle = ns.NameplatePresentation.ApplySimpleStyle
local UpdateData = ns.NameplatePresentation.UpdateData
local RepairHealthColor, RepairName =
    ns.NameplatePresentation.RepairHealthColor, ns.NameplatePresentation.RepairName
local Restoration = ns.NameplateRestoration
local Periodic = ns.PeriodicWork
local Cap = ns.PresentationCapabilities
local knownFrames, knownPlates = {}, {}
local reconcilePlates, nextSnapshot = {}, 0
local function ResetReconciliation()
    Periodic.Clear("reconciliation")
    reconcilePlates, nextSnapshot = {}, 0
end
local pendingUnits = {}
local removedUnits = {}
local unitGenerations = {}
local globalWork = {}
local globalEpoch = 0
local previousPriorityPlates = {}
local function ClearGlobalWork()
    Periodic.Clear("global refresh")
    globalWork = {}
    globalEpoch = globalEpoch + 1
end
local pendingPlates = setmetatable({}, {__mode = "k"})
local CachedNameHasDrifted, RepairCachedName =
    ns.NameplateText.CachedNameHasDrifted, ns.NameplateText.RepairCachedName

local fullWork = {full = true}
local workKeys = {"full", "classify", "name", "threat", "cast", "layout"}
local function MergeWork(destination, source)
    for _, key in ipairs(workKeys) do if source[key] then destination[key] = true end end
    return destination
end

local RefreshUnit
local function RetryUnit(unit)
    if not pendingUnits[unit] or removedUnits[unit] then return end
    if not GetStylingEnabled() then return end
    RefreshUnit(unit, "pending unit", pendingUnits[unit])
    if pendingUnits[unit] then return 0.25 end
end
local function RetryPlate(plate)
    if not pendingPlates[plate] or not GetStylingEnabled() then return end
    local context = WorldContext.Get()
    local frame = GetFrameFromPlate(plate, context)
    if not frame then return 0.25 end
    local unit = ns.AccessibleValue(frame.unit)
    if type(unit) ~= "string" then return 0.25 end
    if removedUnits[unit] then pendingPlates[plate] = nil; return end
    local ok, current = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    current = ok and ns.AccessibleValue(current)
    if not current then return 0.25 end
    if current ~= plate then pendingPlates[plate] = nil; return end
    pendingPlates[plate] = nil
    knownFrames[unit], knownPlates[unit], removedUnits[unit] = frame, plate, nil
    ApplySimpleStyle(frame, context, "pending plate")
end
local function DeferUnit(unit)
    Periodic.Schedule("unit retry", unit, RetryUnit, 0.25)
end
local function DeferPlate(plate)
    Periodic.Schedule("plate retry", plate, RetryPlate, 0.25)
end
RefreshUnit = function(unit, reason, work)
    if removedUnits[unit] then return end
    work = MergeWork(pendingUnits[unit] or {}, work or fullWork)
    local context = WorldContext.Get()
    local frame, _, plate = GetUnitFrame(unit, context)
    local assigned = frame and ns.AccessibleValue(Cap.SafeField(frame, "unit", context))
    if frame and assigned == unit then
        local queued = globalWork[plate]
        if queued and (queued.unit == nil or queued.unit == unit) then
            work = MergeWork(work, queued.work)
            globalWork[plate] = nil
            Periodic.Cancel("global refresh", plate)
        end
        knownFrames[unit], knownPlates[unit], pendingUnits[unit] = frame, plate, nil
        Periodic.Cancel("unit retry", unit)
        if work.full and (reason == "initial plate" or reason == "late plate") then
            ns.NameplatePresentation.InitializeOrRefresh(frame, context, reason)
        elseif work.full then ApplySimpleStyle(frame, context, reason or "unit refresh")
        else UpdateData(frame, context, work) end
    else pendingUnits[unit] = work; DeferUnit(unit) end
end

local function RefreshGlobalPlate(plate)
    local request = globalWork[plate]
    if not request or not GetStylingEnabled() then return end
    local context = WorldContext.Get()
    local frame = Cap.SafeField(plate, "UnitFrame", context)
    local unit = ns.AccessibleValue(Cap.SafeField(frame, "unit", context))
    if type(unit) ~= "string" then return 0.25 end
    if removedUnits[unit] or (request.unit and (request.unit ~= unit
        or request.generation ~= unitGenerations[unit])) then
        globalWork[plate] = nil; return
    end
    local ok, current = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    current = ok and ns.AccessibleValue(current)
    if not current then return 0.25 end
    if current ~= plate then globalWork[plate] = nil; return end
    if request.guid and UnitGUID then
        local guidOK, guid = pcall(UnitGUID, unit)
        guid = guidOK and ns.AccessibleValue(guid)
        if type(guid) == "string" and guid ~= request.guid then globalWork[plate] = nil; return end
    end
    pendingPlates[plate] = nil
    Periodic.Cancel("plate retry", plate)
    -- Detach before writes so synchronous callbacks can retain newer work.
    local flags = request.work
    if Periodic.Has("global refresh", plate) then Periodic.Cancel("global refresh", plate) end
    globalWork[plate] = nil
    ns.Profiler.Count("Global refresh plates", flags.full and "full" or "focused")
    local applied, err = pcall(RefreshUnit, unit, "global refresh", flags)
    if not applied then
        local newer = globalWork[plate]
        if newer and newer.unit == request.unit and newer.generation == request.generation then
            MergeWork(newer.work, flags)
        elseif not newer and request.epoch == globalEpoch and not removedUnits[unit]
            and (not request.unit or request.generation == unitGenerations[unit]) and GetStylingEnabled() then
            globalWork[plate] = request
        end
        if globalWork[plate] then Periodic.Schedule("global refresh", plate, RefreshGlobalPlate, 0.25) end
        error(err, 0)
    end
end
RefreshGlobalPlate = ns.Profiler.Wrap("Global plate refresh", RefreshGlobalPlate)

local function RefreshAll(work, queuedUnits)
    if not GetStylingEnabled() then return end
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    work = work or fullWork
    if work.full then ResetReconciliation(); ClearGlobalWork() end
    local context = WorldContext.Get()
    local priority, currentPriorities = {}, {}
    for plate in pairs(previousPriorityPlates) do priority[plate] = true end
    for _, token in ipairs({"target", "mouseover", "softinteract"}) do
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, token)
        plate = ok and ns.AccessibleValue(plate)
        if plate then priority[plate], currentPriorities[plate] = true, true end
    end
    previousPriorityPlates = currentPriorities
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local frame = Cap.SafeField(plate, "UnitFrame", context)
        local unit = ns.AccessibleValue(Cap.SafeField(frame, "unit", context))
        if type(unit) ~= "string" then unit = nil end
        if unit then removedUnits[unit] = nil end
        local request = globalWork[plate]
        if not request or request.unit ~= unit or request.generation ~= (unit and unitGenerations[unit]) then
            local guid
            if unit and UnitGUID then
                local ok, value = pcall(UnitGUID, unit)
                value = ok and ns.AccessibleValue(value)
                if type(value) == "string" then guid = value end
            end
            request = {unit = unit, generation = unit and unitGenerations[unit], guid = guid,
                epoch = globalEpoch, work = {}}
            globalWork[plate] = request
        end
        MergeWork(request.work, work)
        local urgent = unit and queuedUnits and queuedUnits[unit]
        if urgent then MergeWork(request.work, urgent); queuedUnits[unit] = nil end
        if priority[plate] or urgent then RefreshGlobalPlate(plate)
        else Periodic.Schedule("global refresh", plate, RefreshGlobalPlate) end
        -- If an immediate priority lookup was temporarily inaccessible, retry
        -- through the same bounded queue rather than losing the request.
        if globalWork[plate] then Periodic.Schedule("global refresh", plate, RefreshGlobalPlate) end
    end
end
RefreshAll = ns.Profiler.Wrap("Global refresh", RefreshAll)

local function RestoreAll()
    ClearGlobalWork()
    ResetReconciliation()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    local context = WorldContext.Get()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        Restoration.RequestPlate(plate, context)
    end
end

if hooksecurefunc and CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame) RepairHealthColor(frame, WorldContext.Get()) end)
end

-- Blizzard recolors the name FontString in its name update path, which occurs
-- after NAME_PLATE_UNIT_ADDED in several situations (mounting, range changes,
-- recycled plates, etc.). Reapply our configured color after Blizzard finishes that pass.
if hooksecurefunc and CompactUnitFrame_UpdateName then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame) RepairName(frame, WorldContext.Get()) end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_REGEN_ENABLED","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","PLAYER_TARGET_CHANGED","UNIT_FACTION","UNIT_FLAGS","UNIT_NAME_UPDATE","UNIT_TARGET","UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP","UNIT_SPELLCAST_EMPOWER_START","UNIT_SPELLCAST_EMPOWER_STOP","UNIT_SPELLCAST_INTERRUPTIBLE","UNIT_SPELLCAST_NOT_INTERRUPTIBLE","CVAR_UPDATE","PLAYER_ENTERING_WORLD","ZONE_CHANGED","ZONE_CHANGED_INDOORS","ZONE_CHANGED_NEW_AREA","WAR_MODE_STATUS_UPDATE","PLAYER_FLAGS_CHANGED","PVP_TIMER_UPDATE","PLAYER_REGEN_DISABLED","PLAYER_SOFT_INTERACT_CHANGED","UPDATE_MOUSEOVER_UNIT"}) do
    events:RegisterEvent(event)
end

local dirtyUnits = {}
local allWork
local eventWork = {
    UNIT_NAME_UPDATE = {classify = true, name = true},
    UNIT_FACTION = {classify = true}, UNIT_FLAGS = {classify = true},
    UNIT_TARGET = {classify = true, threat = true},
    UNIT_THREAT_LIST_UPDATE = {classify = true, threat = true},
    UNIT_THREAT_SITUATION_UPDATE = {classify = true, threat = true},
    PLAYER_TARGET_CHANGED = {classify = true, threat = true},
    PLAYER_SOFT_INTERACT_CHANGED = {classify = true, name = true},
    UPDATE_MOUSEOVER_UNIT = {classify = true, name = true},
}
local castWork = {cast = true}
for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE"}) do eventWork[event] = castWork end

local function QueueUnitRefresh(unit, event)
    unit = ns.AccessibleValue(unit)
    if type(unit) == "string" and unit:match("^nameplate%d+$") then
        dirtyUnits[unit] = MergeWork(dirtyUnits[unit] or {}, eventWork[event] or fullWork)
        ns.Profiler.Count("Queued unit events", event or "unspecified")
    end
end

local function QueueRefreshAll(reason, work)
    if not work or work.full then ResetReconciliation(); ClearGlobalWork() end
    ns.Profiler.Count("Queued global refresh", reason or "settings or callback")
    allWork = MergeWork(allWork or {}, work or fullWork)
end

local function FlushQueuedRefreshes()
    if not allWork and not next(dirtyUnits) then return end
    -- Detach the batch before writes: synchronous native callbacks may enqueue
    -- new work, which must survive for the next frame rather than being wiped.
    local units, work = dirtyUnits, allWork
    dirtyUnits, allWork = {}, nil
    if work then ns.Profiler.Count("Urgent batches", work.full and "global full" or "global focused") end
    if work then RefreshAll(work, units) end
    for unit, flags in pairs(units) do
        ns.Profiler.Count("Urgent batches", "unit job")
        RefreshUnit(unit, "unit refresh", flags)
    end
end
FlushQueuedRefreshes = ns.Profiler.Wrap("Urgent refresh", FlushQueuedRefreshes)

local function HandlePlayerLogin()
    ns.EnsureDB()
    if ns.CheckNameplateSetup then ns.CheckNameplateSetup() end
    ns.ApplyCritterCompanionNameVisibility()
    C_Timer.After(1, function()
        if ns.GetHideCritterCompanionNames() then ns.ApplyCritterCompanionNameVisibility() end
        ns.ApplyManagedNameSettings()
    end)
    if ns.RegisterSettingsPanels then ns.RegisterSettingsPanels() end
    if ns.TRP3 and ns.TRP3.RegisterCallbacks then ns.TRP3.RegisterCallbacks() end
    if GetStylingEnabled() then
        -- Refresh once more after Blizzard finishes login setup.
        C_Timer.After(1, function()
            if GetStylingEnabled() then
                RefreshAll()
            end
        end)
        C_Timer.After(0.5, ns.ShowNameplateConflictWarning)
        C_Timer.After(0, RefreshAll)
    end
end

local function HandleCVarUpdate(cvarName)
    if type(cvarName) == "string"
        and ns.MANAGED_NAME_CVAR_SET[string.lower(cvarName)] then
        if ns.ApplyManagedNameSettings then ns.ApplyManagedNameSettings() end
        QueueRefreshAll("CVAR_UPDATE")
        return
    end
    if ns.GetHideCritterCompanionNames() then
        for _, cvar in ipairs(ns.BLIZZARD_CRITTER_COMPANION_NAME_CVARS) do
            if cvarName == cvar then
                ns.ApplyCritterCompanionNameVisibility()
                return
            end
        end
    end
    if not GetStylingEnabled() then return end
    for _, cvar in ipairs(ns.FRIENDLY_COLOR_CVARS) do
        if cvarName == cvar then
            QueueRefreshAll("CVAR_UPDATE")
            return
        end
    end
end

local function CleanupRemovedNameplate(unit)
    local frame = knownFrames[unit] or GetUnitFrame(unit, WorldContext.Get())
    if ns.CastHighlight and ns.CastHighlight.ClearUnit then ns.CastHighlight.ClearUnit(unit, frame) end
    local plate = knownPlates[unit]
    if plate then
        Periodic.Cancel("global refresh", plate)
        globalWork[plate] = nil
        Periodic.Cancel("reconciliation", plate)
        Periodic.Cancel("plate retry", plate)
        pendingPlates[plate], reconcilePlates[plate] = nil, nil
    end
    Periodic.Cancel("unit retry", unit)
    Restoration.Request(frame, WorldContext.Get(), unit)
    knownFrames[unit], knownPlates[unit], dirtyUnits[unit], pendingUnits[unit] = nil, nil, nil, nil
    removedUnits[unit] = true
    unitGenerations[unit] = (unitGenerations[unit] or 0) + 1
end

local function HandleNameplateEvent(event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        removedUnits[unit] = nil
        unitGenerations[unit] = (unitGenerations[unit] or 0) + 1
        local generation = unitGenerations[unit]
        RefreshUnit(unit, "initial plate")
        -- One delayed pass covers late nameplate initialization; the Blizzard
        -- hooks and cached drift check handle subsequent changes.
        C_Timer.After(0.50, function()
            if unitGenerations[unit] == generation and GetStylingEnabled() then RefreshUnit(unit, "late plate") end
        end)
        return true
    end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        CleanupRemovedNameplate(unit)
        return true
    end
    return false
end

local function HandleEvent(_, event, unit)
    if WorldContext.HandlesEvent(event, unit) then
        local _, changed = WorldContext.Refresh(event)
        if changed or event == "PLAYER_ENTERING_WORLD"
            or event == "UNIT_FLAGS" or event == "UNIT_FACTION" then QueueRefreshAll(event) end
    end
    if event == "ADDON_LOADED" then
        if unit ~= addon then return end
        events:UnregisterEvent("ADDON_LOADED")
        ns.EnsureDB()
        WorldContext.Refresh(event)
        return
    end
    if event == "PLAYER_LOGIN" then HandlePlayerLogin(); return end
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.ApplyPendingManagedNameSettings then ns.ApplyPendingManagedNameSettings() end
        if ns.RetryNameplateSetup then ns.RetryNameplateSetup() end
        QueueRefreshAll(event)
        return
    end
    if event == "CVAR_UPDATE" then HandleCVarUpdate(unit); return end
    if event == "NAME_PLATE_UNIT_REMOVED" then CleanupRemovedNameplate(unit); return end
    local readableUnit = ns.AccessibleValue(unit)
    if ns.CastHighlight and ns.CastHighlight.RecordSpellcastEvent then
        ns.CastHighlight.RecordSpellcastEvent(event, readableUnit)
    end
    if not GetStylingEnabled() then return end
    if HandleNameplateEvent(event, unit) then return end
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_SOFT_INTERACT_CHANGED"
        or event == "UPDATE_MOUSEOVER_UNIT" then QueueRefreshAll(event, eventWork[event]); return end
    if type(readableUnit) == "string" and readableUnit:match("^nameplate%d+$") then QueueUnitRefresh(readableUnit, event)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then QueueRefreshAll(event, eventWork[event]) end
end

events:SetScript("OnEvent", HandleEvent)


-- Reconcile one current plate per job; no assessment or property observation
-- survives between jobs. Urgent events are flushed before this shared budget.
local function ReconcileNames(plate)
    if not GetStylingEnabled() or not reconcilePlates[plate] then return end
    local context = WorldContext.Get()
    local frame, assessment = GetFrameFromPlate(plate, context)
    if frame then
        local unit = ns.AccessibleValue(frame.unit)
        if type(unit) ~= "string" then return 0.25 end
        if removedUnits[unit] then reconcilePlates[plate] = nil; return end
        local getter = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        if type(getter) == "function" then
            local ok, current = pcall(getter, unit)
            current = ok and ns.AccessibleValue(current)
            if not current then return 0.25 end
            if current ~= plate then
                ns.Profiler.Count("Periodic limits", "stale plate")
                reconcilePlates[plate] = nil; return
            end
        end
        if frame.SNPArtworkPending then
            ns.NameplateFrames.ApplyBarArtwork(frame, assessment, context)
            assessment = Cap.InspectFrame(frame, context)
        end
        if frame.SNPTitleVisibilityPending then
            ns.NameplateText.SyncFullTitleVisibility(frame, context, assessment, true)
        end
        local drifted, reason, plan
        if frame.SNPState then drifted, reason, plan = CachedNameHasDrifted(frame, context, assessment) end
        if drifted then
            ns.Profiler.Count("Name drift", reason or "unknown")
            if RepairCachedName(frame, context, assessment, plan) then
                ns.Profiler.Count("Reconciliation repairs", "cached repair")
            else
                ns.Profiler.Count("Reconciliation repairs", "full-style fallback")
                ApplySimpleStyle(frame, context, "reconciliation fallback")
            end
        end
        if frame.SNPArtworkPending then
            local current = Cap.InspectFrame(frame, context)
            if current.canAccess then ns.NameplateFrames.ApplyBarArtwork(frame, current, context) end
        end
    end
    return 0.25
end
ReconcileNames = ns.Profiler.Wrap("Reconciliation", ReconcileNames)

local function DiscoverPlates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    -- The native list snapshot and Lua queue bookkeeping do no plate styling.
    local present = {}
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        present[plate], reconcilePlates[plate] = true, true
        Periodic.Schedule("reconciliation", plate, ReconcileNames)
    end
    for plate in pairs(reconcilePlates) do
        if not present[plate] then
            Periodic.Cancel("reconciliation", plate)
            reconcilePlates[plate] = nil
        end
    end
    for plate in pairs(globalWork) do
        if not present[plate] then
            Periodic.Cancel("global refresh", plate)
            globalWork[plate] = nil
        end
    end
    for unit in pairs(pendingUnits) do DeferUnit(unit) end
    for plate in pairs(pendingPlates) do
        if present[plate] then DeferPlate(plate)
        else pendingPlates[plate] = nil; Periodic.Cancel("plate retry", plate) end
    end
end
DiscoverPlates = ns.Profiler.Wrap("Plate discovery", DiscoverPlates)
local wasEnabled
local function RuntimeUpdate(_, elapsed)
    Periodic.Advance(elapsed)
    local enabled = GetStylingEnabled()
    if enabled ~= wasEnabled then
        ResetReconciliation()
        if not enabled then
            ClearGlobalWork()
            Periodic.Clear("unit retry"); Periodic.Clear("plate retry")
        end
        wasEnabled = enabled
    end
    if enabled then
        FlushQueuedRefreshes()
        if Periodic.Now() >= nextSnapshot then
            nextSnapshot = Periodic.Now() + 0.25
            DiscoverPlates()
        end
    end
    -- Restoration remains eligible while styling is disabled. All routine
    -- reconciliation and deferred retries share this frame's one budget.
    Periodic.Run()
end
events:SetScript("OnUpdate", ns.Profiler.Wrap("Runtime update", RuntimeUpdate))


ns.RefreshRestoredNameplate = function(frame)
    local unit = ns.AccessibleValue(frame.unit)
    if GetStylingEnabled() and type(unit) == "string" and not removedUnits[unit] then
        RefreshUnit(unit, "restoration retry", fullWork)
    end
end
ns.QueueNameplateRefresh = QueueRefreshAll
ns.RefreshAll = function() QueueRefreshAll("direct request") end
ns.RefreshNameplateData = function(work) QueueRefreshAll("TRP3 callback", work) end
ns.RestoreAll = RestoreAll
ns.StateForUnit = StateForUnit
