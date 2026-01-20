-- ======================================================
-- MyUtilityBuffTracker (Deterministic ordering, Aspect Ratio,
-- Multi-row center layout, Combat-safe skinning, EditMode safe)
-- Target: _G["UtilityCooldownViewer"]
-- ======================================================

-- SavedVariables
MyUtilityBuffTrackerDB = MyUtilityBuffTrackerDB or {}

-- Hide Cooldown Manager when mounted

-- Mount hide/show option
local function IsPlayerMounted()
    return IsMounted and IsMounted()
end

local function UpdateCooldownManagerVisibility()
    local viewer = _G["UtilityCooldownViewer"]
    if viewer then
        if MyUtilityBuffTrackerDB.hideWhenMounted then
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
    spacing         = 0,
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
}

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
    MyUtilityBuffTrackerDB.columns           = MyUtilityBuffTrackerDB.columns  or DEFAULTS.columns
    MyUtilityBuffTrackerDB.hSpacing          = MyUtilityBuffTrackerDB.hSpacing or DEFAULTS.hSpacing
    MyUtilityBuffTrackerDB.vSpacing          = MyUtilityBuffTrackerDB.vSpacing or DEFAULTS.vSpacing
    if MyUtilityBuffTrackerDB.growUp == nil then MyUtilityBuffTrackerDB.growUp = DEFAULTS.growUp end
    if MyUtilityBuffTrackerDB.locked == nil then MyUtilityBuffTrackerDB.locked = DEFAULTS.locked end
    MyUtilityBuffTrackerDB.iconSize          = MyUtilityBuffTrackerDB.iconSize or DEFAULTS.iconSize
    MyUtilityBuffTrackerDB.aspectRatio       = MyUtilityBuffTrackerDB.aspectRatio or DEFAULTS.aspectRatio
    MyUtilityBuffTrackerDB.aspectRatioCrop   = MyUtilityBuffTrackerDB.aspectRatioCrop or DEFAULTS.aspectRatioCrop
    MyUtilityBuffTrackerDB.spacing           = MyUtilityBuffTrackerDB.spacing or DEFAULTS.spacing
    MyUtilityBuffTrackerDB.rowLimit          = MyUtilityBuffTrackerDB.rowLimit or DEFAULTS.rowLimit
    MyUtilityBuffTrackerDB.rowGrowDirection  = MyUtilityBuffTrackerDB.rowGrowDirection or DEFAULTS.rowGrowDirection

    if MyUtilityBuffTrackerDB.iconCornerRadius == nil then MyUtilityBuffTrackerDB.iconCornerRadius = DEFAULTS.iconCornerRadius end
    MyUtilityBuffTrackerDB.cooldownTextSize  = MyUtilityBuffTrackerDB.cooldownTextSize or DEFAULTS.cooldownTextSize
    MyUtilityBuffTrackerDB.cooldownTextPosition = MyUtilityBuffTrackerDB.cooldownTextPosition or DEFAULTS.cooldownTextPosition
    MyUtilityBuffTrackerDB.cooldownTextX = MyUtilityBuffTrackerDB.cooldownTextX or DEFAULTS.cooldownTextX
    MyUtilityBuffTrackerDB.cooldownTextY = MyUtilityBuffTrackerDB.cooldownTextY or DEFAULTS.cooldownTextY
    MyUtilityBuffTrackerDB.chargeTextSize    = MyUtilityBuffTrackerDB.chargeTextSize or DEFAULTS.chargeTextSize
    MyUtilityBuffTrackerDB.chargeTextPosition = MyUtilityBuffTrackerDB.chargeTextPosition or DEFAULTS.chargeTextPosition
    MyUtilityBuffTrackerDB.chargeTextX = MyUtilityBuffTrackerDB.chargeTextX or DEFAULTS.chargeTextX
    MyUtilityBuffTrackerDB.chargeTextY = MyUtilityBuffTrackerDB.chargeTextY or DEFAULTS.chargeTextY

    if MyUtilityBuffTrackerDB.showCooldownText == nil then MyUtilityBuffTrackerDB.showCooldownText = DEFAULTS.showCooldownText end
    if MyUtilityBuffTrackerDB.showChargeText == nil then MyUtilityBuffTrackerDB.showChargeText = DEFAULTS.showChargeText end
    if MyUtilityBuffTrackerDB.hideWhenMounted == nil then MyUtilityBuffTrackerDB.hideWhenMounted = DEFAULTS.hideWhenMounted end

    if MyUtilityBuffTrackerDB.staticGridMode == nil then MyUtilityBuffTrackerDB.staticGridMode = DEFAULTS.staticGridMode end
    MyUtilityBuffTrackerDB.gridRows = MyUtilityBuffTrackerDB.gridRows or DEFAULTS.gridRows
    MyUtilityBuffTrackerDB.gridColumns = MyUtilityBuffTrackerDB.gridColumns or DEFAULTS.gridColumns
    MyUtilityBuffTrackerDB.gridSlotMap = MyUtilityBuffTrackerDB.gridSlotMap or {}

    -- Per-row sizes
    MyUtilityBuffTrackerDB.rowSizes = MyUtilityBuffTrackerDB.rowSizes or {}
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
-- UtilityIconViewers Core (initialize early)
-- ---------------------------
UtilityIconViewers = UtilityIconViewers or {}
UtilityIconViewers.__pendingIcons = UtilityIconViewers.__pendingIcons or {}
UtilityIconViewers.__iconSkinEventFrame = UtilityIconViewers.__iconSkinEventFrame or nil
UtilityIconViewers.__pendingBackdrops = UtilityIconViewers.__pendingBackdrops or {}
UtilityIconViewers.__backdropEventFrame = UtilityIconViewers.__backdropEventFrame or nil

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
    if not UtilityIconViewers.__pendingBackdrops then return end
    for frame, info in pairs(UtilityIconViewers.__pendingBackdrops) do
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
                    UtilityIconViewers.__pendingBackdrops[frame] = nil
                end
            end
        end
    end
