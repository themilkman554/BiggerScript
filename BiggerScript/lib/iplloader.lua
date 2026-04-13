local M = {}

local rootPath = nil
local cachedIPLData = nil
local cachedDlcNames = nil
local loadedGroups = {}  -- { groupName = { position = {X, Y, Z}, displayName = "..." } }
local selectedDlcFilter = nil  -- nil means "All"
local lastLoadedGroup = nil
local pendingUnloads = {}  -- Queue of group names to unload (deferred to avoid ImGui issues)

function M.init(context)
    rootPath = context.rootPath
end

-- Parse ipls.json and cache the data
local function parseIPLData()
    if cachedIPLData then
        return cachedIPLData
    end
    
    local iplsPath = rootPath .. "\\ipls.json"
    if not FileMgr.DoesFileExist(iplsPath) then
        GUI.AddToast("IPL Loader", "ipls.json not found", 3000, 0)
        return {}
    end
    
    local content = FileMgr.ReadFileContent(iplsPath)
    if not content or content == "" then
        GUI.AddToast("IPL Loader", "Failed to read ipls.json", 3000, 0)
        return {}
    end
    
    -- Parse JSON using the same method as spawning.lua
    local success, data = pcall(function()
        local luaCode = content
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
            error("Failed to parse: " .. tostring(err))
        end
        return func()
    end)
    
    if not success or not data then
        GUI.AddToast("IPL Loader", "Failed to parse ipls.json", 3000, 0)
        return {}
    end
    
    cachedIPLData = data
    return cachedIPLData
end

-- Get display name for a group (use ExtraData.Name if GroupName is "Auto YMAP Group X")
local function getDisplayNameForGroup(groupName, iplData)
    -- If it's an auto-generated group name, try to find a better name
    if groupName:match("^Auto YMAP Group") then
        for _, ipl in ipairs(iplData) do
            if ipl.ExtraData and ipl.ExtraData.GroupName == groupName then
                -- Use ExtraData.Name if available
                if ipl.ExtraData.Name and ipl.ExtraData.Name ~= "" then
                    return ipl.ExtraData.Name
                end
                -- Fall back to IPL Name
                if ipl.Name and ipl.Name ~= "" then
                    return ipl.Name
                end
            end
        end
    end
    return groupName
end

-- Get sorted list of unique DlcNames
function M.getDlcNames()
    if cachedDlcNames then
        return cachedDlcNames
    end
    
    local iplData = parseIPLData()
    local dlcSet = {}
    
    for _, ipl in ipairs(iplData) do
        if ipl.DlcName and ipl.DlcName ~= "" then
            dlcSet[ipl.DlcName] = true
        end
    end
    
    local dlcs = {}
    for dlcName, _ in pairs(dlcSet) do
        table.insert(dlcs, dlcName)
    end
    table.sort(dlcs, function(a, b) return a:lower() < b:lower() end)
    
    cachedDlcNames = dlcs
    return cachedDlcNames
end

-- Cache for group names per DLC filter
local cachedGroupsByDlc = {}
local lastDlcFilter = nil

-- Set DLC filter (nil for all)
function M.setDlcFilter(dlcName)
    print("[IPL Debug] setDlcFilter: " .. tostring(dlcName))
    selectedDlcFilter = dlcName
end

-- Get current DLC filter
function M.getDlcFilter()
    return selectedDlcFilter
end

-- Get sorted list of unique GroupNames with display names (filtered by DLC if set)
function M.getGroupNames()
    -- Use cache key based on filter
    local cacheKey = selectedDlcFilter or "__main__"
    
    -- Return cached if available
    if cachedGroupsByDlc[cacheKey] then
        return cachedGroupsByDlc[cacheKey]
    end
    
    local iplData = parseIPLData()
    local groupMap = {}  -- groupName -> displayName
    
    for _, ipl in ipairs(iplData) do
        -- Apply DLC filter: "__all__" means all DLCs, specific DLC name filters to that DLC
        local matchesDlc = (selectedDlcFilter == "__all__") or (ipl.DlcName == selectedDlcFilter)
        
        if matchesDlc and ipl.ExtraData and ipl.ExtraData.GroupName and ipl.ExtraData.GroupName ~= "" then
            local groupName = ipl.ExtraData.GroupName
            if not groupMap[groupName] then
                groupMap[groupName] = getDisplayNameForGroup(groupName, iplData)
            end
        end
    end
    
    -- Convert to sorted array of {key, displayName}
    local groups = {}
    for groupName, displayName in pairs(groupMap) do
        table.insert(groups, { key = groupName, display = displayName })
    end
    table.sort(groups, function(a, b) return a.display:lower() < b.display:lower() end)
    
    -- Store in cache
    cachedGroupsByDlc[cacheKey] = groups
    return groups
