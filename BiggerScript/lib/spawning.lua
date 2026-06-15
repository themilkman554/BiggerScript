local M = {}

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

local previewUpdateJob = nil
local isPreviewUpdaterRunning = false
local lastSpawnedVehiclePath = nil

-- Import parsers
local xml_parser = require("BiggerScript/lib/parsers/xml_parser")
local ini_parser = require("BiggerScript/lib/parsers/ini_parser")
local json_parser = require("BiggerScript/lib/parsers/json_parser")
local job_parser = require("BiggerScript/lib/parsers/job_parser")
local spawn_core = require("BiggerScript/lib/spawn_core")
local asset_loader = require("BiggerScript/lib/asset_loader")

-- Context variables to be initialized by the main script
local upsidedownmap_module, spawnerSettings, debug_print, spawnedVehicles, spawnedMaps, spawnedOutfits, previewEntities, currentPreviewFile, constructor_lib, parse_ini_file, get_xml_element_content, get_xml_element, to_boolean, safe_tonumber, trim, split_str, request_model_load, xmlVehiclesFolder, iniVehiclesFolder, jsonVehiclesFolder, xmlMapsFolder, jsonMapsFolder, jobMapsFolder, xmlOutfitsFolder, jsonOutfitsFolder, previewRotation, spawnedProps, currentSelectedVehicleXml, currentSelectedVehicleIni, chrxVehiclesFolder, chrxOutfitsFolder

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
    jobMapsFolder = context.jobMapsFolder
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
    -- Initialize parser sub-modules with shared utilities
    local parserCtx = {
        safe_tonumber = M.safe_tonumber,
        trim = M.trim,
        split_str = M.split_str,
        to_boolean = M.to_boolean,
        debug_print = M.debug_print,
        get_xml_element_content = M.get_xml_element_content,
        get_xml_element = M.get_xml_element
    }
    xml_parser.init(parserCtx)
    ini_parser.init(parserCtx)
    json_parser.init(parserCtx)
    job_parser.init(parserCtx)
    
    -- Initialize spawn core with spawning context
    spawn_core.init({
        spawning = M,
        spawnerSettings = spawnerSettings,
        spawnedVehicles = spawnedVehicles,
        spawnedMaps = spawnedMaps,
        spawnedOutfits = spawnedOutfits,
        previewEntities = previewEntities,
        currentPreviewFile = currentPreviewFile,
        debug_print = M.debug_print,
        constructor_lib = constructor_lib
    })
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

-- Photo Preview state
local photoTextureCache = {} -- Cache for photo textures: pngPath -> textureId or "loading" or "failed" or "none"
local MAX_PHOTO_TEXTURES = 20 -- Limit loaded photo textures
local loadedPhotoTextureCount = 0

-- Helper: find a matching .png for a given file path (same name, same directory)
local function findMatchingPng(filePath)
    if not filePath then return nil end
    -- Strip the extension and replace with .png
    local basePath = filePath:match("^(.+)%.[^%.]+$")
    if not basePath then return nil end
    local pngPath = basePath .. ".png"
    if FileMgr.DoesFileExist(pngPath) then
        return pngPath
    end
    return nil
end

-- Load a photo texture (async, cached)
local function loadPhotoTexture(pngPath)
    if not pngPath then return nil end
    
    local cached = photoTextureCache[pngPath]
    if cached then
        return cached -- textureId, "loading", "failed", or "none"
    end
    
    -- Hard limit
    if loadedPhotoTextureCount >= MAX_PHOTO_TEXTURES then
        return "limit_reached"
    end
    
    -- Mark as loading and start async load
    photoTextureCache[pngPath] = "loading"
    
    FreemodeQueueJob(function()
        pcall(function()
            local safePath = pngPath:gsub("/", "\\")
            if FileMgr.DoesFileExist(safePath) then
                local texId = Texture.LoadTextureAsync(safePath)
                if texId and texId ~= 0 then
                    photoTextureCache[pngPath] = texId
                    loadedPhotoTextureCount = loadedPhotoTextureCount + 1
                else
                    photoTextureCache[pngPath] = "failed"
                end
            else
                photoTextureCache[pngPath] = "none"
            end
        end)
    end)
    
    return "loading"
end

-- Render a photo preview image inside a tooltip (call between BeginTooltip/EndTooltip)
local function renderPhotoPreviewInTooltip(pngPath)
    if not pngPath then return end
    
    local texResult = loadPhotoTexture(pngPath)
    
    if texResult == "loading" then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.7, 1.0)
        ImGui.Text("Loading preview...")
        ImGui.PopStyleColor()
        return
    end
    
    if texResult == "failed" or texResult == "none" or texResult == "limit_reached" then
        return
    end
    
    -- texResult should be a texture ID
    local texId = texResult
    if type(texId) ~= "number" or texId == 0 then return end
    
    if not Texture.IsTextureValid(texId) then return end
    
    local d3dTex = Texture.GetTexture(texId)
    if not d3dTex then return end
    
    local gpuTex = d3dTex:GetCurrent()
    if not gpuTex then return end
    
    -- Get texture dimensions for aspect ratio
    local texW = d3dTex:GetWidth()
    local texH = d3dTex:GetHeight()
    local imgWidth = spawnerSettings and spawnerSettings.photoPreviewWidth or 256
    local imgHeight = imgWidth -- default square
    
    if texW > 0 and texH > 0 then
        local aspect = texW / texH
        imgHeight = imgWidth / aspect
        if imgHeight > imgWidth * 1.5 then
            imgHeight = imgWidth * 1.5
        end
    end
    
    local cp_x, cp_y = ImGui.GetCursorScreenPos()
    ImGui.AddImage(gpuTex, cp_x, cp_y, cp_x + imgWidth, cp_y + imgHeight)
    ImGui.Dummy(imgWidth, imgHeight)
end

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

-- Helper function to detect ImpulseJamezGamez array-of-arrays format
-- Format: [ ["modelName", hash, x, y, z, rotX, rotY, rotZ, refX?, refY?, refZ?], ... ]
local function isImpulseArrayFormat(jsonData)
    return json_parser.isImpulseArrayFormat(jsonData)
end

local function countJsonChildren(jsonData)
    return json_parser.countJsonChildren(jsonData)
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
        local displayName = GTA.GetDisplayNameFromHash(hashNum)
            if displayName and displayName ~= "" and displayName ~= "null" then
                name = displayName
            end
    elseif entityType == "outfit" or entityType == "ped" then
        local modelName = GTA.GetModelNameFromHash(hashNum)
            if modelName and modelName ~= "" and modelName ~= "null" then
                name = modelName
            end
    else
        local displayName = GTA.GetDisplayNameFromHash(hashNum)
            if displayName and displayName ~= "" and displayName ~= "null" then
                name = displayName
            end
        if not name then
            local modelName = GTA.GetModelNameFromHash(hashNum)
                if modelName and modelName ~= "" and modelName ~= "null" then
                    name = modelName
                end
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
        local parsed = xml_parser.parseMetadata(content, filePath)
        if parsed then
            for k, v in pairs(parsed) do metadata[k] = v end
            -- Resolve model name from hash if parser didn't provide one
            if metadata.modelHash and not metadata.modelName then
                metadata.modelName = getModelNameFromHashForPreview(metadata.modelHash, metadata.itemType)
            end
        end
    elseif ext == "ini" then
        local parsed = ini_parser.parseMetadata(content, filePath)
        if parsed then
            for k, v in pairs(parsed) do metadata[k] = v end
            -- Resolve model name from hash if parser didn't provide one
            if metadata.modelHash and not metadata.modelName then
                metadata.modelName = getModelNameFromHashForPreview(metadata.modelHash, metadata.itemType)
            end
        end
    elseif ext == "json" then
        -- Try Job/Transform format first (use robust parser for large files)
        local parsedJob = job_parser.parseMetadata(content, filePath, asset_loader.json_decode)
        if parsedJob then
            for k, v in pairs(parsedJob) do metadata[k] = v end
        else
            local parsed = json_parser.parseMetadata(content, filePath, getModelNameFromHashForPreview)
            if parsed then
                for k, v in pairs(parsed) do metadata[k] = v end
            end
        end
    end
    
    contextPreviewCache[filePath] = metadata
    
    return metadata
end

-- Render context preview tooltip
local function renderContextPreviewTooltip(filePath, itemType)
    local showContext = spawnerSettings and spawnerSettings.contextPreview
    local showPhoto = spawnerSettings and spawnerSettings.photoPreview and itemType == "map"
    
    if not showContext and not showPhoto then return end
    if not filePath then return end
    
    -- Check for matching photo
    local pngPath = nil
    if showPhoto then
        pngPath = findMatchingPng(filePath)
    end
    
    -- If only photo preview is enabled but no photo exists, and context is off, skip
    if not showContext and not pngPath then return end
    
    local metadata = nil
    if showContext then
        metadata = parseFileMetadata(filePath, itemType)
        if not metadata and not pngPath then return end
    end
    
    ImGui.BeginTooltip()
    
    -- Render photo preview first (above stats)
    if pngPath then
        renderPhotoPreviewInTooltip(pngPath)
        if showContext and metadata then
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
        end
    end
    
    -- Render context preview stats
    if showContext and metadata then
        -- Get network limits using natives
        local maxObjects = NETWORK.GET_MAX_NUM_NETWORK_OBJECTS()
        local maxVehicles = NETWORK.GET_MAX_NUM_NETWORK_VEHICLES()
        local maxPeds = NETWORK.GET_MAX_NUM_NETWORK_PEDS()
        
        -- Helper to determine if count is under limit
        local function isUnderLimit(count, limit)
            if limit <= 0 then return true end -- If we can't get the limit, assume ok
            return count < limit
        end
        
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
    end
    
    ImGui.EndTooltip()
end

-- Public function to handle hover callback for context preview
function M.handleContextPreviewHover(fileInfo)
    local showContext = spawnerSettings and spawnerSettings.contextPreview
    local showPhoto = spawnerSettings and spawnerSettings.photoPreview
    
    if not showContext and not showPhoto then return end
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
        local n = tonumber(str:sub(3), 16)
        if n then return n end
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

-- Apply F1/Racing wheels (wheel type 10) to a vehicle if setting is enabled
function M.applyF1WheelsIfEnabled(vehicleHandle)
    if spawnerSettings and spawnerSettings.spawnWithF1Wheels and vehicleHandle and vehicleHandle ~= 0 then
        VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicleHandle, 10)
        M.debug_print("[Spawn] Applied F1/Racing wheels to vehicle: " .. tostring(vehicleHandle))
    end
end

function M.finalizePreviewVehicle(entities)
    for _, entity in ipairs(entities) do
        ENTITY.FREEZE_ENTITY_POSITION(entity, false)
        ENTITY.SET_ENTITY_COLLISION(entity, true, true)
        ENTITY.SET_ENTITY_PROOFS(entity, false, false, false, false, false, false, false, false)
    end
end

function M.parse_outfit_ped_data(xmlContent)
    return xml_parser.parse_outfit_ped_data(xmlContent)
end

function M.parse_task_sequence(taskSequenceXml, autoStartFlag)
    return xml_parser.parse_task_sequence(taskSequenceXml, autoStartFlag)
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
    end
end

function M.run_ptfx_task(entityHandle, task)
    if not task or not (task.EffectName and task.AssetName) then return end
    if not GRAPHICS then return end
    
    FreemodeQueueJob(function()
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
                handle = startFunc(
                        task.EffectName, entityHandle,
                        pos.x or 0.0, pos.y or 0.0, pos.z or 0.0,
                        rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                        scale, false, false, false
                    )
            end
            
            if handle and handle ~= 0 then
                -- Apply color and scale
                GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                
                -- Refresh loop - keep effect alive with 150ms interval
                FreemodeQueueJob(function()
                    while ENTITY.DOES_ENTITY_EXIST(entityHandle) do
                        Script.Yield(150)
                        if not ENTITY.DOES_ENTITY_EXIST(entityHandle) then break end
                        
                        -- Stop and restart the effect
                        GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false)
                        
                        if not ensure_ptfx_asset_loaded(task.AssetName) then break end
                        
                        GRAPHICS.USE_PARTICLE_FX_ASSET(task.AssetName)
                        
                        local newHandle = nil
                        if startFunc then
                            newHandle = startFunc(
                                    task.EffectName, entityHandle,
                                    pos.x or 0.0, pos.y or 0.0, pos.z or 0.0,
                                    rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                                    scale, false, false, false
                                )
                        end
                        
                        if newHandle and newHandle ~= 0 then
                            handle = newHandle
                            GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                            GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                            GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                        else
                            break
                        end
                    end
                    
                    -- Cleanup
                    if handle then
                        GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false)
                    end
                end)
            end
        else
            -- Non-looped particle FX
            if task.Colour then
                GRAPHICS.SET_PARTICLE_FX_NON_LOOPED_COLOUR(r, g, b)
            end
            
            GRAPHICS.START_PARTICLE_FX_NON_LOOPED_ON_ENTITY(
                task.EffectName, entityHandle,
                pos.x or 0.0, pos.y or 0.0, pos.z or 0.0,
                rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                scale, false, false, false
            )
        end
    end)
end

function M.parse_ini_file(filePath)
    return ini_parser.parse_ini_file(filePath)
end

function M.request_model_load(hashOrName)
    if not hashOrName then return end
    local model = M.safe_tonumber(hashOrName, nil) or hashOrName
    if model then
        STREAMING.REQUEST_MODEL(model)
    end
end

function M.apply_ped_properties(pedHandle, pedProperties)
    if not pedHandle or pedHandle == 0 or not pedProperties then return end
    if pedProperties.IsStill ~= nil then
        PED.SET_PED_ENABLE_WEAPON_BLOCKING(pedHandle, M.to_boolean(pedProperties.IsStill))
    end
    if pedProperties.CanRagdoll ~= nil then
        local canRagdoll = M.to_boolean(pedProperties.CanRagdoll)
        PED.SET_PED_CAN_RAGDOLL(pedHandle, canRagdoll)
    end
    if pedProperties.HasShortHeight ~= nil then
        PED.SET_PED_CONFIG_FLAG(pedHandle, 223, M.to_boolean(pedProperties.HasShortHeight))
    end
    if pedProperties.Armour ~= nil then
        local armour = M.safe_tonumber(pedProperties.Armour, 0)
        PED.SET_PED_ARMOUR(pedHandle, armour)
    end
    if pedProperties.CurrentWeapon ~= nil then
        local weaponHash = M.safe_tonumber(pedProperties.CurrentWeapon, nil)
        if weaponHash and weaponHash ~= 0 then
            WEAPON.GIVE_WEAPON_TO_PED(pedHandle, weaponHash, 9999, true, true)
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
                    PED.SET_PED_PROP_INDEX(pedHandle, propId, propData.prop_id, propData.texture_id, true)
                else
                    PED.CLEAR_PED_PROP(pedHandle, propId)
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
                PED.SET_PED_COMPONENT_VARIATION(pedHandle, compId, compData.comp_id, compData.texture_id, 0)
            end
        end
    end
    if pedProperties.RelationshipGroup ~= nil then
        local relGroup = M.safe_tonumber(pedProperties.RelationshipGroup, nil)
        if relGroup then
            PED.SET_PED_RELATIONSHIP_GROUP_HASH(pedHandle, relGroup)
        end
    end
    if pedProperties.AnimActive == "true" and pedProperties.AnimDict and pedProperties.AnimName then
        local animDict = pedProperties.AnimDict
        local animName = pedProperties.AnimName
        STREAMING.REQUEST_ANIM_DICT(animDict)
            local t0 = Time.GetEpoche()
            while not STREAMING.HAS_ANIM_DICT_LOADED(animDict) and Time.GetEpoche() - t0 < 2 do
                Script.Yield(10)
            end
            if STREAMING.HAS_ANIM_DICT_LOADED(animDict) then
                TASK.TASK_PLAY_ANIM(pedHandle, animDict, animName, 8.0, 8.0, -1, 1, 1.0, false, false, false)
                PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(pedHandle, true)
            end
    end
end

function M.parse_ini_attachments(iniData, mainVehicleSelfNumeration)
    return ini_parser.parse_ini_attachments(iniData, mainVehicleSelfNumeration)
end

function M.parse_spooner_attachments(xml)
    return xml_parser.parse_spooner_attachments(xml)
end


