-- Config removed: all configuration is now in the Interface Options panel via the Modern Settings API
-- All dropdowns and color pickers are now handled by the Modern Settings API panel below
-- Modern Settings API panel for Essential Buffs
-- All checkboxes are now handled by the Modern Settings API panel
-- ShowConfig and all custom config UI code removed; all configuration is now in the Interface Options panel
-- Minimap icon removed by user request
-- ======================================================
-- MyEssentialBuffTracker (Deterministic ordering, Aspect Ratio,
-- Multi-row center layout, Combat-safe skinning, EditMode safe)
-- Target: _G["EssentialCooldownViewer"]
-- ======================================================

-- SavedVariables
MyEssentialBuffTrackerDB = MyEssentialBuffTrackerDB or {}

-- Hide Cooldown Manager when mounted

-- Mount hide/show option
local function IsPlayerMounted()
    return IsMounted and IsMounted()
end

local function UpdateCooldownManagerVisibility()
    local viewer = _G["EssentialCooldownViewer"]
    if viewer then
        if MyEssentialBuffTrackerDB.hideWhenMounted then
            if IsPlayerMounted() then
                viewer:Hide()
            else
                viewer:Show()
            end
        else
            viewer:Show()
        end
    end
end

local mountEventFrame = CreateFrame("Frame")
mountEventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mountEventFrame:SetScript("OnEvent", function()
    UpdateCooldownManagerVisibility()
end)

local DEFAULTS = {
    columns         = 3,
    hSpacing        = 2,
    vSpacing        = 2,
    growUp          = true,
    locked          = true,
    iconSize        = 36,
    aspectRatio     = "1:1",
    aspectRatioCrop = nil,
    spacing         = 4,
    rowLimit        = 0,
    rowGrowDirection= "down",

    -- New settings
    iconCornerRadius = 1,
    cooldownTextSize = 16,
    cooldownTextPosition = "CENTER",
    cooldownTextX = 0,
    cooldownTextY = 0,
    chargeTextSize = 14,
    chargeTextPosition = "BOTTOMRIGHT",
    chargeTextX = 0,
    chargeTextY = 0,

    showCooldownText = true,
    showChargeText = true,
    hideWhenMounted = false,

    -- Static Grid Mode
    staticGridMode = false,
    gridRows = 4,
    gridColumns = 4,
    gridSlotMap = {},

    -- Per-row icon sizes (optional override, otherwise uses iconSize)
    rowSizes = {},

    -- Border
    borderSize = 1,
    borderColor = {0, 0, 0, 1},
}
    if MyEssentialBuffTrackerDB.borderSize == nil then MyEssentialBuffTrackerDB.borderSize = DEFAULTS.borderSize end
    MyEssentialBuffTrackerDB.borderColor = MyEssentialBuffTrackerDB.borderColor or DEFAULTS.borderColor

local POSITION_PRESETS = {
    ["CENTER"] = {x = 0, y = 0, point = "CENTER"},
    ["TOP"] = {x = 0, y = 0, point = "TOP"},
    ["BOTTOM"] = {x = 0, y = 0, point = "BOTTOM"},
    ["LEFT"] = {x = 0, y = 0, point = "LEFT"},
    ["RIGHT"] = {x = 0, y = 0, point = "RIGHT"},
    ["TOPLEFT"] = {x = 0, y = 0, point = "TOPLEFT"},
    ["TOPRIGHT"] = {x = 0, y = 0, point = "TOPRIGHT"},
    ["BOTTOMLEFT"] = {x = 0, y = 0, point = "BOTTOMLEFT"},
    ["BOTTOMRIGHT"] = {x = 0, y = 0, point = "BOTTOMRIGHT"},
}

-- ---------------------------
-- Utilities
-- ---------------------------
local function EnsureDB()
    MyEssentialBuffTrackerDB.columns           = MyEssentialBuffTrackerDB.columns  or DEFAULTS.columns
    MyEssentialBuffTrackerDB.hSpacing          = MyEssentialBuffTrackerDB.hSpacing or DEFAULTS.hSpacing
    MyEssentialBuffTrackerDB.vSpacing          = MyEssentialBuffTrackerDB.vSpacing or DEFAULTS.vSpacing
    if MyEssentialBuffTrackerDB.growUp == nil then MyEssentialBuffTrackerDB.growUp = DEFAULTS.growUp end
    if MyEssentialBuffTrackerDB.locked == nil then MyEssentialBuffTrackerDB.locked = DEFAULTS.locked end
    MyEssentialBuffTrackerDB.iconSize          = MyEssentialBuffTrackerDB.iconSize or DEFAULTS.iconSize
    MyEssentialBuffTrackerDB.aspectRatio       = MyEssentialBuffTrackerDB.aspectRatio or DEFAULTS.aspectRatio
    MyEssentialBuffTrackerDB.aspectRatioCrop   = MyEssentialBuffTrackerDB.aspectRatioCrop or DEFAULTS.aspectRatioCrop
    MyEssentialBuffTrackerDB.spacing           = MyEssentialBuffTrackerDB.spacing or DEFAULTS.spacing
    MyEssentialBuffTrackerDB.rowLimit          = MyEssentialBuffTrackerDB.rowLimit or DEFAULTS.rowLimit
    MyEssentialBuffTrackerDB.rowGrowDirection  = MyEssentialBuffTrackerDB.rowGrowDirection or DEFAULTS.rowGrowDirection

    if MyEssentialBuffTrackerDB.iconCornerRadius == nil then MyEssentialBuffTrackerDB.iconCornerRadius = DEFAULTS.iconCornerRadius end
    MyEssentialBuffTrackerDB.cooldownTextSize  = MyEssentialBuffTrackerDB.cooldownTextSize or DEFAULTS.cooldownTextSize
    MyEssentialBuffTrackerDB.cooldownTextPosition = MyEssentialBuffTrackerDB.cooldownTextPosition or DEFAULTS.cooldownTextPosition
    MyEssentialBuffTrackerDB.cooldownTextX = MyEssentialBuffTrackerDB.cooldownTextX or DEFAULTS.cooldownTextX
    MyEssentialBuffTrackerDB.cooldownTextY = MyEssentialBuffTrackerDB.cooldownTextY or DEFAULTS.cooldownTextY
    MyEssentialBuffTrackerDB.chargeTextSize    = MyEssentialBuffTrackerDB.chargeTextSize or DEFAULTS.chargeTextSize
    MyEssentialBuffTrackerDB.chargeTextPosition = MyEssentialBuffTrackerDB.chargeTextPosition or DEFAULTS.chargeTextPosition
    MyEssentialBuffTrackerDB.chargeTextX = MyEssentialBuffTrackerDB.chargeTextX or DEFAULTS.chargeTextX
    MyEssentialBuffTrackerDB.chargeTextY = MyEssentialBuffTrackerDB.chargeTextY or DEFAULTS.chargeTextY

    if MyEssentialBuffTrackerDB.showCooldownText == nil then MyEssentialBuffTrackerDB.showCooldownText = DEFAULTS.showCooldownText end
    if MyEssentialBuffTrackerDB.showChargeText == nil then MyEssentialBuffTrackerDB.showChargeText = DEFAULTS.showChargeText end
    if MyEssentialBuffTrackerDB.hideWhenMounted == nil then MyEssentialBuffTrackerDB.hideWhenMounted = DEFAULTS.hideWhenMounted end

    if MyEssentialBuffTrackerDB.staticGridMode == nil then MyEssentialBuffTrackerDB.staticGridMode = DEFAULTS.staticGridMode end
    MyEssentialBuffTrackerDB.gridRows = MyEssentialBuffTrackerDB.gridRows or DEFAULTS.gridRows
    MyEssentialBuffTrackerDB.gridColumns = MyEssentialBuffTrackerDB.gridColumns or DEFAULTS.gridColumns
    MyEssentialBuffTrackerDB.gridSlotMap = MyEssentialBuffTrackerDB.gridSlotMap or {}

    -- Per-row sizes
    MyEssentialBuffTrackerDB.rowSizes = MyEssentialBuffTrackerDB.rowSizes or {}
end

local function SafeNumber(val, default)
    local num = tonumber(val)
    if num ~= nil then return num end
    return default
end

local function IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

-- ---------------------------
-- MyEssentialIconViewers Core (initialize early)
-- ---------------------------
-- Only define MyEssentialIconViewers for EssentialCooldownViewer in this file
MyEssentialIconViewers = MyEssentialIconViewers or {}
MyEssentialIconViewers.__pendingIcons = MyEssentialIconViewers.__pendingIcons or {}
MyEssentialIconViewers.__iconSkinEventFrame = MyEssentialIconViewers.__iconSkinEventFrame or nil
MyEssentialIconViewers.__pendingBackdrops = MyEssentialIconViewers.__pendingBackdrops or {}
MyEssentialIconViewers.__backdropEventFrame = MyEssentialIconViewers.__backdropEventFrame or nil

-- ---------------------------
-- Helper functions for skinning
-- ---------------------------
local function StripTextureMasks(texture)
    if not texture or not texture.GetMaskTexture then return end
    local i = 1
    local mask = texture:GetMaskTexture(i)
    while mask do
        texture:RemoveMaskTexture(mask)
        i = i + 1
        mask = texture:GetMaskTexture(i)
    end
end

