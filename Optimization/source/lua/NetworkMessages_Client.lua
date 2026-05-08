-- ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\NetworkMessages_Client.lua
--
--    Created by:   Charlie Cleveland (charlie@unknownworlds.com) and
--                  Max McGuire (max@unknownworlds.com)
--
-- See the Messages section of the Networking docs in Spark Engine scripting docs for details.
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================
Script.Load("lua/InsightNetworkMessages_Client.lua")
Script.Load("lua/bots/BotDebuggingNetworkMessages_Client.lua")

function OnCommandPing(pingTable)
    PROFILE("NetworkMessages_Client:OnCommandPing")
    local playerId, ping = ParsePingMessage(pingTable)
    Scoreboard_SetPing(playerId, ping)

end

function OnCommandHitEffect(hitEffectTable)
    PROFILE("NetworkMessages_Client:OnCommandHitEffect")
    local position, doer, surface, target, showtracer, altMode, damage, direction =
        ParseHitEffectMessage(hitEffectTable)
    HandleHitEffect(position, doer, surface, target, showtracer, altMode, damage, direction)

end

-- Show damage numbers for players.
function OnCommandDamage(damageTable)
    PROFILE("NetworkMessages_Client:OnCommandDamage")
    local targetId, amount, hitpos, type = ParseDamageMessage(damageTable)

    local worldMessageType = type == kDamageMessageType.Boneshield and kWorldTextMessageType.DamageBoneshield or
                                 kWorldTextMessageType.Damage
    Client.AddWorldMessage(worldMessageType, amount, hitpos, targetId)

end

function OnCommandMarkEnemy(msg)
    PROFILE("NetworkMessages_Client:OnCommandMarkEnemy")
    local target, weapon = ParseMarkEnemyMessage(msg)
    local player = Client.GetLocalPlayer()
    if not player:GetIsCommander() and player.MarkEnemyFromServer then
        player:MarkEnemyFromServer(target, weapon)
    end

end

function OnCommandHitSound(hitSoundTable)
    PROFILE("NetworkMessages_Client:OnCommandHitSound")
    local sound = ParseHitSoundMessage(hitSoundTable)
    HitSounds_PlayHitsound(sound)

end

function OnCommandAbilityResult(msg)
    PROFILE("NetworkMessages_Client:OnCommandAbilityResult")
    -- The server will send us this message to tell us an ability succeded.
    local player = Client.GetLocalPlayer()
    if player:GetIsCommander() then
        player:OnAbilityResultMessage(msg.techId, msg.success, msg.castTime)
    end

end