function M.create_by_type(model, typ, coords)
    local mnum = M.safe_tonumber(model, model)
    M.request_model_load(mnum)
    if typ == "1" or typ == 1 then
        local h = GTA.CreatePed(mnum, 26, coords.x, coords.y, coords.z, 0, true, true)
        if h and h ~= 0 then
            ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF)
            return h
        end
        h = GTA.CreateRandomPed(coords.x, coords.y, coords.z)
        if h and h ~= 0 then
            ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF)
            return h
        end
        return 0
    end
    if typ == "2" or typ == 2 then
        local h = GTA.SpawnVehicle(mnum, coords.x, coords.y, coords.z, 0, true, true)
        if h and h ~= 0 then
            ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF)
            return h
        end
        return 0
    end
    if typ == "3" or typ == 3 then
        local h = GTA.CreateObject(mnum, coords.x, coords.y, coords.z, true, true)
        if h and h ~= 0 then
            if ENTITY.SET_ENTITY_COORDS then ENTITY.SET_ENTITY_COORDS(h, coords.x, coords.y, coords.z, false, false, false, true) end
            ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF)
            return h
        end
        h = GTA.CreateWorldObject(mnum, coords.x, coords.y, coords.z, true, true)
        if h and h ~= 0 then
            if ENTITY.SET_ENTITY_COORDS then ENTITY.SET_ENTITY_COORDS(h, coords.x, coords.y, coords.z, false, false, false, true) end
            ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF)
            return h
        end
        h = GTA.SpawnVehicle(mnum, coords.x, coords.y, coords.z, 0, true, true)
        if h and h ~= 0 then
            ENTITY.SET_ENTITY_LOD_DIST(h, 0xFFFF)
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
    playerPed = GTA.GetLocalPed()
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
        local t0 = Time.GetEpoche()
        while not STREAMING.HAS_MODEL_LOADED(M.safe_tonumber(model, model) or model) and Time.GetEpoche() - t0 < 0.3 do
            Script.Yield(10)
        end
        if not STREAMING.HAS_MODEL_LOADED(M.safe_tonumber(model, model) or model) then
            Logger.LogError("[Spawn] Model failed to load: '" .. attachmentName .. "' (hash: " .. tostring(model) .. ")")
        end
        local h = M.create_by_type(model, att.Type, spawnCoords)
        if not h or h == 0 then
            GUI.AddToast("Spawn Error", "Failed to spawn " .. (att.HashName or tostring(att.ModelHash)), 5000, 0)
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
            ENTITY.SET_ENTITY_COLLISION(h, false, false)
        else
            if finalCollisionProof then
                -- Use multiple methods to ensure collision is disabled
                
                -- Method 1: SET_ENTITY_COLLISION
                ENTITY.SET_ENTITY_COLLISION(h, false, false)
                
                -- Method 2: SET_ENTITY_COMPLETELY_DISABLE_COLLISION (more aggressive)
                if ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION then
                        ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(h, false, true)
                    end
                
                -- Method 3: For peds, disable collision with player's vehicle
                if tostring(att.Type) == "1" then
                    local playerPed = PLAYER.PLAYER_PED_ID()
                        if playerPed and playerPed ~= 0 then
                            local playerVehicle = PED.GET_VEHICLE_PED_IS_IN(playerPed, false)
                            if playerVehicle and playerVehicle ~= 0 then
                                ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(h, playerVehicle, true)
                            end
                        end
                    
                    -- Also disable ragdoll for peds to prevent physics issues
                    if PED.SET_PED_CAN_RAGDOLL then
                            PED.SET_PED_CAN_RAGDOLL(h, false)
                        end
                end
                
                -- Method 4: SET_ENTITY_PROOFS with collision proof
                ENTITY.SET_ENTITY_PROOFS(h, false, false, false, true, false, false, false, false)
            end
        end

        if att.OpacityLevel ~= nil then
            local opacityLevel = M.safe_tonumber(att.OpacityLevel, nil)
            if opacityLevel ~= nil and opacityLevel == 0 then
                ENTITY.SET_ENTITY_ALPHA(h, 0, false)
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
                    VEHICLE.SET_VEHICLE_COLOURS(h, colors.Primary or 0, colors.Secondary or 0)
                end
                
                if colors.IsPrimaryColourCustom then
                    VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(h, colors.Cust1_R, colors.Cust1_G, colors.Cust1_B)
                end

                if colors.IsSecondaryColourCustom then
                    VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(h, colors.Cust2_R, colors.Cust2_G, colors.Cust2_B)
                end

                if colors.Pearl ~= nil or colors.Rim ~= nil then
                    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(h, colors.Pearl or 0, colors.Rim or 0)
                end
                if colors.tyreSmoke_R and colors.tyreSmoke_G and colors.tyreSmoke_B then
                    VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(h, colors.tyreSmoke_R, colors.tyreSmoke_G, colors.tyreSmoke_B)
                end
                if colors.LrInterior and colors.LrInterior > 0 then VEHICLE.SET_VEHICLE_EXTRA_COLOUR_5(h, colors.LrInterior) end
                if colors.LrDashboard and colors.LrDashboard > 0 then VEHICLE.SET_VEHICLE_EXTRA_COLOUR_6(h, colors.LrDashboard) end
            end
            
            if vp.Mods then
                VEHICLE.SET_VEHICLE_MOD_KIT(h, 0)
                for modId, modData in pairs(vp.Mods) do
                    if modData and modData.mod and modData.mod >= 0 then VEHICLE.SET_VEHICLE_MOD(h, modId, modData.mod, false) end
                end
            end
            
            if vp.Livery and vp.Livery >= 0 then VEHICLE.SET_VEHICLE_LIVERY(h, vp.Livery) end
            if vp.NumberPlateText then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(h, vp.NumberPlateText) end
            if vp.NumberPlateIndex then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(h, vp.NumberPlateIndex) end
            if vp.WheelType then VEHICLE.SET_VEHICLE_WHEEL_TYPE(h, vp.WheelType) end
            if vp.WindowTint and vp.WindowTint >= 0 then VEHICLE.SET_VEHICLE_WINDOW_TINT(h, vp.WindowTint) end
            if vp.DirtLevel then VEHICLE.SET_VEHICLE_DIRT_LEVEL(h, vp.DirtLevel) end
            if vp.BulletProofTyres ~= nil then VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(h, not vp.BulletProofTyres) end
            if vp.EngineOn ~= nil and spawnerSettings.vehicleEngineOn and vp.EngineOn then VEHICLE.SET_VEHICLE_ENGINE_ON(h, true, true, false) end
            
            if vp.Neons then
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 0, vp.Neons.Left or false)
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 1, vp.Neons.Right or false)
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 2, vp.Neons.Front or false)
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 3, vp.Neons.Back or false)
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 0, vp.Neons.Left or false) end
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 1, vp.Neons.Right or false) end
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 2, vp.Neons.Front or false) end
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 3, vp.Neons.Back or false) end
                if vp.Neons.R and vp.Neons.G and vp.Neons.B then
                    VEHICLE.SET_VEHICLE_EXTRA_COLOUR_6(h, vp.Neons.R, vp.Neons.G, vp.Neons.B)
                end
            end
            
        end
        
        -- Apply INI vehicle properties if this is a vehicle attachment from INI
        if att.VehicleMods or att.VehicleToggles or att.VehicleColors or att.Neons then
            
            -- Set mod kit first
            VEHICLE.SET_VEHICLE_MOD_KIT(h, 0)
            
            -- Apply vehicle mods
            if att.VehicleMods then
                for modId, modValue in pairs(att.VehicleMods) do
                    if modValue >= -1 then
                        VEHICLE.SET_VEHICLE_MOD(h, modId, modValue, false)
                    end
                end
            end
            
            -- Apply vehicle toggles
            if att.VehicleToggles then
                for toggleId, toggleValue in pairs(att.VehicleToggles) do
                    VEHICLE.TOGGLE_VEHICLE_MOD(h, toggleId, toggleValue)
                end
            end
            
            -- Apply vehicle extras
            if att.VehicleExtras then
                for extraId, extraEnabled in pairs(att.VehicleExtras) do
                    VEHICLE.SET_VEHICLE_EXTRA(h, extraId, not extraEnabled)
                end
            end
            
            -- Apply standard vehicle colors
            if att.VehicleColors then
                if att.VehicleColors.Primary or att.VehicleColors.Secondary then
                    VEHICLE.SET_VEHICLE_COLOURS(h, att.VehicleColors.Primary or 0, att.VehicleColors.Secondary or 0)
                end
            end
            
            -- Apply custom colors
            if att.IsCustomPrimary and att.CustomPrimaryColor then
                VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(h, 
                    att.CustomPrimaryColor.R, att.CustomPrimaryColor.G, att.CustomPrimaryColor.B)
            end
            
            if att.IsCustomSecondary and att.CustomSecondaryColor then
                VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(h, 
                    att.CustomSecondaryColor.R, att.CustomSecondaryColor.G, att.CustomSecondaryColor.B)
            end
            
            -- Apply extra colors (pearlescent, wheel)
            if att.ExtraColors then
                if att.ExtraColors.Pearl or att.ExtraColors.Wheel then
                    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(h, 
                        att.ExtraColors.Pearl or 0, att.ExtraColors.Wheel or 0)
                end
            end
            
            -- Apply neon lights
            if att.Neons then
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 0, att.Neons.Enabled0 or false)
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 1, att.Neons.Enabled1 or false)
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 2, att.Neons.Enabled2 or false)
                VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 3, att.Neons.Enabled3 or false)
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 0, att.Neons.Enabled0 or false) end
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 1, att.Neons.Enabled1 or false) end
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 2, att.Neons.Enabled2 or false) end
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(h, 3, att.Neons.Enabled3 or false) end
            end
            
            -- Apply neon color
            if att.NeonColor then
                VEHICLE.SET_VEHICLE_EXTRA_COLOUR_6(h, 
                    att.NeonColor.R, att.NeonColor.G, att.NeonColor.B)
            end
            
            -- Apply tire smoke color
            if att.TireSmoke then
                VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(h, 
                    att.TireSmoke.R, att.TireSmoke.G, att.TireSmoke.B)
            end
            
            -- Apply wheel type
            if att.WheelType then
                VEHICLE.SET_VEHICLE_WHEEL_TYPE(h, att.WheelType)
            end
            
            -- Apply numberplate
            if att.Numberplate then
                if att.Numberplate.Text then
                    VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(h, att.Numberplate.Text)
                end
                if att.Numberplate.Index then
                    VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(h, att.Numberplate.Index)
                end
            end
            
            -- Apply window tint
            if att.WindowTint and att.WindowTint >= 0 then
                VEHICLE.SET_VEHICLE_WINDOW_TINT(h, att.WindowTint)
            end
            
            -- Apply paint fade (dirt level)
            if att.PaintFade then
                VEHICLE.SET_VEHICLE_DIRT_LEVEL(h, att.PaintFade)
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
                local ok, err = ENTITY.ATTACH_ENTITY_TO_ENTITY(
                        m.created,
                        parentHandle,
                        m.bone,
                        m.x, m.y, m.z,
                        m.pitch, m.roll, m.yaw,
                        false, false, not m.iscollisionproof, m.isped, 2, true
                    )
                if ok then
                    M.debug_print("[Spawn] âœ“ Attached '" .. (m.name or "Unknown") .. "' to '" .. (m.parentName or "Parent") .. "'")
                    
                    -- Re-apply collision AFTER attachment (attachment may reset collision state)
                    if m.iscollisionproof then
                        ENTITY.SET_ENTITY_COLLISION(m.created, false, false)
                        if ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION then
                                ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(m.created, false, true)
                            end
                        -- For peds, extra methods
                        if m.isped then
                            if PED.SET_PED_CAN_RAGDOLL then
                                    PED.SET_PED_CAN_RAGDOLL(m.created, false)
                                end
                            -- Disable collision with parent
                            ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(m.created, parentHandle, true)
                        end
                    end
                end
            else
                M.debug_print("[Spawn] âœ— Failed to attach '" .. (m.name or "Unknown") .. "' - parent '" .. (m.parentName or tostring(m.attachedto)) .. "' not found")
            end
        else
            M.debug_print("[Spawn] '" .. (m.name or "Unknown") .. "' is a root entity (no parent attachment)")
        end
    end
    return created
end

