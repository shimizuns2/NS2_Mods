local Shine = Shine
local Plugin = Shine.Plugin(...)

Plugin.HasConfig = true
Plugin.ConfigName = "devnull_ImprovedComHud.json"
Plugin.DefaultState = true
Plugin.PrintName = "Devnull - Improved Commander HUD"
Plugin.PrintVersion = "1.0"

local mapIcons

function Plugin:Initialise()
	self.Enabled = true

	HPrint(Plugin.PrintName .. ", version " .. Plugin.PrintVersion)

	self:CreateHooks()

	return true
end

function Plugin:CreateHooks()
	local plugin = self
	local AFKKICK = Shine.Plugins.afkkick

	plugin.OldGUIUnitStatusUpdateUnitStatusBlip = GUIUnitStatus.UpdateUnitStatusBlip

	local oldUpdate = GUIUnitStatus.UpdateUnitStatusBlip
	function GUIUnitStatus:UpdateUnitStatusBlip(blipIndex, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType)
		oldUpdate(self, blipIndex, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType)

		local blipData = self.activeStatusInfo[blipIndex]
		local updateBlip = self.activeBlipList[blipIndex]
		local blipNameText = blipData.Name
--		if blipNameText == "Door" then
			local textColor = kNameTagFontColors[blipData.TeamType]
			updateBlip.NameText:SetIsVisible(true)
			updateBlip.NameText:SetText(blipNameText .. tostring(blipIndex))
			updateBlip.NameText:SetColor(textColor)
			updateBlip.statusBg:SetIsVisible(true)
		end
--	end
end

function Plugin:Cleanup()
	self.BaseClass.Cleanup(self)

	self.Enabled = false
end
