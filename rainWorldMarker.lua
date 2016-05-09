local NUM_WORLD_RAID_MARKERS = NUM_WORLD_RAID_MARKERS
local WORLD_RAID_MARKER_ORDER = WORLD_RAID_MARKER_ORDER

local showIn = {
	pvp = nil,
	arena = nil,
	party = true,
	raid = true,
	scenario = true,
}

local HexToRGB = function(hexColor)
	return tonumber("0x"..hexColor:sub(1,2)) / 255, tonumber("0x"..hexColor:sub(3,4)) / 255, tonumber("0x"..hexColor:sub(5,6)) / 255
end

local markerColors = {}
do
	for i = 1, NUM_WORLD_RAID_MARKERS do
		local text = _G["WORLD_MARKER"..i]
		local hexColor = string.match(text, "|cff(......)")
		local r, g, b = HexToRGB(hexColor)
		markerColors[i] = {r, g, b, 0.8}
	end
	markerColors[9] = {0.7, 0.7, 0.7, 0.8}
end

local buttonWidthCollapsed = 3
local buttonWidthExpanded = 10

local buttonsCreated
local visibilityUpdated
local positionsUpdated

local Holder = CreateFrame("Frame", nil, Minimap)
Holder:SetScript("OnEvent", function(self, event, ...) self[event](self, event, ...) end)

local OnEnter = function(self)
	self.bg:SetWidth(buttonWidthExpanded)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetText(_G["WORLD_MARKER"..WORLD_RAID_MARKER_ORDER[self.id]])
	GameTooltip:AddLine("|cff00FF00Left-Click|r to place", 1, 1, 1, true)
	GameTooltip:AddLine("|cff00FF00Right-Click|r to remove", 1, 1, 1, true)
	GameTooltip:AddLine("|cff00FF00Ctrl-Right-Click|r to remove all", 1, 1, 1, true)
	if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
		GameTooltip:AddLine("|cff00FF00Ctrl-Click|r to issue a ready check", 1, 1, 1, true)
		if not HasLFGRestrictions() then
			GameTooltip:AddLine("|cff00FF00Shift-Click|r to issue a role poll", 1, 1, 1, true)
		end
	end
	GameTooltip:Show()
end

local OnLeave = function(self)
	self.bg:SetWidth(buttonWidthCollapsed)
	GameTooltip:Hide()
end

local UpdateVisibility = function()
	if InCombatLockdown() then
		Holder:RegisterEvent("PLAYER_REGEN_ENABLED")
		visibilityUpdated = false
		return
	end

	local show = false
	local isInInstance, locType = IsInInstance()

	if isInInstance and showIn[locType] then
		show = true
		if locType == "raid" then
			show = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
		end
	elseif locType == "none" then
		show = UnitInParty("player")
	end

	if show then
		Holder:Show()
	else
		Holder:Hide()
	end

	visibilityUpdated = true
end

local UpdatePositions = function()
	if InCombatLockdown() then
		Holder:RegisterEvent("PLAYER_REGEN_ENABLED")
		positionsUpdated = false
		return
	end

	local minimapHeight = Minimap:GetHeight()
	local buttonHeight = minimapHeight / NUM_WORLD_RAID_MARKERS

	Holder:SetPoint("RIGHT", Minimap, "LEFT")
	Holder:SetSize(buttonWidthExpanded, minimapHeight)

	for index = 1, NUM_WORLD_RAID_MARKERS do
		local button = Holder[index]
		button:SetPoint("TOPRIGHT", Holder, "TOPRIGHT", 0, (index - 1) * -buttonHeight)
		button:SetSize(buttonWidthExpanded, buttonHeight)

		local bg = button.bg
		bg:SetPoint("RIGHT", button)
		bg:SetSize(buttonWidthCollapsed, buttonHeight - 2)

		button.bg = bg
		Holder[index] = button
	end

	positionsUpdated = true
end

local CreateButtons = function()
	if InCombatLockdown() then
		Holder:RegisterEvent("PLAYER_REGEN_ENABLED")
		buttonsCreated = false
		return
	end

	for i = 1, NUM_WORLD_RAID_MARKERS do
		local index = WORLD_RAID_MARKER_ORDER[i]
		local button = CreateFrame("Button", nil, Holder, "SecureActionButtonTemplate")

		button:SetAttribute("type1", "macro")
		button:SetAttribute("macrotext1", "/wm " .. index)
		button:SetAttribute("type2", "macro")
		button:SetAttribute("macrotext2", "/cwm " .. index)
		button:SetAttribute("ctrl-type2", "macro")
		button:SetAttribute("ctrl-macrotext2", "/cwm all")
		button:SetAttribute("ctrl-type1", "readycheck")
		button:SetAttribute("_readycheck", DoReadyCheck)
		button:SetAttribute("shift-type1", "rolepoll")
		button:SetAttribute("_rolepoll", InitiateRolePoll)

		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

		button:SetScript("OnEnter", OnEnter)
		button:SetScript("OnLeave", OnLeave)

		button.bg = button:CreateTexture(nil, "BACKGROUND")
		button.bg:SetTexture(unpack(markerColors[index]))

		button.id = i

		Holder[i] = button
	end

	buttonsCreated = true
end

function Holder:PLAYER_LOGIN()
	CreateButtons()
	UpdatePositions()
	UpdateVisibility()
	Minimap:HookScript("OnSizeChanged", UpdatePositions)
end

function Holder:PLAYER_REGEN_ENABLED(event)
	self:UnregisterEvent(event)
	if not buttonsCreated then
		CreateButtons()
	end
	if not positionsUpdated then
		UpdatePositions()
	end
	if not visibilityUpdated then
		UpdateVisibility()
	end
end

Holder.PLAYER_ENTERING_WORLD = UpdateVisibility
Holder.GROUP_ROSTER_UPDATE = UpdateVisibility
Holder.PARTY_LEADER_CHANGED = UpdateVisibility

Holder:RegisterEvent("PLAYER_LOGIN")
Holder:RegisterEvent("PLAYER_ENTERING_WORLD")
Holder:RegisterEvent("GROUP_ROSTER_UPDATE")
Holder:RegisterEvent("PARTY_LEADER_CHANGED")
