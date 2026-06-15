-- ============================================================================
-- Spawn Core Module
-- Unified spawning logic shared across all formats (XML, INI, JSON, CHRX)
-- ============================================================================
local Core = {}

local function FreemodeQueueJob(cb, ...)
    local args = {...}
    if NETWORK.NETWORK_IS_SESSION_STARTED() then
        Script.ExecuteAsScript("freemode", function()
            Script.QueueJob(cb, table.unpack(args))
        end)
    else
        Script.QueueJob(cb, table.unpack(args))
    end
end

local function FreemodeRegisterLooped(cb, ...)
    local args = {...}
    if NETWORK.NETWORK_IS_SESSION_STARTED() then
        Script.ExecuteAsScript("freemode", function()
            Script.RegisterLooped(cb, table.unpack(args))
        end)
    else
        Script.RegisterLooped(cb, table.unpack(args))
    end
end


-- References set via init()
local M              -- spawning module (M) reference for calling format-specific helpers
local spawnerSettings
local spawnedVehicles, spawnedMaps, spawnedOutfits, previewEntities
local currentPreviewFile
local debug_print
local constructor_lib

-- ============================================================================
-- Init — called by spawning.init()
-- ============================================================================
function Core.init(ctx)
    M                 = ctx.spawning
    spawnerSettings   = ctx.spawnerSettings
    spawnedVehicles   = ctx.spawnedVehicles
    spawnedMaps       = ctx.spawnedMaps
    spawnedOutfits    = ctx.spawnedOutfits
    previewEntities   = ctx.previewEntities
    currentPreviewFile = ctx.currentPreviewFile
    debug_print       = ctx.debug_print or function() end
    constructor_lib   = ctx.constructor_lib
end

-- ============================================================================
-- Helper: Get player position and heading
-- ============================================================================
function Core.getPlayerSpawnInfo()
    local playerPed = GTA.GetLocalPed()
    if not playerPed then return nil end
    local pos = playerPed.Position
    local heading = playerPed.Heading or 0.0
    return {
        ped = playerPed,
        pos = pos,
        heading = heading,
        playerID = PLAYER.PLAYER_ID()
    }
end

-- ============================================================================
-- Helper: Calculate preview spawn coords
-- ============================================================================
function Core.getPreviewCoords(playerInfo, offsetDistance)
    offsetDistance = offsetDistance or 5.0
    local rad = math.rad(playerInfo.heading)
    return {
        x = playerInfo.pos.x + (math.sin(rad) * offsetDistance),
        y = playerInfo.pos.y + (math.cos(rad) * offsetDistance),
        z = playerInfo.pos.z + 0.5
    }
end

-- ============================================================================
-- Helper: Spawn a vehicle handle (shared ceremony for all formats)
-- Handles: apply-to-current, plane/heli air spawn, normal spawn, preview
-- Returns: vehicleHandle or nil
-- ============================================================================
function Core.spawnVehicleHandle(modelHash, playerInfo, isPreview)
    local vehicleHandle = nil
    local playerID = playerInfo.playerID
    local forwardOffset = 5.0

    -- Check if we should use the current vehicle instead of spawning
    local applyToCurrentVehicle = spawnerSettings.onlyApplyAttachments and not isPreview
    
    if applyToCurrentVehicle then
        local playerPedHandle = GTA.PointerToHandle(playerInfo.ped)
        if playerPedHandle and playerPedHandle ~= 0 then
            local currentVehicle = PED.GET_VEHICLE_PED_IS_IN(playerPedHandle, false)
            if currentVehicle and currentVehicle ~= 0 then
                vehicleHandle = currentVehicle
                debug_print("[Apply Attachments] Using current vehicle: " .. tostring(vehicleHandle))
            else
                GUI.AddToast("Apply Attachments", "You must be in a vehicle to apply attachments", 5000, 0)
                return nil
            end
        else
            GUI.AddToast("Apply Attachments", "Could not get player ped handle", 5000, 0)
            return nil
        end
    elseif not isPreview then
        -- Check for plane/heli air spawn
        local isPlane = VEHICLE.IS_THIS_MODEL_A_PLANE(modelHash)
        local isHeli = VEHICLE.IS_THIS_MODEL_A_HELI(modelHash)
        if spawnerSettings.spawnPlaneInTheAir and (isPlane or isHeli) then
            vehicleHandle = GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset)
            if vehicleHandle and vehicleHandle ~= 0 then
                local coords = ENTITY.GET_ENTITY_COORDS(vehicleHandle, true)
                ENTITY.SET_ENTITY_COORDS(vehicleHandle, coords.x, coords.y, coords.z + 45.0, false, false, false, true)
                VEHICLE.SET_HELI_BLADES_FULL_SPEED(vehicleHandle)
                VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, true, true, true)
                VEHICLE.SET_VEHICLE_FORWARD_SPEED(vehicleHandle, 100.0)
            end
        else
            vehicleHandle = GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset)
        end
    else
        -- Preview spawn
        vehicleHandle = GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset)
    end
    
    -- Set preview collision off
    if isPreview and vehicleHandle and vehicleHandle ~= 0 then
        ENTITY.SET_ENTITY_COLLISION(vehicleHandle, false, false)
    end
    
    return vehicleHandle