end

local function EnsureBackdropEventFrame()
    if UtilityIconViewers.__backdropEventFrame then return end
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("PLAYER_REGEN_ENABLED")
    ef:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            ProcessPendingBackdrops()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
    end)
    UtilityIconViewers.__backdropEventFrame = ef
end

local function SafeSetBackdrop(frame, backdropInfo, color)
    if not frame or not frame.SetBackdrop then return false end

    if InCombatLockdown() then
        frame.__mbtBackdropPending = true
        UtilityIconViewers.__pendingBackdrops = UtilityIconViewers.__pendingBackdrops or {}
        UtilityIconViewers.__pendingBackdrops[frame] = { backdrop = backdropInfo, color = color }
        EnsureBackdropEventFrame()
        UtilityIconViewers.__backdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
        UtilityIconViewers.__pendingBackdrops = UtilityIconViewers.__pendingBackdrops or {}
        UtilityIconViewers.__pendingBackdrops[frame] = { backdrop = backdropInfo, color = color }
        EnsureBackdropEventFrame()
        UtilityIconViewers.__backdropEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
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
function UtilityIconViewers:SkinIcon(icon, settings)
    if not icon then return false end

    local iconTexture = icon.Icon or icon.icon
    if not iconTexture then return false end

    settings = settings or MyUtilityBuffTrackerDB

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
            -- Set charge/stack text color from ChargeTextColorOptions
            local color = (_G.CooldownChargeDB and _G.CooldownChargeDB["TextColor_ChargeText_Utility"]) or {1,1,1,1}
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
            -- Set cooldown text color from ChargeTextColorOptions
            local color = (_G.CooldownChargeDB and _G.CooldownChargeDB["TextColor_CooldownText_Utility"]) or {1,1,1,1}
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
    local borderSize = 1
    local borderColor = {0, 0, 0, 1}

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
function UtilityIconViewers:ProcessPendingIcons()
    for icon, data in pairs(self.__pendingIcons) do
        if icon and icon:IsShown() and not icon.__mbtSkinned then
            pcall(function() self:SkinIcon(icon, data.settings) end)
        end
        self.__pendingIcons[icon] = nil
    end
end

local function EnsurePendingEventFrame()
    if UtilityIconViewers.__iconSkinEventFrame then return end
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("PLAYER_REGEN_ENABLED")
    ef:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            UtilityIconViewers:ProcessPendingIcons()
            ProcessPendingBackdrops()
        end
    end)
    UtilityIconViewers.__iconSkinEventFrame = ef
end

