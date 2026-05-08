-- ======= Copyright (c) 2003-2020, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua/GUIGameEndStats.lua
--
-- Ported by: Darrell Gentry (darrell@naturalselection2.com)
--
-- Port of the NS2+ end of round stats. It displays an amalgam of stats at the end of a round.
-- Originally Created By: Juanjo Alfaro "Mendasp"
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================
class "GUIGameEndStats"(GUIScript)

local zlib = require("zlib")
local json = require("json")

Script.Load("lua/graphs/LineGraph.lua")
Script.Load("lua/graphs/ComparisonBarGraph.lua")
Script.Load("lua/NS2Utility.lua")
Script.Load("lua/GUI/GUIObject.lua")
Script.Load("lua/menu2/PlayerScreen/FriendsList/GUIMenuAvatar.lua")

local kButtonClickSound = "sound/NS2.fev/common/button_click"
local kMouseHoverSound = "sound/NS2.fev/common/hovar"
local kSlideSound = "sound/NS2.fev/marine/commander/hover_ui"
Client.PrecacheLocalSound(kButtonClickSound)
Client.PrecacheLocalSound(kMouseHoverSound)
Client.PrecacheLocalSound(kSlideSound)

local screenWidth = Client.GetScreenWidth()
local screenHeight = Client.GetScreenHeight()
local aspectRatio = screenWidth / screenHeight
local lowResScreen = (screenWidth < 1800) and true or false

local kSteamProfileURL = "http://steamcommunity.com/profiles/"
local kNs2PanelUserURL = "https://ns2panel.com/player/"

local function RGBAtoColor(r, g, b, a)
    return Color(r / 255, g / 255, b / 255, a)
end

-- Round function implementation with round up and decimal
local function round(number, decimals)
    if number and IsNumber(number) then
        if decimals > 0 then
            decimals = 10 ^ decimals
            number = number * decimals
            number = number % 1 >= 0.5 and math.ceil(number) or math.floor(number)
            number = number / decimals
        else
            number = number % 1 >= 0.5 and math.ceil(number) or math.floor(number)
        end
        return tostring(number)
    else
        return "NaN"
    end
end

local function roundNumber(number, decimals)
    if number and IsNumber(number) then
        if decimals > 0 then
            decimals = 10 ^ decimals
            number = number * decimals
            number = number % 1 >= 0.5 and math.ceil(number) or math.floor(number)
            number = number / decimals
        else
            number = number % 1 >= 0.5 and math.ceil(number) or math.floor(number)
        end

        return number
    else
        return 0
    end
end

local function humanNumber(number)
    if number and IsNumber(number) then
        if number > 1000000 then
            number = number / 10000
            number = number % 1 >= 0.5 and math.ceil(number) or math.floor(number)
            number = number / 100
            number = tostring(number) .. "m"
        elseif number > 1000 then
            number = number / 100
            number = number % 1 >= 0.5 and math.ceil(number) or math.floor(number)
            number = number / 10
            number = tostring(number) .. "k"
        end

        return tostring(number)
    else
        return "NaN"
    end
end

-- To avoid printing 200.00 or things like that
local function printNumWithDecimals(number, decimals)
    if number and IsNumber(number) then
        if decimals == 0 or number == math.floor(number) then
            return string.format("%d", number)
        else
            return string.format("%." .. decimals .. "f", number)
        end
    else
        return "NaN"
    end
end

local printNum = function(number)
    return printNumWithDecimals(number, 2)
end
local printNum1 = function(number)
    return printNumWithDecimals(number, 1)
end
local printNum2 = function(number)
    return printNumWithDecimals(number, 2)
end

function CompressTable(tbl)
    local jsonData = json.encode(tbl)
    local deflater = zlib.deflate()
    return deflater(jsonData, "finish")
end

function DecompressToTable(data)
    local inflater = zlib.inflate()
    local jsonData = inflater(data, "finish")
    return json.decode(jsonData)
end

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

local function startswith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local kTitleFontName = Fonts.kAgencyFB_Medium
local kSubTitleFontName = Fonts.kAgencyFB_Small
local kRowFontName = Fonts.kArial_17
local widthPercentage
local kBackgroundSize
local kTitleSize
local kCardSize
local kTechLogTitleSize
local kCloseButtonSize
local scaledVector
local kTopOffset
local rtGraphPadding
local rtGraphSize
local comparisonSize

local kMarineStatsColor = Color(0, 0.75, 0.88, 0.65)
local kAlienStatsColor = Color(0.84, 0.48, 0.17, 0.65)
local kCommanderStatsColor = Color(0.75, 0.75, 0, 0.65)
local kStatusStatsColor = Color(1, 1, 1, 0.65)
local kPlayerStatsTextColor = Color(1, 1, 1, 1)
local kMarinePlayerStatsEvenColor = Color(0, 0, 0, 0.75)
local kMarinePlayerStatsOddColor = Color(0, 0, 0, 0.65)
local kAlienPlayerStatsEvenColor = Color(0, 0, 0, 0.75)
local kAlienPlayerStatsOddColor = Color(0, 0, 0, 0.65)
local kCurrentPlayerStatsColor = Color(1, 1, 1, 0.75)
local kCurrentPlayerStatsTextColor = Color(0, 0, 0, 1)
local kCommanderStatsEvenColor = kMarinePlayerStatsEvenColor
local kCommanderStatsOddColor = kMarinePlayerStatsOddColor
local kLostTechEvenColor = Color(0.55, 0, 0, 1)
local kLostTechOddColor = Color(0.65, 0, 0, 1)
local kHeaderRowColor = Color(0, 0, 0, 0)
local kMarineHeaderRowTextColor = Color(1, 1, 1, 1)
local kMarineHeaderRowTextHighlightColor = Color(0, 0, 0, 1)
local kAlienHeaderRowTextColor = Color(1, 1, 1, 1)
local kAlienHeaderRowTextHighlightColor = Color(0, 0, 0, 1)
local kAverageRowColor = Color(0.05, 0.05, 0.05, 0.25)
local kAverageRowTextColor = Color(1, 1, 1, 1)

local kHeaderTexture = PrecacheAsset("ui/statsheader.dds")
local kHeaderCoordsLeft = {0, 0, 15, 64}
local kHeaderCoordsMiddle = {16, 0, 112, 64}
local kHeaderCoordsRight = {113, 0, 128, 64}
local kMarineStatsLogo = PrecacheAsset("ui/logo_marine.dds")
local kAlienStatsLogo = PrecacheAsset("ui/logo_alien.dds")
local kMissingAvatarTexture = PrecacheAsset("ui/missing_avatar.dds")
local kAvatarFrameTexture = PrecacheAsset("ui/thunderdome/roledisplay_avatar_frame.dds")
local kEalAlienTexture = PrecacheAsset("ui/Devnull_IPS/Alien.dds")
local kEalMarineArmoryTexture = PrecacheAsset("ui/Devnull_IPS/Marine.dds")
local kIpsBackgroundGeneric = PrecacheAsset("ui/Devnull_IPS/bg_generic.dds")
local kIpsBackgroundAliens = PrecacheAsset("ui/Devnull_IPS/bg_alien_" .. tostring(math.random(1, 2)) .. ".dds")
local kIpsBackgroundMarines = PrecacheAsset("ui/Devnull_IPS/bg_marines_" .. tostring(math.random(1, 2)) .. ".dds")
-- local kSmurfAvatarTexture = PrecacheAsset("ui/smurf_avatar.dds")
local kCommBadgeTexture = PrecacheAsset("ui/badges/commander_20.dds")
local kCommSkillIconTexture = PrecacheAsset("ui/Devnull_IPS/ComSkillBadges.dds")

-- Tier skill
local kPlayerSkillIconSize = Vector(62, 20, 0)
local kPlayerSkillIconTexture = PrecacheAsset("ui/skill_tier_icons.dds")
local kPlayerSkillIconSizeOverride = Vector(58, 20, 0)

-- Kill Stats icons
local kBuildMenuTexture = PrecacheAsset("ui/buildmenu.dds")

local kLogoSize
local kLogoOffset
local kTeamNameOffset
local kTextShadowOffset
local kTextShadowOffsetMini
local kPlayerCountOffset
local kContentMaxYSize

local kRowSize
local kCardRowSize
local kTechLogRowSize
local kTableContainerOffset
local kRowBorderSize
local kRowPlayerNameOffset

local finalStatsTable = {}
local playerStatMap = {}
local avgAccTable = {}
local miscDataTable = {}
local cardsTable = {}
local hiveSkillGraphTable = {}
local rtGraphTable = {}
local commanderStats
local killGraphTable = {}
local equipmentAndLifeformsLogTable = {}
local teamSpecificStatsLogTable = {}
local buildingSummaryTable = {}
local statusSummaryTable = {}
local techLogTable = {}

local DIPS_EnahncedStats = false
local DIPS_AlienCommID = nil
local DIPS_MarineCommID = nil

local lastStatsMsg = -100
local lastGameEnd = 0
local kMaxAppendTime = 2.5
local loadedLastRound = false
local lastRoundFile = "config://NS2Plus/LastRoundStats.json"

local highlightedField
local highlightedFieldMarine
local lastSortedT1 = "kills"
local lastSortedT1WasInv = false
local lastSortedT2 = "kills"
local lastSortedT2WasInv = false

local avatarObj = ""

local TopScorePlayer = {}
local TopKillsPlayer = {}
local TopMarineAccPlayer = {}
local TopPDmgPlayer = {}
local TopSDmgPlayer = {}
local TopBuildTimePlayer = {}

local presGraphTableMarines = {}
local presGraphTableAliens = {}

local function estimateHiveSkillGraph()
    if #hiveSkillGraphTable ~= 0 or #finalStatsTable == 0 then
        return
    end

    -- split and sort into teams
    local teams = {}
    for _, stat in ipairs(finalStatsTable) do
        if stat.score ~= 0 and stat.minutesPlaying > 0 and stat.teamNumber ~= 0 then
            if not teams[stat.teamNumber] then
                teams[stat.teamNumber] = {}
            end
            table.insert(teams[stat.teamNumber], stat)
        end
    end

    if #teams < 2 then
        return
    end

    table.sort(teams[1], function(a, b)
        return a.minutesPlaying > b.minutesPlaying
    end)
    table.sort(teams[2], function(a, b)
        return a.minutesPlaying > b.minutesPlaying
    end)

    -- greedy knapsack
    local gameLength = miscDataTable.gameLengthMinutes
    local left = gameLength
    for _, team in ipairs(teams) do
        repeat
            left = gameLength
            for i, player in ipairs(team) do
                if player and player.minutesPlaying then
                    if left - player.minutesPlaying >= 0 then
                        table.insert(hiveSkillGraphTable, {
                            gameMinute = gameLength - left,
                            joined = true,
                            teamNumber = player.teamNumber,
                            steamId = player.steamId
                        })
                        left = left - player.minutesPlaying
                        table.insert(hiveSkillGraphTable, {
                            gameMinute = gameLength - left,
                            joined = false,
                            teamNumber = player.teamNumber,
                            steamId = player.steamId
                        })
                        -- allow some time for others to react and join instead
                        left = left - 10 / 60
                        team[i] = {}
                    end
                end
            end
        until left == gameLength
    end
end

local function UpdateSizeOfUI()
    screenWidth = Client.GetScreenWidth()
    screenHeight = Client.GetScreenHeight()
    aspectRatio = screenWidth / screenHeight
    lowResScreen = (screenWidth < 1800) and true or false

    widthPercentage = ConditionalValue(aspectRatio < 1.5, 0.95, 0.75)
    kTitleSize = Vector(screenWidth * widthPercentage, GUILinearScale(74), 0)
    local backgroundScale = (screenWidth * widthPercentage) / 1190
    kBackgroundSize = Vector(1190 * backgroundScale, 384 * backgroundScale, 0)
    kCardSize = Vector(kTitleSize.x / 3.5, GUILinearScale(74), 0)
    kTechLogTitleSize = Vector(kTitleSize.x / 2 - GUILinearScale(16), GUILinearScale(74), 0)
    kCloseButtonSize = Vector(GUILinearScale(24), GUILinearScale(24), 0)
    scaledVector = GUILinearScale(Vector(1, 1, 1))
    kTopOffset = GUILinearScale(32)

    kLogoSize = GUILinearScale(Vector(52, 52, 0))
    kLogoOffset = GUILinearScale(4)
    kTeamNameOffset = GUILinearScale(10)
    kTextShadowOffset = GUILinearScale(2)
    kTextShadowOffsetMini = GUILinearScale(1)
    kPlayerCountOffset = -GUILinearScale(20)
    kContentMaxYSize = screenHeight - GUILinearScale(128) - kTopOffset

    kRowSize = Vector(kTitleSize.x - (kLogoSize.x + kTeamNameOffset) * 2, GUILinearScale(24), 0)
    kCardRowSize = Vector(kCardSize.x * 0.85, GUILinearScale(24), 0)
    kTechLogRowSize = Vector(kTechLogTitleSize.x * 0.85, GUILinearScale(24), 0)
    kTableContainerOffset = GUILinearScale(5)
    kRowBorderSize = GUILinearScale(2)
    kRowPlayerNameOffset = GUILinearScale(10)

    rtGraphPadding = GUILinearScale(50)
    rtGraphSize = Vector(kTitleSize.x * 0.85, GUILinearScale(370), 0)
    comparisonSize = GUILinearScale(Vector(400, 30, 0))
end

function GUIGameEndStats:CreateTeamBackground(teamNumber)
    local color = kMarineStatsColor
    local teamLogo = kMarineStatsLogo
    local teamName = Locale.ResolveString("NAME_TEAM_1")

    if teamNumber == 2 then
        color = kAlienStatsColor
        teamLogo = kAlienStatsLogo
        teamName = Locale.ResolveString("NAME_TEAM_2")
    end

    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(color)
    item.background:SetTexture(kHeaderTexture)
    item.background:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsMiddle))
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetInheritsParentAlpha(false)
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(Vector(kTitleSize.x - GUILinearScale(64), kTitleSize.y, 0))

    item.backgroundLeft = GUIManager:CreateGraphicItem()
    item.backgroundLeft:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundLeft:SetColor(color)
    item.backgroundLeft:SetTexture(kHeaderTexture)
    item.backgroundLeft:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsLeft))
    item.backgroundLeft:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundLeft:SetInheritsParentAlpha(false)
    item.backgroundLeft:SetLayer(kGUILayerMainMenu)
    item.backgroundLeft:SetSize(Vector(GUILinearScale(16), kTitleSize.y, 0))
    item.backgroundLeft:SetPosition(Vector(-GUILinearScale(16), 0, 0))
    item.background:AddChild(item.backgroundLeft)

    item.backgroundRight = GUIManager:CreateGraphicItem()
    item.backgroundRight:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundRight:SetColor(color)
    item.backgroundRight:SetTexture(kHeaderTexture)
    item.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
    item.backgroundRight:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundRight:SetInheritsParentAlpha(false)
    item.backgroundRight:SetLayer(kGUILayerMainMenu)
    item.backgroundRight:SetSize(Vector(GUILinearScale(16), kTitleSize.y, 0))
    item.backgroundRight:SetPosition(Vector(kTitleSize.x - GUILinearScale(64), 0, 0))
    item.background:AddChild(item.backgroundRight)

    item.tableBackground = GUIManager:CreateGraphicItem()
    item.tableBackground:SetStencilFunc(GUIItem.NotEqual)
    item.tableBackground:SetColor(color)
    item.tableBackground:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
    item.tableBackground:SetPosition(Vector(-(kRowSize.x + kRowBorderSize * 2) / 2, -kTableContainerOffset, 0))
    item.tableBackground:SetLayer(kGUILayerMainMenu)
    item.tableBackground:SetSize(Vector(kRowSize.x + kRowBorderSize * 2, kRowBorderSize * 2, 0))
    item.background:AddChild(item.tableBackground)

    item.logo = GUIManager:CreateGraphicItem()
    item.logo:SetStencilFunc(GUIItem.NotEqual)
    item.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.logo:SetLayer(kGUILayerMainMenu)
    item.logo:SetIsVisible(true)
    item.logo:SetSize(kLogoSize)
    item.logo:SetPosition(Vector(kLogoOffset, -kLogoSize.y / 2, 0))
    item.logo:SetTexture(teamLogo)
    item.background:AddChild(item.logo)

    item.teamNameTextShadow = GUIManager:CreateTextItem()
    item.teamNameTextShadow:SetStencilFunc(GUIItem.NotEqual)
    item.teamNameTextShadow:SetFontName(kTitleFontName)
    item.teamNameTextShadow:SetColor(Color(0, 0, 0, 1))
    item.teamNameTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.teamNameTextShadow)
    item.teamNameTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.teamNameTextShadow:SetText(teamName)
    item.teamNameTextShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamNameTextShadow:SetPosition(Vector(kLogoSize.x + kTeamNameOffset + kTextShadowOffset,
        kTitleSize.y / 2 + kTextShadowOffset, 0))
    item.teamNameTextShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamNameTextShadow)

    item.teamNameText = GUIManager:CreateTextItem()
    item.teamNameText:SetStencilFunc(GUIItem.NotEqual)
    item.teamNameText:SetFontName(kTitleFontName)
    item.teamNameText:SetColor(Color(1, 1, 1, 1))
    item.teamNameText:SetScale(scaledVector)
    GUIMakeFontScale(item.teamNameText)
    item.teamNameText:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.teamNameText:SetText(teamName)
    item.teamNameText:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamNameText:SetPosition(Vector(kLogoSize.x + kTeamNameOffset, kTitleSize.y / 2, 0))
    item.teamNameText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamNameText)

    item.teamGameStatusShadow = GUIManager:CreateTextItem()
    item.teamGameStatusShadow:SetStencilFunc(GUIItem.NotEqual)
    item.teamGameStatusShadow:SetFontName(kTitleFontName)
    item.teamGameStatusShadow:SetColor(Color(0, 0, 0, 1))
    item.teamGameStatusShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.teamGameStatusShadow)
    item.teamGameStatusShadow:SetAnchor(GUIItem.Middle, GUIItem.Center)
    item.teamGameStatusShadow:SetText("")
    item.teamGameStatusShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamGameStatusShadow:SetTextAlignmentX(GUIItem.Align_Center)
    item.teamGameStatusShadow:SetPosition(Vector(kTextShadowOffset, kTextShadowOffset, 0))
    item.teamGameStatusShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamGameStatusShadow)

    item.teamGameStatus = GUIManager:CreateTextItem()
    item.teamGameStatus:SetStencilFunc(GUIItem.NotEqual)
    item.teamGameStatus:SetFontName(kTitleFontName)
    item.teamGameStatus:SetColor(Color(1, 1, 1, 1))
    item.teamGameStatus:SetScale(scaledVector)
    GUIMakeFontScale(item.teamGameStatus)
    item.teamGameStatus:SetAnchor(GUIItem.Middle, GUIItem.Center)
    item.teamGameStatus:SetText("")
    item.teamGameStatus:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamGameStatus:SetTextAlignmentX(GUIItem.Align_Center)
    item.teamGameStatus:SetPosition(Vector(0, 0, 0))
    item.teamGameStatus:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamGameStatus)

    item.teamPlayerCountShadow = GUIManager:CreateTextItem()
    item.teamPlayerCountShadow:SetStencilFunc(GUIItem.NotEqual)
    item.teamPlayerCountShadow:SetFontName(kSubTitleFontName)
    item.teamPlayerCountShadow:SetColor(Color(0, 0, 0, 1))
    item.teamPlayerCountShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.teamPlayerCountShadow)
    item.teamPlayerCountShadow:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.teamPlayerCountShadow:SetText("")
    item.teamPlayerCountShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamPlayerCountShadow:SetTextAlignmentX(GUIItem.Align_Max)
    item.teamPlayerCountShadow:SetPosition(Vector(kPlayerCountOffset + kTextShadowOffset, kTextShadowOffset, 0))
    item.teamPlayerCountShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamPlayerCountShadow)

    item.teamPlayerCount = GUIManager:CreateTextItem()
    item.teamPlayerCount:SetStencilFunc(GUIItem.NotEqual)
    item.teamPlayerCount:SetFontName(kSubTitleFontName)
    item.teamPlayerCount:SetColor(Color(1, 1, 1, 1))
    item.teamPlayerCount:SetScale(scaledVector)
    GUIMakeFontScale(item.teamPlayerCount)
    item.teamPlayerCount:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.teamPlayerCount:SetText("")
    item.teamPlayerCount:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamPlayerCount:SetTextAlignmentX(GUIItem.Align_Max)
    item.teamPlayerCount:SetPosition(Vector(kPlayerCountOffset, 0, 0))
    item.teamPlayerCount:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamPlayerCount)

    return item
end

local function CreateScoreboardRow(container, bgColor, textColor, playerName, kills, assists, deaths, acc, score, pdmg,
    sdmg, timeBuilding, timePlayed, timeComm, steamId, isRookie, hiveSkill)
    local containerSize = container:GetSize()
    container:SetSize(Vector(containerSize.x, containerSize.y + kRowSize.y, 0))

    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(bgColor)
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetPosition(Vector(kRowBorderSize, containerSize.y - kRowBorderSize, 0))
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(kRowSize)

    if steamId then
        item.steamId = steamId
    end

    local skillSpacer = 0

    if hiveSkill and GetPlayerSkillTier and steamId then
        local skillIconOverrideSettings = CheckForSpecialBadgeRecipient(steamId)
        local skillTier, skillTierName = GetPlayerSkillTier(hiveSkill, isRookie)
        item.hiveSkillTier = skillTier
        item.hiveSkillTierName = skillTierName

        item.skillIcon = GUIManager:CreateGraphicItem()
        item.skillIcon:SetStencilFunc(GUIItem.NotEqual)
        item.skillIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
        item.skillIcon:SetIsVisible(true)
        item.skillIcon:SetPosition(Vector(0, -GUILinearScale(10), 0))
        item.skillIcon:SetLayer(kGUILayerMainMenu)
        item.skillIcon.tooltip = string.format(Locale.ResolveString("SKILLTIER_TOOLTIP"),
            Locale.ResolveString(skillTierName), skillTier)

        if not skillIconOverrideSettings then -- Change the skill icon's shader to the one that will animate.
            item.skillIcon:SetTexture(kPlayerSkillIconTexture)
            item.skillIcon:SetShader("shaders/GUIBasic.surface_shader")
            if item.hiveSkillTier > 0 then
                item.skillIcon:SetTexturePixelCoordinates(0, (item.hiveSkillTier + 2) * 32, 100,
                    ((item.hiveSkillTier + 2) + 1) * 32 - 1)
            else
                item.skillIcon:SetTexturePixelCoordinates(0, 0, 100, 31)
            end
            item.skillIcon:SetSize(kPlayerSkillIconSize)
        else
            item.skillIcon:SetShader(skillIconOverrideSettings.shader)
            item.skillIcon:SetTexture(skillIconOverrideSettings.tex)
            item.skillIcon:SetFloatParameter("frameCount", skillIconOverrideSettings.frameCount)

            -- Change the size so it doesn't touch the weapon name text.
            item.skillIcon:SetSize(kPlayerSkillIconSizeOverride * GUIScoreboard.kScalingFactor)

            -- Change the tooltip of the skill icon.
            item.skillIcon.tooltip = skillIconOverrideSettings.tooltip .. "\n" .. item.skillIcon.tooltip
        end
        item.background:AddChild(item.skillIcon)
        skillSpacer = 62
    end

    container:AddChild(item.background)

    item.playerName = GUIManager:CreateTextItem()
    item.playerName:SetStencilFunc(GUIItem.NotEqual)
    item.playerName:SetFontName(kRowFontName)
    item.playerName:SetColor(isRookie and Color(0, 0.8, 0.25, 1) or textColor)
    item.playerName:SetScale(scaledVector)
    GUIMakeFontScale(item.playerName)
    item.playerName:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.playerName:SetTextAlignmentY(GUIItem.Align_Center)
    item.playerName:SetPosition(Vector(skillSpacer + kRowPlayerNameOffset, 0, 0))
    item.playerName:SetText(playerName or "")
    item.playerName:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.playerName)

    local playerNameLength = item.playerName:GetTextWidth(playerName or "") * item.playerName:GetScale().x +
                                 GUILinearScale(5)

    if timeComm then
        item.commIcon = GUIManager:CreateGraphicItem()
        item.commIcon:SetStencilFunc(GUIItem.NotEqual)
        item.commIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
        item.commIcon:SetTexture("ui/badges/commander_grey_20.dds")
        item.commIcon:SetIsVisible(true)
        item.commIcon:SetSize(GUILinearScale(Vector(20, 20, 0)))
        item.commIcon:SetPosition(Vector(skillSpacer + kRowPlayerNameOffset + playerNameLength, -GUILinearScale(10), 0))
        item.commIcon:SetLayer(kGUILayerMainMenu)
        item.commIcon.tooltip = "Commander time: " .. timeComm
        item.background:AddChild(item.commIcon)
    end

    local kItemSize = GUILinearScale(50)
    local xOffset = kRowSize.x
    local kItemPaddingMediumLarge = GUILinearScale(50)
    local kItemPaddingMedium = GUILinearScale(40)
    local kItemPaddingSmallMedium = GUILinearScale(30)
    local kItemPaddingSmall = GUILinearScale(20)
    local kItemPaddingExtraSmall = GUILinearScale(10)

    xOffset = xOffset - kItemPaddingMedium + kItemPaddingExtraSmall

    item.timePlayed = GUIManager:CreateTextItem()
    item.timePlayed:SetStencilFunc(GUIItem.NotEqual)
    item.timePlayed:SetFontName(kRowFontName)
    item.timePlayed:SetColor(textColor)
    item.timePlayed:SetScale(scaledVector)
    GUIMakeFontScale(item.timePlayed)
    item.timePlayed:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.timePlayed:SetTextAlignmentY(GUIItem.Align_Center)
    item.timePlayed:SetTextAlignmentX(GUIItem.Align_Max)
    item.timePlayed:SetPosition(Vector(xOffset, 0, 0))
    item.timePlayed:SetText(timePlayed or "")
    item.timePlayed:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.timePlayed)

    xOffset = xOffset - kItemSize - kItemPaddingExtraSmall

    item.timeBuilding = GUIManager:CreateTextItem()
    item.timeBuilding:SetStencilFunc(GUIItem.NotEqual)
    item.timeBuilding:SetFontName(kRowFontName)
    item.timeBuilding:SetColor(textColor)
    item.timeBuilding:SetScale(scaledVector)
    GUIMakeFontScale(item.timeBuilding)
    item.timeBuilding:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.timeBuilding:SetTextAlignmentY(GUIItem.Align_Center)
    item.timeBuilding:SetTextAlignmentX(GUIItem.Align_Max)
    item.timeBuilding:SetPosition(Vector(xOffset, 0, 0))
    item.timeBuilding:SetText(timeBuilding or "")
    item.timeBuilding:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.timeBuilding)

    xOffset = xOffset - kItemSize - kItemPaddingSmallMedium

    item.sdmg = GUIManager:CreateTextItem()
    item.sdmg:SetStencilFunc(GUIItem.NotEqual)
    item.sdmg:SetFontName(kRowFontName)
    item.sdmg:SetColor(textColor)
    item.sdmg:SetScale(scaledVector)
    GUIMakeFontScale(item.sdmg)
    item.sdmg:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.sdmg:SetTextAlignmentY(GUIItem.Align_Center)
    item.sdmg:SetTextAlignmentX(GUIItem.Align_Max)
    item.sdmg:SetPosition(Vector(xOffset, 0, 0))
    item.sdmg:SetText(sdmg or "")
    item.sdmg:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.sdmg)

    xOffset = xOffset - kItemSize - kItemPaddingSmallMedium

    item.pdmg = GUIManager:CreateTextItem()
    item.pdmg:SetStencilFunc(GUIItem.NotEqual)
    item.pdmg:SetFontName(kRowFontName)
    item.pdmg:SetColor(textColor)
    item.pdmg:SetScale(scaledVector)
    GUIMakeFontScale(item.pdmg)
    item.pdmg:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.pdmg:SetTextAlignmentY(GUIItem.Align_Center)
    item.pdmg:SetTextAlignmentX(GUIItem.Align_Max)
    item.pdmg:SetPosition(Vector(xOffset, 0, 0))
    item.pdmg:SetText(pdmg or "")
    item.pdmg:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.pdmg)

    xOffset = xOffset - kItemSize - kItemSize

    item.score = GUIManager:CreateTextItem()
    item.score:SetStencilFunc(GUIItem.NotEqual)
    item.score:SetFontName(kRowFontName)
    item.score:SetColor(textColor)
    item.score:SetScale(scaledVector)
    GUIMakeFontScale(item.score)
    item.score:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.score:SetTextAlignmentY(GUIItem.Align_Center)
    item.score:SetTextAlignmentX(GUIItem.Align_Max)
    item.score:SetPosition(Vector(xOffset, 0, 0))
    item.score:SetText(score or "")
    item.score:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.score)

    xOffset = xOffset - kItemSize - kItemSize

    item.acc = GUIManager:CreateTextItem()
    item.acc:SetStencilFunc(GUIItem.NotEqual)
    item.acc:SetFontName(kRowFontName)
    item.acc:SetColor(textColor)
    item.acc:SetScale(scaledVector)
    GUIMakeFontScale(item.acc)
    item.acc:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.acc:SetTextAlignmentY(GUIItem.Align_Center)
    item.acc:SetTextAlignmentX(GUIItem.Align_Max)
    item.acc:SetPosition(Vector(xOffset, 0, 0))
    item.acc:SetText(acc or "")
    item.acc:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.acc)

    xOffset = xOffset - kItemSize -
                  ConditionalValue(avgAccTable.marineOnosAcc == -1, kItemPaddingSmall, kItemPaddingMediumLarge) * 2

    item.deaths = GUIManager:CreateTextItem()
    item.deaths:SetStencilFunc(GUIItem.NotEqual)
    item.deaths:SetFontName(kRowFontName)
    item.deaths:SetColor(textColor)
    item.deaths:SetScale(scaledVector)
    GUIMakeFontScale(item.deaths)
    item.deaths:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.deaths:SetTextAlignmentY(GUIItem.Align_Center)
    item.deaths:SetTextAlignmentX(GUIItem.Align_Max)
    item.deaths:SetPosition(Vector(xOffset, 0, 0))
    item.deaths:SetText(deaths or "")
    item.deaths:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.deaths)

    xOffset = xOffset - kItemSize

    item.assists = GUIManager:CreateTextItem()
    item.assists:SetStencilFunc(GUIItem.NotEqual)
    item.assists:SetFontName(kRowFontName)
    item.assists:SetColor(textColor)
    item.assists:SetScale(scaledVector)
    GUIMakeFontScale(item.assists)
    item.assists:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.assists:SetTextAlignmentY(GUIItem.Align_Center)
    item.assists:SetTextAlignmentX(GUIItem.Align_Max)
    item.assists:SetPosition(Vector(xOffset, 0, 0))
    item.assists:SetText(assists or "")
    item.assists:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.assists)

    xOffset = xOffset - kItemSize

    item.kills = GUIManager:CreateTextItem()
    item.kills:SetStencilFunc(GUIItem.NotEqual)
    item.kills:SetFontName(kRowFontName)
    item.kills:SetColor(textColor)
    item.kills:SetScale(scaledVector)
    GUIMakeFontScale(item.kills)
    item.kills:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.kills:SetTextAlignmentY(GUIItem.Align_Center)
    item.kills:SetTextAlignmentX(GUIItem.Align_Max)
    item.kills:SetPosition(Vector(xOffset, 0, 0))
    item.kills:SetText(kills or "")
    item.kills:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.kills)

    return item
