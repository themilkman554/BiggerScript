---bigger script
GUI.AddToast("BiggerScriptv5.3", "Added FOV Changer in outfits\n Things should now be deleted for other players", 10000, 0)

if Cherax.GetEdition() == "LE" then
    GUI.AddToast("BiggerScript", "Legacy Version of Cherax breaks vehicles with too many attachments", 10000, 0)
end
package.path = FileMgr.GetMenuRootPath() .. "\\Lua\\?.lua;"

local function IsLoadedFromFile()
    if debug and debug.getinfo then
        local info = debug.getinfo(1, "S")
        if info and info.source then
            local source = info.source
            if string.sub(source, 1, 1) == "@" then
                source = string.sub(source, 2)
            end
            if string.find(source, "\\") or string.find(source, "/") then
                return true
            end
        end
    end
    return false
end

local LoadLocalLibraries = IsLoadedFromFile()
if LoadLocalLibraries then
    print("BiggerScript: Detected local execution, using local libraries.")
else
    print("BiggerScript: Detected remote execution, using GitHub libraries.")
end

local GITHUB_RAW_BASE_URL = "https://raw.githubusercontent.com/themilkman554/BiggerScript/main/"

local function curl_get_content(url)
    print("Fetching: " .. url)
    local curlObject = Curl.Easy()

    curlObject:Setopt(10002, url)
    curlObject:Perform()

    while not curlObject:GetFinished() do
        Script.Yield(10)
    end

    local code, response = curlObject:GetResponse()


    if code == 0 then
        return response
    else
        print("Curl error for " .. url .. ": " .. tostring(code))
        return nil
    end
end

if not LoadLocalLibraries then
    Script.QueueJob(function()
        local menuRoot = FileMgr.GetMenuRootPath()
        local oldLoaderPath = menuRoot .. "\\Lua\\BiggerScriptLoader.lua"
        if FileMgr.DoesFileExist(oldLoaderPath) then
            GUI.AddToast("BiggerScript", "Downloading New Loader please restart Script/refrest files for loaderv2", 10000, 0)
            FileMgr.DeleteFile(oldLoaderPath)
            
            local newLoaderUrl = "https://raw.githubusercontent.com/themilkman554/BiggerScript/refs/heads/main/BiggerScriptLoaderv2.lua"
            local content = curl_get_content(newLoaderUrl)
            
            if content then
                local newLoaderPath = menuRoot .. "\\Lua\\BiggerScriptLoaderv2.lua"
                local file = io.open(newLoaderPath, "w")
                if file then
                    file:write(content)
                    file:close()

                    if Script.SetShouldUnload then
                        Script.SetShouldUnload(true)
                    end
                    return
                else
                    print("BiggerScript: Failed to save new loader to " .. newLoaderPath)
                end
            else
                print("BiggerScript: Failed to download new loader from " .. newLoaderUrl)
            end
        end
    end)
end

local function load_from_github(path)
    local url = GITHUB_RAW_BASE_URL .. path
    local content = curl_get_content(url)
    if content then
        local chunk, err = load(content, "@" .. path)
        if chunk then
            local success, result = pcall(chunk)
            if success then
                return result
            else
                print("Error executing script from " .. url .. ": " .. tostring(result))
            end
        else
            print("Error loading script from " .. url .. ": " .. err)
        end
    end
    return nil
end

-- Load libraries
local upsidedownmap, spawning, robot, constructor_lib, vehicle_fly



require("BiggerScript/natives/natives")

