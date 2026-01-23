-- MyActionBars: Rearranges action buttons into Logitech G13 layout
-- Uses ActionButton1-12 (main bar) + MultiBarBottomLeftButton1-10 (bar 2) = 22 buttons

local ADDON_NAME = "MyActionBars"

local BUTTON_SIZE = 36
local BUTTON_GAP = 4
local BUTTON_SPACING = BUTTON_SIZE + BUTTON_GAP -- 40

-- G13 Layout: 22 keys in staggered rows
-- Row 1: G1-G7   (7 keys)
-- Row 2: G8-G14  (7 keys, staggered right)
-- Row 3: G15-G19 (5 keys, staggered more)
-- Row 4: G20-G22 (3 keys, staggered most)

-- Position table: {x, y} offsets from container's BOTTOMLEFT
-- x increases right, y increases up
local G13_LAYOUT = {
    -- Row 1 (top): G1-G7
    { 0, 120 },   -- G1  -> ActionButton1
    { 40, 120 },  -- G2  -> ActionButton2
    { 80, 120 },  -- G3  -> ActionButton3
    { 120, 120 }, -- G4  -> ActionButton4
    { 160, 120 }, -- G5  -> ActionButton5
    { 200, 120 }, -- G6  -> ActionButton6
    { 240, 120 }, -- G7  -> ActionButton7

    -- Row 2: G8-G14 (staggered ~20px right)
    { 20, 80 },   -- G8  -> ActionButton8
    { 60, 80 },   -- G9  -> ActionButton9
    { 100, 80 },  -- G10 -> ActionButton10
    { 140, 80 },  -- G11 -> ActionButton11
    { 180, 80 },  -- G12 -> ActionButton12
    { 220, 80 },  -- G13 -> MultiBarBottomLeftButton1
    { 260, 80 },  -- G14 -> MultiBarBottomLeftButton2

    -- Row 3: G15-G19 (staggered ~40px right)
    { 40, 40 },   -- G15 -> MultiBarBottomLeftButton3
    { 80, 40 },   -- G16 -> MultiBarBottomLeftButton4
    { 120, 40 },  -- G17 -> MultiBarBottomLeftButton5
    { 160, 40 },  -- G18 -> MultiBarBottomLeftButton6
    { 200, 40 },  -- G19 -> MultiBarBottomLeftButton7

    -- Row 4 (bottom): G20-G22 (staggered ~80px right)
    { 80, 0 },    -- G20 -> MultiBarBottomLeftButton8
    { 120, 0 },   -- G21 -> MultiBarBottomLeftButton9
    { 160, 0 },   -- G22 -> MultiBarBottomLeftButton10
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
    "ActionButton8",
    "ActionButton9",
    "ActionButton10",
    "ActionButton11",
    "ActionButton12",
    "MultiBarBottomLeftButton1",
    "MultiBarBottomLeftButton2",
    "MultiBarBottomLeftButton3",
    "MultiBarBottomLeftButton4",
    "MultiBarBottomLeftButton5",
    "MultiBarBottomLeftButton6",
    "MultiBarBottomLeftButton7",
    "MultiBarBottomLeftButton8",
    "MultiBarBottomLeftButton9",
    "MultiBarBottomLeftButton10",
}

-- Create container frame for G13 layout
local G13Frame = CreateFrame("Frame", "MyActionBarsG13Frame", UIParent)
G13Frame:SetSize(300, 160)
G13Frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 50)

-- State tracking
local setupComplete = false
local setupPending = false
local originalSetPoints = {}

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
        -- Hide background and artwork textures
        local regions = {MainMenuBar:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetAlpha(0)
            end
        end
        -- Also hide the art frame if it exists
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

    setupComplete = true
    setupPending = false
    print(string.format("%s: Positioned %d/%d buttons in G13 layout", ADDON_NAME, successCount, #BUTTON_MAP))

    return true
end

-- Create event frame to trigger setup at right time
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Delay to ensure all UI elements are loaded
        C_Timer.After(1.0, function()
            if not InCombatLockdown() then
                SetupG13Layout()
            else
                setupPending = true
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" and setupPending then
        -- Combat ended and we have pending setup
        SetupG13Layout()
    end
end)
