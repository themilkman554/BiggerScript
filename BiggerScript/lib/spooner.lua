local M = {}
local spawnerSettings
local ConstructorLib = require("BiggerScript/lib/constructor_lib")

-- State for the spooner
local hoveredEntity = 0
local hoveredEntityType = nil
local selectedEntity = 0
local selectedEntityType = nil
local isRunning = false
local lastClickTime = 0
local lastKeyTime = 0
local browserVisible = false
local browserExpanded = true  -- Whether browser is expanded (not collapsed to small box)
local nearbyEntitiesVisible = true
local saveNameInput = "" -- Input for saving vehicle/outfit names
local isKeyboardCaptured = false -- Whether ImGui wants to capture keyboard input

-- 3D Position Gizmo State
local gizmoState = {
    enabled = false,           -- Whether gizmo is currently shown
    dragging = false,          -- Currently dragging an axis
    dragAxis = nil,            -- "x", "y", or "z"
    hoveredAxis = nil,         -- Currently hovered axis
    lastMouseX = 0,            -- Last mouse X position for delta calculation
    lastMouseY = 0,            -- Last mouse Y position for delta calculation
    arrowLength = 1.5,         -- Length of each arrow
    arrowHeadSize = 0.15,      -- Size of arrow head cone
    sensitivity = 0.02,        -- Mouse movement to offset conversion
    jobRunning = false         -- Whether the render job is running
}

-- Helper to check GUI state and enforce browser visibility
local function IsGUIOpenAndManageBrowser()
    local isOpen = false
    pcall(function()
        isOpen = GUI.IsOpen()
    end)
    
    return isOpen
end

-- Free Cam State
local freeCamState = {
    enabled = true,  -- Free cam is enabled by default when spooner starts
    camHandle = 0,
    posX = 0.0,
    posY = 0.0,
    posZ = 0.0,
    rotX = 0.0,  -- Pitch
    rotY = 0.0,  -- Roll (usually 0)
    rotZ = 0.0,  -- Yaw (heading)
    moveSpeed = 0.5,
    fastMoveSpeed = 2.0,
    rotSpeed = 5.0,
    initialized = false,
    -- Raycast state for entity detection
    raycastHandle = nil,
    raycastFrameCounter = 0
}

-- Toggle states for selected entity options
local toggleStates = {
    dynamic = true,
    frozen = false,
    invincible = false,
    fireproof = false,
    visible = true,
    collision = true,
    gravity = true,
    database = false
}

-- Track if user manually enabled freeze (so we know not to unfreeze on deselect)
local userEnabledFreeze = false

-- Cache for entity properties that don't have native getters
-- Key: entity handle, Value: {invincible, dynamic, gravity, fireproof}
local entityPropertyCache = {}

-- Cache for attachment offsets
-- Key: attached entity handle, Value: {bone, offsetX, offsetY, offsetZ, rotPitch, rotRoll, rotYaw}
local attachmentOffsetCache = {}

-- Attachment tracking for selected entity
local selectedEntityAttachments = {
    isAttached = false,
    attachedTo = 0,
    attachmentCount = 0,
    list = {} -- List of {handle, type} tables for attached entities
}

-- Check attachments for the selected entity
local function checkEntityAttachments(entity)
    selectedEntityAttachments.isAttached = false
    selectedEntityAttachments.attachedTo = 0
    selectedEntityAttachments.attachmentCount = 0
    selectedEntityAttachments.list = {}
    
    if not entity or entity == 0 then return end
    if not ENTITY.DOES_ENTITY_EXIST(entity) then return end
    
    Script.QueueJob(function()
        pcall(function()
            -- Check if this entity is attached to something
            local isAttached = ENTITY.IS_ENTITY_ATTACHED(entity)
            selectedEntityAttachments.isAttached = isAttached
            
            if isAttached then
                local attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(entity)
                selectedEntityAttachments.attachedTo = attachedTo or 0
            end
            
            -- Build list of entities attached to this entity
            -- We need to iterate through all entities and check if they're attached to us
            local attachmentList = {}
            
            -- Check vehicles
            local vehicleCount = PoolMgr.GetCurrentVehicleCount() or 0
            for i = 0, vehicleCount - 1 do
                local veh = PoolMgr.GetVehicle(i)
                if veh and veh ~= 0 and veh ~= entity and ENTITY.DOES_ENTITY_EXIST(veh) then
                    if ENTITY.IS_ENTITY_ATTACHED(veh) then
                        local attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(veh)
                        if attachedTo == entity then
                            table.insert(attachmentList, {handle = veh, type = "vehicle"})
                        end
                    end
                end
            end
            
            -- Check peds
            local pedCount = PoolMgr.GetCurrentPedCount() or 0
            for i = 0, pedCount - 1 do
                local ped = PoolMgr.GetPed(i)
                if ped and ped ~= 0 and ped ~= entity and ENTITY.DOES_ENTITY_EXIST(ped) then
                    if ENTITY.IS_ENTITY_ATTACHED(ped) then
                        local attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(ped)
                        if attachedTo == entity then
                            table.insert(attachmentList, {handle = ped, type = "ped"})
                        end
                    end
                end
            end
            
            -- Check objects
            local objectCount = PoolMgr.GetCurrentObjectCount() or 0
            for i = 0, objectCount - 1 do
                local obj = PoolMgr.GetObject(i)
                if obj and obj ~= 0 and obj ~= entity and ENTITY.DOES_ENTITY_EXIST(obj) then
                    if ENTITY.IS_ENTITY_ATTACHED(obj) then
                        local attachedTo = ENTITY.GET_ENTITY_ATTACHED_TO(obj)
                        if attachedTo == entity then
                            table.insert(attachmentList, {handle = obj, type = "object"})
                        end
                    end
                end
            end
            
            selectedEntityAttachments.list = attachmentList
            selectedEntityAttachments.attachmentCount = #attachmentList
        end)
    end)
end


-- Database to store entities for later
local entityDatabase = {}

-- Get model name from hash (returns hash as string if name not found)
local function getModelName(entity)
    if not entity or entity == 0 then return "Unknown" end
    
    -- First check if entity is in database with a custom name
    if entityDatabase[entity] and entityDatabase[entity].customName then
        return entityDatabase[entity].customName
    end
    
    local success, result = pcall(function()
        local model = ENTITY.GET_ENTITY_MODEL(entity)
        if not model or model == 0 then return "Unknown" end
        
        -- Try to get display name for vehicles
        if ENTITY.IS_ENTITY_A_VEHICLE(entity) then
            -- Try GTA.GetDisplayNameFromHash first (User requested)
            local displayName = GTA.GetDisplayNameFromHash(model)
            if displayName and displayName ~= "" and displayName ~= "null" then
                return displayName
            end
            
            -- Fallback to native
            local displayName = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(model)
            if displayName and displayName ~= "CARNOTFOUND" and displayName ~= "" then
                return displayName
            end
        end

        -- For non-vehicles (or fallback), try GetModelNameFromHash (User requested)
        local modelName = GTA.GetModelNameFromHash(model)
        if modelName and modelName ~= "" and modelName ~= "null" then
            return modelName
        end
        
        -- Return hash as hex string
        return string.format("0x%X", model)
    end)
    
    if success and result then
        return result
    end
    return "Unknown"
end

-- Update toggle states based on an entity's actual properties
local function updateToggleStatesForEntity(entity, preserveFrozenState)
    if not entity or entity == 0 then
        -- Reset to defaults when no entity selected
        toggleStates.dynamic = true
        toggleStates.frozen = false
        toggleStates.invincible = false
        toggleStates.fireproof = false
        toggleStates.visible = true
        toggleStates.collision = true
        toggleStates.gravity = true
        return
    end
    
    if not ENTITY.DOES_ENTITY_EXIST(entity) then
        return
    end
    
    -- Check if it is a ped
    local isPed = false
    pcall(function() isPed = ENTITY.IS_ENTITY_A_PED(entity) end)
    
    -- Update database toggle state based on whether entity is in database
    toggleStates.database = entityDatabase[entity] ~= nil
    
    -- Check if we have cached property values for properties without native getters
    local cached = entityPropertyCache[entity]
    if cached then
        toggleStates.invincible = cached.invincible or false
        toggleStates.dynamic = cached.dynamic ~= false -- default to true
        toggleStates.gravity = cached.gravity ~= false -- default to true
    else
        -- No cache, set defaults
        toggleStates.invincible = false
        toggleStates.dynamic = true
        toggleStates.gravity = true
    end
    
    -- Force frozen state for peds (UNLESS preserveFrozenState is true)
    if isPed and not preserveFrozenState then
        toggleStates.frozen = true
    end
    
    Script.QueueJob(function()
        pcall(function()
            if not ENTITY.DOES_ENTITY_EXIST(entity) then return end
            
            -- If it is a ped, force apply frozen state and flags (UNLESS preserveFrozenState is true)
            if isPed and not preserveFrozenState then
                ENTITY.FREEZE_ENTITY_POSITION(entity, true)
                PED.SET_PED_CAN_RAGDOLL(entity, false)
                PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(entity, true)
            end
            
            -- Check collision state (GET_ENTITY_COLLISION_DISABLED returns true if collision is OFF)
            local collisionSuccess, collisionDisabled = pcall(function()
                return ENTITY.GET_ENTITY_COLLISION_DISABLED(entity)
            end)
            if collisionSuccess then
                toggleStates.collision = not collisionDisabled
            end
            
            -- Check visible state
            local visibleSuccess, isVisible = pcall(function()
                return ENTITY.IS_ENTITY_VISIBLE(entity)
            end)
            if visibleSuccess then
                toggleStates.visible = isVisible
            end
            
            -- Check frozen state using IS_ENTITY_POSITION_FROZEN (only if not forced frozen)
            if not isPed then
                local frozenSuccess, isFrozen = pcall(function()
                    return ENTITY.IS_ENTITY_POSITION_FROZEN(entity)
                end)
                if frozenSuccess then
                    toggleStates.frozen = isFrozen
                end
            end
            
            -- Check entity proofs (fireproof, etc.) using GET_ENTITY_PROOFS
            -- This requires memory allocation for the output pointers
            local proofsSuccess = pcall(function()
                if Memory and Memory.AllocBool and Memory.ReadBool then
                    local bulletProofPtr = Memory.AllocBool()
                    local fireProofPtr = Memory.AllocBool()
                    local explosionProofPtr = Memory.AllocBool()
                    local collisionProofPtr = Memory.AllocBool()
                    local meleeProofPtr = Memory.AllocBool()
                    local steamProofPtr = Memory.AllocBool()
                    local p7Ptr = Memory.AllocBool()
                    local drownProofPtr = Memory.AllocBool()
                    
                    ENTITY.GET_ENTITY_PROOFS(entity, bulletProofPtr, fireProofPtr, explosionProofPtr, collisionProofPtr, meleeProofPtr, steamProofPtr, p7Ptr, drownProofPtr)
                    
                    local fireProof = Memory.ReadBool(fireProofPtr)
                    toggleStates.fireproof = fireProof or false
                end
            end)
            
            if not proofsSuccess then
                -- Check cache for fireproof, else default to false
                if cached and cached.fireproof ~= nil then
                    toggleStates.fireproof = cached.fireproof
                else
                    toggleStates.fireproof = false
                end
            end
        end)
    end)
end

-- List of nearby entities for the GUI
local nearbyEntities = {
    vehicles = {},
    peds = {},
    objects = {}
}

-- GTA Hash Browser State
local gtaHashBrowser = {
    -- Categories available on gtahash.ru (objects)
    objectCategories = {
        "construction", "bush", "rooftop", "bar", "other", "Walls And Fences",
        "potted", "utility", "procedural", "bins", "cacti", "ext_veg",
        "minigame", "storage", "halloween", "industrial", "seating", "rocks",
        "traffic_lights", "fastfood", "pieces", "garden", "Doors And Gates",
        "kitchen", "electrical", "seating_tables", "bathroom", "trees", "palm",
        "office", "garage", "farm", "crops", "rubbish", "snow", "recreational",
        "signs", "fanpalm", "Outdoor objects", "Buildings", "Interior objects",
        "Equipment", "Lightsources", "Vehicle parts", "Stunt objects", "Structures",
        "Transportation", "Weapon models", "xmas"
    },
    -- Vehicle categories
    vehicleCategories = {
        "utility", "muscle", "trains", "compacts", "sedans", "super",
        "industrial", "suvs", "military", "planes", "coupes", "vans",
        "off-road", "service", "boats", "cycles", "sports", "helicopters",
        "emergency", "commercials", "trailer", "motorcycles", "sport-classic", "open-wheel"
    },
    -- Current state
    currentSource = "list", -- Defaults to list
    showDisplayNames = true, -- Toggle for vehicle display names
    currentTab = "objects",  -- "objects" or "vehicles"
    selectedCategory = nil,
    currentPage = 1,
    totalPages = 1,
    isLoading = false,
    loadError = nil,
    -- Cached items from the current page
    items = {},
    -- Loaded textures cache (model hash -> texture id)
    textureCache = {},
    -- Search filter
    searchFilter = "",
    -- Clipboard source state
    clipboardText = "",
    lastClipboardCheck = 0,
    -- Remote loading state
    remoteItemsPerPage = 24, -- Match gtahash.ru website's items per page
    pendingDownloads = {}, -- Track active image downloads
    -- Preview state
    previewEnabled = false,
    previewEntity = 0,
    previewModelName = nil,
    previewSpawning = false,
    -- Auto-select state (Spooner mode only)
    selectOnSpawn = true
}


local rootPath = ""
function M.init(context)
    spawnerSettings = context.spawnerSettings
    rootPath = context.rootPath
end

function M.debug_print(...)
    if spawnerSettings.printToDebug then
        print(...)
    end
end

-- Calculate angle between camera direction and entity direction
local function getAngleToEntity(camPos, camDir, entityPos)
    if not camPos or not camDir or not entityPos then return 999 end
    
    -- Vector from camera to entity
    local toEntityX = entityPos.x - camPos.x
    local toEntityY = entityPos.y - camPos.y
    local toEntityZ = entityPos.z - camPos.z
    
    -- Normalize the vector to entity
    local toEntityLen = math.sqrt(toEntityX*toEntityX + toEntityY*toEntityY + toEntityZ*toEntityZ)
    if toEntityLen < 0.001 then return 999 end
    
    toEntityX = toEntityX / toEntityLen
    toEntityY = toEntityY / toEntityLen
    toEntityZ = toEntityZ / toEntityLen
    
    -- Dot product gives cos of angle
    local dot = camDir.x * toEntityX + camDir.y * toEntityY + camDir.z * toEntityZ
    
    -- Clamp to valid range
    dot = math.max(-1, math.min(1, dot))
    
    -- Return angle in degrees
    return math.acos(dot) * 180 / math.pi
end

-- Get camera direction from rotation
local function getCameraDirection(camRot)
    if not camRot then return nil end
    
    local radX = camRot.x * math.pi / 180.0
    local radZ = camRot.z * math.pi / 180.0
    
    return {
        x = -math.sin(radZ) * math.cos(radX),
        y = math.cos(radZ) * math.cos(radX),
        z = math.sin(radX)
    }
end

-- Calculate distance between two positions
local function getDistance(pos1, pos2)
    if not pos1 or not pos2 then return 9999 end
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

-- Get entities from a pool using PoolMgr
local function getEntitiesFromPool(playerPos, playerPed, entityType, maxDist)
    local entities = {}
    
    local count = 0
    local getEntity = nil
    
    if entityType == "vehicle" then
        count = PoolMgr.GetCurrentVehicleCount()
        getEntity = PoolMgr.GetVehicle
    elseif entityType == "ped" then
        count = PoolMgr.GetCurrentPedCount()
        getEntity = PoolMgr.GetPed
    elseif entityType == "object" then
        count = PoolMgr.GetCurrentObjectCount()
        getEntity = PoolMgr.GetObject
    end
    
    -- Limit iterations to prevent lag
    local maxCheck = math.min(count, 100)
    
    for i = 0, maxCheck - 1 do
        local entity = getEntity(i)
        if entity and entity ~= 0 and entity ~= playerPed then
            if ENTITY.DOES_ENTITY_EXIST(entity) then
                local entPos = ENTITY.GET_ENTITY_COORDS(entity, true)
                if entPos then
                    local dist = getDistance(playerPos, entPos)
                    if dist < maxDist then
                        -- Get model name/hash
                        local model = ENTITY.GET_ENTITY_MODEL(entity)
                        table.insert(entities, {
                            handle = entity,
                            distance = dist,
                            model = model,
                            type = entityType
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(entities, function(a, b) return a.distance < b.distance end)
    
    -- Limit to 10 closest
    local result = {}
    for i = 1, math.min(#entities, 10) do
        result[i] = entities[i]
    end
    
    return result
end

-- Start entity detection loop
function M.startDetectionLoop()
    if isRunning then return end
    isRunning = true
    
    -- Trigger Disable Hud when spooner mode starts
    pcall(function()
        local disableHudFeature = FeatureMgr.GetFeatureByName("Disable Hud")
        if disableHudFeature then
            disableHudFeature:TriggerCallback()
        end
    end)
    
    -- Local state for grabbing entities
    local isGrabbing = false
    local grabDistance = 10.0
    
    -- Initialize free cam
    Script.QueueJob(function()
        pcall(function()
            -- Get player position for initial camera position
            local playerPed = PLAYER.PLAYER_PED_ID()
            if playerPed and playerPed ~= 0 then
                local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, true)
                local playerHeading = ENTITY.GET_ENTITY_HEADING(playerPed)
                
                freeCamState.posX = playerCoords.x
                freeCamState.posY = playerCoords.y
                freeCamState.posZ = playerCoords.z + 2.0  -- Slightly above player
                freeCamState.rotX = 0.0  -- Looking forward
                freeCamState.rotY = 0.0
                freeCamState.rotZ = playerHeading
                
                -- Create the camera
                freeCamState.camHandle = CAM.CREATE_CAM("DEFAULT_SCRIPTED_CAMERA", true)
                CAM.SET_CAM_COORD(freeCamState.camHandle, freeCamState.posX, freeCamState.posY, freeCamState.posZ)
                CAM.SET_CAM_ROT(freeCamState.camHandle, freeCamState.rotX, freeCamState.rotY, freeCamState.rotZ, 2)
                CAM.SET_CAM_ACTIVE(freeCamState.camHandle, true)
                CAM.RENDER_SCRIPT_CAMS(true, true, 500, true, false, 0)
                
                -- Freeze the player
                ENTITY.FREEZE_ENTITY_POSITION(playerPed, true)
                PLAYER.SET_PLAYER_CONTROL(PLAYER.PLAYER_ID(), false, 0)
                
                freeCamState.initialized = true
                freeCamState.enabled = true
            end
        end)
    end)
    
    -- Main free cam control loop (separate from entity detection for faster response)
    Script.QueueJob(function()
        while isRunning and spawnerSettings and spawnerSettings.enableSpooner do
            pcall(function()
                if freeCamState.initialized and freeCamState.enabled then
                    -- Only rotate camera if GUI menu is not open
                    local menuOpen = IsGUIOpenAndManageBrowser()
                    
                    if not menuOpen then
                        -- Get mouse movement for camera rotation
                        local mouseX = PAD.GET_DISABLED_CONTROL_NORMAL(0, 1)  -- Mouse X
                        local mouseY = PAD.GET_DISABLED_CONTROL_NORMAL(0, 2)  -- Mouse Y
                        
                        -- Apply rotation (invert Y for natural feel)
                        freeCamState.rotZ = freeCamState.rotZ - mouseX * freeCamState.rotSpeed
                        freeCamState.rotX = freeCamState.rotX - mouseY * freeCamState.rotSpeed
                        
                        -- Clamp pitch to prevent flipping
                        if freeCamState.rotX > 89.0 then freeCamState.rotX = 89.0 end
                        if freeCamState.rotX < -89.0 then freeCamState.rotX = -89.0 end
                    end
                    
                    -- Calculate forward/right vectors
                    local radZ = freeCamState.rotZ * math.pi / 180.0
                    local radX = freeCamState.rotX * math.pi / 180.0
                    
                    local forwardX = -math.sin(radZ) * math.cos(radX)
                    local forwardY = math.cos(radZ) * math.cos(radX)
                    local forwardZ = math.sin(radX)
                    
                    local rightX = math.cos(radZ)
                    local rightY = math.sin(radZ)
                    
                    -- Determine speed (Space for fast)
                    local speed = freeCamState.moveSpeed
                    if PAD.IS_DISABLED_CONTROL_PRESSED(0, 22) then  -- Space (Jump)
                        speed = freeCamState.fastMoveSpeed
                    end
                    
                    -- WASD Movement
                    if PAD.IS_DISABLED_CONTROL_PRESSED(0, 32) then  -- W
                        freeCamState.posX = freeCamState.posX + forwardX * speed
                        freeCamState.posY = freeCamState.posY + forwardY * speed
                        freeCamState.posZ = freeCamState.posZ + forwardZ * speed
                    end
                    if PAD.IS_DISABLED_CONTROL_PRESSED(0, 33) then  -- S
                        freeCamState.posX = freeCamState.posX - forwardX * speed
                        freeCamState.posY = freeCamState.posY - forwardY * speed
                        freeCamState.posZ = freeCamState.posZ - forwardZ * speed
                    end
                    if PAD.IS_DISABLED_CONTROL_PRESSED(0, 34) then  -- A
                        freeCamState.posX = freeCamState.posX - rightX * speed
                        freeCamState.posY = freeCamState.posY - rightY * speed
                    end
                    if PAD.IS_DISABLED_CONTROL_PRESSED(0, 35) then  -- D
                        freeCamState.posX = freeCamState.posX + rightX * speed
                        freeCamState.posY = freeCamState.posY + rightY * speed
                    end
                    -- Up/Down movement (Shift = Up, Ctrl = Down)
                    if PAD.IS_DISABLED_CONTROL_PRESSED(0, 36) then  -- Left Ctrl (Duck) - Down
                        freeCamState.posZ = freeCamState.posZ - speed
                    end
                    if PAD.IS_DISABLED_CONTROL_PRESSED(0, 21) then  -- Left Shift (Sprint) - Up
                        freeCamState.posZ = freeCamState.posZ + speed
                    end
                    
                    -- Update camera position and rotation
                    CAM.SET_CAM_COORD(freeCamState.camHandle, freeCamState.posX, freeCamState.posY, freeCamState.posZ)
                    CAM.SET_CAM_ROT(freeCamState.camHandle, freeCamState.rotX, freeCamState.rotY, freeCamState.rotZ, 2)
                    
                    -- Update streaming focus to load world around camera position
                    STREAMING.SET_FOCUS_POS_AND_VEL(freeCamState.posX, freeCamState.posY, freeCamState.posZ, 0.0, 0.0, 0.0)
                    
                    -- Raycast entity detection (every 3 frames for performance)
                    freeCamState.raycastFrameCounter = freeCamState.raycastFrameCounter + 1
                    if freeCamState.raycastFrameCounter >= 3 then
                        freeCamState.raycastFrameCounter = 0
                        
                        -- Calculate forward direction from camera rotation
                        local radZ = freeCamState.rotZ * math.pi / 180.0
                        local radX = freeCamState.rotX * math.pi / 180.0
                        local forwardX = -math.sin(radZ) * math.cos(radX)
                        local forwardY = math.cos(radZ) * math.cos(radX)
                        local forwardZ = math.sin(radX)
                        
                        -- Raycast endpoint (1000 units forward)
                        local endX = freeCamState.posX + forwardX * 1000.0
                        local endY = freeCamState.posY + forwardY * 1000.0
                        local endZ = freeCamState.posZ + forwardZ * 1000.0
                        
                        -- Perform raycast: flags = 2 (vehicles) + 4 (peds) + 16 (objects) = 22
                        local playerPed = PLAYER.PLAYER_PED_ID()
                        freeCamState.raycastHandle = SHAPETEST.START_SHAPE_TEST_LOS_PROBE(
                            freeCamState.posX, freeCamState.posY, freeCamState.posZ,
                            endX, endY, endZ,
                            22, -- flags: vehicles + peds + objects (no world geometry)
                            playerPed, 7
                        )
                    end
                    
                    -- Check raycast result
                    if freeCamState.raycastHandle then
                        local hit = Memory.AllocInt()
                        local endCoords = Memory.Alloc(24)
                        local surfaceNormal = Memory.Alloc(24)
                        local entityHit = Memory.AllocInt()
                        
                        local resultReady = SHAPETEST.GET_SHAPE_TEST_RESULT(
                            freeCamState.raycastHandle, hit, endCoords, surfaceNormal, entityHit
                        )
                        
                        -- Only process if result is ready (resultReady == 2 means complete)
                        if resultReady == 2 then
                            local hitValue = Memory.ReadInt(hit)
                            local entityHitValue = Memory.ReadInt(entityHit)
                            
                            if hitValue == 1 and entityHitValue ~= 0 and ENTITY.DOES_ENTITY_EXIST(entityHitValue) then
                                hoveredEntity = entityHitValue
                                -- Determine entity type
                                if ENTITY.IS_ENTITY_A_VEHICLE(entityHitValue) then
                                    hoveredEntityType = "vehicle"
                                elseif ENTITY.IS_ENTITY_A_PED(entityHitValue) then
                                    hoveredEntityType = "ped"
                                else
                                    hoveredEntityType = "object"
                                end
                            else
                                hoveredEntity = 0
                                hoveredEntityType = nil
                            end
                            
                            freeCamState.raycastHandle = nil
                        end
                        
                        Memory.Free(hit)
                        Memory.Free(endCoords)
                        Memory.Free(surfaceNormal)
                        Memory.Free(entityHit)
                    end
                    
                    -- Handle Grabbing Clean-up
                    if not PAD.IS_DISABLED_CONTROL_PRESSED(0, 24) then
                        isGrabbing = false
                    end

                    -- Left-click to select entity AND/OR start grabbing
                    if not menuOpen and PAD.IS_DISABLED_CONTROL_JUST_PRESSED(0, 24) then  -- Left Mouse Button
                        if hoveredEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(hoveredEntity) then
                            selectedEntity = hoveredEntity
                            selectedEntityType = hoveredEntityType
                            userEnabledFreeze = false -- Reset when selecting new entity
                            checkEntityAttachments(hoveredEntity)
                            updateToggleStatesForEntity(hoveredEntity)
                            GUI.AddToast("Spooner", "Selected " .. (hoveredEntityType or "entity"), 1500, 0)
                        end
                        
                        -- Start grabbing if we have a valid selection (either just selected or previously selected)
                        -- AND if we are currently looking at it (hoveredEntity == selectedEntity)
                        if selectedEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
                            if selectedEntity == hoveredEntity then
                                isGrabbing = true
                                local camPos = {x = freeCamState.posX, y = freeCamState.posY, z = freeCamState.posZ}
                                local entPos = ENTITY.GET_ENTITY_COORDS(selectedEntity, true)
                                grabDistance = getDistance(camPos, entPos)
                            end
                        end
                    end
                    
                    -- Process Grabbing (Move entity)
                    if not menuOpen and isGrabbing and selectedEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
                         -- Calculate target position based on camera forward vector + grabDistance
                         local radZ = freeCamState.rotZ * math.pi / 180.0
                         local radX = freeCamState.rotX * math.pi / 180.0
                         
                         local forwardX = -math.sin(radZ) * math.cos(radX)
                         local forwardY = math.cos(radZ) * math.cos(radX)
                         local forwardZ = math.sin(radX)
                         
                         local targetX = freeCamState.posX + forwardX * grabDistance
                         local targetY = freeCamState.posY + forwardY * grabDistance
                         local targetZ = freeCamState.posZ + forwardZ * grabDistance
                         
                         ENTITY.SET_ENTITY_COORDS_NO_OFFSET(selectedEntity, targetX, targetY, targetZ, true, true, true)
                         ENTITY.SET_ENTITY_VELOCITY(selectedEntity, 0, 0, 0)
                         ENTITY.SET_ENTITY_ROTATION(selectedEntity, 0, 0, freeCamState.rotZ, 2, true)
                    end
                    
                    -- Disable player controls
                    PAD.DISABLE_ALL_CONTROL_ACTIONS(0)
                end
            end)
            Script.Yield(0)  -- Run every frame for smooth camera
        end
    end)
    
    -- Background loop for keyboard shortcuts and entity validation
    Script.QueueJob(function()
        while isRunning and spawnerSettings and spawnerSettings.enableSpooner do
            -- Wrap everything in pcall to prevent crashes
            pcall(function()
                local playerPed = PLAYER.PLAYER_PED_ID()
                if playerPed and playerPed ~= 0 then
                    -- Get position for nearby entities list (for UI)
                    -- Get position for nearby entities list (for UI)
                    -- Use rendered camera to support external free cams
                    local camPos = CAM.GET_FINAL_RENDERED_CAM_COORD()
                    if not camPos then
                        camPos = ENTITY.GET_ENTITY_COORDS(playerPed, true)
                    end
                    
                    local maxDist = 100.0
                    
                    -- Update nearby entities list for the UI (not for crosshair detection)
                    nearbyEntities.vehicles = getEntitiesFromPool(camPos, playerPed, "vehicle", maxDist)
                    nearbyEntities.peds = getEntitiesFromPool(camPos, playerPed, "ped", maxDist)
                    nearbyEntities.objects = getEntitiesFromPool(camPos, playerPed, "object", maxDist)
                    
                    local currentTime = Time.GetEpocheMs()
                    
                    -- Validate selected entity still exists
                    if selectedEntity ~= 0 then
                        if not ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
                            selectedEntity = 0
                            selectedEntityType = nil
                        end
                    end
                    

                end
            end)
            
            -- Yield - can run slower now since raycast handles detection
            Script.Yield(100)
        end
        
        -- Cleanup
        isRunning = false
        hoveredEntity = 0
        hoveredEntityType = nil
        selectedEntity = 0
        selectedEntityType = nil
        nearbyEntities = { vehicles = {}, peds = {}, objects = {} }
    end)
end

-- Stop the detection loop
function M.stopDetectionLoop()
    isRunning = false
    hoveredEntity = 0
    hoveredEntityType = nil
    selectedEntity = 0
    selectedEntityType = nil
    userEnabledFreeze = false
    nearbyEntities = { vehicles = {}, peds = {}, objects = {} }
    
    -- Clean up free cam
    if freeCamState.initialized then
        Script.QueueJob(function()
            pcall(function()
                -- Destroy the camera
                if freeCamState.camHandle ~= 0 then
                    CAM.SET_CAM_ACTIVE(freeCamState.camHandle, false)
                    CAM.RENDER_SCRIPT_CAMS(false, true, 500, true, false, 0)
                    CAM.DESTROY_CAM(freeCamState.camHandle, false)
                    freeCamState.camHandle = 0
                end
                
                -- Unfreeze the player
                local playerPed = PLAYER.PLAYER_PED_ID()
                if playerPed and playerPed ~= 0 then
                    ENTITY.FREEZE_ENTITY_POSITION(playerPed, false)
                    PED.SET_PED_CAN_RAGDOLL(playerPed, true)
                    PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(playerPed, false)
                    PLAYER.SET_PLAYER_CONTROL(PLAYER.PLAYER_ID(), true, 0)
                end
                
                -- Clear streaming focus and reset focus back to player ped
                STREAMING.CLEAR_FOCUS()
                if playerPed and playerPed ~= 0 then
                    STREAMING.SET_FOCUS_ENTITY(playerPed)
                end
                
                freeCamState.initialized = false
                freeCamState.enabled = false
            end)
        end)
    end
    
    -- Ensure gizmo rendering stops
    if stopGizmoRenderLoop then
        stopGizmoRenderLoop()
    end
    -- Force clear state in case function failed or loop is stuck
    gizmoState.jobRunning = false
    gizmoState.enabled = false
    
    -- Clean up any preview entity when stopping spooner
    if gtaHashBrowser.previewEntity ~= 0 then
        local entityToDelete = gtaHashBrowser.previewEntity
        gtaHashBrowser.previewEntity = 0
        gtaHashBrowser.previewModelName = nil
        Script.QueueJob(function()
            pcall(function()
                if entityToDelete and entityToDelete ~= 0 and ENTITY.DOES_ENTITY_EXIST(entityToDelete) then
                    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entityToDelete, true, true)
                    local ptr = Memory.AllocInt()
                    Memory.WriteInt(ptr, entityToDelete)
                    ENTITY.DELETE_ENTITY(ptr)
                end
            end)
        end)
    end
end

-- Clear selection
function M.clearSelection()
    selectedEntity = 0
    selectedEntityType = nil
    userEnabledFreeze = false
end

-- Get the list of nearby entities (for GUI)
function M.getNearbyEntities()
    return nearbyEntities
end

-- Get/Set browser visibility
function M.getBrowserVisible()
    return browserVisible
end

function M.setBrowserVisible(visible)
    browserVisible = visible
end

function M.toggleBrowserVisible()
    browserVisible = not browserVisible
end

-- Get/Set browser expanded state (collapsed vs full window)
function M.getBrowserExpanded()
    return browserExpanded
end

function M.setBrowserExpanded(expanded)
    browserExpanded = expanded
end

-- Open browser in expanded state (for Spooner mode)
function M.openBrowserExpanded()
    browserVisible = true
    browserExpanded = true
end

-- Render the Nearby Entities window for the Spooner Tab GUI
function M.renderNearbyEntitiesGUI()
    local totalCount = #nearbyEntities.vehicles + #nearbyEntities.peds + #nearbyEntities.objects
    
    ImGui.Text("Entities within 50 units: " .. totalCount)
    ImGui.Spacing()
    
    -- Vehicles section
    if #nearbyEntities.vehicles > 0 then
        if ImGui.TreeNode("Vehicles (" .. #nearbyEntities.vehicles .. ")") then
            for i, ent in ipairs(nearbyEntities.vehicles) do
                local label = string.format("Vehicle #%d - %.1fm", i, ent.distance)
                ImGui.Text(label)
                ImGui.SameLine()
                
                -- Select button (purple)
                ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.15, 0.4, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.2, 0.5, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.1, 0.35, 1.0)
                if ImGui.Button("Select##veh" .. i) then
                    if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                        selectedEntity = ent.handle
                        selectedEntityType = "vehicle"
                        checkEntityAttachments(ent.handle)
                        updateToggleStatesForEntity(ent.handle)
                    end
                end
                ImGui.PopStyleColor(3)
            end
            ImGui.TreePop()
        end
    end
    
    -- Peds section
    if #nearbyEntities.peds > 0 then
        if ImGui.TreeNode("Peds (" .. #nearbyEntities.peds .. ")") then
            for i, ent in ipairs(nearbyEntities.peds) do
                local label = string.format("Ped #%d - %.1fm", i, ent.distance)
                ImGui.Text(label)
                ImGui.SameLine()
                
                -- Select button (purple)
                ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.15, 0.4, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.2, 0.5, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.1, 0.35, 1.0)
                if ImGui.Button("Select##ped" .. i) then
                    if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                        selectedEntity = ent.handle
                        selectedEntityType = "ped"
                        checkEntityAttachments(ent.handle)
                        updateToggleStatesForEntity(ent.handle)
                    end
                end
                ImGui.PopStyleColor(3)
            end
            ImGui.TreePop()
        end
    end
    
    -- Objects section
    if #nearbyEntities.objects > 0 then
        if ImGui.TreeNode("Objects (" .. #nearbyEntities.objects .. ")") then
            for i, ent in ipairs(nearbyEntities.objects) do
                local label = string.format("Object #%d - %.1fm", i, ent.distance)
                ImGui.Text(label)
                ImGui.SameLine()
                
                -- Select button (purple)
                ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.15, 0.4, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.2, 0.5, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.1, 0.35, 1.0)
                if ImGui.Button("Select##obj" .. i) then
                    if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                        selectedEntity = ent.handle
                        selectedEntityType = "object"
                        checkEntityAttachments(ent.handle)
                        updateToggleStatesForEntity(ent.handle)
                    end
                end
                ImGui.PopStyleColor(3)
            end
            ImGui.TreePop()
        end
    end
    
    if totalCount == 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
        ImGui.Text("No entities nearby")
        ImGui.PopStyleColor()
    end
end

-- Render standalone Nearby Entities window (below entity options window)
local function renderNearbyEntitiesWindow()
    if not spawnerSettings or not spawnerSettings.enableSpooner then
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    local posX = 10
    local posY = screenHeight - 320 - 20  -- Bottom-left corner with padding
    
    -- Style colors used for both states
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10.0, 8.0)
    
    if not nearbyEntitiesVisible then
        -- Collapsed state - show small expand button
        local collapsedWidth = 50
        local collapsedHeight = 50
        
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(collapsedWidth, collapsedHeight, ImGuiCond.Always)
        
        local windowFlags = ImGuiWindowFlags.NoResize + 
                            ImGuiWindowFlags.NoMove + 
                            ImGuiWindowFlags.NoCollapse +
                            ImGuiWindowFlags.NoScrollbar +
                            ImGuiWindowFlags.NoTitleBar
        
        if ImGui.Begin("##NearbyEntitiesCollapsed", true, windowFlags) then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
            if ImGui.Button(">", 24, 24) then
                nearbyEntitiesVisible = true
            end
            ImGui.PopStyleColor(3)
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Expand Nearby Entities")
            end
        end
        ImGui.End()
    else
        -- Expanded state
        local windowWidth = 220
        local windowHeight = 300
        
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
        
        local windowFlags = ImGuiWindowFlags.NoResize + 
                            ImGuiWindowFlags.NoMove + 
                            ImGuiWindowFlags.NoCollapse +
                            ImGuiWindowFlags.NoScrollbar +
                            ImGuiWindowFlags.NoTitleBar
        
        if ImGui.Begin("##NearbyEntities", true, windowFlags) then
            local totalCount = #nearbyEntities.vehicles + #nearbyEntities.peds + #nearbyEntities.objects
            
            -- Header with collapse button
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.Text("Nearby Entities (" .. totalCount .. ")")
            ImGui.PopStyleColor()
            
            -- Collapse button on right side of header
            ImGui.SameLine(windowWidth - 45)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
            if ImGui.Button("<##collapseNE", 24, 24) then
                nearbyEntitiesVisible = false
            end
            ImGui.PopStyleColor(3)
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Collapse")
            end
            
            ImGui.Separator()
            
            -- Scrollable area for entities
            ImGui.BeginChild("EntityList", 0, windowHeight - 50, false)
            
            -- Vehicles section
            if #nearbyEntities.vehicles > 0 then
                if ImGui.TreeNode("Vehicles (" .. #nearbyEntities.vehicles .. ")") then
                    for i, ent in ipairs(nearbyEntities.vehicles) do
                        local modelName = "Unknown"
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                                modelName = getModelName(ent.handle)
                            end
                        end)
                        
                        local label = string.format("%s - %.0fm", modelName, ent.distance)
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                        ImGui.Text(label)
                        ImGui.PopStyleColor()
                        
                        if ImGui.IsItemClicked() then
                            if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                                selectedEntity = ent.handle
                                selectedEntityType = "vehicle"
                                checkEntityAttachments(ent.handle)
                                updateToggleStatesForEntity(ent.handle)
                            end
                        end
                    end
                    ImGui.TreePop()
                end
            end
            
            -- Peds section
            if #nearbyEntities.peds > 0 then
                if ImGui.TreeNode("Peds (" .. #nearbyEntities.peds .. ")") then
                    for i, ent in ipairs(nearbyEntities.peds) do
                        local modelName = "Ped"
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                                modelName = getModelName(ent.handle)
                            end
                        end)
                        
                        local label = string.format("%s - %.0fm", modelName, ent.distance)
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                        ImGui.Text(label)
                        ImGui.PopStyleColor()
                        
                        if ImGui.IsItemClicked() then
                            if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                                selectedEntity = ent.handle
                                selectedEntityType = "ped"
                                checkEntityAttachments(ent.handle)
                                updateToggleStatesForEntity(ent.handle)
                            end
                        end
                    end
                    ImGui.TreePop()
                end
            end
            
            -- Objects section
            if #nearbyEntities.objects > 0 then
                if ImGui.TreeNode("Objects (" .. #nearbyEntities.objects .. ")") then
                    for i, ent in ipairs(nearbyEntities.objects) do
                        local modelName = "Object"
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                                modelName = getModelName(ent.handle)
                            end
                        end)
                        
                        local label = string.format("%s - %.0fm", modelName, ent.distance)
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                        ImGui.Text(label)
                        ImGui.PopStyleColor()
                        
                        if ImGui.IsItemClicked() then
                            if ENTITY.DOES_ENTITY_EXIST(ent.handle) then
                                selectedEntity = ent.handle
                                selectedEntityType = "object"
                                checkEntityAttachments(ent.handle)
                                updateToggleStatesForEntity(ent.handle)
                            end
                        end
                    end
                    ImGui.TreePop()
                end
            end
            
            if totalCount == 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
                ImGui.Text("No entities nearby")
                ImGui.PopStyleColor()
            end
            
            ImGui.EndChild()
        end
        ImGui.End()
    end
    
    ImGui.PopStyleVar(3)
    ImGui.PopStyleColor(2)
