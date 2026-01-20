


-- IMPORTANT: To persist color settings, add this line to your .toc file:
-- SavedVariables: CooldownChargeDB

_G.ChargeTextColorOptionsPanel = CreateFrame("Frame", "ChargeTextColorOptionsPanel", UIParent)
_G.ChargeTextColorOptionsPanel.name = "Charge Text Colors"

_G.CooldownChargeDB = _G.CooldownChargeDB or {}
local function GetCooldownChargeDB()
    if type(_G.CooldownChargeDB) ~= "table" then _G.CooldownChargeDB = {} end
    return _G.CooldownChargeDB
end

local function ClearIconSkinCache(viewer)
    if not viewer or not viewer.GetChildren then return end
    for _, child in ipairs({ viewer:GetChildren() }) do
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

local function ReskinAllViewers()
    -- Buffs
    if _G.BuffIconViewers and _G.BuffIconCooldownViewer then
        ClearIconSkinCache(_G.BuffIconCooldownViewer)
        if _G.BuffIconViewers.ForceReskinViewer then
            _G.BuffIconViewers:ForceReskinViewer(_G.BuffIconCooldownViewer)
        end
        if _G.BuffIconViewers.ApplyViewerLayout then
            pcall(function() _G.BuffIconViewers:ApplyViewerLayout(_G.BuffIconCooldownViewer) end)
        end
    end
    -- Essentials
    if _G.MyEssentialIconViewers and _G.EssentialCooldownViewer then
        ClearIconSkinCache(_G.EssentialCooldownViewer)
        if _G.MyEssentialIconViewers.ForceReskinViewer then
            _G.MyEssentialIconViewers:ForceReskinViewer(_G.EssentialCooldownViewer)
        end
        if _G.MyEssentialIconViewers.ApplyViewerLayout then
            pcall(function() _G.MyEssentialIconViewers:ApplyViewerLayout(_G.EssentialCooldownViewer) end)
        end
    end
    -- Utility
    if _G.UtilityIconViewers and _G.UtilityCooldownViewer then
        ClearIconSkinCache(_G.UtilityCooldownViewer)
        if _G.UtilityIconViewers.ForceReskinViewer then
            _G.UtilityIconViewers:ForceReskinViewer(_G.UtilityCooldownViewer)
        end
        if _G.UtilityIconViewers.ApplyViewerLayout then
            pcall(function() _G.UtilityIconViewers:ApplyViewerLayout(_G.UtilityCooldownViewer) end)
        end
    end
end

local function ShowColorPicker(groupName)
    local CooldownChargeDB = GetCooldownChargeDB()
    local current = CooldownChargeDB["TextColor_" .. groupName] or {1,1,1,1}
    local r, g, b, a = unpack(current)
    local function openOptionsPanel()
        if _G.Settings and _G.Settings.GetCategory and _G.Settings.OpenToCategory and _G.ChargeTextColorOptionsPanel then
            local cat = _G.Settings.GetCategory(_G.ChargeTextColorOptionsPanel)
            if cat and cat.ID then
                _G.Settings.OpenToCategory(cat.ID)
            end
        elseif _G.InterfaceOptionsFrame_OpenToCategory and _G.ChargeTextColorOptionsPanel then
            _G.InterfaceOptionsFrame_OpenToCategory(_G.ChargeTextColorOptionsPanel)
        end
    end
    local function setColor(newR, newG, newB, newA)
        local db = GetCooldownChargeDB()
        db["TextColor_" .. groupName] = {newR, newG, newB, newA}
        _G.CooldownChargeDB = db -- ensure global is updated
    end
    local function onCancel()
        openOptionsPanel()
    end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or 1
                setColor(newR, newG, newB, newA)
                ReskinAllViewers()
            end,
            opacityFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or 1
                setColor(newR, newG, newB, newA)
                ReskinAllViewers()
            end,
            hasOpacity = true,
            opacity = a,
            r = r,
            g = g,
            b = b,
        })
    end
end

local function CreateChargeTextColorOptionsUI()
    print("[ChargeTextColorOptions] Creating UI elements...")
    -- Add a background for visibility
    local bg = _G.ChargeTextColorOptionsPanel:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)
    bg:SetAllPoints(_G.ChargeTextColorOptionsPanel)

    local title = _G.ChargeTextColorOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Charge Text Color Options")

    -- Add section labels for clarity
    local cooldownLabel = _G.ChargeTextColorOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    cooldownLabel:SetPoint("TOPLEFT", 32, -48)
    cooldownLabel:SetText("Cooldown Text Colors")

    local chargeLabel = _G.ChargeTextColorOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    chargeLabel:SetPoint("TOPLEFT", 240, -48)
    chargeLabel:SetText("Charge/Stack Text Colors")

    local groups = {"Buff", "Essential", "Utility"}
    for i, group in ipairs(groups) do
        -- Cooldown text color picker
        local cdBtn = CreateFrame("Button", nil, _G.ChargeTextColorOptionsPanel, "UIPanelButtonTemplate")
        cdBtn:SetSize(180, 30)
        cdBtn:SetPoint("TOPLEFT", 32, -80 - (i-1)*40)
        cdBtn:SetText("Pick " .. group .. " Cooldown Color")
        cdBtn:SetScript("OnClick", function()
            ShowColorPicker("CooldownText_" .. group)
        end)

        -- Charge/stack text color picker
        local stackBtn = CreateFrame("Button", nil, _G.ChargeTextColorOptionsPanel, "UIPanelButtonTemplate")
        stackBtn:SetSize(180, 30)
        stackBtn:SetPoint("TOPLEFT", 240, -80 - (i-1)*40)
        stackBtn:SetText("Pick " .. group .. " Charge/Stack Color")
        stackBtn:SetScript("OnClick", function()
            ShowColorPicker("ChargeText_" .. group)
        end)
    end
end

CreateChargeTextColorOptionsUI()

