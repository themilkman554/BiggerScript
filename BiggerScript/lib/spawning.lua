local M = {}
local previewUpdateJob = nil
local isPreviewUpdaterRunning = false
local lastSpawnedVehiclePath = nil

-- Context variables to be initialized by the main script
local upsidedownmap_module, spawnerSettings, debug_print, spawnedVehicles, spawnedMaps, spawnedOutfits, previewEntities, currentPreviewFile, constructor_lib, parse_ini_file, get_xml_element_content, get_xml_element, to_boolean, safe_tonumber, trim, split_str, request_model_load, xmlVehiclesFolder, iniVehiclesFolder, jsonVehiclesFolder, xmlMapsFolder, jsonMapsFolder, xmlOutfitsFolder, jsonOutfitsFolder, previewRotation, spawnedProps, currentSelectedVehicleXml, currentSelectedVehicleIni, chrxVehiclesFolder, chrxOutfitsFolder

-- Preview Feature
local previewRotation = { z = 0.0 }

local function parse_attributes(attrString)
    local attrs = {}
    if not attrString then return attrs end
    for key, value in attrString:gmatch('([%w_]+)%s*=%s*"([^"]*)"') do
        attrs[key] = value
    end
    return attrs
end

local function parse_self_closing_tag(xml, tagName)
    if not xml or not tagName then return nil end
    return xml:match("<" .. tagName .. "(.-)/>")
end

local function parse_vector_from_tag(xml, tagName)
    local snippet = parse_self_closing_tag(xml, tagName)
    if not snippet then return nil end
    local attrs = parse_attributes(snippet)
    return {
        x = M.safe_tonumber(attrs.X or attrs.x, 0.0),
        y = M.safe_tonumber(attrs.Y or attrs.y, 0.0),
        z = M.safe_tonumber(attrs.Z or attrs.z, 0.0)
    }
end

-- Functions to be initialized from the main script
function M.init(context)
    upsidedownmap_module = context.upsidedownmap_module
    spawnerSettings = context.spawnerSettings
    debug_print = context.debug_print
    spawnedVehicles = context.spawnedVehicles
    spawnedMaps = context.spawnedMaps
    spawnedOutfits = context.spawnedOutfits
    previewEntities = context.previewEntities
    currentPreviewFile = context.currentPreviewFile
    constructor_lib = context.constructor_lib
	parse_ini_file = context.parse_ini_file
    get_xml_element_content = context.get_xml_element_content
    get_xml_element = context.get_xml_element
    to_boolean = context.to_boolean
    safe_tonumber = context.safe_tonumber
    trim = context.trim
    split_str = context.split_str
    request_model_load = context.request_model_load
    xmlVehiclesFolder = context.xmlVehiclesFolder
    iniVehiclesFolder = context.iniVehiclesFolder
    jsonVehiclesFolder = context.jsonVehiclesFolder
    xmlMapsFolder = context.xmlMapsFolder
    jsonMapsFolder = context.jsonMapsFolder
    xmlOutfitsFolder = context.xmlOutfitsFolder
    jsonOutfitsFolder = context.jsonOutfitsFolder
    spawnedProps = context.spawnedProps
    currentSelectedVehicleXml = context.currentSelectedVehicleXml
    currentSelectedVehicleIni = context.currentSelectedVehicleIni
    chrxVehiclesFolder = context.chrxVehiclesFolder
    chrxOutfitsFolder = context.chrxOutfitsFolder

    upsidedownmap_module.init({
        spawnerSettings = spawnerSettings,
        debug_print = M.debug_print,
        spawnedMaps = spawnedMaps,
        xmlMapsFolder = xmlMapsFolder,
        constructor_lib = constructor_lib,
        parse_map_placements = M.parse_map_placements,
        create_by_type = M.create_by_type,
        request_model_load = M.request_model_load,
        safe_tonumber = M.safe_tonumber,
        get_filename_from_path = M.get_filename_from_path,
        to_boolean = M.to_boolean,
        get_xml_element_content = M.get_xml_element_content,
        spawnedProps = spawnedProps,
        spawnMapFromXML = M.spawnMapFromXML,
        deleteAllSpawnedMaps = M.deleteAllSpawnedMaps
    })
    
    M.spawnUpsideDownMapV3 = upsidedownmap_module.spawnUpsideDownMapV3
end

function M.debug_print(...)
    if spawnerSettings.printToDebug then
        Logger.LogInfo(...)
    end
end

-- ============================================================================
-- Context Preview Functions
-- ============================================================================

-- Context Preview state
local contextPreviewCache = {} -- Cache for file metadata: path -> {modelName, attachmentCount, entityCount, fileType, lastModified}

-- Helper function to get element content from XML (local for context preview)
local function getXmlElementContentLocal(xml, tagName)
    if not xml or not tagName then return nil end
    local pattern = "<%s*" .. tagName .. "[^>]*>(.-)</%s*" .. tagName .. "%s*>"
    local content = xml:match(pattern)
    if content then return content end
    return nil
end

-- Helper function to count attachments in XML content by type
-- Returns: { objects = n, vehicles = n, peds = n, total = n }
local function countXmlAttachmentsByType(xmlContent)
    local counts = { objects = 0, vehicles = 0, peds = 0, total = 0 }
    local spoonerSection = xmlContent:match("<SpoonerAttachments[^>]*>(.-)</SpoonerAttachments>")
    if spoonerSection then
        -- Match each Attachment block and extract its Type
        for attachmentBlock in spoonerSection:gmatch("<Attachment[^>]*>(.-)</Attachment>") do
            local typeStr = getXmlElementContentLocal(attachmentBlock, "Type")
            local typeNum = tonumber(typeStr) or 3 -- Default to object if unknown
            
            if typeNum == 1 then
                counts.peds = counts.peds + 1
            elseif typeNum == 2 then
                counts.vehicles = counts.vehicles + 1
            else
                counts.objects = counts.objects + 1
            end
            counts.total = counts.total + 1
        end
    end
    return counts
end

-- Helper function to count attachments in XML content (legacy, still used)
local function countXmlAttachments(xmlContent)
    local counts = countXmlAttachmentsByType(xmlContent)
    return counts.total
end

-- Helper function to count placements in map XML by type
-- Returns: { objects = n, vehicles = n, peds = n, total = n }
local function countMapPlacementsByType(xmlContent)
    local counts = { objects = 0, vehicles = 0, peds = 0, total = 0 }
    for placementBlock in xmlContent:gmatch("<Placement[^>]*>(.-)</Placement>") do
        local typeStr = getXmlElementContentLocal(placementBlock, "Type")
        local typeNum = tonumber(typeStr) or 3 -- Default to object if unknown
        
        if typeNum == 1 then
            counts.peds = counts.peds + 1
        elseif typeNum == 2 then
            counts.vehicles = counts.vehicles + 1
        else
            counts.objects = counts.objects + 1
        end
        counts.total = counts.total + 1
    end
    return counts
end

-- Helper function to count placements in map XML (legacy)
local function countMapPlacements(xmlContent)
    local counts = countMapPlacementsByType(xmlContent)
    return counts.total
end

-- Helper function to count children in JSON data
local function countJsonChildren(jsonData)
    if not jsonData then return 0 end
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

-- Parse JSON file to Lua table (simple parser for context preview)
local function parseJsonForPreview(jsonContent)
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
        if not func then return nil end
        return func()
    end)
    if success and result then return result end
    return nil
end

-- Get model name from hash based on entity type
local function getModelNameFromHashForPreview(hash, entityType)
    if not hash then return nil end
    local hashNum = tonumber(hash)
    if not hashNum then return tostring(hash) end
    
    local name = nil
    
    if entityType == "vehicle" then
        pcall(function()
            local displayName = GTA.GetDisplayNameFromHash(hashNum)
            if displayName and displayName ~= "" and displayName ~= "null" then
                name = displayName
            end
        end)
    elseif entityType == "outfit" or entityType == "ped" then
        pcall(function()
            local modelName = GTA.GetModelNameFromHash(hashNum)
            if modelName and modelName ~= "" and modelName ~= "null" then
                name = modelName
            end
        end)
    else
        pcall(function()
            local displayName = GTA.GetDisplayNameFromHash(hashNum)
            if displayName and displayName ~= "" and displayName ~= "null" then
                name = displayName
            end
        end)
        if not name then
            pcall(function()
                local modelName = GTA.GetModelNameFromHash(hashNum)
                if modelName and modelName ~= "" and modelName ~= "null" then
                    name = modelName
                end
            end)
        end
    end
    
    return name or string.format("0x%X", hashNum)
end

-- Parse file metadata for context preview
local function parseFileMetadata(filePath, fileType)
    if not filePath or not FileMgr.DoesFileExist(filePath) then
        return nil
    end
    
    if contextPreviewCache[filePath] then
        return contextPreviewCache[filePath]
    end
    
    local metadata = {
        modelName = nil,
        modelHash = nil,
        attachmentCount = 0,
        entityCount = 0,
        objectCount = 0,
        vehicleCount = 0,
        pedCount = 0,
        fileType = fileType,
        itemType = nil
    }
    
    local content = FileMgr.ReadFileContent(filePath)
    if not content or content == "" then
        return nil
    end
    
    local ext = filePath:lower():match("%.([^%.]+)$")
    
    if ext == "xml" then
        local hasMapPlacements = content:find("<Placement[^>]*>") ~= nil
        local hasSpoonerAttachments = content:find("<SpoonerAttachments") ~= nil
        local isMapFile = hasMapPlacements and not hasSpoonerAttachments
        
        if isMapFile then
            metadata.itemType = "map"
            local counts = countMapPlacementsByType(content)
            metadata.entityCount = counts.total
            metadata.objectCount = counts.objects
            metadata.vehicleCount = counts.vehicles
            metadata.pedCount = counts.peds
        else
            local modelHash = getXmlElementContentLocal(content, "ModelHash")
            if modelHash then
                metadata.modelHash = modelHash
            end
            
            local hashName = getXmlElementContentLocal(content, "HashName")
            local counts = countXmlAttachmentsByType(content)
            metadata.attachmentCount = counts.total
            metadata.objectCount = counts.objects
            metadata.vehicleCount = counts.vehicles
            metadata.pedCount = counts.peds
            
            -- Determine base entity type
            local typeStr = getXmlElementContentLocal(content, "Type")
            if typeStr == "1" then
                metadata.itemType = "outfit"
                metadata.pedCount = metadata.pedCount + 1 -- Add base ped
            elseif typeStr == "2" then
                metadata.itemType = "vehicle"
                metadata.vehicleCount = metadata.vehicleCount + 1 -- Add base vehicle
            else
                if filePath:lower():find("outfit") then
                    metadata.itemType = "outfit"
                    metadata.pedCount = metadata.pedCount + 1
                elseif filePath:lower():find("vehicle") then
                    metadata.itemType = "vehicle"
                    metadata.vehicleCount = metadata.vehicleCount + 1
                else
                    metadata.itemType = "vehicle"
                    metadata.vehicleCount = metadata.vehicleCount + 1
                end
            end
            
            if metadata.modelHash then
                metadata.modelName = getModelNameFromHashForPreview(metadata.modelHash, metadata.itemType)
            end
            if not metadata.modelName and hashName then
                metadata.modelName = hashName
            end
        end
    elseif ext == "ini" then
        metadata.itemType = "vehicle"
        
        local vehicleSection = content:match("%[Vehicle%](.-)%[") or content:match("%[Vehicle0%](.-)%[") or content:match("%[Vehicle%](.*)$") or content:match("%[Vehicle0%](.*)$")
        if vehicleSection then
            local hash = vehicleSection:match("Hash%s*=%s*([^\r\n]+)")
                      or vehicleSection:match("ModelHash%s*=%s*([^\r\n]+)")
                      or vehicleSection:match("Model%s*=%s*([^\r\n]+)")
            if hash then
                hash = hash:match("^%s*(.-)%s*$")
                metadata.modelHash = hash
                metadata.modelName = getModelNameFromHashForPreview(hash, "vehicle")
            end
        end
        
        -- Count attached objects (all considered objects in INI format)
        local attachCount = 0
        for sectionName in content:gmatch("%[([^%]]+)%]") do
            if sectionName:match("^%d+$") or sectionName:match("^Attached Object %d+$") or sectionName:match("^Object%d+$") then
                attachCount = attachCount + 1
            end
        end
        
        -- Count additional vehicles
        local extraVehicles = 0
        for num in content:gmatch("%[Vehicle(%d+)%]") do
            if tonumber(num) > 0 then
                extraVehicles = extraVehicles + 1
            end
        end
        
        metadata.attachmentCount = attachCount + extraVehicles
        metadata.objectCount = attachCount
        metadata.vehicleCount = 1 + extraVehicles -- Base vehicle + attached vehicles
        metadata.pedCount = 0
    elseif ext == "json" then
        local jsonData = parseJsonForPreview(content)
        if jsonData then
            local modelHash = jsonData.hash or jsonData.model
            if not modelHash and jsonData.base then
                modelHash = jsonData.base.model or (jsonData.base.data and jsonData.base.data.model)
            end
            
            if modelHash then
                metadata.modelHash = modelHash
            end
            
            metadata.attachmentCount = countJsonChildren(jsonData)
            -- For JSON, we can't easily determine type breakdown, assume all objects for now
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
            
            if metadata.modelHash then
                metadata.modelName = getModelNameFromHashForPreview(metadata.modelHash, metadata.itemType)
            end
        end
    end
    
    contextPreviewCache[filePath] = metadata
    
    return metadata
end

-- Render context preview tooltip
local function renderContextPreviewTooltip(filePath, itemType)
    if not spawnerSettings or not spawnerSettings.contextPreview then return end
    if not filePath then return end
    
    local metadata = parseFileMetadata(filePath, itemType)
    if not metadata then return end
    
    -- Get network limits using natives
    local maxObjects = 0
    local maxVehicles = 0
    local maxPeds = 0
    
    pcall(function()
        if NETWORK and NETWORK.GET_MAX_NUM_NETWORK_OBJECTS then
            maxObjects = NETWORK.GET_MAX_NUM_NETWORK_OBJECTS()
        end
    end)
    pcall(function()
        if NETWORK and NETWORK.GET_MAX_NUM_NETWORK_VEHICLES then
            maxVehicles = NETWORK.GET_MAX_NUM_NETWORK_VEHICLES()
        end
    end)
    pcall(function()
        if NETWORK and NETWORK.GET_MAX_NUM_NETWORK_PEDS then
            maxPeds = NETWORK.GET_MAX_NUM_NETWORK_PEDS()
        end
    end)
    
    -- Helper to determine if count is under limit
    local function isUnderLimit(count, limit)
        if limit <= 0 then return true end -- If we can't get the limit, assume ok
        return count < limit
    end
    
    ImGui.BeginTooltip()
    
    -- Display model name for vehicles/outfits
    if metadata.itemType ~= "map" then
        if metadata.modelName then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.SetWindowFontScale(1.1)
            ImGui.Text(metadata.modelName)
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()
        elseif metadata.modelHash then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.SetWindowFontScale(1.1)
            ImGui.Text(tostring(metadata.modelHash))
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()
        end
        
        ImGui.Separator()
    end
    
    -- Display Objects count with color based on limit
    local objectCount = metadata.objectCount or 0
    if objectCount > 0 then
        if isUnderLimit(objectCount, maxObjects) then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0) -- Light blue
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.6, 0.2, 1.0) -- Orange
        end
        ImGui.Text("Objects: " .. tostring(objectCount))
        ImGui.PopStyleColor()
    end
    
    -- Display Vehicles count with color based on limit
    local vehicleCount = metadata.vehicleCount or 0
    if vehicleCount > 0 then
        if isUnderLimit(vehicleCount, maxVehicles) then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0) -- Light blue
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.6, 0.2, 1.0) -- Orange
        end
        ImGui.Text("Vehicles: " .. tostring(vehicleCount))
        ImGui.PopStyleColor()
    end
    
    -- Display Peds count with color based on limit
    local pedCount = metadata.pedCount or 0
    if pedCount > 0 then
        if isUnderLimit(pedCount, maxPeds) then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0) -- Light blue
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.6, 0.2, 1.0) -- Orange
        end
        ImGui.Text("Peds: " .. tostring(pedCount))
        ImGui.PopStyleColor()
    end
    
    -- If all counts are 0 for a map, show total entity count
    if metadata.itemType == "map" and objectCount == 0 and vehicleCount == 0 and pedCount == 0 then
        local totalEntities = metadata.entityCount or 0
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
        ImGui.Text("Entities: " .. tostring(totalEntities))
        ImGui.PopStyleColor()
    end
    
    ImGui.EndTooltip()
end

-- Public function to handle hover callback for context preview
function M.handleContextPreviewHover(fileInfo)
    if not spawnerSettings or not spawnerSettings.contextPreview then return end
    if not fileInfo or not fileInfo.path then return end
    
    renderContextPreviewTooltip(fileInfo.path, fileInfo.type)
end

-- ============================================================================
-- End Context Preview Functions
-- ============================================================================


function M.trim(s)
    if not s then return s end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.safe_tonumber(str, default)
    if str == nil then return default end
    str = tostring(str)
    str = M.trim(str)
    if str == "" then return default end
    if str:match("^0[xX][0-9a-fA-F]+$") then
        local ok, n = pcall(function() return tonumber(str:sub(3), 16) end)
        if ok and n then return n end
        return default
    end
    local n = tonumber(str)
    if n ~= nil then return n end
    local firstNum = str:match("([%+%-]?%d+%.?%d*)")
    if firstNum then
        local n2 = tonumber(firstNum)
        if n2 ~= nil then return n2 end
    end
    return default
end

function M.to_boolean(text)
    if not text then return false end
    text = tostring(text)
    if text == "true" or text == "1" or text:lower() == "true" then return true end
    return false
end

function M.split_str(inputstr, sep)
    if inputstr == nil then return {} end
    if sep == nil then sep = "%s" end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do table.insert(t, M.trim(str)) end
    return t
end

function M.get_xml_element_content(xml, tag)
    if not xml or not tag then return nil end
    local pattern = "<" .. tag .. ">([^<]*)</" .. tag .. ">"
    local match = xml:match(pattern)
    if match then return M.trim(match) end
    pattern = "<" .. tag .. "[^>]*>([^<]*)</" .. tag .. ">"
    match = xml:match(pattern)
    if match then return M.trim(match) end
    return nil
end

function M.get_xml_element(xml, tag)
    if not xml or not tag then return nil end
    local pattern = "<" .. tag .. "([^>]*)>(.-)</" .. tag .. ">"
    local match = xml:match(pattern)
    if match then
        local content = xml:match("<" .. tag .. "[^>]*>(.-)</" .. tag .. ">")
        return content
    end
    return nil
end

function M.finalizePreviewVehicle(entities)
    for _, entity in ipairs(entities) do
        ENTITY.FREEZE_ENTITY_POSITION(entity, false)
        ENTITY.SET_ENTITY_COLLISION(entity, true, true)
        ENTITY.SET_ENTITY_PROOFS(entity, false, false, false, false, false, false, false, false)
    end
end

function M.parse_outfit_ped_data(xmlContent)
    local outfitData = {}
    outfitData.ModelHash = M.get_xml_element_content(xmlContent, "ModelHash")
    outfitData.Type = M.get_xml_element_content(xmlContent, "Type")
    outfitData.InitialHandle = M.get_xml_element_content(xmlContent, "InitialHandle")
    local pedPropsElement = M.get_xml_element(xmlContent, "PedProperties")
    if pedPropsElement then
        outfitData.PedProperties = {}
        outfitData.PedProperties.IsStill = M.to_boolean(M.get_xml_element_content(pedPropsElement, "IsStill"))
        outfitData.PedProperties.CanRagdoll = M.to_boolean(M.get_xml_element_content(pedPropsElement, "CanRagdoll"))
        outfitData.PedProperties.HasShortHeight = M.to_boolean(M.get_xml_element_content(pedPropsElement, "HasShortHeight"))
        outfitData.PedProperties.Armour = M.safe_tonumber(M.get_xml_element_content(pedPropsElement, "Armour"), 0)
        outfitData.PedProperties.CurrentWeapon = M.get_xml_element_content(pedPropsElement, "CurrentWeapon")
        outfitData.PedProperties.RelationshipGroup = M.get_xml_element_content(pedPropsElement, "RelationshipGroup")
        local pedPropsSubElement = M.get_xml_element(pedPropsElement, "PedProps")
        if pedPropsSubElement then
            outfitData.PedProperties.PedProps = {}
            for propId, propData in pedPropsSubElement:gmatch("<_(%d+)>([^<]+)</_") do
                local parts = {}
                for part in propData:gmatch("([^,]+)") do table.insert(parts, part) end
                outfitData.PedProperties.PedProps["_" .. propId] = {
                    prop_id = M.safe_tonumber(parts[1], -1),
                    texture_id = M.safe_tonumber(parts[2], 0)
                }
            end
        end
        local pedCompsElement = M.get_xml_element(pedPropsElement, "PedComps")
        if pedCompsElement then
            outfitData.PedProperties.PedComps = {}
            for compId, compData in pedCompsElement:gmatch("<_(%d+)>([^<]+)</_") do
                local parts = {}
                for part in compData:gmatch("([^,]+)") do table.insert(parts, part) end
                outfitData.PedProperties.PedComps["_" .. compId] = {
                    comp_id = M.safe_tonumber(parts[1], 0),
                    texture_id = M.safe_tonumber(parts[2], 0)
                }
            end
        end
    end
    return outfitData
end

function M.parse_task_sequence(taskSequenceXml, autoStartFlag)
    if not taskSequenceXml then return nil end
    local sequence = { tasks = {}, autoStart = autoStartFlag }
    for taskInner in taskSequenceXml:gmatch("<Task>(.-)</Task>") do
        local task = {}
        task.Type = M.safe_tonumber(M.get_xml_element_content(taskInner, "Type"), nil)
        if task.Type then
            task.Duration = M.safe_tonumber(M.get_xml_element_content(taskInner, "Duration"), 0)
            task.KeepTaskRunningAfterTime = M.safe_tonumber(M.get_xml_element_content(taskInner, "KeepTaskRunningAfterTime"), nil)
            task.IsLoopedTask = M.to_boolean(M.get_xml_element_content(taskInner, "IsLoopedTask"))
            task.Delay = M.safe_tonumber(M.get_xml_element_content(taskInner, "Delay"), 0)
            task.AssetName = M.get_xml_element_content(taskInner, "AssetName")
            task.EffectName = M.get_xml_element_content(taskInner, "EffectName")
            task.Scale = M.safe_tonumber(M.get_xml_element_content(taskInner, "Scale"), 1.0)
            local colourSnippet = parse_self_closing_tag(taskInner, "Colour")
            if colourSnippet then
                local colourAttrs = parse_attributes(colourSnippet)
                task.Colour = {
                    r = M.safe_tonumber(colourAttrs.R or colourAttrs.r, 255),
                    g = M.safe_tonumber(colourAttrs.G or colourAttrs.g, 255),
                    b = M.safe_tonumber(colourAttrs.B or colourAttrs.b, 255),
                    a = M.safe_tonumber(colourAttrs.A or colourAttrs.a, 255)
                }
            end
            task.RelativePosition = parse_vector_from_tag(taskInner, "RelativePosition")
            task.RelativeRotation = parse_vector_from_tag(taskInner, "RelativeRotation")
            table.insert(sequence.tasks, task)
        end
    end
    if #sequence.tasks == 0 then return nil end
    if sequence.autoStart == nil then sequence.autoStart = true end
    return sequence
end

local function normalize_colour_component(value, default)
    local component = M.safe_tonumber(value, default or 255) or (default or 255)
    if component < 0 then component = 0 end
    if component > 255 then component = 255 end
    return component / 255.0
end

local function ensure_ptfx_asset_loaded(assetName)
    if not assetName or assetName == "" then return false end
    if not STREAMING or not STREAMING.REQUEST_NAMED_PTFX_ASSET or not STREAMING.HAS_NAMED_PTFX_ASSET_LOADED then
        return false
    end
    STREAMING.REQUEST_NAMED_PTFX_ASSET(assetName)
    local waited = 0
    local maxWait = 2000
    while waited < maxWait do
        if STREAMING.HAS_NAMED_PTFX_ASSET_LOADED(assetName) then
            return true
        end
        Script.Yield(50)
        waited = waited + 50
    end
    return STREAMING.HAS_NAMED_PTFX_ASSET_LOADED(assetName)
end

function M.apply_task_sequence_to_entity(entityHandle, sequence)
    if not sequence or not entityHandle or entityHandle == 0 then return end
    if sequence.autoStart == false then
        return
    end
    if not sequence.tasks or #sequence.tasks == 0 then return end
    for _, task in ipairs(sequence.tasks) do
        M.execute_task_sequence_item(entityHandle, task)
    end
end

function M.execute_task_sequence_item(entityHandle, task)
    if not task or not task.Type then return end
    if task.Type == 39 then
        M.run_ptfx_task(entityHandle, task)
    else
    end
end

function M.run_ptfx_task(entityHandle, task)
    if not task or not (task.EffectName and task.AssetName) then return end
    if not GRAPHICS then return end
    
    Script.QueueJob(function()
        if task.Delay and task.Delay > 0 then Script.Yield(task.Delay) end
        
        if not ENTITY or not ENTITY.DOES_ENTITY_EXIST(entityHandle) then return end
        if not ensure_ptfx_asset_loaded(task.AssetName) then return end
        
        local pos = task.RelativePosition or { x = 0.0, y = 0.0, z = 0.0 }
        local rot = task.RelativeRotation or { x = 0.0, y = 0.0, z = 0.0 }
        local scale = task.Scale or 1.0
        
        -- Get color
        local r, g, b, a = 1.0, 1.0, 1.0, 1.0
        if task.Colour then
            r = normalize_colour_component(task.Colour.r, 255)
            g = normalize_colour_component(task.Colour.g, 255)
            b = normalize_colour_component(task.Colour.b, 255)
            a = normalize_colour_component(task.Colour.a, 255)
        end
        
        if GRAPHICS.USE_PARTICLE_FX_ASSET then
            GRAPHICS.USE_PARTICLE_FX_ASSET(task.AssetName)
        end
        
        local handle = nil
        if task.IsLoopedTask then
            -- Use looped particle FX
            local startFunc = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY or GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY
            if startFunc then
                pcall(function()
                    handle = startFunc(
                        task.EffectName, entityHandle,
                        pos.x or 0.0, pos.y or 0.0, pos.z or 0.0,
                        rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                        scale, false, false, false
                    )
                end)
            end
            
            if handle and handle ~= 0 then
                -- Apply color and scale
                pcall(function()
                    if GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR then
                        GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                    end
                    if GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA then
                        GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                    end
                    if GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE then
                        GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                    end
                end)
                
                -- Refresh loop - keep effect alive with 150ms interval
                Script.QueueJob(function()
                    while ENTITY and ENTITY.DOES_ENTITY_EXIST(entityHandle) do
                        Script.Yield(150)
                        if not ENTITY.DOES_ENTITY_EXIST(entityHandle) then break end
                        
                        -- Stop and restart the effect
                        if GRAPHICS.STOP_PARTICLE_FX_LOOPED then
                            pcall(function() GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false) end)
                        end
                        
                        if not ensure_ptfx_asset_loaded(task.AssetName) then break end
                        
                        if GRAPHICS.USE_PARTICLE_FX_ASSET then
                            GRAPHICS.USE_PARTICLE_FX_ASSET(task.AssetName)
                        end
                        
                        local newHandle = nil
                        if startFunc then
                            pcall(function()
                                newHandle = startFunc(
                                    task.EffectName, entityHandle,
                                    pos.x or 0.0, pos.y or 0.0, pos.z or 0.0,
                                    rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                                    scale, false, false, false
                                )
                            end)
                        end
                        
                        if newHandle and newHandle ~= 0 then
                            handle = newHandle
                            pcall(function()
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR then
                                    GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                                end
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA then
                                    GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                                end
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE then
                                    GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                                end
                            end)
                        else
                            break
                        end
                    end
                    
                    -- Cleanup
                    if GRAPHICS.STOP_PARTICLE_FX_LOOPED and handle then
                        pcall(function() GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false) end)
                    end
                end)
            end
        else
            -- Non-looped particle FX
            if task.Colour and GRAPHICS.SET_PARTICLE_FX_NON_LOOPED_COLOUR then
                pcall(function() GRAPHICS.SET_PARTICLE_FX_NON_LOOPED_COLOUR(r, g, b) end)
            end
            
            local startFunc = GRAPHICS.START_PARTICLE_FX_NON_LOOPED_ON_ENTITY or GRAPHICS.START_NETWORKED_PARTICLE_FX_NON_LOOPED_ON_ENTITY
            if startFunc then
                pcall(function()
                    startFunc(
                        task.EffectName, entityHandle,
                        pos.x or 0.0, pos.y or 0.0, pos.z or 0.0,
                        rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                        scale, false, false, false
                    )
                end)
            end
        end
    end)
end

function M.parse_ini_file(filePath)
    local iniContent = FileMgr.ReadFileContent(filePath)
    if not iniContent then return nil end
    
    -- Strip BOM (Byte Order Mark) if present
    -- UTF-8 BOM is the byte sequence EF BB BF (or the character U+FEFF)
    if iniContent:sub(1, 3) == "\239\187\191" then
        iniContent = iniContent:sub(4)
    end
    
    local data = {}
    local currentSection = nil
    for line in iniContent:gmatch("[^\r\n]+") do
        line = M.trim(line)
        if line:match("^%[.+%]$") then
            currentSection = line:match("^%[(.+)%]$")
            data[currentSection] = data[currentSection] or {}
        elseif line:match("^[^;=]+=[^;]*$") and currentSection then
            local key, value = line:match("^([^;=]+)=([^;]*)$")
            if key and value then
                local trimmedKey = M.trim(key)
                local trimmedValue = M.trim(value):match("^(.-)%s*;.*$") or M.trim(value)
                data[currentSection][trimmedKey] = trimmedValue
            end
        end
    end
    return data
end

function M.request_model_load(hashOrName)
    if not hashOrName then return end
    local model = M.safe_tonumber(hashOrName, nil) or hashOrName
    if STREAMING and STREAMING.REQUEST_MODEL and model then
        pcall(function() STREAMING.REQUEST_MODEL(model) end)
    end
end

