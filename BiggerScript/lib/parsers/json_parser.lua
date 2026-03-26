-- ============================================================================
-- JSON Parser Module
-- Parses Constructor/Stand JSON and Impulse/JamezGamez JSON formats
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
-- Core JSON-to-Lua converter (converts JSON string to Lua table)
-- ============================================================================
function P.parseJSON(jsonContent)
    if not jsonContent or jsonContent == "" then return nil end
    local success, result = pcall(function()
        local luaCode = jsonContent
        luaCode = luaCode:gsub("%[", "{")
        luaCode = luaCode:gsub("%]", "}")
        luaCode = luaCode:gsub(":null", ":nil")
        luaCode = luaCode:gsub(",null", ",nil")
        luaCode = luaCode:gsub("{null", "{nil")
        luaCode = luaCode:gsub('"([^"]+)"%s*:%s*', function(key)
            if key:match("^[%a_][%w_]*$") then
                return key .. "="
            else
                return '["' .. key .. '"]='
            end
        end)
        luaCode = "return " .. luaCode
        local func, err = load(luaCode)
        if not func then
            error("Failed to parse JSON: " .. tostring(err))
        end
        return func()
    end)
    if success and result then return result end
    return nil
end

-- ============================================================================
-- Format detection: Impulse/JamezGamez array-of-arrays format
-- Format: [ ["modelName", hash, x, y, z, rotX, rotY, rotZ, refX?, refY?, refZ?], ... ]
-- ============================================================================
function P.isImpulseArrayFormat(jsonData)
    if not jsonData then return false end
    -- Must be a numerically-indexed table (array)
    if #jsonData == 0 then return false end
    -- First element must also be a numerically-indexed table (array) with a string model name
    local first = jsonData[1]
    if type(first) ~= "table" then return false end
    -- The first element of the inner array should be a string (model name)
    if type(first[1]) ~= "string" then return false end
    -- The second element should be a number (hash)
    if type(first[2]) ~= "number" then return false end
    -- Should have at least 8 elements (name, hash, x, y, z, rotX, rotY, rotZ)
    if #first < 8 then return false end
    return true
end

-- ============================================================================
-- Count children in JSON data
-- ============================================================================
function P.countJsonChildren(jsonData)
    if not jsonData then return 0 end
    -- Check for Impulse array-of-arrays format first
    if P.isImpulseArrayFormat(jsonData) then
        return #jsonData
    end
    if jsonData.children and type(jsonData.children) == "table" then
        return #jsonData.children
    end
    if jsonData.objects and type(jsonData.objects) == "table" then
        local count = #jsonData.objects
        if jsonData.vehicles and type(jsonData.vehicles) == "table" then
            count = count + #jsonData.vehicles
        end
        return count
    end
    return 0
end

-- ============================================================================
-- Context preview metadata for JSON files
-- ============================================================================
function P.parseMetadata(content, filePath, getModelNameFromHashForPreview)
    local metadata = {}
    
    local jsonData = P.parseJSON(content)
    if not jsonData then return nil end
    
    -- Check for Impulse array-of-arrays format
    if P.isImpulseArrayFormat(jsonData) then
        metadata.itemType = "map"
        metadata.entityCount = #jsonData
        metadata.objectCount = #jsonData
        metadata.vehicleCount = 0
        metadata.pedCount = 0
        -- Use first entity's model name if available
        if jsonData[1] and type(jsonData[1][1]) == "string" then
            metadata.modelName = jsonData[1][1]
            metadata.modelHash = jsonData[1][2]
        end
    else
        local modelHash = jsonData.hash or jsonData.model
        if not modelHash and jsonData.base then
            modelHash = jsonData.base.model or (jsonData.base.data and jsonData.base.data.model)
        end
        
        if modelHash then
            metadata.modelHash = modelHash
        end
        
        metadata.attachmentCount = P.countJsonChildren(jsonData)
        metadata.objectCount = metadata.attachmentCount
        
        local typeStr = jsonData.type
        if typeStr == "VEHICLE" then
            metadata.itemType = "vehicle"
            metadata.vehicleCount = 1
            metadata.objectCount = metadata.attachmentCount
        elseif typeStr == "PED" then
            metadata.itemType = "outfit"
            metadata.pedCount = 1
            metadata.objectCount = metadata.attachmentCount
        elseif typeStr == "OBJECT" or typeStr == "MAP" then
            metadata.itemType = "map"
            metadata.entityCount = 1 + metadata.attachmentCount
            metadata.objectCount = 1 + metadata.attachmentCount
        else
            if jsonData.base then
                metadata.itemType = "vehicle"
                metadata.vehicleCount = 1
            else
                if filePath:lower():find("map") then
                    metadata.itemType = "map"
                    metadata.entityCount = 1 + metadata.attachmentCount
                    metadata.objectCount = 1 + metadata.attachmentCount
                elseif filePath:lower():find("outfit") then
                    metadata.itemType = "outfit"
                    metadata.pedCount = 1
                else
                    metadata.itemType = "vehicle"
                    metadata.vehicleCount = 1
                end
            end
        end
        
        if metadata.modelHash and getModelNameFromHashForPreview then
            metadata.modelName = getModelNameFromHashForPreview(metadata.modelHash, metadata.itemType)
        end
    end
    
    return metadata
end

return P