end

function GUIGameEndStats:CreateGraphicHeader(text, color, logoTexture, logoCoords, logoSizeX, logoSizeY)
    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(color)
    item.background:SetTexture(kHeaderTexture)
    item.background:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsMiddle))
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetInheritsParentAlpha(false)
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(Vector(kCardSize.x - GUILinearScale(32), kCardSize.y, 0))
    self.background:AddChild(item.background)

    item.backgroundLeft = GUIManager:CreateGraphicItem()
    item.backgroundLeft:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundLeft:SetColor(color)
    item.backgroundLeft:SetTexture(kHeaderTexture)
    item.backgroundLeft:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsLeft))
    item.backgroundLeft:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundLeft:SetInheritsParentAlpha(false)
    item.backgroundLeft:SetLayer(kGUILayerMainMenu)
    item.backgroundLeft:SetSize(Vector(GUILinearScale(16), kCardSize.y, 0))
    item.backgroundLeft:SetPosition(Vector(-GUILinearScale(16), 0, 0))
    item.background:AddChild(item.backgroundLeft)

    item.backgroundRight = GUIManager:CreateGraphicItem()
    item.backgroundRight:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundRight:SetColor(color)
    item.backgroundRight:SetTexture(kHeaderTexture)
    item.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
    item.backgroundRight:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundRight:SetInheritsParentAlpha(false)
    item.backgroundRight:SetLayer(kGUILayerMainMenu)
    item.backgroundRight:SetSize(Vector(GUILinearScale(16), kCardSize.y, 0))
    item.backgroundRight:SetPosition(Vector(kCardSize.x - GUILinearScale(32), 0, 0))
    item.background:AddChild(item.backgroundRight)

    local xOffset = kLogoOffset

    if logoTexture then
        logoSizeX = GUILinearScale(logoSizeX)
        logoSizeY = GUILinearScale(logoSizeY)

        item.logo = GUIManager:CreateGraphicItem()
        item.logo:SetStencilFunc(GUIItem.NotEqual)
        item.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
        item.logo:SetLayer(kGUILayerMainMenu)
        item.logo:SetIsVisible(true)
        item.logo:SetSize(Vector(logoSizeX, logoSizeY, 0))
        item.logo:SetPosition(Vector(kLogoOffset, -logoSizeY / 2, 0))
        item.logo:SetTexture(logoTexture)
        if logoCoords then
            item.logo:SetTexturePixelCoordinates(GUIUnpackCoords(logoCoords))
        end
        item.background:AddChild(item.logo)

        xOffset = xOffset + logoSizeX + kTeamNameOffset
    else
        xOffset = 0
    end

    item.textShadow = GUIManager:CreateTextItem()
    item.textShadow:SetStencilFunc(GUIItem.NotEqual)
    item.textShadow:SetFontName(kTitleFontName)
    item.textShadow:SetColor(Color(0, 0, 0, 1))
    item.textShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.textShadow)
    item.textShadow:SetAnchor(ConditionalValue(logoTexture, GUIItem.Left, GUIItem.Middle), GUIItem.Top)
    item.textShadow:SetText(text)
    item.textShadow:SetTextAlignmentX(ConditionalValue(logoTexture, GUIItem.Align_Min, GUIItem.Align_Center))
    item.textShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.textShadow:SetPosition(Vector(xOffset + kTextShadowOffset, kCardSize.y / 2 + kTextShadowOffset, 0))
    item.textShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.textShadow)

    item.text = GUIManager:CreateTextItem()
    item.text:SetStencilFunc(GUIItem.NotEqual)
    item.text:SetFontName(kTitleFontName)
    item.text:SetColor(Color(1, 1, 1, 1))
    item.text:SetScale(scaledVector)
    GUIMakeFontScale(item.text)
    item.text:SetAnchor(ConditionalValue(logoTexture, GUIItem.Left, GUIItem.Middle), GUIItem.Top)
    item.text:SetText(text)
    item.text:SetTextAlignmentX(ConditionalValue(logoTexture, GUIItem.Align_Min, GUIItem.Align_Center))
    item.text:SetTextAlignmentY(GUIItem.Align_Center)
    item.text:SetPosition(Vector(xOffset, kCardSize.y / 2, 0))
    item.text:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.text)

    item.tableBackground = GUIManager:CreateGraphicItem()
    item.tableBackground:SetStencilFunc(GUIItem.NotEqual)
    item.tableBackground:SetColor(color)
    item.tableBackground:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
    item.tableBackground:SetPosition(Vector(-(kCardRowSize.x + kRowBorderSize * 2) / 2, -kTableContainerOffset, 0))
    item.tableBackground:SetLayer(kGUILayerMainMenu)
    item.tableBackground:SetSize(Vector(kCardRowSize.x + kRowBorderSize * 2, kRowBorderSize * 2, 0))
    item.background:AddChild(item.tableBackground)

    return item
end

-- ToDo: eal
function GUIGameEndStats:CreateEALGraphicHeader(text, color, logoTexture, logoCoords, logoSizeX, logoSizeY, buyText,
    lostText)
    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(color)
    item.background:SetTexture(kHeaderTexture)
    item.background:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsMiddle))
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetInheritsParentAlpha(false)
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(Vector(kTitleSize.x - GUILinearScale(64), kTitleSize.y + 5, 0))
    self.background:AddChild(item.background)

    item.backgroundLeft = GUIManager:CreateGraphicItem()
    item.backgroundLeft:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundLeft:SetColor(color)
    item.backgroundLeft:SetTexture(kHeaderTexture)
    item.backgroundLeft:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsLeft))
    item.backgroundLeft:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundLeft:SetInheritsParentAlpha(false)
    item.backgroundLeft:SetLayer(kGUILayerMainMenu)
    item.backgroundLeft:SetSize(Vector(GUILinearScale(16), kTitleSize.y + 5, 0))
    item.backgroundLeft:SetPosition(Vector(-GUILinearScale(16), 0, 0))
    item.background:AddChild(item.backgroundLeft)

    item.backgroundRight = GUIManager:CreateGraphicItem()
    item.backgroundRight:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundRight:SetColor(color)
    item.backgroundRight:SetTexture(kHeaderTexture)
    item.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
    item.backgroundRight:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundRight:SetInheritsParentAlpha(false)
    item.backgroundRight:SetLayer(kGUILayerMainMenu)
    item.backgroundRight:SetSize(Vector(GUILinearScale(16), kTitleSize.y + 5, 0))
    item.backgroundRight:SetPosition(Vector(kTitleSize.x - GUILinearScale(64), 0, 0))
    item.background:AddChild(item.backgroundRight)

    local xOffset = kLogoOffset

    if logoTexture then
        logoSizeX = GUILinearScale(logoSizeX)
        logoSizeY = GUILinearScale(logoSizeY)

        item.logo = GUIManager:CreateGraphicItem()
        item.logo:SetStencilFunc(GUIItem.NotEqual)
        item.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
        item.logo:SetLayer(kGUILayerMainMenu)
        item.logo:SetIsVisible(true)
        item.logo:SetSize(Vector(logoSizeX, logoSizeY, 0))
        item.logo:SetPosition(Vector(kLogoOffset, -logoSizeY / 2, 0))
        item.logo:SetTexture(logoTexture)
        if logoCoords then
            item.logo:SetTexturePixelCoordinates(GUIUnpackCoords(logoCoords))
        end
        item.background:AddChild(item.logo)

        xOffset = xOffset + logoSizeX + kTeamNameOffset
    else
        xOffset = 0
    end

    item.textShadow = GUIManager:CreateTextItem()
    item.textShadow:SetStencilFunc(GUIItem.NotEqual)
    item.textShadow:SetFontName(kTitleFontName)
    item.textShadow:SetColor(Color(0, 0, 0, 1))
    item.textShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.textShadow)
    item.textShadow:SetAnchor(ConditionalValue(logoTexture, GUIItem.Left, GUIItem.Middle), GUIItem.Top)
    item.textShadow:SetText(text)
    item.textShadow:SetTextAlignmentX(ConditionalValue(logoTexture, GUIItem.Align_Min, GUIItem.Align_Center))
    item.textShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.textShadow:SetPosition(Vector(xOffset + kTextShadowOffset, (kTitleSize.y + 5) / 2 + kTextShadowOffset, 0))
    item.textShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.textShadow)

    item.text = GUIManager:CreateTextItem()
    item.text:SetStencilFunc(GUIItem.NotEqual)
    item.text:SetFontName(kTitleFontName)
    item.text:SetColor(Color(1, 1, 1, 1))
    item.text:SetScale(scaledVector)
    GUIMakeFontScale(item.text)
    item.text:SetAnchor(ConditionalValue(logoTexture, GUIItem.Left, GUIItem.Middle), GUIItem.Top)
    item.text:SetText(text)
    item.text:SetTextAlignmentX(ConditionalValue(logoTexture, GUIItem.Align_Min, GUIItem.Align_Center))
    item.text:SetTextAlignmentY(GUIItem.Align_Center)
    item.text:SetPosition(Vector(xOffset, (kTitleSize.y + 5) / 2, 0))
    item.text:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.text)

    local ThisPos = 100

    item.textBuyShadow = GUIManager:CreateTextItem()
    item.textBuyShadow:SetStencilFunc(GUIItem.NotEqual)
    item.textBuyShadow:SetFontName(kTitleFontName)
    item.textBuyShadow:SetColor(Color(0, 0, 0, 1))
    -- item.textBuyShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.textBuyShadow, "kAgencyFB", 20)
    item.textBuyShadow:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    item.textBuyShadow:SetText(tostring(buyText))
    item.textBuyShadow:SetTextAlignmentX(GUIItem.Right)
    item.textBuyShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.textBuyShadow:SetPosition(Vector(GUILinearScale(ThisPos - 2.5) + GUILinearScale(20) + kTextShadowOffsetMini,
        GUILinearScale(-17) + kTextShadowOffsetMini, 0))
    item.textBuyShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.textBuyShadow)

    item.textBuy = GUIManager:CreateTextItem()
    item.textBuy:SetStencilFunc(GUIItem.NotEqual)
    item.textBuy:SetFontName(kTitleFontName)
    item.textBuy:SetColor(RGBAtoColor(255, 255, 255, 1))
    -- item.textBuy:SetScale(scaledVector)
    GUIMakeFontScale(item.textBuy, "kAgencyFB", 20)
    item.textBuy:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    item.textBuy:SetTextAlignmentX(GUIItem.Right)
    item.textBuy:SetTextAlignmentY(GUIItem.Align_Center)
    item.textBuy:SetPosition(Vector(GUILinearScale(ThisPos - 2.5) + GUILinearScale(20), GUILinearScale(-17), 0))
    item.textBuy:SetText(tostring(buyText))
    item.textBuy:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.textBuy)

    item.textLostShadow = GUIManager:CreateTextItem()
    item.textLostShadow:SetStencilFunc(GUIItem.NotEqual)
    item.textLostShadow:SetFontName(kTitleFontName)
    item.textLostShadow:SetColor(Color(0, 0, 0, 1))
    -- item.textLostShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.textLostShadow, "kAgencyFB", 20)
    item.textLostShadow:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    item.textLostShadow:SetText(tostring(lostText))
    item.textLostShadow:SetTextAlignmentX(GUIItem.Left)
    item.textLostShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.textLostShadow:SetPosition(Vector(GUILinearScale(ThisPos + 2.5) + GUILinearScale(20) + kTextShadowOffsetMini,
        GUILinearScale(-17) + kTextShadowOffsetMini, 0))
    item.textLostShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.textLostShadow)

    item.textLost = GUIManager:CreateTextItem()
    item.textLost:SetStencilFunc(GUIItem.NotEqual)
    item.textLost:SetFontName(kTitleFontName)
    item.textLost:SetColor(RGBAtoColor(255, 50, 50, 1))
    -- item.textLost:SetScale(scaledVector)
    GUIMakeFontScale(item.textLost, "kAgencyFB", 20)
    item.textLost:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    item.textLost:SetTextAlignmentX(GUIItem.Left)
    item.textLost:SetTextAlignmentY(GUIItem.Align_Center)
    item.textLost:SetPosition(Vector(GUILinearScale(ThisPos + 2.5) + GUILinearScale(20), GUILinearScale(-17), 0))
    item.textLost:SetText(tostring(lostText))
    item.textLost:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.textLost)
    return item
end

local function GetPlayerNameFromId(SteamId)
    for _, message in pairs(finalStatsTable) do
        if tostring(message.steamId) == tostring(SteamId) then
            return message.playerName
        end
    end
    return "Unknown"
end

local function GetPlayerDataFromId(SteamId)
    for _, message in pairs(finalStatsTable) do
        if tostring(message.steamId) == tostring(SteamId) then
            return message
        end
    end
    return nil
end

-- ToDo: eal
local function CreateTssItem(container, dataTable, decimals, Label, Icon, IconVector, ItemNr, toolTip)
    local containerSize = container:GetSize()

    local AvatarSize = 40

    local playerData = {}
    for _, message in pairs(dataTable) do
        local tssItem = {}
        tssItem.playerName = GetPlayerNameFromId(_)
        tssItem.Value = roundNumber(message, decimals)
        tssItem.steamId = _
        table.insert(playerData, tssItem)
    end
    table.sort(playerData, function(a, b)
        return a.Value > b.Value
    end)

    local item = {}
    local StartSpacing = GUILinearScale(150)
    local ColumnSpacing = 200
    if lowResScreen then
        StartSpacing = StartSpacing / 1.2
        ColumnSpacing = ColumnSpacing / 1.2
    end

    local ThisPos = StartSpacing + (GUILinearScale(ColumnSpacing) * ItemNr)

    item.labelTextShadow = GUIManager:CreateTextItem()
    item.labelTextShadow:SetStencilFunc(GUIItem.NotEqual)
    item.labelTextShadow:SetFontName(kSubTitleFontName)
    item.labelTextShadow:SetColor(Color(0, 0, 0, 1))
    GUIMakeFontScale(item.labelTextShadow, "kAgencyFB", 25)
    item.labelTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.labelTextShadow:SetText(Label)
    item.labelTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    item.labelTextShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.labelTextShadow:SetPosition(Vector(ThisPos - 2.5 + GUILinearScale(AvatarSize / 2) + kTextShadowOffsetMini,
        GUILinearScale(17) + GUILinearScale(kTextShadowOffsetMini), 0))
    item.labelTextShadow:SetLayer(kGUILayerMainMenu)
    container:AddChild(item.labelTextShadow)

    item.labelText = GUIManager:CreateTextItem()
    item.labelText:SetStencilFunc(GUIItem.NotEqual)
    item.labelText:SetFontName(kSubTitleFontName)
    item.labelText:SetColor(RGBAtoColor(255, 255, 255, 1))
    GUIMakeFontScale(item.labelText, "kAgencyFB", 25)
    item.labelText:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.labelText:SetTextAlignmentX(GUIItem.Align_Center)
    item.labelText:SetTextAlignmentY(GUIItem.Align_Center)
    item.labelText:SetPosition(Vector(ThisPos - 2.5 + (GUILinearScale(AvatarSize / 2)), GUILinearScale(16), 0))
    item.labelText:SetText(Label)
    item.labelText:SetLayer(kGUILayerMainMenu)
    item.labelText.tooltip = toolTip
    container:AddChild(item.labelText)

    -- Build text string
    local dataText = ""
    local i = 0
    for _, tData in pairs(playerData) do
        if i > 5 then
            break
        end
        if dataText ~= "" then
            dataText = dataText .. string.char(10)
        end
        if Label == "Node Clearer" then
            dataText = dataText .. "(" .. tostring(humanNumber(tData.Value)) .. "/" ..
                           roundNumber(tData.Value / (kHarvesterHealth + kHarvesterArmor), 1) .. "RTs) " ..
                           tData.playerName
        elseif Label == "Resource Eater" then
            dataText = dataText .. "(" .. tostring(humanNumber(tData.Value)) .. "/" ..
                           roundNumber(tData.Value / (kExtractorHealth + kExtractorArmor), 1) .. "RTs) " ..
                           tData.playerName
        else
            dataText = dataText .. "(" .. tostring(humanNumber(tData.Value)) .. ") " .. tData.playerName
        end
        i = i + 1
    end
    item.labelText.tooltip = item.labelText.tooltip .. "\n" .. dataText

    item.avatar = CreateGUIObject("avatar", GUIMenuAvatar, container)
    item.avatar:SetStencilFunc(GUIItem.NotEqual)
    item.avatar:SetAnchor(GUIItem.Left, GUIItem.Top)
    local steamId64 = Shared.ConvertSteamId32To64(tonumber(playerData[1].steamId))
    item.avatar:SetSteamID64(steamId64)
    item.avatar:SetSize(Vector(GUILinearScale(AvatarSize), GUILinearScale(AvatarSize), 0))
    item.avatar:SetPosition(Vector(ThisPos - 2.5, GUILinearScale(26), 0))

    item.avatarFrame = CreateGUIObject("avatarFrame", GUIObject, item.avatar)
    item.avatarFrame:SetStencilFunc(GUIItem.NotEqual)
    item.avatarFrame:SetTexture(kAvatarFrameTexture)
    item.avatarFrame:SetSize(item.avatar:GetSize())
    item.avatarFrame:SetColor(1, 1, 1)
    item.avatarFrame:AlignCenter()

    item.textBuyShadow = GUIManager:CreateTextItem()
    item.textBuyShadow:SetStencilFunc(GUIItem.NotEqual)
    item.textBuyShadow:SetFontName(Fonts.kArial_15)
    item.textBuyShadow:SetColor(Color(0, 0, 0, 1))
    GUIMakeFontScale(item.textBuyShadow, Fonts.kArial_15, 6)
    item.textBuyShadow:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    item.textBuyShadow:SetText(playerData[1].playerName)
    item.textBuyShadow:SetTextAlignmentX(GUIItem.Align_Center)
    item.textBuyShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.textBuyShadow:SetPosition(Vector(ThisPos - 2.5 + (GUILinearScale(AvatarSize / 2)) + kTextShadowOffsetMini,
        -GUILinearScale(13) + GUILinearScale(kTextShadowOffsetMini), 0))
    item.textBuyShadow:SetLayer(kGUILayerMainMenu)
    container:AddChild(item.textBuyShadow)

    item.textBuy = GUIManager:CreateTextItem()
    item.textBuy:SetStencilFunc(GUIItem.NotEqual)
    item.textBuy:SetFontName(Fonts.kArial_15)
    item.textBuy:SetColor(RGBAtoColor(255, 255, 255, 1))
    GUIMakeFontScale(item.textBuy, Fonts.kArial_15, 6)
    item.textBuy:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    item.textBuy:SetTextAlignmentX(GUIItem.Align_Center)
    item.textBuy:SetTextAlignmentY(GUIItem.Align_Center)
    item.textBuy:SetPosition(Vector(ThisPos - 2.5 + (GUILinearScale(AvatarSize / 2)), -GUILinearScale(13), 0))
    item.textBuy:SetText(playerData[1].playerName)
    item.textBuy:SetLayer(kGUILayerMainMenu)
    container:AddChild(item.textBuy)

    -- item.text:SetPosition(Vector(xOffset, (kTitleSize.y+5)/2, 0))
    return item
end

-- ToDo: eal
local function CreateEalIcon(container, buyCount, lostCount, Texture, TextureVector, TextureSize, IconNr, forMarine,
    sTooltip)
    local containerSize = container:GetSize()

    local item = {}
    local StartSpacing = GUILinearScale(200)
    local ColumnSpacing = 100
    if forMarine then
        ColumnSpacing = 100
    end

    if lowResScreen then
        StartSpacing = StartSpacing / 1.35
        ColumnSpacing = ColumnSpacing / 1.35
    end

    item.icon = GUIManager:CreateGraphicItem()
    item.icon:SetStencilFunc(GUIItem.NotEqual)
    item.icon:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.icon:SetLayer(kGUILayerMainMenu)
    item.icon:SetSize(TextureSize)
    item.icon:SetTexture(Texture)
    item.icon.tooltip = tostring(sTooltip)
    if TextureVector then
        item.icon:SetTexturePixelCoordinates(GUIUnpackCoords(TextureVector))
    end

    local ThisPos = StartSpacing + (GUILinearScale(ColumnSpacing) * IconNr)
    item.icon:SetPosition(Vector(ThisPos, GUILinearScale(17), 0))

    container:AddChild(item.icon)

    if buyCount > 0 or lostCount > 0 then
        item.textBuyShadow = GUIManager:CreateTextItem()
        item.textBuyShadow:SetStencilFunc(GUIItem.NotEqual)
        item.textBuyShadow:SetFontName(kTitleFontName)
        item.textBuyShadow:SetColor(Color(0, 0, 0, 1))
        GUIMakeFontScale(item.textBuyShadow, "kAgencyFB", 22)
        item.textBuyShadow:SetAnchor(GUIItem.Left, GUIItem.Bottom)
        item.textBuyShadow:SetText(tostring(buyCount))
        item.textBuyShadow:SetTextAlignmentX(GUIItem.Right)
        item.textBuyShadow:SetTextAlignmentY(GUIItem.Align_Center)
        item.textBuyShadow:SetPosition(Vector(ThisPos - 2.5 + GUILinearScale(item.icon:GetSize().x / 2) +
                                                  kTextShadowOffsetMini, GUILinearScale(-17) + kTextShadowOffsetMini, 0))
        item.textBuyShadow:SetLayer(kGUILayerMainMenu)
        container:AddChild(item.textBuyShadow)

        item.textBuy = GUIManager:CreateTextItem()
        item.textBuy:SetStencilFunc(GUIItem.NotEqual)
        item.textBuy:SetFontName(kTitleFontName)
        item.textBuy:SetColor(RGBAtoColor(255, 255, 255, 1))
        GUIMakeFontScale(item.textBuy, "kAgencyFB", 22)
        item.textBuy:SetAnchor(GUIItem.Left, GUIItem.Bottom)
        item.textBuy:SetTextAlignmentX(GUIItem.Right)
        item.textBuy:SetTextAlignmentY(GUIItem.Align_Center)
        item.textBuy:SetPosition(Vector(ThisPos - 2.5 + GUILinearScale(item.icon:GetSize().x / 2), GUILinearScale(-17),
            0))
        item.textBuy:SetText(tostring(buyCount))
        item.textBuy:SetLayer(kGUILayerMainMenu)
        container:AddChild(item.textBuy)

        item.textLostShadow = GUIManager:CreateTextItem()
        item.textLostShadow:SetStencilFunc(GUIItem.NotEqual)
        item.textLostShadow:SetFontName(kTitleFontName)
        item.textLostShadow:SetColor(Color(0, 0, 0, 1))
        GUIMakeFontScale(item.textLostShadow, "kAgencyFB", 22)
        item.textLostShadow:SetAnchor(GUIItem.Left, GUIItem.Bottom)
        item.textLostShadow:SetText(tostring(lostCount))
        item.textLostShadow:SetTextAlignmentX(GUIItem.Left)
        item.textLostShadow:SetTextAlignmentY(GUIItem.Align_Center)
        item.textLostShadow:SetPosition(Vector(ThisPos + 2.5 + GUILinearScale(item.icon:GetSize().x / 2) +
                                                   kTextShadowOffsetMini, GUILinearScale(-17) + kTextShadowOffsetMini, 0))
        item.textLostShadow:SetLayer(kGUILayerMainMenu)
        container:AddChild(item.textLostShadow)

        item.textLost = GUIManager:CreateTextItem()
        item.textLost:SetStencilFunc(GUIItem.NotEqual)
        item.textLost:SetFontName(kTitleFontName)
        item.textLost:SetColor(RGBAtoColor(255, 50, 50, 1))
        GUIMakeFontScale(item.textLost, "kAgencyFB", 22)
        item.textLost:SetAnchor(GUIItem.Left, GUIItem.Bottom)
        item.textLost:SetTextAlignmentX(GUIItem.Left)
        item.textLost:SetTextAlignmentY(GUIItem.Align_Center)
        item.textLost:SetPosition(Vector(ThisPos + 2.5 + GUILinearScale(item.icon:GetSize().x / 2), GUILinearScale(-17),
            0))
        item.textLost:SetText(tostring(lostCount))
        item.textLost:SetLayer(kGUILayerMainMenu)
        container:AddChild(item.textLost)
    end

    -- item.text:SetPosition(Vector(xOffset, (kTitleSize.y+5)/2, 0))

    return item
end

local function CreateTopPlayerSmallRow(container, bgColor, textColor, PlayerObject, StatName, StatValue)
    local containerSize = container:GetSize()
    container:SetSize(Vector(containerSize.x, containerSize.y + kCardRowSize.y + kCardRowSize.y + kCardRowSize.y, 0))

    local item = {}
    local AvatarSize = 64

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(bgColor)
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetPosition(Vector(kRowBorderSize, containerSize.y - kRowBorderSize, 0))
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(Vector(kCardRowSize.x, kCardRowSize.y + kCardRowSize.y + kCardRowSize.y, 0))

    container:AddChild(item.background)

    -- Code to get avatar...
    item.avatar = CreateGUIObject("avatar", GUIMenuAvatar, item.background)
    item.avatar:SetStencilFunc(GUIItem.NotEqual)
    item.avatar:SetAnchor(GUIItem.Left, GUIItem.Top)
    local steamId64 = Shared.ConvertSteamId32To64(PlayerObject.steamId)
    item.avatar:SetSteamID64(steamId64)
    item.avatar:SetSize(Vector(GUILinearScale(AvatarSize), GUILinearScale(AvatarSize), 0))
    item.avatar:SetPosition(Vector(kLogoOffset, kLogoOffset, 0))

    item.avatarFrame = CreateGUIObject("avatarFrame", GUIObject, item.avatar)
    item.avatarFrame:SetStencilFunc(GUIItem.NotEqual)
    item.avatarFrame:SetTexture(kAvatarFrameTexture)
    item.avatarFrame:SetSize(item.avatar:GetSize())
    item.avatarFrame:SetColor(1, 1, 1)
    item.avatarFrame:AlignCenter()

    item.playerText = GUIManager:CreateTextItem()
    item.playerText:SetStencilFunc(GUIItem.NotEqual)
    item.playerText:SetFontName(kTitleFontName)
    item.playerText:SetColor(textColor)
    item.playerText:SetScale(scaledVector)
    GUIMakeFontScale(item.playerText)
    item.playerText:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.playerText:SetTextAlignmentY(GUIItem.Align_Center)
    item.playerText:SetPosition(Vector(GUILinearScale(73), GUILinearScale(17), 0))
    item.playerText:SetText(PlayerObject.playerName or "[Unkown]")
    item.playerText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.playerText)

    item.leftText = GUIManager:CreateTextItem()
    item.leftText:SetStencilFunc(GUIItem.NotEqual)
    item.leftText:SetFontName(kRowFontName)
    item.leftText:SetColor(textColor)
    item.leftText:SetScale(scaledVector)
    GUIMakeFontScale(item.leftText)
    item.leftText:SetAnchor(GUIItem.Left, GUIItem.Align_Max)
    item.leftText:SetTextAlignmentY(GUIItem.Align_Center)
    item.leftText:SetPosition(Vector(GUILinearScale(73), -14, 0))
    item.leftText:SetText(StatName or "")
    item.leftText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.leftText)

    item.rightText = GUIManager:CreateTextItem()
    item.rightText:SetStencilFunc(GUIItem.NotEqual)
    item.rightText:SetFontName(kRowFontName)
    item.rightText:SetColor(textColor)
    item.rightText:SetScale(scaledVector)
    GUIMakeFontScale(item.rightText)
    item.rightText:SetAnchor(GUIItem.Right, GUIItem.Align_Max)
    item.rightText:SetTextAlignmentX(GUIItem.Align_Max)
    item.rightText:SetTextAlignmentY(GUIItem.Align_Center)
    item.rightText:SetPosition(Vector(-GUILinearScale(5), -14, 0))
    item.rightText:SetText(StatValue or "")
    item.rightText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.rightText)

    return item