function OnCommandScores(scoreTable)

    local status = kPlayerStatus[scoreTable.status]
    if scoreTable.status == kPlayerStatus.Hidden then
        status = "-"
    elseif scoreTable.status == kPlayerStatus.Dead then
        status = Locale.ResolveString("STATUS_DEAD")
    elseif scoreTable.status == kPlayerStatus.Evolving then
        status = Locale.ResolveString("STATUS_EVOLVING")
    elseif scoreTable.status == kPlayerStatus.Embryo then
        status = Locale.ResolveString("STATUS_EMBRYO")
    elseif scoreTable.status == kPlayerStatus.Commander then
        status = Locale.ResolveString("STATUS_COMMANDER")
    elseif scoreTable.status == kPlayerStatus.Exo then
        status = Locale.ResolveString("STATUS_EXO")
    elseif scoreTable.status == kPlayerStatus.GrenadeLauncher then
        status = Locale.ResolveString("STATUS_GRENADE_LAUNCHER")
    elseif scoreTable.status == kPlayerStatus.Rifle then
        status = Locale.ResolveString("STATUS_RIFLE")
    elseif scoreTable.status == kPlayerStatus.HeavyMachineGun then
        status = Locale.ResolveString("STATUS_HMG")
    elseif scoreTable.status == kPlayerStatus.Shotgun then
        status = Locale.ResolveString("STATUS_SHOTGUN")
    elseif scoreTable.status == kPlayerStatus.Flamethrower then
        status = Locale.ResolveString("STATUS_FLAMETHROWER")
    elseif scoreTable.status == kPlayerStatus.Void then
        status = Locale.ResolveString("STATUS_VOID")
    elseif scoreTable.status == kPlayerStatus.Spectator then
        status = Locale.ResolveString("STATUS_SPECTATOR")
    elseif scoreTable.status == kPlayerStatus.Skulk then
        status = Locale.ResolveString("STATUS_SKULK")
    elseif scoreTable.status == kPlayerStatus.Gorge then
        status = Locale.ResolveString("STATUS_GORGE")
    elseif scoreTable.status == kPlayerStatus.Lerk then
        status = Locale.ResolveString("STATUS_LERK")
    elseif scoreTable.status == kPlayerStatus.Fade then
        status = Locale.ResolveString("STATUS_FADE")
    elseif scoreTable.status == kPlayerStatus.Onos then
        status = Locale.ResolveString("STATUS_ONOS")
    elseif scoreTable.status == kPlayerStatus.SkulkEgg then
        status = Locale.ResolveString("SKULK_EGG")
    elseif scoreTable.status == kPlayerStatus.GorgeEgg then
        status = Locale.ResolveString("GORGE_EGG")
    elseif scoreTable.status == kPlayerStatus.LerkEgg then
        status = Locale.ResolveString("LERK_EGG")
    elseif scoreTable.status == kPlayerStatus.FadeEgg then
        status = Locale.ResolveString("FADE_EGG")
    elseif scoreTable.status == kPlayerStatus.OnosEgg then
        status = Locale.ResolveString("ONOS_EGG")
    end

    Scoreboard_SetPlayerData(scoreTable.clientId, scoreTable.entityId, scoreTable.playerName, scoreTable.teamNumber,
        scoreTable.score, scoreTable.kills, scoreTable.deaths, math.floor(scoreTable.resources), scoreTable.isCommander,
        scoreTable.isRookie, status, scoreTable.isSpectator, scoreTable.assists, scoreTable.clientIndex)

end

function OnCommandClearTechTree()
    PROFILE("NetworkMessages_Client:OnCommandClearTechTree")
    ClearTechTree()
    PlayerUI_ClearResearchNotifications()
end

function OnCommandTechNodeBase(techNodeBaseTable)
    PROFILE("NetworkMessages_Client:OnCommandTechNodeBase")
    GetTechTree():CreateTechNodeFromNetwork(techNodeBaseTable)
end

function OnCommandTechNodeUpdate(techNodeUpdateTable)
    PROFILE("NetworkMessages_Client:OnCommandTechNodeUpdate")
    GetTechTree():UpdateTechNodeFromNetwork(techNodeUpdateTable)
end

function OnCommandTechNodeInstanceUpdate(techNodeUpdateTable)
    PROFILE("NetworkMessages_Client:OnCommandTechNodeInstanceUpdate")
    GetTechTree():UpdateNodeInstanceFromNetwork(techNodeUpdateTable)
end

function OnCommandOnResetGame()
    PROFILE("NetworkMessages_Client:OnCommandOnResetGame")
    Scoreboard_OnResetGame()
    ResetLights()

    if GetGameInfoEntity() then
        GetGameInfoEntity():OnResetGame()
    end
end

function OnCommandDebugLine(debugLineMessage)
    DebugLine(ParseDebugLineMessage(debugLineMessage))
end

function OnCommandDebugCapsule(debugCapsuleMessage)
    DebugCapsule(ParseDebugCapsuleMessage(debugCapsuleMessage))
end

function OnDebugDumpRoundStats(message)
    assert(message.dumpRoundStats)
    Log("Round-End stats dump is %s", (message.dumpRoundStats and "ENABLED" or "DISABLED"))
end

function OnCommandDebugGrenades(message)
    Log("Grenades debug %s", (message.enabled == true and "ENABLED" or "DISABLED"))
end

function OnCommandMinimapAlert(message)
    PROFILE("NetworkMessages_Client:OnCommandMinimapAlert")
    local player = Client.GetLocalPlayer()
    if player then
        player:AddAlert(message.techId, message.worldX, message.worldZ, message.entityId, message.entityTechId)
    end

