--[[
    Impulse Lua - Paid Tier System
    Handles premium feature gating based on user UID
]]

local PaidTier = {}

PaidTier.Finished = false



-- List of paid user UIDs
PaidTier.PaidUIDs = {}

-- Cache the result so we don't call GetUID repeatedly
local cachedIsPaid = nil

--- Check if the current user has paid access
---@return boolean
function PaidTier.IsPaid()
    if cachedIsPaid ~= nil then
        return cachedIsPaid
    end
    
    if not PaidTier.PaidUIDs then
        PaidTier.PaidUIDs = {}
    end
    
    local uid = Cherax.GetUID()
    for _, paidUID in ipairs(PaidTier.PaidUIDs) do
        if uid == paidUID then
            cachedIsPaid = true
            return true
        end
    end
    
    cachedIsPaid = false
    return false
end

--- Check if user is on free tier
---@return boolean
function PaidTier.IsFree()
    return not PaidTier.IsPaid()
end

--- Reset cache (useful for testing)
function PaidTier.ResetCache()
    cachedIsPaid = nil
end




PaidTier.RemoteURL = ""
-- I became jewish :pensive:
PaidTier.RemoteToken = ""


function PaidTier.CheckRemote()
    if not Curl then 
        Logger.LogInfo("[PaidTier] Curl library not available.")
        return 
    end

    local curl = Curl.Easy()
    

    local url = PaidTier.RemoteURL .. "?t=" .. tostring(MISC.GET_GAME_TIMER())
    curl:Setopt(eCurlOption.CURLOPT_URL, url)
    

    if PaidTier.RemoteToken and PaidTier.RemoteToken ~= "" then
        curl:AddHeader("Authorization: token " .. PaidTier.RemoteToken)
    end

    curl:Perform()
    
    Script.QueueJob(function()
        local timeout = MISC.GET_GAME_TIMER() + 10000 
        
        while not curl:GetFinished() do
            if MISC.GET_GAME_TIMER() > timeout then
                return
            end
            Script.Yield()
        end
        
        local success, response = curl:GetResponse()
        if success then
            PaidTier.ParseRemoteList(response)
        end
        PaidTier.Finished = true
    end)
end


---@param content string
function PaidTier.ParseRemoteList(content)
    if not content then return end
    
    local count = 0
    for line in content:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        
        if line ~= "" then
            local uid = tonumber(line)
            if uid then
                local exists = false
                for _, existingId in ipairs(PaidTier.PaidUIDs) do
                    if existingId == uid then
                        exists = true
                        break
                    end
                end
                
                if not exists then
                    table.insert(PaidTier.PaidUIDs, uid)
                    count = count + 1
                end
            end
        end
    end
    
    if count > 0 then
        PaidTier.ResetCache()
    end
end

return PaidTier
