--======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\UtilityShared.lua
--
--    Created by:   Mats Olsson (mats.olsson@matsotech.se)
--
-- Includes utility function used by the GUIView VMs as well as the World VMs
-- Move things over from Utility.lua as the GUIViews needs them
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================


local math_min, math_max, math_floor = math.min, math.max, math.floor

function Round(value, decimalPlaces)
    local mult = 10 ^ (decimalPlaces or 0)
    return math_floor(value * mult + 0.5) / mult
end

function Clamp(value, min, max)
    -- fsfod says this is faster in LuaJIT
    return (math_min(math_max(value, min), max))
end

function ClampVector(vector, min, max)
    assert(type(vector) == "table" and vector.x and vector.y and vector.z, "Invalid vector")
    assert(type(min) == "table" and min.x and min.y and min.z, "Invalid min vector")
    assert(type(max) == "table" and max.x and max.y and max.z, "Invalid max vector")

    vector.x = Clamp(vector.x, min.x, max.x)
    vector.y = Clamp(vector.y, min.y, max.y)
    vector.z = Clamp(vector.z, min.z, max.z)
end

function Limit(x, limit1, limit2)
    return Clamp(x, math_min(limit1, limit2), math_max(limit1, limit2))
end

function Wrap(x, min, max)
    local range = max - min
    if range == 0 then
        return min
    end

    -- Use modulo arithmetic for wrapping
    return min + ((x - min) % range + range) % range
end
