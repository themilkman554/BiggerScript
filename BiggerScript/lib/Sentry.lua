local constructor_lib = require("BiggerScript/lib/constructor_lib")
local Sentry = {}

-- ============================================================
-- Constants
-- ============================================================

Sentry.Weapons = {
    { name = "RPG",              value = Utils.Joaat("WEAPON_RPG") },
    { name = "Assault Shotgun",  value = Utils.Joaat("WEAPON_ASSAULTSHOTGUN") },
    { name = "Snowball",         value = Utils.Joaat("WEAPON_SNOWBALL") },
    { name = "Railgun",          value = Utils.Joaat("WEAPON_RAILGUN") },
    { name = "Air Defence",      value = Utils.Joaat("WEAPON_AIR_DEFENCE_GUN") },
}

Sentry.AimTypes = {
    { name = "Vehicles",   value = 0 },
    { name = "Players",    value = 1 },
    { name = "Peds",       value = 2 },
    { name = "Aircraft",   value = 4 },
    { name = "Everything", value = 3 },
}

Sentry.AttachOptions = {
    { name = "Ground",   value = 0 },
    { name = "Self",     value = 1 },
    { name = "Vehicle",  value = 2 },
}

-- Build name lists for ImGui.Combo
Sentry.WeaponNames  = {}
Sentry.AimTypeNames = {}
Sentry.AttachNames  = {}
for i, w in ipairs(Sentry.Weapons)       do Sentry.WeaponNames[i]  = w.name end
for i, a in ipairs(Sentry.AimTypes)      do Sentry.AimTypeNames[i] = a.name end
for i, a in ipairs(Sentry.AttachOptions) do Sentry.AttachNames[i]  = a.name end

-- ============================================================
-- State
-- ============================================================

Sentry.SpawnedSentries = {}

-- Current spawn configuration (indices are 0-based for ImGui.Combo)
Sentry.Settings = {
    weaponIndex  = 0,
    targetIndex  = 0,
    attachIndex  = 0,
    range        = 600.0,
}

-- Whether the looped script has been started
Sentry._loopStarted = false

-- ============================================================
-- Helpers
-- ============================================================

local function GetLocalPed()
    return PLAYER.PLAYER_PED_ID()
end

local function GetLocalCoords()
    return ENTITY.GET_ENTITY_COORDS(GetLocalPed(), true)
end

-- ============================================================
-- Spawn
-- ============================================================

