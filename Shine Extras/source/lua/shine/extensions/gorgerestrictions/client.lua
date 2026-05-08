local Plugin = Shine.Plugin(...)
Plugin.NotifyPrefixColour = {255, 50, 0}
Plugin.PrintName = "Gorge Restrictions"
Plugin.Version = "0.9"
Plugin.HasConfig = false
Plugin.DefaultState = false



function Plugin:GorgeRestrict(purchases)
    print("AlienPurchase")
end

function Plugin:Initialise()
    Shared.Message("Loading Gorge Restrictions...")
    print("Loaded Gorge Restrictions")

    SetupClassHook("AlienBuy_Client", "AlienBuy_Purchase", "GorgeRestrict", "halt")

    return true
end

return Plugin