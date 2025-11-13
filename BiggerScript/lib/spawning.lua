local M = {}
local previewUpdateJob = nil
local isPreviewUpdaterRunning = false -- New flag for controlling the preview job
local lastSpawnedVehiclePath = nil

-- Context variables to be initialized by the main script
local upsidedownmap_module, spawnerSettings, debug_print, spawnedVehicles, spawnedMaps, spawnedOutfits, previewEntities, currentPreviewFile, constructor_lib, parse_ini_file, get_xml_element_content, get_xml_element, to_boolean, safe_tonumber, trim, split_str, request_model_load, xmlVehiclesFolder, iniVehiclesFolder, xmlMapsFolder, xmlOutfitsFolder, previewRotation, spawnedProps, currentSelectedVehicleXml, currentSelectedVehicleIni

-- Preview Feature Start (Moved from BiggerScriptv0.3.2.lua)
local previewRotation = { z = 0.0 }
-- Preview Feature End

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
    xmlMapsFolder = context.xmlMapsFolder
    xmlOutfitsFolder = context.xmlOutfitsFolder
    -- previewRotation = context.previewRotation -- Removed as it's now local to spawning.lua
    spawnedProps = context.spawnedProps
    currentSelectedVehicleXml = context.currentSelectedVehicleXml
    currentSelectedVehicleIni = context.currentSelectedVehicleIni

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
        spawnMapFromXML = M.spawnMapFromXML
    })
    
    M.spawnUpsideDownMapV3 = upsidedownmap_module.spawnUpsideDownMapV3
end

function M.debug_print(...)
    if spawnerSettings.printToDebug then
        print(...)
    end
end

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

function M.parse_ini_file(filePath)
    local iniContent = FileMgr.ReadFileContent(filePath)
    if not iniContent then return nil end
    local data = {}
    local currentSection = nil
    for line in iniContent:gmatch("[^\r\n]+") do
        M.debug_print("[Parse INI Debug] Processing line:", line)
        line = M.trim(line)
        if line:match("^%[.+%]$") then
            currentSection = line:match("^%[(.+)%]$")
            data[currentSection] = data[currentSection] or {}
            M.debug_print("[Parse INI Debug] Found section:", currentSection)
        elseif line:match("^[^;=]+=[^;]*$") and currentSection then
            local key, value = line:match("^([^;=]+)=([^;]*)$")
            if key and value then
                local trimmedKey = M.trim(key)
                local trimmedValue = M.trim(value):match("^(.-)%s*;.*$") or M.trim(value)
                data[currentSection][trimmedKey] = trimmedValue
                M.debug_print("[Parse INI Debug] Section:", currentSection, "Key:", trimmedKey, "Value:", trimmedValue)
            end
        end
    end
    M.debug_print("[Parse INI Debug] Finished parsing INI file. Data table:", tostring(data))
    return data
end