end

local function CreateTopPlayerMainRow(container, bgColor, textColor, PlayerObject, StatName, StatValue)
    local containerSize = container:GetSize()
    container:SetSize(Vector(containerSize.x, containerSize.y + (kCardRowSize.y * 8), 0))

    local item = {}
    local AvatarSize = 132

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(bgColor)
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetPosition(Vector(kRowBorderSize, containerSize.y - kRowBorderSize, 0))
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(Vector(kCardRowSize.x,
        containerSize.y + (kCardRowSize.y * 8) - kRowBorderSize - kRowBorderSize, 0))

    container:AddChild(item.background)

    -- Code to get avatar...
    item.avatar = CreateGUIObject("avatar", GUIMenuAvatar, item.background)
    item.avatar:SetStencilFunc(GUIItem.NotEqual)
    item.avatar:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.avatar:SetLayer(kGUILayerMainMenu)
    local steamId64 = Shared.ConvertSteamId32To64(PlayerObject.steamId)
    item.avatar:SetSteamID64(steamId64)
    item.avatar:SetSize(Vector(GUILinearScale(AvatarSize), GUILinearScale(AvatarSize), 0))
    item.avatar:SetPosition(Vector(((kCardRowSize.x / 2) - (GUILinearScale(AvatarSize) / 2)), kLogoOffset, 0))

    item.avatarFrame = CreateGUIObject("avatarFrame", GUIObject, item.avatar)
    item.avatarFrame:SetStencilFunc(GUIItem.NotEqual)
    item.avatarFrame:SetLayer(kGUILayerMainMenu)
    item.avatarFrame:SetTexture(kAvatarFrameTexture)
    item.avatarFrame:SetSize(item.avatar:GetSize())
    item.avatarFrame:SetColor(1, 1, 1)
    item.avatarFrame:AlignCenter()

    item.playerText = GUIManager:CreateTextItem()
    item.playerText:SetStencilFunc(GUIItem.NotEqual)
    item.playerText:SetFontName(kTitleFontName)
    item.playerText:SetColor(textColor)
    item.playerText:SetScale(scaledVector)
    GUIMakeFontScale(item.playerText)
    item.playerText:SetAnchor(GUIItem.Left, GUIItem.Align_Max)
    item.playerText:SetTextAlignmentY(GUIItem.Align_Center)
    item.playerText:SetTextAlignmentX(GUIItem.Align_Center)
    item.playerText:SetPosition(Vector(containerSize.x / 2, GUILinearScale(-33), 0))
    item.playerText:SetText(PlayerObject.playerName or "[Unkown]")
    item.playerText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.playerText)

    item.leftText = GUIManager:CreateTextItem()
    item.leftText:SetStencilFunc(GUIItem.NotEqual)
    item.leftText:SetFontName(kRowFontName)
    item.leftText:SetColor(textColor)
    item.leftText:SetScale(scaledVector)
    GUIMakeFontScale(item.leftText)
    item.leftText:SetAnchor(GUIItem.Left, GUIItem.Align_Max)
    item.leftText:SetTextAlignmentY(GUIItem.Align_Center)
    item.leftText:SetPosition(Vector(GUILinearScale(5), -14, 0))
    item.leftText:SetText(StatName or "")
    item.leftText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.leftText)

    item.rightText = GUIManager:CreateTextItem()
    item.rightText:SetStencilFunc(GUIItem.NotEqual)
    item.rightText:SetFontName(kRowFontName)
    item.rightText:SetColor(textColor)
    item.rightText:SetScale(scaledVector)
    GUIMakeFontScale(item.rightText)
    item.rightText:SetAnchor(GUIItem.Right, GUIItem.Align_Max)
    item.rightText:SetTextAlignmentX(GUIItem.Align_Max)
    item.rightText:SetTextAlignmentY(GUIItem.Align_Center)
    item.rightText:SetPosition(Vector(-GUILinearScale(5), -14, 0))
    item.rightText:SetText(StatValue or "")
    item.rightText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.rightText)

    return item
end

local function CreateHeaderRow(container, bgColor, textColor, leftText, rightText)
    local containerSize = container:GetSize()
    container:SetSize(Vector(containerSize.x, containerSize.y + kCardRowSize.y, 0))

    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(bgColor)
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetPosition(Vector(kRowBorderSize, containerSize.y - kRowBorderSize, 0))
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(kCardRowSize)

    container:AddChild(item.background)

    item.leftText = GUIManager:CreateTextItem()
    item.leftText:SetStencilFunc(GUIItem.NotEqual)
    item.leftText:SetFontName(kRowFontName)
    item.leftText:SetColor(textColor)
    item.leftText:SetScale(scaledVector)
    GUIMakeFontScale(item.leftText)
    item.leftText:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.leftText:SetTextAlignmentY(GUIItem.Align_Center)
    item.leftText:SetPosition(Vector(GUILinearScale(5), 0, 0))
    item.leftText:SetText(leftText or "")
    item.leftText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.leftText)

    item.rightText = GUIManager:CreateTextItem()
    item.rightText:SetStencilFunc(GUIItem.NotEqual)
    item.rightText:SetFontName(kRowFontName)
    item.rightText:SetColor(textColor)
    item.rightText:SetScale(scaledVector)
    GUIMakeFontScale(item.rightText)
    item.rightText:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.rightText:SetTextAlignmentX(GUIItem.Align_Max)
    item.rightText:SetTextAlignmentY(GUIItem.Align_Center)
    item.rightText:SetPosition(Vector(-GUILinearScale(5), 0, 0))
    item.rightText:SetText(rightText or "")
    item.rightText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.rightText)

    return item
end

function GUIGameEndStats:CreateTechLogHeader(teamNumber, teamName)
    local item = {}

    local color = kMarineStatsColor
    local teamLogo = kMarineStatsLogo
    local commander = nil

    if teamNumber == 2 then
        color = kAlienStatsColor
        teamLogo = kAlienStatsLogo
        commander = DIPS_AlienCommID and playerStatMap[teamNumber][DIPS_AlienCommID] or nil
    else
        commander = DIPS_MarineCommID and playerStatMap[teamNumber][DIPS_MarineCommID] or nil
    end

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(color)
    item.background:SetTexture(kHeaderTexture)
    item.background:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsMiddle))
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetInheritsParentAlpha(false)
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(Vector(kTechLogTitleSize.x - GUILinearScale(32), kTechLogTitleSize.y, 0))
    self.background:AddChild(item.background)

    item.backgroundLeft = GUIManager:CreateGraphicItem()
    item.backgroundLeft:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundLeft:SetColor(color)
    item.backgroundLeft:SetTexture(kHeaderTexture)
    item.backgroundLeft:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsLeft))
    item.backgroundLeft:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundLeft:SetInheritsParentAlpha(false)
    item.backgroundLeft:SetLayer(kGUILayerMainMenu)
    item.backgroundLeft:SetSize(Vector(GUILinearScale(16), kTechLogTitleSize.y, 0))
    item.backgroundLeft:SetPosition(Vector(-GUILinearScale(16), 0, 0))
    item.background:AddChild(item.backgroundLeft)

    item.backgroundRight = GUIManager:CreateGraphicItem()
    item.backgroundRight:SetStencilFunc(GUIItem.NotEqual)
    item.backgroundRight:SetColor(color)
    item.backgroundRight:SetTexture(kHeaderTexture)
    item.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
    item.backgroundRight:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.backgroundRight:SetInheritsParentAlpha(false)
    item.backgroundRight:SetLayer(kGUILayerMainMenu)
    item.backgroundRight:SetSize(Vector(GUILinearScale(16), kTechLogTitleSize.y, 0))
    item.backgroundRight:SetPosition(Vector(kTechLogTitleSize.x - GUILinearScale(32), 0, 0))
    item.background:AddChild(item.backgroundRight)

    item.logo = GUIManager:CreateGraphicItem()
    item.logo:SetStencilFunc(GUIItem.NotEqual)
    item.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.logo:SetLayer(kGUILayerMainMenu)
    item.logo:SetIsVisible(true)
    item.logo:SetSize(kLogoSize)
    item.logo:SetPosition(Vector(kLogoOffset, -kLogoSize.y / 2, 0))
    item.logo:SetTexture(teamLogo)
    item.background:AddChild(item.logo)

    item.teamNameTextShadow = GUIManager:CreateTextItem()
    item.teamNameTextShadow:SetStencilFunc(GUIItem.NotEqual)
    item.teamNameTextShadow:SetFontName(kTitleFontName)
    item.teamNameTextShadow:SetColor(Color(0, 0, 0, 1))
    item.teamNameTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.teamNameTextShadow)
    item.teamNameTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.teamNameTextShadow:SetText(teamName)
    item.teamNameTextShadow:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamNameTextShadow:SetPosition(Vector(kLogoSize.x + kTeamNameOffset + kTextShadowOffset,
        kTechLogTitleSize.y / 2 + kTextShadowOffset, 0))
    item.teamNameTextShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamNameTextShadow)

    item.teamNameText = GUIManager:CreateTextItem()
    item.teamNameText:SetStencilFunc(GUIItem.NotEqual)
    item.teamNameText:SetFontName(kTitleFontName)
    item.teamNameText:SetColor(Color(1, 1, 1, 1))
    item.teamNameText:SetScale(scaledVector)
    GUIMakeFontScale(item.teamNameText)
    item.teamNameText:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.teamNameText:SetText(teamName)
    item.teamNameText:SetTextAlignmentY(GUIItem.Align_Center)
    item.teamNameText:SetPosition(Vector(kLogoSize.x + kTeamNameOffset, kTechLogTitleSize.y / 2, 0))
    item.teamNameText:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.teamNameText)

    if DIPS_EnahncedStats and commander then
        item.commBadge = GUIManager:CreateGraphicItem()
        item.commBadge:SetStencilFunc(GUIItem.NotEqual)
        item.commBadge:SetAnchor(GUIItem.Right, GUIItem.Center)
        item.commBadge:SetLayer(kGUILayerMainMenu)
        item.commBadge:SetIsVisible(true)
        item.commBadge:SetSize(Vector(100 * 0.7, 52 * 0.7, 0))
        item.commBadge:SetPosition(Vector(-(100 * 0.7), -((52 * 0.7) / 2), 0))
        item.commBadge:SetTexture(kCommSkillIconTexture) -- todo: com
        local skillTier, skillTierName = GetPlayerSkillTier((teamNumber == 2 and commander.commanderSkillAlien or
                                                                commander.commanderSkillMarine), isRookie)
        if skillTier > 0 then
            item.commBadge:SetTexturePixelCoordinates(0, (skillTier + 2) * 32, 52, 32 * (skillTier + 3))
        else
            item.commBadge:SetTexturePixelCoordinates(0, 0, 100, 31)
        end
        item.commBadge.tooltip = string.format(Locale.ResolveString("SKILLTIER_TOOLTIP"),
            Locale.ResolveString(skillTierName), skillTier)
        table.insert(self.toolTipCards, item.commBadge)
        item.background:AddChild(item.commBadge)

        item.commNameTextShadow = GUIManager:CreateTextItem()
        item.commNameTextShadow:SetStencilFunc(GUIItem.NotEqual)
        item.commNameTextShadow:SetFontName(kTitleFontName)
        item.commNameTextShadow:SetColor(Color(0, 0, 0, 1))
        item.commNameTextShadow:SetScale(scaledVector)
        GUIMakeFontScale(item.commNameTextShadow)
        item.commNameTextShadow:SetAnchor(GUIItem.Right, GUIItem.Top)
        item.commNameTextShadow:SetText(commander.playerName)
        item.commNameTextShadow:SetTextAlignmentY(GUIItem.Align_Center)
        item.commNameTextShadow:SetTextAlignmentX(GUIItem.Align_Max)
        item.commNameTextShadow:SetPosition(Vector(-(kLogoSize.x + kTeamNameOffset + kTextShadowOffset),
            kTechLogTitleSize.y / 2 + kTextShadowOffset, 0))
        item.commNameTextShadow:SetLayer(kGUILayerMainMenu)
        item.background:AddChild(item.commNameTextShadow)

        item.commNameText = GUIManager:CreateTextItem()
        item.commNameText:SetStencilFunc(GUIItem.NotEqual)
        item.commNameText:SetFontName(kTitleFontName)
        item.commNameText:SetColor(Color(1, 1, 1, 1))
        item.commNameText:SetScale(scaledVector)
        GUIMakeFontScale(item.commNameText)
        item.commNameText:SetAnchor(GUIItem.Right, GUIItem.Top)
        item.commNameText:SetText(commander.playerName)
        item.commNameText:SetTextAlignmentY(GUIItem.Align_Center)
        item.commNameText:SetTextAlignmentX(GUIItem.Align_Max)
        item.commNameText:SetPosition(Vector(-(kLogoSize.x + kTeamNameOffset), kTechLogTitleSize.y / 2, 0))
        item.commNameText:SetLayer(kGUILayerMainMenu)
        item.background:AddChild(item.commNameText)
    end

    item.tableBackground = GUIManager:CreateGraphicItem()
    item.tableBackground:SetStencilFunc(GUIItem.NotEqual)
    item.tableBackground:SetColor(color)
    item.tableBackground:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
    item.tableBackground:SetPosition(Vector(-(kTechLogRowSize.x + kRowBorderSize * 2) / 2, -kTableContainerOffset, 0))
    item.tableBackground:SetLayer(kGUILayerMainMenu)
    item.tableBackground:SetSize(Vector(kTechLogRowSize.x + kRowBorderSize * 2, kRowBorderSize * 2, 0))
    item.background:AddChild(item.tableBackground)

    return item
end

-- ToDo: Kill graph icon
local function CreateKillGraphIcon(container, possition, techTable)
    local item = {}
    local offset = 0
    local team = 1
    item.logo = GUIManager:CreateGraphicItem()
    item.logo:SetStencilFunc(GUIItem.NotEqual)
    if team == 1 then
        item.logo:SetAnchor(GUIItem.Left, GUIItem.Top)
        offset = -5
    else
        item.logo:SetAnchor(GUIItem.Left, GUIItem.Bottom)
        offset = 5
    end
    item.logo:SetLayer(kGUILayerMainMenu)
    item.logo:SetIsVisible(true)
    item.logo:SetSize(Vector(24, 24, 0))
    item.logo:SetPosition(Vector(24, 24, 0))
    -- item.logo:SetColor(logoColor)
    item.logo:SetTexture(techTable.iconTexture)
    item.logo:SetTexturePixelCoordinates(GUIUnpackCoords(techTable.iconCoords))
    item.logo.tooltip = techTable.name
    -- item.logo:GiveParent(container)
    table.insert(self.toolTipCards, item.logo)
    return item.logo
end

local function CreateTechLogRow(container, bgColor, textColor, timeBuilt, techName, activeRTs, numRes, logoTexture,
    logoCoords, logoSizeX, logoSizeY, logoColor)
    local containerSize = container:GetSize()
    container:SetSize(Vector(containerSize.x, containerSize.y + kTechLogRowSize.y, 0))

    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(bgColor)
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetPosition(Vector(kRowBorderSize, containerSize.y - kRowBorderSize, 0))
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(kTechLogRowSize)

    container:AddChild(item.background)

    local xOffset = GUILinearScale(10)

    if timeBuilt ~= "" then
        item.timeBuilt = GUIManager:CreateTextItem()
        item.timeBuilt:SetStencilFunc(GUIItem.NotEqual)
        item.timeBuilt:SetFontName(kRowFontName)
        item.timeBuilt:SetColor(textColor)
        item.timeBuilt:SetScale(scaledVector)
        GUIMakeFontScale(item.timeBuilt)
        item.timeBuilt:SetAnchor(GUIItem.Left, GUIItem.Center)
        item.timeBuilt:SetTextAlignmentX(GUIItem.Align_Center)
        item.timeBuilt:SetTextAlignmentY(GUIItem.Align_Center)
        item.timeBuilt:SetPosition(Vector(GUILinearScale(30), 0, 0))
        item.timeBuilt:SetText(timeBuilt or "")
        item.timeBuilt:SetLayer(kGUILayerMainMenu)
        item.background:AddChild(item.timeBuilt)

        xOffset = GUILinearScale(70)
    end

    if logoTexture then
        logoSizeX = GUILinearScale(logoSizeX)
        logoSizeY = GUILinearScale(logoSizeY)

        item.logo = GUIManager:CreateGraphicItem()
        item.logo:SetStencilFunc(GUIItem.NotEqual)
        item.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
        item.logo:SetLayer(kGUILayerMainMenu)
        item.logo:SetIsVisible(true)
        item.logo:SetSize(Vector(logoSizeX, logoSizeY, 0))
        item.logo:SetPosition(Vector(xOffset, -logoSizeY / 2, 0))
        item.logo:SetColor(logoColor)
        item.logo:SetTexture(logoTexture)
        if logoCoords then
            item.logo:SetTexturePixelCoordinates(GUIUnpackCoords(logoCoords))
        end
        item.background:AddChild(item.logo)

        xOffset = xOffset + logoSizeX + GUILinearScale(5)
    end

    item.techName = GUIManager:CreateTextItem()
    item.techName:SetStencilFunc(GUIItem.NotEqual)
    item.techName:SetFontName(kRowFontName)
    item.techName:SetColor(textColor)
    item.techName:SetScale(scaledVector)
    GUIMakeFontScale(item.techName)
    item.techName:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.techName:SetTextAlignmentY(GUIItem.Align_Center)
    item.techName:SetPosition(Vector(xOffset, 0, 0))
    item.techName:SetText(techName or "")
    item.techName:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.techName)

    item.activeRTs = GUIManager:CreateTextItem()
    item.activeRTs:SetStencilFunc(GUIItem.NotEqual)
    item.activeRTs:SetFontName(kRowFontName)
    item.activeRTs:SetColor(textColor)
    item.activeRTs:SetScale(scaledVector)
    GUIMakeFontScale(item.activeRTs)
    item.activeRTs:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.activeRTs:SetTextAlignmentX(GUIItem.Align_Center)
    item.activeRTs:SetTextAlignmentY(GUIItem.Align_Center)
    item.activeRTs:SetPosition(Vector(GUILinearScale(-80), 0, 0))
    item.activeRTs:SetText(tostring(activeRTs) or "")
    item.activeRTs:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.activeRTs)

    item.numRes = GUIManager:CreateTextItem()
    item.numRes:SetStencilFunc(GUIItem.NotEqual)
    item.numRes:SetFontName(kRowFontName)
    item.numRes:SetColor(textColor)
    item.numRes:SetScale(scaledVector)
    GUIMakeFontScale(item.numRes)
    item.numRes:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.numRes:SetTextAlignmentX(GUIItem.Align_Center)
    item.numRes:SetTextAlignmentY(GUIItem.Align_Center)
    item.numRes:SetPosition(Vector(GUILinearScale(-30), 0, 0))
    item.numRes:SetText(tostring(numRes) or "")
    item.numRes:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.numRes)

    return item
end

local function CreateCommStatsRow(container, bgColor, textColor, techName, accuracy, efficiency, refill, used, wasted,
    logoTexture, logoCoords, logoSizeX, logoSizeY, logoColor)
    local containerSize = container:GetSize()
    container:SetSize(Vector(containerSize.x, containerSize.y + kTechLogRowSize.y, 0))

    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetColor(bgColor)
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetPosition(Vector(kRowBorderSize, containerSize.y - kRowBorderSize, 0))
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(kTechLogRowSize)

    container:AddChild(item.background)

    local xOffset = GUILinearScale(10)

    if logoTexture then
        logoSizeX = GUILinearScale(logoSizeX)
        logoSizeY = GUILinearScale(logoSizeY)

        item.logo = GUIManager:CreateGraphicItem()
        item.logo:SetStencilFunc(GUIItem.NotEqual)
        item.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
        item.logo:SetLayer(kGUILayerMainMenu)
        item.logo:SetIsVisible(true)
        item.logo:SetSize(Vector(logoSizeX, logoSizeY, 0))
        item.logo:SetPosition(Vector(xOffset, -logoSizeY / 2, 0))
        item.logo:SetColor(logoColor)
        item.logo:SetTexture(logoTexture)
        if logoCoords then
            item.logo:SetTexturePixelCoordinates(GUIUnpackCoords(logoCoords))
        end
        item.background:AddChild(item.logo)

        xOffset = xOffset + logoSizeX + GUILinearScale(5)
    end

    item.techName = GUIManager:CreateTextItem()
    item.techName:SetStencilFunc(GUIItem.NotEqual)
    item.techName:SetFontName(kRowFontName)
    item.techName:SetColor(textColor)
    item.techName:SetScale(scaledVector)
    GUIMakeFontScale(item.techName)
    item.techName:SetAnchor(GUIItem.Left, GUIItem.Center)
    item.techName:SetTextAlignmentY(GUIItem.Align_Center)
    item.techName:SetPosition(Vector(xOffset, 0, 0))
    item.techName:SetText(techName or "")
    item.techName:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.techName)

    item.accuracy = GUIManager:CreateTextItem()
    item.accuracy:SetStencilFunc(GUIItem.NotEqual)
    item.accuracy:SetFontName(kRowFontName)
    item.accuracy:SetColor(textColor)
    item.accuracy:SetScale(scaledVector)
    GUIMakeFontScale(item.accuracy)
    item.accuracy:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.accuracy:SetTextAlignmentX(GUIItem.Align_Center)
    item.accuracy:SetTextAlignmentY(GUIItem.Align_Center)
    item.accuracy:SetPosition(Vector(GUILinearScale(-250), 0, 0))
    item.accuracy:SetText(tostring(accuracy) or "")
    item.accuracy:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.accuracy)

    item.efficiency = GUIManager:CreateTextItem()
    item.efficiency:SetStencilFunc(GUIItem.NotEqual)
    item.efficiency:SetFontName(kRowFontName)
    item.efficiency:SetColor(textColor)
    item.efficiency:SetScale(scaledVector)
    GUIMakeFontScale(item.efficiency)
    item.efficiency:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.efficiency:SetTextAlignmentX(GUIItem.Align_Center)
    item.efficiency:SetTextAlignmentY(GUIItem.Align_Center)
    item.efficiency:SetPosition(Vector(GUILinearScale(-130), 0, 0))
    item.efficiency:SetText(tostring(efficiency) or "")
    item.efficiency:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.efficiency)

    item.refill = GUIManager:CreateTextItem()
    item.refill:SetStencilFunc(GUIItem.NotEqual)
    item.refill:SetFontName(kRowFontName)
    item.refill:SetColor(textColor)
    item.refill:SetScale(scaledVector)
    GUIMakeFontScale(item.refill)
    item.refill:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.refill:SetTextAlignmentX(GUIItem.Align_Center)
    item.refill:SetTextAlignmentY(GUIItem.Align_Center)
    item.refill:SetPosition(Vector(GUILinearScale(-190), 0, 0))
    item.refill:SetText(tostring(refill) or "")
    item.refill:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.refill)

    item.used = GUIManager:CreateTextItem()
    item.used:SetStencilFunc(GUIItem.NotEqual)
    item.used:SetFontName(kRowFontName)
    item.used:SetColor(textColor)
    item.used:SetScale(scaledVector)
    GUIMakeFontScale(item.used)
    item.used:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.used:SetTextAlignmentX(GUIItem.Align_Center)
    item.used:SetTextAlignmentY(GUIItem.Align_Center)
    item.used:SetPosition(Vector(GUILinearScale(-80), 0, 0))
    item.used:SetText(tostring(used) or "")
    item.used:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.used)

    item.wasted = GUIManager:CreateTextItem()
    item.wasted:SetStencilFunc(GUIItem.NotEqual)
    item.wasted:SetFontName(kRowFontName)
    item.wasted:SetColor(textColor)
    item.wasted:SetScale(scaledVector)
    GUIMakeFontScale(item.wasted)
    item.wasted:SetAnchor(GUIItem.Right, GUIItem.Center)
    item.wasted:SetTextAlignmentX(GUIItem.Align_Center)
    item.wasted:SetTextAlignmentY(GUIItem.Align_Center)
    item.wasted:SetPosition(Vector(GUILinearScale(-30), 0, 0))
    item.wasted:SetText(tostring(wasted) or "")
    item.wasted:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.wasted)

    return item
end

function GUIGameEndStats:SetPlayerCount(teamItem, playerCount)
    if playerCount and IsNumber(playerCount) then
        local playerString = string.format("%d %s", playerCount, ConditionalValue(playerCount == 1,
            Locale.ResolveString("PLAYER"), Locale.ResolveString("PLAYERS")))
        teamItem.teamPlayerCountShadow:SetText(playerString)
        teamItem.teamPlayerCount:SetText(playerString)
    else
        teamItem.teamPlayerCountShadow:SetText("")
        teamItem.teamPlayerCount:SetText("")
    end
end

function GUIGameEndStats:SetGameResult(teamItem, result)
    teamItem.teamGameStatusShadow:SetText(result)
    teamItem.teamGameStatus:SetText(result)
end

function GUIGameEndStats:SetTeamName(teamItem, teamName)
    if teamName == nil then
        teamName = ""
    end
    teamItem.teamNameTextShadow:SetText(teamName)
    teamItem.teamNameText:SetText(teamName)
end

function GUIGameEndStats:LoadLastRoundStats()
    if not loadedLastRound and GetFileExists(lastRoundFile) then
        local openedFile = io.open(lastRoundFile, "r")
        if openedFile then
            local parsedFile = json.decode(openedFile:read("*all"))
            io.close(openedFile)

            if parsedFile then
                finalStatsTable = parsedFile.finalStatsTable or {}
                avgAccTable = parsedFile.avgAccTable or {}
                miscDataTable = parsedFile.miscDataTable or {}
                cardsTable = parsedFile.cardsTable or {}
                hiveSkillGraphTable = parsedFile.hiveSkillGraphTable or {}
                rtGraphTable = parsedFile.rtGraphTable or {}
                commanderStats = parsedFile.commanderStats or nil
                techLogTable = parsedFile.techLogTable or {}
                killGraphTable = parsedFile.killGraphTable or {}
                equipmentAndLifeformsLogTable = parsedFile.equipmentAndLifeformsLogTable or {}
                teamSpecificStatsLogTable = parsedFile.teamSpecificStatsLogTable or {}
                buildingSummaryTable = parsedFile.buildingSummaryTable or {}
                statusSummaryTable = parsedFile.statusSummaryTable or {}

                presGraphTableMarines = parsedFile.presGraphTableMarines or {}
                presGraphTableAliens = parsedFile.presGraphTableAliens or {}

                if #hiveSkillGraphTable == 0 then
                    estimateHiveSkillGraph()
                end

                local vanillaStats = true
                --  Dirty hack, 209 are Drifters in vanilla, and Skulks in balance mod. A skulk has to die in the game for it to work..
                for i, v in pairs(equipmentAndLifeformsLogTable) do
                    if v.techId == 209 then
                        vanillaStats = false
                    end
                end

                local balanceServer = false
                -- Max tech id is 447 in vanilla, 469 in balance mod
                if kTechId.Max == 469 then
                    balanceServer = true
                end

                -- convert vanilla techIds into balancemod techIds
                if balanceServer and vanillaStats then
                    for i, v in pairs(equipmentAndLifeformsLogTable) do
                        if v.techId > kTechId.JetpackTech and v.techId <= kTechId.DeathTrigger then
                            v.techId = v.techId - 1
                        elseif v.techId == ExosuitTech then
                            v.techId = 448
                        end
                    end
                end

                -- convert balance techIds into vanilla techIds
                if not balanceServer and not vanillaStats then
                    for i, v in pairs(equipmentAndLifeformsLogTable) do
                        if v.techId > kTechId.JetpackTech and v.techId <= kTechId.DeathTrigger then
                            v.techId = v.techId + 1
                        elseif v.techId == ExosuitTech then
                            v.techId = 142
                        end
                    end
                end
            end

            self.saved = true
            loadedLastRound = true
        end
    end
end

function GUIGameEndStats:SaveLastRoundStats()
    if not self.saved then
        local savedStats = {}
        savedStats.finalStatsTable = finalStatsTable
        savedStats.avgAccTable = avgAccTable
        savedStats.miscDataTable = miscDataTable
        savedStats.cardsTable = cardsTable
        savedStats.hiveSkillGraphTable = hiveSkillGraphTable
        savedStats.rtGraphTable = rtGraphTable
        savedStats.commanderStats = commanderStats
        savedStats.killGraphTable = killGraphTable
        savedStats.equipmentAndLifeformsLogTable = equipmentAndLifeformsLogTable
        savedStats.teamSpecificStatsLogTable = teamSpecificStatsLogTable
        savedStats.buildingSummaryTable = buildingSummaryTable
        savedStats.statusSummaryTable = statusSummaryTable
        savedStats.techLogTable = techLogTable

        savedStats.presGraphTableMarines = presGraphTableMarines
        savedStats.presGraphTableAliens = presGraphTableAliens

        local savedFile = io.open(lastRoundFile, "w+")
        if savedFile then
            savedFile:write(json.encode(savedStats, {
                indent = true
            }))
            io.close(savedFile)
        end
        self.saved = true
    end