function M.clearPreview()
    FreemodeQueueJob(function()
        for _, entity in ipairs(previewEntities) do
            if entity and ENTITY.DOES_ENTITY_EXIST(entity) then
                constructor_lib.delete_entity(entity)
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
    FreemodeQueueJob(function()
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
    previewUpdateJob = FreemodeQueueJob(function()
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
    return xml_parser.parse_vehicle_mods(xml)
end

function M.parse_vehicle_colors(xml)
    return xml_parser.parse_vehicle_colors(xml)
end

function M.parse_vehicle_neons(xml)
    return xml_parser.parse_vehicle_neons(xml)
end

function M.parse_map_placements(xml)
    return xml_parser.parse_map_placements(xml)
end

function M.parse_outfit_attachments(xmlContent)
    return xml_parser.parse_outfit_attachments(xmlContent)
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
    FreemodeQueueJob(function()
        if vehicleData.attachments then
            for _, attachmentHandle in ipairs(vehicleData.attachments) do
                if attachmentHandle and attachmentHandle ~= 0 then
                    if ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                            local entityType = ENTITY.GET_ENTITY_TYPE(attachmentHandle)
                            if not entityType or entityType < 0 or entityType > 3 then
                                return
                            end
                            constructor_lib.delete_entity(attachmentHandle)
else
                            M.debug_print("[Delete Debug] Warning: Attachment entity does not exist for handle:", tostring(attachmentHandle))
                        end
                end
            end
        end
        if vehicleData.vehicle and vehicleData.vehicle ~= 0 then
            if ENTITY.DOES_ENTITY_EXIST(vehicleData.vehicle) then
                    local entityType = ENTITY.GET_ENTITY_TYPE(vehicleData.vehicle)
                    if entityType ~= 2 then
                        return
                    end
                    constructor_lib.delete_entity(vehicleData.vehicle)
                end
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
    FreemodeQueueJob(function()
        if mapData.entities then
            for _, entityHandle in ipairs(mapData.entities) do
                if entityHandle and entityHandle ~= 0 then
                    if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                            constructor_lib.delete_entity(entityHandle)
end
                end
            end
        end
    end)
    table.remove(spawnedMaps, index)
end

-- Put player into a vehicle (drive it)
function M.driveVehicle(vehicleHandle)
    if not vehicleHandle or vehicleHandle == 0 then return end
    FreemodeQueueJob(function()
        if not ENTITY.DOES_ENTITY_EXIST(vehicleHandle) then
            GUI.AddToast("Error", "Vehicle no longer exists", 3000, 0)
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
    FreemodeQueueJob(function()
        local playerPed = PLAYER.PLAYER_PED_ID()
        if playerPed and playerPed ~= 0 then
            ENTITY.SET_ENTITY_COORDS(playerPed, refCoords.x or 0, refCoords.y or 0, refCoords.z or 0, false, false, false, true)
        end
    end)
end

-- Bring a loaded map to the player's current position
-- This deletes the existing map and respawns it at the player's location
function M.bringMapToPlayer(mapIndex)
    if not spawnedMaps or not spawnedMaps[mapIndex] then return end
    
    -- Get map data before deletion
    local mapData = spawnedMaps[mapIndex]
    local filePath = mapData.filePath
    
    if not filePath then
        GUI.AddToast("Bring Map", "No file path stored for this map", 3000, 0)
        return
    end
    
    FreemodeQueueJob(function()
        -- Delete all entities from this map
        if mapData.entities then
            for _, entityHandle in ipairs(mapData.entities) do
                if entityHandle and entityHandle ~= 0 then
                    if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                            constructor_lib.delete_entity(entityHandle)
end
                end
            end
        end
        
        -- Remove from spawnedMaps table
        table.remove(spawnedMaps, mapIndex)
        
        -- Wait a moment for entities to be deleted
        Script.Yield(100)
        
        -- Now respawn the map at player's location
        -- Pass options to override settings specifically for this spawn
        M.spawnMapFromXML(filePath, { 
            spawnMapOnMe = true, 
            teleportToMap = false, 
            deleteOldMap = false 
        })
        
        local fileName = M.get_filename_from_path(filePath)
            GUI.AddToast("Map Brought", "Respawned " .. fileName .. " at your location", 3000, 0)
    end)
end

function M.deleteAllSpawnedVehicles()
    FreemodeQueueJob(function()
        local vehiclesToDelete = {}
        for _, vehicleData in pairs(spawnedVehicles) do
            table.insert(vehiclesToDelete, vehicleData)
        end
        for i, vehicleData in ipairs(vehiclesToDelete) do
            if vehicleData.attachments then
                for _, attachmentHandle in ipairs(vehicleData.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        if ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                                local entityType = ENTITY.GET_ENTITY_TYPE(attachmentHandle)
                                if not entityType or entityType < 0 or entityType > 3 then
                                    return
                                end
                                constructor_lib.delete_entity(attachmentHandle)
else
                                M.debug_print("[Delete Debug] Warning: Attachment entity does not exist for handle:", tostring(attachmentHandle))
                            end
                    end
                end
            end
            if vehicleData.vehicle and vehicleData.vehicle ~= 0 then
                if ENTITY.DOES_ENTITY_EXIST(vehicleData.vehicle) then
                        local entityType = ENTITY.GET_ENTITY_TYPE(vehicleData.vehicle)
                        if entityType ~= 2 then
                            return
                        end
                        constructor_lib.delete_entity(vehicleData.vehicle)
                    end
            end
        end
        for k in pairs(spawnedVehicles) do spawnedVehicles[k] = nil end
    end)
end

function M.deleteAllSpawnedMaps()
    FreemodeQueueJob(function()
        local mapsToDelete = {}
        for _, mapData in pairs(spawnedMaps) do
            table.insert(mapsToDelete, mapData)
        end
        for i, mapData in ipairs(mapsToDelete) do
            if mapData.entities then
                for j, entityHandle in ipairs(mapData.entities) do
                    if entityHandle and entityHandle ~= 0 then
                        if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                                constructor_lib.delete_entity(entityHandle)
                            end
                    end
                end
            end
        end
        for k in pairs(spawnedMaps) do spawnedMaps[k] = nil end
    end)
end

function M.deleteAllSpawnedOutfits()
    FreemodeQueueJob(function()
        local outfitsToDelete = {}
        for _, outfitData in pairs(spawnedOutfits) do
            table.insert(outfitsToDelete, outfitData)
        end
        for i, outfitData in ipairs(outfitsToDelete) do
            if outfitData.spawnedPed then
                if ENTITY.DOES_ENTITY_EXIST(outfitData.spawnedPed) then
                        constructor_lib.delete_entity(outfitData.spawnedPed)
                    end
            end
            if outfitData.attachments then
                for j, attachmentHandle in ipairs(outfitData.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        if ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                                constructor_lib.delete_entity(attachmentHandle)
else
                                M.debug_print("[Delete Debug] Warning: Outfit attachment entity does not exist for handle:", tostring(attachmentHandle))
                            end
                    end
                end
            end
        end
        for k in pairs(spawnedOutfits) do spawnedOutfits[k] = nil end
    end)
end

function M.spawnVehicleFromINI(filePath, isPreview)
    isPreview = isPreview or false
    FreemodeQueueJob(function()
        -- Pre-spawn checks
        local err = spawn_core.preSpawnChecks(filePath, isPreview, "INI")
        if err then return end
        
        -- Parse INI
        local iniData = M.parse_ini_file(filePath)
        if not iniData then
            M.debug_print("[Spawn Debug] Error: Failed to parse INI file:", filePath)
            return
        end
        local mainVehicleSection = iniData.Vehicle or iniData.Vehicle0
        if not mainVehicleSection then
            M.debug_print("[Spawn Debug] Error: Main vehicle section not found in INI file:", filePath)
            return
        end
        local modelHashStr = mainVehicleSection.Hash or mainVehicleSection.ModelHash or mainVehicleSection.Model or mainVehicleSection.model
        if not modelHashStr then
            M.debug_print("[Spawn Debug] Error: Vehicle model hash not found in INI file:", filePath)
            return
        end
        local modelHash = M.safe_tonumber(modelHashStr, nil)
        if not modelHash then
            M.debug_print("[Spawn Debug] Error: Invalid vehicle model hash:", modelHashStr)
            return
        end
        
        -- Get player info
        local playerInfo = spawn_core.getPlayerSpawnInfo()
        if not playerInfo then return end
        local previewCoords = isPreview and spawn_core.getPreviewCoords(playerInfo) or nil
        
        -- Delete old vehicles
        spawn_core.deleteOldIfEnabled(isPreview)
        
        -- Spawn vehicle handle
        local vehicleHandle = spawn_core.spawnVehicleHandle(modelHash, playerInfo, isPreview)
        if not vehicleHandle or vehicleHandle == 0 then
            spawn_core.logSpawnFailure(filePath, modelHash)
            return
        end
        
        -- Apply vehicle properties from INI
        local createdAttachments = {}
        
        if not spawn_core.applyRandomColorIfEnabled(vehicleHandle) and mainVehicleSection then
            -- Apply colors from INI data
            local primaryPaint = M.safe_tonumber(mainVehicleSection["primary paint"], nil)
            local secondaryPaint = M.safe_tonumber(mainVehicleSection["secondary paint"], nil)
            if primaryPaint ~= nil and secondaryPaint ~= nil then
                VEHICLE.SET_VEHICLE_COLOURS(vehicleHandle, primaryPaint, secondaryPaint)
            end
            local customPrimaryColour = M.safe_tonumber(mainVehicleSection["custom primary colour"], nil)
            local customSecondaryColour = M.safe_tonumber(mainVehicleSection["custom secondary colour"], nil)
            if customPrimaryColour ~= nil and customSecondaryColour ~= nil then
                VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicleHandle, customPrimaryColour, customPrimaryColour, customPrimaryColour)
                VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicleHandle, customSecondaryColour, customSecondaryColour, customSecondaryColour)
            end
            local pearlescentColour = M.safe_tonumber(mainVehicleSection["pearlescent colour"], nil)
            local wheelColour = M.safe_tonumber(mainVehicleSection["wheel colour"], nil)
            if pearlescentColour ~= nil and wheelColour ~= nil then
                VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicleHandle, pearlescentColour, wheelColour)
            end
            local tyreSmokeR = M.safe_tonumber(mainVehicleSection["tyre smoke red"], nil)
            local tyreSmokeG = M.safe_tonumber(mainVehicleSection["tyre smoke green"], nil)
            local tyreSmokeB = M.safe_tonumber(mainVehicleSection["tyre smoke blue"], nil)
            if tyreSmokeR and tyreSmokeG and tyreSmokeB then
                VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(vehicleHandle, tyreSmokeR, tyreSmokeG, tyreSmokeB)
            end
            local neonR = M.safe_tonumber(mainVehicleSection["neon red"], nil)
            local neonG = M.safe_tonumber(mainVehicleSection["neon green"], nil)
            local neonB = M.safe_tonumber(mainVehicleSection["neon blue"], nil)
            if neonR and neonG and neonB then
                VEHICLE.SET_VEHICLE_EXTRA_COLOUR_6(vehicleHandle, neonR, neonG, neonB)
            end
            for i = 0, 3 do
                local neonEnabled = M.to_boolean(mainVehicleSection["neon " .. i])
                VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, i, neonEnabled)
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, i, neonEnabled) end
            end
            local windowTint = M.safe_tonumber(mainVehicleSection["window tint"], nil)
            if windowTint ~= nil and windowTint >= 0 then VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicleHandle, windowTint) end
            local plateIndex = M.safe_tonumber(mainVehicleSection["plate index"], nil)
            if plateIndex ~= nil then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(vehicleHandle, plateIndex) end
            local plateText = mainVehicleSection["plate text"]
            if plateText then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicleHandle, plateText) end
            local wheelType = M.safe_tonumber(mainVehicleSection["wheel type"], nil)
            if wheelType ~= nil then VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicleHandle, wheelType) end
            local bulletproofTyres = M.to_boolean(mainVehicleSection["bulletproof tyres"])
            VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicleHandle, not bulletproofTyres)
            local dirtLevel = M.safe_tonumber(mainVehicleSection["dirt level"], nil)
            if dirtLevel ~= nil then VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicleHandle, dirtLevel) end
            local engineOn = M.to_boolean(mainVehicleSection.EngineOn)
            if spawnerSettings.vehicleEngineOn and engineOn then VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, true, true, false) end
            if spawnerSettings.radioOff then AUDIO.SET_VEHICLE_RADIO_ENABLED(vehicleHandle, false) end
            local paintFade = M.safe_tonumber(mainVehicleSection.PaintFade, nil)
            if paintFade ~= nil then VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicleHandle, paintFade) end
        end
        
        -- Livery
        if not spawn_core.applyRandomLiveryIfEnabled(vehicleHandle) and mainVehicleSection then
            local livery = M.safe_tonumber(mainVehicleSection.Livery, nil)
            if livery and livery >= 0 then VEHICLE.SET_VEHICLE_LIVERY(vehicleHandle, livery) end
        end
        
        -- Mods
        local modsSection = iniData["Vehicle Mods"]
        if not spawn_core.applyMaxUpgradesIfEnabled(vehicleHandle) then
            VEHICLE.SET_VEHICLE_MOD_KIT(vehicleHandle, 0)
            if modsSection then
                for modIdStr, modValueStr in pairs(modsSection) do
                    local modId = M.safe_tonumber(modIdStr, nil)
                    local modValue = M.safe_tonumber(modValueStr, -1)
                    if modId ~= nil and modValue >= -1 then
                        VEHICLE.SET_VEHICLE_MOD(vehicleHandle, modId, modValue, false)
                    end
                end
            else
                for key, value in pairs(mainVehicleSection) do
                    local modId = M.safe_tonumber(key, nil)
                    if modId ~= nil and modId >= 0 and modId <= 50 then
                        local modValue = M.safe_tonumber(value, -1)
                        if modValue >= -1 then VEHICLE.SET_VEHICLE_MOD(vehicleHandle, modId, modValue, false) end
                    end
                end
            end
        end
        
        -- Toggles
        local togglesSection = iniData["Vehicle Toggles"]
        if togglesSection then
            for toggleIdStr, toggleValueStr in pairs(togglesSection) do
                local toggleId = M.safe_tonumber(toggleIdStr, nil)
                if toggleId then VEHICLE.TOGGLE_VEHICLE_MOD(vehicleHandle, toggleId, M.to_boolean(toggleValueStr)) end
            end
        end
        
        -- Spawner settings
        spawn_core.applySpawnerSettings(vehicleHandle, isPreview)
        
        -- Opacity/visibility
        local opacityLevel = M.safe_tonumber(mainVehicleSection.OpacityLevel, nil)
        if opacityLevel ~= nil and opacityLevel == 0 then
            ENTITY.SET_ENTITY_ALPHA(vehicleHandle, 0, false)
        end
        local isVisible = mainVehicleSection.IsVisible
        if isVisible ~= nil then
            ENTITY.SET_ENTITY_VISIBLE(vehicleHandle, M.to_boolean(isVisible), false)
        end
        
        -- Attachments
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
            local fallbackCoords = previewCoords or { x = 0, y = 0, z = 0 }
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, fallbackCoords, spawnerSettings.disableCollision, isPreview)
            for _, h in ipairs(createdAttachments) do ENTITY.SET_ENTITY_INVINCIBLE(h, true) end
        end
        spawnerSettings.inVehicle = originalInVehicleSetting
        
        -- Preview or register
        if isPreview then
            spawn_core.handlePreviewEntities(vehicleHandle, createdAttachments)
            return
        end
        spawn_core.registerSpawnedVehicle(vehicleHandle, createdAttachments, filePath)
        spawn_core.enterVehicleIfEnabled(vehicleHandle, playerInfo.ped, isPreview, false)
    end)
end

function M.spawnVehicleFromXML(filePath, isPreview)
    isPreview = isPreview or false
    FreemodeQueueJob(function()
        -- Pre-spawn checks
        local err = spawn_core.preSpawnChecks(filePath, isPreview, "XML")
        if err then return end
        
        -- Read and parse XML
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then
            M.debug_print("[Spawn Debug] Error: Failed to read XML file:", filePath)
            return
        end
        local modelHashStr = M.get_xml_element_content(xmlContent, "ModelHash")
        if not modelHashStr then
            M.debug_print("[Spawn Debug] Error: 'ModelHash' not found in XML:", filePath)
            return
        end
        local modelHash = M.safe_tonumber(modelHashStr, nil)
        if not modelHash then
            M.debug_print("[Spawn Debug] Error: Invalid ModelHash:", modelHashStr)
            return
        end
        
        -- Get player info
        local playerInfo = spawn_core.getPlayerSpawnInfo()
        if not playerInfo then return end
        local previewCoords = isPreview and spawn_core.getPreviewCoords(playerInfo, 15.0) or nil
        
        -- Delete old vehicles
        spawn_core.deleteOldIfEnabled(isPreview)
        
        -- Spawn vehicle handle
        local vehicleHandle = spawn_core.spawnVehicleHandle(modelHash, playerInfo, isPreview)
        if not vehicleHandle or vehicleHandle == 0 then
            spawn_core.logSpawnFailure(filePath, modelHash)
            return
        end
        
        -- Parse vehicle data from XML
        local createdAttachments = {}
        local initialHandleMap = {}
        local initialHandleVal = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
        if initialHandleVal then initialHandleMap[initialHandleVal] = vehicleHandle end
        local colors = M.parse_vehicle_colors(xmlContent)
        local mods = M.parse_vehicle_mods(xmlContent)
        local neons = M.parse_vehicle_neons(xmlContent)
        local vehicleProperties = M.get_xml_element(xmlContent, "VehicleProperties")
        
        -- Apply colors
        if not spawn_core.applyRandomColorIfEnabled(vehicleHandle) then
            if colors then
                if colors.Primary ~= nil or colors.Secondary ~= nil then
                    VEHICLE.SET_VEHICLE_COLOURS(vehicleHandle, colors.Primary or 0, colors.Secondary or 0)
                end
                if colors.IsPrimaryColourCustom then
                    VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicleHandle, colors.Cust1_R, colors.Cust1_G, colors.Cust1_B)
                end
                if colors.IsSecondaryColourCustom then
                    VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicleHandle, colors.Cust2_R, colors.Cust2_G, colors.Cust2_B)
                end
                if colors.Pearl ~= nil or colors.Rim ~= nil then
                    VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicleHandle, colors.Pearl or 0, colors.Rim or 0)
                end
                if colors.tyreSmoke_R and colors.tyreSmoke_G and colors.tyreSmoke_B then
                    VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(vehicleHandle, colors.tyreSmoke_R, colors.tyreSmoke_G, colors.tyreSmoke_B)
                end
                if colors.LrInterior and colors.LrInterior > 0 then VEHICLE.SET_VEHICLE_EXTRA_COLOUR_5(vehicleHandle, colors.LrInterior) end
                if colors.LrDashboard and colors.LrDashboard > 0 then VEHICLE.SET_VEHICLE_EXTRA_COLOUR_6(vehicleHandle, colors.LrDashboard) end
            end
        end
        
        -- Livery
        if not spawn_core.applyRandomLiveryIfEnabled(vehicleHandle) and vehicleProperties then
            local livery = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "Livery"), nil)
            if livery and livery >= 0 then VEHICLE.SET_VEHICLE_LIVERY(vehicleHandle, livery) end
        end
        
        -- Mods
        if not spawn_core.applyMaxUpgradesIfEnabled(vehicleHandle) then
            for modId, modData in pairs(mods) do
                if modData and modData.mod and modData.mod >= 0 then VEHICLE.SET_VEHICLE_MOD(vehicleHandle, modId, modData.mod, false) end
            end
        end
        
        -- Neons
        if neons then
            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 0, neons.Left or false)
            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 1, neons.Right or false)
            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 2, neons.Front or false)
            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 3, neons.Back or false)
            if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 0, neons.Left or false) end
            if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 1, neons.Right or false) end
            if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 2, neons.Front or false) end
            if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, 3, neons.Back or false) end
        end
        
        -- Vehicle properties
        if vehicleProperties then
            local numberPlateText = M.get_xml_element_content(vehicleProperties, "NumberPlateText")
            if numberPlateText then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicleHandle, numberPlateText) end
            local numberPlateIndex = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "NumberPlateIndex"), nil)
            if numberPlateIndex ~= nil then VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(vehicleHandle, numberPlateIndex) end
            local wheelType = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "WheelType"), nil)
            if wheelType ~= nil then VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicleHandle, wheelType) end
            local windowTint = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "WindowTint"), nil)
            if windowTint ~= nil and windowTint >= 0 then VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicleHandle, windowTint) end
            local bulletProofTyres = M.get_xml_element_content(vehicleProperties, "BulletProofTyres")
            if bulletProofTyres ~= nil then
                VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicleHandle, not M.to_boolean(bulletProofTyres))
            end
            local dirtLevel = M.safe_tonumber(M.get_xml_element_content(vehicleProperties, "DirtLevel"), nil)
            if dirtLevel ~= nil then VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicleHandle, dirtLevel) end
            local engineOn = M.get_xml_element_content(vehicleProperties, "EngineOn")
            if engineOn ~= nil then
                if spawnerSettings.vehicleEngineOn and M.to_boolean(engineOn) then
                    VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, true, true, false)
                end
            end
            if spawnerSettings.radioOff then AUDIO.SET_VEHICLE_RADIO_ENABLED(vehicleHandle, false) end
        end
        
        -- Spawner settings
        spawn_core.applySpawnerSettings(vehicleHandle, isPreview)
        
        -- Opacity/visibility
        local opacityLevel = M.safe_tonumber(M.get_xml_element_content(xmlContent, "OpacityLevel"), nil)
        if opacityLevel ~= nil and opacityLevel == 0 then
            ENTITY.SET_ENTITY_ALPHA(vehicleHandle, 0, false)
        end
        local isVisible = M.get_xml_element_content(xmlContent, "IsVisible")
        if isVisible ~= nil then
            ENTITY.SET_ENTITY_VISIBLE(vehicleHandle, M.to_boolean(isVisible), false)
        end
        
        -- Driver visibility
        local isDriverVisible = M.get_xml_element_content(xmlContent, "IsDriverVisible")
        local shouldHideDriver = isDriverVisible ~= nil and not M.to_boolean(isDriverVisible)
        
        -- Attachments
        local originalInVehicleSetting = spawnerSettings.inVehicle
        spawnerSettings.inVehicle = false
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        if (not parsedAttachments or #parsedAttachments == 0) then
            parsedAttachments = M.parse_outfit_attachments(xmlContent)
        end
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            if initialHandleVal then parentHandleMap[initialHandleVal] = vehicleHandle end
            local fallbackCoords = previewCoords or { x = 0, y = 0, z = 0 }
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, fallbackCoords, spawnerSettings.disableCollision, isPreview)
            for _, h in ipairs(createdAttachments) do ENTITY.SET_ENTITY_INVINCIBLE(h, true) end
        end
        spawnerSettings.inVehicle = originalInVehicleSetting
        
        -- Preview or register
        if isPreview then
            spawn_core.handlePreviewEntities(vehicleHandle, createdAttachments)
            return
        end
        
        -- Enter vehicle (before registering, since it may need yield)
        spawn_core.enterVehicleIfEnabled(vehicleHandle, playerInfo.ped, isPreview, shouldHideDriver)
        spawn_core.registerSpawnedVehicle(vehicleHandle, createdAttachments, filePath)
    end)
