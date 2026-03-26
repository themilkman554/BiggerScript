local M = {}

-- State
local isVisible = false
local spawnerSettings = nil
local targetEntity = 0
local animDicts = nil -- Lazy loaded
local filteredDicts = nil

-- UI State
local searchInput = ""
local currentPage = 1
local dictsPerPage = 300
local selectedDictIndex = 0
local isControllable = true
local isContort = false
local isPrintToConsole = false

-- Loading
local isLoading = false
local loadError = nil

-- ============================================================================
-- JSON Parser (borrowed & optimized from spawning.lua)
-- ============================================================================
local function parseJsonDicts(jsonContent)
    if not jsonContent or jsonContent == "" then return nil end
    local success, result = pcall(function()
        local luaCode = jsonContent
        luaCode = luaCode:gsub("%[", "{")
        luaCode = luaCode:gsub("%]", "}")
        -- Simple key string replacement for our specific JSON format
        luaCode = luaCode:gsub('"DictionaryName"%s*:%s*', 'DictionaryName=')
        luaCode = luaCode:gsub('"Animations"%s*:%s*', 'Animations=')
        luaCode = "return " .. luaCode
        local func, err = load(luaCode)
        if not func then return nil end
        return func()
    end)
    if success and result then return result end
    return nil
end

local function loadAnimData()
    if animDicts or isLoading then return end
    
    isLoading = true
    loadError = nil
    
    Script.QueueJob(function()
        pcall(function()
            local filePath = FileMgr.GetMenuRootPath() .. "\\Lua\\BiggerScript\\SpoonerAssets\\animDictsCompact.json"
            if not FileMgr.DoesFileExist(filePath) then
                loadError = "Animation data not found at: " .. filePath
                isLoading = false
                return
            end
            
            local content = FileMgr.ReadFileContent(filePath)
            if not content then
                loadError = "Failed to read animation data."
                isLoading = false
                return
            end
            
            -- This takes a moment, so let the UI render while it works
            local parsed = parseJsonDicts(content)
            if parsed and type(parsed) == "table" then
                animDicts = parsed
                filteredDicts = animDicts
            else
                loadError = "Failed to parse animation data."
            end
            
            isLoading = false
        end)
    end)
end

-- ============================================================================
-- Filter logic
-- ============================================================================
local function updateFilter()
    if not animDicts then return end
    
    if searchInput == "" then
        filteredDicts = animDicts
    else
        local lowerSearch = searchInput:lower()
        filteredDicts = {}
        for _, dictEntry in ipairs(animDicts) do
            if dictEntry.DictionaryName and dictEntry.DictionaryName:lower():find(lowerSearch, 1, true) then
                table.insert(filteredDicts, dictEntry)
            end
        end
    end
    
    -- Reset to page 1 after filtering
    currentPage = 1
    selectedDictIndex = 0
end

-- ============================================================================
-- Playback logic
-- ============================================================================
local function playAnim(dict, anim)
    if not targetEntity or targetEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(targetEntity) then
        GUI.AddToast("Animations", "Target entity does not exist", 2000, 0)
        return
    end

    Script.QueueJob(function()
        pcall(function()
            -- Request dict
            STREAMING.REQUEST_ANIM_DICT(dict)
            local t = 0
            while not STREAMING.HAS_ANIM_DICT_LOADED(dict) and t < 100 do
                Script.Yield(10)
                t = t + 1
            end
            
            if STREAMING.HAS_ANIM_DICT_LOADED(dict) then
                -- Calculate animation flag based on options (same as animation_menu.lua)
                local flag = 9
                if not isControllable and not isContort then
                    flag = 9
                elseif not isControllable and isContort then
                    flag = 257
                elseif isControllable and not isContort then
                    flag = 121
                else
                    flag = 377
                end
                
                -- Clear current tasks first
                TASK.CLEAR_PED_TASKS(targetEntity)
                
                -- TASK_PLAY_ANIM(ped, dict, name, blendIn, blendOut, duration, flag, playbackRate, lockX, lockY, lockZ)
                TASK.TASK_PLAY_ANIM(targetEntity, dict, anim, 8.0, -8.0, -1, flag, 0.0, false, false, false)
                
                GUI.AddToast("Animations", "Playing: " .. anim, 2000, 0)
                
                if isPrintToConsole then
                    Logger.LogInfo("Dict: " .. dict .. " | Anim: " .. anim)
                end
            else
                GUI.AddToast("Animations", "Failed to load dict", 2000, 0)
            end
        end)
    end)
