-- ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\Alien_Upgrade.lua
--
--    Created by:   Andreas Urwalek (andi@unknownworlds.com)
--    Optimized by: Devnull
--
--    Utility functions for readability.
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

-- ============================
-- Tech Tree Utility Functions
-- ============================

function GetTechTreeSafe(teamNumber)
    local techTree = GetTechTree(teamNumber)
    if not techTree then
        Log("Warning: TechTree is nil for teamNumber %d", teamNumber)
    end
    return techTree
end

local function GetTechNodeSafe(teamNumber, techId)
    local techTree = GetTechTreeSafe(teamNumber)
    if techTree then
        local techNode = techTree:GetTechNode(techId)
        return techNode
    end
    return nil
end

-- ============================
-- Upgrade Check Functions
-- ============================

function GetHasPrereqs(teamNumber, techId)
    local techNode = GetTechNodeSafe(teamNumber, techId)
    if techNode then
        local prereq1 = techNode:GetPrereq1()
        local prereq2 = techNode:GetPrereq2()
        return prereq1 and prereq2
    end
    return false
end

function GetIsTechAvailable(teamNumber, techId)
    if not techId or not teamNumber then
        print("GetIsTechAvailable(): techId or teamNumber is nil")
        return false
    end

    local techNode = GetTechNodeSafe(teamNumber, techId)
    if techNode then
        return techNode:GetAvailable()
    end

    return false
end

function GetIsTechResearched(teamNumber, techId)
    if not techId or not teamNumber then
        print("GetIsTechResearched(): techId or teamNumber is nil")
        return false
    end

    local techNode = GetTechNodeSafe(teamNumber, techId)
    if techNode then
        return techNode:GetResearched()
    end

    return false
end

local function GetTeamHasTech(teamNumber, techId)
    if not techId or not teamNumber then
        print("GetTeamHasTech(): techId or teamNumber is nil")
        return false
    end
    local techTree = GetTechTreeSafe(teamNumber)
    if techTree then
        return techTree:GetHasTech(techId, true)
    end

    return false
end

function GetHasHealingBedUpgrade(teamNumber)
    return GetTeamHasTech(teamNumber, kTechId.HealingBed)
end

function GetHasMucousMembraneUpgrade(teamNumber)
    return GetTeamHasTech(teamNumber, kTechId.MucousMembrane)
end

function GetHasBacterialReceptorsUpgrade(teamNumber)
    return GetTeamHasTech(teamNumber, kTechId.BacterialReceptors)
end

local function HasUpgrade(callingEntity, techId)

    if not callingEntity then
        return false
    end

    local techtree = GetTechTree(callingEntity:GetTeamNumber())

    if techtree then
        return callingEntity:GetHasUpgrade(techId) -- and techtree:GetIsTechAvailable(techId)
    else
        return false
    end

end

-- ============================
-- Entity Upgrade Functions
-- ============================

function GetHasRegenerationUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Regeneration)
end

function GetHasCarapaceUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Carapace)
end

function GetHasCrushUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Crush)
end

function GetHasCelerityUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Celerity)
end

function GetHasAdrenalineUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Adrenaline)
end

function GetHasSilenceUpgrade(callingEntity)
    return false
end

function GetHasCamouflageUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Camouflage)
end

function GetHasFocusUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Focus)
end

function GetHasVampirismUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Vampirism)
end

function GetHasAuraUpgrade(callingEntity)
    return HasUpgrade(callingEntity, kTechId.Aura)
end

local hiveTypeCache = {}

function GetHiveTypeForUpgrade(upgradeId)
    if not hiveTypeCache[upgradeId] then
        hiveTypeCache[upgradeId] = LookupTechData(upgradeId, kTechDataCategory, kTechId.None)
    end
    return hiveTypeCache[upgradeId]
end

-- checks if upgrade category is already used
function GetIsUpgradeAllowed(callingEntity, techId, upgradeList)
    if not callingEntity or not upgradeList then
        return false
    end

    local hiveType = GetHiveTypeForUpgrade(techId)
    for i = 1, #upgradeList do
        if GetHiveTypeForUpgrade(upgradeList[i]) == hiveType then
            return false
        end
    end

    return true
end