function M.apply_ped_properties(pedHandle, pedProperties)
    if not pedHandle or pedHandle == 0 or not pedProperties then return end
    if pedProperties.IsStill ~= nil then
        pcall(function() PED.SET_PED_ENABLE_WEAPON_BLOCKING(pedHandle, M.to_boolean(pedProperties.IsStill)) end)
    end
    if pedProperties.CanRagdoll ~= nil then
        local canRagdoll = M.to_boolean(pedProperties.CanRagdoll)
        pcall(function() PED.SET_PED_CAN_RAGDOLL(pedHandle, canRagdoll) end)
    end
    if pedProperties.HasShortHeight ~= nil then
        pcall(function() PED.SET_PED_CONFIG_FLAG(pedHandle, 223, M.to_boolean(pedProperties.HasShortHeight)) end)
    end
    if pedProperties.Armour ~= nil then
        local armour = M.safe_tonumber(pedProperties.Armour, 0)
        pcall(function() PED.SET_PED_ARMOUR(pedHandle, armour) end)
    end
    if pedProperties.CurrentWeapon ~= nil then
        local weaponHash = M.safe_tonumber(pedProperties.CurrentWeapon, nil)
        if weaponHash and weaponHash ~= 0 then
            pcall(function()
                WEAPON.GIVE_WEAPON_TO_PED(pedHandle, weaponHash, 9999, true, true)
            end)
        end
    end
    if pedProperties.PedProps then
        for propKey, propData in pairs(pedProperties.PedProps) do
            local propId
            if type(propKey) == "number" then
                propId = propKey
            else
                propId = M.safe_tonumber(propKey:gsub("^_", ""), nil)
            end
            if propId ~= nil then
                if propData.prop_id ~= -1 then
                    pcall(function()
                        PED.SET_PED_PROP_INDEX(pedHandle, propId, propData.prop_id, propData.texture_id, true)
                    end)
                else
                    pcall(function()
                        PED.CLEAR_PED_PROP(pedHandle, propId)
                    end)
                end
            end
        end
    end
    if pedProperties.PedComps then
        for compKey, compData in pairs(pedProperties.PedComps) do
            local compId
            if type(compKey) == "number" then
                compId = compKey
            else
                compId = M.safe_tonumber(compKey:gsub("^_", ""), nil)
            end
            if compId ~= nil then
                pcall(function()
                    PED.SET_PED_COMPONENT_VARIATION(pedHandle, compId, compData.comp_id, compData.texture_id, 0)
                end)
            end
        end
    end
    if pedProperties.RelationshipGroup ~= nil then
        local relGroup = M.safe_tonumber(pedProperties.RelationshipGroup, nil)
        if relGroup then
            pcall(function() PED.SET_PED_RELATIONSHIP_GROUP_HASH(pedHandle, relGroup) end)
        end
    end
    if pedProperties.AnimActive == "true" and pedProperties.AnimDict and pedProperties.AnimName then
        local animDict = pedProperties.AnimDict
        local animName = pedProperties.AnimName
        pcall(function()
            STREAMING.REQUEST_ANIM_DICT(animDict)
            local t0 = Time.GetEpoche()
            while not STREAMING.HAS_ANIM_DICT_LOADED(animDict) and Time.GetEpoche() - t0 < 2 do
                Script.Yield(10)
            end
            if STREAMING.HAS_ANIM_DICT_LOADED(animDict) then
                TASK.TASK_PLAY_ANIM(pedHandle, animDict, animName, 8.0, 8.0, -1, 1, 1.0, false, false, false)
                PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(pedHandle, true)
            end
        end)
    end
end

function M.parse_ini_attachments(iniData, mainVehicleSelfNumeration)
    local attachments = {}
    for sectionName, attachmentSection in pairs(iniData) do
        if M.safe_tonumber(sectionName) ~= nil or sectionName:match("^Attached Object %d+$") or sectionName:match("^Vehicle%d+$") or sectionName:match("^Object%d+$") then
            if sectionName == "Vehicle0" or sectionName == "Object0" then goto continue end
            local att = {}
            att.ModelHash = M.safe_tonumber(attachmentSection.Hash or attachmentSection.model or attachmentSection.Model, nil)
            att.HashName = attachmentSection["model name"] or attachmentSection["Model Name"] or attachmentSection.model or attachmentSection.Model or attachmentSection.Hash
            att.Type = "3"
            att.InitialHandle = M.safe_tonumber(attachmentSection.SelfNumeration, nil)
            att.PositionRotation = {
                X = M.safe_tonumber(attachmentSection.OffsetX or attachmentSection["x offset"] or attachmentSection.X or attachmentSection.x, 0.0),
                Y = M.safe_tonumber(attachmentSection.OffsetY or attachmentSection["y offset"] or attachmentSection.Y or attachmentSection.y, 0.0),
                Z = M.safe_tonumber(attachmentSection.OffsetZ or attachmentSection["z offset"] or attachmentSection.Z or attachmentSection.z, 0.0),
                Pitch = M.safe_tonumber(attachmentSection.Pitch or attachmentSection.pitch or attachmentSection.RotX or attachmentSection.rotX, 0.0),
                Roll = M.safe_tonumber(attachmentSection.Roll or attachmentSection.roll or attachmentSection.RotY or attachmentSection.rotY, 0.0),
                Yaw = M.safe_tonumber(attachmentSection.Yaw or attachmentSection.yaw or attachmentSection.RotZ or attachmentSection.rotZ, 0.0)
            }
            local attachedToWhat = attachmentSection.AttachedToWhat or attachmentSection.AttachedToWhat
            local attachNumeration = M.safe_tonumber(attachmentSection.AttachNumeration, nil)
            att.Attachment = {
                isAttached = true,
                AttachedTo = "main_vehicle_placeholder",
                BoneIndex = M.safe_tonumber(attachmentSection.Bone or attachmentSection.bone, -1),
                X = att.PositionRotation.X,
                Y = att.PositionRotation.Y,
                Z = att.PositionRotation.Z,
                Pitch = att.PositionRotation.Pitch,
                Roll = att.PositionRotation.Roll,
                Yaw = att.PositionRotation.Yaw
            }
            if attachedToWhat == "Vehicle" and mainVehicleSelfNumeration then
                att.Attachment.AttachedTo = mainVehicleSelfNumeration
                M.debug_print("[Parse INI Debug] Attachment", sectionName, "attached to main vehicle (SelfNumeration:", tostring(mainVehicleSelfNumeration), ")")
            elseif attachNumeration then
                att.Attachment.AttachedTo = attachNumeration
                M.debug_print("[Parse INI Debug] Attachment", sectionName, "attached to object with AttachNumeration:", tostring(attachNumeration))
            else
                M.debug_print("[Parse INI Debug] Warning: Attachment", sectionName, "has no clear parent. Defaulting to main vehicle placeholder.")
                att.Attachment.AttachedTo = "main_vehicle_placeholder"
            end
            att.IsCollisionProof = M.to_boolean(attachmentSection.collision or attachmentSection.Collision)
            att.FrozenPos = M.to_boolean(attachmentSection.froozen or attachmentSection.frozen or attachmentSection.Froozen or attachmentSection.Frozen)
            
            -- Parse vehicle-specific properties if this is a vehicle attachment
            if sectionName:match("^Vehicle%d+$") then
                att.Type = "2" -- Vehicle type
                
                -- Parse vehicle mods
                local modsSection = iniData[sectionName .. "Mods"]
                if modsSection then
                    att.VehicleMods = {}
                    for key, value in pairs(modsSection) do
                        if key:match("^M%d+$") then
                            local modId = M.safe_tonumber(key:sub(2), nil)
                            local modValue = M.safe_tonumber(value, -1)
                            if modId and modValue >= -1 then
                                att.VehicleMods[modId] = modValue
                            end
                        end
                    end
                end
                
                -- Parse vehicle toggles
                local togglesSection = iniData[sectionName .. "Toggles"]
                if togglesSection then
                    att.VehicleToggles = {}
                    for key, value in pairs(togglesSection) do
                        if key:match("^T%d+$") then
                            local toggleId = M.safe_tonumber(key:sub(2), nil)
                            if toggleId then
                                att.VehicleToggles[toggleId] = M.to_boolean(value)
                            end
                        end
                    end
                end
                
                -- Parse vehicle extras
                local extrasSection = iniData[sectionName .. "Extras"]
                if extrasSection then
                    att.VehicleExtras = {}
                    for key, value in pairs(extrasSection) do
                        if key:match("^E%d+$") then
                            local extraId = M.safe_tonumber(key:sub(2), nil)
                            if extraId then
                                att.VehicleExtras[extraId] = M.to_boolean(value)
                            end
                        end
                    end
                end
                
                -- Parse vehicle colors
                local colorsSection = iniData[sectionName .. "VehicleColors"]
                if colorsSection then
                    att.VehicleColors = {
                        Primary = M.safe_tonumber(colorsSection.Primary, nil),
                        Secondary = M.safe_tonumber(colorsSection.Secondary, nil)
                    }
                end
                
                -- Parse extra colors (pearlescent, wheel)
                local extraColorsSection = iniData[sectionName .. "ExtraColors"]
                if extraColorsSection then
                    att.ExtraColors = {
                        Pearl = M.safe_tonumber(extraColorsSection.Pearl, nil),
                        Wheel = M.safe_tonumber(extraColorsSection.Wheel, nil)
                    }
                end
                
                -- Parse custom primary color
                local customPrimarySection = iniData[sectionName .. "CustomPrimaryColor"]
                if customPrimarySection then
                    att.CustomPrimaryColor = {
                        R = M.safe_tonumber(customPrimarySection.R, 0),
                        G = M.safe_tonumber(customPrimarySection.G, 0),
                        B = M.safe_tonumber(customPrimarySection.B, 0)
                    }
                end
                
                -- Parse custom secondary color
                local customSecondarySection = iniData[sectionName .. "CustomSecondaryColor"]
                if customSecondarySection then
                    att.CustomSecondaryColor = {
                        R = M.safe_tonumber(customSecondarySection.R, 0),
                        G = M.safe_tonumber(customSecondarySection.G, 0),
                        B = M.safe_tonumber(customSecondarySection.B, 0)
                    }
                end
                
                -- Parse neon settings
                local neonSection = iniData[sectionName .. "Neon"]
                if neonSection then
                    att.Neons = {
                        Enabled0 = M.to_boolean(neonSection.Enabled0),
                        Enabled1 = M.to_boolean(neonSection.Enabled1),
                        Enabled2 = M.to_boolean(neonSection.Enabled2),
                        Enabled3 = M.to_boolean(neonSection.Enabled3)
                    }
                end
                
                -- Parse neon color
                local neonColorSection = iniData[sectionName .. "NeonColor"]
                if neonColorSection then
                    att.NeonColor = {
                        R = M.safe_tonumber(neonColorSection.R, 255),
                        G = M.safe_tonumber(neonColorSection.G, 255),
                        B = M.safe_tonumber(neonColorSection.B, 255)
                    }
                end
                
                -- Parse tire smoke color
                local tireSmokeSection = iniData[sectionName .. "TireSmoke"]
                if tireSmokeSection then
                    att.TireSmoke = {
                        R = M.safe_tonumber(tireSmokeSection.R, 255),
                        G = M.safe_tonumber(tireSmokeSection.G, 255),
                        B = M.safe_tonumber(tireSmokeSection.B, 255)
                    }
                end
                
                -- Parse wheel type
                local wheelTypeSection = iniData[sectionName .. "WheelType"]
                if wheelTypeSection then
                    att.WheelType = M.safe_tonumber(wheelTypeSection.Index, nil)
                end
                
                -- Parse numberplate
                local numberplateSection = iniData[sectionName .. "Numberplate"]
                if numberplateSection then
                    att.Numberplate = {
                        Text = numberplateSection.Text,
                        Index = M.safe_tonumber(numberplateSection.Index, 0)
                    }
                end
                
                -- Parse window tint
                local windowTintSection = iniData[sectionName .. "WindowTint"]
                if windowTintSection then
                    att.WindowTint = M.safe_tonumber(windowTintSection.Index, nil)
                end
                
                -- Parse paint fade
                local paintFadeSection = iniData[sectionName .. "PaintFade"]
                if paintFadeSection then
                    att.PaintFade = M.safe_tonumber(paintFadeSection.PaintFade, nil)
                end
                
                -- Parse custom primary/secondary flags
                local isCustomPrimarySection = iniData[sectionName .. "IsCustomPrimary"]
                if isCustomPrimarySection then
                    att.IsCustomPrimary = M.to_boolean(isCustomPrimarySection.bool)
                end
                
                local isCustomSecondarySection = iniData[sectionName .. "IsCustomSecondary"]
                if isCustomSecondarySection then
                    att.IsCustomSecondary = M.to_boolean(isCustomSecondarySection.bool)
                end
            end
            
            table.insert(attachments, att)
        end
        ::continue::
    end
    return attachments
end

function M.parse_spooner_attachments(xml)
    local out = {}
    local defaultTaskAutoStart = nil
    local spoonerAttributes = xml:match("<SpoonerAttachments([^>]*)>")
    if spoonerAttributes then
        local attrs = parse_attributes(spoonerAttributes)
        if attrs and attrs.StartTaskSequencesOnLoad ~= nil then
            defaultTaskAutoStart = M.to_boolean(attrs.StartTaskSequencesOnLoad)
        end
    end
    local s = M.get_xml_element(xml, "SpoonerAttachments")
    if not s then return out end
    local searchPos = 1
    while true do
        local openStart = s:find("<Attachment[^>]*>", searchPos)
        if not openStart then break end
        local closePos = nil
        local depth = 1
        local pos = openStart + 1
        while depth > 0 and pos <= #s do
            local nextOpen = s:find("<Attachment[^>]*>", pos)
            local nextClose = s:find("</Attachment>", pos)
            if not nextClose then break end
            if nextOpen and nextOpen < nextClose then
                depth = depth + 1
                pos = nextOpen + 1
            else
                depth = depth - 1
                if depth == 0 then
                    closePos = nextClose + #"</Attachment>" - 1
                    break
                end
                pos = nextClose + 1
            end
        end
        if closePos then
            local attInner = s:sub(openStart, closePos)
            local content = attInner:match("<Attachment[^>]*>(.*)</Attachment>")
            if content then
                local e = {}
                e.ModelHash = M.get_xml_element_content(attInner, "ModelHash")
                e.Type = M.get_xml_element_content(attInner, "Type")
                e.Dynamic = M.to_boolean(M.get_xml_element_content(attInner, "Dynamic"))
                e.FrozenPos = M.to_boolean(M.get_xml_element_content(attInner, "FrozenPos"))
                e.HashName = M.get_xml_element_content(attInner, "HashName")
                e.InitialHandle = M.safe_tonumber(M.get_xml_element_content(attInner, "InitialHandle"), nil)
                e.OpacityLevel = M.get_xml_element_content(attInner, "OpacityLevel")
                e.HasGravity = M.to_boolean(M.get_xml_element_content(attInner, "HasGravity"))
                local objProps = M.get_xml_element(attInner, "ObjectProperties")
                if objProps then
                    e.ObjectProperties = {}
                    for name, val in objProps:gmatch("<([%w_]+)>(.-)</%1>") do e.ObjectProperties[name] = val end
                end
                local pedProps = M.get_xml_element(attInner, "PedProperties")
                if pedProps then
                    e.PedProperties = {}
                    for name, val in pedProps:gmatch("<([%w_]+)>(.-)</%1>") do e.PedProperties[name] = val end
                    local propsSection = M.get_xml_element(pedProps, "PedProps")
                    if propsSection then
                        e.PedProperties.PedProps = {}
                        for name, val in propsSection:gmatch("<_(%d+)>([^<]+)</_%1>") do
                            local id = M.safe_tonumber(name)
                            if id then
                                local parts = M.split_str(val, ",")
                                e.PedProperties.PedProps[id] = {
                                    prop_id = M.safe_tonumber(parts[1], -1),
                                    texture_id = M.safe_tonumber(parts[2], -1)
                                }
                            end
                        end
                    end
                    local compsSection = M.get_xml_element(pedProps, "PedComps")
                    if compsSection then
                        e.PedProperties.PedComps = {}
                        for name, val in compsSection:gmatch("<_(%d+)>([^<]+)</_%1>") do
                            local id = M.safe_tonumber(name)
                            if id then
                                local parts = M.split_str(val, ",")
                                e.PedProperties.PedComps[id] = {
                                    comp_id = M.safe_tonumber(parts[1], 0),
                                    texture_id = M.safe_tonumber(parts[2], 0)
                                }
                            end
                        end
                    end
                end
                
                -- Parse VehicleProperties for attachments
                local vehProps = M.get_xml_element(attInner, "VehicleProperties")
                if vehProps then
                    e.VehicleProperties = {}
                    -- Parse colors using the helper
                    e.VehicleProperties.Colours = M.parse_vehicle_colors(attInner)
                    -- Parse mods using the helper
                    e.VehicleProperties.Mods = M.parse_vehicle_mods(attInner)
                    -- Parse other vehicle properties as needed (e.g. Livery, Plate)
                    e.VehicleProperties.Livery = M.safe_tonumber(M.get_xml_element_content(vehProps, "Livery"), nil)
                    e.VehicleProperties.NumberPlateText = M.get_xml_element_content(vehProps, "NumberPlateText")
                    e.VehicleProperties.NumberPlateIndex = M.safe_tonumber(M.get_xml_element_content(vehProps, "NumberPlateIndex"), nil)
                    e.VehicleProperties.WheelType = M.safe_tonumber(M.get_xml_element_content(vehProps, "WheelType"), nil)
                    e.VehicleProperties.WindowTint = M.safe_tonumber(M.get_xml_element_content(vehProps, "WindowTint"), nil)
                    e.VehicleProperties.DirtLevel = M.safe_tonumber(M.get_xml_element_content(vehProps, "DirtLevel"), nil)
                    e.VehicleProperties.EngineOn = M.to_boolean(M.get_xml_element_content(vehProps, "EngineOn"))
                    
                    local bulletProofTyres = M.get_xml_element_content(vehProps, "BulletProofTyres")
                    if bulletProofTyres ~= nil then
                        e.VehicleProperties.BulletProofTyres = M.to_boolean(bulletProofTyres)
                    end
                    
                    -- Neons
                    e.VehicleProperties.Neons = M.parse_vehicle_neons(attInner)
                end
                local posRot = M.get_xml_element(attInner, "PositionRotation")
                if posRot then
                    e.PositionRotation = {}
                    for name, val in posRot:gmatch("<([%w_]+)>(.-)</%1>") do e.PositionRotation[name] = M.safe_tonumber(val, 0.0) end
                end
                local nested = nil
                local lastAttachStart = nil
                local searchPos = 1
                while true do
                    local found = attInner:find("<Attachment[^>]*>", searchPos)
                    if not found then break end
                    lastAttachStart = found
                    searchPos = found + 1
                end
                if lastAttachStart then
                    local afterTag = attInner:match("<Attachment[^>]*>(.*)", lastAttachStart)
                    if afterTag then
                        local closePos = afterTag:find("</Attachment>")
                        if closePos then
                            nested = afterTag:sub(1, closePos - 1)
                        end
                    end
                end
                if nested then
                    e.Attachment = {}
                    e.Attachment.AttachedTo = M.get_xml_element_content(nested, "AttachedTo")
                    e.Attachment.BoneIndex = M.safe_tonumber(M.get_xml_element_content(nested, "BoneIndex"), 0)
                    e.Attachment.X = M.get_xml_element_content(nested, "X")
                    e.Attachment.Y = M.get_xml_element_content(nested, "Y")
                    e.Attachment.Z = M.get_xml_element_content(nested, "Z")
                    e.Attachment.Pitch = M.get_xml_element_content(nested, "Pitch")
                    e.Attachment.Roll = M.get_xml_element_content(nested, "Roll")
                    e.Attachment.Yaw = M.get_xml_element_content(nested, "Yaw")
                    e.AttachmentRaw = nested
                end
                if e.Attachment and e.Attachment.AttachedTo then
                    local atn = M.safe_tonumber(e.Attachment.AttachedTo, nil)
                    if atn ~= nil then e.Attachment.AttachedTo = atn end
                end
-- Capture all boolean-like tags
for name, val in attInner:gmatch("<([%w_]+)>(.-)</%1>") do
    if name:match("^Is") then
        e[name] = M.to_boolean(val)
    end
end

-- Explicitly read IsCollisionProof (some XMLs put it outside boolean group)
local colProofTag = M.get_xml_element_content(attInner, "IsCollisionProof")
if colProofTag ~= nil then
    e.IsCollisionProof = M.to_boolean(colProofTag)
else
    -- Try fallback search anywhere in XML just in case
    local anyProof = attInner:match("<IsCollisionProof>([^<]+)</IsCollisionProof>")
    if anyProof then
        e.IsCollisionProof = M.to_boolean(anyProof)
    else
        e.IsCollisionProof = false
    end
end

-- Debug to verify

                local taskSequenceXml = M.get_xml_element(attInner, "TaskSequence")
                if taskSequenceXml then
                    e.TaskSequence = M.parse_task_sequence(taskSequenceXml, defaultTaskAutoStart)
                end

                if e.ModelHash then
                    local mh = M.safe_tonumber(e.ModelHash, nil)
                    if mh ~= nil then e.ModelHash = mh end
                end
                out[#out + 1] = e
            end
        end
        searchPos = closePos and (closePos + 1) or (openStart + 1)
    end
    return out
end

function M.create_by_type(model, typ, coords)
    local mnum = M.safe_tonumber(model, model)
    M.request_model_load(mnum)
    if typ == "1" or typ == 1 then
        local ok, h = pcall(function() return GTA.CreatePed(mnum, 26, coords.x, coords.y, coords.z, 0, true, true) end)
        if ok and h and h ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF) end)
            return h
        end
        ok, h = pcall(function() return GTA.CreateRandomPed(coords.x, coords.y, coords.z) end)
        if ok and h and h ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF) end)
            return h
        end
        return 0
    end
    if typ == "2" or typ == 2 then
        local ok, h = pcall(function() return GTA.SpawnVehicle(mnum, coords.x, coords.y, coords.z, 0, true, true) end)
        if ok and h and h ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF) end)
            return h
        end
        return 0
    end
    if typ == "3" or typ == 3 then
        local ok, h = pcall(function() return GTA.CreateObject(mnum, coords.x, coords.y, coords.z, true, true) end)
        if ok and h and h ~= 0 then
            pcall(function() if ENTITY and ENTITY.SET_ENTITY_COORDS then ENTITY.SET_ENTITY_COORDS(h, coords.x, coords.y, coords.z, false, false, false, true) end end)
            pcall(function() ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF) end)
            return h
        end
        ok, h = pcall(function() return GTA.CreateWorldObject(mnum, coords.x, coords.y, coords.z, true, true) end)
        if ok and h and h ~= 0 then
            pcall(function() if ENTITY and ENTITY.SET_ENTITY_COORDS then ENTITY.SET_ENTITY_COORDS(h, coords.x, coords.y, coords.z, false, false, false, true) end end)
            pcall(function() ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF) end)
            return h
        end
        ok, h = pcall(function() return GTA.SpawnVehicle(mnum, coords.x, coords.y, coords.z, 0, true, true) end)
        if ok and h and h ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF) end)
            return h
        end
        return 0
    end
    return 0
end