end

local function stopAnim()
    if not targetEntity or targetEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(targetEntity) then return end
    Script.QueueJob(function()
        pcall(function()
            TASK.CLEAR_PED_TASKS(targetEntity)
        end)
    end)
end

-- ============================================================================
-- ImGui Rendering
-- ============================================================================
local function renderDictList(windowWidth)
    if isLoading then
        ImGui.TextDisabled("Loading animation data... (Might freeze briefly)")
        return
    end
    
    if loadError then
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.3, 0.3, 1.0)
        ImGui.TextWrapped(loadError)
        ImGui.PopStyleColor()
        if ImGui.Button("Retry") then
            loadAnimData()
        end
        return
    end
    
    if not filteredDicts then return end
    
    local totalDicts = #filteredDicts
    local totalPages = math.max(1, math.ceil(totalDicts / dictsPerPage))
    
    -- Filter
    ImGui.PushItemWidth(280) -- Match dictionary list width
    local oldSearch = searchInput
    searchInput = ImGui.InputText("##SearchDict", searchInput or "", 64)
    if searchInput ~= oldSearch then
        updateFilter()
        totalDicts = #filteredDicts
        totalPages = math.max(1, math.ceil(totalDicts / dictsPerPage))
    end
    ImGui.PopItemWidth()
    if ImGui.IsItemHovered() then
        ImGui.SetTooltip("Search dictionary name")
    end
    
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    
    -- List
    local startIndex = ((currentPage - 1) * dictsPerPage) + 1
    local endIndex = math.min(startIndex + dictsPerPage - 1, totalDicts)
    
    if totalDicts == 0 then
        ImGui.TextDisabled("No dictionaries found")
    else
        -- Draw child for the dict list to allow scrolling, leaving room for pagination
        ImGui.BeginChild("DictList", 280, 580, true)
        
        for i = startIndex, endIndex do
            local dictEntry = filteredDicts[i]
            local dictName = dictEntry.DictionaryName or "unknown"
            
            local isSelected = (selectedDictIndex == i)
            if ImGui.Selectable(dictName .. "##" .. i, isSelected) then
                selectedDictIndex = i
            end
        end
        ImGui.EndChild()
        
        -- Pagination controls
        ImGui.Spacing()
        ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.2, 0.3, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.3, 0.4, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.15, 0.25, 1.0)
        
        -- Center pagination
        ImGui.SetCursorPosX((windowWidth - 200) / 2)
        
        if ImGui.Button("< Prev", 60, 0) then
            if currentPage > 1 then
                currentPage = currentPage - 1
            end
        end
        ImGui.SameLine()
        
        ImGui.Text(string.format("Page %d / %d", currentPage, totalPages))
        
        ImGui.SameLine()
        if ImGui.Button("Next >", 60, 0) then
            if currentPage < totalPages then
                currentPage = currentPage + 1
            end
        end
        ImGui.PopStyleColor(3)
    end
end