end

-- Get groups for Main filter: all groups with display names starting with uppercase letter
-- Excludes groups that are already in curated locations
local cachedMainGroups = nil
function M.getMainGroups()
    if cachedMainGroups then
        return cachedMainGroups
    end
    
    -- Build set of curated group names to exclude
    local curatedGroupNames = {}
    for _, loc in ipairs(M.curatedLocations) do
        if loc.type == "group" and loc.groupName then
            curatedGroupNames[loc.groupName] = true
        end
    end
    
    local iplData = parseIPLData()
    local groupMap = {}  -- groupName -> displayName
    
    for _, ipl in ipairs(iplData) do
        if ipl.ExtraData and ipl.ExtraData.GroupName and ipl.ExtraData.GroupName ~= "" then
            local groupName = ipl.ExtraData.GroupName
            -- Skip auto-generated group names and curated locations
            if not groupName:match("^Auto YMAP Group") and not curatedGroupNames[groupName] then
                if not groupMap[groupName] then
                    local displayName = getDisplayNameForGroup(groupName, iplData)
                    -- Only include if display name starts with uppercase letter
                    local firstChar = displayName:sub(1, 1)
                    if firstChar:match("[A-Z]") then
                        groupMap[groupName] = displayName
                    end
                end
            end
        end
    end
    
    -- Convert to sorted array
    local groups = {}
    for groupName, displayName in pairs(groupMap) do
        table.insert(groups, { key = groupName, display = displayName })
    end
    table.sort(groups, function(a, b) return a.display:lower() < b.display:lower() end)
    
    cachedMainGroups = groups
    return cachedMainGroups
end

-- Get all IPL names for a specific group (also returns first IPL position, display name, and DLC name)
local function getIPLsForGroup(groupName)
    local iplData = parseIPLData()
    local ipls = {}
    local firstPosition = nil
    local displayName = groupName
    local dlcName = "basegame"
    
    for _, ipl in ipairs(iplData) do
        if ipl.ExtraData and ipl.ExtraData.GroupName == groupName and ipl.Name then
            table.insert(ipls, ipl.Name)
            -- Store position of first IPL
            if not firstPosition and ipl.Position then
                firstPosition = ipl.Position
            end
            -- Get display name
            if displayName == groupName then
                displayName = getDisplayNameForGroup(groupName, iplData)
            end
            -- Get DLC name from first IPL
            if dlcName == "basegame" and ipl.DlcName then
                dlcName = ipl.DlcName
            end
        end
    end
    
    return ipls, firstPosition, displayName, dlcName
end

-- Load all IPLs in a group and teleport to first IPL position
function M.loadIPLGroup(groupName, skipTeleport)
    local iplData = parseIPLData()
    local loadedCount = 0
    local firstPosition = nil
    local displayName = groupName
    local iplDetails = {}
    
    -- Collect and load all IPLs for this group
    for _, ipl in ipairs(iplData) do
        if ipl.ExtraData and ipl.ExtraData.GroupName == groupName and ipl.Name then
            STREAMING.REQUEST_IPL(ipl.Name)
            loadedCount = loadedCount + 1
            
            -- Store first position for teleport
            if not firstPosition and ipl.Position then
                firstPosition = ipl.Position
            end
            
            -- Get display name
            if displayName == groupName then
                displayName = getDisplayNameForGroup(groupName, iplData)
            end
            
            -- Store IPL details for teleport dropdown
            table.insert(iplDetails, {
                name = ipl.Name,
                position = ipl.Position,
                displayName = (ipl.ExtraData and ipl.ExtraData.Name and ipl.ExtraData.Name ~= "") and ipl.ExtraData.Name or ipl.Name
            })
        end
    end
    
    -- Also try to activate interior entity sets for MLO interiors
    pcall(function()
        for _, iplDetail in ipairs(iplDetails) do
            if firstPosition and firstPosition.X then
                local interior = INTERIOR.GET_INTERIOR_AT_COORDS(firstPosition.X, firstPosition.Y, firstPosition.Z)
                if interior and interior ~= 0 then
                    INTERIOR.ACTIVATE_INTERIOR_ENTITY_SET(interior, iplDetail.name)
                    INTERIOR.REFRESH_INTERIOR(interior)
                end
            end
        end
    end)
    
    loadedGroups[groupName] = {
        position = firstPosition,
        displayName = displayName,
        iplCount = loadedCount,
        ipls = iplDetails
    }
    
    -- Teleport player to first IPL position (unless skipped)
    if not skipTeleport and firstPosition and firstPosition.X and firstPosition.Y and firstPosition.Z then
        local playerPed = PLAYER.PLAYER_PED_ID()
        if playerPed and playerPed ~= 0 then
            ENTITY.SET_ENTITY_COORDS(playerPed, firstPosition.X, firstPosition.Y, firstPosition.Z, false, false, false, true)
        end
    end
    
    GUI.AddToast("IPL Loader", "Loaded " .. displayName .. " (" .. loadedCount .. " IPLs)", 2000, 0)
