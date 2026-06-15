---I think the edgy cracker logo really adds to whole experience
Logger.Log(eLogColor.GREEN, "", " ▄▄▄▄    ██▓  ▄████   ▄████ ▓█████  ██▀███    ██████  ▄████▄   ██▀███   ██▓ ██▓███  ▄▄▄█████▓")
Logger.Log(eLogColor.GREEN, "", "▓█████▄ ▓██▒ ██▒ ▀█▒ ██▒ ▀█▒▓█   ▀ ▓██ ▒ ██▒▒██    ▒ ▒██▀ ▀█  ▓██ ▒ ██▒▓██▒▓██░  ██▒▓  ██▒ ▓▒")
Logger.Log(eLogColor.GREEN, "", "▒██▒ ▄██▒██▒▒██░▄▄▄░▒██░▄▄▄░▒███   ▓██ ░▄█ ▒░ ▓██▄   ▒▓█    ▄ ▓██ ░▄█ ▒▒██▒▓██░ ██▓▒▒ ▓██░ ▒░")
Logger.Log(eLogColor.GREEN, "", "▒██░█▀  ░██░░▓█  ██▓░▓█  ██▓▒▓█  ▄ ▒██▀▀█▄    ▒   ██▒▒▓▓▄ ▄██▒▒██▀▀█▄  ░██░▒██▄█▓▒ ▒░ ▓██▓ ░ ")
Logger.Log(eLogColor.GREEN, "", "░▓█  ▀█▓░██░░▒▓███▀▒░▒▓███▀▒░▒████▒░██▓ ▒██▒▒██████▒▒▒ ▓███▀ ░░██▓ ▒██▒░██░▒██▒ ░  ░  ▒██▒ ░ ")
Logger.Log(eLogColor.GREEN, "", "░▒▓███▀▒░▓   ░▒   ▒  ░▒   ▒ ░░ ▒░ ░░ ▒▓ ░▒▓░▒ ▒▓▒ ▒ ░░ ░▒ ▒  ░░ ▒▓ ░▒▓░░▓  ▒▓▒░ ░  ░  ▒ ░░   ")
Logger.Log(eLogColor.GREEN, "", "▒░▒   ░  ▒ ░  ░   ░   ░   ░  ░ ░  ░  ░▒ ░ ▒░░ ░▒  ░ ░  ░  ▒     ░▒ ░ ▒░ ▒ ░░▒ ░         ░    ")
Logger.Log(eLogColor.GREEN, "", " ░    ░  ▒ ░░ ░   ░ ░ ░   ░    ░     ░░   ░ ░  ░  ░  ░          ░░   ░  ▒ ░░░         ░      ")
Logger.Log(eLogColor.GREEN, "", " ░       ░        ░       ░    ░  ░   ░           ░  ░ ░         ░      ░                    ")
Logger.Log(eLogColor.GREEN, "", "      ░                                              ░                                       ")

GUI.AddToast("BiggerScriptv8.2", "Expanded Job Browser\n GTA Outfit Loader", 10000, 0)

if Cherax.GetEdition() == "LE" then
    GUI.AddToast("BiggerScript", "Legacy Version of Cherax breaks vehicles with too many attachments", 10000, 0)
end
package.path = FileMgr.GetMenuRootPath() .. "\\Lua\\?.lua;"

local upsidedownmap = require("BiggerScript/lib/upsidedownmap")
local spawning = require("BiggerScript/lib/spawning")
local robot = require("BiggerScript/lib/robot")
local constructor_lib = require("BiggerScript/lib/constructor_lib")
local vehicle_fly = require("BiggerScript/lib/vehicle_fly")
local spooner = require("BiggerScript/lib/spooner")
local asset_loader = require("BiggerScript/lib/asset_loader")
local iplloader = require("BiggerScript/lib/iplloader")
local PaidTier = require("BiggerScript/lib/paid_tier")
local Sentry = require("BiggerScript/lib/Sentry")
local Hoverboard = require("BiggerScript/lib/Hoverboard")
local animPlayer = require("BiggerScript/lib/anim_player")

local menuRootPath = FileMgr.GetMenuRootPath()
local biggerScriptRootPath = menuRootPath .. "\\Lua\\BiggerScript"
local xmlVehiclesFolder = biggerScriptRootPath .. "\\XML Vehicles"
local iniVehiclesFolder = biggerScriptRootPath .. "\\INI Vehicles"
local jsonVehiclesFolder = biggerScriptRootPath .. "\\JSON Vehicles"
local xmlMapsFolder = biggerScriptRootPath .. "\\XML Maps"
local jsonMapsFolder = biggerScriptRootPath .. "\\JSON Maps"
local jobMapsFolder = biggerScriptRootPath .. "\\Jobs"
local xmlOutfitsFolder = biggerScriptRootPath .. "\\XML Outfits"
local jsonOutfitsFolder = biggerScriptRootPath .. "\\JSON Outfits"
local chrxVehiclesFolder = FileMgr.GetMenuRootPath() .. "\\Vehicles"
local chrxOutfitsFolder = FileMgr.GetMenuRootPath() .. "\\Outfits"


local spawnerSettings = {
    inVehicle = true,
    spawnPlaneInTheAir = true,
    deleteOldVehicle = false,
    vehicleGodMode = true,
    vehicleEngineOn = true,
    upgradedVehicle = false,
    randomColor = false,
    randomLivery = false,
    printToDebug = false,
    networkMapsV2Enabled = true,
    networkMapsV1Enabled = false, 
    deleteOldMap = false,
    spawnIn000Vehicle = false, 
    previewVehicle = false,
    previewOutfit = false,
    teleportToMap = true,
    spawnMapOnMe = false,
    vehicleFly = false,
    upsideDownMap = false,
    radioOff = false,
    onlyApplyAttachments = false,
    deleteLastOutfitAttachments = false,
    enableSpooner = false,
    enableGizmo = true, 
    showSpoonerControls = true,
    deletePhotoCache = false,
    contextPreview = true,
    photoPreview = true,
    photoPreviewWidth = 256,
    unloadLastIPL = false,
    separateFormatTabs = true,
    separateMapFormatTabs = true,
    separateOutfitFormatTabs = true,
    attackerSpawnMode = 0, -- 0 = Attacker, 1 = Gift, 2 = Apply
    scaleLengthOffset = 0x60,
    scaleWidthOffset = 0x74,
    scaleHeightOffset = 0x88, -- Initial values for scale memory modification (length, width, height)
}
local attackerSpawnModeNames = {"Attacker", "Gift", "Apply"}
local lastSpoonerState = false


local previewEntities = {}
local currentPreviewFile = nil

local spawnedVehicles = {}


local spawnedMaps = {}


local spawnedOutfits = {}


local currentSelectedVehicleXml = nil
local currentSelectedVehicleIni = nil

local function getCurrentSelectedVehicleXml()
    if currentSelectedVehicleXml and FileMgr.DoesFileExist(currentSelectedVehicleXml) then return currentSelectedVehicleXml end
    return spawning.getFirstVehicleXml()
end

local function getCurrentSelectedVehicleIni()
    if currentSelectedVehicleIni and FileMgr.DoesFileExist(currentSelectedVehicleIni) then return currentSelectedVehicleIni end
    local files = FileMgr.FindFiles(iniVehiclesFolder, ".ini", true)
    if not files or #files == 0 then return nil end
    return files[1]
end

local function buildFolderStructure(files, basePath)
    local structure = { folders = {}, files = {} }
    for _, filePath in ipairs(files) do
        local normalizedBase = basePath:gsub("\\", "/")
        local normalizedFile = filePath:gsub("\\", "/")
        local relative = normalizedFile:gsub("^" .. normalizedBase .. "/", "")
        local parts = {}
        for part in relative:gmatch("([^/]+)") do table.insert(parts, part) end
        local cur = structure
        for i = 1, #parts do
            local part = parts[i]
            if i == #parts then
                -- Remove file extension from display name
                local displayName = part:gsub("%.xml$", ""):gsub("%.ini$", ""):gsub("%.json$", "")
                table.insert(cur.files, { name = displayName, fullPath = filePath })
            else
                cur.folders[part] = cur.folders[part] or { folders = {}, files = {} }
                cur = cur.folders[part]
            end
        end
    end
    return structure
end

local cachedXmlVehicles = nil
local cachedIniVehicles = nil
local cachedJsonVehicles = nil
local cachedXmlMaps = nil
local cachedJsonMaps = nil
local cachedJobMaps = nil
local cachedXmlOutfits = nil
local cachedJsonOutfits = nil

local function refreshXmlVehicles()
    local files = FileMgr.FindFiles(xmlVehiclesFolder, ".xml", true)
    if not files or #files == 0 then
        cachedXmlVehicles = { folders = {}, files = {} }
    else
        cachedXmlVehicles = buildFolderStructure(files, xmlVehiclesFolder)
    end
end

local function refreshIniVehicles()
    local files = FileMgr.FindFiles(iniVehiclesFolder, ".ini", true)
    if not files or #files == 0 then
        cachedIniVehicles = { folders = {}, files = {} }
    else
        cachedIniVehicles = buildFolderStructure(files, iniVehiclesFolder)
    end
end

local function refreshXmlMaps()
    local files = FileMgr.FindFiles(xmlMapsFolder, ".xml", true)
    if not files or #files == 0 then
        cachedXmlMaps = { folders = {}, files = {} }
    else
        cachedXmlMaps = buildFolderStructure(files, xmlMapsFolder)
    end
end

local function refreshXmlOutfits()
    local files = FileMgr.FindFiles(xmlOutfitsFolder, ".xml", true)
    if not files or #files == 0 then
        cachedXmlOutfits = { folders = {}, files = {} }
    else
        cachedXmlOutfits = buildFolderStructure(files, xmlOutfitsFolder)
    end
end

local function getXmlFiles()
    if not cachedXmlVehicles then refreshXmlVehicles() end
    return cachedXmlVehicles
end

local function getIniVehicles()
    if not cachedIniVehicles then refreshIniVehicles() end
    return cachedIniVehicles
end

local function refreshJsonVehicles()
    local files = FileMgr.FindFiles(jsonVehiclesFolder, ".json", true)
    if not files or #files == 0 then
        cachedJsonVehicles = { folders = {}, files = {} }
    else
        cachedJsonVehicles = buildFolderStructure(files, jsonVehiclesFolder)
    end
end

local function getJsonVehicles()
    if not cachedJsonVehicles then refreshJsonVehicles() end
    return cachedJsonVehicles
end

local function getXmlMaps()
    if not cachedXmlMaps then refreshXmlMaps() end
    return cachedXmlMaps
end

local function refreshJsonMaps()
    local files = FileMgr.FindFiles(jsonMapsFolder, ".json", true)
    if not files or #files == 0 then
        cachedJsonMaps = { folders = {}, files = {} }
    else
        cachedJsonMaps = buildFolderStructure(files, jsonMapsFolder)
   end
end

local function getJsonMaps()
    if not cachedJsonMaps then refreshJsonMaps() end
    return cachedJsonMaps
end

local function refreshJobMaps()
    local files = FileMgr.FindFiles(jobMapsFolder, ".json", true)
    if not files or #files == 0 then
        cachedJobMaps = { folders = {}, files = {} }
    else
        cachedJobMaps = buildFolderStructure(files, jobMapsFolder)
    end
end

local function getJobMaps()
    if not cachedJobMaps then refreshJobMaps() end
    return cachedJobMaps
end

local function getXmlOutfits()
    if not cachedXmlOutfits then refreshXmlOutfits() end
    return cachedXmlOutfits
end

local function refreshJsonOutfits()
    local files = FileMgr.FindFiles(jsonOutfitsFolder, ".json", true)
    if not files or #files == 0 then
        cachedJsonOutfits = { folders = {}, files = {} }
    else
        cachedJsonOutfits = buildFolderStructure(files, jsonOutfitsFolder)
    end
end

local cachedChrxVehicles = nil
local cachedChrxOutfits = nil

local function refreshChrxVehicles()
    local files = FileMgr.FindFiles(chrxVehiclesFolder, ".json", true) 
    if not files or #files == 0 then
        cachedChrxVehicles = { folders = {}, files = {} }
    else
        cachedChrxVehicles = buildFolderStructure(files, chrxVehiclesFolder)
    end
end

local function refreshChrxOutfits()
    local files = FileMgr.FindFiles(chrxOutfitsFolder, ".json", true)
    if not files or #files == 0 then
        cachedChrxOutfits = { folders = {}, files = {} }
    else
        cachedChrxOutfits = buildFolderStructure(files, chrxOutfitsFolder)
    end
end

local function getChrxVehicles()
    if not cachedChrxVehicles then refreshChrxVehicles() end
    return cachedChrxVehicles
end

local function getChrxOutfits()
    if not cachedChrxOutfits then refreshChrxOutfits() end
    return cachedChrxOutfits
end

local function getJsonOutfits()
    if not cachedJsonOutfits then refreshJsonOutfits() end
    return cachedJsonOutfits
end

local function folderContainsMatch(folderData, filterText)
    if not filterText or filterText == "" then
        return true
    end

    for _, fileData in ipairs(folderData.files) do
        if string.find(fileData.name:lower(), filterText:lower()) then
            return true
        end
    end

    for _, subFolderData in pairs(folderData.folders) do
        if folderContainsMatch(subFolderData, filterText) then
            return true
        end
    end

    return false
end

local folderStates = {}
local preSearchFolderStates = nil
local memoryScannerState = {
    rangeStart = 0x0,
    rangeEnd = 0x300,
    results = {},
    lastScanTime = 0
}

-- Context menu state
local contextMenuFile = nil  -- { path = string, type = string ("vehicle"/"map"/"outfit") }
local contextMenuOpen = false
local contextKeyConsumed = false  -- Prevent multiple activations per key press
local mouseRightConsumed = false  -- Prevent multiple activations per right-click
local contextMenuPos = { x = 0, y = 0 }  -- Store position where menu was opened
local wasGuiOpen = false  -- Track GUI open state to detect reopens
local menuJustReopened = false  -- True only on the first render frame after menu reopens

