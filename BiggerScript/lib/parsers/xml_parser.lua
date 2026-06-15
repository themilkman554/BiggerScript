-- ============================================================================
-- XML Parser Module
-- Parses Menyoo/Spooner XML files into normalized data structures
-- ============================================================================
local P = {}

-- Shared utility references (set via init)
local safe_tonumber, trim, split_str, to_boolean, debug_print
local get_xml_element_content, get_xml_element

-- ============================================================================
-- Internal XML helpers
-- ============================================================================

local function parse_attributes(attrStr)
    local attrs = {}
    if not attrStr then return attrs end
    for key, value in attrStr:gmatch('(%w+)="([^"]*)"') do
        attrs[key] = value
    end
    return attrs
end

local function parse_self_closing_tag(xml, tagName)
    if not xml or not tagName then return nil end
    return xml:match("<" .. tagName .. "(.-)/>" )
end

local function parse_vector_from_tag(xml, tagName)
    local snippet = parse_self_closing_tag(xml, tagName)
    if not snippet then return nil end
    local attrs = parse_attributes(snippet)
    return {
        x = safe_tonumber(attrs.X or attrs.x, 0.0),
        y = safe_tonumber(attrs.Y or attrs.y, 0.0),
        z = safe_tonumber(attrs.Z or attrs.z, 0.0)
    }
end

-- ============================================================================
-- Init (receive shared utilities from spawning.lua)
-- ============================================================================
function P.init(ctx)
    safe_tonumber = ctx.safe_tonumber
    trim = ctx.trim
    split_str = ctx.split_str
    to_boolean = ctx.to_boolean
    debug_print = ctx.debug_print
    get_xml_element_content = ctx.get_xml_element_content
    get_xml_element = ctx.get_xml_element
end

-- ============================================================================
-- Vehicle color parsing
-- ============================================================================
function P.parse_vehicle_colors(xml)
    local colors = {}
    local vehicleProperties = get_xml_element(xml, "VehicleProperties")
    if not vehicleProperties then return colors end
    local colorsSection = get_xml_element(vehicleProperties, "Colours")
    if not colorsSection then return colors end
    colors.Primary = safe_tonumber(get_xml_element_content(colorsSection, "Primary"), nil)
    colors.Secondary = safe_tonumber(get_xml_element_content(colorsSection, "Secondary"), nil)
    colors.Pearl = safe_tonumber(get_xml_element_content(colorsSection, "Pearl"), nil)
    colors.Rim = safe_tonumber(get_xml_element_content(colorsSection, "Rim"), nil)
    colors.tyreSmoke_R = safe_tonumber(get_xml_element_content(colorsSection, "tyreSmoke_R"), nil)
    colors.tyreSmoke_G = safe_tonumber(get_xml_element_content(colorsSection, "tyreSmoke_G"), nil)
    colors.tyreSmoke_B = safe_tonumber(get_xml_element_content(colorsSection, "tyreSmoke_B"), nil)
    colors.LrInterior = safe_tonumber(get_xml_element_content(colorsSection, "LrInterior"), nil)
    colors.LrDashboard = safe_tonumber(get_xml_element_content(colorsSection, "LrDashboard"), nil)

    -- Custom Colors
    colors.IsPrimaryColourCustom = to_boolean(get_xml_element_content(colorsSection, "IsPrimaryColourCustom"))
    colors.Cust1_R = safe_tonumber(get_xml_element_content(colorsSection, "Cust1_R"), 0)
    colors.Cust1_G = safe_tonumber(get_xml_element_content(colorsSection, "Cust1_G"), 0)
    colors.Cust1_B = safe_tonumber(get_xml_element_content(colorsSection, "Cust1_B"), 0)

    colors.IsSecondaryColourCustom = to_boolean(get_xml_element_content(colorsSection, "IsSecondaryColourCustom"))
    colors.Cust2_R = safe_tonumber(get_xml_element_content(colorsSection, "Cust2_R"), 0)
    colors.Cust2_G = safe_tonumber(get_xml_element_content(colorsSection, "Cust2_G"), 0)
    colors.Cust2_B = safe_tonumber(get_xml_element_content(colorsSection, "Cust2_B"), 0)

    return colors
end

