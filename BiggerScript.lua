---bigger script

package.path = FileMgr.GetMenuRootPath() .. "\\Lua\\?.lua;"

local GITHUB_RAW_BASE_URL = "https://raw.githubusercontent.com/themilkman554/BiggerScript/main/"

local function curl_get_content(url)
    print("Fetching: " .. url)
    local curlObject = Curl.Easy()
    -- 10002 is CURLOPT_URL
    curlObject:Setopt(10002, url)
    curlObject:Perform()

    while not curlObject:GetFinished() do
        Script.Yield(10) -- Yield a bit to not hog the thread
    end

    local code, response = curlObject:GetResponse()

    -- 0 is CURLE_OK
    if code == 0 then
        return response
    else
        print("Curl error for " .. url .. ": " .. tostring(code))
        return nil
    end
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
local upsidedownmap = load_from_github("BiggerScript/lib/upsidedownmap.lua")
if not upsidedownmap then print("Failed to load upsidedownmap.lua"); return end

local spawning = load_from_github("BiggerScript/lib/spawning.lua")
if not spawning then print("Failed to load spawning.lua"); return end

local robot = load_from_github("BiggerScript/lib/robot.lua")
if not robot then print("Failed to load robot.lua"); return end
require("BiggerScript/natives/natives")
GUI.AddToast("BiggerScript", "BiggerScriptV4 Changelog Added Previews", 5000, 0)
local menuRootPath = FileMgr.GetMenuRootPath()
local biggerScriptRootPath = menuRootPath .. "\\Lua\\BiggerScript"
local xmlVehiclesFolder = biggerScriptRootPath .. "\\XML Vehicles"
local iniVehiclesFolder = biggerScriptRootPath .. "\\INI Vehicles"
local xmlMapsFolder = biggerScriptRootPath .. "\\XML Maps"
local xmlOutfitsFolder = biggerScriptRootPath .. "\\XML Outfits"

if not FileMgr.DoesFileExist(xmlVehiclesFolder) then
    FileMgr.CreateDir(xmlVehiclesFolder)
end

if not FileMgr.DoesFileExist(iniVehiclesFolder) then
    FileMgr.CreateDir(iniVehiclesFolder)
end

if not FileMgr.DoesFileExist(xmlMapsFolder) then
    FileMgr.CreateDir(xmlMapsFolder)
end

if not FileMgr.DoesFileExist(xmlOutfitsFolder) then
    FileMgr.CreateDir(xmlOutfitsFolder)
end


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
    previewOutfit = false
}


local previewEntities = {}
local currentPreviewFile = nil



local constructor_lib = {}

constructor_lib.set_entity_as_networked = function(attachment, timeout)
    local time <const> = Time.GetEpocheMs() + (timeout or 1500)
    while time > Time.GetEpocheMs() and not NETWORK.NETWORK_GET_ENTITY_IS_NETWORKED(attachment.handle) do
        NETWORK.NETWORK_REGISTER_ENTITY_AS_NETWORKED(attachment.handle)
        Script.Yield(0)
    end
    return NETWORK.NETWORK_GET_ENTITY_IS_NETWORKED(attachment.handle)
end

constructor_lib.constantize_network_id = function(attachment)
    constructor_lib.set_entity_as_networked(attachment, 25)
    local net_id <const> = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(attachment.handle)
    -- network.set_network_id_can_migrate(net_id, false) -- Caused players unable to drive vehicles
    NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(net_id, true)
    NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(net_id, players.user(), true)
    return net_id
end

constructor_lib.make_entity_networked = function(attachment)
    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(attachment.handle, false, true)
    ENTITY.SET_ENTITY_SHOULD_FREEZE_WAITING_ON_COLLISION(attachment.handle, false)
    constructor_lib.constantize_network_id(attachment)
    NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.OBJ_TO_NET(attachment.handle), false)
end



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
                table.insert(cur.files, { name = part, fullPath = filePath })
            else
                cur.folders[part] = cur.folders[part] or { folders = {}, files = {} }
                cur = cur.folders[part]
            end
        end
    end
    return structure
end

local function getXmlFiles()
    local files = FileMgr.FindFiles(xmlVehiclesFolder, ".xml", true)
    if not files or #files == 0 then return { folders = {}, files = {} } end
    return buildFolderStructure(files, xmlVehiclesFolder)
end

local function getIniVehicles()
    local files = FileMgr.FindFiles(iniVehiclesFolder, ".ini", true)
    if not files or #files == 0 then return { folders = {}, files = {} } end
    return buildFolderStructure(files, iniVehiclesFolder)
end

local function getXmlMaps()
    local files = FileMgr.FindFiles(xmlMapsFolder, ".xml", true)
    if not files or #files == 0 then return { folders = {}, files = {} } end
    return buildFolderStructure(files, xmlMapsFolder)
end

local function getXmlOutfits()
    local files = FileMgr.FindFiles(xmlOutfitsFolder, ".xml", true)
    if not files or #files == 0 then return { folders = {}, files = {} } end
    return buildFolderStructure(files, xmlOutfitsFolder)
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
                spawning.debug_print("[UI Debug] Selected XML vehicle:", selectedPath)
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
local searchXmlMaps = ""
local searchXmlOutfits = ""

