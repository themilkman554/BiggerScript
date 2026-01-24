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

GUI.AddToast("BiggerScriptv6.4", "Added Gift and Apply vehicles", 10000, 0)

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

local menuRootPath = FileMgr.GetMenuRootPath()
local biggerScriptRootPath = menuRootPath .. "\\Lua\\BiggerScript"
local xmlVehiclesFolder = biggerScriptRootPath .. "\\XML Vehicles"
local iniVehiclesFolder = biggerScriptRootPath .. "\\INI Vehicles"
local jsonVehiclesFolder = biggerScriptRootPath .. "\\JSON Vehicles"
local xmlMapsFolder = biggerScriptRootPath .. "\\XML Maps"
local jsonMapsFolder = biggerScriptRootPath .. "\\JSON Maps"
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
    contextPreview = false,
    unloadLastIPL = false,
    attackerSpawnMode = 0, -- 0 = Attacker, 1 = Gift, 2 = Apply
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
local activeSearchField = nil

-- Context menu state
local contextMenuFile = nil  -- { path = string, type = string ("vehicle"/"map"/"outfit") }
local contextMenuOpen = false
local contextKeyConsumed = false  -- Prevent multiple activations per key press
local mouseRightConsumed = false  -- Prevent multiple activations per right-click
local contextMenuPos = { x = 0, y = 0 }  -- Store position where menu was opened

