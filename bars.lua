-- Core.lua - CkraigCooldownManager (Buff Bars only, stack-count sizing added)
local AddonName, Addon = ...
local CkraigCooldownManager = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local FADE_THRESHOLD = 0.3

-- Default DB (change fontSize or stackFontScale here)
local defaults = {
    profile = {
        buffBars = {
            enabled = true,
            font = "Friz Quadrata TT",
            fontSize = 11,            -- base font size (pixels)
            stackFontScale = 1.6,     -- multiplier applied when stack > 1
            texture = "Blizzard Raid Bar",
            borderSize = 1.0,
            backdropBorderSize = 1.0,
            borderColor = {r = 0, g = 0, b = 0, a = 1},
            barHeight = 24,
            barWidth = 200,
            barSpacing = 2,
            showIcon = true,
            useClassColor = true,
            customColor = {r = 0.5, g = 0.5, b = 0.5, a = 1},
            backdropColor = {r = 0, g = 0, b = 0, a = 0.5},
            truncateText = false,
            maxTextWidth = 0,
            frameStrata = "LOW",
            anchorPoint = nil,
            relativePoint = nil,
            anchorX = nil,
            anchorY = nil,
            barAlpha = 1.0,
            aspectRatio = "1:1",
            cornerRadius = 0,
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
    local baseSize = cfg.fontSize or 11
    local scale = cfg.stackFontScale or 1.6

    local ok, txt = pcall(function() return stackFS:GetText() end)
    if not ok or not txt then txt = "" end

    pcall(function() stackFS:SetFont(fontPath, baseSize, "OUTLINE") end)
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
    local fontSize = settings.fontSize or 11
    local texturePath = LSM:Fetch("statusbar", settings.texture) or "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"

    local parent = barFrame:GetParent()

    if barFrame.SetHeight then barFrame:SetHeight(barHeight) end
    if barFrame.SetWidth and settings.barWidth then barFrame:SetWidth(settings.barWidth) end
    if parent and parent.SetHeight then parent:SetHeight(barHeight) end
    if parent and parent.SetWidth and settings.barWidth then parent:SetWidth(settings.barWidth) end

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
            outer:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
            outer:Show()
        elseif parent._bb_outer_border then
            parent._bb_outer_border:Hide()
        end
    end

    -- Icon handling (improved cropping)
    local iconContainer = parent and (parent.Icon or parent.icon or parent.IconTexture)
    if iconContainer and settings.showIcon then
        local aspectRatio = 1.0 -- default square
        if settings.aspectRatio and type(settings.aspectRatio) == "string" then
            local w, h = settings.aspectRatio:match("^(%d+):(%d+)$")
            if w and h then aspectRatio = tonumber(w) / tonumber(h) end
        end
        local left, right, top, bottom = 0, 1, 0, 1
        if aspectRatio > 1.0 then
            local crop = 1 - (1 / aspectRatio)
            local off = crop / 2
            top = top + off
            bottom = bottom - off
        elseif aspectRatio < 1.0 then
            local crop = 1 - aspectRatio
            local off = crop / 2
            left = left + off
            right = right - off
        end
        local cornerRadius = settings.cornerRadius or 0
        if cornerRadius > 0 then
            local extra = 0.07 + (cornerRadius * 0.005)
            if extra > 0.24 then extra = 0.24 end
            left   = left   + extra
            right  = right  - extra
            top    = top    + extra
            bottom = bottom - extra
        end
        if iconContainer:IsObjectType("Texture") then
            pcall(iconContainer.SetTexCoord, iconContainer, left, right, top, bottom)
            pcall(iconContainer.SetSize, iconContainer, barHeight, barHeight)
            pcall(iconContainer.ClearAllPoints, iconContainer)
            pcall(iconContainer.SetPoint, iconContainer, "LEFT", barFrame, "LEFT", -barHeight - 4, 0)
        else
            local childTex = iconContainer.icon or iconContainer.Icon or iconContainer.IconTexture or iconContainer.Texture
            if childTex and childTex:IsObjectType("Texture") then
                pcall(childTex.SetTexCoord, childTex, left, right, top, bottom)
                pcall(childTex.SetAllPoints, childTex, iconContainer)
                pcall(iconContainer.SetSize, iconContainer, barHeight, barHeight)
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
        pcall(nameFS.SetFont, nameFS, fontPath, fontSize, "OUTLINE")
        pcall(nameFS.SetTextColor, nameFS,1,1,1,1)
    end
    local timeFS = barFrame.TimeLeft or barFrame.Duration
    if timeFS and timeFS.SetFont then
        pcall(timeFS.SetFont, timeFS, fontPath, fontSize, "OUTLINE")
        local color = {r=1, g=1, b=1, a=1} -- default white
        local ok, txt = pcall(function() return timeFS:GetText() end)
        local seconds = tonumber(txt)
        if seconds then
            if seconds < 5 then
                color = {r=1, g=0, b=0, a=1} -- red
            elseif seconds >= 6 and seconds <= 10 then
                color = {r=1, g=0.95, b=0.6, a=1} -- yellow
            elseif seconds >= 11 then
                color = {r=1, g=1, b=1, a=1} -- white
            end
        end
        pcall(timeFS.SetTextColor, timeFS, color.r, color.g, color.b, color.a)
    end

    if self.ApplyBarFrameSettings then pcall(self.ApplyBarFrameSettings, self, barFrame) end

    -- Only modify the stack/count FontString (no other changes)
    pcall(function() ApplyStackFontToBar(self, barFrame) end)
end

function CkraigCooldownManager:RepositionAllBars()
    if not BuffBarCooldownViewer or not self.db.profile.buffBars.enabled then return end
    local bars = GetBuffBarFrames()
    local settings = self.db.profile.buffBars
    local barHeight, spacing = settings.barHeight or 24, settings.barSpacing or 2

    for _, bar in ipairs(bars) do if bar and bar.ClearAllPoints then bar:ClearAllPoints() end end

    for i, bar in ipairs(bars) do
        local y = roundPixel((i - 1) * (barHeight + spacing))
        if bar.SetPoint then pcall(bar.SetPoint, bar, "BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, y) end
        local barObj = bar.Bar or bar
        barObj._bb_barIndex = i
        self:StyleBar(barObj)
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
    self.db = LibStub("AceDB-3.0"):New("CkraigCooldownManagerDB", defaults, true)
    if not LSM:IsValid("font","Friz Quadrata TT") then LSM:Register("font","Friz Quadrata TT","Fonts\\FRIZQT__.TTF") end
    if not LSM:IsValid("statusbar","Blizzard Raid Bar") then LSM:Register("statusbar","Blizzard Raid Bar","Interface\\RaidFrame\\Raid-Bar-Hp-Fill") end
    LSM.RegisterCallback(self,"LibSharedMedia_Registered", function() self:RepositionAllBars() end)
    if self.SetupOptions then self:SetupOptions() end
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
    SlashCmdList["BETTERBUFFSDEBUG"] = function()
        local bars = GetBuffBarFrames()
        if #bars == 0 then print("BetterBuffs: no buff bar frames found") return end
        local bar = bars[1]
        print("BetterBuffs: Inspecting frame:", bar:GetName() or "(unnamed)")
        if bar.GetRegions then
            for i = 1, select("#", bar:GetRegions()) do
                local r = select(i, bar:GetRegions())
                if r then print(" region", i, "type", r.GetObjectType and r:GetObjectType() or "?", "name", r:GetName() or "(anon)") end
            end
        end
        if bar.GetChildren then
            for i, child in ipairs({bar:GetChildren()}) do
                if child then
                    print(" child", i, "type", child.GetObjectType and child:GetObjectType() or "?", "name", child:GetName() or "(anon)")
                    if child.GetRegions then
                        for j = 1, select("#", child:GetRegions()) do
                            local r = select(j, child:GetRegions())
                            if r then print("  child region", j, "type", r.GetObjectType and r:GetObjectType() or "?", "name", r:GetName() or "(anon)") end
                        end
                    end
                end
            end
        end
    end
end


-- Options panel for bar settings (CkraigCooldownManager)
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

    -- Bar Height
    local heightLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heightLabel:SetPoint("TOPLEFT", texLabel, "BOTTOMLEFT", 0, -24)
    heightLabel:SetText("Bar Height:")
    heightLabel:SetTextColor(0.9,0.9,0.9,1)
    local heightBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    heightBox:SetSize(40, 24)
    heightBox:SetPoint("LEFT", heightLabel, "RIGHT", 8, 0)
    heightBox:SetAutoFocus(false)
    heightBox:SetNumeric(true)
    heightBox:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barHeight or 24))

    -- Bar Width
    local widthLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    widthLabel:SetPoint("TOPLEFT", heightLabel, "BOTTOMLEFT", 0, -24)
    widthLabel:SetText("Bar Width:")
    widthLabel:SetTextColor(0.9,0.9,0.9,1)
    local widthBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    widthBox:SetSize(40, 24)
    widthBox:SetPoint("LEFT", widthLabel, "RIGHT", 8, 0)
    widthBox:SetAutoFocus(false)
    widthBox:SetNumeric(true)
    widthBox:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barWidth or 200))

    -- Bar Spacing
    local spacingLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spacingLabel:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -24)
    spacingLabel:SetText("Bar Spacing:")
    spacingLabel:SetTextColor(0.9,0.9,0.9,1)
    local spacingBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    spacingBox:SetSize(40, 24)
    spacingBox:SetPoint("LEFT", spacingLabel, "RIGHT", 8, 0)
    spacingBox:SetAutoFocus(false)
    spacingBox:SetNumeric(true)
    spacingBox:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.barSpacing or 2))

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
            rightAnchorX + col * colSpacing,
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
            ColorPickerFrame.func = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                barColors[i] = {r=r, g=g, b=b}
                db.profile.buffBars.barColors = barColors
                picker:SetBackdropColor(r, g, b, 1)
                if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
            end
            ColorPickerFrame.cancelFunc = function(prev)
                if prev then
                    barColors[i] = {r=prev[1], g=prev[2], b=prev[3]}
                    db.profile.buffBars.barColors = barColors
                    picker:SetBackdropColor(prev[1], prev[2], prev[3], 1)
                    if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
                end
            end
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


    -- Aspect Ratio Option
    local aspectLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aspectLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -32)
    aspectLabel:SetText("Icon Aspect Ratio (e.g. 1:1, 4:3):")
    aspectLabel:SetTextColor(0.9,0.9,0.9,1)
    local aspectBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    aspectBox:SetSize(80, 24)
    aspectBox:SetPoint("LEFT", aspectLabel, "RIGHT", 8, 0)
    aspectBox:SetAutoFocus(false)
    aspectBox:SetText(CkraigCooldownManager.db.profile.buffBars.aspectRatio or "1:1")

    -- Corner Radius Option
    local radiusLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    radiusLabel:SetPoint("TOPLEFT", aspectLabel, "BOTTOMLEFT", 0, -24)
    radiusLabel:SetText("Icon Corner Radius (0-20):")
    radiusLabel:SetTextColor(0.9,0.9,0.9,1)
    local radiusBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    radiusBox:SetSize(40, 24)
    radiusBox:SetPoint("LEFT", radiusLabel, "RIGHT", 8, 0)
    radiusBox:SetAutoFocus(false)
    radiusBox:SetNumeric(true)
    radiusBox:SetText(tostring(CkraigCooldownManager.db.profile.buffBars.cornerRadius or 0))

    -- Apply Button (create after all controls)
    local applyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    applyBtn:SetSize(80, 24)
    applyBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        local db = CkraigCooldownManager.db
        local height = tonumber(heightBox:GetText())
        if height then db.profile.buffBars.barHeight = height end
        local width = tonumber(widthBox:GetText())
        if width then db.profile.buffBars.barWidth = width end
        local spacing = tonumber(spacingBox:GetText())
        if spacing then db.profile.buffBars.barSpacing = spacing end
        local font = db.profile.buffBars.font
        if font then db.profile.buffBars.font = font end
        local texture = db.profile.buffBars.texture
        if texture then db.profile.buffBars.texture = texture end
        local useClassColor = db.profile.buffBars.useClassColor
        db.profile.buffBars.useClassColor = useClassColor
        local barColors = db.profile.buffBars.barColors
        if barColors then db.profile.buffBars.barColors = barColors end
        local aspect = aspectBox:GetText()
        if aspect and aspect ~= "" then db.profile.buffBars.aspectRatio = aspect end
        local radius = tonumber(radiusBox:GetText())
        if radius then db.profile.buffBars.cornerRadius = radius end
        if type(CkraigCooldownManager.RepositionAllBars) == "function" then CkraigCooldownManager:RepositionAllBars() end
    end)

    _G.CkraigBarOptionsPanel = panel
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

_G["CkraigCooldownManager"] = CkraigCooldownManager