-- ============================================================================
-- Vehicle mod parsing
-- ============================================================================
function P.parse_vehicle_mods(xml)
    local mods = {}
    local vehicleProperties = get_xml_element(xml, "VehicleProperties")
    if not vehicleProperties then return mods end
    local modsSection = get_xml_element(vehicleProperties, "Mods")
    if not modsSection then return mods end
    for modId, modValue in modsSection:gmatch("<_([0-9]+)>([^<]+)</%d+>") do
        local id = safe_tonumber(modId, nil)
        if id then
            local parts = split_str(modValue, ",")
            local m = safe_tonumber(parts[1], -1)
            local v = safe_tonumber(parts[2], 0)
            mods[id] = { mod = m, var = v }
        end
    end
    return mods
end

-- ============================================================================
-- Vehicle neon parsing
-- ============================================================================
function P.parse_vehicle_neons(xml)
    local neons = nil
    local vehicleProperties = get_xml_element(xml, "VehicleProperties")
    if vehicleProperties then
        local neonsSection = get_xml_element(vehicleProperties, "Neons")
        if neonsSection then
            neons = {}
            neons.Left = to_boolean(get_xml_element_content(neonsSection, "Left"))
            neons.Right = to_boolean(get_xml_element_content(neonsSection, "Right"))
            neons.Front = to_boolean(get_xml_element_content(neonsSection, "Front"))
            neons.Back = to_boolean(get_xml_element_content(neonsSection, "Back"))
            neons.R = safe_tonumber(get_xml_element_content(neonsSection, "R"), nil)
            neons.G = safe_tonumber(get_xml_element_content(neonsSection, "G"), nil)
            neons.B = safe_tonumber(get_xml_element_content(neonsSection, "B"), nil)
        end
    end
    return neons
end

-- ============================================================================
-- Outfit ped data parsing
-- ============================================================================
function P.parse_outfit_ped_data(xmlContent)
    local outfitData = {}
    outfitData.ModelHash = get_xml_element_content(xmlContent, "ModelHash")
    outfitData.Type = get_xml_element_content(xmlContent, "Type")
    outfitData.InitialHandle = get_xml_element_content(xmlContent, "InitialHandle")
    local pedPropsElement = get_xml_element(xmlContent, "PedProperties")
    if pedPropsElement then
        outfitData.PedProperties = {}
        outfitData.PedProperties.IsStill = to_boolean(get_xml_element_content(pedPropsElement, "IsStill"))
        outfitData.PedProperties.CanRagdoll = to_boolean(get_xml_element_content(pedPropsElement, "CanRagdoll"))
        outfitData.PedProperties.HasShortHeight = to_boolean(get_xml_element_content(pedPropsElement, "HasShortHeight"))
        outfitData.PedProperties.Armour = safe_tonumber(get_xml_element_content(pedPropsElement, "Armour"), 0)
        outfitData.PedProperties.CurrentWeapon = get_xml_element_content(pedPropsElement, "CurrentWeapon")
        outfitData.PedProperties.RelationshipGroup = get_xml_element_content(pedPropsElement, "RelationshipGroup")
        local pedPropsSubElement = get_xml_element(pedPropsElement, "PedProps")
        if pedPropsSubElement then
            outfitData.PedProperties.PedProps = {}
            for propId, propData in pedPropsSubElement:gmatch("<_(%d+)>([^<]+)</_") do
                local parts = {}
                for part in propData:gmatch("([^,]+)") do table.insert(parts, part) end
                outfitData.PedProperties.PedProps["_" .. propId] = {
                    prop_id = safe_tonumber(parts[1], -1),
                    texture_id = safe_tonumber(parts[2], 0)
                }
            end
        end
        local pedCompsElement = get_xml_element(pedPropsElement, "PedComps")
        if pedCompsElement then
            outfitData.PedProperties.PedComps = {}
            for compId, compData in pedCompsElement:gmatch("<_(%d+)>([^<]+)</_") do
                local parts = {}
                for part in compData:gmatch("([^,]+)") do table.insert(parts, part) end
                outfitData.PedProperties.PedComps["_" .. compId] = {
                    comp_id = safe_tonumber(parts[1], 0),
                    texture_id = safe_tonumber(parts[2], 0)
                }
            end
        end
    end
    return outfitData
end

