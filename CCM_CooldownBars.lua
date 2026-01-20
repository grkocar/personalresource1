-- Core.lua - CkraigCooldownManager (Buff Bars only, stack-count sizing added)
-- Sync with Edit Mode box width slider
local LibEditModeOverride = LibStub("LibEditModeOverride-1.0", true)


-- When custom slider changes, update Edit Mode width
local function SetEditModeWidth(newWidth)
    if not LibEditModeOverride or not _G.BuffBarCooldownViewer then return end
    local frame = _G.BuffBarCooldownViewer
    local setting = Enum.EditModeSetting and Enum.EditModeSetting.Width or "Width"
    pcall(function()
        LibEditModeOverride:SetFrameSetting(frame, setting, newWidth)
        LibEditModeOverride:ApplyChanges()
    end)
end

-- Ensure BuffBarCooldownViewer exists for this addon
if not _G.BuffBarCooldownViewer then
    local f = CreateFrame("Frame", "BuffBarCooldownViewer", UIParent, "BackdropTemplate")
    f:SetSize(220, 300)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if CkraigCooldownManager and CkraigCooldownManager.SaveBuffBarPosition then
            CkraigCooldownManager:SaveBuffBarPosition()
        end
    end)
    f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8})
    f:SetBackdropColor(0,0,0,0.3)
    f:SetBackdropBorderColor(0.2,0.2,0.2,0.8)
    _G.BuffBarCooldownViewer = f
end
local AddonName, Addon = ...
local CkraigCooldownManager = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local FADE_THRESHOLD = 0.3

-- Default DB (change fontSize or stackFontScale here)
local defaults = {
    profile = {
        buffBars = {
            anchorPoint = "CENTER", -- Default anchor
            relativePoint = "CENTER",
            anchorX = 0,
            anchorY = 0,
            enabled = true,
            font = "Friz Quadrata TT",
            fontSize = 11,            -- base font size (pixels)
            barTextFontSize = 11,     -- bar text font size (for bar label)
            stackFontSize = 14,       -- font size for stack/application number
            stackFontOffsetX = 0,     -- X offset for stack/application number
            stackFontOffsetY = 0,     -- Y offset for stack/application number
            stackFontScale = 1.6,     -- multiplier applied when stack > 1
            texture = "Blizzard Raid Bar",
            borderSize = 1.0,
            backdropBorderSize = 1.0,
            borderColor = {r = 0, g = 0, b = 0, a = 1},
            barHeight = 24,
            iconWidth = 24,
            iconHeight = 24,
            barWidth = 200,
            barSpacing = 2,
            showIcon = true,
            useClassColor = true,
            customColor = {r = 0.5, g = 0.5, b = 0.5, a = 1},
            backdropColor = {r = 0, g = 0, b = 0, a = 0.5},
            truncateText = false,
            maxTextWidth = 0,
            frameStrata = "LOW",
            -- Removed duplicate anchorPoint, relativePoint, anchorX, anchorY
            barAlpha = 1.0,
            aspectRatio = "1:1",
            cornerRadius = 0,
            hideBarName = false,
            hideIcons = false,
        },
    }
}

-- Helpers
local function roundPixel(value) return math.floor((value or 0) + 0.5) end

local function GetBuffBarFrames()
    if not BuffBarCooldownViewer then return {} end
    local frames = {}

    if BuffBarCooldownViewer and type(BuffBarCooldownViewer.GetItemFrames) == "function" then
        local ok, items = pcall(function() return BuffBarCooldownViewer:GetItemFrames() end)
        if ok and items and type(items) == "table" then
            for _, f in ipairs(items) do
                if f and f:IsObjectType("Frame") then table.insert(frames, f) end
            end
        end
    end

    if #frames == 0 and BuffBarCooldownViewer and type(BuffBarCooldownViewer.GetChildren) == "function" then
        local ok, children = pcall(function() return { BuffBarCooldownViewer:GetChildren() } end)
        if ok and children then
            for _, child in ipairs(children) do
                if child and child:IsObjectType("Frame") then table.insert(frames, child) end
            end
        end
    end

    local active = {}
    for _, frame in ipairs(frames) do
        if frame and frame:IsShown() and frame:IsVisible() then table.insert(active, frame) end
    end
    return active
end

-- Color helpers
function CkraigCooldownManager:GetClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b, 1
    end
    return 0.5, 0.5, 0.5, 1
end

function CkraigCooldownManager:GetBarColor()
    local cfg = self.db.profile.buffBars
    if cfg.useClassColor then return self:GetClassColor() end
    local c = cfg.customColor or {r=1,g=1,b=1,a=1}
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

-- =========================
-- Stack-count text helpers
-- =========================

local function FindStackFontString(barFrame)
    if not barFrame then return nil end

    local candidates = {
        barFrame.Count, barFrame.CountText, barFrame.StackCount, barFrame.Stack,
        barFrame.CountFontString, barFrame.StackFontString, barFrame.Number
    }

    for _, c in ipairs(candidates) do
        if c and type(c) == "table" and c.IsObjectType and c:IsObjectType("FontString") then
            return c
        end
    end

    if barFrame.GetRegions then
        for i = 1, select("#", barFrame:GetRegions()) do
            local region = select(i, barFrame:GetRegions())
            if region and region.IsObjectType and region:IsObjectType("FontString") then
                local ok, txt = pcall(function() return region:GetText() end)
                txt = ok and txt or ""
                if txt and #txt <= 6 then return region end
            end
        end
    end

    if barFrame.GetChildren then
        for _, child in ipairs({barFrame:GetChildren()}) do
            if child and child.GetRegions then
                for i = 1, select("#", child:GetRegions()) do
                    local region = select(i, child:GetRegions())
                    if region and region.IsObjectType and region:IsObjectType("FontString") then
                        local ok, txt = pcall(function() return region:GetText() end)
                        txt = ok and txt or ""
                        if txt and #txt <= 6 then return region end
                    end
                end
            end
        end
    end

    return nil
end

local function ApplyStackFontToBar(self, barFrame)
    if not barFrame then return end
    local cfg = self.db and self.db.profile and self.db.profile.buffBars
    if not cfg then return end

    local stackFS = FindStackFontString(barFrame)
    if not stackFS then return end


    local fontPath = LSM:Fetch("font", cfg.font) or STANDARD_TEXT_FONT
    local barHeight = cfg.barHeight or 24
    local stackFontSize = math.min(cfg.stackFontSize or 14, barHeight)
    local scale = cfg.stackFontScale or 1.6

    local ok, txt = pcall(function() return stackFS:GetText() end)
    if not ok or not txt then txt = "" end

    -- Only apply stackFontSize if the FontString is attached to the icon (not the duration/cooldown number)
    local parent = stackFS:GetParent() or barFrame
    local isIconFont = false
    if parent and (parent:GetName() or ""):find("Icon") then
        isIconFont = true
    end
    if isIconFont then
        pcall(function() stackFS:SetFont(fontPath, stackFontSize, "OUTLINE") end)
    else
        -- fallback: use bar text font size for non-icon fontstrings
        local barTextFontSize = math.min(cfg.barTextFontSize or cfg.fontSize or 11, barHeight)
        pcall(function() stackFS:SetFont(fontPath, barTextFontSize, "OUTLINE") end)
    end
    pcall(function() stackFS:SetTextColor(1, 1, 1, 1) end)
end

local function UpdateAllStackFonts(self)
    if not BuffBarCooldownViewer or not self.db or not self.db.profile or not self.db.profile.buffBars.enabled then return end
    local bars = GetBuffBarFrames()
    for _, bar in ipairs(bars) do
        local bf = bar.Bar or bar
        pcall(function() ApplyStackFontToBar(self, bf) end)
    end
end

-- =========================
-- Styling and layout
-- =========================

