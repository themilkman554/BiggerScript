-- ============================================================================
-- Job/Transform JSON Parser Module
-- Parses GTA Online Job/Transform/Race JSON format (Rockstar Creator exports)
-- Structure: { mission: { prop: {...}, dprop: {...}, veh: {...} } }
-- Each section uses parallel arrays: model[], loc[], vRot[], head[], no (count)
-- ============================================================================
local P = {}

-- Shared utility references (set via init)
local safe_tonumber, trim, to_boolean, debug_print

-- ============================================================================
-- Init
-- ============================================================================
function P.init(ctx)
    safe_tonumber = ctx.safe_tonumber
    trim = ctx.trim
    to_boolean = ctx.to_boolean
    debug_print = ctx.debug_print
end

-- ============================================================================
-- Format detection: Is this a Job/Transform JSON?
-- Checks for the presence of mission.prop or mission.dprop or mission.veh
-- with the parallel-array structure (model[], loc[], no)
-- ============================================================================
function P.isJobFormat(jsonData)
    if not jsonData then return false end
    if type(jsonData) ~= "table" then return false end
    local mission = jsonData.mission
    if not mission or type(mission) ~= "table" then return false end

    -- Check for at least one entity section with the characteristic parallel-array layout
    local sections = { mission.prop, mission.dprop, mission.veh }
    for _, section in ipairs(sections) do
        if type(section) == "table" and section.model and section.loc and section.no then
            return true
        end
    end
    return false
end

-- ============================================================================
-- Internal: Extract entities from a single section (prop / dprop / veh)
-- Returns an array of entity descriptors:
--   { model=hash, pos={x,y,z}, rot={x,y,z}, heading=n, entityType=string }
-- ============================================================================
local function extractEntitiesFromSection(section, entityType, tintFieldName)
    local entities = {}
    if not section or type(section) ~= "table" then return entities end

    local count = section.no or 0
    if count == 0 then return entities end

    local models = section.model or {}
    local locs   = section.loc   or {}
    local rots   = section.vRot  or {}
    local heads  = section.head  or {}
    local tints  = (tintFieldName and section[tintFieldName]) or {}

    for i = 1, count do
        local modelHash = models[i]
        -- Skip entries with model hash 0 (placeholder/empty slots)
        if modelHash and modelHash ~= 0 then
            local pos = locs[i] or { x = 0, y = 0, z = 0 }
            local rot = rots[i]  -- may be nil (vehicles often only have heading)
            local heading = heads[i] or 0
            local tintIndex = tints[i]  -- texture variation index, may be nil

            local entity = {
                model = modelHash,
                pos = {
                    x = pos.x or 0,
                    y = pos.y or 0,
                    z = pos.z or 0
                },
                rot = rot and {
                    x = rot.x or 0,
                    y = rot.y or 0,
                    z = rot.z or 0
                } or nil,
                heading = heading,
                entityType = entityType,
                tintIndex = tintIndex
            }
            table.insert(entities, entity)
        end
    end

    return entities
end

-- ============================================================================
-- Parse all spawnable entities from a Job JSON
-- Returns a table:
--   { entities = {entity, ...}, refCoords = {x,y,z} or nil, name = string }
-- ============================================================================
function P.parseJobEntities(jsonData)
    if not jsonData or not jsonData.mission then
        return { entities = {}, refCoords = nil, name = "" }
    end

    local mission = jsonData.mission
    local allEntities = {}

    -- 1. Props (mission.prop) — static objects/scenery (tint field: prpclr)
    local props = extractEntitiesFromSection(mission.prop, "OBJECT", "prpclr")
    for _, e in ipairs(props) do table.insert(allEntities, e) end

    -- 2. Dynamic Props (mission.dprop) — interactive/destructible props (tint field: prpdclr)
    local dprops = extractEntitiesFromSection(mission.dprop, "OBJECT", "prpdclr")
    for _, e in ipairs(dprops) do table.insert(allEntities, e) end

    -- 3. Vehicles (mission.veh) — no texture tint for vehicles
    local vehicles = extractEntitiesFromSection(mission.veh, "VEHICLE", nil)
    for _, e in ipairs(vehicles) do table.insert(allEntities, e) end

    -- Determine reference coordinates from first entity or free spawn point (fsp)
    local refCoords = nil
    if mission.fsp and mission.fsp.loc and mission.fsp.loc[1] then
        local fspLoc = mission.fsp.loc[1]
        if fspLoc.x ~= 0 or fspLoc.y ~= 0 or fspLoc.z ~= 0 then
            refCoords = { x = fspLoc.x, y = fspLoc.y, z = fspLoc.z }
        end
    end
    if not refCoords and #allEntities > 0 then
        refCoords = {
            x = allEntities[1].pos.x,
            y = allEntities[1].pos.y,
            z = allEntities[1].pos.z
        }
    end

    return {
        entities = allEntities,
        refCoords = refCoords
    }
end

-- ============================================================================
-- Count entities by type for context preview
-- ============================================================================
function P.countEntities(jsonData)
    if not jsonData or not jsonData.mission then
        return { objects = 0, vehicles = 0, peds = 0, total = 0 }
    end

    local mission = jsonData.mission
    local counts = { objects = 0, vehicles = 0, peds = 0, total = 0 }

    -- Count props
    if mission.prop and mission.prop.no then
        -- Only count non-zero model entries
        local propModels = mission.prop.model or {}
        for i = 1, (mission.prop.no or 0) do
            if propModels[i] and propModels[i] ~= 0 then
                counts.objects = counts.objects + 1
            end
        end
    end

    -- Count dynamic props
    if mission.dprop and mission.dprop.no then
        local dpropModels = mission.dprop.model or {}
        for i = 1, (mission.dprop.no or 0) do
            if dpropModels[i] and dpropModels[i] ~= 0 then
                counts.objects = counts.objects + 1
            end
        end
    end

    -- Count vehicles
    if mission.veh and mission.veh.no then
        local vehModels = mission.veh.model or {}
        for i = 1, (mission.veh.no or 0) do
            if vehModels[i] and vehModels[i] ~= 0 then
                counts.vehicles = counts.vehicles + 1
            end
        end
    end

    counts.total = counts.objects + counts.vehicles + counts.peds
    return counts
end

-- ============================================================================
-- Context preview metadata for Job JSON files
-- ============================================================================
function P.parseMetadata(content, filePath, parseJSON)
    local metadata = {}

    local jsonData = parseJSON(content)
    if not jsonData then return nil end

    if not P.isJobFormat(jsonData) then return nil end

    metadata.itemType = "map"

    local counts = P.countEntities(jsonData)
    metadata.objectCount = counts.objects
    metadata.vehicleCount = counts.vehicles
    metadata.pedCount = counts.peds
    metadata.entityCount = counts.total

    return metadata
end

return P
