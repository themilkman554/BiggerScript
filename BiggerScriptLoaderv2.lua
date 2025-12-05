package.path = FileMgr.GetMenuRootPath() .. "\\Lua\\"

local menuRootPath = FileMgr.GetMenuRootPath()
local targetPath = menuRootPath .. "\\Lua\\BiggerScript"
local lastCommitPath = targetPath .. "\\last_commit.txt"

local OWNER = "themilkman554"
local REPO = "BiggerScriptAssests"
local BRANCH = "main"

local function json_decode(text)
    local pos = 1
    local function skip_whitespace()
        while pos <= #text and text:sub(pos, pos):match("%s") do pos = pos + 1 end
    end
    local function parse_value()
        skip_whitespace()
        local char = text:sub(pos, pos)
        if char == "{" then
            pos = pos + 1
            local obj = {}
            skip_whitespace()
            if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
            while true do
                local key = parse_value()
                skip_whitespace()
                if text:sub(pos, pos) == ":" then pos = pos + 1 else return nil end
                local val = parse_value()
                obj[key] = val
                skip_whitespace()
                local next_char = text:sub(pos, pos)
                pos = pos + 1
                if next_char == "}" then return obj end
                if next_char ~= "," then return nil end
            end
        elseif char == "[" then
            pos = pos + 1
            local arr = {}
            skip_whitespace()
            if text:sub(pos, pos) == "]" then pos = pos + 1; return arr end
            local idx = 1
            while true do
                arr[idx] = parse_value()
                idx = idx + 1
                skip_whitespace()
                local next_char = text:sub(pos, pos)
                pos = pos + 1
                if next_char == "]" then return arr end
                if next_char ~= "," then return nil end
            end
        elseif char == '"' then
            local start = pos + 1
            local end_quote = text:find('"', start)
            while end_quote and text:sub(end_quote-1, end_quote-1) == '\\' do
                end_quote = text:find('"', end_quote + 1)
            end
            if not end_quote then return nil end
            local str = text:sub(start, end_quote - 1)
            pos = end_quote + 1
            return str
        elseif char == "t" then pos = pos + 4; return true
        elseif char == "f" then pos = pos + 5; return false
        elseif char == "n" then pos = pos + 4; return nil
        else
            local start = pos
            while pos <= #text and text:sub(pos, pos):match("[%d%.%-eE+]") do pos = pos + 1 end
            return tonumber(text:sub(start, pos - 1))
        end
    end
    if not text then return nil end
    return parse_value()
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(path, data, mode)
    local f = io.open(path, mode or "w")
    if f then
        f:write(data or "")
        f:close()
    end
end

local function ensure_dir(path)
    local dir = path:match("(.+)[/\\]")
    if dir and not FileMgr.DoesFileExist(dir) then
        FileMgr.CreateDirectory(dir)
    end
end

local function curl_get(url)
    local curl = Curl.Easy()
    curl:Setopt(10002, url)
    curl:Setopt(52, 1)
    curl:Setopt(10018, "Cherax-Script")
    curl:Perform()
    while not curl:GetFinished() do
        Script.Yield(10)
    end
    local code, response = curl:GetResponse()
    if code == 0 then return response end
    return nil
end

Script.QueueJob(function()
    -- 1. Fetch latest commit info from GitHub API
    local api_url = string.format("https://api.github.com/repos/%s/%s/commits/%s", OWNER, REPO, BRANCH)
    local body = curl_get(api_url)
    local commit_data = json_decode(body)
    local latest_commit = commit_data and commit_data.sha
    
    local last_commit = read_file(lastCommitPath)
    
    -- 2. Determine Update Strategy
    if not FileMgr.DoesFileExist(targetPath) or not last_commit then
        -- A. Full Install (Missing folder or no version history)
        GUI.AddToast("BiggerScript", "Installing BiggerScript Assets (game will be frozen)", 5000, 0)
        local ZIP_URL = "https://codeload.github.com/themilkman554/BiggerScriptAssests/zip/refs/heads/main"
        local tempZipPath = menuRootPath .. "\\Lua\\BiggerScriptTemp.zip"
        
        local zipData = curl_get(ZIP_URL)
        if zipData then
            write_file(tempZipPath, zipData, "wb")
            if FileMgr.Unzip(tempZipPath, menuRootPath .. "\\Lua") then
                FileMgr.DeleteFile(tempZipPath)
                local extractedFolder = menuRootPath .. "\\Lua\\BiggerScriptAssests-main"
                
                if FileMgr.DoesFileExist(targetPath) then
                    local backupPath = targetPath .. "_backup_" .. os.time()
                    os.rename(targetPath, backupPath)
                end
                os.rename(extractedFolder, targetPath)
                
                if latest_commit then write_file(lastCommitPath, latest_commit) end
                GUI.AddToast("BiggerScript", "Assets Installed!", 5000, 0)
            else
                GUI.AddToast("BiggerScript", "Failed to unzip assets!", 5000, 0)
            end
        else
            GUI.AddToast("BiggerScript", "Asset Download Failed!", 5000, 0)
        end

    elseif latest_commit and latest_commit ~= last_commit then
        -- B. Incremental Update (Only changed files)
        GUI.AddToast("BiggerScript", "Updating Assets...", 5000, 0)
        
        if commit_data and commit_data.files then
            local count = 0
            for _, file in ipairs(commit_data.files) do
                local filename = file.filename
                local status = file.status
                local raw_url = file.raw_url
                local local_path = targetPath .. "\\" .. filename:gsub("/", "\\")
                
                if status == "removed" then
                    if FileMgr.DoesFileExist(local_path) then
                        FileMgr.DeleteFile(local_path)
                    end
                else
                    local content = curl_get(raw_url)
                    if content then
                        ensure_dir(local_path)
                        write_file(local_path, content, "wb") -- binary safe
                        count = count + 1
                    end
                end
            end
            write_file(lastCommitPath, latest_commit)
            GUI.AddToast("BiggerScript", "Updated " .. count .. " files.", 5000, 0)
        else
            GUI.AddToast("BiggerScript", "Failed to parse update data.", 5000, 0)
        end
    end
    
    -- 3. Load Main Script from Web
    local GITHUB_RAW_BASE_URL = "https://raw.githubusercontent.com/themilkman554/BiggerScript/main/"
    local main_script_url = GITHUB_RAW_BASE_URL .. "BiggerScript.lua"
    local main_script_content = curl_get(main_script_url)
    
    if main_script_content then
        local main_chunk, err = load(main_script_content, "@BiggerScript.lua")
        if main_chunk then
            pcall(main_chunk)
        else
            GUI.AddToast("BiggerScript", "Compile Error: " .. tostring(err), 5000, 0)
        end
    else
        GUI.AddToast("BiggerScript", "Failed to load main script!", 5000, 0)
    end

end)