end

-- Unload all IPLs in a group
function M.unloadIPLGroup(groupName)
    local ipls, _, displayName = getIPLsForGroup(groupName)
    local unloadedCount = 0
    
    for _, iplName in ipairs(ipls) do
        -- Wrap in pcall to prevent crashes on certain IPLs
        pcall(function()
            -- Only try to remove if the IPL is actually active
            if STREAMING.IS_IPL_ACTIVE(iplName) then
                STREAMING.REMOVE_IPL(iplName)
                unloadedCount = unloadedCount + 1
            end
        end)
    end
    
    loadedGroups[groupName] = nil
    GUI.AddToast("IPL Loader", "Unloaded " .. displayName .. " (" .. unloadedCount .. " IPLs)", 2000, 0)
end

-- Check if a group is currently loaded
function M.isGroupLoaded(groupName)
    return loadedGroups[groupName] ~= nil
end

-- Get all loaded groups (for UI display) with IPL details
function M.getLoadedGroups()
    local result = {}
    for groupName, data in pairs(loadedGroups) do
        table.insert(result, {
            key = groupName,
            displayName = data.displayName or groupName,
            position = data.position,
            iplCount = data.iplCount or 0,
            ipls = data.ipls or {}
        })
    end
    return result
end

-- Get IPL details for a loaded group (for teleport dropdown)
function M.getIPLsForLoadedGroup(groupName)
    local data = loadedGroups[groupName]
    if data and data.ipls then
        return data.ipls
    end
    return {}
end

-- Teleport to a loaded group's position
function M.teleportToGroup(groupName)
    local data = loadedGroups[groupName]
    if data and data.position then
        local pos = data.position
        if pos.X and pos.Y and pos.Z then
            local playerPed = PLAYER.PLAYER_PED_ID()
            if playerPed and playerPed ~= 0 then
                ENTITY.SET_ENTITY_COORDS(playerPed, pos.X, pos.Y, pos.Z, false, false, false, true)
            end
        end
    end
end

-- Teleport to a specific IPL position
function M.teleportToPosition(pos)
    if pos and pos.X and pos.Y and pos.Z then
        local playerPed = PLAYER.PLAYER_PED_ID()
        if playerPed and playerPed ~= 0 then
            ENTITY.SET_ENTITY_COORDS(playerPed, pos.X, pos.Y, pos.Z, false, false, false, true)
        end
    end
end

-- Unload all loaded IPL groups
function M.unloadAllGroups()
    local count = 0
    for groupName, _ in pairs(loadedGroups) do
        local ipls = getIPLsForGroup(groupName)
        for _, iplName in ipairs(ipls) do
            pcall(function()
                if STREAMING.IS_IPL_ACTIVE(iplName) then
                    STREAMING.REMOVE_IPL(iplName)
                end
            end)
        end
        count = count + 1
    end
    loadedGroups = {}
    if count > 0 then
        GUI.AddToast("IPL Loader", "Unloaded " .. count .. " IPL groups", 2000, 0)
    end
end

-- Queue a group for deferred unloading (safe to call during ImGui rendering)
function M.queueUnloadGroup(groupName)
    table.insert(pendingUnloads, { type = "group", key = groupName })
end

-- Queue a curated location for deferred unloading
function M.queueUnloadCurated(index)
    table.insert(pendingUnloads, { type = "curated", index = index })
end

-- Queue a DLC for deferred unloading
function M.queueUnloadDlc(dlcName)
    table.insert(pendingUnloads, { type = "dlc", key = dlcName })
end

-- Process all pending unloads (call this after ImGui rendering is complete)
function M.processPendingUnloads()
    if #pendingUnloads == 0 then
        return
    end
    
    -- Copy and clear the queue first to avoid issues if unload triggers more unloads
    local toProcess = pendingUnloads
    pendingUnloads = {}
    
    for _, pending in ipairs(toProcess) do
        if pending.type == "group" then
            M.unloadIPLGroup(pending.key)
        elseif pending.type == "curated" then
            M.unloadCuratedLocation(pending.index)
        elseif pending.type == "dlc" then
            M.unloadByDlc(pending.key)
        end
    end
end