function M.spawn_attachments(parsedAttachments, parentHandleMap, fallbackCoords, disableCollisionForAttachments, isPreview)
    local created = {}
    local attachMeta = {}
    local playerPed = nil
    local playerPos = nil
    local playerHeading = 0.0
    pcall(function()
        playerPed = GTA.GetLocalPed()
    end)
    for i, att in ipairs(parsedAttachments) do
        local model = att.ModelHash or att.HashName
        local attachmentName = att.HashName or tostring(model) or "Unknown"
        if not model then
            M.debug_print("[Spawn] Warning: Attachment #" .. i .. " has no model hash or name. Skipping.")
            goto continue
        end
        local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
        if att.PositionRotation and (att.PositionRotation.X or att.PositionRotation.Y or att.PositionRotation.Z) then
            spawnCoords.x = att.PositionRotation.X or 0.0
            spawnCoords.y = att.PositionRotation.Y or 0.0
            spawnCoords.z = att.PositionRotation.Z or 0.0
        elseif fallbackCoords and fallbackCoords.x and fallbackCoords.y and fallbackCoords.z then
            spawnCoords.x = fallbackCoords.x
            spawnCoords.y = fallbackCoords.y
            spawnCoords.z = fallbackCoords.z
        elseif playerPos then
            local forwardX = math.sin(math.rad(playerHeading)) * 1.5
            local forwardY = math.cos(math.rad(playerHeading)) * 1.5
            spawnCoords.x = playerPos.x + forwardX
            spawnCoords.y = playerPos.y + forwardY
            spawnCoords.z = playerPos.z + 0.5
        else
            spawnCoords.x = 0.0; spawnCoords.y = 0.0; spawnCoords.z = 0.0
        end
        M.request_model_load(model)
        if STREAMING and STREAMING.HAS_MODEL_LOADED then
            local t0 = Time.GetEpoche()
            while not pcall(function() return STREAMING.HAS_MODEL_LOADED(M.safe_tonumber(model, model) or model) end) and Time.GetEpoche() - t0 < 0.3 do
                Script.Yield(10)
            end
            if not pcall(function() return STREAMING.HAS_MODEL_LOADED(M.safe_tonumber(model, model) or model) end) then
                Logger.LogError("[Spawn] Model failed to load: '" .. attachmentName .. "' (hash: " .. tostring(model) .. ")")
            end
        else
            Script.Yield(30)
        end
        local h = M.create_by_type(model, att.Type, spawnCoords)
        if not h or h == 0 then
            pcall(function() GUI.AddToast("Spawn Error", "Failed to spawn " .. (att.HashName or tostring(att.ModelHash)), 5000, 0) end)
            Logger.LogError("[Spawn] Failed to create '" .. attachmentName .. "' (model: " .. tostring(model) .. ")")
            goto continue
        end
        local typeNames = {["1"] = "Ped", ["2"] = "Vehicle", ["3"] = "Object", [1] = "Ped", [2] = "Vehicle", [3] = "Object"}
        local typeName = typeNames[att.Type] or tostring(att.Type)
        M.debug_print("[Spawn] Created '" .. attachmentName .. "' [" .. typeName .. "] (handle: " .. tostring(h) .. ")")
        table.insert(created, h)
        if att.InitialHandle then
            local ihNum = M.safe_tonumber(att.InitialHandle, nil)
            local ihStr = tostring(att.InitialHandle)
            if ihNum ~= nil then parentHandleMap[ihNum] = h end
            parentHandleMap[ihStr] = h
        end
        
        -- Calculate collision proof BEFORE the isPreview check so it's in scope for meta table
        local finalCollisionProof = false
        if att.IsCollisionProof ~= nil then
            local val = tostring(att.IsCollisionProof):lower()
            finalCollisionProof = (val == "true" or val == "1")
        end
        
        if isPreview then
            pcall(function() ENTITY.SET_ENTITY_COLLISION(h, false, false) end)
        else
            if finalCollisionProof then
                -- Use multiple methods to ensure collision is disabled
                
                -- Method 1: SET_ENTITY_COLLISION
                pcall(function()
                    ENTITY.SET_ENTITY_COLLISION(h, false, false)
                end)
                
                -- Method 2: SET_ENTITY_COMPLETELY_DISABLE_COLLISION (more aggressive)
                pcall(function()
                    if ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION then
                        ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(h, false, true)
                    end
                end)
                
                -- Method 3: For peds, disable collision with player's vehicle
                if tostring(att.Type) == "1" then
                    pcall(function()
                        local playerPed = PLAYER.PLAYER_PED_ID()
                        if playerPed and playerPed ~= 0 then
                            local playerVehicle = PED.GET_VEHICLE_PED_IS_IN(playerPed, false)
                            if playerVehicle and playerVehicle ~= 0 then
                                ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(h, playerVehicle, true)
                            end
                        end
                    end)
                    
                    -- Also disable ragdoll for peds to prevent physics issues
                    pcall(function()
                        if PED.SET_PED_CAN_RAGDOLL then
                            PED.SET_PED_CAN_RAGDOLL(h, false)
                        end
                    end)
                end
                
                -- Method 4: SET_ENTITY_PROOFS with collision proof
                pcall(function()
                    ENTITY.SET_ENTITY_PROOFS(h, false, false, false, true, false, false, false, false)
                end)
            end
        end

        if att.OpacityLevel ~= nil then
            local opacityLevel = M.safe_tonumber(att.OpacityLevel, nil)
            if opacityLevel ~= nil and opacityLevel == 0 then
                pcall(function() ENTITY.SET_ENTITY_ALPHA(h, 0, false) end)
            end
        end
        if att.PedProperties and (tostring(att.Type) == "1") then
            M.apply_ped_properties(h, att.PedProperties)
        end
        if att.VehicleProperties and (tostring(att.Type) == "2") then
            local vp = att.VehicleProperties
            local colors = vp.Colours
            if colors then
                if colors.Primary ~= nil or colors.Secondary ~= nil then
                    M.try_call(VEHICLE, "SET_VEHICLE_COLOURS", h, colors.Primary or 0, colors.Secondary or 0)
                end
                
                if colors.IsPrimaryColourCustom then
                    M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", h, colors.Cust1_R, colors.Cust1_G, colors.Cust1_B)
                end

                if colors.IsSecondaryColourCustom then
                    M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", h, colors.Cust2_R, colors.Cust2_G, colors.Cust2_B)
                end

                if colors.Pearl ~= nil or colors.Rim ~= nil then
                    M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOURS", h, colors.Pearl or 0, colors.Rim or 0)
                end
                if colors.tyreSmoke_R and colors.tyreSmoke_G and colors.tyreSmoke_B then
                    M.try_call(VEHICLE, "SET_VEHICLE_TYRE_SMOKE_COLOR", h, colors.tyreSmoke_R, colors.tyreSmoke_G, colors.tyreSmoke_B)
                end
                if colors.LrInterior and colors.LrInterior > 0 then M.try_call(VEHICLE, "_SET_VEHICLE_INTERIOR_COLOR", h, colors.LrInterior) end
                if colors.LrDashboard and colors.LrDashboard > 0 then M.try_call(VEHICLE, "_SET_VEHICLE_DASHBOARD_COLOR", h, colors.LrDashboard) end
            end
            
            if vp.Mods then
                M.try_call(VEHICLE, "SET_VEHICLE_MOD_KIT", h, 0)
                for modId, modData in pairs(vp.Mods) do
                    if modData and modData.mod and modData.mod >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_MOD", h, modId, modData.mod, false) end
                end
            end
            
            if vp.Livery and vp.Livery >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_LIVERY", h, vp.Livery) end
            if vp.NumberPlateText then M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT", h, vp.NumberPlateText) end
            if vp.NumberPlateIndex then M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX", h, vp.NumberPlateIndex) end
            if vp.WheelType then M.try_call(VEHICLE, "SET_VEHICLE_WHEEL_TYPE", h, vp.WheelType) end
            if vp.WindowTint and vp.WindowTint >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_WINDOW_TINT", h, vp.WindowTint) end
            if vp.DirtLevel then M.try_call(VEHICLE, "SET_VEHICLE_DIRT_LEVEL", h, vp.DirtLevel) end
            if vp.BulletProofTyres ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_TYRES_CAN_BURST", h, not vp.BulletProofTyres) end
            if vp.EngineOn ~= nil and spawnerSettings.vehicleEngineOn and vp.EngineOn then M.try_call(VEHICLE, "SET_VEHICLE_ENGINE_ON", h, true, true, false) end
            
            if vp.Neons then
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 0, vp.Neons.Left or false)
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 1, vp.Neons.Right or false)
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 2, vp.Neons.Front or false)
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 3, vp.Neons.Back or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 0, vp.Neons.Left or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 1, vp.Neons.Right or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 2, vp.Neons.Front or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 3, vp.Neons.Back or false)
                if vp.Neons.R and vp.Neons.G and vp.Neons.B then
                    M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHTS_COLOUR", h, vp.Neons.R, vp.Neons.G, vp.Neons.B)
                end
            end
            
        end
        
        -- Apply INI vehicle properties if this is a vehicle attachment from INI
        if att.VehicleMods or att.VehicleToggles or att.VehicleColors or att.Neons then
            
            -- Set mod kit first
            M.try_call(VEHICLE, "SET_VEHICLE_MOD_KIT", h, 0)
            
            -- Apply vehicle mods
            if att.VehicleMods then
                for modId, modValue in pairs(att.VehicleMods) do
                    if modValue >= -1 then
                        M.try_call(VEHICLE, "SET_VEHICLE_MOD", h, modId, modValue, false)
                    end
                end
            end
            
            -- Apply vehicle toggles
            if att.VehicleToggles then
                for toggleId, toggleValue in pairs(att.VehicleToggles) do
                    M.try_call(VEHICLE, "SET_VEHICLE_TOGGLE_MOD", h, toggleId, toggleValue)
                end
            end
            
            -- Apply vehicle extras
            if att.VehicleExtras then
                for extraId, extraEnabled in pairs(att.VehicleExtras) do
                    M.try_call(VEHICLE, "SET_VEHICLE_EXTRA", h, extraId, not extraEnabled)
                end
            end
            
            -- Apply standard vehicle colors
            if att.VehicleColors then
                if att.VehicleColors.Primary or att.VehicleColors.Secondary then
                    M.try_call(VEHICLE, "SET_VEHICLE_COLOURS", h, att.VehicleColors.Primary or 0, att.VehicleColors.Secondary or 0)
                end
            end
            
            -- Apply custom colors
            if att.IsCustomPrimary and att.CustomPrimaryColor then
                M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", h, 
                    att.CustomPrimaryColor.R, att.CustomPrimaryColor.G, att.CustomPrimaryColor.B)
            end
            
            if att.IsCustomSecondary and att.CustomSecondaryColor then
                M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", h, 
                    att.CustomSecondaryColor.R, att.CustomSecondaryColor.G, att.CustomSecondaryColor.B)
            end
            
            -- Apply extra colors (pearlescent, wheel)
            if att.ExtraColors then
                if att.ExtraColors.Pearl or att.ExtraColors.Wheel then
                    M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOURS", h, 
                        att.ExtraColors.Pearl or 0, att.ExtraColors.Wheel or 0)
                end
            end
            
            -- Apply neon lights
            if att.Neons then
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 0, att.Neons.Enabled0 or false)
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 1, att.Neons.Enabled1 or false)
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 2, att.Neons.Enabled2 or false)
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", h, 3, att.Neons.Enabled3 or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 0, att.Neons.Enabled0 or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 1, att.Neons.Enabled1 or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 2, att.Neons.Enabled2 or false)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", h, 3, att.Neons.Enabled3 or false)
            end
            
            -- Apply neon color
            if att.NeonColor then
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHTS_COLOUR", h, 
                    att.NeonColor.R, att.NeonColor.G, att.NeonColor.B)
            end
            
            -- Apply tire smoke color
            if att.TireSmoke then
                M.try_call(VEHICLE, "SET_VEHICLE_TYRE_SMOKE_COLOR", h, 
                    att.TireSmoke.R, att.TireSmoke.G, att.TireSmoke.B)
            end
            
            -- Apply wheel type
            if att.WheelType then
                M.try_call(VEHICLE, "SET_VEHICLE_WHEEL_TYPE", h, att.WheelType)
            end
            
            -- Apply numberplate
            if att.Numberplate then
                if att.Numberplate.Text then
                    M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT", h, att.Numberplate.Text)
                end
                if att.Numberplate.Index then
                    M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX", h, att.Numberplate.Index)
                end
            end
            
            -- Apply window tint
            if att.WindowTint and att.WindowTint >= 0 then
                M.try_call(VEHICLE, "SET_VEHICLE_WINDOW_TINT", h, att.WindowTint)
            end
            
            -- Apply paint fade (dirt level)
            if att.PaintFade then
                M.try_call(VEHICLE, "SET_VEHICLE_DIRT_LEVEL", h, att.PaintFade)
            end
            
        end
        if att.TaskSequence then
            M.apply_task_sequence_to_entity(h, att.TaskSequence)
        end
        local meta = {
            created = h,
            name = attachmentName,
            attachedto = nil,
            parentName = nil,
            bone = 0,
            x = 0.0, y = 0.0, z = 0.0,
            pitch = 0.0, yaw = 0.0, roll = 0.0,
            isped = (tostring(att.Type) == "1"),
            iscollisionproof = finalCollisionProof -- Use finalCollisionProof here
        }
        if att.Attachment then
            meta.attachedto = M.safe_tonumber(att.Attachment.AttachedTo, nil) or att.Attachment.AttachedTo
            meta.bone = M.safe_tonumber(att.Attachment.BoneIndex) or 0
            meta.x = M.safe_tonumber(att.Attachment.X, nil)
            meta.y = M.safe_tonumber(att.Attachment.Y, nil)
            meta.z = M.safe_tonumber(att.Attachment.Z, nil)
            meta.pitch = M.safe_tonumber(att.Attachment.Pitch, nil)
            meta.roll = M.safe_tonumber(att.Attachment.Roll, nil)
            meta.yaw = M.safe_tonumber(att.Attachment.Yaw, nil)
            -- Find parent name from parsed attachments
            for _, parentAtt in ipairs(parsedAttachments) do
                local parentInitHandle = parentAtt.InitialHandle
                if parentInitHandle and (tostring(parentInitHandle) == tostring(meta.attachedto) or M.safe_tonumber(parentInitHandle) == M.safe_tonumber(meta.attachedto)) then
                    meta.parentName = parentAtt.HashName or tostring(parentAtt.ModelHash) or "Unknown Parent"
                    break
                end
            end
            M.debug_print("[Spawn] '" .. attachmentName .. "' will attach to '" .. (meta.parentName or tostring(meta.attachedto)) .. "' (bone: " .. tostring(meta.bone) .. ")")
            if att.AttachmentRaw then
                if meta.x == nil then meta.x = M.safe_tonumber(M.get_xml_element_content(att.AttachmentRaw, "X"), 0.0) end
                if meta.y == nil then meta.y = M.safe_tonumber(M.get_xml_element_content(att.AttachmentRaw, "Y"), 0.0) end
                if meta.z == nil then meta.z = M.safe_tonumber(M.get_xml_element_content(att.AttachmentRaw, "Z"), 0.0) end
                if meta.pitch == nil then meta.pitch = M.safe_tonumber(M.get_xml_element_content(att.AttachmentRaw, "Pitch"), 0.0) end
                if meta.roll == nil then meta.roll = M.safe_tonumber(M.get_xml_element_content(att.AttachmentRaw, "Roll"), 0.0) end
                if meta.yaw == nil then meta.yaw = M.safe_tonumber(M.get_xml_element_content(att.AttachmentRaw, "Yaw"), 0.0) end
                if meta.bone == 0 then
                    local rawBone = M.get_xml_element_content(att.AttachmentRaw, "BoneIndex")
                    local b = M.safe_tonumber(rawBone, 0)
                    meta.bone = (b == 0) and -1 or b
                end
            end
            meta.x = meta.x or 0.0
            meta.y = meta.y or 0.0
            meta.z = meta.z or 0.0
            meta.pitch = meta.pitch or 0.0
            meta.roll = meta.roll or 0.0
            meta.yaw = meta.yaw or 0.0
            if meta.bone == 0 then meta.bone = -1 end
        end
        if spawnerSettings.spawnPlaneInTheAir then
            local vehhash = model
            local isPlane = VEHICLE.IS_THIS_MODEL_A_PLANE(vehhash)
            local isHeli = VEHICLE.IS_THIS_MODEL_A_HELI(vehhash)
            if isPlane or isHeli then
                spawnCoords.z = spawnCoords.z + 45.0
            end
        end
        attachMeta[#attachMeta + 1] = meta
        ::continue::
    end
    local phdbg = {}
    for k, v in pairs(parentHandleMap) do phdbg[#phdbg+1] = tostring(k) .. "->" .. tostring(v) end
    for _, m in ipairs(attachMeta) do
        M.debug_print("[Spawn] Processing '" .. (m.name or "Unknown") .. "' -> attaching to '" .. (m.parentName or tostring(m.attachedto) or "World") .. "'")
        if m.attachedto then
            local parentHandle = parentHandleMap[M.safe_tonumber(m.attachedto)] or parentHandleMap[tostring(m.attachedto)]
            if parentHandle and parentHandle ~= 0 and m.created and m.created ~= 0 then
                local ok, err = pcall(function()
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(
                        m.created,
                        parentHandle,
                        m.bone,
                        m.x, m.y, m.z,
                        m.pitch, m.roll, m.yaw,
                        false, false, not m.iscollisionproof, m.isped, 2, true
                    )
                end)
                if ok then
                    M.debug_print("[Spawn] ✓ Attached '" .. (m.name or "Unknown") .. "' to '" .. (m.parentName or "Parent") .. "'")
                    
                    -- Re-apply collision AFTER attachment (attachment may reset collision state)
                    if m.iscollisionproof then
                        pcall(function()
                            ENTITY.SET_ENTITY_COLLISION(m.created, false, false)
                        end)
                        pcall(function()
                            if ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION then
                                ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(m.created, false, true)
                            end
                        end)
                        -- For peds, extra methods
                        if m.isped then
                            pcall(function()
                                if PED.SET_PED_CAN_RAGDOLL then
                                    PED.SET_PED_CAN_RAGDOLL(m.created, false)
                                end
                            end)
                            -- Disable collision with parent
                            pcall(function()
                                ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(m.created, parentHandle, true)
                            end)
                        end
                    end
                else
                end
            else
                M.debug_print("[Spawn] ✗ Failed to attach '" .. (m.name or "Unknown") .. "' - parent '" .. (m.parentName or tostring(m.attachedto)) .. "' not found")
            end
        else
            M.debug_print("[Spawn] '" .. (m.name or "Unknown") .. "' is a root entity (no parent attachment)")
        end
    end
    return created
end

function M.clearPreview()
    Script.QueueJob(function()
        for _, entity in ipairs(previewEntities) do
            if entity and ENTITY.DOES_ENTITY_EXIST(entity) then
                local ptr = Memory.AllocInt()
                Memory.WriteInt(ptr, entity)
                ENTITY.DELETE_ENTITY(ptr)
            end
        end
        previewEntities = {}
    end)
end

function M.managePreview(hoveredFile)
    if not GUI.IsOpen() then
        if #previewEntities > 0 then
            M.clearPreview()
            M.stopPreviewUpdater()
        end
        currentPreviewFile = nil
        return
    end

    local hoveredPath = hoveredFile and hoveredFile.path or nil

    if hoveredPath and hoveredPath == lastSpawnedVehiclePath then
        if #previewEntities > 0 then
            M.clearPreview()
            M.stopPreviewUpdater()
        end
        currentPreviewFile = nil
        return
    end

    if hoveredPath then
        lastSpawnedVehiclePath = nil
    end

    local currentPath = currentPreviewFile and currentPreviewFile.path or nil

    -- If the hovered file is the same as the current, do nothing.
    if hoveredPath == currentPath then
        return
    end

    -- Always clear previous preview entities and stop updater before processing a new preview.
    if #previewEntities > 0 then
        M.clearPreview()
        M.stopPreviewUpdater()
    end

    currentPreviewFile = hoveredFile

    if not hoveredFile then
        return
    end

    local fileToPreview = hoveredFile
    Script.QueueJob(function()
        Script.Yield(1000)

        -- After delay, check if the user is still hovering over the same file.
        if currentPreviewFile ~= fileToPreview then
            return
        end

        local isPreviewing = true
        if fileToPreview.type == 'vehicle' and spawnerSettings.previewVehicle then
            if fileToPreview.path:lower():match(".xml$") then
                M.spawnVehicleFromXML(fileToPreview.path, isPreviewing)
            elseif fileToPreview.path:lower():match(".ini$") then
                M.spawnVehicleFromINI(fileToPreview.path, isPreviewing)
            end
            M.startPreviewUpdater()
        elseif fileToPreview.type == 'outfit' and spawnerSettings.previewOutfit then
            M.spawnOutfitFromXML(fileToPreview.path, isPreviewing)
            M.startPreviewUpdater()
        end
    end)
end

-- Helper function to calculate combined bounding box for all preview entities
local function calculateCombinedBoundingBox(entities, mainEntity)
    -- Initialize with extreme values
    local globalMinX, globalMinY, globalMinZ = math.huge, math.huge, math.huge
    local globalMaxX, globalMaxY, globalMaxZ = -math.huge, -math.huge, -math.huge
    
    for _, entity in ipairs(entities) do
        if entity and ENTITY.DOES_ENTITY_EXIST(entity) then
            -- Get entity bounding box using model dimensions
            -- GTA V Vector3 has padding: x(4) + pad(4) + y(4) + pad(4) + z(4) + pad(4) = 24 bytes
            local min = Memory.Alloc(24)
            local max = Memory.Alloc(24)
            MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(entity), min, max)
            
            -- Read with proper Vector3 stride (8 bytes per component due to padding)
            local minX = Memory.ReadFloat(min)
            local minY = Memory.ReadFloat(min + 8)
            local minZ = Memory.ReadFloat(min + 16)
            local maxX = Memory.ReadFloat(max)
            local maxY = Memory.ReadFloat(max + 8)
            local maxZ = Memory.ReadFloat(max + 16)
            
            Memory.Free(min)
            Memory.Free(max)
            
            -- Calculate the 8 corners of this entity's bounding box
            local corners = {
                {minX, minY, minZ},
                {maxX, minY, minZ},
                {maxX, maxY, minZ},
                {minX, maxY, minZ},
                {minX, minY, maxZ},
                {maxX, minY, maxZ},
                {maxX, maxY, maxZ},
                {minX, maxY, maxZ}
            }
            
            -- Transform corners to world space relative to the main entity
            for _, corner in ipairs(corners) do
                local worldPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(entity, corner[1], corner[2], corner[3])
                -- Convert world pos back to main entity's local space
                local localPos = ENTITY.GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(mainEntity, worldPos.x, worldPos.y, worldPos.z)
                
                -- Update global bounds
                if localPos.x < globalMinX then globalMinX = localPos.x end
                if localPos.y < globalMinY then globalMinY = localPos.y end
                if localPos.z < globalMinZ then globalMinZ = localPos.z end
                if localPos.x > globalMaxX then globalMaxX = localPos.x end
                if localPos.y > globalMaxY then globalMaxY = localPos.y end
                if localPos.z > globalMaxZ then globalMaxZ = localPos.z end
            end
        end
    end
    
    -- Calculate size
    local sizeX = globalMaxX - globalMinX
    local sizeY = globalMaxY - globalMinY
    local sizeZ = globalMaxZ - globalMinZ
    local maxDimension = math.max(sizeX, sizeY, sizeZ)
    
    return {
        minX = globalMinX, minY = globalMinY, minZ = globalMinZ,
        maxX = globalMaxX, maxY = globalMaxY, maxZ = globalMaxZ,
        sizeX = sizeX, sizeY = sizeY, sizeZ = sizeZ,
        maxDimension = maxDimension
    }
end

-- Helper function to draw bounding box around preview entities
local function drawPreviewBoundingBox(mainEntity, bounds)
    -- Calculate the 8 corners of the combined bounding box in local space
    local corners = {
        {bounds.minX, bounds.minY, bounds.minZ}, -- bottom front left
        {bounds.maxX, bounds.minY, bounds.minZ}, -- bottom front right
        {bounds.maxX, bounds.maxY, bounds.minZ}, -- bottom back right
        {bounds.minX, bounds.maxY, bounds.minZ}, -- bottom back left
        {bounds.minX, bounds.minY, bounds.maxZ}, -- top front left
        {bounds.maxX, bounds.minY, bounds.maxZ}, -- top front right
        {bounds.maxX, bounds.maxY, bounds.maxZ}, -- top back right
        {bounds.minX, bounds.maxY, bounds.maxZ}  -- top back left
    }
    
    -- Transform corners to world space
    local worldCorners = {}
    for _, corner in ipairs(corners) do
        local worldPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(mainEntity, corner[1], corner[2], corner[3])
        table.insert(worldCorners, worldPos)
    end
    
    -- Purple color for all edges
    local boxColor = {r = 180, g = 100, b = 255, a = 200}
    
    -- Draw bottom edges
    GRAPHICS.DRAW_LINE(worldCorners[1].x, worldCorners[1].y, worldCorners[1].z,
                       worldCorners[2].x, worldCorners[2].y, worldCorners[2].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[2].x, worldCorners[2].y, worldCorners[2].z,
                       worldCorners[3].x, worldCorners[3].y, worldCorners[3].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[3].x, worldCorners[3].y, worldCorners[3].z,
                       worldCorners[4].x, worldCorners[4].y, worldCorners[4].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[4].x, worldCorners[4].y, worldCorners[4].z,
                       worldCorners[1].x, worldCorners[1].y, worldCorners[1].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    
    -- Draw top edges
    GRAPHICS.DRAW_LINE(worldCorners[5].x, worldCorners[5].y, worldCorners[5].z,
                       worldCorners[6].x, worldCorners[6].y, worldCorners[6].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[6].x, worldCorners[6].y, worldCorners[6].z,
                       worldCorners[7].x, worldCorners[7].y, worldCorners[7].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[7].x, worldCorners[7].y, worldCorners[7].z,
                       worldCorners[8].x, worldCorners[8].y, worldCorners[8].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[8].x, worldCorners[8].y, worldCorners[8].z,
                       worldCorners[5].x, worldCorners[5].y, worldCorners[5].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    
    -- Draw vertical edges connecting bottom to top
    GRAPHICS.DRAW_LINE(worldCorners[1].x, worldCorners[1].y, worldCorners[1].z,
                       worldCorners[5].x, worldCorners[5].y, worldCorners[5].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[2].x, worldCorners[2].y, worldCorners[2].z,
                       worldCorners[6].x, worldCorners[6].y, worldCorners[6].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[3].x, worldCorners[3].y, worldCorners[3].z,
                       worldCorners[7].x, worldCorners[7].y, worldCorners[7].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[4].x, worldCorners[4].y, worldCorners[4].z,
                       worldCorners[8].x, worldCorners[8].y, worldCorners[8].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
end

function M.startPreviewUpdater()
    if previewUpdateJob then return end
    isPreviewUpdaterRunning = true -- Set flag to true when starting
    previewUpdateJob = Script.QueueJob(function()
        while isPreviewUpdaterRunning do -- Loop while the flag is true
            if not GUI.IsOpen() then
                M.clearPreview()
                M.stopPreviewUpdater()
                goto continue_loop
            end
            if #previewEntities > 0 then
                local mainEntity = previewEntities[1]
                if mainEntity and ENTITY.DOES_ENTITY_EXIST(mainEntity) then
                    local playerPed = PLAYER.PLAYER_PED_ID()
                    if not playerPed or playerPed == 0 then
                        M.clearPreview()
                    else
                        -- Calculate combined bounding box for all preview entities
                        local bounds = calculateCombinedBoundingBox(previewEntities, mainEntity)
                        
                        local camCoords = CAM.GET_GAMEPLAY_CAM_COORD()
                        local camRot = CAM.GET_GAMEPLAY_CAM_ROT(2) -- 2 for Euler angles
                        
                        local isOutfit = ENTITY.GET_ENTITY_TYPE(mainEntity) == 1 -- 1 for ped
                        
                        -- Calculate dynamic distance based on bounding box size
                        -- Use max dimension to ensure the entire vehicle fits in view
                        local baseDistance = isOutfit and 2.5 or 10.0
                        local dynamicDistance = baseDistance + (bounds.maxDimension * 1.5)
                        -- Clamp distance to reasonable values
                        dynamicDistance = math.max(5.0, math.min(dynamicDistance, 100.0))
                        
                        local offset_height = isOutfit and -0.5 or 0.0

                        local camForward = M.RotToDir(camRot)
                        -- Calculate horizontal position in front of camera
                        local spawnPos = {
                            x = camCoords.x + (camForward.x * dynamicDistance),
                            y = camCoords.y + (camForward.y * dynamicDistance),
                            z = camCoords.z -- Temporary, will be adjusted
                        }
                        
                        -- Get ground Z at the spawn position and add 5 units
                        local foundGround, groundZ = GTA.GetGroundZ(spawnPos.x, spawnPos.y)
                        if foundGround then
                            spawnPos.z = groundZ + 1.0
                        else
                            -- Fallback if ground not found
                            spawnPos.z = camCoords.z + 1.0
                        end

                        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(mainEntity, spawnPos.x, spawnPos.y, spawnPos.z, false, false, true)
                        
                        previewRotation.z = previewRotation.z + 1.0
                        if previewRotation.z > 360 then previewRotation.z = 0.0 end
                        
                        -- Align the entity with the camera's yaw, but keep pitch and roll at 0 for a stable preview
                        ENTITY.SET_ENTITY_ROTATION(mainEntity, 0.0, 0.0, camRot.z + previewRotation.z, 2, true)
                        
                        -- Draw bounding box around the entire vehicle and attachments
                        drawPreviewBoundingBox(mainEntity, bounds)
                    end
                else
                    M.clearPreview()
                end
            end
            Script.Yield(0)
            ::continue_loop::
        end
        previewUpdateJob = nil -- Clear the job reference when the loop ends
    end)
end

function M.RotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return {x = -math.sin(z) * num, y = math.cos(z) * num, z = math.sin(x)}
end

function M.stopPreviewUpdater()
    if isPreviewUpdaterRunning then
        isPreviewUpdaterRunning = false -- Set flag to false to stop the loop
        -- The job reference will be set to nil by the job itself when the loop terminates
    end
end

function M.parse_vehicle_mods(xml)
    local mods = {}
    local vehicleProperties = M.get_xml_element(xml, "VehicleProperties")
    if not vehicleProperties then return mods end
    local modsSection = M.get_xml_element(vehicleProperties, "Mods")
    if not modsSection then return mods end
    for modId, modValue in modsSection:gmatch("<_([0-9]+)>([^<]+)</_%d+>") do
        local id = M.safe_tonumber(modId, nil)
        if id then
            local parts = M.split_str(modValue, ",")
            local m = M.safe_tonumber(parts[1], -1)
            local v = M.safe_tonumber(parts[2], 0)
            mods[id] = { mod = m, var = v }
        end
    end
    return mods
end

function M.parse_vehicle_colors(xml)
    local colors = {}
    local vehicleProperties = M.get_xml_element(xml, "VehicleProperties")
    if not vehicleProperties then return colors end
    local colorsSection = M.get_xml_element(vehicleProperties, "Colours")
    if not colorsSection then return colors end
    colors.Primary = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Primary"), nil)
    colors.Secondary = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Secondary"), nil)
    colors.Pearl = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Pearl"), nil)
    colors.Rim = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Rim"), nil)
    colors.tyreSmoke_R = M.safe_tonumber(M.get_xml_element_content(colorsSection, "tyreSmoke_R"), nil)
    colors.tyreSmoke_G = M.safe_tonumber(M.get_xml_element_content(colorsSection, "tyreSmoke_G"), nil)
    colors.tyreSmoke_B = M.safe_tonumber(M.get_xml_element_content(colorsSection, "tyreSmoke_B"), nil)
    colors.LrInterior = M.safe_tonumber(M.get_xml_element_content(colorsSection, "LrInterior"), nil)
    colors.LrDashboard = M.safe_tonumber(M.get_xml_element_content(colorsSection, "LrDashboard"), nil)

    -- Custom Colors
    colors.IsPrimaryColourCustom = M.to_boolean(M.get_xml_element_content(colorsSection, "IsPrimaryColourCustom"))
    colors.Cust1_R = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Cust1_R"), 0)
    colors.Cust1_G = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Cust1_G"), 0)
    colors.Cust1_B = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Cust1_B"), 0)

    colors.IsSecondaryColourCustom = M.to_boolean(M.get_xml_element_content(colorsSection, "IsSecondaryColourCustom"))
    colors.Cust2_R = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Cust2_R"), 0)
    colors.Cust2_G = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Cust2_G"), 0)
    colors.Cust2_B = M.safe_tonumber(M.get_xml_element_content(colorsSection, "Cust2_B"), 0)

    return colors
end

function M.parse_vehicle_neons(xml)
    local neons = nil
    local vehicleProperties = M.get_xml_element(xml, "VehicleProperties")
    if vehicleProperties then
        local neonsSection = M.get_xml_element(vehicleProperties, "Neons")
        if neonsSection then
            neons = {}
            neons.Left = M.to_boolean(M.get_xml_element_content(neonsSection, "Left"))
            neons.Right = M.to_boolean(M.get_xml_element_content(neonsSection, "Right"))
            neons.Front = M.to_boolean(M.get_xml_element_content(neonsSection, "Front"))
            neons.Back = M.to_boolean(M.get_xml_element_content(neonsSection, "Back"))
            neons.R = M.safe_tonumber(M.get_xml_element_content(neonsSection, "R"), nil)
            neons.G = M.safe_tonumber(M.get_xml_element_content(neonsSection, "G"), nil)
            neons.B = M.safe_tonumber(M.get_xml_element_content(neonsSection, "B"), nil)
        end
    end
    return neons
end

function M.parse_map_placements(xml)
    local placements = {}
    local searchPos = 1
    while true do
        local openStart = xml:find("<Placement[^>]*>", searchPos)
        if not openStart then break end
        local closePos = xml:find("</Placement>", openStart)
        if not closePos then break end
        local placementInner = xml:sub(openStart, closePos + #"</Placement>" - 1)
        local placement = {}
        placement.ModelHash = M.get_xml_element_content(placementInner, "ModelHash")
        placement.Type = M.get_xml_element_content(placementInner, "Type")
        placement.Dynamic = M.to_boolean(M.get_xml_element_content(placementInner, "Dynamic"))
        placement.FrozenPos = M.to_boolean(M.get_xml_element_content(placementInner, "FrozenPos"))
        placement.HashName = M.get_xml_element_content(placementInner, "HashName")
        placement.InitialHandle = M.safe_tonumber(M.get_xml_element_content(placementInner, "InitialHandle"), nil)
        placement.OpacityLevel = M.get_xml_element_content(placementInner, "OpacityLevel")
        placement.LodDistance = M.get_xml_element_content(placementInner, "LodDistance")
        placement.IsVisible = M.get_xml_element_content(placementInner, "IsVisible")
        placement.MaxHealth = M.get_xml_element_content(placementInner, "MaxHealth")
        placement.Health = M.get_xml_element_content(placementInner, "Health")
        placement.HasGravity = M.to_boolean(M.get_xml_element_content(placementInner, "HasGravity"))
        placement.IsOnFire = M.to_boolean(M.get_xml_element_content(placementInner, "IsOnFire"))
        placement.IsInvincible = M.to_boolean(M.get_xml_element_content(placementInner, "IsInvincible"))
        placement.IsBulletProof = M.to_boolean(M.get_xml_element_content(placementInner, "IsBulletProof"))
        placement.IsCollisionProof = M.to_boolean(M.get_xml_element_content(placementInner, "IsCollisionProof"))
        placement.IsExplosionProof = M.to_boolean(M.get_xml_element_content(placementInner, "IsExplosionProof"))
        placement.IsFireProof = M.to_boolean(M.get_xml_element_content(placementInner, "IsFireProof"))
        placement.IsMeleeProof = M.to_boolean(M.get_xml_element_content(placementInner, "IsMeleeProof"))
        placement.IsOnlyDamagedByPlayer = M.to_boolean(M.get_xml_element_content(placementInner, "IsOnlyDamagedByPlayer"))
        local objProps = M.get_xml_element(placementInner, "ObjectProperties")
        if objProps then
            placement.ObjectProperties = {}
            for name, val in objProps:gmatch("<([%w_]+)>(.-)</%1>") do
                placement.ObjectProperties[name] = val
            end
        end
        local posRot = M.get_xml_element(placementInner, "PositionRotation")
        if posRot then
            placement.PositionRotation = {}
            for name, val in posRot:gmatch("<([%w_]+)>(.-)</%1>") do
                placement.PositionRotation[name] = M.safe_tonumber(val, val)
            end
        end
        local attachment = M.get_xml_element(placementInner, "Attachment")
        if attachment then
            placement.Attachment = {}
            placement.Attachment.isAttached = attachment:find('isAttached="true"') ~= nil
            if placement.Attachment.isAttached then
                placement.Attachment.AttachedTo = M.safe_tonumber(M.get_xml_element_content(attachment, "AttachedTo"), nil)
                placement.Attachment.BoneIndex = M.safe_tonumber(M.get_xml_element_content(attachment, "BoneIndex"), nil)
                placement.Attachment.X = M.safe_tonumber(M.get_xml_element_content(attachment, "X"), 0.0)
                placement.Attachment.Y = M.safe_tonumber(M.get_xml_element_content(attachment, "Y"), 0.0)
                placement.Attachment.Z = M.safe_tonumber(M.get_xml_element_content(attachment, "Z"), 0.0)
                placement.Attachment.Pitch = M.safe_tonumber(M.get_xml_element_content(attachment, "Pitch"), 0.0)
                placement.Attachment.Roll = M.safe_tonumber(M.get_xml_element_content(attachment, "Roll"), 0.0)
                placement.Attachment.Yaw = M.safe_tonumber(M.get_xml_element_content(attachment, "Yaw"), 0.0)
            end
        end
        table.insert(placements, placement)
        searchPos = closePos + #"</Placement>"
    end

    local markers = {}
    searchPos = 1
    while true do
        local openStart = xml:find("<Marker[^>]*>", searchPos)
        if not openStart then break end
        local closePos = xml:find("</Marker>", openStart)
        if not closePos then break end
        local markerInner = xml:sub(openStart, closePos + #"</Marker>" - 1)
        
        local marker = {}
        marker.Type = M.safe_tonumber(M.get_xml_element_content(markerInner, "Type"), 0)
        marker.X = 0.0
        marker.Y = 0.0
        marker.Z = 0.0
        
        -- Parse Position
        local posBlock = M.get_xml_element(markerInner, "Position")
        if posBlock then
            local innerPos = parse_vector_from_tag(posBlock, "Position")
            if innerPos then
                marker.X = innerPos.x
                marker.Y = innerPos.y
                marker.Z = innerPos.z
            end
            local innerRot = parse_vector_from_tag(posBlock, "Rotation")
            if innerRot then
                marker.RotX = innerRot.x
                marker.RotY = innerRot.y
                marker.RotZ = innerRot.z
            end
        end
        
        marker.Scale = M.safe_tonumber(M.get_xml_element_content(markerInner, "Scale"), 1.0)
        marker.RotateContinuously = M.to_boolean(M.get_xml_element_content(markerInner, "RotateContinuously"))
        
        local colourSnippet = parse_self_closing_tag(markerInner, "Colour")
        if colourSnippet then
            local colourAttrs = parse_attributes(colourSnippet)
            marker.Colour = {
                r = M.safe_tonumber(colourAttrs.R or colourAttrs.r, 255),
                g = M.safe_tonumber(colourAttrs.G or colourAttrs.g, 255),
                b = M.safe_tonumber(colourAttrs.B or colourAttrs.b, 255),
                a = M.safe_tonumber(colourAttrs.A or colourAttrs.a, 255)
            }
        end
        
        table.insert(markers, marker)
        searchPos = closePos + 1
    end

    return placements, markers
end

function M.parse_outfit_attachments(xmlContent)
    local attachments = {}
    local defaultTaskAutoStart = nil
    local attrSnippet = xmlContent:match("<SpoonerAttachments([^>]*)>")
    if attrSnippet then
        local attrs = parse_attributes(attrSnippet)
        if attrs and attrs.StartTaskSequencesOnLoad ~= nil then
            defaultTaskAutoStart = M.to_boolean(attrs.StartTaskSequencesOnLoad)
        end
    end
    local spoonerAttachmentsElement = M.get_xml_element(xmlContent, "SpoonerAttachments")
    if not spoonerAttachmentsElement then
        return attachments
    end
    for attachmentElement in spoonerAttachmentsElement:gmatch("<Attachment>.-</Attachment>") do
        local attachment = {}
        attachment.ModelHash = M.get_xml_element_content(attachmentElement, "ModelHash")
        attachment.Type = M.get_xml_element_content(attachmentElement, "Type")
        attachment.Dynamic = M.to_boolean(M.get_xml_element_content(attachmentElement, "Dynamic"))
        attachment.FrozenPos = M.to_boolean(M.get_xml_element_content(attachmentElement, "FrozenPos"))
        attachment.HashName = M.get_xml_element_content(attachmentElement, "HashName")
        attachment.InitialHandle = M.get_xml_element_content(attachmentElement, "InitialHandle")
        attachment.OpacityLevel = M.safe_tonumber(M.get_xml_element_content(attachmentElement, "OpacityLevel"), nil)
        attachment.IsVisible = M.to_boolean(M.get_xml_element_content(attachmentElement, "IsVisible"))
        attachment.IsInvincible = M.to_boolean(M.get_xml_element_content(attachmentElement, "IsInvincible"))
        local objectPropsElement = M.get_xml_element(attachmentElement, "ObjectProperties")
        if objectPropsElement then
            attachment.ObjectProperties = {}
            local textureVariation = M.get_xml_element_content(objectPropsElement, "TextureVariation")
            if textureVariation then
                attachment.ObjectProperties.TextureVariation = M.safe_tonumber(textureVariation, 0)
            end
        end
        local posRotElement = M.get_xml_element(attachmentElement, "PositionRotation")
        if posRotElement then
            attachment.PositionRotation = {}
            attachment.PositionRotation.X = M.safe_tonumber(M.get_xml_element_content(posRotElement, "X"), 0.0)
            attachment.PositionRotation.Y = M.safe_tonumber(M.get_xml_element_content(posRotElement, "Y"), 0.0)
            attachment.PositionRotation.Z = M.safe_tonumber(M.get_xml_element_content(posRotElement, "Z"), 0.0)
            attachment.PositionRotation.Pitch = M.safe_tonumber(M.get_xml_element_content(posRotElement, "Pitch"), 0.0)
            attachment.PositionRotation.Roll = M.safe_tonumber(M.get_xml_element_content(posRotElement, "Roll"), 0.0)
            attachment.PositionRotation.Yaw = M.safe_tonumber(M.get_xml_element_content(posRotElement, "Yaw"), 0.0)
        end
        local attachmentDataElement = M.get_xml_element(attachmentElement, "Attachment")
        if attachmentDataElement then
            attachment.Attachment = {}
            attachment.Attachment.isAttached = attachmentDataElement:find('isAttached="true"') and true or false
            attachment.Attachment.AttachedTo = M.get_xml_element_content(attachmentDataElement, "AttachedTo")
            attachment.Attachment.BoneIndex = M.safe_tonumber(M.get_xml_element_content(attachmentDataElement, "BoneIndex"), 0)
            attachment.Attachment.X = M.safe_tonumber(M.get_xml_element_content(attachmentDataElement, "X"), 0.0)
            attachment.Attachment.Y = M.safe_tonumber(M.get_xml_element_content(attachmentDataElement, "Y"), 0.0)
            attachment.Attachment.Z = M.safe_tonumber(M.get_xml_element_content(attachmentDataElement, "Z"), 0.0)
            attachment.Attachment.Pitch = M.safe_tonumber(M.get_xml_element_content(attachmentDataElement, "Pitch"), 0.0)
            attachment.Attachment.Roll = M.safe_tonumber(M.get_xml_element_content(attachmentDataElement, "Roll"), 0.0)
            attachment.Attachment.Yaw = M.safe_tonumber(M.get_xml_element_content(attachmentDataElement, "Yaw"), 0.0)
        end
        local taskSequenceElement = M.get_xml_element(attachmentElement, "TaskSequence")
        if taskSequenceElement then
            attachment.TaskSequence = M.parse_task_sequence(taskSequenceElement, defaultTaskAutoStart)
        end
        table.insert(attachments, attachment)
    end
    return attachments
end

function M.get_filename_from_path(filePath)
    if not filePath then return "Unknown" end
    local filename = filePath:match("([^/\\]+)$")
    return filename or "Unknown"
end

function M.try_call(tbl, fname, ...)
    if not tbl then return nil end
    local f = tbl[fname]
    if type(f) == "function" then return f(...) end
    return nil
end

function M.deleteVehicle(vehicleData)
    if not vehicleData then return end
    Script.QueueJob(function()
        if vehicleData.attachments then
            for _, attachmentHandle in ipairs(vehicleData.attachments) do
                if attachmentHandle and attachmentHandle ~= 0 then
                    pcall(function()
                        if ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                            local entityType = ENTITY.GET_ENTITY_TYPE(attachmentHandle)
                            if not entityType or entityType < 0 or entityType > 3 then
                                return
                            end
                            local ptr = Memory.AllocInt()
                            Memory.WriteInt(ptr, attachmentHandle)
                            ENTITY.DELETE_ENTITY(ptr)
                        else
                            M.debug_print("[Delete Debug] Warning: Attachment entity does not exist for handle:", tostring(attachmentHandle))
                        end
                    end)
                end
            end
        end
        if vehicleData.vehicle and vehicleData.vehicle ~= 0 then
            pcall(function()
                if ENTITY and ENTITY.DOES_ENTITY_EXIST(vehicleData.vehicle) then
                    local entityType = ENTITY.GET_ENTITY_TYPE(vehicleData.vehicle)
                    if entityType ~= 2 then
                        return
                    end
                    local ptr = Memory.AllocInt()
                    Memory.WriteInt(ptr, vehicleData.vehicle)
                    ENTITY.DELETE_ENTITY(ptr)
                else
                end
            end)
        end
    end)
end

-- Delete a specific vehicle by index
function M.deleteVehicleByIndex(index)
    if not spawnedVehicles or not spawnedVehicles[index] then return end
    local vehicleData = spawnedVehicles[index]
    M.deleteVehicle(vehicleData)
    table.remove(spawnedVehicles, index)
end

-- Delete a specific map by index
function M.deleteMapByIndex(index)
    if not spawnedMaps or not spawnedMaps[index] then return end
    local mapData = spawnedMaps[index]
    Script.QueueJob(function()
        if mapData.entities then
            for _, entityHandle in ipairs(mapData.entities) do
                if entityHandle and entityHandle ~= 0 then
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                            local ptr = Memory.AllocInt()
                            Memory.WriteInt(ptr, entityHandle)
                            ENTITY.DELETE_ENTITY(ptr)
                        end
                    end)
                end
            end
        end
    end)
    table.remove(spawnedMaps, index)
end

-- Put player into a vehicle (drive it)
function M.driveVehicle(vehicleHandle)
    if not vehicleHandle or vehicleHandle == 0 then return end
    Script.QueueJob(function()
        if not ENTITY.DOES_ENTITY_EXIST(vehicleHandle) then
            pcall(function() GUI.AddToast("Error", "Vehicle no longer exists", 3000, 0) end)
            return
        end
        local playerPed = PLAYER.PLAYER_PED_ID()
        if playerPed and playerPed ~= 0 then
            PED.SET_PED_INTO_VEHICLE(playerPed, vehicleHandle, -1)
        end
    end)
end

-- Teleport player to map reference coordinates
function M.teleportToMapRefCoords(refCoords)
    if not refCoords then return end
    Script.QueueJob(function()
        local playerPed = PLAYER.PLAYER_PED_ID()
        if playerPed and playerPed ~= 0 then
            ENTITY.SET_ENTITY_COORDS(playerPed, refCoords.x or 0, refCoords.y or 0, refCoords.z or 0, false, false, false, true)
        end
    end)
end

function M.deleteAllSpawnedVehicles()
    Script.QueueJob(function()
        local vehiclesToDelete = {}
        for _, vehicleData in pairs(spawnedVehicles) do
            table.insert(vehiclesToDelete, vehicleData)
        end
        for i, vehicleData in ipairs(vehiclesToDelete) do
            if vehicleData.attachments then
                for _, attachmentHandle in ipairs(vehicleData.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        pcall(function()
                            if ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                                local entityType = ENTITY.GET_ENTITY_TYPE(attachmentHandle)
                                if not entityType or entityType < 0 or entityType > 3 then
                                    return
                                end
                                local ptr = Memory.AllocInt()
                                Memory.WriteInt(ptr, attachmentHandle)
                                ENTITY.DELETE_ENTITY(ptr)
                            else
                                M.debug_print("[Delete Debug] Warning: Attachment entity does not exist for handle:", tostring(attachmentHandle))
                            end
                        end)
                    end
                end
            end
            if vehicleData.vehicle and vehicleData.vehicle ~= 0 then
                pcall(function()
                    if ENTITY and ENTITY.DOES_ENTITY_EXIST(vehicleData.vehicle) then
                        local entityType = ENTITY.GET_ENTITY_TYPE(vehicleData.vehicle)
                        if entityType ~= 2 then
                            return
                        end
                        local ptr = Memory.AllocInt()
                        Memory.WriteInt(ptr, vehicleData.vehicle)
                        ENTITY.DELETE_ENTITY(ptr)
                    else
                    end
                end)
            end
        end
        for k in pairs(spawnedVehicles) do spawnedVehicles[k] = nil end
    end)
end

function M.deleteAllSpawnedMaps()
    Script.QueueJob(function()
        local mapsToDelete = {}
        for _, mapData in pairs(spawnedMaps) do
            table.insert(mapsToDelete, mapData)
        end
        for i, mapData in ipairs(mapsToDelete) do
            if mapData.entities then
                for j, entityHandle in ipairs(mapData.entities) do
                    if entityHandle and entityHandle ~= 0 then
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                                local ptr = Memory.AllocInt()
                                Memory.WriteInt(ptr, entityHandle)
                                ENTITY.DELETE_ENTITY(ptr)
                            else
                            end
                        end)
                    end
                end
            end
        end
        for k in pairs(spawnedMaps) do spawnedMaps[k] = nil end
    end)
end

function M.deleteAllSpawnedOutfits()
    Script.QueueJob(function()
        local outfitsToDelete = {}
        for _, outfitData in pairs(spawnedOutfits) do
            table.insert(outfitsToDelete, outfitData)
        end
        for i, outfitData in ipairs(outfitsToDelete) do
            if outfitData.spawnedPed then
                pcall(function()
                    if ENTITY and ENTITY.DOES_ENTITY_EXIST(outfitData.spawnedPed) then
                        local ptr = Memory.AllocInt()
                        Memory.WriteInt(ptr, outfitData.spawnedPed)
                        ENTITY.DELETE_ENTITY(ptr)
                    else
                    end
                end)
            end
            if outfitData.attachments then
                for j, attachmentHandle in ipairs(outfitData.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        pcall(function()
                            if ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                                local ptr = Memory.AllocInt()
                                Memory.WriteInt(ptr, attachmentHandle)
                                ENTITY.DELETE_ENTITY(ptr)
                            else
                                M.debug_print("[Delete Debug] Warning: Outfit attachment entity does not exist for handle:", tostring(attachmentHandle))
                            end
                        end)
                    end
                end
            end
        end
        for k in pairs(spawnedOutfits) do spawnedOutfits[k] = nil end
    end)
end

function M.spawnVehicleFromINI(filePath, isPreview)
    isPreview = isPreview or false
    Script.QueueJob(function()
        if not isPreview and currentPreviewFile and currentPreviewFile.path == filePath and #previewEntities > 0 then
            M.clearPreview()
            M.stopPreviewUpdater()
        end
        local vehicleHandle = nil
        local createdAttachments = {}
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Spawn Debug] Error: INI file does not exist:", filePath)
            return
        end
        local iniData = M.parse_ini_file(filePath)
        if not iniData then
            M.debug_print("[Spawn Debug] Error: Failed to parse INI file:", filePath)
            return
        end
        local mainVehicleSection = iniData.Vehicle or iniData.Vehicle0
        if not mainVehicleSection then
            M.debug_print("[Spawn Debug] Error: Main vehicle section ('Vehicle' or 'Vehicle0') not found in INI file:", filePath)
            return
        end
        local modelHashStr = mainVehicleSection.Hash or mainVehicleSection.ModelHash or mainVehicleSection.Model or mainVehicleSection.model
        if not modelHashStr then
            M.debug_print("[Spawn Debug] Error: Vehicle model hash (Hash, ModelHash, Model, or model) not found in main vehicle section of INI file:", filePath)
            return
        end
        local modelHash = M.safe_tonumber(modelHashStr, nil)
        if not modelHash then
            M.debug_print("[Spawn Debug] Error: Invalid vehicle model hash value in INI file:", modelHashStr, "from:", filePath)
            return
        end
        local playerPed = GTA.GetLocalPed()
        if not playerPed then
            M.debug_print("[Spawn Debug] Error: Player ped not found.")
            return
        end
        local pos = playerPed.Position
        local heading = playerPed.Heading or 0.0
        local spawnX, spawnY, spawnZ
        if isPreview then
            local offset_distance = 5.0
            local offset_height = 0.5
            local rad_heading = math.rad(heading)
            spawnX = pos.x + (math.sin(rad_heading) * offset_distance)
            spawnY = pos.y + (math.cos(rad_heading) * offset_distance)
            spawnZ = pos.z + offset_height
        end
        if spawnerSettings.deleteOldVehicle and not isPreview then
            M.deleteAllSpawnedVehicles()
        end

        local playerID = PLAYER.PLAYER_ID()
        local forwardOffset = 5.0 

        -- Check if we should use the current vehicle instead of spawning a new one
        local applyToCurrentVehicle = spawnerSettings.onlyApplyAttachments and not isPreview
        
        if applyToCurrentVehicle then
            -- Get the player's current vehicle
            local playerPedHandle = GTA.PointerToHandle(playerPed)
            if playerPedHandle and playerPedHandle ~= 0 then
                local currentVehicle = nil
                pcall(function()
                    currentVehicle = PED.GET_VEHICLE_PED_IS_IN(playerPedHandle, false)
                end)
                if currentVehicle and currentVehicle ~= 0 then
                    vehicleHandle = currentVehicle
                    M.debug_print("[Apply Attachments] Using current vehicle: " .. tostring(vehicleHandle))
                else
                    GUI.AddToast("Apply Attachments", "You must be in a vehicle to apply attachments", 5000, 0)
                    return
                end
            else
                GUI.AddToast("Apply Attachments", "Could not get player ped handle", 5000, 0)
                return
            end
        elseif not isPreview then
  
            local vehhash = modelHash
            local isPlane = VEHICLE.IS_THIS_MODEL_A_PLANE(vehhash)
            local isHeli = VEHICLE.IS_THIS_MODEL_A_HELI(vehhash)
            if spawnerSettings.spawnPlaneInTheAir and (isPlane or isHeli) then
 
                local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
                if ok and h and h ~= 0 then vehicleHandle = h end
                if vehicleHandle and vehicleHandle ~= 0 then
                    local currentCoords = ENTITY.GET_ENTITY_COORDS(vehicleHandle, true)
                    ENTITY.SET_ENTITY_COORDS(vehicleHandle, currentCoords.x, currentCoords.y, currentCoords.z + 45.0, false, false, false, true)
                    VEHICLE.SET_HELI_BLADES_FULL_SPEED(vehicleHandle)
                    VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, true, true, true)
                    VEHICLE.SET_VEHICLE_FORWARD_SPEED(vehicleHandle, 100.0)
                end
            else
                local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
                if ok and h and h ~= 0 then vehicleHandle = h end
            end
        else -- isPreview
            local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end

        if isPreview and vehicleHandle and vehicleHandle ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_COLLISION(vehicleHandle, false, false) end)
        end

        if not vehicleHandle or vehicleHandle == 0 then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            Logger.LogError("[Spawn] Failed to spawn vehicle from '" .. fileName .. "' (hash: " .. tostring(modelHash) .. ")")
            return
        end
        if spawnerSettings.randomColor then
            M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_5", vehicleHandle, math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_6", vehicleHandle, math.random(0,255))
        elseif mainVehicleSection then
            local primaryPaint = M.safe_tonumber(mainVehicleSection["primary paint"], nil)
            local secondaryPaint = M.safe_tonumber(mainVehicleSection["secondary paint"], nil)
            if primaryPaint ~= nil and secondaryPaint ~= nil then
                M.try_call(VEHICLE, "SET_VEHICLE_COLOURS", vehicleHandle, primaryPaint, secondaryPaint)
            end
            local customPrimaryColour = M.safe_tonumber(mainVehicleSection["custom primary colour"], nil)
            local customSecondaryColour = M.safe_tonumber(mainVehicleSection["custom secondary colour"], nil)
            if customPrimaryColour ~= nil and customSecondaryColour ~= nil then
                M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", vehicleHandle, customPrimaryColour, customPrimaryColour, customPrimaryColour)
                M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", vehicleHandle, customSecondaryColour, customSecondaryColour, customSecondaryColour)
            end
            local pearlescentColour = M.safe_tonumber(mainVehicleSection["pearlescent colour"], nil)
            local wheelColour = M.safe_tonumber(mainVehicleSection["wheel colour"], nil)
            if pearlescentColour ~= nil and wheelColour ~= nil then
                M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOURS", vehicleHandle, pearlescentColour, wheelColour)
            end
            local tyreSmokeR = M.safe_tonumber(mainVehicleSection["tyre smoke red"], nil)
            local tyreSmokeG = M.safe_tonumber(mainVehicleSection["tyre smoke green"], nil)
            local tyreSmokeB = M.safe_tonumber(mainVehicleSection["tyre smoke blue"], nil)
            if tyreSmokeR ~= nil and tyreSmokeG ~= nil and tyreSmokeB ~= nil then
                M.try_call(VEHICLE, "SET_VEHICLE_TYRE_SMOKE_COLOR", vehicleHandle, tyreSmokeR, tyreSmokeG, tyreSmokeB)
            end
            local neonR = M.safe_tonumber(mainVehicleSection["neon red"], nil)
            local neonG = M.safe_tonumber(mainVehicleSection["neon green"], nil)
            local neonB = M.safe_tonumber(mainVehicleSection["neon blue"], nil)
            if neonR ~= nil and neonG ~= nil and neonB ~= nil then
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHTS_COLOUR", vehicleHandle, neonR, neonG, neonB)
            end
            for i = 0, 3 do
                local neonEnabled = M.to_boolean(mainVehicleSection["neon " .. i])
                M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, i, neonEnabled)
                M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, i, neonEnabled)
            end
            local windowTint = M.safe_tonumber(mainVehicleSection["window tint"], nil)
            if windowTint ~= nil and windowTint >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_WINDOW_TINT", vehicleHandle, windowTint) end
            local plateIndex = M.safe_tonumber(mainVehicleSection["plate index"], nil)
            if plateIndex ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX", vehicleHandle, plateIndex) end
            local plateText = mainVehicleSection["plate text"]
            if plateText then M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT", vehicleHandle, plateText) end
            local wheelType = M.safe_tonumber(mainVehicleSection["wheel type"], nil)
            if wheelType ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_WHEEL_TYPE", vehicleHandle, wheelType) end
            local bulletproofTyres = M.to_boolean(mainVehicleSection["bulletproof tyres"])
            M.try_call(VEHICLE, "SET_VEHICLE_TYRES_CAN_BURST", vehicleHandle, not bulletproofTyres)
            local customTyres = M.to_boolean(mainVehicleSection["custom tyres"])
            M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_TYRES", vehicleHandle, customTyres)
            local dirtLevel = M.safe_tonumber(mainVehicleSection["dirt level"], nil)
            if dirtLevel ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_DIRT_LEVEL", vehicleHandle, dirtLevel) end
            local engineOn = M.to_boolean(mainVehicleSection.EngineOn)
            if spawnerSettings.vehicleEngineOn and engineOn then M.try_call(VEHICLE, "SET_VEHICLE_ENGINE_ON", vehicleHandle, true, true, false) end
            if spawnerSettings.radioOff then M.try_call(AUDIO, "SET_VEHICLE_RADIO_ENABLED", vehicleHandle, false) end
            local paintFade = M.safe_tonumber(mainVehicleSection.PaintFade, nil)
            if paintFade ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_DIRT_LEVEL", vehicleHandle, paintFade) end
            local radioStation = M.safe_tonumber(mainVehicleSection.Radio, nil)
            if radioStation ~= nil then M.try_call(PLAYER, "SET_PLAYER_RADIO_STATION_INDEX", radioStation) end
        end
        if spawnerSettings.randomLivery then
            local liveryCount = M.try_call(VEHICLE, "GET_VEHICLE_LIVERY_COUNT", vehicleHandle)
            if liveryCount and liveryCount > 0 then
                local randomLivery = math.random(0, liveryCount - 1)
                M.try_call(VEHICLE, "SET_VEHICLE_LIVERY", vehicleHandle, randomLivery)
            else
            end
        elseif mainVehicleSection then
            local livery = M.safe_tonumber(mainVehicleSection.Livery, nil)
            if livery and livery >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_LIVERY", vehicleHandle, livery) end
        end
        local modsSection = iniData["Vehicle Mods"]
        if spawnerSettings.upgradedVehicle then
            M.try_call(VEHICLE, "SET_VEHICLE_MOD_KIT", vehicleHandle, 0)
            for i = 0, 50 do
                local maxMods = M.try_call(VEHICLE, "GET_NUM_VEHICLE_MODS", vehicleHandle, i)
                if maxMods and maxMods > 0 then M.try_call(VEHICLE, "SET_VEHICLE_MOD", vehicleHandle, i, maxMods - 1, false) end
            end
        else
            M.try_call(VEHICLE, "SET_VEHICLE_MOD_KIT", vehicleHandle, 0)
            if modsSection then
                for modIdStr, modValueStr in pairs(modsSection) do
                    local modId = M.safe_tonumber(modIdStr, nil)
                    local modValue = M.safe_tonumber(modValueStr, -1)
                    if modId ~= nil and modValue >= -1 then
                        M.try_call(VEHICLE, "SET_VEHICLE_MOD", vehicleHandle, modId, modValue, false)
                    end
                end
            else
                for key, value in pairs(mainVehicleSection) do
                    local modId = M.safe_tonumber(key, nil)
                    if modId ~= nil and modId >= 0 and modId <= 50 then
                        local modValue = M.safe_tonumber(value, -1)
                        if modValue >= -1 then
                            M.try_call(VEHICLE, "SET_VEHICLE_MOD", vehicleHandle, modId, modValue, false)
                        end
                    end
                end
            end
        end
        local togglesSection = iniData["Vehicle Toggles"]
        if togglesSection then
            for toggleIdStr, toggleValueStr in pairs(togglesSection) do
                local toggleId = M.safe_tonumber(toggleIdStr, nil)
                local toggleValue = M.to_boolean(toggleValueStr)
                if toggleId ~= nil then
                    M.try_call(VEHICLE, "SET_VEHICLE_TOGGLE_MOD", vehicleHandle, toggleId, toggleValue)
                end
            end
        end
        if spawnerSettings.vehicleGodMode then M.try_call(ENTITY, "SET_ENTITY_INVINCIBLE", vehicleHandle, true) end

        --this is so it networks and because setting it normally makes lights see through for some reason
        local opacityLevel = M.safe_tonumber(mainVehicleSection.OpacityLevel, nil)
        if opacityLevel ~= nil and opacityLevel == 0 then
            M.try_call(ENTITY, "SET_ENTITY_ALPHA", vehicleHandle, 0, false)
        end
        local isVisible = mainVehicleSection.IsVisible
        if isVisible ~= nil then
            M.try_call(ENTITY, "SET_ENTITY_VISIBLE", vehicleHandle, M.to_boolean(isVisible), false)
        end
        local mainVehicleSelfNumeration = M.safe_tonumber(mainVehicleSection.SelfNumeration, nil)
        local parentHandleMap = {}
        if mainVehicleSelfNumeration then
            parentHandleMap[mainVehicleSelfNumeration] = vehicleHandle
        else
            parentHandleMap["main_vehicle_placeholder"] = vehicleHandle
        end
        local originalInVehicleSetting = spawnerSettings.inVehicle
        spawnerSettings.inVehicle = false
        local parsedAttachments = M.parse_ini_attachments(iniData, mainVehicleSelfNumeration)
        if parsedAttachments and #parsedAttachments > 0 then
            local fallbackCoords = { x = spawnX, y = spawnY, z = spawnZ }
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, fallbackCoords, spawnerSettings.disableCollision, isPreview)
            for _, h in ipairs(createdAttachments) do pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) end
        end
        spawnerSettings.inVehicle = originalInVehicleSetting
        if isPreview then
            table.insert(previewEntities, vehicleHandle)
            for _, attachment in ipairs(createdAttachments) do
                table.insert(previewEntities, attachment)
            end
            -- All preview logic is now handled by M.startPreviewUpdater
            return
        end
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
            local attachmentCount = #vehicleData.attachments
            pcall(function()
                GUI.AddToast("Vehicle Spawned", "Spawned " .. filename .. " with " .. attachmentCount .. " attachment" .. (attachmentCount == 1 and "" or "s"), 5000, 0)
                print("Vehicle Spawned", "Spawned " .. filename .. " with " .. attachmentCount .. " attachment" .. (attachmentCount == 1 and "" or "s"))
            end)
        end
        if spawnerSettings.inVehicle and not isPreview then
            Script.Yield(500)
            local playerHandle = GTA.PointerToHandle(playerPed)
            if playerHandle and playerHandle > 0 then
                M.try_call(PED, "SET_PED_INTO_VEHICLE", playerHandle, vehicleHandle, -1)
            else
            end
        end
    end)