end

-- ============================================================================
-- Helper: Apply spawner settings (god mode, engine, radio, F1 wheels)
-- ============================================================================
function Core.applySpawnerSettings(vehicleHandle, isPreview)
    if spawnerSettings.vehicleGodMode and not isPreview then
        M.try_call(ENTITY, "SET_ENTITY_INVINCIBLE", vehicleHandle, true)
    end
    if spawnerSettings.vehicleEngineOn and not isPreview then
        M.try_call(VEHICLE, "SET_VEHICLE_ENGINE_ON", vehicleHandle, true, true, false)
    end
    if spawnerSettings.radioOff and not isPreview then
        M.try_call(AUDIO, "SET_VEHICLE_RADIO_ENABLED", vehicleHandle, false)
    end
    if not isPreview then
        M.applyF1WheelsIfEnabled(vehicleHandle)
    end
end

-- ============================================================================
-- Helper: Apply random color if setting is enabled
-- Returns true if random color was applied
-- ============================================================================
function Core.applyRandomColorIfEnabled(vehicleHandle)
    if spawnerSettings.randomColor then
        M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
        M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
        M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_5", vehicleHandle, math.random(0,255))
        M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_6", vehicleHandle, math.random(0,255))
        return true
    end
    return false
end

-- ============================================================================
-- Helper: Apply random livery if setting is enabled
-- Returns true if random livery was applied
-- ============================================================================
function Core.applyRandomLiveryIfEnabled(vehicleHandle)
    if spawnerSettings.randomLivery then
        local liveryCount = M.try_call(VEHICLE, "GET_VEHICLE_LIVERY_COUNT", vehicleHandle)
        if liveryCount and liveryCount > 0 then
            M.try_call(VEHICLE, "SET_VEHICLE_LIVERY", vehicleHandle, math.random(0, liveryCount - 1))
        end
        return true
    end
    return false
end

-- ============================================================================
-- Helper: Apply max upgrades if setting is enabled
-- Returns true if upgrades were applied
-- ============================================================================
function Core.applyMaxUpgradesIfEnabled(vehicleHandle)
    if spawnerSettings.upgradedVehicle then
        M.try_call(VEHICLE, "SET_VEHICLE_MOD_KIT", vehicleHandle, 0)
        for i = 0, 50 do
            local maxMods = M.try_call(VEHICLE, "GET_NUM_VEHICLE_MODS", vehicleHandle, i)
            if maxMods and maxMods > 0 then
                M.try_call(VEHICLE, "SET_VEHICLE_MOD", vehicleHandle, i, maxMods - 1, false)
            end
        end
        return true
    end
    return false
end

-- ============================================================================
-- Helper: Handle preview entities
-- ============================================================================
function Core.handlePreviewEntities(vehicleHandle, createdAttachments)
    table.insert(previewEntities, vehicleHandle)
    if createdAttachments then
        for _, attachment in ipairs(createdAttachments) do
            table.insert(previewEntities, attachment)
        end
    end
