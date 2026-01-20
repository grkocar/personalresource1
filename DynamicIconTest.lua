-- Dynamic and Free Positioning Icon Test
-- This file demonstrates both dynamic centering and free positioning for real cooldown manager buff icons.

-- Replace ICONS and iconFrames with real buff icons from BuffIconCooldownViewer
local function GetBuffIcons()
    local viewer = _G["BuffIconCooldownViewer"]
    if not viewer then return {} end
    local container = viewer.viewerFrame or viewer
    local icons = {}
    for _, child in ipairs({container:GetChildren()}) do
        if child and (child.Icon or child.icon) then
            table.insert(icons, child)
        end
    end
    return icons
end

-- Example: assign positionMode/x/y to some icons for testing
local function SetupTestPositions()
    local icons = GetBuffIcons()
    for i, icon in ipairs(icons) do
        if i == 1 or i == 2 then
            icon.positionMode = "centered"
        elseif i == 3 then
            icon.positionMode = "free"; icon.x = 400; icon.y = -200
        elseif i == 4 then
            icon.positionMode = "free"; icon.x = 600; icon.y = -300
        else
            icon.positionMode = "centered"
        end
    end
end

-- Addon-wide lock state
local iconsLocked = true

-- Helper to set all icons to centered unless unlocked/free
local function UpdateIconModes()
    local icons = GetBuffIcons()
    for _, icon in ipairs(icons) do
        if iconsLocked or icon.positionMode ~= "free" then
            icon.positionMode = "centered"
            icon.x = nil
            icon.y = nil
        end
    end
end

-- Modified PositionBuffIcons to always center unless unlocked/free
local function PositionBuffIcons()
    local icons = GetBuffIcons()
    local centered = {}
    local free = {}
    for i, icon in ipairs(icons) do
        if icon.positionMode == "free" then
            table.insert(free, icon)
        else
            table.insert(centered, icon)
        end
    end
    local iconSize = 40
    local spacing = 10
    local frame = _G["BuffIconCooldownViewer"]
    if not frame then return end
    local totalWidth = #centered * iconSize + (#centered - 1) * spacing
    local startX = (frame:GetWidth() - totalWidth) / 2
    local yCenter = frame:GetHeight() / 2
    for i, icon in ipairs(centered) do
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
        local x = startX + (i-1)*(iconSize+spacing)
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -yCenter)
    end
    for _, icon in ipairs(free) do
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", icon.x or 0, icon.y or 0)
    end
end

-- Persistent position storage
CkraigCooldownManagerIconPositions = CkraigCooldownManagerIconPositions or {}

-- Edit Mode state
local editModeEnabled = false

-- Helper to get unique icon ID (use spellID, auraInstanceID, or fallback to index)
local function GetIconID(icon, idx)
    return icon.spellID or icon.auraInstanceID or icon:GetID() or idx
end

-- Save all icon positions
local function SaveIconPositions()
    local icons = GetBuffIcons()
    for idx, icon in ipairs(icons) do
        local id = GetIconID(icon, idx)
        if icon.positionMode == "free" then
            CkraigCooldownManagerIconPositions[id] = { x = icon.x, y = icon.y }
        else
            CkraigCooldownManagerIconPositions[id] = nil
        end
    end
end

-- Restore all icon positions
local function RestoreIconPositions()
    local icons = GetBuffIcons()
    for idx, icon in ipairs(icons) do
        local id = GetIconID(icon, idx)
        local pos = CkraigCooldownManagerIconPositions[id]
        if pos then
            icon.positionMode = "free"
            icon.x = pos.x
            icon.y = pos.y
        else
            icon.positionMode = "centered"
            icon.x = nil
            icon.y = nil
        end
    end
end

-- Detect Blizzard Edit Mode and only apply custom icon positions when not active
local function IsBlizzardEditModeActive()
    local editModeManager = _G["EditModeManagerFrame"]
    return editModeManager and editModeManager:IsShown()
end

local function SafePositionBuffIcons()
    if not IsBlizzardEditModeActive() then
        PositionBuffIcons()
    end
end