end

function GUIGameEndStats:Initialize()
    UpdateSizeOfUI(self)

    self.header = GUIManager:CreateGraphicItem()
    self.header:SetColor(Color(0, 0, 0, 0.5))
    self.header:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.header:SetSize(kTitleSize)
    self.header:SetPosition(Vector(-kTitleSize.x / 2, kTopOffset, 0))
    self.header:SetLayer(kGUILayerMainMenu)

    self.closeButton = GUIManager:CreateGraphicItem()
    self.closeButton:SetAnchor(GUIItem.Right, GUIItem.Top)
    self.closeButton:SetSize(kCloseButtonSize)
    self.closeButton:SetPosition(Vector(GUILinearScale(8), 0, 0))
    self.closeButton:SetLayer(kGUILayerMainMenu)
    self.header:AddChild(self.closeButton)

    self.closeText = GUIManager:CreateTextItem()
    self.closeText:SetColor(Color(1, 1, 1, 1))
    self.closeText:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.closeText:SetText("X")
    self.closeText:SetScale(scaledVector)
    self.closeText:SetFontName(kSubTitleFontName)
    GUIMakeFontScale(self.closeText)
    self.closeText:SetTextAlignmentX(GUIItem.Align_Center)
    self.closeText:SetTextAlignmentY(GUIItem.Align_Center)
    self.closeText:SetPosition(Vector(0, GUILinearScale(2), 0))
    self.closeText:SetLayer(kGUILayerMainMenu)
    self.closeButton:AddChild(self.closeText)

    self.roundDate = GUIManager:CreateTextItem()
    self.roundDate:SetFontName(kSubTitleFontName)
    self.roundDate:SetColor(Color(1, 1, 1, 1))
    self.roundDate:SetScale(scaledVector)
    GUIMakeFontScale(self.roundDate)
    self.roundDate:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.roundDate:SetPosition(Vector(GUILinearScale(10), GUILinearScale(4), 0))
    self.roundDate:SetLayer(kGUILayerMainMenu)
    self.header:AddChild(self.roundDate)

    self.serverName = GUIManager:CreateTextItem()
    self.serverName:SetFontName(kSubTitleFontName)
    self.serverName:SetColor(Color(1, 1, 1, 1))
    self.serverName:SetScale(scaledVector)
    GUIMakeFontScale(self.serverName)
    self.serverName:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    self.serverName:SetPosition(Vector(GUILinearScale(10), GUILinearScale(-4), 0))
    self.serverName:SetTextAlignmentY(GUIItem.Align_Max)
    self.serverName:SetLayer(kGUILayerMainMenu)
    self.header:AddChild(self.serverName)

    self.gameLength = GUIManager:CreateTextItem()
    self.gameLength:SetFontName(kSubTitleFontName)
    self.gameLength:SetColor(Color(1, 1, 1, 1))
    self.gameLength:SetScale(scaledVector)
    GUIMakeFontScale(self.gameLength)
    self.gameLength:SetAnchor(GUIItem.Right, GUIItem.Top)
    self.gameLength:SetPosition(Vector(GUILinearScale(-10), GUILinearScale(4), 0))
    self.gameLength:SetTextAlignmentX(GUIItem.Align_Max)
    self.gameLength:SetLayer(kGUILayerMainMenu)
    self.header:AddChild(self.gameLength)

    self.mapName = GUIManager:CreateTextItem()
    self.mapName:SetFontName(kSubTitleFontName)
    self.mapName:SetColor(Color(1, 1, 1, 1))
    self.mapName:SetScale(scaledVector)
    GUIMakeFontScale(self.mapName)
    self.mapName:SetAnchor(GUIItem.Right, GUIItem.Bottom)
    self.mapName:SetPosition(Vector(GUILinearScale(-10), GUILinearScale(-4), 0))
    self.mapName:SetTextAlignmentX(GUIItem.Align_Max)
    self.mapName:SetTextAlignmentY(GUIItem.Align_Max)
    self.mapName:SetLayer(kGUILayerMainMenu)
    self.header:AddChild(self.mapName)

    self.team1UI = self:CreateTeamBackground(1)
    self.team1UI.playerRows = {}
    table.insert(self.team1UI.playerRows,
        CreateScoreboardRow(self.team1UI.tableBackground, kHeaderRowColor, kMarineHeaderRowTextColor, "Player name",
            "K", "A", "D", ConditionalValue(avgAccTable.marineOnosAcc == -1, "Accuracy", "Acc. (No Onos)"), "Score",
            "Pl. dmg", "Str. dmg", "Build time", "Played"))
    self.team2UI = self:CreateTeamBackground(2)
    self.team2UI.playerRows = {}
    table.insert(self.team2UI.playerRows,
        CreateScoreboardRow(self.team2UI.tableBackground, kHeaderRowColor, kAlienHeaderRowTextColor, "Player name", "K",
            "A", "D", "Accuracy", "Score", "Pl. dmg", "Str. dmg", "Build time", "Played"))

    self.sliderBarBg = GUIManager:CreateGraphicItem()
    self.sliderBarBg:SetColor(Color(0, 0, 0, 0.5))
    self.sliderBarBg:SetSize(Vector(GUILinearScale(8), kContentMaxYSize, 0))
    self.sliderBarBg:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.sliderBarBg:SetPosition(Vector((kTitleSize.x + GUILinearScale(32)) / 2, GUILinearScale(128), 0))
    self.sliderBarBg:SetLayer(kGUILayerMainMenu)

    self.slider = GUIManager:CreateGraphicItem()
    self.slider:SetColor(Color(1, 1, 1, 1))
    self.slider:SetSize(Vector(GUILinearScale(16), GUILinearScale(8), 0))
    self.slider:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.slider:SetLayer(kGUILayerMainMenu)
    self.sliderBarBg:AddChild(self.slider)

    self.contentBackground = GUIManager:CreateGraphicItem()
    self.contentBackground:SetColor(Color(0, 0, 0, 0.5))
    self.contentBackground:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.contentBackground:SetPosition(Vector(-kTitleSize.x / 2, GUILinearScale(128), 0))
    self.contentBackground:SetSize(Vector(kTitleSize.x, kContentMaxYSize, 0))
    self.contentBackground:SetLayer(kGUILayerMainMenu)

    self.contentStencil = GUIManager:CreateGraphicItem()
    self.contentStencil:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.contentStencil:SetPosition(Vector(-kTitleSize.x / 2, GUILinearScale(128), 0))
    self.contentStencil:SetSize(Vector(kTitleSize.x, kContentMaxYSize, 0))
    self.contentStencil:SetIsStencil(true)
    self.contentStencil:SetClearsStencilBuffer(true)
    self.contentStencil:SetLayer(kGUILayerMainMenu)

    self.background = GUIManager:CreateGraphicItem()
    self.background:SetColor(Color(0, 0, 0, 0))
    self.background:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.background:SetPosition(Vector(-(kTitleSize.x - GUILinearScale(32)) / 2, GUILinearScale(128), 0))
    self.background:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.team1UI.background)
    self.background:AddChild(self.team2UI.background)

    self.topPlayersTextShadow = GUIManager:CreateTextItem()
    self.topPlayersTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.topPlayersTextShadow:SetFontName(kTitleFontName)
    self.topPlayersTextShadow:SetColor(Color(0, 0, 0, 1))
    self.topPlayersTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.topPlayersTextShadow)
    self.topPlayersTextShadow:SetIsVisible(false)
    self.topPlayersTextShadow:SetText("TOP PLAYERS")
    self.topPlayersTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.topPlayersTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.topPlayersTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.topPlayersTextShadow)

    self.topPlayersText = GUIManager:CreateTextItem()
    self.topPlayersText:SetStencilFunc(GUIItem.NotEqual)
    self.topPlayersText:SetFontName(kTitleFontName)
    self.topPlayersText:SetColor(Color(1, 1, 1, 1))
    self.topPlayersText:SetScale(scaledVector)
    GUIMakeFontScale(self.topPlayersText)
    self.topPlayersText:SetText("TOP PLAYERS")
    self.topPlayersText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.topPlayersText:SetTextAlignmentX(GUIItem.Align_Center)
    self.topPlayersText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.topPlayersText:SetLayer(kGUILayerMainMenu)
    self.topPlayersTextShadow:AddChild(self.topPlayersText)

    self.equipmentAndLifeformsTextShadow = GUIManager:CreateTextItem()
    self.equipmentAndLifeformsTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.equipmentAndLifeformsTextShadow:SetFontName(kTitleFontName)
    self.equipmentAndLifeformsTextShadow:SetColor(Color(0, 0, 0, 1))
    self.equipmentAndLifeformsTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.equipmentAndLifeformsTextShadow)
    self.equipmentAndLifeformsTextShadow:SetIsVisible(false)
    self.equipmentAndLifeformsTextShadow:SetText("EQUIPMENT AND LIFEFORMS")
    self.equipmentAndLifeformsTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.equipmentAndLifeformsTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.equipmentAndLifeformsTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.equipmentAndLifeformsTextShadow)

    self.equipmentAndLifeformsText = GUIManager:CreateTextItem()
    self.equipmentAndLifeformsText:SetStencilFunc(GUIItem.NotEqual)
    self.equipmentAndLifeformsText:SetFontName(kTitleFontName)
    self.equipmentAndLifeformsText:SetColor(Color(1, 1, 1, 1))
    self.equipmentAndLifeformsText:SetScale(scaledVector)
    GUIMakeFontScale(self.equipmentAndLifeformsText)
    self.equipmentAndLifeformsText:SetText("EQUIPMENT AND LIFEFORMS")
    self.equipmentAndLifeformsText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.equipmentAndLifeformsText:SetTextAlignmentX(GUIItem.Align_Center)
    self.equipmentAndLifeformsText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.equipmentAndLifeformsText:SetLayer(kGUILayerMainMenu)
    self.equipmentAndLifeformsTextShadow:AddChild(self.equipmentAndLifeformsText)

    self.TssTextShadow = GUIManager:CreateTextItem()
    self.TssTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.TssTextShadow:SetFontName(kTitleFontName)
    self.TssTextShadow:SetColor(Color(0, 0, 0, 1))
    self.TssTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.TssTextShadow)
    self.TssTextShadow:SetIsVisible(false)
    self.TssTextShadow:SetText("TEAM SPECIFIC STATS")
    self.TssTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.TssTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.TssTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.TssTextShadow)

    self.TssText = GUIManager:CreateTextItem()
    self.TssText:SetStencilFunc(GUIItem.NotEqual)
    self.TssText:SetFontName(kTitleFontName)
    self.TssText:SetColor(Color(1, 1, 1, 1))
    self.TssText:SetScale(scaledVector)
    GUIMakeFontScale(self.TssText)
    self.TssText:SetText("TEAM SPECIFIC STATS")
    self.TssText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.TssText:SetTextAlignmentX(GUIItem.Align_Center)
    self.TssText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.TssText:SetLayer(kGUILayerMainMenu)
    self.TssTextShadow:AddChild(self.TssText)

    self.teamStatsTextShadow = GUIManager:CreateTextItem()
    self.teamStatsTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.teamStatsTextShadow:SetFontName(kTitleFontName)
    self.teamStatsTextShadow:SetColor(Color(0, 0, 0, 1))
    self.teamStatsTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.teamStatsTextShadow)
    self.teamStatsTextShadow:SetText("TEAM STATS")
    self.teamStatsTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.teamStatsTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.teamStatsTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.teamStatsTextShadow)

    self.teamStatsText = GUIManager:CreateTextItem()
    self.teamStatsText:SetStencilFunc(GUIItem.NotEqual)
    self.teamStatsText:SetFontName(kTitleFontName)
    self.teamStatsText:SetColor(Color(1, 1, 1, 1))
    self.teamStatsText:SetScale(scaledVector)
    GUIMakeFontScale(self.teamStatsText)
    self.teamStatsText:SetText("TEAM STATS")
    self.teamStatsText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.teamStatsText:SetTextAlignmentX(GUIItem.Align_Center)
    self.teamStatsText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.teamStatsText:SetLayer(kGUILayerMainMenu)
    self.teamStatsTextShadow:AddChild(self.teamStatsText)

    self.yourStatsTextShadow = GUIManager:CreateTextItem()
    self.yourStatsTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.yourStatsTextShadow:SetFontName(kTitleFontName)
    self.yourStatsTextShadow:SetColor(Color(0, 0, 0, 1))
    self.yourStatsTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.yourStatsTextShadow)
    self.yourStatsTextShadow:SetIsVisible(false)
    self.yourStatsTextShadow:SetText("YOUR STATS")
    self.yourStatsTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.yourStatsTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.yourStatsTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.yourStatsTextShadow)

    self.yourStatsText = GUIManager:CreateTextItem()
    self.yourStatsText:SetStencilFunc(GUIItem.NotEqual)
    self.yourStatsText:SetFontName(kTitleFontName)
    self.yourStatsText:SetColor(Color(1, 1, 1, 1))
    self.yourStatsText:SetScale(scaledVector)
    GUIMakeFontScale(self.yourStatsText)
    self.yourStatsText:SetText("YOUR STATS")
    self.yourStatsText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.yourStatsText:SetTextAlignmentX(GUIItem.Align_Center)
    self.yourStatsText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.yourStatsText:SetLayer(kGUILayerMainMenu)
    self.yourStatsTextShadow:AddChild(self.yourStatsText)

    self.techLogTextShadow = GUIManager:CreateTextItem()
    self.techLogTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.techLogTextShadow:SetFontName(kTitleFontName)
    self.techLogTextShadow:SetColor(Color(0, 0, 0, 1))
    self.techLogTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.techLogTextShadow)
    self.techLogTextShadow:SetIsVisible(false)
    self.techLogTextShadow:SetText("TECH LOG")
    self.techLogTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.techLogTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.techLogTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.techLogTextShadow)

    self.techLogText = GUIManager:CreateTextItem()
    self.techLogText:SetStencilFunc(GUIItem.NotEqual)
    self.techLogText:SetFontName(kTitleFontName)
    self.techLogText:SetColor(Color(1, 1, 1, 1))
    self.techLogText:SetScale(scaledVector)
    GUIMakeFontScale(self.techLogText)
    self.techLogText:SetText("TECH LOG")
    self.techLogText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.techLogText:SetTextAlignmentX(GUIItem.Align_Center)
    self.techLogText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.techLogText:SetLayer(kGUILayerMainMenu)
    self.techLogTextShadow:AddChild(self.techLogText)

    self.hiveSkillGraphTextShadow = GUIManager:CreateTextItem()
    self.hiveSkillGraphTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.hiveSkillGraphTextShadow:SetFontName(kTitleFontName)
    self.hiveSkillGraphTextShadow:SetColor(Color(0, 0, 0, 1))
    self.hiveSkillGraphTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.hiveSkillGraphTextShadow)
    self.hiveSkillGraphTextShadow:SetIsVisible(false)
    self.hiveSkillGraphTextShadow:SetText("HIVESKILL GRAPH (Not Accounting For Comm Skill)")
    self.hiveSkillGraphTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.hiveSkillGraphTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.hiveSkillGraphTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.hiveSkillGraphTextShadow)

    self.hiveSkillGraphText = GUIManager:CreateTextItem()
    self.hiveSkillGraphText:SetStencilFunc(GUIItem.NotEqual)
    self.hiveSkillGraphText:SetFontName(kTitleFontName)
    self.hiveSkillGraphText:SetColor(Color(1, 1, 1, 1))
    self.hiveSkillGraphText:SetScale(scaledVector)
    GUIMakeFontScale(self.hiveSkillGraphText)
    self.hiveSkillGraphText:SetText("HIVESKILL GRAPH (Not Accounting For Comm Skill)")
    self.hiveSkillGraphText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.hiveSkillGraphText:SetTextAlignmentX(GUIItem.Align_Center)
    self.hiveSkillGraphText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.hiveSkillGraphText:SetLayer(kGUILayerMainMenu)
    self.hiveSkillGraphTextShadow:AddChild(self.hiveSkillGraphText)

    self.rtGraphTextShadow = GUIManager:CreateTextItem()
    self.rtGraphTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.rtGraphTextShadow:SetFontName(kTitleFontName)
    self.rtGraphTextShadow:SetColor(Color(0, 0, 0, 1))
    self.rtGraphTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.rtGraphTextShadow)
    self.rtGraphTextShadow:SetIsVisible(false)
    self.rtGraphTextShadow:SetText("RT GRAPH")
    self.rtGraphTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.rtGraphTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.rtGraphTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.rtGraphTextShadow)

    -- commented out for LessNetworkData
    --[[
    self.presGraphTextShadow = GUIManager:CreateTextItem()
    self.presGraphTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.presGraphTextShadow:SetFontName(kTitleFontName)
    self.presGraphTextShadow:SetColor(Color(0, 0, 0, 1))
    self.presGraphTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.presGraphTextShadow)
    self.presGraphTextShadow:SetIsVisible(false)
    self.presGraphTextShadow:SetText("PRES GRAPH")

    self.presGraphTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.presGraphTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.presGraphTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.presGraphTextShadow)

    self.presGraphText = GUIManager:CreateTextItem()
    self.presGraphText:SetStencilFunc(GUIItem.NotEqual)
    self.presGraphText:SetFontName(kTitleFontName)
    self.presGraphText:SetColor(Color(1, 1, 1, 1))
    self.presGraphText:SetScale(scaledVector)
    GUIMakeFontScale(self.presGraphText)
    self.presGraphText:SetText("PRES GRAPH")
    self.presGraphText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.presGraphText:SetTextAlignmentX(GUIItem.Align_Center)
    self.presGraphText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.presGraphText:SetLayer(kGUILayerMainMenu)
    self.presGraphTextShadow:AddChild(self.presGraphText)
    ]]

    self.rtGraphText = GUIManager:CreateTextItem()
    self.rtGraphText:SetStencilFunc(GUIItem.NotEqual)
    self.rtGraphText:SetFontName(kTitleFontName)
    self.rtGraphText:SetColor(Color(1, 1, 1, 1))
    self.rtGraphText:SetScale(scaledVector)
    GUIMakeFontScale(self.rtGraphText)
    self.rtGraphText:SetText("RT GRAPH")
    self.rtGraphText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.rtGraphText:SetTextAlignmentX(GUIItem.Align_Center)
    self.rtGraphText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.rtGraphText:SetLayer(kGUILayerMainMenu)
    self.rtGraphTextShadow:AddChild(self.rtGraphText)

    self.killGraphTextShadow = GUIManager:CreateTextItem()
    self.killGraphTextShadow:SetStencilFunc(GUIItem.NotEqual)
    self.killGraphTextShadow:SetFontName(kTitleFontName)
    self.killGraphTextShadow:SetColor(Color(0, 0, 0, 1))
    self.killGraphTextShadow:SetScale(scaledVector)
    GUIMakeFontScale(self.killGraphTextShadow)
    self.killGraphTextShadow:SetIsVisible(false)
    self.killGraphTextShadow:SetText("KILL GRAPH")
    self.killGraphTextShadow:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.killGraphTextShadow:SetTextAlignmentX(GUIItem.Align_Center)
    self.killGraphTextShadow:SetLayer(kGUILayerMainMenu)
    self.background:AddChild(self.killGraphTextShadow)

    self.killGraphText = GUIManager:CreateTextItem()
    self.killGraphText:SetStencilFunc(GUIItem.NotEqual)
    self.killGraphText:SetFontName(kTitleFontName)
    self.killGraphText:SetColor(Color(1, 1, 1, 1))
    self.killGraphText:SetScale(scaledVector)
    GUIMakeFontScale(self.killGraphText)
    self.killGraphText:SetText("KILL GRAPH")
    self.killGraphText:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.killGraphText:SetTextAlignmentX(GUIItem.Align_Center)
    self.killGraphText:SetPosition(Vector(-kTextShadowOffset, -kTextShadowOffset, 0))
    self.killGraphText:SetLayer(kGUILayerMainMenu)
    self.killGraphTextShadow:AddChild(self.killGraphText)

    -- Adding TopPlayers
    local yPos = GUILinearScale(16)
    self.topPlayersTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
    self.equipmentAndLifeformsTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
    self.TssTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
    self.teamStatsTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
    yPos = yPos + GUILinearScale(32)
    if DIPS_EnahncedStats then
        yPos = yPos + GUILinearScale(100)
    end
    self.team1UI.background:SetPosition(Vector(GUILinearScale(16), yPos, 0))
    yPos = yPos + self.team1UI.tableBackground:GetSize().y + self.team1UI.background:GetSize().y
    self.team2UI.background:SetPosition(Vector(GUILinearScale(16), yPos, 0))
    yPos = yPos + self.team2UI.tableBackground:GetSize().y + self.team2UI.background:GetSize().y + GUILinearScale(32)
    self.yourStatsTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))

    self.contentSize = yPos

    self.avatars = {}
    self.topPlayersCards = {}
    self.topTssCards = {}
    self.topEalCards = {}
    self.statsCards = {}
    self.techLogs = {}
    self.hiveSkillGraphs = {}
    self.rtGraphs = {}
    self.killGraphs = {}
    self.killIcons = {}
    self.toolTipCards = {}

    self.hiveSkillGraph = LineGraph()
    self.hiveSkillGraph:Initialize()
    self.hiveSkillGraph:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.hiveSkillGraph:SetSize(rtGraphSize)
    self.hiveSkillGraph:SetYGridSpacing(1)
    self.hiveSkillGraph:SetIsVisible(false)
    self.hiveSkillGraph:SetXAxisIsTime(true)
    self.hiveSkillGraph:ExtendXAxisToBounds(true)
    self.hiveSkillGraph:GiveParent(self.background)
    self.hiveSkillGraph:SetStencilFunc(GUIItem.NotEqual)

    self.hiveSkillGraph:StartLine(kTeam1Index, kBlueColor)
    self.hiveSkillGraph:StartLine(kTeam2Index, kRedColor)
    self.rtGraph = LineGraph()
    self.rtGraph:Initialize()
    self.rtGraph:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.rtGraph:SetSize(rtGraphSize)
    self.rtGraph:SetYGridSpacing(1)
    self.rtGraph:SetIsVisible(false)
    self.rtGraph:SetXAxisIsTime(true)
    self.rtGraph:ExtendXAxisToBounds(true)
    self.rtGraph:GiveParent(self.background)
    self.rtGraph:SetStencilFunc(GUIItem.NotEqual)

    self.rtGraph:StartLine(kTeam1Index, kBlueColor)
    self.rtGraph:StartLine(kTeam2Index, kRedColor)

    self.killGraph = LineGraph()
    self.killGraph:Initialize()
    self.killGraph:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.killGraph:SetSize(rtGraphSize)
    self.killGraph:SetYGridSpacing(1)
    self.killGraph:SetIsVisible(false)
    self.killGraph:SetXAxisIsTime(true)
    self.killGraph:ExtendXAxisToBounds(true)
    self.killGraph:GiveParent(self.background)
    self.killGraph:SetStencilFunc(GUIItem.NotEqual)

    self.killGraph:StartLine(kTeam1Index, kBlueColor)
    self.killGraph:StartLine(kTeam2Index, kRedColor)

    -- commented out for LessNetworkData
    --[[
    self.presGraph = {}
    self.presGraph = LineGraph()
    self.presGraph:Initialize()
    self.presGraph:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.presGraph:SetSize(rtGraphSize)
    self.presGraph:SetYGridSpacing(1)
    self.presGraph:SetIsVisible(false)
    self.presGraph:SetXAxisIsTime(true)
    self.presGraph:ExtendXAxisToBounds(true)
    self.presGraph:GiveParent(self.background)
    self.presGraph:SetStencilFunc(GUIItem.NotEqual)

    self.presGraph:StartLine(1, kBlueColor)
    --self.presGraph:StartLine(2, Color(0.22 , 0.46 , 0.66, 1))
    self.presGraph:StartLine(3, kRedColor)
    --self.presGraph:StartLine(4, Color(0.66 , 0.4 , 0.13, 1))
    -- kBlueColor = Color(0, 0.6117, 1, 1)
    -- kRedColor = Color(1, 0.4941, 0, 1)
    self.presGraph:StartLine(2, Color(0.12, 0.30, 0.66, 1))
    self.presGraph:StartLine(4, Color(0.66, 0.2, 0.2, 1))

    self.presGraphText.tooltip = "Aliens:\nOrange: pres of currently living lifeforms\nRed: unused pres AND currently living lifeforms\n\nMarines:\nLightblue: current equipment on marines or ground\nBlue: unused pres AND current equipment on marines or ground"
    self.presGraph.graphBackground.tooltip = self.presGraphText.tooltip
    table.insert(self.toolTipCards, self.presGraphText)
    table.insert(self.toolTipCards, self.presGraph.graphBackground)

    ]]

    self.builtRTsComp = ComparisonBarGraph()
    self.builtRTsComp:Initialize()
    self.builtRTsComp:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.builtRTsComp:SetSize(comparisonSize)
    self.builtRTsComp:SetValues(0, 0)
    self.builtRTsComp:SetStencilFunc(GUIItem.NotEqual)
    self.builtRTsComp:SetTitle("Built RTs")
    self.builtRTsComp:GiveParent(self.background)

    self.lostRTsComp = ComparisonBarGraph()
    self.lostRTsComp:Initialize()
    self.lostRTsComp:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.lostRTsComp:SetSize(comparisonSize)
    self.lostRTsComp:SetValues(0, 0)
    self.lostRTsComp:SetStencilFunc(GUIItem.NotEqual)
    self.lostRTsComp:SetTitle("Lost RTs")
    self.lostRTsComp:GiveParent(self.background)

    self.avgRTsComp = ComparisonBarGraph()
    self.avgRTsComp:Initialize()
    self.avgRTsComp:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.avgRTsComp:SetSize(comparisonSize)
    self.avgRTsComp:SetValues(0, 0)
    self.avgRTsComp:SetStencilFunc(GUIItem.NotEqual)
    self.avgRTsComp:SetTitle("Average RTs")
    self.avgRTsComp:GiveParent(self.background)

    self.killComparison = ComparisonBarGraph()
    self.killComparison:Initialize()
    self.killComparison:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.killComparison:SetSize(comparisonSize)
    self.killComparison:SetValues(0, 0)
    self.killComparison:SetStencilFunc(GUIItem.NotEqual)
    self.killComparison:SetTitle("Total Kills")
    self.killComparison:GiveParent(self.background)

    self.saved = false
    self.prevRequestKey = false
    self.prevScoreKey = false
    self.isDragging = false
    self.slideOffset = 0
    self.displayed = false

    lastSortedT1 = "kills"
    lastSortedT1WasInv = false
    lastSortedT2 = "kills"
    lastSortedT2WasInv = false

    pcall(self.LoadLastRoundStats, self)

    self.actionIconGUI = GetGUIManager():CreateGUIScript("GUIActionIcon")
    self.actionIconGUI:SetColor(kWhite)
    self.actionIconGUI.pickupIcon:SetLayer(kGUILayerPlayerHUD)
    self.actionIconGUI:Hide()

    self.tooltip = GetGUIManager():CreateGUIScriptSingle("menu/GUIHoverTooltip")
    self.hoverMenu = GetGUIManager():CreateGUIScript("GUIHoverMenu")
    self.hoverMenu:Hide()

    self.lastRow = nil

    self.background:SetIsVisible(false)
    self.header:SetIsVisible(false)
    self.sliderBarBg:SetIsVisible(false)
    self.contentBackground:SetIsVisible(false)
    self.contentStencil:SetIsVisible(false)

    EndStatsVisible = false
end

function GUIGameEndStats:Uninitialize()
    if self:GetIsVisible() then
        MouseTracker_SetIsVisible(false)
    end

    -- GUI.DestroyItem(self.background)
    self:SetIsVisible(false)
    self.background = nil
    GUI.DestroyItem(self.header)
    GUI.DestroyItem(self.sliderBarBg)
    GUI.DestroyItem(self.contentBackground)
    GUI.DestroyItem(self.contentStencil)

    GetGUIManager():DestroyGUIScript(self.actionIconGUI)
    self.actionIconGUI = nil
end

function GUIGameEndStats:SetIsVisible(visible)
    -- Don't try to display it if there is no content visible
    local gameInfo = GetGameInfoEntity()
    local teamStatsVisible = gameInfo and gameInfo.showEndStatsTeamBreakdown
    local visibleStats = teamStatsVisible and self.teamStatsTextShadow:GetIsVisible() or #self.statsCards > 0 or
                             #self.rtGraphs > 0
    if visible ~= self:GetIsVisible() and ((visible and visibleStats) or not visible) then
        self.background:SetIsVisible(visible)
        self.header:SetIsVisible(visible)
        self.sliderBarBg:SetIsVisible(visible)
        self.contentBackground:SetIsVisible(visible)
        self.contentStencil:SetIsVisible(visible)

        EndStatsVisible = visible
        self.slideOffset = 0

        if not visible then
            self.hoverMenu:Hide()
            self.tooltip:Hide(0)
        else
            self:RepositionStats()
        end

        MouseTracker_SetIsVisible(visible)
    end
end

function GUIGameEndStats:GetIsVisible()
    return self.background:GetIsVisible()
end