end

function M.getFirstVehicleXml()
    local files = FileMgr.FindFiles(xmlVehiclesFolder, ".xml", true)
    if not files or #files == 0 then return nil end
    return files[1]
end

-- ============================================================================
-- PLAYER-TARGETED OPERATIONS: Attacker, Gift, Apply Attachments
-- Each has XML, INI, and JSON variants using shared spawn_core helpers
-- ============================================================================

-- ======== XML Variants ========

function M.spawnMenyooAttackerFromXML(filePath, targetPlayerIndex, suppressToast)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then spawnerSettings.inVehicle = originalInVehicle return end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then spawnerSettings.inVehicle = originalInVehicle return end
        local modelHash = M.safe_tonumber(M.get_xml_element_content(xmlContent, "ModelHash"), nil)
        if not modelHash then spawnerSettings.inVehicle = originalInVehicle return end
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then spawnerSettings.inVehicle = originalInVehicle return end
        local spawnCoords = spawn_core.getTargetSpawnCoords(targetPed, -10.0)
        
        local vehicleHandle = spawn_core.spawnVehicleAtCoords(modelHash, spawnCoords)
        if not vehicleHandle or vehicleHandle == 0 then spawnerSettings.inVehicle = originalInVehicle return end
        
        local attackerModel = M.safe_tonumber(M.get_xml_element_content(xmlContent, "AttackerModelHash"), 71929310)
        local attacker = spawn_core.setupAttackerPed(attackerModel, vehicleHandle, targetPed, spawnCoords)
        if not attacker then spawnerSettings.inVehicle = originalInVehicle return end
        
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            local ihv = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
            if ihv then parentHandleMap[ihv] = vehicleHandle end
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do ENTITY.SET_ENTITY_INVINCIBLE(h, true) end
        end
        local attachments = { attacker }
        for _, h in ipairs(createdAttachments) do table.insert(attachments, h) end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Attacker Vehicle", M.get_filename_from_path(filePath) .. " sent to chase " .. tName, 5000, 0) end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnGiftVehicleFromXML(filePath, targetPlayerIndex, suppressToast)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then spawnerSettings.inVehicle = originalInVehicle return end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then spawnerSettings.inVehicle = originalInVehicle return end
        local modelHash = M.safe_tonumber(M.get_xml_element_content(xmlContent, "ModelHash"), nil)
        if not modelHash then spawnerSettings.inVehicle = originalInVehicle return end
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then spawnerSettings.inVehicle = originalInVehicle return end
        local spawnCoords = spawn_core.getTargetSpawnCoords(targetPed, 5.0)
        
        local vehicleHandle = spawn_core.spawnVehicleAtCoords(modelHash, spawnCoords)
        if not vehicleHandle or vehicleHandle == 0 then spawnerSettings.inVehicle = originalInVehicle return end
        
        local colors = M.parse_vehicle_colors(xmlContent)
        local mods = M.parse_vehicle_mods(xmlContent)
        local neons = M.parse_vehicle_neons(xmlContent)
        if colors then
            if colors.Primary ~= nil or colors.Secondary ~= nil then VEHICLE.SET_VEHICLE_COLOURS(vehicleHandle, colors.Primary or 0, colors.Secondary or 0) end
            if colors.IsPrimaryColourCustom then VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicleHandle, colors.Cust1_R, colors.Cust1_G, colors.Cust1_B) end
            if colors.IsSecondaryColourCustom then VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicleHandle, colors.Cust2_R, colors.Cust2_G, colors.Cust2_B) end
        end
        for modId, modData in pairs(mods) do
            if modData and modData.mod and modData.mod >= 0 then VEHICLE.SET_VEHICLE_MOD(vehicleHandle, modId, modData.mod, false) end
        end
        if neons then
            for i = 0, 3 do
                local sides = { [0] = neons.Left, [1] = neons.Right, [2] = neons.Front, [3] = neons.Back }
                if VEHICLE.SET_VEHICLE_NEON_ENABLED then VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, i, sides[i] or false) end
            end
        end
        
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            local ihv = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
            if ihv then parentHandleMap[ihv] = vehicleHandle end
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = createdAttachments })
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Spawn Vehicle", M.get_filename_from_path(filePath) .. " spawned in front of " .. tName, 5000, 0) end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.applyVehicleAttachmentsFromXML(filePath, targetPlayerIndex, suppressToast)
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then return end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then return end
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then return end
        local targetVehicle = spawn_core.getTargetVehicle(targetPed, targetPlayerIndex, suppressToast)
        if not targetVehicle then return end
        
        local spawnCoords = { x = 0, y = 0, z = 0 }
        local c = ENTITY.GET_ENTITY_COORDS(targetVehicle, true)
        spawnCoords = { x = c.x or c[1] or 0, y = c.y or c[2] or 0, z = c.z or c[3] or 0 }
        
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            local ihv = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
            if ihv then parentHandleMap[ihv] = targetVehicle end
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do ENTITY.SET_ENTITY_INVINCIBLE(h, true) end
        end
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Apply Attachments", M.get_filename_from_path(filePath) .. " applied " .. #createdAttachments .. " attachments to " .. tName .. "'s vehicle", 5000, 0) end
    end)
end

-- ======== INI Variants ========

function M.spawnMenyooAttackerFromINI(filePath, targetPlayerIndex, suppressToast)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then spawnerSettings.inVehicle = originalInVehicle return end
        local iniData = M.parse_ini_file(filePath)
        if not iniData then spawnerSettings.inVehicle = originalInVehicle return end
        local mainSection = iniData.Vehicle or iniData.Vehicle0
        if not mainSection then spawnerSettings.inVehicle = originalInVehicle return end
        local modelHash = M.safe_tonumber(mainSection.Hash or mainSection.ModelHash or mainSection.Model or mainSection.model, nil)
        if not modelHash then spawnerSettings.inVehicle = originalInVehicle return end
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then spawnerSettings.inVehicle = originalInVehicle return end
        local spawnCoords = spawn_core.getTargetSpawnCoords(targetPed, -10.0)
        
        local vehicleHandle = spawn_core.spawnVehicleAtCoords(modelHash, spawnCoords)
        if not vehicleHandle or vehicleHandle == 0 then spawnerSettings.inVehicle = originalInVehicle return end
        
        local attackerModel = M.safe_tonumber(mainSection.AttackerModelHash, 71929310)
        local attacker = spawn_core.setupAttackerPed(attackerModel, vehicleHandle, targetPed, spawnCoords)
        if not attacker then spawnerSettings.inVehicle = originalInVehicle return end
        
        local selfNum = M.safe_tonumber(mainSection.SelfNumeration, nil)
        local parentHandleMap = {}
        if selfNum then parentHandleMap[selfNum] = vehicleHandle else parentHandleMap["main_vehicle_placeholder"] = vehicleHandle end
        local parsedAttachments = M.parse_ini_attachments(iniData, selfNum)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do ENTITY.SET_ENTITY_INVINCIBLE(h, true) end
        end
        local attachments = { attacker }
        for _, h in ipairs(createdAttachments) do table.insert(attachments, h) end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Attacker Vehicle", M.get_filename_from_path(filePath) .. " sent to chase " .. tName, 5000, 0) end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnGiftVehicleFromINI(filePath, targetPlayerIndex, suppressToast)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then spawnerSettings.inVehicle = originalInVehicle return end
        local iniData = M.parse_ini_file(filePath)
        if not iniData then spawnerSettings.inVehicle = originalInVehicle return end
        local mainSection = iniData.Vehicle or iniData.Vehicle0
        if not mainSection then spawnerSettings.inVehicle = originalInVehicle return end
        local modelHash = M.safe_tonumber(mainSection.Hash or mainSection.ModelHash or mainSection.Model or mainSection.model, nil)
        if not modelHash then spawnerSettings.inVehicle = originalInVehicle return end
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then spawnerSettings.inVehicle = originalInVehicle return end
        local spawnCoords = spawn_core.getTargetSpawnCoords(targetPed, 5.0)
        
        local vehicleHandle = spawn_core.spawnVehicleAtCoords(modelHash, spawnCoords)
        if not vehicleHandle or vehicleHandle == 0 then spawnerSettings.inVehicle = originalInVehicle return end
        
        local selfNum = M.safe_tonumber(mainSection.SelfNumeration, nil)
        local parentHandleMap = {}
        if selfNum then parentHandleMap[selfNum] = vehicleHandle else parentHandleMap["main_vehicle_placeholder"] = vehicleHandle end
        local parsedAttachments = M.parse_ini_attachments(iniData, selfNum)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = createdAttachments })
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Spawn Vehicle", M.get_filename_from_path(filePath) .. " spawned in front of " .. tName, 5000, 0) end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.applyVehicleAttachmentsFromINI(filePath, targetPlayerIndex, suppressToast)
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then return end
        local iniData = M.parse_ini_file(filePath)
        if not iniData then return end
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then return end
        local targetVehicle = spawn_core.getTargetVehicle(targetPed, targetPlayerIndex, suppressToast)
        if not targetVehicle then return end
        
        local spawnCoords = { x = 0, y = 0, z = 0 }
        local c = ENTITY.GET_ENTITY_COORDS(targetVehicle, true)
        spawnCoords = { x = c.x or c[1] or 0, y = c.y or c[2] or 0, z = c.z or c[3] or 0 }
        
        local mainSection = iniData.Vehicle or iniData.Vehicle0
        local selfNum = mainSection and M.safe_tonumber(mainSection.SelfNumeration, nil) or nil
        local parentHandleMap = {}
        if selfNum then parentHandleMap[selfNum] = targetVehicle else parentHandleMap["main_vehicle_placeholder"] = targetVehicle end
        local parsedAttachments = M.parse_ini_attachments(iniData, selfNum)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do ENTITY.SET_ENTITY_INVINCIBLE(h, true) end
        end
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Apply Attachments", M.get_filename_from_path(filePath) .. " applied " .. #createdAttachments .. " attachments to " .. tName .. "'s vehicle", 5000, 0) end
    end)
end

-- ======== JSON Variants ========

