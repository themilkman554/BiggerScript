local constructor_lib = require("BiggerScript/lib/constructor_lib")
local Hoverboard = {}

-- ============================================================
-- State
-- ============================================================

Hoverboard.Active         = false
Hoverboard._vehicle       = 0
Hoverboard._board         = 0
Hoverboard._ped           = 0
Hoverboard._decor1        = 0
Hoverboard._decor2        = 0
Hoverboard._state         = "idle"   -- idle / crouching / spinning / boosting
Hoverboard._spinAngle     = 0.0
Hoverboard._spinTicks     = 0
Hoverboard._spinDir       = 1        -- 1 or -1, alternates each spin
Hoverboard._boardVariation = 1
Hoverboard._eTrick        = false
Hoverboard._eTrickIndex   = 1         -- cycles between tricks

-- ============================================================
-- Model hashes (from bbbbb.json)
-- vehicle: 1353120668  (motorcycle base)
-- board:   1159992493  (object, type 3)
-- ped:     2602752943  (type 2)
-- ============================================================

local MOTO_HASH  = 1353120668
local DECOR_HASH = 4173782916

local function GetBoardHash(variation)
    local num = string.format("%02d", variation)
    return Utils.Joaat("prop_boogieboard_" .. num)
end

-- E-key trick definitions: { dict, anim, upsideDown, offsetY }
local E_TRICKS = {
    { dict = "anim@amb@nightclub@mini@dance@dance_solo@female@var_b@", anim = "high_center_up",             upsideDown = true  },
    { dict = "rcm_barry2",                                            anim = "clown_idle_1",               upsideDown = false },
    { dict = "sol_3_int-24",                                          anim = "cs_devin_dual-24",           upsideDown = false, offsetY = -0.9 },
    { dict = "hs4f_ext-13",                                           anim = "a_f_y_clubcust_04^2_dual-13", upsideDown = false, offsetY = -0.1 },
}

-- ============================================================
-- Helpers 
-- ============================================================

local function WaitForModel(hash, maxTicks)
    STREAMING.REQUEST_MODEL(hash)
    local t = 0
    while not STREAMING.HAS_MODEL_LOADED(hash) and t < (maxTicks or 100) do
        Script.Yield()
        t = t + 1
    end
end

-- (DeleteEntitySafe removed)

local function SpawnDecors(board)
    if not board or board == 0 or not ENTITY.DOES_ENTITY_EXIST(board) then return 0, 0 end

    WaitForModel(DECOR_HASH)

    local pos1 = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(board, -0.2, 0.08, 0.1)
    local d1 = GTA.CreateObject(DECOR_HASH, pos1.x, pos1.y, pos1.z, true, true)
    if d1 and d1 ~= 0 then
        -- quat(-0.4876, 0.5121, 0.4876, 0.5121) → xRot=0, yRot=-90, zRot=90
        ENTITY.ATTACH_ENTITY_TO_ENTITY(d1, board, -1,
            -0.2, 0.08, 0.1,
            0.0, 90.0, 90.0,
            false, false, false, false, 2, true, 0)
    end

    local pos2 = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(board, 0.2, 0.1, 0.2)
    local d2 = GTA.CreateObject(DECOR_HASH, pos2.x, pos2.y, pos2.z, true, true)
    if d2 and d2 ~= 0 then
        -- quat(0.5, 0.5, -0.5, 0.5) → xRot=0, yRot=90, zRot=90
        ENTITY.ATTACH_ENTITY_TO_ENTITY(d2, board, -1,
            0.2, 0.1, 0.2,
            0.0, 90.0, 90.0,
            false, false, false, false, 2, true, 0)
    end

    STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(DECOR_HASH)
    return d1 or 0, d2 or 0
end

-- ============================================================
-- Spawn
-- ============================================================