end

-- Render the database window showing saved entities (positioned where nearby entities used to be)
local databaseWindowVisible = true

local function renderDatabaseWindow()
    if not spawnerSettings or not spawnerSettings.enableSpooner then
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    local posX = 10
    local posY = 440
    
    -- Style colors used for both states
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10.0, 8.0)
    
    if not databaseWindowVisible then
        -- Collapsed state - show small expand button
        local collapsedWidth = 50
        local collapsedHeight = 50
        
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(collapsedWidth, collapsedHeight, ImGuiCond.Always)
        
        local windowFlags = ImGuiWindowFlags.NoResize + 
                            ImGuiWindowFlags.NoMove + 
                            ImGuiWindowFlags.NoCollapse +
                            ImGuiWindowFlags.NoScrollbar +
                            ImGuiWindowFlags.NoTitleBar
        
        if ImGui.Begin("##DatabaseCollapsed", true, windowFlags) then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
            if ImGui.Button(">", 24, 24) then
                databaseWindowVisible = true
            end
            ImGui.PopStyleColor(3)
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Expand Database")
            end
        end
        ImGui.End()
    else
        -- Expanded state
        local windowWidth = 220
        local windowHeight = 300
        
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
        
        local windowFlags = ImGuiWindowFlags.NoResize + 
                            ImGuiWindowFlags.NoMove + 
                            ImGuiWindowFlags.NoCollapse +
                            ImGuiWindowFlags.NoScrollbar +
                            ImGuiWindowFlags.NoTitleBar
        
        if ImGui.Begin("##Database", true, windowFlags) then
            -- Count entities in database
            local dbCount = 0
            for _ in pairs(entityDatabase) do
                dbCount = dbCount + 1
            end
            
            -- Header with collapse button
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.Text("Database (" .. dbCount .. ")")
            ImGui.PopStyleColor()
            
            -- Collapse button on right side of header
            ImGui.SameLine(windowWidth - 45)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
            if ImGui.Button("<##collapseDB", 24, 24) then
                databaseWindowVisible = false
            end
            ImGui.PopStyleColor(3)
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Collapse")
            end
            

            -- Scrollable area for database entities
            ImGui.BeginChild("DatabaseList", 0, windowHeight - 50, false)
            
            -- "Self" Option
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0)
            ImGui.Text("Self")
            ImGui.PopStyleColor()
            if ImGui.IsItemClicked() then
                Script.QueueJob(function()
                     pcall(function()
                        local playerPed = PLAYER.PLAYER_PED_ID()
                        if ENTITY.DOES_ENTITY_EXIST(playerPed) then
                            selectedEntity = playerPed
                            selectedEntityType = "ped"
                            checkEntityAttachments(playerPed)
                            updateToggleStatesForEntity(playerPed)
                        end
                     end)
                end)
            end
            ImGui.Separator()
            
            -- Organize entities by type
            local dbVehicles = {}
            local dbPeds = {}
            local dbObjects = {}
            
            for handle, data in pairs(entityDatabase) do
                if ENTITY.DOES_ENTITY_EXIST(handle) then
                    if data.type == "vehicle" then
                        table.insert(dbVehicles, {handle = handle, data = data})
                    elseif data.type == "ped" then
                        table.insert(dbPeds, {handle = handle, data = data})
                    elseif data.type == "object" then
                        table.insert(dbObjects, {handle = handle, data = data})
                    end
                else
                    -- Entity no longer exists, remove from database
                    entityDatabase[handle] = nil
                end
            end
            
            -- Vehicles section
            if #dbVehicles > 0 then
                if ImGui.TreeNode("Vehicles (" .. #dbVehicles .. ")") then
                    for i, item in ipairs(dbVehicles) do
                        local modelName = "Unknown"
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(item.handle) then
                                modelName = getModelName(item.handle)
                            end
                        end)
                        
                        local label = modelName
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                        ImGui.Text(label)
                        ImGui.PopStyleColor()
                        
                        if ImGui.IsItemClicked() then
                            if ENTITY.DOES_ENTITY_EXIST(item.handle) then
                                selectedEntity = item.handle
                                selectedEntityType = "vehicle"
                                checkEntityAttachments(item.handle)
                                updateToggleStatesForEntity(item.handle)
                            end
                        end
                    end
                    ImGui.TreePop()
                end
            end
            
            -- Peds section
            if #dbPeds > 0 then
                if ImGui.TreeNode("Peds (" .. #dbPeds .. ")") then
                    for i, item in ipairs(dbPeds) do
                        local modelName = "Ped"
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(item.handle) then
                                modelName = getModelName(item.handle)
                            end
                        end)
                        
                        local label = modelName
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                        ImGui.Text(label)
                        ImGui.PopStyleColor()
                        
                        if ImGui.IsItemClicked() then
                            if ENTITY.DOES_ENTITY_EXIST(item.handle) then
                                selectedEntity = item.handle
                                selectedEntityType = "ped"
                                checkEntityAttachments(item.handle)
                                updateToggleStatesForEntity(item.handle)
                            end
                        end
                    end
                    ImGui.TreePop()
                end
            end
            
            -- Objects section
            if #dbObjects > 0 then
                if ImGui.TreeNode("Objects (" .. #dbObjects .. ")") then
                    for i, item in ipairs(dbObjects) do
                        local modelName = "Object"
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(item.handle) then
                                modelName = getModelName(item.handle)
                            end
                        end)
                        
                        local label = modelName
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                        ImGui.Text(label)
                        ImGui.PopStyleColor()
                        
                        if ImGui.IsItemClicked() then
                            if ENTITY.DOES_ENTITY_EXIST(item.handle) then
                                selectedEntity = item.handle
                                selectedEntityType = "object"
                                checkEntityAttachments(item.handle)
                                updateToggleStatesForEntity(item.handle)
                            end
                        end
                    end
                    ImGui.TreePop()
                end
            end
            
            if dbCount == 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
                ImGui.Text("No entities in database")
                ImGui.PopStyleColor()
            end
            
            ImGui.EndChild()
        end
        ImGui.End()
    end
    
    ImGui.PopStyleVar(3)
    ImGui.PopStyleColor(2)
end

-- ============================================================================
-- Vehicle Customizations Window
-- ============================================================================

local vehicleCustomsVisible = false
local vehicleCustomsState = {
    -- Mod Options
    bulletproofTires = false,
    lowGripTires = false,
    turbo = false,
    tiresmoke = false,
    -- Slot selection
    selectedSlot = 0,
    selectedMod = -1,
    -- Neon lights
    neonLeft = false,
    neonRight = false,
    neonFront = false,
    neonBack = false,
    headlights = false,
    -- Color selection
    colorToChange = 0, -- 0=Primary, 1=Secondary, 2=Pearlescent, 3=Interior, 4=Dashboard, 5=TireSmoke, 6=Wheel, 7=Headlight, 8=Neon
    colorType = 0, -- 0=Custom, 1=Chrome, 2=Classic, 3=Matte, 4=Metals, 5=Util, 6=Worn
    customColor = {0, 0, 0}, -- RGB
    -- Plate
    plateText = ""
}

-- Slot names for display
local modSlotNames = {
    [-1] = "Window Tint",
    [-2] = "Plate Style",
    [-4] = "Wheel Type",
    [0] = "Spoiler",
    [1] = "Front Bumper",
    [2] = "Rear Bumper",
    [3] = "Side Skirts",
    [4] = "Exhaust",
    [5] = "Roll Cage",
    [6] = "Grille",
    [7] = "Hood",
    [8] = "Fender",
    [9] = "Right Fender",
    [10] = "Roof",
    [11] = "Engine",
    [12] = "Brakes",
    [13] = "Transmission",
    [14] = "Horns",
    [15] = "Suspension",
    [16] = "Armor",
    [18] = "Turbo",
    [22] = "Xenon Lights",
    [23] = "Front Wheels",
    [24] = "Rear Wheels",
    [25] = "Plate Holder",
    [26] = "Vanity Plates",
    [27] = "Trim",
    [28] = "Ornaments",
    [29] = "Dashboard",
    [30] = "Dial",
    [31] = "Door Speaker",
    [32] = "Seats",
    [33] = "Steering Wheel",
    [34] = "Shifter Leavers",
    [35] = "Plaques",
    [36] = "Speakers",
    [37] = "Trunk",
    [38] = "Hydraulics",
    [39] = "Engine Block",
    [40] = "Air Filter",
    [41] = "Struts",
    [42] = "Arch Cover",
    [43] = "Aerials",
    [44] = "Trim 2",
    [45] = "Tank",
    [46] = "Windows",
    [48] = "Livery"
}

-- Color option names
local colorOptionNames = {
    [0] = "Primary",
    [1] = "Secondary",
    [2] = "Pearlescent",
    [3] = "Interior",
    [4] = "Dashboard",
    [5] = "Tire Smoke",
    [6] = "Wheel Color",
    [7] = "Headlight",
    [8] = "Neon"
}

-- Color type names for primary/secondary
local colorTypeNames = {
    [0] = "Custom",
    [1] = "Remove Custom",
    [2] = "Chrome",
    [3] = "Classic",
    [4] = "Matte",
    [5] = "Metals",
    [6] = "Util",
    [7] = "Worn"
}

-- Function to open vehicle customizations
function M.openVehicleCustomizations()
    vehicleCustomsVisible = true
    -- Reset state to defaults - we can't call natives from render thread
    -- The actual vehicle state will be read/set when user interacts
    vehicleCustomsState.bulletproofTires = false
    vehicleCustomsState.lowGripTires = false
    vehicleCustomsState.turbo = false
    vehicleCustomsState.tiresmoke = false
    vehicleCustomsState.headlights = false
    vehicleCustomsState.neonLeft = false
    vehicleCustomsState.neonRight = false
    vehicleCustomsState.neonFront = false
    vehicleCustomsState.neonBack = false
    vehicleCustomsState.plateText = "CHERAX"
    vehicleCustomsState.customColor = {0, 0, 0}
    vehicleCustomsState.selectedSlot = 0
    vehicleCustomsState.selectedMod = -1
    vehicleCustomsState.colorToChange = 0
    vehicleCustomsState.isStandalone = false -- Not standalone when opened normally
end

-- Function to close vehicle customizations
function M.closeVehicleCustomizations()
    vehicleCustomsVisible = false
end

-- Render the Vehicle Customizations window
local function renderVehicleCustomizationsWindow()
    if not vehicleCustomsVisible then return end
    -- No longer require full Spooner mode - can be opened from Spooner Tab
    if selectedEntity == 0 or selectedEntityType ~= "vehicle" then
        vehicleCustomsVisible = false
        return
    end
    
    local success, err = pcall(function()
        if not ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
            vehicleCustomsVisible = false
            return
        end
        
        local screenWidth, screenHeight = ImGui.GetDisplaySize()
        if not screenWidth or not screenHeight then return end
        
        -- Window size and position (centered-ish, to the right of entity options)
        local windowWidth = 600
        local windowHeight = 750
        local posX = 235
        local posY = 10
        
        -- Adjust position if standalone
        if vehicleCustomsState.isStandalone then
            posX = 10
            posY = 10
        end
        
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
        
        -- Window flags
        local windowFlags = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoCollapse + ImGuiWindowFlags.NoMove
        
        -- Style the window (Matching Browser Window)
        ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
        ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.15, 0.12, 0.2, 0.9)
        ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0.25, 0.2, 0.35, 1.0)
        ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0.3, 0.25, 0.4, 1.0)
        ImGui.PushStyleColor(ImGuiCol.Header, 0.25, 0.15, 0.4, 0.8)
        ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.35, 0.25, 0.5, 1.0)
        ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.4, 0.3, 0.55, 1.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4.0)
        
        if ImGui.Begin("##VehicleCustoms", true, windowFlags) then
            -- Custom Header
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.SetWindowFontScale(1.3)
            ImGui.Text("Vehicle Customizations")
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()
            
            -- Close button (X)
            ImGui.SameLine(windowWidth - 40)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
            if ImGui.Button("X", 25, 25) then
                vehicleCustomsVisible = false
            end
            ImGui.PopStyleColor(3)
            
            -- Keep original vehicle customizations code...
            
            ImGui.Separator()
            ImGui.Spacing()
            local vehicle = selectedEntity
            
            -- Verify vehicle still exists
            if not ENTITY.DOES_ENTITY_EXIST(vehicle) then
                ImGui.Text("Vehicle no longer exists")
                ImGui.End()
                ImGui.PopStyleVar(4)
                ImGui.PopStyleColor(8)
                vehicleCustomsVisible = false
                return
            end

            -- Auto-close if selection changed
            if vehicleCustomsState.targetEntity and vehicleCustomsState.targetEntity ~= selectedEntity then
                 vehicleCustomsVisible = false
                 ImGui.End()
                 ImGui.PopStyleVar(4)
                 ImGui.PopStyleColor(8)
                 return
            end
            
            -- Row 1: Max Vehicle button and Plate Number
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.35, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.45, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.4, 1.0)
            
            if ImGui.Button("Max Vehicle", 120, 0) then
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
                            for i = 0, 49 do
                                local numMods = VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, i)
                                if numMods and numMods > 0 then
                                    VEHICLE.SET_VEHICLE_MOD(vehicle, i, numMods - 1, false)
                                end
                            end
                            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, 18, true)
                            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, 20, true)
                            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, 22, true)
                            VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicle, false)
                            GUI.AddToast("LS Customs", "Vehicle maxed!", 2000, 0)
                        end
                    end)
                end)
            end
            ImGui.PopStyleColor(3)
            
            ImGui.SameLine()
            
            -- Plate text input
            ImGui.PushItemWidth(120)
            vehicleCustomsState.plateText = ImGui.InputText("##plateText", vehicleCustomsState.plateText or "CHERAX", 8)
            ImGui.PopItemWidth()
            ImGui.SameLine()
            
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.35, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.45, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.4, 1.0)
            if ImGui.Button("Change Plate", 130, 0) then
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicle, vehicleCustomsState.plateText or "")
                        end
                    end)
                end)
            end
            ImGui.PopStyleColor(3)
            
            -- ======== Mod Options Section ========
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.Text("Mod Options")
            ImGui.PopStyleColor()
            ImGui.Separator()
            
            -- Bulletproof Tires
            local newBulletproof = ImGui.Checkbox("Bulletproof Tires", vehicleCustomsState.bulletproofTires or false)
            if newBulletproof ~= vehicleCustomsState.bulletproofTires then
                vehicleCustomsState.bulletproofTires = newBulletproof
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicle, not newBulletproof)
                        end
                    end)
                end)
            end
            
            ImGui.SameLine()
            
            -- Turbo
            local newTurbo = ImGui.Checkbox("Turbo", vehicleCustomsState.turbo or false)
            if newTurbo ~= vehicleCustomsState.turbo then
                vehicleCustomsState.turbo = newTurbo
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, 18, newTurbo)
                        end
                    end)
                end)
            end
            
            ImGui.SameLine()
            
            -- Tiresmoke
            local newTiresmoke = ImGui.Checkbox("Tiresmoke", vehicleCustomsState.tiresmoke or false)
            if newTiresmoke ~= vehicleCustomsState.tiresmoke then
                vehicleCustomsState.tiresmoke = newTiresmoke
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, 20, newTiresmoke)
                        end
                    end)
                end)
            end
            
            -- ======== Slot Section ========
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.Text("Slot")
            ImGui.PopStyleColor()
            ImGui.Separator()
            
            -- Slots list
            ImGui.BeginChild("SlotList", 180, 160, true)
            local slotOrder = {-1, -2, -4, 0, 1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 23, 48}
            
            for _, slot in ipairs(slotOrder) do
                local slotName = modSlotNames[slot] or ("Slot " .. slot)
                local isSelected = vehicleCustomsState.selectedSlot == slot
                
                if ImGui.Selectable(slotName .. "##slot" .. slot, isSelected) then
                    vehicleCustomsState.selectedSlot = slot
                    vehicleCustomsState.selectedMod = -1
                end
            end
            ImGui.EndChild()
            
            ImGui.SameLine()
            
            -- Mods list for selected slot
            ImGui.BeginChild("ModList", 300, 160, true)
            if vehicleCustomsState.selectedSlot ~= nil then
                local slot = vehicleCustomsState.selectedSlot
                
                -- Handle special slots
                if slot == -1 then -- Window Tint
                    local tintNames = {"None", "Pure Black", "Dark Smoke", "Light Smoke", "Stock", "Limo", "Green"}
                    for i, name in ipairs(tintNames) do
                        if ImGui.Selectable(name .. "##tint" .. i, false) then
                            Script.QueueJob(function()
                                pcall(function()
                                    if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                                        VEHICLE.SET_VEHICLE_WINDOW_TINT(vehicle, i - 1)
                                    end
                                end)
                            end)
                        end
                    end
                elseif slot == -2 then -- Plate Style
                    local plateStyles = {"Blue/White 1", "Yellow/Black", "Yellow/Blue", "Blue/White 2", "Blue/White 3", "Yankton"}
                    for i, name in ipairs(plateStyles) do
                        if ImGui.Selectable(name .. "##plate" .. i, false) then
                            Script.QueueJob(function()
                                pcall(function()
                                    if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                                        VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(vehicle, i - 1)
                                    end
                                end)
                            end)
                        end
                    end
                elseif slot == -4 then -- Wheel Type
                    local wheelTypes = {"Sport", "Muscle", "Lowrider", "SUV", "Offroad", "Tuner", "Bike", "High End"}
                    for i, name in ipairs(wheelTypes) do
                        if ImGui.Selectable(name .. "##wheel" .. i, false) then
                            Script.QueueJob(function()
                                pcall(function()
                                    if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                                        VEHICLE.SET_VEHICLE_WHEEL_TYPE(vehicle, i - 1)
                                    end
                                end)
                            end)
                        end
                    end
                else
                    -- Regular mod slots
                    local numMods = 0
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            numMods = VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, slot) or 0
                        end
                    end)
                    
                    if numMods > 0 then
                        -- Stock option
                        if ImGui.Selectable("Stock##mod-1", vehicleCustomsState.selectedMod == -1) then
                            vehicleCustomsState.selectedMod = -1
                            Script.QueueJob(function()
                                pcall(function()
                                    if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                                        VEHICLE.REMOVE_VEHICLE_MOD(vehicle, slot)
                                    end
                                end)
                            end)
                        end
                        
                        for i = 0, numMods - 1 do
                            local modName = "Mod " .. (i + 1)
                            if ImGui.Selectable(modName .. "##mod" .. i, vehicleCustomsState.selectedMod == i) then
                                vehicleCustomsState.selectedMod = i
                                Script.QueueJob(function()
                                    pcall(function()
                                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                                            VEHICLE.SET_VEHICLE_MOD(vehicle, slot, i, false)
                                        end
                                    end)
                                end)
                            end
                        end
                    else
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
                        ImGui.Text("No mods")
                        ImGui.PopStyleColor()
                    end
                end
            end
            ImGui.EndChild()
            
            -- ======== Neon Light Options Section ========
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.Text("Neon Light Options")
            ImGui.PopStyleColor()
            ImGui.Separator()
            
            -- Headlight checkbox
            local newHeadlight = ImGui.Checkbox("Xenon", vehicleCustomsState.headlights or false)
            if newHeadlight ~= vehicleCustomsState.headlights then
                vehicleCustomsState.headlights = newHeadlight
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.TOGGLE_VEHICLE_MOD(vehicle, 22, newHeadlight)
                        end
                    end)
                end)
            end
            
            ImGui.SameLine()
            
            -- Left neon
            local newLeft = ImGui.Checkbox("L", vehicleCustomsState.neonLeft or false)
            if newLeft ~= vehicleCustomsState.neonLeft then
                vehicleCustomsState.neonLeft = newLeft
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicle, 0, newLeft)
                        end
                    end)
                end)
            end
            
            ImGui.SameLine()
            
            -- Right neon
            local newRight = ImGui.Checkbox("R", vehicleCustomsState.neonRight or false)
            if newRight ~= vehicleCustomsState.neonRight then
                vehicleCustomsState.neonRight = newRight
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicle, 1, newRight)
                        end
                    end)
                end)
            end
            
            ImGui.SameLine()
            
            -- Front neon
            local newFront = ImGui.Checkbox("F", vehicleCustomsState.neonFront or false)
            if newFront ~= vehicleCustomsState.neonFront then
                vehicleCustomsState.neonFront = newFront
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicle, 2, newFront)
                        end
                    end)
                end)
            end
            
            ImGui.SameLine()
            
            ImGui.SameLine()
            
            -- Back neon
            local newBack = ImGui.Checkbox("B", vehicleCustomsState.neonBack or false)
            if newBack ~= vehicleCustomsState.neonBack then
                vehicleCustomsState.neonBack = newBack
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                            VEHICLE.SET_VEHICLE_NEON_ENABLED(vehicle, 3, newBack)
                        end
                    end)
                end)
            end
            
            -- ======== Color Options Section ========
            ImGui.Spacing()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.Text("Color Options")
            ImGui.PopStyleColor()
            ImGui.Separator()
            
            -- Color selection list (left side)
            ImGui.BeginChild("ColorOptionsList", 130, 200, true)
            for i = 0, 8 do
                local name = colorOptionNames[i] or ("Color " .. i)
                if ImGui.Selectable(name .. "##color" .. i, vehicleCustomsState.colorToChange == i) then
                    vehicleCustomsState.colorToChange = i
                end
            end
            ImGui.EndChild()
            
            ImGui.SameLine()
            
            -- Color Picker (compact HSV picker with RGB/Hex inputs and preview)
            ImGui.BeginGroup()
                -- Get current RGB values
                local rInt = vehicleCustomsState.customColor[1] or 0
                local gInt = vehicleCustomsState.customColor[2] or 0
                local bInt = vehicleCustomsState.customColor[3] or 0
                
                -- Convert to 0-1 range for the picker
                local r = rInt / 255.0
                local g = gInt / 255.0
                local b = bInt / 255.0
                
                -- Create a table for the color picker (normalized 0-1 values)
                local colorTable = {r, g, b}
                
                -- Color picker flags: show hue bar, no alpha, no side preview, no inputs, no label
                local pickerFlags = ImGuiColorEditFlags.PickerHueBar + 
                                   ImGuiColorEditFlags.NoAlpha + 
                                   ImGuiColorEditFlags.NoSidePreview + 
                                   ImGuiColorEditFlags.NoInputs +
                                   ImGuiColorEditFlags.NoLabel +
                                   ImGuiColorEditFlags.NoSmallPreview
                
                -- Make the picker smaller by setting item width
                ImGui.PushItemWidth(150)
                
                -- Draw the color picker
                local newColor, changed = ImGui.ColorPicker3("##vehicleColorPicker", colorTable, pickerFlags)
                
                ImGui.PopItemWidth()
                
                -- Flag to track if we need to apply color
                local applyColor = false
                
                if changed and newColor then
                    -- Convert back to 0-255 range
                    rInt = math.floor(newColor[1] * 255 + 0.5)
                    gInt = math.floor(newColor[2] * 255 + 0.5)
                    bInt = math.floor(newColor[3] * 255 + 0.5)
                    
                    vehicleCustomsState.customColor[1] = rInt
                    vehicleCustomsState.customColor[2] = gInt
                    vehicleCustomsState.customColor[3] = bInt
                    applyColor = true
                end
                
                -- RGB number inputs below the picker
                ImGui.Spacing()
                ImGui.PushItemWidth(45)
                
                local newR = ImGui.InputInt("##colorR", rInt, 0, 0)
                if newR and newR ~= rInt then
                    newR = math.max(0, math.min(255, newR))
                    vehicleCustomsState.customColor[1] = newR
                    applyColor = true
                end
                
                ImGui.SameLine()
                local newG = ImGui.InputInt("##colorG", gInt, 0, 0)
                if newG and newG ~= gInt then
                    newG = math.max(0, math.min(255, newG))
                    vehicleCustomsState.customColor[2] = newG
                    applyColor = true
                end
                
                ImGui.SameLine()
                local newB = ImGui.InputInt("##colorB", bInt, 0, 0)
                if newB and newB ~= bInt then
                    newB = math.max(0, math.min(255, newB))
                    vehicleCustomsState.customColor[3] = newB
                    applyColor = true
                end
                
                ImGui.PopItemWidth()
                
                -- Hex input below the RGB inputs
                local hexVal = string.format("#%02X%02X%02X", 
                    vehicleCustomsState.customColor[1] or 0, 
                    vehicleCustomsState.customColor[2] or 0, 
                    vehicleCustomsState.customColor[3] or 0)
                
                -- Initialize hex input state if not exists
                if not vehicleCustomsState.hexInput then
                    vehicleCustomsState.hexInput = hexVal
                end
                
                ImGui.PushItemWidth(145)
                local newHex = ImGui.InputText("##colorHex", vehicleCustomsState.hexInput, 8)
                ImGui.PopItemWidth()
                
                if newHex and newHex ~= vehicleCustomsState.hexInput then
                    vehicleCustomsState.hexInput = newHex
                    -- Parse hex color
                    local hexStr = newHex:gsub("#", "")
                    if #hexStr == 6 then
                        local hexR = tonumber(hexStr:sub(1, 2), 16)
                        local hexG = tonumber(hexStr:sub(3, 4), 16)
                        local hexB = tonumber(hexStr:sub(5, 6), 16)
                        if hexR and hexG and hexB then
                            vehicleCustomsState.customColor[1] = hexR
                            vehicleCustomsState.customColor[2] = hexG
                            vehicleCustomsState.customColor[3] = hexB
                            applyColor = true
                        end
                    end
                else
                    -- Update hex input to match current color if not focused
                    vehicleCustomsState.hexInput = hexVal
                end
                
                -- Apply color if changed
                if applyColor then
                    Script.QueueJob(function()
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(vehicle) then
                                local cr = vehicleCustomsState.customColor[1] or 0
                                local cg = vehicleCustomsState.customColor[2] or 0
                                local cb = vehicleCustomsState.customColor[3] or 0
                                local colorTarget = vehicleCustomsState.colorToChange or 0
                                
                                if colorTarget == 0 then
                                    VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicle, cr, cg, cb)
                                elseif colorTarget == 1 then
                                    VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicle, cr, cg, cb)
                                elseif colorTarget == 5 then
                                    VEHICLE.SET_VEHICLE_TYRE_SMOKE_COLOR(vehicle, cr, cg, cb)
                                end
                            end
                        end)
                    end)
                end
            ImGui.EndGroup()
            
            ImGui.SameLine()
            
            -- Color Preview Box (to the right)
            ImGui.BeginGroup()
                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                ImGui.Text("Preview")
                ImGui.PopStyleColor()
                
                -- Get cursor position for drawing the preview
                local cursorX, cursorY = ImGui.GetCursorScreenPos()
                
                -- Draw preview box with current color
                local previewR = vehicleCustomsState.customColor[1] or 0
                local previewG = vehicleCustomsState.customColor[2] or 0
                local previewB = vehicleCustomsState.customColor[3] or 0
                
                -- Draw filled rect for color preview (60x60 box)
                ImGui.AddRectFilled(cursorX, cursorY, cursorX + 60, cursorY + 60, 
                    previewR, previewG, previewB, 255, 4.0)
                
                -- Draw border around preview
                ImGui.AddRect(cursorX, cursorY, cursorX + 60, cursorY + 60, 
                    100, 100, 120, 255, 4.0, 0, 1.0)
                
                -- Add dummy to reserve space
                ImGui.Dummy(60, 60)
            ImGui.EndGroup()
        end
        ImGui.End()
        
        ImGui.PopStyleVar(4)
        ImGui.PopStyleColor(8)
    end)
    
    if not success then
        M.debug_print("[Spooner] Vehicle Customizations error: " .. tostring(err))
    end