-- Shared recursive child spawner for JSON player-targeted ops
local function spawnJSONChildRecursive(child, parentHandle, spawnCoords, allSpawnedObjects)
    if not child then return end
    local childModel = child.hash or child.model
    if not childModel then
        if type(child.model) == "string" then childModel = Utils.Joaat(child.model) end
    end
    if not childModel or childModel == 0 then return end
    
    local childType = child.type or "OBJECT"
    M.request_model_load(childModel)
    Script.Yield(100)
    
    local objectHandle = nil
    if childType == "VEHICLE" then
        local h = GTA.SpawnVehicle(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
        if h and h ~= 0 then
            objectHandle = h
            if child.options and child.options.engine_running then VEHICLE.SET_VEHICLE_ENGINE_ON(h, true, true, false) end
            if child.vehicle_attributes and child.vehicle_attributes.options and child.vehicle_attributes.options.engine_running then VEHICLE.SET_VEHICLE_ENGINE_ON(h, true, true, false) end
        end
    elseif childType == "PED" then
        local h = GTA.CreatePed(childModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
        if h and h ~= 0 then objectHandle = h end
    else
        local h = GTA.CreateObject(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true)
        if h and h ~= 0 then objectHandle = h end
    end
    
    if not objectHandle or objectHandle == 0 then return end
    
    ENTITY.SET_ENTITY_LOD_DIST(objectHandle, 0xFFFF)
    
    if child.options then
        if child.options.is_visible ~= nil then ENTITY.SET_ENTITY_VISIBLE(objectHandle, child.options.is_visible, false) end
        if child.options.has_collision ~= nil then ENTITY.SET_ENTITY_COLLISION(objectHandle, child.options.has_collision, false) end
        if child.options.is_invincible ~= nil then ENTITY.SET_ENTITY_INVINCIBLE(objectHandle, child.options.is_invincible)
        else ENTITY.SET_ENTITY_INVINCIBLE(objectHandle, true) end
        if child.options.alpha and child.options.alpha < 255 then ENTITY.SET_ENTITY_ALPHA(objectHandle, child.options.alpha, false) end
        if child.options.is_frozen then ENTITY.FREEZE_ENTITY_POSITION(objectHandle, true) end
    end
    
    if childType == "PED" and parentHandle and parentHandle ~= 0 then
        local parentType = nil
        parentType = ENTITY.GET_ENTITY_TYPE(parentHandle)
        if parentType == 2 then
            local seat = (child.ped_attributes and child.ped_attributes.seat) or -1
            PED.SET_PED_INTO_VEHICLE(objectHandle, parentHandle, seat)
                PED.SET_PED_CAN_BE_DRAGGED_OUT(objectHandle, false)
                PED.SET_PED_STAY_IN_VEHICLE_WHEN_JACKED(objectHandle, true)
                PED.SET_PED_CONFIG_FLAG(objectHandle, 184, true)
                PED.SET_PED_CONFIG_FLAG(objectHandle, 292, true)
                PED.SET_PED_CONFIG_FLAG(objectHandle, 32, false)
                PED.SET_PED_COMBAT_ATTRIBUTES(objectHandle, 3, false)
            VEHICLE.SET_VEHICLE_ENGINE_ON(parentHandle, true, true, false)
        end
    end
    
    table.insert(allSpawnedObjects, objectHandle)
    
    if childType == "VEHICLE" and child.vehicle_attributes then
        M.applyJSONVehicleAttributes(objectHandle, child.vehicle_attributes)
    end
    
    if child.children and #child.children > 0 then
        for _, gc in ipairs(child.children) do
            spawnJSONChildRecursive(gc, objectHandle, spawnCoords, allSpawnedObjects)
        end
    end
    
    if parentHandle and parentHandle ~= 0 and childType ~= "PED" then
        local bone = child.options and child.options.bone_index or 0
        local ox = child.offset and child.offset.x or 0
        local oy = child.offset and child.offset.y or 0
        local oz = child.offset and child.offset.z or 0
        local rx = child.rotation and child.rotation.x or 0
        local ry = child.rotation and child.rotation.y or 0
        local rz = child.rotation and child.rotation.z or 0
        local softPin = child.options and child.options.use_soft_pinning or false
        ENTITY.ATTACH_ENTITY_TO_ENTITY(objectHandle, parentHandle, bone, ox, oy, oz, rx, ry, rz, false, softPin, false, false, 2, true)
            ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(objectHandle, parentHandle, false)
    end
end

local function parseJSONForTargetOp(filePath)
    local jsonContent = FileMgr.ReadFileContent(filePath)
    if not jsonContent or jsonContent == "" then return nil end
    local jsonData = json_parser.parseJSON(jsonContent)
    if not jsonData then return nil end
    if jsonData.type ~= "VEHICLE" then return nil end
    if not jsonData.hash and not jsonData.model then return nil end
    return jsonData
end

function M.spawnMenyooAttackerFromJSON(filePath, targetPlayerIndex, suppressToast)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then spawnerSettings.inVehicle = originalInVehicle return end
        local jsonData = parseJSONForTargetOp(filePath)
        if not jsonData then spawnerSettings.inVehicle = originalInVehicle return end
        local modelHash = jsonData.hash or jsonData.model
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then spawnerSettings.inVehicle = originalInVehicle return end
        local spawnCoords = spawn_core.getTargetSpawnCoords(targetPed, -10.0)
        
        local vehicleHandle = spawn_core.spawnVehicleAtCoords(modelHash, spawnCoords)
        if not vehicleHandle or vehicleHandle == 0 then spawnerSettings.inVehicle = originalInVehicle return end
        
        local attacker = spawn_core.setupAttackerPed(71929310, vehicleHandle, targetPed, spawnCoords)
        if not attacker then spawnerSettings.inVehicle = originalInVehicle return end
        
        if jsonData.options then spawn_core.applyEntityOptions(vehicleHandle, jsonData.options) end
        
        local attachedObjects = {}
        if jsonData.children and #jsonData.children > 0 then
            for _, child in ipairs(jsonData.children) do spawnJSONChildRecursive(child, vehicleHandle, spawnCoords, attachedObjects) end
        end
        local attachments = { attacker }
        for _, h in ipairs(attachedObjects) do table.insert(attachments, h) end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Attacker Vehicle", M.get_filename_from_path(filePath) .. " sent to chase " .. tName, 5000, 0) end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnGiftVehicleFromJSON(filePath, targetPlayerIndex, suppressToast)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then spawnerSettings.inVehicle = originalInVehicle return end
        local jsonData = parseJSONForTargetOp(filePath)
        if not jsonData then spawnerSettings.inVehicle = originalInVehicle return end
        local modelHash = jsonData.hash or jsonData.model
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then spawnerSettings.inVehicle = originalInVehicle return end
        local spawnCoords = spawn_core.getTargetSpawnCoords(targetPed, 5.0)
        
        local vehicleHandle = spawn_core.spawnVehicleAtCoords(modelHash, spawnCoords)
        if not vehicleHandle or vehicleHandle == 0 then spawnerSettings.inVehicle = originalInVehicle return end
        
        if jsonData.vehicle_attributes then M.applyJSONVehicleAttributes(vehicleHandle, jsonData.vehicle_attributes) end
        if jsonData.options then spawn_core.applyEntityOptions(vehicleHandle, jsonData.options) end
        
        local attachedObjects = {}
        if jsonData.children and #jsonData.children > 0 then
            for _, child in ipairs(jsonData.children) do spawnJSONChildRecursive(child, vehicleHandle, spawnCoords, attachedObjects) end
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachedObjects })
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Spawn Vehicle", M.get_filename_from_path(filePath) .. " spawned in front of " .. tName, 5000, 0) end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.applyVehicleAttachmentsFromJSON(filePath, targetPlayerIndex, suppressToast)
    FreemodeQueueJob(function()
        if not filePath or not FileMgr.DoesFileExist(filePath) then return end
        local jsonData = parseJSONForTargetOp(filePath)
        if not jsonData then return end
        
        local targetPed = spawn_core.resolveTargetPed(targetPlayerIndex)
        if not targetPed then return end
        local targetVehicle = spawn_core.getTargetVehicle(targetPed, targetPlayerIndex, suppressToast)
        if not targetVehicle then return end
        
        local spawnCoords = { x = 0, y = 0, z = 0 }
        local c = ENTITY.GET_ENTITY_COORDS(targetVehicle, true)
        spawnCoords = { x = c.x or c[1] or 0, y = c.y or c[2] or 0, z = c.z or c[3] or 0 }
        
        local attachedObjects = {}
        if jsonData.children and #jsonData.children > 0 then
            for _, child in ipairs(jsonData.children) do spawnJSONChildRecursive(child, targetVehicle, spawnCoords, attachedObjects) end
        end
        local tName = spawn_core.getTargetName(targetPlayerIndex)
        if not suppressToast then GUI.AddToast("Apply Attachments", M.get_filename_from_path(filePath) .. " applied " .. #attachedObjects .. " attachments to " .. tName .. "'s vehicle", 5000, 0) end
    end)
end


function M.spawnMapV1Networked(filePath, placements)
    local carattach_hash = Utils.Joaat("lazer")
    M.request_model_load(carattach_hash)
    local carattach = GTA.SpawnVehicle(carattach_hash, 0.0, 0.0, 0.0, 0.0, true, true)
    if not carattach or carattach == 0 then
        Logger.LogError("[Spawn] Failed to spawn base vehicle for Network Maps V1")
        GUI.AddToast("Spawn Error", "Failed to spawn base vehicle for Network Maps V1.", 5000, 1)
        return nil, 0
    end
    ENTITY.FREEZE_ENTITY_POSITION(carattach, true)
    ENTITY.SET_ENTITY_COLLISION(carattach, false, false)
    ENTITY.SET_ENTITY_VISIBLE(carattach, false, false)
    ENTITY.SET_ENTITY_LOD_DIST(carattach, 100000)
    constructor_lib.make_entity_networked({handle = carattach})
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
                ENTITY.ATTACH_ENTITY_TO_ENTITY(
                        entityHandle,
                        parentHandle,
                        placement.Attachment.BoneIndex or 0,
                        placement.Attachment.X or 0.0, placement.Attachment.Y or 0.0, placement.Attachment.Z or 0.0,
                        placement.Attachment.Pitch or 0.0, placement.Attachment.Roll or 0.0, placement.Attachment.Yaw or 0.0,
                        false, false, true, false, 2, true
                    )
                    M.debug_print("[Spawn Debug] Attached entity", tostring(entityHandle), "to parent object", tostring(parentHandle))
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
            ENTITY.ATTACH_ENTITY_TO_ENTITY(
                    entityHandle,
                    carattach,
                    0,
                    spawnCoords.x, spawnCoords.y, spawnCoords.z,
                    rotX, rotY, rotZ,
                    false, false, true, false, 2, true
                )
                M.debug_print("[Spawn Debug] Attached entity", tostring(entityHandle), "to base vehicle", tostring(carattach))
        end
        pcall(function()
            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entityHandle, true, false)
            ENTITY.SET_ENTITY_LOD_DIST(entityHandle, 100000)
            constructor_lib.make_entity_networked({handle = entityHandle})
        end)
        if placement.IsInvincible then ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, true) end
        if placement.IsVisible ~= nil then ENTITY.SET_ENTITY_VISIBLE(entityHandle, placement.IsVisible, false) end
        if placement.OpacityLevel ~= nil then
            local opacity = M.safe_tonumber(placement.OpacityLevel, 255)
            if opacity == 0 then
                ENTITY.SET_ENTITY_ALPHA(entityHandle, 0, false)
            end
        end
        if placement.HasGravity ~= nil then ENTITY.SET_ENTITY_HAS_GRAVITY(entityHandle, placement.HasGravity) end
        if placement.Health ~= nil then local health = M.safe_tonumber(placement.Health, 1000) ENTITY.SET_ENTITY_HEALTH(entityHandle, health, 0) end
        if placement.MaxHealth ~= nil then local maxHealth = M.safe_tonumber(placement.MaxHealth, 1000) ENTITY.SET_ENTITY_MAX_HEALTH(entityHandle, maxHealth) end
        if placement.IsBulletProof then ENTITY.SET_ENTITY_PROOFS(entityHandle, true, false, false, false, false, false, false, false) end
        if placement.IsCollisionProof then ENTITY.SET_ENTITY_PROOFS(entityHandle, false, true, false, false, false, false, false, false) end
        if placement.IsExplosionProof then ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, true, false, false, false, false, false) end
        if placement.IsFireProof then ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, true, false, false, false, false) end
        if placement.IsMeleeProof then ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, false, true, false, false, false) end
        if placement.FrozenPos then ENTITY.FREEZE_ENTITY_POSITION(entityHandle, true) end
        if placement.ObjectProperties then
            for propName, propValue in pairs(placement.ObjectProperties) do
                if propName == "TextureVariation" then
                    local texture = M.safe_tonumber(propValue, 0)
                    OBJECT.SET_OBJECT_TINT_INDEX(entityHandle, texture)
                end
            end
        end
        ::continue_placement::
    end
    return mapV1Entities, spawnCount
end

function M.spawnMapFromXML(filePath, options)
    FreemodeQueueJob(function()
        local opt = options or {}
        local checkSpawnOnMe = (opt.spawnMapOnMe ~= nil) and opt.spawnMapOnMe or spawnerSettings.spawnMapOnMe
        local checkTeleport = (opt.teleportToMap ~= nil) and opt.teleportToMap or spawnerSettings.teleportToMap
        local checkDeleteOld = (opt.deleteOldMap ~= nil) and opt.deleteOldMap or spawnerSettings.deleteOldMap
        
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
        if checkDeleteOld then
            M.deleteAllSpawnedMaps()
        end
        spawn_core.clearAreaIfEnabled()
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
        
        -- Calculate spawn offset if "Spawn Map on Me" is enabled
        local spawnOffset = { x = 0.0, y = 0.0, z = 0.0 }
        local actualRefCoords = refCoords -- The reference coords we'll store (updated if spawning on player)
        if checkSpawnOnMe and refCoords then
            local playerPed = PLAYER.PLAYER_PED_ID()
            if playerPed and playerPed ~= 0 then
                local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, false)
                spawnOffset.x = playerCoords.x - refCoords.x
                spawnOffset.y = playerCoords.y - refCoords.y
                spawnOffset.z = playerCoords.z - refCoords.z
                -- Update actual ref coords to player's position for storage
                actualRefCoords = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
                M.debug_print("[Spawn Map on Me] Offset calculated: X=" .. spawnOffset.x .. " Y=" .. spawnOffset.y .. " Z=" .. spawnOffset.z)
            end
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
                    -- Apply the spawn offset to the original coordinates
                    spawnCoords.x = (placement.PositionRotation.X or 0.0) + spawnOffset.x
                    spawnCoords.y = (placement.PositionRotation.Y or 0.0) + spawnOffset.y
                    spawnCoords.z = (placement.PositionRotation.Z or 0.0) + spawnOffset.z
                end

                local entityHandle = M.create_by_type(model, placement.Type, spawnCoords)
                local placementName = placement.HashName or tostring(model) or "Unknown"
                local typeNames = {["1"] = "Ped", ["2"] = "Vehicle", ["3"] = "Object", [1] = "Ped", [2] = "Vehicle", [3] = "Object"}
                local typeName = typeNames[placement.Type] or tostring(placement.Type)
                if not entityHandle or entityHandle == 0 then
                    Logger.LogError("[Spawn] Failed to create '" .. placementName .. "' [" .. typeName .. "] (hash: " .. tostring(model) .. ")")
                    goto continue_v2
                end
                ENTITY.SET_ENTITY_COORDS(entityHandle, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
                table.insert(createdEntities, entityHandle)
                spawnCount = spawnCount + 1
                -- Show progress toasts at 25%, 50%, 75% for maps over 200 entities
                if totalPlacements > 200 then
                    local percentComplete = math.floor((spawnCount / totalPlacements) * 100)
                    if percentComplete >= 25 and not progressShown[25] then
                        progressShown[25] = true
                        GUI.AddToast("Spawning Map", "25% completed (" .. spawnCount .. "/" .. totalPlacements .. ")", 2000, 0)
                    elseif percentComplete >= 50 and not progressShown[50] then
                        progressShown[50] = true
                        GUI.AddToast("Spawning Map", "50% completed (" .. spawnCount .. "/" .. totalPlacements .. ")", 2000, 0)
                    elseif percentComplete >= 75 and not progressShown[75] then
                        progressShown[75] = true
                        GUI.AddToast("Spawning Map", "75% completed (" .. spawnCount .. "/" .. totalPlacements .. ")", 2000, 0)
                    end
                end
                if spawnerSettings.networkMapsV2Enabled then
                    pcall(function()
                        constructor_lib.make_entity_networked({handle = entityHandle})
                    end)
                end
                if placement.IsInvincible then
                    ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, true)
                end
                if placement.IsVisible ~= nil then
                    ENTITY.SET_ENTITY_VISIBLE(entityHandle, placement.IsVisible, false)
                end
                if placement.OpacityLevel ~= nil then
                    local opacity = M.safe_tonumber(placement.OpacityLevel, 255)
                    if opacity == 0 then
                        ENTITY.SET_ENTITY_ALPHA(entityHandle, 0, false)
                    end
                end
                if placement.HasGravity ~= nil then
                    ENTITY.SET_ENTITY_HAS_GRAVITY(entityHandle, placement.HasGravity)
                end
                if placement.Health ~= nil then
                    local health = M.safe_tonumber(placement.Health, 1000)
                    ENTITY.SET_ENTITY_HEALTH(entityHandle, health, 0)
                end
                if placement.MaxHealth ~= nil then
                    local maxHealth = M.safe_tonumber(placement.MaxHealth, 1000)
                    ENTITY.SET_ENTITY_MAX_HEALTH(entityHandle, maxHealth)
                end
                if placement.IsBulletProof then
                    ENTITY.SET_ENTITY_PROOFS(entityHandle, true, false, false, false, false, false, false, false)
                end
                if placement.IsCollisionProof then
                    ENTITY.SET_ENTITY_PROOFS(entityHandle, false, true, false, false, false, false, false, false)
                end
                if placement.IsExplosionProof then
                    ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, true, false, false, false, false, false)
                end
                if placement.IsFireProof then
                    ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, true, false, false, false, false)
                end
                if placement.IsMeleeProof then
                    ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, false, true, false, false, false)
                end
                if placement.PositionRotation then
                    local rotX = placement.PositionRotation.Pitch or 0.0
                    local rotY = placement.PositionRotation.Roll or 0.0
                    local rotZ = placement.PositionRotation.Yaw or 0.0
                    ENTITY.SET_ENTITY_ROTATION(entityHandle, rotX, rotY, rotZ, 2)
                    if placement.FrozenPos then
                        ENTITY.FREEZE_ENTITY_POSITION(entityHandle, true)
                    end
                end
                if placement.ObjectProperties then
                    for propName, propValue in pairs(placement.ObjectProperties) do
                        if propName == "TextureVariation" then
                            local texture = M.safe_tonumber(propValue, 0)
                            OBJECT.SET_OBJECT_TINT_INDEX(entityHandle, texture)
                        end
                    end
                end
                ::continue_v2::
            end
        end
        -- Only teleport if not using spawnMapOnMe (because player is already at the spawn location)
        if refCoords and checkTeleport and not checkSpawnOnMe then
            local playerPed = GTA.GetLocalPed()
            if playerPed then
                local playerHandle = GTA.PointerToHandle(playerPed)
                    if playerHandle and playerHandle > 0 then
                        ENTITY.SET_ENTITY_COORDS(playerHandle, refCoords.x, refCoords.y, refCoords.z, false, false, false, true)
                    end
            end
        end
        -- Apply spawn offset to markers if spawnMapOnMe is enabled
        if markers and checkSpawnOnMe then
            for _, marker in ipairs(markers) do
                marker.X = (marker.X or 0.0) + spawnOffset.x
                marker.Y = (marker.Y or 0.0) + spawnOffset.y
                marker.Z = (marker.Z or 0.0) + spawnOffset.z
            end
        end
        
        if markers and #markers > 0 then
            FreemodeQueueJob(function()
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
                refCoords = actualRefCoords -- Use updated ref coords when spawning on player
            }
            table.insert(spawnedMaps, mapData)
            local markerCount = (markers and #markers or 0)
                local toastMsg = filename .. " (" .. spawnCount .. " entities, " .. markerCount .. " markers)"
                if checkSpawnOnMe then
                    toastMsg = toastMsg .. " - Spawned at your location"
                end
                GUI.AddToast("Map Spawned", toastMsg, 5000, 0)
                print("Map Spawned", toastMsg)
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
        end
    end)
end

function M.spawnOutfitFromXML(filePath, isPreview)
    isPreview = isPreview or false
    FreemodeQueueJob(function()
        -- Preview finalization shortcut
        if not isPreview and currentPreviewFile and currentPreviewFile.path == filePath and #previewEntities > 0 then
            local entitiesToFinalize = {}
            for _, entity in ipairs(previewEntities) do table.insert(entitiesToFinalize, entity) end
            M.finalizePreviewVehicle(entitiesToFinalize)
            local spawnedPed = entitiesToFinalize[1]
            local createdAttachments = {}
            for i = 2, #entitiesToFinalize do table.insert(createdAttachments, entitiesToFinalize[i]) end
            local pid = PLAYER.PLAYER_ID()
            if pid then PLAYER.CHANGE_PLAYER_PED(pid, spawnedPed, true, true) end
            table.insert(spawnedOutfits, { attachments = createdAttachments, spawnedPed = spawnedPed, filePath = filePath })
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
        if not outfitData or not outfitData.ModelHash then return end
        local modelHash = M.safe_tonumber(outfitData.ModelHash, nil)
        if not modelHash or modelHash == 0 then return end
        
        local playerInfo = spawn_core.getPlayerPedInfo()
        if not playerInfo then return end
        local spawnCoords = spawn_core.calcOutfitSpawnCoords(playerInfo, isPreview)
        
        local spawnedPed = nil
        local targetPed = playerInfo.handle
        
        if not spawnerSettings.onlyApplyAttachments then
            M.request_model_load(modelHash)
            spawnedPed = M.create_by_type(modelHash, 1, spawnCoords)
            if not spawnedPed or spawnedPed == 0 then return end
            targetPed = spawnedPed
            if outfitData.PedProperties then
                M.apply_ped_properties(spawnedPed, outfitData.PedProperties)
            end
        end
        
        local parentHandleMap = {}
        local xmlInitialHandle = M.safe_tonumber(outfitData.InitialHandle, nil)
        if xmlInitialHandle then parentHandleMap[xmlInitialHandle] = targetPed end
        
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision, isPreview)
        end
        -- Fallback: try attaching to player if attachments failed on spawned ped
        if (not createdAttachments or #createdAttachments == 0) and parsedAttachments and #parsedAttachments > 0 then
            local playerCoords = ENTITY.GET_ENTITY_COORDS(playerInfo.handle, false)
            local fallbackCoords = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
            local playerParentMap = {}
            if xmlInitialHandle then playerParentMap[xmlInitialHandle] = playerInfo.handle end
            createdAttachments = M.spawn_attachments(parsedAttachments, playerParentMap, fallbackCoords, spawnerSettings.disableCollision, isPreview)
        end
        
        PED.SET_PED_KEEP_TASK(spawnedPed, true)
            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(spawnedPed, true)
            ENTITY.SET_ENTITY_INVINCIBLE(spawnedPed, true)
        
        -- Attachment verification with retry
        local function all_attachments_attached(list, parent)
            if not list or #list == 0 then return true end
            for _, ah in ipairs(list) do
                if ah and ah ~= 0 and ENTITY.DOES_ENTITY_EXIST(ah) then
                    local attachedTo = nil
                    attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(ah)
                    if attachedTo ~= parent then return false end
                end
            end
            return true
        end
        local attached_ok = false
        for i = 1, 15 do
            if all_attachments_attached(createdAttachments, targetPed) then attached_ok = true break end
            if i == 5 then
                for _, ah in ipairs(createdAttachments) do
                    if ah and ah ~= 0 and ENTITY.DOES_ENTITY_EXIST(ah) then
                        local attachedTo = nil
                        attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(ah)
                        if attachedTo ~= targetPed then
                            ENTITY.ATTACH_ENTITY_TO_ENTITY(ah, targetPed, -1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, spawnerSettings.disableCollision, false, 0, true)
                        end
                    end
                end
            end
            Script.Yield(200)
        end
        
        if isPreview then
            if spawnedPed then table.insert(previewEntities, spawnedPed) end
            for _, attachment in ipairs(createdAttachments) do table.insert(previewEntities, attachment) end
            return
        end
        if spawnedPed and not spawnerSettings.onlyApplyAttachments then
            local pid = PLAYER.PLAYER_ID()
            if pid then
                Script.Yield(2000)
                PLAYER.CHANGE_PLAYER_PED(pid, spawnedPed, true, true)
                Script.Yield(250)
                FeatureMgr.GetFeatureByName("Give All Weapons"):TriggerCallback()
            end
        end
        table.insert(spawnedOutfits, { attachments = createdAttachments, spawnedPed = spawnedPed, filePath = filePath })
    end)