local function StripBlizzardOverlay(icon)
    if not icon or not icon.GetRegions then return end
    for _, region in ipairs({ icon:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") and region.GetAtlas then
            if region:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetTexture("")
                region:Hide()
                region.Show = function() end
            end
        end
    end
end

local function NeutralizeAtlasTexture(texture)
    if not texture then return end
    if texture.SetAtlas then
        texture:SetAtlas(nil)
        if not texture.__mbtAtlasNeutralized then
            texture.__mbtAtlasNeutralized = true
            hooksecurefunc(texture, "SetAtlas", function(self)
                if self.SetTexture then self:SetTexture(nil) end
                if self.SetAlpha then self:SetAlpha(0) end
            end)
        end
    end
    if texture.SetTexture then texture:SetTexture(nil) end
    if texture.SetAlpha then texture:SetAlpha(0) end
end

local function HideDebuffBorder(icon)
    if not icon then return end
    if icon.DebuffBorder then NeutralizeAtlasTexture(icon.DebuffBorder) end
    local name = icon.GetName and icon:GetName()
    if name and _G[name .. "DebuffBorder"] then NeutralizeAtlasTexture(_G[name .. "DebuffBorder"]) end
    if icon.GetRegions then
        for _, region in ipairs({ icon:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                local rname = region.GetName and region:GetName()
                if rname and rname:find("DebuffBorder", 1, true) then
                    NeutralizeAtlasTexture(region)
                end
            end
        end
    end
end

-- Combat-safe deferred backdrop system
local function ProcessPendingBackdrops()
    if not MyEssentialIconViewers.__pendingBackdrops then return end
    for frame, info in pairs(MyEssentialIconViewers.__pendingBackdrops) do
        if frame and info then
            if not InCombatLockdown() then
                local okW, w = pcall(frame.GetWidth, frame)
                local okH, h = pcall(frame.GetHeight, frame)
                local dimsOk = false
                if okW and okH and w and h then
                    local testOk = pcall(function() return w + h end)
                    dimsOk = testOk and w > 0 and h > 0
                end
                if dimsOk then
                    local success = pcall(frame.SetBackdrop, frame, info.backdrop)
                    if success and info.color then
                        local r,g,b,a = unpack(info.color)
                        frame:SetBackdropBorderColor(r,g,b,a or 1)
                    end
                    frame:Show()
                    frame.__mbtBackdropPending = nil
                    MyEssentialIconViewers.__pendingBackdrops[frame] = nil
                end
            end
        end
    end
end

local function EnsureBackdropEventFrame()
    if MyEssentialIconViewers.__backdropEventFrame then return end
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("PLAYER_REGEN_ENABLED")
    ef:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            ProcessPendingBackdrops()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
    end)
    MyEssentialIconViewers.__backdropEventFrame = ef
end

local function SafeSetBackdrop(frame, backdropInfo, color)
    if not frame or not frame.SetBackdrop then return false end

    if InCombatLockdown() then
        frame.__mbtBackdropPending = true
        MyEssentialIconViewers.__pendingBackdrops = MyEssentialIconViewers.__pendingBackdrops or {}
        MyEssentialIconViewers.__pendingBackdrops[frame] = { backdrop = backdropInfo, color = color }
        EnsureBackdropEventFrame()
        MyEssentialIconViewers.__backdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end

    local okW, w = pcall(frame.GetWidth, frame)
    local okH, h = pcall(frame.GetHeight, frame)
    local dimsOk = false
    if okW and okH and w and h then
        local testOk = pcall(function() return w + h end)
        dimsOk = testOk and w > 0 and h > 0
    end

    if not dimsOk then
        frame.__mbtBackdropPending = true
        MyEssentialIconViewers.__pendingBackdrops = MyEssentialIconViewers.__pendingBackdrops or {}
        MyEssentialIconViewers.__pendingBackdrops[frame] = { backdrop = backdropInfo, color = color }
        EnsureBackdropEventFrame()
        MyEssentialIconViewers.__backdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end

    local ok = pcall(frame.SetBackdrop, frame, backdropInfo)
    if ok and color then
        local r,g,b,a = unpack(color)
        frame:SetBackdropBorderColor(r,g,b,a or 1)
    end
    return ok
end

-- ---------------------------
-- Aspect ratio helper
-- ---------------------------
local function ConvertAspectRatio(value)
    if not value then return 1.0 end
    if type(value) == "number" then return value end
    local w,h = value:match("^(%d+%.?%d*):(%d+%.?%d*)$")
    if w and h then return tonumber(w)/tonumber(h) end
    w,h = value:match("^(%d+%.?%d*)x(%d+%.?%d*)$")
    if w and h then return tonumber(w)/tonumber(h) end
    return 1.0
end

-- ---------------------------
-- Force reskin helper (fixes live preview)
-- ---------------------------
local function ForceReskinViewer(viewer)
    if not viewer then return end
    local container = viewer.viewerFrame or viewer
    for _, child in ipairs({ container:GetChildren() }) do
        if child then
            child.__mbtSkinned = nil
            child.__mbtSkinPending = nil
            child.__mbtSkinError = nil
            if child.__mbtBorder then
                child.__mbtBorder.__mbtBackdropPending = nil
            end
        end
    end
end

-- ---------------------------
-- SkinIcon (combined, robust)
-- ---------------------------
function MyEssentialIconViewers:SkinIcon(icon, settings)
    if not icon then return false end

    local iconTexture = icon.Icon or icon.icon
    if not iconTexture then return false end

    settings = settings or MyEssentialBuffTrackerDB

    -- Aspect ratio + corner radius (texcoord cropping)
    local cornerRadius = settings.iconCornerRadius or DEFAULTS.iconCornerRadius

    local aspectRatioValue = 1.0
    if settings.aspectRatioCrop and type(settings.aspectRatioCrop) == "number" then
        aspectRatioValue = settings.aspectRatioCrop
    elseif settings.aspectRatio then
        aspectRatioValue = ConvertAspectRatio(settings.aspectRatio)
    end

    iconTexture:ClearAllPoints()
    iconTexture:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    iconTexture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)

    StripTextureMasks(iconTexture)

    local left, right, top, bottom = 0, 1, 0, 1

    if aspectRatioValue ~= 1.0 then
        if aspectRatioValue > 1.0 then
            local crop = 1 - (1 / aspectRatioValue)
            local off = crop / 2
            top = top + off
            bottom = bottom - off
        else
            local crop = 1 - aspectRatioValue
            local off = crop / 2
            left = left + off
            right = right - off
        end
    end

    if cornerRadius and cornerRadius ~= 0 then
        local extra = 0.07 + (cornerRadius * 0.005)
        if extra > 0.24 then extra = 0.24 end
        left   = left   + extra
        right  = right  - extra
        top    = top    + extra
        bottom = bottom - extra
    end

    iconTexture:SetTexCoord(left, right, top, bottom)

    -- Cooldown swipe / flash alignment
    local cdPadding = 0

    if icon.CooldownFlash then
        icon.CooldownFlash:ClearAllPoints()
        icon.CooldownFlash:SetPoint("TOPLEFT", icon, "TOPLEFT", cdPadding, -cdPadding)
        icon.CooldownFlash:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cdPadding, cdPadding)
    end

    if icon.Cooldown or icon.cooldown then
        local cd = icon.Cooldown or icon.cooldown
        cd:ClearAllPoints()
        cd:SetPoint("TOPLEFT", icon, "TOPLEFT", cdPadding, -cdPadding)
        cd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -cdPadding, cdPadding)

        if cd.SetSwipeTexture then cd:SetSwipeTexture("Interface\\Buttons\\WHITE8X8") end
        if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.8) end
        if cd.SetDrawEdge then cd:SetDrawEdge(true) end
        if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
    end

    -- Pandemic + out of range alignment
    local picon = icon.PandemicIcon or icon.pandemicIcon or icon.Pandemic or icon.pandemic
    if not picon and icon.GetChildren then
        for _, child in ipairs({ icon:GetChildren() }) do
            local n = child.GetName and child:GetName()
            if n and n:find("Pandemic") then
                picon = child
                break
            end
        end
    end
    if picon and picon.ClearAllPoints then
        picon:ClearAllPoints()
        picon:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        picon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    end

    local oor = icon.OutOfRange or icon.outOfRange or icon.oor
    if oor and oor.ClearAllPoints then
        oor:ClearAllPoints()
        oor:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        oor:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    end

    -- Charge / stack text detection and placement
    local chargeText = nil

    if icon.GetApplicationsFontString then
        local ok, result = pcall(icon.GetApplicationsFontString, icon)
        if ok then chargeText = result end
    end

    if not chargeText and icon.ChargeCount and icon.ChargeCount.Current then
        chargeText = icon.ChargeCount.Current
    end

    if not chargeText then
        chargeText = icon._chargeText or icon._customCountText or icon.Count or icon.count
            or icon.Charges or icon.charges or icon.StackCount
    end

    if not chargeText and icon.GetRegions then
        for _, region in ipairs({ icon:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                local t = region:GetText()
                if t and tonumber(t) and tonumber(t) > 0 then
                    chargeText = region
                    break
                end
            end
        end
    end

    if chargeText and chargeText.SetFont then
        if settings.showChargeText then
            chargeText:Show()
            local fontSize = SafeNumber(settings.chargeTextSize, DEFAULTS.chargeTextSize)
            chargeText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
            chargeText:ClearAllPoints()

            local position = POSITION_PRESETS[settings.chargeTextPosition] or POSITION_PRESETS["BOTTOMRIGHT"]
            local offsetX = SafeNumber(settings.chargeTextX, 0)
            local offsetY = SafeNumber(settings.chargeTextY, 0)
            chargeText:SetPoint(position.point, icon, position.point, position.x + offsetX, position.y + offsetY)
            -- Force use of CooldownChargeDB for charge/stack text color
            local color = (_G.CooldownChargeDB and _G.CooldownChargeDB["TextColor_ChargeText_Essential"]) or {1,1,1,1}
            if color and chargeText.SetTextColor then
                chargeText:SetTextColor(color[1], color[2], color[3], color[4] or 1)
            end
        else
            chargeText:Hide()
        end
    end

    -- Cooldown text detection and placement
    local cdText = nil
    if icon.Cooldown or icon.cooldown then
        local cd = icon.Cooldown or icon.cooldown
        cdText = cd.Text or cd.text

        if not cdText and cd.GetChildren then
            for _, child in ipairs({ cd:GetChildren() }) do
                if child and child.GetObjectType and child:GetObjectType() == "FontString" then
                    cdText = child
                    break
                end
            end
        end

        if not cdText and cd.GetRegions then
            for _, region in ipairs({ cd:GetRegions() }) do
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    cdText = region
                    break
                end
            end
        end
    end

    if cdText and cdText.SetFont then
        if settings.showCooldownText then
            cdText:Show()
            local fontSize = SafeNumber(settings.cooldownTextSize, DEFAULTS.cooldownTextSize)
            cdText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
            cdText:ClearAllPoints()

            local position = POSITION_PRESETS[settings.cooldownTextPosition] or POSITION_PRESETS["CENTER"]
            local offsetX = SafeNumber(settings.cooldownTextX, 0)
            local offsetY = SafeNumber(settings.cooldownTextY, 0)
            cdText:SetPoint(position.point, icon, position.point, position.x + offsetX, position.y + offsetY)
            -- Force use of CooldownChargeDB for cooldown text color
            local color = (_G.CooldownChargeDB and _G.CooldownChargeDB["TextColor_CooldownText_Essential"]) or {1,1,1,1}
            if color and cdText.SetTextColor then
                cdText:SetTextColor(color[1], color[2], color[3], color[4] or 1)
            end
        else
            cdText:Hide()
        end
    end

    -- Strip overlays and debuff borders
    StripBlizzardOverlay(icon)
    HideDebuffBorder(icon)

    -- Border with deferred backdrop
    local borderSize = settings.borderSize or DEFAULTS.borderSize
    local borderColor = settings.borderColor or DEFAULTS.borderColor

    -- If cornerRadius is exactly 1, force a 1-pixel black border
    -- If cornerRadius is exactly 1 and 1-pixel border is enabled, force a 1-pixel black border
    if cornerRadius == 1 and (MyEssentialBuffTrackerDB.onePixelBorder == nil or MyEssentialBuffTrackerDB.onePixelBorder == 1) then
        borderSize = 1
        borderColor = {0, 0, 0, 1}
    end

    if not icon.__mbtBorder then
        icon.__mbtBorder = CreateFrame("Frame", nil, icon, "BackdropTemplate")
        local ok, level = pcall(icon.GetFrameLevel, icon)
        if ok and level then
            icon.__mbtBorder:SetFrameLevel(level + 10)
        end
    end

    local border = icon.__mbtBorder
    if border then
        local backdropInfo = {
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = borderSize,
        }
        local ok = SafeSetBackdrop(border, backdropInfo, borderColor)
        if ok then
            border:ClearAllPoints()
            border:SetPoint("TOPLEFT", icon, "TOPLEFT", -borderSize, borderSize)
            border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", borderSize, -borderSize)
            border:Show()
        else
            border:Hide()
        end
    end

    icon.__mbtSkinned = true
    icon.__mbtSkinPending = nil
    return true
end

-- ---------------------------
-- Process pending icons (called after combat)
-- ---------------------------
function MyEssentialIconViewers:ProcessPendingIcons()
    for icon, data in pairs(self.__pendingIcons) do
        if icon and icon:IsShown() and not icon.__mbtSkinned then
            pcall(function() self:SkinIcon(icon, data.settings) end)
        end
        self.__pendingIcons[icon] = nil
    end
end

local function EnsurePendingEventFrame()
    if MyEssentialIconViewers.__iconSkinEventFrame then return end
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("PLAYER_REGEN_ENABLED")
    ef:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            MyEssentialIconViewers:ProcessPendingIcons()
            ProcessPendingBackdrops()
        end
    end)
    MyEssentialIconViewers.__iconSkinEventFrame = ef
end

-- ---------------------------
-- ApplyViewerLayout (layout + skinning)
-- ---------------------------
function MyEssentialIconViewers:ApplyViewerLayout(viewer)
    if not viewer or not viewer.GetName then return end
    if not viewer:IsShown() then return end

    local settings = MyEssentialBuffTrackerDB
    local container = viewer.viewerFrame or viewer

    local icons = {}
    for _, child in ipairs({container:GetChildren()}) do
        if child and child.Icon then
            table.insert(icons, child)
        end
    end
    if #icons == 0 then
        viewer.__mbtLastNumRows = 0
        return
    end

    for i, icon in ipairs(icons) do
        icon.__mbtCreationOrder = icon.__mbtCreationOrder or i
    end
    table.sort(icons, function(a,b)
        return (a.layoutIndex or a:GetID() or a.__mbtCreationOrder) < (b.layoutIndex or b:GetID() or b.__mbtCreationOrder)
    end)

    local inCombat = InCombatLockdown()
    for _, icon in ipairs(icons) do
        if not icon.__mbtSkinned and not icon.__mbtSkinPending then
            icon.__mbtSkinPending = true
            if inCombat then
                EnsurePendingEventFrame()
                MyEssentialIconViewers.__pendingIcons[icon] = { icon=icon, settings=settings, viewer=viewer }
                MyEssentialIconViewers.__iconSkinEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            else
                pcall(function() MyEssentialIconViewers:SkinIcon(icon, settings) end)
                icon.__mbtSkinPending = nil
            end
        end
    end

    local shownIcons = {}
    for _, icon in ipairs(icons) do
        if icon:IsShown() then table.insert(shownIcons, icon) end
    end
    if #shownIcons == 0 then
        viewer.__mbtLastNumRows = 0
        return
    end

    local iconSize = SafeNumber(settings.iconSize, DEFAULTS.iconSize)

    -- Default base size
    for _, icon in ipairs(shownIcons) do
        icon:SetSize(iconSize, iconSize)
    end

    local iconWidth, iconHeight = iconSize, iconSize
    local spacing = settings.spacing or DEFAULTS.spacing

    -- Static Grid Mode (per-row size does NOT affect static grid)
    if settings.staticGridMode then
        local gridRows = SafeNumber(settings.gridRows, DEFAULTS.gridRows)
        local gridCols = SafeNumber(settings.gridColumns, DEFAULTS.gridColumns)
        local totalWidth = gridCols * iconWidth + (gridCols - 1) * spacing
        local totalHeight = gridRows * iconHeight + (gridRows - 1) * spacing

        settings.gridSlotMap = settings.gridSlotMap or {}

        local usedSlots = {}
        for _, icon in ipairs(shownIcons) do
            local iconID = icon.spellID or icon.auraInstanceID or icon:GetID() or icon.__mbtCreationOrder
            local key = tostring(iconID)
            if settings.gridSlotMap[key] then usedSlots[settings.gridSlotMap[key]] = true end
        end

        local nextSlot = 1
        for _, icon in ipairs(shownIcons) do
            local iconID = icon.spellID or icon.auraInstanceID or icon:GetID() or icon.__mbtCreationOrder
            local key = tostring(iconID)
            if not settings.gridSlotMap[key] then
                while usedSlots[nextSlot] do nextSlot = nextSlot + 1 end
                settings.gridSlotMap[key] = nextSlot
                usedSlots[nextSlot] = true
                nextSlot = nextSlot + 1
            end
        end

        for _, icon in ipairs(shownIcons) do
            local iconID = icon.spellID or icon.auraInstanceID or icon:GetID() or icon.__mbtCreationOrder
            local key = tostring(iconID)
            local slotNum = settings.gridSlotMap[key]
            if slotNum then
                local row = math.floor((slotNum - 1) / gridCols)
                local col = (slotNum - 1) % gridCols
                local x = -totalWidth / 2 + iconWidth / 2 + col * (iconWidth + spacing)
                local y = -totalHeight / 2 + iconHeight / 2 + row * (iconHeight + spacing)
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
            end
        end

        viewer.__mbtLastNumRows = gridRows

        if not InCombatLockdown() then viewer:SetSize(totalWidth, totalHeight) end
        return
    end

    -- Dynamic mode
    local rowLimit = SafeNumber(settings.rowLimit or settings.columns, DEFAULTS.rowLimit)

    -- Single-row mode
    if rowLimit <= 0 then
        local rowSize = (settings.rowSizes and settings.rowSizes[1]) or iconSize
        for _, icon in ipairs(shownIcons) do
            icon:SetSize(rowSize, rowSize)
        end
        local totalWidth = #shownIcons * rowSize + (#shownIcons - 1) * spacing
        local startX = -totalWidth / 2 + rowSize / 2
        for i, icon in ipairs(shownIcons) do
            local x = startX + (i-1)*(rowSize+spacing)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", container, "TOPLEFT", x, 0)
        end
        viewer.__mbtLastNumRows = 1
        if not InCombatLockdown() then
            viewer:SetSize(totalWidth, rowSize)
        end
    else
        -- Multi-row mode with per-row size
        local numRows = math.ceil(#shownIcons/rowLimit)
        local rows = {}
        local maxRowWidth = 0

        for r = 1, numRows do
            rows[r] = {}
            local startIdx = (r-1)*rowLimit + 1
            local endIdx = math.min(r*rowLimit, #shownIcons)
            for i=startIdx,endIdx do table.insert(rows[r], shownIcons[i]) end
        end

        local growDir = (settings.rowGrowDirection or DEFAULTS.rowGrowDirection):lower()

        for r = 1, numRows do
            local row = rows[r]

            local rowSize = (settings.rowSizes and settings.rowSizes[r]) or iconSize
            local w = rowSize
            local h = rowSize

            local rowWidth = #row * w + (#row - 1) * spacing
            if rowWidth > maxRowWidth then maxRowWidth = rowWidth end

            -- Center row horizontally at the TOP of the container
            local startX = -rowWidth/2 + w/2
            local y = 0
            if r > 1 then
                local rowSpacing = iconHeight + spacing
                y = (r-1) * (iconHeight + spacing)
            end

            for i, icon in ipairs(row) do
                local x = startX + (i-1)*(w+spacing)
                icon:SetSize(w, h)
                icon:ClearAllPoints()
                icon:SetPoint("TOP", container, "TOP", x, -y)
            end
        end

        local rowSpacing = iconHeight + spacing
        local totalHeight = (numRows-1)*rowSpacing + iconHeight

        viewer.__mbtLastNumRows = numRows

        if not InCombatLockdown() then
            viewer:SetSize(maxRowWidth, totalHeight)
        end
    end
    viewer.__mbtIconCount = #shownIcons
end

function MyEssentialIconViewers:RescanViewer(viewer)
    if not viewer or not viewer.GetName then return end
    MyEssentialIconViewers:ApplyViewerLayout(viewer)
end

MyEssentialBuffTracker = MyEssentialBuffTracker or {}
MyEssentialBuffTracker.IconViewers = MyEssentialIconViewers
-- ---------------------------
-- Robust event-driven viewer update logic
-- ---------------------------
local function IsCooldownIconFrame(frame)
    return frame and (frame.icon or frame.Icon) and frame.Cooldown
end

function MyEssentialIconViewers:ApplyViewerSkin(viewer)
    if not viewer or not viewer.GetName then return end
    local name = viewer:GetName()
    local settings = MyEssentialBuffTrackerDB
    if not settings then return end

    if self.ApplyViewerLayout then
        self:ApplyViewerLayout(viewer)
    end
    if self.SkinAllIconsInViewer then
        self:SkinAllIconsInViewer(viewer)
    end
    if self.ApplyViewerLayout then
        self:ApplyViewerLayout(viewer)
    end
    if not InCombatLockdown() then
        self:ProcessPendingIcons()
    end
end

function MyEssentialIconViewers:HookViewers()
    local viewers = {"EssentialCooldownViewer"}
    for _, name in ipairs(viewers) do
        local viewer = _G[name]
        if viewer and not viewer.__cdmHooked then
            viewer.__cdmHooked = true

            viewer:HookScript("OnShow", function(f)
                MyEssentialIconViewers:ApplyViewerSkin(f)
            end)

            viewer:HookScript("OnSizeChanged", function(f)
                if f.__cdmLayoutSuppressed or f.__cdmLayoutRunning then
                    return
                end
                if MyEssentialIconViewers.ApplyViewerLayout then
                    MyEssentialIconViewers:ApplyViewerLayout(f)
                end
            end)

            -- Minimal OnUpdate for pending icons only
            local lastProcessTime = 0
            viewer:HookScript("OnUpdate", function(f, elapsed)
                lastProcessTime = lastProcessTime + elapsed
                if lastProcessTime > 0.1 and not InCombatLockdown() then -- Process every 0.1 seconds
                    lastProcessTime = 0
                    MyEssentialIconViewers:ProcessPendingIcons()
                end
            end)

            self:ApplyViewerSkin(viewer)
        end
    end
end

-- Initialize event-driven hooks on login
local function InitEventDrivenHooks()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_LOGIN" then
            EnsureDB()
            MyEssentialIconViewers:HookViewers()
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                pcall(function() MyEssentialIconViewers:RescanViewer(viewer) end)
            end
        end
    end)
end

InitEventDrivenHooks()

-- ---------------------------
-- Config UI (original restored, with live preview + per-row sizes)
-- ---------------------------
local cfgFrame

-- Compact dropdown
local function CreateDropdown(parent, labelText, options, initial, onChanged)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(210, 50)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(0.85, 0.7, 1, 1)

    local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", -15, -20)
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, initial)

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option
            info.func = function()
                UIDropDownMenu_SetText(dropdown, option)
                onChanged(option)
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    pcall(ProcessPendingBackdrops)
                end
            end
            info.checked = (UIDropDownMenu_GetText(dropdown) == option)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return container
end


-- Modern Settings API panel for Essential Buffs
function MyEssentialBuffTracker:CreateOptionsPanel()
    EnsureDB()
    if _G.MyEssentialBuffTrackerPanel then return _G.MyEssentialBuffTrackerPanel end

    local panel = CreateFrame("Frame")
    panel.name = "Essential Buffs"


    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category, layout = Settings.RegisterVerticalLayoutCategory("Essential Buffs")

        -- Border Size Slider
        local borderSizeSetting = Settings.RegisterAddOnSetting(
            "essential_borderSize", -- unique key
            1, -- version
            function() return MyEssentialBuffTrackerDB.borderSize or 1 end,
            function(v)
                MyEssentialBuffTrackerDB.borderSize = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end
        )
        local borderSizeSlider = Settings.CreateSlider(
            borderSizeSetting,
            { label = "Border Size (pixels)", min = 0, max = 6, step = 1 }
        )
        layout:AddWidget(borderSizeSlider)

        -- Color pickers for cooldown and charge/stack text
        local textColors = {
            {name = "White", val = {1,1,1,1}},
            {name = "Yellow", val = {1,1,0,1}},
            {name = "Red", val = {1,0,0,1}},
            {name = "Green", val = {0,1,0,1}},
            {name = "Blue", val = {0,0,1,1}},
            {name = "Cyan", val = {0,1,1,1}},
            {name = "Magenta", val = {1,0,1,1}},
            {name = "Orange", val = {1,0.5,0,1}},
            {name = "Gray", val = {0.7,0.7,0.7,1}},
        }
        local function textColorName(val)
            for _,c in ipairs(textColors) do
                if c.val[1]==val[1] and c.val[2]==val[2] and c.val[3]==val[3] and c.val[4]==val[4] then return c.name end
            end
            return "Custom"
        end
        -- Cooldown Text Color Dropdown
        local cdColorSetting = Settings.RegisterAddOnSetting(
            "essential_cdTextColor", 1,
            function() return textColorName(MyEssentialBuffTrackerDB.cooldownTextColor or {1,1,1,1}) end,
            function(selected)
                for _,c in ipairs(textColors) do
                    if c.name == selected then
                        MyEssentialBuffTrackerDB.cooldownTextColor = c.val
                        local viewer = _G["EssentialCooldownViewer"]
                        if viewer then
                            ForceReskinViewer(viewer)
                            pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                        end
                    end
                end
            end
        )
        local cdColorDropdown = Settings.CreateDropDown(cdColorSetting, { label = "Cooldown Text Color", options = (function() local t={} for _,c in ipairs(textColors) do t[#t+1]=c.name end; return t end)() })
        layout:AddWidget(cdColorDropdown)

        -- Charge/Stack Text Color Dropdown
        local chargeColorSetting = Settings.RegisterAddOnSetting(
            "essential_chargeTextColor", 1,
            function() return textColorName(MyEssentialBuffTrackerDB.chargeTextColor or {1,1,1,1}) end,
            function(selected)
                for _,c in ipairs(textColors) do
                    if c.name == selected then
                        MyEssentialBuffTrackerDB.chargeTextColor = c.val
                        local viewer = _G["EssentialCooldownViewer"]
                        if viewer then
                            ForceReskinViewer(viewer)
                            pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                        end
                    end
                end
            end
        )
        local chargeColorDropdown = Settings.CreateDropDown(chargeColorSetting, { label = "Charge/Stack Text Color", options = (function() local t={} for _,c in ipairs(textColors) do t[#t+1]=c.name end; return t end)() })
        layout:AddWidget(chargeColorDropdown)

        category:SetLayout(layout)
        _G.MyEssentialBuffTrackerPanel = category:GetFrame()
        return _G.MyEssentialBuffTrackerPanel
    end

    -- Fallback: empty panel
    _G.MyEssentialBuffTrackerPanel = panel
    return panel
end

-- Compact checkbox
local function CreateCheckbox(parent, labelText, initial, onChanged)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(210, 24)

    local checkbox = CreateFrame("CheckButton", nil, container)
    checkbox:SetPoint("LEFT", 0, 0)
    checkbox:SetSize(20, 20)
    checkbox:SetChecked(initial)

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("LEFT", checkbox, 0, 0)
    bg:SetSize(20, 20)
    bg:SetColorTexture(0.1, 0.05, 0.15, 0.8)

    local check = checkbox:CreateTexture(nil, "OVERLAY")
    check:SetAllPoints(checkbox)
    check:SetColorTexture(0.2, 0.9, 0.3, 1)
    check:SetAlpha(initial and 1 or 0)
    checkbox:SetCheckedTexture(check)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
    label:SetText(labelText)
    label:SetTextColor(0.85, 0.7, 1, 1)

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        check:SetAlpha(checked and 1 or 0)
        onChanged(checked)
        local viewer = _G["EssentialCooldownViewer"]
        if viewer then
            ForceReskinViewer(viewer)
            pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            pcall(ProcessPendingBackdrops)
        end
    end)

    return container
end

function MyEssentialBuffTracker.ShowConfig()
        -- Border Size Slider
        local borderSizeSetting = Settings.RegisterAddOnSetting(
            "essential_borderSize", -- unique key
            1, -- version
            function() return MyEssentialBuffTrackerDB.borderSize or 1 end,
            function(v)
                MyEssentialBuffTrackerDB.borderSize = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end
        )
        local borderSizeSlider = Settings.CreateSlider(
            borderSizeSetting,
            { label = "Border Size (pixels)", min = 0, max = 8, step = 1 }
        )
        layout:AddWidget(borderSizeSlider)

        -- 1-Pixel Black Border Slider (when corner radius is 1)
        local onePixelBorderSetting = Settings.RegisterAddOnSetting(
            "essential_onePixelBorder", -- unique key
            1, -- version
            function() return MyEssentialBuffTrackerDB.onePixelBorder or 1 end,
            function(v)
                MyEssentialBuffTrackerDB.onePixelBorder = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end
        )
        local onePixelBorderSlider = Settings.CreateSlider(
            onePixelBorderSetting,
            { label = "1-Pixel Black Border (when corner radius is 1)", min = 0, max = 1, step = 1 }
        )
        layout:AddWidget(onePixelBorderSlider)
            -- Simple color picker for border (black/white/gray)
            local borderColors = {
                {name = "Black", val = {0,0,0,1}},
                {name = "White", val = {1,1,1,1}},
                {name = "Gray", val = {0.5,0.5,0.5,1}},
                {name = "Red", val = {1,0,0,1}},
                {name = "Green", val = {0,1,0,1}},
                {name = "Blue", val = {0,0,1,1}},
            }
            local function colorName(val)
                for _,c in ipairs(borderColors) do
                    if c.val[1]==val[1] and c.val[2]==val[2] and c.val[3]==val[3] and c.val[4]==val[4] then return c.name end
                end
                return "Custom"
            end
            local borderColorDropdown = CreateDropdown(cfgFrame, "Border Color", (function() local t={} for _,c in ipairs(borderColors) do t[#t+1]=c.name end; return t end)(), colorName(MyEssentialBuffTrackerDB.borderColor or {0,0,0,1}),
                function(selected)
                    for _,c in ipairs(borderColors) do
                        if c.name == selected then
                            MyEssentialBuffTrackerDB.borderColor = c.val
                            local viewer = _G["EssentialCooldownViewer"]
                            if viewer then
                                ForceReskinViewer(viewer)
                                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                            end
                        end
                    end
                end)
            borderColorDropdown:SetPoint("TOPLEFT", x2, y+46)
        -- Border settings
        local borderTitle = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        borderTitle:SetPoint("TOPLEFT", x1, y)
        borderTitle:SetText("Icon Border")
        borderTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24

        local borderSizeSlider = CreateSlider(cfgFrame, "Border Size (pixels)", 0, 8, 1, MyEssentialBuffTrackerDB.borderSize or 1,
            function(v)
                MyEssentialBuffTrackerDB.borderSize = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        borderSizeSlider:SetPoint("TOPLEFT", x1, y)
        y = y - 46

        -- Simple color picker for border (black/white/gray)
        local borderColors = {
            {name = "Black", val = {0,0,0,1}},
            {name = "White", val = {1,1,1,1}},
            {name = "Gray", val = {0.5,0.5,0.5,1}},
            {name = "Red", val = {1,0,0,1}},
            {name = "Green", val = {0,1,0,1}},
            {name = "Blue", val = {0,0,1,1}},
        }
        local function colorName(val)
            for _,c in ipairs(borderColors) do
                if c.val[1]==val[1] and c.val[2]==val[2] and c.val[3]==val[3] and c.val[4]==val[4] then return c.name end
            end
            return "Custom"
        end
        local borderColorDropdown = CreateDropdown(cfgFrame, "Border Color", (function() local t={} for _,c in ipairs(borderColors) do t[#t+1]=c.name end; return t end)(), colorName(MyEssentialBuffTrackerDB.borderColor or {0,0,0,1}),
            function(selected)
                for _,c in ipairs(borderColors) do
                    if c.name == selected then
                        MyEssentialBuffTrackerDB.borderColor = c.val
                        local viewer = _G["EssentialCooldownViewer"]
                        if viewer then
                            ForceReskinViewer(viewer)
                            pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                        end
                    end
                end
            end)
        borderColorDropdown:SetPoint("TOPLEFT", x2, y+46)
    EnsureDB()
    if cfgFrame and cfgFrame:IsShown() then cfgFrame:Hide(); return end

    if not cfgFrame then
        cfgFrame = CreateFrame("Frame", "MyEssentialBuffTrackerConfig", UIParent, "BackdropTemplate")
        cfgFrame:SetSize(550, 1100)
        cfgFrame:SetPoint("CENTER")
        cfgFrame:SetMovable(true)
        cfgFrame:EnableMouse(true)
        cfgFrame:RegisterForDrag("LeftButton")
        cfgFrame:SetScript("OnDragStart", cfgFrame.StartMoving)
        cfgFrame:SetScript("OnDragStop", cfgFrame.StopMovingOrSizing)

        cfgFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        cfgFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        cfgFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local titleBg = cfgFrame:CreateTexture(nil, "ARTWORK")
        titleBg:SetPoint("TOPLEFT", 4, -4)
        titleBg:SetPoint("TOPRIGHT", -4, -4)
        titleBg:SetHeight(28)
        titleBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

        local title = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("MyEssentialBuffTracker")
        title:SetTextColor(1, 1, 1, 1)

        local closeBtn = CreateFrame("Button", nil, cfgFrame)
        closeBtn:SetSize(20, 20)
        closeBtn:SetPoint("TOPRIGHT", -8, -8)
        local closeBg = closeBtn:CreateTexture(nil, "BACKGROUND")
        closeBg:SetAllPoints()
        closeBg:SetColorTexture(0.6, 0.1, 0.1, 0.8)
        local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        closeText:SetText("X")
        closeText:SetTextColor(1, 1, 1, 1)
        closeText:SetPoint("CENTER")
        closeBtn:SetScript("OnEnter", function() closeBg:SetColorTexture(0.9, 0.1, 0.1, 1) end)
        closeBtn:SetScript("OnLeave", function() closeBg:SetColorTexture(0.6, 0.1, 0.1, 0.8) end)
        closeBtn:SetScript("OnClick", function() cfgFrame:Hide() end)

        cfgFrame._contentBuilt = false
    end

    if not cfgFrame._contentBuilt then
        cfgFrame._contentBuilt = true

        local x1, x2 = 20, 290
        local y = -48


        -- ICON SETTINGS
        local iconTitle = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconTitle:SetPoint("TOPLEFT", x1, y)
        iconTitle:SetText("Icon Settings")
        iconTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24

        local iconSizeSlider = CreateSlider(cfgFrame, "Icon Size", -200, 300, 1, MyEssentialBuffTrackerDB.iconSize,
            function(v)
                MyEssentialBuffTrackerDB.iconSize = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        iconSizeSlider:SetPoint("TOPLEFT", x1, y)

        local aspectRatioSlider = CreateSlider(cfgFrame, "Aspect Ratio", 0.1, 5.0, 0.01, MyEssentialBuffTrackerDB.aspectRatioCrop or 1.0,
            function(v)
                MyEssentialBuffTrackerDB.aspectRatioCrop = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        aspectRatioSlider:SetPoint("TOPLEFT", x2, y)
        y = y - 46

        local cornerRadius = CreateSlider(cfgFrame, "Corner Radius", -50, 100, 1, MyEssentialBuffTrackerDB.iconCornerRadius or 0,
            function(v)
                MyEssentialBuffTrackerDB.iconCornerRadius = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cornerRadius:SetPoint("TOPLEFT", x1, y)
        y = y - 52

        -- HIDE WHEN MOUNTED OPTION (moved up for visibility)
        local hideMount = CreateCheckbox(cfgFrame, "Hide when mounted", MyEssentialBuffTrackerDB.hideWhenMounted,
            function(v)
                MyEssentialBuffTrackerDB.hideWhenMounted = v
                UpdateCooldownManagerVisibility()
            end)
        hideMount:SetPoint("TOPLEFT", x1, y)
        y = y - 28

        -- SPACING & LAYOUT
        local spaceTitle = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        spaceTitle:SetPoint("TOPLEFT", x1, y)
        spaceTitle:SetText("Spacing & Layout")
        spaceTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24

        local hSpace = CreateSlider(cfgFrame, "Horizontal Spacing", -200, 200, 1, MyEssentialBuffTrackerDB.spacing,
            function(v)
                MyEssentialBuffTrackerDB.spacing = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        hSpace:SetPoint("TOPLEFT", x1, y)

        local vSpace = CreateSlider(cfgFrame, "Vertical Spacing", -200, 200, 1, MyEssentialBuffTrackerDB.spacing,
            function(v)
                MyEssentialBuffTrackerDB.spacing = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        vSpace:SetPoint("TOPLEFT", x2, y)
        y = y - 46

        local perRow = CreateSlider(cfgFrame, "Icons Per Row", 1, 50, 1, MyEssentialBuffTrackerDB.columns,
            function(v)
                MyEssentialBuffTrackerDB.columns = v; MyEssentialBuffTrackerDB.rowLimit = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        perRow:SetPoint("TOPLEFT", x1, y)
        y = y - 52

        y = y - 46

        cfgFrame._dynamicYStart = y
    end

    -- Rebuild per-row size controls each time the window is opened
    if cfgFrame._rowSizeWidgets then
        for _, w in ipairs(cfgFrame._rowSizeWidgets) do
            if w then w:Hide() end
        end
    end
    cfgFrame._rowSizeWidgets = {}

    local x1, x2 = 20, 290
    local y = cfgFrame._dynamicYStart or -300

    local viewer = _G["EssentialCooldownViewer"]
    local numRows = 1
    if viewer and viewer.__mbtLastNumRows and viewer.__mbtLastNumRows > 0 then
        numRows = viewer.__mbtLastNumRows
    end

    local rowSizeTitle = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rowSizeTitle:SetPoint("TOPLEFT", x1, y)
    rowSizeTitle:SetText("Row Icon Sizes")
    rowSizeTitle:SetTextColor(0.9, 0.9, 0.9, 1)
    y = y - 24
    table.insert(cfgFrame._rowSizeWidgets, rowSizeTitle)

    for r = 1, numRows do
        local current = (MyEssentialBuffTrackerDB.rowSizes and MyEssentialBuffTrackerDB.rowSizes[r]) or MyEssentialBuffTrackerDB.iconSize
        local rowSlider = CreateSlider(cfgFrame, "Row "..r.." Size", 1, 200, 1, current,
            function(v)
                MyEssentialBuffTrackerDB.rowSizes[r] = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        rowSlider:SetPoint("TOPLEFT", x1, y)
        y = y - 46
        table.insert(cfgFrame._rowSizeWidgets, rowSlider)
    end


    -- HIDE WHEN MOUNTED OPTION
    local hideMount = CreateCheckbox(cfgFrame, "Hide when mounted", MyEssentialBuffTrackerDB.hideWhenMounted,
        function(v)
            MyEssentialBuffTrackerDB.hideWhenMounted = v
            UpdateCooldownManagerVisibility()
        end)
    hideMount:SetPoint("TOPLEFT", x1, y)
    y = y - 28

    -- COOLDOWN TEXT
    local cdTitle = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cdTitle:SetPoint("TOPLEFT", x1, y)
    cdTitle:SetText("Cooldown Text")
    cdTitle:SetTextColor(0.9, 0.9, 0.9, 1)
    y = y - 24

    local showCD = CreateCheckbox(cfgFrame, "Show Cooldown Text", MyEssentialBuffTrackerDB.showCooldownText,
        function(v)
            MyEssentialBuffTrackerDB.showCooldownText = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    showCD:SetPoint("TOPLEFT", x1, y)
    y = y - 28

    -- Color pickers for cooldown and charge/stack text
    local textColors = {
        {name = "White", val = {1,1,1,1}},
        {name = "Yellow", val = {1,1,0,1}},
        {name = "Red", val = {1,0,0,1}},
        {name = "Green", val = {0,1,0,1}},
        {name = "Blue", val = {0,0,1,1}},
        {name = "Cyan", val = {0,1,1,1}},
        {name = "Magenta", val = {1,0,1,1}},
        {name = "Orange", val = {1,0.5,0,1}},
        {name = "Gray", val = {0.7,0.7,0.7,1}},
    }
    local function textColorName(val)
        for _,c in ipairs(textColors) do
            if c.val[1]==val[1] and c.val[2]==val[2] and c.val[3]==val[3] and c.val[4]==val[4] then return c.name end
        end
        return "Custom"
    end
    MyEssentialBuffTrackerDB.cooldownTextColor = MyEssentialBuffTrackerDB.cooldownTextColor or {1,1,1,1}
    MyEssentialBuffTrackerDB.chargeTextColor = MyEssentialBuffTrackerDB.chargeTextColor or {1,1,1,1}

    -- DEBUG: Add a test label to confirm code path
    local testLabel = cfgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    testLabel:SetPoint("TOPLEFT", x1, y)
    testLabel:SetText("[DEBUG] Color pickers should be below")
    testLabel:SetTextColor(1, 0, 0, 1)
    y = y - 24

    local cdColorDropdown = CreateDropdown(cfgFrame, "Cooldown Text Color", (function() local t={} for _,c in ipairs(textColors) do t[#t+1]=c.name end; return t end)(), textColorName(MyEssentialBuffTrackerDB.cooldownTextColor),
        function(selected)
            for _,c in ipairs(textColors) do
                if c.name == selected then
                    MyEssentialBuffTrackerDB.cooldownTextColor = c.val
                    local viewer = _G["EssentialCooldownViewer"]
                    if viewer then
                        ForceReskinViewer(viewer)
                        pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    end
                end
            end
        end)
    cdColorDropdown:SetPoint("TOPLEFT", x1, y)
    if cdColorDropdown.SetFrameStrata then cdColorDropdown:SetFrameStrata("DIALOG") end
    if cdColorDropdown.Show then cdColorDropdown:Show() end
    y = y - 46

    local chargeColorDropdown = CreateDropdown(cfgFrame, "Charge/Stack Text Color", (function() local t={} for _,c in ipairs(textColors) do t[#t+1]=c.name end; return t end)(), textColorName(MyEssentialBuffTrackerDB.chargeTextColor),
        function(selected)
            for _,c in ipairs(textColors) do
                if c.name == selected then
                    MyEssentialBuffTrackerDB.chargeTextColor = c.val
                    local viewer = _G["EssentialCooldownViewer"]
                    if viewer then
                        ForceReskinViewer(viewer)
                        pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    end
                end
            end
        end)
    chargeColorDropdown:SetPoint("TOPLEFT", x1, y)
    if chargeColorDropdown.SetFrameStrata then chargeColorDropdown:SetFrameStrata("DIALOG") end
    if chargeColorDropdown.Show then chargeColorDropdown:Show() end
    y = y - 46

    local cdSize = CreateSlider(cfgFrame, "Text Size", 1, 100, 1, MyEssentialBuffTrackerDB.cooldownTextSize,
        function(v)
            MyEssentialBuffTrackerDB.cooldownTextSize = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    cdSize:SetPoint("TOPLEFT", x1, y)

    local cdX = CreateSlider(cfgFrame, "X Offset", -100, 100, 1, MyEssentialBuffTrackerDB.cooldownTextX or 0,
        function(v)
            MyEssentialBuffTrackerDB.cooldownTextX = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    cdX:SetPoint("TOPLEFT", x2, y)
    y = y - 46

    local cdY = CreateSlider(cfgFrame, "Y Offset", -100, 100, 1, MyEssentialBuffTrackerDB.cooldownTextY or 0,
        function(v)
            MyEssentialBuffTrackerDB.cooldownTextY = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    cdY:SetPoint("TOPLEFT", x1, y)
    y = y - 46

    local positionOptions = {"CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
    local cdPosition = CreateDropdown(cfgFrame, "Position", positionOptions, MyEssentialBuffTrackerDB.cooldownTextPosition or "CENTER",
        function(v)
            MyEssentialBuffTrackerDB.cooldownTextPosition = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    cdPosition:SetPoint("TOPLEFT", x1, y)
    y = y - 52

    local function HookViewer()
        local viewer = _G["EssentialCooldownViewer"]
        if not viewer then return end

        viewer:SetMovable(not MyEssentialBuffTrackerDB.locked)
        viewer:EnableMouse(not MyEssentialBuffTrackerDB.locked)

        viewer:HookScript("OnShow", function(self) pcall(function() MyEssentialIconViewers:RescanViewer(self) end) end)
        viewer:HookScript("OnSizeChanged", function(self) pcall(function() MyEssentialIconViewers:ApplyViewerLayout(self) end) end)

        if not viewer._MyEssentialBuffTrackerTickerFrame then
            local ticker = CreateFrame("Frame", nil, viewer)
            ticker.elapsed = 0
            ticker:SetScript("OnUpdate", function(self, elapsed)
                if IsEditModeActive() then return end
                self.elapsed = self.elapsed + elapsed
                if self.elapsed >= 0.2 then
                    self.elapsed = 0
                    pcall(function()
                        if viewer and viewer:IsShown() then
                            MyEssentialIconViewers:RescanViewer(viewer)
                        end
                    end)
                end
            end)
            viewer._MyEssentialBuffTrackerTickerFrame = ticker
        end
    end

    HookViewer()
    local chargeX = CreateSlider(cfgFrame, "X Offset", -100, 100, 1, MyEssentialBuffTrackerDB.chargeTextX or 0,
        function(v)
            MyEssentialBuffTrackerDB.chargeTextX = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    chargeX:SetPoint("TOPLEFT", x2, y)
    y = y - 46

    local chargeY = CreateSlider(cfgFrame, "Y Offset", -100, 100, 1, MyEssentialBuffTrackerDB.chargeTextY or 0,
        function(v)
            MyEssentialBuffTrackerDB.chargeTextY = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    chargeY:SetPoint("TOPLEFT", x1, y)
    y = y - 46

    local chargePosition = CreateDropdown(cfgFrame, "Position", positionOptions, MyEssentialBuffTrackerDB.chargeTextPosition or "BOTTOMRIGHT",
        function(v)
            MyEssentialBuffTrackerDB.chargeTextPosition = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                ForceReskinViewer(viewer)
                pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            end
        end)
    chargePosition:SetPoint("TOPLEFT", x1, y)
    y = y - 52

    -- OTHER
    local lockFrame = CreateCheckbox(cfgFrame, "Lock Frame", MyEssentialBuffTrackerDB.locked,
        function(v)
            MyEssentialBuffTrackerDB.locked = v
            local viewer = _G["EssentialCooldownViewer"]
            if viewer then
                viewer:SetMovable(not v)
                viewer:EnableMouse(not v)
            end
        end)
    lockFrame:SetPoint("TOPLEFT", x1, y)

    cfgFrame:Show()
end

SLASH_MYESSENTIALBUFFTRACKER1 = "/mebt"
SlashCmdList.MYESSENTIALBUFFTRACKER = function()
    MyEssentialBuffTracker.ShowConfig()
end

-- ---------------------------
-- Initialization
-- ---------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        MyEssentialIconViewers:HookViewers()
        local viewer = _G["EssentialCooldownViewer"]
        if viewer then
            pcall(function() MyEssentialIconViewers:RescanViewer(viewer) end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            local viewer = _G["EssentialCooldownViewer"]
            if viewer and not viewer:IsShown() then
                viewer:Show()
                C_Timer.After(5, function()
                    if viewer then viewer:Hide() end
                end)
            end
        end)
    end
end)

-- ---------------------------
-- Config UI (original restored, with live preview + per-row sizes)
-- ---------------------------
local cfgFrame

-- Compact dropdown
local function CreateDropdown(parent, labelText, options, initial, onChanged)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(210, 50)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(0.85, 0.7, 1, 1)

    local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", -15, -20)
    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_SetText(dropdown, initial)

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, option in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option
            info.func = function()
                UIDropDownMenu_SetText(dropdown, option)
                onChanged(option)
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    pcall(ProcessPendingBackdrops)
                end
            end
            info.checked = (UIDropDownMenu_GetText(dropdown) == option)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return container
end

-- Compact slider with input
local function CreateSlider(parent, labelText, min, max, step, initial, onChanged)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(210, 40)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 4)
    label:SetText(labelText)
    label:SetTextColor(0.85, 0.7, 1, 1)

    local sliderName = (parent:GetName() or "SliderParent") .. labelText:gsub("%s+", "") .. "Slider"
    local slider = CreateFrame("Slider", sliderName, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetSize(140, 16)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(initial)

    -- Show value above slider
    local valueText = _G[slider:GetName() .. 'Text']
    if valueText then
        valueText:ClearAllPoints()
        valueText:SetPoint("BOTTOM", slider, "TOP", 0, 4)
        local _, fontHeight = valueText:GetFont()
        valueText:SetFont("Fonts\\FRIZQT__.TTF", (fontHeight or 12) + 5, "OUTLINE")
        valueText:SetText(tostring(slider:GetValue()))
    end

    local input = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    input:SetSize(50, 20)
    input:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    input:SetAutoFocus(false)
    input:SetMaxLetters(6)

    -- Middle mouse edit box
    local editBox = CreateFrame("EditBox", nil, slider, "BackdropTemplate")
    editBox:SetAutoFocus(true)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetSize(60, 24)
    editBox:SetJustifyH("CENTER")
    editBox:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 }})
    editBox:SetBackdropColor(0,0,0,0.8)
    editBox:Hide()
    editBox:SetPoint("CENTER", slider, "CENTER")
    editBox:SetScript("OnEscapePressed", function(self) self:Hide() end)
    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= min and val <= max then
            slider:SetValue(val)
            input:SetText(tostring(val))
            if valueText then valueText:SetText(tostring(math.floor(val))) end
            onChanged(val)
        end
        self:Hide()
    end)
    editBox:SetScript("OnEditFocusLost", function(self) self:Hide() end)
    slider:HookScript("OnMouseDown", function(self, btn)
        if btn == "MiddleButton" then
            editBox:SetText(tostring(math.floor(self:GetValue())))
            editBox:Show()
            editBox:SetFocus()
        end
    end)

    -- Helper to set both slider and input box value
    local function SetValue(val)
        if step >= 1 then val = math.floor(val + 0.5) end
        slider:SetValue(val)
        input:SetText(tostring(val))
        if valueText then valueText:SetText(tostring(math.floor(val))) end
    end

    -- Set initial value
    SetValue(initial)

    local function UpdateValue(val)
        if step >= 1 then val = math.floor(val + 0.5) end
        input:SetText(tostring(val))
        if valueText then valueText:SetText(tostring(math.floor(val))) end
        onChanged(val)
        local viewer = _G["EssentialCooldownViewer"]
        if viewer then
            ForceReskinViewer(viewer)
            pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            pcall(ProcessPendingBackdrops)
        end
    end

    slider:SetScript("OnValueChanged", function(self, val)
        input:SetText(tostring(val))
        if valueText then
            valueText:SetText(tostring(math.floor(val)))
            valueText:Show()
        end
        onChanged(val)
        local viewer = _G["EssentialCooldownViewer"]
        if viewer then
            ForceReskinViewer(viewer)
            pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            pcall(ProcessPendingBackdrops)
        end
    end)

    input:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= min and val <= max then
            slider:SetValue(val)
        else
            self:SetText(tostring(slider:GetValue()))
        end
        self:ClearFocus()
    end)

    input:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(slider:GetValue()))
        self:ClearFocus()
    end)

    -- Always keep input in sync if shown
    container:SetScript("OnShow", function()
        input:SetText(tostring(slider:GetValue()))
        if valueText then valueText:SetText(tostring(math.floor(slider:GetValue()))) end
    end)

    return container
end

-- Compact checkbox
local function CreateCheckbox(parent, labelText, initial, onChanged)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(210, 24)

    local checkbox = CreateFrame("CheckButton", nil, container)
    checkbox:SetPoint("LEFT", 0, 0)
    checkbox:SetSize(20, 20)
    checkbox:SetChecked(initial)

    local bg = container:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("LEFT", checkbox, 0, 0)
    bg:SetSize(20, 20)
    bg:SetColorTexture(0.1, 0.05, 0.15, 0.8)

    local check = checkbox:CreateTexture(nil, "OVERLAY")
    check:SetAllPoints(checkbox)
    check:SetColorTexture(0.2, 0.9, 0.3, 1)
    check:SetAlpha(initial and 1 or 0)
    checkbox:SetCheckedTexture(check)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
    label:SetText(labelText)
    label:SetTextColor(0.85, 0.7, 1, 1)

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked() and true or false
        check:SetAlpha(checked and 1 or 0)
        onChanged(checked)
        local viewer = _G["EssentialCooldownViewer"]
        if viewer then
            ForceReskinViewer(viewer)
            pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
            pcall(ProcessPendingBackdrops)
        end
    end)

    return container
end


-- Addon Options Panel integration
local optionsPanel


function MyEssentialBuffTracker:CreateOptionsPanel()
    EnsureDB()
    if optionsPanel then return optionsPanel end
    optionsPanel = CreateFrame("Frame", "MyEssentialBuffTrackerOptionsPanel", InterfaceOptionsFramePanelContainer or UIParent)
        -- Always refresh UI when panel is shown
        optionsPanel:SetScript("OnShow", function()
            if MyEssentialBuffTracker and MyEssentialBuffTracker.UpdateSettings then
                MyEssentialBuffTracker:UpdateSettings()
            end
        end)
    optionsPanel.name = "MyEssentialBuffTracker"
    optionsPanel:SetSize(550, 1100)
    -- Add green note to top-right (after optionsPanel is created)
    local note = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -24, -26)
    note:SetText("Drag all spells in essential cooldown manager!")
    note:SetTextColor(0.2, 1, 0.2, 1)
    note:SetJustifyH("LEFT")

    -- ScrollFrame setup
    local scrollFrame = CreateFrame("ScrollFrame", nil, optionsPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(530, 2000)
    scrollFrame:SetScrollChild(content)

    optionsPanel._content = content


    -- Inline per-row slider builder, returns new y offset
    local function AddPerRowSliders(content, x1, y)
        -- Remove old widgets
        if content._rowSizeWidgets then
            for _, w in ipairs(content._rowSizeWidgets) do if w then w:Hide() end end
        end
        content._rowSizeWidgets = {}

        local viewer = _G["EssentialCooldownViewer"]
        local numRows = 1
        if viewer and viewer.__mbtLastNumRows and viewer.__mbtLastNumRows > 0 then
            numRows = viewer.__mbtLastNumRows
        end

        local rowSizeTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        rowSizeTitle:SetPoint("TOPLEFT", x1, y)
        rowSizeTitle:SetText("Row Icon Sizes")
        rowSizeTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24
        table.insert(content._rowSizeWidgets, rowSizeTitle)

        for r = 1, numRows do
            local current = (MyEssentialBuffTrackerDB.rowSizes and MyEssentialBuffTrackerDB.rowSizes[r]) or MyEssentialBuffTrackerDB.iconSize
            local rowSlider = CreateSlider(content, "Row "..r.." Size", 1, 200, 1, current,
                function(v)
                    MyEssentialBuffTrackerDB.rowSizes[r] = v
                    local viewer = _G["EssentialCooldownViewer"]
                    if viewer then
                        ForceReskinViewer(viewer)
                        pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                        -- Rebuild all config UI to update layout
                        if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                    end
                end)
            rowSlider:SetPoint("TOPLEFT", x1, y)
            y = y - 46
            table.insert(content._rowSizeWidgets, rowSlider)
        end
        return y
    end


    -- Rebuilds the entire config UI, including per-row sliders, with correct y-offsets
    function optionsPanel:_rebuildConfigUI()
        -- Remove all children except scroll bar
        for i, child in ipairs({content:GetChildren()}) do
            if not (child:GetObjectType() == "Slider" or child:GetObjectType() == "ScrollFrame") then
                child:Hide()
            end
        end

        local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("MyEssentialBuffTracker")
        title:SetTextColor(1, 1, 1, 1)

        local x1, x2 = 20, 290
        local y = -48


        -- ICON SETTINGS
        local iconTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconTitle:SetPoint("TOPLEFT", x1, y)
        iconTitle:SetText("Icon Settings")
        iconTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24

        local iconSizeSlider = CreateSlider(content, "Icon Size", -200, 300, 1, MyEssentialBuffTrackerDB.iconSize,
            function(v)
                MyEssentialBuffTrackerDB.iconSize = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        iconSizeSlider:SetPoint("TOPLEFT", x1, y)

        local aspectRatioSlider = CreateSlider(content, "Aspect Ratio", 0.1, 5.0, 0.01, MyEssentialBuffTrackerDB.aspectRatioCrop or 1.0,
            function(v)
                MyEssentialBuffTrackerDB.aspectRatioCrop = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        aspectRatioSlider:SetPoint("TOPLEFT", x2, y)
        y = y - 46

        local cornerRadius = CreateSlider(content, "Corner Radius", -50, 100, 1, MyEssentialBuffTrackerDB.iconCornerRadius or 0,
            function(v)
                MyEssentialBuffTrackerDB.iconCornerRadius = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cornerRadius:SetPoint("TOPLEFT", x1, y)
        y = y - 52

        -- HIDE WHEN MOUNTED OPTION (now visible in UI)
        local hideMount = CreateCheckbox(content, "Hide when mounted", MyEssentialBuffTrackerDB.hideWhenMounted,
            function(v)
                MyEssentialBuffTrackerDB.hideWhenMounted = v
                UpdateCooldownManagerVisibility()
            end)
        hideMount:SetPoint("TOPLEFT", x1, y)
        y = y - 28

        -- SPACING & LAYOUT
        local spaceTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        spaceTitle:SetPoint("TOPLEFT", x1, y)
        spaceTitle:SetText("Spacing & Layout")
        spaceTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24

        local hSpace = CreateSlider(content, "Horizontal Spacing", -200, 200, 1, MyEssentialBuffTrackerDB.spacing,
            function(v)
                MyEssentialBuffTrackerDB.spacing = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        hSpace:SetPoint("TOPLEFT", x1, y)

        local vSpace = CreateSlider(content, "Vertical Spacing", -200, 200, 1, MyEssentialBuffTrackerDB.spacing,
            function(v)
                MyEssentialBuffTrackerDB.spacing = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        vSpace:SetPoint("TOPLEFT", x2, y)
        y = y - 46

        local perRow = CreateSlider(content, "Icons Per Row", 1, 50, 1, MyEssentialBuffTrackerDB.columns,
            function(v)
                MyEssentialBuffTrackerDB.columns = v; MyEssentialBuffTrackerDB.rowLimit = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        perRow:SetPoint("TOPLEFT", x1, y)
        y = y - 52

        y = y - 46

        -- Insert per-row sliders inline, update y
        y = AddPerRowSliders(content, x1, y)

        -- COOLDOWN TEXT
        -- Only add Cooldown Text section label if not already present
        if not content._cdTitle then
            content._cdTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            content._cdTitle:SetPoint("TOPLEFT", x1, y)
            content._cdTitle:SetText("Cooldown Text")
            content._cdTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        else
            content._cdTitle:ClearAllPoints()
            content._cdTitle:SetPoint("TOPLEFT", x1, y)
            content._cdTitle:Show()
        end
        y = y - 24

        local showCD = CreateCheckbox(content, "Show Cooldown Text", MyEssentialBuffTrackerDB.showCooldownText,
            function(v)
                MyEssentialBuffTrackerDB.showCooldownText = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        showCD:SetPoint("TOPLEFT", x1, y)
        y = y - 28

        local cdSize = CreateSlider(content, "Text Size", 1, 100, 1, MyEssentialBuffTrackerDB.cooldownTextSize,
            function(v)
                MyEssentialBuffTrackerDB.cooldownTextSize = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cdSize:SetPoint("TOPLEFT", x1, y)

        local cdX = CreateSlider(content, "X Offset", -100, 100, 1, MyEssentialBuffTrackerDB.cooldownTextX or 0,
            function(v)
                MyEssentialBuffTrackerDB.cooldownTextX = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cdX:SetPoint("TOPLEFT", x2, y)
        y = y - 46

        local cdY = CreateSlider(content, "Y Offset", -100, 100, 1, MyEssentialBuffTrackerDB.cooldownTextY or 0,
            function(v)
                MyEssentialBuffTrackerDB.cooldownTextY = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cdY:SetPoint("TOPLEFT", x1, y)
        y = y - 46

        local positionOptions = {"CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
        local cdPosition = CreateDropdown(content, "Position", positionOptions, MyEssentialBuffTrackerDB.cooldownTextPosition or "CENTER",
            function(v)
                MyEssentialBuffTrackerDB.cooldownTextPosition = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cdPosition:SetPoint("TOPLEFT", x1, y)
        y = y - 52



        -- Charge/Count Text Size
        local chargeSize = CreateSlider(content, "Charge/Count Text Size", 1, 100, 1, MyEssentialBuffTrackerDB.chargeTextSize or 14,
            function(v)
                MyEssentialBuffTrackerDB.chargeTextSize = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        chargeSize:SetPoint("TOPLEFT", x2, y)
        y = y - 46


        local chargeX = CreateSlider(content, "X Offset", -100, 100, 1, MyEssentialBuffTrackerDB.chargeTextX or 0,
            function(v)
                MyEssentialBuffTrackerDB.chargeTextX = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        chargeX:SetPoint("TOPLEFT", x2, y)
        y = y - 46

        local chargeY = CreateSlider(content, "Y Offset", -100, 100, 1, MyEssentialBuffTrackerDB.chargeTextY or 0,
            function(v)
                MyEssentialBuffTrackerDB.chargeTextY = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        chargeY:SetPoint("TOPLEFT", x1, y)
        y = y - 46


        -- Add label above charge position dropdown only once
        if not content._chargePosLabel then
            content._chargePosLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            content._chargePosLabel:SetPoint("TOPLEFT", x1, y)
            content._chargePosLabel:SetText("Charge/Count Text Position")
            content._chargePosLabel:SetTextColor(0.85, 0.7, 1, 1)
        else
            content._chargePosLabel:ClearAllPoints()
            content._chargePosLabel:SetPoint("TOPLEFT", x1, y)
            content._chargePosLabel:Show()
        end
        y = y - 20

        local chargePosition = CreateDropdown(content, "Position", positionOptions, MyEssentialBuffTrackerDB.chargeTextPosition or "BOTTOMRIGHT",
            function(v)
                MyEssentialBuffTrackerDB.chargeTextPosition = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() MyEssentialIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        chargePosition:SetPoint("TOPLEFT", x1, y)
        y = y - 52

        -- OTHER
        local lockFrame = CreateCheckbox(content, "Lock Frame", MyEssentialBuffTrackerDB.locked,
            function(v)
                MyEssentialBuffTrackerDB.locked = v
                local viewer = _G["EssentialCooldownViewer"]
                if viewer then
                    viewer:SetMovable(not v)
                    viewer:EnableMouse(not v)
                end
            end)
        lockFrame:SetPoint("TOPLEFT", x1, y)
    end

    optionsPanel:_rebuildConfigUI()

    optionsPanel:HookScript("OnShow", function()
        if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
    end)

    -- Do not self-register; assign to global for parent registration
    _G.MyEssentialBuffTrackerPanel = optionsPanel
    return optionsPanel
end

-- Register the options panel on login
local optionsInit = CreateFrame("Frame")
optionsInit:RegisterEvent("PLAYER_LOGIN")
optionsInit:SetScript("OnEvent", function()
    MyEssentialBuffTracker:CreateOptionsPanel()
end)



-- ---------------------------
-- Initialization
-- ---------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:RegisterEvent("PLAYER_ENTERING_WORLD")
init:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        MyEssentialIconViewers:HookViewers()
        local viewer = _G["EssentialCooldownViewer"]
        if viewer then
            pcall(function() MyEssentialIconViewers:RescanViewer(viewer) end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            local viewer = _G["EssentialCooldownViewer"]
            if viewer and not viewer:IsShown() then
                viewer:Show()
                C_Timer.After(5, function()
                    if viewer then viewer:Hide() end
                end)
            end
        end)
    end
end)