end

-- ============================================================================
-- Helper: Register spawned vehicle
-- ============================================================================
function Core.registerSpawnedVehicle(vehicleHandle, createdAttachments, filePath)
    local vehicleData = {
        vehicle = nil,
        attachments = {},
        filePath = filePath
    }
    if vehicleHandle and vehicleHandle ~= 0 and ENTITY and ENTITY.DOES_ENTITY_EXIST(vehicleHandle) then
        vehicleData.vehicle = vehicleHandle
    end
    if createdAttachments then
        for _, attachmentHandle in ipairs(createdAttachments) do
            if attachmentHandle and attachmentHandle ~= 0 and ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                table.insert(vehicleData.attachments, attachmentHandle)
            end
        end
    end
    if vehicleData.vehicle or #vehicleData.attachments > 0 then
        table.insert(spawnedVehicles, vehicleData)
        local filename = M.get_filename_from_path(filePath)
        local count = #vehicleData.attachments
        GUI.AddToast("Vehicle Spawned", filename .. " with " .. count .. " attachment" .. (count == 1 and "" or "s"), 5000, 0)
        print("Vehicle Spawned", filename .. " with " .. count .. " attachment" .. (count == 1 and "" or "s"))
    end
    return vehicleData
end

-- ============================================================================
-- Helper: Enter vehicle if setting is enabled
-- ============================================================================
function Core.enterVehicleIfEnabled(vehicleHandle, playerPed, isPreview, shouldHideDriver)
    if not spawnerSettings.inVehicle or isPreview then return end
    Script.Yield(500)
    local playerHandle = GTA.PointerToHandle(playerPed)
    if not playerHandle or playerHandle <= 0 then return end
    M.try_call(PED, "SET_PED_INTO_VEHICLE", playerHandle, vehicleHandle, -1)
    
    if shouldHideDriver then
        debug_print("[Spawn] IsDriverVisible is false, hiding player")
        ENTITY.SET_ENTITY_VISIBLE(playerHandle, false, false)
        
        -- Monitor for vehicle exit to restore visibility
        local vehH, pedH = vehicleHandle, playerHandle
        FreemodeQueueJob(function()
            while true do
                Script.Yield(250)
                if not ENTITY.DOES_ENTITY_EXIST(vehH) then
                    ENTITY.SET_ENTITY_VISIBLE(pedH, true, false)
                    break
                end
                if not PED.IS_PED_IN_VEHICLE(pedH, vehH, false) then
                    ENTITY.SET_ENTITY_VISIBLE(pedH, true, false)
                    break
                end
            end
        end)
    end
end

-- ============================================================================
-- Helper: Register spawned map
-- ============================================================================
function Core.registerSpawnedMap(entities, filePath, refCoords)
    local mapData = {
        entities = {},
        filePath = filePath,
        refCoords = refCoords
    }
    for _, h in ipairs(entities) do
        if h and h ~= 0 and ENTITY.DOES_ENTITY_EXIST(h) then
            table.insert(mapData.entities, h)
        end
    end
    if #mapData.entities > 0 then
        table.insert(spawnedMaps, mapData)
        local filename = M.get_filename_from_path(filePath)
        local count = #mapData.entities
        GUI.AddToast("Map Spawned", filename .. " (" .. count .. " entities)", 5000, 0)
    end
    return mapData
end

-- ============================================================================
-- Helper: Pre-spawn common checks
-- Returns nil on success, or error string on failure
-- ============================================================================
function Core.preSpawnChecks(filePath, isPreview, formatName)
    if not isPreview and currentPreviewFile and currentPreviewFile.path == filePath and #previewEntities > 0 then
        M.clearPreview()
        M.stopPreviewUpdater()
    end
    if not FileMgr.DoesFileExist(filePath) then
        debug_print("[Spawn Debug] Error: " .. formatName .. " file does not exist:", filePath)
        return "File not found"
    end
    return nil
