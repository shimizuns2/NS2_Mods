local DIPS_Name = "Devnull - Interesting Post Scoreboard"
local DIPS_Version = "2.4.1"
kDevnull_IPS = DIPS_Version
if Server or Client then
    HPrint(DIPS_Name .. ", version " .. DIPS_Version)
end

if Server then
    ModLoader.SetupFileHook("lua/Player_Server.lua", "lua/Devnull_IPS/Player_Server.lua", "post")
    ModLoader.SetupFileHook("lua/Alien_Server.lua", "lua/Devnull_IPS/Alien_Server.lua", "post")
    ModLoader.SetupFileHook("lua/Exo.lua", "lua/Devnull_IPS/Exo.lua", "post")
    ModLoader.SetupFileHook("lua/JetpackOnBack.lua", "lua/Devnull_IPS/JetpackOnBack.lua", "post")
    ModLoader.SetupFileHook("lua/Weapons/Marine/ClipWeapon.lua", "lua/Devnull_IPS/Weapons/Marine/ClipWeapon.lua", "post")
    ModLoader.SetupFileHook("lua/Weapons/Marine/Welder.lua", "lua/Devnull_IPS/Weapons/Marine/Welder.lua", "post")

    ModLoader.SetupFileHook("lua/Mine.lua", "lua/Devnull_IPS/Mine.lua", "post")
    ModLoader.SetupFileHook("lua/Weapons/Marine/GasGrenade.lua", "lua/Devnull_IPS/Weapons/Marine/GasGrenade.lua", "post")
    ModLoader.SetupFileHook("lua/Weapons/Marine/ClusterGrenade.lua", "lua/Devnull_IPS/Weapons/Marine/ClusterGrenade.lua", "post")
    ModLoader.SetupFileHook("lua/Weapons/Marine/PulseGrenade.lua", "lua/Devnull_IPS/Weapons/Marine/PulseGrenade.lua", "post")

    ModLoader.SetupFileHook("lua/ParasiteMixin.lua", "lua/Devnull_IPS/ParasiteMixin.lua", "post")
    --ModLoader.SetupFileHook("lua/Weapons/Alien/HealSprayMixin.lua", "lua/Devnull_IPS/Weapons/Alien/HealSprayMixin.lua", "post")
    ModLoader.SetupFileHook("lua/Weapons/Marine/LayMines.lua", "lua/Devnull_IPS/Weapons/Marine/LayMines.lua", "post")
    ModLoader.SetupFileHook("lua/LiveMixin.lua", "lua/Devnull_IPS/LiveMixin.lua", "post")
    ModLoader.SetupFileHook("lua/MedPack.lua", "lua/Devnull_IPS/MedPack.lua", "post")

    -- pres calculations for pres graph, commented out for LessNetworkData
    --ModLoader.SetupFileHook("lua/NS2Gamerules.lua", "lua/Devnull_IPS/NS2Gamerules.lua", "post")
end

if Client then
    ModLoader.SetupFileHook("lua/GUIDeathStats.lua", "lua/Devnull_IPS/GUIDeathStats.lua", "post")
end
ModLoader.SetupFileHook("lua/GUIGameEndStats.lua", "lua/Devnull_IPS/GUIGameEndStats.lua", "replace")
ModLoader.SetupFileHook("lua/ServerStats.lua", "lua/Devnull_IPS/ServerStats.lua", "replace")
ModLoader.SetupFileHook("lua/NetworkMessages.lua", "lua/Devnull_IPS/NetworkMessages.lua", "post")