end

function M.spawnVehicleFromXML(filePath, isPreview)
    isPreview = isPreview or false
    Script.QueueJob(function()
        if not isPreview and currentPreviewFile and currentPreviewFile.path == filePath and #previewEntities > 0 then
            M.clearPreview()
            M.stopPreviewUpdater()
        end
        local vehicleHandle = nil
        local createdAttachments = {}
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Spawn Debug] Error: XML file does not exist:", filePath)
            return
        end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then
            M.debug_print("[Spawn Debug] Error: Failed to read XML file or content is empty:", filePath)
            return
        end
        local modelHashStr = M.get_xml_element_content(xmlContent, "ModelHash")
        if not modelHashStr then
            M.debug_print("[Spawn Debug] Error: 'ModelHash' not found in XML file:", filePath)
            return
        end
        local modelHash = M.safe_tonumber(modelHashStr, nil)
        if not modelHash then
            M.debug_print("[Spawn Debug] Error: Invalid 'ModelHash' value in XML file:", modelHashStr, "from:", filePath)
            return
        end
        local playerPed = GTA.GetLocalPed()
        if not playerPed then
            M.debug_print("[Spawn Debug] Error: Player ped not found.")
            return
        end
        local pos = playerPed.Position
        local heading = playerPed.Heading or 0.0
        local spawnX, spawnY, spawnZ
        if isPreview then
            local offset_distance = 15.0
            local offset_height = 0.5
            local rad_heading = math.rad(heading)
            spawnX = pos.x + (math.sin(rad_heading) * offset_distance)
            spawnY = pos.y + (math.cos(rad_heading) * offset_distance)
            spawnZ = pos.z + offset_height
        end
        if spawnerSettings.deleteOldVehicle and not isPreview then
            M.deleteAllSpawnedVehicles()
        end

        local playerID = PLAYER.PLAYER_ID()
        local forwardOffset = 5.0 -- Default forward offset

        -- Check if we should use the current vehicle instead of spawning a new one
        local applyToCurrentVehicle = spawnerSettings.onlyApplyAttachments and not isPreview
        
        if applyToCurrentVehicle then
            -- Get the player's current vehicle
            local playerPedHandle = GTA.PointerToHandle(playerPed)
            if playerPedHandle and playerPedHandle ~= 0 then
                local currentVehicle = nil
                pcall(function()
                    currentVehicle = PED.GET_VEHICLE_PED_IS_IN(playerPedHandle, false)
                end)
                if currentVehicle and currentVehicle ~= 0 then
                    vehicleHandle = currentVehicle
                    M.debug_print("[Apply Attachments] Using current vehicle: " .. tostring(vehicleHandle))
                else
                    GUI.AddToast("Apply Attachments", "You must be in a vehicle to apply attachments", 5000, 0)
                    return
                end
            else
                GUI.AddToast("Apply Attachments", "Could not get player ped handle", 5000, 0)
                return
            end
        elseif not isPreview then
            -- If it's a plane/heli, spawn it higher
            local vehhash = modelHash
            local isPlane = VEHICLE.IS_THIS_MODEL_A_PLANE(vehhash)
            local isHeli = VEHICLE.IS_THIS_MODEL_A_HELI(vehhash)
            if spawnerSettings.spawnPlaneInTheAir and (isPlane or isHeli) then
                -- GTA.SpawnVehicleForPlayer doesn't have a Z offset, so we'll spawn and then adjust
                local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
                if ok and h and h ~= 0 then vehicleHandle = h end
                if vehicleHandle and vehicleHandle ~= 0 then
                    local currentCoords = ENTITY.GET_ENTITY_COORDS(vehicleHandle, true)
                    ENTITY.SET_ENTITY_COORDS(vehicleHandle, currentCoords.x, currentCoords.y, currentCoords.z + 45.0, false, false, false, true)
                    VEHICLE.SET_HELI_BLADES_FULL_SPEED(vehicleHandle)
                    VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, true, true, true)
                    VEHICLE.SET_VEHICLE_FORWARD_SPEED(vehicleHandle, 100.0)
                end
            else
                local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
                if ok and h and h ~= 0 then vehicleHandle = h end
            end
        else -- isPreview
            local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end

        if isPreview and vehicleHandle and vehicleHandle ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_COLLISION(vehicleHandle, false, false) end)
        end

        if not vehicleHandle or vehicleHandle == 0 then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            Logger.LogError("[Spawn] Failed to spawn vehicle from '" .. fileName .. "' (hash: " .. tostring(modelHash) .. ")")
            return
        end
        local initialHandleMap = {}
        local initialHandleVal = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
        if initialHandleVal then initialHandleMap[initialHandleVal] = vehicleHandle end
        if initialHandleVal then  end
        local colors = M.parse_vehicle_colors(xmlContent)
        local mods = M.parse_vehicle_mods(xmlContent)
        local neons = M.parse_vehicle_neons(xmlContent)
        local vehicleProperties = M.get_xml_element(xmlContent, "VehicleProperties")
        if spawnerSettings.randomColor then
            M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_5", vehicleHandle, math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_6", vehicleHandle, math.random(0,255))
        else
            if colors then
                if colors.Primary ~= nil or colors.Secondary ~= nil then
                    M.try_call(VEHICLE, "SET_VEHICLE_COLOURS", vehicleHandle, colors.Primary or 0, colors.Secondary or 0)
                end

                if colors.IsPrimaryColourCustom then
                    M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", vehicleHandle, colors.Cust1_R, colors.Cust1_G, colors.Cust1_B)
                end

                if colors.IsSecondaryColourCustom then
                    M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", vehicleHandle, colors.Cust2_R, colors.Cust2_G, colors.Cust2_B)
                end

                if colors.Pearl ~= nil or colors.Rim ~= nil then
                    M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOURS", vehicleHandle, colors.Pearl or 0, colors.Rim or 0)
                end
                if colors.tyreSmoke_R and colors.tyreSmoke_G and colors.tyreSmoke_B then
                    M.try_call(VEHICLE, "SET_VEHICLE_TYRE_SMOKE_COLOR", vehicleHandle, colors.tyreSmoke_R, colors.tyreSmoke_G, colors.tyreSmoke_B)
                end
                if colors.LrInterior and colors.LrInterior > 0 then M.try_call(VEHICLE, "_SET_VEHICLE_INTERIOR_COLOR", vehicleHandle, colors.LrInterior) end
                if colors.LrDashboard and colors.LrDashboard > 0 then M.try_call(VEHICLE, "_SET_VEHICLE_DASHBOARD_COLOR", vehicleHandle, colors.LrDashboard) end
            end
        end
        if spawnerSettings.randomLivery then
            local liveryCount = M.try_call(VEHICLE, "GET_VEHICLE_LIVERY_COUNT", vehicleHandle)
            if liveryCount and liveryCount > 0 then
                local randomLivery = math.random(0, liveryCount - 1)
                M.try_call(VEHICLE, "SET_VEHICLE_LIVERY", vehicleHandle, randomLivery)
            else
            end
        elseif vehicleProperties then
            local livery = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "Livery"), nil)
            if livery and livery >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_LIVERY", vehicleHandle, livery) end
        end
        if spawnerSettings.upgradedVehicle then
            M.try_call(VEHICLE, "SET_VEHICLE_MOD_KIT", vehicleHandle, 0)
            for i = 0, 50 do
                local maxMods = M.try_call(VEHICLE, "GET_NUM_VEHICLE_MODS", vehicleHandle, i)
                if maxMods and maxMods > 0 then M.try_call(VEHICLE, "SET_VEHICLE_MOD", vehicleHandle, i, maxMods - 1, false) end
            end
        else
            for modId, modData in pairs(mods) do
                if modData and modData.mod and modData.mod >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_MOD", vehicleHandle, modId, modData.mod, false) end
            end
        end
        if neons then
            M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 0, neons.Left or false)
            M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 1, neons.Right or false)
            M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 2, neons.Front or false)
            M.try_call(VEHICLE, "_SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 3, neons.Back or false)
            M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 0, neons.Left or false)
            M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 1, neons.Right or false)
            M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 2, neons.Front or false)
            M.try_call(VEHICLE, "SET_VEHICLE_NEON_LIGHT_ENABLED", vehicleHandle, 3, neons.Back or false)
        end
        if vehicleProperties then
            local numberPlateText = M.get_xml_element_content(vehicleProperties, "NumberPlateText")
            if numberPlateText then M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT", vehicleHandle, numberPlateText) end
            local numberPlateIndex = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "NumberPlateIndex"), nil)
            if numberPlateIndex ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX", vehicleHandle, numberPlateIndex) end
            local wheelType = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "WheelType"), nil)
            if wheelType ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_WHEEL_TYPE", vehicleHandle, wheelType) end
            local windowTint = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "WindowTint"), nil)
            if windowTint ~= nil and windowTint >= 0 then M.try_call(VEHICLE, "SET_VEHICLE_WINDOW_TINT", vehicleHandle, windowTint) end
            local bulletProofTyres = M.get_xml_element_content(vehicleProperties, "BulletProofTyres")
            if bulletProofTyres ~= nil then
                bulletProofTyres = M.to_boolean(bulletProofTyres)
                M.try_call(VEHICLE, "SET_VEHICLE_TYRES_CAN_BURST", vehicleHandle, not bulletProofTyres)
            end
            local dirtLevel = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "DirtLevel"), nil)
            if dirtLevel ~= nil then M.try_call(VEHICLE, "SET_VEHICLE_DIRT_LEVEL", vehicleHandle, dirtLevel) end
            local engineOn = M.get_xml_element_content(vehicleProperties, "EngineOn")
            if engineOn ~= nil then engineOn = M.to_boolean(engineOn) if spawnerSettings.vehicleEngineOn and engineOn then M.try_call(VEHICLE, "SET_VEHICLE_ENGINE_ON", vehicleHandle, true, true, false) end end
            if spawnerSettings.radioOff then M.try_call(AUDIO, "SET_VEHICLE_RADIO_ENABLED", vehicleHandle, false) end
        end
        if spawnerSettings.vehicleGodMode then M.try_call(ENTITY, "SET_ENTITY_INVINCIBLE", vehicleHandle, true) end
        local opacityLevel = M.safe_tonumber(M.get_xml_element_content(xmlContent, "OpacityLevel"), nil)
        if opacityLevel ~= nil and opacityLevel == 0 then
            M.try_call(ENTITY, "SET_ENTITY_ALPHA", vehicleHandle, 0, false)
        end
        local isVisible = M.get_xml_element_content(xmlContent, "IsVisible")
        if isVisible ~= nil then
            M.try_call(ENTITY, "SET_ENTITY_VISIBLE", vehicleHandle, M.to_boolean(isVisible), false)
        end
        
        -- Parse IsDriverVisible for player invisibility when driving
        local isDriverVisible = M.get_xml_element_content(xmlContent, "IsDriverVisible")
        local shouldHideDriver = false
        if isDriverVisible ~= nil then
            shouldHideDriver = not M.to_boolean(isDriverVisible)
        end
        
        local originalInVehicleSetting = spawnerSettings.inVehicle
        spawnerSettings.inVehicle = false
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        if (not parsedAttachments or #parsedAttachments == 0) then
            parsedAttachments = M.parse_outfit_attachments(xmlContent)
            if parsedAttachments and #parsedAttachments > 0 then
            end
        end
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            if initialHandleVal then parentHandleMap[initialHandleVal] = vehicleHandle end
            local fallbackCoords = { x = spawnX, y = spawnY, z = spawnZ }
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, fallbackCoords, spawnerSettings.disableCollision, isPreview)
            for _, h in ipairs(createdAttachments) do pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) end
        end
        spawnerSettings.inVehicle = originalInVehicleSetting
        if isPreview then
            table.insert(previewEntities, vehicleHandle)
            for _, attachment in ipairs(createdAttachments) do
                table.insert(previewEntities, attachment)
            end
            -- All preview logic is now handled by M.startPreviewUpdater
            return
        end
        local isAttackerVehicle = (filePath == currentSelectedVehicleXml and playerId ~= nil)
        if not isAttackerVehicle and spawnerSettings.inVehicle then
            Script.Yield(500)
            local playerHandle = GTA.PointerToHandle(playerPed)
            if playerHandle and playerHandle > 0 then
                M.try_call(PED, "SET_PED_INTO_VEHICLE", playerHandle, vehicleHandle, -1)
                
                -- If IsDriverVisible is false, make the player invisible
                if shouldHideDriver then
                    M.debug_print("[Spawn] IsDriverVisible is false, hiding player")
                    pcall(function()
                        ENTITY.SET_ENTITY_VISIBLE(playerHandle, false, false)
                    end)
                    
                    -- Start a background job to restore visibility when player exits vehicle
                    local vehHandle = vehicleHandle
                    local pedHandle = playerHandle
                    Script.QueueJob(function()
                        print("[Driver Visibility] Starting vehicle exit monitor for handle: " .. tostring(vehHandle))
                        -- Wait for the player to exit the vehicle
                        while true do
                            Script.Yield(250)
                            
                            -- Check if vehicle still exists
                            local vehExists = false
                            pcall(function()
                                vehExists = ENTITY.DOES_ENTITY_EXIST(vehHandle)
                            end)
                            
                            if not vehExists then
                                print("[Driver Visibility] Vehicle no longer exists, restoring visibility")
                                pcall(function()
                                    ENTITY.SET_ENTITY_VISIBLE(pedHandle, true, false)
                                end)
                                break
                            end
                            
                            -- Check if player is in this specific vehicle using IS_PED_IN_VEHICLE
                            local isInVehicle = false
                            pcall(function()
                                isInVehicle = PED.IS_PED_IN_VEHICLE(pedHandle, vehHandle, false)
                            end)
                            
                            print("[Driver Visibility] Checking: isInVehicle=" .. tostring(isInVehicle))
                            
                            -- If player is no longer in the vehicle, restore visibility
                            if not isInVehicle then
                                print("[Driver Visibility] Player exited vehicle, restoring visibility")
                                pcall(function()
                                    ENTITY.SET_ENTITY_VISIBLE(pedHandle, true, false)
                                end)
                                break
                            end
                        end
                        print("[Driver Visibility] Monitor ended")
                    end)
                end
            end
        end
        local vehicleData = {
            vehicle = nil,
            attachments = {},
            filePath = filePath
        }
        if vehicleHandle and vehicleHandle ~= 0 and ENTITY and ENTITY.DOES_ENTITY_EXIST(vehicleHandle) then
            vehicleData.vehicle = vehicleHandle
        else
        end
        if createdAttachments then
            for _, attachmentHandle in ipairs(createdAttachments) do
                if attachmentHandle and attachmentHandle ~= 0 and ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                    table.insert(vehicleData.attachments, attachmentHandle)
                else
                    M.debug_print("[Spawn Debug] Warning: Attachment handle invalid or does not exist:", tostring(attachmentHandle))
                end
            end
        end
        if vehicleData.vehicle or #vehicleData.attachments > 0 then
            table.insert(spawnedVehicles, vehicleData)
            local filename = M.get_filename_from_path(filePath)
            local attachmentCount = #vehicleData.attachments
            pcall(function()
                GUI.AddToast("Vehicle Spawned", filename .. " with " .. attachmentCount .. " attachment" .. (attachmentCount == 1 and "" or "s"), 5000, 0)
                print("Vehicle Spawned", filename .. " with " .. attachmentCount .. " attachment" .. (attachmentCount == 1 and "" or "s"))
            end)
        else
        end
    end)