end

-- ============================================================================
-- Helper: Delete old vehicles if setting enabled
-- ============================================================================
function Core.deleteOldIfEnabled(isPreview)
    if spawnerSettings.deleteOldVehicle and not isPreview then
        M.deleteAllSpawnedVehicles()
    end
end

-- ============================================================================
-- Helper: Log spawn failure
-- ============================================================================
function Core.logSpawnFailure(filePath, modelHash)
    local fileName = filePath:match("([^/\\]+)$") or filePath
    Logger.LogError("[Spawn] Failed to spawn vehicle from '" .. fileName .. "' (hash: " .. tostring(modelHash) .. ")")
end

-- ============================================================================
-- Helper: Resolve target ped from player index
-- Returns ped handle or nil
-- ============================================================================
function Core.resolveTargetPed(targetPlayerIndex)
    local targetPed = nil
    if targetPlayerIndex ~= nil then
        targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerIndex)
    end
    if not targetPed or targetPed == 0 then
        targetPed = GTA.GetLocalPed()
    end
    if not targetPed or targetPed == 0 then
        debug_print("[Spawn Debug] Error: No target ped available.")
        return nil
    end
    return targetPed
end

-- ============================================================================
-- Helper: Get spawn coords relative to a target ped
-- forwardOffset: positive = in front, negative = behind
-- ============================================================================
function Core.getTargetSpawnCoords(targetPed, forwardOffset)
    forwardOffset = forwardOffset or 5.0
    local off = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, forwardOffset, 0)
    local spawnCoords = {
        x = off.x or off[1] or 0.0,
        y = off.y or off[2] or 0.0,
        z = off.z or off[3] or 0.0
    }
    local foundGround, gz = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
    if foundGround then spawnCoords.z = gz end
    return spawnCoords
end

-- ============================================================================
-- Helper: Spawn vehicle at coords (used for attacker/gift/apply)
-- ============================================================================
function Core.spawnVehicleAtCoords(modelHash, spawnCoords)
    M.request_model_load(modelHash)
    local vehicleHandle = GTA.SpawnVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
    -- Fallback
    if (not vehicleHandle or vehicleHandle == 0) and entities and entities.create_vehicle then
        vehicleHandle = entities.create_vehicle(modelHash, spawnCoords, 0)
    end
    return vehicleHandle
end

