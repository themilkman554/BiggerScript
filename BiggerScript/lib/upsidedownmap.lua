local M = {}


local spawnerSettings, debug_print, spawnedMaps, xmlMapsFolder, constructor_lib, parse_map_placements, create_by_type, request_model_load, safe_tonumber, get_filename_from_path, to_boolean, get_xml_element_content, spawnedProps, spawnMapFromXML, deleteAllSpawnedMaps


function M.init(context)
    spawnerSettings = context.spawnerSettings
    debug_print = context.debug_print
    spawnedMaps = context.spawnedMaps
    xmlMapsFolder = context.xmlMapsFolder
    constructor_lib = context.constructor_lib
    parse_map_placements = context.parse_map_placements
    create_by_type = context.create_by_type
    request_model_load = context.request_model_load
    safe_tonumber = context.safe_tonumber
    get_filename_from_path = context.get_filename_from_path
    to_boolean = context.to_boolean
    get_xml_element_content = context.get_xml_element_content
    spawnedProps = context.spawnedProps
    spawnMapFromXML = context.spawnMapFromXML
    deleteAllSpawnedMaps = context.deleteAllSpawnedMaps
end

local upsideDownRadars = {}

function M.spawnUpsideDownMapV3()
    Script.QueueJob(function()
        local ENTITIES_PER_RADAR = 20
        local mapFileName = "Upside_Down_Worldv2.xml"
        local subFolder = "Upside Down Maps and Big World Stuff"
        local mapFolderPath = xmlMapsFolder .. "\\" .. subFolder
        debug_print("[Spawn Debug] xmlMapsFolder:", xmlMapsFolder)
        debug_print("[Spawn Debug] subFolder:", subFolder)
        debug_print("[Spawn Debug] mapFolderPath:", mapFolderPath)
        local radarModelName = "prop_air_bigradar_slod"
        local radarModelHash = Utils.Joaat(radarModelName)
        local fixedRadarSpawnCoords = {
            x = -74.91609191894531,
            y = -819.2665405273438,
            z = 326.17510986328125
        }
        
        local local_SET_ENTITY_INVINCIBLE = ENTITY.SET_ENTITY_INVINCIBLE
        local local_FREEZE_ENTITY_POSITION = ENTITY.FREEZE_ENTITY_POSITION
        local local_SET_ENTITY_AS_MISSION_ENTITY = ENTITY.SET_ENTITY_AS_MISSION_ENTITY
        local local_SET_ENTITY_LOD_DIST = ENTITY.SET_ENTITY_LOD_DIST
        local local_ATTACH_ENTITY_TO_ENTITY = ENTITY.ATTACH_ENTITY_TO_ENTITY
        local local_DOES_ENTITY_EXIST = ENTITY.DOES_ENTITY_EXIST
        local local_IS_ENTITY_ATTACHED = ENTITY.IS_ENTITY_ATTACHED
        
        local filePath = mapFolderPath .. "\\" .. mapFileName
        debug_print("[Spawn Debug] Attempting to spawn Upside Down Map v2 from:", filePath)
        
        if not FileMgr.DoesFileExist(filePath) then
            debug_print("[Spawn Debug] Error: XML map file does not exist:", filePath)
            pcall(function() GUI.AddToast("Spawn Error", "Map file not found: " .. mapFileName, 5000, 1) end)
            return
        end
        
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then
            debug_print("[Spawn Debug] Error: Failed to read XML map file or content is empty:", filePath)
            return
        end
        
        local placements = parse_map_placements(xmlContent)
        if not placements or #placements == 0 then
            debug_print("[Spawn Debug] Warning: No placements found in XML map file:", filePath)
            return
        end
        
        debug_print("[Spawn Debug] Found " .. #placements .. " placements in map file")
        
        -- Spawn the map first
        spawnMapFromXML(filePath)
        Script.Yield(2000)
        
        local mapData = spawnedMaps[#spawnedMaps]
        if not mapData or mapData.filePath ~= filePath then
            debug_print("[Spawn Debug] Error: Could not find the spawned map data for attachment.")
            return
        end
        
        local entities = mapData.entities or {}
        local totalEntities = #entities
        local radarCount = math.ceil(totalEntities / ENTITIES_PER_RADAR)
        
        debug_print("[Spawn Debug] Total entities: " .. totalEntities .. ", creating " .. radarCount .. " radars")
        
        -- Pre-load the radar model
        request_model_load(radarModelHash)
        if not STREAMING.HAS_MODEL_LOADED(radarModelHash) then
            debug_print("[Spawn Debug] Error: Model '" .. radarModelName .. "' failed to load.")
            return
        end
        
        local currentRadar = nil
        local entitiesAttachedToCurrentRadar = 0
        local radarIndex = 0
        
        for j, entityHandle in ipairs(entities) do
            -- Create a new radar every ENTITIES_PER_RADAR entities
            if entitiesAttachedToCurrentRadar == 0 or entitiesAttachedToCurrentRadar >= ENTITIES_PER_RADAR then
                radarIndex = radarIndex + 1
                entitiesAttachedToCurrentRadar = 0
                
                -- Spawn a new radar
                currentRadar = create_by_type(radarModelHash, 3, fixedRadarSpawnCoords)
                if not currentRadar or currentRadar == 0 then
                    debug_print("[Spawn Debug] Error: Failed to spawn radar #" .. radarIndex)
                    goto continue_entity_loop
                end
                
                pcall(function()
                    local_SET_ENTITY_INVINCIBLE(currentRadar, true)
                    local_FREEZE_ENTITY_POSITION(currentRadar, true)
                    local_SET_ENTITY_AS_MISSION_ENTITY(currentRadar, true, false)
                    local_SET_ENTITY_LOD_DIST(currentRadar, 16960)
                    if spawnerSettings.networkMapsV2Enabled then
                        constructor_lib.make_entity_networked({handle = currentRadar})
                        debug_print("[Spawn Debug] Radar #" .. radarIndex .. " networked:", tostring(currentRadar))
                    end
                end)
                
                table.insert(spawnedProps, currentRadar)
                table.insert(upsideDownRadars, currentRadar)
                table.insert(mapData.entities, currentRadar)
                
                debug_print("[Spawn Debug] Created radar #" .. radarIndex .. " with handle:", tostring(currentRadar))
                Script.Yield(500)
            end
            
            -- Attach entity to current radar
            local placement = placements[j]
            if placement and placement.PositionRotation and currentRadar then
                local pos = placement.PositionRotation
                local rot = placement.PositionRotation
                local offsetX = (pos.X or 0.0) - fixedRadarSpawnCoords.x
                local offsetY = (pos.Y or 0.0) - fixedRadarSpawnCoords.y
                local offsetZ = (pos.Z or 0.0) - fixedRadarSpawnCoords.z
                
                Script.Yield(50)
                
                if not entityHandle or not local_DOES_ENTITY_EXIST(entityHandle) then
                    debug_print("[Attach Debug] Warning: Entity handle", tostring(entityHandle), "does not exist. Skipping.")
                    goto continue_entity_loop
                end
                
                if local_IS_ENTITY_ATTACHED(entityHandle) then
                    debug_print("[Attach Debug] Info: Entity", tostring(entityHandle), "is already attached. Skipping.")
                    goto continue_entity_loop
                end
                
                local success, err = pcall(function()
                    local_SET_ENTITY_AS_MISSION_ENTITY(entityHandle, true, false)
                    local_SET_ENTITY_LOD_DIST(entityHandle, 0xFFFF)
                    local_ATTACH_ENTITY_TO_ENTITY(
                        entityHandle,
                        currentRadar,
                        1,
                        offsetX, offsetY, offsetZ,
                        rot.Pitch or 0.0, rot.Roll or 0.0, rot.Yaw or 0.0,
                        false, false, false, false, 2, true
                    )
                end)
                
                if success then
                    entitiesAttachedToCurrentRadar = entitiesAttachedToCurrentRadar + 1
                    debug_print("[Attach Debug] Attached entity " .. j .. "/" .. totalEntities .. " to radar #" .. radarIndex)
                    if spawnerSettings.networkMapsV2Enabled then
                        pcall(function()
                            constructor_lib.make_entity_networked({handle = entityHandle})
                        end)
                    end
                else
                    debug_print("[Attach Debug] Error attaching entity", tostring(entityHandle), ":", tostring(err))
                end
            else
                debug_print("[Attach Debug] Warning: No position/rotation data for entity handle:", tostring(entityHandle))
            end
            
            ::continue_entity_loop::
        end
        
        pcall(function() GUI.AddToast("Upside Down Map", "Attached " .. totalEntities .. " entities to " .. radarIndex .. " radars", 5000, 0) end)
        debug_print("[Spawn Debug] Upside Down Map v2 spawn complete: " .. totalEntities .. " entities on " .. radarIndex .. " radars")
    end)
end

function M.clearUpsideDownMap()
    Script.QueueJob(function()
        if deleteAllSpawnedMaps then
            deleteAllSpawnedMaps()
        end
        
        pcall(function() GUI.AddToast("Upside Down Map", "Cleared Upside Down Map and Radars", 3000, 0) end)
    end)
end

function M.toggle_upside_down_map(state)
    if state then
        M.spawnUpsideDownMapV3()
    else
        M.clearUpsideDownMap()
    end
end

return M