local function renderMenyooTab()
    local hoveredFileThisFrame = nil
    local function hoverCallback(file)
        hoveredFileThisFrame = file
    end

    if ImGui.BeginTabBar("MenyooTabs") then
        if ImGui.BeginTabItem("XML Vehicles") then
            local columns = 2
            if ImGui.BeginTable("XML Vehicles", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Spawner Settings") then
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()

                    spawnerSettings.inVehicle = ImGui.Checkbox("In Vehicle", spawnerSettings.inVehicle)
                    spawnerSettings.spawnPlaneInTheAir = ImGui.Checkbox("Spawn Aircraft In The Air", spawnerSettings.spawnPlaneInTheAir)
                    spawnerSettings.deleteOldVehicle = ImGui.Checkbox("Delete Old Vehicle", spawnerSettings.deleteOldVehicle)
                    spawnerSettings.vehicleGodMode = ImGui.Checkbox("Vehicle God Mode", spawnerSettings.vehicleGodMode)
                    spawnerSettings.vehicleEngineOn = ImGui.Checkbox("Vehicle Engine On", spawnerSettings.vehicleEngineOn)
                    spawnerSettings.upgradedVehicle = ImGui.Checkbox("Upgraded Vehicle", spawnerSettings.upgradedVehicle)
                    spawnerSettings.randomColor = ImGui.Checkbox("Random Color", spawnerSettings.randomColor)
                    spawnerSettings.randomLivery = ImGui.Checkbox("Random Livery", spawnerSettings.randomLivery)
                    spawnerSettings.printToDebug = ImGui.Checkbox("Print Debug to Console", spawnerSettings.printToDebug)
                    spawnerSettings.previewVehicle = ImGui.Checkbox("Preview Vehicle", spawnerSettings.previewVehicle)
                    ImGui.Spacing()


                    if ImGui.Button("Delete All Spawned Vehicles") then
                        spawning.deleteAllSpawnedVehicles()
                    end

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete all previously spawned vehicles and their attachments")
                    end

                    ImGui.Spacing()


                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("XML Vehicles") then

                    searchXmlVehicles, _ = ImGui.InputText("##searchXmlVehicles", searchXmlVehicles, 256)
                    ImGui.Spacing()

                    local xmlStructure = getXmlFiles()
                    renderFolderContents(xmlStructure, spawning.spawnVehicleFromXML, searchXmlVehicles, "xmlVehicles", "vehicle", hoverCallback)

                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.EndTable()
            end

            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("INI Vehicles") then
            local columns = 2
            if ImGui.BeginTable("INI Vehicles", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Spawner Settings") then
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()

                    spawnerSettings.inVehicle = ImGui.Checkbox("In Vehicle", spawnerSettings.inVehicle)
                    spawnerSettings.spawnPlaneInTheAir = ImGui.Checkbox("Spawn Aircraft In The Air", spawnerSettings.spawnPlaneInTheAir)
                    spawnerSettings.deleteOldVehicle = ImGui.Checkbox("Delete Old Vehicle", spawnerSettings.deleteOldVehicle)
                    spawnerSettings.vehicleGodMode = ImGui.Checkbox("Vehicle God Mode", spawnerSettings.vehicleGodMode)
                    spawnerSettings.vehicleEngineOn = ImGui.Checkbox("Vehicle Engine On", spawnerSettings.vehicleEngineOn)
                    spawnerSettings.upgradedVehicle = ImGui.Checkbox("Upgraded Vehicle", spawnerSettings.upgradedVehicle)
                    spawnerSettings.randomColor = ImGui.Checkbox("Random Color", spawnerSettings.randomColor)
                    spawnerSettings.randomLivery = ImGui.Checkbox("Random Livery", spawnerSettings.randomLivery)
                    spawnerSettings.printToDebug = ImGui.Checkbox("Print Debug to Console", spawnerSettings.printToDebug)
                    spawnerSettings.previewVehicle = ImGui.Checkbox("Preview Vehicle", spawnerSettings.previewVehicle)
                    ImGui.Spacing()


                    if ImGui.Button("Delete All Spawned Vehicles") then
                        spawning.deleteAllSpawnedVehicles()
                    end

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete all previously spawned vehicles and their attachments")
                    end

                    ImGui.Spacing()


                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("INI Vehicles") then

                    searchIniVehicles, _ = ImGui.InputText("##searchIniVehicles", searchIniVehicles, 256)
                    ImGui.Spacing()

                    local iniStructure = getIniVehicles()
                    renderFolderContents(iniStructure, spawning.spawnVehicleFromINI, searchIniVehicles, "iniVehicles", "vehicle", hoverCallback)

                    ClickGUI.EndCustomChildWindow()
                end


                ImGui.EndTable()
            end

            ImGui.EndTabItem()
        end


        if ImGui.BeginTabItem("XML Maps") then
            local columns = 2
            if ImGui.BeginTable("XML Maps", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Map Settings") then
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()

                    spawnerSettings.networkMapsV2Enabled = ImGui.Checkbox("Network Maps V2", spawnerSettings.networkMapsV2Enabled)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Enable networking for spawned map objects (requires constructor_lib functions)")
                    end
                    spawnerSettings.networkMapsV1Enabled = ImGui.Checkbox("Network Maps V1", spawnerSettings.networkMapsV1Enabled)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Enable networking for spawned map objects using the older attachment method (spawns a vehicle at 0,0,0 and attaches everything to it)")
                    end
                    spawnerSettings.spawnIn000Vehicle = ImGui.Checkbox("[Debug] Spawn in 0 0 0 Vehicle", spawnerSettings.spawnIn000Vehicle)

                    spawnerSettings.deleteOldMap = ImGui.Checkbox("Delete Old Map", spawnerSettings.deleteOldMap)
                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete the previously spawned map when a new one is spawned")
                    end
                    ImGui.Spacing()

                    if ImGui.Button("Delete All Spawned Maps") then
                        spawning.deleteAllSpawnedMaps()
                    end

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete all previously spawned map objects")
                    end

                    ImGui.Spacing()

                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("XML Maps") then

                    searchXmlMaps, _ = ImGui.InputText("##searchXmlMaps", searchXmlMaps, 256)
                    ImGui.Spacing()

                    local xmlStructure = getXmlMaps()
                    renderFolderContents(xmlStructure, spawning.spawnMapFromXML, searchXmlMaps, "xmlMaps", "map", function() end)

                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("XML Outfits") then
            local columns = 2
            if ImGui.BeginTable("XML Outfits", columns, ImGuiTableFlags.SizingStretchSame) then
                ImGui.TableNextRow()
                ImGui.TableSetColumnIndex(0)
                if ClickGUI.BeginCustomChildWindow("Outfit Settings") then
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.Spacing()

                    spawnerSettings.previewOutfit = ImGui.Checkbox("Preview Outfit", spawnerSettings.previewOutfit)
                    ImGui.Spacing()

                    if ImGui.Button("Delete All Spawned Outfits") then
                        spawning.deleteAllSpawnedOutfits()
                    end

                    if ImGui.IsItemHovered() then
                        ImGui.SetTooltip("Delete all previously spawned outfit attachments")
                    end

                    ImGui.Spacing()

                    ClickGUI.EndCustomChildWindow()
                                        ImGui.Text("I think Cherax does something that limits the attachments")
                                        ImGui.Text("the attachments that your character I can spawn them")
                                        ImGui.Text("and have them on but if I switch to them")
                                        ImGui.Text("or just attach them to myself they detach")
                end

                ImGui.TableSetColumnIndex(1)
                if ClickGUI.BeginCustomChildWindow("XML Outfits") then


                    searchXmlOutfits, _ = ImGui.InputText("##searchXmlOutfits", searchXmlOutfits, 256)
                    ImGui.Spacing()

                    local xmlStructure = getXmlOutfits()
                    renderFolderContents(xmlStructure, spawning.spawnOutfitFromXML, searchXmlOutfits, "xmlOutfits", "outfit", hoverCallback)

                    ClickGUI.EndCustomChildWindow()
                end

                ImGui.EndTable()
            end
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Special") then
            if ClickGUI.BeginCustomChildWindow("Special Stuff") then
                ImGui.SetWindowFontScale(1.0)
                
                if ImGui.Button("Spawn Robot") then
                    robot.spawnRobot()
                end

                if ImGui.Button("Self Destruction") then
                    robot.selfDestructRobot()
                end

                ImGui.Spacing()
                if ImGui.Button("Upside Down Map v3") then
                    spawning.spawnUpsideDownMapV3()
                end

                ClickGUI.EndCustomChildWindow()
            end
            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end
    spawning.managePreview(hoveredFileThisFrame)
end

ClickGUI.AddTab("bigger script", renderMenyooTab)


ClickGUI.AddPlayerTab("Bigger Script", function()
    if ClickGUI.BeginCustomChildWindow("Bigger Script Player Features") then

        ClickGUI.RenderFeature(Utils.Joaat("DeleteMenyooAttackerVehicle"), Utils.GetSelectedPlayer())
        ImGui.Spacing()

        if ImGui.BeginTabBar("AttackerTypeTabs") then
            if ImGui.BeginTabItem("XML Attackers") then
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

            if ImGui.BeginTabItem("INI Attackers") then
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
    xmlMapsFolder = xmlMapsFolder,
    xmlOutfitsFolder = xmlOutfitsFolder,
    spawnedProps = spawnedProps,
    currentSelectedVehicleXml = currentSelectedVehicleXml,
    currentSelectedVehicleIni = currentSelectedVehicleIni
})

spawning.startPreviewUpdater()

robot.init({
    spawnerSettings = spawnerSettings,
    debug_print = spawning.debug_print,
    spawnedVehicles = spawnedVehicles,
    moveableLegs = moveableLegs,
    legAnimationJob = legAnimationJob,
    robot_objects = robot_objects
})