end

-- ============================================================================
-- Ped Customizations Window
-- ============================================================================

local pedCustomsVisible = false
local pedCustomsState = {
    targetEntity = nil,
    -- Component values (drawable and texture for each)
    components = {}, -- [componentId] = {drawable = 0, texture = 0, maxDrawable = 0, maxTexture = 0}
    -- Prop values (drawable and texture for each)
    props = {}, -- [propId] = {drawable = -1, texture = 0, maxDrawable = 0, maxTexture = 0}
    -- Step size for +/- buttons
    step = 1
}

-- Component names matching the reference image
local pedComponentNames = {
    [2] = "Hair Style",
    [1] = "Masks",
    [3] = "Torsos",
    [8] = "Undershirts",
    [11] = "Tops",
    [9] = "Armor",
    [7] = "Accessories",
    [5] = "Bags",
    [4] = "Legs",
    [6] = "Feet",
    [10] = "Decals"
}

-- Order for components display (matches reference image)
local pedComponentOrder = {2, 1, 3, 8, 11, 9, 7, 5, 4, 6, 10}


-- Prop names matching the reference image
local pedPropNames = {
    [0] = "Hats",
    [1] = "Glasses",
    [2] = "Ears",
    [6] = "Watches"
}

-- Order for props display
local pedPropOrder = {0, 1, 2, 6}

-- Function to open ped customizations
local pedPreviewJobRunning = false

local function startPedPreviewLoop()
    if pedPreviewJobRunning then return end
    pedPreviewJobRunning = true

    Script.QueueJob(function()
        while pedPreviewJobRunning and pedCustomsVisible do
            if selectedEntity and selectedEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
                local ped = selectedEntity
                local cPed = nil
                -- Try to get CPed object
                if ped == PLAYER.PLAYER_PED_ID() then
                     cPed = Players.GetCPed(PLAYER.PLAYER_ID())
                else
                    local count = PoolMgr.GetCurrentPedCount()
                    local maxCheck = math.min(count, 250)
                    for i = 0, maxCheck - 1 do
                        if PoolMgr.GetPed(i) == ped then
                            cPed = PoolMgr.GetCPed(i)
                            break
                        end
                    end
                end

                if cPed and GTA and GTA.DrawPedPreview then
                     local screenWidth, screenHeight = ImGui.GetDisplaySize()
                     if screenWidth and screenHeight then
                        local windowWidth = 550
                        local windowHeight = 500
                        local posX = 235
                        local posY = 10
                        
                        -- Adjust preview position based on standalone mode
                        if pedCustomsState.isStandalone then
                            posX = 10
                            posY = 10
                        end
                        
                        local previewW = 0.25
                        local previewH = 0.5
                        
                        local centerX = (posX + windowWidth * 0.5) / screenWidth
                        local topY = (posY + windowHeight) / screenHeight + 0.01 
                        
                        -- If standalone, put preview BELOW the window and a bit to the left
                        if pedCustomsState.isStandalone then
                             local startY = posY + windowHeight + 10
                             topY = startY / screenHeight
                             
                             -- Center of window minus offset
                             local pixelCenterX = (posX + windowWidth * 0.5) + 50
                             centerX = pixelCenterX / screenWidth
                        else
                             -- Normal position
                             topY = (posY + windowHeight) / screenHeight + 0.01 
                        end
                        
                        local centerY = topY + previewH * 0.5
                        
                        -- Clamp to screen
                        if centerY + previewH * 0.5 > 1.0 then
                            centerY = 1.0 - previewH * 0.5
                        end

                        GTA.DrawPedPreview(cPed, V2.New(centerX, centerY), V2.New(previewW, previewH), -3.0, 0.0, 0.0, 1.0)
                     end
                end
            end
            Script.Yield(0)
        end
        pedPreviewJobRunning = false
    end)
end

function M.openPedCustomizations()
    pedCustomsVisible = true
    if not pedCustomsState then pedCustomsState = {} end
    pedCustomsState.isStandalone = false 
    startPedPreviewLoop()
    pedCustomsState.targetEntity = selectedEntity
    pedCustomsState.components = {}
    pedCustomsState.props = {}
    -- Values will be populated in render function via queued job
end

-- Function to close ped customizations
function M.closePedCustomizations()
    pedCustomsVisible = false
end

-- Get/Set ped customizations visibility
function M.getPedCustomsVisible()
    return pedCustomsVisible
end

function M.setPedCustomsVisible(visible)
    pedCustomsVisible = visible
end

-- Get/Set vehicle customizations visibility
function M.getVehicleCustomsVisible()
    return vehicleCustomsVisible
end

function M.setVehicleCustomsVisible(visible)
    vehicleCustomsVisible = visible
end

-- Close all sub-windows (Browser, PED Customizations, Vehicle Customizations)
function M.closeAllSubWindows()
    browserVisible = false
    pedCustomsVisible = false
    vehicleCustomsVisible = false
end

-- Open PED Customizations with the player's own ped (for Spooner Tab access)
function M.openPlayerPedCustomizations()
    local playerPed = PLAYER.PLAYER_PED_ID()
    if playerPed and playerPed ~= 0 and ENTITY.DOES_ENTITY_EXIST(playerPed) then
        selectedEntity = playerPed
        selectedEntityType = "ped"
        pedCustomsVisible = true
        
        if not pedCustomsState then pedCustomsState = {} end
        pedCustomsState.targetEntity = playerPed
        pedCustomsState.isStandalone = true
        pedCustomsState.components = {}
        pedCustomsState.props = {}
        checkEntityAttachments(playerPed)
        updateToggleStatesForEntity(playerPed, true)
        startPedPreviewLoop()
        return true
    end
    return false
end

-- Open Vehicle Customizations with the player's current vehicle (for Spooner Tab access)
function M.openPlayerVehicleCustomizations()
    local playerPed = PLAYER.PLAYER_PED_ID()
    if not playerPed or playerPed == 0 then
        return false, "No player ped"
    end
    
    -- Check if player is in a vehicle
    local vehicle = PED.GET_VEHICLE_PED_IS_IN(playerPed, false)
    if not vehicle or vehicle == 0 or not ENTITY.DOES_ENTITY_EXIST(vehicle) then
        return false, "You need to be in a vehicle"
    end
    
    selectedEntity = vehicle
    selectedEntityType = "vehicle"
    vehicleCustomsVisible = true
    
    vehicleCustomsState.targetEntity = vehicle
    vehicleCustomsState.isStandalone = true -- MARK AS STANDALONE
    
    -- Reset state to defaults
    vehicleCustomsState.bulletproofTires = false
    vehicleCustomsState.lowGripTires = false
    vehicleCustomsState.turbo = false
    vehicleCustomsState.tiresmoke = false
    vehicleCustomsState.headlights = false
    vehicleCustomsState.neonLeft = false
    vehicleCustomsState.neonRight = false
    vehicleCustomsState.neonFront = false
    vehicleCustomsState.neonBack = false
    vehicleCustomsState.plateText = "CHERAX"
    vehicleCustomsState.customColor = {0, 0, 0}
    vehicleCustomsState.selectedSlot = 0
    vehicleCustomsState.selectedMod = -1
    vehicleCustomsState.colorToChange = 0
    checkEntityAttachments(vehicle)
    updateToggleStatesForEntity(vehicle)
    return true
end

-- Render the Ped Customizations window
local function renderPedCustomizationsWindow()
    if not pedCustomsVisible then return end
    -- No longer require full Spooner mode - can be opened from Spooner Tab
    if selectedEntity == 0 or selectedEntityType ~= "ped" then
        pedCustomsVisible = false
        return
    end
    
    local success, err = pcall(function()
        if not ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
            pedCustomsVisible = false
            return
        end
        
        local screenWidth, screenHeight = ImGui.GetDisplaySize()
        if not screenWidth or not screenHeight then return end
        
        -- Window size and position (centered-ish, to the right of entity options)
        local windowWidth = 550
        local windowHeight = 500
        local posX = 235
        local posY = 10
        
        -- Adjust position if standalone
        if pedCustomsState.isStandalone then
            posX = 10
            posY = 10
        end
        
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
        
        -- Window flags
        local windowFlags = ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoCollapse + ImGuiWindowFlags.NoMove
        
        -- Style the window (Matching Vehicle Customizations Window)
        ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
        ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.15, 0.12, 0.2, 0.9)
        ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0.25, 0.2, 0.35, 1.0)
        ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0.3, 0.25, 0.4, 1.0)
        ImGui.PushStyleColor(ImGuiCol.Header, 0.25, 0.15, 0.4, 0.8)
        ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.35, 0.25, 0.5, 1.0)
        ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.4, 0.3, 0.55, 1.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4.0)
        
        if ImGui.Begin("##PedCustoms", true, windowFlags) then
            -- Custom Header
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.SetWindowFontScale(1.3)
            ImGui.Text("Ped Customizations")
            ImGui.SetWindowFontScale(1.0)
            ImGui.PopStyleColor()
            
            -- Swap to Ped button (light blue, to the left of Random)
            local isPlayerPed = false
            pcall(function()
                if selectedEntity == PLAYER.PLAYER_PED_ID() then
                    isPlayerPed = true
                end
            end)
            
            if not isPlayerPed then
                ImGui.SameLine(windowWidth - 250)
                ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.6, 1.0, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.7, 1.0, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.5, 0.9, 1.0)
                if ImGui.Button("Swap to Ped", 120, 35) then
                    local pedToSwap = selectedEntity
                    Script.QueueJob(function()
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(pedToSwap) then
                                local player = PLAYER.PLAYER_ID()
                                PLAYER.CHANGE_PLAYER_PED(player, pedToSwap, true, true)
                            end
                        end)
                    end)
                end
                ImGui.PopStyleColor(3)
            end
            
            -- Randomize button (green, to the left of X)
            ImGui.SameLine(windowWidth - 120)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.4, 0.2, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.2, 0.5, 0.25, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.12, 0.35, 0.18, 1.0)
            if ImGui.Button("Random", 80, 35) then
                local pedToRandomize = selectedEntity
                Script.QueueJob(function()
                    pcall(function()
                        if not ENTITY.DOES_ENTITY_EXIST(pedToRandomize) then return end
                        
                        -- Randomize all components
                        for _, compId in ipairs(pedComponentOrder) do
                            local maxDrawable = PED.GET_NUMBER_OF_PED_DRAWABLE_VARIATIONS(pedToRandomize, compId) or 0
                            if maxDrawable > 1 then
                                local randomDrawable = math.random(0, maxDrawable - 1)
                                local maxTexture = PED.GET_NUMBER_OF_PED_TEXTURE_VARIATIONS(pedToRandomize, compId, randomDrawable) or 0
                                local randomTexture = 0
                                if maxTexture > 1 then
                                    randomTexture = math.random(0, maxTexture - 1)
                                end
                                PED.SET_PED_COMPONENT_VARIATION(pedToRandomize, compId, randomDrawable, randomTexture, 0)
                            end
                        end
                        
                        -- Randomize all props
                        for _, propId in ipairs(pedPropOrder) do
                            local maxDrawable = PED.GET_NUMBER_OF_PED_PROP_DRAWABLE_VARIATIONS(pedToRandomize, propId) or 0
                            if maxDrawable > 0 then
                                -- Include -1 as option (no prop)
                                local randomDrawable = math.random(-1, maxDrawable - 1)
                                if randomDrawable == -1 then
                                    PED.CLEAR_PED_PROP(pedToRandomize, propId)
                                else
                                    local maxTexture = PED.GET_NUMBER_OF_PED_PROP_TEXTURE_VARIATIONS(pedToRandomize, propId, randomDrawable) or 0
                                    local randomTexture = 0
                                    if maxTexture > 1 then
                                        randomTexture = math.random(0, maxTexture - 1)
                                    end
                                    PED.SET_PED_PROP_INDEX(pedToRandomize, propId, randomDrawable, randomTexture, true)
                                end
                            end
                        end
                    end)
                end)
            end
            ImGui.PopStyleColor(3)
            ImGui.SameLine()
            
            -- Close button (X)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)

            if ImGui.Button("X##closePedCustoms", 25, 25) then
                pedCustomsVisible = false
            end
            ImGui.PopStyleColor(3)

            
            local ped = selectedEntity
            
            -- Verify ped still exists
            if not ENTITY.DOES_ENTITY_EXIST(ped) then
                ImGui.Text("Ped no longer exists")
                ImGui.End()
                ImGui.PopStyleVar(4)
                ImGui.PopStyleColor(8)
                pedCustomsVisible = false
                return
            end

            -- Auto-close if selection changed
            if pedCustomsState.targetEntity and pedCustomsState.targetEntity ~= selectedEntity then
                 pedCustomsVisible = false
                 ImGui.End()
                 ImGui.PopStyleVar(4)
                 ImGui.PopStyleColor(8)
                 return
            end
            
            ImGui.Separator()
            ImGui.Spacing()
            
            local ped = selectedEntity
            local sliderWidth = 120
            local buttonWidth = 22
            local contentWidth = windowWidth - 30
            local panelHeight = windowHeight - 80
            
            -- First, check if there's anything to customize
            local hasComponents = false
            local hasProps = false
            
            for _, compId in ipairs(pedComponentOrder) do
                local maxDrawable = 0
                pcall(function() maxDrawable = PED.GET_NUMBER_OF_PED_DRAWABLE_VARIATIONS(ped, compId) or 0 end)
                if maxDrawable > 1 then hasComponents = true break end
            end
            
            for _, propId in ipairs(pedPropOrder) do
                local maxDrawable = 0
                pcall(function() maxDrawable = PED.GET_NUMBER_OF_PED_PROP_DRAWABLE_VARIATIONS(ped, propId) or 0 end)
                if maxDrawable > 0 then hasProps = true break end
            end
            
            if not hasComponents and not hasProps then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
                ImGui.Text("No customization options available for this ped.")
                ImGui.PopStyleColor()
            else
                -- Single scrolling panel for both Components and Props
                ImGui.BeginChild("CustomizationsPanel", contentWidth, panelHeight, false)
                
                -- Components Section
                if hasComponents then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
                    ImGui.SetWindowFontScale(1.1)
                    ImGui.Text("Components")
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.PopStyleColor()
                    ImGui.Separator()
                    ImGui.Spacing()
                    
                    for _, compId in ipairs(pedComponentOrder) do
                        local compName = pedComponentNames[compId]
                        if compName then
                            local maxDrawable = 0
                            pcall(function() maxDrawable = PED.GET_NUMBER_OF_PED_DRAWABLE_VARIATIONS(ped, compId) or 0 end)
                            
                            -- Only show if there are more than 1 variation (0 is always there)
                            if maxDrawable > 1 then
                                local currentDrawable = 0
                                local currentTexture = 0
                                local maxTexture = 0
                                pcall(function()
                                    currentDrawable = PED.GET_PED_DRAWABLE_VARIATION(ped, compId) or 0
                                    currentTexture = PED.GET_PED_TEXTURE_VARIATION(ped, compId) or 0
                                    maxTexture = PED.GET_NUMBER_OF_PED_TEXTURE_VARIATIONS(ped, compId, currentDrawable) or 0
                                end)
                                
                                -- Component name
                                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                                ImGui.Text(compName)
                                ImGui.PopStyleColor()
                                ImGui.SameLine(100)
                                
                                -- Drawable Slider
                                ImGui.PushItemWidth(sliderWidth)
                                local newDrawable = ImGui.SliderInt("##CompDraw" .. compId, currentDrawable, 0, maxDrawable - 1)
                                if newDrawable ~= currentDrawable then
                                    Script.QueueJob(function()
                                        pcall(function()
                                            if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                PED.SET_PED_COMPONENT_VARIATION(ped, compId, newDrawable, 0, 0)
                                            end
                                        end)
                                    end)
                                end
                                ImGui.PopItemWidth()
                                ImGui.SameLine()
                                
                                -- Minus button
                                if ImGui.Button("-##CompDraw" .. compId .. "M", buttonWidth, 0) then
                                    local newVal = math.max(0, currentDrawable - 1)
                                    Script.QueueJob(function()
                                        pcall(function()
                                            if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                PED.SET_PED_COMPONENT_VARIATION(ped, compId, newVal, 0, 0)
                                            end
                                        end)
                                    end)
                                end
                                ImGui.SameLine()
                                
                                -- Plus button
                                if ImGui.Button("+##CompDraw" .. compId .. "P", buttonWidth, 0) then
                                    local newVal = math.min(maxDrawable - 1, currentDrawable + 1)
                                    Script.QueueJob(function()
                                        pcall(function()
                                            if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                PED.SET_PED_COMPONENT_VARIATION(ped, compId, newVal, 0, 0)
                                            end
                                        end)
                                    end)
                                end
                                
                                -- Texture slider (only if there are texture variations)
                                if maxTexture > 1 then
                                    ImGui.SameLine()
                                    ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.7, 0.9, 1.0)
                                    ImGui.Text("T:")
                                    ImGui.PopStyleColor()
                                    ImGui.SameLine()
                                    ImGui.PushItemWidth(60)
                                    local newTexture = ImGui.SliderInt("##CompTex" .. compId, currentTexture, 0, maxTexture - 1)
                                    if newTexture ~= currentTexture then
                                        Script.QueueJob(function()
                                            pcall(function()
                                                if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                    PED.SET_PED_COMPONENT_VARIATION(ped, compId, currentDrawable, newTexture, 0)
                                                end
                                            end)
                                        end)
                                    end
                                    ImGui.PopItemWidth()
                                    ImGui.SameLine()
                                    
                                    -- Minus button for Texture
                                    if ImGui.Button("-##CompTex" .. compId .. "M", buttonWidth, 0) then
                                        local newVal = math.max(0, currentTexture - 1)
                                        Script.QueueJob(function()
                                            pcall(function()
                                                if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                    PED.SET_PED_COMPONENT_VARIATION(ped, compId, currentDrawable, newVal, 0)
                                                end
                                            end)
                                        end)
                                    end
                                    ImGui.SameLine()
                                    
                                    -- Plus button for Texture
                                    if ImGui.Button("+##CompTex" .. compId .. "P", buttonWidth, 0) then
                                        local newVal = math.min(maxTexture - 1, currentTexture + 1)
                                        Script.QueueJob(function()
                                            pcall(function()
                                                if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                    PED.SET_PED_COMPONENT_VARIATION(ped, compId, currentDrawable, newVal, 0)
                                                end
                                            end)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                    
                    ImGui.Spacing()
                end

                
                -- Props Section
                if hasProps then
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
                    ImGui.SetWindowFontScale(1.1)
                    ImGui.Text("Props")
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.PopStyleColor()
                    ImGui.Separator()
                    ImGui.Spacing()
                    
                    for _, propId in ipairs(pedPropOrder) do
                        local propName = pedPropNames[propId]
                        if propName then
                            local maxDrawable = 0
                            pcall(function() maxDrawable = PED.GET_NUMBER_OF_PED_PROP_DRAWABLE_VARIATIONS(ped, propId) or 0 end)
                            
                            -- Only show if there are variations
                            if maxDrawable > 0 then
                                local currentDrawable = -1
                                local currentTexture = 0
                                local maxTexture = 0
                                pcall(function()
                                    currentDrawable = PED.GET_PED_PROP_INDEX(ped, propId) or -1
                                    currentTexture = PED.GET_PED_PROP_TEXTURE_INDEX(ped, propId) or 0
                                    if currentDrawable >= 0 then
                                        maxTexture = PED.GET_NUMBER_OF_PED_PROP_TEXTURE_VARIATIONS(ped, propId, currentDrawable) or 0
                                    end
                                end)
                                
                                -- Prop name
                                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                                ImGui.Text(propName)
                                ImGui.PopStyleColor()
                                ImGui.SameLine(100)
                                
                                -- Drawable Slider (allow -1 for no prop)
                                ImGui.PushItemWidth(sliderWidth)
                                local newDrawable = ImGui.SliderInt("##PropDraw" .. propId, currentDrawable, -1, maxDrawable - 1)
                                if newDrawable ~= currentDrawable then
                                    Script.QueueJob(function()
                                        pcall(function()
                                            if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                if newDrawable == -1 then
                                                    PED.CLEAR_PED_PROP(ped, propId)
                                                else
                                                    PED.SET_PED_PROP_INDEX(ped, propId, newDrawable, 0, true)
                                                end
                                            end
                                        end)
                                    end)
                                end
                                ImGui.PopItemWidth()
                                ImGui.SameLine()
                                
                                -- Minus button
                                if ImGui.Button("-##PropDraw" .. propId .. "M", buttonWidth, 0) then
                                    local newVal = math.max(-1, currentDrawable - 1)
                                    Script.QueueJob(function()
                                        pcall(function()
                                            if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                if newVal == -1 then
                                                    PED.CLEAR_PED_PROP(ped, propId)
                                                else
                                                    PED.SET_PED_PROP_INDEX(ped, propId, newVal, 0, true)
                                                end
                                            end
                                        end)
                                    end)
                                end
                                ImGui.SameLine()
                                
                                -- Plus button
                                if ImGui.Button("+##PropDraw" .. propId .. "P", buttonWidth, 0) then
                                    local newVal = math.min(maxDrawable - 1, currentDrawable + 1)
                                    Script.QueueJob(function()
                                        pcall(function()
                                            if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                PED.SET_PED_PROP_INDEX(ped, propId, newVal, 0, true)
                                            end
                                        end)
                                    end)
                                end
                                
                                -- Texture slider (only if there are texture variations and prop is equipped)
                                if currentDrawable >= 0 and maxTexture > 1 then
                                    ImGui.SameLine()
                                    ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.7, 0.9, 1.0)
                                    ImGui.Text("T:")
                                    ImGui.PopStyleColor()
                                    ImGui.SameLine()
                                    ImGui.PushItemWidth(60)
                                    local newTexture = ImGui.SliderInt("##PropTex" .. propId, currentTexture, 0, maxTexture - 1)
                                    if newTexture ~= currentTexture then
                                        Script.QueueJob(function()
                                            pcall(function()
                                                if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                    PED.SET_PED_PROP_INDEX(ped, propId, currentDrawable, newTexture, true)
                                                end
                                            end)
                                        end)
                                    end
                                    ImGui.PopItemWidth()
                                    ImGui.SameLine()
                                     
                                    -- Minus button for Texture (Prop)
                                    if ImGui.Button("-##PropTex" .. propId .. "M", buttonWidth, 0) then
                                        local newVal = math.max(0, currentTexture - 1)
                                        Script.QueueJob(function()
                                            pcall(function()
                                                if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                    PED.SET_PED_PROP_INDEX(ped, propId, currentDrawable, newVal, true)
                                                end
                                            end)
                                        end)
                                    end
                                    ImGui.SameLine()
                                    
                                    -- Plus button for Texture (Prop)
                                    if ImGui.Button("+##PropTex" .. propId .. "P", buttonWidth, 0) then
                                        local newVal = math.min(maxTexture - 1, currentTexture + 1)
                                        Script.QueueJob(function()
                                            pcall(function()
                                                if ENTITY.DOES_ENTITY_EXIST(ped) then
                                                    PED.SET_PED_PROP_INDEX(ped, propId, currentDrawable, newVal, true)
                                                end
                                            end)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end

                
                ImGui.EndChild()
            end
            
        end
        
        ImGui.End()
        
        ImGui.PopStyleVar(4)
        ImGui.PopStyleColor(8)
    end)
    
    if not success then
        M.debug_print("[Spooner] Ped Customizations error: " .. tostring(err))
    end
end

-- Get model name from hash (returns hash as string if name not found)



-- ============================================================================
-- Entity Attach Window
-- ============================================================================

local attachWindowVisible = false
local attachWindowHoveredEntity = 0 -- Track hovered entity for marker drawing
local attachSettings = {
    keepWorldPos = true
}

-- Forward declarations for attachments window state (defined fully later, but needed here)
local attachmentsWindowVisible = false
local attachmentsWindowState = {
    selectedAttachment = nil,
    selectedAttachmentType = nil,
    boneIndex = 0,
    offsetX = 0.0,
    offsetY = 0.0,
    offsetZ = 0.0,
    rotPitch = 0.0,
    rotRoll = 0.0,
    rotYaw = 0.0
}

function M.openAttachWindow()
    attachWindowVisible = true
    attachWindowHoveredEntity = 0
end


