-- ============================================================================
-- INI Parser Module
-- Parses Menyoo INI vehicle files into normalized data structures
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
-- INI file parser (reads file content, returns section table)
-- ============================================================================
function P.parse_ini_file(filePath)
    local iniContent = FileMgr.ReadFileContent(filePath)
    if not iniContent then return nil end
    
    -- Strip BOM (Byte Order Mark) if present
    if iniContent:sub(1, 3) == "\239\187\191" then
        iniContent = iniContent:sub(4)
    end
    
    local data = {}
    local currentSection = nil
    for line in iniContent:gmatch("[^\r\n]+") do
        line = trim(line)
        if line:match("^%[.+%]$") then
            currentSection = line:match("^%[(.+)%]$")
            data[currentSection] = data[currentSection] or {}
        elseif line:match("^[^;=]+=[^;]*$") and currentSection then
            local key, value = line:match("^([^;=]+)=([^;]*)$")
            if key and value then
                local trimmedKey = trim(key)
                local trimmedValue = trim(value):match("^(.-)%s*;.*$") or trim(value)
                data[currentSection][trimmedKey] = trimmedValue
            end
        end
    end
    return data
end

-- ============================================================================
-- INI attachment parser (parses attachment sections from INI data)
-- ============================================================================
function P.parse_ini_attachments(iniData, mainVehicleSelfNumeration)
    local attachments = {}
    for sectionName, attachmentSection in pairs(iniData) do
        if safe_tonumber(sectionName) ~= nil or sectionName:match("^Attached Object %d+$") or sectionName:match("^Vehicle%d+$") or sectionName:match("^Object%d+$") then
            if sectionName == "Vehicle0" or sectionName == "Object0" then goto continue end
            local att = {}
            att.ModelHash = safe_tonumber(attachmentSection.Hash or attachmentSection.model or attachmentSection.Model, nil)
            att.HashName = attachmentSection["model name"] or attachmentSection["Model Name"] or attachmentSection.model or attachmentSection.Model or attachmentSection.Hash
            att.Type = "3"
            att.InitialHandle = safe_tonumber(attachmentSection.SelfNumeration, nil)
            att.PositionRotation = {
                X = safe_tonumber(attachmentSection.OffsetX or attachmentSection["x offset"] or attachmentSection.X or attachmentSection.x, 0.0),
                Y = safe_tonumber(attachmentSection.OffsetY or attachmentSection["y offset"] or attachmentSection.Y or attachmentSection.y, 0.0),
                Z = safe_tonumber(attachmentSection.OffsetZ or attachmentSection["z offset"] or attachmentSection.Z or attachmentSection.z, 0.0),
                Pitch = safe_tonumber(attachmentSection.Pitch or attachmentSection.pitch or attachmentSection.RotX or attachmentSection.rotX, 0.0),
                Roll = safe_tonumber(attachmentSection.Roll or attachmentSection.roll or attachmentSection.RotY or attachmentSection.rotY, 0.0),
                Yaw = safe_tonumber(attachmentSection.Yaw or attachmentSection.yaw or attachmentSection.RotZ or attachmentSection.rotZ, 0.0)
            }
            local attachedToWhat = attachmentSection.AttachedToWhat or attachmentSection.AttachedToWhat
            local attachNumeration = safe_tonumber(attachmentSection.AttachNumeration, nil)
            att.Attachment = {
                isAttached = true,
                AttachedTo = "main_vehicle_placeholder",
                BoneIndex = safe_tonumber(attachmentSection.Bone or attachmentSection.bone, -1),
                X = att.PositionRotation.X,
                Y = att.PositionRotation.Y,
                Z = att.PositionRotation.Z,
                Pitch = att.PositionRotation.Pitch,
                Roll = att.PositionRotation.Roll,
                Yaw = att.PositionRotation.Yaw
            }
            if attachedToWhat == "Vehicle" and mainVehicleSelfNumeration then
                att.Attachment.AttachedTo = mainVehicleSelfNumeration
                debug_print("[Parse INI Debug] Attachment", sectionName, "attached to main vehicle (SelfNumeration:", tostring(mainVehicleSelfNumeration), ")")
            elseif attachNumeration then
                att.Attachment.AttachedTo = attachNumeration
                debug_print("[Parse INI Debug] Attachment", sectionName, "attached to object with AttachNumeration:", tostring(attachNumeration))
            else
                debug_print("[Parse INI Debug] Warning: Attachment", sectionName, "has no clear parent. Defaulting to main vehicle placeholder.")
                att.Attachment.AttachedTo = "main_vehicle_placeholder"
            end
            att.IsCollisionProof = to_boolean(attachmentSection.collision or attachmentSection.Collision)
            att.FrozenPos = to_boolean(attachmentSection.froozen or attachmentSection.frozen or attachmentSection.Froozen or attachmentSection.Frozen)
            
            -- Parse vehicle-specific properties if this is a vehicle attachment
            if sectionName:match("^Vehicle%d+$") then
                att.Type = "2" -- Vehicle type
                
                -- Parse vehicle mods
                local modsSection = iniData[sectionName .. "Mods"]
                if modsSection then
                    att.VehicleMods = {}
                    for key, value in pairs(modsSection) do
                        if key:match("^M%d+$") then
                            local modId = safe_tonumber(key:sub(2), nil)
                            local modValue = safe_tonumber(value, -1)
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
                            local toggleId = safe_tonumber(key:sub(2), nil)
                            if toggleId then
                                att.VehicleToggles[toggleId] = to_boolean(value)
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
                            local extraId = safe_tonumber(key:sub(2), nil)
                            if extraId then
                                att.VehicleExtras[extraId] = to_boolean(value)
                            end
                        end
                    end
                end
                
                -- Parse vehicle colors
                local colorsSection = iniData[sectionName .. "VehicleColors"]
                if colorsSection then
                    att.VehicleColors = {
                        Primary = safe_tonumber(colorsSection.Primary, nil),
                        Secondary = safe_tonumber(colorsSection.Secondary, nil)
                    }
                end
                
                -- Parse extra colors (pearlescent, wheel)
                local extraColorsSection = iniData[sectionName .. "ExtraColors"]
                if extraColorsSection then
                    att.ExtraColors = {
                        Pearl = safe_tonumber(extraColorsSection.Pearl, nil),
                        Wheel = safe_tonumber(extraColorsSection.Wheel, nil)
                    }
                end
                
                -- Parse custom primary color
                local customPrimarySection = iniData[sectionName .. "CustomPrimaryColor"]
                if customPrimarySection then
                    att.CustomPrimaryColor = {
                        R = safe_tonumber(customPrimarySection.R, 0),
                        G = safe_tonumber(customPrimarySection.G, 0),
                        B = safe_tonumber(customPrimarySection.B, 0)
                    }
                end
                
                -- Parse custom secondary color
                local customSecondarySection = iniData[sectionName .. "CustomSecondaryColor"]
                if customSecondarySection then
                    att.CustomSecondaryColor = {
                        R = safe_tonumber(customSecondarySection.R, 0),
                        G = safe_tonumber(customSecondarySection.G, 0),
                        B = safe_tonumber(customSecondarySection.B, 0)
                    }
                end
                
                -- Parse neon settings
                local neonSection = iniData[sectionName .. "Neon"]
                if neonSection then
                    att.Neons = {
                        Enabled0 = to_boolean(neonSection.Enabled0),
                        Enabled1 = to_boolean(neonSection.Enabled1),
                        Enabled2 = to_boolean(neonSection.Enabled2),
                        Enabled3 = to_boolean(neonSection.Enabled3)
                    }
                end
                
                -- Parse neon color
                local neonColorSection = iniData[sectionName .. "NeonColor"]
                if neonColorSection then
                    att.NeonColor = {
                        R = safe_tonumber(neonColorSection.R, 255),
                        G = safe_tonumber(neonColorSection.G, 255),
                        B = safe_tonumber(neonColorSection.B, 255)
                    }
                end
                
                -- Parse tire smoke color
                local tireSmokeSection = iniData[sectionName .. "TireSmoke"]
                if tireSmokeSection then
                    att.TireSmoke = {
                        R = safe_tonumber(tireSmokeSection.R, 255),
                        G = safe_tonumber(tireSmokeSection.G, 255),
                        B = safe_tonumber(tireSmokeSection.B, 255)
                    }
                end
                
                -- Parse wheel type
                local wheelTypeSection = iniData[sectionName .. "WheelType"]
                if wheelTypeSection then
                    att.WheelType = safe_tonumber(wheelTypeSection.Index, nil)
                end
                
                -- Parse numberplate
                local numberplateSection = iniData[sectionName .. "Numberplate"]
                if numberplateSection then
                    att.Numberplate = {
                        Text = numberplateSection.Text,
                        Index = safe_tonumber(numberplateSection.Index, 0)
                    }
                end
                
                -- Parse window tint
                local windowTintSection = iniData[sectionName .. "WindowTint"]
                if windowTintSection then
                    att.WindowTint = safe_tonumber(windowTintSection.Index, nil)
                end
                
                -- Parse paint fade
                local paintFadeSection = iniData[sectionName .. "PaintFade"]
                if paintFadeSection then
                    att.PaintFade = safe_tonumber(paintFadeSection.PaintFade, nil)
                end
                
                -- Parse custom primary/secondary flags
                local isCustomPrimarySection = iniData[sectionName .. "IsCustomPrimary"]
                if isCustomPrimarySection then
                    att.IsCustomPrimary = to_boolean(isCustomPrimarySection.bool)
                end
                
                local isCustomSecondarySection = iniData[sectionName .. "IsCustomSecondary"]
                if isCustomSecondarySection then
                    att.IsCustomSecondary = to_boolean(isCustomSecondarySection.bool)
                end
            end
            
            table.insert(attachments, att)
        end
        ::continue::
    end
    return attachments
end

-- ============================================================================
-- Context preview metadata for INI files
-- ============================================================================
function P.parseMetadata(content, filePath)
    local metadata = {}
    metadata.itemType = "vehicle"
    
    local vehicleSection = content:match("%[Vehicle%](.-)%[") or content:match("%[Vehicle0%](.-)%[") or content:match("%[Vehicle%](.*)$") or content:match("%[Vehicle0%](.*)$")
    if vehicleSection then
        local hash = vehicleSection:match("Hash%s*=%s*([^\r\n]+)")
                  or vehicleSection:match("ModelHash%s*=%s*([^\r\n]+)")
                  or vehicleSection:match("Model%s*=%s*([^\r\n]+)")
        if hash then
            hash = hash:match("^%s*(.-)%s*$")
            metadata.modelHash = hash
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
    metadata.vehicleCount = 1 + extraVehicles
    metadata.pedCount = 0
    
    return metadata
end

return P
