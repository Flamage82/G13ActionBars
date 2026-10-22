-- MyActionBars: Rearranges action buttons into Logitech G13 layout
-- Uses ActionButton1-12 + MultiBarBottomLeftButton1-12 = 24 buttons (action bars 1 & 2)

local ADDON_NAME = "MyActionBars"

local BUTTON_SIZE = 36
local BUTTON_GAP = 9
local BUTTON_SPACING = BUTTON_SIZE + BUTTON_GAP -- 45

-- G13 Layout: 22 keys + 2 mouse buttons
-- Row 1: G1-G7   (7 keys)
-- Row 2: G8-G14  (7 keys, aligned with row 1)
-- Row 3: G15-G19 (5 keys, aligned)
-- Row 4: G20-G22 (3 keys, aligned)
-- Mouse buttons on the right

-- Position table: {x, y} offsets from container's BOTTOMLEFT
-- x increases right, y increases up (using 45px spacing)
local G13_LAYOUT = {
    -- Row 1 (top): G1-G7
    { 0, 135 },   -- G1  -> ActionButton1
    { 45, 135 },  -- G2  -> ActionButton2
    { 90, 135 },  -- G3  -> ActionButton3
    { 135, 135 }, -- G4  -> ActionButton4
    { 180, 135 }, -- G5  -> ActionButton5
    { 225, 135 }, -- G6  -> ActionButton6
    { 270, 135 }, -- G7  -> ActionButton7

    -- Row 2: G8-G14 (aligned with row 1)
    { 0, 90 },    -- G8  -> MultiBarBottomLeftButton1 (bar 2)
    { 45, 90 },   -- G9  -> ActionButton8 (bar 1, central)
    { 90, 90 },   -- G10 -> ActionButton9 (bar 1, central)
    { 135, 90 },  -- G11 -> ActionButton10 (bar 1, central)
    { 180, 90 },  -- G12 -> ActionButton11 (bar 1, central)
    { 225, 90 },  -- G13 -> ActionButton12 (bar 1, central)
    { 270, 90 },  -- G14 -> MultiBarBottomLeftButton2 (bar 2)

    -- Row 3: G15-G19 (shifted right by 1 button)
    { 45, 45 },   -- G15 -> MultiBarBottomLeftButton3
    { 90, 45 },   -- G16 -> MultiBarBottomLeftButton4
    { 135, 45 },  -- G17 -> MultiBarBottomLeftButton5
    { 180, 45 },  -- G18 -> MultiBarBottomLeftButton6
    { 225, 45 },  -- G19 -> MultiBarBottomLeftButton7

    -- Row 4 (bottom): G20-G22 (shifted right by 1 button)
    { 90, 0 },    -- G20 -> MultiBarBottomLeftButton8
    { 135, 0 },   -- G21 -> MultiBarBottomLeftButton9
    { 180, 0 },   -- G22 -> MultiBarBottomLeftButton10

    -- Extra buttons (bottom right, for mouse buttons)
    { 270, 45 },  -- Mouse1 -> MultiBarBottomLeftButton11
    { 270, 0 },   -- Mouse2 -> MultiBarBottomLeftButton12
}

-- Map G13 positions to actual button frames
local BUTTON_MAP = {
    "ActionButton1",
    "ActionButton2",
    "ActionButton3",
    "ActionButton4",
    "ActionButton5",
    "ActionButton6",
    "ActionButton7",
    "MultiBarBottomLeftButton1",  -- G8 (bar 2)
    "ActionButton8",              -- G9 (bar 1, central)
    "ActionButton9",              -- G10 (bar 1, central)
    "ActionButton10",             -- G11 (bar 1, central)
    "ActionButton11",             -- G12 (bar 1, central)
    "ActionButton12",             -- G13 (bar 1, central)
    "MultiBarBottomLeftButton2",  -- G14 (bar 2)
    "MultiBarBottomLeftButton3",
    "MultiBarBottomLeftButton4",
    "MultiBarBottomLeftButton5",
    "MultiBarBottomLeftButton6",
    "MultiBarBottomLeftButton7",
    "MultiBarBottomLeftButton8",
    "MultiBarBottomLeftButton9",
    "MultiBarBottomLeftButton10",
    "MultiBarBottomLeftButton11",
    "MultiBarBottomLeftButton12",
}

