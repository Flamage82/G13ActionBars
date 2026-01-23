local btn = CreateFrame("CheckButton", "myButton", UIParent, "ActionBarButtonTemplate");
-- btn:SetAttribute("type", "action");
-- btn:SetAttribute("action", 1);
-- btn:SetSize(52, 52)
btn:SetPoint("CENTER", 0, -4)

if DLAPI then DLAPI.DebugLog("Test", "Test") end

local hotkey = btn.HotKey;
local frameWidth, frameHeight = btn:GetSize();
hotkey:SetSize(frameWidth-8, 10);
hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -5);
hotkey:SetText("T");
hotkey:Show();

btn:Show()