function CkraigCooldownManager:StyleBar(barFrame)
    if not barFrame then return end
    local settings = self.db.profile.buffBars
    local barHeight = settings.barHeight or 24
    local borderSize = settings.borderSize or 0
    local backdropBorderSize = settings.backdropBorderSize or 0
    local borderColor = settings.borderColor or {r=0,g=0,b=0,a=1}
    local backdropColor = settings.backdropColor or {r=0,g=0,b=0,a=0.5}
    local fontPath = LSM:Fetch("font", settings.font) or STANDARD_TEXT_FONT
    local fontSize = settings.barTextFontSize or settings.fontSize or 11
    local texturePath = LSM:Fetch("statusbar", settings.texture) or "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"

    local parent = barFrame:GetParent()

    if barFrame.SetHeight then barFrame:SetHeight(barHeight) end
    if barFrame.SetWidth and settings.barWidth then barFrame:SetWidth(settings.barWidth) end
    if parent and parent.SetWidth and settings.barWidth then parent:SetWidth(settings.barWidth) end
    -- Do NOT set parent (BuffBarCooldownViewer) height/width here; keep it fixed
    -- This prevents the Edit Mode box from stretching to fit all bars
    -- Only the bars themselves should be sized

    if barFrame.SetStatusBarTexture then
        pcall(barFrame.SetStatusBarTexture, barFrame, texturePath)
        local r, g, b, a
        if settings.useClassColor then
            r, g, b, a = self:GetClassColor()
        else
            local barColors = settings.barColors or {}
            local defaultColors = {
                {r=0.2, g=0.9, b=0.2},
                {r=1.0, g=0.9, b=0.1},
                {r=0.2, g=0.6, b=1.0},
                {r=1.0, g=0.4, b=0.2},
                {r=0.8, g=0.2, b=0.8},
                {r=1.0, g=0.2, b=0.2},
            }
            local barIndex = barFrame._bb_barIndex or barFrame.barIndex or barFrame.index or 1
            local color = barColors[barIndex] or defaultColors[((barIndex-1)%#defaultColors)+1]
            r = tonumber(color.r) or 1
            g = tonumber(color.g) or 1
            b = tonumber(color.b) or 1
            a = 1
        end
        if barFrame.SetStatusBarColor then pcall(barFrame.SetStatusBarColor, barFrame, r, g, b, a) end
    end

    if not barFrame._bb_backdrop then
        barFrame._bb_backdrop = CreateFrame("Frame", nil, barFrame, "BackdropTemplate")
    end
    local bg = barFrame._bb_backdrop
    bg:ClearAllPoints()
    bg:SetPoint("TOPLEFT", barFrame, -backdropBorderSize, backdropBorderSize)
    bg:SetPoint("BOTTOMRIGHT", barFrame, backdropBorderSize, -backdropBorderSize)
    bg:SetFrameLevel(math.max(0, (barFrame:GetFrameLevel() or 0) - 1))
    bg:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=backdropBorderSize})
    bg:SetBackdropColor(backdropColor.r, backdropColor.g, backdropColor.b, backdropColor.a)
    bg:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    bg:Show()

    if parent then
        if borderSize > 0 then
            if not parent._bb_outer_border then
                parent._bb_outer_border = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            end
            local outer = parent._bb_outer_border
            outer:ClearAllPoints()
            outer:SetPoint("TOPLEFT", parent, -borderSize, borderSize)
            outer:SetPoint("BOTTOMRIGHT", parent, borderSize, -borderSize)
            outer:SetFrameLevel(math.max(0, (parent:GetFrameLevel() or 0) - 1))
            outer:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=borderSize})
            outer:SetBackdropColor(0,0,0,0)
            -- Make the border fully transparent
            outer:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 0)
            outer:Show()
        elseif parent._bb_outer_border then
            parent._bb_outer_border:Hide()
        end
    end

    -- Icon handling (improved cropping)
    local iconContainer = parent and (parent.Icon or parent.icon or parent.IconTexture)
    if iconContainer then
        local iconW = math.min(settings.iconWidth or settings.barHeight or 24, barHeight)
        local iconH = math.min(settings.iconHeight or settings.barHeight or 24, barHeight)
        if settings.hideIcons then
            -- Only hide the texture, not the Applications FontString
            if iconContainer:IsObjectType("Texture") then
                iconContainer:Hide()
                if parent and parent.Icon and parent.Icon.Applications then
                    parent.Icon.Applications:Show()
                end
            else
                local childTex = iconContainer.icon or iconContainer.Icon or iconContainer.IconTexture or iconContainer.Texture
                if childTex and childTex:IsObjectType("Texture") then
                    childTex:Hide()
                end
                if iconContainer.Applications then
                    iconContainer.Applications:Show()
                end
            end
        else
            -- Always show the icon texture when un-hiding icons
            if iconContainer:IsObjectType("Texture") then
                iconContainer:Show()
                pcall(iconContainer.SetSize, iconContainer, iconW, iconH)
            else
                local childTex = iconContainer.icon or iconContainer.Icon or iconContainer.IconTexture or iconContainer.Texture
                if childTex and childTex.IsObjectType and childTex:IsObjectType("Texture") then
                    childTex:Show()
                    pcall(iconContainer.SetSize, iconContainer, iconW, iconH)
                end
            end
            if parent and parent.Icon and parent.Icon.Applications then
                parent.Icon.Applications:Show()
            end
            if iconContainer.Applications then
                iconContainer.Applications:Show()
            end
        end
        -- If there are multiple icons, ensure they are centered and do not exceed bar height
        if parent and parent.Icons and type(parent.Icons) == "table" then
            local totalWidth = 0
            for _, ic in ipairs(parent.Icons) do
                if ic.SetSize then ic:SetSize(iconW, iconH) end
                totalWidth = totalWidth + iconW
            end
            -- Center icons horizontally if needed
            if parent.SetWidth then
                local barWidth = CkraigCooldownManager and CkraigCooldownManager.db and CkraigCooldownManager.db.profile and CkraigCooldownManager.db.profile.buffBars and CkraigCooldownManager.db.profile.buffBars.barWidth or settings.barWidth or 200
                parent:SetWidth(barWidth)
            end
        end
    end

    if barFrame.GetRegions then
        for i = 1, select("#", barFrame:GetRegions()) do
            local region = select(i, barFrame:GetRegions())
            if region and region:IsObjectType("Texture") then
                local keep = false
                if barFrame.GetStatusBarTexture and region == barFrame:GetStatusBarTexture() then keep = true end
                if not keep then pcall(region.SetTexture, region, nil); pcall(region.Hide, region) end
            end
        end
    end

    local nameFS = barFrame.Name or barFrame.Text
    if nameFS and nameFS.SetFont then
        if settings.hideBarName then
            nameFS:Hide()
        else
            nameFS:Show()
            pcall(nameFS.SetFont, nameFS, fontPath, fontSize, "OUTLINE")
            pcall(nameFS.SetTextColor, nameFS,1,1,1,1)
        end
    end
    local timeFS = barFrame.TimeLeft or barFrame.Duration
    if timeFS and timeFS.SetFont then
        pcall(timeFS.SetFont, timeFS, fontPath, fontSize, "OUTLINE")
            local color = {r=1, g=1, b=1, a=1} -- default white
            local ok, txt = pcall(function() return timeFS:GetText() end)
            local seconds = tonumber(txt)
            if seconds then
                if seconds >= 1 and seconds <= 6 then
                    color = {r=1, g=0, b=0, a=1} -- red
                elseif seconds >= 7 and seconds <= 10 then
                    color = {r=1, g=0.95, b=0.6, a=1} -- yellow
                elseif seconds >= 11 and seconds <= 100 then
                    color = {r=1, g=1, b=1, a=1} -- white
                end
            end
            pcall(timeFS.SetTextColor, timeFS, color.r, color.g, color.b, color.a)
    end

    if self.ApplyBarFrameSettings then pcall(self.ApplyBarFrameSettings, self, barFrame) end

    -- Only modify the stack/count FontString (no other changes)
    pcall(function() ApplyStackFontToBar(self, barFrame) end)

    -- Always set stack/application font and position if Applications FontString exists
    if parent and parent.Icon and parent.Icon.Applications and parent.Icon.Applications.SetFont then
        local fontPath = LSM:Fetch("font", settings.font) or STANDARD_TEXT_FONT
        local baseSize = math.min(14, barHeight)
        local mult = settings.stackFontSize and (settings.stackFontSize / 14) or 1.0
        parent.Icon.Applications:SetFont(fontPath, baseSize * mult, "OUTLINE")
        parent.Icon.Applications:ClearAllPoints()
        parent.Icon.Applications:SetPoint("CENTER", parent.Icon, "CENTER", settings.stackFontOffsetX or 0, settings.stackFontOffsetY or 0)
        parent.Icon.Applications:Show()
    end
    if iconContainer and iconContainer.Applications and iconContainer.Applications.SetFont then
        local fontPath = LSM:Fetch("font", settings.font) or STANDARD_TEXT_FONT
        local baseSize = math.min(14, barHeight)
        local mult = settings.stackFontSize and (settings.stackFontSize / 14) or 1.0
        iconContainer.Applications:SetFont(fontPath, baseSize * mult, "OUTLINE")
        iconContainer.Applications:ClearAllPoints()
        iconContainer.Applications:SetPoint("CENTER", iconContainer, "CENTER", settings.stackFontOffsetX or 0, settings.stackFontOffsetY or 0)
        iconContainer.Applications:Show()
    end
