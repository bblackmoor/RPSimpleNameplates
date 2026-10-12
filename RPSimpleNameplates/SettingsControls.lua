-- Simple Nameplates: shared settings controls and layout.
local _, addon = ...
local settingsPages = {}

local function RefreshNameplates()
    if addon.RefreshAll then addon.RefreshAll() end
end

-- Canvas settings pages are not scrollable on their own. Each page owns a
-- scroll frame and a content frame. The cursor makes vertical placement
-- sequential; explicit horizontal offsets and control heights remain useful.
local function CreateScrollablePanel(name)
    local panel = CreateFrame("Frame")
    panel.name = name
    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(640, 1)
    scroll:SetScrollChild(content)

    local desiredHeight, finished = 1, false
    local layout = { parent = content, offset = 18, items = {} }
    local function Reflow()
        local offset = 18
        for _, item in ipairs(layout.items) do
            local height = item.height
            if item.region and item.region.LayoutFullWidth then
                item.region:SetWidth(math.max(1, content:GetWidth() - item.x - 24))
            end
            if item.autoHeight then
                local text = item.region.LayoutText or item.region
                if item.region.LayoutText then
                    text:SetWidth(item.region:GetWidth())
                    text:SetJustifyH("LEFT")
                end
                text:SetHeight(0) -- Measure wrapped text without its previous height cap.
                height = math.max(16, text:GetStringHeight() + 2)
            end
            if item.region then
                item.region:SetHeight(height)
                item.region:SetPoint("TOPLEFT", content, "TOPLEFT", item.x, -offset)
            end
            offset = offset + height + item.gap
        end
        layout.offset = offset
        desiredHeight = offset + 20
    end
    local function UpdateContentSize(_, width, height)
        width = width or scroll:GetWidth()
        height = height or scroll:GetHeight()
        if width and width > 4 then content:SetWidth(width - 4) end
        if finished then Reflow() end
        content:SetHeight(math.max(desiredHeight, height or 1, 1))
    end
    scroll:SetScript("OnSizeChanged", UpdateContentSize)
    scroll:SetScript("OnShow", function(self)
        UpdateContentSize(self, self:GetWidth(), self:GetHeight())
    end)
    function layout:Add(region, x, height, gap, autoHeight)
        self.items[#self.items + 1] = {region = region, x = x or 24,
            height = height or 20, gap = gap or 0, autoHeight = autoHeight}
        if region.LayoutFullWidth then region:SetWidth(math.max(1, content:GetWidth() - (x or 24) - 24)) end
        region:SetHeight(height or 20)
        region:SetPoint("TOPLEFT", content, "TOPLEFT", x or 24, -self.offset)
        self.offset = self.offset + (height or 20) + (gap or 0)
        return region
    end
    function layout:Space(height)
        self.items[#self.items + 1] = {height = height, gap = 0}
        self.offset = self.offset + height
    end
    function layout:Finish()
        finished = true
        local onShow = panel:GetScript("OnShow")
        panel:SetScript("OnShow", function(self, ...)
            if onShow then onShow(self, ...) end
            UpdateContentSize(scroll, scroll:GetWidth(), scroll:GetHeight())
        end)
        UpdateContentSize(scroll, scroll:GetWidth(), scroll:GetHeight())
    end
    settingsPages[#settingsPages + 1] = panel
    return panel, content, layout
end

local function AddTitle(content, layout, text)
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetText(text)
    layout:Add(title, 24, 24, 8)
    if text ~= "About" then
        local notice = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notice.LayoutFullWidth = true
        notice:SetJustifyH("LEFT")
        notice:SetTextColor(0.72, 0.72, 0.72, 1)
        notice:SetText("Settings changes are disabled during combat; unfinished edits are cancelled.")
        layout:Add(notice, 24, 16, 8, true)
    end
    return title
end

local function AddDescription(content, layout, text)
    local description = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description.LayoutFullWidth = true
    description:SetTextColor(0.72, 0.72, 0.72, 1)
    description:SetJustifyH("LEFT")
    description:SetText(text)
    return layout:Add(description, 24, 16, 8, true)
end

local function CreateInfoLink(parent, anchor, popupKey)
    local link = CreateFrame("Button", nil, parent)
    link:SetSize(24, 26)
    link:SetPoint("LEFT", anchor, "RIGHT", 12, 0)
    local circle = link:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    circle:SetPoint("CENTER")
    circle:SetText("O")
    local letter = link:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    letter:SetPoint("CENTER")
    letter:SetText("i")
    link:SetSize(math.ceil(math.max(circle:GetStringWidth(), letter:GetStringWidth()) + 6),
        math.ceil(math.max(circle:GetStringHeight(), letter:GetStringHeight()) + 4))
    link:SetScript("OnClick", function() StaticPopup_Show(popupKey) end)
    return link
end

local CONTROL_X = 340
local function AddSection(content, layout, text)
    layout:Space(14)
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetText(text)
    return layout:Add(label, 24, 20, 6)
end

local function CreateSettingRow(content, layout, text)
    local row = CreateFrame("Frame", nil, content)
    row.LayoutFullWidth = true
    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT")
    label:SetWidth(CONTROL_X - 16)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    layout:Add(row, 24, 32, 6)
    return row, label
end

-- Resolve the adapter when building controls: it loads after this layout module.
-- Pages retain their setters, refresh scope and lifecycle decisions.
local function AddSwitchRow(content, layout, refreshers, text, getter, onChanged)
    local row, label = CreateSettingRow(content, layout, text)
    local toggle = addon.SettingsWidgets.CreateSwitch(row, onChanged)
    toggle:SetPoint("LEFT", row, "LEFT", CONTROL_X, 0)
    refreshers[#refreshers + 1] = function() toggle:SetChecked(getter()) end
    return toggle, label
end

local function AddSwitchStatus(row, anchor, refreshers, getter, onChanged)
    local toggle = addon.SettingsWidgets.CreateSwitch(row, onChanged)
    toggle:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    local status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("LEFT", toggle:GetFrame(), "RIGHT", 8, 0)
    status:SetWidth(56)
    status:SetJustifyH("LEFT")
    local function Refresh()
        local active = getter()
        toggle:SetChecked(active)
        status:SetText(active and "Active" or "Inactive")
    end
    refreshers[#refreshers + 1] = Refresh
    return toggle, status, Refresh
end

local function CreateDropdownRow(content, layout, text, options, onChanged, controlX)
    local row, label = CreateSettingRow(content, layout, text)
    controlX = controlX or CONTROL_X
    label:SetWidth(controlX - 16)
    local dropdown = addon.SettingsWidgets.CreateDropdown(row, options, onChanged)
    dropdown:SetPoint("LEFT", row, "LEFT", controlX, 0)
    return row, dropdown
end

-- Each page chooses action placement; headings remain separate rows.
local function AddPageAction(content, layout, text, onClick, width)
    local button = addon.SettingsWidgets.CreateButton(content, text, onClick, width)
    layout:Add(button:GetFrame(), 24, 24, 8)
    return button
end

local function RunRefreshers(refreshers)
    for _, refresh in ipairs(refreshers) do refresh() end
end

addon.SettingsUI = {
    CreateScrollablePanel = CreateScrollablePanel,
    AddTitle = AddTitle,
    AddDescription = AddDescription,
    CreateInfoLink = CreateInfoLink,
    CreateSettingRow = CreateSettingRow,
    AddSwitchRow = AddSwitchRow,
    AddSwitchStatus = AddSwitchStatus,
    CreateDropdownRow = CreateDropdownRow,
    AddPageAction = AddPageAction,
    CONTROL_X = CONTROL_X,
    AddSection = AddSection,
    RunRefreshers = RunRefreshers,
    RefreshNameplates = RefreshNameplates,
}
addon.SettingsPanels = {}



local UI = addon.SettingsUI
UI.IsSettingsEditable = function() return addon.SettingsWidgets.IsEditingAllowed() end
local combatEvents
function UI.InstallCombatGuard()
    if combatEvents then return end
    combatEvents = CreateFrame("Frame")
    combatEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    local function Update(locked)
        addon.SettingsWidgets.SetCombatLocked(locked)
        if locked and UI.CancelProfileDialogs then UI.CancelProfileDialogs() end
        for _, panel in ipairs(settingsPages) do
            if panel.Refresh then panel.Refresh() end
        end
    end
    combatEvents:SetScript("OnEvent", function(_, event)
        Update(event == "PLAYER_REGEN_DISABLED")
    end)
    Update(not UI.IsSettingsEditable())
end