local menuRootPath = FileMgr.GetMenuRootPath()
local biggerScriptRootPath = menuRootPath .. "\\Lua\\BiggerScript"
local xmlVehiclesFolder = biggerScriptRootPath .. "\\XML Vehicles"
local iniVehiclesFolder = biggerScriptRootPath .. "\\INI Vehicles"
local jsonVehiclesFolder = biggerScriptRootPath .. "\\JSON Vehicles"
local xmlMapsFolder = biggerScriptRootPath .. "\\XML Maps"
local jsonMapsFolder = biggerScriptRootPath .. "\\JSON Maps"
local xmlOutfitsFolder = biggerScriptRootPath .. "\\XML Outfits"
local jsonOutfitsFolder = biggerScriptRootPath .. "\\JSON Outfits"


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
    vehicleFly = false,
    upsideDownMap = false,
    radioOff = false,
    onlyApplyAttachments = false,
    deleteLastOutfitAttachments = false,
    autoLoadScript = false
}


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
        ImGui.SetNextItemOpen(true)
        isOpen = ImGui.TreeNode(folderName)
    else
        local currentState = folderStates[currentPath]
        if currentState ~= nil then
            ImGui.SetNextItemOpen(currentState)
        end
        isOpen = ImGui.TreeNode(folderName)
        folderStates[currentPath] = isOpen
    end

    if isOpen then
        local subFolders = {}
        for subFolderName, subFolderData in pairs(folderData.folders) do table.insert(subFolders, {name = subFolderName, data = subFolderData}) end
        table.sort(subFolders, function(a, b) return a.name < b.name end)
        for _, subFolder in ipairs(subFolders) do renderFolder(subFolder.name, subFolder.data, spawnFunction, filterText, currentPath, searchId, itemType, hoverCallback) end

        local sortedFiles = {}
        for _, fileData in ipairs(folderData.files) do table.insert(sortedFiles, fileData) end
        table.sort(sortedFiles, function(a, b) return a.name < b.name end)
        for _, fileData in ipairs(sortedFiles) do
            if not filterText or filterText == "" or string.find(fileData.name:lower(), filterText:lower()) then
                if ImGui.Selectable(fileData.name) then
                    local selectedPath = fileData.fullPath
                    local norm = selectedPath:gsub("\\", "/")
                    local baseNorm = xmlVehiclesFolder:gsub("\\", "/")
                    if norm:sub(1, #baseNorm) == baseNorm then currentSelectedVehicleXml = selectedPath end
                    spawning.debug_print("[UI Debug] Selected XML vehicle:", selectedPath)
                    if spawnFunction then
                        if spawnFunction == iniAttackerSelectFunction then
                            spawnFunction(selectedPath)
                        else
                            Script.QueueJob(function() spawnFunction(selectedPath) end)
                        end
                    end
                end
                if ImGui.IsItemHovered() and hoverCallback then
                    hoverCallback({ path = fileData.fullPath, type = itemType })
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
    table.sort(subFolders, function(a, b) return a.name < b.name end)
    for _, sub in ipairs(subFolders) do
        renderFolder(sub.name, sub.data, spawnFunction, filterText, nil, searchId, itemType, hoverCallback)
    end


    local files = {}
    for _, f in ipairs(folderData.files) do table.insert(files, f) end
    table.sort(files, function(a, b) return a.name < b.name end)
    for _, fileData in ipairs(files) do
        if not filterText or string.find(fileData.name:lower(), filterText:lower()) then
            if ImGui.Selectable(fileData.name) then
                local selectedPath = fileData.fullPath
                spawning.debug_print("[UI Debug] Selected " .. (itemType or "item") .. ":", selectedPath)
                currentSelectedVehicleXml = selectedPath
                if spawnFunction then
                    Script.QueueJob(function() spawnFunction(selectedPath) end)
                end
            end
            if ImGui.IsItemHovered() and hoverCallback then
                hoverCallback({ path = fileData.fullPath, type = itemType })
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
local searchXmlMaps = ""
local searchJsonMaps = ""
local searchXmlOutfits = ""
local searchJsonOutfits = ""

local initialized = false

local function Initialize()
    if LoadLocalLibraries then
        upsidedownmap = require("BiggerScript/lib/upsidedownmap")
        spawning = require("BiggerScript/lib/spawning")
        robot = require("BiggerScript/lib/robot")
        constructor_lib = require("BiggerScript/lib/constructor_lib")
        vehicle_fly = require("BiggerScript/lib/vehicle_fly")
    else
        upsidedownmap = load_from_github("BiggerScript/lib/upsidedownmap.lua")
        if not upsidedownmap then print("Failed to load upsidedownmap.lua"); return end

        spawning = load_from_github("BiggerScript/lib/spawning.lua")
        if not spawning then print("Failed to load spawning.lua"); return end

        robot = load_from_github("BiggerScript/lib/robot.lua")
        if not robot then print("Failed to load robot.lua"); return end

        constructor_lib = load_from_github("BiggerScript/lib/constructor_lib.lua")
        if not constructor_lib then print("Failed to load constructor_lib.lua"); return end

        vehicle_fly = load_from_github("BiggerScript/lib/vehicle_fly.lua")
        if not vehicle_fly then print("Failed to load vehicle_fly.lua"); return end
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
        currentSelectedVehicleIni = currentSelectedVehicleIni
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

    initialized = true
end

Script.QueueJob(Initialize)



local function renderMenyooTab()
    if not initialized then
        ImGui.Text("Loading libraries... Please wait.")
        return
    end
    local hoveredFileThisFrame = nil
    local function hoverCallback(file)
        hoveredFileThisFrame = file
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

                    spawnerSettings.inVehicle = ImGui.Checkbox("In Vehicle", spawnerSettings.inVehicle)
                    spawnerSettings.spawnPlaneInTheAir = ImGui.Checkbox("Spawn Aircraft In The Air", spawnerSettings.spawnPlaneInTheAir)
                    spawnerSettings.deleteOldVehicle = ImGui.Checkbox("Delete Old Vehicle", spawnerSettings.deleteOldVehicle)
                    spawnerSettings.vehicleGodMode = ImGui.Checkbox("Vehicle God Mode", spawnerSettings.vehicleGodMode)
                    spawnerSettings.vehicleEngineOn = ImGui.Checkbox("Vehicle Engine On", spawnerSettings.vehicleEngineOn)
                    spawnerSettings.radioOff = ImGui.Checkbox("Radio Off", spawnerSettings.radioOff)
                    spawnerSettings.upgradedVehicle = ImGui.Checkbox("Upgraded Vehicle", spawnerSettings.upgradedVehicle)
                    spawnerSettings.randomColor = ImGui.Checkbox("Random Color", spawnerSettings.randomColor)
                    spawnerSettings.randomLivery = ImGui.Checkbox("Random Livery", spawnerSettings.randomLivery)
                    spawnerSettings.previewVehicle = ImGui.Checkbox("Preview Vehicle", spawnerSettings.previewVehicle)
                    
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

                            local xmlStructure = getXmlFiles()
                            renderFolderContents(xmlStructure, spawning.spawnVehicleFromXML, searchXmlVehicles, "xmlVehicles", "vehicle", hoverCallback)
                            ImGui.EndTabItem()
                        end

                        if ImGui.BeginTabItem("INI") then
                            searchIniVehicles, _ = ImGui.InputText("##searchIniVehicles", searchIniVehicles, 256)
                            ImGui.SameLine()
                            if ImGui.Button("Refresh##iniVeh") then
                                refreshIniVehicles()
                            end
                            ImGui.Spacing()

                            local iniStructure = getIniVehicles()
                            renderFolderContents(iniStructure, spawning.spawnVehicleFromINI, searchIniVehicles, "iniVehicles", "vehicle", hoverCallback)
                            ImGui.EndTabItem()
                        end

                        if ImGui.BeginTabItem("JSON") then
                            searchJsonVehicles, _ = ImGui.InputText("##searchJsonVehicles", searchJsonVehicles, 256)
                            ImGui.SameLine()
                            if ImGui.Button("Refresh##jsonVeh") then
                                refreshJsonVehicles()
                            end
                            ImGui.Spacing()

                            local jsonStructure = getJsonVehicles()
                            renderFolderContents(jsonStructure, spawning.spawnVehicleFromJSON, searchJsonVehicles, "jsonVehicles", "vehicle", hoverCallback)
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

                    spawnerSettings.teleportToMap = ImGui.Checkbox("Teleport to Map", spawnerSettings.teleportToMap)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Teleport to the map's reference coordinates when spawning (if available)")
                    end

                    spawnerSettings.networkMapsV2Enabled = ImGui.Checkbox("Network Maps V2", spawnerSettings.networkMapsV2Enabled)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Uses a few networking natives to hopefully network better")
                    end
                    spawnerSettings.networkMapsV1Enabled = ImGui.Checkbox("Network Maps V1", spawnerSettings.networkMapsV1Enabled)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Spawns a vehicle at 0,0,0 and attaches everything to it (sometimes networks bettert)")
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

                            local xmlStructure = getXmlMaps()
                            renderFolderContents(xmlStructure, spawning.spawnMapFromXML, searchXmlMaps, "xmlMaps", "map", function() end)
                            ImGui.EndTabItem()
                        end

                        if ImGui.BeginTabItem("JSON") then
                            searchJsonMaps, _ = ImGui.InputText("##searchJsonMaps", searchJsonMaps, 256)
                            ImGui.SameLine()
                            if ImGui.Button("Refresh##jsonMaps") then
                                refreshJsonMaps()
                            end
                            ImGui.Spacing()

                            local jsonStructure = getJsonMaps()
                            renderFolderContents(jsonStructure, spawning.spawnMapFromJSON, searchJsonMaps, "jsonMaps", "map", function() end)
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
                    ImGui.Text("Cherax limits the attachments you can have on your character")
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

                            local xmlStructure = getXmlOutfits()
                            renderFolderContents(xmlStructure, spawning.spawnOutfitFromXML, searchXmlOutfits, "xmlOutfits", "outfit", hoverCallback)
                            ImGui.EndTabItem()
                        end

                        if ImGui.BeginTabItem("JSON") then
                            searchJsonOutfits, _ = ImGui.InputText("##searchJsonOutfits", searchJsonOutfits, 256)
                            ImGui.SameLine()
                            if ImGui.Button("Refresh##jsonOutfits") then
                                refreshJsonOutfits()
                            end
                            ImGui.Spacing()

                            local jsonStructure = getJsonOutfits()
                            renderFolderContents(jsonStructure, spawning.spawnOutfitFromJSON, searchJsonOutfits, "jsonOutfits", "outfit", hoverCallback)
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

                    ImGui.Spacing()
                    local oldAutoLoad = spawnerSettings.autoLoadScript
                    spawnerSettings.autoLoadScript = ImGui.Checkbox("Auto Load Script", spawnerSettings.autoLoadScript)
                    if spawnerSettings.autoLoadScript ~= oldAutoLoad then
                        local startupPath = FileMgr.GetMenuRootPath() .. "\\Lua\\Startup.lua"
                        local scriptToLoad
                        if LoadLocalLibraries then
                            scriptToLoad = "BiggerScript.lua"
                        else
                            scriptToLoad = "BiggerScriptLoaderv2.lua"
                        end
                        
                        local executeScriptLine = "Utils.ExecuteScript(\"" .. scriptToLoad .. "\")"
                        
                        -- Read current Startup.lua content
                        local file = io.open(startupPath, "r")
                        if file then
                            local content = file:read("*all")
                            file:close()
                            
                            if spawnerSettings.autoLoadScript then
                                -- Add the line if not already present
                                if not content:find(executeScriptLine, 1, true) then
                                    -- Find the line with "-- Utils.ExecuteScript" comment
                                    local insertPos = content:find("-- Utils%.ExecuteScript%(\"MyScript%.lua\"%)")
                                    if insertPos then
                                        -- Insert after the comment line
                                        local lineEnd = content:find("\n", insertPos)
                                        if lineEnd then
                                            content = content:sub(1, lineEnd) .. executeScriptLine .. "\n" .. content:sub(lineEnd + 1)
                                        end
                                    else
                                        -- Fallback: insert before SetShouldUnload()
                                        local unloadPos = content:find("SetShouldUnload%(%)") or content:find("-- Load Default Feature Settings")
                                        if unloadPos then
                                            content = content:sub(1, unloadPos - 1) .. executeScriptLine .. "\n" .. content:sub(unloadPos)
                                        end
                                    end
                                    
                                    -- Write back to file
                                    file = io.open(startupPath, "w")
                                    if file then
                                        file:write(content)
                                        file:close()
                                        GUI.AddToast("BiggerScript", "Added auto-load to Startup.lua: " .. scriptToLoad, 5000, 0)
                                    end
                                end
                            else
                                -- Remove the line
                                local pattern = executeScriptLine:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                                content = content:gsub(pattern .. "\r?\n?", "")
                                
                                -- Write back to file
                                file = io.open(startupPath, "w")
                                if file then
                                    file:write(content)
                                    file:close()
                                    GUI.AddToast("BiggerScript", "Removed auto-load from Startup.lua", 5000, 0)
                                end
                            end
                        else
                            GUI.AddToast("BiggerScript", "Failed to open Startup.lua", 5000, 0)
                        end
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
                    ImGui.Text("Everyone who made and shared their creations")
                    ImGui.Text("Ai Free Usage")
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
    if ClickGUI.BeginCustomChildWindow("Attacker Vehicles") then

        ClickGUI.RenderFeature(Utils.Joaat("DeleteMenyooAttackerVehicle"), Utils.GetSelectedPlayer())
        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.157, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.22, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.10, 1.0)
        if ImGui.Button("Delete All Attackers") then
            spawning.deleteAllSpawnedVehicles()
        end
        ImGui.PopStyleColor(3)
        ImGui.Spacing()

        if ImGui.BeginTabBar("AttackerTypeTabs") then
            if ImGui.BeginTabItem("XML") then
                local xmlFiles = getXmlFiles()
                local targetPlayer = Utils.GetSelectedPlayer()
                local attackerSpawnFunc = function(filePath)
                    spawning.spawnMenyooAttackerFromXML(filePath, targetPlayer)
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
                    spawning.spawnMenyooAttackerFromINI(filePath, targetPlayer)
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
                    spawning.spawnMenyooAttackerFromJSON(filePath, targetPlayer)
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


