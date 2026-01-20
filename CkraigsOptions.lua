-- CkraigsOptions.lua
-- Registers a single parent category with all 4 module panels as subcategories in the Blizzard settings UI


local function RegisterCkraigOptions()
    if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory or not Settings.RegisterCanvasLayoutSubcategory then
        return -- Not Dragonflight+ or Settings API not available
    end

    -- Ensure all panels are created
    if MyEssentialBuffTracker and MyEssentialBuffTracker.CreateOptionsPanel then
        MyEssentialBuffTracker:CreateOptionsPanel()
    end
    if MyUtilityBuffTracker and MyUtilityBuffTracker.CreateOptionsPanel then
        MyUtilityBuffTracker:CreateOptionsPanel()
    end
    if _G.CkraigBarOptionsPanel then
        -- Already created by CCM_CooldownBars.lua
    end
    if DYNAMICICONS and DYNAMICICONS.CreateOptionsPanel then
        DYNAMICICONS:CreateOptionsPanel()
    end

    -- Parent category with logo
    local parentPanel = CreateFrame("Frame")
    parentPanel:SetSize(600, 200)
    local logo = parentPanel:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\CkraigCooldownManager\\CkraigfriendsBack.tga")
    logo:SetSize(512, 256)
    logo:SetPoint("TOP", 0, -20)

    local parent = Settings.RegisterCanvasLayoutCategory(parentPanel, "Ckraig Cooldown Manager")
    Settings.RegisterAddOnCategory(parent)

    -- Subcategories
    if _G.MyEssentialBuffTrackerPanel then
        local sub = Settings.RegisterCanvasLayoutSubcategory(parent, _G.MyEssentialBuffTrackerPanel, "Essential Buffs")
        Settings.RegisterAddOnCategory(sub)
    end
    if _G.MyUtilityBuffTrackerPanel then
        local sub = Settings.RegisterCanvasLayoutSubcategory(parent, _G.MyUtilityBuffTrackerPanel, "Utility Buffs")
        Settings.RegisterAddOnCategory(sub)
    end
    if _G.CkraigBarOptionsPanel then
        local sub = Settings.RegisterCanvasLayoutSubcategory(parent, _G.CkraigBarOptionsPanel, "Cooldown Bars")
        Settings.RegisterAddOnCategory(sub)
    end
    if _G.DYNAMICICONSPanel then
        local sub = Settings.RegisterCanvasLayoutSubcategory(parent, _G.DYNAMICICONSPanel, "Dynamic Icons")
        Settings.RegisterAddOnCategory(sub)
    end

    -- Register Charge Text Colors panel as a subcategory
    if _G.ChargeTextColorOptionsPanel then
        local sub = Settings.RegisterCanvasLayoutSubcategory(parent, _G.ChargeTextColorOptionsPanel, "Charge Text Colors")
        Settings.RegisterAddOnCategory(sub)
    end

    -- Profile Manager options panel
    if _G.CkraigProfileManagerPanel then
        local sub = Settings.RegisterCanvasLayoutSubcategory(parent, _G.CkraigProfileManagerPanel, "Profile Manager")
        Settings.RegisterAddOnCategory(sub)
    end
end

-- Register on login
local optionsInit = CreateFrame("Frame")
optionsInit:RegisterEvent("PLAYER_LOGIN")
optionsInit:SetScript("OnEvent", RegisterCkraigOptions)