end

function CkraigCooldownManager:RepositionAllBars()
    if not BuffBarCooldownViewer or not self.db.profile.buffBars.enabled then return end
    local bars = GetBuffBarFrames()
    local settings = self.db.profile.buffBars
    local barHeight, spacing = settings.barHeight or 24, settings.barSpacing or 2
    local parentHeight = BuffBarCooldownViewer:GetHeight() or 300
    local maxBars = math.floor((parentHeight + spacing) / (barHeight + spacing))

    for i, bar in ipairs(bars) do
        if bar and bar.ClearAllPoints then bar:ClearAllPoints() end
        if i <= maxBars then
            local y = roundPixel((i - 1) * (barHeight + spacing))
            if bar.SetPoint then pcall(bar.SetPoint, bar, "BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, y) end
            local barObj = bar.Bar or bar
            barObj._bb_barIndex = i
            self:StyleBar(barObj)
            bar:Show()
        else
            bar:Hide()
        end
    end
end

function CkraigCooldownManager:CheckExpiringBars()
    if not BuffBarCooldownViewer then return end
    for _, frame in ipairs(GetBuffBarFrames()) do
        if frame.cooldownInfo and frame.cooldownInfo.duration then
            local duration, startTime = frame.cooldownInfo.duration, frame.cooldownInfo.startTime
            if duration and startTime and duration > 0 then
                local remaining = (startTime + duration) - GetTime()
                if remaining <= FADE_THRESHOLD and remaining > 0 then
                    local fadeProgress = 1 - (remaining / FADE_THRESHOLD)
                    frame:SetAlpha(1 - fadeProgress)
                    frame._bb_fading = true
                elseif remaining <= 0 then
                    frame:SetAlpha(0)
                    frame:Hide()
                    frame._bb_fading = false
                elseif frame._bb_fading then
                    frame:SetAlpha(1)
                    frame._bb_fading = false
                end
            end
        end
    end
end

function CkraigCooldownManager:SaveBuffBarPosition()
    if not BuffBarCooldownViewer then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = BuffBarCooldownViewer:GetPoint(1)
    if not point or not xOfs or not yOfs then return end
    local settings = self.db.profile.buffBars
    settings.anchorPoint = point
    settings.relativePoint = relativePoint or point
    settings.anchorX = xOfs
    settings.anchorY = yOfs
    print("|cff00ff00BetterBuffs:|r Position saved ("..point.." "..math.floor(xOfs)..","..math.floor(yOfs)..")")
end

function CkraigCooldownManager:LoadBuffBarPosition()
    if not BuffBarCooldownViewer then return end
    local s = self.db.profile.buffBars
    local point, relativePoint, x, y = s.anchorPoint, s.relativePoint, s.anchorX, s.anchorY
    BuffBarCooldownViewer:ClearAllPoints()
    if point and x and y then
        BuffBarCooldownViewer:SetPoint(point, UIParent, relativePoint or point, x, y)
        print("|cff00ff00BetterBuffs:|r Position loaded ("..point.." "..math.floor(x)..","..math.floor(y)..")")
    else
        BuffBarCooldownViewer:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("|cff00ff00BetterBuffs:|r Using default position")
    end
end

function CkraigCooldownManager:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("DYNAMICBARSDB", defaults, true)
    if not LSM:IsValid("font","Friz Quadrata TT") then LSM:Register("font","Friz Quadrata TT","Fonts\\FRIZQT__.TTF") end
    if not LSM:IsValid("statusbar","Blizzard Raid Bar") then LSM:Register("statusbar","Blizzard Raid Bar","Interface\\RaidFrame\\Raid-Bar-Hp-Fill") end
    LSM.RegisterCallback(self,"LibSharedMedia_Registered", function() self:RepositionAllBars() end)
    if self.SetupOptions then self:SetupOptions() end
    -- Always load position on init
    if self.LoadBuffBarPosition then self:LoadBuffBarPosition() end
end

function CkraigCooldownManager:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN", function()
        if BuffBarCooldownViewer then
            self:LoadBuffBarPosition()
            self:RepositionAllBars()
        end
    end)

    if not self._bb_updateFrame then
        self._bb_updateFrame = CreateFrame("Frame")
        self._bb_updateFrame:SetScript("OnUpdate", function()
            if self.db and self.db.profile and self.db.profile.buffBars.enabled then
                self:RepositionAllBars()
                self:CheckExpiringBars()
                UpdateAllStackFonts(self) -- updates only stack/count text sizing
            end
        end)
    end
    self._bb_updateFrame:Show()

    SLASH_BETTERBUFFSDEBUG1 = "/bbdebug"
    -- Removed orphaned debug code and unexpected 'end'
end


-- Options panel for bar settings (CkraigCooldownManager)


-- Helper: Attach middle-click input box to a slider
local function AttachSliderInputBox(slider, minValue, maxValue, onValueSet)
    local editBox = CreateFrame("EditBox", nil, slider, "BackdropTemplate")
    editBox:SetAutoFocus(true)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetSize(60, 24)
    editBox:SetJustifyH("CENTER")
    editBox:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 }})
    editBox:SetBackdropColor(0,0,0,0.8)
    editBox:Hide()
    editBox:SetScript("OnEscapePressed", function(self) self:Hide() end)
    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(minValue, math.min(maxValue, val))
            slider:SetValue(val)
            if onValueSet then onValueSet(val) end
        end
        self:Hide()
    end)
    editBox:SetScript("OnEditFocusLost", function(self) self:Hide() end)
    slider:HookScript("OnMouseDown", function(self, btn)
        if btn == "MiddleButton" then
            editBox:SetText(tostring(math.floor(self:GetValue())))
            editBox:SetPoint("CENTER", self, "CENTER")
            editBox:Show()
            editBox:SetFocus()
        end
    end)
end