end

kWorldTextResolveStrings = {}
kWorldTextResolveStrings[kWorldTextMessageType.Resources] = "RESOURCES_ADDED"
kWorldTextResolveStrings[kWorldTextMessageType.Resource] = "RESOURCE_ADDED"
kWorldTextResolveStrings[kWorldTextMessageType.Damage] = "DAMAGE_TAKEN"
function OnCommandWorldText(message)
    PROFILE("NetworkMessages_Client:OnCommandWorldText")
    local messageStr = string.format(Locale.ResolveString(kWorldTextResolveStrings[message.messageType]), message.data)
    Client.AddWorldMessage(message.messageType, messageStr, message.position)

end

function OnCommandCommanderError(message)
    PROFILE("NetworkMessages_Client:OnCommandCommanderError")
    local messageStr = Locale.ResolveString(message.data)
    Client.AddWorldMessage(kWorldTextMessageType.CommanderError, messageStr, message.position)

end

function OnCommandJoinError(message)
    PROFILE("NetworkMessages_Client:OnCommandJoinError")
    if message.reason == 0 then
        ChatUI_AddSystemMessage(Locale.ResolveString("JOIN_ERROR_TOO_MANY"))
    elseif message.reason == 1 then
        ChatUI_AddSystemMessage(Locale.ResolveString("JOIN_ERROR_ROOKIE"))
    elseif message.reason == 2 then
        ChatUI_AddSystemMessage(Locale.ResolveString("JOIN_ERROR_VETERAN"))
    elseif message.reason == 3 then
        ChatUI_AddSystemMessage(Locale.ResolveString("JOIN_ERROR_NO_PLAYER_SLOT_LEFT"))
    end
end

function OnCommanderLoginError(message)
    PROFILE("NetworkMessages_Client:OnCommanderLoginError")
    ChatUI_AddSystemMessage(Locale.ResolveString("LOGIN_ERROR_ROOKIE"))
end

function OnVoteConcedeCast(message)
    PROFILE("NetworkMessages_Client:OnVoteConcedeCast")
    local text = string.format(Locale.ResolveString("VOTE_CONCEDE_BROADCAST"), message.voterName,
        message.votesMoreNeeded)
    ChatUI_AddSystemMessage(text)

end

function OnVoteEjectCast(message)
    PROFILE("NetworkMessages_Client:OnVoteEjectCast")
    local text = string.format(Locale.ResolveString("VOTE_EJECT_BROADCAST"), message.voterName, message.votesMoreNeeded)
    ChatUI_AddSystemMessage(text)

end

function OnTeamConceded(message)
    PROFILE("NetworkMessages_Client:OnTeamConceded")
    if message.teamNumber == kMarineTeamType then
        ChatUI_AddSystemMessage(Locale.ResolveString("TEAM_MARINES_CONCEDED"))
    else
        ChatUI_AddSystemMessage(Locale.ResolveString("TEAM_ALIENS_CONCEDED"))
    end

end

local function OnDisabledOption(msg)

    local key = msg.disabledOption

    if AdvancedOptions[key] ~= nil then

        AdvancedOptions[key].disabled = true

        if AdvancedOptions[key].immediateUpdate then

            AdvancedOptions[key].immediateUpdate()

        end
    end
end

Client.HookNetworkMessage("DisabledOption", OnDisabledOption)

local function OnCommandCreateDecal(message)

    PROFILE("NetworkMessages_Client:OnCommandCreateDecal")

    local normal, position, materialName, scale = ParseCreateDecalMessage(message)

    local coords = Coords.GetTranslation(position)
    coords.yAxis = normal

    local randomAxis = Vector(math.random() * 2 - 0.9, math.random() * 2 - 1.1, math.random() * 2 - 1)
    randomAxis:Normalize()

    coords.zAxis = randomAxis
    coords.xAxis = coords.yAxis:CrossProduct(coords.zAxis)
    coords.zAxis = coords.xAxis:CrossProduct(coords.yAxis)

    coords.xAxis:Normalize()
    coords.yAxis:Normalize()

    Shared.CreateTimeLimitedDecal(materialName, coords, scale)