local function repositionStatsCards(self)
    -- Every row will have 3 items
    local numItemsPerRow = 3
    local cardSize = (kCardSize.x - GUILinearScale(32))
    local yPos = 0
    local xPos = 0
    local ySize = 0

    if #self.statsCards > 0 then
        yPos = self.yourStatsTextShadow:GetPosition().y + GUILinearScale(32)
        ySize = self.yourStatsTextShadow:GetPosition().y
        local lastTeam
        local tmp = {}
        for _, teamCard in ipairs(self.statsCards) do
            if lastTeam ~= teamCard.teamNumber then
                lastTeam = teamCard.teamNumber
                table.insert(tmp, {})
            end
            table.insert(tmp[#tmp], teamCard)
        end
        for _, team in ipairs(tmp) do
            local row = 0
            local tallestElem = 0
            local remainingElems = 0
            for index, card in ipairs(team) do
                local numRows = math.ceil(#team / numItemsPerRow)
                -- Determine the last row with 3 elements
                local last3Row = numItemsPerRow * (numRows - 1)
                local curRow = math.ceil(index / numItemsPerRow)
                local relativeIndex = index - ((curRow - 1) * numItemsPerRow)
                local currentYPos = card.tableBackground:GetSize().y + card.background:GetSize().y + GUILinearScale(16)
                if row == curRow and currentYPos > tallestElem then
                    tallestElem = currentYPos
                elseif row ~= curRow then
                    row = curRow
                    yPos = yPos + tallestElem
                    tallestElem = currentYPos
                    remainingElems = #team - index + 1
                end
                if index <= last3Row or remainingElems == 3 then
                    xPos = (relativeIndex - 2) * GUILinearScale(32) - cardSize * 1.5 + (relativeIndex - 1) * cardSize
                elseif remainingElems == 2 then
                    xPos = -cardSize + (2 - relativeIndex) * cardSize + ConditionalValue(relativeIndex == 1, 1, -1) *
                               GUILinearScale(32)
                else
                    xPos = -cardSize / 2
                end
                card.background:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2 + xPos, yPos, 0))
            end
            yPos = yPos + tallestElem
        end
    end

    return yPos - ySize
end

function GUIGameEndStats:RepositionStats()
    local yPos = kBackgroundSize.y
    yPos = yPos + GUILinearScale(16)

    self.yourStatsTextShadow:SetIsVisible(#self.statsCards > 0)

    if self.topPlayersTextShadow:GetIsVisible() then
        yPos = yPos + GUILinearScale(146 + 162)
    end

    if self.team1UI.background:GetIsVisible() then
        if self.equipmentAndLifeformsTextShadow:GetIsVisible() then
            self.equipmentAndLifeformsTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
            self.topEalCards.Aliens.background:SetPosition(GUILinearScale(32) / 2,
                self.equipmentAndLifeformsTextShadow:GetPosition().y + GUILinearScale(32), 0)
            self.topEalCards.Marines.background:SetPosition(GUILinearScale(32) / 2,
                self.topEalCards.Aliens.background:GetPosition().y + self.topEalCards.Aliens.background:GetSize().y, 0)
            yPos =
                self.topEalCards.Marines.background:GetPosition().y + self.topEalCards.Marines.background:GetSize().y +
                    GUILinearScale(16)
        end
        if self.TssTextShadow:GetIsVisible() then
            self.TssTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
            self.topTssCards.AlienItem.background:SetPosition(GUILinearScale(32) / 2,
                self.TssTextShadow:GetPosition().y + GUILinearScale(32), 0)
            self.topTssCards.MarineItem.background:SetPosition(GUILinearScale(32) / 2, self.topTssCards.AlienItem
                .background:GetPosition().y + self.topTssCards.AlienItem.background:GetSize().y, 0)
            yPos = self.topTssCards.MarineItem.background:GetPosition().y +
                       self.topTssCards.MarineItem.background:GetSize().y + GUILinearScale(16)
        end
        self.teamStatsTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
        yPos = yPos + GUILinearScale(32)
        self.team1UI.background:SetPosition(Vector(GUILinearScale(16), yPos, 0))
        yPos = yPos + self.team1UI.tableBackground:GetSize().y + self.team1UI.background:GetSize().y
        self.team2UI.background:SetPosition(Vector(GUILinearScale(16), yPos, 0))
        yPos = yPos + self.team2UI.tableBackground:GetSize().y + self.team2UI.background:GetSize().y +
                   GUILinearScale(32)
    end

    self.yourStatsTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
    yPos = yPos + repositionStatsCards(self)

    local showTechLog = #self.techLogs > 0
    self.techLogTextShadow:SetIsVisible(showTechLog)
    if showTechLog then
        self.techLogTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
        yPos = yPos + GUILinearScale(32)

        self.techLogs[1].header.background:SetPosition(Vector(GUILinearScale(16), yPos, 0))
        self.techLogs[2].header.background:SetPosition(Vector(kTechLogTitleSize.x + GUILinearScale(16), yPos, 0))

        local team1YSize = self.techLogs[1].header.background:GetSize().y +
                               self.techLogs[1].header.tableBackground:GetSize().y
        local team2YSize = self.techLogs[2].header.background:GetSize().y +
                               self.techLogs[2].header.tableBackground:GetSize().y

        yPos = yPos + GUILinearScale(32) + math.max(team1YSize, team2YSize)
    end

    local showRTGraph = #self.rtGraphs > 0
    self.rtGraphTextShadow:SetIsVisible(showRTGraph)
    self.rtGraph:SetIsVisible(showRTGraph)
    self.builtRTsComp:SetIsVisible(showRTGraph)
    self.lostRTsComp:SetIsVisible(showRTGraph)
    self.avgRTsComp:SetIsVisible(showRTGraph)
    if showRTGraph then
        self.rtGraphTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
        yPos = yPos + GUILinearScale(32)

        self.rtGraph:SetPosition(Vector((kTitleSize.x - rtGraphSize.x) / 2, yPos, 0))
        yPos = yPos + rtGraphSize.y + GUILinearScale(72)

        self.builtRTsComp:SetPosition(Vector((kTitleSize.x - comparisonSize.x - rtGraphPadding) / 2, yPos, 0))
        yPos = yPos + comparisonSize.y + GUILinearScale(48)

        self.lostRTsComp:SetPosition(Vector((kTitleSize.x - comparisonSize.x - rtGraphPadding) / 2, yPos, 0))
        yPos = yPos + comparisonSize.y + GUILinearScale(48)

        self.avgRTsComp:SetPosition(Vector((kTitleSize.x - comparisonSize.x - rtGraphPadding) / 2, yPos, 0))
        yPos = yPos + comparisonSize.y + GUILinearScale(48)
    end

    local showKillGraph = #self.killGraphs > 0
    self.killGraphTextShadow:SetIsVisible(showKillGraph)
    self.killGraph:SetIsVisible(showKillGraph)
    self.killComparison:SetIsVisible(showKillGraph)
    if showKillGraph then
        self.killGraphTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
        yPos = yPos + GUILinearScale(32)

        self.killGraph:SetPosition(Vector((kTitleSize.x - rtGraphSize.x) / 2, yPos, 0))
        yPos = yPos + rtGraphSize.y + GUILinearScale(72)

        self.killComparison:SetPosition(Vector((kTitleSize.x - comparisonSize.x - rtGraphPadding) / 2, yPos, 0))
        yPos = yPos + comparisonSize.y + GUILinearScale(48)
    end

    local showHiveSkillGraph = #self.hiveSkillGraphs > 0
    self.hiveSkillGraphTextShadow:SetIsVisible(showHiveSkillGraph)
    self.hiveSkillGraph:SetIsVisible(showHiveSkillGraph)
    if showHiveSkillGraph then
        self.hiveSkillGraphTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
        yPos = yPos + GUILinearScale(32)

        self.hiveSkillGraph:SetPosition(Vector((kTitleSize.x - rtGraphSize.x) / 2, yPos, 0))
        yPos = yPos + rtGraphSize.y + GUILinearScale(72)
    end

    -- commented out for LessNetworkData
    --[[
    local showpresGraph = self.presGraphs and #self.presGraphs > 0 or false
    self.presGraphTextShadow:SetIsVisible(showpresGraph)
    self.presGraph:SetIsVisible(showpresGraph)
    if showpresGraph then
        self.presGraphTextShadow:SetPosition(Vector((kTitleSize.x - GUILinearScale(32)) / 2, yPos, 0))
        yPos = yPos + GUILinearScale(32)

        self.presGraph:SetPosition(Vector((kTitleSize.x - rtGraphSize.x) / 2, yPos, 0))
        yPos = yPos + rtGraphSize.y + GUILinearScale(72)
    end
    ]]

    self.contentSize = math.max(self.contentSize, yPos)
end

local function HandleSlidebarClicked(self)
    local _, mouseY = Client.GetCursorPosScreen()
    if self.sliderBarBg:GetIsVisible() and self.isDragging then
        local topPos = self.sliderBarBg:GetScreenPosition(screenWidth, screenHeight).y
        local bottomPos = topPos + kContentMaxYSize
        mouseY = Clamp(mouseY, topPos, bottomPos)
        local slidePercentage = (mouseY - topPos) / (bottomPos - topPos)
        self.slideOffset = slidePercentage * (self.contentSize - kContentMaxYSize)
    end
end

local function CheckRowHighlight(self, row, mouseX, mouseY)
    if GUIItemContainsPoint(row.background, mouseX, mouseY) and row.steamId then
        if not row.originalColor then
            row.originalColor = row.background:GetColor()
        end
        local color = row.originalColor * 0.75
        row.background:SetColor(color)

        if row.commIcon and row.commIcon.tooltip and GUIItemContainsPoint(row.commIcon, mouseX, mouseY) then
            self.tooltip:SetText(row.commIcon.tooltip)
            self.tooltip:Show()
        else
            self.tooltip:Hide()
        end

        self.lastRow = row
    elseif row.originalColor then
        row.background:SetColor(row.originalColor)
        row.originalColor = nil
    end
end

local function SortByColumn(self, isMarine, sortField, inv)
    local playerRows = isMarine and self.team1UI.playerRows or self.team2UI.playerRows
    local sortTable = {}
    for _, row in ipairs(playerRows) do
        if row.originalOrder and row.message then
            table.insert(sortTable, row)
        end
    end

    table.sort(sortTable, function(a, b)
        if a.message[sortField] == b.message[sortField] then
            return a.originalOrder < b.originalOrder
        elseif sortField == "lowerCaseName" and not inv or sortField ~= "lowerCaseName" and inv then
            return a.message[sortField] < b.message[sortField]
        else
            return a.message[sortField] > b.message[sortField]
        end
    end)

    for index, row in ipairs(sortTable) do
        local bgColor = isMarine and kMarinePlayerStatsOddColor or kAlienPlayerStatsOddColor
        if index % 2 == 0 then
            bgColor = isMarine and kMarinePlayerStatsEvenColor or kAlienPlayerStatsEvenColor
        end

        row.background:SetPosition(Vector(kRowBorderSize, kRowBorderSize + index * kRowSize.y, 0))
        -- Our own row is colored correctly already
        if row.message.steamId ~= Client.GetSteamId() then
            row.background:SetColor(bgColor)
        end
    end
end

local function GetXSpacing(gameLength)
    local xSpacing = 60

    if gameLength < 60 then
        xSpacing = 10
    elseif gameLength < 5 * 60 then
        xSpacing = 30
    elseif gameLength < 15 * 60 then
        xSpacing = 60
    elseif gameLength < 60 * 60 then
        xSpacing = 300
    else
        xSpacing = 600
    end

    return xSpacing
end

local function GetYSpacing(value)
    local ySpacing = 25

    if value < 10 then
        return 1
    elseif value < 20 then
        return 2
    elseif value < 100 then
        return 10
    else
        return 25
    end

    return ySpacing
end

function GUIGameEndStats:CheckTooltipItem()
    local mouseX, mouseY = Client.GetCursorPosScreen()

    -- Loop thru different tooltip items in case we are on one with tooltip
    for i, item in pairs(self.toolTipCards) do
        -- print("Item: " .. tostring(type(item)))
        if item.tooltip then
            -- print("Tooltip: " .. tostring(item.tooltip))
            -- if item:GetIsVisible() and GUIItemContainsPoint(item, mouseX, mouseY) then
            if GUIItemContainsPoint(item, mouseX, mouseY) then
                -- print("Hover activated :-)")
                self.tooltip:SetText(item.tooltip)
                self.tooltip:Show()
            end
        end
    end
    -- GUIItemContainsPoint(row.background, mouseX, mouseY)
end

function GUIGameEndStats:UpdateRowHighlight()
    local mouseX, mouseY = Client.GetCursorPosScreen()

    if not self.hoverMenu.background:GetIsVisible() then
        self.lastRow = nil
        highlightedField = nil
        for index, row in ipairs(self.team1UI.playerRows) do
            if index == 1 then
                local highlightColor = kMarineHeaderRowTextHighlightColor
                local textColor = kMarineHeaderRowTextColor
                for fieldName, item in pairs(row) do
                    if item.GetText and item:GetText() ~= "" then
                        if GUIItemContainsPoint(item, mouseX, mouseY) then
                            highlightedField = fieldName
                            highlightedFieldMarine = true
                            item:SetColor(highlightColor)
                        else
                            item:SetColor(textColor)
                        end
                    end
                end
            else
                CheckRowHighlight(self, row, mouseX, mouseY)
            end
        end
        for index, row in ipairs(self.team2UI.playerRows) do
            if index == 1 then
                local highlightColor = kAlienHeaderRowTextHighlightColor
                local textColor = kAlienHeaderRowTextColor
                for fieldName, item in pairs(row) do
                    if item.GetText and item:GetText() ~= "" then
                        if GUIItemContainsPoint(item, mouseX, mouseY) then
                            highlightedField = fieldName
                            highlightedFieldMarine = false
                            item:SetColor(highlightColor)
                        else
                            item:SetColor(textColor)
                        end
                    end
                end
            else
                CheckRowHighlight(self, row, mouseX, mouseY)
            end
        end

        if self.lastRow == nil then
            self.tooltip:Hide()
        end

        -- Change it to the field name on the message table for proper sorting
        if highlightedField == "acc" then
            highlightedField = "realAccuracy"
        elseif highlightedField == "timeBuilding" then
            highlightedField = "minutesBuilding"
        elseif highlightedField == "timePlayed" then
            highlightedField = "minutesPlaying"
        elseif highlightedField == "playerName" then
            highlightedField = "lowerCaseName"
        end
    end
end

function GUIGameEndStats:UpdateSlidebar()
    -- Handle sliderbar position and display
    if self.sliderBarBg:GetIsVisible() and self.mousePressed and self.isDragging then
        HandleSlidebarClicked(self)
    end

    -- Check if it's visible again since we hide the menu if the game starts
    local showSlidebar = self.contentSize > kContentMaxYSize and self:GetIsVisible()
    local sliderPos = (self.slideOffset / (self.contentSize - kContentMaxYSize) * kContentMaxYSize) -
                          self.slider:GetSize().y / 2
    self.background:SetPosition(Vector(-(kTitleSize.x - GUILinearScale(32)) / 2,
        -self.slideOffset + GUILinearScale(128), 0))

    if math.abs(self.slider:GetPosition().y - sliderPos) > 2.5 then
        StartSoundEffect(kSlideSound)
    end

    self.slider:SetPosition(Vector(-GUILinearScale(8), sliderPos, 0))
    self.sliderBarBg:SetIsVisible(showSlidebar)
end

function GUIGameEndStats:CheckGameState()
    local gameInfo = GetGameInfoEntity()
    local warmupActive = gameInfo.GetWarmUpActive and gameInfo:GetWarmUpActive()

    -- Hide the stats when the game starts if we're on a team
    if PlayerUI_GetHasGameStarted() and not warmupActive and
        (Client.GetLocalPlayer():GetTeamNumber() ~= kTeamReadyRoom and Client.GetLocalPlayer():GetTeamNumber() ~=
            kSpectatorIndex) then
        self:SetIsVisible(false)
        self.actionIconGUI:Hide()
    end
end

function GUIGameEndStats:UpdateCloseButton()
    local mouseX, mouseY = Client.GetCursorPosScreen()

    -- Close button
    local kCloseButtonColor = Color(1, 0, 0, 0.5)
    local kCloseButtonHighlightColor = Color(1, 0, 0, 0.75)

    if GUIItemContainsPoint(self.closeButton, mouseX, mouseY) then
        if self.closeButton:GetColor() ~= kCloseButtonHighlightColor then
            self.closeButton:SetColor(kCloseButtonHighlightColor)
            StartSoundEffect(kMouseHoverSound)
        end
    elseif self.closeButton:GetColor() ~= kCloseButtonColor then
        self.closeButton:SetColor(kCloseButtonColor)
        StartSoundEffect(kMouseHoverSound)
    end
end

function GUIGameEndStats:UpdateVisibleUI()
    -- When going back to the RR sometimes we'll lose the cursor
    if not MouseTracker_GetIsVisible() then
        MouseTracker_SetIsVisible(true)
    end

    self:CheckGameState()

    if not self:GetIsVisible() then
        return
    end

    self:UpdateRowHighlight()

    self:CheckTooltipItem()

    self:UpdateSlidebar()

    self:UpdateCloseButton()
end

local function tblIndexSortSubValue(tbl, subvalue)
    local idx = {}
    for i = 1, #tbl do
        idx[i] = i
    end -- build a table of indexes
    -- sort the indexes, but use the values as the sorting criteria
    table.sort(idx, function(a, b)
        return tbl[a][subvalue] > tbl[b][subvalue]
    end)
    -- return the sorted indexes
    return (table.unpack or unpack)(idx)
end

-- todo: functions
function GUIGameEndStats:BuildTopWinGraph()
    local labelColor = RGBAtoColor(255, 255, 255, 1)
    local topScoreLogoTexture = kMarineStatsLogo
    local topBackground = kIpsBackgroundGeneric
    local labelText = Locale.ResolveString("DRAW_GAME")
    local comObject = nil
    local topPlayerObject = nil

    local teams = {}
    if miscDataTable.winningTeam == kMarineTeamType or miscDataTable.winningTeam == kAlienTeamType then
        for _, stat in ipairs(finalStatsTable) do
            if stat.teamNumber and stat.score ~= 0 and stat.minutesPlaying > 0 and stat.teamNumber ~= 0 then
                if not teams[stat.teamNumber] then
                    teams[stat.teamNumber] = {}
                end
                table.insert(teams[stat.teamNumber], stat)
            end
        end
    end

    if miscDataTable.winningTeam == kMarineTeamType then
        labelText = Locale.ResolveString("MARINE_VICTORY")
        labelColor = kMarineStatsColor
        topBackground = kIpsBackgroundMarines
        comObject = GetPlayerDataFromId(DIPS_MarineCommID)
        if teams and teams[kMarineTeamType] then
            topPlayerObject = teams[kMarineTeamType][tblIndexSortSubValue(teams[kMarineTeamType], "score")]
        end
    elseif miscDataTable.winningTeam == kAlienTeamType then
        labelText = Locale.ResolveString("ALIEN_VICTORY")
        labelColor = kAlienStatsColor
        topBackground = kIpsBackgroundAliens
        topScoreLogoTexture = kAlienStatsLogo
        comObject = GetPlayerDataFromId(DIPS_AlienCommID)
        if teams and teams[kAlienTeamType] then
            topPlayerObject = teams[kAlienTeamType][tblIndexSortSubValue(teams[kAlienTeamType], "score")]
        end
    end

    local item = {}

    item.background = GUIManager:CreateGraphicItem()
    item.background:SetStencilFunc(GUIItem.NotEqual)
    item.background:SetTexture(topBackground)
    item.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    item.background:SetInheritsParentAlpha(false)
    item.background:SetLayer(kGUILayerMainMenu)
    item.background:SetSize(Vector(kBackgroundSize.x, kBackgroundSize.y, 0))
    self.background:AddChild(item.background)

    item.textShadow = GUIManager:CreateTextItem()
    item.textShadow:SetStencilFunc(GUIItem.NotEqual)
    item.textShadow:SetFont(ReadOnly {
        family = "Arial",
        size = 48
    })
    -- item.textShadow:SetFontName(kTitleFontName)
    item.textShadow:SetColor(Color(0, 0, 0, 1))
    item.textShadow:SetScale(scaledVector)
    GUIMakeFontScale(item.textShadow)
    item.textShadow:SetAnchor(GUIItem.Middle, GUIItem.Top)
    item.textShadow:SetText(labelText)
    item.textShadow:SetTextAlignmentX(GUIItem.Align_Center)
    item.textShadow:SetTextAlignmentY(GUIItem.Align_Min)
    -- item.textShadow:SetPosition(Vector(kTextShadowOffset, item.background:GetSize().y / 2 + kTextShadowOffset, 0))
    item.textShadow:SetPosition(Vector(kTextShadowOffset, kTextShadowOffset, 0))
    item.textShadow:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.textShadow)

    item.text = GUIManager:CreateTextItem()
    item.text:SetStencilFunc(GUIItem.NotEqual)
    -- item.text:SetFontName(kTitleFontName)
    item.text:SetFont(ReadOnly {
        family = "Arial",
        size = 48
    })
    item.text:SetColor(Color(1, 1, 1, 1))
    item.text:SetScale(scaledVector)
    GUIMakeFontScale(item.text)
    item.text:SetAnchor(GUIItem.Middle, GUIItem.Top)
    item.text:SetText(labelText)
    item.text:SetTextAlignmentX(GUIItem.Align_Center)
    item.text:SetTextAlignmentY(GUIItem.Align_Min)
    item.text:SetPosition(Vector(0, 0, 0))
    item.text:SetLayer(kGUILayerMainMenu)
    item.background:AddChild(item.text)

    -- If we have com object then create the row on the right side
    if comObject then
        local comCard = {}
        local comCard = self:CreateGraphicHeader("Commander", labelColor, topScoreLogoTexture, Vector(10, 10, 0),
            kLogoSize.x, kLogoSize.y)
        comCard.rows = {}
        comCard.teamNumber = miscDataTable.winningTeam
        comCard.background:SetPosition(Vector(GUILinearScale(32), GUILinearScale(64), 0))
        table.insert(comCard.rows, CreateTopPlayerMainRow(comCard.tableBackground, kAverageRowColor, Color(1, 1, 1, 1),
            comObject, nil, nil))
        self.topPlayersCards.com = comCard
    end

    -- Create topPlayer
    if topPlayerObject then
        local topPlayerCard = {}
        local topPlayerCard = self:CreateGraphicHeader("Top Player", labelColor, topScoreLogoTexture, Vector(10, 10, 0),
            kLogoSize.x, kLogoSize.y)
        topPlayerCard.rows = {}
        topPlayerCard.teamNumber = miscDataTable.winningTeam
        topPlayerCard.background:SetPosition(Vector(item.background:GetSize().x -
                                                        (topPlayerCard.background:GetSize().x + GUILinearScale(64)),
            GUILinearScale(64), 0))
        table.insert(topPlayerCard.rows, CreateTopPlayerMainRow(topPlayerCard.tableBackground, kAverageRowColor,
            Color(1, 1, 1, 1), topPlayerObject, nil, nil))
        self.topPlayersCards.com = topPlayerCard
    end

    self.topPlayersCards.winCard = item
end

function GUIGameEndStats:BuildTopPlayersGraph()
    -- Generate TopPlayers cards
    if self.topPlayersTextShadow:GetIsVisible() then
        -- Special color for top round player
        local bgColor = RGBAtoColor(247, 179, 108, 0.67)
        local topScoreLogoTexture = kMarineStatsLogo

        -- Top of the round (Score)
        TopScorePlayer = finalStatsTable[tblIndexSortSubValue(finalStatsTable, "score")]
        if TopScorePlayer.score > 10 then
            if TopScorePlayer.isMarine then
                topScoreLogoTexture = kMarineStatsLogo
            else
                topScoreLogoTexture = kAlienStatsLogo
            end
            local TopScorePlayerCard = self:CreateGraphicHeader("Most Valued Player", bgColor, topScoreLogoTexture,
                Vector(10, 10, 0), kLogoSize.x, kLogoSize.y)
            TopScorePlayerCard.rows = {}
            TopScorePlayerCard.teamNumber = -2
            TopScorePlayerCard.background:SetPosition(Vector((kTitleSize.x / 2) - (kCardSize.x / 2),
                kBackgroundSize.y + GUILinearScale(16), 0))
            table.insert(TopScorePlayerCard.rows,
                CreateTopPlayerMainRow(TopScorePlayerCard.tableBackground, kAverageRowColor, Color(1, 1, 1, 1),
                    TopScorePlayer, "Score", round(TopScorePlayer.score, 0)))
            self.topPlayersCards.mvp = TopScorePlayerCard
        end

        -- Color for other top players
        bgColor = RGBAtoColor(133, 97, 63, 0.67)

        -- Top Kills
        TopKillsPlayer = finalStatsTable[tblIndexSortSubValue(finalStatsTable, "kills")]
        if TopKillsPlayer.kills > 4 then
            if TopKillsPlayer.isMarine then
                topScoreLogoTexture = kMarineStatsLogo
            else
                topScoreLogoTexture = kAlienStatsLogo
            end
            local TopKillsPlayerCard = self:CreateGraphicHeader("Top Killer", bgColor, topScoreLogoTexture,
                Vector(10, 10, 0), kLogoSize.x, kLogoSize.y)
            TopKillsPlayerCard.rows = {}
            TopKillsPlayerCard.teamNumber = -2
            TopKillsPlayerCard.background:SetPosition(Vector(GUILinearScale(32), kBackgroundSize.y + GUILinearScale(16),
                0))
            table.insert(TopKillsPlayerCard.rows,
                CreateTopPlayerSmallRow(TopKillsPlayerCard.tableBackground, kAverageRowColor, Color(1, 1, 1, 1),
                    TopKillsPlayer, "Kills", printNum(TopKillsPlayer.kills)))
            self.topPlayersCards.kills = TopKillsPlayerCard
        end

        -- Top Structure Dmg
        if DIPS_EnahncedStats and
            (teamSpecificStatsLogTable["marineRtDamage"] or teamSpecificStatsLogTable["alienRtDamage"]) then
            -- Switch this to top RT damage
            local playerData = {}
            if teamSpecificStatsLogTable["marineRtDamage"] then
                for _, message in pairs(teamSpecificStatsLogTable["marineRtDamage"]) do
                    local tssItem = {}
                    tssItem.playerData = GetPlayerDataFromId(_)
                    tssItem.Value = roundNumber(message, 0)
                    table.insert(playerData, tssItem)
                end
            end
            if teamSpecificStatsLogTable["alienRtDamage"] then
                for _, message in pairs(teamSpecificStatsLogTable["alienRtDamage"]) do
                    local tssItem = {}
                    tssItem.playerData = GetPlayerDataFromId(_)
                    tssItem.Value = roundNumber(message, 0)
                    table.insert(playerData, tssItem)
                end
            end
            table.sort(playerData, function(a, b)
                return a.Value > b.Value
            end)
            TopSDmgPlayer = playerData[1].playerData
            local rtAmount = "NaN"
            if TopSDmgPlayer.isMarine then
                topScoreLogoTexture = kMarineStatsLogo
                rtAmount = round(playerData[1].Value / (kHarvesterHealth + kHarvesterArmor), 1)

            else
                topScoreLogoTexture = kAlienStatsLogo
                rtAmount = round(playerData[1].Value / (kExtractorHealth + kExtractorArmor), 1)
            end
            local TopSDmgPlayerCard = self:CreateGraphicHeader("Top Resource Tower", bgColor, topScoreLogoTexture,
                Vector(10, 10, 0), kLogoSize.x, kLogoSize.y)
            TopSDmgPlayerCard.rows = {}
            TopSDmgPlayerCard.teamNumber = -2
            TopSDmgPlayerCard.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
            TopSDmgPlayerCard.background:SetPosition(Vector(kTitleSize.x - kCardSize.x - GUILinearScale(32),
                kBackgroundSize.y + GUILinearScale(16), 0))
            table.insert(TopSDmgPlayerCard.rows,
                CreateTopPlayerSmallRow(TopSDmgPlayerCard.tableBackground, kAverageRowColor, Color(1, 1, 1, 1),
                    TopSDmgPlayer, "RT Damage", humanNumber(roundNumber(playerData[1].Value, 0)) .. " (" .. rtAmount ..
                        " RTs)"))
            self.topPlayersCards.sdmg = TopSDmgPlayerCard
        else
            TopSDmgPlayer = finalStatsTable[tblIndexSortSubValue(finalStatsTable, "sdmg")]
            if TopSDmgPlayer.sdmg > 400 then
                if TopSDmgPlayer.isMarine then
                    topScoreLogoTexture = kMarineStatsLogo
                else
                    topScoreLogoTexture = kAlienStatsLogo
                end
                local TopSDmgPlayerCard = self:CreateGraphicHeader("Top Structure", bgColor, topScoreLogoTexture,
                    Vector(10, 10, 0), kLogoSize.x, kLogoSize.y)
                TopSDmgPlayerCard.rows = {}
                TopSDmgPlayerCard.teamNumber = -2
                TopSDmgPlayerCard.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
                TopSDmgPlayerCard.background:SetPosition(Vector(kTitleSize.x - kCardSize.x - GUILinearScale(32),
                    kBackgroundSize.y + GUILinearScale(16), 0))
                table.insert(TopSDmgPlayerCard.rows,
                    CreateTopPlayerSmallRow(TopSDmgPlayerCard.tableBackground, kAverageRowColor, Color(1, 1, 1, 1),
                        TopSDmgPlayer, "Structure Damage", humanNumber(roundNumber(TopSDmgPlayer.sdmg, 0))))
                self.topPlayersCards.sdmg = TopSDmgPlayerCard
            end
        end

        -- Top Player Dmg
        TopPDmgPlayer = finalStatsTable[tblIndexSortSubValue(finalStatsTable, "pdmg")]
        if TopPDmgPlayer.pdmg > 400 then
            if TopPDmgPlayer.isMarine then
                topScoreLogoTexture = kMarineStatsLogo
            else
                topScoreLogoTexture = kAlienStatsLogo
            end
            local TopPDmgPlayerCard = self:CreateGraphicHeader("Top Damage", bgColor, topScoreLogoTexture,
                Vector(10, 10, 0), kLogoSize.x, kLogoSize.y)
            TopPDmgPlayerCard.rows = {}
            TopPDmgPlayerCard.teamNumber = -2
            TopPDmgPlayerCard.background:SetPosition(Vector(GUILinearScale(32),
                kBackgroundSize.y + GUILinearScale(146 + 16), 0))
            table.insert(TopPDmgPlayerCard.rows,
                CreateTopPlayerSmallRow(TopPDmgPlayerCard.tableBackground, kAverageRowColor, Color(1, 1, 1, 1),
                    TopPDmgPlayer, "Player Damage", humanNumber(roundNumber(TopPDmgPlayer.pdmg, 0))))
            self.topPlayersCards.pdmg = TopPDmgPlayerCard
        end

        -- Top Welder/Builder
        TopBuildTimePlayer = finalStatsTable[tblIndexSortSubValue(finalStatsTable, "minutesBuilding")]
        local minutes = math.floor(TopBuildTimePlayer.minutesBuilding)
        if minutes > 1 then
            local seconds = (TopBuildTimePlayer.minutesBuilding % 1) * 60
            if TopBuildTimePlayer.isMarine then
                topScoreLogoTexture = kMarineStatsLogo
            else
                topScoreLogoTexture = kAlienStatsLogo
            end
            local TopBuildTimePlayerCard = self:CreateGraphicHeader("Welder/Builder", bgColor, topScoreLogoTexture,
                Vector(10, 10, 0), kLogoSize.x, kLogoSize.y)
            TopBuildTimePlayerCard.rows = {}
            TopBuildTimePlayerCard.teamNumber = -2
            TopBuildTimePlayerCard.background:SetPosition(Vector(kTitleSize.x - kCardSize.x - GUILinearScale(32),
                kBackgroundSize.y + GUILinearScale(146 + 16), 0))
            table.insert(TopBuildTimePlayerCard.rows,
                CreateTopPlayerSmallRow(TopBuildTimePlayerCard.tableBackground, kAverageRowColor, Color(1, 1, 1, 1),
                    TopBuildTimePlayer, "Time", string.format("%d:%02d", minutes, seconds)))
            self.topPlayersCards = TopBuildTimePlayerCard
        end
    end
end

local function enumContainsKey(enum, StringValue)
    for key, value in pairs(enum) do
        if tostring(key) == StringValue then
            return true
        end
    end

    return false
end

function GetEalEntry(techName)
    for index, row in ipairs(equipmentAndLifeformsLogTable) do
        if row.name == techName then
            return row
        end
    end
    return nil
end

function GUIGameEndStats:BuildEALGraph()
    self.topPlayersCards.ealcards = {}
    if self.equipmentAndLifeformsTextShadow:GetIsVisible() then
        local techName = ""
        local equipmentAndLifeformsAlienCard = self:CreateEALGraphicHeader("Lifeforms", kAlienStatsColor,
            kAlienStatsLogo, Vector(10, 10, 0), kLogoSize.x, kLogoSize.y, "EVOLVED", "LOST")
        equipmentAndLifeformsAlienCard.rows = {}
        equipmentAndLifeformsAlienCard.teamNumber = -2
        local yPos = (366 > kBackgroundSize.y) and 366 or kBackgroundSize.y
        if self.topPlayersTextShadow:GetIsVisible() then
            equipmentAndLifeformsAlienCard.background:SetPosition(
                Vector(GUILinearScale(32) / 2, GUILinearScale(yPos), 0))
        else
            equipmentAndLifeformsAlienCard.background:SetPosition(
                Vector(GUILinearScale(32) / 2, GUILinearScale(16 + 32), 0))
        end

        -- Skulks
        techName = "Skulk"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end

        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 0, 340, 114 * 1}, Vector(90, 30, 0), 0, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Gorges
        techName = "Gorge"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 1, 340, 114 * 2}, Vector(90, 30, 0), 1, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Lerks
        techName = "Lerk"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 2, 340, 114 * 3}, Vector(90, 30, 0), 2, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards, itemCard)

        -- Fade
        techName = "Fade"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 3, 340, 114 * 4}, Vector(90, 30, 0), 3, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Onos
        techName = "Onos"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 4, 340, 114 * 5}, Vector(90, 30, 0), 4, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Prowler
        if enumContainsKey(kTechId, "Prowler") then -- kTechId["Prowler"] ~= nil then
            ealEntry = GetEalEntry("Prowler")
            local buyCount = 0
            local lostCount = 0
            if ealEntry then
                buyCount = ealEntry.buyCount
                lostCount = ealEntry.lostCount
            end
            local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount,
                kEalAlienTexture, {0, 114 * 5, 340, 114 * 6}, Vector(90, 30, 0), 5, false, "Prowler")
            table.insert(self.toolTipCards, itemCard.icon)
            table.insert(self.topPlayersCards.ealcards, itemCard)
        end

        -- Crag
        techName = "Crag"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 10, 340, 114 * 11}, Vector(90, 30, 0), 6, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Shade
        techName = "Shade"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 11, 340, 114 * 12}, Vector(90, 30, 0), 6.74, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Shift
        techName = "Shift"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 9, 340, 114 * 10}, Vector(90, 30, 0), 7.5, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Shell
        techName = "Shell"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 6, 340, 114 * 7}, Vector(90, 30, 0), 8.5, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Veil
        techName = "Veil"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 8, 340, 114 * 9}, Vector(90, 30, 0), 9.25, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Spur
        techName = "Spur"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsAlienCard.background, buyCount, lostCount, kEalAlienTexture,
            {0, 114 * 7, 340, 114 * 8}, Vector(90, 30, 0), 10, false, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Marines:
        local equipmentAndLifeformsMarineCard = self:CreateEALGraphicHeader("Equipment", kMarineStatsColor,
            kMarineStatsLogo, Vector(10, 10, 0), kLogoSize.x, kLogoSize.y, "BOUGHT", "LOST")
        equipmentAndLifeformsMarineCard.rows = {}
        equipmentAndLifeformsMarineCard.teamNumber = -2
        if self.topPlayersTextShadow:GetIsVisible() then
            equipmentAndLifeformsMarineCard.background:SetPosition(
                Vector(GUILinearScale(32) / 2, GUILinearScale(yPos + 96 - 16), 0))
        else
            equipmentAndLifeformsMarineCard.background:SetPosition(
                Vector(GUILinearScale(32) / 2, GUILinearScale(16 + 32 + 96 - 16), 0))
        end

        -- Shotgun
        techName = "Shotgun"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 2, 340, 114 * 3}, Vector(90, 30, 0), 0, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- GrenadeLauncher
        techName = "GrenadeLauncher"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 3, 340, 114 * 4}, Vector(90, 30, 0), 1, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Flamer
        techName = "Flamethrower"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 4, 340, 114 * 5}, Vector(90, 30, 0), 2, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- HeavyMachineGun
        techName = "HeavyMachineGun"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 5, 340, 114 * 6}, Vector(90, 30, 0), 3, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- JetPack
        techName = "Jetpack"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 12, 340, 114 * 13}, Vector(90, 30, 0), 4.25, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Exo Minigun
        techName = "DualMinigunExosuit"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 14, 340, 114 * 15}, Vector(90, 30, 0), 5, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Exo Railgun
        techName = "DualRailgunExosuit"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 13, 340, 114 * 14}, Vector(90, 30, 0), 5.75, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Welder
        techName = "Welder"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 7, 340, 114 * 8}, Vector(90, 30, 0), 7, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Gas Grenade
        techName = "GasGrenade"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 8, 340, 114 * 9}, Vector(90, 30, 0), 7.75, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Cluster
        techName = "ClusterGrenade"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 9, 340, 114 * 10}, Vector(90, 30, 0), 8.5, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Pulse
        techName = "PulseGrenade"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 10, 340, 114 * 11}, Vector(90, 30, 0), 9.25, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)

        -- Mine
        techName = "LayMines"
        ealEntry = GetEalEntry(techName)
        local buyCount = 0
        local lostCount = 0
        if ealEntry then
            buyCount = ealEntry.buyCount
            lostCount = ealEntry.lostCount
        end
        local itemCard = CreateEalIcon(equipmentAndLifeformsMarineCard.background, buyCount, lostCount,
            kEalMarineArmoryTexture, {0, 114 * 11, 340, 114 * 12}, Vector(90, 30, 0), 10, true, Locale.ResolveString(
                LookupTechData(kTechId[techName], kTechDataDisplayName, "unknown")))
        table.insert(self.toolTipCards, itemCard.icon)
        table.insert(self.topPlayersCards.ealcards, itemCard)
        self.topEalCards.Aliens = equipmentAndLifeformsAlienCard
        self.topEalCards.Marines = equipmentAndLifeformsMarineCard
    end