local function renderAttachWindow()
    if not attachWindowVisible then return end
    if not spawnerSettings or not spawnerSettings.enableSpooner then return end
    
    if selectedEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
        attachWindowVisible = false
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    -- Window size and position (to the right of entity options, similar to Customs)
    local windowWidth = 300
    local windowHeight = 400
    local posX = 240 -- Similar to Vehicle Customs
    local posY = 10
    
    ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    
    local windowFlags = ImGuiWindowFlags.NoResize + 
                        ImGuiWindowFlags.NoMove + 
                        ImGuiWindowFlags.NoCollapse +
                        ImGuiWindowFlags.NoTitleBar
    
    -- Style the window
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
    
    if ImGui.Begin("##AttachWindow", true, windowFlags) then
        -- Header
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.SetWindowFontScale(1.2)
        ImGui.Text("Attach to Something")
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()
        
        -- Close button
        ImGui.SameLine(windowWidth - 35)
        ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
        if ImGui.Button("X", 20, 20) then
            attachWindowVisible = false
        end
        ImGui.PopStyleColor()
        
        ImGui.Separator()
        ImGui.Spacing()
        
        -- Options
        local keepPos = ImGui.Checkbox("Keep World Position", attachSettings.keepWorldPos)
        if keepPos ~= attachSettings.keepWorldPos then
            attachSettings.keepWorldPos = keepPos
        end
        
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Text("Select Entity from Database:")
        ImGui.BeginChild("DatabaseList", 0, 0, true)
        
        -- "Self" Option
        ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0)
        ImGui.Text("Self")
        ImGui.PopStyleColor()
        if ImGui.IsItemHovered() then
            attachWindowHoveredEntity = PLAYER.PLAYER_PED_ID()
        end
        if ImGui.IsItemClicked() then
            local targetEntity = PLAYER.PLAYER_PED_ID()
            local entityToAttach = selectedEntity
            local entityToAttachType = selectedEntityType
            local useKeepPos = attachSettings.keepWorldPos
            
            -- IMPORTANT: Set UI state SYNCHRONOUSLY before Script.QueueJob()
            -- This ensures renderAttachmentsWindow() sees the correct state immediately
            attachWindowVisible = false
            selectedEntity = targetEntity
            selectedEntityType = "ped"
            updateToggleStatesForEntity(targetEntity)
            
            -- Set attachment list synchronously so window doesn't close
            selectedEntityAttachments.list = {{handle = entityToAttach, type = entityToAttachType}}
            selectedEntityAttachments.attachmentCount = 1
            
            -- Open attachments window and pre-select the just-attached entity
            attachmentsWindowVisible = true
            attachmentsWindowState.selectedAttachment = entityToAttach
            attachmentsWindowState.selectedAttachmentType = entityToAttachType
            attachmentsWindowState.boneIndex = 0
            attachmentsWindowState.offsetX = 0.0
            attachmentsWindowState.offsetY = 0.0
            attachmentsWindowState.offsetZ = 0.0
            attachmentsWindowState.rotPitch = 0.0
            attachmentsWindowState.rotRoll = 0.0
            attachmentsWindowState.rotYaw = 0.0
            
            -- ASYNC: Only the actual attach operation needs to be in QueueJob
            Script.QueueJob(function()
                pcall(function()
                    if ENTITY.DOES_ENTITY_EXIST(entityToAttach) and ENTITY.DOES_ENTITY_EXIST(targetEntity) then
                        local boneIndex = 0
                        local xPos, yPos, zPos = 0.0, 0.0, 0.0
                        local xRot, yRot, zRot = 0.0, 0.0, 0.0
                        local p9 = false
                        local useSoftPinning = false
                        local collision = false
                        local isPed = ENTITY.IS_ENTITY_A_PED(targetEntity) or ENTITY.IS_ENTITY_A_PED(entityToAttach)
                        local vertexIndex = 0
                        local fixedRot = true
                        
                        if useKeepPos then
                            ENTITY.ATTACH_ENTITY_TO_ENTITY(entityToAttach, targetEntity, boneIndex, xPos, yPos, zPos, xRot, yRot, zRot, p9, useSoftPinning, collision, isPed, vertexIndex, fixedRot)
                        else
                             ENTITY.ATTACH_ENTITY_TO_ENTITY(entityToAttach, targetEntity, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, p9, useSoftPinning, collision, isPed, vertexIndex, fixedRot)
                        end
                        
                        GUI.AddToast("Spooner", "Entity Attached!", 2000, 0)
                    end
                end)
            end)
        end
        ImGui.Separator()


        -- Organize entities by type
        local dbVehicles = {}
        local dbPeds = {}
        local dbObjects = {}
        
        for handle, data in pairs(entityDatabase) do
            if handle ~= selectedEntity and ENTITY.DOES_ENTITY_EXIST(handle) then
                if data.type == "vehicle" then
                    table.insert(dbVehicles, {handle = handle, data = data})
                elseif data.type == "ped" then
                    table.insert(dbPeds, {handle = handle, data = data})
                elseif data.type == "object" then
                    table.insert(dbObjects, {handle = handle, data = data})
                end
            end
        end
        
        local hasItems = (#dbVehicles > 0) or (#dbPeds > 0) or (#dbObjects > 0)
        
        -- Helper to render a group of entities
        local function renderEntityGroup(title, entities)
            if ImGui.TreeNode(title) then
                for _, item in ipairs(entities) do
                    local name = "Unknown"
                    if item.data and item.data.customName then
                        name = item.data.customName
                    else
                        name = getModelName(item.handle)
                    end
                    
                    local label = string.format("%s (ID: %d)", name, item.handle)
                    
                    if ImGui.Selectable(label, false) then
                        local targetEntity = item.handle
                        local targetEntityType = item.data and item.data.type or "object"
                        local entityToAttach = selectedEntity
                        local entityToAttachType = selectedEntityType
                        local useKeepPos = attachSettings.keepWorldPos
                        
                        -- IMPORTANT: Set UI state SYNCHRONOUSLY before Script.QueueJob()
                        -- This ensures renderAttachmentsWindow() sees the correct state immediately
                        attachWindowVisible = false
                        selectedEntity = targetEntity
                        selectedEntityType = targetEntityType
                        updateToggleStatesForEntity(targetEntity)
                        
                        -- Set attachment list synchronously so window doesn't close
                        selectedEntityAttachments.list = {{handle = entityToAttach, type = entityToAttachType}}
                        selectedEntityAttachments.attachmentCount = 1
                        
                        -- Open attachments window and pre-select the just-attached entity
                        attachmentsWindowVisible = true
                        attachmentsWindowState.selectedAttachment = entityToAttach
                        attachmentsWindowState.selectedAttachmentType = entityToAttachType
                        attachmentsWindowState.boneIndex = 0
                        attachmentsWindowState.offsetX = 0.0
                        attachmentsWindowState.offsetY = 0.0
                        attachmentsWindowState.offsetZ = 0.0
                        attachmentsWindowState.rotPitch = 0.0
                        attachmentsWindowState.rotRoll = 0.0
                        attachmentsWindowState.rotYaw = 0.0
                        
                        -- ASYNC: Only the actual attach operation needs to be in QueueJob
                        Script.QueueJob(function()
                            pcall(function()
                                if ENTITY.DOES_ENTITY_EXIST(entityToAttach) and ENTITY.DOES_ENTITY_EXIST(targetEntity) then
                                    local boneIndex = 0
                                    local xPos, yPos, zPos = 0.0, 0.0, 0.0
                                    local xRot, yRot, zRot = 0.0, 0.0, 0.0
                                    local p9 = false
                                    local useSoftPinning = false
                                    local collision = false
                                    local isPed = ENTITY.IS_ENTITY_A_PED(targetEntity) or ENTITY.IS_ENTITY_A_PED(entityToAttach)
                                    local vertexIndex = 0
                                    local fixedRot = true
                                    
                                    if useKeepPos then
                                        ENTITY.ATTACH_ENTITY_TO_ENTITY(entityToAttach, targetEntity, boneIndex, xPos, yPos, zPos, xRot, yRot, zRot, p9, useSoftPinning, collision, isPed, vertexIndex, fixedRot)
                                    else
                                         ENTITY.ATTACH_ENTITY_TO_ENTITY(entityToAttach, targetEntity, boneIndex, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, p9, useSoftPinning, collision, isPed, vertexIndex, fixedRot)
                                    end
                                    
                                    GUI.AddToast("Spooner", "Entity Attached!", 2000, 0)
                                end
                            end)
                        end)
                    end
                    -- Track hovered entity for marker drawing
                    if ImGui.IsItemHovered() then
                        attachWindowHoveredEntity = item.handle
                    end
                end
                ImGui.TreePop()
            end
        end


        if #dbVehicles > 0 then
            renderEntityGroup("Vehicles##attach", dbVehicles)
        end
        if #dbPeds > 0 then
            renderEntityGroup("Peds##attach", dbPeds)
        end
        if #dbObjects > 0 then
            renderEntityGroup("Objects##attach", dbObjects)
        end
        
        if not hasItems then
            ImGui.TextDisabled("Database is empty or contains only selected entity")
        end
        
        ImGui.EndChild()
    end
    ImGui.End()
    
    ImGui.PopStyleVar(3)
    ImGui.PopStyleColor(2)
    
    -- Draw purple marker over hovered entity
    if attachWindowHoveredEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(attachWindowHoveredEntity) then
        local pos = ENTITY.GET_ENTITY_COORDS(attachWindowHoveredEntity, true)
        if pos then
            -- Marker type 2 = upside-down cone
            -- Purple color
            GRAPHICS.DRAW_MARKER(
                2,                          -- type (upside-down cone)
                pos.x, pos.y, pos.z + 1,  -- position (above entity)

                0.0, 0.0, 0.0,              -- direction
                180.0, 0.0, 0.0,            -- rotation (flip upside down)
                0.3, 0.3, 0.3,              -- scale (small)
                150, 50, 200, 200,          -- R, G, B, A (purple)
                false,                      -- bob up and down
                false,                      -- face camera
                2,                          -- p19
                false,                      -- rotate
                nil,                        -- texture dict
                nil,                        -- texture name
                false                       -- draw on entities
            )
        end
    end

    
    -- Reset hovered entity for next frame
    attachWindowHoveredEntity = 0
end


-- ============================================================================
-- Attachments Window (View/Edit entities attached to selected entity)
-- ============================================================================

-- (attachmentsWindowVisible and attachmentsWindowState declared earlier for forward reference)

-- Common GTA bone enum IDs (for use with GET_PED_BONE_INDEX)

-- These are the bone enum values, NOT the bone indices. Use getPedBoneIndex() to get actual indices.
local boneList = {
    {name = "Root (Default)", boneEnum = 0},
    {name = "SKEL_Pelvis", boneEnum = 11816},
    {name = "SKEL_Spine_Root", boneEnum = 57597},
    {name = "SKEL_Spine0", boneEnum = 23553},
    {name = "SKEL_Spine1", boneEnum = 24816},
    {name = "SKEL_Spine2", boneEnum = 24817},
    {name = "SKEL_Spine3", boneEnum = 24818},
    {name = "SKEL_Neck_1", boneEnum = 39317},
    {name = "SKEL_Head", boneEnum = 31086},
    {name = "IK_Head", boneEnum = 12844},
    {name = "FACIAL_facialRoot", boneEnum = 65068},
    {name = "SKEL_L_Clavicle", boneEnum = 64729},
    {name = "SKEL_L_UpperArm", boneEnum = 45509},
    {name = "SKEL_L_Forearm", boneEnum = 61163},
    {name = "SKEL_L_Hand", boneEnum = 18905},
    {name = "SKEL_L_Finger00", boneEnum = 26610},
    {name = "SKEL_L_Finger01", boneEnum = 4089},
    {name = "SKEL_L_Finger02", boneEnum = 4090},
    {name = "SKEL_L_Finger10", boneEnum = 26611},
    {name = "SKEL_L_Finger20", boneEnum = 26612},
    {name = "SKEL_L_Finger30", boneEnum = 26613},
    {name = "SKEL_L_Finger40", boneEnum = 26614},
    {name = "PH_L_Hand", boneEnum = 60309},
    {name = "SKEL_R_Clavicle", boneEnum = 10706},
    {name = "SKEL_R_UpperArm", boneEnum = 40269},
    {name = "SKEL_R_Forearm", boneEnum = 28252},
    {name = "SKEL_R_Hand", boneEnum = 57005},
    {name = "SKEL_R_Finger00", boneEnum = 58866},
    {name = "SKEL_R_Finger01", boneEnum = 64016},
    {name = "SKEL_R_Finger02", boneEnum = 64017},
    {name = "SKEL_R_Finger10", boneEnum = 58867},
    {name = "SKEL_R_Finger20", boneEnum = 58868},
    {name = "SKEL_R_Finger30", boneEnum = 58869},
    {name = "SKEL_R_Finger40", boneEnum = 58870},
    {name = "PH_R_Hand", boneEnum = 28422},
    {name = "SKEL_L_Thigh", boneEnum = 58271},
    {name = "SKEL_L_Calf", boneEnum = 63931},
    {name = "SKEL_L_Foot", boneEnum = 14201},
    {name = "SKEL_L_Toe0", boneEnum = 2108},
    {name = "IK_L_Foot", boneEnum = 65245},
    {name = "PH_L_Foot", boneEnum = 2060},
    {name = "SKEL_R_Thigh", boneEnum = 51826},
    {name = "SKEL_R_Calf", boneEnum = 36864},
    {name = "SKEL_R_Foot", boneEnum = 52301},
    {name = "SKEL_R_Toe0", boneEnum = 20781},
    {name = "IK_R_Foot", boneEnum = 35502},
    {name = "PH_R_Foot", boneEnum = 20718},
    {name = "RB_L_ArmRoll", boneEnum = 5232},
    {name = "RB_R_ArmRoll", boneEnum = 37119},
    {name = "RB_Neck_1", boneEnum = 35731}
}

-- Get bone index for attachment (uses native function)
local function getBoneIndex(entity, boneEnum)
    if not entity or entity == 0 or not ENTITY.DOES_ENTITY_EXIST(entity) then
        return 0
    end
    
    -- For peds, use GET_PED_BONE_INDEX with the bone enum
    if ENTITY.IS_ENTITY_A_PED(entity) then
        local result = 0
        pcall(function()
            result = PED.GET_PED_BONE_INDEX(entity, boneEnum)
        end)
        return result
    end
    
    -- For non-peds (vehicles, objects), bone index is usually 0 or use the enum directly
    -- Most vehicles don't have named bones accessible this way
    return boneEnum
end

function M.openAttachmentsWindow()
    attachmentsWindowVisible = true
    -- Reset selection when opening
    attachmentsWindowState.selectedAttachment = nil
    attachmentsWindowState.selectedAttachmentType = nil
    attachmentsWindowState.boneIndex = 0
    attachmentsWindowState.offsetX = 0.0
    attachmentsWindowState.offsetY = 0.0
    attachmentsWindowState.offsetZ = 0.0
    attachmentsWindowState.rotPitch = 0.0
    attachmentsWindowState.rotRoll = 0.0
    attachmentsWindowState.rotYaw = 0.0
end

-- ============================================================================
-- 3D Position Gizmo Helper Functions
-- ============================================================================

-- Convert world position to screen coordinates (returns x, y in 0-1 range, or nil if not on screen)
local function worldToScreen(worldX, worldY, worldZ)
    local screenX, screenY = nil, nil
    pcall(function()
        -- Use Cherax GTA.WorldToScreen API which returns normalized 0-1 screen coordinates
        screenX, screenY = GTA.WorldToScreen(worldX, worldY, worldZ)
    end)
    return screenX, screenY
end



-- Draw a solid 3D arrow using DRAW_POLY triangles (rectangular shaft + pyramid head)
local function drawGizmoArrow(originX, originY, originZ, axisX, axisY, axisZ, length, r, g, b, alpha, isHovered)
    -- Normalize the axis direction
    local dirLen = math.sqrt(axisX * axisX + axisY * axisY + axisZ * axisZ)
    if dirLen < 0.001 then return end
    local dx, dy, dz = axisX / dirLen, axisY / dirLen, axisZ / dirLen
    
    -- Increase alpha and size if hovered
    local drawAlpha = isHovered and 255 or alpha
    local shaftWidth = isHovered and 0.08 or 0.05
    local headWidth = isHovered and 0.25 or 0.18
    local headLength = isHovered and 0.35 or 0.28
    local shaftLength = length - headLength
    
    -- Calculate perpendicular vectors for creating the 3D shape
    -- Find a vector not parallel to the axis
    local perpX, perpY, perpZ
    if math.abs(dz) < 0.9 then
        -- Cross with up vector (0,0,1)
        perpX = dy
        perpY = -dx
        perpZ = 0
    else
        -- Cross with forward vector (0,1,0)
        perpX = dz
        perpY = 0
        perpZ = -dx
    end
    
    -- Normalize perpendicular
    local perpLen = math.sqrt(perpX * perpX + perpY * perpY + perpZ * perpZ)
    if perpLen < 0.001 then perpLen = 1 end
    perpX, perpY, perpZ = perpX / perpLen, perpY / perpLen, perpZ / perpLen
    
    -- Second perpendicular (cross product of direction and first perpendicular)
    local perp2X = dy * perpZ - dz * perpY
    local perp2Y = dz * perpX - dx * perpZ
    local perp2Z = dx * perpY - dy * perpX
    
    -- Helper to draw a double-sided triangle (both winding orders to prevent backface culling)
    local function drawDoubleSidedPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3)
        GRAPHICS.DRAW_POLY(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, drawAlpha)
        GRAPHICS.DRAW_POLY(x1, y1, z1, x3, y3, z3, x2, y2, z2, r, g, b, drawAlpha)  -- Reversed winding
    end
    
    -- Shaft corners at origin (4 corners of square cross-section)
    local s = shaftWidth
    local shaftStart = {
        {originX + perpX * s + perp2X * s, originY + perpY * s + perp2Y * s, originZ + perpZ * s + perp2Z * s},
        {originX - perpX * s + perp2X * s, originY - perpY * s + perp2Y * s, originZ - perpZ * s + perp2Z * s},
        {originX - perpX * s - perp2X * s, originY - perpY * s - perp2Y * s, originZ - perpZ * s - perp2Z * s},
        {originX + perpX * s - perp2X * s, originY + perpY * s - perp2Y * s, originZ + perpZ * s - perp2Z * s}
    }
    
    -- Shaft corners at shaft end (where head starts)
    local shaftEndX = originX + dx * shaftLength
    local shaftEndY = originY + dy * shaftLength
    local shaftEndZ = originZ + dz * shaftLength
    local shaftEnd = {
        {shaftEndX + perpX * s + perp2X * s, shaftEndY + perpY * s + perp2Y * s, shaftEndZ + perpZ * s + perp2Z * s},
        {shaftEndX - perpX * s + perp2X * s, shaftEndY - perpY * s + perp2Y * s, shaftEndZ - perpZ * s + perp2Z * s},
        {shaftEndX - perpX * s - perp2X * s, shaftEndY - perpY * s - perp2Y * s, shaftEndZ - perpZ * s - perp2Z * s},
        {shaftEndX + perpX * s - perp2X * s, shaftEndY + perpY * s - perp2Y * s, shaftEndZ + perpZ * s - perp2Z * s}
    }
    
    -- Draw shaft start cap (2 double-sided triangles)
    drawDoubleSidedPoly(
        shaftStart[1][1], shaftStart[1][2], shaftStart[1][3],
        shaftStart[2][1], shaftStart[2][2], shaftStart[2][3],
        shaftStart[3][1], shaftStart[3][2], shaftStart[3][3]
    )
    drawDoubleSidedPoly(
        shaftStart[1][1], shaftStart[1][2], shaftStart[1][3],
        shaftStart[3][1], shaftStart[3][2], shaftStart[3][3],
        shaftStart[4][1], shaftStart[4][2], shaftStart[4][3]
    )
    
    -- Draw shaft sides (4 rectangular faces = 8 triangles, each double-sided)
    for i = 1, 4 do
        local j = (i % 4) + 1
        -- First triangle of face
        drawDoubleSidedPoly(
            shaftStart[i][1], shaftStart[i][2], shaftStart[i][3],
            shaftStart[j][1], shaftStart[j][2], shaftStart[j][3],
            shaftEnd[i][1], shaftEnd[i][2], shaftEnd[i][3]
        )
        -- Second triangle of face
        drawDoubleSidedPoly(
            shaftStart[j][1], shaftStart[j][2], shaftStart[j][3],
            shaftEnd[j][1], shaftEnd[j][2], shaftEnd[j][3],
            shaftEnd[i][1], shaftEnd[i][2], shaftEnd[i][3]
        )
    end
    
    -- Head base corners (wider than shaft)
    local h = headWidth
    local headBase = {
        {shaftEndX + perpX * h + perp2X * h, shaftEndY + perpY * h + perp2Y * h, shaftEndZ + perpZ * h + perp2Z * h},
        {shaftEndX - perpX * h + perp2X * h, shaftEndY - perpY * h + perp2Y * h, shaftEndZ - perpZ * h + perp2Z * h},
        {shaftEndX - perpX * h - perp2X * h, shaftEndY - perpY * h - perp2Y * h, shaftEndZ - perpZ * h - perp2Z * h},
        {shaftEndX + perpX * h - perp2X * h, shaftEndY + perpY * h - perp2Y * h, shaftEndZ + perpZ * h - perp2Z * h}
    }
    
    -- Head tip (point at the end)
    local tipX = originX + dx * length
    local tipY = originY + dy * length
    local tipZ = originZ + dz * length
    
    -- Draw head sides (4 triangular faces from base corners to tip, each double-sided)
    for i = 1, 4 do
        local j = (i % 4) + 1
        drawDoubleSidedPoly(
            headBase[i][1], headBase[i][2], headBase[i][3],
            headBase[j][1], headBase[j][2], headBase[j][3],
            tipX, tipY, tipZ
        )
    end
    
    -- Draw head base (2 double-sided triangles to close the base)
    drawDoubleSidedPoly(
        headBase[1][1], headBase[1][2], headBase[1][3],
        headBase[2][1], headBase[2][2], headBase[2][3],
        headBase[3][1], headBase[3][2], headBase[3][3]
    )
    drawDoubleSidedPoly(
        headBase[1][1], headBase[1][2], headBase[1][3],
        headBase[3][1], headBase[3][2], headBase[3][3],
        headBase[4][1], headBase[4][2], headBase[4][3]
    )
end






-- Check if mouse is near a gizmo axis arrow (returns distance to axis line in screen space)
local function getDistanceToAxisLine(mouseScreenX, mouseScreenY, originScreenX, originScreenY, endScreenX, endScreenY)
    if not originScreenX or not originScreenY or not endScreenX or not endScreenY then
        return 9999
    end
    
    -- Vector from origin to end
    local lineX = endScreenX - originScreenX
    local lineY = endScreenY - originScreenY
    local lineLenSq = lineX * lineX + lineY * lineY
    
    if lineLenSq < 0.0001 then return 9999 end
    
    -- Vector from origin to mouse
    local toMouseX = mouseScreenX - originScreenX
    local toMouseY = mouseScreenY - originScreenY
    
    -- Project mouse onto line, clamped to [0, 1]
    local t = math.max(0, math.min(1, (toMouseX * lineX + toMouseY * lineY) / lineLenSq))
    
    -- Closest point on line
    local closestX = originScreenX + t * lineX
    local closestY = originScreenY + t * lineY
    
    -- Distance from mouse to closest point
    local dx = mouseScreenX - closestX
    local dy = mouseScreenY - closestY
    
    return math.sqrt(dx * dx + dy * dy)
end

-- Forward declarations for gizmo render loop functions
local startGizmoRenderLoop
local stopGizmoRenderLoop

-- Render the 3D position gizmo
local function renderPositionGizmo()
    -- Use global setting from spawnerSettings
    if not spawnerSettings or not spawnerSettings.enableGizmo then 
        if gizmoState.jobRunning then
            stopGizmoRenderLoop()
        end
        return 
    end
    
    -- Determine what entity to show gizmo on
    -- Priority: attachment (if attachments window open with selection) > selected entity
    local targetHandle = nil
    local isAttachment = false
    local parentEntity = nil
    
    if attachmentsWindowVisible and attachmentsWindowState.selectedAttachment and 
       ENTITY.DOES_ENTITY_EXIST(attachmentsWindowState.selectedAttachment) then
        -- Attachment mode
        targetHandle = attachmentsWindowState.selectedAttachment
        isAttachment = true
        parentEntity = selectedEntity
    elseif selectedEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
        -- Check if selected entity is attached to something
        local isAttachedEntity = false
        if selectedEntityAttachments.isAttached and selectedEntityAttachments.attachedTo ~= 0 and ENTITY.DOES_ENTITY_EXIST(selectedEntityAttachments.attachedTo) then
             isAttachedEntity = true
        end

        if isAttachedEntity then
            -- ATTACHMENT MODE for Selected Entity
            targetHandle = selectedEntity
            isAttachment = true
            parentEntity = selectedEntityAttachments.attachedTo
            
            -- Sync state if we haven't selected this implicit attachment yet
            if attachmentsWindowState.selectedAttachment ~= selectedEntity then
                 attachmentsWindowState.selectedAttachment = selectedEntity
                 attachmentsWindowState.selectedAttachmentType = selectedEntityType or "object"
                 
                 local cached = attachmentOffsetCache[selectedEntity]
                 if cached then
                    attachmentsWindowState.boneIndex = cached.bone or 0
                    attachmentsWindowState.offsetX = cached.offsetX or 0.0
                    attachmentsWindowState.offsetY = cached.offsetY or 0.0
                    attachmentsWindowState.offsetZ = cached.offsetZ or 0.0
                    attachmentsWindowState.rotPitch = cached.rotPitch or 0.0
                    attachmentsWindowState.rotRoll = cached.rotRoll or 0.0
                    attachmentsWindowState.rotYaw = cached.rotYaw or 0.0
                 else
                    -- Defaults - user can adjust from here
                    attachmentsWindowState.boneIndex = 0
                    attachmentsWindowState.offsetX = 0.0
                    attachmentsWindowState.offsetY = 0.0
                    attachmentsWindowState.offsetZ = 0.0
                    attachmentsWindowState.rotPitch = 0.0
                    attachmentsWindowState.rotRoll = 0.0
                    attachmentsWindowState.rotYaw = 0.0
                 end
            end
        else
            -- NORMAL MODE
            -- Selected entity mode - skip peds for now (gizmo only works on vehicles/objects)

            targetHandle = selectedEntity
            isAttachment = false
        end
    end

    
    if not targetHandle then
        if gizmoState.jobRunning then
            stopGizmoRenderLoop()
        end
        return
    end
    
    -- Store current target in gizmoState for render loop
    gizmoState.targetHandle = targetHandle
    gizmoState.isAttachment = isAttachment
    gizmoState.parentEntity = parentEntity
    gizmoState.enabled = true
    
    -- Start the render job loop if not already running
    if not gizmoState.jobRunning then
        startGizmoRenderLoop()
    end
    
    -- Get the target entity's world position for hover detection
    local pos = ENTITY.GET_ENTITY_COORDS(targetHandle, true)
    if not pos then return end
    
    local boxSize = 1.5
    
    -- Calculate arrow origins for hover detection
    local xArrowOrigin = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetHandle, boxSize, 0, 0)
    local yArrowOrigin = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetHandle, 0, boxSize, 0)
    local zArrowOrigin = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetHandle, 0, 0, boxSize)
    
    -- Get arrow directions from entity rotation (use parent for attachments, self for selected entity)
    local rotSource = isAttachment and parentEntity or targetHandle
    local entityRot = ENTITY.GET_ENTITY_ROTATION(rotSource, 2)
    if not entityRot then entityRot = {x = 0, y = 0, z = 0} end
    
    local pitch = math.rad(entityRot.x)
    local roll = math.rad(entityRot.y)
    local yaw = math.rad(entityRot.z)
    
    local cosPitch, sinPitch = math.cos(pitch), math.sin(pitch)
    local cosRoll, sinRoll = math.cos(roll), math.sin(roll)
    local cosYaw, sinYaw = math.cos(yaw), math.sin(yaw)
    
    local function rotateVector(x, y, z)
        local x1 = x * cosYaw - y * sinYaw
        local y1 = x * sinYaw + y * cosYaw
        local z1 = z
        local x2, y2 = x1, y1 * cosPitch - z1 * sinPitch
        local z2 = y1 * sinPitch + z1 * cosPitch
        return x2 * cosRoll + z2 * sinRoll, y2, -x2 * sinRoll + z2 * cosRoll
    end
    
    local xDirX, xDirY, xDirZ = rotateVector(1, 0, 0)
    local yDirX, yDirY, yDirZ = rotateVector(0, 1, 0)
    local zDirX, zDirY, zDirZ = rotateVector(0, 0, 1)
    
    local arrowLength = gizmoState.arrowLength
    
    -- Get screen size for mouse calculations
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    -- Get mouse position
    local mouseX, mouseY = ImGui.GetMousePos()
    local mouseScreenX = mouseX / screenWidth
    local mouseScreenY = mouseY / screenHeight
    
    -- Convert axis positions to screen coordinates for hover detection
    local xOriginSX, xOriginSY = worldToScreen(xArrowOrigin.x, xArrowOrigin.y, xArrowOrigin.z)
    local xEndSX, xEndSY = worldToScreen(xArrowOrigin.x + xDirX * arrowLength, xArrowOrigin.y + xDirY * arrowLength, xArrowOrigin.z + xDirZ * arrowLength)
    
    local yOriginSX, yOriginSY = worldToScreen(yArrowOrigin.x, yArrowOrigin.y, yArrowOrigin.z)
    local yEndSX, yEndSY = worldToScreen(yArrowOrigin.x + yDirX * arrowLength, yArrowOrigin.y + yDirY * arrowLength, yArrowOrigin.z + yDirZ * arrowLength)
    
    local zOriginSX, zOriginSY = worldToScreen(zArrowOrigin.x, zArrowOrigin.y, zArrowOrigin.z)
    local zEndSX, zEndSY = worldToScreen(zArrowOrigin.x + zDirX * arrowLength, zArrowOrigin.y + zDirY * arrowLength, zArrowOrigin.z + zDirZ * arrowLength)
    
    -- Check which axis is hovered (if not dragging)
    local hoverThreshold = 0.05
    gizmoState.hoveredAxis = nil
    
    if not gizmoState.dragging then
        local xDist = getDistanceToAxisLine(mouseScreenX, mouseScreenY, xOriginSX, xOriginSY, xEndSX, xEndSY)
        local yDist = getDistanceToAxisLine(mouseScreenX, mouseScreenY, yOriginSX, yOriginSY, yEndSX, yEndSY)
        local zDist = getDistanceToAxisLine(mouseScreenX, mouseScreenY, zOriginSX, zOriginSY, zEndSX, zEndSY)
        
        local minDist = math.min(xDist, yDist, zDist)
        if minDist < hoverThreshold then
            if xDist == minDist then
                gizmoState.hoveredAxis = "x"
            elseif yDist == minDist then
                gizmoState.hoveredAxis = "y"
            else
                gizmoState.hoveredAxis = "z"
            end
        end
    end
    
    -- Handle mouse interaction
    local mouseHeld = false
    local mouseReleased = false
    
    pcall(function()
        mouseHeld = PAD.IS_DISABLED_CONTROL_PRESSED(0, 24) or
                    PAD.IS_DISABLED_CONTROL_PRESSED(2, 237)
        mouseReleased = not mouseHeld
    end)
    
    if mouseHeld and not gizmoState.dragging and gizmoState.hoveredAxis then
        gizmoState.dragging = true
        gizmoState.dragAxis = gizmoState.hoveredAxis
        gizmoState.lastMouseX = mouseX
        gizmoState.lastMouseY = mouseY
        
        -- Freeze entity at drag start
        if not isAttachment and targetHandle and ENTITY.DOES_ENTITY_EXIST(targetHandle) then
            Script.QueueJob(function()
                pcall(function()
                    ENTITY.FREEZE_ENTITY_POSITION(targetHandle, true)
                end)
            end)
        end
    elseif mouseHeld and gizmoState.dragging and gizmoState.dragAxis then


        local deltaX = (mouseX - gizmoState.lastMouseX) * gizmoState.sensitivity
        local deltaY = (mouseY - gizmoState.lastMouseY) * gizmoState.sensitivity
        
        local positionDelta = 0
        if gizmoState.dragAxis == "z" then
            positionDelta = -deltaY
        else
            positionDelta = deltaX
        end
        
        if math.abs(positionDelta) > 0.001 then
            if isAttachment then
                -- ATTACHMENT MODE: Update offsets and re-attach
                -- Use worldToScreen projection for consistent behavior from all angles
                local capturedAxis = gizmoState.dragAxis
                local capturedDelta = 0  -- Will be calculated from projection
                
                -- Get parent entity rotation to calculate arrow directions in world space
                local entityRot = ENTITY.GET_ENTITY_ROTATION(parentEntity, 2)
                if not entityRot then entityRot = {x = 0, y = 0, z = 0} end
                
                local pitch = math.rad(entityRot.x)
                local roll = math.rad(entityRot.y)
                local yaw = math.rad(entityRot.z)
                
                local cosPitch, sinPitch = math.cos(pitch), math.sin(pitch)
                local cosRoll, sinRoll = math.cos(roll), math.sin(roll)
                local cosYaw, sinYaw = math.cos(yaw), math.sin(yaw)
                
                local function rotateVectorToWorld(x, y, z)
                    local x1 = x * cosYaw - y * sinYaw
                    local y1 = x * sinYaw + y * cosYaw
                    local z1 = z
                    local x2, y2 = x1, y1 * cosPitch - z1 * sinPitch
                    local z2 = y1 * sinPitch + z1 * cosPitch
                    return x2 * cosRoll + z2 * sinRoll, y2, -x2 * sinRoll + z2 * cosRoll
                end
                
                -- Get arrow direction in world space (matches visual arrow)
                local arrowDirX, arrowDirY, arrowDirZ = 0, 0, 0
                if capturedAxis == "x" then
                    arrowDirX, arrowDirY, arrowDirZ = rotateVectorToWorld(1, 0, 0)
                elseif capturedAxis == "y" then
                    arrowDirX, arrowDirY, arrowDirZ = rotateVectorToWorld(0, 1, 0)
                elseif capturedAxis == "z" then
                    arrowDirX, arrowDirY, arrowDirZ = rotateVectorToWorld(0, 0, 1)
                end
                
                -- Use worldToScreen projection for correct direction from any viewing angle
                local entityPos = ENTITY.GET_ENTITY_COORDS(targetHandle, true)
                local shouldApply = false
                
                if entityPos then
                    local arrowOriginX, arrowOriginY, arrowOriginZ = entityPos.x, entityPos.y, entityPos.z
                    local arrowTipX = arrowOriginX + arrowDirX
                    local arrowTipY = arrowOriginY + arrowDirY
                    local arrowTipZ = arrowOriginZ + arrowDirZ
                    
                    local originScreenX, originScreenY = nil, nil
                    local tipScreenX, tipScreenY = nil, nil
                    
                    pcall(function()
                        originScreenX, originScreenY = GTA.WorldToScreen(arrowOriginX, arrowOriginY, arrowOriginZ)
                        tipScreenX, tipScreenY = GTA.WorldToScreen(arrowTipX, arrowTipY, arrowTipZ)
                    end)
                    
                    if originScreenX and originScreenY and tipScreenX and tipScreenY then
                        local arrowScreenX = tipScreenX - originScreenX
                        local arrowScreenY = -(tipScreenY - originScreenY)
                        
                        local screenWidth, screenHeight = ImGui.GetDisplaySize()
                        if screenWidth and screenHeight then
                            local mouseDeltaX = (mouseX - gizmoState.lastMouseX) / screenWidth
                            local mouseDeltaY = -(mouseY - gizmoState.lastMouseY) / screenHeight
                            
                            local arrowScreenLen = math.sqrt(arrowScreenX * arrowScreenX + arrowScreenY * arrowScreenY)
                            
                            if arrowScreenLen > 0.001 then
                                local arrowScreenNormX = arrowScreenX / arrowScreenLen
                                local arrowScreenNormY = arrowScreenY / arrowScreenLen
                                local projection = mouseDeltaX * arrowScreenNormX + mouseDeltaY * arrowScreenNormY
                                
                                capturedDelta = projection * 700 * gizmoState.sensitivity
                                shouldApply = math.abs(capturedDelta) > 0.0001
                            end
                        end
                    end
                end
                
                -- Apply the delta to the appropriate offset (consistent signs for all axes)
                if shouldApply then
                    if capturedAxis == "x" then
                        attachmentsWindowState.offsetX = attachmentsWindowState.offsetX + capturedDelta
                    elseif capturedAxis == "y" then
                        attachmentsWindowState.offsetY = attachmentsWindowState.offsetY + capturedDelta
                    elseif capturedAxis == "z" then
                        attachmentsWindowState.offsetZ = attachmentsWindowState.offsetZ + capturedDelta
                    end
                
                    local boneEnum = attachmentsWindowState.boneIndex
                    local offX = attachmentsWindowState.offsetX
                    local offY = attachmentsWindowState.offsetY
                    local offZ = attachmentsWindowState.offsetZ
                    local rotX = attachmentsWindowState.rotPitch
                    local rotY = attachmentsWindowState.rotRoll
                    local rotZ = attachmentsWindowState.rotYaw
                    
                    attachmentOffsetCache[targetHandle] = {
                        bone = boneEnum, offsetX = offX, offsetY = offY, offsetZ = offZ,
                        rotPitch = rotX, rotRoll = rotY, rotYaw = rotZ
                    }
                    
                    Script.QueueJob(function()
                        pcall(function()
                            if ENTITY.DOES_ENTITY_EXIST(targetHandle) and ENTITY.DOES_ENTITY_EXIST(parentEntity) then
                                local actualBoneIndex = getBoneIndex(parentEntity, boneEnum)
                                ENTITY.DETACH_ENTITY(targetHandle, true, true)
                                local isPed = ENTITY.IS_ENTITY_A_PED(parentEntity) or ENTITY.IS_ENTITY_A_PED(targetHandle)
                                ENTITY.ATTACH_ENTITY_TO_ENTITY(targetHandle, parentEntity, actualBoneIndex, offX, offY, offZ, rotX, rotY, rotZ, false, false, false, isPed, 0, true)
                            end
                        end)
                    end)
                end  -- end if shouldApply
            else
                -- SELECTED ENTITY MODE: Move entity along its local axes (matching visual arrow directions)
                -- (freeze and ped handling done at drag start)
                local capturedHandle = targetHandle
                local capturedAxis = gizmoState.dragAxis
                local capturedDelta = positionDelta
                
                -- Get entity rotation to calculate local axis directions
                local entityRot = ENTITY.GET_ENTITY_ROTATION(capturedHandle, 2)
                if not entityRot then entityRot = {x = 0, y = 0, z = 0} end
                
                local pitch = math.rad(entityRot.x)
                local roll = math.rad(entityRot.y)
                local yaw = math.rad(entityRot.z)
                
                local cosPitch, sinPitch = math.cos(pitch), math.sin(pitch)
                local cosRoll, sinRoll = math.cos(roll), math.sin(roll)
                local cosYaw, sinYaw = math.cos(yaw), math.sin(yaw)
                
                -- Rotate a local unit vector to world space (same as arrow drawing)
                local function rotateVectorToWorld(x, y, z)
                    local x1 = x * cosYaw - y * sinYaw
                    local y1 = x * sinYaw + y * cosYaw
                    local z1 = z
                    local x2, y2 = x1, y1 * cosPitch - z1 * sinPitch
                    local z2 = y1 * sinPitch + z1 * cosPitch
                    return x2 * cosRoll + z2 * sinRoll, y2, -x2 * sinRoll + z2 * cosRoll
                end
                
                -- Calculate the movement direction in world space based on the dragged axis
                local moveDirX, moveDirY, moveDirZ = 0, 0, 0
                if capturedAxis == "x" then
                    moveDirX, moveDirY, moveDirZ = rotateVectorToWorld(1, 0, 0)
                elseif capturedAxis == "y" then
                    moveDirX, moveDirY, moveDirZ = rotateVectorToWorld(0, 1, 0)
                elseif capturedAxis == "z" then
                    moveDirX, moveDirY, moveDirZ = rotateVectorToWorld(0, 0, 1)
                end
                
                -- BULLETPROOF APPROACH: Use worldToScreen to get ACTUAL arrow screen direction
                -- This bypasses all camera math by using GTA's own projection
                
                local entityPos = ENTITY.GET_ENTITY_COORDS(capturedHandle, true)
                
                if entityPos then
                    -- Get arrow origin in world space (at entity position)
                    local arrowOriginX, arrowOriginY, arrowOriginZ = entityPos.x, entityPos.y, entityPos.z
                    
                    -- Get arrow tip in world space (1 unit along arrow direction)
                    local arrowTipX = arrowOriginX + moveDirX
                    local arrowTipY = arrowOriginY + moveDirY
                    local arrowTipZ = arrowOriginZ + moveDirZ
                    
                    -- Convert to screen coordinates using GTA's own projection
                    local originScreenX, originScreenY = nil, nil
                    local tipScreenX, tipScreenY = nil, nil
                    
                    pcall(function()
                        originScreenX, originScreenY = GTA.WorldToScreen(arrowOriginX, arrowOriginY, arrowOriginZ)
                        tipScreenX, tipScreenY = GTA.WorldToScreen(arrowTipX, arrowTipY, arrowTipZ)
                    end)
                    
                    if originScreenX and originScreenY and tipScreenX and tipScreenY then
                        -- Calculate actual screen direction of arrow (in normalized screen coords, 0-1)
                        local arrowScreenX = tipScreenX - originScreenX
                        local arrowScreenY = -(tipScreenY - originScreenY)  -- Invert Y because screen Y goes down
                        
                        -- Get screen dimensions for mouse delta normalization
                        local screenWidth, screenHeight = ImGui.GetDisplaySize()
                        if screenWidth and screenHeight then
                            -- Mouse delta in normalized screen space (0-1 range)
                            local mouseDirX = (mouseX - gizmoState.lastMouseX) / screenWidth
                            local mouseDirY = -(mouseY - gizmoState.lastMouseY) / screenHeight  -- Invert Y
                            
                            -- Normalize arrow screen direction
                            local arrowScreenLen = math.sqrt(arrowScreenX * arrowScreenX + arrowScreenY * arrowScreenY)
                            
                            if arrowScreenLen > 0.001 then
                                local arrowScreenNormX = arrowScreenX / arrowScreenLen
                                local arrowScreenNormY = arrowScreenY / arrowScreenLen
                                
                                -- Project mouse movement onto arrow's screen direction
                                local projection = mouseDirX * arrowScreenNormX + mouseDirY * arrowScreenNormY
                                
                                -- Scale projection to reasonable movement (increased sensitivity)
                                capturedDelta = projection * 700 * gizmoState.sensitivity
                            end
                        end
                    end
                end
                

                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(capturedHandle) then
                            local currentPos = ENTITY.GET_ENTITY_COORDS(capturedHandle, true)
                            if currentPos then
                                local newX = currentPos.x + (moveDirX * capturedDelta)
                                local newY = currentPos.y + (moveDirY * capturedDelta)
                                local newZ = currentPos.z + (moveDirZ * capturedDelta)
                                
                                -- Universal handling for all entities to prevent physics interference
                                -- Freeze and zero velocity on every update
                                -- Note: Peds are already frozen by selection, but redundant freeze is safe
                                if ENTITY.IS_ENTITY_A_VEHICLE(capturedHandle) then
                                    ENTITY.SET_ENTITY_VELOCITY(capturedHandle, 0, 0, 0)
                                end
                                
                                -- Use NO_OFFSET version for everything to avoid ground snapping/physics
                                ENTITY.SET_ENTITY_COORDS_NO_OFFSET(capturedHandle, newX, newY, newZ, false, false, false)
                            end
                        end
                    end)
                end)
            end



        end
        
        gizmoState.lastMouseX = mouseX
        gizmoState.lastMouseY = mouseY
    end
    
    -- Unfreeze entity when drag ends
    if gizmoState.dragging and (mouseReleased or not mouseHeld) then
        -- Restore frozen state based on the toggle (or keep frozen if it's a ped)
        if not isAttachment and targetHandle and ENTITY.DOES_ENTITY_EXIST(targetHandle) then
            local isPed = ENTITY.IS_ENTITY_A_PED(targetHandle)
            local shouldBeFrozen = toggleStates.frozen or isPed -- Peds stay frozen
            
            if not shouldBeFrozen then
                Script.QueueJob(function()
                    pcall(function()
                        ENTITY.FREEZE_ENTITY_POSITION(targetHandle, false)
                    end)
                end)
            end
        end
        gizmoState.dragging = false
        gizmoState.dragAxis = nil
    end
end





-- Start the gizmo rendering job loop (call from renderPositionGizmo when gizmo becomes enabled)
startGizmoRenderLoop = function()
    if gizmoState.jobRunning then return end
    gizmoState.jobRunning = true
    
    Script.QueueJob(function()
        while gizmoState.jobRunning and gizmoState.enabled and spawnerSettings.enableSpooner do
            -- Get current target from gizmoState
            local targetHandle = gizmoState.targetHandle
            local isAttachment = gizmoState.isAttachment
            local parentEntity = gizmoState.parentEntity
            
            if targetHandle and ENTITY.DOES_ENTITY_EXIST(targetHandle) then
                -- Get entity bounding box using model dimensions
                -- GTA V Vector3 has padding: x(4) + pad(4) + y(4) + pad(4) + z(4) + pad(4) = 24 bytes
                local min = Memory.Alloc(24)
                local max = Memory.Alloc(24)
                MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(targetHandle), min, max)

                -- Read with proper Vector3 stride (8 bytes per component due to padding)
                local minX = Memory.ReadFloat(min)
                local minY = Memory.ReadFloat(min + 8)
                local minZ = Memory.ReadFloat(min + 16)
                local maxX = Memory.ReadFloat(max)
                local maxY = Memory.ReadFloat(max + 8)
                local maxZ = Memory.ReadFloat(max + 16)

                Memory.Free(min)
                Memory.Free(max)

                -- Calculate the 8 corners of the bounding box
                local corners = {
                    {minX, minY, minZ}, -- bottom front left
                    {maxX, minY, minZ}, -- bottom front right
                    {maxX, maxY, minZ}, -- bottom back right
                    {minX, maxY, minZ}, -- bottom back left
                    {minX, minY, maxZ}, -- top front left
                    {maxX, minY, maxZ}, -- top front right
                    {maxX, maxY, maxZ}, -- top back right
                    {minX, maxY, maxZ}  -- top back left
                }

                -- Transform corners to world space
                local worldCorners = {}
                for _, corner in ipairs(corners) do
                    local worldPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetHandle, corner[1], corner[2], corner[3])
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
                    
                -- Only draw gizmo arrows when GUI is open
                if IsGUIOpenAndManageBrowser() then
                    -- Calculate arrow origins using model dimensions
                    local xArrowOrigin = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetHandle, maxX, 0, 0)
                    local yArrowOrigin = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetHandle, 0, maxY, 0)
                    local zArrowOrigin = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetHandle, 0, 0, maxZ)
                    
                    -- Get arrow directions from rotation source (parent for attachments, self for selected)
                    local rotSource = isAttachment and parentEntity or targetHandle
                    local entityRot = rotSource and ENTITY.GET_ENTITY_ROTATION(rotSource, 2) or {x = 0, y = 0, z = 0}
                    if not entityRot then entityRot = {x = 0, y = 0, z = 0} end
                    
                    local pitch = math.rad(entityRot.x)
                    local roll = math.rad(entityRot.y)
                    local yaw = math.rad(entityRot.z)
                    
                    local cosPitch, sinPitch = math.cos(pitch), math.sin(pitch)
                    local cosRoll, sinRoll = math.cos(roll), math.sin(roll)
                    local cosYaw, sinYaw = math.cos(yaw), math.sin(yaw)
                    
                    local function rotateVector(x, y, z)
                        local x1 = x * cosYaw - y * sinYaw
                        local y1 = x * sinYaw + y * cosYaw
                        local z1 = z
                        local x2, y2 = x1, y1 * cosPitch - z1 * sinPitch
                        local z2 = y1 * sinPitch + z1 * cosPitch
                        return x2 * cosRoll + z2 * sinRoll, y2, -x2 * sinRoll + z2 * cosRoll
                    end
                    
                    local xDirX, xDirY, xDirZ = rotateVector(1, 0, 0)
                    local yDirX, yDirY, yDirZ = rotateVector(0, 1, 0)
                    local zDirX, zDirY, zDirZ = rotateVector(0, 0, 1)
                    
                    local arrowLength = gizmoState.arrowLength
                    local alpha = 200
                    
                    -- Draw arrows
                    drawGizmoArrow(xArrowOrigin.x, xArrowOrigin.y, xArrowOrigin.z, xDirX, xDirY, xDirZ, arrowLength, 255, 50, 50, alpha, 
                        gizmoState.hoveredAxis == "x" or gizmoState.dragAxis == "x")
                    drawGizmoArrow(yArrowOrigin.x, yArrowOrigin.y, yArrowOrigin.z, yDirX, yDirY, yDirZ, arrowLength, 50, 255, 50, alpha,
                        gizmoState.hoveredAxis == "y" or gizmoState.dragAxis == "y")
                    drawGizmoArrow(zArrowOrigin.x, zArrowOrigin.y, zArrowOrigin.z, zDirX, zDirY, zDirZ, arrowLength, 50, 100, 255, alpha,
                        gizmoState.hoveredAxis == "z" or gizmoState.dragAxis == "z")
                end
            end
            Script.Yield(0)
        end
        gizmoState.jobRunning = false
    end)
