-- ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\Alien_Server.lua
--
--    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
--                  Max McGuire (max@unknownworlds.com)
--    Optimized by: Devnull
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================
Script.Load("lua/AlienUpgradeManager.lua")

-- Cache frequently used functions at the top
local GetTime = Shared.GetTime
local max = math.max
local Clamp = Clamp
local GetHasRoomForCapsule = GetHasRoomForCapsule
local GetRandomSpawnForCapsule = GetRandomSpawnForCapsule
local EntityFilterOne = EntityFilterOne
local EntityFilterAll = EntityFilterAll
local LookupTechData = LookupTechData

function Alien:TriggerEnzyme(duration)
    if self:GetIsOnFire() or self:GetElectrified() then
        return
    end

    self.timeWhenEnzymeExpires = max(self.timeWhenEnzymeExpires, duration + GetTime())
end

function Alien:Reset()
    Player.Reset(self)

    if self:GetTeamNumber() == kNeutralTeamType then
        return
    end

    self.oneHive = false
    self.twoHives = false
    self.threeHives = false
end

function Alien:OnProcessMove(input)
    PROFILE("Alien:OnProcessMove")

    if not self then
        return
    end

    -- Cache frequently accessed values
    self.hasAdrenalineUpgrade = GetHasAdrenalineUpgrade(self)
    local currentTime = GetTime()

    -- Update energy
    self:GetEnergy()

    -- Clear hatch effect after 3 seconds
    if self.hatched and self.creationTime + 3 < currentTime then
        self.hatched = false
    end

    Player.OnProcessMove(self, input)

    -- Early return if destroyed
    if self:GetIsDestroyed() then
        return
    end

    -- Update ability availability
    UpdateAbilityAvailability(self, self:GetTierOneTechId(), self:GetTierTwoTechId(), self:GetTierThreeTechId())

    -- Update status effects
    self.enzymed = self.timeWhenEnzymeExpires > currentTime
    self.electrified = self.timeElectrifyEnds > currentTime

    self:UpdateAutoHeal()
end

-- deprecated (silence got removed)
function Alien:UpdateSilenceLevel()
    if GetHasSilenceUpgrade(self) then
        self.silenceLevel = self:GetSpurLevel()
    else
        self.silenceLevel = 0
    end
end

function Alien:UpdateAutoHeal()
    PROFILE("Alien:UpdateAutoHeal")

    if not self then
        return
    end

    if not self:GetIsHealable() then
        return
    end

    local currentTime = GetTime()
    if self.timeLastAlienAutoHeal and self.timeLastAlienAutoHeal + kAlienRegenerationTime > currentTime then
        return
    end

    -- Cache frequently used values
    local shellLevel = self:GetShellLevel()
    local maxHealth = self:GetBaseHealth()
    local hasRegenUpgrade = shellLevel > 0 and GetHasRegenerationUpgrade(self)

    -- Calculate heal rate
    local healRate
    if hasRegenUpgrade then
        healRate = Clamp(kAlienRegenerationPercentage * maxHealth, kAlienMinRegeneration, kAlienMaxRegeneration) *
                       (shellLevel / 3)
    else
        healRate = Clamp(kAlienInnateRegenerationPercentage * maxHealth, kAlienMinInnateRegeneration,
            kAlienMaxInnateRegeneration)
    end

    -- Apply combat modifier if needed
    if self:GetIsUnderFire() then
        local modifier = kAlienRegenerationCombatModifier
        if self.GetCombatInnateRegenOverride then
            modifier = self:GetCombatInnateRegenOverride() or modifier
        end
        healRate = healRate * modifier
    end

    self:AddHealth(healRate, false, false, not hasRegenUpgrade, self, true)
    self.timeLastAlienAutoHeal = currentTime
end

function Alien:GetDamagedAlertId()
    return kTechId.AlienAlertLifeformUnderAttack
end

-- Helper function to validate spawn location
function Alien:ValidateSpawnLocation(position, eggExtents, spawnBufferExtents)
    if not self then
        return
    end

    local trace = Shared.TraceCapsule(position + Vector(0, eggExtents.y + 0.2, 0), position + Vector(0, -4.5, 0),
        math.max(eggExtents.x, eggExtents.z), eggExtents.y, CollisionRep.Move, PhysicsMask.AllButPCs, EntityFilterAll())

    if not trace then
        return false
    end

    -- Check for evolution restrictions
    local evolve_blocked = trace.surface == "no_evolve"
    if not evolve_blocked and self.lifeFormTechId then
        local gestate_name = LookupTechData(self.lifeFormTechId, kTechDataGestateName)
        evolve_blocked = trace.surface == ("no_evolve_" .. tostring(gestate_name))
    end

    return not evolve_blocked
end

