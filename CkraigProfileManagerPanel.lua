-- CkraigProfileManagerPanel.lua
-- Creates a Profile Manager options panel for the Blizzard settings UI

local panel = CreateFrame("Frame")
panel.name = "Profile Manager"
panel:SetSize(600, 400)

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 20, -20)
title:SetText("Profile Manager")

local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
info:SetText("Create, copy, delete, and switch profiles.")

-- Example input box for profile name
local nameBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
nameBox:SetSize(200, 30)
nameBox:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -20)
nameBox:SetAutoFocus(false)
nameBox:SetText("")

local nameLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
nameLabel:SetPoint("RIGHT", nameBox, "LEFT", -10, 0)
nameLabel:SetText("Profile Name:")

-- Create button
local createBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
createBtn:SetSize(100, 24)
createBtn:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
createBtn:SetText("Create")
createBtn:SetScript("OnClick", function()
    local name = nameBox:GetText()
    if name and name ~= "" then
        CkraigCooldownManager_ProfileManager:CreateProfile(name)
        print("Created profile:", name)
    end
end)

-- List profiles
local listLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
listLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -30)
listLabel:SetText("Profiles:")

local listBox = CreateFrame("Frame", nil, panel)
listBox:SetSize(200, 120)
listBox:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -10)

local function RefreshProfileList()
    for i, child in ipairs({listBox:GetChildren()}) do
        child:Hide()
    end
    local profiles = CkraigCooldownManager_ProfileManager:ListProfiles()
    for i, name in ipairs(profiles) do
        local btn = CreateFrame("Button", nil, listBox, "UIPanelButtonTemplate")
        btn:SetSize(180, 22)
        btn:SetPoint("TOPLEFT", 0, -((i-1)*24))
        btn:SetText(name)
        btn:SetScript("OnClick", function()
            CkraigCooldownManager_ProfileManager:SwitchProfile(name)
            print("Switched to profile:", name)
        end)
        btn:Show()
        -- Delete button
        local delBtn = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
        delBtn:SetSize(40, 22)
        delBtn:SetPoint("RIGHT", btn, "RIGHT", 45, 0)
        delBtn:SetText("Delete")
        delBtn:SetScript("OnClick", function()
            CkraigCooldownManager_ProfileManager:DeleteProfile(name)
            print("Deleted profile:", name)
            RefreshProfileList()
        end)
        delBtn:Show()
    end
end

panel.RefreshProfileList = RefreshProfileList
createBtn:SetScript("OnClick", function()
    local name = nameBox:GetText()
    if name and name ~= "" then
        CkraigCooldownManager_ProfileManager:CreateProfile(name)
        print("Created profile:", name)
        RefreshProfileList()
    end
end)

panel:SetScript("OnShow", RefreshProfileList)

_G.CkraigProfileManagerPanel = panel
