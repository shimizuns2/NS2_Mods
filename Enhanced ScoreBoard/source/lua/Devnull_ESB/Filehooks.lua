local kVersion = "1.8.8"
local kName = "Devnull - Enhanced ScoreBoard"

if Client then
    HPrint(kName .. ", version " .. kVersion)
end

--Hooks
ModLoader.SetupFileHook("lua/GUIScoreboard.lua", "lua/Devnull_ESB/GUIScoreboard.lua", "replace")
ModLoader.SetupFileHook("lua/PlayerInfoEntity.lua", "lua/Devnull_ESB/PlayerInfoEntity.lua", "post")
--ModLoader.SetupFileHook("lua/NS2Utility.lua", "lua/Devnull_ESB/NS2Utility.lua", "post")
--ModLoader.SetupFileHook("lua/Scoreboard.lua", "lua/Devnull_ESB/Scoreboard.lua", "replace")
--ModLoader.SetupFileHook("lua/GUITechMap.lua", "lua/Devnull_ESB/GUITechMap.lua", "replace")