-- ---------------------------
-- ApplyViewerLayout (layout + skinning)
-- ---------------------------
function UtilityIconViewers:ApplyViewerLayout(viewer)
    if not viewer or not viewer.GetName then return end
    if not viewer:IsShown() then return end

    -- Defensive: if viewer.viewerFrame is a string name, resolve it
    if viewer.viewerFrame and type(viewer.viewerFrame) == "string" then
        local resolved = _G[viewer.viewerFrame]
        if resolved then viewer.viewerFrame = resolved end
    end

    local settings = MyUtilityBuffTrackerDB
    local container = viewer.viewerFrame or viewer

    local icons = {}
    local okChildren, children = pcall(function() return {container:GetChildren()} end)
    if okChildren and children then
        for _, child in ipairs(children) do
            if child and (child.Icon or child.icon) then
                table.insert(icons, child)
            end
        end
    else
        -- Fallback: try viewer:GetChildren directly if container failed
        local okAlt, altChildren = pcall(function() return {viewer:GetChildren()} end)
        if okAlt and altChildren then
            for _, child in ipairs(altChildren) do
                if child and (child.Icon or child.icon) then
                    table.insert(icons, child)
                end
            end
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
                UtilityIconViewers.__pendingIcons[icon] = { icon=icon, settings=settings, viewer=viewer }
                UtilityIconViewers.__iconSkinEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            else
                pcall(function() UtilityIconViewers:SkinIcon(icon, settings) end)
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
                icon:SetPoint("CENTER", container, "CENTER", x, y)
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
            icon:SetPoint("CENTER", container, "CENTER", x, 0)
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

            local startX = -rowWidth/2 + w/2

            local y = 0
            if r > 1 then
                local rowSpacing = iconHeight + spacing
                if growDir == "up" then
                    y = (r-1) * rowSpacing
                else
                    y = -(r-1) * rowSpacing
                end
            end

            for i, icon in ipairs(row) do
                local x = startX + (i-1)*(w+spacing)
                icon:SetSize(w, h)
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", container, "CENTER", x, y)
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

function UtilityIconViewers:RescanViewer(viewer)
    if not viewer or not viewer.GetName then return end
    UtilityIconViewers:ApplyViewerLayout(viewer)
end

MyUtilityBuffTracker = MyUtilityBuffTracker or {}
MyUtilityBuffTracker.IconViewers = UtilityIconViewers
-- ---------------------------
-- HookViewer
-- ---------------------------
local function HookViewer()
    local viewer = _G["UtilityCooldownViewer"]
    if not viewer then return end

    -- Defensive: if the addon exposes a container frame under a different name,
    -- try common fallbacks (optional)
    if not viewer.viewerFrame and viewer.GetName and _G[viewer:GetName() .. "Frame"] then
        viewer.viewerFrame = _G[viewer:GetName() .. "Frame"]
    end

    viewer:SetMovable(not MyUtilityBuffTrackerDB.locked)
    viewer:EnableMouse(not MyUtilityBuffTrackerDB.locked)

    viewer:HookScript("OnShow", function(self) pcall(function() UtilityIconViewers:RescanViewer(self) end) end)
    viewer:HookScript("OnSizeChanged", function(self) pcall(function() UtilityIconViewers:ApplyViewerLayout(self) end) end)

    if not viewer._MyBuffTrackerTickerFrame then
        local ticker = CreateFrame("Frame", nil, viewer)
        ticker.elapsed = 0
        ticker:SetScript("OnUpdate", function(self, elapsed)
            if IsEditModeActive() then return end
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 0.2 then
                self.elapsed = 0
                pcall(function()
                    if viewer and viewer:IsShown() then
                        UtilityIconViewers:RescanViewer(viewer)
                    end
                end)
            end
        end)
        viewer._MyBuffTrackerTickerFrame = ticker
    end
end

-- Ensure DB and try to hook immediately if the frame exists now
EnsureDB()
HookViewer()

