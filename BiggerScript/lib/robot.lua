local M = {}


local spawnerSettings, debug_print, spawnedVehicles, moveableLegs, legAnimationJob, robot_objects


function M.init(context)
    spawnerSettings = context.spawnerSettings
    debug_print = context.debug_print
    spawnedVehicles = context.spawnedVehicles
    moveableLegs = context.moveableLegs
    legAnimationJob = context.legAnimationJob
    robot_objects = context.robot_objects
end

function M.v3(x, y, z)
    return {x = x, y = y, z = z}
end

function M.clear_legs_movement(robot_obj_tbl)
    robot_obj_tbl = robot_obj_tbl or robot_objects
    if robot_obj_tbl['llbone'] and robot_obj_tbl['rlbone'] and robot_obj_tbl['tampa'] then
        local left = robot_obj_tbl['llbone']
        local right = robot_obj_tbl['rlbone']
        local main = robot_obj_tbl['tampa']
        pcall(function()
            ENTITY.ATTACH_ENTITY_TO_ENTITY(left, main, 0, -4.25, 0, 12.5, 0, 0, 0, true, true, false, false, 2, true)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(right, main, 0, 4.25, 0, 12.5, 0, 0, 0, true, true, false, false, 2, true)
        end)
    end
end

function M.animate_legs(robot_obj_tbl)
    robot_obj_tbl = robot_obj_tbl or robot_objects
    if legAnimationJob and robot_obj_tbl == robot_objects then
        Script.KillJob(legAnimationJob)
        legAnimationJob = nil
    end
    if not moveableLegs and robot_obj_tbl == robot_objects then
        M.clear_legs_movement(robot_obj_tbl)
        return
    end
    local job = Script.QueueJob(function()
        if not robot_obj_tbl['llbone'] or not robot_obj_tbl['rlbone'] or not robot_obj_tbl['tampa'] then return end
        local left = robot_obj_tbl['llbone']
        local right = robot_obj_tbl['rlbone']
        local main = robot_obj_tbl['tampa']
        local offsetL = M.v3(-4.25, 0, 12.5)
        local offsetR = M.v3(4.25, 0, 12.5)
        while robot_obj_tbl['tampa'] and ENTITY.DOES_ENTITY_EXIST(robot_obj_tbl['tampa']) do
            local speed = ENTITY.GET_ENTITY_SPEED(robot_obj_tbl['tampa'])
            if speed < 2.5 then
                M.clear_legs_movement(robot_obj_tbl)
                Script.Yield(100)
            else
                for i = 0, 50 do
                    if not robot_obj_tbl['tampa'] or not ENTITY.DOES_ENTITY_EXIST(robot_obj_tbl['tampa']) then M.clear_legs_movement(robot_obj_tbl) return end
                    speed = ENTITY.GET_ENTITY_SPEED(robot_obj_tbl['tampa'])
                    if speed < 2.5 then break end
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(left, main, 0, offsetL.x, offsetL.y, offsetL.z, i, 0, 0, false, true, false, false, 2, true)
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(right, main, 0, offsetR.x, offsetR.y, offsetR.z, 360 - i, 0, 0, false, true, false, false, 2, true)
                    local wait = math.floor(51 - (speed / 1))
                    if wait < 1 then wait = 0 end
                    Script.Yield(wait)
                end
                for i = 50, -50, -1 do
                    if not robot_obj_tbl['tampa'] or not ENTITY.DOES_ENTITY_EXIST(robot_obj_tbl['tampa']) then M.clear_legs_movement(robot_obj_tbl) return end
                    speed = ENTITY.GET_ENTITY_SPEED(robot_obj_tbl['tampa'])
                    if speed < 2.5 then break end
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(left, main, 0, offsetL.x, offsetL.y, offsetL.z, i, 0, 0, false, true, false, false, 2, true)
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(right, main, 0, offsetR.x, offsetR.y, offsetR.z, 360 - i, 0, 0, false, true, false, false, 2, true)
                    local wait = math.floor(51 - (speed / 1))
                    if wait < 1 then wait = 0 end
                    Script.Yield(wait)
                end
                for i = -50, 0 do
                    if not robot_obj_tbl['tampa'] or not ENTITY.DOES_ENTITY_EXIST(robot_obj_tbl['tampa']) then M.clear_legs_movement(robot_obj_tbl) return end
                    speed = ENTITY.GET_ENTITY_SPEED(robot_obj_tbl['tampa'])
                    if speed < 2.5 then break end
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(left, main, 0, offsetL.x, offsetL.y, offsetL.z, i, 0, 0, false, true, false, false, 2, true)
                    ENTITY.ATTACH_ENTITY_TO_ENTITY(right, main, 0, offsetR.x, offsetR.y, offsetR.z, 360 - i, 0, 0, false, true, false, false, 2, true)
                    local wait = math.floor(51 - (speed / 1))
                    if wait < 1 then wait = 0 end
                    Script.Yield(wait)
                end
            end
        end
        M.clear_legs_movement(robot_obj_tbl)
    end)
    if robot_obj_tbl == robot_objects then
        legAnimationJob = job
    end