end
Client.HookNetworkMessage("CreateDecal", OnCommandCreateDecal)

local function OnSetClientIndex(message)
    Client.localClientIndex = message.clientIndex
end
Client.HookNetworkMessage("SetClientIndex", OnSetClientIndex)

local function OnSetServerHidden(message)
    Client.serverHidden = message.hidden
end
Client.HookNetworkMessage("ServerHidden", OnSetServerHidden)

local function OnSetClientTeamNumber(message)
    Client.localClientTeamNumber = message.teamNumber

    local guiVoiceChat = ClientUI.GetScript("GUIVoiceChat")
    if guiVoiceChat then
        guiVoiceChat:Reload()
    end
end
Client.HookNetworkMessage("SetClientTeamNumber", OnSetClientTeamNumber)

local function OnScoreUpdate(message)
    PROFILE("NetworkMessages_Client:OnScoreUpdate")
    ScoreDisplayUI_SetNewScore(message.points, message.res, message.wasKill)
end
Client.HookNetworkMessage("ScoreUpdate", OnScoreUpdate)

local function OnMessageAutoConcedeWarning(message)
    PROFILE("NetworkMessages_Client:OnMessageAutoConcedeWarning")
    local warningText = StringReformat(Locale.ResolveString("AUTO_CONCEDE_WARNING"), {
        time = message.time,
        teamName = message.team1Conceding and "Marines" or "Aliens"
    })
    ChatUI_AddSystemMessage(warningText)

end

local function OnCommandCameraShake(message)
    PROFILE("NetworkMessages_Client:OnCommandCameraShake")
    local intensity = ParseCameraShakeMessage(message)

    local player = Client.GetLocalPlayer()
    if player and player.SetCameraShake then
        player:SetCameraShake(intensity * 0.1, 5, 0.25)
    end

end

local function OnSetAchievement(message)
    if message and message.name then
        if not Client.GetAchievement(message.name) then
            -- Only attempt to set it when not unlocked already (saves steam api call/lock-state)
            Client.SetAchievement(message.name)
        end
    end
end

local function OnDangerMusicUpdate(message)
    PROFILE("NetworkMessages_Client:OnDangerMusicUpdate")
    assert(message)

    local player = Client.GetLocalPlayer() -- skip spectators entirely?
    assert(player)

    if player:GetDistance(message.origin) <= kDangerMusicCheckStartDistance or
        (player:isa("Commander") and message.teamIndex == player:GetTeamNumber()) then
        -- EH...case to be made for this NOT to play for Comms
        local musicName = message.active and "sound/NS2.fev/danger" or "sound/NS2.fev/no_danger"

        Client.PlayMusic(musicName)
        Client._playingDangerMusic = true
    end

    if message.active == false and Client:IsPlayingDangerMusic() then -- ideally this should have a constant timeout func
        Client.PlayMusic("sound/NS2.fev/no_danger")
        Client._playingDangerMusic = false
    end

end