-- ============================================================================
-- Helper: Create and configure an attacker ped
-- ============================================================================
function Core.setupAttackerPed(attackerModel, vehicleHandle, targetPed, spawnCoords)
    attackerModel = attackerModel or 71929310
    M.request_model_load(attackerModel)
    local attacker = GTA.CreatePed(attackerModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
    if not attacker or attacker == 0 then
        Logger.LogError("[Spawn] Failed to spawn attacker ped (hash: " .. tostring(attackerModel) .. ")")
        return nil
    end
    PED.SET_PED_INTO_VEHICLE(attacker, vehicleHandle, -1)
    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(attacker, true, true)
    ENTITY.SET_ENTITY_INVINCIBLE(attacker, true)
    PED.SET_PED_ACCURACY(attacker, 100.0)
    PED.SET_PED_COMBAT_ABILITY(attacker, 1, true)
    PED.SET_PED_FLEE_ATTRIBUTES(attacker, 0, false)
    PED.SET_PED_COMBAT_ATTRIBUTES(attacker, 46, true)
    PED.SET_PED_COMBAT_ATTRIBUTES(attacker, 5, true)
    PED.SET_PED_CONFIG_FLAG(attacker, 52, true)
    local relHash = PED.GET_PED_RELATIONSHIP_GROUP_HASH(targetPed)
    PED.SET_PED_RELATIONSHIP_GROUP_HASH(attacker, relHash)
    ENTITY.SET_ENTITY_INVINCIBLE(vehicleHandle, true)
    TASK.TASK_VEHICLE_MISSION_PED_TARGET(attacker, vehicleHandle, targetPed, 6, 500.0, 786988, 0.0, 0.0, true)
    return attacker
end

-- ============================================================================
-- Helper: Get target vehicle (for apply-attachments mode)
-- Returns: targetVehicle handle, or nil + toast if not in vehicle
-- ============================================================================
function Core.getTargetVehicle(targetPed, targetPlayerIndex, suppressToast)
    if not ENTITY.DOES_ENTITY_EXIST(targetPed) then
        local tName = Core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Apply Attachments", "Cannot find " .. tName, 5000, 0) end
        return nil
    end
    
    local targetVehicle = PED.GET_VEHICLE_PED_IS_IN(targetPed, false)
    if not targetVehicle or targetVehicle == 0 or not ENTITY.DOES_ENTITY_EXIST(targetVehicle) or not PED.IS_PED_IN_VEHICLE(targetPed, targetVehicle, false) then
        local tName = Core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Apply Attachments", tName .. " is not in a vehicle", 5000, 0) end
        return nil
    end
    
    return targetVehicle
end

-- ============================================================================
-- Helper: Get target player name
-- ============================================================================
function Core.getTargetName(targetPlayerIndex)
    local tName = "Target"
    if targetPlayerIndex then
        tName = Players.GetName(targetPlayerIndex) or "Target"
    end
    return tName
end

-- ============================================================================
-- MAP HELPERS
-- ============================================================================

-- Helper: Delete old maps if setting enabled (deletes ALL spawned maps)
function Core.deleteOldMapIfEnabled()
    if spawnerSettings.deleteOldMap and #spawnedMaps > 0 then
        for _, mapData in ipairs(spawnedMaps) do
            if mapData.entities then
                for _, entityHandle in ipairs(mapData.entities) do
                    if entityHandle and entityHandle ~= 0 then
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                                constructor_lib.delete_entity(entityHandle)
                            end
                        end)
                    end
                end
            end
        end
        for k in pairs(spawnedMaps) do spawnedMaps[k] = nil end
    end
end


function Core.clearAreaIfEnabled()
    if spawnerSettings.clearAreaBeforeMapSpawn then
        local clearFeature = FeatureMgr.GetFeatureByName("Clear Distance")
        if clearFeature then
            clearFeature:SetIntValue(1000)
        end
        FeatureMgr.TriggerFeatureCallback(53700821)
        Script.Yield(500)
    end
end

-- Helper: Apply entity options from JSON (visibility, collision, frozen, gravity, alpha)
function Core.applyEntityOptions(entityHandle, opts)
    if not opts then return end
    if opts.is_visible ~= nil then ENTITY.SET_ENTITY_VISIBLE(entityHandle, opts.is_visible, false) end
    if opts.is_invincible ~= nil then ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, opts.is_invincible) end
    if opts.has_collision ~= nil then ENTITY.SET_ENTITY_COLLISION(entityHandle, opts.has_collision, false) end
    if opts.is_frozen ~= nil then ENTITY.FREEZE_ENTITY_POSITION(entityHandle, opts.is_frozen) end
    if opts.has_gravity ~= nil and not opts.has_gravity then ENTITY.SET_ENTITY_HAS_GRAVITY(entityHandle, false) end
    if opts.alpha and opts.alpha ~= 255 then ENTITY.SET_ENTITY_ALPHA(entityHandle, opts.alpha, false) end
end

-- Helper: Spawn entity by type (vehicle/ped/object) at coords
-- Returns entity handle or nil
function Core.spawnEntityByType(entityType, modelHash, spawnPos, rotZ)
    rotZ = rotZ or 0
    M.request_model_load(modelHash)
    Script.Yield(100)
    
    local entityHandle = nil
    if entityType == "VEHICLE" then
        entityHandle = GTA.SpawnVehicle(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, rotZ, true, true)
    elseif entityType == "PED" then
        entityHandle = GTA.CreatePed(modelHash, 26, spawnPos.x, spawnPos.y, spawnPos.z, rotZ, true, true)
    else
        entityHandle = GTA.CreateObject(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, true, true)
        if not entityHandle or entityHandle == 0 then
            entityHandle = GTA.CreateWorldObject(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, true, true)
        end
    end
    
    if entityHandle and entityHandle ~= 0 then
        ENTITY.SET_ENTITY_LOD_DIST(entityHandle, 0xFFFF)
    end
    
    return entityHandle