-- Helper function to get !favs folder path based on item type and base folder
local function getFavsFolder(itemType, originalPath)
    local baseFolders = {
        vehicle = { xmlVehiclesFolder, iniVehiclesFolder, jsonVehiclesFolder, chrxVehiclesFolder },
        map = { xmlMapsFolder, jsonMapsFolder, jobMapsFolder },
        outfit = { xmlOutfitsFolder, jsonOutfitsFolder, chrxOutfitsFolder }
    }
    local folders = baseFolders[itemType]
    if not folders then return nil end
    
    local normalizedPath = originalPath:gsub("\\", "/")
    for _, baseFolder in ipairs(folders) do
        local normalizedBase = baseFolder:gsub("\\", "/")
        if normalizedPath:sub(1, #normalizedBase) == normalizedBase then
            return baseFolder .. "\\!favs"
        end
    end
    return nil
end

-- Helper function to get filename from path
local function getFilenameFromPath(path)
    return path:match("[^/\\]+$") or path
end

-- Helper function to refresh the appropriate cache based on file path
local function refreshCacheForFile(filePath, itemType)
    local normalizedPath = filePath:gsub("\\", "/")
    
    if itemType == "vehicle" then
        if normalizedPath:find(xmlVehiclesFolder:gsub("\\", "/"), 1, true) then
            refreshXmlVehicles()
        elseif normalizedPath:find(iniVehiclesFolder:gsub("\\", "/"), 1, true) then
            refreshIniVehicles()
        elseif normalizedPath:find(jsonVehiclesFolder:gsub("\\", "/"), 1, true) then
            refreshJsonVehicles()
        elseif normalizedPath:find(chrxVehiclesFolder:gsub("\\", "/"), 1, true) then
            refreshChrxVehicles()
        end
    elseif itemType == "map" then
        if normalizedPath:find(xmlMapsFolder:gsub("\\", "/"), 1, true) then
            refreshXmlMaps()
        elseif normalizedPath:find(jsonMapsFolder:gsub("\\", "/"), 1, true) then
            refreshJsonMaps()
        elseif normalizedPath:find(jobMapsFolder:gsub("\\", "/"), 1, true) then
            refreshJobMaps()
        end
    elseif itemType == "outfit" then
        if normalizedPath:find(xmlOutfitsFolder:gsub("\\", "/"), 1, true) then
            refreshXmlOutfits()
        elseif normalizedPath:find(jsonOutfitsFolder:gsub("\\", "/"), 1, true) then
            refreshJsonOutfits()
        elseif normalizedPath:find(chrxOutfitsFolder:gsub("\\", "/"), 1, true) then
            refreshChrxOutfits()
        end
    end
end

-- Move file to favorites folder
local function moveToFavorites(filePath, itemType)
    if not filePath or not FileMgr.DoesFileExist(filePath) then
        GUI.AddToast("BiggerScript", "File not found: " .. tostring(filePath), 3000, 0)
        return false
    end
    
    local favsFolder = getFavsFolder(itemType, filePath)
    if not favsFolder then
        GUI.AddToast("BiggerScript", "Could not determine favorites folder", 3000, 0)
        return false
    end
    
    -- Ensure !favs folder exists
    FileMgr.CreateDir(favsFolder)
    
    local filename = getFilenameFromPath(filePath)
    local destPath = favsFolder .. "\\" .. filename
    
    -- Read file content
    local content = FileMgr.ReadFileContent(filePath)
    if not content then
        GUI.AddToast("BiggerScript", "Failed to read file", 3000, 0)
        return false
    end
    
    -- Write to new location
    local success = FileMgr.WriteFileContent(destPath, content, false)
    if not success then
        GUI.AddToast("BiggerScript", "Failed to write to favorites folder", 3000, 0)
        return false
    end
    
    -- Delete original file
    FileMgr.DeleteFile(filePath)
    
    -- Refresh the appropriate caches
    refreshCacheForFile(filePath, itemType)
    refreshCacheForFile(destPath, itemType)
    
    GUI.AddToast("BiggerScript", "Moved to favorites: " .. filename, 3000, 0)
    return true
end

-- Delete a file
local function deleteFile(filePath, itemType)
    if not filePath or not FileMgr.DoesFileExist(filePath) then
        GUI.AddToast("BiggerScript", "File not found: " .. tostring(filePath), 3000, 0)
        return false
    end
    
    local filename = getFilenameFromPath(filePath)
    
    FileMgr.DeleteFile(filePath)
    
    -- Refresh the appropriate cache
    refreshCacheForFile(filePath, itemType)
    
    GUI.AddToast("BiggerScript", "Deleted: " .. filename, 3000, 0)
    return true
end

local function renderFolder(folderName, folderData, spawnFunction, filterText, path, searchId, itemType, hoverCallback)
    local currentPath = path and (path .. "/" .. folderName) or folderName

    if not folderContainsMatch(folderData, filterText) then
        return
    end

    local isSearching = filterText and #filterText > 0

    if isSearching and activeSearchField ~= searchId then
        preSearchFolderStates = {}
        for k, v in pairs(folderStates) do
            preSearchFolderStates[k] = v
        end
        activeSearchField = searchId
    elseif not isSearching and activeSearchField == searchId then
        if preSearchFolderStates then
            folderStates = preSearchFolderStates
        end
        preSearchFolderStates = nil
        activeSearchField = nil
    end

    local isOpen
    local treeLabel = folderName .. "##" .. currentPath
    if isSearching then
        ImGui.SetNextItemOpen(true, ImGuiCond.Always)
        isOpen = ImGui.TreeNode(treeLabel)
    else
        -- Only force-restore folder states on the first frame after menu reopens
        if menuJustReopened then
            local currentState = folderStates[currentPath]
            if currentState ~= nil then
                ImGui.SetNextItemOpen(currentState, ImGuiCond.Always)
            end
        end
        isOpen = ImGui.TreeNode(treeLabel)
        folderStates[currentPath] = isOpen
    end

    if isOpen then
        local subFolders = {}
        for subFolderName, subFolderData in pairs(folderData.folders) do table.insert(subFolders, {name = subFolderName, data = subFolderData}) end
        table.sort(subFolders, function(a, b) return a.name:lower() < b.name:lower() end)
        for _, subFolder in ipairs(subFolders) do renderFolder(subFolder.name, subFolder.data, spawnFunction, filterText, currentPath, searchId, itemType, hoverCallback) end

        local sortedFiles = {}
        for _, fileData in ipairs(folderData.files) do table.insert(sortedFiles, fileData) end
        table.sort(sortedFiles, function(a, b) return a.name:lower() < b.name:lower() end)
        for i, fileData in ipairs(sortedFiles) do
            if not filterText or filterText == "" or string.find(fileData.name:lower(), filterText:lower()) then
                if ImGui.Selectable(fileData.name) then
                    local selectedPath = fileData.fullPath
                    local norm = selectedPath:gsub("\\", "/")
                    local baseNorm = xmlVehiclesFolder:gsub("\\", "/")
                    if norm:sub(1, #baseNorm) == baseNorm then currentSelectedVehicleXml = selectedPath end
                    spawning.debug_print("[UI Debug] Selected XML vehicle:", selectedPath, "Index:", i-1)
                    local effectiveSpawnFunc = fileData.spawnFunc or spawnFunction
                    if effectiveSpawnFunc then
                        if effectiveSpawnFunc == iniAttackerSelectFunction then
                            effectiveSpawnFunc(selectedPath)
                        elseif effectiveSpawnFunc == spawning.spawnVehicleFromCHRX or effectiveSpawnFunc == spawning.spawnOutfitFromCHRX then
                            -- CHRX functions need the index parameter
                            Script.QueueJob(function() effectiveSpawnFunc(selectedPath, i-1) end)
                        else
                            -- Other spawn functions don't need the index
                            Script.QueueJob(function() effectiveSpawnFunc(selectedPath) end)
                        end
                    end
                end
                -- Press Delete key OR right-click while hovering to open context menu
                if ImGui.IsItemHovered() then
                    if hoverCallback then
                        hoverCallback({ path = fileData.fullPath, type = itemType })
                    end
                    -- Delete key (VK_DELETE = 46) or right mouse button (only when GUI is open)
                    local delPressed = Utils.IsKeyPressed(46) and not contextKeyConsumed and GUI.IsOpen()
                    local rightClick = ImGui.IsMouseDown(1) and not mouseRightConsumed and GUI.IsOpen()
                    if delPressed or rightClick then
                        -- Toggle: if clicking same file, close the menu
                        if contextMenuOpen and contextMenuFile and contextMenuFile.path == fileData.fullPath then
                            contextMenuOpen = false
                            contextMenuFile = nil
                        else
                            contextMenuFile = { path = fileData.fullPath, type = itemType }
                            contextMenuOpen = true
                            -- Store mouse position for frozen tooltip
                            contextMenuPos.x, contextMenuPos.y = ImGui.GetMousePos()
                        end
                        if delPressed then contextKeyConsumed = true end
                        if rightClick then mouseRightConsumed = true end
                    end
                end
            end
        end

        ImGui.Separator()
        ImGui.TreePop()
    end
end


local function renderFolderContents(folderData, spawnFunction, filterText, searchId, itemType, hoverCallback)
    if not folderData then return end

    local subFolders = {}
    for folderName, folderDataChild in pairs(folderData.folders) do
        table.insert(subFolders, {name = folderName, data = folderDataChild})
    end
    table.sort(subFolders, function(a, b) return a.name:lower() < b.name:lower() end)
    for _, sub in ipairs(subFolders) do
        renderFolder(sub.name, sub.data, spawnFunction, filterText, nil, searchId, itemType, hoverCallback)
    end


    local files = {}
    for _, f in ipairs(folderData.files) do table.insert(files, f) end
    table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
    for i, fileData in ipairs(files) do
        if not filterText or string.find(fileData.name:lower(), filterText:lower()) then
            if ImGui.Selectable(fileData.name) then
                local selectedPath = fileData.fullPath
                spawning.debug_print("[UI Debug] Selected " .. (itemType or "item") .. ":", selectedPath, "Index:", i-1)
                currentSelectedVehicleXml = selectedPath
                local effectiveSpawnFunc = fileData.spawnFunc or spawnFunction
                if effectiveSpawnFunc then
                    if effectiveSpawnFunc == spawning.spawnVehicleFromCHRX or effectiveSpawnFunc == spawning.spawnOutfitFromCHRX then
                        -- CHRX functions need the index parameter
                        Script.QueueJob(function() effectiveSpawnFunc(selectedPath, i-1) end)
                    else
                        -- Other spawn functions don't need the index
                        Script.QueueJob(function() effectiveSpawnFunc(selectedPath) end)
                    end
                end
            end
            -- Press Delete key OR right-click while hovering to open context menu
            if ImGui.IsItemHovered() then
                if hoverCallback then
                    hoverCallback({ path = fileData.fullPath, type = itemType })
                end
                -- Delete key (VK_DELETE = 46) or right mouse button (only when GUI is open)
                local delPressed = Utils.IsKeyPressed(46) and not contextKeyConsumed and GUI.IsOpen()
                local rightClick = ImGui.IsMouseDown(1) and not mouseRightConsumed and GUI.IsOpen()
                if delPressed or rightClick then
                    -- Toggle: if clicking same file, close the menu
                    if contextMenuOpen and contextMenuFile and contextMenuFile.path == fileData.fullPath then
                        contextMenuOpen = false
                        contextMenuFile = nil
                    else
                        contextMenuFile = { path = fileData.fullPath, type = itemType }
                        contextMenuOpen = true
                        -- Store mouse position for frozen tooltip
                        contextMenuPos.x, contextMenuPos.y = ImGui.GetMousePos()
                    end
                    if delPressed then contextKeyConsumed = true end
                    if rightClick then mouseRightConsumed = true end
                end
            end
        end
    end
end

-- Merge multiple folder structures into one, tagging files with their spawn function.
-- entries: list of {structure = folderData, spawnFunc = function}
local function mergeFolderStructures(entries)
    local merged = { folders = {}, files = {} }

    local function mergeInto(target, source, spawnFunc)
        -- Merge files
        for _, f in ipairs(source.files) do
            table.insert(target.files, { name = f.name, fullPath = f.fullPath, spawnFunc = spawnFunc or f.spawnFunc })
        end
        -- Merge folders (recursively combines same-named folders)
        for folderName, folderData in pairs(source.folders) do
            if not target.folders[folderName] then
                target.folders[folderName] = { folders = {}, files = {} }
            end
            mergeInto(target.folders[folderName], folderData, spawnFunc)
        end
    end

    for _, entry in ipairs(entries) do
        if entry.structure then
            mergeInto(merged, entry.structure, entry.spawnFunc)
        end
    end

    return merged
end

local robot_objects = {}
local entitys = { robot_weapon_left = {}, robot_weapon_right = {} }
local settings = {}

local moveableLegs = false

local legAnimationJob = nil

local spawnedProps = {} 

-- Persistent search variables
local searchXmlVehicles = ""
local searchIniVehicles = ""
local searchJsonVehicles = ""
local searchXmlVehicles = ""
local searchIniVehicles = ""
local searchJsonVehicles = ""
local searchChrxVehicles = ""
local searchXmlMaps = ""
local searchJsonMaps = ""
local searchJobMaps = ""
local searchXmlOutfits = ""
local searchXmlOutfits = ""
local searchJsonOutfits = ""
local searchChrxOutfits = ""
local searchGtaOutfits = ""
local gtaOutfitCache = nil
local gtaOutfitCacheChar = -1
local gtaOutfitCacheLoading = false

-- Job Browser state
local jobBrowserQueryType = 0 -- combo index
local jobBrowserContentType = 0 -- 0 = gta5mission, 1 = playlist
local jobBrowserResults = {} -- array of result entries
local jobBrowserPage = 0 -- current page (0-indexed)
local jobBrowserPerPage = 25
local jobBrowserTotalResults = 0
local jobBrowserSearching = false
local jobBrowserSaving = {} -- map of index -> true while saving
local jobBrowserPreviewFolder = biggerScriptRootPath .. "\\Jobs\\browser_cache"
local jobBrowserTexCache = {} -- map of cid -> "downloading"/"loading"/"failed"/"none"/textureId

-- Job Importer state
local jobImporterUrl = ""
local jobImporterStatus = ""
local jobImporterBusy = false
local jobImporterSaveImage = true
local jobImporterStatusColor = { 0.7, 0.7, 0.7, 1.0 }

local initialized = false

local function Initialize()
    local function ContinueInit()
        local status, result = pcall(require, "BiggerScript/natives/natives")
        if not status then
            GUI.AddToast("BiggerScript", "Failed to load natives: " .. tostring(result), 10000, 0)
        else
        end

        spawning.init({
            upsidedownmap_module = upsidedownmap,
            spawnerSettings = spawnerSettings,
            debug_print = spawning.debug_print,
            spawnedVehicles = spawnedVehicles,
            spawnedMaps = spawnedMaps,
            spawnedOutfits = spawnedOutfits,
            previewEntities = previewEntities,
            currentPreviewFile = currentPreviewFile,
            constructor_lib = constructor_lib,
            parse_ini_file = spawning.parse_ini_file,
            get_xml_element_content = spawning.get_xml_element_content,
            get_xml_element = spawning.get_xml_element,
            to_boolean = spawning.to_boolean,
            safe_tonumber = spawning.safe_tonumber,
            trim = spawning.trim,
            split_str = spawning.split_str,
            request_model_load = spawning.request_model_load,
            xmlVehiclesFolder = xmlVehiclesFolder,
            iniVehiclesFolder = iniVehiclesFolder,
            jsonVehiclesFolder = jsonVehiclesFolder,
            xmlMapsFolder = xmlMapsFolder,
            jsonMapsFolder = jsonMapsFolder,
            jobMapsFolder = jobMapsFolder,
            xmlOutfitsFolder = xmlOutfitsFolder,
            jsonOutfitsFolder = jsonOutfitsFolder,
            spawnedProps = spawnedProps,
            currentSelectedVehicleXml = currentSelectedVehicleXml,
            currentSelectedVehicleXml = currentSelectedVehicleXml,
            currentSelectedVehicleIni = currentSelectedVehicleIni,
            chrxVehiclesFolder = chrxVehiclesFolder,
            chrxOutfitsFolder = chrxOutfitsFolder
        })

        robot.init({
            spawnerSettings = spawnerSettings,
            debug_print = spawning.debug_print,
            spawnedVehicles = spawnedVehicles,
            moveableLegs = moveableLegs,
            legAnimationJob = legAnimationJob,
            robot_objects = robot_objects,
            request_model_load = spawning.request_model_load,
            safe_tonumber = spawning.safe_tonumber
        })

        vehicle_fly.init({
            spawnerSettings = spawnerSettings
        })

        spooner.init({
            spawnerSettings = spawnerSettings,
            rootPath = biggerScriptRootPath
        })

        iplloader.init({
            rootPath = biggerScriptRootPath
        })

        -- Register spooner's onPresent handler
        EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, function()
            if spooner.isEnabled() then
                spooner.onPresent()
                -- Render the crosshair for free cam mode
                spooner.renderCrosshair()
            end
            -- Always render sub-windows (they can be opened independently without full Spooner mode)
            spooner.renderGtaHashBrowserWindow()
            spooner.renderSubWindows()
        end)
        
        -- Register cleanup on unload
        EventMgr.RegisterHandler(eLuaEvent.ON_UNLOAD, function()
            if spooner then
                spooner.setEnabled(false)
            end

            -- Delete Photo Cache if enabled
            if spawnerSettings.deletePhotoCache then
                local cachePath = biggerScriptRootPath .. "\\SpoonerAssets\\gtahashru\\objects"
                local extensions = {".png", ".jpg", ".jpeg", ".bmp"}
                for _, ext in ipairs(extensions) do
                    local files = FileMgr.FindFiles(cachePath, ext, true)
                    if files then
                        for _, file in ipairs(files) do
                            FileMgr.DeleteFile(file)
                        end
                    end
                end
            end

            GUI.AddToast("BiggerScript", "Unloaded successfully", 3000, 0)
        end)

        initialized = true

        -- Check donors remotely
        if PaidTier.CheckRemote then
            PaidTier.CheckRemote()
        end

        -- Set active menu tab to LuaTab
        ClickGUI.SetActiveMenuTab(ClickTab.LuaTab)

        -- Start sentry loop
        Sentry.StartLoop()
        -- Start hoverboard tick loop
        Hoverboard.StartLoop()
    end

    -- Perform Asset Check/Update
    local config = asset_loader.getBiggerScriptAssetsConfig()

    -- Check if natives exist to decide if we should force a check or just notify
    local nativesPath = FileMgr.GetMenuRootPath() .. "\\Lua\\BiggerScript\\natives\\natives.lua"
    if not FileMgr.DoesFileExist(nativesPath) then
        GUI.AddToast("BiggerScript", "Missing Assets. Downloading...", 5000, 0)
    end

    asset_loader.checkAndUpdate(config, function(updateType, success, message, files)
        if not success then
            GUI.AddToast("BiggerScript Error", "Asset update failed: " .. tostring(message), 10000, 0)
            -- Try to continue anyway? If natives are missing, it will fail in ContinueInit
        end
        ContinueInit()
    end)
end

Script.QueueJob(Initialize)

local logoState = {
    textureId = nil,
    alpha = 0,
    fadeInDuration = 1500,
    displayDuration = 3000,
    fadeOutDuration = 1500,
    startTime = nil,
    active = false
}

local logoPath = biggerScriptRootPath .. "\\logo.png"
if FileMgr.DoesFileExist(logoPath) then
    logoState.textureId = Texture.LoadTexture(logoPath)
    if logoState.textureId and logoState.textureId ~= 0 then
        logoState.startTime = Time.GetEpocheMs()
        logoState.active = true
    end
end

local watermelonPath = biggerScriptRootPath .. "\\watermelon.png"
local watermelonTexture = nil
if FileMgr.DoesFileExist(watermelonPath) then
    watermelonTexture = Texture.LoadTexture(watermelonPath)
end

local function renderLogoFadeIn()
    if not logoState.active or not logoState.textureId or logoState.textureId == 0 then
        return
    end
    
    if not Texture.IsTextureValid(logoState.textureId) then
        return
    end
    
    local elapsed = Time.GetEpocheMs() - logoState.startTime
    local totalDuration = logoState.fadeInDuration + logoState.displayDuration + logoState.fadeOutDuration
    
    if elapsed < logoState.fadeInDuration then
        logoState.alpha = (elapsed / logoState.fadeInDuration) * 255
    elseif elapsed < (logoState.fadeInDuration + logoState.displayDuration) then
        logoState.alpha = 255
    elseif elapsed < totalDuration then
        local fadeOutElapsed = elapsed - (logoState.fadeInDuration + logoState.displayDuration)
        logoState.alpha = (1 - (fadeOutElapsed / logoState.fadeOutDuration)) * 255
    else
        logoState.active = false
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    local d3dTexture = Texture.GetTexture(logoState.textureId)
    local textureID = d3dTexture:GetCurrent()
    local texWidth = d3dTexture:GetWidth()
    local texHeight = d3dTexture:GetHeight()
    local maxSize = 900
    local scale = maxSize / math.max(texWidth, texHeight)
    local logoWidth = texWidth * scale
    local logoHeight = texHeight * scale
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    ImGui.BgAddImageRotated(textureID, centerX, centerY, logoWidth, logoHeight, 0.0, math.floor(logoState.alpha))
end

EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, renderLogoFadeIn)