end


function M.deleteAllSpawnedProps()
    FreemodeQueueJob(function()
        for i, propHandle in ipairs(spawnedProps) do
            if propHandle and ENTITY.DOES_ENTITY_EXIST(propHandle) then
                constructor_lib.delete_entity(propHandle)
            end
        end
        spawnedProps = {}
        GUI.AddToast("Props Deleted", "All spawned props deleted.", 3000, 0)
    end)
end

-- JSON Vehicle Spawning Function
function M.spawnVehicleFromJSON(filePath, isPreview)
    FreemodeQueueJob(function()
        -- Pre-spawn checks
        local err = spawn_core.preSpawnChecks(filePath, isPreview, "JSON")
        if err then
            GUI.AddToast("Spawn Error", "JSON file not found", 3000, 0)
            return
        end
        
        -- Read and parse JSON
        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            M.debug_print("[JSON Spawn Debug] Error: Failed to read JSON file:", filePath)
            GUI.AddToast("Spawn Error", "Failed to read JSON file", 3000, 0)
            return
        end
        
        local jsonData = json_parser.parseJSON(jsonContent)
        if not jsonData then
            GUI.AddToast("Spawn Error", "Failed to parse JSON", 5000, 0)
            return
        end
        
        -- Detect and normalize format (JSTAND/Jackz Builder)
        local isJSTAND = jsonData.base ~= nil or jsonData.version and jsonData.version:match("Jackz Builder")
        if isJSTAND then
            local modelHash = jsonData.base and jsonData.base.model or jsonData.base and jsonData.base.data and jsonData.base.data.model
            if not modelHash then
                GUI.AddToast("Spawn Error", "No model in JSTAND base", 3000, 0)
                return
            end
            jsonData.hash = modelHash
            jsonData.type = "VEHICLE"
            jsonData.children = {}
            if jsonData.objects then
                for _, obj in ipairs(jsonData.objects) do
                    table.insert(jsonData.children, {
                        type = "OBJECT", hash = obj.model, model = obj.model,
                        offset = obj.offset, rotation = obj.rotation,
                        options = { is_visible = obj.visible, has_collision = obj.collision, bone_index = obj.boneIndex or 0 }
                    })
                end
            end
            if jsonData.vehicles then
                for _, veh in ipairs(jsonData.vehicles) do
                    table.insert(jsonData.children, {
                        type = "VEHICLE", hash = veh.model, model = veh.model,
                        offset = veh.offset, rotation = veh.rotation,
                        options = { is_visible = veh.visible, is_invincible = veh.godmode, has_collision = veh.collision, bone_index = veh.boneIndex or 0 }
                    })
                end
            end
        end
        
        if jsonData.type ~= "VEHICLE" then
            GUI.AddToast("Spawn Error", "This JSON is not a vehicle", 3000, 0)
            return
        end
        
        local modelHash = jsonData.hash
        if not modelHash then
            GUI.AddToast("Spawn Error", "No model hash in JSON", 3000, 0)
            return
        end
        
        -- Get player info
        local playerInfo = spawn_core.getPlayerSpawnInfo()
        if not playerInfo then return end
        
        -- Delete old vehicles
        spawn_core.deleteOldIfEnabled(isPreview)
        
        -- Spawn vehicle handle
        local vehicleHandle = spawn_core.spawnVehicleHandle(modelHash, playerInfo, isPreview)
        if not vehicleHandle or vehicleHandle == 0 then
            spawn_core.logSpawnFailure(filePath, modelHash)
            GUI.AddToast("Spawn Error", "Failed to spawn vehicle", 3000, 0)
            return
        end
        
        local playerPed = PLAYER.PLAYER_PED_ID()
        local spawnCoords = ENTITY.GET_ENTITY_COORDS(vehicleHandle, true)
        
        -- Apply vehicle attributes using the unified function
        if jsonData.vehicle_attributes then
            M.applyJSONVehicleAttributes(vehicleHandle, jsonData.vehicle_attributes)
        end
        
        if jsonData.options then
            spawn_core.applyEntityOptions(vehicleHandle, jsonData.options)
        end
        
        -- Apply spawner settings
        spawn_core.applySpawnerSettings(vehicleHandle, isPreview)
        
        -- Recursive child spawning function
        local function spawnJSONChild(child, parentHandle, depth, childEntities)
            depth = depth or 0
            
            -- PARTICLE type
            if child.type == "PARTICLE" then
                local particleAttrs = child.particle_attributes
                if particleAttrs and particleAttrs.asset and particleAttrs.effect_name then
                    M.spawnParticleOnEntity(parentHandle, particleAttrs, child.offset, child.rotation)
                end
                return nil
            end
            
            -- Get model
            local childModel = child.hash or child.model
            if not childModel then return nil end
            
            -- Infer type from attributes if not explicitly set (many ConstructorLib JSONs omit this)
            local childType = child.type
            if not childType then
                if child.vehicle_attributes then
                    childType = "VEHICLE"
                elseif child.ped_attributes then
                    childType = "PED"
                else
                    childType = "OBJECT"
                end
            end
            
            -- Proper model loading with wait loop
            local modelToLoad = M.safe_tonumber(childModel, childModel) or childModel
            M.request_model_load(modelToLoad)
            local t0 = Time.GetEpoche()
            while not STREAMING.HAS_MODEL_LOADED(modelToLoad) and Time.GetEpoche() - t0 < 1.0 do
                Script.Yield(10)
            end
            if not STREAMING.HAS_MODEL_LOADED(modelToLoad) then return nil end
            
            local childHandle
            if childType == "VEHICLE" then
                local h = GTA.SpawnVehicle(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
                if h and h ~= 0 then
                    childHandle = h
                    if child.vehicle_attributes then
                        M.applyJSONVehicleAttributes(h, child.vehicle_attributes)
                    end
                end
            elseif childType == "PED" then
                local h = GTA.CreatePed(childModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true)
                if h and h ~= 0 then
                    childHandle = h
                    -- Apply ONLY cosmetic ped attributes before attachment (components, props, weapon)
                    -- Animations are deferred until after attachment to prevent peds from falling off
                    if child.ped_attributes then
                        M.applyPedAttributesCosmetic(h, child.ped_attributes, parentHandle)
                    end
                end
            else
                local h = GTA.CreateObject(childModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true)
                if h and h ~= 0 then childHandle = h end
            end
            
            if not childHandle or childHandle == 0 then return nil end
            
            -- Set entity flags BEFORE attachment (matches ConstructorLib order)
            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(childHandle, true, false)
            if childType == "PED" then
                -- Stabilize ped before attachment to prevent falling off
                PED.SET_PED_CAN_RAGDOLL(childHandle, false)
                PED.SET_PED_CAN_RAGDOLL_FROM_PLAYER_IMPACT(childHandle, false)
                PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(childHandle, true)
                PED.SET_PED_CONFIG_FLAG(childHandle, 208, true) -- CPED_CONFIG_FLAG_BlockNonTemporaryEvents
                PED.SET_PED_KEEP_TASK(childHandle, true)
            end
            if child.options then
                if child.options.is_invincible then
                    ENTITY.SET_ENTITY_INVINCIBLE(childHandle, true)
                end
                if child.options.has_collision == false then
                    ENTITY.SET_ENTITY_COLLISION(childHandle, false, false)
                end
                if child.options.is_visible == false then
                    ENTITY.SET_ENTITY_VISIBLE(childHandle, false, false)
                end
                if child.options.is_frozen then
                    ENTITY.FREEZE_ENTITY_POSITION(childHandle, true)
                end
                if child.options.alpha and child.options.alpha < 255 then
                    ENTITY.SET_ENTITY_ALPHA(childHandle, child.options.alpha, false)
                end
            end
            
            -- Attach to parent
            local offsetX = child.offset and child.offset.x or 0.0
            local offsetY = child.offset and child.offset.y or 0.0
            local offsetZ = child.offset and child.offset.z or 0.0
            local rotX = child.rotation and child.rotation.x or 0.0
            local rotY = child.rotation and child.rotation.y or 0.0
            local rotZ = child.rotation and child.rotation.z or 0.0
            local boneIndex = child.options and child.options.bone_index or 0
            local useSoftPinning = child.options and child.options.use_soft_pinning
            if useSoftPinning == nil then useSoftPinning = true end
            local hasCollision = child.options and child.options.has_collision
            if hasCollision == nil then hasCollision = false end
            local rotOrder = child.rotation_order or 2
            
            ENTITY.ATTACH_ENTITY_TO_ENTITY(childHandle, parentHandle, boneIndex,
                    offsetX, offsetY, offsetZ, rotX, rotY, rotZ,
                    false, useSoftPinning, hasCollision, false, rotOrder, true)
            
            -- Apply ped animations AFTER attachment so they don't fight the attachment
            if childType == "PED" and child.ped_attributes then
                M.applyPedAttributesAnimation(childHandle, child.ped_attributes)
            end
            
            ENTITY.SET_ENTITY_LOD_DIST(childHandle, 0xFFFF)
            
            table.insert(childEntities, childHandle)
            
            -- Yield to let the game process the attachment before spawning children on this entity
            Script.Yield(50)
            
            -- Recurse into nested children
            if child.children and type(child.children) == "table" then
                local hasChildren = false
                for _ in pairs(child.children) do hasChildren = true; break end
                if hasChildren then
                    local usedIpairs = false
                    for _, nestedChild in ipairs(child.children) do
                        usedIpairs = true
                        spawnJSONChild(nestedChild, childHandle, depth + 1, childEntities)
                    end
                    if not usedIpairs then
                        for _, nestedChild in pairs(child.children) do
                            if type(nestedChild) == "table" then
                                spawnJSONChild(nestedChild, childHandle, depth + 1, childEntities)
                            end
                        end
                    end
                end
            end
            
            return childHandle
        end
        
        -- Spawn all children
        local childEntities = {}
        if jsonData.children and type(jsonData.children) == "table" then
            for _, child in ipairs(jsonData.children) do
                spawnJSONChild(child, vehicleHandle, 0, childEntities)
            end
        end
        
        -- Preview handling
        if isPreview then
            table.insert(previewEntities, vehicleHandle)
            for _, h in ipairs(childEntities) do table.insert(previewEntities, h) end
            return
        end
        
        -- Enter vehicle
        if spawnerSettings.inVehicle and not isPreview then
            PED.SET_PED_INTO_VEHICLE(playerPed, vehicleHandle, -1)
        end
        
        -- Register
        local vehicleRecord = { vehicle = vehicleHandle, attachments = childEntities, filePath = filePath }
        table.insert(spawnedVehicles, vehicleRecord)
        
        local fileName = M.get_filename_from_path(filePath)
            local count = #childEntities
            local msg = fileName .. " with " .. count .. " attachment" .. (count == 1 and "" or "s")
            if jsonData.author and jsonData.author ~= "" then msg = msg .. "\nby " .. jsonData.author end
            GUI.AddToast("Vehicle Spawned", msg, 5000, 0)
    end)
end

-- ============================================================================
-- Helper: Spawn a particle effect on an entity (shared by XML and JSON)
-- ============================================================================
function M.spawnParticleOnEntity(entityHandle, particleAttrs, offset, rotation)
    if not particleAttrs or not particleAttrs.asset or not particleAttrs.effect_name then return end
    
    local assetName = particleAttrs.asset
    local effectName = particleAttrs.effect_name
    local scale = particleAttrs.scale or 1.0
    local offsetX = offset and offset.x or 0.0
    local offsetY = offset and offset.y or 0.0
    local offsetZ = offset and offset.z or 0.0
    local rotX = rotation and rotation.x or 0.0
    local rotY = rotation and rotation.y or 0.0
    local rotZ = rotation and rotation.z or 0.0
    local r = particleAttrs.color and particleAttrs.color.r or 1.0
    local g = particleAttrs.color and particleAttrs.color.g or 1.0
    local b = particleAttrs.color and particleAttrs.color.b or 1.0
    local a = particleAttrs.color and particleAttrs.color.a or 1.0
    
    FreemodeQueueJob(function()
        if not ENTITY.DOES_ENTITY_EXIST(entityHandle) then return end
        if not ensure_ptfx_asset_loaded(assetName) then return end
        
        GRAPHICS.USE_PARTICLE_FX_ASSET(assetName)
        
        local handle = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY(effectName, entityHandle, offsetX, offsetY, offsetZ, rotX, rotY, rotZ, scale, false, false, false)
        
        if handle and handle ~= 0 then
            GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
            GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
            GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
            
            -- Refresh loop
            FreemodeQueueJob(function()
                while ENTITY.DOES_ENTITY_EXIST(entityHandle) do
                    Script.Yield(150)
                    if not ENTITY.DOES_ENTITY_EXIST(entityHandle) then break end
                    GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false)
                    if not ensure_ptfx_asset_loaded(assetName) then break end
                    GRAPHICS.USE_PARTICLE_FX_ASSET(assetName)
                    local newHandle = GRAPHICS.START_PARTICLE_FX_LOOPED_ON_ENTITY(effectName, entityHandle, offsetX, offsetY, offsetZ, rotX, rotY, rotZ, scale, false, false, false)
                    if newHandle and newHandle ~= 0 then
                        handle = newHandle
                        GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(handle, r, g, b, false)
                        GRAPHICS.SET_PARTICLE_FX_LOOPED_ALPHA(handle, a)
                        GRAPHICS.SET_PARTICLE_FX_LOOPED_SCALE(handle, scale)
                    else break end
                end
                if handle then
                    GRAPHICS.STOP_PARTICLE_FX_LOOPED(handle, false)
                end
            end)
        end
    end)
end

-- ============================================================================
-- Helper: Apply ped attributes from JSON (components, props, animation, seat)
-- ============================================================================
function M.applyPedAttributes(pedHandle, attrs, parentHandle)
    if not attrs then return end
    
    -- Animation: support both nested format {animation={dictionary,clip}} and ConstructorLib flat format {animation_dict, animation_name}
    local animDict = (attrs.animation and attrs.animation.dictionary) or attrs.animation_dict
    local animName = (attrs.animation and attrs.animation.clip) or attrs.animation_name
    local animLoop = attrs.animation and attrs.animation.loop
    if animDict and animName then
        Script.Yield(100)
        STREAMING.REQUEST_ANIM_DICT(animDict)
        local timeout = 0
        while not STREAMING.HAS_ANIM_DICT_LOADED(animDict) and timeout < 50 do
            Script.Yield(10)
            timeout = timeout + 1
        end
        if STREAMING.HAS_ANIM_DICT_LOADED(animDict) then
            TASK.TASK_PLAY_ANIM(pedHandle, animDict, animName, 8.0, -8.0, -1, animLoop and 1 or 1, 0, false, false, false)
        end
    end
    
    -- Components (clothing)
    if attrs.components then
        for compKey, compData in pairs(attrs.components) do
            local compId = tonumber(compKey:match("_(%d+)"))
            if compId and compData.drawable_variation then
                PED.SET_PED_COMPONENT_VARIATION(pedHandle, compId, compData.drawable_variation, compData.texture_variation or 0, compData.palette_variation or 0)
            end
        end
    end
    
    -- Props (accessories)
    if attrs.props then
        for propKey, propData in pairs(attrs.props) do
            local propId = tonumber(propKey:match("_(%d+)"))
            if propId then
                if propData.drawable_variation and propData.drawable_variation ~= -1 then
                    PED.SET_PED_PROP_INDEX(pedHandle, propId, propData.drawable_variation, propData.texture_variation or 0, true)
                else
                    PED.CLEAR_PED_PROP(pedHandle, propId)
                end
            end
        end
    end
    
    -- Ped flags
    if attrs.ignore_events then PED.SET_PED_CONFIG_FLAG(pedHandle, 208, true) end
    if attrs.keep_on_task then PED.SET_PED_KEEP_TASK(pedHandle, true) end
    
    -- Armor
    if attrs.armor then PED.SET_PED_ARMOUR(pedHandle, attrs.armor) end
    
    -- Weapon
    if attrs.weapon and attrs.weapon.model then
        local weaponHash = type(attrs.weapon.model) == "string" and MISC.GET_HASH_KEY(attrs.weapon.model) or attrs.weapon.model
        M.request_model_load(weaponHash)
        Script.Yield(100)
        WEAPON.GIVE_WEAPON_TO_PED(pedHandle, weaponHash, 9999, false, true)
    end
    
    -- Seat in parent vehicle
    if attrs.seat ~= nil and parentHandle then
        local parentType = ENTITY.GET_ENTITY_TYPE(parentHandle)
        if parentType == 2 then
            PED.SET_PED_INTO_VEHICLE(pedHandle, parentHandle, attrs.seat)
            PED.SET_PED_CAN_BE_DRAGGED_OUT(pedHandle, false)
            PED.SET_PED_STAY_IN_VEHICLE_WHEN_JACKED(pedHandle, true)
            PED.SET_PED_CONFIG_FLAG(pedHandle, 184, true)
            PED.SET_PED_CONFIG_FLAG(pedHandle, 292, true)
            PED.SET_PED_CONFIG_FLAG(pedHandle, 32, false)
            PED.SET_PED_COMBAT_ATTRIBUTES(pedHandle, 3, false)
            VEHICLE.SET_VEHICLE_ENGINE_ON(parentHandle, true, true, false)
        end
    end