end

function M.getFirstVehicleXml()
    local files = FileMgr.FindFiles(xmlVehiclesFolder, ".xml", true)
    if not files or #files == 0 then return nil end
    return files[1]
end

function M.spawnMenyooAttackerFromXML(filePath, targetPlayerIndex)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    Script.QueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Spawn Debug] Error: XML file does not exist for attacker:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then
            M.debug_print("[Spawn Debug] Error: Failed to read XML file or content is empty for attacker:", filePath)
            return
        end
        local modelHashStr = M.get_xml_element_content(xmlContent, "ModelHash")
        if not modelHashStr then
            M.debug_print("[Spawn Debug] Error: 'ModelHash' not found in XML file for attacker:", filePath)
            return
        end
        local modelHash = M.safe_tonumber(modelHashStr, nil)
        if not modelHash then
            M.debug_print("[Spawn Debug] Error: Invalid 'ModelHash' value in XML file for attacker:", modelHashStr, "from:", filePath)
            return
        end
        local targetPed = nil
        if targetPlayerIndex ~= nil then
            pcall(function() targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerIndex) end)
        end
        if not targetPed or targetPed == 0 then
            targetPed = GTA.GetLocalPed()
        end
        if not targetPed or targetPed == 0 then
            M.debug_print("[Spawn Debug] Error: No target ped available for attacker spawn.")
            return
        end
        local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
        pcall(function()
            local off = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, -10.0, 0)
            spawnCoords.x = off.x or off[1] or 0.0
            spawnCoords.y = off.y or off[2] or 0.0
            spawnCoords.z = off.z or off[3] or 0.0
            local foundGround, gz = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
            if foundGround then spawnCoords.z = gz end
        end)
        M.request_model_load(modelHash)
        local vehicleHandle = nil
        local ok, h = pcall(function() return GTA.SpawnVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
        if ok and h and h ~= 0 then vehicleHandle = h end
        if not vehicleHandle and entities and entities.create_vehicle then
            local ok, h = pcall(function() return entities.create_vehicle(modelHash, spawnCoords, 0) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end
        if not vehicleHandle or vehicleHandle == 0 then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            Logger.LogError("[Spawn] Failed to spawn attacker vehicle from '" .. fileName .. "' (hash: " .. tostring(modelHash) .. ")")
            return
        end
        local attackerModel = M.safe_tonumber(M.get_xml_element_content(xmlContent, "AttackerModelHash"), 71929310)
        M.request_model_load(attackerModel)
        local attacker = nil
        local ok2, h2 = pcall(function() return GTA.CreatePed(attackerModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
        if ok2 and h2 and h2 ~= 0 then attacker = h2 end
        if not attacker or attacker == 0 then
            Logger.LogError("[Spawn] Failed to spawn attacker ped (hash: " .. tostring(attackerModel) .. ")")
            return
        end
        pcall(function()
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
        end)
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            local initialHandleVal = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
            if initialHandleVal then parentHandleMap[initialHandleVal] = vehicleHandle end
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) end
        end
        local attachments = { attacker }
        for _, h in ipairs(createdAttachments) do
            table.insert(attachments, h)
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        if #createdAttachments > 0 then
        end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnMenyooAttackerFromINI(filePath, targetPlayerIndex)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    Script.QueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Spawn Debug] Error: INI file does not exist for attacker:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local iniData = M.parse_ini_file(filePath)
        if not iniData then
            M.debug_print("[Spawn Debug] Error: Failed to parse INI file for attacker:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local mainVehicleSection = iniData.Vehicle or iniData.Vehicle0
        if not mainVehicleSection then
            M.debug_print("[Spawn Debug] Error: Main vehicle section ('Vehicle' or 'Vehicle0') not found in INI attacker file:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local modelHashStr = mainVehicleSection.Hash or mainVehicleSection.ModelHash or mainVehicleSection.Model or mainVehicleSection.model
        if not modelHashStr then
            M.debug_print("[Spawn Debug] Error: Vehicle model hash (Hash, ModelHash, Model, or model) not found in main vehicle section of INI attacker file:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local modelHash = M.safe_tonumber(modelHashStr, nil)
        if not modelHash then
            M.debug_print("[Spawn Debug] Error: Invalid vehicle model hash value in INI attacker file:", modelHashStr, "from:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local targetPed = nil
        if targetPlayerIndex ~= nil then
            pcall(function() targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerIndex) end)
        end
        if not targetPed or targetPed == 0 then
            targetPed = GTA.GetLocalPed()
        end
        if not targetPed or targetPed == 0 then
            M.debug_print("[Spawn Debug] Error: No target ped available for attacker spawn.")
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
        pcall(function()
            local off = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, -10.0, 0)
            spawnCoords.x = off.x or off[1] or 0.0
            spawnCoords.y = off.y or off[2] or 0.0
            spawnCoords.z = off.z or off[3] or 0.0
            local foundGround, gz = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
            if foundGround then spawnCoords.z = gz end
        end)
        M.request_model_load(modelHash)
        local vehicleHandle = nil
        local ok, h = pcall(function() return GTA.SpawnVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
        if ok and h and h ~= 0 then vehicleHandle = h end
        if not vehicleHandle and entities and entities.create_vehicle then
            local ok, h = pcall(function() return entities.create_vehicle(modelHash, spawnCoords, 0) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end
        if not vehicleHandle or vehicleHandle == 0 then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            Logger.LogError("[Spawn] Failed to spawn attacker vehicle from '" .. fileName .. "' (hash: " .. tostring(modelHash) .. ")")
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        local attackerModel = M.safe_tonumber(mainVehicleSection.AttackerModelHash, 71929310)
        M.request_model_load(attackerModel)
        local attacker = nil
        local ok2, h2 = pcall(function() return GTA.CreatePed(attackerModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
        if ok2 and h2 and h2 ~= 0 then attacker = h2 end
        if not attacker or attacker == 0 then
            Logger.LogError("[Spawn] Failed to spawn attacker ped (hash: " .. tostring(attackerModel) .. ")")
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        pcall(function()
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
        end)
        local mainVehicleSelfNumeration = M.safe_tonumber(mainVehicleSection.SelfNumeration, nil)
        local parentHandleMap = {}
        if mainVehicleSelfNumeration then
            parentHandleMap[mainVehicleSelfNumeration] = vehicleHandle
        else
            parentHandleMap["main_vehicle_placeholder"] = vehicleHandle
        end
        local parsedAttachments = M.parse_ini_attachments(iniData, mainVehicleSelfNumeration)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) end
        end
        local attachments = { attacker }
        for _, h in ipairs(createdAttachments) do
            table.insert(attachments, h)
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnMenyooAttackerFromJSON(filePath, targetPlayerIndex)
    print("[JSON Attacker] Function called with file:", filePath, "target player:", tostring(targetPlayerIndex))
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    Script.QueueJob(function()
        print("[JSON Attacker] Inside Script.QueueJob")
        
        if not filePath or not FileMgr.DoesFileExist(filePath) then
            print("[JSON Attacker] Error: File does not exist:", filePath)
            M.debug_print("[Spawn Debug] Error: JSON file does not exist for attacker:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        
        print("[JSON Attacker] Reading file...")
        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            print("[JSON Attacker] Error: Failed to read file or content empty")
            M.debug_print("[Spawn Debug] Error: Failed to read JSON file or content is empty for attacker:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        
        print("[JSON Attacker] Parsing JSON...")
        local jsonData
        local parseSuccess, parseResult = pcall(function()
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
        
        if not parseSuccess or not parseResult then
            print("[JSON Attacker] Parse failed:", tostring(parseResult))
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        
        jsonData = parseResult
        print("[JSON Attacker] Parse successful!")
        
        -- Check if it's a vehicle
        if jsonData.type ~= "VEHICLE" then
            print("[JSON Attacker] Error: Not a VEHICLE type, got:", tostring(jsonData.type))
            M.debug_print("[Spawn Debug] Error: JSON is not a VEHICLE type for attacker, got:", tostring(jsonData.type))
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        
        local modelHash = jsonData.hash or jsonData.model
        print("[JSON Attacker] Model hash:", tostring(modelHash))
        if not modelHash or modelHash == 0 then
            print("[JSON Attacker] Error: Invalid model hash")
            M.debug_print("[Spawn Debug] Error: Invalid model hash for JSON attacker")
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        
        -- Get target ped
        print("[JSON Attacker] Getting target ped...")
        local targetPed = nil
        if targetPlayerIndex ~= nil then
            pcall(function() targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerIndex) end)
        end
        if not targetPed or targetPed == 0 then
            targetPed = GTA.GetLocalPed()
        end
        if not targetPed or targetPed == 0 then
            print("[JSON Attacker] Error: No target ped available")
            M.debug_print("[Spawn Debug] Error: No target ped available for attacker spawn.")
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        
        -- Calculate spawn coordinates (behind target)
        M.debug_print("[JSON Attacker] Calculating spawn position...")
        local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
        pcall(function()
            local off = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, -10.0, 0)
            spawnCoords.x = off.x or off[1] or 0.0
            spawnCoords.y = off.y or off[2] or 0.0
            spawnCoords.z = off.z or off[3] or 0.0
            local foundGround, gz = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
            if foundGround then spawnCoords.z = gz end
        end)
        
        -- Spawn the vehicle
        M.debug_print("[JSON Attacker] Spawning vehicle...")
        M.request_model_load(modelHash)
        local vehicleHandle = nil
        local ok, h = pcall(function() return GTA.SpawnVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
        if ok and h and h ~= 0 then vehicleHandle = h end
        if not vehicleHandle and entities and entities.create_vehicle then
            local ok, h = pcall(function() return entities.create_vehicle(modelHash, spawnCoords, 0) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end
        if not vehicleHandle or vehicleHandle == 0 then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            Logger.LogError("[Spawn] Failed to spawn attacker vehicle from '" .. fileName .. "' (hash: " .. tostring(modelHash) .. ")")
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        M.debug_print("[JSON Attacker] Vehicle spawned, handle:", vehicleHandle)
        
        -- Spawn attacker ped
        M.debug_print("[JSON Attacker] Spawning attacker ped...")
        local attackerModel = 71929310  -- Default attacker model
        M.request_model_load(attackerModel)
        local attacker = nil
        local ok2, h2 = pcall(function() return GTA.CreatePed(attackerModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
        if ok2 and h2 and h2 ~= 0 then attacker = h2 end
        if not attacker or attacker == 0 then
            Logger.LogError("[Spawn] Failed to spawn attacker ped (hash: " .. tostring(attackerModel) .. ")")
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        M.debug_print("[JSON Attacker] Attacker ped spawned, handle:", attacker)
        
        -- Configure attacker
        M.debug_print("[JSON Attacker] Configuring attacker...")
        pcall(function()
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
        end)
        
        -- Spawn and attach children objects
        M.debug_print("[JSON Attacker] Spawning attachments...")
        local attachedObjects = {}
        if jsonData.children and #jsonData.children > 0 then
            M.debug_print("[JSON Attacker] Found", #jsonData.children, "children to spawn")
            
            for i, child in ipairs(jsonData.children) do
                local childModel = child.hash or child.model
                if childModel then
                    M.request_model_load(childModel)
                    Script.Yield(100)
                    
                    local objectHandle
                    if child.type == "VEHICLE" then
                        local ok2, h2 = pcall(function()
                            return GTA.SpawnVehicle(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
                        end)
                        if ok2 and h2 and h2 ~= 0 then
                            objectHandle = h2
                        end
                    else
                        local ok2, h2 = pcall(function()
                            return GTA.CreateObject(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true)
                        end)
                        if ok2 and h2 and h2 ~= 0 then
                            objectHandle = h2
                        end
                    end
                    
                    if objectHandle and objectHandle ~= 0 then
                        print("[JSON Attacker] Attachment", i, "spawned, handle:", objectHandle)
                        
                        -- Apply options
                        if child.options then
                            local opts = child.options
                            if opts.is_visible ~= nil then
                                pcall(function() ENTITY.SET_ENTITY_VISIBLE(objectHandle, opts.is_visible, false) end)
                            end
                            if opts.has_collision ~= nil then
                                pcall(function() ENTITY.SET_ENTITY_COLLISION(objectHandle, opts.has_collision, false) end)
                            end
                            if opts.is_invincible ~= nil then
                                pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(objectHandle, opts.is_invincible) end)
                            else
                                pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(objectHandle, true) end)
                            end
                        end
                        
                        -- Attach to vehicle
                        pcall(function()
                            ENTITY.ATTACH_ENTITY_TO_ENTITY(
                                objectHandle, vehicleHandle, 0,
                                child.offset and child.offset.x or 0,
                                child.offset and child.offset.y or 0,
                                child.offset and child.offset.z or 0,
                                child.rotation and child.rotation.x or 0,
                                child.rotation and child.rotation.y or 0,
                                child.rotation and child.rotation.z or 0,
                                false, false, false, false, 2, true
                            )
                        end)
                        print("[JSON Attacker] Attached child", i)
                        
                        table.insert(attachedObjects, objectHandle)
                    end
                end
            end
        end
        
        print("[JSON Attacker] Total attachments spawned:", #attachedObjects)
        
        -- Track spawned vehicle
        local attachments = { attacker }
        for _, h in ipairs(attachedObjects) do
            table.insert(attachments, h)
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        M.debug_print("[JSON Attacker] Spawn complete!")
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnMapV1Networked(filePath, placements)
    local carattach_hash = Utils.Joaat("lazer")
    M.request_model_load(carattach_hash)
    local carattach = GTA.SpawnVehicle(carattach_hash, 0.0, 0.0, 0.0, 0.0, true, true)
    if not carattach or carattach == 0 then
        Logger.LogError("[Spawn] Failed to spawn base vehicle for Network Maps V1")
        pcall(function() GUI.AddToast("Spawn Error", "Failed to spawn base vehicle for Network Maps V1.", 5000, 1) end)
        return nil, 0
    end
    pcall(function()
        ENTITY.FREEZE_ENTITY_POSITION(carattach, true)
        ENTITY.SET_ENTITY_COLLISION(carattach, false, false)
        ENTITY.SET_ENTITY_VISIBLE(carattach, false, false)
        ENTITY.SET_ENTITY_LOD_DIST(carattach, 100000)
        constructor_lib.make_entity_networked({handle = carattach})
    end)
    local mapV1Entities = {}
    table.insert(mapV1Entities, carattach)
    local spawnCount = 1
    local parentHandleMap = {}
    for _, placement in ipairs(placements) do
        local model = placement.ModelHash or placement.HashName
        if not model then
            goto continue_creation
        end
        local entityHandle = M.create_by_type(model, placement.Type, {x = 0.0, y = 0.0, z = 0.0})
        local placementName = placement.HashName or tostring(model) or "Unknown"
        local typeNames = {["1"] = "Ped", ["2"] = "Vehicle", ["3"] = "Object", [1] = "Ped", [2] = "Vehicle", [3] = "Object"}
        local typeName = typeNames[placement.Type] or tostring(placement.Type)
        if not entityHandle or entityHandle == 0 then
            Logger.LogError("[Spawn] Failed to create '" .. placementName .. "' [" .. typeName .. "] (hash: " .. tostring(model) .. ")")
            goto continue_creation
        end
        if placement.InitialHandle then
            parentHandleMap[M.safe_tonumber(placement.InitialHandle)] = entityHandle
        end
        placement.runtimeHandle = entityHandle
        table.insert(mapV1Entities, entityHandle)
        spawnCount = spawnCount + 1
        ::continue_creation::
    end
    for _, placement in ipairs(placements) do
        if not placement.runtimeHandle then goto continue_placement end
        local entityHandle = placement.runtimeHandle
        local isAttachedToOtherObject = false
        if placement.Attachment and placement.Attachment.isAttached then
            local parentHandle = parentHandleMap[M.safe_tonumber(placement.Attachment.AttachedTo)]
            if parentHandle then
                isAttachedToOtherObject = true
                pcall(function()
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(
                        entityHandle,
                        parentHandle,
                        placement.Attachment.BoneIndex or 0,
                        placement.Attachment.X or 0.0, placement.Attachment.Y or 0.0, placement.Attachment.Z or 0.0,
                        placement.Attachment.Pitch or 0.0, placement.Attachment.Roll or 0.0, placement.Attachment.Yaw or 0.0,
                        false, false, true, false, 2, true
                    )
                    M.debug_print("[Spawn Debug] Attached entity", tostring(entityHandle), "to parent object", tostring(parentHandle))
                end)
            end
        end
        if not isAttachedToOtherObject then
            local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
            local rotX, rotY, rotZ = 0.0, 0.0, 0.0
            if placement.PositionRotation then
                spawnCoords.x = placement.PositionRotation.X or 0.0
                spawnCoords.y = placement.PositionRotation.Y or 0.0
                spawnCoords.z = placement.PositionRotation.Z or 0.0
                rotX = placement.PositionRotation.Pitch or 0.0
                rotY = placement.PositionRotation.Roll or 0.0
                rotZ = placement.PositionRotation.Yaw or 0.0
            end
            pcall(function()
                ENTITY.ATTACH_ENTITY_TO_ENTITY(
                    entityHandle,
                    carattach,
                    0,
                    spawnCoords.x, spawnCoords.y, spawnCoords.z,
                    rotX, rotY, rotZ,
                    false, false, true, false, 2, true
                )
                M.debug_print("[Spawn Debug] Attached entity", tostring(entityHandle), "to base vehicle", tostring(carattach))
            end)
        end
        pcall(function()
            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entityHandle, true, false)
            ENTITY.SET_ENTITY_LOD_DIST(entityHandle, 100000)
            constructor_lib.make_entity_networked({handle = entityHandle})
        end)
        if placement.IsInvincible then pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, true) end) end
        if placement.IsVisible ~= nil then pcall(function() ENTITY.SET_ENTITY_VISIBLE(entityHandle, placement.IsVisible, false) end) end
        if placement.OpacityLevel ~= nil then
            local opacity = M.safe_tonumber(placement.OpacityLevel, 255)
            if opacity == 0 then
                pcall(function() ENTITY.SET_ENTITY_ALPHA(entityHandle, 0, false) end)
            end
        end
        if placement.HasGravity ~= nil then pcall(function() ENTITY.SET_ENTITY_HAS_GRAVITY(entityHandle, placement.HasGravity) end) end
        if placement.Health ~= nil then local health = M.safe_tonumber(placement.Health, 1000) pcall(function() ENTITY.SET_ENTITY_HEALTH(entityHandle, health, 0) end) end
        if placement.MaxHealth ~= nil then local maxHealth = M.safe_tonumber(placement.MaxHealth, 1000) pcall(function() ENTITY.SET_ENTITY_MAX_HEALTH(entityHandle, maxHealth) end) end
        if placement.IsBulletProof then pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, true, false, false, false, false, false, false, false) end) end
        if placement.IsCollisionProof then pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, true, false, false, false, false, false, false) end) end
        if placement.IsExplosionProof then pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, true, false, false, false, false, false) end) end
        if placement.IsFireProof then pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, true, false, false, false, false) end) end
        if placement.IsMeleeProof then pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, false, true, false, false, false) end) end
        if placement.FrozenPos then pcall(function() ENTITY.FREEZE_ENTITY_POSITION(entityHandle, true) end) end
        if placement.ObjectProperties then
            for propName, propValue in pairs(placement.ObjectProperties) do
                if propName == "TextureVariation" then
                    local texture = M.safe_tonumber(propValue, 0)
                    pcall(function() OBJECT.SET_OBJECT_TEXTURE_VARIATION(entityHandle, texture) end)
                end
            end
        end
        ::continue_placement::
    end
    return mapV1Entities, spawnCount
end

function M.spawnMapFromXML(filePath)
    Script.QueueJob(function()
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Spawn Debug] Error: XML map file does not exist:", filePath)
            return
        end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then
            M.debug_print("[Spawn Debug] Error: Failed to read XML map file or content is empty:", filePath)
            return
        end
        local placements, markers = M.parse_map_placements(xmlContent)
        if (not placements or #placements == 0) and (not markers or #markers == 0) then
            return
        end
        if spawnerSettings.deleteOldMap then
            M.deleteAllSpawnedMaps()
        end
        local createdEntities = {}
        local spawnCount = 0
        local totalPlacements = #placements
        local filename = M.get_filename_from_path(filePath)
        local refCoords = nil
        local refCoordsElement = M.get_xml_element(xmlContent, "ReferenceCoords")
        if refCoordsElement then
            refCoords = {}
            refCoords.x = M.safe_tonumber(M.get_xml_element_content(refCoordsElement, "X"), 0.0)
            refCoords.y = M.safe_tonumber(M.get_xml_element_content(refCoordsElement, "Y"), 0.0)
            refCoords.z = M.safe_tonumber(M.get_xml_element_content(refCoordsElement, "Z"), 0.0)
        end
        -- Progress tracking for maps over 200 entities
        local progressShown = { [25] = false, [50] = false, [75] = false }
        if spawnerSettings.networkMapsV1Enabled then
            createdEntities, spawnCount = M.spawnMapV1Networked(filePath, placements)
        else
            for _, placement in ipairs(placements) do
                local model = placement.ModelHash or placement.HashName
                if not model then
                    goto continue_v2
                end
                local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
                if placement.PositionRotation then
                    spawnCoords.x = placement.PositionRotation.X or 0.0
                    spawnCoords.y = placement.PositionRotation.Y or 0.0
                    spawnCoords.z = placement.PositionRotation.Z or 0.0
                end
                local entityHandle = M.create_by_type(model, placement.Type, spawnCoords)
                local placementName = placement.HashName or tostring(model) or "Unknown"
                local typeNames = {["1"] = "Ped", ["2"] = "Vehicle", ["3"] = "Object", [1] = "Ped", [2] = "Vehicle", [3] = "Object"}
                local typeName = typeNames[placement.Type] or tostring(placement.Type)
                if not entityHandle or entityHandle == 0 then
                    Logger.LogError("[Spawn] Failed to create '" .. placementName .. "' [" .. typeName .. "] (hash: " .. tostring(model) .. ")")
                    goto continue_v2
                end
                pcall(function()
                    ENTITY.SET_ENTITY_COORDS(entityHandle, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
                end)
                table.insert(createdEntities, entityHandle)
                spawnCount = spawnCount + 1
                -- Show progress toasts at 25%, 50%, 75% for maps over 200 entities
                if totalPlacements > 200 then
                    local percentComplete = math.floor((spawnCount / totalPlacements) * 100)
                    if percentComplete >= 25 and not progressShown[25] then
                        progressShown[25] = true
                        pcall(function() GUI.AddToast("Spawning Map", "25% completed (" .. spawnCount .. "/" .. totalPlacements .. ")", 2000, 0) end)
                    elseif percentComplete >= 50 and not progressShown[50] then
                        progressShown[50] = true
                        pcall(function() GUI.AddToast("Spawning Map", "50% completed (" .. spawnCount .. "/" .. totalPlacements .. ")", 2000, 0) end)
                    elseif percentComplete >= 75 and not progressShown[75] then
                        progressShown[75] = true
                        pcall(function() GUI.AddToast("Spawning Map", "75% completed (" .. spawnCount .. "/" .. totalPlacements .. ")", 2000, 0) end)
                    end
                end
                if spawnerSettings.networkMapsV2Enabled then
                    pcall(function()
                        constructor_lib.make_entity_networked({handle = entityHandle})
                    end)
                end
                if placement.IsInvincible then
                    pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, true) end)
                end
                if placement.IsVisible ~= nil then
                    pcall(function() ENTITY.SET_ENTITY_VISIBLE(entityHandle, placement.IsVisible, false) end)
                end
                if placement.OpacityLevel ~= nil then
                    local opacity = M.safe_tonumber(placement.OpacityLevel, 255)
                    if opacity == 0 then
                        pcall(function() ENTITY.SET_ENTITY_ALPHA(entityHandle, 0, false) end)
                    end
                end
                if placement.HasGravity ~= nil then
                    pcall(function() ENTITY.SET_ENTITY_HAS_GRAVITY(entityHandle, placement.HasGravity) end)
                end
                if placement.Health ~= nil then
                    local health = M.safe_tonumber(placement.Health, 1000)
                    pcall(function() ENTITY.SET_ENTITY_HEALTH(entityHandle, health, 0) end)
                end
                if placement.MaxHealth ~= nil then
                    local maxHealth = M.safe_tonumber(placement.MaxHealth, 1000)
                    pcall(function() ENTITY.SET_ENTITY_MAX_HEALTH(entityHandle, maxHealth) end)
                end
                if placement.IsBulletProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, true, false, false, false, false, false, false, false) end)
                end
                if placement.IsCollisionProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, true, false, false, false, false, false, false) end)
                end
                if placement.IsExplosionProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, true, false, false, false, false, false) end)
                end
                if placement.IsFireProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, true, false, false, false, false) end)
                end
                if placement.IsMeleeProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, false, true, false, false, false) end)
                end
                if placement.PositionRotation then
                    local rotX = placement.PositionRotation.Pitch or 0.0
                    local rotY = placement.PositionRotation.Roll or 0.0
                    local rotZ = placement.PositionRotation.Yaw or 0.0
                    pcall(function() ENTITY.SET_ENTITY_ROTATION(entityHandle, rotX, rotY, rotZ, 2) end)
                    if placement.FrozenPos then
                        pcall(function() ENTITY.FREEZE_ENTITY_POSITION(entityHandle, true) end)
                    end
                end
                if placement.ObjectProperties then
                    for propName, propValue in pairs(placement.ObjectProperties) do
                        if propName == "TextureVariation" then
                            local texture = M.safe_tonumber(propValue, 0)
                            pcall(function() OBJECT.SET_OBJECT_TEXTURE_VARIATION(entityHandle, texture) end)
                        end
                    end
                end
                ::continue_v2::
            end
        end
        if refCoords and spawnerSettings.teleportToMap then
            local playerPed = GTA.GetLocalPed()
            if playerPed then
                pcall(function()
                    local playerHandle = GTA.PointerToHandle(playerPed)
                    if playerHandle and playerHandle > 0 then
                        ENTITY.SET_ENTITY_COORDS(playerHandle, refCoords.x, refCoords.y, refCoords.z, false, false, false, true)
                    end
                end)
            end
        end
        if markers and #markers > 0 then
            Script.QueueJob(function()
                while true do
                    local isMapActive = false
                    for _, map in ipairs(spawnedMaps) do
                        if map.entities == createdEntities then
                            isMapActive = true
                            break
                        end
                    end
                    
                    if not isMapActive then
                        break
                    end
                    
                    for _, marker in ipairs(markers) do
                         local r = marker.Colour and marker.Colour.r or 255
                         local g = marker.Colour and marker.Colour.g or 255
                         local b = marker.Colour and marker.Colour.b or 255
                         local a = marker.Colour and marker.Colour.a or 255
                         
                         GRAPHICS.DRAW_MARKER(
                             marker.Type,
                             marker.X or 0.0, marker.Y or 0.0, marker.Z or 0.0,
                             0.0, 0.0, 0.0,
                             marker.RotX or 0.0, marker.RotY or 0.0, marker.RotZ or 0.0,
                             marker.Scale, marker.Scale, marker.Scale,
                             r, g, b, a,
                             false, false, 2, marker.RotateContinuously, nil, nil, false
                         )
                    end
                    Script.Yield(0)
                end
            end)
        end

        if spawnCount > 0 or (markers and #markers > 0) then
            local mapData = {
                entities = createdEntities,
                markers = markers,
                filePath = filePath,
                refCoords = refCoords
            }
            table.insert(spawnedMaps, mapData)
            pcall(function()
                local markerCount = (markers and #markers or 0)
                local toastMsg = filename .. " (" .. spawnCount .. " entities, " .. markerCount .. " markers)"
                GUI.AddToast("Map Spawned", toastMsg, 5000, 0)
                print("Map Spawned", toastMsg)
            end)
        else
        end
        if spawnerSettings.networkMapsV1Enabled and spawnerSettings.spawnIn000Vehicle then
            local playerPed = PLAYER.PLAYER_PED_ID()
            local baseVehicleHandle = createdEntities[1]
            if playerPed and baseVehicleHandle and ENTITY.DOES_ENTITY_EXIST(baseVehicleHandle) then
                Script.Yield(100)
                PED.SET_PED_INTO_VEHICLE(playerPed, baseVehicleHandle, -1)
            end
        end
        local allEntitiesCreated = false
        local startTime = Time.Get()
        while not allEntitiesCreated and (Time.Get() - startTime) < 10 do
            allEntitiesCreated = true
            for _, entityHandle in ipairs(createdEntities) do
                if not ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                    allEntitiesCreated = false
                    break
                end
            end
            if not allEntitiesCreated then
                Script.Yield(100)
            end
        end
        if allEntitiesCreated then
        else
        end
    end)
end

function M.spawnOutfitFromXML(filePath, isPreview)
    isPreview = isPreview or false
    Script.QueueJob(function()
        if not isPreview and currentPreviewFile and currentPreviewFile.path == filePath and #previewEntities > 0 then
            local entitiesToFinalize = {}
            for _, entity in ipairs(previewEntities) do
                table.insert(entitiesToFinalize, entity)
            end
            M.finalizePreviewVehicle(entitiesToFinalize)
            local spawnedPed = entitiesToFinalize[1]
            local createdAttachments = {}
            for i = 2, #entitiesToFinalize do
                table.insert(createdAttachments, entitiesToFinalize[i])
            end
            pcall(function()
                if PLAYER and PLAYER.PLAYER_ID and PLAYER.CHANGE_PLAYER_PED then
                    local pid = PLAYER.PLAYER_ID()
                    if pid then
                        PLAYER.CHANGE_PLAYER_PED(pid, spawnedPed, true, true)
                    end
                end
            end)
            local outfitRecord = { attachments = createdAttachments, spawnedPed = spawnedPed, filePath = filePath }
            table.insert(spawnedOutfits, outfitRecord)
            previewEntities = {}
            currentPreviewFile = nil
            return
        end
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Spawn Debug] Error: XML outfit file does not exist:", filePath)
            return
        end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then
            M.debug_print("[Spawn Debug] Error: Failed to read XML outfit file or content is empty:", filePath)
            return
        end
        local outfitData = M.parse_outfit_ped_data(xmlContent)
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        if not outfitData or not outfitData.ModelHash then
            M.debug_print("[Spawn Debug] Error: Outfit data or ModelHash not found in XML file:", filePath)
            return
        end
        local modelHash = M.safe_tonumber(outfitData.ModelHash, nil)
        if not modelHash or modelHash == 0 then
            M.debug_print("[Spawn Debug] Error: Invalid ModelHash for outfit:", tostring(outfitData.ModelHash), "from:", filePath)
            return
        end
        local playerPed = GTA.GetLocalPed()
        if not playerPed then M.debug_print("[Spawn Debug] Error: Player ped not found for outfit spawn.") return end
        local playerHandle = GTA.PointerToHandle(playerPed) or (PLAYER and PLAYER.PLAYER_PED_ID and PLAYER.PLAYER_PED_ID())
        if not playerHandle or playerHandle == 0 then M.debug_print("[Spawn Debug] Error: Player handle not found for outfit spawn.") return end
        local pcoords = ENTITY.GET_ENTITY_COORDS(playerHandle, false)
        local heading = (playerPed.Heading or 0.0)
        local spawnCoords
        if isPreview then
            local offset_distance = 2.0
            local offset_height = 0.0
            local rad_heading = math.rad(heading)
            spawnCoords = {
                x = pcoords.x + (math.sin(rad_heading) * offset_distance),
                y = pcoords.y + (math.cos(rad_heading) * offset_distance),
                z = pcoords.z
            }
            local foundGround, groundZ = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
            if foundGround then spawnCoords.z = groundZ end
        else
            local forwardX = math.sin(math.rad(heading)) * 2.0
            local forwardY = math.cos(math.rad(heading)) * 2.0
            spawnCoords = { x = pcoords.x + forwardX, y = pcoords.y + forwardY, z = pcoords.z }
            local foundGround, groundZ = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
            if foundGround then spawnCoords.z = groundZ + 1.0 end
        end
        
        local spawnedPed = nil
        local targetPed = playerHandle  -- Default to player's ped
        
        -- Only spawn a new ped if onlyApplyAttachments is false
        if not spawnerSettings.onlyApplyAttachments then
            M.request_model_load(modelHash)
            spawnedPed = M.create_by_type(modelHash, 1, spawnCoords)
            if not spawnedPed or spawnedPed == 0 then
                M.debug_print("[Spawn Debug] Error: Failed to spawn main ped for outfit model hash:", modelHash, "from:", filePath)
                return
            end
            targetPed = spawnedPed
            
            -- Apply ped properties only if we spawned a new ped
            if spawnedPed ~= 0 then
                if outfitData.PedProperties then
                    M.apply_ped_properties(spawnedPed, outfitData.PedProperties)
                end
            else
                M.debug_print("[Spawn Debug] Error: spawnedPed is invalid, skipping property application and attachments.")
                return
            end
        else
        end
        
        local parentHandleMap = {}
        local xmlInitialHandle = M.safe_tonumber(outfitData.InitialHandle, nil)
        if xmlInitialHandle then parentHandleMap[xmlInitialHandle] = targetPed end
        if not parsedAttachments or #parsedAttachments == 0 then
        else
            for i, a in ipairs(parsedAttachments) do
            end
        end
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision, isPreview)
        end
        if (not createdAttachments or #createdAttachments == 0) and parsedAttachments and #parsedAttachments > 0 then
            local playerCoords = ENTITY.GET_ENTITY_COORDS(playerHandle, false)
            local fallbackForPlayer = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
            local playerParentMap = {}
            if xmlInitialHandle then playerParentMap[xmlInitialHandle] = playerHandle end
            local createdOnPlayer = M.spawn_attachments(parsedAttachments, playerParentMap, fallbackForPlayer, spawnerSettings.disableCollision, isPreview)
            createdAttachments = createdOnPlayer
        end
        pcall(function()
            PED.SET_PED_KEEP_TASK(spawnedPed, true)
            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(spawnedPed, true)
            ENTITY.SET_ENTITY_INVINCIBLE(spawnedPed, true)
        end)
        local function all_attachments_attached(list, parent)
            if not list or #list == 0 then return true end
            for _, ah in ipairs(list) do
                if ah and ah ~= 0 and ENTITY.DOES_ENTITY_EXIST(ah) then
                    local attachedTo = nil
                    pcall(function() attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(ah) end)
                    if attachedTo ~= parent then return false end
                end
            end
            return true
        end
        local attached_ok = false
        local maxChecks = 15
        for i = 1, maxChecks do
            if all_attachments_attached(createdAttachments, targetPed) then
                attached_ok = true
                break
            end
            if i == 5 then
                for _, ah in ipairs(createdAttachments) do
                    if ah and ah ~= 0 and ENTITY.DOES_ENTITY_EXIST(ah) then
                        local attachedTo = nil
                        pcall(function() attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(ah) end)
                        if attachedTo ~= targetPed then
                            pcall(function()
                                local originalAttData = nil
                                for _, originalAtt in ipairs(parsedAttachments) do
                                    if originalAtt.created == ah then
                                        originalAttData = originalAtt
                                        break
                                    end
                                end
                                ENTITY.ATTACH_ENTITY_TO_ENTITY(ah, targetPed, -1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, spawnerSettings.disableCollision, false, 0, true)
                                M.debug_print("[Spawn Debug] Re-attached attachment", tostring(ah), "with collisionFlag:", tostring(spawnerSettings.disableCollision))
                            end)
                        end
                    end
                end
            end
            Script.Yield(200)
        end
        if not attached_ok then
            M.debug_print("[Spawn Debug] Warning: Not all attachments were successfully attached to the spawned ped.")
        end
        if isPreview then
            if spawnedPed then
                table.insert(previewEntities, spawnedPed)
            end
            for _, attachment in ipairs(createdAttachments) do
            table.insert(previewEntities, attachment)
        end
        -- All preview logic is now handled by M.startPreviewUpdater
        return
    end
    -- Only change player to spawned ped if we actually spawned a new ped
    if spawnedPed and not spawnerSettings.onlyApplyAttachments then
        pcall(function()
                if PLAYER and PLAYER.PLAYER_ID and PLAYER.CHANGE_PLAYER_PED then
                    local pid = PLAYER.PLAYER_ID()
                    if pid then
                        Script.Yield(2000)
                        PLAYER.CHANGE_PLAYER_PED(pid, spawnedPed, true, true)
                        Script.Yield(250)
                    end
                end
            end)
    end
        local outfitRecord = { attachments = createdAttachments, spawnedPed = spawnedPed, filePath = filePath }
        table.insert(spawnedOutfits, outfitRecord)
    end)
