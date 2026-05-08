-- complete file is commented out at the Filehooks due for LessNetworkData


if Server then

    local kUpdateGraphInterval = kResourceTowerResourceInterval --collect pres amount data every 6 seconds,

    local oldNS2GamerulesOnCreate = NS2Gamerules.OnCreate
    function NS2Gamerules:OnCreate()
        oldNS2GamerulesOnCreate(self)
        self.lastUpdatePresGraphMarine = -100 -- start negative to always collect at gamesecond 0
        self.lastUpdatePresGraphAlien = -100

    end

    local oldNS2GamerulesOnUpdate = NS2Gamerules.OnUpdate
    function NS2Gamerules:OnUpdate(timePassed)
        oldNS2GamerulesOnUpdate(self, timePassed)

        if Server and  self:GetMapLoaded() and self:GetGameState() == kGameState.Started then

            if self.lastUpdatePresGraphMarine + kUpdateGraphInterval <= self.timeSinceGameStateChanged then

                local teamIndex = 1
                local teamInfo = GetEntitiesForTeam("TeamInfo", teamIndex)
                local currentRTs = teamInfo[1]:GetNumResourceTowers()

                local team = GetEntitiesForTeam("Player", teamIndex)

                local presUnused = 0
                local presEquipped = 0
                local playerCount = 0

                local emptyExos = GetEntitiesForTeam("Exosuit", teamIndex)
                presEquipped  = presEquipped + #emptyExos * kDualExosuitCost -- TODO separate check for railguns and miniguns?
                -- Log("emptyExos %s", emptyExos)
                local droppedJps = GetEntitiesForTeam("Jetpack", teamIndex)
                presEquipped  = presEquipped + #droppedJps * kJetpackCost
                -- Log("droppedJps %s", droppedJps)
                local jper = GetEntitiesForTeam("JetpackMarine", teamIndex)
                presEquipped  = presEquipped + #jper * kJetpackCost
                -- Log("jper %s", jper)

                local mines = GetEntitiesForTeam("Mine", teamIndex)
                presEquipped = presEquipped + #mines * kMineCost
                -- Log("mines %s", mines)
                local laymines = GetEntitiesForTeam("LayMines", teamIndex)
                presEquipped = presEquipped + #laymines * kMineCost
                --  Log("laymines %s", laymines)
                local welders = GetEntitiesForTeam("Welder", teamIndex)
                presEquipped  = presEquipped + #welders * kWelderCost
                -- Log("welders %s", welders)

                local shotguns = GetEntitiesForTeam("Shotgun", teamIndex)
                presEquipped  = presEquipped + #shotguns * kShotgunCost
                --Log("sgs %s", shotguns)
                local flamers = GetEntitiesForTeam("Flamethrower", teamIndex)
                presEquipped  = presEquipped + #flamers * kFlamethrowerCost
                --Log("fts %s", flamers)
                local mgs = GetEntitiesForTeam("HeavyMachineGun", teamIndex)
                presEquipped  = presEquipped + #mgs * kHeavyMachineGunCost
                --Log("mgs %s", mgs)
                local gls = GetEntitiesForTeam("GrenadeLauncher", teamIndex)
                presEquipped  = presEquipped + #gls * kGrenadeLauncherCost
                --Log("gls %s", gls)

                local gasgrenades = GetEntitiesForTeam("GasGrenadeThrower", teamIndex)
                presEquipped  = presEquipped + #gasgrenades * kGasGrenadeCost
                -- Log("gasgrenades %s", gasgrenades)
                local pulsegrenades = GetEntitiesForTeam("PulseGrenadeThrower", teamIndex)
                presEquipped  = presEquipped + #pulsegrenades * kPulseGrenadeCost
                -- Log("pulsegrenades %s", pulsegrenades)
                local clustergrenades = GetEntitiesForTeam("ClusterGrenadeThrower", teamIndex)
                presEquipped  = presEquipped + #clustergrenades * kClusterGrenadeCost
                -- Log("clustergrenades %s", clustergrenades)

                for count, player in pairs(team) do
                    presUnused = presUnused + player:GetResources()

                    if player:isa("Exo") then

                        if player:GetHasRailgun() then
                            presEquipped = presEquipped + kDualRailgunExosuitCost
                            --Log("+1 railgunexo")
                        end
                        if player:GetHasMinigun() then
                            presEquipped = presEquipped + kDualExosuitCost
                        -- Log("+1 minigunexo")
                        end
                        if player.prevPlayerMapName == "jetpackmarine" then
                            presEquipped = presEquipped + kJetpackCost
                        end
                    end

                    if not player:isa("Commander") then

                        -- its always 0 for living marines, nil for commander
                        if player.grenadesLeft ~= nil and player.grenadesLeft > 0 then
                            presEquipped = presEquipped + player.grenadesLeft * kClusterGrenadeCost
                        end
                        if player.minesLeft ~= nil and player.minesLeft > 0 then
                            presEquipped = presEquipped + player.minesLeft * kMineCost
                        end

                        -- used for counting how many players receive pres
                        if player:GetResources() < 100 then
                            playerCount = playerCount + 1
                        end

                    elseif player.previousMapName == "jetpackmarine" then
                        presEquipped = presEquipped + kJetpackCost
                    end

                end

                --Log("unused: %s, equipped: %s", presUnused, presEquipped)
                STATSUI_PresGraphMarines(presUnused, presEquipped, currentRTs, playerCount)

                self.lastUpdatePresGraphMarine = self.timeSinceGameStateChanged

                -- make sure to offset it by 0.1 once to be behind the kResourceTowerResourceInterval
                if self.lastUpdatePresGraphMarine < 0.05 then
                    self.lastUpdatePresGraphMarine = 0.1 - kUpdateGraphInterval
                end

            end


            if self.lastUpdatePresGraphAlien + kUpdateGraphInterval <= self.timeSinceGameStateChanged then

                local teamIndex = 2

                local teamInfo = GetEntitiesForTeam("TeamInfo", teamIndex)
                if teamInfo and teamInfo[1] then
                    local currentRTs = teamInfo[1]:GetNumResourceTowers()
                else
                    local currentRTs = 0
                end

                local team = GetEntitiesForTeam("Player", teamIndex)
                local presUnused = 0
                local presEquipped = 0
                local playerCount = 0


                -- only gets normal eggs without players. Eggs with player inside are embryos
                local eggs = GetEntitiesForTeam("Egg", teamIndex)
                for i, egg in pairs(eggs) do
                    --egg:GetGestateTechId() returns the lifeform which gets researched
                    local eggTechId = egg:GetTechId()
                    if eggTechId ~= kTechId.Egg then
                        if eggTechId == kTechId.GorgeEgg then
                            presEquipped = presEquipped + kGorgeCost
                        elseif eggTechId == kTechId.LerkEgg then
                            presEquipped = presEquipped + kLerkCost
                        elseif eggTechId == kTechId.FadeEgg then
                            presEquipped = presEquipped + kFadeUpgradeCost
                        elseif eggTechId == kTechId.OnosEgg then
                            presEquipped = presEquipped + kOnosCost
                        end
                    end
                end


                for count, player in pairs(team) do
                    presUnused = presUnused + player:GetResources()

                    local upgradeAmount = #player:GetUpgrades()


                    if player:isa("Embryo") then

                         -- get upgrades dont work on embryo
                        upgradeAmount = #player.evolvingUpgrades
                        local gestationTechId = player:GetGestationTechId()

                        if gestationTechId == kTechId.Gorge then
                            presEquipped = presEquipped + kGorgeCost + kGorgeUpgradeCost * upgradeAmount
                        elseif gestationTechId == kTechId.Lerk then
                            presEquipped = presEquipped + kLerkCost + kLerkUpgradeCost * upgradeAmount
                        elseif gestationTechId == kTechId.Fade then
                            presEquipped = presEquipped + kFadeCost + kFadeUpgradeCost * upgradeAmount
                        elseif gestationTechId == kTechId.Onos then
                            presEquipped = presEquipped + kOnosCost + kOnosUpgradeCost * upgradeAmount
                        end
                        -- I hate that I have to do it like this
                    elseif player:isa("Commander") then

                        local maxHealth = player:GetMaxHealth()
                        if maxHealth >= kOnosHealth then
                            presEquipped = presEquipped + kOnosCost + kOnosUpgradeCost * upgradeAmount
                        elseif maxHealth >= kFadeHealth then
                            presEquipped = presEquipped + kFadeCost + kFadeUpgradeCost * upgradeAmount
                        elseif maxHealth >= kLerkHealth then
                            presEquipped = presEquipped + kLerkCost + kLerkUpgradeCost * upgradeAmount
                        elseif maxHealth >= kGorgeHealth then
                            presEquipped = presEquipped + kGorgeCost + kGorgeUpgradeCost * upgradeAmount
                        end
                    elseif player:isa("Gorge") then
                        presEquipped = presEquipped + kGorgeCost + kGorgeUpgradeCost * upgradeAmount
                    elseif player:isa("Lerk") then
                        presEquipped = presEquipped + kLerkCost + kLerkUpgradeCost * upgradeAmount
                    elseif player:isa("Fade") then
                        presEquipped = presEquipped + kFadeCost + kFadeUpgradeCost * upgradeAmount
                    elseif player:isa("Onos") then
                        presEquipped = presEquipped + kOnosCost + kOnosUpgradeCost * upgradeAmount
                    end


                    if not player:isa("Commander") then

                         -- used for counting how many players receive pres
                         if player:GetResources() < 100  then
                            playerCount = playerCount + 1
                        end

                    end
                end

                --Log("unused: %s, equipped: %s", presUnused, presEquipped)
                STATSUI_PresGraphAliens(presUnused, presEquipped, currentRTs, playerCount)
                self.lastUpdatePresGraphAlien = self.timeSinceGameStateChanged


                 -- make sure to offset it by 0.1 once to be behind the kResourceTowerResourceInterval
                 if self.lastUpdatePresGraphAlien < 0.05 then
                    self.lastUpdatePresGraphAlien = 0.1 - kUpdateGraphInterval
                end
            end

        else
            self.lastUpdatePresGraphMarine = -100
            self.lastUpdatePresGraphAlien = -100
        end
    end
end