end


-- Stop the gizmo rendering job loop
stopGizmoRenderLoop = function()
    gizmoState.jobRunning = false
    gizmoState.enabled = false
end


local function renderAttachmentsWindow()

    if not attachmentsWindowVisible then return end
    if not spawnerSettings or not spawnerSettings.enableSpooner then return end
    
    if selectedEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
        attachmentsWindowVisible = false
        return
    end
    
    if selectedEntityAttachments.attachmentCount == 0 then
        attachmentsWindowVisible = false
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    -- Wider and taller window with two-column layout
    local windowWidth = 750
    local windowHeight = 650
    local posX = 240
    local posY = 10
    
    ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    
    local windowFlags = ImGuiWindowFlags.NoResize + 
                        ImGuiWindowFlags.NoMove + 
                        ImGuiWindowFlags.NoCollapse +
                        ImGuiWindowFlags.NoTitleBar
    
    -- Style the window (Matching Vehicle Customizations Window)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.15, 0.12, 0.2, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0.25, 0.2, 0.35, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0.3, 0.25, 0.4, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, 0.25, 0.15, 0.4, 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.35, 0.25, 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.4, 0.3, 0.55, 1.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4.0)
    
    if ImGui.Begin("##AttachmentsWindow", true, windowFlags) then
        -- Header
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.SetWindowFontScale(1.3)
        ImGui.Text("Attachments")
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()
        
        -- Close button
        ImGui.SameLine(windowWidth - 40)
        ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
        if ImGui.Button("X##closeAttachments", 25, 25) then
            attachmentsWindowVisible = false
        end
        ImGui.PopStyleColor(3)
        
        ImGui.Separator()
        ImGui.Spacing()
        
        -- Two column layout using BeginChild
        local leftPanelWidth = 200
        local rightPanelWidth = windowWidth - leftPanelWidth - 35
        
        -- Slider limits (adjustable)
        if not attachmentsWindowState.positionMax then attachmentsWindowState.positionMax = 10.0 end
        if not attachmentsWindowState.rotationMax then attachmentsWindowState.rotationMax = 180.0 end
        local panelHeight = windowHeight - 80
        
        -- Left panel: Categorized attachment list
        ImGui.BeginChild("AttachmentsListPanel", leftPanelWidth, panelHeight, true)
        
        -- Organize attachments by type
        local attVehicles = {}
        local attPeds = {}
        local attObjects = {}
        
        for i, attachment in ipairs(selectedEntityAttachments.list) do
            if ENTITY.DOES_ENTITY_EXIST(attachment.handle) then
                if attachment.type == "vehicle" then
                    table.insert(attVehicles, attachment)
                elseif attachment.type == "ped" then
                    table.insert(attPeds, attachment)
                elseif attachment.type == "object" then
                    table.insert(attObjects, attachment)
                end
            end
        end
        
        -- Helper function to render category
        local function renderAttachmentCategory(title, attachments, typeStr)
            if #attachments > 0 then
                if ImGui.TreeNode(title .. " (" .. #attachments .. ")") then
                    for i, attachment in ipairs(attachments) do
                        local name = getModelName(attachment.handle)
                        local isSelected = (attachmentsWindowState.selectedAttachment == attachment.handle)
                        
                        if isSelected then
                            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0)
                        else
                            ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                        end
                        
                        ImGui.Text(name)
                        ImGui.PopStyleColor()
                        
                        if ImGui.IsItemClicked() then
                            attachmentsWindowState.selectedAttachment = attachment.handle
                            attachmentsWindowState.selectedAttachmentType = attachment.type
                            -- Load cached offsets if available, otherwise reset to zeros
                            local cached = attachmentOffsetCache[attachment.handle]
                            if cached then
                                attachmentsWindowState.boneIndex = cached.bone or 0
                                attachmentsWindowState.offsetX = cached.offsetX or 0.0
                                attachmentsWindowState.offsetY = cached.offsetY or 0.0
                                attachmentsWindowState.offsetZ = cached.offsetZ or 0.0
                                attachmentsWindowState.rotPitch = cached.rotPitch or 0.0
                                attachmentsWindowState.rotRoll = cached.rotRoll or 0.0
                                attachmentsWindowState.rotYaw = cached.rotYaw or 0.0
                            else
                                attachmentsWindowState.boneIndex = 0
                                attachmentsWindowState.offsetX = 0.0
                                attachmentsWindowState.offsetY = 0.0
                                attachmentsWindowState.offsetZ = 0.0
                                attachmentsWindowState.rotPitch = 0.0
                                attachmentsWindowState.rotRoll = 0.0
                                attachmentsWindowState.rotYaw = 0.0
                            end
                        end
                    end
                    ImGui.TreePop()
                end
            end
        end
        
        renderAttachmentCategory("Vehicles", attVehicles, "vehicle")
        renderAttachmentCategory("Peds", attPeds, "ped")
        renderAttachmentCategory("Objects", attObjects, "object")
        
        if #attVehicles == 0 and #attPeds == 0 and #attObjects == 0 then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
            ImGui.Text("No attachments")
            ImGui.PopStyleColor()
        end
        
        ImGui.EndChild()
        
        -- Right panel: Controls
        ImGui.SameLine()
        ImGui.BeginChild("AttachmentsControlsPanel", rightPanelWidth, panelHeight, true)
        
        if attachmentsWindowState.selectedAttachment and ENTITY.DOES_ENTITY_EXIST(attachmentsWindowState.selectedAttachment) then
            -- Selected attachment name
            local selectedName = getModelName(attachmentsWindowState.selectedAttachment)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
            ImGui.Text(selectedName)
            ImGui.PopStyleColor()
            
            ImGui.Separator()
            ImGui.Spacing()
            
            -- Bone selection dropdown (smaller)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("Bone:")
            ImGui.PopStyleColor()
            ImGui.SameLine() -- Let ImGui handle spacing (was 50)
            ImGui.PushItemWidth(200) -- Increased width slightly
            
            -- Find current bone name
            local currentBoneName = "Root (Default)"
            for _, bone in ipairs(boneList) do
                if bone.boneEnum == attachmentsWindowState.boneIndex then
                    currentBoneName = bone.name
                    break
                end
            end
            
            if ImGui.BeginCombo("##BoneCombo", currentBoneName) then
                for _, bone in ipairs(boneList) do
                    local isSelected = (bone.boneEnum == attachmentsWindowState.boneIndex)
                    if ImGui.Selectable(bone.name .. "##bone" .. bone.boneEnum, isSelected) then
                        attachmentsWindowState.boneIndex = bone.boneEnum
                        -- Auto-apply when bone changes
                        local attachHandle = attachmentsWindowState.selectedAttachment
                        local targetHandle = selectedEntity
                        local boneEnum = bone.boneEnum
                        local offX = attachmentsWindowState.offsetX
                        local offY = attachmentsWindowState.offsetY
                        local offZ = attachmentsWindowState.offsetZ
                        local rotX = attachmentsWindowState.rotPitch
                        local rotY = attachmentsWindowState.rotRoll
                        local rotZ = attachmentsWindowState.rotYaw
                        
                        -- Cache the offset values
                        attachmentOffsetCache[attachHandle] = {
                            bone = boneEnum,
                            offsetX = offX,
                            offsetY = offY,
                            offsetZ = offZ,
                            rotPitch = rotX,
                            rotRoll = rotY,
                            rotYaw = rotZ
                        }
                        
                        Script.QueueJob(function()
                            pcall(function()
                                if ENTITY.DOES_ENTITY_EXIST(attachHandle) and ENTITY.DOES_ENTITY_EXIST(targetHandle) then
                                    -- Get actual bone index using native function
                                    local actualBoneIndex = getBoneIndex(targetHandle, boneEnum)
                                    ENTITY.DETACH_ENTITY(attachHandle, true, true)
                                    local isPed = ENTITY.IS_ENTITY_A_PED(targetHandle) or ENTITY.IS_ENTITY_A_PED(attachHandle)
                                    ENTITY.ATTACH_ENTITY_TO_ENTITY(attachHandle, targetHandle, actualBoneIndex, offX, offY, offZ, rotX, rotY, rotZ, false, false, false, isPed, 0, true)
                                end
                            end)
                        end)
                    end
                end
            ImGui.EndCombo()
            end
            ImGui.PopItemWidth()
            
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.15, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.2, 0.5, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.1, 0.35, 1.0)
            if ImGui.Button("Select This Entity") then
                 if attachmentsWindowState.selectedAttachment and ENTITY.DOES_ENTITY_EXIST(attachmentsWindowState.selectedAttachment) then
                     selectedEntity = attachmentsWindowState.selectedAttachment
                     selectedEntityType = attachmentsWindowState.selectedAttachmentType or "object"
                     checkEntityAttachments(selectedEntity)
                     updateToggleStatesForEntity(selectedEntity)
                     GUI.AddToast("Spooner", "Selected Attached Entity", 2000, 0)
                 end
            end
            ImGui.PopStyleColor(3)
            
            ImGui.Spacing()
            ImGui.Separator()

            
            -- Position step size control
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("Pos Step:")
            ImGui.PopStyleColor()
            ImGui.SameLine() -- Let ImGui handle spacing
            ImGui.PushItemWidth(80)
            if not attachmentsWindowState.positionStep then attachmentsWindowState.positionStep = 0.10 end
            attachmentsWindowState.positionStep = ImGui.InputFloat("##PositionStep", attachmentsWindowState.positionStep, 0, 0, "%.2f")
            if attachmentsWindowState.positionStep < 0.01 then attachmentsWindowState.positionStep = 0.01 end
            ImGui.PopItemWidth()
            
            -- Rotation step size control
            ImGui.SameLine()
            ImGui.Dummy(40, 1) -- Add spacing manually
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("Rot Step:")
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.PushItemWidth(80)
            if not attachmentsWindowState.rotationStep then attachmentsWindowState.rotationStep = 0.10 end
            attachmentsWindowState.rotationStep = ImGui.InputFloat("##RotationStep", attachmentsWindowState.rotationStep, 0, 0, "%.2f")
            if attachmentsWindowState.rotationStep < 0.01 then attachmentsWindowState.rotationStep = 0.01 end
            ImGui.PopItemWidth()
            
            ImGui.Spacing()
            ImGui.Separator()
            
            -- Track if any slider value changed for auto-apply
            local valueChanged = false
            
            -- Position sliders
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("Position")
            ImGui.PopStyleColor()
            ImGui.SameLine(rightPanelWidth - 150)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.7, 1.0)
            ImGui.Text("Max:")
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.PushItemWidth(60)
            attachmentsWindowState.positionMax = ImGui.InputFloat("##PosMax", attachmentsWindowState.positionMax, 0, 0, "%.1f")
            if attachmentsWindowState.positionMax < 1.0 then attachmentsWindowState.positionMax = 1.0 end
            ImGui.PopItemWidth()
            
            local sliderWidth = rightPanelWidth - 180
            local inputWidth = 70
            local buttonWidth = 25
            
            -- X offset
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.4, 0.4, 1.0)
            ImGui.Text("X")
            ImGui.PopStyleColor()
            ImGui.SameLine(25)
            
            -- Slider
            ImGui.PushItemWidth(sliderWidth)
            local newX = ImGui.SliderFloat("##OffsetX", attachmentsWindowState.offsetX, -attachmentsWindowState.positionMax, attachmentsWindowState.positionMax, "%.2f")
            if newX ~= attachmentsWindowState.offsetX then
                attachmentsWindowState.offsetX = newX
                valueChanged = true
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            
            -- Minus button
            if ImGui.Button("-##XMinus", buttonWidth, 0) then
                attachmentsWindowState.offsetX = attachmentsWindowState.offsetX - attachmentsWindowState.positionStep
                valueChanged = true
            end
            ImGui.SameLine()
            
            -- Plus button
            if ImGui.Button("+##XPlus", buttonWidth, 0) then
                attachmentsWindowState.offsetX = attachmentsWindowState.offsetX + attachmentsWindowState.positionStep
                valueChanged = true
            end
            
            -- Y offset
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 1.0, 0.4, 1.0)
            ImGui.Text("Y")
            ImGui.PopStyleColor()
            ImGui.SameLine(25)
            
            -- Slider
            ImGui.PushItemWidth(sliderWidth)
            local newY = ImGui.SliderFloat("##OffsetY", attachmentsWindowState.offsetY, -attachmentsWindowState.positionMax, attachmentsWindowState.positionMax, "%.2f")
            if newY ~= attachmentsWindowState.offsetY then
                attachmentsWindowState.offsetY = newY
                valueChanged = true
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            
            -- Minus button
            if ImGui.Button("-##YMinus", buttonWidth, 0) then
                attachmentsWindowState.offsetY = attachmentsWindowState.offsetY - attachmentsWindowState.positionStep
                valueChanged = true
            end
            ImGui.SameLine()
            
            -- Plus button
            if ImGui.Button("+##YPlus", buttonWidth, 0) then
                attachmentsWindowState.offsetY = attachmentsWindowState.offsetY + attachmentsWindowState.positionStep
                valueChanged = true
            end
            
            -- Z offset
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.6, 1.0, 1.0)
            ImGui.Text("Z")
            ImGui.PopStyleColor()
            ImGui.SameLine(25)
            
            -- Slider
            ImGui.PushItemWidth(sliderWidth)
            local newZ = ImGui.SliderFloat("##OffsetZ", attachmentsWindowState.offsetZ, -attachmentsWindowState.positionMax, attachmentsWindowState.positionMax, "%.2f")
            if newZ ~= attachmentsWindowState.offsetZ then
                attachmentsWindowState.offsetZ = newZ
                valueChanged = true
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            
            -- Minus button
            if ImGui.Button("-##ZMinus", buttonWidth, 0) then
                attachmentsWindowState.offsetZ = attachmentsWindowState.offsetZ - attachmentsWindowState.positionStep
                valueChanged = true
            end
            ImGui.SameLine()
            
            -- Plus button
            if ImGui.Button("+##ZPlus", buttonWidth, 0) then
                attachmentsWindowState.offsetZ = attachmentsWindowState.offsetZ + attachmentsWindowState.positionStep
                valueChanged = true
            end
            
            ImGui.Separator()
            
            -- Rotation sliders
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("Rotation")
            ImGui.PopStyleColor()
            
            -- Pitch
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.6, 0.4, 1.0)
            ImGui.Text("P")
            ImGui.PopStyleColor()
            ImGui.SameLine(25)
            
            -- Slider
            ImGui.PushItemWidth(sliderWidth)
            local newPitch = ImGui.SliderFloat("##RotPitch", attachmentsWindowState.rotPitch, -attachmentsWindowState.rotationMax, attachmentsWindowState.rotationMax, "%.1f")
            if newPitch ~= attachmentsWindowState.rotPitch then
                attachmentsWindowState.rotPitch = newPitch
                valueChanged = true
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            
            -- Minus button
            if ImGui.Button("-##PitchMinus", buttonWidth, 0) then
                attachmentsWindowState.rotPitch = attachmentsWindowState.rotPitch - attachmentsWindowState.rotationStep
                valueChanged = true
            end
            ImGui.SameLine()
            
            -- Plus button
            if ImGui.Button("+##PitchPlus", buttonWidth, 0) then
                attachmentsWindowState.rotPitch = attachmentsWindowState.rotPitch + attachmentsWindowState.rotationStep
                valueChanged = true
            end
            
            -- Roll
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 1.0, 0.4, 1.0)
            ImGui.Text("R")
            ImGui.PopStyleColor()
            ImGui.SameLine(25)
            
            -- Slider
            ImGui.PushItemWidth(sliderWidth)
            local newRoll = ImGui.SliderFloat("##RotRoll", attachmentsWindowState.rotRoll, -attachmentsWindowState.rotationMax, attachmentsWindowState.rotationMax, "%.1f")
            if newRoll ~= attachmentsWindowState.rotRoll then
                attachmentsWindowState.rotRoll = newRoll
                valueChanged = true
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            
            -- Minus button
            if ImGui.Button("-##RollMinus", buttonWidth, 0) then
                attachmentsWindowState.rotRoll = attachmentsWindowState.rotRoll - attachmentsWindowState.rotationStep
                valueChanged = true
            end
            ImGui.SameLine()
            
            -- Plus button
            if ImGui.Button("+##RollPlus", buttonWidth, 0) then
                attachmentsWindowState.rotRoll = attachmentsWindowState.rotRoll + attachmentsWindowState.rotationStep
                valueChanged = true
            end
            
            -- Yaw
            ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0)
            ImGui.Text("Y")
            ImGui.PopStyleColor()
            ImGui.SameLine(25)
            
            -- Slider
            ImGui.PushItemWidth(sliderWidth)
            local newYaw = ImGui.SliderFloat("##RotYaw", attachmentsWindowState.rotYaw, -attachmentsWindowState.rotationMax, attachmentsWindowState.rotationMax, "%.1f")
            if newYaw ~= attachmentsWindowState.rotYaw then
                attachmentsWindowState.rotYaw = newYaw
                valueChanged = true
            end
            ImGui.PopItemWidth()
            ImGui.SameLine()
            
            -- Minus button
            if ImGui.Button("-##YawMinus", buttonWidth, 0) then
                attachmentsWindowState.rotYaw = attachmentsWindowState.rotYaw - attachmentsWindowState.rotationStep
                valueChanged = true
            end
            ImGui.SameLine()
            
            -- Plus button
            if ImGui.Button("+##YawPlus", buttonWidth, 0) then
                attachmentsWindowState.rotYaw = attachmentsWindowState.rotYaw + attachmentsWindowState.rotationStep
                valueChanged = true
            end
            
            -- Auto-apply if any value changed
            if valueChanged then
                local attachHandle = attachmentsWindowState.selectedAttachment
                local targetHandle = selectedEntity
                local boneEnum = attachmentsWindowState.boneIndex
                local offX = attachmentsWindowState.offsetX
                local offY = attachmentsWindowState.offsetY
                local offZ = attachmentsWindowState.offsetZ
                local rotX = attachmentsWindowState.rotPitch
                local rotY = attachmentsWindowState.rotRoll
                local rotZ = attachmentsWindowState.rotYaw
                
                -- Cache the offset values
                attachmentOffsetCache[attachHandle] = {
                    bone = boneEnum,
                    offsetX = offX,
                    offsetY = offY,
                    offsetZ = offZ,
                    rotPitch = rotX,
                    rotRoll = rotY,
                    rotYaw = rotZ
                }
                
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(attachHandle) and ENTITY.DOES_ENTITY_EXIST(targetHandle) then
                            -- Get actual bone index using native function
                            local actualBoneIndex = getBoneIndex(targetHandle, boneEnum)
                            ENTITY.DETACH_ENTITY(attachHandle, true, true)
                            local isPed = ENTITY.IS_ENTITY_A_PED(targetHandle) or ENTITY.IS_ENTITY_A_PED(attachHandle)
                            ENTITY.ATTACH_ENTITY_TO_ENTITY(attachHandle, targetHandle, actualBoneIndex, offX, offY, offZ, rotX, rotY, rotZ, false, false, false, isPed, 0, true)
                        end
                    end)
                end)
            end
            
            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()
            
            -- Detach button (Full width)
            local buttonWidth = rightPanelWidth - 20
            
            ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.2, 0.1, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.25, 0.15, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.15, 0.08, 1.0)
            if ImGui.Button("Detach", buttonWidth, 0) then
                local attachHandle = attachmentsWindowState.selectedAttachment
                
                -- Clear the cache for this attachment
                attachmentOffsetCache[attachHandle] = nil
                
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(attachHandle) then
                            ENTITY.DETACH_ENTITY(attachHandle, true, true)
                            GUI.AddToast("Spooner", "Entity Detached!", 2000, 0)
                            -- Refresh attachment list
                            checkEntityAttachments(selectedEntity)
                        end
                    end)
                end)
                
                attachmentsWindowState.selectedAttachment = nil
                attachmentsWindowState.selectedAttachmentType = nil
            end
            ImGui.PopStyleColor(3)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
            ImGui.Text("Select an attachment")
            ImGui.Text("from the list to edit")
            ImGui.PopStyleColor()
        end
        
        ImGui.EndChild()
    end
    ImGui.End()
    
    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(8)