-- Helper function to complete evolution process
function Alien:CompleteEvolution(upgradeManager, position, roomAfter)
    if not self then
        return
    end

    local oldLifeFormTechId = self:GetTechId()
    local newPlayer = self:Replace(Embryo.kMapName)

    position.y = position.y + Embryo.kEvolveSpawnOffset
    newPlayer:SetOrigin(position)

    -- Reset angles
    local angles = Angles(self:GetViewAngles())
    angles.roll = 0.0
    angles.pitch = 0.0
    newPlayer:SetOriginalAngles(angles)
    newPlayer:SetValidSpawnPoint(roomAfter)

    -- Reset velocity and position
    newPlayer:SetVelocity(Vector(0, 0, 0))
    newPlayer:DropToFloor()

    -- Set new player properties
    newPlayer:SetResources(upgradeManager:GetAvailableResources())
    newPlayer:SetGestationData(upgradeManager:GetUpgrades(), self:GetTechId(), self:GetHealthScalar(),
        self:GetArmorScalar())

    -- Reset hive status if changing lifeform
    if oldLifeFormTechId and self.lifeFormTechId and oldLifeFormTechId ~= self.lifeFormTechId then
        newPlayer.oneHive = false
        newPlayer.twoHives = false
        newPlayer.threeHives = false
    end

    return true
end

-- Morph into new class or buy upgrade.
function Alien:ProcessBuyAction(techIds)
    ASSERT(type(techIds) == "table")

    if not self then
        return
    end

    -- Early return if nothing to buy
    if #techIds == 0 then
        return true
    end

    local gameRules = GetGamerules()
    if not (gameRules:GetGameStarted() or gameRules:GetWarmUpActive()) then
        self:TriggerInvalidSound()
        return false
    end

    -- Separate upgrades and lifeform tech
    local upgradeIds = {}
    local lifeFormTechId

    for _, techId in ipairs(techIds) do
        if LookupTechData(techId, kTechDataGestateName) then
            lifeFormTechId = techId
        else
            table.insertunique(upgradeIds, techId)
        end
    end

    -- Process upgrades
    local upgradeManager = AlienUpgradeManager()
    upgradeManager:Populate(self)

    if lifeFormTechId then
        upgradeManager:AddUpgrade(lifeFormTechId)
    end

    for _, newUpgradeId in ipairs(upgradeIds) do
        if newUpgradeId ~= kTechId.None then
            upgradeManager:AddUpgrade(newUpgradeId, true)
        end
    end

    -- Check for changes
    if not upgradeManager:GetHasChanged() then
        self:TriggerInvalidSound()
        return false
    end

    -- Check evolution restrictions
    local position = self:GetOrigin()
    local eggExtents = LookupTechData(kTechId.Embryo, kTechDataMaxExtents)
    local spawnBufferExtents = Vector(0.1, 0.1, 0.1)

    -- Validate spawn location
    local evolveAllowed = self:ValidateSpawnLocation(position, eggExtents, spawnBufferExtents)
    local roomAfter = evolveAllowed and position

    if evolveAllowed and roomAfter then
        return self:CompleteEvolution(upgradeManager, position, roomAfter)
    end

    self:TriggerInvalidSound()
    return false
end

function Alien:GetTierOneTechId()
    return kTechId.None
end

function Alien:GetTierTwoTechId()
    return kTechId.None
end

function Alien:GetTierThreeTechId()
    return kTechId.None
end

function Alien:OnKill(attacker, doer, point, direction)
    Player.OnKill(self, attacker, doer, point, direction)

    self.oneHive = false
    self.twoHives = false
    self.threeHives = false

    if self.isHallucination then
        self:TriggerEffects("death_hallucination")
    end
end

function Alien:CopyPlayerDataForReadyRoomFrom(player)
    local respawnMapName = ReadyRoomTeam.GetRespawnMapName(nil, player)
    local gestationMapName = respawnMapName == ReadyRoomEmbryo.kMapName and player.gestationClass or nil

    local charge = (respawnMapName == Onos.kMapName or gestationMapName == Onos.kMapName) and
                       (player.oneHive or GetIsTechUnlocked(player, kTechId.Charge))

    local sstep = (respawnMapName == Fade.kMapName or gestationMapName == Fade.kMapName) and
                      (player.oneHive or GetIsTechUnlocked(player, kTechId.ShadowStep))

    local leap = (respawnMapName == Skulk.kMapName or gestationMapName == Skulk.kMapName) and
                     (player.twoHives or GetIsTechUnlocked(player, kTechId.Leap))

    self.oneHive = charge or sstep
    self.twoHives = leap
    self.gestationClass = gestationMapName
end

function Alien:CopyPlayerDataFrom(player)
    Player.CopyPlayerDataFrom(self, player)

    local selfInRR, playerInRR = self:GetTeamNumber() == kNeutralTeamType, player:GetTeamNumber() == kNeutralTeamType

    if selfInRR and not playerInRR then
        -- copy for ready room, give the tech if they deserve it
        Alien.CopyPlayerDataForReadyRoomFrom(self, player)
    elseif not selfInRR and playerInRR then
        -- don't copy Alien data from player while entering the game
    elseif player:isa("AlienSpectator") then
        -- don't copy Alien data from an AlienSpectator if not going to the RR
    else
        -- otherwise copy Alien data across
        self.oneHive = player.oneHive
        self.twoHives = player.twoHives
        self.threeHives = player.threeHives
    end
end