end

function M.cleanupRobot()
    Script.QueueJob(function()
        if legAnimationJob then
            Script.KillJob(legAnimationJob)
            legAnimationJob = nil
        end
        for i in pairs(robot_objects) do
            if robot_objects[i] and ENTITY.DOES_ENTITY_EXIST(robot_objects[i]) then
                ENTITY.SET_ENTITY_AS_MISSION_ENTITY(robot_objects[i], false, true)
                ENTITY.DELETE_ENTITY(robot_objects[i])
            end
        end
        robot_objects = {}
    end)
end

function M.selfDestructRobot()
    if not robot_objects['tampa'] then return end
    Script.QueueJob(function()
        for i in pairs(robot_objects) do
            if robot_objects[i] and ENTITY.DOES_ENTITY_EXIST(robot_objects[i]) then
                ENTITY.DETACH_ENTITY(robot_objects[i], true, true)
                ENTITY.SET_ENTITY_INVINCIBLE(robot_objects[i], false)
                ENTITY.FREEZE_ENTITY_POSITION(robot_objects[i], false)
                Script.Yield(0)
            end
        end
        for i in pairs(robot_objects) do
            if robot_objects[i] and ENTITY.DOES_ENTITY_EXIST(robot_objects[i]) then
                local coords = ENTITY.GET_ENTITY_COORDS(robot_objects[i], true)
                FIRE.ADD_EXPLOSION(coords.x, coords.y, coords.z, 8, 1.0, true, false, 0.0)
                Script.Yield(33)
            end
         end
        robot_objects = {}
        moveableLegs = false
    end)
end