end

-- Helper: Show progress toast for large maps
function Core.showMapProgress(fileName, current, total, threshold)
    threshold = threshold or 200
    if total > threshold then
        GUI.AddToast("Spawning Map", fileName .. " (" .. current .. "/" .. total .. ")", 1000, 0)
    end
end

-- Helper: Teleport player if teleportToMap is enabled
function Core.teleportPlayerIfEnabled(refCoords, skipIfSpawnOnMe)
    if skipIfSpawnOnMe and spawnerSettings.spawnMapOnMe then return end
    if spawnerSettings.teleportToMap and refCoords then
        local playerPed = PLAYER.PLAYER_PED_ID()
        ENTITY.SET_ENTITY_COORDS(playerPed, refCoords.x, refCoords.y, refCoords.z, false, false, false, true)
    end
end

-- Helper: Calculate spawn offset for "Spawn Map on Me" feature
-- Returns offset table {x, y, z}
function Core.calcSpawnOnMeOffset(refCoords)
    if not spawnerSettings.spawnMapOnMe or not refCoords then
        return { x = 0, y = 0, z = 0 }
    end
    local playerPed = PLAYER.PLAYER_PED_ID()
    local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, false)
    return {
        x = playerCoords.x - refCoords.x,
        y = playerCoords.y - refCoords.y,
        z = playerCoords.z - refCoords.z
    }
end

-- ============================================================================
-- OUTFIT HELPERS
-- ============================================================================

-- Helper: Delete old outfit attachments if setting enabled
function Core.deleteOldOutfitIfEnabled()
    if spawnerSettings.deleteLastOutfitAttachments and #spawnedOutfits > 0 then
        for _, outfitData in ipairs(spawnedOutfits) do
            if outfitData.attachments then
                for _, attachmentHandle in ipairs(outfitData.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        pcall(function() constructor_lib.delete_entity(attachmentHandle) end)
                    end
                end
            end
        end
        for k in pairs(spawnedOutfits) do spawnedOutfits[k] = nil end
    end
end

-- Helper: Get player ped info (returns ped pointer, handle, coords, heading)
function Core.getPlayerPedInfo()
    local playerPed = GTA.GetLocalPed()
    if not playerPed then return nil end
    local playerHandle = GTA.PointerToHandle(playerPed) or (PLAYER and PLAYER.PLAYER_PED_ID and PLAYER.PLAYER_PED_ID())
    if not playerHandle or playerHandle == 0 then return nil end
    local pcoords = ENTITY.GET_ENTITY_COORDS(playerHandle, false)
    local heading = (playerPed.Heading or 0.0)
    return {
        ped = playerPed,
        handle = playerHandle,
        coords = { x = pcoords.x, y = pcoords.y, z = pcoords.z },
        heading = heading
    }
end

-- Helper: Calculate outfit spawn coords (preview = 2m in front, normal = at player)
function Core.calcOutfitSpawnCoords(playerInfo, isPreview)
    local pcoords = playerInfo.coords
    local heading = playerInfo.heading
    if isPreview then
        local rad = math.rad(heading)
        local sc = {
            x = pcoords.x + (math.sin(rad) * 2.0),
            y = pcoords.y + (math.cos(rad) * 2.0),
            z = pcoords.z
        }
        local foundGround, groundZ = GTA.GetGroundZ(sc.x, sc.y)
        if foundGround then sc.z = groundZ end
        return sc
    else
        local forwardX = math.sin(math.rad(heading)) * 2.0
        local forwardY = math.cos(math.rad(heading)) * 2.0
        local sc = { x = pcoords.x + forwardX, y = pcoords.y + forwardY, z = pcoords.z }
        local foundGround, groundZ = GTA.GetGroundZ(sc.x, sc.y)
        if foundGround then sc.z = groundZ + 1.0 end
        return sc
    end
end

return Core