-- Helper function to get !favs folder path based on item type and base folder
local function getFavsFolder(itemType, originalPath)
    local baseFolders = {
        vehicle = { xmlVehiclesFolder, iniVehiclesFolder, jsonVehiclesFolder, chrxVehiclesFolder },
        map = { xmlMapsFolder, jsonMapsFolder },
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
    if isSearching then
        ImGui.SetNextItemOpen(true, ImGuiCond.Always)
        isOpen = ImGui.TreeNode(folderName)
    else
        local currentState = folderStates[currentPath]
        if currentState ~= nil then
            ImGui.SetNextItemOpen(currentState, ImGuiCond.Always)
        end
        isOpen = ImGui.TreeNode(folderName)
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
                    if spawnFunction then
                        if spawnFunction == iniAttackerSelectFunction then
                            spawnFunction(selectedPath)
                        elseif spawnFunction == spawning.spawnVehicleFromCHRX or spawnFunction == spawning.spawnOutfitFromCHRX then
                            -- CHRX functions need the index parameter
                            Script.QueueJob(function() spawnFunction(selectedPath, i-1) end)
                        else
                            -- Other spawn functions don't need the index
                            Script.QueueJob(function() spawnFunction(selectedPath) end)
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
                if spawnFunction then
                    if spawnFunction == spawning.spawnVehicleFromCHRX or spawnFunction == spawning.spawnOutfitFromCHRX then
                        -- CHRX functions need the index parameter
                        Script.QueueJob(function() spawnFunction(selectedPath, i-1) end)
                    else
                        -- Other spawn functions don't need the index
                        Script.QueueJob(function() spawnFunction(selectedPath) end)
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
local searchXmlOutfits = ""
local searchXmlOutfits = ""
local searchJsonOutfits = ""
local searchChrxOutfits = ""

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

local function renderMenyooTab()
    if not initialized then
        ImGui.Text("Loading libraries... Please wait.")
        return
    end
    local hoveredFileThisFrame = nil
    local function hoverCallback(file)
        hoveredFileThisFrame = file
        -- Call context preview handler if enabled
        if spawnerSettings.contextPreview and spawning then
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
            ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.36, 0.157, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.46, 0.22, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.26, 0.10, 1.0)
            if ImGui.Button("Move to Favorites") then
                moveToFavorites(contextMenuFile.path, contextMenuFile.type)
                contextMenuOpen = false
                contextMenuFile = nil
            end
            ImGui.PopStyleColor(3)
            
            -- Delete button (red)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.016, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.06, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.01, 1.0)
            if ImGui.Button("Delete") then
                deleteFile(contextMenuFile.path, contextMenuFile.type)
                contextMenuOpen = false
                contextMenuFile = nil
            end
            ImGui.PopStyleColor(3)
            
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

                    spawnerSettings.contextPreview = ImGui.Checkbox("Context Preview", spawnerSettings.contextPreview)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Light Blue = Networkable (under 80)\nOrange = Not everything will network")
                    end
                    spawnerSettings.previewVehicle = ImGui.Checkbox("Preview Vehicle", spawnerSettings.previewVehicle)
                    spawnerSettings.onlyApplyAttachments = ImGui.Checkbox("Apply Attachments to Current Vehicle", spawnerSettings.onlyApplyAttachments)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Instead of spawning a new vehicle, attach objects to the vehicle you're currently in")
                    end
                    spawnerSettings.inVehicle = ImGui.Checkbox("In Vehicle", spawnerSettings.inVehicle)
                    spawnerSettings.spawnPlaneInTheAir = ImGui.Checkbox("Spawn Aircraft In The Air", spawnerSettings.spawnPlaneInTheAir)
                    spawnerSettings.deleteOldVehicle = ImGui.Checkbox("Delete Old Vehicle", spawnerSettings.deleteOldVehicle)
                    spawnerSettings.vehicleGodMode = ImGui.Checkbox("Vehicle God Mode", spawnerSettings.vehicleGodMode)
                    spawnerSettings.vehicleEngineOn = ImGui.Checkbox("Vehicle Engine On", spawnerSettings.vehicleEngineOn)
                    spawnerSettings.radioOff = ImGui.Checkbox("Radio Off", spawnerSettings.radioOff)
                    spawnerSettings.upgradedVehicle = ImGui.Checkbox("Upgraded Vehicle", spawnerSettings.upgradedVehicle)
                    spawnerSettings.randomColor = ImGui.Checkbox("Random Color", spawnerSettings.randomColor)
                    spawnerSettings.randomLivery = ImGui.Checkbox("Random Livery", spawnerSettings.randomLivery)

                    
                    local oldFly = spawnerSettings.vehicleFly
                    spawnerSettings.vehicleFly = ImGui.Checkbox("Vehicle Fly", spawnerSettings.vehicleFly)
                    if spawnerSettings.vehicleFly ~= oldFly then
                        vehicle_fly.toggle_vehicle_fly(spawnerSettings.vehicleFly)
                    end

                    ImGui.Spacing()

                    ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.157, 1.0) 
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.22, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.10, 1.0)
                    if ImGui.Button("Delete All Spawned Vehicles") then
                        spawning.deleteAllSpawnedVehicles()
                    end
                    ImGui.PopStyleColor(3)

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete all previously spawned vehicles and their attachments")
                    end

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
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.36, 0.157, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.46, 0.22, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.26, 0.10, 1.0)
                            if ImGui.Button("Drive##veh" .. i) then
                                if vehicleData.vehicle and vehicleData.vehicle ~= 0 then
                                    spawning.driveVehicle(vehicleData.vehicle)
                                end
                            end
                            ImGui.PopStyleColor(3)
                            
                            ImGui.SameLine()
                            
                            -- Red Delete button
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.016, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.06, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.01, 1.0)
                            if ImGui.Button("Delete##veh" .. i) then
                                spawning.deleteVehicleByIndex(i)
                            end
                            ImGui.PopStyleColor(3)
                        end
                        ClickGUI.EndCustomChildWindow()
                    end
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("Vehicles") then
                    if ImGui.BeginTabBar("VehicleTypeTabs") then
                        if ImGui.BeginTabItem("XML") then
                            searchXmlVehicles, _ = ImGui.InputText("##searchXmlVehicles", searchXmlVehicles, 256)
                            ImGui.SameLine()
                            if ImGui.Button("Refresh##xmlVeh") then
                                refreshXmlVehicles()
                            end
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
                            if ImGui.Button("Refresh##iniVeh") then
                                refreshIniVehicles()
                            end
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
                            if ImGui.Button("Refresh##jsonVeh") then
                                refreshJsonVehicles()
                            end
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
                            if ImGui.Button("Refresh##chrxVeh") then
                                refreshChrxVehicles()
                            end
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

                    spawnerSettings.contextPreview = ImGui.Checkbox("Context Preview", spawnerSettings.contextPreview)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Light Blue = Networkable (under 80)\nOrange = Not everything will network")
                    end
                    spawnerSettings.teleportToMap = ImGui.Checkbox("Teleport to Map", spawnerSettings.teleportToMap)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Teleport to the map's reference coordinates when spawning (if available)")
                    end
                    spawnerSettings.spawnMapOnMe = ImGui.Checkbox("Spawn Map on Me", spawnerSettings.spawnMapOnMe)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Spawn the map at your current position instead of its original coordinates")
                    end

                    spawnerSettings.networkMapsV2Enabled = ImGui.Checkbox("Network Maps V2", spawnerSettings.networkMapsV2Enabled)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Uses a few networking natives to hopefully network better")
                    end
                    spawnerSettings.networkMapsV1Enabled = ImGui.Checkbox("Network Maps V1", spawnerSettings.networkMapsV1Enabled)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Don't use seems broken after the latest update")
                    end

                    spawnerSettings.deleteOldMap = ImGui.Checkbox("Delete Old Map", spawnerSettings.deleteOldMap)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete the previously spawned map when a new one is spawned")
                    end

                    ImGui.Spacing()

                    ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.157, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.22, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.10, 1.0)
                    if ImGui.Button("Delete All Spawned Maps") then
                        spawning.deleteAllSpawnedMaps()
                    end
                    ImGui.PopStyleColor(3)

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete all previously spawned map objects")
                    end

                    ImGui.Spacing()

                    ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.36, 0.157, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.46, 0.22, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.26, 0.10, 1.0)
                    if ImGui.Button("Teleport All Players To Me") then
                        FeatureMgr.GetFeatureByName("Teleport All To Me"):TriggerCallback()
                    end
                    ImGui.PopStyleColor(3)

                    ImGui.Spacing()

                    ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.157, 0.36, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.22, 0.46, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.10, 0.26, 1.0)
                    if ImGui.Button("Clear Area") then
                        FeatureMgr.GetFeatureByName("Clear Distance"):SetIntValue(1000)
                        FeatureMgr.GetFeatureByName("Clear Area"):TriggerCallback()
                    end
                    ImGui.PopStyleColor(3)

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Useful to clear the objects pool/network more map props")
                    end

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
                            ImGui.Text(displayName)
                            ImGui.SameLine()
                            
                            -- Green Teleport button
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.36, 0.157, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.46, 0.22, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.26, 0.10, 1.0)
                            if ImGui.Button("Teleport##map" .. i) then
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
                            end
                            ImGui.PopStyleColor(3)
                            
                            ImGui.SameLine()
                            
                            -- Blue Bring button (move map to player)
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.157, 0.36, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.22, 0.46, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.10, 0.26, 1.0)
                            if ImGui.Button("Bring##map" .. i) then
                                spawning.bringMapToPlayer(i)
                            end
                            ImGui.PopStyleColor(3)
                            
                            ImGui.SameLine()
                            
                            -- Red Delete button
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.016, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.06, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.01, 1.0)
                            if ImGui.Button("Delete##map" .. i) then
                                spawning.deleteMapByIndex(i)
                            end
                            ImGui.PopStyleColor(3)
                        end
                        ClickGUI.EndCustomChildWindow()
                    end
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("Maps") then
                    if ImGui.BeginTabBar("MapTypeTabs") then
                        if ImGui.BeginTabItem("XML") then
                            searchXmlMaps, _ = ImGui.InputText("##searchXmlMaps", searchXmlMaps, 256)
                            ImGui.SameLine()
                            if ImGui.Button("Refresh##xmlMaps") then
                                refreshXmlMaps()
                            end
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
                            if ImGui.Button("Refresh##jsonMaps") then
                                refreshJsonMaps()
                            end
                            ImGui.Spacing()

                            -- Scrollable child region for file list
                            ImGui.BeginChild("##jsonMapsList", 0, 475, false)
                            local jsonStructure = getJsonMaps()
                            renderFolderContents(jsonStructure, spawning.spawnMapFromJSON, searchJsonMaps, "jsonMaps", "map", hoverCallback)
                            ImGui.EndChild()
                            ImGui.EndTabItem()
                        end

                        ImGui.EndTabBar()
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

                    spawnerSettings.contextPreview = ImGui.Checkbox("Context Preview", spawnerSettings.contextPreview)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Light Blue = Networkable (under 80)\nOrange = Not everything will network")
                    end
                    spawnerSettings.previewOutfit = ImGui.Checkbox("Preview Outfit", spawnerSettings.previewOutfit)
                    
                    spawnerSettings.onlyApplyAttachments = ImGui.Checkbox("Only Apply Attachments", spawnerSettings.onlyApplyAttachments)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("May Break Positioning")
                    end
                    
                    spawnerSettings.deleteLastOutfitAttachments = ImGui.Checkbox("Delete Last Outfit Attachments", spawnerSettings.deleteLastOutfitAttachments)
                    
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
                        local oldFOVEnabled = spawnerSettings.thirdPersonFOVEnabled
                        spawnerSettings.thirdPersonFOVEnabled = ImGui.Checkbox("FOV Changer", spawnerSettings.thirdPersonFOVEnabled)
                        
                        if spawnerSettings.thirdPersonFOVEnabled ~= oldFOVEnabled then
                            -- Toggle the Cherax menu feature
                            thirdPersonFOVFeature:Toggle()
                            
                            if spawnerSettings.thirdPersonFOVEnabled then
                                -- Get current value or default to 50
                                local currentValue = spawnerSettings.thirdPersonFOVValue or 50
                                thirdPersonFOVFeature:SetIntValue(currentValue)
                                thirdPersonAimFOVFeature:SetIntValue(currentValue)
                            else
                                -- Reset to 0 when disabled
                                thirdPersonFOVFeature:SetIntValue(0)
                                thirdPersonAimFOVFeature:SetIntValue(0)
                            end
                        end
                        
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

                    ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.157, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.22, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.10, 1.0)
                    if ImGui.Button("Delete All Spawned Outfits") then
                        spawning.deleteAllSpawnedOutfits()
                    end
                    ImGui.PopStyleColor(3)

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete all previously spawned outfit attachments")
                    end

                    ImGui.Spacing()

                    ClickGUI.EndCustomChildWindow()
                    ImGui.Text("Cherax limits the attachments you can have")
                    ImGui.Text("on your character to 20")
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("Outfits") then
                    if ImGui.BeginTabBar("OutfitTypeTabs") then
                        if ImGui.BeginTabItem("XML") then
                            searchXmlOutfits, _ = ImGui.InputText("##searchXmlOutfits", searchXmlOutfits, 256)
                            ImGui.SameLine()
                            if ImGui.Button("Refresh##xmlOutfits") then
                                refreshXmlOutfits()
                            end
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
                            if ImGui.Button("Refresh##jsonOutfits") then
                                refreshJsonOutfits()
                            end
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
                            if ImGui.Button("Refresh##chrxOutfits") then
                                refreshChrxOutfits()
                            end
                            ImGui.Spacing()

                            -- Scrollable child region for file list
                            ImGui.BeginChild("##chrxOutfitsList", 0, 475, false)
                            local chrxStructure = getChrxOutfits()
                            renderFolderContents(chrxStructure, spawning.spawnOutfitFromCHRX, searchChrxOutfits, "chrxOutfits", "outfit", hoverCallback)
                            ImGui.EndChild()
                            ImGui.EndTabItem()
                        end

                        ImGui.EndTabBar()
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
                    
                    spawnerSettings.unloadLastIPL = ImGui.Checkbox("Unload Last IPL", spawnerSettings.unloadLastIPL)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Unload the previously loaded IPL group when loading a new one")
                    end
                    
                    ImGui.Spacing()
                    
                    -- Unload All button
                    ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.157, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.22, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.10, 1.0)
                    if ImGui.Button("Unload All IPLs") then
                        iplloader.unloadAllGroups()
                    end
                    ImGui.PopStyleColor(3)
                    
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Unload all currently loaded IPL groups")
                    end
                    
                    ImGui.Spacing()
                    ClickGUI.EndCustomChildWindow()
                end
                
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
                if ClickGUI.BeginCustomChildWindow("Special Stuff") then
                    ImGui.SetWindowFontScale(1.0)
                    
                    if ImGui.Button("Spawn Robot") then
                        robot.spawnRobot()
                    end

                    if ImGui.Button("Self Destruction") then
                        robot.selfDestructRobot()
                    end



                    ImGui.Spacing()
                    local oldUpsideDown = spawnerSettings.upsideDownMap
                    spawnerSettings.upsideDownMap = ImGui.Checkbox("Upside Down Map v3", spawnerSettings.upsideDownMap)
                    if spawnerSettings.upsideDownMap ~= oldUpsideDown then
                        upsidedownmap.toggle_upside_down_map(spawnerSettings.upsideDownMap)
                    end



                    ClickGUI.EndCustomChildWindow()
                end

                if ClickGUI.BeginCustomChildWindow("Debug") then
                    spawnerSettings.printToDebug = ImGui.Checkbox("Print Debug to Console", spawnerSettings.printToDebug)
                    spawnerSettings.spawnIn000Vehicle = ImGui.Checkbox("Spawn in Network v1 0 0 0 Vehicle", spawnerSettings.spawnIn000Vehicle)
                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.TableSetColumnIndex(1)
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
                    ClickGUI.EndCustomChildWindow()
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
                    
                    spawnerSettings.enableGizmo = ImGui.Checkbox("Enable Gizmo Arrows", spawnerSettings.enableGizmo)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Show 3D gizmo arrows on selected entities for positioning")
                    end
                    
                    spawnerSettings.showSpoonerControls = ImGui.Checkbox("Show Controls", spawnerSettings.showSpoonerControls)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Show the Spooner Controls info window in the bottom right")
                    end
                    

                    spawnerSettings.deletePhotoCache = ImGui.Checkbox("Delete Photo Cache After Exit", spawnerSettings.deletePhotoCache)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("When enabled, deletes all files in BiggerScript\\SpoonerAssets\\gtahashru\\objects and subfolders when script unloads")
                    end
                    
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
                    if spoonerEnabled then
                        -- Red when enabled (exit)
                        ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.1, 0.1, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.15, 0.15, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.08, 0.08, 1.0)
                    else
                        -- Green when disabled (launch)
                        ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.5, 0.15, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.6, 0.2, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.45, 0.12, 1.0)
                    end
                    
                    if ImGui.Button(spoonerButtonText, -1, 30) then
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
                    end
                    ImGui.PopStyleColor(3)
                    
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
                        if browserVisible then
                            -- Light blue when on
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.6, 0.9, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.7, 1.0, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.55, 0.85, 1.0)
                        else
                            -- Dark blue when off
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.2, 0.4, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.3, 0.5, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.18, 0.35, 1.0)
                        end
                        
                        if ImGui.Button("Browser", -1, 30) then
                            if browserVisible then
                                -- Toggle off
                                spooner.setBrowserVisible(false)
                            else
                                -- Close other windows first (mutual exclusivity)
                                spooner.closeAllSubWindows()
                                spooner.setBrowserVisible(true)
                            end
                        end
                        ImGui.PopStyleColor(3)
                        
                        ImGui.Spacing()
                        
                        -- PED Customizations button (dark blue when off, light blue when on)
                        local pedCustomsVisible = spooner.getPedCustomsVisible()
                        if pedCustomsVisible then
                            -- Light blue when on
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.6, 0.9, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.7, 1.0, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.55, 0.85, 1.0)
                        else
                            -- Dark blue when off
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.2, 0.4, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.3, 0.5, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.18, 0.35, 1.0)
                        end
                        
                        if ImGui.Button("PED Customizations", -1, 30) then
                            if pedCustomsVisible then
                                -- Toggle off
                                spooner.setPedCustomsVisible(false)
                            else
                                -- Close other windows first (mutual exclusivity)
                                spooner.closeAllSubWindows()
                                -- Open ped customizations with player's ped
                                spooner.openPlayerPedCustomizations()
                            end
                        end
                        ImGui.PopStyleColor(3)
                    
                        ImGui.Spacing()
                        
                        -- Vehicle Customizations button (dark blue when off, light blue when on)
                        local vehicleCustomsVisible = spooner.getVehicleCustomsVisible()
                        if vehicleCustomsVisible then
                            -- Light blue when on
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.6, 0.9, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.7, 1.0, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.55, 0.85, 1.0)
                        else
                            -- Dark blue when off
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.2, 0.4, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.3, 0.5, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.18, 0.35, 1.0)
                        end
                        
                        if ImGui.Button("Vehicle Customizations", -1, 30) then
                            if vehicleCustomsVisible then
                                -- Toggle off
                                spooner.setVehicleCustomsVisible(false)
                            else
                                -- Close other windows first (mutual exclusivity)
                                spooner.closeAllSubWindows()
                                -- Try to open vehicle customizations
                                local success, errorMsg = spooner.openPlayerVehicleCustomizations()
                                if not success then
                                    GUI.AddToast("Spooner", errorMsg or "You need to be in a vehicle", 2000, 0)
                                end
                            end
                        end
                        ImGui.PopStyleColor(3)
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

        ImGui.EndTabBar()
    end
    spawning.managePreview(hoveredFileThisFrame)