end

-- ============================================================================
-- Save Window
-- ============================================================================

local saveWindowVisible = false
local saveWindowState = {
    targetEntity = 0,
    targetType = nil, -- "vehicle" or "ped"
    saveName = ""
}

function M.openSaveWindow()
    if selectedEntity ~= 0 and (selectedEntityType == "vehicle" or selectedEntityType == "ped") then
        saveWindowVisible = true
        saveWindowState.targetEntity = selectedEntity
        saveWindowState.targetType = selectedEntityType
        saveWindowState.saveName = ""
    end
end

local function performSave()
    if saveWindowState.saveName == "" then
        GUI.AddToast("Spooner", "Enter a name first", 2000, 0)
        return
    end
    
    local entToSave = saveWindowState.targetEntity
    local entType = saveWindowState.targetType
    local saveName = saveWindowState.saveName
    
    Script.QueueJob(function()
        pcall(function()
            if entType == "vehicle" then
                -- For vehicles: always warp player into driver's seat first, then save
                local playerPed = PLAYER.PLAYER_PED_ID()
                
                -- Unfreeze the vehicle before sitting in it
                if ENTITY.DOES_ENTITY_EXIST(entToSave) then
                    ENTITY.FREEZE_ENTITY_POSITION(entToSave, false)
                end
                
                -- Always warp player into the driver's seat (-1) of the selected vehicle
                PED.SET_PED_INTO_VEHICLE(playerPed, entToSave, -1)
                Script.Yield(500)
                
                -- Set the name and save with 1 second delay
                local vehicleNameFeature = FeatureMgr.GetFeatureByName("Vehicle Name")
                local saveVehicleFeature = FeatureMgr.GetFeatureByName("Save Current Vehicle")
                
                if vehicleNameFeature and saveVehicleFeature then
                    vehicleNameFeature:SetStringValue(saveName)
                    Script.Yield(1000) -- 1 second delay
                    saveVehicleFeature:TriggerCallback()
                    GUI.AddToast("Spooner", "Saved vehicle: " .. saveName, 2000, 0)
                else
                    GUI.AddToast("Spooner", "Save feature not found", 3000, 0)
                end
                
            elseif entType == "ped" then
                -- For peds/outfits: switch to the ped if it's not our ped
                local playerPed = PLAYER.PLAYER_PED_ID()
                
                if entToSave ~= playerPed then
                    -- Switch to the ped using CHANGE_PLAYER_PED
                    PLAYER.CHANGE_PLAYER_PED(PLAYER.PLAYER_ID(), entToSave, true, true)
                    Script.Yield(500)
                end
                
                -- Set the name and save with 1 second delay
                local outfitNameFeature = FeatureMgr.GetFeatureByName("Outfit Name")
                
                if outfitNameFeature then
                    outfitNameFeature:SetStringValue(saveName)
                    Script.Yield(1000) -- 1 second delay
                    FeatureMgr.TriggerFeatureCallback(231503983)
                    GUI.AddToast("Spooner", "Saved outfit: " .. saveName, 2000, 0)
                else
                    GUI.AddToast("Spooner", "Outfit Name feature not found", 3000, 0)
                end
            end
        end)
    end)
    
    saveWindowVisible = false
end

local function renderSaveWindow()
    if not saveWindowVisible then return end
    if not spawnerSettings or not spawnerSettings.enableSpooner then return end
    
    -- Close if entity no longer exists
    if saveWindowState.targetEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(saveWindowState.targetEntity) then
        saveWindowVisible = false
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    -- Window size and position (to the right of entity options)
    local windowWidth = 260
    local windowHeight = 200
    local posX = 240
    local posY = 10
    
    ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    
    local windowFlags = ImGuiWindowFlags.NoResize + 
                        ImGuiWindowFlags.NoMove + 
                        ImGuiWindowFlags.NoCollapse +
                        ImGuiWindowFlags.NoTitleBar +
                        ImGuiWindowFlags.NoScrollbar +
                        ImGuiWindowFlags.NoScrollWithMouse
    
    -- Style the window (purple border like other windows)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.95)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8) -- Purple border to match other windows
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
    
    if ImGui.Begin("##SaveWindow", true, windowFlags) then
        -- Header
        local headerText = saveWindowState.targetType == "vehicle" and "Save Vehicle" or "Save Outfit"
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0) -- Purple text to match
        ImGui.SetWindowFontScale(1.1)
        ImGui.Text(headerText)
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()
        
        -- Close button (white X)
        ImGui.SameLine(windowWidth - 30)
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
        ImGui.Text("X")
        ImGui.PopStyleColor()
        if ImGui.IsItemClicked() then
            saveWindowVisible = false
        end
        
        ImGui.Separator()
        ImGui.Spacing()
        
        -- Name label
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
        local labelText = saveWindowState.targetType == "vehicle" and "Name:" or "Name:"
        ImGui.Text(labelText)
        ImGui.PopStyleColor()
        
        -- Name input
        ImGui.PushItemWidth(windowWidth - 30)
        saveWindowState.saveName = ImGui.InputText("##SaveNameInput", saveWindowState.saveName or "", 64)
        ImGui.PopItemWidth()
        
        -- Check for Enter key
        if ImGui.IsKeyPressed(13) then -- 13 = Enter key
            performSave()
        end
        
        ImGui.Spacing()
        
        -- Save button (yellow, same style as entity options button)
        ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.4, 0.1, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.5, 0.15, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.35, 0.08, 1.0)
        
        if ImGui.Button("Save", -1, 0) then
            performSave()
        end
        ImGui.PopStyleColor(3)
    end
    ImGui.End()
    
    ImGui.PopStyleVar(3)
    ImGui.PopStyleColor(2)
end


local function renderControlsWindow()
    if not spawnerSettings or not spawnerSettings.enableSpooner then
        return
    end
    
    if spawnerSettings.showSpoonerControls == false then
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    -- Window size
    local windowWidth = 450
    local windowHeight = 120
    
    -- Position in bottom right corner with some padding
    local padding = 20
    local posX = screenWidth - windowWidth - padding
    local posY = screenHeight - windowHeight - padding
    
    -- Set window position and size
    ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    
    -- Window flags for a clean info panel
    local windowFlags = ImGuiWindowFlags.NoResize + 
                        ImGuiWindowFlags.NoMove + 
                        ImGuiWindowFlags.NoCollapse +
                        ImGuiWindowFlags.NoScrollbar +
                        ImGuiWindowFlags.NoTitleBar +
                        ImGuiWindowFlags.NoScrollWithMouse
    
    -- Style the window with semi-transparent background
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
    
    if ImGui.Begin("##SpoonerControls", true, windowFlags) then
        -- Header
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.SetWindowFontScale(1.2)
        ImGui.Text("Spooner Controls")
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()
        
        ImGui.Separator()
        ImGui.Spacing()
        
        -- Keyboard controls
        if ImGui.BeginTable("ControlsTable", 2, 0) then
            -- Row 1, Col 1
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("M1")
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.7, 1.0)
            ImGui.Text("Select Entity")
            ImGui.PopStyleColor()
            
            -- Row 1, Col 2
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("END")
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.7, 1.0)
            ImGui.Text("Switch Modes")
            ImGui.PopStyleColor()
            
            -- Row 2, Col 1
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("B")
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.7, 1.0)
            ImGui.Text("Browser")
            ImGui.PopStyleColor()
            
            -- Row 2, Col 2
            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
            ImGui.Text("X")
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.7, 1.0)
            ImGui.Text("Close Spooner")
            ImGui.PopStyleColor()
            
            ImGui.EndTable()
        end
    end
    ImGui.End()
    
    ImGui.PopStyleVar(3)
    ImGui.PopStyleColor(2)
end



-- Render the entity options window (top-left when entity is selected)
local function renderEntityOptionsWindow()
    if not spawnerSettings or not spawnerSettings.enableSpooner then
        return
    end
    
    if selectedEntity == 0 or not selectedEntityType then
        return
    end
    
    -- Verify entity still exists
    if not ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
        selectedEntity = 0
        selectedEntityType = nil
        return
    end
    
    -- Check if it is the player ped
    local isPlayerPed = false
    pcall(function()
        if selectedEntity == PLAYER.PLAYER_PED_ID() then
            isPlayerPed = true
        end
    end)
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    -- Window size and position (very top-left)
    local windowWidth = 220
    local windowHeight = 420
    local posX = 10
    local posY = 10
    
    ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    
    -- Window flags
    local windowFlags = ImGuiWindowFlags.NoResize + 
                        ImGuiWindowFlags.NoMove + 
                        ImGuiWindowFlags.NoCollapse +
                        ImGuiWindowFlags.NoScrollbar +
                        ImGuiWindowFlags.NoTitleBar
    
    -- Style the window
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10.0, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 4.0, 2.0)
    
    if ImGui.Begin("##EntityOptions", true, windowFlags) then
        -- Header - show "Self" for player ped, otherwise model name
        local displayName
        if isPlayerPed then
            displayName = "Self"
        else
            displayName = getModelName(selectedEntity)
        end
        
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.Text(displayName)
        ImGui.PopStyleColor()
        
        ImGui.Separator()
        
        -- Attachments button (light blue) - only show if entity has attachments
        if selectedEntityAttachments.attachmentCount > 0 then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.5, 0.7, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.6, 0.8, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.15, 0.45, 0.65, 1.0)
            local attachmentsLabel = "Attachments (" .. selectedEntityAttachments.attachmentCount .. ")"
            if ImGui.Button(attachmentsLabel, windowWidth - 25, 0) then
                saveWindowVisible = false
                M.openAttachmentsWindow()
            end
            ImGui.PopStyleColor(3)
        end
        
        -- Attach button (green)
        ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.4, 0.2, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.5, 0.25, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.35, 0.15, 1.0)
        if ImGui.Button("Attach", windowWidth - 25, 0) then
            saveWindowVisible = false
            M.openAttachWindow()
        end
        ImGui.PopStyleColor(3)
        
        -- Customizations button (dark blue)
        local customLabel = "Customizations"
        if selectedEntityType == "vehicle" then
            customLabel = "Vehicle Customizations"
        elseif selectedEntityType == "ped" then
            customLabel = "Ped Customizations"
        end
        
        ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.15, 0.35, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.2, 0.45, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.12, 0.3, 1.0)
        if ImGui.Button(customLabel, windowWidth - 25, 0) then
            if selectedEntityType == "vehicle" then
                if vehicleCustomsVisible and vehicleCustomsState.targetEntity == selectedEntity then
                    vehicleCustomsVisible = false
                else
                    saveWindowVisible = false
                    pedCustomsVisible = false
                    vehicleCustomsState.targetEntity = selectedEntity
                    M.openVehicleCustomizations()
                end
            elseif selectedEntityType == "ped" then
                if pedCustomsVisible and pedCustomsState.targetEntity == selectedEntity then
                    pedCustomsVisible = false
                else
                    saveWindowVisible = false
                    vehicleCustomsVisible = false
                    pedCustomsState.targetEntity = selectedEntity
                    M.openPedCustomizations()
                end
            end
        end
        ImGui.PopStyleColor(3)

        
        -- Save button (only for vehicles and peds, not objects) - yellow/orange
        if selectedEntityType == "vehicle" or selectedEntityType == "ped" then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.4, 0.1, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.5, 0.15, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.35, 0.08, 1.0)
            
            local saveLabel = selectedEntityType == "vehicle" and "Save Vehicle" or "Save Outfit"
            if ImGui.Button(saveLabel, windowWidth - 25, 0) then
                -- Toggle behavior: close if already open for same entity, else open
                if saveWindowVisible and saveWindowState.targetEntity == selectedEntity then
                    saveWindowVisible = false
                else
                    -- Close other windows (mutual exclusivity)
                    vehicleCustomsVisible = false
                    pedCustomsVisible = false
                    attachWindowVisible = false
                    attachmentsWindowVisible = false
                    -- Open save window

                    M.openSaveWindow()
                end
            end
            ImGui.PopStyleColor(3)
        end
        
        ImGui.Separator()
        
        if not isPlayerPed then
            -- Database toggle - saves entity to database table
            -- Use Selectable for full-row clickable area
            if toggleStates.database then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
            end
            local indicatorDb = "o"
            ImGui.PopStyleColor()
            
            if ImGui.Selectable("Database", false, 0, windowWidth - 20, 0) then
                toggleStates.database = not toggleStates.database
                if toggleStates.database then
                    -- Add to database
                    local model = ENTITY.GET_ENTITY_MODEL(selectedEntity)
                    entityDatabase[selectedEntity] = {
                        handle = selectedEntity,
                        type = selectedEntityType,
                        model = model
                    }
                else
                    -- Remove from database
                    entityDatabase[selectedEntity] = nil
                end
            end
            ImGui.SameLine(windowWidth - 25)
            if toggleStates.database then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
            end
            ImGui.Text("o")
            ImGui.PopStyleColor()
        end
        
        -- Copy (clone the entity at the same position) - full row clickable
        if ImGui.Selectable("Copy", false, 0, windowWidth - 20, 0) then
            -- Capture values before queuing job
            local entToCopy = selectedEntity
            local entType = selectedEntityType
            Script.QueueJob(function()
                pcall(function()
                    if ENTITY.DOES_ENTITY_EXIST(entToCopy) then
                        local model = ENTITY.GET_ENTITY_MODEL(entToCopy)
                        local coords = ENTITY.GET_ENTITY_COORDS(entToCopy, true)
                        local heading = ENTITY.GET_ENTITY_HEADING(entToCopy)
                        
                        -- Request model
                        STREAMING.REQUEST_MODEL(model)
                        local timeout = 0
                        while not STREAMING.HAS_MODEL_LOADED(model) and timeout < 100 do
                            Script.Yield(10)
                            timeout = timeout + 1
                        end
                        
                        if STREAMING.HAS_MODEL_LOADED(model) then
                            local newEntity = 0
                            if entType == "vehicle" then
                                newEntity = GTA.SpawnVehicle(model, coords.x + 2, coords.y, coords.z, heading, true, true)
                            elseif entType == "ped" then
                                newEntity = GTA.CreatePed(model, 26, coords.x + 2, coords.y, coords.z, heading, true, true)
                            else
                                newEntity = GTA.CreateObject(model, coords.x + 2, coords.y, coords.z, true, true)
                                if newEntity and newEntity ~= 0 then
                                    ENTITY.SET_ENTITY_HEADING(newEntity, heading)
                                end
                            end
                            STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(model)
                        end
                    end
                end)
            end)
        end
        
        if not isPlayerPed then
            -- Delete (remove the entity) - full row clickable
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.4, 0.4, 1.0)
            if ImGui.Selectable("Delete", false, 0, windowWidth - 20, 0) then
                -- Capture values before queuing job
                local entToDelete = selectedEntity
                -- Clear selection immediately
                selectedEntity = 0
                selectedEntityType = nil
                entityDatabase[entToDelete] = nil
                
                Script.QueueJob(function()
                    pcall(function()
                        if ENTITY.DOES_ENTITY_EXIST(entToDelete) then
                            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entToDelete, true, true)
                            local ptr = Memory.AllocInt()
                            Memory.WriteInt(ptr, entToDelete)
                            ENTITY.DELETE_ENTITY(ptr)
                        end
                    end)
                end)
            end
            ImGui.PopStyleColor()
        end
        
        -- Clickable toggle: Dynamic (full row clickable)
        if ImGui.Selectable("Dynamic", false, 0, windowWidth - 20, 0) then
            toggleStates.dynamic = not toggleStates.dynamic
            -- Cache the property
            if not entityPropertyCache[selectedEntity] then entityPropertyCache[selectedEntity] = {} end
            entityPropertyCache[selectedEntity].dynamic = toggleStates.dynamic
            pcall(function()
                ENTITY.SET_ENTITY_DYNAMIC(selectedEntity, toggleStates.dynamic)
            end)
        end
        ImGui.SameLine(windowWidth - 25)
        if toggleStates.dynamic then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
        end
        ImGui.Text("o")
        ImGui.PopStyleColor()
        
        -- Clickable toggle: Frozen In Place (full row clickable)
        if ImGui.Selectable("Frozen In Place", false, 0, windowWidth - 20, 0) then
            toggleStates.frozen = not toggleStates.frozen
            -- Track if user manually enabled freeze
            if toggleStates.frozen then
                userEnabledFreeze = true
            else
                userEnabledFreeze = false
            end
            pcall(function()
                ENTITY.FREEZE_ENTITY_POSITION(selectedEntity, toggleStates.frozen)
            end)
        end
        ImGui.SameLine(windowWidth - 25)
        if toggleStates.frozen then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
        end
        ImGui.Text("o")
        ImGui.PopStyleColor()
        
        -- Clickable toggle: Invincible (full row clickable)
        if ImGui.Selectable("Invincible", false, 0, windowWidth - 20, 0) then
            toggleStates.invincible = not toggleStates.invincible
            -- Cache the property
            if not entityPropertyCache[selectedEntity] then entityPropertyCache[selectedEntity] = {} end
            entityPropertyCache[selectedEntity].invincible = toggleStates.invincible
            pcall(function()
                ENTITY.SET_ENTITY_INVINCIBLE(selectedEntity, toggleStates.invincible)
            end)
        end
        ImGui.SameLine(windowWidth - 25)
        if toggleStates.invincible then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
        end
        ImGui.Text("o")
        ImGui.PopStyleColor()
        
        -- Clickable toggle: Fireproof (full row clickable)
        if ImGui.Selectable("Fireproof", false, 0, windowWidth - 20, 0) then
            toggleStates.fireproof = not toggleStates.fireproof
            -- Cache the property
            if not entityPropertyCache[selectedEntity] then entityPropertyCache[selectedEntity] = {} end
            entityPropertyCache[selectedEntity].fireproof = toggleStates.fireproof
            pcall(function()
                -- SET_ENTITY_PROOFS(entity, bulletProof, fireProof, explosionProof, collisionProof, meleeProof, p6, p7, drownProof)
                ENTITY.SET_ENTITY_PROOFS(selectedEntity, false, toggleStates.fireproof, false, false, false, false, false, false)
            end)
        end
        ImGui.SameLine(windowWidth - 25)
        if toggleStates.fireproof then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
        end
        ImGui.Text("o")
        ImGui.PopStyleColor()
        
        -- Clickable toggle: Visible (full row clickable)
        if ImGui.Selectable("Visible", false, 0, windowWidth - 20, 0) then
            toggleStates.visible = not toggleStates.visible
            pcall(function()
                ENTITY.SET_ENTITY_VISIBLE(selectedEntity, toggleStates.visible, false)
            end)
        end
        ImGui.SameLine(windowWidth - 25)
        if toggleStates.visible then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
        end
        ImGui.Text("o")
        ImGui.PopStyleColor()
        
        -- Clickable toggle: Collision (full row clickable)
        if ImGui.Selectable("Collision", false, 0, windowWidth - 20, 0) then
            toggleStates.collision = not toggleStates.collision
            pcall(function()
                ENTITY.SET_ENTITY_COLLISION(selectedEntity, toggleStates.collision, true)
            end)
        end
        ImGui.SameLine(windowWidth - 25)
        if toggleStates.collision then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
        end
        ImGui.Text("o")
        ImGui.PopStyleColor()
        
        -- Clickable toggle: Gravity (full row clickable)
        if ImGui.Selectable("Gravity", false, 0, windowWidth - 20, 0) then
            toggleStates.gravity = not toggleStates.gravity
            -- Cache the property
            if not entityPropertyCache[selectedEntity] then entityPropertyCache[selectedEntity] = {} end
            entityPropertyCache[selectedEntity].gravity = toggleStates.gravity
            pcall(function()
                ENTITY.SET_ENTITY_HAS_GRAVITY(selectedEntity, toggleStates.gravity)
            end)
        end
        ImGui.SameLine(windowWidth - 25)
        if toggleStates.gravity then
            ImGui.PushStyleColor(ImGuiCol.Text, 0.0, 0.9, 0.4, 1.0)
        else
            ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.3, 0.3, 1.0)
        end
        ImGui.Text("o")
        ImGui.PopStyleColor()
        
        ImGui.Separator()
        
        -- Deselect
        ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.3, 0.3, 1.0)
        ImGui.Text("Deselect")
        ImGui.PopStyleColor()
        if ImGui.IsItemClicked() then
            -- Unfreeze the entity if user didn't manually enable freeze
            if not userEnabledFreeze and selectedEntity ~= 0 then
                pcall(function()
                    if ENTITY.DOES_ENTITY_EXIST(selectedEntity) then
                        ENTITY.FREEZE_ENTITY_POSITION(selectedEntity, false)
                    end
                end)
            end
            selectedEntity = 0
            selectedEntityType = nil
            userEnabledFreeze = false
        end
    end
    ImGui.End()
    
    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(2)
end

-- Called every frame when spooner is enabled (render thread)
-- Called every frame when spooner is enabled (render thread)
-- Called every frame when spooner is enabled (render thread)
function M.onPresent()
    -- Check input capture state
    pcall(function()
        -- Use IsAnyItemActive as a more reliable check for typing in input fields
        if ImGui.IsAnyItemActive then
            isKeyboardCaptured = ImGui.IsAnyItemActive()
        end
    end)

    -- Start detection loop if not running
    if not isRunning and spawnerSettings and spawnerSettings.enableSpooner then
        M.startDetectionLoop()
    end
    
    -- Keyboard shortcuts (handled in render thread for better input blocking)
    -- Only handle shortcuts if keyboard is not captured by ImGui inputs
    if spawnerSettings and spawnerSettings.enableSpooner and not isKeyboardCaptured then
        local currentTime = Time.GetEpocheMs()
        
        -- B key (0x42) - Toggle Browser
        if Utils.IsKeyDown(0x42) then
            if currentTime - lastKeyTime > 300 then
                lastKeyTime = currentTime
                browserVisible = not browserVisible
            end
        end
        
        -- X key (0x58) - Close Spooner
        if Utils.IsKeyDown(0x58) then
            if currentTime - lastKeyTime > 300 then
                lastKeyTime = currentTime
                spawnerSettings.enableSpooner = false
                M.stopDetectionLoop()
                if M.closeAllSubWindows then
                    M.closeAllSubWindows()
                else
                    -- Fallback if function not found
                    browserVisible = false
                    vehicleCustomsVisible = false
                    pedCustomsVisible = false
                    attachWindowVisible = false
                    attachmentsWindowVisible = false
                    saveWindowVisible = false
                end
            end
        end
    end
    
    renderEntityOptionsWindow()
    renderDatabaseWindow()
    renderNearbyEntitiesWindow()
    -- Vehicle and Ped customizations are now rendered via renderSubWindows() always
    renderAttachWindow()
    renderAttachmentsWindow()
    renderPositionGizmo()  -- 3D gizmo for attachments
    renderSaveWindow()
    renderControlsWindow()
end

-- Render sub-windows that can work independently (without full Spooner mode)
-- Called every frame from ON_PRESENT, regardless of Spooner mode being enabled
function M.renderSubWindows()
    -- These windows can be opened from the Spooner Tab without free camera mode
    renderVehicleCustomizationsWindow()
    renderPedCustomizationsWindow()
end


-- Toggle spooner mode on/off
function M.setEnabled(enabled)
    if spawnerSettings then
        spawnerSettings.enableSpooner = enabled
        if not enabled then
            M.stopDetectionLoop()
        end
    end
end

-- Check if spooner is enabled
function M.isEnabled()
    return spawnerSettings and spawnerSettings.enableSpooner
end

-- Get currently hovered entity
function M.getHoveredEntity()
    return hoveredEntity
end

-- Get hovered entity type
function M.getHoveredEntityType()
    return hoveredEntityType
end

-- Get currently selected entity
function M.getSelectedEntity()
    return selectedEntity
end

-- Get selected entity type
function M.getSelectedEntityType()
    return selectedEntityType
end

-- Set selected entity directly
function M.setSelectedEntity(entity, entityType)
    selectedEntity = entity or 0
    selectedEntityType = entityType
    -- Reset user freeze flag when selecting new entity
    userEnabledFreeze = false
    -- Check attachments for the new selected entity
    checkEntityAttachments(entity)
    -- Update toggle states based on actual entity properties
    updateToggleStatesForEntity(entity)
end

-- Get the entity database
function M.getEntityDatabase()
    return entityDatabase
end

-- Check if an entity is in the database
function M.isEntityInDatabase(entity)
    return entityDatabase[entity] ~= nil
end

-- ============================================================================
-- GTA Hash Browser Functions
-- ============================================================================

-- ============================================================================
-- Local Asset Browser Functions
-- ============================================================================

-- Maximum number of textures we can load (Cherax has a ~1000 slot limit)
local MAX_LOADED_TEXTURES = 999
local loadedTextureCount = 0

-- ============================================================================
-- Remote Fetching Functions (Curl-based)
-- ============================================================================