function Hoverboard.Spawn()
    Script.QueueJob(function()
        local myPed = PLAYER.PLAYER_PED_ID()
        local pos   = ENTITY.GET_ENTITY_COORDS(myPed, true)

        -- Load models
        WaitForModel(MOTO_HASH)
        local boardHash = GetBoardHash(Hoverboard._boardVariation)
        WaitForModel(boardHash)

        -- Spawn motorcycle in front of player, then we'll use it as-is
        local veh = GTA.SpawnVehicleForPlayer(MOTO_HASH, GTA.GetLocalPlayerId(), 3.0)
        if not veh or veh == 0 then return end

        -- 0 opacity (fully invisible)
        ENTITY.SET_ENTITY_ALPHA(veh, 0, false)
        ENTITY.SET_ENTITY_INVINCIBLE(veh, true)
        ENTITY.SET_VEHICLE_AS_NO_LONGER_NEEDED = nil -- just skip

        -- Spawn board (object, line 272 in json)
        -- Attached to vehicle: offset (0, 0, 0.3), rotation -90° on X → pitch=-90, roll=0, yaw=0
        local boardPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(veh, 0.0, 0.0, 0.3)
        local board = GTA.CreateObject(boardHash, boardPos.x, boardPos.y, boardPos.z, true, true)
        if board and board ~= 0 then
            -- bone 0, offset (0,0,0.3) from vehicle, -90° pitch
            -- params: entity1, entity2, boneIndex, xPos,yPos,zPos, xRot,yRot,zRot, p9, useSoftPinning, collision, isPed, vertexIndex, fixedRot, p15
            ENTITY.ATTACH_ENTITY_TO_ENTITY(board, veh, 0,
                0.0, 0.0, 0.3,
                -90.0, 0.0, 0.0,
                false, false, false, false, 2, true, 0)
            Hoverboard._board = board

            -- Spawn decorations on the board
            Hoverboard._decor1, Hoverboard._decor2 = SpawnDecors(board)
        end

        -- Spawn ped (clone of player ped)
        -- Attached to board: offset (0,-1,0), quat(0.7071,0,0,0.7071) = pitch +90°
        if board and board ~= 0 then
            local ped = PED.CLONE_PED(myPed, ENTITY.GET_ENTITY_HEADING(myPed), true, false)
            if ped and ped ~= 0 then
                -- bone -1, offset (0,-1,0), +90° pitch, isPed = true
                -- params: entity1, entity2, boneIndex, xPos,yPos,zPos, xRot,yRot,zRot, p9, useSoftPinning, collision, isPed, vertexIndex, fixedRot, p15
                ENTITY.ATTACH_ENTITY_TO_ENTITY(ped, board, -1,
                    0.0, -1.0, 0.0,
                    90.0, 0.0, 0.0,
                    false, false, false, true, 2, true, 0)
                ENTITY.SET_ENTITY_INVINCIBLE(ped, true)

                -- Load and play base_jump_idle animation
                local animDict = "oddjobs@bailbond_mountain"
                local animName = "base_jump_idle"
                STREAMING.REQUEST_ANIM_DICT(animDict)
                local t = 0
                while not STREAMING.HAS_ANIM_DICT_LOADED(animDict) and t < 100 do
                    Script.Yield()
                    t = t + 1
                end
                TASK.TASK_PLAY_ANIM(ped, animDict, animName, 8.0, -8.0, -1, 1, 0.0, false, false, false)
                -- Block non-temporary events so animation can't be interrupted
                PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)

                Hoverboard._ped = ped
            end
        end

        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(MOTO_HASH)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(boardHash)

        -- Preload crouch anim dict for jump trick
        STREAMING.REQUEST_ANIM_DICT("move_crouch_proto")
        local t2 = 0
        while not STREAMING.HAS_ANIM_DICT_LOADED("move_crouch_proto") and t2 < 100 do
            Script.Yield()
            t2 = t2 + 1
        end

        -- Preload sunbathe anim dict for boost
        STREAMING.REQUEST_ANIM_DICT("amb@world_human_sunbathe@male@front@base")
        local t3 = 0
        while not STREAMING.HAS_ANIM_DICT_LOADED("amb@world_human_sunbathe@male@front@base") and t3 < 100 do
            Script.Yield()
            t3 = t3 + 1
        end

        -- Preload all E-trick anim dicts
        for _, trick in ipairs(E_TRICKS) do
            STREAMING.REQUEST_ANIM_DICT(trick.dict)
            local tw = 0
            while not STREAMING.HAS_ANIM_DICT_LOADED(trick.dict) and tw < 100 do
                Script.Yield()
                tw = tw + 1
            end
        end

        -- Put player in the vehicle and make driver invisible
        PED.SET_PED_INTO_VEHICLE(myPed, veh, -1)
        ENTITY.SET_ENTITY_VISIBLE(myPed, false, false)

        FeatureMgr.GetFeatureByName("Seatbelt"):SetValue(true):TriggerCallback()
        FeatureMgr.GetFeatureByName("Drive On Water"):SetValue(true):TriggerCallback()
        FeatureMgr.GetFeatureByName("Auto Repair"):SetValue(true):TriggerCallback()
        Hoverboard._vehicle = veh
        Hoverboard.Active   = true
    end)
end

-- ============================================================
-- Tick loop (event blocking per frame)
-- ============================================================