end

ClickGUI.AddTab("Bigger Script", renderMenyooTab)


ClickGUI.AddPlayerTab("Bigger Script", function()
    if ClickGUI.BeginCustomChildWindow("Send Vehicles") then

        ClickGUI.RenderFeature(Utils.Joaat("DeleteMenyooAttackerVehicle"), Utils.GetSelectedPlayer())
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.157, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.22, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.10, 1.0)
        if ImGui.Button("Delete All") then
            spawning.deleteAllSpawnedVehicles()
        end
        ImGui.PopStyleColor(3)
        
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
            local targetName = PLAYER.GET_PLAYER_NAME(Utils.GetSelectedPlayer()) or "Target"
            ImGui.SetTooltip("Attacker: Spawns vehicle with ped that chases " .. targetName .. "\nGift: Spawns vehicle in front of " .. targetName .. "\nApply: Applies attachments to " .. targetName .. "'s current vehicle")
        end
        ImGui.Spacing()

        if ImGui.BeginTabBar("AttackerTypeTabs") then
            if ImGui.BeginTabItem("XML") then
                local xmlFiles = getXmlFiles()
                local targetPlayer = Utils.GetSelectedPlayer()
                local attackerSpawnFunc = function(filePath)
                    local mode = spawnerSettings.attackerSpawnMode
                    if mode == 0 then
                        spawning.spawnMenyooAttackerFromXML(filePath, targetPlayer)
                    elseif mode == 1 then
                        spawning.spawnGiftVehicleFromXML(filePath, targetPlayer)
                    elseif mode == 2 then
                        spawning.applyVehicleAttachmentsFromXML(filePath, targetPlayer)
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
                    if mode == 0 then
                        spawning.spawnMenyooAttackerFromINI(filePath, targetPlayer)
                    elseif mode == 1 then
                        spawning.spawnGiftVehicleFromINI(filePath, targetPlayer)
                    elseif mode == 2 then
                        spawning.applyVehicleAttachmentsFromINI(filePath, targetPlayer)
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
                    if mode == 0 then
                        spawning.spawnMenyooAttackerFromJSON(filePath, targetPlayer)
                    elseif mode == 1 then
                        spawning.spawnGiftVehicleFromJSON(filePath, targetPlayer)
                    elseif mode == 2 then
                        spawning.applyVehicleAttachmentsFromJSON(filePath, targetPlayer)
                    end
                end
                local searchJsonAttackers = ImGui.InputText("##searchJsonAttackers", searchJsonAttackers or "", 256)
                ImGui.Spacing()
                renderFolderContents(jsonFiles, attackerSpawnFunc, searchJsonAttackers, "jsonAttackers")
                ImGui.EndTabItem()
            end

            if ImGui.BeginTabItem("Robot Attacker") then
                if ImGui.Button("Spawn Robot Attacker") then
                    local targetPlayer = Utils.GetSelectedPlayer()
                    robot.spawnRobotAttacker(targetPlayer)
                end
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end

        ClickGUI.EndCustomChildWindow()
    end
end)