-- Toggle load/unload for a group (uses queued unload for safety during ImGui rendering)
function M.toggleGroup(groupName, unloadLast)
    if M.isGroupLoaded(groupName) then
        M.queueUnloadGroup(groupName)
    else
        -- Unload last group if setting is enabled
        if unloadLast and lastLoadedGroup and lastLoadedGroup ~= groupName and M.isGroupLoaded(lastLoadedGroup) then
            M.queueUnloadGroup(lastLoadedGroup)
        end
        M.loadIPLGroup(groupName)
        lastLoadedGroup = groupName
    end
end

-- ===== CURATED LOCATIONS =====

-- Load all IPLs by DlcName (for Cayo Perico etc)
function M.loadByDlc(dlcName, displayName, shouldTeleport)
    local iplData = parseIPLData()
    local loadedCount = 0
    local firstPosition = nil
    local iplDetails = {}
    
    for _, ipl in ipairs(iplData) do
        if ipl.DlcName == dlcName and ipl.Name then
            pcall(function()
                STREAMING.REQUEST_IPL(ipl.Name)
            end)
            loadedCount = loadedCount + 1
            
            -- Store first position for teleport
            if not firstPosition and ipl.Position then
                firstPosition = ipl.Position
            end
            
            -- Store IPL details
            table.insert(iplDetails, {
                name = ipl.Name,
                position = ipl.Position,
                displayName = (ipl.ExtraData and ipl.ExtraData.Name) or ipl.Name
            })
        end
    end
    
    local groupKey = "dlc:" .. dlcName
    loadedGroups[groupKey] = {
        position = firstPosition,
        displayName = displayName or dlcName,
        iplCount = loadedCount,
        ipls = iplDetails,
        isDlcGroup = true
    }
    
    -- Teleport only if requested
    if shouldTeleport and firstPosition then
        M.teleportToPosition(firstPosition)
    end
    
    GUI.AddToast("IPL Loader", "Loaded " .. displayName .. " (" .. loadedCount .. " IPLs)", 2000, 0)
    return groupKey
end

-- Unload all IPLs by DlcName
function M.unloadByDlc(dlcName)
    local iplData = parseIPLData()
    local unloadedCount = 0
    
    for _, ipl in ipairs(iplData) do
        if ipl.DlcName == dlcName and ipl.Name then
            pcall(function()
                if STREAMING.IS_IPL_ACTIVE(ipl.Name) then
                    STREAMING.REMOVE_IPL(ipl.Name)
                    unloadedCount = unloadedCount + 1
                end
            end)
        end
    end
    
    loadedGroups["dlc:" .. dlcName] = nil
    GUI.AddToast("IPL Loader", "Unloaded " .. unloadedCount .. " IPLs", 2000, 0)
end

-- Curated locations configuration
M.curatedLocations = {
    {
        name = "North Yankton",
        type = "group",
        groupName = "North Yankton",
        description = "Prologue location",
        customTeleport = { X = 3210.0, Y = -4833.0, Z = 111.0 }
    },
    {
        name = "Cayo Perico",
        type = "dlc",
        dlcName = "mpheist4",
        description = "Heist island",
        customTeleport = { X = 4482.0, Y = -4497.0, Z = 4.0 }
    }
}

-- Load a curated location
function M.loadCuratedLocation(index, shouldTeleport)
    local loc = M.curatedLocations[index]
    if not loc then return end
    
    if loc.type == "group" then
        if loc.customTeleport and shouldTeleport then
            M.loadIPLGroup(loc.groupName, true)
            M.teleportToPosition(loc.customTeleport)
        else
            M.loadIPLGroup(loc.groupName, not shouldTeleport)
        end
    elseif loc.type == "dlc" then
        if loc.customTeleport and shouldTeleport then
            M.loadByDlc(loc.dlcName, loc.name, false)
            M.teleportToPosition(loc.customTeleport)
        else
            M.loadByDlc(loc.dlcName, loc.name, shouldTeleport)
        end
    end
end

-- Check if a curated location is loaded
function M.isCuratedLocationLoaded(index)
    local loc = M.curatedLocations[index]
    if not loc then return false end
    
    if loc.type == "group" then
        return M.isGroupLoaded(loc.groupName)
    elseif loc.type == "dlc" then
        return loadedGroups["dlc:" .. loc.dlcName] ~= nil
    end
    return false
end

-- Unload a curated location
function M.unloadCuratedLocation(index)
    local loc = M.curatedLocations[index]
    if not loc then return end
    
    if loc.type == "group" then
        M.unloadIPLGroup(loc.groupName)
    elseif loc.type == "dlc" then
        M.unloadByDlc(loc.dlcName)
    end
end

return M