-- Async HTTP GET using Curl
local function curlGetAsync(url, callback)
    local curl = Curl.Easy()
    curl:Setopt(10002, url) -- CURLOPT_URL
    curl:Setopt(10018, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Cherax-Spooner") -- User-Agent
    curl:Perform()
    
    Script.QueueJob(function()
        local timeout = 0
        while not curl:GetFinished() and timeout < 300 do
            Script.Yield(100)
            timeout = timeout + 1
        end
        local code, response = curl:GetResponse()
        if code == 0 and response then
            callback(true, response)
        else
            M.debug_print("[Spooner] Curl error code: " .. tostring(code) .. " for URL: " .. url)
            callback(false, nil)
        end
    end)
end

-- Download image and save to category folder (matches Python scraper structure)
local function downloadImageToCache(imageUrl, modelName, category, isVehicle, callback)
    local typeFolder = isVehicle and "vehicles" or "objects"
    local safeCategory = (category or "unknown"):gsub('[<>:"/\\|?*]', '_')
    local safeName = modelName:gsub('[<>:"/\\|?*]', '_')
    
    local categoryDir = rootPath .. "\\SpoonerAssets\\gtahashru\\" .. typeFolder .. "\\" .. safeCategory
    local cachePath = categoryDir .. "\\" .. safeName .. ".jpg"
    
    -- Skip if already cached locally
    if FileMgr.DoesFileExist(cachePath) then
        callback(cachePath)
        return
    end
    
    -- Mark as pending
    gtaHashBrowser.pendingDownloads[modelName] = true
    
    -- Download via Curl
    local curl = Curl.Easy()
    curl:Setopt(10002, imageUrl)
    curl:Setopt(10018, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Cherax-Spooner")
    curl:Perform()
    
    Script.QueueJob(function()
        local timeout = 0
        while not curl:GetFinished() and timeout < 300 do
            Script.Yield(100)
            timeout = timeout + 1
        end
        local code, response = curl:GetResponse()
        gtaHashBrowser.pendingDownloads[modelName] = nil
        
        if code == 0 and response then
            -- Create category folder and save
            FileMgr.CreateDir(categoryDir)
            local f = io.open(cachePath, "wb")
            if f then
                f:write(response)
                f:close()
                M.debug_print("[Spooner] Downloaded: " .. modelName .. " -> " .. safeCategory)
                callback(cachePath)
            else
                M.debug_print("[Spooner] Failed to write file: " .. cachePath)
                callback(nil)
            end
        else
            M.debug_print("[Spooner] Failed to download: " .. imageUrl)
            callback(nil)
        end
    end)
end

-- Load remote category from gtahash.ru
local function loadRemoteCategory(category, isVehicle, page)
    gtaHashBrowser.isLoading = true
    gtaHashBrowser.loadError = nil
    
    if page == 1 then
        gtaHashBrowser.items = {}
        gtaHashBrowser.allItems = nil
        clearTextureCache()
    end
    
    local baseUrl = isVehicle and "https://gtahash.ru/car/" or "https://gtahash.ru/"
    local encodedCategory = category and category:gsub(" ", "%%20") or ""
    local url = baseUrl .. "?c=" .. encodedCategory
    if page and page > 1 then
        url = url .. "&page=" .. page
    end
    
    M.debug_print("[Spooner] Fetching remote: " .. url)
    
    curlGetAsync(url, function(success, html)
        if success and html then
            local items = parseGtaHashHtml(html, category)
            local totalPages = extractTotalPages(html)
            
            M.debug_print("[Spooner] Found " .. #items .. " items on page " .. page .. " of " .. totalPages)
            
            gtaHashBrowser.items = items
            gtaHashBrowser.allItems = items
            gtaHashBrowser.totalItems = #items
            gtaHashBrowser.itemsPerPage = gtaHashBrowser.remoteItemsPerPage
            gtaHashBrowser.totalPages = totalPages
            gtaHashBrowser.currentPage = page
            gtaHashBrowser.isLoading = false
        else
            gtaHashBrowser.loadError = "Failed to fetch from gtahash.ru"
            gtaHashBrowser.isLoading = false
        end
    end)
end

-- GitHub repository base URLs (raw URLs have no rate limits!)
local GITHUB_RAW_BASE = "https://raw.githubusercontent.com/themilkman554/SpoonerAssets/main/gtahashru"

-- Cached GitHub index (to avoid re-fetching)
local githubIndexCache = {
    objects = nil,
    vehicles = nil
}

-- Load category from GitHub repository using manifest/index file  
local function loadGitHubCategory(category, isVehicle, page)
    gtaHashBrowser.isLoading = true
    gtaHashBrowser.loadError = nil
    
    page = page or 1
    local itemsPerPage = 40 -- Load 40 at a time as requested
    
    if page == 1 then
        gtaHashBrowser.items = {}
        gtaHashBrowser.allItems = nil
    end
    
    local typeFolder = isVehicle and "vehicles" or "objects"
    
    -- Check if we have cached index
    local cachedIndex = githubIndexCache[typeFolder]
    
    local function processIndex(indexContent)
        local items = {}
        
        -- Parse the index file (one entry per line: category/filename.jpg)
        for line in indexContent:gmatch("[^\r\n]+") do
            local lineCat, filename = line:match("^([^/]+)/(.+)$")
            
            if filename and filename:match("%.jpg$") then
                -- Filter by category if specified
                if not category or lineCat == category then
                    local modelName = filename:gsub("%.jpg$", "")
                    local encodedCat = lineCat:gsub(" ", "%%20")
                    local encodedFile = filename:gsub(" ", "%%20")
                    
                    table.insert(items, {
                        name = modelName,
                        imageUrl = GITHUB_RAW_BASE .. "/" .. typeFolder .. "/" .. encodedCat .. "/" .. encodedFile,
                        category = lineCat
                    })
                end
            end
        end
        
        M.debug_print("[Spooner] Found " .. #items .. " items from GitHub index")
        
        -- Store all items and paginate
        gtaHashBrowser.allItems = items
        gtaHashBrowser.totalItems = #items
        gtaHashBrowser.itemsPerPage = itemsPerPage
        gtaHashBrowser.totalPages = math.ceil(#items / itemsPerPage)
        if gtaHashBrowser.totalPages == 0 then gtaHashBrowser.totalPages = 1 end
        gtaHashBrowser.currentPage = page
        
        -- Populate current page
        local startIdx = (page - 1) * itemsPerPage + 1
        local endIdx = math.min(startIdx + itemsPerPage - 1, #items)
        
        gtaHashBrowser.items = {}
        for i = startIdx, endIdx do
            if items[i] then
                table.insert(gtaHashBrowser.items, items[i])
            end
        end
        
        gtaHashBrowser.isLoading = false
    end
    
    if cachedIndex then
        -- Use cached index
        processIndex(cachedIndex)
    else
        -- Fetch the index file from raw GitHub (no rate limits!)
        local indexUrl = GITHUB_RAW_BASE .. "/" .. typeFolder .. "_index.txt"
        M.debug_print("[Spooner] Fetching GitHub index: " .. indexUrl)
        
        curlGetAsync(indexUrl, function(success, response)
            if not success or not response then
                gtaHashBrowser.loadError = "Failed to fetch index file. Please ensure " .. typeFolder .. "_index.txt exists in the repo."
                gtaHashBrowser.isLoading = false
                return
            end
            
            -- Check if we got an error page
            if response:match("^<!DOCTYPE") or response:match("^<html") or response:match("404") then
                gtaHashBrowser.loadError = "Index file not found. Run generate_github_index.py and push to repo."
                gtaHashBrowser.isLoading = false
                return
            end
            
            M.debug_print("[Spooner] GitHub index loaded: " .. #response .. " bytes")
            
            -- Cache the index
            githubIndexCache[typeFolder] = response
            
            processIndex(response)
        end)
    end
end

-- List source categories
local listCategories = {"Peds", "Objects", "Vehicles"}
local listItemsPerPage = 100

-- Load items from INI list files (PedList.ini, ObjectList.ini, VehicleList.ini)
local function loadListCategory(listType)
    gtaHashBrowser.isLoading = true
    gtaHashBrowser.loadError = nil
    gtaHashBrowser.items = {}
    gtaHashBrowser.currentPage = 1
    gtaHashBrowser.totalPages = 1
    gtaHashBrowser.searchQuery = "" -- Reset search on category load
    
    Script.QueueJob(function()
        local fileName = ""
        if listType == "Peds" then
            fileName = "PedList.ini"
        elseif listType == "Objects" then
            fileName = "ObjectList.ini"
        elseif listType == "Vehicles" then
            fileName = "VehicleList.ini"
        else
            M.debug_print("[Spooner] Unknown list type: " .. tostring(listType))
            gtaHashBrowser.isLoading = false
            return
        end
        
        local filePath = rootPath .. "\\SpoonerAssets\\" .. fileName
        
        -- Read the file
        local file = io.open(filePath, "r")
        if not file then
            M.debug_print("[Spooner] List file not found: " .. filePath)
            gtaHashBrowser.loadError = "File not found: " .. fileName
            gtaHashBrowser.isLoading = false
            return
        end
        
        local allItems = {}
        
        for line in file:lines() do
            local trimmedLine = line:match("^%s*(.-)%s*$")
            if trimmedLine and trimmedLine ~= "" then
                local modelName = nil
                local modelHash = nil
                
                -- Check if line has format "Name=Hash" or just "Name"
                local name, hash = trimmedLine:match("^([^=]+)=(.+)$")
                if name then
                    modelName = name
                    modelHash = hash
                else
                    modelName = trimmedLine
                end
                
                table.insert(allItems, {
                    name = modelName,
                    hash = modelHash,
                    listType = listType
                })
            end
        end
        
        file:close()
        
        M.debug_print("[Spooner] Loaded " .. #allItems .. " items from " .. fileName)
        
        -- Store all items for pagination
        gtaHashBrowser.allItems = allItems
        gtaHashBrowser.displayItems = allItems -- Initially display all items
        gtaHashBrowser.totalItems = #allItems
        gtaHashBrowser.totalPages = math.ceil(#allItems / listItemsPerPage)
        if gtaHashBrowser.totalPages == 0 then gtaHashBrowser.totalPages = 1 end
        
        -- Populate first page
        local startIdx = 1
        local endIdx = math.min(listItemsPerPage, gtaHashBrowser.totalItems)
        gtaHashBrowser.items = {}
        for i = startIdx, endIdx do
            table.insert(gtaHashBrowser.items, gtaHashBrowser.allItems[i])
        end
        
        gtaHashBrowser.isLoading = false
    end)
end

-- Update page for List source
local function updateListPage()
    if not gtaHashBrowser.displayItems then return end
    
    local startIdx = (gtaHashBrowser.currentPage - 1) * listItemsPerPage + 1
    local endIdx = math.min(startIdx + listItemsPerPage - 1, gtaHashBrowser.totalItems)
    
    gtaHashBrowser.items = {}
    if startIdx <= gtaHashBrowser.totalItems then
        for i = startIdx, endIdx do
            table.insert(gtaHashBrowser.items, gtaHashBrowser.displayItems[i])
        end
    end
end

-- Filter list items based on search query
local function updateListSearch(query)
    if not gtaHashBrowser.allItems then return end
    
    -- Safety check: ensure query is a string
    if type(query) ~= "string" then
        query = ""
    end
    
    gtaHashBrowser.searchQuery = query
    
    if not query or query == "" then
        gtaHashBrowser.displayItems = gtaHashBrowser.allItems
    else
        local filtered = {}
        local lowerQuery = query:lower()
        for _, item in ipairs(gtaHashBrowser.allItems) do
            if item.name:lower():find(lowerQuery, 1, true) then
                table.insert(filtered, item)
            end
        end
        gtaHashBrowser.displayItems = filtered
    end
    
    -- Recalculate pagination
    gtaHashBrowser.totalItems = #gtaHashBrowser.displayItems
    gtaHashBrowser.totalPages = math.ceil(gtaHashBrowser.totalItems / listItemsPerPage)
    if gtaHashBrowser.totalPages == 0 then gtaHashBrowser.totalPages = 1 end
    
    -- Reset to page 1
    gtaHashBrowser.currentPage = 1
    updateListPage()
end

-- Load items from a local category folder
local function loadLocalCategory(category, isVehicle)
    gtaHashBrowser.isLoading = true
    gtaHashBrowser.loadError = nil
    gtaHashBrowser.items = {}
    gtaHashBrowser.currentPage = 1
    gtaHashBrowser.totalPages = 1

    Script.QueueJob(function()
        local typeFolder = isVehicle and "vehicles" or "objects"
        local catFolder = category or ""
        -- Construct path: .../SpoonerAssets/gtahashru/objects/<category>
        local basePath = rootPath .. "\\SpoonerAssets\\gtahashru\\" .. typeFolder .. "\\" .. catFolder

        local isRecursive = (category == nil)
        local files = FileMgr.FindFiles(basePath, ".jpg", isRecursive)
        
        if not files then
            M.debug_print("[Spooner] No files found in or directory missing: " .. basePath)
            gtaHashBrowser.isLoading = false
            return
        end
        for _, filePath in ipairs(files) do
                -- Extract filename (model name)
                local fileName = filePath:match("([^\\]+)%.jpg$") or filePath:match("([^/]+)%.jpg$")
                
                -- Determine category if not provided
                local itemCat = category
                if not itemCat then
                    -- Attempt to extract parent folder name as category
                    -- path\to\category\file.jpg
                    local parent = filePath:match(".*[\\/]([^\\/]+)[\\/][^\\/]+$")
                    itemCat = parent or "unknown"
                end
                
                if fileName then
                    table.insert(gtaHashBrowser.items, {
                        name = fileName,
                        imageUrl = filePath, -- Use absolute path
                        category = itemCat,
                        hash = nil
                    })
                end
            end


        -- Sort by name
        table.sort(gtaHashBrowser.items, function(a, b) return a.name < b.name end)

        -- Pagination logic could be applied here if needed if list is huge
        -- For now, let's just show all or implement simple pagination slice in GUI
        -- To keep GUI logic simple, let's keep existing pagination variables but ignore them or setup for slicing?
        -- The existing GUI renders `gtaHashBrowser.items`. If I dump 1000 items, ImGui might lag.
        -- Let's stick to pagination.
        
        -- We will store ALL items in a separate list and populates `items` based on page.
        -- Clear texture cache when loading new category to prevent texture exhaustion
        clearTextureCache()
        
        gtaHashBrowser.allItems = gtaHashBrowser.items -- Store full list
        gtaHashBrowser.totalItems = #gtaHashBrowser.items
        gtaHashBrowser.itemsPerPage = 50 -- Reduced from 50 to prevent texture slot exhaustion
        gtaHashBrowser.totalPages = math.ceil(gtaHashBrowser.totalItems / gtaHashBrowser.itemsPerPage)
        if gtaHashBrowser.totalPages == 0 then gtaHashBrowser.totalPages = 1 end
        
        -- Populate first page
        local startIdx = 1
        local endIdx = math.min(gtaHashBrowser.itemsPerPage, gtaHashBrowser.totalItems)
        gtaHashBrowser.items = {}
        for i = startIdx, endIdx do
            table.insert(gtaHashBrowser.items, gtaHashBrowser.allItems[i])
        end

        gtaHashBrowser.isLoading = false
    end)
end

local function updatePage()
    if not gtaHashBrowser.allItems then return end
    
    local startIdx = (gtaHashBrowser.currentPage - 1) * gtaHashBrowser.itemsPerPage + 1
    local endIdx = math.min(startIdx + gtaHashBrowser.itemsPerPage - 1, gtaHashBrowser.totalItems)
    
    gtaHashBrowser.items = {}
    if startIdx <= gtaHashBrowser.totalItems then
        for i = startIdx, endIdx do
            table.insert(gtaHashBrowser.items, gtaHashBrowser.allItems[i])
        end
    end
end

-- Load image from local path or remote URL into texture cache
local function loadLocalImage(imagePathOrUrl, modelName, category, isVehicle)
    if gtaHashBrowser.textureCache[modelName] then
        return gtaHashBrowser.textureCache[modelName]
    end
    
    -- Hard limit: don't load more textures if we've hit the limit
    if loadedTextureCount >= MAX_LOADED_TEXTURES then
        return "limit_reached"
    end
    
    -- Mark as loading
    gtaHashBrowser.textureCache[modelName] = "loading"
    
    -- Check if it's a remote URL
    if imagePathOrUrl:match("^https?://") then
        -- Remote URL - download first, then load texture
        downloadImageToCache(imagePathOrUrl, modelName, category or gtaHashBrowser.selectedCategory, isVehicle or (gtaHashBrowser.currentTab == "vehicles"), function(localPath)
            if localPath then
                Script.QueueJob(function()
                    pcall(function()
                        local texId = Texture.LoadTextureAsync(localPath)
                        if texId and texId ~= 0 then
                            gtaHashBrowser.textureCache[modelName] = texId
                            loadedTextureCount = loadedTextureCount + 1
                        else
                            gtaHashBrowser.textureCache[modelName] = "failed"
                        end
                    end)
                end)
            else
                gtaHashBrowser.textureCache[modelName] = "failed"
            end
        end)
    else
        -- Local path - load directly
        Script.QueueJob(function()
            pcall(function()
                local safePath = imagePathOrUrl:gsub("/", "\\")
                
                if FileMgr.DoesFileExist(safePath) then
                    local texId = Texture.LoadTextureAsync(safePath)
                    if texId and texId ~= 0 then
                        gtaHashBrowser.textureCache[modelName] = texId
                        loadedTextureCount = loadedTextureCount + 1
                    else
                        gtaHashBrowser.textureCache[modelName] = "failed"
                    end
                else
                    gtaHashBrowser.textureCache[modelName] = "failed"
                end
            end)
        end)
    end
    
    return nil
end

-- Render the GTA Hash Browser GUI
-- Render the GTA Hash Browser GUI
function M.renderGtaHashBrowserGUI()
    -- Tab bar for Objects vs Vehicles
    if ImGui.BeginTabBar("GtaHashTabs") then
        if ImGui.BeginTabItem("Objects") then
            gtaHashBrowser.currentTab = "objects"
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem("Vehicles") then
            gtaHashBrowser.currentTab = "vehicles"
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end
    
    ImGui.Spacing()
    
    -- Category selector
    local categories = gtaHashBrowser.currentTab == "vehicles" 
        and gtaHashBrowser.vehicleCategories 
        or gtaHashBrowser.objectCategories
    
    ImGui.Text("Category:")
    ImGui.SameLine()
    
    -- Category dropdown using a TreeNode + Selectables approach
    local currentCategoryDisplay = gtaHashBrowser.selectedCategory or "All"
    
    if ImGui.BeginCombo("##CategoryCombo", currentCategoryDisplay) then
        -- "All" option
        if ImGui.Selectable("All", gtaHashBrowser.selectedCategory == nil) then
            gtaHashBrowser.selectedCategory = nil
            loadLocalCategory(nil, gtaHashBrowser.currentTab == "vehicles")
        end
        
        -- Category options
        for _, cat in ipairs(categories) do
            if ImGui.Selectable(cat, gtaHashBrowser.selectedCategory == cat) then
                gtaHashBrowser.selectedCategory = cat
                loadLocalCategory(cat, gtaHashBrowser.currentTab == "vehicles")
            end
        end
        ImGui.EndCombo()
    end
    
    ImGui.Spacing()
    
    -- Refresh button
    ImGui.PushStyleColor(ImGuiCol.Button, 0.1, 0.3, 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.15, 0.4, 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.08, 0.25, 0.45, 1.0)
    if ImGui.Button("Refresh") then
        loadLocalCategory(gtaHashBrowser.selectedCategory, gtaHashBrowser.currentTab == "vehicles")
    end
    ImGui.PopStyleColor(3)
    
    ImGui.SameLine()
    
    -- Show loading state
    if gtaHashBrowser.isLoading then
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 0.0, 1.0)
        ImGui.Text("Loading...")
        ImGui.PopStyleColor()
    elseif gtaHashBrowser.loadError then
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.3, 0.3, 1.0)
        ImGui.Text(gtaHashBrowser.loadError)
        ImGui.PopStyleColor()
    else
        ImGui.Text(string.format("Page %d / %d", gtaHashBrowser.currentPage, gtaHashBrowser.totalPages))
    end
    
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    
    -- Display items in a scrollable list
    if #gtaHashBrowser.items == 0 and not gtaHashBrowser.isLoading then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
        ImGui.Text("No items loaded. Select a category.")
        ImGui.PopStyleColor()
    else
        for i, item in ipairs(gtaHashBrowser.items) do
            -- Each item row
            ImGui.PushID(i)
            
            -- Model name (clickable to copy to clipboard)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.9, 1.0, 1.0)
            if ImGui.Selectable(item.name, false) then
                -- Copy model name to clipboard
                Utils.SetClipboardText(item.name)
                GUI.AddToast("GTA Hash", "Copied: " .. item.name, 2000, 0)
            end
            ImGui.PopStyleColor()
            
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Click to copy model name\nRight-click to spawn")
            end
            
            -- Right-click to spawn
            if ImGui.IsItemClicked(1) then -- Right mouse button
                local modelToSpawn = item.name
                Script.QueueJob(function()
                    pcall(function()
                        local hash = Utils.Joaat(modelToSpawn)
                        STREAMING.REQUEST_MODEL(hash)
                        local timeout = 0
                        while not STREAMING.HAS_MODEL_LOADED(hash) and timeout < 100 do
                            Script.Yield(10)
                            timeout = timeout + 1
                        end
                        
                        if STREAMING.HAS_MODEL_LOADED(hash) then
                            local playerPed = PLAYER.PLAYER_PED_ID()
                            local coords = ENTITY.GET_ENTITY_COORDS(playerPed, true)
                            local heading = ENTITY.GET_ENTITY_HEADING(playerPed)
                            
                            -- Spawn in front of player
                            local forwardX = -math.sin(heading * math.pi / 180) * 3.0
                            local forwardY = math.cos(heading * math.pi / 180) * 3.0
                            
                            local spawnX = coords.x + forwardX
                            local spawnY = coords.y + forwardY
                            local spawnZ = coords.z
                            
                            if gtaHashBrowser.currentTab == "vehicles" then
                                GTA.SpawnVehicle(hash, spawnX, spawnY, spawnZ, heading, true, true)
                                GUI.AddToast("GTA Hash", "Spawned vehicle: " .. modelToSpawn, 2000, 0)
                            else
                                GTA.CreateObject(hash, spawnX, spawnY, spawnZ, true, true)
                                GUI.AddToast("GTA Hash", "Spawned object: " .. modelToSpawn, 2000, 0)
                            end
                            
                            STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
                        else
                            GUI.AddToast("GTA Hash", "Failed to load model: " .. modelToSpawn, 3000, 0)
                        end
                    end)
                end)
            end
            
            ImGui.PopID()
        end
    end
    
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    
    -- Pagination controls
    local buttonWidth = 60
    
    -- Previous page
    local canGoPrev = gtaHashBrowser.currentPage > 1 and not gtaHashBrowser.isLoading
    if not canGoPrev then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.2, 0.2, 0.5)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.2, 0.2, 0.2, 0.5)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.2, 0.2, 0.2, 0.5)
    else
        ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.15, 0.4, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.2, 0.5, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.1, 0.35, 1.0)
    end
    
    if ImGui.Button("< Prev", buttonWidth, 0) and canGoPrev then
        gtaHashBrowser.currentPage = gtaHashBrowser.currentPage - 1
        updatePage()
    end
    ImGui.PopStyleColor(3)
    
    ImGui.SameLine()
    
    -- Next page
    local canGoNext = gtaHashBrowser.currentPage < gtaHashBrowser.totalPages and not gtaHashBrowser.isLoading
    if not canGoNext then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.2, 0.2, 0.5)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.2, 0.2, 0.2, 0.5)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.2, 0.2, 0.2, 0.5)
    else
        ImGui.PushStyleColor(ImGuiCol.Button, 0.3, 0.15, 0.4, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.2, 0.5, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.1, 0.35, 1.0)
    end
    
    if ImGui.Button("Next >", buttonWidth, 0) and canGoNext then
        gtaHashBrowser.currentPage = gtaHashBrowser.currentPage + 1
        updatePage()
    end
    ImGui.PopStyleColor(3)
end

-- Get the GTA Hash browser state (for external access if needed)
function M.getGtaHashBrowserState()
    return gtaHashBrowser
end

-- State for standalone window
local gtaHashWindowOpen = false

-- Toggle the standalone GTA Hash browser window
function M.toggleGtaHashWindow()
    gtaHashWindowOpen = not gtaHashWindowOpen
    M.debug_print("[GTA Hash Debug] Window toggled: " .. tostring(gtaHashWindowOpen))
end

-- Check if window is open
function M.isGtaHashWindowOpen()
    return gtaHashWindowOpen
end

-- Set window open state
function M.setGtaHashWindowOpen(open)
    gtaHashWindowOpen = open
end

-- Render the GTA Hash Browser Window (matches other Spooner windows style, top-right corner)
-- Helper to get spawn coordinates from the free camera raycast (where the crosshair/camera is pointing)
local function getSpawnCoordsFromCamera()
    -- Enable compatibility with external free cams by using the actual rendered camera
    -- This works for: Internal Spooner Cam, External Script Cams, and Gameplay Cam
    local camPos = CAM.GET_FINAL_RENDERED_CAM_COORD()
    local camRot = CAM.GET_FINAL_RENDERED_CAM_ROT(2)

    -- If native failed, fallback to player ped (unlikely)
    if not camPos or not camRot then
        local playerPed = PLAYER.PLAYER_PED_ID()
        local coords = ENTITY.GET_ENTITY_COORDS(playerPed, true)
        local heading = ENTITY.GET_ENTITY_HEADING(playerPed)
        
        local forwardX = -math.sin(heading * math.pi / 180) * 3.0
        local forwardY = math.cos(heading * math.pi / 180) * 3.0
        
        return coords.x + forwardX, coords.y + forwardY, coords.z, heading
    end
        
    -- Calculate forward direction from camera rotation
    local radZ = camRot.z * math.pi / 180.0
    local radX = camRot.x * math.pi / 180.0
    local forwardX = -math.sin(radZ) * math.cos(radX)
    local forwardY = math.cos(radZ) * math.cos(radX)
    local forwardZ = math.sin(radX)
    
    -- Raycast endpoint (500 units forward to find ground/surface)
    local endX = camPos.x + forwardX * 500.0
    local endY = camPos.y + forwardY * 500.0
    local endZ = camPos.z + forwardZ * 500.0
    
    -- Perform raycast: flags = 1 (world) - detecting ground/buildings
    local playerPed = PLAYER.PLAYER_PED_ID()
    local rayHandle = SHAPETEST.START_SHAPE_TEST_LOS_PROBE(
        camPos.x, camPos.y, camPos.z,
        endX, endY, endZ,
        1, -- World geometry only
        playerPed, 7
    )
    
    -- Wait for raycast result (synchronous approach for spawn)
    local hit = Memory.AllocInt()
    local endCoords = Memory.Alloc(24)  -- Vector3
    local surfaceNormal = Memory.Alloc(24)  -- Vector3
    local entityHit = Memory.AllocInt()
    
    -- Poll for result
    local resultReady = 0
    local pollCount = 0
    while resultReady ~= 2 and pollCount < 20 do
        Script.Yield(5)
        resultReady = SHAPETEST.GET_SHAPE_TEST_RESULT(rayHandle, hit, endCoords, surfaceNormal, entityHit)
        pollCount = pollCount + 1
    end
    
    local spawnX, spawnY, spawnZ, heading
    
    if resultReady == 2 then
        local hitValue = Memory.ReadInt(hit)
        
        if hitValue == 1 then
            -- Hit something, spawn at the hit point (slightly above to avoid clipping)
            spawnX = Memory.ReadFloat(endCoords)
            spawnY = Memory.ReadFloat(endCoords + 4)
            spawnZ = Memory.ReadFloat(endCoords + 8) + 0.5
        else
            -- No hit, spawn at a default distance from camera
            spawnX = camPos.x + forwardX * 10.0
            spawnY = camPos.y + forwardY * 10.0
            spawnZ = camPos.z + forwardZ * 10.0
        end
    else
        -- Raycast timed out, use default position
        spawnX = camPos.x + forwardX * 10.0
        spawnY = camPos.y + forwardY * 10.0
        spawnZ = camPos.z + forwardZ * 10.0
    end
    
    -- Heading based on camera direction (entity faces away from camera)
    heading = camRot.z + 180.0
    if heading > 360.0 then heading = heading - 360.0 end
    
    Memory.Free(hit)
    Memory.Free(endCoords)
    Memory.Free(surfaceNormal)
    Memory.Free(entityHit)
    
    return spawnX, spawnY, spawnZ, heading
end

-- Helper to spawn item (auto-detects type: tries object first, then vehicle, then ped)
local function spawnItem(modelName, entityType)
    Script.QueueJob(function()
        pcall(function()
            M.debug_print("[Spawn Debug] Starting spawn for: " .. modelName)
            local hash = Utils.Joaat(modelName)
            M.debug_print("[Spawn Debug] Hash: " .. tostring(hash))
            
            STREAMING.REQUEST_MODEL(hash)
            local timeout = 0
            while not STREAMING.HAS_MODEL_LOADED(hash) and timeout < 100 do
                Script.Yield(10)
                timeout = timeout + 1
            end
            
            if STREAMING.HAS_MODEL_LOADED(hash) then
                M.debug_print("[Spawn Debug] Model loaded successfully")
                
                -- Get spawn coords from camera raycast
                local spawnX, spawnY, spawnZ, heading = getSpawnCoordsFromCamera()
                
                M.debug_print("[Spawn Debug] Spawn coords: " .. spawnX .. ", " .. spawnY .. ", " .. spawnZ)
                
                -- Determine entity type (explicit or auto-detect: object -> vehicle -> ped)
                local detectedType = "object"
                if entityType == "vehicle" then
                    detectedType = "vehicle"
                elseif entityType == "ped" then
                    detectedType = "ped"
                elseif entityType == "object" then
                    detectedType = "object"
                else
                    -- Auto-detect: try object first, then vehicle, then ped
                    if STREAMING.IS_MODEL_A_VEHICLE(hash) then
                        detectedType = "vehicle"
                    elseif STREAMING.IS_MODEL_A_PED(hash) then
                        detectedType = "ped"
                    else
                        detectedType = "object"
                    end
                end
                
                M.debug_print("[Spawn Debug] Detected type: " .. detectedType)
                
                local spawnSuccess = false
                local newEntity = nil
                
                if detectedType == "vehicle" and GTA and GTA.SpawnVehicle then
                    M.debug_print("[Spawn Debug] Attempting to spawn vehicle...")
                    local newVeh = GTA.SpawnVehicle(hash, spawnX, spawnY, spawnZ, heading, true, true)
                    M.debug_print("[Spawn Debug] Vehicle handle: " .. tostring(newVeh))
                    if newVeh and newVeh ~= 0 and ENTITY.DOES_ENTITY_EXIST(newVeh) then
                        M.debug_print("[Spawn Debug] Vehicle spawned successfully!")
                        GUI.AddToast("Browser", "Spawned vehicle: " .. modelName, 2000, 0)
                        spawnSuccess = true
                        newEntity = newVeh
                        
                        -- Add to database automatically
                        local displayName = modelName
                        pcall(function()
                             if GTA and GTA.GetDisplayNameFromHash then
                                local dn = GTA.GetDisplayNameFromHash(hash)
                                if dn and dn ~= "" and dn ~= "null" then
                                    displayName = dn
                                end
                             end
                        end)

                        entityDatabase[newVeh] = {
                            handle = newVeh,
                            type = "vehicle",
                            model = hash,
                            customName = displayName
                        }
                    else
                        M.debug_print("[Spawn Debug] Vehicle spawn FAILED - entity does not exist")
                    end
                elseif detectedType == "ped" and GTA and GTA.CreatePed then
                    M.debug_print("[Spawn Debug] Attempting to spawn ped...")
                    local newPed = GTA.CreatePed(hash, 26, spawnX, spawnY, spawnZ, heading, true, true)
                    M.debug_print("[Spawn Debug] Ped handle: " .. tostring(newPed))
                    if newPed and newPed ~= 0 and ENTITY.DOES_ENTITY_EXIST(newPed) then
                        M.debug_print("[Spawn Debug] Ped spawned successfully!")
                        GUI.AddToast("Browser", "Spawned ped: " .. modelName, 2000, 0)
                        spawnSuccess = true
                        newEntity = newPed
                        
                        -- Add to database automatically
                        entityDatabase[newPed] = {
                            handle = newPed,
                            type = "ped",
                            model = hash,
                            customName = modelName
                        }
                    else
                        M.debug_print("[Spawn Debug] Ped spawn FAILED - entity does not exist")
                    end
                else
                    -- Object spawning with fallback
                    local newObj = nil
                    
                    -- Try GTA.CreateObject first
                    M.debug_print("[Spawn Debug] Attempting to spawn object with CreateObject...")
                    newObj = GTA.CreateObject(hash, spawnX, spawnY, spawnZ, true, true)
                    M.debug_print("[Spawn Debug] CreateObject handle: " .. tostring(newObj))
                    
                    -- Fallback to GTA.CreateWorldObject if CreateObject failed
                    if (not newObj or newObj == 0 or not ENTITY.DOES_ENTITY_EXIST(newObj)) then
                        M.debug_print("[Spawn Debug] CreateObject failed, trying CreateWorldObject...")
                        newObj = GTA.CreateWorldObject(hash, spawnX, spawnY, spawnZ, true, true)
                        M.debug_print("[Spawn Debug] CreateWorldObject handle: " .. tostring(newObj))
                    end
                    
                    if newObj and newObj ~= 0 and ENTITY.DOES_ENTITY_EXIST(newObj) then
                        M.debug_print("[Spawn Debug] Object spawned successfully!")
                        GUI.AddToast("Browser", "Spawned object: " .. modelName, 2000, 0)
                        spawnSuccess = true
                        newEntity = newObj
                        
                        -- Add to database automatically
                        entityDatabase[newObj] = {
                            handle = newObj,
                            type = "object",
                            model = hash,
                            customName = modelName
                        }
                    else
                        M.debug_print("[Spawn Debug] Object spawn FAILED - entity does not exist")
                    end
                end
                
                if not spawnSuccess then
                    M.debug_print("[Spawn Debug] All spawn attempts failed for type: " .. detectedType)
                elseif newEntity then
                    M.debug_print("[Spawn Debug] Entering auto-select block, newEntity: " .. tostring(newEntity))
                    
                    -- Wrap ConstructorLib call in pcall to prevent it from breaking flow
                    if ConstructorLib then
                        local ok, err = pcall(function()
                            ConstructorLib.make_entity_networked({handle = newEntity})
                        end)
                        if not ok then
                            M.debug_print("[Spawn Debug] ConstructorLib error: " .. tostring(err))
                        end
                    end

                    M.debug_print("[Spawn Debug] selectOnSpawn: " .. tostring(gtaHashBrowser.selectOnSpawn))
                    M.debug_print("[Spawn Debug] spawnerSettings: " .. tostring(spawnerSettings))
                    M.debug_print("[Spawn Debug] enableSpooner: " .. tostring(spawnerSettings and spawnerSettings.enableSpooner))
                    
                    if (gtaHashBrowser.selectOnSpawn == nil or gtaHashBrowser.selectOnSpawn == true) then
                        M.debug_print("[Spawn Debug] selectOnSpawn condition PASSED")
                        -- Auto-select logic (after successful spawn)
                        if spawnerSettings and spawnerSettings.enableSpooner then
                             M.debug_print("[Spawn Debug] Spooner mode condition PASSED - selecting entity: " .. tostring(newEntity))
                             selectedEntity = newEntity
                             selectedEntityType = detectedType
                             updateToggleStatesForEntity(selectedEntity)
                             checkEntityAttachments(selectedEntity)
                             M.debug_print("[Spawn Debug] selectedEntity is now: " .. tostring(selectedEntity))
                             GUI.AddToast("Spooner", "Auto-selected spawned entity", 1500, 0)
                        else
                             M.debug_print("[Spawn Debug] Spooner mode condition FAILED")
                        end
                    else
                        M.debug_print("[Spawn Debug] selectOnSpawn condition FAILED")
                    end
                end
                
                STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
            else
                M.debug_print("[Spawn Debug] Model failed to load after timeout")
                GUI.AddToast("Browser", "Failed to load model: " .. modelName, 3000, 0)
            end
        end)
    end)
end

-- Helper to delete the current preview entity
local function deletePreviewEntity()
    if gtaHashBrowser.previewEntity ~= 0 then
        local entityToDelete = gtaHashBrowser.previewEntity
        gtaHashBrowser.previewEntity = 0
        gtaHashBrowser.previewModelName = nil
        Script.QueueJob(function()
            pcall(function()
                if entityToDelete and entityToDelete ~= 0 and ENTITY.DOES_ENTITY_EXIST(entityToDelete) then
                    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(entityToDelete, true, true)
                    local ptr = Memory.AllocInt()
                    Memory.WriteInt(ptr, entityToDelete)
                    ENTITY.DELETE_ENTITY(ptr)
                end
            end)
        end)
    end
end

