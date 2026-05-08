local function dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

local techUpgradesTable = {kTechId.Jetpack, kTechId.Welder, kTechId.ClusterGrenade, kTechId.PulseGrenade,
                           kTechId.GasGrenade, kTechId.Mine, kTechId.Vampirism, kTechId.Carapace, kTechId.Regeneration,

                           kTechId.Aura, kTechId.Focus, kTechId.Camouflage, kTechId.Celerity, kTechId.Adrenaline,
                           kTechId.Crush, kTechId.Parasite, kTechId.DualMinigunExosuit, kTechId.DualRailgunExosuit}

local techUpgradesBitmask = CreateBitMask(techUpgradesTable)

local oldPlayerInfoEntityUpdateScore = PlayerInfoEntity.UpdateScore

function GetTechIdsFromBitMask(techTable)
    local techIds = {}

    if techTable and techTable > 0 then
        for _, techId in ipairs(techUpgradesTable) do
            local bitmask = techUpgradesBitmask[techId]
            if bit.band(techTable, bitmask) > 0 then
                table.insert(techIds, techId)
            end
        end
    end

    -- Sort the table by bitmask value so it keeps the order established in the original table
    table.sort(techIds, function(a, b)
        return techUpgradesBitmask[a] < techUpgradesBitmask[b]
    end)

    return techIds
end

function PlayerInfoEntity:UpdateScore()
    techUpgradesTable = {kTechId.Jetpack, kTechId.Welder, kTechId.ClusterGrenade, kTechId.PulseGrenade,
                         kTechId.GasGrenade, kTechId.Mine, kTechId.Vampirism, kTechId.Carapace, kTechId.Regeneration,

                         kTechId.Aura, kTechId.Focus, kTechId.Camouflage, kTechId.Celerity, kTechId.Adrenaline,
                         kTechId.Crush, kTechId.Parasite, kTechId.DualMinigunExosuit, kTechId.DualRailgunExosuit}
    techUpgradesBitmask = CreateBitMask(techUpgradesTable)

    local ret = oldPlayerInfoEntityUpdateScore(self)
    if Server then
        local scorePlayer = Shared.GetEntity(self.playerId)
        if scorePlayer and self.currentTech then
            if scorePlayer:isa("Exo") then
                if scorePlayer:GetHasMinigun() and techUpgradesBitmask[kTechId.DualMinigunExosuit] then
                    self.currentTech = bit.bor(self.currentTech, techUpgradesBitmask[kTechId.DualMinigunExosuit])
                elseif scorePlayer:GetHasRailgun() and techUpgradesBitmask[kTechId.DualRailgunExosuit] then
                    self.currentTech = bit.bor(self.currentTech, techUpgradesBitmask[kTechId.DualRailgunExosuit])
                end
            end
        end
    end
    return ret
end