-- Default saved variables
local defaults = {
    position = { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 50 },
    locked = true,
    editMode = {}, -- EditModeExpanded storage for position/scale per profile
    combatFade = false, -- Fade top two rows in combat to train cooldown tracking
}

-- Combat fade state
local FADE_ALPHA = 0.2
local FADE_ROWS_COUNT = 14 -- First 14 buttons = rows 1 & 2 (G1-G14)
local combatFadeHooked = false
local isHoveringFadeButton = false
local inCombat = false
local fadeLeaveTimer = nil

-- Hover reveal state (shows the layout while a UI fader such as Cinematic has faded the main bar)
local hoverRevealHooked = false
local hoverRevealTimer = nil

-- Create container frame for G13 layout
local G13Frame = CreateFrame("Frame", "MyActionBarsG13Frame", UIParent)
G13Frame:SetSize(320, 180)
G13Frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 50)
G13Frame:SetMovable(true)
G13Frame:SetClampedToScreen(true)

-- Create drag handle above the action bar
local DragHandle = CreateFrame("Frame", "MyActionBarsDragHandle", G13Frame, "BackdropTemplate")
DragHandle:SetSize(300, 16)
DragHandle:SetPoint("BOTTOM", G13Frame, "TOP", 0, 2)
DragHandle:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
DragHandle:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
DragHandle:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
DragHandle:EnableMouse(true)
DragHandle:RegisterForDrag("LeftButton")
DragHandle:Hide() -- Hidden by default (locked)

-- Add label to drag handle
local DragLabel = DragHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
DragLabel:SetPoint("CENTER")
DragLabel:SetText("Drag to move | /mab lock")
DragLabel:SetTextColor(0.7, 0.7, 0.7)

-- Drag handle scripts
DragHandle:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
        G13Frame:StartMoving()
    end
end)

DragHandle:SetScript("OnDragStop", function(self)
    G13Frame:StopMovingOrSizing()
    -- Save position
    local point, _, relativePoint, x, y = G13Frame:GetPoint()
    if MyActionBarsDB then
        MyActionBarsDB.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end)

-- State tracking
local setupComplete = false
local setupPending = false
local originalSetPoints = {}

-- Function to toggle lock state
local function ToggleLock()
    if not MyActionBarsDB then return end

    MyActionBarsDB.locked = not MyActionBarsDB.locked

    if MyActionBarsDB.locked then
        DragHandle:Hide()
        print(ADDON_NAME .. ": Locked. Use /mab unlock to move.")
    else
        DragHandle:Show()
        print(ADDON_NAME .. ": Unlocked. Drag the handle to move.")
    end
end

-- Function to restore saved position
local function RestorePosition()
    if not MyActionBarsDB or not MyActionBarsDB.position then return end

    local pos = MyActionBarsDB.position
    G13Frame:ClearAllPoints()
    G13Frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)

    -- Update lock state
    if MyActionBarsDB.locked then
        DragHandle:Hide()
    else
        DragHandle:Show()
    end
end

-- Combat fade: set alpha on top two rows
local function SetFadeRowsAlpha(alpha)
    for i = 1, FADE_ROWS_COUNT do
        local button = _G[BUTTON_MAP[i]]
        if button then
            button:SetAlpha(alpha)
        end
    end
end

-- Called when entering/leaving combat or hover state changes
local function UpdateCombatFade()
    if not MyActionBarsDB or not MyActionBarsDB.combatFade then return end

    if inCombat and not isHoveringFadeButton then
        SetFadeRowsAlpha(FADE_ALPHA)
    else
        SetFadeRowsAlpha(1.0)
    end
end

-- Hook OnEnter/OnLeave on top-row buttons for hover detection
local function HookCombatFadeButtons()
    if combatFadeHooked then return end

    for i = 1, FADE_ROWS_COUNT do
        local button = _G[BUTTON_MAP[i]]
        if button then
            button:HookScript("OnEnter", function()
                if not MyActionBarsDB or not MyActionBarsDB.combatFade then return end
                isHoveringFadeButton = true
                if fadeLeaveTimer then
                    fadeLeaveTimer:Cancel()
                    fadeLeaveTimer = nil
                end
                UpdateCombatFade()
            end)
            button:HookScript("OnLeave", function()
                if not MyActionBarsDB or not MyActionBarsDB.combatFade then return end
                -- Small delay to avoid flicker when moving between adjacent buttons
                if fadeLeaveTimer then fadeLeaveTimer:Cancel() end
                fadeLeaveTimer = C_Timer.NewTimer(0.1, function()
                    isHoveringFadeButton = false
                    fadeLeaveTimer = nil
                    UpdateCombatFade()
                end)
            end)
        end
    end

    combatFadeHooked = true