function M.request_model_load(hashOrName)
    if not hashOrName then return end
    local model = M.safe_tonumber(hashOrName, nil) or hashOrName
    if STREAMING and STREAMING.REQUEST_MODEL and model then
        pcall(function()
            STREAMING.REQUEST_MODEL(model)
            local t0 = os.time()
            while not STREAMING.HAS_MODEL_LOADED(model) and os.time() - t0 < 1 do Script.Yield(10) end
        end)
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
            local t0 = os.time()
            while not STREAMING.HAS_ANIM_DICT_LOADED(animDict) and os.time() - t0 < 2 do
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
        if M.safe_tonumber(sectionName) ~= nil or sectionName:match("^Attached Object %d+$") or sectionName:match("^Vehicle%d+$") then
            if sectionName == "Vehicle0" then goto continue end
            M.debug_print("[Parse INI Debug] Processing attachment section:", sectionName, "Content:", tostring(attachmentSection))
            local att = {}
            att.ModelHash = M.safe_tonumber(attachmentSection.Hash or attachmentSection.model or attachmentSection.Model, nil)
            att.HashName = attachmentSection["model name"] or attachmentSection["Model Name"] or attachmentSection.model or attachmentSection.Model or attachmentSection.Hash
            att.Type = "3"
            att.InitialHandle = M.safe_tonumber(attachmentSection.SelfNumeration, nil)
            att.PositionRotation = {
                X = M.safe_tonumber(attachmentSection["x offset"] or attachmentSection.X or attachmentSection.x, 0.0),
                Y = M.safe_tonumber(attachmentSection["y offset"] or attachmentSection.Y or attachmentSection.y, 0.0),
                Z = M.safe_tonumber(attachmentSection["z offset"] or attachmentSection.Z or attachmentSection.z, 0.0),
                Pitch = M.safe_tonumber(attachmentSection.pitch or attachmentSection.RotX or attachmentSection.rotX, 0.0),
                Roll = M.safe_tonumber(attachmentSection.roll or attachmentSection.RotY or attachmentSection.rotY, 0.0),
                Yaw = M.safe_tonumber(attachmentSection.yaw or attachmentSection.RotZ or attachmentSection.rotZ, 0.0)
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
            table.insert(attachments, att)
        end
        ::continue::
    end
    return attachments
end

function M.parse_spooner_attachments(xml)
    local out = {}
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
                e.Dynamic = M.get_xml_element_content(attInner, "Dynamic")
                e.FrozenPos = M.get_xml_element_content(attInner, "FrozenPos")
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
M.debug_print("[Parse Attach Debug] IsCollisionProof tag read as:", tostring(e.IsCollisionProof))

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
        if GTA and GTA.CreatePed then
            local ok, h = pcall(function() return GTA.CreatePed(mnum, 26, coords.x, coords.y, coords.z, 0, true, true) end)
            if ok and h and h ~= 0 then return h end
        end
        if GTA and GTA.CreateRandomPed then
            local ok, h = pcall(function() return GTA.CreateRandomPed(coords.x, coords.y, coords.z) end)
            if ok and h and h ~= 0 then return h end
        end
        return 0
    end
    if typ == "2" or typ == 2 then
        if GTA and GTA.SpawnVehicle then
            local ok, h = pcall(function() return GTA.SpawnVehicle(mnum, coords.x, coords.y, coords.z, 0, true, true) end)
            if ok and h and h ~= 0 then return h end
        end
        return 0
    end
    if typ == "3" or typ == 3 then
        if GTA and GTA.CreateObject then
            local ok, h = pcall(function() return GTA.CreateObject(mnum, coords.x, coords.y, coords.z, true, true) end)
            if ok and h and h ~= 0 then
                pcall(function() if ENTITY and ENTITY.SET_ENTITY_COORDS then ENTITY.SET_ENTITY_COORDS(h, coords.x, coords.y, coords.z, false, false, false, true) end end)
                return h
            end
        end
        if GTA and GTA.CreateWorldObject then
            local ok, h = pcall(function() return GTA.CreateWorldObject(mnum, coords.x, coords.y, coords.z, true, true) end)
            if ok and h and h ~= 0 then
                pcall(function() if ENTITY and ENTITY.SET_ENTITY_COORDS then ENTITY.SET_ENTITY_COORDS(h, coords.x, coords.y, coords.z, false, false, false, true) end end)
                return h
            end
        end
        if OBJECT and OBJECT.CREATE_OBJECT then
            local ok, h = pcall(function() return OBJECT.CREATE_OBJECT(mnum, coords.x, coords.y, coords.z, true, false, false) end)
            if ok and h and h ~= 0 then
                pcall(function() if ENTITY and ENTITY.SET_ENTITY_COORDS then ENTITY.SET_ENTITY_COORDS(h, coords.x, coords.y, coords.z, false, false, false, true) end end)
                return h
            end
        end
        if GTA and GTA.SpawnVehicle then
            local ok, h = pcall(function() return GTA.SpawnVehicle(mnum, coords.x, coords.y, coords.z, 0, true, true) end)
            if ok and h and h ~= 0 then return h end
        end
        return 0
    end
    return 0
end

function M.spawn_attachments(parsedAttachments, parentHandleMap, fallbackCoords, disableCollisionForAttachments, isPreview)
    M.debug_print("[Spawn Debug] Starting spawn_attachments. Number of attachments to process:", #parsedAttachments, "Is Preview:", tostring(isPreview))
    local created = {}
    local attachMeta = {}
    local playerPed = nil
    local playerPos = nil
    local playerHeading = 0.0
    pcall(function()
        playerPed = GTA.GetLocalPed()
        if playerPed then playerPos = playerPed.Position M.debug_print("[Spawn Debug] Player position:", playerPos.x, playerPos.y, playerPos.z) playerHeading = playerPed.Heading or 0.0 end
    end)
    for i, att in ipairs(parsedAttachments) do
        M.debug_print("[Spawn Debug] Processing attachment", i, ": ModelHash:", att.ModelHash, "HashName:", att.HashName, "Type:", att.Type)
        local model = att.ModelHash or att.HashName
        if not model then
            M.debug_print("[Spawn Debug] Warning: Attachment", i, "has no model hash or name. Skipping.")
            goto continue
        end
        local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
        if att.PositionRotation and (att.PositionRotation.X or att.PositionRotation.Y or att.PositionRotation.Z) then
            spawnCoords.x = att.PositionRotation.X or 0.0
            spawnCoords.y = att.PositionRotation.Y or 0.0
            spawnCoords.z = att.PositionRotation.Z or 0.0
            M.debug_print("[Spawn Debug] Attachment", i, "using explicit position:", spawnCoords.x, spawnCoords.y, spawnCoords.z)
        elseif fallbackCoords and fallbackCoords.x and fallbackCoords.y and fallbackCoords.z then
            spawnCoords.x = fallbackCoords.x
            spawnCoords.y = fallbackCoords.y
            spawnCoords.z = fallbackCoords.z
            M.debug_print("[Spawn Debug] Attachment", i, "using fallback position:", spawnCoords.x, spawnCoords.y, spawnCoords.z)
        elseif playerPos then
            local forwardX = math.sin(math.rad(playerHeading)) * 1.5
            local forwardY = math.cos(math.rad(playerHeading)) * 1.5
            spawnCoords.x = playerPos.x + forwardX
            spawnCoords.y = playerPos.y + forwardY
            spawnCoords.z = playerPos.z + 0.5
            M.debug_print("[Spawn Debug] Attachment", i, "using player-relative position:", spawnCoords.x, spawnCoords.y, spawnCoords.z)
        else
            spawnCoords.x = 0.0; spawnCoords.y = 0.0; spawnCoords.z = 0.0
            M.debug_print("[Spawn Debug] Attachment", i, "using default 0,0,0 position.")
        end
        M.request_model_load(model)
        if STREAMING and STREAMING.HAS_MODEL_LOADED then
            local t0 = os.time()
            while not pcall(function() return STREAMING.HAS_MODEL_LOADED(M.safe_tonumber(model, model) or model) end) and os.time() - t0 < 1 do
                Script.Yield(10)
            end
            if not pcall(function() return STREAMING.HAS_MODEL_LOADED(M.safe_tonumber(model, model) or model) end) then
                M.debug_print("[Spawn Debug] Error: Model failed to load for attachment", i, ":", tostring(model))
            end
        else
            Script.Yield(50)
        end
        local h = M.create_by_type(model, att.Type, spawnCoords)
        if not h or h == 0 then
            pcall(function() GUI.AddToast("Spawn Error", "Failed to spawn " .. (att.HashName or tostring(att.ModelHash)), 5000, 0) end)
            M.debug_print("[Spawn Debug] Error: Failed to create entity for attachment", i, "model:", tostring(model))
            goto continue
        end
        M.debug_print("[Spawn Debug] Successfully created entity for attachment", i, "with handle:", tostring(h), "Model:", tostring(model), "Type:", tostring(att.Type))
        table.insert(created, h)
        if att.InitialHandle then
            local ihNum = M.safe_tonumber(att.InitialHandle, nil)
            local ihStr = tostring(att.InitialHandle)
            if ihNum ~= nil then parentHandleMap[ihNum] = h end
            parentHandleMap[ihStr] = h
            M.debug_print("[Spawn Debug] Attachment", i, "InitialHandle:", tostring(att.InitialHandle), "mapped to handle:", tostring(h))
        end
        if att.IsInvincible then pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) M.debug_print("[Spawn Debug] Attachment", i, "set invincible.") end
        if att.IsVisible ~= nil then pcall(function() ENTITY.SET_ENTITY_VISIBLE(h, att.IsVisible, false) end) M.debug_print("[Spawn Debug] Attachment", i, "set visible:", tostring(att.IsVisible)) end
        if isPreview then
            pcall(function() ENTITY.SET_ENTITY_COLLISION(h, false, false) end)
            M.debug_print("[Spawn Debug] Attachment", i, "collision disabled for preview.")
        else
            -- Apply collision proofing based on original setting
            local finalCollisionProof = false
if att.IsCollisionProof ~= nil then
    local val = tostring(att.IsCollisionProof):lower()
    finalCollisionProof = (val == "true" or val == "1")
end
-- Apply damage proofs
pcall(function()
    ENTITY.SET_ENTITY_PROOFS(h, false, finalCollisionProof, false, false, false, false, false, false)
end)

-- Apply actual collision toggle (so IsCollisionProof=true means no physical collision)
pcall(function()
    ENTITY.SET_ENTITY_COLLISION(h, not finalCollisionProof, false)
end)

M.debug_print("[Spawn Debug] Attachment", i, "set collision proof:", tostring(finalCollisionProof), "collision enabled:", tostring(not finalCollisionProof))


M.debug_print("[Spawn Debug] Attachment", i, "XML IsCollisionProof value:", tostring(att.IsCollisionProof), "→ finalCollisionProof:", tostring(finalCollisionProof))

            pcall(function() ENTITY.SET_ENTITY_PROOFS(h, false, finalCollisionProof, false, false, false, false, false, false) end)
            M.debug_print("[Spawn Debug] Attachment", i, "set collision proof:", tostring(finalCollisionProof))
        end

        if att.FrozenPos ~= nil then pcall(function() ENTITY.FREEZE_ENTITY_POSITION(h, att.FrozenPos) end) M.debug_print("[Spawn Debug] Attachment", i, "set frozen position:", tostring(att.FrozenPos)) end
        if att.OpacityLevel ~= nil then
            local opacityLevel = M.safe_tonumber(att.OpacityLevel, nil)
            if opacityLevel ~= nil and opacityLevel == 0 then
                pcall(function() ENTITY.SET_ENTITY_VISIBLE(h, false, false) end)
                M.debug_print("[Spawn Debug] Attachment", i, "set invisible due to opacity level 0.")
            end
        end
        if att.PedProperties and (tostring(att.Type) == "1") then
            M.apply_ped_properties(h, att.PedProperties)
            M.debug_print("[Spawn Debug] Applied ped properties for attachment", i)
        end
        local meta = {
            created = h,
            attachedto = nil,
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
            M.debug_print("[Spawn Debug] Attachment", i, "attachment meta - AttachedTo:", tostring(meta.attachedto), "BoneIndex:", tostring(meta.bone), "Coords:", meta.x, meta.y, meta.z, "Rot:", meta.pitch, meta.roll, meta.yaw)
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
    M.debug_print("[Spawn Debug] Parent handle map (before attachments):", table.concat(phdbg, ", "))
    M.debug_print("[Spawn Debug] Full attachMeta table (before attachments):", tostring(attachMeta)) -- Added debug print for full attachMeta
    for _, m in ipairs(attachMeta) do
        M.debug_print("[Spawn Debug] Processing attachment meta for entity:", tostring(m.created), "AttachedTo:", tostring(m.attachedto), "Bone:", tostring(m.bone), "Offsets:", m.x, m.y, m.z, "Rot:", m.pitch, m.roll, m.yaw)
        if m.attachedto then
            local parentHandle = parentHandleMap[M.safe_tonumber(m.attachedto)] or parentHandleMap[tostring(m.attachedto)]
            if parentHandle and parentHandle ~= 0 and m.created and m.created ~= 0 then
                M.debug_print("[Spawn Debug] Attempting to attach entity", tostring(m.created), "to parent", tostring(parentHandle), "Bone:", tostring(m.bone), "Offsets:", m.x, m.y, m.z, "Rot:", m.pitch, m.roll, m.yaw, "IsCollisionProof:", tostring(m.iscollisionproof), "IsPed:", tostring(m.isped))
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
                    M.debug_print("[Spawn Debug] Successfully attached entity", tostring(m.created), "to parent", tostring(parentHandle))
                else
                    M.debug_print("[Spawn Debug] Error attaching entity", tostring(m.created), "to parent", tostring(parentHandle), ":", tostring(err))
                end
            else
                M.debug_print("[Spawn Debug] Warning: Could not attach entity", tostring(m.created), ". Parent handle not found or invalid for attachedto:", tostring(m.attachedto))
            end
        else
            M.debug_print("[Spawn Debug] Warning: Attachment", tostring(m.created), "has no 'attachedto' property. Not attaching.")
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
        M.debug_print("[Preview Manager] Clearing previous preview entities and stopping updater.")
        M.clearPreview()
        M.stopPreviewUpdater()
    end

    currentPreviewFile = hoveredFile

    if not hoveredFile then
        M.debug_print("[Preview Manager] No file hovered, ensuring preview is cleared.")
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
                        -- Ensure collision is disabled for all preview entities, as set during spawn_attachments
                        -- No need for a loop here, as collision is handled by the isPreview flag in spawn_attachments
                        
                        local camCoords = CAM.GET_GAMEPLAY_CAM_COORD()
                        local camRot = CAM.GET_GAMEPLAY_CAM_ROT(2) -- 2 for Euler angles
                        
                        local isOutfit = ENTITY.GET_ENTITY_TYPE(mainEntity) == 1 -- 1 for ped
                        local offset_distance = isOutfit and 2.5 or 25.0 -- Increased distance for camera preview
                        local offset_height = isOutfit and -0.5 or 0.0 -- Adjusted height for camera preview

                        local camForward = M.RotToDir(camRot)
                        local spawnPos = {
                            x = camCoords.x + (camForward.x * offset_distance),
                            y = camCoords.y + (camForward.y * offset_distance),
                            z = camCoords.z + (camForward.z * offset_distance) + offset_height
                        }
                        
                        -- Removed groundZ logic as per user feedback for previews
                        -- if isOutfit then
                        --     local foundGround, groundZ = GTA.GetGroundZ(spawnPos.x, spawnPos.y)
                        --     if foundGround then spawnPos.z = groundZ end
                        -- end

                        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(mainEntity, spawnPos.x, spawnPos.y, spawnPos.z, false, false, true)
                        
                        previewRotation.z = previewRotation.z + 1.0
                        if previewRotation.z > 360 then previewRotation.z = 0.0 end
                        
                        -- Align the entity with the camera's yaw, but keep pitch and roll at 0 for a stable preview
                        ENTITY.SET_ENTITY_ROTATION(mainEntity, 0.0, 0.0, camRot.z + previewRotation.z, 2, true)
                    end
                else
                    M.clearPreview()
                end
            end
            Script.Yield(0)
            ::continue_loop::
        end
        previewUpdateJob = nil -- Clear the job reference when the loop ends
        M.debug_print("[Preview Updater] Preview updater job finished.")
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
        M.debug_print("[Preview Updater] Stopping preview updater.")
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
        placement.Dynamic = M.get_xml_element_content(placementInner, "Dynamic")
        placement.FrozenPos = M.get_xml_element_content(placementInner, "FrozenPos")
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
    return placements
end

function M.parse_outfit_attachments(xmlContent)
    local attachments = {}
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
                            M.debug_print("[Delete Debug] Attachment entity type invalid:", tostring(entityType))
                            local entityType = ENTITY.GET_ENTITY_TYPE(attachmentHandle)
                            if not entityType or entityType < 0 or entityType > 3 then
                                return
                            end
                            local ptr = Memory.AllocInt()
                            local pEntity = GTA.HandleToPointer(attachmentHandle)
                            if pEntity and pEntity ~= 0 then
                                M.debug_print("[Delete Debug] Unregistering and deleting attachment network object:", tostring(attachmentHandle))
                                if pEntity.NetObject and pEntity.NetObject ~= 0 then
                                    NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                                end
                                Memory.WriteInt(ptr, attachmentHandle)
                                ENTITY.DELETE_ENTITY(ptr)
                                M.debug_print("[Delete Debug] Attachment deleted:", tostring(attachmentHandle))
                            else
                                M.debug_print("[Delete Debug] Warning: Attachment pointer invalid for handle:", tostring(attachmentHandle))
                            end
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
                    M.debug_print("[Delete Debug] Vehicle entity type invalid:", tostring(entityType))
                    local entityType = ENTITY.GET_ENTITY_TYPE(vehicleData.vehicle)
                    if entityType ~= 2 then
                        return
                    end
                    local ptr = Memory.AllocInt()
                    local pEntity = GTA.HandleToPointer(vehicleData.vehicle)
                    if pEntity and pEntity ~= 0 then
                        M.debug_print("[Delete Debug] Unregistering and deleting vehicle network object:", tostring(vehicleData.vehicle))
                        if pEntity.NetObject and pEntity.NetObject ~= 0 then
                            NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                        end
                        Memory.WriteInt(ptr, vehicleData.vehicle)
                        ENTITY.DELETE_ENTITY(ptr)
                        M.debug_print("[Delete Debug] Vehicle deleted:", tostring(vehicleData.vehicle))
                    else
                        M.debug_print("[Delete Debug] Warning: Vehicle pointer invalid for handle:", tostring(vehicleData.vehicle))
                    end
                else
                    M.debug_print("[Delete Debug] Warning: Vehicle entity does not exist for handle:", tostring(vehicleData.vehicle))
                end
            end)
        end
    end)