-- If the Utility viewer is created later by another addon, ensure we hook when it's available
local hookFrame = CreateFrame("Frame")
hookFrame:RegisterEvent("ADDON_LOADED")
hookFrame:SetScript("OnEvent", function(self, event, name)
    if _G["UtilityCooldownViewer"] then
        HookViewer()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- ---------------------------
-- Config Panel (Interface Options) with safe deferred registration
-- ---------------------------

-- Compact slider with input
local function CreateSlider(parent, labelText, min, max, step, initial, onChanged)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(210, 40)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 0, 0)
    label:SetText(labelText)
    label:SetTextColor(0.85, 0.7, 1, 1)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetSize(140, 16)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(initial)

        -- Add value text above the slider
        local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valueText:SetPoint("BOTTOM", slider, "TOP", 0, 8)
        valueText:SetText(tostring(initial))

        slider:HookScript("OnValueChanged", function(self, val)
            valueText:SetText(tostring(step >= 1 and math.floor(val + 0.5) or val))
        end)

    -- Use default thumb from OptionsSliderTemplate

    local input = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
    input:SetSize(50, 20)
    input:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    input:SetAutoFocus(false)
    input:SetText(tostring(initial))
    input:SetTextColor(1, 1, 1, 1)
    input:SetMaxLetters(6)

    local function UpdateValue(val)
        if step >= 1 then val = math.floor(val + 0.5) end
        onChanged(val)
        local viewer = _G["UtilityCooldownViewer"]
        if viewer then
            ForceReskinViewer(viewer)
            pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
        end
    end

    slider:SetScript("OnValueChanged", function(self, val)
        UpdateValue(val)
        input:SetText(tostring(val))
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

    container:SetScript("OnShow", function()
        input:SetText(tostring(slider:GetValue()))
    end)

    return container
end

-- Compact checkbox
local function CreateCheck(parent, labelText, initial, onChanged)
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
        local viewer = _G["UtilityCooldownViewer"]
        if viewer then
            ForceReskinViewer(viewer)
            pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
        end
    end)

    return container
end