function Hoverboard.OnTick()
    if not Hoverboard.Active then return end

    local ped   = Hoverboard._ped
    local board = Hoverboard._board
    local veh   = Hoverboard._vehicle

    -- Keep ped events blocked
    if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
        PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
    end


    local state = Hoverboard._state

    -- ── F-key trick to exit ────────────────────────
    -- F key (VK_F = 0x46)
    if Utils.IsKeyDown(0x46) then
        local feature = FeatureMgr.GetFeatureByName("Hoverboard")
        if feature then
            feature:SetValue(false)
        end
        Hoverboard.Toggle(false)
        GUI.AddToast("Hoverboard", "Hoverboard Disabled", 3000, 0)
        return
    end
    -- ──────────────────────────────────────────────────────────

    -- ── E-key trick (highest priority) ────────────────────────
    -- INPUT_CONTEXT = 51 (E key)
    if PAD.IS_CONTROL_PRESSED(0, 51) then
        if not Hoverboard._eTrick then
            Hoverboard._eTrick = true
            local trick = E_TRICKS[Hoverboard._eTrickIndex]
            if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) and trick then
                ENTITY.DETACH_ENTITY(ped, true, true)
                local xRot    = trick.upsideDown and -90.0 or 90.0
                local offsetY = trick.offsetY or -1.0
                ENTITY.ATTACH_ENTITY_TO_ENTITY(ped, board, -1,
                    0.0, offsetY, 0.0,
                    xRot, 0.0, 0.0,
                    false, false, false, true, 2, true, 0)
                TASK.TASK_PLAY_ANIM(ped, trick.dict, trick.anim,
                    8.0, -8.0, -1, 1, 0.0, false, false, false)
            end
        end
        return  -- skip all other state logic while E is held
    elseif Hoverboard._eTrick then
        -- E just released: restore and cycle to next trick
        Hoverboard._eTrick = false
        Hoverboard._eTrickIndex = (Hoverboard._eTrickIndex % #E_TRICKS) + 1
        if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
            ENTITY.DETACH_ENTITY(ped, true, true)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(ped, board, -1,
                0.0, -1.0, 0.0,
                90.0, 0.0, 0.0,
                false, false, false, true, 2, true, 0)
            TASK.TASK_PLAY_ANIM(ped, "oddjobs@bailbond_mountain", "base_jump_idle",
                8.0, -8.0, -1, 1, 0.0, false, false, false)
        end
    end
    -- ──────────────────────────────────────────────────────────

    if state == "idle" then
        -- Detect space press → start crouching
        if PAD.IS_DISABLED_CONTROL_PRESSED(0, 76) then
            Hoverboard._state = "crouching"
            if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
                TASK.TASK_PLAY_ANIM(ped, "move_crouch_proto", "idle",
                    8.0, -8.0, -1, 1, 0.0, false, false, false)
            end

        -- Detect shift press → start boosting
        elseif PAD.IS_CONTROL_PRESSED(0, 21) then
            Hoverboard._state = "boosting"
            if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
                TASK.TASK_PLAY_ANIM(ped, "amb@world_human_sunbathe@male@front@base", "base",
                    8.0, -8.0, -1, 1, 0.0, false, false, false)
            end
        end

    elseif state == "crouching" then
        -- Holding space: stay crouched. On release: jump + spin
        if not PAD.IS_DISABLED_CONTROL_PRESSED(0, 76) then
            Hoverboard._state     = "spinning"
            Hoverboard._spinAngle = 0.0
            Hoverboard._spinTicks = 20  -- spin for ~20 frames

            -- Apply upward force
            if veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(veh) then
                ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(veh, 1,
                    0.0, 0.0, 15.0, false, false, true, false)
            end
        end

    elseif state == "spinning" then
        -- Spin the board each frame
        Hoverboard._spinAngle = (Hoverboard._spinAngle + 18.0 * Hoverboard._spinDir) % 360.0
        Hoverboard._spinTicks = Hoverboard._spinTicks - 1

        if board ~= 0 and ENTITY.DOES_ENTITY_EXIST(board) then
            ENTITY.DETACH_ENTITY(board, true, true)
            ENTITY.ATTACH_ENTITY_TO_ENTITY(board, veh, 0,
                0.0, 0.0, 0.3,
                -90.0, 0.0, Hoverboard._spinAngle,
                false, false, false, false, 2, true, 0)
        end

        -- Spin finished → restore
        if Hoverboard._spinTicks <= 0 then
            Hoverboard._state = "idle"
            Hoverboard._spinDir = Hoverboard._spinDir * -1  -- flip for next time

            -- Restore idle anim
            if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
                TASK.TASK_PLAY_ANIM(ped, "oddjobs@bailbond_mountain", "base_jump_idle",
                    8.0, -8.0, -1, 1, 0.0, false, false, false)
            end

            -- Reattach board in normal position
            if board ~= 0 and ENTITY.DOES_ENTITY_EXIST(board) then
                ENTITY.DETACH_ENTITY(board, true, true)
                ENTITY.ATTACH_ENTITY_TO_ENTITY(board, veh, 0,
                    0.0, 0.0, 0.3,
                    -90.0, 0.0, 0.0,
                    false, false, false, false, 2, true, 0)
            end
        end

    elseif state == "boosting" then
        -- While holding shift: apply forward force for speed boost
        if PAD.IS_CONTROL_PRESSED(0, 21) then
            if veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(veh) then
                ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(veh, 1,
                    0.0, 1.0, 0.0, false, true, true, false)
            end
        else
            -- Released shift: restore idle anim
            Hoverboard._state = "idle"
            if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
                TASK.TASK_PLAY_ANIM(ped, "oddjobs@bailbond_mountain", "base_jump_idle",
                    8.0, -8.0, -1, 1, 0.0, false, false, false)
            end
        end
    end
end

function Hoverboard.StartLoop()
    Script.RegisterLooped(function()
        Hoverboard.OnTick()
        Script.Yield()
    end)

    -- Dedicated native-thread loop for control disabling (runs every game frame)
    Script.QueueJob(function()
        while true do
            if Hoverboard.Active then
                local veh = Hoverboard._vehicle
                -- Disable handbrake / brake
                PAD.DISABLE_CONTROL_ACTION(0, 76, true)  -- INPUT_VEH_HANDBRAKE
                -- Disable horn
                PAD.DISABLE_CONTROL_ACTION(0, 86, true)  -- INPUT_VEH_HORN
                -- Disable lean forward (causes downward force on bikes)
                PAD.DISABLE_CONTROL_ACTION(0, 67, true)  -- INPUT_VEH_MOVE_UP_ONLY
                -- Force handbrake off
                if veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(veh) then
                    VEHICLE.SET_VEHICLE_HANDBRAKE(veh, false)
                end
            end
            Script.Yield()
        end
    end)
end

-- ============================================================
-- Board variation swap
-- ============================================================

function Hoverboard.SetBoardVariation(variation)
    Hoverboard._boardVariation = variation
    if not Hoverboard.Active then return end

    Script.QueueJob(function()
        local veh = Hoverboard._vehicle
        local oldBoard = Hoverboard._board
        local ped = Hoverboard._ped
        if veh == 0 or not ENTITY.DOES_ENTITY_EXIST(veh) then return end

        local boardHash = GetBoardHash(variation)
        WaitForModel(boardHash)

        -- Detach ped from old board
        if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
            ENTITY.DETACH_ENTITY(ped, true, true)
        end

        -- Delete old board
        constructor_lib.delete_entity(oldBoard)

        -- Spawn new board and attach to vehicle
        local boardPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(veh, 0.0, 0.0, 0.3)
        local newBoard = GTA.CreateObject(boardHash, boardPos.x, boardPos.y, boardPos.z, true, true)
        if newBoard and newBoard ~= 0 then
            ENTITY.ATTACH_ENTITY_TO_ENTITY(newBoard, veh, 0,
                0.0, 0.0, 0.3,
                -90.0, 0.0, 0.0,
                false, false, false, false, 2, true, 0)
            Hoverboard._board = newBoard

            -- Spawn decors on new board
            constructor_lib.delete_entity(Hoverboard._decor1)
            constructor_lib.delete_entity(Hoverboard._decor2)
            Hoverboard._decor1, Hoverboard._decor2 = SpawnDecors(newBoard)

            -- Reattach ped to new board
            if ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(ped) then
                ENTITY.ATTACH_ENTITY_TO_ENTITY(ped, newBoard, -1,
                    0.0, -1.0, 0.0,
                    90.0, 0.0, 0.0,
                    false, false, false, true, 2, true, 0)
            end
        end

        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(boardHash)
    end)
end

-- ============================================================
-- Delete / Cleanup
-- ============================================================

function Hoverboard.Delete()
    Script.QueueJob(function()
        -- Make driver visible again and eject
        local myPed = PLAYER.PLAYER_PED_ID()
        ENTITY.SET_ENTITY_VISIBLE(myPed, true, false)
        if PED.GET_VEHICLE_PED_IS_IN(myPed, false) == Hoverboard._vehicle then
            TASK.CLEAR_PED_TASKS_IMMEDIATELY(myPed)
            Script.Yield(50)
        end

        constructor_lib.delete_entity(Hoverboard._decor1)
        constructor_lib.delete_entity(Hoverboard._decor2)
        constructor_lib.delete_entity(Hoverboard._ped)
        constructor_lib.delete_entity(Hoverboard._board)
        constructor_lib.delete_entity(Hoverboard._vehicle)

        Hoverboard._vehicle = 0
        Hoverboard._board   = 0
        Hoverboard._ped     = 0
        Hoverboard._decor1  = 0
        Hoverboard._decor2  = 0
        Hoverboard.Active   = false
    end)
end

-- ============================================================
-- Toggle
-- ============================================================

function Hoverboard.Toggle(enabled)
    if enabled then
        if not Hoverboard.Active then
            Hoverboard.Spawn()
        end
    else
        if Hoverboard.Active then
            Hoverboard.Delete()
        end
    end
end

return Hoverboard
