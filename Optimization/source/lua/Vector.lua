-- ======= Copyright (c) 2003-2011, Unknown Worlds Entertainment, Inc. All rights reserved. =======
--
-- lua\Vector.lua
--
--    Created by:   Charlie Cleveland (charlie@unknownworlds.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================
--------------------/
-- Class functions --
--------------------/
------------------------
-- Internal functions --
------------------------
local math_sqrt, math_abs, math_acos = math.sqrt, math.abs, math.acos

function InternalVectorLength(vec)
    local length = math_sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    if length < Vector.kEpsilon then
        length = 0
    end
    return length
end

----------------------/
-- Utility functions --
----------------------/

function GetAngleBetweenVectors(vec1, vec2)
    local normVec1 = GetNormalizedVector(vec1)
    local normVec2 = GetNormalizedVector(vec2)
    local dot = math.max(-1, math.min(1, normVec1:DotProduct(normVec2))) -- Clamp to avoid precision errors
    return math_acos(dot)
end

function GetNormalizedVector(inputVec)
    local length = InternalVectorLength(inputVec)
    if length > Vector.kEpsilon then
        return Vector(inputVec.x / length, inputVec.y / length, inputVec.z / length)
    else
        return Vector(0, 0, 0)
    end
end

function GetNormalizedVectorXZ(inputVec)

    local normVec = Vector()

    VectorCopy(inputVec, normVec)
    normVec.y = 0
    normVec:Normalize()

    return normVec

end

function GetNormalizedVectorXY(inputVec)

    local normVec = Vector()

    VectorCopy(inputVec, normVec)
    normVec.z = 0
    normVec:Normalize()

    return normVec

end

function GetNormalizedVectorYZ(inputVec)

    local normVec = Vector()

    VectorCopy(inputVec, normVec)
    normVec.x = 0
    normVec:Normalize()

    return normVec

end

function ReflectVector(inputVector, normal)
    local inputVectorLength = InternalVectorLength(inputVector)
    local unitBounceDirection = Vector(inputVector.x, inputVector.y, inputVector.z)
    unitBounceDirection:Scale(-1 / inputVectorLength)

    local bounceReflection = unitBounceDirection:GetReflection(normal)
    bounceReflection:Normalize()

    return bounceReflection * inputVectorLength
end

function VectorCopy(src, dest)
    dest.x = src.x
    dest.y = src.y
    dest.z = src.z
end

function VectorAbs(vec)
    vec.x = math_abs(vec.x)
    vec.y = math_abs(vec.y)
    vec.z = math_abs(vec.z)
end

function VectorSetLength(vec, newLength)
    local length = InternalVectorLength(vec)
    if length > Vector.kEpsilon then
        local scale = newLength / length
        vec.x = vec.x * scale
        vec.y = vec.y * scale
        vec.z = vec.z * scale
    else
        vec.x, vec.y, vec.z = 0, 0, 0
    end
end

