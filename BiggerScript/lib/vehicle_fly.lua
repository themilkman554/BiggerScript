local M = {}
local spawnerSettings

local is_flying = false
local speed = 5.0 
local no_collision = true
local stop_on_exit = true

function M.init(context)
    spawnerSettings = context.spawnerSettings
end

local function do_vehicle_fly()
    if PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false) == 0 then
        is_flying = false
        if spawnerSettings then
            spawnerSettings.vehicleFly = false
        end
        return
    end
    
    local veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
    print("Vehicle Fly: In vehicle " .. tostring(veh))

    if VEHICLE.GET_PED_IN_VEHICLE_SEAT(veh, -1) ~= PLAYER.PLAYER_PED_ID() then
        return
    end

    local cam_pos = CAM.GET_GAMEPLAY_CAM_ROT(0)
    ENTITY.SET_ENTITY_COLLISION(veh, not no_collision, true)
    ENTITY.SET_ENTITY_ROTATION(veh, cam_pos.x, cam_pos.y, cam_pos.z, 1, true)

    local locspeed = speed * 10
    local locspeed2 = speed

    if PAD.IS_CONTROL_PRESSED(0, 76) then 
        locspeed = locspeed * 2
        locspeed2 = locspeed2 * 2
    end

    local dont_stop = false

    -- W (71)
    if PAD.IS_CONTROL_PRESSED(2, 71) then
        if dont_stop then
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, 0.0, speed, 0.0, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        else
            VEHICLE.SET_VEHICLE_FORWARD_SPEED(veh, locspeed)
        end
    end

    -- S (72)
    if PAD.IS_CONTROL_PRESSED(2, 72) then
        local lsp = speed
        if not PAD.IS_CONTROL_PRESSED(0, 61) then
            lsp = speed * 2
        end
        if dont_stop then
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, 0.0, 0 - (lsp), 0.0, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        else
            VEHICLE.SET_VEHICLE_FORWARD_SPEED(veh, 0 - (locspeed))
        end
    end

    -- A (63)
    if PAD.IS_CONTROL_PRESSED(2, 63) then
        local lsp = (0 - speed) * 2
        if not PAD.IS_CONTROL_PRESSED(0, 61) then
            lsp = 0 - speed
        end
        if dont_stop then
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, (lsp), 0.0, 0.0, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        else
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, 0 - (locspeed), 0.0, 0.0, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        end
    end

    -- D (64)
    if PAD.IS_CONTROL_PRESSED(2, 64) then
        local lsp = speed
        if not PAD.IS_CONTROL_PRESSED(0, 61) then
            lsp = speed * 2
        end
        if dont_stop then
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, lsp, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        else
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, locspeed, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        end
    end

    -- Up (61)
    if PAD.IS_CONTROL_PRESSED(2, 61) then
        local lsp = speed
        if dont_stop then
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, 0.0, 0.0, lsp, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        else
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, 0.0, 0.0, locspeed, 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        end
    end

    -- Down (62)
    if PAD.IS_CONTROL_PRESSED(2, 62) then
        local lsp = speed
        if dont_stop then
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, 0.0, 0.0, 0 - (lsp), 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        else
            ENTITY.APPLY_FORCE_TO_ENTITY(veh, 1, 0.0, 0.0, 0 - (locspeed), 0.0, 0.0, 0.0, 0, 1, 1, 1, 0, 1)
        end
    end

    if not dont_stop and not PAD.IS_CONTROL_PRESSED(2, 71) and not PAD.IS_CONTROL_PRESSED(2, 72) then
        VEHICLE.SET_VEHICLE_FORWARD_SPEED(veh, 0.0)
    end
end

function M.toggle_vehicle_fly(enable)
    if enable then
        if is_flying then return end
        
        local veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
        if veh == 0 then
            GUI.AddToast("Vehicle Fly", "Disabled Sport mode. Not in vehicle", 5000, 0)
            if spawnerSettings then
                spawnerSettings.vehicleFly = false
            end
            return
        end

        is_flying = true
        GUI.AddToast("Vehicle Fly", "Space for speed Boost\n Shift/ctrl to go up and down", 5000, 0)
        
        Script.QueueJob(function()
            local last_veh = 0
            while is_flying do
                local current_veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
                print("Vehicle Fly Loop: current_veh " .. tostring(current_veh))
                
                if current_veh == 0 then
                    is_flying = false
                    if spawnerSettings then
                        spawnerSettings.vehicleFly = false
                    end
                    GUI.AddToast("Vehicle Fly", "Disabled Sport mode. Not in vehicle", 5000, 0)
                else
                    last_veh = current_veh
                    if VEHICLE.GET_PED_IN_VEHICLE_SEAT(current_veh, -1) == PLAYER.PLAYER_PED_ID() then
                        VEHICLE.SET_VEHICLE_GRAVITY(current_veh, false)
                        do_vehicle_fly()
                    else
                        VEHICLE.SET_VEHICLE_GRAVITY(current_veh, true)
                        ENTITY.SET_ENTITY_COLLISION(current_veh, true, true)
                    end
                end
                Script.Yield(0)
            end
            
            if last_veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(last_veh) then
                VEHICLE.SET_VEHICLE_GRAVITY(last_veh, true)
                ENTITY.SET_ENTITY_COLLISION(last_veh, true, true)
            end
        end)
    else
        is_flying = false
    end
end

return M