-- Detect menu open/close globally (runs every frame)
EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, function()
    local guiOpen = GUI.IsOpen()
    if guiOpen and not wasGuiOpen then
        contextMenuOpen = false
        contextMenuFile = nil
        menuJustReopened = true  -- Signal renderFolder to restore saved states this frame
    elseif not guiOpen and wasGuiOpen then
        -- Force close context menu when main menu is closed
        contextMenuOpen = false
        contextMenuFile = nil
    end
    wasGuiOpen = guiOpen
end)

local function RenderCustomCheckboxFeature(label, featureName, hashStr, settingsTable, settingKey, tooltipText, onChange)
    local hash = Utils.Joaat(hashStr)
    if not FeatureMgr.GetFeature(hash) then
        local featDesc = tooltipText or ""
        local customFeat = FeatureMgr.AddFeature(hash, featureName, eFeatureType.Custom, featDesc, function(feat)
            local oldVal = settingsTable[settingKey]
            local displayName = feat:GetName(true)-- to get translated name
            settingsTable[settingKey] = ImGui.Checkbox(displayName, settingsTable[settingKey])
            if tooltipText and ImGui.IsItemHovered() then
                ImGui.SetTooltip(tooltipText)
            end
            if onChange and oldVal ~= settingsTable[settingKey] then
                onChange(settingsTable[settingKey])
            end
        end, false)
        if customFeat then
            customFeat:SetNoCallbackOnPress(true)
        end
    end
    ClickGUI.RenderFeature(hash)
end

local function RenderCustomButtonFeature(label, featureName, hashStr, colorScheme, tooltipText, onClick)
    local hash = Utils.Joaat(hashStr)
    if not FeatureMgr.GetFeature(hash) then
        local featDesc = tooltipText or ""
        local customFeat = FeatureMgr.AddFeature(hash, featureName, eFeatureType.Custom, featDesc, function(feat)
            local displayName = feat:GetName(true)
            
            -- Default Red color scheme if none provided
            local normal = {0.36, 0.016, 0.016, 1.0}
            local hover = {0.46, 0.06, 0.06, 1.0}
            local active = {0.26, 0.01, 0.01, 1.0}
            
            if colorScheme == "PurpleRed" then
                normal = {0.36, 0.016, 0.157, 1.0}
                hover = {0.46, 0.06, 0.22, 1.0}
                active = {0.26, 0.01, 0.10, 1.0}
            elseif colorScheme == "Green" then
                normal = {0.016, 0.36, 0.157, 1.0}
                hover = {0.06, 0.46, 0.22, 1.0}
                active = {0.01, 0.26, 0.10, 1.0}
            elseif colorScheme == "Blue" then
                normal = {0.016, 0.157, 0.36, 1.0}
                hover = {0.06, 0.22, 0.46, 1.0}
                active = {0.01, 0.10, 0.26, 1.0}
            elseif colorScheme == "DarkBlue" then
                normal = {0.1, 0.2, 0.4, 1.0}
                hover = {0.15, 0.3, 0.5, 1.0}
                active = {0.08, 0.18, 0.35, 1.0}
            elseif colorScheme == "LightBlue" then
                normal = {0.2, 0.6, 0.9, 1.0}
                hover = {0.3, 0.7, 1.0, 1.0}
                active = {0.15, 0.55, 0.85, 1.0}
            elseif colorScheme == "SpoonerRed" then
                normal = {0.5, 0.1, 0.1, 1.0}
                hover = {0.6, 0.15, 0.15, 1.0}
                active = {0.45, 0.08, 0.08, 1.0}
            elseif colorScheme == "SpoonerGreen" then
                normal = {0.1, 0.5, 0.15, 1.0}
                hover = {0.15, 0.6, 0.2, 1.0}
                active = {0.08, 0.45, 0.12, 1.0}
            elseif colorScheme == "LightPurple" then
                normal = {0.5, 0.3, 0.7, 1.0}
                hover = {0.6, 0.4, 0.8, 1.0}
                active = {0.4, 0.2, 0.6, 1.0}
            elseif colorScheme == "DarkPurple" then
                normal = {0.3, 0.15, 0.45, 1.0}
                hover = {0.4, 0.2, 0.55, 1.0}
                active = {0.25, 0.1, 0.35, 1.0}
            end

            ImGui.PushStyleColor(ImGuiCol.Button, normal[1], normal[2], normal[3], normal[4])
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, hover[1], hover[2], hover[3], hover[4])
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, active[1], active[2], active[3], active[4])
            
            if ImGui.Button(displayName .. "##btn" .. hashStr) then
                if onClick then
                    local success, err = pcall(onClick)
                    if not success then
                        print("[BiggerScript] Error in button callback: " .. tostring(err))
                    end
                end
            end
            ImGui.PopStyleColor(3)
            
            if tooltipText and ImGui.IsItemHovered() then
                ImGui.SetTooltip(tooltipText)
            end
        end, false)
        if customFeat then
            customFeat:SetNoCallbackOnPress(true)
        end
    end
    ClickGUI.RenderFeature(hash)
end

-- Helper for immediate-mode dynamic buttons that need to change text/color every frame
local function RenderDynamicButton(label, colorScheme, width, height, onClick)
    local normal, hover, active = {0.36, 0.016, 0.016, 1.0}, {0.46, 0.06, 0.06, 1.0}, {0.26, 0.01, 0.01, 1.0}
    
    if colorScheme == "PurpleRed" then
        normal = {0.36, 0.016, 0.157, 1.0}
        hover = {0.46, 0.06, 0.22, 1.0}
        active = {0.26, 0.01, 0.10, 1.0}
    elseif colorScheme == "Green" then
        normal = {0.016, 0.36, 0.157, 1.0}
        hover = {0.06, 0.46, 0.22, 1.0}
        active = {0.01, 0.26, 0.10, 1.0}
    elseif colorScheme == "Blue" then
        normal = {0.016, 0.157, 0.36, 1.0}
        hover = {0.06, 0.22, 0.46, 1.0}
        active = {0.01, 0.10, 0.26, 1.0}
    elseif colorScheme == "DarkBlue" then
        normal = {0.1, 0.2, 0.4, 1.0}
        hover = {0.15, 0.3, 0.5, 1.0}
        active = {0.08, 0.18, 0.35, 1.0}
    elseif colorScheme == "LightBlue" then
        normal = {0.2, 0.6, 0.9, 1.0}
        hover = {0.3, 0.7, 1.0, 1.0}
        active = {0.15, 0.55, 0.85, 1.0}
    elseif colorScheme == "SpoonerRed" then
        normal = {0.5, 0.1, 0.1, 1.0}
        hover = {0.6, 0.15, 0.15, 1.0}
        active = {0.45, 0.08, 0.08, 1.0}
    elseif colorScheme == "SpoonerGreen" then
        normal = {0.1, 0.5, 0.15, 1.0}
        hover = {0.15, 0.6, 0.2, 1.0}
        active = {0.08, 0.45, 0.12, 1.0}
    elseif colorScheme == "LightPurple" then
        normal = {0.5, 0.3, 0.7, 1.0}
        hover = {0.6, 0.4, 0.8, 1.0}
        active = {0.4, 0.2, 0.6, 1.0}
    elseif colorScheme == "DarkPurple" then
        normal = {0.3, 0.15, 0.45, 1.0}
        hover = {0.4, 0.2, 0.55, 1.0}
        active = {0.25, 0.1, 0.35, 1.0}
    end

    ImGui.PushStyleColor(ImGuiCol.Button, normal[1], normal[2], normal[3], normal[4])
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, hover[1], hover[2], hover[3], hover[4])
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, active[1], active[2], active[3], active[4])
    
    if ImGui.Button(label, width or 0, height or 0) then
        if onClick then 
            local success, err = pcall(onClick)
            if not success then
                print("[BiggerScript] Error in dynamic button: " .. tostring(err))
            end
        end
    end
    ImGui.PopStyleColor(3)
end

local function RenderStandardButtonFeature(featureName, hashStr, tooltipText, onClick) --since I put it custom imgui
    local hash = Utils.Joaat(hashStr)
    if not FeatureMgr.GetFeature(hash) then
        local featDesc = tooltipText or ""
        FeatureMgr.AddFeature(hash, featureName, eFeatureType.Button, featDesc, function(feat)
            if onClick then onClick() end
        end, false)
    end
    ClickGUI.RenderFeature(hash)
end