end

function GUIGameEndStats:BuildTSSGraph()
    -- "Lifeforms", kAlienStatsColor, kAlienStatsLogo, Vector(10, 10, 0), kLogoSize.x, kLogoSize.y, "EVOLVED", "LOST"

    local AlienItem = {}

    AlienItem.background = GUIManager:CreateGraphicItem()
    AlienItem.background:SetStencilFunc(GUIItem.NotEqual)
    AlienItem.background:SetColor(kAlienStatsColor)
    AlienItem.background:SetTexture(kHeaderTexture)
    AlienItem.background:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsMiddle))
    AlienItem.background:SetAnchor(GUIItem.Middle, GUIItem.Top)
    AlienItem.background:SetInheritsParentAlpha(false)
    AlienItem.background:SetLayer(kGUILayerMainMenu)
    AlienItem.background:SetSize(Vector(kTitleSize.x - GUILinearScale(64), kTitleSize.y + 10, 0))
    local yPos = self.TssTextShadow:GetPosition().y + GUILinearScale(32)
    self.background:AddChild(AlienItem.background)

    AlienItem.backgroundLeft = GUIManager:CreateGraphicItem()
    AlienItem.backgroundLeft:SetStencilFunc(GUIItem.NotEqual)
    AlienItem.backgroundLeft:SetColor(kAlienStatsColor)
    AlienItem.backgroundLeft:SetTexture(kHeaderTexture)
    AlienItem.backgroundLeft:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsLeft))
    AlienItem.backgroundLeft:SetAnchor(GUIItem.Left, GUIItem.Top)
    AlienItem.backgroundLeft:SetInheritsParentAlpha(false)
    AlienItem.backgroundLeft:SetLayer(kGUILayerMainMenu)
    AlienItem.backgroundLeft:SetSize(Vector(GUILinearScale(16), kTitleSize.y + 10, 0))
    AlienItem.backgroundLeft:SetPosition(Vector(-GUILinearScale(16), 0, 0))
    AlienItem.background:AddChild(AlienItem.backgroundLeft)

    AlienItem.backgroundRight = GUIManager:CreateGraphicItem()
    -- AlienItem.backgroundRight:SetStencilFunc(GUIItem.NotEqual)
    AlienItem.backgroundRight:SetColor(kAlienStatsColor)
    AlienItem.backgroundRight:SetTexture(kHeaderTexture)
    AlienItem.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
    AlienItem.backgroundRight:SetAnchor(GUIItem.Left, GUIItem.Top)
    AlienItem.backgroundRight:SetInheritsParentAlpha(false)
    AlienItem.backgroundRight:SetLayer(kGUILayerMainMenu)
    AlienItem.backgroundRight:SetSize(Vector(GUILinearScale(16), kTitleSize.y + 10, 0))
    AlienItem.backgroundRight:SetPosition(Vector(kTitleSize.x - GUILinearScale(64), 0, 0))
    AlienItem.background:AddChild(AlienItem.backgroundRight)

    local xOffset = kLogoOffset

    logoSizeX = GUILinearScale(kLogoSize.x)
    logoSizeY = GUILinearScale(kLogoSize.y)

    AlienItem.logo = GUIManager:CreateGraphicItem()
    AlienItem.logo:SetStencilFunc(GUIItem.NotEqual)
    AlienItem.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
    AlienItem.logo:SetLayer(kGUILayerMainMenu)
    AlienItem.logo:SetIsVisible(true)
    AlienItem.logo:SetSize(Vector(logoSizeX, logoSizeY, 0))
    AlienItem.logo:SetPosition(Vector(kLogoOffset, -logoSizeY / 2, 0))
    AlienItem.logo:SetTexture(kAlienStatsLogo)
    AlienItem.logo:SetTexturePixelCoordinates(GUIUnpackCoords(Vector(10, 10, 0)))
    AlienItem.background:AddChild(AlienItem.logo)

    xOffset = xOffset + logoSizeX + kTeamNameOffset

    self.topTssCards.AlienItem = AlienItem

    local MarineItem = {}

    MarineItem.background = GUIManager:CreateGraphicItem()
    MarineItem.background:SetStencilFunc(GUIItem.NotEqual)
    MarineItem.background:SetColor(kMarineStatsColor)
    MarineItem.background:SetTexture(kHeaderTexture)
    MarineItem.background:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsMiddle))
    MarineItem.background:SetAnchor(GUIItem.Left, GUIItem.Top)
    MarineItem.background:SetInheritsParentAlpha(false)
    MarineItem.background:SetLayer(kGUILayerMainMenu)
    MarineItem.background:SetSize(Vector(kTitleSize.x - GUILinearScale(64), kTitleSize.y + 10, 0))
    self.background:AddChild(MarineItem.background)

    MarineItem.backgroundLeft = GUIManager:CreateGraphicItem()
    MarineItem.backgroundLeft:SetStencilFunc(GUIItem.NotEqual)
    MarineItem.backgroundLeft:SetColor(kMarineStatsColor)
    MarineItem.backgroundLeft:SetTexture(kHeaderTexture)
    MarineItem.backgroundLeft:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsLeft))
    MarineItem.backgroundLeft:SetAnchor(GUIItem.Left, GUIItem.Top)
    MarineItem.backgroundLeft:SetInheritsParentAlpha(false)
    MarineItem.backgroundLeft:SetLayer(kGUILayerMainMenu)
    MarineItem.backgroundLeft:SetSize(Vector(GUILinearScale(16), kTitleSize.y + 10, 0))
    MarineItem.backgroundLeft:SetPosition(Vector(-GUILinearScale(16), 0, 0))
    MarineItem.background:AddChild(MarineItem.backgroundLeft)

    MarineItem.backgroundRight = GUIManager:CreateGraphicItem()
    MarineItem.backgroundRight:SetStencilFunc(GUIItem.NotEqual)
    MarineItem.backgroundRight:SetColor(kMarineStatsColor)
    MarineItem.backgroundRight:SetTexture(kHeaderTexture)
    MarineItem.backgroundRight:SetTexturePixelCoordinates(GUIUnpackCoords(kHeaderCoordsRight))
    MarineItem.backgroundRight:SetAnchor(GUIItem.Left, GUIItem.Top)
    MarineItem.backgroundRight:SetInheritsParentAlpha(false)
    MarineItem.backgroundRight:SetLayer(kGUILayerMainMenu)
    MarineItem.backgroundRight:SetSize(Vector(GUILinearScale(16), kTitleSize.y + 10, 0))
    MarineItem.backgroundRight:SetPosition(Vector(kTitleSize.x - GUILinearScale(64), 0, 0))
    MarineItem.background:AddChild(MarineItem.backgroundRight)

    local xOffset = kLogoOffset

    logoSizeX = GUILinearScale(kLogoSize.x)
    logoSizeY = GUILinearScale(kLogoSize.y)

    MarineItem.logo = GUIManager:CreateGraphicItem()
    MarineItem.logo:SetStencilFunc(GUIItem.NotEqual)
    MarineItem.logo:SetAnchor(GUIItem.Left, GUIItem.Center)
    MarineItem.logo:SetLayer(kGUILayerMainMenu)
    MarineItem.logo:SetIsVisible(true)
    MarineItem.logo:SetSize(Vector(logoSizeX, logoSizeY, 0))
    MarineItem.logo:SetPosition(Vector(kLogoOffset, -logoSizeY / 2, 0))
    MarineItem.logo:SetTexture(kMarineStatsLogo)
    MarineItem.logo:SetTexturePixelCoordinates(GUIUnpackCoords(Vector(10, 10, 0)))

    MarineItem.background:AddChild(MarineItem.logo)

    xOffset = xOffset + logoSizeX + kTeamNameOffset

    self.topTssCards.MarineItem = MarineItem
    local tssItem
    -- Process Alien Stats
    local i = 0
    local ItemNr = 0
    if teamSpecificStatsLogTable["alienSpecialKill"] then
        tssItem = CreateTssItem(AlienItem.background, teamSpecificStatsLogTable["alienSpecialKill"], 0, "Easy Prey",
            false, false, ItemNr, "Kills with parasite, babbler or healspray")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["Parasite"] then
        tssItem = CreateTssItem(AlienItem.background, teamSpecificStatsLogTable["Parasite"], 2, "Parasites", false,
            false, ItemNr, "Parasites per min as skulk\nOnly marine, mine, phasegate or arc count")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["MineKills"] then
        tssItem = CreateTssItem(AlienItem.background, teamSpecificStatsLogTable["MineKills"], 0, "Minesweeper", false,
            false, ItemNr, "Most mines triggered or destroyed")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["GorgeHealPlayer"] then
        tssItem = CreateTssItem(AlienItem.background, teamSpecificStatsLogTable["GorgeHealPlayer"], 0, "Field Doctor",
            false, false, ItemNr, "Amount of healing done to other alien players")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["GorgeHealStruct"] then
        tssItem = CreateTssItem(AlienItem.background, teamSpecificStatsLogTable["GorgeHealStruct"], 0,
            "Bob the Builder", false, false, ItemNr, "Amount of healing done to structures")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["alienRtDamage"] then
        tssItem = CreateTssItem(AlienItem.background, teamSpecificStatsLogTable["alienRtDamage"], 0, "Resource Eater",
            false, false, ItemNr, "Amount of damage done to resource towers")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    -- Marines
    ItemNr = 0
    if teamSpecificStatsLogTable["marineSpecialKill"] then
        tssItem = CreateTssItem(MarineItem.background, teamSpecificStatsLogTable["marineSpecialKill"], 0,
            "Who Needs Bullets", nil, nil, ItemNr, "Kills with axe, welder, riflebutt or grenades")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["WeldPlayer"] then
        tssItem = CreateTssItem(MarineItem.background, teamSpecificStatsLogTable["WeldPlayer"], 0, "Field Doctor", nil,
            nil, ItemNr, "Most welding on other marine players")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["WeldStruct"] then
        tssItem = CreateTssItem(MarineItem.background, teamSpecificStatsLogTable["WeldStruct"], 0, "Repair Bot", nil,
            nil, ItemNr, "Most welding done on marine structures")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["MineDrops"] then
        tssItem = CreateTssItem(MarineItem.background, teamSpecificStatsLogTable["MineDrops"], 0, "Mine Operator", nil,
            nil, ItemNr, "Most mines successfully placed")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["MarineMedsReceived"] then
        tssItem = CreateTssItem(MarineItem.background, teamSpecificStatsLogTable["MarineMedsReceived"], 0,
            "High Maintenance", nil, nil, ItemNr, "Most medpacks received/picked up")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end

    if teamSpecificStatsLogTable["marineRtDamage"] then
        tssItem = CreateTssItem(MarineItem.background, teamSpecificStatsLogTable["marineRtDamage"], 0, "Node Clearer",
            nil, nil, ItemNr, "Amount of damage done to resource towers")
        table.insert(self.toolTipCards, tssItem.labelText)
        table.insert(self.toolTipCards, tssItem.avatar)
        ItemNr = ItemNr + 1
    end
end