local function CreateCkraigBarOptionsPanel()

    local panel = CreateFrame("Frame", "CkraigBarOptionsPanel", UIParent)
    panel.name = "Cooldown Bars"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ckraig Cooldown Bar Settings")

    -- Texture Dropdown
    local texLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    texLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    texLabel:SetText("Bar Texture:")
    texLabel:SetTextColor(0.9,0.9,0.9,1)

    local texDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    texDropdown:SetPoint("LEFT", texLabel, "RIGHT", -10, 2)
    texDropdown:SetWidth(160)

    local function RefreshTextureDropdown()
        local textures = LSM and LSM:List("statusbar") or {"Blizzard Raid Bar"}
        local selectedTexture = CkraigCooldownManager.db.profile.buffBars.texture or textures[1]
        UIDropDownMenu_Initialize(texDropdown, function(self, level, menuList)
            for i, tex in ipairs(textures) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = tex
                info.checked = (tex == selectedTexture)
                info.func = function()
                    selectedTexture = tex
                    CkraigCooldownManager.db.profile.buffBars.texture = tex
                    UIDropDownMenu_SetSelectedName(texDropdown, tex)
                    if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedName(texDropdown, selectedTexture)
        UIDropDownMenu_SetWidth(texDropdown, 140)
        UIDropDownMenu_SetButtonWidth(texDropdown, 160)
        UIDropDownMenu_JustifyText(texDropdown, "LEFT")
    end
    texDropdown:HookScript("OnShow", RefreshTextureDropdown)
    texDropdown:HookScript("OnMouseDown", RefreshTextureDropdown)
    RefreshTextureDropdown()


    -- Bar Height Slider
    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", texLabel, "BOTTOMLEFT", 0, -24)
    heightLabel:SetText("Bar Height:")
    heightLabel:SetTextColor(0.9,0.9,0.9,1)
    local heightSlider = CreateFrame("Slider", "CkraigBarOptionsPanelHeightSlider", panel, "OptionsSliderTemplate")
    heightSlider:SetPoint("LEFT", heightLabel, "RIGHT", 8, 0)
    heightSlider:SetMinMaxValues(10, 54)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(120)
    heightSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barHeight or 24)
    heightSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.barHeight = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)
    _G[heightSlider:GetName() .. 'Low']:SetText("10")
    _G[heightSlider:GetName() .. 'High']:SetText("55")
    _G[heightSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barHeight or 24))
    AttachSliderInputBox(heightSlider, 10, 60, function(val)
        CkraigCooldownManager.db.profile.buffBars.barHeight = math.floor(val)
        _G[heightSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)


    -- Bar Text Font Size Slider
    local barTextFontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barTextFontLabel:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, -36)
    barTextFontLabel:SetText("Bar Text Font Size:")
    barTextFontLabel:SetTextColor(0.9,0.9,0.9,1)
    local barTextFontSlider = CreateFrame("Slider", "CkraigBarOptionsPanelBarTextFontSlider", panel, "OptionsSliderTemplate")
    barTextFontSlider:SetPoint("LEFT", barTextFontLabel, "RIGHT", 8, 0)
    barTextFontSlider:SetMinMaxValues(6, 36)
    barTextFontSlider:SetValueStep(1)
    barTextFontSlider:SetObeyStepOnDrag(true)
    barTextFontSlider:SetWidth(120)
    barTextFontSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barTextFontSize or 11)
    barTextFontSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.barTextFontSize = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)
    _G[barTextFontSlider:GetName() .. 'Low']:SetText("6")
    _G[barTextFontSlider:GetName() .. 'High']:SetText("36")
    _G[barTextFontSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barTextFontSize or 11))
    AttachSliderInputBox(barTextFontSlider, 6, 36, function(val)
        CkraigCooldownManager.db.profile.buffBars.barTextFontSize = math.floor(val)
        _G[barTextFontSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Stack/Application Font Size Slider
    local stackFontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackFontLabel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -60, -120)
    stackFontLabel:SetText("Stack/Application Font Size:")
    stackFontLabel:SetTextColor(0.9,0.9,0.9,1)
    local stackFontSlider = CreateFrame("Slider", "CkraigBarOptionsPanelStackFontSlider", panel, "OptionsSliderTemplate")
    stackFontSlider:SetPoint("TOPLEFT", stackFontLabel, "BOTTOMLEFT", 0, -8)
    stackFontSlider:SetMinMaxValues(6, 36)
    stackFontSlider:SetValueStep(1)
    stackFontSlider:SetObeyStepOnDrag(true)
    stackFontSlider:SetWidth(120)
    stackFontSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.stackFontSize or 14)
    stackFontSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.stackFontSize = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)
    _G[stackFontSlider:GetName() .. 'Low']:SetText("6")
    _G[stackFontSlider:GetName() .. 'High']:SetText("36")
    _G[stackFontSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.stackFontSize or 14))
    AttachSliderInputBox(stackFontSlider, 6, 36, function(val)
        CkraigCooldownManager.db.profile.buffBars.stackFontSize = math.floor(val)
        _G[stackFontSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Stack/Application Number X Offset Slider
    local stackFontXLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackFontXLabel:SetPoint("TOPLEFT", stackFontSlider, "BOTTOMLEFT", 0, -18)
    stackFontXLabel:SetText("Stack/Application Number X Offset:")
    stackFontXLabel:SetTextColor(0.9,0.9,0.9,1)
    local stackFontXSlider = CreateFrame("Slider", "CkraigBarOptionsPanelStackFontXSlider", panel, "OptionsSliderTemplate")
    stackFontXSlider:SetPoint("TOPLEFT", stackFontXLabel, "BOTTOMLEFT", 0, -8)
    stackFontXSlider:SetMinMaxValues(-50, 50)
    stackFontXSlider:SetValueStep(1)
    stackFontXSlider:SetObeyStepOnDrag(true)
    stackFontXSlider:SetWidth(120)
    stackFontXSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.stackFontOffsetX or 0)
    stackFontXSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.stackFontOffsetX = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)
    _G[stackFontXSlider:GetName() .. 'Low']:SetText("-50")
    _G[stackFontXSlider:GetName() .. 'High']:SetText("50")
    _G[stackFontXSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.stackFontOffsetX or 0))
    AttachSliderInputBox(stackFontXSlider, -50, 50, function(val)
        CkraigCooldownManager.db.profile.buffBars.stackFontOffsetX = math.floor(val)
        _G[stackFontXSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Stack/Application Number Y Offset Slider
    local stackFontYLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackFontYLabel:SetPoint("TOPLEFT", stackFontXSlider, "BOTTOMLEFT", 0, -18)
    stackFontYLabel:SetText("Stack/Application Number Y Offset:")
    stackFontYLabel:SetTextColor(0.9,0.9,0.9,1)
    local stackFontYSlider = CreateFrame("Slider", "CkraigBarOptionsPanelStackFontYSlider", panel, "OptionsSliderTemplate")
    stackFontYSlider:SetPoint("TOPLEFT", stackFontYLabel, "BOTTOMLEFT", 0, -8)
    stackFontYSlider:SetMinMaxValues(-50, 50)
    stackFontYSlider:SetValueStep(1)
    stackFontYSlider:SetObeyStepOnDrag(true)
    stackFontYSlider:SetWidth(120)
    stackFontYSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.stackFontOffsetY or 0)
    stackFontYSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.stackFontOffsetY = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)
    _G[stackFontYSlider:GetName() .. 'Low']:SetText("-50")
    _G[stackFontYSlider:GetName() .. 'High']:SetText("50")
    _G[stackFontYSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.stackFontOffsetY or 0))
    AttachSliderInputBox(stackFontYSlider, -50, 50, function(val)
        CkraigCooldownManager.db.profile.buffBars.stackFontOffsetY = math.floor(val)
        _G[stackFontYSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)


    -- Bar Width Slider
    local widthLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", barTextFontLabel, "BOTTOMLEFT", 0, -36)
    widthLabel:SetText("Bar Width:")
    widthLabel:SetTextColor(0.9,0.9,0.9,1)
    local widthSlider = CreateFrame("Slider", "CkraigBarOptionsPanelWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("LEFT", widthLabel, "RIGHT", 8, 0)
    widthSlider:SetMinMaxValues(50, 400)
    widthSlider:SetValueStep(1)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(120)
    widthSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barWidth or 200)
    widthSlider:HookScript("OnValueChanged", function(self, value)
        local newWidth = math.floor(value)
        CkraigCooldownManager.db.profile.buffBars.barWidth = newWidth
        _G[self:GetName() .. 'Text']:SetText(tostring(newWidth))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
        SetEditModeWidth(value)
    end)
    _G[widthSlider:GetName() .. 'Low']:SetText("50")
    _G[widthSlider:GetName() .. 'High']:SetText("400")
    _G[widthSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barWidth or 200))
    AttachSliderInputBox(widthSlider, 50, 400, function(val)
        CkraigCooldownManager.db.profile.buffBars.barWidth = math.floor(val)
        _G[widthSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)


    -- Bar Spacing Slider
    local spacingLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spacingLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -36)
    spacingLabel:SetText("Bar Spacing:")
    spacingLabel:SetTextColor(0.9,0.9,0.9,1)
    local spacingSlider = CreateFrame("Slider", "CkraigBarOptionsPanelSpacingSlider", panel, "OptionsSliderTemplate")
    spacingSlider:SetPoint("LEFT", spacingLabel, "RIGHT", 8, 0)
    spacingSlider:SetMinMaxValues(0, 9)
    spacingSlider:SetValueStep(1)
    spacingSlider:SetObeyStepOnDrag(true)
    spacingSlider:SetWidth(120)
    spacingSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barSpacing or 2)
    spacingSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.barSpacing = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
    end)
    _G[spacingSlider:GetName() .. 'Low']:SetText("0")
    _G[spacingSlider:GetName() .. 'High']:SetText("9")
    _G[spacingSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barSpacing or 2))
    AttachSliderInputBox(spacingSlider, 0, 9, function(val)
        CkraigCooldownManager.db.profile.buffBars.barSpacing = math.floor(val)
        _G[spacingSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
    end)

    -- Use Class Color Checkbox
    local classColorCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    classColorCheck:SetPoint("TOPLEFT", spacingLabel, "BOTTOMLEFT", -10, -24)
    classColorCheck.text = classColorCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classColorCheck.text:SetPoint("LEFT", classColorCheck, "RIGHT", 4, 0)
    classColorCheck.text:SetText("Use Class Color for Bars")
    classColorCheck:SetChecked(CkraigCooldownManager.db.profile.buffBars.useClassColor or false)
    classColorCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.useClassColor = self:GetChecked()
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- 12 Color Pickers
    local colorPickers = {}
    local colorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", classColorCheck, "BOTTOMLEFT", 0, -24)
    colorLabel:SetText("Bar Colors:")
    colorLabel:SetTextColor(0.9,0.9,0.9,1)

    local panelWidth = 420
    local rightAnchorX = panelWidth - 180
    local colSpacing = 80
    local rowSpacing = -4
    local firstRowY = 30
    local colorPickersYOffset = -220 - 300
    for i = 1, 12 do
        local picker = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate,BackdropTemplate")
        picker:SetSize(60, 22)
        colorPickers[i] = picker
    end
    for i = 1, 12 do
        local picker = colorPickers[i]
        local col = (i <= 6) and 0 or 1
        local row = (i - 1) % 6
        picker:SetPoint(
            "TOPLEFT",
            panel,
            "TOPLEFT",
            rightAnchorX + col * colSpacing + 30,
            colorPickersYOffset + firstRowY + row * (22 + rowSpacing)
        )
        picker:SetText("Bar "..i)
        picker.colorIndex = i
        picker:SetScript("OnClick", function(self)
            local db = CkraigCooldownManager.db
            local barColors = db.profile.buffBars.barColors or {}
            local defaultColors = {
                {r=0.2, g=0.9, b=0.2},
                {r=1.0, g=0.9, b=0.1},
                {r=0.2, g=0.6, b=1.0},
                {r=1.0, g=0.4, b=0.2},
                {r=0.8, g=0.2, b=0.8},
                {r=1.0, g=0.2, b=0.2},
            }
            local colorCount = #defaultColors
            local c = barColors[i] or defaultColors[((i-1)%colorCount)+1]
            if ColorPickerFrame and ColorPickerFrame.SetColorRGB then
                local r = tonumber(c and c.r) or 1
                local g = tonumber(c and c.g) or 1
                local b = tonumber(c and c.b) or 1
                ColorPickerFrame:SetColorRGB(r, g, b)
            end
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = {c and c.r or 1, c and c.g or 1, c and c.b or 1}
            -- Removed duplicate ColorPickerFrame.func and cancelFunc assignments
            ColorPickerFrame.swatchFunc = ColorPickerFrame.func
            ColorPickerFrame:Show()
        end)
        picker:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        local db = CkraigCooldownManager.db.profile.buffBars.barColors or {}
        local defaultColors = {
            {r=0.2, g=0.9, b=0.2},
            {r=1.0, g=0.9, b=0.1},
            {r=0.2, g=0.6, b=1.0},
            {r=1.0, g=0.4, b=0.2},
            {r=0.8, g=0.2, b=0.8},
            {r=1.0, g=0.2, b=0.2},
        }
        local colorCount = #defaultColors
        local c = db[i] or defaultColors[((i-1)%colorCount)+1]
        local r = tonumber(c and c.r) or 1
        local g = tonumber(c and c.g) or 1
        local b = tonumber(c and c.b) or 1
        picker:SetBackdropColor(r, g, b, 1)
    end
    -- Disable color pickers if class color is enabled
    for _, picker in ipairs(colorPickers) do
        picker:SetEnabled(not (CkraigCooldownManager.db.profile.buffBars.useClassColor or false))
    end
    classColorCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.useClassColor = self:GetChecked()
        for _, picker in ipairs(colorPickers) do
            picker:SetEnabled(not self:GetChecked())
        end
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Font Dropdowns
    local fontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -32)
    fontLabel:SetText("Bar Text Font:")
    fontLabel:SetTextColor(0.9,0.9,0.9,1)

    local fontDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("LEFT", fontLabel, "RIGHT", -10, 2)
    fontDropdown:SetWidth(160)

    local function RefreshFontDropdown()
        local fonts = LSM and LSM:List("font") or {"Friz Quadrata TT"}
        local selectedFont = CkraigCooldownManager.db.profile.buffBars.font or fonts[1]
        UIDropDownMenu_Initialize(fontDropdown, function(self, level, menuList)
            for i, font in ipairs(fonts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = font
                info.checked = (font == selectedFont)
                info.func = function()
                    selectedFont = font
                    CkraigCooldownManager.db.profile.buffBars.font = font
                    UIDropDownMenu_SetSelectedName(fontDropdown, font)
                    if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedName(fontDropdown, selectedFont)
        UIDropDownMenu_SetWidth(fontDropdown, 140)
        UIDropDownMenu_SetButtonWidth(fontDropdown, 160)
        UIDropDownMenu_JustifyText(fontDropdown, "LEFT")
    end
    fontDropdown:HookScript("OnShow", RefreshFontDropdown)
    fontDropdown:HookScript("OnMouseDown", RefreshFontDropdown)
    RefreshFontDropdown()



    _G.CkraigBarOptionsPanel = panel
    -- Add creator note at bottom left
    local creatorNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    creatorNote:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    creatorNote:SetText("ORIGINAL CREATOR LAZARPAKY LAZARUI")
    creatorNote:SetTextColor(0.2, 1, 0.2, 1)

    -- Place checkboxes above the creator note at the bottom left
    local hideIconsCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    if creatorNote then
        hideIconsCheck:SetPoint("BOTTOMLEFT", creatorNote, "TOPLEFT", 0, 8)
    else
        hideIconsCheck:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 40)
    end
    hideIconsCheck.text = hideIconsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideIconsCheck.text:SetPoint("LEFT", hideIconsCheck, "RIGHT", 4, 0)

    hideIconsCheck.text:SetText("Hide Icons")
    hideIconsCheck:SetChecked(CkraigCooldownManager.db.profile.buffBars.hideIcons or false)
    hideIconsCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.hideIcons = self:GetChecked()
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Add red warning note next to Hide Icons checkbox
    local hideIconsNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideIconsNote:SetPoint("LEFT", hideIconsCheck.text, "RIGHT", 12, 0)
    hideIconsNote:SetText("(If you hide icons here, set display mode to Name Only in Edit Mode)")
    hideIconsNote:SetTextColor(1, 0.1, 0.1, 1)

    local hideNameCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    hideNameCheck:SetPoint("BOTTOMLEFT", hideIconsCheck, "TOPLEFT", 0, 8)
    hideNameCheck.text = hideNameCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideNameCheck.text:SetPoint("LEFT", hideNameCheck, "RIGHT", 4, 0)
    hideNameCheck.text:SetText("Hide Bar Name")
    hideNameCheck:SetChecked(CkraigCooldownManager.db.profile.buffBars.hideBarName or false)
    hideNameCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.hideBarName = self:GetChecked()
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Minimap Button Checkbox (top right corner)
    local minimapCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("RIGHT", panel, "TOPRIGHT", -140, -24)
    minimapCheck.text = minimapCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    minimapCheck.text:SetPoint("LEFT", minimapCheck, "RIGHT", 4, 0)
    minimapCheck.text:SetText("Show Minimap Button")
    minimapCheck:SetChecked(not (CkraigCooldownManager.db.profile.minimap and CkraigCooldownManager.db.profile.minimap.hide))
    minimapCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.minimap = CkraigCooldownManager.db.profile.minimap or {}
        CkraigCooldownManager.db.profile.minimap.hide = not self:GetChecked()
        if DBIcon and DBIcon.IsRegistered and DBIcon:IsRegistered("CkraigCooldownBars") then
            DBIcon:Refresh("CkraigCooldownBars", CkraigCooldownManager.db.profile.minimap)
        end
    end)
    return panel