end

-- Split version: Apply only cosmetic ped attributes (components, props, weapon, seat) - safe to call before attachment
function M.applyPedAttributesCosmetic(pedHandle, attrs, parentHandle)
    if not attrs then return end
    
    -- Components (clothing)
    if attrs.components then
        for compKey, compData in pairs(attrs.components) do
            local compId = tonumber(compKey:match("_(%d+)"))
            if compId and compData.drawable_variation then
                PED.SET_PED_COMPONENT_VARIATION(pedHandle, compId, compData.drawable_variation, compData.texture_variation or 0, compData.palette_variation or 0)
            end
        end
    end
    
    -- Props (accessories)
    if attrs.props then
        for propKey, propData in pairs(attrs.props) do
            local propId = tonumber(propKey:match("_(%d+)"))
            if propId then
                if propData.drawable_variation and propData.drawable_variation ~= -1 then
                    PED.SET_PED_PROP_INDEX(pedHandle, propId, propData.drawable_variation, propData.texture_variation or 0, true)
                else
                    PED.CLEAR_PED_PROP(pedHandle, propId)
                end
            end
        end
    end
    
    -- Ped flags
    if attrs.ignore_events then PED.SET_PED_CONFIG_FLAG(pedHandle, 208, true) end
    if attrs.keep_on_task then PED.SET_PED_KEEP_TASK(pedHandle, true) end
    
    -- Armor
    if attrs.armor then PED.SET_PED_ARMOUR(pedHandle, attrs.armor) end
    
    -- Weapon
    if attrs.weapon and attrs.weapon.model then
        local weaponHash = type(attrs.weapon.model) == "string" and MISC.GET_HASH_KEY(attrs.weapon.model) or attrs.weapon.model
        M.request_model_load(weaponHash)
        Script.Yield(100)
        WEAPON.GIVE_WEAPON_TO_PED(pedHandle, weaponHash, 9999, false, true)
    end
    
    -- Seat in parent vehicle
    if attrs.seat ~= nil and parentHandle then
        local parentType = ENTITY.GET_ENTITY_TYPE(parentHandle)
        if parentType == 2 then
            PED.SET_PED_INTO_VEHICLE(pedHandle, parentHandle, attrs.seat)
            PED.SET_PED_CAN_BE_DRAGGED_OUT(pedHandle, false)
            PED.SET_PED_STAY_IN_VEHICLE_WHEN_JACKED(pedHandle, true)
            PED.SET_PED_CONFIG_FLAG(pedHandle, 184, true)
            PED.SET_PED_CONFIG_FLAG(pedHandle, 292, true)
            PED.SET_PED_CONFIG_FLAG(pedHandle, 32, false)
            PED.SET_PED_COMBAT_ATTRIBUTES(pedHandle, 3, false)
            VEHICLE.SET_VEHICLE_ENGINE_ON(parentHandle, true, true, false)
        end
    end
end

-- Split version: Apply only ped animation - must be called AFTER attachment
function M.applyPedAttributesAnimation(pedHandle, attrs)
    if not attrs then return end
    
    local animDict = (attrs.animation and attrs.animation.dictionary) or attrs.animation_dict
    local animName = (attrs.animation and attrs.animation.clip) or attrs.animation_name
    local animLoop = attrs.animation and attrs.animation.loop
    if animDict and animName then
        Script.Yield(100)
        STREAMING.REQUEST_ANIM_DICT(animDict)
        local timeout = 0
        while not STREAMING.HAS_ANIM_DICT_LOADED(animDict) and timeout < 50 do
            Script.Yield(10)
            timeout = timeout + 1
        end
        if STREAMING.HAS_ANIM_DICT_LOADED(animDict) then
            TASK.TASK_PLAY_ANIM(pedHandle, animDict, animName, 8.0, -8.0, -1, animLoop and 1 or 1, 0, false, false, false)
        end
    end
end

-- Helper function to apply complex JSON vehicle attributes
function M.applyJSONVehicleAttributes(vehicleHandle, attrs)
    if not vehicleHandle or vehicleHandle == 0 or not attrs then return end
    
    -- 1. Mods (Before paint to ensure compatibility)
    VEHICLE.SET_VEHICLE_MOD_KIT(vehicleHandle, 0)
    if attrs.mods then
        for modKey, modValue in pairs(attrs.mods) do
            local modType = tonumber(modKey:match("_(%d+)"))
            if modType then
                if type(modValue) == "boolean" then
                    VEHICLE.TOGGLE_VEHICLE_MOD(vehicleHandle, modType, modValue)
                elseif type(modValue) == "number" then
                    VEHICLE.SET_VEHICLE_MOD(vehicleHandle, modType, modValue, false)
                end
            end
        end
    end

    -- 2. Livery (Standard and Legacy)
    if attrs.paint then
        if attrs.paint.livery and attrs.paint.livery ~= -1 then
            VEHICLE.SET_VEHICLE_MOD(vehicleHandle, 48, attrs.paint.livery, false)
            VEHICLE.SET_VEHICLE_LIVERY(vehicleHandle, attrs.paint.livery) 
        end
    end

    -- 3. Paint (Primary, Secondary, Pearl, Wheel, Interior, Dashboard)
    if attrs.paint then
        local p = attrs.paint
        local primary = p.primary and p.primary.vehicle_standard_color or 0
        local secondary = p.secondary and p.secondary.vehicle_standard_color or 0
        
        -- Set standard colors
        VEHICLE.SET_VEHICLE_COLOURS(vehicleHandle, primary, secondary)
        
        -- Custom Primary
        if p.primary and p.primary.is_custom and p.primary.custom_color and #p.primary.custom_color >= 3 then
            VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicleHandle, p.primary.custom_color[1], p.primary.custom_color[2], p.primary.custom_color[3])
        end
        
        -- Custom Secondary
        if p.secondary and p.secondary.is_custom and p.secondary.custom_color and #p.secondary.custom_color >= 3 then
            VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicleHandle, p.secondary.custom_color[1], p.secondary.custom_color[2], p.secondary.custom_color[3])
        end
        
        -- Pearlescent and Wheels
        local pearl = p.extra_colors and p.extra_colors.pearlescent or 0
        local wheelCol = p.extra_colors and p.extra_colors.wheel or 0
        VEHICLE.SET_VEHICLE_EXTRA_COLOURS(vehicleHandle, pearl, wheelCol)
        
        -- Interior and Dashboard
        if p.interior_color then
             -- Note: Natives for interior/dashboard exist but might not be exposed standardly in all APIs. 
             -- Cherax usually maps extra colors. If not available, we skip.
        end
        
        -- Enamel/Fade/Dirt
        if p.dirt_level then VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicleHandle, p.dirt_level) end
    end

    -- 4. Wheels (Type and Custom Tires)
    if attrs.wheels then
        if attrs.wheels.wheel_type then
            VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicleHandle, attrs.wheels.wheel_type)
        end
        -- Apply wheel mod if defined in mods to ensure it sticks
         if attrs.mods and attrs.mods._23 then
             VEHICLE.SET_VEHICLE_MOD(vehicleHandle, 23, attrs.mods._23, attrs.wheels.is_custom_tires or false)
         end
    end

    -- 5. Window Tint
    if attrs.options and attrs.options.window_tint and attrs.options.window_tint ~= -1 then
        VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicleHandle, attrs.options.window_tint)
    end
    
    -- 6. Neon
    if attrs.neon then
        if attrs.neon.lights then
            for i, side in pairs({[0] = "left", [1] = "right", [2] = "front", [3] = "back"}) do
                local enabled = attrs.neon.lights[side] or false
                VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, i, enabled)
                VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicleHandle, i, enabled)
            end
        end
        if attrs.neon.color then
            local r, g, b = attrs.neon.color.r or 255, attrs.neon.color.g or 255, attrs.neon.color.b or 255
            VEHICLE.SET_VEHICLE_NEON_COLOUR(vehicleHandle, r, g, b)
        end
    end
    
    -- 7. Extras
    if attrs.extras then
        for extraKey, enabled in pairs(attrs.extras) do
            local extraId = tonumber(extraKey:match("_(%d+)"))
            if extraId then
                VEHICLE.SET_VEHICLE_EXTRA(vehicleHandle, extraId, not enabled)
            end
        end
    end

    -- 8. Doors
    if attrs.doors and attrs.doors.open then
        local doorMap = {frontleft=0, frontright=1, backleft=2, backright=3, hood=4, trunk=5, trunk2=6}
        for doorName, isOpen in pairs(attrs.doors.open) do
            if isOpen and doorMap[doorName] then
                VEHICLE.SET_VEHICLE_DOOR_OPEN(vehicleHandle, doorMap[doorName], false, false)
            end
        end
    end
    
    -- 9. General Options
    if attrs.options then
        if attrs.options.engine_running then
            VEHICLE.SET_VEHICLE_ENGINE_ON(vehicleHandle, true, true, false)
        end
        if attrs.options.bulletproof_tires then
            VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicleHandle, false)
        end
        if attrs.options.license_plate_text then
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicleHandle, attrs.options.license_plate_text)
        end
        if attrs.options.license_plate_type then
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(vehicleHandle, attrs.options.license_plate_type)
        end
    end
end