-- Enable/disable Edit Mode (mouse drag)
local function SetEditMode(enabled)
    if IsBlizzardEditModeActive() then
        print("Blizzard Edit Mode is active. Use Blizzard's Edit Mode to move/resize the container. Exit Blizzard Edit Mode before using per-icon edit mode.")
        return
    end
    editModeEnabled = enabled
    local icons = GetBuffIcons()
    for _, icon in ipairs(icons) do
        icon:EnableMouse(enabled)
        icon:SetMovable(enabled)
        if enabled then
            icon:RegisterForDrag("LeftButton")
            icon:SetScript("OnDragStart", function(self)
                self:StartMoving()
            end)
            icon:SetScript("OnDragStop", function(self)
                self:StopMovingOrSizing()
                local frame = _G["BuffIconCooldownViewer"]
                local left, top = self:GetLeft(), self:GetTop()
                local parentLeft, parentTop = frame:GetLeft(), frame:GetTop()
                self.x = left - parentLeft
                self.y = top - parentTop - self:GetHeight()
                self.positionMode = "free"
                SaveIconPositions()
                print("Buff Icon dragged to (" .. math.floor(self.x) .. ", " .. math.floor(self.y) .. ") and set to free mode.")
                SafePositionBuffIcons()
            end)
        else
            icon:SetScript("OnDragStart", nil)
            icon:SetScript("OnDragStop", nil)
        end
    end
end

-- Setup test positions and position icons on load
SetupTestPositions()
PositionBuffIcons()

-- Modified slash command to toggle Edit Mode
SLASH_DYNAMICON1 = "/dicon"

SlashCmdList["DYNAMICON"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do table.insert(args, word) end
    if args[1] == "editmode" then
        SetEditMode(true)
        print("Edit Mode enabled. Drag icons to move them. Use /dicon save to persist positions, /dicon exit to leave Edit Mode.")
        return
    elseif args[1] == "exit" then
        SetEditMode(false)
        print("Edit Mode disabled. Icons are now locked.")
        SafePositionBuffIcons()
        return
    elseif args[1] == "save" then
        SaveIconPositions()
        print("Icon positions saved.")
        return
    elseif args[1] == "restore" then
        RestoreIconPositions()
        SafePositionBuffIcons()
        print("Icon positions restored.")
        return
    end
    local iconId = tonumber(args[1])
    local icons = GetBuffIcons()
    if not iconId or not icons[iconId] then
        print("Usage: /dicon editmode | exit | save | restore | <iconId> [centered|free] [x] [y]")
        return
    end
    local mode = args[2]
    if mode == "centered" then
        icons[iconId].positionMode = "centered"
        icons[iconId].x = nil
        icons[iconId].y = nil
        SaveIconPositions()
        print("Buff Icon " .. iconId .. " set to centered mode.")
    elseif mode == "free" then
        icons[iconId].positionMode = "free"
        icons[iconId].x = tonumber(args[3]) or 0
        icons[iconId].y = tonumber(args[4]) or 0
        SaveIconPositions()
        print("Buff Icon " .. iconId .. " set to free mode at (" .. icons[iconId].x .. ", " .. icons[iconId].y .. ").")
    else
        print("Usage: /dicon editmode | exit | save | restore | <iconId> [centered|free] [x] [y]")
        return
    end
    SafePositionBuffIcons()
end

-- On load, restore positions and center icons if needed
RestoreIconPositions()
SafePositionBuffIcons()

-- Automatically re-apply saved positions after UI reload or leaving combat, but not during Blizzard Edit Mode
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event)
    C_Timer.After(0.5, function()
        RestoreIconPositions()
        SafePositionBuffIcons()
    end)
end)

-- Workaround: re-apply icon positions after Edit Mode likely closes
local function SetupEditModeWatcher()
    local frame = _G["BuffIconCooldownViewer"]
    if not frame then return end
    if frame._editModeWatcher then return end
    frame._editModeWatcher = true
    frame:HookScript("OnShow", function()
        C_Timer.After(2, function()
            RestoreIconPositions()
            SafePositionBuffIcons()
        end)
    end)
end

-- Call watcher setup on load and after events
SetupEditModeWatcher()
