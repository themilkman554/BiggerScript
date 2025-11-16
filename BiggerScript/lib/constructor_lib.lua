local M = {}

M.set_entity_as_networked = function(attachment, timeout)
    local time <const> = Time.GetEpocheMs() + (timeout or 1500)
    while time > Time.GetEpocheMs() and not NETWORK.NETWORK_GET_ENTITY_IS_NETWORKED(attachment.handle) do
        NETWORK.NETWORK_REGISTER_ENTITY_AS_NETWORKED(attachment.handle)
        Script.Yield(0)
    end
    return NETWORK.NETWORK_GET_ENTITY_IS_NETWORKED(attachment.handle)
end

M.constantize_network_id = function(attachment)
    M.set_entity_as_networked(attachment, 25)
    local net_id <const> = NETWORK.NETWORK_GET_NETWORK_ID_FROM_ENTITY(attachment.handle)
    -- network.set_network_id_can_migrate(net_id, false) -- Caused players unable to drive vehicles
    NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(net_id, true)
    NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(net_id, players.user(), true)
    return net_id
end

M.make_entity_networked = function(attachment)
    ENTITY.SET_ENTITY_AS_MISSION_ENTITY(attachment.handle, false, true)
    ENTITY.SET_ENTITY_SHOULD_FREEZE_WAITING_ON_COLLISION(attachment.handle, false)
    M.constantize_network_id(attachment)
    NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.OBJ_TO_NET(attachment.handle), false)
end

return M
