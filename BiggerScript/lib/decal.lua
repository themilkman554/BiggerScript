-- Decal helper library for BiggerScript
local M = {}

M.loadedTextures = {}
M.activeDecals = {}

M.emblemSettings = { normX = 0.0, normY = 0.0, normZ = -1.0, upX = -1.0, upY = 0.0, upZ = 0.0, scale = 0.5, p13 = 0, alpha = 255 }

local function try(func, ...)
    local success, result = pcall(func, ...)
    if not success then Logger.LogInfo("[Decal] Error: " .. tostring(result)) end
    return success, result
end

function M.applyCrewEmblem(vehicle, ped, boneName)
    local bone = ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(vehicle, boneName or "chassis_dummy")
    if bone == -1 then bone = 0 end
    local s = M.emblemSettings
    local ok, res = try(GRAPHICS.ADD_VEHICLE_CREW_EMBLEM, vehicle, ped, bone, 0.0, 1.4, 1.0, s.normX, s.normY, s.normZ, s.upX, s.upY, s.upZ, s.scale, s.p13, s.alpha)
    return ok and res or false
end

function M.removeCrewEmblem(vehicle, index)
    return try(GRAPHICS.REMOVE_VEHICLE_CREW_EMBLEM, vehicle, index or 0)
end

function M.vehicleHasCrewEmblem(vehicle, index)
    local ok, res = try(GRAPHICS.DOES_VEHICLE_HAVE_CREW_EMBLEM, vehicle, index or 0)
    return ok and res or false
end

function M.getCrewEmblemRequestState(vehicle, index)
    local ok, res = try(GRAPHICS.GET_VEHICLE_CREW_EMBLEM_REQUEST_STATE, vehicle, index or 0)
    return ok and res or -1
end

function M.loadTextureDict(dict, timeout)
    timeout = timeout or 100
    if M.loadedTextures[dict] then return true end
    
    local ok, loaded = try(GRAPHICS.HAS_STREAMED_TEXTURE_DICT_LOADED, dict)
    if ok and loaded then M.loadedTextures[dict] = true return true end

    try(GRAPHICS.REQUEST_STREAMED_TEXTURE_DICT, dict, false)
    
    while timeout > 0 do
        ok, loaded = try(GRAPHICS.HAS_STREAMED_TEXTURE_DICT_LOADED, dict)
        if ok and loaded then M.loadedTextures[dict] = true return true end
        Script.Yield(50)
        timeout = timeout - 1
    end
    return false
end

function M.isTextureLoaded(dict)
    local ok, res = try(GRAPHICS.HAS_STREAMED_TEXTURE_DICT_LOADED, dict)
    return ok and res
end

function M.releaseTextureDict(dict)
    try(GRAPHICS.SET_STREAMED_TEXTURE_DICT_AS_NO_LONGER_NEEDED, dict)
    M.loadedTextures[dict] = nil
end

function M.overrideDecalTexture(type, dict, name)
    local ok, res = try(GRAPHICS._OVERRIDE_DECAL_TEXTURE, type, dict, name)
    return ok and res ~= nil
end

local function normalize(x, y, z)
    local m = math.sqrt(x*x + y*y + z*z)
    return m > 0 and x/m or 0, m > 0 and y/m or 0, m > 0 and z/m or 0
end

function M.addDecal(type, x, y, z, dx, dy, dz, w, h, r, g, b, a, time, onVeh)
    local nx, ny, nz = normalize(dx, dy, dz)
    local ux, uy, uz = 0.0, 1.0, 0.0
    if math.abs(ny) > 0.9 then ux, uy, uz = 1.0, 0.0, 0.0 end
    
    local ok, handle = try(GRAPHICS.ADD_DECAL, type, x, y, z, nx, ny, nz, ux, uy, uz, w or 1, h or 1, r or 1, g or 1, b or 1, a or 1, time or 30, false, false, onVeh ~= false)
    if ok and handle and handle ~= 0 then M.activeDecals[handle] = true return handle end
    return nil
end

function M.addDecalTexture(dict, name, x, y, z, dx, dy, dz, w, h, r, g, b, a, time, onVeh, type)
    type = type or 9118
    if not M.overrideDecalTexture(type, dict, name) then return nil end
    return M.addDecal(type, x, y, z, dx, dy, dz, w, h, r, g, b, a, time, onVeh)
end

function M.removeDecal(handle)
    if handle and handle ~= 0 then try(GRAPHICS.REMOVE_DECAL, handle) M.activeDecals[handle] = nil end
end

function M.removeDecalsInRange(x, y, z, range)
    try(GRAPHICS.REMOVE_DECALS_IN_RANGE, x, y, z, range)
end

function M.isDecalAlive(handle)
    local ok, res = try(GRAPHICS.IS_DECAL_ALIVE, handle)
    return ok and res
end

function M.removeAllActiveDecals()
    for h, _ in pairs(M.activeDecals) do M.removeDecal(h) end
    M.activeDecals = {}
end

return M