local function renderAnimList(windowWidth)
    if selectedDictIndex <= 0 or not filteredDicts[selectedDictIndex] then
        ImGui.TextDisabled("Select a dictionary")
        return
    end
    
    local dictEntry = filteredDicts[selectedDictIndex]
    local dictName = dictEntry.DictionaryName
    local anims = dictEntry.Animations or {}
    
    if #anims == 0 then
        ImGui.TextDisabled("No animations in dict")
        return
    end
    
    -- Use fixed height to guarantee a scrollbar appears
    ImGui.BeginChild("AnimList", 450, 680, true)
    
    -- Stop button at top
    ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.1, 0.1, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.15, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.08, 0.08, 1.0)
    if ImGui.Button("Stop All Animations", -1, 0) then
        stopAnim()
    end
    ImGui.PopStyleColor(3)
    
    ImGui.Spacing()
    
    ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.4, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.5, 0.25, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.35, 0.15, 1.0)
    
    for i, anim in ipairs(anims) do
        if ImGui.Button("Play##" .. i, 50, 0) then
            playAnim(dictName, anim)
        end
        ImGui.SameLine()
        -- Trim name so it doesn't overflow
        local displayAnim = anim
        if string.len(displayAnim) > 30 then
            displayAnim = string.sub(displayAnim, 1, 27) .. "..."
        end
        ImGui.Text(displayAnim)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip(anim)
        end
    end
    
    ImGui.PopStyleColor(3)
    ImGui.EndChild()
end

function M.renderAnimPlayerWindow()
    if not isVisible then return end
    
    -- Verify entity still exists
    if targetEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(targetEntity) then
        isVisible = false
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    -- Load data if not already done
    if not animDicts and not isLoading and not loadError then
        loadAnimData()
    end
    
    local windowWidth = 750
    local windowHeight = 850
    local posX = (screenWidth - windowWidth) / 2
    local posY = (screenHeight - windowHeight) / 2
    
    ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Once)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    
    local windowFlags = ImGuiWindowFlags.NoResize + 
                        ImGuiWindowFlags.NoCollapse +
                        ImGuiWindowFlags.NoTitleBar +
                        ImGuiWindowFlags.NoScrollbar
    
    -- Style the window (purple border like other windows)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.95)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
    
    if ImGui.Begin("##AnimPlayerWindow", true, windowFlags) then
        -- Header
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.SetWindowFontScale(1.1)
        ImGui.Text("Animations Player")
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()
        
        -- Close button
        ImGui.SameLine(windowWidth - 30)
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
        ImGui.Text("X")
        ImGui.PopStyleColor()
        if ImGui.IsItemClicked() then
            isVisible = false
        end
        
        ImGui.Separator()
        ImGui.Spacing()
        
        -- Top options
        local oldControllable = isControllable
        isControllable = ImGui.Checkbox("Controllable", isControllable)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Allows the ped to move upper-body only (uses flag 48 instead of 1)")
        end
        
        ImGui.SameLine(160)
        
        local oldContort = isContort
        isContort = ImGui.Checkbox("Contort", isContort)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Completely fuck the animation")
        end
        
        ImGui.SameLine(270)
        
        local oldPrint = isPrintToConsole
        isPrintToConsole = ImGui.Checkbox("Print to console", isPrintToConsole)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Print dictionary and animation name to console when played")
        end
        
        ImGui.Spacing()
        ImGui.Separator()
        
        -- Two columns: Dictionaries | Animations
        ImGui.BeginChild("Col1", 290, 750, false)
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.Text("Dictionaries")
        ImGui.PopStyleColor()
        renderDictList(280)
        ImGui.EndChild()
        
        ImGui.SameLine()
        
        ImGui.BeginChild("Col2", 455, 750, false)
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.Text("Animations")
        ImGui.PopStyleColor()
        renderAnimList(450)
        ImGui.EndChild()
    end
    ImGui.End()
    
    ImGui.PopStyleVar(3)
    ImGui.PopStyleColor(2)
end

-- ============================================================================
-- Public API
-- ============================================================================
function M.init(contextSettings)
    spawnerSettings = contextSettings
end

function M.getAnimPlayerVisible()
    return isVisible
end

function M.setAnimPlayerVisible(visible)
    isVisible = visible
end

function M.openAnimPlayer(entityHandle)
    if entityHandle and entityHandle ~= 0 and ENTITY.DOES_ENTITY_EXIST(entityHandle) then
        targetEntity = entityHandle
        isVisible = true
        loadAnimData() -- kick off load if needed
    else
        GUI.AddToast("Animations", "Invalid entity selected", 2000, 0)
    end
end

return M