function Sentry.Spawn()
    Script.QueueJob(function()
        local s = Sentry.Settings
        local attachType = Sentry.AttachOptions[s.attachIndex + 1].value
        local weapon     = Sentry.Weapons[s.weaponIndex + 1].value
        local aimType    = Sentry.AimTypes[s.targetIndex + 1].value

        local turret = {
            Populated      = true,
            ExcludeSelf    = true,   -- auto-exclude
            ID             = 0,
            Minigun        = 0,
            Type           = aimType,
            TurrentPed     = 0,
            Weapon         = weapon,
            OnGround       = (attachType == 0),
            TurrentCooldown = 0,
            AttachType     = attachType,
            Parent         = 0,
            Godmode        = false,
            Invisible      = false,
            Range          = s.range,
        }

        local telescopeHash = 0x3250D9D6
        local minigunHash   = 0xC89630B8

        STREAMING.REQUEST_MODEL(telescopeHash)
        STREAMING.REQUEST_MODEL(minigunHash)
        WEAPON.REQUEST_WEAPON_ASSET(turret.Weapon, 31, 0)

        local timeout = 0
        while (not STREAMING.HAS_MODEL_LOADED(telescopeHash) or
               not STREAMING.HAS_MODEL_LOADED(minigunHash) or
               not WEAPON.HAS_WEAPON_ASSET_LOADED(turret.Weapon)) and timeout < 100 do
            Script.Yield()
            timeout = timeout + 1
        end

        local ped = GetLocalPed()
        local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(ped, 0, 1, 0)

        turret.ID      = GTA.CreateObject(telescopeHash, pos.x, pos.y, pos.z, true, true)
        turret.Minigun = GTA.CreateObject(minigunHash, pos.x, pos.y, pos.z, true, true)

        ENTITY.ATTACH_ENTITY_TO_ENTITY(turret.Minigun, turret.ID, 0,
            0.0, 0.3, 1.6, 0.0, 0.0, 90.0, true, true, true, false, 2, true)

        if attachType == 1 then -- Self
            turret.Parent = ped
            ENTITY.ATTACH_ENTITY_TO_ENTITY(turret.ID, ped, 0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        elseif attachType == 2 then -- Vehicle
            local veh = PED.GET_VEHICLE_PED_IS_IN(ped, false)
            if veh ~= 0 then
                turret.Parent = veh
                ENTITY.SET_ENTITY_INVINCIBLE(veh, true)
                ENTITY.ATTACH_ENTITY_TO_ENTITY(turret.ID, veh, 0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            else
                turret.AttachType = 0
                turret.OnGround  = true
                ENTITY.SET_ENTITY_HEADING(turret.ID, ENTITY.GET_ENTITY_HEADING(ped))
            end
        else
            ENTITY.SET_ENTITY_HEADING(turret.ID, ENTITY.GET_ENTITY_HEADING(ped))
        end

        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(telescopeHash)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(minigunHash)

        table.insert(Sentry.SpawnedSentries, turret)
    end)
end

-- ============================================================
-- Delete
-- ============================================================

function Sentry.Delete(index)
    local turret = Sentry.SpawnedSentries[index]
    if not turret then return end

    Script.QueueJob(function()
        constructor_lib.delete_entity(turret.Minigun)
        constructor_lib.delete_entity(turret.ID)
        constructor_lib.delete_entity(turret.TurrentPed)
    end)

    table.remove(Sentry.SpawnedSentries, index)
end

function Sentry.DeleteAll()
    for i = #Sentry.SpawnedSentries, 1, -1 do
        Sentry.Delete(i)
    end
end


-- ============================================================
-- Per-sentry management
-- ============================================================

function Sentry.SetGodmode(index, val)
    local turret = Sentry.SpawnedSentries[index]
    if not turret then return end
    turret.Godmode = val
    if ENTITY.DOES_ENTITY_EXIST(turret.ID) then
        ENTITY.SET_ENTITY_INVINCIBLE(turret.ID, val)
    end
    if turret.Minigun ~= 0 and ENTITY.DOES_ENTITY_EXIST(turret.Minigun) then
        ENTITY.SET_ENTITY_INVINCIBLE(turret.Minigun, val)
    end
end

function Sentry.SetInvisible(index, val)
    local turret = Sentry.SpawnedSentries[index]
    if not turret then return end
    turret.Invisible = val
    if ENTITY.DOES_ENTITY_EXIST(turret.ID) then
        ENTITY.SET_ENTITY_VISIBLE(turret.ID, not val, false)
    end
    if turret.Minigun ~= 0 and ENTITY.DOES_ENTITY_EXIST(turret.Minigun) then
        ENTITY.SET_ENTITY_VISIBLE(turret.Minigun, not val, false)
    end
end

function Sentry.TeleportToMe(index)
    local turret = Sentry.SpawnedSentries[index]
    if not turret then return end
    if ENTITY.DOES_ENTITY_EXIST(turret.ID) then
        local coords = GetLocalCoords()
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(turret.ID, coords.x, coords.y, coords.z, false, false, false)
        turret.OnGround = true
    end
end

-- ============================================================
-- Tick / Update (targeting + shooting)
-- ============================================================

local function UpdateTurret(turret)
    if not ENTITY.DOES_ENTITY_EXIST(turret.ID) then return false end

    local coords = ENTITY.GET_ENTITY_COORDS(turret.ID, false)

    -- Place on ground the first time
    if turret.OnGround then
        ENTITY.SET_ENTITY_COORDS(turret.ID, coords.x, coords.y, coords.z - 1, false, true, true, false)
        turret.OnGround = false
    end

    -- Create hidden ped for shooting (required by SHOOT_SINGLE_BULLET)
    if turret.TurrentPed == 0 then
        local rela    = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(turret.ID, 0, 0, -3)
        local pedHash = MISC.GET_HASH_KEY("a_f_y_skater_01")
        STREAMING.REQUEST_MODEL(pedHash)
        local t = 0
        while not STREAMING.HAS_MODEL_LOADED(pedHash) and t < 50 do
            Script.Yield()
            t = t + 1
        end
        local ped = GTA.CreatePed(pedHash, 21, rela.x, rela.y, rela.z,
            ENTITY.GET_ENTITY_HEADING(GetLocalPed()), true, false)
        if ENTITY.DOES_ENTITY_EXIST(ped) then
            ENTITY.SET_ENTITY_INVINCIBLE(ped, true)
            ENTITY.SET_ENTITY_VISIBLE(ped, false, false)
            ENTITY.SET_ENTITY_COLLISION(ped, false, false)
            ENTITY.FREEZE_ENTITY_POSITION(ped, true)
            turret.TurrentPed = ped
        end
        return true -- wait until next tick to find targets
    end

    -- ---- Target acquisition ----
    local target          = 0
    local closestDistance  = 99999.0
    local myPed           = GetLocalPed()
    local myVeh           = PED.GET_VEHICLE_PED_IS_IN(myPed, false)
    local range           = turret.Range or 600.0
    local targetType      = turret.Type

    -- Vehicles (type 0, 3)
    if targetType == 0 or targetType == 3 then
        local vehCount = PoolMgr.GetCurrentVehicleCount()
        for v = 0, vehCount - 1 do
            local veh = PoolMgr.GetVehicle(v)
            if veh and veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(veh) then
                if veh ~= myVeh and veh ~= turret.Parent then
                    local vc   = ENTITY.GET_ENTITY_COORDS(veh, false)
                    local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(coords.x, coords.y, coords.z, vc.x, vc.y, vc.z, false)
                    if dist < closestDistance and dist < range then
                        target          = veh
                        closestDistance  = dist
                    end
                end
            end
        end
    end

    -- Players (type 1, 3)
    if targetType == 1 or targetType == 3 then
        local nearestPlayer = ENTITY.GET_NEAREST_PLAYER_TO_ENTITY(turret.ID)
        if nearestPlayer ~= -1 then
            local playerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(nearestPlayer)
            if ENTITY.DOES_ENTITY_EXIST(playerPed) and not ENTITY.IS_ENTITY_DEAD(playerPed, false) then
                -- Auto-exclude self
                if not (turret.ExcludeSelf and playerPed == myPed) then
                    local pc   = ENTITY.GET_ENTITY_COORDS(playerPed, false)
                    local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(coords.x, coords.y, coords.z, pc.x, pc.y, pc.z, false)
                    if dist < closestDistance and dist < range then
                        target          = playerPed
                        closestDistance  = dist
                    end
                end
            end
        end
    end

    -- Peds (type 2, 3)
    if targetType == 2 or targetType == 3 then
        local pedCount = PoolMgr.GetCurrentPedCount()
        for p = 0, pedCount - 1 do
            local ped = PoolMgr.GetPed(p)
            if ped and ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) and not ENTITY.IS_ENTITY_DEAD(ped, false) then
                if ped ~= myPed and ped ~= turret.TurrentPed and not PED.IS_PED_A_PLAYER(ped) then
                    local pc   = ENTITY.GET_ENTITY_COORDS(ped, false)
                    local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(coords.x, coords.y, coords.z, pc.x, pc.y, pc.z, false)
                    if dist < closestDistance and dist < range then
                        target          = ped
                        closestDistance  = dist
                    end
                end
            end
        end
    end

    -- Aircraft (type 4, 3)
    if targetType == 4 or targetType == 3 then
        local vehCount = PoolMgr.GetCurrentVehicleCount()
        for v = 0, vehCount - 1 do
            local veh = PoolMgr.GetVehicle(v)
            if veh and veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(veh) then
                local vehHash = ENTITY.GET_ENTITY_MODEL(veh)
                if VEHICLE.IS_THIS_MODEL_A_PLANE(vehHash) or VEHICLE.IS_THIS_MODEL_A_HELI(vehHash) then
                    if veh ~= myVeh and veh ~= turret.Parent then
                        local vc   = ENTITY.GET_ENTITY_COORDS(veh, false)
                        local dist = MISC.GET_DISTANCE_BETWEEN_COORDS(coords.x, coords.y, coords.z, vc.x, vc.y, vc.z, false)
                        if dist < closestDistance and dist < range then
                            target          = veh
                            closestDistance  = dist
                        end
                    end
                end
            end
        end
    end

    -- ---- Aim + Shoot ----
    if target ~= 0 and ENTITY.DOES_ENTITY_EXIST(target) and not ENTITY.IS_ENTITY_DEAD(target, false) then
        local finish   = ENTITY.GET_ENTITY_COORDS(target, false)
        local start    = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(turret.Minigun, 0.7, 0.0, 0.0)
        local distance = MISC.GET_DISTANCE_BETWEEN_COORDS(start.x, start.y, start.z, finish.x, finish.y, finish.z, false)
        local rotY     = MISC.ATAN2((finish.z - start.z), distance) * -1
        local rotZ     = MISC.ATAN2((finish.y - start.y), (finish.x - start.x))

        -- Rotate base
        if turret.AttachType ~= 0 and ENTITY.DOES_ENTITY_EXIST(turret.Parent) then
            local parentHeading = ENTITY.GET_ENTITY_HEADING(turret.Parent)
            local relativeZ     = (rotZ + 90) - parentHeading
            ENTITY.ATTACH_ENTITY_TO_ENTITY(turret.ID, turret.Parent, 0,
                0.0, 0.0, 0.0, 0.0, 0.0, relativeZ, false, false, false, false, 2, true)
        else
            ENTITY.SET_ENTITY_ROTATION(turret.ID, 0, 0, rotZ + 90, 0, false)
        end

        -- Aim minigun
        ENTITY.ATTACH_ENTITY_TO_ENTITY(turret.Minigun, turret.ID, 0,
            0.0, -0.3, 1.6, 0.0, rotY, 270.0, true, true, true, false, 2, true)

        -- Laser
        GRAPHICS.DRAW_LINE(start.x, start.y, start.z, finish.x, finish.y, finish.z, 255, 0, 0, 255)

        -- Shoot
        local rpgHash = 0xB1CA77B1
        if turret.Weapon == rpgHash then
            if turret.TurrentCooldown < MISC.GET_GAME_TIMER() then
                MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(start.x, start.y, start.z,
                    finish.x, finish.y, finish.z, 250, false, turret.Weapon, turret.TurrentPed, true, false, 1000.0)
                turret.TurrentCooldown = MISC.GET_GAME_TIMER() + 1000
            end
        else
            MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(start.x, start.y, start.z,
                finish.x, finish.y, finish.z, 250, false, turret.Weapon, turret.TurrentPed, true, false, 1000.0)
        end
    end

    return true
end

function Sentry.OnTick()
    for i = #Sentry.SpawnedSentries, 1, -1 do
        local alive = UpdateTurret(Sentry.SpawnedSentries[i])
        if not alive then
            table.remove(Sentry.SpawnedSentries, i)
        end
    end
end

-- ============================================================
-- Start the looped script (call once at init)
-- ============================================================

function Sentry.StartLoop()
    if Sentry._loopStarted then return end
    Sentry._loopStarted = true
    Script.RegisterLooped(function()
        Sentry.OnTick()
        Script.Yield()
    end)
end

-- ============================================================
-- ImGui Render  (call from the Donor child window)
-- ============================================================

function Sentry.RenderUI()
    -- Weapon combo
    local weaponList = table.concat(Sentry.WeaponNames, "\0") .. "\0"
    Sentry.Settings.weaponIndex = ImGui.Combo("Weapon##sentry", Sentry.Settings.weaponIndex, weaponList)

    -- Target combo
    local aimList = table.concat(Sentry.AimTypeNames, "\0") .. "\0"
    Sentry.Settings.targetIndex = ImGui.Combo("Target##sentry", Sentry.Settings.targetIndex, aimList)

    -- Attach combo
    local attachList = table.concat(Sentry.AttachNames, "\0") .. "\0"
    Sentry.Settings.attachIndex = ImGui.Combo("Attach##sentry", Sentry.Settings.attachIndex, attachList)

    ImGui.Spacing()

    -- Spawn button
    ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.36, 0.157, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.46, 0.22, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.26, 0.10, 1.0)
    if ImGui.Button("Spawn Sentry") then
        Sentry.Spawn()
    end
    ImGui.PopStyleColor(3)

    ImGui.Spacing()
    ImGui.Separator()

    -- Delete All
    if #Sentry.SpawnedSentries > 0 then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.016, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.06, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.01, 1.0)
        if ImGui.Button("Delete All Sentries") then
            Sentry.DeleteAll()
        end
        ImGui.PopStyleColor(3)
        ImGui.Spacing()
    end

    -- Spawned sentries list
    for i, turret in ipairs(Sentry.SpawnedSentries) do
        if ENTITY.DOES_ENTITY_EXIST(turret.ID) then
            local weaponName = "Sentry"
            for _, w in ipairs(Sentry.Weapons) do
                if w.value == turret.Weapon then weaponName = w.name break end
            end

            ImGui.Text(weaponName .. " #" .. i)
            ImGui.SameLine()

            -- Teleport
            ImGui.PushStyleColor(ImGuiCol.Button, 0.016, 0.157, 0.36, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.06, 0.22, 0.46, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.01, 0.10, 0.26, 1.0)
            if ImGui.Button("TP##sentry" .. i) then
                Sentry.TeleportToMe(i)
            end
            ImGui.PopStyleColor(3)

            ImGui.SameLine()

            -- Delete
            ImGui.PushStyleColor(ImGuiCol.Button, 0.36, 0.016, 0.016, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.46, 0.06, 0.06, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.01, 0.01, 1.0)
            if ImGui.Button("Delete##sentry" .. i) then
                Sentry.Delete(i)
            end
            ImGui.PopStyleColor(3)

            -- Godmode / Invisible toggles
            local newGod = ImGui.Checkbox("Godmode##sentry" .. i, turret.Godmode or false)
            if newGod ~= (turret.Godmode or false) then
                Sentry.SetGodmode(i, newGod)
            end
            ImGui.SameLine()
            local newInvis = ImGui.Checkbox("Invisible##sentry" .. i, turret.Invisible or false)
            if newInvis ~= (turret.Invisible or false) then
                Sentry.SetInvisible(i, newInvis)
            end

            ImGui.Separator()
        end
    end
end

return Sentry