function M.spawnRobotAttacker(targetPlayerIndex)
    Script.QueueJob(function()
        local targetPed = nil
        if targetPlayerIndex ~= nil then
            pcall(function() targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerIndex) end)
        end
        if not targetPed or targetPed == 0 then
            M.debug_print("[Spawn Debug] Error: No target ped available for robot attacker spawn.")
            return
        end
        local spawnCoords = { x = 0.0, y = 0.0, z = 0.0 }
        pcall(function()
            local off = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(targetPed, 0, -20.0, 10.0)
            spawnCoords.x = off.x or off[1] or 0.0
            spawnCoords.y = off.y or off[2] or 0.0
            spawnCoords.z = off.z or off[3] or 0.0
            local foundGround, gz = GTA.GetGroundZ(spawnCoords.x, spawnCoords.y)
            if foundGround then spawnCoords.z = gz end
            M.debug_print("[Spawn Debug] Robot Attacker spawn coordinates:", spawnCoords.x, spawnCoords.y, spawnCoords.z)
        end)
        local current_robot_objects = {}
        local tampa_hash = 3084515313
        STREAMING.REQUEST_MODEL(tampa_hash)
        while not STREAMING.HAS_MODEL_LOADED(tampa_hash) do Script.Yield(0) end
        current_robot_objects['tampa'] = VEHICLE.CREATE_VEHICLE(tampa_hash, spawnCoords.x, spawnCoords.y, spawnCoords.z, ENTITY.GET_ENTITY_HEADING(targetPed), true, true)
        DECORATOR.DECOR_SET_INT(current_robot_objects['tampa'], "MPBitset", 1)
        ENTITY.SET_ENTITY_INVINCIBLE(current_robot_objects['tampa'], true)
        VEHICLE.SET_VEHICLE_MOD_KIT(current_robot_objects['tampa'], 0)
        for i = 0, 24 do
            local mod = VEHICLE.GET_NUM_VEHICLE_MODS(current_robot_objects['tampa'], i)
            if mod > 0 then
                VEHICLE.SET_VEHICLE_MOD(current_robot_objects['tampa'], i, mod - 1, false)
            end
        end
        VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(current_robot_objects['tampa'], false)
        VEHICLE.SET_VEHICLE_WINDOW_TINT(current_robot_objects['tampa'], 1)
        VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(current_robot_objects['tampa'], 1)
        VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(current_robot_objects['tampa'], "ATTACK")
        local function spawn_and_attach_attacker(part_name, model_hash, is_vehicle, parent, ox, oy, oz, rx, ry, rz)
            local model = model_hash
            STREAMING.REQUEST_MODEL(model)
            while not STREAMING.HAS_MODEL_LOADED(model) do Script.Yield(0) end
            local coords = ENTITY.GET_ENTITY_COORDS(current_robot_objects[parent], true)
            local entity
            if is_vehicle then
                entity = VEHICLE.CREATE_VEHICLE(model, coords.x, coords.y, coords.z, 0.0, true, true)
            else
                entity = OBJECT.CREATE_OBJECT(model, coords.x, coords.y, coords.z, true, true, false)
            end
            current_robot_objects[part_name] = entity
            ENTITY.SET_ENTITY_INVINCIBLE(entity, true)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(entity, current_robot_objects[parent], 0, ox, oy, oz, rx, ry, rz, true, true, false, false, 2, true)
        end
        spawn_and_attach_attacker('ppdump', 0x810369E2, true, 'tampa', 0, 0, 12.5, 0, 0, 0)
        spawn_and_attach_attacker('llbone', 1803116220, false, 'tampa', -4.25, 0, 12.5, 0, 0, 0)
        spawn_and_attach_attacker('rlbone', 1803116220, false, 'tampa', 4.25, 0, 12.5, 0, 0, 0)
        spawn_and_attach_attacker('lltrain', 1030400667, true, 'llbone', 0, 0, -5, 90, 0, 0)
        spawn_and_attach_attacker('lfoot', 782665360, true, 'llbone', 0, 2, -12.5, 0, 0, 0)
        spawn_and_attach_attacker('rltrain', 1030400667, true, 'rlbone', 0, 0, -5, 90, 0, 0)
        spawn_and_attach_attacker('rfoot', 782665360, true, 'rlbone', 0, 2, -12.5, 0, 0, 0)
        spawn_and_attach_attacker('body', 1030400667, true, 'tampa', 0, 0, 22.5, 90, 0, 0)
        spawn_and_attach_attacker('shoulder', 0x810369E2, true, 'tampa', 0, 0, 27.5, 0, 0, 0)
        spawn_and_attach_attacker('lheadbone', 1803116220, false, 'tampa', -3.25, 0, 27.5, 0, 0, 0)
        spawn_and_attach_attacker('rheadbone', 1803116220, false, 'tampa', 3.25, 0, 27.5, 0, 0, 0)
        spawn_and_attach_attacker('lheadtrain', 1030400667, true, 'lheadbone', -3, 4, -5, 325, 0, 45)
        spawn_and_attach_attacker('lhand', 782665360, true, 'lheadtrain', 0, 7.5, 0, 0, 0, 0)
        spawn_and_attach_attacker('rheadtrain', 1030400667, true, 'rheadbone', 3, 4, -5, 325, 0, 315)
        spawn_and_attach_attacker('rhand', 782665360, true, 'rheadtrain', 0, 7.5, 0, 0, 0, 0)
        spawn_and_attach_attacker('head', -543669801, false, 'tampa', 0, 0, 35, 0, 0, 0)
        local attackerModel = 71929310
        M.request_model_load(attackerModel)
        local attacker = nil
        if GTA and GTA.CreatePed then
            local ok, h = pcall(function() return GTA.CreatePed(attackerModel, 26, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0, true, true) end)
            if ok and h and h ~= 0 then attacker = h end
        end
        if not attacker or attacker == 0 then
            M.debug_print("[Spawn Debug] Error: Failed to spawn attacker ped for robot.")
            return
        end
        M.debug_print("[Spawn Debug] Spawned robot attacker ped handle:", tostring(attacker))
        pcall(function()
            PED.SET_PED_INTO_VEHICLE(attacker, current_robot_objects['tampa'], -1)
            ENTITY.SET_ENTITY_AS_MISSION_ENTITY(attacker, true, true)
            ENTITY.SET_ENTITY_INVINCIBLE(attacker, true)
            PED.SET_PED_ACCURACY(attacker, 100.0)
            PED.SET_PED_COMBAT_ABILITY(attacker, 1, true)
            PED.SET_PED_FLEE_ATTRIBUTES(attacker, 0, false)
            PED.SET_PED_COMBAT_ATTRIBUTES(attacker, 46, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(attacker, 5, true)
            PED.SET_PED_CONFIG_FLAG(attacker, 52, true)
            local relHash = PED.GET_PED_RELATIONSHIP_GROUP_HASH(targetPed)
            PED.SET_PED_RELATIONSHIP_GROUP_HASH(attacker, relHash)
            TASK.TASK_VEHICLE_MISSION_PED_TARGET(attacker, current_robot_objects['tampa'], targetPed, 6, 500.0, 786988, 0.0, 0.0, true)
            M.debug_print("[Spawn Debug] Robot attacker ped configured and tasked.")
        end)
        local vehicleData = {
            vehicle = current_robot_objects['tampa'],
            attachments = {attacker},
            filePath = "Robot Attacker"
        }
        for part_name, entity in pairs(current_robot_objects) do
            if part_name ~= 'tampa' then
                table.insert(vehicleData.attachments, entity)
            end
        end
        table.insert(spawnedVehicles, vehicleData)
        pcall(function()
            GUI.AddToast("Attacker Spawned", "Robot attacker sent to player.", 5000, 0)
        end)
        M.animate_legs(current_robot_objects)
    end)