end

function M.deleteAllSpawnedVehicles()
    Script.QueueJob(function()
        M.debug_print("[Delete Debug] Deleting all spawned vehicles. Count:", #spawnedVehicles)
        local vehiclesToDelete = {}
        for _, vehicleData in pairs(spawnedVehicles) do
            table.insert(vehiclesToDelete, vehicleData)
        end
        for i, vehicleData in ipairs(vehiclesToDelete) do
            M.debug_print("[Delete Debug] Processing vehicle", i, "from path:", vehicleData.filePath)
            if vehicleData.attachments then
                for _, attachmentHandle in ipairs(vehicleData.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        pcall(function()
                            if ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                                M.debug_print("[Delete Debug] Deleting attachment handle:", tostring(attachmentHandle))
                                local entityType = ENTITY.GET_ENTITY_TYPE(attachmentHandle)
                                if not entityType or entityType < 0 or entityType > 3 then
                                    M.debug_print("[Delete Debug] Attachment entity type invalid:", tostring(entityType))
                                    return
                                end
                                local ptr = Memory.AllocInt()
                                local pEntity = GTA.HandleToPointer(attachmentHandle)
                                if pEntity and pEntity ~= 0 then
                                    M.debug_print("[Delete Debug] Unregistering and deleting attachment network object:", tostring(attachmentHandle))
                                    if pEntity.NetObject and pEntity.NetObject ~= 0 then
                                        NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                                    end
                                    Memory.WriteInt(ptr, attachmentHandle)
                                    ENTITY.DELETE_ENTITY(ptr)
                                    M.debug_print("[Delete Debug] Attachment deleted:", tostring(attachmentHandle))
                                else
                                    M.debug_print("[Delete Debug] Warning: Attachment pointer invalid for handle:", tostring(attachmentHandle))
                                end
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
                        M.debug_print("[Delete Debug] Deleting vehicle handle:", tostring(vehicleData.vehicle))
                        local entityType = ENTITY.GET_ENTITY_TYPE(vehicleData.vehicle)
                        if entityType ~= 2 then
                            M.debug_print("[Delete Debug] Vehicle entity type invalid:", tostring(entityType))
                            return
                        end
                        local ptr = Memory.AllocInt()
                        local pEntity = GTA.HandleToPointer(vehicleData.vehicle)
                        if pEntity and pEntity ~= 0 then
                            M.debug_print("[Delete Debug] Unregistering and deleting vehicle network object:", tostring(vehicleData.vehicle))
                            if pEntity.NetObject and pEntity.NetObject ~= 0 then
                                NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                            end
                            Memory.WriteInt(ptr, vehicleData.vehicle)
                            ENTITY.DELETE_ENTITY(ptr)
                            M.debug_print("[Delete Debug] Vehicle deleted:", tostring(vehicleData.vehicle))
                        else
                            M.debug_print("[Delete Debug] Warning: Vehicle pointer invalid for handle:", tostring(vehicleData.vehicle))
                        end
                    else
                        M.debug_print("[Delete Debug] Warning: Vehicle entity does not exist for handle:", tostring(vehicleData.vehicle))
                    end
                end)
            end
        end
        spawnedVehicles = {}
        M.debug_print("[Delete Debug] All spawned vehicles cleared.")
    end)
end

function M.deleteAllSpawnedMaps()
    Script.QueueJob(function()
        M.debug_print("[Delete Debug] Deleting all spawned maps. Count:", #spawnedMaps)
        local mapsToDelete = {}
        for _, mapData in pairs(spawnedMaps) do
            table.insert(mapsToDelete, mapData)
        end
        for i, mapData in ipairs(mapsToDelete) do
            M.debug_print("[Delete Debug] Processing map", i, "from path:", mapData.filePath)
            if mapData.entities then
                for j, entityHandle in ipairs(mapData.entities) do
                    if entityHandle and entityHandle ~= 0 then
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(entityHandle) then
                                M.debug_print("[Delete Debug] Deleting map entity handle:", tostring(entityHandle))
                                local ptr = Memory.AllocInt()
                                local pEntity = GTA.HandleToPointer(entityHandle)
                                if pEntity and pEntity ~= 0 then
                                    M.debug_print("[Delete Debug] Unregistering and deleting map entity network object:", tostring(entityHandle))
                                    if pEntity.NetObject and pEntity.NetObject ~= 0 then
                                        NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                                    end
                                    Memory.WriteInt(ptr, entityHandle)
                                    ENTITY.DELETE_ENTITY(ptr)
                                    M.debug_print("[Delete Debug] Map entity deleted:", tostring(entityHandle))
                                else
                                    M.debug_print("[Delete Debug] Warning: Map entity pointer invalid for handle:", tostring(entityHandle))
                                end
                            else
                                M.debug_print("[Delete Debug] Warning: Map entity does not exist for handle:", tostring(entityHandle))
                            end
                        end)
                    end
                end
            end
        end
        spawnedMaps = {}
        M.debug_print("[Delete Debug] All spawned maps cleared.")
    end)
end

function M.deleteAllSpawnedOutfits()
    Script.QueueJob(function()
        M.debug_print("[Delete Debug] Deleting all spawned outfits. Count:", #spawnedOutfits)
        local outfitsToDelete = {}
        for _, outfitData in pairs(spawnedOutfits) do
            table.insert(outfitsToDelete, outfitData)
        end
        for i, outfitData in ipairs(outfitsToDelete) do
            M.debug_print("[Delete Debug] Processing outfit", i, "from path:", outfitData.filePath)
            if outfitData.spawnedPed then
                pcall(function()
                    if ENTITY and ENTITY.DOES_ENTITY_EXIST(outfitData.spawnedPed) then
                        M.debug_print("[Delete Debug] Deleting spawned ped handle:", tostring(outfitData.spawnedPed))
                        local ptr = Memory.AllocInt()
                        local pEntity = GTA.HandleToPointer(outfitData.spawnedPed)
                        if pEntity and pEntity ~= 0 then
                            M.debug_print("[Delete Debug] Unregistering and deleting ped network object:", tostring(outfitData.spawnedPed))
                            if pEntity.NetObject and pEntity.NetObject ~= 0 then
                                NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                            end
                            Memory.WriteInt(ptr, outfitData.spawnedPed)
                            ENTITY.DELETE_ENTITY(ptr)
                            M.debug_print("[Delete Debug] Ped deleted:", tostring(outfitData.spawnedPed))
                        else
                            M.debug_print("[Delete Debug] Warning: Ped pointer invalid for handle:", tostring(outfitData.spawnedPed))
                        end
                    else
                        M.debug_print("[Delete Debug] Warning: Spawned ped entity does not exist for handle:", tostring(outfitData.spawnedPed))
                    end
                end)
            end
            if outfitData.attachments then
                for j, attachmentHandle in ipairs(outfitData.attachments) do
                    if attachmentHandle and attachmentHandle ~= 0 then
                        pcall(function()
                            if ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                                M.debug_print("[Delete Debug] Deleting outfit attachment handle:", tostring(attachmentHandle))
                                local ptr = Memory.AllocInt()
                                local pEntity = GTA.HandleToPointer(attachmentHandle)
                                if pEntity and pEntity ~= 0 then
                                    M.debug_print("[Delete Debug] Unregistering and deleting outfit attachment network object:", tostring(attachmentHandle))
                                    if pEntity.NetObject and pEntity.NetObject ~= 0 then
                                        NetworkObjectMgr.UnregisterNetworkObject(pEntity.NetObject, 15, true, true)
                                    end
                                    Memory.WriteInt(ptr, attachmentHandle)
                                    ENTITY.DELETE_ENTITY(ptr)
                                    M.debug_print("[Delete Debug] Outfit attachment deleted:", tostring(attachmentHandle))
                                else
                                    M.debug_print("[Delete Debug] Warning: Outfit attachment pointer invalid for handle:", tostring(attachmentHandle))
                                end
                            else
                                M.debug_print("[Delete Debug] Warning: Outfit attachment entity does not exist for handle:", tostring(attachmentHandle))
                            end
                        end)
                    end
                end
            end
        end
        spawnedOutfits = {}
        M.debug_print("[Delete Debug] All spawned outfits cleared.")
    end)
end

function M.spawnVehicleFromINI(filePath, isPreview)
    isPreview = isPreview or false
    Script.QueueJob(function()
        M.debug_print("[Spawn Debug] Attempting to spawn INI vehicle from:", filePath, "Is Preview:", tostring(isPreview))
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

        if not isPreview then
  
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
            if GTA and GTA.SpawnVehicleForPlayer then
                local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
                if ok and h and h ~= 0 then vehicleHandle = h end
            end
        end

        if isPreview and vehicleHandle and vehicleHandle ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_COLLISION(vehicleHandle, false, false) end)
        end

        if not vehicleHandle or vehicleHandle == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn main vehicle for model hash:", modelHash, "from:", filePath)
            return
        end
        M.debug_print("[Spawn Debug] Spawned vehicle handle:", tostring(vehicleHandle), "from:", filePath:match("([^\\\\/]+)$"))
        M.debug_print("[Spawn Debug] Applying vehicle properties from mainVehicleSection.")
        if spawnerSettings.randomColor then
            M.debug_print("[Spawn Debug] Applying random colors for INI vehicle:", tostring(vehicleHandle))
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
                M.debug_print("[Spawn Debug] Applied random livery", randomLivery, "for INI vehicle:", tostring(vehicleHandle))
            else
                M.debug_print("[Spawn Debug] Warning: No liveries available for INI vehicle", tostring(vehicleHandle), "to apply random livery.")
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
            M.try_call(ENTITY, "SET_ENTITY_VISIBLE", vehicleHandle, false, false)
            M.debug_print("[Spawn Debug] Vehicle set invisible due to opacity level 0.")
        end
        local isVisible = mainVehicleSection.IsVisible
        if isVisible ~= nil then
            M.try_call(ENTITY, "SET_ENTITY_VISIBLE", vehicleHandle, M.to_boolean(isVisible), false)
        end
        local mainVehicleSelfNumeration = M.safe_tonumber(mainVehicleSection.SelfNumeration, nil)
        local parentHandleMap = {}
        if mainVehicleSelfNumeration then
            parentHandleMap[mainVehicleSelfNumeration] = vehicleHandle
            M.debug_print("[Spawn Debug] Main vehicle SelfNumeration:", tostring(mainVehicleSelfNumeration), "mapped to handle:", tostring(vehicleHandle))
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
            M.debug_print("[Spawn Debug] Spawned", #createdAttachments, "attachments for vehicle:", tostring(vehicleHandle), "from:", filePath:match("([^\\\\/]+)$"))
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
            end)
        end
        if spawnerSettings.inVehicle and not isPreview then
            Script.Yield(500)
            local playerHandle = GTA.PointerToHandle(playerPed)
            if playerHandle and playerHandle > 0 then
                M.try_call(PED, "SET_PED_INTO_VEHICLE", playerHandle, vehicleHandle, -1)
                M.debug_print("[Spawn Debug] Player put into vehicle:", tostring(vehicleHandle))
            else
                M.debug_print("[Spawn Debug] Warning: Could not put player into vehicle. Player handle invalid.")
            end
        end
    end)
end

function M.spawnVehicleFromXML(filePath, isPreview)
    isPreview = isPreview or false
    Script.QueueJob(function()
        M.debug_print("[Spawn Debug] Attempting to spawn XML vehicle from:", filePath, "Is Preview:", tostring(isPreview))
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

        if not isPreview then
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
            if GTA and GTA.SpawnVehicleForPlayer then
                local ok, h = pcall(function() return GTA.SpawnVehicleForPlayer(modelHash, playerID, forwardOffset) end)
                if ok and h and h ~= 0 then vehicleHandle = h end
            end
        end

        if isPreview and vehicleHandle and vehicleHandle ~= 0 then
            pcall(function() ENTITY.SET_ENTITY_COLLISION(vehicleHandle, false, false) end)
        end

        if not vehicleHandle or vehicleHandle == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn main vehicle for model hash:", modelHash, "from:", filePath)
            return
        end
        M.debug_print("[Spawn Debug] Spawned vehicle handle:", tostring(vehicleHandle), "from:", filePath:match("([^\\\\/]+)$"))
        local initialHandleMap = {}
        local initialHandleVal = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
        if initialHandleVal then initialHandleMap[initialHandleVal] = vehicleHandle end
        if initialHandleVal then  end
        local colors = M.parse_vehicle_colors(xmlContent)
        local mods = M.parse_vehicle_mods(xmlContent)
        local neons = M.parse_vehicle_neons(xmlContent)
        local vehicleProperties = M.get_xml_element(xmlContent, "VehicleProperties")
        if spawnerSettings.randomColor then
            M.debug_print("[Spawn Debug] Applying random colors for XML vehicle:", tostring(vehicleHandle))
            M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_PRIMARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_CUSTOM_SECONDARY_COLOUR", vehicleHandle, math.random(0,255), math.random(0,255), math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_5", vehicleHandle, math.random(0,255))
            M.try_call(VEHICLE, "SET_VEHICLE_EXTRA_COLOUR_6", vehicleHandle, math.random(0,255))
        else
            if colors then
                if colors.Primary ~= nil or colors.Secondary ~= nil then
                    M.try_call(VEHICLE, "SET_VEHICLE_COLOURS", vehicleHandle, colors.Primary or 0, colors.Secondary or 0)
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
                M.debug_print("[Spawn Debug] Applied random livery", randomLivery, "for XML vehicle:", tostring(vehicleHandle))
            else
                M.debug_print("[Spawn Debug] Warning: No liveries available for XML vehicle", tostring(vehicleHandle), "to apply random livery.")
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
        end
        if spawnerSettings.vehicleGodMode then M.try_call(ENTITY, "SET_ENTITY_INVINCIBLE", vehicleHandle, true) end
        local opacityLevel = M.safe_tonumber(M.get_xml_element_content(xmlContent, "OpacityLevel"), nil)
        if opacityLevel ~= nil and opacityLevel == 0 then
            M.try_call(ENTITY, "SET_ENTITY_VISIBLE", vehicleHandle, false, false)
            M.debug_print("[Spawn Debug] Vehicle set invisible due to opacity level 0.")
        end
        local isVisible = M.get_xml_element_content(xmlContent, "IsVisible")
        if isVisible ~= nil then
            M.try_call(ENTITY, "SET_ENTITY_VISIBLE", vehicleHandle, M.to_boolean(isVisible), false)
        end
        local originalInVehicleSetting = spawnerSettings.inVehicle
        spawnerSettings.inVehicle = false
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        if (not parsedAttachments or #parsedAttachments == 0) then
            parsedAttachments = M.parse_outfit_attachments(xmlContent)
            if parsedAttachments and #parsedAttachments > 0 then
                M.debug_print("[Spawn Debug] Found outfit attachments as fallback.")
            end
        end
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            if initialHandleVal then parentHandleMap[initialHandleVal] = vehicleHandle end
            local fallbackCoords = { x = spawnX, y = spawnY, z = spawnZ }
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, fallbackCoords, spawnerSettings.disableCollision, isPreview)
            for _, h in ipairs(createdAttachments) do pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) end
            M.debug_print("[Spawn Debug] Spawned", #createdAttachments, "attachments for vehicle:", tostring(vehicleHandle), "from:", filePath:match("([^\\\\/]+)$"))
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
            end
        end
        local vehicleData = {
            vehicle = nil,
            attachments = {},
            filePath = filePath
        }
        if vehicleHandle and vehicleHandle ~= 0 and ENTITY and ENTITY.DOES_ENTITY_EXIST(vehicleHandle) then
            vehicleData.vehicle = vehicleHandle
            M.debug_print("[Spawn Debug] Main vehicle handle recorded:", tostring(vehicleHandle))
        else
            M.debug_print("[Spawn Debug] Warning: Main vehicle handle invalid or does not exist.")
        end
        if createdAttachments then
            for _, attachmentHandle in ipairs(createdAttachments) do
                if attachmentHandle and attachmentHandle ~= 0 and ENTITY and ENTITY.DOES_ENTITY_EXIST(attachmentHandle) then
                    table.insert(vehicleData.attachments, attachmentHandle)
                    M.debug_print("[Spawn Debug] Attachment handle recorded:", tostring(attachmentHandle))
                else
                    M.debug_print("[Spawn Debug] Warning: Attachment handle invalid or does not exist:", tostring(attachmentHandle))
                end
            end
        end
        if vehicleData.vehicle or #vehicleData.attachments > 0 then
            table.insert(spawnedVehicles, vehicleData)
            M.debug_print("[Spawn Debug] Vehicle data recorded. Total spawned vehicles:", #spawnedVehicles)
            local filename = M.get_filename_from_path(filePath)
            local attachmentCount = #vehicleData.attachments
            pcall(function()
                GUI.AddToast("Vehicle Spawned", "Spawned " .. filename .. " with " .. attachmentCount .. " attachment" .. (attachmentCount == 1 and "" or "s"), 5000, 0)
            end)
        else
            M.debug_print("[Spawn Debug] No vehicle or attachments spawned for XML file:", filePath)
        end
    end)
end

function M.getFirstVehicleXml()
    local files = FileMgr.FindFiles(xmlVehiclesFolder, ".xml", true)
    if not files or #files == 0 then return nil end
    return files[1]
end

function M.spawnMenyooAttackerFromXML(filePath, targetPlayerIndex)
    M.debug_print("[Spawn Debug] Attempting to spawn XML attacker from:", filePath, "for player index:", tostring(targetPlayerIndex))
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
            M.debug_print("[Spawn Debug] Warning: Target ped not found for attacker. Defaulting to local ped.")
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
            M.debug_print("[Spawn Debug] Attacker spawn coordinates:", spawnCoords.x, spawnCoords.y, spawnCoords.z)
        end)
        M.request_model_load(modelHash)
        local vehicleHandle = nil
        if GTA and GTA.SpawnVehicle then
            local ok, h = pcall(function() return GTA.SpawnVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end
        if not vehicleHandle and entities and entities.create_vehicle then
            local ok, h = pcall(function() return entities.create_vehicle(modelHash, spawnCoords, 0) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end
        if not vehicleHandle or vehicleHandle == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn main attacker vehicle for model hash:", modelHash, "from:", filePath)
            return
        end
        M.debug_print("[Spawn Debug] Spawned attacker vehicle handle:", tostring(vehicleHandle))
        local attackerModel = M.safe_tonumber(M.get_xml_element_content(xmlContent, "AttackerModelHash"), 71929310)
        M.request_model_load(attackerModel)
        local attacker = nil
        if GTA and GTA.CreatePed then
            local ok, h = pcall(function() return GTA.CreatePed(attackerModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
            if ok and h and h ~= 0 then attacker = h end
        end
        if not attacker or attacker == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn attacker ped for model:", tostring(attackerModel))
            return
        end
        M.debug_print("[Spawn Debug] Spawned attacker ped handle:", tostring(attacker))
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
            M.debug_print("[Spawn Debug] Attacker ped configured and tasked.")
        end)
        local parsedAttachments = M.parse_spooner_attachments(xmlContent)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            local parentHandleMap = {}
            local initialHandleVal = M.safe_tonumber(M.get_xml_element_content(xmlContent, "InitialHandle"), nil)
            if initialHandleVal then parentHandleMap[initialHandleVal] = vehicleHandle end
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) end
            M.debug_print("[Spawn Debug] Spawned", #createdAttachments, "attachments for attacker vehicle:", tostring(vehicleHandle))
        end
        local attachments = { attacker }
        for _, h in ipairs(createdAttachments) do
            table.insert(attachments, h)
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        if #createdAttachments > 0 then
            M.debug_print("[Spawn Debug] Attacker vehicle and attachments recorded.")
        end
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnMenyooAttackerFromINI(filePath, targetPlayerIndex)
    local originalInVehicle = spawnerSettings.inVehicle
    spawnerSettings.inVehicle = false
    Script.QueueJob(function()
        M.debug_print("[Spawn Debug] Attempting to spawn INI attacker from:", filePath)
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
            M.debug_print("[Spawn Debug] Warning: Target ped not found for attacker. Defaulting to local ped.")
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
            M.debug_print("[Spawn Debug] Attacker spawn coordinates:", spawnCoords.x, spawnCoords.y, spawnCoords.z)
        end)
        M.request_model_load(modelHash)
        local vehicleHandle = nil
        if GTA and GTA.SpawnVehicle then
            local ok, h = pcall(function() return GTA.SpawnVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end
        if not vehicleHandle and entities and entities.create_vehicle then
            local ok, h = pcall(function() return entities.create_vehicle(modelHash, spawnCoords, 0) end)
            if ok and h and h ~= 0 then vehicleHandle = h end
        end
        if not vehicleHandle or vehicleHandle == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn main attacker vehicle for model hash:", modelHash, "from:", filePath)
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        M.debug_print("[Spawn Debug] Spawned attacker vehicle handle:", tostring(vehicleHandle))
        local attackerModel = M.safe_tonumber(mainVehicleSection.AttackerModelHash, 71929310)
        M.request_model_load(attackerModel)
        local attacker = nil
        if GTA and GTA.CreatePed then
            local ok, h = pcall(function() return GTA.CreatePed(attackerModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
            if ok and h and h ~= 0 then attacker = h end
        end
        if not attacker or attacker == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn attacker ped for model:", tostring(attackerModel))
            spawnerSettings.inVehicle = originalInVehicle
            return
        end
        M.debug_print("[Spawn Debug] Spawned attacker ped handle:", tostring(attacker))
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
            M.debug_print("[Spawn Debug] Attacker ped configured and tasked.")
        end)
        local mainVehicleSelfNumeration = M.safe_tonumber(mainVehicleSection.SelfNumeration, nil)
        local parentHandleMap = {}
        if mainVehicleSelfNumeration then
            parentHandleMap[mainVehicleSelfNumeration] = vehicleHandle
            M.debug_print("[Spawn Debug] Main attacker vehicle SelfNumeration:", tostring(mainVehicleSelfNumeration), "mapped to handle:", tostring(vehicleHandle))
        else
            parentHandleMap["main_vehicle_placeholder"] = vehicleHandle
        end
        local parsedAttachments = M.parse_ini_attachments(iniData, mainVehicleSelfNumeration)
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision)
            for _, h in ipairs(createdAttachments) do pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(h, true) end) end
            M.debug_print("[Spawn Debug] Spawned", #createdAttachments, "attachments for attacker vehicle:", tostring(vehicleHandle))
        end
        local attachments = { attacker }
        for _, h in ipairs(createdAttachments) do
            table.insert(attachments, h)
        end
        table.insert(spawnedVehicles, { vehicle = vehicleHandle, attachments = attachments })
        M.debug_print("[Spawn Debug] Attacker vehicle and attachments recorded.")
        spawnerSettings.inVehicle = originalInVehicle
    end)
end

function M.spawnMapV1Networked(filePath, placements)
    M.debug_print("[Spawn Debug] Attempting to spawn XML map with Network Maps V1 from:", filePath)
    local carattach_hash = Utils.Joaat("lazer")
    M.request_model_load(carattach_hash)
    local carattach = GTA.SpawnVehicle(carattach_hash, 0.0, 0.0, 0.0, 0.0, true, true)
    if not carattach or carattach == 0 then
        M.debug_print("[Spawn Debug] Error: Failed to spawn base vehicle for Network Maps V1.")
        pcall(function() GUI.AddToast("Spawn Error", "Failed to spawn base vehicle for Network Maps V1.", 5000, 1) end)
        return nil, 0
    end
    pcall(function()
        ENTITY.FREEZE_ENTITY_POSITION(carattach, true)
        ENTITY.SET_ENTITY_COLLISION(carattach, false, false)
        ENTITY.SET_ENTITY_VISIBLE(carattach, false, false)
        ENTITY.SET_ENTITY_LOD_DIST(carattach, 100000)
        constructor_lib.make_entity_networked({handle = carattach})
        M.debug_print("[Spawn Debug] Base vehicle for Network Maps V1 spawned and networked:", tostring(carattach))
    end)
    local mapV1Entities = {}
    table.insert(mapV1Entities, carattach)
    local spawnCount = 1
    local parentHandleMap = {}
    for _, placement in ipairs(placements) do
        local model = placement.ModelHash or placement.HashName
        if not model then
            M.debug_print("[Spawn Debug] Warning: Map placement has no model hash or name. Skipping creation.")
            goto continue_creation
        end
        local entityHandle = M.create_by_type(model, placement.Type, {x = 0.0, y = 0.0, z = 0.0})
        if not entityHandle or entityHandle == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to create entity for map placement model:", tostring(model), "type:", placement.Type)
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
        M.debug_print("[Spawn Debug] Processing entity for attachment with handle:", tostring(entityHandle))
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
            M.debug_print("[Spawn Debug] Map entity networked:", tostring(entityHandle))
        end)
        if placement.IsInvincible then pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, true) end) end
        if placement.IsVisible ~= nil then pcall(function() ENTITY.SET_ENTITY_VISIBLE(entityHandle, placement.IsVisible, false) end) end
        if placement.OpacityLevel ~= nil then
            local opacity = M.safe_tonumber(placement.OpacityLevel, 255)
            if opacity == 0 then
                pcall(function() ENTITY.SET_ENTITY_VISIBLE(entityHandle, false, false) end)
                M.debug_print("[Spawn Debug] Map entity set invisible due to opacity level 0.")
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
        M.debug_print("[Spawn Debug] Attempting to spawn XML map from:", filePath)
        if not FileMgr.DoesFileExist(filePath) then
            M.debug_print("[Spawn Debug] Error: XML map file does not exist:", filePath)
            return
        end
        local xmlContent = FileMgr.ReadFileContent(filePath)
        if not xmlContent or xmlContent == "" then
            M.debug_print("[Spawn Debug] Error: Failed to read XML map file or content is empty:", filePath)
            return
        end
        local placements = M.parse_map_placements(xmlContent)
        if not placements or #placements == 0 then
            M.debug_print("[Spawn Debug] Warning: No placements found in XML map file:", filePath)
            return
        end
        if spawnerSettings.deleteOldMap then
            M.deleteAllSpawnedMaps()
        end
        local createdEntities = {}
        local spawnCount = 0
        local refCoords = nil
        local refCoordsElement = M.get_xml_element(xmlContent, "ReferenceCoords")
        if refCoordsElement then
            refCoords = {}
            refCoords.x = M.safe_tonumber(M.get_xml_element_content(refCoordsElement, "X"), 0.0)
            refCoords.y = M.safe_tonumber(M.get_xml_element_content(refCoordsElement, "Y"), 0.0)
            refCoords.z = M.safe_tonumber(M.get_xml_element_content(refCoordsElement, "Z"), 0.0)
        end
        if spawnerSettings.networkMapsV1Enabled then
            createdEntities, spawnCount = M.spawnMapV1Networked(filePath, placements)
        else
            for _, placement in ipairs(placements) do
                M.debug_print("[Spawn Debug] Processing map placement: ModelHash:", placement.ModelHash, "HashName:", placement.HashName, "Type:", placement.Type)
                local model = placement.ModelHash or placement.HashName
                if not model then
                    M.debug_print("[Spawn Debug] Warning: Map placement has no model hash or name. Skipping.")
                    goto continue_v2
                end
                local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
                if placement.PositionRotation then
                    spawnCoords.x = placement.PositionRotation.X or 0.0
                    spawnCoords.y = placement.PositionRotation.Y or 0.0
                    spawnCoords.z = placement.PositionRotation.Z or 0.0
                end
                local entityHandle = M.create_by_type(model, placement.Type, spawnCoords)
                if not entityHandle or entityHandle == 0 then
                    M.debug_print("[Spawn Debug] Error: Failed to create entity for map placement model:", tostring(model), "type:", placement.Type)
                    goto continue_v2
                end
                M.debug_print("[Spawn Debug] Successfully created entity for map placement with handle:", tostring(entityHandle))
                pcall(function()
                    ENTITY.SET_ENTITY_COORDS(entityHandle, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, true)
                    M.debug_print("[Spawn Debug] Set entity coords for map placement:", spawnCoords.x, spawnCoords.y, spawnCoords.z)
                end)
                table.insert(createdEntities, entityHandle)
                spawnCount = spawnCount + 1
                if spawnerSettings.networkMapsV2Enabled then
                    pcall(function()
                        constructor_lib.make_entity_networked({handle = entityHandle})
                        M.debug_print("[Spawn Debug] Map entity networked:", tostring(entityHandle))
                    end)
                end
                if placement.IsInvincible then
                    pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(entityHandle, true) end)
                    M.debug_print("[Spawn Debug] Map entity set invincible:", tostring(entityHandle))
                end
                if placement.IsVisible ~= nil then
                    pcall(function() ENTITY.SET_ENTITY_VISIBLE(entityHandle, placement.IsVisible, false) end)
                    M.debug_print("[Spawn Debug] Map entity set visible:", tostring(placement.IsVisible))
                end
                if placement.OpacityLevel ~= nil then
                    local opacity = M.safe_tonumber(placement.OpacityLevel, 255)
                    if opacity == 0 then
                        pcall(function() ENTITY.SET_ENTITY_VISIBLE(entityHandle, false, false) end)
                        M.debug_print("[Spawn Debug] Map entity set invisible due to opacity level 0.")
                    end
                end
                if placement.HasGravity ~= nil then
                    pcall(function() ENTITY.SET_ENTITY_HAS_GRAVITY(entityHandle, placement.HasGravity) end)
                    M.debug_print("[Spawn Debug] Map entity set gravity:", tostring(placement.HasGravity))
                end
                if placement.Health ~= nil then
                    local health = M.safe_tonumber(placement.Health, 1000)
                    pcall(function() ENTITY.SET_ENTITY_HEALTH(entityHandle, health, 0) end)
                    M.debug_print("[Spawn Debug] Map entity set health:", tostring(health))
                end
                if placement.MaxHealth ~= nil then
                    local maxHealth = M.safe_tonumber(placement.MaxHealth, 1000)
                    pcall(function() ENTITY.SET_ENTITY_MAX_HEALTH(entityHandle, maxHealth) end)
                    M.debug_print("[Spawn Debug] Map entity set max health:", tostring(maxHealth))
                end
                if placement.IsBulletProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, true, false, false, false, false, false, false, false) end)
                    M.debug_print("[Spawn Debug] Map entity set bulletproof.")
                end
                if placement.IsCollisionProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, true, false, false, false, false, false, false) end)
                    M.debug_print("[Spawn Debug] Map entity set collision proof.")
                end
                if placement.IsExplosionProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, true, false, false, false, false, false) end)
                    M.debug_print("[Spawn Debug] Map entity set explosion proof.")
                end
                if placement.IsFireProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, true, false, false, false, false) end)
                    M.debug_print("[Spawn Debug] Map entity set fire proof.")
                end
                if placement.IsMeleeProof then
                    pcall(function() ENTITY.SET_ENTITY_PROOFS(entityHandle, false, false, false, false, true, false, false, false) end)
                    M.debug_print("[Spawn Debug] Map entity set melee proof.")
                end
                if placement.PositionRotation then
                    local rotX = placement.PositionRotation.Pitch or 0.0
                    local rotY = placement.PositionRotation.Roll or 0.0
                    local rotZ = placement.PositionRotation.Yaw or 0.0
                    pcall(function() ENTITY.SET_ENTITY_ROTATION(entityHandle, rotX, rotY, rotZ, 2) end)
                    M.debug_print("[Spawn Debug] Map entity set rotation:", rotX, rotY, rotZ)
                    if placement.FrozenPos then
                        pcall(function() ENTITY.FREEZE_ENTITY_POSITION(entityHandle, true) end)
                        M.debug_print("[Spawn Debug] Map entity set frozen position.")
                    end
                end
                if placement.ObjectProperties then
                    for propName, propValue in pairs(placement.ObjectProperties) do
                        if propName == "TextureVariation" then
                            local texture = M.safe_tonumber(propValue, 0)
                            pcall(function() OBJECT.SET_OBJECT_TEXTURE_VARIATION(entityHandle, texture) end)
                            M.debug_print("[Spawn Debug] Map entity set texture variation:", tostring(texture))
                        end
                    end
                end
                ::continue_v2::
            end
        end
        if refCoords then
            local playerPed = GTA.GetLocalPed()
            if playerPed then
                pcall(function()
                    local playerHandle = GTA.PointerToHandle(playerPed)
                    if playerHandle and playerHandle > 0 then
                        ENTITY.SET_ENTITY_COORDS(playerHandle, refCoords.x, refCoords.y, refCoords.z, false, false, false, true)
                        M.debug_print("[Spawn Debug] Player teleported to map reference coordinates:", refCoords.x, refCoords.y, refCoords.z)
                    end
                end)
            end
        end
        if spawnCount > 0 then
            local mapData = {
                entities = createdEntities,
                filePath = filePath
            }
            table.insert(spawnedMaps, mapData)
            M.debug_print("[Spawn Debug] Map spawned successfully. Total objects:", spawnCount)
            local filename = M.get_filename_from_path(filePath)
            pcall(function()
                GUI.AddToast("Map Spawned", "Spawned " .. filename .. " with " .. spawnCount .. " object" .. (spawnCount == 1 and "" or "s"), 5000, 0)
            end)
        else
            M.debug_print("[Spawn Debug] No objects spawned for map:", filePath)
        end
        if spawnerSettings.networkMapsV1Enabled and spawnerSettings.spawnIn000Vehicle then
            local playerPed = PLAYER.PLAYER_PED_ID()
            local baseVehicleHandle = createdEntities[1]
            if playerPed and baseVehicleHandle and ENTITY.DOES_ENTITY_EXIST(baseVehicleHandle) then
                Script.Yield(100)
                PED.SET_PED_INTO_VEHICLE(playerPed, baseVehicleHandle, -1)
                M.debug_print("[Spawn Debug] Player put into 0,0,0 vehicle for debug after refCoords teleport.")
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
            M.debug_print("[Spawn Debug] All map entities confirmed to exist.")
        else
            M.debug_print("[Spawn Debug] Warning: Timeout waiting for all map entities to be created.")
        end
    end)
