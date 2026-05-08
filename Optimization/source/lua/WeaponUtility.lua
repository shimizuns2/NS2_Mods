-- ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\WeaponUtility.lua
--
--    Created by:   Brian Cronin (brianc@unknownworlds.com)
--
-- Weapon utility functions.
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================
--
-- Pass in a target direction and a spread amount in radians and a new
-- direction vector is returned. Pass in a function that returns a random
-- number between and including 0 and 1.
--
local math_cos, math_sin, math_tan, math_pi = math.cos, math.sin, math.tan, math.pi

function CalculateSpread(directionCoords, spreadAmount, randomizer)
    assert(type(spreadAmount) == "number", "Invalid spreadAmount")
    assert(type(randomizer) == "function", "Invalid randomizer")

    local spreadAngle = spreadAmount / 2

    -- Precompute random values
    local randomAngle = randomizer() * math_pi * 2
    local cosAngle = math_cos(randomAngle)
    local sinAngle = math_sin(randomAngle)
    local randomRadius = randomizer() * math_tan(spreadAngle)

    -- Compute spread direction
    local spreadDirection = directionCoords.zAxis +
                                (directionCoords.xAxis * cosAngle + directionCoords.yAxis * sinAngle) * randomRadius

    -- Normalize the result
    spreadDirection:Normalize()

    return spreadDirection
end

function DebugFireRate(weapon)
    if Server then
        if not weapon.timeLastShootDebug then
            weapon.timeLastShootDebug = 0
        end

        local currentTime = Shared.GetTime()
        local delta = currentTime - weapon.timeLastShootDebug
        DebugPrint("%s: %.3f seconds since last shot", ToString(weapon), delta)
        weapon.timeLastShootDebug = currentTime
    end
end