-- Todo: Split this monster into submethods
function GUIGameEndStats:ProcessStats()
    table.sort(finalStatsTable, function(a, b)
        a.teamNumber = a.isMarine and 1 or 2
        b.teamNumber = b.isMarine and 1 or 2
        a.realAccuracy = a.accuracyOnos == -1 and a.accuracy or a.accuracyOnos
        b.realAccuracy = b.accuracyOnos == -1 and b.accuracy or b.accuracyOnos
        a.lowerCaseName = string.UTF8Lower(a.playerName)
        b.lowerCaseName = string.UTF8Lower(b.playerName)
        if a.teamNumber == b.teamNumber then
            if a.kills == b.kills then
                if a.assists == b.assists then
                    if a.deaths == b.deaths then
                        if a.realAccuracy == b.realAccuracy then
                            if a.pdmg == b.pdmg then
                                if a.sdmg == b.sdmg then
                                    if a.minutesBuilding == b.minutesBuilding then
                                        return a.lowerCaseName < b.lowerCaseName
                                    else
                                        return a.minutesBuilding > b.minutesBuilding
                                    end
                                else
                                    return a.sdmg > b.sdmg
                                end
                            else
                                return a.pdmg > b.pdmg
                            end
                        else
                            return a.accuracy > b.accuracy
                        end
                    else
                        return a.deaths < b.deaths
                    end
                else
                    return a.assists > b.assists
                end
            else
                return a.kills > b.kills
            end
        else
            return a.teamNumber < b.teamNumber
        end
    end)

    table.sort(cardsTable, function(a, b)
        if a.order and b.order then
            return a.order < b.order
        elseif a.teamNumber == b.teamNumber then
            if a.message.kills and b.message.kills then
                a.message.realAccuracy = a.message.accuracyOnos == -1 and a.message.accuracy or a.message.accuracyOnos
                b.message.realAccuracy = b.message.accuracyOnos == -1 and b.message.accuracy or b.message.accuracyOnos
                if a.message.kills == b.message.kills then
                    return a.message.realAccuracy > b.message.realAccuracy
                else
                    return a.message.kills > b.message.kills
                end
            end
        else
            return a.teamNumber < b.teamNumber
        end
    end)

    local totalKills1 = 0
    local totalKills2 = 0
    local totalAssists1 = 0
    local totalAssists2 = 0
    local totalDeaths1 = 0
    local totalDeaths2 = 0
    local totalPdmg1 = 0
    local totalPdmg2 = 0
    local totalSdmg1 = 0
    local totalSdmg2 = 0
    local totalTimeBuilding1 = 0
    local totalTimeBuilding2 = 0
    local totalTimePlaying1 = 0
    local totalTimePlaying2 = 0
    local avgAccuracy1 = 0
    local avgAccuracy1Onos = 0
    local avgAccuracy2 = 0
    local team1Score = 0
    local team2Score = 0
    local team1Comm = 0
    local team2Comm = 0
    local team1CommTime = 0
    local team2CommTime = 0

    self:Uninitialize()
    self:Initialize()

    for _, message in ipairs(finalStatsTable) do
        -- Initialize the values in case there's something missing
        message.isMarine = message.isMarine or false
        message.playerName = message.playerName or "NSPlayer"
        message.kills = message.kills or 0
        message.assists = message.assists or 0
        message.deaths = message.deaths or 0
        message.accuracy = message.accuracy or 0
        message.accuracyOnos = message.accuracyOnos or -1
        message.score = message.score or 0
        message.pdmg = message.pdmg or 0
        message.sdmg = message.sdmg or 0
        message.minutesBuilding = message.minutesBuilding or 0
        message.minutesPlaying = message.minutesPlaying or 0
        message.minutesComm = message.minutesComm or 0
        message.killstreak = message.killstreak or 0
        message.steamId = message.steamId or 1
        message.isRookie = message.isRookie or false
        message.hiveSkill = message.hiveSkill or -1

        local isMarine = message.isMarine

        -- save player stats into a map for later usage (e.g. hive skill graph)
        local teamNumber = isMarine and 1 or 2
        if not playerStatMap[teamNumber] then
            playerStatMap[teamNumber] = {}
        end
        playerStatMap[teamNumber][message.steamId] = message

        local minutes = math.floor(message.minutesBuilding)
        local seconds = (message.minutesBuilding % 1) * 60

        local pMinutes = math.floor(message.minutesPlaying)
        local pSeconds = (message.minutesPlaying % 1) * 60

        local cMinutes = math.floor(message.minutesComm)
        local cSeconds = (message.minutesComm % 1) * 60

        local teamObj

        if isMarine then
            teamObj = self.team1UI
            totalKills1 = totalKills1 + message.kills
            totalAssists1 = totalAssists1 + message.assists
            totalDeaths1 = totalDeaths1 + message.deaths
            totalPdmg1 = totalPdmg1 + message.pdmg
            totalSdmg1 = totalSdmg1 + message.sdmg
            totalTimeBuilding1 = totalTimeBuilding1 + message.minutesBuilding
            totalTimePlaying1 = totalTimePlaying1 + message.minutesPlaying
            avgAccuracy1 = avgAccTable.marineAcc
            avgAccuracy1Onos = avgAccTable.marineOnosAcc
            team1Score = team1Score + message.score
        else
            teamObj = self.team2UI
            totalKills2 = totalKills2 + message.kills
            totalAssists2 = totalAssists2 + message.assists
            totalDeaths2 = totalDeaths2 + message.deaths
            totalPdmg2 = totalPdmg2 + message.pdmg
            totalSdmg2 = totalSdmg2 + message.sdmg
            totalTimeBuilding2 = totalTimeBuilding2 + message.minutesBuilding
            totalTimePlaying2 = totalTimePlaying2 + message.minutesPlaying
            avgAccuracy2 = avgAccTable.alienAcc
            team2Score = team2Score + message.score
        end

        local playerCount = #teamObj.playerRows
        local bgColor = isMarine and kMarinePlayerStatsOddColor or kAlienPlayerStatsOddColor
        local playerTextColor = kPlayerStatsTextColor
        if playerCount % 2 == 0 then
            bgColor = isMarine and kMarinePlayerStatsEvenColor or kAlienPlayerStatsEvenColor
        end

        -- Color our own row in a different color
        if message.steamId == Client.GetSteamId() then
            bgColor = kCurrentPlayerStatsColor
            playerTextColor = kCurrentPlayerStatsTextColor
        end

        local playerScoreboardRow = CreateScoreboardRow(teamObj.tableBackground, bgColor, playerTextColor,
            message.playerName, printNum(message.kills), printNum(message.assists), printNum(message.deaths),
            message.accuracyOnos == -1 and string.format("%s%%", round(message.accuracy, 0)) or
                string.format("%s%% (%s%%)", round(message.accuracy, 0), round(message.accuracyOnos, 0)),
            round(message.score, 0), humanNumber(roundNumber(message.pdmg, 0)),
            humanNumber(roundNumber(message.sdmg, 0)), string.format("%d:%02d", minutes, seconds),
            string.format("%d:%02d", pMinutes, pSeconds), message.minutesComm > 0 and
                string.format("%d:%02d", cMinutes, cSeconds) or nil, message.steamId, message.isRookie,
            message.hiveSkill)
        table.insert(self.toolTipCards, playerScoreboardRow.skillIcon) -- mee
        if message["accuracyFiltered"] and message["accuracyFiltered"] ~= "NaN" then
            playerScoreboardRow.acc.tooltip = message["accuracyFiltered"]
            table.insert(self.toolTipCards, playerScoreboardRow.acc)
        end

        table.insert(teamObj.playerRows, playerScoreboardRow)
        -- Store some of the original info so we can sort afterwards
        teamObj.playerRows[#teamObj.playerRows].originalOrder = playerCount
        teamObj.playerRows[#teamObj.playerRows].message = message

        if isMarine and message.minutesComm > team1CommTime then
            team1Comm = playerCount + 1
            team1CommTime = message.minutesComm
            DIPS_MarineCommID = message.steamId
        elseif not isMarine and message.minutesComm > team2CommTime then
            team2Comm = playerCount + 1
            team2CommTime = message.minutesComm
            DIPS_AlienCommID = message.steamId
        end
    end

    if team1Comm > 0 then
        if self.team1UI.playerRows[team1Comm].message then
            self.team1UI.playerRows[team1Comm].commIcon:SetTexture(kCommBadgeTexture)
        end
    end

    if team2Comm > 0 then
        if self.team2UI.playerRows[team2Comm] then
            self.team2UI.playerRows[team2Comm].commIcon:SetTexture(kCommBadgeTexture)
        end
    end

    local numPlayers1 = #self.team1UI.playerRows - 1
    local numPlayers2 = #self.team2UI.playerRows - 1
    self:SetPlayerCount(self.team1UI, numPlayers1)
    self:SetPlayerCount(self.team2UI, numPlayers2)
    miscDataTable.team1PlayerCount = numPlayers1
    miscDataTable.team2PlayerCount = numPlayers2
    self:SetTeamName(self.team1UI, miscDataTable.team1Name or Locale.ResolveString("NAME_TEAM_1"))
    self:SetTeamName(self.team2UI, miscDataTable.team2Name or Locale.ResolveString("NAME_TEAM_2"))
    local team1Result, team2Result = "DRAW", "DRAW"
    if miscDataTable.winningTeam > 0 then
        team1Result = miscDataTable.winningTeam == kMarineTeamType and "WINNER" or "LOSER"
        team2Result = miscDataTable.winningTeam == kAlienTeamType and "WINNER" or "LOSER"
    end
    self:SetGameResult(self.team1UI, team1Result)
    self:SetGameResult(self.team2UI, team2Result)

    local minutes1 = math.floor(totalTimeBuilding1)
    local seconds1 = (totalTimeBuilding1 % 1) * 60
    totalTimeBuilding1 = totalTimeBuilding1 / numPlayers1
    local minutes1Avg = math.floor(totalTimeBuilding1)
    local seconds1Avg = (totalTimeBuilding1 % 1) * 60

    totalTimePlaying1 = totalTimePlaying1 / numPlayers1
    local minutes1PAvg = math.floor(totalTimePlaying1)
    local seconds1PAvg = (totalTimePlaying1 % 1) * 60

    local minutes2 = math.floor(totalTimeBuilding2)
    local seconds2 = (totalTimeBuilding2 % 1) * 60
    totalTimeBuilding2 = totalTimeBuilding2 / numPlayers2
    local minutes2Avg = math.floor(totalTimeBuilding2)
    local seconds2Avg = (totalTimeBuilding2 % 1) * 60

    totalTimePlaying2 = totalTimePlaying2 / numPlayers2
    local minutes2PAvg = math.floor(totalTimePlaying2)
    local seconds2PAvg = (totalTimePlaying2 % 1) * 60

    -- When there's only one player in a team, the total and the average will be the same
    -- Don't even bother displaying this, it looks odd
    if numPlayers1 > 1 then
        table.insert(self.team1UI.playerRows,
            CreateScoreboardRow(self.team1UI.tableBackground, kHeaderRowColor, kMarineHeaderRowTextColor, "Total",
                printNum(totalKills1), printNum(totalAssists1), printNum(totalDeaths1), " ", round(team1Score, 0),
                round(totalPdmg1, 0), round(totalSdmg1, 0), string.format("%d:%02d", minutes1, seconds1)))
        table.insert(self.team1UI.playerRows,
            CreateScoreboardRow(self.team1UI.tableBackground, kAverageRowColor, kAverageRowTextColor, "Average",
                round(totalKills1 / numPlayers1, 0), round(totalAssists1 / numPlayers1, 0),
                round(totalDeaths1 / numPlayers1, 0),
                avgAccuracy1Onos == -1 and string.format("%s%%", round(avgAccuracy1, 0)) or
                    string.format("%s%% (%s%%)", round(avgAccuracy1, 0), round(avgAccuracy1Onos, 0)),
                round(team1Score / numPlayers1, 0), round(totalPdmg1 / numPlayers1, 0),
                round(totalSdmg1 / numPlayers1, 0), string.format("%d:%02d", minutes1Avg, seconds1Avg),
                string.format("%d:%02d", minutes1PAvg, seconds1PAvg)))
    end
    if numPlayers2 > 1 then
        table.insert(self.team2UI.playerRows,
            CreateScoreboardRow(self.team2UI.tableBackground, kHeaderRowColor, kAlienHeaderRowTextColor, "Total",
                printNum(totalKills2), printNum(totalAssists2), printNum(totalDeaths2), " ", round(team2Score, 0),
                round(totalPdmg2, 0), round(totalSdmg2, 0), string.format("%d:%02d", minutes2, seconds2)))
        table.insert(self.team2UI.playerRows,
            CreateScoreboardRow(self.team2UI.tableBackground, kAverageRowColor, kAverageRowTextColor, "Average",
                round(totalKills2 / numPlayers2, 0), round(totalAssists2 / numPlayers2, 0),
                round(totalDeaths2 / numPlayers2, 0), string.format("%s%%", round(avgAccuracy2, 0)),
                round(team2Score / numPlayers2, 0), round(totalPdmg2 / numPlayers2, 0),
                round(totalSdmg2 / numPlayers2, 0), string.format("%d:%02d", minutes2Avg, seconds2Avg),
                string.format("%d:%02d", minutes2PAvg, seconds2PAvg)))
    end

    local gameInfo = GetGameInfoEntity()
    local teamStatsVisible = gameInfo.showEndStatsTeamBreakdown

    if miscDataTable.gameLengthMinutes > 2 then
        self.topPlayersTextShadow:SetIsVisible(teamStatsVisible)
    end

    if equipmentAndLifeformsLogTable and #equipmentAndLifeformsLogTable > 0 then
        HPrint("- Using enhanced stats for scoreboard!")
        DIPS_EnahncedStats = true
        self.hiveSkillGraphTextShadow:SetText("HIVESKILL GRAPH (Enhanced)")
        self.hiveSkillGraphText:SetText("HIVESKILL GRAPH (Enhanced)")
        self.equipmentAndLifeformsTextShadow:SetIsVisible(teamStatsVisible)
        self.TssTextShadow:SetIsVisible(teamStatsVisible)
    else
        HPrint("- Using legacy data for stats. Scoreboard limited.")
        DIPS_EnahncedStats = false
    end

    self.team1UI.background:SetIsVisible(teamStatsVisible)
    self.team2UI.background:SetIsVisible(teamStatsVisible)
    self.teamStatsTextShadow:SetIsVisible(teamStatsVisible)

    self.roundDate:SetText(string.format("Round date: %s", miscDataTable.roundDateString))
    self.gameLength:SetText(string.format("Game length: %s", miscDataTable.gameLength))
    self.serverName:SetText(string.format("Server name: %s", miscDataTable.serverName))
    self.mapName:SetText(string.format("Map: %s", miscDataTable.mapName))

    -- My graph functions
    self:BuildTopWinGraph()
    self:BuildTopPlayersGraph()
    self:BuildEALGraph()
    if self.TssTextShadow:GetIsVisible() then
        self:BuildTSSGraph()
    end

    if #statusSummaryTable > 0 then
        table.sort(statusSummaryTable, function(a, b)
            if a.timeMinutes == b.timeMinutes then
                return a.className < b.className
            else
                return a.timeMinutes > b.timeMinutes
            end
        end)

        local bgColor = kStatusStatsColor
        local statCard = self:CreateGraphicHeader("Class time distribution", bgColor)
        statCard.rows = {}
        statCard.teamNumber = -2

        local totalTime = 0
        for _, row in ipairs(statusSummaryTable) do
            totalTime = totalTime + row.timeMinutes
        end

        -- Class time dist
        for index, row in ipairs(statusSummaryTable) do
            bgColor = ConditionalValue(index % 2 == 0, kMarinePlayerStatsEvenColor, kMarinePlayerStatsOddColor)
            local minutes = math.floor(row.timeMinutes)
            local seconds = (row.timeMinutes % 1) * 60
            local percentage = row.timeMinutes / totalTime * 100
            table.insert(statCard.rows,
                CreateHeaderRow(statCard.tableBackground, bgColor, Color(1, 1, 1, 1), row.className,
                    string.format("%d:%02d (%s%%)", minutes, seconds, round(percentage, 0))))
        end
        table.insert(self.statsCards, statCard)
    end

    -- Lifeform/Weapon cards
    for _, card in ipairs(cardsTable) do
        local bgColor
        if card.teamNumber == 1 then
            bgColor = kMarineStatsColor
        elseif card.teamNumber == 2 then
            bgColor = kAlienStatsColor
        else
            bgColor = kCommanderStatsColor
        end
        local statCard = self:CreateGraphicHeader(card.text, bgColor, card.logoTexture, card.logoCoords, card.logoSizeX,
            card.logoSizeY)
        statCard.rows = {}
        statCard.teamNumber = card.teamNumber

        for index, row in ipairs(card.rows) do
            if card.teamNumber == 1 then
                bgColor = ConditionalValue(index % 2 == 0, kMarinePlayerStatsEvenColor, kMarinePlayerStatsOddColor)
            elseif card.teamNumber == 2 then
                bgColor = ConditionalValue(index % 2 == 0, kAlienPlayerStatsEvenColor, kAlienPlayerStatsOddColor)
            else
                bgColor = ConditionalValue(index % 2 == 0, kCommanderStatsEvenColor, kCommanderStatsOddColor)
            end

            table.insert(statCard.rows,
                CreateHeaderRow(statCard.tableBackground, bgColor, Color(1, 1, 1, 1), row.title, row.value))
        end
        table.insert(self.statsCards, statCard)
    end

    if #techLogTable > 0 or #buildingSummaryTable > 0 then
        table.sort(techLogTable, function(a, b)
            if a.teamNumber == b.teamNumber then
                if a.finishedMinute == b.finishedMinute then
                    return a.name > b.name
                else
                    return a.finishedMinute < b.finishedMinute
                end
            else
                return a.teamNumber < b.teamNumber
            end
        end)

        table.sort(buildingSummaryTable, function(a, b)
            if a.teamNumber == b.teamNumber then
                if a.built == b.built then
                    if a.lost == b.lost then
                        return a.techId < b.techId
                    else
                        return a.lost > b.lost
                    end
                else
                    return a.built > b.built
                end
            else
                return a.teamNumber < b.teamNumber
            end
        end)

        local team1Name = miscDataTable.team1Name or Locale.ResolveString("NAME_TEAM_1")
        local team2Name = miscDataTable.team2Name or Locale.ResolveString("NAME_TEAM_2")

        self.techLogs[1] = {}
        self.techLogs[1].header = self:CreateTechLogHeader(1, team1Name)
        self.techLogs[1].rows = {}

        self.techLogs[2] = {}
        self.techLogs[2].header = self:CreateTechLogHeader(2, team2Name)
        self.techLogs[2].rows = {}

        -- Right now we only have marine comm stats so...
        if commanderStats then
            table.insert(self.techLogs[1].rows,
                CreateCommStatsRow(self.techLogs[1].header.tableBackground, kHeaderRowColor, kMarineHeaderRowTextColor,
                    "Commander Stats", "Acc.", "Effic.", "Refilled", "Picked", "Expired"))

            local row = 1

            if commanderStats.medpackResUsed > 0 or commanderStats.medpackResExpired > 0 then
                table.insert(self.techLogs[1].rows, CreateCommStatsRow(self.techLogs[1].header.tableBackground,
                    row % 2 == 0 and kMarinePlayerStatsEvenColor or kMarinePlayerStatsOddColor,
                    kMarineHeaderRowTextColor, "Medpacks", round(commanderStats.medpackAccuracy, 0) .. "%", round(
                        commanderStats.medpackEfficiency, 0) .. "%", commanderStats.medpackRefill,
                    commanderStats.medpackResUsed, commanderStats.medpackResExpired, kBuildMenuTexture,
                    GetTextureCoordinatesForIcon(kTechId.MedPack), 24, 24, kIconColors[1]))
                row = row + 1
            end

            if commanderStats.ammopackResUsed > 0 or commanderStats.ammopackResExpired > 0 then
                table.insert(self.techLogs[1].rows, CreateCommStatsRow(self.techLogs[1].header.tableBackground,
                    row % 2 == 0 and kMarinePlayerStatsEvenColor or kMarinePlayerStatsOddColor,
                    kMarineHeaderRowTextColor, "Ammopacks", "-", round(commanderStats.ammopackEfficiency, 0) .. "%",
                    commanderStats.ammopackRefill, commanderStats.ammopackResUsed, commanderStats.ammopackResExpired,
                    kBuildMenuTexture, GetTextureCoordinatesForIcon(kTechId.AmmoPack), 24, 24, kIconColors[1]))
                row = row + 1
            end

            if commanderStats.catpackResUsed > 0 or commanderStats.catpackResExpired > 0 then
                table.insert(self.techLogs[1].rows, CreateCommStatsRow(self.techLogs[1].header.tableBackground,
                    row % 2 == 0 and kMarinePlayerStatsEvenColor or kMarinePlayerStatsOddColor,
                    kMarineHeaderRowTextColor, "Catpacks", "-", round(commanderStats.catpackEfficiency, 0) .. "%", "-",
                    commanderStats.catpackResUsed, commanderStats.catpackResExpired, kBuildMenuTexture,
                    GetTextureCoordinatesForIcon(kTechId.CatPack), 24, 24, kIconColors[1]))
            end
        end

        if #buildingSummaryTable > 0 then
            if buildingSummaryTable[1].teamNumber == 1 then
                table.insert(self.techLogs[1].rows,
                    CreateTechLogRow(self.techLogs[1].header.tableBackground, kHeaderRowColor,
                        kMarineHeaderRowTextColor, "", "Tech", "Built", "Lost"))
            end

            if buildingSummaryTable[#buildingSummaryTable].teamNumber == 2 then
                table.insert(self.techLogs[2].rows,
                    CreateTechLogRow(self.techLogs[2].header.tableBackground, kHeaderRowColor, kAlienHeaderRowTextColor,
                        "", "Tech", "Built", "Lost"))
            end

            for index, buildingEntry in ipairs(buildingSummaryTable) do
                local isMarine = buildingEntry.teamNumber == 1
                local rowTextColor = isMarine and kMarineHeaderRowTextColor or kAlienHeaderRowTextColor
                local logoColor = kIconColors[buildingEntry.teamNumber]
                local bgColor = isMarine and kMarinePlayerStatsOddColor or kAlienPlayerStatsOddColor
                if index % 2 == 0 then
                    bgColor = isMarine and kMarinePlayerStatsEvenColor or kAlienPlayerStatsEvenColor
                end

                table.insert(self.techLogs[buildingEntry.teamNumber].rows,
                    CreateTechLogRow(self.techLogs[buildingEntry.teamNumber].header.tableBackground, bgColor,
                        rowTextColor, "", buildingEntry.name, buildingEntry.built, buildingEntry.lost,
                        buildingEntry.iconTexture, buildingEntry.iconCoords, buildingEntry.iconSizeX,
                        buildingEntry.iconSizeY, logoColor))
            end
        end

        if #techLogTable > 0 then
            if techLogTable[1].teamNumber == 1 then
                table.insert(self.techLogs[1].rows,
                    CreateTechLogRow(self.techLogs[1].header.tableBackground, kHeaderRowColor,
                        kMarineHeaderRowTextColor, "Time", "Tech", "RTs", "Res"))
            end

            if techLogTable[#techLogTable].teamNumber == 2 then
                table.insert(self.techLogs[2].rows,
                    CreateTechLogRow(self.techLogs[2].header.tableBackground, kHeaderRowColor, kAlienHeaderRowTextColor,
                        "Time", "Tech", "RTs", "Res"))
            end

            for index, techLogEntry in ipairs(techLogTable) do
                local isMarine = techLogEntry.teamNumber == 1
                local isLost = techLogEntry.destroyed == true
                local rowTextColor = isMarine and kMarineHeaderRowTextColor or kAlienHeaderRowTextColor
                local logoColor = kIconColors[techLogEntry.teamNumber]
                local bgColor = isLost and kLostTechOddColor or isMarine and kMarinePlayerStatsOddColor or
                                    kAlienPlayerStatsOddColor
                if index % 2 == 0 then
                    bgColor = isLost and kLostTechEvenColor or isMarine and kMarinePlayerStatsEvenColor or
                                  kAlienPlayerStatsEvenColor
                end

                table.insert(self.techLogs[techLogEntry.teamNumber].rows,
                    CreateTechLogRow(self.techLogs[techLogEntry.teamNumber].header.tableBackground, bgColor,
                        rowTextColor, techLogEntry.finishedTime, techLogEntry.name, techLogEntry.activeRTs,
                        techLogEntry.teamRes, techLogEntry.iconTexture, techLogEntry.iconCoords, techLogEntry.iconSizeX,
                        techLogEntry.iconSizeY, logoColor))
            end
        end
    end

    self.hiveSkillGraphs = {}
    if #hiveSkillGraphTable > 0 then
        table.sort(hiveSkillGraphTable, function(a, b)
            return a.gameMinute < b.gameMinute
        end)

        self.hiveSkillGraphs[1] = {}
        self.hiveSkillGraphs[2] = {}
        local hiveSkill = {0, 0}
        local lineOffset = {0, 0.5}
        local maxHiveSkill = 0
        local minHiveSkill = 0
        local avgTeam1Skill = 0
        local avgTeam2Skill = 0

        -- Keep track of players in each team to filter out duplicate hiveSkillGraphTable join/leave entries
        local players = {{}, {}}
        -- Counting set size is not easy so keep separate track
        local playerCount = {0, 0}

        -- Iterate over the graph data table but only add a new data point after advancing in time
        -- It's not uncommon for more than 1 player to change their team at any given point in time
        -- Specially at the very begining of a round
        -- The iteration limit is #hiveSkillGraphTable + 1 to add the last data point at the very end
        local graphTime = 0
        local roundEndTime = miscDataTable.gameLengthMinutes
        for i = 1, #hiveSkillGraphTable + 1 do
            local entry = hiveSkillGraphTable[i]
            local entryTime = entry and entry.gameMinute

            -- Add data point after advancing in time or reaching the end of the data table (entry == nil) / round
            local atEnd = entry == nil or entryTime >= roundEndTime
            if atEnd or graphTime ~= entry.gameMinute then
                local gameSeconds = graphTime * 60
                if gameSeconds == 0 then
                    -- Dont show graph going from 0 to start average hive skill
                    -- The total hive skill is larger than the min average hive skill.
                    minHiveSkill = math.min(hiveSkill[1], hiveSkill[2])
                else
                    table.insert(self.hiveSkillGraphs[1], Vector(gameSeconds, avgTeam1Skill + lineOffset[1], 0))
                    table.insert(self.hiveSkillGraphs[2], Vector(gameSeconds, avgTeam2Skill + lineOffset[2], 0))
                end

                -- ToDo: Hiveskill based on highest team size
                -- avgTeam1Skill, avgTeam2Skill = hiveSkill[1] / math.max(playerCount[1], 1), hiveSkill[2] / math.max(playerCount[2], 1)
                local higherPlayercount = math.max(playerCount[1], playerCount[2], 1)
                avgTeam1Skill, avgTeam2Skill = hiveSkill[1] / higherPlayercount, hiveSkill[2] / higherPlayercount
                -- avgTeam1Skill, avgTeam2Skill = hiveSkill[1] / math.max(playerCount[1], 1), hiveSkill[2] / math.max(playerCount[2], 1)
                maxHiveSkill = math.max(maxHiveSkill, avgTeam1Skill, avgTeam2Skill)
                minHiveSkill = math.min(minHiveSkill, avgTeam1Skill, avgTeam2Skill)

                table.insert(self.hiveSkillGraphs[1], Vector(gameSeconds, avgTeam1Skill + lineOffset[1], 0))
                table.insert(self.hiveSkillGraphs[2], Vector(gameSeconds, avgTeam2Skill + lineOffset[2], 0))

                -- Reached the end, exit here
                if atEnd then
                    break
                end

                graphTime = entryTime
            end

            local id = entry.steamId
            local teamNumber = entry.teamNumber
            local isHuman = id > 0 -- don't track bots
            local playerEntry = isHuman and playerStatMap[teamNumber] and playerStatMap[teamNumber][id]
            local isPlaying = isHuman and players[teamNumber] and players[teamNumber][id]

            -- Filter out invalid data table entries
            if playerEntry and entry.joined ~= isPlaying then
                local playerSkill = math.max(playerEntry.hiveSkill, 0)
                if DIPS_EnahncedStats then
                    if teamNumber == 1 then
                        if id == DIPS_MarineCommID then
                            -- print("Marine com: " .. tostring(DIPS_MarineCommID))
                            playerSkill = math.max(playerEntry.commanderSkillMarine or playerEntry.hiveSkill, 0)
                        else
                            playerSkill = math.max(playerEntry.hiveSkillMarine or playerEntry.hiveSkill, 0)
                        end
                    else
                        if id == DIPS_AlienCommID then
                            -- print("Alien comm: " .. tostring(DIPS_AlienCommID))
                            playerSkill = math.max(playerEntry.commanderSkillAlien or playerEntry.hiveSkill, 0)
                        else
                            playerSkill = math.max(playerEntry.hiveSkillAlien or playerEntry.hiveSkill, 0)
                        end
                    end
                end
                players[teamNumber][id] = entry.joined
                playerCount[teamNumber] = playerCount[teamNumber] + ConditionalValue(entry.joined, 1, -1)
                hiveSkill[teamNumber] = hiveSkill[teamNumber] +
                                            ConditionalValue(entry.joined, playerSkill, -playerSkill)
            end
        end

        self.hiveSkillGraph:SetPoints(1, self.hiveSkillGraphs[1])
        self.hiveSkillGraph:SetPoints(2, self.hiveSkillGraphs[2])

        minHiveSkill = Round(math.max(minHiveSkill - 100, 0), -2)
        maxHiveSkill = Round(maxHiveSkill + 100, -2)
        self.hiveSkillGraph:SetYBounds(minHiveSkill, maxHiveSkill, true)

        local gameLength = miscDataTable.gameLengthMinutes * 60
        local xSpacing = GetXSpacing(gameLength)

        self.hiveSkillGraph:SetXBounds(0, gameLength)
        self.hiveSkillGraph:SetXGridSpacing(xSpacing)

        local diff = maxHiveSkill - minHiveSkill
        local yGridSpacing = diff <= 200 and 25 or diff <= 400 and 50 or diff <= 800 and 100 or Round(diff / 8, -2)
        self.hiveSkillGraph:SetYGridSpacing(yGridSpacing)
    end

    self.rtGraphs = {}
    if #rtGraphTable > 0 then
        table.sort(rtGraphTable, function(a, b)
            return a.gameMinute < b.gameMinute
        end)

        self.rtGraphs[1] = {}
        self.rtGraphs[2] = {}
        local rtCount = {0, 0}
        local lineOffset = {0, 0.05}
        local maxRTs = 0

        for _, entry in ipairs(rtGraphTable) do
            local teamNumber = entry.teamNumber
            table.insert(self.rtGraphs[teamNumber],
                Vector(entry.gameMinute * 60, rtCount[teamNumber] + lineOffset[teamNumber], 0))
            rtCount[teamNumber] = rtCount[teamNumber] + ConditionalValue(entry.destroyed, -1, 1)
            table.insert(self.rtGraphs[teamNumber],
                Vector(entry.gameMinute * 60, rtCount[teamNumber] + lineOffset[teamNumber], 0))
            maxRTs = math.max(maxRTs, rtCount[teamNumber])
        end

        self.rtGraph:SetPoints(1, self.rtGraphs[1])
        self.rtGraph:SetPoints(2, self.rtGraphs[2])
        self.rtGraph:SetYBounds(0, maxRTs + 1, true)
        local gameLength = miscDataTable.gameLengthMinutes * 60
        local xSpacing = GetXSpacing(gameLength)

        self.rtGraph:SetXBounds(0, gameLength)
        self.rtGraph:SetXGridSpacing(xSpacing)

        self.builtRTsComp:SetValues(miscDataTable.marineRTsBuilt, miscDataTable.alienRTsBuilt)
        self.lostRTsComp:SetValues(miscDataTable.marineRTsLost, miscDataTable.alienRTsLost)

        local marineAvgRTs, alienAvgRTs = CalculateAverageRTs(rtGraphTable, miscDataTable.gameLengthMinutes)
        self.avgRTsComp:SetValues(roundNumber(marineAvgRTs, 2), roundNumber(alienAvgRTs, 2))

        -- Logic to get lost unbuilt RT's
        local marineRTsLostUnbuilt = miscDataTable.marineRTsLost
        local alienRTsLostUnbuilt = miscDataTable.alienRTsLost
        for _, entry in ipairs(rtGraphTable) do
            if entry.destroyed then
                if entry.teamNumber == 1 then
                    marineRTsLostUnbuilt = marineRTsLostUnbuilt - 1
                else
                    alienRTsLostUnbuilt = alienRTsLostUnbuilt - 1
                end
            end
        end
        local rtLabelText = ""
        if miscDataTable.marineRTsBuilt > 0 then
            self.builtRTsComp:SetLeftText("(" ..
                                              round(miscDataTable.marineRTsBuilt / miscDataTable.gameLengthMinutes, 1) ..
                                              "/min)  " .. tostring(miscDataTable.marineRTsBuilt))
        end
        if miscDataTable.alienRTsBuilt > 0 then
            self.builtRTsComp:SetRightText(tostring(miscDataTable.alienRTsBuilt) .. "  (" ..
                                               round(miscDataTable.alienRTsBuilt / miscDataTable.gameLengthMinutes, 1) ..
                                               "/min)")
        end
        if miscDataTable.marineRTsLost > 0 then
            rtLabelText = "(" .. round(miscDataTable.marineRTsLost / miscDataTable.gameLengthMinutes, 1) .. "/min)  " ..
                              tostring(miscDataTable.marineRTsLost)
            if marineRTsLostUnbuilt > 0 then
                self.lostRTsComp:SetLeftText(rtLabelText .. " (" .. tostring(marineRTsLostUnbuilt) .. " Unbuilt)")
            else
                self.lostRTsComp:SetLeftText(rtLabelText)
            end
        end
        if miscDataTable.alienRTsLost > 0 then
            rtLabelText = tostring(miscDataTable.alienRTsLost) .. "  (" ..
                              round(miscDataTable.alienRTsLost / miscDataTable.gameLengthMinutes, 1) .. "/min)"
            if alienRTsLostUnbuilt > 0 then
                self.lostRTsComp:SetRightText(rtLabelText .. " (" .. tostring(alienRTsLostUnbuilt) .. " Unbuilt)")
            else
                self.lostRTsComp:SetRightText(rtLabelText)
            end
        end
    end

    self.killGraphs = {}
    if #killGraphTable > 0 then
        table.sort(killGraphTable, function(a, b)
            return a.gameMinute < b.gameMinute
        end)

        self.killGraphs[1] = {}
        self.killGraphs[2] = {}
        local teamKills = {0, 0}
        local lineOffsets = {0, 0.05}

        for _, entry in ipairs(killGraphTable) do
            local teamNumber = entry.teamNumber
            table.insert(self.killGraphs[teamNumber],
                Vector(entry.gameMinute * 60, teamKills[teamNumber] + lineOffsets[teamNumber], 0))
            teamKills[teamNumber] = teamKills[teamNumber] + 1
            table.insert(self.killGraphs[teamNumber],
                Vector(entry.gameMinute * 60, teamKills[teamNumber] + lineOffsets[teamNumber], 0))
        end

        self.killGraph:SetPoints(1, self.killGraphs[1])
        self.killGraph:SetPoints(2, self.killGraphs[2])
        local yElems = math.max(teamKills[1], teamKills[2]) + 1
        self.killGraph:SetYBounds(0, yElems, true)
        local gameLength = miscDataTable.gameLengthMinutes * 60
        local xSpacing = GetXSpacing(gameLength)
        local ySpacing = GetYSpacing(yElems)

        self.killGraph:SetXBounds(0, gameLength)
        self.killGraph:SetXGridSpacing(xSpacing)
        self.killGraph:SetYGridSpacing(ySpacing)

        self.killComparison:SetValues(teamKills[1], teamKills[2])

        if teamKills[1] > 0 then
            self.killComparison:SetLeftText(
                "(" .. round(teamKills[1] / miscDataTable.gameLengthMinutes, 1) .. "/min)  " .. tostring(teamKills[1]))
        end
        if teamKills[2] > 0 then
            self.killComparison:SetRightText(tostring(teamKills[2]) .. "  (" ..
                                                 round(teamKills[2] / miscDataTable.gameLengthMinutes, 1) .. "/min)")
        end
    end

    -- ToDo: Add tech to kill graph
    --[[
	if #techLogTable > 0 then
		for i = 1, #techLogTable do
			if techLogTable[i].teamNumber == 1 then
				local logoColor = kIconColors[1]
				local bgColor = kAlienPlayerStatsOddColor
				if i % 2 == 0 then
					bgColor = kAlienPlayerStatsEvenColor
				end
				-- Magic filter
				if startswith(techLogTable[i].name, "Weapons #") or startswith(techLogTable[i].name, "Armor #") or techLogTable[i].name == "Research Exosuits" or techLogTable[i].name == "Research Jetpacks" or techLogTable[i].name == "Advanced Support" or techLogTable[i].name == "Upgrade to Advanced Armory" or techLogTable[i].name == "Research Mines" or techLogTable[i].name == "Research hand grenades" then
					--print("Name: " .. techLogTable[i].name .. " (" .. tostring(techLogTable[i].finishedTime) .. ")")
					-- ToDo: Add icon to kill graph
					local possition = miscDataTable.gameLengthMinutes/techLogTable[i].finishedMinute
					--print("GameTime: " .. tostring(miscDataTable.gameLengthMinutes))
					--print("Possition: " .. tostring(possition))
					--print(tostring(dump(techLogTable[i])))
					--table.insert(self.killIcons, CreateKillGraphIcon(self.killGraph, possition, techLogTable[i]))
				end
				--table.insert(self.techLogs[techLogEntry.teamNumber].rows, CreateTechLogRow(self.techLogs[techLogEntry.teamNumber].header.tableBackground, bgColor, rowTextColor, techLogEntry.finishedTime, techLogEntry.name, techLogEntry.activeRTs, techLogEntry.teamRes, techLogEntry.iconTexture, techLogEntry.iconCoords, techLogEntry.iconSizeX, techLogEntry.iconSizeY, logoColor))
			end
		end
	end
	]]

    -- commented out for LessNetworkData
    --[[

    local function getPresGraphPoints(teamNumber, presTable, graphCeiling, equippedGraph, totalGraph)
        table.sort(
            presTable,
            function(a, b)
                return a.gameMinute < b.gameMinute
            end
        )

        local nextGameSecond
        local gameLength = miscDataTable.gameLengthMinutes

        -- counts up for every started 20 min interval. This limites the lines used in the graph to 1600 lines
        local graphSkipFrequency = math.ceil(gameLength / 20)

        -- used to draw the projected point with the resgain
        local projectedPoint = {}
        projectedPoint.resGain = 0

        for i = 1, #presTable do
            local entry = presTable[i]
            local gameSecond = entry.gameMinute * 60

            -- skip every second point at 20-40min rounds, 2 out of 3 points at 40-60min rounds and so on.
            -- always draw the starting point with i == 1
            if i == 1 or i % graphSkipFrequency == 0 then
                -- skip first point since there was no pres gain
                if i ~= 1 then
                    table.insert(equippedGraph, Vector(gameSecond, projectedPoint.presEquipped, 0))
                    table.insert(totalGraph, Vector(gameSecond, projectedPoint.presEquipped + projectedPoint.presUnused + projectedPoint.resGain, 0))
                end
                table.insert(equippedGraph, Vector(gameSecond, entry.presEquipped, 0))
                table.insert(totalGraph, Vector(gameSecond, entry.presEquipped + entry.presUnused, 0))

                projectedPoint.presEquipped = entry.presEquipped
                projectedPoint.presUnused = entry.presUnused
                graphCeiling = math.max(graphCeiling, projectedPoint.presEquipped + projectedPoint.presUnused + projectedPoint.resGain)
                projectedPoint.resGain = 0
            end

            -- get seconds until next point to calculate the pres gain by rts
            if presTable[i + 1] == nil then
                nextGameSecond = miscDataTable.gameLengthMinutes * 60
            else
                nextGameSecond = presTable[i + 1].gameMinute * 60
            end
            local timeBetweenPoints = nextGameSecond - gameSecond

            local resGain = entry.rtAmount * entry.playerCount * kPlayerResPerInterval * timeBetweenPoints / kResourceTowerResourceInterval
            projectedPoint.resGain = projectedPoint.resGain + resGain
        end

        -- last points
        table.insert(equippedGraph, Vector(nextGameSecond, projectedPoint.presEquipped, 0))
        table.insert(totalGraph, Vector(nextGameSecond, projectedPoint.presEquipped + projectedPoint.presUnused + projectedPoint.resGain, 0))

        return graphCeiling
    end

    -- presGraph Mod
    self.presGraphs = {}
    if #presGraphTableMarines > 0 and #presGraphTableAliens > 0 then
        self.presGraphs[1] = {} -- Marine equipped pres
        self.presGraphs[2] = {} -- Marine equipped + saved pres
        self.presGraphs[3] = {} -- Alien evolved pres
        self.presGraphs[4] = {} -- Alien evolved + saved pres
        local graphCeiling = 0

        graphCeiling = getPresGraphPoints(1, presGraphTableMarines, graphCeiling, self.presGraphs[1], self.presGraphs[2])
        graphCeiling = getPresGraphPoints(2, presGraphTableAliens, graphCeiling, self.presGraphs[3], self.presGraphs[4])

        self.presGraph:SetPoints(1, self.presGraphs[1])
        self.presGraph:SetPoints(2, self.presGraphs[2])
        self.presGraph:SetPoints(3, self.presGraphs[3])
        self.presGraph:SetPoints(4, self.presGraphs[4])

        -- spacing should be around 8-10 and starts overlapping at around 20
        -- spacing of 20 would be 10 aliens with 3 chamber upgraded onos, each 100 pres unused and multiple onos lifeform eggs..
        local yGridSpacing = graphCeiling <= 200 and 25 or graphCeiling <= 500 and 50 or 100
        local maxYBounds = math.ceil(graphCeiling / yGridSpacing) * yGridSpacing
        self.presGraph:SetYBounds(0, maxYBounds, true)
        self.presGraph:SetYGridSpacing(yGridSpacing)

        local gameLength = miscDataTable.gameLengthMinutes * 60
        local xSpacing = GetXSpacing(gameLength)
        self.presGraph:SetXBounds(0, gameLength)
        self.presGraph:SetXGridSpacing(xSpacing)
    end

    ]]

    self:RepositionStats()

    pcall(self.SaveLastRoundStats, self)

    finalStatsTable = {}
    playerStatMap = {}
    avgAccTable = {}
    miscDataTable = {}
    cardsTable = {}
    hiveSkillGraphTable = {}
    rtGraphTable = {}
    commanderStats = nil
    killGraphTable = {}
    buildingSummaryTable = {}
    statusSummaryTable = {}
    techLogTable = {}

    -- My variables
    equipmentAndLifeformsLogTable = {}
    teamSpecificStatsLogTable = {}
    DIPS_AlienCommID = nil
    DIPS_MarineCommID = nil
    DIPS_EnahncedStats = false

    -- commented out for LessNetworkData
    -- presGraphTableAliens = {}
    -- presGraphTableMarines = {}
end

function CalculateAverageRTs(rtGraphTable, gameLengthMinutes)
    local teamRTs = {
        [1] = 0,
        [2] = 0
    } -- Track total RTs for each team
    local lastRTCount = {
        [1] = 0,
        [2] = 0
    } -- Track last known RT count for each team
    local lastTimeStamp = {
        [1] = 0,
        [2] = 0
    } -- Track last timestamp for each team

    -- Sort entries by time
    table.sort(rtGraphTable, function(a, b)
        return a.gameMinute < b.gameMinute
    end)

    -- Calculate weighted average based on time periods
    for _, entry in ipairs(rtGraphTable) do
        local teamNumber = entry.teamNumber
        local timeElapsed = entry.gameMinute - lastTimeStamp[teamNumber]

        -- Add contribution of previous RT count for this time period
        teamRTs[teamNumber] = teamRTs[teamNumber] + (lastRTCount[teamNumber] * timeElapsed)

        -- Update RT count
        if entry.destroyed then
            lastRTCount[teamNumber] = lastRTCount[teamNumber] - 1
        else
            lastRTCount[teamNumber] = lastRTCount[teamNumber] + 1
        end

        lastTimeStamp[teamNumber] = entry.gameMinute
    end

    -- Add final contribution for remaining time
    for team = 1, 2 do
        local remainingTime = gameLengthMinutes - lastTimeStamp[team]
        teamRTs[team] = teamRTs[team] + (lastRTCount[team] * remainingTime)

        -- Calculate average by dividing by total game length
        teamRTs[team] = teamRTs[team] / gameLengthMinutes
    end

    return teamRTs[1], teamRTs[2] -- Returns marine average, alien average
end

function GUIGameEndStats:Update()
    local timeSinceRoundEnd = lastStatsMsg > 0 and Shared.GetTime() - lastGameEnd or 0
    local gameInfo = GetGameInfoEntity()

    if self:GetIsVisible() then
        self:UpdateVisibleUI()
    else
        self.lastRow = nil
    end

    -- Enough time has passed, so let's process the stats we received
    if Shared.GetTime() > lastStatsMsg + kMaxAppendTime and
        (#finalStatsTable > 0 or #cardsTable > 0 or #miscDataTable > 0) and gameInfo then
        self:ProcessStats()
    end

    -- Automatic data display on round end
    if timeSinceRoundEnd > 2.5 and Shared.GetTime() > lastStatsMsg + kMaxAppendTime then
        if GetAdvancedOption("deathstats") > 0 and timeSinceRoundEnd < 7.5 and not self.displayed then
            self.actionIconGUI:ShowIcon(BindingsUI_GetInputValue("RequestMenu"), nil, "Last round stats", nil)
        else
            self.actionIconGUI:Hide()
        end

        local gameEndSummary = Client.shouldShowEndSummary or ClientUI.GetScript("GUIGameEndPage") and
                                   ClientUI.GetScript("GUIGameEndPage"):GetIsVisible()
        local gameFeedback = Client.shouldShowFeedback or ClientUI.GetScript("GUIGameFeedback") and
                                 ClientUI.GetScript("GUIGameFeedback"):GetIsVisible()

        if not gameEndSummary and not gameFeedback and timeSinceRoundEnd > 7.5 and lastGameEnd > 0 and
            not self.displayed then
            self:SetIsVisible(gameInfo and gameInfo.showEndStatsAuto and GetAdvancedOption("deathstats") > 1)
            self.displayed = true
        end
    end
end

function GUIGameEndStats:GetShouldUpdate()
    return true
end

function EndStats_SetEndStatsHeaderInfo(self, playerWon, playerDraw, playerTeamType)
    local playerIsMarine = playerTeamType == kMarineTeamType
    miscDataTable.team1Name = InsightUI_GetTeam1Name()
    miscDataTable.team2Name = InsightUI_GetTeam2Name()
    miscDataTable.winningTeam = 0

    if playerWon then
        miscDataTable.winningTeam = playerIsMarine and kMarineTeamType or kAlienTeamType
    elseif not playerDraw then
        miscDataTable.winningTeam = playerIsMarine and kAlienTeamType or kMarineTeamType
    end

    miscDataTable.roundDateString = FormatDateTimeString(Shared.GetSystemTime())
    miscDataTable.serverName = Client.GetServerIsHidden() and "Hidden" or Client.GetConnectedServerName()
    miscDataTable.mapName = Shared.GetMapName()

    lastGameEnd = Shared.GetTime()
end

local function CHUDSetPlayerStats(message)
    if message and message.playerName then
        table.insert(finalStatsTable, message)
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetGameData(message)
    if message and message.marineAcc then
        avgAccTable = {
            marineAcc = message.marineAcc,
            marineOnosAcc = message.marineOnosAcc,
            alienAcc = message.alienAcc
        }

        local minutes = math.floor(message.gameLengthMinutes)
        local seconds = (message.gameLengthMinutes % 1) * 60

        miscDataTable.gameLengthMinutes = message.gameLengthMinutes
        miscDataTable.gameLength = string.format("%d:%.2d", minutes, seconds)
        miscDataTable.marineRTsBuilt = message.marineRTsBuilt
        miscDataTable.marineRTsLost = message.marineRTsLost
        miscDataTable.alienRTsBuilt = message.alienRTsBuilt
        miscDataTable.alienRTsLost = message.alienRTsLost
    end

    lastStatsMsg = Shared.GetTime()
end

local kFriendlyWeaponNames = {}
kFriendlyWeaponNames[kTechId.LerkBite] = "Lerk Bite"
kFriendlyWeaponNames[kTechId.Swipe] = "Swipe"
kFriendlyWeaponNames[kTechId.Spit] = "Spit"
kFriendlyWeaponNames[kTechId.Spray] = "Spray"
kFriendlyWeaponNames[kTechId.GrenadeLauncher] = "Grenade Launcher"
kFriendlyWeaponNames[kTechId.LayMines] = "Mines"
kFriendlyWeaponNames[kTechId.PulseGrenade] = "Pulse grenade"
kFriendlyWeaponNames[kTechId.ClusterGrenade] = "Cluster grenade"
kFriendlyWeaponNames[kTechId.GasGrenade] = "Gas grenade"
kFriendlyWeaponNames[kTechId.WhipBomb] = "Whip bilebomb"
kFriendlyWeaponNames[kTechId.HeavyMachineGun] = "Heavy Machine Gun"

local function CHUDSetWeaponStats(message)
    local weaponName
    local wTechId = message.wTechId

    if wTechId > 1 and wTechId ~= kTechId.None then
        if kFriendlyWeaponNames[wTechId] then
            weaponName = kFriendlyWeaponNames[wTechId]
        else
            local techdataName = LookupTechData(wTechId, kTechDataMapName) or
                                     Locale.ResolveString(LookupTechData(wTechId, kTechDataDisplayName, ""))
            weaponName = techdataName:gsub("^%l", string.upper)
        end
    else
        weaponName = "Others"
    end
    local cardEntry = {}
    cardEntry.text = weaponName
    cardEntry.teamNumber = message.teamNumber
    cardEntry.logoTexture = kInventoryIconsTexture
    cardEntry.logoCoords = {GetTexCoordsForTechId(wTechId)}
    cardEntry.logoSizeX = 64
    cardEntry.logoSizeY = 32
    cardEntry.message = message

    cardEntry.rows = {}

    local row = {}
    row.title = "Kills"
    row.value = printNum(message.kills)
    table.insert(cardEntry.rows, row)

    if message.accuracy > 0 then
        row = {}
        row.title = "Accuracy"
        row.value = round(message.accuracy, 0) .. "%"
        table.insert(cardEntry.rows, row)

        if message.accuracyOnos > -1 then
            row = {}
            row.title = "Accuracy (No Onos)"
            row.value = round(message.accuracyOnos, 0) .. "%"
            table.insert(cardEntry.rows, row)
        end
    end

    if message.pdmg > 0 then
        row = {}
        row.title = "Player damage"
        row.value = humanNumber(roundNumber(message.pdmg, 0))
        table.insert(cardEntry.rows, row)
    end

    if message.sdmg > 0 then
        row = {}
        row.title = "Structure damage"
        row.value = humanNumber(roundNumber(message.sdmg, 0))
        table.insert(cardEntry.rows, row)
    end

    table.insert(cardsTable, cardEntry)

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetStatusStats(message)
    local kStatusString = {
        [kPlayerStatus.Dead] = "Dead",
        [kPlayerStatus.Commander] = "Commander",
        [kPlayerStatus.Exo] = "Exo",
        [kPlayerStatus.GrenadeLauncher] = "Grenade Launcher",
        [kPlayerStatus.Rifle] = "Rifle",
        [kPlayerStatus.Shotgun] = "Shotgun",
        [kPlayerStatus.Flamethrower] = "Flamethrower",
        [kPlayerStatus.Void] = "Other",
        [kPlayerStatus.Spectator] = "Spectator",
        [kPlayerStatus.Embryo] = "Egg",
        [kPlayerStatus.Skulk] = "Skulk",
        [kPlayerStatus.Gorge] = "Gorge",
        [kPlayerStatus.Lerk] = "Lerk",
        [kPlayerStatus.Fade] = "Fade",
        [kPlayerStatus.Onos] = "Onos"
    }

    local entry = {}
    entry.className = kStatusString[message.statusId] or "Unknown"
    entry.timeMinutes = message.timeMinutes
    table.insert(statusSummaryTable, entry)

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetCommStats(message)
    if message.medpackAccuracy then
        if message.medpackResUsed + message.medpackResExpired > 0 then
            local cardEntry = {}
            cardEntry.text = "Medpacks"
            cardEntry.teamNumber = -1
            cardEntry.logoTexture = kBuildMenuTexture
            cardEntry.logoCoords = GetTextureCoordinatesForIcon(kTechId.MedPack)
            cardEntry.logoSizeX = 32
            cardEntry.logoSizeY = 32
            cardEntry.message = message
            cardEntry.order = 1

            cardEntry.rows = {}

            local row = {}
            row.title = "Accuracy"
            row.value = round(message.medpackAccuracy, 0) .. "%"
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Amount healed"
            row.value = printNum(message.medpackRefill)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Res spent on used medpacks"
            row.value = printNum(message.medpackResUsed)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Res spent on expired medpacks"
            row.value = printNum(message.medpackResExpired)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Efficiency (used vs expired)"
            row.value = round(message.medpackEfficiency, 0) .. "%"
            table.insert(cardEntry.rows, row)

            table.insert(cardsTable, cardEntry)
        end

        if message.ammopackResUsed + message.ammopackResExpired > 0 then
            local cardEntry = {}
            cardEntry.text = "Ammopacks"
            cardEntry.teamNumber = -1
            cardEntry.logoTexture = kBuildMenuTexture
            cardEntry.logoCoords = GetTextureCoordinatesForIcon(kTechId.AmmoPack)
            cardEntry.logoSizeX = 32
            cardEntry.logoSizeY = 32
            cardEntry.message = message
            cardEntry.order = 2

            cardEntry.rows = {}

            local row = {}
            row.title = "Ammo refilled"
            row.value = printNum(message.ammopackRefill)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Res spent on used ammopacks"
            row.value = printNum(message.ammopackResUsed)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Res spent on expired ammopacks"
            row.value = printNum(message.ammopackResExpired)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Efficiency (used vs expired)"
            row.value = round(message.ammopackEfficiency, 0) .. "%"
            table.insert(cardEntry.rows, row)

            table.insert(cardsTable, cardEntry)
        end

        if message.catpackResUsed + message.catpackResExpired > 0 then
            local cardEntry = {}
            cardEntry.text = "Catpacks"
            cardEntry.teamNumber = -1
            cardEntry.logoTexture = kBuildMenuTexture
            cardEntry.logoCoords = GetTextureCoordinatesForIcon(kTechId.CatPack)
            cardEntry.logoSizeX = 32
            cardEntry.logoSizeY = 32
            cardEntry.message = message
            cardEntry.order = 3

            cardEntry.rows = {}

            local row = {}
            row.title = "Res spent on used catpacks"
            row.value = printNum(message.catpackResUsed)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Res spent on expired catpacks"
            row.value = printNum(message.catpackResExpired)
            table.insert(cardEntry.rows, row)

            row = {}
            row.title = "Efficiency (used vs expired)"
            row.value = round(message.catpackEfficiency, 0) .. "%"
            table.insert(cardEntry.rows, row)

            table.insert(cardsTable, cardEntry)
        end
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetGlobalCommStats(message)
    if message and message.medpackAccuracy then
        commanderStats = message
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetHiveSkillGraph(message)
    if message and message.gameMinute then
        table.insert(hiveSkillGraphTable, message)
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetRTGraph(message)
    if message and message.gameMinute then
        table.insert(rtGraphTable, message)
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetKillGraph(message)
    if message and message.gameMinute then
        local entry = {}
        entry.teamNumber = message.killerTeamNumber
        entry.gameMinute = message.gameMinute
        table.insert(killGraphTable, entry)
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDEquipmentAndLifeformsLog(message)
    if message and message.name then
        local entry = {}
        entry.name = message.name
        entry.buyCount = message.buyCount
        entry.lostCount = message.lostCount
        table.insert(equipmentAndLifeformsLogTable, entry)
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDTeamSpecificStatsLog(message)
    -- print("Got message: " .. dump(message))
    if message and message.steamId then
        local entry = {}
        entry.steamId = message.steamId
        entry.techName = message.techName
        entry.value = message.value
        -- print("insert: " .. dump(message))
        if not teamSpecificStatsLogTable[message.techName] then
            teamSpecificStatsLogTable[message.techName] = {}
        end
        if not teamSpecificStatsLogTable[message.techName][message.steamId] then
            teamSpecificStatsLogTable[message.techName][message.steamId] = {}
        end
        teamSpecificStatsLogTable[message.techName][message.steamId] = message.value
        -- table.insert(teamSpecificStatsLogTable, entry)
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetBuildingSummary(message)
    if message and message.techId then
        local entry = {}
        entry.iconTexture = kBuildMenuTexture
        entry.iconCoords = GetTextureCoordinatesForIcon(message.techId)
        entry.iconSizeX = 24
        entry.iconSizeY = 24
        entry.teamNumber = message.teamNumber
        entry.name = GetDisplayNameForTechId(message.techId)

        entry.techId = message.techId
        entry.lost = message.lost
        entry.built = message.built

        table.insert(buildingSummaryTable, entry)
    end

    lastStatsMsg = Shared.GetTime()
end

local function CHUDSetTechLog(message)
    if message and message.finishedMinute then
        local entry = {}
        entry.iconTexture = kBuildMenuTexture
        entry.iconCoords = GetTextureCoordinatesForIcon(message.techId)
        entry.iconSizeX = 24
        entry.iconSizeY = 24
        entry.teamNumber = message.teamNumber
        entry.name = GetDisplayNameForTechId(message.techId)
        if message.built == false then
            entry.name = string.format(Locale.ResolveString("UNBUILT_STRUCTURE"), entry.name)
        end
        if message.recycled == true then
            local format_string = message.teamNumber == 2 and Locale.ResolveString("CONSUMED_STRUCTURE") or
                                      Locale.ResolveString("RECYCLED_STRUCTURE")
            entry.name = string.format(format_string, entry.name)
        end

        local minutes = math.floor(message.finishedMinute)
        local seconds = (message.finishedMinute % 1) * 60

        entry.finishedMinute = message.finishedMinute
        entry.finishedTime = string.format("%d:%.2d", minutes, seconds)
        entry.activeRTs = message.activeRTs
        entry.teamRes = message.teamRes
        entry.destroyed = message.destroyed
        entry.built = message.built
        entry.recycled = message.recycled

        table.insert(techLogTable, entry)
    end

    lastStatsMsg = Shared.GetTime()
end

local function GetIsOnNeutralTeam()
    local player = Client.GetLocalPlayer()
    local teamNumber = player and player:GetTeamNumber()
    return teamNumber == kTeamReadyRoom or teamNumber == kSpectatorIndex
end

local function GetGameStarted()
    local gameInfo = GetGameInfoEntity()
    return gameInfo and gameInfo:GetGameStarted()
end

local lastDisplayStatus = false
local lastDown = 0
local kKeyTapTiming = 0.2
function GUIGameEndStats:SendKeyEvent(key, down)
    if GetIsBinding(key, "RequestMenu") and GetAdvancedOption("deathstats") > 0 and
        (not GetGameStarted() or GetIsOnNeutralTeam()) and not ChatUI_EnteringChatMessage() and
        not MainMenu_GetIsOpened() and self.prevRequestKey ~= down then
        self.prevRequestKey = down

        if down then
            -- Only show stats when the player hasn't selected something from the request menu first
            lastDown = Shared.GetTime()
        elseif not down then
            local isVisible = self:GetIsVisible()
            if isVisible then
                self:SetIsVisible(false)
            elseif lastDown + kKeyTapTiming > Shared.GetTime() then
                self:SetIsVisible(true)
            end
        end
    end

    if self:GetIsVisible() then
        if key == InputKey.Escape and down then
            self:SetIsVisible(false)
            return true
        elseif key == InputKey.MouseButton0 and down then
            local mouseX, mouseY = Client.GetCursorPosScreen()

            if GUIItemContainsPoint(self.closeButton, mouseX, mouseY) then
                StartSoundEffect(kButtonClickSound)
                self:SetIsVisible(false)
                return true
            end

            if self.lastRow and not self.hoverMenu.background:GetIsVisible() then
                local function openSteamProf()
                    Client.ShowWebpage(string.format("%s[U:1:%s]", kSteamProfileURL, self.lastRow.steamId))
                end

                local function openNs2PanelProf()
                    Client.ShowWebpage(string.format("%s%s", kNs2PanelUserURL, self.lastRow.steamId))
                end

                self.hoverMenu:ResetButtons()

                local textColor = Color(1, 1, 1, 1)
                local nameBgColor = Color(0, 0, 0, 0)
                local teamColorHighlight = self.lastRow.background:GetParent():GetColor() * 0.25
                teamColorHighlight.a = 1
                local teamColorBg = self.lastRow.background:GetParent():GetColor() * 0.5
                teamColorBg.a = 1
                local bgColor = self.lastRow.background:GetParent():GetColor() * 0.75
                bgColor.a = 0.9

                self.hoverMenu:SetBackgroundColor(bgColor)
                local name = self.lastRow.playerName:GetText()

                if self.lastRow.hiveSkillTier then
                    name = string.format("[%s] %s", self.lastRow.hiveSkillTier, name)
                end

                self.hoverMenu:AddButton(name, nameBgColor, nameBgColor, textColor)
                self.hoverMenu:AddButton(Locale.ResolveString("SB_MENU_STEAM_PROFILE"), teamColorBg, teamColorHighlight,
                    textColor, openSteamProf)
                self.hoverMenu:AddButton("NS2Panel profile", teamColorBg, teamColorHighlight, textColor,
                    openNs2PanelProf)

                StartSoundEffect(kButtonClickSound)
                self.hoverMenu:Show()

                return true
            elseif self.lastRow and self.hoverMenu.background:GetIsVisible() and
                not GUIItemContainsPoint(self.hoverMenu.background, mouseX, mouseY) then
                self.hoverMenu:Hide()
            end

            if highlightedField ~= nil then
                if highlightedFieldMarine then
                    if lastSortedT1 == highlightedField then
                        lastSortedT1WasInv = not lastSortedT1WasInv
                    else
                        lastSortedT1WasInv = false
                        lastSortedT1 = highlightedField
                    end
                else
                    if lastSortedT2 == highlightedField then
                        lastSortedT2WasInv = not lastSortedT2WasInv
                    else
                        lastSortedT2WasInv = false
                        lastSortedT2 = highlightedField
                    end
                end

                StartSoundEffect(kButtonClickSound)
                SortByColumn(self, highlightedFieldMarine, highlightedField,
                    highlightedFieldMarine and lastSortedT1WasInv or lastSortedT2WasInv)
                return true
            end
        end
    end

    if GetIsBinding(key, "Scoreboard") and self.prevScoreKey ~= down then
        self.prevScoreKey = down
        if down then
            lastDisplayStatus = self:GetIsVisible()
            if lastDisplayStatus then
                self:SetIsVisible(false)
            end
        elseif lastDisplayStatus and not self:GetIsVisible() then
            self:SetIsVisible(lastDisplayStatus)
        end
    end

    if self.sliderBarBg:GetIsVisible() and not self.hoverMenu.background:GetIsVisible() then
        local maxPos = self.contentSize - kContentMaxYSize
        if key == InputKey.MouseButton0 and self.mousePressed ~= down then
            self.mousePressed = down
            if down then
                local mouseX, mouseY = Client.GetCursorPosScreen()
                self.isDragging = GUIItemContainsPoint(self.sliderBarBg, mouseX, mouseY) or
                                      GUIItemContainsPoint(self.slider, mouseX, mouseY)
                return true
            end
        elseif key == InputKey.MouseWheelDown then
            self.slideOffset = math.min(self.slideOffset + GUILinearScale(75), maxPos)
            return true
        elseif key == InputKey.MouseWheelUp then
            self.slideOffset = math.max(self.slideOffset - GUILinearScale(75), 0)
            return true
        elseif key == InputKey.PageDown and down then
            self.slideOffset = math.min(self.slideOffset + kContentMaxYSize / 2, maxPos)
            return true
        elseif key == InputKey.PageUp and down then
            self.slideOffset = math.max(self.slideOffset - kContentMaxYSize / 2, 0)
            return true
        elseif key == InputKey.Home then
            self.slideOffset = 0
            return true
        elseif key == InputKey.End then
            self.slideOffset = maxPos
            return true
        end
    end

    return false
end

function GUIGameEndStats:OnResolutionChanged(oldX, oldY, newX, newY)
    -- Mark the last round as not loaded so it loads it back when we destroy the current UI
    loadedLastRound = false

    -- We need to trigger this manually to update font sizes
    self.hiveSkillGraph:OnResolutionChanged(oldX, oldY, newX, newY)
    self.rtGraph:OnResolutionChanged(oldX, oldY, newX, newY)
    self.builtRTsComp:OnResolutionChanged(oldX, oldY, newX, newY)
    self.lostRTsComp:OnResolutionChanged(oldX, oldY, newX, newY)

    self:Uninitialize()
    self:Initialize()
end

local oldGetCanDisplayReqMenu = PlayerUI_GetCanDisplayRequestMenu
function PlayerUI_GetCanDisplayRequestMenu()
    return oldGetCanDisplayReqMenu() and not EndStatsVisible and lastDown + kKeyTapTiming < Shared.GetTime()
end

-- Add the missing icons so they display correctly
-- We have to call the function first so it creates the array
GetTexCoordsForTechId(kTechId.None)

gTechIdPosition[kTechId.Sentry] = kDeathMessageIcon.Sentry
gTechIdPosition[kTechId.ARC] = kDeathMessageIcon.ARC
gTechIdPosition[kTechId.Whip] = kDeathMessageIcon.Whip
gTechIdPosition[kTechId.Babbler] = kDeathMessageIcon.Babbler
gTechIdPosition[kTechId.Hydra] = kDeathMessageIcon.HydraSpike
gTechIdPosition[kTechId.Minigun] = kDeathMessageIcon.Minigun
gTechIdPosition[kTechId.Claw] = kDeathMessageIcon.Claw
gTechIdPosition[kTechId.Railgun] = kDeathMessageIcon.Railgun

Client.HookNetworkMessage("PlayerStats", CHUDSetPlayerStats)
Client.HookNetworkMessage("GameData", CHUDSetGameData)
Client.HookNetworkMessage("EndStatsWeapon", CHUDSetWeaponStats)
Client.HookNetworkMessage("EndStatsStatus", CHUDSetStatusStats)
Client.HookNetworkMessage("MarineCommStats", CHUDSetCommStats)
Client.HookNetworkMessage("GlobalCommStats", CHUDSetGlobalCommStats)
Client.HookNetworkMessage("HiveSkillGraph", CHUDSetHiveSkillGraph)
Client.HookNetworkMessage("RTGraph", CHUDSetRTGraph)
Client.HookNetworkMessage("KillGraph", CHUDSetKillGraph)
Client.HookNetworkMessage("TechLog", CHUDSetTechLog)
Client.HookNetworkMessage("BuildingSummary", CHUDSetBuildingSummary)
Client.HookNetworkMessage("EalStats", CHUDEquipmentAndLifeformsLog)
Client.HookNetworkMessage("TeamSpecificStats", CHUDTeamSpecificStatsLog)

-- commented out for LessNetworkData
--[[

local function CHUDPresGraphAliens(message)
    if message and message.gameMinute then
        table.insert(presGraphTableAliens, message)
    end
    lastStatsMsg = Shared.GetTime()
end
Client.HookNetworkMessage("PresGraphStatsAliens", CHUDPresGraphAliens)

-- presGraph Mod
local function CHUDPresGraphMarines(message)
    if message and message.gameMinute then
        table.insert(presGraphTableMarines, message)
    end
    lastStatsMsg = Shared.GetTime()
end
Client.HookNetworkMessage("PresGraphStatsMarines", CHUDPresGraphMarines)

]]