-- ============================================================================
-- Task sequence parsing
-- ============================================================================
function P.parse_task_sequence(taskSequenceXml, autoStartFlag)
    if not taskSequenceXml then return nil end
    local sequence = { tasks = {}, autoStart = autoStartFlag }
    for taskInner in taskSequenceXml:gmatch("<Task>(.-)</Task>") do
        local task = {}
        task.Type = safe_tonumber(get_xml_element_content(taskInner, "Type"), nil)
        if task.Type then
            task.Duration = safe_tonumber(get_xml_element_content(taskInner, "Duration"), 0)
            task.KeepTaskRunningAfterTime = safe_tonumber(get_xml_element_content(taskInner, "KeepTaskRunningAfterTime"), nil)
            task.IsLoopedTask = to_boolean(get_xml_element_content(taskInner, "IsLoopedTask"))
            task.Delay = safe_tonumber(get_xml_element_content(taskInner, "Delay"), 0)
            task.AssetName = get_xml_element_content(taskInner, "AssetName")
            task.EffectName = get_xml_element_content(taskInner, "EffectName")
            task.Scale = safe_tonumber(get_xml_element_content(taskInner, "Scale"), 1.0)
            local colourSnippet = parse_self_closing_tag(taskInner, "Colour")
            if colourSnippet then
                local colourAttrs = parse_attributes(colourSnippet)
                task.Colour = {
                    r = safe_tonumber(colourAttrs.R or colourAttrs.r, 255),
                    g = safe_tonumber(colourAttrs.G or colourAttrs.g, 255),
                    b = safe_tonumber(colourAttrs.B or colourAttrs.b, 255),
                    a = safe_tonumber(colourAttrs.A or colourAttrs.a, 255)
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

-- ============================================================================
-- Map placement parsing (from Lance Spooner / Menyoo map XML)
-- ============================================================================
function P.parse_map_placements(xml)
    local placements = {}
    local searchPos = 1
    while true do
        local openStart = xml:find("<Placement[^>]*>", searchPos)
        if not openStart then break end
        local closePos = xml:find("</Placement>", openStart)
        if not closePos then break end
        local placementInner = xml:sub(openStart, closePos + #"</Placement>" - 1)
        local placement = {}
        placement.ModelHash = get_xml_element_content(placementInner, "ModelHash")
        placement.Type = get_xml_element_content(placementInner, "Type")
        placement.Dynamic = to_boolean(get_xml_element_content(placementInner, "Dynamic"))
        placement.FrozenPos = to_boolean(get_xml_element_content(placementInner, "FrozenPos"))
        placement.HashName = get_xml_element_content(placementInner, "HashName")
        placement.InitialHandle = safe_tonumber(get_xml_element_content(placementInner, "InitialHandle"), nil)
        placement.OpacityLevel = get_xml_element_content(placementInner, "OpacityLevel")
        placement.LodDistance = get_xml_element_content(placementInner, "LodDistance")
        placement.IsVisible = get_xml_element_content(placementInner, "IsVisible")
        placement.MaxHealth = get_xml_element_content(placementInner, "MaxHealth")
        placement.Health = get_xml_element_content(placementInner, "Health")
        placement.HasGravity = to_boolean(get_xml_element_content(placementInner, "HasGravity"))
        placement.IsOnFire = to_boolean(get_xml_element_content(placementInner, "IsOnFire"))
        placement.IsInvincible = to_boolean(get_xml_element_content(placementInner, "IsInvincible"))
        placement.IsBulletProof = to_boolean(get_xml_element_content(placementInner, "IsBulletProof"))
        placement.IsCollisionProof = to_boolean(get_xml_element_content(placementInner, "IsCollisionProof"))
        placement.IsExplosionProof = to_boolean(get_xml_element_content(placementInner, "IsExplosionProof"))
        placement.IsFireProof = to_boolean(get_xml_element_content(placementInner, "IsFireProof"))
        placement.IsMeleeProof = to_boolean(get_xml_element_content(placementInner, "IsMeleeProof"))
        placement.IsOnlyDamagedByPlayer = to_boolean(get_xml_element_content(placementInner, "IsOnlyDamagedByPlayer"))
        local objProps = get_xml_element(placementInner, "ObjectProperties")
        if objProps then
            placement.ObjectProperties = {}
            for name, val in objProps:gmatch("<([%w_]+)>(.-)</%1>") do
                placement.ObjectProperties[name] = val
            end
        end
        local posRot = get_xml_element(placementInner, "PositionRotation")
        if posRot then
            placement.PositionRotation = {}
            for name, val in posRot:gmatch("<([%w_]+)>(.-)</%1>") do
                placement.PositionRotation[name] = safe_tonumber(val, val)
            end
        end
        local attachment = get_xml_element(placementInner, "Attachment")
        if attachment then
            placement.Attachment = {}
            placement.Attachment.isAttached = attachment:find('isAttached="true"') ~= nil
            if placement.Attachment.isAttached then
                placement.Attachment.AttachedTo = safe_tonumber(get_xml_element_content(attachment, "AttachedTo"), nil)
                placement.Attachment.BoneIndex = safe_tonumber(get_xml_element_content(attachment, "BoneIndex"), nil)
                placement.Attachment.X = safe_tonumber(get_xml_element_content(attachment, "X"), 0.0)
                placement.Attachment.Y = safe_tonumber(get_xml_element_content(attachment, "Y"), 0.0)
                placement.Attachment.Z = safe_tonumber(get_xml_element_content(attachment, "Z"), 0.0)
                placement.Attachment.Pitch = safe_tonumber(get_xml_element_content(attachment, "Pitch"), 0.0)
                placement.Attachment.Roll = safe_tonumber(get_xml_element_content(attachment, "Roll"), 0.0)
                placement.Attachment.Yaw = safe_tonumber(get_xml_element_content(attachment, "Yaw"), 0.0)
            end
        end
        -- Parse PedProperties for map placements too
        local pedProps = get_xml_element(placementInner, "PedProperties")
        if pedProps then
            placement.PedProperties = {}
            placement.PedProperties.IsStill = to_boolean(get_xml_element_content(pedProps, "IsStill"))
            placement.PedProperties.CanRagdoll = to_boolean(get_xml_element_content(pedProps, "CanRagdoll"))
            placement.PedProperties.HasShortHeight = to_boolean(get_xml_element_content(pedProps, "HasShortHeight"))
            placement.PedProperties.Armour = safe_tonumber(get_xml_element_content(pedProps, "Armour"), 0)
            placement.PedProperties.CurrentWeapon = get_xml_element_content(pedProps, "CurrentWeapon")
            placement.PedProperties.RelationshipGroup = get_xml_element_content(pedProps, "RelationshipGroup")
            placement.PedProperties.AnimActive = get_xml_element_content(pedProps, "AnimActive")
            placement.PedProperties.AnimDict = get_xml_element_content(pedProps, "AnimDict")
            placement.PedProperties.AnimName = get_xml_element_content(pedProps, "AnimName")
            local propsSection = get_xml_element(pedProps, "PedProps")
            if propsSection then
                placement.PedProperties.PedProps = {}
                for propId, propData in propsSection:gmatch("<_(%d+)>([^<]+)</_") do
                    local parts = {}
                    for part in propData:gmatch("([^,]+)") do table.insert(parts, part) end
                    placement.PedProperties.PedProps["_" .. propId] = {
                        prop_id = safe_tonumber(parts[1], -1),
                        texture_id = safe_tonumber(parts[2], 0)
                    }
                end
            end
            local compsSection = get_xml_element(pedProps, "PedComps")
            if compsSection then
                placement.PedProperties.PedComps = {}
                for compId, compData in compsSection:gmatch("<_(%d+)>([^<]+)</_") do
                    local parts = {}
                    for part in compData:gmatch("([^,]+)") do table.insert(parts, part) end
                    placement.PedProperties.PedComps["_" .. compId] = {
                        comp_id = safe_tonumber(parts[1], 0),
                        texture_id = safe_tonumber(parts[2], 0)
                    }
                end
            end
        end
        -- Parse VehicleProperties for map placements
        local vehProps = get_xml_element(placementInner, "VehicleProperties")
        if vehProps then
            placement.VehicleProperties = {}
            placement.VehicleProperties.Colours = P.parse_vehicle_colors(placementInner)
            placement.VehicleProperties.Mods = P.parse_vehicle_mods(placementInner)
            placement.VehicleProperties.Neons = P.parse_vehicle_neons(placementInner)
            placement.VehicleProperties.Livery = safe_tonumber(get_xml_element_content(vehProps, "Livery"), nil)
            placement.VehicleProperties.NumberPlateText = get_xml_element_content(vehProps, "NumberPlateText")
            placement.VehicleProperties.NumberPlateIndex = safe_tonumber(get_xml_element_content(vehProps, "NumberPlateIndex"), nil)
            placement.VehicleProperties.WheelType = safe_tonumber(get_xml_element_content(vehProps, "WheelType"), nil)
            placement.VehicleProperties.WindowTint = safe_tonumber(get_xml_element_content(vehProps, "WindowTint"), nil)
            placement.VehicleProperties.DirtLevel = safe_tonumber(get_xml_element_content(vehProps, "DirtLevel"), nil)
            placement.VehicleProperties.EngineOn = to_boolean(get_xml_element_content(vehProps, "EngineOn"))
            local bulletProofTyres = get_xml_element_content(vehProps, "BulletProofTyres")
            if bulletProofTyres ~= nil then
                placement.VehicleProperties.BulletProofTyres = to_boolean(bulletProofTyres)
            end
        end
        table.insert(placements, placement)
        searchPos = closePos + #"</Placement>"
    end

    -- Parse markers
    local markers = {}
    searchPos = 1
    while true do
        local openStart = xml:find("<Marker[^>]*>", searchPos)
        if not openStart then break end
        local closePos = xml:find("</Marker>", openStart)
        if not closePos then break end
        local markerInner = xml:sub(openStart, closePos + #"</Marker>" - 1)
        
        local marker = {}
        marker.Type = safe_tonumber(get_xml_element_content(markerInner, "Type"), 0)
        marker.X = 0.0
        marker.Y = 0.0
        marker.Z = 0.0
        
        local posBlock = get_xml_element(markerInner, "Position")
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
        
        marker.Scale = safe_tonumber(get_xml_element_content(markerInner, "Scale"), 1.0)
        marker.RotateContinuously = to_boolean(get_xml_element_content(markerInner, "RotateContinuously"))
        
        local colourSnippet = parse_self_closing_tag(markerInner, "Colour")
        if colourSnippet then
            local colourAttrs = parse_attributes(colourSnippet)
            marker.Colour = {
                r = safe_tonumber(colourAttrs.R or colourAttrs.r, 255),
                g = safe_tonumber(colourAttrs.G or colourAttrs.g, 255),
                b = safe_tonumber(colourAttrs.B or colourAttrs.b, 255),
                a = safe_tonumber(colourAttrs.A or colourAttrs.a, 255)
            }
        end
        
        table.insert(markers, marker)
        searchPos = closePos + 1
    end

    return placements, markers
end

-- ============================================================================
-- Spooner attachments parsing (for vehicles/outfits)
-- ============================================================================
function P.parse_spooner_attachments(xml)
    local out = {}
    local defaultTaskAutoStart = nil
    local spoonerAttributes = xml:match("<SpoonerAttachments([^>]*)>")
    if spoonerAttributes then
        local attrs = parse_attributes(spoonerAttributes)
        if attrs and attrs.StartTaskSequencesOnLoad ~= nil then
            defaultTaskAutoStart = to_boolean(attrs.StartTaskSequencesOnLoad)
        end
    end
    local s = get_xml_element(xml, "SpoonerAttachments")
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
                e.ModelHash = get_xml_element_content(attInner, "ModelHash")
                e.Type = get_xml_element_content(attInner, "Type")
                e.Dynamic = to_boolean(get_xml_element_content(attInner, "Dynamic"))
                e.FrozenPos = to_boolean(get_xml_element_content(attInner, "FrozenPos"))
                e.HashName = get_xml_element_content(attInner, "HashName")
                e.InitialHandle = safe_tonumber(get_xml_element_content(attInner, "InitialHandle"), nil)
                e.OpacityLevel = get_xml_element_content(attInner, "OpacityLevel")
                e.HasGravity = to_boolean(get_xml_element_content(attInner, "HasGravity"))
                local objProps = get_xml_element(attInner, "ObjectProperties")
                if objProps then
                    e.ObjectProperties = {}
                    for name, val in objProps:gmatch("<([%w_]+)>(.-)</%1>") do e.ObjectProperties[name] = val end
                end
                local pedProps = get_xml_element(attInner, "PedProperties")
                if pedProps then
                    e.PedProperties = {}
                    for name, val in pedProps:gmatch("<([%w_]+)>(.-)</%1>") do e.PedProperties[name] = val end
                    local propsSection = get_xml_element(pedProps, "PedProps")
                    if propsSection then
                        e.PedProperties.PedProps = {}
                        for name, val in propsSection:gmatch("<_(%d+)>([^<]+)</%_(%d+)>") do
                            local id = safe_tonumber(name)
                            if id then
                                local parts = split_str(val, ",")
                                e.PedProperties.PedProps[id] = {
                                    prop_id = safe_tonumber(parts[1], -1),
                                    texture_id = safe_tonumber(parts[2], -1)
                                }
                            end
                        end
                    end
                    local compsSection = get_xml_element(pedProps, "PedComps")
                    if compsSection then
                        e.PedProperties.PedComps = {}
                        for name, val in compsSection:gmatch("<_(%d+)>([^<]+)</%_(%d+)>") do
                            local id = safe_tonumber(name)
                            if id then
                                local parts = split_str(val, ",")
                                e.PedProperties.PedComps[id] = {
                                    comp_id = safe_tonumber(parts[1], 0),
                                    texture_id = safe_tonumber(parts[2], 0)
                                }
                            end
                        end
                    end
                end
                
                -- Parse VehicleProperties for attachments
                local vehProps = get_xml_element(attInner, "VehicleProperties")
                if vehProps then
                    e.VehicleProperties = {}
                    e.VehicleProperties.Colours = P.parse_vehicle_colors(attInner)
                    e.VehicleProperties.Mods = P.parse_vehicle_mods(attInner)
                    e.VehicleProperties.Livery = safe_tonumber(get_xml_element_content(vehProps, "Livery"), nil)
                    e.VehicleProperties.NumberPlateText = get_xml_element_content(vehProps, "NumberPlateText")
                    e.VehicleProperties.NumberPlateIndex = safe_tonumber(get_xml_element_content(vehProps, "NumberPlateIndex"), nil)
                    e.VehicleProperties.WheelType = safe_tonumber(get_xml_element_content(vehProps, "WheelType"), nil)
                    e.VehicleProperties.WindowTint = safe_tonumber(get_xml_element_content(vehProps, "WindowTint"), nil)
                    e.VehicleProperties.DirtLevel = safe_tonumber(get_xml_element_content(vehProps, "DirtLevel"), nil)
                    e.VehicleProperties.EngineOn = to_boolean(get_xml_element_content(vehProps, "EngineOn"))
                    local bulletProofTyres = get_xml_element_content(vehProps, "BulletProofTyres")
                    if bulletProofTyres ~= nil then
                        e.VehicleProperties.BulletProofTyres = to_boolean(bulletProofTyres)
                    end
                    e.VehicleProperties.Neons = P.parse_vehicle_neons(attInner)
                end
                local posRot = get_xml_element(attInner, "PositionRotation")
                if posRot then
                    e.PositionRotation = {}
                    for name, val in posRot:gmatch("<([%w_]+)>(.-)</%1>") do e.PositionRotation[name] = safe_tonumber(val, 0.0) end
                end
                local nested = nil
                local lastAttachStart = nil
                local innerSearchPos = 1
                while true do
                    local found = attInner:find("<Attachment[^>]*>", innerSearchPos)
                    if not found then break end
                    lastAttachStart = found
                    innerSearchPos = found + 1
                end
                if lastAttachStart then
                    local afterTag = attInner:match("<Attachment[^>]*>(.*)", lastAttachStart)
                    if afterTag then
                        local nestedClosePos = afterTag:find("</Attachment>")
                        if nestedClosePos then
                            nested = afterTag:sub(1, nestedClosePos - 1)
                        end
                    end
                end
                if nested then
                    e.Attachment = {}
                    e.Attachment.AttachedTo = get_xml_element_content(nested, "AttachedTo")
                    e.Attachment.BoneIndex = safe_tonumber(get_xml_element_content(nested, "BoneIndex"), 0)
                    e.Attachment.X = get_xml_element_content(nested, "X")
                    e.Attachment.Y = get_xml_element_content(nested, "Y")
                    e.Attachment.Z = get_xml_element_content(nested, "Z")
                    e.Attachment.Pitch = get_xml_element_content(nested, "Pitch")
                    e.Attachment.Roll = get_xml_element_content(nested, "Roll")
                    e.Attachment.Yaw = get_xml_element_content(nested, "Yaw")
                    e.AttachmentRaw = nested
                end
                if e.Attachment and e.Attachment.AttachedTo then
                    local atn = safe_tonumber(e.Attachment.AttachedTo, nil)
                    if atn ~= nil then e.Attachment.AttachedTo = atn end
                end
                -- Capture all boolean-like tags
                for name, val in attInner:gmatch("<([%w_]+)>(.-)</%1>") do
                    if name:match("^Is") then
                        e[name] = to_boolean(val)
                    end
                end

                -- Explicitly read IsCollisionProof
                local colProofTag = get_xml_element_content(attInner, "IsCollisionProof")
                if colProofTag ~= nil then
                    e.IsCollisionProof = to_boolean(colProofTag)
                else
                    local anyProof = attInner:match("<IsCollisionProof>([^<]+)</IsCollisionProof>")
                    if anyProof then
                        e.IsCollisionProof = to_boolean(anyProof)
                    else
                        e.IsCollisionProof = false
                    end
                end

                local taskSequenceXml = get_xml_element(attInner, "TaskSequence")
                if taskSequenceXml then
                    e.TaskSequence = P.parse_task_sequence(taskSequenceXml, defaultTaskAutoStart)
                end

                if e.ModelHash then
                    local mh = safe_tonumber(e.ModelHash, nil)
                    if mh ~= nil then e.ModelHash = mh end
                end
                out[#out + 1] = e
            end
        end
        searchPos = closePos and (closePos + 1) or (openStart + 1)
    end
    return out
end

-- ============================================================================
-- Outfit attachments parsing (simpler than spooner, for outfit XMLs)
-- ============================================================================
function P.parse_outfit_attachments(xmlContent)
    local attachments = {}
    local defaultTaskAutoStart = nil
    local attrSnippet = xmlContent:match("<SpoonerAttachments([^>]*)>")
    if attrSnippet then
        local attrs = parse_attributes(attrSnippet)
        if attrs and attrs.StartTaskSequencesOnLoad ~= nil then
            defaultTaskAutoStart = to_boolean(attrs.StartTaskSequencesOnLoad)
        end
    end
    local spoonerAttachmentsElement = get_xml_element(xmlContent, "SpoonerAttachments")
    if not spoonerAttachmentsElement then
        return attachments
    end
    for attachmentElement in spoonerAttachmentsElement:gmatch("<Attachment>.-</Attachment>") do
        local attachment = {}
        attachment.ModelHash = get_xml_element_content(attachmentElement, "ModelHash")
        attachment.Type = get_xml_element_content(attachmentElement, "Type")
        attachment.Dynamic = to_boolean(get_xml_element_content(attachmentElement, "Dynamic"))
        attachment.FrozenPos = to_boolean(get_xml_element_content(attachmentElement, "FrozenPos"))
        attachment.HashName = get_xml_element_content(attachmentElement, "HashName")
        attachment.InitialHandle = get_xml_element_content(attachmentElement, "InitialHandle")
        attachment.OpacityLevel = safe_tonumber(get_xml_element_content(attachmentElement, "OpacityLevel"), nil)
        attachment.IsVisible = to_boolean(get_xml_element_content(attachmentElement, "IsVisible"))
        attachment.IsInvincible = to_boolean(get_xml_element_content(attachmentElement, "IsInvincible"))
        local objectPropsElement = get_xml_element(attachmentElement, "ObjectProperties")
        if objectPropsElement then
            attachment.ObjectProperties = {}
            local textureVariation = get_xml_element_content(objectPropsElement, "TextureVariation")
            if textureVariation then
                attachment.ObjectProperties.TextureVariation = safe_tonumber(textureVariation, 0)
            end
        end
        local posRotElement = get_xml_element(attachmentElement, "PositionRotation")
        if posRotElement then
            attachment.PositionRotation = {}
            attachment.PositionRotation.X = safe_tonumber(get_xml_element_content(posRotElement, "X"), 0.0)
            attachment.PositionRotation.Y = safe_tonumber(get_xml_element_content(posRotElement, "Y"), 0.0)
            attachment.PositionRotation.Z = safe_tonumber(get_xml_element_content(posRotElement, "Z"), 0.0)
            attachment.PositionRotation.Pitch = safe_tonumber(get_xml_element_content(posRotElement, "Pitch"), 0.0)
            attachment.PositionRotation.Roll = safe_tonumber(get_xml_element_content(posRotElement, "Roll"), 0.0)
            attachment.PositionRotation.Yaw = safe_tonumber(get_xml_element_content(posRotElement, "Yaw"), 0.0)
        end
        local attachmentDataElement = get_xml_element(attachmentElement, "Attachment")
        if attachmentDataElement then
            attachment.Attachment = {}
            attachment.Attachment.isAttached = attachmentDataElement:find('isAttached="true"') and true or false
            attachment.Attachment.AttachedTo = get_xml_element_content(attachmentDataElement, "AttachedTo")
            attachment.Attachment.BoneIndex = safe_tonumber(get_xml_element_content(attachmentDataElement, "BoneIndex"), 0)
            attachment.Attachment.X = safe_tonumber(get_xml_element_content(attachmentDataElement, "X"), 0.0)
            attachment.Attachment.Y = safe_tonumber(get_xml_element_content(attachmentDataElement, "Y"), 0.0)
            attachment.Attachment.Z = safe_tonumber(get_xml_element_content(attachmentDataElement, "Z"), 0.0)
            attachment.Attachment.Pitch = safe_tonumber(get_xml_element_content(attachmentDataElement, "Pitch"), 0.0)
            attachment.Attachment.Roll = safe_tonumber(get_xml_element_content(attachmentDataElement, "Roll"), 0.0)
            attachment.Attachment.Yaw = safe_tonumber(get_xml_element_content(attachmentDataElement, "Yaw"), 0.0)
        end
        local taskSequenceElement = get_xml_element(attachmentElement, "TaskSequence")
        if taskSequenceElement then
            attachment.TaskSequence = P.parse_task_sequence(taskSequenceElement, defaultTaskAutoStart)
        end
        table.insert(attachments, attachment)
    end
    return attachments
end

-- ============================================================================
-- Context preview metadata for XML files
-- ============================================================================

local function getXmlElementContentLocal(xml, tag)
    if not xml or not tag then return nil end
    local pattern = "<" .. tag .. ">([^<]*)</" .. tag .. ">"
    local content = xml:match(pattern)
    if content then return content end
    return nil
end

local function countXmlAttachmentsByType(xmlContent)
    local counts = { objects = 0, vehicles = 0, peds = 0, total = 0 }
    local spoonerSection = xmlContent:match("<SpoonerAttachments[^>]*>(.-)</SpoonerAttachments>")
    if spoonerSection then
        for attachBlock in spoonerSection:gmatch("<Attachment>(.-)</Attachment>") do
            local typeStr = getXmlElementContentLocal(attachBlock, "Type")
            local typeNum = tonumber(typeStr) or 3
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

local function countMapPlacementsByType(xmlContent)
    local counts = { objects = 0, vehicles = 0, peds = 0, total = 0 }
    for placementBlock in xmlContent:gmatch("<Placement[^>]*>(.-)</Placement>") do
        local typeStr = getXmlElementContentLocal(placementBlock, "Type")
        local typeNum = tonumber(typeStr) or 3
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

function P.parseMetadata(content, filePath)
    local metadata = {}
    
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
        local rootBlock = content
        local hasVehicleRoot = content:find("<Vehicle[^>]*>") ~= nil
        local hasSpoonerSection = content:find("<SpoonerAttachments") ~= nil
        
        if hasVehicleRoot or (hasSpoonerSection and content:find("<ModelHash>.-<SpoonerAttachments")) then
            -- Root entity data is above <SpoonerAttachments>, extract only that portion
            local beforeSpooner = content:match("^(.-)<SpoonerAttachments")
            if beforeSpooner then
                rootBlock = beforeSpooner
            end
        elseif hasSpoonerSection then
            -- Pure SpoonerAttachments format: root entity is the first Attachment block
            local spoonerSection = content:match("<SpoonerAttachments[^>]*>(.*)</SpoonerAttachments>")
            if spoonerSection then
                local firstAttachment = spoonerSection:match("<Attachment[^>]*>(.-)</Attachment>")
                if firstAttachment then
                    rootBlock = firstAttachment
                end
            end
        end
        
        local modelHash = getXmlElementContentLocal(rootBlock, "ModelHash")
        if modelHash then
            metadata.modelHash = modelHash
        end
        
        local hashName = getXmlElementContentLocal(rootBlock, "HashName")
        local counts = countXmlAttachmentsByType(content)
        metadata.attachmentCount = counts.total
        metadata.objectCount = counts.objects
        metadata.vehicleCount = counts.vehicles
        metadata.pedCount = counts.peds
        
        local typeStr = getXmlElementContentLocal(rootBlock, "Type")
        if typeStr == "1" then
            metadata.itemType = "outfit"
            metadata.pedCount = metadata.pedCount + 1
        elseif typeStr == "2" or hasVehicleRoot then
            metadata.itemType = "vehicle"
            metadata.vehicleCount = metadata.vehicleCount + 1
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
        
        if not metadata.modelName and hashName then
            metadata.modelName = hashName
        end
    end
    
    return metadata
end

return P