-- Helper to draw bounding box for an entity
local function drawBoundingBox(entity)
     if not entity or entity == 0 or not ENTITY.DOES_ENTITY_EXIST(entity) then return end
     
     local min = Memory.Alloc(24)
     local max = Memory.Alloc(24)
     MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(entity), min, max)
     
     local minX = Memory.ReadFloat(min)
     local minY = Memory.ReadFloat(min + 8)
     local minZ = Memory.ReadFloat(min + 16)
     local maxX = Memory.ReadFloat(max)
     local maxY = Memory.ReadFloat(max + 8)
     local maxZ = Memory.ReadFloat(max + 16)
     
     Memory.Free(min)
     Memory.Free(max)
     
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
    
    local worldCorners = {}
    for _, corner in ipairs(corners) do
        local worldPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(entity, corner[1], corner[2], corner[3])
        table.insert(worldCorners, worldPos)
    end
    
    local boxColor = {r = 180, g = 100, b = 255, a = 200}
    
    -- Bottom
    GRAPHICS.DRAW_LINE(worldCorners[1].x, worldCorners[1].y, worldCorners[1].z, worldCorners[2].x, worldCorners[2].y, worldCorners[2].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[2].x, worldCorners[2].y, worldCorners[2].z, worldCorners[3].x, worldCorners[3].y, worldCorners[3].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[3].x, worldCorners[3].y, worldCorners[3].z, worldCorners[4].x, worldCorners[4].y, worldCorners[4].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[4].x, worldCorners[4].y, worldCorners[4].z, worldCorners[1].x, worldCorners[1].y, worldCorners[1].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    
    -- Top
    GRAPHICS.DRAW_LINE(worldCorners[5].x, worldCorners[5].y, worldCorners[5].z, worldCorners[6].x, worldCorners[6].y, worldCorners[6].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[6].x, worldCorners[6].y, worldCorners[6].z, worldCorners[7].x, worldCorners[7].y, worldCorners[7].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[7].x, worldCorners[7].y, worldCorners[7].z, worldCorners[8].x, worldCorners[8].y, worldCorners[8].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[8].x, worldCorners[8].y, worldCorners[8].z, worldCorners[5].x, worldCorners[5].y, worldCorners[5].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    
    -- Sides
    GRAPHICS.DRAW_LINE(worldCorners[1].x, worldCorners[1].y, worldCorners[1].z, worldCorners[5].x, worldCorners[5].y, worldCorners[5].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[2].x, worldCorners[2].y, worldCorners[2].z, worldCorners[6].x, worldCorners[6].y, worldCorners[6].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[3].x, worldCorners[3].y, worldCorners[3].z, worldCorners[7].x, worldCorners[7].y, worldCorners[7].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
    GRAPHICS.DRAW_LINE(worldCorners[4].x, worldCorners[4].y, worldCorners[4].z, worldCorners[8].x, worldCorners[8].y, worldCorners[8].z, boxColor.r, boxColor.g, boxColor.b, boxColor.a)
end

local previewLoopRunning = false
local function startPreviewLoop()
    if previewLoopRunning then return end
    previewLoopRunning = true
    Script.QueueJob(function()
        while previewLoopRunning do
             if gtaHashBrowser.previewEnabled and gtaHashBrowser.previewEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(gtaHashBrowser.previewEntity) then
                 pcall(drawBoundingBox, gtaHashBrowser.previewEntity)
             end
             Script.Yield(0)
        end
    end)
end

-- Helper to spawn a preview entity (non-blocking version of spawnItem for preview)
local function spawnPreviewEntity(modelName, entityType)
    startPreviewLoop() -- Ensure loop is running

    -- Don't spawn if already spawning or if same model already spawned
    if gtaHashBrowser.previewSpawning then return end
    if gtaHashBrowser.previewModelName == modelName and gtaHashBrowser.previewEntity ~= 0 then return end
    
    -- Delete existing preview first
    deletePreviewEntity()
    
    gtaHashBrowser.previewSpawning = true
    gtaHashBrowser.previewModelName = modelName
    
    Script.QueueJob(function()
        pcall(function()
            local hash = Utils.Joaat(modelName)
            
            STREAMING.REQUEST_MODEL(hash)
            local timeout = 0
            -- Shorter timeout for preview (faster response)
            while not STREAMING.HAS_MODEL_LOADED(hash) and timeout < 50 do
                Script.Yield(10)
                timeout = timeout + 1
            end
            
            -- Check if we should still spawn (model name might have changed)
            if gtaHashBrowser.previewModelName ~= modelName then
                gtaHashBrowser.previewSpawning = false
                STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
                return
            end
            
            if STREAMING.HAS_MODEL_LOADED(hash) then
                -- Get spawn coords from camera raycast
                local spawnX, spawnY, spawnZ, heading = getSpawnCoordsFromCamera()
                
                -- Determine entity type
                local detectedType = entityType
                if not detectedType then
                    if STREAMING.IS_MODEL_A_VEHICLE(hash) then
                        detectedType = "vehicle"
                    elseif STREAMING.IS_MODEL_A_PED(hash) then
                        detectedType = "ped"
                    else
                        detectedType = "object"
                    end
                end
                
                local newEntity = nil
                
                if detectedType == "vehicle" then
                    newEntity = GTA.SpawnVehicle(hash, spawnX, spawnY, spawnZ, heading, true, true)
                elseif detectedType == "ped" then
                    newEntity = GTA.CreatePed(hash, 26, spawnX, spawnY, spawnZ, heading, true, true)
                else
                    -- Try object
                    newEntity = GTA.CreateObject(hash, spawnX, spawnY, spawnZ, true, true)
                    if (not newEntity or newEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(newEntity)) then
                        newEntity = GTA.CreateWorldObject(hash, spawnX, spawnY, spawnZ, true, true)
                    end
                end
                
                -- Verify and store preview entity
                if newEntity and newEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(newEntity) then
                    -- Check again if model name still matches (could have changed during spawn)
                    if gtaHashBrowser.previewModelName == modelName then
                        gtaHashBrowser.previewEntity = newEntity
                        -- Freeze the entity and disable collision for preview
                        ENTITY.FREEZE_ENTITY_POSITION(newEntity, true)
                        ENTITY.SET_ENTITY_COLLISION(newEntity, false, false)
                    else
                        -- Model changed, delete this one
                        ENTITY.SET_ENTITY_AS_MISSION_ENTITY(newEntity, true, true)
                        local ptr = Memory.AllocInt()
                        Memory.WriteInt(ptr, newEntity)
                        ENTITY.DELETE_ENTITY(ptr)
                    end
                end
                
                STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
            end
        end)
        gtaHashBrowser.previewSpawning = false
    end)
end

-- Track if any item was hovered this frame (for preview cleanup)
local browserItemHoveredThisFrame = false

function M.renderGtaHashBrowserWindow()
    -- Hide browser if GUI is not open (but keep state)
    local guiOpen = false
    pcall(function()
        guiOpen = GUI.IsOpen()
    end)
    if not guiOpen then
        return
    end
    
    -- If browser is completely hidden (from Spooner Tab toggle), don't render anything
    if not browserVisible then
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    local padding = 20
    local windowWidth = 900
    local windowHeight = 725
    local posY = padding
    
    -- Style colors used for both states
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.1, 0.1, 0.15, 0.85)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.4, 0.2, 0.6, 0.8)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.15, 0.12, 0.2, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0.25, 0.2, 0.35, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0.3, 0.25, 0.4, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, 0.25, 0.15, 0.4, 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.35, 0.25, 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.4, 0.3, 0.55, 1.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 8.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12.0, 10.0)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4.0)
    
    if not browserExpanded then
        -- Collapsed state - show small expand button on right edge
        local collapsedWidth = 50
        local collapsedHeight = 50
        local posX = screenWidth - collapsedWidth - padding
        
        ImGui.SetNextWindowPos(posX, posY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(collapsedWidth, collapsedHeight, ImGuiCond.Always)
        
        local windowFlags = ImGuiWindowFlags.NoResize + 
                            ImGuiWindowFlags.NoMove + 
                            ImGuiWindowFlags.NoCollapse +
                            ImGuiWindowFlags.NoScrollbar +
                            ImGuiWindowFlags.NoTitleBar
        
        if ImGui.Begin("##BrowserCollapsed", true, windowFlags) then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
            if ImGui.Button("<", 24, 24) then
                browserExpanded = true
            end
            ImGui.PopStyleColor(3)
            if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Expand Browser")
            end
        end
        ImGui.End()
        
        ImGui.PopStyleVar(4)
        ImGui.PopStyleColor(8)
        return
    end
    
    -- Expanded state
    local posX = screenWidth - windowWidth - padding
    
    ImGui.SetNextWindowPos(posX, posY, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSize(windowWidth, windowHeight, ImGuiCond.Always)
    
    local windowFlags = ImGuiWindowFlags.NoResize + 
                        ImGuiWindowFlags.NoCollapse +
                        ImGuiWindowFlags.NoTitleBar +
                        ImGuiWindowFlags.NoScrollbar +
                        ImGuiWindowFlags.NoScrollWithMouse
        
    if ImGui.Begin("##ObjectBrowser", true, windowFlags) then
        -- Reset hover tracking for preview cleanup
        browserItemHoveredThisFrame = false
        
        -- Header with collapse button
        ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
        ImGui.SetWindowFontScale(1.3)
        ImGui.Text("Browser")
        ImGui.SetWindowFontScale(1.0)
        ImGui.PopStyleColor()
        
        -- Collapse button on right side of header
        ImGui.SameLine(windowWidth - 45)
        ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
        if ImGui.Button(">##collapseBrowser", 24, 24) then
            browserExpanded = false
            -- Clean up any preview entity when collapsing
            if gtaHashBrowser.previewEntity ~= 0 then
                deletePreviewEntity()
            end
        end
        ImGui.PopStyleColor(3)
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Collapse")
        end
        
        ImGui.Separator()
        ImGui.Spacing()
            
            -- === ALL DROPDOWNS ON ONE ROW ===
            -- Source dropdown
            ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
            ImGui.Text("Source")
            ImGui.PopStyleColor()
            ImGui.SameLine()
            ImGui.PushItemWidth(110)
            local currentSourceDisplay = "gta5hash.ru"
            if gtaHashBrowser.currentSource == "clipboard" then
                currentSourceDisplay = "Clipboard"
            elseif gtaHashBrowser.currentSource == "list" then
                currentSourceDisplay = "List"
            end
            if ImGui.BeginCombo("##Source", currentSourceDisplay) then
                if ImGui.Selectable("gta5hash.ru", gtaHashBrowser.currentSource == "gta5hash") then
                    if gtaHashBrowser.currentSource ~= "gta5hash" then
                        gtaHashBrowser.currentSource = "gta5hash"
                        gtaHashBrowser.items = {}
                        gtaHashBrowser.allItems = nil
                        -- Auto-load when source changes
                        loadGitHubCategory(gtaHashBrowser.selectedCategory, gtaHashBrowser.currentTab == "vehicles", 1)
                    end
                end
                if ImGui.Selectable("List", gtaHashBrowser.currentSource == "list") then
                    if gtaHashBrowser.currentSource ~= "list" then
                        gtaHashBrowser.currentSource = "list"
                        gtaHashBrowser.items = {}
                        gtaHashBrowser.allItems = nil
                        gtaHashBrowser.selectedListType = gtaHashBrowser.selectedListType or "Peds"
                        -- Auto-load when source changes
                        loadListCategory(gtaHashBrowser.selectedListType)
                    end
                end
                if ImGui.Selectable("Clipboard", gtaHashBrowser.currentSource == "clipboard") then
                    if gtaHashBrowser.currentSource ~= "clipboard" then
                        gtaHashBrowser.currentSource = "clipboard"
                        gtaHashBrowser.items = {}
                        gtaHashBrowser.allItems = nil
                    end
                end
                ImGui.EndCombo()
            end
            ImGui.PopItemWidth()
            
            -- Auto-load on first open (if no items loaded yet and not already loading)
            if not gtaHashBrowser.hasAutoLoaded and not gtaHashBrowser.isLoading and #gtaHashBrowser.items == 0 then
                gtaHashBrowser.hasAutoLoaded = true
                if gtaHashBrowser.currentSource == "gta5hash" then
                    loadGitHubCategory(gtaHashBrowser.selectedCategory, gtaHashBrowser.currentTab == "vehicles", 1)
                elseif gtaHashBrowser.currentSource == "list" then
                    loadListCategory(gtaHashBrowser.selectedListType or "Peds")
                end
            end
            
            -- Show Type and Category dropdowns for gta5hash source
            if gtaHashBrowser.currentSource == "gta5hash" then

                ImGui.SameLine()
                
                -- Type dropdown
                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                ImGui.Text("Type")
                ImGui.PopStyleColor()
                ImGui.SameLine()
                ImGui.PushItemWidth(90)
                local currentType = gtaHashBrowser.currentTab == "vehicles" and "Vehicles" or "Objects"
                if ImGui.BeginCombo("##Type", currentType) then
                    if ImGui.Selectable("Objects", gtaHashBrowser.currentTab == "objects") then
                        if gtaHashBrowser.currentTab ~= "objects" then
                            gtaHashBrowser.currentTab = "objects"
                            gtaHashBrowser.selectedCategory = nil
                            gtaHashBrowser.items = {}
                            gtaHashBrowser.allItems = nil
                        end
                    end
                    if ImGui.Selectable("Vehicles", gtaHashBrowser.currentTab == "vehicles") then
                        if gtaHashBrowser.currentTab ~= "vehicles" then
                            gtaHashBrowser.currentTab = "vehicles"
                            gtaHashBrowser.selectedCategory = nil
                            gtaHashBrowser.items = {}
                            gtaHashBrowser.allItems = nil
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.PopItemWidth()
                
                ImGui.SameLine()
                
                -- Category dropdown
                local categories = gtaHashBrowser.currentTab == "vehicles" 
                    and gtaHashBrowser.vehicleCategories 
                    or gtaHashBrowser.objectCategories
                
                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                ImGui.Text("Category")
                ImGui.PopStyleColor()
                ImGui.SameLine()
                
                local currentCategoryDisplay = gtaHashBrowser.selectedCategory or "All"
                ImGui.PushItemWidth(180)
                if ImGui.BeginCombo("##Category", currentCategoryDisplay) then
                    if ImGui.Selectable("All", gtaHashBrowser.selectedCategory == nil) then
                        if gtaHashBrowser.selectedCategory ~= nil then
                            gtaHashBrowser.selectedCategory = nil
                            loadGitHubCategory(nil, gtaHashBrowser.currentTab == "vehicles", 1)
                        end
                    end
                    for _, cat in ipairs(categories) do
                        if ImGui.Selectable(cat, gtaHashBrowser.selectedCategory == cat) then
                            if gtaHashBrowser.selectedCategory ~= cat then
                                gtaHashBrowser.selectedCategory = cat
                                loadGitHubCategory(cat, gtaHashBrowser.currentTab == "vehicles", 1)
                            end
                        end
                    end
                    ImGui.EndCombo()
                end
            ImGui.PopItemWidth()
            
            elseif gtaHashBrowser.currentSource == "list" then
                -- List source: Type dropdown (Peds, Objects, Vehicles)
                ImGui.SameLine()
                
                ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
                ImGui.Text("Type")
                ImGui.PopStyleColor()
                ImGui.SameLine()
                
                gtaHashBrowser.selectedListType = gtaHashBrowser.selectedListType or "Peds"
                ImGui.PushItemWidth(140) -- Widened from 100
                if ImGui.BeginCombo("##ListType", gtaHashBrowser.selectedListType) then
                    for _, listType in ipairs(listCategories) do
                        if ImGui.Selectable(listType, gtaHashBrowser.selectedListType == listType) then
                            if gtaHashBrowser.selectedListType ~= listType then
                                gtaHashBrowser.selectedListType = listType
                                loadListCategory(listType)
                            end
                        end
                    end
                    ImGui.EndCombo()
                end
                ImGui.PopItemWidth()
                
                -- Display Names Toggle for Vehicles
                if gtaHashBrowser.selectedListType == "Vehicles" then
                    ImGui.SameLine()
                    local showNames = ImGui.Checkbox("Display Names", gtaHashBrowser.showDisplayNames)
                    if showNames ~= gtaHashBrowser.showDisplayNames then
                        gtaHashBrowser.showDisplayNames = showNames
                    end
                end
            end -- End of source type if/elseif block
            



            ImGui.SameLine()
            
            -- Status on same row
            if gtaHashBrowser.isLoading then
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 0.0, 1.0)
                ImGui.Text("Loading...")
                ImGui.PopStyleColor()
            elseif gtaHashBrowser.loadError then
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.3, 0.3, 1.0)
                ImGui.Text("Error")
                ImGui.PopStyleColor()
            else
                ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.7, 1.0)
                ImGui.Text(string.format("%d items", gtaHashBrowser.totalItems or 0))
                ImGui.PopStyleColor()
            end
            
            -- Search Bar for List Source (Right Aligned)
            if gtaHashBrowser.currentSource == "list" then
                local searchWidth = 180
                -- windowWidth is 900. Position at 900 - searchWidth - padding
                ImGui.SameLine(windowWidth - searchWidth - 25)
                ImGui.PushItemWidth(searchWidth)
                
                gtaHashBrowser.searchQuery = gtaHashBrowser.searchQuery or ""
                local newQuery, changed = ImGui.InputText("##SearchList", gtaHashBrowser.searchQuery, 256)
                if changed then
                    updateListSearch(newQuery)
                end
                ImGui.PopItemWidth()
            end
            
            ImGui.Separator()
            ImGui.Spacing()
            
            -- Skip entire grid section for clipboard (clipboard has its own UI)
            if gtaHashBrowser.currentSource ~= "clipboard" then
            
            -- Grid of items with images (MUCH larger size)
            local itemWidth = 200
            local gridHeight = 530
            
            ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.08, 0.08, 0.12, 0.5)
            ImGui.BeginChild("ItemGrid", 0, gridHeight, true)
            
            if #gtaHashBrowser.items == 0 and not gtaHashBrowser.isLoading then
                ImGui.Spacing()
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
                ImGui.Text("No items loaded.")
                ImGui.Text("Select a category.")
                ImGui.PopStyleColor()
            elseif gtaHashBrowser.currentSource == "list" then
                -- List source: 3-column text display (no images)
                local numColumns = 3
                if ImGui.BeginTable("ListItemTable", numColumns, 0) then
                    for i, item in ipairs(gtaHashBrowser.items) do
                        ImGui.TableNextColumn()
                        
                        ImGui.PushID(i)
                        
                        -- Clickable text button for each item
                        ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.12, 0.2, 0.8)
                        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.2, 0.35, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.35, 0.25, 0.45, 1.0)
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
                        
                        -- Truncate long names
                        local displayName = item.name
                        
                        -- Handle Display Names for Vehicles
                        if gtaHashBrowser.currentSource == "list" and gtaHashBrowser.selectedListType == "Vehicles" and gtaHashBrowser.showDisplayNames then
                            if not item.cachedDisplayName then
                                local hash = item.hash
                                local hashInt = nil
                                
                                if hash then
                                    hashInt = tonumber(hash)
                                end
                                
                                -- Try to get hash from name if missing
                                if not hashInt and GTA and GTA.GetHashKey then
                                    hashInt = GTA.GetHashKey(item.name)
                                end
                                
                                if hashInt then
                                    pcall(function()
                                        -- Use existing getModelName helper (User requested simplification)
                                        -- Note: We can't pass an entity handle here since we only have hash/name
                                        -- So we replicate the robust logic from getModelName but for a hash
                                        
                                        local displayName = "Unknown"
                                        
                                        -- Try GTA.GetDisplayNameFromHash first 
                                        local dn = GTA.GetDisplayNameFromHash(hashInt)
                                        if dn and dn ~= "" and dn ~= "null" then
                                            displayName = dn
                                        end
                                        
                                        -- Fallback if that failed
                                        if displayName == "Unknown" then
                                            local realName = VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(hashInt)
                                            if realName and realName ~= "" and realName ~= "CARNOTFOUND" then
                                                -- Attempt to localize if it looks like a label
                                                local localized = realName
                                                if HUD and HUD._GET_LABEL_TEXT then
                                                     local labelText = HUD._GET_LABEL_TEXT(realName)
                                                     if labelText and labelText ~= "NULL" then
                                                         localized = labelText
                                                     end
                                                end
                                                displayName = localized
                                            else
                                                -- Final fallback to list name
                                                displayName = item.name
                                            end
                                        end
                                        
                                        item.cachedDisplayName = displayName
                                    end)
                                end
                            end
                            
                            if item.cachedDisplayName then
                                displayName = item.cachedDisplayName
                            end
                        end

                        if #displayName > 22 then
                            displayName = displayName:sub(1, 20) .. ".."
                        end
                        
                        if ImGui.Button(displayName, -1, 0) then
                            -- Spawn based on list type
                            if item.listType == "Vehicles" then
                                spawnItem(item.name, "vehicle")
                            elseif item.listType == "Peds" then
                                spawnItem(item.name, "ped")
                            else
                                spawnItem(item.name, "object")
                            end
                        end
                        
                        ImGui.PopStyleColor(4)
                        
                        if ImGui.IsItemHovered() then
                            local tooltip = item.name
                            if item.hash then
                                tooltip = tooltip .. "\nHash: " .. item.hash
                            end
                            tooltip = tooltip .. "\nClick to spawn"
                            ImGui.SetTooltip(tooltip)
                            
                            -- Preview spawn on hover
                            if gtaHashBrowser.previewEnabled then
                                browserItemHoveredThisFrame = true
                                local entityType = nil
                                if item.listType == "Vehicles" then
                                    entityType = "vehicle"
                                elseif item.listType == "Peds" then
                                    entityType = "ped"
                                else
                                    entityType = "object"
                                end
                                spawnPreviewEntity(item.name, entityType)
                            end
                        end
                        
                        ImGui.PopID()
                    end
                    ImGui.EndTable()
                end
            else
                -- Calculate Columns
                local availWidth, availHeight = ImGui.GetContentRegionAvail()
                if not availWidth then availWidth = 380 end
                local gridPadding = 10
                local numColumns = math.floor(availWidth / (itemWidth + gridPadding))
                if numColumns < 1 then numColumns = 1 end

                if ImGui.BeginTable("ItemGridTable", numColumns, 0) then
                     for i, item in ipairs(gtaHashBrowser.items) do
                        ImGui.TableNextColumn()
                        
                        ImGui.PushID(i)
                        ImGui.BeginGroup()

                        local texId = gtaHashBrowser.textureCache[item.name]
                        
                        if not texId and item.imageUrl then
                            loadLocalImage(item.imageUrl, item.name, item.category, gtaHashBrowser.currentTab == "vehicles")
                        end
                        
                        local drawn = false
                        if type(texId) == "number" and texId > 0 then
                             if Texture.IsTextureValid(texId) then
                                local d3dTex = Texture.GetTexture(texId)
                                if d3dTex then
                                    local gpuTex = d3dTex:GetCurrent()
                                    if gpuTex then
                                        local texW = d3dTex:GetWidth()
                                        local texH = d3dTex:GetHeight()
                                        if texW > 0 and texH > 0 then
                                            local aspect = texW / texH
                                            local imgH = itemWidth / aspect
                                            if imgH > itemWidth * 1.2 then
                                                imgH = itemWidth * 1.2
                                            end
                                            
                                            local cursorX, cursorY = ImGui.GetCursorScreenPos()
                                            
                                            ImGui.PushStyleColor(ImGuiCol.Button, 0.12, 0.12, 0.18, 0.8)
                                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.2, 0.35, 1.0)
                                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.35, 0.25, 0.45, 1.0)
                                            
                                            local clicked = ImGui.Button("##" .. item.name, itemWidth, imgH)
                                            
                                            ImGui.PopStyleColor(3)
                                            
                                            pcall(function()
                                                ImGui.AddImage(gpuTex, cursorX, cursorY, cursorX + itemWidth, cursorY + imgH)
                                            end)

                                            if clicked then
                                                 local entityType = gtaHashBrowser.currentTab == "vehicles" and "vehicle" or "object"
                                                 spawnItem(item.name, entityType)
                                            end
                                            -- Check hover for preview on the image button
                                            if ImGui.IsItemHovered() then
                                                if gtaHashBrowser.previewEnabled then
                                                    browserItemHoveredThisFrame = true
                                                    local entityType = gtaHashBrowser.currentTab == "vehicles" and "vehicle" or "object"
                                                    spawnPreviewEntity(item.name, entityType)
                                                end
                                            end
                                            drawn = true
                                        end
                                    end
                                end
                             end
                        end
                        
                        if not drawn then
                            ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.12, 0.2, 0.8)
                            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.2, 0.35, 1.0)
                            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.35, 0.25, 0.45, 1.0)
                            if ImGui.Button("?", itemWidth, itemWidth * 0.75) then
                                local entityType = gtaHashBrowser.currentTab == "vehicles" and "vehicle" or "object"
                                spawnItem(item.name, entityType)
                            end
                            ImGui.PopStyleColor(3)
                        end
                        
                        if ImGui.IsItemHovered() then
                            ImGui.SetTooltip(item.name .. "\nClick to spawn")
                            
                            -- Preview spawn on hover
                            if gtaHashBrowser.previewEnabled then
                                browserItemHoveredThisFrame = true
                                local entityType = gtaHashBrowser.currentTab == "vehicles" and "vehicle" or "object"
                                spawnPreviewEntity(item.name, entityType)
                            end
                        end

                        local displayName = item.name
                        if #displayName > 14 then
                            displayName = displayName:sub(1, 12) .. ".."
                        end
                        ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.9, 1.0)
                        ImGui.Text(displayName)
                        ImGui.PopStyleColor()
                        
                        ImGui.EndGroup()
                        ImGui.PopID()
                     end
                     ImGui.EndTable()
                end
            end
            
            ImGui.EndChild()
            ImGui.PopStyleColor()
            
            -- Preview cleanup: if preview is enabled but nothing was hovered this frame, delete preview
            if gtaHashBrowser.previewEnabled and not browserItemHoveredThisFrame and gtaHashBrowser.previewEntity ~= 0 then
                deletePreviewEntity()
            end
            
            ImGui.Spacing()
            
            -- Bottom bar: Pagination
            ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.15, 0.3, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.3, 0.22, 0.4, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.25, 0.18, 0.35, 1.0)
            
            if ImGui.Button("< Prev", 60, 0) then
                if gtaHashBrowser.currentPage > 1 and not gtaHashBrowser.isLoading then
                    gtaHashBrowser.currentPage = gtaHashBrowser.currentPage - 1
                    if gtaHashBrowser.currentSource == "remote" then
                        loadRemoteCategory(gtaHashBrowser.selectedCategory, gtaHashBrowser.currentTab == "vehicles", gtaHashBrowser.currentPage)
                    elseif gtaHashBrowser.currentSource == "list" then
                        updateListPage()
                    else
                        -- GitHub and local both use in-memory pagination
                        updatePage()
                    end
                end
            end
            
            ImGui.SameLine()
            
            ImGui.PushStyleColor(ImGuiCol.Text, 0.7, 0.7, 0.8, 1.0)
            ImGui.Text(string.format(" %d / %d ", gtaHashBrowser.currentPage, gtaHashBrowser.totalPages))
            ImGui.PopStyleColor()
            
            ImGui.SameLine()
            
            if ImGui.Button("Next >", 60, 0) then
                if gtaHashBrowser.currentPage < gtaHashBrowser.totalPages and not gtaHashBrowser.isLoading then
                    gtaHashBrowser.currentPage = gtaHashBrowser.currentPage + 1
                    if gtaHashBrowser.currentSource == "remote" then
                        loadRemoteCategory(gtaHashBrowser.selectedCategory, gtaHashBrowser.currentTab == "vehicles", gtaHashBrowser.currentPage)
                    elseif gtaHashBrowser.currentSource == "list" then
                        updateListPage()
                    else
                        -- GitHub and local both use in-memory pagination
                        updatePage()
                    end
                end
            end
            
            ImGui.PopStyleColor(3)

            ImGui.SameLine()
            ImGui.Dummy(5, 1)
            ImGui.SameLine()
            
            -- Preview Toggle
            local preview = ImGui.Checkbox("Preview", gtaHashBrowser.previewEnabled)
            if preview ~= gtaHashBrowser.previewEnabled then
                 gtaHashBrowser.previewEnabled = preview
                 if not preview then
                     deletePreviewEntity()
                 end
            end
             if ImGui.IsItemHovered() then
                ImGui.SetTooltip("Show a 3D preview of the entity when hovering in the list")
            end

            -- Auto-Select Toggle (only visible in Spooner mode)
            if spawnerSettings and spawnerSettings.enableSpooner then
                ImGui.SameLine()
                local selectOnSpawn = ImGui.Checkbox("Auto-Select", gtaHashBrowser.selectOnSpawn)
                if selectOnSpawn ~= gtaHashBrowser.selectOnSpawn then
                    gtaHashBrowser.selectOnSpawn = selectOnSpawn
                end
                if ImGui.IsItemHovered() then
                    ImGui.SetTooltip("Automatically select the entity after spawning")
                end
            end
            

            end -- End of clipboard skip block (grid + pagination)
            
            -- ========== CLIPBOARD SOURCE ==========
            if gtaHashBrowser.currentSource == "clipboard" then
                ImGui.Separator()
                ImGui.Spacing()
                
                -- Auto-check clipboard every 1 second
                local currentTime = Time.GetEpocheMs()
                if currentTime - gtaHashBrowser.lastClipboardCheck > 1000 then
                    gtaHashBrowser.lastClipboardCheck = currentTime
                    Script.QueueJob(function()
                        pcall(function()
                            local clipContent = Utils.GetClipBoardText()
                            if clipContent and clipContent ~= "" then
                                gtaHashBrowser.clipboardText = clipContent
                            end
                        end)
                    end)
                end
                
                -- Display clipboard content
                ImGui.PushStyleColor(ImGuiCol.Text, 0.9, 0.7, 1.0, 1.0)
                ImGui.SetWindowFontScale(1.1)
                ImGui.Text("Clipboard Model:")
                ImGui.SetWindowFontScale(1.0)
                ImGui.PopStyleColor()
                
                ImGui.Spacing()
                
                -- Show the clipboard text with spawn button
                local clipText = gtaHashBrowser.clipboardText
                if clipText and clipText ~= "" then
                    -- Clean the text (remove whitespace, newlines)
                    clipText = clipText:match("^%s*(.-)%s*$") or clipText
                    
                    -- Main row with name and spawn button
                    ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.12, 0.1, 0.18, 0.9)
                    ImGui.BeginChild("ClipboardItem", 0, 60, true)
                    
                    -- Model name (large)
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 1.0, 1.0)
                    ImGui.SetWindowFontScale(1.3)
                    ImGui.Text(clipText)
                    ImGui.SetWindowFontScale(1.0)
                    ImGui.PopStyleColor()
                    
                    ImGui.SameLine(windowWidth - 150)
                    
                    -- Spawn button (auto-detects type: tries object, then vehicle, then ped)
                    ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.5, 0.3, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.25, 0.6, 0.35, 1.0)
                    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.18, 0.45, 0.28, 1.0)
                    if ImGui.Button("Spawn##clipboard", 100, 35) then
                        spawnItem(clipText, nil) -- nil = auto-detect type
                    end
                    ImGui.PopStyleColor(3)
                    
                    ImGui.EndChild()
                    ImGui.PopStyleColor()
                else
                    ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.6, 1.0)
                    ImGui.Text("Copy a model name to your clipboard to spawn it.")
                    ImGui.Text("Example: prop_bench_01a or sultanrs")
                    ImGui.PopStyleColor()
                end
            end
        ImGui.End()
    end
    
    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(8)
end

-- Helper to spawn item

-- Render the crosshair for free cam mode
function M.renderCrosshair()
    if not spawnerSettings or not spawnerSettings.enableSpooner then
        return
    end
    
    if not freeCamState.initialized or not freeCamState.enabled then
        return
    end
    
    -- Hide crosshair when GUI menu is open
    local menuOpen = false
    pcall(function()
        menuOpen = GUI.IsOpen()
    end)
    if menuOpen then
        return
    end
    
    local screenWidth, screenHeight = ImGui.GetDisplaySize()
    if not screenWidth or not screenHeight then return end
    
    local centerX = screenWidth / 2
    local centerY = screenHeight / 2
    
    -- Determine crosshair color based on whether we're hovering over an entity
    local r, g, b, a
    if hoveredEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(hoveredEntity) then
        -- Green when hovering over an entity
        r, g, b, a = 0.2, 1.0, 0.4, 1.0
    else
        -- White when not hovering
        r, g, b, a = 1.0, 1.0, 1.0, 0.8
    end
    
    local crosshairSize = 12
    local crosshairThickness = 2
    local gapSize = 4
    
    -- Use ImGui to draw the crosshair with a transparent window
    ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)
    ImGui.SetNextWindowSize(screenWidth, screenHeight, ImGuiCond.Always)
    
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0, 0, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 0)
    
    local windowFlags = ImGuiWindowFlags.NoTitleBar +
                        ImGuiWindowFlags.NoResize +
                        ImGuiWindowFlags.NoMove +
                        ImGuiWindowFlags.NoScrollbar +
                        ImGuiWindowFlags.NoInputs +
                        ImGuiWindowFlags.NoBackground
    
    if ImGui.Begin("##Crosshair", true, windowFlags) then
        -- Draw crosshair lines using ImGui rectangles
        -- Horizontal line (left part)
        ImGui.SetCursorScreenPos(centerX - crosshairSize - gapSize, centerY - crosshairThickness/2)
        ImGui.PushStyleColor(ImGuiCol.Button, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, r, g, b, a)
        ImGui.Button("##crossL", crosshairSize, crosshairThickness)
        ImGui.PopStyleColor(3)
        
        -- Horizontal line (right part)
        ImGui.SetCursorScreenPos(centerX + gapSize, centerY - crosshairThickness/2)
        ImGui.PushStyleColor(ImGuiCol.Button, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, r, g, b, a)
        ImGui.Button("##crossR", crosshairSize, crosshairThickness)
        ImGui.PopStyleColor(3)
        
        -- Vertical line (top part)
        ImGui.SetCursorScreenPos(centerX - crosshairThickness/2, centerY - crosshairSize - gapSize)
        ImGui.PushStyleColor(ImGuiCol.Button, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, r, g, b, a)
        ImGui.Button("##crossT", crosshairThickness, crosshairSize)
        ImGui.PopStyleColor(3)
        
        -- Vertical line (bottom part)
        ImGui.SetCursorScreenPos(centerX - crosshairThickness/2, centerY + gapSize)
        ImGui.PushStyleColor(ImGuiCol.Button, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, r, g, b, a)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, r, g, b, a)
        ImGui.Button("##crossB", crosshairThickness, crosshairSize)
        ImGui.PopStyleColor(3)
        
        -- If hovering, show entity name
        if hoveredEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(hoveredEntity) then
            local entityName = getModelName(hoveredEntity)
            local typeName = hoveredEntityType or "Entity"
            local displayText = typeName:sub(1,1):upper() .. typeName:sub(2) .. ": " .. entityName
            
            ImGui.SetCursorScreenPos(centerX + 25, centerY - 10)
            ImGui.PushStyleColor(ImGuiCol.Text, r, g, b, a)
            ImGui.Text(displayText)
            ImGui.PopStyleColor()
        end
    end
    ImGui.End()
    
    ImGui.PopStyleVar(2)
    ImGui.PopStyleColor()
end

return M