end

function M.spawnRobot()
    Script.QueueJob(function()
        if robot_objects['tampa'] then return end
        local playerPed = PLAYER.PLAYER_PED_ID()
        local veh = PED.GET_VEHICLE_PED_IS_IN(playerPed, false)
        local spawn_it = true
        if veh ~= 0 and ENTITY.GET_ENTITY_MODEL(veh) == 3084515313 then
            robot_objects['tampa'] = veh
            spawn_it = false
        end
        if spawn_it then
            local playerCoords = ENTITY.GET_ENTITY_COORDS(playerPed, true)
            local playerHeading = ENTITY.GET_ENTITY_HEADING(playerPed)
            local tampa_hash = 3084515313
            STREAMING.REQUEST_MODEL(tampa_hash)
            while not STREAMING.HAS_MODEL_LOADED(tampa_hash) do Script.Yield(0) end
            robot_objects['tampa'] = VEHICLE.CREATE_VEHICLE(tampa_hash, playerCoords.x, playerCoords.y, playerCoords.z, playerHeading, true, true)
            DECORATOR.DECOR_SET_INT(robot_objects['tampa'], "MPBitset", 1)
            ENTITY.SET_ENTITY_INVINCIBLE(robot_objects['tampa'], true)
            VEHICLE.SET_VEHICLE_MOD_KIT(robot_objects['tampa'], 0)
            for i = 0, 24 do
                local mod = VEHICLE.GET_NUM_VEHICLE_MODS(robot_objects['tampa'], i)
                if mod > 0 then
                    VEHICLE.SET_VEHICLE_MOD(robot_objects['tampa'], i, mod - 1, false)
                end
            end
            VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(robot_objects['tampa'], false)
            VEHICLE.SET_VEHICLE_WINDOW_TINT(robot_objects['tampa'], 1)
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT_INDEX(robot_objects['tampa'], 1)
            VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(robot_objects['tampa'], "Bigger")
        end
        local function spawn_and_attach(part_name, model_hash, is_vehicle, parent, ox, oy, oz, rx, ry, rz)
            local model = model_hash
            STREAMING.REQUEST_MODEL(model)
            while not STREAMING.HAS_MODEL_LOADED(model) do Script.Yield(0) end
            local coords = ENTITY.GET_ENTITY_COORDS(robot_objects[parent], true)
            local entity
            if is_vehicle then
                entity = VEHICLE.CREATE_VEHICLE(model, coords.x, coords.y, coords.z, 0.0, true, true)
            else
                entity = OBJECT.CREATE_OBJECT(model, coords.x, coords.y, coords.z, true, true, false)
            end
            robot_objects[part_name] = entity
            ENTITY.SET_ENTITY_INVINCIBLE(entity, true)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(entity, robot_objects[parent], 0, ox, oy, oz, rx, ry, rz, true, true, false, false, 2, true)
        end
        spawn_and_attach('ppdump', 0x810369E2, true, 'tampa', 0, 0, 12.5, 0, 0, 0)
        spawn_and_attach('llbone', 1803116220, false, 'tampa', -4.25, 0, 12.5, 0, 0, 0)
        spawn_and_attach('rlbone', 1803116220, false, 'tampa', 4.25, 0, 12.5, 0, 0, 0)
        spawn_and_attach('lltrain', 1030400667, true, 'llbone', 0, 0, -5, 90, 0, 0)
        spawn_and_attach('lfoot', 782665360, true, 'llbone', 0, 2, -12.5, 0, 0, 0)
        spawn_and_attach('rltrain', 1030400667, true, 'rlbone', 0, 0, -5, 90, 0, 0)
        spawn_and_attach('rfoot', 782665360, true, 'rlbone', 0, 2, -12.5, 0, 0, 0)
        spawn_and_attach('body', 1030400667, true, 'tampa', 0, 0, 22.5, 90, 0, 0)
        spawn_and_attach('shoulder', 0x810369E2, true, 'tampa', 0, 0, 27.5, 0, 0, 0)
        spawn_and_attach('lheadbone', 1803116220, false, 'tampa', -3.25, 0, 27.5, 0, 0, 0)
        spawn_and_attach('rheadbone', 1803116220, false, 'tampa', 3.25, 0, 27.5, 0, 0, 0)
        spawn_and_attach('lheadtrain', 1030400667, true, 'lheadbone', -3, 4, -5, 325, 0, 45)
        spawn_and_attach('lhand', 782665360, true, 'lheadtrain', 0, 7.5, 0, 0, 0, 0)
        spawn_and_attach('rheadtrain', 1030400667, true, 'rheadbone', 3, 4, -5, 325, 0, 315)
        spawn_and_attach('rhand', 782665360, true, 'rheadtrain', 0, 7.5, 0, 0, 0, 0)
        spawn_and_attach('head', -543669801, false, 'tampa', 0, 0, 35, 0, 0, 0)
        moveableLegs = true
        M.animate_legs()
        if robot_objects['tampa'] then
            PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), robot_objects['tampa'], -1)
        end
    end)
end

return M