local function renderMenyooTab()
    if not initialized then
        ImGui.Text("Loading libraries... Please wait.")
        return
    end

    local hoveredFileThisFrame = nil
    local function hoverCallback(file)
        hoveredFileThisFrame = file
        -- Call context preview handler if enabled (context preview or photo preview)
        if (spawnerSettings.contextPreview or spawnerSettings.photoPreview) and spawning then
            spawning.handleContextPreviewHover(file)
        end
    end

    -- Reset consumed flags when keys released
    if not Utils.IsKeyPressed(46) then
        contextKeyConsumed = false
    end
    if not ImGui.IsMouseDown(1) then
        mouseRightConsumed = false
    end

    -- Render context menu as fixed-position window (styled like tooltip)
    if contextMenuOpen and contextMenuFile then
        local filename = getFilenameFromPath(contextMenuFile.path)
        local displayName = filename:gsub("%.xml$", ""):gsub("%.ini$", ""):gsub("%.json$", "")
        
        -- Position window at stored mouse position
        ImGui.SetNextWindowPos(contextMenuPos.x, contextMenuPos.y, ImGuiCond.Always)
        ImGui.SetNextWindowSize(0, 0)  -- Auto-size
        
        local windowFlags = ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.AlwaysAutoResize + ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoSavedSettings
        local windowOpen = ImGui.Begin("##FileContextMenu", true, windowFlags)
        if windowOpen then
            -- Header with file name (purple like Context Preview)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.SetWindowFontScale(1.1)
            ImGui.Text(displayName)
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()
            
            ImGui.Separator()
            ImGui.Spacing()
            
            -- Move to Favorites button (green)
            RenderCustomButtonFeature("Move to Favorites", "Move File to Favorites", "BiggerScript_File_Favorite", "Green", nil, function()
                moveToFavorites(contextMenuFile.path, contextMenuFile.type)
                contextMenuOpen = false
                contextMenuFile = nil
            end)
            
            -- Delete button (red)
            RenderCustomButtonFeature("Delete", "Delete File", "BiggerScript_File_Delete", nil, nil, function()
                deleteFile(contextMenuFile.path, contextMenuFile.type)
                contextMenuOpen = false
                contextMenuFile = nil
            end)
            
            ImGui.Spacing()
            
            -- Info text
            ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.5, 1.0)
            ImGui.Text("Right-click to close")
            ImGui.PopStyleColor()
            
            -- Close if right-clicking inside the window
            if ImGui.IsWindowHovered() and ImGui.IsMouseDown(1) and not mouseRightConsumed then
                contextMenuOpen = false
                contextMenuFile = nil
                mouseRightConsumed = true
            end
            
            ImGui.End()
        end
    end

    if ImGui.BeginTabBar("MenyooTabs") then
        -- SETTINGS TAB (first tab)
        if ImGui.BeginTabItem("Settings") then
            local columns = 2
            if ImGui.BeginTable("SettingsTable", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)

                -- Donor Info
                if ClickGUI.BeginCustomChildWindow("Donor Info") then
                    ImGui.Text("UID: " .. tostring(Cherax.GetUID()))
                    ImGui.SameLine()
                    if ImGui.Button("Clipboard##UID") then
                        Utils.SetClipBoardText(tostring(Cherax.GetUID()), "")
                    end

                    ImGui.Text("Tier: ")
                    ImGui.SameLine()

                    if PaidTier.IsPaid() then
                        ImGui.PushStyleColor(0, 0.0, 1.0, 0.0, 1.0)
                        ImGui.Text("Donor")
                        ImGui.PopStyleColor()
                    else
                        ImGui.Text("Free")
                    end

                    if not PaidTier.IsPaid() then
                        ImGui.Separator()
                        ImGui.Text("To Purchase Donor Join Discord")
                        ImGui.SameLine()
                        if ImGui.Button("Clipboard##Discord") then
                            Utils.SetClipBoardText("https://discord.gg/ctnbevsz54", "")
                        end
                    end

                    ClickGUI.EndCustomChildWindow()
                end

                -- Debug (moved from Special tab)
                if ClickGUI.BeginCustomChildWindow("Debug") then
                    RenderCustomCheckboxFeature("Debug Mode", "Debug Mode", "BiggerScript_Settings_DebugMode", spawnerSettings, "printToDebug")
                    RenderCustomCheckboxFeature("Spawn in Network v1 0 0 0 Vehicle", "Spawn v1 0 0 0 Vehicle", "BiggerScript_Settings_Spawn1000", spawnerSettings, "spawnIn000Vehicle")
                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.TableSetColumnIndex(1)

                -- Credits (moved from Special tab)
                if ClickGUI.BeginCustomChildWindow("Credits") then
                    ImGui.Text("Menyoo")
                    ImGui.Text("Constructor by hexarobi")
                    ImGui.Text("Lance Spooner")
                    ImGui.Text("Kek's Lua")
                    ImGui.Text("2take1script")
                    ImGui.Text("YimMenu")
                    ImGui.Text("anonymous50000")
                    ImGui.Text("Prisuhm")
                    ImGui.Text("Everyone who made and shared their creations")
                    ImGui.Text("Ai Free Usage")
                    ImGui.Text("Main Cherax Rabbi Whitewatermelon the Elder,\nSupreme Grand Rabbi and Head of Lua Developers,\nScion of the Chosen People of Israel,\nDirect Descendant of Abraham, Isaac, and Jacob,\nBearer of the Eternal Covenant and Holy Torah,\nGuardian of the Sacred Scripts and Lua Mishnah,\nMaster of the Cherax Talmud and Gemara,\nHeir to the Prophets and Kings of Judea,\nSon of the Tribe of Levi and Kohanim,\nWise Sage of the Synagogue of Exploits,\nHigh Priest of the Lua Temple in the Pixelated Promised Land,\nProtector of the Holy GitHub Ark,\nPatriarch of the Cherax Diaspora,\nKeeper of the 613 Mitzvot of Scripting,\nDefender of the Faith Against the Amalekites of Bad Code,\nScholar of the Zohar and Infinite Loops,\nRebbe of the Holy Shtetl of Cherax,\nOy Vey Master of the Chosen Exploits.")
                    ImGui.Text(" |")
                    ImGui.Text("V")
                    
                    if watermelonTexture and watermelonTexture ~= 0 and Texture.IsTextureValid(watermelonTexture) then
                        local d3dTex = Texture.GetTexture(watermelonTexture)
                        if d3dTex then
                            local texHandle = d3dTex:GetCurrent()
                            local cp_x, cp_y = ImGui.GetCursorScreenPos()
                            local imgSize = 160
                            ImGui.AddImage(texHandle, cp_x, cp_y, cp_x + imgSize, cp_y + imgSize)
                            ImGui.Dummy(0, imgSize) 
                        end
                    end
                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end


        -- VEHICLES TAB (combines XML, INI, JSON)
        if ImGui.BeginTabItem("Vehicles") then
            local columns = 2
            if ImGui.BeginTable("VehiclesTable", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Vehicle Settings") then
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()

                    RenderCustomCheckboxFeature("Separate Format Tabs", "Separate Format Tabs", "BiggerScript_Veh_SeparateFormatTabs", spawnerSettings, "separateFormatTabs", "Show XML/INI/JSON/CHRX as separate tabs instead of a combined list")
                    RenderCustomCheckboxFeature("Context Preview", "Context Preview", "BiggerScript_TestCustomFeature", spawnerSettings, "contextPreview", "Light Blue = Networkable (under 80)\nOrange = Not everything will network")
                    RenderCustomCheckboxFeature("Preview Vehicle", "Preview Vehicle", "BiggerScript_Veh_PreviewVehicle", spawnerSettings, "previewVehicle")
                    RenderCustomCheckboxFeature("Apply Attachments to Current Vehicle", "Apply Attachments", "BiggerScript_Veh_ApplyAttachments", spawnerSettings, "onlyApplyAttachments", "Instead of spawning a new vehicle, attach objects to the vehicle you're currently in")
                    RenderCustomCheckboxFeature("In Vehicle", "In Vehicle", "BiggerScript_Veh_InVehicle", spawnerSettings, "inVehicle")
                    RenderCustomCheckboxFeature("Spawn Aircraft In The Air", "Spawn Aircraft", "BiggerScript_Veh_SpawnAircraftInTheAir", spawnerSettings, "spawnPlaneInTheAir")
                    RenderCustomCheckboxFeature("Delete Old Vehicle", "Delete Old Vehicle", "BiggerScript_Veh_DeleteOldVehicle", spawnerSettings, "deleteOldVehicle")
                    RenderCustomCheckboxFeature("Vehicle God Mode", "Vehicle God Mode", "BiggerScript_Veh_VehicleGodMode", spawnerSettings, "vehicleGodMode")
                    RenderCustomCheckboxFeature("Vehicle Engine On", "Vehicle Engine On", "BiggerScript_Veh_VehicleEngineOn", spawnerSettings, "vehicleEngineOn")
                    RenderCustomCheckboxFeature("Radio Off", "Radio Off", "BiggerScript_Veh_RadioOff", spawnerSettings, "radioOff")
                    RenderCustomCheckboxFeature("Upgraded Vehicle", "Upgraded Vehicle", "BiggerScript_Veh_UpgradedVehicle", spawnerSettings, "upgradedVehicle")
                    RenderCustomCheckboxFeature("Random Color", "Random Color", "BiggerScript_Veh_RandomColor", spawnerSettings, "randomColor")
                    RenderCustomCheckboxFeature("Random Livery", "Random Livery", "BiggerScript_Veh_RandomLivery", spawnerSettings, "randomLivery")
                    
                    RenderCustomCheckboxFeature("Vehicle Fly", "Vehicle Fly", "BiggerScript_Veh_VehicleFly", spawnerSettings, "vehicleFly", nil, function(newVal)
                        vehicle_fly.toggle_vehicle_fly(newVal)
                    end)

                    ImGui.Spacing()

                    RenderCustomButtonFeature("Delete All Spawned Vehicles", "Delete All Vehicles", "BiggerScript_Veh_DeleteAll", "PurpleRed", "Delete all previously spawned vehicles and their attachments", function()
                        spawning.deleteAllSpawnedVehicles()
                    end)

                    ImGui.Spacing()

                    ClickGUI.EndCustomChildWindow()
                end

                -- Currently Loaded Vehicles (only show if there are spawned vehicles)
                if #spawnedVehicles > 0 then
                    if ClickGUI.BeginCustomChildWindow("Currently Loaded Vehicles") then
                        for i, vehicleData in ipairs(spawnedVehicles) do
                            local fileName = spawning.get_filename_from_path(vehicleData.filePath or "Unknown")
                            local displayName = fileName:gsub("%.xml$", ""):gsub("%.ini$", ""):gsub("%.json$", "")
                            ImGui.Text(displayName)
                            ImGui.SameLine()
                            
                            -- Green Drive button
                            RenderCustomButtonFeature("Drive##veh" .. i, "Drive", "BiggerScript_Veh_" .. i .. "_Drive", "Green", nil, function()
                                if vehicleData.vehicle and vehicleData.vehicle ~= 0 then
                                    spawning.driveVehicle(vehicleData.vehicle)
                                end
                            end)
                            
                            ImGui.SameLine()
                            
                            -- Red Delete button
                            RenderCustomButtonFeature("Delete##veh" .. i, "Delete", "BiggerScript_Veh_" .. i .. "_Delete", nil, nil, function()
                                spawning.deleteVehicleByIndex(i)
                            end)
                        end
                        ClickGUI.EndCustomChildWindow()
                    end
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("Vehicles") then
                    if spawnerSettings.separateFormatTabs then
                        -- Separate tabs per format
                        if ImGui.BeginTabBar("VehicleTypeTabs") then
                            if ImGui.BeginTabItem("XML") then
                                searchXmlVehicles, _ = ImGui.InputText("##searchXmlVehicles", searchXmlVehicles, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Veh_RefreshXML", nil, function()
                                    refreshXmlVehicles()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##xmlVehiclesList", 0, 475, false)
                                local xmlStructure = getXmlFiles()
                                renderFolderContents(xmlStructure, spawning.spawnVehicleFromXML, searchXmlVehicles, "xmlVehicles", "vehicle", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("INI") then
                                searchIniVehicles, _ = ImGui.InputText("##searchIniVehicles", searchIniVehicles, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Veh_RefreshINI", nil, function()
                                    refreshIniVehicles()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##iniVehiclesList", 0, 475, false)
                                local iniStructure = getIniVehicles()
                                renderFolderContents(iniStructure, spawning.spawnVehicleFromINI, searchIniVehicles, "iniVehicles", "vehicle", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("JSON") then
                                searchJsonVehicles, _ = ImGui.InputText("##searchJsonVehicles", searchJsonVehicles, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Veh_RefreshJSON", nil, function()
                                    refreshJsonVehicles()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##jsonVehiclesList", 0, 475, false)
                                local jsonStructure = getJsonVehicles()
                                renderFolderContents(jsonStructure, spawning.spawnVehicleFromJSON, searchJsonVehicles, "jsonVehicles", "vehicle", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("CHRX") then
                                searchChrxVehicles, _ = ImGui.InputText("##searchChrxVehicles", searchChrxVehicles, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Veh_RefreshCHRX", nil, function()
                                    refreshChrxVehicles()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##chrxVehiclesList", 0, 475, false)
                                local chrxStructure = getChrxVehicles()
                                renderFolderContents(chrxStructure, spawning.spawnVehicleFromCHRX, searchChrxVehicles, "chrxVehicles", "vehicle", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            ImGui.EndTabBar()
                        end
                    else
                        -- Combined list (all formats together)
                        searchXmlVehicles, _ = ImGui.InputText("##searchAllVehicles", searchXmlVehicles, 256)
                        ImGui.SameLine()
                        RenderStandardButtonFeature("Refresh", "BiggerScript_Veh_RefreshAll", nil, function()
                            refreshXmlVehicles()
                            refreshIniVehicles()
                            refreshJsonVehicles()
                            refreshChrxVehicles()
                        end)
                        ImGui.Spacing()

                        -- Scrollable child region for combined file list
                        ImGui.BeginChild("##allVehiclesList", 0, 475, false)
                        local mergedStructure = mergeFolderStructures({
                            { structure = getXmlFiles(), spawnFunc = spawning.spawnVehicleFromXML },
                            { structure = getIniVehicles(), spawnFunc = spawning.spawnVehicleFromINI },
                            { structure = getJsonVehicles(), spawnFunc = spawning.spawnVehicleFromJSON },
                            { structure = getChrxVehicles(), spawnFunc = spawning.spawnVehicleFromCHRX },
                        })
                        renderFolderContents(mergedStructure, nil, searchXmlVehicles, "allVehicles", "vehicle", hoverCallback)
                        ImGui.EndChild()
                    end
                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end

        -- MAPS TAB (combines XML, JSON)
        if ImGui.BeginTabItem("Maps") then
            local hasMarkers = false
            for _, map in ipairs(spawnedMaps) do
                if map.markers and #map.markers > 0 then
                    hasMarkers = true
                    break
                end
            end

            local columns = 2
            if ImGui.BeginTable("MapsTable", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Map Settings") then
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()

                    RenderCustomCheckboxFeature("Separate Format Tabs", "Separate Format Tabs", "BiggerScript_Maps_SeparateFormatTabs", spawnerSettings, "separateMapFormatTabs", "Show XML/JSON/Jobs as separate tabs instead of a combined list")
                    RenderCustomCheckboxFeature("Context Preview", "Map Context Preview", "BiggerScript_Maps_ContextPreview", spawnerSettings, "contextPreview", "Light Blue = Networkable (under 80)\nOrange = Not everything will network")
                    RenderCustomCheckboxFeature("Photo Preview", "Map Photo Preview", "BiggerScript_Maps_PhotoPreview", spawnerSettings, "photoPreview", "Show a preview image when hovering over maps (requires matching .png file)")
                    RenderCustomCheckboxFeature("Teleport to Map", "Teleport to Map", "BiggerScript_Maps_TeleportToMap", spawnerSettings, "teleportToMap", "Teleport to the map's reference coordinates when spawning (if available)")
                    RenderCustomCheckboxFeature("Spawn Map on Me", "Spawn Map on Me", "BiggerScript_Maps_SpawnMapOnMe", spawnerSettings, "spawnMapOnMe", "Spawn the map at your current position instead of its original coordinates")
                    RenderCustomCheckboxFeature("Network Maps V2", "Network Maps V2", "BiggerScript_Maps_NetworkV2", spawnerSettings, "networkMapsV2Enabled", "Uses a few networking natives to hopefully network better")
                    RenderCustomCheckboxFeature("Network Maps V1", "Network Maps V1", "BiggerScript_Maps_NetworkV1", spawnerSettings, "networkMapsV1Enabled", "Don't use seems broken after the latest update")
                    RenderCustomCheckboxFeature("Delete Old Map", "Delete Old Map", "BiggerScript_Maps_DeleteOldMap", spawnerSettings, "deleteOldMap", "Delete the previously spawned map when a new one is spawned")
                    RenderCustomCheckboxFeature("Clear Area Before Map Spawn", "Clear Area Before Map Spawn", "BiggerScript_Maps_ClearAreaBeforeSpawn", spawnerSettings, "clearAreaBeforeMapSpawn", "Clears area before spawning a map")

                    ImGui.Spacing()

                    RenderCustomButtonFeature("Delete All Spawned Maps", "Delete All Maps", "BiggerScript_Maps_DeleteAll", "PurpleRed", "Delete all previously spawned map objects", function()
                        spawning.deleteAllSpawnedMaps()
                    end)

                    ImGui.Spacing()

                    RenderCustomButtonFeature("Teleport All Players To Me", "Teleport All to Me", "BiggerScript_Maps_TeleportAll", "Green", nil, function()
                        FeatureMgr.GetFeatureByName("Teleport All To Me"):TriggerCallback()
                    end)

                    ImGui.Spacing()

                    RenderCustomButtonFeature("Clear Area", "Clear Area", "BiggerScript_Maps_ClearArea", "Blue", "Useful to clear the objects pool/network more map props", function()
                        FeatureMgr.GetFeatureByName("Clear Distance"):SetIntValue(1000)
                        FeatureMgr.TriggerFeatureCallback(53700821)-- needs hash cause has same name now cause it's a customfeature.
                    end)

                    if hasMarkers then
                        ImGui.Spacing()
                        ImGui.Separator()
                        ImGui.Text("Map Markers")
                        ImGui.Spacing()
                        for i, map in ipairs(spawnedMaps) do
                            if map.markers and #map.markers > 0 then
                                local mapName = spawning.get_filename_from_path(map.filePath)
                                ImGui.SetNextItemOpen(true, ImGuiCond.Once)
                                if ImGui.TreeNode(mapName .. " Markers##" .. i) then
                                    for j, marker in ipairs(map.markers) do
                                        if ImGui.Button("Marker " .. j .. "##" .. i .. "_" .. j) then
                                            local playerPed = PLAYER.PLAYER_PED_ID()
                                            if playerPed and playerPed ~= 0 then
                                                ENTITY.SET_ENTITY_COORDS(playerPed, marker.X, marker.Y, marker.Z, false, false, false, true)
                                            end
                                        end
                                        ImGui.SameLine()
                                        ImGui.Text("Pos: " .. string.format("%.1f, %.1f, %.1f", marker.X, marker.Y, marker.Z))
                                    end
                                    ImGui.TreePop()
                                end
                            end
                        end
                    end

                    ClickGUI.EndCustomChildWindow()
                end

                -- Currently Loaded Maps (only show if there are spawned maps)
                if #spawnedMaps > 0 then
                    if ClickGUI.BeginCustomChildWindow("Currently Loaded Maps") then
                        for i, mapData in ipairs(spawnedMaps) do
                            local fileName = spawning.get_filename_from_path(mapData.filePath or "Unknown")
                            local displayName = fileName:gsub("%.xml$", ""):gsub("%.ini$", ""):gsub("%.json$", "")
                            if #displayName > 15 then
                                displayName = displayName:sub(1, 15) .. "..."
                            end
                            ImGui.Text(displayName)
                            ImGui.SameLine()
                            
                            -- Green Teleport button
                            RenderCustomButtonFeature("Teleport##map" .. i, "Teleport", "BiggerScript_Map_" .. i .. "_TP", "Green", nil, function()
                                if mapData.refCoords then
                                    spawning.teleportToMapRefCoords(mapData.refCoords)
                                else
                                    -- Fallback: teleport to first entity if no refCoords
                                    if mapData.entities and mapData.entities[1] and ENTITY.DOES_ENTITY_EXIST(mapData.entities[1]) then
                                        local coords = ENTITY.GET_ENTITY_COORDS(mapData.entities[1], false)
                                        local playerPed = PLAYER.PLAYER_PED_ID()
                                        if playerPed and playerPed ~= 0 then
                                            ENTITY.SET_ENTITY_COORDS(playerPed, coords.x, coords.y, coords.z, false, false, false, true)
                                        end
                                    end
                                end
                            end)
                            
                            ImGui.SameLine()
                            
                            -- Blue Bring button (move map to player)
                            RenderCustomButtonFeature("Bring##map" .. i, "Bring", "BiggerScript_Map_" .. i .. "_Bring", "Blue", nil, function()
                                spawning.bringMapToPlayer(i)
                            end)
                            
                            ImGui.SameLine()
                            
                            -- Red Delete button
                            RenderCustomButtonFeature("Delete##map" .. i, "Delete", "BiggerScript_Map_" .. i .. "_Delete", nil, nil, function()
                                spawning.deleteMapByIndex(i)
                            end)
                        end
                        ClickGUI.EndCustomChildWindow()
                    end
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("Maps") then
                    if spawnerSettings.separateMapFormatTabs then
                        -- Separate tabs per format
                        if ImGui.BeginTabBar("MapTypeTabs") then
                            if ImGui.BeginTabItem("XML") then
                                searchXmlMaps, _ = ImGui.InputText("##searchXmlMaps", searchXmlMaps, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Maps_RefreshXML", nil, function()
                                    refreshXmlMaps()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##xmlMapsList", 0, 475, false)
                                local xmlStructure = getXmlMaps()
                                renderFolderContents(xmlStructure, spawning.spawnMapFromXML, searchXmlMaps, "xmlMaps", "map", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("JSON") then
                                searchJsonMaps, _ = ImGui.InputText("##searchJsonMaps", searchJsonMaps, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Maps_RefreshJSON", nil, function()
                                    refreshJsonMaps()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##jsonMapsList", 0, 475, false)
                                local jsonStructure = getJsonMaps()
                                renderFolderContents(jsonStructure, spawning.spawnMapFromJSON, searchJsonMaps, "jsonMaps", "map", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("Jobs") then
                                searchJobMaps, _ = ImGui.InputText("##searchJobMaps", searchJobMaps, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Maps_RefreshJobs", nil, function()
                                    refreshJobMaps()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##jobMapsList", 0, 475, false)
                                local jobStructure = getJobMaps()
                                renderFolderContents(jobStructure, spawning.spawnMapFromJobJSON, searchJobMaps, "jobMaps", "map", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            ImGui.EndTabBar()
                        end
                    else
                        -- Combined list (all map formats together, merged folders)
                        searchXmlMaps, _ = ImGui.InputText("##searchAllMaps", searchXmlMaps, 256)
                        ImGui.SameLine()
                        RenderStandardButtonFeature("Refresh", "BiggerScript_Maps_RefreshAll", nil, function()
                            refreshXmlMaps()
                            refreshJsonMaps()
                            refreshJobMaps()
                        end)
                        ImGui.Spacing()

                        -- Scrollable child region for combined file list
                        ImGui.BeginChild("##allMapsList", 0, 475, false)
                        local mergedStructure = mergeFolderStructures({
                            { structure = getXmlMaps(), spawnFunc = spawning.spawnMapFromXML },
                            { structure = getJsonMaps(), spawnFunc = spawning.spawnMapFromJSON },
                            { structure = getJobMaps(), spawnFunc = spawning.spawnMapFromJobJSON },
                        })
                        renderFolderContents(mergedStructure, nil, searchXmlMaps, "allMaps", "map", hoverCallback)
                        ImGui.EndChild()
                    end
                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end

        -- OUTFITS TAB (combines XML, JSON)
        if ImGui.BeginTabItem("Outfits") then
            local columns = 2
            if ImGui.BeginTable("OutfitsTable", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Outfit Settings") then
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()

                    RenderCustomCheckboxFeature("Separate Format Tabs", "Separate Format Tabs", "BiggerScript_Outfits_SeparateFormatTabs", spawnerSettings, "separateOutfitFormatTabs", "Show XML/JSON/CHRX as separate tabs instead of a combined list")
                    RenderCustomCheckboxFeature("Context Preview", "Outfit Context Preview", "BiggerScript_Outfits_ContextPreview", spawnerSettings, "contextPreview", "Light Blue = Networkable (under 80)\nOrange = Not everything will network")
                    RenderCustomCheckboxFeature("Preview Outfit", "Preview Outfit", "BiggerScript_Outfits_PreviewOutfit", spawnerSettings, "previewOutfit")
                    RenderCustomCheckboxFeature("Only Apply Attachments", "Outfit Apply Attachments", "BiggerScript_Outfits_ApplyAttachments", spawnerSettings, "onlyApplyAttachments", "May Break Positioning")
                    RenderCustomCheckboxFeature("Delete Last Outfit Attachments", "Delete Last Outfit Attachments", "BiggerScript_Outfits_DeleteLastAttachments", spawnerSettings, "deleteLastOutfitAttachments")
                    
                    ImGui.Spacing()
                    
                    -- Third Person FOV Toggle and Slider
                    local thirdPersonFOVFeature = FeatureMgr.GetFeatureByName("Third Person FOV")
                    local thirdPersonAimFOVFeature = FeatureMgr.GetFeatureByName("Third Person Aim FOV")
                    
                    if thirdPersonFOVFeature and thirdPersonAimFOVFeature then
                        -- Initialize the setting if it doesn't exist
                        if spawnerSettings.thirdPersonFOVEnabled == nil then
                            spawnerSettings.thirdPersonFOVEnabled = false
                        end
                        
                        -- Toggle to enable/disable FOV
                        RenderCustomCheckboxFeature("FOV Changer", "Third Person FOV Toggle", "BiggerScript_Outfits_FOVChanger", spawnerSettings, "thirdPersonFOVEnabled", nil, function(newVal)
                            -- Toggle the Cherax menu feature
                            thirdPersonFOVFeature:Toggle()
                            
                            if newVal then
                                -- Get current value or default to 50
                                local currentValue = spawnerSettings.thirdPersonFOVValue or 50
                                thirdPersonFOVFeature:SetIntValue(currentValue)
                                thirdPersonAimFOVFeature:SetIntValue(currentValue)
                            else
                                -- Reset to 0 when disabled
                                thirdPersonFOVFeature:SetIntValue(0)
                                thirdPersonAimFOVFeature:SetIntValue(0)
                            end
                        end)
                        
                        -- Single slider that controls both FOV values
                        if spawnerSettings.thirdPersonFOVEnabled then
                            -- Initialize the value if it doesn't exist
                            if spawnerSettings.thirdPersonFOVValue == nil then
                                spawnerSettings.thirdPersonFOVValue = 50
                            end
                            
                            local newFOV, changed = ImGui.SliderInt("FOV Value", spawnerSettings.thirdPersonFOVValue, 0, 130)
                            if changed then
                                spawnerSettings.thirdPersonFOVValue = newFOV
                                thirdPersonFOVFeature:SetIntValue(newFOV)
                                thirdPersonAimFOVFeature:SetIntValue(newFOV)
                            end
                        end
                    end
                    
                    ImGui.Spacing()

                    RenderCustomButtonFeature("Delete All Spawned Outfits", "Delete All Outfits", "BiggerScript_Outfits_DeleteAll", "PurpleRed", "Delete all previously spawned outfit attachments", function()
                        spawning.deleteAllSpawnedOutfits()
                    end)

                    ImGui.Spacing()


                    -- Print Outfit List button
                    RenderCustomButtonFeature("Print Outfit List", "Print Outfit List", "BiggerScript_Outfits_PrintList", "Blue", "Query and print all outfit names via GTA5 shop ped natives", function()
                        Script.QueueJob(function()
                            local charNames = { [0]="Michael", [1]="Franklin", [2]="Trevor", [3]="MP Male", [4]="MP Female" }
                            for charType = 0, 4 do
                                local numOutfits = FILES.SETUP_SHOP_PED_OUTFIT_QUERY(charType, false)
                                Logger.Log(eLogColor.GREEN, "[Outfits]", charNames[charType] .. " -> " .. tostring(numOutfits) .. " outfits")
                                if numOutfits and numOutfits > 0 then
                                    for i = 0, numOutfits - 1 do
                                        -- Outfit struct: 7 fields * 8 bytes each + 16 bytes padding
                                        local blob = string.rep('\0\0\0\0\0\0\0\0', 7 + 16)
                                        FILES.GET_SHOP_PED_QUERY_OUTFIT(i, blob)
                                        -- Parse fields from binary blob (little-endian int32, 8-byte strides)
                                        local hash      = string.unpack('<i4', blob, 9)
                                        local price     = string.unpack('<i4', blob, 17)
                                        local totalProps = string.unpack('<i4', blob, 25)
                                        local totalComponents = string.unpack('<i4', blob, 33)
                                        local gxt       = string.unpack('z',   blob, 57)
                                        -- Resolve GXT key to human-readable name
                                        local displayName = ""
                                        if gxt and gxt ~= "" then
                                            local resolved = HUD.GET_FILENAME_FOR_AUDIO_CONVERSATION(gxt)
                                            displayName = (resolved and resolved ~= "" and resolved ~= "NULL") and resolved or gxt
                                        else
                                            displayName = string.format("0x%X", hash)
                                        end
                                        Logger.Log(eLogColor.WHITE, "[Outfits]",
                                            string.format("  [%d] %s (GXT=%s  Hash=0x%X  Price=$%d  Props=%d  Comps=%d)",
                                                i, displayName, (gxt ~= "" and gxt or "?"), hash, price, totalProps, totalComponents))
                                    end
                                end
                            end
                            Logger.Log(eLogColor.GREEN, "[Outfits]", "Done printing outfit list.")
                        end)
                    end)

                    ImGui.Spacing()

                    ClickGUI.EndCustomChildWindow()
                    ImGui.Text("Cherax limits the attachments you can have")
                    ImGui.Text("on your character to 20")
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("Outfits") then
                    if spawnerSettings.separateOutfitFormatTabs then
                        -- Separate tabs per format
                        if ImGui.BeginTabBar("OutfitTypeTabs") then
                            if ImGui.BeginTabItem("XML") then
                                searchXmlOutfits, _ = ImGui.InputText("##searchXmlOutfits", searchXmlOutfits, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Outfits_RefreshXML", nil, function()
                                    refreshXmlOutfits()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##xmlOutfitsList", 0, 475, false)
                                local xmlStructure = getXmlOutfits()
                                renderFolderContents(xmlStructure, spawning.spawnOutfitFromXML, searchXmlOutfits, "xmlOutfits", "outfit", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("JSON") then
                                searchJsonOutfits, _ = ImGui.InputText("##searchJsonOutfits", searchJsonOutfits, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Outfits_RefreshJSON", nil, function()
                                    refreshJsonOutfits()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##jsonOutfitsList", 0, 475, false)
                                local jsonStructure = getJsonOutfits()
                                renderFolderContents(jsonStructure, spawning.spawnOutfitFromJSON, searchJsonOutfits, "jsonOutfits", "outfit", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("CHRX") then
                                searchChrxOutfits, _ = ImGui.InputText("##searchChrxOutfits", searchChrxOutfits, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Outfits_RefreshCHRX", nil, function()
                                    refreshChrxOutfits()
                                end)
                                ImGui.Spacing()

                                -- Scrollable child region for file list
                                ImGui.BeginChild("##chrxOutfitsList", 0, 475, false)
                                local chrxStructure = getChrxOutfits()
                                renderFolderContents(chrxStructure, spawning.spawnOutfitFromCHRX, searchChrxOutfits, "chrxOutfits", "outfit", hoverCallback)
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            if ImGui.BeginTabItem("GTA") then
                                -- Detect current character type from player ped model
                                local ped = PLAYER.PLAYER_PED_ID()
                                local modelHash = ENTITY.GET_ENTITY_MODEL(ped)
                                local charType = -1
                                local charName = "Unknown"
                                
                                if modelHash == Utils.Joaat("Player_Zero") or modelHash == Utils.sJoaat("Player_Zero") then charType = 0; charName = "Michael"
                                elseif modelHash == Utils.Joaat("Player_One") or modelHash == Utils.sJoaat("Player_One") then charType = 1; charName = "Franklin"
                                elseif modelHash == Utils.Joaat("Player_Two") or modelHash == Utils.sJoaat("Player_Two") then charType = 2; charName = "Trevor"
                                elseif modelHash == Utils.Joaat("MP_M_Freemode_01") or modelHash == Utils.sJoaat("MP_M_Freemode_01") then charType = 3; charName = "MP Male"
                                elseif modelHash == Utils.Joaat("MP_F_Freemode_01") or modelHash == Utils.sJoaat("MP_F_Freemode_01") then charType = 4; charName = "MP Female"
                                end

                                -- Invalidate cache when character changes
                                if charType ~= gtaOutfitCacheChar then
                                    gtaOutfitCache = nil
                                    gtaOutfitCacheChar = charType
                                    gtaOutfitCacheLoading = false
                                end

                                -- Kick off async cache population once
                                if gtaOutfitCache == nil and not gtaOutfitCacheLoading and charType >= 0 then
                                    gtaOutfitCacheLoading = true
                                    local capturedChar = charType
                                    local capturedName = charName
                                    Script.QueueJob(function()
                                        local cache = {}
                                        local numOutfits = FILES.SETUP_SHOP_PED_OUTFIT_QUERY(capturedChar, false)
                                        if numOutfits and numOutfits > 0 then
                                            for i = 0, numOutfits - 1 do
                                                local blob = string.rep('\0\0\0\0\0\0\0\0', 7 + 16)
                                                FILES.GET_SHOP_PED_QUERY_OUTFIT(i, blob)
                                                local hash           = string.unpack('<i4', blob, 9)
                                                local price          = string.unpack('<i4', blob, 17)
                                                local totalProps     = string.unpack('<i4', blob, 25)
                                                local totalComponents = string.unpack('<i4', blob, 33)
                                                local gxt            = string.unpack('z',   blob, 57)
                                                local displayName = gxt
                                                if gxt and gxt ~= "" then
                                                    local resolved = HUD.GET_FILENAME_FOR_AUDIO_CONVERSATION(gxt)
                                                    if resolved and resolved ~= "" and resolved ~= "NULL" then
                                                        displayName = resolved
                                                    end
                                                end
                                                if not displayName or displayName == "" then
                                                    displayName = string.format("Outfit %d", i)
                                                end
                                                table.insert(cache, {
                                                    index = i,
                                                    hash = hash,
                                                    gxt = gxt,
                                                    name = displayName,
                                                    totalComponents = totalComponents,
                                                    totalProps = totalProps,
                                                })
                                            end
                                        end
                                        gtaOutfitCache = cache
                                        gtaOutfitCacheLoading = false
                                    end)
                                end

                                -- Header + search bar
                                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.8, 1.0, 1.0)
                                ImGui.Text(charType >= 0 and ("Character: " .. charName) or "Unsupported ped model")
                                ImGui.PopStyleColor()
                                searchGtaOutfits, _ = ImGui.InputText("##searchGtaOutfits", searchGtaOutfits, 256)
                                ImGui.SameLine()
                                RenderStandardButtonFeature("Refresh", "BiggerScript_Outfits_RefreshGTA", nil, function()
                                    gtaOutfitCache = nil
                                    gtaOutfitCacheChar = -1
                                    gtaOutfitCacheLoading = false
                                end)
                                ImGui.Spacing()

                                -- Outfit list
                                ImGui.BeginChild("##gtaOutfitsList", 0, 445, false)
                                if charType < 0 then
                                    ImGui.TextDisabled("No outfits found — unsupported ped model")
                                elseif gtaOutfitCacheLoading then
                                    ImGui.TextDisabled("Loading outfits...")
                                elseif gtaOutfitCache and #gtaOutfitCache > 0 then
                                    local search = searchGtaOutfits:lower()
                                    for _, outfit in ipairs(gtaOutfitCache) do
                                        local show = search == "" or
                                            string.find(outfit.name:lower(), search, 1, true) or
                                            (outfit.gxt and string.find(outfit.gxt:lower(), search, 1, true))
                                        if show then
                                            if ImGui.Selectable(outfit.name .. "##gta_outfit_" .. outfit.index, false) then
                                                local outfitHash     = outfit.hash
                                                local numComps       = outfit.totalComponents
                                                local numProps       = outfit.totalProps
                                                local outfitName     = outfit.name
                                                Script.QueueJob(function()
                                                    local applyPed = PLAYER.PLAYER_PED_ID()
                                                    -- Reset to default clothes
                                                    PED.SET_PED_DEFAULT_COMPONENT_VARIATION(applyPed)
                                                    
                                                    -- Explicitly clear all props (hats, glasses, etc)
                                                    for i = 0, 10 do
                                                        PED.CLEAR_PED_PROP(applyPed, i)
                                                    end
                                                    
                                                    -- Explicitly zero out accessory/overlay components 
                                                    -- (Mask, Parachute, Accessories, Undershirt, Armor, Decals)
                                                    -- to prevent leftover clipping from previous outfits
                                                    local clearComps = {1, 5, 7, 8, 9, 10}
                                                    for _, c in ipairs(clearComps) do
                                                        PED.SET_PED_COMPONENT_VARIATION(applyPed, c, 0, 0, 0)
                                                    end

                                                    -- Apply component variations
                                                    for ci = 0, numComps - 1 do
                                                        local vb = string.rep('\0\0\0\0\0\0\0\0', 3 + 16)
                                                        FILES.GET_SHOP_PED_OUTFIT_COMPONENT_VARIANT(outfitHash, ci, vb)
                                                        local compHash = string.unpack('<i4', vb, 1)
                                                        local compType = string.unpack('<i4', vb, 17)
                                                        local cb = string.rep('\0\0\0\0\0\0\0\0', 9 + 16)
                                                        FILES.GET_SHOP_PED_COMPONENT(compHash, cb)
                                                        local drawable = string.unpack('<i4', cb, 25)
                                                        local texture  = string.unpack('<i4', cb, 33)
                                                        PED.SET_PED_COMPONENT_VARIATION(applyPed, compType, drawable, texture, 0)
                                                    end
                                                    -- Apply prop variations
                                                    for pi = 0, numProps - 1 do
                                                        local vb = string.rep('\0\0\0\0\0\0\0\0', 3 + 16)
                                                        FILES.GET_SHOP_PED_OUTFIT_PROP_VARIANT(outfitHash, pi, vb)
                                                        local propHash   = string.unpack('<i4', vb, 1)
                                                        local anchorPoint = string.unpack('<i4', vb, 17)
                                                        local pb = string.rep('\0\0\0\0\0\0\0\0', 9 + 16)
                                                        FILES.GET_SHOP_PED_PROP(propHash, pb)
                                                        local drawable = string.unpack('<i4', pb, 25)
                                                        local texture  = string.unpack('<i4', pb, 33)
                                                        PED.SET_PED_PROP_INDEX(applyPed, anchorPoint, drawable, texture, true)
                                                    end
                                                    GUI.AddToast("BiggerScript", "Applied: " .. outfitName, 3000, 0)
                                                end)
                                            end
                                        end
                                    end
                                elseif gtaOutfitCache then
                                    ImGui.TextDisabled("No outfits found")
                                end
                                ImGui.EndChild()
                                ImGui.EndTabItem()
                            end

                            ImGui.EndTabBar()
                        end
                    else
                        -- Combined list (all outfit formats together, merged folders)
                        searchXmlOutfits, _ = ImGui.InputText("##searchAllOutfits", searchXmlOutfits, 256)
                        ImGui.SameLine()
                        RenderStandardButtonFeature("Refresh", "BiggerScript_Outfits_RefreshAll", nil, function()
                            refreshXmlOutfits()
                            refreshJsonOutfits()
                            refreshChrxOutfits()
                        end)
                        ImGui.Spacing()

                        -- Scrollable child region for combined file list
                        ImGui.BeginChild("##allOutfitsList", 0, 475, false)
                        local mergedStructure = mergeFolderStructures({
                            { structure = getXmlOutfits(), spawnFunc = spawning.spawnOutfitFromXML },
                            { structure = getJsonOutfits(), spawnFunc = spawning.spawnOutfitFromJSON },
                            { structure = getChrxOutfits(), spawnFunc = spawning.spawnOutfitFromCHRX },
                        })
                        renderFolderContents(mergedStructure, nil, searchXmlOutfits, "allOutfits", "outfit", hoverCallback)
                        ImGui.EndChild()
                    end
                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end

        -- IPL LOADER TAB
        if ImGui.BeginTabItem("IPL Loader") then
            local columns = 2
            if ImGui.BeginTable("IPLTable", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                
                -- IPL Settings (left column)
                if ClickGUI.BeginCustomChildWindow("IPL Settings") then
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()
                    
                    RenderCustomCheckboxFeature("Unload Last IPL", "Unload Last IPL", "BiggerScript_IPL_UnloadLast", spawnerSettings, "unloadLastIPL", "Unload the previously loaded IPL group when loading a new one")
                    
                    ImGui.Spacing()
                    
                    RenderCustomButtonFeature("Unload All IPLs", "Unload All IPLs", "BiggerScript_IPL_UnloadAll", "PurpleRed", "Unload all currently loaded IPL groups", function()
                        iplloader.unloadAllGroups()
                    end)
                    
                    ImGui.Spacing()
                    ClickGUI.EndCustomChildWindow()
                end
                ImGui.Text("IPLS do not sync/network")
                -- Currently Loaded IPLs (only show if there are loaded groups)
                local loadedIPLGroups = iplloader.getLoadedGroups()
                if #loadedIPLGroups > 0 then
                    if ClickGUI.BeginCustomChildWindow("Currently Loaded IPLs") then
                        for i, groupData in ipairs(loadedIPLGroups) do
                            -- Use TreeNode to make it expandable
                            local nodeOpen = ImGui.TreeNode(groupData.displayName .. " (" .. groupData.iplCount .. ")##loaded" .. i)
                            
                            -- Main teleport and unload buttons on the same line
                            ImGui.SameLine()
                            
                            -- Green Teleport button
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.36, 0.157, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.46, 0.22, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.26, 0.10, 1.0)
                            if ImGui.Button("TP##ipl" .. i) then
                                iplloader.teleportToGroup(groupData.key)
                            end
                            ImGui.PopStyleColor(3)
                            
                            ImGui.SameLine()
                            
                            -- Red Unload button
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.016, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.06, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.01, 1.0)
                            if ImGui.Button("Unload##ipl" .. i) then
                                iplloader.queueUnloadGroup(groupData.key)
                            end
                            ImGui.PopStyleColor(3)
                            
                            -- Show individual IPL teleports when expanded
                            if nodeOpen then
                                if groupData.ipls and #groupData.ipls > 0 then
                                    for j, iplData in ipairs(groupData.ipls) do
                                        ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.3, 0.5, 1.0)
                                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.4, 0.6, 1.0)
                                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.25, 0.45, 1.0)
                                        if ImGui.Button(iplData.displayName .. "##ipltp" .. i .. "_" .. j, -1, 0) then
                                            iplloader.teleportToPosition(iplData.position)
                                        end
                                        ImGui.PopStyleColor(3)
                                    end
                                else
                                    ImGui.TextDisabled("No teleport locations available")
                                end
                                ImGui.TreePop()
                            end
                        end
                        ClickGUI.EndCustomChildWindow()
                    end
                end
                
                -- Right column: IPL List
                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("IPL Groups") then
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()
                    
                    -- Filter Dropdown (includes Main + DLCs)
                    ImGui.Text("Filter:")
                    ImGui.SameLine()
                    local dlcNames = iplloader.getDlcNames()
                    local currentFilter = iplloader.getDlcFilter()
                    local previewText = currentFilter or "Main"
                    
                    local comboOpen = ImGui.BeginCombo("##iplFilter", previewText)
                    if comboOpen then
                        -- "Main" option (curated locations)
                        if ImGui.Selectable("Main##filterMain", currentFilter == nil) then
                            if currentFilter ~= nil then
                                iplloader.setDlcFilter(nil)
                            end
                        end
                        
                        ImGui.Separator()
                        
                        -- "All DLCs" option
                        if ImGui.Selectable("All DLCs##filterAll", currentFilter == "__all__") then
                            if currentFilter ~= "__all__" then
                                iplloader.setDlcFilter("__all__")
                            end
                        end
                        
                        -- DLC options
                        for idx, dlcName in ipairs(dlcNames) do
                            local isSelected = (currentFilter == dlcName)
                            if ImGui.Selectable(dlcName .. "##dlc" .. idx, isSelected) then
                                if currentFilter ~= dlcName then
                                    iplloader.setDlcFilter(dlcName)
                                end
                            end
                        end
                        ImGui.EndCombo()
                    end
                    
                    ImGui.Spacing()
                    ImGui.Separator()
                    ImGui.Spacing()
                    
                    -- Content based on filter
                    if currentFilter == nil then
                        -- Main: Show curated locations
                        local curatedLocs = iplloader.curatedLocations
                        for idx, loc in ipairs(curatedLocs) do
                            local isLoaded = iplloader.isCuratedLocationLoaded(idx)
                            
                            if isLoaded then
                                -- Green when loaded
                                ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.5, 0.15, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.6, 0.2, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.45, 0.12, 1.0)
                            else
                                -- Purple for curated
                                ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.1, 0.4, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.15, 0.5, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.08, 0.35, 1.0)
                            end
                            
                            if ImGui.Button(loc.name .. "##curated" .. idx, -1, 0) then
                                if isLoaded then
                                    iplloader.queueUnloadCurated(idx)
                                else
                                    iplloader.loadCuratedLocation(idx, true)
                                end
                            end
                            ImGui.PopStyleColor(3)
                            
                            if ImGui.IsItemHovered() then
                                ImGui.SetTooltip(loc.description)
                            end
                        end
                        
                        -- Separator before main groups
                        ImGui.Spacing()
                        ImGui.Separator()
                        ImGui.Spacing()
                        
                        -- Main groups: All groups with capital letter names
                        local mainGroups = iplloader.getMainGroups()
                        for _, group in ipairs(mainGroups) do
                            local isLoaded = iplloader.isGroupLoaded(group.key)
                            
                            if isLoaded then
                                -- Green when loaded
                                ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.5, 0.15, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.6, 0.2, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.45, 0.12, 1.0)
                            else
                                -- Default dark blue when not loaded
                                ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.2, 0.4, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.3, 0.5, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.18, 0.35, 1.0)
                            end
                            
                            if ImGui.Button(group.display .. "##main" .. group.key, -1, 0) then
                                iplloader.toggleGroup(group.key, spawnerSettings.unloadLastIPL)
                            end
                            ImGui.PopStyleColor(3)
                        end
                    else
                        -- DLC filter: Show group names
                        local groupNames = iplloader.getGroupNames()
                        
                        if #groupNames == 0 then
                            ImGui.TextDisabled("No groups found for this filter")
                        else
                            for _, group in ipairs(groupNames) do
                                local isLoaded = iplloader.isGroupLoaded(group.key)
                                
                                if isLoaded then
                                    -- Green when loaded
                                    ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.5, 0.15, 1.0)
                                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.6, 0.2, 1.0)
                                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.45, 0.12, 1.0)
                                else
                                    -- Default dark blue when not loaded
                                    ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.2, 0.4, 1.0)
                                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.3, 0.5, 1.0)
                                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.18, 0.35, 1.0)
                                end
                                
                                if ImGui.Button(group.display .. "##" .. group.key, -1, 0) then
                                    iplloader.toggleGroup(group.key, spawnerSettings.unloadLastIPL)
                                end
                                ImGui.PopStyleColor(3)
                            end
                        end
                    end
                    
                    ImGui.Spacing()
                    ClickGUI.EndCustomChildWindow()
                end
                
                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end
        
        -- Process any queued IPL unloads after rendering is complete
        iplloader.processPendingUnloads()

        if ImGui.BeginTabItem("Special") then
            local columns = 2
            if ImGui.BeginTable("SpecialTable", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Free") then
                    ImGui.SetWindowFontScale(1.0)
                    
                    RenderStandardButtonFeature("Spawn Robot", "BiggerScript_Special_SpawnRobot", nil, function()
                        robot.spawnRobot()
                    end)

                    RenderStandardButtonFeature("Self Destruction", "BiggerScript_Special_RobotSelfDestruct", nil, function()
                        robot.selfDestructRobot()
                    end)



                    ImGui.Spacing()
                    RenderCustomCheckboxFeature("Upside Down Map v3", "Upside Down Map", "BiggerScript_Maps_UpsideDown", spawnerSettings, "upsideDownMap", nil, function(newVal)
                        upsidedownmap.toggle_upside_down_map(newVal)
                    end)



                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.TableSetColumnIndex(1)
                
                ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 1.0, 0.0, 1.0)
                local windowName = PaidTier.IsPaid() and "Hoverboard" or "Donor"
                local showDonor = ClickGUI.BeginCustomChildWindow(windowName)
                ImGui.PopStyleColor()

                if showDonor then
                    if PaidTier.IsPaid() then
                        -- Sync with actual state in case it was toggled by hotkey
                        if spawnerSettings.hoverboard ~= Hoverboard.Active then
                            spawnerSettings.hoverboard = Hoverboard.Active
                        end
                        RenderCustomCheckboxFeature("Hoverboard", "Hoverboard Toggle", "BiggerScript_Donor_Hoverboard", spawnerSettings, "hoverboard", "Controls: Shift to boost, Space to jump, E to do tricks", function(newVal)
                            Hoverboard.Toggle(newVal)
                        end)

                        -- Board variation slider (1-9: prop_boogieboard_01 to _09)
                        if spawnerSettings.boardVariation == nil then
                            spawnerSettings.boardVariation = 1
                        end
                        local newVar, changed = ImGui.SliderInt("Board Style", spawnerSettings.boardVariation, 1, 9)
                        if changed then
                            spawnerSettings.boardVariation = newVar
                            Hoverboard.SetBoardVariation(newVar)
                        end
                    else
                        ImGui.Text("More features are available")
                        ImGui.Text("in the donor edition")
                        ImGui.Separator()
                        if ImGui.Button("Copy Discord Link") then
                            Utils.SetClipBoardText("https://discord.gg/ctnbevsz54", "")
                        end
                    end
                    ClickGUI.EndCustomChildWindow()
                end

                if PaidTier.IsPaid() then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 1.0, 0.0, 1.0)
                    local showSentry = ClickGUI.BeginCustomChildWindow("Sentry Gun")
                    ImGui.PopStyleColor()

                    if showSentry then
                        Sentry.RenderUI()
                        ClickGUI.EndCustomChildWindow()
                    end
                end


                
                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end

        -- SPOONER TAB
        if ImGui.BeginTabItem("Spooner") then
            local columns = 2
            if ImGui.BeginTable("SpoonerTable", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                
                -- LEFT COLUMN: Spooner Settings (toggles)
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Spooner Settings") then
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()
                    
                    RenderCustomCheckboxFeature("Enable Gizmo Arrows", "Spooner Gizmo Arrows", "BiggerScript_Spooner_Gizmo", spawnerSettings, "enableGizmo", "Show 3D gizmo arrows on selected entities for positioning")
                    RenderCustomCheckboxFeature("Show Controls", "Spooner Show Controls", "BiggerScript_Spooner_Controls", spawnerSettings, "showSpoonerControls", "Show the Spooner Controls info window in the bottom right")
                    
                    if spawnerSettings.printToDebug then
                        ImGui.Spacing()
                        ImGui.Text("Scale Offsets (Hex)")
                        
                        -- Scale Length Offset Input
                        local lengthHex = string.format("%X", spawnerSettings.scaleLengthOffset)
                        local newLengthHex, changedLength = ImGui.InputText("Length Offset", lengthHex, 16)
                        if newLengthHex ~= lengthHex then
                            local val = tonumber(newLengthHex, 16)
                            if val then
                                spawnerSettings.scaleLengthOffset = val
                            end
                        end
                        if ImGui.IsItemHovered() then
                            ImGui.SetTooltip("Memory offset for length scaling (Default: 60)")
                        end

                        -- Scale Width Offset Input
                        local widthHex = string.format("%X", spawnerSettings.scaleWidthOffset)
                        local newWidthHex, changedWidth = ImGui.InputText("Width Offset", widthHex, 16)
                        if newWidthHex ~= widthHex then
                            local val = tonumber(newWidthHex, 16)
                            if val then
                                spawnerSettings.scaleWidthOffset = val
                            end
                        end
                        if ImGui.IsItemHovered() then
                            ImGui.SetTooltip("Memory offset for width scaling (Default: 74)")
                        end

                        -- Scale Height Offset Input
                        local heightHex = string.format("%X", spawnerSettings.scaleHeightOffset)
                        local newHeightHex, changedHeight = ImGui.InputText("Height Offset", heightHex, 16)
                        if newHeightHex ~= heightHex then
                            local val = tonumber(newHeightHex, 16)
                            if val then
                                spawnerSettings.scaleHeightOffset = val
                            end
                        end
                        if ImGui.IsItemHovered() then
                            ImGui.SetTooltip("Memory offset for height scaling (Default: 88)")
                        end
                        
                        ImGui.Spacing()
                        ImGui.Separator()
                        ImGui.Spacing()
                        
                        -- Memory Scanner
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
                        ImGui.Text("Memory Scanner")
                        ImGui.PopStyleColor()
                        
                        if spooner.isEntityCaptured() then
                            local handle = spooner.getCapturedEntity()
                            local ptrObj = GTA.HandleToPointer(handle)
                            local addr = ptrObj and ptrObj:GetAddress() or 0
                            ImGui.Text("Entity Address: " .. string.format("0x%X", addr))
                            
                            -- Scanner Range Inputs
                            local startHex = string.format("%X", memoryScannerState.rangeStart)
                            local newStart, changedStart = ImGui.InputText("Start Offset", startHex, 16)
                            if newStart ~= startHex then
                                local val = tonumber(newStart, 16)
                                if val then memoryScannerState.rangeStart = val end
                            end
                            
                            local endHex = string.format("%X", memoryScannerState.rangeEnd)
                            local newEnd, changedEnd = ImGui.InputText("End Offset", endHex, 16)
                            if newEnd ~= endHex then
                                local val = tonumber(newEnd, 16)
                                if val then memoryScannerState.rangeEnd = val end
                            end
                            
                            if ImGui.Button("Scan Memory", -1, 0) then
                                memoryScannerState.results = {}
                                if addr ~= 0 then
                                    for offset = memoryScannerState.rangeStart, memoryScannerState.rangeEnd, 4 do
                                        local fVal = Memory.ReadFloat(addr + offset)
                                        local iVal = Memory.ReadInt(addr + offset)
                                        
                                        -- Filter interesting values (floats between 0.1 and 10.0, excluding exactly 0)
                                        if fVal and fVal > 0.1 and fVal < 10.0 then
                                            table.insert(memoryScannerState.results, {
                                                offset = offset,
                                                float = fVal,
                                                int = iVal,
                                                isLikely = (fVal >= 0.9 and fVal <= 1.1) -- Highlight values near 1.0
                                            })
                                        end
                                    end
                                    spawning.debug_print("[Scanner] Found " .. #memoryScannerState.results .. " potential values")
                                end
                            end
                            
                            -- Results List
                            if #memoryScannerState.results > 0 then
                                ImGui.Spacing()
                                ImGui.Text("Potential Matches (" .. #memoryScannerState.results .. "):")
                                ImGui.BeginChild("ScannerResults", 0, 200, true)
                                
                                local columns = 3
                                if ImGui.BeginTable("ScannerTable", columns, ImGuiTableFlags.SizingStretchSame + ImGuiTableFlags.Borders) then
                                     -- Manually render headers since TableSetupColumn might be causing issues
                                     ImGui.TableNextRow()
                                     ImGui.TableSetColumnIndex(0)
                                     ImGui.Text("Offset")
                                     ImGui.TableSetColumnIndex(1)
                                     ImGui.Text("Value")
                                     ImGui.TableSetColumnIndex(2)
                                     ImGui.Text("Action")
                                     
                                     for _, res in ipairs(memoryScannerState.results) do
                                        ImGui.TableNextRow()
                                        ImGui.TableSetColumnIndex(0)
                                        
                                        -- Highlight likely candidates (near 1.0)
                                        if res.isLikely then
                                            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 1.0, 0.0, 1.0)
                                        end
                                        ImGui.Text(string.format("0x%X", res.offset))
                                        if res.isLikely then ImGui.PopStyleColor() end
                                        
                                        ImGui.TableSetColumnIndex(1)
                                        ImGui.Text(string.format("%.3f", res.float))
                                        if ImGui.IsItemHovered() then
                                            ImGui.SetTooltip("Int: " .. res.int)
                                        end
                                        
                                        ImGui.TableSetColumnIndex(2)
                                        if ImGui.Button("Test L##" .. res.offset) then
                                            spawnerSettings.scaleLengthOffset = res.offset
                                        end
                                        ImGui.SameLine()
                                        if ImGui.Button("Test W##" .. res.offset) then
                                            spawnerSettings.scaleWidthOffset = res.offset
                                        end
                                        ImGui.SameLine()
                                        if ImGui.Button("Test H##" .. res.offset) then
                                            spawnerSettings.scaleHeightOffset = res.offset
                                        end
                                    end
                                    ImGui.EndTable()
                                end
                                ImGui.EndChild()
                            end
                        else
                            ImGui.TextDisabled("Select an entity with Spooner to scan")
                        end
                        ImGui.Spacing()
                    end
                    RenderCustomCheckboxFeature("Delete Photo Cache After Exit", "Delete Photo Cache", "BiggerScript_Spooner_PhotoCache", spawnerSettings, "deletePhotoCache", "When enabled, deletes all files in BiggerScript\\SpoonerAssets\\gtahashru\\objects and subfolders when script unloads")
                    
                    ImGui.Spacing()
                    ClickGUI.EndCustomChildWindow()
                end
                
                -- RIGHT COLUMN: Sub Windows with toggle buttons
                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("Spooner") then
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()
                    
                    -- Spooner toggle button (green when off = ready to launch, red when on = exit)
                    local spoonerEnabled = spawnerSettings.enableSpooner
                    local spoonerButtonText = spoonerEnabled and "Exit Spooner" or "Launch Spooner"
                    local spoonerColor = spoonerEnabled and "SpoonerRed" or "SpoonerGreen"
                    
                    RenderDynamicButton(spoonerButtonText, spoonerColor, -1, 30, function()
                        spawnerSettings.enableSpooner = not spawnerSettings.enableSpooner
                        if spawnerSettings.enableSpooner then
                            spooner.startDetectionLoop()
                            -- Close PED/Vehicle customization windows and open Browser when Spooner mode is enabled
                            spooner.setPedCustomsVisible(false)
                            spooner.setVehicleCustomsVisible(false)
                            spooner.openBrowserExpanded()
                        else
                            spooner.stopDetectionLoop()
                            -- Close all sub-windows when Spooner mode is disabled
                            spooner.closeAllSubWindows()
                        end
                    end)
                    
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Enable entity detection and management (Free Cam mode)")
                    end
                    
                    ImGui.Spacing()
                    ImGui.Separator()
                    ImGui.Spacing()
                    
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
                    ImGui.Text("Sub Modules")
                    ImGui.PopStyleColor()
                    
                    ImGui.Spacing()
                    
                    -- Only show Sub Windows if Spooner Mode is NOT active
                    if not spoonerEnabled then
                        -- Browser button (dark blue when off, light blue when on)
                        local browserVisible = spooner.getBrowserVisible()
                        local browserColor = browserVisible and "LightBlue" or "DarkBlue"
                        
                        RenderDynamicButton("Browser", browserColor, -1, 30, function()
                            if browserVisible then
                                -- Toggle off
                                spooner.setBrowserVisible(false)
                            else
                                -- Close other windows first (mutual exclusivity)
                                spooner.closeAllSubWindows()
                                spooner.setBrowserVisible(true)
                            end
                        end)
                        
                        ImGui.Spacing()
                        
                        -- PED Customizations button (dark blue when off, light blue when on)
                        local pedCustomsVisible = spooner.getPedCustomsVisible()
                        local pedColor = pedCustomsVisible and "LightBlue" or "DarkBlue"

                        RenderDynamicButton("Ped Customs", pedColor, -1, 30, function()
                            if pedCustomsVisible then
                                spooner.setPedCustomsVisible(false)
                            else
                                spooner.closeAllSubWindows()
                                spooner.setPedCustomsVisible(true)
                            end
                        end)
                        
                        ImGui.Spacing()
                        
                        -- Vehicle Customizations button (dark blue when off, light blue when on)
                        local vehicleCustomsVisible = spooner.getVehicleCustomsVisible()
                        local vehColor = vehicleCustomsVisible and "LightBlue" or "DarkBlue"
                        
                        RenderDynamicButton("Vehicle Customizations", vehColor, -1, 30, function()
                            if vehicleCustomsVisible then
                                spooner.setVehicleCustomsVisible(false)
                            else
                                spooner.closeAllSubWindows()
                                local success, errorMsg = spooner.openPlayerVehicleCustomizations()
                                if not success then
                                    GUI.AddToast("Spooner", errorMsg or "You need to be in a vehicle", 2000, 0)
                                end
                            end
                        end)
                        
                        ImGui.Spacing()
                        
                        -- Animations button (dark purple when off, light purple when on)
                        local animPlayerVisible = animPlayer.getAnimPlayerVisible()
                        local animColor = animPlayerVisible and "LightPurple" or "DarkPurple"
                        
                        RenderDynamicButton("Animations", animColor, -1, 30, function()
                            if animPlayerVisible then
                                animPlayer.setAnimPlayerVisible(false)
                            else
                                spooner.closeAllSubWindows()
                                animPlayer.openAnimPlayer(PLAYER.PLAYER_PED_ID())
                            end
                        end)
                    else
                        ImGui.TextDisabled("Available when Spooner is OFF")
                    end
                    
                    ImGui.Spacing()
                    ClickGUI.EndCustomChildWindow()
                end
                
                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end

        -- JOB BROWSER TAB
        if ImGui.BeginTabItem("Job Browser") then
            ImGui.Columns(2, "jobBrowserCols", false)
            if ClickGUI.BeginCustomChildWindow("Settings") then
                ImGui.Spacing()
                ImGui.Text("Search Type:")
                ImGui.SameLine()

                local queryLabels = {
                    "Bookmarked",
                    "My Content",
                    "Friend Content",
                    "Most Recent",
                    "Top Rated",
                    "Crew Content",
                }
                local comboOpen = ImGui.BeginCombo("##jobBrowserQueryType", queryLabels[jobBrowserQueryType + 1])
                if comboOpen then
                    for i, label in ipairs(queryLabels) do
                        local selected = (jobBrowserQueryType == i - 1)
                        if ImGui.Selectable(label .. "##jbq" .. i, selected) then
                            jobBrowserQueryType = i - 1
                        end
                    end
                    ImGui.EndCombo()
                end

                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                local categoryStr = "gta5mission"

                if ImGui.Button("Search##jobBrowserSearch", -1, 0) then
                    local qType = jobBrowserQueryType
                    local cat = categoryStr
                    jobBrowserSearching = true
                    jobBrowserResults = {}
                    Script.QueueJob(function()
                        local success = false
                        local queryName = queryLabels[qType + 1]

                        NETWORK.UGC_CANCEL_QUERY()
                        Script.Yield(100)

                        if qType == 0 then
                            success = NETWORK.UGC_GET_BOOKMARKED_CONTENT(0, 50, cat, 0)
                        elseif qType == 1 then
                            success = NETWORK.UGC_GET_MY_CONTENT(0, 50, cat, 0)
                        elseif qType == 2 then
                            success = NETWORK.UGC_GET_FRIEND_CONTENT(0, 50, cat, 0)
                        elseif qType == 3 then
                            success = NETWORK.UGC_QUERY_BY_CATEGORY(3, 0, 50, cat, 0, false)
                        elseif qType == 4 then
                            success = NETWORK.UGC_QUERY_BY_CATEGORY(5, 0, 50, cat, 0, false)
                        elseif qType == 5 then
                            success = NETWORK.UGC_GET_CREW_CONTENT(-1, 0, 50, cat, 0)
                        end

                        if not success then
                            Logger.Log(eLogColor.RED, "[JobBrowser]", queryName .. " query failed.")
                            jobBrowserSearching = false
                            return
                        end

                        -- Poll until results arrive (up to 15s)
                        local startMs = Time.GetEpocheMs()
                        local finished = false
                        while Time.GetEpocheMs() - startMs < 15000 do
                            Script.Yield(200)
                            local didSucceed  = NETWORK.UGC_DID_GET_SUCCEED()
                            local hasFinished = NETWORK.UGC_HAS_GET_FINISHED()
                            local numNow      = NETWORK.UGC_GET_CONTENT_NUM()
                            if (NETWORK.UGC_IS_GETTING() or didSucceed) and numNow and numNow > 0 then
                                finished = true
                                break
                            end
                            if hasFinished or didSucceed then
                                finished = true
                                break
                            end
                        end

                        if not finished then
                            Logger.Log(eLogColor.RED, "[JobBrowser]", queryName .. " timed out.")
                            jobBrowserSearching = false
                            return
                        end

                        local numResults  = NETWORK.UGC_GET_CONTENT_NUM()
                        local totalResults = NETWORK.UGC_GET_CONTENT_TOTAL()

                        jobBrowserResults = {}
                        jobBrowserTotalResults = totalResults or 0
                        jobBrowserPage = 0

                        if numResults and numResults > 0 then
                            for i = 0, numResults - 1 do
                                local name    = NETWORK.UGC_GET_CONTENT_NAME(i)
                                local cid     = NETWORK.UGC_GET_CONTENT_ID(i)
                                local creator = NETWORK.UGC_GET_CONTENT_USER_NAME(i)
                                local catNum  = NETWORK.UGC_GET_CONTENT_CATEGORY(i)
                                local descHash = NETWORK.UGC_GET_CONTENT_DESCRIPTION_HASH(i)
                                local path    = NETWORK.UGC_GET_CONTENT_PATH(i, 2) -- 2 = hi-res photo
                                local fileVer = NETWORK.UGC_GET_CONTENT_FILE_VERSION(i, 0)
                                local rating  = NETWORK.UGC_GET_CONTENT_RATING(i, 0)
                                local ratingCount = NETWORK.UGC_GET_CONTENT_RATING_COUNT(i, 0)
                                local isVerified = NETWORK.UGC_GET_CONTENT_IS_VERIFIED(i)

                                -- CDN base URL
                                local cdnBase = nil
                                if cid and fileVer then
                                    cdnBase = "https://prod.cloud.rockstargames.com/ugc/gta5mission/" .. tostring(fileVer) .. "/" .. tostring(cid)
                                end

                                table.insert(jobBrowserResults, {
                                    name = tostring(name or "Unknown"),
                                    cid = tostring(cid or ""),
                                    creator = tostring(creator or "Unknown"),
                                    category = catNum or 0,
                                    descHash = descHash or 0,
                                    cdnPath = path or "",
                                    cdnBase = cdnBase,
                                    fileVersion = fileVer or 0,
                                    rating = rating or 0,
                                    ratingCount = ratingCount or 0,
                                    verified = isVerified or false,
                                })

                                end
                                Logger.Log(eLogColor.GREEN, "[JobBrowser]", "Found " .. #jobBrowserResults .. " results.")

                            -- Download preview images in background
                            for _, entry in ipairs(jobBrowserResults) do
                                local dlCid = entry.cid
                                if dlCid and dlCid ~= "" and not jobBrowserTexCache[dlCid] then
                                    jobBrowserTexCache[dlCid] = "downloading"
                                    local dlEntry = entry
                                    Script.QueueJob(function()
                                        local nativeVer = dlEntry.fileVersion or 0
                                        local paddedVer = string.format("%04d", nativeVer)
                                        local versions = { paddedVer }
                                        if tostring(nativeVer) ~= paddedVer then
                                            table.insert(versions, tostring(nativeVer))
                                        end
                                        local extraVersions = { 6285, 5131, 5828, 5483, 3816, 0, 1, 2, 3, 4, 5 }
                                        for _, v in ipairs(extraVersions) do table.insert(versions, tostring(v)) end

                                        local imgPath = jobBrowserPreviewFolder .. "\\" .. dlCid .. ".png"

                                        -- Check if already cached on disk
                                        if FileMgr.DoesFileExist(imgPath) then
                                            -- Already downloaded, just load texture
                                            local texId = Texture.LoadTextureAsync(imgPath)
                                            if texId and texId ~= 0 then
                                                jobBrowserTexCache[dlCid] = texId
                                            else
                                                jobBrowserTexCache[dlCid] = "failed"
                                            end
                                            return
                                        end

                                        -- Ensure cache directory exists
                                        FileMgr.CreateDir(jobBrowserPreviewFolder)

                                        local downloaded = false
                                        for _, ver in ipairs(versions) do
                                            if downloaded then break end
                                            local imgUrl = "https://prod.cloud.rockstargames.com/ugc/gta5mission/" .. ver .. "/" .. dlCid .. "/2_0.jpg"
                                            local imgData = asset_loader.curl_get(imgUrl)
                                            if imgData and #imgData > 100 then
                                                asset_loader.write_file(imgPath, imgData, "wb")
                                                downloaded = true
                                            end
                                            Script.Yield(0)
                                        end

                                        if downloaded then
                                            Script.Yield(100) -- Small delay for file to settle
                                            local texId = Texture.LoadTextureAsync(imgPath)
                                            if texId and texId ~= 0 then
                                                jobBrowserTexCache[dlCid] = texId
                                            else
                                                jobBrowserTexCache[dlCid] = "failed"
                                            end
                                        else
                                            jobBrowserTexCache[dlCid] = "none"
                                        end
                                    end)
                                end
                            end
                        else
                            Logger.Log(eLogColor.RED, "[JobBrowser]", "No results found.")
                        end
                        jobBrowserSearching = false
                    end)
                end

                ClickGUI.EndCustomChildWindow()
            end
            
            ImGui.NextColumn()

            -- Job Importer panel
            if ClickGUI.BeginCustomChildWindow("Job Importer") then
                ImGui.Spacing()
                ImGui.Text("Paste a Social Club or CDN URL:")
                ImGui.Spacing()
                jobImporterUrl, _ = ImGui.InputText("##jobImporterUrl", jobImporterUrl, 512)
                ImGui.Spacing()

                RenderCustomCheckboxFeature("Save Preview Image", "Save Preview Image", "BiggerScript_JobImporter_SaveImage", spawnerSettings, "jobImporterSaveImage", "Download the job preview image as .png for photo preview")
                if spawnerSettings.jobImporterSaveImage == nil then spawnerSettings.jobImporterSaveImage = true end

                ImGui.Spacing()

                if jobImporterBusy then
                    ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.3, 0.3, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.3, 0.3, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.3, 0.3, 0.3, 1.0)
                    ImGui.Button("Importing...")
                    ImGui.PopStyleColor(3)
                else
                    RenderCustomButtonFeature("Import Job", "Import Job", "BiggerScript_JobImporter_Import", "Green", "Download the job JSON (and optional image) from Rockstar CDN", function()
                        if jobImporterUrl == "" then
                            jobImporterStatus = "Please enter a URL"
                            jobImporterStatusColor = { 1.0, 0.6, 0.2, 1.0 }
                            return
                        end
                        jobImporterBusy = true
                        jobImporterStatus = "Starting import..."
                        jobImporterStatusColor = { 0.4, 0.8, 1.0, 1.0 }

                        Script.QueueJob(function()
                            local url = jobImporterUrl
                            local saveImg = spawnerSettings.jobImporterSaveImage

                            -- Language list (client language dependent, try common ones first)
                            local langs = { "en", "ja", "zh", "zh-cn", "fr", "de", "it", "ru", "pt", "pl", "ko", "es", "es-mx" }
                            -- Common file patterns (i_j prefix)
                            local commonPatterns = { {0,0}, {0,1}, {1,0}, {2,0} }

                            -- Determine base CDN path from input URL
                            local cdnBase = nil
                            local contentId = nil

                            -- Case 1: Direct CDN JSON URL
                            if url:match("prod%.cloud%.rockstargames%.com") and url:match("%.json$") then
                                cdnBase = url:match("^(.+)/[^/]+$")
                                jobImporterStatus = "Downloading JSON directly..."
                                local body = asset_loader.curl_get(url)
                                if body and body ~= "" then
                                    local jsonData = asset_loader.json_decode(body)
                                    if jsonData then
                                        -- Extract race name
                                        local raceName = nil
                                        if jsonData.mission and jsonData.mission.gen and jsonData.mission.gen.nm then
                                            raceName = jsonData.mission.gen.nm
                                        end
                                        if not raceName or raceName == "" then
                                            -- Try recursive nm search
                                            local function findNm(obj, depth)
                                                if depth > 5 then return nil end
                                                if type(obj) == "table" then
                                                    if obj.nm and type(obj.nm) == "string" then return obj.nm end
                                                    for _, v in pairs(obj) do
                                                        local r = findNm(v, depth + 1)
                                                        if r then return r end
                                                    end
                                                end
                                                return nil
                                            end
                                            raceName = findNm(jsonData, 0)
                                        end
                                        if not raceName or raceName == "" then raceName = "unnamed_job" end

                                        -- Sanitize filename
                                        local safeName = raceName:gsub('[\\/*?:"<>|]', ''):gsub('[%s%-+.,;=]', '_'):gsub('_+', '_')
                                        if #safeName > 100 then safeName = safeName:sub(1, 100) end
                                        safeName = safeName:match('^_*(.-_*)$') or safeName
                                        if safeName == "" then safeName = "unnamed_job" end

                                        local savePath = jobMapsFolder .. "\\" .. safeName .. ".json"
                                        asset_loader.write_file(savePath, body)

                                        -- Download image if enabled
                                        if saveImg and cdnBase then
                                            local imgUrl = cdnBase .. "/2_0.jpg"
                                            jobImporterStatus = "Downloading preview image..."
                                            local imgData = asset_loader.curl_get(imgUrl)
                                            if imgData and #imgData > 100 then
                                                local imgPath = jobMapsFolder .. "\\" .. safeName .. ".png"
                                                asset_loader.write_file(imgPath, imgData, "wb")
                                            end
                                        end

                                        jobImporterStatus = "Imported: " .. raceName
                                        jobImporterStatusColor = { 0.2, 1.0, 0.4, 1.0 }
                                        refreshJobMaps()
                                    else
                                        jobImporterStatus = "Failed to parse JSON"
                                        jobImporterStatusColor = { 1.0, 0.3, 0.3, 1.0 }
                                    end
                                else
                                    jobImporterStatus = "Failed to download JSON"
                                    jobImporterStatusColor = { 1.0, 0.3, 0.3, 1.0 }
                                end
                                jobImporterBusy = false
                                return
                            end

                            -- Case 2: CDN image/base URL (extract base path)
                            if url:match("prod%.cloud%.rockstargames%.com") then
                                cdnBase = url:match("^(.+)/[^/]+$") or url
                                contentId = cdnBase:match("/([^/]+)$")
                            end

                            -- Case 3: Social Club URL — extract content ID and build CDN base
                            if url:match("socialclub%.rockstargames%.com") then
                                contentId = url:match("/job/gtav/([^/]+)")
                                if not contentId then
                                    contentId = url:match("/([^/]+)$")
                                end
                            end

                            if not contentId or contentId == "" then
                                jobImporterStatus = "Could not extract content ID from URL"
                                jobImporterStatusColor = { 1.0, 0.3, 0.3, 1.0 }
                                jobImporterBusy = false
                                return
                            end

                            -- Try common version numbers for CDN path
                            local versionNumbers = {}
                            if cdnBase then
                                -- Already have full CDN path, use it directly
                                table.insert(versionNumbers, cdnBase)
                            else
                                -- Build CDN URLs with common version numbers
                                local commonVersions = { 6285, 5131, 5828, 5483, 3816, 0, 1, 2, 3, 4, 5 }
                                for _, ver in ipairs(commonVersions) do
                                    table.insert(versionNumbers, "https://prod.cloud.rockstargames.com/ugc/gta5mission/" .. ver .. "/" .. contentId)
                                end
                            end

                            jobImporterStatus = "Searching for JSON... (trying " .. #versionNumbers .. " paths)"
                            local found = false

                            for _, basePath in ipairs(versionNumbers) do
                                if found then break end

                                -- Try common patterns first
                                for _, pattern in ipairs(commonPatterns) do
                                    if found then break end
                                    for _, lang in ipairs(langs) do
                                        if found then break end
                                        local tryUrl = basePath .. "/" .. pattern[1] .. "_" .. pattern[2] .. "_" .. lang .. ".json"
                                        jobImporterStatus = "Trying: " .. lang .. " (" .. pattern[1] .. "_" .. pattern[2] .. ")..."
                                        local body = asset_loader.curl_get(tryUrl)
                                        if body and body ~= "" and body:sub(1,1) == "{" then
                                            local jsonData = asset_loader.json_decode(body)
                                            if jsonData then
                                                -- Extract race name
                                                local raceName = nil
                                                if jsonData.mission and jsonData.mission.gen and jsonData.mission.gen.nm then
                                                    raceName = jsonData.mission.gen.nm
                                                end
                                                if not raceName or raceName == "" then
                                                    local function findNm(obj, depth)
                                                        if depth > 5 then return nil end
                                                        if type(obj) == "table" then
                                                            if obj.nm and type(obj.nm) == "string" then return obj.nm end
                                                            for _, v in pairs(obj) do
                                                                local r = findNm(v, depth + 1)
                                                                if r then return r end
                                                            end
                                                        end
                                                        return nil
                                                    end
                                                    raceName = findNm(jsonData, 0)
                                                end
                                                if not raceName or raceName == "" then raceName = "unnamed_job" end

                                                local safeName = raceName:gsub('[\\/*?:"<>|]', ''):gsub('[%s%-+.,;=]', '_'):gsub('_+', '_')
                                                if #safeName > 100 then safeName = safeName:sub(1, 100) end
                                                safeName = safeName:match('^_*(.-_*)$') or safeName
                                                if safeName == "" then safeName = "unnamed_job" end

                                                local savePath = jobMapsFolder .. "\\" .. safeName .. ".json"
                                                asset_loader.write_file(savePath, body)

                                                -- Download image
                                                if saveImg then
                                                    local imgUrl = basePath .. "/2_0.jpg"
                                                    jobImporterStatus = "Downloading preview image..."
                                                    local imgData = asset_loader.curl_get(imgUrl)
                                                    if imgData and #imgData > 100 then
                                                        local imgPath = jobMapsFolder .. "\\" .. safeName .. ".png"
                                                        asset_loader.write_file(imgPath, imgData, "wb")
                                                    end
                                                end

                                                jobImporterStatus = "Imported: " .. raceName
                                                jobImporterStatusColor = { 0.2, 1.0, 0.4, 1.0 }
                                                refreshJobMaps()
                                                found = true
                                            end
                                        end
                                        Script.Yield(0)
                                    end
                                end
                            end

                            if not found then
                                jobImporterStatus = "No JSON found. Try a direct CDN URL."
                                jobImporterStatusColor = { 1.0, 0.3, 0.3, 1.0 }
                            end
                            jobImporterBusy = false
                        end)
                    end)
                end

                -- Status message
                if jobImporterStatus ~= "" then
                    ImGui.Spacing()
                    ImGui.PushStyleColor(ImGuiCol.Text, jobImporterStatusColor[1], jobImporterStatusColor[2], jobImporterStatusColor[3], jobImporterStatusColor[4])
                    ImGui.TextWrapped(jobImporterStatus)
                    ImGui.PopStyleColor()
                end

                ImGui.Spacing()
                ClickGUI.EndCustomChildWindow()
            end

            ImGui.Columns(1)

            -- Results display area (full width below the two columns)
            if jobBrowserSearching then
                ImGui.Spacing()
                ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Searching...")
            elseif #jobBrowserResults > 0 then
                ImGui.Spacing()
                ImGui.Separator()
                ImGui.Spacing()

                -- Pagination controls
                local totalPages = math.ceil(#jobBrowserResults / jobBrowserPerPage)
                local startIdx = jobBrowserPage * jobBrowserPerPage + 1
                local endIdx = math.min(startIdx + jobBrowserPerPage - 1, #jobBrowserResults)

                ImGui.Text(string.format("Showing %d-%d of %d results (Page %d/%d)",
                    startIdx, endIdx, #jobBrowserResults, jobBrowserPage + 1, totalPages))
                ImGui.SameLine()
                if jobBrowserPage > 0 then
                    if ImGui.SmallButton("< Prev##jbPrev") then
                        jobBrowserPage = jobBrowserPage - 1
                    end
                    ImGui.SameLine()
                end
                if jobBrowserPage < totalPages - 1 then
                    if ImGui.SmallButton("Next >##jbNext") then
                        jobBrowserPage = jobBrowserPage + 1
                    end
                end

                ImGui.Spacing()

                if ClickGUI.BeginCustomChildWindow("Results") then

                    for idx = startIdx, endIdx do
                        local r = jobBrowserResults[idx]
                        if r then
                            ImGui.PushID("jbResult" .. idx)

                            -- Each result row: image placeholder on left, info on right
                            ImGui.Columns(2, "jbRow" .. idx, false)
                            ImGui.SetColumnWidth(0, 130)

                            -- Left column: preview image
                            local texState = jobBrowserTexCache[r.cid]
                            if type(texState) == "number" and texState ~= 0 then
                                -- Texture loaded, render inline
                                local valid = pcall(function()
                                    if Texture.IsTextureValid(texState) then
                                        local d3dTex = Texture.GetTexture(texState)
                                        if d3dTex then
                                            local gpuTex = d3dTex:GetCurrent()
                                            if gpuTex then
                                                local cp_x, cp_y = ImGui.GetCursorScreenPos()
                                                ImGui.AddImage(gpuTex, cp_x, cp_y, cp_x + 120, cp_y + 68)
                                                ImGui.Dummy(120, 68)
                                            else
                                                ImGui.Dummy(120, 68)
                                            end
                                        else
                                            ImGui.Dummy(120, 68)
                                        end
                                    else
                                        ImGui.Dummy(120, 68)
                                    end
                                end)
                                if not valid then
                                    ImGui.Dummy(120, 68)
                                end
                            elseif texState == "downloading" or texState == "loading" then
                                ImGui.TextColored(0.5, 0.5, 0.5, 1.0, "Loading...")
                                ImGui.Dummy(120, 48)
                            else
                                -- No image or failed
                                ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.15, 0.2, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.15, 0.2, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.15, 0.2, 1.0)
                                ImGui.Button("No Image##ni" .. idx, 120, 68)
                                ImGui.PopStyleColor(3)
                            end

                            -- Right column: name, creator, save
                            ImGui.NextColumn()

                            -- Job name
                            if r.verified then
                                ImGui.TextColored(0.3, 1.0, 0.5, 1.0, "[V] " .. r.name)
                            else
                                ImGui.TextColored(1.0, 1.0, 1.0, 1.0, r.name)
                            end

                            -- Creator
                            ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "By: " .. r.creator)

                            -- Save button
                            if jobBrowserSaving[idx] then
                                ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.3, 0.3, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.3, 0.3, 1.0)
                                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.3, 0.3, 0.3, 1.0)
                                ImGui.Button("Saving...##sv" .. idx)
                                ImGui.PopStyleColor(3)
                            else
                                if ImGui.Button("Save##jbSave" .. idx) then
                                    jobBrowserSaving[idx] = true
                                    local entry = r
                                    local saveIdx = idx
                                    Script.QueueJob(function()
                                        local saveImg = spawnerSettings.jobImporterSaveImage
                                        local langs = { "en", "ja", "zh", "zh-cn", "fr", "de", "it", "ru", "pt", "pl", "ko", "es", "es-mx" }
                                        local commonPatterns = { {0,0}, {0,1}, {1,0}, {2,0} }

                                        local cid = entry.cid
                                        if not cid or cid == "" then
                                            Logger.Log(eLogColor.RED, "[JobBrowser]", "No CID for: " .. entry.name)
                                            jobBrowserSaving[saveIdx] = nil
                                            return
                                        end

                                        -- Build list of CDN base URLs to try (native version first, then common ones)
                                        local versionNumbers = {}
                                        local nativeVer = entry.fileVersion or 0
                                        local paddedVer = string.format("%04d", nativeVer)
                                        table.insert(versionNumbers, "https://prod.cloud.rockstargames.com/ugc/gta5mission/" .. paddedVer .. "/" .. cid)
                                        if tostring(nativeVer) ~= paddedVer then
                                            table.insert(versionNumbers, "https://prod.cloud.rockstargames.com/ugc/gta5mission/" .. tostring(nativeVer) .. "/" .. cid)
                                        end
                                        local commonVersions = { 6285, 5131, 5828, 5483, 3816, 0, 1, 2, 3, 4, 5 }
                                        for _, ver in ipairs(commonVersions) do
                                            table.insert(versionNumbers, "https://prod.cloud.rockstargames.com/ugc/gta5mission/" .. ver .. "/" .. cid)
                                        end

                                        Logger.Log(eLogColor.GREEN, "[JobBrowser]", "Saving: " .. entry.name)

                                        local found = false
                                        for _, basePath in ipairs(versionNumbers) do
                                            if found then break end
                                            for _, pattern in ipairs(commonPatterns) do
                                                if found then break end
                                                for _, lang in ipairs(langs) do
                                                    if found then break end
                                                    local tryUrl = basePath .. "/" .. pattern[1] .. "_" .. pattern[2] .. "_" .. lang .. ".json"
                                                    local body = asset_loader.curl_get(tryUrl)
                                                    if body and body ~= "" and body:sub(1,1) == "{" then
                                                        local jsonData = asset_loader.json_decode(body)
                                                        if jsonData then
                                                            local raceName = entry.name
                                                            if not raceName or raceName == "" then raceName = "unnamed_job" end

                                                            local safeName = raceName:gsub('[\\/*?:"<>|]', ''):gsub('[%s%-+.,;=]', '_'):gsub('_+', '_')
                                                            if #safeName > 100 then safeName = safeName:sub(1, 100) end
                                                            safeName = safeName:match('^_*(.-_*)$') or safeName
                                                            if safeName == "" then safeName = "unnamed_job" end

                                                            local savePath = jobMapsFolder .. "\\" .. safeName .. ".json"
                                                            asset_loader.write_file(savePath, body)

                                                            local imgDst = jobMapsFolder .. "\\" .. safeName .. ".png"
                                                            local imgUrl = basePath .. "/2_0.jpg"
                                                            local imgData = asset_loader.curl_get(imgUrl)
                                                            if imgData and #imgData > 100 then
                                                                asset_loader.write_file(imgDst, imgData, "wb")
                                                            end

                                                            Logger.Log(eLogColor.GREEN, "[JobBrowser]", "Saved: " .. raceName)
                                                            refreshJobMaps()
                                                            found = true
                                                        end
                                                    end
                                                    Script.Yield(0)
                                                end
                                            end
                                        end

                                        if not found then
                                            Logger.Log(eLogColor.RED, "[JobBrowser]", "Could not download JSON for: " .. entry.name)
                                        end
                                        jobBrowserSaving[saveIdx] = nil
                                    end)
                                end
                            end

                            ImGui.Columns(1)
                            ImGui.Spacing()
                            ImGui.Separator()
                            ImGui.Spacing()

                            ImGui.PopID()
                        end
                    end

                    ClickGUI.EndCustomChildWindow()
                end
            end

            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end
    spawning.managePreview(hoveredFileThisFrame)
    menuJustReopened = false  -- Clear after all folders have been rendered this frame
end

ClickGUI.AddTab("Bigger Script", renderMenyooTab)


ClickGUI.AddPlayerTab("Bigger Script", function()
    if ClickGUI.BeginCustomChildWindow("Send Vehicles") then

        ClickGUI.RenderFeature(Utils.Joaat("DeleteMenyooAttackerVehicle"), Utils.GetSelectedPlayer())
        ImGui.Spacing()

        RenderCustomButtonFeature("Delete All", "Delete All", "BiggerScript_Attacker_DeleteAll", "PurpleRed", nil, function()
            spawning.deleteAllSpawnedVehicles()
        end)
        
        ImGui.SameLine()
        
        -- Spawn Mode Dropdown
        ImGui.SetNextItemWidth(150) -- Optional: set a fixed width for the combo to make it fit better
        local currentModeName = attackerSpawnModeNames[spawnerSettings.attackerSpawnMode + 1] or "Attacker"
        if ImGui.BeginCombo("##attackerSpawnMode", currentModeName) then
            for i, modeName in ipairs(attackerSpawnModeNames) do
                local isSelected = (spawnerSettings.attackerSpawnMode == (i - 1))
                if ImGui.Selectable(modeName .. "##mode" .. i, isSelected) then
                    spawnerSettings.attackerSpawnMode = i - 1
                end
            end
            ImGui.EndCombo()
        end
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Attacker: Spawns vehicle with ped that chases Target\nSpawn: Spawns vehicle in front of Target\nApply: Applies attachments to Target's current vehicle")
        end
        ImGui.SameLine()
        if spawnerSettings.sendToAllPlayers == nil then spawnerSettings.sendToAllPlayers = false end
        RenderCustomCheckboxFeature("Send to All", "Send to All", "BiggerScript_Attacker_SendToAll", spawnerSettings, "sendToAllPlayers", "Send vehicle to all players in the session (excluding you)")
        ImGui.Spacing()

        if ImGui.BeginTabBar("AttackerTypeTabs") then
            if ImGui.BeginTabItem("XML") then
                local xmlFiles = getXmlFiles()
                local targetPlayer = Utils.GetSelectedPlayer()
                local attackerSpawnFunc = function(filePath)
                    local mode = spawnerSettings.attackerSpawnMode
                    if spawnerSettings.sendToAllPlayers then
                        local count = 0
                        for _, pid in pairs(Players.Get()) do
                            if pid ~= GTA.GetLocalPlayerId() then
                                if mode == 0 then spawning.spawnMenyooAttackerFromXML(filePath, pid, true)
                                elseif mode == 1 then spawning.spawnGiftVehicleFromXML(filePath, pid, true)
                                elseif mode == 2 then spawning.applyVehicleAttachmentsFromXML(filePath, pid, true)
                                end
                                count = count + 1
                            end
                        end
                        GUI.AddToast("Send to All", "Sent to " .. count .. " players", 5000, 0)
                    else
                        if mode == 0 then
                            spawning.spawnMenyooAttackerFromXML(filePath, targetPlayer)
                        elseif mode == 1 then
                            spawning.spawnGiftVehicleFromXML(filePath, targetPlayer)
                        elseif mode == 2 then
                            spawning.applyVehicleAttachmentsFromXML(filePath, targetPlayer)
                        end
                    end
                end
                local searchXmlAttackers = ImGui.InputText("##searchXmlAttackers", searchXmlAttackers or "", 256)
                ImGui.Spacing()
                renderFolderContents(xmlFiles, attackerSpawnFunc, searchXmlAttackers, "xmlAttackers")
                ImGui.EndTabItem()
            end

            if ImGui.BeginTabItem("INI") then
                local iniFiles = getIniVehicles()
                local targetPlayer = Utils.GetSelectedPlayer()
                local attackerSpawnFunc = function(filePath)
                    local mode = spawnerSettings.attackerSpawnMode
                    if spawnerSettings.sendToAllPlayers then
                        local count = 0
                        for _, pid in pairs(Players.Get()) do
                            if pid ~= GTA.GetLocalPlayerId() then
                                if mode == 0 then spawning.spawnMenyooAttackerFromINI(filePath, pid, true)
                                elseif mode == 1 then spawning.spawnGiftVehicleFromINI(filePath, pid, true)
                                elseif mode == 2 then spawning.applyVehicleAttachmentsFromINI(filePath, pid, true)
                                end
                                count = count + 1
                            end
                        end
                        GUI.AddToast("Send to All", "Sent to " .. count .. " players", 5000, 0)
                    else
                        if mode == 0 then
                            spawning.spawnMenyooAttackerFromINI(filePath, targetPlayer)
                        elseif mode == 1 then
                            spawning.spawnGiftVehicleFromINI(filePath, targetPlayer)
                        elseif mode == 2 then
                            spawning.applyVehicleAttachmentsFromINI(filePath, targetPlayer)
                        end
                    end
                end
                local searchIniAttackers = ImGui.InputText("##searchIniAttackers", searchIniAttackers or "", 256)
                ImGui.Spacing()
                renderFolderContents(iniFiles, attackerSpawnFunc, searchIniAttackers, "iniAttackers")
                ImGui.EndTabItem()
            end

            if ImGui.BeginTabItem("JSON") then
                local jsonFiles = getJsonVehicles()
                local targetPlayer = Utils.GetSelectedPlayer()
                local attackerSpawnFunc = function(filePath)
                    local mode = spawnerSettings.attackerSpawnMode
                    if spawnerSettings.sendToAllPlayers then
                        local count = 0
                        for _, pid in pairs(Players.Get()) do
                            if pid ~= GTA.GetLocalPlayerId() then
                                if mode == 0 then spawning.spawnMenyooAttackerFromJSON(filePath, pid, true)
                                elseif mode == 1 then spawning.spawnGiftVehicleFromJSON(filePath, pid, true)
                                elseif mode == 2 then spawning.applyVehicleAttachmentsFromJSON(filePath, pid, true)
                                end
                                count = count + 1
                            end
                        end
                        GUI.AddToast("Send to All", "Sent to " .. count .. " players", 5000, 0)
                    else
                        if mode == 0 then
                            spawning.spawnMenyooAttackerFromJSON(filePath, targetPlayer)
                        elseif mode == 1 then
                            spawning.spawnGiftVehicleFromJSON(filePath, targetPlayer)
                        elseif mode == 2 then
                            spawning.applyVehicleAttachmentsFromJSON(filePath, targetPlayer)
                        end
                    end
                end
                local searchJsonAttackers = ImGui.InputText("##searchJsonAttackers", searchJsonAttackers or "", 256)
                ImGui.Spacing()
                renderFolderContents(jsonFiles, attackerSpawnFunc, searchJsonAttackers, "jsonAttackers")
                ImGui.EndTabItem()
            end

            if ImGui.BeginTabItem("Robot Attacker") then
                RenderStandardButtonFeature("Spawn Robot Attacker", "BiggerScript_Attacker_Robot", nil, function()
                    local targetPlayer = Utils.GetSelectedPlayer()
                    robot.spawnRobotAttacker(targetPlayer)
                end)
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end

        ClickGUI.EndCustomChildWindow()
    end
end)