end

-- Register options panel in Blizzard settings UI (Dragonflight+)
local function RegisterCkraigBarOptions()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then return end
    CreateCkraigBarOptionsPanel()
    local parentPanel = _G.CkraigBarOptionsPanel
    local parent = Settings.RegisterCanvasLayoutCategory(parentPanel, "Cooldown Bars")
    Settings.RegisterAddOnCategory(parent)
end

local optionsInit = CreateFrame("Frame")
optionsInit:RegisterEvent("PLAYER_LOGIN")
optionsInit:SetScript("OnEvent", RegisterCkraigBarOptions)

_G["CkraigCooldownManagersBarsOnly"] = CkraigCooldownManager

-- =========================
-- Minimap Icon and Config Panel
-- =========================

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local minimapLDB

local function CreateCkraigBarOptionsPanel()
    if _G.CkraigBarOptionsPanel then
        return _G.CkraigBarOptionsPanel
    end
    local panel = CreateFrame("Frame", "CkraigBarOptionsPanel", UIParent)
    panel.name = "Cooldown Bars"

    local yOffset = -16
    local function nextYOffset(amount)
        yOffset = yOffset - (amount or 36)
        return yOffset
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, yOffset)
    title:SetText("Ckraig Cooldown Bar Settings")

    -- Bar Texture
    local texLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    texLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, nextYOffset(24))
    texLabel:SetText("Bar Texture:")
    texLabel:SetTextColor(0.9,0.9,0.9,1)
    local texDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    texDropdown:SetPoint("LEFT", texLabel, "RIGHT", -10, 2)
    texDropdown:SetWidth(160)
    local function RefreshTextureDropdown()
        local textures = LSM and LSM:List("statusbar") or {"Blizzard Raid Bar"}
        local selectedTexture = CkraigCooldownManager.db.profile.buffBars.texture or textures[1]
        UIDropDownMenu_Initialize(texDropdown, function(self, level, menuList)
            for i, tex in ipairs(textures) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = tex
                info.checked = (tex == selectedTexture)
                info.func = function()
                    selectedTexture = tex
                    CkraigCooldownManager.db.profile.buffBars.texture = tex
                    UIDropDownMenu_SetSelectedName(texDropdown, tex)
                    if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedName(texDropdown, selectedTexture)
        UIDropDownMenu_SetWidth(texDropdown, 140)
        UIDropDownMenu_SetButtonWidth(texDropdown, 160)
        UIDropDownMenu_JustifyText(texDropdown, "LEFT")
    end
    texDropdown:HookScript("OnShow", RefreshTextureDropdown)
    texDropdown:HookScript("OnMouseDown", RefreshTextureDropdown)
    RefreshTextureDropdown()

    -- Bar Height
    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", texLabel, "BOTTOMLEFT", 0, nextYOffset())
    heightLabel:SetText("Bar Height:")
    heightLabel:SetTextColor(0.9,0.9,0.9,1)
    local heightSlider = CreateFrame("Slider", "CkraigBarOptionsPanelHeightSlider", panel, "OptionsSliderTemplate")
    heightSlider:SetPoint("LEFT", heightLabel, "RIGHT", 8, 0)
    heightSlider:SetMinMaxValues(10, 54)
    heightSlider:SetValueStep(1)
    heightSlider:SetObeyStepOnDrag(true)
    heightSlider:SetWidth(120)
    heightSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barHeight or 24)
    heightSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.barHeight = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
    end)
    _G[heightSlider:GetName() .. 'Low']:SetText("10")
    _G[heightSlider:GetName() .. 'High']:SetText("60")
    _G[heightSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barHeight or 24))

    -- Bar Text Font Size
    local barTextFontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barTextFontLabel:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, nextYOffset())
    barTextFontLabel:SetText("Bar Text Font Size:")
    barTextFontLabel:SetTextColor(0.9,0.9,0.9,1)
    local barTextFontSlider = CreateFrame("Slider", "CkraigBarOptionsPanelBarTextFontSlider", panel, "OptionsSliderTemplate")
    barTextFontSlider:SetPoint("LEFT", barTextFontLabel, "RIGHT", 8, 0)
    barTextFontSlider:SetMinMaxValues(6, 36)
    barTextFontSlider:SetValueStep(1)
    barTextFontSlider:SetObeyStepOnDrag(true)
    barTextFontSlider:SetWidth(120)
    barTextFontSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barTextFontSize or 11)
    barTextFontSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.barTextFontSize = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)
    _G[barTextFontSlider:GetName() .. 'Low']:SetText("6")
    _G[barTextFontSlider:GetName() .. 'High']:SetText("36")
    _G[barTextFontSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barTextFontSize or 11))

    -- Stack/Application Font Size
    local stackFontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stackFontLabel:SetPoint("TOPLEFT", barTextFontLabel, "BOTTOMLEFT", 0, nextYOffset())
    stackFontLabel:SetText("Stack/Application Font Size:")
    stackFontLabel:SetTextColor(0.9,0.9,0.9,1)
    local stackFontSlider = CreateFrame("Slider", "CkraigBarOptionsPanelStackFontSlider", panel, "OptionsSliderTemplate")
    stackFontSlider:SetPoint("LEFT", stackFontLabel, "RIGHT", 8, 0)
    stackFontSlider:SetMinMaxValues(6, 36)
    stackFontSlider:SetValueStep(1)
    stackFontSlider:SetObeyStepOnDrag(true)
    stackFontSlider:SetWidth(120)
    stackFontSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.stackFontSize or 14)
    stackFontSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.stackFontSize = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)
    _G[stackFontSlider:GetName() .. 'Low']:SetText("6")
    _G[stackFontSlider:GetName() .. 'High']:SetText("36")
    _G[stackFontSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.stackFontSize or 14))

    -- Bar Width
    local widthLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", stackFontLabel, "BOTTOMLEFT", 0, nextYOffset())
    widthLabel:SetText("Bar Width:")
    widthLabel:SetTextColor(0.9,0.9,0.9,1)
    local widthSlider = CreateFrame("Slider", "CkraigBarOptionsPanelWidthSlider", panel, "OptionsSliderTemplate")
    widthSlider:SetPoint("LEFT", widthLabel, "RIGHT", 8, 0)
    widthSlider:SetMinMaxValues(50, 400)
    widthSlider:SetValueStep(1)
    widthSlider:SetObeyStepOnDrag(true)
    widthSlider:SetWidth(120)
    widthSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barWidth or 200)
    widthSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.barWidth = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
        SetEditModeWidth(value)
    end)
    _G[widthSlider:GetName() .. 'Low']:SetText("50")
    _G[widthSlider:GetName() .. 'High']:SetText("400")
    _G[widthSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barWidth or 200))

    -- Bar Spacing
    local spacingLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spacingLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, nextYOffset())
    spacingLabel:SetText("Bar Spacing:")
    spacingLabel:SetTextColor(0.9,0.9,0.9,1)
    local spacingSlider = CreateFrame("Slider", "CkraigBarOptionsPanelSpacingSlider", panel, "OptionsSliderTemplate")
    spacingSlider:SetPoint("LEFT", spacingLabel, "RIGHT", 8, 0)
    spacingSlider:SetMinMaxValues(0, 9)
    spacingSlider:SetValueStep(1)
    spacingSlider:SetObeyStepOnDrag(true)
    spacingSlider:SetWidth(120)
    spacingSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.barSpacing or 2)
    spacingSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.barSpacing = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
    end)
    _G[spacingSlider:GetName() .. 'Low']:SetText("0")
    _G[spacingSlider:GetName() .. 'High']:SetText("20")
    _G[spacingSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barSpacing or 2))

    -- Use Class Color
    local classColorCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    classColorCheck:SetPoint("TOPLEFT", spacingLabel, "BOTTOMLEFT", -10, nextYOffset(24))
    classColorCheck.text = classColorCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classColorCheck.text:SetPoint("LEFT", classColorCheck, "RIGHT", 4, 0)
    classColorCheck.text:SetText("Use Class Color for Bars")
    classColorCheck:SetChecked(CkraigCooldownManager.db.profile.buffBars.useClassColor or false)
    classColorCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.useClassColor = self:GetChecked()
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- 12 Color Pickers
    local colorPickers = {}
    local colorLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", classColorCheck, "BOTTOMLEFT", 0, -24)
    colorLabel:SetText("Bar Colors:")
    colorLabel:SetTextColor(0.9,0.9,0.9,1)

    local panelWidth = 420
    local rightAnchorX = panelWidth - 180
    local colSpacing = 80

    local rowSpacing = -4
    local firstRowY = 30
    local colorPickersYOffset = -220 - 300
    for i = 1, 12 do
        local picker = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate,BackdropTemplate")
        picker:SetSize(60, 22)
        colorPickers[i] = picker
    end
    for i = 1, 12 do
        local picker = colorPickers[i]
        local col = (i <= 6) and 0 or 1
        local row = (i - 1) % 6
        picker:SetPoint(
            "TOPLEFT",
            panel,
            "TOPLEFT",
            rightAnchorX + col * colSpacing + 30,
            colorPickersYOffset + firstRowY + row * (22 + rowSpacing)
        )
        picker:SetText("Bar "..i)
        picker.colorIndex = i
        picker:SetScript("OnClick", function(self)
            local db = CkraigCooldownManager.db
            local barColors = db.profile.buffBars.barColors or {}
            local defaultColors = {
                {r=0.2, g=0.9, b=0.2},
                {r=1.0, g=0.9, b=0.1},
                {r=0.2, g=0.6, b=1.0},
                {r=1.0, g=0.4, b=0.2},
                {r=0.8, g=0.2, b=0.8},
                {r=1.0, g=0.2, b=0.2},
            }
            local colorCount = #defaultColors
            local c = barColors[i] or defaultColors[((i-1)%colorCount)+1]
            if ColorPickerFrame and ColorPickerFrame.SetColorRGB then
                local r = tonumber(c and c.r) or 1
                local g = tonumber(c and c.g) or 1
                local b = tonumber(c and c.b) or 1
                ColorPickerFrame:SetColorRGB(r, g, b)
            end
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = {c and c.r or 1, c and c.g or 1, c and c.b or 1}
            -- Removed duplicate ColorPickerFrame.func and cancelFunc assignments
            ColorPickerFrame.swatchFunc = ColorPickerFrame.func
            ColorPickerFrame:Show()
        end)
        picker:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
        local db = CkraigCooldownManager.db.profile.buffBars.barColors or {}
        local defaultColors = {
            {r=0.2, g=0.9, b=0.2},
            {r=1.0, g=0.9, b=0.1},
            {r=0.2, g=0.6, b=1.0},
            {r=1.0, g=0.4, b=0.2},
            {r=0.8, g=0.2, b=0.8},
            {r=1.0, g=0.2, b=0.2},
        }
        local colorCount = #defaultColors
        local c = db[i] or defaultColors[((i-1)%colorCount)+1]
        local r = tonumber(c and c.r) or 1
        local g = tonumber(c and c.g) or 1
        local b = tonumber(c and c.b) or 1
        picker:SetBackdropColor(r, g, b, 1)
    end
    -- Disable color pickers if class color is enabled
    for _, picker in ipairs(colorPickers) do
        picker:SetEnabled(not (CkraigCooldownManager.db.profile.buffBars.useClassColor or false))
    end
    classColorCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.useClassColor = self:GetChecked()
        for _, picker in ipairs(colorPickers) do
            picker:SetEnabled(not self:GetChecked())
        end
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Font Dropdowns
    local fontLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -32)
    fontLabel:SetText("Bar Text Font:")
    fontLabel:SetTextColor(0.9,0.9,0.9,1)

    local fontDropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("LEFT", fontLabel, "RIGHT", -10, 2)
    fontDropdown:SetWidth(160)

    local function RefreshFontDropdown()
        local fonts = LSM and LSM:List("font") or {"Friz Quadrata TT"}
        local selectedFont = CkraigCooldownManager.db.profile.buffBars.font or fonts[1]
        UIDropDownMenu_Initialize(fontDropdown, function(self, level, menuList)
            for i, font in ipairs(fonts) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = font
                info.checked = (font == selectedFont)
                info.func = function()
                    selectedFont = font
                    CkraigCooldownManager.db.profile.buffBars.font = font
                    UIDropDownMenu_SetSelectedName(fontDropdown, font)
                    if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        UIDropDownMenu_SetSelectedName(fontDropdown, selectedFont)
        UIDropDownMenu_SetWidth(fontDropdown, 140)
        UIDropDownMenu_SetButtonWidth(fontDropdown, 160)
        UIDropDownMenu_JustifyText(fontDropdown, "LEFT")
    end
    fontDropdown:HookScript("OnShow", RefreshFontDropdown)
    fontDropdown:HookScript("OnMouseDown", RefreshFontDropdown)
    RefreshFontDropdown()



    -- Aspect Ratio Slider (0.5 to 2.0, shown as X:Y)
    local aspectLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aspectLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -32)
    aspectLabel:SetText("Icon Aspect Ratio:")
    aspectLabel:SetTextColor(0.9,0.9,0.9,1)
    local aspectSlider = CreateFrame("Slider", "CkraigBarOptionsPanelAspectSlider", panel, "OptionsSliderTemplate")
    aspectSlider:SetPoint("LEFT", aspectLabel, "RIGHT", 8, 0)
    aspectSlider:SetMinMaxValues(0.5, 2.0)
    aspectSlider:SetValueStep(0.01)
    aspectSlider:SetObeyStepOnDrag(true)
    aspectSlider:SetWidth(120)
    local aspectVal = 1.0
    local aspectStr = tostring(CkraigCooldownManager.db.profile.buffBars.aspectRatio or "1:1")
    local aspectW, aspectH = aspectStr:match("^(%d+):(%d+)$")
    if aspectW and aspectH then aspectVal = tonumber(aspectW) / tonumber(aspectH) end
    aspectSlider:SetValue(aspectVal)
    aspectSlider:HookScript("OnValueChanged", function(self, value)
        local ratio = math.floor(value * 100 + 0.5) / 100
        local shown = ratio >= 1 and (ratio .. ":1") or ("1:" .. math.floor(1/ratio + 0.5))
        CkraigCooldownManager.db.profile.buffBars.aspectRatio = shown
        _G[self:GetName() .. 'Text']:SetText(shown)
    end)
    _G[aspectSlider:GetName() .. 'Low']:SetText("0.5")
    _G[aspectSlider:GetName() .. 'High']:SetText("2.0")
    local shown = aspectVal >= 1 and (aspectVal .. ":1") or ("1:" .. math.floor(1/aspectVal + 0.5))
    _G[aspectSlider:GetName() .. 'Text']:SetText(shown)
    AttachSliderInputBox(aspectSlider, 0.5, 2.0, function(val)
        local ratio = math.floor(val * 100 + 0.5) / 100
        local shown = ratio >= 1 and (ratio .. ":1") or ("1:" .. math.floor(1/ratio + 0.5))
        CkraigCooldownManager.db.profile.buffBars.aspectRatio = shown
        _G[aspectSlider:GetName() .. 'Text']:SetText(shown)
    end)

    -- Corner Radius Slider (0-20)
    local radiusLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    radiusLabel:SetPoint("TOPLEFT", aspectLabel, "BOTTOMLEFT", 0, -36)
    radiusLabel:SetText("Icon Corner Radius:")
    radiusLabel:SetTextColor(0.9,0.9,0.9,1)
    local radiusSlider = CreateFrame("Slider", "CkraigBarOptionsPanelRadiusSlider", panel, "OptionsSliderTemplate")
    radiusSlider:SetPoint("LEFT", radiusLabel, "RIGHT", 8, 0)
    radiusSlider:SetMinMaxValues(0, 20)
    radiusSlider:SetValueStep(1)
    radiusSlider:SetObeyStepOnDrag(true)
    radiusSlider:SetWidth(120)
    radiusSlider:SetValue(CkraigCooldownManager.db.profile.buffBars.cornerRadius or 0)
    radiusSlider:HookScript("OnValueChanged", function(self, value)
        CkraigCooldownManager.db.profile.buffBars.cornerRadius = math.floor(value)
        _G[self:GetName() .. 'Text']:SetText(tostring(math.floor(value)))
    end)
    _G[radiusSlider:GetName() .. 'Low']:SetText("0")
    _G[radiusSlider:GetName() .. 'High']:SetText("20")
    _G[radiusSlider:GetName() .. 'Text']:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.cornerRadius or 0))
    AttachSliderInputBox(radiusSlider, 0, 20, function(val)
        CkraigCooldownManager.db.profile.buffBars.cornerRadius = math.floor(val)
        _G[radiusSlider:GetName() .. 'Text']:SetText(tostring(math.floor(val)))
    end)


    _G.CkraigBarOptionsPanel = panel
    -- Add creator note at bottom left
    local creatorNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    creatorNote:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    creatorNote:SetText("ORIGINAL CREATOR LAZARPAKY LAZARUI")
    creatorNote:SetTextColor(0.2, 1, 0.2, 1)

    -- Place checkboxes above the creator note at the bottom left
    local hideIconsCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    if creatorNote then
        hideIconsCheck:SetPoint("BOTTOMLEFT", creatorNote, "TOPLEFT", 0, 8)
    else
        hideIconsCheck:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 40)
    end
    hideIconsCheck.text = hideIconsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideIconsCheck.text:SetPoint("LEFT", hideIconsCheck, "RIGHT", 4, 0)

    hideIconsCheck.text:SetText("Hide Icons")
    hideIconsCheck:SetChecked(CkraigCooldownManager.db.profile.buffBars.hideIcons or false)
    hideIconsCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.hideIcons = self:GetChecked()
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    -- Add red warning note next to Hide Icons checkbox
    local hideIconsNote = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideIconsNote:SetPoint("LEFT", hideIconsCheck.text, "RIGHT", 12, 0)
    hideIconsNote:SetText("(If you hide icons here, set display mode to Name Only in Edit Mode)")
    hideIconsNote:SetTextColor(1, 0.1, 0.1, 1)

    local hideNameCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    hideNameCheck:SetPoint("BOTTOMLEFT", hideIconsCheck, "TOPLEFT", 0, 8)
    hideNameCheck.text = hideNameCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideNameCheck.text:SetPoint("LEFT", hideNameCheck, "RIGHT", 4, 0)
    hideNameCheck.text:SetText("Hide Bar Name")
    hideNameCheck:SetChecked(CkraigCooldownManager.db.profile.buffBars.hideBarName or false)
    hideNameCheck:SetScript("OnClick", function(self)
        CkraigCooldownManager.db.profile.buffBars.hideBarName = self:GetChecked()
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    return panel
end

local function ShowCkraigBarOptionsPopup()
    if not _G.CkraigBarOptionsPopup then
        local popup = CreateFrame("Frame", "CkraigBarOptionsPopup", UIParent, "BackdropTemplate")
        popup:SetSize(800, 800)
        popup:SetPoint("CENTER", UIParent, "CENTER")
        popup:SetMovable(true)
        popup:EnableMouse(true)
        popup:RegisterForDrag("LeftButton")
        popup:SetScript("OnDragStart", popup.StartMoving)
        popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
        popup:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 8})
        popup:SetBackdropColor(0,0,0,0.85)
        popup:SetBackdropBorderColor(0.2,0.2,0.2,0.8)
        popup:Hide()
        local optionsPanel = CreateCkraigBarOptionsPanel()
        optionsPanel:SetParent(popup)
        optionsPanel:ClearAllPoints()
        optionsPanel:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, 0)
        optionsPanel:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", 0, 0)
        optionsPanel:Show()
        local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() popup:Hide() end)
        _G.CkraigBarOptionsPopup = popup
    end
    _G.CkraigBarOptionsPopup:Show()
    _G.CkraigBarOptionsPopup:SetFrameStrata("DIALOG")
    _G.CkraigBarOptionsPopup:Raise()