end

function M.deleteAllSpawnedProps()
    Script.QueueJob(function()
        for i, propHandle in ipairs(spawnedProps) do
            if propHandle and ENTITY.DOES_ENTITY_EXIST(propHandle) then
                pcall(function()
                    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(propHandle, false, true)
                    ENTITY.DELETE_ENTITY(propHandle)
                end)
            end
        end
        spawnedProps = {}
        pcall(function() GUI.AddToast("Props Deleted", "All spawned props deleted.", 3000, 0) end)
    end)
end

-- JSON Vehicle Spawning Function
function M.spawnVehicleFromJSON(filePath, isPreview)
    Script.QueueJob(function()
        
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[JSON Spawn Debug] Error: JSON file does not exist:", filePath)
            pcall(function() GUI.AddToast("Spawn Error", "JSON file not found", 3000, 0) end)
            return
        end
        
        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            M.debug_print("[JSON Spawn Debug] Error: Failed to read JSON file or content is empty:", filePath)
            pcall(function() GUI.AddToast("Spawn Error", "Failed to read JSON file", 3000, 0) end)
            return
        end
        
        
        -- Parse JSON using proper converter
        local jsonData
        local parseSuccess, parseResult = pcall(function()
            -- Convert JSON to Lua table syntax
            local luaCode = jsonContent
            
            -- Replace arrays: [] -> {}
            luaCode = luaCode:gsub("%[", "{")
            luaCode = luaCode:gsub("%]", "}")
            
            -- Replace null with nil
            luaCode = luaCode:gsub(":null", ":nil")
            luaCode = luaCode:gsub(",null", ",nil")
            luaCode = luaCode:gsub("{null", "{nil")
            
            -- Replace quoted keys with unquoted keys and change : to =
            -- But keep quotes if the key has spaces or special characters
            luaCode = luaCode:gsub('"([^"]+)"%s*:%s*', function(key)
                -- Check if key is a valid Lua identifier (letters, numbers, underscore, no spaces)
                if key:match("^[%a_][%w_]*$") then
                    -- Valid identifier, remove quotes
                    return key .. "="
                else
                    -- Has spaces or special chars, keep quotes and use bracket notation
                    return '["' .. key .. '"]='
                end
            end)
            
            -- Wrap in return statement
            luaCode = "return " .. luaCode
            
            local func, err = load(luaCode)
            if not func then
                M.debug_print("[JSON Spawn Debug] Load error:", tostring(err))
                error("Failed to parse JSON: " .. tostring(err))
            end
            return func()
        end)
        
        if not parseSuccess or not parseResult then
            pcall(function() GUI.AddToast("Spawn Error", "Failed to parse JSON: " .. tostring(parseResult), 5000, 0) end)
            return
        end
        
        jsonData = parseResult
        
        -- Detect JSON format
        local isJSTAND = jsonData.base ~= nil or jsonData.version and jsonData.version:match("Jackz Builder")
        local isConstructor = jsonData.type == "VEHICLE"
        
        
        -- Handle JSTAND format (Jackz Builder)
        if isJSTAND then
            
            -- Get the base vehicle model
            local modelHash = jsonData.base and jsonData.base.model or jsonData.base and jsonData.base.data and jsonData.base.data.model
            if not modelHash then
                M.debug_print("[JSON Spawn Debug] Error: No model in JSTAND base")
                pcall(function() GUI.AddToast("Spawn Error", "No model in JSTAND base", 3000, 0) end)
                return
            end
            
            -- Convert JSTAND to a format we can use
            jsonData.hash = modelHash
            jsonData.type = "VEHICLE"
            jsonData.children = {}
            
            -- Add objects as children
            if jsonData.objects then
                for _, obj in ipairs(jsonData.objects) do
                    table.insert(jsonData.children, {
                        type = "OBJECT",
                        hash = obj.model,
                        model = obj.model,
                        offset = obj.offset,
                        rotation = obj.rotation,
                        options = {
                            is_visible = obj.visible,
                            has_collision = obj.collision,
                            bone_index = obj.boneIndex or 0
                        }
                    })
                end
            end
            
            -- Add vehicles as children
            if jsonData.vehicles then
                for _, veh in ipairs(jsonData.vehicles) do
                    table.insert(jsonData.children, {
                        type = "VEHICLE",
                        hash = veh.model,
                        model = veh.model,
                        offset = veh.offset,
                        rotation = veh.rotation,
                        options = {
                            is_visible = veh.visible,
                            is_invincible = veh.godmode,
                            has_collision = veh.collision,
                            bone_index = veh.boneIndex or 0
                        }
                    })
                end
            end
            
        end
        
        -- Check if it's a vehicle (after potential conversion)
        if jsonData.type ~= "VEHICLE" then
            M.debug_print("[JSON Spawn Debug] Error: JSON is not a vehicle type, got:", tostring(jsonData.type))
            pcall(function() GUI.AddToast("Spawn Error", "This JSON is not a vehicle", 3000, 0) end)
            return
        end
        
        -- Get player position for spawning
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, false)
        local playerHeading = ENTITY.GET_ENTITY_HEADING(playerPed)
        
        
        -- Calculate spawn position
        local spawnCoords = {}
        if spawnerSettings.inVehicle then
            spawnCoords.x = playerCoords.x
            spawnCoords.y = playerCoords.y
            spawnCoords.z = playerCoords.z
        else
            local forwardX = math.sin(math.rad(playerHeading)) * 3.0
            local forwardY = math.cos(math.rad(playerHeading)) * 3.0
            spawnCoords.x = playerCoords.x + forwardX
            spawnCoords.y = playerCoords.y + forwardY
            spawnCoords.z = playerCoords.z
        end
        
        
        -- Delete old vehicle if requested
        if spawnerSettings.deleteOldVehicle and not isPreview then
            M.deleteAllSpawnedVehicles()
            Script.Yield(100)
        end
        
        -- Get vehicle model
        local modelHash = jsonData.hash
        if not modelHash then
            M.debug_print("[JSON Spawn Debug] Error: No model hash in JSON")
            pcall(function() GUI.AddToast("Spawn Error", "No model hash in JSON", 3000, 0) end)
            return
        end
        
        
        -- Request and load model
        M.request_model_load(modelHash)
        Script.Yield(200)
        
        -- Spawn the main vehicle
        local vehicleHandle
        local playerID = PLAYER.PLAYER_ID()
        local forwardOffset = 5.0
        
        -- Check if we should use the current vehicle instead of spawning a new one
        local applyToCurrentVehicle = spawnerSettings.onlyApplyAttachments and not isPreview
        
        if applyToCurrentVehicle then
            -- Get the player's current vehicle
            local currentVehicle = nil
            pcall(function()
                currentVehicle = PED.GET_VEHICLE_PED_IS_IN(playerPed, false)
            end)
            if currentVehicle and currentVehicle ~= 0 then
                vehicleHandle = currentVehicle
                M.debug_print("[Apply Attachments] Using current vehicle: " .. tostring(vehicleHandle))
            else
                GUI.AddToast("Apply Attachments", "You must be in a vehicle to apply attachments", 5000, 0)
                return
            end
        else
            -- Use GTA.SpawnVehicleForPlayer like INI spawning does
            local spawnSuccess, spawnResult = pcall(function()
                return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset)
            end)
            
            if spawnSuccess and spawnResult and spawnResult ~= 0 then
                vehicleHandle = spawnResult
            else
            end
            
            -- Fallback to GTA.SpawnVehicle if SpawnVehicleForPlayer failed
            if not vehicleHandle or vehicleHandle == 0 then
                local spawnSuccess2, spawnResult2 = pcall(function()
                    return GTA.SpawnVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, playerHeading, true, true)
                end)
                
                if spawnSuccess2 and spawnResult2 and spawnResult2 ~= 0 then
                    vehicleHandle = spawnResult2
                end
            end
        end
        
        if not vehicleHandle or vehicleHandle == 0 then
            local fileName = filePath:match("([^/\\]+)$") or filePath
            Logger.LogError("[Spawn] Failed to spawn vehicle from '" .. fileName .. "' (hash: " .. tostring(modelHash) .. ")")
            pcall(function() GUI.AddToast("Spawn Error", "Failed to spawn vehicle", 3000, 0) end)
            return
        end
        
        
        -- Apply vehicle attributes from JSON with comprehensive phasing
        if jsonData.vehicle_attributes then
            local attrs = jsonData.vehicle_attributes
            
            -- Phase 1: Set vehicle as modifiable
            pcall(function()
                VEHICLE.SET_VEHICLE_MOD_KIT(vehicleHandle, 0)
            end)
            Script.Yield(50)
            
            -- Phase 2: Apply all mods (0-49)
            if attrs.mods then
                for modKey, modValue in pairs(attrs.mods) do
                    local modId = tonumber(modKey:match("_(%d+)"))
                    if modId then
                        if type(modValue) == "boolean" then
                            pcall(function() 
                                VEHICLE.TOGGLE_VEHICLE_MOD(vehicleHandle, modId, modValue)
                            end)
                        elseif type(modValue) == "number" and modValue ~= -1 then
                            pcall(function() 
                                VEHICLE.SET_VEHICLE_MOD(vehicleHandle, modId, modValue, false)
                            end)
                        end
                    end
                end
                Script.Yield(50)
            end
            
            -- Phase 3: Apply paint (colors, pearlescent, fade, dirt)
            if attrs.paint then
                local paint = attrs.paint
                
                -- Primary color
                if paint.primary then
                    if paint.primary.is_custom and paint.primary.custom_color then
                        local c = paint.primary.custom_color
                        pcall(function() 
                            VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicleHandle, c.r or 0, c.g or 0, c.b or 0)
                        end)
                    elseif paint.primary.vehicle_standard_color then
                        pcall(function()
                            VEHICLE.SET_VEHICLE_COLOURS(vehicleHandle, paint.primary.vehicle_standard_color, paint.secondary and paint.secondary.vehicle_standard_color or 0)
                        end)
                    end
                    
                    -- Pearlescent color (on primary)
                    if paint.primary.pearlescent_color and paint.primary.pearlescent_color ~= -1 then
                        pcall(function()
                            local wheelColor = paint.extra_colors and paint.extra_colors.wheel or 0
                            VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicleHandle, paint.primary.pearlescent_color, wheelColor)
                        end)
                    end
                end
                
                -- Secondary color
                if paint.secondary and paint.secondary.is_custom and paint.secondary.custom_color then
                    local c = paint.secondary.custom_color
                    pcall(function()
                        VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicleHandle, c.r or 0, c.g or 0, c.b or 0)
                    end)
                end
                
                -- Extra colors (pearlescent and wheel)
                if paint.extra_colors then
                    if paint.extra_colors.pearlescent and paint.extra_colors.pearlescent ~= -1 then
                        pcall(function()
                            VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicleHandle, paint.extra_colors.pearlescent, paint.extra_colors.wheel or 0)
                        end)
                    end
                end
                
                -- Dirt level
                if paint.dirt_level then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicleHandle, paint.dirt_level)
                    end)
                end
                
                -- Fade
                if paint.fade then
                    -- Note: Fade is typically handled through paint type, not a direct native
                end
                
                -- Dashboard and interior colors
                if paint.dashboard_color and paint.dashboard_color ~= -1 then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_DASHBOARD_COLOUR(vehicleHandle, paint.dashboard_color)
                    end)
                end
                
                if paint.interior_color and paint.interior_color ~= -1 then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_INTERIOR_COLOUR(vehicleHandle, paint.interior_color)
                    end)
                end
                
                -- Livery
                if paint.livery and paint.livery ~= -1 then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_LIVERY(vehicleHandle, paint.livery)
                    end)
                end
                
                Script.Yield(50)
            end
            
            -- Phase 4: Apply neon lights
            if attrs.neon then
                if attrs.neon.lights then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 0, attrs.neon.lights.left or false)
                        VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 1, attrs.neon.lights.right or false)
                        VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 2, attrs.neon.lights.front or false)
                        VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 3, attrs.neon.lights.back or false)
                    end)
                end
                
                if attrs.neon.color then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_NEON_COLOUR(vehicleHandle, attrs.neon.color.r or 0, attrs.neon.color.g or 0, attrs.neon.color.b or 0)
                    end)
                end
                Script.Yield(50)
            end
            
            -- Phase 5: Apply headlights
            if attrs.headlights then
                if attrs.headlights.headlights_color and attrs.headlights.headlights_color ~= -1 then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_XENON_LIGHT_COLOR_INDEX(vehicleHandle, attrs.headlights.headlights_color)
                    end)
                end
                
                if attrs.headlights.headlights_type then
                    pcall(function()
                        VEHICLE.TOGGLE_VEHICLE_MOD(vehicleHandle, 22, attrs.headlights.headlights_type)
                    end)
                end
                
                Script.Yield(50)
            end
            
            -- Phase 6: Apply wheels
            if attrs.wheels then
                if attrs.wheels.wheel_type then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicleHandle, attrs.wheels.wheel_type)
                    end)
                end
                
                -- Tire smoke color
                if attrs.wheels.tire_smoke_color then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(vehicleHandle, 
                            attrs.wheels.tire_smoke_color.r or 0, 
                            attrs.wheels.tire_smoke_color.g or 0, 
                            attrs.wheels.tire_smoke_color.b or 0)
                    end)
                end
                
                -- Burst tires
                if attrs.wheels.tires_burst then
                    for tireKey, isBurst in pairs(attrs.wheels.tires_burst) do
                        if isBurst then
                            local tireId = tonumber(tireKey:match("_(%d+)"))
                            if tireId then
                                pcall(function()
                                    VEHICLE.SET_VEHICLE_TYRE_BURST(vehicleHandle, tireId, true, 1000.0)
                                end)
                            end
                        end
                    end
                end
                
                Script.Yield(50)
            end
            
            -- Phase 7: Apply extras
            if attrs.extras then
                for extraKey, isEnabled in pairs(attrs.extras) do
                    local extraId = tonumber(extraKey:match("_(%d+)"))
                    if extraId then
                        pcall(function()
                            VEHICLE.SET_VEHICLE_EXTRA(vehicleHandle, extraId, not isEnabled)
                        end)
                    end
                end
                Script.Yield(50)
            end
            
            -- Phase 8: Apply doors
            if attrs.doors then
                -- Open doors
                if attrs.doors.open then
                    for doorName, isOpen in pairs(attrs.doors.open) do
                        if isOpen then
                            local doorId = ({
                                frontleft = 0, frontright = 1,
                                backleft = 2, backright = 3,
                                hood = 4, trunk = 5, trunk2 = 6
                            })[doorName]
                            if doorId then
                                pcall(function()
                                    VEHICLE.SET_VEHICLE_DOOR_OPEN(vehicleHandle, doorId, false, false)
                                end)
                            end
                        end
                    end
                end
                
                -- Broken doors
                if attrs.doors.broken then
                    for doorName, isBroken in pairs(attrs.doors.broken) do
                        if isBroken then
                            local doorId = ({
                                frontleft = 0, frontright = 1,
                                backleft = 2, backright = 3,
                                hood = 4, trunk = 5, trunk2 = 6
                            })[doorName]
                            if doorId then
                                pcall(function()
                                    VEHICLE.SET_VEHICLE_DOOR_BROKEN(vehicleHandle, doorId, true)
                                end)
                            end
                        end
                    end
                end
                Script.Yield(50)
            end
            
            -- Phase 9: Apply options
            if attrs.options then
                local opts = attrs.options
                
                if opts.license_plate_text then
                    pcall(function() 
                        VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicleHandle, opts.license_plate_text)
                    end)
                end
                
                if opts.license_plate_type and opts.license_plate_type ~= -1 then
                    pcall(function() 
                        VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(vehicleHandle, opts.license_plate_type)
                    end)
                end
                
                if opts.window_tint and opts.window_tint ~= -1 then
                    pcall(function() 
                        VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicleHandle, opts.window_tint)
                    end)
                end
                
                if opts.bulletproof_tires then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicleHandle, false)
                    end)
                end
                
                if opts.engine_running ~= nil then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, opts.engine_running, true, false)
                    end)
                end
                
                if opts.siren then
                    pcall(function()
                        VEHICLE.SET_VEHICLE_HAS_MUTED_SIRENS(vehicleHandle, not opts.siren)
                    end)
                end
                
                Script.Yield(50)
            end
            
        end
        
        -- Apply spawner settings
        if spawnerSettings.vehicleGodMode and not isPreview then
            pcall(function()
                ENTITY.SET_ENTITY_INVINCIBLE(vehicleHandle, true)
                ENTITY.SET_ENTITY_PROOFS(vehicleHandle, true, true, true, true, true, true, true, true)
            end)
        end
        
        if spawnerSettings.vehicleEngineOn and not isPreview then
            pcall(function()
                VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, true, true, false)
            end)
        end
        
        if spawnerSettings.radioOff and not isPreview then
            pcall(function()
                VEHICLE.SET_VEHICLE_RADIO_ENABLED(vehicleHandle, false)
            end)
        end
        
        -- Recursive function to spawn a child and its nested children
        local function spawnJSONChild(child, parentHandle, depth, childEntities)
            depth = depth or 0
            local indent = string.rep("  ", depth)
            
            -- Check for PARTICLE type FIRST - particles don't have hash/model
            if child.type == "PARTICLE" then
                local particleAttrs = child.particle_attributes
                if particleAttrs and particleAttrs.asset and particleAttrs.effect_name then
                    local assetName = particleAttrs.asset
                    local effectName = particleAttrs.effect_name
                    local scale = particleAttrs.scale or 1.0
                    
                    -- Get offset and rotation
                    local offsetX = child.offset and child.offset.x or 0.0
                    local offsetY = child.offset and child.offset.y or 0.0
                    local offsetZ = child.offset and child.offset.z or 0.0
                    local rotX = child.rotation and child.rotation.x or 0.0
                    local rotY = child.rotation and child.rotation.y or 0.0
                    local rotZ = child.rotation and child.rotation.z or 0.0
                    
                    -- Get color
                    local r, g, b, a = 1.0, 1.0, 1.0, 1.0
                    if particleAttrs.color then
                        r = particleAttrs.color.r or 1.0
                        g = particleAttrs.color.g or 1.0
                        b = particleAttrs.color.b or 1.0
                        a = particleAttrs.color.a or 1.0
                    end
                    
                    local entityHandle = parentHandle
                    
                    Script.QueueJob(function()
                        if not ENTITY or not ENTITY.DOES_ENTITY_EXIST(entityHandle) then return end
                        if not GRAPHICS then return end
                        if not ensure_ptfx_asset_loaded(assetName) then return end
                        
                        if GRAPHICS.USE_PARTICLE_FX_ASSET then
                            GRAPHICS.USE_PARTICLE_FX_ASSET(assetName)
                        end
                        
                        local handle = nil
                        local startFunc = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY or GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY
                        if startFunc then
                            pcall(function()
                                handle = startFunc(
                                    effectName, entityHandle,
                                    offsetX, offsetY, offsetZ,
                                    rotX, rotY, rotZ,
                                    scale, false, false, false
                                )
                            end)
                        end
                        
                        if handle and handle ~= 0 then
                            pcall(function()
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR then
                                    GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                                end
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA then
                                    GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                                end
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE then
                                    GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                                end
                            end)
                            
                            -- Refresh loop - keep effect alive with 150ms interval
                            Script.QueueJob(function()
                                while ENTITY and ENTITY.DOES_ENTITY_EXIST(entityHandle) do
                                    Script.Yield(150)
                                    if not ENTITY.DOES_ENTITY_EXIST(entityHandle) then break end
                                    
                                    -- Stop and restart the effect
                                    if GRAPHICS.STOP_PARTICLE_FX_LOOPED then
                                        pcall(function() GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false) end)
                                    end
                                    
                                    if not ensure_ptfx_asset_loaded(assetName) then break end
                                    
                                    if GRAPHICS.USE_PARTICLE_FX_ASSET then
                                        GRAPHICS.USE_PARTICLE_FX_ASSET(assetName)
                                    end
                                    
                                    local newHandle = nil
                                    if startFunc then
                                        pcall(function()
                                            newHandle = startFunc(
                                                effectName, entityHandle,
                                                offsetX, offsetY, offsetZ,
                                                rotX, rotY, rotZ,
                                                scale, false, false, false
                                            )
                                        end)
                                    end
                                    
                                    if newHandle and newHandle ~= 0 then
                                        handle = newHandle
                                        pcall(function()
                                            if GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR then
                                                GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                                            end
                                            if GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA then
                                                GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                                            end
                                            if GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE then
                                                GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                                            end
                                        end)
                                    else
                                        break
                                    end
                                end
                                
                                -- Cleanup
                                if GRAPHICS.STOP_PARTICLE_FX_LOOPED and handle then
                                    pcall(function() GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false) end)
                                end
                            end)
                        end
                    end)
                end
                return nil
            end
            
            -- For non-PARTICLE types, check for model hash
            local childModel = child.hash or child.model
            if not childModel then
                return nil
            end
            
            M.request_model_load(childModel)
            Script.Yield(100)
            
            local childHandle
            if child.type == "VEHICLE" then
                -- Use Cherax API for vehicle spawning
                local ok, h = pcall(function()
                    return GTA.SpawnVehicle(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
                end)
                    if ok and h and h ~= 0 then 
                        childHandle = h 
                        
                        -- Apply comprehensive vehicle attributes if present
                        if child.vehicle_attributes then
                            local attrs = child.vehicle_attributes
                            
                            -- Set vehicle as modifiable
                            pcall(function() VEHICLE.SET_VEHICLE_MOD_KIT(h, 0) end)
                            Script.Yield(50)
                            
                            -- Apply mods
                            if attrs.mods then
                                for modKey, modValue in pairs(attrs.mods) do
                                    local modId = tonumber(modKey:match("_(%d+)"))
                                    if modId then
                                        if type(modValue) == "boolean" then
                                            pcall(function() VEHICLE.TOGGLE_VEHICLE_MOD(h, modId, modValue) end)
                                        elseif type(modValue) == "number" and modValue ~= -1 then
                                            pcall(function() VEHICLE.SET_VEHICLE_MOD(h, modId, modValue, false) end)
                                        end
                                    end
                                end
                            end
                            
                            -- Apply paint
                            if attrs.paint then
                                if attrs.paint.primary then
                                    if attrs.paint.primary.is_custom and attrs.paint.primary.custom_color then
                                        local c = attrs.paint.primary.custom_color
                                        pcall(function() VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(h, c.r or 0, c.g or 0, c.b or 0) end)
                                    elseif attrs.paint.primary.vehicle_standard_color then
                                        pcall(function()
                                            VEHICLE.SET_VEHICLE_COLOURS(h, attrs.paint.primary.vehicle_standard_color, attrs.paint.secondary and attrs.paint.secondary.vehicle_standard_color or 0)
                                        end)
                                    end
                                    if attrs.paint.primary.pearlescent_color and attrs.paint.primary.pearlescent_color ~= -1 then
                                        pcall(function()
                                            local wheelColor = attrs.paint.extra_colors and attrs.paint.extra_colors.wheel or 0
                                            VEHICLE.SET_VEHICLE_EXTRA_COLOURS(h, attrs.paint.primary.pearlescent_color, wheelColor)
                                        end)
                                    end
                                end
                                if attrs.paint.secondary and attrs.paint.secondary.is_custom and attrs.paint.secondary.custom_color then
                                    local c = attrs.paint.secondary.custom_color
                                    pcall(function() VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(h, c.r or 0, c.g or 0, c.b or 0) end)
                                end
                                if attrs.paint.extra_colors and attrs.paint.extra_colors.pearlescent and attrs.paint.extra_colors.pearlescent ~= -1 then
                                    pcall(function()
                                        VEHICLE.SET_VEHICLE_EXTRA_COLOURS(h, attrs.paint.extra_colors.pearlescent, attrs.paint.extra_colors.wheel or 0)
                                    end)
                                end
                                if attrs.paint.dirt_level then
                                    pcall(function() VEHICLE.SET_VEHICLE_DIRT_LEVEL(h, attrs.paint.dirt_level) end)
                                end
                                if attrs.paint.dashboard_color and attrs.paint.dashboard_color ~= -1 then
                                    pcall(function() VEHICLE.SET_VEHICLE_DASHBOARD_COLOUR(h, attrs.paint.dashboard_color) end)
                                end
                                if attrs.paint.interior_color and attrs.paint.interior_color ~= -1 then
                                    pcall(function() VEHICLE.SET_VEHICLE_INTERIOR_COLOUR(h, attrs.paint.interior_color) end)
                                end
                                if attrs.paint.livery and attrs.paint.livery ~= -1 then
                                    pcall(function() VEHICLE.SET_VEHICLE_LIVERY(h, attrs.paint.livery) end)
                                end
                            end
                            
                            -- Apply neon
                            if attrs.neon then
                                if attrs.neon.lights then
                                    pcall(function()
                                        VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 0, attrs.neon.lights.left or false)
                                        VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 1, attrs.neon.lights.right or false)
                                        VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 2, attrs.neon.lights.front or false)
                                        VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 3, attrs.neon.lights.back or false)
                                    end)
                                end
                                if attrs.neon.color then
                                    pcall(function()
                                        VEHICLE.SET_VEHICLE_NEON_COLOUR(h, attrs.neon.color.r or 0, attrs.neon.color.g or 0, attrs.neon.color.b or 0)
                                    end)
                                end
                            end
                            
                            -- Apply headlights
                            if attrs.headlights then
                                if attrs.headlights.headlights_color and attrs.headlights.headlights_color ~= -1 then
                                    pcall(function() VEHICLE.SET_VEHICLE_XENON_LIGHT_COLOR_INDEX(h, attrs.headlights.headlights_color) end)
                                end
                                if attrs.headlights.headlights_type then
                                    pcall(function() VEHICLE.TOGGLE_VEHICLE_MOD(h, 22, attrs.headlights.headlights_type) end)
                                end
                            end
                            
                            -- Apply wheels
                            if attrs.wheels then
                                if attrs.wheels.wheel_type then
                                    pcall(function() VEHICLE.SET_VEHICLE_WHEEL_TYPE(h, attrs.wheels.wheel_type) end)
                                end
                                if attrs.wheels.tire_smoke_color then
                                    pcall(function()
                                        VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(h, 
                                            attrs.wheels.tire_smoke_color.r or 0, 
                                            attrs.wheels.tire_smoke_color.g or 0, 
                                            attrs.wheels.tire_smoke_color.b or 0)
                                    end)
                                end
                                if attrs.wheels.tires_burst then
                                    for tireKey, isBurst in pairs(attrs.wheels.tires_burst) do
                                        if isBurst then
                                            local tireId = tonumber(tireKey:match("_(%d+)"))
                                            if tireId then
                                                pcall(function() VEHICLE.SET_VEHICLE_TYRE_BURST(h, tireId, true, 1000.0) end)
                                            end
                                        end
                                    end
                                end
                            end
                            
                            -- Apply extras
                            if attrs.extras then
                                for extraKey, isEnabled in pairs(attrs.extras) do
                                    local extraId = tonumber(extraKey:match("_(%d+)"))
                                    if extraId then
                                        pcall(function() VEHICLE.SET_VEHICLE_EXTRA(h, extraId, not isEnabled) end)
                                    end
                                end
                            end
                            
                            -- Apply doors
                            if attrs.doors then
                                if attrs.doors.open then
                                    for doorName, isOpen in pairs(attrs.doors.open) do
                                        if isOpen then
                                            local doorId = ({
                                                frontleft = 0, frontright = 1,
                                                backleft = 2, backright = 3,
                                                hood = 4, trunk = 5, trunk2 = 6
                                            })[doorName]
                                            if doorId then
                                                pcall(function() VEHICLE.SET_VEHICLE_DOOR_OPEN(h, doorId, false, false) end)
                                            end
                                        end
                                    end
                                end
                                if attrs.doors.broken then
                                    for doorName, isBroken in pairs(attrs.doors.broken) do
                                        if isBroken then
                                            local doorId = ({
                                                frontleft = 0, frontright = 1,
                                                backleft = 2, backright = 3,
                                                hood = 4, trunk = 5, trunk2 = 6
                                            })[doorName]
                                            if doorId then
                                                pcall(function() VEHICLE.SET_VEHICLE_DOOR_BROKEN(h, doorId, true) end)
                                            end
                                        end
                                    end
                                end
                            end
                            
                            -- Apply options
                            if attrs.options then
                                if attrs.options.license_plate_text then
                                    pcall(function() VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(h, attrs.options.license_plate_text) end)
                                end
                                if attrs.options.license_plate_type and attrs.options.license_plate_type ~= -1 then
                                    pcall(function() VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(h, attrs.options.license_plate_type) end)
                                end
                                if attrs.options.window_tint and attrs.options.window_tint ~= -1 then
                                    pcall(function() VEHICLE.SET_VEHICLE_WINDOW_TINT(h, attrs.options.window_tint) end)
                                end
                                if attrs.options.bulletproof_tires then
                                    pcall(function() VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(h, false) end)
                                end
                                if attrs.options.engine_running ~= nil then
                                    pcall(function() VEHICLE.SET_VEHICLE_ENGINE_ON(h, attrs.options.engine_running, true, false) end)
                                end
                                if attrs.options.siren then
                                    pcall(function() VEHICLE.SET_VEHICLE_HAS_MUTED_SIRENS(h, not attrs.options.siren) end)
                                end
                            end
                            
                        end
                    else
                        M.debug_print("[JSON Spawn Debug]" .. indent .. "Failed to spawn child VEHICLE with GTA.SpawnVehicle, ok:", ok, "handle:", tostring(h))
                    end
            elseif child.type == "PED" then
                -- Use Cherax API for ped spawning
                local ok, h = pcall(function()
                    return GTA.CreatePed(childModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
                end)
                if ok and h and h ~= 0 then 
                        childHandle = h 
                        
                        -- Apply ped attributes
                        if child.ped_attributes then
                            local attrs = child.ped_attributes
                            
                            -- Apply animation
                            if attrs.animation and attrs.animation.dictionary and attrs.animation.clip then
                                Script.Yield(100)
                                pcall(function()
                                    STREAMING.REQUEST_ANIM_DICT(attrs.animation.dictionary)
                                    local timeout = 0
                                    while not STREAMING.HAS_ANIM_DICT_LOADED(attrs.animation.dictionary) and timeout < 50 do
                                        Script.Yield(10)
                                        timeout = timeout + 1
                                    end
                                    if STREAMING.HAS_ANIM_DICT_LOADED(attrs.animation.dictionary) then
                                        TASK.TASK_PLAY_ANIM(h, attrs.animation.dictionary, attrs.animation.clip, 8.0, -8.0, -1, attrs.animation.loop and 1 or 0, 0, false, false, false)
                                    end
                                end)
                            end
                            
                            -- Apply components (clothing)
                            if attrs.components then
                                for compKey, compData in pairs(attrs.components) do
                                    local compId = tonumber(compKey:match("_(%d+)"))
                                    if compId and compData.drawable_variation then
                                        pcall(function()
                                            PED.SET_PED_COMPONENT_VARIATION(h, compId, compData.drawable_variation, compData.texture_variation or 0, compData.palette_variation or 0)
                                        end)
                                    end
                                end
                            end
                            
                            -- Apply props (accessories)
                            if attrs.props then
                                for propKey, propData in pairs(attrs.props) do
                                    local propId = tonumber(propKey:match("_(%d+)"))
                                    if propId and propData.drawable_variation and propData.drawable_variation ~= -1 then
                                        pcall(function()
                                            PED.SET_PED_PROP_INDEX(h, propId, propData.drawable_variation, propData.texture_variation or 0, true)
                                        end)
                                    end
                                end
                            end
                            
                            -- Apply other ped settings
                            if attrs.ignore_events then
                                pcall(function() PED.SET_PED_CONFIG_FLAG(h, 208, true) end)
                            end
                            
                            if attrs.keep_on_task then
                                pcall(function() PED.SET_PED_KEEP_TASK(h, true) end)
                            end
                        end
                else
                    M.debug_print("[JSON Spawn Debug]" .. indent .. "Failed to spawn child PED with GTA.CreatePed, ok:", ok, "handle:", tostring(h))
                end
            elseif child.type == "PARTICLE" then
                -- Handle PARTICLE type children - spawn particle effect on parent (matching XML approach)
                local particleAttrs = child.particle_attributes
                print("[JSON PTFX] Processing PARTICLE child, particle_attributes:", particleAttrs and "found" or "nil")
                
                if particleAttrs then
                    local assetName = particleAttrs.asset
                    local effectName = particleAttrs.effect_name
                    local scale = particleAttrs.scale or 1.0
                    local boneIndex = particleAttrs.bone_index or 0
                    
                    print("[JSON PTFX] Asset:", tostring(assetName), "Effect:", tostring(effectName), "Scale:", scale, "Bone:", boneIndex)
                    
                    if assetName and effectName then
                        -- Get offset from child
                        local offsetX = child.offset and child.offset.x or 0.0
                        local offsetY = child.offset and child.offset.y or 0.0
                        local offsetZ = child.offset and child.offset.z or 0.0
                        
                        -- Get rotation from child
                        local rotX = child.rotation and child.rotation.x or 0.0
                        local rotY = child.rotation and child.rotation.y or 0.0
                        local rotZ = child.rotation and child.rotation.z or 0.0
                        
                        print("[JSON PTFX] Offset:", offsetX, offsetY, offsetZ, "Rotation:", rotX, rotY, rotZ)
                        
                        -- Get color from particle_attributes (JSON uses 0-1 range like XML after normalization)
                        local r, g, b, a = 1.0, 1.0, 1.0, 1.0
                        if particleAttrs.color then
                            r = particleAttrs.color.r or 1.0
                            g = particleAttrs.color.g or 1.0
                            b = particleAttrs.color.b or 1.0
                            a = particleAttrs.color.a or 1.0
                        end
                        print("[JSON PTFX] Color RGBA:", r, g, b, a)
                        
                        -- Store the parent handle for the queued job
                        local entityHandle = parentHandle
                        
                        -- Use Script.QueueJob exactly like XML does
                        Script.QueueJob(function()
                            print("[JSON PTFX] Queued job started for:", effectName)
                            
                            -- Check if entity still exists (like XML does)
                            if not ENTITY or not ENTITY.DOES_ENTITY_EXIST or not ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                                print("[JSON PTFX] ERROR: Entity does not exist!")
                                return
                            end
                            print("[JSON PTFX] Entity exists, handle:", entityHandle)
                            
                            -- Check if GRAPHICS is available
                            if not GRAPHICS then
                                print("[JSON PTFX] ERROR: GRAPHICS not available!")
                                return
                            end
                            print("[JSON PTFX] GRAPHICS available")
                            
                            -- Load the PTFX asset (like XML does)
                            print("[JSON PTFX] Loading PTFX asset:", assetName)
                            local ptfxLoaded = ensure_ptfx_asset_loaded(assetName)
                            print("[JSON PTFX] Asset loaded:", ptfxLoaded)
                            
                            if not ptfxLoaded then
                                print("[JSON PTFX] ERROR: Failed to load PTFX asset:", assetName)
                                M.debug_print("[JSON PTFX] Failed to load PTFX asset:", tostring(assetName))
                                return
                            end
                            
                            -- Start the particle effect (matching XML's looped task approach)
                            local handle = nil
                            local ok, err = pcall(function()
                                print("[JSON PTFX] Calling USE_PARTICLE_FX_ASSET")
                                if GRAPHICS.USE_PARTICLE_FX_ASSET then
                                    GRAPHICS.USE_PARTICLE_FX_ASSET(assetName)
                                end
                                
                                print("[JSON PTFX] Attempting to start particle FX...")
                                print("[JSON PTFX] START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE:", GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE and "available" or "nil")
                                print("[JSON PTFX] START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE:", GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE and "available" or "nil")
                                print("[JSON PTFX] START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY:", GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY and "available" or "nil")
                                print("[JSON PTFX] START_PARTICLE_FX_LOOPED_ON_ENTITY:", GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY and "available" or "nil")
                                
                                -- Try each method in order (same as XML)
                                if GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE then
                                    print("[JSON PTFX] Using START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE")
                                    handle = GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE(
                                        effectName,
                                        entityHandle,
                                        offsetX, offsetY, offsetZ,
                                        rotX, rotY, rotZ,
                                        boneIndex,
                                        scale,
                                        false, false, false,
                                        r, g, b, a
                                    )
                                    print("[JSON PTFX] Result handle:", handle)
                                elseif GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE then
                                    print("[JSON PTFX] Using START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE")
                                    handle = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE(
                                        effectName,
                                        entityHandle,
                                        offsetX, offsetY, offsetZ,
                                        rotX, rotY, rotZ,
                                        boneIndex,
                                        scale,
                                        false, false, false
                                    )
                                    print("[JSON PTFX] Result handle:", handle)
                                elseif GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY then
                                    print("[JSON PTFX] Using START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY")
                                    handle = GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY(
                                        effectName,
                                        entityHandle,
                                        offsetX, offsetY, offsetZ,
                                        rotX, rotY, rotZ,
                                        scale,
                                        false, false, false,
                                        r, g, b, a
                                    )
                                    print("[JSON PTFX] Result handle:", handle)
                                elseif GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY then
                                    print("[JSON PTFX] Using START_PARTICLE_FX_LOOPED_ON_ENTITY")
                                    handle = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY(
                                        effectName,
                                        entityHandle,
                                        offsetX, offsetY, offsetZ,
                                        rotX, rotY, rotZ,
                                        scale,
                                        false, false, false
                                    )
                                    print("[JSON PTFX] Result handle:", handle)
                                else
                                    print("[JSON PTFX] ERROR: No suitable PARTICLE_FX function available!")
                                end
                            end)
                            
                            if not ok then
                                print("[JSON PTFX] ERROR: pcall failed:", tostring(err))
                                return
                            end
                            
                            if handle and handle ~= 0 then
                                print("[JSON PTFX] SUCCESS! PTFX handle:", handle)
                                M.debug_print("[JSON PTFX] Spawned PARTICLE:", effectName, "from asset:", assetName, "handle:", handle)
                                
                                -- Apply color and scale (like XML does)
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR then
                                    pcall(function()
                                        GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                                        print("[JSON PTFX] Applied color")
                                    end)
                                end
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA then
                                    pcall(function()
                                        GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                                        print("[JSON PTFX] Applied alpha")
                                    end)
                                end
                                if GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE then
                                    pcall(function()
                                        GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                                        print("[JSON PTFX] Applied scale")
                                    end)
                                end
                                
                                -- Keep the effect running (like XML's KeepTaskRunningAfterTime = -1)
                                -- Refresh the particle effect periodically to keep it alive
                                local refreshInterval = 150
                                Script.QueueJob(function()
                                    print("[JSON PTFX] Starting refresh loop for:", effectName)
                                    while ENTITY and ENTITY.DOES_ENTITY_EXIST and ENTITY.DOES_ENTITY_EXIST(entityHandle) do
                                        Script.Yield(refreshInterval)
                                        
                                        if not ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                                            print("[JSON PTFX] Entity no longer exists, stopping refresh")
                                            break
                                        end
                                        
                                        -- Stop and restart to keep effect visible
                                        if GRAPHICS.STOP_PARTICLE_FX_LOOPED then
                                            pcall(function() GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false) end)
                                        end
                                        
                                        if not ensure_ptfx_asset_loaded(assetName) then
                                            print("[JSON PTFX] Asset no longer loaded, breaking")
                                            break
                                        end
                                        
                                        local newHandle = nil
                                        pcall(function()
                                            if GRAPHICS.USE_PARTICLE_FX_ASSET then
                                                GRAPHICS.USE_PARTICLE_FX_ASSET(assetName)
                                            end
                                            
                                            if GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE then
                                                newHandle = GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE(
                                                    effectName, entityHandle,
                                                    offsetX, offsetY, offsetZ,
                                                    rotX, rotY, rotZ,
                                                    boneIndex, scale,
                                                    false, false, false,
                                                    r, g, b, a
                                                )
                                            elseif GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE then
                                                newHandle = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY_BONE(
                                                    effectName, entityHandle,
                                                    offsetX, offsetY, offsetZ,
                                                    rotX, rotY, rotZ,
                                                    boneIndex, scale,
                                                    false, false, false
                                                )
                                            elseif GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY then
                                                newHandle = GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY(
                                                    effectName, entityHandle,
                                                    offsetX, offsetY, offsetZ,
                                                    rotX, rotY, rotZ,
                                                    scale,
                                                    false, false, false,
                                                    r, g, b, a
                                                )
                                            elseif GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY then
                                                newHandle = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY(
                                                    effectName, entityHandle,
                                                    offsetX, offsetY, offsetZ,
                                                    rotX, rotY, rotZ,
                                                    scale,
                                                    false, false, false
                                                )
                                            end
                                        end)
                                        
                                        if newHandle and newHandle ~= 0 then
                                            handle = newHandle
                                            
                                            if GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR then
                                                pcall(function() GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false) end)
                                            end
                                            if GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA then
                                                pcall(function() GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a) end)
                                            end
                                            if GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE then
                                                pcall(function() GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale) end)
                                            end
                                        else
                                            print("[JSON PTFX] Refresh failed, breaking loop")
                                            break
                                        end
                                    end
                                    
                                    -- Cleanup
                                    print("[JSON PTFX] Cleaning up particle effect:", effectName)
                                    if GRAPHICS.STOP_PARTICLE_FX_LOOPED and handle then
                                        pcall(function() GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false) end)
                                    end
                                end)
                            else
                                print("[JSON PTFX] FAILED: handle is nil or 0")
                                M.debug_print("[JSON PTFX] Failed to start PARTICLE effect:", effectName)
                            end
                        end)
                    else
                        print("[JSON PTFX] ERROR: Missing asset or effect_name")
                    end
                else
                    print("[JSON PTFX] ERROR: No particle_attributes found")
                end
                
                -- Particles don't create entity handles, so skip to next child
                return nil
            else
                -- It's an object - try multiple methods
                
                -- Try GTA.CreateObject first (preferred method)
                local ok, h = pcall(function()
                    return GTA.CreateObject(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true)
                end)
                if ok and h and h ~= 0 then
                    childHandle = h
                end
                
                -- Try GTA.CreateWorldObject if first method failed
                if not childHandle or childHandle == 0 then
                    ok, h = pcall(function()
                        return GTA.CreateWorldObject(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true)
                    end)
                    if ok and h and h ~= 0 then
                        childHandle = h
                    end
                end
            end
            
            if childHandle and childHandle ~= 0 then
                
                -- Apply all options from JSON
                if child.options then
                    local opts = child.options
                    
                    -- Set visibility
                    if opts.is_visible ~= nil then
                        pcall(function() 
                            ENTITY.SET_ENTITY_VISIBLE(childHandle, opts.is_visible, false) 
                        end)
                    end
                    
                    -- Set invincibility
                    if opts.is_invincible ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(childHandle, opts.is_invincible) end)
                    end
                    
                    -- Set collision
                    if opts.has_collision ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_COLLISION(childHandle, opts.has_collision, false) end)
                    end
                    
                    -- Set frozen state
                    if opts.is_frozen ~= nil then
                        pcall(function() ENTITY.FREEZE_ENTITY_POSITION(childHandle, opts.is_frozen) end)
                    end
                    
                    -- Set gravity
                    if opts.has_gravity ~= nil and not opts.has_gravity then
                        pcall(function() ENTITY.SET_ENTITY_HAS_GRAVITY(childHandle, false) end)
                    end
                    
                    -- Set alpha/transparency
                    if opts.alpha and opts.alpha ~= 255 then
                        pcall(function() ENTITY.SET_ENTITY_ALPHA(childHandle, opts.alpha, false) end)
                    end
                    
                    -- Set proofs (fire, bullet, explosion, melee)
                    local fireProof = opts.is_fire_proof or false
                    local bulletProof = opts.is_bullet_proof or false
                    local explosionProof = opts.is_explosion_proof or false
                    local meleeProof = opts.is_melee_proof or false
                    pcall(function()
                        ENTITY.SET_ENTITY_PROOFS(childHandle, bulletProof, fireProof, explosionProof, false, meleeProof, false, false, false)
                    end)
                    
                    -- Get bone index for attachment
                    local boneIndex = opts.bone_index or 0
                    
                    -- Attach to parent
                    if child.offset then
                        pcall(function()
                            ENTITY.ATTACH_ENTITY_TO_ENTITY(
                                childHandle, parentHandle, boneIndex,
                                child.offset.x or 0, child.offset.y or 0, child.offset.z or 0,
                                child.rotation and child.rotation.x or 0,
                                child.rotation and child.rotation.y or 0,
                                child.rotation and child.rotation.z or 0,
                                false, false, true, false, 0, true
                            )
                        end)
                        M.debug_print("[JSON Spawn Debug]" .. indent .. "Attached to parent (bone:", boneIndex, ")")
                    end
                end
                
                table.insert(childEntities, childHandle)
                
                -- Recursively spawn nested children
                if child.children and #child.children > 0 then
                    for j, nestedChild in ipairs(child.children) do
                        spawnJSONChild(nestedChild, childHandle, depth + 1, childEntities)
                    end
                end
                
                return childHandle
            end
            
            return nil
        end
        
        -- Spawn and attach children
        local childEntities = {}
        if jsonData.children and #jsonData.children > 0 then
            
            for i, child in ipairs(jsonData.children) do
                spawnJSONChild(child, vehicleHandle, 0, childEntities)
            end
        end
        
        -- Put player in vehicle if requested
        if spawnerSettings.inVehicle and not isPreview then
            Script.Yield(200)
            pcall(function()
                PED.SET_PED_INTO_VEHICLE(playerPed, vehicleHandle, -1)
            end)
        end
        
        -- Handle preview mode
        if isPreview then
            table.insert(previewEntities, vehicleHandle)
            for _, entity in ipairs(childEntities) do
                table.insert(previewEntities, entity)
            end
        else
            -- Track spawned vehicle
            local vehicleRecord = {
                vehicle = vehicleHandle,
                attachments = childEntities,
                filePath = filePath
            }
            table.insert(spawnedVehicles, vehicleRecord)
            
            pcall(function()
                local fileName = M.get_filename_from_path(filePath)
                local attachmentCount = #childEntities
                local toastMessage = fileName .. " with " .. attachmentCount .. " attachment" .. (attachmentCount == 1 and "" or "s")
                if jsonData.author and jsonData.author ~= "" then
                    toastMessage = toastMessage .. "\nby " .. jsonData.author
                end
                GUI.AddToast("Vehicle Spawned", toastMessage, 5000, 0)
                print("Vehicle Spawned", toastMessage)
            end)
        end
    end)
