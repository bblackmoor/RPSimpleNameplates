-- Simple Nameplates: access to assessed Blizzard nameplate regions.
local _, ns = ...
local Capabilities = ns.PresentationCapabilities

local function GetUnitFrame(unit, context)
    local assessment = Capabilities.InspectUnit(unit, context)
    return assessment.frame, assessment, assessment.plate
end

local function GetFrameFromPlate(plate, context)
    local frame = Capabilities.SafeField(plate, "UnitFrame", context)
    local assessment = Capabilities.InspectFrame(frame, context)
    return assessment.frame, assessment
end

local function GetHealthBar(frame, context, assessment)
    assessment = assessment or Capabilities.InspectFrame(frame, context)
    if assessment.canAccess then return assessment.healthBar end
end

local function GetCastBar(frame, context, assessment)
    assessment = assessment or Capabilities.InspectFrame(frame, context)
    if assessment.canAccess then return assessment.castBar end
end

local function SetShownSafe(region, shown, context)
    if Capabilities.ObjectStatus(region, context or ns.WorldContext.Get()) ~= "accessible" then return end
    if shown then region:Show() else region:Hide() end
end

-- Opposite native anchors determine dimensions even after SetWidth/SetHeight.
-- Preserve their baseline and use a single centered anchor while sizing a bar.
local function AnchorPreparationResult(ready, reason)
    ns.Profiler.Count("Bar anchor preparation", reason)
    return ready, reason
end

-- GetPoint is unavailable on anchor-restricted nameplate regions. For the
-- current Retail hierarchy, derive anchors from Blizzard's UpdateAnchors
-- inputs instead. PixelUtil preserves the native rounding and UI scale.
local function NativeSizePoints(frame, region, context)
    local setup = ns.AccessibleValue(NamePlateSetupOptions)
    local pixelPoint = PixelUtil and PixelUtil.SetPoint
    if not setup or type(pixelPoint) ~= "function"
        or type(Capabilities.SafeField(frame, "UpdateAnchors", context)) ~= "function" then return end
    local container = Capabilities.SafeField(frame, "HealthBarsContainer", context)
    local bar = Capabilities.SafeField(container, "healthBar", context)
    local points
    if region == container then
        local cast = Capabilities.SafeField(frame, "CastBarsContainer", context)
        local spacing = ns.AccessibleNumber(setup.castBarToHealthBarSpacing)
        if Capabilities.ObjectStatus(cast, context) ~= "accessible" or spacing == nil then return end
        points = {{"BOTTOMLEFT", cast, "TOPLEFT", 0, spacing},
            {"BOTTOMRIGHT", cast, "TOPRIGHT", 0, spacing}}
    elseif region == bar then
        if Capabilities.ObjectStatus(container, context) ~= "accessible" then return end
        local classic = ns.AccessibleBoolean(setup.useClassicHealthBar)
        if classic == nil then return end
        local left, right, y = 0, 0, 0
        if classic then
            local horizontal = ns.AccessibleNumber(setup.horizontalScale)
            local vertical = ns.AccessibleNumber(setup.verticalScale)
            if horizontal == nil or vertical == nil then return end
            left, right, y = 3.5 * horizontal, -20.75 * horizontal, 0.5 * vertical
        end
        points = {{"TOPLEFT", container, "TOPLEFT", left, y},
            {"BOTTOMRIGHT", container, "BOTTOMRIGHT", right, y}}
    end
    if points then points.pixelPoint = pixelPoint end
    return points
end