-- JSON Map Spawning Function
function M.spawnMapFromJSON(filePath, isPreview)
    FreemodeQueueJob(function()
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[JSON Map Spawn Debug] Error: JSON file does not exist:", filePath)
            GUI.AddToast("Spawn Error", "JSON file not found", 3000, 0)
            return
        end
        
        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            M.debug_print("[JSON Map Spawn Debug] Error: Failed to read JSON file or content is empty:", filePath)
            GUI.AddToast("Spawn Error", "Failed to read JSON file", 3000, 0)
            return
        end
        
        -- Parse JSON using shared parser
        local jsonData = json_parser.parseJSON(jsonContent)
        if not jsonData then
            GUI.AddToast("Spawn Error", "Failed to parse JSON", 5000, 0)
            return
        end
        
        -- Detect Impulse array-of-arrays format and dispatch to dedicated handler
        if isImpulseArrayFormat(jsonData) then
            M.spawnMapFromImpulseJSON(filePath, jsonData, isPreview)
            return
        end
        
        local fileName = M.get_filename_from_path(filePath)
        local totalChildren = (jsonData.children and #jsonData.children or 0) + (jsonData.hash and 1 or 0)
        
        -- Delete old maps
        spawn_core.deleteOldMapIfEnabled()
        spawn_core.clearAreaIfEnabled()
        
        -- Get player position for reference
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, false)
        
        -- Determine the original map position (where it was saved)
        local originalPos = jsonData.position or { x = 0, y = 0, z = 0 }
        
        -- Determine reference coordinates and relocation delta
        local refCoords = {}
        local shouldTeleport = false
        local relocDelta = { x = 0, y = 0, z = 0 }
        
        if jsonData.always_spawn_at_position and jsonData.position then
            -- Map wants to spawn at its original position
            refCoords = { x = jsonData.position.x, y = jsonData.position.y, z = jsonData.position.z }
            shouldTeleport = spawnerSettings.teleportToMap
        elseif jsonData.position and spawnerSettings.teleportToMap then
            -- Teleport player to map's original position
            refCoords = { x = jsonData.position.x, y = jsonData.position.y, z = jsonData.position.z }
            shouldTeleport = true
        elseif spawnerSettings.spawnMapOnMe and jsonData.position then
            -- Relocate map to player position (calculate delta)
            refCoords = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
            relocDelta = {
                x = playerCoords.x - originalPos.x,
                y = playerCoords.y - originalPos.y,
                z = playerCoords.z - originalPos.z
            }
        else
            -- Default: use original position
            refCoords = { x = originalPos.x, y = originalPos.y, z = originalPos.z }
        end
        
        if shouldTeleport then
            ENTITY.SET_ENTITY_COORDS(playerPed, refCoords.x, refCoords.y, refCoords.z, false, false, false, true)
        end
        
        -- For maps, ConstructorLib spawns each object at its absolute world position
        -- NOT as attachments. The children hierarchy is flattened and each entity
        -- is placed at its 'position' with 'world_rotation', then frozen.
        
        -- Collect all entities from the tree (flatten the hierarchy)
        local function collectEntities(node, list)
            table.insert(list, node)
            if node.children and type(node.children) == "table" then
                local usedIpairs = false
                for _, child in ipairs(node.children) do
                    usedIpairs = true
                    collectEntities(child, list)
                end
                if not usedIpairs then
                    for _, child in pairs(node.children) do
                        if type(child) == "table" then
                            collectEntities(child, list)
                        end
                    end
                end
            end
        end
        
        -- Recursive function to spawn children and their nested children
        local function spawnMapChild(child, relocDelta, allEntities)
            local childModel = child.hash or child.model
            if not childModel then return nil end
            
            -- Calculate spawn position from absolute world position + relocation delta
            local spawnPos
            if child.position then
                spawnPos = {
                    x = child.position.x + relocDelta.x,
                    y = child.position.y + relocDelta.y,
                    z = child.position.z + relocDelta.z
                }
            else
                spawnPos = { x = refCoords.x, y = refCoords.y, z = refCoords.z }
            end
            
            -- Load model
            local modelToLoad = M.safe_tonumber(childModel, childModel) or childModel
            M.request_model_load(modelToLoad)
            local t0 = Time.GetEpoche()
            while not STREAMING.HAS_MODEL_LOADED(modelToLoad) and Time.GetEpoche() - t0 < 1.0 do
                Script.Yield(10)
            end
            if not STREAMING.HAS_MODEL_LOADED(modelToLoad) then return nil end
            
            local childName = child.name or child.model or tostring(childModel)
            
            local entityHandle = spawn_core.spawnEntityByType(child.type or "OBJECT", childModel, spawnPos, 0)
            
            if not entityHandle or entityHandle == 0 then
                return nil
            end
            
            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entityHandle, true, false)
            
            -- Force exact position (GTA.CreateObject applies a Z offset we need to undo)
            ENTITY.SET_ENTITY_COORDS_NO_OFFSET(entityHandle, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
            
            -- Apply world rotation (absolute rotation in world space)
            local rotData = child.world_rotation or child.rotation
            if rotData then
                local rotOrder = child.rotation_order or 2
                ENTITY.SET_ENTITY_ROTATION(entityHandle, rotData.x or 0, rotData.y or 0, rotData.z or 0, rotOrder, true)
            end
            
            -- Apply entity options
            spawn_core.applyEntityOptions(entityHandle, child.options)
            
            -- Freeze map objects in place
            ENTITY.FREEZE_ENTITY_POSITION(entityHandle, true)
            ENTITY.SET_ENTITY_LOD_DIST(entityHandle, 0xFFFF)
            
            -- Apply ped attributes if applicable
            if child.type == "PED" and child.ped_attributes then
                M.applyPedAttributes(entityHandle, child.ped_attributes, nil)
            end
            
            table.insert(allEntities, entityHandle)
            
            return entityHandle
        end
        
        -- Flatten the entire entity tree (root + all nested children)
        local allNodes = {}
        collectEntities(jsonData, allNodes)
        
        -- Spawn each entity at its absolute world position
        local spawnedEntities = {}
        local totalNodes = #allNodes
        local progressShown = { [25] = false, [50] = false, [75] = false }
        for i, node in ipairs(allNodes) do
            spawnMapChild(node, relocDelta, spawnedEntities)
            -- Show progress toasts at 25%, 50%, 75% for maps over 200 entities
            if totalNodes > 200 then
                local percentComplete = math.floor((#spawnedEntities / totalNodes) * 100)
                if percentComplete >= 25 and not progressShown[25] then
                    progressShown[25] = true
                    GUI.AddToast("Spawning Map", "25% completed (" .. #spawnedEntities .. "/" .. totalNodes .. ")", 2000, 0)
                elseif percentComplete >= 50 and not progressShown[50] then
                    progressShown[50] = true
                    GUI.AddToast("Spawning Map", "50% completed (" .. #spawnedEntities .. "/" .. totalNodes .. ")", 2000, 0)
                elseif percentComplete >= 75 and not progressShown[75] then
                    progressShown[75] = true
                    GUI.AddToast("Spawning Map", "75% completed (" .. #spawnedEntities .. "/" .. totalNodes .. ")", 2000, 0)
                end
            end
        end
        
        -- Track spawned map
        local mapRecord = {
            entities = spawnedEntities,
            filePath = filePath,
            markers = {},
            refCoords = refCoords
        }
        table.insert(spawnedMaps, mapRecord)
        
        local toastMsg = fileName .. " (" .. #spawnedEntities .. "/" .. #allNodes .. " entities)"
            GUI.AddToast("Map Spawned", toastMsg, 5000, 0)
            print("Map Spawned", toastMsg)
    end)
end

-- Impulse/JamezGamez Array-of-Arrays JSON Map Spawning Function
-- Format: [ ["modelName", hash, x, y, z, rotX, rotY, rotZ, refX?, refY?, refZ?], ... ]
function M.spawnMapFromImpulseJSON(filePath, jsonData, isPreview)
    FreemodeQueueJob(function()
        local fileName = M.get_filename_from_path(filePath)
        local totalEntities = #jsonData
        
        M.debug_print("[Impulse JSON Map] Spawning", fileName, "with", totalEntities, "entities")
        
        -- Delete old maps
        spawn_core.deleteOldMapIfEnabled()
        spawn_core.clearAreaIfEnabled()
        
        -- Get player position for reference
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, false)
        
        -- Determine reference coords from 11-element entries or first entity position
        local refCoords = nil
        for _, entry in ipairs(jsonData) do
            if #entry >= 11 then
                refCoords = { x = entry[9], y = entry[10], z = entry[11] }
                break
            end
        end
        local mapCenter = jsonData[1] and { x = jsonData[1][3], y = jsonData[1][4], z = jsonData[1][5] } or nil
        local teleportRef = refCoords or mapCenter
        
        -- Spawn offset / teleport
        local offset = spawn_core.calcSpawnOnMeOffset(teleportRef)
        if not spawnerSettings.spawnMapOnMe then
            spawn_core.teleportPlayerIfEnabled(teleportRef)
        end
        
        -- Spawn all entities
        local spawnedEntities = {}
        local progressShown = { [25] = false, [50] = false, [75] = false }
        
        for i, entry in ipairs(jsonData) do
            local modelName = entry[1]
            local modelHash = entry[2]
            local spawnPos = { x = entry[3] + offset.x, y = entry[4] + offset.y, z = entry[5] + offset.z }
            local rotX, rotY, rotZ = entry[6], entry[7], entry[8]
            
            -- Impulse maps are all objects
            local entityHandle = spawn_core.spawnEntityByType("OBJECT", modelHash, spawnPos)
            
            if entityHandle and entityHandle ~= 0 then
                ENTITY.SET_ENTITY_ROTATION(entityHandle, rotX or 0, rotY or 0, rotZ or 0, 2, true)
                table.insert(spawnedEntities, entityHandle)
            else
                M.debug_print("[Impulse JSON Map] Failed to spawn entity:", modelName, "(", modelHash, ")")
            end
            
            -- Show progress toasts at 25%, 50%, 75% for maps over 200 entities
            if totalEntities > 200 then
                local percentComplete = math.floor((#spawnedEntities / totalEntities) * 100)
                if percentComplete >= 25 and not progressShown[25] then
                    progressShown[25] = true
                    GUI.AddToast("Spawning Map", "25% completed (" .. #spawnedEntities .. "/" .. totalEntities .. ")", 2000, 0)
                elseif percentComplete >= 50 and not progressShown[50] then
                    progressShown[50] = true
                    GUI.AddToast("Spawning Map", "50% completed (" .. #spawnedEntities .. "/" .. totalEntities .. ")", 2000, 0)
                elseif percentComplete >= 75 and not progressShown[75] then
                    progressShown[75] = true
                    GUI.AddToast("Spawning Map", "75% completed (" .. #spawnedEntities .. "/" .. totalEntities .. ")", 2000, 0)
                end
            end
        end
        
        -- Track spawned map
        local effectiveRef = teleportRef or { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
        if spawnerSettings.spawnMapOnMe and teleportRef then
            effectiveRef = { x = teleportRef.x + offset.x, y = teleportRef.y + offset.y, z = teleportRef.z + offset.z }
        end
        
        local mapRecord = {
            entities = spawnedEntities,
            filePath = filePath,
            markers = {},
            refCoords = effectiveRef
        }
        table.insert(spawnedMaps, mapRecord)
        
        local toastMsg = fileName .. " (" .. #spawnedEntities .. "/" .. totalEntities .. " entities)"
            GUI.AddToast("Map Spawned", toastMsg, 5000, 0)
            print("Map Spawned", toastMsg)
    end)
end

-- JSON Outfit Spawning Function
-- JSON Outfit Spawning Function
function M.spawnOutfitFromJSON(filePath, isPreview)
    isPreview = isPreview or false
    
    FreemodeQueueJob(function()
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[JSON Outfit Spawn Debug] Error: JSON file does not exist:", filePath)
            GUI.AddToast("Spawn Error", "JSON file not found", 3000, 0)
            return
        end
        
        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            M.debug_print("[JSON Outfit Spawn Debug] Error: Failed to read JSON file or content is empty:", filePath)
            GUI.AddToast("Spawn Error", "Failed to read JSON file", 3000, 0)
            return
        end
        
        -- Parse JSON using shared parser
        local jsonData = json_parser.parseJSON(jsonContent)
        if not jsonData then
            GUI.AddToast("Spawn Error", "Failed to parse JSON", 5000, 0)
            return
        end
        
        if jsonData.type ~= "PED" then
            M.debug_print("[JSON Outfit Spawn Debug] Error: JSON is not a PED type, got:", tostring(jsonData.type))
            GUI.AddToast("Spawn Error", "This JSON is not a PED outfit", 3000, 0)
            return
        end
        
        local isAttachToPlayer = (jsonData.is_player == false)
        local modelHash = jsonData.hash or jsonData.model
        if not isAttachToPlayer and (not modelHash or modelHash == 0) then return end
        
        local playerInfo = spawn_core.getPlayerPedInfo()
        if not playerInfo then return end
        
        local spawnCoords
        if isPreview then
            spawnCoords = spawn_core.calcOutfitSpawnCoords(playerInfo, true)
        else
            spawnCoords = { x = playerInfo.coords.x, y = playerInfo.coords.y, z = playerInfo.coords.z }
        end
        
        -- Delete old outfit attachments
        spawn_core.deleteOldOutfitIfEnabled()
        
        -- Determine target ped
        local targetPed
        local spawnedPed = nil
        
        if spawnerSettings.onlyApplyAttachments or isAttachToPlayer then
            targetPed = playerInfo.handle
        else
            M.request_model_load(modelHash)
            Script.Yield(200)
            local h = GTA.CreatePed(modelHash, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, playerInfo.heading, false, false)
            if h and h ~= 0 then
                spawnedPed = h
                ENTITY.SET_ENTITY_LOD_DIST(spawnedPed, 0xFFFF)
            end
            if not spawnedPed or spawnedPed == 0 then
                M.debug_print("[JSON Outfit Spawn Debug] Error: Failed to spawn ped")
                return
            end
            targetPed = spawnedPed
        end
        
        -- Apply ped attributes (components, props, armor, weapon)
        if jsonData.ped_attributes and not spawnerSettings.onlyApplyAttachments then
            M.applyPedAttributes(targetPed, jsonData.ped_attributes)
        end
        
        -- Change player to spawned ped
        if spawnedPed and not isAttachToPlayer then
            local playerID = PLAYER.PLAYER_ID()
                if playerID and playerID >= 0 then
                    local currentPed = PLAYER.PLAYER_PED_ID()
                    local currentRelGroup = PED.GET_PED_RELATIONSHIP_GROUP_HASH(currentPed)
                    PLAYER.CHANGE_PLAYER_PED(playerID, spawnedPed, true, false)
                    if currentRelGroup ~= 0 then
                        PED.SET_PED_RELATIONSHIP_GROUP_HASH(spawnedPed, currentRelGroup)
                    else
                        PED.SET_PED_RELATIONSHIP_GROUP_HASH(spawnedPed, MISC.GET_HASH_KEY("PLAYER"))
                    end
                    Script.Yield(2000)
                    FeatureMgr.GetFeatureByName("Give All Weapons"):TriggerCallback()
                end
        end
        
        -- Spawn and attach children objects recursively
        local attachedObjects = {}
        local function spawnAndAttachChildren(children, parentEntity, parentName)
            if not children or #children == 0 then return end
            for i, child in ipairs(children) do
                local childModel = child.hash or child.model
                if childModel then
                    local objectHandle = spawn_core.spawnEntityByType(child.type or "OBJECT", childModel, spawnCoords)
                    if objectHandle and objectHandle ~= 0 then
                        spawn_core.applyEntityOptions(objectHandle, child.options)
                        
                        local boneIndex = child.options and child.options.bone_index or 0
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
                        table.insert(attachedObjects, objectHandle)
                        
                        if child.children and type(child.children) == "table" and #child.children > 0 then
                            spawnAndAttachChildren(child.children, objectHandle, child.name or tostring(childModel))
                        end
                    end
                end
            end
        end
        
        if jsonData.children and #jsonData.children > 0 then
            local parentName = isAttachToPlayer and "player" or "spawned ped"
            spawnAndAttachChildren(jsonData.children, targetPed, parentName)
        end
        
        -- Handle preview vs actual spawn
        if isPreview then
            if spawnedPed then table.insert(previewEntities, spawnedPed) end
            for _, obj in ipairs(attachedObjects) do table.insert(previewEntities, obj) end
        else
            local outfitRecord = {
                spawnedPed = spawnedPed,
                attachments = attachedObjects,
                filePath = filePath,
                attachedToPlayer = isAttachToPlayer
            }
            table.insert(spawnedOutfits, outfitRecord)
            local fileName = M.get_filename_from_path(filePath)
                local msg = isAttachToPlayer 
                    and ("Attached " .. #attachedObjects .. " object" .. (#attachedObjects == 1 and "" or "s") .. " to player")
                    or ("Spawned " .. fileName .. " with " .. #attachedObjects .. " attachment" .. (#attachedObjects == 1 and "" or "s"))
                GUI.AddToast("Outfit Spawned", msg, 5000, 0)
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

-- ============================================================================
-- Job/Transform JSON Map Spawning
-- Format: { mission: { prop: {model[], loc[], vRot[], head[], no}, dprop: {...}, veh: {...} } }
-- ============================================================================
function M.spawnMapFromJobJSON(filePath, isPreview)
    FreemodeQueueJob(function()
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Job Map Spawn] Error: file does not exist:", filePath)
            GUI.AddToast("Spawn Error", "Job JSON file not found", 3000, 0)
            return
        end

        local jsonContent = FileMgr.ReadFileContent(filePath)
        if not jsonContent or jsonContent == "" then
            M.debug_print("[Job Map Spawn] Error: Failed to read file:", filePath)
            GUI.AddToast("Spawn Error", "Failed to read Job JSON file", 3000, 0)
            return
        end

        -- Parse JSON using robust recursive descent parser (handles large 1MB+ files)
        local jsonData = asset_loader.json_decode(jsonContent)
        if not jsonData then
            GUI.AddToast("Spawn Error", "Failed to parse Job JSON", 5000, 0)
            return
        end

        -- Verify this is actually a Job format
        if not job_parser.isJobFormat(jsonData) then
            -- Fallback: try spawning as regular JSON map
            M.debug_print("[Job Map Spawn] Not a Job format, falling back to regular JSON map")
            M.spawnMapFromJSON(filePath, isPreview)
            return
        end

        local fileName = M.get_filename_from_path(filePath)
        local parsed = job_parser.parseJobEntities(jsonData)
        local entities = parsed.entities
        local refCoords = parsed.refCoords

        if #entities == 0 then
            GUI.AddToast("Spawn Error", "No spawnable entities found in Job JSON", 5000, 0)
            return
        end

        M.debug_print("[Job Map Spawn] Spawning", fileName, "with", #entities, "entities")

        -- Delete old maps
        spawn_core.deleteOldMapIfEnabled()
        spawn_core.clearAreaIfEnabled()

        -- Get player position
        local playerPed = PLAYER.PLAYER_PED_ID()
        local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, false)

        -- Determine relocation offset
        local offset = spawn_core.calcSpawnOnMeOffset(refCoords)
        if not spawnerSettings.spawnMapOnMe then
            spawn_core.teleportPlayerIfEnabled(refCoords, false)
        end

        -- Spawn each entity
        local spawnedEntities = {}
        local totalEntities = #entities
        local progressShown = { [25] = false, [50] = false, [75] = false }
        for i, ent in ipairs(entities) do
            local spawnPos = {
                x = ent.pos.x + offset.x,
                y = ent.pos.y + offset.y,
                z = ent.pos.z + offset.z
            }

            -- Load model
            local modelHash = M.safe_tonumber(ent.model, ent.model) or ent.model
            M.request_model_load(modelHash)
            local t0 = Time.GetEpoche()
            while not STREAMING.HAS_MODEL_LOADED(modelHash) and Time.GetEpoche() - t0 < 1.0 do
                Script.Yield(10)
            end
            if not STREAMING.HAS_MODEL_LOADED(modelHash) then
                M.debug_print("[Job Map Spawn] Failed to load model:", tostring(modelHash))
                goto continue
            end

            local entityHandle = spawn_core.spawnEntityByType(ent.entityType or "OBJECT", modelHash, spawnPos, ent.heading or 0)

            if entityHandle and entityHandle ~= 0 then
                ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entityHandle, true, false)
                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(entityHandle, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)

                -- Apply rotation: prefer vRot (full xyz rotation) over heading-only
                if ent.rot then
                    ENTITY.SET_ENTITY_ROTATION(entityHandle, ent.rot.x or 0, ent.rot.y or 0, ent.rot.z or 0, 2, true)
                elseif ent.heading then
                    ENTITY.SET_ENTITY_HEADING(entityHandle, ent.heading)
                end

                ENTITY.FREEZE_ENTITY_POSITION(entityHandle, true)
                ENTITY.SET_ENTITY_LOD_DIST(entityHandle, 0xFFFF)

                -- Apply texture variation (tint index) if present
                if ent.tintIndex and ent.tintIndex >= 0 then
                    OBJECT.SET_OBJECT_TINT_INDEX(entityHandle, ent.tintIndex)
                end

                -- Network the entity if enabled
                if spawnerSettings.networkMapsV2Enabled then
                    pcall(function()
                        NETWORK.NETWORK_REGISTER_ENTITY_AS_NETWORKED(entityHandle)
                        local netId = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(entityHandle)
                        if netId and netId ~= 0 then
                            NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(netId, true)
                            NETWORK.SET_NETWORK_ID_CAN_MIGRATE(netId, true)
                        end
                    end)
                end

                table.insert(spawnedEntities, entityHandle)
            end

            -- Show progress toasts at 25%, 50%, 75% for maps over 200 entities
            if totalEntities > 200 then
                local percentComplete = math.floor((#spawnedEntities / totalEntities) * 100)
                if percentComplete >= 25 and not progressShown[25] then
                    progressShown[25] = true
                    GUI.AddToast("Spawning Job Map", "25% completed (" .. #spawnedEntities .. "/" .. totalEntities .. ")", 2000, 0)
                elseif percentComplete >= 50 and not progressShown[50] then
                    progressShown[50] = true
                    GUI.AddToast("Spawning Job Map", "50% completed (" .. #spawnedEntities .. "/" .. totalEntities .. ")", 2000, 0)
                elseif percentComplete >= 75 and not progressShown[75] then
                    progressShown[75] = true
                    GUI.AddToast("Spawning Job Map", "75% completed (" .. #spawnedEntities .. "/" .. totalEntities .. ")", 2000, 0)
                end
            end

            -- Yield periodically to avoid freezing
            if i % 10 == 0 then
                Script.Yield(0)
            end

            ::continue::
        end

        -- Track spawned map
        local mapRecord = {
            entities = spawnedEntities,
            filePath = filePath,
            markers = {},
            refCoords = refCoords
        }
        table.insert(spawnedMaps, mapRecord)

        local toastMsg = fileName .. " (" .. #spawnedEntities .. "/" .. #entities .. " entities)"
        GUI.AddToast("Job Map Spawned", toastMsg, 5000, 0)
        print("Job Map Spawned", toastMsg)
    end)
end

return M
