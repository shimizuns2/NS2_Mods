-- ======= Copyright (c) 2003-2013, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\PhaseGateUserMixin.lua
--
--    Created by:   Andreas Urwalek (andi@unknownworlds.com)
--    Optimized by: Devnull
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================
PhaseGateUserMixin = CreateMixin(PhaseGateUserMixin)
PhaseGateUserMixin.type = "PhaseGateUser"

local kPhaseDelay = 2

-- Cache Frequently Used Functions and Values
local GetTime = Shared.GetTime
local ipairs = ipairs
local GetEntitiesForTeamWithinRange = GetEntitiesForTeamWithinRange
local GetIsUnitActive = GetIsUnitActive
local HasMixin = HasMixin
local GetConcedeSequenceActive = GetConcedeSequenceActive

PhaseGateUserMixin.networkVars = {
    timeOfLastPhase = "compensated private time"
}

local function SharedUpdate(self)
    PROFILE("PhaseGateUserMixin:OnUpdate")

    -- Early return if phasing not possible
    if not self:GetCanPhase() then
        return
    end

    if self:GetCanPhase() then
        for _, phaseGate in ipairs(GetEntitiesForTeamWithinRange("PhaseGate", self:GetTeamNumber(), self:GetOrigin(), 0.5)) do
            if phaseGate:GetIsDeployed() and GetIsUnitActive(phaseGate) then
                if phaseGate:Phase(self) then
                    self.timeOfLastPhase = GetTime()

                    if Client then
                        self.timeOfLastPhaseClient = GetTime()
                        local viewAngles = self:GetViewAngles()
                        -- Cache these calls
                        local yaw, pitch = viewAngles.yaw, viewAngles.pitch
                        Client.SetYaw(yaw)
                        Client.SetPitch(pitch)
                    end

                    return -- Exit early once phased
                end
            end
        end
    end
end

function PhaseGateUserMixin:__initmixin()
    PROFILE("PhaseGateUserMixin:__initmixin")

    self.timeOfLastPhase = 0
end

local kOnPhase = {
    phaseGateId = "entityid",
    phasedEntityId = "entityid"
}
Shared.RegisterNetworkMessage("OnPhase", kOnPhase)

if Server then
    function PhaseGateUserMixin:OnProcessMove(input)
        PROFILE("PhaseGateUserMixin:OnProcessMove")

        -- Early return if phasing not possible
        if not self:GetCanPhase() then return end

        -- Cache these values
        local teamNumber = self:GetTeamNumber()
        local origin = self:GetOrigin()
        local client = self:GetClient()

        for _, phaseGate in ipairs(GetEntitiesForTeamWithinRange("PhaseGate", teamNumber, origin, 0.5)) do
            if phaseGate:GetIsDeployed() and GetIsUnitActive(phaseGate) and phaseGate:Phase(self) then
                self.timeOfLastPhase = GetTime()

                -- Cache entity ID
                local id = self:GetId()
                Server.SendNetworkMessage(
                    client,
                    "OnPhase",
                    {
                        phaseGateId = phaseGate:GetId(),
                        phasedEntityId = id or Entity.invalidId
                    },
                    true
                )
                return
            end
        end
    end

    function PhaseGateUserMixin:OnUpdate(deltaTime)
        SharedUpdate(self)
    end
end

if Client then
    local function OnMessagePhase(message)
        PROFILE("PhaseGateUserMixin:OnMessagePhase")

        -- Cache entity lookups
        local phaseGate = Shared.GetEntity(message.phaseGateId)
        local phasedEnt = Shared.GetEntity(message.phasedEntityId)

        if not phaseGate or not phasedEnt then return end

        phasedEnt.timeOfLastPhaseClient = GetTime()

        if phaseGate:Phase(phasedEnt) then
            local viewAngles = phasedEnt:GetViewAngles()
            -- Cache angle values
            local yaw, pitch = viewAngles.yaw, viewAngles.pitch
            Client.SetYaw(yaw)
            Client.SetPitch(pitch)
        end
    end

    Client.HookNetworkMessage("OnPhase", OnMessagePhase)
end

function PhaseGateUserMixin:GetCanPhase()
    local canPhase = self:GetIsAlive() and GetTime() > self.timeOfLastPhase + kPhaseDelay

    if Server then
        return canPhase and not GetConcedeSequenceActive()
    end

    return canPhase
end

function PhaseGateUserMixin:OnPhaseGateEntry(destinationOrigin)
    if Server and HasMixin(self, "LOS") then
        self:MarkNearbyDirtyImmediately()
    end
end