local function PrepareBarSize(frame, region, context)
    local count = ns.AccessibleNumber(Capabilities.ReadRegion(region, "GetNumPoints", context))
    if not count then return AnchorPreparationResult(false, "anchor count unreadable") end
    if count < 2 then return AnchorPreparationResult(true, "already unconstrained") end
    if count ~= 2 then return AnchorPreparationResult(false, "unsupported anchor count") end
    local restricted = ns.AccessibleBoolean(Capabilities.ReadRegion(region, "IsAnchoringRestricted", context))
    local points = restricted == true and NativeSizePoints(frame, region, context) or nil
    if restricted == true and not points then
        return AnchorPreparationResult(false, "restricted layout unsupported")
    end
    local getter = Capabilities.SafeField(region, "GetPoint", context)
    if not points and type(getter) ~= "function" then return AnchorPreparationResult(false, "point getter unavailable") end
    local native = points ~= nil
    points = points or {}
    for index = 1, native and 0 or count do
        local ok, point, relative, relativePoint, x, y = pcall(getter, region, index)
        point, relative, relativePoint = ns.AccessibleValue(point), ns.AccessibleValue(relative), ns.AccessibleValue(relativePoint)
        x, y = ns.AccessibleNumber(x), ns.AccessibleNumber(y)
        if not ok then
            points = NativeSizePoints(frame, region, context)
            if not points then return AnchorPreparationResult(false, "point getter failed") end
            native = true
            break
        end
        if type(point) ~= "string" or type(relativePoint) ~= "string" then
            return AnchorPreparationResult(false, "point labels unreadable")
        end
        if not relative then return AnchorPreparationResult(false, "relative frame unreadable") end
        if x == nil or y == nil then return AnchorPreparationResult(false, "point offsets unreadable") end
        if Capabilities.ObjectStatus(relative, context) ~= "accessible" then
            return AnchorPreparationResult(false, "relative frame inaccessible")
        end
        points[index] = {point, relative, relativePoint, x, y}
    end
    local first, last = points[1], points[#points]
    if first[2] ~= last[2] then return AnchorPreparationResult(false, "different relative frames") end
    local function Center(point)
        local centered = point:gsub("LEFT", ""):gsub("RIGHT", "")
        return centered == "" and "CENTER" or centered
    end
    -- Only take ownership of recognizable native corner/edge pairs.
    if not ((first[1]:find("LEFT") and last[1]:find("RIGHT"))
        or (first[1]:find("RIGHT") and last[1]:find("LEFT"))) then
        return AnchorPreparationResult(false, "unsupported edge pair")
    end
    local height = ns.AccessibleNumber(Capabilities.ReadRegion(region, "GetHeight", context))
    if not height then return AnchorPreparationResult(false, "height unreadable") end
    -- Opposing anchors may be the only source of width. Removing them before
    -- setting just the height collapses a natively sized bar to zero width.
    local width = ns.AccessibleNumber(Capabilities.ReadRegion(region, "GetWidth", context))
    if not width or width <= 0 then return AnchorPreparationResult(false, "width unavailable") end
    points.width = width
    frame.SNPOriginalSizeAnchors = frame.SNPOriginalSizeAnchors or {}
    if not frame.SNPOriginalSizeAnchors[region] then frame.SNPOriginalSizeAnchors[region] = points end
    region:ClearAllPoints()
    if points.pixelPoint then
        points.pixelPoint(region, Center(first[1]), first[2], Center(first[3]), (first[4] + last[4]) / 2, first[5])
    else
        region:SetPoint(Center(first[1]), first[2], Center(first[3]), (first[4] + last[4]) / 2, first[5])
    end
    region:SetWidth(width)
    region:SetHeight(height)
    return AnchorPreparationResult(true, native and "released native restricted anchors" or "released opposing anchors")
end

local function RestoreSizeAnchors(frame, context)
    for region, points in pairs(frame.SNPOriginalSizeAnchors or {}) do
        if Capabilities.ObjectStatus(region, context) ~= "accessible" then
            error("Bar anchor restoration is temporarily inaccessible")
        end
        region:ClearAllPoints()
        for _, point in ipairs(points) do
            if Capabilities.ObjectStatus(point[2], context) ~= "accessible" then
                error("Bar relative anchor is temporarily inaccessible")
            end
            if points.pixelPoint then points.pixelPoint(region, (unpack or table.unpack)(point))
            else region:SetPoint((unpack or table.unpack)(point)) end
        end
    end
    frame.SNPOriginalSizeAnchors = nil
end

local function RestoreBarWidth(frame, assessment)
    local bar = frame.SNPOriginalHealthBar or assessment.healthBar
    local container = frame.SNPOriginalHealthBarsContainer or frame.HealthBarsContainer
    if bar and frame.SNPOriginalBarWidth then
        bar:SetWidth(frame.SNPOriginalBarWidth)
    end
    if container and frame.SNPOriginalContainerWidth then
        container:SetWidth(frame.SNPOriginalContainerWidth)
    end
    frame.SNPOriginalBarWidth, frame.SNPOriginalContainerWidth = nil, nil
    frame.SNPBarWidth, frame.SNPContainerWidth = nil, nil
end

local function ApplyBarWidth(frame, assessment, context)
    local percent = ns.GetAppearanceSetting("healthBarWidth") or 100
    if percent == 100 then
        RestoreBarWidth(frame, assessment)
        RestoreSizeAnchors(frame, context)
        return
    end
    for _, item in ipairs({
        {assessment.healthBar, "SNPOriginalBarWidth", "SNPBarWidth"},
        {frame.HealthBarsContainer, "SNPOriginalContainerWidth", "SNPContainerWidth"},
    }) do
        local region, originalKey, expectedKey = item[1], item[2], item[3]
        if region and not frame[originalKey] then
            local width = ns.AccessibleNumber(Capabilities.ReadRegion(region, "GetWidth", context))
            if width and width > 0 then frame[originalKey] = width end
        end
        if region and frame[originalKey] then
            frame[expectedKey] = frame[originalKey] * percent / 100
            PrepareBarSize(frame, region, context)
            region:SetWidth(frame[expectedKey])
        end
    end
end

-- Keep native progress/value logic; replace only the decorative artwork.
local function ReadValues(region, method, context, ...)
    local fn = Capabilities.SafeField(region, method, context)
    if type(fn) ~= "function" then return nil end
    local values = {pcall(fn, region, ...)}
    if not values[1] then return nil end
    table.remove(values, 1)
    for index, value in ipairs(values) do
        values[index] = ns.AccessibleValue(value)
        if values[index] == nil then return nil end
    end
    return values
end

local function OriginalArtwork(frame, region, context)
    if Capabilities.ObjectStatus(region, context) ~= "accessible" then return nil end
    local originals = frame.SNPOriginalArtwork or {}
    frame.SNPOriginalArtwork = originals
    local original = originals[region]
    if not original then
        original = {}
        originals[region] = original
    end
    return original
end

local function RemoveArtworkEdge(frame, region, context)
    local original = OriginalArtwork(frame, region, context)
    if not original then return end
    if original.alpha == nil then
        original.alpha = ns.AccessibleNumber(Capabilities.ReadRegion(region, "GetAlpha", context))
    end
    if original.alpha ~= nil then region:SetAlpha(0) end
end

local function FlattenFill(frame, region, context, isCast)
    local original = OriginalArtwork(frame, region, context)
    if not original then return end
    if not original.fill then
        local atlas = Capabilities.ReadRegion(region, "GetAtlas", context)
        local texture = Capabilities.ReadRegion(region, "GetTexture", context)
        local coords = ReadValues(region, "GetTexCoord", context)
        if not atlas and not texture then
            if not isCast then return end
            -- Preserve an opaque native texture only for renderer restoration.
            -- Never compare or classify its value; a fresh live cast may already
            -- have a secret identifier before this frame has an artwork backup.
            local getter = Capabilities.SafeField(region, "GetTexture", context)
            if type(getter) ~= "function" then return end
            local ok, nativeTexture = pcall(getter, region)
            if not ok then return end
            texture = nativeTexture
        end
        original.fill = {atlas = atlas, texture = texture, coords = coords}
    end
    region:SetTexture("Interface\\Buttons\\WHITE8X8")
    region:SetTexCoord(0, 1, 0, 1)
end

local function StyleNativeTextOutline(frame, region, context, inside)
    local original = OriginalArtwork(frame, region, context)
    if not original then return end
    if not original.font then
        local font = ReadValues(region, "GetFont", context)
        if not font or type(font[1]) ~= "string" or type(font[2]) ~= "number" then return end
        original.font = font
        original.shadowColor = ReadValues(region, "GetShadowColor", context)
        original.shadowOffset = ReadValues(region, "GetShadowOffset", context)
        if inside then original.drawLayer = ReadValues(region, "GetDrawLayer", context) end
    end
    region:SetFont(original.font[1], original.font[2], ns.FontFlags())
    region:SetShadowColor(0, 0, 0, 0)
    region:SetShadowOffset(0, 0)
end

local function StyleHealthText(frame, region, context, bar)
    local original = OriginalArtwork(frame, region, context)
    if not original then return end
    StyleNativeTextOutline(frame, region, context, true)
    if original.points == nil then
        local count = ns.AccessibleNumber(Capabilities.ReadRegion(region, "GetNumPoints", context))
        if count then
            local points = {}
            for index = 1, count do
                local values = ReadValues(region, "GetPoint", context, index)
                if not values or type(values[4]) ~= "number" or type(values[5]) ~= "number" then
                    points = nil; break
                end
                points[#points + 1] = values
            end
            original.points = points
        end
    end
    if original.points then
        region:ClearAllPoints()
        for _, point in ipairs(original.points) do
            region:SetPoint(point[1], point[2], point[3], point[4], point[5] - 0.5)
        end
    end
    if not original.textColor then
        original.textColor = ReadValues(region, "GetTextColor", context)
        original.vertexColor = ReadValues(region, "GetVertexColor", context)
    end
    region:SetDrawLayer("OVERLAY", 7)
    if original.textColor then
        region:SetTextColor(1, 1, 1, 1)
        if original.vertexColor then region:SetVertexColor(1, 1, 1, 1) end
    end
end

-- Right-to-left order matches Blizzard's percentage/value/single-text labels.
-- Anchors follow label regions, so secret or changing text widths need no reads.
local function HealthTextLayoutState(frame, bar, context)
    local labels, signature = {}, ""
    local threat
    if bar and frame.SNPThreatTextBar == bar
        and frame.SNPThreatStatus == "displayed scaled percentage" then
        threat = frame.SNPThreatText
    end
    signature = threat and "T" or "-"
    for _, key in ipairs({"LeftText", "RightText", "Text"}) do
        local region = Capabilities.SafeField(bar, key, context)
        if Capabilities.ObjectStatus(region, context) ~= "accessible" then region = nil end
        local original = frame.SNPOriginalArtwork and frame.SNPOriginalArtwork[region]
        local shown = ns.AccessibleBoolean(Capabilities.ReadRegion(region, "IsShown", context))
        -- Preserve space for unknown visibility; do not inspect restricted text.
        local included = region and original and original.points and shown ~= false
        signature = signature .. (included and "1" or "0")
        if included then labels[#labels + 1] = region end
    end
    return labels, threat, signature
end

local function GetHealthTextInsetRegion(frame, bar, context)
    local labels, threat, signature = HealthTextLayoutState(frame, bar, context)
    return labels[#labels] or threat, signature, labels, threat
end

local function LayoutHealthText(frame, bar, context, observed)
    local labels, threat, signature
    if observed then labels, threat, signature = observed.labels, observed.threat, observed.signature
    else labels, threat, signature = HealthTextLayoutState(frame, bar, context) end
    local previous = threat
    if threat then
        threat:ClearAllPoints()
        threat:SetPoint("RIGHT", bar, "RIGHT", -3, -0.5)
    end
    for _, region in ipairs(labels) do
        region:ClearAllPoints()
        region:SetPoint("RIGHT", previous or bar, previous and "LEFT" or "RIGHT", -3, previous and 0 or -0.5)
        previous = region
    end
    return labels[#labels] or threat, signature
end

-- Modern cast colors are baked into the atlas, while its vertex color is
-- white. Use Blizzard's own flat/classic colors before replacing that atlas.
-- Only inspect accessible artwork identifiers, never secret cast state.
local function FlattenCastColor(frame, fill, context)
    local atlas = Capabilities.ReadRegion(fill, "GetAtlas", context)
    local texture = Capabilities.ReadRegion(fill, "GetTexture", context)
    local identifier = atlas or texture
    if identifier == nil then return false end
    if type(identifier) ~= "string" then return true end
    for _, info in pairs(CastingBarTypeInfo or {}) do
        local color
        if identifier == info.filling then color = info.classicFillColor
        elseif identifier == info.full then color = info.classicFullColor end
        if color then
            local rgb = ReadValues(color, "GetRGB", context)
            local original = OriginalArtwork(frame, fill, context)
            if rgb and original then
                if not original.vertexColor then
                    original.vertexColor = ReadValues(fill, "GetVertexColor", context)
                end
                if original.vertexColor then fill:SetVertexColor(rgb[1], rgb[2], rgb[3], 1) end
            end
            return true
        end
    end
    return true
end

local function FlattenBar(frame, bar, backgroundKey, context, isCast)
    if Capabilities.ObjectStatus(bar, context) ~= "accessible" then return end
    RemoveArtworkEdge(frame, Capabilities.SafeField(bar, backgroundKey, context), context)
    local fill = Capabilities.ReadRegion(bar, "GetStatusBarTexture", context)
        or Capabilities.SafeField(bar, "barTexture", context)
    if isCast then FlattenCastColor(frame, fill, context) end
    -- A saved fill can be replaced even when its current identifier is secret.
    FlattenFill(frame, fill, context, isCast)
    local background = bar.SNPPlainBackground
    if not background and type(bar.CreateTexture) == "function" then
        background = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        background:SetAllPoints(bar)
        background:SetColorTexture(0, 0, 0, 0.4)
        bar.SNPPlainBackground = background
    end
    if background then
        frame.SNPPlainBackgrounds = frame.SNPPlainBackgrounds or {}
        frame.SNPPlainBackgrounds[background] = true
        background:Show()
    end
end

local CAST_DECORATIONS = {"Spark", "Flash", "StandardGlow", "CraftGlow", "CraftingGlow",
    "ChannelShadow", "Shine", "EnergyGlow", "Flakes01", "Flakes02", "Flakes03",
    "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02", "InterruptGlow", "ChargeGlow", "ChargeFlash"}

local function RemoveCastDecoration(frame, region, context)
    RemoveArtworkEdge(frame, region, context)
    local original = OriginalArtwork(frame, region, context)
    if not original then return end
    if not original.fill then
        local atlas = Capabilities.ReadRegion(region, "GetAtlas", context)
        local texture = Capabilities.ReadRegion(region, "GetTexture", context)
        if not atlas and not texture then return end
        original.fill = {atlas = atlas, texture = texture, coords = ReadValues(region, "GetTexCoord", context)}
    end
    -- Animation alpha can override SetAlpha(0); an empty texture stays invisible.
    region:SetTexture(nil)
end

local function InstallArtworkHooks(frame, bar, context)
    if Capabilities.ObjectStatus(bar, context) ~= "accessible" then return end
    if bar.SNPArtworkHookOwner == frame then return end
    local function Refresh()
        if frame.SNPRestoring or frame.SNPRestoringArtwork or frame.SNPApplyingArtwork
            or not frame.SNPOriginalArtwork then return end
        if frame.SNPApplyingStyle then frame.SNPArtworkPending = true; return end
        local current = ns.WorldContext.Get()
        local assessment = Capabilities.InspectFrame(frame, current)
        if assessment.canAccess then ns.NameplateFrames.ApplyBarArtwork(frame, assessment, current) end
    end
    if type(bar.HookScript) == "function" then bar:HookScript("OnShow", Refresh) end
    if hooksecurefunc and type(bar.ApplyStyleAndAnchoring) == "function" then
        hooksecurefunc(bar, "ApplyStyleAndAnchoring", Refresh)
    end
    if hooksecurefunc and type(bar.UpdateBarFillTexture) == "function" then
        hooksecurefunc(bar, "UpdateBarFillTexture", Refresh)
    end
    if hooksecurefunc and type(bar.ShowSpark) == "function" then
        hooksecurefunc(bar, "ShowSpark", Refresh)
    end
    if hooksecurefunc and type(bar.UpdateBarFillTexture) == "function" then
        for _, key in ipairs(CAST_DECORATIONS) do
            local region = Capabilities.SafeField(bar, key, context)
            for _, method in ipairs({"SetAtlas", "SetTexture"}) do
                if type(Capabilities.SafeField(region, method, context)) == "function" then
                    hooksecurefunc(region, method, Refresh)
                end
            end
        end
    end
    bar.SNPArtworkHookOwner = frame
end

local function ApplyArtwork(frame, assessment, context)
    local healthBar, castBar = assessment.healthBar, assessment.castBar
    InstallArtworkHooks(frame, healthBar, context)
    InstallArtworkHooks(frame, castBar, context)
    FlattenBar(frame, healthBar, "bgTexture", context)
    if ns.HealthGradient then
        local fill = Capabilities.SafeField(healthBar, "barTexture", context)
            or Capabilities.ReadRegion(healthBar, "GetStatusBarTexture", context)
        ns.HealthGradient.Apply(healthBar, fill, context)
        if healthBar then
            frame.SNPGradientBars = frame.SNPGradientBars or {}
            frame.SNPGradientBars[healthBar] = true
        end
    end
    for _, key in ipairs({"Text", "RightText", "LeftText"}) do
        StyleHealthText(frame, Capabilities.SafeField(healthBar, key, context), context, healthBar)
    end
    -- Blizzard keeps absorb fill/prediction visible; suppress only its bright
    -- right-edge overflow marker. Retail owns it on the bar; legacy frames
    -- may expose the region directly.
    RemoveArtworkEdge(frame, Capabilities.SafeField(healthBar, "overAbsorbGlow", context), context)
    RemoveArtworkEdge(frame, Capabilities.SafeField(frame, "overAbsorbGlow", context), context)
    for _, key in ipairs({"selectedBorder", "deselectedOverlay"}) do
        RemoveArtworkEdge(frame, Capabilities.SafeField(healthBar, key, context), context)
    end
    FlattenBar(frame, castBar, "Background", context, true)
    for _, key in ipairs({"Border", "TextBorder", "DropShadow"}) do
        RemoveArtworkEdge(frame, Capabilities.SafeField(castBar, key, context), context)
    end
    for _, key in ipairs(CAST_DECORATIONS) do
        RemoveCastDecoration(frame, Capabilities.SafeField(castBar, key, context), context)
    end
    for _, key in ipairs({"Text", "CastTargetNameText"}) do
        StyleNativeTextOutline(frame, Capabilities.SafeField(castBar, key, context), context)
    end
    LayoutHealthText(frame, healthBar, context)
    frame.SNPArtworkPending = nil
end

-- Artwork hooks can also fire while a bar or its labels are being changed.
local function ApplyBarArtwork(frame, assessment, context)
    if frame.SNPRestoring or frame.SNPApplyingArtwork then return end
    frame.SNPApplyingArtwork = true
    local ok, err = pcall(ApplyArtwork, frame, assessment, context)
    frame.SNPApplyingArtwork = nil
    if not ok then error(err, 0) end
    if not frame.SNPApplyingStyle and ns.NameplateText then
        if ns.NameplatePresentation then ns.NameplatePresentation.RepairPendingGeometry(frame) end
        ns.NameplateText.RepairPendingNameAppearance(frame)
        ns.NameplateText.FinishCachedAppearance(frame, context)
    end
end

local unpackValues = unpack or table.unpack
local function RestoreArtwork(frame, context)
    for region, original in pairs(frame.SNPOriginalArtwork or {}) do
        if Capabilities.ObjectStatus(region, context) ~= "accessible" then
            error("Bar artwork restoration is temporarily inaccessible")
        end
        if original.drawLayer then region:SetDrawLayer(unpackValues(original.drawLayer)) end
        if original.alpha ~= nil then region:SetAlpha(original.alpha) end
        if original.fill then
            if original.fill.atlas then region:SetAtlas(original.fill.atlas)
            else region:SetTexture(original.fill.texture) end
            if original.fill.coords then region:SetTexCoord(unpackValues(original.fill.coords)) end
        end
        if original.textColor then region:SetTextColor(unpackValues(original.textColor)) end
        if original.vertexColor then region:SetVertexColor(unpackValues(original.vertexColor)) end
        if original.points then
            region:ClearAllPoints()
            for _, point in ipairs(original.points) do region:SetPoint(unpackValues(point)) end
        end
        if original.font then
            region:SetFont(original.font[1], original.font[2], original.font[3] or "")
            if original.shadowColor then region:SetShadowColor(unpackValues(original.shadowColor)) end
            if original.shadowOffset then region:SetShadowOffset(unpackValues(original.shadowOffset)) end
        end
    end
    for region in pairs(frame.SNPPlainBackgrounds or {}) do
        if Capabilities.ObjectStatus(region, context) ~= "accessible" then
            error("Plain bar background restoration is temporarily inaccessible")
        end
        region:Hide()
    end
    for bar in pairs(frame.SNPGradientBars or {}) do
        if Capabilities.ObjectStatus(bar, context) ~= "accessible" then
            error("Gradient restoration is temporarily inaccessible")
        end
        ns.HealthGradient.Hide(bar)
    end
    frame.SNPGradientBars = nil
    frame.SNPArtworkPending = nil
    frame.SNPOriginalArtwork, frame.SNPPlainBackgrounds = nil, nil
end

local function RestoreBarArtwork(frame, context)
    frame.SNPRestoringArtwork = true
    local ok, err = pcall(RestoreArtwork, frame, context)
    frame.SNPRestoringArtwork = nil
    if not ok then error(err, 0) end
end

LayoutHealthText = ns.Profiler.Wrap("Health text layout", LayoutHealthText)
ApplyBarArtwork = ns.Profiler.Wrap("Bar artwork", ApplyBarArtwork)

ns.NameplateFrames = {
    PrepareBarSize = PrepareBarSize, RestoreSizeAnchors = RestoreSizeAnchors,
    ApplyBarWidth = ApplyBarWidth, RestoreBarWidth = RestoreBarWidth,
    LayoutHealthText = LayoutHealthText, GetHealthTextInsetRegion = GetHealthTextInsetRegion,
    ApplyBarArtwork = ApplyBarArtwork, RestoreBarArtwork = RestoreBarArtwork,
    GetUnitFrame = GetUnitFrame, GetFrameFromPlate = GetFrameFromPlate,
    GetHealthBar = GetHealthBar, GetCastBar = GetCastBar, SetShownSafe = SetShownSafe,
}