-- Scrollable, full-featured options panel for Interface Options
local optionsPanel
function MyUtilityBuffTracker:CreateOptionsPanel()
    EnsureDB()
    if optionsPanel then return optionsPanel end
    optionsPanel = CreateFrame("Frame", "MyUtilityBuffTrackerOptionsPanel", UIParent)
        -- Always refresh UI when panel is shown
        optionsPanel:SetScript("OnShow", function()
            if MyUtilityBuffTracker and MyUtilityBuffTracker.UpdateSettings then
                MyUtilityBuffTracker:UpdateSettings()
            end
        end)
    optionsPanel.name = "MyUtilityBuffTracker"
    optionsPanel:SetSize(550, 1100)
    local note = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -24, -26)
    note:SetText("Drag  a slider and numbers will show or click through pages!")
    note:SetTextColor(0.2, 1, 0.2, 1)
    note:SetJustifyH("LEFT")

    local scrollFrame = CreateFrame("ScrollFrame", nil, optionsPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(530, 2000)
    scrollFrame:SetScrollChild(content)
    optionsPanel._content = content

    local function AddPerRowSliders(content, x1, y)
        if content._rowSizeWidgets then
            for _, w in ipairs(content._rowSizeWidgets) do if w then w:Hide() end end
        end
        content._rowSizeWidgets = {}
        local viewer = _G["UtilityCooldownViewer"]
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
            local current = (MyUtilityBuffTrackerDB.rowSizes and MyUtilityBuffTrackerDB.rowSizes[r]) or MyUtilityBuffTrackerDB.iconSize
            local rowSlider = CreateSlider(content, "Row "..r.." Size", 1, 200, 1, current,
                function(v)
                    MyUtilityBuffTrackerDB.rowSizes[r] = v
                    local viewer = _G["UtilityCooldownViewer"]
                    if viewer then
                        ForceReskinViewer(viewer)
                        pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                        if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                    end
                end)
            rowSlider:SetPoint("TOPLEFT", x1, y)
            y = y - 46
            table.insert(content._rowSizeWidgets, rowSlider)
        end
        return y
    end

    function optionsPanel:_rebuildConfigUI()
        for i, child in ipairs({content:GetChildren()}) do
            if not (child:GetObjectType() == "Slider" or child:GetObjectType() == "ScrollFrame") then
                child:Hide()
            end
        end
        local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -12)
        title:SetText("MyUtilityBuffTracker")
        title:SetTextColor(1, 1, 1, 1)
        local x1, x2 = 20, 290
        local y = -48
        local iconTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconTitle:SetPoint("TOPLEFT", x1, y)
        iconTitle:SetText("Icon Settings")
        iconTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24
        local iconSizeSlider = CreateSlider(content, "Icon Size", 8, 128, 1, MyUtilityBuffTrackerDB.iconSize,
            function(v)
                MyUtilityBuffTrackerDB.iconSize = v
                local viewer = _G["UtilityCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        iconSizeSlider:SetPoint("TOPLEFT", x1, y)

        -- Cooldown Text Size Slider
        y = y - 46
        local cooldownTextSizeSlider = CreateSlider(content, "Cooldown Text Size", 8, 36, 1, MyUtilityBuffTrackerDB.cooldownTextSize or 16,
            function(v)
                MyUtilityBuffTrackerDB.cooldownTextSize = v
                -- Live update: re-apply layout to update all cooldown text sizes
                local viewer = _G["UtilityCooldownViewer"]
                if viewer then
                    pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cooldownTextSizeSlider:SetPoint("TOPLEFT", x1, y)
        local aspectRatioSlider = CreateSlider(content, "Aspect Ratio", 0.1, 5.0, 0.01, MyUtilityBuffTrackerDB.aspectRatioCrop or 1.0,
            function(v)
                MyUtilityBuffTrackerDB.aspectRatioCrop = v
                local viewer = _G["UtilityCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        aspectRatioSlider:SetPoint("TOPLEFT", x2, y)
        y = y - 46
        local cornerRadius = CreateSlider(content, "Corner Radius", 0, 20, 1, MyUtilityBuffTrackerDB.iconCornerRadius or 0,
            function(v)
                MyUtilityBuffTrackerDB.iconCornerRadius = v
                local viewer = _G["UtilityCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                end
            end)
        cornerRadius:SetPoint("TOPLEFT", x1, y)
        y = y - 52
        local spaceTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        spaceTitle:SetPoint("TOPLEFT", x1, y)
        spaceTitle:SetText("Spacing & Layout")
        spaceTitle:SetTextColor(0.9, 0.9, 0.9, 1)
        y = y - 24
        local hSpace = CreateSlider(content, "Horizontal Spacing", 0, 40, 1, MyUtilityBuffTrackerDB.spacing,
            function(v)
                MyUtilityBuffTrackerDB.spacing = v
                local viewer = _G["UtilityCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        hSpace:SetPoint("TOPLEFT", x1, y)
        local vSpace = CreateSlider(content, "Vertical Spacing", 0, 40, 1, MyUtilityBuffTrackerDB.spacing,
            function(v)
                MyUtilityBuffTrackerDB.spacing = v
                local viewer = _G["UtilityCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        vSpace:SetPoint("TOPLEFT", x2, y)
        y = y - 46
        local perRow = CreateSlider(content, "Icons Per Row", 1, 50, 1, MyUtilityBuffTrackerDB.columns,
            function(v)
                MyUtilityBuffTrackerDB.columns = v; MyUtilityBuffTrackerDB.rowLimit = v
                local viewer = _G["UtilityCooldownViewer"]
                if viewer then
                    ForceReskinViewer(viewer)
                    pcall(function() UtilityIconViewers:ApplyViewerLayout(viewer) end)
                    if optionsPanel and optionsPanel._rebuildConfigUI then optionsPanel:_rebuildConfigUI() end
                end
            end)
        perRow:SetPoint("TOPLEFT", x1, y)
        y = y - 52
        y = y - 46
        y = AddPerRowSliders(content, x1, y)
        -- HIDE WHEN MOUNTED OPTION
        local hideMount = CreateCheck(content, "Hide when mounted", MyUtilityBuffTrackerDB.hideWhenMounted,
            function(v)
                MyUtilityBuffTrackerDB.hideWhenMounted = v
                UpdateCooldownManagerVisibility()
            end)
        hideMount:SetPoint("TOPLEFT", x1, y)
        y = y - 28

        local lockFrame = CreateCheck(content, "Lock Frame", MyUtilityBuffTrackerDB.locked,
            function(v)
                MyUtilityBuffTrackerDB.locked = v
                local viewer = _G["UtilityCooldownViewer"]
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
    _G.MyUtilityBuffTrackerPanel = optionsPanel
    return optionsPanel
end

local optionsInit = CreateFrame("Frame")
optionsInit:RegisterEvent("PLAYER_LOGIN")
optionsInit:SetScript("OnEvent", function()
    MyUtilityBuffTracker:CreateOptionsPanel()
end)

SLASH_MYUTILITYBUFF1 = "/ubt"
SlashCmdList["MYUTILITYBUFF"] = function()
    if Settings and Settings.OpenToCategory and MyUtilityBuffTrackerCategory then
        Settings.OpenToCategory(MyUtilityBuffTrackerCategory.ID)
    elseif type(InterfaceOptionsFrame_OpenToCategory) == "function" then
        pcall(function() InterfaceOptionsFrame_OpenToCategory("MyUtilityBuffTracker") end)
    else
        print("Utility Buff Tracker: Interface Options not ready yet. Open Interface -> AddOns after logging in, or use /reload once UI is loaded.")
    end
end