local function OnRoundStatsProcessingComplete()
    Log("Received RoundStatsProcessingComplete Net-Message")

    local hiveProfile = {}
    Client.GetLocalHiveProfileData(hiveProfile)

    local scorePlayer = Client.GetLocalPlayer()
    if scorePlayer and HasMixin(scorePlayer, "Scoring") then
        Log("Caching updated skill data from server")
        Log("Current hive profile data: %s", hiveProfile)

        local level = scorePlayer:GetPlayerLevel()
        local xp = scorePlayer:GetTotalXP()
        local score = scorePlayer:GetScore()

        -- Leave these fields as originally fetched
        local lat = hiveProfile[15]
        local long = hiveProfile[16]
        local tdSysEnabled = hiveProfile[17]

        if Shared.GetThunderdomeEnabled() then

            local td_skill = scorePlayer:GetTDPlayerSkill()
            local td_commSkill = scorePlayer:GetTDPlayerCommanderSkill()
            local td_skillOffset = scorePlayer:GetTDPlayerSkillOffset()
            local td_commSkillOffset = scorePlayer:GetTDPlayerCommanderSkillOffset()
            local td_adagrad = scorePlayer:GetTDAdagradSum()

            Client.SetLocalHiveProfileData(hiveProfile[1], hiveProfile[2], hiveProfile[3], hiveProfile[4],
                hiveProfile[5], td_skill, td_commSkill, td_skillOffset, td_commSkillOffset, td_adagrad, level, xp,
                score, "", -- Note: badges now handled via Steam items
                lat, long, tdSysEnabled)

        else

            local skill = scorePlayer:GetPlayerSkill()
            local commSkill = scorePlayer:GetCommanderSkill()
            local skillOffset = scorePlayer:GetPlayerSkillOffset()
            local commSkillOffset = scorePlayer:GetCommanderSkillOffset()
            local adagrad = scorePlayer:GetAdagradSum()

            Client.SetLocalHiveProfileData(skill, commSkill, skillOffset, commSkillOffset, adagrad, hiveProfile[6],
                hiveProfile[7], hiveProfile[8], hiveProfile[9], hiveProfile[10], level, xp, score, "", -- Note: badges now handled via Steam items
                lat, long, tdSysEnabled)

        end

    end

    local postupdate = {}
    Client.GetLocalHiveProfileData(postupdate)

    Log("New hive profile data: %s", postupdate)

end

Client.HookNetworkMessage("AutoConcedeWarning", OnMessageAutoConcedeWarning)

Client.HookNetworkMessage("Ping", OnCommandPing)
Client.HookNetworkMessage("HitEffect", OnCommandHitEffect)
Client.HookNetworkMessage("Damage", OnCommandDamage)
Client.HookNetworkMessage("MarkEnemy", OnCommandMarkEnemy)
Client.HookNetworkMessage("HitSound", OnCommandHitSound)
Client.HookNetworkMessage("AbilityResult", OnCommandAbilityResult)
Client.HookNetworkMessage("JoinError", OnCommandJoinError)
Client.HookNetworkMessage("CommanderLoginError", OnCommanderLoginError)

Client.HookNetworkMessage("ClearTechTree", OnCommandClearTechTree)
Client.HookNetworkMessage("TechNodeBase", OnCommandTechNodeBase)
Client.HookNetworkMessage("TechNodeUpdate", OnCommandTechNodeUpdate)
Client.HookNetworkMessage("TechNodeInstance", OnCommandTechNodeInstanceUpdate)

Client.HookNetworkMessage("MinimapAlert", OnCommandMinimapAlert)

Client.HookNetworkMessage("ResetGame", OnCommandOnResetGame)

Client.HookNetworkMessage("DebugLine", OnCommandDebugLine)
Client.HookNetworkMessage("DebugCapsule", OnCommandDebugCapsule)

Client.HookNetworkMessage("DumpRoundStats", OnDebugDumpRoundStats)

Client.HookNetworkMessage("DebugGrenades", OnCommandDebugGrenades)

Client.HookNetworkMessage("WorldText", OnCommandWorldText)
Client.HookNetworkMessage("CommanderError", OnCommandCommanderError)

Client.HookNetworkMessage("VoteConcedeCast", OnVoteConcedeCast)
Client.HookNetworkMessage("VoteEjectCast", OnVoteEjectCast)
Client.HookNetworkMessage("TeamConceded", OnTeamConceded)
Client.HookNetworkMessage("CameraShake", OnCommandCameraShake)

Client.HookNetworkMessage("SetAchievement", OnSetAchievement)

Client.HookNetworkMessage("DangerMusicUpdate", OnDangerMusicUpdate)

Client.HookNetworkMessage("RoundStatsProcessingCompleted", OnRoundStatsProcessingComplete)

if Shared.GetThunderdomeEnabled() then
    -- Simple hook for client to check if its unlocked any items from a TD round

    Client.HookNetworkMessage("Thunderdome_EndRoundItemsCheck", function()
        SLog("----  TD Unlocks Net-msg received, checking stats and achievements  ---")
        Client.ForceUpdateAchievements()
    end)

end