end

function M.spawnOutfitFromXML(filePath, isPreview)
    isPreview = isPreview or false
    Script.QueueJob(function()
        M.debug_print("[Spawn Debug] Attempting to spawn XML outfit from:", filePath, "Is Preview:", tostring(isPreview))
        if not isPreview and currentPreviewFile and currentPreviewFile.path == filePath and #previewEntities > 0 then
            M.debug_print("[Spawn Debug] Finalizing preview for outfit:", filePath)
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
                        M.debug_print("[Spawn Debug] Player changed to finalized preview ped:", tostring(spawnedPed))
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
        M.request_model_load(modelHash)
        local spawnedPed = M.create_by_type(modelHash, 1, spawnCoords)
        if not spawnedPed or spawnedPed == 0 then
            M.debug_print("[Spawn Debug] create_by_type failed for outfit ped. Trying PED.CREATE_PED.")
            local ok, h = pcall(function() return PED.CREATE_PED(4, modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, false, false) end)
            if ok and h and h ~= 0 then spawnedPed = h end
        end
        if not spawnedPed or spawnedPed == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn main ped for outfit model hash:", modelHash, "from:", filePath)
            return
        end
        M.debug_print("[Spawn Debug] Spawned outfit ped handle:", tostring(spawnedPed))
        if spawnedPed ~= 0 then
            if outfitData.PedProperties then
                M.apply_ped_properties(spawnedPed, outfitData.PedProperties)
                M.debug_print("[Spawn Debug] Applied ped properties for outfit ped:", tostring(spawnedPed))
            end
        else
            M.debug_print("[Spawn Debug] Error: spawnedPed is invalid, skipping property application and attachments.")
            return
        end
        local parentHandleMap = {}
        local xmlInitialHandle = M.safe_tonumber(outfitData.InitialHandle, nil)
        if xmlInitialHandle then parentHandleMap[xmlInitialHandle] = spawnedPed end
        if not parsedAttachments or #parsedAttachments == 0 then
            M.debug_print("[Spawn Debug] No attachments found for outfit.")
        else
            M.debug_print("[Spawn Debug] Found", #parsedAttachments, "attachments for outfit.")
            for i, a in ipairs(parsedAttachments) do
                M.debug_print("[Spawn Debug] Attachment", i, ": ModelHash:", a.ModelHash, "Type:", a.Type)
            end
        end
        local createdAttachments = {}
        if parsedAttachments and #parsedAttachments > 0 then
            createdAttachments = M.spawn_attachments(parsedAttachments, parentHandleMap, spawnCoords, spawnerSettings.disableCollision, isPreview)
            M.debug_print("[Spawn Debug] Spawned", #createdAttachments, "attachments for outfit.")
            for _, ah in ipairs(createdAttachments) do if ah and ah ~= 0 then pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(ah, true) end) M.debug_print("[Spawn Debug] Attachment", tostring(ah), "set invincible.") end end
        end
        if (not createdAttachments or #createdAttachments == 0) and parsedAttachments and #parsedAttachments > 0 then
            M.debug_print("[Spawn Debug] No attachments created on spawned ped, attempting to spawn on player as fallback.")
            local playerCoords = ENTITY.GET_ENTITY_COORDS(playerHandle, false)
            local fallbackForPlayer = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z }
            local playerParentMap = {}
            if xmlInitialHandle then playerParentMap[xmlInitialHandle] = playerHandle end
            local createdOnPlayer = M.spawn_attachments(parsedAttachments, playerParentMap, fallbackForPlayer, spawnerSettings.disableCollision, isPreview)
            M.debug_print("[Spawn Debug] Spawned", #createdOnPlayer, "attachments on player as fallback.")
            for _, ah in ipairs(createdOnPlayer) do if ah and ah ~= 0 then pcall(function() ENTITY.SET_ENTITY_INVINCIBLE(ah, true) end) M.debug_print("[Spawn Debug] Fallback attachment", tostring(ah), "set invincible.") end end
            createdAttachments = createdOnPlayer
        end
        pcall(function()
            PED.SET_PED_KEEP_TASK(spawnedPed, true)
            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(spawnedPed, true)
            ENTITY.SET_ENTITY_INVINCIBLE(spawnedPed, true)
            M.debug_print("[Spawn Debug] Outfit ped configured (keep task, block events, invincible).")
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
            if all_attachments_attached(createdAttachments, spawnedPed) then
                attached_ok = true
                break
            end
            if i == 5 then
                for _, ah in ipairs(createdAttachments) do
                    if ah and ah ~= 0 and ENTITY.DOES_ENTITY_EXIST(ah) then
                        local attachedTo = nil
                        pcall(function() attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(ah) end)
                        if attachedTo ~= spawnedPed then
                            M.debug_print("[Spawn Debug] Re-attaching attachment", tostring(ah), "to spawned ped", tostring(spawnedPed))
                            pcall(function()
                                local originalAttData = nil
                                for _, originalAtt in ipairs(parsedAttachments) do
                                    if originalAtt.created == ah then
                                        originalAttData = originalAtt
                                        break
                                    end
                                end
                                ENTITY.ATTACH_ENTITY_TO_ENTITY(ah, spawnedPed, -1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, spawnerSettings.disableCollision, false, 0, true)
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
            table.insert(previewEntities, spawnedPed)
            for _, attachment in ipairs(createdAttachments) do
            table.insert(previewEntities, attachment)
        end
        -- All preview logic is now handled by M.startPreviewUpdater
        return
    end
    pcall(function()
            if PLAYER and PLAYER.PLAYER_ID and PLAYER.CHANGE_PLAYER_PED then
                local pid = PLAYER.PLAYER_ID()
                if pid then
                    Script.Yield(2000)
                    PLAYER.CHANGE_PLAYER_PED(pid, spawnedPed, true, true)
                    M.debug_print("[Spawn Debug] Player changed to spawned ped:", tostring(spawnedPed))
                    Script.Yield(250)
                end
            end
        end)
        local outfitRecord = { attachments = createdAttachments, spawnedPed = spawnedPed, filePath = filePath }
        table.insert(spawnedOutfits, outfitRecord)
        M.debug_print("[Spawn Debug] Outfit spawned and recorded. Ped handle:", tostring(spawnedPed), "Attachments count:", #createdAttachments)
    end)
end

function M.deleteAllSpawnedProps()
    Script.QueueJob(function()
        M.debug_print("[Delete Debug] Deleting all spawned props. Count:", #spawnedProps)
        for i, propHandle in ipairs(spawnedProps) do
            if propHandle and ENTITY.DOES_ENTITY_EXIST(propHandle) then
                pcall(function()
                    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(propHandle, false, true)
                    ENTITY.DELETE_ENTITY(propHandle)
                    M.debug_print("[Delete Debug] Deleted prop handle:", tostring(propHandle))
                end)
            end
        end
        spawnedProps = {}
        M.debug_print("[Delete Debug] All spawned props cleared.")
        pcall(function() GUI.AddToast("Props Deleted", "All spawned props deleted.", 3000, 0) end)
    end)
end

return M
