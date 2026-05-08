-- Morph into new class or buy upgrade.
function Alien:ProcessBuyAction(techIds)
    ASSERT(type(techIds) == "table")

    -- Validate input
    if table.icount(techIds) == 0 then
        return true
    end

    local gameRules = GetGamerules()
    if not (gameRules:GetGameStarted() or gameRules:GetWarmUpActive()) then
        return false
    end

    local success = false

    -- Separate life form and upgrades
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

    -- add this first because it will allow switching existing upgrades
    if lifeFormTechId then
        upgradeManager:AddUpgrade(lifeFormTechId)
    end

    for _, newUpgradeId in ipairs(upgradeIds) do
        if newUpgradeId ~= kTechId.None then
            upgradeManager:AddUpgrade(newUpgradeId, true)
        end
    end

    -- check if there has been any change before starting to evolve
    if not upgradeManager:GetHasChanged() then
        self:TriggerInvalidSound()
        return false
    end

    -- Check evolution restrictions
    local position = self:GetOrigin()
    local eggExtents = LookupTechData(kTechId.Embryo, kTechDataMaxExtents)
    local trace = Shared.TraceCapsule(position + Vector(0, eggExtents.y + 0.2, 0), position + Vector(0, -4.5, 0),
        math.max(eggExtents.x, eggExtents.z), eggExtents.y, CollisionRep.Move, PhysicsMask.AllButPCs, EntityFilterAll())

    -- no_evolve geo blocks all lifeforms
    local evolve_blocked = trace.surface == "no_evolve"
    -- no_evolve_{lifeform} blocks evolving to that specific lifeform
    if lifeFormTechId and not evolve_blocked then
        local gestate_name = LookupTechData(lifeFormTechId, kTechDataGestateName)
        evolve_blocked = trace.surface == ("no_evolve_" .. tostring(gestate_name)) -- eat nil values if returned
    end

    if not evolve_blocked then

        -- Check for room
        local newLifeFormTechId = upgradeManager:GetLifeFormTechId()
        local newAlienExtents = LookupTechData(newLifeFormTechId, kTechDataMaxExtents)
        local physicsMask = PhysicsMask.Evolve

        -- Add a bit to the extents when looking for a clear space to spawn.
        local spawnBufferExtents = Vector(0.1, 0.1, 0.1)

        local evolveAllowed = self:GetIsOnGround() and
                                  GetHasRoomForCapsule(eggExtents + spawnBufferExtents, position +
                Vector(0, eggExtents.y + Embryo.kEvolveSpawnOffset, 0), CollisionRep.Default, physicsMask, self)

        local roomAfter
        local spawnPoint

        -- If not on the ground for the buy action, attempt to automatically
        -- put the player on the ground in an area with enough room for the new Alien.
        if not evolveAllowed then

            for _ = 1, 100 do

                spawnPoint = GetRandomSpawnForCapsule(eggExtents.y, math.max(eggExtents.x, eggExtents.z),
                    self:GetModelOrigin(), 0.5, 5, EntityFilterOne(self))

                if spawnPoint then
                    self:SetOrigin(spawnPoint)
                    position = spawnPoint
                    break
                end

            end

        end

        if not GetHasRoomForCapsule(newAlienExtents + spawnBufferExtents,
            self:GetOrigin() + Vector(0, newAlienExtents.y + Embryo.kEvolveSpawnOffset, 0), CollisionRep.Default,
            PhysicsMask.AllButPCsAndRagdollsAndBabblers, nil, EntityFilterOne(self)) then

            for _ = 1, 100 do
                roomAfter = GetRandomSpawnForCapsule(newAlienExtents.y, math.max(newAlienExtents.x, newAlienExtents.z),
                    self:GetModelOrigin(), 0.5, 5, EntityFilterOne(self))

                if roomAfter then
                    evolveAllowed = true
                    break
                end
            end
        else
            roomAfter = position
            evolveAllowed = true
        end

        if evolveAllowed and roomAfter ~= nil then
            local oldLifeFormTechId = self:GetTechId()
            local newPlayer = self:Replace(Embryo.kMapName)
            position.y = position.y + Embryo.kEvolveSpawnOffset
            newPlayer:SetOrigin(position)

            -- Clear angles, in case we were wall-walking or doing some crazy alien thing
            local angles = Angles(self:GetViewAngles())
            angles.roll = 0.0
            angles.pitch = 0.0
            newPlayer:SetOriginalAngles(angles)
            newPlayer:SetValidSpawnPoint(roomAfter)

            -- Eliminate velocity so that we don't slide or jump as an egg
            newPlayer:SetVelocity(Vector(0, 0, 0))
            newPlayer:DropToFloor()

            newPlayer:SetResources(upgradeManager:GetAvailableResources())
            newPlayer:SetGestationData(upgradeManager:GetUpgrades(), self:GetTechId(), self:GetHealthScalar(),
                self:GetArmorScalar())

            if oldLifeFormTechId and lifeFormTechId and oldLifeFormTechId ~= lifeFormTechId then
                -- print("Bought (" .. tostring(lifeFormTechId) .. "):" .. EnumToString(kTechId, lifeFormTechId) ", OLD (" .. tostring(oldLifeFormTechId) .. "):" .. EnumToString(kTechId, oldLifeFormTechId))
                -- print("Bought (" .. tostring(lifeFormTechId) .. "), OLD (" .. tostring(oldLifeFormTechId) .. ")")
                -- print("Sending to StatsUI_RegisterPurchase")
                StatsUI_RegisterPurchase(lifeFormTechId)
                -- print("sent...")
                newPlayer.oneHive = false
                newPlayer.twoHives = false
                newPlayer.threeHives = false
            end
            success = true
        end
    end

    if not success then
        self:TriggerInvalidSound()
    end

    return success
end