end

-- Hook OnEnter/OnLeave on all buttons so hovering the layout reveals it.
-- Cinematic only counts the mouse as over the main bar inside that bar's own
-- rect, so hovering the G13 layout elsewhere wouldn't bring it back.
local function HookHoverReveal()
    if hoverRevealHooked or not G13Frame.SetIgnoreParentAlpha then return end

    for _, buttonName in ipairs(BUTTON_MAP) do
        local button = _G[buttonName]
        if button then
            button:HookScript("OnEnter", function()
                if hoverRevealTimer then
                    hoverRevealTimer:Cancel()
                    hoverRevealTimer = nil
                end
                G13Frame:SetIgnoreParentAlpha(true)
            end)
            button:HookScript("OnLeave", function()
                -- Small delay to avoid flicker when moving between adjacent buttons
                if hoverRevealTimer then hoverRevealTimer:Cancel() end
                hoverRevealTimer = C_Timer.NewTimer(0.1, function()
                    hoverRevealTimer = nil
                    G13Frame:SetIgnoreParentAlpha(false)
                end)
            end)
        end
    end

    hoverRevealHooked = true
end

-- Function to position a button at a G13 slot
local function PositionButton(buttonName, x, y)
    local button = _G[buttonName]
    if not button then
        print(ADDON_NAME .. ": Warning - Button not found: " .. buttonName)
        return false
    end

    -- Store original SetPoint if not already stored
    if not originalSetPoints[buttonName] then
        originalSetPoints[buttonName] = button.SetPoint
    end

    -- Reparent to our container
    button:SetParent(G13Frame)

    -- Clear existing anchors and set new position
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", G13Frame, "BOTTOMLEFT", x, y)

    -- Override SetPoint with combat-aware version that ignores repositioning attempts
    local origSetPoint = originalSetPoints[buttonName]
    button.SetPoint = function(self, ...)
        -- Silently ignore - we control positioning
        -- This prevents Blizzard UI from resetting our layout
    end

    -- Ensure button is shown
    button:Show()

    return true
end