end

-- JSON Map Spawning Function
function M.spawnMapFromJSON(filePath, isPreview)
    Script.QueueJob(function()
        
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[JSON Map Spawn Debug] Error: JSON file does not exist:", filePath)
            pcall(function() GUI.AddToast("Spawn Error", "JSON file not found", 3000, 0) end)
            return
        end
        
        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            M.debug_print("[JSON Map Spawn Debug] Error: Failed to read JSON file or content is empty:", filePath)
            pcall(function() GUI.AddToast("Spawn Error", "Failed to read JSON file", 3000, 0) end)
            return
        end
        
        
        -- Parse JSON using the same parser as vehicles
        local jsonData
        local parseSuccess, parseResult = pcall(function()
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
                M.debug_print("[JSON Map Spawn Debug] Load error:", tostring(err))
                error("Failed to parse JSON: " .. tostring(err))
            end
            return func()
        end)
        
        if not parseSuccess or not parseResult then
            pcall(function() GUI.AddToast("Spawn Error", "Failed to parse JSON: " .. tostring(parseResult), 5000, 0) end)
            return
        end
        
        jsonData = parseResult
        
        -- Get filename and total children for progress tracking
        local fileName = M.get_filename_from_path(filePath)
        local totalChildren = (jsonData.children and #jsonData.children or 0) + (jsonData.hash and 1 or 0)
        
        -- Delete old map if requested
        if spawnerSettings.deleteOldMap and #spawnedMaps > 0 then
            local lastMap = spawnedMaps[#spawnedMaps]
            if lastMap and lastMap.entities then
                for _, entityHandle in ipairs(lastMap.entities) do
                    if entityHandle and entityHandle ~= 0 then
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                                local ptr = Memory.AllocInt()
                                Memory.WriteInt(ptr, entityHandle)
                                ENTITY.DELETE_ENTITY(ptr)
                            end
                        end)
                    end
                end
            end
            table.remove(spawnedMaps, #spawnedMaps)
        end
        
        -- Get player position for reference
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, false)
        
        -- Determine reference coordinates
        local refCoords = {}
        local shouldTeleport = false
        
        if jsonData.always_spawn_at_position and jsonData.position then
            -- Map has always_spawn_at_position flag - use map position
            refCoords.x = jsonData.position.x
            refCoords.y = jsonData.position.y
            refCoords.z = jsonData.position.z
            shouldTeleport = spawnerSettings.teleportToMap
        elseif jsonData.position and spawnerSettings.teleportToMap then
            -- Map has position and teleport is enabled - use map position
            refCoords.x = jsonData.position.x
            refCoords.y = jsonData.position.y
            refCoords.z = jsonData.position.z
            shouldTeleport = true
        else
            -- Use player position
            refCoords.x = playerCoords.x
            refCoords.y = playerCoords.y
            refCoords.z = playerCoords.z
        end
        
        -- Teleport player if needed
        if shouldTeleport then
            pcall(function()
                ENTITY.SET_ENTITY_COORDS(playerPed, refCoords.x, refCoords.y, refCoords.z, false, false, false, true)
            end)
        end
        
        -- Recursive function to spawn children and their nested children
        local function spawnMapChild(child, parentHandle, depth, allEntities)
            local indent = string.rep("  ", depth)
            
            local childModel = child.hash or child.model
            if not childModel then
                return nil
            end
            
            M.request_model_load(childModel)
            Script.Yield(100)
            
            
            -- Calculate spawn position
            local spawnPos
            -- First priority: use child's absolute position if available
            if child.position then
                spawnPos = {
                    x = child.position.x,
                    y = child.position.y,
                    z = child.position.z
                }
            elseif parentHandle and parentHandle ~= 0 then
                -- If there's a parent and no absolute position, spawn at parent's position (will be attached with offset)
                local parentCoords = ENTITY.GET_ENTITY_COORDS(parentHandle, false)
                spawnPos = {
                    x = parentCoords.x,
                    y = parentCoords.y,
                    z = parentCoords.z
                }
            else
                -- No parent and no position, use reference coords + offset
                spawnPos = {
                    x = refCoords.x + (child.offset and child.offset.x or 0),
                    y = refCoords.y + (child.offset and child.offset.y or 0),
                    z = refCoords.z + (child.offset and child.offset.z or 0)
                }
            end
            
            local entityHandle
            if child.type == "VEHICLE" then
                local rotData = child.world_rotation or child.rotation
                -- Use Cherax API for vehicle spawning
                local ok, h = pcall(function()
                    return GTA.SpawnVehicle(childModel, spawnPos.x, spawnPos.y, spawnPos.z, rotData and rotData.z or 0, true, true)
                end)
                if ok and h and h ~= 0 then 
                    entityHandle = h 
                end
            elseif child.type == "PED" then
                local rotData = child.world_rotation or child.rotation
                -- Use Cherax API for ped spawning
                local ok, h = pcall(function()
                    return GTA.CreatePed(childModel, 26, spawnPos.x, spawnPos.y, spawnPos.z, rotData and rotData.z or 0, true, true)
                end)
                if ok and h and h ~= 0 then 
                    entityHandle = h 
                    
                    -- Apply ped attributes
                    if child.ped_attributes then
                        local attrs = child.ped_attributes
                        if attrs.animation and attrs.animation.dictionary and attrs.animation.clip then
                            Script.Yield(100)
                            pcall(function()
                                STREAMING.REQUEST_ANIM_DICT(attrs.animation.dictionary)
                                local timeout = 0
                                while not STREAMING.HAS_ANIM_DICT_LOADED(attrs.animation.dictionary) and timeout < 50 do
                                    Script.Yield(10)
                                    timeout = timeout + 1
                                end
                                if STREAMING.HAS_ANIM_DICT_LOADED(attrs.animation.dictionary) then
                                    TASK.TASK_PLAY_ANIM(h, attrs.animation.dictionary, attrs.animation.clip, 8.0, -8.0, -1, attrs.animation.loop and 1 or 0, 0, false, false, false)
                                end
                            end)
                        end
                        if attrs.components then
                            for compKey, compData in pairs(attrs.components) do
                                local compId = tonumber(compKey:match("_(%d+)"))
                                if compId and compData.drawable_variation then
                                    pcall(function()
                                        PED.SET_PED_COMPONENT_VARIATION(h, compId, compData.drawable_variation, compData.texture_variation or 0, compData.palette_variation or 0)
                                    end)
                                end
                            end
                        end
                        if attrs.props then
                            for propKey, propData in pairs(attrs.props) do
                                local propId = tonumber(propKey:match("_(%d+)"))
                                if propId and propData.drawable_variation and propData.drawable_variation ~= -1 then
                                    pcall(function()
                                        PED.SET_PED_PROP_INDEX(h, propId, propData.drawable_variation, propData.texture_variation or 0, true)
                                    end)
                                end
                            end
                        end
                        if attrs.ignore_events then
                            pcall(function() PED.SET_PED_CONFIG_FLAG(h, 208, true) end)
                        end
                        if attrs.keep_on_task then
                            pcall(function() PED.SET_PED_KEEP_TASK(h, true) end)
                        end
                    end
                end
            else
                -- It's an object
                local ok, h = pcall(function()
                    return GTA.CreateObject(childModel, spawnPos.x, spawnPos.y, spawnPos.z, true, true)
                end)
                if ok and h and h ~= 0 then
                    entityHandle = h
                end
                if not entityHandle or entityHandle == 0 then
                    ok, h = pcall(function()
                        return GTA.CreateWorldObject(childModel, spawnPos.x, spawnPos.y, spawnPos.z, true, true)
                    end)
                    if ok and h and h ~= 0 then
                        entityHandle = h
                    end
                end
            end
            
            if entityHandle and entityHandle ~= 0 then
                
                -- Apply rotation (use world_rotation if available, otherwise rotation)
                local rotData = child.world_rotation or child.rotation
                if rotData then
                    pcall(function()
                        ENTITY.SET_ENTITY_ROTATION(entityHandle, rotData.x or 0, rotData.y or 0, rotData.z or 0, 2, true)
                    end)
                end
                
                -- Apply options
                if child.options then
                    local opts = child.options
                    if opts.is_visible ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_VISIBLE(entityHandle, opts.is_visible, false) end)
                    end
                    if opts.is_invincible ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, opts.is_invincible) end)
                    end
                    if opts.has_collision ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_COLLISION(entityHandle, opts.has_collision, false) end)
                    end
                    if opts.is_frozen ~= nil then
                        pcall(function() ENTITY.FREEZE_ENTITY_POSITION(entityHandle, opts.is_frozen) end)
                    end
                    if opts.has_gravity ~= nil and not opts.has_gravity then
                        pcall(function() ENTITY.SET_ENTITY_HAS_GRAVITY(entityHandle, false) end)
                    end
                    if opts.alpha and opts.alpha ~= 255 then
                        pcall(function() ENTITY.SET_ENTITY_ALPHA(entityHandle, opts.alpha, false) end)
                    end
                    
                    -- Determine if this child should be attached to parent or spawned independently
                    local shouldAttach = false
                    local offsetX = child.offset and child.offset.x or 0
                    local offsetY = child.offset and child.offset.y or 0
                    local offsetZ = child.offset and child.offset.z or 0
                    
                    -- Check if offset is non-zero (meaning it should be attached)
                    if offsetX ~= 0 or offsetY ~= 0 or offsetZ ~= 0 then
                        shouldAttach = true
                    end
                    
                    -- Also check the is_attached flag if present
                    if opts.is_attached ~= nil and not opts.is_attached then
                        shouldAttach = false
                    end
                    
                    -- Attach to parent if this child should be attached
                    if parentHandle and parentHandle ~= 0 and shouldAttach and child.offset then
                        local boneIndex = opts.bone_index or 0
                        pcall(function()
                            ENTITY.ATTACH_ENTITY_TO_ENTITY(
                                entityHandle, parentHandle, boneIndex,
                                offsetX, offsetY, offsetZ,
                                child.rotation and child.rotation.x or 0,
                                child.rotation and child.rotation.y or 0,
                                child.rotation and child.rotation.z or 0,
                                false, false, true, false, 0, true
                            )
                        end)
                        M.debug_print("[JSON Map Spawn Debug]" .. indent .. "Attached to parent (bone:", boneIndex, ")")
                    else
                    end
                end
                
                table.insert(allEntities, entityHandle)
                
                -- Recursively spawn nested children
                if child.children and #child.children > 0 then
                    for j, nestedChild in ipairs(child.children) do
                        spawnMapChild(nestedChild, entityHandle, depth + 1, allEntities)
                    end
                end
                
                return entityHandle
            end
            
            return nil
        end
        
        
        -- Spawn the main parent object first (the root of the JSON)
        local mainParentHandle = nil
        local mainModel = jsonData.hash or jsonData.model
        
        if mainModel then
            M.request_model_load(mainModel)
            Script.Yield(100)
            
            -- Spawn at the position specified in the JSON
            local mainPos = jsonData.position or refCoords
            
            if jsonData.type == "VEHICLE" then
                -- Use Cherax API for vehicle spawning
                local ok, h = pcall(function()
                    return GTA.SpawnVehicle(mainModel, mainPos.x, mainPos.y, mainPos.z, jsonData.rotation and jsonData.rotation.z or 0, true, true)
                end)
                if ok and h and h ~= 0 then mainParentHandle = h end
            elseif jsonData.type == "PED" then
                -- Use Cherax API for ped spawning
                local ok, h = pcall(function()
                    return GTA.CreatePed(mainModel, 26, mainPos.x, mainPos.y, mainPos.z, jsonData.rotation and jsonData.rotation.z or 0, true, true)
                end)
                if ok and h and h ~= 0 then mainParentHandle = h end
            else
                -- It's an object
                local ok, h = pcall(function()
                    return GTA.CreateObject(mainModel, mainPos.x, mainPos.y, mainPos.z, true, true)
                end)
                if ok and h and h ~= 0 then mainParentHandle = h end
                if not mainParentHandle or mainParentHandle == 0 then
                    ok, h = pcall(function()
                        return GTA.CreateWorldObject(mainModel, mainPos.x, mainPos.y, mainPos.z, true, true)
                    end)
                    if ok and h and h ~= 0 then mainParentHandle = h end
                end
            end
            
            if mainParentHandle and mainParentHandle ~= 0 then
                
                -- Apply rotation to main parent (use world_rotation if available)
                local mainRotData = jsonData.world_rotation or jsonData.rotation
                if mainRotData then
                    pcall(function()
                        ENTITY.SET_ENTITY_ROTATION(mainParentHandle, mainRotData.x or 0, mainRotData.y or 0, mainRotData.z or 0, 2, true)
                    end)
                end
                
                -- Apply options to main parent
                if jsonData.options then
                    local opts = jsonData.options
                    if opts.is_visible ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_VISIBLE(mainParentHandle, opts.is_visible, false) end)
                    end
                    if opts.is_invincible ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(mainParentHandle, opts.is_invincible) end)
                    end
                    if opts.has_collision ~= nil then
                        pcall(function() ENTITY.SET_ENTITY_COLLISION(mainParentHandle, opts.has_collision, false) end)
                    end
                    if opts.is_frozen ~= nil then
                        pcall(function() ENTITY.FREEZE_ENTITY_POSITION(mainParentHandle, opts.is_frozen) end)
                    end
                    if opts.has_gravity ~= nil and not opts.has_gravity then
                        pcall(function() ENTITY.SET_ENTITY_HAS_GRAVITY(mainParentHandle, false) end)
                    end
                    if opts.alpha and opts.alpha ~= 255 then
                        pcall(function() ENTITY.SET_ENTITY_ALPHA(mainParentHandle, opts.alpha, false) end)
                    end
                end
            else
                M.debug_print("[JSON Map Spawn Debug] Failed to spawn main parent object")
            end
        end
        
        -- Spawn all children attached to the main parent (or standalone if no parent)
        local spawnedEntities = {}
        if mainParentHandle then
            table.insert(spawnedEntities, mainParentHandle)
        end
        
        if jsonData.children and #jsonData.children > 0 then
            
            for i, child in ipairs(jsonData.children) do
                spawnMapChild(child, mainParentHandle, 1, spawnedEntities)
                -- Show live progress (only if over 200 entities)
                if totalChildren > 200 and (i == 1 or i == #jsonData.children or i % 5 == 0) then
                    pcall(function() GUI.AddToast("Spawning Map", fileName .. " (" .. #spawnedEntities .. "/" .. totalChildren .. ")", 1000, 0) end)
                end
            end
        end
        
        
        -- Track spawned map
        local mapRecord = {
            entities = spawnedEntities,
            filePath = filePath,
            markers = {}, -- No markers for JSON maps yet
            refCoords = refCoords
        }
        table.insert(spawnedMaps, mapRecord)
        
        pcall(function()
            local spawnedCount = #spawnedEntities
            local toastMsg = fileName
            if totalChildren > 200 then
                toastMsg = toastMsg .. " (" .. spawnedCount .. "/" .. totalChildren .. " entities)"
            end
            GUI.AddToast("Map Spawned", toastMsg, 5000, 0)
            print("Map Spawned", toastMsg)
        end)
    end)
end

-- JSON Outfit Spawning Function
function M.spawnOutfitFromJSON(filePath, isPreview)
    print("[JSON Outfit] Function called with file:", filePath, "isPreview:", tostring(isPreview))
    isPreview = isPreview or false
    
    Script.QueueJob(function()
        print("[JSON Outfit] Inside Script.QueueJob")
        
        if not FileMgr.DoesFileExist(filePath) then
            print("[JSON Outfit] Error: File does not exist:", filePath)
            M.debug_print("[JSON Outfit Spawn Debug] Error: JSON file does not exist:", filePath)
            pcall(function() GUI.AddToast("Spawn Error", "JSON file not found", 3000, 0) end)
            return
        end
        
        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            M.debug_print("[JSON Outfit] Error: Failed to read file or content empty")
            M.debug_print("[JSON Outfit Spawn Debug] Error: Failed to read JSON file or content is empty:", filePath)
            pcall(function() GUI.AddToast("Spawn Error", "Failed to read JSON file", 3000, 0) end)
            return
        end
        
        
        -- Parse JSON using the same parser
        local jsonData
        local parseSuccess, parseResult = pcall(function()
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
        
        if not parseSuccess or not parseResult then
            pcall(function() GUI.AddToast("Spawn Error", "Failed to parse JSON: " .. tostring(parseResult), 5000, 0) end)
            return
        end
        
        jsonData = parseResult
        
        -- Check if it's a ped outfit
        if jsonData.type ~= "PED" then
            M.debug_print("[JSON Outfit] Error: Not a PED type")
            M.debug_print("[JSON Outfit Spawn Debug] Error: JSON is not a PED type, got:", tostring(jsonData.type))
            pcall(function() GUI.AddToast("Spawn Error", "This JSON is not a PED outfit", 3000, 0) end)
            return
        end
        
        -- Check is_player flag FIRST before validating model hash
        local isAttachToPlayer = (jsonData.is_player == false)  -- When is_player is false, attach directly to player
        
        -- Only validate model hash if we need to spawn a new ped (is_player is true or nil)
        local modelHash = jsonData.hash or jsonData.model
        if not isAttachToPlayer then
            if not modelHash or modelHash == 0 then
                M.debug_print("[JSON Outfit] Error: Invalid model hash")
                M.debug_print("[JSON Outfit Spawn Debug] Error: Invalid model hash")
                return
            end
        else
        end
        
        -- Get player position and heading
        local playerPed = GTA.GetLocalPed()
        if not playerPed then
            M.debug_print("[JSON Outfit] Error: Player ped not found")
            M.debug_print("[JSON Outfit Spawn Debug] Error: Player ped not found")
            return
        end
        
        local playerHandle = GTA.PointerToHandle(playerPed) or PLAYER.PLAYER_PED_ID()
        if not playerHandle or playerHandle == 0 then
            M.debug_print("[JSON Outfit] Error: Player handle not found")
            M.debug_print("[JSON Outfit Spawn Debug] Error: Player handle not found")
            return
        end
        
        local pcoords = ENTITY.GET_ENTITY_COORDS(playerHandle, false)
        local heading = (playerPed.Heading or 0.0)
        
        -- Calculate spawn position (in front of player for preview, or at player for actual spawn)
        local spawnCoords
        if isPreview then
            local offset_distance = 2.0
            local rad_heading = math.rad(heading)
            spawnCoords = {
                x = pcoords.x + (math.sin(rad_heading) * offset_distance),
                y = pcoords.y + (math.cos(rad_heading) * offset_distance),
                z = pcoords.z
            }
            local foundGround, groundZ = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
            if foundGround then spawnCoords.z = groundZ end
        else
            spawnCoords = { x = pcoords.x, y = pcoords.y, z = pcoords.z }
        end
        
        
        -- Delete last outfit attachments if toggle is enabled
        if spawnerSettings.deleteLastOutfitAttachments and #spawnedOutfits > 0 then
            local lastOutfit = spawnedOutfits[#spawnedOutfits]
            if lastOutfit and lastOutfit.attachments then
                for _, attachmentHandle in ipairs(lastOutfit.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                                local ptr = Memory.AllocInt()
                                local pEntity = GTA.HandleToPointer(attachmentHandle)
                                if pEntity and pEntity ~= 0 then
                                    if pEntity.NetObject and pEntity.NetObject ~= 0 then
                                        NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                                    end
                                    Memory.WriteInt(ptr, attachmentHandle)
                                    ENTITY.DELETE_ENTITY(ptr)
                                end
                            end
                        end)
                    end
                end
            end
            table.remove(spawnedOutfits, #spawnedOutfits)
        end
        
        
        -- Determine target ped based on is_player flag and onlyApplyAttachments setting
        local targetPed
        local spawnedPed = nil -- Only set if we actually spawn a new ped
        
        -- If onlyApplyAttachments is enabled, always attach to player (skip model swap and ped properties)
        -- OR if isAttachToPlayer is true (is_player flag is false in JSON)
        if spawnerSettings.onlyApplyAttachments or isAttachToPlayer then
            -- Attach directly to player ped (no new ped spawned)
            if spawnerSettings.onlyApplyAttachments then
            else
            end
            targetPed = playerHandle
        else
            -- Spawn a new ped (is_player is true or nil, and onlyApplyAttachments is false)
            M.request_model_load(modelHash)
            Script.Yield(200)
            
            -- Use Cherax API for ped spawning
            local ok, h = pcall(function()
                return GTA.CreatePed(modelHash, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, false, false)
            end)
            if ok and h and h ~= 0 then
                spawnedPed = h
            end
            
            if not spawnedPed or spawnedPed == 0 then
                M.debug_print("[JSON Outfit] Error: Failed to spawn ped")
                M.debug_print("[JSON Outfit Spawn Debug] Error: Failed to spawn ped")
                return
            end
            
            targetPed = spawnedPed
        end

        
        -- Apply ped attributes (components, props, armor, weapon) to the target ped
        -- ONLY if not in onlyApplyAttachments mode
        if jsonData.ped_attributes and not spawnerSettings.onlyApplyAttachments then
            local attrs = jsonData.ped_attributes
            
            -- Apply components (clothing)
            if attrs.components then
                for compKey, compData in pairs(attrs.components) do
                    local compId = tonumber(compKey:match("_(%d+)"))
                    if compId and compData.drawable_variation then
                        pcall(function()
                            PED.SET_PED_COMPONENT_VARIATION(
                                targetPed, 
                                compId, 
                                compData.drawable_variation, 
                                compData.texture_variation or 0, 
                                compData.palette_variation or 0
                            )
                        end)
                    end
                end
            end
            
            -- Apply props (accessories like hats, glasses, etc.)
            if attrs.props then
                for propKey, propData in pairs(attrs.props) do
                    local propId = tonumber(propKey:match("_(%d+)"))
                    if propId then
                        if propData.drawable_variation and propData.drawable_variation ~= -1 then
                            pcall(function()
                                PED.SET_PED_PROP_INDEX(
                                    targetPed, 
                                    propId, 
                                    propData.drawable_variation, 
                                    propData.texture_variation or 0, 
                                    true
                                )
                            end)
                        else
                            -- Clear the prop if drawable_variation is -1
                            pcall(function()
                                PED.CLEAR_PED_PROP(targetPed, propId)
                            end)
                        end
                    end
                end
            end
            
            -- Apply armor
            if attrs.armor then
                pcall(function()
                    PED.SET_PED_ARMOUR(targetPed, attrs.armor)
                end)
            end
            
            -- Apply weapon
            if attrs.weapon and attrs.weapon.model then
                local weaponModel = attrs.weapon.model
                local weaponHash
                
                -- Convert weapon model to hash if it's a string
                if type(weaponModel) == "string" then
                    weaponHash = MISC.GET_HASH_KEY(weaponModel)
                else
                    weaponHash = weaponModel
                end
                
                -- Phase the weapon model
                M.request_model_load(weaponHash)
                Script.Yield(100)
                
                -- Give weapon to ped and force equip it
                pcall(function()
                    WEAPON.GIVE_WEAPON_TO_PED(targetPed, weaponHash, 9999, false, true)
                end)
            end
            
        end
        
        -- Change player to the spawned ped if we spawned a new one
        if spawnedPed and not isAttachToPlayer then
            pcall(function()
                local playerID = PLAYER.PLAYER_ID()
                if playerID and playerID >= 0 then
                    PLAYER.CHANGE_PLAYER_PED(playerID, spawnedPed, true, false)
                end
            end)
        end
        
        -- Spawn and attach children objects (with recursive nested children support)
        local attachedObjects = {}
        
        -- Recursive function to spawn and attach children
        local function spawnAndAttachChildren(children, parentEntity, parentName)
            if not children or #children == 0 then return end
            
            M.debug_print("[JSON Outfit] Spawning", #children, "children attached to", parentName)
            M.debug_print("[JSON Outfit Spawn Debug] Spawning", #children, "children attached to", parentName)
            
            for i, child in ipairs(children) do
                local childModel = child.hash or child.model
                if childModel then
                    M.request_model_load(childModel)
                    Script.Yield(100)
                    
                    local objectHandle
                    -- Use Cherax API for object spawning
                    local ok2, h2 = pcall(function()
                        return GTA.CreateObject(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true)
                    end)
                    if ok2 and h2 and h2 ~= 0 then
                        objectHandle = h2
                    end
                    
                    if objectHandle and objectHandle ~= 0 then
                        local childName = child.name or child.model or tostring(childModel)
                        
                        -- Apply options
                        if child.options then
                            local opts = child.options
                            if opts.is_visible ~= nil then
                                pcall(function() ENTITY.SET_ENTITY_VISIBLE(objectHandle, opts.is_visible, false) end)
                            end
                            if opts.has_collision ~= nil then
                                pcall(function() ENTITY.SET_ENTITY_COLLISION(objectHandle, opts.has_collision, false) end)
                            end
                            if opts.is_invincible ~= nil then
                                pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(objectHandle, opts.is_invincible) end)
                            end
                        end
                        
                        -- Attach to parent entity (could be the player/ped or another object)
                        local boneIndex = child.options and child.options.bone_index or 0
                        pcall(function()
                            ENTITY.ATTACH_ENTITY_TO_ENTITY(
                                objectHandle, parentEntity, boneIndex,
                                child.offset and child.offset.x or 0,
                                child.offset and child.offset.y or 0,
                                child.offset and child.offset.z or 0,
                                child.rotation and child.rotation.x or 0,
                                child.rotation and child.rotation.y or 0,
                                child.rotation and child.rotation.z or 0,
                                false, false, false, false, 2, true
                            )
                        end)
                        M.debug_print("[JSON Outfit] Attached", childName, "to bone", boneIndex, "on", parentName)
                        M.debug_print("[JSON Outfit Spawn Debug] Attached", childName, "to bone", boneIndex, "on", parentName)
                        
                        table.insert(attachedObjects, objectHandle)
                        
                        -- Recursively spawn and attach nested children to THIS object
                        if child.children and type(child.children) == "table" and #child.children > 0 then
                            spawnAndAttachChildren(child.children, objectHandle, childName)
                        end
                    else
                        M.debug_print("[JSON Outfit] Failed to spawn child", i)
                        M.debug_print("[JSON Outfit Spawn Debug] Failed to spawn child", i)
                    end
                end
            end
        end
        
        -- Start the recursive spawning from the top-level children
        if jsonData.children and #jsonData.children > 0 then
            local parentName = isAttachToPlayer and "player" or "spawned ped"
            spawnAndAttachChildren(jsonData.children, targetPed, parentName)
        end
        
        
        -- Handle preview vs actual spawn
        if isPreview then
            if spawnedPed then
                table.insert(previewEntities, spawnedPed)
            end
            for _, obj in ipairs(attachedObjects) do
                table.insert(previewEntities, obj)
            end
        else
            -- Track spawned outfit
            local outfitRecord = {
                spawnedPed = spawnedPed, -- Will be set if we spawned a new ped, nil if attached to player
                attachments = attachedObjects,
                filePath = filePath,
                attachedToPlayer = isAttachToPlayer -- True if attached to player, false if new ped spawned
            }
            table.insert(spawnedOutfits, outfitRecord)
            
            pcall(function()
                local fileName = M.get_filename_from_path(filePath)
                local msg = isAttachToPlayer 
                    and ("Attached " .. #attachedObjects .. " object" .. (#attachedObjects == 1 and "" or "s") .. " to player")
                    or ("Spawned " .. fileName .. " with " .. #attachedObjects .. " attachment" .. (#attachedObjects == 1 and "" or "s"))
                GUI.AddToast("Outfit Spawned", msg, 5000, 0)
            end)
        end
    end)
end

function M.spawnVehicleFromCHRX(path, index)
    if not path then return end
    
    -- Get the root CHRX vehicles folder and find all files recursively
    local chrxRoot = chrxVehiclesFolder
    local allFiles = FileMgr.FindFiles(chrxRoot, ".json", true)
    
    if not allFiles or #allFiles == 0 then
        GUI.AddToast("CHRX Spawn", "No vehicle files found", 5000, 0)
        return
    end
    
    -- Sort files alphabetically (case-insensitive) to match Cherax's ordering
    table.sort(allFiles, function(a, b)
        return a:lower() < b:lower()
    end)
    
    -- Find the index of our file in the sorted list
    local correctIndex = nil
    for i, file in ipairs(allFiles) do
        -- Normalize paths for comparison
        local normalizedFile = file:gsub("\\", "/")
        local normalizedPath = path:gsub("\\", "/")
        if normalizedFile == normalizedPath then
            correctIndex = i - 1 -- 0-indexed
            break
        end
    end
    
    if correctIndex == nil then
        GUI.AddToast("CHRX Spawn", "Failed to find file index", 5000, 0)
        return
    end
    
    -- Spawn the vehicle using the calculated index
    FeatureMgr.SetFeatureListIndex(514776905, correctIndex)
    FeatureMgr.GetFeatureByName("Load Vehicle"):TriggerCallback()
end

function M.spawnOutfitFromCHRX(path, index)
    if not path then return end
    
    -- Get the root CHRX outfits folder and find all files recursively
    local chrxRoot = chrxOutfitsFolder
    local allFiles = FileMgr.FindFiles(chrxRoot, ".json", true)
    
    if not allFiles or #allFiles == 0 then
        GUI.AddToast("CHRX Spawn", "No outfit files found", 5000, 0)
        return
    end
    
    -- Sort files alphabetically (case-insensitive) to match Cherax's ordering
    table.sort(allFiles, function(a, b)
        return a:lower() < b:lower()
    end)
    
    -- Find the index of our file in the sorted list
    local correctIndex = nil
    for i, file in ipairs(allFiles) do
        -- Normalize paths for comparison
        local normalizedFile = file:gsub("\\", "/")
        local normalizedPath = path:gsub("\\", "/")
        if normalizedFile == normalizedPath then
            correctIndex = i - 1 -- 0-indexed
            break
        end
    end
    
    if correctIndex == nil then
        GUI.AddToast("CHRX Spawn", "Failed to find file index", 5000, 0)
        return
    end
    
    -- Spawn the outfit using the calculated index
    FeatureMgr.SetFeatureListIndex(2384691091, correctIndex)
    FeatureMgr.GetFeatureByName("Load Outfit"):TriggerCallback()
end

return M
