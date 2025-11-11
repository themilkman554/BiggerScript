local M = {}


local spawnerSettings, debug_print, spawnedMaps, xmlMapsFolder, constructor_lib, parse_map_placements, create_by_type, request_model_load, safe_tonumber, get_filename_from_path, to_boolean, get_xml_element_content, spawnedProps, spawnMapFromXML


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
end

function M.spawnUpsideDownMapV3()
    Script.QueueJob(function()
        local mapFiles = {
            "Upside_Down_Worldv3part1.xml",
            "Upside_Down_Worldv3part2.xml",
            "Upside_Down_Worldv3part3.xml"
        }
        local radarModelName = "prop_air_bigradar_slod"
        local radarModelHash = Utils.Joaat(radarModelName)
        local fixedRadarSpawnCoords = {
            x = -74.91609191894531,
            y = -819.2665405273438,
            z = 326.17510986328125
        }
        for i, mapFileName in ipairs(mapFiles) do
            local local_SET_ENTITY_INVINCIBLE = ENTITY.SET_ENTITY_INVINCIBLE
            local local_FREEZE_ENTITY_POSITION = ENTITY.FREEZE_ENTITY_POSITION
            local local_SET_ENTITY_AS_MISSION_ENTITY = ENTITY.SET_ENTITY_AS_MISSION_ENTITY
            local local_SET_ENTITY_LOD_DIST = ENTITY.SET_ENTITY_LOD_DIST
            local local_ATTACH_ENTITY_TO_ENTITY = ENTITY.ATTACH_ENTITY_TO_ENTITY
            local local_DOES_ENTITY_EXIST = ENTITY.DOES_ENTITY_EXIST
            local local_IS_ENTITY_ATTACHED = ENTITY.IS_ENTITY_ATTACHED
            local filePath = xmlMapsFolder .. "\\" .. mapFileName
            debug_print("[Spawn Debug] Attempting to spawn Upside Down Map v3 part " .. i .. " from:", filePath)
            if not FileMgr.DoesFileExist(filePath) then
                debug_print("[Spawn Debug] Error: XML map file does not exist:", filePath)
                pcall(function() GUI.AddToast("Spawn Error", "Map file not found: " .. mapFileName, 5000, 1) end)
                goto continue_map_loop
            end
            local xmlContent = FileMgr.ReadFileContent(filePath)
            if not xmlContent or xmlContent == "" then
                debug_print("[Spawn Debug] Error: Failed to read XML map file or content is empty:", filePath)
                goto continue_map_loop
            end
            local placements = parse_map_placements(xmlContent)
            if not placements or #placements == 0 then
                debug_print("[Spawn Debug] Warning: No placements found in XML map file:", filePath)
                goto continue_map_loop
            end

            spawnMapFromXML(filePath)
            Script.Yield(2000)
            request_model_load(radarModelHash)
            if not STREAMING.HAS_MODEL_LOADED(radarModelHash) then
                debug_print("[Spawn Debug] Error: Model '" .. radarModelName .. "' failed to load for map part " .. i .. ".")
                goto continue_map_loop
            end
            local radarHandle = create_by_type(radarModelHash, 3, fixedRadarSpawnCoords)
            if not radarHandle or radarHandle == 0 then
                debug_print("[Spawn Debug] Error: Failed to spawn " .. radarModelName .. " at specified coordinates for map part " .. i .. ".")
                goto continue_map_loop
            end
            pcall(function()
                local_SET_ENTITY_INVINCIBLE(radarHandle, true)
                local_FREEZE_ENTITY_POSITION(radarHandle, true)
                local_SET_ENTITY_AS_MISSION_ENTITY(radarHandle, true, false)
                local_SET_ENTITY_LOD_DIST(radarHandle, 16960)
                if spawnerSettings.networkMapsV2Enabled then
                    constructor_lib.make_entity_networked({handle = radarHandle})
                    debug_print("[Spawn Debug] Radar entity networked for map part " .. i .. ":", tostring(radarHandle))
                end
            end)
            table.insert(spawnedProps, radarHandle)
            debug_print("[Spawn Debug] Spawned " .. radarModelName .. " with handle:", tostring(radarHandle), "at:", fixedRadarSpawnCoords.x, fixedRadarSpawnCoords.y, fixedRadarSpawnCoords.z, "for map part " .. i .. ".")
            Script.Yield(1000)
            local mapData = spawnedMaps[#spawnedMaps]
            if not mapData or mapData.filePath ~= filePath then
                debug_print("[Spawn Debug] Error: Could not find the spawned map data for attachment for map part " .. i .. ".")
                goto continue_map_loop
            end
            if #mapData.entities ~= #placements then
                debug_print("[Spawn Debug] Error: Mismatch between spawned entities and parsed placements for map part " .. i .. ". Aborting attachment.")
                goto continue_map_loop
            end
            if not radarHandle or not local_DOES_ENTITY_EXIST(radarHandle) then
                debug_print("[Spawn Debug] Error: Radar entity does not exist or is invalid for map part " .. i .. ". Cannot attach map props.")
                pcall(function() GUI.AddToast("Attachment Error", "Radar not found for attaching map props for " .. mapFileName, 5000, 1) end)
                goto continue_map_loop
            end
            for j, entityHandle in ipairs(mapData.entities) do
                local placement = placements[j]
                if placement and placement.PositionRotation then
                    local pos = placement.PositionRotation
                    local rot = placement.PositionRotation
                    local offsetX = (pos.X or 0.0) - fixedRadarSpawnCoords.x
                    local offsetY = (pos.Y or 0.0) - fixedRadarSpawnCoords.y
                    local offsetZ = (pos.Z or 0.0) - fixedRadarSpawnCoords.z
                    Script.Yield(50)
                    if not entityHandle or not local_DOES_ENTITY_EXIST(entityHandle) then
                        debug_print("[Attach Debug] Warning: Map entity handle", tostring(entityHandle), "does not exist. Skipping attachment for map part " .. i .. ".")
                        goto continue_attachment_loop_inner
                    end
                    if local_IS_ENTITY_ATTACHED(entityHandle) then
                        debug_print("[Attach Debug] Info: Entity", tostring(entityHandle), "is already attached. Skipping re-attachment for map part " .. i .. ".")
                        goto continue_attachment_loop_inner
                    end
                debug_print("[Attach Debug] Attempting to attach entity", entityHandle, "to radar", radarHandle, "with relative offsets:", offsetX, offsetY, offsetZ, "and rotation:", rot.Pitch, rot.Roll, rot.Yaw, "for map part " .. i .. ".")
                local success, err = pcall(function()
                    local_SET_ENTITY_AS_MISSION_ENTITY(entityHandle, true, false)
                    local_SET_ENTITY_LOD_DIST(entityHandle, 0xFFFF)
                    local_ATTACH_ENTITY_TO_ENTITY(
                        entityHandle,
                        radarHandle,
                        1,
                        offsetX, offsetY, offsetZ,
                        rot.Pitch or 0.0, rot.Roll or 0.0, rot.Yaw or 0.0,
                        false, false, false, false, 2, true
                    )
                end)
                    if success then
                        debug_print("[Attach Debug] Successfully attached entity", tostring(entityHandle), "for map part " .. i .. ".")
                        if spawnerSettings.networkMapsV2Enabled then
                            pcall(function()
                                constructor_lib.make_entity_networked({handle = entityHandle})
                                debug_print("[Attach Debug] Attached map entity networked for map part " .. i .. ":", tostring(entityHandle))
                            end)
                        end
                    else
                        debug_print("[Attach Debug] Error attaching entity", tostring(entityHandle), "for map part " .. i .. ":", tostring(err))
                    end
                else
                    debug_print("[Attach Debug] Warning: No position/rotation data for entity handle:", entityHandle, "for map part " .. i .. ".")
                end
                ::continue_attachment_loop_inner::
            end
            pcall(function() GUI.AddToast("Map Modified", "Attached " .. #mapData.entities .. " props to radar for " .. mapFileName, 5000, 0) end)
            ::continue_map_loop::
        end
    end)
end

return M