-- Function to hide default bar artwork (textures only, not the functional frames)
local function HideDefaultBars()
    -- Hide MainMenuBar artwork
    if MainMenuBar then
        local regions = {MainMenuBar:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
        if MainMenuBar.ArtFrame then
            MainMenuBar.ArtFrame:SetAlpha(0)
        end
        if MainMenuBarArtFrame then
            MainMenuBarArtFrame:SetAlpha(0)
        end
        if MainMenuBarArtFrameBackground then
            MainMenuBarArtFrameBackground:SetAlpha(0)
        end
    end

    -- Hide MultiBarBottomLeft artwork
    if MultiBarBottomLeft then
        local regions = {MultiBarBottomLeft:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
    end
end

-- Main setup function
local function SetupG13Layout()
    -- Don't modify in combat
    if InCombatLockdown() then
        setupPending = true
        return false
    end

    -- Don't run if already set up
    if setupComplete then
        return true
    end

    -- Parent the container to the game's main action bar so it inherits that
    -- bar's scale (Edit Mode), visibility and alpha. UI faders such as Cinematic
    -- fade the main bar, so the G13 layout fades with the rest of the UI.
    local mainBar = _G["MainActionBar"] or _G["MainMenuBar"]
    if mainBar then
        G13Frame:SetParent(mainBar)
    end

    -- Position all 22 buttons
    local successCount = 0
    for i, buttonName in ipairs(BUTTON_MAP) do
        local pos = G13_LAYOUT[i]
        if pos and PositionButton(buttonName, pos[1], pos[2]) then
            successCount = successCount + 1
        end
    end

    -- Hide default bar artwork
    HideDefaultBars()

    HookHoverReveal()

    setupComplete = true
    setupPending = false
    print(string.format("%s: Positioned %d/%d buttons in G13 layout", ADDON_NAME, successCount, #BUTTON_MAP))

    return true
end

-- Edit Mode integration using EditModeExpanded-1.0 library
local editModeRegistered = false
local function RegisterWithEditMode()
    if editModeRegistered then return true end

    -- Check if LibStub is available
    if not LibStub then
        print(ADDON_NAME .. ": LibStub not found")
        return false
    end

    -- Check if EditModeExpanded-1.0 is available
    local lib = LibStub("EditModeExpanded-1.0", true)
    if not lib then
        print(ADDON_NAME .. ": EditModeExpanded-1.0 library not found (addon may not be installed)")
        return false
    end

    -- Ensure db is initialized with type validation
    if not MyActionBarsDB then
        print(ADDON_NAME .. ": Warning - Cannot register Edit Mode (DB not initialized)")
        return false
    end
    if not MyActionBarsDB.editMode or type(MyActionBarsDB.editMode) ~= "table" then
        MyActionBarsDB.editMode = {}
    end

    -- Register G13Frame with Edit Mode using protected call for error handling
    local success, err = pcall(function()
        -- Parameters: frame, name, db, anchorTo, anchorPoint, clamped
        lib:RegisterFrame(G13Frame, "MyActionBars", MyActionBarsDB.editMode, UIParent, "BOTTOMLEFT", true)
        -- Add scale slider (values are percentages: 50 = 0.5x, 100 = 1.0x, 200 = 2.0x)
        lib:RegisterResizable(G13Frame, 50, 200, 5)
    end)

    if not success then
        print(ADDON_NAME .. ": Edit Mode registration failed - " .. tostring(err))
        return false
    end

    editModeRegistered = true
    print(ADDON_NAME .. ": Edit Mode integration enabled")
    return true
end

-- Slash commands
SLASH_MYACTIONBARS1 = "/myactionbars"
SLASH_MYACTIONBARS2 = "/mab"
SlashCmdList["MYACTIONBARS"] = function(msg)
    local cmd = string.lower(msg or "")

    if cmd == "unlock" then
        if MyActionBarsDB then
            MyActionBarsDB.locked = true -- Set to locked so toggle will unlock
            ToggleLock()
        end
    elseif cmd == "lock" then
        if MyActionBarsDB then
            MyActionBarsDB.locked = false -- Set to unlocked so toggle will lock
            ToggleLock()
        end
    elseif cmd == "toggle" then
        ToggleLock()
    elseif cmd == "fade" then
        if MyActionBarsDB then
            MyActionBarsDB.combatFade = not MyActionBarsDB.combatFade
            if MyActionBarsDB.combatFade then
                HookCombatFadeButtons()
                print(ADDON_NAME .. ": Combat fade ON - Top rows fade to " .. (FADE_ALPHA * 100) .. "% in combat. Hover to reveal.")
            else
                -- Restore full opacity immediately
                SetFadeRowsAlpha(1.0)
                print(ADDON_NAME .. ": Combat fade OFF.")
            end
        end
    elseif cmd == "reset" then
        if MyActionBarsDB then
            MyActionBarsDB.position = defaults.position
            RestorePosition()
            print(ADDON_NAME .. ": Position reset to default.")
        end
    else
        print(ADDON_NAME .. " commands:")
        print("  /mab unlock - Show drag handle to move")
        print("  /mab lock - Hide drag handle")
        print("  /mab toggle - Toggle lock state")
        print("  /mab fade - Toggle combat fade (top rows)")
        print("  /mab reset - Reset position to default")
    end
end

-- Create event frame to trigger setup at right time
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize saved variables
        if not MyActionBarsDB then
            MyActionBarsDB = {}
        end
        -- Apply defaults for missing values
        for k, v in pairs(defaults) do
            if MyActionBarsDB[k] == nil then
                MyActionBarsDB[k] = v
            end
        end
    elseif event == "PLAYER_LOGIN" then
        -- Delay to ensure all UI elements are loaded
        C_Timer.After(1.0, function()
            -- Restore saved position
            RestorePosition()

            if not InCombatLockdown() then
                SetupG13Layout()
            else
                setupPending = true
            end

            -- Hook fade buttons if combat fade was previously enabled
            if MyActionBarsDB.combatFade then
                HookCombatFadeButtons()
            end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Register with Edit Mode after EditModeExpanded has initialized
        -- Use a small delay to ensure EditModeExpanded's PLAYER_ENTERING_WORLD handler runs first
        C_Timer.After(0.5, function()
            RegisterWithEditMode()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat
        inCombat = true
        UpdateCombatFade()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat
        inCombat = false
        isHoveringFadeButton = false
        UpdateCombatFade()
        if setupPending then
            SetupG13Layout()
        end
    end
end)