end

local function SetupMinimapIcon(self)
    if LDB and DBIcon and not minimapLDB then
        minimapLDB = LDB:NewDataObject("CkraigCooldownBars", {
            type = "launcher",
            icon = "Interface/AddOns/CkraigCooldownManagersBarsOnly/ck_logo.tga",
            tocname = AddonName,
            OnClick = function(_, button)
                if button == "LeftButton" or button == "RightButton" then
                    ShowCkraigBarOptionsPopup()
                end
            end,
            OnTooltipShow = function(tt)
                tt:AddLine("Ckraig Cooldown Bars")
                tt:AddLine("|cffffff00Left or Right Click:|r Open Popup Options")
            end,
        })
        if self.db and self.db.profile and self.db.profile.minimap == nil then
            self.db.profile.minimap = { hide = false }
        end
        DBIcon:Register("CkraigCooldownBars", minimapLDB, self.db.profile.minimap)
    end
end

-- Add slash command to open config popup
SLASH_CKRAIGBARS1 = "/ckbars"
SlashCmdList["CKRAIGBARS"] = function()
    ShowCkraigBarOptionsPopup()
end

-- Call minimap icon setup in your OnInitialize or OnEnable
hooksecurefunc(CkraigCooldownManager, "OnInitialize", function(self)
    SetupMinimapIcon(self)
end)

